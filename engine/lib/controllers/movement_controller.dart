import '../coord_3d.dart';
import '../grid.dart';
import '../ship.dart';
import '../systems/engines.dart';
import 'fugue_controller.dart';
import 'pilot_controller.dart';

enum MoveResult {moved,impCollision,impEnter,noEngine,inactiveEngine,outOfEnergy,badDestination,unsafeDestination,error}

class MovementController extends FugueController {
  MovementController(super.fm);

  MoveResult vectorShip(Ship ship, Coord3D v) {
    return moveShip(ship, ship.loc.cell.coord.add(v));
  }

  MoveResult moveShip(Ship ship, Coord3D c, {double baseEnergy = 20}) {
    GridCell? destination = ship.loc.level.map.cells[c];
    if (destination == null) {
      return MoveResult.badDestination;
    }
    if (ship.loc.domain == Domain.impulse) {
      if (fm.shipRegistry.atCell(destination).isNotEmpty) {
        return MoveResult.impCollision;
      }
      if (ship.pilot.safeMovement && destination.hazMap.entries
          .any((e) => !ship.pilot.safeList.contains(e.key) && e.value > 0)) {
        return MoveResult.unsafeDestination;
      }
    }
    final dist = ship.loc.cell.coord.distance(destination.coord);
    Engine? engine = ship.systemControl.getEngine(ship.loc.domain);
    if (engine == null) return MoveResult.noEngine;
    if (!engine.active) return MoveResult.inactiveEngine; //engine.active = true; //auto activate
    final auts = (engine.baseAutPerUnitTraversal * dist).round(); //print("Auts: $auts");
    double energyRequired = baseEnergy * (1 / engine.efficiency) * dist;
    if (!ship.systemControl.burnEnergy(energyRequired)) {
      return MoveResult.outOfEnergy;
    }
    ship.move(ship.loc.withCell(destination),fm.shipRegistry); //fm.glog("Moving ${ship.name} => $destination");
    final ships = fm.shipRegistry.atCell(destination);
    if (ship.loc.domain == Domain.system && ships.length > 1 && ships.contains(fm.playerShip)) {
      fm.layerTransitController.createAndEnterImpulse(); //action?
      return MoveResult.impEnter;
    }
    fm.pilotController.action(ship.pilot, ActionType.movement,actionAuts: auts);
    return MoveResult.moved;
  }

  void loiter({int auts = 10}) {
    fm.pilotController.action(fm.player, ActionType.movement, actionAuts: auts);
  }

}