import '../grid.dart';
import '../systems/engines.dart';
import '../systems/ship_system.dart';
import 'stock_pile.dart';

final Map<StockSystem, EngineData> stockEngines = {
  StockSystem.engBasicFedImp: EngineData(
      systemData: ShipSystemData("Mark I Fed Impulse Engine",
      techLvl: StockSystem.engBasicFedImp.techLvl, rarity: StockSystem.engBasicFedImp.rarity,
      mass: 80, baseCost: 300, baseRepairCost: 2, powerDraw: 5),
    domain: Domain.impulse,
    engineType: EngineType.fedMark1,
    efficiency: .5,
    baseAutPerUnitTraversal: 10,
  ),
  StockSystem.engBasicFedSub: EngineData(
    systemData: ShipSystemData("Mark I Fed Sublight Engine",
        techLvl: StockSystem.engBasicFedSub.techLvl, rarity: StockSystem.engBasicFedSub.rarity,
        mass: 80, baseCost: 300, baseRepairCost: 2, powerDraw: 3.3),
    domain: Domain.system,
    engineType: EngineType.fedMark1,
    efficiency: .5,
    baseAutPerUnitTraversal: 10,
  ),
  StockSystem.engBasicFedHyper: EngineData(
    systemData: ShipSystemData("Mark I Fed Hyperdrive Engine",
        techLvl: StockSystem.engBasicFedHyper.techLvl, rarity: StockSystem.engBasicFedHyper.rarity,
        mass: 80, baseCost: 300, baseRepairCost: 2, powerDraw: 8),
    domain: Domain.hyperspace,
    engineType: EngineType.fedMark1,
    efficiency: .5,
    baseAutPerUnitTraversal: 10,
  ),
  StockSystem.engMovSub1: EngineData(
    systemData: ShipSystemData("Mark I Movelian Hyperdrive Engine",
        techLvl: StockSystem.engMovSub1.techLvl, rarity: StockSystem.engMovSub1.rarity,
        mass: 80, baseCost: 1000, baseRepairCost: 2, powerDraw: 12),
    domain: Domain.system,
    engineType: EngineType.moevelian,
    efficiency: .7,
    baseAutPerUnitTraversal: 7,
  ),

};