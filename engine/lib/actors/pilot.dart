import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/actors/player.dart';
import 'package:crawlspace_engine/rng/rng.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:crawlspace_engine/stock_items/xenomancy.dart';
import 'agent.dart';
import '../color.dart';
import '../controllers/pilot_controller.dart';
import '../galaxy/models/civ_model.dart';
import '../galaxy/galaxy.dart';
import '../galaxy/hazards.dart';
import '../galaxy/geometry/location.dart';
import '../menu.dart';
import '../galaxy/system.dart';

enum AttribType {
  int("clever","stupid"),
  wis("wiser","ignorant"),
  str("stronger","weaker"),
  dex("nibler","clumsier"),
  con("hardier","frail"),
  cha("more persuasive","less persuasive"),
  ;
  final String enhanceStr, devolveStr;
  const AttribType(this.enhanceStr,this.devolveStr);
}

enum SkillType {
  engineering,piloting,xeno,communications,combat
}

enum TransactionType {  shopBuy,shopSell,repair,fooshamWin,fooshamPlay,drink,jail,robbed,bribe,rollback }

class TransactionRecord {
  final TransactionType type;
  final int credits;
  const TransactionRecord(this.type,this.credits);
}

class Pilot {
  String name;
  SpaceLocation get loc => locale.loc;
  PilotLocale get locale => _locale;
  void set locale(PilotLocale l) { //print("Setting locale: ${l.name}");
    _locale = l;
  }
  PilotLocale _locale;
  System get system => locale.loc.system;
  AtEnvironment? get _env => locale is AtEnvironment ? locale as AtEnvironment : null;
  double get tech => _env?.env.techLvl ?? .5;
  double get fed => _env?.env.fedLvl ?? .5;
  int credits = 10000;
  List<TransactionRecord> transRec = [];
  late Faction faction;
  Map<AttribType,double> attributes = {};
  Map<SkillType,double> skills = {};
  int hp;
  int auCooldown = 0;
  int ticksSinceLastAction = 0;
  ActionType? lastAct;
  bool safeMovement = true;
  Set<Hazard> safeList = { Hazard.nebula, Hazard.wake };
  Map<Species, double> reputation = {}; // -1 hostile to 1.0 friendly
  bool get ready => auCooldown == 0;
  bool? _hostile;
  bool get hostile => _hostile ?? false;
  final Map<XenomancySchool,double> _xenoSkills = {};
  void setXeno(XenomancySchool school, double x) => _xenoSkills[school] = x.clamp(0,1);
  double xenoSkill(XenomancySchool school) => _xenoSkills[school] ?? 0;
  final List<XenomancySpell> spellBook = [XenomancySpell.foldSpace];
  final Map<String,XenomancySpell> knownSpells = {};
  SpaceLocation? targetLoc;

  void tick(FugueEngine fm) {
    auCooldown = max(0,auCooldown - 1);
    ticksSinceLastAction++;
  }

  void wake() {
    auCooldown = 0;
  }

  void newTurn() {
    print("au: $ticksSinceLastAction");
    ticksSinceLastAction = 0;
  }


  Pilot(this.name,this._locale,{Random? rnd, Galaxy? galaxy, Faction? f, this.hp = 32, isPirate = false}) {
    //locale = AtEnvironment.fromSystem(sector);
    if (this is Player) { //FactionList.values.forEach((f) => print(f.factionName)); print(FactionList.values);
      faction = getFaction(FactionList.fedReb)!;
    } else if (this is Agent) {
      faction = getFaction(FactionList.fed)!;
    } else {
      final pilotRnd = rnd ?? Random();
      final species = galaxy != null
          ? Rng.weightedRandom(galaxy.civMod.civIntensity[system]!,pilotRnd, fallback: StockSpecies.humanoid.species)
          : StockSpecies.humanoid.species;  //print("Species: ${species.name}");
      if (isPirate) {
        faction = factions.firstWhereOrNull((f) => f.species == species && f.isPirate) ?? factions.firstWhere((t) => t.isPirate);
      } else {
        final factionMap = Map.fromEntries(factions.where((fa) => fa.species == species).map((f2) => MapEntry(f2, f2.strength)));
        faction = f ?? Rng.weightedRandom(factionMap, pilotRnd, fallback: factions.first);
      }
    }
    for (final a in AttribType.values) attributes[a] = .5;
    for (final skill in SkillType.values) skills[skill] = .25;
  }

  bool setHostilityToPlayer(FugueEngine fm, {bool? hostility, reset = false}) {
    if (_hostile == null || reset) {
      if (hostility != null) {
        _hostile = hostility;
      } else {
        if (faction.isPirate) _hostile = true;
        else {
          final h = hostilityToward(fm.player.faction.species, fm.galaxy.civMod);
          if (h < .75) _hostile = false;
          else {
            _hostile = (fm.aiRnd.nextDouble() < (h * .75)); //TODO: tie into game difficulty?
          }
        }
        glog("Setting hostility: ${faction.name} -> player = ${_hostile}, pirate: ${faction.isPirate}",level: DebugLevel.Fine);
      }
    }
    return _hostile!;
  }

  double hostilityToward(Species s, CivModel civ) {
    final baseline = (civ.factionAttitudes[faction]?[s] ?? 0.5); //higher = more hostile?
    print("${faction.name} -> ${s.name}, baseline: $baseline");
    final rep = reputation[s] ?? 0.0;
    return (baseline - rep).clamp(0, 1);
  }

  bool transaction(TransactionType type, int c) {
    bool ok = c > 0 || ((credits + c) > 0); //print("Whee: $c");
    if (ok) {
      credits += c;
      transRec.add(TransactionRecord(type,c));
    }
    return ok;
  }

  bool rollBack() {
    return (transRec.isNotEmpty && transaction(TransactionType.rollback,-transRec.last.credits));
  }

  TextEntry get creditLine => TextEntry(txtBlocks: [TextBlock("Credits: ${credits}", GameColors.green, true)]);

}