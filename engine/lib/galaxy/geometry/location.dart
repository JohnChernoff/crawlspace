import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';

import 'grid.dart';
import 'impulse.dart';
import '../../ship/ship.dart';
import '../system.dart';

sealed class SpaceLocation implements Locatable {
  SpaceLocation get loc => this;
  final Level _level;
  final GridCell _cell;
  Domain get domain;
  Level get level => _level;
  GridCell get cell => _cell;

  @override
  bool operator ==(Object other) {
    return other is SpaceLocation && other.domain == domain && other.cell.coord == cell.coord;
  }
  @override
  int get hashCode => level.hashCode * cell.hashCode;

  SpaceLocation withCell(GridCell newCell);

  System get system {
    final loc = this; return switch(loc) {
      SystemLocation() => loc.level,
      ImpulseLocation() => loc.systemLoc.level,
    };
  }

  double dist({SpaceLocation? l, GridCell? c}) {
    if (l != null) {
      if (l.domain == domain) {
        return cell.coord.distance(l.cell.coord);
      } else {
        glog("Error: invalid ship location comparison", error: true);
        return double.infinity;
      }
    } else if (c != null) {
      return cell.coord.distance(c.coord);
    } else {
      glog("Error: missing distance argument", error: true);
      return double.infinity;
    }
  }

  const SpaceLocation(this._level,this._cell);
}

class SystemLocation extends SpaceLocation {
  @override
  Domain get domain => Domain.system;
  @override
  System get level => _level as System;
  @override
  SectorCell get cell => _cell as SectorCell;

  SystemLocation(super.level, super.cell)
      : assert(level is System, "SystemLocation requires a System, got ${level.runtimeType}"),
        assert(cell is SectorCell, "SystemLocation requires a SectorCell, got ${cell.runtimeType}");

  @override
  SystemLocation withCell(GridCell newCell) => SystemLocation(level, newCell as SectorCell);

  @override
  String toString() {
    return "System: ${level.name}\nSector: ${cell.coord}";
  }
}

class ImpulseLocation extends SpaceLocation {
  @override
  Domain get domain => Domain.impulse;
  final SystemLocation systemLoc;
  @override
  ImpulseLevel get level => _level as ImpulseLevel;
  @override
  ImpulseCell get cell => _cell as ImpulseCell;

  ImpulseLocation(this.systemLoc, super.level, super.cell)
      : assert(level is ImpulseLevel, "ImpulseLocation requires a ImpulseLevel, got ${level.runtimeType}"),
        assert(cell is ImpulseCell, "ImpulseLocation requires a ImpulseCell, got ${cell.runtimeType}");

  @override
  ImpulseLocation withCell(GridCell newCell) => ImpulseLocation(systemLoc, level, newCell as ImpulseCell);

  @override
  String toString() {
    return "System: ${systemLoc.toString()}\nImpulse: ${cell.coord}";
  }
}

sealed class PilotLocale implements Locatable {
  SpaceLocation get loc;
}

class AboardShip extends PilotLocale {
  final Ship ship;
  AboardShip(this.ship);
  @override
  SpaceLocation get loc => ship.loc; // dynamic — follows ship
}

class AtEnvironment extends PilotLocale {
  final SpaceEnvironment env;
  AtEnvironment(this.env);
  factory AtEnvironment.fromSystem(SystemLocation s) => AtEnvironment(SpaceEnvironment("",0,0,locale: s)); //TODO: copy galactic kernels
  @override
  SpaceLocation get loc => env.loc; // stable — fixed point
}
