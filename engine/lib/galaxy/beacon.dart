import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'geometry/object.dart';

class Beacon extends SpaceEnvironment<ImpulseLocation> {
  bool accessed = false;
  int number;
  Beacon(this.number) : super("A pulsating beacon emitting the number $number", 0.0, 0.0);
}
