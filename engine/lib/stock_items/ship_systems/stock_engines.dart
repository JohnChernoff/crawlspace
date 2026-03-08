import 'package:crawlspace_engine/stock_items/xenomancy.dart';

import '../../galaxy/geometry/grid.dart';
import '../../ship/systems/engines.dart';
import '../../ship/systems/ship_system.dart';
import 'stock_pile.dart';

final Map<StockSystem, EngineData> stockEngines = {
  StockSystem.engBasicFedImp: EngineData(
      systemData: ShipSystemData.fromStock(StockSystem.engBasicFedImp,"Mark I Fed Impulse Engine",
      about: "The original Federation impulse engine design - simple, straightforward, and generally nonexposive.",
      mass: 80, baseCost: 300, baseRepairCost: 2, powerDraw: 5),
    domain: Domain.impulse,
    engineType: EngineType.nuclear,
    efficiency: .5,
    baseAutPerUnitTraversal: 10,
  ),
  StockSystem.engBasicFedSub: EngineData(
    systemData: ShipSystemData.fromStock(StockSystem.engBasicFedSub,"Mark I Fed Sublight Engine",
        about: "The original Federation sublight engine design - simple, straightforward, and generally nonexposive.",
        mass: 80, baseCost: 300, baseRepairCost: 2, powerDraw: 3.3),
    domain: Domain.system,
    engineType: EngineType.nuclear,
    efficiency: .5,
    baseAutPerUnitTraversal: 10,
  ),
  StockSystem.engBasicFedHyper: EngineData(
    systemData: ShipSystemData.fromStock(StockSystem.engBasicFedHyper,"Mark I Fed Hyperdrive Engine",
        about: "The original Federation hyperspace engine design - simple, straightforward, and generally nonexposive.",
        mass: 80, baseCost: 300, baseRepairCost: 2, powerDraw: 8),
    domain: Domain.hyperspace,
    engineType: EngineType.nuclear,
    efficiency: .5,
    baseAutPerUnitTraversal: 10,
  ),
  StockSystem.engMovSub1: EngineData(
    systemData: ShipSystemData.fromStock(StockSystem.engMovSub1,"Mark I Movelian Hyperdrive Engine",
        about: "The Movelians are engine specialists. This particular model is their most basic, designed for moderately demanding travel.",
        mass: 80, baseCost: 1000, baseRepairCost: 2, powerDraw: 12),
    domain: Domain.system,
    engineType: EngineType.nuclear,
    efficiency: .7,
    baseAutPerUnitTraversal: 7,
  ),
  StockSystem.engVorImp1: EngineData(
    systemData: ShipSystemData.fromStock(StockSystem.engVorImp1,"Vorlonian Impluse Coil",
        about: "A fast and, more importantly xeno-enabled product of the Vorlonian Empire.",
        mass: 280, baseCost: 100000, baseRepairCost: 8, powerDraw: 24),
    domain: Domain.impulse,
    engineType: EngineType.antimatter,
    efficiency: .9,
    baseAutPerUnitTraversal: 8,
    xenoGen: .25,
    xenoCastBonus: {XenomancySchool.dark : 2}
  ),

};