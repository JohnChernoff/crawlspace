import 'dart:collection';
import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/galaxy/star.dart';
import '../item.dart';
import '../rng/plan_blueprint_gen.dart';
import '../rng/star_sys_gen.dart';
import 'geometry/coord_3d.dart';
import 'galaxy.dart';
import 'geometry/grid.dart';
import 'geometry/impulse.dart';
import 'geometry/path_gen.dart';
import 'hazards.dart';
import 'planet.dart';
import '../rng/rng.dart';

enum TrafficGenHint { normal, culDeSac, hub }

typedef SystemMap = MappedGrid<SectorCell>;

class System extends Grid implements Nameable {
  final systemMapDim = GridDim(20, 20, 1);
  final impulseMapDim = GridDim(20, 20, 1);
  String name;
  String get selectionName => name;
  Set<System> links = HashSet();
  List<Star> stars(Galaxy g) => g.stars.inSystem(this).toList();
  List<Planet> planets(Galaxy g) => g.planets.inSystem(this).toList();
  List<MassiveObject> massiveObjects(Galaxy g) => [
    ...planets(g),
    ...stars(g),
  ];
  bool starOne, blackHole;
  TrafficGenHint trafficGenHint;
  bool scouted = false;
  bool visited = false;
  bool connected;
  double anomaly;
  SystemMap map;
  final Map<Coord3D, SectorMap> impulseCache = {};
  late SystemMetadata metadata;

  System(this.name,Random rnd,
      { super.hazMap, required this.map,this.blackHole = false,this.starOne = false,
        this.trafficGenHint = TrafficGenHint.normal, this.connected = false})
      : anomaly = 0.7 + rnd.nextDouble() * 0.6;

  bool addLink(System sys, {linkback = false, required bool update}) { //modify tech/fed levels?
    if (this != sys && links.add(sys)) { //use trafficLvl?
      if (sys.connected) setConnection(true, update: update); //print("$name <-> ${sys.name}, links: ${links.length}");
      return (linkback || sys.addLink(this,linkback: true, update: update));
    }
    return false;
  }

  setConnection(bool c, {update = true}) {
    if (connected != c) {
      connected = c;
      if (connected && update) {
        for (System link in links) {
          link.setConnection(true);
        }
      }
    }
  }

  void visit(FugueEngine fm) {
    if (!visited) {
      visited = true;
      fm.populateSystem(this);
    }
  }

  void scout(Galaxy g) {
    scouted = true;
    for (Planet planet in planets(g)) {
      planet.known = true;
    }
  }

  SystemMap createSystemMap(double nebulaFactor, double ionFactor, double blackFactor, Galaxy g) {
    final dim = systemMapDim;
    Map<Coord3D,SectorCell> cells = {};
    for (int x=0;x<dim.mx;x++) {
      for (int y=0;y<dim.my;y++) {
        for (int z=0;z<dim.mz;z++) {
          Map<Hazard, double> hazMap = {
            Hazard.nebula : (nebulaFactor > g.rnd.nextDouble() ? 1 : 0),
            Hazard.ion : (ionFactor > g.rnd.nextDouble() ? 1 : 0),
            Hazard.roid : (ionFactor > g.rnd.nextDouble() ? 1 : 0)
          };
          final c = Coord3D(x, y, z); //if (neb == 1) print("System: $name, neb: $neb -> $c");
          final sectorCell = SectorCell(this,g.rnd.nextInt(999999),coord: c,hazMap: hazMap);
          cells.putIfAbsent(c, () => sectorCell);
        }
      }
    }

    final map = SystemMap(dim, cells);
    for (int x=0;x<map.dim.mx;x++) {
      for (int y=0;y<map.dim.my;y++) {
        for (int z=0;z<map.dim.mz;z++) {
          final c = map.at(Coord3D(x, y, z)); //use copy
          for (final h in c.hazMap.entries) {
            if (h.value == 1) { //print("System: $name, Adding hazard -> ${c.coord}");
              map.growHazard(c,h.key,g.rnd.nextDouble(),g.rnd);
            }
          }
        }
      }
    }

    if (blackFactor > g.rnd.nextDouble()) map.rndCell(g.rnd).blackHole = true;

    final List<SectorCell> starCells = map.values.where((c) => !c.hasPlanets(g) && c.blackHole == false).toList();
    final starCell = map.rndCell(g.rnd, cellList:  starCells);
    starCell.clearHazards();

    return map;
  }

  List<Star> generateStars(Galaxy g, Random rnd) {
    List<Star> starList = [];
    for (int i=0;i < min(metadata.stellarClasses.length,3);i++) {
      final star = Star(metadata.stellarClasses.elementAt(i), i == 0);
      starList.add(star);
      final sectorCoord = metadata.starConfig.starPositions(systemMapDim).elementAt(i);
      final loc = ImpulseLocation(this,
          sectorCoord,
          g.stars.randomEmptyCoord(this,sectorCoord,systemMapDim, rnd));
      g.stars.register(star, loc); //print("Registered: ${name}, $loc");
    }
    return starList;
  }

  //which to use - g.fedLevel.val(this) or g.fedMod.fedPressure[this]
  List<Planet> generatePlanets(Galaxy g, Random rnd) {
    List<Planet> planetList = [];
    for (final pData in metadata.planetBlueprints) { //print("Adding planet to $name");

      final fed = g.fedKernel.val(this);
      final tech = g.techKernel.val(this);
      final comm = g.commerceKernel.val(this);
      final res = g.civKernel.val(this);
      final dust = min(1.0, comm * 0.7 + tech * 0.3);
      //print("res: $res, comm: $comm, dust: $dust");

      final centerLoc = ImpulseLocation(this, pData.position, systemMapDim.center);
      final loc = g.planets.byImpulse(centerLoc) != null
      ? g.planets.randomUnoccupiedLocation(this, rnd)
      : centerLoc;

      final planet = Planet(
        g.nameGenerator.generatePlanetName(),
        Rng.betaRnd(rnd, fed, 15),
        Rng.betaRnd(rnd, tech, 12),
        rnd,
        species: Rng.weightedRandom(g.civMod.civIntensity[this]!, rnd),
        population: Rng.betaRnd(rnd, res, 20),
        commerce: Rng.betaRnd(rnd, comm, 10),
        industry: Rng.betaRnd(rnd, dust, 6),
        environment: PlanetBlueprint.candidatesFor(OrbitalZone.inner, pData.type).first, //TODO: determine OrbitalZone
        weirdness: rnd.nextDouble()
      );

      g.planets.register(planet, loc);
      planetList.add(planet);
    }
    return planetList;
  }

  void explore(int depth, Galaxy g, {System? sys}) { //msgController.addMsg("Exploring: ${system.name} , depth: $depth");
    final system = sys ?? this;
    system.scout(g);
    if (depth == 0) return;
    for (System link in system.links) {
      if (!link.scouted) explore(depth-1,g,sys: system);
    }
  }

  ImpulseLocation rndImpLoc(Galaxy g) => ImpulseLocation(
      this,
      Coord3D.random(systemMapDim,g.rnd),
      Coord3D.random(impulseMapDim,g.rnd));

  String shortString(Galaxy g, {bool showVisit = false}) {
    return "$name ("
        "🛡${(g.fedKernel.valStr(this))},"
        "⚙${g.techKernel.valStr(this)})"
        "${(showVisit && visited) ? '*' : ''}";
  }

  @override String toString() {
    StringBuffer linksStr = StringBuffer();
    for (int i=0;i<links.length;i++) {
      linksStr.write(" ${links.elementAt(i).name} ");
    }
    return "$name (${links.length} links,${trafficGenHint.name})\n";
  }

  @override
  bool operator ==(Object other) => other is System && other.name == name;

  @override
  int get hashCode => name.hashCode;

  SectorMap generateImpulseMap(SectorCell sector, GridDim dim, Random rnd) {
    final sectorIon = sector.hazMap[Hazard.ion] ?? 0;
    final sectorNeb = sector.hazMap[Hazard.nebula] ?? 0;

    final cells = <Coord3D, ImpulseCell>{};
    final centerCoord = Coord3D((dim.mx/2).round(), (dim.my/2).round(), 0) ;
    for (int x = 0; x < dim.mx; x++) {
      for (int y = 0; y < dim.my; y++) {
        for (int z = 0; z < dim.mz; z++) {
          final c = Coord3D(x, y, z);
          cells[c] = ImpulseCell(
            sector,
            coord: c,
            outpost: c == centerCoord,
            hazMap: {
              Hazard.nebula: rnd.nextDouble() < sectorNeb ? sectorNeb : 0,
              Hazard.ion: rnd.nextDouble() < sectorIon ? sectorIon : 0,
              Hazard.roid: sector.hazMap[Hazard.roid] ?? 0,
              //Hazard.wake: c.isEdge(dim) ? 1 : 0, //TODO: perhaps for 3D only
            },
          );
        }
      }
    }
    final impMap = SectorMap(dim, cells);
    if (sector.hasHaz(Hazard.roid)) {
      PathGenerator.generate(impMap, 4, 0, rnd, haz: Hazard.roid);
    }
    return impMap;
  }
}

class EmptySector extends SystemMap {
  EmptySector() : super(GridDim(0, 0, 0), const {});
}
