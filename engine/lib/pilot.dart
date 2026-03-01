import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/coord_3d.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/player.dart';
import 'package:crawlspace_engine/rng/rng.dart';
import 'package:crawlspace_engine/sector.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'agent.dart';
import 'controllers/pilot_controller.dart';
import 'galaxy/civ_model.dart';
import 'galaxy/galaxy.dart';
import 'hazards.dart';
import 'location.dart';
import 'object.dart';
import 'galaxy/system.dart';

enum AttribType {
  int,wis,str,dex,cha,con
}

enum SkillType {
  engineering,piloting,medicine,communications,combat
}

enum TransactionType {  shopBuy,shopSell,repair,fooshamWin,fooshamLose,drink,jail,robbed,bribe,rollback }

class TransactionRecord {
  final TransactionType type;
  final int credits;
  const TransactionRecord(this.type,this.credits);
}

final nowhere = AtEnvironment.fromSystem(SystemLocation(System("nowhere",StellarClass.A,Random()),SectorCell(Coord3D(0,0,0),{},0)));
final Pilot nobody = Pilot("nobody",loc:nowhere);

class Pilot implements Locatable {
  String name;
  SpaceLocation get loc => locale.loc;
  PilotLocale get locale => _locale;
  void set locale(PilotLocale l) { //print("Setting locale: ${l.name}");
    _locale = l;
    if (l is AboardShip && this != nobody) {
      l.ship.pilot = this;
    }
  }
  late PilotLocale _locale;
  System get system => locale.loc.system;
  int credits = 10000;
  List<TransactionRecord> transRec = [];
  late Faction faction;
  Map<AttribType,double> attributes = {};
  Map<SkillType,double> skills = {};
  int hp;
  int auCooldown = 0;
  ActionType? lastAct;
  bool safeMovement = true;
  Set<Hazard> safeList = { Hazard.nebula, Hazard.wake };
  Map<Species, double> reputation = {}; // -1 hostile to 1.0 friendly
  bool get ready => auCooldown == 0;
  bool? _hostile;
  bool get hostile => _hostile ?? false;

  void tick(FugueEngine fm) => auCooldown = max(0,auCooldown - 1);

  Pilot(this.name,{Random? rnd, required PilotLocale loc, Galaxy? galaxy, Faction? f, this.hp = 32, isPirate = false}) {
    locale = loc;
    if (this is Player) { //FactionList.values.forEach((f) => print(f.factionName)); print(FactionList.values);
      faction = getFaction(FactionList.fedReb)!;
    } else if (this is Agent) {
      faction = getFaction(FactionList.fed)!;
    } else {
      final pilotRnd = rnd ?? Random();
      final species = galaxy != null
          ? Rng.weightedRandom(galaxy.civMod.civIntensity[locale.loc.system]!,pilotRnd, fallback: StockSpecies.humanoid.species)
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
            _hostile = (fm.aiRng.nextDouble() < (h * .75)); //TODO: tie into game difficulty?
          }
        }
        print("Setting hostility: ${faction.name} -> player = ${_hostile}, pirate: ${faction.isPirate}");
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

}