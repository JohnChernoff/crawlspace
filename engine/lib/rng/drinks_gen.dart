// drink_gen.dart
// Generates a signature alien drink for a planet based on its properties.
// Inputs used:
//   planet.wealth       (0–1) → archetype tier (swill → vintage)
//   planet.techLvl      (0–1) → potency descriptor
//   planet.population   (0–1) → cultural blend (local → exotic import)
//   planet.weirdness    (0–1) → chaos injection
//   dominantSpecies     → name syllable flavor + color tint

import 'dart:math';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/planet.dart';
import 'package:crawlspace_engine/stock_items/species.dart';

import '../color.dart';
import '../item.dart';

class AlienDrink extends Item {
  final double strength; // 0–1, effect on pilot
  final String potency;  // for display/tooltip

  AlienDrink(super.name, {
    required super.desc,
    required super.baseCost,
    required this.strength,
    required this.potency,
    super.objColor,
  });

  @override
  String toString() => '$name ($potency) — $baseCost cr';
}

class DrinkGen {

  // ── Archetypes ──────────────────────────────────────────────────────────────
  // Tiered by wealth: 0=dirt-poor, 1=modest, 2=comfortable, 3=wealthy
  static const List<List<String>> _archetypes = [
    ["Swill", "Rot", "Gut-Wash", "Dregs", "Sludge"],
    ["Brew", "Ale", "Spirits", "Tonic", "Draught"],
    ["Reserve", "Vintage", "Blend", "Distillate", "Extract"],
    ["Elixir", "Essence", "Nectar", "Infusion", "Crystallate"],
  ];

  // ── Potency descriptors ──────────────────────────────────────────────────────
  // Tiered by techLvl: 0=primitive, 1=low, 2=mid, 3=high, 4=extreme
  static const List<List<String>> _potency = [
    ["Weak", "Mild", "Flat"],
    ["Sharp", "Rough", "Bitter"],
    ["Strong", "Potent", "Heady"],
    ["Volatile", "Fierce", "Searing"],
    ["Lethal", "Transcendent", "Singularity-Grade"],
  ];

  // ── Weird overrides ─────────────────────────────────────────────────────────
  static const List<String> _weirdArchetypes = [
    "Paradox", "Void-Drip", "Phase Fluid", "Null Brew",
    "Screaming Tonic", "Anti-Elixir", "Chromatic Slurry",
    "Dream Residue", "Collapsed Matter", "Echo Extract",
  ];

  static const List<String> _weirdAdjectives = [
    "Forbidden", "Inverted", "Haunted", "Recursive",
    "Dimensional", "Screaming", "Crystallized", "Unresolved",
  ];

  // ── Species-flavored syllable pools ─────────────────────────────────────────
  static const Map<String, List<String>> _speciesPrefixes = {
    "Humanoid":            ["Sol", "Ter", "Arc", "Nova", "Star", "Orb"],
    "Vorlon":              ["Vor", "Ulm", "Yon", "Keth", "Zal", "Nyx"],
    "Greshplerglesnortz":  ["Gresh", "Plomp", "Snortz", "Blump", "Glorn"],
    "Skorpl":              ["Skr", "Xok", "Vrax", "Zplit", "Ork"],
    "Lael":                ["Lae", "Syl", "Aer", "Lith", "Vel"],
    "Orblix":              ["Orb", "Lix", "Glob", "Blix", "Rolm"],
    "Moveliean":           ["Mov", "Vel", "Eem", "Liean", "Movi"],
    "Krakkar":             ["Krak", "Arrk", "Thrak", "Kral", "Rrax"],
  };

  static const List<String> _genericPrefixes = [
    "Xar", "Qel", "Vor", "Zyn", "Tal", "Prax", "Khe", "Syr", "Nok", "Gor",
  ];

  static const List<String> _suffixes = [
    "ak", "on", "ix", "ar", "el", "ox", "um", "eth", "ek", "orn",
    "yl", "ax", "an", "oth", "is", "ul", "ven", "al",
  ];

  // ── Descriptions ─────────────────────────────────────────────────────────────
  static const List<String> _descTemplates = [
    "A {potency} local {archetype} with a {note} finish.",
    "Brewed by {species} artisans, this {archetype} is {note}.",
    "A {potency} {archetype} — {note}.",
    "Imported from distant systems, this {archetype} is {note}.",
    "The house {archetype}. {note}.",
  ];

  static const List<String> _flavorNotes = [
    "smoky aftertaste", "hints of stardust", "a faintly metallic bite",
    "surprising warmth", "lingering bitterness", "a clean, cold finish",
    "notes of burnt circuitry", "a faintly luminescent glow",
    "an aroma of deep space", "a curious numbing sensation",
  ];

  static const List<String> _weirdNotes = [
    "it seems to drink you back",
    "colors shift when you look at it sideways",
    "time feels optional after the third sip",
    "it tastes different every time",
    "the glass appears empty even when full",
    "it hums at a frequency you can feel in your teeth",
    "you're not sure if you've already drunk it",
  ];

  // ── Color pools ─────────────────────────────────────────────────────────────
  // Wealth tier → plausible drink colors (low=murky, high=jewel tones)
  static const List<List<GameColor>> _wealthColors = [
    [GameColors.brown, GameColors.olive, GameColors.sienna, GameColors.darkGreen],
    [GameColors.amber, GameColors.tan, GameColors.gold, GameColors.orange],
    [GameColors.red, GameColors.coral, GameColors.teal, GameColors.indigo],
    [GameColors.purple, GameColors.violet, GameColors.darkRed, GameColors.cyan],
  ];

  // Weird colors — things that have no business being in a glass
  static const List<GameColor> _weirdColors = [
    GameColors.neonGreen, GameColors.neonBlue, GameColors.neonPink,
    GameColors.magenta, GameColors.lime, GameColors.cyan,
  ];

  // Species tint — lerped subtly into the base color
  static const Map<String, GameColor> _speciesTint = {
    "Humanoid":           GameColors.amber,
    "Vorlon":             GameColors.indigo,
    "Greshplerglesnortz": GameColors.darkGreen,
    "Skorpl":             GameColors.orange,
    "Lael":               GameColors.cyan,
    "Orblix":             GameColors.teal,
    "Moveliean":          GameColors.violet,
    "Krakkar":            GameColors.coral,
  };

  static GameColor _lerpColor(GameColor a, GameColor b, double t) {
    int lerp(int x, int y) => (x + (y - x) * t).round().clamp(0, 255);
    return GameColor.fromRgb(lerp(a.r, b.r), lerp(a.g, b.g), lerp(a.b, b.b));
  }

  static GameColor _generateColor(int archetypeTier, bool isWeird, Species species, double weirdness, Random rnd) {
    GameColor base = _wealthColors[archetypeTier][rnd.nextInt(_wealthColors[archetypeTier].length)];
    final tint = _speciesTint[species.name];
    if (tint != null) base = _lerpColor(base, tint, 0.1 + rnd.nextDouble() * 0.15);
    if (isWeird) {
      final weirdColor = _weirdColors[rnd.nextInt(_weirdColors.length)];
      base = _lerpColor(base, weirdColor, 0.4 + weirdness * 0.4);
    }
    return base;
  }

  // ── Main generator ───────────────────────────────────────────────────────────
  static AlienDrink generate(Galaxy g, Planet planet, Random rnd, {required double strength}) {
    final species    = g.civMod.dominantSpecies(planet.locale.system) ?? StockSpecies.humanoid.species;
    final wealth     = planet.wealth.clamp(0.0, 1.0);
    final tech       = planet.techLvl.clamp(0.0, 1.0);
    final population = planet.population.clamp(0.0, 1.0);
    final weirdness  = planet.weirdness.clamp(0.0, 1.0);

    final isWeird = rnd.nextDouble() < (weirdness * weirdness); // quadratic: only fires at high weirdness

    // ── Tiers ──
    final archetypeTier = (wealth * (_archetypes.length - 1)).round();
    final potencyTier   = (tech   * (_potency.length   - 1)).round();

    // ── Archetype ──
    final String archetype = isWeird && rnd.nextDouble() < 0.6
        ? _weirdArchetypes[rnd.nextInt(_weirdArchetypes.length)]
        : _archetypes[archetypeTier][rnd.nextInt(_archetypes[archetypeTier].length)];

    // ── Potency label ──
    final String potencyLabel = _potency[potencyTier][rnd.nextInt(_potency[potencyTier].length)];

    // ── Alien name ──
    // High population = more likely to draw exotic foreign syllables
    final bool useLocalSpecies = rnd.nextDouble() > population * 0.6;
    final prefixes = useLocalSpecies
        ? (_speciesPrefixes[species.name] ?? _genericPrefixes)
        : _genericPrefixes;

    final alienName = "${prefixes[rnd.nextInt(prefixes.length)]}${_suffixes[rnd.nextInt(_suffixes.length)]}";

    // ── Name assembly ──
    final String drinkName;
    if (isWeird && rnd.nextDouble() < 0.5) {
      drinkName = "${_weirdAdjectives[rnd.nextInt(_weirdAdjectives.length)]} $alienName $archetype";
    } else if (isWeird) {
      drinkName = "$alienName $archetype";
    } else {
      drinkName = (potencyTier == 0 || potencyTier == _potency.length - 1)
          ? "$potencyLabel $alienName $archetype"
          : "$alienName $archetype";
    }

    // ── Description ──
    final note = isWeird
        ? _weirdNotes[rnd.nextInt(_weirdNotes.length)]
        : _flavorNotes[rnd.nextInt(_flavorNotes.length)];

    final description = _descTemplates[rnd.nextInt(_descTemplates.length)]
        .replaceAll("{potency}", potencyLabel.toLowerCase())
        .replaceAll("{archetype}", archetype.toLowerCase())
        .replaceAll("{species}", species.name)
        .replaceAll("{note}", note);

    // ── Cost ──
    final baseCost = (
        1
            + (wealth * 8)
            + (tech * 2)
            + (isWeird ? 5 + rnd.nextInt(12) : 0)
            + rnd.nextInt(5)
    ).round();

    // ── Color ──
    final color = _generateColor(archetypeTier, isWeird, species, weirdness, rnd);

    return AlienDrink(
      drinkName,
      desc: description,
      baseCost: baseCost,
      strength: strength,
      potency: potencyLabel,
      objColor: color,
    );
  }
}
