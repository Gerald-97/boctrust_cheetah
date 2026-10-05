import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../model/beneficiary_models.dart';
import '../model/interbank_models.dart';
import '../provider/core_payments_providers.dart';
import '../service/core_transfer_service.dart';
import 'core_flow_widgets.dart';

/// The Beneficiaries route: the saved list when the capability is
/// available, otherwise an explanation.
class BeneficiariesScreen extends ConsumerStatefulWidget {
  const BeneficiariesScreen({super.key});

  @override
  ConsumerState<BeneficiariesScreen> createState() =>
      _BeneficiariesScreenState();
}

class _BeneficiariesScreenState extends FlowPageState<BeneficiariesScreen> {
  @override
  Widget build(BuildContext context) => popScope(
    ref
            .watch(featureAvailabilityProvider(FeatureCapability.beneficiaries))
            .isAvailable
        ? BeneficiariesView(onBack: back, onSectionSelected: goSection)
        : unavailablePage(
            const UnavailableDestination(
              title: 'Beneficiaries',
              heading: 'Beneficiaries are unavailable',
              message: 'Saved beneficiaries are not available yet.',
              section: AppSection.account,
              capability: FeatureCapability.beneficiaries,
            ),
          ),
  );
}

/// The customer's saved bank accounts and biller customers.
class BeneficiariesView extends ConsumerStatefulWidget {
  const BeneficiariesView({
    required this.onBack,
    required this.onSectionSelected,
    super.key,
  });

  final VoidCallback onBack;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  ConsumerState<BeneficiariesView> createState() => _BeneficiariesViewState();
}

class _BeneficiariesViewState extends ConsumerState<BeneficiariesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(beneficiariesProvider.notifier).load());
    });
  }

  Future<void> _delete(Beneficiary beneficiary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove beneficiary?'),
        content: Text(
          '${beneficiary.nickname ?? beneficiary.name} will be '
          'removed from your saved list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error = await ref
        .read(beneficiariesProvider.notifier)
        .delete(beneficiary.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Beneficiary removed.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(beneficiariesProvider);
    final rows = state.data ?? const <Beneficiary>[];
    final banks = [
      for (final b in rows)
        if (b.type == BeneficiaryType.bankAccount) b,
    ];
    final billers = [
      for (final b in rows)
        if (b.type != BeneficiaryType.bankAccount) b,
    ];
    Widget tile(Beneficiary b, String detail) => SettingsTile(
      icon: b.type == BeneficiaryType.bankAccount
          ? IconsaxPlusLinear.bank
          : IconsaxPlusLinear.receipt_item,
      title: b.nickname ?? b.name,
      subtitle: '$detail · ${b.maskedNumber}',
      trailing: IconButton(
        tooltip: 'Remove',
        icon: const Icon(IconsaxPlusLinear.trash),
        onPressed: () => _delete(b),
      ),
    );
    return AppScaffold(
      title: 'Beneficiaries',
      activeSection: AppSection.account,
      onBack: widget.onBack,
      onSectionSelected: widget.onSectionSelected,
      body: RefreshIndicator(
        onRefresh: ref.read(beneficiariesProvider.notifier).load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(BocSpace.gutter).clearOfNav(context),
          children: [
            if (state.isLoading && state.data == null)
              const ApiLoadingSection(label: 'Loading beneficiaries'),
            if (state.isError)
              ApiStateCard(
                title: 'Beneficiaries unavailable',
                message: state.message ?? 'We could not load them.',
                tone: ApiStateTone.error,
                actionLabel: 'Retry',
                onAction: ref.read(beneficiariesProvider.notifier).load,
              ),
            if (state.isDone && rows.isEmpty)
              const ApiStateCard(
                title: 'No beneficiaries yet',
                message:
                    'Save a bank account here, or after a transfer or '
                    'bill payment.',
                tone: ApiStateTone.info,
              ),
            if (banks.isNotEmpty)
              SettingsGroup(
                caption: 'Bank accounts',
                padding: const EdgeInsets.only(bottom: BocSpace.md),
                children: [
                  for (final b in banks)
                    tile(b, b.bankName ?? b.bankCode ?? ''),
                ],
              ),
            if (billers.isNotEmpty)
              SettingsGroup(
                caption: 'Billers',
                padding: const EdgeInsets.only(bottom: BocSpace.md),
                children: [
                  for (final b in billers)
                    tile(b, b.paymentItemName ?? b.type?.wireValue ?? ''),
                ],
              ),
            const SizedBox(height: BocSpace.md),
            PrimaryButton(
              label: 'Add bank account',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const _AddBankBeneficiary(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saves a bank account after Core confirms its name.
class _AddBankBeneficiary extends ConsumerStatefulWidget {
  const _AddBankBeneficiary();

  @override
  ConsumerState<_AddBankBeneficiary> createState() =>
      _AddBankBeneficiaryState();
}

class _AddBankBeneficiaryState extends ConsumerState<_AddBankBeneficiary> {
  final _number = TextEditingController();
  final _nickname = TextEditingController();
  CommercialBank? _bank;
  String? _name;
  String? _error;
  bool _busy = false;
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(interbankBanksProvider).data == null) {
        unawaited(ref.read(interbankBanksProvider.notifier).load());
      }
    });
  }

  @override
  void dispose() {
    _number.dispose();
    _nickname.dispose();
    super.dispose();
  }

  void _changed() => setState(() {
    _lookup++;
    _name = null;
    _error = null;
    _busy = false;
  });

  Future<void> _check() async {
    final bank = _bank;
    if (bank == null) return;
    final lookup = ++_lookup;
    setState(() => _busy = true);
    final result = await ref
        .read(coreTransferServiceProvider)
        .nameEnquiry(bankCode: bank.code, accountNumber: _number.text.trim());
    if (!mounted || lookup != _lookup) return;
    setState(() {
      _busy = false;
      _name = result.data?.name;
      _error = _name == null ? "We couldn't find this account." : null;
    });
  }

  Future<void> _save() async {
    final bank = _bank;
    if (bank == null) return;
    setState(() => _busy = true);
    final error = await ref
        .read(beneficiariesProvider.notifier)
        .add(
          bankBeneficiaryRequest(
            bankCode: bank.code,
            number: _number.text.trim(),
            nickname: _nickname.text,
          ),
        );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final banks = ref.watch(interbankBanksProvider).data ?? const [];
    final ready =
        _bank != null && RegExp(r'^\d{10}$').hasMatch(_number.text.trim());
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(BocSpace.gutter),
        children: [
          const FlowHeading('Add bank account'),
          BankSelectorTile(
            bank: _bank,
            banks: banks,
            loading: ref.watch(interbankBanksProvider).isLoading,
            onSelected: (bank) {
              _changed();
              setState(() => _bank = bank);
            },
          ),
          const SizedBox(height: BocSpace.md),
          AppTextField(
            label: 'Account number',
            controller: _number,
            keyboardType: TextInputType.number,
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: BocSpace.sm),
          AppTextField(label: 'Nickname (optional)', controller: _nickname),
          if (_name != null) ...[
            const SizedBox(height: BocSpace.sm),
            ApiStateCard(
              title: _name!,
              message: _bank?.name ?? '',
              tone: ApiStateTone.info,
            ),
          ],
          if (_error != null) FieldError(_error!),
          const SizedBox(height: BocSpace.lg),
          PrimaryButton(
            label: _name == null ? 'Check account' : 'Save',
            isLoading: _busy,
            onPressed: !ready ? null : (_name == null ? _check : _save),
          ),
        ],
      ),
    );
  }
}
