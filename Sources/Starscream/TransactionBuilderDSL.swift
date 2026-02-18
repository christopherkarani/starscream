import StarscreamXDR

public typealias XDROperation = StarscreamXDR.Operation

@resultBuilder
public enum TransactionContentBuilder {
    public static func buildBlock(_ components: [XDROperation]...) -> [XDROperation] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: XDROperation) -> [XDROperation] {
        [expression]
    }

    public static func buildExpression(_ expression: [XDROperation]) -> [XDROperation] {
        expression
    }

    public static func buildOptional(_ component: [XDROperation]?) -> [XDROperation] {
        component ?? []
    }

    public static func buildEither(first component: [XDROperation]) -> [XDROperation] {
        component
    }

    public static func buildEither(second component: [XDROperation]) -> [XDROperation] {
        component
    }

    public static func buildArray(_ components: [[XDROperation]]) -> [XDROperation] {
        components.flatMap { $0 }
    }
}

@resultBuilder
public enum FunctionArgumentBuilder {
    public static func buildBlock(_ components: [ScVal]...) -> [ScVal] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: ScVal) -> [ScVal] {
        [expression]
    }

    public static func buildExpression<T: ScValConvertible>(_ expression: T) -> [ScVal] {
        guard let value = try? expression.toScVal() else {
            preconditionFailure("Unable to convert argument to ScVal")
        }
        return [value]
    }

    public static func buildOptional(_ component: [ScVal]?) -> [ScVal] {
        component ?? []
    }

    public static func buildEither(first component: [ScVal]) -> [ScVal] {
        component
    }

    public static func buildEither(second component: [ScVal]) -> [ScVal] {
        component
    }

    public static func buildArray(_ components: [[ScVal]]) -> [ScVal] {
        components.flatMap { $0 }
    }
}

public func invokeContract(
    _ contractId: String,
    function: String,
    @FunctionArgumentBuilder arguments: () -> [ScVal] = { [] }
) -> HostFunction {
    let decoded = try? StrKey.decode(contractId)
    guard let decoded, decoded.version == .contract else {
        preconditionFailure("contractId must be a C... StrKey contract address")
    }

    return .invokeContract(
        InvokeContractArgs(
            contractAddress: .contract(decoded.data),
            functionName: function,
            args: arguments()
        )
    )
}

public enum TransactionBuilder {
    public static func build(
        source: Account,
        network: Network,
        fee: UInt32,
        @TransactionContentBuilder content: () -> [XDROperation]
    ) throws -> Transaction {
        let sourceKey = try PublicKey(strKey: source.publicKey)
        return Transaction(
            sourceAccount: .ed25519(sourceKey.rawBytes),
            fee: fee,
            seqNum: source.sequenceNumber + 1,
            cond: .none,
            memo: .none,
            operations: content(),
            ext: .v0
        )
    }
}
