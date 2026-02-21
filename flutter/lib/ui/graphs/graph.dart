import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/system.dart';
import 'package:flutter_force_directed_graph/model/config.dart';
import 'package:flutter_force_directed_graph/model/edge.dart';
import 'package:flutter_force_directed_graph/model/graph.dart';
import 'package:flutter_force_directed_graph/model/node.dart';

class FugueGraph {
  late ForceDirectedGraph<System> graph;
  Galaxy galaxy;

  FugueGraph(this.galaxy) {
    graph = ForceDirectedGraph<System>(config: const GraphConfig(
      scaling: 0.05,
      repulsion: 180, //92,
      repulsionRange: 512, //360,
      maxStaticFriction: 36,
      elasticity: .5,
      damping: .9,
    ));
    for (System sys in galaxy.systems) {
      graph.addNode(Node(sys));
    }
    for (System sys in galaxy.systems) {
      for (System link in sys.links) {
        addEdge(sys,link);
      }
    }
  }

  void addEdge(System s1, System s2) {
    Node n1 = graph.nodes.firstWhere((n) => n.data == s1);
    Node n2 = graph.nodes.firstWhere((n) => n.data == s2);
    Edge edge = Edge(n1,n2);
    if (!graph.edges.contains(edge)) {
      graph.addEdge(edge); //print("Adding edge: $edge");
    }
  }
}