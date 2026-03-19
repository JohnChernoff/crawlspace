import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/controllers/xeno_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/ship/ship_sys.dart';
import '../galaxy/system.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/impulse.dart';
import '../galaxy/geometry/location.dart';
import '../menu.dart';
import '../actors/pilot.dart';
import '../rng/rng.dart';
import '../ship/ship.dart';
import '../ship/systems/ship_system.dart';
import '../ship/systems/weapons.dart';
import 'fugue_controller.dart';
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

  void castEffect(Pilot pilot) {
    final ship = fm.galaxy.ships.byPilot(pilot);
    if (ship != null) {
      fm.menuController.showMenu(
          () => fm.menuFactory.buildXenoMenu(pilot, action: (s) {
            final result = fm.xenoControl.generateEffect(s,ship);
            if (result != XenoResult.success) fm.msg(result.msg);
          }),
          headerTxt: "Effects: "
      );
    }
  }

  void showToggleSystemMenu(Ship ship) {
    fm.menuController.showMenu(headerTxt: "Toggle System", () => fm.menuFactory.buildSystemToggleMenu(ship));
  }

  void toggleSystem(ShipSystem? system, Ship ship, {bool? on, silent = false}) {
    if (system != null) {
      if (ship.systemControl.toggleSystem(system, on: on)) {
        if (!silent) fm.msgController.addMsg("${system.type.name}: ${system.active ? 'on' : 'off'}");
      } else {
        fm.msg("Cannot activate system (insufficient energy)");
      }
    }
  }

  ResultMessage uninstallSystem(ShipSystem system, Ship ship) {
    if (ship.systemControl.uninstallSystem(system)) {
      return const ResultMessage("Uninstalled",true);
    } else {
      return const ResultMessage("Couldn't uninstall",false);
    }
  }

  ResultMessage installSystem(Ship ship, ShipSystem system, {SystemSlot? slot}) {
    if (ship.inventory.all.contains(system)) {
      if (slot == null) {
        fm.menuController.showMenu(() => fm.menuFactory.buildInstallSlotMenu(ship,system),headerTxt: "Select Slot:");
        return const ResultMessage("Select a slot", true);
      } else { //print("hmm");
        final report = ship.systemControl.installSystem(system, slot: slot);
        if (report.result == InstallResult.success) {
          return ResultMessage("Installed at slot: ${slot.name}",true);
        } else {
          return ResultMessage("${report.result.name} slot: ${slot.name}",false);
        }
      }
    }
    return ResultMessage("System not found: $system",false);
  }

  //returns false if location domain changes
  bool action(Pilot pilot, ActionType actionType, { mod = 1.0, int? actionAuts }) {
    if (pilot == nobody) return true;
    if (pilot == fm.player && actionType.risk > 0 && fm.aiRnd.nextInt(255) < fm.player.fedLevel(fm.galaxy)) {
      //msgController.addMsg("You have a bad feeling about this...");
      if (fm.aiRnd.nextInt(128) < (max(actionType.risk - (actionType.dna ? fm.player.dnaScram : 0),1))) {
        //fm.heat(actionType.heat);
      }
    }
    final auts = ((actionAuts ?? actionType.baseAuts) * mod).round();
    pilot.auCooldown += auts;
    pilot.lastAct = actionType;
    Ship? ship = fm.getShip(pilot); if (ship != null) {
      for (final h in ship.loc.cell.hazMap.entries) {
        final msg = h.key.effectPerTurn(ship, auts, fm);
        if (msg != null) fm.msgController.addMsg(msg);
      }
    }
    fm.update();
    if (pilot == fm.player) return fm.runUntilNextPlayerTurn();
    return true;
  }

  void npcShipAct(Ship ship) {
    if (ship == fm.playerShip) return;
    ship.tick(fm: fm);
    Pilot pilot = ship.pilot; //print(pilot.name);
    if (pilot == nobody) return;
    if (pilot.ready) { //print("${ship.name}'s turn...");
      final hostile = pilot.setHostilityToPlayer(fm); //TODO: unset/refresh this somewhere?
      final playLoc = fm.playerShip != null ? ship.detect(fm.playerShip!) : null;
      if (playLoc != null && hostile && fm.galaxy.ships.atDomain(ship.loc).contains(fm.playerShip)) {
        final loc = ship.loc;
        final target = ship.nav.targetShip = fm.playerShip;
        if (target == null) {
          glog("Null NPC target",level: DebugLevel.Warning);
        } else if (loc is ImpulseLocation) {
            Weapon? w = ship.systemControl.primaryWeapon;
            if (w != null && ship.currentHullPercentage > (ship.pilot.faction.courage * 100)) {
              final r = w.accuracyRangeConfig.idealRange, d = ship.distance(l: playLoc); //print("${ship.name} combat...$r, $d");
              if ((r -d).abs() > 1) { //print("${ship.name} maneuvering...");
                final idealCells = ship.loc.map.values
                    .where((c) => (playLoc.distCell(c) - r).abs() < 1.5) //TODO: tweak acceptable range
                    .sorted((c1,c2) => ship.distance(c: c1.coord).compareTo(ship.distance(c: c2.coord)));
                ship.nav.currentPath = ship.loc.map.greedyPath(ship.loc.cell, idealCells.first, 3, fm.aiRnd); //print(ship.currentPath);
              } else {
                if (playLoc != target.loc) {
                  //print("${ship.name} cannot find ${fm.target?.name}"); //TODO: fallback strategy
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
              final idealCells = ship.loc.map.values
                  .sorted((c1,c2) => playLoc.distCell(c2).compareTo(playLoc.distCell(c1)));
              ship.nav.currentPath = ship.loc.map.greedyPath(ship.loc.cell, idealCells.first, 3, fm.aiRnd);
            }
        } else if (loc is SectorLocation) {
          ship.nav.currentPath = ship.loc.map.greedyPath(ship.loc.cell,target.loc.cell,3,fm.aiRnd, forceHaz: true); //print(ship.currentPath);
        }
      }
      if (ship.nav.currentPath.isNotEmpty) {
        final result = fm.movementController.moveShip(ship, ship.nav.currentPath.removeAt(0).loc); //print(result);
        if (result == MoveResultType.impCollision) { //fm.movementController.vectorShip(ship, Rng.rndUnitVector(fm.rnd));
          action(pilot, ActionType.movement, actionAuts: 10);
        }
      } else { //TODO: avoid hazards (if possible)
        fm.movementController.vectorShip(ship, Rng.rndUnitVector(fm.aiRnd));
      }
    }
  }

  void plotCourse(Pilot pilot,System system) {
    Ship? ship = fm.galaxy.ships.byPilot(pilot);
    if (ship != null) {
      ship.itinerary = fm.galaxy.topo.graph.path(pilot.system, system);
      fm.msgController.addMsg("Course plotted: ${ship.itinerary!.map((s) => s.name).reduce((i,l) => "${l} - ${i}")}");
    }
  }

  void headTowards(GridCell cell) {}

  energyScoop() {
    Ship? ship = fm.playerShip;
    if (ship == null) {
      fm.msgController.addMsg("You're not in a ship."); return;
    }
    double amount = 50; //((ship.energyConvertor.value/(Rng.biasedRndInt(rnd,mean: 50, min: 25, max: 80))) * player.system.starClass.power).floor();
    fm.msgController.addMsg("Scooping class ${fm.player.system.starClass.name} star... gained ${ship.systemControl.recharge(amount)} energy");
    fm.pilotController.action(fm.player,ActionType.energyScoop);
  }

  void scrap() { //print("Attempting to scrap");
    int m = 0;
    Ship? ship = fm.playerShip; if (ship != null) {
      final cell = ship.loc.cell; if (cell is ImpulseCell) {
        for (final i in List.of(cell.itemz)) {
          if (i is ShipSystem) {
            if (ship.addScrap(i)) {
              m++;
              fm.msgController.addMsg("Scrapping: ${i.name}");
              cell.removeItem(i,fm.galaxy.items);
            }
            else {
              fm.msgController.addMsg("Couldn't scrap: ${i.name}");
            }
          } else {
            m++;
            cell.removeItem(i,fm.galaxy.items);
            ship.inventory.add(i);
            fm.msgController.addMsg("Added: ${i.name}");
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

  void installSystemSelect(Ship ship, {bool uninstall = false}) {
    final available = fm.menuController.showMenu(() => uninstall
      ? fm.menuFactory.buildUninstallMenu(ship)
      : fm.menuFactory.buildInstallMenu(ship)); //show menu anyhow
    if (!available) fm.msgController.addMsg("No available system");
  }

  void hailShip(Ship ship) {

  }
}

