import 'dart:math';

//TODO: merge with Rng
class NameGenerator {
  final Random _random;
  NameGenerator(int seed) : _random = Random(seed);

  static final _prefixes = [
    "Xan", "Vor", "Zy", "Alt", "Neb", "Kel", "Tra", "Yul", "Gar", "Omn", "Qor", "Jal", "Tir", "Usk", "Fen"
  ];

  static final _roots = [
    "aris", "tan", "thar", "gorn", "lax", "der", "vek", "nar", "lux", "thor", "zun", "quar", "nova", "zent", "mir"
  ];

  static final _suffixes = [
    "ia", "on", "ar", "os", " Prime", " Major", "-VII", "-X", "-12", "ara", "eon", "ex", "or", "eth"
  ];

  static final _greekish = [
    "Alpha", "Beta", "Delta", "Epsilon", "Zeta", "Gamma", "Sigma", "Tau"
  ];

  String generatePlanetName() {
    int style = _random.nextInt(4);
    switch (style) {
      case 0:
        return _capitalize("${_pick(_prefixes)}${_pick(_roots)}${_pick(_suffixes)}");
      case 1:
        return _capitalize("${_pick(_roots)}${_pick(_suffixes)}");
      case 2:
        return "${_pick(_greekish)} ${_capitalize(_pick(_roots))}";
      case 3:
        return _capitalize("${_pick(_roots)}-${_random.nextInt(99)}");
      default:
        return _capitalize("${_pick(_prefixes)}${_pick(_roots)}");
    }
  }

  String generateSystemName() {
    return _capitalize("${_pick(_prefixes)}${_pick(_roots)}${_pick(_suffixes)}");
  }

  String _pick(List<String> list) => list[_random.nextInt(list.length)];
  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
