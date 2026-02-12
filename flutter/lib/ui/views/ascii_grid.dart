import 'package:crawlspace_engine/coord_3d.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/grid.dart';
import 'package:crawlspace_engine/impulse.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:flutter/material.dart';
import 'ascii_gridcell_widget.dart';

class AsciiGrid extends StatefulWidget {
  final FugueEngine fugueModel;
  const AsciiGrid(this.fugueModel, {super.key});

  @override
  State<StatefulWidget> createState() => _AsciiGridState();
}

class _AsciiGridState extends State<AsciiGrid> {
  late FocusNode _focusNode;
  bool showAllCellsOnZPlane = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double cellScaleFactor = 1;
    return LayoutBuilder(builder: (ctx,bc) {
      final playship = widget.fugueModel.playerShip;
      if (playship != null) {
        final map = playship.loc.level.map;
        List<Widget> stacks = [];
        int mapSize = playship.loc.level.map.size;
        final cellWidth = (bc.maxWidth / mapSize) * cellScaleFactor;
        final cellHeight = (bc.maxHeight / mapSize) * cellScaleFactor;
        final scannedCell =
            widget.fugueModel.playerShip?.targetShip?.loc.cell ??
                widget.fugueModel.scannerController.currentScanSelection;
        for (int y = 0; y < mapSize; y++) {
          for (int x = 0; x < mapSize; x++) {
            final widgets = createStack(x,y,cellHeight/2,map,playship,scannedCell,
                showAllCellsOnZPlane: widget.fugueModel.scannerController.showAllCellsOnZPlane);
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
}

List<GridCellWidget> createStack(int x, int y, double size, Grid<GridCell> map, Ship playship, GridCell? scannedCell, {showAllCellsOnZPlane = true}) {
  GridCell closestCell = map.cells[Coord3D(x, y, 0)]!;
  final shipCoord = playship.loc.cell.coord;
  final cellWidgets = <GridCellWidget>[];
  final invert = map is ImpulseMap && map.cells.entries.any((e) => e.value.hazLevel > 0);
  for (int z = 0; z < map.size; z++) {
    final cell = map.cells[Coord3D(x,y,z)]!;
    final scanned = scannedCell?.coord == cell.coord;
    if (showAllCellsOnZPlane) {
      cellWidgets.add(GridCellWidget(cell,size,playship.loc.level.shipsAt(cell), playship, scanned: scanned, invert: invert,));
    }
    else {
      if (scannedCell?.coord == cell.coord) { //print("Adding scanned coord: ${cell.coord}");
        cellWidgets.add(GridCellWidget(cell,size,playship.loc.level.shipsAt(scannedCell!), playship, scanned: scanned, invert: invert,));
      } else {
        if (shipCoord == cell.coord) {
          closestCell = cell; break;
        }
        else if (!cell.empty(playship.loc.level.map)) {
          if (closestCell.empty(playship.loc.level.map) ||
              shipCoord.distance(cell.coord) < shipCoord.distance(closestCell.coord)) {
            closestCell = cell; //print("Closer cell: $closestCell");
          }
        }
      }
    }
  }
  if (!showAllCellsOnZPlane && (cellWidgets.isEmpty || cellWidgets.first.cell.coord.distance(shipCoord) > closestCell.coord.distance(shipCoord))) {
    cellWidgets.add(GridCellWidget(closestCell,size,playship.loc.level.shipsAt(closestCell), playship, invert: invert,));
    //if (cellWidgets.length > 1) print("adding closest coord: ${closestCell.coord}");
  } else {
    cellWidgets.sort((a, b) => a.cell.coord.z.compareTo(b.cell.coord.z)); // IMPORTANT: back → front
  }
  return cellWidgets;
}


