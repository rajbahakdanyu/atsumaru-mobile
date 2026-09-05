import Foundation

/// Sanitizes user-generated markdown so embedded remote images can only
/// point at Atsumaru-controlled hosts. Images hosted elsewhere are rewritten
/// to plain links (which do NOT trigger an image fetch) so readers are not
/// made to load arbitrary third-party URLs.
public enum MarkdownSanitizer {
    public static let allowedHosts: Set<String> = ["atsu.moe", "cdn.atsu.moe"]

    private static let inlineImage = #"!\[([^\]]*)\]\(\s*([^)\s]+)(?:\s+"[^"]*"|\s+'[^']*'|\s+\([^)]*\))?\s*\)"#
    private static let referenceImage = #"!\[([^\]]*)\]\[([^\]]*)\]"#

    /// `![alt](url)` → `[alt](url)` (and reference-style/nested forms) unless
    /// the image URL's host is allowlisted. Runs to a fixpoint so nested image
    /// syntax can't smuggle a hostile host past a single pass.
    public static func sanitizeImages(_ markdown: String) -> String {
        var result = markdown
        for _ in 0..<8 {
            let next = pass(result)
            if next == result { return result }
            result = next
        }
        return result
    }

    private static func pass(_ markdown: String) -> String {
        let ns = markdown as NSString
        let range = NSRange(location: 0, length: ns.length)

        let inline = try? NSRegularExpression(pattern: inlineImage)
        let reference = try? NSRegularExpression(pattern: referenceImage)

        var result = markdown
        // Demote inline images with non-allowlisted (or malformed) URLs.
        if let inline {
            for match in inline.matches(in: markdown, options: [], range: range).reversed() {
                guard match.numberOfRanges >= 3 else { continue }
                let alt = ns.substring(with: match.range(at: 1))
                let urlString = ns.substring(with: match.range(at: 2))
                let replacement = allows(urlString)
                    ? "![\(alt)](\(urlString))"
                    : "[\(alt)](\(urlString))"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        // Demote reference-style images (the reference is opaque to us, so we
        // can't introspect its host — demote all of them to links).
        if let reference {
            let nsResult = result as NSString
            let resultRange = NSRange(location: 0, length: nsResult.length)
            for match in reference.matches(in: result, options: [], range: resultRange).reversed() {
                guard match.numberOfRanges >= 3 else { continue }
                let alt = nsResult.substring(with: match.range(at: 1))
                let ref = nsResult.substring(with: match.range(at: 2))
                result = (result as NSString).replacingCharacters(
                    in: match.range,
                    with: "[\(alt)][\(ref)]"
                )
            }
        }
        return result
    }

    private static func allows(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host?.lowercased() else { return false }
        return isAllowed(host: host)
    }

    public static func isAllowed(host: String) -> Bool {
        let lower = host.lowercased()
        return allowedHosts.contains { lower == $0 || lower.hasSuffix("." + $0) }
    }
}
