import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';

void main() {
  int n = 12;
  debugLevel = DebugLevel.Lowest;
  final engine = FugueEngine(Galaxy("Testlandia"), "Zug", seed: 0); // Random().nextInt(999));
  for (int i=0; i<n; i++) {
    print("***");
    final rndSys = engine.galaxy.systems.elementAt(engine.mapRnd.nextInt(engine.galaxy.systems.length));
    print("Fed HW distance: ${engine.galaxy.topo.distance(rndSys, engine.galaxy.fedHomeSystem)}");
    print("Fed Influence: ${engine.galaxy.fedKernel.val(rndSys)}");
    print("Comm Influence: ${engine.galaxy.commerceKernel.val(rndSys)}");
    print("Planets: ");
    for (final planet in rndSys.planets) {
        print(planet);
    }
  }

  final fedVals = engine.galaxy.fedKernel.value.values.toList()..sort(); //print(vals);
  fedVals.sort();
  double p(double f) => fedVals[(fedVals.length * f).floor()];
  print("***");
  print("10% ${p(0.1)} 50% ${p(0.5)} 90% ${p(0.9)}");

  final commVals = engine.galaxy.commerceKernel.value.values.toList()..sort(); //print(vals);
  commVals.sort();
  double p2(double f) => commVals[(commVals.length * f).floor()];
  print("***");
  print("10% ${p2(0.1)} 50% ${p2(0.5)} 90% ${p2(0.9)}");
}