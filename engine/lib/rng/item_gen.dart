import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/rng/rng.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/location.dart';
import '../item.dart';
import '../stock_items/activators.dart';
import '../stock_items/species.dart';

class ItemGen {
  int numArtifacts = 255;
  int numScrolls = 255;
  Item ancientFedArt1 = Item("Primitive Humanoid Communications Device",shortDesc: "Something called an 'IPhone 27'",sellable: false);
  Item ancientFedArt2 = Item("A glowing datastack",shortDesc: "A datastack entitled 'Ancient Earth History (500 BC - 2500 AD)'",sellable: false);
  Item ancientFedArt3 = Item("Ivory chess piece", shortDesc: "A chess knight, floating in space. Odd.",sellable: false);

  void generateItems(Galaxy galaxy) {
    final repo = galaxy.items;
    for (int i=0; i<numArtifacts; i++) {
      final item = Rng.randomArtifact(galaxy.rnd, 100000); //items.add(item);
      final itemLoc = galaxy.rndLoc(galaxy.rnd);
      repo.register(item, itemLoc);
    }
    for (final s in StockSpecies.values) {
      final t = galaxy.territory(s.species);
      if (t.isNotEmpty) {
        final sys = t.elementAt(galaxy.rnd.nextInt(t.length));
        final r = Relic("${s.species.name} relic", s.species);
        final loc = sys.rndImpLoc(galaxy);
        repo.register(r, loc);
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
        final loc = sys.rndImpLoc(galaxy);
        repo.register(activator, loc);
      }
    }

    final startingSystem = galaxy.farthestSystem(galaxy.fedHomeSystem);
    final loc = SectorLocation(startingSystem, Coord3D(5,5,5));
    repo.register(ActivatorFactory.generate(StockActivator.xenoEnhanceScroll, .5, galaxy.rnd, species: StockSpecies.vorlon.species),loc);
  }
}