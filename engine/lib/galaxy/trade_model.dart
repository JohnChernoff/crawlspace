// trade_model.dart
// Galaxy-level trade system — seeded once at galaxy creation, consistent
// across saves for a given seed.
//
// Responsibilities:
//   - Generate the SpecialGood pool per species (4 handcrafted + 2 random)
//   - Assign species goods to source planets near each homeworld
//   - Generate planetary house specials (tier 3, rarely traded)
//   - Expose demand queries used by shops and price calculations
//
// Dependencies (must exist before TradeModel is constructed):
//   civMod       — dominantSpecies, civIntensity
//   topo         — distance, distCache
//   kernels      — commerceKernel, techKernel (for demand intensity)
//   planets      — all systems must have planets assigned

import 'dart:math';
import 'package:crawlspace_engine/galaxy/sub_model.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:crawlspace_engine/planet.dart';
import 'package:crawlspace_engine/galaxy/system.dart';

import '../fugue_engine.dart';
import '../rng/goods_gen.dart';
import '../stock_items/goods.dart';

// ── How far from homeworld a species special is likely to be produced ─────────
const int _speciesGoodsSourceRadius = 4; // systems
const int _handcraftedPerSpecies    = 4;
const int _randomPerSpecies         = 2;

// ── How far demand for a species special meaningfully reaches ─────────────────
// Beyond this, demand exists only as a faint curiosity signal (alienDriver)
const int _speciesDemandCoreRadius  = 6; // systems

class TradeModel extends GalaxySubMod {

  // ── Species special goods pool ─────────────────────────────────────────────
  // Generated once at seed time. Key = StockSpecies.
  // All SpecialGoods for a species — both handcrafted and random.
  final Map<StockSpecies, List<SpecialGood>> speciesGoods = {};

  // ── Source planets for species goods ──────────────────────────────────────
  // Which planets produce a given SpecialGood this run.
  // A good can have 1–3 source planets, all near the homeworld.
  final Map<SpecialGood, List<Planet>> goodsSources = {};

  // ── Planetary house specials ───────────────────────────────────────────────
  // Tier 3 — one per planet, rarely traded outside the system.
  final Map<Planet, SpecialGood> houseSpecials = {};

  // ── Demand cache ──────────────────────────────────────────────────────────
  // planet → good → demand intensity 0.0–1.0
  // Computed lazily and cached — demand is static unless an event fires.
  final Map<Planet, Map<SpecialGood, double>> _demandCache = {};

  // ── Universal commodity supply map ────────────────────────────────────────
  // planet → set of universals it produces (derived from EnvType)
  final Map<Planet, Set<UniversalCommodity>> planetSupply = {};

  TradeModel(super.galaxy) {
    // Dedicated RNG — seeded off galaxy.rnd's next value so it's
    // reproducible per galaxy seed without consuming the main rnd stream
    // unpredictably. Same pattern as FugueEngine's split RNGs.
    final tradeRng = Random(galaxy.rnd.nextInt(0x7FFFFFFF) ^ 0x75AE5EED);

    _seedSpeciesGoods(tradeRng);
    _assignSourcePlanets(tradeRng);
    _seedHouseSpecials(tradeRng);
    _buildSupplyMap();

    _debugDump();
  }

  // ── Step 1: generate species goods pool ───────────────────────────────────
  void _seedSpeciesGoods(Random rnd) {
    for (final stockSpecies in StockSpecies.values) {
      final goods = <SpecialGood>[];
      final usedArchetypes = <GoodsArchetype>[];

      // Handcrafted — archetypes in declaration order for this species
      final archetypes = GoodsArchetype.forSpecies(stockSpecies);
      for (int i = 0; i < _handcraftedPerSpecies && i < archetypes.length; i++) {
        final good = GoodsGen.fromArchetype(
          archetypes[i],
          rnd,
          weirdness: _speciesWeirdness(stockSpecies),
        );
        goods.add(good);
        usedArchetypes.add(archetypes[i]);
      }

      // Random — weighted by species traits, no repeats
      for (int i = 0; i < _randomPerSpecies; i++) {
        final good = GoodsGen.generateRandom(
          stockSpecies,
          rnd,
          weirdness: _speciesWeirdness(stockSpecies),
          exclude: usedArchetypes,
        );
        goods.add(good);
        usedArchetypes.add(good.archetype);
      }

      speciesGoods[stockSpecies] = goods;

      glog("TradeModel: ${stockSpecies.species.name} goods: "
          "${goods.map((g) => g.name).join(', ')}");
    }
  }

  // ── Step 2: assign source planets ─────────────────────────────────────────
  // Each good gets 1–2 source planets near the homeworld.
  // Weighted by distance — closer systems more likely to be sources.
  // A planet can source multiple goods but not from different species.
  void _assignSourcePlanets(Random rnd) {
    for (final entry in speciesGoods.entries) {
      final stockSpecies = entry.key;
      final goods        = entry.value;
      final homeSystem   = galaxy.findHomeworld(stockSpecies.species);

      // Candidate planets: within radius, has planets, dominant species matches
      final candidates = nearbyPlanets(homeSystem, _speciesGoodsSourceRadius)
          .where((p) => dominantSpeciesAt(p) == stockSpecies.species)
          .toList();

      if (candidates.isEmpty) {
        // Fallback: any planet in homeworld system
        final fallback = homeSystem.planets;
        for (final good in goods) {
          goodsSources[good] = fallback.isNotEmpty ? [fallback.first] : [];
        }
        continue;
      }

      for (final good in goods) {
        // Distance-weighted pick — closer = more likely source
        final weights = <Planet, double>{};
        for (final p in candidates) {
          final d = galaxy.topo.distance(p.locale.system, homeSystem);
          weights[p] = 1.0 / (1 + d); // inverse distance weight
        }

        // Pick 1 or 2 source planets
        final numSources = rnd.nextDouble() < 0.35 ? 2 : 1;
        final sources = <Planet>[];
        for (int i = 0; i < numSources && candidates.isNotEmpty; i++) {
          final picked = _weightedPickPlanet(weights, rnd);
          sources.add(picked);
          weights.remove(picked); // no repeats
        }
        goodsSources[good] = sources;
      }
    }
  }

  // ── Step 3: house specials ────────────────────────────────────────────────
  // One per planet, generated from the planet's own character.
  // Uses a house archetype synthesized from the dominant species' pool
  // but weighted strongly toward the planet's own stats.
  void _seedHouseSpecials(Random rnd) {
    for (final system in systems) {
      for (final planet in system.planets) {
        final dominant = dominantStockSpeciesAt(planet);
        if (dominant == null) continue;

        // House specials use planet weirdness heavily — they're idiosyncratic
        final good = GoodsGen.generateRandom(
          dominant,
          rnd,
          weirdness: planet.weirdness,
          exclude: [], // house specials can repeat archetype — they're unique by planet
        );
        houseSpecials[planet] = good;
      }
    }
  }

  // ── Step 4: universal supply map ─────────────────────────────────────────
  // Derived purely from EnvType — no RNG needed.
  void _buildSupplyMap() {
    for (final system in systems) {
      for (final planet in system.planets) {
        final supply = <UniversalCommodity>{};
        for (final commodity in UniversalCommodity.values) {
          if (commodity.producedBy(planet.environment)) {
            supply.add(commodity);
          }
        }
        planetSupply[planet] = supply;
      }
    }
  }

  // ── Demand queries ────────────────────────────────────────────────────────

  // Demand intensity for a SpecialGood at a planet, 0.0–1.0.
  // Factors in:
  //   - Whether this planet's species has affinity for the good (reach)
  //   - Distance from source (steeper falloff for speciesOnly goods)
  //   - Planet stats via archetype demandDrivers
  //   - Political relationship between planet's species and good's species
  double demandFor(SpecialGood good, Planet planet) {
    return _demandCache
        .putIfAbsent(planet, () => {})
        .putIfAbsent(good, () => _computeDemand(good, planet));
  }

  double _computeDemand(SpecialGood good, Planet planet) {
    final system          = planet.locale.system;
    final homeSystem      = galaxy.findHomeworld(good.species.species);
    final distFromHome    = galaxy.topo.distance(system, homeSystem);
    final dominantSpecies = galaxy.civMod.dominantSpecies(system);

    // ── Base demand from planet stats ──
    final dominant = galaxy.civMod.dominantSpecies(system); //TODO: modulate?
    final statMap  = {
      StatType.tech:       planet.techLvl,
      StatType.population: planet.population,
      StatType.industry:   planet.industry,
      StatType.commerce:   planet.commerce,
      StatType.wealth:     planet.wealth,
      StatType.fedLevel:   planet.fedLvl,
      StatType.militancy:  dominant?.militancy  ?? 0.5,
      StatType.xenomancy:  dominant?.xenomancy  ?? 0.5,
    };
    double totalWeight = 0;
    double score       = 0;
    for (final entry in good.archetype.demandDrivers.entries) {
      score       += (statMap[entry.key] ?? 0.0) * entry.value;
      totalWeight += entry.value;
    }
    final statDemand = totalWeight > 0
        ? (score / totalWeight).clamp(0.0, 1.0)
        : 0.0;

    // ── Reach modifier ──
    final reachMod = switch (good.reach) {
      DemandReach.speciesOnly => _speciesOnlyMod(good, dominantSpecies, distFromHome),
      DemandReach.speciesCore => _speciesCoreMod(good, dominantSpecies, distFromHome),
      DemandReach.political   => _politicalMod(system),
      DemandReach.crossCultural => _crossCulturalMod(dominantSpecies, good, distFromHome),
    };

    // ── Political relationship modifier ──
    // Species that like each other develop more demand for each other's goods
    final politicalMod = _politicalRelationshipMod(dominantSpecies, good);

    return (statDemand * reachMod * politicalMod).clamp(0.0, 1.0);
  }

  // speciesOnly: near-zero outside producing species, falls off sharply
  double _speciesOnlyMod(SpecialGood good, Species? dominant, int dist) {
    if (dominant == null) return 0.0;
    if (dominant != good.species.species) return 0.02; // trace — xenobiologists
    return _distanceFalloff(dist, radius: _speciesDemandCoreRadius, sharpness: 3.0);
  }

  // speciesCore: strong at home, thin curiosity demand elsewhere via alienDriver
  double _speciesCoreMod(SpecialGood good, Species? dominant, int dist) {
    if (dominant == null) return 0.0;
    if (dominant == good.species.species) {
      return _distanceFalloff(dist, radius: _speciesDemandCoreRadius, sharpness: 2.0);
    }
    // Alien curiosity demand — thin but real, driven by alienDriver
    final alienBase = _alienDriverMod(dominant, good.archetype.alienDriver);
    return alienBase * _distanceFalloff(dist, radius: galaxy.maxJumps, sharpness: 0.5);
  }

  // political: follows federation authority kernel regardless of species
  double _politicalMod(System system) {
    return galaxy.fedKernel.val(system).clamp(0.1, 1.0);
  }

  // crossCultural: moderate everywhere, distance-weighted
  double _crossCulturalMod(Species? dominant, SpecialGood good, int dist) {
    final base = dominant == good.species.species ? 1.0 : 0.5;
    return base * _distanceFalloff(dist, radius: galaxy.maxJumps ~/ 2, sharpness: 1.0);
  }

  // Alien driver — what makes a non-producing species want a good at all
  double _alienDriverMod(Species dominant, AlienDemandDriver? driver) {
    if (driver == null) return 0.0;
    return switch (driver) {
      AlienDemandDriver.xenomancyAndWealth => dominant.xenomancy * 0.7 + dominant.commerce * 0.3,
      AlienDemandDriver.militancy          => dominant.militancy,
      AlienDemandDriver.commerce           => dominant.commerce,
      AlienDemandDriver.tech               => dominant.tech,
      AlienDemandDriver.population         => dominant.populationDensity,
    };
  }

  // Political relationship between planet's dominant species and good's species
  // High mutual respect → more cultural exchange → more demand
  double _politicalRelationshipMod(Species? dominant, SpecialGood good) {
    if (dominant == null) return 1.0;
    if (dominant == good.species.species) return 1.0; // own species, no political discount
    final attitude = galaxy.civMod.politicalMap[dominant]?[good.species.species] ?? 0.5;
    // Map 0–1 attitude to 0.2–1.2 modifier — hostile species still trade a little
    return 0.2 + attitude;
  }

  // ── Universal commodity demand ────────────────────────────────────────────
  double universalDemandFor(UniversalCommodity commodity, Planet planet) {
    return commodity.demandFor(
      tech:       planet.techLvl,
      population: planet.population,
      industry:   planet.industry,
      commerce:   planet.commerce,
      militancy:  galaxy.civMod.dominantSpecies(planet.locale.system)?.militancy ?? 0.5,
      xenomancy:  galaxy.civMod.dominantSpecies(planet.locale.system)?.xenomancy ?? 0.5,
      wealth:     planet.wealth,
      fedLevel:   planet.fedLvl,
    );
  }

  // Price of a universal at a planet — thin band, distance-modulated
  int universalPriceAt(UniversalCommodity commodity, Planet planet) {
    final hasSupply  = planetSupply[planet]?.contains(commodity) ?? false;
    final nearestDist = nearestSourceDist(commodity, planet);
    return commodity.priceAt(hasLocalSupply: hasSupply, distFromSource: nearestDist);
  }

  // ── Shop stock helpers ────────────────────────────────────────────────────

  // Species goods available at a planet — those produced nearby with
  // meaningful demand at this planet. Used by shop stock generation.
  List<SpecialGood> availableSpeciesGoods(Planet planet) {
    final result = <SpecialGood>[];
    for (final goods in speciesGoods.values) {
      for (final good in goods) {
        // Good is available if this planet is a source OR a nearby planet is
        final sources = goodsSources[good] ?? [];
        final isSource = sources.contains(planet);
        final nearbySource = sources.any((src) =>
        galaxy.topo.distance(src.locale.system, planet.locale.system) <= 3);
        if (isSource || nearbySource) {
          result.add(good);
        }
      }
    }
    return result;
  }

  // Demand list for a planet — all goods with meaningful demand here,
  // sorted by intensity descending. Used to decide what a planet will buy.
  List<(SpecialGood, double)> demandListFor(Planet planet, {double threshold = 0.1}) {
    final all = speciesGoods.values.expand((g) => g).toList();
    final result = <(SpecialGood, double)>[];
    for (final good in all) {
      final d = demandFor(good, planet);
      if (d >= threshold) result.add((good, d));
    }
    result.sort((a, b) => b.$2.compareTo(a.$2));
    return result;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // Exponential distance falloff, normalized to 1.0 at dist=0
  // sharpness: higher = steeper drop (3.0 = speciesOnly, 0.5 = crossCultural)
  double _distanceFalloff(int dist, {required int radius, required double sharpness}) {
    if (radius == 0) return 0.0;
    return exp(-sharpness * dist / radius).clamp(0.0, 1.0);
  }

  List<Planet> nearbyPlanets(System origin, int maxDist) {
    final result = <Planet>[];
    for (final system in systems) {
      final d = galaxy.topo.distance(origin, system);
      if (d <= maxDist) result.addAll(system.planets);
    }
    return result;
  }

  Species? dominantSpeciesAt(Planet p) =>
      galaxy.civMod.dominantSpecies(p.locale.system);

  StockSpecies? dominantStockSpeciesAt(Planet p) {
    final sp = dominantSpeciesAt(p);
    if (sp == null) return null;
    try {
      return StockSpecies.values.firstWhere((s) => s.species == sp);
    } catch (_) {
      return null;
    }
  }

  int nearestSourceDist(UniversalCommodity commodity, Planet planet) {
    int nearest = galaxy.maxJumps;
    for (final entry in planetSupply.entries) {
      if (entry.value.contains(commodity)) {
        final d = galaxy.topo.distance(
            entry.key.locale.system, planet.locale.system);
        if (d < nearest) nearest = d;
      }
    }
    return nearest;
  }

  Planet _weightedPickPlanet(Map<Planet, double> weights, Random rnd) {
    final total = weights.values.fold(0.0, (a, b) => a + b);
    double cursor = rnd.nextDouble() * total;
    for (final entry in weights.entries) {
      cursor -= entry.value;
      if (cursor <= 0) return entry.key;
    }
    return weights.keys.last;
  }

  // Proxy for species "weirdness" — no direct field, derived from xenomancy
  // and flexibility. Vorlons and highly xenomantic species get weirder goods.
  double _speciesWeirdness(StockSpecies s) =>
      (s.species.xenomancy * 0.7 + s.species.flexibility * 0.3).clamp(0.0, 1.0);

  // ── Debug ─────────────────────────────────────────────────────────────────
  void _debugDump() {
    glog('═' * 60);
    glog('TRADE MODEL — species goods');
    glog('═' * 60);
    for (final entry in speciesGoods.entries) {
      glog('${entry.key.species.name}:');
      for (final good in entry.value) {
        final sources = goodsSources[good]?.map((p) => p.name).join(', ') ?? '—';
        final tag = good.isHandcrafted ? 'crafted' : 'random';
        glog('  [$tag] ${good.name} (${good.archetype.reach.name}) '
            '— sources: $sources');
      }
    }
    glog('═' * 60);
    glog('TRADE MODEL — universal supply (sample: first 5 systems)');
    glog('═' * 60);
    for (final system in systems.take(5)) {
      for (final planet in system.planets) {
        final supply = planetSupply[planet];
        if (supply != null && supply.isNotEmpty) {
          glog('  ${planet.name}: ${supply.map((c) => c.name).join(', ')}');
        }
      }
    }
    glog('═' * 60);
  }
}
