import 'dart:math';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/system.dart';
import '../../controllers/scanner_controller.dart';
import 'grid.dart';
import '../hazards.dart';
import 'impulse.dart';

typedef SectorMap = MappedGrid<ImpulseCell>;

class SectorCell extends GridCell {
  final System system;
  //Set<Planet> planets(PlanetRegistry reg) => reg.inSector(loc);
  int numPlanets(Galaxy g) => g.planets.inSector(loc).length;
  bool hasPlanets(Galaxy g) => numPlanets(g) > 0;
  StellarClass? starClass;
  bool starOne, blackHole;
  int impulseSeed;
  @override
  SectorMap get map => system.impulseCache.putIfAbsent(coord,
        () => system.generateImpulseMap(this, system.impulseMapDim, Random(impulseSeed)),
  );

  SectorCell(
      this.system,
      this.impulseSeed, {
        super.coord,
        super.hazMap,
        this.starClass,
        this.starOne = false,
        this.blackHole = false,
      });

  @override
  bool isEmpty(Galaxy g, {countPlayer = true}) { //print("Chceking enpty");
    final ships = g.ships.atCell(this);
    if (ships.isNotEmpty && (countPlayer || ships.any((s) => s.npc))) return false;
    if (hasPlanets(g)) return false;
    if (starClass != null) return false;
    if (starOne || blackHole) return false;
    if (hazLevel > 0) return false;
    return true;
  }

  @override
  String toScannerString(Galaxy g) {
    StringBuffer sb = StringBuffer(super.toScannerString(g));
    int i = sb.isEmpty ? 0 : 1;
    for (final planet in g.planets.inSector(loc)) {
      final comma = i++ > 1 ? "," : "";
      sb.write("$comma${planet.name}");
    }
    return sb.toString();
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer(super.toString());
    if (starClass != null) sb.write("Class ${starClass?.name} Star");
    return sb.toString();
  }

  @override //TODO: Nebula Effects
  bool scannable(ScannerMode mode,Galaxy g) {
    if (mode == ScannerMode.all) return true;
    if (mode.scaningShips && g.ships.atCell(this).isNotEmpty) return true;
    if (mode.scaningPlanets && hasPlanets(g)) return true;
    if (mode.scaningStars && starClass != null) return true;
    if (mode.scaningNeb && hasHaz(Hazard.nebula)) return true;
    if (mode.scaningIons && hasHaz(Hazard.ion)) return true;
    if (mode.scaningRoids && hasHaz(Hazard.roid)) return true;
    if (mode.scaningStarOne && starOne) return true;
    if (mode.scaningBlackhole && blackHole) return true;
    return false;
  }

  @override
  SectorLocation get loc => SectorLocation(system, coord);
}

class EmptyImpulse extends SectorMap {
  EmptyImpulse() : super(GridDim(0, 0, 0), {});
}
