part of '../../app_flow/app_flow_navigator.dart';

extension SendScreens on AppFlowNavigatorState {
  Widget _sendHubScreen() {
    return AppScaffold(
      title: 'Send money',
      activeSection: AppSection.send,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('Where to?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ProductTile(
            icon: Icons.swap_horiz_rounded,
            title: 'To my own account',
            subtitle: 'Move money between Flex, Target, Lock & Group',
            color: BocColors.gold,
            onTap: () => _go(AppScreen.sendOwn),
          ),
          ProductTile(
            icon: Icons.person_outline_rounded,
            title: 'To a Cheetah beneficiary',
            subtitle: 'Send free & instant to another Cheetah user',
            color: BocColors.blue,
            onTap: () => _go(AppScreen.sendBeneficiary),
          ),
          ProductTile(
            icon: Icons.account_balance_outlined,
            title: 'To another bank',
            subtitle: 'Send to any Nigerian bank account',
            color: BocColors.purple,
            onTap: () => _go(AppScreen.sendBank),
          ),
          const SizedBox(height: 18),
          Text(
            'Recent recipients',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          const ContactCard(
            initials: 'IN',
            name: 'Ifeoma Nwachukwu',
            subtitle: 'Cheetah · 0198 220 341',
          ),
          const SizedBox(height: 10),
          const ContactCard(
            initials: 'TB',
            name: 'Tunde Bakare',
            subtitle: 'GTBank · 0221 884 010',
          ),
        ],
      ),
    );
  }

  Widget _sendOwnScreen() {
    return AppScaffold(
      title: 'Move between savings',
      activeSection: AppSection.send,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const AccountSelectorCard(
            label: 'From',
            title: 'Everyday Flex',
            subtitle: 'Balance: ₦420,180.10',
            icon: Icons.savings_outlined,
          ),
          const SizedBox(height: 12),
          Center(
            child: CircleAvatar(
              backgroundColor: context.bocColors.goldPale,
              foregroundColor: BocColors.gold,
              child: const Icon(Icons.swap_vert_rounded),
            ),
          ),
          const SizedBox(height: 12),
          const AccountSelectorCard(
            label: 'To',
            title: 'Rent — Dec 2026',
            subtitle: 'Cheetah Target Savings',
            icon: Icons.track_changes_rounded,
          ),
          const SizedBox(height: 20),
          const AmountDisplay(
            amount: '40,000',
            subtitle:
                'Instant, no fees — moves stay within your Cheetah account',
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Move money',
            onPressed: () => _openAuth(
              const TransactionContext(
                amount: '₦40,000.00',
                description: 'Moved from Everyday Flex to Rent — Dec 2026.',
                title: 'Money moved successfully',
                row1Label: 'From',
                row1Value: 'Everyday Flex',
                row2Label: 'To',
                row2Value: 'Rent — Dec 2026',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sendBeneficiaryScreen() {
    return AppScaffold(
      title: 'Send to beneficiary',
      activeSection: AppSection.send,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const SearchField(hint: 'Search name or account number'),
          const SizedBox(height: 18),
          Text(
            'Saved beneficiaries',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          const ContactCard(
            initials: 'IN',
            name: 'Ifeoma Nwachukwu',
            subtitle: '0198 220 341 · Cheetah',
          ),
          const SizedBox(height: 10),
          const ContactCard(
            initials: 'CO',
            name: 'Chuka Obi',
            subtitle: '0177 552 903 · Cheetah',
          ),
          const SizedBox(height: 10),
          const ContactCard(
            initials: 'HM',
            name: 'Hauwa Musa',
            subtitle: '0134 908 227 · Cheetah',
          ),
          const SizedBox(height: 18),
          Text('Amount', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const ContactCard(
            initials: 'IN',
            name: 'Ifeoma Nwachukwu',
            subtitle: 'Cheetah · 0198 220 341',
            trailing: Text(
              'Change',
              style: TextStyle(
                color: BocColors.blue,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const AmountDisplay(
            amount: '35,000',
            subtitle: 'Transfers to other Cheetah users are free & instant',
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Review transfer',
            onPressed: () => _openAuth(
              const TransactionContext(
                amount: '₦35,000.00',
                description:
                    'Sent to Ifeoma Nwachukwu · Cheetah. This receipt has been saved to your statement.',
                title: 'Transfer successful',
                row1Label: 'Recipient',
                row1Value: 'Ifeoma Nwachukwu',
                row2Label: 'Account',
                row2Value: '0198 220 341',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sendBankScreen() {
    return AppScaffold(
      title: 'Send to other bank',
      activeSection: AppSection.send,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const LabeledField(
            label: 'Bank',
            value: 'Guaranty Trust Bank (GTBank)',
          ),
          const SizedBox(height: 12),
          const AppTextField(
            label: 'Account number',
            initialValue: '0221 884 010',
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
                Icon(Icons.check_circle_outline, color: BocColors.green),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tunde Bakare',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Account name resolved',
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
            amount: '75,000',
            subtitle: 'Standard NIP transfer fee: ₦26.88 · Arrives in seconds',
          ),
          const SizedBox(height: 18),
          Text('Recent banks', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const BankRow(name: 'GTBank', subtitle: 'Guaranty Trust Bank'),
          const BankRow(name: 'Access Bank', subtitle: 'Access Bank Plc'),
          const BankRow(name: 'Opay', subtitle: 'Paycom / Opay'),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Review transfer',
            onPressed: () => _openAuth(
              const TransactionContext(
                amount: '₦75,000.00',
                description: 'Sent to Tunde Bakare · GTBank.',
                title: 'Transfer successful',
                row1Label: 'Recipient',
                row1Value: 'Tunde Bakare',
                row2Label: 'Bank account',
                row2Value: 'GTBank · 0221 884 010',
                fee: '₦26.88',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authPinScreen() {
    return AppScaffold(
      title: "Confirm it's you",
      activeSection: AppSection.send,
      onBack: _back,
      onSectionSelected: _goSection,
      showBottomNavigation: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          Center(
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: context.bocColors.goldPale,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: BocColors.gold,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Enter your PIN',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              children: [
                Text(
                  _transaction.amount,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _transaction.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PinDots(filled: _authPinCount),
          const SizedBox(height: 18),
          MoneyKeypad(
            showDecimal: false,
            onKey: (_) => _pinPressed(),
            onBackspace: _removePinDigit,
          ),
          TextButton.icon(
            onPressed: () => _go(AppScreen.success),
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Use Face ID or fingerprint instead'),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Confirm & complete transaction',
            onPressed: () => _go(AppScreen.success),
          ),
        ],
      ),
    );
  }

  Widget _successScreen() {
    return AppScaffold(
      title: '',
      activeSection: AppSection.send,
      onBack: _back,
      onSectionSelected: _goSection,
      showBottomNavigation: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: context.bocColors.greenPale,
              foregroundColor: BocColors.green,
              child: const Icon(Icons.check_rounded, size: 38),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _transaction.title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 8),
          Text(
            _transaction.amount,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 8),
          Text(
            _transaction.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SurfaceCard(
            child: Column(
              children: [
                ReceiptRow(
                  label: _transaction.row1Label,
                  value: _transaction.row1Value,
                ),
                ReceiptRow(
                  label: _transaction.row2Label,
                  value: _transaction.row2Value,
                ),
                ReceiptRow(label: 'Fee', value: _transaction.fee),
                const ReceiptRow(label: 'Date', value: '22 Jul 2026, 4:20 PM'),
                const ReceiptRow(label: 'Reference', value: 'BOC7734912X'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _showMessage('Receipt share sheet opened.'),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share receipt'),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Back to home',
            onPressed: () => _go(AppScreen.home, replace: true),
          ),
        ],
      ),
    );
  }
}
