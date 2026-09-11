import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/providers/printer_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/widgets/auth_wrapper.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const CoffeeKattaPOSApp(),
    ),
  );

  // Remove the splash screen once the app is loaded
  FlutterNativeSplash.remove();
}

typedef ShreeRajmandirPOSApp = CoffeeKattaPOSApp;

class CoffeeKattaPOSApp extends ConsumerWidget {
  const CoffeeKattaPOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Coffee Katta POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthWrapper(),
    );
  }
}
