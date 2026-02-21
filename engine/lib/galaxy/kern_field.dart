import 'package:crawlspace_engine/fugue_engine.dart';

import '../flow_field.dart';
import '../galaxy.dart';
import '../system.dart';

abstract class KernelOps<T> extends FlowOps<T> {}

class KernelField {
  final Galaxy galaxy;
  final Map<System, double> value = {};
  final double Function(int d) kernel;

  KernelField(this.galaxy, {required this.kernel});

  double val(System s) {
    if (value.containsKey(s)) {
      return value[s]!;
    }
    else {
      glog("Warning: kernel field not found for system: ${s.name}",error: true);
      return double.infinity;
    }
  }

  Map<System, int> bfsDistances(System start) {
    final dist = <System, int>{};
    final q = <System>[start];
    dist[start] = 0;

    while (q.isNotEmpty) {
      final s = q.removeLast();
      for (final n in s.links) {
        if (!dist.containsKey(n)) {
          dist[n] = dist[s]! + 1;
          q.add(n);
        }
      }
    }
    return dist;
  }
}