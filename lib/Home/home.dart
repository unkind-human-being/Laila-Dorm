import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../Database/app_database.dart';
import '../Payments/billing_helper.dart';
import '../Payments/payments.dart';
import '../Registration/register.dart';
import '../Reports/reports.dart';
import '../Rooms/rooms.dart';
import '../Settings/settings.dart';
import '../SMS/sms.dart';
import '../SMS/sms_automation.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  final List<String> menuNames = const [
    'Home',
    'Registration',
    'Rooms',
    'SMS',
    'Payments',
    'Reports',
    'Settings',
  ];

  final List<IconData> menuIcons = const [
    Icons.dashboard_outlined,
    Icons.person_add_alt_1_outlined,
    Icons.meeting_room_outlined,
    Icons.sms_outlined,
    Icons.payments_outlined,
    Icons.bar_chart_outlined,
    Icons.settings_outlined,
  ];

  void navigateTo(int index) {
    setState(() => selectedIndex = index);
  }

  Widget getSelectedPage() {
    switch (selectedIndex) {
      case 0:
        return DashboardContent(onNavigate: navigateTo);
      case 1:
        return const RegistrationPage();
      case 2:
        return const RoomsPage();
      case 3:
        return const SmsPage();
      case 4:
        return const PaymentsPage();
      case 5:
        return const ReportsPage();
      case 6:
        return const SettingsPage();
      default:
        return DashboardContent(onNavigate: navigateTo);
    }
  }

  void logout() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  Widget appLogo({double size = 50}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          'assets/LOGO.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.apartment_rounded,
            color: Color(0xFF17617D),
          ),
        ),
      ),
    );
  }

  Widget navigationPanel({bool drawerMode = false}) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/H.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 96,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(
                children: [
                  appLogo(size: 52),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Laila Dormitory',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white70),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: menuNames.length,
                itemBuilder: (context, index) {
                  final bool selected = selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Material(
                      color: selected
                          ? Colors.white.withValues(alpha: .25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          navigateTo(index);
                          if (drawerMode) {
                            Navigator.pop(context);
                          }
                        },
                        child: SizedBox(
                          height: 52,
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Icon(
                                menuIcons[index],
                                color: Colors.white,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  menuNames[index],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (selected)
                                const Padding(
                                  padding: EdgeInsets.only(right: 10),
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white70),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Material(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: logout,
                  borderRadius: BorderRadius.circular(10),
                  child: const SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        SizedBox(width: 14),
                        Icon(Icons.logout, color: Colors.white),
                        SizedBox(width: 14),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget desktopTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE4E7EC)),
        ),
      ),
      child: Row(
        children: [
          Text(
            menuNames[selectedIndex],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D2939),
            ),
          ),
          const Spacer(),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Administrator',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Admin',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            backgroundColor: Color(0xFFD9F3FF),
            child: Icon(
              Icons.person_outline,
              color: Color(0xFF17617D),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool desktop = constraints.maxWidth >= 900;

        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                navigationPanel(),
                Expanded(
                  child: Column(
                    children: [
                      desktopTopBar(),
                      Expanded(child: getSelectedPage()),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Image.asset(
                    'assets/LOGO.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.apartment_rounded,
                      color: Color(0xFF17617D),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    menuNames[selectedIndex],
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          drawer: Drawer(
            width: 275,
            child: navigationPanel(drawerMode: true),
          ),
          body: getSelectedPage(),
        );
      },
    );
  }
}

// ============================================================================
// HOME DASHBOARD
// ============================================================================

class DashboardContent extends StatefulWidget {
  final void Function(int) onNavigate;

  const DashboardContent({
    super.key,
    required this.onNavigate,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  static const int pageSize = 10;

  int smsPage = 0;
  int deactivationPage = 0;

  DashboardSort smsSort = DashboardSort.latest;
  DashboardSort deactivationSort = DashboardSort.latest;

  DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  bool isThisMonth(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  String shortDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  String money(double value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '₱${value.toStringAsFixed(0)}';
    }
    return '₱${value.toStringAsFixed(2)}';
  }

  double partialCredit(Map<dynamic, dynamic> resident) {
    return double.tryParse(
          resident['partialCredit']?.toString() ?? '0',
        ) ??
        0;
  }

  String paymentStatus(
    Map<dynamic, dynamic> resident,
    int dueSoonDays,
  ) {
    final String residentStatus =
        resident['status']?.toString().toLowerCase() ?? 'active';

    if (residentStatus != 'active') {
      return 'inactive';
    }

    final DateTime? paidUntil = parseDate(resident['paidUntil']);
    final double credit = partialCredit(resident);
    final DateTime now = DateTime.now();

    if (credit > 0 &&
        (paidUntil == null || !paidUntil.isAfter(now))) {
      return 'partial';
    }

    if (paidUntil == null || !paidUntil.isAfter(now)) {
      return 'overdue';
    }

    if (paidUntil.difference(now).inDays <= dueSoonDays) {
      return 'dueSoon';
    }

    return 'paid';
  }

  String roomBedText(Map<dynamic, dynamic> resident) {
    final dynamic room = resident['roomNumber'];
    final String bed =
        resident['bedType']?.toString().toLowerCase() ?? '';

    if (room == null) return 'No room assigned';

    return 'Room ${room.toString().padLeft(3, '0')}'
        '${bed.isEmpty ? '' : ' • ${bed == 'upper' ? 'Upper Deck' : 'Lower Deck'}'}';
  }

  List<Map<String, dynamic>> smsActionItems({
    required Box residents,
    required double monthlyRate,
  }) {
    final Map<String, Map<String, dynamic>> byKey = {};

    for (final key in residents.keys) {
      final dynamic raw = residents.get(key);
      if (raw is Map) {
        byKey[key.toString()] = Map<String, dynamic>.from(raw);
      }
    }

    final List<Map<String, dynamic>> result = [];

    for (final queueItem in SmsAutomation.buildQueue()) {
      final String residentKey =
          queueItem['residentKey']?.toString() ?? '';

      final resident = byKey[residentKey];
      if (resident == null) continue;

      final double balance = BillingHelper.getRemainingBalance(
        resident: resident,
        monthlyRate: monthlyRate,
      );

      final DateTime sortDate =
          parseDate(resident['updatedAt']) ??
          parseDate(resident['paidUntil']) ??
          parseDate(resident['registeredAt']) ??
          DateTime(1970);

      result.add({
        'queue': Map<String, dynamic>.from(queueItem),
        'resident': resident,
        'balance': balance,
        'sortDate': sortDate,
      });
    }

    result.sort((a, b) {
      final aDate = a['sortDate'] as DateTime;
      final bDate = b['sortDate'] as DateTime;

      return smsSort == DashboardSort.latest
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });

    return result;
  }

  List<Map<String, dynamic>> deactivationReviewItems({
    required Box residents,
    required int dueSoonDays,
    required double monthlyRate,
  }) {
    final List<Map<String, dynamic>> result = [];
    final DateTime now = DateTime.now();

    for (final key in residents.keys) {
      final dynamic raw = residents.get(key);
      if (raw == null || raw is! Map) continue;

      final resident = Map<String, dynamic>.from(raw);

      final String status =
          resident['status']?.toString().toLowerCase() ?? 'active';

      if (status != 'active') continue;
      if (resident['roomNumber'] == null || resident['bedType'] == null) {
        continue;
      }

      // Partial-payment residents stay in SMS reminders and are not
      // automatically treated as deactivation candidates.
      if (partialCredit(resident) > 0) continue;

      if (paymentStatus(resident, dueSoonDays) != 'overdue') {
        continue;
      }

      final DateTime? paidUntil = parseDate(resident['paidUntil']);
      final int overdueDays = paidUntil == null
          ? 0
          : now.difference(paidUntil).inDays.clamp(0, 999999).toInt();

      result.add({
        'residentKey': key,
        'resident': resident,
        'paidUntil': paidUntil,
        'overdueDays': overdueDays,
        'balance': BillingHelper.getRemainingBalance(
          resident: resident,
          monthlyRate: monthlyRate,
        ),
      });
    }

    result.sort((a, b) {
      final DateTime aDate =
          a['paidUntil'] as DateTime? ?? DateTime(1970);
      final DateTime bDate =
          b['paidUntil'] as DateTime? ?? DateTime(1970);

      return deactivationSort == DashboardSort.latest
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });

    return result;
  }

  String smsCategoryLabel(String category) {
    switch (category) {
      case 'dueSoon':
        return 'DUE SOON';
      case 'partial':
        return 'PARTIAL';
      case 'overdue':
        return 'OVERDUE';
      default:
        return category.toUpperCase();
    }
  }

  Color smsCategoryColor(String category) {
    switch (category) {
      case 'dueSoon':
        return Colors.orange;
      case 'partial':
        return Colors.amber.shade800;
      case 'overdue':
        return Colors.red;
      default:
        return const Color(0xFF17617D);
    }
  }

  int safePage(int requestedPage, int totalItems) {
    if (totalItems <= 0) return 0;
    final int maxPage = (totalItems - 1) ~/ pageSize;
    return requestedPage.clamp(0, maxPage);
  }

  List<Map<String, dynamic>> pageItems(
    List<Map<String, dynamic>> items,
    int requestedPage,
  ) {
    if (items.isEmpty) return [];

    final int page = safePage(requestedPage, items.length);
    final int start = page * pageSize;
    final int end = (start + pageSize).clamp(0, items.length);

    return items.sublist(start, end);
  }

  Widget paginationBar({
    required int currentPage,
    required int totalItems,
    required ValueChanged<int> onPageChanged,
  }) {
    final int page = safePage(currentPage, totalItems);
    final int totalPages =
        totalItems == 0 ? 1 : ((totalItems - 1) ~/ pageSize) + 1;

    final int start = totalItems == 0 ? 0 : (page * pageSize) + 1;
    final int end = totalItems == 0
        ? 0
        : ((page + 1) * pageSize).clamp(0, totalItems);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 460;

        final Widget info = Text(
          totalItems == 0
              ? 'No records'
              : 'Showing $start–$end of $totalItems',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        );

        final Widget buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: page > 0
                  ? () => onPageChanged(page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${page + 1}/$totalPages',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: page < totalPages - 1
                  ? () => onPageChanged(page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        );

        if (compact) {
          return Column(
            children: [
              info,
              const SizedBox(height: 4),
              buttons,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: info),
            buttons,
          ],
        );
      },
    );
  }

  Widget actionPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required int total,
    required DashboardSort sort,
    required ValueChanged<DashboardSort> onSortChanged,
    required Widget content,
    required Widget pagination,
    required VoidCallback onOpen,
    required String openText,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final Widget header = Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF17617D)
                            .withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF17617D),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF17617D)
                                      .withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$total',
                                  style: const TextStyle(
                                    color: Color(0xFF17617D),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final Widget controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<DashboardSort>(
                      value: sort,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: DashboardSort.latest,
                          child: Text('Latest'),
                        ),
                        DropdownMenuItem(
                          value: DashboardSort.oldest,
                          child: Text('Oldest'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onSortChanged(value);
                      },
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: onOpen,
                      child: Text(openText),
                    ),
                  ],
                );

                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: controls,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: header),
                    controls,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 5),
            child: content,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: pagination,
          ),
        ],
      ),
    );
  }

  Widget smsActionRow(Map<String, dynamic> item) {
    final queue = Map<String, dynamic>.from(item['queue']);
    final resident = Map<String, dynamic>.from(item['resident']);

    final String category = queue['category']?.toString() ?? '';
    final Color categoryColor = smsCategoryColor(category);
    final double balance =
        double.tryParse(item['balance']?.toString() ?? '0') ?? 0;

    return InkWell(
      onTap: () => widget.onNavigate(3),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Widget details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${resident['lastName'] ?? ''}, '
                  '${resident['firstName'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  roomBedText(resident),
                  style: const TextStyle(
                    color: Color(0xFF17617D),
                    fontSize: 11,
                  ),
                ),
                Text(
                  queue['number']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            );

            final Widget status = Column(
              crossAxisAlignment: constraints.maxWidth < 500
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    smsCategoryLabel(category),
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance > 0
                      ? '${money(balance)} remaining'
                      : 'Reminder ready',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );

            if (constraints.maxWidth < 500) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 8),
                  status,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 10),
                status,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget deactivationRow(Map<String, dynamic> item) {
    final resident = Map<String, dynamic>.from(item['resident']);
    final DateTime? paidUntil = item['paidUntil'] as DateTime?;
    final int overdueDays =
        int.tryParse(item['overdueDays']?.toString() ?? '0') ?? 0;
    final double balance =
        double.tryParse(item['balance']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Widget details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${resident['lastName'] ?? ''}, '
                '${resident['firstName'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                roomBedText(resident),
                style: const TextStyle(
                  color: Color(0xFF17617D),
                  fontSize: 11,
                ),
              ),
              Text(
                'Expired: ${shortDate(paidUntil)}'
                '${overdueDays > 0 ? ' • $overdueDays day${overdueDays == 1 ? '' : 's'} overdue' : ''}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          );

          final Widget action = Column(
            crossAxisAlignment: constraints.maxWidth < 500
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'REVIEW',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${money(balance)} due',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              TextButton.icon(
                onPressed: () => widget.onNavigate(2),
                icon: const Icon(
                  Icons.meeting_room_outlined,
                  size: 16,
                ),
                label: const Text('Open Rooms'),
              ),
            ],
          );

          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 8),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 10),
              action,
            ],
          );
        },
      ),
    );
  }

  Widget dashboardCardWrap(List<HomeCardData> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        final double cardWidth = width < 560
            ? width
            : width < 900
                ? (width - 14) / 2
                : 245;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map(
                (card) => HomeDashboardCard(
                  width: cardWidth,
                  title: card.title,
                  value: card.value,
                  icon: card.icon,
                  onTap: card.onTap,
                ),
              )
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Box residentsBox =
        Hive.box(AppDatabase.residentsBoxName);
    final Box roomsBox =
        Hive.box(AppDatabase.roomsBoxName);
    final Box paymentsBox =
        Hive.box(AppDatabase.paymentsBoxName);
    final Box settingsBox =
        Hive.box(AppDatabase.settingsBoxName);

    return ValueListenableBuilder(
      valueListenable: residentsBox.listenable(),
      builder: (context, Box residents, _) {
        return ValueListenableBuilder(
          valueListenable: roomsBox.listenable(),
          builder: (context, Box rooms, __) {
            return ValueListenableBuilder(
              valueListenable: paymentsBox.listenable(),
              builder: (context, Box payments, ___) {
                return ValueListenableBuilder(
                  valueListenable: settingsBox.listenable(),
                  builder: (context, Box settings, ____) {
                    final double monthlyRate = double.tryParse(
                          settings
                              .get(
                                'monthlyRate',
                                defaultValue: 3500.0,
                              )
                              .toString(),
                        ) ??
                        3500;

                    final int dueSoonDays = int.tryParse(
                          settings
                              .get(
                                'dueSoonDays',
                                defaultValue: 3,
                              )
                              .toString(),
                        ) ??
                        3;

                    int activeResidents = 0;
                    int inactiveResidents = 0;
                    int studentResidents = 0;
                    int regularResidents = 0;
                    int overdueResidents = 0;
                    int dueSoonResidents = 0;
                    int partialResidents = 0;
                    int occupiedBeds = 0;

                    for (final key in residents.keys) {
                      final dynamic raw = residents.get(key);
                      if (raw == null || raw is! Map) continue;

                      final resident =
                          Map<dynamic, dynamic>.from(raw);

                      final String status =
                          resident['status']?.toString().toLowerCase() ??
                              'active';

                      final String type =
                          resident['residentType']
                                  ?.toString()
                                  .toLowerCase() ??
                              'regular';

                      if (status == 'active') {
                        activeResidents++;

                        if (resident['roomNumber'] != null &&
                            resident['bedType'] != null) {
                          occupiedBeds++;
                        }

                        final String pStatus =
                            paymentStatus(resident, dueSoonDays);

                        if (pStatus == 'overdue') overdueResidents++;
                        if (pStatus == 'dueSoon') dueSoonResidents++;
                        if (pStatus == 'partial') partialResidents++;
                      } else {
                        inactiveResidents++;
                      }

                      if (type == 'student') {
                        studentResidents++;
                      } else {
                        regularResidents++;
                      }
                    }

                    int totalRooms = 0;

                    for (final room in rooms.values) {
                      if (room is Map && room['isActive'] != false) {
                        totalRooms++;
                      }
                    }

                    final int totalBeds = totalRooms * 2;
                    final int vacantBeds = totalBeds - occupiedBeds;

                    double collectedThisMonth = 0;
                    final Set<dynamic> residentsPaidThisMonth = {};

                    for (final key in payments.keys) {
                      final dynamic raw = payments.get(key);
                      if (raw == null || raw is! Map) continue;

                      final DateTime? paidAt = parseDate(raw['paidAt']);

                      if (!isThisMonth(paidAt)) continue;

                      collectedThisMonth += double.tryParse(
                            raw['amount']?.toString() ?? '0',
                          ) ??
                          0;

                      if (raw['residentKey'] != null) {
                        residentsPaidThisMonth.add(raw['residentKey']);
                      }
                    }

                    final smsItems = smsActionItems(
                      residents: residents,
                      monthlyRate: monthlyRate,
                    );

                    final deactivationItems = deactivationReviewItems(
                      residents: residents,
                      dueSoonDays: dueSoonDays,
                      monthlyRate: monthlyRate,
                    );

                    final int safeSmsPage =
                        safePage(smsPage, smsItems.length);

                    final int safeDeactivationPage = safePage(
                      deactivationPage,
                      deactivationItems.length,
                    );

                    final visibleSms =
                        pageItems(smsItems, safeSmsPage);

                    final visibleDeactivation =
                        pageItems(deactivationItems, safeDeactivationPage);

                    final double padding =
                        MediaQuery.of(context).size.width < 600 ? 14 : 26;

                    return Container(
                      color: const Color(0xFFF5F7FA),
                      child: SingleChildScrollView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(padding),
                        child: Center(
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 1180),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Welcome back!',
                                  style: TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Dormitory management overview and action center.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 24),

                                const HomeSectionTitle(
                                  title: 'Residents',
                                  icon: Icons.people_alt_outlined,
                                ),
                                const SizedBox(height: 12),
                                dashboardCardWrap([
                                  HomeCardData(
                                    title: 'All Residents',
                                    value: residents.length.toString(),
                                    icon: Icons.groups_outlined,
                                    onTap: () => widget.onNavigate(5),
                                  ),
                                  HomeCardData(
                                    title: 'Active Residents',
                                    value: activeResidents.toString(),
                                    icon: Icons.person_outline,
                                    onTap: () => widget.onNavigate(5),
                                  ),
                                  HomeCardData(
                                    title: 'Inactive Residents',
                                    value: inactiveResidents.toString(),
                                    icon: Icons.person_off_outlined,
                                    onTap: () => widget.onNavigate(5),
                                  ),
                                  HomeCardData(
                                    title: 'Student Residents',
                                    value: studentResidents.toString(),
                                    icon: Icons.school_outlined,
                                    onTap: () => widget.onNavigate(5),
                                  ),
                                  HomeCardData(
                                    title: 'Regular Residents',
                                    value: regularResidents.toString(),
                                    icon: Icons.badge_outlined,
                                    onTap: () => widget.onNavigate(5),
                                  ),
                                ]),
                                const SizedBox(height: 26),

                                const HomeSectionTitle(
                                  title: 'Rooms & Beds',
                                  icon: Icons.bed_outlined,
                                ),
                                const SizedBox(height: 12),
                                dashboardCardWrap([
                                  HomeCardData(
                                    title: 'Total Rooms',
                                    value: totalRooms.toString(),
                                    icon: Icons.apartment_outlined,
                                    onTap: () => widget.onNavigate(2),
                                  ),
                                  HomeCardData(
                                    title: 'Total Beds',
                                    value: totalBeds.toString(),
                                    icon: Icons.bed_outlined,
                                    onTap: () => widget.onNavigate(2),
                                  ),
                                  HomeCardData(
                                    title: 'Occupied Beds',
                                    value: occupiedBeds.toString(),
                                    icon: Icons.bedroom_parent_outlined,
                                    onTap: () => widget.onNavigate(2),
                                  ),
                                  HomeCardData(
                                    title: 'Vacant Beds',
                                    value: vacantBeds.toString(),
                                    icon: Icons.bedroom_child_outlined,
                                    onTap: () => widget.onNavigate(2),
                                  ),
                                ]),
                                const SizedBox(height: 26),

                                const HomeSectionTitle(
                                  title: 'Payments',
                                  icon: Icons.payments_outlined,
                                ),
                                const SizedBox(height: 12),
                                dashboardCardWrap([
                                  HomeCardData(
                                    title: 'Monthly Rate',
                                    value: money(monthlyRate),
                                    icon: Icons.price_check_outlined,
                                    onTap: () => widget.onNavigate(4),
                                  ),
                                  HomeCardData(
                                    title: 'Paid This Month',
                                    value: residentsPaidThisMonth.length
                                        .toString(),
                                    icon: Icons.check_circle_outline,
                                    onTap: () => widget.onNavigate(4),
                                  ),
                                  HomeCardData(
                                    title: 'Partial Payments',
                                    value: partialResidents.toString(),
                                    icon:
                                        Icons.account_balance_wallet_outlined,
                                    onTap: () => widget.onNavigate(4),
                                  ),
                                  HomeCardData(
                                    title: 'Due Soon',
                                    value: dueSoonResidents.toString(),
                                    icon: Icons.schedule_outlined,
                                    onTap: () => widget.onNavigate(4),
                                  ),
                                  HomeCardData(
                                    title: 'Overdue Residents',
                                    value: overdueResidents.toString(),
                                    icon: Icons.warning_amber_outlined,
                                    onTap: () => widget.onNavigate(4),
                                  ),
                                  HomeCardData(
                                    title: 'Collected This Month',
                                    value: money(collectedThisMonth),
                                    icon:
                                        Icons.account_balance_wallet_outlined,
                                    onTap: () => widget.onNavigate(5),
                                  ),
                                ]),
                                const SizedBox(height: 28),

                                const HomeSectionTitle(
                                  title: 'Action Center',
                                  icon:
                                      Icons.notifications_active_outlined,
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Latest residents who need SMS reminders or room-status review.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final Widget smsPanel = actionPanel(
                                      title: 'Needs SMS',
                                      subtitle:
                                          'Due soon, partial and overdue reminders.',
                                      icon: Icons.sms_outlined,
                                      total: smsItems.length,
                                      sort: smsSort,
                                      onSortChanged: (value) {
                                        setState(() {
                                          smsSort = value;
                                          smsPage = 0;
                                        });
                                      },
                                      onOpen: () => widget.onNavigate(3),
                                      openText: 'Open SMS',
                                      content: visibleSms.isEmpty
                                          ? const EmptyActionState(
                                              icon: Icons.sms_outlined,
                                              text:
                                                  'No residents currently need an SMS reminder.',
                                            )
                                          : Column(
                                              children: visibleSms
                                                  .map(smsActionRow)
                                                  .toList(),
                                            ),
                                      pagination: paginationBar(
                                        currentPage: safeSmsPage,
                                        totalItems: smsItems.length,
                                        onPageChanged: (value) {
                                          setState(() => smsPage = value);
                                        },
                                      ),
                                    );

                                    final Widget deactivatePanel =
                                        actionPanel(
                                      title: 'Deactivation Review',
                                      subtitle:
                                          'Active room occupants with overdue full balances.',
                                      icon: Icons.person_off_outlined,
                                      total: deactivationItems.length,
                                      sort: deactivationSort,
                                      onSortChanged: (value) {
                                        setState(() {
                                          deactivationSort = value;
                                          deactivationPage = 0;
                                        });
                                      },
                                      onOpen: () => widget.onNavigate(2),
                                      openText: 'Open Rooms',
                                      content: visibleDeactivation.isEmpty
                                          ? const EmptyActionState(
                                              icon:
                                                  Icons.check_circle_outline,
                                              text:
                                                  'No room occupants currently need deactivation review.',
                                            )
                                          : Column(
                                              children: visibleDeactivation
                                                  .map(deactivationRow)
                                                  .toList(),
                                            ),
                                      pagination: paginationBar(
                                        currentPage:
                                            safeDeactivationPage,
                                        totalItems:
                                            deactivationItems.length,
                                        onPageChanged: (value) {
                                          setState(
                                            () => deactivationPage = value,
                                          );
                                        },
                                      ),
                                    );

                                    if (constraints.maxWidth >= 900) {
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: smsPanel),
                                          const SizedBox(width: 14),
                                          Expanded(child: deactivatePanel),
                                        ],
                                      );
                                    }

                                    return Column(
                                      children: [
                                        smsPanel,
                                        const SizedBox(height: 14),
                                        deactivatePanel,
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 28),

                                const HomeSectionTitle(
                                  title: 'Quick Access',
                                  icon: Icons.apps_outlined,
                                ),
                                const SizedBox(height: 12),
                                dashboardCardWrap([
                                  HomeCardData(
                                    title: 'Register Resident',
                                    value: 'Open',
                                    icon:
                                        Icons.person_add_alt_1_outlined,
                                    onTap: () => widget.onNavigate(1),
                                  ),
                                  HomeCardData(
                                    title: 'SMS Reminders',
                                    value: '${smsItems.length} Pending',
                                    icon: Icons.sms_outlined,
                                    onTap: () => widget.onNavigate(3),
                                  ),
                                  HomeCardData(
                                    title: 'Management Reports',
                                    value: 'View',
                                    icon: Icons.bar_chart_outlined,
                                    onTap: () => widget.onNavigate(5),
                                  ),
                                  HomeCardData(
                                    title: 'System Settings',
                                    value: 'Manage',
                                    icon: Icons.settings_outlined,
                                    onTap: () => widget.onNavigate(6),
                                  ),
                                ]),
                                const SizedBox(height: 35),
                              ],
                            ),
                          ),
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

// ============================================================================
// SMALL UI HELPERS
// ============================================================================

class HomeSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const HomeSectionTitle({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: const Color(0xFF17617D),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class HomeCardData {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const HomeCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });
}

class HomeDashboardCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const HomeDashboardCard({
    super.key,
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 118,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE4E7EC),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF17617D)
                        .withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF17617D),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyActionState extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyActionState({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 26, horizontal: 15),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

enum DashboardSort {
  latest,
  oldest,
}
