import 'dart:math';
import '../stock_items/species.dart';
import 'kern_field.dart';
import '../system.dart';

class AuthorityKernelField extends KernelField {
  final Faction faction;

  AuthorityKernelField(
      super.galaxy, {
        required this.faction,
        required super.kernel,
      }) {
    for (final s in galaxy.systems) value[s] = 0.0;
  }

  double frontierShape(double x) => pow(x, 0.65).toDouble();

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
      final dist = bfsDistances(src);

      for (final s in dist.keys) {
        final d = dist[s]!;
        final base = kernel(d) * strength;

        // frontier collapse
        final shaped = frontierShape(base);

        // traffic undermines control
        final penalized = shaped * trafficPenalty(s);

        // patchiness
        final finalValue = penalized * noise(s);

        value[s] = (value[s] ?? 0.0) + finalValue;
      }
    }
  }
}

