# Starscream SDK

Starscream is a **conversion-first Swift SDK** for **Stellar Soroban**.

If you are building Stellar tooling in Swift, this project is aimed at converting Stellar artifacts into typed Swift abstractions and converting Swift values back for on-chain use:

- StrKey strings to and from raw key bytes
- XDR bytes to and from model objects
- RPC JSON payloads to strongly typed responses
- SCSpec function/type metadata into Swift client APIs

## Quickstart

### Add dependency

```swift
// Package.swift
.package(url: "https://github.com/christopherkarani/starscream.git", from: "1.0.0")
```

```swift
.target(
    name: "YourApp",
    dependencies: ["Starscream"]
)
```

### Build, simulate, sign, and submit a transaction

```swift
import Foundation
import Starscream

let server = SorobanServer(endpoint: URL(string: "https://soroban-testnet.stellar.org")!)
let source = "G..." // source account (StrKey)
let contractId = "C..." // contract ID (StrKey)
let keyPair = try KeyPair(secretSeed: "S...")

let assembled: AssembledTransaction<Void> = try await server.prepareTransaction(
    try invokeContract(contractId, function: "increment") {
        UInt32(1)
    },
    source: source,
    network: .testnet,
    options: .default
)

let sent = try await assembled
    .signed(by: keyPair)
    .send(using: server)

try await sent.result() // Void for non-returning methods
```

For typed JSON-first result decoding, you can also decode directly to `Decodable`:

```swift
struct CounterState: Codable, Sendable {
    let value: UInt32
}

let typed: CounterState = try await sent.result(as: CounterState.self)
```

### Contract client example (macro-generated)

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
    let server = SorobanServer(endpoint: URL(string: "https://soroban-testnet.stellar.org")!)
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

## Core conversion paths

- `StrKey.encode(...)` / `StrKey.decode(...)`: convert Stellar key formats
- `toXDR()` / `init(xdr:)`: convert between in-memory models and binary XDR
- `ScValConvertible`: map between `ScVal` and Swift native types
- `@ContractClient(spec:)`: convert contract spec metadata into typed client methods

## Error handling

All public failures are surfaced through `StarscreamError` (`rpcError`, `networkError`, `xdrError`, `cryptoError`, and transaction flow/state errors). See `Sources/Starscream/Errors.swift` for details.

## Migration notes

- `invokeContract(...)` is now `throws`; update call sites to use `try`.
- `SentTransaction` now honors `TransactionOptions.timeoutSeconds` and `pollIntervalMilliseconds`.
- `AssembledTransaction.toJSON()` now persists full decorated signatures (`hint` + `signature`) for deterministic round-trip reconstruction.
- `AssembledTransaction.fromJSON(...)` remains backward compatible with legacy JSON and supports strict signature-hint enforcement via `requireSignatureHints`.

## StrKey specification

Starscream implements SEP-0023-compatible StrKey encoding:

1. Build payload: `[versionByte] + payloadBytes`
2. Compute checksum: CRC16-XMODEM over payload (`poly=0x1021`, `init=0x0000`)
3. Append checksum (little-endian)
4. Base32 encode (RFC 4648, uppercase, no `=` padding)

Supported version bytes:

- `ed25519PublicKey` (`G...`)
- `ed25519SecretSeed` (`S...`)
- `preAuthTx` (`T...`)
- `sha256Hash` (`X...`)
- `muxedAccount` (`M...`)
- `signedPayload` (`P...`)
- `contract` (`C...`)

Implementation: `Sources/StarscreamXDR/StrKey.swift`.

## SC to Swift mapping

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
| `RESULT<OK,ERR>` | `SorobanResult<OK, ERR>` |
| `VEC<T>` | `[T]` |
| `MAP<K,V>` | `SorobanMap<K, V>` |
| `UDT(name)` | generated Swift type |

Macro implementation: `Sources/StarscreamMacrosImpl/MacroImpl.swift`.

## Concurrency model

- `SorobanServer` is an `actor` for orchestration and RPC coordination.
- `EventWatcher` is an `actor` and publishes `AsyncStream<Result<EventInfo, Error>>`.
- Core model types are value types (`struct`/`enum`) and `Sendable`.
