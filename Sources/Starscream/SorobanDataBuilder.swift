import Foundation
import StarscreamXDR

public struct SorobanDataBuilder: Sendable, Hashable {
    private var readOnly: [LedgerKey]
    private var readWrite: [LedgerKey]
    private var instructions: UInt32
    private var readBytes: UInt32
    private var writeBytes: UInt32
    private var resourceFee: Int64

    public init() {
        self.readOnly = []
        self.readWrite = []
        self.instructions = 0
        self.readBytes = 0
        self.writeBytes = 0
        self.resourceFee = 0
    }

    public func setReadOnly(_ keys: [LedgerKey]) -> SorobanDataBuilder {
        var copy = self
        copy.readOnly = keys
        return copy
    }

    public func setReadWrite(_ keys: [LedgerKey]) -> SorobanDataBuilder {
        var copy = self
        copy.readWrite = keys
        return copy
    }

    public func setInstructions(_ value: UInt32) -> SorobanDataBuilder {
        var copy = self
        copy.instructions = value
        return copy
    }

    public func setReadBytes(_ value: UInt32) -> SorobanDataBuilder {
        var copy = self
        copy.readBytes = value
        return copy
    }

    public func setWriteBytes(_ value: UInt32) -> SorobanDataBuilder {
        var copy = self
        copy.writeBytes = value
        return copy
    }

    public func setResourceFee(_ fee: Int64) -> SorobanDataBuilder {
        var copy = self
        copy.resourceFee = fee
        return copy
    }

    public func build() -> SorobanTransactionData {
        SorobanTransactionData(
            ext: ExtensionPoint(),
            resources: SorobanResources(
                footprint: LedgerFootprint(readOnly: readOnly, readWrite: readWrite),
                instructions: instructions,
                readBytes: readBytes,
                writeBytes: writeBytes
            ),
            resourceFee: resourceFee
        )
    }
}
