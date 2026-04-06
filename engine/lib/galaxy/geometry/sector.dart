import 'dart:math';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/path_gen.dart';
import 'package:crawlspace_engine/galaxy/planet.dart';
import 'package:crawlspace_engine/galaxy/star.dart';
import 'package:crawlspace_engine/galaxy/system.dart';
import '../../controllers/scanner_controller.dart';
import '../../stock_items/species.dart';
import 'grid.dart';
import '../hazards.dart';
import 'impulse.dart';
import 'object.dart';

typedef ImpulseMap = MappedGrid<ImpulseCell>;

class Asteroid extends MassiveObject {
  Asteroid(super.name, {super.mass});
}

class SectorCell extends GridCell {
  final SectorLocation loc;
  final System system;
  bool hasBuoy = false;
  //int roidSeed = 1; Map<Coord3D,Asteroid> asteroidMap = {};

  @override
  List<Planet> planets(Galaxy g) => g.planets.inSector(loc).toList();
  @override
  List<Star> stars(Galaxy g) => g.stars.inSector(loc).toList();
  @override
  List<GravBuoy> buoys(Galaxy g) => g.buoys.inSector(loc).toList();

  int numPlanets(Galaxy g) => planets(g).length;
  bool hasPlanets(Galaxy g) => numPlanets(g) > 0;
  int numStars(Galaxy g) => stars(g).length;
  bool hasStars(Galaxy g) => numStars(g) > 0;
  bool hasGate(Galaxy g) => stars(g).any((s) => s.jumpgate);

  bool starOne, blackHole;
  int impulseSeed;

  @override
  ImpulseMap get map => system.impulseCache.putIfAbsent(coord,
        () => generateImpulseMap(Random(impulseSeed)),
  );

  SectorCell(
      this.system,
      this.impulseSeed, {
        required super.coord,
        super.hazMap,
        this.starOne = false,
        this.blackHole = false,
        Faction? propriator,
      }) : loc = SectorLocation(system, coord);

  ImpulseMap generateImpulseMap(Random rnd) {
    final dim = system.impulseMapDim;
    final sectorIon = hazMap[Hazard.ion] ?? 0;
    final sectorNeb = hazMap[Hazard.nebula] ?? 0;

    final cells = <Coord3D, ImpulseCell>{};
    for (int x = 0; x < dim.mx; x++) {
      for (int y = 0; y < dim.my; y++) {
        for (int z = 0; z < dim.mz; z++) {
          final c = Coord3D(x, y, z);
          final buoy = hasBuoy && c == dim.center;
          cells[c] = ImpulseCell(
            this,
            coord: c,
            asteroid: !buoy && (hasHaz(Hazard.roid) || hasBuoy) && rnd.nextDouble() < .1
              ? Asteroid("Asteroid", mass: 1000)
              : null,
            hazMap: buoy ? {} : {
              Hazard.nebula: rnd.nextDouble() < sectorNeb ? sectorNeb : 0,
              Hazard.ion: rnd.nextDouble() < sectorIon ? sectorIon : 0,
              //Hazard.roid: hazMap[Hazard.roid] ?? (hasBuoy && rnd.nextDouble() < .1 ? : 0),
              //Hazard.wake: c.isEdge(dim) ? 1 : 0, //TODO: perhaps for 3D only
            },
          );
        }
      }
    }
    final impMap = ImpulseMap(dim, cells);
    //if (hasHaz(Hazard.roid)) PathGenerator.generate(impMap, 4, 0, rnd, haz: Hazard.roid);
    return impMap;
  }

  bool hasGravitySource(Galaxy g) => hasStars(g) || hasPlanets(g) || hasBuoy;

  @override
  bool isEmpty(Galaxy g, {countPlayer = true}) { //print("Checking empty");
    final ships = g.ships.atCell(this);
    if (ships.isNotEmpty && (countPlayer || ships.any((s) => s.npc))) return false;
    if (hasPlanets(g)) return false;
    if (hasStars(g)) return false;
    if (hasBuoy) return false;
    if (starOne || blackHole) return false;
    if (hazLevel > 0) return false;
    return true;
  }

  @override
  String toScannerString(Galaxy g) {
    StringBuffer sb = StringBuffer(super.toScannerString(g));
    int i = sb.isEmpty ? 0 : 1;
    for (final planet in g.planets.inSector(loc)) {
      final comma = i++ > 1 ? "," : "";
      sb.write("$comma${planet.name}");
    }
    for (final star in g.stars.inSector(loc)) {
      final comma = i++ > 1 ? "," : "";
      sb.write("$comma${star.name}");
    }
    for (final buoy in g.buoys.inSector(loc)) {
      final comma = i++ > 1 ? "," : "";
      sb.write("$comma${buoy.name}");
    }
    return sb.toString();
  }

  @override //TODO: Nebula Effects
  bool scannable(ScannerMode mode,Galaxy g) {
    if (mode == ScannerMode.all) return true;
    if (mode.scaningShips && g.ships.atCell(this).isNotEmpty) return true;
    if (mode.scaningPlanets && hasPlanets(g)) return true;
    if (mode.scaningStars && hasStars(g)) return true;
    if (mode.scaningBuoys && hasBuoy) return true;
    if (mode.scaningNeb && hasHaz(Hazard.nebula)) return true;
    if (mode.scaningIons && hasHaz(Hazard.ion)) return true;
    if (mode.scaningRoids && hasHaz(Hazard.roid)) return true;
    if (mode.scaningStarOne && starOne) return true;
    if (mode.scaningBlackhole && blackHole) return true;
    return false;
  }

}

class EmptyImpulse extends ImpulseMap {
  EmptyImpulse() : super(GridDim(0, 0, 0), {});
}
