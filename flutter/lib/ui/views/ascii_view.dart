import 'dart:ui';
import 'package:crawlspace_engine/controllers/menu_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_flutter/main.dart';
import 'package:flutter/material.dart';
import '../inputs/menu_input.dart';
import '../inputs/ship_input.dart';
import 'ascii_grid.dart';
import 'galaxy_map.dart';
import 'menu_view.dart';
import 'message_log.dart';

class AsciiView extends StatefulWidget {
  final FugueEngine fugueModel;
  const AsciiView(this.fugueModel, {super.key});

  @override
  State<StatefulWidget> createState() => AsciiViewState();
}

class AsciiViewState extends State<AsciiView> {

  @override
  Widget build(BuildContext context) { //print(widget.fugueModel.menuController.inputStack);
    return currentView == ViewType.galaxy
        ? GalaxyMap(widget.fugueModel)
        : widget.fugueModel.menuController.inputMode.showMenu
            ? menuView()
            : buildInputLayer(child: asciiView(), fugueModel: widget.fugueModel);
  }

  Widget menuView() {
    return LayoutBuilder(builder: (ctx,bc) {
      double w4 = bc.maxWidth / 4;
      double h4 = bc.maxHeight / 4;
      return Stack(children: [
        asciiView(),
        // Blur overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 5),
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ),
        Positioned(
            left: w4,
            top: h4 / 2,
            child: Container(
              color: Colors.black,
              width: w4 * 2,
              height: h4 * 3 ,
              child: MenuWidget(widget.fugueModel),
            ))
        ]);
    });
  }

  Widget asciiView() {
    return ColoredBox(color: Colors.black,child: Column(children: [
        Expanded(child: Row(children: [
          Expanded(flex: 3, child:
            MessageLog(key: const ValueKey("main-log"), messageStream: widget.fugueModel.msgController.msgWorker.stream)
          ),
          if (currentView == ViewType.normal) Expanded(child: TextBlockWidget(widget.fugueModel.scannerController.scannerText())),
          if (currentView == ViewType.normal) Expanded(child: TextBlockWidget(widget.fugueModel.scannerController.statusText()))
        ])),
        if (currentView == ViewType.normal) Expanded(child: Row(children: [ //const ColoredBox(color: Colors.grey),
          Expanded(child: AspectRatio(aspectRatio: 2, child: AsciiGrid(widget.fugueModel)))
        ]))
      ]));
  }
}

class TextBlockWidget extends StatelessWidget {
  final List<TextBlock> blocks;

  const TextBlockWidget(this.blocks, {super.key});

  @override
  Widget build(BuildContext context) { //print("TextBlockWidget building with blocks: ${blocks.length}");
    List<Widget> lines = [];
    List<Widget> currentLine = [];

    for (final block in blocks) { //print(block.txt);
      currentLine.add(Text(block.txt, style: TextStyle(color: Color(block.color.argb), fontFamily: "JetBrainsMono")));

      if (block.newline) { //print("Adding line, len: ${currentLine.length}");
        lines.add(SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: currentLine)));
        currentLine = [];
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(Row(children: currentLine));
    }

    return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white)
        ),
        child: ListView(children: lines)
    );
  }

}

Widget buildInputLayer({required Widget child, required FugueEngine fugueModel}) =>
  switch (fugueModel.menuController.inputMode) {
     InputMode.main => ShipInput(child,fugueModel),
     InputMode.menu => MenuInput(child, fugueModel),
     InputMode.planet => MenuInput(child, fugueModel)
};