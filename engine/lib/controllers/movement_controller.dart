import 'dart:async';
import 'package:crawlspace_engine/controllers/xeno_controller.dart';
import '../fugue_engine.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';
import '../ship/nav.dart';
import '../ship/ship.dart';
import 'fugue_controller.dart';
import 'pilot_controller.dart';

class MoveResult {
  final MoveResultType resultType;
  final MovementPreview? preview;
  const MoveResult(this.preview,this.resultType);
}

enum MoveResultType {
  moved,
  impCollision,
  impEnter,
  noEngine,
  inactiveEngine,
  outOfEnergy,
  badDestination,
  unsafeDestination,
  heldPosition,
  rejected,
  mapDoink,
  error;
  bool get moving => this == moved || this == unsafeDestination;
}

enum ThrottleMode {
  full(1.0),
  half(0.5),
  stop(0.0),
  drift(0.0);
  final double speedFactor;
  const ThrottleMode(this.speedFactor);
}

class MovementPreview {
  final GridCell? desiredCell;
  final GridCell? actualCell;
  final int auts;
  final double energyRequired;
  final bool engineFail;
  final double? emergencyDecel;
  final NavState newState;

  const MovementPreview({
    this.desiredCell,
    this.actualCell,
    this.auts = 1,
    this.energyRequired = 0,
    this.engineFail = false,
    this.emergencyDecel,
    required this.newState,
  });
}

class MovementController extends FugueController {
  bool npcFreeMovement = true;
  ThrottleMode _throttle = ThrottleMode.full;
  ThrottleMode get throttle => _throttle;
  void set throttle(ThrottleMode mode) {
    _throttle = mode;
    fm.msg("Throttle: $mode");
    fm.update();
  }
  /// Small passive stabilization so ships do not drift forever.

  MovementController(super.fm);

  Future<SpaceLocation?> acquireTarget(Coord3D v) {
    final loc = fm.player.loc;
    final c = loc.cell.coord.add(v);
    if (!loc.map.containsCoord(c)) return Future.value(null);
    fm.player.targetLoc = loc.withCell(loc.map[c]!);
    fm.setInputMode(InputMode.movementTarget);
    fm.msg("Select movement target (arrows to adjust, Enter to confirm)");
    targetCompleter = Completer();
    return targetCompleter!.future;
  }

  void vectorTarget(Coord3D v) {
    final loc = fm.player.targetLoc;
    if (loc == null) return;
    final c = loc.cell.coord.add(v);
    if (loc.map.containsCoord(c)) {
      fm.player.targetLoc = loc.withCell(loc.map[c]!);
      fm.update();
    }
  }

  void handleMove(Ship ship, Coord3D vec) {
    if (fm.inputMode == InputMode.main) {
      if (ship.loc.domain == Domain.impulse) {
        fm.movementController.acquireTarget(vec).then((loc) {
          if (loc != null) fm.movementController.moveShip(ship, loc);
        });
      } else {
        fm.movementController.vectorShip(ship,vec);
      }
    }
    else if (fm.inputMode.targeting) {
      fm.movementController.vectorTarget(vec);
    }
  }

  MoveResult? vectorShip(Ship ship, Coord3D v) { //TODO: normalize v?
    final loc = ship.loc.map[ship.loc.cell.coord.add(v)]?.loc;
    return (loc != null) ? moveShip(ship, loc) : null;
  }

  MoveResult moveShip(Ship ship,
      SpaceLocation desiredLocation, {
        double baseEnergy = 20,
        ThrottleMode? throttleOverride,
      }) {

    bool newtonian = ship.loc.domain == Domain.impulse;
    final result = reportMove(ship, desiredLocation, throttleOverride: throttleOverride, newtonian: newtonian);
    //fm.msg(result.resultType.name);

    if (result.preview?.engineFail ?? false) {
      fm.msg("Warning: engine failure");
    }

    if (result.resultType == MoveResultType.rejected) {
      fm.msg("${ship.name} is rejected from your folded space!");
    } else if ((result.preview?.emergencyDecel ?? 0) > 0) {
      String barrier = ship.loc.domain == Domain.system ? "The Oort Cloud" : "Impulse Wake Turbulence";
      fm.msg("${ship.name} crashes into $barrier, emergency deacceration: ${result.preview?.emergencyDecel}");
      ship.nav.setVelocity(0, 0, 0);
    } else {
      final nextCell = result.preview?.actualCell;
      if (nextCell != null) {
        if (result.resultType == MoveResultType.impEnter) {
          ship.move(ship.loc.withCell(nextCell), fm.shipRegistry); //even if its the same cell
          fm.layerTransitController.createAndEnterImpulse();
        } else if (nextCell != ship.loc.cell) {
          ship.move(ship.loc.withCell(nextCell), fm.shipRegistry);
        }
      }
    }
    print("Action AUTs: ${result.preview?.auts}");
    fm.pilotController.action(ship.pilot, ActionType.movement, actionAuts: result.preview?.auts ?? 1);
    assert(ship.loc == ship.loc.cell.loc);
    fm.update();
    return result;
  }

  MoveResult reportMove(
      Ship ship,
      SpaceLocation? desiredLocation, {
        bool newtonian = true,
        ThrottleMode? throttleOverride,
      }) {

    if (desiredLocation == null) return MoveResult(null, MoveResultType.badDestination);

    final ThrottleMode actualThrottle = throttleOverride ?? throttle;

    // For NPCs with free movement, or non-Newtonian moves, use full preview
    // first and handle energy separately below.
    var preview = ship.nav.movePreviewer.moveUntilNextCell(
        desiredLocation.cell,
        throttle: actualThrottle,
        newtonian: newtonian
    );

    print("Energy: ${ship.systemControl.getCurrentEnergy()} ${preview.energyRequired}");
    bool ignoreEngineFail = true;
    if (newtonian && (!ship.npc || !npcFreeMovement)) {
      final double available = ship.systemControl.getCurrentEnergy();
      if (available <= 0 && !ignoreEngineFail) {
        // Completely out of energy — coast as pure drift, engine flagged as failed.
        // In stop mode this means the ship can no longer brake; it will overshoot.
        preview = ship.nav.movePreviewer.previewFixedStep(
            state: NavState.fromShip(ship),
            ctx: MoveContext.fromShip(ship),
            desiredCell: desiredLocation.cell,
            throttle: actualThrottle,
            newtonian: newtonian,
            drift: true);
        if (actualThrottle == ThrottleMode.stop) {
          fm.msg("Warning: out of energy, cannot complete braking burn!");
        }
      } else if (available < preview.energyRequired && preview.energyRequired > 0 && !ignoreEngineFail) {
        // Partial energy — scale thrust proportionally, cost is exactly what's available.
        final double thrustFraction = available / preview.energyRequired;
        preview = ship.nav.movePreviewer.previewFixedStep(
            state: NavState.fromShip(ship),
            ctx: MoveContext.fromShip(ship),
            desiredCell: desiredLocation.cell,
            throttle: actualThrottle,
            newtonian: newtonian,
            thrustFraction: thrustFraction,
            energyOverride: available);
        ship.systemControl.burnEnergy(available);
      } else {
        ship.systemControl.burnEnergy(preview.energyRequired);
      }
    } else if (!ship.npc || !npcFreeMovement) {
      // Non-Newtonian: binary — either afford it or stay put.
      if (!ship.systemControl.burnEnergy(preview.energyRequired)) {
        fm.msg("Insufficient energy");
        preview = MovementPreview(
            desiredCell: desiredLocation.cell,
            actualCell: ship.loc.cell,
            energyRequired: 0,
            newState: NavState.fromShip(ship),
            auts: 1
        );
      }
    } else {
      // NPC free movement — burn what we can, don't penalise.
      ship.systemControl.burnEnergy(preview.energyRequired);
    }
    print("AUTs: ${preview.auts}");
    ship.nav.heading = desiredLocation;
    ship.nav.setVelocity(
        preview.newState.vel.x,
        preview.newState.vel.y,
        preview.newState.vel.z);
    ship.nav.pos = preview.newState.pos;

    // Clear heading and zero velocity on arrival for stop mode (engine must
    // not have failed, otherwise the ship couldn't execute its braking burn).
    final bool arrived = preview.actualCell == desiredLocation.cell;
    if (arrived && actualThrottle == ThrottleMode.stop && !preview.engineFail) {
      ship.nav.heading = null; // also clears isBraking via the heading setter
      ship.nav.setVelocity(0, 0, 0);
    }

    final newCell = preview.actualCell;
    if (newCell == null) return MoveResult(preview,MoveResultType.error);
    if (ship.loc.domain == Domain.impulse) {
      if (fm.shipRegistry.atCell(newCell).isNotEmpty) {
        return MoveResult(preview,MoveResultType.impCollision); //TODO: fix
      }
      if (ship.pilot.safeMovement &&
          newCell.hazMap.entries.any((e) =>
          !ship.pilot.safeList.contains(e.key) && e.value > 0)) {
        return MoveResult(preview,MoveResultType.unsafeDestination);
      }
    } else if (ship.loc.domain == Domain.system) {
      final playerEncounter =
          (ship.playship && fm.shipRegistry.atCell(newCell).any((s) => s.npc)) ||
              (ship.npc && fm.shipRegistry.atCell(newCell).contains(fm.playerShip));
      if (playerEncounter) {
        if (ship.npc && fm.playerShip!.activeEffect(ShipEffect.folding)) {
          return MoveResult(preview, MoveResultType.rejected);
        }
        return MoveResult(preview, MoveResultType.impEnter);
      }
    }
    if (newCell != ship.loc.cell) {
      return MoveResult(preview,MoveResultType.moved);
    }
    return MoveResult(preview, MoveResultType.heldPosition);
  }

  void cruise(Ship? ship) {
    if (ship == null) return;

    if (ship.nav.heading == null || ship.loc.cell == ship.nav.heading?.cell) {
      print("arrived");
      ship.nav.heading = null;
      ship.nav.isBraking = false;
      ship.nav.setVelocity(0, 0, 0); // for stop/cruise arrival
      loiter(ship);
      return;
    }
    final result = moveShip(ship, ship.nav.heading!.cell.loc);
    print("current     = ${ship.loc.cell.coord}");
    print("heading     = ${ship.nav.heading?.cell.coord}");
    print("desiredCell = ${result.preview?.desiredCell?.coord}");
    print("actualCell  = ${result.preview?.actualCell?.coord}");
  }

  void loiter(Ship? ship, {int auts = 10}) { //TODO: what happens if ship is moving?
    if (ship != null) fm.pilotController.action(ship.pilot, ActionType.movement, actionAuts: auts);
  }
}
