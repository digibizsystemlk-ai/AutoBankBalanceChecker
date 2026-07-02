class ParsedTransaction {
  final String accountLast4;
  final String type; // 'Credit', 'Debit', 'Cheque'
  final double amount;
  final bool isSuccessful;

  ParsedTransaction({
    required this.accountLast4,
    required this.type,
    required this.amount,
    this.isSuccessful = true,
  });
}

class SmsParser {
  /// A flexible string parser utility that extracts bank transaction details.
  /// It can handle text pasted by the user or received via notifications.
  static ParsedTransaction? parseSms(String text) {
    text = text.toLowerCase();

    // 1. Identify if it's a transaction SMS
    // Looking for keywords like 'debited', 'credited', 'paid', 'purchase', 'deposit'
    bool isCredit = text.contains('credit') || text.contains('deposit') || text.contains('added');
    bool isDebit = text.contains('debit') || text.contains('paid') || text.contains('purchase') || text.contains('withdrawn');
    bool isCheque = text.contains('cheque') || text.contains('chq') || text.contains('clearing');

    if (!isCredit && !isDebit && !isCheque) {
      return null; // Not a recognized transaction
    }

    String type = 'Debit'; // default
    if (isCheque) {
      type = 'Cheque';
    } else if (isCredit) {
      type = 'Credit';
    }

    // 2. Extract Account Number (usually ends with 4 digits: a/c XXXXX1234 or acc **1234 or a/c 1234)
    String accountLast4 = '';
    // Regex for typical account masks like **1234, XXXXX1234, a/c 1234
    RegExp accountRegExp = RegExp(r'(?:a/c|acct|acc|account|a\\c)?\s*(?:[x\*]+|-)?(\d{4})\b', caseSensitive: false);
    Match? accMatch = accountRegExp.firstMatch(text);
    if (accMatch != null && accMatch.group(1) != null) {
      accountLast4 = accMatch.group(1)!;
    } else {
      // If we can't find a 4 digit account, we can't associate it.
      return null;
    }

    // 3. Extract Amount
    // Regex to find amounts like Rs. 1000.00, LKR 5,000.00, Rs 500, amount 200.50
    double amount = 0.0;
    RegExp amountRegExp = RegExp(r'(?:rs\.?|lkr|rmb|usd)\s*([\d,]+\.?\d*)', caseSensitive: false);
    Match? amtMatch = amountRegExp.firstMatch(text);
    
    if (amtMatch != null && amtMatch.group(1) != null) {
      String amtStr = amtMatch.group(1)!.replaceAll(',', '');
      amount = double.tryParse(amtStr) ?? 0.0;
    } else {
      // Fallback: look for the first decimal number or number greater than 0
      RegExp numRegExp = RegExp(r'\b(\d+[\d,]*\.\d+)\b');
      Match? numMatch = numRegExp.firstMatch(text);
      if (numMatch != null && numMatch.group(1) != null) {
        String numStr = numMatch.group(1)!.replaceAll(',', '');
        amount = double.tryParse(numStr) ?? 0.0;
      } else {
        return null; // Cannot parse amount
      }
    }

    return ParsedTransaction(
      accountLast4: accountLast4,
      type: type,
      amount: amount,
    );
  }
}
