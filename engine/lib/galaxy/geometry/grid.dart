import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import '../../controllers/scanner_controller.dart';
import '../../fugue_engine.dart';
import '../planet.dart';
import '../star.dart';
import 'coord_3d.dart';
import '../../effects.dart';
import '../hazards.dart';
import '../../ship/ship.dart';
import 'object.dart';

enum Domain {
  hyperspace,
  system,
  impulse,
  orbital;

  Domain get engineDomain => switch (this) {
    Domain.orbital => Domain.impulse,
    _ => this,
  };

  bool isAbove(Domain other) => index < other.index;
  bool isBelow(Domain other) => index > other.index;
}

abstract class Grid {
  CellMap get map;
  final Map<Hazard,double> hazMap;
  final EffectMap<CellEffect> effects = EffectMap();
  List<Planet> planets(Galaxy g);
  List<Star> stars(Galaxy g);
  List<MassiveObject> massiveObjects(Galaxy g) => [
    ...planets(g),
    ...stars(g),
  ];

  Grid({this.hazMap = const {}});
}

abstract class GridCell extends Grid {
  SpaceLocation get loc;
  Coord3D coord;

  GridCell({required this.coord,super.hazMap = const {}});

  double distCell(GridCell cell) => loc.dist(cell.loc);
  double dist(SpaceLocation loc) => this.loc.dist(loc);

  bool isEmpty(Galaxy g, {countPlayer = true});
  void clearHazard(Hazard haz) => hazMap.remove(haz);
  void clearHazards() => hazMap.clear();


  String toScannerString(Galaxy g) {
    StringBuffer sb = StringBuffer(toString());
    final hazards = hazMap.entries.where((h) => h.key != Hazard.wake && h.value > 0);
    for (final haz in hazards) sb.write("${haz.key.shortName}: ${haz.value.toStringAsFixed(2)} ");
    final ships = g.ships.atCell(this);
    if (ships.length > 1 || sb.length > 0) for (Ship ship in ships) sb.write("\n$ship ");
    else if (ships.length == 1) sb.write("${ships.first} ");
    return "$coord $sb";
  }

  bool scannable(ScannerMode mode, Galaxy g);
  double get hazLevel => hazMap.entries.where((h) => h.key != Hazard.wake).map((el) => el.value).sum;
  bool hasHaz(Hazard h) => hazMap.containsKey(h) && hazMap[h]! > 0;

  @override
  String toString() => "";
}

class MappedGrid<T extends GridCell> extends DenseCellMap<T> {
  @override
  final GridDim dim;

  final Map<Coord3D, T> _cells;

  MappedGrid(this.dim, Map<Coord3D, T> cells) : _cells = cells;

  @override
  T? operator [](Coord3D coord) => _cells[coord];

  @override
  void operator []=(Coord3D coord, T value) {
    _cells[coord] = value;
  }

  @override
  T? atXYZ(int x, int y, int z) => _cells[Coord3D(x, y, z)];

  @override
  T at(Coord3D coord) {
    final cell = _cells[coord];
    if (cell == null) throw StateError('No cell at $coord');
    return cell;
  }

  @override
  Iterable<T> get values => _cells.values;

}

abstract class CellMap<T extends GridCell> {
  //int get size;
  GridDim get dim;
  Map<Coord3D,Vec3> gravMap = {};
  Map<Coord3D,double> gravHeatMap = {};

  T? operator [](Coord3D coord);
  void operator []=(Coord3D coord, T value);
  Iterable<T> get values;

  T? atXYZ(int x, int y, int z);

  bool containsCoord(Coord3D c) =>
      c.x >= 0 && c.y >= 0 && c.z >= 0 &&
          c.x < dim.mx && c.y < dim.my && c.z < dim.mz;

  bool containsXYZ(int x, int y, int z) =>
      x >= 0 && y >= 0 && z >= 0 &&
          x < dim.mx && y <  dim.my && z < dim.mz;

  T rndCell(Random rnd, {List<T>? cellList}) {
    final list = cellList ?? values.toList();
    return list[rnd.nextInt(list.length)];
  }

  Coord3D rndCoord(Random rnd) => Coord3D.random(dim, rnd);

  T? get centerCell => this[(dim.center)];

  void updateGravMap(Galaxy g) {
    gravMap.clear();
    for (final cell in values) {
      Vec3 net = const Vec3(0, 0, 0);
      final objects = cell.loc is SectorLocation //make less kludgy?
      ? cell.loc.system.massiveObjects(g)
      : cell.loc.system.massiveObjects(g).where((o) => o.loc.sectorOrNull == cell.loc.sectorOrNull);
      for (final obj in objects) {
        final coord = obj.loc.relativeDomainCoord(cell.loc);
        if (coord == null) {
          print ("Warning: null gravity coordinate"); return;
        }
        final dx = coord.x - cell.coord.x;
        final dy = coord.y - cell.coord.y;
        final dz = coord.z - cell.coord.z;

        final offset = Vec3(dx.toDouble(), dy.toDouble(), dz.toDouble());
        final dist = offset.mag;

        if (cell.loc is ImpulseLocation) {
          glog("obj: ${obj.name}, obj coord: $coord, cell coord: ${cell.coord}, dist: $dist", level: DebugLevel.Fine);
        }
        if (dist == 0) continue; //TODO: invent something

        final direction = offset.normalized;
        final strength = obj.gravMass / (dist * dist);
            //obj.mass / (dist * dist);

        net = net + (direction * strength);
      }
      gravMap[cell.coord] = net;
    }

    final mags = gravMap.map((k, v) => MapEntry(k, v.mag));
    final maxMag = mags.values.isEmpty ? 0.0 : mags.values.reduce(max);

    gravHeatMap.clear();
    for (final entry in mags.entries) {
      final raw = maxMag == 0 ? 0.0 : entry.value / maxMag;
      gravHeatMap[entry.key] = sqrt(raw); // nicer spread
    }
  }

  Vec3 gravAt(Coord3D c) => gravMap[c] ?? const Vec3(0, 0, 0);
  double gravStrengthAt(Coord3D c) => gravAt(c).mag;
  Vec3 gravDirectionAt(Coord3D c) => gravAt(c).normalized;

  void growHazard(T cell, Hazard hazard, double strength, Random rnd, {spreadFactor = .25}) {
    cell.hazMap[hazard] = strength;
    double spreadProb = (rnd.nextDouble() * strength) * spreadFactor;
    for (final neighborCell in getAdjacentCells(cell)) {
      if (neighborCell.hazMap[hazard] == 0 && rnd.nextDouble() < spreadProb) {
        double nextStr = rnd.nextDouble() * strength;
        growHazard(neighborCell,hazard,nextStr,rnd);
      }
    }
  }

  Iterable<T> adjacentCells(T cell, {int distance = 1}) sync* {
    final cx = cell.coord.x;
    final cy = cell.coord.y;
    final cz = cell.coord.z;

    final minX = max(cx - distance, 0);
    final maxX = min(cx + distance, dim.mx - 1).clamp(0, dim.mx);
    final minY = max(cy - distance, 0);
    final maxY = min(cy + distance, dim.my - 1).clamp(0, dim.my);
    final minZ = max(cz - distance, 0);
    final maxZ = min(cz + distance, dim.mz - 1).clamp(0, dim.mz);

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        for (int z = minZ; z <= maxZ; z++) {
          if (x == cx && y == cy && z == cz) continue;

          final neighbor = atXYZ(x, y, z);
          if (neighbor != null) {
            yield neighbor;
          }
        }
      }
    }
  }

  List<T> getAdjacentCells(T cell, {int distance = 1}) =>
      adjacentCells(cell, distance: distance).toList();

  List<T> getOppositeEdgeCells(T cell) {
    final xMax = dim.mx - 1;
    final yMax = dim.my - 1;
    final zMax = dim.mz - 1;

    if (cell.coord.x == 0) {
      return values.where((c) => c.coord.x == xMax).toList();
    } else if (cell.coord.x == xMax) {
      return values.where((c) => c.coord.x == 0).toList();
    }

    if (cell.coord.y == 0) {
      return values.where((c) => c.coord.y == yMax).toList();
    } else if (cell.coord.y == yMax) {
      return values.where((c) => c.coord.y == 0).toList();
    }

    if (cell.coord.z == 0) {
      return values.where((c) => c.coord.z == zMax).toList();
    } else if (cell.coord.z == zMax) {
      return values.where((c) => c.coord.z == 0).toList();
    }

    return [];
  }

  List<T> greedyPath(T start, T goal, int maxSteps, Random rnd, {int nDist = 1, double minHaz = 0, double jitter = .2, forceHaz = false, ignoreHaz = false}) {
    final path = <T>[];
    T current = start;

    for (int i = 0; i < maxSteps; i++) {
      if (current == goal) break;

      final candidates = getAdjacentCells(current, distance: nDist).where((c) => !path.contains(c)).toList();

      candidates.sort((a, b) {
        final da = a.distCell(goal) + (rnd.nextDouble() * jitter);
        final db = b.distCell(goal) + (rnd.nextDouble() * jitter);
        return da.compareTo(db);
      });

      var next;
      if (ignoreHaz) {
        next = candidates.contains(goal) ? goal : candidates.first;
      } else {
        next = (candidates.contains(goal)) ? goal : candidates.firstWhereOrNull((c) => c.hazLevel <= minHaz);
        if (next == null && forceHaz) next = candidates.firstOrNull;
      }
      if (next == null) break;
      path.add(next);
      current = next;
    }

    return path;
  }
}

abstract class DenseCellMap<T extends GridCell> extends CellMap<T> {
  T at(Coord3D coord);
}

abstract class LazyCellMap<T extends GridCell> extends CellMap<T> {
  T getOrCreate(Coord3D coord);
}

class GridDim {
  final int mx;
  final int my;
  final int mz;
  Coord3D get center => Coord3D((mx/2).floor(), (my/2).floor(), (mz/2).floor());
  double get maxDist => sqrt(
    pow(mx - 1, 2) +
        pow(my - 1, 2) +
        pow(mz - 1, 2),
  );
  int get maxDim => [mx, my, mz].reduce(max);
  int get maxXY => max(mx, my);
  int get depth => mz;

  const GridDim(this.mx,this.my,this.mz);

  Coord3D rndCoord(Random rnd) => Coord3D(
      rnd.nextInt(mx),
      rnd.nextInt(my),
      rnd.nextInt(mz));
}

class LazyMappedGrid<T extends GridCell> extends LazyCellMap<T> {
  @override
  final GridDim dim;

  final Map<Coord3D, T> _cells = {};
  final T Function(Coord3D coord) _factory;

  LazyMappedGrid(this.dim, this._factory);

  @override
  T? operator [](Coord3D coord) =>
      containsCoord(coord) ? getOrCreate(coord) : null;

  @override
  void operator []=(Coord3D coord, T value) {
    if (!containsCoord(coord)) return;
    _cells[coord] = value;
  }

  @override
  T? atXYZ(int x, int y, int z) {
    if (!containsXYZ(x, y, z)) return null;
    return getOrCreate(Coord3D(x, y, z));
  }

  @override
  T getOrCreate(Coord3D coord) {
    if (!containsCoord(coord)) {
      throw StateError('Out of bounds: $coord');
    }
    return _cells.putIfAbsent(coord, () => _factory(coord));
  }

  @override
  Iterable<T> get values => _cells.values;
}
