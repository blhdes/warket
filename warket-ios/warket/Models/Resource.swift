import Foundation

/// A user-attached link stored inside an Asset's `resources` JSON array.
/// Mirrors the `Resource` interface in the web app's `src/lib/types.ts`.
struct Resource: Codable, Hashable {
    var title: String
    var url: String
    var favicon: String
}
