import 'package:crawlspace_engine/galaxy/sub_model.dart';
import 'flow_field.dart';

class FlowManager extends GalaxySubMod {
  final Map<String, FlowField> fields = {};
  final FlowScheduler scheduler = FlowScheduler();

  FlowManager(super.galaxy);

  void register(String name, FlowField f, int period) {
    fields[name] = f;
    scheduler.register(name, period, galaxy.rnd);
  }

  void tick() {
    for (final k in fields.keys) {
      if (scheduler.shouldTick(k)) fields[k]!.tick();
    }
  }
}


