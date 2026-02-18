import Crypto
import Foundation
import StarscreamXDR

internal func authorizeEntry(
    _ entry: SorobanAuthorizationEntry,
    with signer: KeyPair,
    network: Network
) throws -> SorobanAuthorizationEntry {
    guard case .address(let credentials) = entry.credentials else {
        return entry
    }

    let networkID = Data(SHA256.hash(data: Data(network.passphrase.utf8)))
    let preimage = HashIDPreimage.sorobanAuthorization(
        HashIDPreimageSorobanAuthorization(
            networkID: networkID,
            nonce: credentials.nonce,
            signatureExpirationLedger: credentials.signatureExpirationLedger,
            invocation: entry.rootInvocation
        )
    )
    let preimageXDR = try preimage.toXDR()
    let payload = Data(SHA256.hash(data: preimageXDR))
    let signature = try signer.sign(payload)

    var updatedCredentials = credentials
    updatedCredentials.signature = .bytes(signature)
    return SorobanAuthorizationEntry(
        credentials: .address(updatedCredentials),
        rootInvocation: entry.rootInvocation
    )
}
