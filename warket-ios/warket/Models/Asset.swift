import Foundation

/// A single tracked asset belonging to a VaultList. Mirrors `Asset` in
/// `src/lib/types.ts` and the `assets` table columns.
struct Asset: Codable, Identifiable, Hashable {
    let id: String
    let listId: String
    var name: String
    var ticker: String
    /// At most `summaryLimit` unicode scalars (enforced in the editor and on import).
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

extension Asset {
    /// The database's `char_length(summary) <= 250` counts unicode scalars, not
    /// the visible characters Swift's `count` gives (an emoji can be several scalars).
    static let summaryLimit = 250

    /// The longest start of `text` that fits the limit, cut only between whole
    /// characters so an emoji is never split in half.
    static func clampSummary(_ text: String) -> String {
        var used = 0
        var end = text.startIndex
        for index in text.indices {
            let size = text[index].unicodeScalars.count
            if used + size > summaryLimit { break }
            used += size
            end = text.index(after: index)
        }
        return String(text[..<end])
    }
}

// In an extension so the memberwise init stays available.
extension Asset {
    /// Only `id` and `list_id` are required. Any other missing or null column falls
    /// back to an empty value, so one odd row never stops the whole list from loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        listId = try c.decode(String.self, forKey: .listId)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        ticker = try c.decodeIfPresent(String.self, forKey: .ticker) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        resources = try c.decodeIfPresent([Resource].self, forKey: .resources) ?? []
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}
