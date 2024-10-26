import Foundation
import OSLog

public final class LDFileCache: KeyedValueCaching {

    private static var instances: [String: LDFileCache] = [:]
    private static let instancesLock = NSLock()
    private static let fileQueue = DispatchQueue(label: "ld_file_io", qos: .utility)
    private let cacheKey: String
    private let encryptionKey: String?
    private let inMemoryCache: KeyedValueCaching
    private let fileIO = fileQueue.debouncer()
    private let logger: OSLog

    public static func factory(encryptionKey: String? = nil) -> LDConfig.CacheFactory {
        return { cacheKey, logger in
            instancesLock.lock()
            defer { instancesLock.unlock() }
            let cacheKey = cacheKey ?? "default"
            if let cache = instances[cacheKey] { return cache }
            let inMemoryCache = LDInMemoryCache.factory()(cacheKey, logger)
            let cache = LDFileCache(cacheKey: cacheKey, inMemoryCache: inMemoryCache, encryptionKey: encryptionKey, logger: logger)
            cache.deserializeFromFile()
            instances[cacheKey] = cache
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

    init(cacheKey: String, inMemoryCache: KeyedValueCaching, encryptionKey: String?, logger: OSLog) {
        self.cacheKey = cacheKey
        self.inMemoryCache = inMemoryCache
        self.encryptionKey = encryptionKey
        self.logger = logger
    }

    func scheduleSerialization() {
        fileIO.debounce(interval: Constants.writeToFileDelay) { [weak self] in
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
            var data = try JSONEncoder().encode(dictionary)
            if let encryptionKey {
                data = try Util.encrypt(data, encryptionKey: encryptionKey, cacheKey: cacheKey)
            }
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
            var data = try Data(contentsOf: url)
            if let encryptionKey {
                data = try Util.decrypt(data, encryptionKey: encryptionKey, cacheKey: cacheKey)
            }
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
        let fileName = Util.sha256hex(cacheKey)
        return dir.appendingPathComponent(fileName)
    }
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
