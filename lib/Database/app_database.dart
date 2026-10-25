import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppDatabase {
  // ============================================================
  // BOX NAMES
  // ============================================================

  static const String residentsBoxName = 'residents';
  static const String roomsBoxName = 'rooms';
  static const String paymentsBoxName = 'payments';
  static const String settingsBoxName = 'settings';
  static const String smsHistoryBoxName = 'smsHistory';

  // Temporary legacy box while we rebuild the old modules.
  static const String legacyRegistrationsBoxName = 'registrations';

  // ============================================================
  // INITIALIZE DATABASE
  // ============================================================

  static Future<void> initialize() async {
    await Hive.initFlutter();

    await Hive.openBox(residentsBoxName);
    await Hive.openBox(roomsBoxName);
    await Hive.openBox(paymentsBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(smsHistoryBoxName);

    // Keep this temporarily so the current Registration,
    // Rooms and Reports pages do not break while we migrate them.
    await Hive.openBox(legacyRegistrationsBoxName);

    await _seedSettings();
    await _seedRooms();
  }

  // ============================================================
  // PASSWORD HASH
  // ============================================================

  static String hashPassword(String password) {
    return sha256
        .convert(
          utf8.encode(password),
        )
        .toString();
  }

  // ============================================================
  // DEFAULT SETTINGS
  // ============================================================

  static Future<void> _seedSettings() async {
    final Box settings =
        Hive.box(settingsBoxName);

    if (!settings.containsKey('username')) {
      await settings.put(
        'username',
        'admin',
      );
    }

    if (!settings.containsKey('passwordHash')) {
      await settings.put(
        'passwordHash',
        hashPassword('123456'),
      );
    }

    if (!settings.containsKey('dormitoryName')) {
      await settings.put(
        'dormitoryName',
        'Laila Dormitory',
      );
    }

    if (!settings.containsKey('monthlyRate')) {
      await settings.put(
        'monthlyRate',
        3500.0,
      );
    }

    if (!settings.containsKey('billingDays')) {
      await settings.put(
        'billingDays',
        30,
      );
    }

    if (!settings.containsKey('dueSoonDays')) {
      await settings.put(
        'dueSoonDays',
        3,
      );
    }
    
    if (!settings.containsKey('autoCloudSync')) {
      await settings.put(
        'autoCloudSync',
        true,
      );
    }
  }

  // ============================================================
  // INITIAL 150 ROOMS
  // ============================================================

  static Future<void> _seedRooms() async {
    final Box rooms =
        Hive.box(roomsBoxName);

    for (int roomNumber = 1;
        roomNumber <= 150;
        roomNumber++) {
      if (!rooms.containsKey(roomNumber)) {
        await rooms.put(
          roomNumber,
          {
            'roomNumber': roomNumber,
            'isActive': true,
            'createdAt':
                DateTime.now()
                    .toIso8601String(),
          },
        );
      }
    }
  }
}