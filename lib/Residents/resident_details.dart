import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../Database/app_database.dart';
import '../Payments/billing_helper.dart';

class ResidentDetailsDialog extends StatefulWidget {
  final dynamic residentKey;

  const ResidentDetailsDialog({
    super.key,
    required this.residentKey,
  });

  @override
  State<ResidentDetailsDialog> createState() =>
      _ResidentDetailsDialogState();
}

class _ResidentDetailsDialogState
    extends State<ResidentDetailsDialog> {
  late final Box residentsBox;
  late final Box roomsBox;
  late final Box paymentsBox;
  late final Box settingsBox;

  final TextEditingController
      reactivationPaymentController =
      TextEditingController();

  int? selectedRoom;
  String? selectedBed;

  bool processing = false;

  @override
  void initState() {
    super.initState();

    residentsBox = Hive.box(
      AppDatabase.residentsBoxName,
    );

    roomsBox = Hive.box(
      AppDatabase.roomsBoxName,
    );

    paymentsBox = Hive.box(
      AppDatabase.paymentsBoxName,
    );

    settingsBox = Hive.box(
      AppDatabase.settingsBoxName,
    );
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  double get monthlyRate {
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

  int get billingDays {
    return int.tryParse(
          settingsBox
              .get(
                'billingDays',
                defaultValue: 30,
              )
              .toString(),
        ) ??
        30;
  }

  // ============================================================
  // FORMATTERS
  // ============================================================

  String money(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  DateTime? parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  String dateTimeText(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    int hour = date.hour;

    final period =
        hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$month/$day/${date.year} '
        '$hour:$minute $period';
  }

  String bedName(dynamic bed) {
    if (bed == 'upper') {
      return 'Upper Deck';
    }

    if (bed == 'lower') {
      return 'Lower Deck';
    }

    return 'Not Assigned';
  }

  // ============================================================
  // ROOM AVAILABILITY
  // ============================================================

  bool bedOccupied({
    required int roomNumber,
    required String bedType,
  }) {
    for (final key in residentsBox.keys) {
      final dynamic raw =
          residentsBox.get(key);

      if (raw == null) {
        continue;
      }

      final resident =
          Map<dynamic, dynamic>.from(raw);

      final String status =
          resident['status']
                  ?.toString()
                  .toLowerCase() ??
              'active';

      if (status != 'active') {
        continue;
      }

      if (resident['roomNumber'] ==
              roomNumber &&
          resident['bedType'] ==
              bedType) {
        return true;
      }
    }

    return false;
  }

  List<String> availableBeds(
    int roomNumber,
  ) {
    final List<String> beds = [];

    if (!bedOccupied(
      roomNumber: roomNumber,
      bedType: 'upper',
    )) {
      beds.add('upper');
    }

    if (!bedOccupied(
      roomNumber: roomNumber,
      bedType: 'lower',
    )) {
      beds.add('lower');
    }

    return beds;
  }

  List<int> availableRooms() {
    final List<int> result = [];

    for (final key in roomsBox.keys) {
      final dynamic raw =
          roomsBox.get(key);

      if (raw == null) {
        continue;
      }

      final room =
          Map<dynamic, dynamic>.from(raw);

      if (room['isActive'] == false) {
        continue;
      }

      final int? roomNumber =
          room['roomNumber'] is int
              ? room['roomNumber']
              : int.tryParse(
                  room['roomNumber']
                          ?.toString() ??
                      '',
                );

      if (roomNumber == null) {
        continue;
      }

      if (availableBeds(roomNumber)
          .isNotEmpty) {
        result.add(roomNumber);
      }
    }

    result.sort();

    return result;
  }


  // ============================================================
  // STATUS HISTORY
  // ============================================================

  List<Map<String, dynamic>>
      getStatusHistory(
    Map<String, dynamic> resident,
  ) {
    final List<Map<String, dynamic>>
        history = [];

    final dynamic rawHistory =
        resident['statusHistory'];

    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map) {
          history.add(
            Map<String, dynamic>.from(
              item,
            ),
          );
        }
      }
    }

    // Support records created before
    // statusHistory was added.
    if (history.isEmpty) {
      final registered =
          parseDate(
        resident['registeredAt'],
      );

      if (registered != null) {
        history.add({
          'type': 'registered',
          'at':
              registered.toIso8601String(),
          'roomNumber':
              resident['lastRoomNumber'] ??
                  resident[
                      'roomNumber'],
          'bedType':
              resident['lastBedType'] ??
                  resident['bedType'],
        });
      }

      final deactivated =
          parseDate(
        resident['deactivatedAt'],
      );

      if (deactivated != null) {
        history.add({
          'type': 'deactivated',
          'at':
              deactivated.toIso8601String(),
          'reason':
              resident[
                  'deactivationReason'],
          'roomNumber':
              resident[
                  'lastRoomNumber'],
          'bedType':
              resident[
                  'lastBedType'],
        });
      }

      final reactivated =
          parseDate(
        resident['reactivatedAt'],
      );

      if (reactivated != null) {
        history.add({
          'type': 'reactivated',
          'at':
              reactivated.toIso8601String(),
          'roomNumber':
              resident['roomNumber'],
          'bedType':
              resident['bedType'],
        });
      }
    }

    history.sort(
      (a, b) {
        final DateTime aDate =
            parseDate(a['at']) ??
                DateTime(1970);

        final DateTime bDate =
            parseDate(b['at']) ??
                DateTime(1970);

        return bDate.compareTo(
          aDate,
        );
      },
    );

    return history;
  }

  // ============================================================
  // PAYMENT HISTORY
  // ============================================================

  List<Map<String, dynamic>>
      paymentHistory() {
    final List<Map<String, dynamic>>
        result = [];

    for (final key in paymentsBox.keys) {
      final dynamic raw =
          paymentsBox.get(key);

      if (raw == null) {
        continue;
      }

      final payment =
          Map<String, dynamic>.from(raw);

      if (payment['residentKey'] ==
          widget.residentKey) {
        result.add({
          'paymentKey': key,
          ...payment,
        });
      }
    }

    result.sort(
      (a, b) {
        final aDate =
            parseDate(
                  a['paidAt'],
                ) ??
                DateTime(1970);

        final bDate =
            parseDate(
                  b['paidAt'],
                ) ??
                DateTime(1970);

        return bDate.compareTo(
          aDate,
        );
      },
    );

    return result;
  }

  // ============================================================
  // REACTIVATE DIALOG
  // ============================================================

  Future<void> showReactivateDialog(
    Map<String, dynamic> resident,
  ) async {
    selectedRoom = null;
    selectedBed = null;
    reactivationPaymentController
        .clear();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            final List<int> rooms =
                availableRooms();

            final List<String> beds =
                selectedRoom == null
                    ? []
                    : availableBeds(
                        selectedRoom!,
                      );

            return AlertDialog(
              title: const Text(
                'Reactivate Resident',
              ),

              content: SizedBox(
                width: 520,
                child:
                    SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        '${resident['firstName'] ?? ''} '
                        '${resident['lastName'] ?? ''}',
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                          height: 5),

                      const Text(
                        'Assign a new room and bed and record the new payment.',
                        style:
                            TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),

                      const SizedBox(
                          height: 20),

                      DropdownButtonFormField<
                          int>(
                        value:
                            selectedRoom,

                        isExpanded:
                            true,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'New Room',
                        ),

                        items:
                            rooms.map(
                          (room) {
                            return DropdownMenuItem<
                                int>(
                              value: room,
                              child: Text(
                                'Room ${room.toString().padLeft(3, '0')}',
                              ),
                            );
                          },
                        ).toList(),

                        onChanged:
                            (value) {
                          setDialogState(
                            () {
                              selectedRoom =
                                  value;

                              selectedBed =
                                  null;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                          height: 12),

                      DropdownButtonFormField<
                          String>(
                        value:
                            selectedBed,

                        isExpanded:
                            true,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Bed Choice',
                        ),

                        items:
                            beds.map(
                          (bed) {
                            return DropdownMenuItem<
                                String>(
                              value: bed,
                              child: Text(
                                bed ==
                                        'upper'
                                    ? 'Upper Deck'
                                    : 'Lower Deck',
                              ),
                            );
                          },
                        ).toList(),

                        onChanged:
                            selectedRoom ==
                                    null
                                ? null
                                : (value) {
                                    setDialogState(
                                      () {
                                        selectedBed =
                                            value;
                                      },
                                    );
                                  },
                      ),

                      const SizedBox(
                          height: 20),

                      TextField(
                        controller:
                            reactivationPaymentController,

                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),

                        inputFormatters: [
                          FilteringTextInputFormatter
                              .allow(
                            RegExp(
                              r'^\d*\.?\d{0,2}',
                            ),
                          ),
                        ],

                        decoration:
                            InputDecoration(
                          labelText:
                              'Reactivation Payment',

                          prefixText:
                              '₱ ',

                          helperText:
                              'Any positive amount is accepted. ${money(monthlyRate)} completes 1 billing cycle.',
                        ),
                      ),

                      const SizedBox(
                          height: 12),

                      Container(
                        padding:
                            const EdgeInsets
                                .all(12),

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                                      0xFF17617D)
                                  .withOpacity(
                                      .06),

                          borderRadius:
                              BorderRadius
                                  .circular(
                                      10),
                        ),

                        child: Text(
                          'Reactivation starts a NEW billing period from today. Any positive payment amount is accepted. Partial payments are tracked as a remaining balance. Previous overdue dates are preserved only as history.',
                          style:
                              const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),

                ElevatedButton.icon(
                  onPressed:
                      processing
                          ? null
                          : () async {
                              final success =
                                  await reactivateResident(
                                resident,
                              );

                              if (success &&
                                  dialogContext
                                      .mounted) {
                                Navigator.pop(
                                  dialogContext,
                                );
                              }
                            },

                  icon:
                      const Icon(
                    Icons
                        .person_add_alt_1,
                  ),

                  label:
                      const Text(
                    'Reactivate',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // REACTIVATE
  // ============================================================

  Future<bool> reactivateResident(
    Map<String, dynamic> resident,
  ) async {
    if (selectedRoom == null) {
      showMessage(
        'Please select a room.',
      );
      return false;
    }

    if (selectedBed == null) {
      showMessage(
        'Please select a bed.',
      );
      return false;
    }

    if (bedOccupied(
      roomNumber:
          selectedRoom!,
      bedType:
          selectedBed!,
    )) {
      showMessage(
        'That bed is already occupied.',
      );
      return false;
    }

    final double? amount =
        double.tryParse(
      reactivationPaymentController
          .text
          .trim(),
    );

    if (amount == null ||
        amount <= 0) {
      showMessage(
        'Please enter a valid reactivation payment.',
      );
      return false;
    }

    setState(() {
      processing = true;
    });

    final DateTime now =
        DateTime.now();

    // ==========================================================
    // NEW BILLING PERIOD
    //
    // Reactivation always starts a brand-new billing period.
    // Any positive payment amount is accepted.
    //
    // Example monthly rate = ₱3,500
    // ₱500  -> partialCredit 500, balanceDue 3000
    // ₱1000 -> partialCredit 1000, balanceDue 2500
    // ₱3500 -> 1 full cycle, balanceDue 0
    // ==========================================================

    final BillingResult billing =
        BillingHelper.applyPayment(
      payment:
          amount,
      monthlyRate:
          monthlyRate,
      billingDays:
          billingDays,
      referenceDate:
          now,
      existingPaidUntil:
          null,
      existingPartialCredit:
          0,
      billingStartedAt:
          now,
    );

    final Map<String, dynamic>
        updated =
        Map<String, dynamic>.from(
      resident,
    );

    final List<Map<String, dynamic>>
        history =
        getStatusHistory(
      updated,
    );

    history.add({
      'type':
          'reactivated',
      'at':
          now.toIso8601String(),
      'roomNumber':
          selectedRoom,
      'bedType':
          selectedBed,
      'payment':
          amount,
      'monthlyRate':
          monthlyRate,
      'cyclesCompleted':
          billing.fullCyclesAdded,
      'partialCredit':
          billing.partialCredit,
      'balanceDue':
          billing.remainingBalance,
      'currentDueDate':
          billing.currentDueDate
              .toIso8601String(),
      'paidUntil':
          billing.paidUntil
              ?.toIso8601String(),
    });

    updated['status'] =
        'active';

    updated['roomNumber'] =
        selectedRoom;

    updated['bedType'] =
        selectedBed;

    updated['reactivatedAt'] =
        now.toIso8601String();

    updated['updatedAt'] =
        now.toIso8601String();

    updated['deactivatedAt'] =
        null;

    updated['deactivationReason'] =
        null;

    // New stay / billing period starts today.
    updated['billingStartedAt'] =
        now.toIso8601String();

    updated['currentDueDate'] =
        billing.currentDueDate
            .toIso8601String();

    updated['paidUntil'] =
        billing.paidUntil
            ?.toIso8601String();

    updated['partialCredit'] =
        billing.partialCredit;

    updated['balanceDue'] =
        billing.remainingBalance;

    updated['statusHistory'] =
        history;

    try {
      await residentsBox.put(
        widget.residentKey,
        updated,
      );

      await paymentsBox.add({
        'residentKey':
            widget.residentKey,
        'residentType':
            updated['residentType'],
        'firstName':
            updated['firstName'],
        'lastName':
            updated['lastName'],
        'roomNumber':
            selectedRoom,
        'bedType':
            selectedBed,
        'amount':
            amount,
        'monthlyRate':
            monthlyRate,
        'cyclesCovered':
            billing.fullCyclesAdded,
        'partialCreditBefore':
            0.0,
        'partialCreditAfter':
            billing.partialCredit,
        'balanceDueAfter':
            billing.remainingBalance,
        'previousPaidUntil':
            null,
        'newPaidUntil':
            billing.paidUntil
                ?.toIso8601String(),
        'currentDueDateAfter':
            billing.currentDueDate
                .toIso8601String(),
        'paidAt':
            now.toIso8601String(),
        'updatedAt':
            now.toIso8601String(),
        'type':
            'Reactivation Payment',
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          processing = false;
        });
      }

      showMessage(
        'Unable to reactivate resident: $error',
      );

      return false;
    }

    if (!mounted) {
      return false;
    }

    setState(() {
      processing = false;
    });

    if (billing.remainingBalance > 0) {
      showMessage(
        'Resident reactivated. Payment ${money(amount)} recorded. Remaining balance: ${money(billing.remainingBalance)}.',
      );
    } else {
      showMessage(
        'Resident reactivated successfully. ${billing.fullCyclesAdded} billing cycle${billing.fullCyclesAdded == 1 ? '' : 's'} completed.',
      );
    }

    return true;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  // ============================================================
  // DETAIL ITEM
  // ============================================================

  Widget detailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color:
                const Color(
                    0xFF17617D),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(
                    height: 2),

                Text(
                  value.isEmpty
                      ? 'Not provided'
                      : value,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY EVENT
  // ============================================================

  Widget statusHistoryItem(
    Map<String, dynamic> item,
  ) {
    final String type =
        item['type']
                ?.toString() ??
            '';

    IconData icon;
    Color color;
    String title;

    switch (type) {
      case 'registered':
        icon =
            Icons.person_add_alt_1;
        color =
            Colors.blue;
        title =
            'Registered';
        break;

      case 'deactivated':
        icon =
            Icons.person_off_outlined;
        color =
            Colors.red;
        title =
            'Deactivated';
        break;

      case 'reactivated':
        icon =
            Icons.restart_alt;
        color =
            Colors.green;
        title =
            'Reactivated';
        break;

      default:
        icon =
            Icons.history;
        color =
            Colors.grey;
        title =
            type;
    }

    final DateTime? date =
        parseDate(
      item['at'],
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          .06,
        ),

        borderRadius:
            BorderRadius.circular(
          10,
        ),

        border: Border.all(
          color:
              color.withOpacity(
            .20,
          ),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                color.withOpacity(
              .10,
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                Text(
                  dateTimeText(
                    date,
                  ),
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 11,
                  ),
                ),

                if (item['roomNumber'] !=
                    null)
                  Text(
                    'Room ${item['roomNumber'].toString().padLeft(3, '0')} • ${bedName(item['bedType'])}',
                    style:
                        const TextStyle(
                      fontSize: 11,
                    ),
                  ),

                if (item['reason'] !=
                        null &&
                    item['reason']
                        .toString()
                        .isNotEmpty)
                  Text(
                    'Reason: ${item['reason']}',
                    style:
                        const TextStyle(
                      fontSize: 11,
                    ),
                  ),

                if (item['payment'] != null)
                  Text(
                    'Payment: ${money(double.tryParse(item['payment'].toString()) ?? 0)}',
                    style:
                        const TextStyle(
                      fontSize: 11,
                    ),
                  ),

                if (item['balanceDue'] != null)
                  Text(
                    'Balance after reactivation: ${money(double.tryParse(item['balanceDue'].toString()) ?? 0)}',
                    style:
                        const TextStyle(
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT HISTORY TILE
  // ============================================================

  Widget paymentHistoryItem(
    Map<String, dynamic> payment,
  ) {
    final double amount =
        double.tryParse(
              payment['amount']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    final int cycles =
        int.tryParse(
              payment['cyclesCovered']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    final double partialAfter =
        double.tryParse(
              payment['partialCreditAfter']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    final double balanceAfter =
        double.tryParse(
              payment['balanceDueAfter']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    final DateTime? paidUntil =
        parseDate(
      payment['newPaidUntil'],
    );

    final DateTime? dueDate =
        parseDate(
      payment['currentDueDateAfter'],
    );

    final String paymentDescription;

    if (cycles == 0) {
      paymentDescription =
          'Partial payment • ${money(balanceAfter)} remaining';
    } else if (partialAfter > 0) {
      paymentDescription =
          '$cycles complete cycle${cycles == 1 ? '' : 's'} + ${money(partialAfter)} toward next cycle';
    } else {
      paymentDescription =
          '$cycles billing cycle${cycles == 1 ? '' : 's'} completed';
    }

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
                0xFFF9FAFB),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              const Color(
                  0xFFE4E7EC),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.payments_outlined,
            color:
                Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  payment['type']
                          ?.toString() ??
                      'Payment',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                Text(
                  paymentDescription,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        Colors.grey,
                  ),
                ),
                if (dueDate != null)
                  Text(
                    'Due: ${dateTimeText(dueDate)}',
                    style:
                        const TextStyle(
                      fontSize: 10,
                      color:
                          Colors.grey,
                    ),
                  ),
                Text(
                  paidUntil == null
                      ? 'Paid until: Not fully paid'
                      : 'Paid until: ${dateTimeText(paidUntil)}',
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color:
                        Colors.grey,
                  ),
                ),
                Text(
                  dateTimeText(
                    parseDate(
                      payment['paidAt'],
                    ),
                  ),
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color:
                        Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            money(amount),
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(
                      0xFF17617D),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable:
          residentsBox.listenable(),

      builder: (
        context,
        Box residents,
        _,
      ) {
        if (!residentsBox.containsKey(
          widget.residentKey,
        )) {
          return const AlertDialog(
            content: Text(
              'Resident record not found.',
            ),
          );
        }

        final resident =
            Map<String, dynamic>.from(
          residentsBox.get(
            widget.residentKey,
          ),
        );

        final dynamic picture =
            resident['picture'];

        final String type =
            resident['residentType']
                    ?.toString() ??
                'regular';

        final String status =
            resident['status']
                    ?.toString()
                    .toLowerCase() ??
                'active';

        final bool active =
            status == 'active';

        final DateTime currentDueDate =
            BillingHelper.getCurrentDueDate(
          resident:
              resident,
          billingDays:
              billingDays,
        );

        final DateTime? paidUntil =
            parseDate(
          resident['paidUntil'],
        );

        final double partialCredit =
            double.tryParse(
                  resident['partialCredit']
                          ?.toString() ??
                      '0',
                ) ??
                0;

        final double balanceDue =
            BillingHelper.getRemainingBalance(
          resident:
              resident,
          monthlyRate:
              monthlyRate,
        );

        final history =
            getStatusHistory(
          resident,
        );

        final payments =
            paymentHistory();

        return Dialog(
          insetPadding:
              const EdgeInsets.all(
            16,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),

          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1000,
              maxHeight: 800,
            ),

            child: Column(
              children: [
                // =================================================
                // HEADER
                // =================================================

                Padding(
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .badge_outlined,
                        color:
                            Color(
                                0xFF17617D),
                      ),

                      const SizedBox(
                          width: 10),

                      const Expanded(
                        child: Text(
                          'Resident Record',
                          style:
                              TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),

                        decoration:
                            BoxDecoration(
                          color: active
                              ? Colors.green
                                  .withOpacity(
                                      .10)
                              : Colors.grey
                                  .withOpacity(
                                      .15),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),

                        child: Text(
                          active
                              ? 'ACTIVE'
                              : 'INACTIVE',

                          style:
                              TextStyle(
                            color: active
                                ? Colors.green
                                : Colors.grey,

                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                          );
                        },
                        icon:
                            const Icon(
                          Icons.close,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // =================================================
                // CONTENT
                // =================================================

                Expanded(
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),

                    child:
                        LayoutBuilder(
                      builder: (
                        context,
                        constraints,
                      ) {
                        final bool desktop =
                            constraints.maxWidth >=
                                750;

                        final Widget basicInfo =
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Center(
                              child:
                                  CircleAvatar(
                                radius: 58,

                                backgroundImage:
                                    picture
                                            is Uint8List
                                        ? MemoryImage(
                                            picture,
                                          )
                                        : null,

                                child: picture
                                        is Uint8List
                                    ? null
                                    : const Icon(
                                        Icons
                                            .person_outline,
                                        size: 55,
                                      ),
                              ),
                            ),

                            const SizedBox(
                                height: 14),

                            Center(
                              child: Text(
                                '${resident['lastName'] ?? ''}, '
                                '${resident['firstName'] ?? ''}'
                                '${(resident['middleInitial'] ?? '').toString().isEmpty ? '' : ' ${resident['middleInitial']}.'}',

                                textAlign:
                                    TextAlign.center,

                                style:
                                    const TextStyle(
                                  fontSize: 21,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(
                                height: 5),

                            Center(
                              child: Text(
                                type ==
                                        'student'
                                    ? 'Student Resident'
                                    : 'Regular Resident',

                                style:
                                    const TextStyle(
                                  color:
                                      Color(
                                          0xFF17617D),
                                ),
                              ),
                            ),

                            const SizedBox(
                                height: 25),

                            detailItem(
                              icon:
                                  Icons.home_outlined,
                              label:
                                  'Permanent Address',
                              value:
                                  resident['permanentAddress']
                                          ?.toString() ??
                                      '',
                            ),

                            detailItem(
                              icon:
                                  Icons.phone_outlined,
                              label:
                                  'Contact Number',
                              value:
                                  resident['contactNumber']
                                          ?.toString() ??
                                      '',
                            ),

                            detailItem(
                              icon:
                                  Icons
                                      .contact_emergency_outlined,
                              label:
                                  'Emergency Number',
                              value:
                                  resident['emergencyNumber']
                                          ?.toString() ??
                                      '',
                            ),

                            if (type ==
                                'student')
                              detailItem(
                                icon:
                                    Icons.school_outlined,
                                label:
                                    'School',
                                value:
                                    resident['schoolName']
                                            ?.toString() ??
                                        '',
                              ),

                            detailItem(
                              icon:
                                  Icons
                                      .person_add_alt_1_outlined,
                              label:
                                  'Registered',
                              value:
                                  dateTimeText(
                                parseDate(
                                  resident[
                                      'registeredAt'],
                                ),
                              ),
                            ),

                            detailItem(
                              icon:
                                  Icons.bed_outlined,
                              label:
                                  active
                                      ? 'Current Room / Bed'
                                      : 'Last Room / Bed',

                              value: active
                                  ? resident['roomNumber'] ==
                                          null
                                      ? 'Not Assigned'
                                      : 'Room ${resident['roomNumber'].toString().padLeft(3, '0')} • ${bedName(resident['bedType'])}'
                                  : resident['lastRoomNumber'] ==
                                          null
                                      ? 'Not Available'
                                      : 'Room ${resident['lastRoomNumber'].toString().padLeft(3, '0')} • ${bedName(resident['lastBedType'])}',
                            ),

                            detailItem(
                              icon:
                                  Icons.schedule_outlined,
                              label:
                                  'Current Due Date',
                              value:
                                  dateTimeText(
                                currentDueDate,
                              ),
                            ),

                            detailItem(
                              icon:
                                  Icons.payments_outlined,
                              label:
                                  'Amount Applied',
                              value:
                                  money(
                                partialCredit,
                              ),
                            ),

                            detailItem(
                              icon:
                                  Icons.account_balance_wallet_outlined,
                              label:
                                  'Remaining Balance',
                              value:
                                  money(
                                balanceDue,
                              ),
                            ),

                            detailItem(
                              icon:
                                  Icons.event_available_outlined,
                              label:
                                  'Paid Until',
                              value:
                                  paidUntil == null
                                      ? 'Not fully paid'
                                      : dateTimeText(
                                          paidUntil,
                                        ),
                            ),

                            if (!active) ...[
                              const SizedBox(
                                  height: 10),

                              SizedBox(
                                width:
                                    double.infinity,
                                height:
                                    50,

                                child:
                                    ElevatedButton.icon(
                                  onPressed:
                                      () {
                                    showReactivateDialog(
                                      resident,
                                    );
                                  },

                                  icon:
                                      const Icon(
                                    Icons.restart_alt,
                                  ),

                                  label:
                                      const Text(
                                    'Reactivate Resident',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );

                        final Widget historyPanel =
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Resident History',
                              style:
                                  TextStyle(
                                fontSize: 19,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(
                                height: 12),

                            if (history.isEmpty)
                              const Text(
                                'No lifecycle history.',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.grey,
                                ),
                              )
                            else
                              ...history.map(
                                statusHistoryItem,
                              ),

                            const SizedBox(
                                height: 25),

                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Payment History',
                                    style:
                                        TextStyle(
                                      fontSize: 19,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),

                                Text(
                                  '${payments.length} transaction${payments.length == 1 ? '' : 's'}',
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                                height: 12),

                            if (payments.isEmpty)
                              const Text(
                                'No payment transactions.',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.grey,
                                ),
                              )
                            else
                              ...payments.map(
                                paymentHistoryItem,
                              ),
                          ],
                        );

                        if (desktop) {
                          return Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Expanded(
                                flex: 4,
                                child:
                                    basicInfo,
                              ),

                              const SizedBox(
                                  width: 30),

                              Expanded(
                                flex: 5,
                                child:
                                    historyPanel,
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            basicInfo,

                            const SizedBox(
                                height: 30),

                            const Divider(),

                            const SizedBox(
                                height: 20),

                            historyPanel,
                          ],
                        );
                      },
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
    reactivationPaymentController
        .dispose();

    super.dispose();
  }
}