import Foundation

public enum XDRDecodingError: Error, Sendable, Equatable, Hashable {
    case insufficientData(expected: Int, available: Int)
    case invalidDiscriminant(type: String, value: Int32)
    case invalidLength(expected: Int, actual: Int)
    case invalidPadding
    case trailingData(consumed: Int, total: Int)
    case invalidUTF8
}

public struct XDRDecoder: ~Copyable {
    public let data: Data
    public private(set) var cursor: Int

    public init(data: Data) {
        self.data = data
        self.cursor = 0
    }

    public static func decodeValue<T: XDRCodable>(_ type: T.Type = T.self, from data: Data) throws -> T {
        var decoder = XDRDecoder(data: data)
        let value = try T(from: &decoder)
        if decoder.cursor != data.count {
            throw XDRDecodingError.trailingData(consumed: decoder.cursor, total: data.count)
        }
        return value
    }

    public mutating func decode() throws -> Int32 {
        let raw = try readBytes(count: 4)
        let value = (UInt32(raw[0]) << 24)
            | (UInt32(raw[1]) << 16)
            | (UInt32(raw[2]) << 8)
            | UInt32(raw[3])
        return Int32(bitPattern: value)
    }

    public mutating func decode() throws -> UInt32 {
        UInt32(bitPattern: try decode() as Int32)
    }

    public mutating func decode() throws -> Int64 {
        let raw = try readBytes(count: 8)
        let value = (UInt64(raw[0]) << 56)
            | (UInt64(raw[1]) << 48)
            | (UInt64(raw[2]) << 40)
            | (UInt64(raw[3]) << 32)
            | (UInt64(raw[4]) << 24)
            | (UInt64(raw[5]) << 16)
            | (UInt64(raw[6]) << 8)
            | UInt64(raw[7])
        return Int64(bitPattern: value)
    }

    public mutating func decode() throws -> UInt64 {
        UInt64(bitPattern: try decode() as Int64)
    }

    public mutating func decode() throws -> Bool {
        let raw: Int32 = try decode()
        switch raw {
        case 0: return false
        case 1: return true
        default: throw XDRDecodingError.invalidDiscriminant(type: "Bool", value: raw)
        }
    }

    public mutating func decode(fixed: Int? = nil) throws -> Data {
        let length: Int
        if let fixed {
            length = fixed
        } else {
            let dynamicLength: UInt32 = try decode()
            length = Int(dynamicLength)
        }

        let payload = try readBytes(count: length)
        try consumePadding(forLength: length)
        return payload
    }

    public mutating func decode() throws -> String {
        let bytes: Data = try decode()
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw XDRDecodingError.invalidUTF8
        }
        return string
    }

    public mutating func decode<T: XDRCodable>() throws -> [T] {
        let count: UInt32 = try decode()
        var values: [T] = []
        values.reserveCapacity(Int(count))
        for _ in 0..<count {
            values.append(try T(from: &self))
        }
        return values
    }

    public mutating func decode<T: XDRCodable>() throws -> T? {
        let isPresent: Bool = try decode()
        return isPresent ? try T(from: &self) : nil
    }

    public mutating func decode<T: XDRCodable>() throws -> [T]? {
        let isPresent: Bool = try decode()
        if !isPresent {
            return nil
        }
        let array: [T] = try decode()
        return array
    }

    public mutating func decodeX<T: XDRCodable>(_ type: T.Type = T.self) throws -> T {
        try T(from: &self)
    }

    private mutating func readBytes(count: Int) throws -> Data {
        guard count >= 0 else {
            throw XDRDecodingError.invalidLength(expected: 0, actual: count)
        }
        let endIndex = cursor + count
        guard endIndex <= data.count else {
            throw XDRDecodingError.insufficientData(expected: endIndex, available: data.count)
        }
        let slice = data[cursor..<endIndex]
        cursor = endIndex
        return Data(slice)
    }

    private mutating func consumePadding(forLength length: Int) throws {
        let padding = (4 - (length % 4)) % 4
        guard padding > 0 else { return }
        let bytes = try readBytes(count: padding)
        if bytes.contains(where: { $0 != 0 }) {
            throw XDRDecodingError.invalidPadding
        }
    }
}
