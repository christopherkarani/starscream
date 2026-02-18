import Foundation
import StarscreamXDR

public struct TransactionOptions: Sendable, Hashable {
    public var fee: UInt32
    public var autoRestore: Bool
    public var timeoutSeconds: UInt32
    public var memo: Memo

    public static let `default` = TransactionOptions(
        fee: 100,
        autoRestore: true,
        timeoutSeconds: 30,
        memo: .none
    )

    public init(
        fee: UInt32 = 100,
        autoRestore: Bool = true,
        timeoutSeconds: UInt32 = 30,
        memo: Memo = .none
    ) {
        self.fee = fee
        self.autoRestore = autoRestore
        self.timeoutSeconds = timeoutSeconds
        self.memo = memo
    }
}
