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

  Player(super.name,super.system,super.rnd, {super.location, super.hostile = false});

  int fedLevel() => location?.fedLvl ?? system.fedLvl;
  int techLevel() => location?.techLvl ?? system.techLvl;

}