import 'dart:math';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/object.dart';
import 'galaxy/goods.dart';
import 'item.dart';
import 'pilot.dart';
import 'planet.dart';
import 'rng/rng.dart';
import 'ship.dart';
import 'stock_items/stock_pile.dart';
import 'systems/ship_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared types
// ─────────────────────────────────────────────────────────────────────────────

enum TransactionResult { ok, insufficientFunds, inventoryError, refusal, wtf }

class ShopOptions {
  int costRepair    = 1;
  int costRecharge  = 1;
  int costBioHack   = 50;
  int costBroadcast = 2000;
}

// CommodityItem — thin Item wrapper for UniversalCommodity so universals
// fit the slot/inventory system without structural changes.
class CommodityItem extends Item {
  final UniversalCommodity commodity;
  CommodityItem(this.commodity, {required int marketPrice})
      : super(commodity.toString(),
      desc: commodity.desc,
      baseCost: marketPrice,
      rarity: 0.8);
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract base
// ─────────────────────────────────────────────────────────────────────────────

abstract class Shop {
  late String name;
  Inventory inventory = Inventory();
  int credits = 10000;
  SpaceEnvironment location;

  Shop(this.location);

  // ── Transactions ──────────────────────────────────────────────────────────
  // Shared logic — subclasses override buyItem() to control what they accept.

  TransactionResult sellItem(Item item, {Ship? ship, Pilot? shiplessPilot}) {
    if (!inventory.hasItem(item)) return TransactionResult.inventoryError;
    final pilot = ship?.pilot ?? shiplessPilot;
    if (pilot == null || pilot == nobody) return TransactionResult.wtf;

    final price = inventory.effectiveSellPrice(item);
    if (!pilot.transaction(TransactionType.shopBuy, -price)) {
      return TransactionResult.insufficientFunds;
    }
    if (item is Ship) {
      location.hangar.add(item);
    } else if (ship == null || !ship.addToInventory(item)) {
      return TransactionResult.inventoryError; //TODO: undo charge?
    }
    inventory.remove(item);
    credits += price;
    return TransactionResult.ok;
  }

  TransactionResult buyItem(Item item, {Ship? ship, Pilot? shiplessPilot}) {
    final pilot = ship?.pilot ?? shiplessPilot;
    if (pilot == null || pilot == nobody) return TransactionResult.wtf;
    final price = inventory.effectiveBuyBackPrice(item);
    if (credits < price) return TransactionResult.insufficientFunds;
    if (!pilot.transaction(TransactionType.shopSell, price)) return TransactionResult.wtf;
    credits -= price;
    ship?.jettisonItem(item);
    inventory.add(item);
    return TransactionResult.ok;
  }

  String transactionSell(Item item, {Ship? ship, Pilot? shiplessPilot}) {
    final price    = inventory.effectiveSellPrice(item);       // ← capture before
    final result   = sellItem(item, ship: ship, shiplessPilot: shiplessPilot);
    return switch (result) {
      TransactionResult.ok => "Purchased: ${item.name} ($price cr)",
      TransactionResult.insufficientFunds => "You don't have enough credits",
      TransactionResult.inventoryError    => "Your ship can't hold that!",
      TransactionResult.refusal           => "No way!",
      TransactionResult.wtf               => "Wtf!",
    };
  }

  String transactionBuy(Item item,
      {Ship? ship, Pilot? shiplessPilot}) {
    final result = buyItem(item, ship: ship, shiplessPilot: shiplessPilot);
    return switch (result) {
      TransactionResult.ok                => "Sold: $item",
      TransactionResult.insufficientFunds => "The shopkeeper can't afford that!",
      TransactionResult.inventoryError    => "The shopkeeper hasn't room for that!",
      TransactionResult.refusal           => "Not interested.",
      TransactionResult.wtf               => "Wtf!",
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SystemShop — ship systems: power, engines, shields, weapons, launchers, misc
// ─────────────────────────────────────────────────────────────────────────────

enum SystemShopType { power, engine, shield, weapon, launcher, misc }

class SystemShop extends Shop {
  final SystemShopType type;
  final int techLvl;
  final bool buysScrap;

  SystemShop(super.location, this.type, this.techLvl, Random rnd,
      {this.buysScrap = false, double avgQuantity = 12}) {
    name = ShopNameGen.generateSystem(type, techLvl, rnd);
    _generateItems(rnd, avgQuantity: avgQuantity);
  }

  factory SystemShop.random(SpaceEnvironment loc, int tech, Random rnd,
      {bool scrap = false}) {
    final t = SystemShopType.values[rnd.nextInt(SystemShopType.values.length)];
    return SystemShop(loc, t, tech, rnd, buysScrap: scrap);
  }

  void _generateItems(Random rnd, {double avgQuantity = 12}) {
    final quantity   = Rng.poissonRandom(avgQuantity);
    final sysTypes   = switch (type) {
      SystemShopType.power    => [ShipSystemType.power],
      SystemShopType.engine   => [ShipSystemType.engine],
      SystemShopType.shield   => [ShipSystemType.shield],
      SystemShopType.weapon   => [ShipSystemType.weapon],
      SystemShopType.launcher => [ShipSystemType.launcher],
      SystemShopType.misc     => [ShipSystemType.power, ShipSystemType.engine],
    };

    final itemSelection = generateSystemInventory(quantity, sysTypes, techLvl, rnd);
    if (itemSelection.isEmpty) return;

    while (inventory.count < quantity) {
      final i = itemSelection.elementAt(rnd.nextInt(itemSelection.length));
      if (rnd.nextDouble() < i.rarity) inventory.add(i.createSystem());
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ShipYard — ship purchases and hangar management
// ─────────────────────────────────────────────────────────────────────────────

class ShipYard extends Shop {
  final int techLvl;

  ShipYard(super.location, this.techLvl, Random rnd, {List<Ship>? shiplist}) {
    name = ShopNameGen.generateYard(techLvl, rnd);
    _generateItems(shiplist);
  }

  void _generateItems(List<Ship>? shiplist) {
    for (final ship in shiplist ?? <Ship>[]) {
      inventory.add(ship);
    }
  }

  // ShipYards don't buy arbitrary items
  @override
  TransactionResult buyItem(Item item,
      {Ship? ship, Pilot? shiplessPilot}) => TransactionResult.refusal;
}

// ─────────────────────────────────────────────────────────────────────────────
// Market — universal commodities + species specials + house specials
// ─────────────────────────────────────────────────────────────────────────────

class Market extends Shop {
  final Planet planet;
  final Galaxy galaxy;

  static const double commerceThreshold = 0.3;

  // What this Market will buy from the player: item name → buy price.
  final Map<String, int> buyList = {};

  Market(this.planet, this.galaxy, Random rnd) : super(planet) {
    name = _MarketNameGen.generate(planet, rnd);
    _generateStock(rnd);
    _buildBuyList();
  }

  static Market? maybeCreate(Planet planet, Galaxy galaxy, Random rnd) {
    if (planet.commerce < commerceThreshold) return null;
    return Market(planet, galaxy, rnd);
  }

  // ── Stock generation ──────────────────────────────────────────────────────

  void _generateStock(Random rnd) {
    inventory.clear();
    final tradeMod = galaxy.tradeMod;

    // Tier 1 — universal commodities
    for (final commodity in UniversalCommodity.values) {
      final dist = _nearestSourceDist(commodity);
      if (!planet.produces(commodity) && dist > 2) continue;

      final marketPrice = commodity.priceAt(
        hasLocalSupply: planet.produces(commodity),
        distFromSource: dist,
      );
      final qty = Rng.poissonRandom(planet.produces(commodity) ? 8.0 : 3.0)
          .clamp(1, 20);

      for (int i=0;i<qty;i++) {
        inventory.add(CommodityItem(commodity, marketPrice: marketPrice),
            data: SlotData(marketPrice: marketPrice,buyBackPrice: (marketPrice * 0.75).round()));
      }
    }

    // Tier 2 — species specials available near this planet
    for (final good in tradeMod.availableSpeciesGoods(planet)) {
      final sources = tradeMod.goodsSources[good] ?? [];
      final srcDist = sources.isEmpty
          ? galaxy.maxJumps
          : sources
          .map((p) => galaxy.topo
          .distance(p.locale.system, planet.locale.system))
          .reduce((a, b) => a < b ? a : b);

      final marketPrice = (good.baseCost * (1.0 + srcDist * 0.05))
          .round()
          .clamp(good.priceFloor, good.priceCeil);

      inventory.add(good, data: SlotData(marketPrice: marketPrice));
    }

    // Tier 3 — house special
    final house = planet.houseSpecial;
    if (house != null) {
      inventory.add(house);
    }
  }

  // ── Buy list ──────────────────────────────────────────────────────────────

  void _buildBuyList() {
    final tradeMod = galaxy.tradeMod;

    for (final commodity in UniversalCommodity.values) {
      final demand = tradeMod.universalDemandFor(commodity, planet);
      if (demand < 0.1) continue;
      final dist  = _nearestSourceDist(commodity);
      final price = commodity.priceAt(
          hasLocalSupply: planet.produces(commodity),
          distFromSource: dist);
      buyList[commodity.toString()] = price;
    }

    for (final entry in planet.demandList) {
      final good   = entry.$1;
      final demand = entry.$2;
      // demand 1.0 → 90% of baseCost, demand 0.1 → 20% — tune to taste
      final price  = (good.baseCost * (0.1 + demand * 0.8))
          .round()
          .clamp(good.priceFloor ~/ 2, good.priceCeil);
      buyList[good.name] = price;
    }
  }

  // ── Buy override ──────────────────────────────────────────────────────────

  @override
  TransactionResult buyItem(Item item,
      {Ship? ship, Pilot? shiplessPilot}) {
    final pilot = ship?.pilot ?? shiplessPilot;
    if (pilot == null || pilot == nobody) return TransactionResult.wtf;

    final price = buyList[item.name];
    if (price == null) return TransactionResult.refusal;
    if (credits < price) return TransactionResult.insufficientFunds;
    if (!pilot.transaction(TransactionType.shopSell, price)) return TransactionResult.wtf;

    credits -= price;
    ship?.jettisonItem(item);
    if (item is CommodityItem) inventory.add(item); // restock universal
    return TransactionResult.ok;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool canBuy(Item item) => buyList.containsKey(item.name);

  String buyListSummary() => buyList.isEmpty
      ? "Not buying anything."
      : buyList.entries.map((e) => "${e.key}: ${e.value}cr").join(", ");

  int _nearestSourceDist(UniversalCommodity commodity) {
    int nearest = galaxy.maxJumps;
    for (final entry in galaxy.tradeMod.planetSupply.entries) {
      if (entry.value.contains(commodity)) {
        final d = galaxy.topo
            .distance(entry.key.locale.system, planet.locale.system);
        if (d < nearest) nearest = d;
      }
    }
    return nearest;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Name generators
// ─────────────────────────────────────────────────────────────────────────────

class ShopNameGen {
  static const _systemNames = {
    SystemShopType.power:    ["Power Supply Co.", "Reactor Depot",   "Core Systems"],
    SystemShopType.engine:   ["Drive Works",      "Thrust & Co.",    "Engine Bay"],
    SystemShopType.shield:   ["Shield Emporium",  "Aegis Supply",    "Barrier Tech"],
    SystemShopType.weapon:   ["Armaments Plus",   "Ballistics Depot","Fire Control"],
    SystemShopType.launcher: ["Launch Systems",   "Ordinance Bay",   "Payload Depot"],
    SystemShopType.misc:     ["General Outfitters","Surplus Depot",  "Mixed Systems"],
  };

  static const _yardNames = [
    "Drydock", "Shipworks", "Orbital Yard", "Hull & Co.", "Vessel Exchange",
  ];

  static String generateSystem(SystemShopType type, int techLvl, Random rnd) {
    final pool = _systemNames[type]!;
    return pool[rnd.nextInt(pool.length)];
  }

  static String generateYard(int techLvl, Random rnd) =>
      _yardNames[rnd.nextInt(_yardNames.length)];
}

class _MarketNameGen {
  static const _prefixes  = [
    "Galactic", "Interstellar", "Void", "Frontier",
    "Outer Rim", "Deep Space",  "Colonial", "Free", "Waypoint",
  ];
  static const _names      = [
    "Exchange", "Market", "Trading Post", "Emporium",
    "Depot",    "Commissary", "Brokerage", "Clearinghouse",
  ];
  static const _fancyNames = [
    "Mercantile Exchange", "Trade Consortium",
    "Commerce Hub",        "Grand Emporium",
  ];

  static String generate(Planet planet, Random rnd) {
    final prefix = _prefixes[rnd.nextInt(_prefixes.length)];
    final suffix = planet.commerce > 0.7
        ? _fancyNames[rnd.nextInt(_fancyNames.length)]
        : _names[rnd.nextInt(_names.length)];
    return "$prefix $suffix";
  }
}