import 'package:collection/collection.dart';
import '../fugue_engine.dart';
import '../color.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/system.dart';
import '../item.dart';
import '../ship/ship.dart';
import 'fugue_controller.dart';

enum ScannerMode {
  all(GameColors.white,true),
  contacts(GameColors.cyan,true),
  items(GameColors.gold,true),
  ships(GameColors.green,false),
  planets(GameColors.blue,false),
  stars(GameColors.yellow,false),
  buoys(GameColors.blue,true),
  ion(GameColors.orange,true),
  neb(GameColors.coral,true),
  roid(GameColors.gray,true),
  oddities(GameColors.neonPink,false),
  storms(GameColors.red,false),
  field(GameColors.brown,false);
  final GameColor color;
  final bool accessable;
  const ScannerMode(this.color, this.accessable);
  bool get scaningShips => this == ScannerMode.ships || this == ScannerMode.contacts;
  bool get scaningPlanets => this == ScannerMode.planets || this == ScannerMode.contacts;
  bool get scaningStars => this == ScannerMode.stars || this == ScannerMode.contacts;
  bool get scaningBuoys => this == ScannerMode.buoys;
  bool get scaningItems => this == ScannerMode.contacts || this == ScannerMode.items;
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

  Set<Item> sensorList = {};
  ScannerMode scannerMode = ScannerMode.contacts;
  List<GridCell> currentScan = [];
  GridCell? currentScanSelection;
  int currentScannedShipIndex = 0;
  bool showAllCellsOnZPlane = true;
  TargetPathMode targetPathMode = TargetPathMode.direct;
  bool autoTarget = true;

  List<GridCell> get targetPath {
    final playShip = fm.playerShip;
    if (playShip != null && playShip.nav.targetShip != null && playShip.canScan(playShip.nav.targetShip!.loc.cell)) {
      final tLoc = playShip.nav.targetShip?.loc;
      if (tLoc != null && tLoc.domain == playShip.loc.domain) {
        return switch(targetPathMode) {
          TargetPathMode.safe => tLoc.map.greedyPath(playShip.loc.cell, tLoc.cell, tLoc.map.dim.maxDim, fm.mapRnd, jitter: 0, minHaz: 0),
          TargetPathMode.safest => tLoc.map.greedyPath(playShip.loc.cell, tLoc.cell, tLoc.map.dim.maxDim, fm.mapRnd, jitter: 0, forceHaz: true),
          TargetPathMode.direct => tLoc.map.greedyPath(playShip.loc.cell, tLoc.cell, tLoc.map.dim.maxDim, fm.mapRnd, jitter: 0,  ignoreHaz: true),
        };
      }
    }
    return [];
  }

  List<TextBlock> statusText() {
    final abbrev = fm.playerShip?.nav.targetShip != null;
    List<TextBlock> blocks = [];
    if (!abbrev) {
      //blocks.add(TextBlock("Mode: ${fm.inputMode.name}",GameColors.white,true));
      blocks.add(TextBlock("Tick: ${fm.auTick / 100}, ",GameColors.khaki,false));
      blocks.add(TextBlock("Credits: ${fm.player.credits}",GameColors.khaki,true));
      final mainSpecies = fm.galaxy.civMod.dominantSpecies(fm.player.locale.loc.system)!;
      int dist = fm.galaxy.topo.distance(fm.player.locale.loc.system, fm.galaxy.findHomeworld(mainSpecies));
      blocks.add(TextBlock("${mainSpecies.name} Space ($dist)",mainSpecies.graphCol,true));
    }
    Ship? ship = fm.playerShip; if (ship == null) {
      blocks.add(const TextBlock("No ship",GameColors.red,true));
    } else {
      if (!abbrev) blocks.add(TextBlock(ship.loc.toString(),GameColors.cyan,true));
      if (ship.itinerary != null) blocks.add(TextBlock("To: ${ship.itinerary!.last.name}", GameColors.green, true));
      blocks.addAll(ship.status.display(fm.galaxy));
    }
    return blocks;
  }

  List<TextBlock> scannerText({ScannerMode? mode}) {
    currentScan.clear();
    List<TextBlock> blocks = [];
    blocks.add(const TextBlock("Scanner mode: ",GameColors.white,false));
    blocks.add(TextBlock(scannerMode.name, scannerMode.color, true));
    Ship? ship = fm.playerShip; if (ship == null) {
      return [TextBlock("?", GameColors.red, true)];
    } else if (ship.inNebula) {
      return [TextBlock("In Nebula", GameColors.red, true)];
    } else {
      final cells = ship.loc.map.values
          .where((c) => c.scannable(mode ?? scannerMode,fm.galaxy))
          .sorted((c1,c2) => c1.dist(ship.loc).compareTo(c2.dist(ship.loc)))
          .sorted((a,b) => fm.galaxy.ships.atCell(b).length.compareTo(fm.galaxy.ships.atCell(a).length));
      for (final cell in cells) {
        if (!cell.isEmpty(fm.galaxy)) {
          currentScan.add(cell); //print("Cell: ${cell.coord}");
          blocks.add(TextBlock(cell.toScannerString(fm.galaxy), currentScanSelection == cell ? GameColors.gold : GameColors.green, true));
        }
      }
      for (final i in sensorList) {
        blocks.add(TextBlock(i.toString(), GameColors.white, true));
        if (i.scanned?.system == true) blocks.add(TextBlock(i.name, i.objColor, true));
      }
    }
    return blocks;
  }

  void refreshSensors(System system) {
    sensorList = fm.galaxy.items.inSystem(system).where((i) => i.scanned?.system == true).toSet();
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
          if (autoTarget) targetScannedObject(currentScanSelection);
          break;
        }
      }
    }
    fm.update();
  }

  void targetScannedObject(GridCell? cell) { //print("Targeting: ${cell?.coord}");
    final scannedCell = cell ?? currentScanSelection;
    if (scannedCell == null || !currentScan.contains(scannedCell)) return;
    Ship? playShip = fm.playerShip; if (playShip != null) {
      final ships = fm.galaxy.ships.atCell(scannedCell).where((s) => s.npc).toList();
      if (ships.length > 1) {
        currentScannedShipIndex++;
        if (currentScannedShipIndex >= ships.length) currentScannedShipIndex = 0;
        playShip.nav.targetCoord = null;
        playShip.nav.targetShip = ships.elementAt(currentScannedShipIndex);
      }
      else if (ships.length == 1) {
        playShip.nav.targetCoord = null;
        playShip.nav.targetShip = ships.first;
      }
      else {
        playShip.nav.targetShip = null;
        playShip.nav.targetCoord = scannedCell.coord;
      }
    }
    fm.update();
  }

  void cycleScannerMode({bool forwards = true}) {
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
    if (!scannerMode.accessable) cycleScannerMode(forwards: forwards);
    reset();
    fm.update();
  }

  void cycleScannerTargetMode() {
    int i = targetPathMode.index < TargetPathMode.values.length - 1
        ? targetPathMode.index + 1
        : 0;
    targetPathMode = TargetPathMode.values.elementAt(i);
    if (targetPathMode == TargetPathMode.safest) targetPathMode = TargetPathMode.direct; // skipping safest for now
    fm.msg("Scanner Target Path Mode: ${targetPathMode.name}");
    fm.update();
  }

  void reset() {
    currentScanSelection = null;
    currentScannedShipIndex = 0;
  }

}