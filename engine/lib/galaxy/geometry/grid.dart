import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/ship/ship_reg.dart';
import '../../controllers/scanner_controller.dart';
import 'coord_3d.dart';
import '../../effects.dart';
import '../hazards.dart';
import '../../ship/ship.dart';

enum Domain {hyperspace,system,impulse}

abstract class Level {
  Domain get domain;
  GridCell? upperLevel;
  late Grid map;
  Level({this.upperLevel});
}

abstract class GridCell {
  final Coord3D coord;
  final Map<Hazard,double> hazMap;
  final EffectMap<CellEffect> effects = EffectMap();

  GridCell(this.coord,this.hazMap);

  bool isEmpty(ShipRegistry reg, {countPlayer = true});
  void clearHazard(Hazard haz) => hazMap.remove(haz);
  void clearHazards() => hazMap.clear();

  String toScannerString(ShipRegistry reg) {
    StringBuffer sb = StringBuffer(toString());
    final hazards = hazMap.entries.where((h) => h.key != Hazard.wake && h.value > 0);
    for (final haz in hazards) sb.write("${haz.key.shortName}: ${haz.value.toStringAsFixed(2)} ");
    final ships = reg.atCell(this);
    if (ships.length > 1 || sb.length > 0) for (Ship ship in ships) sb.write("\n$ship");
    else if (ships.length == 1) sb.write("${ships.first}");
    return "$coord $sb";
  }

  bool scannable(ScannerMode mode, ShipRegistry reg);
  double get hazLevel => hazMap.entries.where((h) => h.key != Hazard.wake).map((el) => el.value).sum;
  bool hasHaz(Hazard h) => hazMap.containsKey(h) && hazMap[h]! > 0;

  @override
  String toString() => "";
}

class Grid<T extends GridCell> { //Map<GridCell,Set<Ship>> shipMap = {};
  final int size;
  final Map<Coord3D, T> cells;
  late final List<T> _cellList;

  Grid(this.size, this.cells)
      : _cellList = cells.values.toList();

  T rndCell(Random rnd, {List<T>? cellList}) {
    final list = cellList ?? _cellList;
    return list[rnd.nextInt(list.length)];
  }

  void growHazard(T cell, Hazard hazard, double strength, Random rnd, {spreadFactor = .25}) {
    cell.hazMap[hazard] = strength;
    double spreadProb = (rnd.nextDouble() * strength) * spreadFactor;
    for (final neighborCell in getAdjacentCells(cell)) {
      if (neighborCell.hazMap[hazard] == 0 && rnd.nextDouble() < spreadProb) {
        double nextStr = rnd.nextDouble() * strength;
        growHazard(neighborCell,hazard,nextStr,rnd);
      }
    }
  }

  List<T> getAdjacentCells(T cell, {int distance = 1}) {
    final List<T> list = [];
    for (int x = max(cell.coord.x - distance, 0); x <= min(cell.coord.x + distance, size - 1); x++) {
      for (int y = max(cell.coord.y - distance, 0); y <= min(cell.coord.y + distance, size - 1); y++) {
        for (int z = max(cell.coord.z - distance, 0); z <= min(cell.coord.z + distance, size - 1); z++) {
          final c = Coord3D(x, y, z);
          final neighbor = cells[c];
          if (neighbor != null && c != cell.coord) {
            list.add(neighbor);
          }
        }
      }
    }

    return list;
  }

  List<T> getOppositeEdgeCells(T cell) {
    final edge = size-1;
    if (cell.coord.x == 0) {
      return cells.values.where((c) => c.coord.x == edge).toList();
    } else if (cell.coord.x == edge) {
      return cells.values.where((c) => c.coord.x == 0).toList();
    }
    if (cell.coord.y == 0) {
      return cells.values.where((c) => c.coord.y == edge).toList();
    } else if (cell.coord.y == edge) {
      return cells.values.where((c) => c.coord.y == 0).toList();
    }
    if (cell.coord.z == 0) {
      return cells.values.where((c) => c.coord.z == edge).toList();
    } else if (cell.coord.z == edge) {
      return cells.values.where((c) => c.coord.z == 0).toList();
    }
    return [];
  }

  List<T> greedyPath(T start, T goal, int maxSteps, Random rnd, {int nDist = 1, double minHaz = 0, double jitter = .2, forceHaz = false, ignoreHaz = false}) {
    final path = <T>[];
    T current = start;

    for (int i = 0; i < maxSteps; i++) {
      if (current == goal) break;

      final candidates = getAdjacentCells(current, distance: nDist).where((c) => !path.contains(c)).toList();

      candidates.sort((a, b) {
        final da = a.coord.distance(goal.coord) + (rnd.nextDouble() * jitter);
        final db = b.coord.distance(goal.coord) + (rnd.nextDouble() * jitter);
        return da.compareTo(db);
      });

      var next;
      if (ignoreHaz) {
        next = candidates.contains(goal) ? goal : candidates.first;
      } else {
        next = (candidates.contains(goal)) ? goal : candidates.firstWhereOrNull((c) => c.hazLevel <= minHaz);
        if (next == null && forceHaz) next = candidates.firstOrNull;
      }
      if (next == null) break;
      path.add(next);
      current = next;
    }

    return path;
  }



}