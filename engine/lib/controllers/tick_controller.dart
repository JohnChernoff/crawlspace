import 'package:crawlspace_engine/controllers/fugue_controller.dart';
import 'package:crawlspace_engine/controllers/pilot_controller.dart';
import '../actors/pilot.dart';
import '../fugue_engine.dart';
import '../galaxy/geometry/location.dart';
import '../galaxy/hazards.dart';
import '../ship/ship.dart';
import 'layer_transit_controller.dart';

class TickController extends FugueController {
  int auTick = 0;

  TickController(super.fm);

  //returns false if player location domain changes
  bool runUntilNextPlayerTurn() { //fm.glog("Running until next turn...");
    final playShip = fm.playerShip;
    final domain = playShip?.loc.domain;
    final pilots = List.of(fm.activePilots); // ← Copy the list
    do {
      for (Pilot p in pilots) { //print("${p.name}'s turn");
        try {
          p.tick(fm);
          Ship? ship = fm.galaxy.ships.byPilot(p);
          if (ship != null) {
            final loc = ship.loc;
            final interactables = fm.galaxy.ships.interactable(loc);
            //print("Interactables for ${ship.name}, ${ship.loc.upper}: $interactables");
            final interactive = interactables.contains(fm.playerShip);
            if (loc.system == fm.playerShip?.loc.system && fm.player.locale is AboardShip && interactive) {
              fm.pilotController.npcShipAct(ship);
            } else if (loc is ImpulseLocation) { //print("Escaping impulse...");
              fm.layerTransitController.changeDomain(ship, DomainDir.up);
              fm.pilotController.action(p, ActionType.movement);
            }
          }
        } on ConcurrentModificationError {
          glog("Skipping: ${p.name}",error: true);
        }
      }
      auTick++;
      fm.player.tick(fm);
      if (playShip != null) {
        final tickResult = playShip.ticker.tick(fm: fm);
        if (tickResult.newCell) fm.pilotController.wakePilot(fm.player);
      }
      //if (playShip != null && playShip.loc is ImpulseLocation) {
      for (final cell in fm.player.loc.map.values) {
        cell.effects.tickAll();
      }//}
    } while (!fm.player.ready);

    if (playShip != null) { //print("Counter..."); //print(playShip.nav.movePreviewer.counter);
      final loc = playShip.loc; if (loc is ImpulseLocation) {
        if (loc.sectorCell.hasHaz(Hazard.ion)) {
          loc.cell.hodgeTick(Hazard.ion, fm.mapRnd);
        }
      }
      for (final s in fm.galaxy.ships.atDomain(playShip.loc).where((s) => s.npc)) playShip.detect(s);
    }
    fm.update();
    fm.player.newTurn();
    return fm.playerShip?.loc.domain == domain;
  }

}