import 'dart:math';
import 'package:crawlspace_engine/fugue_engine.dart';

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

  String? effectPerTurn(Ship ship, int turns, FugueEngine fm) {
    final cell = ship.loc.cell;
    if (fm.effectRnd.nextDouble() < (cell.hazMap[this] ?? 0)) {
      if (this == Hazard.ion) {
        final system = ship.systemControl.getInstalledSystems().elementAt(
            fm.effectRnd.nextInt(ship.systemControl.getInstalledSystems().length));
        final dmg = (fm.effectRnd.nextDouble() * (cell is ImpulseCell ? .025 : .01)) * turns;
        system.takeDamage(dmg);
        return "${ship.name} takes ${(dmg * 100).round()}% ion damage to ${system.name}...";
      }
      if (this == Hazard.roid) {
        final dmg = fm.effectRnd.nextInt(cell is ImpulseCell ? 10 : 40) * turns;
        fm.combatController.damage(ship, dmg, DamageType.kinetic, details: "(asteroid)");
      }
    }
    return null;
  }
}

