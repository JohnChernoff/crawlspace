import 'dart:math';
import 'package:crawlspace_engine/controllers/combat_controller.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/orbital.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import '../../controllers/scanner_controller.dart';
import '../planet.dart';
import '../star.dart';
import 'grid.dart';
import '../hazards.dart';
import '../../item.dart';
import 'object.dart';

typedef OrbitalMap = MappedGrid<OrbitalCell>;

class ImpulseCell extends GridCell {
  final ImpulseLocation loc;
  SectorCell sector;
  Asteroid? asteroid;

  @override
  List<Planet> planets(Galaxy g) => g.planets.inImpulse(loc).toList();
  @override
  List<Star> stars(Galaxy g) => g.stars.inImpulse(loc).toList();
  @override
  List<GravBuoy> buoys(Galaxy g) => g.buoys.inImpulse(loc).toList();

  Planet? getPlanet(Galaxy g) => g.planets.singleAtImpulse(loc);
  bool hasPlanet(Galaxy g) => getPlanet(g) != null;
  Star? getStar(Galaxy g) => g.stars.singleAtImpulse(loc);
  bool hasStar(Galaxy g) => getStar(g) != null;

  Set<ImpulseSlug> slugs(Galaxy g) => g.slugs.inImpulse(loc);

  @override
  OrbitalMap get map => loc.system.orbitalCache.putIfAbsent(coord,
          () => loc.system.generateOrbitalMap(this,Random(sector.impulseSeed))); //orbitalSeed?

  ImpulseCell(
      this.sector, {
        required super.coord,
        super.hazMap,
        this.asteroid
      }) : loc = ImpulseLocation(sector.system, sector.coord, coord);

  void hodgeTick(Hazard haz, Random rnd, {jitter = .1}) {
    final parentMap = sector.map;
    final Map<Coord3D,double> tmpCells = {};
    for (final entry in parentMap.values) {
      int count = parentMap.getAdjacentCells(entry).where((n) => n.hasHaz(haz)).length;
      if (entry.hasHaz(haz)) {
        if (count > 3 && count < 6) tmpCells[entry.coord] = entry.hazMap[haz]!;
        else tmpCells[entry.coord] = 0;
      } else {
        if (count == 5 || (count == 0 && rnd.nextDouble() < jitter)) tmpCells[entry.coord] = rnd.nextDouble();
        else tmpCells[entry.coord] = 0;
      }
    }
    for (final entry in parentMap.values) {
      entry.hazMap[haz] = tmpCells[entry.coord] ?? 0;
    }
  }

  @override
  bool scannable(ScannerMode mode, Galaxy g) {
    if (mode == ScannerMode.all) return true;
    if (mode.scaningShips && g.ships.atCell(this).isNotEmpty) return true;
    if (mode.scaningStars && hasStar(g)) return true;
    if (mode.scaningPlanets && hasPlanet(g)) return true;
    if (mode.scaningNeb && hasHaz(Hazard.nebula)) return true;
    if (mode.scaningIons && hasHaz(Hazard.ion)) return true;
    if (mode.scaningRoids && asteroid != null) return true;
    if (mode.scaningItems && g.items.byLoc(loc).isNotEmpty) return true;
    if (mode.scaningSlugs && slugs(g).isNotEmpty) return true;
    return false;
  }

  @override
  bool isEmpty(Galaxy g, {countPlayer = true}) {
    final ships = g.ships.atCell(this);
    if (ships.isNotEmpty && (countPlayer || ships.any((s) => s.npc))) return false;
    if (hasPlanet(g)) return false;
    if (hasStar(g)) return false;
    if (hazLevel > 0) return false;
    if (g.items.byLoc(loc).isNotEmpty) return false;
    if (asteroid != null) return false;
    if (slugs(g).isNotEmpty) return false;
    return true;
  }

  @override
  String toScannerString(Galaxy g, {verbose = false}) {
    StringBuffer sb = StringBuffer(super.toScannerString(g, verbose: verbose));
    Planet? planet = getPlanet(g);
    if (planet != null) sb.write(verbose ? planet.shortString() : planet.name);
    Star? star = getStar(g);
    if (star != null) sb.write(verbose ? star.stellarClass : star.name);
    for (final slug in slugs(g)) sb.write("$slug ");
    return sb.toString();
  }

}

class EmptyOrbital extends OrbitalMap {
  static final instance = EmptyOrbital._();
  EmptyOrbital._() : super(GridDim(0, 0, 0), const {});
}
