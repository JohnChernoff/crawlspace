import 'package:crawlspace_engine/controllers/layer_transit_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/ship/nav/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DirectionIntent extends Intent {
  final int dx,dy,dz;
  const DirectionIntent(this.dx,this.dy,this.dz);
}

class StopIntent extends Intent {
  const StopIntent();
}

class CruiseIntent extends Intent {
  const CruiseIntent();
}

class ThrottleIntent extends Intent {
  final ThrottleMode mode;
  const ThrottleIntent(this.mode);
}

class DomainIntent extends Intent {
  final DomainDir dir;
  const DomainIntent(this.dir);
}

class AutoPilotIntent extends Intent {
  final AutoPilotMode mode;
  const AutoPilotIntent(this.mode);
}

mixin ShipMovementMixin {
  FugueEngine get fm;

  static const downComboKey = LogicalKeyboardKey.shift;
  static const upComboKey = LogicalKeyboardKey.keyZ;

  Map<LogicalKeySet, Intent> getMovementShortcuts(BuildContext ctx) => {

      LogicalKeySet(LogicalKeyboardKey.f1):
        const DirectionIntent(0, -1, 0),
      LogicalKeySet(LogicalKeyboardKey.f2):
        const DirectionIntent(0, 1, 0),
      LogicalKeySet(LogicalKeyboardKey.f3):
        const DirectionIntent(-1, 0, 0),
      LogicalKeySet(LogicalKeyboardKey.f4):
        const DirectionIntent(1, 0, 0),

      LogicalKeySet(LogicalKeyboardKey.arrowUp):
        const DirectionIntent(0, -1, 0),
        LogicalKeySet(LogicalKeyboardKey.arrowDown):
        const DirectionIntent(0, 1, 0),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
        const DirectionIntent(-1, 0, 0),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
        const DirectionIntent(1, 0, 0),
        LogicalKeySet(LogicalKeyboardKey.end):
        const DirectionIntent(-1, 1, 0),
        LogicalKeySet(LogicalKeyboardKey.home):
        const DirectionIntent(-1, -1, 0),
        LogicalKeySet(LogicalKeyboardKey.pageUp):
        const DirectionIntent(1, -1, 0),
        LogicalKeySet(LogicalKeyboardKey.pageDown):
        const DirectionIntent(1, 1, 0),

        LogicalKeySet(LogicalKeyboardKey.arrowUp, downComboKey):
        const DirectionIntent(0, -1, -1),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, downComboKey):
        const DirectionIntent(0, 1, -1),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, downComboKey):
        const DirectionIntent(-1, 0, -1),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, downComboKey):
        const DirectionIntent(1, 0, -1),
        LogicalKeySet(LogicalKeyboardKey.end, downComboKey):
        const DirectionIntent(-1, 1, -1),
        LogicalKeySet(LogicalKeyboardKey.home, downComboKey):
        const DirectionIntent(-1, -1, -1),
        LogicalKeySet(LogicalKeyboardKey.pageUp, downComboKey):
        const DirectionIntent(1, -1, -1),
        LogicalKeySet(LogicalKeyboardKey.pageDown, downComboKey):
        const DirectionIntent(1, 1, -1),
        LogicalKeySet(LogicalKeyboardKey.clear, downComboKey):
        const DirectionIntent(0, 0, -1),

        LogicalKeySet(LogicalKeyboardKey.arrowUp, upComboKey):
        const DirectionIntent(0, -1, 1),
        LogicalKeySet(LogicalKeyboardKey.arrowDown, upComboKey):
        const DirectionIntent(0, 1, 1),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft, upComboKey):
        const DirectionIntent(-1, 0, 1),
        LogicalKeySet(LogicalKeyboardKey.arrowRight, upComboKey):
        const DirectionIntent(1, 0, 1),
        LogicalKeySet(LogicalKeyboardKey.end, upComboKey):
        const DirectionIntent(-1, 1, 1),
        LogicalKeySet(LogicalKeyboardKey.home, upComboKey):
        const DirectionIntent(-1, -1, 1),
        LogicalKeySet(LogicalKeyboardKey.pageUp, upComboKey):
        const DirectionIntent(1, -1, 1),
        LogicalKeySet(LogicalKeyboardKey.pageDown, upComboKey):
        const DirectionIntent(1, 1, 1),
        LogicalKeySet(LogicalKeyboardKey.clear, upComboKey):
        const DirectionIntent(0, 0, 1),

        LogicalKeySet(LogicalKeyboardKey.clear):
        const CruiseIntent(),

        LogicalKeySet(LogicalKeyboardKey.period):
        const DomainIntent(DomainDir.down),

        LogicalKeySet(LogicalKeyboardKey.comma):
        const DomainIntent(DomainDir.up),

        LogicalKeySet(LogicalKeyboardKey.digit0):
        const ThrottleIntent(ThrottleMode.drift),

        LogicalKeySet(LogicalKeyboardKey.digit1):
        const ThrottleIntent(ThrottleMode.tenth),

        LogicalKeySet(LogicalKeyboardKey.digit2):
        const ThrottleIntent(ThrottleMode.quarter),

        LogicalKeySet(LogicalKeyboardKey.digit3):
        const ThrottleIntent(ThrottleMode.half),

        LogicalKeySet(LogicalKeyboardKey.digit4):
        const ThrottleIntent(ThrottleMode.full),

        LogicalKeySet(LogicalKeyboardKey.digit5):
        const ThrottleIntent(ThrottleMode.stop),

        LogicalKeySet(LogicalKeyboardKey.keyS):
        const StopIntent(),

        LogicalKeySet(LogicalKeyboardKey.digit1, LogicalKeyboardKey.shift):
        const AutoPilotIntent(AutoPilotMode.none),

        LogicalKeySet(LogicalKeyboardKey.digit2, LogicalKeyboardKey.shift):
        const AutoPilotIntent(AutoPilotMode.simple),

        LogicalKeySet(LogicalKeyboardKey.digit3, LogicalKeyboardKey.shift):
        const AutoPilotIntent(AutoPilotMode.enhanced),
      };

  Map<Type, Action<Intent>> get movementActions => {
    DirectionIntent: CallbackAction<DirectionIntent>(
      onInvoke: (intent) { //print("Moving ship");
        if (fm.playerShip == null) return null;
        fm.movementController.handleMove(
            fm.playerShip!,Coord3D(intent.dx, intent.dy, intent.dz));
        return null;
      },
    ),
    CruiseIntent: CallbackAction<CruiseIntent>(
        onInvoke: (_) { //fm.movementController.cruise(fm.playerShip);
          fm.movementController.loiter(fm.playerShip);
          return null;
        }
    ),
    ThrottleIntent: CallbackAction<ThrottleIntent>(
        onInvoke: (intent) {
          if (fm.playerShip != null) fm.movementController.setThrottle(intent.mode,fm.playerShip!);
          return null;
        }
    ),
    StopIntent: CallbackAction<StopIntent>(
        onInvoke: (_) {
          if (fm.playerShip != null) fm.movementController.fullStop(fm.playerShip!);
          return null;
        }
    ),
    DomainIntent: CallbackAction<DomainIntent>(
        onInvoke: (intent) {
          if (fm.playerShip != null) fm.layerTransitController.changeDomain(fm.playerShip!, intent.dir);
          return null;
        }
    ),
    AutoPilotIntent: CallbackAction<AutoPilotIntent>(
        onInvoke: (intent) {
          fm.pilotController.setAutoPilotMode(intent.mode);
          return null;
        }
    ),
  };
}