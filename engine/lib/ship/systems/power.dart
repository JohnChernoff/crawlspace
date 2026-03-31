import 'dart:math';
import '../../stock_items/ship/stock_pile.dart';
import '../../stock_items/ship/stock_power.dart';
import 'ship_system.dart';

enum PowerType {
  nuclear,antimatter,quantum,dark,astral
}

enum PowerEgo {
  none,nebular,ionic,gravimetric,stable,efficient
}

abstract class RechargableShipSystem extends ShipSystem {
  final double _maxEnergy;
  double _currentEnergy;
  double rechargeRate; //% per aut
  int avgRecoveryTime; //in auts

  RechargableShipSystem(super.name, {
    required double maxEnergy,
    required this.rechargeRate,
    required this.avgRecoveryTime,
    required super.baseCost,
    required super.baseRepairCost,
    required super.mass,
    required super.powerDraw,
    required super.about,
    super.manufacturer,
    super.rarity,
    super.stability,
    super.repairDifficulty,
  }) : _maxEnergy = maxEnergy, _currentEnergy = maxEnergy;

  double recharge(double amount) {
    double prevEnergy = _currentEnergy; //ignore damage
    double newEnergy = min(_currentEnergy + amount,_maxEnergy);
    _currentEnergy = newEnergy;
    return _currentEnergy - prevEnergy;
  }

  double burn(double e, {partial = false}) {
    if (!partial) {
      if (currentEnergy >= e) {
        _currentEnergy -= e; return e;
      } return 0;
    } else {
      double partialBurn = min(_currentEnergy,e);
      _currentEnergy -= partialBurn;
      return partialBurn;
    }
  }

  double get rawMaxEnergy => _maxEnergy;
  double get currentMaxEnergy => _maxEnergy * (1-damage);
  double get rawEnergy => _currentEnergy;
  double get currentEnergy => _currentEnergy * (1-damage);
}

class PowerGenerator extends RechargableShipSystem {
  PowerType powerType;
  PowerEgo ego;

  @override
  ShipSystemType get type => ShipSystemType.power;

  PowerGenerator(super.name, {
    required super.maxEnergy,
    required this.powerType,
    this.ego = PowerEgo.none,
    required super.rechargeRate,
    required super.avgRecoveryTime,
    required super.baseCost,
    required super.baseRepairCost,
    required super.mass,
    required super.powerDraw,
    required super.about,
    super.manufacturer,
    super.rarity,
    super.stability,
    super.repairDifficulty,
  });

  factory PowerGenerator.fromStock(StockSystem stock) {
    final data = stockPPs[stock]!;
    return PowerGenerator(
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
      powerType: data.powerType,
      maxEnergy: data.maxEnergy,
      rechargeRate: data.rechargeRate,
      avgRecoveryTime: data.avgRecoveryTime
    );
  }
}

class PowerData {
  final ShipSystemData systemData;
  final PowerType powerType;
  final double maxEnergy;
  final double rechargeRate;
  final int avgRecoveryTime;

  const PowerData({
    required this.systemData,
    required this.powerType,
    required this.maxEnergy,
    required this.rechargeRate,
    required this.avgRecoveryTime
  });
}