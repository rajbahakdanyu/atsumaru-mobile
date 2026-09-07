import Foundation

public enum ImageURLBuilder {
    private static let baseURL = URL(string: "https://atsu.moe/")!
    private static let allowedHosts = ["atsu.moe", "cdn.atsu.moe"]

    /// Builds a poster/banner URL. Paths come in two shapes:
    /// - `/static/posters/...` or `/static/banners/...` (already rooted)
    /// - `posters/...` or `banners/...` (bare, need the `/static/` prefix)
    public static func poster(_ path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        var path = path
        if path.hasPrefix("/") { path.removeFirst() }
        if path.hasPrefix("posters/") || path.hasPrefix("banners/") {
            path = "static/" + path
        }
        return URL(string: "https://atsu.moe/\(path)")
    }
    public static func page(_ path: String) -> URL? {
        pinnedURL(path)
    }

    /// Builds an avatar URL. Relative paths are rooted at `atsu.moe`; absolute
    /// URLs must use HTTPS and an Atsumaru-controlled host.
    public static func avatar(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return pinnedURL(path)
    }

    private static func pinnedURL(_ path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        let url: URL?
        if let parsed = URL(string: path), parsed.scheme != nil {
            url = parsed
        } else {
            url = URL(string: path, relativeTo: baseURL)?.absoluteURL
        }
        guard let url,
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              allowedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) else {
            return nil
        }
        return url
    }
}