import 'dart:math';

import 'grid.dart';

abstract class PathGenerator2<T extends GridCell> {
  static void generate<T extends GridCell>(
      Grid<T> grid,
      int numPaths,
      int numRooms,
      Random rnd, {
        int roomRadius = 2,
        int pathWidth = 0,
      }) {

    for (int n=0;n<numPaths;n++) {
      for (int i = 0; i < numPaths; i++) {
        _forgePath(grid, rnd);
      }
    }
  }

  static int _forgePath<T extends GridCell>(Grid<T> grid,Random rnd, {width = 0}) {
    final edgeCells = grid.cells.entries.where((e) => e.value.coord.isEdge(grid.size));
    T start = edgeCells.elementAt(rnd.nextInt(edgeCells.length)).value;
    final endCells =  grid.getOppositeEdgeCells(start);
    T end = endCells.elementAt(rnd.nextInt(endCells.length));
    start.clearHazards();
    end.clearHazards();
    final path = grid.greedyPath(start, end, grid.size * 2, rnd, ignoreHaz: true);
    for (final s in path) s.clearHazards();
    return path.length;
  }


}