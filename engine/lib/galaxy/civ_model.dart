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
  Map<Species,Map<Species,double>> politicalMap = {}; // 0 hostile to 1.0 friendly
  Map<System, Map<Species,double>> civIntensity = {};
  Map<System,double> techField = {};
  Map<System,double> commerceField = {};

  CivModel(super.galaxy) {
    computeCivFields();
  }

  void computeCivFields() {
    for (final s in systems) {
      civIntensity[s] = {};
      for (final sp in allSpecies) {
        final d = distance(galaxy.findHomeworld(sp), s);
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
    politicalMap = {};

    // Initialize empty maps for each species
    for (final sp in allSpecies) {
      politicalMap[sp] = {};
      politicalMap[sp]![sp] = 1.0; // every species respects itself
    }

    for (int i = 0; i < allSpecies.length; i++) {
      for (int j = i + 1; j < allSpecies.length; j++) {
        final a = allSpecies[i];
        final b = allSpecies[j];

        final influence = _generateInfluence(a, b, rnd, mode: mode);

        politicalMap[a]![b] = influence;
        politicalMap[b]![a] = influence; // symmetric to start — could diverge later
      }
    }

    // Ensure at least a few strong relationships in each direction
    // so the galaxy doesn't feel blandly neutral
    _ensureDrama(rnd);
    _ensureMinimumRespect(rnd);
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

// Guarantees the galaxy has at least 2 strong alliances and 2 strong rivalries
// Prevents everything clustering around 0.5
  void _ensureDrama(Random rnd) {
    final pairs = <List<Species>>[];
    for (int i = 0; i < allSpecies.length; i++) {
      for (int j = i + 1; j < allSpecies.length; j++) {
        pairs.add([allSpecies[i], allSpecies[j]]);
      }
    }
    pairs.shuffle(rnd);

    // Force 2 strong friendships (0.75–0.95)
    for (int i = 0; i < 2; i++) {
      final pair = pairs[i];
      final v = 0.75 + rnd.nextDouble() * 0.2;
      politicalMap[pair[0]]![pair[1]] = v;
      politicalMap[pair[1]]![pair[0]] = v;
    }

    // Force 2 strong rivalries (0.05–0.25)
    for (int i = 2; i < 4; i++) {
      final pair = pairs[i];
      final v = 0.05 + rnd.nextDouble() * 0.2;
      politicalMap[pair[0]]![pair[1]] = v;
      politicalMap[pair[1]]![pair[0]] = v;
    }
  }

  void _ensureMinimumRespect(Random rnd) {
    for (final a in allSpecies) {
      final others = allSpecies.where((b) => b != a).toList()..shuffle(rnd);
      int respectCount = politicalMap[a]!
          .entries
          .where((e) => e.key != a && e.value >= 0.5)
          .length;
      for (final b in others) {
        if (respectCount >= minPositiveRelationships) break;
        if ((politicalMap[a]?[b] ?? 0) < 0.5) {
          final v = 0.5 + rnd.nextDouble() * 0.4;
          politicalMap[a]![b] = v;
          politicalMap[b]![a] = v;
          respectCount++;
        }
      }
    }
  }

// Called periodically during Reckoning mode as the entity's influence grows
// Gradually pushes all relationships toward hostility
  void degradePolitics(Random rnd, {double intensity = 0.05}) {
    for (final a in allSpecies) {
      for (final b in allSpecies) {
        if (a == b) continue;
        final current = politicalMap[a]![b]!;
        // Drift toward hostility, with some noise
        final drift = intensity * (0.5 + rnd.nextDouble() * 0.5);
        politicalMap[a]![b] = (current - drift).clamp(0.0, 1.0);
      }
    }
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

}

//civIntensity[system][species] += civKernelInfluence * migrationRate;