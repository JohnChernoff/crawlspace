import 'package:crawlspace_engine/stock_items/species.dart';
import 'geometry/location.dart';
import 'geometry/object.dart';

class Outpost extends SpaceEnvironment<ImpulseLocation> {
  Faction owner;
  double mass = 1000;
  Outpost(this.owner,super.name, super.fedLvl, super.techLvl, {required super.locale});
}