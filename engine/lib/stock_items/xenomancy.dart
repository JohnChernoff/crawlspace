import 'package:crawlspace_engine/grid.dart';

enum XenoFlags {
  trans, damage, summoning, directional, targeted, aoe, escape
}

enum XenomancySchool {
  quantum("quantum"), //translocations
  elemental("elemental"), //elemental
  dark("dark"), //indirect necromancy (dark matter)
  antimatter("antimatter"), //direct necromancy (damage)
  astramancy("astramancy"), //conjurations
  gravimancy("gravimancy"), //hexes
  chronomancy("chronomancy"); //abjuration/summoning
  final String schoolName;
  const XenomancySchool(this.schoolName);
}

enum XenomancySpell {
  foldSpace("Fold Space","FSpace",[XenomancySchool.gravimancy],
      level: 1, matterCost: 4,timeout: 250, flags: [XenoFlags.escape]),
  leap("Quantum Leap","Qleap",[XenomancySchool.quantum],
      level: 1, matterCost: 1, timeout: 50, flags: [XenoFlags.trans]),
  firecloud("Fire Cloud","FCloud",[XenomancySchool.elemental],
      level: 2, matterCost: 2, timeout: 100,flags: [XenoFlags.damage, XenoFlags.aoe]),
  invisibility("Dark Cloak","Invis",[XenomancySchool.dark],
      level: 3, matterCost: 3,timeout: 500, flags: []),
  quarkblast("Quarkblast","QBlast",[XenomancySchool.antimatter],
      level: 1, matterCost: 2, timeout: 10, flags: [XenoFlags.targeted]),
  starburst("Starburst","SBurst",[XenomancySchool.astramancy],
      level: 2, matterCost: 3, timeout: 50, flags: [XenoFlags.directional]),
  flux("Mass Flux","MFlux",[XenomancySchool.gravimancy],
      level: 3, matterCost: 4, timeout: 10,flags: [XenoFlags.aoe]),
  slow("Slow","Slow",[XenomancySchool.chronomancy],
      level: 3, matterCost: 5, timeout: 10, flags: [XenoFlags.targeted]),
  phaseShift("Phase Shift: Summon Alien","PS_Alien",[XenomancySchool.chronomancy],
      level: 4,matterCost: 8, timeout: 100, flags: [XenoFlags.summoning],
      instability: .5, domain: Domain.system)
  ;
  final List<XenomancySchool> schools;
  final String spellName,shortName;
  final int level, matterCost, timeout;
  final List<XenoFlags> flags;
  final Domain domain;
  final double instability;
  const XenomancySpell(this.spellName,this.shortName,this.schools, {
    required this.level, required this.matterCost, required this.timeout, required this.flags,
    this.instability = .1, this.domain = Domain.impulse});
}