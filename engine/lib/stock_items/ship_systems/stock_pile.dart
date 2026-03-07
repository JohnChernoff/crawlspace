import 'dart:math';
import 'package:crawlspace_engine/stock_items/corps.dart';

import '../../item.dart';
import '../../rng/rng.dart';
import '../../ship/systems/engines.dart';
import '../../ship/systems/power.dart';
import '../../ship/systems/shields.dart';
import '../../ship/systems/ship_system.dart';
import '../../ship/systems/weapons.dart';

const maxTechLvl = 10;
enum StockSystem {
  engBasicFedImp(ShipSystemType.engine,1,.9),
  engBasicFedSub(ShipSystemType.engine,1,.9),
  engBasicFedHyper(ShipSystemType.engine,1,.9),
  engMovSub1(ShipSystemType.engine,3,.75, manufacturer: Corporation.rimbaud),
  engVorImp1(ShipSystemType.engine,5,.5, manufacturer: Corporation.nimrod),

  genBasicNuclear(ShipSystemType.power,1,.9),
  genZemlinsky(ShipSystemType.power,2,.75),
  genAojginx(ShipSystemType.power,4,.66, manufacturer: Corporation.smythe),
  genGjellorny(ShipSystemType.power,5,.5, manufacturer: Corporation.rimbaud),
  genBellauxfz(ShipSystemType.power,7,.25),

  shdBasicEnergon(ShipSystemType.shield,1,.9),
  shdMovEnergon(ShipSystemType.shield,2,.8),
  shdCassat(ShipSystemType.shield,3,.5),
  shdRemlok(ShipSystemType.shield,5,.33),
  shdOrtegroq(ShipSystemType.shield,7,.25),
  shdKevlop(ShipSystemType.shield,8,.1),

  wepFedLaser1(ShipSystemType.weapon,1,.9),
  wepFedLaser2(ShipSystemType.weapon,2,.9),
  wepFedLaser3(ShipSystemType.weapon,3,.9),
  wepPlasmaRay(ShipSystemType.weapon,4,.75),
  wepGravRifle(ShipSystemType.weapon,5,.66, manufacturer: Corporation.bauchmann),
  wepVibraSlap(ShipSystemType.weapon,6,.5, manufacturer: Corporation.sinclair),
  wepNeuRad(ShipSystemType.weapon,7,.25, manufacturer: Corporation.sinclair),
  wepThermalLance(ShipSystemType.weapon,8,.25, manufacturer: Corporation.sinclair),
  wepQuarkSplitter(ShipSystemType.weapon,5,.25, manufacturer: Corporation.salazar),
  wepGammapult(ShipSystemType.weapon,8,.25, manufacturer: Corporation.salazar),
  wepCosmogripher(ShipSystemType.weapon,9,.25, manufacturer: Corporation.sinclair),
  webSingularitron(ShipSystemType.weapon,99,.01, manufacturer: Corporation.sinclair),

  lchfedTorpLauncher(ShipSystemType.launcher,1,.9, manufacturer: Corporation.bauchmann),
  lchPlasmaCannon(ShipSystemType.launcher,2,.9, manufacturer: Corporation.bauchmann),

  ammoFedTorp(ShipSystemType.ammo,1,.9),
  ammoPlasmaBall(ShipSystemType.ammo,2,.9),
  ;

  final ShipSystemType type;
  final int techLvl;
  final double rarity;
  final Corporation manufacturer;
  const StockSystem(this.type,this.techLvl, this.rarity, {this.manufacturer = Corporation.genCorp});

  Item createSystem() => switch(type) {
      ShipSystemType.power => PowerGenerator.fromStock(this),
      ShipSystemType.engine => Engine.fromStock(this),
      ShipSystemType.shield => Shield.fromStock(this),
      ShipSystemType.weapon => Weapon.fromStock(this),
      ShipSystemType.launcher => Weapon.fromStock(this),
      ShipSystemType.ammo => Ammo.fromStock(this),
  // TODO: Handle this case.
    ShipSystemType.quarters => throw UnimplementedError(),
  // TODO: Handle this case.
    ShipSystemType.converter => throw UnimplementedError(),
  // TODO: Handle this case.
    ShipSystemType.sensor => throw UnimplementedError(),
  // TODO: Handle this case.
    ShipSystemType.unknown => throw UnimplementedError(),
  // TODO: Handle this case.
    ShipSystemType.emitter => throw UnimplementedError(),
  // TODO: Handle this case.
    ShipSystemType.scrapper => throw UnimplementedError(),
  // TODO: Handle this case.
    ShipSystemType.adapter => throw UnimplementedError(),
  };
}

List<StockSystem> generateSystemInventory(
    int n, List<ShipSystemType> types, int techLvl, Random rnd,
    {Map<Corporation, double>? corpWeights, bool militaryAvailable = false}) {

  final candidates = getSystemsByTech(types, techLvl,
      availableCorps: corpWeights?.keys.toList(),
      militaryAvailable: militaryAvailable).toList();

  if (candidates.isEmpty) return techLvl > 0
      ? generateSystemInventory(n, types, techLvl - 1, rnd,
      corpWeights: corpWeights, militaryAvailable: militaryAvailable)
      : [];

  final weights = {
    for (final s in candidates)
      s: (corpWeights?[s.manufacturer] ?? 1.0) * s.rarity
  };

  final maxItems = min(n, candidates.length);
  final Set<StockSystem> chosen = {};
  while (chosen.length < maxItems) {
    chosen.add(Rng.weightedRandom(weights, rnd));
  }
  return chosen.toList();
}

Iterable<StockSystem> getSystemsByTech(
    List<ShipSystemType> types, int techLvl,
    {List<Corporation>? availableCorps, bool militaryAvailable = false}) =>
    StockSystem.values.where((s) =>
    types.contains(s.type) &&
        s.techLvl <= techLvl &&
        (availableCorps == null || availableCorps.contains(s.manufacturer)) &&
        (militaryAvailable || s.manufacturer.tierFor(s.type) != CorpTier.military)
    );
