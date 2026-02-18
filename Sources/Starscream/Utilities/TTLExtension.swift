import Foundation
import StarscreamXDR

public extension SorobanServer {
    func extendFootprintTTL(
        keys: [LedgerKey],
        extendTo: UInt32,
        sourceAccount: Account,
        network: Network
    ) async throws -> SentTransaction<Void> {
        let sourceKey = try PublicKey(strKey: sourceAccount.publicKey)

        let txData = SorobanDataBuilder()
            .setReadWrite(keys)
            .build()

        let tx = Transaction(
            sourceAccount: .ed25519(sourceKey.rawBytes),
            fee: 100,
            seqNum: sourceAccount.sequenceNumber + 1,
            cond: .none,
            memo: .none,
            operations: [
                Operation(
                    sourceAccount: nil,
                    body: .extendFootprintTTL(ExtendFootprintTTLOp(ext: ExtensionPoint(), extendTo: extendTo))
                )
            ],
            ext: .v1(txData)
        )

        let envelope = TransactionEnvelope.v1(TransactionV1Envelope(tx: tx, signatures: []))
        let response = try await sendTransaction(envelope)
        return SentTransaction<Void>(hash: response.hash, server: self)
    }
}
