import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy.dart';

void main() {
  final engine = FugueEngine(Galaxy("Testlandia"), "Zug", seed: Random().nextInt(999));
  final rndSys = engine.galaxy.systems.elementAt(engine.rnd.nextInt(engine.galaxy.systems.length));
  print("System: $rndSys");
  print("${engine.galaxy.graphDistance(rndSys, engine.galaxy.homeSystem)}");
  engine.populateSystem(rndSys,numShips: 1);
}