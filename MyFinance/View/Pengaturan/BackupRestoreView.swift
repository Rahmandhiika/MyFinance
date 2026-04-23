import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - File type

extension UTType {
    static let myfinanceBackup = UTType(importedAs: "rahmandhika.MyFinance.backup")
}

// MARK: - Document wrapper (export)

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.myfinanceBackup, .json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - View

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument: BackupDocument? = nil

    @State private var showImportConfirm = false
    @State private var pendingImportData: Data? = nil

    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var resultIsError = false

    @State private var isProcessing = false

    var body: some View {
        ZStack {
            Color(hex: "#0D0D0D").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header illustration
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#22C55E").opacity(0.1))
                                .frame(width: 72, height: 72)
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color(hex: "#22C55E"))
                        }
                        Text("Backup & Restore")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Export data ke file .myfinance untuk backup,\nlalu import kapan saja untuk restore.")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    // Scope info card
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("APA YANG DISIMPAN")
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                        scopeRow(icon: "creditcard.fill", label: "Pocket & Saldo", color: "#3B82F6")
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 44)
                        scopeRow(icon: "tag.fill", label: "Kategori Transaksi", color: "#A78BFA")
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 44)
                        scopeRow(icon: "arrow.left.arrow.right", label: "Semua Transaksi & Transfer", color: "#22D3EE")
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 44)
                        scopeRow(icon: "chart.pie.fill", label: "Semua Aset (termasuk target investasi)", color: "#F59E0B")
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 44)
                        scopeRow(icon: "target", label: "Target & Riwayat Tabungan", color: "#22C55E")
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 44)
                        scopeRow(icon: "creditcard.circle.fill", label: "Daftar Bills", color: "#EC4899")
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 44)
                        scopeRow(icon: "photo.fill", label: "Logo, foto & portofolio aset", color: "#F97316")
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    // Export button
                    VStack(spacing: 10) {
                        sectionHeader("EXPORT")
                            .padding(.horizontal, 16)

                        Button {
                            doExport()
                        } label: {
                            HStack(spacing: 10) {
                                if isProcessing {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                Text("Export Data")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#22C55E"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isProcessing)
                        .padding(.horizontal, 16)

                        Text("File akan disimpan/dibagikan via Files, AirDrop, atau apps lainnya.")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    // Import button
                    VStack(spacing: 10) {
                        sectionHeader("IMPORT / RESTORE")
                            .padding(.horizontal, 16)

                        Button {
                            isImporting = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Pilih File Backup")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(Color(hex: "#F59E0B"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#F59E0B").opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "#F59E0B").opacity(0.3), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 16)

                        Text("⚠️ Import akan menggantikan SEMUA data yang ada sekarang — pocket, transaksi, kategori, aset, target, dan bills.")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#F59E0B").opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        // Export sheet
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename()
        ) { result in
            switch result {
            case .success: showSuccess("Data berhasil diekspor!")
            case .failure(let e): showError("Gagal export: \(e.localizedDescription)")
            }
        }
        // Import picker
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json, .myfinanceBackup],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    pendingImportData = data
                    showImportConfirm = true
                } else {
                    showError("Gagal membaca file.")
                }
            case .failure(let e):
                showError("Gagal memilih file: \(e.localizedDescription)")
            }
        }
        // Import confirm alert
        .alert("Yakin Import?", isPresented: $showImportConfirm) {
            Button("Import & Ganti Data", role: .destructive) {
                if let data = pendingImportData { doImport(data: data) }
            }
            Button("Batal", role: .cancel) { pendingImportData = nil }
        } message: {
            Text("Semua data yang ada sekarang (pocket, transaksi, kategori, aset, target, bills) akan digantikan dengan data dari file backup.")
        }
        // Result alert
        .alert(resultIsError ? "Gagal" : "Berhasil", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: - Actions

    private func doExport() {
        isProcessing = true
        Task {
            do {
                let data = try BackupService.shared.export(context: context)
                await MainActor.run {
                    exportDocument = BackupDocument(data: data)
                    isProcessing = false
                    isExporting = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    showError("Gagal export: \(error.localizedDescription)")
                }
            }
        }
    }

    private func doImport(data: Data) {
        isProcessing = true
        Task {
            do {
                let summary = try BackupService.shared.restore(data: data, context: context)
                await MainActor.run {
                    isProcessing = false
                    showSuccess(
                        "Import berhasil!\n" +
                        "• \(summary.pocket) pocket\n" +
                        "• \(summary.kategori) kategori\n" +
                        "• \(summary.transaksi) transaksi\n" +
                        "• \(summary.transfer) transfer\n" +
                        "• \(summary.aset) aset\n" +
                        "• \(summary.target) target (\(summary.simpanKeTarget) riwayat)\n" +
                        "• \(summary.langganan) bills"
                    )
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    showError("Gagal import: \(error.localizedDescription)")
                }
            }
        }
    }

    private func exportFilename() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return "myfinance_backup_\(f.string(from: Date())).json"
    }

    private func showSuccess(_ msg: String) {
        resultMessage = msg
        resultIsError = false
        showResult = true
    }

    private func showError(_ msg: String) {
        resultMessage = msg
        resultIsError = true
        showResult = true
    }

    // MARK: - Sub Views

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.gray)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func scopeRow(icon: String, label: String, color: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: color).opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: color))
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: "#22C55E"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
