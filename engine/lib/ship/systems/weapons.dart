import 'dart:math' as math;
import '../../galaxy/geometry/grid.dart';
import '../../item.dart';
import '../../rng/rng.dart';
import '../ship.dart';
import '../../stock_items/ship/stock_ammo.dart';
import '../../stock_items/ship/stock_lauchers.dart';
import '../../stock_items/ship/stock_pile.dart';
import '../../stock_items/ship/stock_weapons.dart';
import 'ship_system.dart';

// top level constants
const _lightSpeedRange = RangeConfig(flat: true);
const _radioRange = RangeConfig(flat: true);
const _chargedParticleRange = RangeConfig(             // ion, particle
    flat: false,
    idealRange: 4,
    maxRange: 8,
    farFalloff: 0.25  // beam spreading/decoherence
);
const _plasmoidRange = RangeConfig(idealRange: 1, maxRange: 3, farFalloff: 2.0);
const _thermalRange = RangeConfig(idealRange: 3, maxRange: 6, farFalloff: 0.4);
const _ballisticRange = RangeConfig(flat: true);

enum DamageType {
  none(0),
  kinetic(.1,damageRange: _ballisticRange), //*** earth/material
  photonic(1, damageRange: _lightSpeedRange), //shield centric damage *** elemental
  plasma(.2, damageRange: _plasmoidRange), //great against shields, fire against hull *** elec
  fire(.25, damageRange: _thermalRange), //damage over time to hull *** poison
  sonic(.5, damageRange: _radioRange), //effective against reduced (50% or less) shields and hull *** vorpal
  ion(1, damageRange: _chargedParticleRange), //some % of the damage dealt affects ship systems directly *** vampiric
  gravitron(1, damageRange: _lightSpeedRange), //pulls ship towards/away when damage is dealt
  neutrino(1, damageRange: _lightSpeedRange), //ignores shields
  etherial(1, damageRange: _lightSpeedRange), //random damage
  all(1);
  final double speed;
  final RangeConfig damageRange;
  const DamageType(this.speed, {
      this.damageRange = const RangeConfig()});
}

class DamageProfile {
  final int? flatDmg;
  final int dmgDice;
  final int dmgDiceSides;
  final int dmgBase;
  final double dmgMult;
  final CritConfig critConfig;

  const DamageProfile({
    this.flatDmg,
    this.dmgDice = 1,
    this.dmgDiceSides = 6,
    this.dmgBase = 1,
    this.dmgMult = 1,
    this.critConfig = const CritConfig()
  });

  double roll(double accuracy, math.Random rnd) {
    double damage = 0;
    final roll = rnd.nextDouble();
    damage = _grossDamage(rnd);
    double overhit = accuracy - roll;
    double critChance = math.min(
      1.0,
      critConfig.baseChance +
          (overhit * critConfig.accuracyScaling),
    );
    if (rnd.nextDouble() < critChance) {
      damage *= critConfig.severity;
    }
    return damage;
  }

  double _grossDamage(math.Random rnd) =>
      (dmgBase +
          (flatDmg == null
            ? Rng.rollDice(dmgDice, dmgDiceSides, rnd)
            : rnd.nextDouble() * flatDmg!))
          * dmgMult;
}

enum WeaponEgo {
  none, corrosive, antiFed, hyperFire, shieldBoost, scrambler, detector, tunneller, disruptor, efficient, extended
}

//enum RangeAttenuation {  linear,exponential }

class RangeConfig {
  final bool flat;
  final double idealRange;
  final double minRange, maxRange;
  final double closeFalloff, farFalloff;

  const RangeConfig({
      this.flat = false,
      this.idealRange = 0,
      this.minRange = 0,
      this.maxRange = 999,
      this.closeFalloff = 0,
      this.farFalloff = 0
  });

  double rangeMultiplier(double dist) {
    if (dist < minRange || dist > maxRange) return 0.0;
    //if (dist == idealRange) return 1.0;
    if (dist > idealRange) {
      return (flat && farFalloff == 0)
          ? 1.0
          : math.exp(-farFalloff * (dist - idealRange));
    } else {
      return (flat && closeFalloff == 0)
          ? 1.0
          : math.exp(-closeFalloff * (idealRange - dist));
    }
  }
}

class CritConfig {
  final double baseChance;      // baseline crit probability
  final double severity;        // how hard scripts hit
  final double accuracyScaling; // how much accuracy above 100% matters

  const CritConfig({
    this.baseChance = 0.0,
    this.severity = 1.0,
    this.accuracyScaling = 0.0,
  });
}

class Weapon extends ShipSystem {
  static double damageMultiplier = 3.3;
  final DamageProfile dmgProf;
  final DamageType dmgType;
  final WeaponEgo ego;
  final AmmoType? ammoType;
  final int clipRate; //units of ammo per round of fire
  final double energyRate; //units of energy per round of fire
  final int fireRate; //aut to complete one round of fire (cooldown)
  final double baseAccuracy; //base chance to hit
  final double accuracyFalloff; //accuracy over distance modifier
  final RangeConfig? _dmgRangeOverride; //unusual overrides of inherent dmg
  final CritConfig critConfig;
  final Domain level;
  final double accel;
  Ammo? ammo;
  int cooldown = 0;
  double get speed => (ammo != null ? ammo!.speed : dmgType.speed) * accel;
  RangeConfig get damageRangeConfig => _dmgRangeOverride ?? dmgType.damageRange;

  @override
  ShipSystemType get type => usesAmmo ? ShipSystemType.launcher : ShipSystemType.weapon;

  Weapon(super.name,{
    required this.dmgProf,
    required this.dmgType,
    required this.ego,
    required this.energyRate,
    required this.fireRate,
    this.baseAccuracy = 1,
    this.accuracyFalloff = .1, //.002 at speed .1 = ~50% at max (32) range
    RangeConfig? dmgRangeOverride,
    this.level = Domain.impulse,
    this.critConfig = const CritConfig(),
    this.clipRate = 0,
    this.ammoType,
    this.accel = 1,
    required super.baseCost,
    required super.baseRepairCost,
    required super.powerDraw,
    required super.mass,
    required super.about,
    super.manufacturer,
    super.rarity,
    super.stability,
    super.repairDifficulty
  }) : _dmgRangeOverride = dmgRangeOverride;

  factory Weapon.fromStock(StockSystem stock) {
    WeaponData data = stockWeapons[stock] ?? stockLaunchers[stock]!;
    return Weapon(
      data.systemData.name,
      manufacturer: data.systemData.manufacturer,
      mass: data.systemData.mass,
      powerDraw: data.systemData.powerDraw,
      stability: data.systemData.stability,
      baseCost: data.systemData.baseCost,
      baseRepairCost: data.systemData.baseRepairCost,
      repairDifficulty: data.systemData.repairDifficulty,
      rarity: data.systemData.rarity,
      about: data.systemData.about,
      //
      dmgProf: data.dmgProf,
      dmgType: data.dmgType,
      ego: data.ego,
      clipRate: data.clipRate,
      ammoType: data.ammoType,
      energyRate: data.energyRate,
      fireRate: data.fireRate,
      baseAccuracy: data.baseAccuracy,
      dmgRangeOverride: data.dmgRangeOverride,
      level: data.level,
      critConfig: data.critConfig,
      accel: data.accel
    );
  }

  bool get usesAmmo => clipRate > 0;

  double fire(double dist, math.Random rnd, {Ship? targetShip}) { //TODO: what is targetShip for?
    cooldown = fireRate;
    return _calcDamage(dist, rnd);
  }

  double baseProbability(double dist) =>
      math.exp(-dist * accuracyFalloff / dmgType.speed);
  double effectiveAccuracy(double dist) =>
      (baseProbability(dist) * baseAccuracy).clamp(0.05, 0.95);

  double _calcDamage(double dist, math.Random rnd) {
    if (inoperable) return 0;
    final ea = effectiveAccuracy(dist);
    double dmg = ammo != null
        ? DamageProfile(flatDmg: (ammo!.maxDamage.floor() + ammo!.enchantment)).roll(ea, rnd)
        : dmgProf.roll(ea,rnd); //print("Gross damage: $dmg");
    //TODO: egos, etc.
    final netDamage = dmg * damageRangeConfig.rangeMultiplier(dist); //print("Net damage: $netDamage");
    return (netDamage * damageMultiplier) / (1-damage);
  }

}

class WeaponData {
  final ShipSystemData systemData;
  final DamageType dmgType;
  final DamageProfile dmgProf;
  final WeaponEgo ego;
  final AmmoType? ammoType;
  final int clipRate; //unit of ammo per round of fire
  final double energyRate; //units of energy per round of fire
  final int fireRate; //aut to complete one round of fire
  final double baseAccuracy; //base chance to hit
  final double accuracyFalloff;
  final RangeConfig? dmgRangeOverride;
  final CritConfig critConfig;
  final Domain level;
  final double accel;

  const WeaponData({
    required this.systemData,
    required this.dmgProf,
    required this.dmgType,
    required this.energyRate,
    required this.fireRate,
    this.baseAccuracy = 1,
    this.accuracyFalloff = .1,
    this.dmgRangeOverride,
    this.level = Domain.impulse,
    this.critConfig = const CritConfig(),
    this.clipRate = 0,
    this.ammoType,
    this.ego = WeaponEgo.none,
    this.accel = 1,
  });
}

enum AmmoType {
  torpedo,missile,slug,particle
}

enum AmmoDamageType {
  kinetic,plasma,fire,nuclear,antimatter
}

enum AmmoEgo {
  none,heatseeking,lightweight,fedbane
}

class Ammo extends Item {
  final AmmoType ammoType;
  final AmmoDamageType damageType;
  final double maxDamage;
  final double volitity;
  final AmmoEgo ego;
  final int splashRad;
  final double splashFalloff;
  final int enchantment;
  final int maxEnchantment;
  final double speed;
  double get expectedDamage => maxDamage * 0.5;

  Ammo(super.name, {
    required this.ammoType,
    required this.damageType,
    required this.maxDamage,
    required super.baseCost,
    this.splashRad = 0,
    this.splashFalloff = .5,
    this.volitity = .9,
    this.ego = AmmoEgo.none,
    super.mass = 0.1,
    this.enchantment = 0,
    this.maxEnchantment = 9,
    this.speed = .1,
    super.rarity = .01,
  });

  factory Ammo.fromStock(StockSystem stock) {
    final ammo = stockAmmo[stock]!;
    return Ammo(ammo.name,
        ammoType: ammo.ammoType,
        damageType: ammo.damageType,
        maxDamage: ammo.maxDamage,
        volitity: ammo.volitity,
        ego: ammo.ego,
        mass: ammo.mass,
        splashRad: ammo.splashRad,
        splashFalloff: ammo.splashFalloff,
        enchantment: ammo.enchantment,
        maxEnchantment: ammo.maxEnchantment,
        baseCost: ammo.baseCost,
        speed: ammo.speed
    );
  }
}
