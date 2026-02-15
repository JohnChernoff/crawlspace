import 'package:crawlspace_engine/fugue_engine.dart';

import 'grid.dart';
import 'impulse.dart';
import 'ship.dart';
import 'system.dart';

sealed class ShipLocation {
  final Level _level;
  final GridCell _cell;
  Domain get domain {
    if (this is SystemLocation) return Domain.system;
    if (this is ImpulseLocation) return Domain.impulse;
    return Domain.hyperspace;
  }
  Level get level => _level;
  GridCell get cell => _cell;
  Set<Ship> get ships => level.shipsAt(cell);

  double dist({ShipLocation? l, GridCell? c}) {
    if (l != null) {
      if (l.domain == domain) {
        return cell.coord.distance(l.cell.coord);
      } else {
        FugueEngine.glog("Error: invalid ship location comparison", error: true);
        return double.infinity;
      }
    } else if (c != null) {
      return cell.coord.distance(c.coord);
    } else {
      FugueEngine.glog("Error: missing distance argument", error: true);
      return double.infinity;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is ShipLocation && other.domain == domain && other.cell.coord == cell.coord;
  }
  @override
  int get hashCode => level.hashCode * cell.hashCode;

  const ShipLocation(this._level,this._cell);
}

class SystemLocation extends ShipLocation {

  @override
  System get level => _level as System;
  @override
  SectorCell get cell => _cell as SectorCell;

  const SystemLocation(super.level, super.cell);

  @override
  String toString() {
    return "System: ${level.name}\nSector: ${cell.coord}";
  }
}

class ImpulseLocation extends ShipLocation {

  final SystemLocation systemLoc;
  @override
  ImpulseLevel get level => _level as ImpulseLevel;
  @override
  ImpulseCell get cell => _cell as ImpulseCell;

  const ImpulseLocation(this.systemLoc, super.level, super.cell);

  @override
  String toString() {
    return "System: ${systemLoc.toString()}\nImpulse: ${cell.coord}";
  }
}
