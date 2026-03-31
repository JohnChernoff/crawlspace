import 'dart:ui';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_flutter/main.dart';
import 'package:crawlspace_flutter/ui/views/alpha_select.dart';
import 'package:crawlspace_flutter/ui/views/new/ascii_grid_fast.dart';
import 'package:flutter/material.dart';
import '../inputs/menu_input.dart';
import '../inputs/ship_input.dart';
import '../inputs/alpha_select_input.dart';
import 'galaxy_map.dart';
import 'menu_view.dart';
import 'message_log.dart';

class AsciiView extends StatefulWidget {
  final FugueModel fugueModel;
  FugueEngine get fm => fugueModel.engine;
  const AsciiView(this.fugueModel, {super.key});

  @override
  State<StatefulWidget> createState() => AsciiViewState();
}

class AsciiViewState extends State<AsciiView> {

  @override
  Widget build(BuildContext context) { //print(widget.fugueModel.menuController.inputStack);
    return currentView == ViewType.galaxy
        ? GalaxyMap(widget.fm)
        : buildInputLayer(child: switch(widget.fm.inputMode) {
          InputMode.main || InputMode.target || InputMode.movementTarget =>  asciiView(),
          InputMode.menu => menuView(),
          InputMode.alphaSelect => AlphaSelect(widget.fm),
        }, fugueModel: widget.fm);
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
              child: MenuWidget(widget.fm),
            ))
        ]);
    });
  }

  Widget asciiView({twoShipScan = false}) {
    return ColoredBox(color: Colors.black, child: Column(children: [
      Expanded(child: Row(children: [
        Expanded(flex: 2, child: MessageLog(
            key: const ValueKey("main-log"),
            messageStream: widget.fm.msgController.msgWorker.stream)), // already stream-based, fine
        if (currentView == ViewType.normal)
          Expanded(child: ListenableBuilder(  // text panels rebuild on notify
              listenable: widget.fugueModel,
              builder: (_,__) => TextBlockWidget(
                  widget.fm.scannerController.scannerText()))),
        if (currentView == ViewType.normal)
          Expanded(child: ListenableBuilder(
              listenable: widget.fugueModel,
              builder: (_,__) => TextBlockWidget(
                  widget.fm.scannerController.statusText()))),
      ])),
      if (currentView == ViewType.normal)
        Expanded(child: Row(children: [
          Expanded(child: AspectRatio(
              aspectRatio: 2,
              child: AsciiGridFast(widget.fm)  // NOT wrapped in ListenableBuilder
          ))
        ]))
    ]));
  }
}

class TextBlockWidget extends StatelessWidget {
  final List<TextBlock> blocks;
  final bool box;
  final bool wrap;
  final bool scrollable; // true for scanner/status panels, false for menu items
  const TextBlockWidget(this.blocks, {this.box = true, this.wrap = false,
    this.scrollable = true, super.key});

  @override
  Widget build(BuildContext context) {
    List<Widget> lines = [];
    List<Widget> currentLine = [];

    for (final block in blocks) {
      currentLine.add(Text(block.txt,
          style: TextStyle(color: Color(block.color.argb),
              fontFamily: "JetBrainsMono")));
      if (block.newline) {
        lines.add(wrap
            ? Wrap(children: List.of(currentLine))
            : SingleChildScrollView(scrollDirection: Axis.horizontal,child: Row(children: List.of(currentLine))));
        currentLine = [];
      }
    }
    if (currentLine.isNotEmpty) lines.add(Row(children: currentLine));

    final content = scrollable
        ? ListView(children: lines)
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines);

    return DecoratedBox(
        decoration: BoxDecoration(
            border: box ? Border.all(color: Colors.white) : null),
        child: content);
  }
}

Widget buildInputLayer({required Widget child, required FugueEngine fugueModel}) =>
  switch (fugueModel.inputMode) {
     InputMode.main || InputMode.target || InputMode.movementTarget => ShipInput(child,fugueModel),
     InputMode.menu => MenuInput(child,fugueModel),
     InputMode.alphaSelect => SystemInput(child, fugueModel, raw: true)
};