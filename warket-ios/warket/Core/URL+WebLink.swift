import Foundation

extension URL {
    /// Only http and https open from vault content. Other schemes (`tel:`, `sms:`,
    /// other apps' links) could trigger actions the reader never meant to take.
    var isWebLink: Bool {
        ["http", "https"].contains(scheme?.lowercased() ?? "")
    }
}
