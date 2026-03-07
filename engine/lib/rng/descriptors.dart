import 'dart:math';

import '../galaxy/planet.dart';

Random _rndDescriptor = Random();

enum PlanetAge {
  newlyColonized(),
  modern(),
  established(),
  longStanding(hyphenated: true),
  old(),
  antiquated(),
  ancient();
  final bool hyphenated;
  const PlanetAge({this.hyphenated = false});
  @override
  String toString() => enumToString(this,hyphenate: true);
}

enum WordType { noun, adj }
enum EnvType {
  icy(DistrictLvl.light,DistrictLvl.medium,DistrictLvl.heavy),
  snowy(DistrictLvl.medium,DistrictLvl.heavy,DistrictLvl.heavy),
  desert(DistrictLvl.heavy,DistrictLvl.heavy,DistrictLvl.heavy),
  rocky(DistrictLvl.medium,DistrictLvl.medium,DistrictLvl.heavy),
  mountainous (DistrictLvl.light,DistrictLvl.light,DistrictLvl.heavy),
  oceanic(DistrictLvl.medium,DistrictLvl.medium,DistrictLvl.medium),
  volcanic(DistrictLvl.none,DistrictLvl.none,DistrictLvl.medium),
  toxic(DistrictLvl.none,DistrictLvl.none,DistrictLvl.medium),
  jungle(DistrictLvl.light,DistrictLvl.light,DistrictLvl.light),
  arboreal(DistrictLvl.medium,DistrictLvl.light,DistrictLvl.light),
  earthlike(DistrictLvl.heavy,DistrictLvl.heavy,DistrictLvl.heavy),
  paradisiacal(DistrictLvl.medium,DistrictLvl.heavy,DistrictLvl.light),
  alluvial(DistrictLvl.heavy,DistrictLvl.heavy,DistrictLvl.heavy),
  arid(DistrictLvl.heavy,DistrictLvl.heavy,DistrictLvl.heavy);
  final DistrictLvl maxResLvl,maxCommLvl,maxDustLvl;
  const EnvType(this.maxResLvl,this.maxCommLvl,this.maxDustLvl);
  @override
  String toString() => enumToString(this,hyphenate: false);
}

enum PlanetDescriptor {
  rebel(0,9,0,77,[],[],[],WordType.adj),
  rogue(0,16,0,55,[],[],[],WordType.adj),
  pirateControlled(0,25,33,67,[DistrictLvl.none,DistrictLvl.light],
      [DistrictLvl.none,DistrictLvl.light],[DistrictLvl.light,DistrictLvl.medium],WordType.adj),
  forgotten(0,25,0,33,[DistrictLvl.none,DistrictLvl.medium],[DistrictLvl.none,DistrictLvl.medium],[],WordType.adj),
  lawless(0,25,0,33,[DistrictLvl.none,DistrictLvl.light],[],[],WordType.adj),
  obscure(0,25,0,50,[],[],[],WordType.adj),
  anarchic(0,25,0,36,[DistrictLvl.none,DistrictLvl.light],[],[],WordType.adj),
  independent(0,25,0,80,[],[],[],WordType.adj),  //unregistered(25,0,100,[],[],[]),
  multiFactional(0,25,0,100,[],[],[],WordType.adj),
  mysterious(0,50,0,100,[],[],[],WordType.adj),
  feudal(0,33,0,50,[],[],[],WordType.adj),
  communistic(0,33,0,80,[],[DistrictLvl.none,DistrictLvl.medium],[],WordType.adj),
  theocratic(0,69,0,55,[],[DistrictLvl.none,DistrictLvl.medium],[],WordType.adj),
  corporate(50,100,50,99,[],[DistrictLvl.heavy],[DistrictLvl.none,DistrictLvl.medium],WordType.adj),
  mediaCentric(50,100,33,99,[],[DistrictLvl.heavy],[DistrictLvl.none,DistrictLvl.light],WordType.adj),
  abandoned(0,100,0,33,
      [DistrictLvl.none],[DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.medium],WordType.adj),
  prison(75,100,0,100,[DistrictLvl.heavy],[DistrictLvl.none],[],WordType.adj),
  polluted(33,100,0,80,[],[],[DistrictLvl.heavy],WordType.adj),
  austere(33,100,0,80,[DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.light],[],WordType.adj),
  gritty(33,100,33,66,[],[DistrictLvl.light,DistrictLvl.medium],[DistrictLvl.medium,DistrictLvl.heavy],WordType.adj),
  bustling(25,90,50,100,[DistrictLvl.heavy],[DistrictLvl.medium,DistrictLvl.heavy],[],WordType.adj),
  multiCultural(33,77,25,99,[DistrictLvl.light,DistrictLvl.heavy],[],[],WordType.adj),
  warTorn(0,75,0,75,[DistrictLvl.none,DistrictLvl.medium],[DistrictLvl.none,DistrictLvl.medium],[],WordType.adj),
  peaceful(0,100,0,100,[],[],[],WordType.adj),
  nondescript(0,100,0,100,[],[],[],WordType.adj),
  glittering(0,100,50,100,[],[DistrictLvl.medium,DistrictLvl.heavy],[],WordType.adj),
  overCrowded(0,100,0,100,[DistrictLvl.heavy],[],[],WordType.adj),
  colony(0,100,0,33,[DistrictLvl.none,DistrictLvl.light],
      [DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.light],WordType.noun),
  outpost(0,100,10,60,[DistrictLvl.none,DistrictLvl.light],
      [DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.medium],WordType.noun),
  enclave(0,50,20,70,[DistrictLvl.none,DistrictLvl.light],
      [DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.light],WordType.noun),
  backwater(0,80,0,33,[DistrictLvl.none,DistrictLvl.light],
      [DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.light],WordType.noun),
  hamlet(0,100,0,70,
      [DistrictLvl.light],[DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.light],WordType.noun),
  settlement(0,100,0,50,
      [DistrictLvl.light],[DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.light],WordType.noun),
  gardenWorld(0,100,33,100,
      [DistrictLvl.medium,DistrictLvl.heavy],[DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none],WordType.noun),
  pleasureWorld(8,92,40,100,
      [DistrictLvl.light,DistrictLvl.medium],[DistrictLvl.heavy],[DistrictLvl.none,DistrictLvl.light],WordType.noun),
  refinery(0,100,50,100,
      [],[DistrictLvl.none,DistrictLvl.medium],[DistrictLvl.heavy],WordType.noun),
  supplyDepot(33,100,33,100,
      [],[DistrictLvl.none,DistrictLvl.medium],[DistrictLvl.heavy],WordType.noun),
  habitation(0,100,0,100,
      [],[DistrictLvl.none,DistrictLvl.light],[],WordType.noun),
  homestead(0,100,0,100,
      [],[DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.light],WordType.noun),
  commonwealth(0,100,0,100,
      [],[],[],WordType.noun),
  thoroughfare(0,100,0,100,
      [],[DistrictLvl.medium],[],WordType.noun),
  tradingCenter(0,100,0,100,
      [],[DistrictLvl.heavy],[],WordType.noun),
  megopolis(0,100,50,100,
      [DistrictLvl.medium,DistrictLvl.heavy],[DistrictLvl.heavy],[],WordType.noun),
  hub(20,100,20,100,
      [],[DistrictLvl.heavy],[],WordType.noun),
  researchCenter(20,80,67,100,
      [DistrictLvl.light,DistrictLvl.medium],[DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none],WordType.noun),
  arcology(25,80,70,100,
      [DistrictLvl.heavy],[DistrictLvl.light,DistrictLvl.medium],[DistrictLvl.none,DistrictLvl.light],WordType.noun),
  watchpost(70,100,20,80, [DistrictLvl.none,DistrictLvl.light],
      [DistrictLvl.none,DistrictLvl.light],[DistrictLvl.none,DistrictLvl.medium],WordType.noun),
  citadel(80,100,50,100,
      [],[],[DistrictLvl.medium,DistrictLvl.heavy],WordType.noun),
  bastion(80,100,50,100, [DistrictLvl.none,DistrictLvl.light],
      [DistrictLvl.none,DistrictLvl.light],[DistrictLvl.medium,DistrictLvl.heavy],WordType.noun),
  mecca(10,90,67,100,
      [DistrictLvl.light,DistrictLvl.heavy],[],[],WordType.noun),
  protectorate(70,100,50,100,
      [],[],[],WordType.noun),
  stronghold(80,100,33,100,
      [],[],[],WordType.noun),
  administrativeCenter(80,100,67,100,
      [],[DistrictLvl.heavy],[],WordType.noun),
  ;
  final WordType wordType;
  final int minInfluence,maxInfluence;
  final int minTech, maxTech;
  final List<DistrictLvl> resLvl,commLvl,dustLvl;
  const PlanetDescriptor(
      this.minInfluence,this.maxInfluence,this.minTech,this.maxTech,this.resLvl,this.commLvl,this.dustLvl, this.wordType);
  @override
  String toString() => enumToString(this,hyphenate: wordType == WordType.adj);
}

enum Goods { //TODO: initially exclude generics when picking randomly?
  rawMaterials(0,[],[]),
  soylentPuce(0,[],[]),
  appendageSanitizers(0,[],[]),
  astrophones(0,[],[]),
  flexodorants(0,[],[]),
  galactapads(0,[],[]),
  cosmozines(0,[],[]),
  exoticFruit(5,[EnvType.alluvial,EnvType.jungle,EnvType.paradisiacal],[DistrictLvl.light,DistrictLvl.medium]),
  hydrogel(30,[EnvType.desert,EnvType.arid],[DistrictLvl.none,DistrictLvl.light]),
  plasmaBatteries(60,[EnvType.volcanic,EnvType.rocky],[DistrictLvl.medium,DistrictLvl.heavy]),
  rareMinerals(40,[EnvType.mountainous,EnvType.rocky],[DistrictLvl.medium,DistrictLvl.heavy]),
  nanoweave(70,[EnvType.earthlike,EnvType.paradisiacal],[DistrictLvl.none,DistrictLvl.medium]),
  synthSpice(25,[EnvType.jungle,EnvType.arboreal],[DistrictLvl.light,DistrictLvl.medium]),
  cyberorganics(80,[EnvType.toxic,EnvType.volcanic],[DistrictLvl.none,DistrictLvl.light]),
  neurogel(90,[EnvType.earthlike,EnvType.arboreal],[DistrictLvl.none,DistrictLvl.light]),
  starCharts(10,[EnvType.oceanic,EnvType.icy],[DistrictLvl.none,DistrictLvl.medium]),
  mechParts(50,[EnvType.rocky,EnvType.desert],[DistrictLvl.medium,DistrictLvl.heavy]),
  medicalSerum(60,[EnvType.paradisiacal,EnvType.earthlike],[DistrictLvl.light,DistrictLvl.medium]),
  quantumCrystals(75,[EnvType.toxic,EnvType.volcanic],[DistrictLvl.medium,DistrictLvl.heavy]),
  nanoConductors(80,[],[DistrictLvl.medium,DistrictLvl.heavy]),
  bioLuxuries(35,[EnvType.jungle,EnvType.arboreal],[DistrictLvl.light,DistrictLvl.medium]),
  archaicRelics(20,[EnvType.mountainous,EnvType.desert],[DistrictLvl.none,DistrictLvl.medium]),
  driftwoodStatues(5,[EnvType.oceanic,EnvType.arboreal],[DistrictLvl.light,DistrictLvl.medium]),
  holovids(10,[EnvType.earthlike,EnvType.paradisiacal],[DistrictLvl.none,DistrictLvl.medium]);
  final List<EnvType> envList;
  final int minTech;
  final List<DistrictLvl> dustLvl;
  const Goods(this.minTech,this.envList,this.dustLvl);
  @override
  String toString() => enumToString(this,hyphenate: false);
}

String enumToString(Enum e, {required bool hyphenate}) {
  final separator = hyphenate ? '-' : ' ';
  return e.name.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)}$separator${match.group(2)!.toLowerCase()}',
  );
}

String article(String subject) {
  return subject.startsWith(RegExp("[aeiou]")) ? "an $subject" : "a $subject";
}

T rndEnum<T extends Enum>(Iterable<T> values) {
  return values.elementAt(_rndDescriptor.nextInt(values.length));
}
