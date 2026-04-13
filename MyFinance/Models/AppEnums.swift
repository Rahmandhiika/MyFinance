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

// MARK: - Aset

enum TipeAset: String, Codable, CaseIterable, Identifiable {
    case saham = "saham"
    case kripto = "kripto"
    case reksadana = "reksadana"
    case emas = "emas"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .saham: "Saham"
        case .kripto: "Kripto"
        case .reksadana: "Reksadana"
        case .emas: "Emas"
        }
    }
}

// MARK: - Anggaran

enum TipeAnggaran: String, Codable, CaseIterable, Identifiable {
    case bulanan = "bulanan"
    case harian = "harian"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bulanan: "Bulanan"
        case .harian: "Harian"
        }
    }
}

// MARK: - Kripto

enum MataUangKripto: String, Codable, CaseIterable, Identifiable {
    case idr = "IDR"
    case usdt = "USDT"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .idr: "IDR"
        case .usdt: "USDT"
        }
    }
}

// MARK: - Emas

enum JenisEmas: String, Codable, CaseIterable, Identifiable {
    case lmAntam = "LMAntam"
    case ubs = "UBS"
    case antamRetro = "AntamRetro"
    case ubsRetro = "UBSRetro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lmAntam: "LM Antam"
        case .ubs: "UBS"
        case .antamRetro: "Antam Retro"
        case .ubsRetro: "UBS Retro"
        }
    }
}
