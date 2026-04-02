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
        bool showDir = false,
        bkgCol = Colors.black, fgCol = Colors.red,
        Color Function(double heat, Color bkgCol, Color fgCol)? colorForHeat,
      }) async {

    print("Loading texture...");
    final t = DateTime.now().millisecondsSinceEpoch;

    final pxPerCell = 1; //no reason to be larger than this now
    final width = grid.map.dim.mx * pxPerCell;
    final height = grid.map.dim.my * pxPerCell;
    final rgba = Uint8List(width * height * 4);

    final colorFn = colorForHeat ?? _defaultColorForHeat;

    final mw = grid.map.dim.mx;
    final mh = grid.map.dim.my;
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
        // Fetch 4 corner values once per cell
        final h00 = _heatAtFlat(heatGrid, cx,     cy,     mw, mh);
        final h10 = _heatAtFlat(heatGrid, cx + 1, cy,     mw, mh);
        final h01 = _heatAtFlat(heatGrid, cx,     cy + 1, mw, mh);
        final h11 = _heatAtFlat(heatGrid, cx + 1, cy + 1, mw, mh);

        // Same for vectors if needed
        final vx00 = vxGrid[cy.clamp(0,mh-1) * mw + cx.clamp(0,mw-1)];
        // ... etc, only if showDir is true

        for (int py = 0; py < pxPerCell; py++) {
          final ty = pxPerCell <= 1 ? 0.0 : py / (pxPerCell - 1);
          final hLeft  = _lerp(h00, h01, ty);
          final hRight = _lerp(h10, h11, ty);

          for (int px = 0; px < pxPerCell; px++) {
            final tx = pxPerCell <= 1 ? 0.0 : px / (pxPerCell - 1);
            final heat = _lerp(hLeft, hRight, tx);

            final off = ((cy * pxPerCell + py) * width + (cx * pxPerCell + px)) * 4;

            // Fix 4 inline — no Color object, no lerp boxing
            final r = (bkgCol.r + (fgCol.r - bkgCol.r) * heat);
            final g = (bkgCol.g + (fgCol.g - bkgCol.g) * heat);
            final b = (bkgCol.b + (fgCol.b - bkgCol.b) * heat);
            final a = (bkgCol.a + (fgCol.a - bkgCol.a) * heat);
            rgba[off]     = (r * 255).round() & 0xff;
            rgba[off + 1] = (g * 255).round() & 0xff;
            rgba[off + 2] = (b * 255).round() & 0xff;
            rgba[off + 3] = (a * 255).round() & 0xff;
          }
        }
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
    print("Loaded texture in ${DateTime.now().millisecondsSinceEpoch - t}");

    return GravityFieldTexture(image, heatGrid, vxGrid, vyGrid, mw, mh);
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

  static double _heatAtFlat(Float64List h, int x, int y, int mw, int mh) {
    return h[y.clamp(0, mh-1) * mw + x.clamp(0, mw-1)];
  }

  static Vec3 _vectAtFlat(Float64List vx, Float64List vy, int x, int y, int mw, int mh) {
    final i = y.clamp(0, mh-1) * mw + x.clamp(0, mw-1);
    return Vec3(vx[i], vy[i], 0);
  }

  static double sampleHeat(double sx, double sy, int mw, int mh, Float64List h) {
    final x0 = sx.floor();
    final y0 = sy.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    final tx = sx - x0;
    final ty = sy - y0;

    final h00 = _heatAtFlat(h, x0, y0, mw, mh);
    final h10 = _heatAtFlat(h, x1, y0, mw, mh);
    final h01 = _heatAtFlat(h, x0, y1, mw, mh);
    final h11 = _heatAtFlat(h, x1, y1, mw, mh);

    final top = _lerp(h00, h10, tx);
    final bottom = _lerp(h01, h11, tx);
    return _lerp(top, bottom, ty);
  }

  static Vec3 sampleVector(double sx, double sy, int mw, int mh, Float64List vx, Float64List vy) {
      final fx = sx - 0.5;
      final fy = sy - 0.5;

      final x0 = fx.floor();
      final y0 = fy.floor();
      final x1 = x0 + 1;
      final y1 = y0 + 1;

      final tx = fx - x0;
      final ty = fy - y0;

    final v00 = _vectAtFlat(vx,vy,x0,y0,mw,mh);
    final v10 = _vectAtFlat(vx,vy,x1,y0,mw,mh);
    final v01 = _vectAtFlat(vx,vy,x0,y1,mw,mh);
    final v11 = _vectAtFlat(vx,vy,x1,y1,mw,mh);

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

  static double _lerp(double a, double b, double t) => a * (1 - t) + b * t;
}

class GravityTextureCache {
  static final GravityTextureCache instance = GravityTextureCache._();
  GravityTextureCache._();

  final Map<CellMap, Future<GravityFieldTexture>> _cache = {};

  Future<GravityFieldTexture> get(Grid grid) {
    return _cache.putIfAbsent(
      grid.map,
          () => GravityFieldTexture.build(grid),
    );
  }

  void invalidate(CellMap map) {
    _cache.remove(map);
  }

  void clear() {
    _cache.clear();
  }
}
