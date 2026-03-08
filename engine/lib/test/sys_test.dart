import '../stock_items/ship_systems/stock_pile.dart';
import 'package:test/test.dart';

void main() {
  test('all StockSystems can be created without error', () {
    for (final stock in StockSystem.values) {
      expect(() => stock.createSystem(), returnsNormally);
    }
  });
}
