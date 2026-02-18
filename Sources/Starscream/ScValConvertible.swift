import Foundation
import StarscreamXDR

public protocol ScValConvertible: Sendable {
    init(fromScVal scVal: ScVal) throws
    func toScVal() throws -> ScVal
}

extension ScVal: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        self = scVal
    }

    public func toScVal() throws -> ScVal {
        self
    }
}

extension Bool: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .bool(let value) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "Bool", actualValue: scVal)
        }
        self = value
    }

    public func toScVal() throws -> ScVal {
        .bool(self)
    }
}

extension UInt32: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .u32(let value) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "UInt32", actualValue: scVal)
        }
        self = value
    }

    public func toScVal() throws -> ScVal { .u32(self) }
}

extension Int32: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .i32(let value) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "Int32", actualValue: scVal)
        }
        self = value
    }

    public func toScVal() throws -> ScVal { .i32(self) }
}

extension UInt64: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .u64(let value) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "UInt64", actualValue: scVal)
        }
        self = value
    }

    public func toScVal() throws -> ScVal { .u64(self) }
}

extension Int64: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .i64(let value) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "Int64", actualValue: scVal)
        }
        self = value
    }

    public func toScVal() throws -> ScVal { .i64(self) }
}

extension String: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        switch scVal {
        case .string(let value), .symbol(let value):
            self = value
        default:
            throw StarscreamError.resultDecodingFailed(expectedType: "String", actualValue: scVal)
        }
    }

    public func toScVal() throws -> ScVal { .string(self) }
}

extension Data: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .bytes(let value) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "Data", actualValue: scVal)
        }
        self = value
    }

    public func toScVal() throws -> ScVal { .bytes(self) }
}

extension StellarInt128: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .i128(let value) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "StellarInt128", actualValue: scVal)
        }
        self = value
    }

    public func toScVal() throws -> ScVal { .i128(self) }
}

extension StellarUInt128: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .u128(let value) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "StellarUInt128", actualValue: scVal)
        }
        self = value
    }

    public func toScVal() throws -> ScVal { .u128(self) }
}

extension SCAddress: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .address(let value) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "SCAddress", actualValue: scVal)
        }
        self = value
    }

    public func toScVal() throws -> ScVal { .address(self) }
}

extension Array: ScValConvertible where Element: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .vec(let values) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "Array", actualValue: scVal)
        }
        self = try (values ?? []).map(Element.init(fromScVal:))
    }

    public func toScVal() throws -> ScVal {
        .vec(try map { try $0.toScVal() })
    }
}

extension Dictionary: ScValConvertible where Key: ScValConvertible, Value: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        guard case .map(let entries) = scVal else {
            throw StarscreamError.resultDecodingFailed(expectedType: "Dictionary", actualValue: scVal)
        }

        var dict: [Key: Value] = [:]
        for entry in entries ?? [] {
            let key = try Key(fromScVal: entry.key)
            let value = try Value(fromScVal: entry.val)
            dict[key] = value
        }
        self = dict
    }

    public func toScVal() throws -> ScVal {
        let entries = try map { (key: Key, value: Value) in
            SCMapEntry(key: try key.toScVal(), val: try value.toScVal())
        }
        return .map(entries)
    }
}

extension Optional: ScValConvertible where Wrapped: ScValConvertible {
    public init(fromScVal scVal: ScVal) throws {
        if case .void = scVal {
            self = nil
        } else {
            self = try Wrapped(fromScVal: scVal)
        }
    }

    public func toScVal() throws -> ScVal {
        switch self {
        case .none:
            return .void
        case .some(let wrapped):
            return try wrapped.toScVal()
        }
    }
}
