import 'package:crawlspace_engine/ship/systems/ship_system.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_pile.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_xeno.dart';

class XenoContainer extends ShipSystem {
  double xenoLevel = 0;
  final double capacity;
  final double spellEfficiency;
  final double durability; //protection from damage, stability is result of damage

  XenoContainer(super.name, {
    required this.capacity,
    this.spellEfficiency = 1,
    this.durability = 1,
    required super.manufacturer,
    required super.stability,
    required super.baseCost,
    required super.baseRepairCost,
    required super.repairDifficulty,
    required super.rarity,
    required super.about,
    required super.mass,
    required super.powerDraw});

  factory XenoContainer.fromStock(StockSystem stock) {
      final data = stockXeno[stock]!;
      return XenoContainer(
        data.systemData.name,
        manufacturer: data.systemData.manufacturer,
        mass: data.systemData.mass,
        powerDraw: data.systemData.powerDraw,
        stability: data.systemData.stability,
        baseCost: data.systemData.baseCost,
        baseRepairCost: data.systemData.baseRepairCost,
        repairDifficulty: data.systemData.repairDifficulty,
        rarity: data.systemData.rarity,
        about: data.systemData.about,
        //
        capacity: data.capacity,
        durability: data.durability,
        spellEfficiency: data.spellEfficiency,
      );
  }

  @override
  ShipSystemType get type => ShipSystemType.xenocan;

}

class XenoContainerData {
  final ShipSystemData systemData;
  final double capacity;
  final double spellEfficiency;
  final double durability;

  const XenoContainerData({
    required this.systemData,
    required this.capacity,
    required this.spellEfficiency,
    required this.durability
  });
}