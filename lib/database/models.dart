class Account {
  final int? id;
  final String accountNumberLast4;
  final String? bankName;
  final String? currency;
  final double initialBalance;
  final double currentBalance;

  Account({
    this.id,
    required this.accountNumberLast4,
    this.bankName,
    this.currency = 'LKR',
    required this.initialBalance,
    required this.currentBalance,
  });

  String get currencySymbol {
    switch (currency) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      default: return 'Rs.';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_number_last_4': accountNumberLast4,
      'bank_name': bankName,
      'currency': currency,
      'initial_balance': initialBalance,
      'current_balance': currentBalance,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      accountNumberLast4: map['account_number_last_4'],
      bankName: map['bank_name'],
      currency: map['currency'] ?? 'LKR',
      initialBalance: map['initial_balance'],
      currentBalance: map['current_balance'],
    );
  }

  Account copyWith({
    int? id,
    String? accountNumberLast4,
    String? bankName,
    String? currency,
    double? initialBalance,
    double? currentBalance,
  }) {
    return Account(
      id: id ?? this.id,
      accountNumberLast4: accountNumberLast4 ?? this.accountNumberLast4,
      bankName: bankName ?? this.bankName,
      currency: currency ?? this.currency,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }
}

class TransactionRecord {
  final int? id;
  final int accountId;
  final String type; // 'Credit', 'Debit', 'Cheque'
  final double amount;
  final DateTime date;
  final String smsBody;

  TransactionRecord({
    this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.date,
    required this.smsBody,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
      'sms_body': smsBody,
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id'],
      accountId: map['account_id'],
      type: map['type'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      smsBody: map['sms_body'],
    );
  }
}
