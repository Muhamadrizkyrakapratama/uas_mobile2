import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';

class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ScreenshotController _screenshotController = ScreenshotController();
  int _currentPage = 0;
  late AnimationController _counterController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Previous month data
  late int _prevMonth;
  late int _prevYear;
  late String _monthName;

  late double _totalIncome;
  late double _totalExpense;
  late double _netBalance;
  late int _transactionCount;
  late String _topCategory;
  late double _topCategoryAmount;
  late Transaction? _biggestExpense;
  late double _budgetLimit;
  late double _budgetPercent;
  late String _persona;
  late String _personaEmoji;
  late String _personaDesc;

  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static const List<List<Color>> _slideGradients = [
    [Color(0xFF4F46E5), Color(0xFF7C3AED)], // Indigo-Purple (Pembuka)
    [Color(0xFF059669), Color(0xFF0891B2)], // Emerald-Cyan (Pemasukan)
    [Color(0xFFE11D48), Color(0xFFEA580C)], // Rose-Orange (Pengeluaran)
    [Color(0xFFD97706), Color(0xFFDC2626)], // Amber-Red (Top Kategori)
    [Color(0xFF2563EB), Color(0xFF7C3AED)], // Blue-Violet (Transaksi)
    [Color(0xFF9333EA), Color(0xFFEC4899)], // Purple-Pink (Biggest)
    [Color(0xFF065F46), Color(0xFF1E40AF)], // Green-Blue (Budget)
    [Color(0xFFBE185D), Color(0xFF7C3AED)], // Pink-Purple (Persona)
    [Color(0xFF111827), Color(0xFF1F2937)], // Dark (Summary)
  ];

  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    // Determine previous month
    final now = DateTime.now();
    _prevMonth = now.month == 1 ? 12 : now.month - 1;
    _prevYear = now.month == 1 ? now.year - 1 : now.year;
    _monthName = _monthNames[_prevMonth - 1];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _computeData();
      _fadeController.forward();
      _counterController.forward();
    });
  }

  void _computeData() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final txs = provider.transactions.where((tx) =>
        tx.date.month == _prevMonth && tx.date.year == _prevYear).toList();

    _totalIncome = txs
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    _totalExpense = txs
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);
    _netBalance = _totalIncome - _totalExpense;
    _transactionCount = txs.length;
    _budgetLimit = provider.budgetLimit;
    _budgetPercent =
        _budgetLimit > 0 ? (_totalExpense / _budgetLimit * 100) : 0;

    // Top spending category
    final Map<String, double> catTotals = {};
    for (var tx in txs.where((t) => t.type == 'expense')) {
      catTotals[tx.category] = (catTotals[tx.category] ?? 0) + tx.amount;
    }
    if (catTotals.isNotEmpty) {
      final top =
          catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      _topCategory = top.key;
      _topCategoryAmount = top.value;
    } else {
      _topCategory = 'Belum ada';
      _topCategoryAmount = 0;
    }

    // Biggest single expense
    final expenses = txs.where((t) => t.type == 'expense').toList();
    if (expenses.isNotEmpty) {
      expenses.sort((a, b) => b.amount.compareTo(a.amount));
      _biggestExpense = expenses.first;
    } else {
      _biggestExpense = null;
    }

    // Persona
    _determinePersona(catTotals);

    setState(() {});
  }

  void _determinePersona(Map<String, double> catTotals) {
    if (catTotals.isEmpty || _totalExpense == 0) {
      _persona = 'The Saver';
      _personaEmoji = '💰';
      _personaDesc = 'Gaes, lo hampir nggak belanja bulan ini. Legit hemat banget, respect!';
      return;
    }

    if (_budgetPercent > 100) {
      _persona = 'Budget Breaker';
      _personaEmoji = '😤';
      _personaDesc = 'Lo udah jebol budget bulan ini Gaes. It\'s okay, bulan depan kita atur lagi!';
      return;
    }

    final top = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
    switch (top.key) {
      case 'Makan':
      case 'Jajan':
        _persona = 'The Foodie';
        _personaEmoji = '🍜';
        _personaDesc = 'Perut adalah prioritas utama lo, Gaes. Dan nggak ada yang salah dengan itu!';
        break;
      case 'Langganan':
        _persona = 'Subscription Addict';
        _personaEmoji = '📱';
        _personaDesc = 'Lo berlangganan lebih dari yang lo ingat, Gaes. Worth it? Cek lagi yuk!';
        break;
      case 'Mobilitas':
        _persona = 'On The Move';
        _personaEmoji = '🚗';
        _personaDesc = 'Lo selalu on the go, Gaes. Jalanan tau banget siapa lo!';
        break;
      case 'Hiburan':
        _persona = 'Fun First';
        _personaEmoji = '🎮';
        _personaDesc = 'Work hard, play harder. Lo percaya banget sama filosofi ini, Gaes!';
        break;
      case 'Kuota/Wifi':
        _persona = 'Always Connected';
        _personaEmoji = '📶';
        _personaDesc = 'Lo nggak bisa hidup tanpa internet, Gaes. Dan jujur, siapa yang bisa?';
        break;
      default:
        _persona = 'The Balanced One';
        _personaEmoji = '⚖️';
        _personaDesc = 'Lo merata dalam semua pengeluaran, Gaes. True balance icon!';
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _counterController.reset();
    _fadeController.reset();
    _fadeController.forward();
    _counterController.forward();
  }

  String _formatAmount(double amount) => _currencyFormat.format(amount);

  Future<void> _shareWrapped() async {
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
      );
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/wrapped_summary.png');
        await file.writeAsBytes(imageBytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Financial Wrapped $_monthName $_prevYear ku di SimPay! 💸🎁',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan gambar.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _counterController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Slide builders ──────────────────────────────────────────────────────

  Widget _buildSlide({
    required int index,
    required Widget child,
  }) {
    final colors = _slideGradients[index];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Content
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(9, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _currentPage ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == _currentPage
                ? Colors.white
                : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildSwipeHint() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swipe_right_alt, color: Colors.white.withOpacity(0.5), size: 16),
            const SizedBox(width: 6),
            Text(
              'Geser untuk lanjut',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Slide 0: Pembuka
  Widget _slide0() {
    return _buildSlide(
      index: 0,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎁',
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 24),
              Text(
                'Financial\nWrapped',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_monthName $_prevYear',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Oke Gaes, ayo kita recap\nkeuangan lo bulan ini 💸',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 60),
              _buildSwipeHint(),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 1: Pemasukan
  Widget _slide1() {
    return _buildSlide(
      index: 1,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bulan ini\nyang masuk 👇',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 20,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _AnimatedNumber(
                value: _totalIncome,
                controller: _counterController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
                format: _currencyFormat,
              ),
              const SizedBox(height: 24),
              _totalIncome > 0
                  ? _infoChip('Dari $_transactionCount total transaksi bulan ini')
                  : _infoChip('Belum ada pemasukan bulan ini'),
              const SizedBox(height: 16),
              Text(
                _totalIncome > 5000000
                    ? 'Cuan banget bulan ini Gaes! 🔥'
                    : _totalIncome > 0
                        ? 'Lumayan masuk Gaes, keep it up!'
                        : 'Bulan ini belum ada pemasukan tercatat nih Gaes.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 2: Pengeluaran
  Widget _slide2() {
    return _buildSlide(
      index: 2,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tapi yang keluar\njuga nggak sedikit... 💸',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 20,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _AnimatedNumber(
                value: _totalExpense,
                controller: _counterController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
                format: _currencyFormat,
              ),
              const SizedBox(height: 24),
              if (_totalIncome > 0)
                _infoChip(
                    '${(_totalExpense / _totalIncome * 100).round()}% dari total pemasukan'),
              const SizedBox(height: 16),
              Text(
                _netBalance >= 0
                    ? 'Lo masih surplus ${_formatAmount(_netBalance)} bulan ini. Keren Gaes! 💪'
                    : 'Lo defisit ${_formatAmount(_netBalance.abs())} bulan ini. Hati-hati Gaes!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 3: Top Kategori
  Widget _slide3() {
    final catEmojis = {
      'Makan': '🍜', 'Jajan': '🧋', 'Langganan': '📱',
      'Mobilitas': '🚗', 'Kuota/Wifi': '📶', 'Hiburan': '🎮',
      'Lain-lain': '📦',
    };
    final emoji = catEmojis[_topCategory] ?? '💸';

    return _buildSlide(
      index: 3,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lo paling boros\ndi sini 👑',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 20,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                emoji,
                style: const TextStyle(fontSize: 72),
              ),
              const SizedBox(height: 12),
              Text(
                _topCategory,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              _AnimatedNumber(
                value: _topCategoryAmount,
                controller: _counterController,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                format: _currencyFormat,
              ),
              const SizedBox(height: 16),
              Text(
                'Kategori $_topCategory makan ${ _totalExpense > 0 ? (_topCategoryAmount / _totalExpense * 100).round() : 0}% dari total pengeluaran lo!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 4: Jumlah Transaksi
  Widget _slide4() {
    return _buildSlide(
      index: 4,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bulan ini lo udah\nbuka dompet...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 20,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _AnimatedCounter(
                value: _transactionCount,
                controller: _counterController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                ),
              ),
              Text(
                'kali',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _transactionCount > 30
                    ? 'Rajin banget nyatat Gaes! Lo the real financial planner 📊'
                    : _transactionCount > 10
                        ? 'Lumayan aktif nih bulan ini, good job! 👏'
                        : _transactionCount > 0
                            ? 'Lo masih mulai belajar nyatat nih, keep going Gaes!'
                            : 'Belum ada transaksi tercatat bulan ini nih Gaes.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 5: Pengeluaran Terbesar
  Widget _slide5() {
    return _buildSlide(
      index: 5,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pengeluaran\nterbesar lo... 🤑',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 20,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (_biggestExpense != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _biggestExpense!.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _infoChip(_biggestExpense!.category),
                      const SizedBox(height: 12),
                      _AnimatedNumber(
                        value: _biggestExpense!.amount,
                        controller: _counterController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                        format: _currencyFormat,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('d MMMM yyyy', 'id').format(_biggestExpense!.date),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ini yang bikin kantong paling berasa terkuras bulan ini, Gaes 😅',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ] else
                Text(
                  'Nggak ada pengeluaran tercatat bulan ini, Gaes. Mantap! 💪',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 20,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 6: Status Budget
  Widget _slide6() {
    Color statusColor;
    String statusText;
    String statusEmoji;

    if (_budgetLimit == 0) {
      statusColor = Colors.white;
      statusText = 'Lo belum atur budget bulanan nih Gaes. Set dulu yuk biar lebih terkontrol!';
      statusEmoji = '🎯';
    } else if (_budgetPercent <= 80) {
      statusColor = const Color(0xFF34D399);
      statusText = 'Lo masih aman! Pengeluaran lo masih di bawah batas. Proud of you Gaes! 🎉';
      statusEmoji = '✅';
    } else if (_budgetPercent <= 100) {
      statusColor = const Color(0xFFFBBF24);
      statusText = 'Hampir mentok nih Gaes! Sisa dikit, hati-hati ya sampai akhir bulan.';
      statusEmoji = '⚠️';
    } else {
      statusColor = const Color(0xFFF87171);
      statusText = 'Budget jebol ${(_budgetPercent - 100).round()}% Gaes! Bulan depan kita lebih hemat ya!';
      statusEmoji = '🚨';
    }

    final percent = _budgetLimit > 0 ? (_budgetPercent / 100).clamp(0.0, 1.2) : 0.0;

    return _buildSlide(
      index: 6,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusEmoji,
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 16),
              Text(
                'Status Budget\nBulan Ini',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 22,
                  height: 1.3,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (_budgetLimit > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedBuilder(
                    animation: _counterController,
                    builder: (_, __) {
                      return LinearProgressIndicator(
                        value: percent * _counterController.value,
                        minHeight: 16,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatAmount(_totalExpense),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    Text(
                      '/ ${_formatAmount(_budgetLimit)}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_budgetPercent.round()}% terpakai',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                statusText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 7: Persona
  Widget _slide7() {
    return _buildSlide(
      index: 7,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Berdasarkan data bulan ini...\nlo adalah seorang',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _personaEmoji,
                style: const TextStyle(fontSize: 72),
              ),
              const SizedBox(height: 12),
              Text(
                _persona,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  _personaDesc,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 8: Summary Card (shareable)
  Widget _slide8() {
    return _buildSlide(
      index: 8,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF111827), Color(0xFF1F2937)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '🎁',
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Financial Wrapped',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  '$_monthName $_prevYear',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        _SummaryRow(
                          label: '💚 Pemasukan',
                          value: _formatAmount(_totalIncome),
                          valueColor: const Color(0xFF34D399),
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: '❤️ Pengeluaran',
                          value: _formatAmount(_totalExpense),
                          valueColor: const Color(0xFFF87171),
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: '💳 Transaksi',
                          value: '$_transactionCount kali',
                          valueColor: const Color(0xFF60A5FA),
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: '👑 Top Kategori',
                          value: _topCategory,
                          valueColor: const Color(0xFFFBBF24),
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: '🎭 Persona',
                          value: '$_personaEmoji $_persona',
                          valueColor: Colors.white,
                        ),
                        const Spacer(),
                        Divider(color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SimPay',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Itu tadi recap keuangan lo,\nGaes! Keep it up! 🔥',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _shareWrapped,
                icon: const Icon(Icons.share, size: 18),
                label: const Text(
                  'Share Wrapped Lo! 📤',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Tutup',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = [
      _slide0(),
      _slide1(),
      _slide2(),
      _slide3(),
      _slide4(),
      _slide5(),
      _slide6(),
      _slide7(),
      _slide8(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) => slides[i],
          ),
          // Top: Progress dots + Close
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: _buildProgressDots()),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────

class _AnimatedNumber extends StatelessWidget {
  final double value;
  final AnimationController controller;
  final TextStyle style;
  final NumberFormat format;

  const _AnimatedNumber({
    required this.value,
    required this.controller,
    required this.style,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final current = value * controller.value;
        return Text(format.format(current), style: style);
      },
    );
  }
}

class _AnimatedCounter extends StatelessWidget {
  final int value;
  final AnimationController controller;
  final TextStyle style;

  const _AnimatedCounter({
    required this.value,
    required this.controller,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final current = (value * controller.value).round();
        return Text('$current', style: style);
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Helper widget for info chips in slides
Widget _infoChip(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
