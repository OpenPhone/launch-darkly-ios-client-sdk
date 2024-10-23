import Foundation
import XCTest

@testable import LaunchDarkly

final class UtilSpec: XCTestCase {

    func testSha256base64() throws {
        let input = "hashThis!"
        let expectedOutput = "sfXg3HewbCAVNQLJzPZhnFKntWYvN0nAYyUWFGy24dQ="
        let output = Util.sha256base64(input)
        XCTAssertEqual(output, expectedOutput)
    }

    func testSha256base64UrlEncoding() throws {
        let input = "OhYeah?HashThis!!!" // hash is KzDwVRpvTuf//jfMK27M4OMpIRTecNcJoaffvAEi+as= and it has a + and a /
        let expectedOutput = "KzDwVRpvTuf__jfMK27M4OMpIRTecNcJoaffvAEi-as="
        let output = Util.sha256(input).base64UrlEncodedString
        XCTAssertEqual(output, expectedOutput)
    }

    func testDispatchQueueDebounceConcurrentRequests() {
        let exp = XCTestExpectation(description: #function)
        let queue = DispatchQueue(label: "test")
        let sut = queue.debouncer()
        var counter: Int = 0
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            sut.debounce(interval: .milliseconds(200)) {
                counter += 1
            }
        }
        XCTAssertEqual(counter, 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            XCTAssertEqual(counter, 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
            XCTAssertEqual(counter, 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testDispatchQueueDebounceDelayedRequests() {
        let exp = XCTestExpectation(description: #function)
        let queue = DispatchQueue(label: "test")
        let sut = queue.debouncer()
        var counter: Int = 0
        for index in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(index * 100)) {
                sut.debounce(interval: .milliseconds(200)) {
                    counter += 1
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
            XCTAssertEqual(counter, 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
}
