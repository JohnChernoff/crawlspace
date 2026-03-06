import 'package:crawlspace_engine/stock_items/species.dart';

import '../systems/ship_system.dart';

enum BrandSupport { native, trustedPartner, compatible, thirdParty, needsAdapter } //null: needsAdapter
enum CorpTier {
  budget(.5),    // cheap, common
  standard(1),  // mid-range, widely available
  premium(2),   // expensive, available in wealthy systems
  military(3);  // expensive AND restricted — special acquisition
  final double costMultiplier;
  const CorpTier(this.costMultiplier);
}

enum Corporation {
  genCorp(
      corpName: "GenCorp",
      lore: "GenCorp, Your one stop slot shop",
      products: {
        ShipSystemType.weapon:    CorpTier.budget,
        ShipSystemType.engine:    CorpTier.budget,
        ShipSystemType.power:     CorpTier.budget,
        ShipSystemType.shield:    CorpTier.budget,
        ShipSystemType.emitter:   CorpTier.budget,
        ShipSystemType.launcher:  CorpTier.budget,
        ShipSystemType.converter: CorpTier.budget,
        ShipSystemType.sensor:    CorpTier.budget,
        ShipSystemType.quarters:  CorpTier.budget,
        ShipSystemType.scrapper:  CorpTier.budget,
      },
      brandRelations: {}),

  rimbaud(
      corpName: "Rimbaud Universal",
      lore: "Stellar Service since Stardate 599.431",
      products: {
        ShipSystemType.engine: CorpTier.standard,
        ShipSystemType.power:  CorpTier.premium,   // power is their real specialty
      },
      brandRelations: {
        Corporation.genCorp: BrandSupport.thirdParty,
      }),

  salazar(
      corpName: "Salazar and Suns",
      lore: "Power you can trust",
      products: {
        ShipSystemType.weapon: CorpTier.military,
        ShipSystemType.power:  CorpTier.standard,
      },
      brandRelations: {
        Corporation.genCorp: BrandSupport.thirdParty,
      }),

  bauchmann(
      corpName: "Bauchmann Unlimited",
      lore: "To Infinity and Back",
      products: {
        ShipSystemType.weapon:    CorpTier.military,
        ShipSystemType.launcher:  CorpTier.military,
        ShipSystemType.shield:    CorpTier.standard,
        ShipSystemType.power:     CorpTier.standard,
        ShipSystemType.converter: CorpTier.standard,
      },
      brandRelations: {
        Corporation.genCorp: BrandSupport.thirdParty,
      }),

  nimrod(
      corpName: "Nimrod Galactics",
      lore: "Think Nimrod",
      products: {
        ShipSystemType.engine:   CorpTier.premium,
        ShipSystemType.power:    CorpTier.standard,
        ShipSystemType.weapon:   CorpTier.standard,
        ShipSystemType.launcher: CorpTier.standard,
        ShipSystemType.shield:   CorpTier.standard,
      },
      brandRelations: {
        Corporation.genCorp: BrandSupport.thirdParty,
        Corporation.rimbaud: BrandSupport.compatible,  // engines are their overlap
      }),

  lopez(
      corpName: "Lopez LLC",
      lore: "Automation made Affordable",
      products: {
        ShipSystemType.weapon:    CorpTier.standard,
        ShipSystemType.power:     CorpTier.premium,   // automation/power is their thing
        ShipSystemType.converter: CorpTier.premium,
      },
      brandRelations: {
        Corporation.genCorp:  BrandSupport.thirdParty,
        Corporation.salazar:  BrandSupport.trustedPartner,
      }),

  smythe(
      corpName: "Smythe Industries",
      lore: "The Best of All Worlds",
      products: {
        ShipSystemType.weapon:    CorpTier.standard,
        ShipSystemType.engine:    CorpTier.standard,
        ShipSystemType.power:     CorpTier.standard,
        ShipSystemType.shield:    CorpTier.standard,
        ShipSystemType.emitter:   CorpTier.standard,
        ShipSystemType.launcher:  CorpTier.standard,
        ShipSystemType.converter: CorpTier.standard,
        ShipSystemType.sensor:    CorpTier.standard,
        ShipSystemType.quarters:  CorpTier.standard,
        ShipSystemType.scrapper:  CorpTier.standard,
      },
      brandRelations: {
        Corporation.genCorp:   BrandSupport.compatible,
        Corporation.bauchmann: BrandSupport.trustedPartner,
        Corporation.nimrod:    BrandSupport.compatible,
      }),

  sinclair(
      corpName: "Sinclair Corp",
      lore: "Peak Performance",
      products: {
        ShipSystemType.weapon: CorpTier.military,
        ShipSystemType.engine: CorpTier.premium,
        ShipSystemType.power:  CorpTier.premium,
        ShipSystemType.shield: CorpTier.premium,
      },
      brandRelations: {
        Corporation.genCorp:   BrandSupport.thirdParty,
        Corporation.bauchmann: BrandSupport.trustedPartner,  // licensed
        Corporation.smythe:    BrandSupport.compatible,      // industry standard
        Corporation.lopez:     BrandSupport.thirdParty,      // reverse engineered
      }),

  tanaka(
      corpName: "Tanaka Engineering",
      lore: "Quasar Consistency",  // fixed spelling :)
      products: {
        ShipSystemType.engine: CorpTier.premium,
      },
      brandRelations: {}),

  gregoriev(
      corpName: "Gregoriev",
      lore: "Premium Protection",
      products: {
        ShipSystemType.shield: CorpTier.premium,
      },
      brandRelations: {});

  final String corpName, lore;
  final Map<Corporation, BrandSupport> _brandRelations;
  final Map<ShipSystemType, CorpTier> products;
  final Map<Species,double> speciesRelations = const {};
  BrandSupport getRelations(Corporation corp) => corp == this
      ? BrandSupport.native
      : _brandRelations[corp] ?? BrandSupport.needsAdapter;

  const Corporation({
    required this.corpName,
    required this.lore,
    required this.products,
    required Map<Corporation,BrandSupport> brandRelations,
  }) : _brandRelations = brandRelations;

  CorpTier? tierFor(ShipSystemType category) => products[category];
  bool makes(ShipSystemType category) => products.containsKey(category);
}
