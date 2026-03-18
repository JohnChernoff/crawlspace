import 'dart:collection';
import 'dart:math';
import 'package:crawlspace_engine/controllers/scanner_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/ship/ship_reg.dart';
import '../color.dart';
import '../item.dart';
import 'geometry/coord_3d.dart';
import 'galaxy.dart';
import 'geometry/grid.dart';
import 'geometry/impulse.dart';
import 'geometry/path_gen.dart';
import 'hazards.dart';
import 'planet.dart';
import '../rng/rng.dart';

enum TrafficGenHint { normal, culDeSac, hub }

enum StellarClass {
  O(GameColor(0xFF3456EE),100,4),
  B(GameColor(0xFFAABEFF),75,12),
  A(GameColor(0xFFD5E0FE),60,20),
  F(GameColor(0xFFF8F5FF),50,32),
  G(GameColor(0xFFFFEDE2),36,48),
  K(GameColor(0xFFFFD9B5),25,75),
  M(GameColor(0xFFFFB56C),12,100);
  final GameColor color;
  final int power;
  final int prob;
  const StellarClass(this.color,this.power,this.prob);
}

typedef SystemMap = MappedGrid<SectorCell>;

class System extends GridCell implements Nameable {
  final systemMapSize = 8;
  final impulseMapSize = 12; //minimums?
  String name;
  String get selectionName => name;
  Set<System> links = HashSet();
  List<Planet> planets = []; //TODO: change to SpaceObject
  bool starOne, blackHole;
  TrafficGenHint trafficGenHint;
  bool scouted = false;
  bool visited = false;
  bool connected;
  StellarClass starClass;
  double anomaly;
  SystemMap map;
  final Map<Coord3D, SectorMap> impulseCache = {};

  System(this.name,this.starClass,Random rnd,
      {super.coord, super.hazMap, required this.map,this.blackHole = false,this.starOne = false,
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

  void scout() {
    scouted = true;
    for (Planet planet in planets) {
      planet.known = true;
    }
  }

  SystemMap createSystemMap(double nebulaFactor, double ionFactor, double blackFactor, Galaxy g) {
    int size = systemMapSize;
    Map<Coord3D,SectorCell> cells = {};
    for (int x=0;x<size;x++) {
      for (int y=0;y<size;y++) {
        for (int z=0;z<size;z++) {
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

    final map = SystemMap(size, cells);
    for (int x=0;x<size;x++) {
      for (int y=0;y<size;y++) {
        for (int z=0;z<size;z++) {
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
    final List<SectorCell> starCells = map.values.where((c) => c.planet == null && c.blackHole == false).toList();
    final starCell = map.rndCell(g.rnd, cellList:  starCells);
    starCell.clearHazards();
    starCell.starClass = starClass;

    return map;
  }

  //which to use - g.fedLevel.val(this) or g.fedMod.fedPressure[this]
  void addPlanets(Galaxy g, Random rnd, {List<Planet> pList = const []}) {
    List<Planet> planetList = pList.toList();
    final n = Rng.biasedRndInt(rnd, mean: Galaxy.avgPlanets, min: 0, max: Galaxy.maxPlanets);
    for (int i = 0; i < n; i++) {//print("Adding planet to $name");
      final fed = g.fedKernel.val(this);
      final tech = g.techKernel.val(this);
      final comm = g.commerceKernel.val(this);
      final res = g.civKernel.val(this);
      final dust = min(1.0, comm * 0.7 + tech * 0.3);
      //print("res: $res, comm: $comm, dust: $dust");
      final cellList = map.values.where((sc) => sc.planet == null && !sc.blackHole).toList();
      final loc = SectorLocation(this,map.rndCell(rnd, cellList: cellList).coord);
      final planet = Planet(
        g.nameGenerator.generatePlanetName(),
        Rng.betaRnd(rnd, fed, 15),
        Rng.betaRnd(rnd, tech, 12),
        rnd,
        species: Rng.weightedRandom(g.civMod.civIntensity[this]!, rnd),
        locale: loc,
        population: Rng.betaRnd(rnd, res, 20),
        commerce: Rng.betaRnd(rnd, comm, 10),
        industry: Rng.betaRnd(rnd, dust, 6),
      );
      planetList.add(planet);
    }
    for (final planet in planetList) {
      planets.add(planet);
      planet.loc.cell.planet = planet;
      planet.loc.cell.clearHazards();
    }
  }

  void explore(int depth, {System? sys}) { //msgController.addMsg("Exploring: ${system.name} , depth: $depth");
    final system = sys ?? this;
    system.scout();
    if (depth == 0) return;
    for (System link in system.links) {
      if (!link.scouted) explore(depth-1,sys: system);
    }
  }

  ImpulseLocation rndImpLoc(Galaxy g) => ImpulseLocation(
      this,
      Coord3D.random(systemMapSize,g.rnd),
      Coord3D.random(impulseMapSize,g.rnd));

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
    StringBuffer planetsStr = StringBuffer();
    for (int i=0;i<planets.length;i++) {
      planetsStr.write(" ${planets.elementAt(i).name} ");
    }
    return "$name (${links.length} links,${trafficGenHint.name}): $linksStr planets: $planetsStr \n";
  }

  @override
  bool operator ==(Object other) => other is System && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  bool isEmpty(ShipRegistry reg, {countPlayer = true}) => false;

  @override
  bool scannable(ScannerMode mode, ShipRegistry reg) => true;

  @override
  SpaceLocation get loc => throw UnimplementedError();

  SectorMap generateImpulseMap(SectorCell sector, int size, Random rnd) {
    final sectorIon = sector.hazMap[Hazard.ion] ?? 0;
    final sectorNeb = sector.hazMap[Hazard.nebula] ?? 0;

    final cells = <Coord3D, ImpulseCell>{};

    for (int x = 0; x < size; x++) {
      for (int y = 0; y < size; y++) {
        for (int z = 0; z < size; z++) {
          final c = Coord3D(x, y, z);
          cells[c] = ImpulseCell(
            sector,
            coord: c,
            hazMap: {
              Hazard.nebula: rnd.nextDouble() < sectorNeb ? sectorNeb : 0,
              Hazard.ion: rnd.nextDouble() < sectorIon ? sectorIon : 0,
              Hazard.roid: sector.hazMap[Hazard.roid] ?? 0,
              Hazard.wake: c.isEdge(size) ? 1 : 0,
            },
          );
        }
      }
    }
    final impMap = SectorMap(size, cells);
    if (sector.hasHaz(Hazard.roid)) {
      PathGenerator.generate(impMap, 4, 0, rnd, haz: Hazard.roid);
    }
    return impMap;
  }
}

class EmptySector extends SystemMap {
  EmptySector() : super(0, const {});
}
