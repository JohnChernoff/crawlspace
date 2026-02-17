import 'dart:async';
import 'dart:collection';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../color.dart';
import '../menu.dart';
import 'fugue_controller.dart';

class MessageController extends FugueController {
  final msgWorker = MessageQueueWorker();

  MessageController(super.fm);

  void addMsg(String txt, {int delay = 100, bool updateAfter = false, GameColor color = GameColors.white}) {
    msgWorker.addMsg(Message(text: txt, timestamp: fm.starDate(),color: color),delay: delay);
    if (updateAfter) fm.update();
  }

  void addResultMsg(ResultMessage rm, {int delay = 100, bool updateAfter = false, GameColor? color}) {
    msgWorker.addMsg(Message(text: rm.msg, timestamp: fm.starDate(),
        color: color ?? (rm.success ? GameColors.white: GameColors.red)),delay: delay);
    if (updateAfter) fm.update();
  }

}

class Message {
  final String text;
  final String timestamp;
  final GameColor? color;

  Message({
    required this.text,
    required this.timestamp,
    this.color,
  });
}

class MessageQueueWorker {
  final _controller = StreamController<IList<Message>>.broadcast();
  IList<Message> _messages = const IList.empty();

  Stream<IList<Message>> get stream => _controller.stream;

  final Queue<_QueuedMessage> _queue = Queue();
  bool isProcessing = false;
  Completer processNotifier = Completer();

  void addMsg(Message msg, {int delay = 0}) {
    _queue.add(_QueuedMessage(msg, delay));
    _processQueue();
  }

  void _processQueue() {
    if (isProcessing) return;
    isProcessing = true;
    processNotifier = Completer();
    _run();
  }

  Future<void> _run() async {
    while (_queue.isNotEmpty) {
      final qm = _queue.removeFirst();
      await Future.delayed(Duration(milliseconds: qm.delay));
      _messages = _messages.add(qm.msg);
      _controller.add(_messages);
    }
    isProcessing = false;
    processNotifier.complete();
  }
}

class _QueuedMessage {
  final Message msg;
  final int delay;
  _QueuedMessage(this.msg, this.delay);
}
