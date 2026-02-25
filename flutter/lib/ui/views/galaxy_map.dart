import 'dart:math';
import 'package:crawlspace_engine/agent.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_force_directed_graph/widget/force_directed_graph_controller.dart';
import 'package:flutter_force_directed_graph/widget/force_directed_graph_widget.dart';
import '../graphs/graph.dart';
import '../../main.dart';
import '../../options.dart';

enum GalaxyMapLegend {
  fed,
  tech,
  trade,
  species,
  star,
  history,
  //planets
}

class GalaxyMap extends StatefulWidget {
  final FugueEngine fugueModel;
  const GalaxyMap(this.fugueModel,{super.key});

  @override
  State<StatefulWidget> createState() => GalaxyMapState();
}

class GalaxyMapState extends State<GalaxyMap> {
  GalaxyMapLegend legend = GalaxyMapLegend.species;
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
          : systemShape(sys),
      edgesBuilder: (context, a, b, distance) {
        return Container(
          width: distance,
          height: 8,
          color: a == widget.fugueModel.player.system || b == widget.fugueModel.player.system
              ? Colors.white
              : Colors.brown,
        );
      },
    );
  }

  Widget systemShape(System sys) {
    if (sys.homeworld != null) return starSystem(sys);
    if (sys.planets.contains(widget.fugueModel.player.tradeTarget?.destination)) return diamondSystem(sys);
    return boxSystem(sys);
  }

  @override
  Widget build(BuildContext context) {
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
          Text("Graph Legend: ${legend.name} (q/w to cycle, esc to exit)",style: TextStyle(color: Colors.white)),
          Expanded(child: Container(decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage("img/galaxy.jpg"),fit: BoxFit.fill)
          ), child: graphWidget,
        )),
        ])),
    ));
  }

  Widget fancyNode(System system) {
    return switch (widget.fugueModel.agentAt(system)) {
      AgentSystemReport.none => boxSystem(system),
      AgentSystemReport.lastKnown => starSystem(system),
      AgentSystemReport.current => starSystem(system, hex: true),
    };
  }

  Widget boxSystem(System system) {
    return Container(
        decoration: BoxDecoration(
          color: systemColor(system),
          borderRadius: widget.fugueModel.player.system != system ? const BorderRadius.all(Radius.elliptical(72,24)) : null,
        ),
        width: 128,
        height: 36,
        alignment: Alignment.center,
        child: Text(system.name));
  }

  Widget starSystem(System system, {bool hex = false}) {
    return CustomPaint(
        painter: hex ? HexagramPainter(systemColor(system)) : PentagramPainter(systemColor(system)),
        child: SizedBox(
          width: 255,
          height: 128,
          child: Center(
            child: Text(system.name, style: const TextStyle(color: Colors.white)),
          ),
        ));
  }

  Widget diamondSystem(System system) {
    return CustomPaint(
        painter: DiamondPainter(systemColor(system)),
        child: SizedBox(
          width: 255,
          height: 128,
          child: Center(
            child: Text(system.name, style: const TextStyle(color: Colors.white)),
          ),
        ));
  }

  Color systemColor(System system) {
    FugueEngine fm = widget.fugueModel;
    Galaxy g = fm.galaxy;
    if (fm.player.system == system) return Colors.yellow;
    if (fm.galaxy.fedHomeSystem == system) return Colors.white;
    return switch(legend) {
      GalaxyMapLegend.star => Color(system.starClass.color.argb),
      GalaxyMapLegend.fed => fedColor(g, system), //blue
      GalaxyMapLegend.tech => techColor(g, system), //green
      GalaxyMapLegend.trade => tradeColor(g, system), //green
      GalaxyMapLegend.species => Color(g.civMod.systemSpeciesColor(system).argb),
      GalaxyMapLegend.history => switch(fm.agentAt(system)) {
        AgentSystemReport.none => system.visited ? Colors.blue : Colors.purple,
        AgentSystemReport.lastKnown => Colors.grey,
        AgentSystemReport.current => Colors.red,
      }, //GalaxyMapLegend.planets =>
    };
  }

  Color planColor(Galaxy g, System system) {
    int c = ((system.planets.length / Galaxy.maxPlanets) * 222).floor() + 32;
    return Color.fromRGBO(c,c,c,1);
  }

  Color fedColor(Galaxy g, System system) {
    int c = ((g.commerceKernel.val(system)) * 222).floor() + 32;
    return Color.fromRGBO(0, 0, c, 1);
  }

  Color techColor(Galaxy g, System system) {
    int c = ((g.commerceKernel.val(system)) * 222).floor() + 32;
    return Color.fromRGBO(0, c, 0, 1);
  }

  Color tradeColor(Galaxy g, System system) {
    int c = ((g.commerceKernel.val(system)) * 222).floor() + 32;
    return Color.fromRGBO(c, c, c, 1);
  }

}

class PentagramPainter extends CustomPainter {
  final Color color;

  PentagramPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double radius = min(size.width, size.height) / 2;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    final Path path = Path();

    for (int i = 0; i < 5; i++) {
      final double angle = (pi / 2) + (2 * pi * i * 2 / 5);
      final double x = centerX + radius * cos(angle);
      final double y = centerY - radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class HexagramPainter extends CustomPainter {
  final Color color;

  HexagramPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double radius = min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    Path triangle(double rotation) {
      final Path path = Path();
      for (int i = 0; i < 3; i++) {
        final angle = (2 * pi * i / 3) + rotation;
        final x = center.dx + radius * cos(angle);
        final y = center.dy + radius * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      return path;
    }

    canvas.drawPath(triangle(0), paint);
    canvas.drawPath(triangle(pi), paint); // flipped triangle
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DiamondPainter extends CustomPainter {
  final Color color;
  DiamondPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.4;
    final ry = size.height * 0.45;

    final path = Path()
      ..moveTo(cx, cy - ry)   // top
      ..lineTo(cx + rx, cy)   // right
      ..lineTo(cx, cy + ry)   // bottom
      ..lineTo(cx - rx, cy)   // left
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

