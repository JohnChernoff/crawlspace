import 'dart:math' as math;
import '../grid.dart';
import '../item.dart';
import '../rng.dart';
import '../ship.dart';
import '../stock_items/stock_ammo.dart';
import '../stock_items/stock_lauchers.dart';
import '../stock_items/stock_pile.dart';
import '../stock_items/stock_weapons.dart';
import 'ship_system.dart';

enum DamageType {
  light, plasma, fire, kinetic, sonic, gravitron, neutrino, etherial
}

enum WeaponEgo {
  none, antiFed, hyperFire, shieldBoost, scrambler, detector, tunneller, disruptor, efficient, extended
}

//enum RangeAttenuation {  linear,exponential }

class RangeConfig {
  final double idealRange;
  final double minRange, maxRange;
  final double closeFalloff, farFalloff;

  const RangeConfig({
      required this.idealRange,
      required this.minRange,
      required this.maxRange,
      required this.closeFalloff,
      required this.farFalloff
  });

  double rangeMultiplier(double dist) {
    if (dist < minRange || dist > maxRange) return 0.0;
    //if (dist == idealRange) return 1.0;
    if (dist > idealRange) {
      return math.exp(-farFalloff * (dist - idealRange));
    } else {
      return math.exp(-closeFalloff * (idealRange - dist));
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
  final int dmgDice;
  final int dmgDiceSides;
  final int dmgBase;
  final double dmgMult;
  final DamageType dmgType;
  final WeaponEgo ego;
  final AmmoType? ammoType;
  final int clipRate; //units of ammo per round of fire
  final int energyRate; //units of energy per round of fire
  final int fireRate; //aut to complete one round of fire (cooldown)
  final double baseAccuracy; //base chance to hit
  final RangeConfig dmgRangeConfig;
  final RangeConfig accuracyRangeConfig;
  final CritConfig critConfig;
  final Domain level;
  Ammo? ammo;
  int cooldown = 0;

  @override
  ShipSystemType get type => usesAmmo ? ShipSystemType.launcher : ShipSystemType.weapon;

  Weapon(super.name,{
    required this.dmgDice,
    required this.dmgDiceSides,
    required this.dmgBase,
    required this.dmgType,
    required this.ego,
    required this.energyRate,
    required this.fireRate,
    required this.baseAccuracy,
    required this.dmgRangeConfig,
    required this.accuracyRangeConfig,
    this.level = Domain.impulse,
    this.dmgMult = 1.0,
    this.critConfig = const CritConfig(),
    this.clipRate = 0,
    this.ammoType,
    required super.baseCost,
    required super.baseRepairCost,
    required super.powerDraw,
    required super.mass,
    super.slot,
    super.rarity,
    super.stability,
    super.repairDifficulty,
  });

  factory Weapon.fromStock(StockSystem stock) {
    WeaponData data = stockWeapons[stock] ?? stockLaunchers[stock]!;
    return Weapon(
      data.systemData.name,
      slot: data.systemData.slot,
      mass: data.systemData.mass,
      powerDraw: data.systemData.powerDraw,
      stability: data.systemData.stability,
      baseCost: data.systemData.baseCost,
      baseRepairCost: data.systemData.baseRepairCost,
      repairDifficulty: data.systemData.repairDifficulty,
      rarity: data.systemData.rarity,
      //
      dmgDice: data.dmgDice,
      dmgDiceSides: data.dmgDiceSides,
      dmgBase: data.dmgBase,
      dmgType: data.dmgType,
      ego: data.ego,
      clipRate: data.clipRate,
      ammoType: data.ammoType,
      energyRate: data.energyRate,
      fireRate: data.fireRate,
      baseAccuracy: data.baseAccuracy,
      dmgRangeConfig: data.dmgRangeConfig,
      accuracyRangeConfig: data.accuracyRangeConfig,
      level: data.level,
      dmgMult: data.dmgMult,
      critConfig: data.critConfig,
    );
  }

  bool get usesAmmo => clipRate > 0;

  double fire(double dist, math.Random rnd, {Ship? targetShip, int? clips}) {
    double damage = 0;
    double hitRoll = rnd.nextDouble();
    //double effectiveAccuracy = baseAccuracy * accuracyRangeConfig.rangeMultiplier(dist);
    final effectiveAccuracy =
    (baseAccuracy * accuracyRangeConfig.rangeMultiplier(dist))
        .clamp(0.05, 0.95);
    bool hit = hitRoll < effectiveAccuracy;

    if (hit) {
      damage = _calcDamage(dist, rnd);
      double overhit = effectiveAccuracy - hitRoll;
      double critChance = math.min(
        1.0,
        critConfig.baseChance +
            (overhit * critConfig.accuracyScaling),
      );
      if (rnd.nextDouble() < critChance) {
        damage *= critConfig.severity;
      }
    }
    cooldown = fireRate;
    return damage;
  }

  double _calcDamage(double dist, math.Random rnd) {
    double dmg = ammo == null
      ? dmgBase + Rng.rollDice(dmgDice, dmgDiceSides, rnd) * dmgMult
      : (dmgBase + (rnd.nextDouble() * ammo!.avgDamage)) * dmgMult;
    //print("Gross damage: $dmg");
    //TODO: egos, etc.
    final netDamage = dmg * dmgRangeConfig.rangeMultiplier(dist); //print("Net damage: $netDamage");
    return netDamage;
  }

}

class WeaponData {
  final ShipSystemData systemData;
  final int dmgDice;
  final int dmgDiceSides;
  final int dmgBase;
  final double dmgMult;
  final DamageType dmgType;
  final WeaponEgo ego;
  final AmmoType? ammoType;
  final int clipRate; //unit of ammo per round of fire
  final int energyRate; //units of energy per round of fire
  final int fireRate; //aut to complete one round of fire
  final double baseAccuracy; //base chance to hit
  final RangeConfig dmgRangeConfig;
  final RangeConfig accuracyRangeConfig;
  final CritConfig critConfig;
  final Domain level;

  const WeaponData({
    required this.systemData,
    required this.dmgDice,
    required this.dmgDiceSides,
    required this.dmgBase,
    required this.dmgType,
    required this.energyRate,
    required this.fireRate,
    required this.baseAccuracy,
    required this.dmgRangeConfig,
    required this.accuracyRangeConfig,
    this.level = Domain.impulse,
    this.dmgMult = 1.0,
    this.critConfig = const CritConfig(),
    this.clipRate = 0,
    this.ammoType,
    this.ego = WeaponEgo.none,
  });
}

enum AmmoType {
  torpedo,missile,slug,particle
}

enum AmmoDamageType {
  plasma,fire,nuclear,antimatter
}

enum AmmoEgo {
  none, heatseeking,lightweight,fedbane
}

class Ammo extends Item {
  final AmmoType ammoType;
  final AmmoDamageType damageType;
  final double avgDamage;
  final double volitity;
  final AmmoEgo ego;
  final double mass;
  final int splashRad;
  final double splashFalloff;
  final int enchantment;
  final int maxEnchantment;

  Ammo(super.name, {
    required this.ammoType,
    required this.damageType,
    required this.avgDamage,
    required super.baseCost,
    this.splashRad = 0,
    this.splashFalloff = .5,
    this.volitity = .9,
    this.ego = AmmoEgo.none,
    this.mass = 1.0,
    this.enchantment= 0,
    this.maxEnchantment = 9,
    super.rarity = .01,
  });

  factory Ammo.fromStock(StockSystem stock) {
    final ammo = stockAmmo[stock]!;
    return Ammo(ammo.name,
        ammoType: ammo.ammoType,
        damageType: ammo.damageType,
        avgDamage: ammo.avgDamage,
        volitity: ammo.volitity,
        ego: ammo.ego,
        mass: ammo.mass,
        splashRad: ammo.splashRad,
        splashFalloff: ammo.splashFalloff,
        enchantment: ammo.enchantment,
        maxEnchantment: ammo.maxEnchantment,
        baseCost: ammo.baseCost
    );
  }
}
