import Foundation
import StarscreamRPC
import StarscreamXDR

public struct AssembledTransaction<T>: Sendable, Hashable {
    public let transaction: Transaction
    public let simulationResult: SimulateTransactionResponse
    public let network: Network
    public let signatures: [DecoratedSignature]

    public init(
        transaction: Transaction,
        simulationResult: SimulateTransactionResponse,
        network: Network,
        signatures: [DecoratedSignature] = []
    ) {
        self.transaction = transaction
        self.simulationResult = simulationResult
        self.network = network
        self.signatures = signatures
    }

    public var isReadCall: Bool {
        (simulationResult.results?.first?.auth ?? []).isEmpty
    }

    public func needsNonInvokerSigningBy() -> [SCAddress] {
        let invoker: SCAddress? = {
            switch transaction.sourceAccount {
            case .ed25519(let key):
                return .account(.ed25519(key))
            case .muxedEd25519(let id, let key):
                return .muxedAccount(MuxedEd25519Account(id: id, ed25519: key))
            }
        }()

        let authBase64 = simulationResult.results?.first?.auth ?? []
        var seen = Set<SCAddress>()
        var ordered: [SCAddress] = []

        for encoded in authBase64 {
            guard
                let authData = Data(base64Encoded: encoded),
                let entry = try? SorobanAuthorizationEntry(xdr: authData),
                case .address(let credentials) = entry.credentials
            else {
                continue
            }

            if credentials.address == invoker {
                continue
            }

            if seen.insert(credentials.address).inserted {
                ordered.append(credentials.address)
            }
        }

        return ordered
    }

    public func signed(by keyPair: KeyPair) throws -> AssembledTransaction<T> {
        let decoratedSignature = try keyPair.signTransaction(
            transaction,
            networkPassphrase: network.passphrase
        )
        return AssembledTransaction(
            transaction: transaction,
            simulationResult: simulationResult,
            network: network,
            signatures: signatures + [decoratedSignature]
        )
    }

    public func signAuthEntries(for address: SCAddress, with signer: KeyPair) throws -> AssembledTransaction<T> {
        guard !transaction.operations.isEmpty else {
            throw StarscreamError.invalidState("Transaction has no operations")
        }

        var updatedTransaction = transaction
        guard case .invokeHostFunction(var invokeOperation) = updatedTransaction.operations[0].body else {
            throw StarscreamError.invalidState("First operation is not invokeHostFunction")
        }

        invokeOperation.auth = try invokeOperation.auth.map { auth in
            guard case .address(let credentials) = auth.credentials, credentials.address == address else {
                return auth
            }
            return try authorizeEntry(auth, with: signer, network: network)
        }

        updatedTransaction.operations[0].body = .invokeHostFunction(invokeOperation)
        return AssembledTransaction(
            transaction: updatedTransaction,
            simulationResult: simulationResult,
            network: network,
            signatures: signatures
        )
    }

    public func send(using server: SorobanServer) async throws -> SentTransaction<T> {
        let envelope = TransactionEnvelope.v1(
            TransactionV1Envelope(tx: transaction, signatures: signatures)
        )
        let response = try await server.sendTransaction(envelope)
        return SentTransaction(hash: response.hash, server: server)
    }
}
