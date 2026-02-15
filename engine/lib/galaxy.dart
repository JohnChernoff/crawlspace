import 'dart:math';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:directed_graph/directed_graph.dart';

import 'descriptors.dart';
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

  Galaxy(this.name, {int? seed}) : rnd = seed != null ?  Random(seed) : Random(), nameGenerator = NameGenerator(seed ?? 1) {
    homeSystem = System("Mentos", StellarClass.K, 100, 100, [homeWorld], rnd, connected: true, homeworld: StockSpecies.humanoid.species);
    systems.add(homeSystem);
    createMap();
    for (System system in systems) {
      system.updateLevels(rnd);
    }
    getRandomLinkableSystem(homeSystem)?.starOne = true;
    getRandomLinkableSystem(homeSystem)?.blackHole = true;
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

    assignHomeworlds();
  }

  System farthestSystem(System system) {
    System farthestSystem = system;
    List<System>? maxPath;
    for (System sys in systems) {
      List<System> path = systemGraph.shortestPath(sys, system);
      if (path.length > (maxPath?.length ?? 0)) {
        maxPath = path; farthestSystem = sys;
      }
    }
    return farthestSystem;
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
    final path = systemGraph.shortestPath(a, b);
    return path.isEmpty ? 999999 : path.length;
  }

  void assignHomeworlds() {
    final homeSystems = <System>[homeSystem];

    for (final species in allSpecies.skip(1)) {
      final candidates = systems.where((s) => s.homeworld == null).toList();

      candidates.sort((a, b) =>
          minDist(homeSystems, b).compareTo(minDist(homeSystems, a)));

      final top = candidates.take(5).toList();
      final chosen = top[rnd.nextInt(top.length)];

      chosen.homeworld = species;
      print("Adding home system: ${species.name} -> ${chosen.name}");
      homeSystems.add(chosen);
      chosen.homeworld = species;
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

}




