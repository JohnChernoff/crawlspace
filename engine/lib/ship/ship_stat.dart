import 'dart:math';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/ship/nav/nav.dart';
import 'package:crawlspace_engine/ship/ship_sub.dart';
import 'package:crawlspace_engine/ship/systems/weapon_profiler.dart';
import 'package:crawlspace_engine/ship/systems/weapons.dart';
import '../color.dart';
import '../fugue_engine.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/hazards.dart';

class ShipStatus extends ShipSubSystem {
  ShipStatus(super.ship);

  String displayEnergy(double e, {digits = 2}) => (e / 100).toStringAsFixed(digits);

  List<TextBlock> display(FugueEngine fm,{bool tactical = false, bool showScannedShip = false, nebula = false}) {
    Galaxy g = fm.galaxy;
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
      blocks.add(TextBlock("Energy: ${displayEnergy(ship.systemControl.getCurrentEnergy())} ",GameColors.green,false));
      blocks.add(TextBlock("(${ship.systemControl.currentEnergyPercentage.round()}%)",GameColors.lightBlue,true));
      blocks.add(TextBlock("Energy Rate: ${displayEnergy(ship.ticker.tick().energy)}, ",GameColors.green,false));
    }
    blocks.add(TextBlock("Xeno: ${ship.xenoMatter.toStringAsFixed(2)}",GameColors.orange,true));
    for (final s in systemControl.getInstalledSystems()) {
      if (s is Weapon) {
        final wc = s.cooldown > 0 ? GameColor.lerp(GameColors.red, GameColors.green, (s.fireRate - s.cooldown) / s.fireRate) : GameColors.gold;
        final ammo = s.ammo != null
            ? "\n(${s.ammo!.name}: ${ship.systemControl.ammoFor(s.ammo!)})"
            : s.usesAmmo ? "\n(no ammo)" : "";
        blocks.add(TextBlock("${s.name}$ammo",wc,false));
        if (loc is ImpulseLocation && nav.targetShip != null && s.cooldown == 0) {
          if (!ship.systemControl.hasEnergy(s.energyRate)) {
            blocks.add(TextBlock(" - energy req: ${displayEnergy(s.energyRate, digits: 0)}", GameColors.gray, false));
          } else if (ship.distance(ship: nav.targetShip) > s.dmgType.damageRange.maxRange) {
            blocks.add(TextBlock(" out of range: ${s.dmgType.damageRange.maxRange}", GameColors.red, false));
          } else if (!s.usesAmmo || s.ammo != null) {
            final a = s.effectiveAccuracy(ship.distance(ship: nav.targetShip));
            blocks.add(TextBlock(", toHit: ${(a * 100).truncate()}%", GameColor.lerp(GameColors.red, GameColors.green, a), false));
          }
        }
      } else {
        blocks.add(TextBlock("${s.name} ",s.active ? GameColors.white : GameColors.gray,false));
      }
      if (s.damage > 0) blocks.add(TextBlock("${s.dmgTxt}% ", GameColors.gray, false));
      //blocks.add(TextBlock("${s.active ? '+' : '-'}",color,true));
      blocks.add(TextBlock("",GameColors.black,true));
    }
    if (!tactical) {
      if (ship.nav.effectiveNewt) {
        blocks.add(TextBlock("GForce: ${ship.nav.gForce}", GameColors.green, true));
        //blocks.add(TextBlock("Targ Facing: ${nav.targetFacing}", GameColors.gray, true));
        //blocks.add(TextBlock("Facing: ${nav.facing}", GameColors.gray, true));
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
    final targLoc = nav.targetLoc; //print(targLoc);
    if (targLoc != null) blocks.add(TextBlock("Scanning: ${targLoc.cell.toScannerString(g, verbose: true)}", GameColors.orange, true));
    //else blocks.add(TextBlock("No target", GameColors.gray, true));
    if (showScannedShip && !tactical && (nav.targetShip != null && nav.targetShip!.npc)) {
      blocks.add(const TextBlock("Scanning Ship: ", GameColors.orange, true));
      blocks.addAll(nav.targetShip!.status.display(fm,tactical: true));
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