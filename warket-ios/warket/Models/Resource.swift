import Foundation

/// A user-attached link stored inside an Asset's `resources` JSON array.
/// Mirrors the `Resource` interface in the web app's `src/lib/types.ts`.
struct Resource: Codable, Hashable {
    var title: String
    var url: String
    var favicon: String

    enum CodingKeys: String, CodingKey {
        case title, url, favicon
    }
}

// In an extension so the memberwise init stays available.
extension Resource {
    /// Missing or null fields become "" so one incomplete link never breaks a whole list.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        favicon = try c.decodeIfPresent(String.self, forKey: .favicon) ?? ""
    }
}
