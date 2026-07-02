import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/models.dart';
import '../database/database_helper.dart';

final transactionProvider = StateNotifierProvider.family<TransactionNotifier, List<TransactionRecord>, int>((ref, accountId) {
  return TransactionNotifier(accountId);
});

final summaryProvider = FutureProvider<Map<String, double>>((ref) async {
  // Watch all transaction providers so summary updates if ANY transaction changes? 
  // For simplicity, we just fetch from DB. Since riverpod needs a way to know when to refresh,
  // we could just fetch it. But let's just make a simple FutureProvider.
  final dbHelper = DatabaseHelper();
  return await dbHelper.getTransactionSummary();
});

class TransactionNotifier extends StateNotifier<List<TransactionRecord>> {
  final int accountId;

  TransactionNotifier(this.accountId) : super([]) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final dbHelper = DatabaseHelper();
    final transactions = await dbHelper.getTransactionsForAccount(accountId);
    state = transactions;
  }

  Future<void> addTransaction(TransactionRecord transaction) async {
    final dbHelper = DatabaseHelper();
    final id = await dbHelper.insertTransaction(transaction);
    final newTransaction = TransactionRecord(
      id: id,
      accountId: transaction.accountId,
      type: transaction.type,
      amount: transaction.amount,
      date: transaction.date,
      smsBody: transaction.smsBody,
    );
    state = [newTransaction, ...state]; // Prepend new transaction
  }

  Future<void> loadFilteredTransactions({DateTime? startDate, DateTime? endDate, String? category, String? searchQuery}) async {
    final dbHelper = DatabaseHelper();
    final filtered = await dbHelper.getFilteredTransactions(
      accountId: accountId,
      startDate: startDate,
      endDate: endDate,
      category: category,
      searchQuery: searchQuery,
    );
    state = filtered;
  }
}
