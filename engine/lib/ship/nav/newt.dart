import '../../fugue_engine.dart';
import '../../galaxy/geometry/coord_3d.dart';
import '../../galaxy/geometry/grid.dart';
import '../systems/engines.dart';
import 'move_ctx.dart';
import 'nav.dart';

class NewtonianStepInput {
  final Engine? engine;
  final bool engineFail;
  final Position oldPos;
  final Vec3 toTarget;
  final double distanceToTarget;
  final Vec3 targetDir;
  final double fAccel;
  final double lAccel;
  final double rAccel;
  final double maxSpeed;

  const NewtonianStepInput({
    required this.engine,
    required this.engineFail,
    required this.oldPos,
    required this.toTarget,
    required this.distanceToTarget,
    required this.targetDir,
    required this.fAccel,
    required this.lAccel,
    required this.rAccel,
    required this.maxSpeed,
  });

  factory NewtonianStepInput.build({
    required NavState state,
    required MoveContext ctx,
    required GridCell desiredCell,
    required Engine? engine,
    required bool engineFail,
  }) {
    final dpos = Position.fromCoord(desiredCell.coord);
    final toTarget = Vec3(
      dpos.x - state.pos.x,
      dpos.y - state.pos.y,
      dpos.z - state.pos.z,
    );

    final dist = toTarget.mag;
    final targetDir = toTarget.fromMag(dist);

    final thrust = engine?.thrust ?? 0.0;
    final thrustScale = ctx.thrustFraction.clamp(0.0, 1.0);

    final noEngine = engine == null;
    final fAccel = noEngine ? 0.0 : ctx.ship.nav.forwardAccel(thrust) * thrustScale;
    final lAccel = noEngine ? 0.0 : ctx.ship.nav.lateralAccel(thrust) * thrustScale;
    final rAccel = noEngine ? 0.0 : ctx.ship.nav.reverseAccel(thrust) * thrustScale;
    final maxSpeed = noEngine ? 0.0 : ctx.ship.maxSpeed;

    return NewtonianStepInput(
      engine: engine,
      engineFail: engineFail,
      oldPos: state.pos,
      toTarget: toTarget,
      distanceToTarget: dist,
      targetDir: targetDir,
      fAccel: fAccel,
      lAccel: lAccel,
      rAccel: rAccel,
      maxSpeed: maxSpeed,
    );
  }
}

class VelocityStepResult {
  final Vec3 moveVelocity;
  final Vec3 storedVelocity;

  const VelocityStepResult({
    required this.moveVelocity,
    required this.storedVelocity,
  });

  factory VelocityStepResult.previewDriftVelocity({
    required NavState state,
  }) {
    return VelocityStepResult(
      moveVelocity: state.vel,
      storedVelocity: state.vel,
    );
  }

  factory VelocityStepResult.previewStoppingVelocity({
    required NavState state,
    required MoveContext ctx,
    required GridCell desiredCell,
    required NewtonianStepInput input,
    required bool selecting,
  }) {

    final guidance = ctx.ship.nav.autoPilot.computeGuidanceVelocity(
      pos: state.pos,
      vel: state.vel,
      targetCell: desiredCell,
      fAccel: input.fAccel,
      lAccel: input.lAccel,
      rAccel: input.rAccel,
      maxSpeed: input.maxSpeed,
      desiredArrivalSpeed: 0,
    );

    final currCoord = ctx.currentCell.coord;
    final targCoord = desiredCell.coord;

    final next = ctx.ship.nav.autoPilot.steerVelocityTowardDirectional(
      current: state.vel,
      desired: guidance.desiredVelocity,
      forwardDir: input.targetDir,
      fAccel: input.fAccel,
      lAccel: input.lAccel,
      rAccel: input.rAccel,
      stabilization: 1.0,
      maxSpeed: input.maxSpeed,
      lockX: currCoord.x == targCoord.x,
      lockY: currCoord.y == targCoord.y,
      lockZ: currCoord.z == targCoord.z,
    );

    if (!selecting) {
      glog("GUIDE d:${input.distanceToTarget.toStringAsFixed(2)}, $guidance",
          level: DebugLevel.Fine);
    }

    return VelocityStepResult(
      moveVelocity: next,
      storedVelocity: next,
    );
  }

  factory VelocityStepResult.previewThrottleVelocity({
    required NavState state,
    required MoveContext ctx,
    required GridCell desiredCell,
    required NewtonianStepInput input,
  }) {
    final guidance = ctx.ship.nav.autoPilot.computeGuidanceVelocity(
      pos: state.pos,
      vel: state.vel,
      targetCell: desiredCell,
      fAccel: input.fAccel,
      lAccel: input.lAccel,
      rAccel: input.rAccel,
      maxSpeed: input.maxSpeed,
      desiredArrivalSpeed: input.maxSpeed,
      lateralWeight: 0.2,
    );

    final current = state.vel;
    final targetDir = input.targetDir;

    final blendedForward = current.mag > 0.01
        ? (targetDir + current.normalized * 0.4).normalized
        : targetDir;

    final next = ctx.ship.nav.autoPilot.steerVelocityTowardDirectional(
      current: current,
      desired: guidance.desiredVelocity,
      forwardDir: blendedForward,
      fAccel: input.fAccel,
      lAccel: input.lAccel,
      rAccel: input.rAccel,
      stabilization: ctx.ship.nav.stabilization,
      maxSpeed: input.maxSpeed * ctx.throttle.speedFactor,
      lockX: false,
      lockY: false,
      lockZ: false,
    );

    return VelocityStepResult(
      moveVelocity: next,
      storedVelocity: next,
    );
  }
}
