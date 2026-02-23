import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/pilot.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/shop.dart';
import 'package:crawlspace_engine/stock_items/stock_ships.dart';
import 'coord_3d.dart';
import 'fugue_engine.dart';
import 'galaxy/galaxy.dart';
import 'galaxy/system.dart';
import 'grid.dart';
import 'location.dart';

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

  static Ship generateShip(System system, Galaxy galaxy, Random rnd) {
    final location = SystemLocation(system,system.map.rndCell(rnd));
    final pilot = Pilot(Rng.generateName(rnd: rnd),rnd,hostile: true, loc: nowhere, galaxy: galaxy);
    final level = max(0,1 - (galaxy.topo.distance(location.loc.system, galaxy.findHomeworld(pilot.faction.species)) / galaxy.maxJumps));
    final techLvl = max(1,(level * 10).round());
    glog("Faction: ${pilot.faction.name}, tech: $level, $techLvl");
    ShipType shipType = Rng.weightedRandom(pilot.faction.shipWeights.normalized,rnd);
    while (level < shipType.dangerLvl) {
      shipType = Rng.weightedRandom(pilot.faction.shipWeights.normalized,rnd);
    }
    final shipClassType = ShipClassType.values.firstWhereOrNull((t) => t.shipclass.type == shipType) ?? ShipClassType.mentok;
    Ship ship = Ship("HMS ${randomAlienName(rnd)}",pilot: pilot, location: location, shipClass: shipClassType.shipclass);
    ship.installRndPower(techLvl, rnd);
    ship.installRndEngine(Domain.impulse, techLvl, rnd);
    ship.installRndEngine(Domain.system, techLvl, rnd); //no hyperspace
    ship.installRndShield(techLvl, rnd);
    ship.installRndWeapon(techLvl, rnd);
    return ship;
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
  static const Map<ShopType, List<String>> shopFlavors = {
    ShopType.power:   ["Reactors", "Powerworks", "Fusion Emporium", "Core Depot"],
    ShopType.engine:  ["Engines", "Driveworks", "Propulsion Guild", "Thrust Hall"],
    ShopType.shield:  ["Shieldworks", "Deflector Forge", "Barrier Bazaar", "Wardens"],
    ShopType.weapon:  ["Arsenal", "Armory", "Killmart", "Gun Cathedral"],
    ShopType.launcher:["Launch Systems", "Missile Bay", "Tube Syndicate"],
    ShopType.misc:    ["Bazaar", "Emporium", "Tech Curios", "Oddities"],
    ShopType.shipyard: ["Shipyard"]
  };

  static const List<String> megacorps = [
    "OmniDyne", "Hyperion", "CryoCore", "VoidStar", "Zenith Union", "NovaCorp"
  ];

  static const List<String> shopPatterns = [
    "{alien} {flavor}",
    "{alien}'s {flavor}",
    "The {alien} {flavor}",
    "{alien}-{alien} {flavor}",
    "{flavor} of {alien}",
    "{alien} & Sons {flavor}",
  ];

  static String generate(ShopType type, Random rnd) {
    String alien = Rng.randomAlienName(rnd);
    String flavor = shopFlavors[type]![rnd.nextInt(shopFlavors[type]!.length)];
    String pattern = shopPatterns[rnd.nextInt(shopPatterns.length)];

    return pattern
        .replaceAll("{alien}", alien)
        .replaceAll("{flavor}", flavor);
  }
}
