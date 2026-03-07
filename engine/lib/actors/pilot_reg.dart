import 'package:crawlspace_engine/actors/pilot.dart';
import 'package:crawlspace_engine/actors/player.dart';
import 'package:crawlspace_engine/ship/ship_reg.dart';

class PilotRegistry {
  final Set<Pilot> _all = {};

  void add(Pilot p) => _all.add(p);
  void remove(Pilot p) => _all.remove(p);

  Iterable<Pilot> get all => _all.where((p) => p != nobody);
  Iterable<Pilot> get npcs => _all.where((p) => p is! Player);
  Iterable<Pilot> withShips(ShipRegistry ships, {npc = true}) =>
      (npc ? npcs : all).where((p) => ships.byPilot(p) != null);
  Iterable<Pilot> withoutShips(ShipRegistry ships, {npc = true}) =>
      (npc ? npcs : all).where((p) => ships.byPilot(p) == null);
}
