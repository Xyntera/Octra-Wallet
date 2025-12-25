class TransactionModel {
  final String hash;
  final int epoch;
  final String from;
  final String to;
  final double amount;

  TransactionModel({
    required this.hash,
    required this.epoch,
    required this.from,
    required this.to,
    required this.amount,
  });

  bool isSent(String myAddress) => from == myAddress;
}
