import 'dart:math';
import 'package:crawlspace_engine/system.dart';
import 'galaxy.dart';

abstract class Deterministic {}
abstract class Stateful {}

abstract class DeterministicField<T> extends FlowField<T> {
  DeterministicField(super.galaxy, super.ops, super.preset);
  void recomputeFromSeed();
}

abstract class StatefulField<T> extends FlowField<T> {
  StatefulField(super.galaxy, super.ops, super.preset);
  void loadState();
  void saveState();
}

abstract class FlowOps<T> {
  T zero();
  T add(T a, T b);
  T scale(T a, double k);
  T clamp(T v);
  double scalarize(T v);
}

class FlowPreset<T> {
  final double Function(System from, System to) edgeWeight;
  final T Function(System s, T v) decay;
  final T Function(System s) source;

  const FlowPreset({
    required this.edgeWeight,
    required this.decay,
    required this.source,
  });
}

class FlowGradient<T> {
  final FlowField<T> field;
  final Map<System, System?> downhill = {};
  FlowGradient(this.field);

  System? smallestLink(System s) {
    System? best;
    double bestV = double.infinity;
    for (final n in s.links) {
      //final v = field.ops.scalarize(field.value[n]!) / trafficWeight(n);
      final v = field.ops.scalarize(field.value[n]!);
      if (v < bestV) {
        bestV = v;
        best = n;
      }
    }
    return best;
  }

  void recompute() {
    for (final s in field.galaxy.systems) downhill[s] = smallestLink(s);
  }
}

class FlowField<T> {
  final Galaxy galaxy;
  final FlowOps<T> ops;
  final FlowPreset<T> preset;
  Map<System, T> value = {};
  Map<System,T> next = {};
  final bool conservative;
  double diffusion;
  double retain = .9;
  T val(System s) => value[s] ?? ops.zero();

  FlowField(this.galaxy, this.ops, this.preset, {this.conservative = false, this.diffusion = 0.1}) {
    for (final s in galaxy.systems) {
      value[s] = ops.zero();
    }
  }

  void tick() {
    // swap buffers
    final tmp = value;
    value = next;
    next = tmp;
    next.clear();

    for (final s in galaxy.systems) {
      final v = val(s);

      // retain self
      next[s] = ops.scale(v, retain * retainFor(s));

      // apply decay + sources
      next[s] = preset.decay(s, next[s]!);
      next[s] = ops.add(next[s]!, preset.source(s));

      for (final n in s.links) {
        final w = preset.edgeWeight(s, n);
        final diff = ops.scale(v, diffusion * w / s.links.length);

        //if (ops is VectorOps) { (ops as VectorOps).addInPlace(next[n]!, diff); } else { next[n] = ops.add(next[n]!, diff); }
        next[n] = ops.add(next[n]!, diff);

        if (conservative) {
          final loss = ops.scale(v, diffusion * w / s.links.length);
          next[s] = ops.add(next[s]!, ops.scale(loss, -1));
        }
      }

      next[s] = ops.clamp(next[s]!);
    }
  }

  double retainFor(System s) => switch (galaxy.trafficFor(s)) {
    > .75 => 0.85,
    > .25 => 0.95,
    _ => 0.99,
  };
}

class DoubleOps extends FlowOps<double> {
  double zero() => 0.0;
  double add(double a, double b) => a + b;
  double scale(double a, double k) => a * k;
  double scalarize(double v) => v;
  double clamp(double v) => max(0,min(v,100));
}

class FlowScheduler {
  final Map<String, int> periods = {}; // turns per tick
  final Map<String, int> counters = {};

  void register(String name, int period, Random rnd) {
    periods[name] = period;
    counters[name] = rnd.nextInt(period); // phase offset
  }

  bool shouldTick(String name) {
    counters[name] = (counters[name]! + 1) % periods[name]!;
    return counters[name] == 0;
  }
}

class VectorOps extends FlowOps<List<double>> {
  final int dim;
  final double minVal;
  final double maxVal;

  VectorOps(this.dim, {this.minVal = 0.0, this.maxVal = 1.0});

  @override
  List<double> zero() => List.filled(dim, 0.0);

  @override
  List<double> add(List<double> a, List<double> b) {
    final out = List<double>.filled(dim, 0.0);
    for (int i = 0; i < dim; i++) {
      out[i] = a[i] + b[i];
    }
    return out;
  }

  @override
  List<double> scale(List<double> a, double k) {
    final out = List<double>.filled(dim, 0.0);
    for (int i = 0; i < dim; i++) {
      out[i] = a[i] * k;
    }
    return out;
  }

  @override
  List<double> clamp(List<double> v) {
    for (int i = 0; i < dim; i++) {
      if (v[i] < minVal) v[i] = minVal;
      if (v[i] > maxVal) v[i] = maxVal;
    }
    return v;
  }

  @override
  double scalarize(List<double> v) {
    // default scalar = total magnitude
    double sum = 0;
    for (final x in v) sum += x;
    return sum;
  }

  void addInPlace(List<double> a, List<double> b) {
    for (int i = 0; i < dim; i++) a[i] += b[i];
  }
}

//print("Flow ${fieldName} max=${value.values.map(ops.scalarize).reduce(max)}");
//for (final s in galaxy.systemsByIndex) { ... }
//value(s) = Σ sources * exp(-distance / decay)
//System chooseNext(System s) => gradient.downhill[s] ?? randomNeighbor();
