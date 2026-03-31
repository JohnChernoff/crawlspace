import 'package:crawlspace_engine/controllers/movement_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/ship/nav/move_ctx.dart';
import 'package:crawlspace_engine/ship/nav/nav.dart';
import 'package:flutter/material.dart';
import 'ascii_grid_painter.dart';
import 'lerp_field.dart';

class AsciiGridFast extends StatefulWidget {
  final FugueEngine fugueModel;
  const AsciiGridFast(this.fugueModel, {super.key});

  @override
  State<AsciiGridFast> createState() => _AsciiGridFastState();
}

class _AsciiGridFastState extends State<AsciiGridFast> {
  CellMap? _cachedMap;
  GravityFieldTexture? _gravityTexture;
  Future<void>? _pendingLoad;

  FugueEngine get fm => widget.fugueModel;

  @override
  void initState() {
    super.initState();
    _syncGravityTexture();
  }

  @override
  void didUpdateWidget(covariant AsciiGridFast oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGravityTexture();
  }

  Future<void> _syncGravityTexture() async {
    final ship = fm.playerShip;
    final map = ship?.loc.map;

    if (map == null) {
      if (_cachedMap != null || _gravityTexture != null) {
        setState(() {
          _cachedMap = null;
          _gravityTexture = null;
        });
      }
      return;
    }

    if (identical(map, _cachedMap)) return;

    _cachedMap = map;
    _gravityTexture = null;

    final load = GravityTextureCache.instance.get(map, pxPerCell: 20);
    _pendingLoad = load.then((texture) {
      if (!mounted) return;
      if (!identical(_cachedMap, map)) return;

      setState(() {
        _gravityTexture = texture;
      });
    });
    await _pendingLoad;
  }

  @override
  Widget build(BuildContext context) {
    _syncGravityTexture();

    MovementPreview? preview;
    final ship = fm.playerShip;

    final Coord3D? ghostCoord = ship == null
        ? null
        : Position(
      ship.nav.pos.x + ship.nav.vel.x,
      ship.nav.pos.y + ship.nav.vel.y,
      ship.nav.pos.z + ship.nav.vel.z,
    ).coord;

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
            ghostCoord: ghostCoord,
            showAllCellsOnZPlane: fm.scannerController.showAllCellsOnZPlane,
            gravityTexture: _gravityTexture,
          ),
        );
      },
    );
  }
}
