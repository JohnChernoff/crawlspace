enum XenoFlags {
  trans, damage, summoning, directional, targeted, aoe
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
  leap("Quantum Leap","Qleap",[XenomancySchool.quantum],1,1,50,[XenoFlags.trans]),
  firecloud("Fire Cloud","FCloud",[XenomancySchool.elemental],2,2,10,[]),
  invisibility("Dark Cloak","Invis",[XenomancySchool.dark],3,3,500,[]),
  quarkblast("Quarkblast","QBlast",[XenomancySchool.antimatter],1,2,10,[XenoFlags.targeted]),
  starburst("Starburst","SBurst",[XenomancySchool.astramancy],2,3,50,[XenoFlags.directional]),
  flux("Mass Flux","MFlux",[XenomancySchool.gravimancy],3,4,10,[XenoFlags.aoe]),
  slow("Slow","Slow",[XenomancySchool.chronomancy],3,5,10,[XenoFlags.targeted]),
  phaseShift("Phase Shift: Summon Alien","PS_Alien",[XenomancySchool.chronomancy],4,8,100,[XenoFlags.summoning])
  ;
  final List<XenomancySchool> schools;
  final String spellName,shortName;
  final int level, matterCost, timeout;
  final List<XenoFlags> flags;
  const XenomancySpell(this.spellName,this.shortName,this.schools,this.level,this.matterCost, this.timeout,this.flags);
}