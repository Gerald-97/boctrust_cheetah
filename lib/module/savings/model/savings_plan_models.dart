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

  /// Core moves this opening amount from Boc Flex when it creates a plan.
  int? get openingMinimumNaira => switch (this) {
    SavingsProductType.smartSave => 5000,
    SavingsProductType.fixed => 1000,
    SavingsProductType.flex || SavingsProductType.padi => null,
  };

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

int? _days(Object? value) => value is int && value > 0 ? value : null;

/// A customer's savings plan as Core reports it. Amounts are Naira decimal
/// strings; the client never computes balances or
/// interest.
class SavingsPlan extends Equatable {
  const SavingsPlan({
    required this.id,
    required this.type,
    required this.name,
    required this.status,
    this.principal,
    this.target,
    this.interestEarned,
    this.accruedInterest,
    this.earlyWithdrawalFeePercent,
    this.rate,
    this.tenorDays,
    this.maturityDate,
    this.startDate,
    this.saveFrequency,
    this.recurringAmount,
    this.projectedInterest,
  });

  final String id;
  final SavingsProductType type;
  final String name;

  /// Null when Core's amount cannot be read; the plan is still shown.
  final String? principal;
  final SavingsPlanStatus status;
  final String? target;
  final String? interestEarned;

  /// Interest accrued so far (Naira), paid on early withdrawal less the fee.
  final String? accruedInterest;

  /// The early-withdrawal fee on that interest, a percent as published.
  final String? earlyWithdrawalFeePercent;

  /// Percent, as published.
  final String? rate;
  final int? tenorDays;
  final DateTime? maturityDate;
  final DateTime? startDate;

  /// How often the customer chose to save; null when Core has none.
  final SavingsFrequency? saveFrequency;
  final String? recurringAmount;

  /// Core's estimate of the interest at maturity (Naira).
  final String? projectedInterest;

  /// A plan of a product this app knows, else null.
  static SavingsPlan? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = coreText(json['planId']);
    final type = SavingsProductType.fromCoreCode(json['productCode']);
    if (id == null || type == null) return null;
    return SavingsPlan(
      id: id,
      type: type,
      name: coreText(json['planName']) ?? type.displayName,
      principal: coreNaira(json['principalAmount']),
      status: SavingsPlanStatus.parse(json['status']),
      target: coreNaira(json['targetAmount']),
      interestEarned: coreNaira(json['interestEarned']),
      accruedInterest: coreNaira(json['accruedInterest']),
      earlyWithdrawalFeePercent: coreText(json['earlyWithdrawalFeePercent']),
      rate: coreText(json['currentInterestRatePercent']),
      tenorDays: _days(json['tenorDays']),
      maturityDate: DateTime.tryParse(coreText(json['maturityDate']) ?? ''),
      startDate: DateTime.tryParse(coreText(json['startDate']) ?? ''),
      saveFrequency: SavingsFrequency.values
          .asNameMap()[coreText(json['saveFrequency'])],
      recurringAmount: coreNaira(json['recurringAmount']),
      projectedInterest: coreNaira(json['projectedInterestAtMaturity']),
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
    accruedInterest,
    earlyWithdrawalFeePercent,
    rate,
    tenorDays,
    maturityDate,
    startDate,
    saveFrequency,
    recurringAmount,
    projectedInterest,
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
    this.rate,
    this.defaultTenorDays,
  });

  final SavingsProductType type;
  final String productName;
  final List<SavingsPlan> plans;

  /// The product's account. Its balance is read from the account list,
  /// whose unit is verified, not from this reply's `accountBalance`.
  final String? accountNumber;
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
      amount: coreNaira(json['amount']),
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

/// What Core reports after a plan action (top-up, early withdrawal,
/// creation). Amounts are Naira decimal strings; any may be absent.
class SavingsPlanActionResult extends Equatable {
  const SavingsPlanActionResult({
    required this.planId,
    required this.status,
    this.principalAmount,
    this.amountPaidOut,
    this.interestAccrued,
    this.earlyWithdrawalFee,
    this.interestPaid,
    this.interestPending,
  });

  final String planId;
  final SavingsPlanStatus status;
  final String? principalAmount;
  final String? amountPaidOut;
  final String? interestAccrued;
  final String? earlyWithdrawalFee;
  final String? interestPaid;
  final String? interestPending;

  /// Null when [json] is not an object or has no `planId`.
  static SavingsPlanActionResult? fromJson(Object? json) {
    if (json is! Map) return null;
    final planId = coreText(json['planId']);
    if (planId == null) return null;
    return SavingsPlanActionResult(
      planId: planId,
      status: SavingsPlanStatus.parse(json['status']),
      principalAmount: coreNaira(json['principalAmount']),
      amountPaidOut: coreNaira(json['amountPaidOut']),
      interestAccrued: coreNaira(json['interestAccrued']),
      earlyWithdrawalFee: coreNaira(json['earlyWithdrawalFee']),
      interestPaid: coreNaira(json['interestPaid']),
      interestPending: coreNaira(json['interestPending']),
    );
  }

  @override
  List<Object?> get props => [
    planId,
    status,
    principalAmount,
    amountPaidOut,
    interestAccrued,
    earlyWithdrawalFee,
    interestPaid,
    interestPending,
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

/// Core's tenor, in days, for each term the wizard offers. Core rejects a
/// tenor with no rate band for the product, and that message is shown.
const tenorDaysForMonths = {3: 90, 6: 180, 9: 270, 12: 365};

/// The largest amount a plan form accepts (in Kobo); Core enforces the real
/// limits.
const savingsPlanMaxKobo = '100000000000';

/// A typed Naira amount as Core's two-decimal string, or null when invalid.
String? savingsPlanNaira(String text) =>
    switch (parseNairaAmount(text, maxKobo: savingsPlanMaxKobo)) {
      ValidMoney(:final minorUnits) => minorUnits,
      InvalidMoney() => null,
    };

/// A SmartSave target must exceed the amount used to open the goal.
bool smartSaveTargetValid(String text) => switch (parseNairaToKobo(
  text,
  maxKobo: savingsPlanMaxKobo,
)) {
  ValidMoney(:final minorUnits) =>
    BigInt.parse(minorUnits) >
        BigInt.from(SavingsProductType.smartSave.openingMinimumNaira! * 100),
  InvalidMoney() => false,
};

/// The body of POST /me/savings-plans. Amounts are Naira strings; null
/// fields are left out.
class CreateSavingsPlanRequest extends Equatable {
  const CreateSavingsPlanRequest({
    required this.productCode,
    required this.tenorDays,
    this.planName,
    this.targetAmount,
    this.saveFrequency,
    this.recurringAmount,
  });

  final String productCode;
  final int tenorDays;
  final String? planName;
  final String? targetAmount;
  final SavingsFrequency? saveFrequency;
  final String? recurringAmount;

  Map<String, Object> toJson() => {
    'productCode': productCode,
    'tenorDays': tenorDays,
    'planName': ?planName,
    'targetAmount': ?targetAmount,
    'saveFrequency': ?saveFrequency?.name,
    'recurringAmount': ?recurringAmount,
  };

  @override
  List<Object?> get props => [
    productCode,
    tenorDays,
    planName,
    targetAmount,
    saveFrequency,
    recurringAmount,
  ];
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
    this.recurringAmount = '',
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

  /// SmartSave auto-save amount per save, as typed, in naira.
  final String recurringAmount;
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
    String? recurringAmount,
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
    recurringAmount: recurringAmount ?? this.recurringAmount,
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
    recurringAmount,
    fundingSource,
    memberCount,
    startDate,
  ];

  /// What Core needs to create this plan. Null for Flex and Padi, without a
  /// term, or when an amount cannot be read. Auto-save fields go only when
  /// auto-save is on.
  CreateSavingsPlanRequest? toCreateRequest() {
    final code = type.coreCode;
    final tenor = tenorDaysForMonths[durationMonths];
    if (code == null || tenor == null) return null;
    final planName = name.trim().isEmpty ? null : name.trim();
    switch (type) {
      case SavingsProductType.fixed:
        return CreateSavingsPlanRequest(
          productCode: code,
          tenorDays: tenor,
          planName: planName,
        );
      case SavingsProductType.smartSave:
        if (!smartSaveTargetValid(amount)) return null;
        final target = savingsPlanNaira(amount)!;
        if (!autoSave) {
          return CreateSavingsPlanRequest(
            productCode: code,
            tenorDays: tenor,
            planName: planName,
            targetAmount: target,
          );
        }
        final recurring = savingsPlanNaira(recurringAmount);
        if (frequency == null || recurring == null) return null;
        return CreateSavingsPlanRequest(
          productCode: code,
          tenorDays: tenor,
          planName: planName,
          targetAmount: target,
          saveFrequency: frequency,
          recurringAmount: recurring,
        );
      case SavingsProductType.flex || SavingsProductType.padi:
        return null;
    }
  }
}
