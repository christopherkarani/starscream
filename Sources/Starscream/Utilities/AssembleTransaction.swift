import Foundation
import StarscreamRPC
import StarscreamXDR

internal func assembleTransaction(
    _ tx: Transaction,
    _ simulation: SimulateTransactionResponse
) throws -> Transaction {
    var newTx = tx

    if let transactionDataBase64 = simulation.transactionData {
        guard let transactionDataBytes = Data(base64Encoded: transactionDataBase64) else {
            throw StarscreamError.invalidFormat("simulateTransaction.transactionData is not valid base64")
        }
        let sorobanData = try SorobanTransactionData(xdr: transactionDataBytes)
        newTx.ext = .v1(sorobanData)
    }

    if !newTx.operations.isEmpty,
       case .invokeHostFunction(var invokeOp) = newTx.operations[0].body {
        let encodedAuthEntries = simulation.results?.first?.auth ?? []
        invokeOp.auth = try encodedAuthEntries.map { authBase64 in
            guard let authData = Data(base64Encoded: authBase64) else {
                throw StarscreamError.invalidFormat("simulateTransaction.auth entry is not valid base64")
            }
            do {
                return try SorobanAuthorizationEntry(xdr: authData)
            } catch let decodeError as XDRDecodingError {
                throw StarscreamError.from(decodeError)
            }
        }
        newTx.operations[0].body = .invokeHostFunction(invokeOp)
    }

    let resourceFee = Int64(simulation.minResourceFee ?? "0") ?? 0
    newTx.fee = tx.fee + UInt32(clamping: resourceFee)

    return newTx
}
