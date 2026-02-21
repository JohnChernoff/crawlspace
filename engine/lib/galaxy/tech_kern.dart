import 'package:crawlspace_engine/galaxy/kern_field.dart';
import 'system.dart';

class TechKernelField extends KernelField {

  TechKernelField(super.galaxy, {required super.kernel}) {
    for (final s in galaxy.systems) {
      value[s] = 0.0;
    }
  }

  void recompute(Map<System, double> techSources) {
    // reset
    for (final s in galaxy.systems) {
      value[s] = 0.0;
    }
    // accumulate
    for (final entry in techSources.entries) {
      final src = entry.key;
      final strength = entry.value;

      final dist = galaxy.topo.distCache[src]!;
      for (final s in dist.keys) {
        final d = dist[s]!;
        value[s] = (value[s] ?? 0.0) + strength * kernel(d);
      }
    }
  }
}
