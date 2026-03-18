import 'dart:math';

import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import 'nav.dart';

class GuidanceResult {
  final Vec3 desiredVelocity;
  final double closingSpeed;
  final double lateralSpeed;
  final double stopSpeed;
  final double horizon;

  const GuidanceResult({
    required this.desiredVelocity,
    required this.closingSpeed,
    required this.lateralSpeed,
    required this.stopSpeed,
    required this.horizon,
  });

  @override
  String toString() =>
      "close:${closingSpeed.toStringAsFixed(2)} "
      "lat:${lateralSpeed.toStringAsFixed(2)} "
      "stop:${stopSpeed.toStringAsFixed(2)} "
      "T:${horizon.toStringAsFixed(2)} "
      "dv:[${desiredVelocity.x.toStringAsFixed(2)},"
      "${desiredVelocity.y.toStringAsFixed(2)},"
      "${desiredVelocity.z.toStringAsFixed(2)}]";
}

class AutoPilot {

  GuidanceResult computeGuidanceVelocity({
    required Position pos,
    required Vec3 vel,
    required GridCell targetCell,
    required double fAccel,
    required double lAccel,
    required double rAccel,
    required double maxSpeed,
    double desiredArrivalSpeed = 0,
    double lateralWeight = 1.5, //double lateralWeight = 1.0;
    double minHorizon = 1.5, //1-2
    double maxHorizon = 6.0, //4-8
  }) {
    final pv = Vec3(pos.x, pos.y, pos.z);
    final tv = Position.fromCoord(targetCell.coord);
    final target = Vec3(tv.x,tv.y,tv.z);

    final r = target - pv;
    final d = r.mag;

    if (d <= 1e-9) {
      return const GuidanceResult(
        desiredVelocity: Vec3(0, 0, 0),
        closingSpeed: 0,
        lateralSpeed: 0,
        stopSpeed: 0,
        horizon: 0,
      );
    }

    final dir = r.normalized();

    final closing = vel.dot(dir);
    final lateral = vel - (dir * closing);
    final lateralSpeed = lateral.mag;

    final speedNow = vel.mag;

    // Estimate a short planning horizon.
    final rawHorizon = d / max(speedNow, 0.25);
    final T = rawHorizon.clamp(minHorizon, maxHorizon);

    // Velocity that would intercept in T if unconstrained.
    final interceptVelocity = r * (1.0 / T);

    // Braking-limited safe closing speed.
    final stopSpeed = sqrt(max(0.0, 2.0 * max(rAccel, 0.001) * d));

    // For stop mode (desiredArrivalSpeed == 0) clamp to stopSpeed so we never
    // approach faster than we can brake.  For full/half throttle
    // (desiredArrivalSpeed > 0) we want to close at up to maxSpeed — the
    // stopSpeed guard is intentionally dropped so the ship actually accelerates
    // toward the target instead of pre-braking from the first tick.
    final double desiredClosing = desiredArrivalSpeed > 0
        ? min(interceptVelocity.mag, maxSpeed)
        : min(interceptVelocity.mag, stopSpeed);
    final clampedClosing = max(desiredArrivalSpeed, min(desiredClosing, maxSpeed));

    // Desired velocity points toward the target,
    // but we bias away from lateral drift.
    final desiredCore = dir * clampedClosing;

    // Subtract weighted lateral velocity to kill side-slip.
    Vec3 desired = desiredCore - (lateral * lateralWeight);

    final desiredMag = desired.mag;
    if (desiredMag > maxSpeed && desiredMag > 0) {
      desired = desired * (maxSpeed / desiredMag);
    }

    return GuidanceResult(
      desiredVelocity: desired,
      closingSpeed: max(0.0, closing),
      lateralSpeed: lateralSpeed,
      stopSpeed: stopSpeed,
      horizon: T,
    );
  }

  double settleAxis(double v, double accel) {
    if (v.abs() <= accel) return 0;
    return v - v.sign * accel;
  }

  Vec3 steerVelocityTowardDirectional({
    required Vec3 current,
    required Vec3 desired,
    required Vec3 forwardDir,
    required double fAccel,
    required double lAccel,
    required double rAccel,
    required double stabilization,
    required double maxSpeed,
    required lockX,
    required lockY,
    required lockZ,
  }) {
    final delta = desired - current;

    final along = delta.dot(forwardDir);
    //where do I use settleAxis?
    final forwardPart = forwardDir * max(0.0, along);
    final reversePart = forwardDir * min(0.0, along);
    final lateralPart = delta - (forwardDir * along);

    Vec3 applied = const Vec3(0, 0, 0);

    if (forwardPart.mag > 1e-9) {
      applied = applied + forwardPart.normalized() * min(fAccel, forwardPart.mag);
    }
    if (reversePart.mag > 1e-9) {
      applied = applied + reversePart.normalized() * min(rAccel, reversePart.mag);
    }
    if (lateralPart.mag > 1e-9) {
      applied = applied + lateralPart.normalized() * min(lAccel, lateralPart.mag);
    }

    var next = (current + applied) * stabilization;

    // Apply settling on locked axes
    double nx = next.x;
    double ny = next.y;
    double nz = next.z;

    if (lockX) nx = settleAxis(nx, lAccel); // or fAccel/rAccel depending on taste
    if (lockY) ny = settleAxis(ny, lAccel);
    if (lockZ) nz = settleAxis(nz, lAccel);
    next = Vec3(nx, ny, nz);

    final m = next.mag;
    if (m > maxSpeed && m > 0) {
      next = next * (maxSpeed / m);
    }
    return next;
  }

  bool wouldLeaveMapSoon({
    required Position pos,
    required Vec3 vel,
    required CellMap map,
    int steps = 4,
  }) {
    var p = pos;
    for (int i = 0; i < steps; i++) {
      p = Position(p.x + vel.x, p.y + vel.y, p.z + vel.z);
      if (map[p.coord] == null) return true;
    }
    return false;
  }
}

