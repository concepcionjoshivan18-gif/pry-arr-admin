import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String phone;
  final String role; // "customer" | "admin" | "staff"
  final String? businessName;
  final bool marketingOptIn;
  final DateTime createdAt;
  final String status; // "Active" | "Inactive"
  final String? profilePhoto;
  final String? assignedRole; // For staff e.g. "Sales", "Inventory"
  
  // New Fields for Staff Profile & Shipping Addresses
  final String address;
  final List<String> shippingAddresses;
  final String? gender;
  final String emergencyContact;
  final List<String> favorites;
  final List<String> archivedOrders;

  // Loyalty Info for Customers
  final int loyaltyPoints;

  // Payroll info for staff
  final double? basicSalary;
  final String? payType; // "Hourly", "Monthly"
  final DateTime? birthday;

  // RFID & Shift info
  final String? rfidUid;
  final bool onShift;

  AppUser({
    required this.uid,
    required this.email,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.phone,
    required this.role,
    this.businessName,
    required this.marketingOptIn,
    required this.createdAt,
    this.status = 'Active',
    this.profilePhoto,
    this.assignedRole,
    this.address = '',
    List<String>? shippingAddresses,
    this.gender,
    this.emergencyContact = '',
    List<String>? favorites,
    List<String>? archivedOrders,
    this.loyaltyPoints = 0,
    this.basicSalary,
    this.payType,
    this.birthday,
    this.rfidUid,
    this.onShift = false,
  }) : shippingAddresses = shippingAddresses ?? (address.isNotEmpty ? [address] : []),
       favorites = favorites ?? [],
       archivedOrders = archivedOrders ?? [];

  String get fullName {
    final buffer = StringBuffer(firstName);
    if (middleName != null && middleName!.trim().isNotEmpty) {
      buffer.write(' ${middleName!.trim()}');
    }
    buffer.write(' $lastName');
    return buffer.toString();
  }

  bool get isDriver =>
      role == 'driver' ||
      assignedRole?.toLowerCase() == 'driver' ||
      assignedRole?.toLowerCase() == 'delivery';

  AppUser copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? middleName,
    String? lastName,
    String? phone,
    String? role,
    String? businessName,
    bool? marketingOptIn,
    DateTime? createdAt,
    String? status,
    String? profilePhoto,
    String? assignedRole,
    String? address,
    List<String>? shippingAddresses,
    String? gender,
    String? emergencyContact,
    List<String>? favorites,
    List<String>? archivedOrders,
    int? loyaltyPoints,
    double? basicSalary,
    String? payType,
    DateTime? birthday,
    String? rfidUid,
    bool? onShift,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      businessName: businessName ?? this.businessName,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      assignedRole: assignedRole ?? this.assignedRole,
      address: address ?? this.address,
      shippingAddresses: shippingAddresses ?? this.shippingAddresses,
      gender: gender ?? this.gender,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      favorites: favorites ?? this.favorites,
      archivedOrders: archivedOrders ?? this.archivedOrders,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      basicSalary: basicSalary ?? this.basicSalary,
      payType: payType ?? this.payType,
      birthday: birthday ?? this.birthday,
      rfidUid: rfidUid ?? this.rfidUid,
      onShift: onShift ?? this.onShift,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'phone': phone,
      'role': role,
      'businessName': businessName,
      'marketingOptIn': marketingOptIn,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'profilePhoto': profilePhoto,
      'assignedRole': assignedRole,
      'address': address,
      'shippingAddresses': shippingAddresses,
      'gender': gender,
      'emergencyContact': emergencyContact,
      'favorites': favorites,
      'archivedOrders': archivedOrders,
      'loyaltyPoints': loyaltyPoints,
      'basicSalary': basicSalary,
      'payType': payType,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'rfidUid': rfidUid,
      'onShift': onShift,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String docUid) {
    List<String> loadedAddresses = [];
    try {
      final rawAddresses = map['shippingAddresses'];
      if (rawAddresses != null && rawAddresses is List) {
        loadedAddresses = rawAddresses.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      } else if (map['address'] != null) {
        loadedAddresses = [map['address'].toString()];
      }
    } catch (_) {}

    List<String> loadedFavorites = [];
    try {
      final rawFavs = map['favorites'];
      if (rawFavs != null && rawFavs is List) {
        loadedFavorites = rawFavs.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}

    List<String> loadedArchivedOrders = [];
    try {
      final rawArchived = map['archivedOrders'];
      if (rawArchived != null && rawArchived is List) {
        loadedArchivedOrders = rawArchived.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}

    double? salary;
    try {
      if (map['basicSalary'] != null) {
        salary = (map['basicSalary'] as num).toDouble();
      }
    } catch (_) {}

    DateTime? bday;
    try {
      if (map['birthday'] is Timestamp) {
        bday = (map['birthday'] as Timestamp).toDate();
      }
    } catch (_) {}

    bool shiftStatus = false;
    try {
      shiftStatus = map['onShift'] == true;
    } catch (_) {}

    return AppUser(
      uid: docUid,
      email: map['email']?.toString() ?? '',
      firstName: map['firstName']?.toString() ?? '',
      middleName: map['middleName']?.toString(),
      lastName: map['lastName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      role: map['role']?.toString() ?? 'customer',
      businessName: map['businessName']?.toString(),
      marketingOptIn: map['marketingOptIn'] == true,
      createdAt: (map['createdAt'] is Timestamp) ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      status: map['status']?.toString() ?? 'Active',
      profilePhoto: map['profilePhoto']?.toString(),
      assignedRole: map['assignedRole']?.toString(),
      address: map['address']?.toString() ?? '',
      shippingAddresses: loadedAddresses,
      gender: map['gender']?.toString(),
      emergencyContact: map['emergencyContact']?.toString() ?? '',
      favorites: loadedFavorites,
      archivedOrders: loadedArchivedOrders,
      loyaltyPoints: (map['loyaltyPoints'] is num) ? (map['loyaltyPoints'] as num).toInt() : 0,
      basicSalary: salary,
      payType: map['payType']?.toString(),
      birthday: bday,
      rfidUid: map['rfidUid']?.toString(),
      onShift: shiftStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
