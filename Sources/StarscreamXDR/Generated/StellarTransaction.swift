import Foundation

public enum MuxedAccount: XDRCodable, Sendable, Hashable {
    case ed25519(UInt256)
    case muxedEd25519(id: UInt64, ed25519: UInt256)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .ed25519(let key):
            encoder.encode(CryptoKeyType.ed25519.rawValue)
            encoder.encode(key, fixed: 32)
        case .muxedEd25519(let id, let key):
            encoder.encode(CryptoKeyType.muxedEd25519.rawValue)
            encoder.encode(id)
            encoder.encode(key, fixed: 32)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case CryptoKeyType.ed25519.rawValue:
            self = .ed25519(try decoder.decode(fixed: 32))
        case CryptoKeyType.muxedEd25519.rawValue:
            self = .muxedEd25519(id: try decoder.decodeX(), ed25519: try decoder.decode(fixed: 32))
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "MuxedAccount", value: disc)
        }
    }
}

public enum Memo: XDRCodable, Sendable, Hashable {
    case none
    case text(String)
    case id(UInt64)
    case hash(Hash)
    case returnHash(Hash)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .none:
            encoder.encode(Int32(0))
        case .text(let value):
            encoder.encode(Int32(1))
            encoder.encode(value)
        case .id(let value):
            encoder.encode(Int32(2))
            encoder.encode(value)
        case .hash(let value):
            encoder.encode(Int32(3))
            encoder.encode(value, fixed: 32)
        case .returnHash(let value):
            encoder.encode(Int32(4))
            encoder.encode(value, fixed: 32)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .none
        case 1: self = .text(try decoder.decodeX())
        case 2: self = .id(try decoder.decodeX())
        case 3: self = .hash(try decoder.decode(fixed: 32))
        case 4: self = .returnHash(try decoder.decode(fixed: 32))
        default: throw XDRDecodingError.invalidDiscriminant(type: "Memo", value: disc)
        }
    }
}

public struct TimeBounds: XDRCodable, Sendable, Hashable {
    public let minTime: UInt64
    public let maxTime: UInt64

    public init(minTime: UInt64, maxTime: UInt64) {
        self.minTime = minTime
        self.maxTime = maxTime
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(minTime)
        encoder.encode(maxTime)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.minTime = try decoder.decodeX()
        self.maxTime = try decoder.decodeX()
    }
}

public struct LedgerBounds: XDRCodable, Sendable, Hashable {
    public let minLedger: UInt32
    public let maxLedger: UInt32

    public init(minLedger: UInt32, maxLedger: UInt32) {
        self.minLedger = minLedger
        self.maxLedger = maxLedger
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(minLedger)
        encoder.encode(maxLedger)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.minLedger = try decoder.decodeX()
        self.maxLedger = try decoder.decodeX()
    }
}

public struct PreconditionsV2: XDRCodable, Sendable, Hashable {
    public let timeBounds: TimeBounds?
    public let ledgerBounds: LedgerBounds?
    public let minSeqNum: Int64?
    public let minSeqAge: UInt64
    public let minSeqLedgerGap: UInt32
    public let extraSigners: [SignerKey]

    public init(
        timeBounds: TimeBounds?,
        ledgerBounds: LedgerBounds?,
        minSeqNum: Int64?,
        minSeqAge: UInt64,
        minSeqLedgerGap: UInt32,
        extraSigners: [SignerKey]
    ) {
        self.timeBounds = timeBounds
        self.ledgerBounds = ledgerBounds
        self.minSeqNum = minSeqNum
        self.minSeqAge = minSeqAge
        self.minSeqLedgerGap = minSeqLedgerGap
        self.extraSigners = extraSigners
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try encoder.encode(timeBounds)
        try encoder.encode(ledgerBounds)
        try encoder.encode(minSeqNum)
        encoder.encode(minSeqAge)
        encoder.encode(minSeqLedgerGap)
        try encoder.encode(extraSigners)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.timeBounds = try decoder.decodeX()
        self.ledgerBounds = try decoder.decodeX()
        self.minSeqNum = try decoder.decodeX()
        self.minSeqAge = try decoder.decodeX()
        self.minSeqLedgerGap = try decoder.decodeX()
        self.extraSigners = try decoder.decodeX()
    }
}

public enum Preconditions: XDRCodable, Sendable, Hashable {
    case none
    case time(TimeBounds)
    case v2(PreconditionsV2)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .none:
            encoder.encode(Int32(0))
        case .time(let value):
            encoder.encode(Int32(1))
            try value.encode(to: &encoder)
        case .v2(let value):
            encoder.encode(Int32(2))
            try value.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .none
        case 1: self = .time(try decoder.decodeX())
        case 2: self = .v2(try decoder.decodeX())
        default: throw XDRDecodingError.invalidDiscriminant(type: "Preconditions", value: disc)
        }
    }
}

public enum OperationType: Int32, XDRCodable, Sendable, Hashable {
    case createAccount = 0
    case payment = 1
    case pathPaymentStrictReceive = 2
    case manageSellOffer = 3
    case createPassiveSellOffer = 4
    case setOptions = 5
    case changeTrust = 6
    case allowTrust = 7
    case accountMerge = 8
    case inflation = 9
    case manageData = 10
    case bumpSequence = 11
    case manageBuyOffer = 12
    case pathPaymentStrictSend = 13
    case createClaimableBalance = 14
    case claimClaimableBalance = 15
    case beginSponsoringFutureReserves = 16
    case endSponsoringFutureReserves = 17
    case revokeSponsorship = 18
    case clawback = 19
    case clawbackClaimableBalance = 20
    case setTrustLineFlags = 21
    case liquidityPoolDeposit = 22
    case liquidityPoolWithdraw = 23
    case invokeHostFunction = 24
    case extendFootprintTTL = 25
    case restoreFootprint = 26

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(rawValue)
    }

    public init(from decoder: inout XDRDecoder) throws {
        let raw: Int32 = try decoder.decodeX()
        guard let value = Self(rawValue: raw) else {
            throw XDRDecodingError.invalidDiscriminant(type: "OperationType", value: raw)
        }
        self = value
    }
}

public protocol EmptyOperationStub: XDRCodable, Sendable, Hashable {
    init()
}

public extension EmptyOperationStub {
    func encode(to encoder: inout XDREncoder) throws {}
    init(from decoder: inout XDRDecoder) throws { self.init() }
}

public struct CreateAccountOp: EmptyOperationStub { public init() {} }
public struct PaymentOp: EmptyOperationStub { public init() {} }
public struct PathPaymentStrictReceiveOp: EmptyOperationStub { public init() {} }
public struct ManageSellOfferOp: EmptyOperationStub { public init() {} }
public struct CreatePassiveSellOfferOp: EmptyOperationStub { public init() {} }
public struct SetOptionsOp: EmptyOperationStub { public init() {} }
public struct ChangeTrustOp: EmptyOperationStub { public init() {} }
public struct AllowTrustOp: EmptyOperationStub { public init() {} }
public struct ManageDataOp: EmptyOperationStub { public init() {} }
public struct BumpSequenceOp: EmptyOperationStub { public init() {} }
public struct ManageBuyOfferOp: EmptyOperationStub { public init() {} }
public struct PathPaymentStrictSendOp: EmptyOperationStub { public init() {} }
public struct CreateClaimableBalanceOp: EmptyOperationStub { public init() {} }
public struct ClaimClaimableBalanceOp: EmptyOperationStub { public init() {} }
public struct BeginSponsoringFutureReservesOp: EmptyOperationStub { public init() {} }
public struct RevokeSponsorshipOp: EmptyOperationStub { public init() {} }
public struct ClawbackOp: EmptyOperationStub { public init() {} }
public struct ClawbackClaimableBalanceOp: EmptyOperationStub { public init() {} }
public struct SetTrustLineFlagsOp: EmptyOperationStub { public init() {} }
public struct LiquidityPoolDepositOp: EmptyOperationStub { public init() {} }
public struct LiquidityPoolWithdrawOp: EmptyOperationStub { public init() {} }

public struct ExtendFootprintTTLOp: XDRCodable, Sendable, Hashable {
    public let ext: ExtensionPoint
    public let extendTo: UInt32

    public init(ext: ExtensionPoint, extendTo: UInt32) {
        self.ext = ext
        self.extendTo = extendTo
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try ext.encode(to: &encoder)
        encoder.encode(extendTo)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.ext = try decoder.decodeX()
        self.extendTo = try decoder.decodeX()
    }
}

public struct RestoreFootprintOp: XDRCodable, Sendable, Hashable {
    public let ext: ExtensionPoint

    public init(ext: ExtensionPoint) {
        self.ext = ext
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try ext.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.ext = try decoder.decodeX()
    }
}

public struct InvokeContractArgs: XDRCodable, Sendable, Hashable {
    public let contractAddress: SCAddress
    public let functionName: String
    public let args: [ScVal]

    public init(contractAddress: SCAddress, functionName: String, args: [ScVal]) {
        self.contractAddress = contractAddress
        self.functionName = functionName
        self.args = args
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try contractAddress.encode(to: &encoder)
        encoder.encode(functionName)
        try encoder.encode(args)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.contractAddress = try decoder.decodeX()
        self.functionName = try decoder.decodeX()
        self.args = try decoder.decodeX()
    }
}

public enum ContractExecutable: XDRCodable, Sendable, Hashable {
    case wasm(Hash)
    case stellarAsset

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .wasm(let hash):
            encoder.encode(Int32(0))
            encoder.encode(hash, fixed: 32)
        case .stellarAsset:
            encoder.encode(Int32(1))
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .wasm(try decoder.decode(fixed: 32))
        case 1: self = .stellarAsset
        default: throw XDRDecodingError.invalidDiscriminant(type: "ContractExecutable", value: disc)
        }
    }
}

public enum ContractIDPreimage: XDRCodable, Sendable, Hashable {
    case fromAddress(address: SCAddress, salt: UInt256)
    case fromAsset(Asset)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .fromAddress(let address, let salt):
            encoder.encode(Int32(0))
            try address.encode(to: &encoder)
            encoder.encode(salt, fixed: 32)
        case .fromAsset(let asset):
            encoder.encode(Int32(1))
            try asset.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0:
            self = .fromAddress(address: try decoder.decodeX(), salt: try decoder.decode(fixed: 32))
        case 1:
            self = .fromAsset(try decoder.decodeX())
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "ContractIDPreimage", value: disc)
        }
    }
}

public struct CreateContractArgs: XDRCodable, Sendable, Hashable {
    public let contractIDPreimage: ContractIDPreimage
    public let executable: ContractExecutable

    public init(contractIDPreimage: ContractIDPreimage, executable: ContractExecutable) {
        self.contractIDPreimage = contractIDPreimage
        self.executable = executable
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try contractIDPreimage.encode(to: &encoder)
        try executable.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.contractIDPreimage = try decoder.decodeX()
        self.executable = try decoder.decodeX()
    }
}

public struct CreateContractArgsV2: XDRCodable, Sendable, Hashable {
    public let contractIDPreimage: ContractIDPreimage
    public let executable: ContractExecutable
    public let constructorArgs: [ScVal]

    public init(contractIDPreimage: ContractIDPreimage, executable: ContractExecutable, constructorArgs: [ScVal]) {
        self.contractIDPreimage = contractIDPreimage
        self.executable = executable
        self.constructorArgs = constructorArgs
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try contractIDPreimage.encode(to: &encoder)
        try executable.encode(to: &encoder)
        try encoder.encode(constructorArgs)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.contractIDPreimage = try decoder.decodeX()
        self.executable = try decoder.decodeX()
        self.constructorArgs = try decoder.decodeX()
    }
}

public enum HostFunction: XDRCodable, Sendable, Hashable {
    case invokeContract(InvokeContractArgs)
    case createContract(CreateContractArgs)
    case uploadWasm(Data)
    case createContractV2(CreateContractArgsV2)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .invokeContract(let args):
            encoder.encode(Int32(0))
            try args.encode(to: &encoder)
        case .createContract(let args):
            encoder.encode(Int32(1))
            try args.encode(to: &encoder)
        case .uploadWasm(let wasm):
            encoder.encode(Int32(2))
            encoder.encode(wasm)
        case .createContractV2(let args):
            encoder.encode(Int32(3))
            try args.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .invokeContract(try decoder.decodeX())
        case 1: self = .createContract(try decoder.decodeX())
        case 2: self = .uploadWasm(try decoder.decodeX())
        case 3: self = .createContractV2(try decoder.decodeX())
        default: throw XDRDecodingError.invalidDiscriminant(type: "HostFunction", value: disc)
        }
    }
}

public enum SorobanAuthorizedFunction: XDRCodable, Sendable, Hashable {
    case contractFn(InvokeContractArgs)
    case createContractHostFn(CreateContractArgs)
    case createContractV2HostFn(CreateContractArgsV2)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .contractFn(let value):
            encoder.encode(Int32(0))
            try value.encode(to: &encoder)
        case .createContractHostFn(let value):
            encoder.encode(Int32(1))
            try value.encode(to: &encoder)
        case .createContractV2HostFn(let value):
            encoder.encode(Int32(2))
            try value.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .contractFn(try decoder.decodeX())
        case 1: self = .createContractHostFn(try decoder.decodeX())
        case 2: self = .createContractV2HostFn(try decoder.decodeX())
        default: throw XDRDecodingError.invalidDiscriminant(type: "SorobanAuthorizedFunction", value: disc)
        }
    }
}

public struct SorobanAuthorizedInvocation: XDRCodable, Sendable, Hashable {
    public let function: SorobanAuthorizedFunction
    public let subInvocations: [SorobanAuthorizedInvocation]

    public init(function: SorobanAuthorizedFunction, subInvocations: [SorobanAuthorizedInvocation]) {
        self.function = function
        self.subInvocations = subInvocations
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try function.encode(to: &encoder)
        try encoder.encode(subInvocations)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.function = try decoder.decodeX()
        self.subInvocations = try decoder.decodeX()
    }
}

public struct SorobanAddressCredentials: XDRCodable, Sendable, Hashable {
    public let address: SCAddress
    public let nonce: Int64
    // Mutable so authorizeEntry can set an updated expiration ledger before signing.
    public var signatureExpirationLedger: UInt32
    // Mutable so authorizeEntry can inject the final signature payload.
    public var signature: ScVal

    public init(address: SCAddress, nonce: Int64, signatureExpirationLedger: UInt32, signature: ScVal) {
        self.address = address
        self.nonce = nonce
        self.signatureExpirationLedger = signatureExpirationLedger
        self.signature = signature
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try address.encode(to: &encoder)
        encoder.encode(nonce)
        encoder.encode(signatureExpirationLedger)
        try signature.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.address = try decoder.decodeX()
        self.nonce = try decoder.decodeX()
        self.signatureExpirationLedger = try decoder.decodeX()
        self.signature = try decoder.decodeX()
    }
}

public enum SorobanCredentials: XDRCodable, Sendable, Hashable {
    case sourceAccount
    case address(SorobanAddressCredentials)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .sourceAccount:
            encoder.encode(Int32(0))
        case .address(let creds):
            encoder.encode(Int32(1))
            try creds.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .sourceAccount
        case 1: self = .address(try decoder.decodeX())
        default: throw XDRDecodingError.invalidDiscriminant(type: "SorobanCredentials", value: disc)
        }
    }
}

public struct SorobanAuthorizationEntry: XDRCodable, Sendable, Hashable {
    public let credentials: SorobanCredentials
    public let rootInvocation: SorobanAuthorizedInvocation

    public init(credentials: SorobanCredentials, rootInvocation: SorobanAuthorizedInvocation) {
        self.credentials = credentials
        self.rootInvocation = rootInvocation
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try credentials.encode(to: &encoder)
        try rootInvocation.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.credentials = try decoder.decodeX()
        self.rootInvocation = try decoder.decodeX()
    }
}

public struct InvokeHostFunctionOp: XDRCodable, Sendable, Hashable {
    public let hostFunction: HostFunction
    // Mutable because simulation returns auth entries after the function is built.
    public var auth: [SorobanAuthorizationEntry]

    public init(hostFunction: HostFunction, auth: [SorobanAuthorizationEntry]) {
        self.hostFunction = hostFunction
        self.auth = auth
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try hostFunction.encode(to: &encoder)
        try encoder.encode(auth)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.hostFunction = try decoder.decodeX()
        self.auth = try decoder.decodeX()
    }
}

public struct LedgerFootprint: XDRCodable, Sendable, Hashable {
    public let readOnly: [LedgerKey]
    public let readWrite: [LedgerKey]

    public init(readOnly: [LedgerKey], readWrite: [LedgerKey]) {
        self.readOnly = readOnly
        self.readWrite = readWrite
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try encoder.encode(readOnly)
        try encoder.encode(readWrite)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.readOnly = try decoder.decodeX()
        self.readWrite = try decoder.decodeX()
    }
}

public struct SorobanResources: XDRCodable, Sendable, Hashable {
    public let footprint: LedgerFootprint
    public let instructions: UInt32
    public let readBytes: UInt32
    public let writeBytes: UInt32

    public init(footprint: LedgerFootprint, instructions: UInt32, readBytes: UInt32, writeBytes: UInt32) {
        self.footprint = footprint
        self.instructions = instructions
        self.readBytes = readBytes
        self.writeBytes = writeBytes
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try footprint.encode(to: &encoder)
        encoder.encode(instructions)
        encoder.encode(readBytes)
        encoder.encode(writeBytes)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.footprint = try decoder.decodeX()
        self.instructions = try decoder.decodeX()
        self.readBytes = try decoder.decodeX()
        self.writeBytes = try decoder.decodeX()
    }
}

public struct SorobanTransactionData: XDRCodable, Sendable, Hashable {
    public let ext: ExtensionPoint
    public let resources: SorobanResources
    public let resourceFee: Int64

    public init(ext: ExtensionPoint, resources: SorobanResources, resourceFee: Int64) {
        self.ext = ext
        self.resources = resources
        self.resourceFee = resourceFee
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try ext.encode(to: &encoder)
        try resources.encode(to: &encoder)
        encoder.encode(resourceFee)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.ext = try decoder.decodeX()
        self.resources = try decoder.decodeX()
        self.resourceFee = try decoder.decodeX()
    }
}

public enum OperationBody: XDRCodable, Sendable, Hashable {
    case createAccount(CreateAccountOp)
    case payment(PaymentOp)
    case pathPaymentStrictReceive(PathPaymentStrictReceiveOp)
    case manageSellOffer(ManageSellOfferOp)
    case createPassiveSellOffer(CreatePassiveSellOfferOp)
    case setOptions(SetOptionsOp)
    case changeTrust(ChangeTrustOp)
    case allowTrust(AllowTrustOp)
    case accountMerge(MuxedAccount)
    case inflation
    case manageData(ManageDataOp)
    case bumpSequence(BumpSequenceOp)
    case manageBuyOffer(ManageBuyOfferOp)
    case pathPaymentStrictSend(PathPaymentStrictSendOp)
    case createClaimableBalance(CreateClaimableBalanceOp)
    case claimClaimableBalance(ClaimClaimableBalanceOp)
    case beginSponsoringFutureReserves(BeginSponsoringFutureReservesOp)
    case endSponsoringFutureReserves
    case revokeSponsorship(RevokeSponsorshipOp)
    case clawback(ClawbackOp)
    case clawbackClaimableBalance(ClawbackClaimableBalanceOp)
    case setTrustLineFlags(SetTrustLineFlagsOp)
    case liquidityPoolDeposit(LiquidityPoolDepositOp)
    case liquidityPoolWithdraw(LiquidityPoolWithdrawOp)
    case invokeHostFunction(InvokeHostFunctionOp)
    case extendFootprintTTL(ExtendFootprintTTLOp)
    case restoreFootprint(RestoreFootprintOp)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .createAccount(let value):
            encoder.encode(OperationType.createAccount.rawValue)
            try value.encode(to: &encoder)
        case .payment(let value):
            encoder.encode(OperationType.payment.rawValue)
            try value.encode(to: &encoder)
        case .pathPaymentStrictReceive(let value):
            encoder.encode(OperationType.pathPaymentStrictReceive.rawValue)
            try value.encode(to: &encoder)
        case .manageSellOffer(let value):
            encoder.encode(OperationType.manageSellOffer.rawValue)
            try value.encode(to: &encoder)
        case .createPassiveSellOffer(let value):
            encoder.encode(OperationType.createPassiveSellOffer.rawValue)
            try value.encode(to: &encoder)
        case .setOptions(let value):
            encoder.encode(OperationType.setOptions.rawValue)
            try value.encode(to: &encoder)
        case .changeTrust(let value):
            encoder.encode(OperationType.changeTrust.rawValue)
            try value.encode(to: &encoder)
        case .allowTrust(let value):
            encoder.encode(OperationType.allowTrust.rawValue)
            try value.encode(to: &encoder)
        case .accountMerge(let value):
            encoder.encode(OperationType.accountMerge.rawValue)
            try value.encode(to: &encoder)
        case .inflation:
            encoder.encode(OperationType.inflation.rawValue)
        case .manageData(let value):
            encoder.encode(OperationType.manageData.rawValue)
            try value.encode(to: &encoder)
        case .bumpSequence(let value):
            encoder.encode(OperationType.bumpSequence.rawValue)
            try value.encode(to: &encoder)
        case .manageBuyOffer(let value):
            encoder.encode(OperationType.manageBuyOffer.rawValue)
            try value.encode(to: &encoder)
        case .pathPaymentStrictSend(let value):
            encoder.encode(OperationType.pathPaymentStrictSend.rawValue)
            try value.encode(to: &encoder)
        case .createClaimableBalance(let value):
            encoder.encode(OperationType.createClaimableBalance.rawValue)
            try value.encode(to: &encoder)
        case .claimClaimableBalance(let value):
            encoder.encode(OperationType.claimClaimableBalance.rawValue)
            try value.encode(to: &encoder)
        case .beginSponsoringFutureReserves(let value):
            encoder.encode(OperationType.beginSponsoringFutureReserves.rawValue)
            try value.encode(to: &encoder)
        case .endSponsoringFutureReserves:
            encoder.encode(OperationType.endSponsoringFutureReserves.rawValue)
        case .revokeSponsorship(let value):
            encoder.encode(OperationType.revokeSponsorship.rawValue)
            try value.encode(to: &encoder)
        case .clawback(let value):
            encoder.encode(OperationType.clawback.rawValue)
            try value.encode(to: &encoder)
        case .clawbackClaimableBalance(let value):
            encoder.encode(OperationType.clawbackClaimableBalance.rawValue)
            try value.encode(to: &encoder)
        case .setTrustLineFlags(let value):
            encoder.encode(OperationType.setTrustLineFlags.rawValue)
            try value.encode(to: &encoder)
        case .liquidityPoolDeposit(let value):
            encoder.encode(OperationType.liquidityPoolDeposit.rawValue)
            try value.encode(to: &encoder)
        case .liquidityPoolWithdraw(let value):
            encoder.encode(OperationType.liquidityPoolWithdraw.rawValue)
            try value.encode(to: &encoder)
        case .invokeHostFunction(let value):
            encoder.encode(OperationType.invokeHostFunction.rawValue)
            try value.encode(to: &encoder)
        case .extendFootprintTTL(let value):
            encoder.encode(OperationType.extendFootprintTTL.rawValue)
            try value.encode(to: &encoder)
        case .restoreFootprint(let value):
            encoder.encode(OperationType.restoreFootprint.rawValue)
            try value.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let raw: Int32 = try decoder.decodeX()
        guard let operationType = OperationType(rawValue: raw) else {
            throw XDRDecodingError.invalidDiscriminant(type: "OperationBody", value: raw)
        }

        switch operationType {
        case .createAccount: self = .createAccount(try decoder.decodeX())
        case .payment: self = .payment(try decoder.decodeX())
        case .pathPaymentStrictReceive: self = .pathPaymentStrictReceive(try decoder.decodeX())
        case .manageSellOffer: self = .manageSellOffer(try decoder.decodeX())
        case .createPassiveSellOffer: self = .createPassiveSellOffer(try decoder.decodeX())
        case .setOptions: self = .setOptions(try decoder.decodeX())
        case .changeTrust: self = .changeTrust(try decoder.decodeX())
        case .allowTrust: self = .allowTrust(try decoder.decodeX())
        case .accountMerge: self = .accountMerge(try decoder.decodeX())
        case .inflation: self = .inflation
        case .manageData: self = .manageData(try decoder.decodeX())
        case .bumpSequence: self = .bumpSequence(try decoder.decodeX())
        case .manageBuyOffer: self = .manageBuyOffer(try decoder.decodeX())
        case .pathPaymentStrictSend: self = .pathPaymentStrictSend(try decoder.decodeX())
        case .createClaimableBalance: self = .createClaimableBalance(try decoder.decodeX())
        case .claimClaimableBalance: self = .claimClaimableBalance(try decoder.decodeX())
        case .beginSponsoringFutureReserves: self = .beginSponsoringFutureReserves(try decoder.decodeX())
        case .endSponsoringFutureReserves: self = .endSponsoringFutureReserves
        case .revokeSponsorship: self = .revokeSponsorship(try decoder.decodeX())
        case .clawback: self = .clawback(try decoder.decodeX())
        case .clawbackClaimableBalance: self = .clawbackClaimableBalance(try decoder.decodeX())
        case .setTrustLineFlags: self = .setTrustLineFlags(try decoder.decodeX())
        case .liquidityPoolDeposit: self = .liquidityPoolDeposit(try decoder.decodeX())
        case .liquidityPoolWithdraw: self = .liquidityPoolWithdraw(try decoder.decodeX())
        case .invokeHostFunction: self = .invokeHostFunction(try decoder.decodeX())
        case .extendFootprintTTL: self = .extendFootprintTTL(try decoder.decodeX())
        case .restoreFootprint: self = .restoreFootprint(try decoder.decodeX())
        }
    }
}

public struct Operation: XDRCodable, Sendable, Hashable {
    public let sourceAccount: MuxedAccount?
    // Mutable so assembly can replace invokeHostFunction bodies with populated auth.
    public var body: OperationBody

    public init(sourceAccount: MuxedAccount? = nil, body: OperationBody) {
        self.sourceAccount = sourceAccount
        self.body = body
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try encoder.encode(sourceAccount)
        try body.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.sourceAccount = try decoder.decodeX()
        self.body = try decoder.decodeX()
    }
}

public enum TransactionExtension: XDRCodable, Sendable, Hashable {
    case v0
    case v1(SorobanTransactionData)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .v0:
            encoder.encode(Int32(0))
        case .v1(let data):
            encoder.encode(Int32(1))
            try data.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case 0: self = .v0
        case 1: self = .v1(try decoder.decodeX())
        default: throw XDRDecodingError.invalidDiscriminant(type: "TransactionExtension", value: disc)
        }
    }
}

public struct Transaction: XDRCodable, Sendable, Hashable {
    public let sourceAccount: MuxedAccount
    // Mutable so assembleTransaction can add Soroban resource fees to the base fee.
    public var fee: UInt32
    public let seqNum: Int64
    public let cond: Preconditions
    public let memo: Memo
    // Mutable so assembled auth entries can be merged into operation payloads.
    public var operations: [Operation]
    // Mutable so assembly can switch ext from v0 to v1(SorobanTransactionData).
    public var ext: TransactionExtension

    public init(
        sourceAccount: MuxedAccount,
        fee: UInt32,
        seqNum: Int64,
        cond: Preconditions,
        memo: Memo,
        operations: [Operation],
        ext: TransactionExtension
    ) {
        self.sourceAccount = sourceAccount
        self.fee = fee
        self.seqNum = seqNum
        self.cond = cond
        self.memo = memo
        self.operations = operations
        self.ext = ext
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try sourceAccount.encode(to: &encoder)
        encoder.encode(fee)
        encoder.encode(seqNum)
        try cond.encode(to: &encoder)
        try memo.encode(to: &encoder)
        try encoder.encode(operations)
        try ext.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.sourceAccount = try decoder.decodeX()
        self.fee = try decoder.decodeX()
        self.seqNum = try decoder.decodeX()
        self.cond = try decoder.decodeX()
        self.memo = try decoder.decodeX()
        self.operations = try decoder.decodeX()
        self.ext = try decoder.decodeX()
    }
}

public struct DecoratedSignature: XDRCodable, Sendable, Hashable {
    public let hint: Data
    public let signature: Data

    public init(hint: Data, signature: Data) {
        self.hint = hint
        self.signature = signature
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(hint, fixed: 4)
        encoder.encode(signature)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.hint = try decoder.decode(fixed: 4)
        self.signature = try decoder.decodeX()
    }
}

public struct TransactionV1Envelope: XDRCodable, Sendable, Hashable {
    public let tx: Transaction
    // Mutable so additional signatures can be appended during multi-sign workflows.
    public var signatures: [DecoratedSignature]

    public init(tx: Transaction, signatures: [DecoratedSignature]) {
        self.tx = tx
        self.signatures = signatures
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try tx.encode(to: &encoder)
        try encoder.encode(signatures)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.tx = try decoder.decodeX()
        self.signatures = try decoder.decodeX()
    }
}

public struct TransactionV0Envelope: XDRCodable, Sendable, Hashable {
    public let tx: Transaction
    public let signatures: [DecoratedSignature]

    public init(tx: Transaction, signatures: [DecoratedSignature]) {
        self.tx = tx
        self.signatures = signatures
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try tx.encode(to: &encoder)
        try encoder.encode(signatures)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.tx = try decoder.decodeX()
        self.signatures = try decoder.decodeX()
    }
}

public struct FeeBumpTransactionEnvelope: XDRCodable, Sendable, Hashable {
    public let tx: Transaction
    public let signatures: [DecoratedSignature]

    public init(tx: Transaction, signatures: [DecoratedSignature]) {
        self.tx = tx
        self.signatures = signatures
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try tx.encode(to: &encoder)
        try encoder.encode(signatures)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.tx = try decoder.decodeX()
        self.signatures = try decoder.decodeX()
    }
}

public enum TransactionEnvelope: XDRCodable, Sendable, Hashable {
    case v0(TransactionV0Envelope)
    case v1(TransactionV1Envelope)
    case feeBump(FeeBumpTransactionEnvelope)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .v0(let value):
            encoder.encode(EnvelopeType.txV0.rawValue)
            try value.encode(to: &encoder)
        case .v1(let value):
            encoder.encode(EnvelopeType.tx.rawValue)
            try value.encode(to: &encoder)
        case .feeBump(let value):
            encoder.encode(EnvelopeType.txFeeBump.rawValue)
            try value.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case EnvelopeType.txV0.rawValue: self = .v0(try decoder.decodeX())
        case EnvelopeType.tx.rawValue: self = .v1(try decoder.decodeX())
        case EnvelopeType.txFeeBump.rawValue: self = .feeBump(try decoder.decodeX())
        default: throw XDRDecodingError.invalidDiscriminant(type: "TransactionEnvelope", value: disc)
        }
    }
}

public struct TransactionSignaturePayload: XDRCodable, Sendable, Hashable {
    public let networkId: Hash
    public let taggedTransaction: TaggedTransaction

    public init(networkId: Hash, taggedTransaction: TaggedTransaction) {
        self.networkId = networkId
        self.taggedTransaction = taggedTransaction
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(networkId, fixed: 32)
        try taggedTransaction.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.networkId = try decoder.decode(fixed: 32)
        self.taggedTransaction = try decoder.decodeX()
    }

    public enum TaggedTransaction: XDRCodable, Sendable, Hashable {
        case v0(TransactionV0Envelope)
        case v1(Transaction)
        case feeBump(FeeBumpTransactionEnvelope)

        public func encode(to encoder: inout XDREncoder) throws {
            switch self {
            case .v0(let tx):
                encoder.encode(EnvelopeType.txV0.rawValue)
                try tx.encode(to: &encoder)
            case .v1(let tx):
                encoder.encode(EnvelopeType.tx.rawValue)
                try tx.encode(to: &encoder)
            case .feeBump(let tx):
                encoder.encode(EnvelopeType.txFeeBump.rawValue)
                try tx.encode(to: &encoder)
            }
        }

        public init(from decoder: inout XDRDecoder) throws {
            let disc: Int32 = try decoder.decodeX()
            switch disc {
            case EnvelopeType.txV0.rawValue: self = .v0(try decoder.decodeX())
            case EnvelopeType.tx.rawValue: self = .v1(try decoder.decodeX())
            case EnvelopeType.txFeeBump.rawValue: self = .feeBump(try decoder.decodeX())
            default: throw XDRDecodingError.invalidDiscriminant(type: "TransactionSignaturePayload.TaggedTransaction", value: disc)
            }
        }
    }
}

public struct HashIDPreimageSorobanAuthorization: XDRCodable, Sendable, Hashable {
    public let networkID: Hash
    public let nonce: Int64
    public let signatureExpirationLedger: UInt32
    public let invocation: SorobanAuthorizedInvocation

    public init(networkID: Hash, nonce: Int64, signatureExpirationLedger: UInt32, invocation: SorobanAuthorizedInvocation) {
        self.networkID = networkID
        self.nonce = nonce
        self.signatureExpirationLedger = signatureExpirationLedger
        self.invocation = invocation
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(networkID, fixed: 32)
        encoder.encode(nonce)
        encoder.encode(signatureExpirationLedger)
        try invocation.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.networkID = try decoder.decode(fixed: 32)
        self.nonce = try decoder.decodeX()
        self.signatureExpirationLedger = try decoder.decodeX()
        self.invocation = try decoder.decodeX()
    }
}

public enum HashIDPreimage: XDRCodable, Sendable, Hashable {
    case operationID(sourceAccount: MuxedAccount, seqNum: Int64, opNum: UInt32)
    case poolRevokeOpID(sourceAccount: MuxedAccount, seqNum: Int64, opNum: UInt32, liquidityPoolID: Hash, asset: Asset)
    case contractID(networkID: Hash, contractIDPreimage: ContractIDPreimage)
    case sorobanAuthorization(HashIDPreimageSorobanAuthorization)

    public func encode(to encoder: inout XDREncoder) throws {
        switch self {
        case .operationID(let sourceAccount, let seqNum, let opNum):
            encoder.encode(EnvelopeType.opId.rawValue)
            try sourceAccount.encode(to: &encoder)
            encoder.encode(seqNum)
            encoder.encode(opNum)
        case .poolRevokeOpID(let sourceAccount, let seqNum, let opNum, let liquidityPoolID, let asset):
            encoder.encode(EnvelopeType.poolRevokeOpId.rawValue)
            try sourceAccount.encode(to: &encoder)
            encoder.encode(seqNum)
            encoder.encode(opNum)
            encoder.encode(liquidityPoolID, fixed: 32)
            try asset.encode(to: &encoder)
        case .contractID(let networkID, let contractIDPreimage):
            encoder.encode(EnvelopeType.contractId.rawValue)
            encoder.encode(networkID, fixed: 32)
            try contractIDPreimage.encode(to: &encoder)
        case .sorobanAuthorization(let authorization):
            encoder.encode(EnvelopeType.sorobanAuthorization.rawValue)
            try authorization.encode(to: &encoder)
        }
    }

    public init(from decoder: inout XDRDecoder) throws {
        let disc: Int32 = try decoder.decodeX()
        switch disc {
        case EnvelopeType.opId.rawValue:
            self = .operationID(sourceAccount: try decoder.decodeX(), seqNum: try decoder.decodeX(), opNum: try decoder.decodeX())
        case EnvelopeType.poolRevokeOpId.rawValue:
            self = .poolRevokeOpID(
                sourceAccount: try decoder.decodeX(),
                seqNum: try decoder.decodeX(),
                opNum: try decoder.decodeX(),
                liquidityPoolID: try decoder.decode(fixed: 32),
                asset: try decoder.decodeX()
            )
        case EnvelopeType.contractId.rawValue:
            self = .contractID(networkID: try decoder.decode(fixed: 32), contractIDPreimage: try decoder.decodeX())
        case EnvelopeType.sorobanAuthorization.rawValue:
            self = .sorobanAuthorization(try decoder.decodeX())
        default:
            throw XDRDecodingError.invalidDiscriminant(type: "HashIDPreimage", value: disc)
        }
    }
}
