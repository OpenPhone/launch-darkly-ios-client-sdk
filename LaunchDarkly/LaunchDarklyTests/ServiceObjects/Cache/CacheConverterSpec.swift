import Foundation
import XCTest

@testable import LaunchDarkly

final class CacheConverterSpec: XCTestCase {

    private var serviceFactory: ClientServiceMockFactory!

    private static var upToDateData: Data!

    override class func setUp() {
        upToDateData = try! JSONEncoder().encode(["version": 8])
    }

    override func setUp() {
        serviceFactory = ClientServiceMockFactory(config: LDConfig(mobileKey: "sdk-key", autoEnvAttributes: .disabled))
    }

    func testNoKeysGiven() {
        CacheConverter().convertCacheData(serviceFactory: serviceFactory, keysToConvert: [], maxCachedContexts: 0)
        // We always make one call to try and clean up old v5 data.
        XCTAssertEqual(serviceFactory.makeKeyedValueCacheCallCount, 1)
        XCTAssertEqual(serviceFactory.makeFeatureFlagCacheCallCount, 0)
    }

    func testUpToDate() {
        let v7valueCacheMock = KeyedValueCachingMock()
        v7valueCacheMock.keysReturnValue = ["key1", "key2"]
        serviceFactory.makeFeatureFlagCacheReturnValue.keyedValueCache = v7valueCacheMock
        serviceFactory.makeKeyedValueCacheReturnValue = v7valueCacheMock
        v7valueCacheMock.dataReturnValue = CacheConverterSpec.upToDateData
        CacheConverter().convertCacheData(serviceFactory: serviceFactory, keysToConvert: ["key1", "key2"], maxCachedContexts: 0)
        XCTAssertEqual(serviceFactory.makeFeatureFlagCacheCallCount, 2)
        XCTAssertEqual(v7valueCacheMock.dataCallCount, 2)
    }

    func testCacheStoreMigration() {
        let oldCache = LDInMemoryCache()
        oldCache.set(Data("test_1".utf8), forKey: "data_1")
        oldCache.set(Data("test_2".utf8), forKey: "data_2")
        oldCache.set(Data("test_3".utf8), forKey: "data_3")
        let newCache = KeyedValueCachingMock()
        newCache.keysReturnValue = []
        serviceFactory.makeFeatureFlagCacheReturnValue.keyedValueCache = newCache
        serviceFactory.makeKeyedValueCacheReturnValue = newCache
        CacheConverter().migrateStorage(serviceFactory: serviceFactory, keysToMigrate: ["key1", "key2"], from: { _, _ in oldCache })
        XCTAssertEqual(serviceFactory.makeKeyedValueCacheCallCount, 2)
        XCTAssertEqual(newCache.setCallCount, 6)
    }
}
