import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/coord_3d.dart';
import 'package:crawlspace_engine/hazards.dart';
import '../fugue_engine.dart';
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

  void toggleSystem(Ship ship) {
    final systems = ship.getAllSystems;
    final menuEntries = List.generate(systems.length, (i) => ValueEntry(
        fm.menuController.letter(i),
        systems.elementAt(i).name,
        systems.elementAt(i),
        (s) => s.active = !s.active, exitMenu: true));
    fm.menuController.showMenu(headerTxt: "Toggle System", menuEntries);
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
    final playShip = fm.playerShip;
    final pilots = List.of(fm.activePilots); // ← Copy the list
    do {
      for (Pilot p in pilots) { //print("${p.name}'s turn");
        try {
          p.tick();
          Ship? ship = fm.pilotMap[p];
          if (ship != null && ship.loc.level == fm.playerShip?.loc.level) npcShipAct(ship);
        } on ConcurrentModificationError {
          FugueEngine.glog("Skipping: ${p.name}",error: true);
        }
      }
      fm.auTick++;
      fm.player.tick();
      playShip?.tick(rnd: fm.rnd);
    } while (!fm.player.ready);
    if (playShip != null) {
      for (final s in playShip.loc.level.getAllShips().where((s) => s.npc)) playShip.detect(s);
    }
    fm.update();
  }

  void npcShipAct(Ship ship) {
    if (ship == fm.playerShip) return;
    ship.tick(rnd: fm.rnd);
    Pilot pilot = ship.pilot; if (pilot == nobody) return;
    if (pilot.ready) { //print("${ship.name}'s turn...");
      final playLoc = fm.playerShip != null ? ship.detect(fm.playerShip!) : null;
      if (playLoc != null &&
          pilot.hostile &&
          ship.loc.level.getAllShips().contains(fm.playerShip)) {
        ship.targetShip = fm.playerShip;
        final loc = ship.loc; if (loc is ImpulseLocation) {
            Weapon? w = ship.primaryWeapon;
            if (w != null && ship.currentHullPercentage > (ship.pilot.faction.courage * 100)) {
              final r = w.accuracyRangeConfig.idealRange, d = ship.distance(l: playLoc); //print("${ship.name} combat...$r, $d");
              if ((r -d).abs() > 1) { //print("${ship.name} maneuvering...");
                final idealCells = ship.loc.level.map.cells.values
                    .where((c) => (playLoc.dist(c: c) - r).abs() < 1.5) //TODO: tweak acceptable range
                    .sorted((c1,c2) => ship.distance(c: c1.coord).compareTo(ship.distance(c: c2.coord)));
                ship.currentPath = ship.loc.level.map.greedyPath(ship.loc.cell, idealCells.first, 3, fm.rnd);
              } else {
                if (playLoc != fm.playerShip!.loc) {
                  print("${ship.name} cannot find ${fm.playerShip!.name}"); //TODO: fallback strategy
                }
                else if (w.cooldown == 0) {  //print("${ship.name} firing...");
                  fm.combatController.fire(ship);
                  return;
                } else { //print("${ship.name} waiting...");
                  fm.pilotController.action(pilot, ActionType.combat, actionAuts: 1);
                  return;
                }
              }
            } else {
              fm.msgController.addMsg("${ship.name} flees!");
              final idealCells = ship.loc.level.map.cells.values
                  .sorted((c1,c2) => playLoc.dist(c: c2).compareTo(playLoc.dist(c: c1)));
              ship.currentPath = ship.loc.level.map.greedyPath(ship.loc.cell, idealCells.first, 3, fm.rnd);
            }
        } else if (loc is SystemLocation) {
          ship.currentPath = ship.loc.level.map.greedyPath(ship.loc.cell,ship.targetShip!.loc.cell,3,fm.rnd, forceHaz: true); //print(ship.currentPath);
        }
      }
      if (ship.currentPath.isNotEmpty) {
        final result = fm.movementController.moveShip(ship, ship.currentPath.removeAt(0).coord);
        if (result == MoveResult.impCollision) { //fm.movementController.vectorShip(ship, Rng.rndUnitVector(fm.rnd));
          action(pilot, ActionType.movement, actionAuts: 10);
        }
      } else { //TODO: avoid hazards (if possible)
        fm.movementController.vectorShip(ship, Rng.rndUnitVector(fm.rnd));
      }
    }
  }

  void headTowards(GridCell cell) {}

  energyScoop() {
    Ship? ship = fm.playerShip;
    if (ship == null) {
      fm.msgController.addMsg("You're not in a ship."); return;
    }
    double amount = 50; //((ship.energyConvertor.value/(Rng.biasedRndInt(rnd,mean: 50, min: 25, max: 80))) * player.system.starClass.power).floor();
    fm.msgController.addMsg("Scooping class ${fm.player.system.starClass.name} star... gained ${ship.recharge(amount)} energy");
    fm.pilotController.action(fm.player,ActionType.energyScoop);
  }
}

