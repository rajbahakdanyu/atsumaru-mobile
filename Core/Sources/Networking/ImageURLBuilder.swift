import Foundation

public enum ImageURLBuilder {
    public static func poster(_ path: String) -> URL? {
        var path = path
        if path.hasPrefix("/") { path.removeFirst() }
        return URL(string: "https://atsu.moe/\(path)")
    }
    public static func page(_ path: String) -> URL? {
        URL(string: "https://atsu.moe\(path)")
    }
}