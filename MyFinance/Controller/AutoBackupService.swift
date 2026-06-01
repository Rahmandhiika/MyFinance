import Foundation
import SwiftData

/// Menyimpan backup JSON ke folder Documents/MyFinanceBackups/ otomatis.
///
/// Folder Documents termasuk dalam iPhone backup ke iCloud secara otomatis
/// (jika user aktifkan iCloud Backup di Pengaturan → iCloud → Backup iPhone).
/// User juga bisa akses file ini langsung dari app Files → iPhone → MyFinance.
///
/// Strategi rotasi: simpan max 7 file, hapus yang paling lama.
final class AutoBackupService {
    static let shared = AutoBackupService()

    private let maxBackupFiles = 7
    private let backupInterval: TimeInterval = 24 * 60 * 60  // 1 hari
    private let udLastBackupKey = "autoBackupLastDate"

    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f
    }()

    private var backupDirectory: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("MyFinanceBackups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Public API

    /// Tanggal backup otomatis terakhir — nil jika belum pernah.
    var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: udLastBackupKey) as? Date
    }

    /// Backup yang tersimpan, diurutkan dari paling baru.
    var savedBackups: [URL] {
        guard let dir = backupDirectory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles)
        else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
    }

    /// Jalankan auto-backup jika sudah lebih dari 24 jam sejak backup terakhir.
    /// Aman dipanggil dari background Task di app init.
    func autoBackupIfNeeded(context: ModelContext) async {
        if let last = lastBackupDate,
           Date().timeIntervalSince(last) < backupInterval {
            return  // masih fresh
        }
        await performBackup(context: context)
    }

    /// Paksa backup sekarang (dipanggil dari tombol manual).
    @discardableResult
    func performBackup(context: ModelContext) async -> URL? {
        do {
            let data = try BackupService.shared.export(context: context)
            guard let dir = backupDirectory else { return nil }

            let filename = "myfinance_\(Self.filenameFormatter.string(from: Date())).json"
            let fileURL  = dir.appendingPathComponent(filename)
            try data.write(to: fileURL, options: .atomic)

            await MainActor.run {
                UserDefaults.standard.set(Date(), forKey: udLastBackupKey)
            }

            pruneOldBackups()
            return fileURL
        } catch {
            print("⚠️ AutoBackup gagal: \(error)")
            return nil
        }
    }

    // MARK: - Private

    /// Hapus backup paling lama jika sudah lebih dari maxBackupFiles.
    private func pruneOldBackups() {
        let all = savedBackups
        guard all.count > maxBackupFiles else { return }
        let toDelete = all.dropFirst(maxBackupFiles)
        for url in toDelete {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - URL helper

private extension URL {
    var creationDate: Date? {
        (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }
}
