import 'galaxy/galaxy.dart';
import 'object.dart';
import 'pilot.dart';
import 'ship.dart';

class TradeTarget {
  SpaceObject source;
  SpaceObject location;
  int reward;
  TradeTarget(this.location,this.source,this.reward);
}

enum OrbitResult {newOrbit,sameOrbit,insufficientEnergy,noShip}

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

  Player(super.name,super.rnd, {super.location, super.sys, super.galaxy, super.hostile = false});

  double fedLevel(Galaxy g) => location?.fedLvl ?? g.fedLevel.val(system);
  double techLevel(Galaxy g) => location?.techLvl ?? g.techLevel.val(system);

}