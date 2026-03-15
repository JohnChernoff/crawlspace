double resistanceReduction(double r, {double k = 1.8}) {
  return r / (r + k);
}

void printResistanceTable({
  double kStart = 1.2,
  double kEnd = 2.4,
  double kStep = 0.2,
  int maxResistance = 10,
}) {
  // Header
  final ks = <double>[];
  for (double k = kStart; k <= kEnd + 0.0001; k += kStep) {
    ks.add(double.parse(k.toStringAsFixed(2)));
  }

  final header = StringBuffer('r '.padRight(4));
  for (final k in ks) {
    header.write('k=${k.toStringAsFixed(1)}'.padLeft(8));
  }
  print(header);

  for (int r = 1; r <= maxResistance; r++) {
    final row = StringBuffer('${r.toString().padRight(4)}');
    for (final k in ks) {
      final pct = resistanceReduction(r.toDouble(), k: k) * 100;
      row.write('${pct.toStringAsFixed(1)}%'.padLeft(8));
    }
    print(row);
  }
}

void main() {
  printResistanceTable();
}
