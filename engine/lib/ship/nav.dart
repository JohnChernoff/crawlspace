import 'dart:math';
import 'package:crawlspace_engine/ship/move_preview.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';

class NavState {
  final Position pos;
  final Vec3 vel;
  final bool isBraking;

  const NavState({
    required this.pos,
    required this.vel,
    required this.isBraking,
  });

  factory NavState.fromShip(Ship ship) => NavState(pos: ship.nav.pos, vel: ship.nav.vel, isBraking: ship.nav.isBraking);

  NavState copyWith({
    Position? pos,
    Vec3? vel,
    bool? isBraking,
  }) {
    return NavState(
      pos: pos ?? this.pos,
      vel: vel ?? this.vel,
      isBraking: isBraking ?? this.isBraking,
    );
  }
}

class MoveContext {
  final Ship ship;
  final Engine? engine;
  final GridCell currentCell;
  final CellMap map;

  const MoveContext({
    required this.ship,
    required this.engine,
    required this.currentCell,
    required this.map,
  });

  factory MoveContext.fromShip(Ship ship) => MoveContext(
      ship: ship,
      engine: ship.systemControl.engine,
      currentCell: ship.loc.cell,
      map: ship.loc.map);
}

class Position {
  final double x;
  final double y;
  final double z;
  const Position(this.x,this.y,this.z);
  factory Position.fromCoord(Coord3D c) =>
      Position(c.x.toDouble(), c.y.toDouble(), c.z.toDouble());

  //TODO: add operators?
  Coord3D get coord => Coord3D(
      (x + .5).floor(),
      (y + .5).floor(),
      (z + .5).floor());

  @override
  String toString() => "[${x.toStringAsFixed(2)},${y.toStringAsFixed(2)},${z.toStringAsFixed(2)}]";
}

class ShipNav {
  Ship ship;
  Vec3 vel = Vec3(0, 0, 0);
  bool get moving => vel.mag > 0;

  Ship? _targetShip;
  Ship? get targetShip => ship.sameLevel(_targetShip) ? _targetShip : null;
  void set targetShip(Ship? ship) {
    _targetShip = ship;
  }
  Coord3D? targetCoord;
  List<GridCell> currentPath = [];
  Map<Ship, SpaceLocation> lastKnown = {};
  late MovePreviewer movePreviewer = MovePreviewer(ship);
  late Position pos = Position.fromCoord(ship.loc.cell.coord);
  SpaceLocation? _heading;
  SpaceLocation? get heading => _heading;
  set heading(SpaceLocation? h) {
    print("Heading: $h");
    if (h != _heading) {
      isBraking = false;
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

  double get speed => sqrt((vel.x * vel.x) + (vel.y * vel.y) + (vel.z * vel.z));

  void setVelocity(double x, double y, double z) {
    vel = Vec3(x, y, z);
  }

  void dampVelocity(double factor) {
    vel = vel * factor;
  }

  Vec3 vecFromCoord(Coord3D c) => Vec3(c.x.toDouble(), c.y.toDouble(), c.z.toDouble());

  ShipNav(this.ship);

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


  String velocityString({int digits = 4}) =>
      '[${vel.x.toStringAsFixed(digits)}, '
          '${vel.y.toStringAsFixed(digits)}, '
          '${vel.z.toStringAsFixed(digits)}]';
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


