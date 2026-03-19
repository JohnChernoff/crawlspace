import 'dart:math';
import 'dart:ui' as ui;
import 'package:crawlspace_engine/controllers/movement_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/geometry/impulse.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/galaxy/hazards.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:flutter/material.dart';
import '../../../options.dart';

//TODO: remove target when not targeting

class AsciiGridPainter extends CustomPainter {
  final FugueEngine fm;
  final MovementPreview? preview;
  final bool showAllCellsOnZPlane;

  AsciiGridPainter({
    required this.fm,
    required this.preview,
    required this.showAllCellsOnZPlane,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ship = fm.playerShip;
    if (ship == null) return;

    final map = ship.loc.map;
    final dim = map.dim;

    final cellW = size.width / dim.mx;
    final cellH = size.height / dim.my;
    final layerSize = cellH / 2;

    final paint = Paint();

    for (int y = 0; y < dim.my; y++) {
      for (int x = 0; x < dim.mx; x++) {
        final baseRect = Rect.fromLTWH(x * cellW, y * cellH, cellW, cellH);

        paint.color = Colors.black;
        canvas.drawRect(baseRect, paint);

        final visibleCells = _visibleCellsAtXY(map, x, y, ship);
        for (final entry in visibleCells) {
          final cell = entry.cell;
          final z = cell.coord.z;
          final t = dim.mz <= 1 ? 0.0 : z / (dim.mz - 1);
          //final tRaw = dim.mz <= 1 ? 0.0 : z / (dim.mz - 1);
          //final t = pow(tRaw, 0.9); // tweak this
          final stackXInset = 4; //cellW * 0.04;
          final zLiftPerLayer = 1; //max(1.0, cellH * 0.015);
          final dx = baseRect.left - stackXInset + (cellW - layerSize) * t;
          final dy = baseRect.top - (cell.coord.z * zLiftPerLayer) + (cellH - layerSize) * t;

          final state = _renderStateForCell(cell, fm, ship);
          final glyph = _glyphForCell(cell, ship);
          final color = _colorForCell(cell, ship, state);
          final fontSize = _fontSizeForCell(layerSize, z, dim);
          //final fontSize = _fontSizeForCell(effectiveLayerSize * 0.9, z, dim);

          final paragraph = _getParagraph(glyph, color, fontSize);
          canvas.drawParagraph(paragraph, Offset(dx, dy));

          if (state.uiTarget) {
            _paintTargetMarker(canvas, Rect.fromLTWH(dx, dy, layerSize, layerSize), fontSize);
          }

          final layerRect = Rect.fromLTWH(dx, dy, layerSize, layerSize);
          if (state.inTargetPath) {
            _paintCellOutline(
              canvas,
              layerRect,
              color: Colors.white,
              strokeWidth: 1.5,
            );
          }

          if (state.targeted) {
            _paintCellOutline(
              canvas,
              layerRect,
              color: Colors.redAccent,
              strokeWidth: 2.0,
            );
          }

          _paintGridBoundary(canvas, baseRect);
          //final layerRect = Rect.fromLTWH(dx, dy, layerSize, layerSize);
          //_paintGridBoundary(canvas, layerRect, color: const Color(0x22FFFFFF), strokeWidth: 0.5);
        }
      }
    }
  }

  String _glyphForCell(GridCell cell, Ship player) {
    final ships = fm.galaxy.ships.atCell(cell);

    // 1. Player ship
    for (final s in ships) {
      if (!s.npc) return "@";
    }

    // 2. NPC ships (if visible)
    for (final s in ships) {
      if (s.npc && player.canScan(cell)) {
        return s.pilot.faction.species.glyph;
      }
    }

    // 3. Effects
    if (cell.effects.anyActive) {
      return "#";
    }

    // 4. Hazards
    final hazards = cell.hazMap.entries
        .where((e) => e.value > 0 && e.key != Hazard.wake)
        .map((e) => e.key)
        .toList();

    if (hazards.isNotEmpty) {
      return _hazardGlyph(hazards);
    }

    // 5. Special cells
    if (cell is SectorCell) {
      if (cell.hasPlanets(fm.galaxy)) return "O";
      if (cell.starClass != null) return "✦";
      if (cell.blackHole) return "-";
    }

    if (cell is ImpulseCell) {
      if (cell.hasPlanet(fm.galaxy)) return "O";
      if (fm.galaxy.items.anyAt(cell.loc)) return "\$";
    }

    // 6. Empty
    return fm.playerShip?.loc.domain == Domain.impulse ? "." : " ";
  }

  void _paintTargetMarker(
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

  String _hazardGlyph(List<Hazard> hazards) {
    if (hazards.length == 1) return hazards.first.glyph;

    final h = hazards.toSet();

    if (h.contains(Hazard.nebula) && h.contains(Hazard.ion)) return '≈';
    if (h.contains(Hazard.nebula) && h.contains(Hazard.roid)) return '✱';
    if (h.contains(Hazard.ion) && h.contains(Hazard.roid)) return '%';
    if (h.contains(Hazard.gamma) && h.contains(Hazard.roid)) return '§';

    if (hazards.length >= 3) return '※';

    return hazards.first.glyph;
  }

  Color _colorForCell(
      GridCell cell,
      Ship player,
      _CellRenderState state,
      ) {
    final ships = fm.galaxy.ships.atCell(cell);

    if (state.selected) {
      return state.sameDepthAndNotEmpty ? scanDepthColor : scanColor;
    }

    // Player ship
    for (final s in ships) {
      if (!s.npc) return shipColor;
    }

    if (state.sameDepthAndNotEmpty) {
      return depthColor;
    }

    // NPC ships
    for (final s in ships) {
      if (s.npc && player.canScan(cell)) {
        return Color(s.pilot.faction.color.argb);
      }
    }

    // Effects
    if (cell.effects.anyActive) {
      final effect = cell.effects.allActive.first;
      return Color(effect.effectColor.argb);
    }

    // Hazards
    final hazards = cell.hazMap.entries
        .where((e) => e.value > 0 && e.key != Hazard.wake)
        .map((e) => e.key)
        .toList();

    if (hazards.isNotEmpty) {
      return Color(hazards.first.color.argb);
    }

    final dim = player.loc.map.dim;
    final dist = player.distanceFromLocation(cell.loc);
    final proximity = 1.0 - (dist / dim.maxDist).clamp(0, 1);

    return Color.lerp(farColor, nearColor, proximity)!;
  }

  double _fontSizeForCell(double baseSize, int z, GridDim dim) {
    final maxZ = max(1, dim.mz - 1);
    final t = sqrt(z / maxZ);

    final depthFactor = 0.6 + 0.6 * t;

    return max(baseSize * depthFactor, baseSize * 0.45);
  }

  double _opacityForZ(int z, GridDim dim) { //apply to Paint.alpha
    final maxZ = max(1, dim.mz - 1);
    final t = sqrt(z / maxZ);
    return 0.55 + 0.45 * t;
  }

  void _paintCellOutline(
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

  void _paintGridBoundary(
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

  final _paragraphCache = <String, ui.Paragraph>{};

  ui.Paragraph _getParagraph(String glyph, Color color, double fontSize) {
    final key = "$glyph-${color.value}-$fontSize";
    return _paragraphCache.putIfAbsent(key, () {
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          fontFamily: 'FixedSys',
          textAlign: TextAlign.center,
        ),
      )
        ..pushStyle(ui.TextStyle(color: color, fontSize: fontSize))
        ..addText(glyph);

      return builder.build()
        ..layout(ui.ParagraphConstraints(width: fontSize * 1.2));
    });
  }

  @override
  bool shouldRepaint(covariant AsciiGridPainter oldDelegate) {
    return true;
  }
}

class _PaintCell {
  final GridCell cell;
  _PaintCell(this.cell);
}

List<_PaintCell> _visibleCellsAtXY(
    CellMap map,
    int x,
    int y,
    Ship ship,
    ) {
  final dim = map.dim;
  final result = <_PaintCell>[];

  for (int z = 0; z < dim.mz; z++) {
    final cell = map.atXYZ(x, y, z);
    if (cell == null) continue;
    //TODO: add scanner logic
    //if (!cell.scannable(ScannerMode.active, ship.registry)) continue;
    result.add(_PaintCell(cell));
  }

  return result;
}

class _CellRenderState {
  final bool scanned;
  final bool targeted;
  final bool inTargetPath;
  final bool uiTarget;
  final bool sameDepth;
  final bool sameDepthAndNotEmpty;

  const _CellRenderState({
    this.scanned = false,
    this.targeted = false,
    this.inTargetPath = false,
    this.uiTarget = false,
    this.sameDepth = false,
    this.sameDepthAndNotEmpty = false,
  });

  bool get selected => scanned || targeted;
  bool get special => scanned || targeted || sameDepthAndNotEmpty;
}

_CellRenderState _renderStateForCell(
    GridCell cell,
    FugueEngine fm,
    Ship player,
    ) {
  final targetLoc = fm.player.targetLoc;
  final targetPath = fm.scannerController.targetPath;

  final scanned = fm.scannerController.currentScanSelection?.loc == cell.loc;
  final targeted = targetLoc?.cell == cell;
  final inTargetPath = targetPath.any((loc) => loc == cell);
  final uiTarget = targeted; // or separate this if you distinguish cursor vs final target
  final sameDepth = (cell.coord.z - player.loc.cell.coord.z).abs() == 0;
  final sameDepthAndNotEmpty = sameDepth && !cell.isEmpty(fm.galaxy);

  return _CellRenderState(
    scanned: scanned,
    targeted: targeted,
    inTargetPath: inTargetPath,
    uiTarget: uiTarget,
    sameDepth: sameDepth,
    sameDepthAndNotEmpty: sameDepthAndNotEmpty,
  );
}
