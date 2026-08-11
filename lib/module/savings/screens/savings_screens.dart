part of '../../app_flow/app_flow_navigator.dart';

extension SavingsScreens on AppFlowNavigatorState {
  Widget _saveHubScreen() {
    return AppScaffold(
      title: 'Savings',
      activeSection: AppSection.save,
      onSectionSelected: _goSection,
      actions: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: BocColors.navy,
          ),
          onPressed: () => _go(AppScreen.target),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            'Choose a way to save',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ProductTile(
            icon: Icons.savings_outlined,
            title: 'Boc Flex Savings',
            subtitle: 'No lock-in — daily interest, withdraw anytime',
            color: BocColors.gold,
            onTap: () => _go(AppScreen.flex),
          ),
          ProductTile(
            icon: Icons.track_changes_rounded,
            title: 'Boctrust Target Savings',
            subtitle: 'Daily, weekly or monthly auto-save toward a goal',
            color: BocColors.blue,
            onTap: () => _go(AppScreen.target),
          ),
          ProductTile(
            icon: Icons.lock_outline_rounded,
            title: 'Boctrust Fixed Deposit',
            subtitle: 'Fixed term, higher rate, locked until maturity',
            color: BocColors.purple,
            onTap: () => _go(AppScreen.lock),
          ),
          ProductTile(
            icon: Icons.groups_outlined,
            title: 'Boctrust Group Savings',
            subtitle: 'Save together with friends, family or colleagues',
            color: BocColors.green,
            onTap: () => _go(AppScreen.group),
          ),
          const SizedBox(height: 14),
          Text(
            'Your active plans',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ActivePlanCard(
            metric: '12.5%',
            name: 'Everyday Flex',
            subtitle: 'Flex · daily interest',
            amount: '₦420,180 balance',
            color: BocColors.gold,
            onTap: () => _go(AppScreen.flex),
          ),
          const SizedBox(height: 12),
          ActivePlanCard(
            metric: '57%',
            name: 'Rent — Dec 2026',
            subtitle: 'Target · weekly',
            amount: '₦570,000 of ₦1,000,000',
            color: BocColors.purple,
            onTap: () => _go(AppScreen.target),
          ),
        ],
      ),
    );
  }

  Widget _addMoneyScreen() {
    return AppScaffold(
      title: 'Add money',
      activeSection: AppSection.payments,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const RegulatoryBadge(),
          const SizedBox(height: 20),
          const AmountDisplay(
            amount: '50,000',
            subtitle: 'To your Boc Flex Savings balance',
          ),
          const SizedBox(height: 10),
          MoneyKeypad(onKey: (_) {}, onBackspace: () {}),
          const SizedBox(height: 16),
          Text('Fund from', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ProductTile(
            icon: Icons.account_balance_outlined,
            title: 'Bank transfer',
            subtitle: 'Get a dedicated virtual account number',
            color: BocColors.blue,
            onTap: () => _showMessage('Virtual account details opened.'),
          ),
          ProductTile(
            icon: Icons.credit_card_outlined,
            title: 'Debit card',
            subtitle: 'Instant, using a card on file',
            color: BocColors.gold,
            onTap: () => _showMessage('Card funding selected.'),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Continue',
            onPressed: () => _openAuth(
              const TransactionContext(
                amount: '₦50,000.00',
                description: 'Adding money to Everyday Flex.',
                title: 'Money added successfully',
                row1Label: 'Destination',
                row1Value: 'Everyday Flex',
                row2Label: 'Funding source',
                row2Value: 'Debit card',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flexScreen() {
    return AppScaffold(
      title: 'Boc Flex Savings',
      activeSection: AppSection.save,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SavingsHeroCard(
            rate: '12.5% p.a. · paid daily',
            amount: '₦420,180.10',
            growth: 'Grew by ₦2,940 this month',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Add money',
                    onPressed: () => _go(AppScreen.addMoney),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showMessage('Withdrawal flow opened.'),
                    child: const Text('Withdraw'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: InfoBanner(
              text:
                  'Interest accrues every night and is added automatically — no lock-in, no penalties.',
              value: '₦412 /day',
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: GridViewInfo(
              items: [
                ('Deposits', 'Unlimited, free'),
                ('Withdrawals', 'Anytime, instant'),
                ('Minimum balance', '₦0'),
                ("This month's interest", '₦8,940.55'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Interest history', action: 'Statement'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  TransactionTile(
                    icon: Icons.trending_up_rounded,
                    name: 'Daily interest',
                    date: '22 Jul 2026',
                    amount: '+₦412.60',
                    incoming: true,
                  ),
                  Divider(height: 1),
                  TransactionTile(
                    icon: Icons.trending_up_rounded,
                    name: 'Daily interest',
                    date: '21 Jul 2026',
                    amount: '+₦408.30',
                    incoming: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetScreen() {
    return AppScaffold(
      title: 'Boctrust Target Savings',
      activeSection: AppSection.save,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your goals',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.sort_rounded, size: 17),
                label: const Text('Sort'),
              ),
            ],
          ),
          const GoalCard(
            progress: 0.57,
            name: 'Rent — Dec 2026',
            frequency: 'Weekly · ₦25,000',
            amount: '₦570,000 of ₦1,000,000',
          ),
          const SizedBox(height: 10),
          const GoalCard(
            progress: 0.28,
            name: 'New MacBook',
            frequency: 'Monthly · ₦45,000',
            amount: '₦258,530 of ₦950,000',
          ),
          const SizedBox(height: 10),
          const GoalCard(
            progress: 0.14,
            name: 'School fees — Jan',
            frequency: 'Daily · ₦1,500',
            amount: '₦42,000 of ₦300,000',
          ),
          const SizedBox(height: 22),
          Text(
            'Start a new goal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const SurfaceCard(
            child: Column(
              children: [
                AppTextField(
                  label: 'Goal name',
                  hintText: 'e.g. Japa fund, Wedding, Rent',
                ),
                SizedBox(height: 12),
                AppTextField(
                  label: 'Target amount',
                  hintText: '₦0.00',
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SAVE FREQUENCY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: BocColors.inkSoft,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                FrequencySelector(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Create target & set auto-save',
            onPressed: () => _showMessage('New target created.'),
          ),
        ],
      ),
    );
  }

  Widget _lockScreen() {
    return AppScaffold(
      title: 'Boctrust Fixed Deposit',
      activeSection: AppSection.save,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SavingsHeroCard(
            rate: '18% p.a. · locked',
            amount: '₦300,000.00',
            growth: 'Matures 14 Oct 2026 · 84 days left',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PrimaryButton(
              label: 'Add to this lock',
              onPressed: () => _showMessage('Add-to-lock flow opened.'),
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Lock details'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Funds are locked until maturity. Breaking early forfeits accrued interest.',
                    style: TextStyle(color: BocColors.inkSoft, height: 1.45),
                  ),
                  SizedBox(height: 12),
                  InfoBanner(
                    text: 'Expected interest',
                    value: '₦45,000 at maturity',
                  ),
                  SizedBox(height: 12),
                  ReceiptRow(label: 'Lock period', value: '6 months'),
                  ReceiptRow(label: 'Payout date', value: '14 Oct 2026'),
                  ReceiptRow(label: 'Interest rate', value: '18% p.a.'),
                  ReceiptRow(label: 'Early exit fee', value: 'All interest'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Your active locks'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                GoalCard(
                  progress: 0.35,
                  name: '18-month lock',
                  frequency: 'Matures 14 Oct 2026',
                  amount: '₦300,000 locked · 18% p.a.',
                ),
                SizedBox(height: 10),
                GoalCard(
                  progress: 0.78,
                  name: 'Wedding lock — 90 days',
                  frequency: 'Matures 3 Sep 2026',
                  amount: '₦180,000 locked · 15% p.a.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: () => _showMessage('New lock setup opened.'),
              icon: const Icon(Icons.add),
              label: const Text('Start a new lock'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupScreen() {
    return AppScaffold(
      title: 'Boctrust Group Savings',
      activeSection: AppSection.save,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              child: Column(
                children: [
                  const Text(
                    '6 members · weekly rotation',
                    style: TextStyle(
                      color: BocColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₦460,000.00',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontSize: 29),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '46% of ₦1,000,000 group target',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  const AvatarStack(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Contribute now',
                          onPressed: () =>
                              _showMessage('Contribution flow opened.'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showMessage('Invite link copied.'),
                          child: const Text('Invite member'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: InfoBanner(
              text:
                  'Owambe Squad · next contribution of ₦20,000 due from you on 28 Jul 2026.',
              value: '',
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Members & contributions'),
          const MemberRow(
            initials: 'AO',
            name: 'Adaeze Okonkwo (you)',
            subtitle: 'Contributed on time · 6 weeks',
            amount: '₦120,000',
          ),
          const MemberRow(
            initials: 'IN',
            name: 'Ifeoma Nwachukwu',
            subtitle: 'Contributed on time · 6 weeks',
            amount: '₦120,000',
          ),
          const MemberRow(
            initials: 'CO',
            name: 'Chuka Obi',
            subtitle: '1 payment pending',
            amount: '₦100,000',
          ),
          const MemberRow(
            initials: '+3',
            name: '3 more members',
            subtitle: 'See full group',
            amount: '₦120,000',
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start a new group',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const AppTextField(
                    label: 'Group name',
                    hintText: 'e.g. Owambe Squad, Rent Circle',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
