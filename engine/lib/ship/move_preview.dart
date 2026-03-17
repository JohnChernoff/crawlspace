import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import '../controllers/movement_controller.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import 'nav.dart';

class MovePreviewer {
  Ship ship;
  ShipNav get nav => ship.nav;
  MovePreviewer(this.ship);

  MovementPreview previewFixedStep({
    required NavState state,
    required MoveContext ctx,
    required GridCell? desiredCell,
    ThrottleMode throttle = ThrottleMode.full,
    bool drift = false,
    bool newtonian = true,
    double thrustFraction = 1.0,
    double? energyOverride,
  }) {
    const int auts = 1;
    if (desiredCell == null) return MovementPreview(desiredCell: null, newState: state);
    final desiredCoord = desiredCell.coord;

    Engine? engine = (throttle == ThrottleMode.drift || drift)
        ? null
        : ctx.engine;
    final noEngine = engine == null;
    final bool engineFail = noEngine && throttle != ThrottleMode.drift;

    // ── Non-Newtonian (hyperspace / system-map) path ──────────────────────
    if (!newtonian) {
      if (engine != null) {
        final double distance = ctx.currentCell.distCell(desiredCell);
        final int travelAuts = (engine.baseAutPerUnitTraversal * distance).round();
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: desiredCell,
          auts: travelAuts,
          energyRequired: engine.efficiency * 20, //TODO: fix
          newState: state.copyWith(pos: Position.fromCoord(desiredCell.coord)),
        );
      } else {
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: ctx.currentCell,
          engineFail: true,
          newState: state,
        );
      }
    }

    // ── Newtonian (impulse) path ───────────────────────────────────────────

    final dpos = Position.fromCoord(desiredCoord);
    final dx = dpos.x - state.pos.x;
    final dy = dpos.y - state.pos.y;
    final dz = dpos.z - state.pos.z;

    final mag = sqrt((dx * dx) + (dy * dy) + (dz * dz));
    final dirX = mag == 0 ? 0.0 : dx / mag;
    final dirY = mag == 0 ? 0.0 : dy / mag;
    final dirZ = mag == 0 ? 0.0 : dz / mag;

    final double thrust = engine?.thrust ?? 0;
    final double thrustScale = thrustFraction.clamp(0.0, 1.0);
    //final double accel = (thrust / max(ship.currentMass, 0.001)) * thrustFraction.clamp(0.0, 1.0);
    final double fAccel = noEngine ? 0.0 : nav.forwardAccel(thrust) * thrustScale;
    final double lAccel = noEngine ? 0.0 : nav.lateralAccel(thrust) * thrustScale;
    final double rAccel = noEngine ? 0.0 : nav.reverseAccel(thrust) * thrustScale;

    final double maxSpeed = engine?.maxSpeed ?? 0;
    final double efficiency = engine?.efficiency ?? 0.1;

    // Start from current velocity — no damping yet.
    double vx = state.vel.x;
    double vy = state.vel.y;
    double vz = state.vel.z;

    // nextVel is what gets written into newVelX/Y/Z (saved for next tick).
    // For most modes it equals vx/vy/vz, but for stop mode we separate
    // "where does momentum carry us this tick" from "how much speed do we
    // shed for next tick", so the ship coasts to the destination rather
    // than freezing on the very next cell.
    double nextVelX = vx;
    double nextVelY = vy;
    double nextVelZ = vz;

    if (throttle == ThrottleMode.stop) {
      if (mag == 0) { //if (mag < epsilon)
        bool nextIsBraking = state.isBraking;
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: ctx.currentCell,
          auts: 1,
          energyRequired: 0,
          newState: state.copyWith(isBraking: false),
        );
      }

      final guidance = nav.computeGuidanceVelocity(
        pos: state.pos,
        vel: state.vel,
        targetCell: desiredCell,
        fAccel: fAccel,
        lAccel: lAccel,
        rAccel: rAccel,
        maxSpeed: maxSpeed,
        desiredArrivalSpeed: 0,
      );

      final current = Vec3(vx, vy, vz);
      final targetDir = Vec3(dirX, dirY, dirZ); //or possibly ship facing

      final cx = ctx.currentCell.coord.x;
      final cy = ctx.currentCell.coord.y;
      final cz = ctx.currentCell.coord.z;

      final tx = desiredCell.coord.x;
      final ty = desiredCell.coord.y;
      final tz = desiredCell.coord.z;

      final lockX = cx == tx;
      final lockY = cy == ty;
      final lockZ = cz == tz;

      // Use whichever budget feels best.
      // For now, use forward accel as the main steering budget.
      final next = nav.steerVelocityTowardDirectional(
          current: current,
          desired: guidance.desiredVelocity,
          forwardDir: targetDir,
          fAccel: fAccel,
          lAccel: lAccel,
          rAccel: rAccel,
          // Don't pre-damp in stop mode — let the braking burn do all the work.
          // Using nav.stabilization here wastes thrust budget and can cause overshoot.
          stabilization: 1.0,
          maxSpeed: maxSpeed,
          lockX: lockX,
          lockY: lockY,
          lockZ: lockZ
      );

      nextVelX = next.x;
      nextVelY = next.y;
      nextVelZ = next.z;

      // In stop mode, use new velocity immediately for step choice.
      vx = next.x;
      vy = next.y;
      vz = next.z;

      print(
          "GUIDE d:${mag.toStringAsFixed(2)} "
              "close:${guidance.closingSpeed.toStringAsFixed(2)} "
              "lat:${guidance.lateralSpeed.toStringAsFixed(2)} "
              "stop:${guidance.stopSpeed.toStringAsFixed(2)} "
              "T:${guidance.horizon.toStringAsFixed(2)} "
              "dv:[${guidance.desiredVelocity.x.toStringAsFixed(2)},"
              "${guidance.desiredVelocity.y.toStringAsFixed(2)},"
              "${guidance.desiredVelocity.z.toStringAsFixed(2)}]"
      );
    } else if (!noEngine) {
      final guidance = nav.computeGuidanceVelocity(
        pos: state.pos,
        vel: state.vel,
        targetCell: desiredCell,
        fAccel: fAccel,
        lAccel: lAccel,
        rAccel: rAccel,
        maxSpeed: maxSpeed,
        desiredArrivalSpeed: maxSpeed, // full wants speed, not stop
        // Low lateral correction in full throttle — ships should arc toward
        // targets, not cancel all side-slip the way stop mode does.
        lateralWeight: 0.2,
      );

      final current = Vec3(vx, vy, vz);
      final targetDir = Vec3(dirX, dirY, dirZ);

      // Blend the target direction with the ship's current velocity direction.
      // This anchors the forward/lateral budget to where the ship is actually
      // going, not just where it wants to be — prevents oscillation when the
      // ship is nearly on-axis to the target.
      final velMag = current.mag;
      final blendedForward = velMag > 0.01
          ? (targetDir + current.normalized() * 0.4).normalized()
          : targetDir;

      final next = nav.steerVelocityTowardDirectional(
          current: current,
          desired: guidance.desiredVelocity,
          forwardDir: blendedForward,
          fAccel: fAccel,
          lAccel: lAccel,
          rAccel: rAccel,
          stabilization: nav.stabilization,
          maxSpeed: maxSpeed * throttle.speedFactor,
          lockX: false,
          lockY: false,
          lockZ: false
      );

      vx = next.x;
      vy = next.y;
      vz = next.z;
      nextVelX = vx;
      nextVelY = vy;
      nextVelZ = vz;
    }
    // else: pure drift — velocity unchanged, no drag, nextVel already set.

    final oldPos = state.pos;
    final newPos = Position(
      oldPos.x + vx * auts,
      oldPos.y + vy * auts,
      oldPos.z + vz * auts,
    );

    final Coord3D actualCoord = newPos.coord;
    final GridCell? actualCell = ctx.map[actualCoord];

    final dvx = nextVelX - state.vel.x;
    final dvy = nextVelY - state.vel.y;
    final dvz = nextVelZ - state.vel.z;
    final deltaV = sqrt((dvx * dvx) + (dvy * dvy) + (dvz * dvz));

    final energyScale = 1.0;
    final energy = engine != null
        ? (ship.currentMass * deltaV * energyScale) / engine.efficiency
        : 0.0;

    if (actualCell == null) {
      final attemptedSpeed = sqrt((vx * vx) + (vy * vy) + (vz * vz));
      final bounceCell = ctx.map.values.isEmpty ? ctx.currentCell
          : ctx.map.values
          .where((c) => c.coord.isEdge(ctx.map.size))
          .fold<GridCell>(ctx.map.values.first, (best, c) =>
      oldPos.coord.distance(c.coord) < oldPos.coord.distance(best.coord) ? c : best);
      print("CTX: ${ctx.map.runtimeType}");
      print("Bounce Cell: ${bounceCell.coord}");
      return MovementPreview(
        desiredCell: desiredCell,
        actualCell: bounceCell,
        auts: 1,
        energyRequired: energy,
        emergencyDecel: attemptedSpeed,
        engineFail: engineFail,
        newState: state.copyWith(pos: Position.fromCoord(bounceCell.coord)),
      );
    }

    return MovementPreview(
      desiredCell: desiredCell,
      actualCell: actualCell,
      auts: auts,
      energyRequired: energy,
      newState: state.copyWith(pos: newPos, vel: Vec3(nextVelX,nextVelY,nextVelZ)),
      engineFail: engineFail,
    );
  }

  MovementPreview previewMoves(
      GridCell? desiredCell, {
        ThrottleMode throttle = ThrottleMode.full,
        bool drift = false,
        bool newtonian = true,
        double thrustFraction = 1.0,
        double? energyOverride,
        int auts = 1,
      }) {
    var state = NavState.fromShip(ship);
    MovementPreview? last;

    var ctx = MoveContext(
      ship: ship,
      engine: (throttle == ThrottleMode.drift || drift)
          ? null
          : ship.systemControl.getEngine(ship.loc.domain),
      currentCell: ship.loc.cell,
      map: ship.loc.map,
    );

    for (int i = 0; i < auts; i++) {
      last = previewFixedStep(
        state: state,
        ctx: ctx,
        desiredCell: desiredCell,
        throttle: throttle,
        drift: drift,
        newtonian: newtonian,
        thrustFraction: thrustFraction,
        energyOverride: energyOverride,
      );

      state = last.newState;

      ctx = MoveContext(
        ship: ship,
        engine: ctx.engine,
        currentCell: last.actualCell ?? ctx.currentCell,
        map: ctx.map,
      );

      if (last.engineFail || last.emergencyDecel != null) break;
    }

    return last!;
  }

  MovementPreview moveUntilNextCell(
      GridCell? desiredCell, {
        ThrottleMode throttle = ThrottleMode.full,
        bool drift = false,
        bool newtonian = true,
        double thrustFraction = 1.0,
        double? energyOverride,
        int maxSteps = 50,
      }) {
    var state = NavState.fromShip(ship);
    final startCell = state.pos.coord;

    var ctx = MoveContext(
      ship: ship,
      engine: (throttle == ThrottleMode.drift || drift)
          ? null
          : ship.systemControl.getEngine(ship.loc.domain),
      currentCell: ship.loc.cell,
      map: ship.loc.map,
    );

    MovementPreview? last;
    int totalAuts = 0;
    double totalEnergy = 0.0;

    for (int i = 0; i < maxSteps; i++) {
      last = previewFixedStep(
        state: state,
        ctx: ctx,
        desiredCell: desiredCell,
        throttle: throttle,
        drift: drift,
        newtonian: newtonian,
        thrustFraction: thrustFraction,
        energyOverride: energyOverride,
      );

      totalAuts += last.auts;
      totalEnergy += last.energyRequired ?? 0.0;
      state = last.newState;

      ctx = MoveContext(
        ship: ship,
        engine: ctx.engine,
        currentCell: last.actualCell ?? ctx.currentCell,
        map: ctx.map,
      );

      if (last.engineFail || last.emergencyDecel != null) {
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: last.actualCell,
          auts: totalAuts,
          energyRequired: totalEnergy,
          emergencyDecel: last.emergencyDecel,
          engineFail: last.engineFail,
          newState: state,
        );
      }

      if (state.pos.coord != startCell) {
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: last.actualCell,
          auts: totalAuts,
          energyRequired: totalEnergy,
          engineFail: last.engineFail,
          newState: state,
        );
      }
    }

    return MovementPreview(
      desiredCell: desiredCell,
      actualCell: ctx.currentCell,
      auts: totalAuts,
      energyRequired: totalEnergy,
      engineFail: false,
      newState: state,
    );
  }
}
