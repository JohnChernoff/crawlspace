import 'package:collection/collection.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';
import '../../item.dart';
import '../geometry/location.dart';
import '../system.dart';

class ItemRegistry<T extends Item<L>, L extends SpaceLocation> extends OmniRegistry<T,L> {
  MapEntry<L, T> nearestItem(System sys, Galaxy galaxy) {
    final entry = all
        .sorted((a, b) => galaxy.topo
        .distance(a.value.system, sys)
        .compareTo(galaxy.topo.distance(b.value.system, sys)))
        .first;
    return MapEntry(entry.value, entry.key);
  }
}
