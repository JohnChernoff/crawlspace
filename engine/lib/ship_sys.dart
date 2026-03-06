import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/stock_items/corps.dart';
import 'package:crawlspace_engine/systems/engines.dart';
import 'package:crawlspace_engine/systems/power.dart';
import 'package:crawlspace_engine/systems/shields.dart';
import 'package:crawlspace_engine/systems/ship_system.dart';
import 'package:crawlspace_engine/systems/weapons.dart';
import 'fugue_engine.dart';
import 'grid.dart';

enum InstallResult {success,unsupported,duplicate}

class ShipSystemControl {
  Ship ship;
  List<SlotAssignment> systemMap = [];
  Map<Ammo,int> ammoMap = {};

  ShipSystemControl(this.ship) {
    print(ship.name);
    print(ship.shipClass.name);
    for (final classSlot in ship.shipClass.slots.all) { //print("Adding slot: ${classSlot.name}");
      systemMap.add(SlotAssignment(classSlot,null));
    }
  }

  Iterable<SlotAssignment> get slots => systemMap;
  int ammoFor(Ammo a) => ammoMap[a] ?? 0;
  Iterable<({Ammo ammo, int count})> get ammo => ammoMap.entries.map((a) => (ammo: a.key, count: a.value));
  Iterable<ShipSystem> get uninstalledSystems => ship.inventory.all.whereType<ShipSystem>().where((s) => !isInstalled(s));
  Iterable<SlotAssignment> get vacantSlots => systemMap.where((sys) => sys.system == null);

  Engine? get engine => getEngine(ship.loc.domain);
  Engine? getEngine(Domain domain, {activeOnly = true}) {
    return getInstalledSystems().whereType<Engine>().where((s) => s.domain == domain && (!activeOnly || s.active)).firstOrNull;
  }

  Shield? getShield({activeOnly = true}) => getShields(activeOnly: activeOnly).firstOrNull;
  Iterable<Shield> getShields({activeOnly = true}) => getInstalledSystems().whereType<Shield>().where((s) => (!activeOnly || s.active));

  PowerGenerator? getPower({activeOnly = true}) => getPowers(activeOnly: activeOnly).firstOrNull;
  Iterable<PowerGenerator> getPowers({activeOnly = true}) => getInstalledSystems().whereType<PowerGenerator>().where((s) => (!activeOnly || s.active));

  Weapon? get primaryWeapon => availableWeapons.sorted((w1,w2) => w1.baseCost - w2.baseCost).firstOrNull;
  Iterable<Weapon> getWeapons({activeOnly = true}) => getInstalledSystems().whereType<Weapon>().where((s) => (!activeOnly || s.active));

  Iterable<RechargableShipSystem> get rechargables => getInstalledSystems().whereType<RechargableShipSystem>().where((s) => s.active);
  Iterable<ShipSystem> get activeSystems => getInstalledSystems().where((s) => s.active);
  bool duplicateInstallation(ShipSystem s) => !ship.multiSystems.contains(s.type) && getInstalledSystems().any((sys) => sys.type == s.type);
  bool isInstalled(ShipSystem s) => getInstalledSystems().contains(s);
  Iterable<SlotAssignment> exactSlots(SystemSlot s) => vacantSlots.where((as) => as.slot == s).toList();
  Iterable<SlotAssignment> availableSlots(ShipSystemType type,Corporation corp) => vacantSlots.where((i) => i.slot.supports(type,corp));
  Iterable<SlotAssignment> availableSlotsbySystem(ShipSystem s) => vacantSlots.where((vs) => canInstall(s,vs) == InstallResult.success);
  InstallResult canInstall(ShipSystem s, SlotAssignment assignment) {
    if (duplicateInstallation(s)) return InstallResult.duplicate;
    glog("Checking if ${s.name},${s.type},${s.manufacturer} can be installed at: "
        "${assignment.system},${assignment.slot.systemType},${assignment.slot.manufacturer}",level: DebugLevel.Finer);
    if (assignment.slot.supports(s.type,s.manufacturer)) {
      return InstallResult.success;
    }
    return InstallResult.unsupported;
  }
  double get currentShieldStrength => ship.multiSystems.contains(ShipSystemType.shield)
      ? getShields().where((s) => s.currentEnergy > 0).firstOrNull?.currentEnergy ?? 0
      : getShield()?.currentEnergy ?? 0;

  bool ammoOK(Weapon weapon) => ammoMap.containsKey(weapon.ammo) && ammoMap[weapon.ammo]! > 0;

  int fireAmmoRound(Weapon weapon) {
    final prevAmmo = ammoMap[weapon.ammo]!;
    final newAmmo = max(prevAmmo - weapon.clipRate,0);
    ammoMap[weapon.ammo!] = newAmmo;
    return prevAmmo - newAmmo;
  }

  void toggleSystem(ShipSystem? s, {bool? on}) {
    if (s != null) {
      if (on == null) s.active = !s.active; else s.active = on;
    }
  }

  bool burnEnergy(double e) {
    if (ship.multiSystems.contains(ShipSystemType.power)) {
      for (final gen in getPowers()) {
        if (gen.burn(e,partial: false) > 0) { //print("Burning: $e");
          return true;
        }
      }
    } else {
      return ((getPower()?.burn(e,partial: false) ?? 0) > 0);
    }
    return false;
  }

  Iterable<ShipSystem> getInstalledSystems({List<ShipSystemType>? types}) {
    if (types != null) return systemMap.where((s) => types.contains(s.system?.type)).map((i) => i.system!);
    return systemMap.where((s) => (s.system != null)).map((i) => i.system!);
  }

  void removeSystem(ShipSystem sys) {
    systemMap.firstWhereOrNull((s) => s.system == sys)?.system = null;
  }

  InstallResult installSystem(ShipSystem system, {SystemSlot? slot}) {
    if (duplicateInstallation(system)) return InstallResult.duplicate;
    if (slot == null) {
      final slots = availableSlotsbySystem(system).toList();
      if (slots.isNotEmpty) {
        slots.first.system = system;
        return InstallResult.success;
      }
    } else {
      final slots = exactSlots(slot).toList();
      if (slots.isNotEmpty && slots.first.slot.supports(system.type,system.manufacturer)) {
        slots.first.system = system;
        return InstallResult.success;
      }
    }
    return InstallResult.unsupported;
  }

  bool uninstallSystem(ShipSystem system) {
    final s = systemMap.firstWhereOrNull((s) => s.system == system);
    if (s != null) {
      s.system = null; return true;
    } return false;
  }

  bool addAmmo(Ammo ammo, int n, {setWeapon = false}) {
    if (!ship.okMass(ammo.mass * n)) return false;
    ammoMap[ammo] = ammoMap.containsKey(ammo) ? ammoMap[ammo]! + n : n; //print("Setting weapon...");
    if (setWeapon) {
      final weapons = getInstalledSystems(types: [ShipSystemType.launcher]);
      if (weapons.isNotEmpty) {
        for (final w in weapons) {
          if (w is Weapon) {
            if (setWeaponAmmo(w, ammo)) break;
          }
        }
      } else {
        print("No launchers");
      }
    }
    return true;
  }

  bool setWeaponAmmo(Weapon w, Ammo a) {
    if (w.usesAmmo) {
      final weapon = getInstalledSystems().firstWhereOrNull((e) => e == w);
      if (weapon != null) { //print("Setting ${w.name},${w.ammoType}...");
        if (weapon is Weapon && weapon.ammoType == a.ammoType) {
          weapon.ammo = a; //print("${weapon.name} -> ${a.name}");
          return true;
        }
      }
    }
    return false;
  }

  double get currentShieldPercentage {
    double s = currentMaxShieldStrength;
    return (s > 0 ? currentShieldStrength/s : 0) * 100;
  }

  double getCurrentMaxEnergy({bool raw = false}) {
    if (ship.multiSystems.contains(ShipSystemType.power)) {
      double e = 0;
      for (final gen in getPowers()) e += (raw ? gen.rawMaxEnergy : gen.currentMaxEnergy);
      return e;
    }
    return raw ? getPower()?.rawMaxEnergy ?? 0 : getPower()?.currentMaxEnergy ?? 0;
  }

  double getCurrentEnergy({bool raw = false}) {
    if (ship.multiSystems.contains(ShipSystemType.power)) {
      double e = 0;
      for (final gen in getPowers()) e += (raw ? gen.rawEnergy : gen.currentEnergy);
      return e;
    }
    return raw ? getPower()?.rawEnergy ?? 0 : getPower()?.currentEnergy ?? 0;
  }

  double get currentEnergyPercentage {
    double s = getCurrentMaxEnergy();
    return (s > 0 ? getCurrentEnergy()/s : 0) * 100;
  }

  double get currentMaxShieldStrength {
    double e = 0;
    for (final shield in getInstalledSystems(types: [ShipSystemType.shield])) {
      if (shield is Shield && shield.active) {
        e = shield.currentMaxEnergy; if (shield.currentEnergy > 0) return e;
      }
    }
    return e;
  }

  Shield? get getCurrentShield {
    for (final shield in getInstalledSystems(types: [ShipSystemType.shield])) {
      if (shield is Shield && shield.active) {
        if (shield.currentEnergy > 0) return shield;
      }
    }
    return null;
  }

  Iterable<Weapon> get availableWeapons {
    return getInstalledSystems(types: [ShipSystemType.weapon,ShipSystemType.launcher])
        .where((w) => w is Weapon && w.active).map((s) => s as Weapon);
  }

  Iterable<Weapon> get readyWeapons {
    return availableWeapons.where((w) => w.cooldown == 0);
  }

  double recharge(double energy) {
    for (final gen in getPowers()) {
      energy -= gen.recharge(energy);
    }
    return energy;
  }

  double rechargeAll() => recharge(getCurrentMaxEnergy(raw: true) - getCurrentEnergy(raw: true));

}