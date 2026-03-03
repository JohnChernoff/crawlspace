import 'dart:collection';
import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/sub_model.dart';
import 'package:directed_graph/directed_graph.dart';
import 'system.dart';

class GalaxyTopology extends GalaxySubMod {
  final DirectedGraph<System> graph;
  late Map<System, Map<System, int>> distCache;
  late Map<System, double> centrality;
  List<System> get systems => galaxy.systems;

  GalaxyTopology(super.galaxy) : graph = DirectedGraph({}) {
    for (final s in systems) graph.addEdges(s, s.links);
    distCache = {};
    for (final s in systems) distCache[s] = _bfsDistances(s);
    computeCentrality();
  }

  int distance(System a, System b) {
    final dist = distCache[a]?[b];
    if (dist == null) {
      glog("Warning: cannot find distance cache for systems: ${a.name},${b.name}", error: true); //return distCache[a]![b]!;
      return 999999;
    } else return dist;
  }

  void computeCentrality() {
    centrality = {};

    for (final s in systems) {
      final dist = distCache[s]!; // you already have this
      double sum = 0;
      for (final d in dist.values) {
        sum += d;
      }

      final avg = sum / (systems.length - 1);
      centrality[s] = 1.0 / (avg + 1e-6); // avoid div by zero
    }

    // normalize 0..1
    final maxC = centrality.values.reduce(max);
    for (final s in systems) {
      centrality[s] = centrality[s]! / maxC;
    }
  }

  Map<System, int> _bfsDistances(System start) {
    final dist = <System, int>{start: 0};
    final queue = Queue<System>()..add(start);

    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();  // true FIFO
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
