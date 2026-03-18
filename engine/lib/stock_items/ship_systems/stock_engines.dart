import 'package:crawlspace_engine/stock_items/xenomancy.dart';
import '../../galaxy/geometry/grid.dart';
import '../../ship/systems/engines.dart';
import '../../ship/systems/ship_system.dart';
import 'stock_pile.dart';

// ── Thrust sizing rationale ───────────────────────────────────────────────────
//
// The impulse map is 8×8 cells.  For throttle.stop to work correctly the ship
// must be able to accelerate AND decelerate within that space.  The constraint
// is:
//
//   stopping_distance = maxSpeed² / (2 * accel)   where accel = thrust / mass
//
// We target a stopping distance of ~3 cells at full speed, leaving room to
// accelerate in the first half of a journey and brake in the second.  Solving:
//
//   thrust = maxSpeed² / (2 * 3) * typicalMass
//
// Typical loaded mass for each class (hull + systems) is estimated below.
// These are intentionally round numbers — balance them in playtesting.
//
//   Hermes/skiff loaded ~900   → thrust_imp ≈ 2.6²/6 * 900 ≈ 1014  → 1000
//   Orion/cruiser loaded ~2200 → thrust_imp ≈ 2.4²/6 * 2200 ≈ 2112 → 2000
//   Marduk/destroyer ~3000     → thrust_imp ≈ 2.4²/6 * 3000 ≈ 2880 → 3000
//   Barge/freighter ~14000     → thrust_imp ≈ 2.0²/6 * 14000 ≈ 9333 → 9000
//
// Sublight (system map) ships travel much farther per move so a lower accel
// is fine — stopping distance matters less there.  Roughly half impulse thrust.
// ─────────────────────────────────────────────────────────────────────────────

final Map<StockSystem, EngineData> stockEngines = {
  StockSystem.engBasicFedImp: EngineData(
    systemData: ShipSystemData.fromStock(
      StockSystem.engBasicFedImp,
      "Mark I Fed Impulse Engine",
      about: "The original Federation impulse engine design - simple, straightforward, and generally nonexplosive.",
      mass: 80,
      baseCost: 300,
      baseRepairCost: 2,
      powerDraw: 5,
    ),
    domain: Domain.impulse,
    engineType: EngineType.nuclear,
    efficiency: .5,
    baseAutPerUnitTraversal: 10,
    thrust: 250,   // accel ≈ 1000/900 ≈ 1.11 → stop from 2.6 in ~3 cells
    arch: EngineArch.center
  ),

  StockSystem.engBasicFedSub: EngineData(
    systemData: ShipSystemData.fromStock(
      StockSystem.engBasicFedSub,
      "Mark I Fed Sublight Engine",
      about: "The original Federation sublight engine design - simple, straightforward, and generally nonexplosive.",
      mass: 80,
      baseCost: 300,
      baseRepairCost: 2,
      powerDraw: 3.3,
    ),
    domain: Domain.system,
    engineType: EngineType.nuclear,
    efficiency: .5,
    baseAutPerUnitTraversal: 10,
    thrust: 500,    // sublight: lower accel is fine, map is much larger
    arch: EngineArch.center
  ),

  StockSystem.engBasicFedHyper: EngineData(
    systemData: ShipSystemData.fromStock(
      StockSystem.engBasicFedHyper,
      "Mark I Fed Hyperdrive Engine",
      about: "The original Federation hyperspace engine design - simple, straightforward, and generally nonexplosive.",
      mass: 80,
      baseCost: 300,
      baseRepairCost: 2,
      powerDraw: 8,
    ),
    domain: Domain.hyperspace,
    engineType: EngineType.nuclear,
    efficiency: .5,
    baseAutPerUnitTraversal: 10,
    thrust: 0,      // unused for non-Newtonian hyperspace
    arch: EngineArch.center
  ),

  StockSystem.engMovSub1: EngineData(
    systemData: ShipSystemData.fromStock(
      StockSystem.engMovSub1,
      "Mark I Movelian Sublight Engine",
      about: "The Movelians are engine specialists. This particular model is their most basic, designed for moderately demanding travel.",
      mass: 80,
      baseCost: 1000,
      baseRepairCost: 2,
      powerDraw: 12,
    ),
    domain: Domain.system,
    engineType: EngineType.nuclear,
    efficiency: .7,
    baseAutPerUnitTraversal: 7,
    thrust: 750,    // better than Fed sub, still sublight so accel is relaxed
    arch: EngineArch.center
  ),

  StockSystem.engVorImp1: EngineData(
    systemData: ShipSystemData.fromStock(
      StockSystem.engVorImp1,
      "Vorlonian Impulse Coil",
      about: "A fast and, more importantly xeno-enabled product of the Vorlonian Empire.",
      mass: 280,
      baseCost: 100000,
      baseRepairCost: 8,
      powerDraw: 24,
    ),
    domain: Domain.impulse,
    engineType: EngineType.antimatter,
    efficiency: .9,
    baseAutPerUnitTraversal: 8,
    thrust: 2000,   // high-end impulse: stop from 3.4 in ~3 cells at ~800kg loaded
    xenoGen: .25,
    xenoCastBonus: {XenomancySchool.dark: 2},
    arch: EngineArch.center
  ),

  StockSystem.engOrbBlock: EngineData(
      systemData: ShipSystemData.fromStock(
        StockSystem.engOrbBlock,
        "Orblix Gravitronic Blockade Runner",
        about: "Goes real fast in a straight line.",
        mass: 280,
        baseCost: 100000,
        baseRepairCost: 8,
        powerDraw: 24,
      ),
      domain: Domain.impulse,
      engineType: EngineType.antimatter,
      efficiency: .9,
      baseAutPerUnitTraversal: 8,
      thrust: 9999,   //
      xenoGen: .25,
      arch: EngineArch.rear
  ),
};
