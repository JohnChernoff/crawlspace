import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/rng/rng.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/ship_sys.dart';
import 'package:crawlspace_engine/ship/systems/xeno_can.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_ammo.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_engines.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_lauchers.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_pile.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_power.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_shields.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_weapons.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import 'package:crawlspace_engine/ship/systems/power.dart';
import 'package:crawlspace_engine/ship/systems/shields.dart';
import 'package:crawlspace_engine/ship/systems/ship_system.dart';
import 'package:crawlspace_engine/ship/systems/weapons.dart';
import '../fugue_engine.dart';
import '../galaxy/geometry/grid.dart';
import '../stock_items/corps.dart';
import '../stock_items/ship/stock_ships.dart';

class RndSystemInstaller {

  final ShipSystemControl sysCtl;
  final Ship ship;
  const RndSystemInstaller(this.ship,this.sysCtl);

  InstallReport? installRndSystemSlot(SystemSlot slot, int i, ShipClassType shipClassType, int techLvl, Random rnd, {increaseTech = true}) {
    glog("Installing: ${slot.systemType.name} , ${slot.manufacturer}, $i",level: DebugLevel.Finer);
    Iterable<StockSystem> sysList = [];
    for (int compLevel = 4; compLevel > 0 && sysList.isEmpty; compLevel--) {
      sysList = StockSystem.values.where((s) => s.type == slot.systemType && slot.manufacturer.getRelations(s.manufacturer).level >= compLevel)
          .sorted((a,b) => (a.techLvl - techLvl).abs().compareTo((b.techLvl - techLvl).abs()));
      if (slot.systemType == ShipSystemType.engine) {
        sysList = sysList.where((s) => ship.systemControl.getEngine(stockEngines[s]!.domain) == null);
      }
    }
    if (sysList.isNotEmpty) {
      final system = (sysList.firstWhere((_) => rnd.nextBool(), orElse: () => sysList.first)).createSystem();
      glog("Installing System: $system",level: DebugLevel.Fine);
      if (system != null) {
        final report = ship.systemControl.installSystem(system);
        glog(report.result.name, level: DebugLevel.Fine);
        return report;
      }
    }
    return (techLvl < 10 && increaseTech) ? installRndSystemSlot(slot, i, shipClassType, techLvl + 1, rnd) : null;
  }

  List<InstallReport?> installRndSystemSlots(ShipClassSlot slot, ShipClassType shipClassType, int techLvl, Random rnd) {
    final corp = shipClassType.corpMap[slot.type] ?? Corporation.genCorp;
    List<InstallReport?> results = [];
    glog("Installing ${slot.type}, slots: ${slot.num}", level: DebugLevel.Fine);
    for (int i=0; i<slot.num; i++) {
      final r = installRndSystemSlot(SystemSlot(slot.type,corp), i, shipClassType, techLvl, rnd);
      final s =  r?.assignment?.system?.name;
      results.add(r);
      if (r?.result != InstallResult.success) {
        glog("Error installing ${slot.type}, ${corp.name}, $s: ${r?.result}", level: DebugLevel.Fine);
        if (slot.type != ShipSystemType.engine) break;
      }
      else glog("Installed System: $s", level: DebugLevel.Fine);
    }
    return results;
  }
}