import 'package:flutter_test/flutter_test.dart';
import 'package:ouqro_wallet/eth/eth_account.dart';

void main() {
  group('EthAccount derivation', () {
    // Canonical BIP44 m/44'/60'/0'/0/0 test vector (Hardhat/Anvil account #0).
    const mnemonic =
        'test test test test test test test test test test test junk';
    const expectedAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

    test('derives the expected EIP-55 address from a known mnemonic', () {
      final account = EthAccount.fromMnemonic(mnemonic);
      expect(account.address, expectedAddress);
      expect(account.mode, EthAccountMode.derived);
      expect(account.canSign, isTrue);
    });

    test('manual address is recipient-only and checksummed', () {
      final account =
          EthAccount.fromAddress(expectedAddress.toLowerCase());
      expect(account.address, expectedAddress); // re-checksummed
      expect(account.mode, EthAccountMode.manual);
      expect(account.canSign, isFalse);
    });

    test('rejects invalid addresses', () {
      expect(EthAccount.isValidAddress('not-an-address'), isFalse);
      expect(EthAccount.isValidAddress(expectedAddress), isTrue);
    });
  });
}
