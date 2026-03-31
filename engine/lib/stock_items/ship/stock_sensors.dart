import 'package:crawlspace_engine/galaxy/geometry/grid.dart';

import '../../ship/systems/sensors.dart';
import '../../ship/systems/ship_system.dart';
import 'stock_pile.dart';

final Map<StockSystem, SensorData> stockSensors = {
  StockSystem.senFed1: SensorData(
    systemData: ShipSystemData.fromStock(StockSystem.senFed1,"Mark I Fed System Sensor",
        about: "The original Federation system level sensor design - simple, straightforward, and generally nonexplosive.",
        mass: 20, baseCost: 3000, baseRepairCost: 2, powerDraw: 3),
    sensorType: SensorType.photonic,
    scope: {Domain.system : 12},
    accuracy: {Domain.system : .5},
  ),
  StockSystem.senLael1: SensorData(
    systemData: ShipSystemData.fromStock(StockSystem.senLael1,"Laventar System Sensor",
        about: "The original Laventar system sensor - still popular eons later after its initial run.",
        mass: 25, baseCost: 30000, baseRepairCost: 5, powerDraw: 8),
    sensorType: SensorType.quantum,
    scope: {Domain.system: 27},
    accuracy: {Domain.system : .8},
  ),
};