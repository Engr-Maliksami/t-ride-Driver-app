class WalletData {
  WalletData({
    this.status,
    this.balance,
    List<WalletTransaction>? transactions,
  }) : transactions = transactions ?? const [];

  final bool? status;
  final num? balance;
  final List<WalletTransaction> transactions;

  factory WalletData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final rawBalance = data['balance'] ?? data['new_balance'];
    num? parsedBalance;
    if (rawBalance is num) {
      parsedBalance = rawBalance;
    } else if (rawBalance is String) {
      parsedBalance = num.tryParse(rawBalance);
    }

    return WalletData(
      status: json['status'] as bool?,
      balance: parsedBalance,
      transactions: (data['transactions'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(WalletTransaction.fromJson)
              .toList() ??
          [],
    );
  }
}

class WalletTransaction {
  WalletTransaction({
    this.id,
    this.amount,
    this.type,
    this.transactionType,
    this.status,
    this.description,
    this.createdAt,
    this.meta,
  });

  final int? id;
  final num? amount;
  final String? type;
  final String? transactionType;
  final String? status;
  final String? description;
  final String? createdAt;
  final Map<String, dynamic>? meta;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    num? parsedAmount;
    if (rawAmount is num) {
      parsedAmount = rawAmount;
    } else if (rawAmount is String) {
      parsedAmount = num.tryParse(rawAmount);
    }

    return WalletTransaction(
      id: (json['id'] as num?)?.toInt(),
      amount: parsedAmount,
      type: json['type'] as String?,
      transactionType: json['transaction_type'] as String?,
      status: json['status'] as String?,
      description: json['description'] as String?,
      createdAt: json['created_at'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }
}

