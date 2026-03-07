import '../../ship/systems/weapons.dart';
import 'stock_pile.dart';

enum StockAmmo {plasmaCannon, fedTorp1}

final Map<StockSystem, Ammo> stockAmmo = {
  StockSystem.ammoPlasmaBall: Ammo("plasma blob",
      ammoType: AmmoType.slug,
      damageType: AmmoDamageType.plasma,
      avgDamage: 360,
      baseCost: 50
  ),

  StockSystem.ammoFedTorp: Ammo("Fed Mk 1 Torpedo",
      ammoType: AmmoType.torpedo,
      damageType: AmmoDamageType.nuclear,
      avgDamage: 480,
      baseCost: 60
  ),
};