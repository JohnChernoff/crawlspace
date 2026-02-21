import 'dart:math';
import 'package:crawlspace_engine/galaxy/sub_model.dart';
import '../flow_field.dart';
import '../galaxy.dart';
import '../stock_items/species.dart';
import '../system.dart';

class CivModel extends GalaxySubMod {
  final List<Species> allSpecies;
  Map<System, Map<Species,double>> civIntensity = {};
  Map<System,double> techField = {};
  Map<System,double> commerceField = {};

  CivModel(super.galaxy, this.allSpecies);

  void computeCivFields() {
    for (final s in systems) {
      civIntensity[s] = {};
      for (final sp in allSpecies) {
        final d = distance(galaxy.findHomeworld(sp), s);
        civIntensity[s]![sp] = exp(-d / sp.range) * sp.populationDensity;
      }
      civIntensity[s] = normalize(civIntensity[s]!);
    }
  }

  void calcMacro() {
    for (final s in systems) {
      techField[s] = civIntensity[s]!
          .entries
          .map((e) => e.value * e.key.tech)
          .reduce((a,b)=>a+b);
      commerceField[s] = civIntensity[s]!
          .entries
          .map((e) => e.value * e.key.commerce)
          .reduce((a,b)=>a+b);
    }
  }
}

class CivFlowField extends FlowField<List<double>> {
  final SpeciesRegistry reg;
  final Map<System, List<double>> sources = {};

  CivFlowField(Galaxy g, this.reg)
      : super(
    g,
    VectorOps(reg.all.length, maxVal: 1.0),
    FlowPreset<List<double>>(
      edgeWeight: (a,b)=>1.0,
      decay: (s,v)=>VectorOps(reg.all.length).scale(v, 0.999),
      source: (s)=>List.filled(reg.all.length, 0.0),
    ),
    diffusion: 0.05,
  ) {
    for (final s in g.systems) value[s] = ops.zero();
  }

  void seedFromCivModel(CivModel civ) {
    for (final s in galaxy.systems) {
      final v = List<double>.filled(reg.all.length, 0.0);
      civ.civIntensity[s]!.forEach((sp, w) {
        v[reg.index[sp]!] = w;
      });
      value[s] = v;
    }
  }

  Species dominantSpecies(System s) {
    final v = val(s);
    int best = 0;
    for (int i=1;i<v.length;i++) if (v[i] > v[best]) best = i;
    return reg.all[best];
  }
}


