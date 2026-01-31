class Wallet {
  final String address;
  final String privateKeyBase64;
  final String? mnemonic; 
  final String name;
  final int color;

  Wallet({
    required this.address,
    required this.privateKeyBase64,
    this.mnemonic,
    String? name,
    int? color,
  }) : 
    this.name = name ?? "Wallet",
    this.color = color ?? 0xFF357AF6; // System Blue default

  Map<String, dynamic> toJson() => {
    'address': address,
    'privateKeyBase64': privateKeyBase64,
    'mnemonic': mnemonic,
    'name': name,
    'color': color,
  };

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      address: json['address'],
      privateKeyBase64: json['privateKeyBase64'],
      mnemonic: json['mnemonic'],
      name: json['name'],
      color: json['color'],
    );
  }
}
