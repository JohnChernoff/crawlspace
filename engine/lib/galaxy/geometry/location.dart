import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/galaxy/geometry/orbital.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import '../../ship/ship.dart';
import 'grid.dart';
import 'impulse.dart';
import '../system.dart';

sealed class SpaceLocation {
  Domain get domain;
  System system; //highest level
  SpaceLocation? get upper;
  Grid get grid;
  Coord3D get localCoord;
  CellMap get map => grid.map;
  GridCell get cell {
    final c = map[localCoord];
    if (c != null) return c; else throw StateError("Unknown cell at: $localCoord");
  }

  bool interactable(SpaceLocation loc) => loc.upper == upper;

  SectorLocation? get sectorOrNull {
    final l = this;
    if (l is SystemLocation) return l.sector; else return null;
  }

  Coord3D? relativeDomainCoord(SpaceLocation loc) {
    SpaceLocation? thisLoc = this;
    while (thisLoc != null && thisLoc.domain.isBelow(loc.domain) &&
        thisLoc.domain != Domain.hyperspace) {
      thisLoc = thisLoc.upper;
    }
    return thisLoc?.domain == loc.domain ? thisLoc!.cell.coord : null;
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
    //throw StateError("invalid location comparison: $this, $l");
    glog("Warning: invalid location comparison", level: DebugLevel.Warning);
    return double.infinity;
  }
}

abstract class SystemLocation extends SpaceLocation {
  @override
  bool interactable(SpaceLocation loc) => super.interactable(loc) && loc.system == system;

  final Coord3D sectorCoord;
  SectorLocation get sector => SectorLocation(system, sectorCoord);
  SectorCell get sectorCell => system.map[sectorCoord] as SectorCell;
  SystemLocation(super.system, this.sectorCoord);
}

class SectorLocation extends SystemLocation {
  Coord3D get localCoord => sectorCoord;

  @override
  SpaceLocation? get upper => null;

  @override
  Domain get domain => Domain.system;

  @override
  SectorCell get cell => super.cell as SectorCell; //sectorCell;

  @override
  Grid get grid => system;

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

abstract interface class ImpulseScope extends SystemLocation {
  Coord3D impulseCoord;
  ImpulseScope(super.system, super.sectorCoord, this.impulseCoord);
}

class ImpulseLocation extends ImpulseScope {
  @override
  Coord3D get localCoord => impulseCoord;

  @override
  SpaceLocation get upper => sector;

  @override
  Domain get domain => Domain.impulse;

  @override
  Grid get grid => sectorCell;

  ImpulseCell get cell => super.cell as ImpulseCell; //sectorCell.map.at(impulseCoord);

  ImpulseLocation(super.system, super.sectorCoord, super.impulseCoord);

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
  Coord3D get localCoord => orbitalCoord;

  @override
  SpaceLocation get upper => impulse;

  ImpulseLocation get impulse => ImpulseLocation(system, sectorCoord, impulseCoord);

  @override
  Domain get domain => Domain.orbital;
  Coord3D orbitalCoord;

  @override
  OrbitalCell get cell => super.cell as OrbitalCell; //impulseCell.map.at(orbitalCoord);

  ImpulseCell get impulseCell => impulse.map[impulseCoord] as ImpulseCell;
  @override
  Grid get grid => impulseCell;

  OrbitalLocation(super.system, super.sectorCoord, super.impulseCoord, this.orbitalCoord);

  @override
  OrbitalLocation withCell(GridCell newCell) => OrbitalLocation(system, sectorCoord, impulseCoord, newCell.coord);

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
  factory AtEnvironment.fromSystem(SectorLocation s) => AtEnvironment(SpaceEnvironment("",0.0,0.0),tmpLoc: s);
  @override
  SpaceLocation get loc => env.maybeLoc ?? _tmpLoc; // stable — fixed point
}
