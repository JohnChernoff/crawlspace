import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crawlspace_engine/color.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:flutter/material.dart';

enum SmudgeStyle {
  glow,graySat,mixed,none
}

class GravityFieldTexture {
  final ui.Image image;
  final Float64List heatGrid;
  final Float64List vxGrid;
  final Float64List vyGrid;
  final Uint32List colorGrid;
  final int mw;
  final int mh;

  GravityFieldTexture(
      this.image,
      this.heatGrid,
      this.vxGrid,
      this.vyGrid,
      this.colorGrid,
      this.mw,
      this.mh,
      );

  static Future<GravityFieldTexture> build(
      Grid grid, {
        Color bkgCol = Colors.black,
        double intensityPower = 0.85,
        Color Function(double heat, GameColor baseColor, Vec3 v)? colorForGravity,
      }) async {
    final mw = grid.map.dim.mx;
    final mh = grid.map.dim.my;
    final rgba = Uint8List(mw * mh * 4);

    final heatGrid = Float64List(mw * mh);
    final vxGrid = Float64List(mw * mh);
    final vyGrid = Float64List(mw * mh);
    final colorGrid = Uint32List(mw * mh);

    final bg = GameColor.fromRgb(bkgCol.red, bkgCol.green, bkgCol.blue, bkgCol.alpha);

    for (int y = 0; y < mh; y++) {
      for (int x = 0; x < mw; x++) {
        final i = y * mw + x;
        final coord = Coord3D(x, y, 0);

        final heat = grid.gravHeatMap[coord] ?? 0.0;
        final v = grid.gravAt(coord);
        final baseColor = grid.gravColorMap[coord] ?? GameColors.black;

        heatGrid[i] = heat;
        vxGrid[i] = v.x;
        vyGrid[i] = v.y;
        colorGrid[i] = baseColor.argb;

        final outColor = colorForGravity != null
            ? colorForGravity(heat, baseColor, v)
            : _defaultGravityColor(
          heat,
          baseColor,
          bg,
          intensityPower: intensityPower,
        );

        final off = i * 4;
        rgba[off]     = outColor.red;
        rgba[off + 1] = outColor.green;
        rgba[off + 2] = outColor.blue;
        rgba[off + 3] = outColor.alpha;
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

    return GravityFieldTexture(
      image,
      heatGrid,
      vxGrid,
      vyGrid,
      colorGrid,
      mw,
      mh,
    );
  }

  static Color _defaultGravityColor(
      double heat,
      GameColor baseColor,
      GameColor background, {
        smudge = SmudgeStyle.mixed,
        double intensityPower = 0.85,
      }) {


    final t = pow(heat.clamp(0.0, 1.0), intensityPower).toDouble();
    GameColor mixed;
    if (smudge == SmudgeStyle.graySat) {
      final base = GameColor.lerp(GameColors.gray, baseColor, t);
      mixed = GameColor.lerp(background, base, t);
    } else if (smudge == SmudgeStyle.glow) { // push toward white at high intensity
      final base = GameColor.lerp(background, baseColor, t.toDouble());
      final glow = pow(t, 2.0); // stronger curve
      mixed = GameColor.lerp(base, GameColors.white, glow * 0.25);
    } else if (smudge == SmudgeStyle.mixed) {
      final satT = pow(t, 0.7).toDouble();   // saturation comes in earlier
      final brightT = pow(t, 1.2).toDouble(); // brightness comes in later
      final base = GameColor.lerp(GameColors.gray, baseColor, satT);
      mixed = GameColor.lerp(background, base, brightT);
    } else {
      mixed = GameColor.lerp(background, baseColor, t);
    }
    return Color.fromARGB(mixed.a, mixed.r, mixed.g, mixed.b);
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

  static GameColor sampleColor(double sx, double sy, int mw, int mh, Uint32List colors) {
    final fx = sx - 0.5;
    final fy = sy - 0.5;
    final x0 = fx.floor();
    final y0 = fy.floor();
    final tx = fx - x0;
    final ty = fy - y0;

    final c00 = _colorAtFlat(colors, x0,     y0,     mw, mh);
    final c10 = _colorAtFlat(colors, x0 + 1, y0,     mw, mh);
    final c01 = _colorAtFlat(colors, x0,     y0 + 1, mw, mh);
    final c11 = _colorAtFlat(colors, x0 + 1, y0 + 1, mw, mh);

    final top = GameColor.lerp(c00, c10, tx);
    final bottom = GameColor.lerp(c01, c11, tx);
    return GameColor.lerp(top, bottom, ty);
  }

  static double _heatAtFlat(Float64List h, int x, int y, int mw, int mh) =>
      h[y.clamp(0, mh - 1) * mw + x.clamp(0, mw - 1)];

  static Vec3 _vectAtFlat(Float64List vx, Float64List vy, int x, int y, int mw, int mh) {
    final i = y.clamp(0, mh - 1) * mw + x.clamp(0, mw - 1);
    return Vec3(vx[i], vy[i], 0);
  }

  static GameColor _colorAtFlat(Uint32List colors, int x, int y, int mw, int mh) {
    final i = y.clamp(0, mh - 1) * mw + x.clamp(0, mw - 1);
    return GameColor(colors[i]);
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
          () => GravityFieldTexture.build(grid, intensityPower: 0.85),
    );
  }

  void invalidate(CellMap map) => _cache.remove(map);
  void clear() => _cache.clear();
}
