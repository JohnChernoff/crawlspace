import 'dart:math';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';
import '../geometry/coord_3d.dart';
import '../geometry/location.dart';
import '../planet.dart';
import '../system.dart';

class PlanetRegistry extends SpaceRegistry<Planet> {
  @override
  void onRegister(Planet p, ImpulseLocation loc) {
    loc.cell.clearHazards();
  }

  ImpulseLocation randomUnoccupiedLocationBySector(
      System system,
      SectorLocation sector,
      Random rnd,
      ) {
    late ImpulseLocation loc;
    do {
      loc = ImpulseLocation(
        system,
        sector.sectorCoord,
        Coord3D.random(system.impulseMapDim, rnd),
      );
    } while (byImpulse(loc) != null);
    return loc;
  }

  ImpulseLocation randomUnoccupiedLocation(System system, Random rnd) {
    late ImpulseLocation loc;
    do {
      loc = ImpulseLocation(
        system,
        Coord3D.random(system.systemMapDim, rnd),
        Coord3D.random(system.impulseMapDim, rnd),
      );
    } while (byImpulse(loc) != null);
    return loc;
  }
}
