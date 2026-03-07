import 'package:crawlspace_engine/galaxy/kernels/kern_field.dart';
import 'package:crawlspace_engine/galaxy/system.dart';
import '../../stock_items/corps.dart';

class CorpKernelField extends KernelField {
  final Corporation corp;

  CorpKernelField(super.galaxy, this.corp, {required super.kernel}) {
    for (final s in galaxy.systems) value[s] = 0.0;
  }

  void recompute(Map<System, double> sources) {
    for (final s in galaxy.systems) value[s] = 0.0;
    for (final entry in sources.entries) {
      final dist = galaxy.topo.distCache[entry.key]!;
      for (final s in dist.keys) {
        value[s] = val(s) + kernel(dist[s]!) * entry.value;
      }
    }
  }
}
