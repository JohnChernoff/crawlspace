import 'dart:math';

class EffectMap<T extends Enum> {
  Map<T,int> _effectMap = {};
  Map<T,int> get map => _effectMap;

  Iterable<T> get allActive => _effectMap.entries.where((e) => e.value > 0).map((em) => em.key);
  bool get anyActive => _effectMap.values.any((v) => v > 0);
  int duration(T effect) => _effectMap[effect] ?? 0;
  bool isActive(T effect) => _effectMap.containsKey(effect) && _effectMap[effect]! > 0;
  bool addEffect(T effect, int duration) {
    final extending = isActive(effect);
    if (extending) _effectMap[effect] = _effectMap[effect]! + duration;
    else _effectMap[effect] = duration;
    return extending;
  }
  bool tick(T effect, {int amount = 1}) {
    if (_effectMap.containsKey(effect)) {
      _effectMap[effect] = max(_effectMap[effect]! - amount,0);
    } else return false;
    return _effectMap[effect]! > 0;
  }
  void tickAll({int amount = 1}) {
    for (final effect in _effectMap.keys) tick(effect, amount: amount);
  }
  bool removeEffect(T effect) => _effectMap.remove(effect) != null;
  void removeAllEffects() => _effectMap.clear();
}