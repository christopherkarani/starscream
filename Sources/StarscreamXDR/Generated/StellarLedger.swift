import Foundation

public enum ContractEventType: Int32, XDRCodable, Sendable, Hashable {
    case system = 0
    case contract = 1
    case diagnostic = 2

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(rawValue)
    }

    public init(from decoder: inout XDRDecoder) throws {
        let raw: Int32 = try decoder.decodeX()
        guard let value = Self(rawValue: raw) else {
            throw XDRDecodingError.invalidDiscriminant(type: "ContractEventType", value: raw)
        }
        self = value
    }
}

public struct ContractEvent: XDRCodable, Sendable, Hashable {
    public let ext: ExtensionPoint
    public let contractID: Hash?
    public let type: ContractEventType
    public let topics: [ScVal]
    public let data: ScVal

    public init(ext: ExtensionPoint, contractID: Hash?, type: ContractEventType, topics: [ScVal], data: ScVal) {
        self.ext = ext
        self.contractID = contractID
        self.type = type
        self.topics = topics
        self.data = data
    }

    public func encode(to encoder: inout XDREncoder) throws {
        try ext.encode(to: &encoder)
        try encoder.encode(contractID)
        try type.encode(to: &encoder)
        try encoder.encode(topics)
        try data.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.ext = try decoder.decodeX()
        self.contractID = try decoder.decodeX()
        self.type = try decoder.decodeX()
        self.topics = try decoder.decodeX()
        self.data = try decoder.decodeX()
    }
}

public struct DiagnosticEvent: XDRCodable, Sendable, Hashable {
    public let inSuccessfulContractCall: Bool
    public let event: ContractEvent

    public init(inSuccessfulContractCall: Bool, event: ContractEvent) {
        self.inSuccessfulContractCall = inSuccessfulContractCall
        self.event = event
    }

    public func encode(to encoder: inout XDREncoder) throws {
        encoder.encode(inSuccessfulContractCall)
        try event.encode(to: &encoder)
    }

    public init(from decoder: inout XDRDecoder) throws {
        self.inSuccessfulContractCall = try decoder.decodeX()
        self.event = try decoder.decodeX()
    }
}
