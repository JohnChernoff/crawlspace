import 'package:crawlspace_engine/stock_items/xenomancy.dart';
import '../grid.dart';
import '../stock_items/stock_engines.dart';
import '../stock_items/stock_pile.dart';
import 'ship_system.dart';

enum EngineEgo {
  none({}),
  nebulizer({Domain.system,Domain.impulse}),
  ionicDampener({Domain.system,Domain.impulse}),
  oortProof({Domain.system}),
  supercharged({Domain.hyperspace,Domain.system,Domain.impulse}),
  afterburner({Domain.impulse});
  final Set<Domain> domains;
  const EngineEgo(this.domains);
}

enum EngineType {
  quantum,
  nuclear,
  etherial,
  gravimetric,
  antimatter;
}

class Engine extends ShipSystem {
  int baseAutPerUnitTraversal; //BAPUT
  double efficiency;
  Domain domain;
  EngineType engineType;
  EngineEgo ego;
  double xenoGen; //per AUT
  Map<XenomancySchool,int> xenoBonus;

  @override
  ShipSystemType get type => ShipSystemType.engine;

  Engine(super.name, {
    super.slot,
    super.rarity,
    super.stability,
    super.repairDifficulty,
    required this.domain,
    required this.engineType,
    this.ego = EngineEgo.none,
    this.xenoGen = .025,
    this.xenoBonus = const {},
    required this.baseAutPerUnitTraversal,
    required this.efficiency,
    required super.baseCost,
    required super.baseRepairCost,
    required super.powerDraw,
    required super.mass});

  factory Engine.fromStock(StockSystem stock) {
    EngineData data = stockEngines[stock]!;
    return Engine(
      data.systemData.name,
      slot: data.systemData.slot,
      mass: data.systemData.mass,
      powerDraw: data.systemData.powerDraw,
      stability: data.systemData.stability,
      baseCost: data.systemData.baseCost,
      baseRepairCost: data.systemData.baseRepairCost,
      repairDifficulty: data.systemData.repairDifficulty,
      rarity: data.systemData.rarity,
      //
      xenoGen: data.xenoGen,
      xenoBonus: data.xenoBonus,
      domain: data.domain,
      engineType: data.engineType,
      ego: data.ego,
      efficiency: data.efficiency,
      baseAutPerUnitTraversal: data.baseAutPerUnitTraversal,
    );
  }
}

class EngineData {
  final ShipSystemData systemData;
  final int baseAutPerUnitTraversal; //BAPUT
  final double efficiency;
  final Domain domain;
  final EngineType engineType;
  final EngineEgo ego;
  final double xenoGen;
  final Map<XenomancySchool,int> xenoBonus;

  const EngineData({
    required this.systemData,
    required this.baseAutPerUnitTraversal,
    required this.efficiency,
    required this.domain,
    required this.engineType,
    this.xenoGen = .025,
    this.xenoBonus = const {},
    this.ego = EngineEgo.none
  });
}


