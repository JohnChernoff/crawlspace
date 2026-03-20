import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/controllers/xeno_controller.dart';
import 'package:crawlspace_engine/effects.dart';
import 'package:crawlspace_engine/galaxy/hazards.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/rng/sys_gen.dart';
import 'package:crawlspace_engine/ship/systems/weapon_profiler.dart';
import '../fugue_engine.dart';
import '../color.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/reg/reg.dart';
import '../galaxy/system.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/impulse.dart';
import '../item.dart';
import '../galaxy/geometry/location.dart';
import '../actors/pilot.dart';
import '../actors/player.dart';
import 'hangar_ship.dart';
import 'nav.dart';
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

class Ship extends HangarShip {
  Pilot pilot;
  double hullDamage = 0;
  int minCool = 0;
  late RndSystemInstaller rndSystemInstaller;
  bool get playship => pilot is Player;
  bool get npc => !playship;
  bool sameLevel(Ship? ship) => ship?.loc.domain == loc.domain;
  bool get inNebula => loc.cell.hasHaz(Hazard.nebula);
  List<System>? itinerary;
  double xenoMatter = 0;
  bool autoShutdown = false;
  EffectMap<ShipEffect> effectMap = EffectMap();
  late ShipNav nav = ShipNav(this);
  double get moveProbability => .1; //TODO: tweak

  Ship(super.name, {
    super.owner,
    super.baseCost = 0,
    super.rarity = 1,
    required super.shipClass,
    required super.location,
    required this.pilot,
    super.generator,
    super.weapons,
    super.ammo,
    super.shield,
    super.impEngine,
    super.subEngine,
    super.hyperEngine,
    super.sensor,
    super.hullMaterial,
  }) {
    pilot.locale = AboardShip(this);
    rndSystemInstaller = RndSystemInstaller(this, systemControl);
  }

  factory Ship.board(Pilot pilot, HangarShip s) => Ship(s.name,
    pilot: pilot,
    owner: s.owner,
    baseCost: s.baseCost,
    rarity: s.rarity,
    shipClass: s.shipClass,
    location: s.loc,
  );

  //shouldn't really do anything other than call the registry
  void move(SpaceLocation newLoc, ShipRegistry registry) { //TODO: remove (quasi-literally)?
    registry.move(this, newLoc);
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
          dmg += weapon.fire(l.distCell(target), rnd, targetShip: ship, clips: clips);
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



  TickResult tick({FugueEngine? fm}) {
    final dryRun = fm == null; //if (!dryRun) print("Tick... $dryRun");
    double totalRecharge = 0, totalBurn = 0;
    for (final rss in systemControl.rechargables) {
      if (rss.currentEnergy < rss.currentMaxEnergy) { //print(rss.name); print(rss.rechargeRate);
        double recharge = rss.currentMaxEnergy * rss.rechargeRate * (1-rss.damage);
        if (!dryRun) {
          if (rss.currentEnergy < 1) {
            recharge = (fm.aiRnd.nextInt(rss.avgRecoveryTime) == 0) ? recharge : 0;
          }
          if (recharge > 0) rss.recharge(recharge);
        }
        totalRecharge += recharge;
      }
    }
    //if (dryRun) print("Total recharge: ${totalRecharge}");
    for (final system in systemControl.activeSystems) { //TODO: handle npc power outages
      double e = system.powerDraw; //print("Burning: $e");
      if (!dryRun) {
        final burnout = !systemControl.burnEnergy(e);
        if (burnout && system is! RechargableShipSystem && autoShutdown) {
          system.active = false;
          fm.msg("Out of power, shutting down ${system.type.name}");
        }
      }
      totalBurn += e;
    } //print("$name: Net energy per tick: ${recharge - totalBurn}");
    //if (dryRun) print("Total burn: ${totalBurn}");
    if (!dryRun) {
      for (final w in systemControl.getWeapons()) if (w.cooldown > 0) w.cooldown--;
      xenoMatter = min(shipClass.maxXeno,
          xenoMatter + (systemControl.engine?.xenoGen ?? 0.0));
      effectMap.tickAll();
      for (final effect in loc.cell.effects.allActive) {
        effect.apply(this,fm);
      }
    }
    final newCell;
    if (!dryRun && loc.domain == Domain.impulse && (nav.moving || nav.activeHeading)) {
      if (fm.auTick % 4 == 0) { //(fm.aiRnd.nextDouble() < 1) { //moveProbability) {
        final prevLoc = loc.cell.coord;
        fm.movementController.moveShip(this, nav.heading ?? loc);
        newCell = (loc.cell.coord != prevLoc);
      } else newCell = false;
    } else newCell = false;
    //if (newCell) print ("Moved: ${fm?.auTick}");
    return TickResult(totalRecharge - totalBurn, newCell);
  }

  void scanSystem(System system, FugueEngine fm) {
    final sensor = systemControl.getSensor();
    if (sensor == null || sensor.scannedSystems.contains(system)) return;
    else {
      sensor.scannedSystems.add(system);
      final itemList = fm.galaxy.items.inSystem(system);
      for (final i in itemList) {
        i.value.forEach((item) => item.scanned = ScanReport(sector: true));
      }
      final scanRoll = ((sensor.accuracy[Domain.system] ?? 0) * .25);
      if (fm.mapRnd.nextDouble() < 1) { //scanRoll) {
        for (final i in fm.galaxy.items.inSystem(system).expand((e) => e.value)) {
          i.scanned = ScanReport(sector: true);
          fm.scannerController.refreshSensors(system);
        }
      }
    }
  }

  bool activeEffect(ShipEffect effect) => effectMap.isActive(effect);

  List<TextBlock> status({bool tactical = false, bool showScannedShip = true, nebula = false}) {
    final abbrev = !tactical && nav.targetShip != null;
    final hostile = pilot.hostile;
    if (nebula || (tactical && loc.cell.hasHaz(Hazard.nebula))) return [TextBlock("In Nebula", GameColors.red, true)];
    List<TextBlock> blocks = [];
    blocks.addAll(dumpEffects());
    if (!abbrev) {
      blocks.add(TextBlock(name,pilot.faction.color,true));
      blocks.add(TextBlock("${pilot.faction.name} ${shipClass.type.name}",pilot.faction.color,true));
    }
    if (pilot.faction.isPirate) blocks.add(TextBlock("*** Pirate ***",GameColors.red,true)); else {
      if (tactical) blocks.add(TextBlock("${(hostile ? 'hostile' : 'peaceful')} ",GameColors.gray,true));
    }

    blocks.add(TextBlock("Hull: ${hullRemaining.toStringAsFixed(2)} ",GameColors.green,false));
    //blocks.add(TextBlock("Volume: ${volume} ",GameColors.green,false));

    blocks.add(TextBlock("%: ${currentHullPercentage.toStringAsFixed(2)}",GameColors.lightBlue,true));
    blocks.add(TextBlock("Shields: ${systemControl.currentShieldStrength.toStringAsFixed(2)}, ",GameColors.green,false));
    blocks.add(TextBlock("%: ${systemControl.currentShieldPercentage.toStringAsFixed(2)}",GameColors.lightBlue,true));
    if (!tactical) {
      blocks.add(TextBlock("Energy: ${systemControl.getCurrentEnergy().toStringAsFixed(2)}, ",GameColors.green,false));
      blocks.add(TextBlock("%: ${systemControl.currentEnergyPercentage.round().toStringAsFixed(2)}",GameColors.lightBlue,true));
      blocks.add(TextBlock("Energy Rate: ${tick().energy.toStringAsFixed(2)}",GameColors.green,true));
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
    if (!tactical && nav.targetShip != null) {

      final sustained = sustainedRangeProfile(maxRange: loc.system.impulseMapDim.maxDim * 2);
      blocks.add(TextBlock(sustained.summary(), GameColors.orange, true));
      final dist = distanceFrom(nav.targetShip!).round();
      final volley = volleyRangeProfile(maxRange: loc.system.impulseMapDim.maxDim * 2);
      final fit = (volley.efficiencyAt(dist) * 100).round();
      blocks.add(TextBlock("Dist $dist | volley fit $fit%", GameColors.lightBlue, true));
      blocks.addAll(combatText());
    }
    if (!tactical) {
      blocks.add(TextBlock("Position: ${nav.pos}", GameColors.gray, true));
      blocks.add(TextBlock("Heading: ${nav.heading?.loc.cell.coord}", GameColors.gray, true));
      blocks.add(TextBlock("Velocity: ${nav.velocityString()}", GameColors.gray, true));
      blocks.add(TextBlock("Speed: ${nav.speed.toStringAsFixed(2)}", GameColors.gray, true));
      blocks.add(TextBlock("Throttle: ${nav.throttle}", GameColors.gray, true));
      if (!abbrev) {
        blocks.add(TextBlock("Total mass: ${currentMass.toStringAsFixed(2)}", GameColors.gray, true));
        blocks.add(TextBlock("Remaining capacity: ${availableSpace.toStringAsFixed(2)}", GameColors.gray, true));
        blocks.add(TextBlock("Total scrap value: ${scrapVal.toStringAsFixed(2)}", GameColors.gray, true));
      }
    }
    blocks.add(const TextBlock("",GameColors.black,true));
    if (nav.targetCoord != null) blocks.add(TextBlock("Scanning Coord: $nav.targetCoord", GameColors.orange, true));
    if (showScannedShip && !tactical && (nav.targetShip != null && nav.targetShip!.npc)) {
      blocks.add(const TextBlock("Scanning Ship: ", GameColors.orange, true));
      blocks.addAll(nav.targetShip!.status(tactical: true));
    }
    return blocks;
  }

  List<TextBlock> combatText() {
    final target = nav.targetShip;
    if (target == null) return [];

    final dist = distance(l: target.loc);
    final projDist = nav.projectedTargetDist;
    final trend = nav.trendGlyph;
    final profile = volleyRangeProfile();

    final inRange = profile.usableBand != null &&
        dist >= profile.usableBand!.start &&
        dist <= profile.usableBand!.end;
    final projInRange = projDist != null && profile.usableBand != null &&
        projDist >= profile.usableBand!.start &&
        projDist <= profile.usableBand!.end;

    final rangeColor = inRange
        ? (projInRange ? GameColors.green : GameColors.orange)
        : (projInRange ? GameColors.lightBlue : GameColors.red);

    final blocks = <TextBlock>[];

    // Header line
    blocks.add(TextBlock(
        "TARGET: ${target.name} "
            "dist:${dist.toStringAsFixed(1)}$trend"
            "->${projDist?.toStringAsFixed(1) ?? '?'} ",
        rangeColor, false));
    blocks.add(TextBlock(profile.asciiBars(), GameColors.cyan, true));

    // Per-weapon lines
    for (final w in systemControl.availableWeapons) {
      final maxCooldown = w.fireRate;
      final filled = maxCooldown > 0
          ? ((1 - w.cooldown / maxCooldown) * 10).round().clamp(0, 10)
          : 10;
      final empty = 10 - filled;

      final wInRange = w.accuracyRangeConfig.rangeMultiplier(dist) > 0;
      final wProjInRange = projDist != null &&
          w.accuracyRangeConfig.rangeMultiplier(projDist) > 0;

      final col = w.cooldown == 0
          ? (wInRange ? GameColors.green : GameColors.orange)
          : (wProjInRange ? GameColors.lightBlue : GameColors.gray);

      final readyStr = w.cooldown == 0 ? "READY" : "${w.cooldown}t";

      blocks.add(TextBlock(
          "${w.name.substring(0, min(10, w.name.length)).padRight(10)} "
              "${'█' * filled}${'░' * empty} "
              "$readyStr ",
          col, true));
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



  @override
  String toString() {
    return name;
  }
}

//int repairAll() { return; }
