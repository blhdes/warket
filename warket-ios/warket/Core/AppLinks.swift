import Foundation

/// Public web pages the app opens. These addresses ship inside the app, so
/// changing them needs an app update (plan decision D9).
enum AppLinks {
    static let privacyPolicy = URL(string: "https://asset-cafe.vercel.app/privacy")!
    static let support = URL(string: "https://asset-cafe.vercel.app/support")!
}
