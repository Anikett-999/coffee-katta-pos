import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/main.dart';
import 'package:coffee_katta_pos/core/app_theme.dart';

void main() {
  test('AppTheme brand colors smoke test', () {
    expect(AppTheme.espressoBrown.value, equals(0xFF4A2C11));
    expect(AppTheme.warmCaramel.value, equals(0xFF8C5835));
    expect(AppTheme.latteCream.value, equals(0xFFF9F6F0));
    expect(AppTheme.warmAmber.value, equals(0xFFD4A373));
    expect(AppTheme.statusAvailable.value, equals(0xFF2D6A4F));
    expect(AppTheme.maroon, equals(AppTheme.espressoBrown));
  });

  test('App widget can be instantiated', () {
    const app = CoffeeKattaPOSApp();
    expect(app, isNotNull);
  });
}
