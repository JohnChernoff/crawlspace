import 'package:collection/collection.dart';
import 'package:crawlspace_engine/fugue_engine.dart';

import '../coord_3d.dart';
import '../impulse.dart';
import '../ship.dart';
import '../systems/ship_system.dart';
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
        final path = ship.loc.level.map.greedyPath(ship.loc.cell, target.loc.cell, 1, fm.rnd);
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
      final cell = ship.loc.level.map.cells[target];
      if (cell is ImpulseCell) { //TODO: sector-ranged weapons?
        final results = ship.fireWeapons(cell, fm.rnd, ship: ship.targetShip);
        if (results.isEmpty && ship == fm.playerShip) {
          fm.msgController.addMsg("No weapons ready");
        } else {
          for (final result in results) {
            if (ship.targetShip != null) {
              fm.msgController.addMsg("Firing weapon: ${result.weapon.name}");
              bool rangedMishap = false;
              if (result.weapon.usesAmmo) {
                if (result.ammoWarn) {
                  fm.msgController.addMsg("No ammo for ${result.weapon.name}");
                  rangedMishap = true;
                } else {
                  final path = ship.loc.level.map.greedyPath(ship.loc.cell, ship.targetShip!.loc.cell, ship.loc.level.map.size, fm.rnd, jitter: 0, ignoreHaz: true);
                  final obstacle = path.firstWhereOrNull((c) => c.hazLevel > 0);
                  if (obstacle != null) {
                    fm.msgController.addMsg("${result.weapon.ammo!.name} hits ${obstacle.hazMap.entries.firstWhere((o) => o.value > 0).key}!");
                    rangedMishap = true;
                  }
                }
              }
              if (!rangedMishap) {
                if (result.dmg <= 0) {
                  fm.msgController.addMsg("${ship.name} misses!");
                } else {
                  fm.msgController.addMsg("${ship.targetShip} takes ${result.dmg} damage");
                  if (ship.targetShip!.takeDamage(result.dmg.roundToDouble(),result.weapon.dmgType)) explode(ship.targetShip!);
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

  void explode(Ship ship) {
    fm.msgController.addMsg("${ship.name} explodes!");
    for (final cmp in ship.systemMap.where((s) => s.system != null)) {
      if (fm.rnd.nextBool()) {
        final cell = ship.loc.cell; if (cell is ImpulseCell) {
          cmp.system!.damage = 50.0 + fm.rnd.nextInt(50);
          cell.items.add(cmp.system!);
        }
      }
    }
    fm.removeShip(ship);
    fm.update();
  }

  void scrap() { //print("Attempting to scrap");
    int m = 0;
    Ship? ship = fm.playerShip; if (ship != null) {
      final cell = ship.loc.cell; if (cell is ImpulseCell) {
        for (final i in List.of(cell.items)) {
          if (i is ShipSystem) {
            if (ship.addScrap(i)) {
              m++;
              fm.msgController.addMsg("Scrapping: ${i.name}");
              cell.items.remove(i);
            }
            else {
              fm.msgController.addMsg("Couldn't scrap: ${i.name}");
            }
          }
        }
      }
      if (m > 0) {
        fm.pilotController.action(ship.pilot, ActionType.scrap, actionAuts: ActionType.scrap.baseAuts * m);
      }
    }
  }

  void jettison(Ship? ship) {
    if (ship != null) {
      final s = ship.jettisonScrap(); if (s != null) {
        fm.msgController.addMsg("${ship.name} jettisons ${s.name}");
        fm.pilotController.action(ship.pilot, ActionType.scrap);
      }
    }
  }
}