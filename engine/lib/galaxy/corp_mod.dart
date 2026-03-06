import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/galaxy/sub_model.dart';
import 'package:crawlspace_engine/galaxy/system.dart';
import '../rng/rng.dart';
import '../stock_items/corps.dart';
import '../stock_items/species.dart';
import '../systems/ship_system.dart';
import 'corp_kern.dart';

class CorpMod extends GalaxySubMod {
  final Map<Corporation, CorpKernelField> kernels = {};
  final Map<Species,Map<Corporation,System>> headquarters = {};

  CorpMod(super.galaxy) {
    for (final species in galaxy.allSpecies) {
      final speciesCorps = Corporation.values
          .where((c) => c.stockSpecies.species == species)
          .toList();
      if (speciesCorps.isEmpty) continue;

      // find the "anchor" corp — first one, seeded to homeworld
      final anchor = speciesCorps.first;
      final homeSystem = galaxy.findHomeworld(species);

      headquarters[species] = {anchor: homeSystem};

      // spread remaining corps across systems dominated by this species
      final speciesSystems = galaxy.systems
          .where((s) => galaxy.civMod.dominantSpecies(s) == species)
          .toList();

      galaxy.spreadAssign(speciesCorps, headquarters[species]!, speciesSystems);
    }
    _initKernels();
  }

  System? getHQSystem(Corporation c) => headquarters[c.stockSpecies.species]?[c];
  Corporation? getHQ(System sys) => headquarters.values.expand((v) => v.entries.where((s) => s.value == sys)).firstOrNull?.key;

  void _initKernels() {
    for (final corp in Corporation.values) {
      // spread tuned by corp character:
      // specialists (gregoriev, tanaka) = tight kernel
      // universals (smythe, genCorp) = wide kernel
      kernels[corp] = CorpKernelField(
        galaxy, corp,
        kernel: (d) => exp(-d / corp.spread),
      );
      final home = getHQSystem(corp);
      if (home != null) {
        kernels[corp]!.recompute({home: 1.0});
      }
    }
  }

  // ── Influence ─────────────────────────────────────────────────────────────

  double influence(Corporation corp, System system) =>
      kernels[corp]!.val(system);

  Corporation? dominantCorp(System system) =>
      Corporation.values
          .sorted((a, b) => influence(b, system)
          .compareTo(influence(a, system)))
          .firstOrNull;

  List<(Corporation, double)> influenceList(System system) =>
      Corporation.values
          .map((c) => (c, influence(c, system)))
          .sorted((a, b) => b.$2.compareTo(a.$2))
          .toList();

  double effectiveInfluence(Corporation corp, System system) {
    final base = influence(corp, system);
    final dominant = galaxy.civMod.dominantSpecies(system);
    final speciesRel = dominant != null
        ? corp.speciesRelations[dominant] ?? 0.0
        : 0.0;
    return (base * (1.0 + speciesRel * 0.3)).clamp(0.0, 1.0);
  }

  // ── Compatibility ─────────────────────────────────────────────────────────

  BrandSupport slotCompatibility(ShipSystem system, SystemSlot slot) {
    if (system.type != slot.systemType) return BrandSupport.needsAdapter;
    if (system.manufacturer == slot.manufacturer) return BrandSupport.native;
    return brandSupport(system.manufacturer, slot.manufacturer);
  }

  BrandSupport brandSupport(Corporation a, Corporation b) {
    if (a == b) return BrandSupport.native;
    final aSupportsB = a.getRelations(b);
    final bSupportsA = b.getRelations(a);
    return _better(aSupportsB, bSupportsA);
  }

  BrandSupport _better(BrandSupport a, BrandSupport b) {
    return a.index < b.index ? a : b;
  }

  // ── Stock generation ──────────────────────────────────────────────────────

  List<Corporation> activeCorporations(System system, {double threshold = 0.1}) =>
      Corporation.values
          .where((c) => effectiveInfluence(c, system) >= threshold)
          .sorted((a, b) => effectiveInfluence(b, system)
          .compareTo(effectiveInfluence(a, system)))
          .toList();

  Corporation? corpForCategory(ShipSystemType type, System system, Random rnd) {
    final candidates = activeCorporations(system)
        .where((c) => c.makes(type))
        .toList();
    if (candidates.isEmpty) return null;

    final weights = Map.fromEntries(
        candidates.map((c) => MapEntry(c, effectiveInfluence(c, system)))
    );

    return Rng.weightedRandom(weights, rnd);
  }

  bool militaryAvailable(System system) => galaxy.fedKernel.val(system) > 0.7;

  // ── GalaxyMapLegend support ───────────────────────────────────────────────

  Map<System, double> normalizedInfluence(Corporation corp) {
    final vals = { for (final s in galaxy.systems) s: influence(corp, s) };
    final maxInfluence = vals.values.reduce(max);
    if (maxInfluence <= 0) return vals;
    return { for (final e in vals.entries) e.key: e.value / maxInfluence };
  }
}
