import 'package:crawlspace_engine/controllers/movement_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/geometry/sector.dart';
import 'package:crawlspace_engine/ship/nav.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:flutter/material.dart';
import 'ascii_gridcell_widget.dart';

class AsciiGrid extends StatefulWidget {
  final FugueEngine fugueModel;
  const AsciiGrid(this.fugueModel, {super.key});

  @override
  State<StatefulWidget> createState() => _AsciiGridState();
}

class _AsciiGridState extends State<AsciiGrid> {
  bool showAllCellsOnZPlane = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    MovementPreview? preview;
    final fm = widget.fugueModel;
    final ship = fm.playerShip;
    if (fm.inputMode == InputMode.movementTarget &&
        ship != null &&
        fm.player.targetLoc != null) {
      preview = ship.nav.movePreviewer.previewFixedStep(
          state: NavState.fromShip(ship),
          ctx: MoveContext.fromShip(ship),
          desiredCell: fm.player.targetLoc!.cell,
          selecting: true
      );
    }

    double cellScaleFactor = 1;
    return LayoutBuilder(builder: (ctx,bc) {
      final playship = widget.fugueModel.playerShip;
      if (playship != null) {
        final map = playship.loc.map;
        List<Widget> stacks = [];
        int mapSize = playship.loc.map.size;
        final cellWidth = (bc.maxWidth / mapSize) * cellScaleFactor;
        final cellHeight = (bc.maxHeight / mapSize) * cellScaleFactor;
        final scannedCell =
            fm.playerShip?.nav.targetShip?.loc.cell ??
                fm.scannerController.currentScanSelection;
        for (int y = 0; y < mapSize; y++) {
          for (int x = 0; x < mapSize; x++) {
            final widgets = createStack(x,y,cellHeight/2,map,playship,scannedCell,preview,
                showAllCellsOnZPlane: fm.scannerController.showAllCellsOnZPlane);
            stacks.add(ColoredBox(color: Colors.black, child: Stack(
                alignment: Alignment.center,
                children: List.generate(widgets.length, (depth) {
                  final widget = widgets.elementAt(depth);
                  final z = widget.cell.coord.z;
                  final maxZ = mapSize - 1;
                  final t = maxZ > 0 ? z / maxZ : 0.0;
                  final cellSize = cellHeight / 2;
                  final xPos = (cellWidth - cellSize) * t;
                  final yPos = (cellHeight - cellSize) * t;
                  return Positioned(
                    left: xPos,
                    top: yPos,
                    child: widget,
                  );
                })),
            ));
          }
        }
        return Container(color: Colors.white, width: bc.maxWidth, height: bc.maxHeight,
            child: Padding(padding: const EdgeInsets.all(1.0), child: GridView.count(
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              crossAxisCount: map.size,
              childAspectRatio: bc.maxWidth / bc.maxHeight,
              children: stacks,
            )));
      }
      return const Text("No ship");
    });
  }

  Set<Ship> shipsAt(GridCell cell) {
    return widget.fugueModel.shipRegistry.atCell(cell);
  }

  List<GridCellWidget> createStack(int x, int y, double size, CellMap<GridCell> map, Ship playship,
      GridCell? scannedCell, MovementPreview? preview, {showAllCellsOnZPlane = true}) {

    GridCell closestCell = map[Coord3D(x, y, 0)]!;
    final shipCoord = playship.loc.cell.coord;
    final cellWidgets = <GridCellWidget>[];
    final invert = map is SectorMap && map.values.any((e) => e.hazLevel > 0);
    final targetPath = widget.fugueModel.scannerController.targetPath;
    for (int z = 0; z < map.size; z++) {
      final cell = map[Coord3D(x,y,z)]!;
      final uiTarget = widget.fugueModel.inputMode.targeting && widget.fugueModel.player.targetLoc?.cell == cell;
      //final scanned = scannedCell?.coord == cell.coord && playship.canScan(cell);
      final scanned = scannedCell != null
          && scannedCell.coord.x == cell.coord.x
          && scannedCell.coord.y == cell.coord.y
          && playship.canScan(cell);
      final inTargetPath = targetPath.contains(cell);
      if (showAllCellsOnZPlane) {
        cellWidgets.add(GridCellWidget(cell,size,shipsAt(cell),playship, scanned: scanned, invert: invert, uiTarget: uiTarget,
            reg: widget.fugueModel.shipRegistry, inTargetPath: inTargetPath,
          movePreviewActual: preview?.actualCell == cell,));
      }
      else {
        if (scannedCell?.coord == cell.coord) { //print("Adding scanned coord: ${cell.coord}");
          cellWidgets.add(GridCellWidget(cell,size,shipsAt(scannedCell!), playship, scanned: scanned, invert: invert, uiTarget: uiTarget,
              reg: widget.fugueModel.shipRegistry, inTargetPath: inTargetPath, movePreviewActual: preview?.actualCell == cell));
        } else {
          if (shipCoord == cell.coord) {
            closestCell = cell; break;
          }
          else if (!cell.isEmpty(widget.fugueModel.shipRegistry)) {
            if (closestCell.isEmpty(widget.fugueModel.shipRegistry) ||
                playship.distance(c: cell.coord) < playship.distance(c: closestCell.coord)) {
              closestCell = cell; //print("Closer cell: $closestCell");
            }
          }
        }
      }
    }
    if (!showAllCellsOnZPlane && (cellWidgets.isEmpty || cellWidgets.first.cell.dist(playship.loc) > closestCell.dist(playship.loc))) {
      final uiTarget = widget.fugueModel.inputMode == InputMode.target && widget.fugueModel.player.targetLoc?.cell == closestCell;
      cellWidgets.add(GridCellWidget(closestCell,size,shipsAt(closestCell), playship,
        reg: widget.fugueModel.shipRegistry, invert: invert, uiTarget: uiTarget, movePreviewActual: preview?.actualCell == closestCell));
      //if (cellWidgets.length > 1) print("adding closest coord: ${closestCell.coord}");
    } else {
      cellWidgets.sort((a, b) => a.cell.coord.z.compareTo(b.cell.coord.z)); // IMPORTANT: back → front
    }
    return cellWidgets;
  }
}




