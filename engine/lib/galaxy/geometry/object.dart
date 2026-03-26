import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import 'package:crawlspace_engine/shop.dart';
import '../../color.dart';
import '../../item.dart';
import '../reg/reg.dart';

class ScanReport {
  bool get unknownLocation => !(system || sector);
  final bool system;
  final bool sector;
  const ScanReport({bool system = false, this.sector = false})
      : this.system = system || sector;
}

class SpaceEnvironment<L extends SpaceLocation> extends MassiveObject<L> {
  String get fedStr  => "${(fedLvl  * 100).round()}";
  String get techStr => "${(techLvl * 100).round()}";
  double fedLvl;
  double techLvl;

  // Typed shop fields — replacing the old untyped `Shop? shop, yard`
  SystemShop? sysShop;    // ship systems: power, engines, weapons, etc.
  ShipYard?   yard;    // ship purchase and hangar
  Market?     market;  // trade goods: commodities, species specials, house specials

  final Set<Ship> hangar = {};
  double rapport = 0; // -1–1

  SpaceEnvironment(super.name, this.fedLvl, this.techLvl,
      {super.shortDesc, super.mass = 1});
}

class SpaceObject<L extends SpaceLocation> extends Locatable<L>
    implements Nameable, Describable {
  final String name;
  String get selectionName => name;
  String get description => shortDesc ?? name;
  String? get flavor => null;
  String? shortDesc;
  bool known = false;
  ScanReport? scanned;

  GameColor objColor;
  SpaceObject(this.name, {this.shortDesc, this.objColor = GameColors.white});
}

class MassiveObject<L extends SpaceLocation> extends SpaceObject<L> {
  double mass; //1 = earth
  MassiveObject(super.name, {required this.mass, super.objColor, super.shortDesc});
}
