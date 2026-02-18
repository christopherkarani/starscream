# Starscream SDK: Implementation TODO

**Status Legend:** `[ ]` pending | `[-]` in progress | `[x]` done | `[!]` blocked

---

## Phase 0: Project Setup

- [x] **P0.1** Initialize Swift Package only if missing manifest (`if [ ! -f Package.swift ]; then swift package init --type library; fi`)
- [x] **P0.2** Write `Package.swift` with all 6 targets + 3 test targets (from plan section 2.1)
  - Targets: `Starscream`, `StarscreamXDR`, `StarscreamRPC`, `StarscreamMacros`, `StarscreamMacrosImpl`, `StarscreamCLI`
  - Verify `Starscream` depends on `StarscreamMacros` (Fix 11)
- [x] **P0.3** Create directory structure matching plan section 2.3 (25 source files + 3 test files)
- [x] **P0.4** Verify `swift build` succeeds with empty stubs
- [x] **P0.5** Set up `.gitignore` and initial commit

---

## Phase 1: Foundational Modules (3 parallel streams)

### Stream A: XDR Codec Engine
**Module:** `StarscreamXDR` | **Files:** `Codec/XDREncoder.swift`, `Codec/XDRDecoder.swift`

- [x] **A.1** Define `XDRCodable` protocol (`encode(to:)` + `init(from:)`)
  - Must include `toXDR() -> Data` and `init(xdr:)` convenience methods
- [x] **A.2** Implement `XDREncoder` as `~Copyable` struct
  - [x] Primitive encoders: `Int32`, `UInt32`, `Int64`, `UInt64`, `Bool`
  - [x] Opaque data encoder with padding (`(4 - n%4)%4` zero bytes)
  - [x] String encoder (variable-length opaque)
  - [x] Generic array encoder (4-byte count prefix + elements)
  - [x] Optional encoder (bool flag + value)
  - [x] Optional array overload (explicit `[T]?` to avoid ambiguity)
- [x] **A.3** Implement `XDRDecoder` as `~Copyable` struct
  - [x] Primitive decoders: `Int32`, `UInt32`, `Int64`, `UInt64`, `Bool`
  - [x] Opaque data decoder (fixed + variable length, with padding skip)
  - [x] String decoder
  - [x] Generic array decoder
  - [x] Optional decoder
  - [x] Optional array overload
  - [x] Bounds checking: throw on insufficient data

### Stream B: Crypto Module
**Module:** `StarscreamXDR` (StrKey) + `Starscream` (KeyPair)
**Files:** `StrKey.swift`, `KeyPair.swift`
**Depends on:** A.1 (XDRCodable protocol), D.1 fundamental types for `TransactionSignaturePayload`

- [x] **B.1** Implement Base32 encode/decode (RFC 4648, no padding)
  - Standard alphabet A-Z, 2-7
  - No `=` padding per SEP-0023
  - Internal to StrKey
- [x] **B.2** Implement CRC16-XMODEM
  - Polynomial `0x1021`, initial `0x0000`, no final XOR, MSB-first
  - 2-byte checksum appended little-endian
- [x] **B.3** Implement `StrKey` enum with `encode(_:version:)` and `decode(_:)` methods
  - All 7 version bytes: `ed25519PublicKey`, `ed25519SecretSeed`, `preAuthTx`, `sha256Hash`, `muxedAccount`, `signedPayload`, `contract`
- [x] **B.4** Implement `PublicKey` struct (crypto key, not XDR)
  - `rawBytes: Data` (32 bytes)
  - `verify(signature:for:)` using `Curve25519.Signing.PublicKey`
  - `stellarAddress: String` computed property (StrKey G... encoding)
  - `init(strKey:)` — decode `G...` StrKey address
- [x] **B.5** Implement `KeyPair` struct
  - `random()` static factory
  - `init(secretSeed:)` — decode `S...` StrKey
  - `sign(_:)` — Ed25519 signature
  - `signTransaction(_:networkPassphrase:)` — uses `TransactionSignaturePayload`

### Stream C: RPC Client Scaffolding
**Module:** `StarscreamRPC` | **Files:** `RPCClient.swift`, `RPCModels.swift`

- [x] **C.1** Implement `RPCClient` (final class, Sendable)
  - JSON-RPC 2.0 request construction
  - POST via `AsyncHTTPClient`
  - Response decoding with `result`/`error` handling
  - Configurable timeout
- [x] **C.2** Define all RPC supporting types (all `Codable & Sendable`)
  - [x] `ResourceConfig`
  - [x] `PaginationOptions`
  - [x] `RestorePreamble` (note: `minResourceFee` is `Int64`)
  - [x] `SimResult`
  - [x] `StateChange`
  - [x] `EventInfo`
  - [x] `LedgerEntryResult`
  - [x] `FeeDistribution` (with computed `maxFee`/`minFee`/`modeFee`)
  - [x] `SimulationCost` (cpuInsns: String, memBytes: String)
  - [x] `LedgerInfo`
  - [x] `TransactionInfo`
- [x] **C.3** Define all RPC request types
  - [x] `SimulateTransactionRequest`
  - [x] `GetEventsRequest`
  - [x] `EventFilter` + `EventFilterTopic`
  - [x] `GetLedgerEntriesRequest`
  - [x] `SendTransactionRequest`
  - [x] `GetTransactionRequest`
  - [x] `GetTransactionsRequest`
  - [x] `GetLedgersRequest`
  - [x] `GetFeeStatsRequest`
- [x] **C.4** Define all RPC response types
  - [x] `SimulateTransactionResponse`
  - [x] `GetEventsResponse`
  - [x] `GetLedgerEntriesResponse`
  - [x] `SendTransactionResponse`
  - [x] `GetTransactionResponse`
  - [x] `GetTransactionsResponse`
  - [x] `GetLedgersResponse`
  - [x] `GetFeeStatsResponse`
  - [x] `GetHealthResponse`
  - [x] `GetNetworkResponse`
  - [x] `GetVersionInfoResponse`
  - [x] `GetLatestLedgerResponse`

---

## Phase 2: Complete XDR Type System
**Module:** `StarscreamXDR` | **Depends on:** Phase 1 Stream A (XDR Codec)

### StellarTypes.swift (Task D.1)
- [x] **D.1.1** Define type aliases: `Hash`, `UInt256`, `Int256` (all `Data`, fixed 32 bytes)
  - Note: Appendix C references `StellarUInt256`/`StellarInt256` as "custom wrappers" but the XDR spec uses opaque[32]. Keep as Data typealiases for now; promote to structs only if hi/lo decomposition is needed (unlike 128-bit, 256-bit values have no standard hi/lo split in the XDR)
- [x] **D.1.2** Implement `StellarUInt128` struct (hi: UInt64, lo: UInt64) with XDRCodable
- [x] **D.1.3** Implement `StellarInt128` struct (hi: Int64, lo: UInt64) with XDRCodable
- [x] **D.1.4** Implement `ExtensionPoint` (void union, encodes as Int32(0))
- [x] **D.1.5** Implement `EnvelopeType` enum (10 cases, raw Int32)
- [x] **D.1.6** Implement `CryptoKeyType` enum (5 cases including muxedEd25519 = 0x100)
- [x] **D.1.7** Implement `SignerKey` enum (4 cases)
- [x] **D.1.8** Implement `XDRPublicKey` enum (ed25519 case with UInt256 payload)
- [x] **D.1.9** Define `AccountID` typealias → `XDRPublicKey`
- [x] **D.1.10** Define `PoolID` typealias → `Hash`

### StellarTransaction.swift (Tasks D.2, D.3)
- [x] **D.2.1** Implement `MuxedAccount` enum (ed25519, muxedEd25519)
- [x] **D.2.2** Implement `Memo` enum (5 cases)
- [x] **D.2.3** Implement `TimeBounds`, `LedgerBounds`, `PreconditionsV2`, `Preconditions`
- [x] **D.2.4** Implement `OperationType` enum (27 cases, raw Int32)
- [x] **D.2.5** Implement `Operation` struct + `OperationBody` enum (27 cases)
- [x] **D.2.6** Implement stubs for 21 non-Soroban operation types
- [x] **D.2.7** Implement Soroban operation types: `InvokeHostFunctionOp`, `ExtendFootprintTTLOp`, `RestoreFootprintOp`
- [x] **D.2.8** Implement `InvokeContractArgs` struct
- [x] **D.2.9** Implement `Transaction` struct (sourceAccount, fee, seqNum, cond, memo, operations, ext)
- [x] **D.2.10** Implement `TransactionExtension` enum (v0, v1(SorobanTransactionData))
- [x] **D.2.11** Implement `DecoratedSignature` struct
- [x] **D.2.12** Implement `TransactionV1Envelope` struct
- [x] **D.2.13** Implement `TransactionV0Envelope` struct (minimal/legacy)
- [x] **D.2.14** Implement `FeeBumpTransactionEnvelope` struct (minimal)
- [x] **D.2.15** Implement `TransactionEnvelope` enum (v0, v1, feeBump)
- [x] **D.2.16** Implement `TransactionSignaturePayload` struct with nested `TaggedTransaction`
- [x] **D.3.1** Implement `HashIDPreimage` enum (4 cases — critical for auth signing)
- [x] **D.3.2** Implement `HashIDPreimageSorobanAuthorization` struct
- [x] **D.3.3** Implement `HostFunction` enum (4 cases)
- [x] **D.3.4** Implement `SorobanAuthorizationEntry` struct
- [x] **D.3.5** Implement `SorobanCredentials` enum + `SorobanAddressCredentials` struct
- [x] **D.3.6** Implement `SorobanAuthorizedInvocation` struct (recursive)
- [x] **D.3.7** Implement `SorobanAuthorizedFunction` enum (3 cases)
- [x] **D.3.8** Implement `SorobanTransactionData` + `SorobanResources` + `LedgerFootprint`
- [x] **D.3.9** Implement `CreateContractArgs`, `CreateContractArgsV2`
- [x] **D.3.10** Implement `ContractIDPreimage` enum, `ContractExecutable` enum

### StellarLedgerEntries.swift (Task D.4)
- [x] **D.4.1** Implement `LedgerKey` enum (10 cases)
- [x] **D.4.2** Implement `LedgerEntry` struct + `LedgerEntryData` enum (10 cases)
- [x] **D.4.3** Implement `AccountEntry` struct (full fields from XDR)
- [x] **D.4.4** Implement `ContractDataEntry` struct
- [x] **D.4.5** Implement `ContractCodeEntry` struct + `ContractCodeEntryExt`
- [x] **D.4.6** Implement `LedgerEntryExt` enum (v0, v1)
- [x] **D.4.7** Implement `TTLEntry` struct
- [x] **D.4.8** Implement non-Soroban ledger entry stubs: `TrustLineEntry`, `OfferEntry`, `DataEntry`, `ClaimableBalanceEntry`, `LiquidityPoolEntry`, `ConfigSettingEntry`
- [x] **D.4.9** Implement `AlphaNum4`, `AlphaNum12`, `Asset` enum, `TrustLineAsset` enum
- [x] **D.4.10** Implement `ContractDataDurability` enum (temporary, persistent)
- [x] **D.4.11** Implement `LedgerEntryExtensionV1` struct (sponsoringID: AccountID?)
  - Referenced by `LedgerEntryExt.v1`

### StellarContract.swift (Task D.5)
- [x] **D.5.1** Implement `SCAddress` enum (5 cases per CAP-0067)
  - account(AccountID), contract(Hash), muxedAccount(MuxedEd25519Account), claimableBalance(ClaimableBalanceID), liquidityPool(Hash)
  - Note: muxedAccount addresses cannot be used as contract storage keys (LedgerKey.contractData)
- [x] **D.5.2** Implement `MuxedEd25519Account` struct (id: UInt64, ed25519: UInt256)
- [x] **D.5.3** Implement `ClaimableBalanceID` enum (v0(Hash)) — used by SCAddress and LedgerKey
- [x] **D.5.4** Implement `SCMapEntry` struct (key: ScVal, val: ScVal) — note: field is `val` (matches XDR spec), not `value`
- [x] **D.5.5** Implement `ScVal` enum (22 cases)
  - Use `StellarUInt128` for u128, `StellarInt128` for i128
  - u256/i256 use `UInt256`/`Int256` (Data typealiases)
- [x] **D.5.6** Implement `SCError` enum (10 cases: contract, wasmVm, context, storage, object, crypto, events, budget, value, auth)
- [x] **D.5.7** Implement `SCErrorCode` enum (10 cases, raw Int32: arithDomain=0 through unexpectedSize=9)
- [x] **D.5.8** Implement `SCContractInstance` struct (executable: ContractExecutable, storage: [SCMapEntry]?)
- [x] **D.5.9** Implement `SCNonceKey` struct (nonce: Int64)
- [x] **D.5.10** Implement all SCSpec types for macro code generation:
  - [x] `SCSpecEntry` enum (functionV0, udtStructV0, udtEnumV0, udtUnionV0, udtErrorEnumV0)
  - [x] `SCSpecFunctionV0` (name, inputs, outputs)
  - [x] `SCSpecUDTStructV0` (name, fields with type + name)
  - [x] `SCSpecUDTEnumV0` (name, cases with name + value)
  - [x] `SCSpecUDTUnionV0` (name, cases with type + optional payload)
  - [x] `SCSpecUDTErrorEnumV0` (name, cases with name + value)
  - [x] `SCSpecTypeDef` enum (all 22 cases from Appendix C mapping table)

### StellarLedger.swift (Task D.6)
- [x] **D.6.1** Implement `ContractEventType` enum (system=0, contract=1, diagnostic=2)
- [x] **D.6.2** Implement `ContractEvent` struct
  - ext: ExtensionPoint, contractID: Hash?, type: ContractEventType, topics: [ScVal], data: ScVal
  - XDR body is a union but flattened for ergonomics — encode as Int32(0) + topics + data
- [x] **D.6.3** Implement `DiagnosticEvent` struct (inSuccessfulContractCall: Bool, event: ContractEvent)

---

## Phase 3: Orchestration Layer
**Module:** `Starscream` | **Depends on:** Phase 2 + Phase 1 Streams B, C

### Supporting Types (Tasks E/F)
**Files:** `Network.swift`, `Account.swift`, `TransactionOptions.swift`, `Errors.swift`

- [x] **E.1** Implement `Network` enum (`` `public` ``, `testnet`, `futurenet`, `custom(passphrase:)`)
  - Each case provides `passphrase: String`
- [x] **E.2** Implement `Account` struct (publicKey: String, sequenceNumber: Int64)
  - Mutable sequenceNumber (incremented after each transaction)
- [x] **E.3** Implement `TransactionOptions` struct (fee, autoRestore, timeoutSeconds, memo)
  - `static let default` with fee=100, autoRestore=true, timeout=30, memo=.none
- [x] **E.4** Implement `StarscreamError` enum (full taxonomy — Appendix A) in `Errors.swift`
  - 4 categories: RPC/Network, XDR/Crypto, Transaction/Simulation, SDK State/Usage
- [x] **E.4.1** Include `friendbotNotAvailable` case (used by `requestAirdrop`)
- [x] **E.5** Define `RPCError` struct (code: Int, message: String, data: String?)
  - Used by `StarscreamError.rpcError(RPCError)`
- [x] **E.6** Define `XDRError` enum (insufficientData, invalidDiscriminant, invalidLength, etc.)
  - Used by `StarscreamError.xdrError(XDRError)`
- [x] **E.7** Define `CryptoError` enum (invalidKeyLength, signatureFailed, etc.)
  - Used by `StarscreamError.cryptoError(CryptoError)`

### Stream G: SorobanServer (Task G.1)
**File:** `SorobanServer.swift` | **Depends on:** B.5, C.1

- [x] **G.1** Implement `SorobanServer` as `actor`
  - [x] `init(endpoint:)` — creates internal RPCClient
  - [x] `getAccount(_:)` — with fake account fallback for simulation (returns Account with sequenceNumber 0)
  - [x] `getHealth()` → `GetHealthResponse`
  - [x] `getLatestLedger()` → `GetLatestLedgerResponse`
  - [x] `getVersionInfo()` → `GetVersionInfoResponse`
  - [x] `getNetwork()` → `GetNetworkResponse`
  - [x] `requestAirdrop(for:)` — friendbot integration via network's friendbotUrl
  - [x] `sendTransaction(...)` → `SendTransactionResponse`
  - [x] `getEvents(...)` → `GetEventsResponse`
  - [x] `getLedgerEntries(keys:)` → `GetLedgerEntriesResponse`
  - [x] `getTransaction(hash:)` → `GetTransactionResponse`
  - [x] `getTransactions(startLedger:pagination:)` → `GetTransactionsResponse`
  - [x] `getLedgers(startLedger:pagination:)` → `GetLedgersResponse`
  - [x] `simulateTransaction(_:resourceConfig:)` → `SimulateTransactionResponse`
  - [x] `getFeeStats()` → `GetFeeStatsResponse`
  - [x] `prepareTransaction(_:source:network:options:)` — the main orchestration method
    - Get account → build tx → simulate → check restore preamble → assemble → return

### Stream G: assembleTransaction (Task G.2)
**File:** `Utilities/AssembleTransaction.swift`

- [x] **G.2** Implement `assembleTransaction(_:_:)` free function
  - Set `SorobanTransactionData` from simulation → `ext = .v1(sorobanData)`
  - Decode base64 auth entries from simulation → set on `InvokeHostFunctionOp`
  - Fee calculation: `tx.fee + UInt32(clamping: resourceFee)` (NOT replacement)

### Stream H: AssembledTransaction + SentTransaction (Tasks H.1–H.3)
**Files:** `AssembledTransaction.swift`, `SentTransaction.swift`, `AssembledTransaction+JSON.swift`

- [x] **H.1** Implement `AssembledTransaction<T>` struct (Sendable, value type)
  - [x] `isReadCall` computed property (empty auth = read-only)
  - [x] `needsNonInvokerSigningBy()` → `[SCAddress]`
  - [x] `signed(by:)` → new `AssembledTransaction` with signature
  - [x] `signAuthEntries(for:with:)` → new `AssembledTransaction`
  - [x] `send(using:)` → `SentTransaction<T>`
- [x] **H.2** Implement `authorizeEntry(...)` utility (in `AuthorizeEntry.swift`)
  - Uses `HashIDPreimage.sorobanAuthorization` for signing
- [x] **H.3** Implement `SentTransaction<T>` struct
  - [x] `status()` — polls `getTransaction`
  - [x] `result()` — polls until success, decodes `ScVal` to `T`
- [x] **H.4** Implement JSON serialization (`toJSON()`, `fromJSON(_:)`)
  - `AssembledTransactionJSON` codable struct

### Stream I: Utilities (Tasks I.1–I.5)
**Files:** `SorobanDataBuilder.swift`, `RestoreFlow.swift`, `TTLExtension.swift`, `EventWatcher.swift`, `ContractDeployment.swift`

- [x] **I.1** Implement `SorobanDataBuilder` (fluent API)
  - `setReadOnly`, `setReadWrite`, `setResourceFee`, `build`
- [x] **I.2** Implement `handleRestore(...)` in `RestoreFlow.swift`
  - Build `RestoreFootprintOp` tx using preamble data
  - Uses `cond: .none` (not timeBounds), `ext: .v1(txData)`, `UInt32(clamping:)` for fee
- [x] **I.3** Implement `extendFootprintTTL(...)` in `TTLExtension.swift`
  - Extension on `SorobanServer`
- [x] **I.4** Implement `EventWatcher` actor
  - `events(filters:)` → `AsyncStream<Result<EventInfo, Error>>`
  - Uses `AsyncStream.makeStream()` pattern (NOT closure-based)
  - Actor-isolated `pollLoop` method for Swift 6 concurrency safety
  - Configurable `pollInterval`
- [x] **I.5** Implement contract deployment helper in `ContractDeployment.swift`
  - Upload WASM via `HostFunction.uploadWasm(Data)` → get WASM hash
  - Create contract via `HostFunction.createContract(CreateContractArgs)` → get contract ID
  - Combined `deploy(wasm:source:network:)` convenience method
- [x] **I.6** Implement `ContractClient` base type in `ContractClient.swift`
  - Properties: `contractId: String`, `server: SorobanServer`, `network: Network`
  - Shared infrastructure for `@ContractClient` macro-generated types
  - Convenience `invoke(_:arguments:source:options:)` method

---

## Phase 4: Developer Experience Layer
**Module:** `Starscream` + `StarscreamMacros` | **Depends on:** Phase 3

### Stream J: Transaction Builder DSL (Tasks J.1–J.2)
**File:** `TransactionBuilderDSL.swift`

- [x] **J.1** Implement `TransactionContentBuilder` result builder
  - `buildBlock`, `buildExpression`, `buildOptional`, `buildEither`, `buildArray`
- [x] **J.2** Implement `FunctionArgumentBuilder` result builder
  - `buildBlock`, `buildExpression`, `buildOptional`, `buildEither`
- [x] **J.3** Implement `invokeContract(_:function:arguments:)` free function
- [x] **J.4** Implement `TransactionBuilder.build(source:network:fee:content:)` static method

### Stream K: ScValConvertible Protocol (Tasks K.1–K.2)
**File:** `ScValConvertible.swift`

- [x] **K.1** Define `ScValConvertible` protocol (init(fromScVal:), toScVal())
- [x] **K.2** Implement conformances for standard types:
  - [x] `Bool`, `Void` (`Void` handled via dedicated `SentTransaction.result() where T == Void` API; tuple protocol conformance remains experimental in Swift)
  - [x] `UInt32`, `Int32`, `UInt64`, `Int64`
  - [x] `String`, `Data`
  - [x] `StellarInt128`, `StellarUInt128`
  - [x] `SCAddress`
  - [x] `Array where Element: ScValConvertible`
  - [x] `Dictionary where Key, Value: ScValConvertible`
  - [x] `Optional where Wrapped: ScValConvertible`

### Stream L: @ContractClient Macro (Tasks L.1–L.3)
**Files:** `StarscreamMacrosImpl/MinimalXDRDecoder.swift`, `StarscreamMacrosImpl/MacroImpl.swift`, `StarscreamMacros/Macros.swift`

- [x] **L.1** Implement `MinimalXDRDecoder` (self-contained, no StarscreamXDR dependency)
  - Decodes `SCSpecEntry` array from base64 WASM custom section
- [x] **L.2** Implement `ContractClientMacro: MemberMacro`
  - [x] Extract + decode spec string from macro arguments
  - [x] `generateFunction(...)` — method for each contract function
  - [x] `generateStruct(...)` — for UDT structs
  - [x] `generateEnum(...)` — for UDT enums
  - [x] `generateUnion(...)` — for UDT unions
  - [x] `generateErrorEnum(...)` — for UDT error enums
  - [x] Type mapping: full SCSpecTypeDef → Swift type mapping (Appendix C)
- [x] **L.3** Define public macro declaration in `Macros.swift`
  - `@attached(member, names: arbitrary)`

---

## Phase 5: CLI, Testing, and Polish

### Stream M: CLI Tool (Task M.1)
**File:** `StarscreamCLI/main.swift` | **Depends on:** L.2 (macro), G.1 (server)

- [x] **M.1** Implement `starscream-cli` using ArgumentParser
  - [x] Argument: contract ID
  - [x] Options: `--rpc-url`, `--output-path`
  - [x] Fetch contract code via `getLedgerEntries` with `LedgerKey.contractCode(hash:)`
  - [x] Decode `LedgerEntry` → `ContractCodeEntry` from base64 XDR response
  - [x] Extract WASM bytecode from `ContractCodeEntry.code`
  - [x] Implement WASM binary parser (minimal): parse section headers, find custom section named `contractspec`
    - WASM format: magic + version + sections (id + size + payload)
    - Custom sections: name length + name bytes + data
    - Only need to find section with name == "contractspec"
  - [x] Base64-encode the extracted spec bytes
  - [x] Generate Swift file with `@ContractClient(spec: ...)` struct
  - [x] Write output to `--output-path`

### Stream N: Testing (Tasks N.1–N.3)

#### XDR Unit Tests (N.1)
**File:** `Tests/StarscreamXDRTests/XDRTests.swift`

- [x] **N.1.1** Encoder round-trip tests for all primitives (Int32, UInt32, Int64, UInt64, Bool)
- [x] **N.1.2** Opaque data encoding tests (fixed + variable, with padding verification)
- [x] **N.1.3** String encoding tests (empty, short, padding-boundary lengths)
- [x] **N.1.4** Array encoding tests (empty, single, multiple elements)
- [x] **N.1.5** Optional encoding tests (nil + present)
- [x] **N.1.6** Complex struct round-trip (Transaction, SorobanTransactionData)
- [x] **N.1.7** Enum/union round-trip (ScVal with all cases, OperationBody)
- [x] **N.1.8** Cross-validation: encode in Swift, compare against known JS SDK XDR hex strings
- [x] **N.1.9** StrKey encode/decode round-trip for all 7 version bytes
- [x] **N.1.10** CRC16-XMODEM test vectors
- [x] **N.1.11** `StellarInt128` / `StellarUInt128` encode/decode with hi/lo verification

#### Crypto Tests (N.2)
**File:** `Tests/StarscreamTests/` (or `StarscreamXDRTests/`)

- [x] **N.2.1** `KeyPair.random()` produces valid keys
- [x] **N.2.2** `KeyPair(secretSeed:)` round-trip with known test vectors
- [x] **N.2.3** `sign` + `verify` round-trip
- [x] **N.2.4** `signTransaction` produces correct `DecoratedSignature`

#### Macro Tests (N.3)
**File:** `Tests/StarscreamMacrosTests/MacroTests.swift`

- [x] **N.3.1** Function generation: input spec → expected Swift method signature
- [x] **N.3.2** Struct generation: UDT struct spec → Swift struct with ScValConvertible
- [x] **N.3.3** Enum generation: UDT enum spec → Swift enum
- [x] **N.3.4** Error enum generation: error spec → Swift enum with Error conformance
- [x] **N.3.5** Full contract spec: multi-function + multi-type spec → complete client struct

#### Integration Tests (N.4)
**File:** `Tests/StarscreamTests/IntegrationTests.swift` | **Requires:** testnet access

- [x] **N.4.1** Read-only contract call (isReadCall = true, result from simulation)
- [x] **N.4.2** Write call: sign + send + poll for confirmation
- [x] **N.4.3** Multi-party signing with `signAuthEntries`
- [x] **N.4.4** Auto-restore flow (call that requires data restoration)
- [x] **N.4.5** Contract deployment (upload WASM + create)
- [x] **N.4.6** Event polling via `EventWatcher`
- [x] **N.4.7** TTL extension via `extendFootprintTTL`
- [x] **N.4.8** Transaction builder DSL end-to-end
- [x] **N.4.9** `AssembledTransaction` JSON serialization round-trip
- [x] **N.4.10** Fee calculation: verify assembled tx fee = base fee + resource fee
- [x] **N.4.11** Friendbot airdrop on testnet
- [x] **N.4.12** Error handling: invalid contract ID, expired entries, insufficient balance

### Stream O: Documentation and Appendices (Task O.1)

- [x] **O.1** Write `StarscreamError` enum with all cases (Appendix A)
- [x] **O.2** Document StrKey specification (Appendix B)
- [x] **O.3** Document ScVal ↔ Swift type mapping table (Appendix C)
- [x] **O.4** Document threading model (Appendix H)
- [x] **O.5** Write end-to-end code example (Appendix E)
- [x] **O.6** Write README.md with quickstart guide

---

## Cross-Cutting Concerns

These apply throughout all phases:

- [x] **X.1** All public types conform to `Sendable`
- [x] **X.2** All structs and enums conform to `Hashable` (or intentionally remain non-Hashable where they carry non-hashable runtime state such as actor/error existential references)
- [x] **X.3** All XDR types follow exact field order from `.x` specification files (covered by deterministic encode/decode and fixed-hex vector tests)
- [x] **X.4** Use plain type names (module qualification for collisions, NOT `XDR<TypeName>` prefix)
- [x] **X.5** Value semantics everywhere — no reference-type XDR types
- [x] **X.6** `SorobanServer` and `EventWatcher` are actors (NOT classes)
- [x] **X.7** All fee calculations use addition (base + resource), never replacement
- [x] **X.8** Linux compatibility (no Foundation-only APIs, no Darwin-specific imports)
- [x] **X.9** XDR encode/decode happens at `Starscream` module boundary, not inside `StarscreamRPC`
  - `StarscreamRPC` deals only in JSON-codable types (strings, base64-encoded XDR)
  - `Starscream` module converts between XDR binary and RPC string representations
- [x] **X.10** `~Copyable` protocol constraint: `XDRCodable` protocol itself must NOT be `~Copyable`
  - Only `XDREncoder` and `XDRDecoder` are `~Copyable`
  - Types conforming to `XDRCodable` remain regular `Copyable` structs/enums
- [x] **X.11** All `var` fields in XDR types (Operation.body, Transaction.fee, etc.) are intentional
  - These are mutated by `assembleTransaction` during simulation → assembly flow
  - Document why each `var` exists to prevent accidental `let` conversion

---

## Dependency Graph (Execution Order)

```
Phase 0 (Setup)
  |
  v
Phase 1 ──┬── Stream A: XDR Codec ──────────────────────────┐
           ├── Stream B: Crypto (waits for A + D.1) ─────────┤
           └── Stream C: RPC Client ─────────────────────────┤
                                                              |
Phase 2 ──── All XDR Types (D.1–D.6) ────────────────────────┤
                                                              |
Phase 3 ──┬── SorobanServer (waits for B.5 + C.1) ──────────┤
           ├── AssembledTransaction (waits for G.1) ──────────┤
           ├── SentTransaction (waits for G.1) ───────────────┤
           ├── Utilities (waits for G.1) ─────────────────────┤
           └── EventWatcher (waits for G.1) ──────────────────┤
                                                              |
Phase 4 ──┬── DSL (waits for D.2) ───────────────────────────┤
           ├── ScValConvertible (waits for D.5) ──────────────┤
           └── Macros (no internal deps, uses swift-syntax) ──┤
                                                              |
Phase 5 ──┬── CLI (waits for L.2 + G.1) ─────────────────────┤
           └── Tests (various deps) ──────────────────────────┘
```

**Critical Path:** A.1 → D.2 (Transaction types) → C.1 (RPC wiring) → G.1 (SorobanServer) → H.1 (AssembledTransaction) → N.4 (Integration Tests)

---

## Task Count Summary

| Phase | Top-level | + Sub-tasks | Description |
|-------|-----------|-------------|-------------|
| Phase 0 | 5 | — | Project setup |
| Phase 1 | 12 | +44 | XDR codec + crypto + RPC client |
| Phase 2 | 60 | +14 | Complete XDR type system |
| Phase 3 | 19 | +23 | Orchestration layer + utilities + errors |
| Phase 4 | 9 | +15 | DSL + ScValConvertible + macros |
| Phase 5 | 39 | +3 | CLI + tests + docs |
| Cross-cutting | 11 | — | Quality constraints |
| **Total** | **155** | **+99** | **254 items total** |
