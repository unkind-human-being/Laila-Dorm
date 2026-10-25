import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'Authentication/Login.dart';
import 'Database/app_database.dart';
import 'Firebase/firebase_config.dart';
import 'Home/home.dart';
import 'SMS/sms_automation.dart';
import 'Sync/sync_service.dart';

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // LOCAL DATABASE
  // ==========================================================

  await AppDatabase.initialize();

  // ==========================================================
  // FIREBASE
  // ==========================================================

  await Firebase.initializeApp(
    options: FirebaseConfig.options,
  );

  // ==========================================================
  // START APP
  // ==========================================================

  runApp(
    const LailaDormitoryApp(),
  );

  // ==========================================================
  // BACKGROUND SERVICES
  //
  // Start these AFTER runApp so the UI does not wait for:
  // - cloud synchronization
  // - SMS initialization
  // ==========================================================

  unawaited(
    _startBackgroundServices(),
  );
}

// ============================================================
// BACKGROUND SERVICES
// ============================================================

Future<void> _startBackgroundServices() async {
  // ==========================================================
  // CLOUD SYNC
  // ==========================================================

  try {
    await SyncService.instance
        .startAutoSync();
  } catch (error) {
    debugPrint(
      'Cloud sync startup error: $error',
    );
  }

  // ==========================================================
  // AUTOMATIC SMS
  // ==========================================================

  try {
    await SmsAutomation.start();
  } catch (error) {
    debugPrint(
      'SMS automation startup error: $error',
    );
  }
}

// ============================================================
// APP
// ============================================================

class LailaDormitoryApp
    extends StatelessWidget {
  const LailaDormitoryApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title:
          'Laila Dormitory Monitoring System',

      // ========================================================
      // THEME
      // ========================================================

      theme: ThemeData(
        useMaterial3: true,

        colorScheme:
            ColorScheme.fromSeed(
          seedColor:
              const Color(
            0xFF17617D,
          ),
        ),

        scaffoldBackgroundColor:
            const Color(
          0xFFF5F7FA,
        ),

        // ======================================================
        // INPUT FIELDS
        // ======================================================

        inputDecorationTheme:
            InputDecorationTheme(
          filled: true,

          fillColor:
              const Color(
            0xFFF9FAFB,
          ),

          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),

          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            borderSide:
                const BorderSide(
              color:
                  Color(
                0xFFD0D5DD,
              ),
            ),
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            borderSide:
                const BorderSide(
              color:
                  Color(
                0xFF17617D,
              ),
              width: 1.5,
            ),
          ),
        ),

        // ======================================================
        // BUTTONS
        // ======================================================

        elevatedButtonTheme:
            ElevatedButtonThemeData(
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                const Color(
              0xFF17617D,
            ),

            foregroundColor:
                Colors.white,

            padding:
                const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),

            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
          ),
        ),

        outlinedButtonTheme:
            OutlinedButtonThemeData(
          style:
              OutlinedButton.styleFrom(
            foregroundColor:
                const Color(
              0xFF17617D,
            ),

            side:
                const BorderSide(
              color:
                  Color(
                0xFF17617D,
              ),
            ),

            padding:
                const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),

            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
          ),
        ),

        // ======================================================
        // CARDS
        // ======================================================

        cardTheme:
            CardThemeData(
          color:
              Colors.white,

          elevation:
              0,

          margin:
              EdgeInsets.zero,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),

            side:
                const BorderSide(
              color:
                  Color(
                0xFFE4E7EC,
              ),
            ),
          ),
        ),

        // ======================================================
        // SNACKBAR
        // ======================================================

        snackBarTheme:
            SnackBarThemeData(
          behavior:
              SnackBarBehavior.floating,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),
        ),
      ),

      // ========================================================
      // START PAGE
      // ========================================================

      initialRoute: '/login',

      // ========================================================
      // ROUTES
      // ========================================================

      routes: {
        '/login': (
          context,
        ) =>
            const LoginPage(),

        '/home': (
          context,
        ) =>
            const HomePage(),
      },
    );
  }
}