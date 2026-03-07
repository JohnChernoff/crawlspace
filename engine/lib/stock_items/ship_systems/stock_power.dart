import 'stock_pile.dart';
import '../../ship/systems/power.dart';
import '../../ship/systems/ship_system.dart';

final Map<StockSystem, PowerData> stockPPs = {
  StockSystem.genBasicNuclear: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genBasicNuclear,"Mark I Fed Power Plant",
        mass: 75, baseCost: 250, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.nuclear,
    maxEnergy: 500,
    rechargeRate: 0.02,
    avgRecoveryTime: 10,
  ),
  StockSystem.genZemlinsky: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genZemlinsky,"Zemlinsky Antimatter Power Plant",
        mass: 75, baseCost: 500, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.antimatter,
    maxEnergy: 750,
    rechargeRate: 0.02,
    avgRecoveryTime: 10,
  ),
  StockSystem.genAojginx: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genAojginx,"Aogjinx Dark Matter Power Plant",
        mass: 75, baseCost: 1000, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.dark,
    maxEnergy: 900,
    rechargeRate: 0.03,
    avgRecoveryTime: 10,
  ),
  StockSystem.genBellauxfz: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genBellauxfz,"Bellauxfz Quantum Power Plant",
        mass: 75, baseCost: 2500, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.quantum,
    maxEnergy: 1500,
    rechargeRate: 0.04,
    avgRecoveryTime: 10,
  ),
  StockSystem.genGjellorny: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genGjellorny,"Gjellorny Multiplanar Power Plant",
        mass: 75, baseCost: 5000, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.astral,
    maxEnergy: 2000,
    rechargeRate: 0.05,
    avgRecoveryTime: 10,
  ),
};
