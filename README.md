# MyFinance

Aplikasi keuangan personal berbasis iOS — **offline-first**, input manual, dark mode, bahasa Indonesia.

**Platform:** iOS 17+ · SwiftUI + SwiftData  
**Author:** Rahmandhika Putra Purwadi Wicaksono

---

## Tech Stack

| Komponen | Detail |
|---|---|
| Framework | SwiftUI + SwiftData |
| Language | Swift 6 |
| Min OS | iOS 17+ |
| Storage | SwiftData (on-device, no cloud) |
| Actor isolation | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| Tipe moneter | `Decimal` (bukan `Double`) |

---

## Navigasi Utama

```
[ Home ]  [ Transaksi ]  [ 🎙 Voice ]  [ Pocket ]  [ Pengaturan ]
```

---

## Models

### `Pocket`
| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama pocket (mis. BCA, GoPay) |
| `kelompokPocket` | `KelompokPocket` | `biasa` / `utang` |
| `kategoriPocket` | `KategoriPocket?` | Sub-kategori pocket |
| `saldo` | Decimal | Saldo saat ini (auto-adjust per transaksi) |
| `logo` | Data? | Foto logo custom |
| `limit` | Decimal? | Limit kredit / PayLater |
| `isAktif` | Bool | Soft delete |
| `urutan` | Int | Urutan tampil (drag reorder) |

---

### `Transaksi`
| Field | Tipe | Keterangan |
|---|---|---|
| `tanggal` | Date | Tanggal transaksi |
| `nominal` | Decimal | Nominal transaksi |
| `tipe` | `TipeTransaksi` | `pemasukan` / `pengeluaran` |
| `subTipe` | `SubTipeTransaksi` | `normal` / `simpanKeTarget` / `pakaiDariTarget` |
| `kategori` | `Kategori?` | Kategori transaksi (auto-nabung untuk simpanKeTarget) |
| `pocket` | `Pocket?` | Pocket asal/tujuan |
| `catatan` | String? | Catatan bebas |
| `goalID` | UUID? | Link ke Target (jika subTipe bukan normal) |
| `otomatisID` | UUID? | Link ke TransaksiOtomatis |

**Hapus transaksi → full rollback:**
- Pocket sumber di-refund
- SimpanKeTarget record ikut dihapus
- `linkedPocket` target dikurangi (bila simpanKeTarget)

---

### `Kategori`
| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama kategori |
| `tipe` | `TipeTransaksi` | Pengeluaran / Pemasukan |
| `ikon` | String | SF Symbol name |
| `warna` | String | Hex color |
| `klasifikasi` | `KlasifikasiExpense?` | `kebutuhanPokok` / `gayaHidup` |
| `kelompokIncome` | `KelompokIncome?` | Gaji / Freelance / dll |
| `isNabung` | Bool | → masuk "Nabung" di dashboard |
| `isAdmin` | Bool | Auto-assign biaya admin |
| `isHasilAset` | Bool | Auto-assign pemasukan jual aset |
| `urutan` | Int | Urutan tampil |

---

### `Anggaran`
| Field | Tipe | Keterangan |
|---|---|---|
| `kategori` | `Kategori?` | Kategori target (nil = global) |
| `nominal` | Decimal | Batas anggaran |
| `tipeAnggaran` | `TipeAnggaran` | `bulanan` |
| `berulang` | Bool | Otomatis aktif tiap bulan |
| `bulan`, `tahun` | Int | Bulan/tahun anggaran |
| `isAktif` | Bool | Toggle |

---

### `Target`
| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama target (mis. DP Rumah) |
| `targetNominal` | Decimal | Nominal yang ingin dicapai |
| `deadline` | Date? | Deadline target |
| `jenisTarget` | `JenisTarget` | `biasa` / `investasi` |
| `fotoData` | Data? | Foto background kartu |
| `linkedAset` | `Aset?` | Aset wadah dana (investasi) |
| `linkedPocket` | `Pocket?` | Pocket simpanan dana (biasa) — saldo otomatis bertambah saat simpan ke target |
| `riwayat` | `[SimpanKeTarget]` | Riwayat setoran (biasa) |
| `isSelesai` | Bool | Tandai selesai |

**Computed:** `tersimpan`, `progressPersen`, `sisa`

---

### `Aset`
| Field | Tipe | Keterangan |
|---|---|---|
| `tipe` | `TipeAset` | 6 tipe (lihat bawah) |
| `nama` | String | Nama aset |
| `kode` | String? | Ticker saham |
| `portofolio` | String? | Nama grup portofolio (mis. "Dana Pensiun") |
| `urutan` | Int | Urutan tampil (drag reorder, cross-group) |
| `nilaiSaatIni` | Decimal | Nilai terkini IDR |
| `logoData` | Data? | Foto/logo custom (PhotosPicker) |
| `pocketSumber` | `Pocket?` | Pocket asal dana |
| `linkedTarget` | `Target?` | Target investasi terhubung |

**Per tipe:**

| Tipe | Fields Khusus |
|---|---|
| Saham IDN | `lot`, `hargaPerLembar` (weighted avg) |
| Saham AS | `totalInvestasiUSD`, `hargaBeliPerShareUSD`, `hargaSaatIniUSD`, `kursBeliUSD`, `kursSaatIniUSD` |
| Reksadana | `jenisReksadana`, `totalInvestasiReksadana`, `hargaBeliPerUnit`, `navSaatIni`, `jumlahUnitReksadana` |
| Valas | `mataUangValas`, `jumlahValas`, `kursBeliPerUnit`, `kursSaatIni` |
| Emas | `jenisEmas`, `tahunCetak`, `beratGram`, `hargaBeliPerGram` |
| Deposito | `nominalDeposito`, `bungaPA`, `pphFinal`, `tenorBulan`, `tanggalMulaiDeposito`, `autoRollOver` |

---

### `PortofolioConfig`
| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama portofolio |
| `warna` | String | Hex color |
| `urutan` | Int | Urutan tampil |

---

### `Langganan`
| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama layanan |
| `nominal` | Decimal | Nominal per bulan |
| `tanggalTagih` | Int | Tanggal tagih (1–28) |
| `kategori` | `Kategori?` | Kategori saat bayar |
| `logo` | Data? | Foto logo custom |
| `isAktif` | Bool | Toggle |
| `urutan` | Int | Urutan tampil |
| `pembayaran` | `[PembayaranLangganan]` | Riwayat bayar |

---

### `TransferInternal`
| Field | Tipe | Keterangan |
|---|---|---|
| `pocketAsal` | `Pocket?` | Pocket pengirim |
| `pocketTujuan` | `Pocket?` | Pocket penerima |
| `nominal` | Decimal | Nominal |
| `biayaAdmin` | Decimal | Biaya admin opsional |
| `catatan` | String? | Catatan |

---

### `TransaksiOtomatis`
Model tersedia, engine belum aktif.

| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama |
| `nominal` | Decimal | Nominal |
| `tipe` | `TipeTransaksi` | Pemasukan / Pengeluaran |
| `kategori` | `Kategori?` | Kategori |
| `pocket` | `Pocket?` | Pocket tujuan |
| `frekuensi` | String | Harian / Mingguan / Bulanan |
| `tanggalMulai` | Date | Mulai aktif |
| `isAktif` | Bool | Toggle |

---

## File Structure

```
MyFinance/
├── Model/
│   ├── Pocket.swift
│   ├── Transaksi.swift
│   ├── Kategori.swift
│   ├── KategoriPocket.swift
│   ├── Anggaran.swift
│   ├── Target.swift              — linkedPocket (biasa), linkedAset (investasi)
│   ├── Aset.swift                — 6 tipe, portofolio, logoData
│   ├── PortofolioConfig.swift    — Konfigurasi grup portofolio aset
│   ├── Langganan.swift           — + PembayaranLangganan
│   ├── TransferInternal.swift
│   ├── TransaksiOtomatis.swift
│   ├── UserConfig.swift
│   └── AppEnums.swift
│
├── View/
│   ├── Main/
│   │   └── MainTabView.swift
│   ├── Home/
│   │   └── HomeView.swift
│   ├── Transaksi/
│   │   ├── TransaksiTabView.swift        — Pocket badge + target badge per baris
│   │   ├── AddEditTransaksiSheet.swift   — Auto nabung kategori untuk simpanKeTarget
│   │   ├── TransaksiDetailSheet.swift    — Full rollback saat hapus
│   │   ├── TransaksiGroupSheet.swift
│   │   └── TransferInternalSheet.swift
│   ├── Voice/
│   │   ├── VoiceTabView.swift
│   │   └── VoiceReviewSheet.swift
│   ├── Pocket/
│   │   ├── PocketTabView.swift
│   │   ├── PocketDetailSheet.swift
│   │   ├── PocketDetailView.swift
│   │   ├── AddEditPocketView.swift
│   │   └── DanaDaruratConfigView.swift
│   ├── Aset/
│   │   ├── AsetListView.swift            — Portfolio groups, cross-group drag reorder
│   │   ├── AsetDetailSheet.swift         — Inline edit harga beli/lembar (saham)
│   │   ├── AddEditAsetView.swift         — Logo upload, total modal editable (saham)
│   │   ├── BeliSahamSheet.swift
│   │   ├── TambahReksadanaSheet.swift
│   │   ├── JualAsetSheet.swift
│   │   ├── CairkanDepositoSheet.swift
│   │   └── AnalisaSahamView.swift        — Analisa teknikal IDN (tanpa NavigationStack)
│   ├── Target/
│   │   ├── TargetListView.swift
│   │   ├── TargetDetailSheet.swift       — Tampil linkedPocket
│   │   └── AddEditTargetView.swift       — Pocket picker untuk target biasa
│   ├── Langganan/
│   │   ├── LanggananBulanIniCard.swift
│   │   ├── LanggananManagementView.swift
│   │   ├── AddEditLanggananView.swift
│   │   └── LanggananReorderSheet.swift
│   ├── Analitik/
│   │   └── AnalitikView.swift
│   ├── Pengaturan/
│   │   ├── PengaturanView.swift
│   │   ├── KategoriManagementView.swift
│   │   ├── AddEditKategoriView.swift
│   │   ├── AnggaranManagementView.swift
│   │   ├── AddEditAnggaranView.swift
│   │   ├── TransaksiOtomatisView.swift
│   │   ├── AddEditTransaksiOtomatisView.swift
│   │   └── BackupRestoreView.swift
│   └── Components/
│       ├── CurrencyInputField.swift
│       ├── QuickAmountButtons.swift
│       ├── KategoriGridPicker.swift
│       ├── PocketChipPicker.swift
│       ├── ProgressBarView.swift
│       ├── MonthNavigator.swift
│       ├── IkonColorPicker.swift
│       └── FlowLayout.swift
│
├── Controller/
│   ├── ModelContainerService.swift
│   ├── AsetPriceService.swift        — Yahoo Finance + Frankfurter
│   ├── StockAnalysisService.swift    — EMA20, RSI14, volume
│   ├── BackupService.swift
│   ├── ReksadanaSearchService.swift  — Sucorinvest dataset (bundled JSON)
│   ├── NLPParser.swift
│   └── SpeechRecognitionService.swift
│
├── Resources/
│   └── reksadana.json                — 12 produk Sucorinvest (4 jenis)
│
└── Extension/
    ├── Color+Hex.swift
    ├── Color+App.swift
    ├── Date+Helpers.swift
    ├── Double+Formatting.swift
    └── TipeAset+UI.swift
```

---

## Fitur

### Home — Dashboard

| Widget | Keterangan |
|---|---|
| Top Bar | Avatar + nama + greeting + toggle hide balance |
| Month Navigator | Navigasi bulan |
| Cashflow Card | Pemasukan, Pengeluaran, Nabung bulan ini, Total Tabungan (dana tersimpan + aset) |
| Aman Dibelanjakan | `pemasukan - pengeluaran - nabung` |
| Total Kekayaan | `cash + dana tersimpan + aset - utang` |
| Rincian Biaya | % Kebutuhan Pokok, % Gaya Hidup, % Dana Tersimpan |
| Anggaran | Progress bar per kategori (kuning >80%, merah over budget) |
| Target Aktif | Semua target belum selesai, foto background + progress |
| Langganan | Status bayar bulan ini + tombol bayar |
| Kategori Teratas | Top 3 pengeluaran terbesar |
| Transaksi Terbaru | 5 transaksi terakhir |

---

### Transaksi

- List per bulan, search, group per hari
- Setiap baris tampil **pocket badge** (selalu) + **target badge** (bila linked ke target)
- Tambah / Edit / Hapus dengan rollback lengkap
- Sub-tipe `simpanKeTarget` → auto-assign kategori nabung + nambah saldo `linkedPocket` target
- Transfer antar pocket (pocket asal ↓, pocket tujuan ↑)
- Biaya admin opsional

---

### Pocket

- Kelompok: **Biasa** dan **Utang**
- Detail histori transaksi per pocket
- Logo custom (PhotosPicker)
- Drag reorder
- Dana Darurat Config

---

### Aset & Portfolio

**6 tipe:** Saham IDN, Saham AS, Reksadana, Valas, Emas, Deposito

- **Portfolio Grouping** — aset bisa dimasukkan ke grup portofolio bernama (mis. "Dana Pensiun")
- **Cross-group drag reorder** — drag aset ke grup lain → otomatis pindah portofolio
- **Logo custom** per aset (PhotosPicker)
- **Total Modal editable** pada saham — sync dua arah dengan harga/lot
- **Inline edit** rata-rata harga beli/lembar dari detail sheet

**Harga otomatis:**

| Tipe | Source |
|---|---|
| Saham IDN | Yahoo Finance `.JK` |
| Saham AS | Yahoo Finance + Frankfurter (kurs) |
| Valas | Frankfurter |
| Reksadana | Manual (NAV input user) |
| Emas | Manual |
| Deposito | — |

**Analisa Teknikal Saham IDN:**
- Fetch data 3 bulan terakhir dari Yahoo Finance
- Hitung: EMA20, RSI14, volume vs rata-rata 20 hari, candle bullish
- Sinyal: **BUY / HOLD / SELL** (score 0–4)
- Scroll hanya vertikal (NavigationStack dihapus dari sheet)

---

### Target Tabungan

| Jenis | Cara Kerja |
|---|---|
| **Biasa** | Setoran manual → `SimpanKeTarget` → progress dari sum riwayat. Pocket ter-link otomatis bertambah setiap simpan. |
| **Investasi** | Linked ke `Aset` → `nilaiEfektif` aset = progress (auto-update) |

- Foto background kartu
- Estimasi setoran/bulan dari deadline
- Tandai selesai
- Semua target aktif (belum selesai) tampil di Home tanpa filter progress

---

### Langganan

- Nominal + tanggal tagih bulanan
- Bayar → potong pocket + catat transaksi
- Batal bayar → refund pocket + hapus transaksi
- Logo custom, drag reorder
- Card ringkasan di Home

---

### Anggaran

- Per kategori atau global
- Progress bar: hijau → kuning (>80%) → merah (over)
- Berulang otomatis tiap bulan

---

### Voice Input

- Speech-to-text realtime
- NLP parser: tipe, nominal, pocket, kategori dari ucapan bebas
- Review sheet sebelum simpan

---

### Analitik

- Grafik cashflow bulanan
- Breakdown per kategori
- Tren bulanan

---

### Backup & Restore

- Export semua data → JSON
- Import/restore dari JSON
- Backward-compatible (field baru optional)

---

## External APIs

| API | Tujuan |
|---|---|
| `query2.finance.yahoo.com/v8/finance/chart/{ticker}` | Harga saham IDN (`.JK`) dan AS |
| `query2.finance.yahoo.com?interval=1d&range=3mo` | Historical data analisa teknikal |
| `api.frankfurter.app` | Kurs valas (USD, SGD, JPY) |

Semua API tanpa autentikasi. App tetap berjalan offline — API hanya untuk refresh harga.

---

## Konvensi

```swift
// Boolean baru di @Model — default di property level (bukan hanya di init)
var isNabung: Bool = false

// Optional baru di @Model — selalu pakai default nil (safe auto-migration)
var logoData: Data? = nil

// Codable optional field di struct — gunakan Bool? bukan Bool = false
// (Bool = false menyebabkan DecodingError.keyNotFound bila key tidak ada di JSON)
var featured: Bool?

// Pocket sort
@Query(sort: \Pocket.urutan) private var allPockets: [Pocket]

// Kategori nabung lookup
private var nabungKategori: Kategori? {
    allKategoris.first { $0.isNabung && $0.tipe == .pengeluaran }
}

// Weighted average saham
let modalLama  = lotLama * 100 * hargaLama
let avgBaru    = (modalLama + nominalBaru) / totalShares

// Save
try? modelContext.save()
```

---

## Known Issues / Tech Debt

| Item | Catatan |
|---|---|
| `TransaksiOtomatis` engine belum aktif | Model + UI ada, scheduler belum dibuat |
| `HomeView` fetch semua Transaksi in-memory | Filter di memory, OK untuk scale saat ini |
| iCloud/CloudKit sync | Belum ada — user belum punya Dev account aktif |
| `View/Main/TrackerView.swift` | File placeholder, belum digunakan |
