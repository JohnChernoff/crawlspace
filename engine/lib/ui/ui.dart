import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

/// Lightweight terminal UI for Crawlspace testing.
///
/// This is intentionally dumb and renderer-focused:
/// - no Flutter
/// - no widgets
/// - monospace terminal output only
/// - fast enough to refresh repeatedly during testing
///
/// Wire it to your real engine by implementing [TerminalUiAdapter].

import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/systems/weapon_profiler.dart';

import '../controllers/message_controller.dart';
import '../galaxy/system.dart';
import '../menu.dart';

/// Example terminal entry point.
///
/// Keep this in a separate debug executable and point the imports at your real
/// package layout. The adapter is intentionally conservative: where your exact
/// controller/menu APIs are not visible here, the code returns placeholders so
/// you have a compiling seam to fill in.
void main() async {
  final engine = FugueEngine(Galaxy('FooBar'), 'Zug', seed: 123);
  final ui = CrawlspaceTerminalUi(FugueEngineTerminalAdapter(engine));
  await ui.run();
}

abstract class TerminalUiAdapter {
  bool get running;
  bool get inMenu;
  bool get inAlphaSelect;
  String get menuTitle;
  List<MenuLine> get menuLines;
  String get alphaPrefix;
  List<AlphaResult> get alphaResults;
  int get alphaSelectedIndex;

  List<LogLine> get messageLog;
  List<String> get scannerLines;
  List<String> get statusLines;
  AsciiGridData get grid;

  void handleKey(String key);
  //void tick();
}

class CrawlspaceTerminalUi {
  final TerminalUiAdapter adapter;
  bool _running = true;

  CrawlspaceTerminalUi(this.adapter);

  Future<void> run() async {
    stdin.echoMode = false;
    stdin.lineMode = false;

    _clear();
    _hideCursor();

    StreamSubscription<List<int>>? sub;

    try {
      sub = stdin.listen((data) {
        print('RAW BYTES: $data');

        for (final key in _decodeBytes(data)) {
          if (key == 'ctrl-c') {
            _running = false;
            return;
          }
          adapter.handleKey(key);
        }
      });

      _render(); // initial draw

      while (_running && adapter.running) {
        //adapter.tick();

        if (adapter is FugueEngineTerminalAdapter) {
          final a = adapter as FugueEngineTerminalAdapter;
          if (a.consumeDirty()) {
            _render();
          }
        }

        await Future.delayed(const Duration(milliseconds: 20));
      }
    } finally {
      await sub?.cancel();
      _showCursor();
      stdin.echoMode = true;
      stdin.lineMode = true;
      stdout.writeln();
    }
  }

  void _render() {
    stdout.write('\x1B[H');

    final termWidth = stdout.hasTerminal ? stdout.terminalColumns : 120;
    final termHeight = stdout.hasTerminal ? stdout.terminalLines : 40;

    final rightWidth = math.max(28, termWidth ~/ 3);
    final leftWidth = termWidth - rightWidth - 2;
    final topHeight = math.max(12, termHeight - 12);
    final msgHeight = 6;
    final cmdHeight = math.max(4, termHeight - topHeight - msgHeight - 2);

    final tacticalLines = _renderGrid(adapter.grid, leftWidth - 2);
    final scannerStatusLines = [
      ...adapter.scannerLines,
      '',
      ...adapter.statusLines,
    ];

    final tacticalPanel = _box(
      'TACTICAL',
      _padLines(tacticalLines, topHeight - 2),
      leftWidth,
      topHeight,
    );

    final infoPanel = _box(
      'SCANNER / STATUS',
      _padLines(scannerStatusLines, topHeight - 2),
      rightWidth,
      topHeight,
    );

    final messagePanel = _box(
      'MESSAGES',
      _padLines(
        adapter.messageLog
            .take(msgHeight - 2)
            .map((m) => '[${m.timestamp}] ${m.text}')
            .toList(),
        msgHeight - 2,
      ),
      termWidth,
      msgHeight,
    );

    final commandLines = adapter.inMenu
        ? _menuCommandLines()
        : adapter.inAlphaSelect
        ? _alphaCommandLines()
        : _mainCommandLines();

    final commandPanel = _box(
      adapter.inMenu
          ? (adapter.menuTitle.isEmpty ? 'MENU' : adapter.menuTitle)
          : adapter.inAlphaSelect
          ? 'SYSTEM SELECT'
          : 'COMMANDS',
      _padLines(
        adapter.inMenu
            ? _menuLinesForPanel(cmdHeight - 2)
            : adapter.inAlphaSelect
            ? _alphaLinesForPanel(cmdHeight - 2)
            : commandLines,
        cmdHeight - 2,
      ),
      termWidth,
      cmdHeight,
    );

    final topRows = _hJoin([tacticalPanel, infoPanel]);
    for (final line in topRows) {
      stdout.writeln(line);
    }
    for (final line in messagePanel) {
      stdout.writeln(line);
    }
    for (final line in commandPanel) {
      stdout.writeln(line);
    }
  }

  List<String> _renderGrid(AsciiGridData grid, int width) {
    final out = <String>[];
    out.add('Depth ${grid.playerZ + 1}/${grid.size}   mode:${grid.showAllZ ? 'all-z' : 'closest'}   target:${grid.targetDistance ?? '-'}');
    out.add('');

    final header = StringBuffer('   ');
    for (int x = 0; x < grid.size; x++) {
      header.write('${x.toString().padLeft(2)} ');
    }
    out.add(header.toString());

    for (int y = 0; y < grid.size; y++) {
      final row = StringBuffer('${y.toString().padLeft(2)} ');
      for (int x = 0; x < grid.size; x++) {
        row.write(' ${grid.display[x][y]} ');
      }
      out.add(row.toString());
    }

    out.add('');
    out.add('Legend  @ player   X target   * path   #/% hazard   + scanned   A-Z ships');
    if (grid.rangeSparkline != null && grid.rangeSparkline!.isNotEmpty) {
      out.add('Range   ${grid.rangeSparkline}');
    }
    return out.map((s) => s.length > width ? s.substring(0, width) : s).toList();
  }

  List<String> _menuCommandLines() => const [
    'menu: press entry letter | esc back',
  ];

  List<String> _alphaCommandLines() => const [
    'alpha: type filter | up/down move | enter select | backspace erase | esc cancel',
  ];

  List<String> _mainCommandLines() => const [
    'move: arrows    z-level: < >    fire: f    target scanned: t',
    'scan cycle: q/a    toggle z-plane: =    wait/next weapon: enter',
    'menu letters act directly when menu is open    ctrl-c exits terminal ui',
  ];

  List<String> _menuLinesForPanel(int height) {
    final body = adapter.menuLines
        .map((m) => '${m.keyLabel.padRight(2)} ${m.label}${m.disabledReason == null ? '' : ' (${m.disabledReason})'}')
        .toList();
    body.add('');
    body.addAll(_menuCommandLines());
    return body.take(height).toList();
  }

  List<String> _alphaLinesForPanel(int height) {
    final lines = <String>[
      'find > ${adapter.alphaPrefix.isEmpty ? '_' : adapter.alphaPrefix}',
      '',
      ...adapter.alphaResults.take(math.max(0, height - 5)).toList().asMap().entries.map((e) {
        final i = e.key;
        final r = e.value;
        final marker = i == adapter.alphaSelectedIndex ? '>' : ' ';
        return '$marker ${r.name.padRight(18)} ${_bar('F', r.fed)} ${_bar('T', r.tech)}${r.visited ? '  visited' : ''}${r.homeworldGlyph == null ? '' : '  ${r.homeworldGlyph}'}';
      }),
      '',
      ..._alphaCommandLines(),
    ];
    return lines.take(height).toList();
  }

  String _bar(String label, double v) {
    final n = (v.clamp(0.0, 1.0) * 6).round();
    return '$label[${'=' * n}${'.' * (6 - n)}]';
  }

  List<String> _hJoin(List<List<String>> blocks) {
    final height = blocks.map((b) => b.length).reduce(math.max);
    final normalized = blocks
        .map((b) => [...b, ...List.filled(height - b.length, ' ' * b.first.length)])
        .toList();

    final out = <String>[];
    for (int i = 0; i < height; i++) {
      out.add(normalized.map((b) => b[i]).join('  '));
    }
    return out;
  }

  List<String> _box(String title, List<String> lines, int width, int height) {
    final innerWidth = math.max(1, width - 2);
    final trimmed = lines.take(math.max(0, height - 2)).map((l) {
      final s = l.length > innerWidth ? l.substring(0, innerWidth) : l;
      return s.padRight(innerWidth);
    }).toList();

    while (trimmed.length < height - 2) {
      trimmed.add(' ' * innerWidth);
    }

    final header = '┌${_fitTitle(title, innerWidth)}┐';
    final body = trimmed.map((l) => '│$l│').toList();
    final footer = '└${'─' * innerWidth}┘';
    return [header, ...body, footer];
  }

  String _fitTitle(String title, int width) {
    if (width <= 0) return '';
    final clean = ' $title ';
    if (clean.length >= width) return clean.substring(0, width);
    final remain = width - clean.length;
    final left = remain ~/ 2;
    final right = remain - left;
    return '${'─' * left}$clean${'─' * right}';
  }

  List<String> _padLines(List<String> lines, int height) {
    final out = lines.take(height).toList();
    while (out.length < height) {
      out.add('');
    }
    return out;
  }

  Iterable<String> _decodeBytes(List<int> data) sync* {
    print("Decoding: $data");
    for (int i = 0; i < data.length; i++) {
      final b = data[i];

      // Ctrl-C
      if (b == 3) {
        yield 'ctrl-c';
        continue;
      }

      // Enter
      if (b == 13 || b == 10) {
        yield 'enter';
        continue;
      }

      // Backspace
      if (b == 8 || b == 127) {
        yield 'backspace';
        continue;
      }

      // Windows extended keys
      if ((b == 0 || b == 224) && i + 1 < data.length) {
        final code = data[++i];
        switch (code) {
          case 72:
            yield 'up';
            break;
          case 80:
            yield 'down';
            break;
          case 75:
            yield 'left';
            break;
          case 77:
            yield 'right';
            break;
          case 73:
            yield 'pageup';
            break;
          case 81:
            yield 'pagedown';
            break;
          case 71:
            yield 'home';
            break;
          case 79:
            yield 'end';
            break;
        }
        continue;
      }

      // ANSI escape sequences: ESC [ A etc.
      if (b == 27) {
        if (i + 2 < data.length && data[i + 1] == 91) {
          final code = data[i + 2];
          i += 2;
          switch (code) {
            case 65:
              yield 'up';
              break;
            case 66:
              yield 'down';
              break;
            case 67:
              yield 'right';
              break;
            case 68:
              yield 'left';
              break;
            default:
              yield 'esc';
          }
        } else {
          yield 'esc';
        }
        continue;
      }

      // Space
      if (b == 32) {
        yield 'space';
        continue;
      }

      // Printable ASCII
      if (b >= 33 && b <= 126) {
        yield String.fromCharCode(b);
      }
    }
  }

  void _clear() => stdout.write('\x1B[2J\x1B[H');
  void _hideCursor() => stdout.write('\x1B[?25l');
  void _showCursor() => stdout.write('\x1B[?25h');
  void _moveCursor(int row, int col) => stdout.write('\x1B[${row};${col}H');
}

class LogLine {
  final String timestamp;
  final String text;
  const LogLine(this.timestamp, this.text);
}

class MenuLine {
  final String keyLabel;
  final String label;
  final String? disabledReason;
  const MenuLine(this.keyLabel, this.label, {this.disabledReason});
}

class AlphaResult {
  final String name;
  final double fed;
  final double tech;
  final String? homeworldGlyph;
  final bool visited;

  const AlphaResult({
    required this.name,
    this.fed = 0,
    this.tech = 0,
    this.homeworldGlyph,
    this.visited = false,
  });
}

class AsciiGridData {
  final int size;
  final int playerZ;
  final bool showAllZ;
  final List<List<String>> display;
  final int? targetDistance;
  final String? rangeSparkline;

  const AsciiGridData({
    required this.size,
    required this.playerZ,
    required this.showAllZ,
    required this.display,
    this.targetDistance,
    this.rangeSparkline,
  });
}

/// --------------------------------------
/// Real engine adapter.
/// --------------------------------------

class FugueEngineTerminalAdapter implements TerminalUiAdapter {
  final FugueEngine fm;
  bool _dirty = true;
  List<Message> _messages = const [];

  FugueEngineTerminalAdapter(this.fm) {
    fm.addListener(_markDirty);
    fm.msgController.msgWorker.stream.listen((msgs) {
      _messages = msgs.unlockView.toList();
      _markDirty();
    });
  }

  void dispose() {
    fm.removeListener(_markDirty);
  }

  void _markDirty() {
    _dirty = true;
  }

  bool consumeDirty() {
    final wasDirty = _dirty;
    _dirty = false;
    return wasDirty;
  }

  @override
  bool get running => !fm.gameOver;

  @override
  bool get inMenu => fm.inputMode == InputMode.menu;

  @override
  bool get inAlphaSelect => fm.inputMode == InputMode.alphaSelect;

  @override
  String get menuTitle => fm.menuController.currentMenuTitle;

  @override
  List<MenuLine> get menuLines {
    return fm.menuController.selectionList.map((e) {
      final label = e.label ?? _blocksToLine(e.txtBlocks) ?? '(unnamed)';
      return MenuLine(
        e.letter ?? '',
        label,
        disabledReason: e.enabled ? null : e.disabledReason,
      );
    }).toList();
  }

  @override
  String get alphaPrefix => fm.menuController.currAlphaComp?.searchPrefix ?? '';

  @override
  List<AlphaResult> get alphaResults {
    final alphaComp = fm.menuController.currAlphaComp;
    if (alphaComp == null) return const [];

    return alphaComp.getCurrentList.map((e) {
      final name = e.selectionName;
      double fed = 0;
      double tech = 0;
      bool visited = false;
      String? homeworldGlyph;

      if (e is System) {
        fed = fm.galaxy.fedKernel.val(e);
        tech = fm.galaxy.techKernel.val(e);
        visited = e.visited;
        homeworldGlyph = fm.galaxy.getHomeworldSpecies(e)?.glyph;
      }

      return AlphaResult(
        name: name,
        fed: fed,
        tech: tech,
        visited: visited,
        homeworldGlyph: homeworldGlyph,
      );
    }).toList();
  }

  @override
  int get alphaSelectedIndex => fm.menuController.currAlphaComp?.selectedIndex ?? 0;

  @override
  List<LogLine> get messageLog {
    final worker = fm.msgController.msgWorker;
    final messages = _messages;
    return messages.reversed.take(14).map((m) {
      return LogLine(m.timestamp, m.text);
    }).toList();
  }

  @override
  List<String> get scannerLines => _textBlocksToLines(fm.scannerController.scannerText());

  @override
  List<String> get statusLines {
    final lines = _textBlocksToLines(fm.scannerController.statusText());
    final ship = fm.playerShip;
    if (ship != null) {
      final spark = _rangeSparkline(ship);
      if (spark.isNotEmpty) lines.add('Range : $spark');
    }
    return lines;
  }

  @override
  AsciiGridData get grid {
    final ship = fm.playerShip;
    if (ship == null) {
      return const AsciiGridData(
        size: 1,
        playerZ: 0,
        showAllZ: false,
        display: [['?']],
      );
    }

    final map = ship.loc.map;
    final size = map.size;
    final scannedCell = ship.nav.targetShip?.loc.cell ?? fm.scannerController.currentScanSelection;
    final display = List.generate(size, (_) => List.filled(size, '.'));

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        display[x][y] = _glyphAt(
          x,
          y,
          map,
          ship,
          scannedCell,
          showAllZPlane: fm.scannerController.showAllCellsOnZPlane,
        );
      }
    }

    final targetDistance = ship.nav.targetShip == null
        ? null
        : ship.distance(ship: ship.nav.targetShip!).round();

    return AsciiGridData(
      size: size,
      playerZ: ship.loc.cell.coord.z,
      showAllZ: fm.scannerController.showAllCellsOnZPlane,
      display: display,
      targetDistance: targetDistance,
      rangeSparkline: _rangeSparkline(ship),
    );
  }

  @override
  void handleKey(String key) {
    switch (key) {
      case 'up':
        _move(0, -1, 0);
        break;
      case 'down':
        _move(0, 1, 0);
        break;
      case 'left':
        _move(-1, 0, 0);
        break;
      case 'right':
        _move(1, 0, 0);
        break;
      case '>':
        _move(0, 0, 1);
        break;
      case '<':
        _move(0, 0, -1);
        break;
      case 'f':
        _try(() => fm.combatController.fire(fm.playerShip));
        break;
      case 't':
        _try(() => fm.scannerController.targetScannedObject(fm.scannerController.currentScanSelection));
        break;
      case 'q':
        _try(() => fm.scannerController.selectScannedObject(true));
        break;
      case 'a':
        _try(() => fm.scannerController.selectScannedObject(false));
        break;
      case '=':
        _try(() {
          fm.scannerController.showAllCellsOnZPlane = !fm.scannerController.showAllCellsOnZPlane;
          fm.update();
        });
        break;
      case 'enter':
        if (fm.inputMode == InputMode.main) {
          _try(() => fm.combatController.awaitNextWeapon(fm.playerShip));
        } else if (fm.inputMode == InputMode.target) {
          _try(() => fm.exitInputMode());
        } else if (fm.inputMode == InputMode.alphaSelect) {
          _try(() => fm.menuController.currAlphaComp?.complete());
        } else if (fm.inputMode == InputMode.menu) {
          _try(() {
            final firstEnabled = fm.menuController.selectionList.firstWhere((e) => e.enabled);
            firstEnabled.activate(fm.menuController);
          });
        }
        break;
      case 'esc':
        _try(() => fm.exitInputMode());
        break;
      default:
        if (key.length == 1 && inAlphaSelect) {
          _try(() {
            final comp = fm.menuController.currAlphaComp;
            if (comp == null) return;
            if (RegExp(r'[a-zA-Z0-9]').hasMatch(key)) {
              comp.searchPrefix = '${comp.searchPrefix}$key';
              fm.update(noWait: true);
            }
          });
        } else if (key == 'backspace' && inAlphaSelect) {
          _try(() {
            final comp = fm.menuController.currAlphaComp;
            if (comp == null || comp.searchPrefix.isEmpty) return;
            comp.searchPrefix = comp.searchPrefix.substring(0, comp.searchPrefix.length - 1);
            fm.update(noWait: true);
          });
        } else if (key == 'up' && inAlphaSelect) {
          _try(() {
            final comp = fm.menuController.currAlphaComp;
            if (comp == null || comp.getCurrentList.isEmpty) return;
            comp.selectedIndex = (comp.selectedIndex - 1) < 0 ? comp.getCurrentList.length - 1 : comp.selectedIndex - 1;
            fm.update(noWait: true);
          });
        } else if (key == 'down' && inAlphaSelect) {
          _try(() {
            final comp = fm.menuController.currAlphaComp;
            if (comp == null || comp.getCurrentList.isEmpty) return;
            comp.selectedIndex = (comp.selectedIndex + 1) % comp.getCurrentList.length;
            fm.update(noWait: true);
          });
        } else if (key == 'esc' && inAlphaSelect) {
          _try(() {
            fm.menuController.currAlphaComp?.abort();
            fm.update(noWait: true);
          });
        } else if (key.length == 1 && inMenu) {
          _try(() {
            final entry = fm.menuController.selectionList.firstWhere((e) => e.letter == key, orElse: () => TextEntry(label: ''));
            if ((entry.label != null || entry.txtBlocks.isNotEmpty) && entry.letter == key) {
              entry.activate(fm.menuController);
            }
          });
        }
    }
  }

  void _move(int dx, int dy, int dz) {
    final ship = fm.playerShip;
    if (ship == null) return;
    if (fm.inputMode == InputMode.main) { //TODO: add movementController.move
      //_try(() => fm.pilotController.move(ship, Coord3D(dx, dy, dz), vector: true));
    } else if (fm.inputMode == InputMode.target) {
      _try(() => fm.movementController.vectorTarget(Coord3D(dx, dy, dz)));
    }
  }

  String _glyphAt(
      int x,
      int y,
      CellMap<GridCell> map,
      Ship playerShip,
      GridCell? scannedCell, {
        required bool showAllZPlane,
      }) {
    GridCell closestCell = map[Coord3D(x, y, 0)]!;
    final shipCoord = playerShip.loc.cell.coord;
    final targetPath = fm.scannerController.targetPath;
    final invert = map is SectorMap && map.values.any((e) => e.hazLevel > 0);

    final glyphs = <String>[];

    for (int z = 0; z < map.size; z++) {
      final cell = map[Coord3D(x, y, z)]!;
      if (!showAllZPlane) {
        if (scannedCell?.coord == cell.coord) {
          return _cellGlyph(cell, playerShip, scanned: true, uiTarget: _isUiTarget(cell), inTargetPath: targetPath.contains(cell), invert: invert);
        }
        if (shipCoord == cell.coord) {
          closestCell = cell;
          break;
        }
        if (!cell.isEmpty(fm.shipRegistry)) {
          if (closestCell.isEmpty(fm.shipRegistry) || playerShip.distance(c: cell.coord) < playerShip.distance(c: closestCell.coord)) {
            closestCell = cell;
          }
        }
        continue;
      }

      glyphs.add(_cellGlyph(
        cell,
        playerShip,
        scanned: scannedCell != null && scannedCell.coord.x == cell.coord.x && scannedCell.coord.y == cell.coord.y && playerShip.canScan(cell),
        uiTarget: _isUiTarget(cell),
        inTargetPath: targetPath.contains(cell),
        invert: invert,
      ));
    }

    if (showAllZPlane) {
      // Back to front, same idea as the Flutter stack. Return the topmost non-blank glyph.
      for (final g in glyphs.reversed) {
        if (g != ' ') return g;
      }
      return '.';
    }

    return _cellGlyph(closestCell, playerShip, uiTarget: _isUiTarget(closestCell), invert: invert);
  }

  bool _isUiTarget(GridCell cell) =>
      fm.inputMode == InputMode.target && fm.player.targetLoc?.cell == cell;

  String _cellGlyph(
      GridCell cell,
      Ship playerShip, {
        bool scanned = false,
        bool uiTarget = false,
        bool inTargetPath = false,
        bool invert = false,
      }) {
    final ships = fm.shipRegistry.atCell(cell);
    if (playerShip.loc.cell == cell) return '@';
    if (uiTarget) return 'X';
    if (ships.isNotEmpty) {
      final ship = ships.first;
      if (ship == playerShip.nav.targetShip) return 'X';
      final pilot = ship.pilot;
      final initial = _try(() => pilot.faction.species.name[0].toUpperCase())
          ?? _try(() => pilot.name[0].toUpperCase())
          ?? 'S';
      return initial;
    }
    final hasHaz = _try(() => cell.hazLevel as int? ?? 0) != 0
        //|| _try(() => cell.hazMap.isNotEmpty)
        || _try(() => cell.effects.allActive.isNotEmpty as bool? ?? false) == true;
    if (hasHaz) return invert ? '#' : '%';
    if (inTargetPath) return '*';
    if (scanned) return '+';
    return '.';
  }

  List<String> _textBlocksToLines(List<dynamic> blocks) {
    final lines = <String>[];
    final sb = StringBuffer();

    for (final b in blocks) {
      final txt = _stringField(b, ['txt']) ?? '';
      final newline = _boolField(b, ['newline']) ?? false;
      sb.write(txt);
      if (newline) {
        lines.add(sb.toString());
        sb.clear();
      }
    }
    if (sb.isNotEmpty) lines.add(sb.toString());
    return lines;
  }

  String _rangeSparkline(Ship ship) {
    try {
      final profile = ship.sustainedRangeProfile(maxRange: ship.loc.map.size * 2);
      const glyphs = [' ', '.', ':', '-', '=', '+', '*', '#', '%', '@'];
      if (profile.peakScore <= 0) return '';
      return profile.scoreByRange.map((score) {
        final t = (score / profile.peakScore).clamp(0.0, 1.0);
        final idx = (t * (glyphs.length - 1)).round();
        return glyphs[idx];
      }).join();
    } catch (_) {
      return '';
    }
  }

  T? _try<T>(T Function() fn) {
    try {
      return fn();
    } catch (_) {
      return null;
    }
  }

  String? _stringField(dynamic obj, List<String> names) {
    for (final name in names) {
      try {
        final value = switch (name) {
          'txt' => obj.txt,
          'label' => obj.label,
          'letter' => obj.letter,
          'text' => obj.text,
          'timestamp' => obj.timestamp,
          'name' => obj.name,
          'disabledReason' => obj.disabledReason,
          _ => null,
        };
        if (value != null) return value.toString();
      } catch (_) {}
    }
    return null;
  }

  bool? _boolField(dynamic obj, List<String> names) {
    for (final name in names) {
      try {
        final value = switch (name) {
          'newline' => obj.newline,
          _ => null,
        };
        if (value is bool) return value;
      } catch (_) {}
    }
    return null;
  }

  String? _blocksToLine(List<dynamic> blocks) {
    if (blocks.isEmpty) return null;
    return _textBlocksToLines(blocks).join(' ');
  }
}
