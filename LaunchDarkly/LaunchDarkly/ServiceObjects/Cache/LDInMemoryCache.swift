import Foundation

public final class LDInMemoryCache: KeyedValueCaching {

    private static var instances: [String: LDInMemoryCache] = [:]
    private static let instancesLock = NSLock()

    private var cache: [String: Any] = [:]
    private var cacheLock = NSLock()

    public static func factory() -> LDConfig.CacheFactory {
        return { _, cacheKey in
            instancesLock.lock()
            defer { instancesLock.unlock() }
            if let cache = instances[cacheKey] { return cache }
            let cache = LDInMemoryCache()
            instances[cacheKey] = cache
            return cache
        }
    }

    public func set(_ value: Data, forKey: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[forKey] = value
    }

    public func data(forKey: String) -> Data? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[forKey] as? Data
    }

    public func removeObject(forKey: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeValue(forKey: forKey)
    }

    public func removeAll() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
    }

    public func keys() -> [String] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return Array(cache.keys)
    }
}
