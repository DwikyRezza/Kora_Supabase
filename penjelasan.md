# Penjelasan Komprehensif Projek: Kora

Dokumen ini berisi penjelasan detail mengenai seluruh aspek teknis dan arsitektur dari projek **Kora - Athlete Sync App**, mencakup fundamental, fitur, integrasi, hingga panduan UI/UX.

---

## 1. Fundamental & Arsitektur Projek

**Nama & Konsep Utama:**
- **Nama Projek:** Kora
- **Masalah yang Diselesaikan:** Banyak pengguna kesulitan melacak aktivitas olahraga (lari dan angkat beban) serta nutrisi harian secara praktis. Mencatat makanan dan menghitung kalori/makro seringkali membosankan dan memakan waktu. Kora hadir sebagai *Personal Digital Assistant* *all-in-one* yang menyatukan pelacakan kebugaran dan otomatisasi perhitungan nutrisi menggunakan kecerdasan buatan (AI) agar pengguna dapat fokus pada progres kesehatan mereka tanpa terbebani oleh input data manual yang rumit.

**Tech Stack:**
- **Frontend Mobile:** Flutter & Dart
- **State Management:** BLoC (`flutter_bloc`)
- **Local Database:** SQLite (`sqflite`) untuk *offline-first data persistence*
- **Cloud Backend (BaaS):** Firebase (Firestore, Auth, Cloud Messaging, Storage)
- **Serverless API:** Vercel (Node.js) sebagai penghubung dan pengaman endpoint ke API pihak ketiga
- **AI Integration:** Groq API (menggunakan model Llama-3-70b)
- **Maps & Location:** Google Maps SDK for Flutter, Geolocator

**Arsitektur & Flow Data:**
- Aplikasi menerapkan pola arsitektur **Clean Architecture** yang dipadukan dengan **BLoC** (Business Logic Component). 
- **Flow Data:** Interaksi dari *User Interface* (UI) mengirimkan event ke BLoC. BLoC memproses logika bisnis dan meminta data ke lapisan *Repository*. *Repository* memutuskan apakah mengambil data dari *Local Database* (SQLite) untuk akses cepat/offline, atau mengambil/mensinkronkannya dengan *Cloud* (Firebase). Untuk fitur AI, *Repository* akan memanggil *Service* yang melakukan *HTTP request* ke Vercel atau langsung ke Groq API. State yang diperbarui oleh BLoC kemudian dipantulkan kembali ke UI secara reaktif.

---

## 2. Fitur Utama & Logic Bisnis

**Core Features:**
1. **Live Running Tracker:** Pelacakan rute lari, kecepatan (*pace*), dan jarak secara *real-time* dengan peta interaktif.
2. **Workout Logger:** Pencatatan sesi angkat beban (gym), set, repetisi, dan volume beban harian.
3. **AI Nutrition Scanner:** Input nama makanan berbasis teks (prompt) yang langsung diurai oleh AI menjadi nilai kalori, protein, karbohidrat, dan lemak.
4. **Weekly Progress Report:** Visualisasi grafik perkembangan fisik dan olahraga tiap pekan.
5. **Smart Reminders:** Pengingat jadwal olahraga (menggunakan Push Notifications & background timer).

**Spesifikasi Teknis Khusus:**
- **Background Service & GPS:** Untuk memastikan pelacakan lari tetap presisi meskipun layar mati atau aplikasi di-*minimize*, aplikasi menggunakan `flutter_foreground_task` (Isolate terpisah). Layanan ini terus mencatat titik GPS dari *Geolocator* tanpa di-*kill* oleh sistem operasi (Android/iOS).
- **Quick Actions:** Implementasi *homescreen shortcuts* (seperti "Catat Telur", "Mulai Lari", "Lihat Jadwal") agar pengguna bisa langsung melompat ke fitur inti dari luar aplikasi.

---

## 3. Integrasi & Pihak Ketiga

**API / Ekosistem:**
- **Groq API (Llama 3):** Digunakan murni sebagai otak NLP (*Natural Language Processing*) untuk fitur *AI Nutrition Scanner*. Prompt pengguna tentang makanan yang dikonsumsi dikirim ke Groq untuk dianalisis dan dikembalikan dalam format JSON terstruktur (makronutrisi).
- **Google Maps & Geocoding:** Menggambarkan *polyline* rute lari secara *live* dan mengubah koordinat GPS menjadi alamat jalan (*reverse geocoding*).
- **Firebase Ecosystem:** 
  - *Firebase Auth* (Google Sign-In) untuk masuk.
  - *Firestore* untuk penyimpanan data cloud tersinkronisasi.
  - *Firebase Cloud Messaging (FCM)* untuk notifikasi dari server Vercel.

---

## 4. Status Saat Ini & Goal Jangka Pendek

**Progress Saat Ini:**
- Aplikasi berada pada tahap **MVP (Minimum Viable Product)** yang solid. UI/UX sudah tersusun rapi (termasuk navigasi *bottom bar* dengan mode terang/gelap). Integrasi API (Groq, Firebase, Maps) dan logika *background tracking* juga sudah terpasang.

**Tantangan Saat Ini (Goal Jangka Pendek):**
- **Akurasi AI Nutrisi:** Memastikan model Llama-3 bisa memprediksi kalori makanan lokal/Indonesia dengan tingkat akurasi tinggi dan format respons (JSON) yang selalu konsisten untuk di-*parsing* oleh aplikasi.
- **Efisiensi Baterai:** Mengoptimalkan *polling* GPS pada layanan *background* agar tidak menyebabkan *battery drain* yang berlebihan.
- **Handling Offline-Sync:** Menyempurnakan resolusi konflik ketika data yang diubah di SQLite (saat offline) disinkronkan kembali ke Firestore.

---

## 5. Detail Arsitektur & Keamanan (Security)

**State Management & Desain Pattern:**
- Menggunakan **BLoC (Business Logic Component)** (contoh: `HomeBloc`, `AuthBloc`, `BodyStatsBloc`). Hal ini memastikan pemisahan yang sangat tegas antara kode UI (Widget) dan *Business Logic*. 

**Keamanan Data:**
- **Autentikasi:** Menggunakan *Firebase Auth* (Google Sign-In & Token JWT). Akses data di Firestore dilindungi dengan *Firestore Security Rules* (pengguna hanya bisa baca/tulis dokumen milik UID-nya sendiri).
- **Komunikasi Data:** Seluruh interaksi dengan API eksternal (Groq/Vercel) berjalan di atas protokol HTTPS yang terenkripsi.
- **Perlindungan Kunci API:** API Key (Groq, Maps) disimpan dengan aman di file `.env` (menggunakan `flutter_dotenv`) dan *environment variables* di server Vercel, sehingga tidak terekspos langsung di *source code* klien.

**Penanganan Error (Error Handling):**
- **Offline-First:** Jika internet mati, data otomatis tersimpan di SQLite lokal. Pengguna tidak akan merasakan *crash*. 
- **Retry Mechanism:** Akses ke AI dan sinkronisasi akan melakukan *auto-retry* saat koneksi jaringan kembali pulih.
- *Graceful degradation:* Jika GPS terputus saat berlari, aplikasi akan mengandalkan titik koordinat terakhir yang valid dan menyambung rute (*interpolasi*) secara visual begitu sinyal kembali.

---

## 6. Pipeline Data & Kecerdasan Buatan (AI)

**Dataset & Training:**
- Kora **tidak** melatih (training) model ML/CV dari awal. Aplikasi memanfaatkan kapabilitas LLM pra-latih (Llama-3-70b) via API. Fokus di sini adalah *Prompt Engineering*—menyusun prompt sistem secara cerdas agar model dapat mengenali makanan dari berbagai kueri (teks acak atau bahasa sehari-hari) dan mengembalikan estimasi makronutrisi.

**Pemrosesan Real-time & Latency:**
- Proses perhitungan nutrisi dilakukan di **Cloud (Groq LPU)**. Groq dipilih khusus karena arsitektur LPU (Language Processing Unit)-nya menawarkan inferensi LLM dengan latensi sangat rendah (nyaris *real-time*). Hal ini membuat UX terasa seperti perhitungan instan di HP secara lokal.

---

## 7. Skalabilitas & Manajemen Infrastruktur

**Sinkronisasi Data:**
- Mengandalkan pendekatan **Trigger-based / Event-driven sync**. Saat pengguna melakukan pencatatan di aplikasi (misal: tambah *workout*), data masuk ke SQLite, dan di latar belakang terjadi *trigger* asinkron untuk memperbarui dokumen di Firestore.

**Konkuransi (Multi-threading):**
- Di Flutter, proses berat tidak boleh menahan UI (Main Isolate). Oleh karena itu:
  1. *Background Tracking (GPS/Timer)* dijalankan di *isolate* terpisah menggunakan `flutter_foreground_task`. 
  2. *Parsing JSON* (dari respons AI atau Firebase) dan komputasi database dijalankan secara *asynchronous* (`Future`, `async/await`), dan bisa menggunakan `compute` (Isolate spawn) untuk memastikan UI (60/120 fps) tetap berjalan *smooth*.

---

## 8. UI/UX & User Persona

**Target Pengguna:**
- Atlet kasual hingga semi-pro.
- Pengunjung gym (*gym-goers*).
- Individu yang sedang menjalani diet atau peduli terhadap asupan makronutrisi, namun malas menggunakan aplikasi kalkulator kalori manual.

**Flow Pengalaman Pengguna (UX):**
- **Akses Cepat (Frictionless):** Hambatan utama pengguna olahraga adalah ribetnya mencatat. Kora memangkas ini dengan tombol aksi mengambang (FAB) besar dan sentral bertuliskan "LATIHAN", *Quick Actions* dari *home screen* OS, serta modal *Bottom Sheet* instan. 
- **AI Automation:** Alih-alih mencari nama makanan di database dengan men-*scroll*, pengguna cukup mengetik "Aku makan 2 potong ayam goreng dan nasi", AI akan memangkas proses *input* dari puluhan detik menjadi hanya 1-2 detik.
- **Aesthetic:** Mengedepankan antarmuka gelap (*Dark Mode*) yang elegan dengan animasi transisi yang mulus (*glow scroll behavior*) layaknya aplikasi premium kelas atas, untuk terus memompa motivasi (*hype*) pengguna saat berolahraga.

---

## 9. Struktur Direktori & File

Projek ini disusun menggunakan pendekatan *Feature-First* (atau *Feature-Driven*) yang terorganisir di dalam folder `lib/`. Berikut adalah penjelasannya:

```text
lib/
├── core/           # Berisi logika inti aplikasi seperti konfigurasi global, konstanta, atau utility umum.
├── features/       # Folder utama! Setiap fitur aplikasi memiliki foldernya sendiri, memisahkan secara tegas logic dan UI.
│   ├── activity_analytics/ # Modul analitik aktivitas lari & angkat beban.
│   ├── ainutrition/        # Modul integrasi AI Groq untuk nutrisi (Scanner makanan).
│   ├── analytics/          # Laporan mingguan/bulanan.
│   ├── auth/               # Modul login, register, dan onboarding (Firebase Auth).
│   ├── home/               # Layar beranda (Dashboard utama aplikasi).
│   ├── nutrition/          # Modul spesifik pencatatan makronutrisi.
│   ├── profile/            # Pengaturan akun, statistik tubuh (berat badan), dll.
│   ├── running/            # Fitur inti Live Running Tracker (Maps, GPS).
│   ├── schedule/           # Jadwal workout & sistem pengingat (reminders).
│   ├── social/             # Fitur sosial sederhana (berbagi progres/tampilan leaderboard).
│   └── workout/            # Modul spesifik Logging angkat beban/gym.
├── models/         # Kelas model data (struktur JSON/SQLite).
├── repositories/   # Lapisan abstraksi data (menghubungkan BLoC dengan Services/Database).
├── services/       # Integrasi pihak ketiga atau layanan sistem (contoh: NotificationService, ProfileService).
├── theme/          # Konfigurasi UI (Dark/Light mode, tipografi, warna primer/aksen).
├── utils/          # Fungsi bantuan (helper) seperti format tanggal, validasi input, dll.
├── widgets/        # Komponen UI yang dapat digunakan berulang (Reusable Widgets, spt: CustomButton).
└── main.dart       # Entry point utama aplikasi (Inisiasi FlutterForegroundTask, Provider BLoC, navigasi dasar).
```

### Mengapa Struktur Ini Dipilih?
- **Modular & Feature-First:** Memudahkan pengembangan (skalabilitas). Jika Anda ingin memperbaiki fitur "Lari", Anda cukup mencari di dalam `lib/features/running/` tanpa perlu mengacak-acak file *screen* atau *logic* dari fitur lain. Di dalam masing-masing folder fitur, umumnya dipecah lagi ke sub-folder seperti `bloc/`, `presentation/` (*screens*), dan *logic* spesifik fitur tersebut.
- **Pemisahan Perhatian (Separation of Concerns):** Memisahkan *UI layer* (`widgets/` dan folder `presentation/` di tiap fitur) dari *Business Logic* (`bloc/`) dan *Data layer* (`repositories/` & `services/`). Ini membuat kode jauh lebih mudah dibaca, di-*maintain*, dan diuji (*Unit Testing*).
