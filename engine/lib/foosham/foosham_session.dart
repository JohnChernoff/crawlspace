import 'package:crawlspace_engine/fugue_engine.dart';

import '../actors/pilot.dart';
import 'foosham.dart';

class FooshamSession {
  final Pilot pilot;
  final int stakes;
  late FooShamGame game;
  FugueEngine fm;
  bool gameOver = false;

  FooshamSession(this.pilot,this.stakes,this.fm) {
    game = FooShamGame(pilot.system,fm.aiRnd, difficulty: FooShamDifficulty.medium, civMod: fm.galaxy.civMod);
  }

  void gameThrow(String t) {
    final result = game.playThrow(t);
    fm.msg(result.toString());
    if (result.crowdReaction != null && result.crowdReaction!.message.isNotEmpty) {
      fm.msg(result.crowdReaction!.message);
    }
    gameOver = game.winner != null;
    if (game.winner == FooShamPlayer.player) {
      final winnings = stakes * 2;
      fm.msg("You win $winnings credits!");
      pilot.transaction(TransactionType.fooshamWin, winnings);
    }
  }

}