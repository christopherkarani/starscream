import Foundation
import StarscreamRPC
import StarscreamXDR

internal func handleRestore(
    preamble: RestorePreamble,
    sourceAccount: Account,
    network: Network,
    server: SorobanServer
) async throws -> SentTransaction<Void> {
    guard let txDataBytes = Data(base64Encoded: preamble.transactionData) else {
        throw StarscreamError.invalidFormat("restorePreamble.transactionData is not valid base64")
    }

    let txData = try SorobanTransactionData(xdr: txDataBytes)

    let sourceKey: PublicKey
    do {
        sourceKey = try PublicKey(strKey: sourceAccount.publicKey)
    } catch let error as StrKeyError {
        throw StarscreamError.from(error)
    } catch let error as KeyPairError {
        throw StarscreamError.from(error)
    } catch {
        throw StarscreamError.invalidFormat("Invalid source account public key")
    }

    let restoreTx = Transaction(
        sourceAccount: .ed25519(sourceKey.rawBytes),
        fee: UInt32(clamping: preamble.minResourceFee),
        seqNum: sourceAccount.sequenceNumber + 1,
        cond: .none,
        memo: .none,
        operations: [
            Operation(
                sourceAccount: nil,
                body: .restoreFootprint(RestoreFootprintOp(ext: ExtensionPoint()))
            )
        ],
        ext: .v1(txData)
    )

    let envelope = TransactionEnvelope.v1(TransactionV1Envelope(tx: restoreTx, signatures: []))
    let response = try await server.sendTransaction(envelope)
    return SentTransaction<Void>(hash: response.hash, server: server)
}
