import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';

import 'grid.dart';
import 'impulse.dart';
import '../../ship/ship.dart';
import '../system.dart';

sealed class SpaceLocation implements Locatable {
  SpaceLocation get loc => this;
  final Level _level;
  final Coord3D _coord;
  Domain get domain;
  Level get level => _level;
  GridCell get cell => level.map.cells[_coord]!; //TODO: error log

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

  const SpaceLocation(this._level,this._coord);

}

class SystemLocation extends SpaceLocation {
  @override
  Domain get domain => Domain.system;
  @override
  System get level => _level as System;
  @override
  SectorCell get cell => super.cell as SectorCell;

  SystemLocation(super._level, super._coord)
      : assert(_level is System, "SystemLocation requires a System, got ${_level.runtimeType}");
  factory SystemLocation.fromCell(Level lev, GridCell cell) => SystemLocation(lev,cell.coord);

  @override
  SystemLocation withCell(GridCell newCell) => SystemLocation(level, newCell.coord);

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
  ImpulseCell get cell => super.cell as ImpulseCell;

  ImpulseLocation(this.systemLoc, super._level, super._coord)
      : assert(_level is ImpulseLevel, "ImpulseLocation requires a ImpulseLevel, got ${_level.runtimeType}");
  factory ImpulseLocation.fromCell(SystemLocation sysLoc, Level lev, GridCell cell) => ImpulseLocation(sysLoc,lev,cell.coord);

  @override
  ImpulseLocation withCell(GridCell newCell) => ImpulseLocation(systemLoc, level, newCell.coord);

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
