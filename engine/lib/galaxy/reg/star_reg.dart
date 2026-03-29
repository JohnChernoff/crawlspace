import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';
import '../geometry/grid.dart';
import '../star.dart';
import '../system.dart';

class StarRegistry extends ImpulseRegistry<Star> {

  @override
  Map<Domain, OccupancyPolicy> get occupancyPolicies => const {
    Domain.impulse: OccupancyPolicy.single,
  };

  ImpulseLocation findGate(System system) {
    final arrivalGate = inSystem(system).where((s) => s.jumpgate).first;
    return locationOf(arrivalGate)!;
  }
  Star mainStar(System s) => inSystem(s).first;
}