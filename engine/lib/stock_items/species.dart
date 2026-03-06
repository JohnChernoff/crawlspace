import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/color.dart';
import 'package:crawlspace_engine/stock_items/stock_ships.dart';
import 'package:crawlspace_engine/stock_items/xenomancy.dart';
import 'package:crawlspace_engine/systems/engines.dart';
import 'package:crawlspace_engine/systems/power.dart';
import 'package:crawlspace_engine/systems/shields.dart';
import 'package:crawlspace_engine/systems/weapons.dart';

enum ShipPrefs {
  all({}),
  standard({
    ShipType.scout: 1,
    ShipType.skiff: .8,
    ShipType.cruiser: .6,
    ShipType.destroyer: .4,
    ShipType.interceptor: .3,
    ShipType.battleship: .2,
    ShipType.flagship: .1
  });
  final Map<ShipType,double> shipWeights;
  const ShipPrefs(this.shipWeights);
}

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

class SpeciesRegistry {
  final List<Species> all;
  final Map<Species,int> index = {};
  SpeciesRegistry(this.all) {
    for (int i = 0; i < all.length; i++) index[all[i]] = i;
  }
}

class Species {
  final String name;
  final String homeWorld;
  final String desc;
  final String glyph;
  final double populationDensity;
  final double propagation;// how fast civIntensity decays with distance
  final double range; //max influence range
  final double commerce; // boosts hubs/trade nodes
  final double courage; // reduces hazard penalties, increases combat willpower
  final double militancy;
  final double tech;
  final double techFall; //tech influence modifier
  final double flexibility; //alliance mutability
  final double xenomancy;
  final GameColor graphCol;
  final WeightedTrait<XenomancySchool>? xenoWeights; //null = all
  final WeightedTrait<ShipType>? shipWeights; //null = all
  final WeightedTrait<PowerType>? powerWeights; //null = all
  final WeightedTrait<EngineType>? engineWeights; //null = all
  final WeightedTrait<ShieldType>? shieldWeights; //null = all
  final WeightedTrait<DamageType>? damageWeights; //null = all
  final WeightedTrait<AmmoDamageType>? ammoDamageWeights; //null = all
  final double rangedProb;
  const Species(this.name,this.homeWorld,this.propagation,this.glyph, {
      required this.graphCol,
      this.desc = "Mostly Harmless",
      this.range = .5,
      this.courage = .5,
      required this.militancy,
      this.flexibility = .5,
      this.xenomancy = .5,
      this.populationDensity = .5,
      this.commerce = .5,
      this.tech = .5,
      this.techFall = .25,
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
  final GameColor color;
  double strength;
  double militancy;
  final Map<Species, double> fixedAttitudes;
  final isPirate;
  final double courage;
  final double flexibility;
  final double xenomancy;
  final double rangedProb;
  final Map<Faction,double> influence = {};
  final WeightedTrait<XenomancySchool> xenoWeights; //null = all
  final WeightedTrait<ShipType> shipWeights; //null = all
  final WeightedTrait<PowerType> powerWeights; //null = all
  final WeightedTrait<EngineType> engineWeights; //null = all
  final WeightedTrait<ShieldType> shieldWeights; //null = all
  final WeightedTrait<DamageType> damageWeights; //null = all
  final WeightedTrait<AmmoDamageType> ammoDamageWeights; //null = all

  Faction(this.species,this.name,{
    required this.strength,
    this.desc = "Mostly Harmless",
    this.color = GameColors.white,
    this.fixedAttitudes = const {},
    this.isPirate = false,
    double? crg,
    double? flex,
    double? xeno,
    double? ranged,
    double? militancy,
    WeightedTrait<XenomancySchool>? xWeights,
    WeightedTrait<ShipType>? shpWeights,
    WeightedTrait<PowerType>? pWeights,
    WeightedTrait<EngineType>? eWeights,
    WeightedTrait<ShieldType>? shldWeights,
    WeightedTrait<DamageType>? dWeights,
    WeightedTrait<AmmoDamageType>? aWeights,
  }) : courage = crg ?? species.courage,
        militancy = militancy ?? species.militancy,
        flexibility = flex ?? species.flexibility,
        xenomancy = xeno ?? species.xenomancy,
        rangedProb = ranged ?? species.rangedProb,
        xenoWeights = xWeights ?? species.xenoWeights ?? WeightedTrait<XenomancySchool>.all(allValues:XenomancySchool.values),
        shipWeights = shpWeights ?? species.shipWeights ?? WeightedTrait<ShipType>.all(allValues: ShipType.values),
        powerWeights = pWeights ?? species.powerWeights ?? WeightedTrait<PowerType>.all(allValues: PowerType.values),
        engineWeights = eWeights ?? species.engineWeights ?? WeightedTrait<EngineType>.all(allValues: EngineType.values),
        shieldWeights = shldWeights ?? species.shieldWeights ?? WeightedTrait<ShieldType>.all(allValues: ShieldType.values),
        damageWeights = dWeights ?? species.damageWeights ?? WeightedTrait<DamageType>.all(allValues: DamageType.values),
        ammoDamageWeights = aWeights ?? species.ammoDamageWeights ?? WeightedTrait<AmmoDamageType>.all(allValues: AmmoDamageType.values);

  void setInfluence(Faction f, double n, {bool mutual = true}) {
    influence[f] = n;
    if (mutual) f.influence[this] = n;
  }
}

enum StockSpecies {
  humanoid(
      Species("Humanoid","Xaxle",.87,"H",graphCol: GameColors.white,
        militancy: .5,
        xenoWeights: WeightedTrait({XenomancySchool.elemental: .9,},
            defWeight: .2, allValues: XenomancySchool.values),
        damageWeights: WeightedTrait({DamageType.etherial: .01},
            defWeight: .5, allValues: DamageType.values)
      )
  ),
  vorlon(Species("Vorlon","Ubuntov",.33,"V",graphCol: GameColors.purple,
        militancy: .7,
        xenoWeights: WeightedTrait({XenomancySchool.dark: .9,},
          defWeight: .1, allValues: XenomancySchool.values),
      damageWeights: WeightedTrait({DamageType.etherial: .08},
          defWeight: .5, allValues: DamageType.values)
      )
  ),
  gersh(Species("Greshplerglesnortz","Hew",.25, xenomancy: .1,"G",graphCol: GameColors.green,
      militancy: .4,
      xenoWeights: WeightedTrait({XenomancySchool.gravimancy: .7,XenomancySchool.dark: .1},
          defWeight: .3, allValues: XenomancySchool.values),
      damageWeights: WeightedTrait({DamageType.kinetic: .08, DamageType.etherial: 0},
          defWeight: .1, allValues: DamageType.values)
      ),
  ),
  edualx(Species("Edualx","Zarm",.25, xenomancy: .4,"S",graphCol: GameColors.orange,
      militancy: .2,
      xenoWeights: WeightedTrait({XenomancySchool.antimatter: .7},
          defWeight: .2, allValues: XenomancySchool.values),
      damageWeights: WeightedTrait({DamageType.neutrino: .08},
          defWeight: .1, allValues: DamageType.values)
      ),
  ),
  lael(Species("Lael","Grenz",.25, xenomancy: .4,"L",graphCol: GameColors.gold,
      militancy: .1,
      xenoWeights: WeightedTrait({XenomancySchool.chronomancy: .7},
          defWeight: .2, allValues: XenomancySchool.values),
      damageWeights: WeightedTrait({DamageType.sonic: .08},
          defWeight: .1, allValues: DamageType.values)
    ),
  ),
  orblix(Species("Orblix","Bollox",.25, xenomancy: .4,"O",graphCol: GameColors.tan,
      militancy: .33,
      xenoWeights: WeightedTrait({XenomancySchool.gravimancy: .7},
          defWeight: .2, allValues: XenomancySchool.values),
      damageWeights: WeightedTrait({DamageType.gravitron: .08},
          defWeight: .1, allValues: DamageType.values)
    ),
  ),
  moveliean(Species("Moveliean","Movelia",.25, xenomancy: .4,"M",graphCol: GameColors.brown,
      militancy: .66,
      xenoWeights: WeightedTrait({XenomancySchool.quantum: .7},
          defWeight: .2, allValues: XenomancySchool.values),
      damageWeights: WeightedTrait({DamageType.plasma: .08},
          defWeight: .1, allValues: DamageType.values)
    ),
  ),
  krakkar(Species("Krakkar","Arkadyz",.25, xenomancy: .4,"K",graphCol: GameColors.coral,
      militancy: .9,
      xenoWeights: WeightedTrait({XenomancySchool.astramancy: .7},
          defWeight: .2, allValues: XenomancySchool.values),
      damageWeights: WeightedTrait({DamageType.plasma: .08},
          defWeight: .1, allValues: DamageType.values)
    ),
  );
  final Species species;
  const StockSpecies(this.species);
}

enum FactionList {
  fed("Federation","An ICORP officer"),
  fedReb("Fed Rebel","An insurrectionist dedicated to their fight against ICORP"),
  vor("Vorlornian","A Vorlornian soldier"),
  vorMystic("Vorlox Mystic","A Vorlornian specialist in the manipulation of dark energy"),
  soroj("Sorojbian","A rogue Vorlornian"),
  gersh("Greshplergian","A strange cross between an earth wooly mamooth, pig, and hippo.  Fearsome when angered."),
  hagy("Hagyorny","A more docile Gershplergian with a penchant for xenomancy"),
  skorpl("",""),
  lael("",""),
  orblix("",""),
  mov("",""),
  krakkar("","");
  final String factionName;
  final String desc;
  const FactionList(this.factionName,this.desc);
}

Faction? getFaction(FactionList factionEnum) => factions.firstWhereOrNull((f) => f.name == factionEnum.factionName);

pirateFaction(Species species, {String? name,String? desc,double strength = .1}) =>
    Faction(species, name ?? "${species.name} Pirate",desc: desc ?? "A dastardly ${species.name} pirate",color: species.graphCol, //darken?
    strength: strength, militancy: .95, isPirate: true,
        shpWeights: WeightedTrait({ShipType.interceptor : .9},defWeight: .01,allValues: ShipType.values));

final List<Faction> factions = [
  Faction(StockSpecies.humanoid.species, FactionList.fed.factionName, desc: FactionList.fed.desc,
      strength: .8, shpWeights: WeightedTrait(ShipPrefs.standard.shipWeights, allValues: ShipType.values),
      color: GameColors.white),

  Faction(StockSpecies.humanoid.species, FactionList.fedReb.factionName, desc: FactionList.fedReb.desc,
      strength: .2, shpWeights: WeightedTrait(ShipPrefs.standard.shipWeights, allValues: ShipType.values),
      fixedAttitudes: {StockSpecies.krakkar.species : .1},
      color: GameColors.lightBlue),

  pirateFaction(StockSpecies.humanoid.species),

  Faction(StockSpecies.vorlon.species, FactionList.vor.factionName, desc: FactionList.vor.desc,
      strength: .67, shpWeights: WeightedTrait(ShipPrefs.standard.shipWeights, allValues: ShipType.values),
      fixedAttitudes: {StockSpecies.humanoid.species : .5},
      color: GameColors.gray),

  Faction(StockSpecies.vorlon.species, FactionList.vorMystic.factionName, desc: FactionList.vorMystic.desc,
      strength: .25, shpWeights: WeightedTrait(ShipPrefs.standard.shipWeights, allValues: ShipType.values),
      fixedAttitudes: {StockSpecies.edualx.species : .1},
      color: GameColors.darkGreen),

  pirateFaction(StockSpecies.vorlon.species, name: FactionList.soroj.factionName, desc: FactionList.soroj.desc),

  Faction(StockSpecies.gersh.species, FactionList.gersh.factionName, desc: FactionList.gersh.desc,
      strength: .9, shpWeights: WeightedTrait(ShipPrefs.standard.shipWeights, allValues: ShipType.values),
      color: GameColors.green),

  Faction(StockSpecies.gersh.species,FactionList.hagy.factionName, desc: FactionList.hagy.desc,
      strength: .1, xeno: .5, shpWeights: WeightedTrait(ShipPrefs.standard.shipWeights, allValues: ShipType.values),
      fixedAttitudes: {StockSpecies.vorlon.species : .8},
      color: GameColors.gold),

  pirateFaction(StockSpecies.edualx.species),
  pirateFaction(StockSpecies.lael.species),
  pirateFaction(StockSpecies.orblix.species),
  pirateFaction(StockSpecies.moveliean.species),
  pirateFaction(StockSpecies.krakkar.species),
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

