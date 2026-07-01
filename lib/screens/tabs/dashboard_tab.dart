import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';
import '../../utils/formatters.dart';
import '../wrapped_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _showCategoryBudgets = false;

  @override
  void dispose() {
    super.dispose();
  }

  // Helper to format currency
  String _formatAmount(double amount) {
    return _currencyFormat.format(amount);
  }

  // Dialog to edit initial balance
  void _showEditInitialBalanceDialog(BuildContext context, TransactionProvider provider) {
    final controller = TextEditingController(
      text: provider.initialBalance > 0
          ? NumberFormat.decimalPattern('id').format(provider.initialBalance)
          : ''
    );
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Atur Saldo Awal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Masukkan nominal saldo awal Anda:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                inputFormatters: [
                  ThousandsSeparatorInputFormatter(),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.replaceAll('.', '');
                final amount = double.tryParse(text) ?? 0.0;
                Navigator.of(dialogCtx).pop();
                // Confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Konfirmasi Saldo Awal'),
                    content: Text(
                      'Simpan saldo awal sebesar ${_formatAmount(amount)}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  provider.setInitialBalance(amount);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Saldo awal berhasil disimpan.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Lanjut'),
            ),
          ],
        );
      },
    );
  }

  // Dialog to confirm reset balance
  void _showResetBalanceConfirmDialog(BuildContext context, TransactionProvider provider) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Reset Saldo & Transaksi'),
          content: const Text(
            'Apakah Anda yakin ingin mereset saldo awal menjadi Rp 0 dan menghapus semua riwayat transaksi? Tindakan ini tidak dapat dibatalkan.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                provider.resetBalance();
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saldo awal dan semua transaksi berhasil di-reset.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  // Dialog to set monthly budget limit (card-style like Total Saldo)
  void _showEditBudgetLimitDialog(BuildContext context, TransactionProvider provider) {
    final controller = TextEditingController(
      text: provider.budgetLimit > 0
          ? NumberFormat.decimalPattern('id').format(provider.budgetLimit)
          : ''
    );
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Atur Batas Anggaran Bulanan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Masukkan batas pengeluaran bulanan Anda:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: 'Contoh: 3.000.000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                inputFormatters: [
                  ThousandsSeparatorInputFormatter(),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.replaceAll('.', '');
                final limit = double.tryParse(text) ?? 0.0;
                Navigator.of(dialogCtx).pop();
                // Confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Konfirmasi Anggaran'),
                    content: Text(
                      'Simpan batas anggaran bulanan sebesar ${_formatAmount(limit)}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  provider.setBudgetLimit(limit);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Batas anggaran bulanan berhasil disimpan.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Lanjut'),
            ),
          ],
        );
      },
    );
  }

  // Dialog to confirm reset budget limit
  void _showResetBudgetConfirmDialog(BuildContext context, TransactionProvider provider) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Reset Batas Anggaran'),
          content: const Text('Apakah Anda yakin ingin mereset batas anggaran bulanan menjadi Rp 0?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                provider.resetBudgetLimit();
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Batas anggaran bulanan berhasil di-reset.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }


  // Dialog to set budget for a category (with confirm)
  void _showCategoryBudgetDialog(
    BuildContext context,
    TransactionProvider provider,
    String category,
    double currentLimit,
  ) {
    final ctrl = TextEditingController(
      text: currentLimit > 0 ? NumberFormat.decimalPattern('id').format(currentLimit) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anggaran: $category', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          decoration: InputDecoration(
            prefixText: 'Rp ',
            hintText: 'Contoh: 500.000',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text.replaceAll('.', '')) ?? 0;
              Navigator.pop(ctx);
              if (amount > 0) {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text('Konfirmasi Anggaran $category'),
                    content: Text('Simpan anggaran kategori "$category" sebesar ${_formatAmount(amount)}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  provider.setCategoryBudget(category, amount);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Anggaran "$category" berhasil disimpan.'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  // Confirm reset category budget
  void _showResetCategoryBudgetConfirmDialog(
    BuildContext context,
    TransactionProvider provider,
    String category,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Anggaran Kategori'),
        content: Text('Hapus anggaran untuk kategori "$category"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.resetCategoryBudget(category);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Anggaran "$category" berhasil dihapus.'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // Custom Summary Card Widget builder
  Widget _buildSummaryCard(
    String title,
    double amount,
    Color indicatorColor,
    bool isDark,
    bool isObscured, {
    String textPrefix = '',
    Widget? subtitle,
    VoidCallback? onEdit,
    VoidCallback? onReset,
    bool isCompact = false,
  }) {
    return Card(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: indicatorColor, width: 4.5),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: isCompact ? 10 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                  ),
                ),
                if (onEdit != null || onReset != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        GestureDetector(
                          onTap: onEdit,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF10B981)),
                          ),
                        ),
                      if (onEdit != null && onReset != null) const SizedBox(width: 6),
                      if (onReset != null)
                        GestureDetector(
                          onTap: onReset,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFFF43F5E).withOpacity(0.12) : const Color(0xFFF43F5E).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.refresh, size: 14, color: Color(0xFFF43F5E)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isObscured
                  ? (textPrefix.isNotEmpty ? "$textPrefix ••••••" : "Rp ••••••")
                  : (textPrefix.isNotEmpty
                      ? "$textPrefix ${_formatAmount(amount).replaceFirst('Rp', '').trim()}"
                      : _formatAmount(amount)),
              style: TextStyle(
                fontSize: title == 'TOTAL SALDO' ? 28 : (isCompact ? 16 : 22),
                fontWeight: FontWeight.w800,
                color: title == 'TOTAL SALDO'
                  ? (isDark ? Colors.white : const Color(0xFF0F2015))
                  : indicatorColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              subtitle,
            ],
          ],
        ),
      ),
    );
  }

  // Budget Card - mimics summary card style but shows progress
  Widget _buildBudgetCard(
    BuildContext context,
    TransactionProvider provider,
    double currentMonthExpenses,
    bool isDark,
    bool isObscured,
  ) {
    final budgetLimit = provider.budgetLimit;
    final percent = budgetLimit > 0 ? (currentMonthExpenses / budgetLimit) * 100 : 0.0;
    final progressPercent = (percent / 100).clamp(0.0, 1.0);

    Color budgetColor = const Color(0xFF10B981);
    if (percent >= 100) {
      budgetColor = const Color(0xFFF43F5E);
    } else if (percent >= 80) {
      budgetColor = const Color(0xFFF59E0B);
    }

    return Card(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFF10B981), width: 4.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'BATAS ANGGARAN BULANAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _showEditBudgetLimitDialog(context, provider),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showResetBudgetConfirmDialog(context, provider),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFFF43F5E).withOpacity(0.12) : const Color(0xFFF43F5E).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.refresh, size: 14, color: Color(0xFFF43F5E)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Budget limit value
            Text(
              budgetLimit > 0
                  ? (isObscured ? 'Rp ••••••' : _formatAmount(budgetLimit))
                  : 'Belum diatur',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: budgetLimit > 0
                    ? (isDark ? Colors.white : const Color(0xFF0F2015))
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 14),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progressPercent,
                minHeight: 8,
                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation<Color>(budgetColor),
              ),
            ),
            const SizedBox(height: 8),
            // Progress text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Terpakai: ${isObscured ? "Rp ••••••" : _formatAmount(currentMonthExpenses)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFCBDCD0) : const Color(0xFF2D4236),
                    ),
                  ),
                ),
                Text(
                  '${percent.round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: budgetColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Toggle to show/hide category budgets
            InkWell(
              onTap: () {
                setState(() {
                  _showCategoryBudgets = !_showCategoryBudgets;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showCategoryBudgets ? Icons.pie_chart : Icons.pie_chart_outline,
                      size: 14,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showCategoryBudgets ? 'Sembunyikan Anggaran Kategori' : 'Tampilkan Anggaran Kategori',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBDCD0) : const Color(0xFF2D4236),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showCategoryBudgets ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 14,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Category Budget Section
  Widget _buildCategoryBudgetSection(
    BuildContext context,
    TransactionProvider provider,
    List<Transaction> transactions,
    bool isDark,
    bool isObscured,
  ) {
    final categories = TransactionProvider.expenseCategories;
    final now = DateTime.now();
    final categoryBudgets = provider.categoryBudgets;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                const Text('Anggaran Per Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pengeluaran bulan ini per kategori',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 14),
            ...categories.map((cat) {
              final spent = transactions
                  .where((tx) =>
                      tx.type == 'expense' &&
                      tx.category == cat &&
                      tx.date.year == now.year &&
                      tx.date.month == now.month)
                  .fold(0.0, (sum, tx) => sum + tx.amount);
              final limit = categoryBudgets[cat] ?? 0.0;
              final percent = (limit > 0) ? (spent / limit * 100).clamp(0.0, 100.0) : 0.0;

              Color barColor = const Color(0xFF10B981);
              if (percent >= 100) { barColor = const Color(0xFFF43F5E); }
              else if (percent >= 75) { barColor = const Color(0xFFF59E0B); }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            if (limit > 0)
                              Text(
                                '${isObscured ? "••••" : _formatAmount(spent)} / ${isObscured ? "••••" : _formatAmount(limit)}',
                                style: TextStyle(fontSize: 11, color: barColor, fontWeight: FontWeight.bold),
                              )
                            else
                              Text('Belum diatur', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _showCategoryBudgetDialog(context, provider, cat, limit),
                              child: Icon(
                                limit > 0 ? Icons.edit_outlined : Icons.add_circle_outline,
                                size: 16,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            if (limit > 0) ...[
                              const SizedBox(width: 2),
                              GestureDetector(
                                onTap: () => _showResetCategoryBudgetConfirmDialog(context, provider, cat),
                                child: const Icon(Icons.close, size: 15, color: Color(0xFFF43F5E)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: limit > 0 ? percent / 100 : 0,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Doughnut Chart (Distribution of expenses by category)
  Widget _buildDonutChartCard(List<Transaction> transactions, bool isDark) {
    final Map<String, double> expensesData = {};
    for (var cat in TransactionProvider.expenseCategories) {
      expensesData[cat] = 0.0;
    }

    for (var tx in transactions) {
      if (tx.type == 'expense') {
        expensesData[tx.category] = (expensesData[tx.category] ?? 0.0) + tx.amount;
      }
    }

    final categoriesWithValues = expensesData.keys.where((cat) => (expensesData[cat] ?? 0.0) > 0.0).toList();

    final List<Color> colors = [
      const Color(0xFFF43F5E),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFEAB308),
      const Color(0xFFA855F7),
      const Color(0xFF06B6D4),
      const Color(0xFFF97316),
    ];

    List<PieChartSectionData> sections = [];
    if (categoriesWithValues.isEmpty) {
      sections = [
        PieChartSectionData(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
          value: 1,
          title: 'Belum ada pengeluaran',
          radius: 40,
          titleStyle: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      ];
    } else {
      double totalExpenses = 0.0;
      for (var v in expensesData.values) {
        totalExpenses += v;
      }

      sections = List.generate(categoriesWithValues.length, (index) {
        final cat = categoriesWithValues[index];
        final val = expensesData[cat] ?? 0.0;
        final color = colors[index % colors.length];
        final double pct = totalExpenses > 0 ? (val / totalExpenses * 100) : 0.0;
        return PieChartSectionData(
          color: color,
          value: val,
          radius: 42,
          showTitle: true,
          title: '${pct.round()}%',
          titleStyle: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titlePositionPercentageOffset: 0.55,
        );
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribusi Pengeluaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 50,
                  sections: sections,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (categoriesWithValues.isNotEmpty)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: List.generate(categoriesWithValues.length, (index) {
                  final cat = categoriesWithValues[index];
                  final color = colors[index % colors.length];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cat,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  // Bar Chart (Monthly income vs monthly expense comparison for the last 6 months)
  Widget _buildBarChartCard(List<Transaction> transactions, bool isDark) {
    final Map<String, Map<String, double>> monthlyMap = {};
    for (var tx in transactions) {
      final m = "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}";
      if (!monthlyMap.containsKey(m)) {
        monthlyMap[m] = {'income': 0.0, 'expense': 0.0};
      }
      if (tx.type == 'income') {
        monthlyMap[m]!['income'] = (monthlyMap[m]!['income'] ?? 0.0) + tx.amount;
      } else {
        monthlyMap[m]!['expense'] = (monthlyMap[m]!['expense'] ?? 0.0) + tx.amount;
      }
    }

    final sortedMonths = monthlyMap.keys.toList()..sort();
    final displayMonths = sortedMonths.length > 6 ? sortedMonths.sublist(sortedMonths.length - 6) : sortedMonths;

    final List<String> monthShorts = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agt", "Sep", "Okt", "Nov", "Des"];
    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < displayMonths.length; i++) {
      final m = displayMonths[i];
      final incomeVal = monthlyMap[m]!['income'] ?? 0.0;
      final expenseVal = monthlyMap[m]!['expense'] ?? 0.0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: incomeVal,
              color: const Color(0xFF10B981),
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: expenseVal,
              color: const Color(0xFFF43F5E),
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tren Bulanan (Masuk vs Keluar)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: barGroups.isEmpty
                  ? const Center(child: Text('Belum ada data bulanan', style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : BarChart(
                      BarChartData(
                        barGroups: barGroups,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < displayMonths.length) {
                                  final m = displayMonths[idx];
                                  final parts = m.split('-');
                                  final mIdx = int.parse(parts[1]) - 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      "${monthShorts[mIdx]} '${parts[0].substring(2)}",
                                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, color: const Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    const Text('Pemasukan', style: TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Container(width: 8, height: 8, color: const Color(0xFFF43F5E)),
                    const SizedBox(width: 4),
                    const Text('Pengeluaran', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final transactions = provider.transactions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isObscured = provider.isObscured;

    // 1. Calculate Summary Totals
    double totalIncome = 0;
    double totalExpense = 0;
    for (var tx in transactions) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }
    double balance = provider.initialBalance + totalIncome - totalExpense;

    // 2. Calculate Current Month Expenses for Budget
    final now = DateTime.now();
    double currentMonthExpenses = 0.0;
    for (var tx in transactions) {
      if (tx.type == 'expense') {
        final txYearMonth = "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}";
        final currentYearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
        if (txYearMonth == currentYearMonth) {
          currentMonthExpenses += tx.amount;
        }
      }
    }

    // 3. Calculate if previous month has transactions
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    final hasPrevMonthTxs = transactions.any((tx) => tx.date.month == prevMonth && tx.date.year == prevYear);

    final wrappedTitle = hasPrevMonthTxs
        ? 'Recap Keuangan Bulan Lalu Lo Udah Ready! ✨'
        : 'Intip Preview Financial Wrapped Lo! 🎁';
    final wrappedSub = hasPrevMonthTxs
        ? 'Cek statistik seru, gaya belanja, dan persona finansial lo.'
        : 'Mulai catat transaksi bulan ini untuk Wrapped penuh bulan depan!';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ringkasan Finansial',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFCBDCD0) : const Color(0xFF2D4236),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isObscured ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF10B981),
                  size: 20,
                ),
                onPressed: () {
                  provider.toggleObscured();
                },
                tooltip: isObscured ? 'Tampilkan Nominal' : 'Sembunyikan Nominal',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Financial Wrapped Banner (Only shown during the first 3 days of the month)
          if (now.day <= 3) ...[
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WrappedScreen()),
                );
              },
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    children: [
                                      Text('🎁 ', style: TextStyle(fontSize: 10)),
                                      Text(
                                        'FINANCIAL WRAPPED',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              wrappedTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              wrappedSub,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF7C3AED),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Summary Cards
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Total Saldo Card with edit + reset
              _buildSummaryCard(
                'TOTAL SALDO',
                balance,
                const Color(0xFF10B981),
                isDark,
                isObscured,
                subtitle: !provider.isInitialBalanceSet
                    ? Row(
                        children: [
                          Text(
                            "Saldo Awal: ${isObscured ? 'Rp ••••••' : _formatAmount(provider.initialBalance)}",
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                        ],
                      )
                    : null,
                onEdit: !provider.isInitialBalanceSet
                    ? () => _showEditInitialBalanceDialog(context, provider)
                    : null,
                onReset: provider.isInitialBalanceSet
                    ? () => _showResetBalanceConfirmDialog(context, provider)
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'PEMASUKAN',
                      totalIncome,
                      const Color(0xFF10B981),
                      isDark,
                      isObscured,
                      textPrefix: '+',
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      'PENGELUARAN',
                      totalExpense,
                      const Color(0xFFF43F5E),
                      isDark,
                      isObscured,
                      textPrefix: '-',
                      isCompact: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Budget Limit Card (card-style like Total Saldo)
          _buildBudgetCard(context, provider, currentMonthExpenses, isDark, isObscured),
          const SizedBox(height: 10),

          // Category Budget Section (hidden by default, revealed by toggle)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return SizeTransition(sizeFactor: animation, child: child);
            },
            child: _showCategoryBudgets
                ? Padding(
                    key: const ValueKey('catBudgets'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildCategoryBudgetSection(context, provider, transactions, isDark, isObscured),
                  )
                : const SizedBox.shrink(key: ValueKey('catBudgetsHidden')),
          ),
          const SizedBox(height: 10),

          // Charts
          _buildDonutChartCard(transactions, isDark),
          const SizedBox(height: 10),
          _buildBarChartCard(transactions, isDark),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
