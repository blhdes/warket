import Foundation
import Supabase

/// A list paired with its asset count, for the lists grid. Mirrors the web app's
/// `ListWithCount` (VaultList + asset_count) in `src/features/lists/ListsView.tsx`.
struct ListWithAssetCount: Identifiable, Hashable {
    let list: VaultList
    let assetCount: Int
    var id: String { list.id }
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

/// All Supabase reads/writes for a single vault. Mirrors `src/lib/queries.ts`,
/// `src/lib/position.ts`, and the inline calls in the web app's feature views.
final class VaultRepository {
    let vaultHash: String
    private let client: SupabaseClient

    init(vaultHash: String) {
        self.vaultHash = vaultHash
        self.client = VaultClient.make(vaultHash: vaultHash)
    }

    // MARK: - Lists

    /// `lists` + asset counts, ordered by position. Maps the `assets(count)` join.
    func fetchLists() async throws -> [ListWithAssetCount] {
        let rows: [ListCountRow] = try await client
            .from("lists")
            .select("*, assets(count)")
            .eq("vault_hash", value: vaultHash)
            .order("position", ascending: true)
            .execute()
            .value
        return rows.map(\.asListWithCount)
    }

    /// Lightweight name+ticker index for list-level search (M4).
    func fetchAssetIndex(listIds: [String]) async throws -> [AssetSearchRow] {
        guard !listIds.isEmpty else { return [] }
        return try await client
            .from("assets")
            .select("list_id, name, ticker")
            .in("list_id", values: listIds)
            .execute()
            .value
    }

    func createList(name: String, tags: [String], position: Int) async throws {
        try await client
            .from("lists")
            .insert(NewList(vault_hash: vaultHash, name: name, tags: tags, position: position))
            .execute()
    }

    func updateList(id: String, name: String, tags: [String]) async throws {
        try await client
            .from("lists")
            .update(ListUpdate(name: name, tags: tags))
            .eq("id", value: id)
            .execute()
    }

    /// Deletes the list; assets cascade-delete via the FK.
    func deleteList(id: String) async throws {
        try await client.from("lists").delete().eq("id", value: id).execute()
    }

    // MARK: - Assets

    func fetchAssets(listId: String) async throws -> [Asset] {
        try await client
            .from("assets")
            .select("*")
            .eq("list_id", value: listId)
            .order("position", ascending: true)
            .execute()
            .value
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
        imageUrl: String?,
        position: Int
    ) async throws -> Asset {
        try await client
            .from("assets")
            .insert(NewAsset(
                list_id: listId, name: name, ticker: ticker, summary: summary,
                description: description, tags: tags, resources: resources,
                image_url: imageUrl, position: position
            ))
            .select()
            .single()
            .execute()
            .value
    }

    /// Updates only the non-nil fields (optional properties are omitted when nil).
    func updateAsset(id: String, fields: AssetUpdate) async throws {
        try await client
            .from("assets")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    func deleteAsset(id: String) async throws {
        try await client.from("assets").delete().eq("id", value: id).execute()
    }

    // MARK: - Reorder (mirrors src/lib/position.ts: parallel position updates)

    func updatePositions(table: String, changes: [PositionChange]) async throws {
        let client = self.client
        try await withThrowingTaskGroup(of: Void.self) { group in
            for change in changes {
                group.addTask {
                    try await client
                        .from(table)
                        .update(PositionUpdate(position: change.position))
                        .eq("id", value: change.id)
                        .execute()
                }
            }
            try await group.waitForAll()
        }
    }

    // MARK: - Export / Import (mirrors src/lib/vaultExport.ts)

    /// Build the JSON export payload. `listIds == nil` exports the whole vault.
    func exportVault(listIds: [String]? = nil) async throws -> VaultExport {
        let all = try await fetchLists()
        let selected: [ListWithAssetCount]
        if let listIds, !listIds.isEmpty {
            let wanted = Set(listIds)
            selected = all.filter { wanted.contains($0.list.id) }
        } else {
            selected = all
        }

        var exportedLists: [ExportedList] = []
        for item in selected {
            let assets = try await fetchAssets(listId: item.list.id)
            let exportedAssets = assets.map { a in
                ExportedAsset(
                    name: a.name, ticker: a.ticker, summary: a.summary,
                    description: a.description, tags: a.tags, resources: a.resources,
                    imageUrl: (a.imageUrl?.isEmpty == false) ? a.imageUrl : nil
                )
            }
            exportedLists.append(ExportedList(name: item.list.name, tags: item.list.tags, assets: exportedAssets))
        }

        return VaultExport(
            version: 1,
            app: "warket",
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            lists: exportedLists
        )
    }

    /// Import a payload, merging by lowercased list name: assets append after the
    /// list's current max position; unknown lists are created after the last one.
    @discardableResult
    func importVault(_ data: VaultExport) async throws -> (lists: Int, assets: Int) {
        let existing = try await fetchLists()
        var byName: [String: String] = [:]
        var nextListPosition = 0
        for item in existing {
            byName[item.list.name.lowercased()] = item.list.id
            if item.list.position >= nextListPosition { nextListPosition = item.list.position + 1 }
        }

        var listsImported = 0
        var assetsImported = 0

        for list in data.lists {
            let listId: String
            if let matchId = byName[list.name.lowercased()] {
                listId = matchId
            } else {
                listId = try await createListReturningId(name: list.name, tags: list.tags, position: nextListPosition)
                nextListPosition += 1
                byName[list.name.lowercased()] = listId
                listsImported += 1
            }

            guard !list.assets.isEmpty else { continue }
            let base = (try await maxAssetPosition(listId: listId) ?? -1) + 1
            let rows = list.assets.enumerated().map { offset, asset in
                NewAsset(
                    list_id: listId, name: asset.name, ticker: asset.ticker,
                    summary: asset.summary, description: asset.description,
                    tags: asset.tags, resources: asset.resources,
                    image_url: asset.imageUrl, position: base + offset
                )
            }
            try await addAssets(rows)
            assetsImported += rows.count
        }

        return (listsImported, assetsImported)
    }

    /// Highest `position` among a list's assets — a one-row read, so import can
    /// append without pulling every asset's full row (mirrors the web).
    private func maxAssetPosition(listId: String) async throws -> Int? {
        let rows: [PositionRow] = try await client
            .from("assets")
            .select("position")
            .eq("list_id", value: listId)
            .order("position", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first?.position
    }

    /// Insert many assets in one request (mirrors the web's per-list batch).
    private func addAssets(_ rows: [NewAsset]) async throws {
        guard !rows.isEmpty else { return }
        try await client.from("assets").insert(rows).execute()
    }

    private func createListReturningId(name: String, tags: [String], position: Int) async throws -> String {
        let row: CreatedListID = try await client
            .from("lists")
            .insert(NewList(vault_hash: vaultHash, name: name, tags: tags, position: position))
            .select("id")
            .single()
            .execute()
            .value
        return row.id
    }

    // MARK: - Sharing (mirrors VaultPage.handleShare)

    /// Create or refresh this vault's read-only share key and return it. The key
    /// is derived one-way from the vault hash, so it can't be reversed.
    @discardableResult
    func upsertShare() async throws -> String {
        let shareHash = SeedPhrase.deriveShareHash(vaultHash)
        try await client
            .from("vault_shares")
            .upsert(ShareUpsert(vault_hash: vaultHash, share_hash: shareHash), onConflict: "vault_hash")
            .execute()
        return shareHash
    }
}

struct PositionChange: Sendable {
    let id: String
    let position: Int
}

/// Partial asset update — nil fields are omitted from the JSON, so only the
/// provided columns change (mirrors the web app's targeted `.update({...})`).
struct AssetUpdate: Encodable {
    var name: String?
    var ticker: String?
    var summary: String?
    var description: String?
    var tags: [String]?
    var resources: [Resource]?
    var image_url: String?
}

// MARK: - Private DTOs

/// Decodes the `select('*, assets(count)')` response shape.
private struct ListCountRow: Decodable {
    let id: String
    let vault_hash: String
    let name: String
    let tags: [String]
    let position: Int
    let created_at: String
    let updated_at: String
    let assets: [CountRow]?

    struct CountRow: Decodable { let count: Int }

    var asListWithCount: ListWithAssetCount {
        ListWithAssetCount(
            list: VaultList(
                id: id, vaultHash: vault_hash, name: name, tags: tags,
                position: position, createdAt: created_at, updatedAt: updated_at
            ),
            assetCount: assets?.first?.count ?? 0
        )
    }
}

private struct NewList: Encodable {
    let vault_hash: String
    let name: String
    let tags: [String]
    let position: Int
}

private struct ListUpdate: Encodable {
    let name: String
    let tags: [String]
}

private struct NewAsset: Encodable {
    let list_id: String
    let name: String
    let ticker: String
    let summary: String
    let description: String
    let tags: [String]
    let resources: [Resource]
    let image_url: String?
    let position: Int
}

private struct PositionUpdate: Encodable {
    let position: Int
}

private struct CreatedListID: Decodable {
    let id: String
}

private struct PositionRow: Decodable {
    let position: Int
}

private struct ShareUpsert: Encodable {
    let vault_hash: String
    let share_hash: String
}
