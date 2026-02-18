import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import StarscreamMacrosImpl

final class MacroTests: XCTestCase {
    private let macros: [String: Macro.Type] = [
        "ContractClient": ContractClientMacro.self,
    ]

    func testContractClientMacro_emptySpecGeneratesCountMember() {
        assertMacroExpansion(
            """
            @ContractClient(spec: "AAAAAA==")
            struct ExampleClient {
                let contractId: String
                let server: SorobanServer
                let network: Network
            }
            """,
            expandedSource: """
            struct ExampleClient {
                let contractId: String
                let server: SorobanServer
                let network: Network

                public static let __contractSpecEntriesCount: Int = 0
            }
            """,
            macros: macros
        )
    }

    func testContractClientMacro_generatesFunctionMember() {
        let spec = singleFunctionSpecBase64(functionName: "hello")

        assertMacroExpansion(
            """
            @ContractClient(spec: "\(spec)")
            struct ExampleClient {
                let contractId: String
                let server: SorobanServer
                let network: Network
            }
            """,
            expandedSource: """
            struct ExampleClient {
                let contractId: String
                let server: SorobanServer
                let network: Network

                public func hello(source: String, options: TransactionOptions = .default) async throws -> AssembledTransaction<Void> {
                    let function = invokeContract(self.contractId, function: "hello") {
                    }
                    return try await self.server.prepareTransaction(function, source: source, network: self.network, options: options)
                }
            }
            """,
            macros: macros
        )
    }

    func testContractClientMacro_generatesStructAndEnumMembers() {
        let spec = structAndEnumSpecBase64()

        assertMacroExpansion(
            """
            @ContractClient(spec: "\(spec)")
            struct ExampleClient {
                let contractId: String
                let server: SorobanServer
                let network: Network
            }
            """,
            expandedSource: """
            struct ExampleClient {
                let contractId: String
                let server: SorobanServer
                let network: Network

                public struct Meta: Sendable, Hashable {
                    public let decimals: UInt32

                    public init(decimals: UInt32) {
                        self.decimals = decimals
                    }
                }

                public enum Err: UInt32, Sendable {
                    case oops = 1
                }
            }
            """,
            macros: macros
        )
    }

    private func singleFunctionSpecBase64(functionName: String) -> String {
        var data = Data()
        data.append(xdrUInt32(1)) // spec entry count
        data.append(functionEntry(functionName))
        return data.base64EncodedString()
    }

    private func structAndEnumSpecBase64() -> String {
        var data = Data()
        data.append(xdrUInt32(2))

        // SCSpecEntry.udtStructV0
        data.append(xdrInt32(1))
        data.append(xdrString("Meta"))
        data.append(xdrUInt32(1)) // one field
        data.append(xdrString("decimals"))
        data.append(xdrInt32(4)) // SC_SPEC_TYPE_U32

        // SCSpecEntry.udtEnumV0
        data.append(xdrInt32(3))
        data.append(xdrString("Err"))
        data.append(xdrUInt32(1))
        data.append(xdrString("oops"))
        data.append(xdrUInt32(1))

        return data.base64EncodedString()
    }

    private func functionEntry(_ functionName: String) -> Data {
        var data = Data()
        data.append(xdrInt32(0)) // SCSpecEntry.functionV0
        data.append(xdrString(functionName))
        data.append(xdrUInt32(0)) // inputs
        data.append(xdrUInt32(0)) // outputs
        return data
    }

    private func xdrInt32(_ value: Int32) -> Data {
        var big = value.bigEndian
        return Data(bytes: &big, count: MemoryLayout<Int32>.size)
    }

    private func xdrUInt32(_ value: UInt32) -> Data {
        xdrInt32(Int32(bitPattern: value))
    }

    private func xdrString(_ value: String) -> Data {
        let bytes = Data(value.utf8)
        var data = Data()
        data.append(xdrUInt32(UInt32(bytes.count)))
        data.append(bytes)
        let padding = (4 - (bytes.count % 4)) % 4
        if padding > 0 {
            data.append(Data(repeating: 0, count: padding))
        }
        return data
    }
}
