import 'dart:math';
import 'package:crawlspace_engine/hazards.dart';
import 'package:crawlspace_engine/menu_factory.dart';
import 'package:crawlspace_engine/pilot_reg.dart';
import 'package:crawlspace_engine/ship_reg.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:crawlspace_engine/systems/engines.dart';
import 'package:crawlspace_engine/systems/power.dart';
import 'package:crawlspace_engine/systems/shields.dart';
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
import 'galaxy/galaxy.dart';
import 'impulse.dart';
import 'location.dart';
import 'pilot.dart';
import 'player.dart';
import 'rng.dart';
import 'ship.dart';
import 'shop.dart';
import 'stock_items/stock_pile.dart';
import 'stock_items/stock_ships.dart';
import 'galaxy/system.dart';
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
//TODO: add music, add launchers, one shield/generator per ship, Galaxy menu/refresh log, themed tavern games/activities
//Show ship class somehow
//hostility calc, pacification/bribes, swap , and . keys, more intuitive key commands, etc.
class FugueEngine {
  final _listeners = <void Function()>[];

  void addListener(void Function() f) => _listeners.add(f);
  void removeListener(void Function() f) => _listeners.remove(f);

  void _notify() {
    for (final f in _listeners) {
      f();
    }
  }

  final String version = "0.1n";
  final Galaxy galaxy;
  late Player player;
  int numAgents = 3;
  final List<Agent> agents = [];
  late Random rnd,combatRng,mapRng,speciesRng,aiRng,itemRng, audioRnd; //TODO: remove rnd
  int auTick = 0;
  String get result => blownUp ? "blown up" : isVictorious ? "victorious" : "vanquished";
  bool get blownUp => (getShip(player)?.hullRemaining ?? 1) <= 0;
  bool? victory;
  bool get isVictorious => victory ??= true;
  bool get gameOver => victory != null || blownUp;
  int get score => auTick + (player.starOne ? 500 : 0) +
      (galaxy.discoveredSystems() * 2) + (player.piratesVanquished * 3) + (isVictorious ? 1000 : 0);
  final ShipRegistry _shipRegistry = ShipRegistry();
  ShipRegistry get shipRegistry => _shipRegistry;
  final PilotRegistry _pilotRegistry = PilotRegistry();
  Ship? getShip(Pilot pilot) => _shipRegistry.byPilot(pilot);
  Ship? get playerShip => getShip(player);
  Iterable<Pilot> get activePilots => _pilotRegistry.withShips(shipRegistry, npc: true);
  Iterable<Pilot> get availablePilots => activePilots.where((p) => p.auCooldown == 0);

  late final MenuFactory menuFactory = MenuFactory(this);
  late final MenuController menuController = MenuController(this);
  late final MessageController msgController = MessageController(this);
  late final MovementController movementController = MovementController(this);
  late final LayerTransitController layerTransitController = LayerTransitController(this);
  late final PilotController pilotController = PilotController(this);
  late final CombatController combatController = CombatController(this);
  late final PlanetsideController planetsideController = PlanetsideController(this);
  late final ScannerController scannerController = ScannerController(this);
  late final AudioController audioController = AudioController(NullAudioService(),audioRnd);
  final ShopOptions shopOptions = ShopOptions();

  FugueEngine(this.galaxy,String playerName,{seed = 0}) {
    rnd = Random(seed);
    audioRnd = Random(seed ^0xAAAAAA);
    mapRng = Random(seed ^0xBBBBBBB);
    speciesRng = Random(seed ^ 0xC0FFEE);
    aiRng = Random(seed ^ 0xBADC0DE);
    itemRng = Random(seed ^ 0xC0BFEED);
    combatRng = Random(seed ^ 0xABCDEF00);
    final farSys = galaxy.farthestSystem(galaxy.fedHomeSystem);
    for (int i=0;i<numAgents;i++) {
      //agents.add(Agent("Agent ${Rng.generateName(rnd: rnd)}", mapRng, 25, sys: galaxy.fedHomeSystem, galaxy: galaxy));
      //TODO: add ships, pilot locale
    }
    Ship playShip = Ship("HMS Sebastian",
        shipClass: ShipClassType.hermes.shipclass,
        location: SystemLocation(farSys, farSys.map.rndCell(rnd)),
        generator: PowerGenerator.fromStock(StockSystem.basicNuclear),
        impEngine: Engine.fromStock(StockSystem.basicFedImpulse),
        subEngine: Engine.fromStock(StockSystem.basicFedSublight),
        hyperEngine: Engine.fromStock(StockSystem.basicFedHyperdrive),
        shield: Shield.fromStock(StockSystem.basicEnergon),
        weapons: [Weapon.fromStock(StockSystem.fedLaser3),Weapon.fromStock(StockSystem.plasmaCannon)],
        ammo: {Ammo.fromStock(StockSystem.plasmaBall) : 50});
    player = Player(playerName,mapRng, loc: AboardShip(playShip)); //playShip.pilot = player;
    player.system.visited = true;
    addShip(playShip);
    msgController.addMsg("Welcome to crawlspace, version $version!  Press 'H' for help, space bar toggles full screen text.");
    update();
  }

  void addShip(Ship ship) {
    _shipRegistry.add(ship);
    _pilotRegistry.add(ship.pilot);
  }

  void populateSystem(System system, {int? numShips}) {
    numShips ??= rnd.nextInt(3);
    print("Populating System: ${system.name}, ships: $numShips");
    for (int i = 0; i < numShips; i++) {
      addShip(Rng.generateShip(system, galaxy, itemRng));
    }
  }

  void newShip(Pilot pilot, Ship ship) {
    final loc = pilot.locale;
    if (loc is AtEnvironment) {
      _shipRegistry.undock(ship, loc.env);
      final formerShip = _shipRegistry.byPilot(pilot);
      if (formerShip != null) _shipRegistry.dock(ship, loc.env);
    }
    _shipRegistry.changePilot(ship, pilot);
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

  void homecoming({bool home = false}) {
    final hw = galaxy.findHomeworld(StockSpecies.humanoid.species);
    if (home) {
      if (!player.starOne || player.broadcasts == 0) {
        msgController.addMsg("You arrive on ${hw.name} and are immediately taken into custody and shortly thereafter executed for treason. "
            "Perhaps you should have broadcasted your information to the galaxy first.");
        victory = false;
      }
      else if (Rng.biasedRndInt(rnd,mean: 1, min: 0, max: 5) <= player.broadcasts) {
        msgController.addMsg("You arrive on ${hw.name} admist a media firestorm and are taken into custody, but before your case can be "
            "heard the Federation Government collapses and you are reappointed and promoted to the rank of Intergalactic Commodore ${player.name}. "
            "Congratulations!");
        victory = true;
      } else {
        msgController.addMsg("You arrive only to be immediately taken into custody as planet-wide protests echo in the distance.  Unfortunately your arrival also "
        "corresponds with the Intergalactic Foosball Cup and the public's interest in your case wanes.  You eventually wind up exiled on the distant ice planet "
        "Winnipegiax where you helplessly witness the antimatter-annihilation of roughly half the galaxy.");
        victory = false;
      }
    }
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
      if (rnd.nextInt(100) > (invert ? 100 - player.techLevel(galaxy) : player.techLevel(galaxy))) return false;
    }
    return true;
  }

  bool fedCheck(int passes, {bool invert = false}) {
    for (int i=0;i<passes;i++) {
      if (rnd.nextInt(100) > (invert ? 100 - player.fedLevel(galaxy) : player.fedLevel(galaxy))) return false;
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

  void reportSighting(System s) {
    for (var agent in agents) {
      if (agent.clueLvl > rnd.nextInt(10)) {
        agent.sighted = s;
        agent.track(5); // 5 turns of confident pursuit
      }
    }
  }

  Future<void> update({bool noWait = false}) async {
    if (noWait || !msgController.msgWorker.isProcessing || msgController.msgWorker.processNotifier.isCompleted) { //print("Updating...");
      _notify();
    } else { //print("Waiting on message queue...");
      msgController.msgWorker.processNotifier.future.then((v) { //print("Message queue clear, updating...");
        _notify();
      });
    }
  }

  //returns false if player location domain changes
  bool runUntilNextPlayerTurn() { //fm.glog("Running until next turn...");
    final playShip = playerShip;
    final domain = playShip?.loc.domain;
    final pilots = List.of(activePilots); // ← Copy the list
    do {
      for (Pilot p in pilots) { //print("${p.name}'s turn");
        try {
          p.tick();
          Ship? ship = getShip(p);
          if (ship != null && ship.loc.level == playerShip?.loc.level && player.locale is AboardShip) {
            pilotController.npcShipAct(ship);
          }
        } on ConcurrentModificationError {
          glog("Skipping: ${p.name}",error: true);
        }
      }
      auTick++;
      player.tick();
      playShip?.tick(rnd: rnd);
    } while (!player.ready);
    if (playShip != null) {
      final playMap = playShip.loc.level.map; if (playMap is ImpulseMap) {
        final playLevel = playShip.loc.level as ImpulseLevel;
        if (playLevel.sector.hasHaz(Hazard.ion)) playMap.hodgeTick(Hazard.ion, rnd);
      }
      for (final s in _shipRegistry.inLevel(playShip.loc.level).where((s) => s.npc)) playShip.detect(s);
    }
    update();
    return playerShip?.loc.domain == domain;
  }
}

enum DebugLevel {
  Highest(100), Warning(90), Info(80), Fine(50), Finer(25), Debug(10), Lowest(0);
  final int level;
  const DebugLevel(this.level);
}

DebugLevel debugLevel = DebugLevel.Info;

void glog(String msg, {bool error = false, DebugLevel level = DebugLevel.Debug}) {
  if (level.level >= debugLevel.level) print(msg);
  assert(() {
    if (error) throw AssertionError(msg);
    return true;
  }());
}