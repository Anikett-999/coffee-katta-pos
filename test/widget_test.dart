import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/main.dart';
import 'package:coffee_katta_pos/core/app_theme.dart';

void main() {
  test('AppTheme brand colors smoke test', () {
    expect(AppTheme.espressoBrown.toARGB32(), equals(0xFF5A3825));
    expect(AppTheme.warmCaramel.toARGB32(), equals(0xFFB77945));
    expect(AppTheme.latteCream.toARGB32(), equals(0xFFF7F4EF));
    expect(AppTheme.warmAmber.toARGB32(), equals(0xFFB77945));
    expect(AppTheme.statusAvailable.toARGB32(), equals(0xFF287A55));
    expect(AppTheme.maroon, equals(AppTheme.espressoBrown));
  });

  test('App widget can be instantiated', () {
    const app = CoffeeKattaPOSApp();
    expect(app, isNotNull);
  });
}
