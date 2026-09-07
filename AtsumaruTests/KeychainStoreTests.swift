import Foundation
import Testing
@testable import Core

@Suite(.serialized)
struct KeychainStoreTests {
    @Test func saveLoadDeleteRoundTrip() throws {
        let store = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
        let key = "test-key-\(UUID().uuidString)"
        defer { try? store.delete(key: key) }

        let payload = Data("hello-atsumaru".utf8)
        #expect(store.load(key: key) == nil)
        try store.save(payload, key: key)
        #expect(store.load(key: key) == payload)
        try store.delete(key: key)
        #expect(store.load(key: key) == nil)
    }

    @Test func saveOverwritesExistingValue() throws {
        let store = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
        let key = "overwrite-\(UUID().uuidString)"
        defer { try? store.delete(key: key) }

        try store.save(Data("first".utf8), key: key)
        try store.save(Data("second".utf8), key: key)
        #expect(store.load(key: key) == Data("second".utf8))
    }

    @Test func deleteIsIdempotentWhenAbsent() throws {
        let store = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
        let key = "absent-\(UUID().uuidString)"
        try store.delete(key: key)
        try store.delete(key: key)
        #expect(store.load(key: key) == nil)
    }
}
