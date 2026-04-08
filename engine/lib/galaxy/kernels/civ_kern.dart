import 'dart:math';

import 'package:crawlspace_engine/galaxy/kernels/kern_field.dart';
import '../system.dart';

class CivKernelField extends KernelField {

  CivKernelField(super.galaxy, {required super.kernel}) {
    for (final s in galaxy.systems) value[s] = 0.0;
  }

  void recompute(Iterable<System> sources) {
    for (final s in galaxy.systems) value[s] = 0.0;

    for (final src in sources) {
      final dist = galaxy.topo.distCache[src]!;
      for (final s in dist.keys) {
        final d = dist[s]!;
        value[s] = val(s) + kernel(d);
      }
    }

    // Normalize to 0–1 across all systems
    final maxVal = value.values.reduce(max);
    if (maxVal > 0) {
      for (final s in galaxy.systems) {
        value[s] = (value[s]! / maxVal).clamp(0.0, 1.0);
      }
    }

    final mean = value.values.reduce((a, b) => a + b) / value.length;
    final scale = 0.4 / mean; // target mean of 0.4
    for (final s in galaxy.systems) {
      value[s] = (value[s]! * scale).clamp(0.0, 1.0);
    }
  }
}

/*
  double civKernel(int d) => exp(-d / 4.0);
  double harsh(int d) => 1 / (1 + d*d);
  double soft(int d) => exp(-d / 8.0);
  double frontierBoost(int d) => pow(exp(-d / 6.0), 0.7).toDouble();
  double shaped(double x) => pow(x, 0.7) as double; // boost outskirts
 */