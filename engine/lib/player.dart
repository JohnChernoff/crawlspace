import 'pilot.dart';
import 'planet.dart';
import 'ship.dart';

class TradeTarget {
  Planet planet;
  Planet? source;
  int reward;
  TradeTarget(this.planet,this.source,this.reward);
}

enum OrbitResult {newOrbit,sameOrbit,insufficientEnergy,noShip}

class Player extends Pilot {
  static const maxDna = 36;
  Planet? planet;
  int dnaScram = 5;
  TradeTarget? tradeTarget;
  bool starOne = false;
  int broadcasts = 0;
  int piratesEncountered = 0;
  int piratesVanquished = 0;
  Set<Ship> fleet = {};

  Player(super.name,super.system,super.rnd, {super.hostile = false});

  int fedLevel() => planet?.fedLvl ?? system.fedLvl;
  int techLevel() => planet?.techLvl ?? system.techLvl;

}