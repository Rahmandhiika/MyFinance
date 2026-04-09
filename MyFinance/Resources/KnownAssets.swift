import Foundation

struct KnownAsset {
    let ticker: String
    let name: String
    let subSector: String
    let exchange: String
    let assetType: AssetType
}

let knownIDXStocks: [KnownAsset] = [
    // Bank
    KnownAsset(ticker: "BBNI.JK", name: "Bank Negara Indonesia", subSector: "Perbankan", exchange: "IDX", assetType: .stock),
    KnownAsset(ticker: "BBRI.JK", name: "Bank Rakyat Indonesia", subSector: "Perbankan", exchange: "IDX", assetType: .stock),
    KnownAsset(ticker: "BMRI.JK", name: "Bank Mandiri", subSector: "Perbankan", exchange: "IDX", assetType: .stock),
    // Mining & Energy
    KnownAsset(ticker: "ADRO.JK", name: "Adaro Energy Indonesia", subSector: "Energi", exchange: "IDX", assetType: .stock),
    KnownAsset(ticker: "PTBA.JK", name: "Bukit Asam", subSector: "Energi", exchange: "IDX", assetType: .stock),
    KnownAsset(ticker: "ITMG.JK", name: "Indo Tambangraya Megah", subSector: "Energi", exchange: "IDX", assetType: .stock),
    // Oil & Gas
    KnownAsset(ticker: "TOTL.JK", name: "Total Bangun Persada", subSector: "Infrastruktur", exchange: "IDX", assetType: .stock),
]

let knownUSStocks: [KnownAsset] = [
    KnownAsset(ticker: "NVDA", name: "NVIDIA Corporation", subSector: "Technology", exchange: "NASDAQ", assetType: .stock),
]

let knownETFs: [KnownAsset] = [
    KnownAsset(ticker: "SPY", name: "S&P 500 ETF", subSector: "Index Fund", exchange: "NYSE", assetType: .etf),
]

let knownCommodities: [KnownAsset] = [
    KnownAsset(ticker: "GC=F", name: "Gold Futures", subSector: "Precious Metal", exchange: "COMEX", assetType: .commodity),
    KnownAsset(ticker: "SLV", name: "iShares Silver Trust", subSector: "Precious Metal", exchange: "NYSE", assetType: .commodity),
]

let allKnownAssets = knownIDXStocks + knownUSStocks + knownETFs + knownCommodities

func knownAsset(for ticker: String) -> KnownAsset? {
    allKnownAssets.first { $0.ticker.uppercased() == ticker.uppercased() }
}
