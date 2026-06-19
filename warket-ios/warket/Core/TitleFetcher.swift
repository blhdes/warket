import Foundation

/// Fetches a web page's title for the "Add resource" flow.
///
/// Native has no CORS restriction, so a direct `URLSession` fetch is the primary
/// path — the web app's `src/lib/fetchTitle.ts` only needs its six proxy
/// strategies to dodge browser CORS. `api.microlink.io` is kept as a fallback
/// for JS-rendered pages that ship no title in their static HTML. The HTML
/// parsing mirrors that file's `extractTitle`/`extractMeta`.
enum TitleFetcher {
    private static let timeout: TimeInterval = 8

    /// Returns a cleaned title, or `nil` if every strategy fails.
    static func fetch(_ rawURL: String) async -> String? {
        guard let url = normalized(rawURL) else { return nil }
        if let direct = await tryDirect(url) { return direct }
        return await tryMicrolink(url)
    }

    // MARK: - Strategies

    private static func tryDirect(_ url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Mozilla/5.0 (compatible; warket/1.0)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
            let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        return extractTitle(from: html)
    }

    private static func tryMicrolink(_ url: URL) async -> String? {
        guard
            let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let endpoint = URL(string: "https://api.microlink.io?url=\(encoded)")
        else { return nil }
        let request = URLRequest(url: endpoint, timeoutInterval: timeout)
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["status"] as? String == "success",
            let payload = json["data"] as? [String: Any],
            let title = (payload["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !title.isEmpty
        else { return nil }
        return clean(title)
    }

    // MARK: - Parsing (mirrors fetchTitle.ts)

    private static func extractTitle(from html: String) -> String? {
        if let og = meta(html, attr: "property", value: "og:title") { return og }
        if let tw = meta(html, attr: "name", value: "twitter:title") { return tw }
        if let mt = meta(html, attr: "name", value: "title") { return mt }
        if let raw = firstGroup(in: html, pattern: "<title[^>]*>([\\s\\S]*?)</title>") {
            let cleaned = clean(decodeEntities(raw))
            if !cleaned.isEmpty { return cleaned }
        }
        return nil
    }

    /// Extract a meta tag's content by property/name, handling either attribute order.
    private static func meta(_ html: String, attr: String, value: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: value)
        let attrBeforeContent = "<meta\\s+[^>]*?\(attr)\\s*=\\s*[\"']\(escaped)[\"'][^>]*?content\\s*=\\s*[\"']([^\"']+)[\"']"
        if let m = firstGroup(in: html, pattern: attrBeforeContent) { return clean(decodeEntities(m)) }
        let contentBeforeAttr = "<meta\\s+[^>]*?content\\s*=\\s*[\"']([^\"']+)[\"'][^>]*?\(attr)\\s*=\\s*[\"']\(escaped)[\"']"
        if let m = firstGroup(in: html, pattern: contentBeforeAttr) { return clean(decodeEntities(m)) }
        return nil
    }

    private static func firstGroup(in text: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = re.firstMatch(in: text, range: range),
            match.numberOfRanges > 1,
            let r = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private static func normalized(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "https://" + s }
        return URL(string: s)
    }

    private static func clean(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decode common HTML entities (named + numeric) — lighter than NSAttributedString.
    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        let named = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&#x27;": "'", "&apos;": "'", "&nbsp;": " ",
            "&mdash;": "—", "&ndash;": "–", "&hellip;": "…",
        ]
        for (entity, char) in named { result = result.replacingOccurrences(of: entity, with: char) }
        result = decodeNumeric(result, pattern: "&#([0-9]+);", radix: 10)
        result = decodeNumeric(result, pattern: "&#[xX]([0-9a-fA-F]+);", radix: 16)
        return result
    }

    private static func decodeNumeric(_ text: String, pattern: String, radix: Int) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        let mutable = NSMutableString(string: text)
        let nsText = text as NSString
        for match in re.matches(in: text, range: NSRange(location: 0, length: mutable.length)).reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let code = nsText.substring(with: match.range(at: 1))
            guard let value = UInt32(code, radix: radix), let scalar = Unicode.Scalar(value) else { continue }
            mutable.replaceCharacters(in: match.range(at: 0), with: String(scalar))
        }
        return mutable as String
    }
}
