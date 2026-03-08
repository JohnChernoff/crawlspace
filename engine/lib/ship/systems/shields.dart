import 'package:crawlspace_engine/ship/systems/weapons.dart';
import '../../stock_items/ship_systems/stock_pile.dart';
import '../../stock_items/ship_systems/stock_shields.dart';
import 'power.dart';
import 'ship_system.dart';

class Resistance {
  final level;
  final DamageType type;
  const Resistance(this.type,{this.level = 1});
  static const none = Resistance(DamageType.none);
}

enum ShieldType {
  fusion({Resistance(DamageType.kinetic)}),
  fission({Resistance(DamageType.ion)}),
  energon({Resistance(DamageType.photonic)}),
  gravimetric({Resistance(DamageType.gravitron)}),
  nullSpace({Resistance(DamageType.etherial)}),
  darkMatter({Resistance(DamageType.neutrino),Resistance(DamageType.fire),Resistance(DamageType.plasma)});
  final Set<Resistance> resists;
  const ShieldType(this.resists);
}

enum ShieldEgo {
  none, endurance, recharging, spike, reflector, absorption
}

class Shield extends RechargableShipSystem {
  final ShieldType shieldType;
  final ShieldEgo ego;

  @override
  ShipSystemType get type => ShipSystemType.shield;

  Shield(super.name,{
    this.ego = ShieldEgo.none,
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
  final ShieldEgo ego;

  const ShieldData({
    required this.systemData,
    required this.maxEnergy,
    required this.rechargeRate,
    required this.avgRecoveryTime,
    required this.shieldType,
    this.ego = ShieldEgo.none,
  });
}