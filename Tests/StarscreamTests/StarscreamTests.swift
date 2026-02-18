import Testing
@testable import Starscream
import Foundation
import StarscreamRPC
import StarscreamXDR

@Test func phase0_packageLayout_expectedFilesExist() async throws {
    let requiredFiles = [
        "Package.swift",
        "Sources/Starscream/Network.swift",
        "Sources/StarscreamXDR/Codec/XDREncoder.swift",
        "Sources/StarscreamRPC/RPCClient.swift",
        "Sources/StarscreamMacros/Macros.swift",
        "Sources/StarscreamMacrosImpl/MacroImpl.swift",
        "Sources/StarscreamCLI/main.swift",
        "Tests/StarscreamXDRTests/XDRTests.swift",
        "Tests/StarscreamMacrosTests/MacroTests.swift",
        "Tests/StarscreamTests/IntegrationTests.swift",
    ]

    for file in requiredFiles {
        #expect(FileManager.default.fileExists(atPath: file), "\(file) should exist")
    }
}

@Test func rpc_streamC_simulationModelCriticalFieldsDecode() throws {
    let json = """
    {
      "latestLedger": 101,
      "minResourceFee": "1500",
      "results": [{"auth": ["AAAA"], "xdr": "AAAA"}],
      "transactionData": "AAAA",
      "restorePreamble": {
        "transactionData": "BBBB",
        "minResourceFee": 2000
      },
      "stateChanges": [],
      "events": [],
      "cost": {
        "cpuInsns": "54321",
        "memBytes": "1024"
      }
    }
    """
    let decoded = try JSONDecoder().decode(SimulateTransactionResponse.self, from: Data(json.utf8))
    #expect(decoded.minResourceFee == "1500")
    #expect(decoded.restorePreamble?.minResourceFee == 2000)
    #expect(decoded.cost?.cpuInsns == "54321")
    #expect(decoded.cost?.memBytes == "1024")
}

@Test func rpc_streamC_feeDistributionComputedInt64Accessors() throws {
    let distribution = FeeDistribution(
        max: "900",
        min: "100",
        mode: "450",
        p10: "100",
        p20: "200",
        p30: "300",
        p40: "400",
        p50: "500",
        p60: "600",
        p70: "700",
        p80: "800",
        p90: "900",
        p95: "950",
        p99: "990",
        transactionCount: "123",
        ledgerCount: 5
    )
    #expect(distribution.maxFee == 900)
    #expect(distribution.minFee == 100)
    #expect(distribution.modeFee == 450)
}

@Test func crypto_streamB_keypairSignAndVerify() throws {
    let keyPair = KeyPair.random()
    let payload = Data("starscream".utf8)
    let signature = try keyPair.sign(payload)
    #expect(keyPair.publicKey.verify(signature: signature, for: payload))
}

@Test func crypto_streamB_initFromSecretSeedProducesValidSigner() throws {
    let seedBytes = Data((1...32).map(UInt8.init))
    let seed = StrKey.encode(seedBytes, version: .ed25519SecretSeed)
    let keyPair = try KeyPair(secretSeed: seed)

    let payload = Data("soroban".utf8)
    let signature = try keyPair.sign(payload)
    #expect(keyPair.publicKey.verify(signature: signature, for: payload))
}

@Test func crypto_phase2_signTransactionProducesDecoratedSignature() throws {
    let seedBytes = Data((1...32).map(UInt8.init))
    let keyPair = try KeyPair(secretSeed: StrKey.encode(seedBytes, version: .ed25519SecretSeed))

    let tx = Transaction(
        sourceAccount: .ed25519(keyPair.publicKey.rawBytes),
        fee: 100,
        seqNum: 1,
        cond: .none,
        memo: .none,
        operations: [],
        ext: .v0
    )

    let passphrase = "Test SDF Network ; September 2015"
    let decorated = try keyPair.signTransaction(tx, networkPassphrase: passphrase)
    #expect(decorated.hint.count == 4)
    #expect(decorated.signature.count == 64)
    #expect(decorated.hint == keyPair.publicKey.rawBytes.suffix(4))
}

@Test func phase3_supportingTypes_defaultsAndPassphrases() throws {
    #expect(Network.public.passphrase == "Public Global Stellar Network ; September 2015")
    #expect(Network.testnet.passphrase == "Test SDF Network ; September 2015")
    #expect(Network.futurenet.passphrase == "Test SDF Future Network ; October 2022")
    #expect(Network.custom(passphrase: "custom").passphrase == "custom")

    var account = Account(publicKey: "GABC", sequenceNumber: 5)
    account.incrementSequenceNumber()
    #expect(account.sequenceNumber == 6)

    let defaults = TransactionOptions.default
    #expect(defaults.fee == 100)
    #expect(defaults.autoRestore)
    #expect(defaults.timeoutSeconds == 30)
    #expect(defaults.memo == .none)
}

@Test func phase3_assembleTransaction_addsResourceFeeAndInjectsSimData() throws {
    let contractHash = Data(repeating: 0xAB, count: 32)
    let invoke = InvokeHostFunctionOp(
        hostFunction: .invokeContract(
            InvokeContractArgs(
                contractAddress: .contract(contractHash),
                functionName: "inc",
                args: []
            )
        ),
        auth: []
    )

    let original = Transaction(
        sourceAccount: .ed25519(Data(repeating: 0x11, count: 32)),
        fee: 100,
        seqNum: 7,
        cond: .none,
        memo: .none,
        operations: [Operation(sourceAccount: nil, body: .invokeHostFunction(invoke))],
        ext: .v0
    )

    let txData = SorobanTransactionData(
        ext: ExtensionPoint(),
        resources: SorobanResources(
            footprint: LedgerFootprint(readOnly: [], readWrite: []),
            instructions: 1,
            readBytes: 2,
            writeBytes: 3
        ),
        resourceFee: 99
    )

    let authEntry = SorobanAuthorizationEntry(
        credentials: .sourceAccount,
        rootInvocation: SorobanAuthorizedInvocation(
            function: .contractFn(
                InvokeContractArgs(
                    contractAddress: .contract(contractHash),
                    functionName: "inc",
                    args: []
                )
            ),
            subInvocations: []
        )
    )

    let simulation = SimulateTransactionResponse(
        latestLedger: 100,
        minResourceFee: "200",
        results: [SimResult(auth: [try authEntry.toXDR().base64EncodedString()], xdr: nil)],
        transactionData: try txData.toXDR().base64EncodedString()
    )

    let assembled = try assembleTransaction(original, simulation)
    #expect(assembled.fee == 300)

    if case .v1 = assembled.ext {
        #expect(Bool(true))
    } else {
        #expect(Bool(false), "Expected ext to be .v1 after assembly")
    }

    guard case .invokeHostFunction(let opBody) = assembled.operations[0].body else {
        Issue.record("Expected invokeHostFunction operation")
        return
    }
    #expect(opBody.auth.count == 1)
}

@Test func phase4_scValConvertible_roundTripsCommonTypes() throws {
    let boolScVal = try true.toScVal()
    #expect(try Bool(fromScVal: boolScVal))

    let intScVal = try Int64(42).toScVal()
    #expect(try Int64(fromScVal: intScVal) == 42)

    let stringScVal = try "starscream".toScVal()
    #expect(try String(fromScVal: stringScVal) == "starscream")

    let arrayScVal = try [UInt32(1), UInt32(2), UInt32(3)].toScVal()
    #expect(try [UInt32](fromScVal: arrayScVal) == [1, 2, 3])

    let dictScVal = try (["a": UInt32(1), "b": UInt32(2)] as [String: UInt32]).toScVal()
    let decodedDict = try [String: UInt32](fromScVal: dictScVal)
    #expect(decodedDict["a"] == 1)
    #expect(decodedDict["b"] == 2)

    let optionalSome = try Optional<Int32>.some(9).toScVal()
    #expect(try Optional<Int32>(fromScVal: optionalSome) == 9)

    let optionalNone = try Optional<Int32>.none.toScVal()
    #expect(try Optional<Int32>(fromScVal: optionalNone) == nil)
}

@Test func phase4_dsl_buildsHostFunctionAndTransaction() throws {
    let contractId = StrKey.encode(Data(repeating: 0x22, count: 32), version: .contract)
    let call = invokeContract(contractId, function: "hello") {
        UInt32(7)
        "world"
    }

    guard case .invokeContract(let args) = call else {
        Issue.record("Expected invokeContract host function")
        return
    }
    #expect(args.functionName == "hello")
    #expect(args.args.count == 2)

    let account = Account(
        publicKey: StrKey.encode(Data(repeating: 0x11, count: 32), version: .ed25519PublicKey),
        sequenceNumber: 41
    )

    let tx = try TransactionBuilder.build(source: account, network: .testnet, fee: 100) {
        Operation(sourceAccount: nil, body: .invokeHostFunction(InvokeHostFunctionOp(hostFunction: call, auth: [])))
    }

    #expect(tx.seqNum == 42)
    #expect(tx.operations.count == 1)
}
