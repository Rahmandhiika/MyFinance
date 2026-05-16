import Foundation
import CommonCrypto

// MARK: - Bibit NAV Response

struct BibitNAVResult {
    let productID: String
    let name: String
    let nav: Double
    let navDate: String
    let type: String
}

// MARK: - Bibit Service

final class BibitService {
    static let shared = BibitService()
    private init() {}

    /// Fetch NAV reksa dana dari Bibit API by product ID (e.g. "RD1657")
    func fetchNAV(productID: String) async throws -> BibitNAVResult {
        guard let url = URL(string: "https://api.bibit.id/products/\(productID)") else {
            throw BibitError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BibitError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        // Parse outer JSON: { "message": "...", "data": "<encrypted hex string>" }
        let outer = try JSONDecoder().decode(BibitOuterResponse.self, from: data)
        let decrypted = try aesDecrypt(outer.data)

        // Parse inner JSON
        guard let innerData = decrypted.data(using: .utf8) else {
            throw BibitError.decryptionFailed
        }
        let product = try JSONDecoder().decode(BibitProduct.self, from: innerData)

        return BibitNAVResult(
            productID: product.symbol,
            name: product.name,
            nav: product.nav?.value ?? 0,
            navDate: product.nav?.date ?? "-",
            type: product.type
        )
    }

    // MARK: - AES Decrypt

    /// Format: first 32 hex chars = IV, last 32 UTF-8 chars = key, middle = ciphertext hex
    private func aesDecrypt(_ hexString: String) throws -> String {
        guard hexString.count > 64 else { throw BibitError.decryptionFailed }

        let ivHex        = String(hexString.prefix(32))
        let secretStr    = String(hexString.suffix(32))
        let ciphertextHex = String(hexString.dropFirst(32).dropLast(32))

        guard let ivData         = Data(hexString: ivHex),
              let ciphertextData = Data(hexString: ciphertextHex),
              let keyData        = secretStr.data(using: .utf8),
              keyData.count == 32 else {
            throw BibitError.decryptionFailed
        }

        let bufferSize = ciphertextData.count + kCCBlockSizeAES128
        var outputBuffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesDecrypted = 0

        let status = keyData.withUnsafeBytes { keyBytes in
            ivData.withUnsafeBytes { ivBytes in
                ciphertextData.withUnsafeBytes { cipherBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, kCCKeySizeAES256,
                        ivBytes.baseAddress,
                        cipherBytes.baseAddress, ciphertextData.count,
                        &outputBuffer, bufferSize,
                        &numBytesDecrypted
                    )
                }
            }
        }

        guard status == kCCSuccess else { throw BibitError.decryptionFailed }
        let decryptedData = Data(outputBuffer.prefix(numBytesDecrypted))

        guard let result = String(data: decryptedData, encoding: .utf8) else {
            throw BibitError.decryptionFailed
        }
        return result
    }
}

// MARK: - Errors

enum BibitError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case decryptionFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "URL tidak valid"
        case .httpError(let c): return "HTTP error \(c)"
        case .decryptionFailed: return "Gagal dekripsi data Bibit"
        case .productNotFound:  return "Produk tidak ditemukan"
        }
    }
}

// MARK: - Decodable Models

private struct BibitOuterResponse: Decodable {
    let message: String
    let data: String
}

private struct BibitProduct: Decodable {
    let symbol: String
    let name: String
    let type: String
    let nav: BibitNAV?

    enum CodingKeys: String, CodingKey {
        case symbol, name, type = "type", nav
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        name   = try container.decode(String.self, forKey: .name)
        type   = try container.decode(String.self, forKey: .type)
        nav    = try container.decodeIfPresent(BibitNAV.self, forKey: .nav)
    }
}

private struct BibitNAV: Decodable {
    let value: Double
    let date: String
}

// MARK: - Data hex helper

private extension Data {
    init?(hexString: String) {
        let len = hexString.count
        guard len % 2 == 0 else { return nil }
        var data = Data(capacity: len / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
