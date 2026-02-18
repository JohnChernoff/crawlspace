import 'dart:math';
import 'item.dart';
import 'pilot.dart';
import 'rng.dart';
import 'ship.dart';
import 'stock_items/stock_pile.dart';
import 'systems/ship_system.dart';

enum ShopType {
  power,engine,shield,weapon,launcher,misc
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

  Shop(this.type,this.techLvl,Random rnd, {this.buysScrap = false}) {
    name = ShopNameGen.generate(type, rnd);
    generateItems(rnd);
  }

  factory Shop.random(int tech, Random rnd, {bool scrap = false}) {
    final t = ShopType.values.elementAt(rnd.nextInt(ShopType.values.length));
    return Shop(t,tech,rnd,buysScrap: scrap);
  }

  TransactionResult buyItem(Item item, Ship ship) {
    final pilot = ship.pilot; if (pilot == nobody) return TransactionResult.wtf;
    final price = (item.baseCost / 2).round(); //TODO: some variable?
    if (credits > price) {
      if (pilot.transaction(TransactionType.shopSell,price)) {
        credits -= price;
        ship.jettisonItem(item);
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

  TransactionResult sellItem(ShopSlot slot, Ship ship) {
    if (slot.items.isEmpty) return TransactionResult.inventoryError;
    final i = slot.items.first;
    int price = i.baseCost;
    if (!ship.pilot.transaction(TransactionType.shopBuy,-price)) {
      return TransactionResult.insufficientFunds;
    } else if (ship.addToInventory(i)) {
      removeItem(slot);
      credits += price;
      return TransactionResult.ok;
    } else {
      ship.pilot.rollBack();
      return TransactionResult.inventoryError;
    }
  }

  String transactionSell(ShopSlot slot,Ship ship) {
    if (slot.items.isEmpty) return "Error: empty slot";
    Item item = slot.items.first;
    TransactionResult result = sellItem(slot,ship);
    return switch (result) {
      TransactionResult.ok => "Purchased: $item",
      TransactionResult.insufficientFunds => "You don't have enough credits",
      TransactionResult.inventoryError => "Your ship can't hold that!",
      TransactionResult.refusal => "No way!",
      TransactionResult.wtf => "Wtf!"
    };
  }

  String transactionBuy(Item item,Ship ship) {
    TransactionResult result = buyItem(item,ship);
    return (switch (result) {
      TransactionResult.ok => "Sold: $item",
      TransactionResult.insufficientFunds => "The shopkeeper can't afford that!",
      TransactionResult.inventoryError => "The shopkeeper hasn't room for that!",
      TransactionResult.refusal => "No way!",
      TransactionResult.wtf => "Wtf!",
    });
  }

  void generateItems(Random rnd, {double avgQuantity = 12}) {
    itemSlots.clear();
    int quantity = Rng.poissonRandom(avgQuantity);
    final itemSelection = switch(type) {
      ShopType.power => generateInventory(quantity,[ShipSystemType.power],techLvl,rnd),
      ShopType.engine => generateInventory(quantity,[ShipSystemType.engine],techLvl,rnd),
      ShopType.shield => generateInventory(quantity,[ShipSystemType.shield],techLvl,rnd),
      ShopType.weapon => generateInventory(quantity,[ShipSystemType.weapon],techLvl,rnd),
      ShopType.launcher => generateInventory(quantity,[ShipSystemType.launcher],techLvl,rnd),
      ShopType.misc => generateInventory(quantity,[ShipSystemType.power,ShipSystemType.engine],techLvl,rnd),
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

class ShopNameGen {
  static const List<String> alienPrefixes = [
    "Xar", "Qel", "Vor", "Zyn", "Tal", "Ixo", "Prax", "Khe", "Ulm", "Syr", "Nok",
    "Gor", "Leth", "Oon", "Trek", "Vash", "Zor", "Hyl", "Mek", "Thra"
  ];

  static const List<String> alienSuffixes = [
    "tek", "kor", "dyn", "plex", "zon", "ium", "rax", "mar", "shi", "tor", "vox",
    "bel", "tar", "nok", "thal", "vek", "lo", "zar"
  ];

  static const Map<ShopType, List<String>> shopFlavors = {
    ShopType.power:   ["Reactors", "Powerworks", "Fusion Emporium", "Core Depot"],
    ShopType.engine:  ["Engines", "Driveworks", "Propulsion Guild", "Thrust Hall"],
    ShopType.shield:  ["Shieldworks", "Deflector Forge", "Barrier Bazaar", "Wardens"],
    ShopType.weapon:  ["Arsenal", "Armory", "Killmart", "Gun Cathedral"],
    ShopType.launcher:["Launch Systems", "Missile Bay", "Tube Syndicate"],
    ShopType.misc:    ["Bazaar", "Emporium", "Tech Curios", "Oddities"]
  };

  static const List<String> megacorps = [
    "OmniDyne", "Hyperion", "CryoCore", "VoidStar", "Zenith Union", "NovaCorp"
  ];

  static const List<String> shopPatterns = [
    "{alien} {flavor}",
    "{alien}'s {flavor}",
    "The {alien} {flavor}",
    "{alien}-{alien} {flavor}",
    "{flavor} of {alien}",
    "{alien} & Sons {flavor}",
  ];

  static String randomAlienName(Random rnd) {
    String p = alienPrefixes[rnd.nextInt(alienPrefixes.length)];
    String s = alienSuffixes[rnd.nextInt(alienSuffixes.length)];

    // Occasionally mash two prefixes for more chaos
    if (rnd.nextDouble() < 0.15) {
      p += alienPrefixes[rnd.nextInt(alienPrefixes.length)].toLowerCase();
    }

    return p + s;
  }

  static String generate(ShopType type, Random rnd) {
    String alien = randomAlienName(rnd);
    String flavor = shopFlavors[type]![rnd.nextInt(shopFlavors[type]!.length)];
    String pattern = shopPatterns[rnd.nextInt(shopPatterns.length)];

    return pattern
        .replaceAll("{alien}", alien)
        .replaceAll("{flavor}", flavor);
  }
}
