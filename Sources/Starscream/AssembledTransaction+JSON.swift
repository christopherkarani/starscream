import Foundation
import StarscreamRPC
import StarscreamXDR

public struct AssembledTransactionJSON: Codable, Sendable {
    public let xdr: String
    public let simulationResult: SimulateTransactionResponse
    public let signatures: [String]
    public let networkPassphrase: String

    public init(
        xdr: String,
        simulationResult: SimulateTransactionResponse,
        signatures: [String],
        networkPassphrase: String
    ) {
        self.xdr = xdr
        self.simulationResult = simulationResult
        self.signatures = signatures
        self.networkPassphrase = networkPassphrase
    }
}

public extension AssembledTransaction {
    func toJSON() throws -> String {
        let jsonStruct = AssembledTransactionJSON(
            xdr: try transaction.toXDR().base64EncodedString(),
            simulationResult: simulationResult,
            signatures: signatures.map { $0.signature.base64EncodedString() },
            networkPassphrase: network.passphrase
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(jsonStruct)
        guard let string = String(data: jsonData, encoding: .utf8) else {
            throw StarscreamError.invalidState("Unable to encode assembled transaction JSON as UTF-8")
        }
        return string
    }

    static func fromJSON(_ json: String) throws -> AssembledTransaction<T> {
        let jsonData = Data(json.utf8)
        let jsonStruct = try JSONDecoder().decode(AssembledTransactionJSON.self, from: jsonData)

        guard let xdrBytes = Data(base64Encoded: jsonStruct.xdr) else {
            throw StarscreamError.invalidFormat("AssembledTransaction JSON contains invalid base64 XDR")
        }
        let transaction = try Transaction(xdr: xdrBytes)

        let decoratedSignatures = try jsonStruct.signatures.map { encoded in
            guard let signature = Data(base64Encoded: encoded) else {
                throw StarscreamError.invalidFormat("AssembledTransaction JSON contains invalid base64 signature")
            }
            return DecoratedSignature(hint: Data(repeating: 0, count: 4), signature: signature)
        }

        return AssembledTransaction(
            transaction: transaction,
            simulationResult: jsonStruct.simulationResult,
            network: .custom(passphrase: jsonStruct.networkPassphrase),
            signatures: decoratedSignatures
        )
    }
}
