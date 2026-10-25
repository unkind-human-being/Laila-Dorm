import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../Database/app_database.dart';
import 'sms_service.dart';

class SmsAutomation {
  SmsAutomation._();

  static bool _started = false;
  static Timer? _debounce;

  static Box get residentsBox =>
      Hive.box(
        AppDatabase.residentsBoxName,
      );

  static Box get settingsBox =>
      Hive.box(
        AppDatabase.settingsBoxName,
      );

  static Box get smsHistoryBox =>
      Hive.box(
        AppDatabase.smsHistoryBoxName,
      );

  static double get monthlyRate {
    return double.tryParse(
          settingsBox
              .get(
                'monthlyRate',
                defaultValue: 3500.0,
              )
              .toString(),
        ) ??
        3500;
  }

  static int get dueSoonDays {
    return int.tryParse(
          settingsBox
              .get(
                'dueSoonDays',
                defaultValue: 3,
              )
              .toString(),
        ) ??
        3;
  }

  static int get partialRepeatDays {
    return int.tryParse(
          settingsBox
              .get(
                'smsPartialRepeatDays',
                defaultValue: 7,
              )
              .toString(),
        ) ??
        7;
  }

  static int get overdueRepeatDays {
    return int.tryParse(
          settingsBox
              .get(
                'smsOverdueRepeatDays',
                defaultValue: 7,
              )
              .toString(),
        ) ??
        7;
  }

  static int get selectedSubscriptionId {
    return int.tryParse(
          settingsBox
              .get(
                'smsSubscriptionId',
                defaultValue: -1,
              )
              .toString(),
        ) ??
        -1;
  }

  static Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;

    residentsBox.listenable().addListener(
          _queueRefresh,
        );

    settingsBox.listenable().addListener(
          _queueRefresh,
        );

    await importNativeResults();

    await syncQueue();

    final bool enabled =
        settingsBox.get(
              'smsAutoEnabled',
              defaultValue: false,
            ) ==
            true;

    if (enabled) {
      await SmsService.scheduleDaily(
        hour: int.tryParse(
              settingsBox
                  .get(
                    'smsHour',
                    defaultValue: 9,
                  )
                  .toString(),
            ) ??
            9,
        minute: int.tryParse(
              settingsBox
                  .get(
                    'smsMinute',
                    defaultValue: 0,
                  )
                  .toString(),
            ) ??
            0,
      );
    }
  }

  static void _queueRefresh() {
    _debounce?.cancel();

    _debounce =
        Timer(
      const Duration(
        milliseconds: 700,
      ),
      () {
        syncQueue();
      },
    );
  }

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  static String? normalizePhilippineNumber(
    dynamic raw,
  ) {
    String digits =
        raw
            ?.toString()
            .replaceAll(
              RegExp(r'[^0-9]'),
              '',
            ) ??
        '';

    if (digits.startsWith('0') &&
        digits.length == 11 &&
        digits.startsWith('09')) {
      return '+63${digits.substring(1)}';
    }

    if (digits.length == 10 &&
        digits.startsWith('9')) {
      return '+63$digits';
    }

    if (digits.length == 12 &&
        digits.startsWith('63')) {
      return '+$digits';
    }

    return null;
  }

  static String _money(
    double value,
  ) {
    return value.toStringAsFixed(2);
  }

  static String _shortDate(
    DateTime date,
  ) {
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  static double _partialCredit(
    Map<dynamic, dynamic> resident,
  ) {
    return double.tryParse(
          resident['partialCredit']
                  ?.toString() ??
              '0',
        ) ??
        0;
  }

  static List<Map<String, dynamic>>
      buildQueue() {
    final List<Map<String, dynamic>>
        queue = [];

    final DateTime now =
        DateTime.now();

    for (final key
        in residentsBox.keys) {
      final dynamic raw =
          residentsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      final resident =
          Map<dynamic, dynamic>.from(
        raw,
      );

      final String status =
          resident['status']
                  ?.toString()
                  .toLowerCase() ??
              'active';

      if (status != 'active') {
        continue;
      }

      final String? number =
          normalizePhilippineNumber(
        resident['contactNumber'],
      );

      if (number == null) {
        continue;
      }

      final String firstName =
          resident['firstName']
                  ?.toString()
                  .trim() ??
              '';

      final String lastName =
          resident['lastName']
                  ?.toString()
                  .trim() ??
              '';

      final String fullName =
          '$firstName $lastName'
              .trim();

      final String residentId =
          resident['syncId']
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true
          ? resident['syncId']
              .toString()
          : key.toString();

      final DateTime? paidUntil =
          _parseDate(
        resident['paidUntil'],
      );

      final double credit =
          _partialCredit(
        resident,
      );

      String? category;
      String? reminderKey;
      String? message;
      int repeatDays = 0;

      if (paidUntil != null &&
          paidUntil.isAfter(now)) {
        final int daysRemaining =
            paidUntil
                .difference(now)
                .inDays;

        if (daysRemaining <=
            dueSoonDays) {
          final double amountDue =
              credit > 0
                  ? (monthlyRate -
                          credit)
                      .clamp(
                        0,
                        monthlyRate,
                      )
                  : monthlyRate;

          category =
              'dueSoon';

          reminderKey =
              'due:$residentId:${paidUntil.toIso8601String()}';

          message =
              'Good day${firstName.isEmpty ? '' : ', $firstName'}. '
              'Laila Dormitory reminder: your room payment is due on '
              '${_shortDate(paidUntil)}. '
              'Next amount due: P${_money(amountDue)}. Thank you.';

          // One reminder for this due date.
          repeatDays =
              0;
        }
      } else {
        if (credit > 0) {
          final double balance =
              (monthlyRate - credit)
                  .clamp(
                    0,
                    monthlyRate,
                  );

          category =
              'partial';

          reminderKey =
              'partial:$residentId:${paidUntil?.toIso8601String() ?? resident['billingStartedAt'] ?? resident['registeredAt'] ?? 'none'}';

          message =
              'Good day${firstName.isEmpty ? '' : ', $firstName'}. '
              'Laila Dormitory reminder: P${_money(balance)} remains '
              'on your current room payment. Thank you.';

          repeatDays =
              partialRepeatDays;
        } else {
          category =
              'overdue';

          reminderKey =
              'overdue:$residentId:${paidUntil?.toIso8601String() ?? resident['registeredAt'] ?? 'none'}';

          message =
              'Good day${firstName.isEmpty ? '' : ', $firstName'}. '
              'Laila Dormitory reminder: your room payment is overdue. '
              'Current amount due: P${_money(monthlyRate)}. '
              'Please settle when able. Thank you.';

          repeatDays =
              overdueRepeatDays;
        }
      }

      if (category == null ||
          reminderKey == null ||
          message == null) {
        continue;
      }

      queue.add({
        'residentKey':
            key.toString(),
        'name':
            fullName,
        'number':
            number,
        'category':
            category,
        'reminderKey':
            reminderKey,
        'message':
            message,
        'repeatDays':
            repeatDays,
        'enabled':
            true,
        'subscriptionId':
            selectedSubscriptionId,
      });
    }

    return queue;
  }

  static Future<void> syncQueue() async {
    try {
      await SmsService.saveReminderQueue(
        buildQueue(),
      );
    } catch (_) {
      // Windows/desktop has no Android SMS channel.
    }
  }

  static Future<void>
      importNativeResults() async {
    try {
      final results =
          await SmsService
              .drainSendResults();

      for (final result
          in results) {
        final String messageId =
            result['messageId']
                    ?.toString() ??
                '';

        bool exists =
            false;

        for (final old
            in smsHistoryBox.values) {
          if (old is Map &&
              old['messageId']
                      ?.toString() ==
                  messageId) {
            exists =
                true;
            break;
          }
        }

        if (exists) {
          continue;
        }

        await smsHistoryBox.add({
          ...result,
          'recordedAt':
              DateTime.now()
                  .toIso8601String(),
        });
      }
    } catch (_) {
      // Ignore on desktop and when Android channel is unavailable.
    }
  }

  static Future<void>
      enableAutomaticSms({
    required int hour,
    required int minute,
    required int subscriptionId,
  }) async {
    await settingsBox.put(
      'smsAutoEnabled',
      true,
    );

    await settingsBox.put(
      'smsHour',
      hour,
    );

    await settingsBox.put(
      'smsMinute',
      minute,
    );

    await settingsBox.put(
      'smsSubscriptionId',
      subscriptionId,
    );

    await syncQueue();

    await SmsService.scheduleDaily(
      hour:
          hour,
      minute:
          minute,
    );
  }

  static Future<void>
      disableAutomaticSms() async {
    await settingsBox.put(
      'smsAutoEnabled',
      false,
    );

    await SmsService.cancelDaily();
  }
}
