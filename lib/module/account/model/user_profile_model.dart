import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';

class UserOwnProfileData extends Equatable {
  const UserOwnProfileData({
    required this.userId,
    this.firstName,
    this.middleName,
    this.lastName,
    this.email,
    this.phoneNumber,
    required this.tier,
    required this.status,
    required this.transactionStatus,
    required this.isVerifiedAccount,
    required this.isVerifiedEmail,
    required this.isVerifiedPhoneNumber,
    required this.isCreatedPassword,
    required this.isCreatedPin,
    this.imageUrl,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
  });

  factory UserOwnProfileData.fromJson(Object? value) {
    final json = Map<String, Object?>.from(value! as Map);
    return UserOwnProfileData(
      userId: json['userId']! as String,
      firstName: json['firstName'] as String?,
      middleName: json['middleName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      tier: (json['tier']! as num).toInt(),
      status: json['status']! as String,
      transactionStatus: json['transactionStatus']! as String,
      isVerifiedAccount: json['isVerifiedAccount']! as bool,
      isVerifiedEmail: json['isVerifiedEmail']! as bool,
      isVerifiedPhoneNumber: json['isVerifiedPhoneNumber']! as bool,
      isCreatedPassword: json['isCreatedPassword']! as bool,
      isCreatedPin: json['isCreatedPin']! as bool,
      imageUrl: json['imageUrl'] as String?,
      lastLoginAt: _date(json['lastLoginAt'], 'lastLoginAt'),
      createdAt: _date(json['createdAt'], 'createdAt'),
      updatedAt: _date(json['updatedAt'], 'updatedAt'),
    );
  }

  static DateTime? _date(Object? value, String field) {
    if (value is! String) {
      if (value != null) _logDate(field);
      return null;
    }
    final parsed = DateTime.tryParse(value)?.toUtc();
    if (parsed == null) _logDate(field);
    return parsed;
  }

  static void _logDate(String field) {
    developer.log(
      'Unable to parse UserOwnProfileData.$field',
      name: 'BOCTrust.Model',
    );
  }

  final String userId;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? email;
  final String? phoneNumber;
  final int tier;
  final String status;
  final String transactionStatus;
  final bool isVerifiedAccount;
  final bool isVerifiedEmail;
  final bool isVerifiedPhoneNumber;
  final bool isCreatedPassword;
  final bool isCreatedPin;
  final String? imageUrl;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final parts = [
      firstName,
      middleName,
      lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty);
    final name = parts.join(' ');
    return name.isEmpty ? 'BOCTrust customer' : name;
  }

  UserOwnProfileData copyWith({bool? isCreatedPin}) => UserOwnProfileData(
    userId: userId,
    firstName: firstName,
    middleName: middleName,
    lastName: lastName,
    email: email,
    phoneNumber: phoneNumber,
    tier: tier,
    status: status,
    transactionStatus: transactionStatus,
    isVerifiedAccount: isVerifiedAccount,
    isVerifiedEmail: isVerifiedEmail,
    isVerifiedPhoneNumber: isVerifiedPhoneNumber,
    isCreatedPassword: isCreatedPassword,
    isCreatedPin: isCreatedPin ?? this.isCreatedPin,
    imageUrl: imageUrl,
    lastLoginAt: lastLoginAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  List<Object?> get props => [
    userId,
    firstName,
    middleName,
    lastName,
    email,
    phoneNumber,
    tier,
    status,
    transactionStatus,
    isVerifiedAccount,
    isVerifiedEmail,
    isVerifiedPhoneNumber,
    isCreatedPassword,
    isCreatedPin,
    imageUrl,
    lastLoginAt,
    createdAt,
    updatedAt,
  ];
}
