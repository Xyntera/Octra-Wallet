class RecipientModel {
  final String address;
  final double amount;

  RecipientModel({
    required this.address,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'to': address,
        'amount': amount,
      };
}
