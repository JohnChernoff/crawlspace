import 'color.dart';

enum OptBool {
  vectorHands(false),
  vectorColors(false);
  final bool defValue;
  const OptBool(this.defValue);
}

class UiOptions {
  Map<OptBool,bool> boolOptions = {};
  GameColor gravCol = GameColors.neonPink;

  UiOptions() {
    for (final opt in OptBool.values) boolOptions[opt] = opt.defValue;
    print("Bool Options: $boolOptions");
  }

  void toggleBool(OptBool opt) => boolOptions[opt] = !(boolOptions[opt]!);

}