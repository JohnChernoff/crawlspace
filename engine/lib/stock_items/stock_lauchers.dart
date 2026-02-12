import '../systems/ship_system.dart';
import '../systems/weapons.dart';
import 'stock_pile.dart';

final Map<StockSystem, WeaponData> stockLaunchers = {
  StockSystem.plasmaCannon:  WeaponData(
    systemData: ShipSystemData("Plasma Cannon",
        techLvl: StockSystem.plasmaCannon.techLvl, rarity: StockSystem.plasmaCannon.rarity,
        mass: 10, baseCost: 7500, baseRepairCost: 1.5, powerDraw: .5,
        slot: const SystemSlot(SystemSlotType.bauchmann,1)),
    dmgDice: 0, dmgDiceSides: 0, dmgBase: 0,
    dmgType: DamageType.plasma,
    dmgMult: 1,
    energyRate: 20,
    fireRate: 12,
    baseAccuracy: .8,
    clipRate: 1,
    dmgRangeConfig: const RangeConfig(idealRange: 2, minRange: 0, maxRange: 12, closeFalloff: .1, farFalloff: .1),
    accuracyRangeConfig: const RangeConfig(idealRange: 4, minRange: 0, maxRange: 8, closeFalloff: .1, farFalloff: .1),
    ammoType: AmmoType.slug,
  ),

  StockSystem.fedTorpLauncher: WeaponData(
    systemData: ShipSystemData("Fed Torp Mk 1",
        techLvl: StockSystem.fedTorpLauncher.techLvl, rarity: StockSystem.fedTorpLauncher.rarity,
        mass: 10, baseCost: 10000, baseRepairCost: 1.5, powerDraw: .5,
        slot: const SystemSlot(SystemSlotType.bauchmann,1)),
    dmgDice: 0, dmgDiceSides: 0, dmgBase: 0,
    dmgType: DamageType.kinetic,
    dmgMult: 2,
    energyRate: 20,
    fireRate: 10,
    baseAccuracy: .8,
    clipRate: 1,
    dmgRangeConfig: const RangeConfig(idealRange: 1, minRange: 0, maxRange: 8, closeFalloff: .1, farFalloff: .5),
    accuracyRangeConfig: const RangeConfig(idealRange: 1, minRange: 0, maxRange: 8, closeFalloff: .1, farFalloff: .33),
    ammoType: AmmoType.torpedo,
  ),
};

