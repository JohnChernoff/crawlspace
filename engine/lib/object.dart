import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/shop.dart';

class SpaceObject {
  final String name;
  double fedLvl;
  double techLvl;
  bool known = false;
  String description = "";
  Shop? shop, yard;
  final Set<Ship> hangar = {};
  SpaceObject(this.name,this.fedLvl,this.techLvl);
}