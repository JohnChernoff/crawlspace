import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import '../../ship/ship.dart';
import 'grid.dart';
import 'impulse.dart';
import '../system.dart';

sealed class SpaceLocation implements Locatable {
  SpaceLocation get loc => this;
  Domain get domain;
  System system;
  GridCell get cell; //TODO: error log
  CellMap get map;

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

class SectorLocation extends SpaceLocation {
  @override
  Domain get domain => Domain.system;

  Coord3D sectorCoord;

  @override
  SectorCell get cell => system.map[sectorCoord] as SectorCell;

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

class ImpulseLocation extends SpaceLocation {
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
  factory AtEnvironment.fromSystem(SectorLocation s) => AtEnvironment(SpaceEnvironment("",0,0,locale: s)); //TODO: copy galactic kernels
  @override
  SpaceLocation get loc => env.loc; // stable — fixed point
}
