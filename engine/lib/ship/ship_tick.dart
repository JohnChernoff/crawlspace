import 'dart:math';
import 'package:crawlspace_engine/ship/nav/rotation_preview.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/ship_sub.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import 'package:crawlspace_engine/ship/systems/power.dart';
import '../fugue_engine.dart';
import 'nav/nav.dart';

class ShipTick extends ShipSubSystem {
  ShipTick(super.ship);

  TickResult tick({FugueEngine? fm}) {
    final dryRun = fm == null; //if (!dryRun) print("Tick... $dryRun");
    double totalRecharge = 0, totalBurn = 0;
    for (final rss in systemControl.rechargables) {
      if (rss.currentEnergy < rss.currentMaxEnergy) { //print(rss.name); print(rss.rechargeRate);
        double recharge = rss.currentMaxEnergy * rss.rechargeRate * (1-rss.damage);
        if (!dryRun) {
          if (rss.currentEnergy < 1) {
            recharge = (fm.aiRnd.nextInt(rss.avgRecoveryTime) == 0) ? recharge : 0;
          }
          if (recharge > 0) rss.recharge(recharge);
        }
        totalRecharge += recharge;
      }
    }
    //if (dryRun) print("Total recharge: ${totalRecharge}");
    for (final system in systemControl.activeSystems) { //TODO: handle npc power outages
      double e = system.powerDraw; //print("Burning: $e");
      if (!dryRun) {
        final burnout = !systemControl.burnEnergy(e);
        if (burnout && system is! RechargableShipSystem && ship.autoShutdown) {
          system.active = false;
          fm.msg("Out of power, shutting down ${system.type.name}");
        }
      }
      totalBurn += e;
    } //print("$name: Net energy per tick: ${recharge - totalBurn}");
    //if (dryRun) print("Total burn: ${totalBurn}");
    if (!dryRun) {
      for (final w in systemControl.getWeapons()) if (w.cooldown > 0) w.cooldown--;
      ship.xenoMatter = min(ship.shipClass.maxXeno,
          ship.xenoMatter + (systemControl.engine?.xenoGen ?? 0.0));
      ship.effectMap.tickAll();
      for (final effect in loc.cell.effects.allActive) {
        effect.apply(ship,fm);
      }
    }
    final newCell;
    if (!dryRun && ship.playship && loc.domain.newt) { // && (nav.moving || nav.activeHeading)) {
      if (fm.auTick % 1 == 0) { //(fm.aiRnd.nextDouble() < 1) { //moveProbability) {
        newCell = tickMove(fm);
      } else newCell = false;
    } else newCell = false;
    //if (newCell) print ("Moved: ${fm?.auTick}");
    return TickResult(totalRecharge - totalBurn, newCell);
  }

  bool tickMove(FugueEngine fm) {
    final prevLoc = loc.cell.coord; //final prevPos = Position(nav.pos.x,nav.pos.y,nav.pos.z);
    final preGravVel = nav.vel;  // snapshot before gravity mutates it
    nav.applyGravity(fm);

    if (nav.rotating) {
      final preview = nav.rotationPreviewer.previewRotationStep(
        state: RotationState.fromShip(ship),
      );
      nav.facing = preview.newState.facing;
      nav.targetFacing = preview.newState.targetFacing;
      if (preview.complete && nav.pendingThrust != null) {
        final engine = ship.systemControl.engine;
        final cost = ship.nav.thrustEnergyCost(engine, nav.pendingThrust!.mag);

        if (cost <= 0 || ship.systemControl.burnEnergy(cost)) {
          nav.applyForce(nav.pendingThrust!);
        } else {
          fm.msg("Insufficient energy for thrust");
        }
        nav.pendingThrust = null;
      }
    }

    if (nav.effectiveAutopilot) {
      fm.movementController.moveShip(
          ship,
          nav.autoPilot.heading,
          preGravVel: preGravVel);
    } else { //if (nav.moving || nav.rotating)
      fm.movementController.moveShip(
          ship,
          loc,
          throttleOverride: ThrottleMode.drift,
          preGravVel: preGravVel);
    } //print("$prevPos => ${nav.pos}");
    //if (nav.vel.mag < .1) { nav.resetMotionState(); }

    return (loc.cell.coord != prevLoc);
  }



}