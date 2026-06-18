import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/rng/rng.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import 'package:crawlspace_engine/ship/ship_sys.dart';
import 'package:crawlspace_engine/ship/systems/ship_system.dart';
import 'package:crawlspace_engine/stock_items/corps.dart';
import 'package:crawlspace_engine/stock_items/loadouts.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_engines.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_pile.dart';
import '../actors/pilot.dart';
import '../fugue_engine.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';
import '../galaxy/system.dart';
import '../ship/ship.dart';
import '../stock_items/ship/stock_ships.dart';

class ShipGenerator {

  static Ship generateRandomShip(System system, Galaxy galaxy, Random rnd, {required Pilot owner}) {
    final location = SectorLocation(system, system.map.rndCoord(rnd)); //galaxy.rndLoc(rnd);
    final dangerLvl = max(0,1 - (galaxy.topo.distance(location.system, galaxy.findHomeworld(owner.faction.species)) / galaxy.maxJumps));
    final techLvl = max(1,(dangerLvl * 10).round());
    glog("Faction: ${owner.faction.name}, tech: $dangerLvl, $techLvl");
    bool military = owner.faction.isPirate ||
        (owner.faction.isWarmonger && rnd.nextDouble() < owner.faction.militancy) ||
        rnd.nextDouble() < dangerLvl;

    var ships = ShipClassType.values.where((sc) => sc.speciesMap.containsKey(owner.faction.species) && sc.type.military == military);
    if (ships.isEmpty) ships = ShipClassType.values.where((sc) => sc.type.military == military);
    ships = ships.sorted((a,b) => (a.type.dangerLvl - dangerLvl).abs().compareTo((b.type.dangerLvl - dangerLvl).abs()));

    final shipClassType = ships.firstWhere((c) => rnd.nextDouble() < c.type.freq, orElse: () => ships.elementAt(rnd.nextInt(ships.length)));

    Ship ship = Ship("HMS ${Rng.randomAlienName(rnd)}", shipClass: ShipClass.fromEnum(shipClassType), techLvl: techLvl, owner: owner);

    for (final slot in shipClassType.slots) {
      final c = shipClassType.corpMap[slot.type] ?? Corporation.genCorp;
      glog("Installing: ${slot.type.name} , $c, ${slot.num}");
      for (int i=0; i<slot.num; i++) {
        Iterable<StockSystem> sysList = [];
        for (int compLevel = 4; compLevel > 0 && sysList.isEmpty; compLevel--) {
          sysList = StockSystem.values.where((s) => s.type == slot.type && c.getRelations(s.manufacturer).level >= compLevel)
              .sorted((a,b) => (a.techLvl - techLvl).abs().compareTo((b.techLvl - techLvl).abs()));
          if (slot.type == ShipSystemType.engine) {
            sysList = sysList.where((s) => ship.systemControl.getEngine(stockEngines[s]!.domain) == null);
          }
        }
        if (sysList.isNotEmpty) {
          final system = (sysList.firstWhere((_) => rnd.nextBool(), orElse: () => sysList.first)).createSystem();
          glog("Installing System: $system");
          if (system != null) glog(ship.systemControl.installSystem(system).result.name);
        }
      }
    }

    return ship;
  }

}