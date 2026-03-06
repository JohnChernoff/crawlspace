import 'package:crawlspace_engine/controllers/scanner_controller.dart';
import 'package:crawlspace_engine/coord_3d.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/object.dart';
import 'package:crawlspace_engine/stock_items/corps.dart';
import 'package:crawlspace_engine/stock_items/goods.dart';
import 'package:crawlspace_flutter/main.dart';
import 'package:crawlspace_flutter/ui/views/galaxy_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'general_input.dart';

enum AlphaSelectionType {
  universalGoods,
  corporations
}

enum DepthViewOption {showAll,showClosest,toggle}
class XenoIntent extends Intent {
  const XenoIntent();
}

class SystemSelectIntent extends Intent {
  final bool unselect;
  const SystemSelectIntent(this.unselect);
}

class AlphaSelectIntent extends Intent {
  final AlphaSelectionType selectionType;
  const AlphaSelectIntent(this.selectionType);
}

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
  const ScannerTargetIntent();
}

class ScannerTargetModeIntent extends Intent {
  const ScannerTargetModeIntent();
}

class ToggleShipSystemIntent extends Intent {
  const ToggleShipSystemIntent();
}

class AwaitOrConfirmIntent extends Intent {
  const AwaitOrConfirmIntent();
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
        ...getGeneralShortcuts(context),
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

        LogicalKeySet(LogicalKeyboardKey.period):
        const ImpulseIntent(true),

        LogicalKeySet(LogicalKeyboardKey.comma):
        const ImpulseIntent(false),

        LogicalKeySet(LogicalKeyboardKey.keyL):
        const OpenPlanetMenuIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyH):
        const HyperSpaceIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyI):
        const OpenInventoryIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyA):
        const ScannerSelectionIntent(false),

        LogicalKeySet(LogicalKeyboardKey.keyQ):
        const ScannerSelectionIntent(true),

        LogicalKeySet(LogicalKeyboardKey.keyA, LogicalKeyboardKey.shift):
        const ScannerModeIntent(mode: null),

        LogicalKeySet(LogicalKeyboardKey.keyQ, LogicalKeyboardKey.shift):
        const ScannerModeIntent(mode: null, forwards: false),

        LogicalKeySet(LogicalKeyboardKey.keyT):
        const ScannerTargetIntent(),

        LogicalKeySet(LogicalKeyboardKey.minus):
        const ScannerTargetModeIntent(),

        LogicalKeySet(LogicalKeyboardKey.enter):
        const AwaitOrConfirmIntent(),

        LogicalKeySet(LogicalKeyboardKey.numpadAdd):
        const PursueIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyF):
        const FireIntent(),

        LogicalKeySet(LogicalKeyboardKey.backquote):
        const ScrapIntent(true),

        LogicalKeySet(LogicalKeyboardKey.keyJ):
        const ScrapIntent(false),

        LogicalKeySet(LogicalKeyboardKey.equal):
        const DepthViewIntent(DepthViewOption.toggle),

        LogicalKeySet(LogicalKeyboardKey.keyI,LogicalKeyboardKey.shift):
        const InstallationIntent(false),

        LogicalKeySet(LogicalKeyboardKey.keyU,LogicalKeyboardKey.shift):
        const InstallationIntent(true),

        LogicalKeySet(LogicalKeyboardKey.quoteSingle):
        const ToggleShipSystemIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyS, LogicalKeyboardKey.shift):
        const SystemSelectIntent(false),

        LogicalKeySet(LogicalKeyboardKey.keyG, LogicalKeyboardKey.shift):
        const AlphaSelectIntent(AlphaSelectionType.universalGoods),

        LogicalKeySet(LogicalKeyboardKey.keyC, LogicalKeyboardKey.shift):
        const AlphaSelectIntent(AlphaSelectionType.corporations),

        LogicalKeySet(LogicalKeyboardKey.keyZ, LogicalKeyboardKey.shift):
        const XenoIntent(),
      },
      actions: {
        ...generalActions,
        DirectionIntent: CallbackAction<DirectionIntent>(
          onInvoke: (intent) { //print("Moving ship");
            if (fm.playerShip != null) {
              if (fm.inputMode == InputMode.main) {
                fm.pilotController.move(fm.playerShip!, Coord3D(intent.dx, intent.dy, intent.dz), vector: true);
              } else if (fm.inputMode == InputMode.target) {
                fm.movementController.vectorTarget(Coord3D(intent.dx, intent.dy, intent.dz));
              }
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
              fm.scannerController.cycleScannerMode(forwards: intent.forwards);
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
              fm.scannerController.targetScannedObject(fm.scannerController.currentScanSelection);
              return null;
            }
        ),
        ScannerTargetModeIntent: CallbackAction<ScannerTargetModeIntent>(
          onInvoke: (_) {
           fm.scannerController.cycleScannerTargetMode();
           return null;
          }
        ),
        AwaitOrConfirmIntent: CallbackAction<AwaitOrConfirmIntent>(
            onInvoke: (_) {
              if (fm.inputMode == InputMode.main) {
                fm.combatController.awaitNextWeapon(fm.playerShip);
              } else if (fm.inputMode == InputMode.target) {
                fm.exitInputMode();
                fm.playerShip?.xenoControl.targetCompleter?.complete(fm.player.targetLoc);
              }
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
                fm.pilotController.scrap();
              } else {
                fm.pilotController.jettison(fm.playerShip);
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
              if (fm.playerShip != null) fm.pilotController.installSystemSelect(fm.playerShip!,uninstall: intent.remove);
              return null;
            }
        ),
        ToggleShipSystemIntent: CallbackAction<ToggleShipSystemIntent>(
            onInvoke: (_) {
              if (fm.playerShip != null) fm.pilotController.showToggleSystemMenu(fm.playerShip!);
              return null;
            }
        ),
        SystemSelectIntent: CallbackAction<SystemSelectIntent>(
            onInvoke: (intent) {
              if (intent.unselect) {
                fm.playerShip?.itinerary = null;
                fm.update();
              } else {
                fm.menuController.getAlphaList(fm.galaxy.systems).then((s) { if (s != null) fm.pilotController.plotCourse(fm.player, s); });
              }
              return null;
            }
        ),
        AlphaSelectIntent: CallbackAction<AlphaSelectIntent>(
            onInvoke: (intent) {
              List<Nameable> list = switch(intent.selectionType) {
                AlphaSelectionType.universalGoods => UniversalCommodity.values,
                AlphaSelectionType.corporations => Corporation.values,
              };
             fm.menuController.getAlphaList(list).then((g) {
                fm.menuController.selectedItem = g;
                galaxyMapLegend = GalaxyMapLegend.selection;
                currentView = ViewType.galaxy;
              });
              return null;
            }
        ),
        OpenInventoryIntent: CallbackAction<OpenInventoryIntent>(
            onInvoke: (_) {
              if (fm.playerShip != null) {
                fm.menuController.showMenu(() => fm.menuFactory.buildInventoryMenu(fm.playerShip!.inventory, shop: false),headerTxt: "Inventory");
              }
              return null;
            }
        ),
        XenoIntent: CallbackAction<XenoIntent>(
            onInvoke: (_) {
              fm.pilotController.castEffect(fm.player);
              return null;
            }
        ),
      },

      child: child,
    );
  }
}
