import 'dart:math';
import 'dart:ui' as ui;
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/geometry/impulse.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/galaxy/hazards.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:flutter/material.dart';

import '../../../options.dart';

class CellRenderer {
  FugueEngine fm;
  CellRenderer(this.fm);

  String glyphForCell(GridCell cell, Ship player) {
    final ships = fm.galaxy.ships.atCell(cell);

    for (final s in ships) {
      if (!s.npc) return "@";
    }

    for (final s in ships) {
      if (s.npc && player.canScan(cell)) {
        return s.pilot.faction.species.glyph;
      }
    }

    if (cell.effects.anyActive) {
      return "#";
    }

    final hazards = cell.hazMap.entries
        .where((e) => e.value > 0 && e.key != Hazard.wake)
        .map((e) => e.key)
        .toList();

    if (hazards.isNotEmpty) {
      return hazardGlyph(hazards);
    }

    if (cell is SectorCell) {
      if (cell.hasPlanets(fm.galaxy)) return "O";
      if (cell.hasStars(fm.galaxy)) return "✦";
      if (cell.hasBuoy) return "⊕";
      if (cell.blackHole) return "-";
    }

    if (cell is ImpulseCell) {
      if (cell.hasPlanet(fm.galaxy)) return "O";
      if (cell.hasStar(fm.galaxy)) return "✦";
      if (cell.asteroid != null) return "+";
      if (fm.galaxy.buoys.singleAtImpulse(cell.loc) != null) return "⊕";
      if (fm.galaxy.items.byLoc(cell.loc).isNotEmpty) return "\$";
      if (fm.galaxy.slugs.inImpulse(cell.loc).isNotEmpty) return "*";
    }

    return fm.playerShip?.loc.domain == Domain.orbital ? "." : " ";
  }

  String hazardGlyph(List<Hazard> hazards) {
    if (hazards.length == 1) return hazards.first.glyph;

    final h = hazards.toSet();

    if (h.contains(Hazard.nebula) && h.contains(Hazard.ion)) return '≈';
    if (h.contains(Hazard.nebula) && h.contains(Hazard.roid)) return '✱';
    if (h.contains(Hazard.ion) && h.contains(Hazard.roid)) return '%';
    if (h.contains(Hazard.gamma) && h.contains(Hazard.roid)) return '§';

    if (hazards.length >= 3) return '※';

    return hazards.first.glyph;
  }

  void paintTargetMarker(
      Canvas canvas,
      Rect rect,
      double fontSize,
      ) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontFamily: 'FixedSys'),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: fontSize,
      ))
      ..addText("X");

    final p = pb.build()
      ..layout(ui.ParagraphConstraints(width: rect.width));

    canvas.drawParagraph(p, Offset(rect.left, rect.top));
  }

  Color bkgColorForCell(Grid grid, GridCell cell) {
    final h = grid.gravHeatMap[cell.coord] ?? 0;
    return Color.lerp(Colors.black, Colors.lightGreenAccent, h)!;
  }

  void drawGravityHand(Canvas canvas, Rect rect, Vec3 v, double heat) {
    final mag = v.mag;
    if (mag < 0.0001 || heat < .2) return;

    final dir = v.normalized;
    final center = rect.center;
    final side = rect.shortestSide / 2;
    final length = max(side / 2, (side * heat.clamp(0.01, 1.0)));
    final angle = atan2(dir.y, dir.x);
    final headLen = side / 2;
    final end = Offset(
      center.dx + dir.x * length,
      center.dy + dir.y * length,
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    if (length > headLen) {
      canvas.drawLine(center, end, paint);
    }

    const headAngle = 0.4;
    final head1 = Offset(
      end.dx - headLen * cos(angle - headAngle),
      end.dy - headLen * sin(angle - headAngle),
    );
    final head2 = Offset(
      end.dx - headLen * cos(angle + headAngle),
      end.dy - headLen * sin(angle + headAngle),
    );

    canvas.drawLine(end, head1, paint);
    canvas.drawLine(end, head2, paint);
  }

  Color colorForCell(
      GridCell cell,
      Ship pShip,
      CellRenderState state,
      { required bool is2D }) {
    final ships = fm.galaxy.ships.atCell(cell);

    if (state.selected) {
      return state.sameDepthAndNotEmpty ? scanDepthColor : scanColor;
    }

    final loc = cell.loc; if (loc is ImpulseLocation) {
      if (fm.galaxy.slugs.inImpulse(loc).isNotEmpty) {
        return Color(fm.galaxy.slugs.inImpulse(loc).first.objColor.argb);
      }
    }

    for (final s in ships) {
      if (!s.npc) return shipColor;
    }

    if (cell is SectorCell && cell.hasPlanets(fm.galaxy)) {
      return Color(cell.planets(fm.galaxy).first.environment.color.argb);
    }

    if (state.sameDepthAndNotEmpty) {
      return Colors.white;
    }

    for (final s in ships) {
      if (s.npc && pShip.canScan(cell)) {
        return Color(s.pilot.faction.color.argb);
      }
    }

    if (cell.effects.anyActive) {
      final effect = cell.effects.allActive.first;
      return Color(effect.effectColor.argb);
    }

    final hazards = cell.hazMap.entries
        .where((e) => e.value > 0 && e.key != Hazard.wake)
        .map((e) => e.key)
        .toList();

    if (hazards.isNotEmpty) {
      return Color(hazards.first.color.argb);
    }

    final dim = pShip.loc.map.dim;
    final dist = pShip.distanceFromLocation(cell.loc);
    final proximity = ((1.0 - (dist / dim.maxDist).clamp(0, 1)) * 8).round() / 8;
    return Color.lerp(farColor, nearColor, proximity)!;
  }

  double fontSizeForCell(double baseSize, int z, GridDim dim) {
    final maxZ = max(1, dim.mz - 1);
    final t = sqrt(z / maxZ);

    final depthFactor = 0.6 + 0.6 * t;

    return max(baseSize * depthFactor, baseSize * 0.45);
  }

  void paintCellBackground(
      Canvas canvas,
      Rect rect, {
        required Color color,
        double strokeWidth = 1.0,
      }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect.deflate(strokeWidth / 2), paint);
  }

  void paintCellOutline(
      Canvas canvas,
      Rect rect, {
        required Color color,
        double strokeWidth = 1.0,
      }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRect(rect.deflate(strokeWidth / 2), paint);
  }

  void paintGridBoundary(
      Canvas canvas,
      Rect rect, {
        Color color = const Color(0x33FFFFFF),
        double strokeWidth = 0.5,
      }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRect(rect, paint);
  }

  ui.Paragraph buildParagraph(String glyph, Color color, double fontSize) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: 'JetBrains Mono',
        textAlign: TextAlign.left,
        maxLines: 1,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
      ))
      ..addText(glyph);

    final p = builder.build();
    p.layout(const ui.ParagraphConstraints(width: 1000));
    return p;
  }
}

class CellRenderState {
  final bool scanned;
  final bool targeted;
  final bool inTargetPath;
  final bool inShipPath;
  final bool uiTarget;
  final bool sameDepth;
  final bool sameDepthAndNotEmpty;

  const CellRenderState({
    this.scanned = false,
    this.targeted = false,
    this.inTargetPath = false,
    this.inShipPath = false,
    this.uiTarget = false,
    this.sameDepth = false,
    this.sameDepthAndNotEmpty = false,
  });

  bool get selected => scanned || targeted;
  bool get special => scanned || targeted || sameDepthAndNotEmpty;

  factory CellRenderState.forCell(
      GridCell cell,
      FugueEngine fm,
      Ship player,
      Set<Coord3D> targetPathCoords,
      Set<Coord3D> shipPathCoords,
      GridCell? targetCell,
      GridCell? scanSelection,
      int playerZ,
      ) {
    final scanned = scanSelection?.loc == cell.loc;
    final targeted = targetCell == cell;
    final inTargetPath = targetPathCoords.contains(cell.coord);
    final inShipPath = shipPathCoords.contains(cell.coord);
    final sameDepth = (cell.coord.z - playerZ).abs() == 0;
    final sameDepthAndNotEmpty = sameDepth && (
        cell.hazLevel > 0 ||
            fm.galaxy.ships.atCell(cell).isNotEmpty ||
            (cell is ImpulseCell && (cell.hasPlanet(fm.galaxy) || fm.galaxy.items.byLoc(cell.loc).isNotEmpty)) ||
            (cell is SectorCell && (cell.hasPlanets(fm.galaxy) || cell.hasStars(fm.galaxy) || cell.blackHole))
    );
    final uiTarget = targeted;

    return CellRenderState(
      scanned: scanned,
      targeted: targeted,
      inTargetPath: inTargetPath,
      inShipPath: inShipPath,
      uiTarget: uiTarget,
      sameDepth: sameDepth,
      sameDepthAndNotEmpty: sameDepthAndNotEmpty,
    );
  }
}

