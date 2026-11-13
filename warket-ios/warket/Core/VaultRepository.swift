import Foundation

/// A list paired with its asset count, for the lists grid. Mirrors `ListWithCount`
/// in the web app's `src/lib/types.ts` (a `VaultList` plus `asset_count`).
struct ListWithAssetCount: Identifiable, Hashable {
    let list: VaultList
    let assetCount: Int
    var id: String { list.id }
}

extension ListWithAssetCount: Decodable {
    private enum CodingKeys: String, CodingKey {
        case assetCount = "asset_count"
    }

    init(from decoder: Decoder) throws {
        list = try VaultList(from: decoder)
        assetCount = try decoder.container(keyedBy: CodingKeys.self)
            .decodeIfPresent(Int.self, forKey: .assetCount) ?? 0
    }
}

/// Lightweight row for the search index (list name + ticker lookup).
struct AssetSearchRow: Decodable, Hashable {
    let listId: String
    let name: String
    let ticker: String

    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case name, ticker
    }
}

/// Every server call for one vault. Mirrors `createVaultApi` in the web app's
/// `src/lib/api.ts`. The server places new items last, tidies input, and refuses
/// every write made with a share key.
final class VaultRepository {
    let access: VaultAccess
    private let api: APIClient

    init(access: VaultAccess) {
        self.access = access
        self.api = APIClient(access: access)
    }

    /// Succeeds when the server accepts this key. An unknown share key fails with
    /// the server's "Invalid or expired share key." message.
    func checkAccess() async throws {
        let _: SessionAnswer = try await api.get("/v1/session")
    }

    // MARK: - Lists

    /// Lists with asset counts, ordered by position.
    func fetchLists() async throws -> [ListWithAssetCount] {
        try await api.get("/v1/lists")
    }

    /// Name and ticker of every asset in the vault, for list-level search.
    func fetchAssetIndex() async throws -> [AssetSearchRow] {
        try await api.get("/v1/assets/index")
    }

    @discardableResult
    func createList(name: String, tags: [String]) async throws -> VaultList {
        try await api.send("POST", "/v1/lists", body: ListInput(name: name, tags: tags))
    }

    @discardableResult
    func updateList(id: String, name: String, tags: [String]) async throws -> VaultList {
        try await api.send("PATCH", "/v1/lists/\(id)", body: ListInput(name: name, tags: tags))
    }

    /// Deletes the list and its assets.
    func deleteList(id: String) async throws {
        try await api.sendNoContent("DELETE", "/v1/lists/\(id)")
    }

    /// `ids` must be every list of the vault, in the new order. Saved all at once or not at all.
    func reorderLists(ids: [String]) async throws {
        try await api.sendNoContent("PUT", "/v1/lists/order", body: OrderInput(ids: ids))
    }

    // MARK: - Assets

    func fetchAssets(listId: String) async throws -> [Asset] {
        try await api.get("/v1/lists/\(listId)/assets")
    }

    @discardableResult
    func addAsset(
        listId: String,
        name: String,
        ticker: String,
        summary: String,
        description: String,
        tags: [String],
        resources: [Resource],
        imageUrl: String?
    ) async throws -> Asset {
        try await api.send("POST", "/v1/lists/\(listId)/assets", body: AssetInput(
            name: name, ticker: ticker, summary: summary, description: description,
            tags: tags, resources: resources, image_url: imageUrl
        ))
    }

    /// Changes only the non-nil fields and returns the saved asset, as tidied by the server.
    @discardableResult
    func updateAsset(id: String, fields: AssetUpdate) async throws -> Asset {
        try await api.send("PATCH", "/v1/assets/\(id)", body: fields)
    }

    func deleteAsset(id: String) async throws {
        try await api.sendNoContent("DELETE", "/v1/assets/\(id)")
    }

    /// `ids` must be every asset of the list, in the new order. Saved all at once or not at all.
    func reorderAssets(listId: String, ids: [String]) async throws {
        try await api.sendNoContent("PUT", "/v1/lists/\(listId)/assets/order", body: OrderInput(ids: ids))
    }

    // MARK: - Export / Import

    /// The export file content. `listIds == nil` exports the whole vault.
    func exportVault(listIds: [String]? = nil) async throws -> VaultExport {
        guard let listIds, !listIds.isEmpty else { return try await api.get("/v1/export") }
        return try await api.get("/v1/export?lists=\(listIds.joined(separator: ","))")
    }

    /// Lists merge by name without regard to case. All or nothing: a failure writes nothing.
    @discardableResult
    func importVault(_ data: VaultExport) async throws -> (lists: Int, assets: Int) {
        let answer: ImportAnswer = try await api.send("POST", "/v1/import", body: data)
        return (answer.listsImported, answer.assetsImported)
    }

    // MARK: - Sharing and deletion

    /// Creates the vault's read-only share key, or returns the existing one.
    func upsertShare() async throws -> String {
        let answer: ShareAnswer = try await api.send("PUT", "/v1/share")
        return answer.shareKey
    }

    /// Erases every list, asset and the share key of this vault on the server.
    func deleteVault() async throws {
        try await api.sendNoContent("DELETE", "/v1/vault")
    }
}

/// Partial asset update. Nil fields are left out of the JSON, so only the provided
/// fields change. To clear a field send `""`, never nil.
struct AssetUpdate: Encodable {
    var name: String?
    var ticker: String?
    var summary: String?
    var description: String?
    var tags: [String]?
    var resources: [Resource]?
    var image_url: String?
}

// MARK: - Request and answer bodies

private struct ListInput: Encodable {
    let name: String
    let tags: [String]
}

private struct AssetInput: Encodable {
    let name: String
    let ticker: String
    let summary: String
    let description: String
    let tags: [String]
    let resources: [Resource]
    let image_url: String?
}

private struct OrderInput: Encodable {
    let ids: [String]
}

private struct SessionAnswer: Decodable {
    let mode: String
}

private struct ImportAnswer: Decodable {
    let listsImported: Int
    let assetsImported: Int

    enum CodingKeys: String, CodingKey {
        case listsImported = "lists_imported"
        case assetsImported = "assets_imported"
    }
}

private struct ShareAnswer: Decodable {
    let shareKey: String

    enum CodingKeys: String, CodingKey {
        case shareKey = "share_key"
    }
}
