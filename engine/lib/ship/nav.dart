import 'dart:math';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import '../controllers/movement_controller.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';

class ShipNav {
  Ship ship;
  double velX = 0;
  double velY = 0;
  double velZ = 0;
  Ship? _targetShip;
  Ship? get targetShip => ship.sameLevel(_targetShip) ? _targetShip : null;
  void set targetShip(Ship? ship) {
    _targetShip = ship;
  }
  Coord3D? targetCoord;
  List<GridCell> currentPath = [];
  Map<Ship, SpaceLocation> lastKnown = {};
  SpaceLocation? heading;
  /// True whenever the ship has a destination it hasn't reached yet.
  /// Does NOT gate on speed — a stopped ship in stop-mode still has a
  /// heading it needs to accelerate toward on the next cruise tick.
  bool get activeHeading => heading != null && heading!.cell != ship.loc.cell;

  /// Passive drag applied to powered ships each tick to prevent infinite drift.
  /// 0.98 = lose 2% of velocity per move when engines are running.
  /// Drifting ships (no engine) retain full momentum — they obey Newton.
  double stabilization = 0.98;

  double get speed => sqrt((velX * velX) + (velY * velY) + (velZ * velZ));

  void setVelocity(double x, double y, double z) {
    velX = x;
    velY = y;
    velZ = z;
  }

  void dampVelocity(double factor) {
    velX *= factor;
    velY *= factor;
    velZ *= factor;
  }

  ShipNav(this.ship);

  MovementPreview previewMove(GridCell? desiredCell, {
    double? baseEnergy,
    ThrottleMode throttle = ThrottleMode.full,
    bool drift = false,
    bool newtonian = true,
  }) {
    final baseUnitEnergy =
        baseEnergy ?? (ship.loc.domain == Domain.system ? 20 : 25);

    if (desiredCell == null) return const MovementPreview(desiredCell: null);
    final desiredCoord = desiredCell.coord;

    Engine? engine = (throttle == ThrottleMode.drift || drift)
        ? null
        : ship.systemControl.getEngine(ship.loc.domain);
    final noEngine = engine == null;
    final bool engineFail = noEngine && throttle != ThrottleMode.drift;

    // ── Non-Newtonian (hyperspace / system-map) path ──────────────────────
    if (!newtonian) {
      if (engine != null) {
        final double travelEnergy =
            (1 / engine.efficiency) * baseUnitEnergy * 0.5;
        final double distance = ship.loc.distCell(desiredCell);
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: desiredCell,
          auts: (engine.baseAutPerUnitTraversal * distance).round(),
          energyRequired: travelEnergy * distance,
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
    final double accel = thrust / max(ship.currentMass, 0.001);
    final double maxSpeed = engine?.maxSpeed ?? 0;
    final int baseAUT = engine?.baseAutPerUnitTraversal ?? 10;
    final double efficiency = engine?.efficiency ?? 0.1;

    // Start from current velocity — no damping yet.
    double vx = velX;
    double vy = velY;
    double vz = velZ;

    // nextVel is what gets written into newVelX/Y/Z (saved for next tick).
    // For most modes it equals vx/vy/vz, but for stop mode we separate
    // "where does momentum carry us this tick" from "how much speed do we
    // shed for next tick", so the ship coasts to the destination rather
    // than freezing on the very next cell.
    double nextVelX = vx;
    double nextVelY = vy;
    double nextVelZ = vz;

    if (throttle == ThrottleMode.stop) {
      // ── Two-phase burn: accelerate until braking distance, then brake ─────
      //
      // We decompose velocity into forward (toward target) and lateral
      // components.  Lateral velocity is cancelled by up to accel/tick so
      // the ship tracks straight to the target rather than drifting off-course
      // or into the map edge.  Stopping distance is computed from the forward
      // component only; the brakingCap guarantees the engine can always stop
      // in time given remaining distance.

      // Decompose current velocity into forward and lateral components.
      final double forwardComponent = mag > 0
          ? (vx * dirX + vy * dirY + vz * dirZ)
          : 0.0;
      final double latVelX = vx - forwardComponent * dirX;
      final double latVelY = vy - forwardComponent * dirY;
      final double latVelZ = vz - forwardComponent * dirZ;
      final double latSpeed =
      sqrt(latVelX * latVelX + latVelY * latVelY + latVelZ * latVelZ);

      // Cancel lateral velocity by up to accel this tick.
      double cvx = vx;
      double cvy = vy;
      double cvz = vz;
      if (latSpeed > 0) {
        final double cancelLat = min(accel, latSpeed);
        final double latScale = (latSpeed - cancelLat) / latSpeed;
        cvx = forwardComponent * dirX + latVelX * latScale;
        cvy = forwardComponent * dirY + latVelY * latScale;
        cvz = forwardComponent * dirZ + latVelZ * latScale;
      }

      // Stopping distance based on forward speed only.
      final double forwardSpeed = max(0.0, forwardComponent);
      final double stoppingDist =
      accel > 0 ? (forwardSpeed * forwardSpeed) / (2 * accel) : double.infinity;
      final bool braking = mag <= stoppingDist;

      if (braking) {
        // Retrograde burn — reduce forward speed by accel, keep lateral
        // cancellation already applied. Ship coasts on vx/vy/vz this tick.
        if (forwardSpeed > accel) {
          final double newForward = forwardSpeed - accel;
          nextVelX = newForward * dirX + (cvx - forwardSpeed * dirX);
          nextVelY = newForward * dirY + (cvy - forwardSpeed * dirY);
          nextVelZ = newForward * dirZ + (cvz - forwardSpeed * dirZ);
        } else {
          nextVelX = 0;
          nextVelY = 0;
          nextVelZ = 0;
        }
        // vx/vy/vz unchanged — momentum carries ship forward this tick.
      } else {
        // Acceleration phase — thrust toward target on lateral-corrected base.
        double ax = cvx + dirX * accel;
        double ay = cvy + dirY * accel;
        double az = cvz + dirZ * accel;
        ax *= stabilization;
        ay *= stabilization;
        az *= stabilization;

        // Cap speed to what the engine can actually stop from at this distance.
        // v_max = sqrt(2 * accel * mag) — solving stopping distance for v.
        final double brakingCap =
        accel > 0 ? sqrt(2 * accel * mag) : maxSpeed;
        final double effectiveCap = min(maxSpeed, brakingCap);
        final double newSpeed = sqrt((ax * ax) + (ay * ay) + (az * az));
        if (newSpeed > effectiveCap && effectiveCap > 0) {
          final double scale = effectiveCap / newSpeed;
          ax *= scale;
          ay *= scale;
          az *= scale;
        }
        nextVelX = ax;
        nextVelY = ay;
        nextVelZ = az;
        // Update vx/vy/vz so the step this tick reflects thrust + correction.
        vx = ax;
        vy = ay;
        vz = az;
      }
      // vx/vy/vz used below for step + AUT calculation.
    } else if (!noEngine) {
      // ── Powered flight: thrust toward target, then apply drag ─────────────
      // Bug fix #1: apply drag *after* thrust so the engine isn't fighting
      // itself, and only on powered ships (true drift = no drag).
      vx += dirX * accel;
      vy += dirY * accel;
      vz += dirZ * accel;

      // Drag / stabilization after thrust.
      vx *= stabilization;
      vy *= stabilization;
      vz *= stabilization;

      // Clamp to throttle-adjusted top speed.
      final double targetSpeed = maxSpeed * throttle.speedFactor;
      if (targetSpeed > 0) {
        final double newSpeed =
        sqrt((vx * vx) + (vy * vy) + (vz * vz));
        if (newSpeed > targetSpeed) {
          final double scale = targetSpeed / newSpeed;
          vx *= scale;
          vy *= scale;
          vz *= scale;
        }
      }
      // In powered mode next-tick velocity == this-tick velocity.
      nextVelX = vx;
      nextVelY = vy;
      nextVelZ = vz;
    }
    // else: pure drift — velocity unchanged, no drag, nextVel already set.

    final Coord3D fallback = noEngine
        ? const Coord3D(0, 0, 0)
        : Coord3D(dx.sign.toInt(), dy.sign.toInt(), dz.sign.toInt());

    final Coord3D finalStep =
    _stepFromVelocity(vx, vy, vz, fallback: fallback);

    // ── Same-cell result (speed too low to cross a cell boundary) ─────────
    if (finalStep.x == 0 && finalStep.y == 0 && finalStep.z == 0) {
      return MovementPreview(
        desiredCell: desiredCell,
        actualCell: ship.loc.cell,
        auts: max(1, (baseAUT * 0.25).round()),
        energyRequired: noEngine
            ? 0
            : baseUnitEnergy * (1 / efficiency) * 0.5,
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
        energyRequired: noEngine
            ? 0
            : baseUnitEnergy * (1 / efficiency) * 0.25,
        emergencyDecel: attemptedSpeed,
        engineFail: engineFail,
        // Caller should zero the ship's velocity on this result.
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

    // Bug fix #5: energy cost is based on distance + efficiency only.
    // Removed the (1 + accel * 0.25) term that punished light/fast ships.
    final double energyRequired = noEngine
        ? 0
        : baseUnitEnergy * (1 / efficiency) * dist;

    return MovementPreview(
      desiredCell: desiredCell,
      actualCell: actualCell,
      auts: auts,
      energyRequired: energyRequired,
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
  Coord3D _stepFromVelocity(double vx, double vy, double vz,
      {required Coord3D fallback}) {
    final double ax = vx.abs();
    final double ay = vy.abs();
    final double az = vz.abs();
    final double maxAbs = max(ax, max(ay, az));

    if (maxAbs < 0.05) return fallback;

    const double keepFactor = 0.85; // was 0.6
    int sx = 0, sy = 0, sz = 0;

    if (ax >= maxAbs * keepFactor) sx = vx > 0 ? 1 : -1;
    if (ay >= maxAbs * keepFactor) sy = vy > 0 ? 1 : -1;
    if (az >= maxAbs * keepFactor) sz = vz > 0 ? 1 : -1;

    return Coord3D(sx, sy, sz);
  }

  String velocityString({int digits = 4}) =>
      '[${velX.toStringAsFixed(digits)}, ${velY.toStringAsFixed(digits)}, ${velZ.toStringAsFixed(digits)}]';
}
