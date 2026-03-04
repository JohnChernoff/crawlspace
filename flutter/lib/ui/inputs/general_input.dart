import 'package:audioplayers/audioplayers.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_flutter/options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart';

class VersionIntent extends Intent {
  const VersionIntent();
}

class HelpIntent extends Intent {
  const HelpIntent();
}

class ViewSelection extends Intent {
  final ViewType viewType;
  const ViewSelection(this.viewType);
}

class CancelToMainIntent extends Intent {
  const CancelToMainIntent();
}

enum AudioChoice {nextTrack,togglePause}
class AudioIntent extends Intent {
  final AudioChoice choice;
  const AudioIntent(this.choice);
}

class OptionIntent extends Intent {
  final BuildContext ctx;
  const OptionIntent(this.ctx);
}

mixin GeneralInputMixin {
  FugueEngine get fm;

  Map<LogicalKeySet, Intent> getGeneralShortcuts(BuildContext ctx) => {
    LogicalKeySet(LogicalKeyboardKey.keyO, LogicalKeyboardKey.shift):
    OptionIntent(ctx),

    LogicalKeySet(LogicalKeyboardKey.keyM):
    const AudioIntent(AudioChoice.togglePause),

    LogicalKeySet(LogicalKeyboardKey.keyN):
    const AudioIntent(AudioChoice.nextTrack),

    LogicalKeySet(LogicalKeyboardKey.keyH, LogicalKeyboardKey.shift):
    const HelpIntent(),

    LogicalKeySet(LogicalKeyboardKey.keyM, LogicalKeyboardKey.shift):
    ViewSelection(currentView == ViewType.galaxy ? ViewType.normal : ViewType.galaxy),

    LogicalKeySet(LogicalKeyboardKey.space):
    ViewSelection(currentView == ViewType.textOnly ? ViewType.normal : ViewType.textOnly),

    LogicalKeySet(LogicalKeyboardKey.keyV):
    const VersionIntent(),
  };

  Map<Type, Action<Intent>> get generalActions => {
    VersionIntent: CallbackAction<VersionIntent>(
        onInvoke: (_) { //print("Full Screen Toggle");
          fm.msgController.addMsg("Crawlspace, version ${fm.version}");
          return null;
        }
    ),
    HelpIntent: CallbackAction<HelpIntent>(
        onInvoke: (_) {
          rootBundle.loadString('assets/help/help.txt').then((file) => fm.msgController.addMsg(file));
          return null;
        }
    ),
    ViewSelection: CallbackAction<ViewSelection>(
        onInvoke: (vt) { //print("Full Screen Toggle");
          currentView = vt.viewType;
          fm.update();
          return null;
        }
    ),
    AudioIntent: CallbackAction<AudioIntent>(
        onInvoke: (intent) {
          switch(intent.choice) {
            case AudioChoice.nextTrack: fm.audioController.newTrack(); break;
            case AudioChoice.togglePause: {
              if (fuguePlayer.state == PlayerState.paused) {
                fuguePlayer.resume();
              } else {
                fuguePlayer.pause();
              }
            }
          }
          return null;
        }
    ),
    OptionIntent: CallbackAction<OptionIntent>(
      onInvoke: (intent) {
        PlayerOptions.editPlayerOptions(intent.ctx,fuguePlayer);
        return null;
      }
    ),
  };
}