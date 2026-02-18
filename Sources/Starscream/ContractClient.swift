import Foundation
import StarscreamXDR

public struct ContractClient: Sendable {
    public let contractId: String
    public let server: SorobanServer
    public let network: Network
    public let source: String

    public init(contractId: String, server: SorobanServer, network: Network, source: String) {
        self.contractId = contractId
        self.server = server
        self.network = network
        self.source = source
    }

    public func invoke<T: ScValConvertible>(
        _ function: String,
        arguments: [ScVal] = [],
        options: TransactionOptions = .default
    ) async throws -> AssembledTransaction<T> {
        let contractAddress = try decodeContractAddress(contractId)
        let hostFunction = HostFunction.invokeContract(
            InvokeContractArgs(
                contractAddress: contractAddress,
                functionName: function,
                args: arguments
            )
        )

        return try await server.prepareTransaction(
            hostFunction,
            source: source,
            network: network,
            options: options
        )
    }

    private func decodeContractAddress(_ value: String) throws -> SCAddress {
        let decoded = try StrKey.decode(value)
        guard decoded.version == .contract else {
            throw StarscreamError.invalidFormat("contractId must be a C... StrKey contract address")
        }
        return .contract(decoded.data)
    }
}
