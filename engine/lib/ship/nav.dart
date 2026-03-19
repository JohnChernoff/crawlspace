import 'dart:math';
import 'package:crawlspace_engine/ship/autopilot.dart';
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

  factory NavState.fromShip(Ship ship) => NavState(pos: ship.nav._pos, vel: ship.nav._vel, isBraking: ship.nav.isBraking);

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

enum ThrottleMode {
  full(1.0),
  half(0.5),
  stop(0.0),
  drift(0.0);
  final double speedFactor;
  const ThrottleMode(this.speedFactor);
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
  Vec3 _vel = Vec3(0, 0, 0);
  Vec3 get vel => _vel;
  bool get moving => _vel.mag > 0;

  Ship? _targetShip;
  Ship? get targetShip => ship.sameLevel(_targetShip) ? _targetShip : null;
  void set targetShip(Ship? ship) {
    _targetShip = ship;
  }
  Coord3D? targetCoord;
  List<GridCell> currentPath = [];
  Map<Ship, SpaceLocation> lastKnown = {};
  late MovePreviewer movePreviewer = MovePreviewer(ship);
  Position _pos;
  Position get pos => _pos;
  void set pos(Position p) {
    _pos = p;
  }
  SpaceLocation? _heading;
  SpaceLocation? get heading => _heading;
  set heading(SpaceLocation? h) {
    print("Heading: $h");
    if (h != _heading) {
      isBraking = false;
    }
    _heading = h;
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

  double get speed => sqrt((_vel.x * _vel.x) + (_vel.y * _vel.y) + (_vel.z * _vel.z));

  void setVelocity(double x, double y, double z) {
    _vel = Vec3(x, y, z);
  }

  void dampVelocity(double factor) {
    _vel = _vel * factor;
  }

  /// Clears all motion state on arrival or forced stop.
  /// Always go through this rather than setting heading/isBraking/vel directly,
  /// so isBraking is never left stale after a stop-mode arrival.
  void resetMotionState() {
    heading = null;      // also clears isBraking via the heading setter
    isBraking = false;
    setVelocity(0, 0, 0);
    _pos = Position.fromCoord(ship.loc.cell.coord); // re-sync pos to current cell
  }

  Vec3 vecFromCoord(Coord3D c) => Vec3(c.x.toDouble(), c.y.toDouble(), c.z.toDouble());

  AutoPilot autoPilot = AutoPilot();

  ShipNav(this.ship) : _pos = Position.fromCoord(ship.loc.cell.coord);

  String velocityString({int digits = 4}) =>
      '[${_vel.x.toStringAsFixed(digits)}, '
          '${_vel.y.toStringAsFixed(digits)}, '
          '${_vel.z.toStringAsFixed(digits)}]';
}



