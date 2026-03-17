import 'dart:async';
import '../fugue_engine.dart';
import '../galaxy/geometry/location.dart';

abstract class FugueController {
  FugueEngine fm;
  Completer<SpaceLocation>? targetCompleter;

  FugueController(this.fm);

  void confirmTarget() {
    fm.exitInputMode();
    targetCompleter?.complete(fm.player.targetLoc);
  }

}
