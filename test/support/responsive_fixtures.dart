import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/app/bootstrap_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_flow_models.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/model/withdrawal_bank_models.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/account/provider/withdrawal_bank_providers.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_status_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:dio/dio.dart';

import 'package:boctrust_savings_loan/module/core_banking/model/bank_product_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';

import 'kyc_configuration_fixtures.dart';

// Deliberately long, synthetic customer data exercises real content layouts.
class LayoutStartup extends StartupGateNotifier {
  @override
  NotifierState<StartupGateData> build() => const NotifierState.error(
    'We could not load your account. Please check your connection and try again.',
  );
}

class LayoutProfile extends UserProfileNotifier {
  @override
  NotifierState<UserOwnProfileData> build() => const NotifierState.done(
    UserOwnProfileData(
      userId: 'layout',
      firstName: 'Alexandria',
      middleName: 'Chinwendu',
      lastName: 'Nwachukwu',
      email: 'alexandria.chinwendu@example.test',
      phoneNumber: '+2348012345678',
      tier: 1,
      status: 'active',
      transactionStatus: 'active',
      isVerifiedAccount: false,
      isVerifiedEmail: false,
      isVerifiedPhoneNumber: false,
      isCreatedPassword: true,
      isCreatedPin: true,
    ),
  );
}

class LayoutHome extends UserHomeNotifier {
  @override
  NotifierState<UserHomeData> build() => NotifierState.done(
    UserHomeData.fromJson({
      'flexWallet': {
        'currency': 'NGN',
        'availableBalance': '1234567890.12',
        'ledgerBalance': '1234567890.12',
        'status': 'active',
      },
      'dedicatedVirtualAccount': {
        'status': 'available',
        'bankName': 'Example Merchant Bank',
        'accountNumber': '0123456789',
        'accountName': 'Alexandria Chinwendu Nwachukwu',
        'provider': 'Example Processor',
      },
    }),
  );
}

const _limit = TierLimitData(
  isUnlimited: false,
  displayValue: '₦1,000,000,000.00',
);

class LayoutTiers extends UserTierNotifier {
  @override
  NotifierState<UserTierInfoData> build() => const NotifierState.done(
    UserTierInfoData(
      userId: 'layout',
      currentTier: 1,
      currentTierSummary: CurrentTierSummaryData(
        tier: 1,
        tierLabel: 'Tier 1',
        dailyTransferLimit: _limit,
        maxWalletBalance: _limit,
      ),
      tiers: [
        TierCardData(
          tier: 2,
          title: 'Verify your government-issued identity document',
          description: 'Increase your savings and transfer limits.',
          requirements: [
            TierRequirementData(
              key: 'id',
              label: 'Government-issued identity document',
              isSatisfied: false,
            ),
          ],
          status: TierCardStatus.inProgress,
          statusLabel: 'Verification in progress',
          actionLabel: 'Continue verification',
          singleTransactionLimit: _limit,
          singleDepositLimit: _limit,
          cumulativeBalanceLimit: _limit,
          checkLists: [],
        ),
      ],
    ),
  );
}

class LayoutKyc extends KycStatusNotifier {
  @override
  NotifierState<KycStatusData> build() => NotifierState.done(
    KycStatusData.fromJson({
      'userId': 'layout',
      'tier': 1,
      'identity': {
        'status': 'success',
        'hasBvnOrNin': true,
        'hasLivenessSelfie': true,
      },
      'governmentId': {
        'status': 'failed',
        'failureReason':
            'The document details could not be verified. Please try another clear image.',
      },
      'utilityBill': {'status': 'not_started'},
      'nextAction': 'verify_government_id',
    }),
  );
}

class LayoutBanks extends BankCatalogueNotifier {
  @override
  NotifierState<BankCatalogueData> build() => const NotifierState.done(
    BankCatalogueData(
      banks: [
        BankData(
          name: 'Example Merchant Bank with a long registered name',
          code: '123',
        ),
      ],
    ),
  );
}

class LayoutAccounts extends WithdrawalBankAccountsNotifier {
  @override
  NotifierState<WithdrawalBankAccountListData> build() =>
      const NotifierState.done(
        WithdrawalBankAccountListData(
          maxAllowed: 2,
          bankAccounts: [
            WithdrawalBankAccount(
              bankAccountId: 'layout',
              bankCode: '123',
              bankName: 'Example Merchant Bank with a long registered name',
              accountNumber: '0123456789',
              accountName: 'Alexandria Chinwendu Nwachukwu',
            ),
          ],
        ),
      );
}

/// Serves the live KYC configuration so the government-ID form is laid out.
class LayoutKycService extends KycService with KycConfigurationFixture {
  LayoutKycService() : super(ApiService(Dio()));
}

/// Core accounts with the same Flex balance [LayoutHome] used to publish.
class LayoutCoreAccounts extends CustomerBankAccountsNotifier {
  @override
  NotifierState<CustomerBankAccountsData> build() => NotifierState.done(
    CustomerBankAccountsData.fromJson({
      'products': [
        {
          'productCode': kFlexProductCode,
          'productName': 'Boc Flex Savings with a Particularly Long Name',
          'accountNumber': '0000000001',
          'status': 'active',
          'availableBalance': '1234567890.12',
          'ledgerBalance': '1234567890.12',
        },
      ],
    }),
  );

  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async => state;
}

class LayoutCoreProducts extends CoreBankProductsNotifier {
  @override
  NotifierState<List<CoreBankProduct>> build() => NotifierState.done(
    CoreBankProduct.listFromJson([
      {'code': kFlexProductCode, 'name': 'Boc Flex'},
    ]),
  );

  @override
  Future<NotifierState<List<CoreBankProduct>>> load() async => state;
}
