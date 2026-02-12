import 'package:crawlspace_engine/controllers/scanner_controller.dart';
import 'package:crawlspace_engine/coord_3d.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'general_input.dart';

enum DepthViewOption {showAll,showClosest,toggle}

class DirectionIntent extends Intent {
  final int dx,dy,dz;
  const DirectionIntent(this.dx,this.dy,this.dz);
}

class OpenInventoryIntent extends Intent {
  const OpenInventoryIntent();
}

class InstallationIntent extends Intent {
  final bool remove;
  const InstallationIntent(this.remove);
}

class OpenPlanetMenuIntent extends Intent {
  const OpenPlanetMenuIntent();
}

class ImpulseIntent extends Intent {
  final bool enter;
  const ImpulseIntent(this.enter);
}

class HyperSpaceIntent extends Intent {
  const HyperSpaceIntent();
}

class ScannerModeIntent extends Intent {
  final bool forwards;
  final ScannerMode? mode;
  const ScannerModeIntent({this.mode,this.forwards = true});
}

class ScannerSelectionIntent extends Intent {
  final bool up;
  const ScannerSelectionIntent(this.up);
}

class ScannerTargetIntent extends Intent {
  final bool ship;
  const ScannerTargetIntent(this.ship);
}

class ScannerTargetModeIntent extends Intent {
  const ScannerTargetModeIntent();
}

class AwaitIntent extends Intent {
  const AwaitIntent();
}

class PursueIntent extends Intent {
  const PursueIntent();
}

class FireIntent extends Intent {
  const FireIntent();
}

class ScrapIntent extends Intent {
  final bool collect;
  const ScrapIntent(this.collect);
}

class LoiterIntent extends Intent {
    const LoiterIntent();
}

class DepthViewIntent extends Intent {
  final DepthViewOption depthView;
  const DepthViewIntent(this.depthView);
}

const downComboKey = LogicalKeyboardKey.shift;
const upComboKey = LogicalKeyboardKey.keyZ;

class ShipInput extends StatelessWidget with GeneralInputMixin {
  final Widget child;
  @override
  final FugueEngine fm;
  const ShipInput(this.child, this.fm, {super.key});

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: true,
      shortcuts: {
        ...generalShortcuts,
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

        LogicalKeySet(LogicalKeyboardKey.arrowUp,downComboKey):
        const DirectionIntent(0, -1, -1),
        LogicalKeySet(LogicalKeyboardKey.arrowDown,downComboKey):
        const DirectionIntent(0, 1, -1),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft,downComboKey):
        const DirectionIntent(-1, 0, -1),
        LogicalKeySet(LogicalKeyboardKey.arrowRight,downComboKey):
        const DirectionIntent(1, 0, -1),
        LogicalKeySet(LogicalKeyboardKey.end,downComboKey):
        const DirectionIntent(-1, 1, -1),
        LogicalKeySet(LogicalKeyboardKey.home,downComboKey):
        const DirectionIntent(-1, -1, -1),
        LogicalKeySet(LogicalKeyboardKey.pageUp,downComboKey):
        const DirectionIntent(1, -1, -1),
        LogicalKeySet(LogicalKeyboardKey.pageDown,downComboKey):
        const DirectionIntent(1, 1, -1),
        LogicalKeySet(LogicalKeyboardKey.clear,downComboKey):
        const DirectionIntent(0, 0, -1),

        LogicalKeySet(LogicalKeyboardKey.arrowUp,upComboKey):
        const DirectionIntent(0, -1, 1),
        LogicalKeySet(LogicalKeyboardKey.arrowDown,upComboKey):
        const DirectionIntent(0, 1, 1),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft,upComboKey):
        const DirectionIntent(-1, 0, 1),
        LogicalKeySet(LogicalKeyboardKey.arrowRight,upComboKey):
        const DirectionIntent(1, 0, 1),
        LogicalKeySet(LogicalKeyboardKey.end,upComboKey):
        const DirectionIntent(-1, 1, 1),
        LogicalKeySet(LogicalKeyboardKey.home,upComboKey):
        const DirectionIntent(-1, -1, 1),
        LogicalKeySet(LogicalKeyboardKey.pageUp,upComboKey):
        const DirectionIntent(1, -1, 1),
        LogicalKeySet(LogicalKeyboardKey.pageDown,upComboKey):
        const DirectionIntent(1, 1, 1),
        LogicalKeySet(LogicalKeyboardKey.clear,upComboKey):
        const DirectionIntent(0, 0, 1),

        LogicalKeySet(LogicalKeyboardKey.clear):
        const LoiterIntent(),

        LogicalKeySet(LogicalKeyboardKey.comma):
        const ImpulseIntent(true),

        LogicalKeySet(LogicalKeyboardKey.period):
        const ImpulseIntent(false),

        LogicalKeySet(LogicalKeyboardKey.keyL):
        const OpenPlanetMenuIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyH):
        const HyperSpaceIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyI):
        const OpenInventoryIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyS):
        const ScannerModeIntent(mode: null),

        LogicalKeySet(LogicalKeyboardKey.keyW):
        const ScannerModeIntent(mode: null, forwards: false),

        LogicalKeySet(LogicalKeyboardKey.keyQ):
        const ScannerSelectionIntent(true),

        LogicalKeySet(LogicalKeyboardKey.keyA):
        const ScannerSelectionIntent(false),

        LogicalKeySet(LogicalKeyboardKey.keyT):
        const ScannerTargetIntent(false),

        LogicalKeySet(LogicalKeyboardKey.keyT, LogicalKeyboardKey.shift):
        const ScannerTargetIntent(true),

        LogicalKeySet(LogicalKeyboardKey.minus):
        const ScannerTargetModeIntent(),

        LogicalKeySet(LogicalKeyboardKey.enter):
        const AwaitIntent(),

        LogicalKeySet(LogicalKeyboardKey.numpadAdd):
        const PursueIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyF):
        const FireIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyS, LogicalKeyboardKey.shift):
        const ScrapIntent(true),

        LogicalKeySet(LogicalKeyboardKey.keyJ):
        const ScrapIntent(false),

        LogicalKeySet(LogicalKeyboardKey.equal):
        const DepthViewIntent(DepthViewOption.toggle),

        LogicalKeySet(LogicalKeyboardKey.keyI):
        const InstallationIntent(false),

        LogicalKeySet(LogicalKeyboardKey.keyU):
        const InstallationIntent(true),

      },
      actions: {
        ...generalActions,
        DirectionIntent: CallbackAction<DirectionIntent>(
          onInvoke: (intent) { //print("Moving ship");
            if (fm.playerShip != null) {
              fm.pilotController.move(fm.playerShip!, Coord3D(intent.dx, intent.dy, intent.dz), vector: true);
            }
            return null;
          },
        ),
        OpenPlanetMenuIntent: CallbackAction(
          onInvoke: (_) {
            fm.planetsideController.planetFall();
            return null;
          },
        ),
        HyperSpaceIntent: CallbackAction(
          onInvoke: (_) {
            fm.layerTransitController.selectHyperSpaceLink();
            return null;
          },
        ),
        ScannerModeIntent: CallbackAction<ScannerModeIntent>(
          onInvoke: (intent) {
            if (intent.mode == null) {
              fm.scannerController.toggleScannerMode(forwards: intent.forwards);
            }
            return null;
          }
        ),
        LoiterIntent: CallbackAction<LoiterIntent>(
            onInvoke: (_) {
              fm.movementController.loiter();
              return null;
            }
        ),
        ImpulseIntent: CallbackAction<ImpulseIntent>(
            onInvoke: (intent) {
              if (intent.enter) {
                fm.layerTransitController.createAndEnterImpulse();
                fm.update();
              } else {
                fm.layerTransitController.enterSublight(fm.playerShip);
              }
              return null;
            }
        ),
        ScannerSelectionIntent: CallbackAction<ScannerSelectionIntent>(
            onInvoke: (intent) {
              fm.scannerController.selectScannedObject(intent.up);
              return null;
            }
        ),
        ScannerTargetIntent: CallbackAction<ScannerTargetIntent>(
            onInvoke: (intent) {
              if (intent.ship) {
                fm.scannerController.targetShipFromScannedCell();
              } else {
                fm.scannerController.targetScannedObject(fm.playerShip,fm.scannerController.currentScanSelection);
              }
              return null;
            }
        ),
        ScannerTargetModeIntent: CallbackAction<ScannerTargetModeIntent>(
          onInvoke: (_) {
           fm.scannerController.cycleScannerTargetMode();
           return null;
          }
        ),
        AwaitIntent: CallbackAction<AwaitIntent>(
            onInvoke: (_) {
              fm.combatController.awaitNextWeapon(fm.playerShip);
              return null;
            }
        ),
        PursueIntent: CallbackAction<PursueIntent>(
            onInvoke: (_) {
              fm.combatController.pursue(fm.playerShip);
              return null;
            }
        ),
        FireIntent: CallbackAction<FireIntent>(
            onInvoke: (_) {
              fm.combatController.fire(fm.playerShip);
              return null;
            }
        ),
        ScrapIntent: CallbackAction<ScrapIntent>(
            onInvoke: (intent) {
              if (intent.collect) {
                fm.combatController.scrap();
              } else {
                fm.combatController.jettison(fm.playerShip);
              }
              return null;
            }
        ),
        DepthViewIntent: CallbackAction<DepthViewIntent>(
            onInvoke: (intent) {
              if (intent.depthView == DepthViewOption.toggle) {
                fm.scannerController.showAllCellsOnZPlane = !fm.scannerController.showAllCellsOnZPlane;
                fm.update();
              }
              return null;
            }
        ),
        InstallationIntent: CallbackAction<InstallationIntent>(
            onInvoke: (intent) {
              if (fm.playerShip != null) {
                if (intent.remove) {
                  fm.menuController.showMenu(fm.menuController.createUninstallMenu(fm.playerShip!));
                } else {
                  fm.menuController.showMenu(fm.menuController.createInstallMenu(fm.playerShip!));
                }
              }
              return null;
            }
        ),
      },
      child: child,
    );
  }
}
