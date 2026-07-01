import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';
import '../../utils/report_printer.dart' as printer;
import '../../utils/formatters.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedType = 'all'; // 'all', 'income', 'expense'
  String _selectedMonth = 'all'; // 'all' or 'YYYY-MM'
  DateTime? _startDate;
  DateTime? _endDate;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Format currency
  String _formatAmount(double amount) {
    return _currencyFormat.format(amount);
  }

  // Show Date Range Picker
  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      end: _endDate ?? DateTime.now(),
    );

    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null ? initialDateRange : null,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF10B981),
                    onPrimary: Colors.white,
                    surface: Color(0xFF0D1B14),
                    onSurface: Color(0xFFCBDCD0),
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF10B981),
                    onPrimary: Colors.white,
                    surface: Color(0xFFF2FAF6),
                    onSurface: Color(0xFF0F2015),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        // Set end date to end of day to include transactions on that date
        _endDate = DateTime(pickedRange.end.year, pickedRange.end.month, pickedRange.end.day, 23, 59, 59);
      });
    }
  }

  // Clear Date Filters
  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  // --- EXPORT JSON BACKUP ---
  Future<void> _exportJson(TransactionProvider provider) async {
    try {
      final jsonStr = provider.exportBackupJson();
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final filename = 'simpay_backup_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([XFile(file.path)], text: 'Backup data SimPay', subject: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export: $e'), backgroundColor: const Color(0xFFF43F5E)),
        );
      }
    }
  }

  // --- EXPORT CSV ---
  Future<void> _exportCsv(TransactionProvider provider) async {
    try {
      final csvStr = provider.exportTransactionsCsv();
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final filename = 'simpay_transaksi_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csvStr);
      await Share.shareXFiles([XFile(file.path)], text: 'Data transaksi SimPay', subject: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export CSV: $e'), backgroundColor: const Color(0xFFF43F5E)),
        );
      }
    }
  }

  // --- IMPORT JSON BACKUP ---
  Future<void> _importJson(TransactionProvider provider) async {
    // Confirm before import
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Backup'),
        content: const Text(
          'Mengimpor file backup akan MENGGANTIKAN semua data transaksi saat ini. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Pilih File Backup JSON',
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final jsonStr = await file.readAsString();
      final success = await provider.importBackupJson(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Data berhasil diimpor!' : 'Format file tidak valid.'),
            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal import: $e'), backgroundColor: const Color(0xFFF43F5E)),
        );
      }
    }
  }

  // Show export/import bottom sheet
  void _showExportImportSheet(BuildContext context, TransactionProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0D1B14) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kelola Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF2FAF6) : const Color(0xFF0F2015),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ekspor atau impor data transaksi Anda',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                // Export JSON
                _buildSheetOption(
                  context: ctx,
                  icon: Icons.upload_file_outlined,
                  color: const Color(0xFF10B981),
                  title: 'Ekspor Backup (JSON)',
                  subtitle: 'Simpan semua data sebagai file backup',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportJson(provider);
                  },
                ),
                const SizedBox(height: 10),
                // Export CSV
                _buildSheetOption(
                  context: ctx,
                  icon: Icons.table_chart_outlined,
                  color: const Color(0xFF06B6D4),
                  title: 'Ekspor ke CSV',
                  subtitle: 'Format spreadsheet untuk Excel / Google Sheets',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportCsv(provider);
                  },
                ),
                const SizedBox(height: 10),
                // Import JSON
                _buildSheetOption(
                  context: ctx,
                  icon: Icons.download_outlined,
                  color: const Color(0xFFF59E0B),
                  title: 'Impor Backup (JSON)',
                  subtitle: 'Pulihkan data dari file backup sebelumnya',
                  isDark: isDark,
                  isWarning: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _importJson(provider);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetOption({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    bool isWarning = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.08) : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isWarning ? const Color(0xFFF59E0B).withOpacity(0.3) : color.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF2FAF6) : const Color(0xFF0F2015),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  // Delete transaction confirm
  Future<void> _deleteTransaction(TransactionProvider provider, Transaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Transaksi'),
          content: Text('Apakah Anda yakin ingin menghapus transaksi "${tx.description}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await provider.deleteTransaction(tx.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil dihapus.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  // Edit transaction dialog
  Future<void> _showEditTransactionDialog(TransactionProvider provider, Transaction tx) async {
    final formKey = GlobalKey<FormState>();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

    String editType = tx.type;
    String editCategory = tx.category;
    final descCtrl = TextEditingController(text: tx.description);
    final amountCtrl = TextEditingController(
      text: currencyFormat.format(tx.amount).trim(),
    );
    DateTime editDate = tx.date;

    // Build category list based on type
    List<String> getCategories(String type) {
      return type == 'income'
          ? TransactionProvider.incomeCategories
          : TransactionProvider.expenseCategories;
    }

    // Make sure category is valid for the current type
    if (!getCategories(editType).contains(editCategory)) {
      editCategory = getCategories(editType).first;
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            const accentColor = Color(0xFF10B981);
            final categories = getCategories(editType);

            return AlertDialog(
              title: const Text('Edit Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              content: SizedBox(
                width: double.maxFinite,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Type toggle
                        ToggleButtons(
                          isSelected: [editType == 'income', editType == 'expense'],
                          onPressed: (i) {
                            setStateDialog(() {
                              editType = i == 0 ? 'income' : 'expense';
                              // Reset category if not valid for new type
                              final cats = getCategories(editType);
                              if (!cats.contains(editCategory)) {
                                  editCategory = cats.first;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          selectedColor: Colors.white,
                          fillColor: editType == 'income' ? accentColor : const Color(0xFFF43F5E),
                          children: const [
                            Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Pemasukan')),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Pengeluaran')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Category dropdown
                        DropdownButtonFormField<String>(
                          value: editCategory,
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) => setStateDialog(() => editCategory = val ?? editCategory),
                          validator: (val) => val == null || val.isEmpty ? 'Pilih kategori' : null,
                        ),
                        const SizedBox(height: 12),
                        // Description
                        TextFormField(
                          controller: descCtrl,
                          decoration: InputDecoration(
                            labelText: 'Deskripsi',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Masukkan deskripsi' : null,
                        ),
                        const SizedBox(height: 12),
                        // Amount
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            ThousandsSeparatorInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Nominal (Rp)',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Masukkan nominal';
                            final cleaned = val.replaceAll('.', '').replaceAll(',', '');
                            if (double.tryParse(cleaned) == null) return 'Nominal tidak valid';
                            if ((double.tryParse(cleaned) ?? 0) <= 0) return 'Nominal harus > 0';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Date picker
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: editDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: isDark
                                        ? const ColorScheme.dark(primary: Color(0xFF10B981), onPrimary: Colors.white)
                                        : const ColorScheme.light(primary: Color(0xFF10B981), onPrimary: Colors.white),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) setStateDialog(() => editDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFF10B981), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('dd MMM yyyy', 'id_ID').format(editDate),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    if (!formKey.currentState!.validate()) return;
                    final cleanedAmount = amountCtrl.text.replaceAll('.', '').replaceAll(',', '');
                    final updatedTx = Transaction(
                      id: tx.id,
                      type: editType,
                      category: editCategory,
                      description: descCtrl.text.trim(),
                      amount: double.parse(cleanedAmount),
                      date: editDate,
                    );
                    Navigator.of(ctx).pop();
                    // Confirmation before saving
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (confirmCtx) => AlertDialog(
                        title: const Text('Konfirmasi Edit'),
                        content: const Text('Simpan perubahan transaksi ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmCtx, false),
                            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(confirmCtx, true),
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
                      await provider.updateTransaction(updatedTx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaksi berhasil diperbarui.'),
                            backgroundColor: Color(0xFF10B981),
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
            );
          },
        );
      },
    );

    descCtrl.dispose();
    amountCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Gather all categories for dropdown filter
    final allCategories = {
      ...TransactionProvider.incomeCategories,
      ...TransactionProvider.expenseCategories
    }.toList();

    // Gather unique months for month filter
    final uniqueMonths = provider.transactions.map((tx) {
      return "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}";
    }).toSet().toList()..sort((a, b) => b.compareTo(a));

    // Filter transaction list
    final filteredTransactions = provider.transactions.where((tx) {
      // 1. Search Query (description or category)
      final matchesSearch = _searchQuery.isEmpty ||
          tx.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.category.toLowerCase().contains(_searchQuery.toLowerCase());

      // 2. Type Filter
      final matchesType = _selectedType == 'all' || tx.type == _selectedType;

      // 3. Category Filter
      final matchesCategory = _selectedCategory == 'all' || tx.category == _selectedCategory;

      // 4. Month Filter
      final txMonthStr = "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}";
      final matchesMonth = _selectedMonth == 'all' || txMonthStr == _selectedMonth;

      // 5. Date Range Filter
      final matchesStartDate = _startDate == null || tx.date.isAfter(_startDate!) || tx.date.isAtSameMomentAs(_startDate!);
      final matchesEndDate = _endDate == null || tx.date.isBefore(_endDate!) || tx.date.isAtSameMomentAs(_endDate!);

      return matchesSearch && matchesType && matchesCategory && matchesMonth && matchesStartDate && matchesEndDate;
    }).toList();

    // Sort by date descending
    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Section Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Pencarian',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Cari deskripsi / kategori...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() { _searchQuery = ''; });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                    onChanged: (val) { setState(() { _searchQuery = val; }); },
                  ),
                  const SizedBox(height: 12),
                  // Type & Category Filters
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Tipe',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Semua', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'income', child: Text('Masuk', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'expense', child: Text('Keluar', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) { setState(() { _selectedType = val ?? 'all'; }); },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('Semua', overflow: TextOverflow.ellipsis)),
                            ...allCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) { setState(() { _selectedCategory = val ?? 'all'; }); },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Month and Date Range Pickers
                  DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Semua Bulan')),
                      ...uniqueMonths.map((m) {
                        final parts = m.split('-');
                        final monthInt = int.parse(parts[1]);
                        final yearStr = parts[0];
                        final monthNames = [
                          "Januari", "Februari", "Maret", "April", "Mei", "Juni",
                          "Juli", "Agustus", "September", "Oktober", "November", "Desember"
                        ];
                        final label = "${monthNames[monthInt - 1]} $yearStr";
                        return DropdownMenuItem(value: m, child: Text(label));
                      }),
                    ],
                    onChanged: (val) { setState(() { _selectedMonth = val ?? 'all'; }); },
                  ),
                  const SizedBox(height: 12),
                  _buildDateRangeSelector(context),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Transactions List Panel
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 480,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header of the list with counts
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transaksi (${filteredTransactions.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Badge when filters active
                              if (_searchQuery.isNotEmpty ||
                                  _selectedCategory != 'all' ||
                                  _selectedType != 'all' ||
                                  _selectedMonth != 'all' ||
                                  _startDate != null ||
                                  _endDate != null) ...[
                                ActionChip(
                                  label: const Text('Reset Filter', style: TextStyle(fontSize: 11, color: Colors.white)),
                                  backgroundColor: const Color(0xFFF43F5E),
                                  side: BorderSide.none,
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedCategory = 'all';
                                      _selectedType = 'all';
                                      _selectedMonth = 'all';
                                      _startDate = null;
                                      _endDate = null;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                icon: const Icon(Icons.print, size: 18, color: Color(0xFF10B981)),
                                onPressed: () {
                                  printer.printReport(filteredTransactions);
                                },
                                tooltip: 'Cetak Laporan',
                              ),
                              IconButton(
                                icon: const Icon(Icons.today, size: 18, color: Color(0xFFF59E0B)),
                                onPressed: () => _showDailyRecapSheet(context, provider.transactions),
                                tooltip: 'Rekap Harian',
                              ),
                              IconButton(
                                icon: const Icon(Icons.swap_vert_circle_outlined, size: 20, color: Color(0xFF06B6D4)),
                                onPressed: () => _showExportImportSheet(context, provider),
                                tooltip: 'Ekspor / Impor Data',
                              ),
                              IconButton(
                                icon: const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF7C3AED)),
                                onPressed: () => _showMonthSelectionSheet(context, provider.transactions),
                                tooltip: 'Ringkasan Bulanan (Wrapped)',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: filteredTransactions.isEmpty
                          ? _buildEmptyState()
                          : _buildMobileListView(provider, filteredTransactions),
                    ),
                  ],
                ),
              ),
            ),
          ),


        ],
      ),
    );
  }

  // Date Range Selector button/row
  Widget _buildDateRangeSelector(BuildContext context) {
    final hasDate = _startDate != null && _endDate != null;
    final text = hasDate
        ? "${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}"
        : "Pilih Rentang Tanggal";

    return InkWell(
      onTap: () => _selectDateRange(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasDate ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                    fontWeight: hasDate ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (hasDate)
              GestureDetector(
                onTap: () {
                  _clearDateFilter();
                },
                child: const Icon(Icons.close, size: 16, color: Colors.grey),
              )
            else
              const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Empty State Widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada transaksi yang ditemukan.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Coba sesuaikan filter Anda.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }



  // Mobile Responsive ListView Layout
  Widget _buildMobileListView(TransactionProvider provider, List<Transaction> list) {
    final controller = ScrollController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scrollbarColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return RawScrollbar(
      controller: controller,
      thumbColor: scrollbarColor,
      radius: const Radius.circular(99),
      thickness: 3.0,
      fadeDuration: const Duration(milliseconds: 300),
      timeToFade: const Duration(milliseconds: 600),
      child: ListView.separated(
        controller: controller,
        itemCount: list.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final tx = list[index];
          final isIncome = tx.type == 'income';
          final accentColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Leading icon
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accentColor.withOpacity(0.12),
                  child: Icon(
                    isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                    color: accentColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                // Middle: description, date + category + amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: description (full width)
                      Text(
                        tx.description,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Row 2: date + category chip + amount (next to category)
                      Row(
                        children: [
                          Text(
                            _dateFormat.format(tx.date),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tx.category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "${isIncome ? '+' : '-'}${_formatAmount(tx.amount).replaceFirst('Rp', '').trim()}",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: accentColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trailing: 3-dot menu only
                SizedBox(
                  height: 36,
                  width: 36,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    tooltip: 'Aksi',
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditTransactionDialog(provider, tx);
                      } else if (value == 'delete') {
                        _deleteTransaction(provider, tx);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 10),
                            Text('Edit', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: Color(0xFFF43F5E)),
                            SizedBox(width: 10),
                            Text('Hapus', style: TextStyle(fontSize: 13, color: Color(0xFFF43F5E))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  // ─── Monthly Wrapped Section (Bottom Sheets) ───────────────────────────

  void _showMonthSelectionSheet(BuildContext context, List<Transaction> allTransactions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Group transactions by "YYYY-MM"
    final Map<String, List<Transaction>> byMonth = {};
    for (final tx in allTransactions) {
      final key = "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}";
      byMonth.putIfAbsent(key, () => []).add(tx);
    }

    final sortedKeys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0D1B14) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Pilih Bulan Wrapped 🎁',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF2FAF6) : const Color(0xFF0F2015),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Lihat rangkuman penuh pengeluaran dan pemasukan bulanan Anda',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                if (sortedKeys.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Belum ada transaksi.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sortedKeys.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final monthKey = sortedKeys[index];
                        final parts = monthKey.split('-');
                        final year = int.parse(parts[0]);
                        final monthIdx = int.parse(parts[1]) - 1;
                        final monthLabel = "${monthNames[monthIdx]} $year";
                        final txs = byMonth[monthKey]!;

                        double totalIn = 0, totalOut = 0;
                        for (final tx in txs) {
                          if (tx.type == 'income') {
                            totalIn += tx.amount;
                          } else {
                            totalOut += tx.amount;
                          }
                        }
                        final net = totalIn - totalOut;

                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showMonthlyWrappedDetailSheet(
                              context,
                              monthKey,
                              txs,
                              monthLabel,
                              isDark,
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        monthLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${txs.length} Transaksi  •  Net: ${_currencyFormat.format(net)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: net >= 0 ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: isDark ? Colors.white30 : Colors.black.withOpacity(0.3),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMonthlyWrappedDetailSheet(
    BuildContext context,
    String monthKey,
    List<Transaction> transactions,
    String monthLabel,
    bool isDark,
  ) {
    double totalIncome = 0;
    double totalExpense = 0;
    final Map<String, double> incomeByCategory = {};
    final Map<String, double> expenseByCategory = {};

    for (final tx in transactions) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
        incomeByCategory[tx.category] = (incomeByCategory[tx.category] ?? 0) + tx.amount;
      } else {
        totalExpense += tx.amount;
        expenseByCategory[tx.category] = (expenseByCategory[tx.category] ?? 0) + tx.amount;
      }
    }

    final net = totalIncome - totalExpense;
    final accentColor = net >= 0 ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1B14) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Top drag indicator and Header row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Wrapped $monthLabel 🎁',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Overview Banner Box
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: net >= 0
                                ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                                : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Pemasukan', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Text(_currencyFormat.format(totalIncome), style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Pengeluaran', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                Text(_currencyFormat.format(totalExpense), style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  net >= 0 ? 'Surplus Bulanan ✨' : 'Defisit Bulanan ⚠️',
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _currencyFormat.format(net),
                                  style: TextStyle(
                                    color: net >= 0 ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Breakdown
                      if (incomeByCategory.isNotEmpty) ...[
                        _categoryBreakdownTitle('💰 Pemasukan dari Apa Saja', const Color(0xFF10B981), isDark),
                        const SizedBox(height: 10),
                        ..._buildCategoryRows(incomeByCategory, totalIncome, const Color(0xFF10B981), isDark),
                        const SizedBox(height: 24),
                      ],

                      if (expenseByCategory.isNotEmpty) ...[
                        _categoryBreakdownTitle('💸 Pengeluaran untuk Apa Saja', const Color(0xFFF43F5E), isDark),
                        const SizedBox(height: 10),
                        ..._buildCategoryRows(expenseByCategory, totalExpense, const Color(0xFFF43F5E), isDark),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1),
                // Action Buttons at bottom
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            printer.printMonthlyWrappedReport(
                              monthLabel: monthLabel,
                              totalIncome: totalIncome,
                              totalExpense: totalExpense,
                              incomeByCategory: incomeByCategory,
                              expenseByCategory: expenseByCategory,
                            );
                          },
                          icon: const Icon(Icons.print, color: Colors.white),
                          label: const Text('Cetak Ringkasan PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _categoryBreakdownTitle(String title, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFF2FAF6) : const Color(0xFF0F2015),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategoryRows(
    Map<String, double> data,
    double total,
    Color color,
    bool isDark,
  ) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((entry) {
      final pct = total > 0 ? (entry.value / total * 100) : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBDCD0) : const Color(0xFF2D4236),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _currencyFormat.format(entry.value),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 6,
                backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.85)),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _showDailyRecapSheet(BuildContext context, List<Transaction> allTransactions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Group transactions by "YYYY-MM-DD"
    final Map<String, List<Transaction>> byDay = {};
    for (final tx in allTransactions) {
      final key = "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}";
      byDay.putIfAbsent(key, () => []).add(tx);
    }

    final sortedKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0D1B14) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.today, color: Color(0xFFF59E0B), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Rekap Transaksi Harian 📅',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFF2FAF6) : const Color(0xFF0F2015),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ketuk tanggal untuk mem-filter transaksi di riwayat',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (sortedKeys.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Belum ada transaksi.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: sortedKeys.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final dateKey = sortedKeys[index];
                            final txs = byDay[dateKey]!;
                            final sampleDate = txs.first.date;
                            final dayLabel = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(sampleDate);

                            double totalIn = 0, totalOut = 0;
                            for (final tx in txs) {
                              if (tx.type == 'income') {
                                totalIn += tx.amount;
                              } else {
                                totalOut += tx.amount;
                              }
                            }
                            final net = totalIn - totalOut;

                            return InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _startDate = DateTime(sampleDate.year, sampleDate.month, sampleDate.day, 0, 0, 0);
                                  _endDate = DateTime(sampleDate.year, sampleDate.month, sampleDate.day, 23, 59, 59);
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dayLabel,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${txs.length} Transaksi',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (totalIn > 0)
                                          Text(
                                            '+ ${_formatAmount(totalIn)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF10B981),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        if (totalOut > 0)
                                          Text(
                                            '- ${_formatAmount(totalOut)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFF43F5E),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Net: ${net >= 0 ? '+' : ''}${_formatAmount(net)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: net >= 0 ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

