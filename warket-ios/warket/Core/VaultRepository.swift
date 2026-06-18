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
