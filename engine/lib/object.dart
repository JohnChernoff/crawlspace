import 'package:crawlspace_engine/location.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/shop.dart';

abstract interface class Locatable {
  SpaceLocation get loc;
}

class SpaceEnvironment<T extends SpaceLocation> extends SpaceObject implements Locatable {
  T get loc => locale;
  T locale;
  String get fedStr => "${(fedLvl * 100).round()}";
  String get techStr => "${(techLvl * 100).round()}";
  double fedLvl;
  double techLvl;
  Shop? shop, yard;
  final Set<Ship> hangar = {};
  SpaceEnvironment(super.name,this.fedLvl,this.techLvl, {super.description, required T this.locale}); // : _loc = loc;
}

class SpaceObject<T extends SpaceLocation> {
  final String name;
  String? description;
  bool known = false;
  SpaceObject(this.name,{this.description});
}