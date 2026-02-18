import Testing
@testable import Starscream
import Foundation

@Test func phase0_packageLayout_expectedFilesExist() async throws {
    let requiredFiles = [
        "Package.swift",
        "Sources/Starscream/Network.swift",
        "Sources/StarscreamXDR/Codec/XDREncoder.swift",
        "Sources/StarscreamRPC/RPCClient.swift",
        "Sources/StarscreamMacros/Macros.swift",
        "Sources/StarscreamMacrosImpl/MacroImpl.swift",
        "Sources/StarscreamCLI/main.swift",
        "Tests/StarscreamXDRTests/XDRTests.swift",
        "Tests/StarscreamMacrosTests/MacroTests.swift",
        "Tests/StarscreamTests/IntegrationTests.swift",
    ]

    for file in requiredFiles {
        #expect(FileManager.default.fileExists(atPath: file), "\(file) should exist")
    }
}
