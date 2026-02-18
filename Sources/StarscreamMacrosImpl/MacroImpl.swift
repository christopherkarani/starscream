import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

public struct ContractClientMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard case .argumentList(let arguments) = node.arguments else {
            return []
        }

        let specArgument = arguments.first { $0.label?.text == "spec" } ?? arguments.first
        guard
            let expression = specArgument?.expression.as(StringLiteralExprSyntax.self),
            let base64 = expression.representedLiteralValue
        else {
            return ["public static let __contractSpecEntriesCount: Int = 0"]
        }

        let entries = (try? MinimalXDRDecoder.decodeSpecEntries(base64: base64)) ?? []
        var generated: [DeclSyntax] = []

        for entry in entries {
            switch entry {
            case .functionV0(let functionSpec):
                generated.append(generateFunction(from: functionSpec))
            case .udtStructV0(let structSpec):
                generated.append(generateStruct(from: structSpec))
            case .udtEnumV0(let enumSpec):
                generated.append(generateEnum(from: enumSpec))
            case .udtUnionV0(let unionSpec):
                generated.append(generateUnion(from: unionSpec))
            case .udtErrorEnumV0(let errorSpec):
                generated.append(generateErrorEnum(from: errorSpec))
            }
        }

        if generated.isEmpty {
            generated.append("public static let __contractSpecEntriesCount: Int = 0")
        }

        return generated
    }

    private static func generateFunction(from spec: MinimalSCSpecFunctionV0) -> DeclSyntax {
        let methodName = escapeIdentifier(spec.name)
        let parameterDecls = spec.inputs.map { input in
            "\(escapeIdentifier(input.name)): \(swiftType(for: input.type))"
        }

        var signatureParameters: [String] = [
            "source: String",
            "options: TransactionOptions = .default",
        ]
        signatureParameters.append(contentsOf: parameterDecls)

        let returnType = spec.outputs.first.map(swiftType(for:)) ?? "Void"
        let argumentLines = spec.inputs
            .map { "            \(escapeIdentifier($0.name))" }
            .joined(separator: "\n")

        let body: String
        if argumentLines.isEmpty {
            body = """
                let function = invokeContract(self.contractId, function: "\(spec.name)") {
                }
            """
        } else {
            body = """
                let function = invokeContract(self.contractId, function: "\(spec.name)") {
            \(argumentLines)
                }
            """
        }

        return DeclSyntax(stringLiteral: """
        public func \(methodName)(\(signatureParameters.joined(separator: ", "))) async throws -> AssembledTransaction<\(returnType)> {
        \(body)
            return try await self.server.prepareTransaction(function, source: source, network: self.network, options: options)
        }
        """)
    }

    private static func generateStruct(from spec: MinimalSCSpecUDTStructV0) -> DeclSyntax {
        let name = sanitizeTypeName(spec.name)
        let fields = spec.fields.map { field in
            (name: escapeIdentifier(field.name), type: swiftType(for: field.type))
        }

        let fieldDecls = fields
            .map { "    public let \($0.name): \($0.type)" }
            .joined(separator: "\n")

        if fields.isEmpty {
            return DeclSyntax(stringLiteral: """
            public struct \(name): Sendable, Hashable {
                public init() {}
            }
            """)
        }

        let params = fields.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
        let assignments = fields.map { "        self.\($0.name) = \($0.name)" }.joined(separator: "\n")

        return DeclSyntax(stringLiteral: """
        public struct \(name): Sendable, Hashable {
        \(fieldDecls)

            public init(\(params)) {
        \(assignments)
            }
        }
        """)
    }

    private static func generateEnum(from spec: MinimalSCSpecUDTEnumV0) -> DeclSyntax {
        let name = sanitizeTypeName(spec.name)
        let cases = spec.cases
            .map { "    case \(escapeIdentifier($0.name)) = \($0.value)" }
            .joined(separator: "\n")

        return DeclSyntax(stringLiteral: """
        public enum \(name): UInt32, Sendable {
        \(cases)
        }
        """)
    }

    private static func generateUnion(from spec: MinimalSCSpecUDTUnionV0) -> DeclSyntax {
        let name = sanitizeTypeName(spec.name)
        let cases = spec.cases
            .map { "    case \(escapeIdentifier($0.name))(\(swiftType(for: $0.type)))" }
            .joined(separator: "\n")

        return DeclSyntax(stringLiteral: """
        public enum \(name): Sendable {
        \(cases)
        }
        """)
    }

    private static func generateErrorEnum(from spec: MinimalSCSpecUDTErrorEnumV0) -> DeclSyntax {
        let name = sanitizeTypeName(spec.name)
        let cases = spec.cases
            .map { "    case \(escapeIdentifier($0.name)) = \($0.value)" }
            .joined(separator: "\n")

        return DeclSyntax(stringLiteral: """
        public enum \(name): UInt32, Error, Sendable {
        \(cases)
        }
        """)
    }

    private static func swiftType(for type: MinimalSCSpecTypeDef) -> String {
        switch type {
        case .val:
            return "ScVal"
        case .bool:
            return "Bool"
        case .void:
            return "Void"
        case .error:
            return "SCError"
        case .u32:
            return "UInt32"
        case .i32:
            return "Int32"
        case .u64:
            return "UInt64"
        case .i64:
            return "Int64"
        case .timepoint, .duration:
            return "UInt64"
        case .u128:
            return "StellarUInt128"
        case .i128:
            return "StellarInt128"
        case .u256:
            return "UInt256"
        case .i256:
            return "Int256"
        case .bytes:
            return "Data"
        case .string, .symbol:
            return "String"
        case .address, .muxedAddress:
            return "SCAddress"
        case .option(let wrapped):
            return "\(swiftType(for: wrapped))?"
        case .result(let ok, let error):
            return "Result<\(swiftType(for: ok)), \(swiftType(for: error))>"
        case .vec(let element):
            return "[\(swiftType(for: element))]"
        case .map(let key, let value):
            return "[(\(swiftType(for: key)), \(swiftType(for: value)))]"
        case .tuple:
            return "ScVal"
        case .bytesN:
            return "Data"
        case .udt(let name):
            return sanitizeTypeName(name)
        }
    }

    private static func sanitizeTypeName(_ raw: String) -> String {
        let parts = raw
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { part in
                guard let first = part.first else { return "" }
                return String(first).uppercased() + part.dropFirst()
            }
        let combined = parts.joined()
        return combined.isEmpty ? "GeneratedType" : combined
    }

    private static func escapeIdentifier(_ raw: String) -> String {
        let sanitized = sanitizeIdentifier(raw)
        if swiftKeywords.contains(sanitized) {
            return "`\(sanitized)`"
        }
        return sanitized
    }

    private static func sanitizeIdentifier(_ raw: String) -> String {
        let mapped = raw.map { char -> Character in
            if char.isLetter || char.isNumber || char == "_" {
                return char
            }
            return "_"
        }
        var value = String(mapped)
        if value.isEmpty {
            value = "value"
        }
        if let first = value.first, first.isNumber {
            value = "_\(value)"
        }
        return value
    }

    private static let swiftKeywords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "func", "import",
        "init", "inout", "internal", "let", "operator", "private", "protocol",
        "public", "static", "struct", "subscript", "typealias", "var", "break",
        "case", "continue", "default", "defer", "do", "else", "fallthrough", "for",
        "guard", "if", "in", "repeat", "return", "switch", "where", "while", "as",
        "Any", "false", "is", "nil", "rethrows", "super", "self", "Self", "throw",
        "throws", "true", "try",
    ]
}

@main
struct StarscreamMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ContractClientMacro.self,
    ]
}
