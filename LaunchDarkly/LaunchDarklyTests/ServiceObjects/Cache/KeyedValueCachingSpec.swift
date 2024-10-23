import Foundation
import XCTest

@testable import LaunchDarkly

final class UserDefaultsCachingSpec: KeyedValueCachingBaseSpec {
    override func makeSut(_ key: String) -> KeyedValueCaching {
        return LDConfig.Defaults.cacheBuilder(key)
    }
}

final class LDInMemoryCacheSpec: KeyedValueCachingBaseSpec {
    override func makeSut(_ key: String) -> KeyedValueCaching {
        return LDInMemoryCache.builder(key)
    }
}

// MARK: - Base spec

class KeyedValueCachingBaseSpec: XCTestCase {

    func makeSut(_ key: String) -> KeyedValueCaching {
        fatalError("Override in a subclass")
    }

    private func skipForBaseSpec() throws {
        if type(of: self) == KeyedValueCachingBaseSpec.self {
            throw XCTSkip()
        }
    }

    // MARK: - public KeyedValueCaching protocol methods

    func testDataForkey() throws {
        try skipForBaseSpec()
        let data = Data("random".utf8)
        makeSut("test").set(data, forKey: "test_key")
        XCTAssertEqual(makeSut("test").data(forKey: "test_key"), data)
    }

    func testDictionaryForKey() throws {
        try skipForBaseSpec()
        // No-op: no public setter declared in the protocol, unused in the library
    }

    func testRemoveObjectForKey() throws {
        try skipForBaseSpec()
        let data = Data("random".utf8)
        makeSut("test").set(data, forKey: "test_key")
        makeSut("test").removeObject(forKey: "test_key")
        XCTAssertNil(makeSut("test").data(forKey: "test_key"))
    }

    func testRemoveAll() throws {
        try skipForBaseSpec()
        let data = Data("random".utf8)
        makeSut("test").set(data, forKey: "test_key")
        makeSut("test").removeAll()
        XCTAssertNil(makeSut("test").data(forKey: "test_key"))
    }

    func testKeysGetter() throws {
        try skipForBaseSpec()
        let sut = makeSut("test")
        let keys = Array(0..<10).map { "key_\($0)" }
        keys.forEach { sut.set(Data($0.utf8), forKey: $0) }
        let storedKeys = makeSut("test").keys()
        // storedKeys may contain external key-values
        XCTAssertEqual(Set(storedKeys).intersection(Set(keys)), Set(keys))
    }

    // MARK: - Non-trivial access conditions

    func testSeparateCacheInstancePerCacheKey() throws {
        try skipForBaseSpec()
        let sut1 = makeSut("key_1")
        let sut2 = makeSut("key_2")
        let sut3 = makeSut("key_3")
        sut1.set(Data("1".utf8), forKey: "test_key")
        sut2.set(Data("2".utf8), forKey: "test_key")
        sut3.set(Data("3".utf8), forKey: "test_key")
        sut3.removeAll()
        XCTAssertEqual(sut1.data(forKey: "test_key"), Data("1".utf8))
        XCTAssertEqual(sut2.data(forKey: "test_key"), Data("2".utf8))
        XCTAssertNil(sut3.data(forKey: "test_key"))
    }

    func testConcurrentAccess() throws {
        try skipForBaseSpec()
        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            let cacheKey = "cache_\(index % 3)"
            let sut = makeSut(cacheKey)
            if index % 9 == 0 {
                sut.removeAll()
            } else {
                let keyIndex = index % 5
                sut.set(Data("value_\(keyIndex)".utf8), forKey: "\(keyIndex)")
            }
        }
        for cacheIndex in 0..<3 {
            let sut = makeSut("cache_\(cacheIndex)")
            let keys = sut.keys()
            for key in keys {
                guard let index = Int(key) else { continue }
                XCTAssertEqual(sut.data(forKey: key), Data("value_\(index)".utf8))
            }
        }
    }
}
