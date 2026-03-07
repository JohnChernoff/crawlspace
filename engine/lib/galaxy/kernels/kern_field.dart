import 'package:crawlspace_engine/fugue_engine.dart';

import '../flow_field.dart';
import '../galaxy.dart';
import '../system.dart';

abstract class KernelOps<T> extends FlowOps<T> {}

class KernelField {
  final Galaxy galaxy;
  final Map<System, double> value = {};
  String valStr(System s) => val(s).toStringAsFixed(2);
  final double Function(int d) kernel;

  KernelField(this.galaxy, {required this.kernel});

  double val(System s) {
    if (value.containsKey(s)) {
      return value[s]!;
    }
    else {
      glog("Warning: kernel field not found for system: ${s.name}",error: true);
      return double.infinity;
    }
  }

}
