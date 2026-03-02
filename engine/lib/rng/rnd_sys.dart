import 'dart:math';
import 'package:crawlspace_engine/rng/rng.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/ship_sys.dart';
import 'package:crawlspace_engine/stock_items/stock_ammo.dart';
import 'package:crawlspace_engine/stock_items/stock_engines.dart';
import 'package:crawlspace_engine/stock_items/stock_lauchers.dart';
import 'package:crawlspace_engine/stock_items/stock_power.dart';
import 'package:crawlspace_engine/stock_items/stock_shields.dart';
import 'package:crawlspace_engine/stock_items/stock_weapons.dart';
import 'package:crawlspace_engine/systems/engines.dart';
import 'package:crawlspace_engine/systems/power.dart';
import 'package:crawlspace_engine/systems/shields.dart';
import 'package:crawlspace_engine/systems/ship_system.dart';
import 'package:crawlspace_engine/systems/weapons.dart';
import '../grid.dart';

class RndSystemInstaller {

  final ShipSystemControl sysCtl;
  final Ship ship;
  const RndSystemInstaller(this.ship,this.sysCtl);

  //TODO: sort by techLvl
  bool installRndEngine(Domain domain, int techLvl, Random rnd, {maxAttempts = 100}) { //print("Attempting to install $domain engine <= techlvl $techLvl...");
    int attempts = 0;
    while (sysCtl.getEngine(domain) == null && attempts++ < maxAttempts) { //print("Engine weights: ${pilot.faction.engineWeights.normalized}");
      final engineType = Rng.weightedRandom(ship.pilot.faction.engineWeights.normalized,rnd); //print("Engine Type: $engineType");
      final engineList = stockEngines.entries.where((v) => v.value.engineType == engineType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.value.systemData.slot,v.key.type).isNotEmpty &&
          v.value.domain == domain);
      if (engineList.isNotEmpty) {
        sysCtl.installSystem(Engine.fromStock(engineList.elementAt(rnd.nextInt(engineList.length)).key));
      }
    }
    return sysCtl.getEngine(domain, activeOnly: false) != null ? true : techLvl > 1 ? installRndEngine(domain, 1, rnd) : false;
  }

  bool installRndPower(int techLvl, Random rnd, {maxAttempts = 10}) { //print("Attempting to install power generator <= techlvl $techLvl...");
    int attempts = 0;
    while (sysCtl.getInstalledSystems(types: [ShipSystemType.power]).isEmpty && attempts++ < 100) {
      final powerType = Rng.weightedRandom(ship.pilot.faction.powerWeights.normalized,rnd);
      final powerList = stockPPs.entries.where((v) => v.value.powerType == powerType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.value.systemData.slot,v.key.type).isNotEmpty);
      if (powerList.isNotEmpty) sysCtl.installSystem(PowerGenerator.fromStock(powerList.elementAt(rnd.nextInt(powerList.length)).key));
    }
    return sysCtl.getInstalledSystems(types: [ShipSystemType.power]).isNotEmpty ? true : techLvl > 1 ? installRndPower(1, rnd) : false;
  }

  bool installRndShield(int techLvl, Random rnd, {maxAttempts = 10}) { //print("Attempting to install shield <= techlvl $techLvl...");
    int attempts = 0;
    while (sysCtl.getInstalledSystems(types: [ShipSystemType.shield]).isEmpty && attempts++ < 100) {
      final shieldType = Rng.weightedRandom(ship.pilot.faction.shieldWeights.normalized,rnd);
      final shieldList = stockShields.entries.where((v) => v.value.shieldType == shieldType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.value.systemData.slot,v.key.type).isNotEmpty);
      if (shieldList.isNotEmpty) sysCtl.installSystem(Shield.fromStock(shieldList.elementAt(rnd.nextInt(shieldList.length)).key));
    }
    return sysCtl.getInstalledSystems(types: [ShipSystemType.shield]).isNotEmpty ? true : techLvl > 1 ? installRndShield(1, rnd) : false;
  }

  bool installRndWeapon(int techLvl, Random rnd, {maxAttempts = 10}) { //print("Attempting to install weapon <= techlvl $techLvl...");
    int attempts = 0;
    while (sysCtl.getInstalledSystems(types: [ShipSystemType.weapon]).isEmpty && attempts++ < 100) {
      final dmgType = Rng.weightedRandom(ship.pilot.faction.damageWeights.normalized,rnd);
      final weaponList = stockWeapons.entries.where((v) => v.value.dmgType == dmgType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.value.systemData.slot,v.key.type).isNotEmpty);
      if (weaponList.isNotEmpty) sysCtl.installSystem(Weapon.fromStock(weaponList.elementAt(rnd.nextInt(weaponList.length)).key));
    }
    return sysCtl.getInstalledSystems(types: [ShipSystemType.weapon]).isNotEmpty;
  }

  bool installRndLauncher(int techLvl, Random rnd, {maxAttempts = 10}) {
    int attempts = 0;
    while (sysCtl.getInstalledSystems(types: [ShipSystemType.launcher]).isEmpty && attempts++ < 100) {
      final dmgType = Rng.weightedRandom(ship.pilot.faction.damageWeights.normalized,rnd);
      final launchList = stockLaunchers.entries.where((v) => v.value.dmgType == dmgType &&
          v.key.techLvl <= techLvl && sysCtl.availableSlots(v.value.systemData.slot,v.key.type).isNotEmpty);
      if (launchList.isNotEmpty) {
        final result = sysCtl.installSystem(Weapon.fromStock(launchList.elementAt(rnd.nextInt(launchList.length)).key));
        if (result == InstallResult.success) {
          final ammoDmgType = Rng.weightedRandom(ship.pilot.faction.ammoDamageWeights.normalized,rnd);
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