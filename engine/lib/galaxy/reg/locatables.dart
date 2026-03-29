import 'package:crawlspace_engine/galaxy/reg/reg.dart';

import '../geometry/location.dart';

abstract class Locatable<T extends SpaceLocation> {
  T? _loc;
  T get loc => _locOrThrow();
  void setRegLoc(T v) { _loc = v; }
  T? get maybeLoc => _loc;
  bool get isRegistered => _loc != null;

  T _locOrThrow() {
    final l = maybeLoc;
    if (l == null) {
      throw StateError('$runtimeType has no registered location');
    }
    return l;
  }

  void onRegistered(T loc) {
    _loc = loc;
  }

  void onRemoved() {
    _loc = null;
  }
}

abstract class Containable<T extends SpaceLocation> extends Locatable<T> {
  Locatable<T>? _container;
  Locatable<T>? get container => _container;

  bool get hasDirectLocation => _loc != null;
  bool get hasLocation => maybeLoc != null;

  @override
  T? get maybeLoc => _loc ?? container?.maybeLoc;

  @override
  void onRegistered(T loc) {
    _container = null;
    super.onRegistered(loc);
  }

  void setContainer(Locatable<T>? value) {
    if (identical(value, this)) {
      throw StateError('$runtimeType cannot contain itself');
    }

    Locatable<T>? cur = value;
    final seen = <Locatable<T>>{};

    while (cur != null) {
      if (!seen.add(cur)) {
        throw StateError('Cycle detected in containment chain');
      }
      if (identical(cur, this)) {
        throw StateError('$runtimeType cannot be contained by its descendant');
      }
      cur = cur is Containable<T> ? cur.container : null;
    }

    _container = value;
    _loc = null;
  }
}

abstract class ContainableRegistry<T extends Containable<ImpulseLocation>>
    extends ImpulseRegistry<T> {
  void contain(T obj, Locatable<ImpulseLocation> container) {
    remove(obj);
    obj.setContainer(container);
  }

  void place(T obj, ImpulseLocation loc) {
    obj.setContainer(null);
    register(obj, loc);
  }
}


