import 'galaxy/galaxy.dart';
import 'object.dart';
import 'pilot.dart';
import 'ship.dart';

class TradeTarget {
  SpaceEnvironment source;
  SpaceEnvironment location;
  int reward;
  TradeTarget(this.location,this.source,this.reward);
}

class Player extends Pilot {
  static const maxDna = 36;
  int dnaScram = 5;
  TradeTarget? tradeTarget;
  bool starOne = false;
  int broadcasts = 0;
  int piratesEncountered = 0;
  int piratesVanquished = 0;
  Set<Ship> fleet = {};
  double heat = 0;

  Player(super.name,super.rnd, {required super.loc, super.galaxy, super.hostile = false});

  double fedLevel(Galaxy g) {
    final env = locale;
    if (env is SpaceEnvironment) return env.fedLvl;
    return g.fedKernel.val(system);
  }

  double techLevel(Galaxy g) {
    final env = locale;
    if (env is SpaceEnvironment) return env.techLvl;
    return g.techKernel.val(system);
  }

}