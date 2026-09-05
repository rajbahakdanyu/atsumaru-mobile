import Foundation

enum TolerantDecoding {
    /// Tolerant list decode: prefers `{"<key>":[…]}` then a bare `[…]`.
    static func array<T: Decodable>(_ type: T.Type, from data: Data, key: String) throws -> [T] {
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let dict = obj as? [String: Any],
           let arr = dict[key] as? [[String: Any]],
           let reencoded = try? JSONSerialization.data(withJSONObject: arr),
           let items = try? JSONDecoder().decode([T].self, from: reencoded) {
            return items
        }
        if let items = try? JSONDecoder().decode([T].self, from: data) { return items }
        throw ApiError.decoding
    }
}
