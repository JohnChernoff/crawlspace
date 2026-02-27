import 'dart:math';
import 'fugue_engine.dart';
import 'galaxy/galaxy.dart';
import 'location.dart';
import 'pilot.dart';
import 'galaxy/system.dart';

enum AgentSystemReport { none, lastKnown, current }

enum AgentPersonality {
  bloodhound("Vance"),
  analyst("Morrow"),
  strategist("Sable");
  final name;
  const AgentPersonality(this.name);
}

class Agent extends Pilot {
  final AgentPersonality personality;
  System? lastKnownPlayerLocation, lastKnown;
  double speed = 1;
  int tracked = 0;

  Agent(super.name, this.personality, {required super.loc, super.galaxy});

  // Called each turn by the engine
  void tick(FugueEngine fm) {
    super.tick(fm);  //final moves = movesPerTurn(fm.galaxy).round(); //TODO use this somehow
    if (fm.aiRng.nextDouble() < .1) _move(fm);
  }

  void _move(FugueEngine fm) {
    if (system.links.isEmpty || fm.player.system == system) return;
    final next = switch (personality) {
      AgentPersonality.bloodhound  => _bloodhoundPick(fm),
      AgentPersonality.analyst     => _analystPick(fm),
      AgentPersonality.strategist  => _strategistPick(fm),
    };
    _travelTo(next, fm);
  }

  void _travelTo(System dest, FugueEngine fm) {
    final newLoc = SystemLocation(dest, dest.map.rndCell(fm.galaxy.rnd));
    fm.shipRegistry.byPilot(this)!.move(newLoc, fm.shipRegistry); //print("Agent $name -> ${system}");
    if (fm.player.system == system) {
      lastKnownPlayerLocation = system;
      fm.msg("Agent Sighted!");
    }
  }

  // --- Bloodhound: follow playerHeatMap gradient greedily ---
  System _bloodhoundPick(FugueEngine fm) {
    final heatMap = fm.galaxy.heatMod.playerHeatMap;
    // 25% random noise so it doesn't get perfectly stuck in local maxima
    if (fm.rnd.nextDouble() < 0.25) {
      return system.links.elementAt(fm.rnd.nextInt(system.links.length));
    }
    return system.links.reduce((a, b) =>
    (heatMap[a] ?? 0) > (heatMap[b] ?? 0) ? a : b);
  }

  // --- Analyst: BFS toward lastKnown, falls back to heat if no lead ---
  System _analystPick(FugueEngine fm) {
    final target = lastKnownPlayerLocation ?? _hottest(fm);
    if (target == null || target == system) return _bloodhoundPick(fm);

    // pick the adjacent system that minimises distance to target
    return system.links.reduce((a, b) {
      final da = fm.galaxy.topo.distance(a, target);
      final db = fm.galaxy.topo.distance(b, target);
      return da < db ? a : b;
    });
  }

  // --- Strategist: intercept likely escape routes via rumor clusters ---
  System _strategistPick(FugueEngine fm) {
    final rumors = fm.galaxy.flowFields["rumors"]!;
    final heat = fm.galaxy.heatMod.playerHeatMap;

    // score = rumor activity * fed amplification - proximity penalty
    // (tries to get ahead of the player rather than follow)
    double scoreSystem(System s) {
      final rumorVal = rumors.val(s) as double;
      final fedAmp = fm.galaxy.fedKernel.val(s);
      final distFromAgent = fm.galaxy.topo.distance(system, s).toDouble();
      final distBias = exp(-distFromAgent / 6.0); // prefers reachable systems
      return rumorVal * fedAmp * distBias;
    }

    // find best target in whole galaxy, then path toward it
    final target = fm.galaxy.systems.reduce((a, b) =>
    scoreSystem(a) > scoreSystem(b) ? a : b);

    if (target == system) return _bloodhoundPick(fm);

    return system.links.reduce((a, b) {
      final da = fm.galaxy.topo.distance(a, target);
      final db = fm.galaxy.topo.distance(b, target);
      return da < db ? a : b;
    });
  }

  // find the single hottest system in the galaxy as a fallback target
  System? _hottest(FugueEngine fm) {
    final heatMap = fm.galaxy.heatMod.playerHeatMap;
    final candidates = fm.galaxy.systems
        .where((s) => (heatMap[s] ?? 0) > 0)
        .toList();
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) =>
    (heatMap[a] ?? 0) > (heatMap[b] ?? 0) ? a : b);
  }

  double movesPerTurn(Galaxy g) {
    final traffic = g.commerceKernel.val(system);
    return speed * (1 + log(1 + traffic));
  }

  AgentSystemReport playerReportFor(System s) {
    if (s == system) return AgentSystemReport.current; // && tracked > 0
    if (s == lastKnown) return AgentSystemReport.lastKnown;
    return AgentSystemReport.none;
  }
}
