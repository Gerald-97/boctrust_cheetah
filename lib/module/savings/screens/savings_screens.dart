import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/route_arguments.dart';
import '../../../app/services.dart';
import '../../../app/theme.dart';
import '../../../utils/input_formatters.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../core_banking/model/bank_product_models.dart';
import '../../core_banking/model/customer_bank_account_models.dart';
import '../../core_banking/model/flex_balance.dart';
import '../../core_banking/provider/core_account_providers.dart';
import '../../core_banking/screens/frozen_account_banner.dart';
import '../../home/model/user_home_model.dart';
import '../../home/provider/home_provider.dart';
import '../../home/screens/home_screen.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/flex_interest_models.dart';
import '../model/savings_plan_models.dart';
import '../provider/flex_interest_provider.dart';
import '../provider/savings_plan_action_provider.dart';
import '../provider/savings_plan_provider.dart';

import 'savings_plan_top_up_sheet.dart';
import 'savings_plan_widgets.dart';
import 'savings_plan_withdraw_sheet.dart';

part 'savings_plan_screens.dart';

/// Savings pages: Back with nothing beneath returns to the Savings hub, and
/// the hub to Home.
abstract class _SavingsPageState<W extends ConsumerStatefulWidget>
    extends FlowPageState<W> {
  @override
  void onNothingToPop() => goReplacing(AppRoutes.savingsHub);

  @override
  Widget build(BuildContext context) => popScope(buildPage(context));

  Widget buildPage(BuildContext context);
}

/// Hub and funding pages refresh the User Home aggregate on entry; funding
/// always, the others only when it has never loaded.
abstract class _HomeDataPageState<W extends ConsumerStatefulWidget>
    extends _SavingsPageState<W> {
  bool get _isFunding => false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(authSessionProvider);
    if (session == null || session.isExpired) return;
    if (!_isFunding &&
        ref.read(userHomeProvider).status != ServiceStatus.idle) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ref.read(authSessionProvider)?.accessToken == session.accessToken) {
        unawaited(ref.read(userHomeProvider.notifier).load());
      }
    });
  }
}

class SaveHubScreen extends ConsumerStatefulWidget {
  const SaveHubScreen({super.key});

  @override
  ConsumerState<SaveHubScreen> createState() => _SaveHubScreenState();
}

class _SaveHubScreenState extends _HomeDataPageState<SaveHubScreen> {
  @override
  Widget buildPage(BuildContext context) => _saveHubScreen();
}

class FlexScreen extends ConsumerStatefulWidget {
  const FlexScreen({super.key});

  @override
  ConsumerState<FlexScreen> createState() => _FlexScreenState();
}

class _FlexScreenState extends _HomeDataPageState<FlexScreen> {
  @override
  Widget buildPage(BuildContext context) => _flexScreen();
}

/// Bank-transfer funding details; also behind the Flex top-up route.
class AddMoneyScreen extends ConsumerStatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  ConsumerState<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends _HomeDataPageState<AddMoneyScreen> {
  @override
  bool get _isFunding => true;

  @override
  Widget buildPage(BuildContext context) => _addMoneyScreen();
}

/// Target and Fixed Deposit plans from Core; Group savings has no plan
/// routes yet.
class SavingsProductScreen extends ConsumerStatefulWidget {
  const SavingsProductScreen.target({super.key})
    : title = 'Target Savings',
      type = SavingsProductType.smartSave;
  const SavingsProductScreen.lock({super.key})
    : title = 'Fixed Deposit',
      type = SavingsProductType.fixed;
  const SavingsProductScreen.group({super.key})
    : title = 'Group Savings',
      type = SavingsProductType.padi;

  final String title;
  final SavingsProductType type;

  @override
  ConsumerState<SavingsProductScreen> createState() =>
      _SavingsProductScreenState();
}

class _SavingsProductScreenState
    extends _SavingsPageState<SavingsProductScreen> {
  @override
  Widget buildPage(BuildContext context) =>
      widget.type.coreCode != null &&
          ref
              .watch(
                featureAvailabilityProvider(FeatureCapability.savingsPlansView),
              )
              .isAvailable
      ? _savingsPlansScreen(widget.type, widget.title)
      : _savingsUnavailableScreen(
          capability: FeatureCapability.savingsPlansView,
          title: widget.title,
          message: '${widget.title} is unavailable in this release.',
        );
}

class SavingsPlanDetailScreen extends ConsumerStatefulWidget {
  const SavingsPlanDetailScreen({super.key});

  @override
  ConsumerState<SavingsPlanDetailScreen> createState() =>
      _SavingsPlanDetailScreenState();
}

class _SavingsPlanDetailScreenState
    extends _SavingsPageState<SavingsPlanDetailScreen> {
  @override
  Widget buildPage(BuildContext context) => _savingsPlanDetailScreen();
}

/// The create wizard for SmartSave, Fixed Deposit or Padi.
class PlanCreationScreen extends ConsumerStatefulWidget {
  const PlanCreationScreen.smartSave({super.key})
    : type = SavingsProductType.smartSave;
  const PlanCreationScreen.fixed({super.key}) : type = SavingsProductType.fixed;
  const PlanCreationScreen.padi({super.key}) : type = SavingsProductType.padi;

  final SavingsProductType type;

  @override
  ConsumerState<PlanCreationScreen> createState() => _PlanCreationScreenState();
}

class _PlanCreationScreenState extends _SavingsPageState<PlanCreationScreen> {
  @override
  Widget buildPage(BuildContext context) => _planCreationScreen(widget.type);
}

extension SavingsScreens on FlowPageState {
  Future<void> _refreshSavings() async {
    await Future.wait([
      ref.read(userHomeProvider.notifier).load(),
      ref.read(customerBankAccountsProvider.notifier).load(),
      ref.read(coreBankProductsProvider.notifier).load(),
    ]);
    ref.invalidate(savingsPlansProvider);
  }

  /// Starts the Core account and product reads the first time a savings
  /// screen needs them.
  NotifierState<CustomerBankAccountsData> _watchCoreAccounts() {
    final accounts = ref.watch(customerBankAccountsProvider);
    if (accounts.status == ServiceStatus.idle &&
        ref.read(authSessionProvider) != null) {
      Future<void>.microtask(
        ref.read(customerBankAccountsProvider.notifier).load,
      );
    }
    return accounts;
  }

  /// The User Service Home aggregate, whose Flex wallet and catalogue cover
  /// customers Core has not opened accounts for yet.
  NotifierState<UserHomeData> _watchUserHome() {
    final home = ref.watch(userHomeProvider);
    if (home.status == ServiceStatus.idle &&
        ref.read(authSessionProvider) != null) {
      Future<void>.microtask(ref.read(userHomeProvider.notifier).load);
    }
    return home;
  }

  NotifierState<List<CoreBankProduct>> _watchCoreProducts() {
    final products = ref.watch(coreBankProductsProvider);
    if (products.status == ServiceStatus.idle &&
        ref.read(authSessionProvider) != null) {
      Future<void>.microtask(ref.read(coreBankProductsProvider.notifier).load);
    }
    return products;
  }

  /// Loading and failure notice for the Core balances. A failed refresh keeps
  /// the last good balances visible beside it.
  List<Widget> _coreAccountsStatus(
    NotifierState<CustomerBankAccountsData> accounts,
  ) => [
    if (accounts.data == null &&
        (accounts.isLoading || accounts.status == ServiceStatus.idle)) ...[
      const SavingsAccountSkeleton(),
      const SizedBox(height: 12),
    ],
    if (accounts.isError || accounts.status == ServiceStatus.blocked) ...[
      ApiStateCard(
        title: accounts.data == null
            ? 'Unable to load your accounts'
            : 'Refresh failed',
        message: accounts.data == null
            ? accounts.message ?? 'Please try again to load your accounts.'
            : 'Showing previously loaded balances. Refresh to check for '
                  'updates.',
        tone: ApiStateTone.warning,
        actionLabel: 'Retry',
        onAction: _refreshSavings,
      ),
      const SizedBox(height: 12),
    ],
  ];

  /// The account's number while Core reports it frozen, otherwise null.
  String? _frozenAccountNumber(String? accountNumber) {
    final accounts = _watchCoreAccounts().data?.accounts;
    return accounts
        ?.where(
          (account) =>
              account.accountNumber == accountNumber &&
              account.status == CoreAccountStatus.frozen,
        )
        .firstOrNull
        ?.accountNumber;
  }

  String _accountStatusLabel(CoreAccountStatus status) => switch (status) {
    CoreAccountStatus.active => 'Active',
    CoreAccountStatus.frozen => 'Frozen',
    CoreAccountStatus.closed => 'Closed',
    CoreAccountStatus.unknown => 'Unavailable',
  };

  /// Only show a count after Core has returned a plan list for this account.
  int? _createdPlanCount(SavingsProductType type, String accountNumber) {
    final result = switch (ref.watch(savingsPlansProvider(type))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (result == null) return null;
    if (result.status == ServiceStatus.empty) return 0;
    if (!result.isDone || result.data == null) return null;

    final groups = result.data!.where((group) => group.type == type).toList();
    if (groups.isEmpty) return 0;
    final matching = groups
        .where((group) => group.accountNumber == accountNumber)
        .toList();
    if (matching.isNotEmpty) {
      return matching.fold<int>(
        0,
        (count, group) => count + group.plans.length,
      );
    }
    if (groups.length == 1 && groups.single.accountNumber == null) {
      return groups.single.plans.length;
    }
    return null;
  }

  /// One owned Core account other than Flex, with its published product facts.
  /// A plan product's account opens its plans; any other its account detail.
  Widget _coreAccountTile(
    CustomerBankAccount account, {
    required bool hidden,
    CoreBankProduct? product,
  }) {
    final colors = context.bocColors;
    final type =
        SavingsProductType.fromCoreCode(account.productCode) ??
        (product == null ? null : _planTypeFor(product)) ??
        (account.productName.toLowerCase().contains('padi')
            ? SavingsProductType.padi
            : null);
    final rate = product?.interestRate;
    final balance = formatApiAmount(account.availableBalance, currency: 'NGN');
    bool available(FeatureCapability capability) =>
        ref.watch(featureAvailabilityProvider(capability)).isAvailable;
    final plansRoute = available(FeatureCapability.savingsPlansView)
        ? switch (SavingsProductType.fromCoreCode(account.productCode)) {
            SavingsProductType.smartSave => AppRoutes.targetSave,
            SavingsProductType.fixed => AppRoutes.lockSave,
            _ => null,
          }
        : null;
    final createdItemCount = plansRoute == null
        ? null
        : _createdPlanCount(type!, account.accountNumber);
    return OwnedSavingsTile(
      title: account.productName,
      balance: balance,
      hidden: hidden,
      accountNumber:
          type == SavingsProductType.smartSave ||
              type == SavingsProductType.fixed
          ? null
          : account.accountNumber,
      status: _accountStatusLabel(account.status),
      icon: switch (type) {
        SavingsProductType.smartSave => IconsaxPlusLinear.flag,
        SavingsProductType.fixed => IconsaxPlusLinear.lock,
        SavingsProductType.padi => IconsaxPlusLinear.profile_2user,
        _ => IconsaxPlusLinear.save_2,
      },
      accent: type == null ? colors.goldStrong : _productAccent(type),
      container: type == null ? colors.goldPale : _productContainer(type),
      rate: rate == null ? null : _formatRate(rate),
      tenureDays: product?.tenureDays,
      createdItemCount: createdItemCount,
      createdItemLabel: switch (type) {
        SavingsProductType.smartSave => 'goal',
        SavingsProductType.fixed => 'deposit',
        _ => null,
      },
      onTap: plansRoute != null
          ? () => go(plansRoute)
          : available(FeatureCapability.coreAccountActivity)
          ? () => go(
              AppRoutes.bankAccountDetail,
              arguments: AppRouteArguments(entityId: account.accountNumber),
            )
          : null,
    );
  }

  List<Widget> _savingsLoadStatus(NotifierState<UserHomeData> home) => [
    if (home.isLoading || home.status == ServiceStatus.idle) ...[
      if (home.data == null)
        const AppShimmerBlock(width: 180, height: 16)
      else
        const LinearProgressIndicator(),
      const SizedBox(height: 12),
      Text(
        home.data == null
            ? 'Loading account details…'
            : 'Refreshing account details…',
      ),
      const SizedBox(height: 12),
    ],
    if (home.isError) ...[
      ApiStateCard(
        title: home.data == null
            ? 'Unable to load account details'
            : 'Refresh failed',
        message: home.data == null
            ? 'Please try again to load your account details.'
            : 'Showing previously loaded details. Refresh to check for updates.',
        tone: ApiStateTone.warning,
        actionLabel: 'Retry',
        onAction: _refreshSavings,
      ),
      const SizedBox(height: 12),
    ],
  ];

  Widget _savingsRefreshAction(NotifierState<UserHomeData> home) => IconButton(
    tooltip: 'Refresh',
    onPressed: home.isLoading ? null : _refreshSavings,
    icon: _refreshIcon(home.isLoading),
  );

  Widget _refreshIcon(bool loading) => loading
      ? SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        )
      : const Icon(IconsaxPlusLinear.refresh);

  Widget _saveHubScreen() {
    final accountsState = _watchCoreAccounts();
    final productsState = _watchCoreProducts();
    final homeState = _watchUserHome();
    final accounts = accountsState.data;
    final flex = resolveFlexBalance(
      core: accounts,
      wallet: homeState.data?.flexWallet,
    );
    final userCatalogue = CoreBankProduct.listFromJson(
      homeState.data?.savingsProducts ?? const [],
    );
    // Core and User Home may publish different subsets. Keep Core's product
    // facts when both publish the same code, while still showing products
    // that only the User catalogue contains.
    final productsByCode = <String, CoreBankProduct>{
      for (final product in productsState.data ?? const <CoreBankProduct>[])
        product.code: product,
    };
    for (final product in userCatalogue) {
      productsByCode.putIfAbsent(product.code, () => product);
    }
    final catalogue = productsByCode.values.toList(growable: false);
    final flexProduct = catalogue
        .where((product) => product.code == kFlexProductCode)
        .firstOrNull;
    final flexRate = flexProduct?.interestRate;
    final hidden = ref.watch(homeBalanceHiddenProvider);
    final otherAccounts = [
      for (final account in accounts?.accounts ?? const <CustomerBankAccount>[])
        if (account.productCode != kFlexProductCode) account,
    ];
    final ownedCodes = {
      for (final account in accounts?.accounts ?? const <CustomerBankAccount>[])
        account.productCode,
      if (flex != null) kFlexProductCode,
    };
    // The two APIs can publish only Flex for a customer before their first
    // plan. These are the four app products, independent of account opening;
    // published facts enrich a card when the corresponding code is present.
    final otherProducts = [
      for (final type in SavingsProductType.values)
        if (type != SavingsProductType.flex &&
            !ownedCodes.contains(_catalogueCodeFor(type)))
          productsByCode[_catalogueCodeFor(type)] ??
              CoreBankProduct(
                code: _catalogueCodeFor(type),
                name: type.displayName,
              ),
    ];
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Save',
      activeSection: AppSection.save,
      onSectionSelected: goSection,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: accountsState.isLoading ? null : _refreshSavings,
          icon: _refreshIcon(accountsState.isLoading),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refreshSavings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            BocSpace.xxs,
            BocSpace.gutter,
            BocSpace.lg,
          ).clearOfNav(context),
          children: [
            // Core problems only matter while Core is the balance source.
            if (flex?.isCoreAccount ?? true)
              ..._coreAccountsStatus(accountsState),
            if (flex != null || otherAccounts.isNotEmpty) ...[
              Semantics(
                header: true,
                child: Text('Your savings', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: BocSpace.sm),
            ],
            if (flex != null)
              FlexSavingsTile(
                title:
                    flex.productName ?? flexProduct?.name ?? 'Boc Flex Savings',
                balance: formatApiAmount(
                  flex.availableBalance,
                  currency: 'NGN',
                ),
                hidden: hidden,
                accountNumber: flex.accountNumber,
                rate: flexRate == null ? null : _formatRate(flexRate),
                frozen: flex.isFrozen,
                onTap: () => go(AppRoutes.flexSave),
              )
            else if (accounts != null || homeState.data != null)
              const ApiStateCard(
                title: 'Flex account unavailable',
                message: 'Your Flex account will appear here when available.',
                tone: ApiStateTone.info,
              ),
            if (flex != null && flex.isFrozen && flex.accountNumber != null)
              FrozenAccountBanner(
                accountNumber: flex.accountNumber!,
                message:
                    'Your Boc Flex account is frozen. Transfers and other '
                    'outgoing payments are paused.',
              ),
            for (final account in otherAccounts) ...[
              const SizedBox(height: BocSpace.sm),
              _coreAccountTile(
                account,
                hidden: hidden,
                product: catalogue
                    .where((p) => p.code == account.productCode)
                    .firstOrNull,
              ),
              if (account.status == CoreAccountStatus.frozen)
                FrozenAccountBanner(
                  accountNumber: account.accountNumber,
                  message:
                      'Your ${account.productName} account is frozen. '
                      'Withdrawals are paused.',
                ),
            ],
            if (otherProducts.isNotEmpty) ...[
              const SizedBox(height: BocSpace.lg),
              Semantics(
                header: true,
                child: Text(
                  'Savings products',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: BocSpace.sm),
              if (productsState.isError && userCatalogue.isEmpty) ...[
                ApiStateCard(
                  title: 'Product details could not be refreshed',
                  message: productsState.message ?? 'Please try again.',
                  tone: ApiStateTone.warning,
                  actionLabel: 'Retry',
                  onAction: _refreshSavings,
                ),
                const SizedBox(height: BocSpace.sm),
              ],
              for (final (index, product) in otherProducts.indexed) ...[
                if (index > 0) const SizedBox(height: BocSpace.sm),
                _bankProductCard(product),
              ],
            ],
            const SizedBox(height: BocSpace.lg),
            const RegulatoryBadge(),
          ],
        ),
      ),
    );
  }

  /// Padi is published in the catalogue but has no customer plan routes yet.
  String _catalogueCodeFor(SavingsProductType type) =>
      type == SavingsProductType.padi ? 'bocPadi' : type.coreCode!;

  /// Matches a published product with a supported Save page.
  SavingsProductType? _planTypeFor(CoreBankProduct product) {
    if (product.isFixedDeposit) return SavingsProductType.fixed;
    final key = '${product.code} ${product.name}'.toLowerCase();
    if (key.contains('smart')) return SavingsProductType.smartSave;
    if (key.contains('padi')) return SavingsProductType.padi;
    if (key.contains('fixed')) return SavingsProductType.fixed;
    return null;
  }

  Widget _bankProductCard(CoreBankProduct product) {
    final colors = context.bocColors;
    final type = product.code == kFlexProductCode
        ? SavingsProductType.flex
        : SavingsProductType.fromCoreCode(product.code) ??
              _planTypeFor(product);
    return BankProductCard(
      title: product.name,
      description: type == SavingsProductType.padi
          ? 'Coming soon'
          : product.description,
      icon: switch (type) {
        SavingsProductType.smartSave => IconsaxPlusLinear.flag,
        SavingsProductType.fixed => IconsaxPlusLinear.lock,
        SavingsProductType.padi => IconsaxPlusLinear.profile_2user,
        _ => IconsaxPlusLinear.save_2,
      },
      accent: type == null ? colors.goldStrong : _productAccent(type),
      container: type == null ? colors.goldPale : _productContainer(type),
      facts: [
        if (type != SavingsProductType.padi) ...[
          if (product.interestRate case final rate?)
            (
              icon: IconsaxPlusLinear.percentage_circle,
              label: '${_formatRate(rate)}% p.a.',
            ),
          if (product.tenureDays case final days?)
            (
              icon: IconsaxPlusLinear.calendar_1,
              label: days == 1 ? '1-day tenure' : '$days-day tenure',
            ),
        ],
      ],
      onTap: switch (type) {
        SavingsProductType.smartSave => () => go(AppRoutes.targetSave),
        SavingsProductType.fixed => () => go(AppRoutes.lockSave),
        _ => null,
      },
    );
  }

  /// A published rate as written, without float noise: 7 → "7", 7.5 → "7.5".
  String _formatRate(num rate) {
    final fixed = rate.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  bool _canCreatePlan(SavingsProductType type) {
    final capability = type.createCapability;
    return capability != null &&
        ref.read(featureAvailabilityProvider(capability)).isAvailable;
  }

  /// Opens a product's creation wizard once it can be created; until then
  /// the customer learns that up front instead of after filling a form.
  Future<void> _startPlanCreation(SavingsProductType type) async {
    if (!_canCreatePlan(type)) {
      await BocUnavailableSheet.show(
        context,
        title: '${type.displayName} is not available yet',
      );
      return;
    }
    go(switch (type) {
      SavingsProductType.fixed => AppRoutes.lockCreate,
      SavingsProductType.padi => AppRoutes.groupCreate,
      _ => AppRoutes.targetSaveCreate,
    });
  }

  /// Deep links to a create route show the wizard only for a product that
  /// can be created.
  Widget _planCreationScreen(SavingsProductType type) {
    if (_canCreatePlan(type)) {
      return _SavingsPlanWizard(
        type: type,
        onExit: back,
        // The finished wizard leaves the stack, so Back from the new plan
        // skips it.
        onCreated: (planId) => goReplacing(
          AppRoutes.savingsPlanDetail,
          arguments: AppRouteArguments(entityId: planId),
        ),
      );
    }
    return _savingsUnavailableScreen(
      capability: type.createCapability!,
      title: type.displayName,
      message: '${type.displayName} is not available yet.',
    );
  }

  Widget _addMoneyScreen() {
    final home = ref.watch(userHomeProvider);
    return AppScaffold(
      title: 'Add money',
      activeSection: AppSection.payments,
      onBack: back,
      onSectionSelected: goSection,
      actions: [_savingsRefreshAction(home)],
      body: RefreshIndicator(
        onRefresh: _refreshSavings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
          children: [
            ..._savingsLoadStatus(home),
            if (home.data != null || home.isDone)
              dedicatedVirtualAccountCard(home.data?.dedicatedVirtualAccount),
          ],
        ),
      ),
    );
  }

  Widget _flexScreen() {
    final accountsState = _watchCoreAccounts();
    final homeState = _watchUserHome();
    final flex = resolveFlexBalance(
      core: accountsState.data,
      wallet: homeState.data?.flexWallet,
    );
    final hidden = ref.watch(homeBalanceHiddenProvider);
    final canWithdraw = ref
        .watch(featureAvailabilityProvider(FeatureCapability.flexWithdraw))
        .isAvailable;
    final ledger = formatApiAmount(flex?.ledgerBalance, currency: 'NGN');
    // A Core Flex account refreshes on its own; the User wallet needs Home.
    final coreAccountNumber = flex?.accountNumber;
    Future<void> refresh() => coreAccountNumber == null
        ? _refreshSavings()
        : ref
              .read(customerBankAccountsProvider.notifier)
              .refreshAccount(coreAccountNumber);
    return AppScaffold(
      title: 'Boc Flex Savings',
      activeSection: AppSection.save,
      onBack: back,
      onSectionSelected: goSection,
      actions: [
        if (coreAccountNumber != null &&
            ref
                .watch(
                  featureAvailabilityProvider(
                    FeatureCapability.coreAccountActivity,
                  ),
                )
                .isAvailable)
          IconButton(
            tooltip: 'Account details',
            onPressed: () => go(AppRoutes.flexStatement),
            icon: const Icon(IconsaxPlusLinear.document_text),
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed:
              (coreAccountNumber == null
                  ? homeState.isLoading || accountsState.isLoading
                  : accountsState.isLoading)
              ? null
              : refresh,
          icon: _refreshIcon(
            coreAccountNumber == null
                ? homeState.isLoading || accountsState.isLoading
                : accountsState.isLoading,
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            0,
            BocSpace.gutter,
            BocSpace.lg,
          ).clearOfNav(context),
          children: [
            if (flex?.isCoreAccount ?? true)
              ..._coreAccountsStatus(accountsState),
            if ((accountsState.data != null || homeState.data != null) &&
                flex == null)
              const ApiStateCard(
                title: 'Flex account unavailable',
                message:
                    'Your Flex account is unavailable right now. Refresh to '
                    'try again.',
                tone: ApiStateTone.info,
              ),
            if (flex != null)
              FlexHeroCard(
                balance: formatApiAmount(
                  flex.availableBalance,
                  currency: 'NGN',
                ),
                hidden: hidden,
                onToggle: () =>
                    ref.read(homeBalanceHiddenProvider.notifier).toggle(),
                primary: PrimaryButton(
                  label: 'Add money',
                  onPressed: () => go(AppRoutes.addMoney),
                ),
                secondary: canWithdraw
                    ? SecondaryButton(label: 'Withdraw', onPressed: () {})
                    : null,
              ),
            if (flex != null && flex.isFrozen && flex.accountNumber != null)
              FrozenAccountBanner(
                accountNumber: flex.accountNumber!,
                message:
                    'Your Boc Flex account is frozen. Transfers and other '
                    'outgoing payments are paused.',
              ),
            if (flex != null) ..._flexInterestSection(hidden),
            // Only an active Flex account is shown, so no status row is needed.
            if (flex != null && ledger != null) ...[
              const SizedBox(height: BocSpace.sm),
              GridViewInfo(
                items: [
                  (
                    label: 'Ledger balance',
                    value: hidden ? '₦ ••••••' : ledger,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The interest card under the balance. No Flex account (404) shows
  /// nothing; other failures show a compact retry card.
  List<Widget> _flexInterestSection(bool hidden) {
    if (!ref
        .watch(featureAvailabilityProvider(FeatureCapability.flexInterestView))
        .isAvailable) {
      return const [];
    }
    final state = ref.watch(flexInterestProvider);
    final FlexInterest? interest = state.value?.data;
    final widgets = switch (state) {
      _ when interest != null => [
        FlexInterestCard(
          interest: interest,
          hidden: hidden,
          onHistory: () => go(AppRoutes.interestHistory),
        ),
      ],
      AsyncData(:final value) when value.statusCode == 404 => <Widget>[],
      AsyncData(:final value) => [
        ApiStateCard(
          title: 'Interest unavailable',
          message: value.message ?? "We couldn't load your interest.",
          tone: ApiStateTone.error,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(flexInterestProvider),
        ),
      ],
      AsyncError() => [
        ApiStateCard(
          title: 'Interest unavailable',
          message: "We couldn't load your interest.",
          tone: ApiStateTone.error,
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(flexInterestProvider),
        ),
      ],
      _ => <Widget>[],
    };
    return [
      if (widgets.isNotEmpty) const SizedBox(height: BocSpace.sm),
      ...widgets,
    ];
  }

  Widget _savingsUnavailableScreen({
    required FeatureCapability capability,
    required String title,
    required String message,
  }) => unavailablePage(
    UnavailableDestination(
      title: title,
      heading: 'Unavailable',
      message: message,
      section: AppSection.save,
      capability: capability,
    ),
  );
}

/// Interest earned on the Flex account: this month's accrual (paid on the 1st
/// of next month) and the total paid so far.
class FlexInterestCard extends StatelessWidget {
  const FlexInterestCard({
    required this.interest,
    required this.hidden,
    this.onHistory,
    super.key,
  });

  final FlexInterest interest;
  final bool hidden;

  /// Opens the daily history; null hides the action.
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? money(String? amount) {
      final text = formatApiAmount(amount, currency: 'NGN');
      return text == null ? null : (hidden ? '₦ ••••••' : text);
    }

    final rate = interest.ratePercent;
    final month = money(interest.currentMonthAccruedInterest);
    final total = money(interest.totalInterestEarned);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Interest', style: theme.textTheme.titleSmall),
            ),
            if (rate != null)
              Text('$rate% p.a.', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: BocSpace.xs),
        GridViewInfo(
          items: [
            if (month != null) (label: 'This month so far', value: month),
            if (total != null) (label: 'Total interest earned', value: total),
          ],
        ),
        if (onHistory != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onHistory,
              child: const Text('Interest history'),
            ),
          ),
      ],
    );
  }
}
