import 'dart:convert';

import 'package:flutter/services.dart';

class SmsService {
  static const MethodChannel _channel =
      MethodChannel(
    'laila_dormitory/sms',
  );

  static Future<bool>
      requestPermissions() async {
    return await _channel.invokeMethod<bool>(
          'requestPermissions',
        ) ??
        false;
  }

  static Future<List<Map<String, dynamic>>>
      getSimInfo() async {
    final dynamic raw =
        await _channel.invokeMethod(
      'getSimInfo',
    );

    if (raw is! List) {
      return [];
    }

    return raw
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item as Map,
          ),
        )
        .toList();
  }

  static Future<bool> sendSms({
    required String number,
    required String message,
    String name = '',
    String residentKey = '',
    String category = 'manual',
    String reminderKey = '',
    int? subscriptionId,
  }) async {
    return await _channel.invokeMethod<bool>(
          'sendSms',
          {
            'number':
                number,
            'message':
                message,
            'name':
                name,
            'residentKey':
                residentKey,
            'category':
                category,
            'reminderKey':
                reminderKey,
            if (subscriptionId != null)
              'subscriptionId':
                  subscriptionId,
          },
        ) ??
        false;
  }

  static Future<void>
      saveReminderQueue(
    List<Map<String, dynamic>> queue,
  ) async {
    await _channel.invokeMethod(
      'saveReminderQueue',
      {
        'json':
            jsonEncode(
          queue,
        ),
      },
    );
  }

  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
  }) async {
    await _channel.invokeMethod(
      'scheduleDaily',
      {
        'hour':
            hour,
        'minute':
            minute,
      },
    );
  }

  static Future<void>
      cancelDaily() async {
    await _channel.invokeMethod(
      'cancelDaily',
    );
  }

  static Future<void>
      runAutomationNow() async {
    await _channel.invokeMethod(
      'runAutomationNow',
    );
  }

  static Future<List<Map<String, dynamic>>>
      drainSendResults() async {
    final String json =
        await _channel.invokeMethod<String>(
              'drainSendResults',
            ) ??
            '[]';

    final dynamic decoded =
        jsonDecode(
      json,
    );

    if (decoded is! List) {
      return [];
    }

    return decoded
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item as Map,
          ),
        )
        .toList();
  }

  static Future<Map<String, dynamic>>
      status() async {
    final dynamic raw =
        await _channel.invokeMethod(
      'smsStatus',
    );

    if (raw is! Map) {
      return {};
    }

    return Map<String, dynamic>.from(
      raw,
    );
  }
}
