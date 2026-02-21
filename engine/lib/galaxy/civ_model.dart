import 'dart:math';
import 'package:crawlspace_engine/galaxy/sub_model.dart';
import '../color.dart';
import '../stock_items/species.dart';
import 'system.dart';

class CivModel extends GalaxySubMod {
  final List<Species> allSpecies;
  Map<System, Map<Species,double>> civIntensity = {};
  Map<System,double> techField = {};
  Map<System,double> commerceField = {};

  CivModel(super.galaxy, this.allSpecies) {
    computeCivFields();
  }

  void computeCivFields() {
    for (final s in systems) {
      civIntensity[s] = {};
      for (final sp in allSpecies) {
        final d = distance(galaxy.findHomeworld(sp), s);
        civIntensity[s]![sp] = exp(-d / (sp.propagation * 10)) * sp.populationDensity;
      }
      civIntensity[s] = normalize(civIntensity[s]!);
    }
  }

  GameColor systemSpeciesColor(System s) {
      final mix = civIntensity[s];
      if (mix == null || mix.isEmpty) return GameColors.black;

      double r = 0, g = 0, b = 0;
      for (final e in mix.entries) {
        final col = e.key.graphCol;
        final w = e.value;
        r += col.r * w;
        g += col.g * w;
        b += col.b * w;
      }

      // diversity metric (Shannon-ish)
      double diversity = 0;
      for (final w in mix.values) {
        if (w > 0) diversity -= w * log(w);
      }
      diversity = diversity.clamp(0, 2.0);

      // boost saturation
      final boost = 1 + diversity * 0.3;

      r = ((r - 128) * boost + 128).clamp(0, 255);
      g = ((g - 128) * boost + 128).clamp(0, 255);
      b = ((b - 128) * boost + 128).clamp(0, 255);

      return GameColor.fromRgb(r.round(), g.round(), b.round());
  }
}

//civIntensity[system][species] += civKernelInfluence * migrationRate;