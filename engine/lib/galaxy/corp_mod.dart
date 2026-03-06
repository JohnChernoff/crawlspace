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

  CorpMod(super.galaxy) {
    _initKernels();
  }

  void _initKernels() {
    for (final corp in Corporation.values) {
      // spread tuned by corp character:
      // specialists (gregoriev, tanaka) = tight kernel
      // universals (smythe, genCorp) = wide kernel
      final spread = _spreadFor(corp);
      kernels[corp] = CorpKernelField(
        galaxy, corp,
        kernel: (d) => exp(-d / spread),
      );
      final home = _homeSystem(corp);
      if (home != null) {
        kernels[corp]!.recompute({home: 1.0});
      }
    }
  }

  double _spreadFor(Corporation corp) => switch(corp) {
    Corporation.genCorp  => 12.0,  // ubiquitous
    Corporation.smythe   => 10.0,  // wide market
    Corporation.nimrod   => 8.0,   // broad but not universal
    Corporation.sinclair => 7.0,
    Corporation.bauchmann => 7.0,
    Corporation.lopez    => 6.0,
    Corporation.salazar  => 6.0,
    Corporation.rimbaud  => 5.0,
    Corporation.tanaka   => 3.0,   // niche specialist
    Corporation.gregoriev => 3.0,  // niche specialist
  };

  // tie corp homeworlds to species homeworlds or fed systems
  // adjust to taste
  System? _homeSystem(Corporation corp) => switch(corp) {
    Corporation.genCorp   => galaxy.fedHomeSystem,
    Corporation.smythe    => galaxy.fed1,
    Corporation.sinclair  => galaxy.fed2,
    Corporation.bauchmann => galaxy.fed3,
    Corporation.rimbaud   => galaxy.findHomeworld(StockSpecies.humanoid.species),
    Corporation.salazar   => galaxy.findHomeworld(StockSpecies.krakkar.species),
    Corporation.nimrod    => galaxy.findHomeworld(StockSpecies.vorlon.species),
    Corporation.lopez     => galaxy.findHomeworld(StockSpecies.gersh.species),
    Corporation.tanaka    => galaxy.findHomeworld(StockSpecies.lael.species),
    Corporation.gregoriev => galaxy.findHomeworld(StockSpecies.orblix.species),
  };

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
    final aSupportsB = a.brandRelations[b];
    final bSupportsA = b.brandRelations[a];
    return _better(aSupportsB, bSupportsA) ?? BrandSupport.needsAdapter;
  }

  BrandSupport? _better(BrandSupport? a, BrandSupport? b) {
    if (a == null) return b;
    if (b == null) return a;
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

  bool militaryAvailable(System system) =>
      galaxy.fedKernel.val(system) > 0.6 ||
          galaxy.fedKernel.val(system) > 0.7;

  // ── GalaxyMapLegend support ───────────────────────────────────────────────

  Map<System, double> normalizedInfluence(Corporation corp) {
    final vals = { for (final s in galaxy.systems) s: influence(corp, s) };
    final maxInfluence = vals.values.reduce(max);
    if (maxInfluence <= 0) return vals;
    return { for (final e in vals.entries) e.key: e.value / maxInfluence };
  }
}
