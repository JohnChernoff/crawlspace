import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';
import '../star.dart';
import '../system.dart';

class StarRegistry extends SpaceRegistry<Star> {
  ImpulseLocation findGate(System system) {
    final arrivalGate = inSystem(system).where((s) => s.jumpgate).first;
    return locationOf(arrivalGate)!;
  }
  Star mainStar(System s) => inSystem(s).first;
}