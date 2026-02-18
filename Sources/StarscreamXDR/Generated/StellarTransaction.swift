import Foundation

public struct Transaction: XDRCodable, Sendable, Hashable {
    public init() {}

    public func encode(to encoder: inout XDREncoder) throws {}

    public init(from decoder: inout XDRDecoder) throws {}
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
        self.signature = try decoder.decode()
    }
}
