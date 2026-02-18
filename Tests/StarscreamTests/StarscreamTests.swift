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
