import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/rng/star_sys_gen.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/planet.dart';
import '../galaxy/star.dart';

/// Orbital zone relative to the frost line.
/// Drives EnvType selection and mass budget.
enum OrbitalZone { inner, habitable, outer, distant }

/// Physical planet type — distinct from EnvType which carries
/// civilization/flavor meaning. This is the astrophysical skeleton.
enum PlanetType { terrestrial, superEarth, iceWorld, gasGiant, icyGiant }

/// Pure physical record produced by SystemMetadataGenerator.
/// No civilization data — that layer is applied later in generatePlanets().
class PlanetBlueprint {
  final PlanetType type;
  final double orbitalRadius;  // grid cells from parent star
  final Coord3D position;      // actual cell on sector map
  final Coord3D starPosition;  // new — position of parent star on sector map
  final bool habitable;
  final bool tidallyLocked;      // new
  final double relativeMass;
  final StellarClass parentStar;

  /// Returns Earth masses for this blueprint.
  /// Uses log-space interpolation within each type's physical range,
  /// since planet mass distributions are log-normal in nature.
  double get earthMasses {
    // Min/max Earth-mass ranges per type, grounded in real astrophysics.
    final (double minM, double maxM) = switch (type) {
      PlanetType.terrestrial => (0.05,  1.5),    // Mercury-ish to slightly above Earth
      PlanetType.superEarth  => (1.5,   10.0),   // 1.5–10 Earth masses
      PlanetType.iceWorld    => (0.01,  1.0),    // Pluto-like to Ganymede-ish
      PlanetType.icyGiant    => (10.0,  50.0),   // Uranus/Neptune territory
      PlanetType.gasGiant    => (50.0,  4000.0), // Saturn up to ~13 Jupiter masses
    };

    // Log-space lerp: feels natural across orders of magnitude.
    final logMin = log(minM);
    final logMax = log(maxM);
    return exp(logMin + relativeMass * (logMax - logMin));
  }

  bool get isGas => type == PlanetType.icyGiant || type == PlanetType.gasGiant;

  OrbitalZone get orbitalZone {
    if (orbitalRadius < parentStar.habitableRadius)  return OrbitalZone.inner;
    if (orbitalRadius < parentStar.frostRadius)      return OrbitalZone.habitable;
    if (orbitalRadius < parentStar.frostRadius * 3)  return OrbitalZone.outer;
    return OrbitalZone.distant;
  }

  const PlanetBlueprint({
    required this.type,
    required this.orbitalRadius,
    required this.position,
    required this.starPosition,
    required this.habitable,
    required this.tidallyLocked,
    required this.relativeMass,
    required this.parentStar,
  });

  static List<EnvType> candidatesFor(
      OrbitalZone zone, PlanetType type, {bool tidallyLocked = false}) {

    // Tidally locked habitable worlds get terminator as primary candidate
    if (tidallyLocked && zone == OrbitalZone.habitable) {
      return [EnvType.terminator, EnvType.earthlike, EnvType.oceanic];
    }

    if (tidallyLocked && zone == OrbitalZone.inner) {
      return [EnvType.volcanic, EnvType.desert, EnvType.arid];
    }

    return switch ((zone, type)) {
      (OrbitalZone.inner, PlanetType.terrestrial) =>
      [EnvType.rocky, EnvType.volcanic, EnvType.desert, EnvType.arid],
      (OrbitalZone.habitable, PlanetType.terrestrial) =>
      [EnvType.earthlike, EnvType.oceanic, EnvType.jungle,
        EnvType.arboreal, EnvType.alluvial, EnvType.paradisiacal],
      (OrbitalZone.habitable, PlanetType.superEarth) =>
      [EnvType.earthlike, EnvType.oceanic, EnvType.toxic],
      (OrbitalZone.outer, PlanetType.iceWorld) =>
      [EnvType.icy, EnvType.snowy, EnvType.mountainous],
      (OrbitalZone.outer, PlanetType.icyGiant) =>
      [EnvType.icy, EnvType.toxic],
      _ => EnvType.values,
    };
  }

  @override
  String toString() => 'PlanetBlueprint('
      'type: $type, '
      'orbRad: $orbitalRadius, '
      'pos: $position, '
      'hab: $habitable, '
      'locked: $tidallyLocked, '
      'relMass: ${relativeMass}, '
      'parentStar: $parentStar'
      ')';
}


class PlanetBlueprintGenerator {
  final GridDim systemDim;
  final GridDim impulseDim;
  double get maxStarRad => (systemDim.maxXY / 2).clamp(2, 50);
  double get minOrbitalSpacing => systemDim.maxXY * .075; // cells, prevents crowding
  double get migrationInc =>  systemDim.maxXY * .025;
  final Random rnd;

  PlanetBlueprintGenerator(this.systemDim,this.impulseDim,{Random? rnd}) : rnd = rnd ?? Random();

  List<PlanetBlueprint> generate(SystemMetadata meta, List<Coord3D> starPositions) {
    final blueprints = <PlanetBlueprint>[];
    final primary = meta.stellarClasses.first;

    switch (meta.starConfig) {
      case MultiStarConfig.single:
      case MultiStarConfig.tightBinary:
      // All planets orbit the center as one system
        blueprints.addAll(_planetsForStar(
            primary, starPositions[0], meta, maxRadius: maxStarRad - 1));

      case MultiStarConfig.wideBinary:
      // Each star gets its own inner family, limited radius
        blueprints.addAll(_planetsForStar(
            meta.stellarClasses[0], starPositions[0], meta, maxRadius: maxStarRad/2));
        blueprints.addAll(_planetsForStar(
            meta.stellarClasses[1], starPositions[1], meta, maxRadius: maxStarRad/2));
    // No outer planets — mutual gravity prevents them

      case MultiStarConfig.hierarchical:
      // Primary pair gets full system
        blueprints.addAll(_planetsForStar(
            primary, starPositions[0], meta, maxRadius: maxStarRad - 1));
        // Distant third gets only close-in planets
        blueprints.addAll(_planetsForStar(
            meta.stellarClasses.last, starPositions.last, meta, maxRadius: maxStarRad/4));
    }

    _applyGiantOutcome(blueprints, meta);
    return blueprints;
  }

  List<PlanetBlueprint> _planetsForStar(
      StellarClass star,
      Coord3D starPos,
      SystemMetadata meta,
      {required double maxRadius}
      ) {
    final planets = <PlanetBlueprint>[];
    final budget = _planetBudget(meta);
    double currentRadius = max(1,systemDim.maxXY * .066); // start just outside star cell

    for (int i = 0; i < budget && currentRadius <= maxRadius; i++) {
      final isInner = currentRadius < star.habitableRadius;
      final isHabitable = currentRadius >= star.habitableRadius
          && currentRadius < star.frostRadius;
      final isOuter = currentRadius >= star.frostRadius;

      final type = _rollType(isInner, isHabitable, isOuter, meta);
      final pos = _positionOnRing(starPos, currentRadius, i, budget);
      final tidallyLocked = currentRadius <= star.tidalLockRadius;

      planets.add(PlanetBlueprint(
        type: type,
        orbitalRadius: currentRadius,
        position: pos,
        starPosition: starPos,
        habitable: isHabitable && type != PlanetType.gasGiant,
        tidallyLocked: tidallyLocked,
        relativeMass: _rollMass(type),
        parentStar: star,
      ));

      // Spacing — gas giants need more clearance
      final spacing = type == PlanetType.gasGiant ? minOrbitalSpacing * 1.75 : minOrbitalSpacing;
      currentRadius += spacing + rnd.nextDouble() * 0.8;
    }

    return planets;
  }

  PlanetType _rollType(bool isInner, bool isHabitable, bool isOuter, SystemMetadata meta) {
    if (isInner) {
      // Inner zone — rocky only, composition biases size
      return meta.composition == SolidComposition.refractoryRich
          ? (rnd.nextDouble() < 0.3 ? PlanetType.superEarth : PlanetType.terrestrial)
          : PlanetType.terrestrial;
    }
    if (isHabitable) {
      return switch (rnd.nextDouble()) {
        < 0.5  => PlanetType.terrestrial,
        < 0.75 => PlanetType.superEarth,
        _      => PlanetType.terrestrial, // gas giants in habitable zone rare
      };
    }
    // Outer zone — volatile rich composition favors giants
    final giantBias = meta.composition == SolidComposition.volatileRich ? 0.2 : 0.0;
    final giantProb = 0.4 + giantBias;
    final roll = rnd.nextDouble();
    if (roll < giantProb) return PlanetType.gasGiant;
    if (roll < 0.7) return PlanetType.icyGiant;
    return PlanetType.iceWorld;
  }

  // Spread planets around the ring with slight angular variation
  Coord3D _positionOnRing(Coord3D starPos, double radius, int index, int total) {
    final angle = (index / total) * 2 * pi + rnd.nextDouble() * 0.4;
    final x = (starPos.x + radius * cos(angle)).round();
    final y = (starPos.y + radius * sin(angle)).round();
    return Coord3D(x.clamp(0, systemDim.maxXY-1), y.clamp(0, systemDim.maxXY-1), 0);
  }

  int _planetBudget(SystemMetadata meta) {
    final base = 2 + (meta.richness * 5).round();
    final effMod = ((meta.formationEfficiency - 0.75) * 4).round();
    return (base + effMod).clamp(1, Galaxy.maxPlanets);
  }

  double _rollMass(PlanetType type) => switch (type) {
    PlanetType.terrestrial => 0.1 + rnd.nextDouble() * 0.4,
    PlanetType.superEarth  => 0.4 + rnd.nextDouble() * 0.3,
    PlanetType.iceWorld    => 0.1 + rnd.nextDouble() * 0.3,
    PlanetType.gasGiant    => 0.3 + rnd.nextDouble() * 0.7,
    PlanetType.icyGiant    => 0.4 + rnd.nextDouble() * 0.3,
  };

  void _applyGiantOutcome(List<PlanetBlueprint> blueprints, SystemMetadata meta) {
    switch (meta.giantOutcome) {
      case GiantOutcome.none:
      // Remove any gas giants that snuck in
        blueprints.removeWhere((p) => p.type == PlanetType.gasGiant);

      case GiantOutcome.inwardMigrated:
      // Find outermost gas giant, move it inward, wreck inner terrestrials
        final giant = blueprints.lastWhereOrNull((p) => p.type == PlanetType.gasGiant);
        if (giant != null) {
          final idx = blueprints.indexOf(giant);
          blueprints[idx] = PlanetBlueprint(
            type: giant.type,
            orbitalRadius: giant.parentStar.habitableRadius - migrationInc,
            position: _positionOnRing(
                giant.starPosition, giant.parentStar.habitableRadius - migrationInc, 0, 1),
            habitable: false,
            tidallyLocked: false, // gas giants can be locked but irrelevant without moon modeling
            relativeMass: giant.relativeMass,
            parentStar: giant.parentStar, starPosition: giant.starPosition,
          );
          // Inner terrestrials mostly destroyed by migration
          blueprints.removeWhere((p) =>
          p.type == PlanetType.terrestrial &&
              p.orbitalRadius < giant.parentStar.habitableRadius);
        }

      case GiantOutcome.chaotic:
      // Randomly eject some planets — chaotic systems are sparse
        blueprints.removeWhere((_) => rnd.nextDouble() < 0.4);

      case GiantOutcome.stableOuter:
      case GiantOutcome.resonant:
        break; // no modification needed
    }
  }
}
