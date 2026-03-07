import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/stock_items/xenomancy.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/geometry/object.dart';
import 'pilot.dart';
import '../ship/ship.dart';

class TradeTarget {
  SpaceEnvironment source;
  SpaceEnvironment destination;
  int reward;
  TradeTarget(this.destination,this.source,this.reward);
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
  double inebriation = 0;

  Player(super.name,{required super.loc, super.galaxy}) {
    knownSpells["f"] = XenomancySpell.foldSpace;
    knownSpells["c"] = XenomancySpell.firecloud;
  }

  void drink(double strength) {
    final con = attributes[AttribType.con] ?? 0.5;
    final resistance = 0.1 + con * 0.9;
    inebriation = (inebriation + (strength * (1 / resistance)) / 32).clamp(0, 1);
  }

  String get inebriationLevel => switch(inebriation) {
    > .9  => "face down on the bar",
    > .75 => "seeing double suns",
    > .66 => "the room is in hyperspace",
    > .5  => "three sheets to the solar wind",
    > .33 => "pleasantly adrift",
    > .25 => "a little loose in the airlock",
    > .10 => "slightly pressurized",
    _     => "completely sober"
  };

  void tick(FugueEngine fm) {
    super.tick(fm);
    final con = attributes[AttribType.con] ?? 0.5;
    final decayRate = 0.005 + con * 0.02; // con 0 = 0.005, con 1 = 0.025
    inebriation = max(0, inebriation - decayRate);
  }

  double fedLevel(Galaxy g) {
    final loc = locale;
    if (loc is AtEnvironment) return loc.env.fedLvl;
    return g.fedKernel.val(system);
  }

  double techLevel(Galaxy g) {
    final loc = locale;
    if (loc is AtEnvironment) return loc.env.techLvl;
    return g.techKernel.val(system);
  }
}