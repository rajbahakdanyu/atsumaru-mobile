import Foundation

extension KeyedDecodingContainer {
    /// Decodes `[T]` for `key`, SKIPPING elements that fail to decode.
    /// Missing key or null → `[]`.
    func tolerantArray<T: Decodable>(_ type: T.Type, forKey key: K) -> [T] {
        var result: [T] = []
        guard var unkeyed = try? self.nestedUnkeyedContainer(forKey: key) else { return [] }
        let count = unkeyed.count ?? 0
        for _ in 0..<count {
            if let item = try? unkeyed.decode(T.self) {
                result.append(item)
            } else if let superDec = try? unkeyed.superDecoder() {
                _ = try? T(from: superDec) // consumes the bad element
            }
        }
        return result
    }
}

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
