import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'system.dart';

class GalaxySubMod {
  Galaxy galaxy;
  List<System> get systems => galaxy.topo.systems;
  int distance(System a, System b) => galaxy.topo.distance(a, b);

  GalaxySubMod(this.galaxy);
}