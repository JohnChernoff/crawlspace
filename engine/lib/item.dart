import 'dart:math';
import 'galaxy/geometry/location.dart';
import 'galaxy/geometry/object.dart';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/stock_items/activators.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'actors/pilot.dart';
import 'galaxy/galaxy.dart';
import 'galaxy/system.dart';

abstract interface class Nameable {
  String get selectionName;
}

abstract interface class Describable extends Nameable {
  String? get flavor;
  String get description;
}

abstract interface class Normalizable extends Nameable {
  Map<System,double> normalize(Galaxy g, {log = true});
}

mixin Itemizable {
  String get name;
  int get baseCost => 0;
  String get shopDesc => name;
  bool eq(Itemizable i) => i.name == name;
}

class Item<T extends SpaceLocation> extends MassiveObject<T> with Itemizable {
  int get baseCost => _baseCost;
  String get shopDesc => name;
  static int _idCounter = 0;
  final int _baseCost;
  final double rarity;
  final int id;
  final double volume; //cubic meters
  final sellable;

  Item(super.name, {super.shortDesc, int baseCost = 0, this.rarity = 0, super.mass = .01, this.volume = .01,
    this.sellable = true, super.objColor}) : id = _idCounter++, _baseCost = baseCost;


  @override
  String toString() => name;
}

class Relic extends Item {
  Species species;
  Relic(super.name, this.species, {super.sellable = false}) {
    objColor = species.graphCol;
  }
}

typedef ActivatorAction = bool Function(FugueEngine fm, Pilot pilot);

class Activator extends Item {
  final ActivatorData data;
  int charges;
  double power;
  bool get isRod => data.type == ActivatorType.rod;
  bool get ready => isRod ? recharged : charges > 0;
  bool get useless => !isRod && !ready;
  bool get recharged => rechargeMeter >= rechargeRequirement;
  int rechargeMeter = 0, rechargeRequirement;
  ActivatorAction onActivate;
  Activator(super.name, this.onActivate, {required this.data, super.shortDesc, this.power = .5, this.charges = 1, this.rechargeRequirement = 0}) :
        super(rarity: data.rarity);
  factory Activator.fromStock(StockActivator stock, ActivatorAction action, {
    double quality = .5, String? name, String? desc}) => switch(stock.data.type) {
    ActivatorType.scroll => Activator(name ?? stock.name, action,data: stock.data, power: quality,
        shortDesc: desc ?? stock.desc),
    ActivatorType.wand => Activator(name ?? stock.name, action,data: stock.data, power: .5,
        charges: (16 * quality).ceil(), shortDesc: desc ?? stock.desc),
    ActivatorType.rod => Activator(name ?? stock.name, action,data: stock.data, power: .5,
        rechargeRequirement: (250 * quality).ceil(), shortDesc: desc ?? stock.desc),
  };

  void consumeCharge() {
    if (isRod) rechargeMeter = 0;
    else charges = max(charges - 1, 0);
  }

  bool activate(FugueEngine fm, Pilot pilot) { //print("$this: $ready, $charges, $isRod");
    if (ready) {
      consumeCharge();
      if (!ready && !isRod) { //TODO: pilot inventory?
        fm.galaxy.ships.byPilot(pilot)?.inventory.remove(this);
      }
      return onActivate(fm,pilot);
    } return false;

  }

  bool recharge(int amount) {
    if (!ready) {
      rechargeMeter = min(rechargeMeter + amount,rechargeRequirement);
      return ready;
    } return false;
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

class ItemSlot<T extends Itemizable> {
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

  @override
  String toString() {
    return "$slotName: ${items.length}";
  }
}

typedef InventoryView<T extends Itemizable> = Inventory<T>;

class Inventory<T extends Itemizable> {
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

  Inventory<Item> get items => filter((i) => i is Item) as Inventory<Item>;

  Inventory<S> filterType<S extends T>() {
    final result = Inventory<S>();
    for (final item in all.whereType<S>()) {
      final slot = getSlot(item);
      result.add(item, data: slot?.data.copyWith());
    }
    return result;
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    for (final slot in slots) sb.writeln(slot);
    return sb.toString();
  }
}
