import 'dart:math';
import '../color.dart';
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
  final double richness;
  final SolidComposition composition;
  final double formationEfficiency;
  final GiantOutcome giantOutcome;

  String get richnessBand {
    if (richness < 0.33) return 'low';
    if (richness < 0.66) return 'medium';
    return 'high';
  }

  const SystemMetadata({
    required this.stellarClasses,
    required this.richness,
    required this.composition,
    required this.formationEfficiency,
    required this.giantOutcome,
  });

  @override
  String toString() {
    return 'SystemMetadata('
        'stars: $stellarClasses, '
        'gas: ${stellarClasses.first.gas}, '
        'richness: $richness, '
        'composition: $composition, '
        'eff: ${formationEfficiency.toStringAsFixed(2)}, '
        'giants: $giantOutcome'
        ')';
  }
}

class SystemMetadataGenerator {
  final Random rnd;

  SystemMetadataGenerator({Random? rnd}) : rnd = rnd ?? Random();

  SystemMetadata generate() {

    final List<StellarClass> stars = [StellarClass.getRndStellarClass(rnd)];
    double extraStarProb = .33; final falloff = .1;
    while (rnd.nextDouble() < extraStarProb) {
      int i =  stars.last == StellarClass.M || rnd.nextDouble() < .77 ? 0 : -1;
      stars.add(stars.elementAt(stars.last.index  - i));
      extraStarProb *= falloff;
    }
    final composition = _rollComposition();
    final richness = rnd.nextDouble();
    final formationEfficiency =
    _calcFormationEfficiency(stars.first, richness, composition);
    final giantOutcome =
    _rollGiantOutcome(stars.first, richness, composition, formationEfficiency);

    return SystemMetadata(
      stellarClasses: stars,
      richness: richness,
      composition: composition,
      formationEfficiency: formationEfficiency,
      giantOutcome: giantOutcome,
    );
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
