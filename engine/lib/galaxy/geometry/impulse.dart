import 'dart:math';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import '../../controllers/scanner_controller.dart';
import '../planet.dart';
import '../star.dart';
import 'grid.dart';
import '../hazards.dart';
import '../../item.dart';

typedef ImpulseMap = MappedGrid<ImpulseCell>;

class ImpulseCell extends GridCell {
  final ImpulseLocation loc;

  @override
  List<Planet> planets(Galaxy g) =>
      [g.planets.byImpulse(loc)].whereType<Planet>().toList();
  @override
  List<Star> stars(Galaxy g) =>
      [g.stars.byImpulse(loc)].whereType<Star>().toList();

  Planet? getPlanet(Galaxy g) => g.planets.byImpulse(loc);
  bool hasPlanet(Galaxy g) => getPlanet(g) != null;
  Star? getStar(Galaxy g) => g.stars.byImpulse(loc);
  bool hasStar(Galaxy g) => getStar(g) != null;
  ImpulseMap map;
  SectorCell sector;
  bool outpost;

  ImpulseCell(
      this.sector, {
        required super.coord,
        super.hazMap,
        this.outpost = false,
      }) : map = EmptySubImpulse.instance, loc = ImpulseLocation(sector.system, sector.coord, coord);

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
    if (mode.scaningRoids && hasHaz(Hazard.roid)) return true;
    if (mode.scaningItems && g.items.anyAt(loc)) return true;
    return false;
  }

  @override
  bool isEmpty(Galaxy g, {countPlayer = true}) {
    final ships = g.ships.atCell(this);
    if (ships.isNotEmpty && (countPlayer || ships.any((s) => s.npc))) return false;
    if (hasPlanet(g)) return false;
    if (hasStar(g)) return false;
    if (hazLevel > 0) return false;
    if (g.items.anyAt(loc)) return false;
    return true;
  }

  @override
  String toScannerString(Galaxy g) {
    StringBuffer sb = StringBuffer(super.toScannerString(g));
    for (Item item in g.items.atLocation(loc)) {
      sb.write("\n${item.name}\n");
    }
    Planet? planet = getPlanet(g);
    if (planet != null) sb.write(planet.name);
    return sb.toString();
  }

}

class EmptySubImpulse extends ImpulseMap {
  static final instance = EmptySubImpulse._();
  EmptySubImpulse._() : super(GridDim(0, 0, 0), const {});
}
