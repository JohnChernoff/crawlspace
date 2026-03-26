import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import '../../ship/ship.dart';
import 'grid.dart';
import 'impulse.dart';
import '../system.dart';

sealed class SpaceLocation {
  Domain get domain;
  System system;
  GridCell get cell; //TODO: error log
  CellMap get map;
  
  SectorLocation? get sectorOrNull => switch (this) {
    SectorLocation s => s,
    ImpulseLocation i => i.sector,
    _ => null,
  };

  @override
  bool operator ==(Object other) {
    return other is SpaceLocation
        && other.domain == domain
        && other.system == system;
  }

  @override
  int get hashCode;

  SpaceLocation withCell(GridCell newCell);

  SpaceLocation(this.system);

  GridDim get dim => switch(domain) {
    Domain.hyperspace => throw UnimplementedError(),
    Domain.system => system.systemMapDim,
    Domain.impulse => system.impulseMapDim,
  };

  double distCell(GridCell cell) => dist(cell.loc);
  double dist(SpaceLocation l) {
    if (l.domain == domain) {
      if (this is SectorLocation && l is SectorLocation) {
        return (this as SectorLocation)
            .sectorCoord
            .distance(l.sectorCoord);
      }
      if (this is ImpulseLocation && l is ImpulseLocation) {
        return (this as ImpulseLocation)
            .impulseCoord
            .distance(l.impulseCoord);
      }
    }
    glog("Warning: invalid ship location comparison", level: DebugLevel.Warning);
    return double.infinity;
  }
}

abstract class SectorLocatable extends SpaceLocation {
  SectorLocatable(super.system);
  Coord3D get sectorCoord;
}

class SystemLocation extends SpaceLocation {
  SystemLocation(super.system);

  @override
  Domain get domain => Domain.hyperspace;

  @override
  GridCell get cell => throw UnimplementedError();

  @override
  CellMap<GridCell> get map => throw UnimplementedError();

  @override
  SpaceLocation withCell(GridCell newCell) => throw UnimplementedError();
}

class SectorLocation extends SectorLocatable {
  @override
  Domain get domain => Domain.system;

  Coord3D sectorCoord;

  @override
  SectorCell get cell {
    final c = system.map[sectorCoord];
    if (c != null) return c;
    else {
      print("System map: ${system.map.values}");
      throw StateError("Bad c: $sectorCoord");
    }
  }


  @override
  SystemMap get map => system.map;

  SectorLocation(super.system, this.sectorCoord);

  @override
  SectorLocation withCell(GridCell newCell) => SectorLocation(system, newCell.coord);

  @override
  String toString() {
    return "System: ${system.name}\nSector: $sectorCoord";
  }

  @override
  bool operator ==(Object other) => (super == other)
      && other is SectorLocation && other.sectorCoord == sectorCoord;

  @override
  int get hashCode =>  Object.hash(system, domain, sectorCoord);

}

class ImpulseLocation extends SectorLocatable {
  @override
  Domain get domain => Domain.impulse;
  Coord3D sectorCoord,impulseCoord;

  SectorLocation get sector => SectorLocation(system, sectorCoord);

  @override
  SectorMap get map => sectorCell.map;

  SectorCell get sectorCell => system.map[sectorCoord] as SectorCell;

  ImpulseCell get cell => sectorCell.map.at(impulseCoord);

  ImpulseLocation(super.system, this.sectorCoord, this.impulseCoord);

  @override
  ImpulseLocation withCell(GridCell newCell) => ImpulseLocation(system, sectorCoord, newCell.coord);

  @override
  String toString() {
    return "Sector: $sectorCoord\nImpulse: $impulseCoord";
  }

  @override
  int get hashCode => Object.hash(system, domain, sectorCoord, impulseCoord);

  @override
  bool operator ==(Object other) => (super == other)
      && other is ImpulseLocation && other.sectorCoord == sectorCoord && other.impulseCoord == impulseCoord;
}

sealed class PilotLocale {
  SpaceLocation get loc;
}

class AboardShip extends PilotLocale {
  final Ship ship;
  AboardShip(this.ship);
  @override
  SpaceLocation get loc => ship.loc; // dynamic — follows ship
}

class AtEnvironment extends PilotLocale {
  final _tmpLoc;
  final SpaceEnvironment env;
  AtEnvironment(this.env, {SpaceLocation? tmpLoc}) : this._tmpLoc = tmpLoc ?? env.loc;
  factory AtEnvironment.fromSystem(SectorLocation s) => AtEnvironment(SpaceEnvironment("",0,0),tmpLoc: s);
  @override
  SpaceLocation get loc => env.maybeLoc ?? _tmpLoc; // stable — fixed point
}
