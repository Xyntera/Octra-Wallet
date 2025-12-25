class PendingTxModel {
  final String hash;
  final double amount;
  final String from;

  PendingTxModel({
    required this.hash,
    required this.amount,
    required this.from,
  });

  factory PendingTxModel.fromJson(Map<String, dynamic> json) {
    return PendingTxModel(
      hash: json['hash'],
      amount: (json['amount'] ?? 0).toDouble(),
      from: json['from'],
    );
  }
}
