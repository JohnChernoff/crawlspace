import 'dart:math';
import 'package:crawlspace_engine/coord_3d.dart';
import 'package:crawlspace_engine/sector.dart';
import 'package:crawlspace_engine/ship_reg.dart';
import 'controllers/scanner_controller.dart';
import 'grid.dart';
import 'hazards.dart';
import 'item.dart';

class ImpulseCell extends GridCell {
  List<Item> items = [];

  ImpulseCell(super.coord, super.hazMap);

  @override
  bool scannable(ScannerMode mode, ShipRegistry reg) {
    if (mode == ScannerMode.all) return true;
    if (mode.scaningShips && reg.atCell(this).isNotEmpty) return true;
    if (mode.scaningNeb && hasHaz(Hazard.nebula)) return true;
    if (mode.scaningIons && hasHaz(Hazard.ion)) return true;
    if (mode.scaningRoids && hasHaz(Hazard.roid)) return true;
    if (mode.scaningItems && items.isNotEmpty) return true;
    return false;
  }

  @override
  bool isEmpty(ShipRegistry reg, {countPlayer = true}) {
    final ships = reg.atCell(this);
    if (ships.isNotEmpty && (countPlayer || ships.any((s) => s.npc))) return false;
    if (hazLevel > 0) return false;
    if (items.isNotEmpty) return false;
    return true;
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer(super.toString());
    for (Item item in items) {
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