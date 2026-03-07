import 'dart:math';

class Coord3D {
  final int x,y,z;
  Coord3D(this.x,this.y,this.z);

  double distance(Coord3D? c) {
    if (c == null) return 0;
    final dx = (c.x - x).abs();
    final dy = (c.y - y).abs();
    final dz = (c.z - z).abs();
    return sqrt((dx*dx) + (dy*dy) + (dz*dz));
  }

  factory Coord3D.random(int size, Random rnd) {
    return Coord3D(rnd.nextInt(size),rnd.nextInt(size),rnd.nextInt(size));
  }

  bool isEdge(int size) {
    final edge = size-1;
    return x == 0 || y == 0 || z == 0 || x == edge || y == edge || z == edge;
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
