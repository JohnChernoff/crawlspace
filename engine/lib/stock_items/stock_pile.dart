import 'dart:math';
import '../item.dart';
import '../systems/engines.dart';
import '../systems/power.dart';
import '../systems/shields.dart';
import '../systems/ship_system.dart';
import '../systems/weapons.dart';

const maxTechLvl = 10;
enum StockSystem {
  engBasicFedImp(ShipSystemType.engine,1,.1),
  engBasicFedSub(ShipSystemType.engine,1,.1),
  engBasicFedHyper(ShipSystemType.engine,1,.1),
  engMovSub1(ShipSystemType.engine,3,.25),

  genBasicNuclear(ShipSystemType.power,1,.1),
  genZemlinsky(ShipSystemType.power,2,.25),
  genAojginx(ShipSystemType.power,4,.33),
  genGjellorny(ShipSystemType.power,5,.5),
  genBellauxfz(ShipSystemType.power,7,.75),

  shdBasicEnergon(ShipSystemType.shield,1,.1),
  shdMovEnergon(ShipSystemType.shield,2,.2),
  shdCassat(ShipSystemType.shield,3,.5),
  shdRemlok(ShipSystemType.shield,5,.66),
  shdOrtegroq(ShipSystemType.shield,7,.75),
  shdKevlop(ShipSystemType.shield,8,.9),

  wepFedLaser1(ShipSystemType.weapon,1,.1),
  wepFedLaser2(ShipSystemType.weapon,2,.1),
  wepFedLaser3(ShipSystemType.weapon,3,.1),
  wepPlasmaRay(ShipSystemType.weapon,4,.25),
  wepGravRifle(ShipSystemType.weapon,5,.33),
  wepVibraSlap(ShipSystemType.weapon,6,.5),
  wepNeuRad(ShipSystemType.weapon,7,.75),
  wepThermalLance(ShipSystemType.weapon,8,.75),
  wepQuarkSplitter(ShipSystemType.weapon,5,.75),
  wepGammapult(ShipSystemType.weapon,8,.75),
  wepCosmogripher(ShipSystemType.weapon,9,.75),
  webSingularitron(ShipSystemType.weapon,99,.75),


  lchfedTorpLauncher(ShipSystemType.launcher,1,.1),
  lchPlasmaCannon(ShipSystemType.launcher,2,.1),

  ammoFedTorp(ShipSystemType.ammo,1,.1),
  ammoPlasmaBall(ShipSystemType.ammo,2,.1),
  ;

  final ShipSystemType type;
  final int techLvl;
  final double rarity;
  const StockSystem(this.type,this.techLvl, this.rarity);

  Item createSystem() => switch(type) {
      ShipSystemType.power => PowerGenerator.fromStock(this),
      ShipSystemType.engine => Engine.fromStock(this),
      ShipSystemType.shield => Shield.fromStock(this),
      ShipSystemType.weapon => Weapon.fromStock(this),
      ShipSystemType.launcher => Weapon.fromStock(this),
      ShipSystemType.ammo => Ammo.fromStock(this),

      // TODO: Handle this case.
      ShipSystemType.quarters => throw UnimplementedError(),
      // TODO: Handle this case.
      ShipSystemType.powerConverter => throw UnimplementedError(),
      // TODO: Handle this case.
      ShipSystemType.sensor => throw UnimplementedError(),
      // TODO: Handle this case.
      ShipSystemType.unknown => throw UnimplementedError()
  };

}

List<StockSystem> generateSystemInventory(int n, List<ShipSystemType> types, int techLvl, Random rnd) {
  final systems = getSystemsByTech(types, techLvl); //.map((e) => e.createSystem()).asList();
  if (systems.isEmpty) return  techLvl > 0 ? generateSystemInventory(n, types, techLvl - 1, rnd) : [];
  final maxItems = min(n,systems.length);
  List<StockSystem> items = [];
  Set<StockSystem> sysList = {};
  do {
    final system = systems.elementAt(rnd.nextInt(systems.length));
    if (rnd.nextDouble() > system.rarity) {
      if (sysList.add(system)) { //print("Stock: ${system.name}");
        items.add(system);
      }
    }
  } while (items.length < maxItems);
  return items;
}

Iterable<StockSystem> getSystemsByTech(List<ShipSystemType> types, int techLvl) =>
    StockSystem.values.where((s) => types.contains(s.type) && s.techLvl <= techLvl);
