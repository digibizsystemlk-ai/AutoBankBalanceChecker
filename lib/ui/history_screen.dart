import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/transaction_provider.dart';
import '../database/models.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final Account account;

  const HistoryScreen({super.key, required this.account});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['All', 'Credit', 'Debit', 'Cheque'];

  @override
  void initState() {
    super.initState();
    // Initially load all transactions for this account
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
    });
  }

  void _applyFilters() {
    ref.read(transactionProvider(widget.account.id!).notifier).loadFilteredTransactions(
      startDate: _startDate,
      endDate: _endDate,
      category: _selectedCategory,
      searchQuery: _searchController.text,
    );
  }

  Future<void> _pickDateRange() async {
    final initialDateRange = _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _applyFilters();
  }

  Future<void> _exportToCsv() async {
    final transactions = ref.read(transactionProvider(widget.account.id!));
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }

    List<List<dynamic>> rows = [];
    rows.add(["Date", "Type", "Amount", "SMS Body"]);

    for (var tx in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(tx.date),
        tx.type,
        tx.amount,
        tx.smsBody,
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/transactions_${widget.account.accountNumberLast4}.csv');
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(file.path)], text: 'Transaction History');
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionProvider(widget.account.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text('History **${widget.account.accountNumberLast4}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCsv,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search SMS content...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _applyFilters(),
            ),
          ),

          // 2. Date Range Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                          : 'Select Date Range',
                    ),
                  ),
                ),
                if (_startDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearDateRange,
                    tooltip: 'Clear Date Filter',
                  ),
              ],
            ),
          ),

          // 3. Category Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                      _applyFilters();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(),

          // 4. Transactions List
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('No transactions found.'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      Color amountColor = Colors.black;
                      String prefix = '';
                      if (tx.type == 'Credit') {
                        amountColor = Colors.green;
                        prefix = '+';
                      } else if (tx.type == 'Debit' || tx.type == 'Cheque') {
                        amountColor = Colors.red;
                        prefix = '-';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: ListTile(
                          title: Text(tx.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('MMM dd, yyyy - hh:mm a').format(tx.date)),
                              const SizedBox(height: 4),
                              Text(tx.smsBody, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: Text(
                            '$prefix${widget.account.currencySymbol} ${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
