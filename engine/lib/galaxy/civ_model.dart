import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/galaxy/sub_model.dart';
import '../color.dart';
import '../foosham/throws.dart';
import '../rng/rng.dart';
import '../stock_items/species.dart';
import 'system.dart';

enum PoliticsMode {
  traditional,flux,reckoning
}

class CivModel extends GalaxySubMod {
  static const int minPositiveRelationships = 2; // minimum species each race respects (≥ 0.5)
  List<Species> get allSpecies => galaxy.allSpecies;
  final Map<Species,System> homeworlds = {};
  final Map<System, Map<Species,double>> civIntensity = {};
  final Map<System,double> techField = {};
  final Map<System,double> commerceField = {};
  Map<Species, Species> rivalries = {}; // store as field
  // Stored — the ground truth
  Map<Faction, Map<Species, double>> factionAttitudes = {};
  Map<Species, Map<Species, double>>? _cachedPoliticalMap;


  Map<Species, Map<Species, double>> get politicalMap {
    return _cachedPoliticalMap ??= _computePoliticalMap();
  }

  Map<Species, Map<Species, double>> _computePoliticalMap() {
    final map = <Species, Map<Species, double>>{};
    for (final a in allSpecies) {
      map[a] = {};
      for (final b in allSpecies) {
        if (a == b) {
          map[a]![b] = 1.0;
          continue;
        }
        final aFactions = factions.where((f) => f.species == a).toList();
        if (aFactions.isEmpty) {
          map[a]![b] = 0.5;
          continue;
        }
        final totalStrength = aFactions.fold(0.0, (sum, f) => sum + f.strength);
        double weightedSum = 0.0;
        for (final faction in aFactions) {
          final attitude = factionAttitudes[faction]?[b] ?? 0.5;
          weightedSum += attitude * (faction.strength / totalStrength);
        }
        map[a]![b] = weightedSum.clamp(0.0, 1.0);
      }
    }
    return map;
  }

  void _invalidatePoliticalMap() => _cachedPoliticalMap = null;

  CivModel(super.galaxy) {
    homeworlds[StockSpecies.humanoid.species] = galaxy.fedHomeSystem;
    galaxy.spreadAssign(allSpecies, homeworlds, galaxy.systems);
    computeCivFields();
  }

  void computeCivFields() {
    for (final s in systems) {
      civIntensity[s] = {};
      for (final sp in allSpecies) {
        final d = distance(homeworlds[sp]!, s);
        civIntensity[s]![sp] = exp(-d / (sp.propagation * 10)) * sp.populationDensity;
      }
      civIntensity[s] = normalize(civIntensity[s]!);
    }
  }

  Species? dominantSpecies(System s) {
    return civIntensity[s]?.entries.sorted((a,b) => a.value.compareTo(b.value)).last.key;
  }

  Species? cantinaCulture(System system, Random rnd) {
    final intensities = civIntensity[system];
    if (intensities == null || intensities.isEmpty) return null;
    return Rng.weightedRandom(
      intensities.map((k, v) => MapEntry(k, v)),
      rnd,
    );
  }

  GameColor systemSpeciesColor(System s) {
      final mix = civIntensity[s];
      if (mix == null || mix.isEmpty) return GameColors.black;

      double r = 0, g = 0, b = 0;
      for (final e in mix.entries) {
        final col = e.key.graphCol;
        final w = e.value;
        r += col.r * w;
        g += col.g * w;
        b += col.b * w;
      }

      // diversity metric (Shannon-ish)
      double diversity = 0;
      for (final w in mix.values) {
        if (w > 0) diversity -= w * log(w);
      }
      diversity = diversity.clamp(0, 2.0);

      // boost saturation
      final boost = 1 + diversity * 0.3;

      r = ((r - 128) * boost + 128).clamp(0, 255);
      g = ((g - 128) * boost + 128).clamp(0, 255);
      b = ((b - 128) * boost + 128).clamp(0, 255);

      return GameColor.fromRgb(r.round(), g.round(), b.round());
  }

  void generatePolitics(Random rnd, {PoliticsMode mode = PoliticsMode.flux}) {
    factionAttitudes = {};
    _invalidatePoliticalMap();

    // Pass 1 — dominant faction sets species baseline, others copy it
    for (final a in allSpecies) {
      final aFactions = factions.where((f) => f.species == a).toList();
      if (aFactions.isEmpty) continue;

      final dominant = aFactions.reduce((x, y) => x.strength > y.strength ? x : y);

      // Generate baseline from dominant faction's perspective
      for (final b in allSpecies) {
        if (b == a) continue;
        factionAttitudes[dominant] ??= {};
        factionAttitudes[dominant]![b] = _generateInfluence(a, b, rnd, mode: mode);
      }

      // Other factions start from dominant's baseline
      for (final faction in aFactions) {
        if (faction == dominant) continue;
        factionAttitudes[faction] = Map.of(factionAttitudes[dominant]!);
      }
    }

    // Pass 2 — minority factions diverge based on militancy and dominance
    for (final a in allSpecies) {
      final aFactions = factions.where((f) => f.species == a).toList();
      if (aFactions.isEmpty) continue;

      final totalStrength = aFactions.fold(0.0, (sum, f) => sum + f.strength);
      final dominant = aFactions.reduce((x, y) => x.strength > y.strength ? x : y);

      for (final faction in aFactions) {
        if (faction == dominant) continue; // dominant doesn't diverge
        final dominance = faction.strength / totalStrength;
        // Minority + high militancy = large divergence
        final divergenceScale = (faction.militancy * (1.0 - dominance)).clamp(0.0, 1.0);

        for (final b in allSpecies) {
          if (b == a) continue;

          // Fixed attitudes override random divergence — core faction identity
          if (faction.fixedAttitudes.containsKey(b)) {
            factionAttitudes[faction]![b] = faction.fixedAttitudes[b]!;
            continue;
          }

          final baseline = factionAttitudes[faction]![b]!;
          final divergence = (rnd.nextDouble() * 2 - 1) * divergenceScale * 0.4;
          factionAttitudes[faction]![b] = (baseline + divergence).clamp(0.0, 1.0);
        }
      }
    }

    // Structural guarantees — operate on factionAttitudes via helper
    _ensureFriendship(rnd);
    _ensureMinimumRespect(rnd);
    rivalries = _generateRivalries(allSpecies, rnd);
    _applyRivalryConstraints(rivalries, rnd);
  }

// Sets attitude for all factions of species a toward species b
  void _setSpeciesAttitude(Species a, Species b, double v) {
    for (final faction in factions.where((f) => f.species == a)) {
      // Don't override fixed attitudes — they're core faction identity
      if (!faction.fixedAttitudes.containsKey(b)) {
        factionAttitudes[faction]?[b] = v;
      }
    }
    _invalidatePoliticalMap();
  }

// Reads weighted average attitude of species a toward species b
  double _getSpeciesAttitude(Species a, Species b) {
    final aFactions = factions.where((f) => f.species == a).toList();
    if (aFactions.isEmpty) return 0.5;
    final totalStrength = aFactions.fold(0.0, (sum, f) => sum + f.strength);
    if (totalStrength == 0) return 0.5;
    double weightedSum = 0.0;
    for (final faction in aFactions) {
      weightedSum += (factionAttitudes[faction]?[b] ?? 0.5) * (faction.strength / totalStrength);
    }
    return weightedSum.clamp(0.0, 1.0);
  }

  void _ensureFriendship(Random rnd) {
    final pairs = <List<Species>>[];
    for (int i = 0; i < allSpecies.length; i++) {
      for (int j = i + 1; j < allSpecies.length; j++) {
        pairs.add([allSpecies[i], allSpecies[j]]);
      }
    }
    pairs.shuffle(rnd);
    for (int i = 0; i < 2; i++) {
      final pair = pairs[i];
      final v = 0.75 + rnd.nextDouble() * 0.2;
      _setSpeciesAttitude(pair[0], pair[1], v);
      _setSpeciesAttitude(pair[1], pair[0], v);
    }
  }

  void _ensureMinimumRespect(Random rnd) {
    for (final a in allSpecies) {
      final others = allSpecies.where((b) => b != a).toList()..shuffle(rnd);
      int respectCount = others.where((b) => _getSpeciesAttitude(a, b) >= 0.5).length;
      for (final b in others) {
        if (respectCount >= minPositiveRelationships) break;
        if (_getSpeciesAttitude(a, b) < 0.5) {
          final v = 0.5 + rnd.nextDouble() * 0.4;
          _setSpeciesAttitude(a, b, v);
          respectCount++;
        }
      }
    }
  }

  void _applyRivalryConstraints(Map<Species, Species> rivalries, Random rnd) {
    for (final entry in rivalries.entries) {
      final hater = entry.key;
      final hated = entry.value;
      final current = _getSpeciesAttitude(hater, hated);
      _setSpeciesAttitude(hater, hated, min(current, 0.25));
      // Note: _setSpeciesAttitude already skips fixed attitudes
      if (_getSpeciesAttitude(hated, hater) >= 0.5) {
        _setSpeciesAttitude(hated, hater, 0.25 + rnd.nextDouble() * 0.24);
      }
    }
  }

  void degradePolitics(Random rnd, {double intensity = 0.05}) {
    for (final faction in factions) {
      for (final b in allSpecies) {
        if (b == faction.species) continue;
        final current = factionAttitudes[faction]?[b] ?? 0.5;
        final drift = intensity * (0.5 + rnd.nextDouble() * 0.5);
        factionAttitudes[faction]?[b] = (current - drift).clamp(0.0, 1.0);
      }
    }
    _invalidatePoliticalMap();
  }

  double _generateInfluence(Species a, Species b, Random rnd, {required PoliticsMode mode}) {
    switch (mode) {
      case PoliticsMode.traditional:
      // Tightly clustered around species-derived mean — learnable across runs
        final mean = _baseMean(a, b);
        final strength = 8.0; // high strength = low variance = consistent across runs
        return Rng.betaRnd(rnd, mean, strength).clamp(0.0, 1.0);

      case PoliticsMode.flux:
      // Looser — random within a species-flavored envelope of variance
        final variance = 2.0 + (a.flexibility + b.flexibility) * 2.0;
        return Rng.betaRnd(rnd, 0.5, variance).clamp(0.0, 1.0);

      case PoliticsMode.reckoning:
      // Start like flux but caller should degrade over time via degradePolitics()
        final mean = _baseMean(a, b);
        final strength = 3.0;
        return Rng.betaRnd(rnd, mean, strength).clamp(0.0, 1.0);
    }
  }

// Derives a baseline relationship mean from species traits
// Commerce similarity → trade partners → friendly
// Courage disparity → one bullies the other → hostile
// Xenomancy similarity → mystical affinity → friendly
  double _baseMean(Species a, Species b) {
    final commerceAffinity  = 1.0 - (a.commerce   - b.commerce).abs();
    final courageDisparity  = (a.courage    - b.courage).abs();
    final xenoAffinity      = 1.0 - (a.xenomancy  - b.xenomancy).abs();

    return ((commerceAffinity + xenoAffinity) / 2.0 - courageDisparity * 0.3)
        .clamp(0.1, 0.9); // never fully certain in either direction
  }

  Map<Species, Species> _generateRivalries(List<Species> species, Random rnd) {
    late List<Species> shuffled;
    do {
      shuffled = [...species]..shuffle(rnd);
    } while (
    Iterable.generate(species.length).any((i) => shuffled[i] == species[i])
    );
    return { for (int i = 0; i < species.length; i++) species[i]: shuffled[i] };
  }

  // Returns true if an anomaly exists between two species in a given system —
  // i.e. the FooSham table doesn't match what the political map predicts
  // Used to surface insurgency/intelligence opportunities to the player
  bool detectAnomaly(System system, Species a, Species b, Map<String,Set<String>> observedBeatMap) {
    final expectedInfluence = localInfluence(system, a, b);
    final avatarA = speciesThrows.entries.firstWhereOrNull((e) => e.value.species == a)?.key;
    final avatarB = speciesThrows.entries.firstWhereOrNull((e) => e.value.species == b)?.key;
    if (avatarA == null || avatarB == null) return false;

    // Expected: high influence = b beats a (honor), low influence = a beats b (hostility)
    final expectedABeatsB = expectedInfluence < 0.5;
    final observedABeatsB = observedBeatMap[avatarA]?.contains(avatarB) ?? false;

    // Anomaly if observed beat direction contradicts political expectation
    return expectedABeatsB != observedABeatsB;
  }

  void debugPrintPoliticalMap() {
    final species = politicalMap.keys.toList();

    // Header row
    final colWidth = 12;
    final nameWidth = 22;
    final header = ''.padRight(nameWidth) +
        species.map((s) => s.name.substring(0, min(colWidth-1, s.name.length))
            .padRight(colWidth)).join();

    print('═' * header.length);
    print('POLITICAL MAP');
    print('═' * header.length);
    print(header);
    print('─' * header.length);

    for (final a in species) {
      final row = StringBuffer();
      row.write(a.name.substring(0, min(nameWidth-1, a.name.length)).padRight(nameWidth));

      for (final b in species) {
        if (a == b) {
          row.write('——'.padRight(colWidth));
        } else {
          final v = politicalMap[a]?[b];
          if (v == null) {
            row.write('?'.padRight(colWidth));
          } else {
            // Label with emoji for quick visual scanning
            final label = switch(v) {
              > 0.75 => '★ ${v.toStringAsFixed(2)}', // strong ally
              > 0.55 => '◎ ${v.toStringAsFixed(2)}', // friendly
              > 0.45 => '· ${v.toStringAsFixed(2)}', // neutral
              > 0.25 => '△ ${v.toStringAsFixed(2)}', // tense
              _      => '✕ ${v.toStringAsFixed(2)}', // hostile
            };
            row.write(label.padRight(colWidth));
          }
        }
      }
      print(row.toString());
    }
    print('═' * header.length);
    print('★ ally  ◎ friendly  · neutral  △ tense  ✕ hostile');
    print('═' * header.length);
  }

  double localInfluence(System system, Species a, Species b) {
    final baseline = politicalMap[a]?[b] ?? 0.5;
    final intensities = civIntensity[system];
    if (intensities == null) return baseline;

    final intensityA = intensities[a] ?? 0.0;
    final intensityB = intensities[b] ?? 0.0;
    final dominant = intensityA >= intensityB ? a : b;

    // Normalize dominance relative to max intensity in system
    // so deep single-species space feels strongly cultural
    final maxIntensity = intensities.values.reduce(max);
    final dominantIntensity = maxIntensity > 0
        ? (intensities[dominant]! / maxIntensity).clamp(0.0, 1.0)
        : 0.0;

    final localBias = politicalMap[dominant]?[dominant == a ? b : a] ?? 0.5;
    return _lerp(baseline, localBias, dominantIntensity).clamp(0.0, 1.0);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void debugPrintRivalries() {
    print('═' * 40);
    print('RIVALRIES');
    print('═' * 40);
    for (final e in rivalries.entries) {
      print('${e.key.name.padRight(20)} → ${e.value.name}');
    }
    print('═' * 40);
  }

}

//civIntensity[system][species] += civKernelInfluence * migrationRate;