import 'dart:math';
import 'package:crawlspace_engine/stock_items/species.dart';

import 'coord_3d.dart';

enum ColorName {
  white,black,blue,red,green,orange,yellow,lavender,peach,vanilla,cream,
  peppermint,olive,puce,teal,taupe,vermillion,brown,silver,gold,bronze
}

enum AnimalName {
  viper, falcon, shark, raven, wolf, bear, eagle, cobra, mantis, wasp,
  lynx, pike, hornet, badger, jackal, vulture, orca, panther, reaper, basilisk,
}

class Rng {

  static const _consonants = [
    'b','c','d','f','g','h','j','k','l','m','n','p','r','s','t','v','w','x','z',
    'ch','sh','th','kr','gr','st','tr','dr','vr','zl'
  ];

  static const _vowels = [
    'a','e','i','o','u','ae','ai','oa','ou','ei','ia'
  ];

  static String rndColorName(Random rnd) {
    return ColorName.values.elementAt(rnd.nextInt(ColorName.values.length)).name;
  }

  static String rndAnimalName(Random rnd) {
    return AnimalName.values.elementAt(rnd.nextInt(AnimalName.values.length)).name;
  }

  static int rollDice(int count, int sides, Random rnd) {
    int total = 0;
    for (int i = 0; i < count; i++) {
      total += rnd.nextInt(sides) + 1;
    }
    return total;
  }

  static Coord3D rndUnitVector(Random rnd) {
    return Coord3D(rndUnit(rnd),rndUnit(rnd),rndUnit(rnd));
  }

  static int rndUnit(Random rnd) {
    return rnd.nextBool() ? 0 : rnd.nextBool() ? 1 : -1;
  }

  static int poissonRandom(double lambda) { // Simple Poisson approximation
    double L = exp(-lambda);
    int k = 0;
    double p = 1.0;
    final rnd = Random();

    do {
      k++;
      p *= rnd.nextDouble();
    } while (p > L);

    return k - 1;
  }


  static int biasedRndInt(Random rnd, {
    required int mean,
    required int min,
    required int max,
  }) {
    final weights = <int, double>{};

    // Create inverse weights based on distance from mean
    double totalWeight = 0;
    for (int i = min; i <= max; i++) {
      double weight = 1 / (1 + (i - mean).abs()); // Inverse to distance
      weights[i] = weight;
      totalWeight += weight;
    }

    // Roll based on the weights
    double roll = rnd.nextDouble() * totalWeight;
    double cumulative = 0;
    for (final entry in weights.entries) {
      cumulative += entry.value;
      if (roll <= cumulative) return entry.key;
    }

    return mean; // Fallback
  }

  static void rndTest(Random rnd) {
    Map<int,int> intMap = {};
    for (int i=0;i<100;i++) {
      int n = biasedRndInt(rnd, mean: 1, min: 0, max: 5);
      intMap.update(n, (v) => v + 1,  ifAbsent: () => 1);
      print("Rnd: $n");
    }
    print("IntMap: $intMap");
  }

  static String generateName({int minSyllables = 2, int maxSyllables = 4, required Random rnd}) {
    final syllables = minSyllables + rnd.nextInt(maxSyllables - minSyllables + 1);
    final sb = StringBuffer();

    for (int i = 0; i < syllables; i++) {
      sb.write(_pick(_consonants,rnd));
      sb.write(_pick(_vowels,rnd));
    }

    final name = sb.toString();
    return name[0].toUpperCase() + name.substring(1);
  }

  static T _pick<T>(List<T> list, Random rnd) => list[rnd.nextInt(list.length)];

  static T weightedRandom<T>(Map<T, double> weights, Random rnd, {T? fallback}) { //print("Weighted Random: ${weights.toString()}");
    double total = 0.0;
    for (final w in weights.values) {
      if (w > 0) total += w;
    }

    if (total <= 0) {
      if (fallback != null) return fallback;
      throw StateError("No positive weights");
    }

    double roll = rnd.nextDouble() * total;
    double cumulative = 0.0;

    for (final entry in weights.entries) {
      final w = entry.value;
      if (w <= 0) continue;
      cumulative += w;
      if (roll <= cumulative) return entry.key;
    }

    // FP fallback
    return fallback ?? weights.keys.first;
  }
}

class WeightedPicker<T> {
  final List<T> values;
  final List<double> cumulative;
  final double total;

  WeightedPicker._(this.values, this.cumulative, this.total);

  factory WeightedPicker(Map<T,double> weights) {
    final values = <T>[];
    final cumulative = <double>[];
    double sum = 0;

    for (final e in weights.entries) {
      if (e.value <= 0) continue;
      sum += e.value;
      values.add(e.key);
      cumulative.add(sum);
    }

    return WeightedPicker._(values, cumulative, sum);
  }

  T pick(Random rnd) {
    final roll = rnd.nextDouble() * total;

    // Binary search
    int low = 0, high = cumulative.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (roll <= cumulative[mid]) high = mid;
      else low = mid + 1;
    }
    return values[low];
  }
}


