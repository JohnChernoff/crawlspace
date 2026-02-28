import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/foosham/crowd.dart';
import 'package:crawlspace_engine/galaxy/civ_model.dart';

import '../galaxy/system.dart';
import '../stock_items/species.dart';
import 'throws.dart';

enum FooShamPlayer {
  player("Player"),
  house("House");
  final String name;
  const FooShamPlayer(this.name);
}

class FooShamResult {
  CrowdReaction? crowdReaction;
  String winThrow, loseThrow;
  FooShamGame game;
  FooShamResult(this.winThrow,this.loseThrow,this.game,{this.crowdReaction});

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    if (winThrow == loseThrow) {
      sb.write("$winThrow vs. $loseThrow... ");
      if (game.houseWinsOnTie) {
        sb.write("house wins on a tie");
      } else {
        sb.write("tie! No points.");
      }
    } else {
      sb.write("$winThrow beats $loseThrow");
    }
    return sb.toString();
  }
}

enum FooShamDifficulty {
  easy,
  medium,
  hard;
}

enum FooShamMode {
  simple,complex
}

class FooShamGame {
  final FooShamMode mode = FooShamMode.simple;
  late final bool speciesMode;
  late final List<String> throwList;
  final FooShamDifficulty difficulty;
  int turn = 0;
  Map<String,Set<String>> beatMap = {};
  Map<String,Set<String>> knownBeatMap = {};
  Map<FooShamPlayer,int> scoreMap = {};
  Map<String, int> playerThrowFrequency = {}; // track player's throws
  int winscore = 12;
  Random rnd;
  bool houseWinsOnTie = true;
  FooShamPlayer? get winner => scoreMap.entries.firstWhereOrNull((s) => s.value >= winscore)?.key;
  final CivModel? civMod;
  final System system;
  late final Species? culture;

  FooShamGame(this.system,this.rnd, {ThrowList? customList, this.difficulty = FooShamDifficulty.easy, this.civMod}) {
    speciesMode = customList == null;
    culture = speciesMode ? civMod!.cantinaCulture(system,rnd) : null;
    throwList = customList?.list ?? speciesThrows.entries.map((t) => t.key).toList();

    for (final p in FooShamPlayer.values) {
      scoreMap[p] = 0;
    }
    for (final t in throwList) {
      beatMap[t] = {};
      knownBeatMap[t] = {};
      playerThrowFrequency[t] = 0;
    }
    print("Dominant species: ${culture?.name}");
    for (int i = 0; i < throwList.length; i++) {
      for (int j = i + 1; j < throwList.length; j++) {
        final t1 = throwList[i];
        final t2 = throwList[j];
        if (calcBeat(t1, t2, culture: culture)) {
          beatMap[t1]!.add(t2);
        } else {
          beatMap[t2]!.add(t1);
        }
      }
    }
  }

  bool calcBeat(String t1, String t2, {Species? culture}) {
    if (speciesMode && civMod != null) {
      if (culture == null) return rnd.nextBool();

      final s1 = speciesThrows[t1]!.species;
      final s2 = speciesThrows[t2]!.species;

      // Case 1: one of the throws IS the house culture — honor mechanic
      // Nebula loses to respected species (deference), beats hostile ones
      if (s1 == culture || s2 == culture) {
        final other = s1 == culture ? s2 : s1;
        final respect = civMod!.politicalMap[culture]?[other] ?? 0.5;
        final cultureThrowIsT1 = s1 == culture;
        return cultureThrowIsT1
            ? respect < 0.5   // Nebula (t1) beats t2 only if hostile toward t2
            : respect >= 0.5; // t1 beats Nebula (t2) if culture respects t1
      }

      // Case 2: neither throw is house culture — power mechanic
      // More respected species wins
      final respectS1 = civMod!.politicalMap[culture]?[s1] ?? 0.5;
      final respectS2 = civMod!.politicalMap[culture]?[s2] ?? 0.5;
      final diff = (respectS1 - respectS2).clamp(-1.0, 1.0);
      final probability = 0.5 + diff * 0.2; // higher respect = wins more often
      return rnd.nextDouble() < probability;
    }
    return rnd.nextBool();
  }

  FooShamResult playThrow(String t) {
    turn++;
    String houseThrow = _getHouseThrow();
    playerThrowFrequency[t] = playerThrowFrequency[t]! + 1;

    final bool playerWon;
    final bool tied;
    final String winThrow;
    final String loseThrow;

    if (t == houseThrow) {
      tied = true;
      playerWon = false;
      winThrow = t;
      loseThrow = houseThrow;
      if (houseWinsOnTie) score(FooShamPlayer.house);
    } else if (beatMap[t]!.contains(houseThrow)) {
      tied = false;
      playerWon = true;
      winThrow = t;
      loseThrow = houseThrow;
      knownBeatMap[t]?.add(houseThrow);
      score(FooShamPlayer.player);
    } else {
      tied = false;
      playerWon = false;
      winThrow = houseThrow;
      loseThrow = t;
      knownBeatMap[houseThrow]?.add(t);
      score(FooShamPlayer.house);
    }

    final reaction = (speciesMode && civMod != null && culture != null)
        ? CrowdReaction.fromResult(t, houseThrow, playerWon, tied, civMod!, culture!, rnd)
        : CrowdReaction.none;

    return FooShamResult(winThrow, loseThrow, this, crowdReaction: reaction);
  }
  String _getHouseThrow() {
    if (turn <= 1) return rndThrow;
    switch(difficulty) {
      case FooShamDifficulty.easy:
        return rndThrow;

      case FooShamDifficulty.medium:
      // Pick the most frequent player throw, then counter it 50% of the time
        var mostFrequent = playerThrowFrequency.entries
            .reduce((a, b) => a.value > b.value ? a : b).key;
        print("Expecting: $mostFrequent");
        var counters = knownBeatMap.entries
            .where((e) => e.value.contains(mostFrequent))
            .map((e) => e.key)
            .toList();

        return (counters.isNotEmpty && rnd.nextDouble() < 0.5)
            ? counters[rnd.nextInt(counters.length)]
            : rndThrow;

      case FooShamDifficulty.hard:
      // Same logic as medium but 66% of the time
        var mostFrequent = playerThrowFrequency.entries
            .reduce((a, b) => a.value > b.value ? a : b).key;
        var counters = knownBeatMap.entries
            .where((e) => e.value.contains(mostFrequent))
            .map((e) => e.key)
            .toList();

        return (counters.isNotEmpty && rnd.nextDouble() < 0.66)
            ? counters[rnd.nextInt(counters.length)]
            : rndThrow;
    }
  }

  String get rndThrow => throwList.elementAt(rnd.nextInt(throwList.length));

  String beatInfo(String t) {
    final beats = knownBeatMap[t] ?? {};
    if (beats.isEmpty) return "";
    final names = beats.map((s) => s.length > 3 ? s.substring(0, 3) : s).join(", ");
    return "(beats $names)";
  }

  String currentScore() {
    StringBuffer sb = StringBuffer();
    if (winner != null) {
      sb.write("${winner!.name} wins!");
    } else {
      for (final ps in scoreMap.entries) {
        sb.write("${ps.key.name}: ${ps.value} points ");
      }
    }
    return sb.toString();
  }

  void score(FooShamPlayer p) {
    scoreMap[p] = scoreMap[p]! + 1;
  }

}
