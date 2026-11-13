import Foundation
import os

extension Logger {
    static let app = Logger(subsystem: "com.blhdes.warket", category: "app")
}

extension Error {
    /// A short sentence that is safe to show in a toast or an error screen.
    /// The server's messages are already written for people. Anything unexpected
    /// gets a plain sentence, and the real error goes to the log.
    var userMessage: String {
        if let apiError = self as? APIError { return apiError.message }
        if let urlError = self as? URLError,
           [.notConnectedToInternet, .timedOut, .networkConnectionLost].contains(urlError.code) {
            return "No connection. Check your internet and try again."
        }
        Logger.app.error("Unexpected error shown to the user as a generic message: \(String(describing: self))")
        return "Something went wrong. Please try again."
    }
}
