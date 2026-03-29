import 'dart:math';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import '../color.dart';

enum StellarClass {
  M(GameColor(0xFFFFB56C), .76, 4,  .1,  .95, -.03, 2.0, 2.5, 3.5, 0.20),
  K(GameColor(0xFFFFD9B5), .88, 12, .2, 1.05, -.04, 2.5, 1.5, 4.0, 0.70),
  G(GameColor(0xFFFFEDE2), .95, 20, .33, 1.0, -.04, 3.0, 1.0, 5.0, 1.00),
  F(GameColor(0xFFF8F5FF), .98, 32, .5,  .95, -.04, 3.5, 0.5, 6.0, 1.30),
  A(GameColor(0xFFD5E0FE), .993,48, .75, .78, -.04, 5.0, 0.3, 7.0, 2.00),
  B(GameColor(0xFFAABEFF), .9995,75,.9,  .6,  .01, 7.0, 0.1, 8.0, 6.00),
  O(GameColor(0xFF3456EE), 1,  100, .99, .45, .01, 9.0, 0.0, 9.0, 25.0),
  ;

  final double frostRadius;      // in grid cells from star
  final double habitableRadius;  // inner edge of habitable zone in cells
  final double tidalLockRadius;  // grid cells within which locking occurs
  final GameColor color;
  final int lumIndex;
  final double prob;
  final double gas;
  final double systemFormationMod;
  final double giantFormationMod;
  final double solarMasses;

  const StellarClass(
      this.color,
      this.prob,
      this.lumIndex,
      this.gas,
      this.systemFormationMod,
      this.giantFormationMod,
      this.frostRadius,
      this.habitableRadius,
      this.tidalLockRadius,
      this.solarMasses,
      );

  static StellarClass getRndStellarClass(Random rnd) {
    final roll = rnd.nextDouble();
    for (final sc in StellarClass.values) {
      if (roll < sc.prob) return sc;
    }
    throw StateError('StellarClass probabilities do not cover given range).');
  }
}

class Star extends MassiveObject<ImpulseLocation> {
  final StellarClass stellarClass;
  bool jumpgate;

  Star(
      this.stellarClass,
      this.jumpgate, {
        super.tuningFactor = .00000001,
      }) : super(
    "Class ${stellarClass.name} Star",
    earthMasses: stellarClass.solarMasses * earthSunRatio,
  );
}
