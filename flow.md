# Diagram Sistem Aplikasi Kora

---

### Gambar 1. Use Case Diagram Sistem Aplikasi Kora

```mermaid
graph LR
    User((Pengguna))

    subgraph KORA
        Login[Login dengan Google]
        Profile[Lengkapi Profil]
        Run[Tracking Lari]
        Strava[Impor Aktivitas Strava]
        Nutrition[Catat Nutrisi]
        Hydration[Pantau Hidrasi]
        Schedule[Kelola Jadwal Latihan]
        Report[Laporan Mingguan]
        Premium[Kelola Langganan Premium]
    end

    GoogleAuth[Google Auth]
    GPS[GPS / Location Service]
    StravaAPI[Strava API]
    GeminiAI[Gemini AI]
    Firestore[Cloud Firestore]

    User --> Login
    User --> Profile
    User --> Run
    User --> Strava
    User --> Nutrition
    User --> Hydration
    User --> Schedule
    User --> Report
    User --> Premium

    Login --> GoogleAuth
    Run --> GPS
    Strava --> StravaAPI
    Nutrition --> GeminiAI
    Profile --> Firestore
    Report --> Firestore
    Premium --> Firestore
```

Menggambarkan interaksi antara pengguna dengan fitur utama aplikasi Kora. Aktor utama pada sistem adalah pengguna, sedangkan aktor eksternal meliputi Google Auth, GPS/Location Service, Strava API, Gemini AI, dan Cloud Firestore. Pengguna dapat melakukan login, melengkapi profil, melacak aktivitas lari, mengimpor aktivitas dari Strava, mencatat nutrisi, memantau hidrasi, mengelola jadwal latihan, melihat laporan mingguan, dan mengelola langganan premium.

---

### Gambar 2. Flowchart Sistem Utama Aplikasi Kora

```mermaid
graph TD
    A[Buka Aplikasi] --> B{Sudah Login?}
    B -->|Belum| C[Login dengan Google]
    C --> D[Restore Data dari Cloud]
    D --> E{Profil Lengkap?}
    B -->|Sudah| D
    E -->|Belum| F[Onboarding]
    F --> G[Simpan Profil ke Firestore]
    G --> H[Dashboard]
    E -->|Sudah| H
    H --> I[Tracking Lari]
    H --> J[Impor Strava]
    H --> K[Catat Nutrisi]
    H --> L[Hidrasi Harian]
    H --> M[Jadwal Latihan]
    H --> N[Laporan Mingguan]
    H --> O[Langganan Premium]
```

Menunjukkan alur utama aplikasi mulai dari pengguna membuka aplikasi, melakukan login, proses restore data dari cloud, pengecekan kelengkapan profil, onboarding, hingga masuk ke dashboard. Setelah berada pada dashboard, pengguna dapat memilih fitur seperti tracking lari, impor Strava, pencatatan nutrisi, hidrasi harian, jadwal latihan, laporan mingguan, atau langganan premium.

---

### Gambar 3. DFD Level 0 Sistem Aplikasi Kora

```mermaid
graph LR
    User((Pengguna))
    GoogleAuth((Google Auth))
    GPS((GPS / Location Service))
    StravaAPI((Strava API))
    GeminiAI((Gemini AI))
    Firestore((Cloud Firestore))

    User -->|Data Profil, Nutrisi, Hidrasi, Jadwal| System
    System -->|Dashboard, Laporan, Rekomendasi| User

    GoogleAuth -->|Token Autentikasi| System
    System -->|Request Login| GoogleAuth

    GPS -->|Data Lokasi & Koordinat| System
    System -->|Aktifkan Tracking| GPS

    StravaAPI -->|Data Aktivitas Impor| System
    System -->|OAuth Request| StravaAPI

    GeminiAI -->|Hasil Analisis Nutrisi| System
    System -->|Request Analisis| GeminiAI

    Firestore -->|Data Sinkronisasi| System
    System -->|Upload & Sync Data| Firestore

    System[Sistem Aplikasi Kora]
```

Merupakan diagram konteks yang menunjukkan hubungan antara Sistem Aplikasi Kora dengan entitas eksternal. Entitas eksternal yang terlibat adalah pengguna, Google Auth, GPS/Location Service, Strava API, Gemini AI, dan Cloud Firestore. Diagram ini menggambarkan aliran data utama seperti data profil, nutrisi, hidrasi, jadwal, tracking lari, autentikasi, data lokasi, analisis nutrisi, dan sinkronisasi cloud.

---

### Gambar 4. DFD Level 1 Sistem Aplikasi Kora

```mermaid
graph TD
    User((Pengguna))
    GoogleAuth((Google Auth))
    GPS((GPS / Location Service))
    StravaAPI((Strava API))
    GeminiAI((Gemini AI))
    Firestore((Cloud Firestore))
    SQLite[(SQLite Local DB)]

    User -->|Kredensial| P1
    GoogleAuth -->|Token| P1
    P1[1. Autentikasi & Profil] -->|Data Profil| Firestore
    P1 -->|Profil Lokal| SQLite

    GPS -->|Koordinat GPS| P2
    P2[2. Manajemen Aktivitas Lari] -->|Data Lari| SQLite
    P2 -->|Sync Lari| Firestore

    StravaAPI -->|Aktivitas| P3
    P3[3. Impor Aktivitas Strava] -->|Data Strava| SQLite
    P3 -->|Sync Strava| Firestore

    GeminiAI -->|Analisis Nutrisi| P4
    P4[4. Manajemen Nutrisi & Hidrasi] -->|Data Nutrisi & Hidrasi| SQLite
    P4 -->|Sync Nutrisi| Firestore

    User -->|Jadwal & Alarm| P5
    P5[5. Manajemen Jadwal & Alarm] -->|Data Jadwal| SQLite
    P5 -->|Sync Jadwal| Firestore

    User -->|Request Premium| P6
    P6[6. Manajemen Premium] -->|Status Premium| Firestore

    SQLite -->|Data Agregat| P7
    P7[7. Laporan & Dashboard] -->|Laporan| User

    P8[8. Sinkronisasi Cloud] -->|Bidirectional Sync| Firestore
    SQLite -->|Local Changes| P8
    P8 -->|Cloud Changes| SQLite
```

Memecah proses utama Sistem Aplikasi Kora menjadi beberapa proses internal, yaitu autentikasi dan profil, manajemen aktivitas lari, impor aktivitas Strava, manajemen nutrisi dan hidrasi, manajemen jadwal dan alarm, manajemen premium, laporan dan dashboard, serta sinkronisasi cloud. Diagram ini juga menunjukkan penggunaan SQLite sebagai basis data lokal dan Cloud Firestore sebagai basis data cloud.

---

### Gambar 5. Struktur Database Aplikasi Kora

```mermaid
erDiagram
    SQLite {
        table workout_activities {
            int id PK
            string type
            datetime date
            double duration
            double distance
            double calories
            string notes
        }
        table nutrition_entries {
            int id PK
            string food_name
            double protein_grams
            double calories
            double carbs_grams
            double fat_grams
            string meal_type
            datetime date
        }
        table hydration_entries {
            int id PK
            int water_ml
            datetime date
        }
        table schedule_entries {
            int id PK
            string title
            string type
            datetime date
            string reminder
        }
        table strava_activities {
            int id PK
            string strava_id
            string type
            double distance
            double duration
            datetime date
        }
        table body_measurements {
            int id PK
            double weight
            double body_fat
            datetime date
        }
        table workout_photos {
            int id PK
            int workout_id FK
            string photo_path
            datetime created_at
        }
    }

    Firestore {
        collection users {
            string uid PK
            map profile
            string email
            string display_name
        }
        collection userData {
            map workout_activities
            map nutrition_entries
            map hydration_entries
            map schedule_entries
            map strava_activities
            map body_measurements
            map premium_status
        }
    }

    SQLite ||--|| Firestore : "CloudSyncService bidirectional sync"
```

Menunjukkan struktur penyimpanan data pada aplikasi Kora. Aplikasi ini menggunakan pendekatan hybrid database, yaitu SQLite Local Database dan Cloud Firestore. Data aktivitas, nutrisi, hidrasi, jadwal, aktivitas Strava, dan pengukuran tubuh disimpan pada SQLite sebagai penyimpanan lokal. Data tersebut kemudian disinkronkan ke Cloud Firestore. Khusus data profil pengguna, sistem menggunakan pendekatan cloud-first melalui dokumen pengguna pada Firestore.

---

### Gambar 6. Sequence Diagram Login dan Onboarding Aplikasi Kora

```mermaid
sequenceDiagram
    actor User as Pengguna
    participant App as Aplikasi Kora
    participant Google as Google Auth
    participant Firebase as Firebase Auth
    participant ProfileSvc as ProfileService
    participant Firestore as Cloud Firestore
    participant SQLite as SQLite Local DB

    User->>App: Buka Aplikasi
    App->>Google: Request Login (Google Sign-In)
    Google-->>App: Return ID Token
    App->>Firebase: Verifikasi Token
    Firebase-->>App: Auth Result (Success)

    App->>ProfileSvc: Check Profile Status
    ProfileSvc->>Firestore: Get User Profile Document
    Firestore-->>ProfileSvc: Profile Data

    alt Pengguna Belum Onboarding
        ProfileSvc-->>App: Profile Belum Lengkap
        App->>User: Tampilkan Halaman Onboarding
        User->>App: Input Data Profil
        App->>Firestore: Simpan Data Profil
        Firestore-->>App: Konfirmasi Simpan
        App->>User: Masuk ke Dashboard
    else Pengguna Sudah Onboarding
        ProfileSvc-->>App: Profile Lengkap
        App->>Firestore: Request Restore Data
        Firestore-->>App: Data Cloud
        App->>SQLite: Restore Data ke Local DB
        SQLite-->>App: Data Tersimpan
        App->>User: Masuk ke Dashboard
    end
```

Menggambarkan urutan interaksi pada proses login dan onboarding. Pengguna melakukan login melalui Google, kemudian sistem melakukan autentikasi menggunakan Firebase Authentication. Setelah login berhasil, ProfileService memeriksa data profil pada Cloud Firestore. Jika pengguna belum melakukan onboarding, sistem menampilkan halaman onboarding dan menyimpan data profil ke Firestore. Jika pengguna sudah melakukan onboarding, sistem melakukan restore data dari cloud ke SQLite sebelum masuk ke dashboard.

---

### Gambar 7. Sequence Diagram Tracking Lari Aplikasi Kora

```mermaid
sequenceDiagram
    actor User as Pengguna
    participant Screen as Running Screen
    participant LocationSvc as Location Service
    participant FGService as Foreground Service
    participant TaskHandler as RunningTaskHandler
    participant SQLite as SQLite Local DB
    participant Firestore as Cloud Firestore

    User->>Screen: Mulai Sesi Lari
    Screen->>LocationSvc: Aktifkan Pelacakan Lokasi
    LocationSvc->>FGService: Start Foreground Service
    FGService-->>Screen: Service Aktif

    loop Selama Sesi Lari Berlangsung
        FGService->>LocationSvc: Request GPS Update
        LocationSvc-->>TaskHandler: Kirim Data Koordinat GPS
        TaskHandler->>TaskHandler: Validasi Akurasi Koordinat
        TaskHandler->>TaskHandler: Hitung Jarak, Durasi, Pace, Elevasi
        TaskHandler-->>Screen: Update Statistik Real-time
        Screen-->>User: Tampilkan Data Lari
    end

    User->>Screen: Akhiri Sesi Lari
    Screen->>FGService: Stop Foreground Service
    FGService-->>Screen: Service Berhenti

    Screen->>TaskHandler: Finalisasi Data Aktivitas
    TaskHandler-->>Screen: Ringkasan Aktivitas

    Screen->>SQLite: Simpan Data Aktivitas Lari
    SQLite-->>Screen: Data Tersimpan

    Screen->>Firestore: Sinkronisasi ke Cloud
    Firestore-->>Screen: Konfirmasi Sync

    Screen->>User: Tampilkan Ringkasan Lari
```

Menunjukkan alur interaksi pada fitur tracking lari. Pengguna memulai sesi lari melalui halaman running, kemudian sistem mengaktifkan layanan pelacakan lokasi. Data GPS dikirim secara berkelanjutan ke RunningTaskHandler untuk divalidasi dan diolah menjadi statistik seperti jarak, durasi, pace, elevasi, dan rute. Setelah sesi selesai, data aktivitas disimpan ke SQLite dan disinkronkan ke Cloud Firestore.
