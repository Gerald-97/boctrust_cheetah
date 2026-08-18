import 'package:equatable/equatable.dart';

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

enum TierCardStatus {
  verified('verified'),
  inProgress('in_progress'),
  locked('locked'),
  unknown('unknown');

  const TierCardStatus(this.wireValue);
  final String wireValue;

  static TierCardStatus fromWire(Object? value) => switch (value) {
    'verified' => verified,
    'in_progress' => inProgress,
    'locked' => locked,
    _ => unknown,
  };
}

class TierLimitData extends Equatable {
  const TierLimitData({
    this.value,
    required this.isUnlimited,
    required this.displayValue,
  });
  factory TierLimitData.fromJson(Object? value) {
    final json = _map(value);
    return TierLimitData(
      value: json['value'] as String?,
      isUnlimited: json['isUnlimited']! as bool,
      displayValue: json['displayValue']! as String,
    );
  }
  final String? value;
  final bool isUnlimited;
  final String displayValue;

  @override
  List<Object?> get props => [value, isUnlimited, displayValue];
}

class TierRequirementData extends Equatable {
  const TierRequirementData({
    required this.key,
    required this.label,
    required this.isSatisfied,
  });
  factory TierRequirementData.fromJson(Object? value) {
    final json = _map(value);
    return TierRequirementData(
      key: json['key']! as String,
      label: json['label']! as String,
      isSatisfied: json['isSatisfied']! as bool,
    );
  }
  final String key;
  final String label;
  final bool isSatisfied;

  @override
  List<Object?> get props => [key, label, isSatisfied];
}

class CurrentTierSummaryData extends Equatable {
  const CurrentTierSummaryData({
    required this.tier,
    required this.tierLabel,
    required this.dailyTransferLimit,
    required this.maxWalletBalance,
  });
  factory CurrentTierSummaryData.fromJson(Object? value) {
    final json = _map(value);
    return CurrentTierSummaryData(
      tier: (json['tier']! as num).toInt(),
      tierLabel: json['tierLabel']! as String,
      dailyTransferLimit: TierLimitData.fromJson(json['dailyTransferLimit']),
      maxWalletBalance: TierLimitData.fromJson(json['maxWalletBalance']),
    );
  }
  final int tier;
  final String tierLabel;
  final TierLimitData dailyTransferLimit;
  final TierLimitData maxWalletBalance;

  @override
  List<Object?> get props => [
    tier,
    tierLabel,
    dailyTransferLimit,
    maxWalletBalance,
  ];
}

class TierCardData extends Equatable {
  const TierCardData({
    required this.tier,
    required this.title,
    this.description,
    required this.requirements,
    required this.status,
    required this.statusLabel,
    this.actionLabel,
    this.lockReason,
    required this.singleTransactionLimit,
    required this.singleDepositLimit,
    required this.cumulativeBalanceLimit,
    required this.checkLists,
  });
  factory TierCardData.fromJson(Object? value) {
    final json = _map(value);
    return TierCardData(
      tier: (json['tier']! as num).toInt(),
      title: json['title']! as String,
      description: json['description'] as String?,
      requirements: (json['requirements']! as List)
          .map(TierRequirementData.fromJson)
          .toList(growable: false),
      status: TierCardStatus.fromWire(json['status']),
      statusLabel: json['statusLabel']! as String,
      actionLabel: json['actionLabel'] as String?,
      lockReason: json['lockReason'] as String?,
      singleTransactionLimit: TierLimitData.fromJson(
        json['singleTransactionLimit'],
      ),
      singleDepositLimit: TierLimitData.fromJson(json['singleDepositLimit']),
      cumulativeBalanceLimit: TierLimitData.fromJson(
        json['cumulativeBalanceLimit'],
      ),
      checkLists: (json['checkLists']! as List).cast<String>(),
    );
  }
  final int tier;
  final String title;
  final String? description;
  final List<TierRequirementData> requirements;
  final TierCardStatus status;
  final String statusLabel;
  final String? actionLabel;
  final String? lockReason;
  final TierLimitData singleTransactionLimit;
  final TierLimitData singleDepositLimit;
  final TierLimitData cumulativeBalanceLimit;
  final List<String> checkLists;

  @override
  List<Object?> get props => [
    tier,
    title,
    description,
    requirements,
    status,
    statusLabel,
    actionLabel,
    lockReason,
    singleTransactionLimit,
    singleDepositLimit,
    cumulativeBalanceLimit,
    checkLists,
  ];
}

class UserTierInfoData extends Equatable {
  const UserTierInfoData({
    required this.userId,
    required this.currentTier,
    required this.currentTierSummary,
    required this.tiers,
  });
  factory UserTierInfoData.fromJson(Object? value) {
    final json = _map(value);
    return UserTierInfoData(
      userId: json['userId']! as String,
      currentTier: (json['currentTier']! as num).toInt(),
      currentTierSummary: CurrentTierSummaryData.fromJson(
        json['currentTierSummary'],
      ),
      tiers: (json['tiers']! as List)
          .map(TierCardData.fromJson)
          .toList(growable: false),
    );
  }
  final String userId;
  final int currentTier;
  final CurrentTierSummaryData currentTierSummary;
  final List<TierCardData> tiers;

  @override
  List<Object?> get props => [userId, currentTier, currentTierSummary, tiers];
}
