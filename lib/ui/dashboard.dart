import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../parser/sms_parser.dart';
import '../database/models.dart';
import 'history_screen.dart';

import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _smsController = TextEditingController();

  void _processSms() {
    final text = _smsController.text;
    if (text.isEmpty) return;

    final parsed = SmsParser.parseSms(text);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse transaction from text.')),
      );
      return;
    }

    _handleParsedTransaction(parsed, text);
    _smsController.clear();
  }

  Future<void> _handleParsedTransaction(ParsedTransaction parsed, String rawText) async {
    final accountNotifier = ref.read(accountProvider.notifier);
    Account? account = accountNotifier.getAccountByLast4(parsed.accountLast4);

    if (account == null) {
      // Dynamic Onboarding
      final balanceController = TextEditingController();
      String selectedBank = 'BOC';
      String selectedCurrency = 'LKR';
      final banks = ['BOC', 'Sampath', 'HNB', 'Commercial', 'Other'];
      final currencies = ['LKR', 'USD', 'EUR', 'GBP'];

      final bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('New Account Detected (**${parsed.accountLast4})'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Link this account and enter CURRENT actual balance.'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedBank,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name',
                        border: OutlineInputBorder(),
                      ),
                      items: banks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedBank = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                      ),
                      items: currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedCurrency = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Current Balance',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (balanceController.text.isNotEmpty) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('Yes, Link'),
                  ),
                ],
              );
            }
          );
        },
      );

      if (confirm == true) {
        final initialBalance = double.tryParse(balanceController.text) ?? 0.0;
        
        final newAccount = Account(
          accountNumberLast4: parsed.accountLast4,
          bankName: selectedBank,
          currency: selectedCurrency,
          initialBalance: initialBalance,
          currentBalance: initialBalance, 
        );
        
        await accountNotifier.addAccount(newAccount);
        
        // Wait for state to update and fetch the newly added account
        // A slight delay to ensure state propagates, or fetch from DB directly
        await Future.delayed(const Duration(milliseconds: 100));
        account = ref.read(accountProvider.notifier).getAccountByLast4(parsed.accountLast4);
      } else {
        return; // User ignored the account
      }
    }

    if (account != null && account.id != null) {
      // We already have the account, calculate running balance
      double newBalance = account.currentBalance;
      if (parsed.type == 'Credit') {
        newBalance += parsed.amount;
      } else if (parsed.type == 'Debit' || parsed.type == 'Cheque') {
        newBalance -= parsed.amount;
      }

      // Update Account Balance
      await accountNotifier.updateAccountBalance(account.id!, newBalance);

      // Record Transaction
      final txNotifier = ref.read(transactionProvider(account.id!).notifier);
      await txNotifier.addTransaction(TransactionRecord(
        accountId: account.id!,
        type: parsed.type,
        amount: parsed.amount,
        date: DateTime.now(),
        smsBody: rawText,
      ));

      // Refresh Summary
      ref.invalidate(summaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction recorded. New Balance: \$newBalance')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider);
    final summaryAsync = ref.watch(summaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Bank Balance'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Analytics Chart
            summaryAsync.when(
              data: (summary) {
                final credit = summary['Credit'] ?? 0.0;
                final debit = summary['Debit'] ?? 0.0;
                if (credit == 0 && debit == 0) return const SizedBox();
                
                return SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(
                          color: Colors.green,
                          value: credit,
                          title: 'Income',
                          radius: 40,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: Colors.red,
                          value: debit,
                          title: 'Expense',
                          radius: 40,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => const Text('Error loading chart'),
            ),
            const SizedBox(height: 10),

            // Simulating SMS Input for Testing
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Test Transaction (Paste SMS):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'e.g. A/C **1234 debited Rs. 5000.00 for Purchase.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _processSms,
                      child: const Text('Process SMS'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Accounts List
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Linked Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: accounts.isEmpty
                  ? const Center(child: Text('No accounts linked yet.'))
                  : ListView.builder(
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final acc = accounts[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.account_balance_wallet),
                            title: Text('Account: **${acc.accountNumberLast4} (${acc.bankName ?? "Unknown"})'),
                            subtitle: Text('Balance: ${acc.currencySymbol} ${acc.currentBalance.toStringAsFixed(2)}'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HistoryScreen(account: acc),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
