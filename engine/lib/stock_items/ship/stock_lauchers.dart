import '../../ship/systems/ship_system.dart';
import '../../ship/systems/weapons.dart';
import 'stock_pile.dart';

final Map<StockSystem, WeaponData> stockLaunchers = {
  StockSystem.lchPlasmaCannon:  WeaponData(
    systemData: ShipSystemData.fromStock(StockSystem.lchPlasmaCannon,"Plasma Cannon",
        mass: 10, baseCost: 7500, baseRepairCost: 1.5, powerDraw: .5),
    dmgDice: 0, dmgDiceSides: 0, dmgBase: 0,
    dmgType: DamageType.plasma,
    dmgMult: 1,
    energyRate: 20,
    fireRate: 12,
    baseAccuracy: .8,
    clipRate: 1,
    accel: 2,
    ammoType: AmmoType.slug,
  ),

  StockSystem.lchfedTorpLauncher: WeaponData(
    systemData: ShipSystemData.fromStock(StockSystem.lchfedTorpLauncher,"Fed Torp Mk 1",
        mass: 10, baseCost: 10000, baseRepairCost: 1.5, powerDraw: .5),
    dmgDice: 0, dmgDiceSides: 0, dmgBase: 0,
    dmgType: DamageType.kinetic,
    dmgMult: 2,
    energyRate: 20,
    fireRate: 10,
    baseAccuracy: .8,
    clipRate: 1,
    accel: 1,
    ammoType: AmmoType.torpedo,
  ),
};

