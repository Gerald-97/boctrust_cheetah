import 'package:equatable/equatable.dart';

import '../../../app/feature_capability.dart';
import '../../core_banking/model/core_json.dart';
import '../../core_banking/model/core_money.dart';

/// The four Boc savings products. Route paths keep their legacy names
/// (target, lock, group); these are the customer-facing names.
enum SavingsProductType {
  flex('Boc Flex Savings', null, null),
  smartSave('Boc SmartSave', FeatureCapability.smartSaveCreate, 'bocSmartSave'),
  fixed(
    'Boc Fixed Deposit',
    FeatureCapability.fixedDepositCreate,
    'boctrustFixedDeposit',
  ),
  padi('Boc Padi', FeatureCapability.padiCreate, null);

  const SavingsProductType(
    this.displayName,
    this.createCapability,
    this.coreCode,
  );

  final String displayName;

  /// Gates creating a new plan of this type; Flex has no create step.
  final FeatureCapability? createCapability;

  /// The Core `productCode` of a product with savings plans; Flex has no
  /// plans and Padi has no plan routes.
  final String? coreCode;

  static SavingsProductType? fromCoreCode(Object? code) {
    for (final type in values) {
      if (type.coreCode != null && type.coreCode == code) return type;
    }
    return null;
  }
}

enum SavingsFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly');

  const SavingsFrequency(this.label);
  final String label;
}

enum SavingsPlanStatus {
  pendingFunding('pending_funding', 'Awaiting funding'),
  active('active', 'Active'),
  matured('matured', 'Matured'),
  liquidated('liquidated', 'Withdrawn'),
  cancelled('cancelled', 'Cancelled'),

  /// A status this build does not know. Shown as unavailable.
  unknown('unknown', 'Unavailable');

  const SavingsPlanStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static SavingsPlanStatus parse(Object? value) {
    for (final status in values) {
      if (status != unknown && status.wireValue == value) return status;
    }
    return unknown;
  }
}

/// A whole Kobo amount sent as digits, as a Naira decimal string, else null.
/// Every amount on the savings-plan routes is Kobo.
String? _naira(Object? kobo) {
  final text = coreText(kobo);
  return text != null && RegExp(r'^\d+$').hasMatch(text)
      ? koboToNaira(text)
      : null;
}

int? _days(Object? value) => value is int && value > 0 ? value : null;

/// A customer's savings plan as Core reports it. Amounts are Naira decimal
/// strings converted from Kobo; the client never computes balances or
/// interest.
class SavingsPlan extends Equatable {
  const SavingsPlan({
    required this.id,
    required this.type,
    required this.name,
    required this.principal,
    required this.status,
    this.target,
    this.interestEarned,
    this.rate,
    this.tenorDays,
    this.maturityDate,
  });

  final String id;
  final SavingsProductType type;
  final String name;
  final String principal;
  final SavingsPlanStatus status;
  final String? target;
  final String? interestEarned;

  /// Percent, as published.
  final String? rate;
  final int? tenorDays;
  final DateTime? maturityDate;

  /// A plan of a product this app knows, else null.
  static SavingsPlan? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = coreText(json['planId']);
    final type = SavingsProductType.fromCoreCode(json['productCode']);
    final principal = _naira(json['principalAmount']);
    if (id == null || type == null || principal == null) return null;
    return SavingsPlan(
      id: id,
      type: type,
      name: coreText(json['planName']) ?? type.displayName,
      principal: principal,
      status: SavingsPlanStatus.parse(json['status']),
      target: _naira(json['targetAmount']),
      interestEarned: _naira(json['interestEarned']),
      rate: coreText(json['currentInterestRatePercent']),
      tenorDays: _days(json['tenorDays']),
      maturityDate: DateTime.tryParse(coreText(json['maturityDate']) ?? ''),
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    principal,
    status,
    target,
    interestEarned,
    rate,
    tenorDays,
    maturityDate,
  ];
}

/// One product's plans with the product's account balance, as grouped by
/// `GET /me/savings-plans`.
class SavingsProductGroup extends Equatable {
  const SavingsProductGroup({
    required this.type,
    required this.productName,
    required this.plans,
    this.accountNumber,
    this.balance,
    this.rate,
    this.defaultTenorDays,
  });

  final SavingsProductType type;
  final String productName;
  final List<SavingsPlan> plans;
  final String? accountNumber;

  /// The product account's balance. Core falls back to summed plan
  /// principal when the live balance fails, without saying so.
  final String? balance;
  final String? rate;
  final int? defaultTenorDays;

  static SavingsProductGroup? tryParse(Object? json) {
    if (json is! Map) return null;
    final type = SavingsProductType.fromCoreCode(json['productCode']);
    if (type == null) return null;
    final plans = json['plans'];
    return SavingsProductGroup(
      type: type,
      productName: coreText(json['productName']) ?? type.displayName,
      plans: List.unmodifiable(
        (plans is List ? plans : const [])
            .map(SavingsPlan.tryParse)
            .whereType<SavingsPlan>(),
      ),
      accountNumber: coreText(json['accountNumber']),
      balance: _naira(json['accountBalance']),
      rate: coreText(json['productInterestRatePercent']),
      defaultTenorDays: _days(json['defaultTenorDays']),
    );
  }

  /// Groups of known products, in server order.
  static List<SavingsProductGroup> listFromJson(Object? json) {
    if (json is! List) throw const FormatException('Missing savings plans.');
    return List.unmodifiable(
      json.map(tryParse).whereType<SavingsProductGroup>(),
    );
  }

  @override
  List<Object?> get props => [
    type,
    productName,
    plans,
    accountNumber,
    balance,
    rate,
    defaultTenorDays,
  ];
}

enum SavingsPlanEventType {
  created('created', 'Created'),
  topUp('top_up', 'Top-up'),
  interestCredit('interest_credit', 'Interest'),
  withdrawal('withdrawal', 'Withdrawal'),
  maturityPayout('maturity_payout', 'Maturity payout'),
  liquidation('liquidation', 'Early withdrawal'),
  unknown('unknown', 'Activity');

  const SavingsPlanEventType(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static SavingsPlanEventType parse(Object? value) {
    for (final type in values) {
      if (type != unknown && type.wireValue == value) return type;
    }
    return unknown;
  }
}

/// One entry in a plan's history. Its server reference is not kept.
class SavingsPlanEvent extends Equatable {
  const SavingsPlanEvent({required this.type, this.amount, this.createdAt});

  final SavingsPlanEventType type;
  final String? amount;
  final DateTime? createdAt;

  static SavingsPlanEvent? tryParse(Object? json) {
    if (json is! Map) return null;
    return SavingsPlanEvent(
      type: SavingsPlanEventType.parse(json['eventType']),
      amount: _naira(json['amount']),
      createdAt: DateTime.tryParse(coreText(json['createdAt']) ?? ''),
    );
  }

  @override
  List<Object?> get props => [type, amount, createdAt];
}

/// A plan with its history, from `GET /me/savings-plans/{planId}`.
class SavingsPlanDetail extends Equatable {
  const SavingsPlanDetail({required this.plan, this.events = const []});

  final SavingsPlan plan;
  final List<SavingsPlanEvent> events;

  factory SavingsPlanDetail.fromJson(Object? json) {
    final plan = SavingsPlan.tryParse(json);
    if (plan == null) throw const FormatException('Invalid savings plan.');
    final events = (json as Map)['events'];
    return SavingsPlanDetail(
      plan: plan,
      events: List.unmodifiable(
        (events is List ? events : const [])
            .map(SavingsPlanEvent.tryParse)
            .whereType<SavingsPlanEvent>(),
      ),
    );
  }

  @override
  List<Object?> get props => [plan, events];
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
