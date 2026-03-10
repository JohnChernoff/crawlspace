import 'package:crawlspace_engine/stock_items/corps.dart';
import 'package:crawlspace_engine/stock_items/ship_systems/stock_adapters.dart';
import '../../stock_items/ship_systems/stock_pile.dart';
import 'ship_system.dart';

class Adapter extends ShipSystem {

  final Map<Corporation,double> supportList;
  ShipSystem? adapting;

  @override
  String get description {
    StringBuffer sb = StringBuffer();
    sb.writeln(flavor);
    sb.writeln();
    sb.writeln("Supports: ");
    for (final c in supportList.entries) sb.writeln(c);
    sb.writeln(super.description);
    return sb.toString();
  }

  @override
  ShipSystemType get type => ShipSystemType.sensor;

  Adapter(super.name, {
    required this.supportList,
    required super.manufacturer,
    required super.baseCost,
    super.rarity,
    super.stability,
    super.repairDifficulty = .1,
    super.baseRepairCost = 1.0,
    super.powerDraw = 0,
    super.mass = 2.5,
    required super.about,
  });

  factory Adapter.fromStock(StockSystem stock) {
    AdapterData data = stockAdaptors[stock]!;
    return Adapter(
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
      supportList: data.supportList,
    );
  }
}

class AdapterData {
  final ShipSystemData systemData;
  final Map<Corporation,double> supportList;

  const AdapterData({
    required this.systemData,
    required this.supportList,
  });
}


