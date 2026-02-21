import 'dart:math';
import '../stock_items/species.dart';
import 'kern_field.dart';
import 'system.dart';

class AuthorityKernelField extends KernelField {
  final Faction faction;

  AuthorityKernelField(
      super.galaxy, {
        required this.faction,
        required super.kernel,
      }) {
    for (final s in galaxy.systems) value[s] = 0.0;
  }

  double frontierShape(double x) => pow(x, 1.2).toDouble();

  double trafficPenalty(System s) {
    final t = galaxy.trafficFor(s);
    return 1.0 / (1.0 + t * 0.5);
  }

  double noise(System s) {
    final h = s.hashCode ^ faction.hashCode;
    final r = (h & 0xFFFF) / 0xFFFF;
    return 0.85 + 0.3 * r;
  }

  void recompute(Map<System, double> authoritySources) {
    for (final s in galaxy.systems) value[s] = 0.0;

    for (final entry in authoritySources.entries) {
      final src = entry.key;
      final strength = entry.value;
      final dist = galaxy.topo.distCache[src]!;

      for (final s in dist.keys) {
        final d = dist[s]!;
        final base = min(kernel(d) * strength, 1.0);

        final shaped = pow(base, 1.3).toDouble();
        final penalized = shaped * trafficPenalty(s);
        final finalValue = penalized * noise(s);

        // Soft saturation blend
        value[s] = 1 - (1 - value[s]!) * (1 - finalValue);
      }
    }
  }
}

//enforcementKernel = exp(-d / 8)
// sovereigntyKernel = 1 / (1 + (d/40)^2)
//fedKernel(d) => exp(-d / 20.0); // galactic superpower