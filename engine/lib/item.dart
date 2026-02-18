class Item {
  int get baseCost => _baseCost;
  String get shopDesc => name;
  static int _idCounter = 0;
  final String name;
  final int _baseCost;
  final double rarity;
  final int id;

  Item(this.name, {required int baseCost, required this.rarity})
      : id = _idCounter++, _baseCost = baseCost;

  @override
  String toString() => name;
}

