import SwiftUI

// MARK: - Pocket

enum KelompokPocket: String, Codable, CaseIterable {
    case biasa = "biasa"
    case investasi = "investasi"
    case utang = "utang"

    var displayName: String {
        switch self {
        case .biasa: "Biasa"
        case .investasi: "Investasi"
        case .utang: "Utang"
        }
    }

    var icon: String {
        switch self {
        case .biasa: "wallet.pass"
        case .investasi: "chart.line.uptrend.xyaxis"
        case .utang: "creditcard.fill"
        }
    }
}

enum NamaKategoriPocket: String, Codable, CaseIterable {
    case rekeningBank = "Rekening Bank"
    case eWallet = "E-Wallet"
    case eMoney = "E-Money"
    case dompet = "Dompet"
    case financing = "Financing"
    case akunBrand = "Akun Brand"
    case cryptoExchange = "Crypto Exchange"
    case akunSekuritas = "Akun Sekuritas"
    case cryptoWallet = "Crypto Wallet"
    case kartuKreditPayLater = "Kartu Kredit/PayLater"

    var displayName: String { rawValue }
}

enum WaktuUpdate: String, Codable, CaseIterable {
    case pagi = "pagi"
    case malam = "malam"
    var displayName: String {
        switch self {
        case .pagi: "Pagi"
        case .malam: "Malam"
        }
    }
}

// MARK: - Kategori Expense

enum Prioritas: String, Codable, CaseIterable {
    case blank = "blank"
    case p0 = "p0"
    case p1 = "p1"
    case p2 = "p2"
    case p3 = "p3"
    case p4 = "p4"

    var displayName: String {
        switch self {
        case .blank: "—"
        case .p0: "P0"
        case .p1: "P1"
        case .p2: "P2"
        case .p3: "P3"
        case .p4: "P4"
        }
    }

    var color: Color {
        switch self {
        case .blank: .gray
        case .p0: .red
        case .p1: .orange
        case .p2: .yellow
        case .p3: .green
        case .p4: .blue
        }
    }
}

enum KelompokExpense: String, Codable, CaseIterable {
    case expense = "expense"
    case nonExpense = "nonExpense"
    var displayName: String {
        switch self {
        case .expense: "Expense"
        case .nonExpense: "Non-Expense"
        }
    }
}

// MARK: - Kategori Income

enum KelompokIncome: String, Codable, CaseIterable {
    case gaji = "gaji"
    case produkDigital = "produkDigital"
    case jasaProfesional = "jasaProfesional"
    case passiveIncome = "passiveIncome"
    case socialMedia = "socialMedia"
    case nonIncome = "nonIncome"

    var displayName: String {
        switch self {
        case .gaji: "Gaji"
        case .produkDigital: "Produk Digital"
        case .jasaProfesional: "Jasa Profesional"
        case .passiveIncome: "Passive Income"
        case .socialMedia: "Social Media"
        case .nonIncome: "Non-Income"
        }
    }
}

// MARK: - Investasi

enum TipeInvestasi: String, Codable, CaseIterable {
    case reksadana = "reksadana"
    case saham = "saham"
    case emas = "emas"
    case kripto = "kripto"

    var displayName: String {
        switch self {
        case .reksadana: "Reksadana"
        case .saham: "Saham"
        case .emas: "Emas"
        case .kripto: "Kripto"
        }
    }

    var icon: String {
        switch self {
        case .reksadana: "chart.pie.fill"
        case .saham: "chart.bar.fill"
        case .emas: "circle.fill"
        case .kripto: "bitcoinsign.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .reksadana: .purple
        case .saham: .blue
        case .emas: .orange
        case .kripto: .cyan
        }
    }
}

// MARK: - Goal

enum TipeGoal: String, Codable, CaseIterable {
    case tabungan = "tabungan"
    case cicilan = "cicilan"
    var displayName: String {
        switch self {
        case .tabungan: "Tabungan"
        case .cicilan: "Cicilan"
        }
    }
}

// MARK: - Transaksi (for voice/NLP parsing)

enum TipeTransaksi: String, Codable, CaseIterable {
    case expense = "expense"
    case income = "income"
    case transfer = "transfer"

    var displayName: String {
        switch self {
        case .expense: "Pengeluaran"
        case .income: "Pemasukan"
        case .transfer: "Transfer"
        }
    }

    var icon: String {
        switch self {
        case .expense: "arrow.up.circle.fill"
        case .income: "arrow.down.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .expense: .red
        case .income: .green
        case .transfer: .blue
        }
    }
}
