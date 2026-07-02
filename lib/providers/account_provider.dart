import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/models.dart';
import '../database/database_helper.dart';

final accountProvider = StateNotifierProvider<AccountNotifier, List<Account>>((ref) {
  return AccountNotifier();
});

class AccountNotifier extends StateNotifier<List<Account>> {
  AccountNotifier() : super([]) {
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    final dbHelper = DatabaseHelper();
    final accounts = await dbHelper.getAccounts();
    state = accounts;
  }

  Future<void> addAccount(Account account) async {
    final dbHelper = DatabaseHelper();
    final id = await dbHelper.insertAccount(account);
    final newAccount = account.copyWith(id: id);
    state = [...state, newAccount];
  }

  Future<void> updateAccountBalance(int accountId, double newBalance) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.updateAccountBalance(accountId, newBalance);
    state = state.map((acc) {
      if (acc.id == accountId) {
        return acc.copyWith(currentBalance: newBalance);
      }
      return acc;
    }).toList();
  }

  Account? getAccountByLast4(String last4) {
    try {
      return state.firstWhere((acc) => acc.accountNumberLast4 == last4);
    } catch (e) {
      return null;
    }
  }
}
