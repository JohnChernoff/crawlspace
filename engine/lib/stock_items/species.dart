import 'dart:math';
import 'package:crawlspace_engine/stock_items/stock_ships.dart';
import 'package:crawlspace_engine/stock_items/xeno.dart';
import 'package:crawlspace_engine/systems/engines.dart';
import 'package:crawlspace_engine/systems/power.dart';
import 'package:crawlspace_engine/systems/shields.dart';
import 'package:crawlspace_engine/systems/weapons.dart';

class WeightedTrait<T extends Enum> {
  final Map<T, double> _map;
  final List<T> allValues;
  final double defWeight;

  Map<T, double> get map => Map.unmodifiable(_map);

  const WeightedTrait(
      this._map, {
        required this.allValues,
        this.defWeight = .5,
      });

  Map<T, double> _buildMap() {
    final m = <T, double>{};
    for (final e in allValues) {
      m[e] = _map[e] ?? defWeight;
    }
    return m;
  }

  Map<T, double> get normalized => normalize(_buildMap());

  double weightOf(T v) => _map[v] ?? defWeight;
  double bias(T v) => weightOf(v);
  double probability(T v) => normalized[v] ?? defWeight;

  factory WeightedTrait.all({
    required List<T> allValues,
    double defWeight = .5,
  }) =>
      WeightedTrait({}, allValues: allValues, defWeight: defWeight);

  factory WeightedTrait.norm(
      Map<T, double> m, {
        required List<T> allValues,
        double defWeight = .5,
      }) =>
      WeightedTrait(normalize(m),
          allValues: allValues, defWeight: defWeight);
}


class Species {
  final String name;
  final String desc;
  final double propagation;
  final double range;
  final double courage;
  final double flexibility;
  final double xenomancy;
  final WeightedTrait<XenomancySchool>? xenoWeights; //null = all
  final WeightedTrait<ShipType>? shipWeights; //null = all
  final WeightedTrait<PowerType>? powerWeights; //null = all
  final WeightedTrait<EngineType>? engineWeights; //null = all
  final WeightedTrait<ShieldType>? shieldWeights; //null = all
  final WeightedTrait<DamageType>? damageWeights; //null = all
  final WeightedTrait<AmmoDamageType>? ammoDamageWeights; //null = all
  final double rangedProb;
  const Species(this.name,this.propagation, {
      this.desc = "Mostly Harmless",
      this.range = .5,
      this.courage = .5,
      this.flexibility = .5,
      this.xenomancy = .5,
      this.xenoWeights,
      this.shipWeights,
      this.powerWeights,
      this.engineWeights,
      this.shieldWeights,
      this.damageWeights,
      this.ammoDamageWeights,
      this.rangedProb = .5,
  });
}

class Faction {
  final Species species;
  final String name;
  final String desc;
  final double relativeFreq;
  final double courage;
  final double flexibility;
  final double xenomancy;
  final double rangedProb;
  final Map<Faction,double> influence = {};
  late final WeightedTrait<XenomancySchool> xenoWeights; //null = all
  late final WeightedTrait<ShipType> shipWeights; //null = all
  late final WeightedTrait<PowerType> powerWeights; //null = all
  late final WeightedTrait<EngineType> engineWeights; //null = all
  late final WeightedTrait<ShieldType> shieldWeights; //null = all
  late final WeightedTrait<DamageType> damageWeights; //null = all
  late final WeightedTrait<AmmoDamageType> ammoDamageWeights; //null = all

  Faction(this.species,this.name,{
    required this.relativeFreq,
    this.desc = "Mostly Harmless",
    double? crg,
    double? flex,
    double? xeno,
    double? ranged,
    WeightedTrait<XenomancySchool>? xWeights,
    WeightedTrait<ShipType>? shpWeights,
    WeightedTrait<PowerType>? pWeights,
    WeightedTrait<EngineType>? eWeights,
    WeightedTrait<ShieldType>? shldWeights,
    WeightedTrait<DamageType>? dWeights,
    WeightedTrait<AmmoDamageType>? aWeights,

  }) : courage = crg ?? species.courage, flexibility = flex ?? species.flexibility, xenomancy = xeno ?? species.xenomancy, rangedProb = ranged ?? species.rangedProb {
    xenoWeights = xWeights ?? species.xenoWeights ?? WeightedTrait<XenomancySchool>.all(allValues:XenomancySchool.values);
    shipWeights = shpWeights ?? species.shipWeights ?? WeightedTrait<ShipType>.all(allValues: ShipType.values);
    powerWeights = pWeights ?? species.powerWeights ?? WeightedTrait<PowerType>.all(allValues: PowerType.values);
    engineWeights = eWeights ?? species.engineWeights ?? WeightedTrait<EngineType>.all(allValues: EngineType.values);
    shieldWeights = shldWeights ?? species.shieldWeights ?? WeightedTrait<ShieldType>.all(allValues: ShieldType.values);
    damageWeights = dWeights ?? species.damageWeights ?? WeightedTrait<DamageType>.all(allValues: DamageType.values);
    ammoDamageWeights = aWeights ?? species.ammoDamageWeights ?? WeightedTrait<AmmoDamageType>.all(allValues: AmmoDamageType.values);
  }

  void setInfluence(Faction f, double n, {bool mutual = true}) {
    influence[f] = n;
    if (mutual) f.influence[this] = n;
  }
}

enum StockSpecies {
  humanoid(
      Species("Humanoid",.87,
        xenoWeights: WeightedTrait({XenomancySchool.elemental: .9,},
            defWeight: .2, allValues: XenomancySchool.values),
        damageWeights: WeightedTrait({DamageType.etherial: .01},
            defWeight: .5, allValues: DamageType.values)
      )
  ),
  vorlon(Species("Vorlon", .33,
        xenoWeights: WeightedTrait({XenomancySchool.dark: .9,},
          defWeight: .1, allValues: XenomancySchool.values),
      damageWeights: WeightedTrait({DamageType.etherial: .08},
          defWeight: .5, allValues: DamageType.values)
      )
  ),
  gersh(Species("Greshplerglesnortz", .25, xenomancy: .1,
      xenoWeights: WeightedTrait({XenomancySchool.gravimancy: .7,XenomancySchool.dark: .1},
          defWeight: .3, allValues: XenomancySchool.values),
      damageWeights: WeightedTrait({DamageType.kinetic: .08, DamageType.etherial: 0},
          defWeight: .1, allValues: DamageType.values)
      ),
  ),

  ;
  final Species species;
  const StockSpecies(this.species);
}

pirateFaction(Species species, {String? name,double freq = .1}) => Faction(species, name ?? "${species.name} Pirate",desc: "A dastardly ${species.name} pirate",
    relativeFreq: freq, shpWeights: WeightedTrait({ShipType.interceptor : .9},defWeight: .01,allValues: ShipType.values));

final List<Faction> factions = [
  Faction(StockSpecies.humanoid.species,"Federation", relativeFreq: .8, desc: "An ICORP officer or citizen"),
  Faction(StockSpecies.humanoid.species,"Fed Rebel", relativeFreq: .2, desc: "An insurrectionist dedicated to their fight against ICORP"),
  pirateFaction(StockSpecies.humanoid.species),
  Faction(StockSpecies.vorlon.species,"Vorlornian", relativeFreq: .67, desc: "A sneaky Vorlornian"),
  Faction(StockSpecies.vorlon.species,"Vorlox Mystic", relativeFreq: .25, desc: "A Vorlornian specialist in the manipulation of dark energy"),
  pirateFaction(StockSpecies.vorlon.species, name: "Sorojbian"),
  Faction(StockSpecies.gersh.species,"Greshplergian", relativeFreq: .9, desc: "A strange cross between an earth wooly mamooth, pig, and hippo.  Fearsome when angered."),
  Faction(StockSpecies.gersh.species,"Hagyorny", relativeFreq: .1, xeno: .5, desc: "A more dolice Gershplergian with a penchant for xenomancy"),
];

Map<T,double> normalize<T>(Map<T,double> m) {
  if (m.isEmpty) return const {};
  final sum = m.values.fold(0.0, (a,b)=>a+b);
  if (sum == 0) {
    final v = 1.0 / m.length;
    return { for (final e in m.keys) e: v };
  }
  return {for (var e in m.entries) e.key: e.value / sum};
}

Map<T,double> uniformWeightsFrom<T>(Iterable<T> values, [double v = 1.0]) =>
    normalize({ for (final e in values) e: v });

Map<T,double> noisyUniform<T extends Enum>(List<T> values, Random rnd) {
  return normalize({
    for (final v in values) v: 0.8 + rnd.nextDouble() * 0.4
  });
}

