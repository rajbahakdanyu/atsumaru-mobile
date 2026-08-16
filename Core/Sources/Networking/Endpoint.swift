import Foundation

public protocol Endpoint: Sendable {
    var path: String { get }
}