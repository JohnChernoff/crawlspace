// goods_gen.dart
// Generates SpecialGood instances from GoodsArchetype skeletons.
// Inputs used:
//   archetype         → name template pool, description templates, price range
//   species           → syllable flavor for alien name component
//   planet.weirdness  → chaos injection into name/desc (for random goods)
//   rnd               → all randomness, seeded from galaxy seed for consistency
//
// Two entry points:
//   GoodsGen.fromArchetype() — handcrafted goods, archetype explicitly provided
//   GoodsGen.generateRandom() — random goods, archetype picked by species traits

import 'dart:math';
import 'package:crawlspace_engine/stock_items/species.dart';

import '../stock_items/trade/goods.dart';
import '../stock_items/trade/trade_enums.dart';

class GoodsGen {

  // ── Species syllable pools ────────────────────────────────────────────────
  // Same pools as DrinkGen for consistency — names should feel like
  // they come from the same linguistic universe.
  static const Map<String, List<String>> _speciesPrefixes = {
    "Humanoid":            ["Sol", "Ter", "Arc", "Nova", "Fed", "Reg"],
    "Vorlon":              ["Vor", "Ulm", "Yon", "Keth", "Zal", "Nyx"],
    "Greshplerglesnortz":  ["Gresh", "Plomp", "Snortz", "Blump", "Glorn"],
    "Edualx":              ["Edu", "Zarm", "Nex", "Qual", "Antim"],
    "Lael":                ["Lae", "Syl", "Aer", "Lith", "Vel"],
    "Orblix":              ["Orb", "Lix", "Glob", "Blix", "Rolm"],
    "Moveliean":           ["Mov", "Vel", "Eem", "Liean", "Strik"],
    "Krakkar":             ["Krak", "Arrk", "Thrak", "Kral", "Rrax"],
  };

  static const List<String> _suffixes = [
    "ak", "on", "ix", "ar", "el", "ox", "um", "eth",
    "yl", "ax", "an", "oth", "is", "ul", "ven", "al",
  ];

  // ── Per-archetype name template pools ────────────────────────────────────
  // {species} = species name, {adj} = adjective, {noun} = alien syllable word
  // Templates are picked randomly; pools below fill the slots.
  static const Map<GoodsArchetype, List<String>> _nameTemplates = {
    // Humanoid
    GoodsArchetype.federationDocument: [
      "{adj} {species} {docType}",
      "Certified {species} {docType}",
      "{species} {docType} ({adj})",
      "Official {docType} — {adj}",
    ],
    GoodsArchetype.humanoidRations: [
      "{species} Standard {noun} Block",
      "{adj} {species} Ration Pack",
      "{noun} Nutrient Concentrate",
      "Grade-{adj} {species} Provisions",
    ],
    GoodsArchetype.humNarcotic: [
      "{adj} {noun}",
      "{noun} {substanceType}",
      "Refined {noun} {substanceType}",
      "{species} {noun} Compound",
    ],
    GoodsArchetype.humMedicine: [
      "{species} {noun} Serum",
      "{adj} {noun} Compound",
      "{noun} Pharmaceutical",
      "{species} Biomedical {noun}",
    ],

    // Vorlon
    GoodsArchetype.voidArtifact: [
      "{noun} of the {voidTerm}",
      "{adj} {noun} Remnant",
      "{species} Void-{noun}",
      "{voidTerm} {noun} Shard",
    ],
    GoodsArchetype.darkEnergyCatalyst: [
      "{adj} {noun} Catalyst",
      "{species} Dark-{noun}",
      "{noun} Energy {noun2}",
      "Condensed {voidTerm} {noun}",
    ],
    GoodsArchetype.vorlonBiologics: [
      "{species} {noun} Compound",
      "{adj} {species} Biologics",
      "{noun} Suspension",
      "{species} {noun} Extract",
    ],
    GoodsArchetype.proscribedTexts: [
      "{adj} {species} {textType}",
      "Encrypted {species} {textType}",
      "{species} {textType} — {adj}",
      "{noun} Knowledge Archive",
    ],

    // Greshplerglesnortz
    GoodsArchetype.greshHeavyAlloy: [
      "{species} {noun} Alloy",
      "{adj} {noun} Composite",
      "Gravity-Forged {noun}",
      "{noun} Structural {noun2}",
    ],
    GoodsArchetype.gravManipulator: [
      "{species} {noun} Manipulator",
      "{adj} Grav-{noun}",
      "{noun} Gravity Tool",
      "{species} {noun} Device",
    ],
    GoodsArchetype.greshFerment: [
      "{species} {noun} Ferment",
      "{adj} {noun} Mash",
      "{noun} Organic Ferment",
      "{species} Fermented {noun}",
    ],
    GoodsArchetype.greshWarTrophy: [
      "{species} {noun} Trophy",
      "{adj} {noun} Relic",
      "Combat {noun} — {species}",
      "{noun} of {adj} Victory",
    ],

    // Edualx
    GoodsArchetype.antimatterCell: [
      "{species} Antimatter {noun}",
      "{adj} {noun} Cell",
      "Stabilized {noun} Vessel",
      "{noun} Antimatter {noun2}",
    ],
    GoodsArchetype.edualxPharmaceutical: [
      "{species} {noun} Compound",
      "{adj} Neutrino-{noun}",
      "{noun} Pharmaceutical",
      "{species} {noun} Modulator",
    ],
    GoodsArchetype.quantumSchematic: [
      "{species} Quantum {noun}",
      "{adj} {noun} Schematic",
      "{noun} Circuit Design",
      "{species} {noun} Blueprint",
    ],
    GoodsArchetype.edualxArtwork: [
      "{species} {noun} Impression",
      "{adj} Antimatter {noun}",
      "{noun} Interference {noun2}",
      "{species} {adj} Artwork",
    ],

    // Lael
    GoodsArchetype.chronoRecording: [
      "{adj} Chrono-{noun}",
      "{species} Temporal {noun}",
      "{noun} Time Impression",
      "{species} {noun} Recording",
    ],
    GoodsArchetype.chronoStabilizer: [
      "{species} {noun} Stabilizer",
      "{adj} Temporal {noun}",
      "{noun} Coherence {noun2}",
      "Chrono-{noun} Device",
    ],
    GoodsArchetype.laelMeditative: [
      "{species} {noun} Texts",
      "{adj} {species} {textType}",
      "{noun} Meditative Aid",
      "{species} {noun} Philosophy",
    ],
    GoodsArchetype.laelBiologics: [
      "{species} {noun} Compound",
      "{adj} {species} Biologics",
      "{noun} Suspension",
      "{species} {noun} Preparation",
    ],

    // Orblix
    GoodsArchetype.gravitationalSurvey: [
      "{species} {noun} Survey",
      "{adj} Grav-{noun} Data",
      "{noun} Mapping {noun2}",
      "{species} {noun} Charts",
    ],
    GoodsArchetype.exoticMatter: [
      "{adj} {noun} Matter",
      "{species} {noun} Sample",
      "Bollox {noun} Extract",
      "{noun} Anomaly {noun2}",
    ],
    GoodsArchetype.orblixCuisine: [
      "{species} {noun} Spheres",
      "{adj} {species} Cuisine",
      "{noun} Orbital Pack",
      "{species} {adj} {noun}",
    ],
    GoodsArchetype.orblixBiologics: [
      "{species} {noun} Compound",
      "{adj} Low-Grav {noun}",
      "{noun} Adaptation {noun2}",
      "{species} {noun} Biologics",
    ],

    // Moveliean
    GoodsArchetype.quantumWeapon: [
      "{species} Quantum {noun}",
      "{adj} Plasma-{noun}",
      "{noun} Weapon {noun2}",
      "{species} {noun} Armament",
    ],
    GoodsArchetype.movTacticalData: [
      "{species} {noun} Intelligence",
      "{adj} {noun} Tactical Data",
      "{noun} Combat {noun2}",
      "{species} {noun} Schematics",
    ],
    GoodsArchetype.movelieanBiologics: [
      "{species} {noun} Compound",
      "{adj} Combat-{noun}",
      "{noun} Enhancement {noun2}",
      "{species} {noun} Biologics",
    ],
    GoodsArchetype.movIntelligence: [
      "{adj} {noun} Intelligence",
      "{species} {noun} Report",
      "{noun} Political {noun2}",
      "Classified {noun} Data",
    ],

    // Krakkar
    GoodsArchetype.krakkarWarTrophy: [
      "{species} {noun} Trophy",
      "{adj} {noun} Spoil",
      "Combat {noun} — {species}",
      "{noun} of the {adj} Hunt",
    ],
    GoodsArchetype.stellarNavData: [
      "{species} {noun} Charts",
      "{adj} Deep-{noun} Data",
      "{noun} Navigation {noun2}",
      "{species} {noun} Coordinates",
    ],
    GoodsArchetype.krakkarWeaponComponent: [
      "{species} {noun} Component",
      "{adj} {noun} Armament",
      "{noun} Forge {noun2}",
      "{species} {noun} Hardware",
    ],
    GoodsArchetype.krakkarBiologics: [
      "{species} {noun} Compound",
      "{adj} Combat-{noun}",
      "{noun} Biological {noun2}",
      "{species} {noun} Biologics",
    ],
  };

  // ── Slot pools ────────────────────────────────────────────────────────────
  // Filled into {adj}, {noun}, {noun2}, {docType} etc. by species flavor.

  static const Map<String, List<String>> _adjPools = {
    "Humanoid":           ["Certified", "Expired", "Redacted", "Classified", "Notarized", "Grade-A"],
    "Vorlon":             ["Forbidden", "Void-Touched", "Collapsed", "Haunted", "Inverted", "Proscribed"],
    "Greshplerglesnortz": ["Heavy-Grade", "Crude", "Forged", "Fermented", "Scarred", "Dense"],
    "Edualx":             ["Stabilized", "Quantum", "Modulated", "Contained", "Refined", "Volatile"],
    "Lael":               ["Temporal", "Resonant", "Chrono-Locked", "Meditative", "Harmonic", "Unresolved"],
    "Orblix":             ["Spherical", "Low-Grav", "Mapped", "Surveyed", "Orbital", "Compressed"],
    "Moveliean":          ["Tactical", "Classified", "Strike-Grade", "Quantum-Hardened", "Encrypted", "Combat"],
    "Krakkar":            ["Battle-Worn", "Plundered", "Forged", "Scarred", "Hunt-Grade", "Raw"],
  };

  // Generic nouns — filled with alien syllable words generated per-call
  // (noun and noun2 are always generated, not from a static pool)

  static const Map<String, List<String>> _specialSlots = {
    "docType":      ["License", "Manifest", "Permit", "Writ", "Charter", "Dispensation"],
    "substanceType":["Compound", "Extract", "Distillate", "Concentrate", "Suspension", "Tincture"],
    "voidTerm":     ["Void", "Deep", "Collapse", "Ancients", "Null", "Abyss"],
    "textType":     ["Archive", "Codex", "Manuscript", "Datastack", "Treatise", "Record"],
  };

  // ── Per-archetype description templates ───────────────────────────────────
  static const Map<GoodsArchetype, List<String>> _descTemplates = {
    GoodsArchetype.federationDocument: [
      "Official {species} paperwork — {adj} and surprisingly hard to forge.",
      "A {adj} {species} document. Essential for operating in Federation space.",
      "{species} bureaucracy made tangible. {note}",
    ],
    GoodsArchetype.humanoidRations: [
      "Standardized {species} nutrition. {note}",
      "Shelf-stable for decades. {note}",
      "The Federation feeds armies on these. {note}",
    ],
    GoodsArchetype.humNarcotic: [
      "A {adj} recreational compound. {note}",
      "Works on roughly half of known species. {note}",
      "Popular in {species} commercial districts. {note}",
    ],
    GoodsArchetype.humMedicine: [
      "Biochemically tailored to {species} physiology. {note}",
      "A {adj} {species} pharmaceutical. {note}",
      "Effective for {species}. Inadvisable for others. {note}",
    ],
    GoodsArchetype.voidArtifact: [
      "Recovered from deep void expeditions. {note}",
      "Its function is unclear. Its value is not. {note}",
      "A {adj} object of uncertain Vorlon origin. {note}",
    ],
    GoodsArchetype.darkEnergyCatalyst: [
      "Condensed dark energy in crystalline suspension. {note}",
      "Essential for Vorlon xenomantic practice. {note}",
      "A {adj} energy catalyst. Unsettling to handle. {note}",
    ],
    GoodsArchetype.vorlonBiologics: [
      "Engineered compounds specific to Vorlon biochemistry. {note}",
      "A {adj} {species} biological preparation. {note}",
      "Deeply toxic to most other species. {note}",
    ],
    GoodsArchetype.proscribedTexts: [
      "Encrypted {species} knowledge archives. {note}",
      "The Federation has opinions about these. {note}",
      "A {adj} {species} datastack. {note}",
    ],
    GoodsArchetype.greshHeavyAlloy: [
      "Dense structural metal, gravity-forge processed. {note}",
      "Prized for its impact resistance. {note}",
      "A {adj} {species} alloy. {note}",
    ],
    GoodsArchetype.gravManipulator: [
      "Crude but effective gravity manipulation tools. {note}",
      "Built to last under conditions that would destroy more elegant instruments. {note}",
      "A {adj} {species} gravity device. {note}",
    ],
    GoodsArchetype.greshFerment: [
      "Fermented {species} organic matter. {note}",
      "An acquired taste. A very acquired taste. {note}",
      "A {adj} {species} ferment. {note}",
    ],
    GoodsArchetype.greshWarTrophy: [
      "Ceremonial combat trophies of {species} origin. {note}",
      "Gifting one is either a great honor or a declaration of intent. {note}",
      "A {adj} {species} trophy. {note}",
    ],
    GoodsArchetype.antimatterCell: [
      "Stabilized antimatter in {species} containment vessels. {note}",
      "Extremely high energy density. Handle with appropriate terror. {note}",
      "A {adj} antimatter cell. {note}",
    ],
    GoodsArchetype.edualxPharmaceutical: [
      "Neutrino-modulated compounds tuned to {species} biochemistry. {note}",
      "Completely inert in other species. Mostly. {note}",
      "A {adj} {species} pharmaceutical. {note}",
    ],
    GoodsArchetype.quantumSchematic: [
      "{species} quantum circuit schematics. {note}",
      "Computing architectures no one else has managed. {note}",
      "A {adj} {species} design schematic. {note}",
    ],
    GoodsArchetype.edualxArtwork: [
      "Visual art encoded in antimatter interference patterns. {note}",
      "Requires special viewing equipment. Worth it, reportedly. {note}",
      "A {adj} {species} artwork. {note}",
    ],
    GoodsArchetype.chronoRecording: [
      "Temporal impression recordings captured across time. {note}",
      "Deeply disorienting for non-{species} minds. {note}",
      "A {adj} {species} chrono-recording. {note}",
    ],
    GoodsArchetype.chronoStabilizer: [
      "Maintains local temporal coherence. {note}",
      "Increasingly valuable anywhere near chronomantic activity. {note}",
      "A {adj} {species} temporal device. {note}",
    ],
    GoodsArchetype.laelMeditative: [
      "Philosophical texts and meditative aids from {species} tradition. {note}",
      "Unusually popular across species lines. {note}",
      "A {adj} {species} philosophical work. {note}",
    ],
    GoodsArchetype.laelBiologics: [
      "{species}-specific biochemical compounds. {note}",
      "Harmless to other species but entirely without effect. {note}",
      "A {adj} {species} biological preparation. {note}",
    ],
    GoodsArchetype.gravitationalSurvey: [
      "Precision gravitational mapping data. {note}",
      "Useful for navigation, mining, and things {species} won't discuss. {note}",
      "A {adj} {species} survey dataset. {note}",
    ],
    GoodsArchetype.exoticMatter: [
      "Matter with unusual gravitational properties from Bollox's gravity wells. {note}",
      "Applications remain mostly theoretical. {note}",
      "A {adj} {species} matter sample. {note}",
    ],
    GoodsArchetype.orblixCuisine: [
      "{species} food culture, shaped by low-gravity preparation techniques. {note}",
      "Spherical. Everything is spherical. {note}",
      "A {adj} {species} food product. {note}",
    ],
    GoodsArchetype.orblixBiologics: [
      "Biologics calibrated to {species} physiology. {note}",
      "Low gravity adaptation compounds. {note}",
      "A {adj} {species} biological preparation. {note}",
    ],
    GoodsArchetype.quantumWeapon: [
      "Plasma-quantum weapon components of {species} manufacture. {note}",
      "Other species quietly import these. {note}",
      "A {adj} {species} weapon component. {note}",
    ],
    GoodsArchetype.movTacticalData: [
      "Combat intelligence and tactical schematics. {note}",
      "The Federation would very much like to know who's buying these. {note}",
      "A {adj} {species} tactical dataset. {note}",
    ],
    GoodsArchetype.movelieanBiologics: [
      "Combat-enhancement compounds tuned to {species} physiology. {note}",
      "Extremely dangerous in non-{species} biology. {note}",
      "A {adj} {species} biological preparation. {note}",
    ],
    GoodsArchetype.movIntelligence: [
      "Actionable intelligence about Federation movements. {note}",
      "Everyone wants this. No one admits it. {note}",
      "A {adj} {species} intelligence report. {note}",
    ],
    GoodsArchetype.krakkarWarTrophy: [
      "Combat trophies with genuine {species} provenance. {note}",
      "Gifting one to an outsider is a significant statement. {note}",
      "A {adj} {species} trophy. {note}",
    ],
    GoodsArchetype.stellarNavData: [
      "Deep-space navigation charts from {species} raiding expeditions. {note}",
      "Extremely accurate. The methods of acquisition are not discussed. {note}",
      "A {adj} {species} navigation dataset. {note}",
    ],
    GoodsArchetype.krakkarWeaponComponent: [
      "Weapon components forged by {species} armorers. {note}",
      "Brutal, functional, and disturbingly well-calibrated. {note}",
      "A {adj} {species} weapon component. {note}",
    ],
    GoodsArchetype.krakkarBiologics: [
      "Combat-specific biological compounds of {species} origin. {note}",
      "Cross-species use results in outcomes best not described here. {note}",
      "A {adj} {species} biological preparation. {note}",
    ],
  };

  // ── Flavor notes — injected into {note} slot ──────────────────────────────
  // Normal notes — grounded, matter-of-fact
  static const List<String> _flavorNotes = [
    "Provenance verified.",
    "Handle with care.",
    "Export restrictions may apply.",
    "Condition: acceptable.",
    "No warranty implied.",
    "Origin: authenticated.",
    "Condition: field-worn.",
    "Inspect before purchase.",
    "Quantity limited.",
    "Certified by no one in particular.",
  ];

  // Weird notes — for high-weirdness planets
  static const List<String> _weirdNotes = [
    "It hums at a frequency you can feel in your bones.",
    "The label has been changed. Recently.",
    "Previous owner: unknown. Outcome: unknown.",
    "Do not expose to temporal fields.",
    "It appears to be observing you.",
    "Recommended storage: not near anything important.",
    "Best consumed before the timeline shifts.",
    "Provenance: complicated.",
  ];

  // ── Alien name generator ──────────────────────────────────────────────────
  static String _alienWord(String speciesName, Random rnd, {bool forceGeneric = false}) {
    final prefixes = forceGeneric
        ? ["Xar", "Qel", "Zyn", "Tal", "Prax", "Khe", "Syr", "Nok"]
        : (_speciesPrefixes[speciesName] ?? ["Xar", "Qel", "Zyn", "Tal"]);
    return "${prefixes[rnd.nextInt(prefixes.length)]}"
        "${_suffixes[rnd.nextInt(_suffixes.length)]}";
  }

  // ── Main entry: handcrafted good ─────────────────────────────────────────
  // Archetype is provided explicitly — used for the 4 handcrafted goods
  // per species. Name and flavor are still generated; mechanics are fixed.
  static SpecialGood fromArchetype(
      GoodsArchetype archetype,
      Random rnd, {
        double weirdness = 0.0,
      }) {
    final speciesName = archetype.species.species.name;
    return _generate(archetype, speciesName, rnd, weirdness: weirdness);
  }

  // ── Main entry: random good ───────────────────────────────────────────────
  // Archetype is chosen by weighting GoodsArchetype values against species
  // traits. Used for the 2 randomly generated goods per species per run.
  static SpecialGood generateRandom(
      StockSpecies stockSpecies,
      Random rnd, {
        double weirdness = 0.0,
        List<GoodsArchetype> exclude = const [],
      }) {
    final sp = stockSpecies.species;
    final candidates = GoodsArchetype.forSpecies(stockSpecies)
        .where((a) => !exclude.contains(a))
        .toList();

    // Weight candidates by how well species traits match archetype demand drivers
    final weights = <GoodsArchetype, double>{};
    for (final a in candidates) {
      double score = 0;
      for (final entry in a.demandDrivers.entries) {
        score += _speciesStat(sp, entry.key) * entry.value;
      }
      weights[a] = score.clamp(0.01, 1.0); // never zero — any archetype is possible
    }

    final archetype = _weightedPick(weights, rnd);
    return _generate(archetype, sp.name, rnd, weirdness: weirdness, isHandcrafted: false);
  }

  // ── Internal generator ────────────────────────────────────────────────────
  static SpecialGood _generate(
      GoodsArchetype archetype,
      String speciesName,
      Random rnd, {
        double weirdness = 0.0,
        bool isHandcrafted = true,
      }) {
    final isWeird = rnd.nextDouble() < (weirdness * weirdness);

    // ── Alien word(s) for {noun} and {noun2} slots ──
    final noun  = _alienWord(speciesName, rnd);
    final noun2 = _alienWord(speciesName, rnd, forceGeneric: true);

    // ── Adjective ──
    final adjPool = _adjPools[speciesName] ?? ["Standard", "Refined", "Processed"];
    final adj = adjPool[rnd.nextInt(adjPool.length)];

    // ── Special slot values ──
    String pickSlot(String key) {
      final pool = _specialSlots[key]!;
      return pool[rnd.nextInt(pool.length)];
    }

    // ── Name ──
    final templates = _nameTemplates[archetype] ?? ["{adj} {noun}"];
    final nameTemplate = templates[rnd.nextInt(templates.length)];
    final name = nameTemplate
        .replaceAll("{species}", speciesName)
        .replaceAll("{adj}",     adj)
        .replaceAll("{noun}",    noun)
        .replaceAll("{noun2}",   noun2)
        .replaceAll("{docType}",      pickSlot("docType"))
        .replaceAll("{substanceType}", pickSlot("substanceType"))
        .replaceAll("{voidTerm}",     pickSlot("voidTerm"))
        .replaceAll("{textType}",     pickSlot("textType"));

    // ── Description ──
    final descTemplates = _descTemplates[archetype] ?? ["{adj} {species} goods. {note}"];
    final descTemplate = descTemplates[rnd.nextInt(descTemplates.length)];
    final note = isWeird
        ? _weirdNotes[rnd.nextInt(_weirdNotes.length)]
        : _flavorNotes[rnd.nextInt(_flavorNotes.length)];

    final desc = descTemplate
        .replaceAll("{species}", speciesName)
        .replaceAll("{adj}",     adj.toLowerCase())
        .replaceAll("{noun}",    noun)
        .replaceAll("{note}",    note);

    // ── Price — within archetype range, nudged by weirdness ──
    final (floor, ceil) = archetype.priceRange;
    final baseCost = (
        floor +
            (ceil - floor) * (0.3 + rnd.nextDouble() * 0.5) +
            (isWeird ? rnd.nextInt(12) : 0)
    ).round().clamp(floor, ceil + 10); // slight ceiling breach for weird goods

    return SpecialGood(
      name,
      desc: desc,
      baseCost: baseCost,
      archetype: archetype,
      isHandcrafted: isHandcrafted,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // Pull a species trait by StatType — bridges species fields to demand drivers
  static double _speciesStat(Species sp, StatType stat) => switch (stat) {
    StatType.tech       => sp.tech,
    StatType.militancy  => sp.militancy,
    StatType.commerce   => sp.commerce,
    StatType.xenomancy  => sp.xenomancy,
    StatType.population => sp.populationDensity,
    StatType.industry   => sp.militancy * 0.5 + sp.commerce * 0.5, // proxy
    StatType.wealth     => sp.commerce,                             // proxy
    StatType.fedLevel   => 1.0 - sp.militancy,                     // proxy: low militancy = fed-adjacent
  };

  static GoodsArchetype _weightedPick(Map<GoodsArchetype, double> weights, Random rnd) {
    final total = weights.values.fold(0.0, (a, b) => a + b);
    double cursor = rnd.nextDouble() * total;
    for (final entry in weights.entries) {
      cursor -= entry.value;
      if (cursor <= 0) return entry.key;
    }
    return weights.keys.lastOrNull ?? GoodsArchetype.federationDocument;
  }
}