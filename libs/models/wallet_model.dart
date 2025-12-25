class WalletModel {
  final String address;
  final String privateKeyB64;
  final String publicKeyB64;
  final List<String> mnemonic;
  int nonce;

  WalletModel({
    required this.address,
    required this.privateKeyB64,
    required this.publicKeyB64,
    required this.mnemonic,
    required this.nonce,
  });
}
