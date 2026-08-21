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

  static Ship generateRandomShip(System system, Galaxy galaxy, Random rnd, {required Pilot owner, List<String> powerFilter = const []}) {
    final location = SectorLocation(system, system.map.rndCoord(rnd)); //galaxy.rndLoc(rnd);
    final dangerLvl = max(0,1 - (galaxy.topo.distance(location.system, galaxy.findHomeworld(owner.faction.species)) / galaxy.maxJumps));
    final techLvl = max(1,(dangerLvl * 10).round());
    glog("Faction: ${owner.faction.name}, tech: $dangerLvl, $techLvl",level: DebugLevel.Fine);
    bool military = owner.faction.isPirate ||
        (owner.faction.isWarmonger && rnd.nextDouble() < owner.faction.militancy) ||
        rnd.nextDouble() < dangerLvl;

    var ships = ShipClassType.values.where((sc) => sc.speciesMap.containsKey(owner.faction.species) && sc.type.military == military);
    if (ships.isEmpty) ships = ShipClassType.values.where((sc) => sc.type.military == military);
    ships = ships.sorted((a,b) => (a.type.dangerLvl - dangerLvl).abs().compareTo((b.type.dangerLvl - dangerLvl).abs()));

    final shipClassType = ships.firstWhere((c) => rnd.nextDouble() < c.type.freq, orElse: () => ships.elementAt(rnd.nextInt(ships.length)));

    Ship ship = Ship("HMS ${Rng.randomAlienName(rnd)}", shipClass: ShipClass.fromEnum(shipClassType), techLvl: techLvl, owner: owner);

    for (final slot in shipClassType.slots) {
      ship.rndSystemInstaller.installRndSystemSlots(slot, shipClassType, techLvl, rnd);
    }

    ship.toggleEngines(Domain.impulse);
    int attempts = 0;
    int t = techLvl;
    var e = ship.ticker.tick().energy;
    var bw = ship.systemControl.battleWorth;
    while ((e < 0 || bw == BattleLevel.noPower) && attempts < 9) {
      t = min(t+1,10);
      glog("${ship.name}: Warning: underpowered ($e / $bw), attempting again ($attempts) at tech level: $t", level: DebugLevel.Warning);
      final pg = ship.systemControl.getPower();
      if (pg != null) {
        final slot = ship.systemControl.getSlot(pg)!.slot;
        ship.systemControl.uninstallSystem(pg, remove: true);
        final report = ship.rndSystemInstaller.installRndSystemSlot(slot, 0, shipClassType, t, rnd);
        if (report?.result != InstallResult.success) {
          glog("${report?.assignment?.system?.name} : ${report?.result.name ?? '?'}", level: DebugLevel.Warning);
        }
        else {
          glog("Installed: ${report?.assignment?.system?.name}",level: DebugLevel.Warning);
        }
      }
      e = ship.ticker.tick().energy;
      bw = ship.systemControl.battleWorth;
      attempts++;
    }
    return ship;
  }

}