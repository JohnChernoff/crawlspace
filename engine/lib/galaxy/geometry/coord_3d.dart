import 'dart:math';

import 'grid.dart';

const noCoord = const Coord3D(999999, 999999, 999999);
class Coord3D {
  final int x,y,z;
  const Coord3D(this.x,this.y,this.z);

  double distance(Coord3D? c) {
    if (c == null) return 0;
    final dx = (c.x - x).abs();
    final dy = (c.y - y).abs();
    final dz = (c.z - z).abs();
    return sqrt((dx*dx) + (dy*dy) + (dz*dz));
  }

  factory Coord3D.random(GridDim dim, Random rnd) {
    return Coord3D(rnd.nextInt(dim.mx),rnd.nextInt(dim.my),rnd.nextInt(dim.mz));
  }

  bool isEdge(GridDim dim) {
    final xMax = dim.mx - 1;
    final yMax = dim.my - 1;
    final zMax = dim.mz - 1;

    return x == 0 || x == xMax ||
        y == 0 || y == yMax ||
        z == 0 || z == zMax;
  }

  int distanceFromEdge(int size, {bool euclidian = true}) {
    // distance to nearest edge along each axis
    final dx = min(x, size - 1 - x);
    final dy = min(y, size - 1 - y);
    final dz = min(z, size - 1 - z);
    return euclidian
        ? sqrt(dx * dx + dy * dy + dz * dz).round()
        : dx + dy + dz;
  }

  Coord3D add(Object other) {
    if (other is Coord3D) return Coord3D(x + other.x, y + other.y, z + other.z);
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (other is Coord3D) return x == other.x && y == other.y && z == other.z;
    return false;
  }

  @override
  int get hashCode =>  Object.hash(x, y, z);

  @override
  String toString() {
    return "[$x,$y,$z]";
  }
}

class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double get mag => sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final m = mag;
    if (m <= 1e-9) return const Vec3(0, 0, 0);
    return Vec3(x / m, y / m, z / m);
  }

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
}
