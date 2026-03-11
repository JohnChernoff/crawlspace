import 'package:collection/collection.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/models/sub_model.dart';
import '../../item.dart';
import '../../rng/rng.dart';
import '../../stock_items/activators.dart';
import '../../stock_items/species.dart';
import '../geometry/location.dart';
import '../system.dart';

typedef ItemMap = Map<SpaceLocation,Set<Item>>;
typedef ItemEntry = MapEntry<SpaceLocation, Set<Item>>;
typedef ItemSet = Set<ItemEntry>;

class ItemRegistry extends GalaxySubMod {

  int numArtifacts = 255;
  int numScrolls = 255;
  ItemMap _repository = {};
  final Map<Item, SpaceLocation> _itemIndex = {};
  Item ancientFedArt1 = Item("Primitive Humanoid Communications Device",shortDesc: "Something called an 'IPhone 27'",sellable: false);
  Item ancientFedArt2 = Item("A glowing datastack",shortDesc: "A datastack entitled 'Ancient Earth History (500 BC - 2500 AD)'",sellable: false);
  Item ancientFedArt3 = Item("Ivory chess piece", shortDesc: "A chess knight, floating in space. Odd.",sellable: false);

  ItemRegistry(super.galaxy) { //Set<Item> items = {ancientFedArt1,ancientFedArt2,ancientFedArt3};
    for (int i=0; i<numArtifacts; i++) {
      final item = Rng.randomArtifact(galaxy.rnd, 100000); //items.add(item);
      final itemLoc = galaxy.rndLoc(galaxy.rnd);
      addItem(item, itemLoc);
    }
    for (final s in StockSpecies.values) {
      final t = galaxy.territory(s.species);
      if (t.isNotEmpty) {
        final sys = t.elementAt(galaxy.rnd.nextInt(t.length));
        final r = Relic("${s.species.name} relic", s.species);
        final loc = sys.rndImpLoc(this.galaxy);
        addItem(r, loc);
      }
    }
    for (final s in StockSpecies.values) {
      final territory = galaxy.territory(s.species);
      print("${s.species.name} Territory size: ${territory.length}");
      for (int i = 0; i < numScrolls / StockSpecies.values.length; i++) {
        final stock = Rng.weightedRandom(
            { for (final sa in StockActivator.values) sa: sa.data.rarity },
            galaxy.rnd
        );
        final quality = galaxy.rnd.nextDouble();
        // pass species context to factory
        final activator = ActivatorFactory.generate(stock, quality, galaxy.rnd,
            species: s.species);
        final sys = territory.elementAt(galaxy.rnd.nextInt(territory.length));
        final loc = sys.rndImpLoc(this.galaxy);
        addItem(activator, loc);
      }
    }

    final startingSystem = galaxy.farthestSystem(galaxy.fedHomeSystem);
    final loc = SectorLocation(startingSystem, Coord3D(5,5,5));
    addItem(ActivatorFactory.generate(StockActivator.xenoEnhanceScroll, .5, galaxy.rnd, species: StockSpecies.vorlon.species),loc);
  }

  void addItem(Item item, SpaceLocation loc) {
    _repository.putIfAbsent(loc, () => {}).add(item);
    _itemIndex[item] = loc;
  }

  void removeItem(Item item) {
    final loc = _itemIndex.remove(item);
    if (loc != null) _repository[loc]?.remove(item);
  }

  SpaceLocation? locationOf(Item item) => _itemIndex[item];

  MapEntry<SpaceLocation,Item> nearestItem(System sys) {
    final loc = _repository.keys
        .sorted((a,b) => galaxy.topo.distance(a.system, sys)
        .compareTo(galaxy.topo.distance(b.system, sys))).first;
    return MapEntry(loc, _repository[loc]!.first);
  }

  ItemSet inSystem(System sys) => _repository.entries.where((m) => m.key.system == sys).toSet();
  Set<Item>? atLocation(SpaceLocation loc) => _repository[loc];
  //Set<Item> atCell(GridCell cell) => _repository.entries.where((m) => m.key.cell == cell).expand((e) => e.value).toSet();


}