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
      Ship? target = ship.targetShip; if (target != null) {
        final path = ship.loc.map.greedyPath(ship.loc.cell, target.loc.cell, 1, fm.combatRnd);
        final dest = path.firstOrNull?.coord;
        if (dest != null) fm.movementController.moveShip(ship, path.first.coord);
      }
    }
  }

  void fire(Ship? ship) { //FugueEngine.glog("${ship?.name} fires...");
    if (ship != null) {
      Coord3D? target = ship.targetShip?.loc.cell.coord ?? ship.targetCoord;
      if (target == null) {
        fm.msgController.addMsg("Error: no target"); return;
      }
      final cell = ship.loc.map.at(target);
      if (cell is ImpulseCell) { //TODO: sector-ranged weapons?
        final results = ship.fireWeapons(cell, fm.combatRnd, ship: ship.targetShip);
        if (results.isEmpty && ship == fm.playerShip) {
          fm.msgController.addMsg("No weapons ready");
        } else {
          for (final result in results) {
            if (ship.targetShip != null) {
              fm.msgController.addMsg("${ship.name} fires weapon: ${result.weapon.name}");
              bool rangedMishap = false;
              if (result.weapon.usesAmmo) {
                if (result.ammoWarn) {
                  fm.msgController.addMsg("No ammo for ${result.weapon.name}");
                  rangedMishap = true;
                } else {
                  final path = ship.loc.map.greedyPath(ship.loc.cell,
                      ship.targetShip!.loc.cell, ship.loc.map.size, fm.combatRnd, jitter: 0, ignoreHaz: true);
                  final obstacle = path.firstWhereOrNull((c) => c.hazLevel > 0);
                  if (obstacle != null) {
                    fm.msgController.addMsg("${result.weapon.ammo!.name} hits ${obstacle.hazMap.entries.firstWhere((o) => o.value > 0).key.name}!");
                    rangedMishap = true;
                  }
                }
              }
              if (!rangedMishap) {
                if (result.dmg <= 0) {
                  fm.msgController.addMsg("${ship.name} misses!");
                } else {
                  damage(ship.targetShip!,result.dmg,result.weapon.dmgType);
                }
              }
              fm.pilotController.action(ship.pilot, ActionType.combat, actionAuts: 1); //or result.minCool?
            }
          }
        }
      } else {
        fm.msgController.addMsg("Wrong firing domain");
      }
    }
  }

  void damage(Ship ship, int dmg, DamageType dmgType, {String? details}) {
    fm.msgController.addMsg("${ship.name} takes ${dmg} damage ${details != null ? details : ''}");
    if (ship.takeDamage(dmg.roundToDouble(),dmgType)) explode(ship);
  }

  void explode(Ship ship) {
    fm.msgController.addMsg("${ship.name} explodes!");
    for (final system in ship.systemControl.getInstalledSystems()) {
      if (fm.combatRnd.nextBool()) {
        final cell = ship.loc.cell; if (cell is ImpulseCell) {
          system.damage = 50.0 + fm.combatRnd.nextInt(50);
          ship.loc.cell.addItem(system, ship.loc, fm.galaxy.itemRepository);
        }
      }
    }
    fm.shipRegistry.remove(ship);
    fm.update();
  }

}