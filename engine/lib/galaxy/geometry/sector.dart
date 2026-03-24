import 'dart:math';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/system.dart';
import '../../controllers/scanner_controller.dart';
import '../../rng/star_sys_gen.dart';
import '../../stock_items/species.dart';
import '../star.dart';
import 'grid.dart';
import '../hazards.dart';
import 'impulse.dart';

typedef SectorMap = MappedGrid<ImpulseCell>;

class SectorCell extends GridCell {
  final System system;
  int numPlanets(Galaxy g) => g.planets.inSector(loc).length;
  bool hasPlanets(Galaxy g) => numPlanets(g) > 0;
  int numStars(Galaxy g) => g.stars.inSector(loc).length;
  bool hasStars(Galaxy g) => numStars(g) > 0;
  bool hasGate(Galaxy g) => g.stars.inSector(loc).any((s) => s.jumpgate);

  bool starOne, blackHole;
  int impulseSeed;
  Faction outpostPropriator;
  Coord3D outpostLoc;
  @override
  SectorMap get map => system.impulseCache.putIfAbsent(coord,
        () => system.generateImpulseMap(this, system.impulseMapDim, Random(impulseSeed)),
  );

  SectorCell(
      this.system,
      this.impulseSeed, {
        super.coord,
        super.hazMap,
        this.starOne = false,
        this.blackHole = false,
        Faction? propriator,
      }) :
        outpostPropriator = propriator ?? getFaction(FactionList.fed)!,
        outpostLoc = Coord3D((system.impulseMapDim.mx/2).round(),(system.impulseMapDim.my/2).round(),0);

  @override
  bool isEmpty(Galaxy g, {countPlayer = true}) { //print("Chceking enpty");
    final ships = g.ships.atCell(this);
    if (ships.isNotEmpty && (countPlayer || ships.any((s) => s.npc))) return false;
    if (hasPlanets(g)) return false;
    if (hasStars(g)) return false;
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

  @override //TODO: Nebula Effects
  bool scannable(ScannerMode mode,Galaxy g) {
    if (mode == ScannerMode.all) return true;
    if (mode.scaningShips && g.ships.atCell(this).isNotEmpty) return true;
    if (mode.scaningPlanets && hasPlanets(g)) return true;
    if (mode.scaningStars && hasStars(g)) return true;
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
