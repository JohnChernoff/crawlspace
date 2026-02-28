import 'stock_pile.dart';
import '../systems/shields.dart';
import '../systems/ship_system.dart';

final Map<StockSystem, ShieldData> stockShields = {
  StockSystem.shdBasicEnergon: ShieldData(
    systemData: ShipSystemData("Basic Energon Shield",
        techLvl: StockSystem.shdBasicEnergon.techLvl, rarity: StockSystem.shdBasicEnergon.rarity,
        mass: 50, baseCost: 500, baseRepairCost: 2.5, powerDraw: 2.5),
      shieldType: ShieldType.energon,
      maxEnergy: 200,
      rechargeRate: .001,
      avgRecoveryTime: 100,
  ),
  StockSystem.shdMovEnergon: ShieldData(
    systemData: ShipSystemData("Movelian Energon Shield",
        techLvl: StockSystem.shdMovEnergon.techLvl, rarity: StockSystem.shdMovEnergon.rarity,
        mass: 50, baseCost: 1000, baseRepairCost: 2.5, powerDraw: 3),
    shieldType: ShieldType.energon,
    maxEnergy: 300,
    rechargeRate: .002,
    avgRecoveryTime: 100,
  ),
  StockSystem.shdCassat: ShieldData(
    systemData: ShipSystemData("Cassat Fission Shield",
        techLvl: StockSystem.shdCassat.techLvl, rarity: StockSystem.shdCassat.rarity,
        mass: 50, baseCost: 1500, baseRepairCost: 2.5, powerDraw: 4),
    shieldType: ShieldType.fission,
    maxEnergy: 250,
    rechargeRate: .005,
    avgRecoveryTime: 100,
  ),
  StockSystem.shdRemlok: ShieldData(
    systemData: ShipSystemData("Remlock Dark Matter Shield",
        techLvl: StockSystem.shdRemlok.techLvl, rarity: StockSystem.shdRemlok.rarity,
        mass: 50, baseCost: 2500, baseRepairCost: 2.5, powerDraw: 5),
    shieldType: ShieldType.darkMatter,
    maxEnergy: 500,
    rechargeRate: .001,
    avgRecoveryTime: 100,
  ),
  StockSystem.shdOrtegroq: ShieldData(
    systemData: ShipSystemData("Ortegroq Gravimetric Shield",
        techLvl: StockSystem.shdKevlop.techLvl, rarity: StockSystem.shdKevlop.rarity,
        mass: 50, baseCost: 7500, baseRepairCost: 2.5, powerDraw: 8),
    shieldType: ShieldType.gravimetric,
    maxEnergy: 600,
    rechargeRate: .001,
    avgRecoveryTime: 100,
  ),
  StockSystem.shdKevlop: ShieldData(
    systemData: ShipSystemData("Kevlok Fusion Shield",
        techLvl: StockSystem.shdKevlop.techLvl, rarity: StockSystem.shdKevlop.rarity,
        mass: 50, baseCost: 7500, baseRepairCost: 2.5, powerDraw: 12),
    shieldType: ShieldType.fusion,
    maxEnergy: 780,
    rechargeRate: .001,
    avgRecoveryTime: 100,
  ),
};

