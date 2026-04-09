import SwiftUI

enum AccountType: String, Codable, CaseIterable {
    case cash = "cash"
    case debit = "debit"
    case credit = "credit"
    case investment = "investment"

    var displayName: String {
        switch self {
        case .cash: "Cash / Dompet"
        case .debit: "Rekening Debit"
        case .credit: "Kredit / Paylater"
        case .investment: "Investasi"
        }
    }
    var icon: String {
        switch self {
        case .cash: "banknotes"
        case .debit: "creditcard"
        case .credit: "creditcard.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
}

enum AppCurrency: String, Codable, CaseIterable {
    case IDR = "IDR"
    case USD = "USD"
    var symbol: String { self == .IDR ? "Rp" : "$" }
}

enum TransactionType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    case transfer = "transfer"
    case payCredit = "payCredit"

    var displayName: String {
        switch self {
        case .income: "Pemasukan"
        case .expense: "Pengeluaran"
        case .transfer: "Transfer"
        case .payCredit: "Bayar Tagihan"
        }
    }
    var icon: String {
        switch self {
        case .income: "arrow.down.circle.fill"
        case .expense: "arrow.up.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        case .payCredit: "creditcard.fill"
        }
    }
    var color: Color {
        switch self {
        case .income: .green
        case .expense: .red
        case .transfer: .blue
        case .payCredit: .orange
        }
    }
}

enum CategoryTransactionType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
}

enum RecurringInterval: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    var displayName: String {
        switch self {
        case .daily: "Harian"
        case .weekly: "Mingguan"
        case .monthly: "Bulanan"
        case .yearly: "Tahunan"
        }
    }
}

enum AssetType: String, Codable, CaseIterable {
    case stock = "stock"
    case etf = "etf"
    case commodity = "commodity"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .stock: "Saham"
        case .etf: "ETF/Index"
        case .commodity: "Komoditas"
        case .custom: "Lainnya"
        }
    }
}

enum PortfolioViewMode: String, CaseIterable {
    case stocks = "Stocks"
    case subSector = "Sub-Sector"
}
