import '../ship.dart';
import '../systems/ship_system.dart';
import '../systems/weapons.dart';

enum HullType {
  basic([],1),
  ablative([HullResistance(DamageType.kinetic,.5)],2),
  refractive([HullResistance(DamageType.photonic,.33)],2.5),
  crystalline([
    HullResistance(DamageType.kinetic,.66),
    HullResistance(DamageType.plasma,.25),
  ],5),
  hypercarbon([
    HullResistance(DamageType.fire,.66),
    HullResistance(DamageType.plasma,.5),
    HullResistance(DamageType.sonic,.5),
  ],6.6);
  final List<HullResistance> resistances;
  final double baseRepairCost; //in kilos
  const HullType(this.resistances,this.baseRepairCost);
}

//TODO: create Alien/Family class, strength based on prox. to their assigned homeworld

class ShipClass {
  final String name;
  final ShipType type;
  final List<ShipClassSlot> slots;
  final double maxMass;
  const ShipClass(this.name,this.type,this.slots,this.maxMass);
}

enum ShipType { //TODO: shipshapes
  scout(.1),skiff(.3),cruiser(.5),destroyer(.66),interceptor(.75),battleship(.9),flagship(1),unknown(0);
  final double dangerLvl;
  const ShipType(this.dangerLvl);
}

enum ShipPrefs {
  all({}),
  standard({
    ShipType.scout: 1,
    ShipType.skiff: .8,
    ShipType.cruiser: .6,
    ShipType.destroyer: .4,
    ShipType.interceptor: .3,
    ShipType.battleship: .2,
    ShipType.flagship: .1
  });
  final Map<ShipType,double> shipWeights;
  const ShipPrefs(this.shipWeights);
}

enum ShipClassType {
  mentok(ShipClass("Mentok",ShipType.scout,
      [ShipClassSlot(SystemSlot(SystemSlotType.generic,1),8)],
      500
  )),
  hermes(ShipClass("Hermes",ShipType.skiff,
      [
        ShipClassSlot(SystemSlot(SystemSlotType.generic,1),6),
        ShipClassSlot(SystemSlot(SystemSlotType.tanaka,1),1),
        ShipClassSlot(SystemSlot(SystemSlotType.sinclair,1),1),
      ],
      750)),
  orion(ShipClass("Orion",ShipType.cruiser,
      [
        ShipClassSlot(SystemSlot(SystemSlotType.generic,1),4),
        ShipClassSlot(SystemSlot(SystemSlotType.nimrod,1),3),
        ShipClassSlot(SystemSlot(SystemSlotType.tanaka,1),1),
      ],
      5000)),
  balrog(ShipClass("Balrog",ShipType.battleship,
      [
        ShipClassSlot(SystemSlot(SystemSlotType.generic,1),4),
        ShipClassSlot(SystemSlot(SystemSlotType.nimrod,1),3),
        ShipClassSlot(SystemSlot(SystemSlotType.tanaka,2),1),
        ShipClassSlot(SystemSlot(SystemSlotType.gregoriev,1),1),
      ],
      7500)),
  galaxy(ShipClass("Galaxy",ShipType.flagship,
      [
        ShipClassSlot(SystemSlot(SystemSlotType.generic,1),4),
        ShipClassSlot(SystemSlot(SystemSlotType.bauchmann,4),4),
        ShipClassSlot(SystemSlot(SystemSlotType.sinclair,2),4),
      ],
      10000
  ));
  final ShipClass shipclass;
  const ShipClassType(this.shipclass);
}