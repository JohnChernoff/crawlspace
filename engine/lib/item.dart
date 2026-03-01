import 'package:crawlspace_engine/stock_items/species.dart';

import 'object.dart';

class Item extends SpaceObject {
  int get baseCost => _baseCost;
  String get shopDesc => name;
  static int _idCounter = 0;
  final int _baseCost;
  final double rarity;
  final int id;
  final sellable;

  Item(super.name, {super.desc, int baseCost = 0, this.rarity = 0, this.sellable = true, super.objColor})
      : id = _idCounter++, _baseCost = baseCost;

  @override
  String toString() => name;
}

class Relic extends Item {
  Species species;
  Relic(super.name, this.species, {super.sellable = false}) {
    objColor = species.graphCol;
  }
}