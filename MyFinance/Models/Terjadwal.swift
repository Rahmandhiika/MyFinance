import SwiftData
import Foundation

@Model
final class ExpenseTerjadwal {
    var id: UUID
    var nama: String
    var setiapTanggal: Int
    var reminderAktif: Bool
    var catatOtomatisAktif: Bool
    var nominal: Double?
    var kategoriID: UUID?
    var pocketID: UUID?
    var catatan: String?
    var isAktif: Bool
    var createdAt: Date

    init(nama: String, setiapTanggal: Int, reminderAktif: Bool = true,
         catatOtomatisAktif: Bool = false, nominal: Double? = nil,
         kategoriID: UUID? = nil, pocketID: UUID? = nil, catatan: String? = nil) {
        self.id = UUID()
        self.nama = nama
        self.setiapTanggal = setiapTanggal
        self.reminderAktif = reminderAktif
        self.catatOtomatisAktif = catatOtomatisAktif
        self.nominal = nominal
        self.kategoriID = kategoriID
        self.pocketID = pocketID
        self.catatan = catatan
        self.isAktif = true
        self.createdAt = Date()
    }
}

@Model
final class IncomeTerjadwal {
    var id: UUID
    var nama: String
    var setiapTanggal: Int
    var reminderAktif: Bool
    var catatOtomatisAktif: Bool
    var nominal: Double?
    var kategoriID: UUID?
    var pocketID: UUID?
    var catatan: String?
    var isAktif: Bool
    var createdAt: Date

    init(nama: String, setiapTanggal: Int, reminderAktif: Bool = true,
         catatOtomatisAktif: Bool = false, nominal: Double? = nil,
         kategoriID: UUID? = nil, pocketID: UUID? = nil, catatan: String? = nil) {
        self.id = UUID()
        self.nama = nama
        self.setiapTanggal = setiapTanggal
        self.reminderAktif = reminderAktif
        self.catatOtomatisAktif = catatOtomatisAktif
        self.nominal = nominal
        self.kategoriID = kategoriID
        self.pocketID = pocketID
        self.catatan = catatan
        self.isAktif = true
        self.createdAt = Date()
    }
}

@Model
final class TransferInternalTerjadwal {
    var id: UUID
    var nama: String
    var setiapTanggal: Int
    var reminderAktif: Bool
    var catatOtomatisAktif: Bool
    var nominal: Double?
    var pocketAsalID: UUID?
    var pocketTujuanID: UUID?
    var catatan: String?
    var isAktif: Bool
    var createdAt: Date

    init(nama: String, setiapTanggal: Int, reminderAktif: Bool = true,
         catatOtomatisAktif: Bool = false, nominal: Double? = nil,
         pocketAsalID: UUID? = nil, pocketTujuanID: UUID? = nil, catatan: String? = nil) {
        self.id = UUID()
        self.nama = nama
        self.setiapTanggal = setiapTanggal
        self.reminderAktif = reminderAktif
        self.catatOtomatisAktif = catatOtomatisAktif
        self.nominal = nominal
        self.pocketAsalID = pocketAsalID
        self.pocketTujuanID = pocketTujuanID
        self.catatan = catatan
        self.isAktif = true
        self.createdAt = Date()
    }
}
