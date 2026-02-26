import 'package:crawlspace_engine/color.dart';
import 'package:crawlspace_engine/controllers/message_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_flutter/ui/views/ascii_view.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

class MenuWidget extends StatefulWidget {
  final FugueEngine fm;
  const MenuWidget(this.fm,{super.key});

  @override
  State<StatefulWidget> createState() => MenuWidgetState();
}

class MenuWidgetState extends State<MenuWidget> {
  TextStyle textStyle = const TextStyle(color: Colors.white);
  String lastMessage = "";

  @override
  Widget build(BuildContext context) {
    final list = widget.fm.menuController.selectionList;

    return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 4),
          color: Colors.black,
          borderRadius: BorderRadius.circular(16), // Adds rounded corners
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Menu Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.fm.menuController.currentMenuTitle,
                style: textStyle.copyWith(
                  fontSize: (textStyle.fontSize ?? 14) + 2, // Slightly larger title
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(
                color: Colors.white.withValues(alpha: 0.2),
                height: 1,
              ),
            ),

            // Menu Items
            Expanded(
              flex: 8,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final isEnabled = list[i].enabled;
                  final disabledString =  isEnabled ? '' : "(${list[i].disabledReason()})";
                  final letter = list[i].letter;
                  final label = list[i].label ?? "";
                  final txtBlocks = list[i].txtBlocks;
                  List<TextBlock> blocks = [];
                  if (txtBlocks.isNotEmpty) {
                    if (letter != null) blocks.add(TextBlock(" $letter ", GameColors.white, false));
                    blocks.addAll(txtBlocks);
                  }
                  final txtStyle = TextStyle(color: isEnabled ? Colors.white : Colors.grey, fontSize: textStyle.fontSize, height: 1.5);
                  final menuItem = blocks.isNotEmpty
                      ? SizedBox(height: 20.0 * ((blocks.where((b) => b.newline).length)), child: TextBlockWidget(blocks, box: false))
                      : Text(letter != null ? "$letter: $label $disabledString" : label, style: txtStyle, // Better line spacing
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    child: menuItem
                  );
                },
              ),
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(
                color: Colors.white.withValues(alpha: 0.2),
                height: 1,
              ),
            ),

            // Message Log
            SizedBox(
              height: 128,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: menuMessageLog(widget.fm.msgController.msgWorker.stream),
              ),
            ),
          ],
        ),
      );
  }

  Widget menuMessageLog(Stream<IList<Message>> messageStream) {
    return StreamBuilder<IList<Message>>( //valueListenable: notifier,
        stream: messageStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            lastMessage = snapshot.data!.last.text;
            return Text(lastMessage, style: textStyle);
          } else {
            return SizedBox.shrink();
          }
        });
  }

}

