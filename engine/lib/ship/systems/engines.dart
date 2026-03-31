import 'package:crawlspace_engine/stock_items/xenomancy.dart';
import '../../galaxy/geometry/grid.dart';
import '../../stock_items/ship/stock_engines.dart';
import '../../stock_items/ship/stock_pile.dart';
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

enum EngineArch {
  rear,
  center,
  distributed;

  double get forwardFactor => switch (this) {
    EngineArch.rear => 1.00,
    EngineArch.center => 0.90,
    EngineArch.distributed => 0.82,
  };

  double get lateralFactor  => switch (this) {
    EngineArch.rear => 0.45,
    EngineArch.center => 0.75, // unused — center engines bypass _thrustMultiplier
    EngineArch.distributed => 1.00,
  };

  double get reverseFactor => switch (this) {
    EngineArch.rear => 0.55,
    EngineArch.center => 0.80,
    EngineArch.distributed => 0.95,
  };
}

class Engine extends ShipSystem {
  int baseAutPerUnitTraversal; // BAPUT
  double efficiency;

  /// Hidden movement-model stats.
  /// Keep defaults conservative so existing stock data still works.
  double thrust;
  //double maxSpeed;
  EngineArch arch;
  Domain domain;
  EngineType engineType;
  EngineEgo ego;
  double xenoGen; // per AUT
  Map<XenomancySchool,int> xenoCastBonus;
  Map<XenomancySchool,int> xenoPowerBonus;

  @override
  String get description {
    StringBuffer sb = StringBuffer();
    sb.writeln(flavor);
    sb.writeln();
    if (domain == Domain.hyperspace) {
      sb.writeln("Base aut per hyperspace jump: $baseAutPerUnitTraversal");
    } else {
      sb.writeln("Base aut per unit traversal (BAPUT): $baseAutPerUnitTraversal");
      sb.writeln("Thrust: ${thrust.toStringAsFixed(2)}");
    }
    sb.writeln("Efficiency: $efficiency");
    sb.writeln("Xeno production (per aut): $xenoGen");
    sb.writeln(super.description);
    return sb.toString();
  }

  @override
  ShipSystemType get type => ShipSystemType.engine;

  Engine(super.name, {
    super.manufacturer,
    super.rarity,
    super.stability,
    super.repairDifficulty,
    required this.domain,
    required this.engineType,
    required this.arch,
    this.ego = EngineEgo.none,
    this.xenoGen = .025,
    this.xenoCastBonus = const {},
    this.xenoPowerBonus = const {},
    required this.baseAutPerUnitTraversal,
    required this.efficiency,
    this.thrust = 1000.0,
    required super.baseCost,
    required super.baseRepairCost,
    required super.powerDraw,
    required super.mass,
    required super.about
  });

  factory Engine.fromStock(StockSystem stock) {
    EngineData data = stockEngines[stock]!;
    return Engine(
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
      xenoGen: data.xenoGen,
      xenoCastBonus: data.xenoCastBonus,
      domain: data.domain,
      engineType: data.engineType,
      ego: data.ego,
      efficiency: data.efficiency,
      baseAutPerUnitTraversal: data.baseAutPerUnitTraversal,
      thrust: data.thrust,
      arch: data.arch
    );
  }
}

class EngineData {
  final ShipSystemData systemData;
  final int baseAutPerUnitTraversal;
  final double efficiency;
  final double thrust;
  final Domain domain;
  final EngineType engineType;
  final EngineArch arch;
  final EngineEgo ego;
  final double xenoGen;
  final Map<XenomancySchool,int> xenoCastBonus;
  final Map<XenomancySchool,int> xenoPowerBonus;

  const EngineData({
    required this.systemData,
    required this.baseAutPerUnitTraversal,
    required this.efficiency,
    this.thrust = 100,
    required this.domain,
    required this.engineType,
    required this.arch,
    this.xenoGen = .025,
    this.xenoCastBonus = const {},
    this.xenoPowerBonus = const {},
    this.ego = EngineEgo.none,
  });
}
