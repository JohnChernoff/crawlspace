import 'dart:collection';
import 'dart:math';
import 'color.dart';
import 'controllers/scanner_controller.dart';
import 'coord_3d.dart';
import 'grid.dart';
import 'hazards.dart';
import 'impulse.dart';
import 'planet.dart';
import 'rng.dart';

enum TrafficLvl { normal, culDeSac, hub }

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

class SystemMap extends Grid<SectorCell> {
  SystemMap(super.size, super.cells);
}

class SectorCell extends GridCell {
  Planet? planet;
  StellarClass? starClass;
  bool starOne,blackHole;

  //double nebula,ionStorm,asteroids;
  int impulseSeed;

  SectorCell(super.coord, super.hazMap, this.impulseSeed, {
    this.planet,this.starClass, this.starOne = false, this.blackHole = false,
  });

  @override
  bool empty(Grid grid, {countPlayer = true}) { //print("Chceking enpty");
    if (super.hasShips(grid,countPlayer: countPlayer)) return false;
    if (planet != null) return false;
    if (starClass != null) return false;
    if (starOne || blackHole) return false;
    if (hazLevel > 0) return false;
    return true;
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer(super.toString());
    if (starClass != null) sb.write(", $starClass");
    if (planet != null) sb.write(", ${planet!.shortString()}");
    return sb.toString();
  }

  @override //TODO: Nebula Effects
  bool scannable(Grid grid,ScannerMode mode) {
    if (mode == ScannerMode.all) return true;
    if (mode.scaningShips && hasShips(grid)) return true;
    if (mode.scaningPlanets && planet != null) return true;
    if (mode.scaningStars && starClass != null) return true;
    if (mode.scaningNeb && hasHaz(Hazard.nebula)) return true;
    if (mode.scaningIons && hasHaz(Hazard.ion)) return true;
    if (mode.scaningRoids && hasHaz(Hazard.roid)) return true;
    if (mode.scaningStarOne && starOne) return true;
    if (mode.scaningBlackhole && blackHole) return true;
    return false;
  }

}

class System extends Level {
  @override
  Domain get domain => Domain.system;
  String name;
  Set<System> links = HashSet();
  List<Planet> planets;
  int fedLvl, techLvl;
  bool starOne, blackHole;
  TrafficLvl traffic;
  bool scouted = false;
  bool visited = false;
  bool connected;
  StellarClass starClass;
  Map<SectorCell,ImpulseLevel> impMapCache = {};

  System(this.name,this.starClass,this.fedLvl,this.techLvl,this.planets,Random rnd,
      {this.blackHole = false,this.starOne = false, this.traffic = TrafficLvl.normal, this.connected = false,
      nebFact = .02, ionFact = .01, bhFact = .1, mapSize = 8}) {
    map = createSystemMap(mapSize,nebFact,ionFact,bhFact,rnd);
  }

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

  void scout() {
    scouted = true;
    for (Planet planet in planets) {
      planet.known = true;
    }
  }

  void updateLevels(Random rnd) {
    int techSum = techLvl, fedSum = fedLvl; //print("Updating Fed: $fedLvl");
    for (System system in links) {
      techSum += system.techLvl;
      fedSum += system.fedLvl;
    }
    int tl = (techSum / (links.length)).round();
    int fl =  (fedSum / (links.length)).round();
    techLvl = min(Rng.biasedRndInt(rnd,mean: tl,min: 0, max: max(tl * 1,100)),100);
    fedLvl = min(Rng.biasedRndInt(rnd,mean: fl ,min: 0, max: max(fl * 1,100)),100);
    //print("$name -> $fedLvl -> $fl -> ${links.length}");
    for (Planet planet in planets) {
      planet.techLvl = Rng.biasedRndInt(rnd,mean: techLvl,min: 0, max: 100);
      planet.fedLvl = Rng.biasedRndInt(rnd,mean: fedLvl,min: 0, max: 100);
      planet.export = planet.getRndExport();
      planet.updateDescription();
    }
  }

  SystemMap createSystemMap(int size, double nebulaFactor, double ionFactor, double blackFactor, Random rnd) {
    Map<Coord3D,SectorCell> cells = {};
    for (int x=0;x<size;x++) {
      for (int y=0;y<size;y++) {
        for (int z=0;z<size;z++) {
          Map<Hazard, double> hazMap = {
            Hazard.nebula : (nebulaFactor > rnd.nextDouble() ? 1 : 0),
            Hazard.ion : (ionFactor > rnd.nextDouble() ? 1 : 0),
            Hazard.roid : (ionFactor > rnd.nextDouble() ? 1 : 0)
          };
          final c = Coord3D(x, y, z); //if (neb == 1) print("System: $name, neb: $neb -> $c");
          cells.putIfAbsent(c, () => SectorCell(c,hazMap, rnd.nextInt(999999)));
        }
      }
    }

    final map = SystemMap(size, cells);
    for (int x=0;x<size;x++) {
      for (int y=0;y<size;y++) {
        for (int z=0;z<size;z++) {
          final c = map.cells[Coord3D(x, y, z)]; //use copy
          if (c != null) {
            for (final h in c.hazMap.entries) {
              if (h.value == 1) { //print("System: $name, Adding hazard -> ${c.coord}");
                map.growHazard(c,h.key,rnd.nextDouble(),rnd);
              }
            }
          }
        }
      }
    }

    if (blackFactor > rnd.nextDouble()) {
      map.rndCell(rnd).blackHole = true;
    }

    final List<SectorCell> npCells = map.cells.values.where((c) => c.planet == null && c.blackHole == false).toList();
    if (npCells.length > planets.length) {
      npCells.shuffle(rnd);
      for (int i = 0; i < planets.length; i++) {
        npCells[i].clearHazards();
        npCells[i].planet = planets[i];
      }
      npCells[planets.length].clearHazards();
      npCells[planets.length].starClass = starClass;
    }

    return map;
  }

  String shortString({bool showVisit = false}) {
    return "$name (🛡$fedLvl,⚙$techLvl)${(showVisit && visited) ? '*' : ''}";
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
    return "$name fed: $fedLvl tech: $techLvl (${links.length} links,${traffic.name}): $linksStr planets: $planetsStr \n";
  }

  @override
  bool operator ==(Object other) => other is System && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
