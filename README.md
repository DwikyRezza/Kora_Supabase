<h1 align="center">
  <img src="assets/icons/logo_splash_screen.png" alt="Kora Logo" width="120" />
  <br>
  Kora - Athlete Sync App
</h1>

<h4 align="center">Aplikasi Cerdas untuk Melacak Lari, Latihan Beban, dan Nutrisi Harian Anda dengan Bantuan AI.</h4>

---

## 🏃‍♂️ Tentang Kora
**Kora** adalah aplikasi pelacak kebugaran *all-in-one* yang dibangun menggunakan **Flutter**. Kora membantu atlet dan penggemar kebugaran untuk menyinkronkan aktivitas fisik mereka (seperti berlari dan angkat beban) serta memantau asupan kalori dan nutrisi harian menggunakan kecerdasan buatan (AI).

## ✨ Fitur Utama
*   🗺️ **Live Running Tracker**: Lacak rute lari Anda secara *real-time* di atas peta menggunakan integrasi Google Maps dan GPS presisi tinggi.
*   🏋️ **Workout Logger**: Catat setiap sesi angkat beban Anda dengan berbagai pilihan gerakan. Kora akan memonitor volume latihan dan perkembangan kekuatan Anda.
*   🥗 **AI Nutrition Scanner**: Punya makanan baru? Ketik nama makanan Anda, dan **Groq AI (Llama 3)** akan secara otomatis menganalisis kalori, protein, karbohidrat, dan lemak di dalamnya!
*   📊 **Weekly Progress Report**: Lihat grafik dan laporan progres latihan Anda setiap minggunya untuk menjaga motivasi.
*   ☁️ **Cloud Sync & Social**: Data Anda aman tersinkronisasi ke Firebase. Kora juga memungkinkan fitur sosial sederhana untuk mengikuti teman olahraga Anda.
*   🔔 **Smart Reminders**: Notifikasi latar belakang untuk mengingatkan jadwal olahraga atau target minum air Anda (via Firebase Cloud Messaging & Vercel Backend).

## 🛠️ Tech Stack
*   **Frontend Mobile**: Flutter & Dart (UI Dinamis & Mode Gelap/Terang)
*   **Local Database**: SQLite (Penyimpanan data *offline-first*)
*   **Cloud Backend (BaaS)**: Firebase (Firestore, Auth, Cloud Messaging)
*   **Serverless API**: Vercel (Node.js) untuk menghubungkan API pihak ketiga.
*   **AI Integration**: Groq API (Model Llama-3-70b)
*   **Maps Service**: Google Maps SDK for Android

## 🚀 Panduan Instalasi (Development)

### Prasyarat
*   Flutter SDK terinstal (versi terbaru)
*   Node.js (jika ingin menjalankan backend lokal)
*   Akun Firebase dan Groq API Key

### Langkah-langkah
1.  **Clone Repositori**
    ```bash
    git clone https://github.com/DwikyRezza/Kora.git
    cd athleteSync_app
    ```
2.  **Instal Dependensi**
    ```bash
    flutter pub get
    ```
3.  **Siapkan Environment Variables**
    Buat file `.env` di folder *root* proyek ini, dan tambahkan kunci Anda:
    ```env
    VERCEL_URL=https://<your-vercel-domain>.vercel.app
    MAPS_API_KEY=KUNCI_GOOGLE_MAPS_ANDA
    ```
4.  **Siapkan Firebase**
    *   Pastikan Anda menempatkan file `google-services.json` ke dalam direktori `android/app/`.
5.  **Jalankan Aplikasi**
    ```bash
    flutter run
    ```

---

*Dibuat untuk Tugas Besar Pemrograman Mobile.*
