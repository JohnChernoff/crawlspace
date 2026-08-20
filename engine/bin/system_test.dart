import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/ship/systems/ship_system.dart';

void main() {
  //debugLevel = DebugLevel.Lowest;
  final engine = FugueEngine(Galaxy("Testlandia"), "Zug", seed: 0); // Random().nextInt(999));

  for (int i=0; i< 12; i++) { //print("***");
    final rndSys = engine.galaxy.systems.elementAt(engine.mapRnd.nextInt(engine.galaxy.systems.length));
    engine.populateSystem(rndSys,numShips: 3);
  }
  for (final ship in engine.galaxy.ships.all) {
    print("Distance: ${engine.galaxy.topo.distance(ship.loc.system, engine.galaxy.fedHomeSystem)}");
    print(ship.summary());
  }

  print("***");

  final erghs = engine.galaxy.ships.all.where((s) => s.systemControl.getEngine(Domain.impulse, activeOnly: false) == null);
  for (final ergh in erghs) {
    print("No engine: $ergh");
    print(ergh.summary());
  }
}