import 'package:crawlspace_engine/pilot.dart';
import 'package:crawlspace_engine/ship_reg.dart';

class PilotRegistry {
  final Set<Pilot> _all = {};

  void add(Pilot p) => _all.add(p);
  void remove(Pilot p) => _all.remove(p);

  Iterable<Pilot> get all => _all;
  Iterable<Pilot> get npcs => _all.where((p) => p != nobody);
  Iterable<Pilot> withShips(ShipRegistry ships, {npc = true}) =>
      (npc ? npcs : all).where((p) => ships.byPilot(p) != null);
  Iterable<Pilot> withoutShips(ShipRegistry ships, {npc = true}) =>
      (npc ? npcs : all).where((p) => ships.byPilot(p) == null);
}
