import Foundation

// MARK: - Transaksi

enum TipeTransaksi: String, Codable, CaseIterable, Identifiable {
    case pengeluaran = "pengeluaran"
    case pemasukan = "pemasukan"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pengeluaran: "Pengeluaran"
        case .pemasukan: "Pemasukan"
        }
    }
}

enum SubTipeTransaksi: String, Codable, CaseIterable, Identifiable {
    case normal = "normal"
    case simpanKeTarget = "simpanKeTarget"
    case pakaiDariTarget = "pakaiDariTarget"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal: "Normal"
        case .simpanKeTarget: "Simpan ke Target"
        case .pakaiDariTarget: "Pakai dari Target"
        }
    }
}

// MARK: - Klasifikasi Expense

enum KlasifikasiExpense: String, Codable, CaseIterable, Identifiable {
    case kebutuhanPokok = "kebutuhanPokok"
    case gayaHidup = "gayaHidup"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kebutuhanPokok: "Kebutuhan Pokok"
        case .gayaHidup: "Gaya Hidup"
        }
    }
}

// MARK: - Kelompok Income

enum KelompokIncome: String, Codable, CaseIterable, Identifiable {
    case gaji = "gaji"
    case freelance = "freelance"
    case produkDigital = "produkDigital"
    case jasaProfesional = "jasaProfesional"
    case passiveIncome = "passiveIncome"
    case socialMedia = "socialMedia"
    case lainnya = "lainnya"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gaji: "Gaji"
        case .freelance: "Freelance"
        case .produkDigital: "Produk Digital"
        case .jasaProfesional: "Jasa Profesional"
        case .passiveIncome: "Passive Income"
        case .socialMedia: "Social Media"
        case .lainnya: "Lainnya"
        }
    }
}

// MARK: - Pocket

enum KelompokPocket: String, Codable, CaseIterable, Identifiable {
    case biasa = "biasa"
    case utang = "utang"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .biasa: "Biasa"
        case .utang: "Utang"
        }
    }
}

// MARK: - Aset (5 tipe)

enum TipeAset: String, Codable, CaseIterable, Identifiable {
    case saham     = "saham"
    case sahamAS   = "sahamAS"
    case reksadana = "reksadana"
    case valas     = "valas"
    case emas      = "emas"
    case deposito  = "deposito"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .saham:     "Saham IDN"
        case .sahamAS:   "Saham AS"
        case .reksadana: "Reksadana"
        case .valas:     "Valas"
        case .emas:      "Emas"
        case .deposito:  "Deposito"
        }
    }
}

// MARK: - Anggaran

enum TipeAnggaran: String, Codable, CaseIterable, Identifiable {
    case bulanan = "bulanan"
    case harian  = "harian"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bulanan: "Bulanan"
        case .harian:  "Harian"
        }
    }
}

// MARK: - Valas

enum MataUangValas: String, Codable, CaseIterable, Identifiable {
    case usd = "USD"
    case sgd = "SGD"
    case jpy = "JPY"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd: "US Dollar (USD)"
        case .sgd: "Singapore Dollar (SGD)"
        case .jpy: "Japanese Yen (JPY)"
        }
    }

    var flag: String {
        switch self {
        case .usd: "🇺🇸"
        case .sgd: "🇸🇬"
        case .jpy: "🇯🇵"
        }
    }

    /// Franfkurter API currency code
    var apiCode: String { rawValue }
}

// MARK: - Emas

enum JenisEmas: String, Codable, CaseIterable, Identifiable {
    case lmAntam     = "LMAntam"
    case ubs         = "UBS"
    case antamRetro  = "AntamRetro"
    case ubsRetro    = "UBSRetro"
    case emasDigital = "EmasDigital"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lmAntam:     "LM Antam"
        case .ubs:         "UBS"
        case .antamRetro:  "Antam Retro"
        case .ubsRetro:    "UBS Retro"
        case .emasDigital: "Emas Digital"
        }
    }

    /// Emas digital (Pluang, dll) tidak punya tahun cetak
    var isDigital: Bool { self == .emasDigital }
}
