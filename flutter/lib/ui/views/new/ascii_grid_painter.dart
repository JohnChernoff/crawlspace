import 'package:crawlspace_engine/controllers/movement_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ui_options.dart';
import 'package:crawlspace_flutter/ui/views/new/cell_renderer.dart';
import 'package:flutter/material.dart';
import 'grid_viewport.dart';
import 'lerp_field.dart';

//TODO: remove target when not targeting
class AsciiGridPainter extends CustomPainter {
  final FugueEngine fm;
  final MovementPreview? preview;
  final bool showAllCellsOnZPlane;
  final Coord3D? ghostCoord;
  final GravityFieldTexture? gravityTexture;
  final bool smoothG;
  final GridViewport? viewport;
  late final cr = CellRenderer(fm);

  AsciiGridPainter({
    required this.fm,
    required this.preview,
    required this.showAllCellsOnZPlane,
    required this.gravityTexture,
    required this.viewport,
    this.ghostCoord,
    this.smoothG = true,
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

    final vp = viewport ??
        GridViewport.centeredOn(
          center: ship.loc.cell.coord,
          mapDim: dim,
          width: dim.mx,
          height: dim.my,
        );

    final cellW = size.width / vp.width;
    final cellH = size.height / vp.height;
    final layerSize = is2D ? cellH : cellH / 2;
    final paint = Paint();
    final projectedPath = ship.nav.projectedPath(4,fm).toSet();

    if (is2D && gravityTexture != null && smoothG) {
      final ppc = gravityTexture!.pxPerCell.toDouble();

      final src = Rect.fromLTWH(
        vp.startX * ppc,
        vp.startY * ppc,
        vp.width * ppc,
        vp.height * ppc,
      );

      final dst = Offset.zero & size;

      canvas.drawImageRect(
        gravityTexture!.image,
        src,
        dst,
        paint,
      );
    }

    for (int sy = 0; sy < vp.height; sy++) {
      final y = vp.startY + sy;

      for (int sx = 0; sx < vp.width; sx++) {
        final x = vp.startX + sx;

        final baseRect = Rect.fromLTWH(
          sx * cellW,
          sy * cellH,
          cellW,
          cellH,
        );

        if (!smoothG) {
          paint.color = Colors.black;
          canvas.drawRect(baseRect, paint);
        }

        final visibleCells = _visibleCellsAtXY(map, x, y, ship);
        for (final entry in visibleCells) {
          final cell = entry.cell;
          final z = cell.coord.z;
          final t = dim.mz <= 1 ? 0.0 : z / (dim.mz - 1);
          final stackXInset = 4;
          final zLiftPerLayer = 1;
          final dx = is2D
              ? baseRect.left + cellW / 2
              : baseRect.left - stackXInset + (cellW - layerSize) * t;
          final dy = baseRect.top - (cell.coord.z * zLiftPerLayer) + (cellH - layerSize) * t;
          final state = CellRenderState.forCell(
            cell,
            fm,
            ship,
            targetPathCoords,
            projectedPath,
            targetLoc?.cell,
            scanSelection,
            playerZ,
          );
          final glyph = cr.glyphForCell(cell, ship);
          final color = cr.colorForCell(cell, ship, state, is2D: is2D);
          final fontSize = cr.fontSizeForCell(layerSize, z, dim);

          final layerRect = is2D
              ? baseRect
              : Rect.fromLTWH(dx, dy, layerSize, layerSize);
          final grid = ship.loc.grid;
          if (!smoothG) {
            cr.paintCellBackground(canvas, layerRect, color: cr.bkgColorForCell(grid, cell));
          } else if (fm.uiOptions.boolOptions[OptBool.vectorHands]!) {
            final wx = x + 0.5;
            final wy = y + 0.5;
            final texture = gravityTexture;
            if (texture != null) {
              final v = GravityFieldTexture.sampleVector(
                wx,
                wy,
                texture.mw,
                texture.mh,
                texture.vxGrid,
                texture.vyGrid,
              );
              final heat = GravityFieldTexture.sampleHeat(
                wx,
                wy,
                texture.mw,
                texture.mh,
                texture.heatGrid,
              );
              cr.drawGravityHand(canvas, baseRect, v, heat);
            }
          }

          cr.paintGridBoundary(canvas, baseRect);

          final paragraph = cr.buildParagraph(glyph, color, fontSize);
          final boxes = paragraph.getBoxesForRange(0, glyph.length);

          if (boxes.isNotEmpty) {
            final box = boxes.first.toRect();
            final cellCenter = baseRect.center;

            final px = cellCenter.dx - (box.left + box.width / 2);
            final py = cellCenter.dy - (box.top + box.height / 2);

            canvas.drawParagraph(paragraph, Offset(px, py));
          } else {
            canvas.drawParagraph(paragraph, baseRect.topLeft);
          }

          if (state.uiTarget || state.inShipPath) {
            cr.paintTargetMarker(canvas, layerRect, fontSize);
          }

          if (state.inTargetPath) {
            cr.paintCellOutline(
              canvas,
              layerRect,
              color: Colors.white,
              strokeWidth: 1.5,
            );
          }

          if (state.targeted) {
            cr.paintCellOutline(
              canvas,
              layerRect,
              color: Colors.redAccent,
              strokeWidth: 2.0,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant AsciiGridPainter oldDelegate) {
    return oldDelegate.preview != preview ||
        oldDelegate.ghostCoord != ghostCoord ||
        oldDelegate.viewport != viewport ||
        oldDelegate.fm.auTick != fm.auTick;
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
    result.add(_PaintCell(cell));
  }

  return result;
}
