import 'package:crawlspace_engine/item.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import 'package:crawlspace_engine/stock_items/corps.dart';
import '../ship/ship.dart';
import '../ship/systems/shields.dart';
import '../ship/systems/ship_system.dart';
import '../ship/systems/weapons.dart';

enum HullMaterial with Resisting {
  basic(1.2,1.5, {},
      1,.1,1,1,.1,.9),
  ablative(1.5,1.5,{Resistance(DamageType.kinetic,level: .5)},
      2,.2,2.5,.8,.2,.66),
  refractive(1.25,1.5,{Resistance(DamageType.photonic,level: .33)},
      2.5,.3,3,.75,.15,.8),
  crystalline(1.75,2,{
    Resistance(DamageType.kinetic,level: .66),
    Resistance(DamageType.plasma,level: .25),
  },5,.4,5,.5,.5,.5),
  hypercarbon(2,1,{
    Resistance(DamageType.fire,level: .66),
    Resistance(DamageType.plasma,level: .5),
    Resistance(DamageType.sonic,level: .5),
  },6.6,.5,20,.1,.25,.75);

  @override
  final Set<Resistance> resists;
  final double integrityMult;
  final double massMult;
  final double speedMult;
  final double baseRepairCost;
  final double repairDifficulty;
  final double unitCost;
  final double rarity;
  final double bulk;

  const HullMaterial(this.integrityMult,this.massMult,this.resists,this.baseRepairCost,this.repairDifficulty,
      this.unitCost, this.rarity, this.bulk, this.speedMult);
}

class Hull extends Item with Resisting {
  HullMaterial material;
  Set<Resistance> get resists => material.resists;
  Hull(this.material,super.name, {super.baseCost, super.rarity, super.volume});
  factory Hull.fromMaterial(HullMaterial material, Ship ship) =>
      Hull(material,"${material.name} hull",
          baseCost: (material.unitCost * ship.volume).round(),
          rarity: material.rarity,
          volume: ship.volume * material.bulk
      );
}

class ShipClassSlot {
  final ShipSystemType type;
  final int num;
  const ShipClassSlot(this.type,this.num);
}

class ShipClass {
  final String name;
  final ShipType type;
  final EngineArch engineArch;
  final Inventory<SystemSlot> slots;
  final double mass, volume, maxXeno, handling;
  final double maxSpeed;
  const ShipClass(this.name,this.type,this.slots,this.mass,this.volume,this.maxXeno,this.engineArch, this.handling, {this.maxSpeed = 2.5});
  factory ShipClass.fromEnum(ShipClassType classType) {
    Inventory<SystemSlot> slotInv = Inventory();
    final allSlots = [...classType.type.slots, ...classType.extras];
    for (final s in allSlots) {
      for (int i=0;i<s.num;i++) slotInv.add(SystemSlot(s.type, classType.corpMap[s.type] ?? Corporation.genCorp));
    }
    return ShipClass(classType.name, classType.type, slotInv, classType.mass, classType.volume, classType.maxXeno,
        classType.engineArch, classType.handling, maxSpeed: classType.maxSpeed);
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
    ShipClassSlot(ShipSystemType.sensor, 1),
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
      mass: 500, volume: 500, maxXeno: 4, maxSpeed: 0.28,  // normal
      corpMap: {
        ShipSystemType.engine: Corporation.rimbaud,
        ShipSystemType.shield: Corporation.smythe,
        ShipSystemType.sensor: Corporation.smythe,
      }),

  ariel("Ariel",
      type: ShipType.scout,
      mass: 500, volume: 450, maxXeno: 6, maxSpeed: 0.30,  // slightly nimbler
      extras: [ShipClassSlot(ShipSystemType.sensor, 1)],
      corpMap: {
        ShipSystemType.engine: Corporation.tanaka,
        ShipSystemType.shield: Corporation.gregoriev,
        ShipSystemType.sensor: Corporation.smythe,
      }),

  // ── Skiffs ────────────────────────────────────────────────────────────────
  hermes("Hermes",
      type: ShipType.skiff,
      mass: 2000, volume: 1500, maxXeno: 6, maxSpeed: 0.35,  // commit
      extras: [ShipClassSlot(ShipSystemType.launcher, 1)],
      engineArch: EngineArch.rear,
      corpMap: {
        ShipSystemType.engine: Corporation.smythe,
        ShipSystemType.shield: Corporation.smythe,
        ShipSystemType.weapon: Corporation.smythe,
        ShipSystemType.launcher: Corporation.bauchmann
      }),

  falcon("Falcon",
      type: ShipType.skiff,
      mass: 500, volume: 700, maxXeno: 4, maxSpeed: 0.28,  // budget, more forgiving
      corpMap: {}),

  // ── Cruisers ──────────────────────────────────────────────────────────────
  orion("Orion",
      type: ShipType.cruiser,
      mass: 1500, volume: 5000, maxXeno: 9, maxSpeed: 0.26,  // normal
      corpMap: {
        ShipSystemType.engine:  Corporation.rimbaud,
        ShipSystemType.power:   Corporation.lopez,
        ShipSystemType.shield:  Corporation.bauchmann,
        ShipSystemType.weapon:  Corporation.bauchmann,
        ShipSystemType.launcher: Corporation.bauchmann,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  perseus("Perseus",
      type: ShipType.cruiser,
      mass: 1500, volume: 5500, maxXeno: 10, maxSpeed: 0.27,
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
      mass: 2000, volume: 5000, maxXeno: 12, maxSpeed: 0.25,  // normal
      corpMap: {
        ShipSystemType.engine:  Corporation.rimbaud,
        ShipSystemType.power:   Corporation.salazar,
        ShipSystemType.shield:  Corporation.bauchmann,
        ShipSystemType.weapon:  Corporation.salazar,
        ShipSystemType.launcher: Corporation.bauchmann,
        ShipSystemType.emitter: Corporation.smythe,
      }),

  nemesis("Nemesis",
      type: ShipType.destroyer,
      mass: 2000, volume: 6000, maxXeno: 12, maxSpeed: 0.24,  // heavier, slightly slower
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
      mass: 1000, volume: 4000, maxXeno: 16, maxSpeed: 0.38,  // commit
      corpMap: {
        ShipSystemType.engine:  Corporation.nimrod,
        ShipSystemType.power:   Corporation.lopez,
        ShipSystemType.shield:  Corporation.smythe,
        ShipSystemType.weapon:  Corporation.nimrod,
        ShipSystemType.launcher: Corporation.bauchmann,
      }),

  raptor("Raptor",
      type: ShipType.interceptor,
      mass: 1000, volume: 3500, maxXeno: 18, maxSpeed: 0.42,  // commit to dangerous
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
      mass: 5000, volume: 7500, maxXeno: 8, maxSpeed: 0.22,  // precise
      corpMap: {
        ShipSystemType.engine:  Corporation.rimbaud,
        ShipSystemType.power:   Corporation.sinclair,
        ShipSystemType.shield:  Corporation.sinclair,
        ShipSystemType.weapon:  Corporation.sinclair,
        ShipSystemType.launcher: Corporation.bauchmann,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  leviathan("Leviathan",
      type: ShipType.battleship,
      mass: 5000, volume: 8000, maxXeno: 8, maxSpeed: 0.20,  // precise, defensive
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
      mass: 8000, volume: 10000, maxXeno: 24, maxSpeed: 0.18,  // precise
      corpMap: {
        ShipSystemType.engine:  Corporation.sinclair,
        ShipSystemType.power:   Corporation.sinclair,
        ShipSystemType.shield:  Corporation.sinclair,
        ShipSystemType.weapon:  Corporation.sinclair,
        ShipSystemType.launcher: Corporation.sinclair,
        ShipSystemType.emitter: Corporation.gregoriev,
        ShipSystemType.quarters: Corporation.smythe,
      }),

  sovereign("Sovereign",
      type: ShipType.flagship,
      mass: 8000, volume: 12000, maxXeno: 30, maxSpeed: 0.17,  // precise
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
      mass: 4000, volume: 20000, maxXeno: 2, maxSpeed: 0.14,  // precise, very slow
      engineArch: EngineArch.rear,
      corpMap: {}),

  condor("Condor",
      type: ShipType.freighter,
      mass: 12000, volume: 18000, maxXeno: 4, maxSpeed: 0.16,  // precise
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
      mass: 5000, volume: 8000, maxXeno: 3, maxSpeed: 0.16,  // precise
      corpMap: {}),

  drayage("Drayage",
      type: ShipType.hauler,
      mass: 5000, volume: 9000, maxXeno: 4, maxSpeed: 0.18,  // armed, slightly aggressive
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
      mass: 50, volume: 200, maxXeno: 8, maxSpeed: 0.45,  // dangerous
      corpMap: {
        ShipSystemType.engine: Corporation.tanaka,
        ShipSystemType.power:  Corporation.rimbaud,
        ShipSystemType.sensor: Corporation.smythe,
      }),

  whisper("Whisper",
      type: ShipType.probe,
      mass: 80, volume: 180, maxXeno: 10, maxSpeed: 0.40,  // dangerous
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
      mass: 800, volume: 3000, maxXeno: 10, maxSpeed: 0.24,  // normal, needs to hold position
      corpMap: {
        ShipSystemType.engine:  Corporation.nimrod,
        ShipSystemType.power:   Corporation.lopez,
        ShipSystemType.shield:  Corporation.gregoriev,
        ShipSystemType.weapon:  Corporation.smythe,
        ShipSystemType.emitter: Corporation.gregoriev,
      }),

  nullfield("Nullfield",
      type: ShipType.emitterBoat,
      mass: 900, volume: 3500, maxXeno: 12, maxSpeed: 0.22,  // normal
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
      mass: 1000, volume: 4000, maxXeno: 6, maxSpeed: 0.30,  // commit — attack platform
      corpMap: {
        ShipSystemType.engine:  Corporation.nimrod,
        ShipSystemType.power:   Corporation.salazar,
        ShipSystemType.shield:  Corporation.smythe,
        ShipSystemType.weapon:  Corporation.salazar,
        ShipSystemType.launcher: Corporation.bauchmann,
      }),

  apocalypse("Apocalypse",
      type: ShipType.gunship,
      mass: 1000, volume: 5000, maxXeno: 4, maxSpeed: 0.28,  // commit
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
  final double mass, volume, maxXeno, maxSpeed;
  final EngineArch engineArch;
  final double handling;

  const ShipClassType(this.className, {
    required this.type,
    required this.mass,
    required this.volume,
    required this.maxXeno,
    required this.maxSpeed,
    this.engineArch = EngineArch.center,
    this.handling = 1,
    this.extras = const [],
    this.corpMap = const {},
  });
}
