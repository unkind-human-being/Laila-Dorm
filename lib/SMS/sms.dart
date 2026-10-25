import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../Database/app_database.dart';
import 'sms_automation.dart';
import 'sms_service.dart';

class SmsPage extends StatefulWidget {
  const SmsPage({
    super.key,
  });

  @override
  State<SmsPage> createState() =>
      _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  late final Box settingsBox;
  late final Box smsHistoryBox;

  final TextEditingController
      testNumberController =
      TextEditingController();

  List<Map<String, dynamic>>
      sims = [];

  bool loadingSims =
      false;

  bool autoEnabled =
      false;

  int hour =
      9;

  int minute =
      0;

  int selectedSubscriptionId =
      -1;

  @override
  void initState() {
    super.initState();

    settingsBox =
        Hive.box(
      AppDatabase.settingsBoxName,
    );

    smsHistoryBox =
        Hive.box(
      AppDatabase.smsHistoryBoxName,
    );

    autoEnabled =
        settingsBox.get(
              'smsAutoEnabled',
              defaultValue: false,
            ) ==
            true;

    hour =
        int.tryParse(
              settingsBox
                  .get(
                    'smsHour',
                    defaultValue: 9,
                  )
                  .toString(),
            ) ??
            9;

    minute =
        int.tryParse(
              settingsBox
                  .get(
                    'smsMinute',
                    defaultValue: 0,
                  )
                  .toString(),
            ) ??
            0;

    selectedSubscriptionId =
        int.tryParse(
              settingsBox
                  .get(
                    'smsSubscriptionId',
                    defaultValue: -1,
                  )
                  .toString(),
            ) ??
            -1;

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        _initialLoad();
      },
    );
  }

  Future<void> _initialLoad() async {
    await SmsAutomation
        .importNativeResults();

    await SmsAutomation
        .syncQueue();

    await _loadSims();
  }

  Future<void> _loadSims() async {
    if (!mounted) {
      return;
    }

    setState(() {
      loadingSims =
          true;
    });

    try {
      final List<Map<String, dynamic>>
          found =
          await SmsService
              .getSimInfo();

      if (!mounted) {
        return;
      }

      int selected =
          selectedSubscriptionId;

      if (found.isNotEmpty &&
          !found.any(
            (sim) =>
                sim['subscriptionId'] ==
                selected,
          )) {
        final tm =
            found.cast<
                Map<String, dynamic>>().where(
          (sim) =>
              sim['isTm'] ==
              true,
        );

        if (tm.isNotEmpty) {
          selected =
              int.tryParse(
                    tm.first[
                            'subscriptionId']
                        .toString(),
                  ) ??
                  -1;
        } else {
          selected =
              int.tryParse(
                    found.first[
                            'subscriptionId']
                        .toString(),
                  ) ??
                  -1;
        }
      }

      setState(() {
        sims =
            found;

        selectedSubscriptionId =
            selected;

        loadingSims =
            false;
      });

      if (selected >= 0) {
        await settingsBox.put(
          'smsSubscriptionId',
          selected,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loadingSims =
              false;
        });
      }
    }
  }

  String _simLabel(
    Map<String, dynamic> sim,
  ) {
    final String display =
        sim['displayName']
                ?.toString()
                .trim() ??
            '';

    final String carrier =
        sim['carrierName']
                ?.toString()
                .trim() ??
            '';

    final int slot =
        (int.tryParse(
              sim['slotIndex']
                      ?.toString() ??
                  '0',
            ) ??
            0) +
        1;

    String name =
        display.isNotEmpty
            ? display
            : carrier;

    if (name.isEmpty) {
      name =
          'SIM $slot';
    }

    return 'SIM $slot • $name';
  }

  String _timeText() {
    int displayHour =
        hour;

    final String period =
        displayHour >= 12
            ? 'PM'
            : 'AM';

    if (displayHour == 0) {
      displayHour =
          12;
    } else if (displayHour > 12) {
      displayHour -=
          12;
    }

    return '$displayHour:'
        '${minute.toString().padLeft(2, '0')} '
        '$period';
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked =
        await showTimePicker(
      context:
          context,
      initialTime:
          TimeOfDay(
        hour:
            hour,
        minute:
            minute,
      ),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      hour =
          picked.hour;

      minute =
          picked.minute;
    });

    await settingsBox.put(
      'smsHour',
      hour,
    );

    await settingsBox.put(
      'smsMinute',
      minute,
    );

    if (autoEnabled &&
        selectedSubscriptionId >= 0) {
      await SmsAutomation
          .enableAutomaticSms(
        hour:
            hour,
        minute:
            minute,
        subscriptionId:
            selectedSubscriptionId,
      );
    }
  }

  Future<void> _toggleAutomatic(
    bool value,
  ) async {
    if (!value) {
      await SmsAutomation
          .disableAutomaticSms();

      if (mounted) {
        setState(() {
          autoEnabled =
              false;
        });
      }

      return;
    }

    final bool permission =
        await SmsService
            .requestPermissions();

    if (!permission) {
      if (mounted) {
        _message(
          'SMS permission was not granted.',
        );
      }

      return;
    }

    await _loadSims();

    if (selectedSubscriptionId <
        0) {
      if (mounted) {
        _message(
          'No active SMS SIM was detected.',
        );
      }

      return;
    }

    await SmsAutomation
        .enableAutomaticSms(
      hour:
          hour,
      minute:
          minute,
      subscriptionId:
          selectedSubscriptionId,
    );

    if (mounted) {
      setState(() {
        autoEnabled =
            true;
      });

      _message(
        'Automatic SMS reminders enabled.',
      );
    }
  }

  Future<void> _sendTest() async {
    final String? number =
        SmsAutomation
            .normalizePhilippineNumber(
      testNumberController.text,
    );

    if (number == null) {
      _message(
        'Enter a valid Philippine mobile number.',
      );
      return;
    }

    final bool permission =
        await SmsService
            .requestPermissions();

    if (!permission) {
      _message(
        'SMS permission is required.',
      );
      return;
    }

    await _loadSims();

    if (selectedSubscriptionId <
        0) {
      _message(
        'No active SIM was found.',
      );
      return;
    }

    try {
      await SmsService.sendSms(
        number:
            number,
        message:
            'Laila Dormitory SMS test. If you received this message, automatic SMS is ready.',
        name:
            'SMS Test',
        category:
            'test',
        reminderKey:
            '',
        subscriptionId:
            selectedSubscriptionId,
      );

      _message(
        'Test SMS queued. Check the receiving phone.',
      );

      await Future<void>.delayed(
        const Duration(
          seconds: 3,
        ),
      );

      await SmsAutomation
          .importNativeResults();

      if (mounted) {
        setState(
          () {},
        );
      }
    } on PlatformException catch (error) {
      _message(
        error.message ??
            'Could not send the test SMS.',
      );
    }
  }

  Future<void> _runNow() async {
    final bool permission =
        await SmsService
            .requestPermissions();

    if (!permission) {
      _message(
        'SMS permission is required.',
      );
      return;
    }

    await SmsAutomation
        .syncQueue();

    await SmsService
        .runAutomationNow();

    _message(
      'Pending reminders were queued for automatic sending.',
    );

    await Future<void>.delayed(
      const Duration(
        seconds: 4,
      ),
    );

    await SmsAutomation
        .importNativeResults();

    if (mounted) {
      setState(
        () {},
      );
    }
  }

  void _message(
    String text,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(text),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width:
          180,
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border:
            Border.all(
          color:
              const Color(
                  0xFFE4E7EC),
        ),
      ),
      child:
          Row(
        children: [
          Icon(
            icon,
            color:
                const Color(
                    0xFF17617D),
          ),
          const SizedBox(
              width: 10),
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize:
                        20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize:
                        11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return ValueListenableBuilder(
      valueListenable:
          smsHistoryBox
              .listenable(),
      builder:
          (
        context,
        Box history,
        _,
      ) {
        final queue =
            SmsAutomation
                .buildQueue();

        final int dueSoon =
            queue
                .where(
                  (item) =>
                      item['category'] ==
                      'dueSoon',
                )
                .length;

        final int partial =
            queue
                .where(
                  (item) =>
                      item['category'] ==
                      'partial',
                )
                .length;

        final int overdue =
            queue
                .where(
                  (item) =>
                      item['category'] ==
                      'overdue',
                )
                .length;

        final List<Map<String, dynamic>>
            historyItems =
            history.keys
                .map(
                  (key) =>
                      Map<String, dynamic>.from(
                    history.get(
                      key,
                    ),
                  ),
                )
                .toList()
              ..sort(
                (
                  a,
                  b,
                ) {
                  final int aAt =
                      int.tryParse(
                            a['at']
                                    ?.toString() ??
                                '0',
                          ) ??
                          0;

                  final int bAt =
                      int.tryParse(
                            b['at']
                                    ?.toString() ??
                                '0',
                          ) ??
                          0;

                  return bAt.compareTo(
                    aAt,
                  );
                },
              );

        return Container(
          color:
              const Color(
                  0xFFF5F7FA),
          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Text(
                  'SMS Reminders',
                  style:
                      TextStyle(
                    fontSize:
                        27,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                    height: 4),

                const Text(
                  'Automatic payment reminders sent using the phone SIM.',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                  ),
                ),

                const SizedBox(
                    height: 18),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                    border:
                        Border.all(
                      color:
                          const Color(
                              0xFFE4E7EC),
                    ),
                  ),
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      SwitchListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        title:
                            const Text(
                          'Automatic SMS Reminders',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        subtitle:
                            Text(
                          autoEnabled
                              ? 'Enabled • Daily around ${_timeText()}'
                              : 'Disabled',
                        ),
                        value:
                            autoEnabled,
                        onChanged:
                            _toggleAutomatic,
                      ),

                      const Divider(),

                      if (loadingSims)
                        const LinearProgressIndicator()
                      else if (sims.isEmpty)
                        const Text(
                          'No SIM information yet. Allow SMS/phone permission, then refresh.',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        )
                      else
                        DropdownButtonFormField<
                            int>(
                          value:
                              sims.any(
                            (sim) =>
                                sim['subscriptionId'] ==
                                selectedSubscriptionId,
                          )
                                  ? selectedSubscriptionId
                                  : null,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'SMS SIM',
                          ),
                          items:
                              sims.map(
                            (
                              sim,
                            ) {
                              final int id =
                                  int.parse(
                                sim['subscriptionId']
                                    .toString(),
                              );

                              return DropdownMenuItem<
                                  int>(
                                value:
                                    id,
                                child:
                                    Text(
                                  '${_simLabel(sim)}'
                                  '${sim['isTm'] == true ? ' • TM/Globe' : ''}',
                                ),
                              );
                            },
                          ).toList(),
                          onChanged:
                              (value) async {
                            if (value ==
                                null) {
                              return;
                            }

                            setState(() {
                              selectedSubscriptionId =
                                  value;
                            });

                            await settingsBox.put(
                              'smsSubscriptionId',
                              value,
                            );

                            await SmsAutomation
                                .syncQueue();

                            if (autoEnabled) {
                              await SmsAutomation
                                  .enableAutomaticSms(
                                hour:
                                    hour,
                                minute:
                                    minute,
                                subscriptionId:
                                    value,
                              );
                            }
                          },
                        ),

                      const SizedBox(
                          height: 12),

                      Row(
                        children: [
                          Expanded(
                            child:
                                OutlinedButton.icon(
                              onPressed:
                                  _pickTime,
                              icon:
                                  const Icon(
                                Icons
                                    .schedule_outlined,
                              ),
                              label:
                                  Text(
                                'Daily Time: ${_timeText()}',
                              ),
                            ),
                          ),

                          const SizedBox(
                              width: 8),

                          IconButton(
                            tooltip:
                                'Refresh SIM',
                            onPressed:
                                _loadSims,
                            icon:
                                const Icon(
                              Icons.refresh,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: 10),

                      const Text(
                        'Android may send the reminder later than the selected time when the phone is in battery-saving or Doze mode.',
                        style:
                            TextStyle(
                          color:
                              Colors.grey,
                          fontSize:
                              11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                    height: 14),

                Wrap(
                  spacing:
                      10,
                  runSpacing:
                      10,
                  children: [
                    _summaryCard(
                      title:
                          'Due Soon',
                      value:
                          dueSoon.toString(),
                      icon:
                          Icons
                              .schedule_outlined,
                    ),
                    _summaryCard(
                      title:
                          'Partial',
                      value:
                          partial.toString(),
                      icon:
                          Icons
                              .account_balance_wallet_outlined,
                    ),
                    _summaryCard(
                      title:
                          'Overdue',
                      value:
                          overdue.toString(),
                      icon:
                          Icons
                              .warning_amber_outlined,
                    ),
                    _summaryCard(
                      title:
                          'Queued',
                      value:
                          queue.length.toString(),
                      icon:
                          Icons
                              .sms_outlined,
                    ),
                  ],
                ),

                const SizedBox(
                    height: 18),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                    border:
                        Border.all(
                      color:
                          const Color(
                              0xFFE4E7EC),
                    ),
                  ),
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Test SMS',
                        style:
                            TextStyle(
                          fontSize:
                              17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                          height: 10),

                      TextField(
                        controller:
                            testNumberController,
                        keyboardType:
                            TextInputType.phone,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Test mobile number',
                          hintText:
                              '09XXXXXXXXX',
                        ),
                      ),

                      const SizedBox(
                          height: 10),

                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            ElevatedButton.icon(
                          onPressed:
                              _sendTest,
                          icon:
                              const Icon(
                            Icons.send_outlined,
                          ),
                          label:
                              const Text(
                            'Send Test SMS',
                          ),
                        ),
                      ),

                      const SizedBox(
                          height: 8),

                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              _runNow,
                          icon:
                              const Icon(
                            Icons
                                .play_arrow_outlined,
                          ),
                          label:
                              const Text(
                            'Run Pending Automatic Reminders Now',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                    height: 18),

                const Text(
                  'Pending Reminders',
                  style:
                      TextStyle(
                    fontSize:
                        19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                    height: 8),

                if (queue.isEmpty)
                  const Text(
                    'No resident currently needs an SMS reminder.',
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  )
                else
                  ...queue.take(
                    50,
                  ).map(
                    (
                      item,
                    ) {
                      return Card(
                        child:
                            ListTile(
                          leading:
                              const Icon(
                            Icons
                                .sms_outlined,
                          ),
                          title:
                              Text(
                            item['name']
                                    ?.toString()
                                    .isNotEmpty ==
                                true
                                ? item[
                                        'name']
                                    .toString()
                                : item[
                                        'number']
                                    .toString(),
                          ),
                          subtitle:
                              Text(
                            '${item['category']} • ${item['number']}\n'
                            '${item['message']}',
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(
                    height: 18),

                Row(
                  children: [
                    const Expanded(
                      child:
                          Text(
                        'SMS History',
                        style:
                            TextStyle(
                          fontSize:
                              19,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed:
                          () async {
                        await SmsAutomation
                            .importNativeResults();

                        if (mounted) {
                          setState(
                            () {},
                          );
                        }
                      },
                      icon:
                          const Icon(
                        Icons.refresh,
                      ),
                      label:
                          const Text(
                        'Refresh',
                      ),
                    ),
                  ],
                ),

                if (historyItems.isEmpty)
                  const Text(
                    'No SMS history yet.',
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  )
                else
                  ...historyItems.take(
                    50,
                  ).map(
                    (
                      item,
                    ) {
                      final bool sent =
                          item['status']
                                  ?.toString() ==
                              'sent';

                      return Card(
                        child:
                            ListTile(
                          leading:
                              Icon(
                            sent
                                ? Icons
                                    .check_circle_outline
                                : Icons
                                    .error_outline,
                            color:
                                sent
                                    ? Colors
                                        .green
                                    : Colors
                                        .red,
                          ),
                          title:
                              Text(
                            item['name']
                                    ?.toString()
                                    .isNotEmpty ==
                                true
                                ? item[
                                        'name']
                                    .toString()
                                : item[
                                        'number']
                                    .toString(),
                          ),
                          subtitle:
                              Text(
                            sent
                                ? '${item['category']} • Sent to ${item['number']}'
                                : '${item['category']} • ${item['error'] ?? 'Failed'}',
                          ),
                          trailing:
                              Text(
                            sent
                                ? 'SENT'
                                : 'FAILED',
                            style:
                                TextStyle(
                              color:
                                  sent
                                      ? Colors
                                          .green
                                      : Colors
                                          .red,
                              fontWeight:
                                  FontWeight.bold,
                              fontSize:
                                  11,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(
                    height: 24),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.orange
                            .withOpacity(
                      .07,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                  ),
                  child:
                      const Text(
                    'If SMS messages start failing, check the TM load/unli-text promo and mobile signal. Android does not provide the app with a reliable exact prepaid load balance.',
                    style:
                        TextStyle(
                      fontSize:
                          11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    testNumberController.dispose();
    super.dispose();
  }
}
