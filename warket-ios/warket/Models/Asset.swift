import Foundation

/// A single tracked asset belonging to a VaultList. Mirrors `Asset` in
/// `src/lib/types.ts` and the `assets` table columns.
struct Asset: Codable, Identifiable, Hashable {
    let id: String
    let listId: String
    var name: String
    var ticker: String
    /// Max 250 characters (enforced in the UI).
    var summary: String
    /// Markdown string.
    var description: String
    var tags: [String]
    var resources: [Resource]
    /// Optional URL to a custom logo/image for the asset.
    var imageUrl: String?
    var position: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case name
        case ticker
        case summary
        case description
        case tags
        case resources
        case imageUrl = "image_url"
        case position
        case createdAt = "created_at"
    }
}
