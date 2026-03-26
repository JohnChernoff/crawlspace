import 'package:collection/collection.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/ship_sys.dart';
import 'package:crawlspace_engine/ship/systems/sensors.dart';
import '../item.dart';
import '../galaxy/geometry/location.dart';
import '../actors/pilot.dart';
import '../stock_items/stock_ships.dart';
import 'systems/engines.dart';
import 'systems/power.dart';
import 'systems/shields.dart';
import 'systems/ship_system.dart';
import 'systems/weapons.dart';

class HangarShip extends Item {
  @override
  int get baseCost => inventory.all.map((i) => i.baseCost).sum + shipClass.volume.round();
  @override
  String get shopDesc => dump(shop: true);
  ShipClass shipClass;
  Pilot? owner;
  Inventory<Item> inventory = Inventory();
  InventoryView<Scrap> get scrapHeap => inventory.filterType<Scrap>();
  InventoryView get cargo => inventory.filter((i) => i is! ShipSystem || !systemControl.isInstalled(i));

  List<ShipSystemType> multiSystems = [
    ShipSystemType.engine,
    ShipSystemType.weapon,
    ShipSystemType.launcher,
    ShipSystemType.ammo,
    ShipSystemType.quarters];
  late ShipSystemControl systemControl;
  late Hull hull;
  double get volume => shipClass.volume;
  double get maxSpeed =>  hull.material.speedMult * shipClass.maxSpeed; // sqrt(volume * mass));

  HangarShip(super.name, {
    this.owner,
    super.baseCost = 0,
    super.rarity = 1,
    required this.shipClass,
    PowerGenerator? generator,
    List<Weapon>? weapons,
    Map<Ammo,int>? ammo,
    Shield? shield,
    Engine? impEngine,
    Engine? subEngine,
    Engine? hyperEngine,
    Sensor? sensor,
    HullMaterial hullMaterial = HullMaterial.basic}) {
    hull = Hull.fromMaterial(hullMaterial,this);
    systemControl = ShipSystemControl(this);
    install(generator);
    install(hyperEngine, active: false);
    install(subEngine);
    install(impEngine,active: false);
    install(shield);
    for (final w in weapons ?? []) {
      install(w);
    }
    for (final a in (ammo ?? {}).entries) {
      systemControl.addAmmo(a.key, a.value, setWeapon: true);
    }
    install(sensor);
  }

  factory HangarShip.toHangar(Ship s) => HangarShip(s.name, shipClass: s.shipClass);

  double get currentMass {
    double m = 0;
    for (final a in systemControl.ammo) {
      m += a.count * a.ammo.mass;
    }
    return inventory.all.fold<double>(0.0, (sum, s) => sum + s.mass) + m + shipClass.mass;
  }

  double get currentVolume {
    double m = 0;
    for (final a in systemControl.ammo) {
      m += a.count * a.ammo.volume;
    }
    return inventory.all.fold<double>(0.0, (sum, s) => sum + s.volume) + m;
  }

  double get availableSpace => shipClass.volume - currentVolume;
  bool okVolume(double m) => availableSpace > m;

  void install(ShipSystem? system, {bool active = true}) {
    if (system != null) {
      addToInventory(system);
      final report = systemControl.installSystem(system);
      if (report.result == InstallResult.success) systemControl.toggleSystem(system, on: active);
      else print("Error installing ${system.name}: ${report.result.name}");
    }
  }

  bool addToInventory(Item i) {
    if (availableSpace < i.mass) return false;
    inventory.add(i);
    return true;
  }

  String dump({shop = false}) {
    StringBuffer sb = StringBuffer();
    if (!shop) {
      sb.writeln(name);
      sb.writeln(shipClass.name);
    }
    else {
      sb.writeln("${shipClass.name} Class Starship");
    }
    for (final system in systemControl.systemMap) {
      ShipSystem? s = system.system; if (s != null) {
        sb.write("${s.name} ");
        if (!shop) sb.write(s.active ? '+' : '-');
        if (s is Weapon && s.ammo != null) {
          sb.write(", ${s.ammo!.name}: ${systemControl.ammoFor(s.ammo!)}");
        }
        if (shop) sb.writeln();
      } else if (!shop) {
        sb.write("Empty");
      }
      if (!shop) sb.writeln(", Slot: ${system.slot}");
    }
    return sb.toString();
  }
}