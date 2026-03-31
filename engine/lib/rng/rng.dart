import 'dart:math';
import 'package:crawlspace_engine/shop.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../item.dart';

enum ColorName {
  white,black,blue,red,green,orange,yellow,lavender,peach,vanilla,cream,
  peppermint,olive,puce,teal,taupe,vermillion,brown,silver,gold,bronze;
  String random(Random rnd) => ColorName.values.elementAt(rnd.nextInt(ColorName.values.length)).name;
}

enum AnimalName {
  viper, falcon, shark, raven, wolf, bear, eagle, cobra, mantis, wasp,
  lynx, pike, hornet, badger, jackal, vulture, orca, panther, reaper, basilisk;
  String random(Random rnd) => AnimalName.values.elementAt(rnd.nextInt(ColorName.values.length)).name;
}

enum Adjective {
  strange(1.2,.5),
  odd(1.3,.5),
  weird(1.5,.4),
  humming(1.66,.33),
  spinning(1.8,.3),
  vibrating(2,.25),
  oscillating(3,.25),
  radiating(5,.2),
  floating(1,.75),
  inert(.75,.75),
  rusty(.5,.5),
  battered(.33,.5),
  nondescript(.25,.5),
  worthless(.1,.5);
  final double multiplier;
  final double rarity;
  const Adjective(this.multiplier,this.rarity);
}

enum Flotsam {
  cylinder(1, .5),
  sphere(1.2, .5),
  cube(1.1, .5),
  apparatus(2, .3),
  device(2.5, .25),
  debris(0.5, .75),
  component(1.5, .5),
  datacell(3, .33),
  fluxcapacitor(5, .2),
  capsule(8, .16),
  pod(12, .1),
  dinghy(20, .05);
  final double multiplier;
  final double rarity;
  const Flotsam(this.multiplier,this.rarity);
}

class Rng {

  static const List<String> alienPrefixes = [
    "Xar", "Qel", "Vor", "Zyn", "Tal", "Ixo", "Prax", "Khe", "Ulm", "Syr", "Nok",
    "Gor", "Leth", "Oon", "Trek", "Vash", "Zor", "Hyl", "Mek", "Thra"
  ];

  static const List<String> alienSuffixes = [
    "tek", "kor", "dyn", "plex", "zon", "ium", "rax", "mar", "shi", "tor", "vox",
    "bel", "tar", "nok", "thal", "vek", "lo", "zar"
  ];

  static String randomAlienName(Random rnd) {
    String p = alienPrefixes[rnd.nextInt(alienPrefixes.length)];
    String s = alienSuffixes[rnd.nextInt(alienSuffixes.length)];

    // Occasionally mash two prefixes for more chaos
    if (rnd.nextDouble() < 0.15) {
      p += alienPrefixes[rnd.nextInt(alienPrefixes.length)].toLowerCase();
    }

    return p + s;
  }

  static Item randomArtifact(Random rnd, int maxPrice) {
    final adjective = weightedRandom(
      Map.fromEntries(Adjective.values.map((a) => MapEntry(a, a.rarity))),
      rnd,
      fallback: Adjective.nondescript,
    );

    final flotsam = weightedRandom(
      Map.fromEntries(Flotsam.values.map((f) => MapEntry(f, f.rarity))),
      rnd,
      fallback: Flotsam.debris,
    );

    final baseCost = (adjective.multiplier * flotsam.multiplier * maxPrice * 0.1)
        .round()
        .clamp(1, maxPrice);
    final rarity = adjective.rarity * flotsam.rarity;
    final name = "${adjective.name} ${flotsam.name}";

    return Item(
      name[0].toUpperCase() + name.substring(1),
      baseCost: baseCost,
      rarity: rarity,
    );
  }

  static const _consonants = [
    'b','c','d','f','g','h','j','k','l','m','n','p','r','s','t','v','w','x','z',
    'ch','sh','th','kr','gr','st','tr','dr','vr','zl'
  ];

  static const _vowels = [
    'a','e','i','o','u','ae','ai','oa','ou','ei','ia'
  ];

  static int rollDice(int count, int sides, Random rnd) {
    int total = 0;
    for (int i = 0; i < count; i++) {
      total += rnd.nextInt(sides) + 1;
    }
    return total;
  }

  static Coord3D rndUnitVector(Random rnd, {depth = false}) {
    return Coord3D(rndUnit(rnd),rndUnit(rnd),depth ? 0 : rndUnit(rnd));
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

  static double betaRnd(Random rnd, double mean, double strength) {
    final eps = 1e-6;
    final m = mean.clamp(eps, 1 - eps);
    final a = m * strength;
    final b = (1 - m) * strength;;

    final ga = gammaRnd(rnd, a);
    final gb = gammaRnd(rnd, b);

    return ga / (ga + gb);
  }

  static double gammaRnd(Random rnd, double shape) {
    if (shape < 1) {
      // Use Johnk's generator
      final u = rnd.nextDouble();
      return gammaRnd(rnd, shape + 1) * pow(u, 1 / shape);
    }

    final d = shape - 1.0 / 3.0;
    final c = 1.0 / sqrt(9.0 * d);

    while (true) {
      double x, v;
      do {
        x = gaussianRnd(rnd, 0, 1);
        v = 1 + c * x;
      } while (v <= 0);
      v = v * v * v;

      final u = rnd.nextDouble();
      if (u < 1 - 0.331 * pow(x, 4)) return d * v;
      if (log(u) < 0.5 * x * x + d * (1 - v + log(v))) return d * v;
    }
  }

  static double gaussianRnd(Random rnd, double mean, double stdDev) {
    // Box-Muller
    final u1 = rnd.nextDouble();
    final u2 = rnd.nextDouble();
    final z0 = sqrt(-2.0 * log(u1)) * cos(2 * pi * u2);
    return mean + z0 * stdDev;
  }

  static double biasedRndDouble(Random rnd, {
    required double mean,
    required double min,
    required double max,
    double? stdDev,
  }) {
    final standardDev = stdDev ?? (0.15 * (max - min));
    return gaussianRnd(rnd, mean, standardDev).clamp(min, max);
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

class ShopNameGen {
  // Low-tech: gritty, salvage-yard vibes
  // Mid-tech: corporate, functional
  // High-tech: sleek, abstract, megacorp prestige
  static const Map<SystemShopType, List<List<String>>> shopFlavors = {
    SystemShopType.power: [
      ["Fuel Shack", "Generator Yard", "Spark Hut"],           // 1–3
      ["Reactors", "Powerworks", "Core Depot"],                // 4–6
      ["Fusion Emporium", "Quantum Core", "Stellar Array"],    // 7–10
    ],
    SystemShopType.engine: [
      ["Drive Shed", "Thruster Patch", "Burn Yard"],
      ["Engines", "Driveworks", "Propulsion Guild"],
      ["Thrust Hall", "Void Propulsion", "Singularity Drive"],
    ],
    SystemShopType.shield: [
      ["Plate Shop", "Hull Patch", "Scrap Ward"],
      ["Shieldworks", "Barrier Bazaar", "Deflector Forge"],
      ["Phase Wardens", "Null Barrier", "Quantum Aegis"],
    ],
    SystemShopType.weapon: [
      ["Guns", "Blasters", "The Rack"],
      ["Arsenal", "Armory", "Killmart"],
      ["Gun Cathedral", "Void Armaments", "Terminus Weapons"],
    ],
    SystemShopType.launcher: [
      ["Tube Shack", "Missile Shed", "The Silo"],
      ["Launch Systems", "Missile Bay"],
      ["Tube Syndicate", "Orbital Payload", "Void Ordnance"],
    ],
    SystemShopType.misc: [
      ["Junk Heap", "Odds & Ends", "The Pile"],
      ["Bazaar", "Emporium", "Tech Curios"],
      ["Oddities", "Quantum Curios", "Relic Exchange"],
    ],
  };

  /*
      SystemShopType.shipyard: [
      ["Shipyard"],
      ["Shipyard", "Dry Dock"],
      ["Shipyard", "Void Foundry", "Stellar Works"],
    ],
   */

  // Patterns skew toward grander structures at higher tech
  static const List<List<String>> shopPatterns = [
    // Low tech (1–3): simple, personal
    [
      "{alien}'s {flavor}",
      "{alien} {flavor}",
      "Old {alien} {flavor}",
    ],
    // Mid tech (4–6): corporate-ish
    [
      "{alien} {flavor}",
      "The {alien} {flavor}",
      "{alien}-{alien} {flavor}",
      "{alien} & Sons {flavor}",
    ],
    // High tech (7–10): abstract, institutional
    [
      "{alien} {flavor}",
      "{flavor} of {alien}",
      "The {alien} {flavor}",
      "{alien}-{alien} {flavor}",
      "{megacorp} {flavor}",       // megacorps only appear at high tech
    ],
  ];

  static const List<String> megacorps = [
    "OmniDyne", "Hyperion", "CryoCore", "VoidStar", "Zenith Union", "NovaCorp"
  ];

  static int _tier(int techLvl) {
    if (techLvl <= 3) return 0;
    if (techLvl <= 6) return 1;
    return 2;
  }

  static String generate(SystemShopType type, int techLvl, Random rnd) {
    final tier = _tier(techLvl.clamp(1, 10));

    final flavorList = shopFlavors[type]![tier];
    final patternList = shopPatterns[tier];

    final alien = Rng.randomAlienName(rnd);
    final alien2 = Rng.randomAlienName(rnd);
    final megacorp = megacorps[rnd.nextInt(megacorps.length)];
    final flavor = flavorList[rnd.nextInt(flavorList.length)];
    final pattern = patternList[rnd.nextInt(patternList.length)];

    return pattern
        .replaceAll("{alien}", alien)
        .replaceAll("{alien2}", alien2)  // in case you want distinct doubles later
        .replaceFirstMapped(RegExp(r'\{alien\}(?=.*\{alien\})'), (_) => alien)
        .replaceAll("{alien}", alien2)   // second {alien} gets a different name
        .replaceAll("{megacorp}", megacorp)
        .replaceAll("{flavor}", flavor);
  }
}
