import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy.dart';

void main() {
  debugLevel = DebugLevel.Lowest;
  final engine = FugueEngine(Galaxy("Testlandia"), "Zug", seed: Random().nextInt(999));
  for (int i=0; i< 100; i++) {
    print("***");
    final rndSys = engine.galaxy.systems.elementAt(engine.rnd.nextInt(engine.galaxy.systems.length));
    print("${engine.galaxy.topo.distance(rndSys, engine.galaxy.fedHomeSystem)}");
    engine.populateSystem(rndSys,numShips: 3);
  }

}