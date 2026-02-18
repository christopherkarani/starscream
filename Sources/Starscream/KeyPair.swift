import Crypto
import Foundation
import StarscreamXDR

public enum KeyPairError: Error, Sendable, Equatable {
    case invalidKeyLength(expected: Int, actual: Int)
    case invalidStrKeyVersion
}

public struct PublicKey: Sendable, Hashable {
    public let rawBytes: Data

    public init(rawBytes: Data) throws {
        guard rawBytes.count == 32 else {
            throw KeyPairError.invalidKeyLength(expected: 32, actual: rawBytes.count)
        }
        self.rawBytes = rawBytes
    }

    public init(strKey: String) throws {
        let (data, version) = try StrKey.decode(strKey)
        guard version == .ed25519PublicKey else {
            throw KeyPairError.invalidStrKeyVersion
        }
        try self.init(rawBytes: data)
    }

    public var stellarAddress: String {
        StrKey.encode(rawBytes, version: .ed25519PublicKey)
    }

    public func verify(signature: Data, for data: Data) -> Bool {
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: rawBytes) else {
            return false
        }
        return key.isValidSignature(signature, for: data)
    }
}

public struct KeyPair: Sendable {
    public let publicKey: PublicKey
    private let secretSeedBytes: Data

    public static func random() -> KeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        let raw = privateKey.rawRepresentation
        let publicKey = try! PublicKey(rawBytes: privateKey.publicKey.rawRepresentation)
        return KeyPair(publicKey: publicKey, secretSeedBytes: raw)
    }

    public init(secretSeed: String) throws {
        let (seed, version) = try StrKey.decode(secretSeed)
        guard version == .ed25519SecretSeed else {
            throw KeyPairError.invalidStrKeyVersion
        }
        guard seed.count == 32 else {
            throw KeyPairError.invalidKeyLength(expected: 32, actual: seed.count)
        }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        self.publicKey = try PublicKey(rawBytes: privateKey.publicKey.rawRepresentation)
        self.secretSeedBytes = seed
    }

    public func sign(_ data: Data) throws -> Data {
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: secretSeedBytes)
        return try privateKey.signature(for: data)
    }

    // TODO: Completed in Phase 2 when TransactionSignaturePayload is available.
    public func signTransaction(_ transaction: Transaction, networkPassphrase: String) throws -> DecoratedSignature {
        fatalError("Requires TransactionSignaturePayload from Phase 2")
    }

    private init(publicKey: PublicKey, secretSeedBytes: Data) {
        self.publicKey = publicKey
        self.secretSeedBytes = secretSeedBytes
    }
}
