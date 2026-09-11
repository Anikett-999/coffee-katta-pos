import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/main.dart';
import 'package:coffee_katta_pos/core/app_theme.dart';

void main() {
  group('Phase 1 - Brand Identity & Palette Verification Tests', () {
    test('1. AppTheme brand color palette matches Coffee Katta specification', () {
      // Primary Espresso Brown: #4A2C11
      expect(AppTheme.espressoBrown, equals(const Color(0xFF4A2C11)));

      // Warm Coffee Caramel: #8C5835
      expect(AppTheme.warmCaramel, equals(const Color(0xFF8C5835)));

      // Latte Cream Background: #F9F6F0
      expect(AppTheme.latteCream, equals(const Color(0xFFF9F6F0)));

      // Amber Accent: #D4A373
      expect(AppTheme.warmAmber, equals(const Color(0xFFD4A373)));

      // Soft Grey: #E8ECEF
      expect(AppTheme.softGrey, equals(const Color(0xFFE8ECEF)));
    });

    test('2. Legacy Maroon is remapped to Espresso Brown (Zero Maroon)', () {
      // Old Shree Rajmandir Maroon was 0xFF650012
      const oldMaroon = Color(0xFF650012);

      // Verify maroon alias points to espressoBrown, NOT old #650012
      expect(AppTheme.maroon, equals(AppTheme.espressoBrown));
      expect(AppTheme.maroon, isNot(equals(oldMaroon)));

      // Verify cream alias points to latteCream
      expect(AppTheme.cream, equals(AppTheme.latteCream));
    });

    test('3. Table status colors match specification', () {
      // Available: Rich Emerald Green (0xFF2D6A4F)
      expect(AppTheme.statusAvailable, equals(const Color(0xFF2D6A4F)));

      // Occupied: Warm Amber (0xFFD97706)
      expect(AppTheme.statusOccupied, equals(const Color(0xFFD97706)));

      // Billing: Deep Brown (0xFF78350F)
      expect(AppTheme.statusBilling, equals(const Color(0xFF78350F)));

      // Aliases
      expect(AppTheme.successGreen, equals(AppTheme.statusAvailable));
      expect(AppTheme.occupiedOrange, equals(AppTheme.statusOccupied));
      expect(AppTheme.billingBlue, equals(const Color(0xFF1E3A8A)));
      expect(AppTheme.primaryRed, equals(const Color(0xFFDC2626)));
    });

    test('4. Root App widget title and alias verification', () {
      const app = CoffeeKattaPOSApp();
      expect(app, isNotNull);

      // Backwards-compatible typedef alias
      const legacyApp = ShreeRajmandirPOSApp();
      expect(legacyApp, isA<CoffeeKattaPOSApp>());
    });
  });

  group('Phase 1 - Multi-Platform Metadata & Rebranding File Tests', () {
    test('5. pubspec.yaml defines coffee_katta_pos package and cafe description', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('name: coffee_katta_pos'), isTrue);
      expect(pubspec.contains('Coffee Katta Specialty Cafe POS'), isTrue);
    });

    test('6. AndroidManifest.xml contains Coffee Katta POS label', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest.contains('android:label="Coffee Katta POS"'), isTrue);
    });

    test('7. build.gradle.kts defines applicationId com.coffeekatta.pos', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle.contains('applicationId = "com.coffeekatta.pos"'), isTrue);
    });

    test('8. windows/runner/main.cpp contains Coffee Katta POS — Latur window title', () {
      final cpp = File('windows/runner/main.cpp').readAsStringSync();
      expect(cpp.contains('L"Coffee Katta POS — Latur"'), isTrue);
    });

    test('9. web/index.html & manifest.json contain Coffee Katta POS', () {
      final indexHtml = File('web/index.html').readAsStringSync();
      expect(indexHtml.contains('<title>Coffee Katta POS</title>'), isTrue);
      expect(indexHtml.contains('content="Coffee Katta POS"'), isTrue);

      final manifest = File('web/manifest.json').readAsStringSync();
      expect(manifest.contains('"name": "Coffee Katta POS"'), isTrue);
      expect(manifest.contains('"short_name": "Coffee Katta"'), isTrue);
    });

    test('10. Firebase configuration is isolated to coffee-katta-pos', () {
      final firebaserc = File('.firebaserc').readAsStringSync();
      expect(firebaserc.contains('"default": "coffee-katta-pos"'), isTrue);
      expect(firebaserc.contains('shreerajmandir'), isFalse);

      final firebaseOptions = File('lib/firebase_options.dart').readAsStringSync();
      expect(firebaseOptions.contains("projectId: 'coffee-katta-pos'"), isTrue);
      expect(firebaseOptions.contains('shreerajmandir-820c7'), isFalse);

      final googleServices = File('android/app/google-services.json').readAsStringSync();
      expect(googleServices.contains('"project_id": "coffee-katta-pos"'), isTrue);
      expect(googleServices.contains('"package_name": "com.coffeekatta.pos"'), isTrue);
      expect(googleServices.contains('shreerajmandir'), isFalse);
    });
  });
}
