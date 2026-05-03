import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/rng/rng.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import 'package:crawlspace_engine/ship/systems/ship_sys.dart';
import 'package:crawlspace_engine/ship/systems/ship_system.dart';
import 'package:crawlspace_engine/stock_items/loadouts.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_engines.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_pile.dart';
import '../actors/pilot.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';
import '../galaxy/system.dart';
import '../ship/ship.dart';
import '../stock_items/ship/stock_ships.dart';

class ShipGenerator {
  static Ship generateShip(System system, Galaxy galaxy, Random rnd, {required Pilot owner}) {
    //print("Generating ship...");
    final location = SectorLocation(system, system.map.rndCoord(rnd)); //galaxy.rndLoc(rnd);
    final level = max(0,1 - (galaxy.topo.distance(location.system, galaxy.findHomeworld(owner.faction.species)) / galaxy.maxJumps));
    final techLvl = max(1,(level * 10).round()); //TODO: something more sophisticated?
    //print("Faction: ${pilot.faction.name}, tech: $level, $techLvl");
    final loadout = Loadout.bySpecies(owner.faction.species.getStock());
    ShipType shipType = loadout.shipMap.keys.elementAt(rnd.nextInt( loadout.shipMap.keys.length)); //TODO: weigh by hw prox
    //Rng.weightedRandom(owner.faction.shipWeights.normalized,rnd);
    bool okType(ShipType type) {
      if (shipType.dangerLvl > techLvl) return false;
      if (owner.faction.isPirate || owner.faction.isWarmonger) {
        return rnd.nextDouble() < .1 || type.slots.map((s) => s.type).contains(ShipSystemType.weapon);
      }
      return true;
    }
    int guard = 0;
    while (!okType(shipType)) {
      if (++guard > 1000) {
        throw StateError("Ship generation failed to find a valid ship type for ${owner.faction.name}");
      }
      if (rnd.nextDouble() < shipType.dangerLvl) {
        shipType = ShipType.values.elementAt(rnd.nextInt(ShipType.values.length));
      } else {
        shipType = Rng.weightedRandom(owner.faction.shipWeights.normalized,rnd);
      }
    }
    final shipClassType = loadout.shipMap[shipType]?.shipClass ?? ShipClassType.mentok;
    //ShipClassType.values.firstWhereOrNull((t) => t.type == shipType) ?? ShipClassType.mentok;
    Ship ship = Ship("HMS ${Rng.randomAlienName(rnd)}", shipClass: ShipClass.fromEnum(shipClassType), techLvl: techLvl, owner: owner);
    //print("Generated ship: $ship");
    return ship;
  }

  static bool installRandomSystem(Ship ship, ShipSystemType type, Random rnd, { Domain? domain }) {
    int techLvl = ship.techLvl ?? 1;
    return switch (type) {
      ShipSystemType.weapon => ship.rndSystemInstaller.installRndWeapon(techLvl, rnd),
      ShipSystemType.launcher => ship.rndSystemInstaller.installRndWeapon(techLvl, rnd),
      ShipSystemType.engine => (domain != null) ? ship.rndSystemInstaller.installRndEngine(domain,techLvl, rnd) : false,
      ShipSystemType.shield => ship.rndSystemInstaller.installRndShield(techLvl, rnd),
      ShipSystemType.power => ship.rndSystemInstaller.installRndShield(techLvl, rnd),
      ShipSystemType.adapter => false,
      ShipSystemType.sensor => false,
      ShipSystemType.ammo => false,
      // TODO: Handle this case.
      ShipSystemType.emitter => throw UnimplementedError(),
      // TODO: Handle this case.
      ShipSystemType.converter => throw UnimplementedError(),
      // TODO: Handle this case.
      ShipSystemType.quarters => throw UnimplementedError(),
      // TODO: Handle this case.
      ShipSystemType.scrapper => throw UnimplementedError(),
      // TODO: Handle this case.
      ShipSystemType.unknown => throw UnimplementedError(),
    };
  }

  static void installRandomSystems(Ship ship, Random rnd) {
    final techLvl = ship.techLvl ?? 5;
    ship.rndSystemInstaller.installRndPower(8, rnd);
    ship.rndSystemInstaller.installRndEngine(Domain.impulse, techLvl, rnd);
    ship.rndSystemInstaller.installRndEngine(Domain.system, techLvl, rnd); //no hyperspace
    ship.rndSystemInstaller.installRndShield(techLvl, rnd);
    ship.rndSystemInstaller.installRndWeapon(techLvl, rnd);
  }

  static void installSpeciesSystems(Ship ship, Random rnd) {
    final stock = ship.pilot.faction.species.getStock();
    final loadout = Loadout.bySpecies(stock);
    print("${ship.shipClass.name}, ${ship.shipClass.type}");
    print("$stock: ${loadout.shipMap}");

    final systems = loadout.shipMap[ship.shipClass.type]?.systems;
    if (systems != null && systems.isNotEmpty) for (final system in systems) {

      final report = ship.install(system.createSystem(),active: true);
      if (report?.result == InstallResult.success) {
        print("Installed: ${system.name}");
      } else {
        if (system.type == ShipSystemType.engine) {
          installRandomSystem(ship, system.type, rnd, domain: stockEngines[system]?.domain);
        } else {
          installRandomSystem(ship, system.type, rnd);
        }
      }
    }
  }

}