import 'dart:math';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/ship/ship_reg.dart';
import '../../controllers/scanner_controller.dart';
import 'grid.dart';
import '../hazards.dart';
import '../../item.dart';

class ImpulseCell extends GridCell {

  ImpulseCell(super.coord, super.hazMap, super.g);

  @override
  bool scannable(ScannerMode mode, ShipRegistry reg) {
    if (mode == ScannerMode.all) return true;
    if (mode.scaningShips && reg.atCell(this).isNotEmpty) return true;
    if (mode.scaningNeb && hasHaz(Hazard.nebula)) return true;
    if (mode.scaningIons && hasHaz(Hazard.ion)) return true;
    if (mode.scaningRoids && hasHaz(Hazard.roid)) return true;
    if (mode.scaningItems && itemz.isNotEmpty) return true;
    return false;
  }

  @override
  bool isEmpty(ShipRegistry reg, {countPlayer = true}) {
    final ships = reg.atCell(this);
    if (ships.isNotEmpty && (countPlayer || ships.any((s) => s.npc))) return false;
    if (hazLevel > 0) return false;
    if (itemz.isNotEmpty) return false;
    return true;
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer(super.toString());
    for (Item item in itemz) {
      sb.write("\n${item.name}");
    }
    return sb.toString();
  }
}

class ImpulseLevel extends Level {
  @override
  Domain get domain => Domain.impulse;

  ImpulseLevel(Grid<ImpulseCell> cells, SectorCell sector) {
    upperLevel = sector;
    map = cells;
  }
  SectorCell get sector => upperLevel as SectorCell;
}

class ImpulseMap extends Grid<ImpulseCell> {
  ImpulseMap(super.size, super.cells);

  void hodgeTick(Hazard haz, Random rnd, {jitter = .1}) {
    final Map<Coord3D,double> tmpCells = {};
    for (final entry in cells.entries) {
      int count = getAdjacentCells(entry.value).where((n) => n.hasHaz(haz)).length; //print("${entry.key}: $count");
      if (entry.value.hasHaz(haz)) {
        if (count > 3 && count < 6) tmpCells[entry.key] = entry.value.hazMap[haz]!;
        else tmpCells[entry.key] = 0;
      } else {
        if (count == 5 || (count == 0 && rnd.nextDouble() < jitter)) tmpCells[entry.key] = rnd.nextDouble();
        else tmpCells[entry.key] = 0;
      }
    }
    for (final entry in cells.entries) {
      entry.value.hazMap[haz] = tmpCells[entry.key] ?? 0;
    }
  }
}