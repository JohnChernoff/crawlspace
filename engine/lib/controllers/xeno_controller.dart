import 'dart:async';
import 'dart:math';
import 'package:crawlspace_engine/location.dart';
import 'package:crawlspace_engine/pilot.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/stock_items/xenomancy.dart';
import '../color.dart';
import '../effects.dart';
import '../fugue_engine.dart';

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
  Completer<SpaceLocation>? targetCompleter;

  XenoController(this.ship);

  XenoResult generateEffect(XenomancySpell spell, FugueEngine fm) {
    if (spell.domain != fm.player.loc.domain) return XenoResult.badLayer;
    if (ship.xenoMatter < spell.matterCost) return XenoResult.insufficientMatter;
    ship.xenoMatter -= spell.matterCost;
    final powBonus = ship.systemControl.engine?.xenoPowerBonus[spell.schools.first] ?? 0;
    final power = calcPower(spell, bonus: powBonus);
    final castBonus = ship.systemControl.engine?.xenoCastBonus[spell.schools.first] ?? 0;
    final baseChance = effectProb(spell, bonus: 0);
    final finalChance = applyBonus(baseChance, castBonus);
    final illegitimacy = 1 - baseChance;
    final overreach = max(0, spell.level/9 - ship.pilot.skills[SkillType.xeno]!);
    final catastropheChance =
        ((illegitimacy * 0.6 + overreach * 0.4)
            * (1 + spell.instability)).clamp(0.0, 0.5);

    final roll = fm.effectRnd.nextDouble();
    if (roll > finalChance) {
      final failureRoll = (roll - finalChance) / (1 - finalChance);
      return failureRoll < catastropheChance
          ? XenoResult.castastrophe
          : XenoResult.castFail;
    }

    if (spell == XenomancySpell.foldSpace) {
      foldSpace(power);
    } else if (spell == XenomancySpell.firecloud) {
      acquireTarget(fm).then((target) => fireCloud(power, target));
    } else {
      return XenoResult.unsupported;
    }
    return XenoResult.success;
  }

  double capacityFactor(double shipXeno, { k = 25.0}) => shipXeno / (shipXeno + k);
  double energyFactor(double shipEnergy, { k = 1000.0}) => shipEnergy / (shipEnergy + k);

  double calcPower(XenomancySpell spell, {int? bonus}) {
    final intelligence = ship.pilot.attributes[AttribType.int] ?? .5;
    final skill = ship.pilot.skills[SkillType.xeno]!;
    final scale = spell.level / 9.0;

    final intFactor = 0.5 + 0.5 * intelligence;
    final skillFactor = 0.4 + 0.6 * skill;
    final mastery = (intFactor * skillFactor).clamp(0.0, 1.0);

    final shipPower =  energyFactor(ship.systemControl.getPower()?.currentMaxEnergy ?? 0);
    final shipXenoPower =  capacityFactor(ship.shipClass.maxXeno);
    final capacity =  sqrt(shipPower * shipXenoPower);

    final overreach = max(0, scale - skill);
    final accessFactor = pow(1 - overreach, 2);

    final supply = mastery * capacity * accessFactor;

    final demandExponent = 1.0 + 2.5 * scale;
    final basePower = pow(supply, demandExponent).toDouble();

    return applyBonus(
      basePower,
      bonus ?? ship.systemControl.engine?.xenoPowerBonus[spell.schools.first] ?? 0,
    ).clamp(0.0, 1.0);
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
        bonus ?? ship.systemControl.engine?.xenoCastBonus[spell.schools.first] ?? 0)
        .clamp(0.0, 1.0);
  }

  double applyBonus(double base, int bonus) {
    return 1 - (1 - base) * pow(bonusDecay, bonus);
  }

  Future<SpaceLocation> acquireTarget(FugueEngine fm) {
    fm.player.targetLoc = fm.player.loc;
    fm.setInputMode(InputMode.target);
    fm.msg("Pick a target (arrows to move, return to select):");
    targetCompleter = Completer();
    return targetCompleter!.future;
  }

  void foldSpace(double power) {
    final duration = ((XenomancySpell.foldSpace.timeout * 1.5) * power) + (XenomancySpell.foldSpace.timeout * .5);
    ship.effectMap.addEffect(ShipEffect.folding, duration.round());
  }

  void fireCloud(double power, SpaceLocation location) {
    //double cells = 8 * power;
    for (final cell in location.level.map.getAdjacentCells(location.cell)) {
      cell.effects.addEffect(CellEffect.fire, XenomancySpell.firecloud.timeout);
    }
  }


}