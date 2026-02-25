import 'dart:math';
import 'package:crawlspace_engine/galaxy/fed_model.dart';
import 'package:crawlspace_engine/galaxy/flow_model.dart';
import 'package:crawlspace_engine/galaxy/topology.dart';
import 'package:crawlspace_engine/location.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'flow_field.dart';
import '../fugue_engine.dart';
import 'auth_kern.dart';
import 'civ_kern.dart';
import 'civ_model.dart';
import 'comm_kern.dart';
import 'heat_model.dart';
import 'tech_kern.dart';
import '../name_generator.dart';
import '../planet.dart';
import 'system.dart';

enum LawLevel { core, regulated, frontier, lawless }

class Galaxy {
  static const int density = 25;
  static const int maxSystems = 250;
  static const int avgPlanets = 3, maxPlanets = 6;
  static const int avgLinks = 3, maxLinks = 9;
  final allSpecies = StockSpecies.values.map((s) => s.species).toList();
  Random rnd;
  String name;
  List<System> systems = [];
  NameGenerator nameGenerator;
  //late Planet fedHomeWorld;
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
  late CivKernelField civKernel;
  late TechKernelField techKernel;
  late CommerceKernelField commerceKernel;
  late AuthorityKernelField fedKernel;

  Galaxy(this.name, {int? seed}) : rnd = seed != null ?  Random(seed) : Random(), nameGenerator = NameGenerator(seed ?? 1) {
    fedHomeSystem = System("Mentos", StellarClass.K, rnd, connected: true, homeworld: StockSpecies.humanoid.species,
        trafficGenHint: TrafficGenHint.hub);
    fed1 = System("Movelia", StellarClass.K, rnd, connected: true, trafficGenHint: TrafficGenHint.hub);
    fed2 = System("Sargon", StellarClass.K, rnd, connected: true, trafficGenHint: TrafficGenHint.normal);
    fed3 = System("Javalix", StellarClass.K, rnd, connected: true, trafficGenHint: TrafficGenHint.culDeSac);
    systems.addAll([fedHomeSystem,fed1,fed2,fed3]);

    final t0 = DateTime.now(); _createMap(); final t1 = DateTime.now();
    glog("Galaxy gen took ${t1.difference(t0).inMilliseconds} ms",level: DebugLevel.Highest);

    topo = GalaxyTopology(this);
    assignHomeworlds();
    civMod = CivModel(this, allSpecies);
    computeKernels();
    initFlowFields();
    fedMod = FederationModel(this);
    heatMod = HeatModel(this);
    getRandomLinkableSystem(fedHomeSystem)?.starOne = true;
    getRandomLinkableSystem(fedHomeSystem)?.blackHole = true;

    for (final s in systems) {
      s.map = s.createSystemMap(8,.02,.01,.001,rnd);
      if (s.homeworld != null) {
        final homeWorld = Planet(s.homeworld!.homeWorld, 1, 1, rnd,
            locale: SystemLocation(s, s.map.rndCell(rnd)), population: 1, industry: 1, commerce: 1);
        s.addPlanets(this, rnd, pList: [homeWorld]);
      } else {
        s.addPlanets(this, rnd);
      }
    }
    maxJumps = topo.distance(farthestSystem(fedHomeSystem), fedHomeSystem);
  }

  void _createMap() {
    while (systems.length < maxSystems) {
      String name;
      do { name = nameGenerator.generateSystemName(); }
      while (systems.where((sys) => sys.name == name).isNotEmpty);
      System system = System(name,getRndStellarClass(),rnd);
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

  void initFlowFields() { //
    final rumorPreset = FlowPreset<double>(
      edgeWeight: (a,b) => a.trafficGenHint == TrafficGenHint.hub ? 2.0 : 1.0, //TODO: use links directly or trafficAt
      decay: (s,v) => v * 0.97,
      source: (_) => 0.0,
    );

    final fedPreset = FlowPreset<double>(
      edgeWeight: (a,b) => 1.0,
      decay: (s,v) => v * 0.999,
      source: (s) => fedMod.fedPressure[s]! * 0.01,
    );

    registerFlowField("rumors", FlowField(this,DoubleOps(),rumorPreset));
    registerFlowField("fedSurveillance", FlowField(this,DoubleOps(),fedPreset));
    //registerFlowField("trade", FlowField(this,DoubleOps(),null));
    //registerFlowField("civFlow", CivFlowField(this, speciesiRegistry));

    flowScheduler.register("rumors", 1, rnd);     // every turn
    flowScheduler.register("fedSurveillance", 10, rnd); // slower
    //flowScheduler.register("trade", 100, rnd);   // very slow
    //flowScheduler.register("civFlow", 50, rnd); // VERY slow

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

  void assignHomeworlds() {
    final homeSystems = <System>[fedHomeSystem];

    for (final species in allSpecies.skip(1)) {
      final candidates = systems.where((s) => s.homeworld == null).toList();

      (System, int)? best;

      for (final c in candidates) {
        final d = homeSystems
            .map((h) => topo.distance(h, c))
            .reduce(min);

        if (best == null || d > best.$2) {
          best = (c, d);
        }
      }

      best!.$1.homeworld = species;
      homeSystems.add(best.$1);
      glog("Adding home system: ${species.name} -> ${best.$1.name}");
    }
  }

  int minDist(Iterable<System> systems, System system) => systems
      .map((h) => topo.distance(h, system))
      .reduce(min);


  void playerCrime(System s, double loudness) {
    flowFields["rumors"]!.value[s] = flowFields["rumors"]!.val(s) + loudness;
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

  System findHomeworld(Species s) => systems.firstWhere((system) => system.homeworld == s);

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

/*
  Map<Species,double> populationMix(System s) {
    final raw = <Species,double>{};
    for (final sp in allSpecies) {
      raw[sp] = exp(-topo.distance(findHomeworld(sp), s) / sp.range) * sp.propagation;
    }
    return normalize(raw);
  }

  List<double> speciesOneHot(Species sp) {
    final v = List<double>.filled(allSpecies.length, 0.0);
    v[allSpecies.indexOf(sp)] = 1.0;
    return v;
  }
 */

//crimeEvent(system) { authorityShockSources[system] += 10.0; }

//final SpeciesRegistry speciesRegistry = SpeciesRegistry(StockSpecies.values.map((s) => s.species).toList());
//late FlowField<List<double>> civField;

//PiracyKernelField
//piracy = commerceLevel * (1 - fedLevel)

//double fedStdKernel(int d) => exp(-d / 6.0);      // soft control gradient
//double harshFed(int d) => 1 / (1 + d * d);     // sharp jurisdiction zones
//double imperial(int d) => exp(-d / 12.0);      // huge empires

/*
  TrafficGenHint getRndTrafficLvl() {
    return switch(rnd.nextInt(100)) {
      > 95 => TrafficGenHint.culDeSac,
      < 10 => TrafficGenHint.hub,
      int() => TrafficGenHint.normal,
    };
  }
 */