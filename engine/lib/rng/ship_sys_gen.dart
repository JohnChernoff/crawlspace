import 'dart:math';
import 'package:crawlspace_engine/rng/rng.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/ship_sys.dart';
import 'package:crawlspace_engine/stock_items/ship_systems/stock_ammo.dart';
import 'package:crawlspace_engine/stock_items/ship_systems/stock_engines.dart';
import 'package:crawlspace_engine/stock_items/ship_systems/stock_lauchers.dart';
import 'package:crawlspace_engine/stock_items/ship_systems/stock_power.dart';
import 'package:crawlspace_engine/stock_items/ship_systems/stock_shields.dart';
import 'package:crawlspace_engine/stock_items/ship_systems/stock_weapons.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import 'package:crawlspace_engine/ship/systems/power.dart';
import 'package:crawlspace_engine/ship/systems/shields.dart';
import 'package:crawlspace_engine/ship/systems/ship_system.dart';
import 'package:crawlspace_engine/ship/systems/weapons.dart';
import '../galaxy/geometry/grid.dart';

class RndSystemInstaller {

  final ShipSystemControl sysCtl;
  final Ship ship;
  const RndSystemInstaller(this.ship,this.sysCtl);

  //TODO: sort by techLvl
  bool installRndEngine(Domain domain, int techLvl, Random rnd, {maxAttempts = 100}) { //print("Attempting to install $domain engine <= techlvl $techLvl...");
    int attempts = 0;
    final faction = ship.pilotOrOwner.faction;
    while (sysCtl.getEngine(domain) == null && attempts++ < maxAttempts) { //print("Engine weights: ${pilot.faction.engineWeights.normalized}");
      final engineType = Rng.weightedRandom(faction.engineWeights.normalized,rnd); //print("Engine Type: $engineType");
      final engineList = stockEngines.entries.where((v) => v.value.engineType == engineType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.key.type,v.value.systemData.manufacturer).isNotEmpty &&
          v.value.domain == domain);
      if (engineList.isNotEmpty) {
        sysCtl.installSystem(Engine.fromStock(engineList.elementAt(rnd.nextInt(engineList.length)).key));
      }
    }
    return sysCtl.getEngine(domain, activeOnly: false) != null ? true : techLvl > 1 ? installRndEngine(domain, 1, rnd) : false;
  }

  bool installRndPower(int techLvl, Random rnd, {maxAttempts = 10}) { //print("Attempting to install power generator <= techlvl $techLvl...");
    int attempts = 0;
    final faction = ship.pilotOrOwner.faction;
    while (sysCtl.getInstalledSystems(types: [ShipSystemType.power]).isEmpty && attempts++ < 100) {
      final powerType = Rng.weightedRandom(faction.powerWeights.normalized,rnd);
      final powerList = stockPPs.entries.where((v) => v.value.powerType == powerType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.key.type,v.value.systemData.manufacturer).isNotEmpty);
      if (powerList.isNotEmpty) sysCtl.installSystem(PowerGenerator.fromStock(powerList.elementAt(rnd.nextInt(powerList.length)).key));
    }
    return sysCtl.getInstalledSystems(types: [ShipSystemType.power]).isNotEmpty ? true : techLvl > 1 ? installRndPower(1, rnd) : false;
  }

  bool installRndShield(int techLvl, Random rnd, {maxAttempts = 10}) { //print("Attempting to install shield <= techlvl $techLvl...");
    int attempts = 0;
    final faction = ship.pilotOrOwner.faction;
    while (sysCtl.getInstalledSystems(types: [ShipSystemType.shield]).isEmpty && attempts++ < 100) {
      final shieldType = Rng.weightedRandom(faction.shieldWeights.normalized,rnd);
      final shieldList = stockShields.entries.where((v) => v.value.shieldType == shieldType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.key.type,v.value.systemData.manufacturer).isNotEmpty);
      if (shieldList.isNotEmpty) sysCtl.installSystem(Shield.fromStock(shieldList.elementAt(rnd.nextInt(shieldList.length)).key));
    }
    return sysCtl.getInstalledSystems(types: [ShipSystemType.shield]).isNotEmpty ? true : techLvl > 1 ? installRndShield(1, rnd) : false;
  }

  bool installRndWeapon(int techLvl, Random rnd, {maxAttempts = 10}) { //print("Attempting to install weapon <= techlvl $techLvl...");
    int attempts = 0;
    final faction = ship.pilotOrOwner.faction;
    while (sysCtl.getInstalledSystems(types: [ShipSystemType.weapon]).isEmpty && attempts++ < 100) {
      final dmgType = Rng.weightedRandom(faction.damageWeights.normalized,rnd);
      final weaponList = stockWeapons.entries.where((v) => v.value.dmgType == dmgType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.key.type,v.value.systemData.manufacturer).isNotEmpty);
      if (weaponList.isNotEmpty) sysCtl.installSystem(Weapon.fromStock(weaponList.elementAt(rnd.nextInt(weaponList.length)).key));
    }
    return sysCtl.getInstalledSystems(types: [ShipSystemType.weapon]).isNotEmpty;
  }

  bool installRndLauncher(int techLvl, Random rnd, {maxAttempts = 10}) {
    int attempts = 0;
    final faction = ship.pilotOrOwner.faction;
    while (sysCtl.getInstalledSystems(types: [ShipSystemType.launcher]).isEmpty && attempts++ < 100) {
      final dmgType = Rng.weightedRandom(faction.damageWeights.normalized,rnd);
      final launchList = stockLaunchers.entries.where((v) => v.value.dmgType == dmgType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.key.type,v.value.systemData.manufacturer).isNotEmpty);
      if (launchList.isNotEmpty) {
        final result = sysCtl.installSystem(Weapon.fromStock(launchList.elementAt(rnd.nextInt(launchList.length)).key));
        if (result == InstallResult.success) {
          final ammoDmgType = Rng.weightedRandom(faction.ammoDamageWeights.normalized,rnd);
          final ammoList = stockAmmo.entries.where((v) => v.value.damageType == ammoDmgType && v.key.techLvl >= techLvl);
          if (ammoList.isNotEmpty) {
            sysCtl.addAmmo(ammoList.elementAt(rnd.nextInt(ammoList.length)).value, 99,setWeapon: true);
          }
        }
      }
    }
    return sysCtl.getInstalledSystems(types: [ShipSystemType.launcher]).isNotEmpty;
  }
}