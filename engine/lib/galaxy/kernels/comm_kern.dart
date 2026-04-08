import 'dart:math';

import 'package:crawlspace_engine/galaxy/kernels/tech_kern.dart';
import '../../stock_items/species.dart';
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
    for (final s in galaxy.systems) value[s] = 0.0;

    // Accumulate all contributions first
    for (final s in galaxy.systems) {
      final civStrength = civ.val(s);
      final techStrength = tech.val(s);

      double speciesCommerce = 0.0;
      for (final entry in civMix[s]!.entries) {
        speciesCommerce += entry.value * entry.key.commerce;
      }

      final base = pow(civStrength * techStrength * speciesCommerce, .66);
      final traffic = pow(galaxy.structuralTraffic(s), 2);
      final local = base * traffic;

      final dist = galaxy.topo.distCache[s]!;
      for (final t in dist.keys) {
        final d = dist[t]!;
        value[t] = value[t]! + local * kernel(d);
      }
    }

    // Normalize once, after all systems have contributed
    final maxVal = value.values.reduce(max);
    if (maxVal > 0) {
      for (final s in galaxy.systems) value[s] = value[s]! / maxVal;
    }
  }

}

/*

      for (final t in dist.keys) {
        final d = dist[t]!;
        final contrib = local * kernel(d);
        value[t] = 1 - (1 - value[t]!) * (1 - contrib);
      }

      // topology modifier
      //final traffic = switch (galaxy.trafficFor(s)) {> .75 => 3.0, > .25 => 1.0, _ => 0.05,};
      final traffic = pow(galaxy.structuralTraffic(s), 1.2) * 3;

      // Base commerce signal
      final base = pow(civStrength * techStrength * speciesCommerce * traffic, 0.35);

      // Spread via kernel
      final dist = galaxy.topo.distCache[s]!;
      for (final t in dist.keys) {
        final d = dist[t]!;
        value[t] = min(1,value[t]! + (base * kernel(d) * exp(-d/12)));
        //value[t] = value[t]! + base * kernel(d);
      }
 */