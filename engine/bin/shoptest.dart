import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/shop.dart';
import 'package:crawlspace_engine/stock_items/stock_pile.dart';

void main() {
  final engine = FugueEngine(Galaxy("Testlandia"), "Zug", seed: Random().nextInt(999999));
  final planets = engine.galaxy.systems.where((s) => s.planets.isNotEmpty).map((ps) => ps.planets.first);
  for (int i=0; i<10; i++) {
    Shop shop = SystemShop(planets.elementAt(Random().nextInt(planets.length)),SystemShopType.misc,Random().nextInt(maxTechLvl-1)+1,engine.rnd);
    print(shop.name); //print(shop.techLvl);
    for (final slot in shop.inventory.slots) {
      print("${slot.items.first}: ${slot.items.length}");
    }
    print("***");
  }
}