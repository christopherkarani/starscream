import ArgumentParser
import Foundation
import StarscreamRPC
import StarscreamXDR

private enum CLIError: Error, CustomStringConvertible {
    case invalidRPCURL(String)
    case invalidContractID
    case missingLedgerEntry(String)
    case invalidLedgerEntry(String)
    case missingContractSpecSection
    case invalidWASM
    case malformedLEB128

    var description: String {
        switch self {
        case .invalidRPCURL(let value):
            return "Invalid RPC URL: \(value)"
        case .invalidContractID:
            return "contractId must be a C... StrKey contract address"
        case .missingLedgerEntry(let details):
            return "Missing ledger entry: \(details)"
        case .invalidLedgerEntry(let details):
            return "Invalid ledger entry: \(details)"
        case .missingContractSpecSection:
            return "WASM does not contain a contractspec custom section"
        case .invalidWASM:
            return "Invalid WASM binary"
        case .malformedLEB128:
            return "Malformed varuint32 in WASM section"
        }
    }
}

@main
struct StarscreamCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "starscream-cli",
        abstract: "Generate typed contract clients from Soroban contracts"
    )

    @Argument(help: "The contract ID to generate a client for.")
    var contractId: String

    @Option(name: .long, help: "The RPC endpoint of a Soroban node.")
    var rpcUrl: String

    @Option(name: .long, help: "The output file path.")
    var outputPath: String

    mutating func run() async throws {
        guard let endpoint = URL(string: rpcUrl) else {
            throw CLIError.invalidRPCURL(rpcUrl)
        }

        let (contractHash, version) = try StrKey.decode(contractId)
        guard version == .contract else {
            throw CLIError.invalidContractID
        }

        let rpc = RPCClient(endpoint: endpoint)

        let instanceKey = LedgerKey.contractData(
            contract: contractHash,
            key: .ledgerKeyContractInstance,
            durability: .persistent
        )
        let contractInstanceEntry = try await fetchLedgerEntry(rpc: rpc, key: instanceKey)
        let wasmHash = try extractWasmHash(from: contractInstanceEntry)

        let codeEntry = try await fetchLedgerEntry(rpc: rpc, key: .contractCode(wasmHash))
        let wasmBinary = try extractWasmBinary(from: codeEntry)

        let specBytes = try extractContractSpecSection(from: wasmBinary)
        let base64Spec = specBytes.base64EncodedString()
        let generatedSwift = renderClientFile(contractId: contractId, specBase64: base64Spec)

        try generatedSwift.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Generated client at \(outputPath)")
    }

    private func fetchLedgerEntry(rpc: RPCClient, key: LedgerKey) async throws -> LedgerEntry {
        let keyBase64 = try key.toXDR().base64EncodedString()
        let response: GetLedgerEntriesResponse = try await rpc.send(
            "getLedgerEntries",
            params: GetLedgerEntriesRequest(keys: [keyBase64])
        )

        guard let entry = response.entries?.first else {
            throw CLIError.missingLedgerEntry("\(key)")
        }
        guard let xdr = Data(base64Encoded: entry.xdr) else {
            throw CLIError.invalidLedgerEntry("xdr is not base64")
        }
        return try LedgerEntry(xdr: xdr)
    }

    private func extractWasmHash(from ledgerEntry: LedgerEntry) throws -> Hash {
        guard case .contractData(let dataEntry) = ledgerEntry.data else {
            throw CLIError.invalidLedgerEntry("Expected contractData ledger entry")
        }
        guard case .contractInstance(let instance) = dataEntry.val else {
            throw CLIError.invalidLedgerEntry("Expected ScVal.contractInstance")
        }
        guard case .wasm(let hash) = instance.executable else {
            throw CLIError.invalidLedgerEntry("Expected ContractExecutable.wasm")
        }
        return hash
    }

    private func extractWasmBinary(from ledgerEntry: LedgerEntry) throws -> Data {
        guard case .contractCode(let codeEntry) = ledgerEntry.data else {
            throw CLIError.invalidLedgerEntry("Expected contractCode ledger entry")
        }
        return codeEntry.code
    }

    private func extractContractSpecSection(from wasm: Data) throws -> Data {
        let bytes = Array(wasm)
        guard bytes.count >= 8 else {
            throw CLIError.invalidWASM
        }

        let magic = Array(bytes[0..<4])
        let version = Array(bytes[4..<8])
        guard magic == [0x00, 0x61, 0x73, 0x6D], version == [0x01, 0x00, 0x00, 0x00] else {
            throw CLIError.invalidWASM
        }

        var index = 8
        while index < bytes.count {
            let sectionID = bytes[index]
            index += 1

            let sectionSize = try readVarUInt32(bytes, &index)
            guard index + sectionSize <= bytes.count else {
                throw CLIError.invalidWASM
            }

            let sectionStart = index
            let sectionEnd = index + sectionSize

            if sectionID == 0 {
                var sectionCursor = sectionStart
                let nameLength = try readVarUInt32(bytes, &sectionCursor)
                guard sectionCursor + nameLength <= sectionEnd else {
                    throw CLIError.invalidWASM
                }

                let nameBytes = Array(bytes[sectionCursor..<(sectionCursor + nameLength)])
                guard let sectionName = String(bytes: nameBytes, encoding: .utf8) else {
                    throw CLIError.invalidWASM
                }
                sectionCursor += nameLength

                if sectionName == "contractspecv0" || sectionName == "contractspec" {
                    return Data(bytes[sectionCursor..<sectionEnd])
                }
            }

            index = sectionEnd
        }

        throw CLIError.missingContractSpecSection
    }

    private func readVarUInt32(_ bytes: [UInt8], _ index: inout Int) throws -> Int {
        var result = 0
        var shift = 0

        while index < bytes.count {
            let byte = Int(bytes[index])
            index += 1

            result |= (byte & 0x7F) << shift
            if (byte & 0x80) == 0 {
                return result
            }

            shift += 7
            if shift > 35 {
                throw CLIError.malformedLEB128
            }
        }

        throw CLIError.malformedLEB128
    }

    private func renderClientFile(contractId: String, specBase64: String) -> String {
        let baseName = String(contractId.prefix(8))
        let clientName = sanitizeTypeName(baseName + "Client")

        return """
        import Starscream

        @ContractClient(spec: "\(specBase64)")
        public struct \(clientName) {
            public let contractId: String
            public let server: SorobanServer
            public let network: Network

            public init(contractId: String = "\(contractId)", server: SorobanServer, network: Network) {
                self.contractId = contractId
                self.server = server
                self.network = network
            }
        }
        """
    }

    private func sanitizeTypeName(_ raw: String) -> String {
        let components = raw.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let value = components
            .map { part -> String in
                guard let first = part.first else { return "" }
                return String(first).uppercased() + part.dropFirst()
            }
            .joined()
        return value.isEmpty ? "GeneratedContractClient" : value
    }
}
