import 'dart:math';
import 'package:crawlspace_engine/galaxy/fed_model.dart';
import 'package:crawlspace_engine/galaxy/flow_model.dart';
import 'package:crawlspace_engine/galaxy/topology.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'flow_field.dart';
import 'fugue_engine.dart';
import 'galaxy/auth_kern.dart';
import 'galaxy/civ_kern.dart';
import 'galaxy/civ_model.dart';
import 'galaxy/comm_kern.dart';
import 'galaxy/heat_model.dart';
import 'galaxy/tech_kern.dart';
import 'name_generator.dart';
import 'planet.dart';
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
  late Planet fedHomeWorld;
  late System fedHomeSystem, fed1,fed2,fed3;
  late int maxJumps;
  Map<System,double> hazardField = {};
  final Map<String, FlowField> flowFields = {};
  FlowField<T> field<T>(String name) => flowFields[name] as FlowField<T>;
  final flowScheduler = FlowScheduler();
  double fedDecay(System s, double v) => v * 0.999;
  double tradeDecay(System s, double v) => v * 0.995;
  double rumorDecay(System s, double v) => v * 0.97;
  late FlowField<List<double>> civField;
  late GalaxyTopology topo;
  late CivModel civ;
  late HeatModel heat;
  late FederationModel fedMod;
  late FlowManager flow;
  late CivKernelField civKernel;
  late TechKernelField techKernel;
  late CommerceKernelField commerceKernel;
  late AuthorityKernelField fedAuthority;
  double fedKernel(int d) => exp(-d / 6.0);      // soft control gradient
  double harshFed(int d) => 1 / (1 + d * d);     // sharp jurisdiction zones
  double imperial(int d) => exp(-d / 12.0);      // huge empires
  //final SpeciesRegistry speciesiRegistry = SpeciesRegistry(StockSpecies.values.map((s) => s.species).toList());

  Galaxy(this.name, {int? seed}) : rnd = seed != null ?  Random(seed) : Random(), nameGenerator = NameGenerator(seed ?? 1) {
    fedHomeWorld = Planet("Xaxle", 1, 1, rnd, population: 1, industry: 1, commerce: 1);
    fedHomeSystem = System("Mentos", StellarClass.K, rnd, connected: true, homeworld: StockSpecies.humanoid.species,
        trafficGenHint: TrafficGenHint.hub);
    fedHomeSystem.planets.add(fedHomeWorld);
    fed1 = System("Movelia", StellarClass.K, rnd, connected: true, homeworld: StockSpecies.humanoid.species,
        trafficGenHint: TrafficGenHint.hub);
    fed2 = System("Sargon", StellarClass.K, rnd, connected: true, homeworld: StockSpecies.humanoid.species,
        trafficGenHint: TrafficGenHint.normal);
    fed3 = System("Javalix", StellarClass.K, rnd, connected: true, homeworld: StockSpecies.humanoid.species,
        trafficGenHint: TrafficGenHint.culDeSac);
    systems.add(fedHomeSystem);
    systems.addAll([fed1,fed2,fed3]);

    final t0 = DateTime.now(); createMap(); final t1 = DateTime.now();
    glog("Galaxy gen took ${t1.difference(t0).inMilliseconds} ms",level: DebugLevel.Highest);

    topo = GalaxyTopology(systems);

    assignHomeworlds();
    civ = CivModel(this, allSpecies);
    civ.computeCivFields(); //civ.calcMacro();
    computeKernels();
    initFlowFields();

    //for (System system in systems) system.updateLevels(this,rnd);
    getRandomLinkableSystem(fedHomeSystem)?.starOne = true;
    getRandomLinkableSystem(fedHomeSystem)?.blackHole = true;
    maxJumps = topo.distance(farthestSystem(fedHomeSystem), fedHomeSystem);
  }

  void createMap() {
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
    //for (final sys in systems) { topo.graph.addEdges(sys, sys.links); }
  }

  void tickFlow() {
    for (final name in flowFields.keys) {
      if (flowScheduler.shouldTick(name)) {
        flowFields[name]!.tick();
      }
    }
  }

  void registerFlowField(String name, FlowField field) {
    flowFields[name] = field;
  }

  void initFlowFields() { ////registerFlowField("trade", FlowField(this,DoubleOps(),null));
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
    //registerFlowField("civFlow", CivFlowField(this, speciesiRegistry));

    flowScheduler.register("rumors", 1, rnd);     // every turn
    flowScheduler.register("fedSurveillance", 10, rnd); // slower
    //flowScheduler.register("trade", 100, rnd);   // very slow
    //flowScheduler.register("civFlow", 50, rnd); // VERY slow

  }

  void computeKernels() {
    civKernel = CivKernelField(this, kernel: (d) => exp(-d / 4.0));
    civKernel.recompute(allSpecies.map(findHomeworld));

    techKernel = TechKernelField(this, kernel: (d) => exp(-d / 6.0));
    techKernel.recompute(buildTechSources());

    commerceKernel = CommerceKernelField(
      this,
      civ: civKernel,
      tech: techKernel,
      kernel: (d) => exp(-d / 5.0),
    );
    commerceKernel.recompute(civ.civIntensity);

    fedAuthority = AuthorityKernelField(
      this,
      faction: factions.first,
      kernel: fedKernel,
    );

    fedAuthority.recompute({
      fedHomeSystem: 1.0,
      fed1: 1.0,
      fed2: 0.4,
      fed3: 0.2,
    });
  }

  double trafficFor(System s) {
    final c = commerceKernel.val(s);
    final cent = topo.centrality[s]!;
    return pow(c * cent, 0.7).toDouble();
  }

  String trafficGlyph(System s) {
    final t = trafficFor(s);
    if (t > 0.8) return "█";
    if (t > 0.5) return "▓";
    if (t > 0.2) return "▒";
    return "░";
  }

  System farthestSystem(System s) {
    return systems.reduce((a, b) =>
    ((topo.distance(s,a) > topo.distance(s, b)) ? a : b));
  }

  int discoveredSystems() => systems.where((s) => s.visited).length;

  System getRandomSystem({Iterable<System> excludeSystems = const [],bool? connected}) {
    Iterable<System> sysList = systems.where((sys) =>
    (connected == null || sys.connected == connected) && !excludeSystems.contains(sys));
    if (sysList.isEmpty) return systems.first;
    return sysList.elementAt(rnd.nextInt(sysList.length));
  }

  System? getRandomLinkableSystem(System sys, {bool ignoreTraffic = false}) {
    Iterable<System> linkableSystems = systems
        .where((s) => s != sys && !s.links.contains(sys) && s.links.length < maxLinks &&
        s.trafficGenHint == TrafficGenHint.hub);
    if (linkableSystems.isEmpty || rnd.nextInt(100) < 33 || ignoreTraffic) {
      linkableSystems = systems.where((s) => s != sys && !s.links.contains(sys) && s.links.length < maxLinks
          && s.trafficGenHint != TrafficGenHint.culDeSac);
    }
    if (linkableSystems.isEmpty) return null;
    return linkableSystems.elementAt(rnd.nextInt(linkableSystems.length));
  }

  TrafficGenHint getRndTrafficLvl() {
    return switch(rnd.nextInt(100)) {
      > 95 => TrafficGenHint.culDeSac,
      < 10 => TrafficGenHint.hub,
      int() => TrafficGenHint.normal,
    };
  }

  DistrictLvl getRndDistrictLvl() {
    int n = rnd.nextInt(DistrictLvl.values.length);
    return DistrictLvl.values.elementAt(n);
  }

  LawLevel law(System s) {
    final a = fedAuthority.val(s);
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

      // Store (system, minDistance)
      final best = <(System, int)>[];

      for (final c in candidates) {
        final d = homeSystems
            .map((h) => topo.distance(h,c))
            .reduce(min);

        if (best.length < 5) {
          best.add((c, d));
          best.sort((a, b) => a.$2.compareTo(b.$2));
        } else {
          final worst = best.last;
          final worstDist = worst.$2;

          if (d < worstDist) {
            best.removeLast();
            best.add((c, d));
            best.sort((a, b) => a.$2.compareTo(b.$2));
          }
        }
      }

      final chosen = best[rnd.nextInt(best.length)];
      chosen.$1.homeworld = species;
      homeSystems.add(chosen.$1);

      glog("Adding home system: ${species.name} -> ${chosen.$1.name}");
    }
  }

  int minDist(Iterable<System> systems, System system) => systems
      .map((h) => topo.distance(h, system))
      .reduce(min);

  System findHomeworld(Species s) => systems.firstWhere((system) => system.homeworld == s);

  void playerCrime(System s, double loudness) {
    flowFields["rumors"]!.value[s] =
        flowFields["rumors"]!.val(s) + loudness;
  }

  void dumpField(String name, {int top = 10}) {
    final field = flowFields[name]!;
    systems
        .toList()
      ..sort((a,b)=>field.value[b]!.compareTo(field.value[a]!))
      ..take(top)
          .forEach((s)=>print("$name ${s.name}: ${field.val(s).toStringAsFixed(2)}"));
  }

  void tickSim() {
    flow.tick();
    heat.decayHeat();
  }

  void tickCentury() {
    civ.computeCivFields();
    fedMod.computeFedPressure();
  }

  Map<System, double> buildTechSources() {
    final sources = <System, double>{};

    for (final sp in allSpecies) {
      final home = findHomeworld(sp);
      sources[home] = sp.tech;
    }

    return sources;
  }

  //crimeEvent(system) { authorityShockSources[system] += 10.0; }

  double patrolChance(System s) {
    return fedAuthority.val(s) * techKernel.val(s);
  }

  double pursuitIntensity(System s) {
    return fedAuthority.val(s) * commerceKernel.val(s);
  }

  double rumorSpread(System s) {
    return commerceKernel.val(s) * (1 + fedAuthority.val(s));
  }

  void dumpCommerce() {
    systems
        .toList()
      ..sort((a,b)=> commerceKernel.val(b).compareTo(commerceKernel.val(a)))
      ..take(10)
          .forEach((s)=> print("${s.name}: ${commerceKernel.val(s).toStringAsFixed(2)}"));
  }

  double marketSize(System s) =>
      commerceKernel.val(s) * civKernel.val(s);

  double localSecurity(System s) =>
      fedAuthority.val(s) * commerceKernel.val(s);
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