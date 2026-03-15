import 'dart:math' as math;
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/systems/weapons.dart';

class RangeProfileOptions {
  final bool readyOnly;            // current volley vs all active weapons
  final bool weightByFireRate;     // sustained dpt vs raw per-shot
  final bool requireAmmo;          // ignore empty launchers?
  final bool requireEnergy;        // ignore weapons ship can't currently support?
  final bool includeCrits;
  final bool includeCooldownBias;  // partially weight near-ready weapons
  final double optimalThreshold;   // e.g. 0.85
  final double usableThreshold;    // e.g. 0.60
  final double minHitChance;       // floor to avoid absolute deadness inside range
  final double maxHitChance;

  const RangeProfileOptions({
    this.readyOnly = false,
    this.weightByFireRate = true,
    this.requireAmmo = true,
    this.requireEnergy = false,
    this.includeCrits = true,
    this.includeCooldownBias = false,
    this.optimalThreshold = 0.85,
    this.usableThreshold = 0.60,
    this.minHitChance = 0.05,
    this.maxHitChance = 0.95,
  });

  double weaponScoreAtRange(Weapon w, double dist) {
    final hitChance = (w.baseAccuracy * w.accuracyRangeConfig.rangeMultiplier(dist))
        .clamp(minHitChance, maxHitChance);

    final avgRawDamage = _avgRawDamage(w);
    final rangeDamage = avgRawDamage * w.dmgRangeConfig.rangeMultiplier(dist);

    double critMultiplier = 1.0;
    if (includeCrits && w.critConfig.baseChance > 0) {
      // Simple expectation model; ignores accuracyScaling for now.
      critMultiplier += w.critConfig.baseChance * (w.critConfig.severity - 1.0);
    }

    double score = rangeDamage * hitChance * critMultiplier;

    if (weightByFireRate) {
      score /= math.max(1, w.fireRate);
    }

    if (includeCooldownBias && w.cooldown > 0) {
      score *= 1.0 / (w.cooldown + 1.0);
    }

    return score;
  }

  double _avgRawDamage(Weapon w) {
    final diceAvg = w.dmgDice * (w.dmgDiceSides + 1) / 2.0;
    return w.ammo == null
        ? w.dmgBase + diceAvg * w.dmgMult
        : (w.dmgBase + w.ammo!.expectedDamage) * w.dmgMult;
  }
}

//enum RangeProfileMode { sustained, volley }

class ShipRangeBand {
  final int start;
  final int end;

  const ShipRangeBand(this.start, this.end);

  bool get isPoint => start == end;

  @override
  String toString() => isPoint ? '$start' : '$start-$end';
}

class ShipRangeProfile {
  final List<double> scoreByRange;
  final int peakRange;
  final double peakScore;
  final ShipRangeBand? optimalBand;
  final ShipRangeBand? usableBand;

  const ShipRangeProfile({
    required this.scoreByRange,
    required this.peakRange,
    required this.peakScore,
    required this.optimalBand,
    required this.usableBand,
  });

  double scoreAt(int range) {
    if (range < 0 || range >= scoreByRange.length) return 0.0;
    return scoreByRange[range];
  }

  double efficiencyAt(int range) {
    if (peakScore <= 0) return 0.0;
    return scoreAt(range) / peakScore;
  }

  String summary() {
    final opt = optimalBand == null ? "-" : optimalBand.toString();
    final use = usableBand == null ? "-" : usableBand.toString();
    return "Rng opt $opt | use $use | peak $peakRange";
  }
}

class ShipRangeProfiler {
  final RangeProfileOptions options;

  const ShipRangeProfiler([this.options = const RangeProfileOptions()]);

  ShipRangeProfile build(
      Ship ship, {
        int maxRange = 12,
      }) {
    final weapons = _eligibleWeapons(ship).toList();

    if (weapons.isEmpty) {
      return ShipRangeProfile(
        scoreByRange: List.filled(maxRange + 1, 0.0),
        peakRange: 0,
        peakScore: 0.0,
        optimalBand: null,
        usableBand: null,
      );
    }

    final scores = List<double>.filled(maxRange + 1, 0.0);

    for (int dist = 0; dist <= maxRange; dist++) {
      double total = 0.0;
      for (final w in weapons) {
        total += options.weaponScoreAtRange(w, dist.toDouble());
      }
      scores[dist] = total;
    }

    final peakScore = scores.reduce(math.max);
    final peakRange = scores.indexOf(peakScore);

    return ShipRangeProfile(
      scoreByRange: scores,
      peakRange: peakRange,
      peakScore: peakScore,
      optimalBand: _findPeakCenteredBand(
        scores,
        peakScore * options.optimalThreshold,
        peakRange,
      ),
      usableBand: _findBestBand(
        scores,
        peakScore * options.usableThreshold,
      ),
    );
  }

  Iterable<Weapon> _eligibleWeapons(Ship ship) {
    final weapons = options.readyOnly
        ? ship.systemControl.readyWeapons
        : ship.systemControl.availableWeapons;

    return weapons.where((w) {
      if (options.requireAmmo && w.usesAmmo) {
        if (w.ammo == null) return false;
        if (!ship.systemControl.ammoOK(w)) return false;
      }

      if (options.requireEnergy) {
        // Approximate: require enough current ship energy for one firing round.
        if (ship.systemControl.getCurrentEnergy() < w.energyRate) return false;
      }

      return true;
    });
  }

  ShipRangeBand? _findBestBand(List<double> scores, double threshold) {
    if (scores.isEmpty) return null;
    if (threshold <= 0) {
      final nonZero = scores.indexWhere((s) => s > 0);
      if (nonZero < 0) return null;
    }

    int? bestStart;
    int? bestEnd;
    int? curStart;

    for (int i = 0; i < scores.length; i++) {
      final inBand = scores[i] >= threshold && scores[i] > 0;
      if (inBand) {
        curStart ??= i;
      } else if (curStart != null) {
        final curEnd = i - 1;
        if (bestStart == null || (curEnd - curStart) > (bestEnd! - bestStart)) {
          bestStart = curStart;
          bestEnd = curEnd;
        }
        curStart = null;
      }
    }

    if (curStart != null) {
      final curEnd = scores.length - 1;
      if (bestStart == null || (curEnd - curStart) > (bestEnd! - bestStart)) {
        bestStart = curStart;
        bestEnd = curEnd;
      }
    }

    return bestStart == null ? null : ShipRangeBand(bestStart, bestEnd!);
  }

  ShipRangeBand? _findPeakCenteredBand(
      List<double> scores,
      double threshold,
      int peak,
      ) {
    if (scores[peak] < threshold) return null;

    int start = peak;
    int end = peak;

    while (start > 0 && scores[start - 1] >= threshold) {
      start--;
    }
    while (end < scores.length - 1 && scores[end + 1] >= threshold) {
      end++;
    }

    return ShipRangeBand(start, end);
  }
}

extension ShipRangeProfileX on Ship {
  ShipRangeProfile sustainedRangeProfile({int maxRange = 12}) {
    return const ShipRangeProfiler(
      RangeProfileOptions(
        readyOnly: false,
        weightByFireRate: true,
        requireAmmo: true,
        includeCrits: true,
      ),
    ).build(this, maxRange: maxRange);
  }

  ShipRangeProfile volleyRangeProfile({int maxRange = 12}) {
    return const ShipRangeProfiler(
      RangeProfileOptions(
        readyOnly: true,
        weightByFireRate: false,
        requireAmmo: true,
        includeCrits: true,
      ),
    ).build(this, maxRange: maxRange);
  }
}

extension ShipRangeProfileAscii on ShipRangeProfile {
  String asciiBars() {
    const glyphs = [' ', '.', ':', '-', '=', '+', '*', '#', '%', '@'];
    if (peakScore <= 0) return 'no weapons';

    return scoreByRange.map((score) {
      final t = (score / peakScore).clamp(0.0, 1.0);
      final idx = (t * (glyphs.length - 1)).round();
      return glyphs[idx];
    }).join();
  }
}
