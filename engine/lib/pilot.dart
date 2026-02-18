import 'dart:math';
import 'package:crawlspace_engine/rng.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'controllers/pilot_controller.dart';
import 'hazards.dart';
import 'object.dart';
import 'system.dart';

enum AttribType {
  int,wis,str,dex,cha,con
}

enum SkillType {
  engineering,piloting,medicine,communications,combat
}

enum TransactionType {  shopBuy,shopSell,repair,fooshamWin,fooshamLose,rollback }

class TransactionRecord {
  final TransactionType type;
  final int credits;
  const TransactionRecord(this.type,this.credits);
}

Pilot nobody = Pilot("nobody",System("nowhere",StellarClass.A,0,0,[],Random()),Random());

class Pilot {
  String name;
  SpaceObject? location; //null = on ship in space
  int credits = 10000;
  List<TransactionRecord> transRec = [];
  System system;
  late Faction faction;
  Map<AttribType,int> attributes = {};
  Map<SkillType,int> skills = {};
  int hp;
  int auCooldown = 0;
  ActionType? lastAct;
  bool hostile;
  bool safeMovement = true;
  Set<Hazard> safeList = { Hazard.nebula, Hazard.wake };

  bool get ready => auCooldown == 0;
  void tick() => auCooldown = max(0,auCooldown - 1);

  Pilot(this.name,this.system,Random rnd,{this.location, Faction? f, this.hp = 32, this.hostile = true}) {
    final species = Rng.weightedRandom(system.population ?? {StockSpecies.humanoid.species : 1},rnd);
    final factionMap = Map.fromEntries(factions.where((fa) => fa.species == species).map((f2) => MapEntry(f2, f2.relativeFreq)));
    faction = f ?? Rng.weightedRandom(factionMap, rnd);
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