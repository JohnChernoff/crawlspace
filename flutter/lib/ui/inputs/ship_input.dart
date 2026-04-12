import 'package:crawlspace_engine/controllers/scanner_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/item.dart';
import 'package:crawlspace_engine/stock_items/corps.dart';
import 'package:crawlspace_engine/stock_items/trade/commodities.dart';
import 'package:crawlspace_engine/ui_options.dart';
import 'package:crawlspace_flutter/main.dart';
import 'package:crawlspace_flutter/ui/inputs/ship_movement.dart';
import 'package:crawlspace_flutter/ui/views/galaxy_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'general_input.dart';

enum AlphaSelectionType {
  universalGoods,
  corporations
}

enum InventoryType {
  display,
  use,
  info
}

enum DepthViewOption {showAll,showClosest,toggle}

class OptionToggleIntent extends Intent {
  final OptBool option;
  const OptionToggleIntent(this.option);
}

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

class OpenInventoryIntent extends Intent {
  final InventoryType type;
  const OpenInventoryIntent(this.type);
}

class InstallationIntent extends Intent {
  final bool remove;
  const InstallationIntent(this.remove);
}

class OpenPlanetMenuIntent extends Intent {
  const OpenPlanetMenuIntent();
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



class DepthViewIntent extends Intent {
  final DepthViewOption depthView;
  const DepthViewIntent(this.depthView);
}



class ShipInput extends StatelessWidget with GeneralInputMixin, ShipMovementMixin {
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
        ...getMovementShortcuts(context),

        LogicalKeySet(LogicalKeyboardKey.keyL):
        const OpenPlanetMenuIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyH):
        const HyperSpaceIntent(),

        LogicalKeySet(LogicalKeyboardKey.keyI):
        const OpenInventoryIntent(InventoryType.display),

        LogicalKeySet(LogicalKeyboardKey.keyU):
        const OpenInventoryIntent(InventoryType.use),

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

        LogicalKeySet(LogicalKeyboardKey.keyH, LogicalKeyboardKey.shift):
        const OptionToggleIntent(OptBool.vectorHands),

        LogicalKeySet(LogicalKeyboardKey.keyC, LogicalKeyboardKey.shift):
        const OptionToggleIntent(OptBool.vectorColors),
      },
      actions: {
        ...generalActions,
        ...movementActions,
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
                fm.xenoControl.confirmTarget();
              } else if (fm.inputMode == InputMode.movementTarget && fm.playerShip != null) {
                fm.movementController.confirmTarget();
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
              fm.combatController.fire(fm.playerShip, fm.galaxy);
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
            onInvoke: (intent) {
              if (intent.type == InventoryType.display) {
                if (fm.playerShip != null) {
                  fm.menuController.showMenu(() => fm.menuFactory
                      .buildInventoryMenu(fm.playerShip!.inventory, shop: false),headerTxt: "Inventory", describable: true);
                }
              } else if (intent.type == InventoryType.use) {
                fm.menuController.showMenu(() => fm.menuFactory.buildInventoryUseMenu(fm.player));
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
        OptionToggleIntent: CallbackAction<OptionToggleIntent>(
            onInvoke: (intent) {
              fm.uiOptions.toggleBool(intent.option);
              fm.update();
              return null;
            }
        ),
      },

      child: child,
    );
  }
}
