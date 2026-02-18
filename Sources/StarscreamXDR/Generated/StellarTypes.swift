import Foundation

public typealias Hash = Data
public typealias UInt256 = Data
public typealias Int256 = Data

public struct StellarUInt128: XDRCodable, Sendable, Hashable {
    public let hi: UInt64
    public let lo: UInt64

    public init(hi: UInt64, lo: UInt64) {
        self.hi = hi
        self.lo = lo
    }

    public init(_ value: UInt64) {
        self.hi = 0
        self.lo = value
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(hi)
        encoder.encode(lo)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.hi = try decoder.decode()
        self.lo = try decoder.decode()
    }
}

public struct StellarInt128: XDRCodable, Sendable, Hashable {
    public let hi: Int64
    public let lo: UInt64

    public init(hi: Int64, lo: UInt64) {
        self.hi = hi
        self.lo = lo
    }

    public init(_ value: Int64) {
        self.hi = value < 0 ? -1 : 0
        self.lo = UInt64(bitPattern: value)
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(hi)
        encoder.encode(lo)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.hi = try decoder.decode()
        self.lo = try decoder.decode()
    }
}

public struct ExtensionPoint: XDRCodable, Sendable, Hashable {
    public init() {}

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(Int32(0))
    }

    public init(from decoder: inout XDRDecoder) throws {
        let value: Int32 = try decoder.decode()
        guard value == 0 else {
            throw XDRDecodingError.invalidDiscriminant(type: "ExtensionPoint", value: value)
        }
    }
}

public enum EnvelopeType: Int32, Sendable, Hashable {
    case txV0 = 0
    case scp = 1
    case tx = 2
    case auth = 3
    case scpValue = 4
    case txFeeBump = 5
    case opId = 6
    case poolRevokeOpId = 7
    case contractId = 8
    case sorobanAuthorization = 9
}

public enum CryptoKeyType: Int32, Sendable, Hashable {
    case ed25519 = 0
    case preAuthTx = 1
    case hashX = 2
    case ed25519SignedPayload = 3
    case muxedEd25519 = 0x100
}

public enum SignerKey: XDRCodable, Sendable, Hashable {
    case ed25519(UInt256)
    case preAuthTx(UInt256)
    case hashX(UInt256)
    case ed25519SignedPayload(ed25519: UInt256, payload: Data)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .ed25519(let key):
            encoder.encode(CryptoKeyType.ed25519.rawValue)
            encoder.encode(key, fixed: 32)
        case .preAuthTx(let hash):
            encoder.encode(CryptoKeyType.preAuthTx.rawValue)
            encoder.encode(hash, fixed: 32)
        case .hashX(let hash):
            encoder.encode(CryptoKeyType.hashX.rawValue)
            encoder.encode(hash, fixed: 32)
        case .ed25519SignedPayload(let ed25519, let payload):
            encoder.encode(CryptoKeyType.ed25519SignedPayload.rawValue)
            encoder.encode(ed25519, fixed: 32)
            encoder.encode(payload)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let discriminant: Int32 = try decoder.decode()
        guard let keyType = CryptoKeyType(rawValue: discriminant) else {
            throw XDRDecodingError.invalidDiscriminant(type: "SignerKey", value: discriminant)
        }

        switch keyType {
        case .ed25519:
            self = .ed25519(try decoder.decode(fixed: 32))
        case .preAuthTx:
            self = .preAuthTx(try decoder.decode(fixed: 32))
        case .hashX:
            self = .hashX(try decoder.decode(fixed: 32))
        case .ed25519SignedPayload:
            let key: Data = try decoder.decode(fixed: 32)
            let payload: Data = try decoder.decode()
            self = .ed25519SignedPayload(ed25519: key, payload: payload)
        case .muxedEd25519:
            throw XDRDecodingError.invalidDiscriminant(type: "SignerKey", value: discriminant)
        }
    }
}

public enum XDRPublicKey: XDRCodable, Sendable, Hashable {
    case ed25519(UInt256)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .ed25519(let key):
            encoder.encode(Int32(0))
            encoder.encode(key, fixed: 32)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let discriminant: Int32 = try decoder.decode()
        guard discriminant == 0 else {
            throw XDRDecodingError.invalidDiscriminant(type: "XDRPublicKey", value: discriminant)
        }
        self = .ed25519(try decoder.decode(fixed: 32))
    }
}

public typealias AccountID = XDRPublicKey
public typealias PoolID = Hash

extension EnvelopeType: XDRCodable {
    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(rawValue)
    }

    public init(from decoder: inout XDRDecoder) throws {
        let raw: Int32 = try decoder.decode()
        guard let value = Self(rawValue: raw) else {
            throw XDRDecodingError.invalidDiscriminant(type: "EnvelopeType", value: raw)
        }
        self = value
    }
}

extension CryptoKeyType: XDRCodable {
    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(rawValue)
    }

    public init(from decoder: inout XDRDecoder) throws {
        let raw: Int32 = try decoder.decode()
        guard let value = Self(rawValue: raw) else {
            throw XDRDecodingError.invalidDiscriminant(type: "CryptoKeyType", value: raw)
        }
        self = value
    }
}
