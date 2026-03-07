import 'dart:math';
import 'package:crawlspace_engine/actors/pilot.dart';
import 'package:crawlspace_engine/item.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:crawlspace_engine/stock_items/xenomancy.dart';

enum ActivatorFlag {
  destructive,enhancement,translocational
}

enum ActivatorType {
  scroll,wand,rod
}

class ActivatorData {
  final ActivatorType type;
  final List<ActivatorFlag> flags;
  final double rarity;
  const ActivatorData({required this.type, required this.rarity, required this.flags});
}

enum StockActivator {
  emergencyWarpScroll(
      "Emergency Warp Conduit (single use)",
      "Scrambles the space/time continum and sends your ship hurling into a completely random star system",
      data: ActivatorData(type: ActivatorType.scroll, rarity: .75, flags: [ActivatorFlag.translocational])),
  statEnhanceScroll(
      "Stat enhancement handbook","A self-improvement manual",
      data: ActivatorData(type: ActivatorType.scroll, rarity: .1, flags: [ActivatorFlag.enhancement])),
  xenoEnhanceScroll(
      "Xenomancy enhancement handbook","A self-improvement manual",
      data: ActivatorData(type: ActivatorType.scroll, rarity: .2, flags: [ActivatorFlag.enhancement])),
  ;
  final String name, desc;
  final ActivatorData data;
  const StockActivator(this.name,this.desc,{required this.data});

}

class ActivatorFactory {

  static String condition(double quality) => switch(quality) {
    > .9 => "pristine",
    > .75 => "shiny",
    > .66 => "well-kept",
    > .5 => "used",
    > .33 => "ragged",
    > .25 => "banged-up",
    > .1 => "flimsy",
    _ => "dilapidated"
  };

  static Map<Species, List<AttribType>> speciesStatAffinity = {
    StockSpecies.vorlon.species: [AttribType.int, AttribType.wis],
    StockSpecies.krakkar.species: [AttribType.str, AttribType.con],
  };

  static Map<Species, List<XenomancySchool>> speciesXenoAffinity = {
    StockSpecies.vorlon.species: [XenomancySchool.dark, XenomancySchool.quantum],
  };

  static Activator generate(StockActivator stock, double quality, Random rnd, {Species? species}) => switch(stock) {
    StockActivator.emergencyWarpScroll => generateWarpScroll(quality),
    StockActivator.statEnhanceScroll   => generateStatScroll(_pickStat(rnd, species), quality),
    StockActivator.xenoEnhanceScroll   => generateXenoScroll(_pickSchool(rnd, species), quality),
  };

  static AttribType _pickStat(Random rnd, Species? species) {
    final affinity = speciesStatAffinity[species];
    if (affinity != null && rnd.nextDouble() > 0.3) {
      return affinity[rnd.nextInt(affinity.length)];
    }
    return AttribType.values[rnd.nextInt(AttribType.values.length)];
  }

  static XenomancySchool _pickSchool(Random rnd, Species? species) {
    final affinity = speciesXenoAffinity[species];
    if (affinity != null && rnd.nextDouble() > 0.3) {
      return affinity[rnd.nextInt(affinity.length)];
    }
    return XenomancySchool.values[rnd.nextInt(XenomancySchool.values.length)];
  }

  static Activator generateStatScroll(AttribType stat, double quality) {
    return Activator.fromStock(StockActivator.statEnhanceScroll, (fm,pilot) {
      pilot.attributes[stat] = min(1,pilot.attributes[stat]! + quality * .2);
      fm.msg("You feel ${stat.enhanceStr}");
      return true;
    },
        name: "${stat.name} Enhancement Handbook",
        desc: "A self-improvement manual (${stat.name})");
  }

  static Activator generateWarpScroll(double quality) {
    return Activator.fromStock(StockActivator.emergencyWarpScroll, (fm,pilot) {
      final ship = fm.shipRegistry.byPilot(pilot); if (ship != null) {
        fm.layerTransitController.emergencyWarp(ship);
        return true;
      } else return false;
    },
        name:"${condition(quality)} emergency warp conduit");
  }

  static Activator generateXenoScroll(XenomancySchool school, double quality) {
    return Activator.fromStock(StockActivator.statEnhanceScroll, (fm,pilot) {
      pilot.xenoSkills[school] = min(1,pilot.xenoSkills[school]! + quality * .2);
      fm.msg("You feel ${school.enhanceStr}");
      return true;
    },
        name: "${school.name} Enhancement Handbook",
        desc: "A self-improvement manual (${school.schoolName})");
  }
}