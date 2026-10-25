class BillingResult {
  final int fullCyclesAdded;
  final double partialCredit;
  final double remainingBalance;

  final DateTime? paidUntil;
  final DateTime currentDueDate;

  const BillingResult({
    required this.fullCyclesAdded,
    required this.partialCredit,
    required this.remainingBalance,
    required this.paidUntil,
    required this.currentDueDate,
  });
}

class BillingHelper {
  static double _round2(
    double value,
  ) {
    return (value * 100).round() /
        100;
  }

  static DateTime? parseDate(
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
  // APPLY PAYMENT
  // ============================================================

  static BillingResult applyPayment({
    required double payment,
    required double monthlyRate,
    required int billingDays,
    required DateTime referenceDate,

    DateTime? existingPaidUntil,

    double existingPartialCredit = 0,

    DateTime? billingStartedAt,
  }) {
    final DateTime billingStart =
        billingStartedAt ??
            referenceDate;

    final double available =
        existingPartialCredit +
            payment;

    final int fullCycles =
        ((available + 0.0001) /
                monthlyRate)
            .floor();

    final double usedForCycles =
        fullCycles *
            monthlyRate;

    final double newPartialCredit =
        _round2(
      available -
          usedForCycles,
    );

    DateTime? newPaidUntil =
        existingPaidUntil;

    // ==========================================================
    // ONLY CREATE / EXTEND PAID UNTIL IF A FULL CYCLE IS PAID
    // ==========================================================

    if (fullCycles > 0) {
      final DateTime baseDate =
          existingPaidUntil ??
              billingStart;

      newPaidUntil =
          baseDate.add(
        Duration(
          days:
              billingDays *
                  fullCycles,
        ),
      );
    }

    // ==========================================================
    // DUE DATE
    //
    // No full cycle yet:
    // registration + billing cycle
    //
    // Has full paid coverage:
    // next payment is due by paidUntil
    // ==========================================================

    final DateTime currentDueDate =
        newPaidUntil ??
            billingStart.add(
              Duration(
                days:
                    billingDays,
              ),
            );

    double remainingBalance;

    if (newPartialCredit > 0) {
      remainingBalance =
          _round2(
        monthlyRate -
            newPartialCredit,
      );
    } else if (newPaidUntil ==
            null ||
        !newPaidUntil.isAfter(
          referenceDate,
        )) {
      // Resident still has no active paid coverage.
      remainingBalance =
          monthlyRate;
    } else {
      remainingBalance =
          0;
    }

    return BillingResult(
      fullCyclesAdded:
          fullCycles,

      partialCredit:
          newPartialCredit,

      remainingBalance:
          remainingBalance,

      paidUntil:
          newPaidUntil,

      currentDueDate:
          currentDueDate,
    );
  }

  // ============================================================
  // CURRENT DUE DATE
  // ============================================================

  static DateTime getCurrentDueDate({
    required Map<dynamic, dynamic>
        resident,

    required int billingDays,
  }) {
    final DateTime? stored =
        parseDate(
      resident['currentDueDate'],
    );

    if (stored != null) {
      return stored;
    }

    final DateTime? paidUntil =
        parseDate(
      resident['paidUntil'],
    );

    if (paidUntil != null) {
      return paidUntil;
    }

    final DateTime billingStart =
        parseDate(
              resident[
                  'billingStartedAt'],
            ) ??
            parseDate(
              resident[
                  'registeredAt'],
            ) ??
            DateTime.now();

    return billingStart.add(
      Duration(
        days:
            billingDays,
      ),
    );
  }

  // ============================================================
  // REMAINING BALANCE
  // ============================================================

  static double getRemainingBalance({
    required Map<dynamic, dynamic>
        resident,

    required double monthlyRate,

    DateTime? now,
  }) {
    final DateTime current =
        now ??
            DateTime.now();

    final double credit =
        double.tryParse(
              resident[
                          'partialCredit']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    if (credit > 0) {
      return _round2(
        monthlyRate -
            credit,
      );
    }

    final DateTime? paidUntil =
        parseDate(
      resident['paidUntil'],
    );

    if (paidUntil == null ||
        !paidUntil.isAfter(
          current,
        )) {
      return monthlyRate;
    }

    return 0;
  }

  // ============================================================
  // REPAIR OLD BUGGED RECORDS
  //
  // Fixes records where:
  // registeredAt == paidUntil
  // partialCredit > 0
  //
  // Example old bug:
  // Registered Oct 15
  // Paid Until Oct 15
  // Partial ₱1000
  //
  // Becomes:
  // Paid Until null
  // Current Due Date Nov 14
  // ============================================================

  static Map<String, dynamic>
      repairLegacyResidentBilling({
    required Map<String, dynamic>
        resident,

    required double monthlyRate,

    required int billingDays,
  }) {
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(
      resident,
    );

    final DateTime? billingStart =
        parseDate(
              data[
                  'billingStartedAt'],
            ) ??
            parseDate(
              data[
                  'registeredAt'],
            );

    DateTime? paidUntil =
        parseDate(
      data['paidUntil'],
    );

    final double credit =
        double.tryParse(
              data[
                          'partialCredit']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    // Detect the exact bug:
    // partial payment but paidUntil is effectively registration time.
    if (credit > 0 &&
        billingStart != null &&
        paidUntil != null) {
      final Duration difference =
          paidUntil.difference(
        billingStart,
      );

      if (difference.inMinutes
              .abs() <=
          5) {
        paidUntil =
            null;

        data['paidUntil'] =
            null;
      }
    }

    final DateTime dueDate =
        paidUntil ??
            (billingStart ??
                    DateTime.now())
                .add(
              Duration(
                days:
                    billingDays,
              ),
            );

    data['currentDueDate'] =
        dueDate.toIso8601String();

    if (credit > 0) {
      data['balanceDue'] =
          _round2(
        monthlyRate -
            credit,
      );
    } else if (paidUntil ==
            null ||
        !paidUntil.isAfter(
          DateTime.now(),
        )) {
      data['balanceDue'] =
          monthlyRate;
    } else {
      data['balanceDue'] =
          0.0;
    }

    return data;
  }
}