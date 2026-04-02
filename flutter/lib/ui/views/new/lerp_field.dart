import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:flutter/material.dart';

class GravityFieldTexture {
  final ui.Image image;
  final int pxPerCell;

  GravityFieldTexture(this.image, {this.pxPerCell = 8});

  static Future<GravityFieldTexture> build(
      Grid grid, {
        int pxPerCell = 8,
        bool showDir = false,
        bkgCol = Colors.black, fgCol = Colors.red,
        Color Function(double heat, Color bkgCol, Color fgCol)? colorForHeat,
      }) async {
    final width = grid.map.dim.mx * pxPerCell;
    final height = grid.map.dim.my * pxPerCell;
    final rgba = Uint8List(width * height * 4);

    final colorFn = colorForHeat ?? _defaultColorForHeat;

    for (int py = 0; py < height; py++) {
      for (int px = 0; px < width; px++) {
        final Color color;
        if (showDir) {
          final sx = px / pxPerCell;
          final sy = py / pxPerCell;

          // fractional position within cell (-0.5 to 0.5)
          final fx = (px % pxPerCell) / pxPerCell - 0.5;
          final fy = (py % pxPerCell) / pxPerCell - 0.5;

          final v = sampleVector(grid, sx, sy);
          final dir = v.mag > 0.001 ? v.normalized : Vec3(0, 0, 0);

          // how far along the gravity direction is this pixel within its cell?
          final directional = (fx * dir.x + fy * dir.y).clamp(-0.5, 0.5);

          final heat = sampleHeat(grid, sx, sy);
          final adjustedHeat = (heat + (directional * sqrt(heat))).clamp(0.0, 1.0);

          color = colorFn(adjustedHeat, bkgCol, fgCol);
        } else {
          final sx = px / pxPerCell;
          final sy = py / pxPerCell;

          final heat = sampleHeat(grid, sx, sy); //final v = sampleVector(map, sx, sy);
          color = colorFn(heat.clamp(0.0, 1.0),bkgCol,fgCol);
        }

        final off = (py * width + px) * 4;
        rgba[off] = (color.r * 255).round() & 0xff;
        rgba[off + 1] = (color.g * 255).round() & 0xff;
        rgba[off + 2] = (color.b * 255).round() & 0xff;
        rgba[off + 3] = (color.a * 255).round() & 0xff;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    return GravityFieldTexture(image, pxPerCell: pxPerCell);
  }

  static Color _defaultColorForHeat(double h, Color bkgCol, Color fgCol) {
    return Color.lerp(bkgCol, fgCol, h.clamp(0.0, 1.0))!;
  }

  static Color _defaultDirectionalColorForHeat(double h, Vec3 v) {
    final angle = atan2(v.y, v.x);
    final hue = (angle / (2 * pi) * 360 + 360) % 360;
    //final hue = (angle / (2 * pi) * 120 + 60 + 360) % 360; // red→yellow→green
    final saturation = (h * 3).clamp(0, 1).toDouble();
    final value = (h * 3).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(1.0, hue, saturation,value).toColor();
  }

  static double sampleHeat(Grid grid, double sx, double sy) {
    final fx = sx - 0.5;
    final fy = sy - 0.5;

    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    final tx = fx - x0;
    final ty = fy - y0;

    final h00 = _heatAt(grid, x0, y0);
    final h10 = _heatAt(grid, x1, y0);
    final h01 = _heatAt(grid, x0, y1);
    final h11 = _heatAt(grid, x1, y1);

    final top = _lerp(h00, h10, tx);
    final bottom = _lerp(h01, h11, tx);
    return _lerp(top, bottom, ty);
  }

  static Vec3 sampleVector(Grid grid, double sx, double sy) {
    final fx = sx - 0.5;
    final fy = sy - 0.5;

    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    final tx = fx - x0;
    final ty = fy - y0;

    final v00 = _vecAt(grid, x0, y0);
    final v10 = _vecAt(grid, x1, y0);
    final v01 = _vecAt(grid, x0, y1);
    final v11 = _vecAt(grid, x1, y1);

    final top = Vec3(
      _lerp(v00.x, v10.x, tx),
      _lerp(v00.y, v10.y, tx),
      _lerp(v00.z, v10.z, tx),
    );

    final bottom = Vec3(
      _lerp(v01.x, v11.x, tx),
      _lerp(v01.y, v11.y, tx),
      _lerp(v01.z, v11.z, tx),
    );

    return Vec3(
      _lerp(top.x, bottom.x, ty),
      _lerp(top.y, bottom.y, ty),
      _lerp(top.z, bottom.z, ty),
    );
  }

  static double _heatAt(Grid grid, int x, int y) {
    final cx = x.clamp(0, grid.map.dim.mx - 1);
    final cy = y.clamp(0, grid.map.dim.my - 1);
    return grid.gravHeatMap[Coord3D(cx, cy, 0)] ?? 0.0;
  }

  static Vec3 _vecAt(Grid grid, int x, int y) {
    final cx = x.clamp(0, grid.map.dim.mx - 1);
    final cy = y.clamp(0, grid.map.dim.my - 1);
    return grid.gravAt(Coord3D(cx, cy, 0));
  }

  static double _lerp(double a, double b, double t) => a * (1 - t) + b * t;
}

class GravityTextureCache {
  static final GravityTextureCache instance = GravityTextureCache._();
  GravityTextureCache._();

  final Map<CellMap, Future<GravityFieldTexture>> _cache = {};

  Future<GravityFieldTexture> get(Grid grid, {int pxPerCell = 16}) {
    return _cache.putIfAbsent(
      grid.map,
          () => GravityFieldTexture.build(grid, pxPerCell: pxPerCell),
    );
  }

  void invalidate(CellMap map) {
    _cache.remove(map);
  }

  void clear() {
    _cache.clear();
  }
}
