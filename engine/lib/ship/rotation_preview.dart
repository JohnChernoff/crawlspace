import 'package:crawlspace_engine/ship/ship.dart';
import '../galaxy/geometry/coord_3d.dart';

class RotationState {
  final double facing;
  final double? targetFacing;
  final Vec3? pendingThrust;

  const RotationState({
    required this.facing,
    this.targetFacing,
    this.pendingThrust,
  });

  factory RotationState.fromShip(Ship ship) => RotationState(
    facing: ship.nav.facing,
    targetFacing: ship.nav.targetFacing,
    pendingThrust: ship.nav.pendingThrust,
  );

  RotationState copyWith({
    double? facing,
    double? targetFacing,
    Vec3? pendingThrust,
  }) => RotationState(
    facing: facing ?? this.facing,
    targetFacing: targetFacing ?? this.targetFacing,
    pendingThrust: pendingThrust ?? this.pendingThrust,
  );
}

class RotationPreview {
  final bool complete;
  final int auts;
  final RotationState newState;

  const RotationPreview({
    required this.complete,
    required this.auts,
    required this.newState,
  });
}

class RotationPreviewer {
  final Ship ship;
  RotationPreviewer(this.ship);

  RotationPreview previewRotationStep({
    required RotationState state,
  }) {
    if (state.targetFacing == null) {
      return RotationPreview(
        complete: true,
        auts: 0,
        newState: state,
      );
    }

    final rotationRate = ship.rotationRate;

    double diff = (state.targetFacing! - state.facing) % 360;
    if (diff > 180) diff -= 360;

    final step = diff.abs() <= rotationRate
        ? diff
        : diff.sign * rotationRate;

    final newFacing = (state.facing + step) % 360;
    final complete = (newFacing - state.targetFacing!).abs() < 0.1;

    return RotationPreview(
      complete: complete,
      auts: 1,
      newState: state.copyWith(
        facing: newFacing,
        targetFacing: complete ? null : state.targetFacing,
        pendingThrust: complete ? null : state.pendingThrust,
      ),
    );
  }

  RotationPreview previewRotation({int maxSteps = 8}) {
    var state = RotationState.fromShip(ship);
    RotationPreview? last;
    int totalAuts = 0;

    for (int i = 0; i < maxSteps; i++) {
      last = previewRotationStep(state: state);
      totalAuts += last.auts;
      state = last.newState;
      if (last.complete) break;
    }

    return RotationPreview(
      complete: last!.complete,
      auts: totalAuts,
      newState: state,
    );
  }
}
