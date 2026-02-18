import Foundation

public struct Account: Sendable, Hashable {
    public let publicKey: String
    public var sequenceNumber: Int64

    public init(publicKey: String, sequenceNumber: Int64) {
        self.publicKey = publicKey
        self.sequenceNumber = sequenceNumber
    }

    public mutating func incrementSequenceNumber() {
        sequenceNumber += 1
    }
}
