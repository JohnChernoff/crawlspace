import '../../galaxy/geometry/grid.dart';
import '../../stock_items/ship_systems/stock_pile.dart';
import '../../stock_items/ship_systems/stock_sensors.dart';
import 'ship_system.dart';

enum SensorEgo {
  none(),
  nebulizer(),
  supercharged();
}

enum SensorType {
  photonic,
  quantum,
  etherial,
  gravimetric,
}

class Sensor extends ShipSystem {
  Map<Domain,int> scope;
  Map<Domain,double> accuracy;
  SensorType sensorType;
  SensorEgo ego;

  @override
  String get description {
    StringBuffer sb = StringBuffer();
    sb.writeln(flavor);
    sb.writeln();
    sb.writeln("Scope: $scope");
    sb.writeln("Accuracy: $accuracy");
    sb.writeln(super.description);
    return sb.toString();
  }

  @override
  ShipSystemType get type => ShipSystemType.sensor;

  Sensor(super.name, {
    super.manufacturer,
    super.rarity,
    super.stability,
    super.repairDifficulty,
    required this.sensorType,
    this.ego = SensorEgo.none,
    required this.scope,
    required this.accuracy,
    required super.baseCost,
    required super.baseRepairCost,
    required super.powerDraw,
    required super.mass,
    required super.about,
  });

  factory Sensor.fromStock(StockSystem stock) {
    SensorData data = stockSensors[stock]!;
    return Sensor(
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
      sensorType: data.sensorType,
      ego: data.ego,
      accuracy: data.accuracy,
      scope: data.scope,
    );
  }
}

class SensorData {
  final ShipSystemData systemData;
  final Map<Domain,int> scope;
  final Map<Domain,double> accuracy;
  final SensorType sensorType;
  final SensorEgo ego;

  const SensorData({
    required this.systemData,
    required this.accuracy,
    required this.scope,
    required this.sensorType,
    this.ego = SensorEgo.none
  });
}


