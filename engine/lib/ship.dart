import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/controllers/xeno_controller.dart';
import 'package:crawlspace_engine/effects.dart';
import 'package:crawlspace_engine/hazards.dart';
import 'package:crawlspace_engine/object.dart';
import 'package:crawlspace_engine/rng/rnd_sys.dart';
import 'package:crawlspace_engine/ship_reg.dart';
import 'package:crawlspace_engine/ship_sys.dart';
import 'fugue_engine.dart';
import 'color.dart';
import 'coord_3d.dart';
import 'galaxy/system.dart';
import 'grid.dart';
import 'impulse.dart';
import 'item.dart';
import 'location.dart';
import 'pilot.dart';
import 'player.dart';
import 'stock_items/stock_ships.dart';
import 'systems/engines.dart';
import 'systems/power.dart';
import 'systems/shields.dart';
import 'systems/ship_system.dart';
import 'systems/weapons.dart';

class HullResistance {
  final DamageType dmgType;
  final double resistance;
  const HullResistance(this.dmgType,this.resistance);
}

class SlotAssignment {
  SystemSlot slot;
  ShipSystem? system;
  SlotAssignment(this.slot,this.system);
}

class FireResult {
  int dmg;
  Weapon weapon;
  bool ammoWarn;
  FireResult(this.dmg,this.weapon,this.ammoWarn);
}

class Scrap extends Item {
  double mass;
  bool jettisonable;
  Scrap(super.name, {
    required this.mass,
    this.jettisonable = true,
    required super.baseCost,
    super.rarity = .01,
  });
  double get costEffectiveness => baseCost / mass;
}

class Ship extends Item implements Locatable {
  @override
  SpaceLocation get loc => _loc;
  @override
  int get baseCost => shipClass.slots.map((s) => s.slot.type.baseCost).sum + shipClass.maxMass.round();
  @override
  String get shopDesc => dump(shop: true);
  SpaceLocation _loc;
  ShipClass shipClass;
  Pilot? owner;
  Pilot? _pilot;
  Pilot get pilot => _pilot ?? nobody;
  set pilot(Pilot? p) => _pilot = (p == nobody) ? null : p;
  bool get hasPilot => _pilot != null;
  double hullDamage = 0;
  int minCool = 0;
  int impulseMapSize = 8;
  Set<Item> inventory = {};
  List<Item> get allInventory => [...inventory, ...scrapHeap];
  bool get playship => pilot is Player;
  bool get npc => !playship;
  Ship? targetShip;
  Coord3D? targetCoord;
  List<GridCell> currentPath = [];
  List<Scrap> scrapHeap = [];
  Map<Ship,SpaceLocation> lastKnown = {};
  HullType hullType;
  bool get inNebula => loc.cell.hasHaz(Hazard.nebula);
  List<ShipSystemType> multiSystems = [ShipSystemType.engine,ShipSystemType.weapon,ShipSystemType.launcher,ShipSystemType.ammo,ShipSystemType.quarters];
  late ShipSystemControl systemControl;
  late RndSystemInstaller rndSystemInstaller;
  List<System>? itinerary;
  double xenoMatter = 0;
  EffectMap<ShipEffect> effectMap = EffectMap();
  late XenoController xenoControl = XenoController(this);

  Ship(super.name, {
    this.owner,
    super.baseCost = 0,
    super.rarity = 1,
    required this.shipClass,
    required SpaceLocation location,
    Pilot? pilot,
    PowerGenerator? generator,
    List<Weapon>? weapons,
    Map<Ammo,int>? ammo,
    Shield? shield,
    Engine? impEngine,
    Engine? subEngine,
    Engine? hyperEngine,
    this.hullType = HullType.basic
    }) : _loc = location, _pilot = pilot {

    _pilot?.locale = AboardShip(this);
    systemControl = ShipSystemControl(this);
    rndSystemInstaller = RndSystemInstaller(this, systemControl);
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
  }

  void install(ShipSystem? system, {bool active = true}) {
    if (system != null) {
      addToInventory(system);
      final result = systemControl.installSystem(system);
      if (result == InstallResult.success) systemControl.toggleSystem(system, on: active);
      else print("Error installing ${system.name}: $result");
    }
  }

  void move(SpaceLocation newLoc, ShipRegistry registry) {
    registry.reIndex(this, newLoc);
    _loc = newLoc;
  }

  void dock(SpaceEnvironment env, ShipRegistry registry) {
    registry.dock(this, env);
  }

  void undock(SpaceEnvironment env, SpaceLocation launchLoc, ShipRegistry registry) {
    registry.undock(this, env);
  }

  bool addToInventory(Item i) {
    if (i is ShipSystem && availableMass < i.mass) return false;
    inventory.add(i);
    return true;
  }

  SpaceLocation? detect(Ship ship) {
    if (canScan(ship.loc.cell)) {
      lastKnown[ship] = ship.loc;
      return ship.loc;
    } else {
      return lastKnown[ship];
    }
  }
  bool canScan(GridCell cell) => !(loc.cell.hasHaz(Hazard.nebula) || cell.hasHaz(Hazard.nebula));

  double get scrapVal => scrapHeap.fold<double>(0.0, (sum, i) => sum + i.baseCost);

  //TODO: some ship system to improve this?
  bool addScrap(ShipSystem s, {double scrapFact = 20, double scrapVal = 20}) {
    double m = s.mass/scrapFact;
      if (availableMass > m) {
        scrapHeap.add(Scrap("scrapped ${s.name}", mass: m, baseCost: (s.baseCost / scrapVal).round()));
        return true;
      } return false;
  }

  Scrap? jettisonScrap() {
    if (scrapHeap.isNotEmpty) {
      scrapHeap.sort((a,b) => a.costEffectiveness.compareTo(b.costEffectiveness));
      return scrapHeap.removeAt(0);
    }
    return null;
  }

  void jettisonItem(Item i) {
    if (i is Scrap) {
      scrapHeap.remove(i);
    } else if (inventory.remove(i) && i is ShipSystem) {
      systemControl.removeSystem(i);
    }
  }

  double distance({Ship? ship, SpaceLocation? l, Coord3D? c}) {
    if (ship != null) return ship.loc.cell.coord.distance(loc.cell.coord);
    if (l != null) return l.cell.coord.distance(loc.cell.coord);
    if (c != null) return c.distance(loc.cell.coord);
    glog("Warning: distance called with 0 arguments",error: true);
    return double.infinity;
  }
  double distanceFrom(Ship ship) => ship.loc.cell.coord.distance(loc.cell.coord);
  double distanceFromLocation(SpaceLocation l) => l.cell.coord.distance(loc.cell.coord);
  double distanceFromCoord(Coord3D c) => c.distance(loc.cell.coord);

  double get hullRemaining  => (hullStrength-hullDamage);
  bool get intact => hullRemaining > 0;

  double get currentHullPercentage {
    double s = hullStrength;
    return (s > 0 ? hullRemaining/s : 0) * 100;
  }



  double repairHull(double amount) {
    double prevDam = hullDamage;
    hullDamage = max(hullDamage - amount,0);
    return prevDam - hullDamage;
  }

  double get hullStrength => shipClass.maxMass;

  bool takeDamage(double dam, DamageType dmgType) {
    Shield? shield = systemControl.getCurrentShield; if (shield != null) {
      dam -= shield.burn(dam,partial: true);
    }
    hullDamage += dam;
    return hullDamage >= hullStrength;
  }

  String damageReport() {
    return "${hullStrength - hullDamage} hull remaining";
  }

  List<FireResult> fireWeapons(ImpulseCell target, Random rnd, {Ship? ship}) {
    List<FireResult> results = [];
    final l = loc;
    if (l is ImpulseLocation && (ship == null || ship.loc.domain == loc.domain)) {
      int? minCool;
      for (final weapon in systemControl.readyWeapons) {
        double dmg = 0;
        bool ammoWarn = false;
        bool ammoOK = true;
        int? clips;
        if (weapon.usesAmmo) {
          ammoOK = systemControl.ammoOK(weapon); if (ammoOK) {
            clips = systemControl.fireAmmoRound(weapon);
          } else {
            ammoWarn = true;
          }
        }
        if (ammoOK) {
          dmg += weapon.fire(l.cell.coord.distance(target.coord), rnd, targetShip: ship, clips: clips);
          if (minCool == null || minCool > weapon.cooldown) minCool = weapon.cooldown;
        }
        results.add(FireResult(dmg.floor(),weapon,ammoWarn));
      }
    }
    return results;
  }

  int get turnsUntilWeaponReady {
    int t = 999;
    for (final w in systemControl.getInstalledSystems(types: [ShipSystemType.weapon])) {
      if (w is Weapon && w.active) {
        if (w.cooldown == 0) return 0;
        if (w.cooldown < t) t = w.cooldown;
      }
    }
    return t;
  }

  double get currentMass {
    double m = 0;
    for (final a in systemControl.ammo) {
      m += a.count * a.ammo.mass;
    }
    m += scrapHeap.fold<double>(0.0, (sum, i) => sum + i.mass);
    return inventory.whereType<ShipSystem>().fold<double>(0.0, (sum, s) => sum + s.mass) + m;
  }

  double get availableMass => shipClass.maxMass - currentMass;
  bool okMass(double m) => availableMass > m;

  //TODO: handle power outages?
  double tick({Random? rnd, dryRun = false}) { //print("Tick... $dryRun");
    double totalRecharge = 0, totalBurn = 0;
    for (final rss in systemControl.rechargables) {
      if (rss.currentEnergy < rss.currentMaxEnergy) { //print(rss.name); print(rss.rechargeRate);
        double recharge = rss.currentMaxEnergy * rss.rechargeRate * (1-rss.damage);
        if (!dryRun) {
          if (rnd != null && rss.currentEnergy < 1) {
            recharge = (rnd.nextInt(rss.avgRecoveryTime) == 0) ? recharge : 0;
          }
          if (recharge > 0) rss.recharge(recharge);
        }
        totalRecharge += recharge;
      }
    }
    for (final system in systemControl.activeSystems) {
      double e = system.powerDraw; //print("Burning: $e");
      if (!dryRun) systemControl.burnEnergy(e);
      totalBurn += e;
    } //print("$name: Net energy per tick: ${recharge - totalBurn}");
    if (!dryRun) {
      for (final w in systemControl.getWeapons()) if (w.cooldown > 0) w.cooldown--;
      xenoMatter = min(shipClass.maxXeno,
          xenoMatter + (systemControl.engine?.xenoGen ?? 0.0));
      effectMap.tickAll();
    }
    return totalRecharge - totalBurn;
  }

  bool activeEffect(ShipEffect effect) => effectMap.isActive(effect);

  List<TextBlock> status({bool tactical = false, bool showScannedShip = false, nebula = false}) {
    final hostile = pilot.hostile;
    if (nebula || (tactical && loc.cell.hasHaz(Hazard.nebula))) return [TextBlock("In Nebula", GameColors.red, true)];
    List<TextBlock> blocks = [];
    blocks.addAll(dumpEffects());
    blocks.add(TextBlock(name,pilot.faction.color,true));
    blocks.add(TextBlock("${pilot.faction.name} ${shipClass.type.name}",pilot.faction.color,true));
    if (pilot.faction.isPirate) blocks.add(TextBlock("*** Pirate ***",GameColors.red,true)); else {
      if (tactical) blocks.add(TextBlock("${(hostile ? 'hostile' : 'peaceful')} ",GameColors.gray,true));
    }
    blocks.add(TextBlock("Hull: ${hullRemaining.toStringAsFixed(2)} ",GameColors.green,false));
    blocks.add(TextBlock("%: ${currentHullPercentage.toStringAsFixed(2)}",GameColors.lightBlue,true));
    blocks.add(TextBlock("Shields: ${systemControl.currentShieldStrength.toStringAsFixed(2)}, ",GameColors.green,false));
    blocks.add(TextBlock("%: ${systemControl.currentShieldPercentage.toStringAsFixed(2)}",GameColors.lightBlue,true));
    if (!tactical) {
      blocks.add(TextBlock("Energy: ${systemControl.getCurrentEnergy().toStringAsFixed(2)}, ",GameColors.green,false));
      blocks.add(TextBlock("%: ${systemControl.currentEnergyPercentage.round().toStringAsFixed(2)}",GameColors.lightBlue,true));
      blocks.add(TextBlock("Energy Rate: ${tick(dryRun: true).round().toStringAsFixed(2)}",GameColors.green,true));
    }
    blocks.add(TextBlock("Xeno Matter: ${xenoMatter.toStringAsFixed(2)}",GameColors.orange,true));
    for (final s in systemControl.getInstalledSystems()) {
      bool cooldown = s is Weapon && s.cooldown > 0;
      final color = cooldown ? GameColors.red : GameColors.white;
      blocks.add(TextBlock("${s.name} ",color,false));
      if (s.damage > 0) blocks.add(TextBlock("${s.dmgTxt}% ", GameColors.gray, false));
      blocks.add(TextBlock("${s.active ? '+' : '-'}",color,true));
      if (s is Weapon && s.ammo != null) {
        blocks.add(TextBlock("${s.ammo!.name}: ${systemControl.ammoFor(s.ammo!)}",GameColors.coral,true));
      }
    }
    if (!tactical) {
      blocks.add(TextBlock("Remaining capacity: ${availableMass.toStringAsFixed(2)}", GameColors.gray, true));
      blocks.add(TextBlock("Total scrap value: ${scrapVal.toStringAsFixed(2)}", GameColors.gray, true));
    }
    blocks.add(const TextBlock("",GameColors.black,true));
    if (targetCoord != null) blocks.add(TextBlock("Scanning Coord: $targetCoord", GameColors.orange, true));
    if (showScannedShip && !tactical && (targetShip != null && targetShip!.npc)) {
      blocks.add(const TextBlock("Scanning Ship: ", GameColors.orange, true));
      blocks.addAll(targetShip!.status(tactical: true));
    }
    return blocks;
  }

  List<TextBlock> dumpEffects() {
      final map = effectMap.map.entries.where((e) => e.value > 0).map(((m) => m.key));
      return List.generate(map.length, (i) {
        final effect = map.elementAt(i);
        return TextBlock(effect.statusString, effect.color, true);
      });
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

  @override
  String toString() {
    return name;
  }
}

//int repairAll() { return; }
