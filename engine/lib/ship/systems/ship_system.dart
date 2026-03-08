import 'dart:math';
import 'package:crawlspace_engine/stock_items/corps.dart';
import '../../item.dart';
import '../../stock_items/ship_systems/stock_pile.dart';

enum ShipSystemType {
  weapon(3),
  launcher(3.5),
  engine(2.5),
  shield(2),
  power(1.5),
  emitter(1.25),
  converter(1),
  sensor(.75),
  quarters(.5),
  scrapper(.25),
  ammo(.16), //handled separately in system control
  adapter(.1),
  unknown(0);
  final costMultiplier;
  const ShipSystemType(this.costMultiplier);
}

class SystemSlot with Itemizable {
  final ShipSystemType systemType;
  final Corporation manufacturer;
  double get costMultiplier => (manufacturer.tierFor(systemType)?.costMultiplier ?? 0) * systemType.costMultiplier;
  bool supportsSystem(ShipSystem sys) => supports(sys.type, sys.manufacturer);
  bool supports(ShipSystemType type, Corporation corp) => systemType == type &&
      manufacturer.getRelations(corp) != BrandSupport.needsAdapter;
  const SystemSlot(this.systemType,this.manufacturer);

  @override
  String get name => "${systemType.name} (${manufacturer.corpName})";
  String supportString(ShipSystem sys) => systemType != sys.type
      ? "Unsupported System"
      : manufacturer.getRelations(sys.manufacturer).name;
  String labelFor(ShipSystem sys) => "$name (${supportString(sys)})";
}

abstract class ShipSystem extends Item {
  String get name => "${super.name} (${manufacturer.corpName})";
  String? get flavor => about;
  ShipSystemType get type;
  String get shopDesc => this.toString();
  final Corporation manufacturer;
  final double baseRepairCost; //credits per 1% repair
  String get dmgTxt => "${(damage * 100).round()}";
  double damage; //% damaged
  int enhancement;
  final int maxEnhancement;
  final double powerDraw; //per 1 aut of use
  final double stability;
  final double repairDifficulty;
  final int techLvl;
  bool active = true;
  String about;

  @override
  String get description {
    StringBuffer sb = StringBuffer();
    sb.writeln("Tech Level: $techLvl");
    sb.writeln("Stability: $stability");
    sb.writeln("Repair Cost (per 1% of damage): $baseRepairCost");
    sb.writeln("Power Draw (per aut): $powerDraw");
    sb.writeln("Mass: $mass");
    if (enhancement > 0) sb.writeln("Enhancement: $enhancement");
    return sb.toString();
  }

  ShipSystem(super.name,{  //required this.type,
    required super.baseCost,
    required this.baseRepairCost,
    super.rarity = .1,
    this.techLvl = 1,
    this.damage = 0,
    this.enhancement = 0,
    this.maxEnhancement = 9,
    this.repairDifficulty = .5, //determines which shops can repair this item (currently unused)
    this.stability = .8,
    this.manufacturer = Corporation.genCorp,
    required this.about,
    required super.mass,
    super.volume = 1,
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
    double dmg = min(damage,r);
    damage -= dmg;
    return dmg;
  }

  @override
  String toString() => name;
}

class ShipSystemData {
  final String name;
  final String about;
  final Corporation manufacturer;
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

  ShipSystemData.fromStock(StockSystem stock, this.name, {
    required this.mass,
    required this.baseCost,
    required this.baseRepairCost,
    required this.powerDraw,
    this.stability = .8,
    this.repairDifficulty = .5,
    this.enhancement = 0,
    this.maxEnhancement = 9,
    String? about,
  }) : techLvl = stock.techLvl,
        rarity = stock.rarity,
        manufacturer = stock.manufacturer,
        about = about ?? "A standard-issue ${name}";
}