import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:crawlspace_engine/stock_items/stock_engines.dart';
import 'package:crawlspace_engine/stock_items/stock_power.dart';
import 'package:crawlspace_engine/systems/engines.dart';
import 'package:crawlspace_engine/systems/power.dart';
import 'package:crawlspace_engine/systems/shields.dart';
import 'package:crawlspace_engine/systems/ship_system.dart';

import 'agent.dart';
import 'audio_service.dart';
import 'color.dart';
import 'controllers/audio_controller.dart';
import 'controllers/combat_controller.dart';
import 'controllers/layer_transit_controller.dart';
import 'controllers/menu_controller.dart';
import 'controllers/message_controller.dart';
import 'controllers/movement_controller.dart';
import 'controllers/pilot_controller.dart';
import 'controllers/planetside_controller.dart';
import 'controllers/scanner_controller.dart';
import 'galaxy.dart';
import 'grid.dart';
import 'location.dart';
import 'pilot.dart';
import 'planet.dart';
import 'player.dart';
import 'rng.dart';
import 'ship.dart';
import 'shop.dart';
import 'stock_items/stock_pile.dart';
import 'stock_items/stock_ships.dart';
import 'system.dart';
import 'systems/weapons.dart';

const blownUp = -1;

class TextBlock {
  final String txt;
  final bool newline;
  final GameColor color;
  const TextBlock(this.txt,this.color,this.newline);
}

//cargo systems?  passengers, smuggling? cloaking systems?
//hyperspace landing spot?   Graph not detecting player location?
class FugueEngine {
  final _listeners = <void Function()>[];

  void addListener(void Function() f) => _listeners.add(f);
  void removeListener(void Function() f) => _listeners.remove(f);

  void _notify() {
    for (final f in _listeners) {
      f();
    }
  }

  final String version = "0.1h";
  Galaxy galaxy;
  late Player player;
  int numAgents = 3;
  List<Agent> agents = [];
  late Random rnd,mapRng,speciesRng,aiRng,itemRng; //TODO: remove rnd
  int auTick = 0;
  String? result;
  bool gameOver = false;
  bool victory = false;
  Map<Pilot,Ship> pilotMap = {};
  Set<Pilot> npcPilots = {};
  Ship? get playerShip => pilotMap[player];
  Iterable<Pilot> get activePilots => npcPilots.where((p) => pilotMap[p] != null);
  Iterable<Pilot> get availablePilots => activePilots.where((p) => p.auCooldown == 0);

  late MessageController msgController;
  late MovementController movementController;
  late LayerTransitController layerTransitController;
  late PilotController pilotController;
  late CombatController combatController;
  late MenuController menuController;
  late PlanetsideController planetsideController;
  late ScannerController scannerController;
  late AudioController audioController;
  ShopOptions shopOptions = ShopOptions();

  FugueEngine(this.galaxy,String playerName,{seed = 0}) {
    rnd = Random(seed);
    mapRng = Random(seed ^0xAAAAAA);
    speciesRng = Random(seed ^ 0xC0FFEE);
    aiRng = Random(seed ^ 0xBADC0DE);
    itemRng = Random(seed ^ 0xC0BFEED);
    msgController = MessageController(this);
    movementController = MovementController(this);
    layerTransitController = LayerTransitController(this);
    pilotController = PilotController(this);
    combatController = CombatController(this);
    menuController = MenuController(this);
    planetsideController = PlanetsideController(this);
    scannerController = ScannerController(this);
    audioController = AudioController(NullAudioService(),rnd);
    player = Player(playerName,galaxy.farthestSystem(galaxy.homeSystem),mapRng);
    player.system.visited = true;
    for (int i=0;i<numAgents;i++) {
      agents.add(Agent("Agent ${Rng.generateName(rnd: rnd)}", galaxy.homeSystem, mapRng, 25));
    }
    final playCell = player.system.map.rndCell(rnd);
    Ship playShip = Ship("HMS Sebastian",
        player,shipClass: ShipClassType.hermes.shipclass,loc: SystemLocation(player.system, playCell),
        generator: PowerGenerator.fromStock(StockSystem.basicNuclear),
        impEngine: Engine.fromStock(StockSystem.basicFedImpulse),
        subEngine: Engine.fromStock(StockSystem.basicFedSublight),
        hyperEngine: Engine.fromStock(StockSystem.basicFedHyperdrive),
        shield: Shield.fromStock(StockSystem.basicEnergon),
        weapons: [Weapon.fromStock(StockSystem.fedLaser3),Weapon.fromStock(StockSystem.plasmaCannon)],
        ammo: {Ammo.fromStock(StockSystem.plasmaBall) : 8});
    pilotMap[player] = playShip;
    msgController.addMsg("Welcome to crawlspace, version $version!  Press 'H' for help, space bar toggles full screen text.");
    update(); //galaxy.rndTest();
  }

  void populateSystem(System system, {int? numShips}) {
    print("Populating System");
    system.population = {
      for (final sp in galaxy.allSpecies)
        sp: 100 / galaxy.graphDistance(system, galaxy.findHomeworld(sp)),
    };
    numShips ??= rnd.nextInt(3);
    for (int i = 0; i < numShips; i++) {
      final pilot = Pilot(Rng.generateName(rnd: rnd),system,mapRng,hostile: true);
      print("Populating System, Pilot: ${pilot.faction.name}");
      final level = 1 - (galaxy.graphDistance(system, galaxy.findHomeworld(pilot.faction.species)) / galaxy.maxJumps);
      final techLvl = (level * 10).round();
      print("Tech lvl: $techLvl, $level");
      ShipType shipType = Rng.weightedRandom(pilot.faction.shipWeights.normalized,mapRng);
      while (level < shipType.dangerLvl) {
        shipType = Rng.weightedRandom(pilot.faction.shipWeights.normalized,mapRng);
      }
      final shipClassType = ShipClassType.values.firstWhereOrNull((t) => t.shipclass.type == shipType) ?? ShipClassType.mentok;
      print("Ship Type: $shipType, $shipClassType");
      Ship ship = Ship("${Rng.rndColorName(rnd)}${Rng.rndAnimalName(rnd)}",pilot,
          loc: SystemLocation(system, system.map.rndCell(mapRng)),
          shipClass: shipClassType.shipclass
      );
      ship.installRndPower(techLvl, itemRng);
      ship.installRndEngine(Domain.impulse, techLvl, itemRng);
      ship.installRndEngine(Domain.system, techLvl, itemRng);
      ship.installRndEngine(Domain.hyperspace, techLvl, itemRng);
      ship.installRndShield(techLvl, itemRng);
      ship.installRndWeapon(techLvl, itemRng);
      addShip(ship);
    }
  }

  void addShip(Ship ship) {
    if (ship.pilot != nobody) {
      pilotMap[ship.pilot] = ship;
      npcPilots.add(ship.pilot);
    }
  }

  void removeShip(Ship ship) {
    for (final s in pilotMap.values) {
      if (s.targetShip == ship) s.targetShip = null;
    }
    pilotMap.remove(ship.pilot);
    ship.loc.level.map.shipMap[ship.loc.cell]?.remove(ship);
  }

  AgentSystemReport agentAt(System system, {bool playerPerspective = true}) {
    AgentSystemReport report = AgentSystemReport.none;
    for (Agent a in agents) { //print("Checking Agent at ${a.system.name}, ${a.lastKnown?.name}, ${a.tracked}");
      if (playerPerspective && a.lastKnown == system) {
        if (a.tracked > 0) {
          return AgentSystemReport.current;
        } else {
          report = AgentSystemReport.lastKnown;
        }
      }
      else if (!playerPerspective && a.system == system) {
        return AgentSystemReport.current;
      }
    }
    return report;
  }

  void outOfEnergy() {
    msgController.addMsg("Insufficient energy!");
  }

  void endGame(String reason, {bool home = false}) {
    if (home) {
      if (!player.starOne || player.broadcasts == 0) {
        msgController.addMsg("You arrive on ${galaxy.homeWorld.name} and are immediately taken into custody and shortly thereafter executed for treason. "
            "Perhaps you should have broadcasted your information to the galaxy first.");
      }
      else if (Rng.biasedRndInt(rnd,mean: 1, min: 0, max: 5) <= player.broadcasts) {
        msgController.addMsg("You arrive on ${galaxy.homeWorld.name} admist a media firestorm and are taken into custody, but before your case can be "
            "heard the Federation Government collapses and you are reappointed and promoted to the rank of Intergalactic Commodore ${player.name}. "
            "Congratulations!");
        victory = true;
      } else {
        msgController.addMsg("You arrive only to be immediately taken into custody as planet-wide protests echo in the distance.  Unfortunately your arrival also "
        "corresponds with the Intergalactic Foosball Cup and the public's interest in your case wanes.  You eventually wind up exiled on the distant ice planet "
        "Winnipegiax where you helplessly witness the antimatter-annihilation of roughly half the galaxy.");
      }
    }
    result = reason;
    gameOver = true;
    msgController.addMsg("*** GAME OVER ***");
    update();
  }

  String starDate() {
    return "$auTick.";
  }

  System starOne() {
    return galaxy.systems.firstWhere((s) => s.starOne);
  }

  //normal: true if repeatedly below level, inverted: true if repeatedly above level (less likely)
  bool techCheck(int passes, {bool invert = false}) {
    for (int i=0;i<passes;i++) {
      if (rnd.nextInt(100) > (invert ? 100 - player.techLevel() : player.techLevel())) return false;
    }
    return true;
  }

  bool fedCheck(int passes, {bool invert = false}) {
    for (int i=0;i<passes;i++) {
      if (rnd.nextInt(100) > (invert ? 100 - player.fedLevel() : player.fedLevel())) return false;
    }
    return true;
  }

  String pathList(List<System> path) {
    StringBuffer sb = StringBuffer();
    for (System link in path) {
      sb.write(link.name);
      if (link != path.last) sb.write(" -> ");
    }
    return sb.toString();
  }

  System? nextSystemInPath(List<System>? path) {
    if (path == null) return null;
    return path.elementAt(path.length > 1 ? 1 : 0);
  }

  int jumps(List<System>? path) => (path?.length ?? 0) - 1;

  void heat(int v, {System? sighted}) {
    for (Agent agent in agents) {
      agent.clueLvl = min(agent.clueLvl + v,100);
      if (sighted != null) agent.sighted = sighted;
    }
    String heatAdj = switch(v) {
      < 5 => "a bit",
      < 12 => "significantly",
      < 24 => "much",
      int() => "massively"
    };
    msgController.addMsg("The galaxy just got $heatAdj more dangerous."); //(+$v)");
  }

  int currentHeat() {
    return (agents.fold(0, (pv,e) => pv + e.clueLvl) / agents.length).floor();
  }

  int score() => auTick + (player.starOne ? 500 : 0) + (galaxy.discoveredSystems() * 2) + (player.piratesVanquished * 3) + (victory ? 1000 : 0);

  Future<void> update() async {
    if (!msgController.msgWorker.isProcessing || msgController.msgWorker.processNotifier.isCompleted) { //print("Updating...");
      _notify();
    } else { //print("Waiting on message queue...");
      msgController.msgWorker.processNotifier.future.then((v) { //print("Message queue clear, updating...");
        _notify();
      });
    }
  }

  static void glog(String msg, {bool error = false}) {
    print(msg);
    assert(() {
      if (error) throw AssertionError(msg);
      return true;
    }());
  }
}