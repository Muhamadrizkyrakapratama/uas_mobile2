import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutTab extends StatefulWidget {
  const AboutTab({super.key});

  @override
  State<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
  String _version = '1.2.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/images/logo.png', height: 90, width: 90, fit: BoxFit.contain),
          ),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFFF43F5E)],
            ).createShader(Offset.zero & bounds.size),
            child: const Text(
              'SimPay',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Colors.white, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"Catat masuknya dikit, keluarnya banyak."',
            style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _buildSection(
            context,
            icon: Icons.info_outline,
            title: 'Sekilas Aplikasi',
            child: Text(
              'SimPay adalah aplikasi pencatatan keuangan pribadi yang ringan, modern, dan bekerja sepenuhnya offline. '
              'Dirancang agar mudah digunakan oleh siapa saja untuk memantau pemasukan, pengeluaran, dan anggaran bulanan.',
              style: TextStyle(fontSize: 13, height: 1.6, color: subtitleColor),
            ),
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            icon: Icons.school_outlined,
            title: 'Cara Penggunaan',
            child: Column(
              children: const [
                _TutorialStep(number: '1', title: 'Atur Saldo Awal', desc: 'Dashboard \u2192 ketuk kartu Total Saldo \u2192 masukkan saldo awal Anda.'),
                _TutorialStep(number: '2', title: 'Catat Transaksi', desc: 'Tab Tambah \u2192 pilih Pemasukan / Pengeluaran \u2192 isi nominal, kategori, catatan.'),
                _TutorialStep(number: '3', title: 'Pantau Riwayat', desc: 'Tab Riwayat \u2192 gunakan filter atau pencarian untuk melihat transaksi.'),
                _TutorialStep(number: '4', title: 'Set Anggaran', desc: 'Dashboard \u2192 atur batas anggaran bulanan global maupun per kategori.'),
                _TutorialStep(number: '5', title: 'Cetak Laporan', desc: 'Riwayat \u2192 ketuk ikon cetak untuk menyimpan laporan sebagai PDF.', isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoTile(context, icon: Icons.person_outline, label: 'Developer', value: 'Muhammad Rizky Raka Pratama', isDark: isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildInfoTile(context, icon: Icons.tag, label: 'Versi', value: 'v$_version', isDark: isDark)),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required IconData icon, required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF10B981), size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, {required IconData icon, required String label, required String value, required bool isDark}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF10B981), size: 18),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
    );
  }
}

class _TutorialStep extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  final bool isLast;
  const _TutorialStep({required this.number, required this.title, required this.desc, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 26, height: 26,
          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
          child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
        ),
        if (!isLast) Container(width: 1.5, height: 32, color: isDark ? Colors.white12 : Colors.black12),
      ]),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.5)),
          ]),
        ),
      ),
    ]);
  }
}
