import 'package:collection/collection.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'object.dart';

class Item extends SpaceObject {
  int get baseCost => _baseCost;
  String get shopDesc => name;
  static int _idCounter = 0;
  final int _baseCost;
  final double rarity;
  final int id;
  final double mass; //tonnes
  final double volume; //cubic meters
  final sellable;

  Item(super.name, {super.desc, int baseCost = 0, this.rarity = 0, this.mass = .01, this.volume = .01, this.sellable = true, super.objColor})
      : id = _idCounter++, _baseCost = baseCost;

  bool eq(Item i) => i.name == name;

  @override
  String toString() => name;
}

class Relic extends Item {
  Species species;
  Relic(super.name, this.species, {super.sellable = false}) {
    objColor = species.graphCol;
  }
}

class SlotData {
  final int maxItems;
  final int? marketPrice;
  final int? buyBackPrice;
  const SlotData({this.maxItems = 99, this.marketPrice, this.buyBackPrice});
  SlotData copyWith({int? maxItems, int? marketPrice, int? buyBackPrice}) => SlotData(
    maxItems: maxItems ?? this.maxItems,
    marketPrice: marketPrice ?? this.marketPrice,
    buyBackPrice: buyBackPrice ?? this.buyBackPrice,
  );
}

class ItemSlot<T extends Item> {
  final Inventory<T> inv;
  final SlotData data;
  final List<T> _items;
  T get item => _items.first;
  List<T> get items => _items;
  int get count => _items.length;
  String get slotName => _items.firstOrNull?.name ?? "empty";
  bool get full => _items.length >= data.maxItems;

  ItemSlot(this.inv, {List<T>? items, SlotData? slotData}) : _items = items ?? [], data = slotData ?? const SlotData();

  factory ItemSlot.create(Inventory<T> inv, T item, {SlotData? data}) =>
      ItemSlot(inv, items: [item], slotData: data ?? SlotData(marketPrice: item.baseCost));

  bool add(T item) {
    if (!full) { _items.add(item); return true; }
    return false;
  }

  bool remove(T item, {deleteEmpty = true}) {
    final removed = _items.remove(item);
    if (removed && count == 0 && deleteEmpty) inv._slots.remove(this);
    return removed;
  }

  String label({bool shop = false}) {
    StringBuffer sb = StringBuffer();
    sb.write(shop ? items.first.shopDesc : slotName);
    if (count > 1) sb.write(" x$count");
    if (shop) {
      sb.write(", ${data.marketPrice} cr");
    }
    return sb.toString();
  }
}

typedef InventoryView<T extends Item> = Inventory<T>;

class Inventory<T extends Item> {
  int maxSlots = 99;
  final List<ItemSlot<T>> _slots;
  List<ItemSlot<T>> get slots => _slots;
  bool get full => _slots.length >= maxSlots;
  Iterable<T> get all => _slots.expand((s) => s.items);
  int get count => _slots.fold(0, (n, s) => n + s.items.length);
  bool get isEmpty => _slots.every((s) => s.items.isEmpty);
  Iterable<ItemSlot<T>> getSlots(T item) => _slots.where((s) => s.items.any((i) => i.eq(item)));
  ItemSlot<T>? getSlot(T item) => getSlots(item).firstOrNull;
  bool hasItem(T item) => getSlot(item) != null;

  int effectiveSellPrice(T i) => getSlot(i)?.data.marketPrice ?? i.baseCost;
  int effectiveBuyBackPrice(T i) => getSlot(i)?.data.buyBackPrice ?? (i.baseCost / 2).round();

  Inventory({List<ItemSlot<T>>? slots}) : _slots = slots ?? [];

  bool add(T item, {SlotData? data}) {
    final availableSlot = getSlots(item).firstWhereOrNull((s) => !s.full);
    if (availableSlot != null) {
      return availableSlot.add(item);
    } else if (!full) {
      _slots.add(ItemSlot.create(this, item, data: data));
      return true;
    }
    return false;
  }

  bool remove(T item) => getSlot(item)?.remove(item) ?? false;

  void clear() {
    for (final item in all.toList()) {
      remove(item);
    }
  }

  InventoryView filter(bool Function(T) test) {
    final result = Inventory<T>();
    for (final item in all.where(test)) {
      result.add(item, data: getSlot(item)?.data);
    }
    return result;
  }

  Inventory<S> filterType<S extends T>() {
    final result = Inventory<S>();
    for (final item in all.whereType<S>()) {
      final slot = getSlot(item);
      result.add(item, data: slot?.data.copyWith());
    }
    return result;
  }
}
