import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../Database/app_database.dart';
import '../Payments/billing_helper.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
  });

  @override
  State<ReportsPage> createState() =>
      _ReportsPageState();
}

class _ReportsPageState
    extends State<ReportsPage> {
  late final Box residentsBox;
  late final Box paymentsBox;
  late final Box roomsBox;
  late final Box settingsBox;

  ReportDateFilter printAllFilter =
      ReportDateFilter.allTime;

  DateTime printAllDate =
      DateTime.now();

  @override
  void initState() {
    super.initState();

    residentsBox = Hive.box(
      AppDatabase.residentsBoxName,
    );

    paymentsBox = Hive.box(
      AppDatabase.paymentsBoxName,
    );

    roomsBox = Hive.box(
      AppDatabase.roomsBoxName,
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

  String get dormitoryName {
    return settingsBox
        .get(
          'dormitoryName',
          defaultValue:
              'Laila Dormitory',
        )
        .toString();
  }

  // ============================================================
  // DATE
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

  String dateText(
    DateTime? date,
  ) {
    if (date == null) {
      return '-';
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

  String dateTimeText(
    DateTime? date,
  ) {
    if (date == null) {
      return '-';
    }

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

    return '${dateText(date)} '
        '$hour:$minute $period';
  }

  bool isThisMonth(
    DateTime? date,
  ) {
    if (date == null) {
      return false;
    }

    final DateTime now =
        DateTime.now();

    return date.year ==
            now.year &&
        date.month ==
            now.month;
  }

  bool matchesDateFilter({
    required DateTime? date,
    required ReportDateFilter filter,
    required DateTime selectedDate,
  }) {
    if (filter ==
        ReportDateFilter.allTime) {
      return true;
    }

    if (date == null) {
      return false;
    }

    switch (filter) {
      case ReportDateFilter.allTime:
        return true;

      case ReportDateFilter.day:
        return date.year ==
                selectedDate.year &&
            date.month ==
                selectedDate.month &&
            date.day ==
                selectedDate.day;

      case ReportDateFilter.month:
        return date.year ==
                selectedDate.year &&
            date.month ==
                selectedDate.month;

      case ReportDateFilter.year:
        return date.year ==
            selectedDate.year;
    }
  }

  String filterTitle(
    ReportDateFilter filter,
    DateTime selectedDate,
  ) {
    switch (filter) {
      case ReportDateFilter.allTime:
        return 'All Time';

      case ReportDateFilter.day:
        return dateText(
          selectedDate,
        );

      case ReportDateFilter.month:
        return '${monthName(selectedDate.month)} '
            '${selectedDate.year}';

      case ReportDateFilter.year:
        return selectedDate.year
            .toString();
    }
  }

  String monthName(
    int month,
  ) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month];
  }

  Future<DateTime?> selectDate(
    BuildContext context,
    DateTime current,
  ) async {
    return showDatePicker(
      context: context,
      initialDate: current,
      firstDate:
          DateTime(2020),
      lastDate:
          DateTime(2100),
    );
  }

  // ============================================================
  // MONEY
  // ============================================================

  String money(
    double value,
  ) {
    return '₱${value.toStringAsFixed(2)}';
  }

  String pdfMoney(
    double value,
  ) {
    return 'PHP ${value.toStringAsFixed(2)}';
  }

  // ============================================================
  // PAYMENT INFORMATION
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

  String residentPaymentStatus(
    Map<dynamic, dynamic> resident,
  ) {
    final String residentStatus =
        resident['status']
                ?.toString()
                .toLowerCase() ??
            'active';

    if (residentStatus !=
        'active') {
      return 'inactive';
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

    if (credit > 0 &&
        (paidUntil == null ||
            !paidUntil.isAfter(
              now,
            ))) {
      return 'partial';
    }

    if (paidUntil == null ||
        now.isAfter(
          paidUntil,
        )) {
      return 'overdue';
    }

    final int remainingDays =
        paidUntil
            .difference(
              now,
            )
            .inDays;

    if (remainingDays <=
        dueSoonDays) {
      return 'dueSoon';
    }

    return 'paid';
  }

  String paymentStatusText(
    Map<dynamic, dynamic> resident,
  ) {
    switch (
        residentPaymentStatus(
      resident,
    )) {
      case 'paid':
        return 'Paid';

      case 'partial':
        return 'Partial Payment';

      case 'dueSoon':
        return 'Due Soon';

      case 'overdue':
        return 'Overdue';

      case 'inactive':
        return 'Inactive';

      default:
        return '-';
    }
  }

  // ============================================================
  // ALL RESIDENTS
  // ============================================================

  List<Map<String, dynamic>>
      allResidents() {
    final List<Map<String, dynamic>>
        result = [];

    for (final key
        in residentsBox.keys) {
      final dynamic raw =
          residentsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      result.add({
        'residentKey':
            key,
        ...Map<String, dynamic>.from(
          raw,
        ),
      });
    }

    return result;
  }

  // ============================================================
  // ALL PAYMENTS
  // ============================================================

  List<Map<String, dynamic>>
      allPayments() {
    final List<Map<String, dynamic>>
        result = [];

    for (final key
        in paymentsBox.keys) {
      final dynamic raw =
          paymentsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      result.add({
        'paymentKey':
            key,
        ...Map<String, dynamic>.from(
          raw,
        ),
      });
    }

    result.sort(
      (
        a,
        b,
      ) {
        final DateTime aDate =
            parseDate(
                  a['paidAt'],
                ) ??
                DateTime(1970);

        final DateTime bDate =
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
  // COUNTS
  // ============================================================

  int countResidents({
    String? status,
    String? type,
  }) {
    return allResidents()
        .where(
          (
            resident,
          ) {
            final String residentStatus =
                resident['status']
                        ?.toString()
                        .toLowerCase() ??
                    'active';

            final String residentType =
                resident['residentType']
                        ?.toString()
                        .toLowerCase() ??
                    'regular';

            if (status != null &&
                residentStatus !=
                    status) {
              return false;
            }

            if (type != null &&
                residentType !=
                    type) {
              return false;
            }

            return true;
          },
        )
        .length;
  }

  int registeredThisMonth() {
    return allResidents()
        .where(
          (
            resident,
          ) {
            return isThisMonth(
              parseDate(
                resident[
                    'registeredAt'],
              ),
            );
          },
        )
        .length;
  }

  int paidThisMonth() {
    final Set<dynamic> residentKeys =
        {};

    for (final payment
        in allPayments()) {
      if (isThisMonth(
        parseDate(
          payment['paidAt'],
        ),
      )) {
        residentKeys.add(
          payment['residentKey'],
        );
      }
    }

    return residentKeys.length;
  }

  double collectedThisMonth() {
    double total = 0;

    for (final payment
        in allPayments()) {
      if (!isThisMonth(
        parseDate(
          payment['paidAt'],
        ),
      )) {
        continue;
      }

      total +=
          double.tryParse(
                payment['amount']
                        ?.toString() ??
                    '0',
              ) ??
              0;
    }

    return total;
  }

  int overdueResidents() {
    return allResidents()
        .where(
          (
            resident,
          ) {
            return residentPaymentStatus(
                  resident,
                ) ==
                'overdue';
          },
        )
        .length;
  }

  int partialResidents() {
    return allResidents()
        .where(
          (
            resident,
          ) {
            return residentPaymentStatus(
                  resident,
                ) ==
                'partial';
          },
        )
        .length;
  }

  // ============================================================
  // ROOM COUNTS
  // ============================================================

  int get totalRooms {
    return roomsBox.values.where(
      (
        room,
      ) {
        if (room is! Map) {
          return false;
        }

        return room['isActive'] !=
            false;
      },
    ).length;
  }

  int get occupiedBeds {
    return allResidents()
        .where(
          (
            resident,
          ) {
            final String status =
                resident['status']
                        ?.toString()
                        .toLowerCase() ??
                    'active';

            return status ==
                    'active' &&
                resident[
                        'roomNumber'] !=
                    null &&
                resident['bedType'] !=
                    null;
          },
        )
        .length;
  }

  int get totalBeds =>
      totalRooms * 2;

  int get vacantBeds =>
      totalBeds - occupiedBeds;

  // ============================================================
  // REPORT TITLES
  // ============================================================

  String reportTitle(
    ReportType type,
  ) {
    switch (type) {
      case ReportType.allResidents:
        return 'All Residents';

      case ReportType.activeResidents:
        return 'Active Residents';

      case ReportType.inactiveResidents:
        return 'Inactive Residents';

      case ReportType.studentResidents:
        return 'Student Residents';

      case ReportType.regularResidents:
        return 'Regular Residents';

      case ReportType.overdueResidents:
        return 'Overdue Residents';

      case ReportType.partialResidents:
        return 'Partial Payment Residents';

      case ReportType.paymentTransactions:
        return 'Payment Transactions';

      case ReportType.occupiedBeds:
        return 'Occupied Beds';

      case ReportType.vacantBeds:
        return 'Vacant Beds';

      case ReportType.totalRooms:
        return 'Room Report';
    }
  }

  bool usesDateFilter(
    ReportType type,
  ) {
    return type !=
            ReportType.occupiedBeds &&
        type !=
            ReportType.vacantBeds &&
        type !=
            ReportType.totalRooms;
  }

  // ============================================================
  // RESIDENT DATE FIELD
  // ============================================================

  DateTime? residentReportDate(
    ReportType type,
    Map<String, dynamic> resident,
  ) {
    switch (type) {
      case ReportType.inactiveResidents:
        return parseDate(
              resident[
                  'deactivatedAt'],
            ) ??
            parseDate(
              resident[
                  'registeredAt'],
            );

      case ReportType.overdueResidents:
        return parseDate(
              resident['paidUntil'],
            ) ??
            parseDate(
              resident[
                  'registeredAt'],
            );

      default:
        return parseDate(
          resident['registeredAt'],
        );
    }
  }

  // ============================================================
  // RESIDENT REPORT FILTER
  // ============================================================

  List<Map<String, dynamic>>
      residentReport({
    required ReportType type,
    required String search,
    required ReportDateFilter
        dateFilter,
    required DateTime filterDate,
  }) {
    List<Map<String, dynamic>>
        residents =
        allResidents();

    switch (type) {
      case ReportType.allResidents:
        break;

      case ReportType.activeResidents:
        residents =
            residents.where(
          (
            resident,
          ) {
            return resident['status']
                    ?.toString()
                    .toLowerCase() ==
                'active';
          },
        ).toList();
        break;

      case ReportType.inactiveResidents:
        residents =
            residents.where(
          (
            resident,
          ) {
            return resident['status']
                    ?.toString()
                    .toLowerCase() ==
                'inactive';
          },
        ).toList();
        break;

      case ReportType.studentResidents:
        residents =
            residents.where(
          (
            resident,
          ) {
            return resident[
                        'residentType']
                    ?.toString()
                    .toLowerCase() ==
                'student';
          },
        ).toList();
        break;

      case ReportType.regularResidents:
        residents =
            residents.where(
          (
            resident,
          ) {
            return resident[
                        'residentType']
                    ?.toString()
                    .toLowerCase() ==
                'regular';
          },
        ).toList();
        break;

      case ReportType.overdueResidents:
        residents =
            residents.where(
          (
            resident,
          ) {
            return residentPaymentStatus(
                  resident,
                ) ==
                'overdue';
          },
        ).toList();
        break;

      case ReportType.partialResidents:
        residents =
            residents.where(
          (
            resident,
          ) {
            return residentPaymentStatus(
                  resident,
                ) ==
                'partial';
          },
        ).toList();
        break;

      case ReportType.paymentTransactions:
      case ReportType.occupiedBeds:
      case ReportType.vacantBeds:
      case ReportType.totalRooms:
        return [];
    }

    if (dateFilter !=
        ReportDateFilter.allTime) {
      residents =
          residents.where(
        (
          resident,
        ) {
          return matchesDateFilter(
            date:
                residentReportDate(
              type,
              resident,
            ),
            filter:
                dateFilter,
            selectedDate:
                filterDate,
          );
        },
      ).toList();
    }

    final String query =
        search
            .trim()
            .toLowerCase();

    if (query.isNotEmpty) {
      residents =
          residents.where(
        (
          resident,
        ) {
          final String first =
              '${resident['firstName'] ?? ''}'
                  .toLowerCase();

          final String last =
              '${resident['lastName'] ?? ''}'
                  .toLowerCase();

          final String contact =
              '${resident['contactNumber'] ?? ''}'
                  .toLowerCase();

          final String address =
              '${resident['permanentAddress'] ?? ''}'
                  .toLowerCase();

          final String room =
              '${resident['roomNumber'] ?? ''}'
                  .toLowerCase();

          final String status =
              '${resident['status'] ?? ''}'
                  .toLowerCase();

          return first.contains(
                  query,
                ) ||
              last.contains(
                query,
              ) ||
              contact.contains(
                query,
              ) ||
              address.contains(
                query,
              ) ||
              room.contains(
                query,
              ) ||
              status.contains(
                query,
              );
        },
      ).toList();
    }

    residents.sort(
      (
        a,
        b,
      ) {
        final String aName =
            '${a['lastName'] ?? ''}'
                .toLowerCase();

        final String bName =
            '${b['lastName'] ?? ''}'
                .toLowerCase();

        return aName.compareTo(
          bName,
        );
      },
    );

    return residents;
  }

  // ============================================================
  // PAYMENT REPORT FILTER
  // ============================================================

  List<Map<String, dynamic>>
      paymentReport({
    required String search,
    required ReportDateFilter
        dateFilter,
    required DateTime filterDate,
  }) {
    List<Map<String, dynamic>>
        payments =
        allPayments();

    if (dateFilter !=
        ReportDateFilter.allTime) {
      payments =
          payments.where(
        (
          payment,
        ) {
          return matchesDateFilter(
            date:
                parseDate(
              payment['paidAt'],
            ),
            filter:
                dateFilter,
            selectedDate:
                filterDate,
          );
        },
      ).toList();
    }

    final String query =
        search
            .trim()
            .toLowerCase();

    if (query.isNotEmpty) {
      payments =
          payments.where(
        (
          payment,
        ) {
          final String first =
              '${payment['firstName'] ?? ''}'
                  .toLowerCase();

          final String last =
              '${payment['lastName'] ?? ''}'
                  .toLowerCase();

          final String room =
              '${payment['roomNumber'] ?? ''}'
                  .toLowerCase();

          final String type =
              '${payment['type'] ?? ''}'
                  .toLowerCase();

          return first.contains(
                  query,
                ) ||
              last.contains(
                query,
              ) ||
              room.contains(
                query,
              ) ||
              type.contains(
                query,
              );
        },
      ).toList();
    }

    return payments;
  }

  // ============================================================
  // ACTIVE RESIDENT FOR BED
  // ============================================================

  Map<String, dynamic>?
      residentForBed(
    int room,
    String bed,
  ) {
    for (final resident
        in allResidents()) {
      final String status =
          resident['status']
                  ?.toString()
                  .toLowerCase() ??
              'active';

      if (status != 'active') {
        continue;
      }

      if (resident['roomNumber'] ==
              room &&
          resident['bedType']
                  ?.toString()
                  .toLowerCase() ==
              bed) {
        return resident;
      }
    }

    return null;
  }

  // ============================================================
  // ROOM REPORT
  // ============================================================

  List<Map<String, dynamic>>
      roomReport({
    required ReportType type,
    required String search,
  }) {
    final List<Map<String, dynamic>>
        rows = [];

    final List<int> roomNumbers =
        [];

    for (final raw
        in roomsBox.values) {
      if (raw is! Map ||
          raw['isActive'] == false) {
        continue;
      }

      final int? number =
          raw['roomNumber'] is int
              ? raw['roomNumber']
              : int.tryParse(
                  raw['roomNumber']
                          ?.toString() ??
                      '',
                );

      if (number != null) {
        roomNumbers.add(
          number,
        );
      }
    }

    roomNumbers.sort();

    for (final room
        in roomNumbers) {
      final upper =
          residentForBed(
        room,
        'upper',
      );

      final lower =
          residentForBed(
        room,
        'lower',
      );

      if (type ==
          ReportType.totalRooms) {
        rows.add({
          'roomNumber':
              room,
          'upper':
              upper,
          'lower':
              lower,
          'occupied':
              (upper != null ? 1 : 0) +
                  (lower != null
                      ? 1
                      : 0),
        });
      }

      if (type ==
          ReportType.occupiedBeds) {
        if (upper != null) {
          rows.add({
            'roomNumber':
                room,
            'bedType':
                'upper',
            'resident':
                upper,
          });
        }

        if (lower != null) {
          rows.add({
            'roomNumber':
                room,
            'bedType':
                'lower',
            'resident':
                lower,
          });
        }
      }

      if (type ==
          ReportType.vacantBeds) {
        if (upper == null) {
          rows.add({
            'roomNumber':
                room,
            'bedType':
                'upper',
          });
        }

        if (lower == null) {
          rows.add({
            'roomNumber':
                room,
            'bedType':
                'lower',
          });
        }
      }
    }

    final String query =
        search
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      return rows;
    }

    return rows.where(
      (
        row,
      ) {
        final String room =
            '${row['roomNumber'] ?? ''}'
                .toLowerCase();

        final String bed =
            '${row['bedType'] ?? ''}'
                .toLowerCase();

        String residentName =
            '';

        final dynamic resident =
            row['resident'];

        if (resident is Map) {
          residentName =
              '${resident['firstName'] ?? ''} '
              '${resident['lastName'] ?? ''}'
                  .toLowerCase();
        }

        return room.contains(
                query,
              ) ||
            bed.contains(
              query,
            ) ||
            residentName.contains(
              query,
            );
      },
    ).toList();
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width:
          260,
      height:
          155,

      child:
          Material(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        child:
            InkWell(
          borderRadius:
              BorderRadius.circular(
            16,
          ),

          onTap:
              onTap,

          child:
              Container(
            padding:
                const EdgeInsets.all(
              20,
            ),

            decoration:
                BoxDecoration(
              border:
                  Border.all(
                color:
                    const Color(
                        0xFFE4E7EC),
              ),

              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),

            child:
                Row(
              children: [
                Container(
                  width:
                      60,
                  height:
                      60,

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                                0xFF17617D)
                            .withOpacity(
                      .08,
                    ),

                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),

                  child:
                      Icon(
                    icon,
                    size:
                        29,

                    color:
                        const Color(
                            0xFF17617D),
                  ),
                ),

                const SizedBox(
                    width: 16),

                Expanded(
                  child:
                      Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,

                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Text(
                        value,

                        style:
                            const TextStyle(
                          fontSize:
                              25,

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                          height: 3),

                      Text(
                        title,

                        style:
                            const TextStyle(
                          fontSize:
                              12,

                          color:
                              Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons
                      .chevron_right,

                  color:
                      Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget statusChip(
    String status,
  ) {
    Color color;

    switch (
        status.toLowerCase()) {
      case 'active':
      case 'paid':
        color =
            Colors.green;
        break;

      case 'inactive':
        color =
            Colors.grey;
        break;

      case 'overdue':
        color =
            Colors.red;
        break;

      case 'partial':
      case 'partial payment':
        color =
            Colors.amber
                .shade800;
        break;

      default:
        color =
            Colors.orange;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            8,
        vertical:
            4,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          .10,
        ),

        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child:
          Text(
        status.toUpperCase(),

        style:
            TextStyle(
          color:
              color,

          fontSize:
              10,

          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // RESIDENT ROW
  // ============================================================

  Widget residentRow(
    Map<String, dynamic> resident,
  ) {
    final dynamic picture =
        resident['picture'];

    final double balance =
        remainingBalance(
      resident,
    );

    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          const BoxDecoration(
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
                    0xFFF0F1F3),
          ),
        ),
      ),

      child:
          Row(
        children: [
          CircleAvatar(
            radius:
                22,

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
            flex:
                2,

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

                Text(
                  resident[
                              'residentType'] ==
                          'student'
                      ? 'Student Resident'
                      : 'Regular Resident',

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

          Expanded(
            child:
                Text(
              resident['roomNumber'] ==
                      null
                  ? '-'
                  : 'Room ${resident['roomNumber'].toString().padLeft(3, '0')}',
            ),
          ),

          Expanded(
            child:
                Text(
              resident['bedType'] ==
                      'upper'
                  ? 'Upper'
                  : resident[
                              'bedType'] ==
                          'lower'
                      ? 'Lower'
                      : '-',
            ),
          ),

          Expanded(
            child:
                Text(
              money(
                balance,
              ),

              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w600,

                color:
                    balance > 0
                        ? Colors
                            .orange
                            .shade800
                        : Colors
                            .green,
              ),
            ),
          ),

          Expanded(
            flex:
                2,

            child:
                Text(
              dateTimeText(
                parseDate(
                  resident[
                      'registeredAt'],
                ),
              ),

              style:
                  const TextStyle(
                fontSize:
                    11,
              ),
            ),
          ),

          statusChip(
            resident['status']
                    ?.toString() ??
                'active',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT ROW
  // ============================================================

  Widget paymentRow(
    Map<String, dynamic> payment,
  ) {
    final double amount =
        double.tryParse(
              payment['amount']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    final double balance =
        double.tryParse(
              payment[
                          'balanceDueAfter']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          const BoxDecoration(
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
                    0xFFF0F1F3),
          ),
        ),
      ),

      child:
          Row(
        children: [
          Expanded(
            flex:
                2,

            child:
                Text(
              '${payment['lastName'] ?? ''}, '
              '${payment['firstName'] ?? ''}',

              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child:
                Text(
              payment['roomNumber'] ==
                      null
                  ? '-'
                  : 'Room ${payment['roomNumber'].toString().padLeft(3, '0')}',
            ),
          ),

          Expanded(
            child:
                Text(
              money(
                amount,
              ),

              style:
                  const TextStyle(
                color:
                    Color(
                        0xFF17617D),

                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child:
                Text(
              money(
                balance,
              ),
            ),
          ),

          Expanded(
            flex:
                2,

            child:
                Text(
              dateTimeText(
                parseDate(
                  payment['paidAt'],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROOM ROW
  // ============================================================

  Widget roomRow(
    ReportType type,
    Map<String, dynamic> row,
  ) {
    final int room =
        row['roomNumber'];

    if (type ==
        ReportType.totalRooms) {
      final dynamic upper =
          row['upper'];

      final dynamic lower =
          row['lower'];

      String name(
        dynamic resident,
      ) {
        if (resident is! Map) {
          return 'Vacant';
        }

        return '${resident['lastName'] ?? ''}, '
            '${resident['firstName'] ?? ''}';
      }

      return Container(
        padding:
            const EdgeInsets.all(
          12,
        ),

        decoration:
            const BoxDecoration(
          border:
              Border(
            bottom:
                BorderSide(
              color:
                  Color(
                      0xFFF0F1F3),
            ),
          ),
        ),

        child:
            Row(
          children: [
            Expanded(
              child:
                  Text(
                'Room ${room.toString().padLeft(3, '0')}',

                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              flex:
                  2,

              child:
                  Text(
                'Upper: ${name(upper)}',
              ),
            ),

            Expanded(
              flex:
                  2,

              child:
                  Text(
                'Lower: ${name(lower)}',
              ),
            ),

            Text(
              '${row['occupied']}/2 occupied',
            ),
          ],
        ),
      );
    }

    if (type ==
        ReportType.vacantBeds) {
      return Container(
        padding:
            const EdgeInsets.all(
          12,
        ),

        decoration:
            const BoxDecoration(
          border:
              Border(
            bottom:
                BorderSide(
              color:
                  Color(
                      0xFFF0F1F3),
            ),
          ),
        ),

        child:
            Row(
          children: [
            Expanded(
              child:
                  Text(
                'Room ${room.toString().padLeft(3, '0')}',
              ),
            ),

            Expanded(
              child:
                  Text(
                row['bedType'] ==
                        'upper'
                    ? 'Upper Deck'
                    : 'Lower Deck',
              ),
            ),

            statusChip(
              'Vacant',
            ),
          ],
        ),
      );
    }

    final Map<String, dynamic>
        resident =
        Map<String, dynamic>.from(
      row['resident'],
    );

    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          const BoxDecoration(
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
                    0xFFF0F1F3),
          ),
        ),
      ),

      child:
          Row(
        children: [
          Expanded(
            child:
                Text(
              'Room ${room.toString().padLeft(3, '0')}',
            ),
          ),

          Expanded(
            child:
                Text(
              row['bedType'] ==
                      'upper'
                  ? 'Upper Deck'
                  : 'Lower Deck',
            ),
          ),

          Expanded(
            flex:
                2,

            child:
                Text(
              '${resident['lastName'] ?? ''}, '
              '${resident['firstName'] ?? ''}',

              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          statusChip(
            'Occupied',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OPEN REPORT FORM
  // ============================================================

  Future<void> openReport({
    required ReportType type,
    String? customTitle,
    ReportDateFilter initialFilter =
        ReportDateFilter.allTime,
    DateTime? initialDate,
  }) async {
    final TextEditingController
        searchController =
        TextEditingController();

    String appliedSearch =
        '';

    ReportDateFilter dateFilter =
        initialFilter;

    DateTime filterDate =
        initialDate ??
            DateTime.now();

    await showDialog(
      context:
          context,

      barrierDismissible:
          false,

      builder:
          (
        context,
      ) {
        return StatefulBuilder(
          builder:
              (
            context,
            setDialogState,
          ) {
            final String title =
                customTitle ??
                    reportTitle(
                      type,
                    );

            final bool roomType =
                !usesDateFilter(
              type,
            );

            final List<
                    Map<String, dynamic>>
                residentRows =
                roomType ||
                        type ==
                            ReportType
                                .paymentTransactions
                    ? []
                    : residentReport(
                        type:
                            type,

                        search:
                            appliedSearch,

                        dateFilter:
                            dateFilter,

                        filterDate:
                            filterDate,
                      );

            final List<
                    Map<String, dynamic>>
                paymentRows =
                type ==
                        ReportType
                            .paymentTransactions
                    ? paymentReport(
                        search:
                            appliedSearch,

                        dateFilter:
                            dateFilter,

                        filterDate:
                            filterDate,
                      )
                    : [];

            final List<
                    Map<String, dynamic>>
                roomRows =
                roomType
                    ? roomReport(
                        type:
                            type,
                        search:
                            appliedSearch,
                      )
                    : [];

            final int recordCount =
                type ==
                        ReportType
                            .paymentTransactions
                    ? paymentRows.length
                    : roomType
                        ? roomRows.length
                        : residentRows
                            .length;

            return Dialog(
              insetPadding:
                  const EdgeInsets.all(
                18,
              ),

              child:
                  SizedBox(
                width:
                    MediaQuery.of(
                          context,
                        ).size.width *
                        .92,

                height:
                    MediaQuery.of(
                          context,
                        ).size.height *
                        .90,

                child:
                    Column(
                  children: [
                    // ==========================================
                    // REPORT WINDOW HEADER
                    // ==========================================

                    Container(
                      padding:
                          const EdgeInsets
                              .all(
                        20,
                      ),

                      decoration:
                          const BoxDecoration(
                        border:
                            Border(
                          bottom:
                              BorderSide(
                            color:
                                Color(
                                    0xFFE4E7EC),
                          ),
                        ),
                      ),

                      child:
                          Row(
                        children: [
                          Container(
                            width:
                                48,
                            height:
                                48,

                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                          0xFF17617D)
                                      .withOpacity(
                                .08,
                              ),

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                            ),

                            child:
                                const Icon(
                              Icons
                                  .assessment_outlined,

                              color:
                                  Color(
                                      0xFF17617D),
                            ),
                          ),

                          const SizedBox(
                              width: 14),

                          Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                Text(
                                  title,

                                  style:
                                      const TextStyle(
                                    fontSize:
                                        23,

                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                Text(
                                  '$recordCount record'
                                  '${recordCount == 1 ? '' : 's'}',

                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            tooltip:
                                'Close',

                            onPressed:
                                () {
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

                    // ==========================================
                    // SEARCH + FILTER
                    // ==========================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .all(
                        16,
                      ),

                      child:
                          Column(
                        children: [
                          LayoutBuilder(
                            builder:
                                (
                              context,
                              constraints,
                            ) {
                              final bool compact =
                                  constraints
                                          .maxWidth <
                                      850;

                              final Widget search =
                                  Row(
                                children: [
                                  Expanded(
                                    child:
                                        TextField(
                                      controller:
                                          searchController,

                                      onSubmitted:
                                          (_) {
                                        setDialogState(
                                          () {
                                            appliedSearch =
                                                searchController
                                                    .text
                                                    .trim();
                                          },
                                        );
                                      },

                                      decoration:
                                          const InputDecoration(
                                        labelText:
                                            'Search',

                                        hintText:
                                            'Search name, room, contact...',

                                        prefixIcon:
                                            Icon(
                                          Icons.search,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                      width: 8),

                                  ElevatedButton.icon(
                                    onPressed:
                                        () {
                                      setDialogState(
                                        () {
                                          appliedSearch =
                                              searchController
                                                  .text
                                                  .trim();
                                        },
                                      );
                                    },

                                    icon:
                                        const Icon(
                                      Icons.search,
                                    ),

                                    label:
                                        const Text(
                                      'Search',
                                    ),
                                  ),

                                  const SizedBox(
                                      width: 6),

                                  TextButton(
                                    onPressed:
                                        () {
                                      searchController
                                          .clear();

                                      setDialogState(
                                        () {
                                          appliedSearch =
                                              '';
                                        },
                                      );
                                    },

                                    child:
                                        const Text(
                                      'Clear',
                                    ),
                                  ),
                                ],
                              );

                              final Widget filters =
                                  roomType
                                      ? Container(
                                          padding:
                                              const EdgeInsets
                                                  .all(
                                            12,
                                          ),

                                          decoration:
                                              BoxDecoration(
                                            color:
                                                const Color(
                                                    0xFFF7F8FA),

                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                              10,
                                            ),
                                          ),

                                          child:
                                              const Text(
                                            'Room and bed reports show the current occupancy snapshot.',
                                            style:
                                                TextStyle(
                                              color:
                                                  Colors.grey,
                                            ),
                                          ),
                                        )
                                      : Row(
                                          children: [
                                            SizedBox(
                                              width:
                                                  165,

                                              child:
                                                  DropdownButtonFormField<
                                                      ReportDateFilter>(
                                                value:
                                                    dateFilter,

                                                decoration:
                                                    const InputDecoration(
                                                  labelText:
                                                      'Filter By',
                                                ),

                                                items:
                                                    const [
                                                  DropdownMenuItem(
                                                    value:
                                                        ReportDateFilter.allTime,

                                                    child:
                                                        Text(
                                                      'All Time',
                                                    ),
                                                  ),

                                                  DropdownMenuItem(
                                                    value:
                                                        ReportDateFilter.day,

                                                    child:
                                                        Text(
                                                      'Day',
                                                    ),
                                                  ),

                                                  DropdownMenuItem(
                                                    value:
                                                        ReportDateFilter.month,

                                                    child:
                                                        Text(
                                                      'Month',
                                                    ),
                                                  ),

                                                  DropdownMenuItem(
                                                    value:
                                                        ReportDateFilter.year,

                                                    child:
                                                        Text(
                                                      'Year',
                                                    ),
                                                  ),
                                                ],

                                                onChanged:
                                                    (
                                                  value,
                                                ) {
                                                  if (value ==
                                                      null) {
                                                    return;
                                                  }

                                                  setDialogState(
                                                    () {
                                                      dateFilter =
                                                          value;
                                                    },
                                                  );
                                                },
                                              ),
                                            ),

                                            if (dateFilter !=
                                                ReportDateFilter
                                                    .allTime) ...[
                                              const SizedBox(
                                                  width: 8),

                                              OutlinedButton.icon(
                                                onPressed:
                                                    () async {
                                                  final DateTime?
                                                      picked =
                                                      await selectDate(
                                                    context,
                                                    filterDate,
                                                  );

                                                  if (picked ==
                                                      null) {
                                                    return;
                                                  }

                                                  setDialogState(
                                                    () {
                                                      filterDate =
                                                          picked;
                                                    },
                                                  );
                                                },

                                                icon:
                                                    const Icon(
                                                  Icons
                                                      .calendar_month_outlined,
                                                ),

                                                label:
                                                    Text(
                                                  filterTitle(
                                                    dateFilter,
                                                    filterDate,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        );

                              if (compact) {
                                return Column(
                                  children: [
                                    search,

                                    const SizedBox(
                                        height: 12),

                                    Align(
                                      alignment:
                                          Alignment
                                              .centerLeft,

                                      child:
                                          filters,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child:
                                        search,
                                  ),

                                  const SizedBox(
                                      width: 15),

                                  filters,
                                ],
                              );
                            },
                          ),

                          const SizedBox(
                              height: 12),

                          Row(
                            children: [
                              Expanded(
                                child:
                                    Text(
                                  roomType
                                      ? 'Current Snapshot'
                                      : 'Period: ${filterTitle(dateFilter, filterDate)}',

                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.grey,

                                    fontSize:
                                        12,
                                  ),
                                ),
                              ),

                              OutlinedButton.icon(
                                onPressed:
                                    () {
                                  printSingleReport(
                                    type:
                                        type,

                                    title:
                                        title,

                                    search:
                                        appliedSearch,

                                    dateFilter:
                                        dateFilter,

                                    filterDate:
                                        filterDate,
                                  );
                                },

                                icon:
                                    const Icon(
                                  Icons.print,
                                ),

                                label:
                                    const Text(
                                  'Print',
                                ),
                              ),

                              const SizedBox(
                                  width: 8),

                              ElevatedButton.icon(
                                onPressed:
                                    () {
                                  exportSingleReport(
                                    type:
                                        type,

                                    title:
                                        title,

                                    search:
                                        appliedSearch,

                                    dateFilter:
                                        dateFilter,

                                    filterDate:
                                        filterDate,
                                  );
                                },

                                icon:
                                    const Icon(
                                  Icons
                                      .picture_as_pdf_outlined,
                                ),

                                label:
                                    const Text(
                                  'Export PDF',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(
                        height: 1),

                    // ==========================================
                    // REPORT RESULTS
                    // ==========================================

                    Expanded(
                      child:
                          recordCount ==
                                  0
                              ? const Center(
                                  child:
                                      Column(
                                    mainAxisSize:
                                        MainAxisSize.min,

                                    children: [
                                      Icon(
                                        Icons
                                            .search_off_outlined,

                                        size:
                                            55,

                                        color:
                                            Colors.grey,
                                      ),

                                      SizedBox(
                                          height: 10),

                                      Text(
                                        'No records found for this filter.',
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      recordCount,

                                  itemBuilder:
                                      (
                                    context,
                                    index,
                                  ) {
                                    if (type ==
                                        ReportType
                                            .paymentTransactions) {
                                      return paymentRow(
                                        paymentRows[
                                            index],
                                      );
                                    }

                                    if (roomType) {
                                      return roomRow(
                                        type,
                                        roomRows[
                                            index],
                                      );
                                    }

                                    return residentRow(
                                      residentRows[
                                          index],
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  // ============================================================
  // PDF HEADER
  // ============================================================

  pw.Widget pdfHeader({
    required String title,
    required DateTime generated,
    required String filter,
    String search = '',
  }) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment
              .start,

      children: [
        pw.Text(
          dormitoryName,

          style:
              pw.TextStyle(
            fontSize:
                20,

            fontWeight:
                pw.FontWeight.bold,
          ),
        ),

        pw.Text(
          'Dormitory Management System',

          style:
              const pw.TextStyle(
            fontSize:
                10,
          ),
        ),

        pw.SizedBox(
            height: 12),

        pw.Text(
          title,

          style:
              pw.TextStyle(
            fontSize:
                16,

            fontWeight:
                pw.FontWeight.bold,
          ),
        ),

        pw.Text(
          'Period: $filter',

          style:
              const pw.TextStyle(
            fontSize:
                9,
          ),
        ),

        if (search.isNotEmpty)
          pw.Text(
            'Search: $search',

            style:
                const pw.TextStyle(
              fontSize:
                  9,
            ),
          ),

        pw.Text(
          'Generated: '
          '${dateTimeText(generated)}',

          style:
              const pw.TextStyle(
            fontSize:
                9,
          ),
        ),

        pw.Divider(),
      ],
    );
  }

  // ============================================================
  // SINGLE REPORT PDF
  // ============================================================

  Future<Uint8List>
      buildSingleReportPdf({
    required ReportType type,
    required String title,
    required String search,
    required ReportDateFilter
        dateFilter,
    required DateTime filterDate,
  }) async {
    final pw.Document pdf =
        pw.Document();

    final DateTime generated =
        DateTime.now();

    final bool roomType =
        !usesDateFilter(
      type,
    );

    if (type ==
        ReportType.paymentTransactions) {
      final payments =
          paymentReport(
        search:
            search,

        dateFilter:
            dateFilter,

        filterDate:
            filterDate,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat:
              PdfPageFormat
                  .a4
                  .landscape,

          margin:
              const pw.EdgeInsets
                  .all(
            25,
          ),

          build:
              (
            context,
          ) =>
                  [
            pdfHeader(
              title:
                  title,

              generated:
                  generated,

              filter:
                  filterTitle(
                dateFilter,
                filterDate,
              ),

              search:
                  search,
            ),

            pw.SizedBox(
                height: 12),

            pw.Table.fromTextArray(
              headers:
                  const [
                'Resident',
                'Room',
                'Amount',
                'Cycles',
                'Balance',
                'Paid At',
                'Paid Until',
                'Type',
              ],

              data:
                  payments.map(
                (
                  payment,
                ) {
                  final double amount =
                      double.tryParse(
                            payment['amount']
                                    ?.toString() ??
                                '0',
                          ) ??
                          0;

                  final double balance =
                      double.tryParse(
                            payment[
                                        'balanceDueAfter']
                                    ?.toString() ??
                                '0',
                          ) ??
                          0;

                  return [
                    '${payment['lastName'] ?? ''}, '
                        '${payment['firstName'] ?? ''}',

                    payment['roomNumber'] ==
                            null
                        ? '-'
                        : 'Room ${payment['roomNumber'].toString().padLeft(3, '0')}',

                    pdfMoney(
                      amount,
                    ),

                    '${payment['cyclesCovered'] ?? 0}',

                    pdfMoney(
                      balance,
                    ),

                    dateTimeText(
                      parseDate(
                        payment['paidAt'],
                      ),
                    ),

                    dateText(
                      parseDate(
                        payment[
                            'newPaidUntil'],
                      ),
                    ),

                    '${payment['type'] ?? ''}',
                  ];
                },
              ).toList(),

              headerStyle:
                  pw.TextStyle(
                fontWeight:
                    pw.FontWeight.bold,
              ),

              cellStyle:
                  const pw.TextStyle(
                fontSize:
                    7,
              ),
            ),
          ],
        ),
      );
    } else if (roomType) {
      final rows =
          roomReport(
        type:
            type,
        search:
            search,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat:
              PdfPageFormat
                  .a4
                  .landscape,

          margin:
              const pw.EdgeInsets
                  .all(
            25,
          ),

          build:
              (
            context,
          ) {
            final List<pw.Widget>
                content = [
              pdfHeader(
                title:
                    title,

                generated:
                    generated,

                filter:
                    'Current Snapshot',

                search:
                    search,
              ),

              pw.Text(
                'Room and bed reports show the current occupancy state.',
                style:
                    const pw.TextStyle(
                  fontSize:
                      9,
                ),
              ),

              pw.SizedBox(
                  height: 12),
            ];

            if (type ==
                ReportType.totalRooms) {
              content.add(
                pw.Table.fromTextArray(
                  headers:
                      const [
                    'Room',
                    'Upper Deck',
                    'Lower Deck',
                    'Occupancy',
                  ],

                  data:
                      rows.map(
                    (
                      row,
                    ) {
                      String occupant(
                        dynamic resident,
                      ) {
                        if (resident
                            is! Map) {
                          return 'Vacant';
                        }

                        return '${resident['lastName'] ?? ''}, '
                            '${resident['firstName'] ?? ''}';
                      }

                      return [
                        'Room ${row['roomNumber'].toString().padLeft(3, '0')}',

                        occupant(
                          row['upper'],
                        ),

                        occupant(
                          row['lower'],
                        ),

                        '${row['occupied']}/2',
                      ];
                    },
                  ).toList(),
                ),
              );
            } else {
              content.add(
                pw.Table.fromTextArray(
                  headers:
                      type ==
                              ReportType
                                  .occupiedBeds
                          ? const [
                              'Room',
                              'Bed',
                              'Resident',
                            ]
                          : const [
                              'Room',
                              'Bed',
                              'Status',
                            ],

                  data:
                      rows.map(
                    (
                      row,
                    ) {
                      if (type ==
                          ReportType
                              .occupiedBeds) {
                        final resident =
                            Map<String, dynamic>.from(
                          row['resident'],
                        );

                        return [
                          'Room ${row['roomNumber'].toString().padLeft(3, '0')}',

                          row['bedType'] ==
                                  'upper'
                              ? 'Upper Deck'
                              : 'Lower Deck',

                          '${resident['lastName'] ?? ''}, '
                              '${resident['firstName'] ?? ''}',
                        ];
                      }

                      return [
                        'Room ${row['roomNumber'].toString().padLeft(3, '0')}',

                        row['bedType'] ==
                                'upper'
                            ? 'Upper Deck'
                            : 'Lower Deck',

                        'Vacant',
                      ];
                    },
                  ).toList(),
                ),
              );
            }

            return content;
          },
        ),
      );
    } else {
      final residents =
          residentReport(
        type:
            type,

        search:
            search,

        dateFilter:
            dateFilter,

        filterDate:
            filterDate,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat:
              PdfPageFormat
                  .a4
                  .landscape,

          margin:
              const pw.EdgeInsets
                  .all(
            25,
          ),

          build:
              (
            context,
          ) =>
                  [
            pdfHeader(
              title:
                  title,

              generated:
                  generated,

              filter:
                  filterTitle(
                dateFilter,
                filterDate,
              ),

              search:
                  search,
            ),

            pw.SizedBox(
                height: 12),

            pw.Table.fromTextArray(
              headers:
                  const [
                'Name',
                'Type',
                'Resident Status',
                'Payment',
                'Balance',
                'Room',
                'Bed',
                'Contact',
                'Registered',
                'Paid Until',
              ],

              data:
                  residents.map(
                (
                  resident,
                ) {
                  return [
                    '${resident['lastName'] ?? ''}, '
                        '${resident['firstName'] ?? ''}',

                    resident['residentType'] ==
                            'student'
                        ? 'Student'
                        : 'Regular',

                    '${resident['status'] ?? 'active'}'
                        .toUpperCase(),

                    paymentStatusText(
                      resident,
                    ),

                    pdfMoney(
                      remainingBalance(
                        resident,
                      ),
                    ),

                    resident['roomNumber'] ==
                            null
                        ? '-'
                        : 'Room ${resident['roomNumber'].toString().padLeft(3, '0')}',

                    resident['bedType'] ==
                            'upper'
                        ? 'Upper'
                        : resident[
                                    'bedType'] ==
                                'lower'
                            ? 'Lower'
                            : '-',

                    '${resident['contactNumber'] ?? ''}',

                    dateText(
                      parseDate(
                        resident[
                            'registeredAt'],
                      ),
                    ),

                    dateText(
                      parseDate(
                        resident[
                            'paidUntil'],
                      ),
                    ),
                  ];
                },
              ).toList(),

              headerStyle:
                  pw.TextStyle(
                fontWeight:
                    pw.FontWeight.bold,
              ),

              cellStyle:
                  const pw.TextStyle(
                fontSize:
                    6.8,
              ),
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }

  // ============================================================
  // PRINT SINGLE REPORT
  // ============================================================

  Future<void> printSingleReport({
    required ReportType type,
    required String title,
    required String search,
    required ReportDateFilter
        dateFilter,
    required DateTime filterDate,
  }) async {
    await Printing.layoutPdf(
      onLayout:
          (_) =>
              buildSingleReportPdf(
        type:
            type,

        title:
            title,

        search:
            search,

        dateFilter:
            dateFilter,

        filterDate:
            filterDate,
      ),
    );
  }

  // ============================================================
  // EXPORT SINGLE REPORT
  // ============================================================

  Future<void> exportSingleReport({
    required ReportType type,
    required String title,
    required String search,
    required ReportDateFilter
        dateFilter,
    required DateTime filterDate,
  }) async {
    final Uint8List bytes =
        await buildSingleReportPdf(
      type:
          type,

      title:
          title,

      search:
          search,

      dateFilter:
          dateFilter,

      filterDate:
          filterDate,
    );

    await Printing.sharePdf(
      bytes:
          bytes,

      filename:
          '${title.replaceAll(' ', '_')}_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ============================================================
  // BUILD PRINT ALL PDF
  // ============================================================

  Future<Uint8List>
      buildAllReportsPdf() async {
    final pw.Document pdf =
        pw.Document();

    final DateTime generated =
        DateTime.now();

    final residents =
        residentReport(
      type:
          ReportType.allResidents,

      search:
          '',

      dateFilter:
          printAllFilter,

      filterDate:
          printAllDate,
    );

    final payments =
        paymentReport(
      search:
          '',

      dateFilter:
          printAllFilter,

      filterDate:
          printAllDate,
    );

    final rooms =
        roomReport(
      type:
          ReportType.totalRooms,

      search:
          '',
    );

    double collected =
        0;

    for (final payment
        in payments) {
      collected +=
          double.tryParse(
                payment['amount']
                        ?.toString() ??
                    '0',
              ) ??
              0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat:
            PdfPageFormat
                .a4
                .landscape,

        margin:
            const pw.EdgeInsets.all(
          24,
        ),

        build:
            (
          context,
        ) =>
                [
          pdfHeader(
            title:
                'Complete Management Report',

            generated:
                generated,

            filter:
                filterTitle(
              printAllFilter,
              printAllDate,
            ),
          ),

          pw.SizedBox(
              height: 10),

          pw.Text(
            'Summary',

            style:
                pw.TextStyle(
              fontSize:
                  14,

              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(
              height: 5),

          pw.Wrap(
            spacing:
                12,
            runSpacing:
                6,

            children: [
              pw.Text(
                'Residents: ${residents.length}',
              ),

              pw.Text(
                'Payments: ${payments.length}',
              ),

              pw.Text(
                'Collected: ${pdfMoney(collected)}',
              ),

              pw.Text(
                'Current Rooms: $totalRooms',
              ),

              pw.Text(
                'Current Occupied Beds: $occupiedBeds',
              ),

              pw.Text(
                'Current Vacant Beds: $vacantBeds',
              ),
            ],
          ),

          pw.SizedBox(
              height: 18),

          pw.Text(
            'Residents',

            style:
                pw.TextStyle(
              fontSize:
                  13,

              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(
              height: 6),

          pw.Table.fromTextArray(
            headers:
                const [
              'Name',
              'Type',
              'Status',
              'Payment',
              'Balance',
              'Room',
              'Bed',
              'Registered',
            ],

            data:
                residents.map(
              (
                resident,
              ) {
                return [
                  '${resident['lastName'] ?? ''}, '
                      '${resident['firstName'] ?? ''}',

                  resident['residentType'] ==
                          'student'
                      ? 'Student'
                      : 'Regular',

                  '${resident['status'] ?? 'active'}',

                  paymentStatusText(
                    resident,
                  ),

                  pdfMoney(
                    remainingBalance(
                      resident,
                    ),
                  ),

                  resident['roomNumber'] ==
                          null
                      ? '-'
                      : '${resident['roomNumber']}',

                  '${resident['bedType'] ?? '-'}',

                  dateText(
                    parseDate(
                      resident[
                          'registeredAt'],
                    ),
                  ),
                ];
              },
            ).toList(),

            cellStyle:
                const pw.TextStyle(
              fontSize:
                  7,
            ),

            headerStyle:
                pw.TextStyle(
              fontSize:
                  7,

              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(
              height: 18),

          pw.Text(
            'Payments',

            style:
                pw.TextStyle(
              fontSize:
                  13,

              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(
              height: 6),

          pw.Table.fromTextArray(
            headers:
                const [
              'Resident',
              'Amount',
              'Balance',
              'Room',
              'Paid At',
              'Type',
            ],

            data:
                payments.map(
              (
                payment,
              ) {
                final double amount =
                    double.tryParse(
                          payment['amount']
                                  ?.toString() ??
                              '0',
                        ) ??
                        0;

                final double balance =
                    double.tryParse(
                          payment[
                                      'balanceDueAfter']
                                  ?.toString() ??
                              '0',
                        ) ??
                        0;

                return [
                  '${payment['lastName'] ?? ''}, '
                      '${payment['firstName'] ?? ''}',

                  pdfMoney(
                    amount,
                  ),

                  pdfMoney(
                    balance,
                  ),

                  '${payment['roomNumber'] ?? '-'}',

                  dateTimeText(
                    parseDate(
                      payment['paidAt'],
                    ),
                  ),

                  '${payment['type'] ?? ''}',
                ];
              },
            ).toList(),

            cellStyle:
                const pw.TextStyle(
              fontSize:
                  7,
            ),

            headerStyle:
                pw.TextStyle(
              fontSize:
                  7,

              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(
              height: 18),

          pw.Text(
            'Current Room Occupancy',

            style:
                pw.TextStyle(
              fontSize:
                  13,

              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),

          pw.Text(
            'Room occupancy is a current snapshot and is not historical.',

            style:
                const pw.TextStyle(
              fontSize:
                  8,
            ),
          ),

          pw.SizedBox(
              height: 6),

          pw.Table.fromTextArray(
            headers:
                const [
              'Room',
              'Upper Deck',
              'Lower Deck',
              'Occupancy',
            ],

            data:
                rooms.map(
              (
                row,
              ) {
                String occupant(
                  dynamic resident,
                ) {
                  if (resident
                      is! Map) {
                    return 'Vacant';
                  }

                  return '${resident['lastName'] ?? ''}, '
                      '${resident['firstName'] ?? ''}';
                }

                return [
                  '${row['roomNumber']}',

                  occupant(
                    row['upper'],
                  ),

                  occupant(
                    row['lower'],
                  ),

                  '${row['occupied']}/2',
                ];
              },
            ).toList(),

            cellStyle:
                const pw.TextStyle(
              fontSize:
                  7,
            ),

            headerStyle:
                pw.TextStyle(
              fontSize:
                  7,

              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // PRINT ALL
  // ============================================================

  Future<void> printAllReports() async {
    await Printing.layoutPdf(
      onLayout:
          (_) =>
              buildAllReportsPdf(),
    );
  }

  // ============================================================
  // EXPORT ALL
  // ============================================================

  Future<void>
      exportAllReports() async {
    final Uint8List bytes =
        await buildAllReportsPdf();

    await Printing.sharePdf(
      bytes:
          bytes,

      filename:
          'Laila_Complete_Report_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ============================================================
  // TOP PRINT FILTER
  // ============================================================

  Widget printAllFilterBar() {
    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        border:
            Border.all(
          color:
              const Color(
                  0xFFE4E7EC),
        ),
      ),

      child:
          LayoutBuilder(
        builder:
            (
          context,
          constraints,
        ) {
          final List<Widget>
              controls = [
            const Text(
              'Print / Export Period',

              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
                width: 12),

            SizedBox(
              width:
                  160,

              child:
                  DropdownButtonFormField<
                      ReportDateFilter>(
                value:
                    printAllFilter,

                decoration:
                    const InputDecoration(
                  labelText:
                      'Filter By',
                ),

                items:
                    const [
                  DropdownMenuItem(
                    value:
                        ReportDateFilter
                            .allTime,

                    child:
                        Text(
                      'All Time',
                    ),
                  ),

                  DropdownMenuItem(
                    value:
                        ReportDateFilter
                            .day,

                    child:
                        Text(
                      'Day',
                    ),
                  ),

                  DropdownMenuItem(
                    value:
                        ReportDateFilter
                            .month,

                    child:
                        Text(
                      'Month',
                    ),
                  ),

                  DropdownMenuItem(
                    value:
                        ReportDateFilter
                            .year,

                    child:
                        Text(
                      'Year',
                    ),
                  ),
                ],

                onChanged:
                    (
                  value,
                ) {
                  if (value ==
                      null) {
                    return;
                  }

                  setState(
                    () {
                      printAllFilter =
                          value;
                    },
                  );
                },
              ),
            ),

            if (printAllFilter !=
                ReportDateFilter
                    .allTime) ...[
              const SizedBox(
                  width: 8),

              OutlinedButton.icon(
                onPressed:
                    () async {
                  final DateTime?
                      picked =
                      await selectDate(
                    context,
                    printAllDate,
                  );

                  if (picked ==
                      null) {
                    return;
                  }

                  setState(
                    () {
                      printAllDate =
                          picked;
                    },
                  );
                },

                icon:
                    const Icon(
                  Icons
                      .calendar_month_outlined,
                ),

                label:
                    Text(
                  filterTitle(
                    printAllFilter,
                    printAllDate,
                  ),
                ),
              ),
            ],

            const Spacer(),

            OutlinedButton.icon(
              onPressed:
                  printAllReports,

              icon:
                  const Icon(
                Icons.print,
              ),

              label:
                  const Text(
                'Print All',
              ),
            ),

            const SizedBox(
                width: 8),

            ElevatedButton.icon(
              onPressed:
                  exportAllReports,

              icon:
                  const Icon(
                Icons
                    .picture_as_pdf_outlined,
              ),

              label:
                  const Text(
                'Export All PDF',
              ),
            ),
          ];

          if (constraints.maxWidth <
              850) {
            return Wrap(
              spacing:
                  8,

              runSpacing:
                  8,

              crossAxisAlignment:
                  WrapCrossAlignment
                      .center,

              children:
                  controls.where(
                (
                  widget,
                ) {
                  return widget
                      is! Spacer;
                },
              ).toList(),
            );
          }

          return Row(
            children:
                controls,
          );
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return ValueListenableBuilder(
      valueListenable:
          residentsBox.listenable(),

      builder:
          (
        context,
        Box residents,
        _,
      ) {
        return ValueListenableBuilder(
          valueListenable:
              paymentsBox.listenable(),

          builder:
              (
            context,
            Box payments,
            __,
          ) {
            return ValueListenableBuilder(
              valueListenable:
                  roomsBox.listenable(),

              builder:
                  (
                context,
                Box rooms,
                ___,
              ) {
                return ValueListenableBuilder(
                  valueListenable:
                      settingsBox
                          .listenable(),

                  builder:
                      (
                    context,
                    Box settings,
                    ____,
                  ) {
                    final int active =
                        countResidents(
                      status:
                          'active',
                    );

                    final int inactive =
                        countResidents(
                      status:
                          'inactive',
                    );

                    final int students =
                        countResidents(
                      type:
                          'student',
                    );

                    final int regular =
                        countResidents(
                      type:
                          'regular',
                    );

                    return Container(
                      color:
                          const Color(
                              0xFFF5F7FA),

                      child:
                          SingleChildScrollView(
                        padding:
                            const EdgeInsets.all(
                          20,
                        ),

                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            // ==================================
                            // HEADER
                            // ==================================

                            const Text(
                              'Management Reports',

                              style:
                                  TextStyle(
                                fontSize:
                                    28,

                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(
                                height: 4),

                            const Text(
                              'Click any report card to open, search, filter and print its records.',

                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                              ),
                            ),

                            const SizedBox(
                                height: 18),

                            // ==================================
                            // PRINT ALL
                            // ==================================

                            printAllFilterBar(),

                            const SizedBox(
                                height: 22),

                            // ==================================
                            // REPORT CARDS
                            // ==================================

                            Wrap(
                              spacing:
                                  14,

                              runSpacing:
                                  14,

                              children: [
                                summaryCard(
                                  title:
                                      'All Residents',

                                  value:
                                      residentsBox
                                          .length
                                          .toString(),

                                  icon:
                                      Icons
                                          .people_outline,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .allResidents,
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Active Residents',

                                  value:
                                      active
                                          .toString(),

                                  icon:
                                      Icons
                                          .person_outline,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .activeResidents,
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Inactive Residents',

                                  value:
                                      inactive
                                          .toString(),

                                  icon:
                                      Icons
                                          .person_off_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .inactiveResidents,
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Student Residents',

                                  value:
                                      students
                                          .toString(),

                                  icon:
                                      Icons
                                          .school_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .studentResidents,
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Regular Residents',

                                  value:
                                      regular
                                          .toString(),

                                  icon:
                                      Icons
                                          .badge_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .regularResidents,
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Registered This Month',

                                  value:
                                      registeredThisMonth()
                                          .toString(),

                                  icon:
                                      Icons
                                          .person_add_alt_1_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .allResidents,

                                      customTitle:
                                          'Registered Residents',

                                      initialFilter:
                                          ReportDateFilter
                                              .month,

                                      initialDate:
                                          DateTime
                                              .now(),
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Paid This Month',

                                  value:
                                      paidThisMonth()
                                          .toString(),

                                  icon:
                                      Icons
                                          .payments_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .paymentTransactions,

                                      customTitle:
                                          'Payments Received',

                                      initialFilter:
                                          ReportDateFilter
                                              .month,

                                      initialDate:
                                          DateTime
                                              .now(),
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Collected This Month',

                                  value:
                                      money(
                                    collectedThisMonth(),
                                  ),

                                  icon:
                                      Icons
                                          .account_balance_wallet_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .paymentTransactions,

                                      customTitle:
                                          'Collected Payments',

                                      initialFilter:
                                          ReportDateFilter
                                              .month,

                                      initialDate:
                                          DateTime
                                              .now(),
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Partial Payments',

                                  value:
                                      partialResidents()
                                          .toString(),

                                  icon:
                                      Icons
                                          .account_balance_wallet_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .partialResidents,
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Overdue Residents',

                                  value:
                                      overdueResidents()
                                          .toString(),

                                  icon:
                                      Icons
                                          .warning_amber_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .overdueResidents,
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Occupied Beds',

                                  value:
                                      occupiedBeds
                                          .toString(),

                                  icon:
                                      Icons
                                          .bed_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .occupiedBeds,
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Vacant Beds',

                                  value:
                                      vacantBeds
                                          .toString(),

                                  icon:
                                      Icons
                                          .bedroom_child_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .vacantBeds,
                                    );
                                  },
                                ),

                                summaryCard(
                                  title:
                                      'Total Rooms',

                                  value:
                                      totalRooms
                                          .toString(),

                                  icon:
                                      Icons
                                          .apartment_outlined,

                                  onTap:
                                      () {
                                    openReport(
                                      type:
                                          ReportType
                                              .totalRooms,
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(
                                height: 24),

                            Container(
                              width:
                                  double.infinity,

                              padding:
                                  const EdgeInsets.all(
                                18,
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
                                  const Row(
                                children: [
                                  Icon(
                                    Icons
                                        .info_outline,

                                    color:
                                        Color(
                                            0xFF17617D),
                                  ),

                                  SizedBox(
                                      width: 12),

                                  Expanded(
                                    child:
                                        Text(
                                      'Select any card above to open its detailed report. '
                                      'Inside the report you can search records, filter by day, month or year, '
                                      'then print or export exactly what is currently displayed.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
}

// ============================================================
// REPORT TYPES
// ============================================================

enum ReportType {
  allResidents,
  activeResidents,
  inactiveResidents,
  studentResidents,
  regularResidents,
  overdueResidents,
  partialResidents,
  paymentTransactions,
  occupiedBeds,
  vacantBeds,
  totalRooms,
}

// ============================================================
// DATE FILTER
// ============================================================

enum ReportDateFilter {
  allTime,
  day,
  month,
  year,
}