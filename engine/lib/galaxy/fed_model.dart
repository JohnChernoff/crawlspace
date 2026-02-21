import 'dart:math';
import 'package:crawlspace_engine/galaxy/sub_model.dart';
import 'system.dart';

//double fedEdgeWeight(System a, System b) => fedPressure[a]!;
class FederationModel extends GalaxySubMod {
  late Map<System,double> fedPressure;
  double fedSource(System s) => fedPressure[s]! * 0.01;

  FederationModel(super.galaxy) {
    computeFedPressure();
  }

  void computeFedPressure() {
    fedPressure = {};
    for (final s in systems) {
      final d = distance(galaxy.fedHomeSystem,s);
      fedPressure[s] = exp(-d / 8.0); // tweak falloff
      //fedPressure[s] *= 0.8 + rnd.nextDouble() * 0.4;
    }
  }

  void dumpFedGradient() {
    systems
        .toList()
      ..sort((a,b) => fedPressure[b]!.compareTo(fedPressure[a]!))
      ..take(10)
          .forEach((s) => print("${s.name}: ${fedPressure[s]!.toStringAsFixed(2)}"));
  }

}
