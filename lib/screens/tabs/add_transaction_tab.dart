import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';
import '../../utils/formatters.dart';

class AddTransactionTab extends StatefulWidget {
  final VoidCallback? onSuccess;

  const AddTransactionTab({super.key, this.onSuccess});

  @override
  State<AddTransactionTab> createState() => _AddTransactionTabState();
}

class _AddTransactionTabState extends State<AddTransactionTab> {
  final _formKey = GlobalKey<FormState>();
  
  String _type = 'expense'; // default is expense
  String? _selectedCategory;
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool get _hasUnsavedData =>
      _amountController.text.trim().isNotEmpty ||
      _descController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _resetCategory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // Reset category selection when type changes
  void _resetCategory() {
    if (_type == 'income') {
      _selectedCategory = TransactionProvider.incomeCategories.first;
    } else {
      _selectedCategory = TransactionProvider.expenseCategories.first;
    }
  }

  // Choose date using material date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF10B981),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Handle Form Submit
  void _submitForm() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final cleanAmountStr = _amountController.text.replaceAll('.', '');
    final amount = double.tryParse(cleanAmountStr) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal transaksi harus lebih dari 0!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final transactionDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    final description = _descController.text.trim().isEmpty
        ? (_type == 'income' ? 'Pemasukan' : 'Pengeluaran')
        : _descController.text.trim();

    // Confirmation dialog before saving
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Transaksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Simpan transaksi berikut?', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            _buildConfirmRow('Tipe', _type == 'income' ? 'Pemasukan' : 'Pengeluaran'),
            _buildConfirmRow('Kategori', _selectedCategory ?? '-'),
            _buildConfirmRow('Nominal', currencyFormat.format(amount)),
            _buildConfirmRow('Catatan', description),
          ],
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

    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();

    if (confirmed != true) return;

    final newTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      category: _selectedCategory ?? 'Lain-lain',
      amount: amount,
      date: transactionDate,
      description: description,
    );

    provider.addTransaction(newTx);

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaksi ${_type == 'income' ? 'Pemasukan' : 'Pengeluaran'} berhasil ditambahkan!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );

    // Reset fields
    _amountController.clear();
    _descController.clear();
    setState(() {
      _type = 'expense';
      _selectedDate = DateTime.now();
      _resetCategory();
    });

    // Callback to home page to redirect back to dashboard tab
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    }
  }

  // Helper widget for confirmation dialog rows
  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Select categories array based on active type
    final categories = _type == 'income' 
        ? TransactionProvider.incomeCategories 
        : TransactionProvider.expenseCategories;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (!_hasUnsavedData) {
          Navigator.of(context).maybePop();
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tinggalkan Form?'),
            content: const Text('Data yang sudah diisi akan hilang. Yakin ingin keluar?'),
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
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).maybePop();
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Tambah Transaksi Baru',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Custom Segmented Type Selector (Pemasukan vs Pengeluaran)
                    Row(
                      children: [
                        // Pemasukan Button
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _type = 'income';
                                _resetCategory();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _type == 'income'
                                    ? const Color(0xFF10B981).withOpacity(0.15)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _type == 'income'
                                      ? const Color(0xFF10B981)
                                      : (isDark ? Colors.white12 : Colors.black12),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_downward,
                                    size: 16,
                                    color: _type == 'income' ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pemasukan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _type == 'income' ? const Color(0xFF10B981) : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Pengeluaran Button
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _type = 'expense';
                                _resetCategory();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _type == 'expense'
                                    ? const Color(0xFFF43F5E).withOpacity(0.15)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _type == 'expense'
                                      ? const Color(0xFFF43F5E)
                                      : (isDark ? Colors.white12 : Colors.black12),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_upward,
                                    size: 16,
                                    color: _type == 'expense' ? const Color(0xFFF43F5E) : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pengeluaran',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _type == 'expense' ? const Color(0xFFF43F5E) : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Dropdown Kategori
                    const Text('Kategori', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      dropdownColor: isDark ? const Color(0xFF0D1B14) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                      items: categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Input Nominal (Amount)
                    const Text('Nominal (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Contoh: 50.000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                      inputFormatters: [
                        ThousandsSeparatorInputFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nominal transaksi tidak boleh kosong!';
                        }
                        final cleanValue = value.replaceAll('.', '');
                        if (double.tryParse(cleanValue) == null) {
                          return 'Nominal transaksi harus berupa angka!';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Input Tanggal (Date Picker Trigger)
                    const Text('Tanggal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white30 : Colors.black26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const Icon(Icons.calendar_month, size: 20, color: Color(0xFF10B981)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Catatan (Description)
                    const Text('Catatan / Keterangan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _type == 'income'
                            ? 'Contoh: Gaji bulan Januari'
                            : 'Contoh: Makan siang warteg',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Simpan Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    ),
    );
  }
}
