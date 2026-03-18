import 'package:crawlspace_engine/controllers/movement_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/ship/nav.dart';
import 'package:flutter/material.dart';
import 'ascii_grid_painter.dart';

class AsciiGridFast extends StatelessWidget {
  final FugueEngine fugueModel;
  const AsciiGridFast(this.fugueModel, {super.key});

  @override
  Widget build(BuildContext context) {
    MovementPreview? preview;
    final fm = fugueModel;
    final ship = fm.playerShip;

    if (fm.inputMode == InputMode.movementTarget &&
        ship != null &&
        fm.player.targetLoc != null) {
      preview = ship.nav.movePreviewer.previewFixedStep(
        state: NavState.fromShip(ship),
        ctx: MoveContext.fromShip(ship),
        desiredCell: fm.player.targetLoc!.cell,
        selecting: true,
      );
    }

    return LayoutBuilder(
      builder: (context, bc) {
        return CustomPaint(
          size: Size(bc.maxWidth, bc.maxHeight),
          painter: AsciiGridPainter(
            fm: fm,
            preview: preview,
            showAllCellsOnZPlane: fm.scannerController.showAllCellsOnZPlane,
          ),
        );
      },
    );
  }
}
