import Foundation

public enum ImageURLBuilder {
    /// Builds a poster/banner URL. Paths come in two shapes:
    /// - `/static/posters/...` or `/static/banners/...` (already rooted)
    /// - `posters/...` or `banners/...` (bare, need the `/static/` prefix)
    public static func poster(_ path: String) -> URL? {
        var path = path
        if path.hasPrefix("/") { path.removeFirst() }
        if path.hasPrefix("posters/") || path.hasPrefix("banners/") {
            path = "static/" + path
        }
        return URL(string: "https://atsu.moe/\(path)")
    }
    public static func page(_ path: String) -> URL? {
        URL(string: "https://atsu.moe\(path)")
    }

    /// Builds an avatar URL. Absolute `atsu.moe` URLs pass through; any other
    /// absolute URL is rejected; relative paths are rooted at `atsu.moe`.
    public static func avatar(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if let url = URL(string: path) {
            if let host = url.host?.lowercased(), host == "atsu.moe" || host.hasSuffix(".atsu.moe") {
                return url
            }
            return nil
        }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "https://atsu.moe/" + trimmed)
    }
}