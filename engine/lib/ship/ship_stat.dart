import 'dart:math';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/ship/ship_sub.dart';
import 'package:crawlspace_engine/ship/systems/weapon_profiler.dart';
import 'package:crawlspace_engine/ship/systems/weapons.dart';
import '../color.dart';
import '../fugue_engine.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/hazards.dart';

class ShipStatus extends ShipSubSystem {
  ShipStatus(super.ship);

  List<TextBlock> display(Galaxy g,{bool tactical = false, bool showScannedShip = true, nebula = false}) {
    final abbrev = !tactical && nav.targetShip != null;
    final hostile = ship.pilot.hostile;
    if (nebula || (tactical && loc.cell.hasHaz(Hazard.nebula))) return [TextBlock("In Nebula", GameColors.red, true)];
    List<TextBlock> blocks = [];
    blocks.addAll(dumpEffects());
    if (!abbrev) {
      blocks.add(TextBlock(ship.name,ship.pilot.faction.color,false));
      blocks.add(TextBlock(" (${ship.pilot.faction.name} ${ship.shipClass.type.name})",ship.pilot.faction.color,true));
    }
    if (ship.pilot.faction.isPirate) blocks.add(TextBlock("*** Pirate ***",GameColors.red,true)); else {
      if (tactical) blocks.add(TextBlock("${(hostile ? 'hostile' : 'peaceful')} ",GameColors.gray,true));
    }

    //blocks.add(TextBlock("Volume: ${volume} ",GameColors.green,false));
    blocks.add(TextBlock("Hull: ${ship.hullRemaining.toStringAsFixed(2)} ",GameColors.green,false));
    blocks.add(TextBlock("(${ship.currentHullPercentage.round()}%)",GameColors.lightBlue,true));
    blocks.add(TextBlock("Shields: ${systemControl.currentShieldStrength.toStringAsFixed(2)} ",GameColors.green,false));
    blocks.add(TextBlock("(${systemControl.currentShieldPercentage.round()}%)",GameColors.lightBlue,true));
    if (!tactical) {
      blocks.add(TextBlock("Energy: ${ship.systemControl.getCurrentEnergy().toStringAsFixed(2)} ",GameColors.green,false));
      blocks.add(TextBlock("(${ship.systemControl.currentEnergyPercentage.round()}%)",GameColors.lightBlue,true));
      blocks.add(TextBlock("Energy Rate: ${ship.ticker.tick().energy.toStringAsFixed(2)}, ",GameColors.green,false));
    }
    blocks.add(TextBlock("Xeno: ${ship.xenoMatter.toStringAsFixed(2)}",GameColors.orange,true));
    for (final s in systemControl.getInstalledSystems()) {
      bool cooldown = s is Weapon && s.cooldown > 0;
      final color = cooldown ? GameColors.red : s.active ? GameColors.white : GameColors.gray;
      blocks.add(TextBlock("${s.name} ",color,false));
      if (s.damage > 0) blocks.add(TextBlock("${s.dmgTxt}% ", GameColors.gray, false));
      blocks.add(TextBlock("${s.active ? '+' : '-'}",color,true));
      if (s is Weapon && s.ammo != null) {
        blocks.add(TextBlock("${s.ammo!.name}: ${systemControl.ammoFor(s.ammo!)}",GameColors.coral,true));
      }
    }
    if (!tactical && loc is ImpulseLocation && nav.targetShip != null) {
      final sustained = ship.sustainedRangeProfile(maxRange: loc.system.impulseMapDim.maxDim * 2);
      blocks.add(TextBlock(sustained.summary(), GameColors.orange, true));
      final dist = ship.distanceFrom(nav.targetShip!).round();
      final volley = ship.volleyRangeProfile(maxRange: loc.system.impulseMapDim.maxDim * 2);
      final fit = (volley.efficiencyAt(dist) * 100).round();
      blocks.add(TextBlock("Dist $dist | volley fit $fit%", GameColors.lightBlue, true));
      blocks.addAll(combatText());
    }
    if (!tactical) {
      if (loc is ImpulseLocation) {
        blocks.add(TextBlock("GForce: ${ship.nav.gForce}", GameColors.green, true));
        blocks.add(TextBlock("Targ Facing: ${nav.targetFacing}", GameColors.gray, true));
        blocks.add(TextBlock("Facing: ${nav.facing}", GameColors.gray, true));
        blocks.add(TextBlock("Position: ${nav.pos}", GameColors.gray, true));
        blocks.add(TextBlock("Heading: ${nav.autoPilot.heading.cell.coord}", GameColors.gray, true));
        blocks.add(TextBlock("Velocity: ${nav.velocityString()}", GameColors.gray, true));
        blocks.add(TextBlock("Speed: ${nav.speed.toStringAsFixed(2)}", GameColors.gray, true));
        blocks.add(TextBlock("Throttle: ${nav.throttle}", GameColors.gray, true));
      }
      if (!abbrev) {
        blocks.add(TextBlock("Mass: ${ship.currentMass.toStringAsFixed(2)}, ", GameColors.gray, false));
        blocks.add(TextBlock("Capacity: ${ship.availableSpace.toStringAsFixed(2)}", GameColors.gray, true));
        blocks.add(TextBlock("Total scrap value: ${ship.scrapVal.toStringAsFixed(2)}", GameColors.gray, true));
      }
    }
    blocks.add(const TextBlock("",GameColors.black,true));
    final targLoc = nav.targetLoc;
    print(targLoc);
    if (targLoc != null) blocks.add(TextBlock("Scanning: ${targLoc.cell.toScannerString(g, verbose: true)}", GameColors.orange, true));
    //else blocks.add(TextBlock("No target", GameColors.gray, true));
    if (showScannedShip && !tactical && (nav.targetShip != null && nav.targetShip!.npc)) {
      blocks.add(const TextBlock("Scanning Ship: ", GameColors.orange, true));
      blocks.addAll(nav.targetShip!.status.display(g,tactical: true));
    }
    return blocks;
  }

  List<TextBlock> combatText() {
    final target = nav.targetShip;
    if (target == null) return [];

    final dist = ship.distance(l: target.loc);
    final projDist = nav.projectedTargetDist;
    final trend = nav.trendGlyph;
    final profile = ship.volleyRangeProfile();

    final inRange = profile.usableBand != null &&
        dist >= profile.usableBand!.start &&
        dist <= profile.usableBand!.end;
    final projInRange = projDist != null && profile.usableBand != null &&
        projDist >= profile.usableBand!.start &&
        projDist <= profile.usableBand!.end;

    final rangeColor = inRange
        ? (projInRange ? GameColors.green : GameColors.orange)
        : (projInRange ? GameColors.lightBlue : GameColors.red);

    final blocks = <TextBlock>[];

    // Header line
    blocks.add(TextBlock(
        "TARGET: ${target.name} "
            "dist:${dist.toStringAsFixed(1)}$trend"
            "->${projDist?.toStringAsFixed(1) ?? '?'} ",
        rangeColor, true));
    //blocks.add(TextBlock(profile.asciiBars(), GameColors.cyan, true));

    // Per-weapon lines
    for (final w in systemControl.availableWeapons) {
      final maxCooldown = w.fireRate;
      final filled = maxCooldown > 0
          ? ((1 - w.cooldown / maxCooldown) * 10).round().clamp(0, 10)
          : 10;
      final empty = 10 - filled;

      final wInRange = w.accuracyRangeConfig.rangeMultiplier(dist) > 0;
      final wProjInRange = projDist != null &&
          w.accuracyRangeConfig.rangeMultiplier(projDist) > 0;

      final col = w.cooldown == 0
          ? (wInRange ? GameColors.green : GameColors.orange)
          : (wProjInRange ? GameColors.lightBlue : GameColors.gray);

      final readyStr = w.cooldown == 0 ? "READY" : "${w.cooldown}t";

      blocks.add(TextBlock(
          "${w.name.substring(0, min(10, w.name.length)).padRight(10)} "
              "${'█' * filled}${'░' * empty} "
              "$readyStr ",
          col, true));
    }
    return blocks;
  }

  List<TextBlock> dumpEffects() {
    final map = ship.effectMap.map.entries.where((e) => e.value > 0).map(((m) => m.key));
    return List.generate(map.length, (i) {
      final effect = map.elementAt(i);
      return TextBlock(effect.statusString, effect.color, true);
    });
  }
}