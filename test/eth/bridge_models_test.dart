import 'package:flutter_test/flutter_test.dart';
import 'package:ouqro_wallet/eth/bridge_models.dart';

void main() {
  test('BridgeRecord JSON round-trips', () {
    final rec = BridgeRecord(
      id: 'w_1',
      direction: BridgeDirection.wrap,
      amountRaw: '1500000',
      ethAddress: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      octraAddress: 'oct5MrNfjiXFNRDLwsodn8Zm9hDKNGAYt3eQDCQ52bSpCHq',
      lockTxHash: 'abc',
      epoch: '42',
      status: BridgeStatus.claimable,
      createdAt: 1718000000000,
    );

    final back = BridgeRecord.fromJson(rec.toJson());

    expect(back.id, rec.id);
    expect(back.direction, BridgeDirection.wrap);
    expect(back.amountRaw, '1500000');
    expect(back.ethAddress, rec.ethAddress);
    expect(back.octraAddress, rec.octraAddress);
    expect(back.lockTxHash, 'abc');
    expect(back.epoch, '42');
    expect(back.status, BridgeStatus.claimable);
    expect(back.createdAt, 1718000000000);
  });

  test('copyWith updates status without losing fields', () {
    final rec = BridgeRecord(
      id: 'u_1',
      direction: BridgeDirection.unwrap,
      amountRaw: '1000000',
      ethAddress: '0x0000000000000000000000000000000000000001',
      octraAddress: 'oct5MrNfjiXFNRDLwsodn8Zm9hDKNGAYt3eQDCQ52bSpCHq',
      createdAt: 1,
    );
    final updated =
        rec.copyWith(burnTxHash: '0xdead', status: BridgeStatus.completed);
    expect(updated.burnTxHash, '0xdead');
    expect(updated.status, BridgeStatus.completed);
    expect(updated.amountRaw, '1000000');
    expect(updated.direction, BridgeDirection.unwrap);
  });
}
