import Foundation
import os

/// How the app reaches a vault: as its owner, or through a read-only share key.
enum VaultAccess: Hashable {
    case owner(vaultHash: String)
    case shared(shareKey: String)

    var isReadOnly: Bool {
        if case .shared = self { return true }
        return false
    }

    /// Vault hashes and share keys are both 64 lowercase hex characters. The server refuses anything else.
    static func isValidKey(_ key: String) -> Bool {
        key.wholeMatch(of: #/[0-9a-f]{64}/#) != nil
    }

    /// The `Authorization` header. It carries a password, so it is never logged.
    fileprivate var authorization: String {
        switch self {
        case .owner(let vaultHash): "Bearer \(vaultHash)"
        case .shared(let shareKey): "Share \(shareKey)"
        }
    }
}

/// An error answer from the server, or a failure to reach it. `message` is a plain
/// sentence that is safe to show, and `localizedDescription` returns it.
struct APIError: LocalizedError {
    let status: Int
    let code: String
    let message: String

    var errorDescription: String? { message }
}

/// The server address from Info.plist (`API_BASE_URL`). It ships inside the app.
enum AppConfig {
    static let apiBaseURL: URL = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: raw), url.host() != nil
        else {
            fatalError("API_BASE_URL missing or invalid in Info.plist")
        }
        return url
    }()
}

extension Logger {
    static let api = Logger(subsystem: "com.blhdes.warket", category: "api")
}

/// A small wrapper around `URLSession` for the warket server (`server/API.md`).
/// Every call sends the vault's `Authorization` header and turns error answers into `APIError`.
struct APIClient {
    let baseURL: URL
    let access: VaultAccess

    /// No disk cache and no cookies: answers depend on the `Authorization` header.
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    init(baseURL: URL = AppConfig.apiBaseURL, access: VaultAccess) {
        self.baseURL = baseURL
        self.access = access
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await send("GET", path)
    }

    /// For calls whose answer has a JSON body.
    func send<T: Decodable>(_ method: String, _ path: String, body: (any Encodable)? = nil) async throws -> T {
        let data = try await perform(method, path, body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Logger.api.error("Could not read the answer to \(method) \(path): \(error)")
            throw APIError(status: 200, code: "invalid_response", message: "The server sent an answer the app could not read.")
        }
    }

    /// For calls the server answers with 204 No Content (deletes and reorders).
    func sendNoContent(_ method: String, _ path: String, body: (any Encodable)? = nil) async throws {
        _ = try await perform(method, path, body: body)
    }

    private func perform(_ method: String, _ path: String, body: (any Encodable)?) async throws -> Data {
        guard let url = URL(string: baseURL.absoluteString.trimmingSuffix("/") + path) else {
            throw APIError(status: 0, code: "invalid_url", message: "The app built an invalid server address.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(access.authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.urlSession.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            // A newer request replaced this one (for example a second drag). Callers check for this.
            throw CancellationError()
        } catch {
            Logger.api.error("Network error on \(method) \(path): \(error.localizedDescription)")
            throw APIError(status: 0, code: "network", message: "Could not reach the server. Check your connection and try again.")
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError(status: 0, code: "invalid_response", message: "The server sent an answer the app could not read.")
        }
        if (200..<300).contains(http.statusCode) { return data }
        throw serverError(status: http.statusCode, data: data, method: method, path: path)
    }

    /// Reads `{ "error": { "code", "message" } }` from a failed answer.
    private func serverError(status: Int, data: Data, method: String, path: String) -> APIError {
        do {
            let envelope = try JSONDecoder().decode(ErrorEnvelope.self, from: data)
            return APIError(status: status, code: envelope.error.code, message: envelope.error.message)
        } catch {
            Logger.api.error("Error answer \(status) to \(method) \(path) has no readable message: \(error)")
            return APIError(status: status, code: "unknown", message: "Something went wrong. Please try again.")
        }
    }

    private struct ErrorEnvelope: Decodable {
        struct Body: Decodable {
            let code: String
            let message: String
        }
        let error: Body
    }
}

private extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
