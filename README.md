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
| Charts | Swift Charts (native) |

---

## Navigasi Utama

```
[ Home ]  [ Transaksi ]  [ 🎙 Voice ]  [ Pocket ]  [ Pengaturan ]
```

Tab **Aset** diakses dari Home atau Pengaturan (belum jadi tab sendiri).

---

## Models

### `Pocket`
| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama pocket (mis. BCA, GoPay) |
| `kelompokPocket` | `KelompokPocket` | `biasa` / `utang` |
| `kategoriPocket` | `KategoriPocket?` | Sub-kategori pocket |
| `saldo` | Decimal | Saldo IDR saat ini |
| `saldoUSD` | Decimal | Saldo USD (hasil konversi IDR → USD) |
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
| `kategori` | `Kategori?` | Kategori transaksi |
| `pocket` | `Pocket?` | Pocket asal/tujuan |
| `catatan` | String? | Catatan bebas |
| `goalID` | UUID? | Link ke Target |
| `otomatisID` | UUID? | Link ke TransaksiOtomatis |

**Hapus transaksi → full rollback:** pocket sumber di-refund, SimpanKeTarget dihapus, linkedPocket target dikurangi.

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
| `isNabung` | Bool | Masuk bucket "Nabung" di dashboard |
| `isAdmin` | Bool | Auto-assign biaya admin transfer |
| `isHasilAset` | Bool | Auto-assign pemasukan dari jual aset |
| `urutan` | Int | Urutan tampil |

---

### `Anggaran`
| Field | Tipe | Keterangan |
|---|---|---|
| `kategori` | `Kategori?` | Target kategori (nil = global) |
| `nominal` | Decimal | Batas anggaran |
| `berulang` | Bool | Reset otomatis tiap bulan |
| `bulan`, `tahun` | Int | Periode anggaran |
| `isAktif` | Bool | Toggle aktif |

---

### `Target`
| Field | Tipe | Keterangan |
|---|---|---|
| `nama` | String | Nama target |
| `targetNominal` | Decimal | Nominal yang ingin dicapai |
| `deadline` | Date? | Deadline target |
| `jenisTarget` | `JenisTarget` | `biasa` / `investasi` |
| `fotoData` | Data? | Foto background kartu |
| `linkedAset` | `Aset?` | Aset wadah dana (investasi) |
| `linkedPocket` | `Pocket?` | Pocket simpanan (biasa) |
| `riwayat` | `[SimpanKeTarget]` | Riwayat setoran |
| `isSelesai` | Bool | Tandai selesai |

**Computed:** `tersimpan`, `progressPersen`, `sisa`

---

### `Aset`
| Field | Tipe | Keterangan |
|---|---|---|
| `tipe` | `TipeAset` | 6 tipe |
| `nama` | String | Nama aset |
| `kode` | String? | Ticker saham |
| `portofolio` | String? | Nama grup portofolio |
| `urutan` | Int | Urutan tampil (drag reorder, cross-group) |
| `nilaiSaatIni` | Decimal | Nilai terkini IDR |
| `logoData` | Data? | Foto/logo custom |
| `pocketSumber` | `Pocket?` | Pocket asal dana |
| `linkedTarget` | `Target?` | Target investasi terhubung |

**Per tipe:**

| Tipe | Fields Khusus |
|---|---|
| Saham IDN | `lot`, `hargaPerLembar` (weighted avg) |
| Saham AS | `totalInvestasiUSD`, `hargaBeliPerShareUSD`, `hargaSaatIniUSD`, `kursBeliUSD`, `kursSaatIniUSD`, `biayaFeeUSD` |
| Reksadana | `jenisReksadana`, `totalInvestasiReksadana`, `hargaBeliPerUnit`, `navSaatIni`, `jumlahUnitReksadana` |
| Valas | `mataUangValas`, `jumlahValas`, `kursBeliPerUnit`, `kursSaatIni` |
| Emas | `jenisEmas`, `beratGram`, `hargaBeliPerGram`, `hargaSaatIniEmasPerGram`, `pajakBeliEmas` |
| Deposito | `nominalDeposito`, `bungaPA`, `pphFinal`, `tenorBulan`, `tanggalMulaiDeposito`, `autoRollOver` |

---

### `NetWorthSnapshot`
| Field | Tipe | Keterangan |
|---|---|---|
| `tanggal` | Date | Tanggal snapshot |
| `totalNetWorth` | Decimal | Total kekayaan bersih |
| `totalAset` | Decimal | Total nilai semua aset |
| `totalCash` | Decimal | Total saldo pocket |

Dipakai untuk grafik tren net worth di Home.

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
| `catatan` | String? | Catatan |

---

### `UserConfig` / `UserProfile`
Menyimpan konfigurasi user: nama, avatar, `tanggalGajian` (1–28).

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
│   ├── Target.swift
│   ├── Aset.swift
│   ├── PortofolioConfig.swift
│   ├── Langganan.swift
│   ├── TransferInternal.swift
│   ├── TransaksiOtomatis.swift
│   ├── NetWorthSnapshot.swift
│   ├── AppTheme.swift
│   ├── UserConfig.swift
│   └── AppEnums.swift
│
├── View/
│   ├── Main/
│   │   └── MainTabView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── NetWorthChartCard.swift    — Grafik tren net worth (Swift Charts)
│   │   └── UpcomingCard.swift         — Tagihan mendatang + KalenderKeuanganSheet
│   ├── Transaksi/
│   │   ├── TransaksiTabView.swift
│   │   ├── AddEditTransaksiSheet.swift
│   │   ├── TransaksiDetailSheet.swift
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
│   │   ├── KonversiUSDSheet.swift     — Konversi IDR → USD dalam pocket
│   │   └── DanaDaruratConfigView.swift
│   ├── Aset/
│   │   ├── AsetListView.swift          — Portofolio groups, alokasi dengan nilai, IHSG/S&P500 card
│   │   ├── AsetDetailSheet.swift
│   │   ├── AddEditAsetView.swift
│   │   ├── AsetReorderSheet.swift
│   │   ├── MarketOverviewCard.swift    — IHSG + S&P 500 mini chart realtime
│   │   ├── BeliSahamSheet.swift
│   │   ├── BeliSahamASSheet.swift      — Beli saham US dari saldo USD
│   │   ├── BeliEmasSheet.swift         — Beli emas fisik & digital
│   │   ├── BeliValasSheet.swift
│   │   ├── TambahReksadanaSheet.swift
│   │   ├── JualAsetSheet.swift
│   │   ├── CairkanDepositoSheet.swift
│   │   ├── EditPortofolioSheet.swift
│   │   └── AnalisaSahamView.swift
│   ├── Target/
│   │   ├── TargetListView.swift
│   │   ├── TargetDetailSheet.swift
│   │   └── AddEditTargetView.swift
│   ├── Langganan/
│   │   ├── LanggananBulanIniCard.swift
│   │   ├── LanggananManagementView.swift
│   │   ├── AddEditLanggananView.swift
│   │   └── LanggananReorderSheet.swift
│   ├── Analitik/
│   │   └── AnalitikView.swift          — Saving rate, vs bulan lalu, insights, CSV export, siklus gajian
│   ├── Pengaturan/
│   │   ├── PengaturanView.swift
│   │   ├── KategoriManagementView.swift
│   │   ├── AddEditKategoriView.swift
│   │   ├── KategoriPocketManagementView.swift
│   │   ├── AnggaranManagementView.swift
│   │   ├── AddEditAnggaranView.swift
│   │   ├── TransaksiOtomatisView.swift
│   │   ├── AddEditTransaksiOtomatisView.swift
│   │   └── BackupRestoreView.swift
│   └── Components/
│       ├── CalcKeypad.swift            — Kalkulator numpad (+−×÷=%) untuk semua input nominal
│       ├── CurrencyInputField.swift    — Keyboard input (masih dipakai di form aset detail)
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
│   ├── MarketIndexService.swift       — IHSG + S&P 500 via Yahoo Finance (@Observable)
│   ├── AsetPriceService.swift         — Harga saham, valas, live fetch
│   ├── StockAnalysisService.swift     — EMA20, RSI14, sinyal BUY/HOLD/SELL
│   ├── ReksadanaSearchService.swift   — Dataset bundled JSON
│   ├── NLPParser.swift
│   ├── SpeechRecognitionService.swift
│   └── BackupService.swift
│
├── Service/
│   └── ThemeManager.swift             — Dark/light/system theme
│
├── Resources/
│   └── reksadana.json
│
└── Extension/
    ├── Color+Hex.swift
    ├── Color+App.swift
    ├── Date+Helpers.swift
    ├── Double+Formatting.swift        — idrFormatted, decimalDisplayFormatted, unitFormatted, shortFormatted
    └── TipeAset+UI.swift
```

---

## Fitur

### Home — Dashboard

| Widget | Keterangan |
|---|---|
| Top Bar | Avatar + nama + greeting + toggle hide balance |
| Month Navigator | Navigasi bulan |
| Net Worth Chart | Grafik tren kekayaan bersih (Swift Charts, dari NetWorthSnapshot) |
| Cashflow Card | Saldo awal → +Pemasukan → −Pengeluaran → Saldo saat ini |
| Total Kekayaan | `cash + dana tersimpan + aset - utang` |
| Rincian Biaya | % Kebutuhan Pokok, % Gaya Hidup, % Dana Tersimpan |
| Anggaran | Progress bar per kategori (kuning >80%, merah over budget) |
| Target Aktif | Semua target belum selesai + progress |
| Langganan | Status bayar bulan ini + card ringkasan |
| Upcoming Bills | Tagihan & gajian dalam 30 hari ke depan + Kalender Keuangan |
| Kategori Teratas | Top 3 pengeluaran terbesar |
| Transaksi Terbaru | 5 transaksi terakhir |

---

### Transaksi

- List per bulan, search, group per hari
- Tambah / Edit / Hapus dengan rollback lengkap
- Sub-tipe `simpanKeTarget` → auto-assign kategori nabung + tambah saldo linkedPocket
- Transfer antar pocket (asal ↓, tujuan ↑) + biaya admin opsional
- Input nominal pakai **CalcKeypad** (kalkulator penuh)

---

### Pocket

- Kelompok: **Biasa** dan **Utang**
- **Saldo USD** per pocket — dipakai untuk beli saham AS
- **Konversi IDR → USD** langsung dari pocket (KonversiUSDSheet)
- Detail histori transaksi per pocket
- Logo custom, drag reorder, Dana Darurat Config

---

### Aset & Portfolio

**6 tipe:** Saham IDN, Saham AS, Reksadana, Valas, Emas, Deposito

- **Market Overview Card** — IHSG 🇮🇩 + S&P 500 🇺🇸 realtime dengan mini area chart (Yahoo Finance)
- **Alokasi dengan nilai** — legend donut chart tampilkan % sekaligus nominal (mis. "45% · Rp 12,5jt")
- **Portfolio Grouping** — aset masuk grup bernama (mis. "Dana Pensiun")
- **Cross-group drag reorder** — drag aset ke grup lain → otomatis pindah portofolio
- **Logo custom** per aset
- **Saham AS** — input total dibayar (USD) + fee → shares otomatis dihitung, deduct dari saldoUSD pocket

**Harga otomatis:**

| Tipe | Source |
|---|---|
| Saham IDN | Yahoo Finance `.JK` |
| Saham AS | Yahoo Finance + Frankfurter (kurs) |
| Valas | Frankfurter |
| Reksadana | Manual (NAV) |
| Emas | Manual |
| Deposito | — |

**Analisa Teknikal Saham IDN:** EMA20, RSI14, volume vs rata-rata → sinyal **BUY / HOLD / SELL**

---

### Kalender Keuangan

Diakses dari Home → UpcomingCard:
- **Upcoming strip** — daftar tagihan + gajian dalam 30 hari, warna urgency (merah ≤2 hari, kuning 3–6 hari)
- **Full calendar sheet** — mini kalender bulanan dengan dot indikator per hari
- **Day detail panel** — tap tanggal → tampil semua event (bayar tagihan, gaji masuk, transaksi)
- Navigasi bulan maju/mundur

---

### Analitik

- **Mode Kalender** — filter per bulan kalender biasa
- **Mode Siklus Gajian** — filter dari tanggal gajian ke tanggal gajian berikutnya (otomatis menyesuaikan bulan aktif berdasarkan `tanggalGajian`)
- **Saldo Awal Bulan** — dihitung mundur dari saldo pocket saat ini dikurangi net transaksi sejak awal siklus
- **Cashflow Card** — Saldo Awal → +Pemasukan → −Pengeluaran → Saldo Saat Ini
- **Saving Rate Card** — persentase pemasukan yang ditabung + vs bulan lalu
- **Auto Insights** — kalimat otomatis berdasarkan kondisi keuangan (defisit, on track, surplus, gaji belum masuk, dll)
- **CSV Export** — export semua transaksi bulan/siklus sebagai file `.csv` via ShareLink
- Grafik cashflow harian, breakdown kategori, tren bulanan

---

### Target Tabungan

| Jenis | Cara Kerja |
|---|---|
| **Biasa** | Setoran manual → `SimpanKeTarget` → progress dari sum riwayat. Pocket ter-link otomatis bertambah. |
| **Investasi** | Linked ke `Aset` → `nilaiEfektif` aset = progress (auto-update) |

- Foto background kartu, deadline, estimasi setoran/bulan, tandai selesai

---

### Langganan

- Nominal + tanggal tagih bulanan
- Bayar → potong pocket + catat transaksi
- Batal bayar → refund pocket + hapus transaksi
- Logo custom, drag reorder

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

### Backup & Restore

- Export semua data → JSON
- Import/restore dari JSON
- Backward-compatible (field baru optional)

---

### Pengaturan

- **Tanggal Gajian** — pilih tanggal 1–28, dipakai Analitik untuk mode Siklus Gajian
- Manajemen Kategori, Kategori Pocket, Anggaran, Transaksi Otomatis
- Tema (dark / light / system)
- Backup & Restore

---

## Input Nominal — CalcKeypad

Semua field nominal di app menggunakan `CalcInputField` (tap → buka kalkulator):

```
[  ÷  |  ×  |  C  |  ⌫  ]
[  7  |  8  |  9  |  +  ]
[  4  |  5  |  6  |  −  ]
[  1  |  2  |  3  |  %  ]
[  0  | 000 |  ,  |  =  ]
```

- Support operasi berantai: `5.000.000 − 300.000 =`
- `%` kontekstual: standalone bagi 100, di tengah operasi hitung % dari akumulator
- Haptic feedback setiap tombol
- `CurrencyInputField` (keyboard) masih dipakai untuk input harga per unit / kurs di form aset

---

## External APIs

| API | Tujuan |
|---|---|
| `query1.finance.yahoo.com/v8/finance/chart/{ticker}` | Harga saham IDN (`.JK`), saham AS, IHSG (`^JKSE`), S&P 500 (`^GSPC`) |
| `query1.finance.yahoo.com?interval=1d&range=3mo` | Historical data analisa teknikal |
| `query1.finance.yahoo.com?interval=1d&range=1mo` | Mini chart data MarketOverviewCard |
| `api.frankfurter.app` | Kurs valas (USD, SGD, JPY) |

Catatan: `^` di ticker di-encode sebagai `%5E` supaya URL parse benar.  
Semua API tanpa autentikasi. App tetap berjalan offline — API hanya untuk refresh harga.

---

## Konvensi

```swift
// Boolean baru di @Model — default di property level (bukan hanya di init)
var isNabung: Bool = false

// Optional baru di @Model — selalu pakai default nil (safe auto-migration)
var logoData: Data? = nil

// Decimal format tanpa prefix — pakai extension (bukan inline NumberFormatter)
val.decimalDisplayFormatted   // "1.234.567,89"
val.idrFormatted              // "Rp 1.234.567"
val.shortFormatted            // "1,2jt"

// Pocket sort
@Query(sort: \Pocket.urutan) private var allPockets: [Pocket]

// Kategori nabung lookup
private var nabungKategori: Kategori? {
    allKategoris.first { $0.isNabung && $0.tipe == .pengeluaran }
}

// Weighted average saham
let modalLama = lotLama * 100 * hargaLama
let avgBaru   = (modalLama + nominalBaru) / totalShares

// MarketIndexService — singleton @Observable
@State private var service = MarketIndexService.shared
.task { await service.refresh() }

// Saldo awal siklus (dihitung mundur dari sekarang)
let saldoAwal = totalPocketNow - pemasukanFromStart + pengeluaranFromStart

// Save
try? modelContext.save()
```

---

## Known Issues / Tech Debt

| Item | Catatan |
|---|---|
| `TransaksiOtomatis` engine | Model + UI ada, scheduler belum diimplementasi |
| `HomeView` fetch semua Transaksi in-memory | Filter di memory, OK untuk scale saat ini |
| iCloud/CloudKit sync | Belum ada — belum ada Dev account aktif |
| `View/Main/TrackerView.swift` | Placeholder, belum digunakan |
| Market data rate limit | Yahoo Finance kadang throttle — tidak ada retry/cache logic |
