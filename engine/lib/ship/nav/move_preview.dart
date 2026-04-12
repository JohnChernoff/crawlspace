import 'dart:math';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import '../../controllers/movement_controller.dart';
import '../../galaxy/geometry/coord_3d.dart';
import '../../galaxy/geometry/grid.dart';
import 'move_ctx.dart';
import 'nav.dart';
import 'newt.dart';

class MovePreviewer {
  Ship ship;
  ShipNav get nav => ship.nav;
  MovePreviewer(this.ship);
  int counter = 0;

  static const double gravityAssistMax = 0.9;   // max 90% faster
  static const double gravityResistMax = 0.75;   // max 75% slower
  static const double minTraversalMult = 0.2;   // never too cheap
  static const double maxTraversalMult = 2.50;   // never too punishing

  MovementPreview finalizeNewtonianStep({
    required NavState state,
    required MoveContext ctx,
    required GridCell desiredCell,
    required NewtonianStepInput input,
    required VelocityStepResult velocity,
    int auts = 1,
  }) {
    final newPos = Position(
      input.oldPos.x + velocity.moveVelocity.x * auts,
      input.oldPos.y + velocity.moveVelocity.y * auts,
      input.oldPos.z + velocity.moveVelocity.z * auts,
    );

    final actualCoord = newPos.coord;
    final actualCell = ctx.map[actualCoord];
    final baseline = ctx.preGravVel ?? state.vel;
    final dvx = velocity.storedVelocity.x - baseline.x;
    final dvy = velocity.storedVelocity.y - baseline.y;
    final dvz = velocity.storedVelocity.z - baseline.z;
    final deltaV = sqrt((dvx * dvx) + (dvy * dvy) + (dvz * dvz));

    final energy = input.engine != null
        ? (ship.currentMass * deltaV) / input.engine!.efficiency
        : 0.0;

    if (actualCell == null) {
      final bounceCell = boundaryCellFromTrajectory(
        oldPos: input.oldPos,
        newPos: newPos,
        map: ctx.map,
        fallback: ctx.currentCell,
      );

      return MovementPreview(
        desiredCell: desiredCell,
        actualCell: bounceCell,
        auts: auts,
        energyRequired: energy,
        emergencyDecel: velocity.moveVelocity.mag,
        engineFail: input.engineFail,
        newState: state.copyWith(
          pos: Position.fromCoord(bounceCell.coord),
          vel: const Vec3(0, 0, 0),
        ),
        doinked: BoundaryResult.clamped,
      );
    }

    return MovementPreview(
      desiredCell: desiredCell,
      actualCell: actualCell,
      auts: auts,
      energyRequired: energy,
      newState: state.copyWith(
        pos: newPos,
        vel: velocity.storedVelocity,
      ),
      engineFail: input.engineFail,
    );
  }

  MovementPreview previewNewtonianStep({
    required NavState state,
    required MoveContext ctx,
    required GridCell desiredCell,
    required Engine? engine,
    required bool engineFail,
    required bool selecting,
  }) {
    final input = NewtonianStepInput.build(
      state: state,
      ctx: ctx,
      desiredCell: desiredCell,
      engine: engine,
      engineFail: engineFail,
    );

    if (ctx.newtonianMode == NewtonianMode.stop &&
        input.distanceToTarget == 0) {
      return MovementPreview(
        desiredCell: desiredCell,
        actualCell: ctx.currentCell,
        auts: 1,
        energyRequired: 0,
        newState: state.copyWith(),
      );
    }

    final velocity = switch (ctx.newtonianMode) {
      NewtonianMode.stop => VelocityStepResult.previewStoppingVelocity(
        state: state,
        ctx: ctx,
        desiredCell: desiredCell,
        input: input,
        selecting: selecting,
      ),
      NewtonianMode.drift => VelocityStepResult.previewDriftVelocity(
        state: state,
      ),
      NewtonianMode.throttle => VelocityStepResult.previewThrottleVelocity(
        state: state,
        ctx: ctx,
        desiredCell: desiredCell,
        input: input,
      ),
    };

    return finalizeNewtonianStep(
      state: state,
      ctx: ctx,
      desiredCell: desiredCell,
      input: input,
      velocity: velocity,
    );
  }

  MovementPreview previewFixedStep({
    required NavState state,
    required MoveContext ctx,
    required GridCell? desiredCell,
    bool selecting = false,
  }) {
    counter++;

    if (desiredCell == null) {
      return MovementPreview(desiredCell: null, newState: state);
    }

    final engine = (ctx.throttle == ThrottleMode.drift || ctx.drift)
        ? null
        : ctx.engine;
    final noEngine = engine == null;
    final engineFail = noEngine && ctx.throttle != ThrottleMode.drift;

    if (!ship.nav.effectiveNewt) {
      return previewNonNewtonianStep(
        state: state,
        ctx: ctx,
        desiredCell: desiredCell,
        engine: engine,
      );
    }

    return previewNewtonianStep(
      state: state,
      ctx: ctx,
      desiredCell: desiredCell,
      engine: engine,
      engineFail: engineFail,
      selecting: selecting,
    );
  }

  MovementPreview previewMoves({
        required NavState state,
        required MoveContext ctx,
        required GridCell? desiredCell,
        bool selecting = false,
        auts = 1,
      }) {
    MovementPreview? last;

    for (int i = 0; i < auts; i++) {
      last = previewFixedStep(
        state: state,
        ctx: ctx,
        desiredCell: desiredCell,
        selecting: selecting
      );

      state = last.newState;

      ctx = ctx.advance(last.actualCell ?? ctx.currentCell);


      if (last.engineFail || last.emergencyDecel != null) break;
    }

    return last!;
  }

  MovementPreview moveUntilNextCell(
      GridCell? desiredCell, {
        required MoveContext ctx,
        int maxSteps = 50,
      }) {
    var state = NavState.fromShip(ship);
    final startCell = state.pos.coord;

    MovementPreview? last;
    int totalAuts = 0;
    double totalEnergy = 0.0;

    for (int i = 0; i < maxSteps; i++) {
      last = previewFixedStep(
        state: state,
        ctx: ctx,
        desiredCell: desiredCell,
      );

      totalAuts += last.auts;
      totalEnergy += last.energyRequired; //?? 0.0;
      state = last.newState;

      ctx = ctx.advance(last.actualCell ?? ctx.currentCell);

      if (last.engineFail || last.emergencyDecel != null) {
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: last.actualCell,
          auts: totalAuts,
          energyRequired: totalEnergy,
          emergencyDecel: last.emergencyDecel,
          engineFail: last.engineFail,
          newState: state,
        );
      }

      if (state.pos.coord != startCell) {
        return MovementPreview(
          desiredCell: desiredCell,
          actualCell: last.actualCell,
          auts: totalAuts,
          energyRequired: totalEnergy,
          engineFail: last.engineFail,
          newState: state,
        );
      }
    }

    return MovementPreview(
      desiredCell: desiredCell,
      actualCell: ctx.currentCell,
      auts: totalAuts,
      energyRequired: totalEnergy,
      engineFail: false,
      newState: state,
    );
  }

  GridCell boundaryCellFromTrajectory({
    required Position oldPos,
    required Position newPos,
    required CellMap map,
    required GridCell fallback,
  }) {
    final dim = map.dim;

    double? firstT;

    void consider(double t) {
      if (t.isNaN || t.isInfinite) return;
      if (t < 0 || t > 1) return;
      if (firstT == null || t < firstT!) firstT = t;
    }

    final dx = newPos.x - oldPos.x;
    final dy = newPos.y - oldPos.y;
    final dz = newPos.z - oldPos.z;

    if (dx < 0) consider((0.0 - oldPos.x) / dx);
    if (dx > 0) consider(((dim.mx - 1).toDouble() - oldPos.x) / dx);

    if (dy < 0) consider((0.0 - oldPos.y) / dy);
    if (dy > 0) consider(((dim.my - 1).toDouble() - oldPos.y) / dy);

    if (dim.mz > 1) {
      if (dz < 0) consider((0.0 - oldPos.z) / dz);
      if (dz > 0) consider(((dim.mz - 1).toDouble() - oldPos.z) / dz);
    }

    if (firstT == null) return fallback;

    final hitX = oldPos.x + dx * firstT!;
    final hitY = oldPos.y + dy * firstT!;
    final hitZ = oldPos.z + dz * firstT!;

    final hitCoord = Coord3D(
      hitX.round().clamp(0, dim.mx - 1),
      hitY.round().clamp(0, dim.my - 1),
      dim.mz <= 1
          ? 0
          : hitZ.round().clamp(0, dim.mz - 1),
    );

    return map[hitCoord] ?? fallback;
  }

  double gravityTraversalMultiplier({
    required GridCell fromCell,
    required GridCell toCell,
  }) {
    final from = fromCell.coord;
    final to = toCell.coord;

    final moveVec = Vec3(
      (to.x - from.x).toDouble(),
      (to.y - from.y).toDouble(),
      (to.z - from.z).toDouble(),
    );

    if (moveVec.mag <= 1e-9) return 1.0;

    final moveDir = moveVec.normalized;

    final gFrom = fromCell.loc.grid.gravAt(from);
    final gTo = toCell.loc.grid.gravAt(to);
    final gAvg = gFrom.avg(gTo);

    final heatFrom = fromCell.loc.grid.gravHeatMap[from] ?? 0.0;
    final heatTo = toCell.loc.grid.gravHeatMap[to] ?? 0.0;
    final heat = (heatFrom + heatTo) * 0.5;

    if (gAvg.mag <= 1e-9 || heat <= 1e-9) return 1.0;

    final gravDir = gAvg.normalized;
    final alignment = moveDir.dot(gravDir).clamp(-1.0, 1.0);

    double mult = 1.0;

    if (alignment >= 0) {
      mult -= alignment * heat * gravityAssistMax;
    } else {
      mult += (-alignment) * heat * gravityResistMax;
    }

    return mult.clamp(minTraversalMult, maxTraversalMult);
  }

  int gravityAdjustedTraversalAuts({
    required Engine engine,
    required GridCell fromCell,
    required GridCell toCell,
  }) {
    final distance = fromCell.distCell(toCell);
    final baseAuts = max(1, (engine.baseAutPerUnitTraversal * distance).round());
    final mult = gravityTraversalMultiplier(fromCell: fromCell, toCell: toCell);
    return max(1, (baseAuts * mult).round());
  }

  MovementPreview previewNonNewtonianStep({
    required NavState state,
    required MoveContext ctx,
    required GridCell desiredCell,
    required Engine? engine,
  }) {
    if (engine == null) {
      return MovementPreview(
        desiredCell: desiredCell,
        actualCell: ctx.currentCell,
        engineFail: true,
        newState: state,
      );
    }

    final distance = ctx.currentCell.distCell(desiredCell);

    final auts = ctx.ship.nav.autoPilotMode == AutoPilotMode.simple
        ? (engine.baseAutPerUnitTraversal * distance).round()
        : gravityAdjustedTraversalAuts(
          engine: engine,
          fromCell: ctx.currentCell,
          toCell: desiredCell);

    final mult = ctx.ship.nav.autoPilotMode == AutoPilotMode.simple
        ? 1
        : gravityTraversalMultiplier(fromCell: ctx.currentCell, toCell: desiredCell);

    final energy = (ship.currentMass * distance * mult * .75) / engine.efficiency;
    //if (ship.playship) print("Auts: $auts, Energy: $energy");

    return MovementPreview(
      desiredCell: desiredCell,
      actualCell: desiredCell,
      auts: auts,
      energyRequired: energy,
      newState: state.copyWith(pos: Position.fromCoord(desiredCell.coord)),
    );
  }

}
