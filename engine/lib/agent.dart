import 'dart:math';
import 'fugue_engine.dart';
import 'pilot.dart';
import 'system.dart';

enum AgentSystemReport {none,lastKnown,current}

class Agent extends Pilot {
  System? sighted;
  System? lastKnown;
  int clueLvl;
  int speed = 1;
  int tracked = 0;

  Agent(super.name,super.system,super.rnd,this.clueLvl);

  System pickLink(FugueEngine game) {
    if (sighted != null) {
      if (system == sighted) {
        sighted = null;
      } else {
        List<System> path = game.galaxy.systemGraph.shortestPath(system,sighted!);
        if (path.length > 1) return path.elementAt(1);
      }
    }
    if (game.rnd.nextInt(100) < clueLvl) {
      List<System> path = game.galaxy.systemGraph.shortestPath(system,game.player.system);
      if (path.length > 1) return path.elementAt(1);
    }
    return system.links.elementAt(game.rnd.nextInt(system.links.length));
  }

  void track(int t) {
    tracked = t; lastKnown = system;
  }

  void investigate(System sys) { //print("$name -> ${system.name}");
    system = sys;
    if (tracked > 0) {
      lastKnown = system;
      tracked = max(tracked - 1, 0);
    }
  }

  int movesPerTurn() {
    return speed * (sighted != null ? 2 : 1);
  }
}