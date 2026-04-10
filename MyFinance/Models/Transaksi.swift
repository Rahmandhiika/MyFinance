import SwiftData
import Foundation

@Model
final class Expense {
    var id: UUID
    var tanggal: Date
    var nominal: Double
    var kategoriID: UUID?
    var pocketID: UUID?
    var catatan: String?
    var debiturID: UUID?
    var krediturID: UUID?
    var fileGambar: Data?
    var terjadwalID: UUID?
    var createdAt: Date

    init(tanggal: Date, nominal: Double, kategoriID: UUID? = nil, pocketID: UUID? = nil,
         catatan: String? = nil, debiturID: UUID? = nil, krediturID: UUID? = nil,
         terjadwalID: UUID? = nil) {
        self.id = UUID()
        self.tanggal = tanggal
        self.nominal = nominal
        self.kategoriID = kategoriID
        self.pocketID = pocketID
        self.catatan = catatan
        self.debiturID = debiturID
        self.krediturID = krediturID
        self.terjadwalID = terjadwalID
        self.createdAt = Date()
    }
}

@Model
final class Income {
    var id: UUID
    var tanggal: Date
    var nominal: Double
    var kategoriID: UUID?
    var pocketID: UUID?
    var catatan: String?
    var debiturID: UUID?
    var krediturID: UUID?
    var fileGambar: Data?
    var terjadwalID: UUID?
    var createdAt: Date

    init(tanggal: Date, nominal: Double, kategoriID: UUID? = nil, pocketID: UUID? = nil,
         catatan: String? = nil, debiturID: UUID? = nil, krediturID: UUID? = nil,
         terjadwalID: UUID? = nil) {
        self.id = UUID()
        self.tanggal = tanggal
        self.nominal = nominal
        self.kategoriID = kategoriID
        self.pocketID = pocketID
        self.catatan = catatan
        self.debiturID = debiturID
        self.krediturID = krediturID
        self.terjadwalID = terjadwalID
        self.createdAt = Date()
    }
}

@Model
final class TransferInternal {
    var id: UUID
    var tanggal: Date
    var nominal: Double
    var pocketAsalID: UUID
    var pocketTujuanID: UUID
    var catatan: String?
    var terjadwalID: UUID?
    var createdAt: Date

    init(tanggal: Date, nominal: Double, pocketAsalID: UUID, pocketTujuanID: UUID,
         catatan: String? = nil, terjadwalID: UUID? = nil) {
        self.id = UUID()
        self.tanggal = tanggal
        self.nominal = nominal
        self.pocketAsalID = pocketAsalID
        self.pocketTujuanID = pocketTujuanID
        self.catatan = catatan
        self.terjadwalID = terjadwalID
        self.createdAt = Date()
    }
}
