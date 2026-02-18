import Foundation

public protocol XDRCodable: Sendable {
    func encode(to encoder: inout XDREncoder) throws
    init(from decoder: inout XDRDecoder) throws
}

public extension XDRCodable {
    func toXDR() throws -> Data {
        var encoder = XDREncoder()
        try encode(to: &encoder)
        return encoder.data
    }

    init(xdr: Data) throws {
        var decoder = XDRDecoder(data: xdr)
        try self.init(from: &decoder)
        if decoder.cursor != xdr.count {
            throw XDRDecodingError.trailingData(consumed: decoder.cursor, total: xdr.count)
        }
    }
}

public struct XDREncoder: ~Copyable {
    public private(set) var data: Data

    public init() {
        self.data = Data()
    }

    public static func encode<T: XDRCodable>(_ value: T) throws -> Data {
        var encoder = XDREncoder()
        try value.encode(to: &encoder)
        return encoder.data
    }

    public mutating func encode(_ value: Int32) {
        append(value.bigEndian)
    }

    public mutating func encode(_ value: UInt32) {
        append(value.bigEndian)
    }

    public mutating func encode(_ value: Int64) {
        append(value.bigEndian)
    }

    public mutating func encode(_ value: UInt64) {
        append(value.bigEndian)
    }

    public mutating func encode(_ value: Bool) {
        encode(value ? Int32(1) : Int32(0))
    }

    public mutating func encode(_ value: Data, fixed: Int? = nil) {
        if let fixed {
            precondition(value.count == fixed, "Fixed opaque length mismatch")
            data.append(value)
            appendPadding(forLength: fixed)
            return
        }

        encode(UInt32(clamping: value.count))
        data.append(value)
        appendPadding(forLength: value.count)
    }

    public mutating func encode(_ value: String) {
        encode(Data(value.utf8))
    }

    public mutating func encode<T: XDRCodable>(_ array: [T]) throws {
        encode(UInt32(clamping: array.count))
        for element in array {
            try element.encode(to: &self)
        }
    }

    public mutating func encode<T: XDRCodable>(_ value: T?) throws {
        if let value {
            encode(true)
            try value.encode(to: &self)
        } else {
            encode(false)
        }
    }

    public mutating func encode<T: XDRCodable>(_ array: [T]?) throws {
        if let array {
            encode(true)
            try encode(array)
        } else {
            encode(false)
        }
    }

    private mutating func append<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
    }

    private mutating func appendPadding(forLength length: Int) {
        let padding = (4 - (length % 4)) % 4
        guard padding > 0 else { return }
        data.append(contentsOf: repeatElement(UInt8(0), count: padding))
    }
}

extension Int32: XDRCodable {
    public func encode(to encoder: inout XDREncoder) throws { encoder.encode(self) }
    public init(from decoder: inout XDRDecoder) throws { self = try decoder.decode() }
}

extension UInt32: XDRCodable {
    public func encode(to encoder: inout XDREncoder) throws { encoder.encode(self) }
    public init(from decoder: inout XDRDecoder) throws { self = try decoder.decode() }
}

extension Int64: XDRCodable {
    public func encode(to encoder: inout XDREncoder) throws { encoder.encode(self) }
    public init(from decoder: inout XDRDecoder) throws { self = try decoder.decode() }
}

extension UInt64: XDRCodable {
    public func encode(to encoder: inout XDREncoder) throws { encoder.encode(self) }
    public init(from decoder: inout XDRDecoder) throws { self = try decoder.decode() }
}

extension Bool: XDRCodable {
    public func encode(to encoder: inout XDREncoder) throws { encoder.encode(self) }
    public init(from decoder: inout XDRDecoder) throws { self = try decoder.decode() }
}

extension Data: XDRCodable {
    public func encode(to encoder: inout XDREncoder) throws { encoder.encode(self) }
    public init(from decoder: inout XDRDecoder) throws { self = try decoder.decode() }
}

extension String: XDRCodable {
    public func encode(to encoder: inout XDREncoder) throws { encoder.encode(self) }
    public init(from decoder: inout XDRDecoder) throws { self = try decoder.decode() }
}
