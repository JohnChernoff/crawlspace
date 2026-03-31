import 'dart:math';

import 'package:collection/collection.dart';
import 'package:crawlspace_engine/ship/systems/weapons.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/impulse.dart';
import '../ship/ship.dart';
import 'fugue_controller.dart';
import 'pilot_controller.dart';

class CombatController extends FugueController {
  CombatController(super.fm);

  void awaitNextWeapon(Ship? ship) {
    if (ship != null) fm.pilotController.action(ship.pilot,ActionType.combat,actionAuts: ship.turnsUntilWeaponReady);
  }

  void pursue(Ship? ship) {
    if (ship != null) {
      Ship? target = ship.nav.targetShip; if (target != null) {
        final path = ship.loc.map.greedyPath(ship.loc.cell, target.loc.cell, 1, fm.combatRnd);
        final dest = path.firstOrNull?.coord;
        if (dest != null) fm.movementController.moveShip(ship, path.first.loc); //TODO: fix?
      }
    }
  }

  void fire(Ship? ship) { //FugueEngine.glog("${ship?.name} fires...");
    if (ship != null) {
      Coord3D? target = ship.nav.targetShip?.loc.cell.coord ?? ship.nav.targetCoord;
      if (target == null) {
        fm.msg("Error: no target"); return;
      }
      final cell = ship.loc.map[target];
      if (cell is ImpulseCell) { //TODO: sector-ranged weapons?
        final results = ship.fireWeapons(cell, fm.combatRnd, ship: ship.nav.targetShip);
        if (results.isEmpty && ship == fm.playerShip) {
          fm.msg("No weapons ready");
        } else {
          for (final result in results) {
            if (ship.nav.targetShip != null) {
              fm.msg("${ship.name} fires weapon: ${result.weapon.name}");
              bool rangedMishap = false;
              if (result.weapon.usesAmmo) {
                if (result.ammoWarn) {
                  fm.msg("No ammo for ${result.weapon.name}");
                  rangedMishap = true;
                } else {
                  final path = ship.loc.map.greedyPath(ship.loc.cell,
                      ship.nav.targetShip!.loc.cell, ship.loc.map.dim.maxDim, fm.combatRnd, jitter: 0, ignoreHaz: true);
                  final obstacle = path.firstWhereOrNull((c) => c.hazLevel > 0);
                  if (obstacle != null) {
                    fm.msg("${result.weapon.ammo!.name} hits ${obstacle.hazMap.entries.firstWhere((o) => o.value > 0).key.name}!");
                    rangedMishap = true;
                  }
                }
              }
              if (!rangedMishap) {
                if (result.dmg <= 0) {
                  fm.msg("${ship.name} misses!");
                } else {
                  damage(ship.nav.targetShip!,result.dmg,result.weapon.dmgType);
                }
              }
              fm.pilotController.action(ship.pilot, ActionType.combat, actionAuts: 1); //or result.minCool?
            }
          }
        }
      } else {
        fm.msg("Wrong firing domain");
      }
    }
  }

  double resistanceReduction(double r) {
    const k = 0.4;
    return 1 - exp(-k * r);
  }

  void damage(Ship ship, int dmg, DamageType dmgType, {String? details}) {
    final suffix = details == null ? "" : " $details";
    final shieldResistance = ship.shieldResistance(dmgType);
    final shieldReduction = resistanceReduction(shieldResistance);
    final netDamage = dmg * (1 - shieldReduction);
    final ShieldHitResult result = ship.takeShieldDamage(netDamage);
    if (result.type == ShieldHitType.absorbed) {
      fm.msg("${ship.name} absorbs ${result.toShield.round()} damage$suffix");
    } else if (result.type == ShieldHitType.efficientBlock) {
      fm.msg("${ship.name} blocks ${netDamage.round()} damage$suffix");
    } else {
      if (result.type == ShieldHitType.phaseCatch) {
        final phased = netDamage - result.toShield - result.toHull;
        fm.msg("${ship.name} phases $phased, absorbs ${result.toShield.round()} damage$suffix");
      } else if (result.toShield > 0) {
        fm.msg("${ship.name} absorbs ${result.toShield.round()} damage$suffix");
      }
      if (result.toHull > 0) {
        final hullResistance = ship.hullResistance(dmgType);
        final hullReduction = resistanceReduction(hullResistance);
        final hullDmg = result.toHull * (1 - hullReduction);
        fm.msg("${ship.name} takes ${hullDmg.round()} hull damage$suffix");
        fm.wakePilot(ship.pilot);
        if (ship.takeHullDamage(hullDmg)) explode(ship);
      }
    }
  }

  void explode(Ship ship) {
    fm.msg("${ship.name} explodes!");
    for (final system in ship.systemControl.getInstalledSystems()) {
      if (fm.combatRnd.nextBool()) {
        final cell = ship.loc.cell; if (cell is ImpulseCell) {
          system.damage = 50.0 + fm.combatRnd.nextInt(50);
          fm.galaxy.items.addItem(system, ship.loc);
        }
      }
    }
    fm.galaxy.ships.remove(ship);
    fm.update();
  }

}