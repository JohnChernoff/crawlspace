import 'dart:math';
import 'package:crawlspace_engine/coord_3d.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/player.dart';
import 'package:crawlspace_engine/rng.dart';
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

enum TransactionType {  shopBuy,shopSell,repair,fooshamWin,fooshamLose,jail,rollback }

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
  bool hostile;
  bool safeMovement = true;
  Set<Hazard> safeList = { Hazard.nebula, Hazard.wake };
  Map<Species, double> reputation = {}; // -1.0 hostile to 1.0 friendly
  bool get ready => auCooldown == 0;
  void tick(FugueEngine fm) => auCooldown = max(0,auCooldown - 1);

  Pilot(this.name,{Random? rnd, required PilotLocale loc, Galaxy? galaxy, Faction? f, this.hp = 32, this.hostile = true}) {
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
      final factionMap = Map.fromEntries(factions.where((fa) => fa.species == species).map((f2) => MapEntry(f2, f2.relativeFreq)));
      faction = f ?? Rng.weightedRandom(factionMap, pilotRnd, fallback: factions.first);
    }
    for (final a in AttribType.values) attributes[a] = .5;
    for (final skill in SkillType.values) skills[skill] = .25;
  }

  double hostilityToward(Species s, CivModel civ) {
    final baseline = civ.politicalMap[faction.species]?[s] ?? 0.5;
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