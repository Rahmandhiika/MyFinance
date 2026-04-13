# Product Requirements Document — MyFinance
**Owner:** Dika  
**Platform:** iOS (SwiftUI + SwiftData)  
**Version:** 3.0 Final  
**Status:** Ready for Development

---

## 1. Executive Summary

Aplikasi manajemen keuangan pribadi offline-first untuk iOS. Menggantikan Coda tracker yang tidak mobile-friendly. Semua data lokal, tidak ada server, tidak ada subscription. Input manual + voice input untuk kecepatan pencatatan. Fitur Aset menggunakan API harga real-time (koneksi internet opsional).

---

## 2. Prinsip Dasar

- **Offline-first** — semua fitur core berjalan tanpa internet (kecuali harga Aset)
- **Manual input** — tidak ada integrasi bank
- **Personal** — hanya untuk satu user (Dika), tidak ada multi-user
- **No onboarding** — app langsung buka ke Home, data kosong, user isi sendiri
- **No data seeding** — tidak ada kategori/pocket default, semua dibuat manual
- **No auth** — tidak ada FaceID/TouchID

---

## 3. Technical Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI |
| Database | SwiftData |
| Voice | SFSpeechRecognizer (on-device) |
| NLP | Custom rule-based parser (Bahasa Indonesia) |
| Charts | SwiftUI Charts |
| Network | URLSession (hanya untuk harga Aset) |
| Notifications | UserNotifications framework |
| Background | BackgroundTasks framework |

---

## 4. Navigasi — Tab Bar (5 Tab)

| # | Tab | Icon | Keterangan |
|---|---|---|---|
| 1 | Home | square.grid.2x2 | Dashboard + ringkasan bulanan |
| 2 | Transaksi | list.bullet | Riwayat transaksi per bulan |
| 3 | Voice | mic.fill | Center button, mic langsung aktif |
| 4 | Pocket | wallet.pass | Manajemen pocket/rekening |
| 5 | Pengaturan | gearshape | Konfigurasi, kategori, anggaran, dll |

Add transaksi bisa dilakukan dari Home (tombol +) dan dari tab Voice.

---

## 5. Data Model

### 5.1 Pocket

```
Pocket
├── id: UUID
├── nama: String
├── kelompokPocket: Enum (Biasa | Utang)
├── kategoriPocket: → KategoriPocket
├── saldo: Decimal
├── logo: Data?
├── isAktif: Bool (default: true)
├── catatan: String?
├── limit: Decimal?         // khusus Kartu Kredit / PayLater
└── createdAt: Date

KategoriPocket
├── id: UUID
└── nama: String
// Nilai: Rekening Bank, E-Wallet, E-Money, Dompet,
//        Kartu Kredit/PayLater, Akun Brand, Lainnya
```

### 5.2 Transaksi

```
Transaksi
├── id: UUID
├── tanggal: Date
├── nominal: Decimal
├── tipe: Enum (Pengeluaran | Pemasukan)
├── subTipe: Enum (Normal | SimpanKeTarget | PakaiDariTarget)
├── kategori: → Kategori?
├── pocket: → Pocket?           // wajib jika saldo ingin terpengaruh
├── catatan: String?
├── goalID: UUID?               // diisi jika subTipe = SimpanKeTarget / PakaiDariTarget
├── otomatisID: → TransaksiOtomatis?
└── createdAt: Date

TransferInternal
├── id: UUID
├── tanggal: Date
├── nominal: Decimal
├── pocketAsal: → Pocket
├── pocketTujuan: → Pocket
├── catatan: String?
└── createdAt: Date
```

### 5.3 Kategori

```
Kategori
├── id: UUID
├── nama: String
├── tipe: Enum (Pengeluaran | Pemasukan)
├── klasifikasi: Enum (KebutuhanPokok | GayaHidup)?   // khusus Pengeluaran
├── kelompokIncome: Enum (Gaji | Freelance | ProdukDigital |
│                         JasaProfesional | PassiveIncome |
│                         SocialMedia | Lainnya)?       // khusus Pemasukan
├── ikon: String               // SF Symbol name
├── ikonCustom: String?        // emoji custom
├── warna: String              // hex color
├── urutan: Int                // untuk drag reorder
└── createdAt: Date
```

### 5.4 Transaksi Otomatis

```
TransaksiOtomatis
├── id: UUID
├── nominal: Decimal
├── tipe: Enum (Pengeluaran | Pemasukan)
├── kategori: → Kategori?
├── pocket: → Pocket?
├── setiapTanggal: Int         // 1–28
├── catatan: String?
├── isAktif: Bool (default: true)
└── createdAt: Date
```

### 5.5 Anggaran

```
Anggaran
├── id: UUID
├── nominal: Decimal
├── tipeAnggaran: Enum (Bulanan | Harian)
├── kategori: → Kategori?      // null = batas keseluruhan
├── berulang: Bool             // Bulanan: reset otomatis tiap bulan
├── pindahan: Bool             // Bulanan: sisa dibawa ke bulan depan
├── harianBerulang: Bool       // Harian: tampil di semua hari
├── bulan: Int?                // 1–12, untuk Bulanan
├── tahun: Int?                // untuk Bulanan
├── tanggal: Date?             // untuk Harian
└── createdAt: Date
```

### 5.6 Target (Goals)

```
Target
├── id: UUID
├── nama: String
├── targetNominal: Decimal
├── deadline: Date?
├── ikonCustom: String?        // emoji bebas
├── ikon: String               // SF Symbol name
├── warna: String              // hex color
├── catatan: String?
├── isSelesai: Bool (default: false)
└── createdAt: Date

SimpanKeTarget
├── id: UUID
├── target: → Target
├── tanggal: Date
├── nominal: Decimal
├── catatan: String?
└── createdAt: Date

// Computed:
// Tersimpan = Σ SimpanKeTarget.nominal per Target
// Sisa      = targetNominal − Tersimpan
// Progress  = Tersimpan / targetNominal × 100
// Perlu Menyisihkan/Bulan = Sisa / sisa bulan hingga deadline
```

### 5.7 Aset

```
Aset
├── id: UUID
├── tipe: Enum (Saham | Kripto | Reksadana | Emas)
├── nama: String
├── kode: String?

// Saham
├── lot: Decimal?
├── hargaPerLembar: Decimal?

// Kripto
├── mataUang: Enum (IDR | USDT)?
├── totalInvestasi: Decimal?
├── hargaPerUnit: Decimal?

// Reksadana
├── jenisReksadana: String?    // Campuran, Saham, Index ETF, dll
├── totalInvestasi: Decimal?
├── nav: Decimal?              // Harga per Unit (NAV)

// Emas
├── jenisEmas: Enum (LMAntam | UBS | AntamRetro | UBSRetro)?
├── tahunCetak: Int?
├── beratGram: Decimal?
├── hargaBeliPerGram: Decimal?

├── nilaiSaatIni: Decimal      // diupdate via API atau manual
├── catatSbgPengeluaran: Bool  // otomatis potong saldo pocket
├── pocketSumber: → Pocket?    // pocket yang dipotong jika catatSbgPengeluaran = true
└── createdAt: Date

// Computed:
// Modal       = jumlah × hargaBeli (kalkulasi per tipe)
// P&L         = nilaiSaatIni − Modal
// Return %    = (P&L / Modal) × 100
```

### 5.8 UserProfile & Config

```
UserProfile
├── id: UUID
├── nama: String
├── greetingText: String       // default "Halo", bisa custom
├── fotoProfil: Data?
└── tanggalGajian: Int?        // 1–28, untuk kalkulasi analytics per periode gajian
```

---

## 6. Kalkulasi Utama

```
// Home — Card Cashflow (per bulan)
Pemasukan Bulan Ini     = Σ Transaksi.nominal (tipe=Pemasukan, bulan=aktif)
Pengeluaran Bulan Ini   = Σ Transaksi.nominal (tipe=Pengeluaran, bulan=aktif)
Nabung Bulan Ini        = Σ SimpanKeTarget.nominal (bulan=aktif)
Dana Tersimpan          = Σ SimpanKeTarget.nominal (all time, semua target)
Aman Dibelanjakan       = Pemasukan − Pengeluaran − Nabung Bulan Ini

// Home — Card Total Kekayaan
Cash                    = Σ Pocket.saldo (kelompok=Biasa)
Hutang Kamu             = Σ Pocket.saldo (kelompok=Utang)
Total Aset              = Σ Aset.nilaiSaatIni
Total Kekayaan          = Cash + Dana Tersimpan + Total Aset − Hutang Kamu

// Home — Rincian Biaya (per bulan)
Total Pengeluaran       = Σ Transaksi (tipe=Pengeluaran, bulan=aktif)
Kebutuhan Pokok %       = Σ Pengeluaran (klasifikasi=KebutuhanPokok) / Total Pengeluaran
Gaya Hidup %            = Σ Pengeluaran (klasifikasi=GayaHidup) / Total Pengeluaran
Dana Tersimpan %        = Nabung Bulan Ini / Pemasukan Bulan Ini
```

---

## 7. Forms

### 7.1 Tambah / Edit Transaksi
| Field | Type | Required |
|---|---|---|
| Nominal | NumberField (besar) | ✓ |
| Tipe | Segmented (Pengeluaran / Pemasukan) | ✓ |
| Sub-tipe | Segmented (Normal / Simpan ke Target / Pakai dari Target) | |
| Kategori | Grid visual (ikon + nama) | |
| Pocket | Chips dari list Pocket aktif | |
| Target | Picker → Target (jika sub-tipe bukan Normal) | |
| Catatan | TextField | |
| Tanggal | DatePicker | ✓ |

### 7.2 Transfer Internal
| Field | Type | Required |
|---|---|---|
| Nominal | NumberField | ✓ |
| Pocket Asal | Picker → Pocket aktif | ✓ |
| Pocket Tujuan | Picker → Pocket aktif | ✓ |
| Catatan | TextField | |
| Tanggal | DatePicker | ✓ |

### 7.3 Tambah Pocket
| Field | Type | Required |
|---|---|---|
| Logo | ImagePicker (kamera/galeri) | |
| Nama | TextField | ✓ |
| Kelompok Pocket | Picker (Biasa / Utang) | ✓ |
| Kategori Pocket | Picker → KategoriPocket | ✓ |
| Saldo Awal | NumberField (default 0) | |
| Limit | NumberField | khusus Kartu Kredit/PayLater |

### 7.4 Tambah / Edit Kategori
| Field | Type | Required |
|---|---|---|
| Nama | TextField | ✓ |
| Tipe | Segmented (Pengeluaran / Pemasukan) | ✓ |
| Klasifikasi | Segmented (Kebutuhan Pokok / Gaya Hidup) | khusus Pengeluaran |
| Kelompok Income | Picker | khusus Pemasukan |
| Ikon Custom | TextField (emoji) | |
| Ikon | Grid preset SF Symbol | |
| Warna | Palette 12 warna | |

### 7.5 Tambah / Edit Transaksi Otomatis
| Field | Type | Required |
|---|---|---|
| Nominal | NumberField | ✓ |
| Tipe | Segmented (Pengeluaran / Pemasukan) | ✓ |
| Kategori | Grid visual | |
| Pocket | Chips dari list Pocket | |
| Tanggal Tiap Bulan | Grid angka 1–28 | ✓ |
| Catatan | TextField | |

### 7.6 Tambah / Edit Anggaran
| Field | Type | Required |
|---|---|---|
| Nominal Anggaran | NumberField | ✓ |
| Tipe | Segmented (Bulanan / Harian) | ✓ |
| Berulang | Toggle (reset otomatis tiap bulan) | khusus Bulanan |
| Pindahan | Toggle (sisa dibawa ke bulan depan) | khusus Bulanan |
| Harian Berulang | Toggle (tampil di semua hari) | khusus Harian |
| Kategori | Grid visual (kosong = keseluruhan) | |

### 7.7 Bikin Target Baru
| Field | Type | Required |
|---|---|---|
| Nama | TextField | ✓ |
| Butuh Dana | NumberField | |
| Target Kapan Tercapai | DatePicker | |
| Ikon Custom | TextField (emoji) | |
| Ikon | Grid preset SF Symbol | |
| Warna | Palette 12 warna | |

### 7.8 Tambah Aset

**Saham:**
| Field | Type | Required |
|---|---|---|
| Nama / Kode | Search (autocomplete + harga pasar live) | ✓ |
| Lot | NumberField | ✓ |
| Harga per Lembar | NumberField | ✓ |
| Catat sbg Pengeluaran | Toggle + Pocket picker | |

**Kripto:**
| Field | Type | Required |
|---|---|---|
| Mata Uang | Segmented (IDR / USDT) | ✓ |
| Nama / Kode | Search | ✓ |
| Total Investasi | NumberField | ✓ |
| Harga per Unit | NumberField | ✓ |
| Catat sbg Pengeluaran | Toggle + Pocket picker | |

**Reksadana:**
| Field | Type | Required |
|---|---|---|
| Filter Jenis | Grid (Campuran / Saham / Index ETF / Pasar Uang / Pendapatan Tetap / Syariah / Terproteksi) | |
| Nama / Kode | Search | ✓ |
| Total Investasi | NumberField | ✓ |
| Harga per Unit (NAV) | NumberField | ✓ |
| Catat sbg Pengeluaran | Toggle + Pocket picker | |

**Emas:**
| Field | Type | Required |
|---|---|---|
| Jenis Emas | Chips (LM Antam / UBS / Antam Retro / UBS Retro) | ✓ |
| Tahun Cetak | Grid tahun (2018–sekarang) | ✓ |
| Berat (gram) | NumberField | ✓ |
| Harga Beli/gram | NumberField (+ current price info) | ✓ |
| Catat sbg Pengeluaran | Toggle + Pocket picker | |

---

## 8. Screens per Tab

### Tab 1 — Home

```
[foto bulat]  {greetingText}, {nama}!

< Bulan Tahun >

┌─────────────────────────────────────┐
│  AMAN DIBELANJAKAN / WAH OVER BUDGET│
│  ± Rp XX.XXX.XXX                    │
│  Tersisa: Rp XX.XXX.XXX             │
│                                     │
│  ↓ PEMASUKAN       ↑ PENGELUARAN    │
│  Rp XX.X           Rp XX.X          │
│                                     │
│  NABUNG BULAN INI  TOTAL TABUNGAN   │
│  Rp XX.X           Rp XX.X          │
└─────────────────────────────────────┘

[ Analitik ]  [ Target ]  [ Aset ]

┌─────────────────────────────────────┐
│  TOTAL KEKAYAAN                     │
│  Rp XX.XXX.XXX                      │
│  CASH      DANA TERSIMPAN  HUTANG   │
│  Rp XX.X   Rp XX.X         Rp XX.X  │
└─────────────────────────────────────┘

┌──────────────────┐  ┌──────────────┐
│  RINCIAN BIAYA   │  │              │
│  Kebutuhan Pokok │  │  (kosong,    │
│  Gaya Hidup      │  │  streak      │
│  Dana Tersimpan  │  │  dihapus)    │
└──────────────────┘  └──────────────┘

// Muncul jika ada target aktif:
┌─────────────────────────────────────┐
│  [ikon] nama target    [Ngegas ↑]   │
│  X% • Rp tersimpan / Rp target      │
│  [progress bar]                     │
│  Estimasi Kelar: tgl • X hari       │
│  PERLU MENYISIHKAN: Rp X /bln       │
└─────────────────────────────────────┘

// Muncul jika ada data:
KATEGORI TERATAS
[ikon] nama kategori    Rp XX.X
[progress bar warna kategori]

TERBARU
[ikon] nama  [badge tipe]    ± Rp XX.X
...
```

### Tab 2 — Transaksi

```
< Bulan Tahun >
[🔍 Cari transaksi...]  [filter]

┌───────────────────────────────┐
│  BERSIH            + Rp XX.X  │
│  ↓ PEMASUKAN  ↑ PENGELUARAN   │
│  Rp XX.X      Rp XX.X         │
└───────────────────────────────┘

DD Bulan YYYY
[ikon] nama  [badge]    ± Rp XX.X
...

// Tap item → Detail bottom sheet
// Tap Pemasukan/Pengeluaran card → list sheet
```

### Tab 3 — Voice

```
[Visualisasi gelombang suara]
[Transkripsi real-time]
[Tombol mic — tap untuk mulai/berhenti]

→ Review Sheet (bottom sheet):
  Tipe     [Pengeluaran / Pemasukan / Transfer]
  Nominal  [hasil parse / kosong]
  Kategori [hasil parse / kosong]
  Pocket   [hasil parse / kosong]
  Tanggal  [hari ini]
  Catatan  [sisa kalimat yang tidak terparse]
  [Simpan]
```

### Tab 4 — Pocket

```
Total Saldo: Rp XX.X

BIASA
└── [list pocket Biasa — nama, saldo, logo]

UTANG
└── [list pocket Utang — nama, saldo, limit, sisa limit]

FAB (+) → Tambah Pocket
```

### Tab 5 — Pengaturan

```
PROFIL
[foto]  nama  greeting text

KONFIGURASI
• Tanggal Gajian

MANAJEMEN
• Kategori      →
• Anggaran      →
• Transaksi Otomatis →

DANGER ZONE
• Reset Semua Data   [tombol merah]
```

---

## 9. Halaman dari Shortcut Home

### Analitik
```
< 1 - DD Bulan YYYY >   [filter]

[Total Pengeluaran]  [Total Pemasukan]
[Rata-rata/Hari]     [Jumlah Transaksi]

PENGELUARAN TERBESAR
Rp XX.X — kategori — tanggal

HARI PALING BOROS
Rp XX.X — hari

TREN
[Line chart: Pengeluaran / Pemasukan / Bersih]
[Toggle: bar / line chart]

PER KATEGORI
[Donut chart + legend + % + progress bar]

PER HARI
[Horizontal bar chart per hari]
```

### Target
```
TOTAL TABUNGAN    Rp XX.X    [X TARGET]

[ikon] nama target          [edit] [hapus]
Saldo: Rp X
Target: Rp XX.X             X%
[progress bar]

→ Tap item → Detail sheet:
  TARGET              Rp XX.X
  TARGET KAPAN        DD Bulan YYYY
  TERSIMPAN           Rp XX.X
  SISA                Rp XX.X
  [↑ Tarik]

  TRANSAKSI
  [list transaksi bertipe SimpanKeTarget/PakaiDariTarget]
```

### Aset
```
[↺ refresh]   [+ Tambah]

PORTOFOLIO                [X ASET]
TOTAL NILAI    Rp XX.X
TOTAL MODAL    Rp XX.X
KEUNTUNGAN     ± Rp XX.X (±X%)

SAHAM (X)
[ikon] KODE        Rp XX.X
       X lot        ± Rp XX.X (X%)

KRIPTO (X) / REKSADANA (X) / EMAS (X)
...

→ Tap item → Detail sheet:
  NILAI PASAR     Rp XX.X
  Jumlah          X lot/gram/unit
  Total Modal     Rp XX.X
  Harga Rata-Rata Rp XX.X
  Harga Saat Ini  Rp XX.X
  Keuntungan      ± Rp XX.X (±X%)
  [✏️ Edit]  [Jual]  [Beli]
```

---

## 10. Detail Views (Bottom Sheet)

| Item | Sheet Size | Konten |
|---|---|---|
| Pocket Biasa | Full | Saldo, histori transaksi, tombol Transfer |
| Pocket Utang | Full | Limit, Sisa Limit, histori, tombol bayar |
| Transaksi | Half | Detail lengkap + Edit + Hapus |
| Transaksi Otomatis | Half | Detail rule + toggle Aktif + Edit + Hapus |
| Target | Full | Progress, tersimpan, sisa, riwayat, Tarik |
| Aset | Half | Nilai, modal, P&L, Return % + Edit + Jual + Beli |
| Anggaran | Full | Anggaran / Terpakai / Sisa + list transaksi |

---

## 11. Voice Input — Parsing Rules

### Alur
1. User tap tab Voice → mic aktif
2. Transkripsi real-time via SFSpeechRecognizer (on-device)
3. User selesai → parser jalan
4. Review Sheet muncul (semua field bisa diedit)
5. User konfirmasi → simpan

### Rules

| Yang Dideteksi | Cara Deteksi |
|---|---|
| Nominal | angka + keyword (ribu/ratus/juta/rb/k/m) |
| Tipe | keyword trigger: beli/bayar/keluar → Pengeluaran; terima/masuk/gajian → Pemasukan; transfer/pindah → Transfer |
| Kategori | keyword mapping ke nama Kategori |
| Pocket | fuzzy string matching ke nama Pocket aktif |
| Catatan | sisa kalimat yang tidak terparse |

### Contoh
```
"beli nasi uduk 10rb pake gopay"
→ Pengeluaran | Rp10.000 | [match kategori] | GoPay

"transfer 500rb ke BCA dari mandiri"
→ Transfer | Rp500.000 | Asal: Mandiri | Tujuan: BCA

"terima gaji 5 juta"
→ Pemasukan | Rp5.000.000 | kategori: kosong | pocket: kosong
```

---

## 12. Transaksi Otomatis — Behavior

- Transaksi dibuat **otomatis di background** pada tanggal yang ditentukan
- `otomatisID` pada Transaksi menandai bahwa record dibuat dari rule otomatis
- Jika tanggal tidak ada di bulan tersebut → skip ke bulan berikutnya
- Max tanggal: **28** (safe untuk semua bulan termasuk Februari)
- User bisa toggle Aktif/nonaktif per rule tanpa menghapus

---

## 13. Anggaran — Behavior

### Bulanan
- **Berulang ON:** anggaran otomatis dibuat ulang tiap bulan dengan nominal sama
- **Pindahan ON:** sisa anggaran bulan ini ditambahkan ke anggaran bulan depan
- Navigasi per bulan `< Bulan Tahun >`

### Harian
- **Harian Berulang ON:** anggaran berlaku di semua hari
- Navigasi per hari `< Hari, DD Bulan >`
- Warna merah jika over, kuning jika normal

### Kategori Kosong
- Jika kategori dikosongkan → anggaran berlaku untuk **total keseluruhan pengeluaran**

---

## 14. Aset — Behavior

- Harga Saham, Kripto, Reksadana, Emas diambil via **API real-time** (butuh internet)
- Jika offline → tampilkan nilai terakhir yang tersimpan
- **Catat sbg Pengeluaran ON:** saldo pocket sumber otomatis terpotong saat Tambah Aset
- **Beli:** tambah jumlah kepemilikan, update modal
- **Jual:** kurangi jumlah kepemilikan, catat sebagai Pemasukan (opsional)
- `nilaiSaatIni` di-refresh saat user buka halaman Aset (jika ada koneksi)

---

## 15. Settings — Pengaturan

### Profil
- Foto profil (kamera/galeri, opsional)
- Nama — dipakai di greeting Home
- Greeting text — free text, default "Halo"

### Konfigurasi
- **Tanggal Gajian** — untuk kalkulasi analytics per periode gajian

### Manajemen
- **Kategori** — CRUD + reorder drag, tipe Pengeluaran/Pemasukan
- **Anggaran** — CRUD mode Bulanan & Harian
- **Transaksi Otomatis** — CRUD + toggle Aktif

### Danger Zone
- **Reset Semua Data** — hapus seluruh data SwiftData (konfirmasi 2 langkah)

---

## 16. Out of Scope v3

- Export data (PDF/Excel/CSV)
- iCloud sync
- Widget iOS home screen
- Integrasi bank / open banking
- Multi-user
- Backup & restore
- Piutang & Utang (Debitur/Kreditur)
- Aset Non-Finansial
- Dana Darurat Calculator
- Fear & Greed Index
- Sistem Prioritas Kategori (P0–P4)
- Struk/foto di transaksi

---

## 17. Non-Functional Requirements

| Kategori | Requirement |
|---|---|
| Platform | iOS 17+ |
| Offline | 100% offline untuk semua fitur kecuali harga Aset |
| Auth | Tidak ada |
| Performance | Voice transcription on-device, latensi < 2 detik |
| UI/UX | Dark mode first, Apple HIG |
| Data | SwiftData, lokal saja |
| Network | Hanya untuk fetch harga Aset (graceful degradation jika offline) |
