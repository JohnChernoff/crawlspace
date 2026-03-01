import 'dart:math';

import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/stock_items/species.dart';

void main() {
  debugLevel = DebugLevel.Lowest;
  final engine = FugueEngine(Galaxy("Testlandia"), "Zug", seed: 0);
  final civModel = engine.galaxy.civMod;

  // Political map and rivalries
  civModel.debugPrintPoliticalMap();
  civModel.debugPrintRivalries();

  // Faction attitude breakdown
  _debugPrintFactionAttitudes(civModel);
}

void _debugPrintFactionAttitudes(civModel) {
  final colWidth = 12;
  final nameWidth = 24;
  final allSpecies = civModel.allSpecies as List<Species>;

  print('═' * (nameWidth + colWidth * allSpecies.length));
  print('FACTION ATTITUDES');
  print('═' * (nameWidth + colWidth * allSpecies.length));

  // Header
  final header = ''.padRight(nameWidth) +
      allSpecies.map((s) => s.name.substring(0, min(colWidth - 1, s.name.length))
          .padRight(colWidth)).join();
  print(header);
  print('─' * header.length);

  // Group factions by species
  for (final species in allSpecies) {
    final speciesFactions = factions.where((f) => f.species == species).toList();
    if (speciesFactions.isEmpty) continue;

    // Species header row — shows weighted average (same as politicalMap)
    final speciesRow = StringBuffer();
    speciesRow.write('[${species.name}]'
        .substring(0, min(nameWidth - 1, species.name.length + 2))
        .padRight(nameWidth));
    for (final b in allSpecies) {
      if (b == species) {
        speciesRow.write('——'.padRight(colWidth));
      } else {
        final v = civModel.politicalMap[species]?[b];
        speciesRow.write(v == null ? '?'.padRight(colWidth) : _label(v).padRight(colWidth));
      }
    }
    print(speciesRow.toString());

    // Individual faction rows
    for (final faction in speciesFactions) {
      final row = StringBuffer();
      final factionLabel = '  ${faction.name} (${faction.strength.toStringAsFixed(2)}'
          ' m:${faction.militancy.toStringAsFixed(2)})';
      row.write(factionLabel.substring(0, min(nameWidth - 1, factionLabel.length))
          .padRight(nameWidth));

      for (final b in allSpecies) {
        if (b == species) {
          row.write('——'.padRight(colWidth));
        } else {
          final v = civModel.factionAttitudes[faction]?[b];
          if (v == null) {
            row.write('?'.padRight(colWidth));
          } else {
            // Mark fixed attitudes with *
            final isFixed = faction.fixedAttitudes.containsKey(b);
            final label = _label(v) + (isFixed ? '*' : '');
            row.write(label.padRight(colWidth));
          }
        }
      }
      print(row.toString());
    }
    print('─' * header.length);
  }

  print('═' * header.length);
  print('★ ally  ◎ friendly  · neutral  △ tense  ✕ hostile  * fixed attitude');
  print('═' * header.length);
}

String _label(double v) => switch(v) {
  > 0.75 => '★ ${v.toStringAsFixed(2)}',
  > 0.55 => '◎ ${v.toStringAsFixed(2)}',
  > 0.45 => '· ${v.toStringAsFixed(2)}',
  > 0.25 => '△ ${v.toStringAsFixed(2)}',
  _      => '✕ ${v.toStringAsFixed(2)}',
};

