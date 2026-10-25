import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../Database/app_database.dart';
import '../Payments/billing_helper.dart';
import '../Residents/resident_details.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({
    super.key,
  });

  @override
  State<RegistrationPage> createState() =>
      _RegistrationPageState();
}

class _RegistrationPageState
    extends State<RegistrationPage> {
  late final Box residentsBox;
  late final Box roomsBox;
  late final Box paymentsBox;
  late final Box settingsBox;

  // ============================================================
  // RESIDENT
  // ============================================================

  final lastNameController =
      TextEditingController();

  final firstNameController =
      TextEditingController();

  final middleInitialController =
      TextEditingController();

  final ageController =
      TextEditingController();

  final permanentAddressController =
      TextEditingController();

  final contactController =
      TextEditingController();

  // ============================================================
  // STUDENT INFORMATION
  // ============================================================

  final schoolController =
      TextEditingController();

  final motherLastNameController =
      TextEditingController();

  final motherFirstNameController =
      TextEditingController();

  final motherMiddleInitialController =
      TextEditingController();

  final fatherLastNameController =
      TextEditingController();

  final fatherFirstNameController =
      TextEditingController();

  final fatherMiddleInitialController =
      TextEditingController();

  final guardianLastNameController =
      TextEditingController();

  final guardianFirstNameController =
      TextEditingController();

  final guardianMiddleInitialController =
      TextEditingController();

  // ============================================================
  // EMERGENCY
  // ============================================================

  final emergencyNumberController =
      TextEditingController();

  // ============================================================
  // PAYMENT
  // ============================================================

  final initialPaymentController =
      TextEditingController();

  // ============================================================
  // SEARCH
  // ============================================================

  final searchController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  Uint8List? residentPicture;

  String residentType = 'student';

  int? selectedRoom;

  String? selectedBed;

  dynamic editingKey;

  bool get isEditing =>
      editingKey != null;

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
  // FORMAT MONEY
  // ============================================================

  String money(double value) {
    return '₱${value.toStringAsFixed(2)}';
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
  // RESIDENT TYPE
  // ============================================================

  void changeResidentType(
    String type,
  ) {
    setState(() {
      residentType = type;
    });
  }

  // ============================================================
  // BED OCCUPANCY
  // ============================================================

  bool bedOccupiedByAnotherResident({
    required int roomNumber,
    required String bedType,
  }) {
    for (final key
        in residentsBox.keys) {
      if (isEditing &&
          key == editingKey) {
        continue;
      }

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

      final String status =
          resident['status']
                  ?.toString()
                  .toLowerCase() ??
              'active';

      if (status != 'active') {
        continue;
      }

      final dynamic room =
          resident['roomNumber'];

      final String bed =
          resident['bedType']
                  ?.toString()
                  .toLowerCase() ??
              '';

      if (room == roomNumber &&
          bed ==
              bedType.toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // AVAILABLE BEDS
  // ============================================================

  List<String> getAvailableBeds(
    int roomNumber,
  ) {
    final List<String> result = [];

    if (!bedOccupiedByAnotherResident(
      roomNumber: roomNumber,
      bedType: 'upper',
    )) {
      result.add(
        'upper',
      );
    }

    if (!bedOccupiedByAnotherResident(
      roomNumber: roomNumber,
      bedType: 'lower',
    )) {
      result.add(
        'lower',
      );
    }

    return result;
  }

  // ============================================================
  // AVAILABLE ROOMS
  // ============================================================

  List<int> getAvailableRooms() {
    final List<int> result = [];

    for (final key in roomsBox.keys) {
      final dynamic raw =
          roomsBox.get(key);

      if (raw == null ||
          raw is! Map) {
        continue;
      }

      final room =
          Map<dynamic, dynamic>.from(
        raw,
      );

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

      if (getAvailableBeds(
        roomNumber,
      ).isNotEmpty) {
        result.add(
          roomNumber,
        );
      }
    }

    result.sort();

    return result;
  }

  // ============================================================
  // SELECT PICTURE
  // ============================================================

  Future<void> selectPicture() async {
    final FilePickerResult? result =
        await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null ||
        result.files.isEmpty) {
      return;
    }

    final Uint8List? bytes =
        result.files.single.bytes;

    if (bytes == null ||
        !mounted) {
      return;
    }

    setState(() {
      residentPicture = bytes;
    });
  }

  // ============================================================
  // SAVE RESIDENT
  // ============================================================

  Future<void> saveResident() async {
    // ==========================================================
    // BASIC VALIDATION
    // ==========================================================

    if (lastNameController.text
            .trim()
            .isEmpty ||
        firstNameController.text
            .trim()
            .isEmpty) {
      showMessage(
        'Please enter the resident name.',
      );
      return;
    }

    final int? age =
        int.tryParse(
      ageController.text.trim(),
    );

    if (age == null ||
        age <= 0 ||
        age > 120) {
      showMessage(
        'Please enter a valid age.',
      );
      return;
    }

    if (permanentAddressController
        .text
        .trim()
        .isEmpty) {
      showMessage(
        'Please enter the permanent address.',
      );
      return;
    }

    final String contact =
        contactController.text.trim();

    if (contact.length != 11) {
      showMessage(
        'Contact number must contain 11 digits.',
      );
      return;
    }

    final String emergency =
        emergencyNumberController
            .text
            .trim();

    if (emergency.length != 11) {
      showMessage(
        'Emergency number must contain 11 digits.',
      );
      return;
    }

    if (residentType ==
            'student' &&
        schoolController.text
            .trim()
            .isEmpty) {
      showMessage(
        'Please enter the school name.',
      );
      return;
    }

    if (selectedRoom == null) {
      showMessage(
        'Please assign a room.',
      );
      return;
    }

    if (selectedBed == null) {
      showMessage(
        'Please select Upper Deck or Lower Deck.',
      );
      return;
    }

    if (bedOccupiedByAnotherResident(
      roomNumber:
          selectedRoom!,
      bedType:
          selectedBed!,
    )) {
      showMessage(
        'That bed is already occupied.',
      );

      setState(() {
        selectedBed = null;
      });

      return;
    }

    // ==========================================================
    // EDIT EXISTING RESIDENT
    // ==========================================================

    if (isEditing) {
      final dynamic oldRaw =
          residentsBox.get(
        editingKey,
      );

      if (oldRaw == null ||
          oldRaw is! Map) {
        showMessage(
          'Resident record was not found.',
        );
        return;
      }

      final Map<String, dynamic>
          oldResident =
          Map<String, dynamic>.from(
        oldRaw,
      );

      final Map<String, dynamic>
          updated = {
        ...oldResident,

        'picture':
            residentPicture,

        'residentType':
            residentType,

        'lastName':
            lastNameController
                .text
                .trim(),

        'firstName':
            firstNameController
                .text
                .trim(),

        'middleInitial':
            middleInitialController
                .text
                .trim(),

        'age':
            age,

        'permanentAddress':
            permanentAddressController
                .text
                .trim(),

        'contactNumber':
            contact,

        'schoolName':
            residentType ==
                    'student'
                ? schoolController
                    .text
                    .trim()
                : '',

        'motherLastName':
            residentType ==
                    'student'
                ? motherLastNameController
                    .text
                    .trim()
                : '',

        'motherFirstName':
            residentType ==
                    'student'
                ? motherFirstNameController
                    .text
                    .trim()
                : '',

        'motherMiddleInitial':
            residentType ==
                    'student'
                ? motherMiddleInitialController
                    .text
                    .trim()
                : '',

        'fatherLastName':
            residentType ==
                    'student'
                ? fatherLastNameController
                    .text
                    .trim()
                : '',

        'fatherFirstName':
            residentType ==
                    'student'
                ? fatherFirstNameController
                    .text
                    .trim()
                : '',

        'fatherMiddleInitial':
            residentType ==
                    'student'
                ? fatherMiddleInitialController
                    .text
                    .trim()
                : '',

        'guardianLastName':
            residentType ==
                    'student'
                ? guardianLastNameController
                    .text
                    .trim()
                : '',

        'guardianFirstName':
            residentType ==
                    'student'
                ? guardianFirstNameController
                    .text
                    .trim()
                : '',

        'guardianMiddleInitial':
            residentType ==
                    'student'
                ? guardianMiddleInitialController
                    .text
                    .trim()
                : '',

        'emergencyNumber':
            emergency,

        'roomNumber':
            selectedRoom,

        'bedType':
            selectedBed,

        'updatedAt':
            DateTime.now()
                .toIso8601String(),
      };

      await residentsBox.put(
        editingKey,
        updated,
      );

      showMessage(
        'Resident information updated.',
      );

      clearForm();

      return;
    }

    // ==========================================================
    // INITIAL PAYMENT
    //
    // ANY POSITIVE AMOUNT IS ALLOWED.
    //
    // ₱1000 of ₱3500:
    // partialCredit = 1000
    // balanceDue = 2500
    //
    // ₱4500:
    // 1 cycle completed
    // partialCredit = 1000
    // balanceDue = 2500 toward next cycle
    // ==========================================================

    final double? initialPayment =
        double.tryParse(
      initialPaymentController
          .text
          .trim(),
    );

    if (initialPayment == null ||
        initialPayment <= 0) {
      showMessage(
        'Please enter a valid initial payment amount.',
      );
      return;
    }

    final DateTime now =
        DateTime.now();

    final BillingResult billing =
        BillingHelper.applyPayment(
      payment:
          initialPayment,

      monthlyRate:
          monthlyRate,

      billingDays:
          billingDays,

      referenceDate:
          now,

      // A partial initial payment does not create paid coverage.
      existingPaidUntil:
          null,

      existingPartialCredit:
          0,

      billingStartedAt:
          now,
    );

    // ==========================================================
    // RESIDENT DATA
    // ==========================================================

    final Map<String, dynamic>
        resident = {
      'picture':
          residentPicture,

      'residentType':
          residentType,

      'lastName':
          lastNameController
              .text
              .trim(),

      'firstName':
          firstNameController
              .text
              .trim(),

      'middleInitial':
          middleInitialController
              .text
              .trim(),

      'age':
          age,

      'permanentAddress':
          permanentAddressController
              .text
              .trim(),

      'contactNumber':
          contact,

      'schoolName':
          residentType ==
                  'student'
              ? schoolController
                  .text
                  .trim()
              : '',

      'motherLastName':
          residentType ==
                  'student'
              ? motherLastNameController
                  .text
                  .trim()
              : '',

      'motherFirstName':
          residentType ==
                  'student'
              ? motherFirstNameController
                  .text
                  .trim()
              : '',

      'motherMiddleInitial':
          residentType ==
                  'student'
              ? motherMiddleInitialController
                  .text
                  .trim()
              : '',

      'fatherLastName':
          residentType ==
                  'student'
              ? fatherLastNameController
                  .text
                  .trim()
              : '',

      'fatherFirstName':
          residentType ==
                  'student'
              ? fatherFirstNameController
                  .text
                  .trim()
              : '',

      'fatherMiddleInitial':
          residentType ==
                  'student'
              ? fatherMiddleInitialController
                  .text
                  .trim()
              : '',

      'guardianLastName':
          residentType ==
                  'student'
              ? guardianLastNameController
                  .text
                  .trim()
              : '',

      'guardianFirstName':
          residentType ==
                  'student'
              ? guardianFirstNameController
                  .text
                  .trim()
              : '',

      'guardianMiddleInitial':
          residentType ==
                  'student'
              ? guardianMiddleInitialController
                  .text
                  .trim()
              : '',

      'emergencyNumber':
          emergency,

      'roomNumber':
          selectedRoom,

      'bedType':
          selectedBed,

      'status':
          'active',

      'registeredAt':
          now.toIso8601String(),

      'updatedAt':
          now.toIso8601String(),

      'deactivatedAt':
          null,

      'deactivationReason':
          null,

      'reactivatedAt':
          null,

      // Billing starts on the registration date.
      'billingStartedAt':
          now.toIso8601String(),

      // The date this current billing obligation is due.
      'currentDueDate':
          billing.currentDueDate
              .toIso8601String(),

      // Null until at least one complete billing cycle is paid.
      'paidUntil':
          billing.paidUntil
              ?.toIso8601String(),

      // Money already applied toward an incomplete cycle.
      'partialCredit':
          billing.partialCredit,

      // Amount still needed to complete the current/next cycle.
      'balanceDue':
          billing.remainingBalance,

      'statusHistory': [
        {
          'type':
              'registered',

          'at':
              now.toIso8601String(),

          'roomNumber':
              selectedRoom,

          'bedType':
              selectedBed,
        },
      ],
    };

    final dynamic residentKey =
        await residentsBox.add(
      resident,
    );

    // ==========================================================
    // INITIAL PAYMENT TRANSACTION
    // ==========================================================

    await paymentsBox.add({
      'residentKey':
          residentKey,

      'residentType':
          residentType,

      'firstName':
          firstNameController
              .text
              .trim(),

      'lastName':
          lastNameController
              .text
              .trim(),

      'roomNumber':
          selectedRoom,

      'bedType':
          selectedBed,

      'amount':
          initialPayment,

      'monthlyRate':
          monthlyRate,

      'cyclesCovered':
          billing
              .fullCyclesAdded,

      'partialCreditBefore':
          0.0,

      'partialCreditAfter':
          billing
              .partialCredit,

      'balanceDueAfter':
          billing
              .remainingBalance,

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
          'Initial Payment',
    });

    // ==========================================================
    // RESULT MESSAGE
    // ==========================================================

    if (billing.remainingBalance >
        0) {
      showMessage(
        'Resident registered. '
        'Initial payment ${money(initialPayment)} recorded. '
        'Remaining balance: '
        '${money(billing.remainingBalance)}.',
      );
    } else {
      showMessage(
        'Resident registered. '
        '${billing.fullCyclesAdded} billing cycle'
        '${billing.fullCyclesAdded == 1 ? '' : 's'} completed.',
      );
    }

    clearForm();
  }

  // ============================================================
  // EDIT RESIDENT
  // ============================================================

  void editResident(
    dynamic key,
    Map<dynamic, dynamic> resident,
  ) {
    setState(() {
      editingKey = key;

      final dynamic picture =
          resident['picture'];

      residentPicture =
          picture is Uint8List
              ? picture
              : null;

      residentType =
          resident['residentType']
                  ?.toString() ??
              'student';

      lastNameController.text =
          resident['lastName']
                  ?.toString() ??
              '';

      firstNameController.text =
          resident['firstName']
                  ?.toString() ??
              '';

      middleInitialController.text =
          resident['middleInitial']
                  ?.toString() ??
              '';

      ageController.text =
          resident['age']
                  ?.toString() ??
              '';

      permanentAddressController.text =
          resident[
                      'permanentAddress']
                  ?.toString() ??
              '';

      contactController.text =
          resident['contactNumber']
                  ?.toString() ??
              '';

      schoolController.text =
          resident['schoolName']
                  ?.toString() ??
              '';

      motherLastNameController.text =
          resident['motherLastName']
                  ?.toString() ??
              '';

      motherFirstNameController.text =
          resident['motherFirstName']
                  ?.toString() ??
              '';

      motherMiddleInitialController
              .text =
          resident[
                      'motherMiddleInitial']
                  ?.toString() ??
              '';

      fatherLastNameController.text =
          resident['fatherLastName']
                  ?.toString() ??
              '';

      fatherFirstNameController.text =
          resident['fatherFirstName']
                  ?.toString() ??
              '';

      fatherMiddleInitialController
              .text =
          resident[
                      'fatherMiddleInitial']
                  ?.toString() ??
              '';

      guardianLastNameController
              .text =
          resident[
                      'guardianLastName']
                  ?.toString() ??
              '';

      guardianFirstNameController
              .text =
          resident[
                      'guardianFirstName']
                  ?.toString() ??
              '';

      guardianMiddleInitialController
              .text =
          resident[
                      'guardianMiddleInitial']
                  ?.toString() ??
              '';

      emergencyNumberController.text =
          resident[
                      'emergencyNumber']
                  ?.toString() ??
              '';

      selectedRoom =
          resident['roomNumber']
                  is int
              ? resident['roomNumber']
              : int.tryParse(
                  resident['roomNumber']
                          ?.toString() ??
                      '',
                );

      selectedBed =
          resident['bedType']
              ?.toString();

      initialPaymentController.clear();
    });
  }

  // ============================================================
  // CLEAR FORM
  // ============================================================

  void clearForm() {
    lastNameController.clear();
    firstNameController.clear();
    middleInitialController.clear();

    ageController.clear();
    permanentAddressController.clear();
    contactController.clear();

    schoolController.clear();

    motherLastNameController.clear();
    motherFirstNameController.clear();
    motherMiddleInitialController.clear();

    fatherLastNameController.clear();
    fatherFirstNameController.clear();
    fatherMiddleInitialController.clear();

    guardianLastNameController.clear();
    guardianFirstNameController.clear();
    guardianMiddleInitialController.clear();

    emergencyNumberController.clear();

    initialPaymentController.clear();

    setState(() {
      residentPicture = null;

      residentType = 'student';

      selectedRoom = null;

      selectedBed = null;

      editingKey = null;
    });
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
  // INPUT FIELD
  // ============================================================

  Widget inputField({
    required String label,
    required TextEditingController
        controller,
    TextInputType keyboardType =
        TextInputType.text,
    List<TextInputFormatter>?
        inputFormatters,
    int? maxLength,
    int maxLines = 1,
    bool enabled = true,
    String? helperText,
  }) {
    return TextField(
      controller: controller,

      enabled: enabled,

      keyboardType:
          keyboardType,

      inputFormatters:
          inputFormatters,

      maxLength:
          maxLength,

      maxLines:
          maxLines,

      decoration:
          InputDecoration(
        labelText:
            label,

        helperText:
            helperText,

        counterText:
            '',
      ),
    );
  }

  // ============================================================
  // NAME FIELDS
  // ============================================================

  Widget nameFields({
    required TextEditingController
        lastName,
    required TextEditingController
        firstName,
    required TextEditingController
        middleInitial,
  }) {
    return LayoutBuilder(
      builder:
          (
        context,
        constraints,
      ) {
        if (constraints.maxWidth <
            520) {
          return Column(
            children: [
              inputField(
                label:
                    'Last Name',
                controller:
                    lastName,
              ),

              const SizedBox(
                  height: 10),

              inputField(
                label:
                    'First Name',
                controller:
                    firstName,
              ),

              const SizedBox(
                  height: 10),

              inputField(
                label:
                    'M.I.',

                controller:
                    middleInitial,

                maxLength:
                    1,

                inputFormatters: [
                  FilteringTextInputFormatter
                      .allow(
                    RegExp(
                      r'[a-zA-Z]',
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 3,
              child:
                  inputField(
                label:
                    'Last Name',
                controller:
                    lastName,
              ),
            ),

            const SizedBox(
                width: 10),

            Expanded(
              flex: 3,
              child:
                  inputField(
                label:
                    'First Name',
                controller:
                    firstName,
              ),
            ),

            const SizedBox(
                width: 10),

            Expanded(
              child:
                  inputField(
                label:
                    'M.I.',

                controller:
                    middleInitial,

                maxLength:
                    1,

                inputFormatters: [
                  FilteringTextInputFormatter
                      .allow(
                    RegExp(
                      r'[a-zA-Z]',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget sectionTitle(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child:
          Row(
        children: [
          Icon(
            icon,
            size: 20,
            color:
                const Color(
                    0xFF17617D),
          ),

          const SizedBox(
              width: 8),

          Text(
            title,
            style:
                const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESIDENT TYPE
  // ============================================================

  Widget residentTypeSelector() {
    return Row(
      children: [
        Expanded(
          child:
              ChoiceChip(
            selected:
                residentType ==
                    'student',

            onSelected:
                (_) {
              changeResidentType(
                'student',
              );
            },

            avatar:
                const Icon(
              Icons
                  .school_outlined,
              size: 18,
            ),

            label:
                const SizedBox(
              width:
                  double.infinity,
              child:
                  Text(
                'Student Resident',
                textAlign:
                    TextAlign.center,
              ),
            ),
          ),
        ),

        const SizedBox(
            width: 10),

        Expanded(
          child:
              ChoiceChip(
            selected:
                residentType ==
                    'regular',

            onSelected:
                (_) {
              changeResidentType(
                'regular',
              );
            },

            avatar:
                const Icon(
              Icons
                  .person_outline,
              size: 18,
            ),

            label:
                const SizedBox(
              width:
                  double.infinity,
              child:
                  Text(
                'Regular Resident',
                textAlign:
                    TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REGISTRATION FORM
  // ============================================================

  Widget registrationForm() {
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
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Resident Registration',
                      style:
                          TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                        height: 4),

                    Text(
                      'Register Student Residents and Regular Residents.',
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              if (isEditing)
                const Chip(
                  label:
                      Text(
                    'Editing',
                  ),
                ),
            ],
          ),

          const SizedBox(
              height: 25),

          sectionTitle(
            'Resident Type',
            Icons
                .badge_outlined,
          ),

          residentTypeSelector(),

          const SizedBox(
              height: 25),

          // ====================================================
          // PHOTO
          // ====================================================

          sectionTitle(
            'Picture',
            Icons
                .photo_camera_outlined,
          ),

          Row(
            children: [
              Container(
                width: 100,
                height: 100,

                clipBehavior:
                    Clip.antiAlias,

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                          0xFFF2F4F7),

                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),

                child:
                    residentPicture ==
                            null
                        ? const Icon(
                            Icons
                                .person_outline,
                            size:
                                48,
                          )
                        : Image.memory(
                            residentPicture!,
                            fit:
                                BoxFit.cover,
                          ),
              ),

              const SizedBox(
                  width: 15),

              ElevatedButton.icon(
                onPressed:
                    selectPicture,

                icon:
                    const Icon(
                  Icons
                      .upload_outlined,
                ),

                label:
                    const Text(
                  'Choose Picture',
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 25),

          // ====================================================
          // BASIC INFO
          // ====================================================

          sectionTitle(
            'Resident Information',
            Icons
                .person_outline,
          ),

          nameFields(
            lastName:
                lastNameController,

            firstName:
                firstNameController,

            middleInitial:
                middleInitialController,
          ),

          const SizedBox(
              height: 12),

          LayoutBuilder(
            builder:
                (
              context,
              constraints,
            ) {
              if (constraints.maxWidth <
                  520) {
                return Column(
                  children: [
                    inputField(
                      label:
                          'Age',

                      controller:
                          ageController,

                      keyboardType:
                          TextInputType
                              .number,

                      maxLength:
                          3,

                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                      ],
                    ),

                    const SizedBox(
                        height: 10),

                    inputField(
                      label:
                          'Contact Number',

                      controller:
                          contactController,

                      keyboardType:
                          TextInputType
                              .phone,

                      maxLength:
                          11,

                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child:
                        inputField(
                      label:
                          'Age',

                      controller:
                          ageController,

                      keyboardType:
                          TextInputType
                              .number,

                      maxLength:
                          3,

                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                      ],
                    ),
                  ),

                  const SizedBox(
                      width: 10),

                  Expanded(
                    flex: 2,
                    child:
                        inputField(
                      label:
                          'Contact Number',

                      controller:
                          contactController,

                      keyboardType:
                          TextInputType
                              .phone,

                      maxLength:
                          11,

                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(
              height: 12),

          inputField(
            label:
                'Permanent Address',

            controller:
                permanentAddressController,

            maxLines:
                2,
          ),

          // ====================================================
          // STUDENT
          // ====================================================

          if (residentType ==
              'student') ...[
            const SizedBox(
                height: 25),

            sectionTitle(
              'Student Information',
              Icons
                  .school_outlined,
            ),

            inputField(
              label:
                  'School Name',

              controller:
                  schoolController,
            ),

            const SizedBox(
                height: 20),

            const Text(
              'Mother',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
                height: 10),

            nameFields(
              lastName:
                  motherLastNameController,

              firstName:
                  motherFirstNameController,

              middleInitial:
                  motherMiddleInitialController,
            ),

            const SizedBox(
                height: 20),

            const Text(
              'Father',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
                height: 10),

            nameFields(
              lastName:
                  fatherLastNameController,

              firstName:
                  fatherFirstNameController,

              middleInitial:
                  fatherMiddleInitialController,
            ),

            const SizedBox(
                height: 20),

            const Text(
              'Guardian',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
                height: 10),

            nameFields(
              lastName:
                  guardianLastNameController,

              firstName:
                  guardianFirstNameController,

              middleInitial:
                  guardianMiddleInitialController,
            ),
          ],

          const SizedBox(
              height: 25),

          // ====================================================
          // EMERGENCY
          // ====================================================

          sectionTitle(
            'Emergency Contact',
            Icons
                .contact_emergency_outlined,
          ),

          inputField(
            label:
                'Emergency Number',

            controller:
                emergencyNumberController,

            keyboardType:
                TextInputType.phone,

            maxLength:
                11,

            inputFormatters: [
              FilteringTextInputFormatter
                  .digitsOnly,
            ],
          ),

          const SizedBox(
              height: 25),

          // ====================================================
          // ROOM + BED
          // ====================================================

          sectionTitle(
            'Room & Bed Assignment',
            Icons.bed_outlined,
          ),

          ValueListenableBuilder(
            valueListenable:
                residentsBox
                    .listenable(),

            builder:
                (
              context,
              Box residents,
              _,
            ) {
              return ValueListenableBuilder(
                valueListenable:
                    roomsBox
                        .listenable(),

                builder:
                    (
                  context,
                  Box rooms,
                  __,
                ) {
                  final List<int>
                      availableRooms =
                      getAvailableRooms();

                  return Column(
                    children: [
                      DropdownButtonFormField<
                          int>(
                        value:
                            availableRooms
                                    .contains(
                                      selectedRoom,
                                    )
                                ? selectedRoom
                                : null,

                        isExpanded:
                            true,

                        decoration:
                            InputDecoration(
                          labelText:
                              'Room',

                          helperText:
                              '${availableRooms.length} room'
                              '${availableRooms.length == 1 ? '' : 's'} '
                              'have an available bed',
                        ),

                        items:
                            availableRooms
                                .map(
                          (
                            room,
                          ) {
                            final beds =
                                getAvailableBeds(
                              room,
                            );

                            return DropdownMenuItem<
                                int>(
                              value:
                                  room,

                              child:
                                  Text(
                                'Room ${room.toString().padLeft(3, '0')} • '
                                '${beds.length} bed'
                                '${beds.length == 1 ? '' : 's'} available',
                              ),
                            );
                          },
                        ).toList(),

                        onChanged:
                            (value) {
                          setState(
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
                            selectedRoom !=
                                        null &&
                                    getAvailableBeds(
                                      selectedRoom!,
                                    ).contains(
                                      selectedBed,
                                    )
                                ? selectedBed
                                : null,

                        isExpanded:
                            true,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Bed Choice',
                        ),

                        hint:
                            const Text(
                          'Select Upper Deck or Lower Deck',
                        ),

                        items:
                            selectedRoom ==
                                    null
                                ? []
                                : getAvailableBeds(
                                    selectedRoom!,
                                  ).map(
                                    (
                                      bed,
                                    ) {
                                      return DropdownMenuItem<
                                          String>(
                                        value:
                                            bed,

                                        child:
                                            Row(
                                          children: [
                                            Icon(
                                              bed ==
                                                      'upper'
                                                  ? Icons
                                                      .keyboard_double_arrow_up
                                                  : Icons
                                                      .keyboard_double_arrow_down,
                                              size:
                                                  18,
                                            ),

                                            const SizedBox(
                                                width: 8),

                                            Text(
                                              bed ==
                                                      'upper'
                                                  ? 'Upper Deck'
                                                  : 'Lower Deck',
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ).toList(),

                        onChanged:
                            selectedRoom ==
                                    null
                                ? null
                                : (value) {
                                    setState(
                                      () {
                                        selectedBed =
                                            value;
                                      },
                                    );
                                  },
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(
              height: 25),

          // ====================================================
          // PAYMENT
          // ====================================================

          sectionTitle(
            'Initial Payment',
            Icons
                .payments_outlined,
          ),

          if (isEditing)
            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                15,
              ),

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                        0xFFF2F4F7),

                borderRadius:
                    BorderRadius
                        .circular(
                  10,
                ),
              ),

              child:
                  const Text(
                'Payments are managed from the Payments page. '
                'Editing a resident here will not change payment history.',
              ),
            )
          else
            ValueListenableBuilder(
              valueListenable:
                  settingsBox
                      .listenable(),

              builder:
                  (
                context,
                Box settings,
                _,
              ) {
                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    inputField(
                      label:
                          'Initial Payment',

                      controller:
                          initialPaymentController,

                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal:
                            true,
                      ),

                      inputFormatters: [
                        paymentFormatter,
                      ],

                      helperText:
                          'Any payment amount is accepted. '
                          '${money(monthlyRate)} completes 1 billing cycle.',
                    ),

                    const SizedBox(
                        height: 7),

                    const Text(
                      'Partial payments will be tracked automatically. '
                      'Example: ₱1,000 payment on a ₱3,500 rate leaves '
                      '₱2,500 remaining.',
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                        fontSize:
                            11,
                      ),
                    ),

                    const SizedBox(
                        height: 7),

                    Text(
                      'Billing cycle: $billingDays days',
                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
                        fontSize:
                            11,
                      ),
                    ),
                  ],
                );
              },
            ),

          const SizedBox(
              height: 28),

          // ====================================================
          // REGISTER BUTTON
          // ====================================================

          Row(
            children: [
              if (isEditing) ...[
                Expanded(
                  child:
                      OutlinedButton(
                    onPressed:
                        clearForm,

                    style:
                        OutlinedButton
                            .styleFrom(
                      minimumSize:
                          const Size(
                        0,
                        52,
                      ),
                    ),

                    child:
                        const Text(
                      'Cancel',
                    ),
                  ),
                ),

                const SizedBox(
                    width: 10),
              ],

              Expanded(
                flex: 2,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      saveResident,

                  style:
                      ElevatedButton
                          .styleFrom(
                    minimumSize:
                        const Size(
                      0,
                      52,
                    ),
                  ),

                  icon:
                      Icon(
                    isEditing
                        ? Icons
                            .save_outlined
                        : Icons
                            .person_add_alt_1_outlined,
                  ),

                  label:
                      Text(
                    isEditing
                        ? 'Save Changes'
                        : 'Register Resident',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESIDENT LIST
  // ============================================================

  Widget residentList() {
    return Container(
      height:
          700,

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
          Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(
              18,
            ),

            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                const Text(
                  'Registered Residents',
                  style:
                      TextStyle(
                    fontSize:
                        20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                    height: 4),

                const Text(
                  'Student and Regular Resident records.',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                    fontSize:
                        12,
                  ),
                ),

                const SizedBox(
                    height: 14),

                TextField(
                  controller:
                      searchController,

                  onChanged:
                      (_) {
                    setState(
                      () {},
                    );
                  },

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Search name, room or address...',

                    prefixIcon:
                        Icon(
                      Icons.search,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(
              height: 1),

          Expanded(
            child:
                ValueListenableBuilder(
              valueListenable:
                  residentsBox
                      .listenable(),

              builder:
                  (
                context,
                Box residents,
                _,
              ) {
                final String query =
                    searchController.text
                        .trim()
                        .toLowerCase();

                final List<dynamic>
                    keys =
                    residents.keys.where(
                  (key) {
                    final dynamic raw =
                        residents.get(key);

                    if (raw == null ||
                        raw is! Map) {
                      return false;
                    }

                    final resident =
                        Map<dynamic,
                                dynamic>.from(
                      raw,
                    );

                    if (query.isEmpty) {
                      return true;
                    }

                    final String first =
                        '${resident['firstName'] ?? ''}'
                            .toLowerCase();

                    final String last =
                        '${resident['lastName'] ?? ''}'
                            .toLowerCase();

                    final String address =
                        '${resident['permanentAddress'] ?? ''}'
                            .toLowerCase();

                    final String room =
                        '${resident['roomNumber'] ?? ''}'
                            .toLowerCase();

                    return first
                            .contains(
                              query,
                            ) ||
                        last.contains(
                          query,
                        ) ||
                        address.contains(
                          query,
                        ) ||
                        room.contains(
                          query,
                        );
                  },
                ).toList();

                if (keys.isEmpty) {
                  return const Center(
                    child:
                        Text(
                      'No residents found.',
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),

                  itemCount:
                      keys.length,

                  separatorBuilder:
                      (
                    _,
                    __,
                  ) =>
                          const SizedBox(
                    height:
                        8,
                  ),

                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final dynamic key =
                        keys[index];

                    final resident =
                        Map<dynamic,
                                dynamic>.from(
                      residents.get(
                        key,
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
                                ?.toString() ??
                            'active';

                    final String bed =
                        resident['bedType']
                                ?.toString() ??
                            '';

                    final dynamic roomNumber =
                        resident[
                            'roomNumber'];

                    final String assignment =
                        roomNumber ==
                                null
                            ? 'No room assigned'
                            : 'Room ${roomNumber.toString().padLeft(3, '0')}'
                                '${bed.isEmpty ? '' : ' • ${bed == 'upper' ? 'Upper Deck' : 'Lower Deck'}'}';

                    return Container(
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
                            BorderRadius
                                .circular(
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
                          CircleAvatar(
                            radius:
                                26,

                            backgroundImage:
                                picture
                                        is Uint8List
                                    ? MemoryImage(
                                        picture,
                                      )
                                    : null,

                            child:
                                picture
                                        is Uint8List
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
                                  '${resident['firstName'] ?? ''}'
                                  '${(resident['middleInitial'] ?? '').toString().isEmpty ? '' : ' ${resident['middleInitial']}.'}',

                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(
                                    height: 3),

                                Text(
                                  type ==
                                          'student'
                                      ? 'Student Resident'
                                      : 'Regular Resident',

                                  style:
                                      const TextStyle(
                                    fontSize:
                                        11,

                                    color:
                                        Color(
                                            0xFF17617D),
                                  ),
                                ),

                                Text(
                                  assignment,

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
                                  8,
                              vertical:
                                  5,
                            ),

                            decoration:
                                BoxDecoration(
                              color:
                                  status ==
                                          'active'
                                      ? Colors
                                          .green
                                          .withOpacity(
                                            .10,
                                          )
                                      : Colors
                                          .grey
                                          .withOpacity(
                                            .15,
                                          ),

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),

                            child:
                                Text(
                              status ==
                                      'active'
                                  ? 'Active'
                                  : 'Inactive',

                              style:
                                  TextStyle(
                                fontSize:
                                    10,

                                fontWeight:
                                    FontWeight
                                        .bold,

                                color:
                                    status ==
                                            'active'
                                        ? Colors
                                            .green
                                        : Colors
                                            .grey,
                              ),
                            ),
                          ),

                          IconButton(
                            tooltip:
                                'View Record',

                            onPressed:
                                () {
                              showDialog(
                                context:
                                    context,

                                builder:
                                    (
                                  context,
                                ) {
                                  return ResidentDetailsDialog(
                                    residentKey:
                                        key,
                                  );
                                },
                              );
                            },

                            icon:
                                const Icon(
                              Icons
                                  .visibility_outlined,

                              color:
                                  Color(
                                      0xFF17617D),
                            ),
                          ),

                          if (status ==
                              'active')
                            IconButton(
                              tooltip:
                                  'Edit',

                              onPressed:
                                  () {
                                editResident(
                                  key,
                                  resident,
                                );
                              },

                              icon:
                                  const Icon(
                                Icons
                                    .edit_outlined,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
      color:
          const Color(
              0xFFF5F7FA),

      child:
          LayoutBuilder(
        builder:
            (
          context,
          constraints,
        ) {
          final bool desktop =
              constraints.maxWidth >=
                  1050;

          if (desktop) {
            return SingleChildScrollView(
              padding:
                  const EdgeInsets.all(
                20,
              ),

              child:
                  Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Expanded(
                    flex: 6,
                    child:
                        registrationForm(),
                  ),

                  const SizedBox(
                      width: 18),

                  Expanded(
                    flex: 5,
                    child:
                        residentList(),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              14,
            ),

            child:
                Column(
              children: [
                registrationForm(),

                const SizedBox(
                    height: 18),

                residentList(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    lastNameController.dispose();
    firstNameController.dispose();
    middleInitialController.dispose();

    ageController.dispose();
    permanentAddressController.dispose();
    contactController.dispose();

    schoolController.dispose();

    motherLastNameController.dispose();
    motherFirstNameController.dispose();
    motherMiddleInitialController.dispose();

    fatherLastNameController.dispose();
    fatherFirstNameController.dispose();
    fatherMiddleInitialController.dispose();

    guardianLastNameController.dispose();
    guardianFirstNameController.dispose();
    guardianMiddleInitialController.dispose();

    emergencyNumberController.dispose();

    initialPaymentController.dispose();

    searchController.dispose();

    super.dispose();
  }
}