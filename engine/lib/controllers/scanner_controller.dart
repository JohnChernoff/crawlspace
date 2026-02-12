//import 'package:collection/collection.dart';
import 'package:collection/collection.dart';

import '../fugue_engine.dart';
import '../color.dart';
import '../grid.dart';
import '../ship.dart';
import 'fugue_controller.dart';

enum ScannerMode {
  all(GameColors.white),
  objects(GameColors.cyan),
  ships(GameColors.green),
  planets(GameColors.blue),
  stars(GameColors.yellow),
  ion(GameColors.orange),
  neb(GameColors.purple),
  roid(GameColors.gray),
  oddities(GameColors.neonPink),
  storms(GameColors.red),
  field(GameColors.brown); //,
  final GameColor color;
  const ScannerMode(this.color);
  bool get scaningShips => this == ScannerMode.ships || this == ScannerMode.objects;
  bool get scaningPlanets => this == ScannerMode.planets || this == ScannerMode.objects;
  bool get scaningStars => this == ScannerMode.stars || this == ScannerMode.objects;
  bool get scaningIons => this == ScannerMode.ion || this == ScannerMode.storms || this == ScannerMode.field;
  bool get scaningNeb => this == ScannerMode.neb || this == ScannerMode.field;
  bool get scaningRoids => this == ScannerMode.roid || this == ScannerMode.field;
  bool get scaningBlackhole => this == ScannerMode.oddities;
  bool get scaningStarOne => this == ScannerMode.oddities;
}

enum TargetPathMode {
  safe,safest,direct
}

class ScannerController extends FugueController {
  ScannerController(super.fm);

  ScannerMode scannerMode = ScannerMode.objects;
  List<GridCell> currentScan = [];
  GridCell? currentScanSelection;
  int currentScannedShipIndex = 0;
  bool showAllCellsOnZPlane = true;
  TargetPathMode targetPathMode = TargetPathMode.direct;

  List<GridCell> get targetPath {
    final tLoc = fm.playerShip?.targetShip?.loc;
    if (tLoc != null) {
      return switch(targetPathMode) {
        TargetPathMode.safe => tLoc.level.map.greedyPath(fm.playerShip!.loc.cell, tLoc.cell, tLoc.level.map.size, fm.rnd, jitter: 0, minHaz: 0),
        TargetPathMode.safest => tLoc.level.map.greedyPath(fm.playerShip!.loc.cell, tLoc.cell, tLoc.level.map.size, fm.rnd, jitter: 0, forceHaz: true),
        TargetPathMode.direct => tLoc.level.map.greedyPath(fm.playerShip!.loc.cell, tLoc.cell, tLoc.level.map.size, fm.rnd, jitter: 0,  ignoreHaz: true),
      };
    } else return [];
  }

  List<TextBlock> statusText() {
    List<TextBlock> blocks = []; //blocks.add(const TextBlock("Status: ",Colors.white,true));
    blocks.add(TextBlock("Mode: ${fm.menuController.inputMode.name}",GameColors.white,true));
    blocks.add(TextBlock("Tick: ${fm.auTick / 100}",GameColors.brown,true));
    blocks.add(TextBlock("Credits: ${fm.player.credits}",GameColors.khaki,true));

    Ship? ship = fm.playerShip; if (ship == null) {
      blocks.add(const TextBlock("No ship!",GameColors.red,true));
    } else {
      blocks.add(TextBlock(ship.loc.toString(),GameColors.cyan,true));
      blocks.addAll(ship.status());
    }
    return blocks;
  }

  void cycleScannerTargetMode() {
    int i = targetPathMode.index < TargetPathMode.values.length - 1
        ? targetPathMode.index + 1
        : 0;
    targetPathMode = TargetPathMode.values.elementAt(i);
    if (targetPathMode == TargetPathMode.safest) targetPathMode = TargetPathMode.direct; // skipping safest for now
    fm.msgController.addMsg("Scanner Target Path Mode: ${targetPathMode.name}");
    fm.update();
  }

  List<TextBlock> scannerText({ScannerMode? mode}) {
    List<TextBlock> blocks = []; currentScan.clear();
    blocks.add(const TextBlock("Scanner mode: ",GameColors.white,false));
    blocks.add(TextBlock(scannerMode.name, scannerMode.color, true));
    Ship? ship = fm.playerShip; if (ship == null) {
      blocks.add(const TextBlock("?", GameColors.red, true));
    } else {
      final cells = ship.loc.level.map.cells.values
          .where((c) => c.scannable(ship.loc.level.map, mode ?? scannerMode))
          .sorted((c1,c2) => c1.coord.distance(ship.loc.cell.coord).compareTo(c2.coord.distance(ship.loc.cell.coord)));
      for (GridCell cell in cells) {
        if (!cell.empty(ship.loc.level.map)) {
          blocks.add(TextBlock(cell.toScannerString(ship.loc.level.map), currentScanSelection == cell ? GameColors.gold : GameColors.green, true));
          currentScan.add(cell);
        }
      }
    }
    return blocks;
  }

  void selectScannedObject(bool up) {
    if (currentScanSelection == null || !currentScan.contains(currentScanSelection)) {
      currentScanSelection = currentScan.firstOrNull;
    } else {
      for (int i=0;i<currentScan.length;i++) {
        if (currentScanSelection == currentScan.elementAt(i)) {
          int newIndex = i + (up ? -1 : 1);
          if (newIndex >= currentScan.length) newIndex = 0;
          if (newIndex < 0) newIndex = currentScan.length - 1;
          currentScanSelection = currentScan.elementAt(newIndex);
          break;
        }
      }
    }
    fm.update();
  }

  void targetScannedObject(Ship? ship, GridCell? cell) {
    if (ship != null && cell != null) ship.targetCoord = cell.coord;
    fm.update();
  }

  void targetShipFromScannedCell({GridCell? currCell}) {
    final scannedCell = currCell ?? currentScanSelection;
    if (scannedCell == null || !currentScan.contains(scannedCell)) return;
    Ship? playShip = fm.playerShip; if (playShip != null) {
      final ships = playShip.loc.level.shipsAt(scannedCell);
      if (ships.length > 1) {
        currentScannedShipIndex++;
        if (currentScannedShipIndex >= ships.length) currentScannedShipIndex = 0;
        playShip.targetShip = ships.elementAt(currentScannedShipIndex);
      }
      else {
        playShip.targetShip = ships.firstOrNull;
      }
    }
    fm.update();
  }

  void toggleScannerMode({bool forwards = true}) {
    if (forwards) {
      if (scannerMode.index < ScannerMode.values.length - 1) {
        scannerMode = ScannerMode.values.elementAt(scannerMode.index + 1);
      } else {
        scannerMode = ScannerMode.values.elementAt(0);
      }
    } else {
      if (scannerMode.index > 0) {
        scannerMode = ScannerMode.values.elementAt(scannerMode.index - 1);
      } else {
        scannerMode = ScannerMode.values.elementAt(ScannerMode.values.length - 1);
      }
    }
    reset();
    fm.update();
  }

  void reset() {
    currentScanSelection = null;
    currentScannedShipIndex = 0;
  }

}