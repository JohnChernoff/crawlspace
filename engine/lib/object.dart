import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/shop.dart';

class SpaceObject {
  final String name;
  String get fedStr => "${(fedLvl * 100).round()}";
  String get techStr => "${(techLvl * 100).round()}";
  double fedLvl;
  double techLvl;
  bool known = false;
  String description = "";
  Shop? shop, yard;
  final Set<Ship> hangar = {};
  SpaceObject(this.name,this.fedLvl,this.techLvl);
}