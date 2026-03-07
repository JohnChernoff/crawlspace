import 'dart:math';

import 'package:crawlspace_engine/galaxy/hazards.dart';

import 'galaxy/geometry/grid.dart';

abstract class PathGenerator<T extends GridCell> {
  static void generate<T extends GridCell>(
      Grid<T> grid,
      int numPaths,
      int numRooms,
      Random rnd, {
        Hazard? haz,
        int roomRadius = 2,
        int pathWidth = 0,
      }) {

    for (int n=0;n<numPaths;n++) {
      for (int i = 0; i < numPaths; i++) {
        _forgePath(grid, rnd, haz: haz);
      }
    }
  }

  static int _forgePath<T extends GridCell>(Grid<T> grid,Random rnd, {width = 0, Hazard? haz}) {
    final edgeCells = grid.cells.entries.where((e) => e.value.coord.isEdge(grid.size));
    T start = edgeCells.elementAt(rnd.nextInt(edgeCells.length)).value;
    final endCells =  grid.getOppositeEdgeCells(start);
    T end = endCells.elementAt(rnd.nextInt(endCells.length));
    clearHazards(start,haz);
    clearHazards(end,haz);
    final path = grid.greedyPath(start, end, grid.size * 2, rnd, ignoreHaz: true);
    for (final s in path) clearHazards(s,haz);
    return path.length;
  }

  static void clearHazards<T extends GridCell>(T grid, Hazard? haz) {
    if (haz != null) grid.clearHazard(haz); else grid.clearHazards();
  }


}