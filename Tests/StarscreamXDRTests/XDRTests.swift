import Testing
import Foundation
@testable import StarscreamXDR

@Test func xdr_streamA_primitivesRoundTrip() throws {
    try assertRoundTrip(Int32(-42))
    try assertRoundTrip(UInt32(42))
    try assertRoundTrip(Int64(-42_000_000_000))
    try assertRoundTrip(UInt64(42_000_000_000))
    try assertRoundTrip(true)
    try assertRoundTrip(false)
}

@Test func xdr_streamA_dataPaddingAndString() throws {
    let payload = Data([0x01, 0x02, 0x03])
    let xdr = try payload.toXDR()
    #expect(xdr.count == 8)
    #expect(xdr == Data([0, 0, 0, 3, 1, 2, 3, 0]))
    #expect(try Data(xdr: xdr) == payload)

    let string = "soroban"
    try assertRoundTrip(string)
}

@Test func xdr_streamA_arrayAndOptionalRoundTrip() throws {
    struct Int32List: XDRCodable, Sendable, Hashable {
        let values: [Int32]

        init(values: [Int32]) {
            self.values = values
        }

        func encode(to encoder: inout XDREncoder) throws {
            try encoder.encode(values)
        }

        init(from decoder: inout XDRDecoder) throws {
            self.values = try decoder.decodeX([Int32].self)
        }
    }

    struct OptionalInt32: XDRCodable, Sendable, Hashable {
        let value: Int32?

        init(value: Int32?) {
            self.value = value
        }

        func encode(to encoder: inout XDREncoder) throws {
            try encoder.encode(value)
        }

        init(from decoder: inout XDRDecoder) throws {
            self.value = try decoder.decodeX(Int32?.self)
        }
    }

    struct OptionalInt32List: XDRCodable, Sendable, Hashable {
        let value: [Int32]?

        init(value: [Int32]?) {
            self.value = value
        }

        func encode(to encoder: inout XDREncoder) throws {
            try encoder.encode(value)
        }

        init(from decoder: inout XDRDecoder) throws {
            self.value = try decoder.decodeX([Int32]?.self)
        }
    }

    try assertRoundTrip(Int32List(values: [1, 2, 3]))
    try assertRoundTrip(OptionalInt32(value: nil))
    try assertRoundTrip(OptionalInt32(value: 99))
    try assertRoundTrip(OptionalInt32List(value: nil))
    try assertRoundTrip(OptionalInt32List(value: [7, 8, 9]))
}

private func assertRoundTrip<T: XDRCodable & Equatable>(_ value: T) throws {
    let xdr = try value.toXDR()
    let decoded = try T(xdr: xdr)
    #expect(decoded == value)
}

@Test func strkey_streamB_roundTripAllVersionBytes() throws {
    let testVectors: [(StrKey.VersionByte, Data)] = [
        (.ed25519PublicKey, Data((0..<32).map(UInt8.init))),
        (.ed25519SecretSeed, Data((32..<64).map(UInt8.init))),
        (.preAuthTx, Data((64..<96).map(UInt8.init))),
        (.sha256Hash, Data((96..<128).map(UInt8.init))),
        (.muxedAccount, Data((0..<40).map(UInt8.init))),
        (.signedPayload, Data((10..<58).map(UInt8.init))),
        (.contract, Data((58..<90).map(UInt8.init))),
    ]

    for (version, payload) in testVectors {
        let encoded = StrKey.encode(payload, version: version)
        let decoded = try StrKey.decode(encoded)
        #expect(decoded.version == version)
        #expect(decoded.data == payload)
    }
}

@Test func strkey_streamB_crc16XmodemKnownVectorAndChecksumValidation() throws {
    let checksum = StrKey.crc16xmodem(Data("123456789".utf8))
    #expect(checksum == 0x31C3)

    let payload = Data((0..<32).map(UInt8.init))
    let valid = StrKey.encode(payload, version: .ed25519PublicKey)
    let broken = String(valid.dropLast()) + "A"
    do {
        _ = try StrKey.decode(broken)
        #expect(Bool(false), "Expected checksum validation failure")
    } catch {
        #expect(Bool(true))
    }
}

@Test func xdr_phase2_stellar128_roundTrip() throws {
    try assertRoundTrip(StellarUInt128(hi: 7, lo: 9))
    try assertRoundTrip(StellarInt128(hi: -1, lo: 42))
}

@Test func xdr_phase2_scval_roundTrip() throws {
    try assertRoundTrip(ScVal.u32(123))
    try assertRoundTrip(ScVal.string("hello"))
}

@Test func xdr_phase2_transaction_roundTrip() throws {
    let accountBytes = Data(repeating: 0x11, count: 32)
    let tx = Transaction(
        sourceAccount: .ed25519(accountBytes),
        fee: 100,
        seqNum: 1,
        cond: .none,
        memo: .none,
        operations: [
            Operation(sourceAccount: nil, body: .restoreFootprint(RestoreFootprintOp(ext: ExtensionPoint())))
        ],
        ext: .v0
    )

    try assertRoundTrip(tx)
}
