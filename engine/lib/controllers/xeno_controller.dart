import 'dart:math';
import 'package:crawlspace_engine/pilot.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/stock_items/xenomancy.dart';
import '../color.dart';

enum ShipEffect {
  folding("Fold",GameColors.darkGreen),
  cloaking("Cloak",GameColors.gray);
  final String statusString;
  final GameColor color;
  const ShipEffect(this.statusString,this.color);
}

enum XenoResult {
  success("Effect created."),
  insufficientMatter("You don't have enough xenomatter."),
  castFail("You fail to generate the effect."),
  castastrophe("Uhoh..."),
  badLayer("Incorrect context."),
  unsupported("Unsupported effect.");
  final String msg;
  const XenoResult(this.msg);
}

class XenoController {
  static const double bonusDecay = 0.85;
  final Ship ship;
  XenoController(this.ship);

  XenoResult generateEffect(XenomancySpell spell, Random rnd) {
    if (ship.xenoMatter < spell.matterCost) return XenoResult.insufficientMatter;
    ship.xenoMatter -= spell.matterCost;
    final bonus = ship.systemControl.engine?.xenoBonus[spell.schools.first] ?? 0;
    final baseChance = effectProb(spell, bonus: 0);
    final finalChance = applyBonus(baseChance, bonus);
    final illegitimacy = 1 - baseChance;
    final overreach = max(0, spell.level/9 - ship.pilot.skills[SkillType.xeno]!);
    final catastropheChance =
        ((illegitimacy * 0.6 + overreach * 0.4)
            * (1 + spell.instability)).clamp(0.0, 0.5);

    final roll = rnd.nextDouble();
    if (roll > finalChance) {
      final failureRoll = (roll - finalChance) / (1 - finalChance);
      return failureRoll < catastropheChance
          ? XenoResult.castastrophe
          : XenoResult.castFail;
    }

    if (spell == XenomancySpell.foldSpace) {
      foldSpace();
    } else {
      return XenoResult.unsupported;
    }
    return XenoResult.success;
  }

  double effectProb(XenomancySpell spell, {int? bonus}) {
    final intelligence = ship.pilot.attributes[AttribType.int] ?? .5;
    final level = spell.level / 9;
    final skill = ship.pilot.skills[SkillType.xeno]!;

    final intFactor = 0.5 + 0.5 * intelligence;
    final levFactor = 0.33 + 0.67 * (1 - level);
    final skillFactor = 0.25 + 0.75 * skill;

    double baseProb = intFactor * levFactor * skillFactor;
    return applyBonus(baseProb,
        bonus ?? ship.systemControl.engine?.xenoBonus[spell.schools.first] ?? 0)
        .clamp(0.0, 1.0);
  }

  double applyBonus(double baseProb, int bonus) {
    return 1 - (1 - baseProb) * pow(bonusDecay, bonus);
  }

  void foldSpace() {
    ship.applyEffect(ShipEffect.folding, XenomancySpell.foldSpace.timeout);
  }


}