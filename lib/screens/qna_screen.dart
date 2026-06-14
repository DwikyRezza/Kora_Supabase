import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// High-performance Q&A screen using ValueNotifier + ListView.builder.
/// - Search filtering is isolated via ValueNotifier<String> so only the
///   list rebuilds on keystroke — AppBar and TextField stay untouched.
/// - ListView.builder lazily renders ExpansionTile items only when they
///   scroll into the viewport, keeping RAM usage minimal on low-end devices.
class QnaScreen extends StatefulWidget {
  const QnaScreen({super.key});

  @override
  State<QnaScreen> createState() => _QnaScreenState();
}

class _QnaScreenState extends State<QnaScreen> {
  /// Search query notifier — isolates rebuild scope to the list only.
  final ValueNotifier<String> _searchQuery = ValueNotifier('');

  /// Master Q&A dataset — immutable, loaded once.
  static const List<Map<String, String>> _allQa = [
    {
      'q': 'Mengapa data pencatatan makanan saya tidak langsung muncul di perangkat lain?',
      'a': 'KORA menerapkan sistem Asynchronous Offline-First. Data Anda langsung disimpan secara instan di database lokal HP Anda agar cepat dan hemat kuota. Sinkronisasi ke server cloud (Firestore) berjalan secara otomatis di latar belakang tanpa mengganggu kenyamanan Anda.',
    },
    {
      'q': 'Mengapa pelacakan lari saya tiba-tiba terhenti saat aplikasi dikeluarkan (di-minimize)?',
      'a': 'Sistem Android sering kali mematikan fungsi latar belakang secara agresif untuk menghemat baterai. Pastikan Anda telah memberikan izin \'Bypass Battery Optimization\' untuk aplikasi KORA agar sistem Android Foreground Service kami dapat menjaga kestabilan GPS.',
    },
    {
      'q': 'Bagaimana cara KORA menentukan target protein harian saya?',
      'a': 'Target protein dihitung secara otomatis berdasarkan berat badan aktif dan target kebugaran (fitness goal) Anda. Sistem kami menerapkan perhitungan ilmiah berkisar antara 1.5g hingga 2.0g dikalikan berat badan Anda saat ini.',
    },
    {
      'q': 'Mengapa indikator lari saya terkadang melompat atau jaraknya tidak bertambah saat saya diam?',
      'a': 'Sistem GPS KORA dilengkapi dengan Multi-layer Noise Filtering. Kami secara otomatis membuang titik koordinat dengan akurasi buruk dan menghentikan perhitungan jika pergerakan Anda di bawah 0.5 meter untuk mencegah gangguan akurasi akibat GPS drift.',
    },
    {
      'q': 'Apakah foto-foto latihan saya membuat penyimpanan HP menjadi penuh?',
      'a': 'Tidak. KORA menggunakan arsitektur Normalized Lazy Loading. Semua berkas foto dipisahkan ke dalam tabel khusus di database dan hanya akan dimuat ke memori saat Anda membuka halaman detail latihan tersebut secara spesifik.',
    },
    {
      'q': 'Bagaimana cara menghitung kalori dan protein yang saya butuhkan setelah latihan beban?',
      'a': 'KORA menggunakan formula otomatis internal pada model Workout untuk menghitung pengeluaran kalori berdasarkan durasi dan intensitas latihan Anda, serta menyajikan estimasi kebutuhan makro protein pemulihan secara proporsional.',
    },
    {
      'q': 'Apakah saya bisa menggunakan fitur GPS pelacakan lari tanpa koneksi internet sama sekali?',
      'a': 'Bisa. Komponen Android Foreground Service kami bekerja langsung membaca perangkat keras GPS internal ponsel Anda. Data koordinat rute akan ditampung sementara di buffer lokal SQLite dan peta rute akan langsung diperbarui begitu Anda mendapatkan sinyal internet kembali.',
    },
    {
      'q': 'Mengapa grafik pada halaman Laporan Mingguan saya tidak memunculkan data angkat beban?',
      'a': 'Periksa filter chip aktif di bagian atas halaman laporan Anda. Secara default, filter dapat diganti antara opsi \'Semua\', \'Lari\', atau \'Angkat Beban\' untuk menyajikan visualisasi metrik volume total kg dan set yang terisolasi dengan rapi.',
    },
    {
      'q': 'Mengapa nama atau foto profil saya di halaman Beranda Komunitas terkadang kosong?',
      'a': 'KORA menerapkan pemisahan data di Firestore antara data akun utama dan sub-dokumen profil. Jika hal ini terjadi, pastikan data koneksi sinkronisasi latar belakang Anda telah selesai memuat pembaruan sub-dokumen profil secara sempurna.',
    },
    {
      'q': 'Bagaimana cara kerja alarm darurat di dalam menu latihan?',
      'a': 'Menu latihan dilengkapi fitur proteksi darurat yang terhubung dengan whistleblower_service.dart. Fitur ini akan langsung memicu bunyi sirine audio bervolume tinggi beserta pola getaran konstan untuk menarik perhatian sekitar jika Anda mengalami kram atau cedera berat di rute lari.',
    },
  ];

  @override
  void dispose() {
    _searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tanya Jawab',
          style: TextStyle(
            color: AppTheme.accentOrange,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar (outside ValueListenableBuilder — never rebuilds) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: TextField(
              style: TextStyle(color: AppTheme.textPrimary),
              onChanged: (val) => _searchQuery.value = val.toLowerCase(),
              decoration: InputDecoration(
                hintText: 'Cari pertanyaan Anda...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Filtered list (rebuilds ONLY when search query changes) ──
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _searchQuery,
              builder: (context, query, _) {
                final filtered = _allQa.where((item) {
                  if (query.isEmpty) return true;
                  return item['q']!.toLowerCase().contains(query) ||
                      item['a']!.toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Pertanyaan tidak ditemukan.\nCoba kata kunci lain, Atlet!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        iconColor: AppTheme.accentOrange,
                        collapsedIconColor: AppTheme.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        title: Text(
                          item['q']!,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item['a']!,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
