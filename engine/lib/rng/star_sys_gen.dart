import 'dart:math';
import 'package:crawlspace_engine/rng/plan_blueprint_gen.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/star.dart';

enum SolidComposition {
  refractoryRich, // rocky-heavy
  balanced,
  volatileRich,   // ice-heavy
}

enum GiantOutcome {
  none,
  stableOuter,
  resonant,
  inwardMigrated,
  chaotic,
}

class SystemMetadata {
  final List<StellarClass> stellarClasses;
  final MultiStarConfig starConfig;      // new
  final double richness;
  final SolidComposition composition;
  final double formationEfficiency;
  final GiantOutcome giantOutcome;
  final List<PlanetBlueprint> planetBlueprints; // new

  String get richnessBand {
    if (richness < 0.33) return 'low';
    if (richness < 0.66) return 'medium';
    return 'high';
  }

  const SystemMetadata({
    required this.stellarClasses,
    required this.starConfig,
    required this.richness,
    required this.composition,
    required this.formationEfficiency,
    required this.giantOutcome,
    required this.planetBlueprints
  });

  SystemMetadata withBlueprints(List<PlanetBlueprint> blueprints) {
    return SystemMetadata(
      stellarClasses: stellarClasses,
      starConfig: starConfig,
      richness: richness,
      composition: composition,
      formationEfficiency: formationEfficiency,
      giantOutcome: giantOutcome,
      planetBlueprints: blueprints,
    );
  }

  @override
  String toString() {
    return 'SystemMetadata('
        'stars: $stellarClasses, '
        'gas: ${stellarClasses.first.gas}, '
        'richness: $richness, '
        'composition: $composition, '
        'eff: ${formationEfficiency.toStringAsFixed(2)}, '
        'giants: $giantOutcome'
        'planets: $planetBlueprints'
        ')';
  }
}

class SystemMetadataGenerator {
  final GridDim systemDim;
  final GridDim impulseDim;
  final Random rnd;

  SystemMetadataGenerator(this.systemDim,this.impulseDim,{Random? rnd}) : rnd = rnd ?? Random();

  SystemMetadata generate() {
    final List<StellarClass> stars = [StellarClass.getRndStellarClass(rnd)];
    double extraStarProb = .33; final falloff = .1;
    while (rnd.nextDouble() < extraStarProb) {
      int i = stars.last == StellarClass.M || rnd.nextDouble() < .77 ? 0 : 1;
      stars.add(StellarClass.values.elementAt(stars.last.index - i));
      extraStarProb *= falloff;
    }
    final composition = _rollComposition();
    final richness = rnd.nextDouble();
    final formationEfficiency =
    _calcFormationEfficiency(stars.first, richness, composition);
    final giantOutcome =
    _rollGiantOutcome(stars.first, richness, composition, formationEfficiency);
    final starConfig = MultiStarConfig.deriveStarConfig(stars, rnd);

    // Build metadata without blueprints first
    final meta = SystemMetadata(
      stellarClasses: stars,
      starConfig: starConfig,
      richness: richness,
      composition: composition,
      formationEfficiency: formationEfficiency,
      giantOutcome: giantOutcome,
      planetBlueprints: const [],  // empty placeholder
    );

    // Now generate blueprints using the complete metadata
    final starPos = starConfig.starPositions(systemDim);
    final blueprints = PlanetBlueprintGenerator(systemDim,impulseDim,rnd: rnd).generate(meta, starPos);

    return meta.withBlueprints(blueprints);
  }

  SolidComposition _rollComposition() {
    final roll = rnd.nextDouble();
    if (roll < 0.25) return SolidComposition.refractoryRich;
    if (roll < 0.75) return SolidComposition.balanced;
    return SolidComposition.volatileRich;
  }

  double _calcFormationEfficiency(
      StellarClass star,
      double richness,
      SolidComposition composition,
      ) {

    double richMod = 0.75 + richness * 0.5;
    double compMod;
    switch (composition) {
      case SolidComposition.refractoryRich:
        compMod = 0.98;
        break;
      case SolidComposition.balanced:
        compMod = 1.0;
        break;
      case SolidComposition.volatileRich:
        compMod = 1.08;
        break;
    }

    return richMod * compMod * star.systemFormationMod;
  }

  GiantOutcome _rollGiantOutcome(
      StellarClass star,
      double richness,
      SolidComposition composition,
      double formationEfficiency,
      ) {
    double giantChance = .66 * richness;

    switch (composition) {
      case SolidComposition.refractoryRich:
        giantChance -= 0.08;
        break;
      case SolidComposition.balanced:
        break;
      case SolidComposition.volatileRich:
        giantChance += 0.12;
        break;
    }

    giantChance += star.giantFormationMod;
    giantChance += (formationEfficiency - 1.0) * 0.25;
    giantChance = giantChance.clamp(0.02, 0.92);

    if (rnd.nextDouble() > giantChance) return GiantOutcome.none;

    final roll = rnd.nextDouble();
    if (roll < 0.45) return GiantOutcome.stableOuter;
    if (roll < 0.70) return GiantOutcome.resonant;
    if (roll < 0.88) return GiantOutcome.inwardMigrated;
    return GiantOutcome.chaotic;
  }
}

enum MultiStarConfig {
  single,          // normal, one star, clean zones
  tightBinary,     // two stars so close they're effectively one —
  // circumbinary planets only, habitable zone pushed out
  wideBinary,      // two stars far apart, each with own planet family,
  // but gravitational interference limits outer planets
  hierarchical;    // tight pair + distant third, messy outer zone


  static MultiStarConfig deriveStarConfig(List<StellarClass> stars, Random rnd) {
    if (stars.length == 1) return MultiStarConfig.single;
    if (stars.length >= 3) return MultiStarConfig.hierarchical;

    // Two stars — tight or wide depends on mass difference
    // Similar mass stars tend toward wider separation
    // Very different mass stars tend toward tight/hierarchical
    final m1 = stars[0].solarMasses;
    final m2 = stars[1].solarMasses;
    final ratio = max(m1, m2) / min(m1, m2);

    return ratio <= 1.5
        ? MultiStarConfig.wideBinary
        : MultiStarConfig.tightBinary;
  }

  List<Coord3D> starPositions(GridDim dim) {
    final cx = dim.mx ~/ 2, cy = dim.my ~/ 2;
    final sepSmall = (dim.maxXY * 0.20).round().clamp(2, 8);
    final sepLarge = (dim.maxXY * 0.35).round().clamp(3, 12);
    return switch (this) {
      MultiStarConfig.single       => [Coord3D(cx, cy, 0)],
      MultiStarConfig.tightBinary  => [Coord3D(cx, cy,0), Coord3D(cx, cy, 0)],
      MultiStarConfig.wideBinary   => [Coord3D(cx-sepSmall, cy,0), Coord3D(cx+sepSmall, cy, 0)],
      MultiStarConfig.hierarchical => [Coord3D(cx, cy,0), Coord3D(cx, cy, 0), Coord3D(cx+sepLarge, cy, 0)],
    };
  }

}



