import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';

import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import 'nav.dart';

class MoveContext {
  final Ship ship;
  final Engine? engine;
  final GridCell currentCell;
  final CellMap map;
  final ThrottleMode throttle;      // was throttleOverride scattered everywhere
  final bool newtonian;             // was computed redundantly in multiple places
  final bool drift;
  final Vec3? preGravVel;           // new — baseline for energy calculation
  final double thrustFraction;

  const MoveContext({
    required this.ship,
    required this.engine,
    required this.currentCell,
    required this.map,
    required this.throttle,
    required this.newtonian,
    this.drift = false,
    this.preGravVel,
    this.thrustFraction = 1.0,
  });

  factory MoveContext.fromShip(Ship ship, {
    ThrottleMode? throttleOverride,
    Vec3? preGravVel,
    bool drift = false,
  }) {
    final throttle = throttleOverride ?? ship.nav.throttle;
    final newtonian = ship.loc.domain.newt;
    return MoveContext(
      ship: ship,
      engine: (throttle == ThrottleMode.drift || drift)
          ? null
          : ship.systemControl.getEngine(ship.loc.domain),
      currentCell: ship.loc.cell,
      map: ship.loc.map,
      throttle: throttle,
      newtonian: newtonian,
      drift: drift,
      preGravVel: preGravVel,
    );
  }

  MoveContext copyWith({
    Engine? engine,
    GridCell? currentCell,
    double? thrustFraction,
    Vec3? preGravVel,
  }) => MoveContext(
    ship: ship,
    engine: engine ?? this.engine,
    currentCell: currentCell ?? this.currentCell,
    map: map,
    throttle: throttle,
    newtonian: newtonian,
    drift: drift,
    preGravVel: preGravVel ?? this.preGravVel,
    thrustFraction: thrustFraction ?? this.thrustFraction,
  );

  MoveContext withoutEngine() => MoveContext(
    ship: ship,
    engine: null,
    currentCell: currentCell,
    map: map,
    throttle: throttle,
    newtonian: newtonian,
    drift: drift,
    preGravVel: preGravVel,
    thrustFraction: thrustFraction,
  );

  // Used when stepping forward through multi-tick previews
  MoveContext advance(GridCell newCell) => MoveContext(
    ship: ship,
    engine: engine,
    currentCell: newCell,
    map: map,
    throttle: throttle,
    newtonian: newtonian,
    drift: drift,
    preGravVel: preGravVel,
    thrustFraction: thrustFraction,
  );
}
