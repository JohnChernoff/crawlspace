import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/ship/nav/autopilot.dart';
import 'package:crawlspace_engine/ship/nav/move_preview.dart';
import 'package:crawlspace_engine/ship/nav/rotation_preview.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import '../../galaxy/geometry/coord_3d.dart';
import '../../galaxy/geometry/grid.dart';
import '../../galaxy/geometry/location.dart';
import '../../utils.dart';

class NavState {
  final Position pos;
  final Vec3 vel;

  const NavState({
    required this.pos,
    required this.vel,
  });

  factory NavState.fromShip(Ship ship) => NavState(pos: ship.nav._pos, vel: ship.nav._vel);

  NavState copyWith({
    Position? pos,
    Vec3? vel,
  }) {
    return NavState(
      pos: pos ?? this.pos,
      vel: vel ?? this.vel,
    );
  }
}

enum ThrottleMode {
  full(1.0),
  half(0.5),
  quarter(0.25),
  tenth(0.1),
  stop(0.0),
  drift(0.0);
  final double speedFactor;
  const ThrottleMode(this.speedFactor);
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

  Position add(Vec3 v) {
    return Position(x + v.x, y + v.y, z + v.z);
  }

  @override
  String toString() => "[${x.toStringAsFixed(2)},${y.toStringAsFixed(2)},${z.toStringAsFixed(2)}]";
}

class ShipNav {
  static const double thrustScale = 0.25; // tune this alone to slow everything down
  static const double gravConstant = .05; // tune by feel
  Ship ship;
  Vec3 _vel = Vec3(0, 0, 0);
  Vec3 get vel => _vel;
  bool get moving => _vel.mag > 0.025;
  bool get hasDestination => autoPilot.heading != ship.loc;

  void applyForce(Vec3 force) {
    _vel = Vec3(
      _vel.x + force.x,
      _vel.y + force.y,
      _vel.z + force.z,
    );
  }

  Position get projectedPosition => Position(
    _pos.x + _vel.x,
    _pos.y + _vel.y,
    _pos.z + _vel.z,
  );

  Coord3D get projectedCoord => projectedPosition.coord;

  double? get projectedTargetDist {
    final target = targetShip;
    if (target == null) return null;
    final tp = target.nav.projectedPosition;
    final mp = projectedPosition;
    final dx = mp.x - tp.x;
    final dy = mp.y - tp.y;
    final dz = mp.z - tp.z;
    return sqrt(dx*dx + dy*dy + dz*dz);
  }
  double? get targetDistTrend {
    final current = targetShip == null ? null : ship.distance(l: targetShip!.loc);
    final projected = projectedTargetDist;
    if (current == null || projected == null) return null;
    return projected - current;
  }

  String get trendGlyph {
    final trend = targetDistTrend;
    return switch(trend) {
      null => "-",
      < -0.3 => "↓",
      > 0.3 => "↑",
      _ => "→"
    };
  }

  Ship? _targetShip;
  Ship? get targetShip => ship.sameLevel(_targetShip) ? _targetShip : null;
  void set targetShip(Ship? ship) {
    _targetShip = ship;
  }
  Coord3D? targetCoord;
  List<GridCell> currentPath = [];
  Map<Ship, SpaceLocation> lastKnown = {};
  Position _pos;
  Position get pos => _pos;
  void set pos(Position p) {
    _pos = p;
  }

  ThrottleMode _throttle = ThrottleMode.full;
  ThrottleMode get throttle => _throttle;
  void set throttle(ThrottleMode mode) {
    _throttle = mode;
  }

  double get effectiveMass => max(ship.currentMass, 0.001);
  double get controlInertia => pow(effectiveMass * ship.volume, 0.5).toDouble();

  double baseForwardAccel(double thrust) => thrust / effectiveMass;
  double baseLateralAccel(double thrust) => thrust / controlInertia;
  double baseReverseAccel(double thrust) => thrust / controlInertia;

  double forwardAccel(double thrust) =>
      baseForwardAccel(thrust) *
          ship.shipClass.engineArch.forwardFactor *
          ship.shipClass.handling *
          thrustScale;

  double lateralAccel(double thrust) =>
      baseLateralAccel(thrust) *
          ship.shipClass.engineArch.lateralFactor *
          ship.shipClass.handling *
          thrustScale;

  double reverseAccel(double thrust) =>
      baseReverseAccel(thrust) *
          ship.shipClass.engineArch.reverseFactor *
          ship.shipClass.handling *
          thrustScale;


  /// Passive drag applied to powered ships each tick to prevent infinite drift.
  /// 0.98 = lose 2% of velocity per move when engines are running.
  /// Drifting ships (no engine) retain full momentum — they obey Newton.
  double stabilization = 0.98;

  double get speed => sqrt((_vel.x * _vel.x) + (_vel.y * _vel.y) + (_vel.z * _vel.z));

  void setVelocity(double x, double y, double z) {
    _vel = Vec3(x, y, z);
  }

  void dampVelocity(double factor) {
    _vel = _vel * factor;
  }

  /// Clears all motion state on arrival or forced stop.
  void resetMotionState() {
    autoStop = false; //autoPilot.heading = null;
    setVelocity(0, 0, 0);
    _targetFacing = null;
    pendingThrust = null;
    _pos = Position.fromCoord(ship.loc.cell.coord);
  }
  Vec3 vecFromCoord(Coord3D c) => Vec3(c.x.toDouble(), c.y.toDouble(), c.z.toDouble());

  late AutoPilot autoPilot;
  late MovePreviewer movePreviewer;
  late RotationPreviewer rotationPreviewer;

  bool get autopilotOn => _autopilotOn;
  bool get effectiveAutopilot => _autopilotOn || _autoStopping;
  void toggleAutoPilot() { _autopilotOn = !_autopilotOn; }
  bool _autopilotOn = false;
  void set autoStop(bool b) {
    _autoStopping = b;
    if (b) autoPilot.heading = ship.loc;
  }
  bool _autoStopping = false;
  bool get autoStopping => _autoStopping;

  ShipNav(this.ship) : _pos = Position.fromCoord(ship.loc.cell.coord) {
    autoPilot  = AutoPilot(ship);
    movePreviewer = MovePreviewer(ship);
    rotationPreviewer = RotationPreviewer(ship);
  }

  double _facing = 0; // degrees, 0 = up/north
  void set facing(double deg) => _facing = deg;
  double get facing => _facing;

  double? _targetFacing;
  double? get targetFacing => _targetFacing;
  set targetFacing(double? f) => _targetFacing = f;

  Vec3? pendingThrust;

  Vec3 facingToVec(double degrees) {
    final radians = degrees * pi / 180;
    // 0 degrees = up = positive y, 90 = right = positive x
    return Vec3(sin(radians), cos(radians), 0);
  }

  Coord3D facingToCoord(double degrees) {
    final v = facingToVec(degrees);
    return Coord3D(
        v.x.round().clamp(-1, 1),
        v.y.round().clamp(-1, 1),
        v.z.round().clamp(-1, 1));
  }

  void applyGravity(FugueEngine fm) {
    final loc = ship.loc;
    if (loc is! SystemLocation || loc.domain.isAbove(Domain.impulse)) return;

    final objects = loc.sector.cell.massiveObjects(fm.galaxy);
    if (objects.isEmpty) return;

    Vec3 gravity = Vec3(0, 0, 0);
    for (final obj in objects) {
      final objCoord = obj.loc.relativeDomainCoord(loc);
      if (objCoord != null) {
        final objPos = Position.fromCoord(objCoord);
        final dx = objPos.x - pos.x;
        final dy = objPos.y - pos.y;
        final dz = objPos.z - pos.z;

        final distSq = max(0.25,
            dx*dx.toDouble() + dy*dy.toDouble() + dz*dz.toDouble());
        final dist = sqrt(distSq);
        final strength = (obj.gravMass * gravConstant) / distSq;

        gravity = gravity + Vec3(
          (dx / dist) * strength,
          (dy / dist) * strength,
          (dz / dist) * strength,
        );
      }
    }
    ship.nav.applyForce(gravity);
  }

  //gravMap for discrete gridcells
  Vec3? get gForce => ship.loc.grid.gravMap[ship.loc.cell.coord];

  void rotate(double degrees) {
    _facing = (_facing + degrees) % 360;
  }

  bool get rotating => _targetFacing != null;

// The thrust direction is constrained by facing for rear engines
  Vec3 effectiveThrustVector(Coord3D requestedDir) {
    final arch = ship.shipClass.engineArch;
    switch(arch) {
      case EngineArch.center:
        return Vec3(requestedDir.x.toDouble(),
            requestedDir.y.toDouble(), 0);
      case EngineArch.rear:
      // can only thrust along facing direction
      // lateral/reverse at penalty
        final facingVec = facingToVec(_facing);
        final requested = Vec3(requestedDir.x.toDouble(),
            requestedDir.y.toDouble(), 0).normalized;
        final alignment = facingVec.dot(requested);
        // alignment 1.0 = full thrust, 0 = lateral penalty, -1 = reverse penalty
        return requested * _thrustMultiplier(alignment, arch);
      case EngineArch.distributed:
      // partial penalty for non-forward thrust
        final facingVec = facingToVec(_facing);
        final requested = Vec3(requestedDir.x.toDouble(),
            requestedDir.y.toDouble(), 0).normalized;
        final alignment = facingVec.dot(requested).clamp(-1.0, 1.0);
        return requested * _thrustMultiplier(alignment, arch) * 0.7;
    }
  }

  double _thrustMultiplier(double alignment, EngineArch arch) => switch(arch) {
    EngineArch.rear => alignment > 0
        ? Utils.lerp(arch.lateralFactor, 1.0, alignment)
        : Utils.lerp(arch.reverseFactor, arch.lateralFactor,
        alignment + 1),
    EngineArch.distributed => Utils.lerp(0.5, 1.0, (alignment + 1) / 2),
    EngineArch.center => 1.0,
  };

  double thrustEnergyCost(Engine? engine, double thrustMag) {
    if (engine == null || thrustMag <= 0) return 0.0;
    return (ship.currentMass * thrustMag) / engine.efficiency;
  }

  List<Coord3D> projectedPath(int length, {iterations = 25}) {
    if (!ship.loc.domain.newt) return [];
    final List<Coord3D> path = [ship.loc.cell.coord];
    Vec3 v = vel.normalized;
    Position p = Position(_pos.x,_pos.y,_pos.z);
    bool outOfBounds = false;
    int i = 0;
    while ((i++ < iterations) && path.length < length && !outOfBounds) {
      p = p.add(v);
      outOfBounds = !(p.coord.inBounds(ship.loc.dim));
      if (!outOfBounds && p.coord != path.last) path.add(p.coord); //if (outOfBounds) print("OOB: $p");
    }
    path.remove(ship.loc.cell.coord);
    return path;
  }

  String velocityString({int digits = 4}) =>
      '[${_vel.x.toStringAsFixed(digits)}, '
          '${_vel.y.toStringAsFixed(digits)}, '
          '${_vel.z.toStringAsFixed(digits)}]';
}



