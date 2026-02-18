import Foundation
import StarscreamRPC
import StarscreamXDR

public enum StarscreamError: Error, Sendable {
    case rpcError(RPCError)
    case networkError(Error)
    case timeout(String)
    case accountNotFound(String)
    case contractNotFound(String)
    case friendbotNotAvailable

    case xdrError(XDRError)
    case cryptoError(CryptoError)

    case simulationFailed(error: String, events: [DiagnosticEvent])
    case transactionFailed(result: GetTransactionResponse, events: [DiagnosticEvent])
    case restoreRequired(preamble: RestorePreamble)
    case restoreFailed(String)
    case notYetSimulated
    case needsMoreSignatures([SCAddress])

    case resultDecodingFailed(expectedType: String, actualValue: ScVal)
    case invalidState(String)
    case invalidFormat(String)
}

public struct RPCError: Error, Sendable, Codable, Equatable, Hashable {
    public let code: Int
    public let message: String
    public let data: String?

    public init(code: Int, message: String, data: String? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public enum XDRError: Error, Sendable, Equatable, Hashable {
    case insufficientData(expected: Int, available: Int)
    case invalidDiscriminant(type: String, value: Int32)
    case invalidLength(expected: Int, actual: Int)
    case invalidPadding
    case trailingData(consumed: Int, total: Int)
    case invalidUTF8
}

public enum CryptoError: Error, Sendable, Equatable, Hashable {
    case invalidKeyLength(expected: Int, actual: Int)
    case signatureFailed
    case invalidSignature
    case checksumMismatch
    case invalidBase32
    case unknownVersionByte(UInt8)
}

extension StarscreamError {
    static func from(_ error: XDRDecodingError) -> StarscreamError {
        switch error {
        case .insufficientData(let expected, let available):
            return .xdrError(.insufficientData(expected: expected, available: available))
        case .invalidDiscriminant(let type, let value):
            return .xdrError(.invalidDiscriminant(type: type, value: value))
        case .invalidLength(let expected, let actual):
            return .xdrError(.invalidLength(expected: expected, actual: actual))
        case .invalidPadding:
            return .xdrError(.invalidPadding)
        case .trailingData(let consumed, let total):
            return .xdrError(.trailingData(consumed: consumed, total: total))
        case .invalidUTF8:
            return .xdrError(.invalidUTF8)
        }
    }

    static func from(_ error: StrKeyError) -> StarscreamError {
        switch error {
        case .invalidBase32:
            return .cryptoError(.invalidBase32)
        case .checksumMismatch:
            return .cryptoError(.checksumMismatch)
        case .invalidLength:
            return .invalidFormat("Invalid StrKey length")
        case .invalidPayloadLength(let expected, let actual):
            return .invalidFormat("Invalid StrKey payload length. expected=\(expected) actual=\(actual)")
        case .unknownVersionByte(let byte):
            return .cryptoError(.unknownVersionByte(byte))
        }
    }

    static func from(_ error: KeyPairError) -> StarscreamError {
        switch error {
        case .invalidKeyLength(let expected, let actual):
            return .cryptoError(.invalidKeyLength(expected: expected, actual: actual))
        case .invalidStrKeyVersion:
            return .invalidFormat("Invalid StrKey version")
        }
    }
}
