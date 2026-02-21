import 'dart:math';

import 'package:crawlspace_engine/object.dart';
import 'color.dart';
import 'descriptors.dart';

enum DistrictLvl { none("-"), light("+"), medium("++"), heavy("+++");
  const DistrictLvl(this.shortString);
  bool atOrAbove(DistrictLvl lvl) => index >= lvl.index;
  final String shortString;
}

class Planet extends SpaceObject {
  late PlanetAge age;
  late EnvType environment;
  late Goods export;
  double industry;   // 0–1
  double commerce;   // 0–1
  double population; // 0–1
  double hazard = 0;     // 0–1 (dust, radiation, etc.)
  double weirdness = 0;

  DistrictLvl tier(double v) {
    if (v < 0.2) return DistrictLvl.none;
    if (v < 0.4) return DistrictLvl.light;
    if (v < 0.7) return DistrictLvl.medium;
    return DistrictLvl.heavy;
  }

  Planet(super.name,super.fedLvl,super.techLvl,Random rnd,{
    required this.industry,
    required this.commerce,
    required this.population}) {
    weirdness = rnd.nextDouble();
    age = PlanetAge.values.elementAt(rnd.nextInt(PlanetAge.values.length));
    environment = EnvType.values.elementAt(rnd.nextInt(EnvType.values.length));
    export = Goods.values.elementAt(rnd.nextInt(Goods.values.length));
  }

  void updateDescription() { //print("Updating: ${toString()}");
    description = "$name is ${article(age.toString())} "
        "${getDescriptor(WordType.adj)} ${getDescriptor(WordType.noun)} "
        "with ${article(environment.toString())} climate.  Its chief exports include $export.";
  }

  Goods getRndExport() {
    List<Goods> goods = Goods.values.where((g) => g.minTech <= techLvl &&
        (g.envList.isEmpty || g.envList.contains(environment)) &&
        (g.dustLvl.isEmpty || (g.dustLvl.first.index <= tier(industry).index && g.dustLvl.last.index >= tier(industry).index))).toList();
    goods.shuffle(); //print("${toString()} -> $goods");
    return goods.first;
  }

  String getDescriptor(WordType wordType) {
    List<PlanetDescriptor> descList = PlanetDescriptor.values.where((a) =>
      a.minInfluence <= fedLvl &&
      a.maxInfluence >= fedLvl &&
      a.minTech <= techLvl &&
      a.maxTech >= techLvl &&
      (a.resLvl.isEmpty || (a.resLvl.first.index <= tier(population).index && a.resLvl.last.index >= tier(population).index)) &&
      (a.commLvl.isEmpty || (a.commLvl.first.index <= tier(commerce).index && a.commLvl.last.index >= tier(commerce).index)) &&
      (a.dustLvl.isEmpty || (a.dustLvl.first.index <= tier(industry).index && a.dustLvl.last.index >= tier(industry).index)) &&
      a.wordType == wordType).toList();
    descList.shuffle(); //print("Updating: ${toString()} -> $descList");
    return descList.isEmpty ? "?" : descList.first.toString();
  }

  GameColor color({required bool fedTech}) {
    if (fedTech) {
      return GameColor.fromRgb(
          255,
          ((techLvl/100) * 200).ceil() + 55,
          ((fedLvl/100) * 200).ceil() + 55);
    } else {
      return GameColor.fromRgb(
          ((tier(population).index/DistrictLvl.values.length) * 200).ceil() + 55,
          ((tier(commerce).index/DistrictLvl.values.length) * 200).ceil() + 55,
          ((tier(industry).index/DistrictLvl.values.length) * 200).ceil() + 55);
    }
  }

  String shortString() {
    if (known) {
      return "$name (🛡$fedStr,⚙$techStr, "
          "RCI: ${tier(population).shortString} ${tier(commerce).shortString} ${tier(industry).shortString})";
    }
    return "$name (🛡$fedStr,⚙$techStr)";
  }

  @override
  String toString() {
    return "$name : Fed: $fedStr, Tech: $techStr, RCI: ${tier(population).name}/${tier(commerce).name}/${tier(industry).name}";
  }
}
