import 'dart:async';
import 'dart:math';
import 'package:collection/collection.dart';
import '../fugue_engine.dart';
import '../galaxy/system.dart';
import '../menu.dart';
import 'fugue_controller.dart';

class MenuController extends FugueController {
  final rootMenu = MenuContext(builder: () => []);
  late final List<MenuContext> menuStack = [rootMenu];
  MenuContext get currentMenu => menuStack.last;
  String get currentMenuTitle => currentMenu.headerTxt;
  List<MenuEntry> _currentPage = [];
  List<MenuEntry> get selectionList => _currentPage;

  String _systemSearchPrefix = "";
  String get systemSearchPrefix => _systemSearchPrefix;
  void set systemSearchPrefix(String pfx) {
    _systemSearchPrefix = pfx;
    fm.menuController.selectedIndex = 0;
  }
  Completer<System?>? systemCompleter;
  List<System> get selectedSystems => fm.galaxy.systems
      .where((s) => s.name.toLowerCase().startsWith(systemSearchPrefix.toLowerCase()))
      .sorted((a,b) => a.name.compareTo(b.name)) //TODO: other sorts
      .toList();
  int selectedIndex = 0;
  System? get selectedSystem => selectedSystems.elementAtOrNull(selectedIndex);

  MenuController(super.fm);

  Future<System?> selectSystem() {
    if (fm.inputMode != InputMode.system) {
      systemCompleter = Completer();
      final prevMode = fm.inputMode;
      fm.setInputMode(InputMode.system);
      return systemCompleter!.future.whenComplete(() {
        systemSearchPrefix = "";
        fm.setInputMode(prevMode);
      });
    }
    return systemCompleter!.future;
  }

  void exitToLevel(MenuLevel level) { //print(menuStack.map((s) => s.level.name));
    if (menuStack.any((s) => s.level == level)) {
      while (currentMenu.level != level) menuStack.removeLast();
      rebuild();
    }
  }

  void exitMenu() { //print("Exit Menu called");
    if (menuStack.length > 1) menuStack.removeLast();
    if (menuStack.length > 1) {
      _rebuildMenu();
    } else {
      fm.setInputMode(InputMode.main); //TODO: what about if/when main isn't the root?
      //print("Back to main");
    }
    fm.update(noWait: true);
  }

  String letter(int n) => String.fromCharCode(n + 97);

  void confirm(String query, VoidCallback action, {VoidCallback? noAction}) {
    showMenu(() => [
      ActionEntry(letter: "y", label: "(y)es", (m) => action(), exitAfter: true),
      ActionEntry(letter: "n", label: "(n)o", (m) { noAction?.call(); }, exitAfter: true),
    ],headerTxt: query, noExit: true);
  }

  //return false if empty
  bool showMenu(MenuBuilder builder, {
    InputMode? mode, String? headerTxt, String? nothingTxt, int? maxEntries, bool? noExit, int? firstEntry, MenuLevel? level}) {
    menuStack.add(MenuContext.fromBuilder(builder, m: mode, ht: headerTxt, nt: nothingTxt, me: maxEntries, ne: noExit, fe: firstEntry, lvl: level));
    return _rebuildMenu();
  }

  void replaceTopMenu({MenuBuilder? builder, int? firstEntry}) {
    final m = currentMenu;
    if (builder != null) m.builder = builder;
    if (firstEntry != null) m.firstEntry = firstEntry;
    _rebuildMenu();
  }

  void replaceTopMenuFull(MenuBuilder builder) {
    final m = currentMenu;
    m.builder = builder;
    m.firstEntry = 0;
    _rebuildMenu();
  }

  void rebuild() {
    _rebuildMenu();
  }

  bool _rebuildMenu({emptyExit = true}) {
    if (menuStack.isEmpty) return false;

    final ctx = currentMenu;
    final full = ctx.builder();

    if (full.isEmpty) { //fm.msgController.addMsg(ctx.nothingTxt);
      if (emptyExit || ctx.noExit) { print("Hrumph");
        exitMenu();
        return false;
      }
    }

    fm.setInputMode(InputMode.menu,noUpdate: true);
    final start = ctx.firstEntry;
    final end = min(start + ctx.maxEntries, full.length);
    final page = full.sublist(start, end);

    final hasPrev = start > 0;
    final hasNext = end < full.length;

    if (hasPrev) {
      page.insert(0, ActionEntry(letter: "<", label: "Prev", (_) =>
          replaceTopMenu(firstEntry: max(start - ctx.maxEntries, 0))
      ));
    }

    if (hasNext) {
      page.add(ActionEntry(letter: ">", label: "Next", (_) =>
          replaceTopMenu(firstEntry: start + ctx.maxEntries)
      ));
    }

    if (!ctx.noExit) {
      if (full.any((m) => m.letter == "x")) {
        page.add(ActionEntry(letter: "X", label: "e(X)it", (_) => exitMenu()));
      } else {
        page.add(ActionEntry(letter: "x", label: "e(x)it", (_) => exitMenu()));
      }
    }

    _currentPage = page; //assert(page.every((e) => e is MenuEntry));

    fm.update();
    glog(menuStack.map((m)=>m.headerTxt).join(" > "));
    return true;
  }

}

/*
  //void refreshMenu() { if (_lastBuilder != null) replaceTopMenuFull(_lastBuilder!); }
//unused
/*
  void createAndShowShopMenu(Shop shop, Ship ship, bool refresh) {
    if (refresh) replaceTopMenuFull(() => createShopMenu(shop, ship));  // maxListLength: 12);
    else showMenu(() => createShopMenu(shop, ship));
  } */
 */