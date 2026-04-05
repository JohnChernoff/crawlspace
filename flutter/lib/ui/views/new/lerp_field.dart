import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:flutter/material.dart';

class GravityFieldTexture {
  final ui.Image image;
  final Float64List heatGrid;
  final Float64List vxGrid;
  final Float64List vyGrid;
  final int mw;
  final int mh;

  GravityFieldTexture(this.image, this.heatGrid, this.vxGrid, this.vyGrid, this.mw, this.mh);

  static Future<GravityFieldTexture> build(
      Grid grid, {
        Color bkgCol = Colors.black,
        Color fgCol = Colors.red,
        Color Function(double heat, Color bkgCol, Color fgCol)? colorForHeat,
        Color Function(double heat, Vec3 v)? colorForVector,
      }) async {

    final mw = grid.map.dim.mx;
    final mh = grid.map.dim.my;
    final rgba = Uint8List(mw * mh * 4);

    final heatGrid = Float64List(mw * mh);
    final vxGrid = Float64List(mw * mh);
    final vyGrid = Float64List(mw * mh);

    for (int y = 0; y < mh; y++) {
      for (int x = 0; x < mw; x++) {
        final coord = Coord3D(x, y, 0);
        heatGrid[y * mw + x] = grid.gravHeatMap[coord] ?? 0.0;
        final v = grid.gravAt(coord);
        vxGrid[y * mw + x] = v.x;
        vyGrid[y * mw + x] = v.y;
      }
    }

    for (int cy = 0; cy < mh; cy++) {
      for (int cx = 0; cx < mw; cx++) {
        final i = cy * mw + cx;
        final heat = heatGrid[i];
        final off = i * 4;

        if (colorForVector != null) {
          final v = Vec3(vxGrid[i], vyGrid[i], 0);
          final color = colorForVector(heat, v);
          rgba[off]     = (color.r * 255).round() & 0xff;
          rgba[off + 1] = (color.g * 255).round() & 0xff;
          rgba[off + 2] = (color.b * 255).round() & 0xff;
          rgba[off + 3] = (color.a * 255).round() & 0xff;
        } else if (colorForHeat != null) {
          final color = colorForHeat(heat, bkgCol, fgCol);
          rgba[off]     = (color.r * 255).round() & 0xff;
          rgba[off + 1] = (color.g * 255).round() & 0xff;
          rgba[off + 2] = (color.b * 255).round() & 0xff;
          rgba[off + 3] = (color.a * 255).round() & 0xff;
        } else {
          _setColor(rgba, off, heat, bkgCol: bkgCol, fgCol: fgCol);
        }
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      mw,
      mh,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;

    return GravityFieldTexture(image, heatGrid, vxGrid, vyGrid, mw, mh);
  }

  static void _setColor(Uint8List rgba, int off, double heat,
      {Color bkgCol = Colors.black, Color fgCol = Colors.redAccent}) {
    rgba[off]     = ((bkgCol.r + (fgCol.r - bkgCol.r) * heat) * 255).round() & 0xff;
    rgba[off + 1] = ((bkgCol.g + (fgCol.g - bkgCol.g) * heat) * 255).round() & 0xff;
    rgba[off + 2] = ((bkgCol.b + (fgCol.b - bkgCol.b) * heat) * 255).round() & 0xff;
    rgba[off + 3] = ((bkgCol.a + (fgCol.a - bkgCol.a) * heat) * 255).round() & 0xff;
  }

  static Color directionalColor(double heat, Vec3 v) {
    final angle = atan2(v.y, v.x);
    final hue = (angle / (2 * pi) * 360 + 360) % 360;
    final saturation = (heat * 3).clamp(0.0, 1.0);
    final value = (heat * 3).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
  }

  static double sampleHeat(double sx, double sy, int mw, int mh, Float64List h) {
    final fx = sx - 0.5;
    final fy = sy - 0.5;
    final x0 = fx.floor();
    final y0 = fy.floor();
    final tx = fx - x0;
    final ty = fy - y0;

    final h00 = _heatAtFlat(h, x0,     y0,     mw, mh);
    final h10 = _heatAtFlat(h, x0 + 1, y0,     mw, mh);
    final h01 = _heatAtFlat(h, x0,     y0 + 1, mw, mh);
    final h11 = _heatAtFlat(h, x0 + 1, y0 + 1, mw, mh);

    return _lerp(_lerp(h00, h10, tx), _lerp(h01, h11, tx), ty);
  }

  static Vec3 sampleVector(double sx, double sy, int mw, int mh, Float64List vx, Float64List vy) {
    final fx = sx - 0.5;
    final fy = sy - 0.5;
    final x0 = fx.floor();
    final y0 = fy.floor();
    final tx = fx - x0;
    final ty = fy - y0;

    final v00 = _vectAtFlat(vx, vy, x0,     y0,     mw, mh);
    final v10 = _vectAtFlat(vx, vy, x0 + 1, y0,     mw, mh);
    final v01 = _vectAtFlat(vx, vy, x0,     y0 + 1, mw, mh);
    final v11 = _vectAtFlat(vx, vy, x0 + 1, y0 + 1, mw, mh);

    return Vec3(
      _lerp(_lerp(v00.x, v10.x, tx), _lerp(v01.x, v11.x, tx), ty),
      _lerp(_lerp(v00.y, v10.y, tx), _lerp(v01.y, v11.y, tx), ty),
      _lerp(_lerp(v00.z, v10.z, tx), _lerp(v01.z, v11.z, tx), ty),
    );
  }

  static double _heatAtFlat(Float64List h, int x, int y, int mw, int mh) =>
      h[y.clamp(0, mh - 1) * mw + x.clamp(0, mw - 1)];

  static Vec3 _vectAtFlat(Float64List vx, Float64List vy, int x, int y, int mw, int mh) {
    final i = y.clamp(0, mh - 1) * mw + x.clamp(0, mw - 1);
    return Vec3(vx[i], vy[i], 0);
  }

  static double _lerp(double a, double b, double t) => a * (1 - t) + b * t;
}

class GravityTextureCache {
  static final GravityTextureCache instance = GravityTextureCache._();
  GravityTextureCache._();

  final Map<CellMap, Future<GravityFieldTexture>> _cache = {};

  Future<GravityFieldTexture> get(Grid grid) {
    return _cache.putIfAbsent(
      grid.map,
          () => GravityFieldTexture.build(grid), // colorForVector: GravityFieldTexture.directionalColor),
    );
  }

  void invalidate(CellMap map) => _cache.remove(map);
  void clear() => _cache.clear();
}
