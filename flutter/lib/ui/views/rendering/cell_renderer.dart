import 'dart:math';
import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/effects.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/geometry/impulse.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/galaxy/hazards.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:flutter/material.dart';

import '../../../options.dart';

class CellSprite {
  final CellEnum cellEnum;
  final Species? species;
  final List<CellEffect> effects;
  final double? rotation;
  String get glyph => cellEnum == CellEnum.ship
    ? species?.glyph ?? "?"
    : cellEnum.glyph;
  //TODO: images/tiles
  String get tilePath => cellEnum.imgPath;
  const CellSprite(this.cellEnum,{this.species,this.effects = const [], this.rotation});

  factory CellSprite.flatten(List<CellSprite> entities) {
    if (entities.isEmpty) return CellSprite(CellEnum.nothing);
    if (entities.length == 1) return entities.first;
    if (entities.every((e) => e.cellEnum.hazard)) {
      if (entities.length > 2) return CellSprite(CellEnum.clusterFark);
      final sprites = entities.map((e) => e.cellEnum);
      if (sprites.contains(CellEnum.nebula) && sprites.contains(CellEnum.ion)) return CellSprite(CellEnum.ionNeb);
      if (sprites.contains(CellEnum.nebula) && sprites.contains(CellEnum.roid)) return CellSprite(CellEnum.nebRoid);
      if (sprites.contains(CellEnum.ion) && sprites.contains(CellEnum.roid)) return CellSprite(CellEnum.ionRoid);
      if (sprites.contains(CellEnum.gamma) && sprites.contains(CellEnum.roid)) return CellSprite(CellEnum.radRoid);
    }
    return entities.sorted((a,b) => a.cellEnum.index - b.cellEnum.index).first;
  }
}

enum CellEnum {
  blackHole("-","img/tiles/blackHole.png",true),
  playShip("@","img/tiles/playship.png",false),
  ship("X","img/tiles/x.png",false),
  beacon("B","img/tiles/beacon.png",true),
  star("✦","img/tiles/star.png",false),
  planet("O","img/tiles/plan.png",false),
  loot("\$","img/tiles/loot.png",false),
  xenoCloud("%","img/tiles/xeno.png",false),
  buoy("⊕","img/tiles/buoy.png",false),
  fastSlug("*","img/tiles/slug.png",false),
  ammoSlug("►","img/tiles/slug.png",false),
  slugDest("▫","img/tiles/slugdest.png",false), //□
  roid("+","img/tiles/roid.png",true),
  nebula("~","img/tiles/neb.png",true),
  ion("#","img/tiles/ion.png",true),
  gamma("&","img/tiles/gamma.png",true),
  wake("\"","img/tiles/wake.png",true),
  radRoid("§","img/tiles/radRoid.png",true),
  ionRoid("^","img/tiles/ionRoid.png",true),
  nebRoid("✱","img/tiles/nebRoid.png",true),
  ionNeb("≈","img/tiles/ionNeb.png",true),
  clusterFark("※","img/tiles/cluster.png",true),
  nothing("","img/tiles/nada.png",false);
  final String glyph, imgPath;
  final bool hazard;
  const CellEnum(this.glyph,this.imgPath,this.hazard);
}

//U+25AB — White Small Square
class CellRenderer {
  FugueEngine fm;
  CellRenderer(this.fm);

  CellSprite spriteForCell(GridCell cell, Ship player) {
    final List<CellSprite> sprites = [];
    final ships = fm.galaxy.ships.atCell(cell);

    for (final s in ships) {
      if (!s.npc) sprites.add(CellSprite(CellEnum.playShip));
    }

    for (final s in ships) {
      if (s.npc && player.canScan(cell)) {
        sprites.add(CellSprite(CellEnum.ship,species: s.pilot.faction.species));
      }
    }

    if (cell.effects.anyActive) {
      sprites.add(CellSprite(CellEnum.xenoCloud,effects: cell.effects.allActive.toList()));
    }

    final hazards = cell.hazMap.entries
        .where((e) => e.value > 0 && e.key != Hazard.wake)
        .map((e) => e.key)
        .toList();

    for (final hazard in hazards) {

      sprites.add(CellSprite(switch(hazard) {
        Hazard.nebula => CellEnum.nebula,
        Hazard.ion => CellEnum.ion,
        Hazard.roid => CellEnum.roid,
        Hazard.gamma => CellEnum.gamma,
        Hazard.wake => CellEnum.wake,
      }));
    }

    if (cell is SectorCell) {
      if (cell.hasPlanets(fm.galaxy)) sprites.add(CellSprite(CellEnum.planet));
      if (cell.hasStars(fm.galaxy)) sprites.add(CellSprite(CellEnum.star));
      if (cell.hasBuoy) sprites.add(CellSprite(CellEnum.buoy));
      if (cell.blackHole) sprites.add(CellSprite(CellEnum.blackHole));
      if (cell.hasBeacon(fm.galaxy)) sprites.add(CellSprite(CellEnum.beacon));
    }

    if (cell is ImpulseCell) {
      if (cell.hasBeacon(fm.galaxy)) sprites.add(CellSprite(CellEnum.beacon));
      if (cell.hasPlanet(fm.galaxy)) sprites.add(CellSprite(CellEnum.planet));
      if (cell.hasStar(fm.galaxy)) sprites.add(CellSprite(CellEnum.star));
      if (cell.asteroid != null) sprites.add(CellSprite(CellEnum.roid));
      if (fm.galaxy.buoys.singleAtImpulse(cell.loc) != null) sprites.add(CellSprite(CellEnum.buoy));
      if (fm.galaxy.items.byLoc(cell.loc).isNotEmpty) sprites.add(CellSprite(CellEnum.loot));
      final slugs = fm.galaxy.slugs.inImpulse(cell.loc);
      if (slugs.isNotEmpty) {
        sprites.add(slugs.first.speed < 1
          ? CellSprite(CellEnum.ammoSlug, rotation: slugs.first.dir.angle2D)
          : CellSprite(CellEnum.fastSlug, rotation: slugs.first.dir.angle2D));
      }
      final nextSlug = fm.galaxy.slugs.nextSlugPosition(cell);
      if (nextSlug != null && nextSlug.speed >= 0) sprites.add(CellSprite(CellEnum.slugDest));
    }

    return CellSprite.flatten(sprites); //fm.playerShip?.loc.domain == Domain.orbital ? "." : " ";
  }

  void paintTargetMarker(
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

  Color bkgColorForCell(Grid grid, GridCell cell) {
    final h = grid.gravHeatMap[cell.coord] ?? 0;
    return Color.lerp(Colors.black, Colors.lightGreenAccent, h)!;
  }

  void drawGravityHand(Canvas canvas, Rect rect, Vec3 v, double heat) {
    final mag = v.mag;
    if (mag < 0.0001 || heat < .2) return;

    final dir = v.normalized;
    final center = rect.center;
    final side = rect.shortestSide / 2;
    final length = max(side / 2, (side * heat.clamp(0.01, 1.0)));
    final angle = atan2(dir.y, dir.x);
    final headLen = side / 2;
    final end = Offset(
      center.dx + dir.x * length,
      center.dy + dir.y * length,
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    if (length > headLen) {
      canvas.drawLine(center, end, paint);
    }

    const headAngle = 0.4;
    final head1 = Offset(
      end.dx - headLen * cos(angle - headAngle),
      end.dy - headLen * sin(angle - headAngle),
    );
    final head2 = Offset(
      end.dx - headLen * cos(angle + headAngle),
      end.dy - headLen * sin(angle + headAngle),
    );

    canvas.drawLine(end, head1, paint);
    canvas.drawLine(end, head2, paint);
  }

  Color colorForCell(
      GridCell cell,
      Ship pShip,
      CellRenderState state,
      { required bool is2D }) {
    final ships = fm.galaxy.ships.atCell(cell);

    if (state.selected) {
      return state.sameDepthAndNotEmpty ? scanDepthColor : scanColor;
    }

    final loc = cell.loc; if (loc is ImpulseLocation) {
      final slugs = fm.galaxy.slugs.inImpulse(loc);
      if (slugs.isNotEmpty) {
        final enemySlugs = slugs.where((s) => s.fromShip.npc).firstOrNull;
        if (enemySlugs != null) return Color(enemySlugs.objColor.argb);
        return Color(slugs.first.objColor.argb);
      }
    }

    if (cell is ImpulseCell) {
      final nextSlug = fm.galaxy.slugs.nextSlugPosition(cell);
      if (nextSlug != null) return Color(nextSlug.objColor.argb);
    }

    for (final s in ships) {
      if (!s.npc) return shipColor;
    }

    if (cell is SectorCell && cell.hasPlanets(fm.galaxy)) {
      return Color(cell.planets(fm.galaxy).first.environment.color.argb);
    }

    if (state.sameDepthAndNotEmpty) {
      return Colors.white;
    }

    for (final s in ships) {
      if (s.npc && pShip.canScan(cell)) {
        return Color(s.pilot.faction.color.argb);
      }
    }

    if (cell.effects.anyActive) {
      final effect = cell.effects.allActive.first;
      return Color(effect.effectColor.argb);
    }

    final hazards = cell.hazMap.entries
        .where((e) => e.value > 0 && e.key != Hazard.wake)
        .map((e) => e.key)
        .toList();

    if (hazards.isNotEmpty) {
      return Color(hazards.first.color.argb);
    }

    final dim = pShip.loc.map.dim;
    final dist = pShip.distanceFromLocation(cell.loc);
    final proximity = ((1.0 - (dist / dim.maxDist).clamp(0, 1)) * 8).round() / 8;
    return Color.lerp(farColor, nearColor, proximity)!;
  }

  double fontSizeForCell(double baseSize, int z, GridDim dim) {
    final maxZ = max(1, dim.mz - 1);
    final t = sqrt(z / maxZ);

    final depthFactor = 0.6 + 0.6 * t;

    return max(baseSize * depthFactor, baseSize * 0.45);
  }

  void paintCellBackground(
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

  void paintCellOutline(
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

  void paintGridBoundary(
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

  ui.Paragraph buildParagraph(String glyph, Color color, double fontSize) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: 'JetBrains Mono',
        textAlign: TextAlign.left,
        maxLines: 1,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
      ))
      ..addText(glyph);

    final p = builder.build();
    p.layout(const ui.ParagraphConstraints(width: 1000));
    return p;
  }
}

class CellRenderState {
  final bool scanned;
  final bool targeted;
  final bool inTargetPath;
  final bool inShipPath;
  final bool uiTarget;
  final bool sameDepth;
  final bool sameDepthAndNotEmpty;

  const CellRenderState({
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

  factory CellRenderState.forCell(
      GridCell cell,
      FugueEngine fm,
      Ship player,
      Set<Coord3D> targetPathCoords,
      Set<Coord3D> shipPathCoords,
      GridCell? targetCell,
      GridCell? scanSelection,
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
            (cell is ImpulseCell && (cell.hasPlanet(fm.galaxy) || fm.galaxy.items.byLoc(cell.loc).isNotEmpty)) ||
            (cell is SectorCell && (cell.hasPlanets(fm.galaxy) || cell.hasStars(fm.galaxy) || cell.blackHole))
    );
    final uiTarget = targeted;

    return CellRenderState(
      scanned: scanned,
      targeted: targeted,
      inTargetPath: inTargetPath,
      inShipPath: inShipPath,
      uiTarget: uiTarget,
      sameDepth: sameDepth,
      sameDepthAndNotEmpty: sameDepthAndNotEmpty,
    );
  }
}

