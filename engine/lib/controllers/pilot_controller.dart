import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/coord_3d.dart';
import '../grid.dart';
import '../location.dart';
import '../pilot.dart';
import '../rng.dart';
import '../ship.dart';
import '../systems/ship_system.dart';
import '../systems/weapons.dart';
import 'fugue_controller.dart';
import 'menu_controller.dart';
import 'movement_controller.dart';

enum ActionType {
  movement(10,1,1,false),
  sector(32,16,1,false),
  planet(24,24,1,true),
  planetLand(36,50,2,true),
  planetLaunch(16,1,1,false),
  planetOrbit(50,1,1,false),
  warp(8,0,0,false),
  energyScoop(72,0,0,false),
  piracy(100,100,10,false),
  combat(10,1,1,false),
  scrap(5,5,5,false);
  final int baseAuts, risk, heat;
  final bool dna;
  const ActionType(this.baseAuts,this.risk, this.heat, this.dna);
}

class PilotController extends FugueController {
  PilotController(super.fm);

  void move(Ship ship, Coord3D c, { required bool vector }) {
    final goto = vector ? ship.loc.cell.coord.add(c) : c;
    final result = fm.movementController.moveShip(ship, goto);
    if (ship.playship) {
      if (result == MoveResult.unsafeDestination) {
        fm.msgController.addMsg("Can't move to $goto (unsafe)");
      } else if (result == MoveResult.outOfEnergy) {
        fm.msgController.addMsg("Out of energy");
      } else if (result == MoveResult.noEngine) {
        fm.msgController.addMsg("Error: no engine");
      }
    }
  }

  ResultMessage uninstallSystem(ShipSystem system, Ship ship) {
    if (ship.uninstallSystem(system)) {
      return const ResultMessage("Uninstalled",true);
    } else {
      return const ResultMessage("Couldn't uninstall",false);
    }
  }

  ResultMessage installSystem(Ship ship, ShipSystem system, {SystemSlot? slot}) {
    if (ship.inventory.contains(system)) {
      if (slot == null) {
        fm.menuController.showMenu(fm.menuController.createInstallSlotMenu(ship,system),headerTxt: "Slot:");
        return const ResultMessage("Select a slot", true);
      } else {
        final installedSystem = ship.installSystem(system, slot: slot);
        if (installedSystem != null) {
          return ResultMessage("Installed at slot: $slot",true);
        } else {
          return ResultMessage("Invalid/unavailable slot: $slot",false);
        }
      }
    }
    return ResultMessage("System not found: $system",false);
  }

  void action(Pilot pilot, ActionType actionType, { mod = 1.0, int? actionAuts }) {
    if (pilot == nobody) return;
    if (pilot == fm.player && actionType.risk > 0 && fm.rnd.nextInt(255) < fm.player.fedLevel()) {
      //msgController.addMsg("You have a bad feeling about this...");
      if (fm.rnd.nextInt(128) < (max(actionType.risk - (actionType.dna ? fm.player.dnaScram : 0),1))) {
        fm.heat(actionType.heat);
      }
    }
    final auts = ((actionAuts ?? actionType.baseAuts) * mod).round();
    pilot.auCooldown += auts;
    pilot.lastAct = actionType;
    Ship? ship = fm.pilotMap[pilot]; if (ship != null) {
      for (final h in ship.loc.cell.hazMap.entries) {
        final msg = h.key.effectPerTurn(ship, auts, fm.rnd);
        if (msg != null) fm.msgController.addMsg(msg);
      }
    }
    fm.update();
    if (pilot == fm.player) runUntilNextPlayerTurn();
  }

  void runUntilNextPlayerTurn() { //fm.glog("Running until next turn...");
    final pilots = List.of(fm.activePilots); // ← Copy the list
    do {
      for (Pilot p in pilots) {
        try {
          p.tick();
          Ship? ship = fm.pilotMap[p];
          if (ship != null && ship.loc.level == fm.playerShip?.loc.level) {
            npcShipAct(ship);
          }
        } on ConcurrentModificationError {
          fm.glog("Skipping: ${p.name}");
        }
      }
      fm.auTick++;
      fm.player.tick();
      fm.playerShip?.tick(fm.rnd);
    } while (!fm.player.ready);
    fm.update();
  }

  void npcShipAct(Ship ship) {
    if (ship == fm.playerShip) return;
    ship.tick(fm.rnd);
    Pilot pilot = ship.pilot; if (pilot == nobody) return;
    if (pilot.ready) {
      final playShip = fm.playerShip;
      //TODO: detect when systems are critical and flee
      if (playShip != null && pilot.hostile && ship.loc.level.getAllShips().contains(playShip)) {
        ship.targetShip = playShip;
        final loc = ship.loc; if (loc is ImpulseLocation) {
            Weapon? w = ship.primaryWeapon; if (w != null && ship.currentShieldPercentage > 50) {
              //print("NPC combat...${w.accuracyRangeConfig.idealRange}, ${ship.distanceFrom(playShip)}");
              if ((w.accuracyRangeConfig.idealRange - ship.distanceFrom(playShip)).abs() > 1) {
                final idealCells = ship.loc.level.map.cells.values
                    .where((c) => playShip.distanceFromCoord(c.coord) < 1)
                    .sorted((c1,c2) => ship.distanceFromCoord(c2.coord).compareTo(ship.distanceFromCoord(c1.coord)));
                ship.currentPath = ship.loc.level.map.greedyPath(ship.loc.cell, idealCells.first, 3, fm.rnd);
              } else {
                if (w.cooldown == 0) {
                  fm.combatController.fire(ship);
                } else {
                  fm.pilotController.action(pilot, ActionType.combat, actionAuts: 1);
                }
                return;
              }
            } else {
              fm.msgController.addMsg("${ship.name} flees!");
              final idealCells = ship.loc.level.map.cells.values
                  .sorted((c1,c2) => playShip.distanceFromCoord(c2.coord).compareTo(playShip.distanceFromCoord(c1.coord)));
              ship.currentPath = ship.loc.level.map.greedyPath(ship.loc.cell, idealCells.first, 3, fm.rnd);
            }
        } else if (loc is SystemLocation) {
          ship.currentPath = ship.loc.level.map.greedyPath(ship.loc.cell,ship.targetShip!.loc.cell,3,fm.rnd, forceHaz: true);
          //print(ship.currentPath);
        }
      }
      if (ship.currentPath.isNotEmpty) {
        final result = fm.movementController.moveShip(ship, ship.currentPath.removeAt(0).coord);
        if (result == MoveResult.impCollision) { //fm.movementController.vectorShip(ship, Rng.rndUnitVector(fm.rnd));
          action(pilot, ActionType.movement, actionAuts: 10);
        }
      } else {
        fm.movementController.vectorShip(ship, Rng.rndUnitVector(fm.rnd));
      }
    }
  }

  void headTowards(GridCell cell) {

  }
}

