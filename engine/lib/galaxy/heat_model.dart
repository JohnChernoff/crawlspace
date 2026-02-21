import 'dart:math';
import 'package:crawlspace_engine/galaxy/sub_model.dart';
import 'system.dart';

class HeatModel extends GalaxySubMod {
  late Map<System,double> physicalHeat;
  late Map<System,double> socialHeat;
  late Map<System,double> playerHeatMap;
  late Map<System,double> socialConductivity;

  HeatModel(super.galaxy) {
    resetPlayerHeatMap();
    computeSocialHeat();
    computeSocialConductivity();
  }

  double detectionRisk(System s) {
    return (physicalHeat[s]! + socialHeat[s]! + playerHeatMap[s]!) * galaxy.fedMod.fedPressure[s]!;
  }

  void leakPhysicalHeat(System origin, double strength) {
    for (final s in systems) {
      final d = distance(origin,s);
      final spread = exp(-d / 4.0); // heat radius
      physicalHeat[s] = (physicalHeat[s]! + strength * spread).clamp(0, 100);
    }
  }

  void leakSocialHeat(System origin, double strength) {
    final queue = <System>[origin];
    final visited = <System>{origin};
    final dist = <System,int>{origin: 0};

    while (queue.isNotEmpty) {
      final s = queue.removeAt(0);
      final d = dist[s]!;

      final attenuation = exp(-d / 2.0); // rumor radius
      final socialAmp = socialConductivity[s]!;

      socialHeat[s] = (socialHeat[s]! + strength * attenuation * socialAmp)
          .clamp(0, 100);

      for (final n in s.links) {
        if (!visited.contains(n)) {
          visited.add(n);
          dist[n] = d + 1;
          queue.add(n);
        }
      }
    }
  }

  void resetPlayerHeatMap() {
    playerHeatMap = { for (var s in systems) s : 0.0 };
    physicalHeat = { for (var s in systems) s : 0.0 };
    socialHeat   = { for (var s in systems) s : 0.0 };
  }

  void decayHeat() {
    for (final s in systems) {
      playerHeatMap[s] =  playerHeatMap[s]! * (1 - 0.001 * galaxy.fedMod.fedPressure[s]!);
    }
  }

  void attentuateSocialHeat() {
    for (var s in systems) {
      for (var n in s.links) {
        socialHeat[n] = socialHeat[n]! * .99;
      }//s.playerHeat *= 0.99;
    }
  }

  //TODO: double-buffer?
  void computeSocialHeat() {
    for (var s in systems) {
      for (final n in s.links) {
        final w = rumorEdgeWeight(s, n);
        socialHeat[n] = socialHeat[n]! + (socialHeat[s]! * 0.1 * w);
      }
    }
  }

  void computeSocialConductivity() {
    socialConductivity = {};
    for (final s in systems) {
      socialConductivity[s] = switch (galaxy.trafficFor(s)) {
        > .75 => 2.5,
        > .25 => 1.0,
        _ => 0.2,
      };
    }
  }

  double rumorEdgeWeight(System a, System b) => galaxy.trafficFor(a) / a.links.length;

}
