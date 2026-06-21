import 'package:crawlspace_engine/galaxy/beacon.dart';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';
import '../geometry/grid.dart';
import '../system.dart';

class BeaconRegistry extends ImpulseRegistry<Beacon> {

  @override
  Map<Domain, OccupancyPolicy> get occupancyPolicies => const {
    Domain.impulse: OccupancyPolicy.single,
  };

  System systemByNumber(int n) => all.where((e) => e.key.number == n).first.value.system;


}