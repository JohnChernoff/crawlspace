import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/ship/move_preview.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';

class Waypoint {
  final Coord3D coord;
  final double maxVelocity;
  const Waypoint(this.coord,this.maxVelocity);
}
//List<Waypoint> wayPoints = [];

class _ArrivalNode {
  final Coord3D coord;
  final double allowedSpeed;
  const _ArrivalNode(this.coord, this.allowedSpeed);
}

typedef BrakeField = Map<Coord3D, double>;

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
  late MovePreviewer movePreviewer = MovePreviewer(this.ship);
  SpaceLocation? _heading;
  SpaceLocation? get heading => _heading;
  set heading(SpaceLocation? h) {
    if (h != _heading) {
      isBraking = false;
      _cachedBrakeField = null;
      _cachedBrakeFieldDest = null;
      _cachedBrakeFieldBrakeAccel = null;
      _cachedBrakeFieldMaxSpeed = null;
    }
    _heading = h;
  }

  double get effectiveMass => max(ship.currentMass, 0.001);
  double get controlInertia => pow(effectiveMass * ship.volume, 0.5).toDouble();

  double baseForwardAccel(double thrust) => thrust / effectiveMass;
  double baseLateralAccel(double thrust) => thrust / controlInertia;
  double baseReverseAccel(double thrust) => thrust / controlInertia;

  double forwardAccel(double thrust) =>
      baseForwardAccel(thrust) *
          ship.shipClass.engineArch.forwardFactor *
          ship.shipClass.handling;

  double lateralAccel(double thrust) =>
      baseLateralAccel(thrust) *
          ship.shipClass.engineArch.lateralFactor *
          ship.shipClass.handling;

  double reverseAccel(double thrust) =>
      baseReverseAccel(thrust) *
          ship.shipClass.engineArch.reverseFactor *
          ship.shipClass.handling;

  BrakeField? _cachedBrakeField;
  Coord3D? _cachedBrakeFieldDest;
  double? _cachedBrakeFieldBrakeAccel;
  double? _cachedBrakeFieldMaxSpeed;

  BrakeField getBrakeField({
    required GridCell destination,
    required double brakeAccel,
    required double maxSpeed,
    double goalSpeed = 0,
  }) {
    final dest = destination.coord;
    final sameDest = _cachedBrakeFieldDest == dest;
    final sameBrake = _cachedBrakeFieldBrakeAccel != null &&
        (_cachedBrakeFieldBrakeAccel! - brakeAccel).abs() < 1e-9;
    final sameMax = _cachedBrakeFieldMaxSpeed != null &&
        (_cachedBrakeFieldMaxSpeed! - maxSpeed).abs() < 1e-9;

    if (_cachedBrakeField != null && sameDest && sameBrake && sameMax) {
      return _cachedBrakeField!;
    }

    final field = buildArrivalSpeedField(
      destination: destination,
      goalSpeed: goalSpeed,
      brakeAccel: brakeAccel,
      maxSpeed: maxSpeed,
    );

    _cachedBrakeField = field;
    _cachedBrakeFieldDest = dest;
    _cachedBrakeFieldBrakeAccel = brakeAccel;
    _cachedBrakeFieldMaxSpeed = maxSpeed;
    return field;
  }

  /*
  final field = buildArrivalSpeedField(
    destination: targetCell,
    goalSpeed: 0,
    brakeAccel: reverseAccel(engine.thrust),
    maxSpeed: engine.maxSpeed,
  );*/

  double? allowedArrivalSpeed(BrakeField field, Coord3D coord) {
    return field[coord];
  }

  BrakeField buildArrivalSpeedField({
    required GridCell destination,
    required double goalSpeed,
    required double brakeAccel,
    required double maxSpeed,
  }) {
    final field = <Coord3D, double>{};

    final queue = PriorityQueue<_ArrivalNode>(
          (a, b) => b.allowedSpeed.compareTo(a.allowedSpeed),
    );

    field[destination.coord] = goalSpeed.clamp(0.0, maxSpeed);
    queue.add(_ArrivalNode(destination.coord, field[destination.coord]!));

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      final current = node.coord;

      // Skip stale queue entries.
      final currentAllowed = field[current];
      if (currentAllowed == null || node.allowedSpeed < currentAllowed) continue;

      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          for (int dz = -1; dz <= 1; dz++) {
            if (dx == 0 && dy == 0 && dz == 0) continue;

            final prev = current.add(Coord3D(dx, dy, dz));
            final prevCell = destination.map[prev];
            if (prevCell == null) continue;

            // Optional: skip blocked cells here if needed.
            // if (prevCell.blocked) continue;

            final stepDist = sqrt((dx * dx) + (dy * dy) + (dz * dz));

            final prevAllowed = min(
              sqrt((currentAllowed * currentAllowed) + (2 * brakeAccel * stepDist)),
              maxSpeed,
            );

            final old = field[prev];
            if (old == null || prevAllowed > old) {
              field[prev] = prevAllowed;
              queue.add(_ArrivalNode(prev, prevAllowed));
            }
          }
        }
      }
    }

    return field;
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


  GuidanceResult computeGuidanceVelocity({
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
    final pos = Vec3(
      ship.loc.cell.coord.x.toDouble(),
      ship.loc.cell.coord.y.toDouble(),
      ship.loc.cell.coord.z.toDouble(),
    );

    final target = Vec3(
      targetCell.coord.x.toDouble(),
      targetCell.coord.y.toDouble(),
      targetCell.coord.z.toDouble(),
    );

    final vel = Vec3(velX, velY, velZ);

    final r = target - pos;
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

    // Use desired arrival speed if you want nonzero terminal speed later.
    final desiredClosing = min(interceptVelocity.mag, stopSpeed);
    //final desiredClosing = min(maxSpeed, max(desiredArrivalSpeed, min(interceptVelocity.mag, maxSpeed))); //for full
    final clampedClosing = min(desiredClosing, maxSpeed);

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


  String velocityString({int digits = 4}) =>
      '[${velX.toStringAsFixed(digits)}, '
          '${velY.toStringAsFixed(digits)}, '
          '${velZ.toStringAsFixed(digits)}]';
}


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
}


