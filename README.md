# Kora (AthleteSync)

Kora (AthleteSync) adalah aplikasi pelacakan kebugaran komprehensif (*all-in-one fitness tracker*) yang menggabungkan manajemen jadwal latihan, pencatatan nutrisi, integrasi alat pelacak lari (termasuk sinkronisasi dengan Strava), serta fitur jejaring sosial untuk memotivasi antar-pengguna.

Aplikasi ini dibangun menggunakan **Flutter** untuk antarmuka multi-platform, menggunakan **SQLite** sebagai penyimpanan luring (*offline first*), dan **Firebase** (Firestore, Auth, Storage) sebagai *backend* komputasi awan.

---

## 🎯 Fitur Utama

1. **Autentikasi & Profil Pengguna**
   - Registrasi dan login aman menggunakan Firebase Authentication.
   - Pengaturan metrik personal seperti Berat Badan, Tinggi Badan, Target Latihan (Bulking/Diet/Endurance), dan pengunggahan foto profil (Firebase Storage).

2. **Sistem Pelacakan Latihan (Workout Tracker)**
   - **Running Tracker**: Melacak rute lari, jarak, durasi, dan kalori secara *real-time* memanfaatkan sensor GPS bawaan perangkat.
   - **Weightlifting**: Pencatatan latihan angkat beban manual untuk mencatat repetisi, set, dan durasi.
   - **Integrasi Strava**: Mengimpor data aktivitas yang telah dilakukan melalui ekosistem Strava menggunakan Strava API.

3. **Pencatatan Nutrisi Cerdas (AI Nutrition)**
   - Fitur pencatatan asupan protein harian untuk mengukur pemenuhan target nutrisi.
   - Kalkulasi otomatis target protein berdasarkan berat badan dan gol latihan.

4. **Jadwal & Pengingat Latihan (Whistleblower)**
   - Perencanaan jadwal latihan untuk beberapa hari ke depan.
   - Alarm otomatis (Kora Assistant) yang mengingatkan pengguna jika waktu jadwal latihan telah tiba.

5. **Ekosistem Sosial Terintegrasi**
   - **Follow System**: Pengguna dapat mencari, mengikuti (Follow), dan berhenti mengikuti akun lain.
   - **Social Feed**: Mempublikasikan riwayat latihan (secara otomatis) ke lini masa Beranda (*Home Feed*) untuk dibagikan kepada pengikut.
   - **Interaksi**: Mendukung pemberian *Like* (Suka) dan *Comments* (Komentar) secara seketika (*real-time*).

6. **Sistem Sinkronisasi Awan (Cloud Sync)**
   - Aplikasi bekerja secara luring (*offline-first*) menggunakan database lokal (SQLite) agar tidak terhambat koneksi lambat.
   - Sinkronisasi di latar belakang ke Cloud Firestore sebagai basis data pusat untuk *backup* dan penyebaran interaksi sosial.

---

## 🔄 Alur Kerja Aplikasi (Application Workflow)

Berikut adalah urutan logika dan aliran interaksi sistem dari awal hingga akhir skenario:

### 1. Orientasi (*Onboarding*) & Autentikasi
1. Pengguna membuka aplikasi. Jika belum login, mereka akan diarahkan ke layar **Login / Daftar**.
2. Setelah pendaftaran berhasil (menyimpan `uid` di Firebase Auth), pengguna melalui tahap **Onboarding** untuk mengisi data awal (umur, berat badan, tinggi, tujuan).
3. Data orientasi ini disimpan di *Cloud Firestore* (tabel `users/uid/profile`) yang kemudian direplikasi ke perangkat lokal.

### 2. Dasbor Utama (*Home Dashboard*)
- Saat login sukses, pengguna akan melihat **Beranda (Home Screen)**. Beranda menyajikan ringkasan holistik:
  - Grafik capaian nutrisi/protein harian vs target.
  - Ringkasan total kalori, sesi, dan durasi latihan hari itu.
  - Kora Assistant: Jadwal/saran latihan terdekat (disertai tombol *Mulai*).
  - Feed Sosial (bagian bawah): Melihat daftar aktivitas teman-teman yang diikuti.

### 3. Eksekusi Aktivitas Latihan
1. Pengguna dapat memilih menu latihan, seperti **Lari (Running Tracker)**.
2. Aplikasi mengaktifkan API Lokasi, mencatat pergerakan *real-time*, menghitung jarak (km) dan laju (Pace).
3. Setelah menekan **Selesai**, ringkasan dicatat ke *Database Lokal (SQLite)*.
4. Di latar belakang, *Cloud Sync Service* melakukan dua hal:
   - Menyimpan *backup* latihan ini ke tabel `workouts` di Firestore.
   - Memanggil `SocialService.publishWorkoutToFeed()` yang membuat dokumen baru di tabel `feed_posts`. Ini memastikan teman-teman dapat melihat latihan tersebut.

### 4. Manajemen Nutrisi & Jadwal
- **Nutrisi**: Pengguna dapat masuk ke menu *Kamera Nutrisi* untuk menginput gram protein yang baru dimakan. Bar progres di dasbor akan otomatis bertambah secara proporsional.
- **Jadwal**: Saat menjadwalkan latihan besok pukul 06:00, aplikasi menjalankan servis *Background Timer/Worker*. Saat pukul 06:00 tiba, antarmuka **Whistleblower** (Alarm Pop-up dan Getaran) aktif menuntut pengguna untuk bersiap.

### 5. Interaksi Jejaring Sosial
1. Pengguna membuka ikon **Cari (Search)** untuk mencari *username* teman yang terdaftar, sistem akan mencari di `users` berdasarkan prefiks *username* huruf kecil (case-insensitive).
2. Dari hasil pencarian, profil publik teman dapat dibuka, lalu pengguna menekan tombol **Ikuti**. (Dokumen relasi terbuat di sub-koleksi `followers` & `following`).
3. Latihan apa pun yang diselesaikan oleh teman tersebut akan dirender dalam Beranda pengguna sebagai *Feed Post Card*.
4. Saat pengguna menekan ikon **Suka (Hati)** atau menulis komentar pada Bottom Sheet, *Firebase Transaction* langsung merevisi hitungan dan menampilkannya tanpa memuat ulang layar penuh.

---

## 🛠 Teknologi yang Digunakan
- **Frontend / UI**: Flutter & Dart (Dengan panduan gaya *Flat UI* melengkung radius 26px).
- **Local Storage**: `sqflite` untuk manajemen basis data SQLite.
- **Backend / Database**: Firebase (Auth, Firestore DB).
- **Penyimpanan Berkas**: Firebase Storage (Untuk foto profil).
- **Integrasi Eksternal**: Strava API OAuth2, Geolocator (untuk lari).

---

> Laporan ini mendokumentasikan struktur logika, alur perjalanan pengguna, serta modul komputasi pada ekosistem aplikasi pelacak kebugaran Kora.
