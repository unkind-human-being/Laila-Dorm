import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../Database/app_database.dart';
import '../Sync/sync_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
  });

  @override
  State<SettingsPage> createState() =>
      _SettingsPageState();
}

class _SettingsPageState
    extends State<SettingsPage> {
  late final Box settingsBox;
  late final Box residentsBox;
  late final Box roomsBox;
  late final Box paymentsBox;

  final TextEditingController
      dormitoryNameController =
      TextEditingController();

  final TextEditingController
      monthlyRateController =
      TextEditingController();

  final TextEditingController
      billingDaysController =
      TextEditingController();

  final TextEditingController
      dueSoonDaysController =
      TextEditingController();

  final TextEditingController
      usernameController =
      TextEditingController();

  final TextEditingController
      currentPasswordController =
      TextEditingController();

  final TextEditingController
      newPasswordController =
      TextEditingController();

  final TextEditingController
      confirmPasswordController =
      TextEditingController();

  bool hideCurrentPassword = true;
  bool hideNewPassword = true;
  bool hideConfirmPassword = true;

  bool autoCloudSync = true;

  @override
  void initState() {
    super.initState();

    settingsBox = Hive.box(
      AppDatabase.settingsBoxName,
    );

    residentsBox = Hive.box(
      AppDatabase.residentsBoxName,
    );

    roomsBox = Hive.box(
      AppDatabase.roomsBoxName,
    );

    paymentsBox = Hive.box(
      AppDatabase.paymentsBoxName,
    );

    loadSettings();
  }

  // ============================================================
  // LOAD SETTINGS
  // ============================================================

  void loadSettings() {
    dormitoryNameController.text =
        settingsBox
            .get(
              'dormitoryName',
              defaultValue:
                  'Laila Dormitory',
            )
            .toString();

    monthlyRateController.text =
        settingsBox
            .get(
              'monthlyRate',
              defaultValue: 3500.0,
            )
            .toString();

    billingDaysController.text =
        settingsBox
            .get(
              'billingDays',
              defaultValue: 30,
            )
            .toString();

    dueSoonDaysController.text =
        settingsBox
            .get(
              'dueSoonDays',
              defaultValue: 3,
            )
            .toString();

    usernameController.text =
        settingsBox
            .get(
              'username',
              defaultValue: 'admin',
            )
            .toString();

    autoCloudSync =
        settingsBox.get(
              'autoCloudSync',
              defaultValue: true,
            ) ==
            true;
  }

  // ============================================================
  // MONEY INPUT
  // ============================================================

  TextInputFormatter get moneyFormatter {
    return TextInputFormatter.withFunction(
      (
        oldValue,
        newValue,
      ) {
        final RegExp valid =
            RegExp(
          r'^\d{0,8}(\.\d{0,2})?$',
        );

        if (valid.hasMatch(
          newValue.text,
        )) {
          return newValue;
        }

        return oldValue;
      },
    );
  }

  // ============================================================
  // SAVE DORMITORY SETTINGS
  // ============================================================

  Future<void>
      saveDormitorySettings() async {
    final String dormitoryName =
        dormitoryNameController.text
            .trim();

    final double? monthlyRate =
        double.tryParse(
      monthlyRateController.text
          .trim(),
    );

    final int? billingDays =
        int.tryParse(
      billingDaysController.text
          .trim(),
    );

    final int? dueSoonDays =
        int.tryParse(
      dueSoonDaysController.text
          .trim(),
    );

    if (dormitoryName.isEmpty) {
      showMessage(
        'Dormitory name cannot be empty.',
      );
      return;
    }

    if (monthlyRate == null ||
        monthlyRate <= 0) {
      showMessage(
        'Please enter a valid monthly rate.',
      );
      return;
    }

    if (billingDays == null ||
        billingDays <= 0) {
      showMessage(
        'Please enter a valid billing cycle.',
      );
      return;
    }

    if (dueSoonDays == null ||
        dueSoonDays < 0) {
      showMessage(
        'Please enter a valid due-soon warning.',
      );
      return;
    }

    await settingsBox.put(
      'dormitoryName',
      dormitoryName,
    );

    await settingsBox.put(
      'monthlyRate',
      monthlyRate,
    );

    await settingsBox.put(
      'billingDays',
      billingDays,
    );

    await settingsBox.put(
      'dueSoonDays',
      dueSoonDays,
    );

    showMessage(
      'Dormitory settings saved.',
    );

    if (autoCloudSync) {
      SyncService.instance.syncAll(
        silent: true,
      );
    }
  }

  // ============================================================
  // SAVE ADMIN ACCOUNT
  // ============================================================

  Future<void>
      saveAdminAccount() async {
    final String username =
        usernameController.text
            .trim();

    if (username.isEmpty) {
      showMessage(
        'Username cannot be empty.',
      );
      return;
    }

    final String newPassword =
        newPasswordController.text;

    final String confirmPassword =
        confirmPasswordController.text;

    // Username can be changed independently.
    await settingsBox.put(
      'username',
      username,
    );

    if (newPassword.isEmpty &&
        confirmPassword.isEmpty) {
      showMessage(
        'Administrator username updated.',
      );

      if (autoCloudSync) {
        SyncService.instance.syncAll(
          silent: true,
        );
      }

      return;
    }

    if (currentPasswordController
        .text
        .isEmpty) {
      showMessage(
        'Please enter your current password.',
      );
      return;
    }

    final String savedHash =
        settingsBox
            .get(
              'passwordHash',
            )
            .toString();

    final String enteredHash =
        AppDatabase.hashPassword(
      currentPasswordController.text,
    );

    if (savedHash != enteredHash) {
      showMessage(
        'Current password is incorrect.',
      );
      return;
    }

    if (newPassword.length < 6) {
      showMessage(
        'New password must contain at least 6 characters.',
      );
      return;
    }

    if (newPassword !=
        confirmPassword) {
      showMessage(
        'New passwords do not match.',
      );
      return;
    }

    await settingsBox.put(
      'passwordHash',
      AppDatabase.hashPassword(
        newPassword,
      ),
    );

    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();

    showMessage(
      'Administrator account updated.',
    );
  }

  // ============================================================
  // AUTO BACKUP
  // ============================================================

  Future<void> changeAutoBackup(
    bool value,
  ) async {
    setState(() {
      autoCloudSync = value;
    });

    await settingsBox.put(
      'autoCloudSync',
      value,
    );

    if (value) {
      await SyncService.instance
          .startAutoSync();

      showMessage(
        'Automatic backup enabled.',
      );
    } else {
      await SyncService.instance
          .stopAutoSync();

      showMessage(
        'Automatic backup disabled.',
      );
    }
  }

  // ============================================================
  // MANUAL SYNC
  // ============================================================

  Future<void> syncNow() async {
    if (SyncService.instance.syncing) {
      return;
    }

    final bool success =
        await SyncService.instance
            .syncAll();

    if (!mounted) return;

    if (success) {
      showMessage(
        'Backup completed successfully.',
      );
    } else {
      showMessage(
        SyncService.instance
                .errorMessage ??
            'Unable to complete the backup.',
      );
    }
  }

  // ============================================================
  // RESTORE CONFIRMATION
  // ============================================================

  Future<void>
      confirmRestoreBackup() async {
    if (SyncService.instance.syncing) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Restore Cloud Backup',
          ),

          content: const Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Cloud records will be downloaded to this device.',
              ),

              SizedBox(height: 12),

              Text(
                'Matching records will be updated instead of duplicated.',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              SizedBox(height: 12),

              Text(
                'This is useful when installing Laila Dormitory on a new phone.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              icon: const Icon(
                Icons.cloud_download_outlined,
              ),
              label: const Text(
                'Restore',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final bool success =
        await SyncService.instance
            .restoreCloudBackup();

    if (!mounted) return;

    if (success) {
      showMessage(
        'Cloud backup restored successfully.',
      );
    } else {
      showMessage(
        SyncService.instance
                .errorMessage ??
            'Restore failed.',
      );
    }
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String formatDateTime(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Never';
    }

    int hour = date.hour;

    final String period =
        hour >= 12 ? 'PM' : 'AM';

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

    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year} • '
        '$hour:$minute $period';
  }

  // ============================================================
  // LAST BACKUP
  // ============================================================

  DateTime? getLastBackup() {
    final dynamic value =
        settingsBox.get(
      'lastCloudSyncAt',
    );

    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // ACTIVE ROOM COUNT
  // ============================================================

  int activeRoomCount() {
    int count = 0;

    for (final raw in roomsBox.values) {
      if (raw is Map &&
          raw['isActive'] != false) {
        count++;
      }
    }

    return count;
  }

  // ============================================================
  // BACKED UP PHOTOS
  // ============================================================

  int backedUpPhotoCount() {
    int count = 0;

    for (final raw
        in residentsBox.values) {
      if (raw is! Map) {
        continue;
      }

      final String url =
          raw['imageUrl']
                  ?.toString() ??
              '';

      if (url.isNotEmpty) {
        count++;
      }
    }

    return count;
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
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // SETTINGS CARD
  // ============================================================

  Widget settingsCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border: Border.all(
          color:
              const Color(
                  0xFFE4E7EC),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
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
                    10,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(
                          0xFF17617D),
                ),
              ),

              const SizedBox(width: 12),

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
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    if (subtitle !=
                        null) ...[
                      const SizedBox(
                          height: 2),

                      Text(
                        subtitle,
                        style:
                            const TextStyle(
                          color:
                              Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // CLOUD STATUS COLOR
  // ============================================================

  Color cloudStatusColor(
    SyncService service,
  ) {
    if (service.syncing) {
      return Colors.blue;
    }

    switch (service.state) {
      case SyncState.complete:
        return Colors.green;

      case SyncState.offline:
        return Colors.orange;

      case SyncState.error:
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // CLOUD STATUS LABEL
  // ============================================================

  String cloudStatusLabel(
    SyncService service,
  ) {
    if (service.syncing) {
      return 'Backup in Progress';
    }

    switch (service.state) {
      case SyncState.complete:
        return 'Backup Up to Date';

      case SyncState.offline:
        return 'Waiting for Internet';

      case SyncState.error:
        return 'Backup Needs Attention';

      default:
        return getLastBackup() ==
                null
            ? 'Not Backed Up Yet'
            : 'Ready';
    }
  }

  // ============================================================
  // BACKUP COUNT
  // ============================================================

  Widget backupCount({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: 195,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color:
            const Color(
                0xFFF8FAFB),
        borderRadius:
            BorderRadius.circular(
          11,
        ),
        border: Border.all(
          color:
              const Color(
                  0xFFE4E7EC),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
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
                  value,
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                Text(
                  label,
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 10,
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
  // BACKUP & SYNC
  // ============================================================

  Widget backupSection() {
    return AnimatedBuilder(
      animation:
          SyncService.instance,
      builder: (
        context,
        _,
      ) {
        final SyncService service =
            SyncService.instance;

        final Color statusColor =
            cloudStatusColor(
          service,
        );

        DateTime? lastBackup =
            getLastBackup();

        if (service.state ==
            SyncState.complete) {
          lastBackup =
              DateTime.tryParse(
            settingsBox
                    .get(
                      'lastCloudSyncAt',
                    )
                    ?.toString() ??
                '',
          );
        }

        return Column(
          children: [
            // ==================================================
            // CLOUD STATUS
            // ==================================================

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration:
                  BoxDecoration(
                color: statusColor
                    .withOpacity(
                  .06,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
                border: Border.all(
                  color: statusColor
                      .withOpacity(
                    .25,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                        BoxDecoration(
                      color: statusColor
                          .withOpacity(
                        .10,
                      ),
                      shape:
                          BoxShape.circle,
                    ),
                    child: service.syncing
                        ? Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                              11,
                            ),
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.5,
                              color:
                                  statusColor,
                            ),
                          )
                        : Icon(
                            service.state ==
                                    SyncState.complete
                                ? Icons
                                    .cloud_done_outlined
                                : service.state ==
                                        SyncState.offline
                                    ? Icons
                                        .cloud_off_outlined
                                    : Icons
                                        .cloud_outlined,
                            color:
                                statusColor,
                          ),
                  ),

                  const SizedBox(
                      width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          cloudStatusLabel(
                            service,
                          ),
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                statusColor,
                          ),
                        ),

                        const SizedBox(
                            height: 3),

                        Text(
                          service.syncing
                              ? service
                                  .statusText
                              : 'Last backup: ${formatDateTime(lastBackup)}',
                          style:
                              const TextStyle(
                            fontSize: 11,
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // SYNC PROGRESS
            // ==================================================

            if (service.syncing) ...[
              const SizedBox(
                  height: 16),

              LinearProgressIndicator(
                value:
                    service.progress,
                minHeight: 8,
                borderRadius:
                    BorderRadius
                        .circular(
                  10,
                ),
              ),

              const SizedBox(
                  height: 10),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      service.statusText,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ),

                  Text(
                    '${(service.progress * 100).round()}%',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                  height: 12),

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .all(
                  13,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.orange
                          .withOpacity(
                    .08,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Icon(
                      Icons
                          .warning_amber_outlined,
                      size: 20,
                      color:
                          Colors.orange,
                    ),

                    SizedBox(width: 9),

                    Expanded(
                      child: Text(
                        'Please do not close the app or turn off your phone while backup is in progress.',
                        style:
                            TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ==================================================
            // AUTO BACKUP SWITCH
            // ==================================================

            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 15,
                vertical: 10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                        0xFFF8FAFB),
                borderRadius:
                    BorderRadius
                        .circular(
                  10,
                ),
              ),
              child: SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,

                title:
                    const Text(
                  'Automatic Backup',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),

                subtitle:
                    const Text(
                  'Automatically back up changes whenever an internet connection is available.',
                  style:
                      TextStyle(
                    fontSize: 11,
                  ),
                ),

                value:
                    autoCloudSync,

                onChanged:
                    service.syncing
                        ? null
                        : changeAutoBackup,
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // LOCAL DATA SUMMARY
            // ==================================================

            Align(
              alignment:
                  Alignment.centerLeft,
              child:
                  const Text(
                'Stored Data',
                style:
                    TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            ValueListenableBuilder(
              valueListenable:
                  residentsBox
                      .listenable(),
              builder: (
                context,
                Box residents,
                _,
              ) {
                return ValueListenableBuilder(
                  valueListenable:
                      roomsBox
                          .listenable(),
                  builder: (
                    context,
                    Box rooms,
                    __,
                  ) {
                    return ValueListenableBuilder(
                      valueListenable:
                          paymentsBox
                              .listenable(),
                      builder: (
                        context,
                        Box payments,
                        ___,
                      ) {
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            backupCount(
                              icon: Icons
                                  .people_outline,
                              label:
                                  'Residents',
                              value:
                                  residents.length
                                      .toString(),
                            ),

                            backupCount(
                              icon: Icons
                                  .apartment_outlined,
                              label:
                                  'Rooms',
                              value:
                                  activeRoomCount()
                                      .toString(),
                            ),

                            backupCount(
                              icon: Icons
                                  .payments_outlined,
                              label:
                                  'Payments',
                              value:
                                  payments.length
                                      .toString(),
                            ),

                            backupCount(
                              icon: Icons
                                  .photo_outlined,
                              label:
                                  'Photos Backed Up',
                              value:
                                  backedUpPhotoCount()
                                      .toString(),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 22),

            // ==================================================
            // BUTTONS
            // ==================================================

            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final bool narrow =
                    constraints.maxWidth <
                        550;

                final Widget syncButton =
                    SizedBox(
                  height: 50,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        service.syncing
                            ? null
                            : syncNow,

                    icon:
                        service.syncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .sync,
                              ),

                    label:
                        Text(
                      service.syncing
                          ? 'Backing Up...'
                          : 'Sync Now',
                    ),
                  ),
                );

                final Widget restoreButton =
                    SizedBox(
                  height: 50,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        service.syncing
                            ? null
                            : confirmRestoreBackup,

                    icon:
                        const Icon(
                      Icons
                          .cloud_download_outlined,
                    ),

                    label:
                        const Text(
                      'Restore Cloud Backup',
                    ),
                  ),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      syncButton,

                      const SizedBox(
                          height: 10),

                      restoreButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child:
                          syncButton,
                    ),

                    const SizedBox(
                        width: 10),

                    Expanded(
                      child:
                          restoreButton,
                    ),
                  ],
                );
              },
            ),

            if (service.errorMessage !=
                null) ...[
              const SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.red
                          .withOpacity(
                    .06,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                child: Text(
                  service.errorMessage!,
                  style:
                      const TextStyle(
                    color:
                        Colors.red,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      color:
          const Color(
              0xFFF5F7FA),
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          22,
        ),
        child:
            Center(
          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 900,
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Text(
                  'System Settings',
                  style:
                      TextStyle(
                    fontSize: 27,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Manage dormitory, administrator and data backup settings.',
                  style:
                      TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 24),

                // ===============================================
                // DORMITORY
                // ===============================================

                settingsCard(
                  title:
                      'Dormitory Settings',

                  subtitle:
                      'Manage billing and dormitory information.',

                  icon:
                      Icons
                          .apartment_outlined,

                  child:
                      Column(
                    children: [
                      TextField(
                        controller:
                            dormitoryNameController,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Dormitory Name',
                        ),
                      ),

                      const SizedBox(
                          height: 14),

                      TextField(
                        controller:
                            monthlyRateController,

                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),

                        inputFormatters: [
                          moneyFormatter,
                        ],

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Monthly Payment',
                          prefixText:
                              '₱ ',
                          helperText:
                              'Amount equivalent to one billing cycle.',
                        ),
                      ),

                      const SizedBox(
                          height: 14),

                      TextField(
                        controller:
                            billingDaysController,

                        keyboardType:
                            TextInputType
                                .number,

                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly,
                        ],

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Billing Cycle',
                          suffixText:
                              ' days',
                        ),
                      ),

                      const SizedBox(
                          height: 14),

                      TextField(
                        controller:
                            dueSoonDaysController,

                        keyboardType:
                            TextInputType
                                .number,

                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly,
                        ],

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Due Soon Warning',
                          suffixText:
                              ' days',
                        ),
                      ),

                      const SizedBox(
                          height: 20),

                      SizedBox(
                        width:
                            double.infinity,
                        height: 50,
                        child:
                            ElevatedButton.icon(
                          onPressed:
                              saveDormitorySettings,

                          icon:
                              const Icon(
                            Icons
                                .save_outlined,
                          ),

                          label:
                              const Text(
                            'Save Dormitory Settings',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ===============================================
                // ADMINISTRATOR
                // ===============================================

                settingsCard(
                  title:
                      'Administrator Account',

                  subtitle:
                      'Manage local administrator login.',

                  icon:
                      Icons
                          .admin_panel_settings_outlined,

                  child:
                      Column(
                    children: [
                      TextField(
                        controller:
                            usernameController,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Username',
                        ),
                      ),

                      const SizedBox(
                          height: 14),

                      TextField(
                        controller:
                            currentPasswordController,

                        obscureText:
                            hideCurrentPassword,

                        decoration:
                            InputDecoration(
                          labelText:
                              'Current Password',

                          suffixIcon:
                              IconButton(
                            onPressed:
                                () {
                              setState(
                                () {
                                  hideCurrentPassword =
                                      !hideCurrentPassword;
                                },
                              );
                            },

                            icon:
                                Icon(
                              hideCurrentPassword
                                  ? Icons
                                      .visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                          height: 14),

                      TextField(
                        controller:
                            newPasswordController,

                        obscureText:
                            hideNewPassword,

                        decoration:
                            InputDecoration(
                          labelText:
                              'New Password',

                          suffixIcon:
                              IconButton(
                            onPressed:
                                () {
                              setState(
                                () {
                                  hideNewPassword =
                                      !hideNewPassword;
                                },
                              );
                            },

                            icon:
                                Icon(
                              hideNewPassword
                                  ? Icons
                                      .visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                          height: 14),

                      TextField(
                        controller:
                            confirmPasswordController,

                        obscureText:
                            hideConfirmPassword,

                        decoration:
                            InputDecoration(
                          labelText:
                              'Confirm New Password',

                          suffixIcon:
                              IconButton(
                            onPressed:
                                () {
                              setState(
                                () {
                                  hideConfirmPassword =
                                      !hideConfirmPassword;
                                },
                              );
                            },

                            icon:
                                Icon(
                              hideConfirmPassword
                                  ? Icons
                                      .visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                          height: 20),

                      SizedBox(
                        width:
                            double.infinity,
                        height: 50,

                        child:
                            ElevatedButton.icon(
                          onPressed:
                              saveAdminAccount,

                          icon:
                              const Icon(
                            Icons
                                .manage_accounts_outlined,
                          ),

                          label:
                              const Text(
                            'Update Administrator Account',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ===============================================
                // BACKUP & SYNC
                // ===============================================

                settingsCard(
                  title:
                      'Backup & Sync',

                  subtitle:
                      'Keep dormitory information safe and available when moving to another device.',

                  icon:
                      Icons
                          .cloud_done_outlined,

                  child:
                      backupSection(),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    dormitoryNameController.dispose();
    monthlyRateController.dispose();
    billingDaysController.dispose();
    dueSoonDaysController.dispose();

    usernameController.dispose();

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }
}