# Product Requirements Document — MyFinance
**Owner:** Dika  
**Platform:** iOS (SwiftUI + SwiftData)  
**Version:** 2.0 Final  
**Status:** Ready for Development

---

## 1. Executive Summary

Aplikasi manajemen keuangan pribadi offline-first untuk iOS. Menggantikan Coda tracker yang tidak mobile-friendly. Semua data lokal, tidak ada server, tidak ada subscription. Input manual + voice input untuk kecepatan pencatatan.

---

## 2. Prinsip Dasar

- **Offline-first** — semua fitur core berjalan tanpa internet
- **Manual input** — tidak ada integrasi bank atau API harga otomatis
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
| Network | Tidak ada (fully offline) |
| Notifications | UserNotifications framework |
| Background | BackgroundTasks framework |

---

## 4. Navigasi — Tab Bar (5 Tab)

| # | Tab | Icon | Keterangan |
|---|---|---|---|
| 1 | Home | house | Dashboard utama |
| 2 | Tracker | list.bullet | Expense / Income / Transfer |
| 3 | Voice | mic.fill | Center button, mic langsung aktif |
| 4 | Invest | chart.line.uptrend | Portfolio investasi |
| 5 | Pocket | wallet.pass | Pocket, Piutang, Utang, Net Worth, Goals |

---

## 5. Data Model

### 5.1 Pocket

```
Pocket
├── id: UUID
├── nama: String
├── kelompokPocket: Enum (Biasa | Investasi | Utang)
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
//        Financing, Akun Brand, Crypto Exchange,
//        Akun Sekuritas, Crypto Wallet, Kartu Kredit/PayLater

UpdateSaldo
├── id: UUID
├── pocket: → Pocket
├── tanggal: Date
├── saldo: Decimal
└── waktuUpdate: Enum (Pagi | Malam)
// Pagi  = sebelum ada transaksi hari ini
// Malam = setelah tidak ada transaksi hari ini
```

### 5.2 Transaksi

```
Expense
├── id: UUID
├── tanggal: Date
├── nominal: Decimal
├── kategori: → KategoriExpense    // carries Prioritas & kelompok
├── pocket: → Pocket?
├── catatan: String?
├── debitur: → Debitur?            // jika piutang-related
├── kreditur: → Kreditur?          // jika utang-related
├── fileGambar: Data?
├── terjadwalID: → ExpenseTerjadwal?  // jika di-generate otomatis
└── createdAt: Date

Income
├── id: UUID
├── tanggal: Date
├── nominal: Decimal
├── kategori: → KategoriIncome     // carries KelompokIncome
├── pocket: → Pocket?
├── catatan: String?
├── debitur: → Debitur?
├── kreditur: → Kreditur?
├── fileGambar: Data?
├── terjadwalID: → IncomeTerjadwal?
└── createdAt: Date

TransferInternal
├── id: UUID
├── tanggal: Date
├── nominal: Decimal
├── pocketAsal: → Pocket
├── pocketTujuan: → Pocket
├── catatan: String?
├── terjadwalID: → TransferInternalTerjadwal?
└── createdAt: Date
```

### 5.3 Kategori

```
KategoriExpense
├── id: UUID
├── nama: String
├── prioritas: Enum (Blank | P0 | P1 | P2 | P3 | P4)
├── kelompok: Enum (Expense | NonExpense)
└── createdAt: Date

// Prioritas color coding:
// P0 = Merah, P1 = Orange, P2 = Kuning, P3 = Hijau, P4 = Biru, Blank = Abu

KategoriIncome
├── id: UUID
├── nama: String
├── kelompokIncome: Enum (Gaji | ProdukDigital | JasaProfesional |
│                         PassiveIncome | SocialMedia | NonIncome)
└── createdAt: Date
```

### 5.4 Terjadwal

```
ExpenseTerjadwal
├── id: UUID
├── nama: String
├── setiapTanggal: Int         // hari ke-X tiap bulan (1–31)
├── reminderAktif: Bool
├── catatOtomatisAktif: Bool   // true = auto-record, false = reminder only
├── nominal: Decimal?
├── kategori: → KategoriExpense?
├── pocket: → Pocket?
├── catatan: String?
├── isAktif: Bool
└── createdAt: Date

IncomeTerjadwal
// sama dengan ExpenseTerjadwal, kategori → KategoriIncome

TransferInternalTerjadwal
├── id: UUID
├── nama: String
├── setiapTanggal: Int
├── reminderAktif: Bool
├── catatOtomatisAktif: Bool
├── nominal: Decimal?
├── pocketAsal: → Pocket?
├── pocketTujuan: → Pocket?
├── catatan: String?
├── isAktif: Bool
└── createdAt: Date
```

### 5.5 Piutang & Utang

```
Debitur
├── id: UUID
├── nama: String
└── catatan: String?

// Computed (tidak disimpan):
// Total Dipinjamkan = Σ Expense[debitur=ini, kategori=KasihUtang]
// Total Kembali     = Σ Income[debitur=ini, kategori=PiutangTerbayar]
// Sisa Piutang      = Total Dipinjamkan − Total Kembali

Kreditur
├── id: UUID
├── nama: String
└── catatan: String?

// Computed (tidak disimpan):
// Total Dipinjam  = Σ Income[kreditur=ini, kategori=UtangPinjaman]
// Total Dibayar   = Σ Expense[kreditur=ini, kategori=BayarUtang]
// Sisa Utang      = Total Dipinjam − Total Dibayar

// Tidak ada tabel terpisah untuk Piutang/Utang.
// Semua data dari query Expense/Income berdasarkan Debitur/Kreditur + Kategori.
// Status per transaksi: Belum Dibayar | Terbayar Sebagian | Lunas
```

### 5.6 Budget

```
BudgetBulanan
├── id: UUID
├── kategoriExpense: → KategoriExpense
├── nominalBudget: Decimal
├── bulan: Int    // 1–12
└── tahun: Int

// Behavior: bulan baru → auto-copy dari bulan sebelumnya sebagai default.
// User bisa edit per kategori.

RencanaAnggaranTahunan
├── id: UUID
├── tahun: Int
├── kategoriExpense: → KategoriExpense
└── nominalBudget: Decimal
// Untuk fitur Tahunan di Analytics
```

### 5.7 Goals

```
Goal
├── id: UUID
├── nama: String
├── tipe: Enum (Tabungan | Cicilan)
├── targetNominal: Decimal
├── deadline: Date?
├── gambar: Data?
├── catatan: String?
├── isSelesai: Bool (default: false)
└── createdAt: Date

RiwayatMenciclMenabung
├── id: UUID
├── goal: → Goal
├── tanggal: Date
├── nominal: Decimal
└── catatan: String?

// Computed:
// Progress  = Σ RiwayatMenciclMenabung.nominal per Goal
// Sisa      = targetNominal − Progress
```

### 5.8 Net Worth

```
AsetNonFinansial
├── id: UUID
├── kategoriAset: → KategoriAset
├── namaAset: String
├── nilaiPasarTerakhir: Decimal
├── catatan: String?
└── updatedAt: Date

KategoriAset
├── id: UUID
└── nama: String
// Nilai awal: Properti, Logam Mulia, Saham Perusahaan Terbuka,
//             Saham Perusahaan Tertutup, Paten, Koleksi,
//             Kendaraan, Gadget dan Elektronik

// Net Worth (computed):
// Aset       = Σ Pocket.saldo (Biasa+Investasi) + Σ AsetNonFinansial.nilaiPasarTerakhir + Σ Sisa Piutang
// Kewajiban  = Σ Pocket.saldo (Utang/Financing) + Σ Sisa Utang
// Net Worth  = Aset − Kewajiban
```

### 5.9 Investasi

```
InvestasiHolding
├── id: UUID
├── pocket: → Pocket          // Kelompok = Investasi
├── nama: String
├── tipe: Enum (Reksadana | Saham | Emas | Kripto)
└── catatan: String?

// P&L (computed, semua manual):
// Modal         = Σ inflow ke pocket ini
// Nilai Saat Ini = Pocket.saldo (diupdate via Input Nilai Saat Ini)
// P&L           = Nilai Saat Ini − Modal
// Return %      = (P&L / Modal) × 100

FGI
├── id: UUID
├── tanggal: Date
└── nilai: Int    // 0–100 (Fear & Greed Index, input manual)
```

### 5.10 Settings / Config

```
UserProfile
├── id: UUID
├── nama: String              // muncul di greeting Home
├── greetingText: String      // default "Welcome back", bisa custom
└── fotoProfil: Data?         // opsional, fallback ke inisial

DanaDaruratConfig
├── id: UUID
├── jumlahBulan: Int          // target berapa bulan (default: 3)
└── prioritasIncluded: [Int]  // prioritas yang dihitung, [] = semua
// Blank prioritas selalu excluded dari perhitungan
```

---

## 6. Forms

### 6.1 Input Expense
| Field | Type | Required |
|---|---|---|
| Tanggal | DatePicker | ✓ |
| Nominal | NumberField | ✓ |
| Kategori | Picker → KategoriExpense | |
| Pocket | Picker → Pocket aktif | |
| Catatan | TextField | |
| Debitur | Picker → Debitur | |
| Kreditur | Picker → Kreditur | |
| File/Gambar | ImagePicker | |

> Saat Kategori dipilih → Prioritas & Kelompok (Expense/NonExpense) otomatis ter-assign dari data kategori.

### 6.2 Input Income
| Field | Type | Required |
|---|---|---|
| Tanggal | DatePicker | ✓ |
| Nominal | NumberField | ✓ |
| Kategori | Picker → KategoriIncome | |
| Pocket | Picker → Pocket aktif | |
| Catatan | TextField | |
| Debitur | Picker → Debitur | |
| Kreditur | Picker → Kreditur | |
| File/Gambar | ImagePicker | |

> Saat Kategori dipilih → KelompokIncome & NonIncome flag otomatis.

### 6.3 Input Transfer Internal
| Field | Type | Required |
|---|---|---|
| Tanggal | DatePicker | ✓ |
| Nominal | NumberField | ✓ |
| Pocket Asal | Picker → Pocket aktif | ✓ |
| Pocket Tujuan | Picker → Pocket aktif | ✓ |
| Catatan | TextField | |

### 6.4 Input Update Saldo
| Field | Type | Required |
|---|---|---|
| Tanggal | DatePicker | ✓ |
| Saldo | NumberField (Rp) | ✓ |
| Pocket | Picker → Pocket | ✓ |
| Waktu Update | Picker (Pagi / Malam) | ✓ |

### 6.5 Input Nilai Saat Ini (Investasi)
| Field | Type | Required |
|---|---|---|
| Tanggal | DatePicker | ✓ |
| Saldo / Nilai | NumberField (Rp) | ✓ |
| Pocket | Picker → Pocket (Investasi) | ✓ |
| Waktu Update | Picker (Pagi / Malam) | ✓ |

### 6.6 Input Mencicil & Menabung
| Field | Type | Required |
|---|---|---|
| Tanggal | DatePicker | ✓ |
| Goal | Picker → Goal | ✓ |
| Nominal | NumberField | ✓ |
| Catatan | TextField | |

### 6.7 Expense Terjadwal
| Field | Type | Required |
|---|---|---|
| Nama | TextField | ✓ |
| Setiap Tanggal | NumberPicker (1–31) | ✓ |
| Reminder | Toggle | |
| Catat Otomatis | Toggle | |
| Nominal | NumberField | |
| Kategori | Picker → KategoriExpense | |
| Pocket | Picker → Pocket | |
| Catatan | TextField | |

### 6.8 Income Terjadwal
> Sama dengan Expense Terjadwal. Kategori → KategoriIncome.

### 6.9 Transfer Internal Terjadwal
| Field | Type | Required |
|---|---|---|
| Nama | TextField | ✓ |
| Setiap Tanggal | NumberPicker (1–31) | ✓ |
| Reminder | Toggle | |
| Catat Otomatis | Toggle | |
| Nominal | NumberField | |
| Pocket Asal | Picker → Pocket | |
| Pocket Tujuan | Picker → Pocket | |
| Catatan | TextField | |

### 6.10 Tambah Pocket
| Field | Type | Required |
|---|---|---|
| Foto/Logo | ImagePicker (kamera/galeri) | |
| Nama | TextField | ✓ |
| Kelompok Pocket | Picker (Biasa/Investasi/Utang) | ✓ |
| Kategori Pocket | Picker → KategoriPocket | ✓ |
| Saldo Awal | NumberField (Rp, default 0) | |

> Foto/Logo ditampilkan di list pocket dan detail view.
> Fallback jika tidak ada foto: inisial nama pocket dengan background warna.
> Untuk Kartu Kredit/PayLater: tambah field Limit (Decimal).

### 6.11 Aset Non-Finansial
| Field | Type | Required |
|---|---|---|
| Kategori Aset | Picker → KategoriAset | ✓ |
| Nama Aset | TextField | ✓ |
| Nilai Pasar Terakhir | NumberField | |

### 6.12 Inline (Add Row Langsung — No Dedicated Form)
| Item | Field yang diisi |
|---|---|
| Budget Bulanan | KategoriExpense + Nominal + Bulan + Tahun |
| Kategori Expense | Nama + Prioritas + Kelompok |
| Kategori Income | Nama + KelompokIncome |
| Kreditur | Nama + Catatan |
| Kategori Aset | Nama |
| Financial Goals | Nama + Tipe + Target + Deadline + Gambar + Catatan |

---

## 7. Detail Views (Bottom Sheet)

Semua detail view menggunakan **bottom sheet** (card melayang dari bawah).  
Drag down untuk dismiss.

| Item | Sheet Size | Konten |
|---|---|---|
| **Pocket** | Full | Saldo, histori transaksi masuk/keluar, tombol Update Saldo, tombol Edit |
| **Kartu Kredit/PayLater** | Full | Limit, Sisa Limit, Utang outstanding, histori, tombol bayar |
| **Transaksi (Expense/Income/Transfer)** | Half | Detail lengkap + Edit + Delete |
| **Terjadwal** | Half | Detail rule + toggle Reminder + toggle Catat Otomatis + Edit |
| **Goal** | Full | Progress bar, Sisa target, Riwayat mencicil/menabung, tombol tambah setoran |
| **Debitur** | Full | Total dipinjamkan, Sisa, Riwayat pinjam, Riwayat bayar |
| **Kreditur** | Full | Total dipinjam, Sisa, Riwayat masuk, Riwayat bayar |
| **InvestasiHolding** | Full | Nilai, Modal, P&L, Return %, tombol update nilai |
| **Aset Non-Finansial** | Half | Nama, Kategori, Nilai pasar + Edit |

---

## 8. Screens per Tab

### Tab 1 — Home
Home adalah satu halaman scroll panjang yang menggabungkan dashboard + analytics.

```
[foto bulat]  {greetingText}, {nama}!        [⚙️]

┌─────────────────────────────────┐
│  NET WORTH                      │
│  Rp XX.XXX.XXX                  │
└─────────────────────────────────┘

Bulan Ini
Income   Rp XX.X    Expense  Rp XX.X    Saving  Rp XX.X

─── Analytics ───
[Expense] [Income] [Bulanan] [Tahunan] [Pocket] [Dana Darurat]
[konten analytics sesuai tab yang dipilih — scroll horizontal untuk ganti]

─── Transaksi Terakhir ───
[list 10 transaksi terbaru, semua tipe]
```

### Tab 2 — Tracker
```
Segmented: [Expense] [Income] [Transfer]

Filter bar: Tanggal | Kategori | Pocket

[List transaksi + warna prioritas untuk expense]

FAB (+) → form input sesuai tab aktif

Bottom section (expandable):
• Terjadwal
• Budget Bulanan
• Kategori (in-context)
```

### Tab 3 — Voice
```
[Visualisasi gelombang suara]
[Transkripsi real-time]
[Tombol mic — tap untuk mulai/berhenti]

→ Review Sheet (bottom sheet full):
  Tipe    [Expense / Income / Transfer]
  Nominal [hasil parse / kosong]
  Kategori [hasil parse / kosong]
  Pocket  [hasil parse / kosong]
  Tanggal [hari ini]
  Catatan [sisa kalimat yang tidak terparse]
  [Simpan]
```

### Tab 4 — Invest
```
FGI Hari Ini: [nilai] — [label Fear/Greed]

Summary:
Total Nilai  Rp XX.X    Modal  Rp XX.X    P&L  Rp XX.X (X%)

Filter: [Semua] [Reksadana] [Saham] [Emas] [Kripto]

[List InvestasiHolding dengan nilai, P&L per item]

FAB (+) → tambah holding baru
```

### Tab 5 — Pocket
```
Segmented / Section:
[Pocket] [Piutang] [Utang] [Net Worth] [Goals] [Dana Darurat]

POCKET:
  Biasa      total: Rp XX.X
  └ [list pocket Biasa]
  Investasi  total: Rp XX.X
  └ [list pocket Investasi]
  Utang      total: Rp XX.X
  └ [list pocket Utang]

PIUTANG:
  [list Debitur + sisa piutang + status]

UTANG:
  [list Kreditur + sisa utang + status]

NET WORTH:
  Aset Finansial    Rp XX.X
  Aset Non-Finansial Rp XX.X
  Kewajiban         Rp XX.X
  ─────────────────────────
  Net Worth         Rp XX.X

GOALS:
  [list Goal dengan progress bar + sisa]

DANA DARURAT:
  Target: X bulan = Rp XX.X
  [tabel prioritas → kategori → rerata/bulan]
```

---

## 9. Voice Input — Parsing Rules

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
| Tipe | keyword trigger: beli/bayar/keluar → Expense; terima/masuk/gajian → Income; transfer/pindah → Transfer |
| Kategori | keyword mapping ke nama KategoriExpense/Income |
| Pocket | fuzzy string matching ke nama Pocket aktif |
| Catatan | sisa kalimat yang tidak terparse |

### Edge Cases
- Nominal tidak disebut → field kosong, user isi manual
- Pocket tidak dikenali → field kosong, user pilih manual
- Kategori tidak dikenali → field kosong, user pilih manual
- Tipe tidak jelas → default Expense
- Semua field tetap editable di Review Sheet sebelum simpan

### Contoh
```
"beli nasi uduk 10rb pake gopay"
→ Expense | Rp10.000 | [match kategori] | GoPay

"transfer 500rb ke BCA dari mandiri"
→ Transfer | Rp500.000 | Asal: Mandiri | Tujuan: BCA

"terima gaji 5 juta"
→ Income | Rp5.000.000 | kategori: kosong | pocket: kosong
```

---

## 10. Settings

**Akses:** ikon gear pojok kanan atas Home

### Profile
- Foto profil (dari kamera/galeri, opsional)
- Nama — dipakai di greeting Home
- Greeting text — free text, default "Welcome back"

### Konfigurasi
- Dana Darurat: jumlah bulan + prioritas yang dihitung
- Tanggal Gajian — untuk kalkulasi "per Tanggal Gajian" di analytics

### Data
- *(out of scope v1)*

---

## 11. Terjadwal — Behavior

- **Reminder only** (Catat Otomatis = off): notifikasi muncul di tanggal tersebut, user input manual
- **Auto-record** (Catat Otomatis = on): transaksi dibuat otomatis di background pada tanggal tersebut
- `terjadwalID` pada Expense/Income/Transfer menandai bahwa record dibuat dari rule terjadwal
- Jika tanggal tidak ada di bulan tersebut (misal tgl 31 di bulan Februari) → skip ke bulan berikutnya

---

## 12. Analytics (In Scope v1)

Analytics ditampilkan inline di Tab Home sebagai section dengan tab horizontal.
Tidak ada halaman terpisah — semua ada di dalam Home scroll.

### Tab Expense Analytics
- Tabel grouped: Expense/Non-Expense → Prioritas → Kategori
- Kolom: Rerata/Bulan, 30H Terakhir, Bulan Ini, Bulan Lalu, per Tgl Gajian, Total All-Time, Alokasi All-Time (%)
- Filter: Kategori, Prioritas

### Tab Income Analytics
- Kelompok Income mapping
- Tabel: Income/Non-Income → Kelompok → Kategori
- Kolom: Rerata/Bulan, 30H Terakhir, Bulan Ini, Bulan Lalu, per Tgl Gajian, Total All-Time, Kontribusi All-Time (%)

### Tab Bulanan
- Bar chart Income/Expense/Saving per bulan (filter Tahun)
- Tabel Rangkuman per Bulan: Tahun → Bulan → Income/Expense/Saving/Catatan
- Pivot Income per Bulan (Tahun × Jan–Des)
- Pivot Expense per Bulan (Tahun × Jan–Des)
- Rangkuman Bulan All-Time (aggregasi per nama bulan, lintas tahun)

### Tab Tahunan
- Filter: Pilih Tahun
- Summary: Total Terealisasi vs Rencana Anggaran (Income/Expense/Saving)
- Income Tahunan per kategori: Rencana/Terealisasi/% /Rerata/Disetahunkan(×12)
- Expense Tahunan per kategori: sama + filter Prioritas
- User bisa input Rencana Anggaran per kategori

### Tab Pocket Analytics
- Badge: jumlah pocket aktif
- Tabel per pocket: Saldo, Rerata Expense Bulanan, Frekuensi Expense/Income/Transfer Asal/Transfer Tujuan/Update Saldo
- List Kategori Pocket: total saldo per kategori

### Tab Dana Darurat
- Konfigurasi: target berapa bulan, Prioritas mana yang dihitung
- Prioritas Blank = exclude dari perhitungan
- Tabel: Prioritas → Kategori → Rerata Expense/Bulan
- Subtotal per Prioritas
- Hasil: Total kebutuhan × bulan target

---

## 13. Out of Scope v1

- Export data (PDF/Excel/CSV)
- iCloud sync
- Widget iOS home screen
- Integrasi bank / open banking
- API harga saham / crypto / kurs otomatis
- Multi-user
- Backup & restore

---

## 14. Non-Functional Requirements

| Kategori | Requirement |
|---|---|
| Platform | iOS 17+ |
| Offline | 100% offline, tidak butuh internet |
| Auth | Tidak ada |
| Performance | Voice transcription on-device, latensi < 2 detik |
| UI/UX | Apple HIG, Dark Mode support |
| Data | SwiftData, lokal saja |
