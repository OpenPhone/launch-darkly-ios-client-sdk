import Foundation
import OSLog
// sourcery: autoMockable
public protocol KeyedValueCaching {
    func set(_ value: Data, forKey: String)
    func data(forKey: String) -> Data?
    func dictionary(forKey: String) -> [String: Any]?
    func removeObject(forKey: String)
    func removeAll()
    func keys() -> [String]
}

public extension LDConfig {
    typealias CacheFactory = (_ logger: OSLog, _ cacheKey: String) -> KeyedValueCaching
}
