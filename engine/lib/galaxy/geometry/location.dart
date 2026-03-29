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
  System system; //highest level
  SpaceLocation get upper;
  GridCell get cell; //TODO: error log
  CellMap get map;
  
  SectorLocation? get sectorOrNull {
    final l = this;
    if (l is SystemLocation) return l.sector; else return null;
  }

  Coord3D? relativeDomainCoord(SpaceLocation loc) {
    SpaceLocation thisLoc = this;
    while (thisLoc.domain.isBelow(loc.domain) &&
        thisLoc.domain != Domain.hyperspace) {
      thisLoc = thisLoc.upper;
    }
    return thisLoc.domain == loc.domain ? thisLoc.cell.coord : null;
  }

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
    Domain.orbital => system.orbitalMapDim
  };

  double distCell(GridCell cell) => dist(cell.loc);
  double dist(SpaceLocation l) {
    if (l.domain == domain) return l.cell.coord.distance(cell.coord);
    glog("Warning: invalid ship location comparison", level: DebugLevel.Warning);
    return double.infinity;
  }
}

abstract class SystemLocation extends SpaceLocation {
  Coord3D sectorCoord;
  SectorLocation get sector => SectorLocation(system, sectorCoord);
  SectorCell get sectorCell => system.map[sectorCoord] as SectorCell;
  SystemLocation(super.system, this.sectorCoord);
}

class SectorLocation extends SystemLocation {
  @override
  SpaceLocation get upper => this; //no higher level

  @override
  Domain get domain => Domain.system;

  @override
  SectorCell get cell => sectorCell;

  @override
  SystemMap get map => system.map;

  SectorLocation(super.system, super.sectorCoord);

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

abstract class ImpulseScope extends SystemLocation {
  Coord3D get impulseCoord;
  ImpulseScope(super.system, super.sectorCoord);
}

class ImpulseLocation extends ImpulseScope {
  @override
  SpaceLocation get upper => sector;

  @override
  Domain get domain => Domain.impulse;
  Coord3D impulseCoord;

  @override
  SectorMap get map => sectorCell.map;

  ImpulseCell get cell => sectorCell.map.at(impulseCoord);

  ImpulseLocation(super.system, super.sectorCoord, this.impulseCoord);

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

class OrbitalLocation extends ImpulseScope {
  @override
  SpaceLocation get upper => impulse;
  ImpulseLocation get impulse => ImpulseLocation(system, sectorCoord, impulseCoord);

  @override
  Domain get domain => Domain.orbital;
  Coord3D impulseCoord,orbitalCoord;

  ImpulseCell get impulseCell => sector.map[impulseCoord] as ImpulseCell;

  @override
  ImpulseCell get cell => impulseCell.map.at(orbitalCoord);

  @override
  ImpulseMap get map => impulseCell.map;

  @override
  OrbitalLocation withCell(GridCell newCell) => OrbitalLocation(system, sectorCoord, impulseCoord, newCell.coord);

  OrbitalLocation(super.system, super.sectorCoord, this.impulseCoord, this.orbitalCoord);

  @override
  int get hashCode => Object.hash(system, domain, sectorCoord, impulseCoord, orbitalCoord);

  @override
  bool operator ==(Object other) => (super == other)
      && other is OrbitalLocation
      && other.sectorCoord == sectorCoord
      && other.impulseCoord == impulseCoord
      && other.orbitalCoord == orbitalCoord;

  @override
  String toString() {
    return "Sector: $sectorCoord\nImpulse: $impulseCoord\nOrbital: $orbitalCoord";
  }
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
