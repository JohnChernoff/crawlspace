import 'dart:math';
import 'color.dart';
import 'grid.dart';
import 'impulse.dart';
import 'ship.dart';
import 'systems/weapons.dart';

enum Hazard {
  nebula("Nebula","Neb","~",[Domain.system],GameColors.purple),
  ion("Ion Storm","Ion","#",[Domain.system,Domain.impulse],GameColors.coral),
  roid("Asteroids","Roid","+",[Domain.system,Domain.impulse],GameColors.gray),
  gamma("Gamma Radiation","Rad","%",[Domain.impulse],GameColors.orange),
  wake("Relativeistic Wake Turbulence","Turb","^",[Domain.impulse],GameColors.green);
  final String name;
  final String shortName;
  final String glyph;
  final List<Domain> domains;
  final GameColor color;
  const Hazard(this.name,this.shortName,this.glyph,this.domains,this.color);

  String? effectPerTurn(Ship ship, int turns, Random rnd) {
    final cell = ship.loc.cell;
    if (rnd.nextDouble() < (cell.hazMap[this] ?? 0)) {
      if (this == Hazard.ion) {
        final system = ship.getAllInstalledSystems.elementAt(
            rnd.nextInt(ship.getAllInstalledSystems.length));
        final dmg = (rnd.nextDouble() * (cell is ImpulseCell ? .25 : .1)) * turns;
        system.takeDamage(dmg);
        return "${ship.name} takes $dmg ion damage to ${system.name}...";
      }
      if (this == Hazard.roid) {
        final dmg = rnd.nextInt(cell is ImpulseCell ? 10 : 40) * turns;
        ship.takeDamage(dmg as double, DamageType.kinetic);
        return "${ship.name} takes $dmg asteroid damage...";
      }
    }
    return null;
  }
}

