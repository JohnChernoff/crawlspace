import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/rng/rng.dart';
import 'package:crawlspace_engine/ship/hangar_ship.dart';
import 'package:crawlspace_engine/ship/systems/ship_system.dart';
import '../actors/pilot.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';
import '../galaxy/system.dart';
import '../ship/ship.dart';
import '../stock_items/stock_ships.dart';

class ShipGenerator {
  static Ship generateShip(System system, Galaxy galaxy, Random rnd, {isPirate = false}) {
    final location = SectorLocation(system, system.map.rndCoord(rnd)); //galaxy.rndLoc(rnd);
    final pilot = Pilot(Rng.generateName(rnd: rnd),rnd: rnd, loc: AtEnvironment.fromSystem(location), galaxy: galaxy, isPirate: isPirate);
    final level = max(0,1 - (galaxy.topo.distance(location.loc.system, galaxy.findHomeworld(pilot.faction.species)) / galaxy.maxJumps));
    final techLvl = max(1,(level * 10).round()); //TODO: something more sophisticated?
    //print("Faction: ${pilot.faction.name}, tech: $level, $techLvl");
    ShipType shipType = Rng.weightedRandom(pilot.faction.shipWeights.normalized,rnd);
    bool okType(ShipType type) {
      if (level > shipType.dangerLvl) return false;
      if (pilot.faction.isPirate || pilot.faction.isWarmonger) {
        return rnd.nextDouble() < .1 || type.slots.map((s) => s.type).contains(ShipSystemType.weapon);
      }
      return true;
    }
    while (okType(shipType)) {
      if (rnd.nextDouble() < shipType.dangerLvl) {
        shipType = ShipType.values.elementAt(rnd.nextInt(ShipType.values.length));
      } else {
        shipType = Rng.weightedRandom(pilot.faction.shipWeights.normalized,rnd);
      }
    }
    //print("Ship Type: $shipType");
    final shipClassType = ShipClassType.values.firstWhereOrNull((t) => t.type == shipType) ?? ShipClassType.mentok;
    //print("Ship Type: $shipClassType");
    Ship ship = Ship("HMS ${Rng.randomAlienName(rnd)}",pilot: pilot, location: location, shipClass: ShipClass.fromEnum(shipClassType));
    ship.rndSystemInstaller.installRndPower(8, rnd);
    ship.rndSystemInstaller.installRndEngine(Domain.impulse, techLvl, rnd);
    ship.rndSystemInstaller.installRndEngine(Domain.system, techLvl, rnd); //no hyperspace
    ship.rndSystemInstaller.installRndShield(techLvl, rnd);
    ship.rndSystemInstaller.installRndWeapon(techLvl, rnd);

    return ship;
  }

  static HangarShip generateHangarShip(System system, Galaxy galaxy, Random rnd, {isPirate = false}) {
    return HangarShip.toHangar(generateShip(system, galaxy, rnd));
  }

}