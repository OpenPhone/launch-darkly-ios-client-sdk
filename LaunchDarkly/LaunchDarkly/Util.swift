import CommonCrypto
import Foundation
import Dispatch

class Util {
    enum Error: Swift.Error {
        case keyGeneration
        case commonCrypto(status: CCCryptorStatus)
    }

    internal static let validKindCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    internal static let validTagCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")

    class func sha256base64(_ str: String) -> String {
        sha256(str).base64EncodedString()
    }

    class func sha256hex(_ str: String) -> String {
        sha256(str).map { String(format: "%02hhX", $0) }.joined()
    }

    class func sha256(_ str: String) -> Data {
        let data = Data(str.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }

    class func encrypt(_ data: Data, encryptionKey: String, cacheKey: String) throws -> Data {
        let (key, iv) = try keyAndIV(encryptionKey: encryptionKey, cacheKey: cacheKey)
        return try crypt(operation: CCOperation(kCCEncrypt), data: data, key: key, iv: iv)
    }

    class func decrypt(_ data: Data, encryptionKey: String, cacheKey: String) throws -> Data {
        let (key, iv) = try keyAndIV(encryptionKey: encryptionKey, cacheKey: cacheKey)
        return try crypt(operation: CCOperation(kCCDecrypt), data: data, key: key, iv: iv)
    }

    private class func keyAndIV(encryptionKey: String, cacheKey: String) throws -> (key: Data, iv: Data) {
        guard let key = (encryptionKey + "salt").data(using: .utf8),
              let iv = (encryptionKey + cacheKey).data(using: .utf8)
        else { throw Error.keyGeneration }
        return (key, iv)
    }

    private class func crypt(operation: CCOperation, data: Data, key: Data, iv: Data) throws -> Data {
        let cryptLength = size_t(data.count + kCCBlockSizeAES128)
        var cryptData = Data(count: cryptLength)
        let keyLength = size_t(kCCKeySizeAES128)
        let options = CCOptions(kCCOptionPKCS7Padding)
        var numBytesEncrypted: size_t = 0
        let cryptStatus = cryptData.withUnsafeMutableBytes { cryptBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(operation, CCAlgorithm(kCCAlgorithmAES), options,
                                keyBytes.baseAddress, keyLength, ivBytes.baseAddress,
                                dataBytes.baseAddress, data.count, cryptBytes.baseAddress,
                                cryptLength, &numBytesEncrypted)
                    }
                }
            }
        }
        guard UInt32(cryptStatus) == UInt32(kCCSuccess) else {
            throw Error.commonCrypto(status: cryptStatus)
        }
        cryptData.removeSubrange(numBytesEncrypted..<cryptData.count)
        return cryptData
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
