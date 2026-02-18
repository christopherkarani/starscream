import Foundation
@preconcurrency import Network
import Testing
@testable import Starscream
import StarscreamRPC
import StarscreamXDR

@Suite("Integration Tests")
struct IntegrationTests {
    @Test
    func integration_readOnlyCall_isReadCallTrue() async throws {
        let signer = try seededKeyPair(start: 1)
        let source = signer.publicKey.stellarAddress
        let contractId = contractAddress(byte: 0x22)
        let accountXDR = try makeAccountLedgerEntryXDR(publicKey: source, sequence: 41)
        let txData = try makeTransactionDataBase64(resourceFee: 5)

        let (server, local, _) = try await makeRPCServer(responses: [
            "getLedgerEntries": [
                .rpcResult(GetLedgerEntriesResponse(
                    entries: [LedgerEntryResult(key: "account", xdr: accountXDR, lastModifiedLedgerSeq: 1)],
                    latestLedger: 101
                )),
            ],
            "simulateTransaction": [
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 101,
                    minResourceFee: "5",
                    results: [SimResult(auth: [], xdr: nil)],
                    transactionData: txData
                )),
            ],
        ])
        defer { local.stop() }

        let assembled: AssembledTransaction<Void> = try await server.prepareTransaction(
            try invokeContract(contractId, function: "read") {},
            source: source,
            network: .testnet
        )

        #expect(assembled.isReadCall)
        #expect(assembled.transaction.fee == 105)
    }

    @Test
    func integration_writeCall_signSendPollSuccess() async throws {
        let signer = try seededKeyPair(start: 10)
        let source = signer.publicKey.stellarAddress
        let contractId = contractAddress(byte: 0x33)
        let accountXDR = try makeAccountLedgerEntryXDR(publicKey: source, sequence: 2)
        let txData = try makeTransactionDataBase64(resourceFee: 3)
        let authEntry = try makeSourceAccountAuthEntry(contractHash: Data(repeating: 0x33, count: 32)).toXDR().base64EncodedString()
        let returnValue = try ScVal.u32(42).toXDR().base64EncodedString()

        var options = TransactionOptions.default
        options.timeoutSeconds = 1
        options.pollIntervalMilliseconds = 10

        let (server, local, _) = try await makeRPCServer(responses: [
            "getLedgerEntries": [
                .rpcResult(GetLedgerEntriesResponse(
                    entries: [LedgerEntryResult(key: "account", xdr: accountXDR, lastModifiedLedgerSeq: 1)],
                    latestLedger: 9
                )),
            ],
            "simulateTransaction": [
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 9,
                    minResourceFee: "3",
                    results: [SimResult(auth: [authEntry], xdr: nil)],
                    transactionData: txData
                )),
            ],
            "sendTransaction": [
                .rpcResult(SendTransactionResponse(
                    status: "PENDING",
                    hash: "tx-hash-1",
                    latestLedger: 9,
                    latestLedgerCloseTime: "2026-01-01T00:00:00Z"
                )),
            ],
            "getTransaction": [
                .rpcResult(GetTransactionResponse(status: "PENDING", latestLedger: 9)),
                .rpcResult(GetTransactionResponse(
                    status: "SUCCESS",
                    latestLedger: 10,
                    returnValue: returnValue
                )),
            ],
        ])
        defer { local.stop() }

        let assembled: AssembledTransaction<UInt32> = try await server.prepareTransaction(
            try invokeContract(contractId, function: "increment") {
                UInt32(1)
            },
            source: source,
            network: .testnet,
            options: options
        )

        #expect(!assembled.isReadCall)

        let sent = try await assembled
            .signed(by: signer)
            .send(using: server)

        let value: UInt32 = try await sent.result()
        #expect(value == 42)

        try await server.close()
    }

    @Test
    func integration_multiPartySigning_signAuthEntries() async throws {
        let sourceSigner = try seededKeyPair(start: 21)
        let cosigner = try seededKeyPair(start: 61)
        let source = sourceSigner.publicKey.stellarAddress
        let contractId = contractAddress(byte: 0x44)
        let contractHash = Data(repeating: 0x44, count: 32)

        let accountXDR = try makeAccountLedgerEntryXDR(publicKey: source, sequence: 7)
        let txData = try makeTransactionDataBase64(resourceFee: 2)

        let cosignerAddress: SCAddress = .account(.ed25519(cosigner.publicKey.rawBytes))
        let authEntry = SorobanAuthorizationEntry(
            credentials: .address(
                SorobanAddressCredentials(
                    address: cosignerAddress,
                    nonce: 99,
                    signatureExpirationLedger: 500,
                    signature: .void
                )
            ),
            rootInvocation: SorobanAuthorizedInvocation(
                function: .contractFn(
                    InvokeContractArgs(
                        contractAddress: .contract(contractHash),
                        functionName: "write",
                        args: []
                    )
                ),
                subInvocations: []
            )
        )

        let (server, local, _) = try await makeRPCServer(responses: [
            "getLedgerEntries": [
                .rpcResult(GetLedgerEntriesResponse(
                    entries: [LedgerEntryResult(key: "account", xdr: accountXDR, lastModifiedLedgerSeq: 1)],
                    latestLedger: 50
                )),
            ],
            "simulateTransaction": [
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 50,
                    minResourceFee: "2",
                    results: [SimResult(auth: [try authEntry.toXDR().base64EncodedString()], xdr: nil)],
                    transactionData: txData
                )),
            ],
        ])
        defer { local.stop() }

        let assembled: AssembledTransaction<Void> = try await server.prepareTransaction(
            try invokeContract(contractId, function: "write") {},
            source: source,
            network: .testnet
        )

        #expect(assembled.needsNonInvokerSigningBy() == [cosignerAddress])

        let signedAuth = try assembled.signAuthEntries(for: cosignerAddress, with: cosigner)
        guard case .invokeHostFunction(let invoke) = signedAuth.transaction.operations[0].body else {
            Issue.record("Expected invoke host function operation")
            return
        }
        guard case .address(let credentials) = invoke.auth.first?.credentials else {
            Issue.record("Expected address credentials")
            return
        }
        guard case .bytes(let signature) = credentials.signature else {
            Issue.record("Expected signed auth payload")
            return
        }

        #expect(signature.count == 64)
    }

    @Test
    func integration_autoRestore_restorePreambleFlow() async throws {
        let signer = try seededKeyPair(start: 100)
        let source = signer.publicKey.stellarAddress
        let contractId = contractAddress(byte: 0x55)
        let accountXDR = try makeAccountLedgerEntryXDR(publicKey: source, sequence: 14)
        let restoreTxData = try makeTransactionDataBase64(resourceFee: 20)
        let finalTxData = try makeTransactionDataBase64(resourceFee: 8)

        let (server, local, recorder) = try await makeRPCServer(responses: [
            "getLedgerEntries": [
                .rpcResult(GetLedgerEntriesResponse(
                    entries: [LedgerEntryResult(key: "account", xdr: accountXDR, lastModifiedLedgerSeq: 1)],
                    latestLedger: 120
                )),
            ],
            "simulateTransaction": [
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 120,
                    restorePreamble: RestorePreamble(transactionData: restoreTxData, minResourceFee: 400)
                )),
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 121,
                    minResourceFee: "8",
                    results: [SimResult(auth: [], xdr: nil)],
                    transactionData: finalTxData
                )),
            ],
            "sendTransaction": [
                .rpcResult(SendTransactionResponse(
                    status: "PENDING",
                    hash: "restore-hash",
                    latestLedger: 120,
                    latestLedgerCloseTime: "2026-01-01T00:00:00Z"
                )),
            ],
        ])
        defer { local.stop() }

        let assembled: AssembledTransaction<Void> = try await server.prepareTransaction(
            try invokeContract(contractId, function: "restore-needed") {},
            source: source,
            network: .testnet
        )

        #expect(assembled.transaction.fee == 108)

        let restoreRequests = recorder.requests(forRPCMethod: "sendTransaction")
        #expect(restoreRequests.count == 1)

        let restoreEnvelope = try decodeEnvelope(from: restoreRequests[0])
        guard case .v1(let txEnvelope) = restoreEnvelope else {
            Issue.record("Expected v1 transaction envelope")
            return
        }
        guard case .restoreFootprint = txEnvelope.tx.operations[0].body else {
            Issue.record("Expected restore footprint operation")
            return
        }
    }

    @Test
    func integration_contractDeployment_uploadAndCreate() async throws {
        let signer = try seededKeyPair(start: 150)
        let source = signer.publicKey.stellarAddress
        let accountXDR = try makeAccountLedgerEntryXDR(publicKey: source, sequence: 3)
        let txDataUpload = try makeTransactionDataBase64(resourceFee: 5)
        let txDataCreate = try makeTransactionDataBase64(resourceFee: 7)
        let wasm = Data([0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00])

        let (server, local, _) = try await makeRPCServer(responses: [
            "getLedgerEntries": [
                .rpcResult(GetLedgerEntriesResponse(entries: [LedgerEntryResult(key: "a", xdr: accountXDR, lastModifiedLedgerSeq: 1)], latestLedger: 10)),
                .rpcResult(GetLedgerEntriesResponse(entries: [LedgerEntryResult(key: "a", xdr: accountXDR, lastModifiedLedgerSeq: 1)], latestLedger: 11)),
            ],
            "simulateTransaction": [
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 10,
                    minResourceFee: "5",
                    results: [SimResult(auth: [], xdr: nil)],
                    transactionData: txDataUpload
                )),
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 11,
                    minResourceFee: "7",
                    results: [SimResult(auth: [], xdr: nil)],
                    transactionData: txDataCreate
                )),
            ],
        ])
        defer { local.stop() }

        let deployment = try await server.deploy(
            wasm: wasm,
            source: source,
            network: .testnet
        )

        guard case .invokeHostFunction(let uploadOp) = deployment.upload.transaction.operations[0].body else {
            Issue.record("Expected invokeHostFunction for upload")
            return
        }
        guard case .uploadWasm(let uploadedWasm) = uploadOp.hostFunction else {
            Issue.record("Expected uploadWasm host function")
            return
        }
        #expect(uploadedWasm == wasm)

        guard case .invokeHostFunction(let createOp) = deployment.create.transaction.operations[0].body else {
            Issue.record("Expected invokeHostFunction for create")
            return
        }
        guard case .createContract = createOp.hostFunction else {
            Issue.record("Expected createContract host function")
            return
        }
    }

    @Test
    func integration_eventPolling_eventWatcherStream() async throws {
        let event1 = EventInfo(
            type: "contract",
            ledger: 1,
            id: "event-1",
            pagingToken: "p1",
            topic: ["counter"],
            value: "AAAA",
            inSuccessfulContractCall: true
        )
        let event2 = EventInfo(
            type: "contract",
            ledger: 2,
            id: "event-2",
            pagingToken: "p2",
            topic: ["counter"],
            value: "AAAB",
            inSuccessfulContractCall: true
        )

        let (server, local, _) = try await makeRPCServer(responses: [
            "getEvents": [
                .rpcResult(GetEventsResponse(events: [event1], latestLedger: 1)),
                .rpcResult(GetEventsResponse(events: [event2], latestLedger: 2)),
                .rpcResult(GetEventsResponse(events: [], latestLedger: 2)),
            ],
        ])
        defer { local.stop() }

        let watcher = EventWatcher(server: server, startLedger: 1, pollInterval: 0.01)

        let streamOne = await watcher.events()
        let first = try await nextEvent(from: streamOne)
        #expect(first.id == "event-1")
        await watcher.cancel()

        await watcher.resume()
        let streamTwo = await watcher.events()
        let second = try await nextEvent(from: streamTwo)
        #expect(second.id == "event-2")
        await watcher.cancel()
    }

    @Test
    func integration_ttlExtension_extendFootprintTTL() async throws {
        let signer = try seededKeyPair(start: 200)
        let source = signer.publicKey.stellarAddress
        let account = Account(publicKey: source, sequenceNumber: 12)

        let (server, local, recorder) = try await makeRPCServer(responses: [
            "sendTransaction": [
                .rpcResult(SendTransactionResponse(
                    status: "PENDING",
                    hash: "ttl-hash",
                    latestLedger: 9,
                    latestLedgerCloseTime: "2026-01-01T00:00:00Z"
                )),
            ],
            "getTransaction": [
                .rpcResult(GetTransactionResponse(status: "SUCCESS", latestLedger: 10)),
            ],
        ])
        defer { local.stop() }

        let sent = try await server.extendFootprintTTL(
            keys: [.contractCode(Data(repeating: 0xAB, count: 32))],
            extendTo: 7_777,
            sourceAccount: account,
            network: .testnet
        )

        let requests = recorder.requests(forRPCMethod: "sendTransaction")
        #expect(requests.count == 1)

        let envelope = try decodeEnvelope(from: requests[0])
        guard case .v1(let txEnvelope) = envelope else {
            Issue.record("Expected v1 transaction envelope")
            return
        }
        guard case .extendFootprintTTL(let op) = txEnvelope.tx.operations[0].body else {
            Issue.record("Expected extendFootprintTTL operation")
            return
        }
        #expect(op.extendTo == 7_777)

        try await sent.result()
    }

    @Test
    func integration_dslEndToEnd_transactionBuilderInvokeContract() async throws {
        let contractId = contractAddress(byte: 0x66)
        let source = try seededKeyPair(start: 33).publicKey.stellarAddress

        let call = try invokeContract(contractId, function: "hello") {
            UInt32(7)
            "world"
        }

        let tx = try TransactionBuilder.build(
            source: Account(publicKey: source, sequenceNumber: 90),
            network: .testnet,
            fee: 100
        ) {
            Operation(sourceAccount: nil, body: .invokeHostFunction(InvokeHostFunctionOp(hostFunction: call, auth: [])))
        }

        #expect(tx.seqNum == 91)

        guard case .invokeHostFunction(let body) = tx.operations[0].body else {
            Issue.record("Expected invoke host function")
            return
        }
        guard case .invokeContract(let args) = body.hostFunction else {
            Issue.record("Expected invoke contract host function")
            return
        }
        #expect(args.functionName == "hello")
        #expect(args.args.count == 2)
    }

    @Test
    func integration_jsonRoundTrip_toJSONFromJSON() async throws {
        let signer = try seededKeyPair(start: 77)
        let source = signer.publicKey.stellarAddress
        let contractId = contractAddress(byte: 0x77)
        let accountXDR = try makeAccountLedgerEntryXDR(publicKey: source, sequence: 6)
        let txData = try makeTransactionDataBase64(resourceFee: 9)

        let (server, local, _) = try await makeRPCServer(responses: [
            "getLedgerEntries": [
                .rpcResult(GetLedgerEntriesResponse(entries: [LedgerEntryResult(key: "a", xdr: accountXDR, lastModifiedLedgerSeq: 1)], latestLedger: 20)),
            ],
            "simulateTransaction": [
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 20,
                    minResourceFee: "9",
                    results: [SimResult(auth: [], xdr: nil)],
                    transactionData: txData
                )),
            ],
        ])
        defer { local.stop() }

        let assembled: AssembledTransaction<Void> = try await server.prepareTransaction(
            try invokeContract(contractId, function: "persist") {},
            source: source,
            network: .testnet
        )
        let signed = try assembled.signed(by: signer)

        let json = try signed.toJSON()
        let restored = try AssembledTransaction<Void>.fromJSON(json)

        #expect(restored.signatures == signed.signatures)
        #expect(restored.network.passphrase == signed.network.passphrase)
        #expect(restored.timeoutSeconds == signed.timeoutSeconds)
        #expect(restored.pollIntervalMilliseconds == signed.pollIntervalMilliseconds)
    }

    @Test
    func integration_feeVerification_basePlusResourceFee() async throws {
        let signer = try seededKeyPair(start: 90)
        let source = signer.publicKey.stellarAddress
        let contractId = contractAddress(byte: 0x90)
        let accountXDR = try makeAccountLedgerEntryXDR(publicKey: source, sequence: 1)
        let txData = try makeTransactionDataBase64(resourceFee: 333)

        let options = TransactionOptions(
            fee: 222,
            autoRestore: true,
            timeoutSeconds: 30,
            pollIntervalMilliseconds: 1_000,
            memo: .none
        )

        let (server, local, _) = try await makeRPCServer(responses: [
            "getLedgerEntries": [
                .rpcResult(GetLedgerEntriesResponse(entries: [LedgerEntryResult(key: "a", xdr: accountXDR, lastModifiedLedgerSeq: 1)], latestLedger: 88)),
            ],
            "simulateTransaction": [
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 88,
                    minResourceFee: "333",
                    results: [SimResult(auth: [], xdr: nil)],
                    transactionData: txData
                )),
            ],
        ])
        defer { local.stop() }

        let assembled: AssembledTransaction<Void> = try await server.prepareTransaction(
            try invokeContract(contractId, function: "fee-check") {},
            source: source,
            network: .testnet,
            options: options
        )

        #expect(assembled.transaction.fee == 555)
    }

    @Test
    func integration_friendbotAirdrop_testnet() async throws {
        let target = try seededKeyPair(start: 111).publicKey.stellarAddress
        let friendbotRecorder = RequestRecorder()

        let friendbot = try await LocalHTTPServer { request in
            friendbotRecorder.record(request)
            if request.method == "GET" {
                return .json(["ok": true])
            }
            return .status(405)
        }
        defer { friendbot.stop() }

        let (server, local, _) = try await makeRPCServer(responses: [
            "getNetwork": [
                .rpcResult(GetNetworkResponse(
                    friendbotUrl: friendbot.url.absoluteString,
                    passphrase: Network.testnet.passphrase,
                    protocolVersion: 22
                )),
            ],
        ])
        defer { local.stop() }

        try await server.requestAirdrop(for: target)

        let requests = friendbotRecorder.allRequests
        #expect(requests.count == 1)
        #expect(requests[0].method == "GET")
        #expect(requests[0].path.contains("addr="))
    }

    @Test
    func integration_errorHandling_invalidContractExpiredEntriesInsufficientBalance() async throws {
        let signer = try seededKeyPair(start: 130)
        let source = signer.publicKey.stellarAddress
        let contractId = contractAddress(byte: 0xAA)
        let accountXDR = try makeAccountLedgerEntryXDR(publicKey: source, sequence: 12)

        let (simulationFailServer, simulationFailLocal, _) = try await makeRPCServer(responses: [
            "getLedgerEntries": [
                .rpcResult(GetLedgerEntriesResponse(entries: [LedgerEntryResult(key: "a", xdr: accountXDR, lastModifiedLedgerSeq: 1)], latestLedger: 70)),
            ],
            "simulateTransaction": [
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 70,
                    error: "insufficient balance"
                )),
            ],
        ])
        defer { simulationFailLocal.stop() }

        do {
            _ = try await simulationFailServer.prepareTransaction(
                try invokeContract(contractId, function: "withdraw") {},
                source: source,
                network: .testnet
            ) as AssembledTransaction<Void>
            #expect(Bool(false), "Expected simulation failure")
        } catch let error as StarscreamError {
            guard case .simulationFailed(let reason, _) = error else {
                #expect(Bool(false), "Expected simulationFailed")
                return
            }
            #expect(reason.contains("insufficient"))
        }

        let txData = try makeTransactionDataBase64(resourceFee: 1)
        let (failedTxServer, failedTxLocal, _) = try await makeRPCServer(responses: [
            "getLedgerEntries": [
                .rpcResult(GetLedgerEntriesResponse(entries: [LedgerEntryResult(key: "a", xdr: accountXDR, lastModifiedLedgerSeq: 1)], latestLedger: 80)),
            ],
            "simulateTransaction": [
                .rpcResult(SimulateTransactionResponse(
                    latestLedger: 80,
                    minResourceFee: "1",
                    results: [SimResult(auth: [], xdr: nil)],
                    transactionData: txData
                )),
            ],
            "sendTransaction": [
                .rpcResult(SendTransactionResponse(
                    status: "PENDING",
                    hash: "failed-hash",
                    latestLedger: 80,
                    latestLedgerCloseTime: "2026-01-01T00:00:00Z"
                )),
            ],
            "getTransaction": [
                .rpcResult(GetTransactionResponse(status: "FAILED", latestLedger: 81)),
            ],
        ])
        defer { failedTxLocal.stop() }

        var options = TransactionOptions.default
        options.timeoutSeconds = 1
        options.pollIntervalMilliseconds = 10

        let assembled: AssembledTransaction<Void> = try await failedTxServer.prepareTransaction(
            try invokeContract(contractId, function: "withdraw") {},
            source: source,
            network: .testnet,
            options: options
        )
        let sent = try await assembled.signed(by: signer).send(using: failedTxServer)

        do {
            try await sent.result()
            #expect(Bool(false), "Expected transaction failure")
        } catch let error as StarscreamError {
            guard case .transactionFailed = error else {
                #expect(Bool(false), "Expected transactionFailed")
                return
            }
            #expect(Bool(true))
        }
    }
}

private enum IntegrationHarnessError: Error {
    case timeout
    case streamFinished
}

private func nextEvent(
    from stream: AsyncStream<Result<EventInfo, Error>>,
    timeoutNanoseconds: UInt64 = 1_000_000_000
) async throws -> EventInfo {
    try await withThrowingTaskGroup(of: EventInfo.self) { group in
        group.addTask {
            var iterator = stream.makeAsyncIterator()
            guard let result = await iterator.next() else {
                throw IntegrationHarnessError.streamFinished
            }
            switch result {
            case .success(let event):
                return event
            case .failure(let error):
                throw error
            }
        }

        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
            throw IntegrationHarnessError.timeout
        }

        let first = try await group.next()
        group.cancelAll()
        return try #require(first)
    }
}

private func seededKeyPair(start: UInt8) throws -> KeyPair {
    let seedBytes = Data((0..<32).map { start &+ UInt8($0) })
    let seed = StrKey.encode(seedBytes, version: .ed25519SecretSeed)
    return try KeyPair(secretSeed: seed)
}

private func contractAddress(byte: UInt8) -> String {
    StrKey.encode(Data(repeating: byte, count: 32), version: .contract)
}

private func makeTransactionDataBase64(resourceFee: Int64) throws -> String {
    let txData = SorobanTransactionData(
        ext: ExtensionPoint(),
        resources: SorobanResources(
            footprint: LedgerFootprint(readOnly: [], readWrite: []),
            instructions: 1,
            readBytes: 1,
            writeBytes: 1
        ),
        resourceFee: resourceFee
    )
    return try txData.toXDR().base64EncodedString()
}

private func makeSourceAccountAuthEntry(contractHash: Data) -> SorobanAuthorizationEntry {
    SorobanAuthorizationEntry(
        credentials: .sourceAccount,
        rootInvocation: SorobanAuthorizedInvocation(
            function: .contractFn(
                InvokeContractArgs(
                    contractAddress: .contract(contractHash),
                    functionName: "increment",
                    args: []
                )
            ),
            subInvocations: []
        )
    )
}

private func makeAccountLedgerEntryXDR(publicKey: String, sequence: Int64) throws -> String {
    let key = try PublicKey(strKey: publicKey)
    let account = AccountEntry(
        accountID: .ed25519(key.rawBytes),
        balance: 10,
        seqNum: sequence,
        numSubEntries: 0,
        inflationDest: nil,
        flags: 0,
        homeDomain: "",
        thresholds: Data([1, 0, 0, 0]),
        signers: [],
        ext: ExtensionPoint()
    )
    let ledgerEntry = LedgerEntry(
        lastModifiedLedgerSeq: 1,
        data: .account(account),
        ext: .v0
    )
    return try ledgerEntry.toXDR().base64EncodedString()
}

private func makeRPCServer(
    responses: [String: [StubHTTPResponse]]
) async throws -> (SorobanServer, LocalHTTPServer, RequestRecorder) {
    let recorder = RequestRecorder()
    let queue = MethodResponseQueue(responses: responses)

    let local = try await LocalHTTPServer { request in
        recorder.record(request)

        guard request.method == "POST" else {
            return .status(405)
        }
        guard let method = rpcMethod(from: request.body) else {
            return .status(400)
        }

        return queue.next(for: method)
    }

    return (SorobanServer(endpoint: local.url), local, recorder)
}

private func decodeEnvelope(from request: StubHTTPRequest) throws -> TransactionEnvelope {
    let params = try #require(rpcParams(from: request.body))
    let envelopeBase64 = try #require(params["transaction"] as? String)
    let envelopeData = try #require(Data(base64Encoded: envelopeBase64))
    return try TransactionEnvelope(xdr: envelopeData)
}

private func rpcParams(from body: Data) -> [String: Any]? {
    guard
        let object = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any],
        let params = object["params"] as? [String: Any]
    else {
        return nil
    }
    return params
}

private struct StubHTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

private struct StubHTTPResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    static func json(_ object: Any) -> StubHTTPResponse {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [])) ?? Data()
        return StubHTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: body
        )
    }

    static func rpcResult<T: Encodable>(_ result: T) -> StubHTTPResponse {
        let encodedResult = (try? jsonObject(from: result)) as Any
        return json([
            "jsonrpc": "2.0",
            "id": 1,
            "result": encodedResult,
        ])
    }

    static func status(_ code: Int) -> StubHTTPResponse {
        StubHTTPResponse(statusCode: code)
    }
}

private func jsonObject<T: Encodable>(from value: T) throws -> Any {
    let data = try JSONEncoder().encode(value)
    return try JSONSerialization.jsonObject(with: data, options: [])
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [StubHTTPRequest] = []

    var allRequests: [StubHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ request: StubHTTPRequest) {
        lock.lock()
        storage.append(request)
        lock.unlock()
    }

    func requests(forRPCMethod method: String) -> [StubHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storage.filter { request in
            rpcMethod(from: request.body) == method
        }
    }
}

private final class MethodResponseQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String: [StubHTTPResponse]]

    init(responses: [String: [StubHTTPResponse]]) {
        self.responses = responses
    }

    func next(for method: String) -> StubHTTPResponse {
        lock.lock()
        defer { lock.unlock() }

        guard var queue = responses[method], !queue.isEmpty else {
            return .json([
                "jsonrpc": "2.0",
                "id": 1,
                "error": [
                    "code": -32601,
                    "message": "Method not found",
                    "data": NSNull(),
                ],
            ])
        }

        let response = queue.removeFirst()
        responses[method] = queue
        return response
    }
}

private func rpcMethod(from body: Data) -> String? {
    guard
        let object = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any],
        let method = object["method"] as? String
    else {
        return nil
    }
    return method
}

private final class LocalHTTPServer: @unchecked Sendable {
    private enum ServerError: Error {
        case missingPort
        case invalidRequest
    }

    private final class ResumeState: @unchecked Sendable {
        var resumed = false
    }

    private final class ReceiveBuffer: @unchecked Sendable {
        var data = Data()
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "starscream.tests.integration.localhttp")
    private let handler: @Sendable (StubHTTPRequest) -> StubHTTPResponse

    private(set) var url: URL = URL(string: "http://127.0.0.1:0")!

    init(handler: @escaping @Sendable (StubHTTPRequest) -> StubHTTPResponse) async throws {
        self.listener = try NWListener(using: .tcp, on: .any)
        self.handler = handler

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        let endpoint = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let resumeState = ResumeState()
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    guard !resumeState.resumed else { return }
                    resumeState.resumed = true
                    guard let port = self.listener.port?.rawValue else {
                        continuation.resume(throwing: ServerError.missingPort)
                        return
                    }
                    continuation.resume(returning: URL(string: "http://127.0.0.1:\(port)")!)
                case .failed(let error):
                    guard !resumeState.resumed else { return }
                    resumeState.resumed = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            self.listener.start(queue: self.queue)
        }

        self.url = endpoint
    }

    func stop() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: ReceiveBuffer())
    }

    private func receive(on connection: NWConnection, buffer: ReceiveBuffer) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let data, !data.isEmpty {
                buffer.data.append(data)
            }

            do {
                if let request = try Self.parseRequest(from: buffer.data) {
                    let response = self.handler(request)
                    self.send(response, on: connection)
                    return
                }
            } catch {
                self.send(.status(400), on: connection)
                return
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }

            self.receive(on: connection, buffer: buffer)
        }
    }

    private func send(_ response: StubHTTPResponse, on connection: NWConnection) {
        var headers = response.headers
        headers["Content-Length"] = "\(response.body.count)"
        headers["Connection"] = "close"

        var http = "HTTP/1.1 \(response.statusCode) \(reasonPhrase(for: response.statusCode))\r\n"
        for (key, value) in headers {
            http += "\(key): \(value)\r\n"
        }
        http += "\r\n"

        var payload = Data(http.utf8)
        payload.append(response.body)

        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func parseRequest(from buffer: Data) throws -> StubHTTPRequest? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = buffer.range(of: separator) else {
            return nil
        }

        let headerData = buffer[..<range.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw ServerError.invalidRequest
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw ServerError.invalidRequest
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            throw ServerError.invalidRequest
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            let pieces = line.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2 else { continue }
            headers[String(pieces[0]).lowercased()] = pieces[1].trimmingCharacters(in: .whitespaces)
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = range.upperBound
        guard buffer.count >= bodyStart + contentLength else {
            return nil
        }

        let body = Data(buffer[bodyStart..<(bodyStart + contentLength)])
        return StubHTTPRequest(
            method: String(parts[0]),
            path: String(parts[1]),
            headers: headers,
            body: body
        )
    }

    private func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200:
            return "OK"
        case 400:
            return "Bad Request"
        case 405:
            return "Method Not Allowed"
        case 500:
            return "Internal Server Error"
        default:
            return "Status"
        }
    }
}
