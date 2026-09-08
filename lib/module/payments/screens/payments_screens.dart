part of '../../app_flow/app_flow_navigator.dart';

extension PaymentsScreens on AppFlowNavigatorState {
  Widget _paymentsScreen() {
    return AppScaffold(
      title: 'Payments',
      activeSection: AppSection.payments,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: RegulatoryBadge(),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Send & receive'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: PaymentActionCard(
                    icon: Icons.send_rounded,
                    title: 'Send money',
                    subtitle: 'Transfer to any bank account',
                    color: BocColors.gold,
                    onTap: () => _go(AppScreen.sendHub),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PaymentActionCard(
                    icon: Icons.add_card_rounded,
                    title: 'Add money',
                    subtitle: 'Top up your wallet balance',
                    color: BocColors.blue,
                    onTap: () => _go(AppScreen.addMoney),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PaymentActionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan to pay',
              subtitle: 'Make a payment with a merchant QR',
              color: BocColors.purple,
              onTap: () => _go(AppScreen.scan),
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Bill payments'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ResponsiveTiles(
              minTileWidth: 72,
              spacing: 16,
              children: [
                BillGridItem(
                  icon: Icons.phone_android_rounded,
                  label: 'Airtime',
                  color: BocColors.gold,
                  onTap: () => _go(AppScreen.airtime),
                ),
                BillGridItem(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: 'Data',
                  color: BocColors.blue,
                  onTap: () => _go(AppScreen.data),
                ),
                BillGridItem(
                  icon: Icons.bolt_outlined,
                  label: 'Electricity',
                  color: BocColors.purple,
                  onTap: () => _openBillerCategory('electricity'),
                ),
                BillGridItem(
                  icon: Icons.water_drop_outlined,
                  label: 'Water',
                  color: BocColors.green,
                  onTap: () => _openBillerCategory('water'),
                ),
                BillGridItem(
                  icon: Icons.tv_outlined,
                  label: 'Cable TV',
                  color: BocColors.gold,
                  onTap: () => _openBillerCategory('cable'),
                ),
                BillGridItem(
                  icon: Icons.wifi_rounded,
                  label: 'Internet',
                  color: BocColors.blue,
                  onTap: () => _openBillerCategory('internet'),
                ),
                BillGridItem(
                  icon: Icons.school_outlined,
                  label: 'Education',
                  color: BocColors.purple,
                  onTap: () => _openBillerCategory('education'),
                ),
                BillGridItem(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  color: BocColors.green,
                  onTap: () => _openBillerCategory('more'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Recent transactions'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  TransactionTile(
                    icon: Icons.phone_android_rounded,
                    name: 'MTN Airtime — 0803 214 7756',
                    date: 'Today, 8:14 AM',
                    amount: '−₦2,000.00',
                  ),
                  Divider(height: 1),
                  TransactionTile(
                    icon: Icons.bolt_outlined,
                    name: 'EKEDC — Meter 04521187733',
                    date: 'Yesterday, 6:40 PM',
                    amount: '−₦15,000.00',
                  ),
                  Divider(height: 1),
                  TransactionTile(
                    icon: Icons.send_rounded,
                    name: 'Sent to Ifeoma Nwachukwu',
                    date: 'Mon, 4:20 PM',
                    amount: '−₦35,000.00',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanScreen() {
    return Scaffold(
      backgroundColor: BocColors.navy,
      appBar: AppBar(
        backgroundColor: BocColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Scan to pay'),
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          maxWidth: 560,
          child: ScrollableFill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: BocColors.goldLight,
                          width: 3,
                        ),
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.white24,
                        size: 140,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      "Point your camera at a merchant's QR code to pay instantly",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFC7D3E0), height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BocColors.goldLight,
                        side: const BorderSide(color: BocColors.goldLight),
                      ),
                      onPressed: () =>
                          _showMessage('Manual payment code entry opened.'),
                      child: const Text('Enter code manually'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _airtimeScreen() {
    return AppScaffold(
      title: 'Buy airtime',
      activeSection: AppSection.payments,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const NetworkSelector(selected: 0),
          const SizedBox(height: 18),
          const AppTextField(
            label: 'Phone number',
            initialValue: '0803 214 7756',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: true,
            onChanged: (_) {},
            title: const Text(
              'Save as beneficiary',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('For faster top-ups next time'),
          ),
          const SizedBox(height: 10),
          const AmountDisplay(
            amount: '2,000',
            subtitle: 'Instant delivery, no fees',
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Buy airtime',
            onPressed: () => _openAuth(
              const TransactionContext(
                amount: '₦2,000.00',
                description: 'MTN airtime for 0803 214 7756.',
                title: 'Airtime purchase successful',
                row1Label: 'Network',
                row1Value: 'MTN',
                row2Label: 'Phone number',
                row2Value: '0803 214 7756',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataScreen() {
    return AppScaffold(
      title: 'Buy data',
      activeSection: AppSection.payments,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const NetworkSelector(selected: 0),
          const SizedBox(height: 18),
          const AppTextField(
            label: 'Phone number',
            initialValue: '0803 214 7756',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 18),
          Text('Choose a plan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const DataPlanCard(
            name: '1GB · 30 days',
            price: '₦800',
            selected: false,
          ),
          const SizedBox(height: 10),
          const DataPlanCard(
            name: '3.5GB · 30 days',
            price: '₦1,500',
            selected: true,
          ),
          const SizedBox(height: 10),
          const DataPlanCard(
            name: '10GB · 30 days',
            price: '₦3,500',
            selected: false,
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Buy data bundle',
            onPressed: () => _openAuth(
              const TransactionContext(
                amount: '₦1,500.00',
                description: '3.5GB MTN data bundle for 0803 214 7756.',
                title: 'Data purchase successful',
                row1Label: 'Plan',
                row1Value: '3.5GB · 30 days',
                row2Label: 'Phone number',
                row2Value: '0803 214 7756',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billerListScreen() {
    final category = billerCategories[_selectedBillerCategory]!;
    return AppScaffold(
      title: category.title,
      activeSection: AppSection.payments,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: SearchField(hint: 'Search billers'),
          ),
          ...category.items.map(
            (item) => ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: RoundedIcon(icon: category.icon, color: category.tint),
              title: Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _selectBiller(_selectedBillerCategory, item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billPayScreen() {
    final category = billerCategories[_selectedBillerCategory]!;
    return AppScaffold(
      title: 'Pay a bill',
      activeSection: AppSection.payments,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          SurfaceCard(
            child: Row(
              children: [
                RoundedIcon(icon: category.icon, color: category.tint),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Biller',
                        style: TextStyle(
                          color: BocColors.inkSoft,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selectedBiller.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _selectedBiller.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: category.fieldLabel,
            initialValue: '04521187733',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.bocColors.greenPale,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: BocColors.green,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adaeze Okonkwo',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Prepaid meter confirmed',
                        style: TextStyle(fontSize: 11, color: BocColors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AmountDisplay(
            amount: '15,000',
            subtitle: 'Token delivered instantly via SMS',
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Pay bill',
            onPressed: () => _openAuth(
              TransactionContext(
                amount: '₦15,000.00',
                description:
                    'Paying ${_selectedBiller.name}. Token/confirmation delivered instantly.',
                title: 'Bill payment successful',
                row1Label: 'Biller',
                row1Value: _selectedBiller.name,
                row2Label: category.fieldLabel,
                row2Value: '04521187733',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
