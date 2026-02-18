import Crypto
import Foundation
import StarscreamXDR

public extension SorobanServer {
    func uploadContractWasm(
        _ wasm: Data,
        source: String,
        network: Network,
        options: TransactionOptions = .default
    ) async throws -> AssembledTransaction<Void> {
        try await prepareTransaction(
            .uploadWasm(wasm),
            source: source,
            network: network,
            options: options
        )
    }

    func createContract(
        contractIDPreimage: ContractIDPreimage,
        executable: ContractExecutable,
        source: String,
        network: Network,
        options: TransactionOptions = .default
    ) async throws -> AssembledTransaction<SCAddress> {
        let createArgs = CreateContractArgs(contractIDPreimage: contractIDPreimage, executable: executable)
        return try await prepareTransaction(
            .createContract(createArgs),
            source: source,
            network: network,
            options: options
        )
    }

    func deploy(
        wasm: Data,
        source: String,
        network: Network,
        options: TransactionOptions = .default
    ) async throws -> (upload: AssembledTransaction<Void>, create: AssembledTransaction<SCAddress>) {
        let upload = try await uploadContractWasm(wasm, source: source, network: network, options: options)

        let sourceKey = try PublicKey(strKey: source)
        let wasmHash = Data(SHA256.hash(data: wasm))
        let preimage = ContractIDPreimage.fromAddress(
            address: .account(.ed25519(sourceKey.rawBytes)),
            salt: Data(repeating: 0, count: 32)
        )
        let create = try await createContract(
            contractIDPreimage: preimage,
            executable: .wasm(wasmHash),
            source: source,
            network: network,
            options: options
        )

        return (upload, create)
    }
}
