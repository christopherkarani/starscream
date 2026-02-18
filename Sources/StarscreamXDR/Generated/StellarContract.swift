import Foundation

public struct MuxedEd25519Account: XDRCodable, Sendable, Hashable {
    public let id: UInt64
    public let ed25519: UInt256

    public init(id: UInt64, ed25519: UInt256) {
        self.id = id
        self.ed25519 = ed25519
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(id)
        encoder.encode(ed25519, fixed: 32)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.id = try decoder.decodeX()
        self.ed25519 = try decoder.decode(fixed: 32)
    }
}

public enum ClaimableBalanceID: XDRCodable, Sendable, Hashable {
    case v0(Hash)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .v0(let hash):
            encoder.encode(Int32(0))
            encoder.encode(hash, fixed: 32)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        guard disc == 0 else {
            throw XDRDecodingError.invalidDiscriminant(type: "ClaimableBalanceID", value: disc)
        }
        self = .v0(try decoder.decode(fixed: 32))
    }
}

public enum SCAddress: XDRCodable, Sendable, Hashable {
    case account(AccountID)
    case contract(Hash)
    case muxedAccount(MuxedEd25519Account)
    case claimableBalance(ClaimableBalanceID)
    case liquidityPool(Hash)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .account(let account):
            encoder.encode(Int32(0))
            try account.encode(to: &encoder)
        case .contract(let contract):
            encoder.encode(Int32(1))
            encoder.encode(contract, fixed: 32)
        case .muxedAccount(let muxed):
            encoder.encode(Int32(2))
            try muxed.encode(to: &encoder)
        case .claimableBalance(let balance):
            encoder.encode(Int32(3))
            try balance.encode(to: &encoder)
        case .liquidityPool(let pool):
            encoder.encode(Int32(4))
            encoder.encode(pool, fixed: 32)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0:
            self = .account(try decoder.decodeX())
        case 1:
            self = .contract(try decoder.decode(fixed: 32))
        case 2:
            self = .muxedAccount(try decoder.decodeX())
        case 3:
            self = .claimableBalance(try decoder.decodeX())
        case 4:
            self = .liquidityPool(try decoder.decode(fixed: 32))
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "SCAddress", value: disc)
        }
    }
}

public struct SCMapEntry: XDRCodable, Sendable, Hashable {
    public let key: ScVal
    public let val: ScVal

    public init(key: ScVal, val: ScVal) {
        self.key = key
        self.val = val
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try key.encode(to: &encoder)
        try val.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.key = try decoder.decodeX()
        self.val = try decoder.decodeX()
    }
}

public enum SCErrorCode: Int32, XDRCodable, Sendable, Hashable {
    case arithDomain = 0
    case indexBounds = 1
    case invalidInput = 2
    case missingValue = 3
    case existingValue = 4
    case exceededLimit = 5
    case invalidAction = 6
    case internalError = 7
    case unexpectedType = 8
    case unexpectedSize = 9

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(rawValue)
    }

    public init(from decoder: inout XDRDecoder) throws {
        let raw: Int32 = try decoder.decodeX()
        guard let value = Self(rawValue: raw) else {
            throw XDRDecodingError.invalidDiscriminant(type: "SCErrorCode", value: raw)
        }
        self = value
    }
}

public enum SCError: XDRCodable, Sendable, Hashable {
    case contract(UInt32)
    case wasmVm(SCErrorCode)
    case context(SCErrorCode)
    case storage(SCErrorCode)
    case object(SCErrorCode)
    case crypto(SCErrorCode)
    case events(SCErrorCode)
    case budget(SCErrorCode)
    case value(SCErrorCode)
    case auth(SCErrorCode)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .contract(let value):
            encoder.encode(Int32(0))
            encoder.encode(value)
        case .wasmVm(let code):
            encoder.encode(Int32(1))
            try code.encode(to: &encoder)
        case .context(let code):
            encoder.encode(Int32(2))
            try code.encode(to: &encoder)
        case .storage(let code):
            encoder.encode(Int32(3))
            try code.encode(to: &encoder)
        case .object(let code):
            encoder.encode(Int32(4))
            try code.encode(to: &encoder)
        case .crypto(let code):
            encoder.encode(Int32(5))
            try code.encode(to: &encoder)
        case .events(let code):
            encoder.encode(Int32(6))
            try code.encode(to: &encoder)
        case .budget(let code):
            encoder.encode(Int32(7))
            try code.encode(to: &encoder)
        case .value(let code):
            encoder.encode(Int32(8))
            try code.encode(to: &encoder)
        case .auth(let code):
            encoder.encode(Int32(9))
            try code.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0:
            self = .contract(try decoder.decodeX())
        case 1:
            self = .wasmVm(try decoder.decodeX())
        case 2:
            self = .context(try decoder.decodeX())
        case 3:
            self = .storage(try decoder.decodeX())
        case 4:
            self = .object(try decoder.decodeX())
        case 5:
            self = .crypto(try decoder.decodeX())
        case 6:
            self = .events(try decoder.decodeX())
        case 7:
            self = .budget(try decoder.decodeX())
        case 8:
            self = .value(try decoder.decodeX())
        case 9:
            self = .auth(try decoder.decodeX())
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "SCError", value: disc)
        }
    }
}

public struct SCContractInstance: XDRCodable, Sendable, Hashable {
    public let executable: ContractExecutable
    public let storage: [SCMapEntry]?

    public init(executable: ContractExecutable, storage: [SCMapEntry]?) {
        self.executable = executable
        self.storage = storage
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try executable.encode(to: &encoder)
        try encoder.encode(storage)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.executable = try decoder.decodeX()
        self.storage = try decoder.decodeX()
    }
}

public struct SCNonceKey: XDRCodable, Sendable, Hashable {
    public let nonce: Int64

    public init(nonce: Int64) {
        self.nonce = nonce
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(nonce)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.nonce = try decoder.decodeX()
    }
}

public enum ScVal: XDRCodable, Sendable, Hashable {
    case bool(Bool)
    case void
    case error(SCError)
    case u32(UInt32)
    case i32(Int32)
    case u64(UInt64)
    case i64(Int64)
    case timepoint(UInt64)
    case duration(UInt64)
    case u128(StellarUInt128)
    case i128(StellarInt128)
    case u256(UInt256)
    case i256(Int256)
    case bytes(Data)
    case string(String)
    case symbol(String)
    case vec([ScVal]?)
    case map([SCMapEntry]?)
    case address(SCAddress)
    case contractInstance(SCContractInstance)
    case ledgerKeyContractInstance
    case ledgerKeyNonce(SCNonceKey)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .bool(let value):
            encoder.encode(Int32(0))
            encoder.encode(value)
        case .void:
            encoder.encode(Int32(1))
        case .error(let value):
            encoder.encode(Int32(2))
            try value.encode(to: &encoder)
        case .u32(let value):
            encoder.encode(Int32(3))
            encoder.encode(value)
        case .i32(let value):
            encoder.encode(Int32(4))
            encoder.encode(value)
        case .u64(let value):
            encoder.encode(Int32(5))
            encoder.encode(value)
        case .i64(let value):
            encoder.encode(Int32(6))
            encoder.encode(value)
        case .timepoint(let value):
            encoder.encode(Int32(7))
            encoder.encode(value)
        case .duration(let value):
            encoder.encode(Int32(8))
            encoder.encode(value)
        case .u128(let value):
            encoder.encode(Int32(9))
            try value.encode(to: &encoder)
        case .i128(let value):
            encoder.encode(Int32(10))
            try value.encode(to: &encoder)
        case .u256(let value):
            encoder.encode(Int32(11))
            encoder.encode(value, fixed: 32)
        case .i256(let value):
            encoder.encode(Int32(12))
            encoder.encode(value, fixed: 32)
        case .bytes(let value):
            encoder.encode(Int32(13))
            encoder.encode(value)
        case .string(let value):
            encoder.encode(Int32(14))
            encoder.encode(value)
        case .symbol(let value):
            encoder.encode(Int32(15))
            encoder.encode(value)
        case .vec(let value):
            encoder.encode(Int32(16))
            try encoder.encode(value)
        case .map(let value):
            encoder.encode(Int32(17))
            try encoder.encode(value)
        case .address(let value):
            encoder.encode(Int32(18))
            try value.encode(to: &encoder)
        case .contractInstance(let value):
            encoder.encode(Int32(19))
            try value.encode(to: &encoder)
        case .ledgerKeyContractInstance:
            encoder.encode(Int32(20))
        case .ledgerKeyNonce(let value):
            encoder.encode(Int32(21))
            try value.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0:
            self = .bool(try decoder.decodeX())
        case 1:
            self = .void
        case 2:
            self = .error(try decoder.decodeX())
        case 3:
            self = .u32(try decoder.decodeX())
        case 4:
            self = .i32(try decoder.decodeX())
        case 5:
            self = .u64(try decoder.decodeX())
        case 6:
            self = .i64(try decoder.decodeX())
        case 7:
            self = .timepoint(try decoder.decodeX())
        case 8:
            self = .duration(try decoder.decodeX())
        case 9:
            self = .u128(try decoder.decodeX())
        case 10:
            self = .i128(try decoder.decodeX())
        case 11:
            self = .u256(try decoder.decode(fixed: 32))
        case 12:
            self = .i256(try decoder.decode(fixed: 32))
        case 13:
            self = .bytes(try decoder.decodeX())
        case 14:
            self = .string(try decoder.decodeX())
        case 15:
            self = .symbol(try decoder.decodeX())
        case 16:
            self = .vec(try decoder.decodeX())
        case 17:
            self = .map(try decoder.decodeX())
        case 18:
            self = .address(try decoder.decodeX())
        case 19:
            self = .contractInstance(try decoder.decodeX())
        case 20:
            self = .ledgerKeyContractInstance
        case 21:
            self = .ledgerKeyNonce(try decoder.decodeX())
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "ScVal", value: disc)
        }
    }
}

public enum SCSpecEntry: XDRCodable, Sendable, Hashable {
    case functionV0(SCSpecFunctionV0)
    case udtStructV0(SCSpecUDTStructV0)
    case udtUnionV0(SCSpecUDTUnionV0)
    case udtEnumV0(SCSpecUDTEnumV0)
    case udtErrorEnumV0(SCSpecUDTErrorEnumV0)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .functionV0(let value):
            encoder.encode(Int32(0))
            try value.encode(to: &encoder)
        case .udtStructV0(let value):
            encoder.encode(Int32(1))
            try value.encode(to: &encoder)
        case .udtUnionV0(let value):
            encoder.encode(Int32(2))
            try value.encode(to: &encoder)
        case .udtEnumV0(let value):
            encoder.encode(Int32(3))
            try value.encode(to: &encoder)
        case .udtErrorEnumV0(let value):
            encoder.encode(Int32(4))
            try value.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0:
            self = .functionV0(try decoder.decodeX())
        case 1:
            self = .udtStructV0(try decoder.decodeX())
        case 2:
            self = .udtUnionV0(try decoder.decodeX())
        case 3:
            self = .udtEnumV0(try decoder.decodeX())
        case 4:
            self = .udtErrorEnumV0(try decoder.decodeX())
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "SCSpecEntry", value: disc)
        }
    }
}

public struct SCSpecFunctionInputV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let type: SCSpecTypeDef

    public init(name: String, type: SCSpecTypeDef) {
        self.name = name
        self.type = type
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        try type.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.type = try decoder.decodeX()
    }
}

public struct SCSpecFunctionV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let inputs: [SCSpecFunctionInputV0]
    public let outputs: [SCSpecTypeDef]

    public init(name: String, inputs: [SCSpecFunctionInputV0], outputs: [SCSpecTypeDef]) {
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        try encoder.encode(inputs)
        try encoder.encode(outputs)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.inputs = try decoder.decodeX()
        self.outputs = try decoder.decodeX()
    }
}

public struct SCSpecUDTStructFieldV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let type: SCSpecTypeDef

    public init(name: String, type: SCSpecTypeDef) {
        self.name = name
        self.type = type
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        try type.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.type = try decoder.decodeX()
    }
}

public struct SCSpecUDTStructV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let fields: [SCSpecUDTStructFieldV0]

    public init(name: String, fields: [SCSpecUDTStructFieldV0]) {
        self.name = name
        self.fields = fields
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        try encoder.encode(fields)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.fields = try decoder.decodeX()
    }
}

public struct SCSpecUDTEnumCaseV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let value: UInt32

    public init(name: String, value: UInt32) {
        self.name = name
        self.value = value
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        encoder.encode(value)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.value = try decoder.decodeX()
    }
}

public struct SCSpecUDTEnumV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let cases: [SCSpecUDTEnumCaseV0]

    public init(name: String, cases: [SCSpecUDTEnumCaseV0]) {
        self.name = name
        self.cases = cases
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        try encoder.encode(cases)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.cases = try decoder.decodeX()
    }
}

public struct SCSpecUDTUnionCaseV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let type: SCSpecTypeDef?

    public init(name: String, type: SCSpecTypeDef?) {
        self.name = name
        self.type = type
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        try encoder.encode(type)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.type = try decoder.decodeX()
    }
}

public struct SCSpecUDTUnionV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let cases: [SCSpecUDTUnionCaseV0]

    public init(name: String, cases: [SCSpecUDTUnionCaseV0]) {
        self.name = name
        self.cases = cases
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        try encoder.encode(cases)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.cases = try decoder.decodeX()
    }
}

public struct SCSpecUDTErrorEnumCaseV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let value: UInt32

    public init(name: String, value: UInt32) {
        self.name = name
        self.value = value
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        encoder.encode(value)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.value = try decoder.decodeX()
    }
}

public struct SCSpecUDTErrorEnumV0: XDRCodable, Sendable, Hashable {
    public let name: String
    public let cases: [SCSpecUDTErrorEnumCaseV0]

    public init(name: String, cases: [SCSpecUDTErrorEnumCaseV0]) {
        self.name = name
        self.cases = cases
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(name)
        try encoder.encode(cases)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.name = try decoder.decodeX()
        self.cases = try decoder.decodeX()
    }
}

public indirect enum SCSpecTypeDef: XDRCodable, Sendable, Hashable {
    case val
    case bool
    case void
    case error
    case u32
    case i32
    case u64
    case i64
    case timepoint
    case duration
    case u128
    case i128
    case u256
    case i256
    case bytes
    case string
    case symbol
    case address
    case muxedAddress
    case option(SCSpecTypeDef)
    case result(ok: SCSpecTypeDef, error: SCSpecTypeDef)
    case vec(SCSpecTypeDef)
    case map(key: SCSpecTypeDef, value: SCSpecTypeDef)
    case tuple([SCSpecTypeDef])
    case bytesN(UInt32)
    case udt(String)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .val: encoder.encode(Int32(0))
        case .bool: encoder.encode(Int32(1))
        case .void: encoder.encode(Int32(2))
        case .error: encoder.encode(Int32(3))
        case .u32: encoder.encode(Int32(4))
        case .i32: encoder.encode(Int32(5))
        case .u64: encoder.encode(Int32(6))
        case .i64: encoder.encode(Int32(7))
        case .timepoint: encoder.encode(Int32(8))
        case .duration: encoder.encode(Int32(9))
        case .u128: encoder.encode(Int32(10))
        case .i128: encoder.encode(Int32(11))
        case .u256: encoder.encode(Int32(12))
        case .i256: encoder.encode(Int32(13))
        case .bytes: encoder.encode(Int32(14))
        case .string: encoder.encode(Int32(16))
        case .symbol: encoder.encode(Int32(17))
        case .address: encoder.encode(Int32(19))
        case .muxedAddress: encoder.encode(Int32(20))
        case .option(let value):
            encoder.encode(Int32(1000))
            try value.encode(to: &encoder)
        case .result(let ok, let error):
            encoder.encode(Int32(1001))
            try ok.encode(to: &encoder)
            try error.encode(to: &encoder)
        case .vec(let value):
            encoder.encode(Int32(1002))
            try value.encode(to: &encoder)
        case .map(let key, let value):
            encoder.encode(Int32(1004))
            try key.encode(to: &encoder)
            try value.encode(to: &encoder)
        case .tuple(let values):
            encoder.encode(Int32(1005))
            try encoder.encode(values)
        case .bytesN(let count):
            encoder.encode(Int32(1006))
            encoder.encode(count)
        case .udt(let name):
            encoder.encode(Int32(2000))
            encoder.encode(name)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .val
        case 1: self = .bool
        case 2: self = .void
        case 3: self = .error
        case 4: self = .u32
        case 5: self = .i32
        case 6: self = .u64
        case 7: self = .i64
        case 8: self = .timepoint
        case 9: self = .duration
        case 10: self = .u128
        case 11: self = .i128
        case 12: self = .u256
        case 13: self = .i256
        case 14: self = .bytes
        case 16: self = .string
        case 17: self = .symbol
        case 19: self = .address
        case 20: self = .muxedAddress
        case 1000: self = .option(try decoder.decodeX())
        case 1001: self = .result(ok: try decoder.decodeX(), error: try decoder.decodeX())
        case 1002: self = .vec(try decoder.decodeX())
        case 1004: self = .map(key: try decoder.decodeX(), value: try decoder.decodeX())
        case 1005: self = .tuple(try decoder.decodeX())
        case 1006: self = .bytesN(try decoder.decodeX())
        case 2000: self = .udt(try decoder.decodeX())
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "SCSpecTypeDef", value: disc)
        }
    }
}
