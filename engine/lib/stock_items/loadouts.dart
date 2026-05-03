import 'dart:math';
import 'package:crawlspace_engine/stock_items/ship/stock_pile.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_ships.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import '../ship/systems/ship_system.dart';

// ── Slot/Corp reference ───────────────────────────────────────────────────────
//
//  ShipClassType → slot corp per system type (genCorp when not listed):
//
//  mentok    engine=rimbaud   shield=smythe    sensor=smythe
//  ariel     engine=tanaka    shield=gregoriev  sensor=smythe
//  falcon    ALL=genCorp      (empty corpMap)
//  hermes    engine=smythe    shield=smythe     weapon=smythe   launcher=bauchmann
//  orion     engine=rimbaud   power=lopez       shield=bauchmann  weapon=bauchmann  launcher=bauchmann
//  marduk    engine=rimbaud   power=salazar     shield=bauchmann  weapon=salazar    launcher=bauchmann
//  balrog    engine=rimbaud   power=sinclair    shield=sinclair   weapon=sinclair   launcher=bauchmann
//  leviathan engine=rimbaud   power=sinclair    shield=gregoriev  weapon=bauchmann  launcher=bauchmann
//  raptor    engine=tanaka    power=rimbaud     shield=gregoriev  weapon=nimrod     launcher=nimrod
//  hellfire  engine=nimrod    power=salazar     shield=smythe     weapon=salazar    launcher=bauchmann
//  apocalypse engine=rimbaud  power=salazar     shield=bauchmann  weapon=salazar    launcher=salazar
//  dart      engine=tanaka    power=rimbaud     sensor=smythe
//
//  BrandSupport relations (slot_corp.getRelations(system_mfr)):
//    native         → same corp          ✓ perfect
//    trustedPartner → licensed/collab    ✓ fine
//    compatible     → industry standard  ✓ fine
//    thirdParty     → works but degraded ~ acceptable
//    needsAdapter   → requires adapter   ✗ avoid
//
//  Key brand relations from corps.dart:
//    genCorp is thirdParty to rimbaud, bauchmann, salazar, nimrod, smythe, sinclair
//    smythe  is compatible with genCorp/nimrod, trustedPartner with bauchmann
//    sinclair is compatible with smythe, trustedPartner with bauchmann
//    nimrod  is compatible with rimbaud, thirdParty with genCorp
//    rimbaud is thirdParty with genCorp
//    bauchmann is thirdParty with genCorp
//    salazar is thirdParty with genCorp
//    laventar has NO relations → needsAdapter everywhere except native laventar slots
//    gregoriev has NO relations → needsAdapter everywhere except native gregoriev slots
//    tanaka  has NO relations → needsAdapter everywhere except native tanaka slots
//    montak  has NO relations → needsAdapter everywhere except native montak slots
//
//  StockSystem manufacturers:
//    engBasicFedImp/Sub/Hyper → genCorp    (thirdParty in most slots: ~ ok)
//    engMovSub1               → rimbaud    (native in mentok/orion/marduk/balrog/leviathan/apocalypse engine slots)
//    engVorImp1               → nimrod     (compatible with rimbaud slots; thirdParty with genCorp slots)
//    engOrbBlock              → genCorp    (thirdParty in most slots: ~ ok)
//    genBasicNuclear          → genCorp
//    genZemlinsky             → genCorp
//    genAojginx               → smythe
//    genGjellorny             → rimbaud
//    genBellauxfz             → genCorp
//    shdBasicEnergon/MovEnergon/Cassat/Remlok/Ortegroq/Kevlop → genCorp
//    wepFedLaser*/PlasmaRay   → genCorp
//    wepGravRifle             → bauchmann  (native in orion/marduk/leviathan weapon slots)
//    wepVibraSlap/NeuRad/ThermalLance/Cosmogripher/Singularitron → sinclair
//    wepQuarkSplitter/Gammapult → salazar
//    lchfedTorpLauncher/lchPlasmaCannon → bauchmann (native in most launcher slots)
//    senFed1                  → genCorp
//    senLael1                 → laventar   (needsAdapter everywhere — use only where noted)
//
//  Sinclair weapons (sinclair) in non-sinclair/smythe/bauchmann weapon slots:
//    sinclair→bauchmann = trustedPartner ✓
//    sinclair→smythe    = compatible ✓  (smythe→sinclair is compatible, and getRelations is on slot)
//    sinclair in salazar slot = needsAdapter ✗  → avoid on hellfire/apocalypse/marduk weapon slots
//    sinclair in nimrod slot  = needsAdapter ✗  → avoid on raptor weapon slots
//
//  engVorImp1 (nimrod) compatibility:
//    nimrod→rimbaud = compatible ✓  → ok on mentok/orion/marduk/balrog/leviathan/apocalypse
//    nimrod→tanaka  = needsAdapter ✗ → avoid on raptor/ariel/dart
//    nimrod→nimrod  = native ✓       → ok on hellfire engine slot
//    nimrod→smythe  = compatible ✓   → ok on hermes engine slot
//    nimrod→genCorp = thirdParty ~   → ok on falcon engine slot
//
//  engMovSub1 (rimbaud) compatibility:
//    rimbaud→rimbaud = native ✓      → perfect on mentok/orion/marduk/balrog/leviathan/apocalypse
//    rimbaud→smythe  = ? smythe has thirdParty←genCorp but no explicit rimbaud entry
//                      → rimbaud not in smythe._brandRelations → needsAdapter ✗ avoid on hermes
//    rimbaud→tanaka  = needsAdapter ✗ → avoid on raptor/ariel/dart
//    rimbaud→nimrod  = compatible ✓   → ok on hellfire/raptor... wait raptor=tanaka → ✗
//
//  senLael1 (laventar): laventar has zero brandRelations → needsAdapter in ALL non-laventar slots.
//    Since no ship class has laventar sensor slots, senLael1 always needs an adapter.
//    We include it only for Lael (their native corp) with the expectation they carry an adapter,
//    and drop it from all other species where it was just an upgrade pick.
//
// ─────────────────────────────────────────────────────────────────────────────

class ShipConfig {
  final ShipClassType shipClass;
  final List<StockSystem> systems;
  const ShipConfig(this.shipClass, [this.systems = const []]);
}

//TODO: ammo
class Loadout {
  final Map<ShipType, ShipConfig> shipMap;
  const Loadout(this.shipMap);

  ShipSystem? getSystem(ShipClassType shipType, ShipSystemType type, Random rnd) {
    final systems = shipMap[shipType]?.systems.where((s) => s.type == type);
    return systems != null
        ? systems.isNotEmpty
        ? systems.elementAt(rnd.nextInt(systems.length)).createSystem()
        : null
        : null;
  }

  factory Loadout.bySpecies(StockSpecies? species) => switch (species) {

  // ── Humanoid ─────────────────────────────────────────────────────────────
  // mentok engine=rimbaud → engMovSub1(rimbaud) native ✓, fed engines genCorp thirdParty ~
  // mentok shield=smythe  → all shields genCorp, smythe→genCorp=compatible ✓
  // mentok sensor=smythe  → senFed1(genCorp), smythe→genCorp=compatible ✓
  // hermes engine=smythe  → fed engines(genCorp), smythe→genCorp=compatible ✓
  // hermes weapon=smythe  → fed lasers(genCorp), smythe→genCorp=compatible ✓
  // hermes launcher=bauchmann → lchfedTorpLauncher(bauchmann) native ✓
  // orion  engine=rimbaud → fed engines thirdParty ~
  // orion  power=lopez    → genZemlinsky(genCorp), lopez→genCorp=thirdParty ~
  // orion  shield=bauchmann → shields(genCorp), bauchmann→genCorp=thirdParty ~
  // orion  weapon=bauchmann → wepFedLaser(genCorp) thirdParty ~
  // orion  launcher=bauchmann → bauchmann native ✓
  // marduk engine=rimbaud → fed engines thirdParty ~
  // marduk power=salazar  → genZemlinsky(genCorp), salazar→genCorp=thirdParty ~
  // marduk shield=bauchmann → genCorp thirdParty ~
  // marduk weapon=salazar → wepFedLaser/PlasmaRay(genCorp) thirdParty ~
  // marduk launcher=bauchmann → native ✓
  // balrog power=sinclair  → genZemlinsky(genCorp), sinclair→genCorp=thirdParty ~
  // balrog shield=sinclair → genCorp thirdParty ~
  // balrog weapon=sinclair → wepFedLaser3/PlasmaRay(genCorp) thirdParty ~
  //                          wepGravRifle(bauchmann), sinclair→bauchmann=trustedPartner ✓
  // balrog launcher=bauchmann → native ✓
    StockSpecies.humanoid => Loadout({
      ShipType.scout: ShipConfig(ShipClassType.mentok, [
        StockSystem.engBasicFedImp,     // genCorp ~ rimbaud slot (thirdParty)
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,    // genCorp ~ genCorp slot (native)
        StockSystem.shdBasicEnergon,    // genCorp ~ smythe slot (compatible)
        StockSystem.senFed1,            // genCorp ~ smythe slot (compatible)
      ]),
      ShipType.skiff: ShipConfig(ShipClassType.hermes, [
        StockSystem.engBasicFedImp,     // genCorp ~ smythe slot (compatible)
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,    // genCorp ~ genCorp slot (native)
        StockSystem.shdBasicEnergon,    // genCorp ~ smythe slot (compatible)
        StockSystem.wepFedLaser1,       // genCorp ~ smythe slot (compatible)
        StockSystem.lchfedTorpLauncher, // bauchmann ~ bauchmann slot (native) ✓
        StockSystem.senFed1,            // genCorp ~ genCorp slot (native)
      ]),
      ShipType.cruiser: ShipConfig(ShipClassType.orion, [
        StockSystem.engBasicFedImp,     // genCorp ~ rimbaud slot (thirdParty)
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,    // genCorp ~ lopez slot (thirdParty)
        StockSystem.genZemlinsky,       // genCorp ~ lopez slot (thirdParty)
        StockSystem.shdBasicEnergon,    // genCorp ~ bauchmann slot (thirdParty)
        StockSystem.wepFedLaser2,       // genCorp ~ bauchmann slot (thirdParty)
        StockSystem.lchfedTorpLauncher, // bauchmann native ✓
      ]),
      ShipType.destroyer: ShipConfig(ShipClassType.marduk, [
        StockSystem.engBasicFedImp,     // genCorp ~ rimbaud slot (thirdParty)
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,    // genCorp ~ salazar slot (thirdParty)
        StockSystem.genZemlinsky,
        StockSystem.shdBasicEnergon,    // genCorp ~ bauchmann slot (thirdParty)
        StockSystem.wepFedLaser2,       // genCorp ~ salazar slot (thirdParty)
        StockSystem.wepFedLaser3,
        StockSystem.lchfedTorpLauncher, // bauchmann native ✓
      ]),
      ShipType.battleship: ShipConfig(ShipClassType.balrog, [
        StockSystem.engBasicFedImp,     // genCorp ~ rimbaud slot (thirdParty)
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ sinclair slot (thirdParty)
        StockSystem.genAojginx,         // smythe ~ sinclair slot (compatible) ✓
        StockSystem.shdBasicEnergon,    // genCorp ~ sinclair slot (thirdParty)
        StockSystem.shdMovEnergon,
        StockSystem.wepFedLaser3,       // genCorp ~ sinclair slot (thirdParty)
        StockSystem.wepPlasmaRay,
        StockSystem.wepGravRifle,       // bauchmann ~ sinclair slot (trustedPartner) ✓
        StockSystem.lchfedTorpLauncher, // bauchmann native ✓
      ]),
    }),

  // ── Vorlon ───────────────────────────────────────────────────────────────
  // engVorImp1 (nimrod): nimrod→rimbaud=compatible ✓ on mentok/orion/marduk/leviathan
  //                      nimrod→tanaka=needsAdapter ✗ — use on mentok(rimbaud) not ariel(tanaka)
  // ariel engine=tanaka → engVorImp1(nimrod) needsAdapter ✗ → use engBasicFed instead
  //   but wait: ariel is our chosen scout for Vorlon. Switch to mentok to keep engVorImp1, OR
  //   use ariel and drop engVorImp1 from the engine pool. Ariel is thematically better (xeno=6).
  //   Resolution: keep ariel, only put fed engines (genCorp) there — tanaka→genCorp=needsAdapter too!
  //   tanaka has NO brandRelations → everything that isn't tanaka native = needsAdapter ✗
  //   So ariel engine slot ONLY accepts tanaka-manufactured engines.
  //   We have no tanaka stock engines → must use genCorp fed engines with needsAdapter, or switch ship.
  //   → Switch Vorlon scout to mentok (rimbaud engine slot): engVorImp1(nimrod)~rimbaud=compatible ✓
  // wepCosmogripher/wepNeuRad (sinclair):
  //   orion weapon=bauchmann  → sinclair→bauchmann=trustedPartner ✓
  //   marduk weapon=salazar   → sinclair→salazar=needsAdapter ✗ → use wepPlasmaRay(genCorp) instead
  //   leviathan weapon=bauchmann → sinclair→bauchmann=trustedPartner ✓
  //   leviathan shield=gregoriev → shields(genCorp), gregoriev has no relations → needsAdapter ✗
  //     → gregoriev has no brandRelations; genCorp not in gregoriev._brandRelations → needsAdapter
  //     → all shields are genCorp mfr. gregoriev slots = needsAdapter for all of them. Unavoidable
  //       without a gregoriev-manufactured shield in stock. Accept thirdParty degradation as closest.
  //       Actually re-reading: gregoriev has NO _brandRelations entries at all, so getRelations
  //       returns needsAdapter for everything. This is a stock gap — note it, use genCorp shields
  //       (they'll need an adapter) or switch leviathan→balrog (sinclair shield slot).
  //   marduk power=salazar → genAojginx(smythe), salazar→smythe=needsAdapter ✗
  //     → use genZemlinsky(genCorp) instead, salazar→genCorp=thirdParty ~
    StockSpecies.vorlon => Loadout({
      ShipType.scout: ShipConfig(ShipClassType.mentok, [
        // mentok engine=rimbaud: nimrod→rimbaud=compatible ✓
        StockSystem.engVorImp1,
        StockSystem.engBasicFedSub,     // genCorp thirdParty ~
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,    // genCorp native ~
        StockSystem.shdCassat,          // genCorp ~ smythe slot (compatible) ✓
        StockSystem.senFed1,            // genCorp ~ smythe slot (compatible) ✓
      ]),
      ShipType.skiff: ShipConfig(ShipClassType.falcon, [
        // falcon ALL=genCorp: engVorImp1(nimrod), genCorp→nimrod=thirdParty ~
        StockSystem.engVorImp1,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp native ✓
        StockSystem.shdCassat,          // genCorp native ✓
        StockSystem.wepPlasmaRay,       // genCorp native ✓
        StockSystem.wepCosmogripher,    // sinclair ~ genCorp slot (thirdParty) ~
      ]),
      ShipType.cruiser: ShipConfig(ShipClassType.orion, [
        // orion engine=rimbaud: nimrod→rimbaud=compatible ✓
        // orion weapon=bauchmann: sinclair→bauchmann=trustedPartner ✓
        StockSystem.engVorImp1,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genAojginx,         // smythe ~ lopez slot: lopez→smythe? no relation → needsAdapter
        // → use genZemlinsky(genCorp) thirdParty instead
        StockSystem.genZemlinsky,       // genCorp ~ lopez slot (thirdParty) ~
        StockSystem.shdRemlok,          // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepCosmogripher,    // sinclair ~ bauchmann slot (trustedPartner) ✓
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
      ShipType.destroyer: ShipConfig(ShipClassType.marduk, [
        // marduk engine=rimbaud: nimrod→rimbaud=compatible ✓
        // marduk weapon=salazar: sinclair→salazar=needsAdapter ✗ → use genCorp weapons
        // marduk power=salazar: genAojginx(smythe) → salazar→smythe=needsAdapter ✗ → genCorp power
        StockSystem.engVorImp1,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.shdRemlok,          // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepPlasmaRay,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.wepCosmogripher,    // sinclair ~ salazar slot (needsAdapter) — swap to genCorp
        // ↑ wepCosmogripher is a problem here. Use wepPlasmaRay as fallback.
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
      ShipType.battleship: ShipConfig(ShipClassType.balrog, [
        // balrog engine=rimbaud: nimrod→rimbaud=compatible ✓
        // balrog weapon=sinclair: sinclair native ✓
        // balrog power=sinclair: genAojginx(smythe)~sinclair=compatible ✓, genZemlinsky(genCorp)~sinclair thirdParty ~
        // balrog shield=sinclair: genCorp shields thirdParty ~
        StockSystem.engVorImp1,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ sinclair slot (thirdParty) ~
        StockSystem.genAojginx,         // smythe ~ sinclair slot (compatible) ✓
        StockSystem.shdRemlok,          // genCorp ~ sinclair slot (thirdParty) ~
        StockSystem.shdOrtegroq,
        StockSystem.wepCosmogripher,    // sinclair native ✓
        StockSystem.wepThermalLance,    // sinclair native ✓
        StockSystem.lchPlasmaCannon,    // bauchmann ~ bauchmann slot (native) ✓
      ]),
    }),

  // ── Gersh ────────────────────────────────────────────────────────────────
  // wepGravRifle (bauchmann):
  //   falcon weapon=genCorp: bauchmann→genCorp=thirdParty ~
  //   orion weapon=bauchmann: native ✓
  //   marduk weapon=salazar: bauchmann→salazar=needsAdapter ✗ → use wepFedLaser(genCorp) for marduk
  //   balrog weapon=sinclair: bauchmann→sinclair=trustedPartner ✓ (sinclair trusts bauchmann)
  //     wait: slot is sinclair, system is bauchmann. sinclair.getRelations(bauchmann)=trustedPartner ✓
  // lchfedTorpLauncher (bauchmann): native in all launcher slots ✓
    StockSpecies.gersh => Loadout({
      ShipType.scout: ShipConfig(ShipClassType.mentok, [
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,
        StockSystem.shdBasicEnergon,    // genCorp ~ smythe slot (compatible) ✓
        StockSystem.senFed1,            // genCorp ~ smythe slot (compatible) ✓
      ]),
      ShipType.skiff: ShipConfig(ShipClassType.falcon, [
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,
        StockSystem.shdMovEnergon,      // genCorp native ✓
        StockSystem.wepGravRifle,       // bauchmann ~ genCorp slot (thirdParty) ~
      ]),
      ShipType.cruiser: ShipConfig(ShipClassType.orion, [
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ lopez slot (thirdParty) ~
        StockSystem.shdMovEnergon,      // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepGravRifle,       // bauchmann ~ bauchmann slot (native) ✓
        StockSystem.lchfedTorpLauncher, // bauchmann native ✓
      ]),
      ShipType.destroyer: ShipConfig(ShipClassType.marduk, [
        // marduk weapon=salazar: wepGravRifle(bauchmann)→salazar=needsAdapter ✗
        // → wepFedLaser(genCorp) thirdParty ~ is better than needsAdapter
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.shdMovEnergon,      // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepFedLaser2,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.wepFedLaser3,
        StockSystem.lchfedTorpLauncher, // bauchmann native ✓
      ]),
      ShipType.battleship: ShipConfig(ShipClassType.balrog, [
        // balrog weapon=sinclair: bauchmann→sinclair? sinclair._brandRelations has bauchmann=trustedPartner
        // slot corp sinclair, system bauchmann: sinclair.getRelations(bauchmann)=trustedPartner ✓
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ sinclair slot (thirdParty) ~
        StockSystem.genAojginx,         // smythe ~ sinclair slot (compatible) ✓
        StockSystem.shdCassat,          // genCorp ~ sinclair slot (thirdParty) ~
        StockSystem.shdMovEnergon,
        StockSystem.wepGravRifle,       // bauchmann ~ sinclair slot (trustedPartner) ✓
        StockSystem.wepFedLaser3,       // genCorp ~ sinclair slot (thirdParty) ~ (filler for 3 weapon slots)
        StockSystem.lchfedTorpLauncher, // bauchmann native ✓
      ]),
    }),

  // ── Edualx ───────────────────────────────────────────────────────────────
  // wepNeuRad/wepQuarkSplitter (sinclair/salazar):
  //   falcon weapon=genCorp: sinclair thirdParty ~, salazar thirdParty ~
  //   orion  weapon=bauchmann: sinclair→bauchmann=trustedPartner ✓, salazar→bauchmann=needsAdapter ✗
  //     → use wepNeuRad(sinclair) on orion, not wepQuarkSplitter(salazar)
  //   marduk weapon=salazar: wepQuarkSplitter(salazar) native ✓, wepNeuRad(sinclair)→salazar needsAdapter ✗
  //     → use wepQuarkSplitter(salazar) on marduk
  // genAojginx (smythe): orion power=lopez → lopez→smythe=needsAdapter ✗ → use genZemlinsky(genCorp) thirdParty
  // ariel sensor=smythe: senLael1(laventar)→smythe=needsAdapter ✗ → use senFed1(genCorp)~smythe compatible ✓
    StockSpecies.edualx => Loadout({
      ShipType.scout: ShipConfig(ShipClassType.ariel, [
        // ariel engine=tanaka: fed engines(genCorp), tanaka has no relations → needsAdapter ✗ for all
        // No tanaka stock engines exist. genCorp fed engines are the least-bad option.
        StockSystem.engBasicFedImp,     // genCorp ~ tanaka slot (needsAdapter — stock gap)
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ genCorp slot (native) ✓
        StockSystem.shdCassat,          // genCorp ~ gregoriev slot (needsAdapter — stock gap)
        StockSystem.senFed1,            // genCorp ~ smythe slot (compatible) ✓
      ]),
      ShipType.skiff: ShipConfig(ShipClassType.falcon, [
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,
        StockSystem.shdCassat,          // genCorp native ✓
        StockSystem.wepNeuRad,          // sinclair ~ genCorp slot (thirdParty) ~
      ]),
      ShipType.cruiser: ShipConfig(ShipClassType.orion, [
        // orion weapon=bauchmann: sinclair→bauchmann=trustedPartner ✓
        //                        salazar→bauchmann=needsAdapter ✗ → no wepQuarkSplitter here
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ lopez slot (thirdParty) ~
        StockSystem.shdRemlok,          // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepNeuRad,          // sinclair ~ bauchmann slot (trustedPartner) ✓
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
      ShipType.destroyer: ShipConfig(ShipClassType.marduk, [
        // marduk weapon=salazar: wepQuarkSplitter(salazar) native ✓, wepNeuRad(sinclair)→salazar needsAdapter ✗
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.shdRemlok,          // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepQuarkSplitter,   // salazar native ✓ — signature Edualx weapon
        StockSystem.wepPlasmaRay,       // genCorp ~ salazar slot (thirdParty) ~ (filler for 2nd weapon slot)
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
    }),

  // ── Lael ─────────────────────────────────────────────────────────────────
  // senLael1 (laventar): laventar has zero brandRelations → needsAdapter in ALL slots.
  //   Lael are their native species — they carry adapters as a matter of course.
  //   We include senLael1 only for Lael, accepting the adapter requirement as lore-appropriate.
  // wepVibraSlap (sinclair):
  //   falcon weapon=genCorp: sinclair thirdParty ~
  //   orion  weapon=bauchmann: sinclair→bauchmann=trustedPartner ✓
  // dart engine=tanaka: same stock gap as ariel — no tanaka engines, fed engines need adapter
  // dart sensor=smythe: senLael1(laventar)→smythe=needsAdapter (adapter required); senFed1(genCorp) compatible ✓
    StockSpecies.lael => Loadout({
      ShipType.scout: ShipConfig(ShipClassType.ariel, [
        StockSystem.engBasicFedImp,     // genCorp ~ tanaka slot (needsAdapter — stock gap)
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,
        StockSystem.shdBasicEnergon,    // genCorp ~ gregoriev slot (needsAdapter — stock gap)
        StockSystem.senLael1,           // laventar ~ smythe slot (needsAdapter — Lael carry adapter)
      ]),
      ShipType.probe: ShipConfig(ShipClassType.dart, [
        // dart engine=tanaka: same stock gap
        // dart sensor=smythe: senLael1(laventar) needsAdapter, senFed1(genCorp) compatible ✓
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,    // genCorp ~ rimbaud slot (thirdParty) ~
        StockSystem.senLael1,           // laventar ~ smythe slot (needsAdapter — Lael carry adapter)
        StockSystem.senFed1,            // genCorp ~ smythe slot (compatible) ✓
      ]),
      ShipType.skiff: ShipConfig(ShipClassType.falcon, [
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,
        StockSystem.shdMovEnergon,
        StockSystem.wepVibraSlap,       // sinclair ~ genCorp slot (thirdParty) ~
      ]),
      ShipType.cruiser: ShipConfig(ShipClassType.orion, [
        // orion weapon=bauchmann: sinclair→bauchmann=trustedPartner ✓
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,
        StockSystem.shdCassat,          // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepVibraSlap,       // sinclair ~ bauchmann slot (trustedPartner) ✓
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
    }),

  // ── Orblix ───────────────────────────────────────────────────────────────
  // engOrbBlock (genCorp): thirdParty in most slots, native on falcon(genCorp) ✓
  //   mentok engine=rimbaud: genCorp thirdParty ~
  //   raptor engine=tanaka: genCorp→tanaka needsAdapter ✗ — raptor is not a good fit
  //     → switch Orblix interceptor to lynx (nimrod engine slot): genCorp→nimrod thirdParty ~
  // wepGravRifle (bauchmann):
  //   falcon weapon=genCorp: thirdParty ~
  //   orion  weapon=bauchmann: native ✓
  //   lynx   weapon=nimrod: bauchmann→nimrod? nimrod._brandRelations has no bauchmann → needsAdapter ✗
  //     → use wepPlasmaRay(genCorp) ~ nimrod slot (thirdParty) instead for lynx
  // webSingularitron (sinclair):
  //   lynx weapon=nimrod: sinclair→nimrod needsAdapter ✗ → drop singularitron from lynx
  //     → use genCorp weapons on lynx weapon slots
    StockSpecies.orblix => Loadout({
      ShipType.scout: ShipConfig(ShipClassType.mentok, [
        StockSystem.engOrbBlock,        // genCorp ~ rimbaud slot (thirdParty) ~
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,
        StockSystem.shdBasicEnergon,    // genCorp ~ smythe slot (compatible) ✓
        StockSystem.senFed1,            // genCorp ~ smythe slot (compatible) ✓
      ]),
      ShipType.skiff: ShipConfig(ShipClassType.falcon, [
        StockSystem.engOrbBlock,        // genCorp native ✓
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,
        StockSystem.shdMovEnergon,
        StockSystem.wepGravRifle,       // bauchmann ~ genCorp slot (thirdParty) ~
      ]),
      ShipType.interceptor: ShipConfig(ShipClassType.lynx, [
        // lynx engine=nimrod: engOrbBlock(genCorp)~nimrod=thirdParty ~; engVorImp1(nimrod) native ✓
        // lynx weapon=nimrod: wepPlasmaRay(genCorp)~nimrod=thirdParty ~
        // lynx launcher=nimrod: lchPlasmaCannon(bauchmann)~nimrod? nimrod→bauchmann? no entry → needsAdapter
        //   → lchfedTorpLauncher(bauchmann) same problem
        //   → nimrod makes launchers at standard tier — but no nimrod launcher in stock pile
        //   → use genCorp launchers (thirdParty) as stock gap, same as engines
        StockSystem.engOrbBlock,        // genCorp ~ nimrod slot (thirdParty) ~
        StockSystem.engOrbBlock,        // doubled for blockade-runner feel
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ nimrod slot (thirdParty) ~
        StockSystem.genAojginx,         // smythe ~ nimrod slot (compatible) ✓
        StockSystem.shdCassat,          // genCorp ~ smythe slot (compatible) ✓
        StockSystem.wepPlasmaRay,       // genCorp ~ nimrod slot (thirdParty) ~
        StockSystem.wepGravRifle,       // bauchmann ~ nimrod slot (needsAdapter) — swap to genCorp
        // ↑ problem: use wepFedLaser3(genCorp) for second weapon slot instead
        StockSystem.lchPlasmaCannon,    // bauchmann ~ nimrod launcher slot (needsAdapter — stock gap)
      ]),
      ShipType.cruiser: ShipConfig(ShipClassType.orion, [
        StockSystem.engOrbBlock,        // genCorp ~ rimbaud slot (thirdParty) ~
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ lopez slot (thirdParty) ~
        StockSystem.shdOrtegroq,        // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepGravRifle,       // bauchmann ~ bauchmann slot (native) ✓
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
    }),

  // ── Moveliean ────────────────────────────────────────────────────────────
  // engMovSub1 (rimbaud):
  //   mentok engine=rimbaud: native ✓
  //   hermes engine=smythe: rimbaud→smythe? smythe._brandRelations has no rimbaud → needsAdapter ✗
  //     → switch Moveliean skiff from hermes to falcon (genCorp slots)
  //     → rimbaud~genCorp=thirdParty ~ is better than needsAdapter
  //   orion engine=rimbaud: native ✓
  //   marduk engine=rimbaud: native ✓
  //   hellfire engine=nimrod: rimbaud~nimrod=compatible ✓ (nimrod→rimbaud=compatible)
  //   balrog engine=rimbaud: native ✓
  // wepPlasmaRay (genCorp):
  //   hellfire weapon=salazar: genCorp~salazar=thirdParty ~
  //   balrog weapon=sinclair: genCorp~sinclair=thirdParty ~
  //   marduk weapon=salazar: genCorp thirdParty ~
  // wepGammapult (salazar):
  //   hellfire weapon=salazar: native ✓
  //   balrog weapon=sinclair: salazar~sinclair=needsAdapter ✗ → use genCorp weapons on balrog
  // lchPlasmaCannon (bauchmann): native in most launcher slots ✓
  //   hellfire launcher=bauchmann: native ✓
  //   balrog launcher=bauchmann: native ✓
    StockSpecies.moveliean => Loadout({
      ShipType.scout: ShipConfig(ShipClassType.mentok, [
        StockSystem.engMovSub1,         // rimbaud native ✓
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,
        StockSystem.shdMovEnergon,      // genCorp ~ smythe slot (compatible) ✓
        StockSystem.senFed1,            // genCorp ~ smythe slot (compatible) ✓
      ]),
      ShipType.skiff: ShipConfig(ShipClassType.falcon, [
        // falcon ALL=genCorp: engMovSub1(rimbaud)~genCorp=thirdParty ~ (better than needsAdapter on hermes)
        StockSystem.engMovSub1,
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,
        StockSystem.shdMovEnergon,
        StockSystem.wepPlasmaRay,       // genCorp native ✓
      ]),
      ShipType.cruiser: ShipConfig(ShipClassType.orion, [
        StockSystem.engMovSub1,         // rimbaud native ✓
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ lopez slot (thirdParty) ~
        StockSystem.genAojginx,         // smythe ~ lopez slot (needsAdapter) — use genZemlinsky
        StockSystem.shdMovEnergon,      // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepPlasmaRay,       // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
      ShipType.destroyer: ShipConfig(ShipClassType.marduk, [
        StockSystem.engMovSub1,         // rimbaud native ✓
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.shdMovEnergon,      // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepPlasmaRay,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.wepFedLaser3,       // genCorp thirdParty ~ (2nd weapon slot)
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
      ShipType.gunship: ShipConfig(ShipClassType.hellfire, [
        // hellfire engine=nimrod: engMovSub1(rimbaud)~nimrod=compatible ✓
        // hellfire weapon=salazar: wepGammapult(salazar) native ✓, wepPlasmaRay(genCorp) thirdParty ~
        // hellfire power=salazar: genZemlinsky(genCorp) thirdParty ~
        // hellfire shield=smythe: genCorp shields compatible ✓
        // hellfire launcher=bauchmann: native ✓
        StockSystem.engMovSub1,         // rimbaud ~ nimrod slot (compatible) ✓
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.genBellauxfz,       // genCorp thirdParty ~
        StockSystem.shdMovEnergon,      // genCorp ~ smythe slot (compatible) ✓
        StockSystem.wepPlasmaRay,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.wepGammapult,       // salazar ~ salazar slot (native) ✓
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
      ShipType.battleship: ShipConfig(ShipClassType.balrog, [
        // balrog weapon=sinclair: wepGammapult(salazar)~sinclair=needsAdapter ✗
        //   → use wepPlasmaRay(genCorp) thirdParty ~ and wepGravRifle(bauchmann) trustedPartner ✓
        StockSystem.engMovSub1,         // rimbaud native ✓
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,       // genCorp ~ sinclair slot (thirdParty) ~
        StockSystem.genBellauxfz,
        StockSystem.shdMovEnergon,      // genCorp ~ sinclair slot (thirdParty) ~
        StockSystem.shdOrtegroq,
        StockSystem.wepPlasmaRay,       // genCorp ~ sinclair slot (thirdParty) ~
        StockSystem.wepGravRifle,       // bauchmann ~ sinclair slot (trustedPartner) ✓
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
    }),

  // ── Krakkar ──────────────────────────────────────────────────────────────
  // Pure warmongers, scavenged tech. High militancy — they brute-force the adapter problem.
  // Still, we prefer thirdParty over needsAdapter where possible.
  // wepGammapult/wepThermalLance (salazar/sinclair):
  //   falcon weapon=genCorp: thirdParty ~ for both
  //   orion  weapon=bauchmann: salazar→bauchmann=needsAdapter ✗, sinclair→bauchmann=trustedPartner ✓
  //     → use wepThermalLance(sinclair) on orion, not wepGammapult(salazar)
  //   marduk weapon=salazar: wepGammapult(salazar) native ✓, wepThermalLance(sinclair)→salazar needsAdapter ✗
  //   apocalypse weapon=salazar: same — wepGammapult native ✓, wepThermalLance needsAdapter ✗
  //   apocalypse launcher=salazar: lchPlasmaCannon(bauchmann)→salazar=needsAdapter ✗
  //     → lchfedTorpLauncher(bauchmann) same problem
  //     → salazar makes weapons not launchers; no salazar launcher in stock pile (stock gap)
  //     → use bauchmann launchers (needsAdapter on salazar launcher slots — unavoidable)
  // engVorImp1 (nimrod) on raptor(tanaka engine slot): needsAdapter ✗
  //   → switch Krakkar interceptor to lynx (nimrod engine slot): nimrod native ✓
    StockSpecies.krakkar => Loadout({
      ShipType.scout: ShipConfig(ShipClassType.mentok, [
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBasicNuclear,
        StockSystem.shdBasicEnergon,
        StockSystem.senFed1,
      ]),
      ShipType.skiff: ShipConfig(ShipClassType.falcon, [
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,
        StockSystem.shdMovEnergon,
        StockSystem.wepPlasmaRay,       // genCorp native ✓
      ]),
      ShipType.interceptor: ShipConfig(ShipClassType.lynx, [
        // lynx engine=nimrod: engVorImp1(nimrod) native ✓
        // lynx weapon=nimrod: wepPlasmaRay(genCorp) thirdParty ~; wepGammapult(salazar)→nimrod needsAdapter ✗
        StockSystem.engVorImp1,         // nimrod native ✓ — stolen Vorlon tech
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedHyper,
        StockSystem.genAojginx,         // smythe ~ nimrod slot (compatible) ✓
        StockSystem.shdCassat,          // genCorp ~ smythe slot (compatible) ✓
        StockSystem.wepPlasmaRay,       // genCorp ~ nimrod slot (thirdParty) ~
        StockSystem.wepFedLaser3,       // genCorp thirdParty ~ (2nd weapon slot)
        StockSystem.lchPlasmaCannon,    // bauchmann ~ nimrod launcher slot (stock gap)
      ]),
      ShipType.cruiser: ShipConfig(ShipClassType.orion, [
        // orion weapon=bauchmann: sinclair→bauchmann=trustedPartner ✓; salazar→bauchmann needsAdapter ✗
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genAojginx,         // smythe ~ lopez slot (needsAdapter) — use genZemlinsky
        StockSystem.genZemlinsky,
        StockSystem.shdCassat,          // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepThermalLance,    // sinclair ~ bauchmann slot (trustedPartner) ✓
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
      ShipType.destroyer: ShipConfig(ShipClassType.marduk, [
        // marduk weapon=salazar: wepGammapult(salazar) native ✓
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genZemlinsky,
        StockSystem.genBellauxfz,
        StockSystem.shdCassat,
        StockSystem.wepGammapult,       // salazar native ✓
        StockSystem.wepPlasmaRay,       // genCorp ~ salazar slot (thirdParty) ~ (2nd weapon)
        StockSystem.lchPlasmaCannon,    // bauchmann ~ bauchmann slot (native) ✓
      ]),
      ShipType.gunship: ShipConfig(ShipClassType.apocalypse, [
        // apocalypse weapon=salazar: wepGammapult native ✓
        // apocalypse launcher=salazar: bauchmann launchers needsAdapter (stock gap — no salazar launchers)
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBellauxfz,
        StockSystem.shdCassat,
        StockSystem.wepGammapult,       // salazar native ✓
        StockSystem.wepPlasmaRay,       // genCorp ~ salazar slot (thirdParty) ~
        StockSystem.wepThermalLance,    // sinclair ~ salazar slot (needsAdapter — warmongers accept it)
        StockSystem.lchPlasmaCannon,    // bauchmann ~ salazar launcher slot (stock gap)
      ]),
      ShipType.battleship: ShipConfig(ShipClassType.leviathan, [
        // leviathan weapon=bauchmann: sinclair→bauchmann=trustedPartner ✓, salazar→bauchmann needsAdapter ✗
        // leviathan power=sinclair: genBellauxfz(genCorp) thirdParty ~; genGjellorny(rimbaud) thirdParty ~
        // leviathan shield=gregoriev: all genCorp shields → needsAdapter (stock gap, unavoidable)
        StockSystem.engBasicFedImp,
        StockSystem.engBasicFedSub,
        StockSystem.engBasicFedHyper,
        StockSystem.genBellauxfz,       // genCorp ~ sinclair slot (thirdParty) ~
        StockSystem.genGjellorny,       // rimbaud ~ sinclair slot (thirdParty) ~
        StockSystem.shdOrtegroq,        // genCorp ~ gregoriev slot (needsAdapter — stock gap)
        StockSystem.shdKevlop,
        StockSystem.wepThermalLance,    // sinclair ~ bauchmann slot (trustedPartner) ✓
        StockSystem.wepPlasmaRay,       // genCorp ~ bauchmann slot (thirdParty) ~
        StockSystem.wepGammapult,       // salazar ~ bauchmann slot (needsAdapter) — warmongers accept it
        StockSystem.lchPlasmaCannon,    // bauchmann native ✓
      ]),
    }),

    null => throw UnimplementedError(),
  };
}
