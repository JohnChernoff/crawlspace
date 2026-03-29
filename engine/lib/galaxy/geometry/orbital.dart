import 'package:crawlspace_engine/controllers/scanner_controller.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/impulse.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/planet.dart';
import 'package:crawlspace_engine/galaxy/star.dart';
import 'grid.dart';

typedef SubOrbitalMap = MappedGrid<OrbitalCell>;

class OrbitalCell extends GridCell {
  final OrbitalLocation loc;
  SubOrbitalMap map;
  //planet is always at center
  Planet? planet(Galaxy g) => (this == loc.map.centerCell) ? impulseCell.getPlanet(g) : null;
  ImpulseCell impulseCell;

  OrbitalCell(
      this.impulseCell, {
        required super.coord,
        super.hazMap,
      }) : map = EmptySubOrbital.instance, loc = OrbitalLocation(
        impulseCell.sector.system,
        impulseCell.sector.coord,
        impulseCell.coord,
        coord);

  @override
  bool isEmpty(Galaxy g, {countPlayer = true}) {
    return planet(g) == null;
  }

  @override
  List<Planet> planets(Galaxy g) => planet(g) != null ? [planet(g)!] : [];

  @override
  bool scannable(ScannerMode mode, Galaxy g) => true;

  @override
  List<Star> stars(Galaxy g) => [];

}

class EmptySubOrbital extends SubOrbitalMap {
  static final instance = EmptySubOrbital._();
  EmptySubOrbital._() : super(GridDim(0, 0, 0), const {});
}