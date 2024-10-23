import Foundation
import OSLog

public final class LDFileCache: KeyedValueCaching {

    private static let instancesLock = NSLock()
    private let cacheKey: String
    private let inMemoryCache: KeyedValueCaching
    private let fileQueue = DispatchQueue(label: "ld_file_io", qos: .utility).debouncer()
    private let logger: OSLog

    public static func factory() -> LDConfig.CacheFactory {
        return { logger, cacheKey in
            instancesLock.lock()
            defer { instancesLock.unlock() }
            let inMemoryCache = LDInMemoryCache.factory()(logger, cacheKey)
            let cache = LDFileCache(cacheKey: cacheKey, inMemoryCache: inMemoryCache, logger: logger)
            if inMemoryCache.data(forKey: initializationKey) == nil {
                cache.deserializeFromFile()
                inMemoryCache.set(Data(), forKey: initializationKey)
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
        return inMemoryCache.keys().filter({ $0 != Self.initializationKey })
    }

    // MARK: - Internal

    init(cacheKey: String, inMemoryCache: KeyedValueCaching, logger: OSLog) {
        self.cacheKey = cacheKey
        self.inMemoryCache = inMemoryCache
        self.logger = logger
    }

    func scheduleSerialization() {
        fileQueue.debounce(interval: Constants.writeToFileDelay) { [weak self] in
            self?.serializeToFile()
        }
    }

    func serializeToFile() {
        do {
            var dictionary: [String: Data] = [:]
            inMemoryCache.keys().forEach { key in
                if let data = inMemoryCache.data(forKey: key) {
                    dictionary[key] = data
                }
            }
            dictionary.removeValue(forKey: Self.initializationKey)
            let data = try JSONEncoder().encode(dictionary)
            let url = try pathToFile()
            try data.write(to: url, options: .atomic)
        } catch {
            os_log("%s failed writing cache to file. Error: %s",
                   log: logger, type: .debug, typeName, String(describing: error))
        }
    }

    func deserializeFromFile() {
        do {
            let url = try pathToFile()
            let data = try Data(contentsOf: url)
            let flags = try JSONDecoder().decode([String: Data].self, from: data)
            flags.forEach { key, value in
                inMemoryCache.set(value, forKey: key)
            }
        } catch {
            os_log("%s failed loading cache from file. Error: %s",
                   log: logger, type: .debug, typeName, String(describing: error))
        }
    }

    func pathToFile() throws -> URL {
        let fileManager = FileManager.default
        guard let dir = fileManager
            .urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ld_cache")
        else { throw Error.cannotAccessLibraryDirectory }
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(cacheKey)
    }

    private static var initializationKey: String { "LDFileCache_initialized" }
}

extension LDFileCache: TypeIdentifying { }

extension LDFileCache {
    enum Error: Swift.Error {
        case cannotAccessLibraryDirectory
    }
    enum Constants {
        static var writeToFileDelay: DispatchTimeInterval { .milliseconds(300) }
    }
}
