import 'package:crawlspace_engine/galaxy/tech_kern.dart';
import '../stock_items/species.dart';
import '../system.dart';
import '../galaxy.dart';
import 'civ_kern.dart';
import 'kern_field.dart';

class CommerceKernelField extends KernelField {
  final CivKernelField civ;
  final TechKernelField tech;

  CommerceKernelField(
      Galaxy galaxy, {
        required this.civ,
        required this.tech,
        required super.kernel,
      }) : super(galaxy);

  void recompute(Map<System, Map<Species, double>> civMix) {
    // reset
    for (final s in galaxy.systems) {
      value[s] = 0.0;
    }

    for (final s in galaxy.systems) {
      final civStrength = civ.val(s);
      final techStrength = tech.val(s);

      // Species commerce bias
      double speciesCommerce = 0.0;
      for (final entry in civMix[s]!.entries) {
        speciesCommerce += entry.value * entry.key.commerce;
      }

      // topology modifier
      final traffic = switch (galaxy.trafficFor(s)) {
        > .75 => 3.0,
        > .25 => 1.0,
        _ => 0.05,
      };

      // Base commerce signal
      final base = civStrength * techStrength * speciesCommerce * traffic;

      // Spread via kernel
      final dist = bfsDistances(s);
      for (final t in dist.keys) {
        final d = dist[t]!;
        value[t] = value[t]! + base * kernel(d);
        if (d > 12) continue; //cap
      }
    }
  }

}
