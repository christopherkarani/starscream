import Foundation
import StarscreamRPC
import StarscreamXDR

public struct SentTransaction<T>: Sendable {
    public let hash: String
    private let server: SorobanServer

    init(hash: String, server: SorobanServer) {
        self.hash = hash
        self.server = server
    }

    public func status() async throws -> GetTransactionResponse {
        try await server.getTransaction(hash: hash)
    }

    public func result() async throws -> T where T: ScValConvertible {
        for _ in 0..<120 {
            let current = try await status()

            switch current.status.uppercased() {
            case "SUCCESS":
                guard let returnValue = current.returnValue else {
                    throw StarscreamError.invalidState("Transaction succeeded but returnValue is missing")
                }
                guard let valueData = Data(base64Encoded: returnValue) else {
                    throw StarscreamError.invalidFormat("Transaction returnValue is not valid base64")
                }

                let scVal = try ScVal(xdr: valueData)
                return try T(fromScVal: scVal)

            case "FAILED", "ERROR":
                throw StarscreamError.transactionFailed(result: current, events: [])

            default:
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        throw StarscreamError.timeout("Timed out waiting for transaction \(hash)")
    }

    public func result() async throws where T == Void {
        for _ in 0..<120 {
            let current = try await status()
            switch current.status.uppercased() {
            case "SUCCESS":
                return
            case "FAILED", "ERROR":
                throw StarscreamError.transactionFailed(result: current, events: [])
            default:
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        throw StarscreamError.timeout("Timed out waiting for transaction \(hash)")
    }
}
