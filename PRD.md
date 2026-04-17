# MyFinance — Product Requirements Document

**Platform:** iOS (SwiftUI + SwiftData)  
**Versi App:** v1.0  
**Last Updated:** April 2026  
**Author:** Rahmandhika Putra Purwadi Wicaksono  

---

## Overview

MyFinance adalah aplikasi keuangan personal berbasis iOS yang dirancang untuk **penggunaan offline**, **input manual**, dan tampilan **dark mode** dengan bahasa Indonesia. Tujuan utamanya adalah membantu pengguna memantau arus kas, mengelola aset, melacak target tabungan, dan memahami pola pengeluaran secara menyeluruh.

---

## Arsitektur Teknis

| Komponen | Detail |
|---|---|
| Framework | SwiftUI + SwiftData |
| Language | Swift 6 |
| Min OS | iOS 17+ |
| Storage | SwiftData (offline-first, on-device) |
| Actor isolation | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| Tipe moneter | `Decimal` (bukan `Double`) |
| Sync cloud | Belum ada (no iCloud/CloudKit) |

---

## Navigasi Utama (Tab Bar)

```
[ Home ]  [ Transaksi ]  [ 🎙 Voice ]  [ Pocket ]  [ Pengaturan ]
    0           1              2              3            4
```

---

## Models (SwiftData)

### `Pocket`
Rekening atau dompet pengguna.

| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama pocket (mis. BCA, GoPay) |
| `kelompokPocket` | `KelompokPocket` | `biasa` / `utang` |
| `kategoriPocket` | `KategoriPocket?` | Sub-kategori pocket (linked model) |
| `saldo` | Decimal | Saldo saat ini (auto-adjust per transaksi) |
| `logo` | Data? | Foto logo custom |
| `limit` | Decimal? | Limit kredit / PayLater |
| `isAktif` | Bool | Soft delete |
| `urutan` | Int | Urutan tampil (drag reorder) |

---

### `Transaksi`
Semua transaksi keuangan (masuk/keluar).

| Field | Tipe | Keterangan |
|---|---|---|
| `tanggal` | Date | Tanggal transaksi |
| `nominal` | Decimal | Nominal transaksi |
| `tipe` | `TipeTransaksi` | `pemasukan` / `pengeluaran` |
| `subTipe` | `SubTipeTransaksi` | `normal` / `simpanKeTarget` / `pakaiDariTarget` |
| `kategori` | `Kategori?` | Kategori transaksi |
| `pocket` | `Pocket?` | Pocket asal/tujuan |
| `catatan` | String? | Catatan bebas |
| `goalID` | UUID? | Link ke Target (jika subTipe bukan normal) |
| `otomatisID` | UUID? | Link ke TransaksiOtomatis (engine belum aktif) |

---

### `Kategori`
Kategori yang bisa dikustomisasi pengguna.

| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama kategori |
| `tipe` | `TipeTransaksi` | Pengeluaran / Pemasukan |
| `ikon` | String | SF Symbol name |
| `warna` | String | Hex color |
| `klasifikasi` | `KlasifikasiExpense?` | `kebutuhanPokok` / `gayaHidup` (pengeluaran only) |
| `kelompokIncome` | `KelompokIncome?` | Gaji / Freelance / dll (pemasukan only) |
| `isNabung` | Bool | Pengeluaran → masuk "Nabung" di dashboard |
| `isAdmin` | Bool | Auto-assign ke biaya admin transfer/jual |
| `isHasilAset` | Bool | Auto-assign ke pemasukan hasil jual aset |
| `urutan` | Int | Urutan tampil |

---

### `Anggaran`
Anggaran bulanan per kategori.

| Field | Tipe | Keterangan |
|---|---|---|
| `kategori` | `Kategori?` | Kategori target anggaran (nil = global) |
| `nominal` | Decimal | Batas anggaran |
| `tipe` | `TipeAnggaran` | `bulanan` |
| `isAktif` | Bool | Toggle aktif/nonaktif |

---

### `Target`
Target tabungan atau investasi.

| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama target (mis. DP Rumah) |
| `targetNominal` | Decimal | Nominal yang ingin dicapai |
| `deadline` | Date? | Deadline target |
| `jenisTarget` | `JenisTarget` | `biasa` / `investasi` |
| `fotoData` | Data? | Foto background kartu (dari PhotosPicker) |
| `linkedAset` | `Aset?` | Aset yang menjadi wadah target investasi |
| `riwayat` | `[SimpanKeTarget]` | Riwayat setoran (untuk target biasa) |
| `isSelesai` | Bool | Tandai selesai |

**Computed:**
- `tersimpan` — sum riwayat setoran (biasa) atau `nilaiEfektif` aset (investasi)
- `progressPersen` — persentase progres (0–100+)
- `sisa` — selisih target − tersimpan

---

### `Aset`
Portfolio aset investasi.

| Field | Tipe | Keterangan |
|---|---|---|
| `tipe` | `TipeAset` | 6 tipe (lihat bawah) |
| `nama` | String | Nama aset |
| `kode` | String? | Ticker saham (BBCA, NVDA, dll) |
| `urutan` | Int | Urutan tampil (drag reorder) |
| `nilaiSaatIni` | Decimal | Nilai terkini dalam IDR (disimpan, diupdate service) |
| `pocketSumber` | `Pocket?` | Pocket asal dana |
| `linkedTarget` | `Target?` | Target investasi yang terhubung |

**Per tipe aset:**

| Tipe | Fields Khusus |
|---|---|
| Saham IDN | `lot`, `hargaPerLembar` (weighted avg + komisi) |
| Saham AS | `totalInvestasiUSD`, `hargaBeliPerShareUSD`, `hargaSaatIniUSD`, `kursBeliUSD`, `kursSaatIniUSD` |
| Reksadana | `jenisReksadana`, `totalInvestasiReksadana`, `hargaBeliPerUnit` (NAV), `navSaatIni` |
| Valas | `mataUangValas`, `jumlahValas`, `kursBeliPerUnit`, `kursSaatIni` |
| Emas | `jenisEmas`, `tahunCetak`, `beratGram`, `hargaBeliPerGram` |
| Deposito | `nominalDeposito`, `bungaPA`, `pphFinal`, `tenorBulan`, `tanggalMulaiDeposito`, `autoRollOver` |

---

### `Langganan`
Langganan berbayar (Spotify, Netflix, dll).

| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama layanan |
| `nominal` | Decimal | Nominal per bulan |
| `tanggalTagih` | Int | Tanggal tagih (1–28) |
| `kategori` | `Kategori?` | Kategori transaksi saat bayar |
| `logo` | Data? | Foto logo custom |
| `isAktif` | Bool | Toggle aktif/nonaktif |
| `urutan` | Int | Urutan tampil (drag reorder) |
| `pembayaran` | `[PembayaranLangganan]` | Riwayat bayar per bulan |

---

### `TransferInternal`
Transfer antar pocket.

| Field | Tipe | Keterangan |
|---|---|---|
| `pocketAsal` | `Pocket?` | Pocket pengirim |
| `pocketTujuan` | `Pocket?` | Pocket penerima |
| `nominal` | Decimal | Nominal yang ditransfer |
| `biayaAdmin` | Decimal | Biaya admin opsional |
| `catatan` | String? | Catatan |

---

### `TransaksiOtomatis`
Transaksi terjadwal (model tersedia, engine belum aktif).

| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama transaksi |
| `nominal` | Decimal | Nominal |
| `tipe` | `TipeTransaksi` | Pemasukan / Pengeluaran |
| `kategori` | `Kategori?` | Kategori |
| `pocket` | `Pocket?` | Pocket tujuan |
| `frekuensi` | String | Harian / Mingguan / Bulanan |
| `tanggalMulai` | Date | Mulai aktif |
| `isAktif` | Bool | Toggle |

> ⚠️ Engine penjadwalan belum diimplementasikan. UI sudah ada di Pengaturan → Transaksi Otomatis.

---

## File Structure

```
MyFinance/
├── Models/
│   ├── Pocket.swift
│   ├── Transaksi.swift
│   ├── Kategori.swift
│   ├── KategoriPocket.swift
│   ├── Anggaran.swift
│   ├── Target.swift              — + fotoData, linkedAset
│   ├── Aset.swift                — 6 tipe aset investasi
│   ├── Langganan.swift           — + PembayaranLangganan
│   ├── TransferInternal.swift
│   ├── TransaksiOtomatis.swift
│   ├── UserConfig.swift          — profil user (nama, foto, greeting)
│   └── AppEnums.swift            — semua enum
│
├── Services/
│   ├── ModelContainerService.swift   — SwiftData container setup
│   ├── AsetPriceService.swift        — fetch harga Yahoo Finance + Frankfurter
│   ├── StockAnalysisService.swift    — EMA20, RSI14, volume analysis
│   ├── BackupService.swift           — export/import JSON backup
│   ├── ReksadanaSearchService.swift  — search reksadana dari bundled JSON
│   ├── NLPParser.swift               — voice input parser
│   └── SpeechRecognitionService.swift
│
├── Extensions/
│   ├── Color+Hex.swift           — Color(hex: "#RRGGBB")
│   ├── Color+App.swift           — .appBg, .appGreen, .appRed, dll
│   ├── Date+Helpers.swift        — .isSameMonth(), .startOfMonth, .endOfMonth
│   ├── Double+Formatting.swift   — .percentFormatted
│   └── TipeAset+UI.swift         — icon + warna per TipeAset
│
└── Views/
    ├── Main/
    │   └── MainTabView.swift         — Tab bar utama (5 tab)
    │
    ├── Home/
    │   └── HomeView.swift            — Dashboard lengkap
    │
    ├── Transaksi/
    │   ├── TransaksiTabView.swift        — List transaksi per bulan + filter
    │   ├── AddEditTransaksiSheet.swift   — Form tambah/edit transaksi
    │   ├── TransaksiDetailSheet.swift    — Detail transaksi
    │   ├── TransaksiGroupSheet.swift     — Grup transaksi per hari
    │   └── TransferInternalSheet.swift  — Transfer antar pocket
    │
    ├── Voice/
    │   ├── VoiceTabView.swift        — Tombol mic + trigger speech
    │   └── VoiceReviewSheet.swift    — Review hasil voice input sebelum simpan
    │
    ├── Pocket/
    │   ├── PocketTabView.swift       — List pocket + saldo + kelompok
    │   ├── PocketDetailSheet.swift   — Detail pocket + histori transaksi
    │   ├── PocketDetailView.swift
    │   ├── AddEditPocketView.swift   — Form tambah/edit pocket
    │   └── DanaDaruratConfigView.swift — Konfigurasi dana darurat
    │
    ├── Aset/
    │   ├── AsetListView.swift            — Portfolio list (toolbar: Analisa + Reorder + Plus)
    │   ├── AsetDetailSheet.swift         — Detail aset (routing Beli/Update/Jual per tipe)
    │   ├── AddEditAsetView.swift         — Form tambah/edit aset semua tipe
    │   ├── BeliSahamSheet.swift          — Beli lot saham (weighted avg + komisi)
    │   ├── TambahReksadanaSheet.swift    — Tambah investasi reksadana (weighted avg NAV)
    │   ├── JualAsetSheet.swift           — Jual aset (+ biaya admin, auto hasilAset)
    │   ├── CairkanDepositoSheet.swift    — Cairkan deposito
    │   ├── AsetReorderSheet.swift        — Drag reorder aset
    │   ├── AnalisaSahamView.swift        — List analisa teknikal saham IDN
    │   └── AnalisaSahamDetailSheet.swift — Detail sinyal per saham
    │
    ├── Target/
    │   ├── TargetListView.swift      — List target (kartu + foto background)
    │   ├── TargetDetailSheet.swift   — Detail + riwayat setoran
    │   └── AddEditTargetView.swift   — Form tambah/edit + PhotosPicker
    │
    ├── Langganan/
    │   ├── LanggananBulanIniCard.swift   — Card di HomeView
    │   ├── LanggananManagementView.swift — CRUD + reorder sheet
    │   ├── AddEditLanggananView.swift    — Form tambah/edit + PhotosPicker logo
    │   └── LanggananReorderSheet.swift  — Drag reorder langganan
    │
    ├── Analitik/
    │   └── AnalitikView.swift        — Grafik cashflow, kategori, tren bulanan
    │
    ├── Pengaturan/
    │   ├── PengaturanView.swift              — Menu pengaturan (profil, manajemen, backup, reset)
    │   ├── KategoriManagementView.swift      — CRUD kategori
    │   ├── AddEditKategoriView.swift         — Form + toggle flags (isNabung, isAdmin, isHasilAset)
    │   ├── AnggaranManagementView.swift      — CRUD anggaran
    │   ├── AddEditAnggaranView.swift
    │   ├── TransaksiOtomatisView.swift       — List transaksi terjadwal (UI only)
    │   ├── AddEditTransaksiOtomatisView.swift
    │   └── BackupRestoreView.swift           — Export/import JSON backup
    │
    └── Components/
        ├── CurrencyInputField.swift      — Input nominal custom keyboard
        ├── QuickAmountButtons.swift      — Tombol +10rb/+50rb/+100rb/+500rb/+1jt
        ├── KategoriGridPicker.swift      — Grid picker kategori
        ├── PocketChipPicker.swift        — Chip picker pocket
        ├── ProgressBarView.swift         — Progress bar reusable
        ├── MonthNavigator.swift          — Navigasi bulan (prev/next + label)
        ├── IkonColorPicker.swift         — SF Symbol + color picker
        └── FlowLayout.swift             — Custom flow layout
```

---

## Fitur Lengkap

### Tab Home — Dashboard

Widget-widget yang tampil di dashboard:

| Widget | Keterangan |
|---|---|
| **Top Bar** | Avatar + nama user + greeting. Toggle hide balance (ikon mata). |
| **Month Navigator** | Navigasi bulan (← bulan →) |
| **Cashflow Card** | Pemasukan, Pengeluaran, Nabung bulan ini |
| **Aman Dibelanjakan** | `pemasukan - pengeluaran - nabung` |
| **Total Kekayaan** | `cash + dana tersimpan + nilai aset - utang` |
| **Rincian Biaya** | % Kebutuhan Pokok, % Gaya Hidup, % Dana Tersimpan |
| **Anggaran Bulan Ini** | Summary total + per-kategori dengan progress bar (kuning >80%, merah over) |
| **Target Aktif** | Kartu target dengan foto background + progress bar |
| **Langganan Bulan Ini** | List langganan + status bayar + tombol bayar |
| **Kategori Teratas** | Top 3 kategori pengeluaran terbesar |
| **Transaksi Terbaru** | 5 transaksi terakhir |

---

### Tab Transaksi

- List transaksi per bulan
- Filter per tipe (pemasukan/pengeluaran) dan kategori
- Tambah / Edit / Hapus transaksi
- Tampil detail + catatan
- Support sub-tipe: Simpan ke Target, Pakai dari Target

**Form Tambah/Edit Transaksi:**
- Nominal → `CurrencyInputField` + `QuickAmountButtons`
- Tipe: Pemasukan / Pengeluaran
- Kategori: `KategoriGridPicker`
- Pocket: `PocketChipPicker`
- Tanggal, Catatan
- Biaya admin opsional (untuk pengeluaran, auto-assign ke kategori `isAdmin`)
- Sub-tipe Simpan ke Target → pilih target + langsung update progres

---

### Tab Voice Input

- Tekan tombol mic → speech-to-text realtime
- NLP parser otomatis deteksi: tipe transaksi, nominal, pocket, kategori dari ucapan bebas
- Review sheet sebelum disimpan: user bisa edit semua field hasil parse

---

### Tab Pocket

- List semua pocket dikelompokkan: **Biasa** dan **Utang**
- Tampil saldo masing-masing + total per kelompok
- Tap pocket → detail saldo + histori transaksi pocket itu
- Tambah / Edit / Hapus pocket
- Logo custom (PhotosPicker)
- Drag reorder
- **Dana Darurat Config** — set target nominal dana darurat, tampil progress dari saldo pocket tertentu

---

### Aset & Portfolio

**6 Tipe Aset:**

| Tipe | Beli | Update Harga | Jual |
|---|---|---|---|
| Saham IDN | BeliSahamSheet (lot + komisi, weighted avg) | Auto-fetch Yahoo Finance (.JK) | JualAsetSheet |
| Saham AS | AddEditAsetView | Auto-fetch Yahoo Finance + Frankfurter kurs | JualAsetSheet |
| Reksadana | TambahReksadanaSheet (nominal + NAV, weighted avg) | Manual (user input NAV terbaru) | JualAsetSheet |
| Valas | AddEditAsetView | Auto-fetch Frankfurter | JualAsetSheet |
| Emas | AddEditAsetView | Manual (user input harga/gram) | JualAsetSheet |
| Deposito | AddEditAsetView | — | CairkanDepositoSheet |

**Fitur tambahan Aset:**
- **Jual Aset** → biaya admin opsional, auto-assign kategori `isHasilAset` ke pemasukan hasil jual
- **Analisa Teknikal Saham IDN** — fetch data 3 bulan terakhir, hitung EMA20, RSI14, volume vs rata-rata, kesimpulan sinyal: **BUY / HOLD / SELL**
- **Linked ke Target Investasi** — nilai aset otomatis update progress target
- **Drag reorder** aset

---

### Target Tabungan

| Jenis | Cara Kerja |
|---|---|
| **Biasa** | User setoran manual → riwayat `SimpanKeTarget` → sum untuk progress |
| **Investasi** | Linked ke `Aset` → `nilaiEfektif` aset = progress target (auto-update) |

- Foto background kartu dari PhotosPicker
- Estimasi setoran per bulan dari deadline
- Tandai selesai
- Riwayat setoran dengan detail tanggal + nominal

---

### Langganan

- Catat semua langganan berbayar (Spotify, Netflix, iCloud, dll)
- Nominal + tanggal tagih bulanan
- **Bayar bulan ini** → deduct saldo pocket + buat transaksi otomatis
- **Batal bayar** → refund saldo pocket + hapus transaksi
- Item sudah bayar → turun ke bawah list
- Logo custom (PhotosPicker)
- Drag reorder
- Card ringkasan tampil di HomeView

---

### Anggaran

- Buat anggaran per kategori atau global
- Progress bar per anggaran: hijau → kuning (>80%) → merah (over budget)
- Tampil summary di HomeView dan AnggaranManagementView

---

### Analitik

- Grafik cashflow bulanan (bar chart pemasukan vs pengeluaran)
- Breakdown pengeluaran per kategori
- Tren bulanan beberapa bulan terakhir

---

### Backup & Restore

- **Export**: semua data → file JSON (pocket, transaksi, kategori, anggaran, target, aset, langganan, profil)
- **Import**: restore dari file JSON
- Backward-compatible: file lama tanpa field baru tetap bisa di-restore

---

### Pengaturan

| Menu | Keterangan |
|---|---|
| Profil | Nama, foto, greeting text |
| Kategori | CRUD + urutan + flags. Badge: cyan (nabung), kuning (admin), hijau (hasilAset) |
| Anggaran | CRUD anggaran bulanan |
| Langganan | CRUD + reorder |
| Transaksi Otomatis | UI list + CRUD (engine belum aktif) |
| Backup & Restore | Export/import JSON |
| Reset Data | Hard reset semua data (dengan konfirmasi double) |

---

## External APIs

| API | Tujuan | Auth |
|---|---|---|
| Yahoo Finance `/v8/finance/chart/{ticker}` | Harga saham IDN (`.JK`) dan AS | Tidak ada |
| Yahoo Finance `?interval=1d&range=3mo` | Historical data untuk analisa teknikal | Tidak ada |
| Frankfurter `api.frankfurter.app` | Kurs valas (USD, SGD, JPY) | Tidak ada |

---

## Konvensi Coding

```swift
// Boolean field baru di @Model — default di property level
var isNabung: Bool = false   // BUKAN hanya di init

// Custom Codable di struct dengan memberwise init
extension MyStruct: Codable {
    init(from decoder: Decoder) throws { ... }
}
// BUKAN di dalam struct body (menghilangkan memberwise init)

// Pocket sort
@Query(sort: \Pocket.urutan) private var allPockets: [Pocket]

// Admin kategori lookup
private var adminKategori: Kategori? {
    allKategoris.first { $0.isAdmin && $0.tipe == .pengeluaran }
}

// Weighted average saham
let modalLama = lotLama * 100 * hargaLama
let avgBaru = (modalLama + nominalPocket) / totalShares

// Save
try? context.save()
```

---

## Known Technical Debt

| Item | Prioritas | Catatan |
|---|---|---|
| `TransaksiOtomatis` — engine belum aktif | Medium | Model + UI ada, tapi tidak ada scheduler yang create transaksi |
| `HomeView` fetch semua Transaksi in-memory | Low | Filter di memory, OK untuk sekarang |
| `terpakai(for:)` duplikat di 2 view | Low | Kandidat pindah ke Anggaran extension |
| Warna hard-coded — `Color+App.swift` sudah ada | Low | Belum semua view pakai static constants |
| `context` vs `modelContext` naming tidak konsisten | Low | Half-half |
| iCloud/CloudKit sync | Future | User belum punya Dev account aktif |
| Target — belum ada drag reorder | Future | Sort by createdAt |
| `HomeView_OLD.swift`, `PocketTabView_OLD.swift` | Low | File lama belum dihapus |
