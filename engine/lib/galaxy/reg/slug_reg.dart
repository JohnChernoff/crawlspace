import 'package:crawlspace_engine/controllers/combat_controller.dart';
import 'package:crawlspace_engine/galaxy/geometry/impulse.dart';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

class SlugReg extends ImpulseRegistry<ImpulseSlug> {
  ImpulseSlug? nextSlugPosition(ImpulseCell cell) {
    for (final slug in inSector(cell.loc.sector)) {
      if (slug.nextCoord == cell.coord) return slug;
    }
    return null;
  }
}