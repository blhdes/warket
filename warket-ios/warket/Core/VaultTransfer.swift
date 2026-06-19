import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Versioned JSON interchange format for a vault, byte-compatible with the web
/// app's export (`src/lib/vaultExport.ts`) so files move freely web ↔ iOS.
struct VaultExport: Codable {
    var version: Int
    var app: String
    var exportedAt: String
    var lists: [ExportedList]

    enum CodingKeys: String, CodingKey {
        case version, app, lists
        case exportedAt = "exported_at"
    }

    /// Semantic check mirroring `validateImportData`. Returns an error message,
    /// or `nil` when the payload is valid. (Codable decoding already guards the
    /// overall structure; this adds the friendly per-row messages.)
    static func validate(_ data: VaultExport) -> String? {
        for (i, list) in data.lists.enumerated() {
            if list.name.trimmingCharacters(in: .whitespaces).isEmpty {
                return "List \(i + 1): missing or empty \"name\""
            }
            for (j, asset) in list.assets.enumerated() {
                if asset.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    return "List \"\(list.name)\", asset \(j + 1): missing or empty \"name\""
                }
                if asset.ticker.trimmingCharacters(in: .whitespaces).isEmpty {
                    return "List \"\(list.name)\", asset \"\(asset.name)\": missing or empty \"ticker\""
                }
            }
        }
        return nil
    }
}

struct ExportedList: Codable {
    var name: String
    var tags: [String]
    var assets: [ExportedAsset]

    enum CodingKeys: String, CodingKey { case name, tags, assets }

    init(name: String, tags: [String], assets: [ExportedAsset]) {
        self.name = name
        self.tags = tags
        self.assets = assets
    }

    // Lenient decode (mirrors the web import's `?? []` defaults).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        assets = (try? c.decode([ExportedAsset].self, forKey: .assets)) ?? []
    }
}

struct ExportedAsset: Codable {
    var name: String
    var ticker: String
    var summary: String
    var description: String
    var tags: [String]
    var resources: [Resource]
    /// Omitted from JSON when nil — matches the web's `image_url ? {…} : {}`.
    var imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, ticker, summary, description, tags, resources
        case imageUrl = "image_url"
    }

    init(
        name: String, ticker: String, summary: String, description: String,
        tags: [String], resources: [Resource], imageUrl: String?
    ) {
        self.name = name
        self.ticker = ticker
        self.summary = summary
        self.description = description
        self.tags = tags
        self.resources = resources
        self.imageUrl = imageUrl
    }

    // Lenient decode (mirrors the web import's `?? ''` / `?? []` defaults).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        ticker = (try? c.decode(String.self, forKey: .ticker)) ?? ""
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        resources = (try? c.decode([Resource].self, forKey: .resources)) ?? []
        imageUrl = try? c.decode(String.self, forKey: .imageUrl)
    }
}

/// Minimal `FileDocument` so SwiftUI's `.fileExporter` can write the JSON blob.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
