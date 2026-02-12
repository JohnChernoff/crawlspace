import 'package:directed_graph/directed_graph.dart';
import 'dart:math';
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

  final String version = "0.1g";
  Galaxy galaxy;
  DirectedGraph<System> systemGraph = DirectedGraph({});
  late Player player;
  int numAgents = 3;
  List<Agent> agents = [];
  Random rnd = Random();
  int auTick = 0;
  String? result;
  bool gameOver = false;
  bool victory = false;
  Map<Pilot,Ship> pilotMap = {};
  Set<Pilot> pilots = {};
  Ship? get playerShip => pilotMap[player];
  Iterable<Pilot> get activePilots => pilots.where((p) => pilotMap[p] != null);
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

  FugueEngine(this.galaxy,String playerName) {
    msgController = MessageController(this);
    movementController = MovementController(this);
    layerTransitController = LayerTransitController(this);
    pilotController = PilotController(this);
    combatController = CombatController(this);
    menuController = MenuController(this);
    planetsideController = PlanetsideController(this);
    scannerController = ScannerController(this);
    audioController = AudioController(NullAudioService(),rnd);
    for (final sys in galaxy.systems) {
      systemGraph.addEdges(sys, sys.links);
    }
    List<System>? maxPath; System farthestSystem = galaxy.homeSystem;
    for (System sys in galaxy.systems) {
      List<System> path = systemGraph.shortestPath(sys, galaxy.homeSystem);
      //galaxyGraph.shortestPath(sys,galaxy.homeSystem);
      if (path.length > (maxPath?.length ?? 0)) {
        maxPath = path; farthestSystem = sys;
      }
    } //print("Max Path: $maxPath");

    player = Player(playerName,farthestSystem);
    player.system.visited = true;
    for (int i=0;i<numAgents;i++) {
      agents.add(Agent("Agent ${Rng.generateName(rnd: rnd)}", galaxy.homeSystem, 25));
    }
    final playCell = player.system.map.rndCell(rnd);
    Ship playShip = Ship("HMS Sebastian",
        player,shipClass: ShipClass.hermes,loc: SystemLocation(player.system, playCell),
        weapons: [Weapon.fromStock(StockSystem.fedLaser3),Weapon.fromStock(StockSystem.plasmaCannon)],
        ammo: {Ammo.fromStock(StockSystem.plasmaBall) : 8});
    pilotMap[player] = playShip;
    for (System sys in galaxy.systems) {
      for (int i=0;i<rnd.nextInt(3);i++) {
        addShip(Ship("${Rng.rndColorName(rnd)}${Rng.rndAnimalName(rnd)}",
            Pilot(Rng.generateName(rnd: rnd),sys),
            shipClass: ShipClass.mentok,
            loc: SystemLocation(sys, sys.map.rndCell(rnd))));
      }
    }
    msgController.addMsg("Welcome to crawlspace, version $version!  Press 'H' for help, space bar toggles full screen text.");
    update(); //galaxy.rndTest();
  }

  void addShip(Ship ship) {
    if (ship.pilot != nobody) {
      pilotMap[ship.pilot] = ship;
      pilots.add(ship.pilot);
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

  void explore(System system,int depth) { //msgController.addMsg("Exploring: ${system.name} , depth: $depth");
    system.scout();
    if (depth == 0) return;
    for (System link in system.links) {
      if (!link.scouted) explore(link,depth-1);
    }
  }

  Planet? createTradePlanet(List<System> path,int steps) {
    if (steps < 1 && path.last.planets.isNotEmpty) {
      return path.last.planets.elementAt(rnd.nextInt(path.last.planets.length));
    } else {
      Set<System> links = path.last.links;
      List<System> unvisitedLinks = links.where((link) => !path.contains(link)).toList();
      if (unvisitedLinks.isNotEmpty) {
        unvisitedLinks.shuffle();
        path.add(unvisitedLinks.first);
        return createTradePlanet(path, steps-1);
      } else { //print("Trade error, steps: $steps, path: $path");
        return null;
      }
    }
  }

  energyScoop() {
    Ship? ship = playerShip;
    if (ship == null) {
      msgController.addMsg("You're not in a ship."); return;
    }
    //if (player.lastAct == ActionType.energyScoop && !pirateCheck(numPirates: 2)) return;
    double amount = 50;
    //((ship.energyConvertor.value/(Rng.biasedRndInt(rnd,mean: 50, min: 25, max: 80))) * player.system.starClass.power).floor();
    msgController.addMsg("Scooping class ${player.system.starClass.name} star... gained ${ship.recharge(amount)} energy");
    pilotController.action(player,ActionType.energyScoop);
  }

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

  void glog(String msg) {
    print(msg);
  }

}