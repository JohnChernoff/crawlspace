import 'stock_pile.dart';
import '../systems/power.dart';
import '../systems/ship_system.dart';

final Map<StockSystem, PowerData> stockPPs = {
  StockSystem.genBasicNuclear: PowerData(
    systemData: ShipSystemData("Mark I Fed Power Plant",
        techLvl: StockSystem.shdBasicEnergon.techLvl, rarity: StockSystem.shdBasicEnergon.rarity,
        mass: 75, baseCost: 250, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.nuclear,
    maxEnergy: 500,
    rechargeRate: 0.02,
    avgRecoveryTime: 10,
  ),
  StockSystem.genZemlinsky: PowerData(
    systemData: ShipSystemData("Zemlinsky Antimatter Power Plant",
        techLvl: StockSystem.genZemlinsky.techLvl, rarity: StockSystem.genZemlinsky.rarity,
        mass: 75, baseCost: 500, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.antimatter,
    maxEnergy: 750,
    rechargeRate: 0.02,
    avgRecoveryTime: 10,
  ),
  StockSystem.genAojginx: PowerData(
    systemData: ShipSystemData("Aogjinx Dark Matter Power Plant",
        techLvl: StockSystem.genAojginx.techLvl, rarity: StockSystem.genAojginx.rarity,
        mass: 75, baseCost: 1000, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.dark,
    maxEnergy: 900,
    rechargeRate: 0.03,
    avgRecoveryTime: 10,
  ),
  StockSystem.genBellauxfz: PowerData(
    systemData: ShipSystemData("Bellauxfz Quantum Power Plant",
        techLvl: StockSystem.genBellauxfz.techLvl, rarity: StockSystem.genBellauxfz.rarity,
        mass: 75, baseCost: 2500, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.quantum,
    maxEnergy: 1500,
    rechargeRate: 0.04,
    avgRecoveryTime: 10,
  ),
  StockSystem.genGjellorny: PowerData(
    systemData: ShipSystemData("Gjellorny Multiplanar Power Plant",
        techLvl: StockSystem.genGjellorny.techLvl, rarity: StockSystem.genGjellorny.rarity,
        mass: 75, baseCost: 5000, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.astral,
    maxEnergy: 2000,
    rechargeRate: 0.05,
    avgRecoveryTime: 10,
  ),
};
