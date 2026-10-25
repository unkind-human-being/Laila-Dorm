import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../Cloud/cloudinary_service.dart';
import '../Database/app_database.dart';

enum SyncState {
  idle,
  checking,
  residents,
  pictures,
  rooms,
  payments,
  settings,
  restoring,
  complete,
  offline,
  error,
}

class SyncService extends ChangeNotifier {
  SyncService._();

  static final SyncService instance =
      SyncService._();

  final FirebaseFirestore firestore =
      FirebaseFirestore.instance;

  final Uuid uuid =
      const Uuid();

  StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;

  bool _syncing = false;

  bool get syncing =>
      _syncing;

  SyncState state =
      SyncState.idle;

  double progress = 0;

  String statusText =
      'Ready';

  String? errorMessage;

  // ============================================================
  // DATABASE BOXES
  // ============================================================

  Box get residentsBox =>
      Hive.box(
        AppDatabase.residentsBoxName,
      );

  Box get roomsBox =>
      Hive.box(
        AppDatabase.roomsBoxName,
      );

  Box get paymentsBox =>
      Hive.box(
        AppDatabase.paymentsBoxName,
      );

  Box get settingsBox =>
      Hive.box(
        AppDatabase.settingsBoxName,
      );

  // ============================================================
  // FIRESTORE -> HIVE SANITIZER
  //
  // Firestore returns Timestamp objects for server timestamps.
  // Hive cannot store Firebase Timestamp directly, so convert
  // all cloud-only objects into Hive-safe values first.
  // ============================================================

  dynamic sanitizeForHive(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value
          .toDate()
          .toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Map) {
      final Map<String, dynamic> result =
          {};

      value.forEach(
        (
          key,
          item,
        ) {
          result[key.toString()] =
              sanitizeForHive(
            item,
          );
        },
      );

      return result;
    }

    if (value is List) {
      return value
          .map(
            sanitizeForHive,
          )
          .toList();
    }

    if (value is String ||
        value is int ||
        value is double ||
        value is bool ||
        value is Uint8List) {
      return value;
    }

    // Fallback for unexpected Firestore-only objects.
    return value.toString();
  }

  Map<String, dynamic>
      sanitizeMapForHive(
    Map<String, dynamic> data,
  ) {
    final dynamic sanitized =
        sanitizeForHive(
      data,
    );

    final Map<String, dynamic> result =
        Map<String, dynamic>.from(
      sanitized as Map,
    );

    // These are cloud-only metadata fields and are not needed
    // in the local Hive database.
    result.remove(
      'cloudSyncedAt',
    );

    return result;
  }

  // ============================================================
  // UPDATE LOADING STATUS
  // ============================================================

  void updateStatus(
    SyncState newState,
    String text,
    double newProgress,
  ) {
    state = newState;

    statusText = text;

    progress =
        newProgress.clamp(
      0,
      1,
    );

    notifyListeners();
  }

  // ============================================================
  // CHECK INTERNET
  // ============================================================

  Future<bool> hasConnection() async {
    final results =
        await Connectivity()
            .checkConnectivity();

    return results.any(
      (result) =>
          result !=
          ConnectivityResult.none,
    );
  }

  // ============================================================
  // AUTO SYNC
  // ============================================================

  Future<void> startAutoSync() async {
    await _connectivitySubscription?.cancel();

    final bool autoSyncEnabled =
        settingsBox.get(
              'autoCloudSync',
              defaultValue: true,
            ) ==
            true;

    if (!autoSyncEnabled) {
      state = SyncState.idle;
      statusText = 'Automatic backup is turned off.';
      progress = 0;

      notifyListeners();
      return;
    }

    _connectivitySubscription =
        Connectivity()
            .onConnectivityChanged
            .listen(
      (
        List<ConnectivityResult> results,
      ) {
        final bool online =
            results.any(
          (result) =>
              result !=
              ConnectivityResult.none,
        );

        if (online && !_syncing) {
          syncAll(
            silent: true,
          );
        }
      },
    );

    // Run initial sync after the app is already open.
    if (!_syncing) {
      syncAll(
        silent: true,
      );
    }
  }

  // ============================================================
  // MAKE SURE RECORDS HAVE PERMANENT IDS
  // ============================================================

  Future<void> ensureSyncIds() async {
    // ==========================================================
    // RESIDENTS
    // ==========================================================

    for (final key
        in residentsBox.keys.toList()) {
      final dynamic raw =
          residentsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(
        raw,
      );

      bool changed = false;

      if (data['syncId'] == null ||
          data['syncId']
              .toString()
              .isEmpty) {
        data['syncId'] =
            uuid.v4();

        changed = true;
      }

      if (data['updatedAt'] == null) {
        data['updatedAt'] =
            DateTime.now()
                .toIso8601String();

        changed = true;
      }

      if (changed) {
        await residentsBox.put(
          key,
          data,
        );
      }
    }

    // ==========================================================
    // PAYMENTS
    // ==========================================================

    for (final key
        in paymentsBox.keys.toList()) {
      final dynamic raw =
          paymentsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(
        raw,
      );

      bool changed = false;

      if (data['syncId'] == null ||
          data['syncId']
              .toString()
              .isEmpty) {
        data['syncId'] =
            uuid.v4();

        changed = true;
      }

      if (data['updatedAt'] == null) {
        data['updatedAt'] =
            data['paidAt'] ??
                DateTime.now()
                    .toIso8601String();

        changed = true;
      }

      if (changed) {
        await paymentsBox.put(
          key,
          data,
        );
      }
    }
  }

  // ============================================================
  // MAIN SYNC
  // ============================================================

  Future<bool> syncAll({
    bool silent = false,
  }) async {
    if (_syncing) {
      return false;
    }

    _syncing = true;
    errorMessage = null;

    notifyListeners();

    try {
      updateStatus(
        SyncState.checking,
        'Checking internet connection...',
        .03,
      );

      if (!await hasConnection()) {
        throw Exception(
          'No internet connection.',
        );
      }

      await ensureSyncIds();

      // Test that Firestore itself is reachable.
      await firestore
          .collection(
            'sync_metadata',
          )
          .doc('main')
          .get(
            const GetOptions(
              source: Source.server,
            ),
          );

      // ========================================================
      // RESIDENTS + PICTURES
      // ========================================================

      updateStatus(
        SyncState.residents,
        'Syncing resident records...',
        .10,
      );

      await syncResidents();

      // ========================================================
      // ROOMS
      // ========================================================

      updateStatus(
        SyncState.rooms,
        'Syncing room information...',
        .60,
      );

      await syncRooms();

      // ========================================================
      // PAYMENTS
      // ========================================================

      updateStatus(
        SyncState.payments,
        'Syncing payment records...',
        .75,
      );

      await syncPayments();

      // ========================================================
      // SETTINGS
      // ========================================================

      updateStatus(
        SyncState.settings,
        'Syncing system settings...',
        .90,
      );

      await syncSettings();

      // ========================================================
      // CLOUD SYNC METADATA
      // ========================================================

      final DateTime now =
          DateTime.now();

      await firestore
          .collection(
            'sync_metadata',
          )
          .doc('main')
          .set(
        {
          'lastSyncAt':
              now.toIso8601String(),

          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      await settingsBox.put(
        'lastCloudSyncAt',
        now.toIso8601String(),
      );

      updateStatus(
        SyncState.complete,
        'Backup complete.',
        1,
      );

      _syncing = false;

      notifyListeners();

      return true;
    } catch (error) {
      _syncing = false;

      errorMessage =
          error.toString();

      state =
          SyncState.offline;

      progress = 0;

      statusText =
          'Backup paused. Your data is safe on this device.';

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // SYNC RESIDENTS
  // ============================================================

  Future<void> syncResidents() async {
    final cloudSnapshot =
        await firestore
            .collection(
              'residents',
            )
            .get(
              const GetOptions(
                source: Source.server,
              ),
            );

    final Map<String,
            Map<String, dynamic>>
        remoteResidents = {};

    for (final doc
        in cloudSnapshot.docs) {
      remoteResidents[doc.id] =
          sanitizeMapForHive(
        doc.data(),
      );
    }

    final Set<String> localIds =
        {};

    final List<dynamic> localKeys =
        residentsBox.keys.toList();

    int current = 0;

    for (final key in localKeys) {
      current++;

      final dynamic raw =
          residentsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      Map<String, dynamic> resident =
          Map<String, dynamic>.from(
        raw,
      );

      final String syncId =
          resident['syncId']
              .toString();

      localIds.add(syncId);

      final Map<String, dynamic>?
          remote =
          remoteResidents[
              syncId];

      final DateTime localUpdated =
          DateTime.tryParse(
                resident['updatedAt']
                        ?.toString() ??
                    '',
              ) ??
              DateTime(1970);

      final DateTime cloudUpdated =
          DateTime.tryParse(
                remote?['updatedAt']
                        ?.toString() ??
                    '',
              ) ??
              DateTime(1970);

      // ========================================================
      // CLOUD VERSION IS NEWER
      // ========================================================

      if (remote != null &&
          cloudUpdated.isAfter(
            localUpdated,
          )) {
        await applyRemoteResident(
          key,
          resident,
          remote,
        );

        continue;
      }

      // ========================================================
      // PICTURE BACKUP
      // ========================================================

      final dynamic picture =
          resident['picture'];

      if (picture is Uint8List) {
        updateStatus(
          SyncState.pictures,
          'Backing up resident pictures...',
          .15 +
              (.25 *
                  current /
                  (localKeys.isEmpty
                      ? 1
                      : localKeys.length)),
        );

        final upload =
            await CloudinaryService
                .uploadResidentPhoto(
          bytes:
              picture,

          residentId:
              syncId,

          oldImageHash:
              resident['imageHash']
                  ?.toString(),

          oldImageUrl:
              resident['imageUrl']
                  ?.toString(),

          oldPublicId:
              resident[
                      'imagePublicId']
                  ?.toString(),
        );

        if (upload.success) {
          resident['imageUrl'] =
              upload.imageUrl;

          resident['imagePublicId'] =
              upload.publicId;

          resident['imageHash'] =
              upload.imageHash;

          await residentsBox.put(
            key,
            resident,
          );
        }
      }

      // ========================================================
      // FIRESTORE UPSERT
      // ========================================================

      final Map<String, dynamic>
          cloudData =
          residentForCloud(
        resident,
      );

      await firestore
          .collection(
            'residents',
          )
          .doc(syncId)
          .set(
            cloudData,
            SetOptions(
              merge: true,
            ),
          );

      updateStatus(
        SyncState.residents,
        'Syncing residents '
        '$current/${localKeys.length}...',
        .20 +
            (.30 *
                current /
                (localKeys.isEmpty
                    ? 1
                    : localKeys.length)),
      );
    }

    // ==========================================================
    // CLOUD RECORDS THAT ARE NOT ON THIS PHONE
    // ==========================================================

    for (final entry
        in remoteResidents.entries) {
      if (localIds.contains(
        entry.key,
      )) {
        continue;
      }

      final Map<String, dynamic>
          remote =
          sanitizeMapForHive(
        entry.value,
      );

      remote['syncId'] =
          entry.key;

      final String? imageUrl =
          remote['imageUrl']
              ?.toString();

      if (imageUrl != null &&
          imageUrl.isNotEmpty) {
        final Uint8List? image =
            await CloudinaryService
                .downloadPicture(
          imageUrl,
        );

        if (image != null) {
          remote['picture'] =
              image;
        }
      }

      await residentsBox.add(
        remote,
      );
    }
  }

  // ============================================================
  // REMOVE LOCAL IMAGE BYTES BEFORE FIRESTORE
  // ============================================================

  Map<String, dynamic> residentForCloud(
    Map<String, dynamic> resident,
  ) {
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(
      resident,
    );

    // Do not store local image bytes in Firestore.
    data.remove(
      'picture',
    );

    data.remove(
      'lastSyncedAt',
    );

    // Older versions added this as a Firestore server timestamp.
    // We no longer need it because updatedAt is already stored
    // as an ISO string and is used for sync comparisons.
    data.remove(
      'cloudSyncedAt',
    );

    return data;
  }

  // ============================================================
  // APPLY CLOUD RESIDENT LOCALLY
  // ============================================================

  Future<void> applyRemoteResident(
    dynamic localKey,
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) async {
    Uint8List? picture;

    if (local['picture']
        is Uint8List) {
      picture =
          local['picture'];
    }

    final String? remoteHash =
        remote['imageHash']
            ?.toString();

    final String? localHash =
        local['imageHash']
            ?.toString();

    if (remoteHash != null &&
        remoteHash != localHash) {
      final String? imageUrl =
          remote['imageUrl']
              ?.toString();

      if (imageUrl != null &&
          imageUrl.isNotEmpty) {
        picture =
            await CloudinaryService
                .downloadPicture(
          imageUrl,
        );
      }
    }

    final Map<String, dynamic> data =
        sanitizeMapForHive(
      remote,
    );

    if (picture != null) {
      data['picture'] =
          picture;
    }

    await residentsBox.put(
      localKey,
      data,
    );
  }

  // ============================================================
  // ROOMS
  // ============================================================

  Future<void> syncRooms() async {
    final cloudSnapshot =
        await firestore
            .collection(
              'rooms',
            )
            .get(
              const GetOptions(
                source: Source.server,
              ),
            );

    final Set<int> cloudRoomNumbers =
        {};

    // Cloud -> local
    for (final doc
        in cloudSnapshot.docs) {
      final Map<String, dynamic> data =
          sanitizeMapForHive(
        doc.data(),
      );

      final int? roomNumber =
          data['roomNumber']
                  is int
              ? data['roomNumber']
              : int.tryParse(
                  data['roomNumber']
                          ?.toString() ??
                      '',
                );

      if (roomNumber == null) {
        continue;
      }

      cloudRoomNumbers.add(
        roomNumber,
      );

      if (!roomsBox.containsKey(
        roomNumber,
      )) {
        await roomsBox.put(
          roomNumber,
          data,
        );
      }
    }

    // Local -> cloud
    for (final key
        in roomsBox.keys) {
      final dynamic raw =
          roomsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      final Map<String, dynamic> room =
          Map<String, dynamic>.from(
        raw,
      );

      final int? roomNumber =
          room['roomNumber']
                  is int
              ? room['roomNumber']
              : int.tryParse(
                  room['roomNumber']
                          ?.toString() ??
                      '',
                );

      if (roomNumber == null) {
        continue;
      }

      await firestore
          .collection(
            'rooms',
          )
          .doc(
            'room_${roomNumber.toString().padLeft(3, '0')}',
          )
          .set(
            room,
            SetOptions(
              merge: true,
            ),
          );
    }
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Future<void> syncPayments() async {
    final cloudSnapshot =
        await firestore
            .collection(
              'payments',
            )
            .get(
              const GetOptions(
                source: Source.server,
              ),
            );

    final Map<String,
            Map<String, dynamic>>
        cloudPayments = {};

    for (final doc
        in cloudSnapshot.docs) {
      cloudPayments[
              doc.id] =
          sanitizeMapForHive(
        doc.data(),
      );
    }

    final Set<String> localIds =
        {};

    // ==========================================================
    // LOCAL -> CLOUD
    // ==========================================================

    for (final key
        in paymentsBox.keys.toList()) {
      final dynamic raw =
          paymentsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(
        raw,
      );

      final String syncId =
          data['syncId']
              .toString();

      localIds.add(
        syncId,
      );

      await firestore
          .collection(
            'payments',
          )
          .doc(
            syncId,
          )
          .set(
            data,
            SetOptions(
              merge: true,
            ),
          );
    }

    // ==========================================================
    // CLOUD -> LOCAL
    // ==========================================================

    for (final entry
        in cloudPayments.entries) {
      if (localIds.contains(
        entry.key,
      )) {
        continue;
      }

      final Map<String, dynamic> data =
          sanitizeMapForHive(
        entry.value,
      );

      data['syncId'] =
          entry.key;

      await paymentsBox.add(
        data,
      );
    }
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  Future<void> syncSettings() async {
    final Map<String, dynamic> data = {
      'username':
          settingsBox.get(
        'username',
        defaultValue:
            'admin',
      ),

      'dormitoryName':
          settingsBox.get(
        'dormitoryName',
        defaultValue:
            'Laila Dormitory',
      ),

      'monthlyRate':
          settingsBox.get(
        'monthlyRate',
        defaultValue:
            3500.0,
      ),

      'billingDays':
          settingsBox.get(
        'billingDays',
        defaultValue:
            30,
      ),

      'dueSoonDays':
          settingsBox.get(
        'dueSoonDays',
        defaultValue:
            3,
      ),

      'updatedAt':
          DateTime.now()
              .toIso8601String(),
    };

    await firestore
        .collection(
          'settings',
        )
        .doc(
          'app',
        )
        .set(
          data,
          SetOptions(
            merge: true,
          ),
        );
  }

  // ============================================================
  // RESTORE CLOUD BACKUP
  // ============================================================

  Future<bool> restoreCloudBackup() async {
    if (_syncing) {
      return false;
    }

    _syncing = true;

    errorMessage = null;

    notifyListeners();

    try {
      updateStatus(
        SyncState.restoring,
        'Restoring cloud backup...',
        .05,
      );

      if (!await hasConnection()) {
        throw Exception(
          'No internet connection.',
        );
      }

      await restoreResidents();

      updateStatus(
        SyncState.restoring,
        'Restoring rooms...',
        .60,
      );

      await restoreRooms();

      updateStatus(
        SyncState.restoring,
        'Restoring payments...',
        .75,
      );

      await restorePayments();

      updateStatus(
        SyncState.restoring,
        'Restoring settings...',
        .90,
      );

      await restoreSettings();

      await ensureSyncIds();

      final DateTime now =
          DateTime.now();

      await settingsBox.put(
        'lastCloudSyncAt',
        now.toIso8601String(),
      );

      updateStatus(
        SyncState.complete,
        'Cloud backup restored.',
        1,
      );

      _syncing = false;

      notifyListeners();

      return true;
    } catch (error) {
      _syncing = false;

      state =
          SyncState.error;

      progress = 0;

      errorMessage =
          error.toString();

      statusText =
          'Restore failed.';

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // RESTORE RESIDENTS
  // ============================================================

  Future<void> restoreResidents() async {
    final snapshot =
        await firestore
            .collection(
              'residents',
            )
            .get(
              const GetOptions(
                source: Source.server,
              ),
            );

    final Map<String, dynamic>
        localBySyncId = {};

    for (final key
        in residentsBox.keys) {
      final dynamic raw =
          residentsBox.get(key);

      if (raw is Map &&
          raw['syncId'] != null) {
        localBySyncId[
                raw['syncId']
                    .toString()] =
            key;
      }
    }

    int current = 0;

    for (final doc
        in snapshot.docs) {
      current++;

      final Map<String, dynamic> data =
          sanitizeMapForHive(
        doc.data(),
      );

      data['syncId'] =
          doc.id;

      final String? imageUrl =
          data['imageUrl']
              ?.toString();

      if (imageUrl != null &&
          imageUrl.isNotEmpty) {
        final Uint8List? bytes =
            await CloudinaryService
                .downloadPicture(
          imageUrl,
        );

        if (bytes != null) {
          data['picture'] =
              bytes;
        }
      }

      final dynamic localKey =
          localBySyncId[
              doc.id];

      if (localKey == null) {
        await residentsBox.add(
          data,
        );
      } else {
        await residentsBox.put(
          localKey,
          data,
        );
      }

      updateStatus(
        SyncState.restoring,
        'Restoring residents '
        '$current/${snapshot.docs.length}...',
        .10 +
            (.45 *
                current /
                (snapshot.docs.isEmpty
                    ? 1
                    : snapshot.docs.length)),
      );
    }
  }

  // ============================================================
  // RESTORE ROOMS
  // ============================================================

  Future<void> restoreRooms() async {
    final snapshot =
        await firestore
            .collection(
              'rooms',
            )
            .get(
              const GetOptions(
                source: Source.server,
              ),
            );

    for (final doc
        in snapshot.docs) {
      final Map<String, dynamic> data =
          sanitizeMapForHive(
        doc.data(),
      );

      final int? roomNumber =
          data['roomNumber']
                  is int
              ? data['roomNumber']
              : int.tryParse(
                  data['roomNumber']
                          ?.toString() ??
                      '',
                );

      if (roomNumber != null) {
        await roomsBox.put(
          roomNumber,
          data,
        );
      }
    }
  }

  // ============================================================
  // RESTORE PAYMENTS
  // ============================================================

  Future<void> restorePayments() async {
    final snapshot =
        await firestore
            .collection(
              'payments',
            )
            .get(
              const GetOptions(
                source: Source.server,
              ),
            );

    final Map<String, dynamic>
        localBySyncId = {};

    for (final key
        in paymentsBox.keys) {
      final dynamic raw =
          paymentsBox.get(key);

      if (raw is Map &&
          raw['syncId'] != null) {
        localBySyncId[
                raw['syncId']
                    .toString()] =
            key;
      }
    }

    for (final doc
        in snapshot.docs) {
      final Map<String, dynamic> data =
          sanitizeMapForHive(
        doc.data(),
      );

      data['syncId'] =
          doc.id;

      final dynamic localKey =
          localBySyncId[
              doc.id];

      if (localKey == null) {
        await paymentsBox.add(
          data,
        );
      } else {
        await paymentsBox.put(
          localKey,
          data,
        );
      }
    }
  }

  // ============================================================
  // RESTORE SETTINGS
  // ============================================================

  Future<void> restoreSettings() async {
    final snapshot =
        await firestore
            .collection(
              'settings',
            )
            .doc('app')
            .get(
              const GetOptions(
                source: Source.server,
              ),
            );

    if (!snapshot.exists ||
        snapshot.data() == null) {
      return;
    }

    final Map<String, dynamic> data =
        sanitizeMapForHive(
      snapshot.data()!,
    );

    const List<String> allowedKeys = [
      'username',
      'dormitoryName',
      'monthlyRate',
      'billingDays',
      'dueSoonDays',
    ];

    for (final key
        in allowedKeys) {
      if (data.containsKey(
        key,
      )) {
        await settingsBox.put(
          key,
          data[key],
        );
      }
    }
  }

  // ============================================================
  // STOP AUTO SYNC
  // ============================================================

  Future<void> stopAutoSync() async {
    await _connectivitySubscription
        ?.cancel();

    _connectivitySubscription =
        null;
  }
}