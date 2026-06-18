import 'package:crawlspace_engine/ship/systems/xeno_can.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_pile.dart';
import '../../ship/systems/ship_system.dart';

final Map<StockSystem, XenoContainerData> stockXeno = {
  StockSystem.xenoFed: XenoContainerData(
    systemData: ShipSystemData.fromStock(StockSystem.xenoFed,"Standard Federation Xeno Containment Unit",
        about: "Standard Xeno Containment for authorized Federation use only.",
        mass: 20, baseCost: 20000, baseRepairCost: 200, powerDraw: 1, stability: .5),
    capacity: 8,
    durability: 1,
    spellEfficiency: .75,
  ),
  StockSystem.xenoVor: XenoContainerData(
    systemData: ShipSystemData.fromStock(StockSystem.xenoFed,"Vorlornian Xeno Containment Unit",
        about: "An opaque sphere with an darkly humming Vorlornian Xeno Containment Field inside.",
        mass: 20, baseCost: 50000, baseRepairCost: 500, powerDraw: 1.5, stability: .8),
    capacity: 16,
    durability: 1,
    spellEfficiency: 1,
  ),
  StockSystem.xenoLael: XenoContainerData(
    systemData: ShipSystemData.fromStock(StockSystem.xenoFed,"Lael Xeno Containment Unit",
        about: "A brighly colored xenographic pool of mystic energies and lightly controlled cosmic anomolies",
        mass: 20, baseCost: 890000, baseRepairCost: 800, powerDraw: 2.5, stability: .9),
    capacity: 32,
    durability: 1,
    spellEfficiency: 1.25,
  ),
};