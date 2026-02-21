import 'dart:math';
import 'fugue_engine.dart';
import 'galaxy/galaxy.dart';
import 'pilot.dart';
import 'galaxy/system.dart';

enum AgentSystemReport {none,lastKnown,current}

class Agent extends Pilot {
  System? sighted;
  System? lastKnown;
  int clueLvl;
  double speed = 1;
  int tracked = 0;
  Map<System,double> beliefHeat = {};

  Agent(super.name,super.rnd,this.clueLvl, {super.sys,super.galaxy});

  System pickLink(FugueEngine fm, Random rnd) {
    System best = system.links.first;
    double bestScore = score(best,fm);

    for (final n in system.links) {
      final s = score(n,fm);
      if (s > bestScore) {
        best = n;
        bestScore = s;
      }
    }

    if (rnd.nextDouble() < 0.3) return system.links.elementAt(rnd.nextInt(system.links.length));
    return best;
  }

  double score(System s, FugueEngine fm) {
    final auth = fm.galaxy.fedLevel.val(s);
    final commerce = fm.galaxy.commerceLevel.val(s);
    final bias = biasToLastKnown(s, fm);

    return auth * 1.5 + bias * 2.0 + commerce * 0.2;
  }

  void track(int t) {
    tracked = t; lastKnown = system;
  }

  void investigate(System sys) {
    system = sys;
    if (tracked > 0) {
      lastKnown = system;
      tracked--;
    } else {
      sighted = null;
    }
  }

  void observe(System s, Galaxy g) {
    //beliefHeat[s] = fm.galaxy.playerBeliefKernel.val(s);
    beliefHeat[s] = g.heatMod.detectionRisk(s);
  }

  double movesPerTurn(Galaxy g) {
    final traffic = g.commerceLevel.val(system);
    return speed * (1 + log(1 + traffic));
  }

  double biasToLastKnown(System s, FugueEngine fm) {
    if (lastKnown == null) return 0;
    final d = fm.galaxy.topo.distance(s,lastKnown!);
    return exp(-d / 4.0);
  }
}