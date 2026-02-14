import 'dart:math';

import '../item.dart';

class ShipClassSlot {
  final SystemSlot slot;
  final int num;
  const ShipClassSlot(this.slot,this.num);
}

enum ShipSystemType {
  weapon,launcher,shield,engine,quarters,power,powerConverter,sensor,ammo,unknown;
}

enum SystemSlotType {
  unknown([],[]),
  generic([],ShipSystemType.values),
  //engine,pow,conv
  rimbaud([],[ShipSystemType.engine,ShipSystemType.power,ShipSystemType.powerConverter]),
  //weapon,pow,conv
  salazar([],[ShipSystemType.weapon,ShipSystemType.power,ShipSystemType.powerConverter]),
  //weapon,shield,pow,conv
  bauchmann([],[ShipSystemType.weapon,ShipSystemType.launcher,ShipSystemType.shield,ShipSystemType.power,ShipSystemType.powerConverter]),
  //rimbaud * weapon,shield
  nimrod([SystemSlotType.rimbaud],[ShipSystemType.weapon,ShipSystemType.launcher,ShipSystemType.shield]),
  //salazar * power
  lopez([SystemSlotType.salazar],[ShipSystemType.power]),
  //generic * weapon,shield
  smythe([SystemSlotType.generic],[ShipSystemType.weapon,ShipSystemType.shield]),
  //bauchman,smythe
  sinclair([SystemSlotType.bauchmann,SystemSlotType.smythe],ShipSystemType.values),
  //generic * engine
  tanaka([SystemSlotType.generic, SystemSlotType.rimbaud],[ShipSystemType.engine]),
  //shield
  gregoriev([],[ShipSystemType.shield]);

  final List<SystemSlotType> supportedSlots;
  final List<ShipSystemType> supportedTypes;
  const SystemSlotType(this.supportedSlots, this.supportedTypes);

  SystemSlotType? supports(SystemSlotType type, [Set<SystemSlotType>? visited]) {
    visited ??= {};
    if (visited.contains(this)) return null; // cycle detection
    visited.add(this);
    if (this == type) return this;
    for (final s in supportedSlots) {
      final result = s.supports(type, visited);
      if (result != null) return result;
    }
    return null;
  }
}

class SystemSlot {
  final SystemSlotType type;
  final int generation; //mark
  const SystemSlot(this.type,this.generation);

  bool supports(SystemSlot slot, ShipSystemType type, {ignoreGenerations = false}) {
    if (slot.type == type) {
      if (ignoreGenerations || (generation >= slot.generation)) {
        return this.type.supportedTypes.contains(type);
      }
    }
    else { // Inherited compatibility: generation doesn't matter
      final s = this.type.supports(slot.type);
      if (s != null) {
        return s.supportedTypes.contains(type);
      }
    }
    return false;
  }
  bool supportsSystem(ShipSystem s, {ignoreGenerations = false}) => supports(s.slot,s.type);

  @override
  String toString() {
    return "${type.name}, gen: $generation";
  }
}

abstract class ShipSystem extends Item {
  ShipSystemType get type;
  final SystemSlot slot;
  final double mass; //kilos
  final double baseRepairCost; //credits per 1% repair
  double damage; //% damaged
  int enhancement;
  final int maxEnhancement;
  final double powerDraw; //per 1 aut of use
  final double stability;
  final double repairDifficulty;
  final int techLvl;
  bool active = true;

  ShipSystem(super.name,{  //required this.type,
    required super.baseCost,
    required this.baseRepairCost,
    super.rarity = .1,
    this.techLvl = 1,
    this.damage = 0,
    this.enhancement = 0,
    this.maxEnhancement = 9,
    this.repairDifficulty = .5,
    this.stability = .8,
    this.slot = const SystemSlot(SystemSlotType.generic,1),
    required this.mass,
    required this.powerDraw,
  });

  bool enhance({int i = 1}) {
    int e = min(maxEnhancement,enhancement + i);
    if (e > enhancement) {
      enhancement = e; return true;
    }
    return false;
  }

  double takeDamage(double dmg) {
    final prevDmg = damage;
    damage = min(1,damage + dmg);
    return damage - prevDmg;
  }

  double repair(double r) {
    double dmg = max(damage - r,0);
    if (dmg < damage) {
      final i = damage - dmg;
      damage = dmg; return i;
    } return 0;
  }

  @override
  String toString() {
    return "${super.toString()}, slot: $slot";
  }
}

class ShipSystemData {
  final String name;
  final SystemSlot slot;
  final double mass; //kilos
  final int techLvl;
  final double rarity;
  final int baseCost;
  final double baseRepairCost; //credits per 1% repair
  final int enhancement;
  final int maxEnhancement;
  final double powerDraw; //per 1 aut of use
  final double stability;
  final double repairDifficulty;

  const ShipSystemData(this.name,{
    this.slot = const SystemSlot(SystemSlotType.generic, 1),
    required this.mass,
    required this.baseCost,
    required this.baseRepairCost,
    required this.powerDraw,
    this.rarity = .1,
    this.techLvl = 1,
    this.enhancement = 0,
    this.maxEnhancement = 9,
    this.stability = .8,
    this.repairDifficulty = .5,
  });
}