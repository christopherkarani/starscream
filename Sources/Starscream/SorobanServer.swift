import AsyncHTTPClient
import Foundation
import NIOCore
import StarscreamRPC
import StarscreamXDR

public actor SorobanServer {
    private struct EmptyParams: Codable, Sendable {
        init() {}
    }

    private let endpoint: URL
    private let httpClient: HTTPClient
    private let ownsHTTPClient: Bool
    private let rpc: RPCClient

    public init(endpoint: URL) {
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        self.endpoint = endpoint
        self.httpClient = client
        self.ownsHTTPClient = true
        self.rpc = RPCClient(endpoint: endpoint, httpClient: client)
    }

    public init(endpoint: URL, httpClient: HTTPClient) {
        self.endpoint = endpoint
        self.httpClient = httpClient
        self.ownsHTTPClient = false
        self.rpc = RPCClient(endpoint: endpoint, httpClient: httpClient)
    }

    deinit {
        if ownsHTTPClient {
            try? httpClient.syncShutdown()
        }
    }

    public func getAccount(_ id: String) async throws -> Account {
        do {
            let key = try PublicKey(strKey: id)
            let response = try await getLedgerEntries(keys: [.account(.ed25519(key.rawBytes))])

            guard let firstEntry = response.entries?.first else {
                return Account(publicKey: id, sequenceNumber: 0)
            }
            guard let xdr = Data(base64Encoded: firstEntry.xdr) else {
                throw StarscreamError.invalidFormat("Ledger entry XDR is not valid base64")
            }

            let decoded = try LedgerEntry(xdr: xdr)
            guard case .account(let accountEntry) = decoded.data else {
                throw StarscreamError.accountNotFound(id)
            }

            return Account(publicKey: id, sequenceNumber: accountEntry.seqNum)
        } catch let error as StarscreamError {
            if case .rpcError(let rpcError) = error, rpcError.code == -32603 {
                return Account(publicKey: id, sequenceNumber: 0)
            }
            throw error
        } catch let error as StrKeyError {
            throw StarscreamError.from(error)
        } catch let error as XDRDecodingError {
            throw StarscreamError.from(error)
        } catch {
            throw StarscreamError.networkError(error)
        }
    }

    public func getHealth() async throws -> GetHealthResponse {
        try await sendRPC(method: "getHealth", params: EmptyParams())
    }

    public func getLatestLedger() async throws -> GetLatestLedgerResponse {
        try await sendRPC(method: "getLatestLedger", params: EmptyParams())
    }

    public func getVersionInfo() async throws -> GetVersionInfoResponse {
        try await sendRPC(method: "getVersionInfo", params: EmptyParams())
    }

    public func getNetwork() async throws -> GetNetworkResponse {
        try await sendRPC(method: "getNetwork", params: EmptyParams())
    }

    public func getFeeStats() async throws -> GetFeeStatsResponse {
        try await sendRPC(method: "getFeeStats", params: GetFeeStatsRequest())
    }

    public func requestAirdrop(for address: String) async throws {
        let network = try await getNetwork()
        guard let friendbotURL = network.friendbotUrl else {
            throw StarscreamError.friendbotNotAvailable
        }

        let separator = friendbotURL.contains("?") ? "&" : "?"
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        let url = friendbotURL + separator + "addr=\(encodedAddress)"

        var request = HTTPClientRequest(url: url)
        request.method = .GET

        let response = try await httpClient.execute(request, timeout: .seconds(30))
        guard response.status == .ok else {
            throw StarscreamError.networkError(RPCClientError.invalidStatus(Int(response.status.code)))
        }
    }

    public func getLedgerEntries(keys: [LedgerKey]) async throws -> GetLedgerEntriesResponse {
        let encodedKeys = try keys.map { try $0.toXDR().base64EncodedString() }
        return try await sendRPC(method: "getLedgerEntries", params: GetLedgerEntriesRequest(keys: encodedKeys))
    }

    public func getLedgers(startLedger: Int, pagination: PaginationOptions? = nil) async throws -> GetLedgersResponse {
        try await sendRPC(
            method: "getLedgers",
            params: GetLedgersRequest(startLedger: startLedger, pagination: pagination)
        )
    }

    public func sendTransaction(_ envelope: TransactionEnvelope) async throws -> SendTransactionResponse {
        let envelopeXDR = try envelope.toXDR().base64EncodedString()
        return try await sendRPC(method: "sendTransaction", params: SendTransactionRequest(transaction: envelopeXDR))
    }

    public func getTransaction(hash: String) async throws -> GetTransactionResponse {
        try await sendRPC(method: "getTransaction", params: GetTransactionRequest(hash: hash))
    }

    public func getTransactions(startLedger: Int, pagination: PaginationOptions? = nil) async throws -> GetTransactionsResponse {
        try await sendRPC(
            method: "getTransactions",
            params: GetTransactionsRequest(startLedger: startLedger, pagination: pagination)
        )
    }

    public func simulateTransaction(
        _ envelope: TransactionEnvelope,
        resourceConfig: ResourceConfig? = nil
    ) async throws -> SimulateTransactionResponse {
        let envelopeXDR = try envelope.toXDR().base64EncodedString()
        let request = SimulateTransactionRequest(transaction: envelopeXDR, resourceConfig: resourceConfig)
        return try await sendRPC(method: "simulateTransaction", params: request)
    }

    public func getEvents(
        startLedger: Int? = nil,
        filters: [EventFilter]? = nil,
        pagination: PaginationOptions? = nil
    ) async throws -> GetEventsResponse {
        try await sendRPC(
            method: "getEvents",
            params: GetEventsRequest(startLedger: startLedger, filters: filters, pagination: pagination)
        )
    }

    public func prepareTransaction<T>(
        _ call: HostFunction,
        source: String,
        network: Network,
        options: TransactionOptions = .default
    ) async throws -> AssembledTransaction<T> {
        let account = try await getAccount(source)
        let sourceKey = try PublicKey(strKey: source)

        let tx = Transaction(
            sourceAccount: .ed25519(sourceKey.rawBytes),
            fee: options.fee,
            seqNum: account.sequenceNumber + 1,
            cond: .none,
            memo: options.memo,
            operations: [Operation(sourceAccount: nil, body: .invokeHostFunction(.init(hostFunction: call, auth: [])))],
            ext: .v0
        )

        let initialEnvelope = TransactionEnvelope.v1(TransactionV1Envelope(tx: tx, signatures: []))
        var simulation = try await simulateTransaction(initialEnvelope, resourceConfig: nil)

        if let preamble = simulation.restorePreamble {
            if options.autoRestore {
                _ = try await handleRestore(
                    preamble: preamble,
                    sourceAccount: account,
                    network: network,
                    server: self
                )
                simulation = try await simulateTransaction(initialEnvelope, resourceConfig: nil)
            } else {
                throw StarscreamError.restoreRequired(preamble: preamble)
            }
        }

        if let error = simulation.error {
            throw StarscreamError.simulationFailed(error: error, events: [])
        }

        let assembledTransaction = try assembleTransaction(tx, simulation)
        return AssembledTransaction<T>(
            transaction: assembledTransaction,
            simulationResult: simulation,
            network: network
        )
    }

    private func sendRPC<Response: Decodable, Params: Encodable & Sendable>(
        method: String,
        params: Params
    ) async throws -> Response {
        do {
            return try await rpc.send(method, params: params)
        } catch let error as RPCClientError {
            throw mapRPCError(error)
        } catch {
            throw StarscreamError.networkError(error)
        }
    }

    private func mapRPCError(_ error: RPCClientError) -> StarscreamError {
        switch error {
        case .rpcError(let code, let message, let data):
            return .rpcError(RPCError(code: code, message: message, data: data))
        case .malformedResponse:
            return .invalidFormat("Malformed JSON-RPC response")
        case .missingResponseBody:
            return .invalidFormat("JSON-RPC response body is missing")
        case .invalidStatus(let statusCode):
            return .networkError(RPCClientError.invalidStatus(statusCode))
        }
    }
}
