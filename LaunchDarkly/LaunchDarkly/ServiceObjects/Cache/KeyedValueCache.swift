import Foundation

// sourcery: autoMockable
public protocol KeyedValueCaching {
    func set(_ value: Data, forKey: String)
    func data(forKey: String) -> Data?
    func dictionary(forKey: String) -> [String: Any]?
    func removeObject(forKey: String)
    func removeAll()
    func keys() -> [String]
}

extension UserDefaults: KeyedValueCaching {
    public func set(_ value: Data, forKey: String) {
        set(value as Any?, forKey: forKey)
    }

    public func removeAll() {
        dictionaryRepresentation().keys.forEach { removeObject(forKey: $0) }
    }

    public func keys() -> [String] {
        dictionaryRepresentation().keys.map { String($0) }
    }
}
