import Foundation

public final class LDFileCache: KeyedValueCaching {

    private static let instancesLock = NSLock()
    private let cacheKey: String
    private let inMemoryCache: LDInMemoryCache
    private let fileQueue = DispatchQueue(label: "ld_file_io", qos: .utility).debouncer()

    public static func builder() -> (String) -> KeyedValueCaching {
        return { cacheKey in
            instancesLock.lock()
            defer { instancesLock.unlock() }
            let inMemoryCache = LDInMemoryCache.builder()(cacheKey)
            let cache = LDFileCache(cacheKey: cacheKey, inMemoryCache: inMemoryCache)
            if inMemoryCache.data(forKey: "is_initialized") == nil {
                cache.deserializeFromFile()
                inMemoryCache.set(Data(), forKey: "is_initialized")
            }
            return cache
        }
    }

    public func set(_ value: Data, forKey: String) {
        inMemoryCache.set(value, forKey: forKey)
        scheduleSerialization()
    }

    public func data(forKey: String) -> Data? {
        return inMemoryCache.data(forKey: forKey)
    }

    public func dictionary(forKey: String) -> [String : Any]? {
        // Legacy - not used by the library
        return nil
    }

    public func removeObject(forKey: String) {
        inMemoryCache.removeObject(forKey: forKey)
        scheduleSerialization()
    }

    public func removeAll() {
        inMemoryCache.removeAll()
        scheduleSerialization()
    }

    public func keys() -> [String] {
        return inMemoryCache.keys()
    }

    // MARK: - Internal

    init(cacheKey: String, inMemoryCache: LDInMemoryCache) {
        self.cacheKey = cacheKey
        self.inMemoryCache = inMemoryCache
    }

    func deserializeFromFile() {

    }

    func serializeToFile() {

    }

    func scheduleSerialization() {
        fileQueue.debounce(interval: .milliseconds(500)) { [weak self] in
            self?.serializeToFile()
        }
    }
}
