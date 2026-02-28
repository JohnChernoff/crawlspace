import 'dart:math';
import 'package:crawlspace_engine/foosham/throws.dart';
import 'package:crawlspace_engine/galaxy/civ_model.dart';
import '../stock_items/species.dart';

class CrowdReaction {
  final String message;
  final double intensity; // -1.0 hostile → 0.0 neutral → 1.0 approving

  const CrowdReaction(this.message, this.intensity);

  static const none = CrowdReaction("", 0.0);

  factory CrowdReaction.fromResult(String thrown, String houseThrow,
      bool playerWon, bool tied, CivModel civMod, Species culture, Random rnd) {
    final s = speciesThrows[thrown]?.species;
    final hs = speciesThrows[houseThrow]?.species;
    if (s == null || hs == null) return CrowdReaction.none;

    final thrownRespect = civMod.politicalMap[culture]?[s] ?? 0.5;
    final houseRespect = civMod.politicalMap[culture]?[hs] ?? 0.5;

    // ── House avatar thrown ──────────────────────────────────────────────────────
    if (s == culture) {
      if (tied) return _pickR([
        CrowdReaction("The crowd exchanges uncertain glances.", -0.1),
        CrowdReaction("Nobody quite knows how to feel.", 0.0),
      ],rnd);
      if (playerWon) return _pickR([
        CrowdReaction("Someone raises a glass reluctantly.", 0.3),
        CrowdReaction("A few nods — the house throw earned it.", 0.4),
      ],rnd);
      // Lost with house avatar
      return _pickR([
        CrowdReaction("The crowd winces.", -0.3),
        CrowdReaction("An uncomfortable silence.", -0.4),
        CrowdReaction("That wasn't supposed to happen.", -0.5),
      ],rnd);
    }

    // ── Both throws politically charged ─────────────────────────────────────────
    if (thrownRespect > 0.65 && houseRespect < 0.35) {
      // Beloved vs hated
      if (playerWon) return _pickR([
        CrowdReaction("The room erupts. Someone buys you a drink.", 1.0),
        CrowdReaction("A cheer goes up — this one meant something.", 0.9),
        CrowdReaction(
            "Even people not watching your table turn to look.", 0.85),
        CrowdReaction(
            "The barkeep slides something stronger your way, unprompted.",
            0.95),
      ],rnd);
      return _pickR([
        CrowdReaction("A collective intake of breath.", -0.4),
        CrowdReaction("The mood shifts in a way you can't quite name.", -0.5),
        CrowdReaction("Someone mutters. Others nod.", -0.4),
        CrowdReaction("You get the feeling you've upset a narrative.", -0.6),
      ],rnd);
    }

    if (thrownRespect < 0.35 && houseRespect > 0.65) {
      // Hated vs beloved
      if (playerWon) return _pickR([
        CrowdReaction("The room goes dangerously quiet.", -0.9),
        CrowdReaction("Nobody moves. Someone is staring at you.", -0.85),
        CrowdReaction(
            "You've won the hand and possibly lost something else.", -0.95),
        CrowdReaction("The barkeep looks away deliberately.", -0.8),
      ],rnd);
      return _pickR([
        CrowdReaction("The crowd exhales audibly.", 0.4),
        CrowdReaction("Quiet satisfaction ripples through the room.", 0.5),
        CrowdReaction(
            "Order, as far as this cantina is concerned, has been restored.",
            0.6),
        CrowdReaction(
            "Someone laughs — not unkindly, but not kindly either.", 0.3),
      ],rnd);
    }

    // ── House avatar in house throw ──────────────────────────────────────────────
    if (hs == culture && playerWon && thrownRespect >= 0.5) {
      return _pickR([
        CrowdReaction("The crowd applauds — honor satisfied.", 0.7),
        CrowdReaction("A warm murmur of approval.", 0.6),
        CrowdReaction("The barkeep nods slowly.", 0.5),
      ],rnd);
    }

    if (hs == culture && playerWon && thrownRespect < 0.25) {
      return _pickR([
        CrowdReaction("The crowd goes very quiet.", -0.7),
        CrowdReaction("Someone stands up slowly.", -0.8),
        CrowdReaction("You feel the temperature drop.", -0.75),
      ],rnd);
    }

    // ── Single throw politically significant ─────────────────────────────────────
    if (!playerWon && thrownRespect < 0.25) {
      return _pickR([
        CrowdReaction("The crowd seems quietly satisfied.", 0.3),
        CrowdReaction("A few smirks around the table.", 0.2),
        CrowdReaction("As expected, some would say.", 0.25),
      ],rnd);
    }

    if (playerWon && thrownRespect > 0.75) {
      return _pickR([
        CrowdReaction("The crowd cheers genuinely.", 0.8),
        CrowdReaction("A ripple of real pleasure through the room.", 0.75),
        CrowdReaction("Even the barkeep smiles.", 0.7),
      ],rnd);
    }

    if (!playerWon && thrownRespect > 0.75) {
      return _pickR([
        CrowdReaction("The crowd sighs.", -0.2),
        CrowdReaction("Someone shakes their head.", -0.25),
        CrowdReaction("A sympathetic groan nearby.", -0.2),
      ],rnd);
    }

    if (playerWon && thrownRespect < 0.25) {
      return _pickR([
        CrowdReaction("An uneasy stir at the nearby tables.", -0.35),
        CrowdReaction("Someone mutters something you don't catch.", -0.3),
      ],rnd);
    }

    if (hs == culture && !playerWon && houseRespect < 0.25) {
      return _pickR([
        CrowdReaction("The crowd can't quite believe what just happened.", -0.6),
        CrowdReaction("An embarrassed silence settles over the room.", -0.5),
        CrowdReaction("Someone at the bar puts their head in their hands.", -0.55),
      ], rnd);
    }

    // ── Neutral — silence is information ────────────────────────────────────────
    return CrowdReaction.none;
  }

  static CrowdReaction _pickR(List<CrowdReaction> list, Random rnd) => list.elementAt(rnd.nextInt(list.length));
}


