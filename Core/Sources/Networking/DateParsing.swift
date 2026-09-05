import Foundation

enum DateParsing {
    static func epochMs(fromISO8601 s: String) -> Int? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return Int(d.timeIntervalSince1970 * 1000) }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return Int(d.timeIntervalSince1970 * 1000) }
        return nil
    }

    /// Decodes an epoch-milliseconds timestamp that may arrive as an `Int`
    /// (milliseconds) or an ISO8601 `String`.
    static func decodeEpochMs<K: CodingKey>(_ c: KeyedDecodingContainer<K>, forKey key: K) -> Int? {
        if let int = try? c.decodeIfPresent(Int.self, forKey: key) { return int }
        if let str = try? c.decodeIfPresent(String.self, forKey: key) { return epochMs(fromISO8601: str) }
        return nil
    }
}

public extension Int {
    var dateFromEpochMs: Date? { Date(timeIntervalSince1970: TimeInterval(self) / 1000) }
}

public extension Date {
    var relativeLabel: String { formatted(.relative(presentation: .named)) }
}
