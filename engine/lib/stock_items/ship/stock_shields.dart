import 'stock_pile.dart';
import '../../ship/systems/shields.dart';
import '../../ship/systems/ship_system.dart';

final Map<StockSystem, ShieldData> stockShields = {
  StockSystem.shdBasicEnergon: ShieldData(
    systemData: ShipSystemData.fromStock(StockSystem.shdBasicEnergon,"Basic Energon Shield",
        mass: 50, baseCost: 500, baseRepairCost: 2.5, powerDraw: 25),
      shieldType: ShieldType.energon,
      maxEnergy: 200,
      rechargeRate: .1,
      avgRecoveryTime: 100,
  ),
  StockSystem.shdMovEnergon: ShieldData(
    systemData: ShipSystemData.fromStock(StockSystem.shdMovEnergon,"Movelian Energon Shield",
        mass: 50, baseCost: 1000, baseRepairCost: 2.5, powerDraw: 30),
    shieldType: ShieldType.energon,
    maxEnergy: 300,
    rechargeRate: .2,
    avgRecoveryTime: 100,
  ),
  StockSystem.shdCassat: ShieldData(
    systemData: ShipSystemData.fromStock(StockSystem.shdCassat,"Cassat Fission Shield",
        mass: 50, baseCost: 1500, baseRepairCost: 2.5, powerDraw: 40),
    shieldType: ShieldType.fission,
    maxEnergy: 250,
    rechargeRate: .5,
    avgRecoveryTime: 100,
  ),
  StockSystem.shdRemlok: ShieldData(
    systemData: ShipSystemData.fromStock(StockSystem.shdRemlok,"Remlock Dark Matter Shield",
        mass: 50, baseCost: 2500, baseRepairCost: 2.5, powerDraw: 50),
    shieldType: ShieldType.darkMatter,
    maxEnergy: 500,
    rechargeRate: .1,
    avgRecoveryTime: 100,
  ),
  StockSystem.shdOrtegroq: ShieldData(
    systemData: ShipSystemData.fromStock(StockSystem.shdOrtegroq,"Ortegroq Gravimetric Shield",
        mass: 50, baseCost: 7500, baseRepairCost: 2.5, powerDraw: 80),
    shieldType: ShieldType.gravimetric,
    maxEnergy: 600,
    rechargeRate: .1,
    avgRecoveryTime: 100,
  ),
  StockSystem.shdKevlop: ShieldData(
    systemData: ShipSystemData.fromStock(StockSystem.shdKevlop,"Kevlok Fusion Shield",
        mass: 50, baseCost: 7500, baseRepairCost: 2.5, powerDraw: 120),
    shieldType: ShieldType.fusion,
    maxEnergy: 780,
    rechargeRate: .1,
    avgRecoveryTime: 100,
  ),
};

