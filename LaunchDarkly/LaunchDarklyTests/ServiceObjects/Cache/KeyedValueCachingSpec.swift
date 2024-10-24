import Foundation
import XCTest

@testable import LaunchDarkly

final class UserDefaultsCachingSpec: KeyedValueCachingBaseSpec {
    override func makeSut(_ key: String) -> KeyedValueCaching {
        return LDConfig.Defaults.cacheFactory(key, .disabled)
    }
}

final class LDInMemoryCacheSpec: KeyedValueCachingBaseSpec {
    override func makeSut(_ key: String) -> KeyedValueCaching {
        return LDInMemoryCache.factory()(key, .disabled)
    }
}

final class LDFileCacheSpec: KeyedValueCachingBaseSpec {

    override func makeSut(_ key: String) -> KeyedValueCaching {
        return LDFileCache.factory()(key, .disabled)
    }

    private func makeFileSut(_ key: String) -> LDFileCache {
        return makeSut(key) as! LDFileCache
    }

    func testPathToFile() throws {
        let sut1 = makeFileSut("test1")
        let sut2 = makeFileSut("test2")
        XCTAssertNotEqual(try sut1.pathToFile(), try sut2.pathToFile())
    }

    func testCorruptFile() throws {
        let sut = makeFileSut(#function)
        let url = try sut.pathToFile()
        try Data("corrupt".utf8).write(to: url, options: .atomic)
        sut.deserializeFromFile()
        XCTAssertEqual(sut.keys(), [])
    }

    func testSerialization() throws {
        let dict: [String: Data] = [
            "key1": try JSONSerialization.data(withJSONObject: [
                "jsonKey1": 42,
                "jsonKey2": "a string",
                "jsonKey3": ["a null": NSNull()]
            ]),
            "key2": Data("random 🔥".utf8),
        ]
        let sut = makeFileSut(#function)
        dict.forEach { key, value in
            sut.set(value, forKey: key)
        }
        let exp = XCTestExpectation(description: #function)
        let delay = DispatchTime.now() + LDFileCache.Constants.writeToFileDelay + .milliseconds(200)
        DispatchQueue.main.asyncAfter(deadline: delay) {
            sut.removeAll()
            XCTAssertEqual(sut.keys(), [])
            sut.deserializeFromFile()
            let keys = sut.keys()
            XCTAssertEqual(Set(keys), Set(dict.keys))
            keys.forEach { key in
                XCTAssertEqual(sut.data(forKey: key), dict[key])
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
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

    func testKeys() throws {
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
