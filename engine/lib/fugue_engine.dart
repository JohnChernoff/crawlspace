import 'dart:math';
import 'package:crawlspace_engine/galaxy/hazards.dart';
import 'package:crawlspace_engine/menu.dart';
import 'package:crawlspace_engine/menu_factory.dart';
import 'package:crawlspace_engine/actors/pilot_reg.dart';
import 'package:crawlspace_engine/rng/ship_gen.dart';
import 'package:crawlspace_engine/ship/ship_reg.dart';
import 'package:crawlspace_engine/ship/systems/sensors.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:crawlspace_engine/ship/systems/engines.dart';
import 'package:crawlspace_engine/ship/systems/power.dart';
import 'package:crawlspace_engine/ship/systems/shields.dart';
import 'actors/agent.dart';
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
import 'controllers/xeno_controller.dart';
import 'galaxy/galaxy.dart';
import 'galaxy/geometry/location.dart';
import 'actors/pilot.dart';
import 'actors/player.dart';
import 'rng/rng.dart';
import 'ship/ship.dart';
import 'shop.dart';
import 'stock_items/ship_systems/stock_pile.dart';
import 'stock_items/stock_ships.dart';
import 'galaxy/system.dart';
import 'ship/systems/weapons.dart';

class TextBlock {
  final String txt;
  final bool newline;
  final GameColor color;
  const TextBlock(this.txt,this.color,this.newline);
  static List<TextBlock> letterMenuEntry(String letter, List<TextBlock> blocks,
      {GameColor letterColor = GameColors.white}) => [
    TextBlock("($letter) ", letterColor, false),
    ...blocks,
  ];
}

enum InputMode {
  main(false),
  target(false),
  movementTarget(false),
  menu(true),
  alphaSelect(false);
  final bool showMenu;
  bool get targeting => this == target || this == movementTarget;
  const InputMode(this.showMenu);
}

//cargo systems?  passengers, smuggling? cloaking systems?
//hyperspace landing spot?   Graph not detecting player location?
//TODO: add music, add launchers, one shield/generator per ship, Galaxy menu/refresh log, themed tavern games/activities
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

  final String version = "0.1r";
  final Galaxy galaxy;
  late Player player;
  int numAgents = 3;
  Iterable<Agent> get agents => _pilotRegistry.npcs.whereType<Agent>();
  late Random combatRnd,mapRnd,speciesRnd,aiRnd,effectRnd,itemRnd,audioRnd,eventRnd;
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
  late final XenoController xenoControl = XenoController(this);

  final ShopOptions shopOptions = ShopOptions();

  List<InputMode> _inputStack = [InputMode.main];
  InputMode get inputMode => _inputStack.last;
  void setInputMode(InputMode mode, {noUpdate = false}) { //print("Setting input mode: $mode");
    if (inputMode != mode) {
      _inputStack.add(mode);
      if (!noUpdate) {
        update(dummyMsg: true);
      }
    }
  }
  void exitInputMode() {
    if (_inputStack.length > 1) {
      _inputStack.removeLast();
      update(dummyMsg: true);
    }
  }

  FugueEngine(this.galaxy,String playerName,{seed = 0}) {
    //rnd = Random(seed);
    audioRnd = Random(seed ^0xAAAAAA);
    mapRnd = Random(seed ^0xBBBBBBB);
    speciesRnd = Random(seed ^ 0xC0FFEE);
    aiRnd = Random(seed ^ 0xBADC0DE);
    itemRnd = Random(seed ^ 0xFEED);
    effectRnd = Random(seed ^ 0xBEAD);
    combatRnd = Random(seed ^ 0xABCDEF);
    final farSys = galaxy.farthestSystem(galaxy.fedHomeSystem);
    Ship playShip = Ship("HMS Sebastian",
        shipClass: ShipClass.fromEnum(ShipClassType.barge),
        location: SectorLocation(farSys, farSys.map.rndCoord(mapRnd)),
        generator: PowerGenerator.fromStock(StockSystem.genBasicNuclear),
        sensor: Sensor.fromStock(StockSystem.senFed1),
        impEngine: Engine.fromStock(StockSystem.engBasicFedImp),
        subEngine: Engine.fromStock(StockSystem.engBasicFedSub),
        hyperEngine: Engine.fromStock(StockSystem.engBasicFedHyper),
        shield: Shield.fromStock(StockSystem.shdBasicEnergon),
        //weapons: [Weapon.fromStock(StockSystem.wepFedLaser3),Weapon.fromStock(StockSystem.lchPlasmaCannon)],
        //ammo: {Ammo.fromStock(StockSystem.ammoPlasmaBall) : 50}
        );
    player = Player(playerName,loc: AboardShip(playShip)); //playShip.pilot = player;
    player.system.visited = true;
    addShip(playShip);
    for (final persona in AgentPersonality.values) {
        Ship agentShip = Ship("Agent ${persona.name}",
            shipClass: ShipClass.fromEnum(ShipClassType.galaxy),
            location: SectorLocation(galaxy.fedHomeSystem, galaxy.fedHomeSystem.map.rndCoord(mapRnd)),
            generator: PowerGenerator.fromStock(StockSystem.genBasicNuclear),
            impEngine: Engine.fromStock(StockSystem.engBasicFedImp),
            subEngine: Engine.fromStock(StockSystem.engBasicFedSub),
            hyperEngine: Engine.fromStock(StockSystem.engBasicFedHyper),
            shield: Shield.fromStock(StockSystem.shdBasicEnergon),
            weapons: [Weapon.fromStock(StockSystem.wepPlasmaRay),Weapon.fromStock(StockSystem.lchPlasmaCannon)],
            ammo: {Ammo.fromStock(StockSystem.ammoPlasmaBall) : 250});
        Agent(persona.name,persona,loc: AboardShip(agentShip),galaxy: galaxy);
        addShip(agentShip);
    }
    //print(_shipRegistry.all); //print(_pilotRegistry.all); //print (activePilots);
    msg("Welcome to crawlspace, version $version!  Press 'H' for help, space bar toggles full screen text.");
    msg("You are ${galaxy.maxJumps} jumps away from Mentos.");
    update();
  }

  void addShip(Ship ship) {
    _shipRegistry.add(ship);
    _pilotRegistry.add(ship.pilot);
  }

  void populateSystem(System system, {int? numShips, int maxShips = 8}) {
    numShips ??= (itemRnd.nextDouble() * (galaxy.civKernel.val(system) * maxShips)).floor();
    for (int i = 0; i < numShips; i++) { //print("Populating System: ${system.name}, ships: $numShips");
      final ship = ShipGenerator.generateShip(system, galaxy, itemRnd);
      addShip(ship); //sanityCheck(ship);
    }
    final numPirates = (itemRnd.nextDouble() * ((1-galaxy.civKernel.val(system)) * (maxShips/2))).floor();
    for (int i = 0; i < numPirates; i++) {
      addShip(ShipGenerator.generateShip(system, galaxy, itemRnd, isPirate: true));
    } //print("Adding pirates: $numPirates");
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
      else if (Rng.biasedRndInt(eventRnd,mean: 1, min: 0, max: 5) <= player.broadcasts) {
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
      if (eventRnd.nextInt(100) > (invert ? 100 - player.techLevel(galaxy) : player.techLevel(galaxy))) return false;
    }
    return true;
  }

  bool fedCheck(int passes, {bool invert = false}) {
    for (int i=0;i<passes;i++) {
      if (eventRnd.nextInt(100) > (invert ? 100 - player.fedLevel(galaxy) : player.fedLevel(galaxy))) return false;
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

  bool agentAt(System system) => _pilotRegistry.npcs.any((p) => p is Agent && p.system == system);
  AgentSystemReport agentReport(System s) {
    for (final agent in agents) {
      final report = agent.playerReportFor(s);
      if (report == AgentSystemReport.current) return AgentSystemReport.current;
      if (report == AgentSystemReport.lastKnown) return AgentSystemReport.lastKnown;
    }
    return AgentSystemReport.none;
  }

  Future<void> update({bool noWait = false, bool dummyMsg = false}) async {
    if (dummyMsg) msgController.addDummyMsg();
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
          p.tick(this);
          Ship? ship = shipRegistry.byPilot(p);
          if (ship != null) {
            final loc = ship.loc;
            if (loc.system == playerShip?.loc.system && player.locale is AboardShip) {
              pilotController.npcShipAct(ship);
            } else if (loc is ImpulseLocation) { //escape impulse
              ship.move(loc, shipRegistry);
            }
          }
        } on ConcurrentModificationError {
          glog("Skipping: ${p.name}",error: true);
        }
      }
      auTick++;
      player.tick(this);
      if (playShip != null) {
        final tickResult = playShip.tick(fm: this);
        if (tickResult.newCell) wakePilot(player);
      }
      //if (playShip != null && playShip.loc is ImpulseLocation) {
      for (final cell in player.loc.map.values) {
        cell.effects.tickAll();
      }//}
    } while (!player.ready);
    if (playShip != null) {
      final loc = playShip.loc; if (loc is ImpulseLocation) {
        if (loc.sectorCell.hasHaz(Hazard.ion)) {
          loc.cell.hodgeTick(Hazard.ion, mapRnd);
        }
      }
      for (final s in _shipRegistry.atDomain(playShip.loc).where((s) => s.npc)) playShip.detect(s);
    }
    update();
    glog("Agents: ${agents.map((a) => '${a.personality.name}@${a.system.name}(${galaxy.topo.distance(a.system, player.system)}j)').join(', ')}",
        level: DebugLevel.Fine);
    return playerShip?.loc.domain == domain;
  }

  void wakePilot(Pilot p) {
    p.auCooldown = 0;
    update();
  }

  void sanityCheck(Ship? ship) {
    if (ship != null) {
      final cell = ship.loc.cell;
      print("ship.loc: ${ship.loc}");
      print("cell.loc: ${cell.loc}");
      print("equal: ${ship.loc == cell.loc}");
      print("atLocation(ship.loc): ${shipRegistry.atLocation(ship.loc)}");
      print("atCell(cell): ${shipRegistry.atCell(cell)}");
    } else {
      print("No ship");
    }
  }

  void msg(String msg) => msgController.addMsg(msg);
  void resultMsg(ResultMessage msg) => msgController.addResultMsg(msg);

}

enum DebugLevel {
  Highest(100), Warning(90), Info(80), Fine(50), Finer(25), Debug(10), Lowest(0);
  final int level;
  const DebugLevel(this.level);
}

DebugLevel debugLevel = DebugLevel.Info;

void glog(String msg, {bool error = false, DebugLevel level = DebugLevel.Info}) {
  if (level.level >= debugLevel.level) print(msg);
  assert(() {
    if (error) throw AssertionError(msg);
    return true;
  }());
}