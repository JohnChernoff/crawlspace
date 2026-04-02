import 'package:crawlspace_engine/stock_items/species.dart';
import 'geometry/grid.dart';
import 'geometry/object.dart';

class Outpost extends SpaceEnvironment {
  Faction owner;
  double mass = 1000;
  Outpost(this.owner,super.name, super.fedLvl, super.techLvl);
}

