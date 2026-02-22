import 'object.dart';

class Item extends SpaceObject {
  int get baseCost => _baseCost;
  String get shopDesc => name;
  static int _idCounter = 0;
  final int _baseCost;
  final double rarity;
  final int id;

  Item(super.name, {required int baseCost, required this.rarity})
      : id = _idCounter++, _baseCost = baseCost;

  @override
  String toString() => name;
}

