
// ── Goods Archetype ───────────────────────────────────────────────────────────
// Tier 2 — species-specific goods. Each archetype is the mechanical skeleton;
// GoodsGen instantiates it with a generated name and flavor each run.
//
// 4 handcrafted per species + 2 randomly generated = ~48 special goods per run.
// demandDrivers shape intensity within the producing species' territory.
// reach + alienDriver control how demand bleeds into other species' space.

import 'package:crawlspace_engine/stock_items/trade/trade_enums.dart';
import '../../item.dart';
import '../../rng/descriptors.dart';
import '../species.dart';

enum GoodsArchetype {

  // ── Humanoid ────────────────────────────────────────────────────────────────
  federationDocument(
    StockSpecies.humanoid,
    reach: DemandReach.political,
    demandDrivers: {StatType.commerce: 0.7, StatType.fedLevel: 0.9},
    alienDriver: null,   // non-species demand is handled by fedKernel directly
    priceRange: (8, 40),
    desc: "Official Federation paperwork — permits, manifests, charters. "
        "Useless to aliens culturally, invaluable to anyone operating in Fed space.",
  ),
  humanoidRations(
    StockSpecies.humanoid,
    reach: DemandReach.speciesOnly,
    demandDrivers: {StatType.population: 0.9, StatType.fedLevel: 0.5},
    alienDriver: null,
    priceRange: (3, 12),
    desc: "Standardized nutrient blocks. Deeply unpleasant but shelf-stable "
        "for decades. The Federation feeds armies on these.",
  ),
  humNarcotic(
    StockSpecies.humanoid,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.commerce: 0.6, StatType.population: 0.7},
    alienDriver: AlienDemandDriver.commerce,
    priceRange: (12, 55),
    desc: "A broad-spectrum recreational substance. Works on roughly half "
        "of known species; the other half find it mildly explosive.",
  ),
  humMedicine(
    StockSpecies.humanoid,
    reach: DemandReach.speciesOnly,
    demandDrivers: {StatType.population: 0.8, StatType.tech: 0.6},
    alienDriver: null,
    priceRange: (10, 45),
    desc: "Biochemically tailored to humanoid physiology. "
        "Alien use is inadvisable and occasionally fatal.",
  ),

  // ── Vorlon ──────────────────────────────────────────────────────────────────
  voidArtifact(
    StockSpecies.vorlon,
    reach: DemandReach.speciesCore,
    demandDrivers: {StatType.xenomancy: 0.9, StatType.tech: 0.4},
    alienDriver: AlienDemandDriver.xenomancyAndWealth,
    priceRange: (30, 120),
    desc: "Objects recovered from deep void expeditions. "
        "Their function is unclear. Their value is not.",
  ),
  darkEnergyCatalyst(
    StockSpecies.vorlon,
    reach: DemandReach.speciesCore,
    demandDrivers: {StatType.xenomancy: 0.8, StatType.tech: 0.7},
    alienDriver: AlienDemandDriver.xenomancyAndWealth,
    priceRange: (25, 90),
    desc: "Condensed dark energy, stabilized in crystalline suspension. "
        "Essential for Vorlon xenomantic practice. Unsettling to handle.",
  ),
  vorlonBiologics(
    StockSpecies.vorlon,
    reach: DemandReach.speciesOnly,
    demandDrivers: {StatType.population: 0.7, StatType.xenomancy: 0.5},
    alienDriver: null,
    priceRange: (15, 50),
    desc: "Engineered biological compounds specific to Vorlon biochemistry. "
        "Deeply toxic to most other species.",
  ),
  proscribedTexts(
    StockSpecies.vorlon,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.xenomancy: 0.7, StatType.commerce: 0.4},
    alienDriver: AlienDemandDriver.xenomancyAndWealth,
    priceRange: (20, 80),
    desc: "Encrypted Vorlon knowledge archives. The Federation has opinions "
        "about these. So does everyone else.",
  ),

  // ── Greshplerglesnortz ───────────────────────────────────────────────────────
  greshHeavyAlloy(
    StockSpecies.gersh,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.industry: 0.9, StatType.militancy: 0.5},
    alienDriver: AlienDemandDriver.militancy,
    priceRange: (8, 35),
    desc: "Dense structural metal, processed using Greshian gravity-forge "
        "techniques. Prized for its impact resistance.",
  ),
  gravManipulator(
    StockSpecies.gersh,
    reach: DemandReach.speciesCore,
    demandDrivers: {StatType.tech: 0.7, StatType.industry: 0.6},
    alienDriver: AlienDemandDriver.tech,
    priceRange: (20, 75),
    desc: "Crude but effective gravity manipulation tools. Built to last "
        "under conditions that would destroy more elegant instruments.",
  ),
  greshFerment(
    StockSpecies.gersh,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.population: 0.6, StatType.commerce: 0.5},
    alienDriver: AlienDemandDriver.commerce,
    priceRange: (5, 25),
    desc: "Fermented Greshian organic matter. An acquired taste. "
        "A very acquired taste. Most species need several attempts.",
  ),
  greshWarTrophy(
    StockSpecies.gersh,
    reach: DemandReach.speciesCore,
    demandDrivers: {StatType.militancy: 0.8, StatType.xenomancy: 0.3},
    alienDriver: AlienDemandDriver.xenomancyAndWealth,
    priceRange: (15, 60),
    desc: "Ceremonial combat trophies. Among Greshians, gifting one "
        "is either a great honor or a declaration of intent.",
  ),

  // ── Edualx ───────────────────────────────────────────────────────────────────
  antimatterCell(
    StockSpecies.edualx,
    reach: DemandReach.speciesCore,
    demandDrivers: {StatType.tech: 0.9, StatType.industry: 0.5},
    alienDriver: AlienDemandDriver.tech,
    priceRange: (30, 100),
    desc: "Stabilized antimatter in Edualx containment vessels. "
        "Extremely high energy density. Handle with appropriate terror.",
  ),
  edualxPharmaceutical(
    StockSpecies.edualx,
    reach: DemandReach.speciesOnly,
    demandDrivers: {StatType.population: 0.8, StatType.tech: 0.6},
    alienDriver: null,
    priceRange: (12, 45),
    desc: "Neutrino-modulated compounds tuned to Edualx biochemistry. "
        "Completely inert in other species. Mostly.",
  ),
  quantumSchematic(
    StockSpecies.edualx,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.tech: 0.8, StatType.commerce: 0.5},
    alienDriver: AlienDemandDriver.tech,
    priceRange: (20, 80),
    desc: "Edualx-designed quantum circuit schematics. Their antimatter "
        "expertise produces computing architectures no one else has managed.",
  ),
  edualxArtwork(
    StockSpecies.edualx,
    reach: DemandReach.speciesCore,
    demandDrivers: {StatType.wealth: 0.7, StatType.commerce: 0.5},
    alienDriver: AlienDemandDriver.xenomancyAndWealth,
    priceRange: (15, 70),
    desc: "Visual art encoded in antimatter interference patterns. "
        "Requires special viewing equipment. Worth it, reportedly.",
  ),

  // ── Lael ─────────────────────────────────────────────────────────────────────
  chronoRecording(
    StockSpecies.lael,
    reach: DemandReach.speciesCore,
    demandDrivers: {StatType.xenomancy: 0.8, StatType.wealth: 0.6},
    alienDriver: AlienDemandDriver.xenomancyAndWealth,
    priceRange: (25, 95),
    desc: "Temporal impression recordings — experiential memories "
        "captured across time. Deeply disorienting for non-Lael minds.",
  ),
  chronoStabilizer(
    StockSpecies.lael,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.tech: 0.7, StatType.xenomancy: 0.6},
    alienDriver: AlienDemandDriver.tech,
    priceRange: (20, 75),
    desc: "Devices that maintain local temporal coherence. "
        "Increasingly valuable anywhere near chronomantic activity.",
  ),
  laelMeditative(
    StockSpecies.lael,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.commerce: 0.5, StatType.population: 0.6},
    alienDriver: AlienDemandDriver.commerce,
    priceRange: (10, 40),
    desc: "Philosophical texts and meditative aids from Lael tradition. "
        "Unusually popular across species lines. Peaceful civilizations "
        "tend to produce things others find calming.",
  ),
  laelBiologics(
    StockSpecies.lael,
    reach: DemandReach.speciesOnly,
    demandDrivers: {StatType.population: 0.8, StatType.tech: 0.5},
    alienDriver: null,
    priceRange: (10, 38),
    desc: "Lael-specific biochemical compounds. "
        "Harmless to other species but entirely without effect.",
  ),

  // ── Orblix ───────────────────────────────────────────────────────────────────
  gravitationalSurvey(
    StockSpecies.orblix,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.tech: 0.7, StatType.commerce: 0.6},
    alienDriver: AlienDemandDriver.tech,
    priceRange: (15, 55),
    desc: "Precision gravitational mapping data. "
        "Useful for navigation, mining, and things Orblix won't discuss.",
  ),
  exoticMatter(
    StockSpecies.orblix,
    reach: DemandReach.speciesCore,
    demandDrivers: {StatType.tech: 0.8, StatType.xenomancy: 0.6},
    alienDriver: AlienDemandDriver.xenomancyAndWealth,
    priceRange: (35, 110),
    desc: "Matter with unusual gravitational properties, harvested "
        "from Bollox's anomalous gravity wells. "
        "Applications remain mostly theoretical.",
  ),
  orblixCuisine(
    StockSpecies.orblix,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.population: 0.6, StatType.commerce: 0.7},
    alienDriver: AlienDemandDriver.commerce,
    priceRange: (6, 28),
    desc: "Orblix food culture, shaped by low-gravity preparation "
        "techniques. Spherical. Everything is spherical.",
  ),
  orblixBiologics(
    StockSpecies.orblix,
    reach: DemandReach.speciesOnly,
    demandDrivers: {StatType.population: 0.8, StatType.tech: 0.4},
    alienDriver: null,
    priceRange: (10, 35),
    desc: "Biologics calibrated to Orblix physiology. "
        "Low gravity adaptation compounds. Useless off-species.",
  ),

  // ── Moveliean ────────────────────────────────────────────────────────────────
  quantumWeapon(
    StockSpecies.moveliean,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.militancy: 0.9, StatType.tech: 0.6},
    alienDriver: AlienDemandDriver.militancy,
    priceRange: (35, 120),
    desc: "Plasma-quantum weapon components. Moveliean militancy "
        "produces weapons engineering that other species quietly import.",
  ),
  movTacticalData(
    StockSpecies.moveliean,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.militancy: 0.8, StatType.commerce: 0.4},
    alienDriver: AlienDemandDriver.militancy,
    priceRange: (20, 70),
    desc: "Combat intelligence and tactical schematics. "
        "The Federation would very much like to know who's buying these.",
  ),
  movelieanBiologics(
    StockSpecies.moveliean,
    reach: DemandReach.speciesOnly,
    demandDrivers: {StatType.population: 0.7, StatType.militancy: 0.4},
    alienDriver: null,
    priceRange: (10, 38),
    desc: "Combat-enhancement compounds tuned to Moveliean physiology. "
        "Extremely dangerous in non-Moveliean biology.",
  ),
  movIntelligence(
    StockSpecies.moveliean,
    reach: DemandReach.political,
    demandDrivers: {StatType.commerce: 0.6, StatType.fedLevel: 0.7},
    alienDriver: null,
    priceRange: (25, 90),
    desc: "Actionable intelligence about Federation movements and "
        "political vulnerabilities. Everyone wants this. No one admits it.",
  ),

  // ── Krakkar ──────────────────────────────────────────────────────────────────
  krakkarWarTrophy(
    StockSpecies.krakkar,
    reach: DemandReach.speciesCore,
    demandDrivers: {StatType.militancy: 0.9, StatType.wealth: 0.5},
    alienDriver: AlienDemandDriver.xenomancyAndWealth,
    priceRange: (20, 85),
    desc: "Combat trophies with genuine provenance. "
        "Among Krakkar, gifting one to an outsider is a significant statement.",
  ),
  stellarNavData(
    StockSpecies.krakkar,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.commerce: 0.7, StatType.tech: 0.5},
    alienDriver: AlienDemandDriver.commerce,
    priceRange: (15, 50),
    desc: "Deep-space navigation charts from Krakkar raiding expeditions. "
        "Extremely accurate. The methods of acquisition are not discussed.",
  ),
  krakkarWeaponComponent(
    StockSpecies.krakkar,
    reach: DemandReach.crossCultural,
    demandDrivers: {StatType.militancy: 0.9, StatType.industry: 0.5},
    alienDriver: AlienDemandDriver.militancy,
    priceRange: (25, 90),
    desc: "Raw weapon components forged by Krakkar armorers. "
        "Brutal, functional, and disturbingly well-calibrated.",
  ),
  krakkarBiologics(
    StockSpecies.krakkar,
    reach: DemandReach.speciesOnly,
    demandDrivers: {StatType.population: 0.7, StatType.militancy: 0.5},
    alienDriver: null,
    priceRange: (10, 38),
    desc: "Combat-specific biological compounds. "
        "Krakkar physiology is sufficiently unique that cross-species "
        "use results in outcomes best not described here.",
  );

  // ── Fields ───────────────────────────────────────────────────────────────────
  final StockSpecies species;
  final DemandReach reach;
  final Map<StatType, double> demandDrivers;
  final AlienDemandDriver? alienDriver;
  final (int, int) priceRange;
  final String desc;

  const GoodsArchetype(
      this.species, {
        required this.reach,
        required this.demandDrivers,
        required this.alienDriver,
        required this.priceRange,
        required this.desc,
      });

  int get priceFloor => priceRange.$1;
  int get priceCeil  => priceRange.$2;

  // All archetypes for a given species
  static List<GoodsArchetype> forSpecies(StockSpecies s) =>
      values.where((a) => a.species == s).toList();

  @override
  String toString() => enumToString(this, hyphenate: false);
}

// ── SpecialGood ───────────────────────────────────────────────────────────────
// A generated instance of a GoodsArchetype — exists per run, not hardcoded.
// Name and flavor are generated by GoodsGen; mechanics come from the archetype.

class SpecialGood extends Item {
  final GoodsArchetype archetype;
  final bool isHandcrafted; // false = randomly generated this run

  SpecialGood(
      super.name, {
        required super.shortDesc,
        required int baseCost,
        required this.archetype,
        this.isHandcrafted = true,
      })  : super(baseCost: baseCost);

  StockSpecies get species      => archetype.species;
  DemandReach get reach         => archetype.reach;
  int get priceFloor            => archetype.priceFloor;
  int get priceCeil             => archetype.priceCeil;

  @override
  String toString() => '$name [${archetype.species.species.name}] — $baseCost cr';
}
