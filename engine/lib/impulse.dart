import 'package:crawlspace_engine/sector.dart';
import 'controllers/scanner_controller.dart';
import 'grid.dart';
import 'hazards.dart';
import 'item.dart';

class ImpulseCell extends GridCell {
  List<Item> items = [];

  ImpulseCell(super.coord, super.hazMap);

  @override
  bool scannable(Grid grid, ScannerMode mode) {
    if (mode == ScannerMode.all) return true;
    if (mode.scaningShips && hasShips(grid)) return true;
    if (mode.scaningNeb && hasHaz(Hazard.nebula)) return true;
    if (mode.scaningIons && hasHaz(Hazard.ion)) return true;
    if (mode.scaningRoids && hasHaz(Hazard.roid)) return true;
    if (mode.scaningItems && items.isNotEmpty) return true;
    return false;
  }

  @override
  bool empty(Grid<GridCell> grid, {countPlayer = true}) {
    if (super.hasShips(grid,countPlayer: countPlayer)) return false;
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
}