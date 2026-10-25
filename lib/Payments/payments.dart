import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../Database/app_database.dart';
import 'billing_helper.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({
    super.key,
  });

  @override
  State<PaymentsPage> createState() =>
      _PaymentsPageState();
}

class _PaymentsPageState
    extends State<PaymentsPage> {
  late final Box residentsBox;
  late final Box paymentsBox;
  late final Box settingsBox;

  final TextEditingController
      searchController =
      TextEditingController();

  final TextEditingController
      amountController =
      TextEditingController();

  dynamic selectedResidentKey;

  String searchText = '';

  PaymentStatusFilter selectedFilter =
      PaymentStatusFilter.all;

  @override
  void initState() {
    super.initState();

    residentsBox = Hive.box(
      AppDatabase.residentsBoxName,
    );

    paymentsBox = Hive.box(
      AppDatabase.paymentsBoxName,
    );

    settingsBox = Hive.box(
      AppDatabase.settingsBoxName,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        repairLegacyBillingRecords();
      },
    );
  }

  // ============================================================
  // REPAIR OLD PARTIAL-PAYMENT RECORDS
  // ============================================================

  Future<void> repairLegacyBillingRecords() async {
    for (final key in residentsBox.keys.toList()) {
      final dynamic raw =
          residentsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      final Map<String, dynamic> original =
          Map<String, dynamic>.from(
        raw,
      );

      final Map<String, dynamic> repaired =
          BillingHelper.repairLegacyResidentBilling(
        resident:
            original,
        monthlyRate:
            monthlyRate,
        billingDays:
            billingDays,
      );

      final bool changed =
          original.toString() !=
              repaired.toString();

      if (changed) {
        await residentsBox.put(
          key,
          repaired,
        );

        // Repair old partial-payment transactions that stored
        // the registration timestamp as "Paid Until".
        for (final paymentKey
            in paymentsBox.keys.toList()) {
          final dynamic paymentRaw =
              paymentsBox.get(
            paymentKey,
          );

          if (paymentRaw == null ||
              paymentRaw is! Map) {
            continue;
          }

          final Map<String, dynamic> payment =
              Map<String, dynamic>.from(
            paymentRaw,
          );

          if (payment['residentKey'] !=
              key) {
            continue;
          }

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

          if (cycles != 0 ||
              partialAfter <= 0) {
            continue;
          }

          final DateTime? paidAt =
              parseDate(
            payment['paidAt'],
          );

          final DateTime? oldNewPaidUntil =
              parseDate(
            payment['newPaidUntil'],
          );

          if (paidAt == null ||
              oldNewPaidUntil == null) {
            continue;
          }

          final int minutes =
              oldNewPaidUntil
                  .difference(
                    paidAt,
                  )
                  .inMinutes
                  .abs();

          if (minutes <= 5) {
            payment['newPaidUntil'] =
                null;

            payment['currentDueDateAfter'] =
                repaired['currentDueDate'];

            await paymentsBox.put(
              paymentKey,
              payment,
            );
          }
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
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

  int get dueSoonDays {
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

  // ============================================================
  // FORMAT MONEY
  // ============================================================

  String money(
    double amount,
  ) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  // ============================================================
  // PAYMENT INPUT FORMATTER
  // ============================================================

  TextInputFormatter get paymentFormatter {
    return TextInputFormatter.withFunction(
      (
        oldValue,
        newValue,
      ) {
        final RegExp valid =
            RegExp(
          r'^\d*\.?\d{0,2}$',
        );

        return valid.hasMatch(
          newValue.text,
        )
            ? newValue
            : oldValue;
      },
    );
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Not available';
    }

    final String month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$month/$day/${date.year}';
  }

  // ============================================================
  // FORMAT DATE + TIME
  // ============================================================

  String formatDateTime(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Not available';
    }

    final String month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    int hour = date.hour;

    final String period =
        hour >= 12
            ? 'PM'
            : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    final String minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$month/$day/${date.year} '
        '$hour:$minute $period';
  }

  // ============================================================
  // PARSE DATE
  // ============================================================

  DateTime? parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // PARTIAL PAYMENT
  // ============================================================

  double partialCredit(
    Map<dynamic, dynamic> resident,
  ) {
    return double.tryParse(
          resident['partialCredit']
                  ?.toString() ??
              '0',
        ) ??
        0;
  }

  double remainingBalance(
    Map<dynamic, dynamic> resident,
  ) {
    return BillingHelper
        .getRemainingBalance(
      resident:
          resident,

      monthlyRate:
          monthlyRate,
    );
  }

  // ============================================================
  // PAYMENT STATUS
  // ============================================================

  ResidentPaymentStatus paymentStatus(
    Map<dynamic, dynamic> resident,
  ) {
    final String residentStatus =
        resident['status']
                ?.toString()
                .toLowerCase() ??
            'active';

    if (residentStatus != 'active') {
      return ResidentPaymentStatus
          .inactive;
    }

    final DateTime? paidUntil =
        parseDate(
      resident['paidUntil'],
    );

    final double credit =
        partialCredit(
      resident,
    );

    final DateTime now =
        DateTime.now();

    // A resident has paid something,
    // but has not completed the current cycle yet.
    if (credit > 0 &&
        (paidUntil == null ||
            !paidUntil.isAfter(
              now,
            ))) {
      return ResidentPaymentStatus
          .partial;
    }

    if (paidUntil == null ||
        now.isAfter(
          paidUntil,
        )) {
      return ResidentPaymentStatus
          .overdue;
    }

    final Duration remaining =
        paidUntil.difference(
      now,
    );

    if (remaining.inDays <=
        dueSoonDays) {
      return ResidentPaymentStatus
          .dueSoon;
    }

    return ResidentPaymentStatus
        .paid;
  }

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String statusLabel(
    ResidentPaymentStatus status,
  ) {
    switch (status) {
      case ResidentPaymentStatus.paid:
        return 'Paid';

      case ResidentPaymentStatus.partial:
        return 'Partial Payment';

      case ResidentPaymentStatus.dueSoon:
        return 'Due Soon';

      case ResidentPaymentStatus.overdue:
        return 'Overdue';

      case ResidentPaymentStatus.inactive:
        return 'Inactive';
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(
    ResidentPaymentStatus status,
  ) {
    switch (status) {
      case ResidentPaymentStatus.paid:
        return Colors.green;

      case ResidentPaymentStatus.partial:
        return Colors.amber.shade800;

      case ResidentPaymentStatus.dueSoon:
        return Colors.orange;

      case ResidentPaymentStatus.overdue:
        return Colors.red;

      case ResidentPaymentStatus.inactive:
        return Colors.grey;
    }
  }

  // ============================================================
  // PAYMENT STATUS DESCRIPTION
  // ============================================================

  String paymentTimeStatus(
    Map<dynamic, dynamic> resident,
  ) {
    final ResidentPaymentStatus status =
        paymentStatus(
      resident,
    );

    if (status ==
        ResidentPaymentStatus.inactive) {
      return 'Resident is inactive';
    }

    final double balance =
        remainingBalance(
      resident,
    );

    final DateTime? paidUntil =
        parseDate(
      resident['paidUntil'],
    );

    final DateTime currentDueDate =
        BillingHelper.getCurrentDueDate(
      resident:
          resident,
      billingDays:
          billingDays,
    );

    final DateTime now =
        DateTime.now();

    if (status ==
        ResidentPaymentStatus.partial) {
      if (now.isAfter(
        currentDueDate,
      )) {
        final int overdueDays =
            now
                .difference(
                  currentDueDate,
                )
                .inDays;

        return '${money(balance)} remaining • '
            '${overdueDays <= 0 ? 'due today' : '$overdueDays day${overdueDays == 1 ? '' : 's'} overdue'}';
      }

      return '${money(balance)} remaining • '
          'due ${formatDate(currentDueDate)}';
    }

    if (paidUntil == null) {
      return 'No fully paid billing cycle yet';
    }

    if (now.isAfter(
      paidUntil,
    )) {
      final int overdue =
          now
              .difference(
                paidUntil,
              )
              .inDays;

      return overdue <= 0
          ? 'Expired today'
          : '$overdue day'
              '${overdue == 1 ? '' : 's'} overdue';
    }

    final int days =
        paidUntil
            .difference(
              now,
            )
            .inDays;

    if (partialCredit(
          resident,
        ) >
        0) {
      return '$days day'
          '${days == 1 ? '' : 's'} remaining • '
          '${money(balance)} needed for next cycle';
    }

    return '$days day'
        '${days == 1 ? '' : 's'} remaining';
  }

  // ============================================================
  // FILTERED RESIDENTS
  // ============================================================

  List<dynamic>
      filteredResidentKeys() {
    return residentsBox.keys.where(
      (key) {
        final dynamic raw =
            residentsBox.get(key);

        if (raw == null ||
            raw is! Map) {
          return false;
        }

        final resident =
            Map<dynamic, dynamic>.from(
          raw,
        );

        final String firstName =
            '${resident['firstName'] ?? ''}'
                .toLowerCase();

        final String lastName =
            '${resident['lastName'] ?? ''}'
                .toLowerCase();

        final String fullName =
            '$firstName $lastName';

        final String contact =
            '${resident['contactNumber'] ?? ''}'
                .toLowerCase();

        final String room =
            '${resident['roomNumber'] ?? ''}'
                .toLowerCase();

        final bool matchesSearch =
            searchText.isEmpty ||
                firstName.contains(
                  searchText,
                ) ||
                lastName.contains(
                  searchText,
                ) ||
                fullName.contains(
                  searchText,
                ) ||
                contact.contains(
                  searchText,
                ) ||
                room.contains(
                  searchText,
                );

        if (!matchesSearch) {
          return false;
        }

        final ResidentPaymentStatus
            status =
            paymentStatus(
          resident,
        );

        switch (selectedFilter) {
          case PaymentStatusFilter.all:
            return true;

          case PaymentStatusFilter.paid:
            return status ==
                ResidentPaymentStatus
                    .paid;

          case PaymentStatusFilter.partial:
            return status ==
                ResidentPaymentStatus
                    .partial;

          case PaymentStatusFilter.dueSoon:
            return status ==
                ResidentPaymentStatus
                    .dueSoon;

          case PaymentStatusFilter.overdue:
            return status ==
                ResidentPaymentStatus
                    .overdue;

          case PaymentStatusFilter.inactive:
            return status ==
                ResidentPaymentStatus
                    .inactive;
        }
      },
    ).toList();
  }

  // ============================================================
  // STATUS COUNT
  // ============================================================

  int countStatus(
    ResidentPaymentStatus status,
  ) {
    int count = 0;

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

      if (paymentStatus(
            resident,
          ) ==
          status) {
        count++;
      }
    }

    return count;
  }

  // ============================================================
  // QUICK PAYMENT
  // ============================================================

  void setQuickPayment(
    int cycles,
  ) {
    amountController.text =
        (monthlyRate * cycles)
            .toStringAsFixed(
      2,
    );

    setState(() {});
  }

  // ============================================================
  // ADD PAYMENT
  // ============================================================

  Future<void> addPayment() async {
    if (selectedResidentKey == null) {
      showMessage(
        'Please select a resident.',
      );
      return;
    }

    final dynamic raw =
        residentsBox.get(
      selectedResidentKey,
    );

    if (raw == null ||
        raw is! Map) {
      showMessage(
        'Resident record not found.',
      );
      return;
    }

    final Map<String, dynamic>
        resident =
        Map<String, dynamic>.from(
      raw,
    );

    final String residentStatus =
        resident['status']
                ?.toString()
                .toLowerCase() ??
            'active';

    if (residentStatus != 'active') {
      showMessage(
        'Reactivate this resident before recording another payment.',
      );
      return;
    }

    final double? amount =
        double.tryParse(
      amountController.text
          .trim(),
    );

    if (amount == null ||
        amount <= 0) {
      showMessage(
        'Please enter a valid payment amount.',
      );
      return;
    }

    final DateTime now =
        DateTime.now();

    final DateTime? oldPaidUntil =
        parseDate(
      resident['paidUntil'],
    );

    final DateTime billingStartedAt =
        parseDate(
              resident['billingStartedAt'],
            ) ??
            parseDate(
              resident['registeredAt'],
            ) ??
            now;

    final double oldPartialCredit =
        partialCredit(
      resident,
    );

    // ==========================================================
    // APPLY PAYMENT
    //
    // A partial payment does NOT create a fake paidUntil date.
    // paidUntil only changes after at least one full cycle is paid.
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
          oldPaidUntil,

      existingPartialCredit:
          oldPartialCredit,

      billingStartedAt:
          billingStartedAt,
    );

    // ==========================================================
    // UPDATE RESIDENT
    // ==========================================================

    resident['paidUntil'] =
        billing.paidUntil
            ?.toIso8601String();

    resident['currentDueDate'] =
        billing.currentDueDate
            .toIso8601String();

    resident['partialCredit'] =
        billing.partialCredit;

    resident['balanceDue'] =
        billing.remainingBalance;

    resident['updatedAt'] =
        now.toIso8601String();

    await residentsBox.put(
      selectedResidentKey,
      resident,
    );

    // ==========================================================
    // PAYMENT TRANSACTION
    // ==========================================================

    await paymentsBox.add({
      'residentKey':
          selectedResidentKey,

      'residentType':
          resident['residentType'],

      'firstName':
          resident['firstName'],

      'lastName':
          resident['lastName'],

      'roomNumber':
          resident['roomNumber'],

      'bedType':
          resident['bedType'],

      'amount':
          amount,

      'monthlyRate':
          monthlyRate,

      'cyclesCovered':
          billing
              .fullCyclesAdded,

      'partialCreditBefore':
          oldPartialCredit,

      'partialCreditAfter':
          billing
              .partialCredit,

      'balanceDueAfter':
          billing
              .remainingBalance,

      'previousPaidUntil':
          oldPaidUntil
              ?.toIso8601String(),

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
          'Rent Payment',
    });

    amountController.clear();

    if (!mounted) {
      return;
    }

    setState(() {});

    if (billing.remainingBalance >
        0) {
      showMessage(
        'Payment recorded. '
        'Remaining balance: '
        '${money(billing.remainingBalance)}.',
      );
    } else {
      showMessage(
        'Payment recorded successfully. '
        '${billing.fullCyclesAdded} billing cycle'
        '${billing.fullCyclesAdded == 1 ? '' : 's'} completed.',
      );
    }
  }

  // ============================================================
  // PAYMENT HISTORY
  // ============================================================

  List<Map<String, dynamic>>
      paymentHistoryForResident(
    dynamic residentKey,
  ) {
    final List<Map<String, dynamic>>
        transactions = [];

    for (final key
        in paymentsBox.keys) {
      final dynamic raw =
          paymentsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      final payment =
          Map<String, dynamic>.from(
        raw,
      );

      if (payment['residentKey'] ==
          residentKey) {
        transactions.add({
          'paymentKey':
              key,
          ...payment,
        });
      }
    }

    transactions.sort(
      (
        a,
        b,
      ) {
        final DateTime aDate =
            parseDate(
                  a['paidAt'],
                ) ??
                DateTime(
                  1970,
                );

        final DateTime bDate =
            parseDate(
                  b['paidAt'],
                ) ??
                DateTime(
                  1970,
                );

        return bDate.compareTo(
          aDate,
        );
      },
    );

    return transactions;
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
  // FILTER BUTTON
  // ============================================================

  Widget filterButton({
    required String title,
    required PaymentStatusFilter
        filter,
    required int count,
    required IconData icon,
  }) {
    final bool selected =
        selectedFilter ==
            filter;

    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          selectedFilter =
              filter;
        });
      },

      icon:
          Icon(
        icon,
        size: 18,
      ),

      label:
          Text(
        '$title ($count)',
      ),

      style:
          OutlinedButton.styleFrom(
        backgroundColor:
            selected
                ? const Color(
                    0xFFE9F2F6,
                  )
                : Colors.white,

        foregroundColor:
            const Color(
                0xFF17617D),
      ),
    );
  }

  // ============================================================
  // RESIDENT CARD
  // ============================================================

  Widget residentCard({
    required dynamic key,
    required Map<dynamic, dynamic>
        resident,
  }) {
    final dynamic picture =
        resident['picture'];

    final ResidentPaymentStatus
        status =
        paymentStatus(
      resident,
    );

    final Color color =
        statusColor(
      status,
    );

    final String bed =
        resident['bedType']
                ?.toString() ??
            '';

    final dynamic room =
        resident['roomNumber'];

    final DateTime? paidUntil =
        parseDate(
      resident['paidUntil'],
    );

    final double balance =
        remainingBalance(
      resident,
    );

    final bool selected =
        selectedResidentKey ==
            key;

    return Material(
      color:
          selected
              ? const Color(
                  0xFFEAF4F7,
                )
              : const Color(
                  0xFFF9FAFB,
                ),

      borderRadius:
          BorderRadius.circular(
        12,
      ),

      child:
          InkWell(
        borderRadius:
            BorderRadius.circular(
          12,
        ),

        onTap: () {
          setState(() {
            selectedResidentKey =
                key;

            amountController.clear();
          });
        },

        child:
            Container(
          padding:
              const EdgeInsets.all(
            13,
          ),

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              12,
            ),

            border:
                Border.all(
              color:
                  selected
                      ? const Color(
                          0xFF17617D,
                        )
                      : const Color(
                          0xFFE4E7EC,
                        ),
            ),
          ),

          child:
              Row(
            children: [
              CircleAvatar(
                radius:
                    27,

                backgroundImage:
                    picture is Uint8List
                        ? MemoryImage(
                            picture,
                          )
                        : null,

                child:
                    picture is Uint8List
                        ? null
                        : const Icon(
                            Icons
                                .person_outline,
                          ),
              ),

              const SizedBox(
                  width: 12),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Text(
                      '${resident['lastName'] ?? ''}, '
                      '${resident['firstName'] ?? ''}',

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                        height: 3),

                    if (room != null)
                      Text(
                        'Room ${room.toString().padLeft(3, '0')}'
                        '${bed.isEmpty ? '' : ' • ${bed == 'upper' ? 'Upper Deck' : 'Lower Deck'}'}',

                        style:
                            const TextStyle(
                          fontSize:
                              11,

                          color:
                              Color(
                                  0xFF17617D),
                        ),
                      ),

                    const SizedBox(
                        height: 3),

                    Text(
                      status ==
                              ResidentPaymentStatus
                                  .partial
                          ? 'Balance: ${money(balance)}'
                          : paidUntil ==
                                  null
                              ? 'No payment coverage'
                              : 'Paid until ${formatDate(paidUntil)}',

                      style:
                          const TextStyle(
                        fontSize:
                            11,

                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      9,
                  vertical:
                      5,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      color.withOpacity(
                    .10,
                  ),

                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),
                ),

                child:
                    Text(
                  statusLabel(
                    status,
                  ),

                  style:
                      TextStyle(
                    fontSize:
                        10,

                    color:
                        color,

                    fontWeight:
                        FontWeight
                            .bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SELECTED RESIDENT DETAILS
  // ============================================================

  Widget selectedResidentPanel(
    Map<String, dynamic> resident,
  ) {
    final dynamic picture =
        resident['picture'];

    final ResidentPaymentStatus
        status =
        paymentStatus(
      resident,
    );

    final Color color =
        statusColor(
      status,
    );

    final DateTime? registeredAt =
        parseDate(
      resident['registeredAt'],
    );

    final DateTime? paidUntil =
        parseDate(
      resident['paidUntil'],
    );

    final DateTime currentDueDate =
        BillingHelper.getCurrentDueDate(
      resident:
          resident,
      billingDays:
          billingDays,
    );

    final String residentType =
        resident['residentType']
                ?.toString() ??
            'regular';

    final bool active =
        resident['status']
                ?.toString()
                .toLowerCase() ==
            'active';

    final double credit =
        partialCredit(
      resident,
    );

    final double balance =
        remainingBalance(
      resident,
    );

    final List<Map<String, dynamic>>
        history =
        paymentHistoryForResident(
      selectedResidentKey,
    );

    return Container(
      padding:
          const EdgeInsets.all(
        20,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
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
          SingleChildScrollView(
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            const Text(
              'Payment Details',
              style:
                  TextStyle(
                fontSize:
                    21,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
                height: 20),

            Center(
              child:
                  CircleAvatar(
                radius:
                    48,

                backgroundImage:
                    picture is Uint8List
                        ? MemoryImage(
                            picture,
                          )
                        : null,

                child:
                    picture is Uint8List
                        ? null
                        : const Icon(
                            Icons
                                .person_outline,
                            size:
                                44,
                          ),
              ),
            ),

            const SizedBox(
                height: 12),

            Center(
              child:
                  Text(
                '${resident['lastName'] ?? ''}, '
                '${resident['firstName'] ?? ''}'
                '${(resident['middleInitial'] ?? '').toString().isEmpty ? '' : ' ${resident['middleInitial']}.'}',

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  fontSize:
                      19,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(
                height: 4),

            Center(
              child:
                  Text(
                residentType ==
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
                height: 18),

            // ==================================================
            // STATUS
            // ==================================================

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                12,
              ),

              decoration:
                  BoxDecoration(
                color:
                    color.withOpacity(
                  .08,
                ),

                borderRadius:
                    BorderRadius
                        .circular(
                  10,
                ),
              ),

              child:
                  Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,

                children: [
                  Icon(
                    status ==
                            ResidentPaymentStatus
                                .paid
                        ? Icons
                            .check_circle
                        : status ==
                                ResidentPaymentStatus
                                    .partial
                            ? Icons
                                .account_balance_wallet_outlined
                            : status ==
                                    ResidentPaymentStatus
                                        .dueSoon
                                ? Icons
                                    .schedule
                                : status ==
                                        ResidentPaymentStatus
                                            .overdue
                                    ? Icons
                                        .warning
                                    : Icons
                                        .person_off,

                    color:
                        color,
                  ),

                  const SizedBox(
                      width: 8),

                  Text(
                    statusLabel(
                      status,
                    )
                        .toUpperCase(),

                    style:
                        TextStyle(
                      color:
                          color,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
                height: 20),

            // ==================================================
            // BILLING INFO
            // ==================================================

            infoRow(
              'Monthly Room Rate',
              money(
                monthlyRate,
              ),
            ),

            infoRow(
              'Billing Cycle',
              '$billingDays days',
            ),

            infoRow(
              'Amount Applied',
              money(
                credit,
              ),
            ),

            infoRow(
              'Remaining Balance',
              money(
                balance,
              ),
            ),

            infoRow(
              'Registered',
              formatDateTime(
                registeredAt,
              ),
            ),

            infoRow(
              'Current Due Date',
              formatDateTime(
                currentDueDate,
              ),
            ),

            infoRow(
              'Paid Until',
              paidUntil == null
                  ? 'Not fully paid'
                  : formatDateTime(
                      paidUntil,
                    ),
            ),

            infoRow(
              'Payment Status',
              paymentTimeStatus(
                resident,
              ),
            ),

            const SizedBox(
                height: 20),

            // ==================================================
            // ADD PAYMENT
            // ==================================================

            if (active) ...[
              const Divider(),

              const SizedBox(
                  height: 15),

              const Text(
                'Record New Payment',
                style:
                    TextStyle(
                  fontSize:
                      17,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                  height: 6),

              const Text(
                'You can enter any payment amount. '
                'Partial payments are automatically added '
                'toward the resident\'s remaining balance.',
                style:
                    TextStyle(
                  color:
                      Colors.grey,

                  fontSize:
                      11,
                ),
              ),

              const SizedBox(
                  height: 12),

              // Convenience buttons.
              Wrap(
                spacing:
                    8,

                runSpacing:
                    8,

                children: [
                  OutlinedButton(
                    onPressed:
                        () {
                      setQuickPayment(
                        1,
                      );
                    },

                    child:
                        Text(
                      '1 Full Cycle\n'
                      '${money(monthlyRate)}',

                      textAlign:
                          TextAlign.center,
                    ),
                  ),

                  OutlinedButton(
                    onPressed:
                        () {
                      setQuickPayment(
                        2,
                      );
                    },

                    child:
                        Text(
                      '2 Full Cycles\n'
                      '${money(monthlyRate * 2)}',

                      textAlign:
                          TextAlign.center,
                    ),
                  ),

                  OutlinedButton(
                    onPressed:
                        () {
                      amountController.text =
                          balance
                              .toStringAsFixed(
                            2,
                          );

                      setState(
                        () {},
                      );
                    },

                    child:
                        Text(
                      'Pay Balance\n'
                      '${money(balance)}',

                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                  height: 12),

              TextField(
                controller:
                    amountController,

                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal:
                      true,
                ),

                inputFormatters: [
                  paymentFormatter,
                ],

                decoration:
                    InputDecoration(
                  labelText:
                      'Payment Amount',

                  prefixText:
                      '₱ ',

                  helperText:
                      'Any positive amount is accepted.',
                ),
              ),

              const SizedBox(
                  height: 12),

              SizedBox(
                width:
                    double.infinity,

                height:
                    50,

                child:
                    ElevatedButton.icon(
                  onPressed:
                      addPayment,

                  icon:
                      const Icon(
                    Icons
                        .add_card_outlined,
                  ),

                  label:
                      const Text(
                    'Record Payment',
                  ),
                ),
              ),
            ] else ...[
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
                      Colors.grey
                          .withOpacity(
                    .10,
                  ),

                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),

                child:
                    const Text(
                  'This resident is inactive. '
                  'Reactivate them before recording another payment.',

                  textAlign:
                      TextAlign.center,
                ),
              ),
            ],

            const SizedBox(
                height: 25),

            const Divider(),

            const SizedBox(
                height: 15),

            // ==================================================
            // HISTORY
            // ==================================================

            Row(
              children: [
                const Expanded(
                  child:
                      Text(
                    'Payment History',

                    style:
                        TextStyle(
                      fontSize:
                          17,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  '${history.length} transaction'
                  '${history.length == 1 ? '' : 's'}',

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

            const SizedBox(
                height: 12),

            if (history.isEmpty)
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical:
                      20,
                ),

                child:
                    Center(
                  child:
                      Text(
                    'No payment transactions.',

                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ...history.map(
                paymentHistoryTile,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAYMENT HISTORY TILE
  // ============================================================

  Widget paymentHistoryTile(
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

    final DateTime? paidAt =
        parseDate(
      payment['paidAt'],
    );

    final DateTime? newPaidUntil =
        parseDate(
      payment['newPaidUntil'],
    );

    final String description;

    if (cycles == 0) {
      description =
          'Partial payment • '
          '${money(balanceAfter)} remaining';
    } else if (partialAfter > 0) {
      description =
          '$cycles complete cycle'
          '${cycles == 1 ? '' : 's'} + '
          '${money(partialAfter)} toward next cycle';
    } else {
      description =
          '$cycles billing cycle'
          '${cycles == 1 ? '' : 's'} completed';
    }

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            8,
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
          Container(
            width:
                40,

            height:
                40,

            decoration:
                BoxDecoration(
              color:
                  Colors.green
                      .withOpacity(
                .10,
              ),

              borderRadius:
                  BorderRadius
                      .circular(
                9,
              ),
            ),

            child:
                const Icon(
              Icons
                  .payments_outlined,

              color:
                  Colors.green,
            ),
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
                  money(
                    amount,
                  ),

                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                Text(
                  description,

                  style:
                      const TextStyle(
                    fontSize:
                        11,

                    color:
                        Colors.grey,
                  ),
                ),

                Text(
                  formatDateTime(
                    paidAt,
                  ),

                  style:
                      const TextStyle(
                    fontSize:
                        10,

                    color:
                        Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,

            children: [
              const Text(
                'Paid Until',

                style:
                    TextStyle(
                  fontSize:
                      9,

                  color:
                      Colors.grey,
                ),
              ),

              Text(
                cycles == 0 &&
                        newPaidUntil == null
                    ? 'Not fully paid'
                    : formatDate(
                        newPaidUntil,
                      ),

                style:
                    const TextStyle(
                  fontSize:
                      11,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              if (balanceAfter > 0)
                Text(
                  'Balance ${money(balanceAfter)}',

                  style:
                      TextStyle(
                    fontSize:
                        9,

                    color:
                        Colors.orange
                            .shade800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            7,
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Expanded(
            child:
                Text(
              label,

              style:
                  const TextStyle(
                color:
                    Colors.grey,
              ),
            ),
          ),

          const SizedBox(
              width: 10),

          Flexible(
            child:
                Text(
              value,

              textAlign:
                  TextAlign.right,

              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY DETAILS
  // ============================================================

  Widget emptyDetails() {
    return Container(
      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
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
          const Center(
        child:
            Padding(
          padding:
              EdgeInsets.all(
            35,
          ),

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Icon(
                Icons
                    .payments_outlined,

                size:
                    60,

                color:
                    Colors.grey,
              ),

              SizedBox(
                  height: 12),

              Text(
                'Select a Resident',

                style:
                    TextStyle(
                  fontSize:
                      18,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              SizedBox(
                  height: 5),

              Text(
                'Select a resident to view payment status, '
                'remaining balance and payment history.',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESPONSIVE PAYMENT FILTER PANEL
  // ============================================================

  Widget paymentFilterPanel({
    required int total,
    required int paid,
    required int partial,
    required int dueSoon,
    required int overdue,
    required int inactive,
    required bool landscape,
  }) {
    final List<Widget> buttons = [
      filterButton(
        title: 'All',
        filter: PaymentStatusFilter.all,
        count: total,
        icon: Icons.people_outline,
      ),

      filterButton(
        title: 'Paid',
        filter: PaymentStatusFilter.paid,
        count: paid,
        icon: Icons.check_circle_outline,
      ),

      filterButton(
        title: 'Partial',
        filter: PaymentStatusFilter.partial,
        count: partial,
        icon: Icons.account_balance_wallet_outlined,
      ),

      filterButton(
        title: 'Due Soon',
        filter: PaymentStatusFilter.dueSoon,
        count: dueSoon,
        icon: Icons.schedule_outlined,
      ),

      filterButton(
        title: 'Overdue',
        filter: PaymentStatusFilter.overdue,
        count: overdue,
        icon: Icons.warning_amber_outlined,
      ),

      filterButton(
        title: 'Inactive',
        filter: PaymentStatusFilter.inactive,
        count: inactive,
        icon: Icons.person_off_outlined,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        landscape ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) {
              setState(() {
                searchText =
                    value.trim().toLowerCase();
              });
            },
            decoration: const InputDecoration(
              hintText:
                  'Search name, contact number, or room...',
              prefixIcon: Icon(
                Icons.search,
              ),
            ),
          ),

          SizedBox(
            height: landscape ? 8 : 12,
          ),

          // ======================================================
          // LANDSCAPE
          //
          // Keep all filters in one horizontal scrollable row.
          // ======================================================

          if (landscape)
            SizedBox(
              height: 48,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics:
                    const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    buttons[0],
                    const SizedBox(width: 8),
                    buttons[1],
                    const SizedBox(width: 8),
                    buttons[2],
                    const SizedBox(width: 8),
                    buttons[3],
                    const SizedBox(width: 8),
                    buttons[4],
                    const SizedBox(width: 8),
                    buttons[5],
                  ],
                ),
              ),
            )

          // ======================================================
          // PORTRAIT
          // ======================================================
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: buttons,
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
      return ValueListenableBuilder(
        valueListenable:
            paymentsBox.listenable(),

        builder: (
          context,
          Box payments,
          __,
        ) {
          return ValueListenableBuilder(
            valueListenable:
                settingsBox.listenable(),

            builder: (
              context,
              Box settings,
              ___,
            ) {
              final List<dynamic> keys =
                  filteredResidentKeys();

              Map<String, dynamic>?
                  selectedResident;

              if (selectedResidentKey !=
                      null &&
                  residentsBox.containsKey(
                    selectedResidentKey,
                  )) {
                selectedResident =
                    Map<String, dynamic>.from(
                  residentsBox.get(
                    selectedResidentKey,
                  ),
                );
              }

              // =================================================
              // COUNTS
              // =================================================

              final int paid =
                  countStatus(
                ResidentPaymentStatus.paid,
              );

              final int partial =
                  countStatus(
                ResidentPaymentStatus.partial,
              );

              final int dueSoon =
                  countStatus(
                ResidentPaymentStatus.dueSoon,
              );

              final int overdue =
                  countStatus(
                ResidentPaymentStatus.overdue,
              );

              final int inactive =
                  countStatus(
                ResidentPaymentStatus.inactive,
              );

              // =================================================
              // RESIDENT LIST PANEL
              // =================================================

              final Widget residentList =
                  Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                        const Color(
                            0xFFE4E7EC),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Residents',
                              style:
                                  TextStyle(
                                fontSize: 19,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),
                          Text(
                            '${keys.length} record'
                            '${keys.length == 1 ? '' : 's'}',
                            style:
                                const TextStyle(
                              color:
                                  Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(
                      height: 1,
                    ),

                    Expanded(
                      child: keys.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching residents.',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.all(
                                10,
                              ),
                              itemCount:
                                  keys.length,
                              separatorBuilder:
                                  (_, __) =>
                                      const SizedBox(
                                height: 8,
                              ),
                              itemBuilder:
                                  (
                                context,
                                index,
                              ) {
                                final dynamic
                                    key =
                                    keys[index];

                                final resident =
                                    Map<dynamic,
                                            dynamic>.from(
                                  residentsBox
                                      .get(
                                    key,
                                  ),
                                );

                                return residentCard(
                                  key: key,
                                  resident:
                                      resident,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );

              // =================================================
              // DETAILS
              // =================================================

              final Widget details =
                  selectedResident == null
                      ? emptyDetails()
                      : selectedResidentPanel(
                          selectedResident,
                        );

              return LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  final Orientation
                      orientation =
                      MediaQuery.orientationOf(
                    context,
                  );

                  final bool landscape =
                      orientation ==
                          Orientation.landscape;

                  // Landscape phones should use side-by-side
                  // layout instead of the portrait stacked layout.
                  final bool sideBySide =
                      constraints.maxWidth >=
                              900 ||
                          (landscape &&
                              constraints
                                      .maxWidth >=
                                  700);

                  final Widget filters =
                      paymentFilterPanel(
                    total:
                        residentsBox.length,
                    paid: paid,
                    partial: partial,
                    dueSoon: dueSoon,
                    overdue: overdue,
                    inactive: inactive,
                    landscape:
                        landscape,
                  );

                  // =============================================
                  // LANDSCAPE / TABLET / DESKTOP
                  // =============================================

                  if (sideBySide) {
                    return Container(
                      color:
                          const Color(
                              0xFFF5F7FA),
                      padding:
                          const EdgeInsets.all(
                        10,
                      ),
                      child: Column(
                        children: [
                          filters,

                          const SizedBox(
                              height: 10),

                          Expanded(
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .stretch,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child:
                                      residentList,
                                ),

                                const SizedBox(
                                    width: 12),

                                Expanded(
                                  flex: 5,
                                  child:
                                      details,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // =============================================
                  // PORTRAIT PHONE
                  //
                  // Whole page is scrollable.
                  // Resident list gets its own visible area.
                  // Details appear below it.
                  // =============================================

                  return Container(
                    color:
                        const Color(
                            0xFFF5F7FA),
                    child:
                        SingleChildScrollView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      child: Column(
                        children: [
                          filters,

                          const SizedBox(
                              height: 12),

                          // Resident list will ALWAYS be visible.
                          SizedBox(
                            height: 340,
                            child:
                                residentList,
                          ),

                          const SizedBox(
                              height: 12),

                          // Details can be scrolled too.
                          SizedBox(
                            height:
                                selectedResident ==
                                        null
                                    ? 380
                                    : 760,
                            child:
                                details,
                          ),

                          const SizedBox(
                              height: 30),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    searchController.dispose();
    amountController.dispose();

    super.dispose();
  }
}

// ============================================================
// PAYMENT FILTER
// ============================================================

enum PaymentStatusFilter {
  all,
  paid,
  partial,
  dueSoon,
  overdue,
  inactive,
}

// ============================================================
// RESIDENT PAYMENT STATUS
// ============================================================

enum ResidentPaymentStatus {
  paid,
  partial,
  dueSoon,
  overdue,
  inactive,
}