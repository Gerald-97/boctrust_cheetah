import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/scan_text_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/scan_bank_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

const _access = CommercialBank(code: '044', name: 'Access Bank');
const _zenith = CommercialBank(code: '057', name: 'Zenith Bank');
const _gtb = CommercialBank(code: '058', name: 'Guaranty Trust Bank');
const _first = CommercialBank(code: '011', name: 'First Bank of Nigeria');
const _fcmb = CommercialBank(code: '214', name: 'First City Monument Bank');
const _abc = CommercialBank(code: '501', name: 'Abc Microfinance Bank');
const _banks = [_access, _zenith, _gtb, _first, _fcmb, _abc];

BankMatch _match(List<String> lines, [List<CommercialBank> banks = _banks]) =>
    matchScanBanks(lines, banks);

void main() {
  test('case, punctuation and legal suffix do not matter', () {
    final match = _match(['ACCESS BANK PLC.']);
    expect(match.status, BankMatchStatus.unique);
    expect(match.candidates, [_access]);
  });

  test('aliases and MFB resolve to a unique bank', () {
    expect(_match(['GTBank']).candidates, [_gtb]);
    expect(_match(['GTBank']).status, BankMatchStatus.unique);
    final mfb = _match(['Abc MFB']);
    expect(mfb.status, BankMatchStatus.unique);
    expect(mfb.candidates, [_abc]);
  });

  test('the longest bank name wins over one it contains', () {
    const union = CommercialBank(code: '032', name: 'Union Bank');
    const unionNigeria = CommercialBank(
      code: '033',
      name: 'Union Bank of Nigeria',
    );
    final match = _match(['Union Bank of Nigeria'], [union, unionNigeria]);
    expect(match.status, BankMatchStatus.unique);
    expect(match.candidates, [unionNigeria]);
  });

  test('two banks in the text are ambiguous', () {
    final match = _match(['Access Bank', 'Zenith Bank']);
    expect(match.status, BankMatchStatus.ambiguous);
    expect(match.candidates, [_access, _zenith]);
  });

  test('a misspelled bank is only a suggestion', () {
    final match = _match(['Acess Bank']);
    expect(match.status, BankMatchStatus.ambiguous);
    expect(match.candidates, [_access]);
  });

  test('generic words alone suggest nothing', () {
    expect(
      _match(['Bank', 'Account Name', '- O']).status,
      BankMatchStatus.none,
    );
  });

  test('banks sharing a code give one candidate', () {
    const duplicate = CommercialBank(code: '044', name: 'Access Bank Plc');
    final match = _match(['Access Bank'], [_access, duplicate]);
    expect(match.status, BankMatchStatus.unique);
    expect(match.candidates, hasLength(1));
  });

  test('BOCTRUST resolves when its transfers are available', () {
    const boctrust = CommercialBank(code: '090117', name: 'Boctrust MFB');
    final match = _match(['Boctrust MFB'], [boctrust, _access]);
    expect(match.status, BankMatchStatus.unique);
    expect(match.candidates, [boctrust]);
  });

  test('an unavailable bank or no text gives none', () {
    expect(_match(['Kuda Bank']).status, BankMatchStatus.none);
    expect(_match(const []).status, BankMatchStatus.none);
  });
}
