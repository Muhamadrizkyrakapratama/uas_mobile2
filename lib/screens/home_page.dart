import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/add_transaction_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/about_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = [
      const DashboardTab(),
      const AddTransactionTab(),
      const HistoryTab(),
      const AboutTab(),
    ];

    // Gradient styling for the Brand text (Green to Red matching the slogan)
    Widget brandTitle = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFFF43F5E)],
      ).createShader(Offset.zero & bounds.size),
      child: const Text(
        'SimPay',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );

    // Divider color matching theme
    final dividerColor = isDark
        ? const Color(0xFF1A2E23)
        : const Color(0xFFD6EDE3);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: dividerColor,
                width: 1.5,
              ),
            ),
          ),
          child: AppBar(
            title: Row(
              children: [
                // Logo Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 38,
                    width: 38,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                // Title + Slogan Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      brandTitle,
                      Text(
                        'Catat masuknya dikit, keluarnya banyak.',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF8FA899) : const Color(0xFF688072),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: isDark ? const Color(0xFFF2FAF6) : const Color(0xFF0F2015),
                ),
                onPressed: () {
                  context.read<TransactionProvider>().toggleTheme();
                },
                tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
      // Mobile Bottom Navigation Bar with top border divider
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: dividerColor,
              width: 1.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: theme.scaffoldBackgroundColor,
          selectedItemColor: theme.primaryColor,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Tambah',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline),
              activeIcon: Icon(Icons.info),
              label: 'Tentang',
            ),
          ],
        ),
      ),
    );
  }
}
