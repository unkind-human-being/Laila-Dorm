import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../Database/app_database.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  late final Box roomsBox;
  late final Box residentsBox;

  final TextEditingController searchController = TextEditingController();

  String searchText = '';
  RoomFilter selectedFilter = RoomFilter.all;

  @override
  void initState() {
    super.initState();

    roomsBox = Hive.box(
      AppDatabase.roomsBoxName,
    );

    residentsBox = Hive.box(
      AppDatabase.residentsBoxName,
    );
  }

  // ============================================================
  // ACTIVE RESIDENTS IN ROOM
  // ============================================================

  List<Map<String, dynamic>> residentsInRoom(
    int roomNumber,
  ) {
    final List<Map<String, dynamic>> result = [];

    for (final key in residentsBox.keys) {
      final dynamic raw = residentsBox.get(key);

      if (raw == null || raw is! Map) {
        continue;
      }

      final Map<String, dynamic> resident =
          Map<String, dynamic>.from(raw);

      final String status =
          resident['status']?.toString().toLowerCase() ?? 'active';

      if (status != 'active') {
        continue;
      }

      final int? residentRoom = resident['roomNumber'] is int
          ? resident['roomNumber'] as int
          : int.tryParse(
              resident['roomNumber']?.toString() ?? '',
            );

      if (residentRoom == roomNumber) {
        result.add({
          'residentKey': key,
          ...resident,
        });
      }
    }

    return result;
  }


  void showResidentPicture({
    required Uint8List picture,
    required String residentName,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(15),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: 700,
                  maxHeight:
                      MediaQuery.of(context)
                              .size
                              .height *
                          .85,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      picture,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                      );
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 15,
                bottom: 15,
                right: 15,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: Text(
                    residentName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // RESIDENT BY BED
  // ============================================================

  Map<String, dynamic>? residentInBed({
    required int roomNumber,
    required String bedType,
  }) {
    final List<Map<String, dynamic>> residents =
        residentsInRoom(roomNumber);

    for (final resident in residents) {
      final String bed =
          resident['bedType']?.toString().toLowerCase() ?? '';

      if (bed == bedType.toLowerCase()) {
        return resident;
      }
    }

    return null;
  }

  // ============================================================
  // ROOM STATUS
  // ============================================================

  int occupiedBedCount(
    int roomNumber,
  ) {
    return residentsInRoom(roomNumber).length;
  }

  bool roomIsVacant(
    int roomNumber,
  ) {
    return occupiedBedCount(roomNumber) == 0;
  }

  bool roomIsOccupied(
    int roomNumber,
  ) {
    return occupiedBedCount(roomNumber) > 0;
  }

  bool roomIsFull(
    int roomNumber,
  ) {
    return occupiedBedCount(roomNumber) >= 2;
  }

  // ============================================================
  // ROOM NUMBERS
  // ============================================================

  List<int> allRoomNumbers() {
    final List<int> rooms = [];

    for (final key in roomsBox.keys) {
      final dynamic raw = roomsBox.get(key);

      if (raw == null || raw is! Map) {
        continue;
      }

      final Map<dynamic, dynamic> room =
          Map<dynamic, dynamic>.from(raw);

      if (room['isActive'] == false) {
        continue;
      }

      final int? roomNumber = room['roomNumber'] is int
          ? room['roomNumber'] as int
          : int.tryParse(
              room['roomNumber']?.toString() ?? '',
            );

      if (roomNumber != null) {
        rooms.add(roomNumber);
      }
    }

    rooms.sort();

    return rooms;
  }

  // ============================================================
  // FILTER / SEARCH
  // ============================================================

  List<int> filteredRooms() {
    final List<int> rooms = allRoomNumbers();

    final String query = searchText.trim().toLowerCase();

    // Search overrides the current room filter so searching a
    // resident always finds the room.
    if (query.isNotEmpty) {
      final Set<int> result = {};

      // Search room number.
      for (final room in rooms) {
        final String normal = room.toString();
        final String padded = room.toString().padLeft(3, '0');
        final String roomNormal = 'room $normal';
        final String roomPadded = 'room $padded';

        if (normal == query ||
            padded == query ||
            roomNormal.contains(query) ||
            roomPadded.contains(query)) {
          result.add(room);
        }
      }

      // Search active resident name.
      for (final key in residentsBox.keys) {
        final dynamic raw = residentsBox.get(key);

        if (raw == null || raw is! Map) {
          continue;
        }

        final Map<dynamic, dynamic> resident =
            Map<dynamic, dynamic>.from(raw);

        final String status =
            resident['status']?.toString().toLowerCase() ?? 'active';

        if (status != 'active') {
          continue;
        }

        final String firstName =
            '${resident['firstName'] ?? ''}'.toLowerCase();

        final String lastName =
            '${resident['lastName'] ?? ''}'.toLowerCase();

        final String fullName = '$firstName $lastName';
        final String reverseName = '$lastName $firstName';

        if (firstName.contains(query) ||
            lastName.contains(query) ||
            fullName.contains(query) ||
            reverseName.contains(query)) {
          final int? room = resident['roomNumber'] is int
              ? resident['roomNumber'] as int
              : int.tryParse(
                  resident['roomNumber']?.toString() ?? '',
                );

          if (room != null && rooms.contains(room)) {
            result.add(room);
          }
        }
      }

      final List<int> sorted = result.toList()..sort();

      return sorted;
    }

    switch (selectedFilter) {
      case RoomFilter.vacant:
        return rooms.where(roomIsVacant).toList();

      case RoomFilter.occupied:
        return rooms.where(roomIsOccupied).toList();

      case RoomFilter.all:
        return rooms;
    }
  }

  // ============================================================
  // ADD ROOM
  // ============================================================

  Future<void> addRoom() async {
    final List<int> rooms = allRoomNumbers();

    final int newRoomNumber =
        rooms.isEmpty ? 1 : rooms.last + 1;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add New Room',
          ),
          content: Text(
            'Create Room ${newRoomNumber.toString().padLeft(3, '0')}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
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
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.add,
              ),
              label: const Text(
                'Add Room',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final DateTime now = DateTime.now();

    await roomsBox.put(
      newRoomNumber,
      {
        'roomNumber': newRoomNumber,
        'isActive': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Room ${newRoomNumber.toString().padLeft(3, '0')} added successfully.',
        ),
      ),
    );
  }

  // ============================================================
  // DEACTIVATE RESIDENT
  // ============================================================

  Future<void> deactivateResident(
    Map<String, dynamic> resident,
  ) async {
    final TextEditingController reasonController =
        TextEditingController();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Deactivate Resident',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Deactivate ${resident['firstName'] ?? ''} '
                  '${resident['lastName'] ?? ''}?',
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text(
                  'The resident will NOT be deleted. Their history will remain '
                  'in the system and the assigned bed will become available.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText: 'Reason',
                    hintText:
                        'Example: Moved out / Did not renew',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Deactivate',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      reasonController.dispose();
      return;
    }

    final dynamic key =
        resident['residentKey'];

    final dynamic raw =
        residentsBox.get(key);

    if (raw == null || raw is! Map) {
      reasonController.dispose();
      return;
    }

    final Map<String, dynamic> updated =
        Map<String, dynamic>.from(raw);

    final DateTime now = DateTime.now();

    // Preserve the previous assignment.
    updated['lastRoomNumber'] =
        updated['roomNumber'];

    updated['lastBedType'] =
        updated['bedType'];

    final List<Map<String, dynamic>>
        history = [];

    final dynamic oldHistory =
        updated['statusHistory'];

    if (oldHistory is List) {
      for (final item in oldHistory) {
        if (item is Map) {
          history.add(
            Map<String, dynamic>.from(
              item,
            ),
          );
        }
      }
    }

    final String reason =
        reasonController.text.trim().isEmpty
            ? 'No reason provided'
            : reasonController.text.trim();

    history.add({
      'type': 'deactivated',
      'at': now.toIso8601String(),
      'roomNumber': updated['roomNumber'],
      'bedType': updated['bedType'],
      'reason': reason,
    });

    updated['statusHistory'] = history;
    updated['status'] = 'inactive';
    updated['deactivatedAt'] =
        now.toIso8601String();
    updated['deactivationReason'] =
        reason;

    // Release the current room and bed.
    updated['roomNumber'] = null;
    updated['bedType'] = null;
    updated['updatedAt'] =
        now.toIso8601String();

    await residentsBox.put(
      key,
      updated,
    );

    reasonController.dispose();

    if (!mounted) {
      return;
    }

    // Close the Room Details dialog.
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Resident deactivated. Their record has been preserved.',
        ),
      ),
    );
  }

  // ============================================================
  // ROOM DETAILS
  // ============================================================

  Future<void> openRoomDetails(
    int roomNumber,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return ValueListenableBuilder(
          valueListenable:
              residentsBox.listenable(),
          builder: (
            context,
            Box residents,
            _,
          ) {
            final Map<String, dynamic>?
                upperResident =
                residentInBed(
              roomNumber: roomNumber,
              bedType: 'upper',
            );

            final Map<String, dynamic>?
                lowerResident =
                residentInBed(
              roomNumber: roomNumber,
              bedType: 'lower',
            );

            final Size screen =
                MediaQuery.of(context).size;

            final bool wide =
                screen.width >= 760;

            return Dialog(
              insetPadding:
                  const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(
                  maxWidth: 950,
                  maxHeight:
                      screen.height * .90,
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding:
                          const EdgeInsets.all(
                        18,
                      ),
                      decoration:
                          const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(
                              0xFFE4E7EC,
                            ),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFFE9F2F6,
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
                                  .meeting_room_outlined,
                              size: 27,
                              color: Color(
                                0xFF17617D,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Room ${roomNumber.toString().padLeft(3, '0')}',
                                  style:
                                      const TextStyle(
                                    fontSize: 21,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 2,
                                ),
                                Text(
                                  roomIsVacant(
                                    roomNumber,
                                  )
                                      ? 'Vacant Room'
                                      : roomIsFull(
                                              roomNumber,
                                            )
                                          ? 'Fully Occupied'
                                          : '1 Bed Available',
                                  style: TextStyle(
                                    color:
                                        roomIsFull(
                                      roomNumber,
                                    )
                                            ? Colors
                                                .orange
                                            : Colors
                                                .green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
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

                    // Bed details
                    Expanded(
                      child:
                          SingleChildScrollView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        child: wide
                            ? Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Expanded(
                                    child:
                                        bedDetailsCard(
                                      roomNumber:
                                          roomNumber,
                                      bedType:
                                          'upper',
                                      resident:
                                          upperResident,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child:
                                        bedDetailsCard(
                                      roomNumber:
                                          roomNumber,
                                      bedType:
                                          'lower',
                                      resident:
                                          lowerResident,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  bedDetailsCard(
                                    roomNumber:
                                        roomNumber,
                                    bedType:
                                        'upper',
                                    resident:
                                        upperResident,
                                  ),
                                  const SizedBox(
                                    height: 14,
                                  ),
                                  bedDetailsCard(
                                    roomNumber:
                                        roomNumber,
                                    bedType:
                                        'lower',
                                    resident:
                                        lowerResident,
                                  ),
                                ],
                              ),
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
  }

  // ============================================================
  // BED DETAILS CARD
  // ============================================================

  Widget bedDetailsCard({
    required int roomNumber,
    required String bedType,
    required Map<String, dynamic>?
        resident,
  }) {
    final bool upper =
        bedType == 'upper';

    if (resident == null) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              const Color(0xFFF9FAFB),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color:
                const Color(0xFFE4E7EC),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  upper
                      ? Icons
                          .keyboard_double_arrow_up
                      : Icons
                          .keyboard_double_arrow_down,
                  color: Colors.green,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  upper
                      ? 'Upper Deck'
                      : 'Lower Deck',
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 28,
            ),
            const Icon(
              Icons.bed_outlined,
              size: 55,
              color: Colors.green,
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'VACANT',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            const Text(
              'No resident is currently assigned to this bed.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
          ],
        ),
      );
    }

    final dynamic picture =
        resident['picture'];

    final String firstName =
        resident['firstName']
                ?.toString() ??
            '';

    final String lastName =
        resident['lastName']
                ?.toString() ??
            '';

    final String middle =
        resident['middleInitial']
                ?.toString() ??
            '';

    final String type =
        resident['residentType']
                ?.toString() ??
            'regular';

    final String address =
        resident['permanentAddress']
                ?.toString() ??
            '';

    final String contact =
        resident['contactNumber']
                ?.toString() ??
            '';

    final String emergency =
        resident['emergencyNumber']
                ?.toString() ??
            '';

    final DateTime? paidUntil =
        DateTime.tryParse(
      resident['paidUntil']
              ?.toString() ??
          '',
    );

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFD0D5DD),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                upper
                    ? Icons
                        .keyboard_double_arrow_up
                    : Icons
                        .keyboard_double_arrow_down,
                color:
                    const Color(
                  0xFF17617D,
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Text(
                upper
                    ? 'Upper Deck'
                    : 'Lower Deck',
                style:
                    const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.orange
                      .withValues(
                    alpha: .10,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),
                ),
                child: const Text(
                  'OCCUPIED',
                  style: TextStyle(
                    color:
                        Colors.orange,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 18,
          ),
          GestureDetector(
            onTap: picture is Uint8List
                ? () {
                    showResidentPicture(
                      picture: picture,
                      residentName:
                          '$lastName, $firstName'
                          '${middle.isEmpty ? '' : ' $middle.'}',
                    );
                  }
                : null,

            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor:
                      const Color(
                    0xFFE9F2F6,
                  ),
                  backgroundImage:
                      picture is Uint8List
                          ? MemoryImage(
                              picture,
                            )
                          : null,
                  child: picture is Uint8List
                      ? null
                      : const Icon(
                          Icons.person_outline,
                          size: 45,
                        ),
                ),

                if (picture is Uint8List)
                  Container(
                    width: 29,
                    height: 29,
                    decoration:
                        const BoxDecoration(
                      color:
                          Color(0xFF17617D),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Center(
            child: Text(
              '$lastName, $firstName'
              '${middle.isEmpty ? '' : ' $middle.'}',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Center(
            child: Text(
              type == 'student'
                  ? 'Student Resident'
                  : 'Regular Resident',
              style:
                  const TextStyle(
                color: Color(
                  0xFF17617D,
                ),
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(
            height: 18,
          ),
          residentDetail(
            icon: Icons.home_outlined,
            title: 'Permanent Address',
            value: address,
          ),
          residentDetail(
            icon: Icons.phone_outlined,
            title: 'Contact Number',
            value: contact,
          ),
          residentDetail(
            icon: Icons
                .contact_emergency_outlined,
            title: 'Emergency Number',
            value: emergency,
          ),
          residentDetail(
            icon: Icons
                .event_available_outlined,
            title: 'Paid Until',
            value: paidUntil == null
                ? 'No payment date'
                : '${paidUntil.month.toString().padLeft(2, '0')}/'
                    '${paidUntil.day.toString().padLeft(2, '0')}/'
                    '${paidUntil.year}',
          ),
          const SizedBox(
            height: 12,
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                deactivateResident(
                  resident,
                );
              },
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.red,
              ),
              icon: const Icon(
                Icons
                    .person_off_outlined,
              ),
              label: const Text(
                'Deactivate Resident',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget residentDetail({
    required IconData icon,
    required String title,
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
              0xFF17617D,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
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
  // ROOM CARD
  // ============================================================

  Widget roomCard(
    int roomNumber,
  ) {
    final int occupied =
        occupiedBedCount(roomNumber);

    final bool full =
        occupied >= 2;

    final bool vacant =
        occupied == 0;

    final String status = vacant
        ? 'Vacant'
        : full
            ? 'Fully Occupied'
            : '1 Bed Available';

    final Color accent = vacant
        ? Colors.green
        : full
            ? Colors.orange
            : const Color(
                0xFF17617D,
              );

    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(14),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(14),
        onTap: () {
          openRoomDetails(
            roomNumber,
          );
        },
        child: Container(
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(
                alpha: .45,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color:
                          accent.withValues(
                        alpha: .08,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .meeting_room_outlined,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$occupied / 2',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 12,
              ),
              Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  'Room ${roomNumber.toString().padLeft(3, '0')}',
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                children: [
                  bedIndicator(
                    roomNumber:
                        roomNumber,
                    bedType: 'upper',
                    label: 'Upper',
                  ),
                  const SizedBox(
                    width: 7,
                  ),
                  bedIndicator(
                    roomNumber:
                        roomNumber,
                    bedType: 'lower',
                    label: 'Lower',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BED INDICATOR
  // ============================================================

  Widget bedIndicator({
    required int roomNumber,
    required String bedType,
    required String label,
  }) {
    final bool occupied =
        residentInBed(
              roomNumber: roomNumber,
              bedType: bedType,
            ) !=
            null;

    final Color accent = occupied
        ? Colors.orange
        : Colors.green;

    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(
            alpha: .08,
          ),
          borderRadius:
              BorderRadius.circular(6),
        ),
        child: Text(
          '$label: ${occupied ? 'Used' : 'Free'}',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          textAlign:
              TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            color: accent,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ROOM FILTER BUTTON
  // ============================================================

  Widget roomFilterButton({
    required String title,
    required int count,
    required RoomFilter filter,
    required IconData icon,
  }) {
    final bool selected =
        selectedFilter == filter;

    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          selectedFilter = filter;
        });
      },
      icon: Icon(
        icon,
        size: 18,
      ),
      label: Text(
        '$title ($count)',
      ),
      style:
          OutlinedButton.styleFrom(
        backgroundColor: selected
            ? const Color(
                0xFFE4F0F4,
              )
            : Colors.white,
        foregroundColor:
            const Color(
          0xFF17617D,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        visualDensity:
            VisualDensity.compact,
        side: BorderSide(
          color: selected
              ? const Color(
                  0xFF17617D,
                )
              : Colors.grey,
        ),
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
          roomsBox.listenable(),
      builder: (
        context,
        Box roomBox,
        _,
      ) {
        return ValueListenableBuilder(
          valueListenable:
              residentsBox.listenable(),
          builder: (
            context,
            Box residentBox,
            __,
          ) {
            // IMPORTANT:
            // filteredRooms() returns List<int>, not List<Map>.
            final List<int> rooms =
                filteredRooms();

            final List<int>
                roomNumbers =
                allRoomNumbers();

            int occupiedRooms = 0;
            int vacantRooms = 0;

            for (final roomNumber
                in roomNumbers) {
              if (roomIsOccupied(
                roomNumber,
              )) {
                occupiedRooms++;
              } else {
                vacantRooms++;
              }
            }

            return LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final double width =
                    constraints.maxWidth;

                final bool landscape =
                    MediaQuery.of(context)
                            .orientation ==
                        Orientation
                            .landscape;

                // ===============================================
                // RESPONSIVE GRID
                // ===============================================

                int columns;

                if (width >= 1400) {
                  columns = 5;
                } else if (width >=
                    1100) {
                  columns = 4;
                } else if (width >=
                    760) {
                  columns = 3;
                } else if (width >=
                    420) {
                  columns = 2;
                } else {
                  columns = 1;
                }

                double cardRatio;

                if (columns == 1) {
                  cardRatio = 1.55;
                } else if (columns ==
                    2) {
                  cardRatio = 1.00;
                } else {
                  cardRatio =
                      landscape
                          ? 1.35
                          : 1.20;
                }

                // ===============================================
                // SEARCH
                // ===============================================

                final Widget searchField =
                    TextField(
                  controller:
                      searchController,
                  onChanged: (value) {
                    setState(() {
                      searchText = value
                          .trim()
                          .toLowerCase();
                    });
                  },
                  decoration:
                      const InputDecoration(
                    hintText:
                        'Search name or room...',
                    prefixIcon:
                        Icon(
                      Icons.search,
                    ),
                  ),
                );

                final Widget addButton =
                    ElevatedButton.icon(
                  onPressed:
                      addRoom,
                  icon:
                      const Icon(
                    Icons.add,
                  ),
                  label:
                      const Text(
                    'Add Room',
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    minimumSize:
                        const Size(
                      150,
                      52,
                    ),
                  ),
                );

                final bool stackSearch =
                    width < 650;

                final Widget
                    searchSection =
                    Container(
                  padding:
                      EdgeInsets.all(
                    landscape
                        ? 10
                        : 14,
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
                        0xFFE4E7EC,
                      ),
                    ),
                  ),
                  child: stackSearch
                      ? Column(
                          children: [
                            searchField,
                            const SizedBox(
                              height: 10,
                            ),
                            SizedBox(
                              width:
                                  double.infinity,
                              child:
                                  addButton,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child:
                                  searchField,
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            addButton,
                          ],
                        ),
                );

                // ===============================================
                // FILTERS
                // ===============================================

                final Widget
                    filterSection =
                    Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 10,
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
                        0xFFE4E7EC,
                      ),
                    ),
                  ),
                  child:
                      SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal,
                    physics:
                        const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        roomFilterButton(
                          title:
                              'All Rooms',
                          count:
                              roomNumbers
                                  .length,
                          filter:
                              RoomFilter.all,
                          icon:
                              Icons
                                  .apartment_outlined,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        roomFilterButton(
                          title:
                              'Room Vacant',
                          count:
                              vacantRooms,
                          filter:
                              RoomFilter
                                  .vacant,
                          icon:
                              Icons
                                  .door_front_door_outlined,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        roomFilterButton(
                          title:
                              'Room Occupied',
                          count:
                              occupiedRooms,
                          filter:
                              RoomFilter
                                  .occupied,
                          icon:
                              Icons
                                  .meeting_room_outlined,
                        ),
                      ],
                    ),
                  ),
                );

                // ===============================================
                // ONE SCROLLABLE PAGE
                // ===============================================

                return Container(
                  color:
                      const Color(
                    0xFFF5F7FA,
                  ),
                  child:
                      CustomScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding:
                            EdgeInsets
                                .fromLTRB(
                          landscape
                              ? 10
                              : 14,
                          landscape
                              ? 8
                              : 14,
                          landscape
                              ? 10
                              : 14,
                          0,
                        ),
                        sliver:
                            SliverToBoxAdapter(
                          child:
                              searchSection,
                        ),
                      ),
                      SliverPadding(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          14,
                          12,
                          14,
                          0,
                        ),
                        sliver:
                            SliverToBoxAdapter(
                          child:
                              filterSection,
                        ),
                      ),
                      SliverPadding(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          16,
                          18,
                          16,
                          10,
                        ),
                        sliver:
                            SliverToBoxAdapter(
                          child: Row(
                            children: [
                              const Expanded(
                                child:
                                    Text(
                                  'Rooms',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        22,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                              Text(
                                '${rooms.length} result'
                                '${rooms.length == 1 ? '' : 's'}',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (rooms.isEmpty)
                        const SliverToBoxAdapter(
                          child:
                              SizedBox(
                            height: 250,
                            child:
                                Center(
                              child: Text(
                                'No rooms found.',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            14,
                            0,
                            14,
                            30,
                          ),
                          sliver:
                              SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  columns,
                              crossAxisSpacing:
                                  12,
                              mainAxisSpacing:
                                  12,
                              childAspectRatio:
                                  cardRatio,
                            ),
                            delegate:
                                SliverChildBuilderDelegate(
                              (
                                context,
                                index,
                              ) {
                                return roomCard(
                                  rooms[index],
                                );
                              },
                              childCount:
                                  rooms.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

enum RoomFilter {
  all,
  vacant,
  occupied,
}
