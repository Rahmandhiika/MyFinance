import Foundation
import SwiftData

// MARK: - Backup DTOs

struct BackupFile: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let kategoriPocket: [KategoriPocketDTO]
    let kategori: [KategoriDTO]
    let pocket: [PocketDTO]
    let transaksi: [TransaksiDTO]
    let transferInternal: [TransferInternalDTO]
    let aset: [AsetDTO]
    let langganan: [LanggananDTO]
    let portofolioConfigs: [PortofolioConfigDTO]
    let target: [TargetDTO]
}

// Backward-compat: pindah init(from:) ke extension supaya memberwise init tetap ada
extension BackupFile {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion    = try c.decode(Int.self, forKey: .schemaVersion)
        exportedAt       = try c.decode(Date.self, forKey: .exportedAt)
        kategoriPocket   = try c.decode([KategoriPocketDTO].self, forKey: .kategoriPocket)
        kategori         = try c.decode([KategoriDTO].self, forKey: .kategori)
        pocket           = try c.decode([PocketDTO].self, forKey: .pocket)
        transaksi        = try c.decode([TransaksiDTO].self, forKey: .transaksi)
        transferInternal = try c.decode([TransferInternalDTO].self, forKey: .transferInternal)
        aset             = try c.decode([AsetDTO].self, forKey: .aset)
        langganan        = (try? c.decode([LanggananDTO].self, forKey: .langganan)) ?? []
        portofolioConfigs = (try? c.decode([PortofolioConfigDTO].self, forKey: .portofolioConfigs)) ?? []
        target           = (try? c.decode([TargetDTO].self, forKey: .target)) ?? []
    }
}

// MARK: - Target DTOs

struct TargetDTO: Codable {
    let id: UUID
    let nama: String
    let targetNominal: String
    let deadline: Date?
    let ikon: String
    let ikonCustom: String?
    let warna: String
    let catatan: String?
    let isSelesai: Bool
    let jenisTarget: String
    let fotoData: String?        // Base64
    let createdAt: Date
    let linkedPocketNama: String?
    let riwayat: [SimpanKeTargetDTO]
}

struct SimpanKeTargetDTO: Codable {
    let tanggal: Date
    let nominal: String
    let catatan: String?
    let createdAt: Date
}

// MARK: - Other DTOs

struct LanggananDTO: Codable {
    let nama: String
    let nominal: String
    let tanggalTagih: Int
    let kategoriNama: String?
    let catatan: String?
    let logo: String?          // Base64
    let isAktif: Bool
    let urutan: Int
}

struct KategoriPocketDTO: Codable {
    let nama: String
    let urutan: Int
}

struct KategoriDTO: Codable {
    let nama: String
    let tipe: String
    let klasifikasi: String?
    let kelompokIncome: String?
    let ikon: String
    let ikonCustom: String?
    let warna: String
    let urutan: Int
}

struct PocketDTO: Codable {
    let nama: String
    let kelompok: String
    let kategoriPocketNama: String?
    let saldo: String          // Decimal as String to preserve precision
    let logo: String?          // Base64
    let catatan: String?
    let limit: String?
    let urutan: Int
}

struct TransaksiDTO: Codable {
    let tanggal: Date
    let nominal: String
    let tipe: String
    let subTipe: String
    let kategoriNama: String?
    let pocketNama: String?
    let catatan: String?
    let klasifikasiExpense: String?
    let kelompokIncome: String?
    let goalID: UUID?          // link ke Target
}

// Backward-compat TransaksiDTO
extension TransaksiDTO {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tanggal          = try c.decode(Date.self, forKey: .tanggal)
        nominal          = try c.decode(String.self, forKey: .nominal)
        tipe             = try c.decode(String.self, forKey: .tipe)
        subTipe          = try c.decode(String.self, forKey: .subTipe)
        kategoriNama     = try? c.decode(String?.self, forKey: .kategoriNama)
        pocketNama       = try? c.decode(String?.self, forKey: .pocketNama)
        catatan          = try? c.decode(String?.self, forKey: .catatan)
        klasifikasiExpense = try? c.decode(String?.self, forKey: .klasifikasiExpense)
        kelompokIncome   = try? c.decode(String?.self, forKey: .kelompokIncome)
        goalID           = try? c.decode(UUID?.self, forKey: .goalID)
    }
}

struct TransferInternalDTO: Codable {
    let tanggal: Date
    let nominal: String
    let pocketAsalNama: String?
    let pocketTujuanNama: String?
    let catatan: String?
}

struct PortofolioConfigDTO: Codable {
    let nama: String
    let warna: String
    let urutan: Int
}

struct AsetDTO: Codable {
    let tipe: String
    let nama: String
    let kode: String?
    let lot: String?
    let hargaPerLembar: String?
    let jenisReksadana: String?
    let totalInvestasiReksadana: String?
    let hargaBeliPerUnit: String?
    let navSaatIni: String?
    let jumlahUnitReksadana: String?   // override unit aktual
    let totalInvestasiUSD: String?
    let hargaBeliPerShareUSD: String?
    let hargaSaatIniUSD: String?
    let kursBeliUSD: String?
    let kursSaatIniUSD: String?
    let mataUangValas: String?
    let jumlahValas: String?
    let kursBeliPerUnit: String?
    let kursSaatIni: String?
    let jenisEmas: String?
    let tahunCetak: Int?
    let beratGram: String?
    let hargaBeliPerGram: String?
    let nominalDeposito: String?
    let bungaPA: String?
    let pphFinal: String?
    let tenorBulan: Int?
    let tanggalMulaiDeposito: Date?
    let autoRollOver: Bool
    let nilaiSaatIni: String
    let urutan: Int
    let portofolio: String?            // nama grup portfolio
    let logoData: String?              // Base64 logo/foto custom
    let catatSbgPengeluaran: Bool
    let pocketSumberNama: String?
    let linkedTargetID: UUID?          // untuk aset yang merupakan wadah target investasi
}

// Backward-compat AsetDTO
extension AsetDTO {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tipe                    = try c.decode(String.self, forKey: .tipe)
        nama                    = try c.decode(String.self, forKey: .nama)
        kode                    = try? c.decode(String?.self, forKey: .kode)
        lot                     = try? c.decode(String?.self, forKey: .lot)
        hargaPerLembar          = try? c.decode(String?.self, forKey: .hargaPerLembar)
        jenisReksadana          = try? c.decode(String?.self, forKey: .jenisReksadana)
        totalInvestasiReksadana = try? c.decode(String?.self, forKey: .totalInvestasiReksadana)
        hargaBeliPerUnit        = try? c.decode(String?.self, forKey: .hargaBeliPerUnit)
        navSaatIni              = try? c.decode(String?.self, forKey: .navSaatIni)
        jumlahUnitReksadana     = try? c.decode(String?.self, forKey: .jumlahUnitReksadana)
        totalInvestasiUSD       = try? c.decode(String?.self, forKey: .totalInvestasiUSD)
        hargaBeliPerShareUSD    = try? c.decode(String?.self, forKey: .hargaBeliPerShareUSD)
        hargaSaatIniUSD         = try? c.decode(String?.self, forKey: .hargaSaatIniUSD)
        kursBeliUSD             = try? c.decode(String?.self, forKey: .kursBeliUSD)
        kursSaatIniUSD          = try? c.decode(String?.self, forKey: .kursSaatIniUSD)
        mataUangValas           = try? c.decode(String?.self, forKey: .mataUangValas)
        jumlahValas             = try? c.decode(String?.self, forKey: .jumlahValas)
        kursBeliPerUnit         = try? c.decode(String?.self, forKey: .kursBeliPerUnit)
        kursSaatIni             = try? c.decode(String?.self, forKey: .kursSaatIni)
        jenisEmas               = try? c.decode(String?.self, forKey: .jenisEmas)
        tahunCetak              = try? c.decode(Int?.self, forKey: .tahunCetak)
        beratGram               = try? c.decode(String?.self, forKey: .beratGram)
        hargaBeliPerGram        = try? c.decode(String?.self, forKey: .hargaBeliPerGram)
        nominalDeposito         = try? c.decode(String?.self, forKey: .nominalDeposito)
        bungaPA                 = try? c.decode(String?.self, forKey: .bungaPA)
        pphFinal                = try? c.decode(String?.self, forKey: .pphFinal)
        tenorBulan              = try? c.decode(Int?.self, forKey: .tenorBulan)
        tanggalMulaiDeposito    = try? c.decode(Date?.self, forKey: .tanggalMulaiDeposito)
        autoRollOver            = (try? c.decode(Bool.self, forKey: .autoRollOver)) ?? false
        nilaiSaatIni            = try c.decode(String.self, forKey: .nilaiSaatIni)
        urutan                  = (try? c.decode(Int.self, forKey: .urutan)) ?? 0
        portofolio              = try? c.decode(String?.self, forKey: .portofolio)
        logoData                = try? c.decode(String?.self, forKey: .logoData)
        catatSbgPengeluaran     = (try? c.decode(Bool.self, forKey: .catatSbgPengeluaran)) ?? false
        pocketSumberNama        = try? c.decode(String?.self, forKey: .pocketSumberNama)
        linkedTargetID          = try? c.decode(UUID?.self, forKey: .linkedTargetID)
    }
}

// MARK: - BackupService

final class BackupService {
    static let shared = BackupService()
    private let schemaVersion = 2

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Export

    func export(context: ModelContext) throws -> Data {
        let kategoriPocket    = try context.fetch(FetchDescriptor<KategoriPocket>(sortBy: [SortDescriptor(\.urutan)]))
        let kategori          = try context.fetch(FetchDescriptor<Kategori>(sortBy: [SortDescriptor(\.urutan)]))
        let pocket            = try context.fetch(FetchDescriptor<Pocket>(sortBy: [SortDescriptor(\.urutan)]))
        let transaksi         = try context.fetch(FetchDescriptor<Transaksi>(sortBy: [SortDescriptor(\.tanggal)]))
        let transfer          = try context.fetch(FetchDescriptor<TransferInternal>(sortBy: [SortDescriptor(\.tanggal)]))
        let aset              = try context.fetch(FetchDescriptor<Aset>(sortBy: [SortDescriptor(\.urutan)]))  // SEMUA aset
        let langganan         = try context.fetch(FetchDescriptor<Langganan>(sortBy: [SortDescriptor(\.urutan)]))
        let portofolioConfigs = try context.fetch(FetchDescriptor<PortofolioConfig>(sortBy: [SortDescriptor(\.urutan)]))
        let targets           = try context.fetch(FetchDescriptor<Target>())

        let backup = BackupFile(
            schemaVersion: schemaVersion,
            exportedAt: Date(),
            kategoriPocket: kategoriPocket.map(mapKategoriPocket),
            kategori: kategori.map(mapKategori),
            pocket: pocket.map(mapPocket),
            transaksi: transaksi.map(mapTransaksi),
            transferInternal: transfer.map(mapTransfer),
            aset: aset.map(mapAset),
            langganan: langganan.map(mapLangganan),
            portofolioConfigs: portofolioConfigs.map { PortofolioConfigDTO(nama: $0.nama, warna: $0.warna, urutan: $0.urutan) },
            target: targets.map(mapTarget)
        )
        return try encoder.encode(backup)
    }

    // MARK: - Import (replace all)

    func restore(data: Data, context: ModelContext) throws -> RestoreSummary {
        let backup = try decoder.decode(BackupFile.self, from: data)

        // 1. Hapus semua data lama
        try context.delete(model: SimpanKeTarget.self)
        try context.delete(model: Transaksi.self)
        try context.delete(model: TransferInternal.self)
        try context.delete(model: PembayaranLangganan.self)
        try context.delete(model: Langganan.self)
        try context.delete(model: Aset.self)
        try context.delete(model: Target.self)
        try context.delete(model: KategoriPocket.self)
        try context.delete(model: Kategori.self)
        try context.delete(model: Pocket.self)
        try context.delete(model: PortofolioConfig.self)
        try context.save()

        // 2. KategoriPocket
        for dto in backup.kategoriPocket {
            context.insert(KategoriPocket(nama: dto.nama, urutan: dto.urutan))
        }
        try context.save()

        // 3. Kategori
        for dto in backup.kategori {
            let k = Kategori(
                nama: dto.nama,
                tipe: TipeTransaksi(rawValue: dto.tipe) ?? .pengeluaran,
                ikon: dto.ikon,
                warna: dto.warna
            )
            k.ikonCustom   = dto.ikonCustom
            k.klasifikasi  = dto.klasifikasi.flatMap { KlasifikasiExpense(rawValue: $0) }
            k.kelompokIncome = dto.kelompokIncome.flatMap { KelompokIncome(rawValue: $0) }
            k.urutan       = dto.urutan
            context.insert(k)
        }
        try context.save()

        // Fetch lookup maps
        let allKP  = try context.fetch(FetchDescriptor<KategoriPocket>())
        let allKat = try context.fetch(FetchDescriptor<Kategori>())
        let kpMap  = Dictionary(uniqueKeysWithValues: allKP.map { ($0.nama, $0) })
        let katMap = Dictionary(uniqueKeysWithValues: allKat.map { ($0.nama, $0) })

        // 4. Pocket
        for dto in backup.pocket {
            let p = Pocket(
                nama: dto.nama,
                kelompokPocket: KelompokPocket(rawValue: dto.kelompok) ?? .biasa,
                kategoriPocket: dto.kategoriPocketNama.flatMap { kpMap[$0] },
                saldo: Decimal(string: dto.saldo) ?? 0,
                catatan: dto.catatan
            )
            p.limit   = dto.limit.flatMap { Decimal(string: $0) }
            p.urutan  = dto.urutan
            if let b64 = dto.logo, let data = Data(base64Encoded: b64) { p.logo = data }
            context.insert(p)
        }
        try context.save()

        let allPocket = try context.fetch(FetchDescriptor<Pocket>())
        let pocketMap = Dictionary(uniqueKeysWithValues: allPocket.map { ($0.nama, $0) })

        // 5. PortofolioConfig
        for dto in backup.portofolioConfigs {
            context.insert(PortofolioConfig(nama: dto.nama, warna: dto.warna, urutan: dto.urutan))
        }
        try context.save()

        // 6. Target — insert dulu tanpa linkedAset, simpan UUID map
        var targetByID: [UUID: Target] = [:]
        for dto in backup.target {
            let t = Target(
                nama: dto.nama,
                targetNominal: Decimal(string: dto.targetNominal) ?? 0,
                deadline: dto.deadline,
                ikon: dto.ikon,
                warna: dto.warna,
                jenisTarget: JenisTarget(rawValue: dto.jenisTarget) ?? .biasa
            )
            t.id          = dto.id   // preserve UUID supaya goalID pada Transaksi tetap valid
            t.ikonCustom  = dto.ikonCustom
            t.catatan     = dto.catatan
            t.isSelesai   = dto.isSelesai
            t.createdAt   = dto.createdAt
            t.linkedPocket = dto.linkedPocketNama.flatMap { pocketMap[$0] }
            if let b64 = dto.fotoData, let data = Data(base64Encoded: b64) { t.fotoData = data }
            context.insert(t)
            targetByID[dto.id] = t
        }
        try context.save()

        // 7. Aset — insert semua, simpan map untuk link ke Target setelahnya
        var asetByLinkedTargetID: [UUID: Aset] = [:]
        for dto in backup.aset {
            let tipeAset = TipeAset(rawValue: dto.tipe) ?? .saham
            let a = Aset(tipe: tipeAset, nama: dto.nama, kode: dto.kode)
            a.lot                    = dto.lot.flatMap { Decimal(string: $0) }
            a.hargaPerLembar         = dto.hargaPerLembar.flatMap { Decimal(string: $0) }
            a.jenisReksadana         = dto.jenisReksadana
            a.totalInvestasiReksadana = dto.totalInvestasiReksadana.flatMap { Decimal(string: $0) }
            a.hargaBeliPerUnit       = dto.hargaBeliPerUnit.flatMap { Decimal(string: $0) }
            a.navSaatIni             = dto.navSaatIni.flatMap { Decimal(string: $0) }
            a.jumlahUnitReksadana    = dto.jumlahUnitReksadana.flatMap { Decimal(string: $0) }
            a.totalInvestasiUSD      = dto.totalInvestasiUSD.flatMap { Decimal(string: $0) }
            a.hargaBeliPerShareUSD   = dto.hargaBeliPerShareUSD.flatMap { Decimal(string: $0) }
            a.hargaSaatIniUSD        = dto.hargaSaatIniUSD.flatMap { Decimal(string: $0) }
            a.kursBeliUSD            = dto.kursBeliUSD.flatMap { Decimal(string: $0) }
            a.kursSaatIniUSD         = dto.kursSaatIniUSD.flatMap { Decimal(string: $0) }
            a.mataUangValas          = dto.mataUangValas.flatMap { MataUangValas(rawValue: $0) }
            a.jumlahValas            = dto.jumlahValas.flatMap { Decimal(string: $0) }
            a.kursBeliPerUnit        = dto.kursBeliPerUnit.flatMap { Decimal(string: $0) }
            a.kursSaatIni            = dto.kursSaatIni.flatMap { Decimal(string: $0) }
            a.jenisEmas              = dto.jenisEmas.flatMap { JenisEmas(rawValue: $0) }
            a.tahunCetak             = dto.tahunCetak
            a.beratGram              = dto.beratGram.flatMap { Decimal(string: $0) }
            a.hargaBeliPerGram       = dto.hargaBeliPerGram.flatMap { Decimal(string: $0) }
            a.nominalDeposito        = dto.nominalDeposito.flatMap { Decimal(string: $0) }
            a.bungaPA                = dto.bungaPA.flatMap { Decimal(string: $0) }
            a.pphFinal               = dto.pphFinal.flatMap { Decimal(string: $0) }
            a.tenorBulan             = dto.tenorBulan
            a.tanggalMulaiDeposito   = dto.tanggalMulaiDeposito
            a.autoRollOver           = dto.autoRollOver
            a.nilaiSaatIni           = Decimal(string: dto.nilaiSaatIni) ?? 0
            a.urutan                 = dto.urutan
            a.portofolio             = dto.portofolio
            a.catatSbgPengeluaran    = dto.catatSbgPengeluaran
            a.pocketSumber           = dto.pocketSumberNama.flatMap { pocketMap[$0] }
            if let b64 = dto.logoData, let data = Data(base64Encoded: b64) { a.logoData = data }
            context.insert(a)

            // Simpan untuk linking nanti
            if let tid = dto.linkedTargetID {
                asetByLinkedTargetID[tid] = a
            }
        }
        try context.save()

        // 8. Link Target.linkedAset ↔ Aset.linkedTarget (dua arah)
        for (targetID, aset) in asetByLinkedTargetID {
            if let target = targetByID[targetID] {
                target.linkedAset = aset
            }
        }
        try context.save()

        // 9. SimpanKeTarget
        for dto in backup.target {
            guard let target = targetByID[dto.id] else { continue }
            for rDto in dto.riwayat {
                let r = SimpanKeTarget(
                    target: target,
                    tanggal: rDto.tanggal,
                    nominal: Decimal(string: rDto.nominal) ?? 0,
                    catatan: rDto.catatan
                )
                r.createdAt = rDto.createdAt
                context.insert(r)
            }
        }
        try context.save()

        // 10. Transaksi (dengan goalID)
        for dto in backup.transaksi {
            let t = Transaksi(
                tanggal: dto.tanggal,
                nominal: Decimal(string: dto.nominal) ?? 0,
                tipe: TipeTransaksi(rawValue: dto.tipe) ?? .pengeluaran,
                subTipe: SubTipeTransaksi(rawValue: dto.subTipe) ?? .normal,
                pocket: dto.pocketNama.flatMap { pocketMap[$0] },
                catatan: dto.catatan
            )
            t.kategori = dto.kategoriNama.flatMap { katMap[$0] }
            t.goalID   = dto.goalID   // UUID langsung — target sudah ada dengan ID sama
            context.insert(t)
        }

        // 11. TransferInternal
        for dto in backup.transferInternal {
            let tr = TransferInternal(
                tanggal: dto.tanggal,
                nominal: Decimal(string: dto.nominal) ?? 0,
                pocketAsal: dto.pocketAsalNama.flatMap { pocketMap[$0] },
                pocketTujuan: dto.pocketTujuanNama.flatMap { pocketMap[$0] },
                catatan: dto.catatan
            )
            context.insert(tr)
        }

        // 12. Langganan
        for dto in backup.langganan {
            let l = Langganan(
                nama: dto.nama,
                nominal: Decimal(string: dto.nominal) ?? 0,
                tanggalTagih: dto.tanggalTagih,
                kategori: dto.kategoriNama.flatMap { katMap[$0] },
                catatan: dto.catatan
            )
            l.isAktif = dto.isAktif
            l.urutan  = dto.urutan
            if let b64 = dto.logo, let data = Data(base64Encoded: b64) { l.logo = data }
            context.insert(l)
        }

        try context.save()

        return RestoreSummary(
            pocket: backup.pocket.count,
            kategori: backup.kategori.count,
            transaksi: backup.transaksi.count,
            transfer: backup.transferInternal.count,
            aset: backup.aset.count,
            langganan: backup.langganan.count,
            portofolioConfig: backup.portofolioConfigs.count,
            target: backup.target.count,
            simpanKeTarget: backup.target.reduce(0) { $0 + $1.riwayat.count }
        )
    }

    // MARK: - Mappers

    private func mapKategoriPocket(_ k: KategoriPocket) -> KategoriPocketDTO {
        KategoriPocketDTO(nama: k.nama, urutan: k.urutan)
    }

    private func mapKategori(_ k: Kategori) -> KategoriDTO {
        KategoriDTO(
            nama: k.nama,
            tipe: k.tipe.rawValue,
            klasifikasi: k.klasifikasi?.rawValue,
            kelompokIncome: k.kelompokIncome?.rawValue,
            ikon: k.ikon,
            ikonCustom: k.ikonCustom,
            warna: k.warna,
            urutan: k.urutan
        )
    }

    private func mapPocket(_ p: Pocket) -> PocketDTO {
        PocketDTO(
            nama: p.nama,
            kelompok: p.kelompokPocket.rawValue,
            kategoriPocketNama: p.kategoriPocket?.nama,
            saldo: "\(p.saldo)",
            logo: p.logo?.base64EncodedString(),
            catatan: p.catatan,
            limit: p.limit.map { "\($0)" },
            urutan: p.urutan
        )
    }

    private func mapTransaksi(_ t: Transaksi) -> TransaksiDTO {
        TransaksiDTO(
            tanggal: t.tanggal,
            nominal: "\(t.nominal)",
            tipe: t.tipe.rawValue,
            subTipe: t.subTipe.rawValue,
            kategoriNama: t.kategori?.nama,
            pocketNama: t.pocket?.nama,
            catatan: t.catatan,
            klasifikasiExpense: t.kategori?.klasifikasi?.rawValue,
            kelompokIncome: t.kategori?.kelompokIncome?.rawValue,
            goalID: t.goalID
        )
    }

    private func mapTransfer(_ t: TransferInternal) -> TransferInternalDTO {
        TransferInternalDTO(
            tanggal: t.tanggal,
            nominal: "\(t.nominal)",
            pocketAsalNama: t.pocketAsal?.nama,
            pocketTujuanNama: t.pocketTujuan?.nama,
            catatan: t.catatan
        )
    }

    private func mapLangganan(_ l: Langganan) -> LanggananDTO {
        LanggananDTO(
            nama: l.nama,
            nominal: "\(l.nominal)",
            tanggalTagih: l.tanggalTagih,
            kategoriNama: l.kategori?.nama,
            catatan: l.catatan,
            logo: l.logo?.base64EncodedString(),
            isAktif: l.isAktif,
            urutan: l.urutan
        )
    }

    private func mapTarget(_ t: Target) -> TargetDTO {
        TargetDTO(
            id: t.id,
            nama: t.nama,
            targetNominal: "\(t.targetNominal)",
            deadline: t.deadline,
            ikon: t.ikon,
            ikonCustom: t.ikonCustom,
            warna: t.warna,
            catatan: t.catatan,
            isSelesai: t.isSelesai,
            jenisTarget: t.jenisTarget.rawValue,
            fotoData: t.fotoData?.base64EncodedString(),
            createdAt: t.createdAt,
            linkedPocketNama: t.linkedPocket?.nama,
            riwayat: t.riwayat.sorted { $0.tanggal < $1.tanggal }.map { r in
                SimpanKeTargetDTO(
                    tanggal: r.tanggal,
                    nominal: "\(r.nominal)",
                    catatan: r.catatan,
                    createdAt: r.createdAt
                )
            }
        )
    }

    private func mapAset(_ a: Aset) -> AsetDTO {
        AsetDTO(
            tipe: a.tipe.rawValue,
            nama: a.nama,
            kode: a.kode,
            lot: a.lot.map { "\($0)" },
            hargaPerLembar: a.hargaPerLembar.map { "\($0)" },
            jenisReksadana: a.jenisReksadana,
            totalInvestasiReksadana: a.totalInvestasiReksadana.map { "\($0)" },
            hargaBeliPerUnit: a.hargaBeliPerUnit.map { "\($0)" },
            navSaatIni: a.navSaatIni.map { "\($0)" },
            jumlahUnitReksadana: a.jumlahUnitReksadana.map { "\($0)" },
            totalInvestasiUSD: a.totalInvestasiUSD.map { "\($0)" },
            hargaBeliPerShareUSD: a.hargaBeliPerShareUSD.map { "\($0)" },
            hargaSaatIniUSD: a.hargaSaatIniUSD.map { "\($0)" },
            kursBeliUSD: a.kursBeliUSD.map { "\($0)" },
            kursSaatIniUSD: a.kursSaatIniUSD.map { "\($0)" },
            mataUangValas: a.mataUangValas?.rawValue,
            jumlahValas: a.jumlahValas.map { "\($0)" },
            kursBeliPerUnit: a.kursBeliPerUnit.map { "\($0)" },
            kursSaatIni: a.kursSaatIni.map { "\($0)" },
            jenisEmas: a.jenisEmas?.rawValue,
            tahunCetak: a.tahunCetak,
            beratGram: a.beratGram.map { "\($0)" },
            hargaBeliPerGram: a.hargaBeliPerGram.map { "\($0)" },
            nominalDeposito: a.nominalDeposito.map { "\($0)" },
            bungaPA: a.bungaPA.map { "\($0)" },
            pphFinal: a.pphFinal.map { "\($0)" },
            tenorBulan: a.tenorBulan,
            tanggalMulaiDeposito: a.tanggalMulaiDeposito,
            autoRollOver: a.autoRollOver,
            nilaiSaatIni: "\(a.nilaiSaatIni)",
            urutan: a.urutan,
            portofolio: a.portofolio,
            logoData: a.logoData?.base64EncodedString(),
            catatSbgPengeluaran: a.catatSbgPengeluaran,
            pocketSumberNama: a.pocketSumber?.nama,
            linkedTargetID: a.linkedTarget?.id
        )
    }
}

// MARK: - Summary

struct RestoreSummary {
    let pocket: Int
    let kategori: Int
    let transaksi: Int
    let transfer: Int
    let aset: Int
    let langganan: Int
    let portofolioConfig: Int
    let target: Int
    let simpanKeTarget: Int
}
