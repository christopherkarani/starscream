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

    private func singleFunctionSpecBase64(functionName: String) -> String {
        var data = Data()
        data.append(xdrUInt32(1))
        data.append(xdrInt32(0))
        data.append(xdrString(functionName))
        data.append(xdrUInt32(0))
        data.append(xdrUInt32(0))
        return data.base64EncodedString()
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
