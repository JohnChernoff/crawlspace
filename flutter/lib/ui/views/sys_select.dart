import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:flutter/material.dart';

class SystemSelect extends StatelessWidget {
  final FugueEngine fm;
  const SystemSelect(this.fm, {super.key});

  @override
  Widget build(BuildContext context) {
    final sysList = fm.menuController.selectedSystems;
    final prefix = fm.menuController.systemSearchPrefix;
    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.green.shade800, width: 1)),
            ),
            child: Row(
              children: [
                Text(
                  "NAVIGATE > ",
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    color: Colors.green.shade700,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  prefix.isEmpty ? "_" : prefix.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14,
                    color: Colors.greenAccent,
                    letterSpacing: 3,
                  ),
                ),
                // Blinking cursor
                if (prefix.isNotEmpty)
                  _BlinkingCursor(),
              ],
            ),
          ),

          // Result count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              "${sysList.length} SYSTEM${sysList.length != 1 ? 'S' : ''} FOUND",
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                color: Colors.green.shade800,
                letterSpacing: 2,
              ),
            ),
          ),

          // System list
          Expanded(
            child: sysList.isEmpty
                ? Center(
              child: Text(
                "NO MATCH",
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  color: Colors.green.shade900,
                  letterSpacing: 4,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: sysList.length,
              itemBuilder: (context, i) {
                final sys = sysList[i];
                final isFirst = i == 0;
                // Highlight matched prefix
                final matchLen = prefix.length;
                return InkWell(
                  onTap: () => fm.menuController.systemCompleter?.complete(sys),
                  hoverColor: Colors.green.withValues(alpha: 0.08),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: isFirst
                          ? Colors.green.withValues(alpha: 0.06)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isFirst ? Colors.greenAccent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Matched prefix highlighted
                        if (matchLen > 0 && sys.name.length >= matchLen)
                          Text(
                            sys.name.substring(0, matchLen).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 13,
                              color: Colors.greenAccent,
                              letterSpacing: 1.5,
                            ),
                          ),
                        // Rest of name
                        Text(
                          sys.name.substring(matchLen).toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 13,
                            color: Colors.green.shade400,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        // Fed/tech indicators
                        _SystemIndicator(
                          label: "F",
                          value: fm.galaxy.fedKernel.val(sys),
                          color: Colors.blue.shade300,
                        ),
                        const SizedBox(width: 8),
                        _SystemIndicator(
                          label: "T",
                          value: fm.galaxy.techKernel.val(sys),
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(width: 8),
                        // Homeworld marker
                        if (sys.homeworld != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              "✦",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade400,
                              ),
                            ),
                          ),
                        // Visited marker
                        if (sys.visited)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              "●",
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.green.shade900, width: 1)),
            ),
            child: Text(
              "TYPE TO FILTER  •  ENTER TO SELECT  •  ESC TO CANCEL",
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 9,
                color: Colors.green.shade900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemIndicator extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SystemIndicator({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 9,
            color: color.withValues(alpha: 0.5),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 3),
        Container(
          width: 28,
          height: 3,
          color: Colors.green.shade900,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0, 1),
            child: Container(color: color.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Opacity(
        opacity: _controller.value > 0.5 ? 1.0 : 0.0,
        child: const Text(
          "█",
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14,
            color: Colors.greenAccent,
          ),
        ),
      ),
    );
  }
}
