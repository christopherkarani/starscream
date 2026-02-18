import Foundation

public enum ContractDataDurability: Int32, XDRCodable, Sendable, Hashable {
    case temporary = 0
    case persistent = 1

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(rawValue)
    }

    public init(from decoder: inout XDRDecoder) throws {
        let raw: Int32 = try decoder.decodeX()
        guard let value = Self(rawValue: raw) else {
            throw XDRDecodingError.invalidDiscriminant(type: "ContractDataDurability", value: raw)
        }
        self = value
    }
}

public struct AlphaNum4: XDRCodable, Sendable, Hashable {
    public let assetCode: Data
    public let issuer: AccountID

    public init(assetCode: Data, issuer: AccountID) {
        self.assetCode = assetCode
        self.issuer = issuer
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(assetCode, fixed: 4)
        try issuer.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.assetCode = try decoder.decode(fixed: 4)
        self.issuer = try decoder.decodeX()
    }
}

public struct AlphaNum12: XDRCodable, Sendable, Hashable {
    public let assetCode: Data
    public let issuer: AccountID

    public init(assetCode: Data, issuer: AccountID) {
        self.assetCode = assetCode
        self.issuer = issuer
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(assetCode, fixed: 12)
        try issuer.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.assetCode = try decoder.decode(fixed: 12)
        self.issuer = try decoder.decodeX()
    }
}

public enum Asset: XDRCodable, Sendable, Hashable {
    case native
    case creditAlphanum4(AlphaNum4)
    case creditAlphanum12(AlphaNum12)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .native:
            encoder.encode(Int32(0))
        case .creditAlphanum4(let value):
            encoder.encode(Int32(1))
            try value.encode(to: &encoder)
        case .creditAlphanum12(let value):
            encoder.encode(Int32(2))
            try value.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .native
        case 1: self = .creditAlphanum4(try decoder.decodeX())
        case 2: self = .creditAlphanum12(try decoder.decodeX())
        default: throw XDRDecodingError.invalidDiscriminant(type: "Asset", value: disc)
        }
    }
}

public enum TrustLineAsset: XDRCodable, Sendable, Hashable {
    case native
    case creditAlphanum4(AlphaNum4)
    case creditAlphanum12(AlphaNum12)
    case poolShare(PoolID)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .native:
            encoder.encode(Int32(0))
        case .creditAlphanum4(let value):
            encoder.encode(Int32(1))
            try value.encode(to: &encoder)
        case .creditAlphanum12(let value):
            encoder.encode(Int32(2))
            try value.encode(to: &encoder)
        case .poolShare(let pool):
            encoder.encode(Int32(3))
            encoder.encode(pool, fixed: 32)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .native
        case 1: self = .creditAlphanum4(try decoder.decodeX())
        case 2: self = .creditAlphanum12(try decoder.decodeX())
        case 3: self = .poolShare(try decoder.decode(fixed: 32))
        default: throw XDRDecodingError.invalidDiscriminant(type: "TrustLineAsset", value: disc)
        }
    }
}

public enum LedgerKey: XDRCodable, Sendable, Hashable {
    case account(AccountID)
    case trustline(AccountID)
    case offer(Int64)
    case data(AccountID, String)
    case claimableBalance(ClaimableBalanceID)
    case liquidityPool(PoolID)
    case contractData(contract: Hash, key: ScVal, durability: ContractDataDurability)
    case contractCode(Hash)
    case configSetting(Int32)
    case ttl(Hash)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .account(let account):
            encoder.encode(Int32(0))
            try account.encode(to: &encoder)
        case .trustline(let account):
            encoder.encode(Int32(1))
            try account.encode(to: &encoder)
        case .offer(let offerId):
            encoder.encode(Int32(2))
            encoder.encode(offerId)
        case .data(let account, let key):
            encoder.encode(Int32(3))
            try account.encode(to: &encoder)
            encoder.encode(key)
        case .claimableBalance(let balance):
            encoder.encode(Int32(4))
            try balance.encode(to: &encoder)
        case .liquidityPool(let pool):
            encoder.encode(Int32(5))
            encoder.encode(pool, fixed: 32)
        case .contractData(let contract, let key, let durability):
            encoder.encode(Int32(6))
            encoder.encode(contract, fixed: 32)
            try key.encode(to: &encoder)
            try durability.encode(to: &encoder)
        case .contractCode(let hash):
            encoder.encode(Int32(7))
            encoder.encode(hash, fixed: 32)
        case .configSetting(let setting):
            encoder.encode(Int32(8))
            encoder.encode(setting)
        case .ttl(let hash):
            encoder.encode(Int32(9))
            encoder.encode(hash, fixed: 32)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .account(try decoder.decodeX())
        case 1: self = .trustline(try decoder.decodeX())
        case 2: self = .offer(try decoder.decodeX())
        case 3: self = .data(try decoder.decodeX(), try decoder.decodeX())
        case 4: self = .claimableBalance(try decoder.decodeX())
        case 5: self = .liquidityPool(try decoder.decode(fixed: 32))
        case 6:
            self = .contractData(
                contract: try decoder.decode(fixed: 32),
                key: try decoder.decodeX(),
                durability: try decoder.decodeX()
            )
        case 7: self = .contractCode(try decoder.decode(fixed: 32))
        case 8: self = .configSetting(try decoder.decodeX())
        case 9: self = .ttl(try decoder.decode(fixed: 32))
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "LedgerKey", value: disc)
        }
    }
}

public struct LedgerEntryExtensionV1: XDRCodable, Sendable, Hashable {
    public let sponsoringID: AccountID?

    public init(sponsoringID: AccountID?) {
        self.sponsoringID = sponsoringID
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try encoder.encode(sponsoringID)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.sponsoringID = try decoder.decodeX()
    }
}

public enum LedgerEntryExt: XDRCodable, Sendable, Hashable {
    case v0
    case v1(LedgerEntryExtensionV1)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .v0:
            encoder.encode(Int32(0))
        case .v1(let ext):
            encoder.encode(Int32(1))
            try ext.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .v0
        case 1: self = .v1(try decoder.decodeX())
        default: throw XDRDecodingError.invalidDiscriminant(type: "LedgerEntryExt", value: disc)
        }
    }
}

public struct Signer: XDRCodable, Sendable, Hashable {
    public let key: SignerKey
    public let weight: UInt32

    public init(key: SignerKey, weight: UInt32) {
        self.key = key
        self.weight = weight
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try key.encode(to: &encoder)
        encoder.encode(weight)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.key = try decoder.decodeX()
        self.weight = try decoder.decodeX()
    }
}

public struct AccountEntry: XDRCodable, Sendable, Hashable {
    public let accountID: AccountID
    public let balance: Int64
    public let seqNum: Int64
    public let numSubEntries: UInt32
    public let inflationDest: AccountID?
    public let flags: UInt32
    public let homeDomain: String
    public let thresholds: Data
    public let signers: [Signer]
    public let ext: ExtensionPoint

    public init(
        accountID: AccountID,
        balance: Int64,
        seqNum: Int64,
        numSubEntries: UInt32,
        inflationDest: AccountID?,
        flags: UInt32,
        homeDomain: String,
        thresholds: Data,
        signers: [Signer],
        ext: ExtensionPoint
    ) {
        self.accountID = accountID
        self.balance = balance
        self.seqNum = seqNum
        self.numSubEntries = numSubEntries
        self.inflationDest = inflationDest
        self.flags = flags
        self.homeDomain = homeDomain
        self.thresholds = thresholds
        self.signers = signers
        self.ext = ext
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try accountID.encode(to: &encoder)
        encoder.encode(balance)
        encoder.encode(seqNum)
        encoder.encode(numSubEntries)
        try encoder.encode(inflationDest)
        encoder.encode(flags)
        encoder.encode(homeDomain)
        encoder.encode(thresholds, fixed: 4)
        try encoder.encode(signers)
        try ext.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.accountID = try decoder.decodeX()
        self.balance = try decoder.decodeX()
        self.seqNum = try decoder.decodeX()
        self.numSubEntries = try decoder.decodeX()
        self.inflationDest = try decoder.decodeX()
        self.flags = try decoder.decodeX()
        self.homeDomain = try decoder.decodeX()
        self.thresholds = try decoder.decode(fixed: 4)
        self.signers = try decoder.decodeX()
        self.ext = try decoder.decodeX()
    }
}

public struct ContractDataEntry: XDRCodable, Sendable, Hashable {
    public let ext: ExtensionPoint
    public let contract: Hash
    public let key: ScVal
    public let durability: ContractDataDurability
    public let val: ScVal

    public init(ext: ExtensionPoint, contract: Hash, key: ScVal, durability: ContractDataDurability, val: ScVal) {
        self.ext = ext
        self.contract = contract
        self.key = key
        self.durability = durability
        self.val = val
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try ext.encode(to: &encoder)
        encoder.encode(contract, fixed: 32)
        try key.encode(to: &encoder)
        try durability.encode(to: &encoder)
        try val.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.ext = try decoder.decodeX()
        self.contract = try decoder.decode(fixed: 32)
        self.key = try decoder.decodeX()
        self.durability = try decoder.decodeX()
        self.val = try decoder.decodeX()
    }
}

public enum ContractCodeEntryExt: XDRCodable, Sendable, Hashable {
    case v0

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(Int32(0))
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        guard disc == 0 else {
            throw XDRDecodingError.invalidDiscriminant(type: "ContractCodeEntryExt", value: disc)
        }
        self = .v0
    }
}

public struct ContractCodeEntry: XDRCodable, Sendable, Hashable {
    public let ext: ContractCodeEntryExt
    public let hash: Hash
    public let code: Data

    public init(ext: ContractCodeEntryExt, hash: Hash, code: Data) {
        self.ext = ext
        self.hash = hash
        self.code = code
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try ext.encode(to: &encoder)
        encoder.encode(hash, fixed: 32)
        encoder.encode(code)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.ext = try decoder.decodeX()
        self.hash = try decoder.decode(fixed: 32)
        self.code = try decoder.decodeX()
    }
}

public struct TTLEntry: XDRCodable, Sendable, Hashable {
    public let keyHash: Hash
    public let liveUntilLedgerSeq: UInt32

    public init(keyHash: Hash, liveUntilLedgerSeq: UInt32) {
        self.keyHash = keyHash
        self.liveUntilLedgerSeq = liveUntilLedgerSeq
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(keyHash, fixed: 32)
        encoder.encode(liveUntilLedgerSeq)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.keyHash = try decoder.decode(fixed: 32)
        self.liveUntilLedgerSeq = try decoder.decodeX()
    }
}

public struct TrustLineEntry: XDRCodable, Sendable, Hashable {
    public init() {}
    public func encode(to encoder: inout XDREncoder) throws {}
    public init(from decoder: inout XDRDecoder) throws {}
}

public struct OfferEntry: XDRCodable, Sendable, Hashable {
    public init() {}
    public func encode(to encoder: inout XDREncoder) throws {}
    public init(from decoder: inout XDRDecoder) throws {}
}

public struct DataEntry: XDRCodable, Sendable, Hashable {
    public init() {}
    public func encode(to encoder: inout XDREncoder) throws {}
    public init(from decoder: inout XDRDecoder) throws {}
}

public struct ClaimableBalanceEntry: XDRCodable, Sendable, Hashable {
    public init() {}
    public func encode(to encoder: inout XDREncoder) throws {}
    public init(from decoder: inout XDRDecoder) throws {}
}

public struct LiquidityPoolEntry: XDRCodable, Sendable, Hashable {
    public init() {}
    public func encode(to encoder: inout XDREncoder) throws {}
    public init(from decoder: inout XDRDecoder) throws {}
}

public struct ConfigSettingEntry: XDRCodable, Sendable, Hashable {
    public init() {}
    public func encode(to encoder: inout XDREncoder) throws {}
    public init(from decoder: inout XDRDecoder) throws {}
}

public enum LedgerEntryData: XDRCodable, Sendable, Hashable {
    case account(AccountEntry)
    case trustline(TrustLineEntry)
    case offer(OfferEntry)
    case data(DataEntry)
    case claimableBalance(ClaimableBalanceEntry)
    case liquidityPool(LiquidityPoolEntry)
    case contractData(ContractDataEntry)
    case contractCode(ContractCodeEntry)
    case configSetting(ConfigSettingEntry)
    case ttl(TTLEntry)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .account(let entry):
            encoder.encode(Int32(0))
            try entry.encode(to: &encoder)
        case .trustline(let entry):
            encoder.encode(Int32(1))
            try entry.encode(to: &encoder)
        case .offer(let entry):
            encoder.encode(Int32(2))
            try entry.encode(to: &encoder)
        case .data(let entry):
            encoder.encode(Int32(3))
            try entry.encode(to: &encoder)
        case .claimableBalance(let entry):
            encoder.encode(Int32(4))
            try entry.encode(to: &encoder)
        case .liquidityPool(let entry):
            encoder.encode(Int32(5))
            try entry.encode(to: &encoder)
        case .contractData(let entry):
            encoder.encode(Int32(6))
            try entry.encode(to: &encoder)
        case .contractCode(let entry):
            encoder.encode(Int32(7))
            try entry.encode(to: &encoder)
        case .configSetting(let entry):
            encoder.encode(Int32(8))
            try entry.encode(to: &encoder)
        case .ttl(let entry):
            encoder.encode(Int32(9))
            try entry.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .account(try decoder.decodeX())
        case 1: self = .trustline(try decoder.decodeX())
        case 2: self = .offer(try decoder.decodeX())
        case 3: self = .data(try decoder.decodeX())
        case 4: self = .claimableBalance(try decoder.decodeX())
        case 5: self = .liquidityPool(try decoder.decodeX())
        case 6: self = .contractData(try decoder.decodeX())
        case 7: self = .contractCode(try decoder.decodeX())
        case 8: self = .configSetting(try decoder.decodeX())
        case 9: self = .ttl(try decoder.decodeX())
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "LedgerEntryData", value: disc)
        }
    }
}

public struct LedgerEntry: XDRCodable, Sendable, Hashable {
    public let lastModifiedLedgerSeq: UInt32
    public let data: LedgerEntryData
    public let ext: LedgerEntryExt

    public init(lastModifiedLedgerSeq: UInt32, data: LedgerEntryData, ext: LedgerEntryExt) {
        self.lastModifiedLedgerSeq = lastModifiedLedgerSeq
        self.data = data
        self.ext = ext
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(lastModifiedLedgerSeq)
        try data.encode(to: &encoder)
        try ext.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.lastModifiedLedgerSeq = try decoder.decodeX()
        self.data = try decoder.decodeX()
        self.ext = try decoder.decodeX()
    }
}
