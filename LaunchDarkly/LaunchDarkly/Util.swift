import CommonCrypto
import Foundation
import Dispatch

class Util {
    internal static let validKindCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    internal static let validTagCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")

    class func sha256base64(_ str: String) -> String {
        sha256(str).base64EncodedString()
    }

    class func sha256(_ str: String) -> Data {
        let data = Data(str.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }
}

extension String {
    func onlyContainsCharset(_ set: CharacterSet) -> Bool {
        if description.rangeOfCharacter(from: set.inverted) != nil {
            return false
        }

        return true
    }
}

extension DispatchQueue {

    func debouncer() -> Debouncer {
        Debouncer(queue: self)
    }

    final class Debouncer {
        private let lock = NSLock()
        private let queue: DispatchQueue
        private var workItem: DispatchWorkItem?

        fileprivate init(queue: DispatchQueue) {
            self.queue = queue
        }

        func debounce(interval: DispatchTimeInterval, action: @escaping () -> Void) {
            lock.lock(); defer { lock.unlock() }
            workItem?.cancel()
            let workItem = DispatchWorkItem(block: action)
            self.workItem = workItem
            queue.asyncAfter(deadline: .now() + interval, execute: workItem)
        }
    }
}
