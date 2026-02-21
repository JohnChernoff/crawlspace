import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/shop.dart';

void main() {
  final engine = FugueEngine(Galaxy("Testlandia"), "Zug");
  for (final system in engine.galaxy.systems) {
    if (system.planets.isNotEmpty) {
      Shop shop = Shop(system.planets.first,ShopType.misc,1,engine.rnd);
      for (final slot in shop.itemSlots) {
        print("${slot.items.first}: ${slot.items.length}");
      }
      break;
    }
  }
}