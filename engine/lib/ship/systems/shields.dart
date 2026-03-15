import 'package:crawlspace_engine/ship/systems/weapons.dart';
import '../../stock_items/ship_systems/stock_pile.dart';
import '../../stock_items/ship_systems/stock_shields.dart';
import 'power.dart';
import 'ship_system.dart';

mixin Resisting {
  Set<Resistance> get resists;

  double getResistance(DamageType type) {
    double r = 0;
    for (final res in resists) {
      if (res.type == type || res.type == DamageType.all) {
        r += res.level;
      }
    }
    return r;
  }
}

class Resistance {
  final double level;
  final DamageType type;

  const Resistance(this.type, {this.level = 1});

  static const none = Resistance(DamageType.none);
}

enum ShieldType with Resisting {
  fusion({Resistance(DamageType.kinetic)}),
  fission({Resistance(DamageType.ion)}),
  energon({Resistance(DamageType.photonic)}),
  gravimetric({Resistance(DamageType.gravitron)}),
  nullSpace({Resistance(DamageType.etherial)}),
  darkMatter({
    Resistance(DamageType.neutrino),
    Resistance(DamageType.fire),
    Resistance(DamageType.plasma),
  });

  @override
  final Set<Resistance> resists;

  const ShieldType(this.resists);
}

enum ShieldEgo with Resisting {
  endurance({}), recharging({}), spike({}), absorption({}), phase({}), block({}), deflector({}),
  reflector({Resistance(DamageType.photonic)}),
  resistance({Resistance(DamageType.photonic), Resistance(DamageType.all)}),
  ionSink({Resistance(DamageType.ion)});

  @override
  final Set<Resistance> resists;

  const ShieldEgo(this.resists);
}

class ShieldState {
  int blockCooldown = 0;
  int phaseCooldown = 0;
}

class Shield extends RechargableShipSystem {
  final ShieldType shieldType;
  ShieldState state = ShieldState();
  final Set<ShieldEgo> egos;

  double resistance(DamageType type) {
    double r = shieldType.getResistance(type);
    for (final e in egos) {
      r += e.getResistance(type);
    }
    return r;
  }

  @override
  ShipSystemType get type => ShipSystemType.shield;

  Shield(super.name,{
    this.egos = const {},
    required this.shieldType,
    required super.maxEnergy,
    required super.rechargeRate,
    required super.avgRecoveryTime,
    required super.baseCost,
    required super.baseRepairCost,
    required super.powerDraw,
    required super.mass,
    required super.about,
    super.manufacturer,
    super.rarity,
    super.stability,
    super.repairDifficulty,
  });

  factory Shield.fromStock(StockSystem stock) {
    ShieldData data = stockShields[stock]!;
    return Shield(
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
      shieldType: data.shieldType,
      maxEnergy: data.maxEnergy,
      rechargeRate: data.rechargeRate,
      avgRecoveryTime: data.avgRecoveryTime
    );
  }
}

class ShieldData {
  final ShipSystemData systemData;
  final double maxEnergy;
  final double rechargeRate;
  final int avgRecoveryTime;
  final ShieldType shieldType;
  final Set<ShieldEgo> ego;

  const ShieldData({
    required this.systemData,
    required this.maxEnergy,
    required this.rechargeRate,
    required this.avgRecoveryTime,
    required this.shieldType,
    this.ego = const {},
  });
}