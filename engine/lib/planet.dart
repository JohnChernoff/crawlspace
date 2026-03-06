import 'dart:math';
import 'package:crawlspace_engine/location.dart';
import 'package:crawlspace_engine/object.dart';
import 'package:crawlspace_engine/rng/rng.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'color.dart';
import 'stock_items/goods.dart';
import 'rng/descriptors.dart';
import 'rng/drinks_gen.dart';

enum DistrictLvl { none("-"), light("+"), medium("++"), heavy("+++");
  const DistrictLvl(this.shortString);
  bool atOrAbove(DistrictLvl lvl) => index >= lvl.index;
  final String shortString;
}

class Planet extends SpaceEnvironment<SystemLocation> {
  late PlanetAge age;
  late EnvType environment;
  late Goods export;
  double industry;    // 0–1
  double commerce;    // 0–1
  double population;  // 0–1
  late double wealth; // 0–1
  double hazard   = 0;
  double weirdness = 0;
  final bool homeworld;
  Species species;
  AlienDrink? drink;

  // ── Trade state ────────────────────────────────────────────────────────────
  // Populated by TradeModel after galaxy construction — Planet itself has
  // no Galaxy reference, so these are injected externally, same pattern
  // as fedLvl/techLvl being passed in from kernel values at construction.

  /// Goods this planet will buy, with demand intensity 0.0–1.0.
  /// Sorted descending by intensity. Set by TradeModel.initPlanetDemand().
  /// Empty until TradeModel has run.
  List<(SpecialGood, double)> demandList = const [];

  /// Universal commodities this planet produces, derived from environment.
  /// Set by TradeModel._buildSupplyMap(). Empty until TradeModel has run.
  Set<UniversalCommodity> universalSupply = const {};

  /// This planet's unique house special — rarely traded beyond the system.
  /// Null until TradeModel._seedHouseSpecials() has run.
  SpecialGood? houseSpecial;

  // ── Convenience accessors ──────────────────────────────────────────────────

  /// True if this planet produces the given universal commodity.
  bool produces(UniversalCommodity c) => universalSupply.contains(c);

  /// Demand intensity for a specific good, 0.0 if not on demand list.
  double demandFor(SpecialGood good) {
    for (final entry in demandList) {
      if (entry.$1 == good) return entry.$2;
    }
    return 0.0;
  }

  /// Top N goods by demand intensity — useful for shop display.
  List<(SpecialGood, double)> topDemand({int n = 3}) =>
      demandList.take(n).toList();

  /// True if this planet has meaningful demand for a good (above threshold).
  bool wants(SpecialGood good, {double threshold = 0.15}) =>
      demandFor(good) >= threshold;

  // ── Constructor ────────────────────────────────────────────────────────────

  DistrictLvl tier(double v) {
    if (v < 0.3) return DistrictLvl.none;
    if (v < 0.5) return DistrictLvl.light;
    if (v < 0.8) return DistrictLvl.medium;
    return DistrictLvl.heavy;
  }

  Planet(super.name, super.fedLvl, super.techLvl, Random rnd, {
    required this.species,
    this.homeworld = false,
    required super.locale,
    required this.industry,
    required this.commerce,
    required this.population,
  }) {
    weirdness   = rnd.nextDouble();
    age         = PlanetAge.values.elementAt(rnd.nextInt(PlanetAge.values.length));
    environment = EnvType.values.elementAt(rnd.nextInt(EnvType.values.length));

    // Use getRndExport() so export respects env/tech/industry constraints.
    // Falls back to a random pick if no filtered goods match (shouldn't happen
    // in practice given the broad coverage of Goods constraints).
    export = _pickExport(rnd);

    desc = "$name is ${article(age.toString())} "
        "${getDescriptor(WordType.adj)} ${getDescriptor(WordType.noun)} "
        "with ${article(environment.toString())} climate. "
        "Its chief exports include $export.";

    wealth = Rng.biasedRndDouble(rnd,
        mean: (population + commerce) / 2, min: 0, max: 1);
  }

  // ── Export selection ───────────────────────────────────────────────────────

  /// Picks an export that respects env/tech/industry constraints.
  /// Previously this was assigned randomly — now uses the filtered list
  /// that getRndExport() already computed.
  Goods _pickExport(Random rnd) {
    final filtered = _filteredGoods();
    if (filtered.isEmpty) {
      // Fallback: unconstrained goods only (the generics like rawMaterials)
      final generics = Goods.values.where((g) =>
      g.envList.isEmpty && g.dustLvl.isEmpty).toList();
      return generics.isEmpty
          ? Goods.values.first
          : generics[rnd.nextInt(generics.length)];
    }
    filtered.shuffle(rnd);
    return filtered.first;
  }

  List<Goods> _filteredGoods() => Goods.values.where((g) =>
  g.minTech <= techLvl &&
      (g.envList.isEmpty || g.envList.contains(environment)) &&
      (g.dustLvl.isEmpty || (
          g.dustLvl.first.index <= tier(industry).index &&
              g.dustLvl.last.index  >= tier(industry).index
      ))
  ).toList();

  // Kept for external callers — unchanged behavior, now backed by _filteredGoods.
  Goods getRndExport() {
    final goods = _filteredGoods()..shuffle();
    return goods.isEmpty ? export : goods.first;
  }

  // ── Descriptors ────────────────────────────────────────────────────────────

  String getDescriptor(WordType wordType) {
    List<PlanetDescriptor> descList = PlanetDescriptor.values.where((a) =>
    a.minInfluence <= fedLvl &&
        a.maxInfluence >= fedLvl &&
        a.minTech      <= techLvl &&
        a.maxTech      >= techLvl &&
        (a.resLvl.isEmpty  || (a.resLvl.first.index  <= tier(population).index &&
            a.resLvl.last.index   >= tier(population).index)) &&
        (a.commLvl.isEmpty || (a.commLvl.first.index  <= tier(commerce).index &&
            a.commLvl.last.index   >= tier(commerce).index)) &&
        (a.dustLvl.isEmpty || (a.dustLvl.first.index  <= tier(industry).index &&
            a.dustLvl.last.index   >= tier(industry).index)) &&
        a.wordType == wordType
    ).toList();
    descList.shuffle();
    return descList.isEmpty ? "?" : descList.first.toString();
  }

  // ── Display ────────────────────────────────────────────────────────────────

  GameColor color({required bool fedTech}) {
    if (fedTech) {
      return GameColor.fromRgb(
          255,
          ((techLvl / 100) * 200).ceil() + 55,
          ((fedLvl  / 100) * 200).ceil() + 55);
    } else {
      return GameColor.fromRgb(
          ((tier(population).index / DistrictLvl.values.length) * 200).ceil() + 55,
          ((tier(commerce).index  / DistrictLvl.values.length) * 200).ceil() + 55,
          ((tier(industry).index  / DistrictLvl.values.length) * 200).ceil() + 55);
    }
  }

  String shortString() {
    if (known) {
      return "$name (🛡$fedStr,⚙$techStr, "
          "RCI: ${tier(population).shortString} "
          "${tier(commerce).shortString} "
          "${tier(industry).shortString})";
    }
    return "$name (🛡$fedStr,⚙$techStr)";
  }

  /// Extended short string including top demand — useful for trade UI.
  String tradeString() {
    final wants = topDemand(n: 2)
        .map((e) => '${e.$1.name} (${(e.$2 * 100).round()}%)')
        .join(', ');
    final supply = universalSupply.map((c) => c.name).join(', ');
    return '${shortString()}'
        '${wants.isNotEmpty   ? '\n  wants:    $wants'  : ''}'
        '${supply.isNotEmpty  ? '\n  produces: $supply' : ''}';
  }

  @override
  String toString() {
    return "$name : Fed: $fedStr, Tech: $techStr, "
        "RCI: ${tier(population).name}/"
        "${tier(commerce).name}/"
        "${tier(industry).name}";
  }
}
