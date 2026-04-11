import 'dart:math';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';

class GridViewport {
  final int startX;
  final int startY;
  final int width;
  final int height;

  const GridViewport({
    required this.startX,
    required this.startY,
    required this.width,
    required this.height,
  });

  int get endX => startX + width - 1;
  int get endY => startY + height - 1;

  static GridViewport centeredOn({
    required Coord3D center,
    required GridDim mapDim,
    int width = 32,
    int height = 32,
  }) {
    final actualWidth = min(width, mapDim.mx);
    final actualHeight = min(height, mapDim.my);

    final maxStartX = max(0, mapDim.mx - actualWidth);
    final maxStartY = max(0, mapDim.my - actualHeight);

    final startX = (center.x - actualWidth ~/ 2).clamp(0, maxStartX);
    final startY = (center.y - actualHeight ~/ 2).clamp(0, maxStartY);

    return GridViewport(
      startX: startX,
      startY: startY,
      width: actualWidth,
      height: actualHeight,
    );
  }
}
