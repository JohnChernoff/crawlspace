import 'dart:math';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/ship/ship_reg.dart';
import '../../controllers/scanner_controller.dart';
import 'grid.dart';
import '../hazards.dart';
import '../../item.dart';

typedef ImpulseMap = MappedGrid<ImpulseCell>;

class ImpulseCell extends GridCell {

  ImpulseMap map;
  SectorCell sector;

  ImpulseCell(
      this.sector, {
        super.coord,
        super.hazMap,
      }) : map = EmptySubImpulse.instance;

  void hodgeTick(Hazard haz, Random rnd, {jitter = .1}) {
    final parentMap = sector.map;
    final Map<Coord3D,double> tmpCells = {};
    for (final entry in parentMap.values) {
      int count = parentMap.getAdjacentCells(entry).where((n) => n.hasHaz(haz)).length;
      if (entry.hasHaz(haz)) {
        if (count > 3 && count < 6) tmpCells[entry.coord] = entry.hazMap[haz]!;
        else tmpCells[entry.coord] = 0;
      } else {
        if (count == 5 || (count == 0 && rnd.nextDouble() < jitter)) tmpCells[entry.coord] = rnd.nextDouble();
        else tmpCells[entry.coord] = 0;
      }
    }
    for (final entry in parentMap.values) {
      entry.hazMap[haz] = tmpCells[entry.coord] ?? 0;
    }
  }

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

  @override
  ImpulseLocation get loc => ImpulseLocation(sector.system, sector.coord, coord);
}

class EmptySubImpulse extends ImpulseMap {
  static final instance = EmptySubImpulse._();
  EmptySubImpulse._() : super(0, const {});
}
