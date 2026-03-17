import 'dart:math';
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

  MovementPreview previewMove(GridCell? desiredCell, {
    double? baseEnergy,
    ThrottleMode throttle = ThrottleMode.full,
    bool drift = false,
    bool newtonian = true,
    double thrustFraction = 1.0,
    double? energyOverride,
  }) {
    if (desiredCell == null) return const MovementPreview(desiredCell: null);
    final desiredCoord = desiredCell.coord;

    Engine? engine = (throttle == ThrottleMode.drift || drift)
        ? null
        : ship.systemControl.getEngine(ship.loc.domain);
    final noEngine = engine == null;
    final bool engineFail = noEngine && throttle != ThrottleMode.drift;

    // Energy cost = thrust / efficiency per cell moved.
    // This is the physical work done by the engine regardless of generator
    // output — if the ship can't afford it, thrustFraction reduces both
    // thrust and cost proportionally in reportMove.
    double energyForAuts(int auts, double efficiency) {
      if (noEngine) return 0;
      if (energyOverride != null) return energyOverride;



      if (baseEnergy != null) return baseEnergy / efficiency;
      return engine.thrust / efficiency;
    }

    // ── Non-Newtonian (hyperspace / system-map) path ──────────────────────
    if (!newtonian) {
      if (engine != null) {
        final double distance = ship.loc.distCell(desiredCell);
        final int travelAuts = (engine.baseAutPerUnitTraversal * distance).round();
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: desiredCell,
          auts: travelAuts,
          energyRequired: energyForAuts(travelAuts, engine.efficiency),
        );
      } else {
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: ship.loc.cell,
          engineFail: true,
        );
      }
    }

    // ── Newtonian (impulse) path ───────────────────────────────────────────

    final dx = desiredCoord.x - ship.loc.cell.coord.x;
    final dy = desiredCoord.y - ship.loc.cell.coord.y;
    final dz = desiredCoord.z - ship.loc.cell.coord.z;

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
    final int baseAUT = engine?.baseAutPerUnitTraversal ?? 10;
    final double efficiency = engine?.efficiency ?? 0.1;

    // Start from current velocity — no damping yet.
    double vx = nav.velX;
    double vy = nav.velY;
    double vz = nav.velZ;

    // nextVel is what gets written into newVelX/Y/Z (saved for next tick).
    // For most modes it equals vx/vy/vz, but for stop mode we separate
    // "where does momentum carry us this tick" from "how much speed do we
    // shed for next tick", so the ship coasts to the destination rather
    // than freezing on the very next cell.
    double nextVelX = vx;
    double nextVelY = vy;
    double nextVelZ = vz;

    if (throttle == ThrottleMode.stop) {
      if (mag == 0) {
        nav.isBraking = false;
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: ship.loc.cell,
          auts: 1,
          energyRequired: 0,
          newVelX: 0,
          newVelY: 0,
          newVelZ: 0,
        );
      }

      final guidance = nav.computeGuidanceVelocity(
        targetCell: desiredCell,
        fAccel: fAccel,
        lAccel: lAccel,
        rAccel: rAccel,
        maxSpeed: maxSpeed,
        desiredArrivalSpeed: 0,
      );

      final current = Vec3(vx, vy, vz);
      final targetDir = Vec3(dirX, dirY, dirZ); //or possibly ship facing

      final cx = ship.loc.cell.coord.x;
      final cy = ship.loc.cell.coord.y;
      final cz = ship.loc.cell.coord.z;

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
        stabilization: nav.stabilization,
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
        targetCell: desiredCell,
        fAccel: fAccel,
        lAccel: lAccel,
        rAccel: rAccel,
        maxSpeed: maxSpeed,
        desiredArrivalSpeed: maxSpeed, // full wants speed, not stop
      );

      final current = Vec3(vx, vy, vz);
      final targetDir = Vec3(dirX, dirY, dirZ); //or possibly ship facing

      final next = nav.steerVelocityTowardDirectional(
        current: current,
        desired: guidance.desiredVelocity,
        forwardDir: targetDir,
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

    final Coord3D fallback = noEngine
        ? const Coord3D(0, 0, 0)
        : Coord3D(dx.sign.toInt(), dy.sign.toInt(), dz.sign.toInt());

    final Coord3D finalStep =
    _stepFromVelocity(vx, vy, vz, fallback: fallback ,allowFallback: false);

    // ── Same-cell result (speed too low to cross a cell boundary) ─────────
    if (finalStep.x == 0 && finalStep.y == 0 && finalStep.z == 0) {
      //final int sameAuts = max(1, (baseAUT * 0.25).round());
      return MovementPreview(
        desiredCell: desiredCell,
        actualCell: ship.loc.cell,
        auts: auts,
        energyRequired: energyForAuts(auts, efficiency),
        newVelX: nextVelX,
        newVelY: nextVelY,
        newVelZ: nextVelZ,
      );
    }

    final Coord3D actualCoord = ship.loc.cell.coord.add(finalStep);
    final GridCell? actualCell = ship.loc.map[actualCoord];

    // ── Off-map collision: emergency stop ─────────────────────────────────
    if (actualCell == null) {
      final double attemptedSpeed =
      sqrt((vx * vx) + (vy * vy) + (vz * vz));
      return MovementPreview(
        desiredCell: desiredCell,
        actualCell: ship.loc.cell,
        auts: 1,
        energyRequired: energyForAuts(1, efficiency),
        emergencyDecel: attemptedSpeed,
        engineFail: engineFail,
        newVelX: 0,
        newVelY: 0,
        newVelZ: 0,
      );
    }

    // ── Normal move ───────────────────────────────────────────────────────

    // Bug fix #3: floor forwardSpeed relative to current speed so that
    // sideways drift / turns don't produce absurdly large AUT counts.
    final double stepMag = sqrt((finalStep.x * finalStep.x) +
        (finalStep.y * finalStep.y) +
        (finalStep.z * finalStep.z));
    final double stepDirX = finalStep.x / stepMag;
    final double stepDirY = finalStep.y / stepMag;
    final double stepDirZ = finalStep.z / stepMag;

    final double rawForward =
        (vx * stepDirX) + (vy * stepDirY) + (vz * stepDirZ);
    final double currentSpeed =
    sqrt((vx * vx) + (vy * vy) + (vz * vz));
    // Floor at 30 % of actual speed so turning/strafing AUTs stay sane.
    final double forwardSpeed = max(currentSpeed * 0.3, max(rawForward, 0.01));

    final double dist = ship.loc.distCell(actualCell);
    final int auts = max(1, (baseAUT * dist / forwardSpeed).round());

    final energyScale = 1;
    final dvx = nextVelX - ship.nav.velX;
    final dvy = nextVelY - ship.nav.velY;
    final dvz = nextVelZ - ship.nav.velZ;
    final deltaV = sqrt((dvx * dvx) + (dvy * dvy) + (dvz * dvz));
    final energy = engine != null ? (ship.currentMass * deltaV * energyScale) / engine.efficiency : 0;

    return MovementPreview(
      desiredCell: desiredCell,
      actualCell: actualCell,
      auts: auts,
      energyRequired: energy.toDouble(), //energyForAuts(auts, efficiency),
      newVelX: nextVelX,
      newVelY: nextVelY,
      newVelZ: nextVelZ,
      engineFail: engineFail,
    );
  }

  /// Converts a velocity vector into a discrete grid step.
  ///
  /// Bug fix #2: raised keepFactor from 0.6 → 0.85 so that ships moving
  /// mostly along one axis don't accidentally step diagonally.  A component
  /// must be at least 85 % of the dominant component to be included,
  /// preventing unintended diagonal movement (which covers more distance
  /// than a cardinal step and breaks AUT accounting).
  Coord3D _stepFromVelocity(
      double vx,
      double vy,
      double vz, {
        Coord3D? fallback,
        bool allowFallback = true,
      }) {
    final double ax = vx.abs();
    final double ay = vy.abs();
    final double az = vz.abs();
    final double maxAbs = max(ax, max(ay, az));

    if (maxAbs < 0.05) {
      if (allowFallback && fallback != null) return fallback;
      return const Coord3D(0, 0, 0);
    }

    const double keepFactor = 0.85;
    int sx = 0, sy = 0, sz = 0;

    if (ax >= maxAbs * keepFactor) sx = vx > 0 ? 1 : -1;
    if (ay >= maxAbs * keepFactor) sy = vy > 0 ? 1 : -1;
    if (az >= maxAbs * keepFactor) sz = vz > 0 ? 1 : -1;

    return Coord3D(sx, sy, sz);
  }

}

