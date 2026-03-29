import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:flutter/material.dart';

class GravityFieldTexture {
  final ui.Image image;
  final int pxPerCell;

  GravityFieldTexture(this.image, {this.pxPerCell = 16});

  static Future<GravityFieldTexture> build(
      CellMap map, {
        int pxPerCell = 16,
        bkgCol = Colors.black, fgCol = Colors.red,
        Color Function(double heat, Color bkgCol, Color fgCol)? colorForHeat,
      }) async {
    final width = map.dim.mx * pxPerCell;
    final height = map.dim.my * pxPerCell;
    final rgba = Uint8List(width * height * 4);

    final colorFn = colorForHeat ?? _defaultColorForHeat;

    for (int py = 0; py < height; py++) {
      for (int px = 0; px < width; px++) {
        final sx = px / pxPerCell;
        final sy = py / pxPerCell;

        final heat = sampleHeat(map, sx, sy);
        final color = colorFn(heat.clamp(0.0, 1.0),bkgCol,fgCol);

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

  static double sampleHeat(CellMap map, double sx, double sy) {
    final fx = sx - 0.5;
    final fy = sy - 0.5;

    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    final tx = fx - x0;
    final ty = fy - y0;

    final h00 = _heatAt(map, x0, y0);
    final h10 = _heatAt(map, x1, y0);
    final h01 = _heatAt(map, x0, y1);
    final h11 = _heatAt(map, x1, y1);

    final top = _lerp(h00, h10, tx);
    final bottom = _lerp(h01, h11, tx);
    return _lerp(top, bottom, ty);
  }

  static Vec3 sampleVector(CellMap map, double sx, double sy) {
    final fx = sx - 0.5;
    final fy = sy - 0.5;

    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    final tx = fx - x0;
    final ty = fy - y0;

    final v00 = _vecAt(map, x0, y0);
    final v10 = _vecAt(map, x1, y0);
    final v01 = _vecAt(map, x0, y1);
    final v11 = _vecAt(map, x1, y1);

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

  static double _heatAt(CellMap map, int x, int y) {
    final cx = x.clamp(0, map.dim.mx - 1);
    final cy = y.clamp(0, map.dim.my - 1);
    return map.gravHeatMap[Coord3D(cx, cy, 0)] ?? 0.0;
  }

  static Vec3 _vecAt(CellMap map, int x, int y) {
    final cx = x.clamp(0, map.dim.mx - 1);
    final cy = y.clamp(0, map.dim.my - 1);
    return map.gravAt(Coord3D(cx, cy, 0));
  }

  static double _lerp(double a, double b, double t) => a * (1 - t) + b * t;
}

class GravityTextureCache {
  static final GravityTextureCache instance = GravityTextureCache._();
  GravityTextureCache._();

  final Map<CellMap, Future<GravityFieldTexture>> _cache = {};

  Future<GravityFieldTexture> get(CellMap map, {int pxPerCell = 16}) {
    return _cache.putIfAbsent(
      map,
          () => GravityFieldTexture.build(map, pxPerCell: pxPerCell),
    );
  }

  void invalidate(CellMap map) {
    _cache.remove(map);
  }

  void clear() {
    _cache.clear();
  }
}
