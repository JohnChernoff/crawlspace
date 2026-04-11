import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/geometry/impulse.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/galaxy/hazards.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_flutter/options.dart';
import 'package:flutter/material.dart';
import 'grid_viewport.dart';

enum MiniMapShape {
  rect,
  oval,
  dot,
  x,
}

class MiniMapCellStyle {
  final Color color;
  final MiniMapShape shape;
  final double scale; // 0..1ish

  const MiniMapCellStyle(
      this.color,
      this.shape, {
        this.scale = 1.0,
      });
}

class MiniMapWidget extends StatelessWidget {
  final FugueEngine fm;
  const MiniMapWidget(this.fm, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, bc) {
      final ship = fm.playerShip;
      if (ship == null) return const SizedBox.shrink();
      return CustomPaint(
        size: Size(bc.maxWidth, bc.maxHeight),
        painter: MiniMapPainter(fm, ship),
      );
    });
  }
}

class MiniMapPainter extends CustomPainter {
  final FugueEngine fm;
  final Ship ship;

  MiniMapPainter(this.fm, this.ship);

  @override
  void paint(Canvas canvas, Size size) {
    final dim = ship.loc.dim;
    final cellWidth = size.width / dim.mx;
    final cellHeight = size.height / dim.my;

    final bgPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bgPaint);

    for (int cx = 0; cx < dim.mx; cx++) {
      final x = cx * cellWidth;

      for (int cy = 0; cy < dim.my; cy++) {
        final y = cy * cellHeight;

        final style = cellStyle(cx, cy);
        final rect = Rect.fromLTWH(x, y, cellWidth, cellHeight);
        _paintMiniMapCell(canvas, rect, style);
      }
    }

    final viewport = GridViewport.centeredOn(
      center: ship.loc.cell.coord,
      mapDim: ship.loc.map.dim,
      width: kViewportWidth,
      height: kViewportHeight,
    );

    final viewportRect = Rect.fromLTWH(
      viewport.startX * cellWidth,
      viewport.startY * cellHeight,
      viewport.width * cellWidth,
      viewport.height * cellHeight,
    );

    final viewportPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(viewportRect, viewportPaint);
  }

  MiniMapCellStyle cellStyle(int x, int y) {
    final cell = ship.loc.map.atXYZ(x, y, 0);
    if (cell == null) {
      return const MiniMapCellStyle(Colors.black, MiniMapShape.rect);
    }

    if (ship.loc.cell.coord == cell.coord) {
      return const MiniMapCellStyle(Colors.blue, MiniMapShape.rect);
    }

    final ships = fm.galaxy.ships.atLocation(cell.loc);
    if (ships.isNotEmpty) {
      if (ships.any((s) => s.pilot.hostile)) {
        return const MiniMapCellStyle(Colors.red, MiniMapShape.rect);
      }
      return const MiniMapCellStyle(Colors.cyan, MiniMapShape.rect);
    }

    if (cell is SectorCell) {
      if (cell.hasStars(fm.galaxy)) {
        return const MiniMapCellStyle(Colors.yellow, MiniMapShape.oval);
      }
      if (cell.hasPlanets(fm.galaxy)) {
        return const MiniMapCellStyle(Colors.green, MiniMapShape.oval);
      }
      if (cell.hasBuoy) {
        return const MiniMapCellStyle(Colors.brown, MiniMapShape.oval);
      }
    }

    if (cell is ImpulseCell) {
      if (cell.hasStar(fm.galaxy)) {
        return const MiniMapCellStyle(Colors.yellow, MiniMapShape.oval);
      }
      if (cell.hasPlanet(fm.galaxy)) {
        return const MiniMapCellStyle(Colors.green, MiniMapShape.oval);
      }
      if (fm.galaxy.buoys.singleAtImpulse(cell.loc) != null) {
        return const MiniMapCellStyle(Colors.brown, MiniMapShape.oval);
      }
      if (cell.asteroid != null) {
        final mass = cell.asteroid!.mass;
        final scale = _asteroidScale(mass);
        return MiniMapCellStyle(Colors.grey, MiniMapShape.dot, scale: scale);
      }
    }

    if (cell.hazLevel > 0) {
      return MiniMapCellStyle(_hazColor(cell), MiniMapShape.x);
    }

    return const MiniMapCellStyle(Colors.black, MiniMapShape.rect);
  }

  double _asteroidScale(double mass) {
    final t = (mass / Asteroid.maxMass).clamp(0.0, 1.0);
    return 0.35 + (t * 0.65);
  }

  Color _hazColor(GridCell cell) {
    double total = 0;
    double r = 0;
    double g = 0;
    double b = 0;

    for (final entry in cell.hazMap.entries) {
      final hazard = entry.key;
      final strength = entry.value;

      if (strength <= 0 || hazard == Hazard.wake) continue;

      final c = hazard.color;
      r += c.r * strength;
      g += c.g * strength;
      b += c.b * strength;
      total += strength;
    }

    if (total <= 0) return Colors.black;

    final mixed = Color.fromARGB(
      255,
      (r / total).round().clamp(0, 255),
      (g / total).round().clamp(0, 255),
      (b / total).round().clamp(0, 255),
    );

    final strength = cell.hazLevel.clamp(0.0, 1.0);
    return Color.lerp(Colors.black, mixed, strength)!;
  }

  void _paintMiniMapCell(
      Canvas canvas,
      Rect rect,
      MiniMapCellStyle style,
      ) {
    switch (style.shape) {
      case MiniMapShape.rect:
        if (style.color == Colors.black) return;
        final paint = Paint()
          ..color = style.color
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, paint);
        break;

      case MiniMapShape.oval:
        final paint = Paint()
          ..color = style.color
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          rect.deflate(rect.shortestSide * 0.15),
          paint,
        );
        break;

      case MiniMapShape.dot:
        final paint = Paint()
          ..color = style.color
          ..style = PaintingStyle.fill;
        final radius = rect.shortestSide * 0.1 * style.scale.clamp(0.3, 1.2);
        canvas.drawCircle(rect.center, radius, paint);
        break;

      case MiniMapShape.x:
        final stroke = Paint()
          ..color = style.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        final inset = rect.shortestSide * 0.2;
        canvas.drawLine(
          Offset(rect.left + inset, rect.top + inset),
          Offset(rect.right - inset, rect.bottom - inset),
          stroke,
        );
        canvas.drawLine(
          Offset(rect.right - inset, rect.top + inset),
          Offset(rect.left + inset, rect.bottom - inset),
          stroke,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant MiniMapPainter oldDelegate) {
    return oldDelegate.fm.auTick != fm.auTick ||
        oldDelegate.ship.loc != ship.loc;
  }
}
