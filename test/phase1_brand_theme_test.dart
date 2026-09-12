import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/main.dart';
import 'package:coffee_katta_pos/core/app_theme.dart';

void main() {
  group('Phase 1 - Brand Identity & Palette Verification Tests', () {
    test('1. AppTheme brand color palette matches Coffee Katta specification', () {
      // Primary Coffee Brown: #5A3825
      expect(AppTheme.espressoBrown, equals(const Color(0xFF5A3825)));

      // Warm Coffee Caramel: #B77945
      expect(AppTheme.warmCaramel, equals(const Color(0xFFB77945)));

      // Subtle Warm Background: #F7F4EF
      expect(AppTheme.latteCream, equals(const Color(0xFFF7F4EF)));

      // Amber Accent: #B77945
      expect(AppTheme.warmAmber, equals(const Color(0xFFB77945)));

      // Soft Border Grey: #E8E1D8
      expect(AppTheme.softGrey, equals(const Color(0xFFE8E1D8)));
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
      // Available: Rich Green (0xFF287A55)
      expect(AppTheme.statusAvailable, equals(const Color(0xFF287A55)));

      // Occupied: Warm Amber (0xFFD97706)
      expect(AppTheme.statusOccupied, equals(const Color(0xFFD97706)));

      // Billing: Deep Brown (0xFF5A3825)
      expect(AppTheme.statusBilling, equals(const Color(0xFF5A3825)));

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
