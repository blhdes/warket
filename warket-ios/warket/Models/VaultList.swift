import Foundation

/// A named watchlist owned by a vault. Mirrors `VaultList` in
/// `src/lib/types.ts` and the server's `List` shape (`server/API.md`).
struct VaultList: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var tags: [String]
    var position: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tags
        case position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// In an extension so the memberwise init stays available.
extension VaultList {
    /// Only `id` is required. Missing or null fields fall back to empty values
    /// so one odd list never stops the whole vault from loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}
