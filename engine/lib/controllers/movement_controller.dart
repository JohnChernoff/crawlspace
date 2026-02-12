import '../coord_3d.dart';
import '../grid.dart';
import '../location.dart';
import '../ship.dart';
import '../systems/engines.dart';
import 'fugue_controller.dart';
import 'pilot_controller.dart';

enum MoveResult {moved,impCollision,impEnter,noEngine,outOfEnergy,badDestination,unsafeDestination,error}

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
      if (ship.loc.level.shipsAt(destination).isNotEmpty) {
        return MoveResult.impCollision;
      }
      if (ship.pilot.safeMovement && destination.hazMap.entries
          .any((e) => !ship.pilot.safeList.contains(e.key) && e.value > 0)) {
        return MoveResult.unsafeDestination;
      }
    }
    final dist = ship.loc.cell.coord.distance(destination.coord);
    Engine? engine = switch(ship.loc) {
      SystemLocation() => ship.subEngine,
      ImpulseLocation() => ship.impEngine,
    };
    if (engine == null) {
      return MoveResult.noEngine;
    }
    final auts = (engine.baseAutPerUnitTraversal * dist).round(); //print("Auts: $auts");
    double energyRequired = baseEnergy * (1 / engine.efficiency) * dist;
    if (!ship.burnEnergy(energyRequired)) {
      return MoveResult.outOfEnergy;
    }
    ship.move(destination); //fm.glog("Moving ${ship.name} => $destination");
    final ships = ship.loc.level.shipsAt(destination);
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