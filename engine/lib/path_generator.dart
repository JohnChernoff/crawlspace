import 'dart:math';
import 'grid.dart';

/// Generates safe paths and rooms through a 3D grid by clearing hazards
/// along paths and in room clusters.
abstract class PathGenerator {
  /// Main entry point: creates paths and rooms in a grid
  ///
  /// Clears hazards from paths connecting start/end points and from
  /// room clusters (safe zones for ships to gather).
  static void generatePathsAndRooms<T extends GridCell>(
      Grid<T> grid,
      int numPaths,
      int numRooms,
      Random rnd, {
        int roomRadius = 2,
        int pathWidth = 0,
      }) {
    // Create rooms first (they're smaller, won't conflict as much)
    for (int i = 0; i < numRooms; i++) {
      _createRoom(grid, rnd, roomRadius: roomRadius);
    }

    // Create paths connecting different regions of the grid
    for (int i = 0; i < numPaths; i++) {
      _createPath(grid, rnd, pathWidth: pathWidth);
    }
  }

  /// Creates a single room: a spherical safe zone in 3D space
  /// Clears hazards from the room center and a radius around it
  static void _createRoom<T extends GridCell>(
      Grid<T> grid,
      Random rnd, {
        int roomRadius = 2,
      }) {
    final roomCenter = grid.rndCell(rnd);
    final cellsInRoom = grid.getAdjacentCells(roomCenter, distance: roomRadius);

    for (final cell in cellsInRoom) {
      cell.clearHazards();
    }
  }

  /// Creates a single path: a corridor of safe cells connecting two points
  /// Uses greedy pathfinding to create a natural-looking route with minimal hazards.
  static void _createPath<T extends GridCell>(
      Grid<T> grid,
      Random rnd, {
        int pathWidth = 1,
      }) {
    // Pick a random start and goal
    final start = grid.rndCell(rnd);
    final goal = grid.rndCell(rnd);

    if (start == goal) return;

    // Use greedy pathfinding to find a low-hazard route
    final path = grid.greedyPath(start, goal, grid.size * 2, rnd, minHaz: 0);

    // Clear hazards along the path with a certain width
    for (final cell in path) {
      _clearCellAndNeighbors(grid, cell, pathWidth);
    }
  }

  /// Helper: clears a cell and its neighbors up to a certain distance
  static void _clearCellAndNeighbors<T extends GridCell>(
      Grid<T> grid,
      T cell,
      int distance,
      ) {
    final cellsToClean = grid.getAdjacentCells(cell, distance: distance);
    for (final c in cellsToClean) {
      c.clearHazards();
    }
    cell.clearHazards();
  }
}

/// ============================================================================
/// ALTERNATIVE APPROACH: More Sophisticated Path Generation
/// ============================================================================
///
/// If you want more control (e.g., longer paths, specific start/end zones),
/// use this expanded version:

abstract class AdvancedPathGenerator {
  /// Generates paths and rooms with more control over structure
  ///
  /// Parameters:
  /// - roomCount: number of safe zone clusters
  /// - pathCount: number of corridors connecting regions
  /// - minPathLength: prefer paths of at least this length
  /// - pathWidthRange: vary corridor width between min/max for visual interest
  static void generateWithControl<T extends GridCell>(
      Grid<T> grid,
      int roomCount,
      int pathCount,
      Random rnd, {
        int roomRadius = 2,
        int minPathLength = 5,
        int pathWidthMin = 1,
        int pathWidthMax = 2,
      }) {
    // Store room locations to avoid overlapping them
    final Set<T> roomCells = {};

    // Create rooms at strategic locations
    for (int i = 0; i < roomCount; i++) {
      final room = _createSmartRoom(grid, rnd, roomCells, roomRadius: roomRadius);
      roomCells.addAll(room);
    }

    // Create paths, preferring longer routes
    int pathsCreated = 0;
    int attempts = 0;
    const maxAttempts = 100;

    while (pathsCreated < pathCount && attempts < maxAttempts) {
      attempts++;
      final pathWidth = rnd.nextInt(pathWidthMax - pathWidthMin + 1) + pathWidthMin;
      final pathLength = _createSmartPath(
        grid,
        rnd,
        roomCells,
        minLength: minPathLength,
        pathWidth: pathWidth,
      );

      if (pathLength >= minPathLength) {
        pathsCreated++;
      }
    }
  }

  /// Creates a room avoiding other rooms
  static List<T> _createSmartRoom<T extends GridCell>(
      Grid<T> grid,
      Random rnd,
      Set<T> existingRoomCells, {
        int roomRadius = 2,
        int maxAttempts = 20,
      }) {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final center = grid.rndCell(rnd);
      final cellsInRoom = grid.getAdjacentCells(center, distance: roomRadius);

      // Check if room overlaps with existing rooms too much
      final overlap = cellsInRoom.where((c) => existingRoomCells.contains(c)).length;
      if (overlap == 0) {
        // No overlap, clear this room
        for (final cell in cellsInRoom) {
          cell.clearHazards();
        }
        cellsInRoom.add(center);
        return cellsInRoom;
      }
    }

    // Fallback: just create a room anyway
    final center = grid.rndCell(rnd);
    final cells = grid.getAdjacentCells(center, distance: roomRadius);
    for (final cell in cells) {
      cell.clearHazards();
    }
    cells.add(center);
    return cells;
  }

  /// Creates a path that tries to be at least minLength long
  /// Returns the actual path length achieved
  static int _createSmartPath<T extends GridCell>(
      Grid<T> grid,
      Random rnd,
      Set<T> roomCells, {
        int minLength = 5,
        int pathWidth = 1,
      }) {
    // Pick start and goal that are reasonably far apart
    T start = grid.rndCell(rnd);
    T goal = grid.rndCell(rnd);

    // Try to find a start/goal pair at least minLength apart
    int attempts = 0;
    while (start == goal && attempts < 10) {
      start = grid.rndCell(rnd);
      goal = grid.rndCell(rnd);
      final dist = start.coord.distance(goal.coord);
      if (dist >= minLength) break;
      attempts++;
    }

    // Find path with some noise to avoid straight corridors
    final path = grid.greedyPath(start, goal, grid.size * 2, rnd, minHaz: 1);

    // Clear the path
    for (final cell in path) {
      _clearCellAndNeighbors(grid, cell, pathWidth);
    }

    return path.length;
  }

  static void _clearCellAndNeighbors<T extends GridCell>(
      Grid<T> grid,
      T cell,
      int distance,
      ) {
    final cellsToClean = grid.getAdjacentCells(cell, distance: distance);
    for (final c in cellsToClean) {
      c.clearHazards();
    }
    cell.clearHazards();
  }
}
