import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/controllers/xeno_controller.dart';
import 'package:crawlspace_engine/effects.dart';
import 'package:crawlspace_engine/galaxy/hazards.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/rng/ship_sys_gen.dart';
import 'package:crawlspace_engine/ship/ship_stat.dart';
import 'package:crawlspace_engine/ship/systems/ship_sys.dart';
import 'package:crawlspace_engine/ship/ship_tick.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import 'package:crawlspace_engine/ship/systems/sensors.dart';
import '../fugue_engine.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/system.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/impulse.dart';
import '../item.dart';
import '../galaxy/geometry/location.dart';
import '../actors/pilot.dart';
import '../actors/player.dart';
import '../stock_items/ship/stock_ships.dart';
import 'nav/nav.dart';
import 'systems/power.dart';
import 'systems/shields.dart';
import 'systems/ship_system.dart';
import 'systems/weapons.dart';

class TickResult {
  final double energy;
  final bool newCell;
  const TickResult(this.energy,this.newCell);
}

enum ShieldHitType {
  none,
  absorbed,
  overflow,
  phaseCatch,
  efficientBlock,
}

class ShieldHitResult {
  final ShieldHitType type;
  final double toHull;
  final double toShield;

  const ShieldHitResult({
    required this.type,
    required this.toHull,
    required this.toShield,
  });
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
  bool jettisonable;
  Scrap(super.name, {
    required super.mass,
    this.jettisonable = true,
    required super.baseCost,
    super.rarity = .01,
  });
  double get costEffectiveness => baseCost / mass;
}

sealed class DockingState {}

class FlightState extends DockingState {
  Pilot pilot;
  final ShipNav nav;
  FlightState(this.pilot, this.nav);
}

class DockedState extends DockingState {
  final SpaceEnvironment hangar;
  DockedState(this.hangar);
}

class Ship extends Item {
  @override
  int get baseCost => inventory.all.map((i) => i.baseCost).sum + shipClass.volume.round();
  @override
  String get shopDesc => dump(shop: true);
  ShipClass shipClass;
  Pilot owner;
  Inventory<Item> inventory = Inventory();
  InventoryView<Scrap> get scrapHeap => inventory.filterType<Scrap>();
  InventoryView get cargo => inventory.filter((i) => i is! ShipSystem || !systemControl.isInstalled(i));

  List<ShipSystemType> multiSystems = [
    ShipSystemType.engine,
    ShipSystemType.weapon,
    ShipSystemType.launcher,
    ShipSystemType.ammo,
    ShipSystemType.quarters];

  late Hull hull;
  late ShipSystemControl systemControl;
  late ShipTick ticker;
  late ShipStatus status;
  double get volume => shipClass.volume;
  double get maxSpeed =>  hull.material.speedMult * shipClass.maxSpeed; // sqrt(volume * mass));
  double hullDamage = 0;
  int minCool = 0;
  late RndSystemInstaller rndSystemInstaller;
  bool get playship => pilotOrNull is Player;
  bool get npc => !playship;
  bool sameLevel(Ship? ship) => ship?.loc.domain == loc.domain;
  bool get inNebula => loc.cell.hasHaz(Hazard.nebula);
  List<System>? itinerary;
  double xenoMatter = 0;
  bool autoShutdown = false;
  EffectMap<ShipEffect> effectMap = EffectMap();
  double get moveProbability => .1; //TODO: tweak
  late DockingState _state;
  DockingState get state => _state;
  void set state(DockingState s) {
    _state = s;
    pilotOrNull?.locale = AboardShip(this);
  }
  bool get isFlying => state is FlightState;
  bool get isDocked => state is DockedState;

  Pilot? get pilotOrNull => switch (state) {
    FlightState(:final pilot) => pilot,
    _ => null,
  };

  ShipNav? get navOrNull => switch (state) {
    FlightState(:final nav) => nav,
    _ => null,
  };

  SpaceEnvironment? get hangarOrNull => switch (state) {
    DockedState(:final hangar) => hangar,
    _ => null,
  };

  Pilot get pilotOrOwner => pilotOrNull ?? owner;
  Pilot get pilot => pilotOrNull!; //livin' dangerously..
  ShipNav get nav => navOrNull!;
  SpaceEnvironment get hangar => hangarOrNull!;
  int? techLvl;

  // Rotation rate in degrees per AUT, scaled by handling
  double get rotationRate => switch(shipClass.engineArch) {
    EngineArch.rear         => shipClass.handling * 45,  // degrees per AUT
    EngineArch.distributed  => shipClass.handling * 90,
    EngineArch.center       => 360, // instant, no facing constraint
  };

  Ship(super.name, {
    required this.owner,
    this.techLvl,
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
    HullMaterial hullMaterial = HullMaterial.basic})  {

    hull = Hull.fromMaterial(hullMaterial,this);
    systemControl = ShipSystemControl(this);
    status = ShipStatus(this);
    ticker = ShipTick(this);
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
    install(sensor);
  }

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

  void move(SpaceLocation newLoc, FugueEngine fm) {
    bool newDom = newLoc.domain != loc.domain;
    fm.galaxy.ships.move(this, newLoc);
    if (newDom) { //print("Resetting loc:");
      if (loc.domain != Domain.orbital) nav.resetMotionState();
      toggleEngines(newLoc.domain);
    } else {
      if (newLoc is ImpulseLocation && newLoc.cell.asteroid != null) {
        fm.combatController.asteroidEncounter(this,newLoc.cell.asteroid!);
      }
    }
  }

  void toggleEngines(Domain newDom) {
    systemControl.toggleSystem(systemControl.getEngine(loc.domain, activeOnly: false),on: false);
    systemControl.toggleSystem(systemControl.getEngine(newDom, activeOnly: false),on: true);
  }

  SpaceLocation? detect(Ship ship) {
    if (canScan(ship.loc.cell)) {
      nav.lastKnown[ship] = ship.loc;
      return ship.loc;
    } else {
      return nav.lastKnown[ship];
    }
  }
  bool canScan(GridCell cell) => !(loc.cell.hasHaz(Hazard.nebula) || cell.hasHaz(Hazard.nebula));

  double get scrapVal => scrapHeap.all.fold<double>(0.0, (sum, i) => sum + i.baseCost);

  //TODO: some ship system to improve this?
  bool addScrap(ShipSystem s, {double scrapFact = 20, double scrapVal = 20}) {
    double m = s.mass/scrapFact;
      if (availableSpace > m) {
        inventory.add(Scrap("scrapped ${s.name}", mass: m, baseCost: (s.baseCost / scrapVal).round()));
        return true;
      } return false;
  }

  Scrap? jettisonScrap() {
    if (scrapHeap.all.isNotEmpty) {
      final s = scrapHeap.all.toList().sorted((a,b) => a.costEffectiveness.compareTo(b.costEffectiveness)).firstOrNull;
      if (s != null && inventory.remove(s)) return s;
      return null;
    }
    return null;
  }

  void jettisonItem(Item i) {
    if (inventory.remove(i) && i is ShipSystem) {
      systemControl.removeSystem(i);
    }
  }

  double distance({Ship? ship, SpaceLocation? l, Coord3D? c}) {
    if (ship != null) return ship.nav.pos.coord.distance(nav.pos.coord);
    if (l != null) return l.dist(loc);
    if (c != null) return c.distance(loc.cell.coord);
    glog("Warning: distance called with 0 arguments",error: true);
    return double.infinity;
  }
  double distanceFrom(Ship ship) => ship.loc.dist(loc);
  double distanceFromLocation(SpaceLocation l) => l.dist(loc);
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

  double get hullStrength => hull.material.integrityMult * volume;

  double shieldResistance(DamageType type) { //TODO: add emitters
    return systemControl.getShields().map((s) => s.resistance(type)).sum;
  }

  double hullResistance(DamageType type) => hull.getResistance(type);

  ShieldHitResult takeShieldDamage(double dmg) {
    final shield = systemControl.getCurrentShield;
    if (shield == null || shield.currentEnergy.floor() <= 0) {
      return ShieldHitResult(
        type: ShieldHitType.none,
        toHull: dmg,
        toShield: 0,
      );
    }

    final canDeflect =
        shield.egos.contains(ShieldEgo.deflector) &&
            shield.state.blockCooldown <= 0 &&
            shield.currentEnergy >= shield.rawMaxEnergy - 0.001;

    final canBlock =
        shield.egos.contains(ShieldEgo.block) &&
        shield.state.blockCooldown <= 0 &&
        shield.currentEnergy >= dmg;

    if (canBlock || canDeflect) {
      if (canBlock) shield.state.blockCooldown = shield.avgRecoveryTime;
      else shield.state.blockCooldown = shield.avgRecoveryTime * 25;

      return ShieldHitResult(
        type: ShieldHitType.efficientBlock,
        toHull: 0,
        toShield: 0,
      );
    }

    final burned = shield.burn(dmg, partial: true);
    final overflow = dmg - burned;

    final canPhase =
        overflow > 0 &&
            shield.egos.contains(ShieldEgo.phase) &&
            shield.state.phaseCooldown <= 0;

    if (canPhase) {
      final phaseFactor = 1.0;
      shield.state.phaseCooldown = shield.avgRecoveryTime * 10;
      final ratio = burned / dmg;
      final negated = (overflow * ratio) * phaseFactor;
      final toHull = overflow - negated;

      return ShieldHitResult(
        type: ShieldHitType.phaseCatch,
        toHull: toHull,
        toShield: burned,
      );
    }

    return ShieldHitResult(
      type: overflow > 0 ? ShieldHitType.overflow : ShieldHitType.absorbed,
      toHull: overflow,
      toShield: burned,
    );
  }

  bool takeHullDamage(double dmg) {
    hullDamage += dmg;
    return hullDamage >= hullStrength;
  }

  String damageReport() {
    return "${hullStrength - hullDamage} hull remaining";
  }

  List<FireResult> fireWeapons(ImpulseCell target, Random rnd, {Ship? ship, required bool slug}) {
    List<FireResult> results = [];
    if (loc is ImpulseLocation && (ship == null || ship.loc.domain == loc.domain)) {
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
          dmg += weapon.fire(loc.distCell(target), rnd, targetShip: ship, clips: clips, slug: slug);
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
    return t == 999 ? 0 : t;
  }

  bool inCombat(Galaxy g) => loc.domain == Domain.impulse && g.ships.activeShips.any((s) => s.loc.interactable(loc) && s.pilot.hostile);

  void scanSystem(System system, FugueEngine fm) {
    final sensor = systemControl.getSensor();
    if (sensor == null || sensor.scannedSystems.contains(system)) return;
    else {
      sensor.scannedSystems.add(system);
      final itemList = fm.galaxy.items.inSystem(system);
      for (final item in itemList) {
        item.scanned = ScanReport(sector: true);
      }
      final scanRoll = ((sensor.accuracy[Domain.system] ?? 0) * .25);
      if (fm.mapRnd.nextDouble() < 1) { //scanRoll) {
        for (final i in fm.galaxy.items.inSystem(system)) {
          i.scanned = ScanReport(sector: true);
          fm.scannerController.refreshSensors(system);
        }
      }
    }
  }

  bool canLand(Galaxy g) {
    final l = loc;
    return l is ImpulseLocation
        && g.planets.singleAtImpulse(l) != null
        && nav.vel.mag < 1;
  }

  bool activeEffect(ShipEffect effect) => effectMap.isActive(effect);

  @override
  String toString() {
    return name;
  }
}

//int repairAll() { return; }
