import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/shop.dart';
import 'package:crawlspace_engine/stock_items/ship_systems/stock_pile.dart';

void main() {
  final engine = FugueEngine(Galaxy("Testlandia"), "Zug", seed: Random().nextInt(999999));
  final planets = engine.galaxy.systems.where((s) => s.planets.isNotEmpty).map((ps) => ps.planets.first);
  for (int i=0; i<10; i++) {

    final planet = planets.elementAt(Random().nextInt(planets.length));
    final system = planet.locale.system;

    // print corp weights for this system
    final corps = engine.galaxy.corpMod.activeCorporations(system);
    print("System: ${system.name}");
    for (final c in corps) {
      final inf = engine.galaxy.corpMod.effectiveInfluence(c, system);
      print("  ${c.corpName}: ${inf.toStringAsFixed(3)}");
    }

    SystemShop shop = SystemShop(galaxy: engine.galaxy,
        planets.elementAt(Random().nextInt(planets.length)),SystemShopType.misc,Random().nextInt(maxTechLvl-1)+1,engine.itemRnd);
    print(shop.name); print(shop.techLvl); print(shop.location.loc.system);
    for (final slot in shop.inventory.slots) {
      print("${slot.items.first}: ${slot.items.length}");
    }
    print("***");
  }
}