import 'package:equatable/equatable.dart';

import '../../../app/feature_capability.dart';

/// The four Boc savings products. Route paths keep their legacy names
/// (target, lock, group); these are the customer-facing names.
enum SavingsProductType {
  flex('Boc Flex Savings', null),
  smartSave('Boc SmartSave', FeatureCapability.smartSaveCreate),
  fixed('Boc Fixed Deposit', FeatureCapability.fixedDepositCreate),
  padi('Boc Padi', FeatureCapability.padiCreate);

  const SavingsProductType(this.displayName, this.createCapability);

  final String displayName;

  /// Gates creating a new plan of this type; Flex has no create step.
  final FeatureCapability? createCapability;
}

enum SavingsFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly');

  const SavingsFrequency(this.label);
  final String label;
}

enum SavingsPlanStatus { active, matured, closed }

/// A customer's savings plan as the server reports it. Amounts arrive
/// server-formatted; the client never computes balances or interest.
class SavingsPlan extends Equatable {
  const SavingsPlan({
    required this.id,
    required this.type,
    required this.name,
    required this.balance,
    required this.status,
    this.target,
    this.progress,
    this.rate,
    this.maturityDate,
    this.earlyWithdrawalPenalty,
  });

  final String id;
  final SavingsProductType type;
  final String name;
  final String balance;
  final SavingsPlanStatus status;
  final String? target;

  /// 0–1 progress toward [target], when the server reports one.
  final double? progress;
  final String? rate;
  final DateTime? maturityDate;

  /// Server copy describing the cost of withdrawing before maturity.
  final String? earlyWithdrawalPenalty;

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    balance,
    status,
    target,
    progress,
    rate,
    maturityDate,
    earlyWithdrawalPenalty,
  ];
}

/// Where a deposit or plan funding comes from.
enum FundingSource {
  wallet('BOCTRUST wallet'),
  flexSavings('Boc Flex Savings'),
  bankTransfer('Bank transfer');

  const FundingSource(this.label);
  final String label;
}

/// A plan being created. Every field stays client-side until the product's
/// create capability exists and the server confirms the plan.
class SavingsPlanDraft extends Equatable {
  const SavingsPlanDraft({
    required this.type,
    this.name = '',
    this.amount = '',
    this.durationMonths,
    this.autoSave = false,
    this.frequency,
    this.contributionDays = const {},
    this.fundingSource,
    this.memberCount,
    this.startDate,
  });

  final SavingsProductType type;
  final String name;

  /// Target (SmartSave), principal (Fixed) or per-member contribution (Padi),
  /// as typed, in naira.
  final String amount;
  final int? durationMonths;
  final bool autoSave;
  final SavingsFrequency? frequency;
  final Set<int> contributionDays;
  final FundingSource? fundingSource;
  final int? memberCount;
  final DateTime? startDate;

  SavingsPlanDraft copyWith({
    String? name,
    String? amount,
    int? durationMonths,
    bool? autoSave,
    SavingsFrequency? frequency,
    Set<int>? contributionDays,
    FundingSource? fundingSource,
    int? memberCount,
    DateTime? startDate,
  }) => SavingsPlanDraft(
    type: type,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    durationMonths: durationMonths ?? this.durationMonths,
    autoSave: autoSave ?? this.autoSave,
    frequency: frequency ?? this.frequency,
    contributionDays: contributionDays ?? this.contributionDays,
    fundingSource: fundingSource ?? this.fundingSource,
    memberCount: memberCount ?? this.memberCount,
    startDate: startDate ?? this.startDate,
  );

  @override
  List<Object?> get props => [
    type,
    name,
    amount,
    durationMonths,
    autoSave,
    frequency,
    contributionDays,
    fundingSource,
    memberCount,
    startDate,
  ];
}
