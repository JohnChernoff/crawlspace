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
  SpaceLocation? _heading;
  SpaceLocation? get heading => _heading;
  set heading(SpaceLocation? h) {
    if (h != _heading) {
      isBraking = false; // reset braking state when heading changes
    }
    _heading = h;
  }

  /// Sticky braking flag for throttle.stop — once set, the ship keeps
  /// braking until stopped, preventing oscillation between brake/accelerate.
  bool isBraking = false;
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

    // Energy cost helper — called once auts are known.
    // Cost = auts * rechargePerAut * drainFactor / efficiency
    // drainFactor 1.5 means movement costs 150% of what you'd regenerate
    // in the same time, so sustained travel is a real but not crippling drain.
    // The baseEnergy override bypasses this for non-Newtonian callers that
    // already have their own cost model.
    double energyForAuts(int auts, double efficiency) {
      if (noEngine) return 0;
      if (energyOverride != null) return energyOverride;
      if (baseEnergy != null) return baseEnergy * (1 / efficiency);
      final double rechargePerAut =
          ship.systemControl.getCurrentMaxEnergy() *
              (ship.systemControl.getPower()?.rechargeRate ?? 0);
      return 20; //auts * rechargePerAut * (1.5 / efficiency);
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
    final double accel = (thrust / max(ship.currentMass, 0.001)) * thrustFraction.clamp(0.0, 1.0);
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
      // If already on the destination cell, just zero velocity and return.
      if (mag == 0) {
        isBraking = false;
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
      // ── Two-phase burn: accelerate until braking distance, then brake ─────
      //
      // For the per-tick physics we work in terms of the immediate next step
      // direction (sign of delta to destination) rather than the full
      // destination vector.  This keeps velocity aligned with actual movement
      // and prevents the ship building up speed in a direction it then has to
      // fight.  mag (full remaining distance) is still used for the braking
      // phase decision so the two-phase profile works over the whole journey.

      // Immediate step direction — one cell toward destination.
      final double stepDX = dx.sign.toDouble();
      final double stepDY = dy.sign.toDouble();
      final double stepDZ = dz.sign.toDouble();
      final double stepMagImm = sqrt(stepDX*stepDX + stepDY*stepDY + stepDZ*stepDZ);
      final double immDirX = stepMagImm > 0 ? stepDX / stepMagImm : dirX;
      final double immDirY = stepMagImm > 0 ? stepDY / stepMagImm : dirY;
      final double immDirZ = stepMagImm > 0 ? stepDZ / stepMagImm : dirZ;

      // Decompose current velocity into forward (toward immediate step) and lateral.
      final double forwardComponent = vx * immDirX + vy * immDirY + vz * immDirZ;
      final double latVelX = vx - forwardComponent * immDirX;
      final double latVelY = vy - forwardComponent * immDirY;
      final double latVelZ = vz - forwardComponent * immDirZ;
      final double latSpeed =
      sqrt(latVelX * latVelX + latVelY * latVelY + latVelZ * latVelZ);

      // Cancel lateral velocity by up to accel this tick.
      double cvx = vx;
      double cvy = vy;
      double cvz = vz;
      if (latSpeed > 0) {
        final double cancelLat = min(accel, latSpeed);
        final double latScale = (latSpeed - cancelLat) / latSpeed;
        cvx = forwardComponent * immDirX + latVelX * latScale;
        cvy = forwardComponent * immDirY + latVelY * latScale;
        cvz = forwardComponent * immDirZ + latVelZ * latScale;
      }

      // Once the ship commits to braking it must not re-accelerate while
      // still carrying speed — doing so causes oscillation. isBraking is
      // sticky once set. Exception: if the ship has come to a full stop
      // (forwardSpeed == 0) and the remaining distance allows a safe single
      // acceleration step, allow it — otherwise the ship gets stuck short
      // of the destination.
      final double forwardSpeed = max(0.0, forwardComponent);
      final double speedIfAccel = min(forwardSpeed + accel, accel > 0 ? sqrt(2 * accel * mag) : maxSpeed);
      final double stopDistIfAccel = accel > 0 ? (speedIfAccel * speedIfAccel) / (2 * accel) : double.infinity;
      if (stopDistIfAccel >= mag) isBraking = true;
      // If stopped and one safe step remains, allow a fresh acceleration.
      if (forwardSpeed == 0 && stopDistIfAccel < mag) isBraking = false;
      final bool braking = isBraking;

      print("STOP mag:${mag.toStringAsFixed(2)} fwd:${forwardSpeed.toStringAsFixed(3)} accel:${accel.toStringAsFixed(3)} stopDistIfAccel:${stopDistIfAccel.toStringAsFixed(2)} braking:$braking brakingCap:${(accel>0?sqrt(2*accel*mag):0).toStringAsFixed(3)}");

      if (braking) {
        // Retrograde burn — reduce forward speed by accel.
        if (forwardSpeed > accel) {
          final double newForward = forwardSpeed - accel;
          nextVelX = newForward * immDirX + (cvx - forwardSpeed * immDirX);
          nextVelY = newForward * immDirY + (cvy - forwardSpeed * immDirY);
          nextVelZ = newForward * immDirZ + (cvz - forwardSpeed * immDirZ);
        } else {
          nextVelX = 0;
          nextVelY = 0;
          nextVelZ = 0;
          // Do NOT clear isBraking here — a stopped ship mid-journey must
          // stay in braking mode, not immediately re-accelerate.
          // isBraking is cleared only when heading changes or ship arrives.
        }
        // vx/vy/vz unchanged — momentum carries ship forward this tick.
      } else {
        // Acceleration phase — thrust in immediate step direction.
        double ax = cvx + immDirX * accel;
        double ay = cvy + immDirY * accel;
        double az = cvz + immDirZ * accel;
        ax *= stabilization;
        ay *= stabilization;
        az *= stabilization;

        // Cap speed to what the engine can stop from over remaining distance.
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
      final int sameAuts = max(1, (baseAUT * 0.25).round());
      return MovementPreview(
        desiredCell: desiredCell,
        actualCell: ship.loc.cell,
        auts: sameAuts,
        energyRequired: energyForAuts(sameAuts, efficiency),
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

    return MovementPreview(
      desiredCell: desiredCell,
      actualCell: actualCell,
      auts: auts,
      energyRequired: energyForAuts(auts, efficiency),
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