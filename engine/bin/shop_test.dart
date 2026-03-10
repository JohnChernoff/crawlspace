import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/ship/systems/ship_system.dart';
import 'package:crawlspace_engine/shop.dart';
import 'package:crawlspace_engine/stock_items/corps.dart';
import 'package:crawlspace_engine/stock_items/ship_systems/stock_pile.dart';

void main() {
  final fm = FugueEngine(Galaxy("Testlandia"), "Zug", seed: Random().nextInt(999999));
  final planets = fm.galaxy.systems.where((s) => s.planets.isNotEmpty).map((ps) => ps.planets.first).toList();
  planets.shuffle(fm.mapRnd);
  final shops = planets.map((p) =>
      SystemShop(galaxy: fm.galaxy, p, SystemShopType.misc, Random().nextInt(maxTechLvl-1)+1, fm.itemRnd)
  ).toList(); // ← materialize here

  print("***");
  //sampleShops(fm,shops);
  sampleShops2(fm,shops);
}

void sampleShops(FugueEngine fm, Iterable<Shop> shops) {
  for (final shop in shops.take(12)) {
    printCorpWeights(fm, shop);
    print(shop);
    print("***");
  }
}

void sampleShops2(FugueEngine fm, Iterable<Shop> shops) {
  final stockedShops1 = shops.where((shop) => shop.inventory.all.any((s) => s is ShipSystem && s.manufacturer == Corporation.laventar)).toList();
  //for (final shop in stockedShops1) { printCorpWeights(fm, shop); print(shop); }
  print("Shops: ${shops.length}, inStock: ${stockedShops1.length}");

  final coreShops = shops.where((s) => fm.galaxy.corpMod.dominantCorp(s.location.locale.system) == Corporation.laventar).toList();;
  final stockedShops = coreShops.where((shop) => shop.inventory.all.any((s) => s is ShipSystem && s.manufacturer == Corporation.laventar)).toList();
  //for (final shop in stockedShops) print(shop);
  print("Shops: ${coreShops.length}, inStock: ${stockedShops.length}");
}

void printCorpWeights(FugueEngine fm, Shop shop) {
  final system = shop.location.locale.system; //print(fm.galaxy.corpMod.corpWeights(system)); return;
  final corps = fm.galaxy.corpMod.activeCorporations(system);
  print("System: ${system.name}");
  for (final c in corps) {
    final inf = fm.galaxy.corpMod.effectiveInfluence(c, system);
    print("  ${c.corpName}: ${inf.toStringAsFixed(2)}");
  }
}