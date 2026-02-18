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

@Test func xdr_phase5_dataPadding_lengths0To5() throws {
    for length in 0...5 {
        let payload = Data((0..<length).map { UInt8($0) })
        let xdr = try payload.toXDR()
        let expectedPadding = (4 - (length % 4)) % 4
        #expect(xdr.count == 4 + length + expectedPadding)
        #expect(try Data(xdr: xdr) == payload)
    }
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

private extension Data {
    init(hexEncoded: String) throws {
        let normalized = hexEncoded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count.isMultiple(of: 2) else {
            throw XDRDecodingError.invalidLength(expected: normalized.count + 1, actual: normalized.count)
        }

        var bytes = Data()
        bytes.reserveCapacity(normalized.count / 2)

        var index = normalized.startIndex
        while index < normalized.endIndex {
            let next = normalized.index(index, offsetBy: 2)
            let pair = normalized[index..<next]
            guard let value = UInt8(pair, radix: 16) else {
                throw XDRDecodingError.invalidLength(expected: 2, actual: pair.count)
            }
            bytes.append(value)
            index = next
        }

        self = bytes
    }

    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
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

@Test func xdr_phase5_scValRepresentativeRoundTrip() throws {
    try assertRoundTrip(ScVal.bool(true))
    try assertRoundTrip(ScVal.i64(-7))
    try assertRoundTrip(ScVal.bytes(Data([1, 2, 3, 4])))
    try assertRoundTrip(ScVal.symbol("sym"))
    try assertRoundTrip(ScVal.vec([.u32(1), .u32(2)]))
    try assertRoundTrip(
        ScVal.map([SCMapEntry(key: .string("k"), val: .i32(9))])
    )
}

@Test func xdr_phase5_scValAllCasesRoundTrip() throws {
    let hash = Data(repeating: 0xAB, count: 32)
    let nonceKey = SCNonceKey(nonce: 99)
    let values: [ScVal] = [
        .bool(true),
        .void,
        .error(.auth(.invalidAction)),
        .u32(1),
        .i32(-2),
        .u64(3),
        .i64(-4),
        .timepoint(5),
        .duration(6),
        .u128(.init(hi: 7, lo: 8)),
        .i128(.init(hi: -9, lo: 10)),
        .u256(Data(repeating: 0x01, count: 32)),
        .i256(Data(repeating: 0x02, count: 32)),
        .bytes(Data([1, 2, 3])),
        .string("hello"),
        .symbol("sym"),
        .vec([.u32(42)]),
        .map([SCMapEntry(key: .symbol("k"), val: .i32(5))]),
        .address(.contract(hash)),
        .contractInstance(.init(executable: .stellarAsset, storage: nil)),
        .ledgerKeyContractInstance,
        .ledgerKeyNonce(nonceKey),
    ]

    for value in values {
        try assertRoundTrip(value)
    }
}

@Test func xdr_phase5_sorobanTransactionData_roundTrip() throws {
    let data = SorobanTransactionData(
        ext: ExtensionPoint(),
        resources: SorobanResources(
            footprint: LedgerFootprint(
                readOnly: [],
                readWrite: [.contractCode(Data(repeating: 0xAA, count: 32))]
            ),
            instructions: 100,
            readBytes: 200,
            writeBytes: 300
        ),
        resourceFee: 400
    )
    try assertRoundTrip(data)
}

@Test func xdr_phase5_operationBody_roundTrip() throws {
    let invoke = OperationBody.invokeHostFunction(
        .init(
            hostFunction: .uploadWasm(Data([0x00, 0x61, 0x73, 0x6D])),
            auth: []
        )
    )
    try assertRoundTrip(invoke)

    let createAccount = OperationBody.createAccount(CreateAccountOp())
    try assertRoundTrip(createAccount)
}

@Test func xdr_phase5_knownJsSdkHexVectors() throws {
    #expect(try Int32(42).toXDR().hexEncodedString() == "0000002a")
    #expect(try UInt64(9).toXDR().hexEncodedString() == "0000000000000009")
    #expect(try Bool(true).toXDR().hexEncodedString() == "00000001")
    #expect(try Data([0x01, 0x02, 0x03]).toXDR().hexEncodedString() == "0000000301020300")
    #expect(try String("ok").toXDR().hexEncodedString() == "000000026f6b0000")
    #expect(try [UInt32(1), UInt32(2)].toXDR().hexEncodedString() == "000000020000000100000002")
    #expect(try ScVal.u32(7).toXDR().hexEncodedString() == "0000000300000007")
    #expect(
        try ScVal.vec([.u32(1), .u32(2)]).toXDR().hexEncodedString()
            == "00000010000000010000000200000003000000010000000300000002"
    )

    let tx = Transaction(
        sourceAccount: .ed25519(Data(repeating: 0x11, count: 32)),
        fee: 100,
        seqNum: 1,
        cond: .none,
        memo: .none,
        operations: [],
        ext: .v0
    )

    let expectedTxHex =
        "00000000" +
        "1111111111111111111111111111111111111111111111111111111111111111" +
        "00000064" +
        "0000000000000001" +
        "00000000" +
        "00000000" +
        "00000000" +
        "00000000"
    let encodedHex = try tx.toXDR().hexEncodedString()
    #expect(encodedHex == expectedTxHex)
    #expect(try Transaction(xdr: Data(hexEncoded: expectedTxHex)) == tx)
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
