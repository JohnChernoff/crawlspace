import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/models/sub_model.dart';
import '../../item.dart';
import '../../rng/rng.dart';
import '../../stock_items/activators.dart';
import '../../stock_items/species.dart';
import '../geometry/location.dart';

class TreasureModel extends GalaxySubMod {

  int numArtifacts = 1000;
  int numScrolls = 1000;

  Map<SystemLocation,Set<Item>> treasureMap = {};
  Item ancientFedArt1 = Item("Primitive Humanoid Communications Device",shortDesc: "Something called an 'IPhone 27'",sellable: false);
  Item ancientFedArt2 = Item("A glowing datastack",shortDesc: "A datastack entitled 'Ancient Earth History (500 BC - 2500 AD)'",sellable: false);
  Item ancientFedArt3 = Item("Ivory chess piece", shortDesc: "A chess knight, floating in space. Odd.",sellable: false);

  TreasureModel(super.galaxy) {
    Set<Item> items = {ancientFedArt1,ancientFedArt2,ancientFedArt3};
    for (int i=0; i<numArtifacts; i++) {
      final item = Rng.randomArtifact(galaxy.rnd, 100000);
      items.add(item);
      final itemLoc = galaxy.rndLoc(galaxy.rnd);
      treasureMap.putIfAbsent(itemLoc, () => {}).add(item); //print("Adding to ${loc}: ${i.name}, ${i.baseCost}");
    }
    for (final s in StockSpecies.values) {
      final t = galaxy.territory(s.species);
      if (t.isNotEmpty) {
        final sys = t.elementAt(galaxy.rnd.nextInt(t.length));
        final r = Relic("${s.species.name} relic", s.species);
        treasureMap.putIfAbsent(SystemLocation(sys,sys.map.rndCell(galaxy.rnd)), () => {}).add(r);
      }
    }
    for (final s in StockSpecies.values) {
      final territory = galaxy.territory(s.species);
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
        final loc = SystemLocation(sys, sys.map.rndCell(galaxy.rnd));
        treasureMap.putIfAbsent(loc, () => {}).add(activator);
      }
    }

    final startingSystem = galaxy.farthestSystem(galaxy.fedHomeSystem);
    final loc = SystemLocation(startingSystem, startingSystem.map.cells[Coord3D(5,5,5)]!);
    treasureMap.putIfAbsent(loc, () => {}).add(ActivatorFactory.generate(StockActivator.xenoEnhanceScroll, .5, galaxy.rnd,
        species: StockSpecies.vorlon.species));
  }

}