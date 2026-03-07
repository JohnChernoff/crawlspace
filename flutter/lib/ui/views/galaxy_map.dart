import 'dart:math';
import 'package:crawlspace_engine/actors/agent.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/system.dart';
import 'package:crawlspace_engine/item.dart';
import 'package:crawlspace_engine/stock_items/corps.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:crawlspace_flutter/ui/views/painters.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_force_directed_graph/widget/force_directed_graph_controller.dart';
import 'package:flutter_force_directed_graph/widget/force_directed_graph_widget.dart';
import '../graphs/graph.dart';
import '../../main.dart';
import '../../options.dart';

enum GalaxyMapLegend {
  history,
  fed,
  tech,
  trade,
  species,
  star,
  surveillance,
  rumors,
  corp,
  selection,
  //planets
}

class GalaxyMap extends StatefulWidget {
  final FugueEngine fugueModel;
  const GalaxyMap(this.fugueModel,{super.key});

  @override
  State<StatefulWidget> createState() => GalaxyMapState();
}

class GalaxyMapState extends State<GalaxyMap> {
  GalaxyMapLegend legend = galaxyMapLegend; //initialize from main.dart
  late final FugueGraph fugueGraph;
  late final ForceDirectedGraphController<System> _controller;
  late final FocusNode _focusNode; // Add this
  late final ForceDirectedGraphWidget graphWidget;

  @override
  void initState() {//print("InitState for Galaxy View");
    super.initState();
    _focusNode = FocusNode(); // Initialize it here
    fugueGraph = FugueGraph(widget.fugueModel.galaxy);
    _controller = ForceDirectedGraphController(graph: fugueGraph.graph, minScale: .001, maxScale: 5);
    _controller.scale = .1;
    _rebuildCache();
    _rebuildGraph();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.needUpdate();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose(); // Dispose it
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GalaxyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fugueModel != widget.fugueModel) {
      _rebuildGraph();
    }
  }

  void _cycleLegend(bool forwards) {
    _rebuildCache();
    _cachedType = null; // force _cachedItemVals to rebuild on next render
    _cachedItemVals.clear();
    setState(() {
      if (forwards) {
        if (legend.index < GalaxyMapLegend.values.length - 1) {
          legend = GalaxyMapLegend.values.elementAt(legend.index + 1);
        } else {
          legend = GalaxyMapLegend.values.first;
        }
      } else {
        if (legend.index > 0) {
          legend = GalaxyMapLegend.values.elementAt(legend.index - 1);
        } else {
          legend = GalaxyMapLegend.values.elementAt(GalaxyMapLegend.values.length - 1);
        }
      }
    }); //print("Legend: ${legend.name}");
  }

  void _rebuildGraph() { //print("Building graph...");
    graphWidget = ForceDirectedGraphWidget<System>(
      controller: _controller,
      nodesBuilder: (context, sys) =>
      fugueOptions.getBool(FugueOption.fancyGraph)
          ? fancyNode(sys)
          : systemShape(sys,
          hw: widget.fugueModel.galaxy.getHomeworldSpecies(sys),
          hq: widget.fugueModel.galaxy.corpMod.getHQ(sys)
      ),
      edgesBuilder: (context, a, b, distance) {
        return Container(
          width: distance,
          height: 8,
          color: a == widget.fugueModel.player.system || b == widget.fugueModel.player.system
              ? Colors.white
              : avgColor([systemColor(a), systemColor(b)]),
        );
      },
    );
  }

  final Map<GalaxyMapLegend, Map<System, double>> _legendCache = {}; //GalaxyMapLegend? _cachedLegend;
  Nameable? _cachedType;
  final Map<System, double> _cachedItemVals = {};

  void _rebuildCache() {
    final g = widget.fugueModel.galaxy;

    // surveillance
    final heatMap = g.heatMod.playerHeatMap;
    final heatMax = g.systems
        .map((s) => heatMap[s] ?? 0.0)
        .reduce(max);
    _legendCache[GalaxyMapLegend.surveillance] = {
      for (final s in g.systems)
        s: heatMax > 0 ? (heatMap[s] ?? 0.0) / heatMax : 0.0
    };

    // rumors
    final rumorMax = g.systems
        .map((s) => g.flowFields["rumors"]!.val(s) as double)
        .reduce(max);
    _legendCache[GalaxyMapLegend.rumors] = {
      for (final s in g.systems)
        s: rumorMax > 0
            ? (g.flowFields["rumors"]!.val(s) as double) / rumorMax
            : 0.0
    };
  }

  void _rebuildItemValCache(Nameable nameable) {
    if (_cachedType == nameable) return; // already cached
    _cachedType = nameable;
    _cachedItemVals.clear();
    final g = widget.fugueModel.galaxy;
    if (nameable is Normalizable) {
      _cachedItemVals.clear();
      _cachedItemVals.addAll(nameable.normalize(g));
    }
  }

  double getVal(Nameable? nameable, System system) {
    if (nameable == null) return 0.0;
    _rebuildItemValCache(nameable);
    return _cachedItemVals[system] ?? 0.0;
  }

  Color avgColor(List<Color> colors) {
    if (colors.isEmpty) return Colors.black;
    final a = colors.map((c) => c.a).reduce((a, b) => a + b) / colors.length;
    final r = colors.map((c) => c.r).reduce((a, b) => a + b) / colors.length;
    final g = colors.map((c) => c.g).reduce((a, b) => a + b) / colors.length;
    final b = colors.map((c) => c.b).reduce((a, b) => a + b) / colors.length;
    return Color.fromARGB(
      (a * 255).round(),
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
    );
  }

  Widget systemShape(System sys, {Species? hw, Corporation? hq}) {
    final borderCol = (widget.fugueModel.player.system == sys) ? Colors.yellowAccent : null;
    if (hw != null) {
      return hw == StockSpecies.humanoid.species
          ? diamondSystem(sys, borderCol: borderCol)
          : starSystem(sys, hex: false, borderCol: borderCol);
    }
    if (hq != null) return starSystem(sys, hex: true, borderCol: borderCol);
    if (sys.planets.contains(widget.fugueModel.player.tradeTarget?.destination)) return diamondSystem(sys, borderCol: borderCol);
    return boxSystem(sys, borderCol: borderCol);
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.fugueModel.menuController.selectedItem?.selectionName;
    return Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (fn,ev) {
          if (ev is! KeyDownEvent) return KeyEventResult.ignored;
          if (ev.logicalKey == LogicalKeyboardKey.escape) {
            setState(() {
              currentView = ViewType.normal;
              widget.fugueModel.update();
            });
            return KeyEventResult.handled;
          } else if (ev.logicalKey == LogicalKeyboardKey.keyW) {
            _cycleLegend(true);
            return KeyEventResult.handled;
          } else if (ev.logicalKey == LogicalKeyboardKey.keyQ) {
            _cycleLegend(false);
            return KeyEventResult.handled;
          } else if (ev.logicalKey == LogicalKeyboardKey.space) {
            widget.fugueModel.movementController.loiter();
            setState(() {});
          }
          return KeyEventResult.ignored;
        },
      child: Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final deltaY = event.scrollDelta.dy;
          setState(() {
            _controller.scale *= deltaY > 0 ? 0.9 : 1.1;
            _controller.scale = _controller.scale.clamp(_controller.minScale, _controller.maxScale);
            _controller.needUpdate();
          });
        }
      },
      child: GestureDetector(
        onScaleUpdate: (details) {
          setState(() {
            _controller.scale *= details.scale;
            _controller.scale = _controller.scale.clamp(_controller.minScale, _controller.maxScale);
            _controller.needUpdate();
          });
        },
        child: Column(children: [
          if (selection != null && legend == GalaxyMapLegend.selection) Text("Selection: $selection",style: TextStyle(color: Colors.white)),
          Text("Graph Legend: ${legend.name} (q/w to cycle, esc to exit)",style: TextStyle(color: Colors.white)),
          Expanded(child: Container(decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage("img/galaxy.jpg"),fit: BoxFit.fill)
          ), child: graphWidget,
        )),
        ])),
    ));
  }

  Widget fancyNode(System system) {
    return switch (widget.fugueModel.agentReport(system)) {
      AgentSystemReport.none => boxSystem(system),
      AgentSystemReport.lastKnown => starSystem(system),
      AgentSystemReport.current => starSystem(system, hex: true),
    };
  }

  Widget boxSystem(System system, {Color? borderCol}) {
    final color = systemColor(system);
    return Container(
        decoration: BoxDecoration(
          color: color,
          //borderRadius:  playSys ? const BorderRadius.all(Radius.elliptical(72,24)) : null,
          border: Border.all(color: borderCol ?? color, width: 2)
        ),
        width: 128,
        height: 36,
        alignment: Alignment.center,
        child: Text(system.name, style: TextStyle(color: constratingColor(color))));
  }

  Widget starSystem(System system, {hex = false, Color? borderCol}) {
    final color = systemColor(system);
    return CustomPaint(
        painter: hex
            ? HexagramPainter(color,borderCol: borderCol)
            : PentagramPainter(color,borderCol: borderCol),
        child: SizedBox(
          width: 255,
          height: 128,
          child: Center(
            child: Text(system.name, style: TextStyle(color: constratingColor(color))),
          ),
        ));
  }

  Widget diamondSystem(System system, {Color? borderCol}) {
    final color = systemColor(system);
    return CustomPaint(
        painter: DiamondPainter(color,borderCol: borderCol),
        child: SizedBox(
          width: 255,
          height: 128,
          child: Center(
            child: Text(system.name, style: TextStyle(color: constratingColor(color))),
          ),
        ));
  }

  Color systemColor(System system) {
    FugueEngine fm = widget.fugueModel;
    Galaxy g = fm.galaxy;  //if (fm.player.system == system) return Colors.yellow;
    if (fm.galaxy.fedHomeSystem == system) return Colors.white;
    return switch(legend) {
      GalaxyMapLegend.selection => graphColor(getVal(fm.menuController.selectedItem,system)),
      GalaxyMapLegend.corp => Color(g.corpMod.dominantCorp(system)?.color.argb ?? 0),
      GalaxyMapLegend.star => Color(system.starClass.color.argb),
      GalaxyMapLegend.fed => graphColor(g.fedKernel.val(system), red: 128, green: 0), //blue
      GalaxyMapLegend.tech => graphColor(g.techKernel.val(system), red: 0, blue: 92), //green
      GalaxyMapLegend.trade => graphColor(g.techKernel.val(system)), //white
      GalaxyMapLegend.species => Color(g.civMod.systemSpeciesColor(system).argb),
      GalaxyMapLegend.surveillance =>
          graphColor(_legendCache[GalaxyMapLegend.surveillance]?[system] ?? 0.0, green: 0, blue: 0),
      GalaxyMapLegend.rumors =>
          graphColor(_legendCache[GalaxyMapLegend.rumors]?[system] ?? 0.0, red: 128, blue: 0),
      GalaxyMapLegend.history => switch(fm.agentReport(system)) {
        AgentSystemReport.none => system.visited ?  Colors.lightBlue : Colors.deepPurple,
        AgentSystemReport.lastKnown => Colors.orange,
        AgentSystemReport.current => Colors.red,
      }, //GalaxyMapLegend.planets =>
    };
  }

  Color graphColor(double v, {int? red, int? green, int? blue, int min = 32, invRed = false, invGreen = false, invBlue = false}) {
    int c = (v * (255 - min)).floor() + min;
    int i = 255 - c;
    return Color.fromRGBO(
        red ?? (invRed ? i : c),
        green ?? (invGreen ? i : c),
        blue ?? (invBlue ? i : c), 1);
  }

  Color constratingColor(Color c) {
    final luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}


/*
  Color planColor(Galaxy g, System system) {
    int c = ((system.planets.length / Galaxy.maxPlanets) * 222).floor() + 32;
    return Color.fromRGBO(c,c,c,1);
  }
 */