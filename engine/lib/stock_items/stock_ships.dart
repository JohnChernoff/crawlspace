import 'package:crawlspace_engine/item.dart';
import 'package:crawlspace_engine/stock_items/corps.dart';
import '../ship/ship.dart';
import '../ship/systems/ship_system.dart';
import '../ship/systems/weapons.dart';

enum HullType {
  basic([],1),
  ablative([HullResistance(DamageType.kinetic,.5)],2),
  refractive([HullResistance(DamageType.photonic,.33)],2.5),
  crystalline([
    HullResistance(DamageType.kinetic,.66),
    HullResistance(DamageType.plasma,.25),
  ],5),
  hypercarbon([
    HullResistance(DamageType.fire,.66),
    HullResistance(DamageType.plasma,.5),
    HullResistance(DamageType.sonic,.5),
  ],6.6);
  final List<HullResistance> resistances;
  final double baseRepairCost;
  const HullType(this.resistances,this.baseRepairCost);
}

class ShipClassSlot {
  final ShipSystemType type;
  final int num;
  const ShipClassSlot(this.type,this.num);
}

class ShipClass {
  final String name;
  final ShipType type;
  final Inventory<SystemSlot> slots;
  final double maxMass, maxXeno;
  const ShipClass(this.name,this.type,this.slots,this.maxMass,this.maxXeno);
  factory ShipClass.fromEnum(ShipClassType classType) {
    Inventory<SystemSlot> slotInv = Inventory();
    final allSlots = [...classType.type.slots, ...classType.extras];
    for (final s in allSlots) {
      for (int i=0;i<s.num;i++) slotInv.add(SystemSlot(s.type, classType.corpMap[s.type] ?? Corporation.genCorp));
    }
    return ShipClass(classType.name, classType.type, slotInv, classType.maxMass, classType.maxXeno);
  }
}

enum ShipType {
  scout(0, 1, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 1),
    ShipClassSlot(ShipSystemType.shield, 1),
    ShipClassSlot(ShipSystemType.sensor, 1),
  ]),
  skiff(.3, .8, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 1),
    ShipClassSlot(ShipSystemType.shield, 1),
    ShipClassSlot(ShipSystemType.weapon, 1),
  ]),
  cruiser(.5, .6, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 2),
    ShipClassSlot(ShipSystemType.shield, 1),
    ShipClassSlot(ShipSystemType.weapon, 1),
    ShipClassSlot(ShipSystemType.launcher, 1),
    ShipClassSlot(ShipSystemType.emitter, 1),
  ]),
  destroyer(.66, .4, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 2),
    ShipClassSlot(ShipSystemType.shield, 1),
    ShipClassSlot(ShipSystemType.weapon, 2),
    ShipClassSlot(ShipSystemType.launcher, 1),
    ShipClassSlot(ShipSystemType.emitter, 1),
  ]),
  interceptor(.75, .3, [
    ShipClassSlot(ShipSystemType.engine, 4),  // speed is the point
    ShipClassSlot(ShipSystemType.power, 2),
    ShipClassSlot(ShipSystemType.shield, 1),
    ShipClassSlot(ShipSystemType.weapon, 2),
    ShipClassSlot(ShipSystemType.launcher, 2),
  ]),
  battleship(.9, .2, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 3),
    ShipClassSlot(ShipSystemType.shield, 2),
    ShipClassSlot(ShipSystemType.weapon, 3),
    ShipClassSlot(ShipSystemType.launcher, 3),
    ShipClassSlot(ShipSystemType.emitter, 2),
  ]),
  flagship(.99, .1, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 4),
    ShipClassSlot(ShipSystemType.shield, 3),
    ShipClassSlot(ShipSystemType.weapon, 4),
    ShipClassSlot(ShipSystemType.launcher, 4),
    ShipClassSlot(ShipSystemType.emitter, 3),
    ShipClassSlot(ShipSystemType.quarters, 2),
  ]),
  freighter(.1, .5, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 2),
    ShipClassSlot(ShipSystemType.shield, 1),
    ShipClassSlot(ShipSystemType.converter, 2),
    ShipClassSlot(ShipSystemType.quarters, 2),
  ]),
  hauler(.2, .6, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 1),
    ShipClassSlot(ShipSystemType.shield, 1),
    ShipClassSlot(ShipSystemType.weapon, 1),
    ShipClassSlot(ShipSystemType.converter, 1),
  ]),
  probe(.1, .4, [
    ShipClassSlot(ShipSystemType.engine, 4),  // fast
    ShipClassSlot(ShipSystemType.power, 1),
    ShipClassSlot(ShipSystemType.sensor, 3),  // sensor heavy
  ]),
  emitterBoat(.4, .3, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 2),
    ShipClassSlot(ShipSystemType.shield, 1),
    ShipClassSlot(ShipSystemType.weapon, 1),
    ShipClassSlot(ShipSystemType.emitter, 4),  // the whole point
  ]),
  gunship(.8, .3, [
    ShipClassSlot(ShipSystemType.engine, 3),
    ShipClassSlot(ShipSystemType.power, 3),
    ShipClassSlot(ShipSystemType.shield, 1),
    ShipClassSlot(ShipSystemType.weapon, 4),
    ShipClassSlot(ShipSystemType.launcher, 3),
  ]);

  final double dangerLvl, freq;
  final List<ShipClassSlot> slots;
  const ShipType(this.dangerLvl, this.freq, this.slots);
}

enum ShipClassType {
  // ── Scouts ────────────────────────────────────────────────────────────────
  mentok("Mentok",
      type: ShipType.scout,
      maxMass: 500, maxXeno: 4,
      corpMap: {
        ShipSystemType.engine: Corporation.rimbaud,
        ShipSystemType.shield: Corporation.smythe,
        ShipSystemType.sensor: Corporation.smythe,
      }),

  ariel("Ariel",   // nimble explorer variant
      type: ShipType.scout,
      maxMass: 450, maxXeno: 6,
      extras: [ShipClassSlot(ShipSystemType.sensor, 1)],  // extra sensor
      corpMap: {
        ShipSystemType.engine: Corporation.tanaka,   // tanaka engines = best speed
        ShipSystemType.shield: Corporation.gregoriev,
        ShipSystemType.sensor: Corporation.smythe,
      }),

  // ── Skiffs ────────────────────────────────────────────────────────────────
  hermes("Hermes",
      type: ShipType.skiff,
      maxMass: 750, maxXeno: 6,
      corpMap: {
        ShipSystemType.engine: Corporation.smythe,
        ShipSystemType.shield: Corporation.smythe,
        ShipSystemType.weapon: Corporation.smythe,
      }),

  falcon("Falcon",   // budget skiff, GenCorp throughout
      type: ShipType.skiff,
      maxMass: 700, maxXeno: 4,
      corpMap: {}),    // all GenCorp default

  // ── Cruisers ──────────────────────────────────────────────────────────────
  orion("Orion",
      type: ShipType.cruiser,
      maxMass: 5000, maxXeno: 9,
      corpMap: {
        ShipSystemType.engine:  Corporation.rimbaud,
        ShipSystemType.power:   Corporation.lopez,
        ShipSystemType.shield:  Corporation.bauchmann,
        ShipSystemType.weapon:  Corporation.bauchmann,
        ShipSystemType.launcher: Corporation.bauchmann,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  perseus("Perseus",   // sinclair premium cruiser
      type: ShipType.cruiser,
      maxMass: 5500, maxXeno: 10,
      extras: [ShipClassSlot(ShipSystemType.emitter, 1)],
      corpMap: {
        ShipSystemType.engine:  Corporation.sinclair,
        ShipSystemType.power:   Corporation.sinclair,
        ShipSystemType.shield:  Corporation.sinclair,
        ShipSystemType.weapon:  Corporation.sinclair,
        ShipSystemType.launcher: Corporation.bauchmann,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  // ── Destroyers ────────────────────────────────────────────────────────────
  marduk("Marduk",
      type: ShipType.destroyer,
      maxMass: 5000, maxXeno: 12,
      corpMap: {
        ShipSystemType.engine:  Corporation.rimbaud,
        ShipSystemType.power:   Corporation.salazar,
        ShipSystemType.shield:  Corporation.bauchmann,
        ShipSystemType.weapon:  Corporation.salazar,
        ShipSystemType.launcher: Corporation.bauchmann,
        ShipSystemType.emitter: Corporation.smythe,
      }),

  nemesis("Nemesis",   // heavier destroyer, extra weapon
      type: ShipType.destroyer,
      maxMass: 6000, maxXeno: 12,
      extras: [ShipClassSlot(ShipSystemType.weapon, 1)],
      corpMap: {
        ShipSystemType.engine:  Corporation.nimrod,
        ShipSystemType.power:   Corporation.salazar,
        ShipSystemType.shield:  Corporation.bauchmann,
        ShipSystemType.weapon:  Corporation.salazar,
        ShipSystemType.launcher: Corporation.salazar,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  // ── Interceptors ──────────────────────────────────────────────────────────
  lynx("Lynx",
      type: ShipType.interceptor,
      maxMass: 4000, maxXeno: 16,
      corpMap: {
        ShipSystemType.engine:  Corporation.nimrod,
        ShipSystemType.power:   Corporation.lopez,
        ShipSystemType.shield:  Corporation.smythe,
        ShipSystemType.weapon:  Corporation.nimrod,
        ShipSystemType.launcher: Corporation.bauchmann,
      }),

  raptor("Raptor",   // tanaka engine interceptor — pure speed
      type: ShipType.interceptor,
      maxMass: 3500, maxXeno: 18,
      extras: [ShipClassSlot(ShipSystemType.engine, 1)],
      corpMap: {
        ShipSystemType.engine:  Corporation.tanaka,
        ShipSystemType.power:   Corporation.rimbaud,
        ShipSystemType.shield:  Corporation.gregoriev,
        ShipSystemType.weapon:  Corporation.nimrod,
        ShipSystemType.launcher: Corporation.nimrod,
      }),

  // ── Battleships ───────────────────────────────────────────────────────────
  balrog("Balrog",
      type: ShipType.battleship,
      maxMass: 7500, maxXeno: 8,
      corpMap: {
        ShipSystemType.engine:  Corporation.rimbaud,
        ShipSystemType.power:   Corporation.sinclair,
        ShipSystemType.shield:  Corporation.sinclair,
        ShipSystemType.weapon:  Corporation.sinclair,
        ShipSystemType.launcher: Corporation.bauchmann,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  leviathan("Leviathan",   // extra shields + emitters, defensive monster
      type: ShipType.battleship,
      maxMass: 8000, maxXeno: 8,
      extras: [
        ShipClassSlot(ShipSystemType.shield, 1),
        ShipClassSlot(ShipSystemType.emitter, 2),
      ],
      corpMap: {
        ShipSystemType.engine:  Corporation.rimbaud,
        ShipSystemType.power:   Corporation.sinclair,
        ShipSystemType.shield:  Corporation.gregoriev,
        ShipSystemType.weapon:  Corporation.bauchmann,
        ShipSystemType.launcher: Corporation.bauchmann,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  // ── Flagships ─────────────────────────────────────────────────────────────
  galaxy("Galaxy",
      type: ShipType.flagship,
      maxMass: 10000, maxXeno: 24,
      corpMap: {
        ShipSystemType.engine:  Corporation.sinclair,
        ShipSystemType.power:   Corporation.sinclair,
        ShipSystemType.shield:  Corporation.sinclair,
        ShipSystemType.weapon:  Corporation.sinclair,
        ShipSystemType.launcher: Corporation.sinclair,
        ShipSystemType.emitter: Corporation.gregoriev,
        ShipSystemType.quarters: Corporation.smythe,
      }),

  sovereign("Sovereign",   // pure Sinclair prestige ship
      type: ShipType.flagship,
      maxMass: 12000, maxXeno: 30,
      extras: [
        ShipClassSlot(ShipSystemType.weapon, 1),
        ShipClassSlot(ShipSystemType.emitter, 1),
      ],
      corpMap: {
        ShipSystemType.engine:  Corporation.sinclair,
        ShipSystemType.power:   Corporation.sinclair,
        ShipSystemType.shield:  Corporation.sinclair,
        ShipSystemType.weapon:  Corporation.sinclair,
        ShipSystemType.launcher: Corporation.sinclair,
        ShipSystemType.emitter: Corporation.sinclair,
        ShipSystemType.quarters: Corporation.sinclair,
      }),

  // ── Freighters ────────────────────────────────────────────────────────────
  barge("Barge",
      type: ShipType.freighter,
      maxMass: 20000, maxXeno: 2,
      corpMap: {}),   // all GenCorp — this is the bottom of the market

  condor("Condor",   // Lopez freighter — excellent converters
      type: ShipType.freighter,
      maxMass: 18000, maxXeno: 4,
      extras: [ShipClassSlot(ShipSystemType.converter, 1)],
      corpMap: {
        ShipSystemType.engine:    Corporation.rimbaud,
        ShipSystemType.power:     Corporation.lopez,
        ShipSystemType.converter: Corporation.lopez,
        ShipSystemType.quarters:  Corporation.smythe,
      }),

  // ── Haulers ───────────────────────────────────────────────────────────────
  mule("Mule",
      type: ShipType.hauler,
      maxMass: 8000, maxXeno: 3,
      corpMap: {}),   // GenCorp workhorse

  drayage("Drayage",   // armed hauler
      type: ShipType.hauler,
      maxMass: 9000, maxXeno: 4,
      extras: [ShipClassSlot(ShipSystemType.weapon, 1)],
      corpMap: {
        ShipSystemType.engine:    Corporation.rimbaud,
        ShipSystemType.power:     Corporation.lopez,
        ShipSystemType.weapon:    Corporation.salazar,
        ShipSystemType.converter: Corporation.lopez,
      }),

  // ── Probes ────────────────────────────────────────────────────────────────
  dart("Dart",
      type: ShipType.probe,
      maxMass: 200, maxXeno: 8,
      corpMap: {
        ShipSystemType.engine: Corporation.tanaka,
        ShipSystemType.power:  Corporation.rimbaud,
        ShipSystemType.sensor: Corporation.smythe,
      }),

  whisper("Whisper",   // stealth probe, gregoriev emitters
      type: ShipType.probe,
      maxMass: 180, maxXeno: 10,
      extras: [ShipClassSlot(ShipSystemType.emitter, 2)],
      corpMap: {
        ShipSystemType.engine: Corporation.tanaka,
        ShipSystemType.power:  Corporation.rimbaud,
        ShipSystemType.sensor: Corporation.smythe,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  // ── Emitter Boats ─────────────────────────────────────────────────────────
  aegis("Aegis",
      type: ShipType.emitterBoat,
      maxMass: 3000, maxXeno: 10,
      corpMap: {
        ShipSystemType.engine:  Corporation.nimrod,
        ShipSystemType.power:   Corporation.lopez,
        ShipSystemType.shield:  Corporation.gregoriev,
        ShipSystemType.weapon:  Corporation.smythe,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  nullfield("Nullfield",   // extreme emitter specialist
      type: ShipType.emitterBoat,
      maxMass: 3500, maxXeno: 12,
      extras: [ShipClassSlot(ShipSystemType.emitter, 2)],
      corpMap: {
        ShipSystemType.engine:  Corporation.rimbaud,
        ShipSystemType.power:   Corporation.sinclair,
        ShipSystemType.shield:  Corporation.gregoriev,
        ShipSystemType.weapon:  Corporation.smythe,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  // ── Gunships ──────────────────────────────────────────────────────────────
  hellfire("Hellfire",
      type: ShipType.gunship,
      maxMass: 4000, maxXeno: 6,
      corpMap: {
        ShipSystemType.engine:  Corporation.nimrod,
        ShipSystemType.power:   Corporation.salazar,
        ShipSystemType.shield:  Corporation.smythe,
        ShipSystemType.weapon:  Corporation.salazar,
        ShipSystemType.launcher: Corporation.bauchmann,
      }),

  apocalypse("Apocalypse",   // extra weapons, nothing else
      type: ShipType.gunship,
      maxMass: 5000, maxXeno: 4,
      extras: [
        ShipClassSlot(ShipSystemType.weapon, 2),
        ShipClassSlot(ShipSystemType.launcher, 1),
      ],
      corpMap: {
        ShipSystemType.engine:  Corporation.rimbaud,
        ShipSystemType.power:   Corporation.salazar,
        ShipSystemType.shield:  Corporation.bauchmann,
        ShipSystemType.weapon:  Corporation.salazar,
        ShipSystemType.launcher: Corporation.salazar,
      });

  final String className;
  final Map<ShipSystemType, Corporation> corpMap;
  final List<ShipClassSlot> extras;
  final ShipType type;
  final double maxMass, maxXeno;

  const ShipClassType(this.className, {
    required this.type,
    required this.maxMass,
    required this.maxXeno,
    this.extras = const [],
    this.corpMap = const {},
  });
}
