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
  void set targetShip(Ship? ship) { //print("Setting target: $ship");
    _targetShip = ship; //print("Target: $targetShip");
  } //=> sameLevel(ship) ? ship : null;
  Coord3D? targetCoord;
  List<GridCell> currentPath = [];
  Map<Ship,SpaceLocation> lastKnown = {};
  SpaceLocation? heading;
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

  MovementPreview previewMove(
      GridCell? desiredCell, {
        double baseEnergy = 20,
        ThrottleMode throttle = ThrottleMode.full,
        emergencyStop = true,
      }) {

    if (desiredCell == null) return const MovementPreview(desiredCell: null);
    final desiredCoord = desiredCell.coord;

    final Engine? engine;
    if (throttle == ThrottleMode.noEngine) {
      engine = null;
    } else if (ship.systemControl.engine == null || !(ship.systemControl.engine?.active ?? false)) {
      engine = null;
    } else {
      engine = ship.systemControl.engine;
    }
    if (engine == null) throttle = ThrottleMode.noEngine;

    final dx = desiredCoord.x - ship.loc.cell.coord.x;
    final dy = desiredCoord.y - ship.loc.cell.coord.y;
    final dz = desiredCoord.z - ship.loc.cell.coord.z;

    final driftStabilization =
    throttle == ThrottleMode.noEngine ? 1.0 : stabilization;

    final mag = sqrt((dx * dx) + (dy * dy) + (dz * dz));
    final dirX = mag == 0 ? 0.0 : dx / mag;
    final dirY = mag == 0 ? 0.0 : dy / mag;
    final dirZ = mag == 0 ? 0.0 : dz / mag;

    final thrust = engine?.thrust ?? 0;
    final accel = thrust / max(ship.currentMass, 0.001);
    final maxSpeed = engine?.maxSpeed ?? 0;
    final baseAUT = engine?.baseAutPerUnitTraversal ?? 10;
    final efficiency = engine?.efficiency ?? .1;

    double vx = ship.nav.velX * driftStabilization;
    double vy = ship.nav.velY * driftStabilization;
    double vz = ship.nav.velZ * driftStabilization;

    final targetSpeed = maxSpeed * throttle.speedFactor;
    if (throttle == ThrottleMode.stop) {
      final currentSpeed = sqrt((vx * vx) + (vy * vy) + (vz * vz));
      if (currentSpeed > 0) {
        final brake = min(accel, currentSpeed);
        vx -= (vx / currentSpeed) * brake;
        vy -= (vy / currentSpeed) * brake;
        vz -= (vz / currentSpeed) * brake;
      }

      final steer = accel * 0.35;
      vx += dirX * steer;
      vy += dirY * steer;
      vz += dirZ * steer;

      final newSpeed = sqrt((vx * vx) + (vy * vy) + (vz * vz));
      final stopCap = max(0.25, maxSpeed * 0.25);
      if (newSpeed > stopCap) {
        final scale = stopCap / newSpeed;
        vx *= scale;
        vy *= scale;
        vz *= scale;
      }
    } else if (throttle != ThrottleMode.noEngine) {
      vx += dirX * accel;
      vy += dirY * accel;
      vz += dirZ * accel;

      final newSpeed = sqrt((vx * vx) + (vy * vy) + (vz * vz));
      if (newSpeed > targetSpeed && targetSpeed > 0) {
        final scale = targetSpeed / newSpeed;
        vx *= scale;
        vy *= scale;
        vz *= scale;
      }
    }

    final fallback = throttle == ThrottleMode.noEngine
        ? const Coord3D(0, 0, 0)
        : Coord3D(dx.sign, dy.sign, dz.sign);

    var finalStep = _stepFromVelocity(vx, vy, vz, fallback: fallback);
    if (finalStep.x == 0 && finalStep.y == 0 && finalStep.z == 0) {
      return MovementPreview(
        desiredCell: desiredCell,
        actualCell: ship.loc.cell,
        auts: max(1, baseAUT),
        energyRequired: throttle == ThrottleMode.noEngine
            ? 0
            : baseEnergy * (1 / efficiency) * 0.5,
        newVelX: vx,
        newVelY: vy,
        newVelZ: vz,
      );
    }

    var actualCoord = ship.loc.cell.coord.add(finalStep);
    var actualCell = ship.loc.map[actualCoord];

    if (actualCell == null) {
      final c = ship.loc.cell.coord;
      final map = ship.loc.map;
      if (emergencyStop) {
        final attemptedSpeed = sqrt((vx * vx) + (vy * vy) + (vz * vz));
        return MovementPreview(
            desiredCell: desiredCell,
            actualCell: ship.loc.cell,
            auts: 1,
            energyRequired: throttle == ThrottleMode.noEngine
                ? 0
                : baseEnergy * (1 / efficiency) * 0.25,
            emergencyDecel: attemptedSpeed
        );
      } else {
        // Kill outward momentum components that point off the map.
        if (vx > 0 && !map.containsCoord(c.add(const Coord3D(1, 0, 0)))) vx = 0;
        if (vx < 0 && !map.containsCoord(c.add(const Coord3D(-1, 0, 0)))) vx = 0;
        if (vy > 0 && !map.containsCoord(c.add(const Coord3D(0, 1, 0)))) vy = 0;
        if (vy < 0 && !map.containsCoord(c.add(const Coord3D(0, -1, 0)))) vy = 0;
        if (vz > 0 && !map.containsCoord(c.add(const Coord3D(0, 0, 1)))) vz = 0;
        if (vz < 0 && !map.containsCoord(c.add(const Coord3D(0, 0, -1)))) vz = 0;

        final newStep = _stepFromVelocity(vx, vy, vz, fallback: const Coord3D(0, 0, 0));
        actualCoord = ship.loc.cell.coord.add(newStep);
        actualCell = ship.loc.map[actualCoord];
        if (actualCell != null) {
          finalStep = newStep;
        }
        if (actualCell == null || (newStep.x == 0 && newStep.y == 0 && newStep.z == 0)) {
          finalStep = _stepFromVelocity(vx, vy, vz, fallback: const Coord3D(0,0,0));
          actualCoord = ship.loc.cell.coord.add(finalStep);
          actualCell = ship.loc.map[actualCoord];
          return MovementPreview(
            desiredCell: desiredCell,
            actualCell: ship.loc.cell,
            auts: max(1, baseAUT),
            energyRequired: throttle == ThrottleMode.noEngine
                ? 0
                : baseEnergy * (1 / efficiency) * 0.25,
            newVelX: vx * 0.5,
            newVelY: vy * 0.5,
            newVelZ: vz * 0.5,
          );
        }
      }
    }

    final stepMag = sqrt((finalStep.x * finalStep.x) + (finalStep.y * finalStep.y) + (finalStep.z * finalStep.z));
    final stepDirX = finalStep.x / stepMag;
    final stepDirY = finalStep.y / stepMag;
    final stepDirZ = finalStep.z / stepMag;

    final forwardSpeed = max(
      0.1,
      (vx * stepDirX) + (vy * stepDirY) + (vz * stepDirZ),
    );

    final dist = ship.loc.distCell(actualCell);
    final auts = max(1, (baseAUT * dist / forwardSpeed).round());

    final energyRequired = throttle == ThrottleMode.noEngine
        ? 0
        : baseEnergy * (1 / efficiency) * dist * (1 + (accel * 0.25));

    return MovementPreview(
      desiredCell: desiredCell,
      actualCell: actualCell,
      auts: auts,
      energyRequired: energyRequired.toDouble(),
      newVelX: vx,
      newVelY: vy,
      newVelZ: vz,
    );
  }

  Coord3D _stepFromVelocity(double vx, double vy, double vz, {required Coord3D fallback}) {
    final ax = vx.abs();
    final ay = vy.abs();
    final az = vz.abs();
    final maxAbs = max(ax, max(ay, az));

    if (maxAbs < 0.05) return fallback;

    int sx = 0, sy = 0, sz = 0;
    const keepFactor = 0.6;

    if (ax >= maxAbs * keepFactor) sx = vx > 0 ? 1 : -1;
    if (ay >= maxAbs * keepFactor) sy = vy > 0 ? 1 : -1;
    if (az >= maxAbs * keepFactor) sz = vz > 0 ? 1 : -1;

    return Coord3D(sx, sy, sz);
  }

  String velocityString({int digits = 4}) =>
      "[${velX.toStringAsFixed(digits)}, ${velY.toStringAsFixed(digits)}, ${velZ.toStringAsFixed(digits)}]";
}

/*
  Coord3D _trueStepFromVelocity(double vx, double vy, double vz, {required Coord3D fallback}) {
    int sx = _axisStep(vx);
    int sy = _axisStep(vy);
    int sz = _axisStep(vz);

    if (sx == 0 && sy == 0 && sz == 0) {
      return fallback;
    }
    return Coord3D(sx, sy, sz);
  }

  int _axisStep(double v, {double epsilon = 0.05}) {
    if (v > epsilon) return 1;
    if (v < -epsilon) return -1;
    return 0;
  }
 */