import 'package:crawlspace_engine/object.dart';
import 'color.dart';
import 'descriptors.dart';

enum DistrictLvl { none("-"), light("+"), medium("++"), heavy("+++");
  const DistrictLvl(this.shortString);
  bool atOrAbove(DistrictLvl lvl) {
    return index >= lvl.index;
  }
  final String shortString;
}

class Planet extends SpaceObject {
  DistrictLvl dustLvl, commLvl, resLvl;
  PlanetAge age;
  EnvType environment;
  Goods export;

  Planet(super.name,super.fedLvl,super.techLvl,this.dustLvl,this.commLvl,this.resLvl,this.age, this.environment, this.export);

  void updateDescription() { //print("Updating: ${toString()}");
    description = "$name is ${article(age.toString())} "
        "${getDescriptor(WordType.adj)} ${getDescriptor(WordType.noun)} "
        "with ${article(environment.toString())} climate.  Its chief exports include $export.";
  }

  Goods getRndExport() {
    List<Goods> goods = Goods.values.where((g) => g.minTech <= techLvl &&
        (g.envList.isEmpty || g.envList.contains(environment)) &&
        (g.dustLvl.isEmpty || (g.dustLvl.first.index <= dustLvl.index && g.dustLvl.last.index >= dustLvl.index))).toList();
    goods.shuffle(); //print("${toString()} -> $goods");
    return goods.first;
  }

  String getDescriptor(WordType wordType) {
    List<PlanetDescriptor> descList = PlanetDescriptor.values.where((a) =>
      a.minInfluence <= fedLvl &&
      a.maxInfluence >= fedLvl &&
      a.minTech <= techLvl &&
      a.maxTech >= techLvl &&
      (a.resLvl.isEmpty || (a.resLvl.first.index <= resLvl.index && a.resLvl.last.index >= resLvl.index)) &&
      (a.commLvl.isEmpty || (a.commLvl.first.index <= commLvl.index && a.commLvl.last.index >= commLvl.index)) &&
      (a.dustLvl.isEmpty || (a.dustLvl.first.index <= dustLvl.index && a.dustLvl.last.index >= dustLvl.index)) &&
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
          ((resLvl.index/DistrictLvl.values.length) * 200).ceil() + 55,
          ((dustLvl.index/DistrictLvl.values.length) * 200).ceil() + 55,
          ((commLvl.index/DistrictLvl.values.length) * 200).ceil() + 55);
    }
  }

  String shortString() {
    if (known) {
      return "$name (🛡$fedLvl,⚙$techLvl, "
          "RCI: ${resLvl.shortString} ${commLvl.shortString} ${dustLvl.shortString})";
    }
    return "$name (🛡$fedLvl,⚙$techLvl)";
  }

  @override
  String toString() {
    return "$name : Fed: $fedLvl, Tech: $techLvl, RCI: ${resLvl.name}/${commLvl.name}/${dustLvl.name}";
  }
}
