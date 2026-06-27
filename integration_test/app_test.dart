import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kora/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Test', () {
    testWidgets('Verify app starts correctly', (tester) async {
      // Menjalankan aplikasi
      await app.main();
      
      // Tunggu hingga aplikasi selesai rendering frame awalnya
      // Menggunakan timeout 5 detik untuk memastikan semua service (Firebase dll) sempat inisialisasi
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Mengecek apakah widget MaterialApp utama berhasil di-load
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // Catatan: Karena aplikasi menggunakan Firebase & status login,
      // tampilan awal bisa LandingScreen, OnboardingScreen, atau HomeScreen.
      // Anda dapat menambahkan spesifik expect di sini sesuai flow yang ingin diuji.
    });
  });
}
