import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';

void main() {
  final fm = FugueEngine(Galaxy("Testlandia"), "Zug", seed: 0); // Random().nextInt(999));
  for (int i=0; i< 12; i++) {
    print("***");
    //final humanSpace = fm.galaxy.territory(StockSpecies.humanoid.species);
    //final rndSys = humanSpace.elementAt(fm.itemRnd.nextInt(humanSpace.length));
    final rndSys = fm.galaxy.rndLoc(fm.itemRnd).level;
    print("System: ${rndSys.name}");
    print(fm.galaxy.itemRepository.inSystem(rndSys));
  }
}