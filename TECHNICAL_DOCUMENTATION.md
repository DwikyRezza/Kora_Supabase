# Kora — Dokumentasi Teknis & Analisis Arsitektur
## Personal Digital Assistant for Athletes

**Versi:** 1.0.0+1  
**Platform:** Flutter (Android, iOS)  
**Tech Stack:** Dart, Flutter, Firebase (Auth, Firestore, Storage), SQLite, Google Maps, Geolocator, Strava API, Groq AI API  
**Domain:** Athletic Performance Tracking — Workout Logging, Nutrition Monitoring, GPS Running Tracker, Social Feed, Cloud Synchronization

---

## 1. ARCHITECTURE & CODE STRUCTURE

### 1.1 Pendekatan Arsitektur: Service-Oriented Layered Architecture

Kora mengimplementasikan arsitektur **Service-Oriented Layered Architecture** yang merupakan adaptasi pragmatis dari Clean Architecture untuk skala aplikasi mobile MVP. Alih-alih mengikuti pattern BLoC atau Riverpod yang heavyweight, proyek ini memilih pendekatan **direct service invocation** dengan pemisahan tanggung jawab yang tegas melalui tiga layer utama:

```
┌──────────────────────────────────────────────────┐
│                  PRESENTATION LAYER               │
│         (screens/, widgets/, main.dart)           │
│   • StatefulWidget + ValueListenableBuilder       │
│   • IndexedStack navigation (persistent tabs)     │
│   • Responsive extension utilities                │
├──────────────────────────────────────────────────┤
│                   SERVICE LAYER                   │
│              (services/*.dart)                    │
│   • Business logic & orchestration                │
│   • Background task management                    │
│   • API integration & authentication              │
│   • Cloud sync engine                             │
├──────────────────────────────────────────────────┤
│                    DATA LAYER                     │
│         (models/*.dart, database_helper.dart)     │
│   • SQLite local database (sqflite)               │
│   • Firestore cloud persistence                   │
│   • SharedPreferences (app settings)              │
│   • Model serialization (toMap/fromMap)           │
└──────────────────────────────────────────────────┘
```

**Mengapa pendekatan ini penting untuk scalability:**

1. **Separation of Concerns** — Setiap service memiliki tanggung jawab tunggal. `AuthService` menangani autentikasi, `CloudSyncService` menangani sinkronisasi, `NotificationService` menangani notifikasi. Penambahan fitur baru (misalnya: integrasi wearable) cukup menambah service baru tanpa mengubah service yang sudah ada.

2. **Singleton Pattern untuk Resource Management** — `DatabaseHelper`, `NotificationService`, dan `StravaShareHandler` menggunakan singleton pattern (`factory constructor + _internal()`) untuk memastikan hanya ada satu instance yang mengelola koneksi database, notification channel, dan share handler di seluruh lifecycle aplikasi. Ini mencegah memory leak akibat duplikasi instance dan memastikan konsistensi data.

3. **Static Method Services** — Service seperti `AuthService`, `ProfileService`, `CloudSyncService`, dan `SocialService` menggunakan static methods secara konsisten. Ini menyederhanakan invocation dari screen manapun tanpa dependency injection framework, cocok untuk skala proyek saat ini.

### 1.2 Folder Structure

```
lib/
├── main.dart                          # Entry point, Firebase init, foreground task setup, navigation
├── models/                            # Data models dengan serialization logic
│   ├── body_measurement.dart          # Model pengukuran tubuh + BMI calculator
│   ├── exercise_definition.dart       # Definisi exercise untuk weightlifting
│   ├── protein_entry.dart             # Model nutrisi + database makanan (4000+ baris)
│   ├── schedule_event.dart            # Model jadwal + status tracking
│   └── workout.dart                   # Model workout + kalkulasi kalori/protein
├── screens/                           # UI screens (30 screen files)
│   ├── active_workout_screen.dart     # Live workout tracking UI
│   ├── ai_nutrition_screen.dart       # AI-powered nutrition analyzer (Groq API)
│   ├── body_stats_screen.dart         # Body measurement dashboard
│   ├── home_screen.dart               # Dashboard utama
│   ├── landing_screen.dart            # Pre-auth landing page
│   ├── login_screen.dart              # Google Sign-In flow
│   ├── onboarding_screen.dart         # First-time user setup
│   ├── profile_screen.dart            # User profile & settings
│   ├── protein_screen.dart            # Nutrition tracking
│   ├── running_tracker_screen.dart    # GPS running + Google Maps (1210 baris)
│   ├── schedule_screen.dart           # Training schedule planner
│   ├── workout_screen.dart            # Workout hub (tab utama)
│   ├── workout_detail_screen.dart     # Detail view sebuah workout
│   ├── workout_setup_screen.dart      # Setup workout baru
│   ├── workout_summary_screen.dart    # Post-workout summary
│   ├── weightlifting_screen.dart      # Weightlifting-specific UI
│   ├── weekly_report_screen.dart      # Laporan mingguan
│   ├── social_screen.dart             # Social feed
│   ├── public_profile_screen.dart     # Profil pengguna lain
│   ├── search_screen.dart             # Search users
│   ├── strava_import_screen.dart      # Import dari Strava
│   ├── notification_screen.dart       # Notification center
│   ├── edit_profile_screen.dart       # Edit profil
│   └── setting_screen.dart            # App settings
├── services/                          # Business logic layer (14 service files)
│   ├── auth_service.dart              # Google Sign-In + Firebase Auth
│   ├── cloud_sync_service.dart        # Bidirectional sync: SQLite ↔ Firestore
│   ├── database_helper.dart           # SQLite ORM + migration (version 1→10)
│   ├── location_service.dart          # Foreground service manager
│   ├── meal_recommender_service.dart  # Rule-based meal recommender
│   ├── notification_service.dart      # Local + cloud notifications
│   ├── profile_service.dart           # Cloud-first profile management
│   ├── running_task_handler.dart      # GPS processing di Android Service
│   ├── settings_service.dart          # SharedPreferences wrapper
│   ├── social_service.dart            # Follow system + social feed
│   ├── storage_service.dart           # Base64 photo upload ke Firestore
│   ├── strava_service.dart            # OAuth2 + Strava API client
│   ├── strava_share_handler.dart      # Deep-link share handler
│   └── whistleblower_service.dart     # Audio alarm + vibration
├── theme/
│   └── app_theme.dart                 # Dual-theme system (dark/light)
├── utils/
│   └── responsive.dart                # Adaptive sizing extension
└── widgets/                           # Reusable UI components
    ├── comment_bottom_sheet.dart       # Komentar bottom sheet
    ├── common_widgets.dart            # Shared widgets
    └── feed_post_card.dart            # Social feed card
```

### 1.3 Design System & Theming Engine

[AppTheme](file:///d:/Rezza/Kuliah/Kora/lib/theme/app_theme.dart) mengimplementasikan **dual-theme architecture** menggunakan `ValueNotifier<ThemeMode>` sebagai reactive state holder. Setiap warna, gradient, dan style didefinisikan sebagai **computed getters** yang merespons perubahan `isDarkMode`:

- **Dark Theme** — Deep navy palette (`#0A0E1A` background, `#131929` surface) dengan neon accent (`#39FF8F` green, `#00D4FF` blue) untuk nuansa sport-tech premium
- **Light Theme** — Soft white palette (`#F7F9FC` background, `#FFFFFF` surface) dengan saturated accent (`#00B359` green, `#0088CC` blue)

Theming mencakup: `ColorScheme`, `AppBarTheme`, `BottomNavigationBarTheme`, `CardThemeData`, `InputDecorationTheme`, `ElevatedButtonTheme`, dan `DividerThemeData` — memastikan konsistensi visual di seluruh widget tree tanpa konfigurasi berulang.

---

## 2. CORE LOGIC & BACKGROUND SERVICES

### 2.1 GPS Running Tracker — Android Foreground Service

Sistem pelacakan lari adalah **core feature paling kompleks** di Kora, melibatkan tiga komponen yang bekerja secara kooperatif:

#### Arsitektur Tiga-Lapis GPS Tracker:

```
┌─────────────────────────────────────────────────────┐
│  Flutter UI (running_tracker_screen.dart)            │
│  • Google Maps rendering + polyline overlay          │
│  • Real-time stats display (pace, distance, elev.)   │
│  • Receives data via FlutterForegroundTask callback  │
├─────────────────────────────────────────────────────┤
│  Communication Bridge                                │
│  • FlutterForegroundTask.sendDataToMain() ← Service  │
│  • FlutterForegroundTask.sendDataToTask() → Service  │
│  • JSON-serialized Map<String, dynamic> protocol     │
├─────────────────────────────────────────────────────┤
│  Android Service (running_task_handler.dart)         │
│  • Geolocator GPS stream (1s interval, 1m filter)    │
│  • Distance calculation (Haversine via Geolocator)   │
│  • Elevation gain tracking                           │
│  • Split-per-km recording                            │
│  • Notification updates (Strava-style)               │
│  • Pause/Resume state machine                        │
└─────────────────────────────────────────────────────┘
```

#### Cara Kerja Background Service (RunningTaskHandler):

[RunningTaskHandler](file:///d:/Rezza/Kuliah/Kora/lib/services/running_task_handler.dart) berjalan **di dalam Android Foreground Service** (bukan di Flutter isolate), yang berarti ia tetap aktif meskipun aplikasi di-minimize atau layar dimatikan.

**Lifecycle:**

1. **Inisialisasi** — `FlutterForegroundTask.initCommunicationPort()` dipanggil di `main()` SEBELUM `runApp()`. Ini membuka port komunikasi IPC (Inter-Process Communication) antara Flutter UI dan Android Service.

2. **Start** — [LocationService.startService()](file:///d:/Rezza/Kuliah/Kora/lib/services/location_service.dart) memanggil `FlutterForegroundTask.startService()` dengan parameter:
   - `serviceId: 256` — ID unik untuk foreground service
   - `callback: startRunningTaskCallback` — top-level function yang menginisialisasi `RunningTaskHandler`
   - `eventAction: ForegroundTaskEventAction.repeat(1000)` — `onRepeatEvent` dipanggil setiap 1 detik

3. **GPS Processing** — `_startGpsStream()` menggunakan `Geolocator.getPositionStream()` dengan `AndroidSettings`:
   - `accuracy: LocationAccuracy.high` — menggunakan GPS hardware
   - `distanceFilter: 1` — minimum 1 meter pergerakan untuk trigger callback
   - `intervalDuration: 1 second` — polling interval

4. **Distance Calculation Algorithm** (`_onPositionUpdate`):
   - **Accuracy Filter** — Titik GPS dengan akurasi > 100m dibuang (kecuali titik pertama)
   - **Teleport Detection** — Segmen ≥ 200m dianggap GPS drift, tidak dihitung sebagai jarak
   - **Movement Threshold** — Hanya segmen ≥ 0.5m yang menambah distance counter
   - **Haversine Formula** — `Geolocator.distanceBetween()` menghitung jarak aktual antara dua koordinat GPS

5. **Elevation Tracking**:
   - `_elevationGain` hanya menambahkan selisih altitude positif > 0.5m (menghindari noise barometer)
   - `_maxElevation` di-track secara running max

6. **Split Recording** — Setiap kelipatan 1km floor(distance), waktu split direkam dalam format `MM:SS`

#### Efisiensi Baterai & Memori:

- **Wake Lock** — `allowWakeLock: true` menjaga CPU aktif tanpa menyalakan layar
- **WiFi Lock** — `allowWifiLock: true` menjaga koneksi untuk map tiles
- **Battery Optimization Bypass** — `requestIgnoreBatteryOptimization()` mencegah Android Doze mode membunuh service
- **Distance Filter (1m)** — Mencegah GPS jitter memicu komputasi berlebihan
- **Notification `onlyAlertOnce: true`** — Mencegah sound/vibrate berulang saat update notifikasi

#### State Machine Pause/Resume:

Handler mengimplementasikan state machine sederhana:
- `_elapsedAtPause` menyimpan elapsed time saat pause
- `_runStartTime` di-set `null` saat pause agar `onRepeatEvent` skip perhitungan
- Saat resume, `_runStartTime = DateTime.now()` dan elapsed dihitung sebagai `_elapsedAtPause + difference(now, _runStartTime)`
- `_lastValidPosition` di-reset saat resume untuk mencegah lompatan jarak

#### Kontrol dari Notifikasi:

Tombol notifikasi (`pause_btn`, `resume_btn`, `finish_btn`) langsung ditangani oleh `onNotificationButtonPressed()` di dalam service tanpa perlu membuka app. Saat tombol "Stop" ditekan, `FlutterForegroundTask.launchApp()` otomatis membawa app ke foreground untuk menampilkan summary.

### 2.2 Sinkronisasi Data dengan API Eksternal

#### 2.2.1 Strava Integration — OAuth 2.0 Flow

[StravaService](file:///d:/Rezza/Kuliah/Kora/lib/services/strava_service.dart) mengimplementasikan **OAuth 2.0 Authorization Code Flow** secara lengkap:

1. **Authorization** — `FlutterWebAuth2.authenticate()` membuka browser untuk consent Strava, dengan callback scheme `Kora://callback`
2. **Token Exchange** — Authorization code ditukar dengan `access_token` + `refresh_token` via POST ke `https://www.strava.com/oauth/token`
3. **Auto-Refresh** — `getValidAccessToken()` memeriksa expiry dengan buffer 60 detik, lalu auto-refresh menggunakan `refresh_token` jika diperlukan
4. **Token Persistence** — Semua token disimpan di `SharedPreferences` (`strava_access_token`, `strava_refresh_token`, `strava_expires_at`)
5. **Error Recovery** — Jika refresh token invalid/kadaluarsa, semua token dihapus dan user diminta re-authenticate

**Activity Import Pipeline** (`importRecentActivities`):
- Fetch 20 aktivitas terbaru dari `/athlete/activities`
- Deduplikasi berdasarkan pattern `Strava#<activityId>: <name>` di field notes
- Mapping tipe aktivitas Strava → Kora (Run → running, WeightTraining → weightlifting, dll.)
- Kalkulasi kalori dan protein menggunakan formula `Workout.calculateCalories()` dan `Workout.calculateProteinNeeded()`

**Deep Link Share Handler** ([StravaShareHandler](file:///d:/Rezza/Kuliah/Kora/lib/services/strava_share_handler.dart)):
- Regex `strava\.com/activities/(\d+)` mengekstrak activity ID dari teks yang di-share
- Import detail aktivitas termasuk polyline rute, splits metrik, dan elevasi
- `ImportResult` sealed class pattern untuk handling berbagai state: `needsAuth`, `fetchFailed`, `notARun`, `tooShort`, `success`

#### 2.2.2 AI Nutrition Analysis — Groq API Integration

[AiNutritionScreen](file:///d:/Rezza/Kuliah/Kora/lib/screens/ai_nutrition_screen.dart) menggunakan **Groq API** (LLM inference) untuk menganalisis kandungan nutrisi makanan:

- **Prompt Engineering** — Sistem berperan sebagai "ahli gizi" dengan output format JSON terstruktur
- **Multi-food Analysis** — User bisa input beberapa makanan sekaligus dengan estimasi gram
- **Structured Output** — Response diparsing menjadi model nutrisi (protein, kalori, karbo, lemak, serat, gula, garam)
- **Auto-save** — Hasil analisis langsung disimpan ke SQLite dan di-sync ke Firestore

### 2.3 Local Notification System

[NotificationService](file:///d:/Rezza/Kuliah/Kora/lib/services/notification_service.dart) mengimplementasikan **multi-channel notification architecture**:

| Channel ID | Fungsi | Schedule Mode |
|---|---|---|
| `Kora_channel` | Notifikasi instan umum | Immediate |
| `Kora_schedule` | Pengingat jadwal latihan (30 menit sebelum) | `exactAllowWhileIdle` |
| `Kora_protein` | Pengingat makan siang (12:00) | `inexactAllowWhileIdle` |
| `Kora_protein_strict` | Warning makan malam (18:00) | `exactAllowWhileIdle` |
| `Kora_progress` | Laporan progress mingguan | `inexactAllowWhileIdle` |

**Fitur canggih:**
- **Zoned Scheduling** — Menggunakan `timezone` package untuk jadwal yang akurat mengikuti zona waktu lokal
- **Exact Alarm Permission** — `requestExactAlarmsPermission()` memastikan notifikasi penting (schedule, strict nutrition) tepat waktu bahkan di Doze mode
- **Reschedule All** — `rescheduleAllEvents()` membatalkan dan menjadwalkan ulang semua reminder saat ada perubahan jadwal
- **Cloud Notifications** — `addNotification()` menulis ke sub-collection `notifications` di Firestore untuk notifikasi sosial (follow, like, comment)

---

## 3. LOCAL STORAGE & STATE MANAGEMENT

### 3.1 SQLite Database Architecture

[DatabaseHelper](file:///d:/Rezza/Kuliah/Kora/lib/services/database_helper.dart) adalah **singleton ORM** yang mengelola 7 tabel dengan sistem migrasi incremental:

#### Schema Overview:

```sql
workouts              -- Riwayat latihan (running, weightlifting, basketball)
├── GPS data: polyline, elevation, splits
├── Metrics: duration, distance, calories, protein
└── Metadata: title, photos, notes

protein_entries       -- Log nutrisi harian
├── Macros: protein, carbs, fat, fiber, sugar, salt
├── Classification: mealType (breakfast/lunch/dinner/snack/water)
└── Extras: emojiStr, waterMl

schedule_events       -- Jadwal latihan & reminder
├── Status: pending → done | failed (auto-fail > 2 jam)
└── Type: workout, meal, rest, reminder

body_measurements     -- Tracking fisik tubuh
├── Core: weight, height, bodyFatPercentage
└── Circumference: chest, waist, hips, biceps

user_profiles         -- Cache profil user (SQLite mirror)
workout_sets          -- Detail set per workout (weightlifting)
temp_tracking_points  -- Buffer GPS points sementara
```

#### Database Migration Strategy (Version 1 → 10):

Sistem migrasi menggunakan **incremental ALTER TABLE** yang dibungkus `try-catch` per blok versi. Ini memungkinkan upgrade dari versi berapapun ke versi terbaru tanpa kehilangan data:

```dart
if (oldVersion < 2) { /* ADD COLUMN carbsGrams, fatGrams, fiber... */ }
if (oldVersion < 3) { /* CREATE TABLE body_measurements */ }
if (oldVersion < 4) { /* ADD COLUMN emojiStr */ }
// ... hingga version 10
```

Setiap `ALTER TABLE` dibungkus `try-catch` terpisah agar kegagalan satu kolom tidak menggagalkan migrasi keseluruhan — defensive programming untuk menangani edge case di production.

#### Query Optimization:

- **Date-range queries** — `getWorkoutsByDate()` dan `getProteinEntriesByDate()` menggunakan `BETWEEN` dengan ISO 8601 string yang memungkinkan range filtering efisien tanpa index tambahan
- **Frequent foods** — `getFrequentFoods()` menggunakan `GROUP BY foodName` + `COUNT(*) as freq` + `ORDER BY freq DESC` untuk predictive search berdasarkan riwayat
- **Lazy initialization** — Database hanya diinisialisasi saat pertama kali diakses (`Future<Database> get database async`)

### 3.2 Cloud-Local Hybrid Storage Strategy

Kora mengimplementasikan **SQLite-First, Firestore-Backup** architecture melalui [CloudSyncService](file:///d:/Rezza/Kuliah/Kora/lib/services/cloud_sync_service.dart):

```
┌─────────────┐     WRITE      ┌─────────────┐
│   SQLite    │ ──────────────→ │  Firestore  │
│  (Primary)  │  background    │  (Backup)    │
│  Fast read  │  sync          │  Cloud sync  │
└─────────────┘                 └─────────────┘
       ↑                              │
       │         READ                 │ RESTORE
       └──────────────────────────────┘
            (new device login)
```

**Write Path:**
1. Data ditulis ke SQLite terlebih dahulu (instant, offline-capable)
2. `CloudSyncService.backupToCloud()` dipanggil secara background
3. Data dikelompokkan per tanggal (nutrition) atau per ID (workout, schedule) untuk efisiensi batch
4. Firestore `batch.commit()` mengirim semua perubahan dalam satu atomic operation

**Read Path:**
- Selalu baca dari SQLite (zero-latency, offline-first)
- Firestore Offline Persistence diaktifkan dengan `CACHE_SIZE_UNLIMITED` untuk data real-time

**Restore Path (Device Baru):**
1. `CloudSyncService.isLocalDataEmpty()` mengecek apakah SQLite lokal kosong
2. Jika kosong, `restoreAllFromCloud()` menarik semua data dari Firestore
3. Empat restore method berjalan **paralel** via `Future.wait()`:
   - `_restoreNutrition()` — Iterasi dokumen per tanggal, insert ulang ke SQLite
   - `_restoreWorkouts()` — Iterasi dokumen workout, insert ulang
   - `_restoreSchedule()` — Iterasi + cleanup ID lama
   - `_restoreBodyMeasurements()` — Iterasi + insert ulang

**Schedule Sync (Bidirectional dengan Deletion Detection):**
```dart
// Deteksi dokumen yang sudah dihapus di lokal
final cloudIds = snapshot.docs.map((d) => d.id).toSet();
final localIds = events.map((e) => e['id'].toString()).toSet();
for (final cloudId in cloudIds) {
  if (!localIds.contains(cloudId)) {
    batch.delete(...); // Hapus dari cloud
  }
}
```

### 3.3 Profile Management — Cloud-First Strategy

[ProfileService](file:///d:/Rezza/Kuliah/Kora/lib/services/profile_service.dart) mengambil pendekatan berbeda: **Cloud-First** (Firestore only, tanpa SQLite). Ini karena profil user harus konsisten di semua device:

- **Target Protein Auto-Calculation** — Berdasarkan goal dan body weight:
  - Bulking: `weight × 2.0g`
  - Weightlifter: `weight × 1.8g`
  - Diet: `weight × 1.6g`
  - Runner: `weight × 1.5g`

- **Photo Resolution Chain** — Prioritas foto: URL baru (HTTPS/data:image) → foto lama yang valid → Google OAuth photo
- **Field-Level Update** — `updateProfileField()` memungkinkan update granular dengan auto-recalculate `targetProtein` jika `weight` atau `goal` berubah

### 3.4 State Management

Kora menggunakan **pragmatic state management** tanpa framework pihak ketiga:

| Mekanisme | Penggunaan | Scope |
|---|---|---|
| `ValueNotifier<ThemeMode>` | Theme switching | Global, reaktif via `ValueListenableBuilder` |
| `setState()` | UI state per-screen | Local widget state |
| `IndexedStack` | Tab persistence | Main navigation — mempertahankan state semua tab |
| `SharedPreferences` | App settings | Persistent key-value (dark mode, notification prefs, units) |
| `FlutterForegroundTask` callbacks | Service → UI data | Background-to-foreground communication |

**IndexedStack Strategy:**
`MainNavigation` menggunakan `IndexedStack` (bukan `PageView` atau navigator) untuk menjaga **semua 5 tab tetap hidup** di memory. Ini berarti state scroll, form input, dan data yang sudah di-load tidak hilang saat berpindah tab — trade-off memory untuk UX yang seamless.

**Quick Actions Integration:**
`QuickActions` package memungkinkan shortcut dari home screen Android:
- "Catat Telur" → langsung ke tab Nutrisi
- "Mulai Lari" → langsung ke tab Training
- "Lihat Jadwal" → langsung ke tab Plan

---

## 4. TECHNICAL CHALLENGES & OPTIMIZATION

### 4.1 GPS Accuracy vs Battery Drain

**Tantangan:** GPS polling berinterval tinggi (1 detik) sangat boros baterai, namun interval terlalu rendah mengurangi akurasi rute dan pace.

**Solusi yang diterapkan:**

1. **Multi-layer Noise Filtering:**
   - Akurasi > 100m → skip titik (kecuali titik pertama)
   - Segment distance ≥ 200m → deteksi sebagai "GPS teleport", skip distance calculation
   - Movement threshold 0.5m → filter jitter saat berdiri diam

2. **Moving Time vs Elapsed Time:**
   - `_elapsedSeconds` berjalan terus sejak start (wall clock)
   - `_movingSeconds` hanya bertambah saat ada pergerakan ≥ 0.5m
   - Ini memungkinkan kalkulasi pace yang akurat (pace = moving_time / distance)

3. **Elevation Noise Reduction:**
   - Hanya menghitung `elevationGain` jika selisih altitude > 0.5m (positif saja)
   - Init `_lastAltitude` dan `_maxElevation` dengan sentinel value `-9999.0`

### 4.2 Foreground Service Reliability

**Tantangan:** Android agresif mematikan background service untuk menghemat baterai (Doze mode, App Standby).

**Solusi:**

1. **Battery Optimization Bypass** — `requestIgnoreBatteryOptimization()` meminta user whitelist app
2. **Wake Lock + WiFi Lock** — Menjaga CPU dan WiFi aktif selama sesi lari
3. **Service Restart Guard** — Sebelum start baru, cek apakah service masih jalan dan stop dulu dengan polling hingga 10 iterasi (300ms interval):
   ```dart
   for (int i = 0; i < 10; i++) {
     await Future.delayed(const Duration(milliseconds: 300));
     if (!await FlutterForegroundTask.isRunningService) break;
   }
   ```
4. **GPS Error Auto-Recovery** — Jika stream error, restart otomatis setelah 3 detik delay:
   ```dart
   onError: (e) {
     Future.delayed(const Duration(seconds: 3), _startGpsStream);
   }
   ```

### 4.3 Cloud Sync tanpa Conflict Resolution

**Tantangan:** User bisa menggunakan app di multiple device. Bagaimana menjaga konsistensi data?

**Strategi yang dipilih: Cloud-Wins Merge**

- **Write** — SQLite first, Firestore background sync
- **Login (device baru)** — Firestore data SELALU menang, replace SQLite lokal
- **Schedule Deletion** — Cloud sync mendeteksi dokumen yang sudah dihapus di lokal dan menghapusnya dari cloud

Ini adalah simplifikasi yang disengaja — untuk use case personal fitness tracker, conflict resolution yang kompleks (CRDT, last-write-wins per field) tidak diperlukan karena user hanya aktif di satu device pada satu waktu.

### 4.4 Database Migration tanpa Data Loss

**Tantangan:** 10 versi database dengan perubahan schema yang berbeda-beda. Migration harus backward-compatible.

**Solusi:**
- Setiap `ALTER TABLE` dibungkus `try-catch` independen
- `CREATE TABLE IF NOT EXISTS` untuk tabel baru di migrasi
- Conditional `if (oldVersion < N)` memastikan setiap blok hanya dijalankan jika diperlukan
- `onUpgrade` dipanggil otomatis oleh `sqflite` saat versi database meningkat

### 4.5 Strava OAuth Token Lifecycle

**Tantangan:** Strava access token expire setelah 6 jam, dan refresh token bisa invalid jika user revoke access.

**Solusi:**
- **60-second buffer** — Token di-refresh 60 detik sebelum expiry sebenarnya: `if (now < expiresAt - 60)`
- **Graceful degradation** — Refresh token invalid → hapus semua token → throw `StravaTokenExpiredException` → UI prompt re-auth
- **Deduplikasi** — `Strava#<id>: <name>` pattern di notes field mencegah import aktivitas yang sama dua kali

### 4.6 Responsive Design tanpa Layout Breakpoints Tradisional

**Tantangan:** Aplikasi harus tampil konsisten di berbagai ukuran layar HP (360dp - 600dp+).

**Solusi:**
[Responsive](file:///d:/Rezza/Kuliah/Kora/lib/utils/responsive.dart) extension pada `BuildContext` memberikan **fluid scaling**:
- `_scale = (width / 360).clamp(0.75, 1.5)` — faktor skala berbasis lebar layar
- Font sizes, spacing, icon sizes, border radius, avatar sizes — semua di-clamp antara minimum dan maximum untuk mencegah ukuran yang terlalu kecil atau terlalu besar
- `RSpace` widget untuk SizedBox yang responsif tanpa hardcode pixel values

### 4.7 Social Feed — Firestore Query Limitation

**Tantangan:** Firestore `whereIn` query dibatasi maksimal 10 elemen. Jika user follow > 10 orang, tidak bisa fetch feed dalam satu query.

**Solusi saat ini (MVP):**
- Fetch 50 post terbaru dari koleksi global `feed_posts`
- Filter client-side berdasarkan daftar `followingUids`
- Ini acceptable untuk skala MVP dengan user base terbatas

### 4.8 Photo Storage — Base64 di Firestore

**Tantangan:** Firebase Storage memerlukan Security Rules yang kompleks untuk upload foto profil.

**Solusi pragmatis:**
[StorageService](file:///d:/Rezza/Kuliah/Kora/lib/services/storage_service.dart) mengonversi foto ke base64 dan menyimpannya langsung di dokumen Firestore:
- Size guard: warning jika file > 200KB
- Data URI format (`data:image/jpeg;base64,...`) bisa langsung ditampilkan di `Image.network()`
- Trade-off: Firestore document size limit 1MB vs simplicity tanpa Storage Rules

### 4.9 Meal Recommendation Engine

[MealRecommenderService](file:///d:/Rezza/Kuliah/Kora/lib/services/meal_recommender_service.dart) mengimplementasikan **rule-based recommendation**:
- **Budget Matching** — `dailyBudget / 3` = budget per makan → kategori Ekonomi (≤20K), Medium (20K-45K), Premium (>45K)
- **Goal Matching** — Diet/Cutting meals vs Bulking meals dari curated database
- **Randomized Selection** — Dari matched meals, pilih random untuk variasi

---

## Ringkasan Dependensi Kritis

| Package | Versi | Peran |
|---|---|---|
| `sqflite` | ^2.3.3 | Local database (primary storage) |
| `firebase_core` | ^3.12.1 | Firebase initialization |
| `firebase_auth` | ^5.5.1 | Google Sign-In authentication |
| `cloud_firestore` | ^5.6.12 | Cloud database + offline persistence |
| `flutter_foreground_task` | ^8.0.0 | Android foreground service (GPS tracker) |
| `geolocator` | ^14.0.2 | GPS positioning + distance calculation |
| `google_maps_flutter` | ^2.10.0 | Map rendering + polyline overlay |
| `flutter_local_notifications` | ^17.1.2 | Scheduled local notifications |
| `flutter_web_auth_2` | ^5.0.1 | Strava OAuth browser flow |
| `google_generative_ai` | ^0.4.6 | AI nutrition analysis (Groq) |
| `fl_chart` | ^0.69.0 | Charts & data visualization |
| `flutter_dotenv` | ^5.2.1 | Environment variable management |
| `audioplayers` | ^6.6.0 | Whistle alarm playback |
| `vibration` | ^3.1.8 | Haptic feedback + vibration patterns |
| `quick_actions` | ^1.0.9 | Android home screen shortcuts |
| `share_plus` | ^12.0.1 | Share workout to social/Strava |

---

*Dokumentasi ini dihasilkan berdasarkan analisis mendalam terhadap seluruh source code repositori Kora v1.0.0.*
