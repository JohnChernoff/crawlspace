import 'stock_pile.dart';
import '../../ship/systems/power.dart';
import '../../ship/systems/ship_system.dart';

// Generator sizing rationale:
// Basic fed impulse engine costs thrust/efficiency = 1000/0.5 = 2000 energy/move.
// We want ~5 full-thrust moves before the tank runs dry (ignoring recharge),
// so maxEnergy ≈ 5 * 2000 = 10000 for a ship running one engine.
// rechargeRate stays at 0.02 so recharge per aut = 10000 * 0.02 = 200/aut.
// At 9 auts/move that's 1800 regenerated vs 2000 spent — a mild net drain
// under sustained full-thrust travel, which is the right feel.
// Better generators have higher maxEnergy and/or rechargeRate.
final Map<StockSystem, PowerData> stockPPs = {
  StockSystem.genBasicNuclear: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genBasicNuclear,
        "Mark I Fed Power Plant",
        mass: 75, baseCost: 250, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.nuclear,
    maxEnergy: 10000,
    rechargeRate: 0.02,
    avgRecoveryTime: 10,
  ),
  StockSystem.genZemlinsky: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genZemlinsky,
        "Zemlinsky Antimatter Power Plant",
        mass: 75, baseCost: 500, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.antimatter,
    maxEnergy: 15000,
    rechargeRate: 0.02,
    avgRecoveryTime: 10,
  ),
  StockSystem.genAojginx: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genAojginx,
        "Aogjinx Dark Matter Power Plant",
        mass: 75, baseCost: 1000, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.dark,
    maxEnergy: 20000,
    rechargeRate: 0.03,
    avgRecoveryTime: 10,
  ),
  StockSystem.genBellauxfz: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genBellauxfz,
        "Bellauxfz Quantum Power Plant",
        mass: 75, baseCost: 2500, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.quantum,
    maxEnergy: 30000,
    rechargeRate: 0.04,
    avgRecoveryTime: 10,
  ),
  StockSystem.genGjellorny: PowerData(
    systemData: ShipSystemData.fromStock(StockSystem.genGjellorny,
        "Gjellorny Multiplanar Power Plant",
        mass: 75, baseCost: 5000, baseRepairCost: 1, powerDraw: 0),
    powerType: PowerType.astral,
    maxEnergy: 50000,
    rechargeRate: 0.05,
    avgRecoveryTime: 10,
  ),
};
