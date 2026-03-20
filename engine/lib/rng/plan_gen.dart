import 'dart:math';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/planet.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:crawlspace_engine/rng/descriptors.dart';

class PlanetDescGen {

  // ── Physical line pools ──────────────────────────────────────────────────

  static const Map<EnvType, List<String>> _envCore = {
    EnvType.icy:          ["frozen world", "ice-locked world", "glacial world",
      "frost-scoured world"],
    EnvType.snowy:        ["snow-covered world", "frigid world", "wintry world",
      "perpetually overcast world"],
    EnvType.desert:       ["desert world", "sun-scorched world", "baked-out world",
      "waterless world"],
    EnvType.rocky:        ["rocky world", "barren rock", "cratered world",
      "geologically inert world"],
    EnvType.mountainous:  ["mountainous world", "high-altitude world",
      "vertically challenging world", "ridge-and-canyon world"],
    EnvType.oceanic:      ["ocean world", "water world", "deep-sea world",
      "almost entirely wet world"],
    EnvType.volcanic:     ["volcanic world", "tectonically restless world",
      "actively erupting world", "geologically violent world"],
    EnvType.toxic:        ["toxic world", "chemically hostile world",
      "poisonous world", "biologically aggressive world"],
    EnvType.jungle:       ["jungle world", "overgrown world",
      "aggressively verdant world", "dense-canopy world"],
    EnvType.arboreal:     ["forest world", "arboreal world",
      "old-growth world", "tree-covered world"],
    EnvType.earthlike:    ["temperate world", "habitable world",
      "suspiciously comfortable world", "earth-type world"],
    EnvType.paradisiacal: ["paradise world", "idyllic world",
      "unreasonably pleasant world", "postcard world"],
    EnvType.alluvial:     ["river-delta world", "fertile world",
      "flood-plain world", "mud-rich world"],
    EnvType.arid:         ["arid world", "semi-desert world",
      "dust world", "desiccated world"],
  };

  static const Map<EnvType, List<String>> _envDetail = {
    EnvType.icy: [
      "Perpetual blizzards have buried most early settlements.",
      "Ice sheets kilometers thick hold whatever is underneath them.",
      "The cold here is not dramatic — it's simply total.",
      "Survey teams have found structures under the ice that predate the colony.",
    ],
    EnvType.snowy: [
      "Short summers are spent preparing for the next winter.",
      "The locals have seventeen words for different kinds of wrong weather.",
      "Frozen tundra dominates. The rest is frozen tundra with ambitions.",
      "Seasonal thaw reveals things that were better left buried.",
    ],
    EnvType.desert: [
      "Water is the real currency here, whatever the exchange rate says.",
      "Vast dune seas shift constantly, swallowing whatever gets left behind.",
      "Surface temperatures at midday exceed what most species consider survivable.",
      "The first settlers underestimated it. Some of their equipment is still out there.",
    ],
    EnvType.rocky: [
      "Cratered plains stretch in every direction. Something hit this world hard, repeatedly.",
      "Thin atmosphere offers little protection from what's above.",
      "Ancient impact basins make for dramatic real estate, if nothing else.",
      "The geological record here is mostly a record of violence.",
    ],
    EnvType.mountainous: [
      "Towering ranges make surface travel an act of optimism.",
      "Mineral-rich peaks have been drawing prospectors for centuries. Most don't get rich.",
      "High-altitude settlements cling to cliffsides with impressive stubbornness.",
      "The mountains don't care who claims them.",
    ],
    EnvType.oceanic: [
      "Landmasses account for less than 5% of the surface. The ocean got the rest.",
      "Subsurface thermal vents support ecosystems that have never seen light.",
      "The deep ocean here has been mapped less thoroughly than several nebulae.",
      "Tidal forces churn the seas. What lives down there has adapted accordingly.",
    ],
    EnvType.volcanic: [
      "Active calderas make long-term infrastructure planning an act of faith.",
      "Lava flows regularly reshape the surface, erasing whatever was there before.",
      "Ash clouds have been a permanent feature of the sky for recorded history.",
      "The planet is still deciding what shape it wants to be.",
    ],
    EnvType.toxic: [
      "Unfiltered atmosphere kills in minutes. The locals seem used to this.",
      "Acid rain has stripped everything unprotected down to its essential nature.",
      "The exotic chemistry that makes this world lethal also makes it valuable.",
      "Certain compounds found only here are worth dying for, commercially speaking.",
    ],
    EnvType.jungle: [
      "Dense canopy blocks surface observation from orbit. This suits some parties.",
      "Aggressive flora has reclaimed most of the early settlements.",
      "Biodiversity here is staggering and largely uncatalogued, possibly deliberately.",
      "The jungle doesn't distinguish between infrastructure and food.",
    ],
    EnvType.arboreal: [
      "Old-growth forests cover most of the landmasses and predate the colony by millennia.",
      "The canopy ecosystem is more populated than the surface, and more dangerous.",
      "Something about the ancient trees makes the locals speak quietly.",
      "Logging operations have been attempted. The forest has so far had the last word.",
    ],
    EnvType.earthlike: [
      "Conditions are close enough to standard that most species settle here without complaint.",
      "Moderate seasons, abundant water, breathable atmosphere — suspiciously convenient.",
      "Federation surveyors rated it highly habitable, which is why the waiting list is long.",
      "The comfortable conditions have attracted every kind of settler, which has complicated things.",
    ],
    EnvType.paradisiacal: [
      "Warm seas and mild climate. The weather seems almost deliberate.",
      "Native biodiversity is extraordinary. The preservation laws are even more extraordinary.",
      "Everything about this world suggests it was designed by someone who wanted to show off.",
      "Visitors tend to stay longer than planned. Some never leave. This is not always by choice.",
    ],
    EnvType.alluvial: [
      "Annual floods replenish soil so fertile it's practically aggressive.",
      "Rich river deltas have been feeding populations here since before anyone was counting.",
      "Waterways are the real infrastructure. Roads are a secondary concern.",
      "The land gives generously. The flooding takes some of it back.",
    ],
    EnvType.arid: [
      "Sparse vegetation clings to dry riverbeds with impressive determination.",
      "Underground aquifers are fiercely contested. Water rights here are a blood sport.",
      "Dust storms last for weeks and carry enough grit to strip paint.",
      "The landscape has a spare, exhausted beauty that grows on you, if you survive it.",
    ],
  };

  static const Map<PlanetAge, List<String>> _ageModifier = {
    PlanetAge.newlyColonized: [
      "newly settled", "recently claimed", "freshly colonized",
      "still being figured out",
    ],
    PlanetAge.modern: [
      "modern", "recently developed", "still finding its footing",
      "a generation or two old",
    ],
    PlanetAge.established: [
      "established", "settled", "developed",
      "old enough to have opinions about itself",
    ],
    PlanetAge.longStanding: [
      "long-standing", "well-established", "mature",
      "settled long enough for things to get complicated",
    ],
    PlanetAge.old: [
      "old", "aging", "time-worn",
      "carrying its history visibly",
    ],
    PlanetAge.antiquated: [
      "antiquated", "pre-Federation", "older than most of the infrastructure suggests",
      "settled before anyone was keeping careful records",
    ],
    PlanetAge.ancient: [
      "ancient", "primordial", "one of the oldest known settlements in the sector",
      "so old that what it was before the colony is still being debated",
    ],
  };

  // ── Political line pools ─────────────────────────────────────────────────

  static String _fedDesc(double fedLvl, Random rnd) => switch(fedLvl) {
    > 0.75 => _pick(rnd, [
      "a Federation core world",
      "firmly under ICORP administration",
      "heavily regulated by Federation authority",
      "one of the more surveilled worlds in the sector",
    ]),
    > 0.4  => _pick(rnd, [
      "under partial Federation jurisdiction",
      "Federation-regulated in the ways that matter to ICORP",
      "monitored, though not oppressively so",
      "nominally self-governing, with Federation oversight",
    ]),
    > 0.15 => _pick(rnd, [
      "frontier territory",
      "at the edge of Federation reach",
      "largely self-governing, for what that's worth",
      "beyond reliable Federation oversight",
    ]),
    _      => _pick(rnd, [
      "ungoverned by any recognized authority",
      "lawless in the operational sense",
      "beyond Federation law, and aware of it",
      "operating on its own terms, which vary",
    ]),
  };

  static String _econDesc(Planet p, Random rnd) {
    final pop = p.tier(p.population);
    final comm = p.tier(p.commerce);
    final ind = p.tier(p.industry);

    if (ind == DistrictLvl.heavy && comm == DistrictLvl.none)
      return _pick(rnd, [
        "heavy industrial output with little local trade",
        "an extraction economy — resources leave, not much arrives",
        "strip-mined and running on skeleton crew",
      ]);
    if (comm == DistrictLvl.heavy && ind == DistrictLvl.none)
      return _pick(rnd, [
        "a thriving trade hub that makes nothing itself",
        "commerce-driven, importing everything it needs",
        "merchants outnumber workers by a considerable margin",
      ]);
    if (pop == DistrictLvl.heavy && comm == DistrictLvl.heavy && ind == DistrictLvl.heavy)
      return _pick(rnd, [
        "densely populated and economically significant",
        "one of the more productive worlds in the region",
        "high output across the board — population, trade, and industry",
      ]);
    if (pop == DistrictLvl.none && comm == DistrictLvl.none && ind == DistrictLvl.none)
      return _pick(rnd, [
        "barely inhabited by any measure",
        "more infrastructure than people",
        "sparsely settled and in no hurry to change that",
      ]);
    if (ind == DistrictLvl.heavy)
      return _pick(rnd, [
        "heavily industrialized",
        "dominated by extraction operations",
        "the kind of place where things get made and nobody asks what for",
      ]);
    if (comm == DistrictLvl.heavy)
      return _pick(rnd, [
        "a significant trading center",
        "commerce-oriented, with all that implies",
        "trade traffic is heavy and the locals prefer it that way",
      ]);
    if (pop == DistrictLvl.heavy)
      return _pick(rnd, [
        "densely populated",
        "overcrowded by most reasonable standards",
        "population pressure is a permanent condition",
      ]);
    return _pick(rnd, [
      "modest in most respects",
      "self-sufficient without being prosperous",
      "unremarkable economically, which suits the locals fine",
    ]);
  }

  static const Map<String, List<String>> _speciesCulture = {
    "Humanoid": [
      "ICORP administrative towers dominate the skyline.",
      "Federation surveillance infrastructure is conspicuously present.",
      "Bureaucratic inefficiency is visible at every level of local government.",
      "Corporate signage competes with official Federation markings for prominence.",
      "The locals have the particular wariness of people accustomed to being watched.",
      "Human ambition has left its usual complicated legacy here.",
      "ICORP's presence is felt without being announced.",
    ],
    "Vorlon": [
      "Vorlornian structures are tall, lightless, and offer no windows.",
      "The locals don't encourage questions, and the questions don't encourage answers.",
      "Dark matter readings are elevated. Nobody will explain why.",
      "Vorlornian monks move through the settlement without making eye contact.",
      "There's a persistent sense of being observed that doesn't diminish with time.",
      "What the Vorlornians are doing here has not been made public.",
      "The monastery at the settlement's edge predates the colony by several centuries.",
    ],
    "Greshplerglesnortz": [
      "The settlement appears to have been built, demolished, and rebuilt at least twice.",
      "Greshplergian enthusiasm has left structural damage on several load-bearing walls.",
      "Everything is loud, colorful, and slightly broken in an endearing way.",
      "The locals will help you with anything, whether you want them to or not.",
      "Chaos is the dominant architectural philosophy. It seems to be working.",
      "It's a mess, but a warm and strangely functional one.",
      "Nobody planned this settlement. It happened anyway, and everyone seems happy about it.",
    ],
    "Edualx": [
      "Edualx infrastructure is eerily precise — no wasted space, no redundancy.",
      "The locals communicate in ways that feel slightly post-verbal.",
      "Everything runs perfectly. The perfection is the unsettling part.",
      "Antimatter research facilities hum with the quiet of things that have already decided.",
      "The Edualx don't waste words, space, or energy. They also don't explain themselves.",
      "You get the sense that decisions here were made long before you arrived.",
      "The efficiency is impressive. It is also, somehow, not comforting.",
    ],
    "Lael": [
      "Lael settlements are grown rather than built — organic structures woven into the terrain.",
      "The locals are polite in a way that makes you feel quietly evaluated.",
      "Ancient Lael groves predate the settlement by centuries and are treated accordingly.",
      "Natural preservation is enforced here with a seriousness that borders on theological.",
      "The Lael manage to make hospitality feel like a mild rebuke.",
      "Everything is beautiful, sustainable, and faintly condescending.",
      "You are welcome here. You are also, in some subtle way, on probation.",
    ],
    "Orblix": [
      "Every service has a price. Every price is negotiable. Everything is for sale.",
      "Orblix mercenary contracts are posted publicly as a matter of civic transparency.",
      "The local economy runs on leverage and favors as much as credits.",
      "Corporate flags outnumber any governmental insignia three to one.",
      "The Orblix have monetized things you wouldn't think could be monetized.",
      "Security here is excellent, provided you can afford the current rate.",
      "There are no free lunches here. The lunches will tell you this themselves.",
    ],
    "Moveliean": [
      "Moveliean settlements go deep — most of the real activity is underground.",
      "The surface infrastructure is functional and unadorned. The subsurface is another matter.",
      "Moveliean craftsmanship is evident in every load-bearing structure.",
      "The locals are blunt, reliable, and mildly contemptuous of surface-dwellers.",
      "What they lack in diplomacy they make up for in structural integrity.",
      "Deep-core mining operations run around the clock. The noise travels.",
      "The Moveliean don't build for aesthetics. They build for ten thousand years.",
    ],
    "Krakkar": [
      "Military installations outnumber civilian ones by a significant margin.",
      "Every structure is built to survive bombardment, including the ones that shouldn't need to.",
      "The locals eye outsiders with the particular hostility of people who've won before.",
      "Evidence of past conquest is not hidden — it's displayed.",
      "Krakkar flags fly over buildings that used to belong to someone else.",
      "The atmosphere of low-grade threat is not accidental. It is policy.",
      "Fortifications here predate any known conflict. The Krakkar plan ahead.",
    ],
  };

  // ── Weird line pools ─────────────────────────────────────────────────────

  static const List<String> _weirdLines = [
    "Sensor readings here are consistent, which is itself unusual.",
    "The colony's founding records contain a gap of about eleven years.",
    "Local wildlife behaves as though something larger used to live here.",
    "Equipment calibrated elsewhere tends to drift after a few days on the surface.",
    "Federation records on this world are thorough up to a point, then stop.",
    "The original survey team's notes are available. Their conclusions were redacted.",
    "Residents report the same dream with unusual frequency. Nobody discusses it.",
    "Something happened here before the colony. The geology suggests it was deliberate.",
    "Xenomantic field strength is elevated in ways the textbooks don't account for.",
    "The locals answer questions about the planet's history with questions about yours.",
    "Certain regions of this world do not appear on any public map, for unspecified reasons.",
    "The anomaly readings are consistent and unexplained, which is the concerning kind.",
  ];

  static const List<String> _highWeirdLines = [
    "Three independent survey teams have submitted contradictory reports about this world.",
    "The anomaly index here has no official explanation, which means there is one.",
    "Whatever the Vorlornians were doing here, they finished and left without comment.",
    "Certain regions of this world do not appear on any public map.",
    "The planet's behavior suggests it is aware of being observed.",
    "Something was here before any of the current spacefaring civilizations. It may still be.",
    "Every instrument agrees this world is normal. Every instrument is wrong.",
  ];

  // ── Homeworld special cases ──────────────────────────────────────────────

  static const Map<String, String> _homeworldLines = {
    "Humanoid":           "This is Xaxle — homeworld of humanity and seat of ICORP power. It did not used to look like this.",
    "Vorlon":             "Ubuntov. The Vorlornians do not discuss what happened to the original surface.",
    "Greshplerglesnortz": "Hew — homeworld of the Greshplerglesnortz, who built it, knocked it down, and built it again several times.",
    "Edualx":             "Zarm. The Edualx were optimized here. Whether that was voluntary is a matter of some debate.",
    "Lael":               "Grenz. The Lael have maintained this world in essentially the same condition for twelve thousand years. They are proud of this.",
    "Orblix":             "Bollox. The first thing the Orblix built was a market. The second was everything else.",
    "Moveliean":          "Arkadyz. Ninety percent of the population lives below the surface. The surface is considered the bad neighborhood.",
    "Krakkar":            "Grenz. The Krakkar homeworld. Every structure here was built to outlast whatever comes next.",
  };

  // ── Generator ────────────────────────────────────────────────────────────

  static List<String> generate(Planet p, Galaxy g, Random rnd) {
    final dominant = g.civMod.dominantSpecies(p.locale.system)
        ?? StockSpecies.humanoid.species;

    // Homeworld gets special treatment
    if (p.homeworld && _homeworldLines.containsKey(dominant.name)) {
      return [
        _physicalLine(p, rnd),
        _homeworldLines[dominant.name]!,
        if (p.weirdness > 0.6) _weirdLine(p, rnd),
      ];
    }

    return [
      _physicalLine(p, rnd),
      _politicalLine(p, dominant, rnd),
      if (p.weirdness > 0.6) _weirdLine(p, rnd),
    ];
  }

  // Returns a single String for backwards compatibility with shortDesc
  static String generateShortDesc(Planet p, Galaxy g, Random rnd) =>
      generate(p, g, rnd).join(" ");

  // ── Line builders ────────────────────────────────────────────────────────

  static String _physicalLine(Planet p, Random rnd) {
    final ageMod = _pick(rnd, _ageModifier[p.age]!);
    final envCore = _pick(rnd, _envCore[p.environment]!);
    final envDetail = _pick(rnd, _envDetail[p.environment]!);
    return "${article(ageMod)} $envCore. $envDetail";
  }

  static String _politicalLine(Planet p, Species dominant, Random rnd) {
    final fed = _fedDesc(p.fedLvl, rnd);
    final econ = _econDesc(p, rnd);
    final culture = _pick(rnd,
        _speciesCulture[dominant.name] ?? ["An unremarkable settlement by most accounts."]);
    return "${p.name} is $fed, with $econ. $culture";
  }

  static String _weirdLine(Planet p, Random rnd) {
    final pool = p.weirdness > 0.85 ? _highWeirdLines : _weirdLines;
    return _pick(rnd, pool);
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  static T _pick<T>(Random rnd, List<T> list) =>
      list[rnd.nextInt(list.length)];
}
