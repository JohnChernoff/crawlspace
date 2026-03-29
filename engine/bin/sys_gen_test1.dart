import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/rng/star_sys_gen.dart';

void main() {
  debugLevel = DebugLevel.Lowest;
  final g = SystemMetadataGenerator(GridDim(20,20,1),GridDim(20,20,1));
  for (int i=0;i<20;i++) print(g.generate());
}