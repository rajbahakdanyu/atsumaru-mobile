import Foundation

/// Sanitizes user-generated markdown so embedded remote images can only
/// point at Atsumaru-controlled hosts. Images hosted elsewhere are rewritten
/// to plain links (which do NOT trigger an image fetch) so readers are not
/// made to load arbitrary third-party URLs.
public enum MarkdownSanitizer {
    public static let allowedHosts: Set<String> = ["atsu.moe", "cdn.atsu.moe"]

    /// `![alt](url)` → `[alt](url)` unless `url`'s host is allowlisted.
    public static func sanitizeImages(_ markdown: String) -> String {
        let pattern = #"!\[([^\]]*)\]\(([^)\s]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }
        let ns = markdown as NSString
        var result = markdown
        let matches = regex.matches(in: markdown, options: [], range: NSRange(location: 0, length: ns.length))
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            let alt = ns.substring(with: match.range(at: 1))
            let urlString = ns.substring(with: match.range(at: 2))
            let replacement: String
            if let url = URL(string: urlString), let host = url.host, isAllowed(host: host) {
                replacement = "![\(alt)](\(urlString))"
            } else {
                replacement = "[\(alt)](\(urlString))"
            }
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }

    public static func isAllowed(host: String) -> Bool {
        allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
