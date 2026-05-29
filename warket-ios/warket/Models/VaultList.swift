import Foundation

/// A named watchlist owned by a vault. Mirrors `VaultList` in
/// `src/lib/types.ts` and the `lists` table columns.
struct VaultList: Codable, Identifiable, Hashable {
    let id: String
    let vaultHash: String
    var name: String
    var tags: [String]
    var position: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case vaultHash = "vault_hash"
        case name
        case tags
        case position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
