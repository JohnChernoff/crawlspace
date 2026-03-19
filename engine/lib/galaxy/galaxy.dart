import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/galaxy/models/corp_model.dart';
import 'package:crawlspace_engine/galaxy/models/fed_model.dart';
import 'package:crawlspace_engine/galaxy/models/flow_model.dart';
import 'package:crawlspace_engine/galaxy/models/topology.dart';
import 'package:crawlspace_engine/galaxy/models/trade_model.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'flow_field.dart';
import '../fugue_engine.dart';
import 'kernels/auth_kern.dart';
import 'kernels/civ_kern.dart';
import 'models/civ_model.dart';
import 'kernels/comm_kern.dart';
import 'models/heat_model.dart';
import 'kernels/tech_kern.dart';
import '../rng/name_gen.dart';
import 'planet.dart';
import 'system.dart';

/*
  GALAXY SIMULATION LAYERS

  STATIC (computed once at gen, changes only on tickCentury):
    fedMod.fedPressure    - raw distance from Mentos; is the Fed present at all?
    fedKernel             - shaped Fed influence across whole galaxy; how much does it matter?
    techKernel            - technological development level by region
    commerceKernel        - trade and economic activity by region
    civKernel             - total civilisation density
    civMod.civIntensity   - species population mix per system (who lives here?)
    civMod.politicalMap   - inter-species relationships

  DYNAMIC (ticking forward each turn):
    flowFields["fedSurveillance"]  - active patrol/surveillance responding to events
    flowFields["rumors"]           - information spreading through trade networks
    heatMod.playerHeatMap          - player's personal notoriety per system

  DERIVED (combine static + dynamic for live game state):
    galaxy.fedLevel(s)     - fedKernel * 0.7 + surveillance * 0.3
    galaxy.rumorLevel(s)   - commerceKernel * 0.5 + rumors * 0.5
    galaxy.law(s)          - LawLevel derived from fedLevel
    galaxy.patrolChance(s) - fedLevel * techKernel
*/

enum LawLevel { core, regulated, frontier, lawless }

class Galaxy {
  static const int density = 25;
  static const int maxSystems = 360;
  static const int avgPlanets = 3, maxPlanets = 6;
  static const int avgLinks = 3, maxLinks = 9;
  final allSpecies = StockSpecies.values.map((s) => s.species).toList();
  Random rnd;
  String name;
  List<System> systems = [];
  NameGenerator nameGenerator;
  late System fedHomeSystem, fed1,fed2,fed3;
  late int maxJumps;
  Map<System,double> hazardField = {};
  final Map<String, FlowField> flowFields = {};
  FlowField<T> field<T>(String name) => flowFields[name] as FlowField<T>;
  final flowScheduler = FlowScheduler();
  double fedDecay(System s, double v) => v * 0.999;
  double tradeDecay(System s, double v) => v * 0.995;
  double rumorDecay(System s, double v) => v * 0.97;
  late FlowManager flowMgr;
  late GalaxyTopology topo;
  late CivModel civMod;
  late HeatModel heatMod;
  late FederationModel fedMod;
  late TradeModel tradeMod;
  late CorpModel corpMod;
  late CivKernelField civKernel;
  late TechKernelField techKernel;
  late CommerceKernelField commerceKernel;
  late AuthorityKernelField fedKernel;
  late RegModel rm;
  PlanetRegistry get planets => rm.planets;
  ShipRegistry get ships => rm.ships;
  ItemRegistry get items => rm.items;
  PilotRegistry get pilots => rm.pilots;
  bool formed = false;

  // Static (computed at gen, recomputed on tickCentury)
  //late TradeKernelField supplyField;    // per-commodity supply gradient
  //late TradeKernelField demandField;    // per-commodity demand gradient

// Dynamic (ticking forward)
// flowFields["tradeFlow"] — actual goods moving along routes
// flowFields["priceSignal"] — price information diffusing through gossip

  Galaxy(this.name, {int? seed}) :
        rnd = seed != null ?  Random(seed) : Random(),
        nameGenerator = NameGenerator(seed ?? 1) {
    fedHomeSystem = System("Mentos", StellarClass.K, rnd, connected: true, trafficGenHint: TrafficGenHint.hub, map: EmptySector());
    fed1 = System("Movelia", StellarClass.K, rnd, connected: true, trafficGenHint: TrafficGenHint.hub, map: EmptySector());
    fed2 = System("Sargon", StellarClass.K, rnd, connected: true, trafficGenHint: TrafficGenHint.normal, map: EmptySector());
    fed3 = System("Javalix", StellarClass.K, rnd, connected: true, trafficGenHint: TrafficGenHint.culDeSac, map: EmptySector());
    systems.addAll([fedHomeSystem,fed1,fed2,fed3]);

    final t0 = DateTime.now(); _createMap(); final t1 = DateTime.now();
    glog("Galaxy gen took ${t1.difference(t0).inMilliseconds} ms",level: DebugLevel.Highest);

    rm = RegModel(this);
    topo = GalaxyTopology(this);
    civMod = CivModel(this);
    civMod.generatePolitics(rnd);
    civMod.debugPrintPoliticalMap();
    computeKernels();
    initFlowFields();
    corpMod = CorpModel(this);
    fedMod = FederationModel(this);
    heatMod = HeatModel(this);
    getRandomLinkableSystem(fedHomeSystem)?.starOne = true;
    getRandomLinkableSystem(fedHomeSystem)?.blackHole = true;

    for (final s in systems) {
      s.map = s.createSystemMap(.02,.01,.001,this);
      final species = getHomeworldSpecies(s);
      if (species != null) {
        final homeWorld = Planet(species.homeWorld, 1, 1, rnd, homeworld: true, species: species,
            locale: planets.randomUnoccupiedLocation(s,rnd),
            population: 1, industry: 1, commerce: 1);
        planets.register(homeWorld, homeWorld.loc);
      }
      s.generatePlanets(this, rnd);
    }

    tradeMod = TradeModel(this);
    maxJumps = topo.distance(farthestSystem(fedHomeSystem), fedHomeSystem);
    formed = true;
  }

  Iterable<System> territory(Species species) => systems.where((s) => civMod.dominantSpecies(s) == species);

  SectorLocation rndLoc(Random rnd) {
    final system = getRandomSystem();
    final rndCoord = system.map.rndCoord(rnd);
    return SectorLocation(system,rndCoord);
  }

  void _createMap() {
    while (systems.length < maxSystems) {
      String name;
      do { name = nameGenerator.generateSystemName(); }
      while (systems.where((sys) => sys.name == name).isNotEmpty);
      System system = System(name,getRndStellarClass(),rnd, map: EmptySector());
      systems.add(system);
    }
    for (System system in systems) {
      while (!system.addLink(getRandomSystem(excludeSystems: [system]),update: false)) {}
    }
    for (System system in systems) {
      if (!system.connected) { //print("Connecting unconnected system: ${system.name}");
        system.addLink(getRandomSystem(excludeSystems:[system],connected: true),update: true);
      }
    }
  }

  void registerFlowField(String name, FlowField field) {
    flowFields[name] = field;
  }

  void initFlowFields() {
    final rumorPreset = FlowPreset<double>(
      edgeWeight: (a,b) => a.trafficGenHint == TrafficGenHint.hub ? 2.0 : 1.0, //TODO: use links directly or trafficAt
      decay: (s,v) => v * 0.97,
      source: (_) => 0.0,
    );
    registerFlowField("rumors", FlowField(this,DoubleOps(),rumorPreset));
    flowScheduler.register("rumors", 1, rnd);     // every turn
  }

  void computeKernels() {
    civKernel = CivKernelField(this, kernel: (d) => exp(-d / 4.0));
    civKernel.recompute(allSpecies.map(findHomeworld));

    techKernel = TechKernelField(this, kernel: (d) => exp(-d / 6)); //6
    techKernel.recompute(buildTechSources());

    commerceKernel = CommerceKernelField(
      this,
      civ: civKernel,
      tech: techKernel,
      kernel: (d) => exp(-d / 5), //5
    );
    commerceKernel.recompute(civMod.civIntensity);

    double fedFrontierKernel(int d) => 1 / (1 + pow(d / 20, 2));
    fedKernel = AuthorityKernelField(
      this,
      faction: factions.first,
      kernel: fedFrontierKernel,
    );

    fedKernel.recompute({
      fedHomeSystem: 1.0,
      fed1: 0.7,
      fed2: 0.35,
      fed3: 0.16,
    });
  }

  System getRandomSystem({Iterable<System> excludeSystems = const [],bool? connected}) {
    Iterable<System> sysList = systems.where((sys) =>
    (connected == null || sys.connected == connected) && !excludeSystems.contains(sys));
    if (sysList.isEmpty) return systems.first;
    return sysList.elementAt(rnd.nextInt(sysList.length));
  }

  System? getRandomLinkableSystem(System excludeSystem, {bool ignoreTraffic = false}) {
    Iterable<System> linkableSystems = systems
        .where((s) => s != excludeSystem && !s.links.contains(excludeSystem) && s.links.length < maxLinks &&
        s.trafficGenHint == TrafficGenHint.hub);
    if (linkableSystems.isEmpty || rnd.nextInt(100) < 33 || ignoreTraffic) {
      linkableSystems = systems.where((s) => s != excludeSystem && !s.links.contains(excludeSystem) && s.links.length < maxLinks
          && s.trafficGenHint != TrafficGenHint.culDeSac);
    }
    if (linkableSystems.isEmpty) return null;
    return linkableSystems.elementAt(rnd.nextInt(linkableSystems.length));
  }

  LawLevel law(System s) {
    final a = fedKernel.val(s);
    if (a > 0.75) return LawLevel.core;
    if (a > 0.4) return LawLevel.regulated;
    if (a > 0.15) return LawLevel.frontier;
    return LawLevel.lawless;
  }

  StellarClass getRndStellarClass() {
    final totalWeight = StellarClass.values.fold<int>(0, (sum, sc) => sum + sc.prob);
    final target = rnd.nextInt(totalWeight);
    int cumulative = 0;
    for (final sc in StellarClass.values) {
      cumulative += sc.prob;
      if (target < cumulative) return sc;
    }
    return StellarClass.values.last; // Fallback (should never happen)
  }

  void spreadAssign<T>(List<T> list, Map<T,System> map, List<System> sysList) {
    if (map.isEmpty) {
      glog("Warning: attempting to generate a spread map without an anchor",error: true);
      return;
    }
    for (final t in list.where((k) => !map.containsKey(k))) {
      final candidates = sysList.where((s) => !map.containsValue(s)).toList();
      (System, int)? best;
      for (final c in candidates) {
        final d = map.values
            .map((s) => topo.distance(s, c))
            .reduce(min);

        if (best == null || d > best.$2) {
          best = (c, d);
        }
      }
      map[t] = best!.$1;
    }
    glog("Spread Map: $map",level: DebugLevel.Fine);
  }

  int minDist(Iterable<System> systems, System system) => systems
      .map((h) => topo.distance(h, system))
      .reduce(min);

  void playerCrime(System s, double loudness) {
    flowFields["rumors"]!.value[s] = flowFields["rumors"]!.val(s) + loudness;
    heatMod.leakPlayerHeat(s, loudness);  // also update player heat map
  }

  Map<System, double> buildTechSources() {
    final sources = <System, double>{};
    for (final sp in allSpecies) {
      final home = findHomeworld(sp);
      sources[home] = sp.tech;
    }
    return sources;
  }

  double structuralTraffic(System s) {
    return pow(topo.centrality[s]!, 0.7) as double;
  }

  double economicTraffic(System s) {
    return pow(commerceKernel.val(s), 0.7) as double;
  }

  double trafficFor(System s) {
    return 0.4 * structuralTraffic(s) + 0.6 * economicTraffic(s);
  }

  System farthestSystem(System s) {
    return systems.reduce((a, b) =>
    ((topo.distance(s,a) > topo.distance(s, b)) ? a : b));
  }

  System findHomeworld(Species s) => civMod.homeworlds[s]!;

  Species? getHomeworldSpecies(System s) => civMod.homeworlds.entries.firstWhereOrNull((e) => e.value == s)?.key;

  int discoveredSystems() => systems.where((s) => s.visited).length;

  double patrolChance(System s) {
    return fedKernel.val(s) * techKernel.val(s);
  }

  double pursuitIntensity(System s) {
    return fedKernel.val(s) * commerceKernel.val(s);
  }

  double rumorSpread(System s) {
    return commerceKernel.val(s) * (1 + fedKernel.val(s));
  }

  double marketSize(System s) =>
      commerceKernel.val(s) * civKernel.val(s);

  double localSecurity(System s) =>
      fedKernel.val(s) * commerceKernel.val(s);

  void tickSim() {
    flowMgr.tick();
    heatMod.decayHeat();
  }

  void tickCentury() {
    civMod.computeCivFields();
    fedMod.computeFedPressure();
  }

  void tickFlow() {
    for (final name in flowFields.keys) {
      if (flowScheduler.shouldTick(name)) {
        flowFields[name]!.tick();
      }
    }
  }

  String trafficGlyph(System s) {
    final t = trafficFor(s);
    if (t > 0.8) return "█";
    if (t > 0.5) return "▓";
    if (t > 0.2) return "▒";
    return "░";
  }

  void dumpField(String name, {int top = 10}) {
    final field = flowFields[name]!;
    systems
        .toList()
      ..sort((a,b)=>field.value[b]!.compareTo(field.value[a]!))
      ..take(top)
          .forEach((s)=>print("$name ${s.name}: ${field.val(s).toStringAsFixed(2)}"));
  }

  void dumpCommerce() {
    systems
        .toList()
      ..sort((a,b)=> commerceKernel.val(b).compareTo(commerceKernel.val(a)))
      ..take(10)
          .forEach((s)=> print("${s.name}: ${commerceKernel.val(s).toStringAsFixed(2)}"));
  }
}
