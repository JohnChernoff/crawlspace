import 'dart:math';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';
import '../geometry/coord_3d.dart';
import '../geometry/grid.dart';
import '../geometry/location.dart';
import '../geometry/object.dart';
import '../planet.dart';
import '../system.dart';

class BuoyRegistry extends ImpulseRegistry<GravBuoy> {
}

class PlanetRegistry extends OrbitalRegistry<Planet> {

  @override
  Map<Domain, OccupancyPolicy> get occupancyPolicies => const {
    Domain.impulse: OccupancyPolicy.single,
    Domain.orbital: OccupancyPolicy.single,
  };

  @override
  void onRegister(Planet p, OrbitalLocation loc) {
    super.onRegister(p, loc);
    //print("Registered: ${p.name}, ${loc.system.name}, $loc");
    //loc.cell.clearHazards();
  }

  OrbitalLocation randomUnoccupiedLocationBySector(
      System system,
      SectorLocation sector,
      Random rnd,
      ) {
    late OrbitalLocation loc;
    do {
      loc = OrbitalLocation(
        system,
        sector.sectorCoord,
        Coord3D.random(system.impulseMapDim, rnd),
        system.orbitalMapDim.center
      );
    } while (this.inImpulse(loc.impulse).isNotEmpty);
    return loc;
  }

  OrbitalLocation randomUnoccupiedLocation(System system, Random rnd) {
    late OrbitalLocation loc;
    do {
      loc = OrbitalLocation(
        system,
        Coord3D.random(system.systemMapDim, rnd),
        Coord3D.random(system.impulseMapDim, rnd),
        system.orbitalMapDim.center
      );
    } while (inImpulse(loc.impulse).isNotEmpty);
    return loc;
  }
}
