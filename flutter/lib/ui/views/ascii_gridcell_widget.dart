import 'dart:math';
import 'package:crawlspace_engine/grid.dart';
import 'package:crawlspace_engine/hazards.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/system.dart';
import 'package:flutter/material.dart';
import '../../options.dart';

class GridCellWidget extends StatefulWidget {
  final double size;
  final bool scanned;
  final bool targeted;
  final bool inTargetPath;
  final Ship playShip;
  final Set<Ship> ships;
  final GridCell cell;
  final bool invert;
  const GridCellWidget(this.cell,this.size,this.ships,this.playShip, {super.key, this.inTargetPath = false, this.targeted = false, this.scanned = false, this.invert = false});

  bool get sameDepth => (cell.coord.z - playShip.loc.cell.coord.z).abs() == 0;
  bool get sameDepthAndNotEmpty => sameDepth && !cell.empty(playShip.loc.level.map);
  bool get selected => scanned || targeted;
  bool get special => scanned || targeted || sameDepthAndNotEmpty;

  @override
  State<StatefulWidget> createState() => GridCellWidgetState();
}

class GridCellWidgetState extends State<GridCellWidget> {
  @override
  Widget build(BuildContext context) {
    final level = widget.playShip.loc.level;
    final maxZ = level.map.size - 1;
    final rawT = widget.cell.coord.z / maxZ;
    final t = sqrt(rawT); // boosts near depths
    final depthFactor = 0.6 + 0.6 * t; // min 0.6, max 1.2
    final opacity = 0.55 + 0.45 * t;  //final offsetY = (1 - t) * 24; // stronger offset for ASCII
    final distFromPlayer = widget.cell.coord.distance(widget.playShip.loc.cell.coord);
    final maxDist = sqrt(3) * level.map.size; // diagonal of grid
    // Normalize 0.0 → 1.0, closer = higher value
    final proximityFactor = 1.0 - (distFromPlayer / maxDist).clamp(0, 1);
    // Color intensity based on proximity
    final Color textColor;
    if (widget.selected) {
      textColor = (widget.sameDepthAndNotEmpty ? scanDepthColor : scanColor);
    }
    else if (widget.sameDepthAndNotEmpty) {
      textColor = depthColor;
    }
    else {
      textColor = Color.lerp(
          farColor,  // far away
          nearColor,      // close
          proximityFactor // * t // but also respect z-depth
      )!; //final textColor = Color.lerp(Colors.grey[500], Colors.black, t);
    }
    final baseFontSize = widget.size * 0.8; // tweak 0.7–0.9
    final fontSize = max(baseFontSize * depthFactor, widget.size * 0.45);

    return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration( //color: Colors.black,
        border: widget.inTargetPath ? Border.all(color: Colors.white, width: 1) : null
    ), child:  Center(
      child: Opacity(
        opacity: widget.special || widget.invert ? 1 : opacity,
        child: getGridChar(fontSize, textColor),
      ),
    ));
  }

  Widget getGridChar(double fontSize, Color color) {
    final style = TextStyle(
      fontFamily: 'FixedSys',
      height: 1.0,
      fontSize: fontSize,
      color: color,
    );
    List<Widget> stack = [];
    final cell = widget.cell;

    //if (widget.inTargetPath) stack.add(Text("□", style: style));

    final hazards = cell.hazMap.entries
        .where((e) => e.value > 0 && e.key != Hazard.wake)
        .map((e) => e.key)
        .toList();

    if (widget.invert) {
      if (hazards.isEmpty) {
        stack.add(Text(".", style: style.copyWith(color: widget.sameDepth ? Colors.white : Colors.cyan)));
      } else {
        stack.add(Text("#", style: widget.special ? style : style.copyWith(color: Color(hazards.first.color.argb)))); //□
      }
    } else if (hazards.isNotEmpty) {
        final hazardGlyph = _getHazardGlyph(hazards);
        stack.add(Text(hazardGlyph, style: style));
    }

    if (cell is SectorCell) {
      if (cell.planet != null) stack.add(Text("O", style: style));
      if (cell.starClass != null) stack.add(Text("✦", style: style));
      if (cell.blackHole) stack.add(Text("-", style: style));
    }

    for (final ship in widget.ships) {
      if (ship.npc) {
        final l = widget.playShip.lastKnown[ship];
        //print("${ship.name} last known loc: $l");
        if (l != null) { //TODO: draw last known elsewhere if not here
          stack.add(Text(ship.pilot.faction.species.glyph, style: style.copyWith(color: Color(ship.pilot.faction.color.argb))));
        }
      } else {
        stack.add(Text("@", style: style.copyWith(color: shipColor)));
      }
    }

    return Stack(children: stack);
  }

  String _getHazardGlyph(List<Hazard> hazards) {
    if (hazards.length == 1) {
      return hazards.first.glyph;
    }

    // Combinations get special glyphs
    final hazardSet = hazards.toSet();

    // Specific combos
    if (hazardSet.contains(Hazard.nebula) && hazardSet.contains(Hazard.ion)) {
      return '≈'; // ionized nebula
    }
    if (hazardSet.contains(Hazard.nebula) && hazardSet.contains(Hazard.roid)) {
      return '✱'; // asteroids in a nebula
    }
    if (hazardSet.contains(Hazard.ion) && hazardSet.contains(Hazard.roid)) {
      return '%'; // charged asteroids collision
    }
    if (hazardSet.contains(Hazard.gamma) && hazardSet.contains(Hazard.roid)) {
      return '§'; // irradiated rocks
    }

    // Fallback: 3+ hazards or unlisted combos
    if (hazards.length >= 3) {
      return '※'; // complex interference pattern
    }

    // Shouldn't reach here, but fallback
    //widget("WTF: $hazards");
    return hazards.firstOrNull?.glyph ?? '?';
  }

}
