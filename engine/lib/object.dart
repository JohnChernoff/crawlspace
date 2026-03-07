import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/shop.dart';
import 'color.dart';
import 'item.dart';

abstract interface class Locatable {
  SpaceLocation get loc;
}

class SpaceEnvironment<T extends SpaceLocation> extends SpaceObject implements Locatable {
  T get loc => locale;
  T locale;
  String get fedStr  => "${(fedLvl  * 100).round()}";
  String get techStr => "${(techLvl * 100).round()}";
  double fedLvl;
  double techLvl;

  // Typed shop fields — replacing the old untyped `Shop? shop, yard`
  SystemShop? sysShop;    // ship systems: power, engines, weapons, etc.
  ShipYard?   yard;    // ship purchase and hangar
  Market?     market;  // trade goods: commodities, species specials, house specials

  final Set<Ship> hangar = {};
  double rapport = 0; // -1–1

  SpaceEnvironment(super.name, this.fedLvl, this.techLvl,
      {super.desc, required T this.locale});
}

class SpaceObject implements Nameable {
  final String name;
  String get selectionName => name;
  String?   desc;
  bool      known    = false;
  GameColor objColor;
  SpaceObject(this.name, {this.desc, this.objColor = GameColors.white});
}
