import 'dart:math';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:directed_graph/directed_graph.dart';

import 'descriptors.dart';
import 'fugue_engine.dart';
import 'name_generator.dart';
import 'planet.dart';
import 'rng.dart';
import 'system.dart';

class Galaxy {
  static const int density = 25;
  static const int maxSystems = 250;
  static const int avgPlanets = 3, maxPlanets = 6;
  static const int avgLinks = 3, maxLinks = 9;
  DirectedGraph<System> systemGraph = DirectedGraph({});
  final allSpecies = StockSpecies.values.map((s) => s.species).toList();
  Random rnd;
  String name;
  List<System> systems = [];
  NameGenerator nameGenerator;
  Planet homeWorld = Planet("Xaxle", 100, 100, DistrictLvl.heavy, DistrictLvl.heavy, DistrictLvl.heavy, PlanetAge.established, EnvType.earthlike, Goods.soylentPuce);
  late System homeSystem;
  late int maxJumps;
  late Map<System, Map<System, int>> _distCache;

  Galaxy(this.name, {int? seed}) : rnd = seed != null ?  Random(seed) : Random(), nameGenerator = NameGenerator(seed ?? 1) {
    homeSystem = System("Mentos", StellarClass.K, 100, 100, [homeWorld], rnd, connected: true, homeworld: StockSpecies.humanoid.species);
    systems.add(homeSystem);
    final t0 = DateTime.now();
    createMap();
    final t1 = DateTime.now();
    glog("Galaxy gen took ${t1.difference(t0).inMilliseconds} ms",level: DebugLevel.Highest);
    for (System system in systems) {
      system.updateLevels(rnd);
    }
    getRandomLinkableSystem(homeSystem)?.starOne = true;
    getRandomLinkableSystem(homeSystem)?.blackHole = true;
    maxJumps = graphDistance(farthestSystem(homeSystem), homeSystem);
  }

  void createMap() {
    while (systems.length < maxSystems) {
      int n = Rng.biasedRndInt(rnd,mean: avgPlanets, min: 0, max: maxPlanets);
      String name;
      do { name = nameGenerator.generateSystemName(); }
      while (systems.where((sys) => sys.name == name).isNotEmpty);
      int fedLvl = rnd.nextInt(100);
      int techLvl = rnd.nextInt(100);
      System system = System(name,getRndStellarClass(),fedLvl,techLvl,
          generatePlanets(n,fedLvl, techLvl),rnd,traffic: getRndTrafficLvl());
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

    for (final sys in systems) {
      systemGraph.addEdges(sys, sys.links);
    }
    buildDistanceCache();
    assignHomeworlds();
  }

  System farthestSystem(System s) {
    return systems.reduce((a, b) =>
    (_distCache[s]![a]! > _distCache[s]![b]!) ? a : b);
  }

  int discoveredSystems() => systems.where((s) => s.visited).length;

  System getRandomSystem({Iterable<System> excludeSystems = const [],bool? connected}) {
    Iterable<System> sysList = systems.where((sys) =>
    (connected == null || sys.connected == connected) && !excludeSystems.contains(sys));
    if (sysList.isEmpty) return systems.first;
    return sysList.elementAt(rnd.nextInt(sysList.length));
  }

  System? getRandomLinkableSystem(System sys, {bool ignoreTraffic = false}) {
    Iterable<System> linkableSystems = systems.where((s) => s != sys && !s.links.contains(sys) && s.links.length < maxLinks && s.traffic == TrafficLvl.hub);
    if (linkableSystems.isEmpty || rnd.nextInt(100) < 33 || ignoreTraffic) {
      linkableSystems = systems.where((s) => s != sys && !s.links.contains(sys) && s.links.length < maxLinks && s.traffic != TrafficLvl.culDeSac);
    }
    if (linkableSystems.isEmpty) return null;
    return linkableSystems.elementAt(rnd.nextInt(linkableSystems.length));
  }

  TrafficLvl getRndTrafficLvl() {
    return switch(rnd.nextInt(100)) {
      > 95 => TrafficLvl.culDeSac,
      < 10 => TrafficLvl.hub,
      int() => TrafficLvl.normal,
    };
  }

  DistrictLvl getRndDistrictLvl() {
    int n = rnd.nextInt(DistrictLvl.values.length);
    return DistrictLvl.values.elementAt(n);
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

  Planet createPlanet(int sysFed, int sysTech) {
    return Planet(nameGenerator.generatePlanetName(),
        Rng.biasedRndInt(rnd,mean: sysFed, min: 0, max: 100),
        Rng.biasedRndInt(rnd,mean: sysTech, min: 0, max: 100),
        getRndDistrictLvl(),getRndDistrictLvl(),getRndDistrictLvl(),
        PlanetAge.values.elementAt(rnd.nextInt(PlanetAge.values.length)),
        EnvType.values.elementAt(rnd.nextInt(EnvType.values.length)),
        Goods.values.elementAt(rnd.nextInt(Goods.values.length)));
  }

  List<Planet> generatePlanets(int numPlanets, int sysFed, int sysTech) {
    List<Planet> planList = [];
    for (int i=0;i<numPlanets;i++) {
      planList.add(createPlanet(sysFed,sysTech));
    }
    return planList;
  }

  int graphDistance(System a, System b) {
    final path = systemGraph.shortestPath(a, b); //TODO: use cache
    return path.isEmpty ? 999999 : path.length;
  }

  void assignHomeworlds() {
    final homeSystems = <System>[homeSystem];

    for (final species in allSpecies.skip(1)) {
      final candidates = systems.where((s) => s.homeworld == null).toList();

      // Store (system, minDistance)
      final best = <(System, int)>[];

      for (final c in candidates) {
        final d = homeSystems
            .map((h) => _distCache[h]?[c] ?? 999999)
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
      .map((h) => graphDistance(h, system))
      .reduce(min);

  System findHomeworld(Species s) => systems.firstWhere((system) => system.homeworld == s);

  Map<Species,double> populationMix(System s) {
    final raw = <Species,double>{};
    for (final sp in allSpecies) {
      raw[sp] = exp(-graphDistance(findHomeworld(sp), s) / sp.range) * sp.propagation;
    }
    return normalize(raw);
  }

  void buildDistanceCache() {
    _distCache = {};
    for (final s in systems) {
      _distCache[s] = _bfsDistances(s);
    }
  }

  Map<System, int> _bfsDistances(System start) {
    final dist = <System, int>{start: 0};
    final queue = <System>[start];

    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      final d = dist[cur]! + 1;

      for (final n in cur.links) {
        if (!dist.containsKey(n)) {
          dist[n] = d;
          queue.add(n);
        }
      }
    }
    return dist;
  }

}




