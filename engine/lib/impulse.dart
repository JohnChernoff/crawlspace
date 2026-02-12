import 'dart:math';
import 'package:crawlspace_engine/path_generator.dart';
import 'controllers/scanner_controller.dart';
import 'coord_3d.dart';
import 'grid.dart';
import 'hazards.dart';
import 'item.dart';
import 'system.dart';

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
  factory ImpulseMap.withPath(int size, Map<Coord3D, ImpulseCell> cells, Random rnd, {
    paths = 2, rooms = 1, roomRad = 1, pwMax = 1}) {
    final imp = ImpulseMap(size, cells);
    // Advanced approach: more structured paths
    AdvancedPathGenerator.generateWithControl(
      imp,
      rooms,
      paths,
      rnd,
      roomRadius: roomRad,
      minPathLength: 5,
      pathWidthMin: 1,
      pathWidthMax: pwMax,
    );
    return imp;
  }
}