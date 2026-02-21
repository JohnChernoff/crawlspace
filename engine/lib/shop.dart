import 'dart:math';
import 'package:crawlspace_engine/object.dart';
import 'fugue_engine.dart';
import 'item.dart';
import 'pilot.dart';
import 'rng.dart';
import 'ship.dart';
import 'stock_items/stock_pile.dart';
import 'systems/ship_system.dart';

enum ShopType {
  power,engine,shield,weapon,launcher,misc,shipyard
}

enum TransactionResult { ok, insufficientFunds, inventoryError, refusal, wtf}

class ShopOptions {
  int costRepair = 1, costRecharge = 1, costBioHack = 50, costBroadcast = 2000;
}

class ShopSlot {
  late List<Item> items;
  ShopSlot({List<Item>? itemList}) {
    items = itemList ?? [];
  }
}

class Shop {
  late String name;
  bool buysScrap;
  Set<ShopSlot> itemSlots = {};
  int credits = 10000;
  int techLvl;
  ShopType type;
  SpaceObject location;

  Shop(this.location,this.type,this.techLvl,Random rnd, {this.buysScrap = false, double avgQuantity = 12, List<Ship>? shiplist}) {
    name = ShopNameGen.generate(type, rnd);
    generateItems(rnd, avgQuantity: avgQuantity, shiplist: shiplist);
  }

  factory Shop.random(SpaceObject loc,int tech, Random rnd, {bool scrap = false}) {
    final t = ShopType.values.elementAt(rnd.nextInt(ShopType.values.length));
    return Shop(loc,t == ShopType.shipyard ? ShopType.misc : t,tech,rnd,buysScrap: scrap);
  }

  TransactionResult buyItem(Item item, {Ship? ship, Pilot? shiplessPilot}) {
    final pilot = ship?.pilot ?? shiplessPilot;
    if (pilot == null || pilot == nobody) return TransactionResult.wtf;
    final price = (item.baseCost / 2).round(); //TODO: some variable?
    if (credits > price) {
      if (pilot.transaction(TransactionType.shopSell,price)) {
        credits -= price;
        ship?.jettisonItem(item); //pilot inventory?
        if (item is ShipSystem) addItem(item); //TODO: generalize
        return TransactionResult.ok;
      }
      else {
        return TransactionResult.wtf;
      }
    } else {
      return TransactionResult.insufficientFunds;
    }
  }

  TransactionResult sellItem(ShopSlot slot, {Ship? ship, Pilot? shiplessPilot}) {
    if (slot.items.isEmpty) return TransactionResult.inventoryError;
    final pilot = ship?.pilot ?? shiplessPilot;
    if (pilot == null || pilot == nobody) return TransactionResult.wtf;
    final i = slot.items.first;
    int price = i.baseCost;
    if (!pilot.transaction(TransactionType.shopBuy,-price)) {
      return TransactionResult.insufficientFunds;
    } else {
      if (i is Ship) {
        location.hangar.add(i); //TODO: message?
      } else if (ship == null || !ship.addToInventory(i)) {
        return TransactionResult.inventoryError;
      }
      removeItem(slot);
      credits += price;
      return TransactionResult.ok;
    }
  }

  String transactionSell(ShopSlot slot, {Ship? ship, Pilot? shiplessPilot}) {
    if (slot.items.isEmpty) return "Error: empty slot";
    Item item = slot.items.first;
    TransactionResult result = sellItem(slot,ship: ship, shiplessPilot: shiplessPilot);
    return switch (result) {
      TransactionResult.ok => "Purchased: $item",
      TransactionResult.insufficientFunds => "You don't have enough credits",
      TransactionResult.inventoryError => "Your ship can't hold that!",
      TransactionResult.refusal => "No way!",
      TransactionResult.wtf => "Wtf!"
    };
  }

  String transactionBuy(Item item, {Ship? ship, Pilot? shiplessPilot}) {
    TransactionResult result = buyItem(item,ship: ship, shiplessPilot: shiplessPilot);
    return (switch (result) {
      TransactionResult.ok => "Sold: $item",
      TransactionResult.insufficientFunds => "The shopkeeper can't afford that!",
      TransactionResult.inventoryError => "The shopkeeper hasn't room for that!",
      TransactionResult.refusal => "No way!",
      TransactionResult.wtf => "Wtf!",
    });
  }

  void generateItems(Random rnd, {double avgQuantity = 12, List<Ship>? shiplist}) {
    itemSlots.clear();
    int quantity = Rng.poissonRandom(avgQuantity);
    final itemSelection = switch(type) {
      ShopType.power => generateInventory(quantity,[ShipSystemType.power],techLvl,rnd),
      ShopType.engine => generateInventory(quantity,[ShipSystemType.engine],techLvl,rnd),
      ShopType.shield => generateInventory(quantity,[ShipSystemType.shield],techLvl,rnd),
      ShopType.weapon => generateInventory(quantity,[ShipSystemType.weapon],techLvl,rnd),
      ShopType.launcher => generateInventory(quantity,[ShipSystemType.launcher],techLvl,rnd),
      ShopType.misc => generateInventory(quantity,[ShipSystemType.power,ShipSystemType.engine],techLvl,rnd),
      ShopType.shipyard => shiplist ?? [],
    };
    for (final i in itemSelection) {
      final slot = ShopSlot();
      do {
        slot.items.add(i);
      } while (rnd.nextBool() && rnd.nextDouble() > i.rarity);
      itemSlots.add(slot);
    }
  }

  void removeItem(ShopSlot slot) {
    if (slot.items.isNotEmpty) slot.items.removeLast();
    if (slot.items.isEmpty) itemSlots.remove(slot);
  }

  void addItem(Item i) {
    for (final slot in itemSlots) {
      if (slot.items.isNotEmpty && slot.items.first.name == i.name) {
        slot.items.add(i); return;
      }
    }
    itemSlots.add(ShopSlot(itemList: [i]));
  }

}


