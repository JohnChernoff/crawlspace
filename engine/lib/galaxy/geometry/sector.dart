import 'dart:math';

import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/planet.dart';
import 'package:crawlspace_engine/galaxy/system.dart';
import 'package:crawlspace_engine/ship/ship_reg.dart';
import '../../controllers/scanner_controller.dart';
import 'grid.dart';
import '../hazards.dart';
import 'impulse.dart';

typedef SectorMap = MappedGrid<ImpulseCell>;

class SectorCell extends GridCell {
  final System system;
  Planet? planet;
  StellarClass? starClass;
  bool starOne, blackHole;
  int impulseSeed;
  @override
  SectorMap get map => system.impulseCache.putIfAbsent(coord,
        () => system.generateImpulseMap(this, system.impulseMapSize, Random(impulseSeed)),
  );

  SectorCell(
      this.system,
      this.impulseSeed, {
        super.g,
        super.coord,
        super.hazMap,
        this.planet,
        this.starClass,
        this.starOne = false,
        this.blackHole = false,
      });

  @override
  bool isEmpty(ShipRegistry reg, {countPlayer = true}) { //print("Chceking enpty");
    final ships = reg.atCell(this);
    if (ships.isNotEmpty && (countPlayer || ships.any((s) => s.npc))) return false;
    if (planet != null) return false;
    if (starClass != null) return false;
    if (starOne || blackHole) return false;
    if (hazLevel > 0) return false;
    return true;
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer(super.toString());
    if (starClass != null) sb.write("Class ${starClass?.name} Star");
    if (planet != null) sb.write("${planet!.shortString()}");
    return sb.toString();
  }

  @override //TODO: Nebula Effects
  bool scannable(ScannerMode mode,ShipRegistry reg) {
    if (mode == ScannerMode.all) return true;
    if (mode.scaningShips && reg.atCell(this).isNotEmpty) return true;
    if (mode.scaningPlanets && planet != null) return true;
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
  EmptyImpulse() : super(0, {});
}
