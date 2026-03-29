import 'dart:async';
import 'dart:math';
import 'package:crawlspace_engine/controllers/xeno_controller.dart';
import '../fugue_engine.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';
import '../ship/move_ctx.dart';
import '../ship/nav.dart';
import '../ship/ship.dart';
import '../ship/systems/engines.dart';
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

  /// Small passive stabilization so ships do not drift forever.

  MovementController(super.fm);

  void setThrottle(ThrottleMode mode, Ship ship) {
    ship.nav.throttle = mode;
    fm.msg("Throttle: $mode");
    fm.update();
  }

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
        if (ship.nav.autopilotOn) {
          fm.movementController.acquireTarget(vec).then((loc) {
            if (loc != null) {
              ship.nav.autoPilot.heading = loc;
              print(ship.systemControl.engine?.name);
              print("Current Loc: ${ship.loc.cell.coord} , New Heading: ${loc.cell.coord}");
              print("Mass: ${ship.currentMass}, Vol: ${ship.volume}, Thrust: ${ship.systemControl.engine?.thrust}, Throttle: ${ship.nav.throttle}");
              // Don't call moveShip directly — set the heading and hand off to
              // the turn engine.  tick() will call cruise()/moveShip when it runs.
              loiter(ship);
            }
          });
        } else {
          manualThrust(ship, direction: vec);
        }
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

  MoveResult moveShip(Ship ship, SpaceLocation desiredLocation, {
    ThrottleMode? throttleOverride,
    Vec3? preGravVel,
    bool drift = false,
  }) {
    final ctx = MoveContext.fromShip(ship,
      throttleOverride: throttleOverride,
      preGravVel: preGravVel,
      drift: drift,
    );
    final report = reportMove(ship, desiredLocation, ctx: ctx);
    final newLoc = report.preview?.actualCell?.loc;
    print("NewLoc: $newLoc");
    if (newLoc != null && ship.loc != newLoc) {
      ship.move(newLoc, fm.galaxy.ships);
      fm.update();
    } else { //TODO: make sensible
      print("Vel: ${ship.nav.vel}, ${ship.nav.vel.mag}");
      if (!ship.nav.moving) {
        ship.nav.autoStop = false;
        print("Handbrake off");
      }
    }
    return report;
  }

  MoveResult reportMove(Ship ship, SpaceLocation? desiredLocation, {
    required MoveContext ctx,
    bool ignoreEngineFail = false,
  }) {
    if (desiredLocation == null)
      return MoveResult(null, MoveResultType.badDestination);

    var preview = ctx.newtonian
        ? ship.nav.movePreviewer.previewFixedStep(
        state: NavState.fromShip(ship),
        ctx: ctx,
        desiredCell: desiredLocation.cell)
        : ship.nav.movePreviewer.moveUntilNextCell(
        desiredLocation.cell,
        ctx: ctx);

    //print("Tick: ${fm.auTick}, Energy: ${ship.systemControl.getCurrentEnergy()} ${preview.energyRequired}");
    // IMPORTANT: energy is burned here in reportMove, and moveUntilNextCell
    // already accumulates energyRequired across sub-steps for display.
    // The two MUST NOT both call burnEnergy — reportMove is the single point
    // of truth for actually spending energy.  If you ever disable ignoreEngineFail,
    // verify the partial-energy re-preview path doesn't burn twice (the
    // previewFixedStep call below is read-only; only the explicit burnEnergy
    // calls below this comment actually spend energy).
    if (ctx.newtonian && (!ship.npc || !npcFreeMovement)) {
      final double available = ship.systemControl.getCurrentEnergy();
      if (available <= 0 && !ignoreEngineFail) {
        // Completely out of energy — coast as pure drift, engine flagged as failed.
        // In stop mode this means the ship can no longer brake; it will overshoot.
        preview = ship.nav.movePreviewer.previewFixedStep(
            state: NavState.fromShip(ship),
            ctx: ctx.withoutEngine(),
            desiredCell: desiredLocation.cell);
        if (ctx.throttle == ThrottleMode.stop) {
          fm.msg("Warning: out of energy, cannot complete braking burn!");
        }
      } else if (available < preview.energyRequired && preview.energyRequired > 0 && !ignoreEngineFail) {
        // Partial energy — scale thrust proportionally, cost is exactly what's available.
        final double thrustFraction = available / preview.energyRequired;
        preview = ship.nav.movePreviewer.previewFixedStep(
            state: NavState.fromShip(ship),
            ctx: ctx.copyWith(thrustFraction: thrustFraction),
            desiredCell: desiredLocation.cell);
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
    } //print("AUTs: ${preview.auts}");

    ship.nav.setVelocity(
        preview.newState.vel.x,
        preview.newState.vel.y,
        preview.newState.vel.z);
    ship.nav.pos = preview.newState.pos;

    // Clear heading and zero velocity on arrival for stop mode (engine must
    // not have failed, otherwise the ship couldn't execute its braking burn).
    final bool arrived = preview.actualCell == desiredLocation.cell;
    if (arrived && ctx.throttle == ThrottleMode.stop && !preview.engineFail) {
      //if (ship.playship) fm.msg("Arrived...");
      //ship.nav.resetMotionState();
      //ship.nav.pos = Position.fromCoord(desiredLocation.cell.coord);
    }

    final newCell = preview.actualCell;
    if (newCell == null) return MoveResult(preview,MoveResultType.error);
    if (ship.loc.domain == Domain.impulse) {
      if (fm.galaxy.ships.atCell(newCell).isNotEmpty) {
        return MoveResult(preview,MoveResultType.impCollision); //TODO: fix
      }
      if (ship.pilot.safeMovement &&
          newCell.hazMap.entries.any((e) =>
          !ship.pilot.safeList.contains(e.key) && e.value > 0)) {
        return MoveResult(preview,MoveResultType.unsafeDestination);
      }
    } else if (ship.loc.domain == Domain.system) {
      final playerEncounter =
          (ship.playship && fm.galaxy.ships.atCell(newCell).any((s) => s.npc)) ||
              (ship.npc && fm.galaxy.ships.atCell(newCell).contains(fm.playerShip));
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

  void loiter(Ship? ship, {int? auts}) {
    if (ship != null) fm.pilotController.action(ship.pilot, ActionType.movement, actionAuts: auts ?? (ship.nav.moving ? 100 : 10));
  }

  void manualThrust(Ship ship, {Coord3D? direction, awaitNextCell = true}) {
    final thrust = ship.systemControl.engine?.thrust ?? 0;
    final accel = ship.nav.forwardAccel(thrust); // * ship.nav.throttle.speedFactor;
    final dir = direction != null
        ? ship.nav.effectiveThrustVector(direction)
        : ship.nav.vel;

    if (ship.shipClass.engineArch == EngineArch.center) {
      print("center thrust");
      // omnidirectional — thrust immediately
      final thrustVec = dir * accel;
      ship.nav.applyForce(thrustVec);
      fm.pilotController.action(ship.pilot, ActionType.movement, actionAuts: 10);
    } else { //print("Rear thrust");
      // rear/distributed — rotate first, then thrust
      final targetFacing = direction != null ? _dirToFacing(direction) : ship.nav.facing;
      ship.nav.targetFacing = targetFacing;
      ship.nav.pendingThrust = dir * accel;
      // no action AUTs yet — rotation tick handles them
    }
    if (awaitNextCell) loiter(ship);
  }

  void fullStop(Ship ship, {awaitNextCell = true}) {
    ship.nav.autoStop = true;
    if (awaitNextCell) loiter(ship, auts: 10);
  }

  double _dirToFacing(Coord3D dir) {
    // convert grid direction to degrees
    // matches _facingToVec: 0 = up = positive y, 90 = right = positive x
    return (atan2(dir.x.toDouble(), dir.y.toDouble()) * 180 / pi) % 360;
  }
}
