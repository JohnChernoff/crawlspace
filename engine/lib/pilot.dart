import 'dart:math';
import 'package:crawlspace_engine/coord_3d.dart';
import 'package:crawlspace_engine/player.dart';
import 'package:crawlspace_engine/rng.dart';
import 'package:crawlspace_engine/sector.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'controllers/pilot_controller.dart';
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

enum TransactionType {  shopBuy,shopSell,repair,fooshamWin,fooshamLose,rollback }

class TransactionRecord {
  final TransactionType type;
  final int credits;
  const TransactionRecord(this.type,this.credits);
}

System nowhere = System("nowhere",StellarClass.A,Random());
Pilot nobody = Pilot("nobody",Random(),loc: SpaceEnvironment("nowhere", 0, 0, locale: SystemLocation(nowhere,SectorCell(Coord3D(0,0,0),{},0))));

class Pilot implements Locatable {
  String name;
  SpaceLocation get loc => locale.loc;
  Locatable get locale => _locale; //could be Planet, Ship, SpaceEnvironment, etc.
  void set locale(Locatable l) {
    _locale = l; //print("Setting locale: ${l.name}");
    if (l is Ship && this != nobody) {
      l.pilot = this;
    }
  }
  late Locatable _locale;
  System get system => locale.loc.system;
  int credits = 10000;
  List<TransactionRecord> transRec = [];
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

  Pilot(this.name,Random rnd,{required Locatable loc, Galaxy? galaxy, Faction? f, this.hp = 32, this.hostile = true}) {
    locale = loc;
    if (this is Player) { //FactionList.values.forEach((f) => print(f.factionName)); print(FactionList.values);
      faction = getFaction(FactionList.fedReb)!;
    } else {
      final species = galaxy != null
          ? Rng.weightedRandom(galaxy.civMod.civIntensity[locale.loc.system]!,rnd, fallback: StockSpecies.humanoid.species)
          : StockSpecies.humanoid.species;  //print("Species: ${species.name}");
      final factionMap = Map.fromEntries(factions.where((fa) => fa.species == species).map((f2) => MapEntry(f2, f2.relativeFreq)));
      faction = f ?? Rng.weightedRandom(factionMap, rnd, fallback: factions.first);
    }
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