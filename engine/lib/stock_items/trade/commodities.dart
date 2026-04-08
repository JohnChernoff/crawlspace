// ── Universal Commodity ───────────────────────────────────────────────────────
// Tier 1 — traded everywhere, thin margins, price varies by distance and
// local supply only. Every planet has baseline demand; supply is
// environmentally constrained.
//
// priceFloor/priceCeil keep profits thin by design.
// supplyEnvs: environments that produce this commodity naturally.
// demandDrivers: which stats push demand above baseline.

import 'dart:math';
import 'package:crawlspace_engine/stock_items/trade/trade_enums.dart';
import '../../galaxy/galaxy.dart';
import '../../galaxy/planet.dart';
import '../../galaxy/system.dart';
import '../../item.dart';
import '../../rng/descriptors.dart';

enum UniversalCommodity implements Normalizable {
  neutronium(
    8, 22,
    supplyEnvs: [EnvType.volcanic, EnvType.toxic],
    demandDrivers: {StatType.tech: 0.9, StatType.industry: 0.6},
    desc: "Refined stellar matter — the primary fuel for hyperspace drives. "
        "Every spacefaring world needs it; few can produce it.",
  ),
  rareMinerals(
    5, 18,
    supplyEnvs: [EnvType.mountainous, EnvType.rocky, EnvType.desert],
    demandDrivers: {StatType.industry: 0.8, StatType.tech: 0.5},
    desc: "Concentrated heavy-element ore. Essential for high-grade "
        "manufacturing and electronics.",
  ),
  constructionMaterials(
    3, 12,
    supplyEnvs: [EnvType.rocky, EnvType.mountainous, EnvType.alluvial],
    demandDrivers: {StatType.population: 0.7, StatType.industry: 0.6},
    desc: "Processed structural composites — the unglamorous backbone "
        "of every settlement.",
  ),
  unstableIsotopes(
    10, 30,
    supplyEnvs: [EnvType.volcanic, EnvType.toxic, EnvType.rocky],
    demandDrivers: {StatType.tech: 0.8, StatType.xenomancy: 0.5},
    desc: "Short-lived radioactive elements. Fuel for exotic reactors, "
        "xenomantic research, and things best left unasked.",
  ),
  organics(
    2, 10,
    supplyEnvs: [EnvType.jungle, EnvType.arboreal, EnvType.earthlike,
      EnvType.paradisiacal, EnvType.alluvial],
    demandDrivers: {StatType.population: 0.9, StatType.commerce: 0.4},
    desc: "Bulk biological matter — food stock, feedstock, raw biochemical "
        "inputs. Demand scales directly with mouths to feed.",
  ),
  water(
    2, 14,
    supplyEnvs: [EnvType.oceanic, EnvType.icy, EnvType.snowy, EnvType.arboreal],
    demandDrivers: {StatType.population: 0.8, StatType.industry: 0.4},
    desc: "Liquid water, purified and pressurized for transport. "
        "Scarce on arid and volcanic worlds; they pay accordingly.",
  ),
  oxygen(
    3, 16,
    supplyEnvs: [EnvType.arboreal, EnvType.jungle, EnvType.earthlike,
      EnvType.paradisiacal, EnvType.oceanic],
    demandDrivers: {StatType.population: 0.7, StatType.industry: 0.3},
    desc: "Compressed atmospheric oxygen. Toxic and icy worlds import "
        "vast quantities. Also used in industrial oxidation processes.",
  ),
  silicon(
    3, 13,
    supplyEnvs: [EnvType.desert, EnvType.arid, EnvType.rocky],
    demandDrivers: {StatType.tech: 0.7, StatType.industry: 0.7},
    desc: "Refined crystalline silicon — substrate for computing, "
        "solar collection, and most standard electronics.",
  );

  final int priceFloor;
  final int priceCeil;
  final List<EnvType> supplyEnvs;
  final Map<StatType, double> demandDrivers;
  final String desc;
  String get selectionName => name;

  const UniversalCommodity(
      this.priceFloor,
      this.priceCeil, {
        required this.supplyEnvs,
        required this.demandDrivers,
        required this.desc,
      });

  // True if this environment can supply this commodity
  bool producedBy(EnvType env) => supplyEnvs.contains(env);

  // Base demand intensity for a planet given its stats.
  // Returns 0.0–1.0. Callers apply distance modifier on top.
  double demandFor({
    required double tech,
    required double population,
    required double industry,
    required double commerce,
    required double militancy,
    required double xenomancy,
    required double wealth,
    required double fedLevel,
  }) {
    final statMap = {
      StatType.tech: tech,
      StatType.population: population,
      StatType.industry: industry,
      StatType.commerce: commerce,
      StatType.militancy: militancy,
      StatType.xenomancy: xenomancy,
      StatType.wealth: wealth,
      StatType.fedLevel: fedLevel,
    };
    double score = 0.0;
    double totalWeight = 0.0;
    for (final entry in demandDrivers.entries) {
      score += (statMap[entry.key] ?? 0.0) * entry.value;
      totalWeight += entry.value;
    }
    return totalWeight > 0 ? (score / totalWeight).clamp(0.0, 1.0) : 0.5;
  }

  // Price at a planet given local supply and distance from nearest source.
  // Clamped to [priceFloor, priceCeil] — thin margins by design.
  int priceAt({required bool hasLocalSupply, required int distFromSource}) {
    final supplyFactor = hasLocalSupply ? 0.0 : 1.0;
    final distFactor = 1 - exp(-distFromSource / 6.0);
    final raw = priceFloor + (priceCeil - priceFloor) * supplyFactor * distFactor;
    return raw.round().clamp(priceFloor, priceCeil);
  }

  Map<System,double> normalize(Galaxy g, {log = true}) {
    final normMap = <System, double>{};
    // compute all system prices
    final allPrices = <System, double>{};
    for (final system in g.systems) {
      final sysPrices = system.planets(g).map((p) {
        final hasSupply = g.tradeMod.planetSupply[p]
            ?.contains(this) ?? false;
        final dist = g.tradeMod.nearestSourceDist(this, p);
        return priceAt(
            hasLocalSupply: hasSupply,
            distFromSource: dist).toDouble();
      }).toList();
      if (sysPrices.isNotEmpty) {
        allPrices[system] = sysPrices.reduce((a, b) => a + b) / sysPrices.length;
      }
    }

    // normalize
    if (allPrices.isEmpty) return normMap;
    final minPrice = allPrices.values.reduce(min);
    final maxPrice = allPrices.values.reduce(max);
    for (final entry in allPrices.entries) {
      if (log) {
        normMap[entry.key] = maxPrice > minPrice
            ? log(entry.value - minPrice + 1) / log(maxPrice - minPrice + 1)
            : 0.5;
      } else {
        normMap[entry.key] = maxPrice > minPrice ? (entry.value - minPrice) / (maxPrice - minPrice) : 0.5;
      }
    }
    return normMap;
  }

  @override
  String toString() => enumToString(this, hyphenate: false);
}
