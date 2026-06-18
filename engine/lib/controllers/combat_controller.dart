import 'dart:math';

import 'package:collection/collection.dart';
import 'package:crawlspace_engine/actors/pilot.dart';
import 'package:crawlspace_engine/color.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/galaxy/reg/locatables.dart';
import 'package:crawlspace_engine/ship/nav/nav.dart';
import 'package:crawlspace_engine/ship/systems/weapons.dart';
import '../fugue_engine.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/impulse.dart';
import '../galaxy/geometry/sector.dart';
import '../ship/ship.dart';
import 'fugue_controller.dart';
import 'pilot_controller.dart';

class ImpulseSlug extends SpaceObject<ImpulseLocation> {
  final quantity;
  final double toHit;
  final int projectedDamage;
  final DamageType dmgType;
  double speed;
  Coord3D target;
  late Vec3 dir;
  Position pos;
  Ship fromShip;
  Coord3D origin;
  Position get nextPos => pos.add(dir * speed);
  Coord3D? get nextCoord => pos.coord == nextPos.coord ? null : nextPos.coord;

  ImpulseSlug({
    super.objColor,
    required this.projectedDamage,
    this.toHit = 1,
    this.quantity = 1,
    required this.origin,
    required this.dmgType,
    required this.speed,
    required this.fromShip,
    required this.target}) : pos = Position.fromCoord(fromShip.loc.cell.coord), super("${fromShip.name} slug (${dmgType})") {
    final v = target.sub(fromShip.loc.cell.coord);
    dir = Vec3.fromCoord(v).normalized;
  }

  void tick(FugueEngine fm) { //print(this);
    final currPos = pos;
    pos = nextPos;
    if (!_hitCheck(fm)) {
      if (!pos.coord.inBounds(loc.dim)) {
        fm.galaxy.slugs.remove(this); return;
      } else {
        if (pos.coord != currPos.coord) {
          if (pos.coord.distance(origin) > dmgType.damageRange.maxRange) {
            glog("Slugged: $this", level: DebugLevel.Info);
            fm.galaxy.slugs.remove(this); return;
          } else {
            fm.galaxy.slugs.move(this, ImpulseLocation(loc.system, loc.sectorCoord, pos.coord));
          }
        }
        if (!_hitCheck(fm)) {
          if (loc.cell.asteroid != null && fm.combatRnd.nextBool()) {
            fm.msg("Asteroid hit! (${dmgType}, ${projectedDamage})"); //TODO: reduce asteroid mass? mining?!
            fm.galaxy.slugs.remove(this);
          }
        } //print("Slug: ${p.coord} -> ${pos.coord}, $p -> $pos");
      }
    }
  }

  bool _hitCheck(FugueEngine fm) {
    final ships = fm.galaxy.ships.atLocation(loc).where((s) => s != fromShip);
    if (ships.isNotEmpty) { //TODO: what if we pass over a location?
      final ship = fm.galaxy.ships.atLocation(loc).first; //TODO: choose randomly?
      int totalDmg = 0;
      for (int i=0; i<quantity;i++) {
        if (fm.combatRnd.nextDouble() < toHit) totalDmg += projectedDamage;
      }
      if (totalDmg > 0) { //TODO: factor ship speed, pilot skill, etc.
        fm.msg("Direct hit! (${dmgType}, ${projectedDamage})");
        fm.combatController.damage(ship,totalDmg,dmgType);
      } else {
        fm.msg("${ship.name} dodges $this");
      }
      fm.galaxy.slugs.remove(this); return true;
    }
    return false;
  }

  @override
  String toString() => "${quantity > 1 ? '(x$quantity) ' : ''}${dmgType.name} slug (${fromShip.name})";
}

class CombatController extends FugueController {
  int msgDelay = 0;
  CombatController(super.fm);

  void awaitNextWeapon(Ship? ship) {
    if (ship != null) fm.pilotController.action(ship.pilot,ActionType.combat,actionAuts: ship.turnsUntilWeaponReady);
  }

  void pursue(Ship? ship) {
    if (ship != null) {
      Ship? target = ship.nav.targetShip; if (target != null) {
        final path = ship.loc.map.greedyPath(ship.loc.cell, target.loc.cell, 1, fm.combatRnd);
        final dest = path.firstOrNull?.coord;
        if (dest != null) fm.movementController.moveShip(ship, path.first.loc); //TODO: fix?
      }
    }
  }

  void asteroidEncounter(Ship ship, Asteroid asteroid) {
    final roidPen = (asteroid.mass / Asteroid.maxMass).clamp(0.0, 1.0);
    final speedPen = ship.nav.speedPenalty.clamp(0.0, 1.0);
    final piloting = (ship.pilot.skills[SkillType.piloting] ?? 0.0).clamp(0.0, 1.0);

    // Bigger asteroid + higher speed = more dangerous encounter.
    final hazard = (0.55 * speedPen) + (0.45 * roidPen);

    // Pilot skill reduces the effective chance of collision.
    final collisionChance = (hazard * (1.0 - 0.7 * piloting)).clamp(0.0, 1.0);

    final roll = fm.combatRnd.nextDouble();

    if (roll < collisionChance) {
      final damageAmount = 50 + (950 * speedPen * (0.35 + 0.65 * roidPen)).floor();
      damage(
        ship,
        damageAmount,
        DamageType.kinetic,
        details: "Asteroid Collision!",
      );
    } else {
      if (ship.playship) fm.msg("Asteroid dodged", delay: msgDelay);
    }
  }

  void fire(Ship? ship, Galaxy g, {coolWait = true}) { //FugueEngine.glog("${ship?.name} fires...");
    if (ship != null) {
      Coord3D? target = ship.nav.targetShip?.loc.cell.coord ?? ship.nav.targetLoc?.cell.coord;
      if (target == null) {
        fm.msg("Error: no target", delay: msgDelay); return;
      }
      int mincool = 999;
      final shipLoc = ship.loc;
      final cell = ship.loc.map[target];
      if (shipLoc is ImpulseLocation && cell is ImpulseCell) { //TODO: sector-ranged weapons?
        final results = ship.fireWeapons(cell, fm.combatRnd, ship: ship.nav.targetShip);
        if (results.isEmpty && ship == fm.playerShip) {
          fm.msg("No weapons ready", npc: ship.npc, delay: msgDelay);
        } else if (ship.nav.targetShip != null) {
          for (final result in results) {
            if (result.resultEnum == FireResultEnum.noEnergy) { //TODO: increase energy requirements
              fm.msg("Insufficient energy for ${result.weapon.name}",npc: ship.npc, delay: msgDelay);
            } else {
              if (result.resultEnum == FireResultEnum.ammoWarn) {
                fm.msg("No ammo for ${result.weapon.name}",npc: ship.npc, delay: msgDelay);
              }
              else {
                fm.msg("${ship.name} fires weapon: ${result.weapon.name}", delay: msgDelay);
                if (result.weapon.cooldown < mincool) mincool = result.weapon.cooldown;
                final slug = ImpulseSlug(//ship.pilot.faction.color,
                    objColor: ship.npc ? GameColors.orange : GameColors.white,
                    projectedDamage: result.projectedDamage,
                    quantity: result.clips,
                    toHit: result.weapon.effectiveAccuracy(ship.distance(c: target)),
                    dmgType: result.weapon.dmgType,
                    speed: result.weapon.speed,
                    fromShip: ship,
                    origin: ship.loc.localCoord,
                    target: target);
                g.slugs.register(slug, shipLoc);
                slug.tick(fm);
              }
            }
          }
          fm.pilotController.action(ship.pilot, ActionType.combat, actionAuts: coolWait && mincool < 999 ? mincool : 1);
        }
      } else {
        fm.msg("Wrong firing domain");
      }
    }
  }

  double resistanceReduction(double r) {
    const k = 0.4;
    return 1 - exp(-k * r);
  }

  void damage(Ship ship, int dmg, DamageType dmgType, {String? details}) {
    final suffix = details == null ? "" : " $details";
    final shieldResistance = ship.shieldResistance(dmgType);
    final shieldReduction = resistanceReduction(shieldResistance);
    final netDamage = dmg * (1 - shieldReduction);
    final ShieldHitResult result = ship.takeShieldDamage(netDamage);
    if (result.type == ShieldHitType.absorbed) {
      fm.msg("${ship.name} absorbs ${result.toShield.round()} damage$suffix", delay: msgDelay);
    } else if (result.type == ShieldHitType.efficientBlock) {
      fm.msg("${ship.name} blocks ${netDamage.round()} damage$suffix", delay: msgDelay);
    } else {
      if (result.type == ShieldHitType.phaseCatch) {
        final phased = netDamage - result.toShield - result.toHull;
        fm.msg("${ship.name} phases $phased, absorbs ${result.toShield.round()} damage$suffix", delay: msgDelay);
      } else if (result.toShield > 0) {
        fm.msg("${ship.name} absorbs ${result.toShield.round()} damage$suffix", delay: msgDelay);
      }
      if (result.toHull > 0) {
        final hullResistance = ship.hullResistance(dmgType);
        final hullReduction = resistanceReduction(hullResistance);
        final hullDmg = result.toHull * (1 - hullReduction);
        fm.msg("${ship.name} takes ${hullDmg.round()} hull damage$suffix", delay: msgDelay);
        fm.pilotController.wakePilot(ship.pilot);
        if (ship.takeHullDamage(hullDmg)) explode(ship);
      }
    }
  }

  void explode(Ship ship) {
    fm.msg("${ship.name} explodes!");
    for (final system in ship.systemControl.getInstalledSystems()) {
      if (fm.combatRnd.nextBool()) {
        final cell = ship.loc.cell; if (cell is ImpulseCell) {
          system.damage = 50.0 + fm.combatRnd.nextInt(50);
          fm.galaxy.items.register(system, ship.loc);
        }
      }
    }
    fm.galaxy.ships.remove(ship);
    fm.update();
  }

}