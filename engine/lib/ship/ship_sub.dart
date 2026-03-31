import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/ship/systems/ship_sys.dart';
import '../galaxy/geometry/location.dart';
import 'nav/nav.dart';

class ShipSubSystem {
  ShipNav get nav => ship.nav;
  SpaceLocation get loc => ship.loc;
  ShipSystemControl get systemControl => ship.systemControl;
  final Ship ship;

  ShipSubSystem(this.ship);
}