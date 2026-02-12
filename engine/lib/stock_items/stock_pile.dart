import 'dart:math';
import '../item.dart';
import '../systems/engines.dart';
import '../systems/power.dart';
import '../systems/shields.dart';
import '../systems/ship_system.dart';
import '../systems/weapons.dart';

enum StockSystem {
  basicFedImpulse(ShipSystemType.engine,1,.1),
  basicFedSublight(ShipSystemType.engine,1,.1),
  basicFedHyperdrive(ShipSystemType.engine,1,.1),
  movSublight1(ShipSystemType.engine,1,.1),

  basicNuclear(ShipSystemType.power,1,.1),
  zemlinsky(ShipSystemType.power,1,.1),
  aojginx(ShipSystemType.power,1,.1),
  gjellorny(ShipSystemType.power,1,.1),
  bellauxfz(ShipSystemType.power,1,.1),

  basicEnergon(ShipSystemType.shield,1,.1),
  movEnergon(ShipSystemType.shield,1,.1),
  cassat(ShipSystemType.shield,1,.1),
  remlok(ShipSystemType.shield,1,.1),
  ortegroq(ShipSystemType.shield,1,.1),
  kevlop(ShipSystemType.shield,1,.1),

  fedLaser1(ShipSystemType.weapon,1,.1),
  fedLaser2(ShipSystemType.weapon,1,.1),
  fedLaser3(ShipSystemType.weapon,1,.1),
  plasmaRay(ShipSystemType.weapon,1,.1),
  gravRifle(ShipSystemType.weapon,1,.1),
  vibraSlap(ShipSystemType.weapon,1,.1),
  neuRad(ShipSystemType.weapon,1,.1),
  thermalLance(ShipSystemType.weapon,1,.1),

  plasmaCannon(ShipSystemType.launcher,1,.1),
  fedTorpLauncher(ShipSystemType.launcher,1,.1),

  plasmaBall(ShipSystemType.ammo,1,.1),
  fedTorp(ShipSystemType.ammo,1,.1),
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

List<Item> generateInventory(int n, List<ShipSystemType> types, int techLvl, Random rnd) {
  final systems = StockSystem.values.where((s) => types.contains(s.type) && s.techLvl >= techLvl); //.map((e) => e.createSystem()).asList();
  final maxItems = min(n,systems.length);
  List<Item> items = [];
  Set<StockSystem> sysList = {};
  do {
    final system = systems.elementAt(rnd.nextInt(systems.length));
    if (rnd.nextDouble() > system.rarity) {
      if (sysList.add(system)) { //print("Stock: ${system.name}");
        items.add(system.createSystem());
      }
    }
  } while (items.length < maxItems);
  return items;
}
