import 'package:flutter_test/flutter_test.dart';
import 'package:ouqro_wallet/eth/eth_abi.dart';
import 'package:ouqro_wallet/eth/eth_constants.dart';

void main() {
  group('EthAbi calldata (byte-exact vs webcli reference)', () {
    test('balanceOf(address)', () {
      final data = EthAbi.balanceOf(
          '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
      expect(
        data,
        '0x70a08231'
        '000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266',
      );
    });

    test('approve(bridge, 1000000) — exact amount, lowercased spender', () {
      final data = EthAbi.approve(EthConstants.ethereumBridge, BigInt.from(1000000));
      expect(
        data,
        '0x095ea7b3'
        '000000000000000000000000e7ed69b852fd2a1406080b26a37e8e04e7da4cae'
        '00000000000000000000000000000000000000000000000000000000000f4240',
      );
    });

    test('burn(string,uint256) — ASCII string layout', () {
      final data = EthAbi.burn('oct', BigInt.from(1000000));
      expect(
        data,
        '0xe3e3aed0'
        '0000000000000000000000000000000000000000000000000000000000000040' // offset
        '00000000000000000000000000000000000000000000000000000000000f4240' // amount
        '0000000000000000000000000000000000000000000000000000000000000003' // len=3
        '6f63740000000000000000000000000000000000000000000000000000000000', // "oct"
      );
    });

    test('burn encodes a full 47-char oct address as a 0x2f-length string', () {
      const addr = 'oct5MrNfjiXFNRDLwsodn8Zm9hDKNGAYt3eQDCQ52bSpCHq';
      expect(addr.length, 47);
      final data = EthAbi.burn(addr, BigInt.one);
      // selector(8) + 0x + offset(64) + amount(64) + len(64) + 2 words(128)
      expect(data.length, 2 + 8 + 64 + 64 + 64 + 128);
      // length word encodes 47 == 0x2f
      expect(data.contains('000000000000000000000000000000000000000000000000000000000000002f'), isTrue);
    });

    test('rejects negative amounts', () {
      expect(() => EthAbi.approve(EthConstants.ethereumBridge, BigInt.from(-1)),
          throwsArgumentError);
    });
  });
}
