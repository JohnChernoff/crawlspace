import 'dart:math';

import 'package:crawlspace_engine/galaxy/hazards.dart';

import 'grid.dart';

abstract class PathGenerator<T extends GridCell> {
  static void generate<T extends GridCell>(
      MappedGrid<T> grid,
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

  static int _forgePath<T extends GridCell>(
      MappedGrid<T> grid,
      Random rnd, {
        int width = 0,
        Hazard? haz,
      }) {
    final edgeCells = grid.values.where((e) => e.coord.isEdge(grid.dim)).toList();
    final start = edgeCells[rnd.nextInt(edgeCells.length)];
    final endCells = grid.getOppositeEdgeCells(start);
    final end = endCells[rnd.nextInt(endCells.length)];

    clearHazards(start, haz);
    clearHazards(end, haz);

    final maxSteps = max(grid.dim.mx, max(grid.dim.my, grid.dim.mz)) * 2;
    final path = grid.greedyPath(start, end, maxSteps, rnd, ignoreHaz: true);

    for (final s in path) {
      clearHazards(s, haz);
    }

    return path.length;
  }

  static void clearHazards<T extends GridCell>(T grid, Hazard? haz) {
    if (haz != null) grid.clearHazard(haz); else grid.clearHazards();
  }


}