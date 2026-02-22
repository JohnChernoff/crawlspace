import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/object.dart';
import 'package:crawlspace_engine/sector.dart';

import 'grid.dart';
import 'impulse.dart';
import 'ship.dart';
import 'galaxy/system.dart';

sealed class SpaceLocation implements Locatable {
  SpaceLocation get loc => this;
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

  @override
  bool operator ==(Object other) {
    return other is SpaceLocation && other.domain == domain && other.cell.coord == cell.coord;
  }
  @override
  int get hashCode => level.hashCode * cell.hashCode;

  const SpaceLocation(this._level,this._cell);
}

class SystemLocation extends SpaceLocation {

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

class ImpulseLocation extends SpaceLocation {

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
