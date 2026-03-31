import 'package:crawlspace_engine/ship/systems/adapter.dart';
import 'package:crawlspace_engine/stock_items/corps.dart';
import '../../ship/systems/ship_system.dart';
import 'stock_pile.dart';

final Map<StockSystem, AdapterData> stockAdaptors = {
  StockSystem.adaGenMult: AdapterData(
    systemData: ShipSystemData.fromStock(StockSystem.adaGenMult,"GenCorp Multipass Adapter",
        about: "60% of the time, it works 97% of time.",
        mass: 5.0, baseCost: 80000, baseRepairCost: 5, powerDraw: 0),
    supportList: Map.fromIterable(Corporation.values.map((c) => MapEntry(c,.6))),
  ),
};