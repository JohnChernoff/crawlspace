import 'dart:math';
import 'dart:ui' as ui;
import 'package:crawlspace_engine/controllers/movement_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/geometry/impulse.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/galaxy/hazards.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:flutter/material.dart';
import '../../../options.dart';
import 'lerp_field.dart';

//TODO: remove target when not targeting

class AsciiGridPainter extends CustomPainter {
  final FugueEngine fm;
  final MovementPreview? preview;
  final bool showAllCellsOnZPlane;
  final Coord3D? ghostCoord;
  final GravityFieldTexture? gravityTexture;
  final bool smoothG;
  final bool hands;

  AsciiGridPainter({
    required this.fm,
    required this.preview,
    required this.showAllCellsOnZPlane,
    required this.gravityTexture,
    this.ghostCoord,
    this.smoothG = true,
    this.hands = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ship = fm.playerShip;
    if (ship == null) return;

    final targetPath = fm.scannerController.targetPath;
    final targetPathCoords = targetPath.map((c) => c.coord).toSet();
    final targetLoc = fm.player.targetLoc;
    final scanSelection = fm.scannerController.currentScanSelection;
    final playerZ = ship.loc.cell.coord.z;
    final map = ship.loc.map;
    final dim = map.dim;
    final is2D = map.dim.mz == 1;
    final cellW = size.width / dim.mx;
    final cellH = size.height / dim.my;
    final layerSize = is2D ? cellH : cellH / 2;
    final paint = Paint();
    final projectedPath = ship.nav.projectedPath(4).toSet();


    if (is2D && gravityTexture != null && smoothG) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: gravityTexture!.image,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
    }

    for (int y = 0; y < dim.my; y++) {
      for (int x = 0; x < dim.mx; x++) {
        final baseRect = Rect.fromLTWH(x * cellW, y * cellH, cellW, cellH);

        if (!smoothG) {
          paint.color = Colors.black;
          canvas.drawRect(baseRect, paint);
        }

        final visibleCells = _visibleCellsAtXY(map, x, y, ship);
        for (final entry in visibleCells) {
          final cell = entry.cell;
          final z = cell.coord.z;
          final t = dim.mz <= 1 ? 0.0 : z / (dim.mz - 1);
          final stackXInset = 4; //cellW * 0.04;
          final zLiftPerLayer = 1; //max(1.0, cellH * 0.015);
          final dx = is2D ?  baseRect.left + cellW/2 : baseRect.left - stackXInset + (cellW - layerSize) * t;
          final dy = baseRect.top - (cell.coord.z * zLiftPerLayer) + (cellH - layerSize) * t;
          final state = _renderStateForCell(cell, fm, ship, targetPathCoords, projectedPath, targetLoc?.cell,scanSelection,playerZ);
          final glyph = _glyphForCell(cell, ship);
          final color = _colorForCell(cell, ship, state, is2D: is2D);
          final fontSize = _fontSizeForCell(layerSize, z, dim);

          final layerRect = is2D
              ? baseRect
              : Rect.fromLTWH(dx, dy, layerSize, layerSize);
          final grid = ship.loc.grid;
          if (!smoothG) {

            final map = ship.loc.map;
            _paintCellBackground(canvas,layerRect,color: _bkgColorForCell(grid,cell));
            (canvas, layerRect, ship.loc.grid.gravDirectionAt(cell.coord));
          } else if (hands) {
            final sx = x + 0.5;
            final sy = y + 0.5;
            final v = GravityFieldTexture.sampleVector(grid, sx, sy);
            final heat = GravityFieldTexture.sampleHeat(grid, sx, sy);
            _drawGravityHand(canvas, baseRect, v, heat);
          }

          final paragraph = _getParagraph(glyph, color, fontSize);
          canvas.drawParagraph(paragraph, Offset(dx, dy));

          if (state.uiTarget || state.inShipPath) {
            _paintTargetMarker(canvas, layerRect, fontSize);
          }

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
      if (cell.hasStars(fm.galaxy)) return "✦";
      if (cell.blackHole) return "-";
    }

    if (cell is ImpulseCell) {
      if (cell.hasPlanet(fm.galaxy)) return "O";
      if (cell.hasStar(fm.galaxy)) return "✦";
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

  Color _bkgColorForCell(Grid grid, GridCell cell) { //final h = sqrt(normalized); // instead of just normalized
    final h = grid.gravHeatMap[cell.coord] ?? 0; //print(h);
    return Color.lerp(Colors.black,Colors.lightGreenAccent, h)!;
  }

  void _drawGravityHand(Canvas canvas, Rect rect, Vec3 v, double heat) {
    final mag = v.mag;
    if (mag < 0.0001) return;

    final dir = v.normalized;
    final center = rect.center;

    final length = rect.width * (0.12 + 0.22 * heat.clamp(0.0, 1.0));

    final end = Offset(
      center.dx + dir.x * length,
      center.dy + dir.y * length,
    );

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, end, paint);
  }

  Color _colorForCell(
      GridCell cell,
      Ship player,
      _CellRenderState state,
      { required bool is2D }) {
    final ships = fm.galaxy.ships.atCell(cell);

    if (state.selected) {
      return state.sameDepthAndNotEmpty ? scanDepthColor : scanColor;
    }

    // Player ship
    for (final s in ships) {
      if (!s.npc) return shipColor;
    }

    if (state.sameDepthAndNotEmpty) {
      return Colors.white; //depthColor;
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
    final proximity = ((1.0 - (dist / dim.maxDist).clamp(0, 1)) * 8).round() / 8;
    return Color.lerp(farColor, nearColor, proximity)!;
  }

  double _fontSizeForCell(double baseSize, int z, GridDim dim) {
    final maxZ = max(1, dim.mz - 1);
    final t = sqrt(z / maxZ);

    final depthFactor = 0.6 + 0.6 * t;

    return max(baseSize * depthFactor, baseSize * 0.45);
  }

  void _paintCellBackground(
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
    final key = "$glyph-${color.toARGB32()}-$fontSize";
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
    return oldDelegate.preview != preview ||
        oldDelegate.ghostCoord != ghostCoord ||
        oldDelegate.fm.auTick != fm.auTick; // only repaint on game tick
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
  final bool inShipPath;
  final bool uiTarget;
  final bool sameDepth;
  final bool sameDepthAndNotEmpty;

  const _CellRenderState({
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
}

_CellRenderState _renderStateForCell(
    GridCell cell,
    FugueEngine fm,
    Ship player,
    Set<Coord3D> targetPathCoords,
    Set<Coord3D> shipPathCoords,
    GridCell? targetCell,      // precomputed targetLoc?.cell
    GridCell? scanSelection,   // precomputed currentScanSelection
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
          (cell is ImpulseCell && (cell.hasPlanet(fm.galaxy) || fm.galaxy.items.anyAt(cell.loc))) ||
          (cell is SectorCell && (cell.hasPlanets(fm.galaxy) || cell.hasStars(fm.galaxy) || cell.blackHole))
  );
  final uiTarget = targeted; // or separate this if you distinguish cursor vs final target

  return _CellRenderState(
    scanned: scanned,
    targeted: targeted,
    inTargetPath: inTargetPath,
    inShipPath: inShipPath,
    uiTarget: uiTarget,
    sameDepth: sameDepth,
    sameDepthAndNotEmpty: sameDepthAndNotEmpty,
  );
}

/*
  double _opacityForZ(int z, GridDim dim) { //apply to Paint.alpha
    final maxZ = max(1, dim.mz - 1);
    final t = sqrt(z / maxZ);
    return 0.55 + 0.45 * t;
  }
 */