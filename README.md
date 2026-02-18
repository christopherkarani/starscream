# Starscream SDK

Swift SDK for Stellar Soroban smart contracts.

## Quickstart

### Add Dependency

```swift
// Package.swift
.package(url: "https://github.com/your-org/starscream.git", from: "1.0.0")
```

```swift
.target(
    name: "YourApp",
    dependencies: ["Starscream"]
)
```

### Basic Usage

```swift
import Foundation
import Starscream

let server = SorobanServer(rpcURL: URL(string: "https://soroban-testnet.stellar.org")!)
let source = "G..." // source account
let contractId = "C..."
let keyPair = try KeyPair(secretSeed: "S...")

let assembled: AssembledTransaction<Void> = try await server.prepareTransaction(
    invokeContract(contractId, function: "increment") {
        UInt32(1)
    },
    source: source,
    network: .testnet,
    options: .default
)

let signed = try assembled.signed(by: keyPair)
let sent = try await signed.send(using: server)
try await sent.result() // Void for non-returning methods
```

## End-to-End Example (Appendix E)

```swift
import Foundation
import Starscream

@ContractClient(spec: "<base64-contract-spec>")
struct CounterClient {
    let contractId: String
    let server: SorobanServer
    let network: Network
}

func runCounterFlow() async throws {
    let server = SorobanServer(rpcURL: URL(string: "https://soroban-testnet.stellar.org")!)
    let signer = try KeyPair(secretSeed: "S...")
    let client = CounterClient(
        contractId: "C...",
        server: server,
        network: .testnet
    )

    let tx = try await client.increment(source: signer.publicKey.stellarAddress)
    let sent = try await tx.signed(by: signer).send(using: server)
    try await sent.result()
}
```

## Error Taxonomy (Appendix A)

`StarscreamError` is the top-level SDK error:

- RPC/network: `rpcError`, `networkError`, `timeout`, `accountNotFound`, `contractNotFound`, `friendbotNotAvailable`
- XDR/crypto: `xdrError`, `cryptoError`
- transaction flow: `simulationFailed`, `transactionFailed`, `restoreRequired`, `restoreFailed`, `notYetSimulated`, `needsMoreSignatures`
- usage/state: `resultDecodingFailed`, `invalidState`, `invalidFormat`

See `/Users/chriskarani/starscream/Sources/Starscream/Errors.swift` for canonical definitions.

## StrKey Specification (Appendix B)

Starscream follows SEP-0023 style StrKey encoding:

1. Build payload: `[versionByte] + payloadBytes`
2. Compute checksum: CRC16-XMODEM over payload (`poly=0x1021`, `init=0x0000`)
3. Append checksum little-endian
4. Base32 encode (RFC 4648, uppercase, no `=` padding)

Supported version bytes:

- `ed25519PublicKey` (`G...`)
- `ed25519SecretSeed` (`S...`)
- `preAuthTx` (`T...`)
- `sha256Hash` (`X...`)
- `muxedAccount` (`M...`)
- `signedPayload` (`P...`)
- `contract` (`C...`)

Implementation: `/Users/chriskarani/starscream/Sources/StarscreamXDR/StrKey.swift`.

## ScVal Mapping (Appendix C)

| SCSpec type | Swift |
|---|---|
| `BOOL` | `Bool` |
| `VOID` | `Void` |
| `U32/I32` | `UInt32` / `Int32` |
| `U64/I64` | `UInt64` / `Int64` |
| `U128/I128` | `StellarUInt128` / `StellarInt128` |
| `U256/I256` | `UInt256` / `Int256` |
| `BYTES` / `BYTES_N` | `Data` |
| `STRING` / `SYMBOL` | `String` |
| `ADDRESS` / `MUXED_ADDRESS` | `SCAddress` |
| `OPTION<T>` | `T?` |
| `VEC<T>` | `[T]` |
| `MAP<K,V>` | `[(K, V)]` |
| `UDT(name)` | generated Swift type |

Macro implementation: `/Users/chriskarani/starscream/Sources/StarscreamMacrosImpl/MacroImpl.swift`.

## Threading Model (Appendix H)

- `SorobanServer` is an `actor` for RPC coordination and transaction lifecycle orchestration.
- `EventWatcher` is an `actor` and publishes an `AsyncStream<Result<EventInfo, Error>>`.
- Core XDR models are value types (`struct`/`enum`) and `Sendable`.
- Mutable XDR fields are intentional for simulation→assembly/signing stages (for example `Transaction.fee`, `Operation.body`, `InvokeHostFunctionOp.auth`, `TransactionV1Envelope.signatures`).

## Notes on `Void` Conversions

Swift tuple protocol conformances are currently experimental, so direct `extension Void: ScValConvertible` is not production-safe.
Starscream handles `Void` return values with `SentTransaction.result() where T == Void`, while `Optional<T>` maps through `.void` in `ScValConvertible`.
