// swift-tools-version:6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Starscream",
    platforms: [.macOS(.v12), .iOS(.v15), .watchOS(.v8), .tvOS(.v15), .visionOS(.v1)],
    products: [
        .library(name: "Starscream", targets: ["Starscream"]),
        .executable(name: "starscream-cli", targets: ["StarscreamCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.25.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "602.0.0-prerelease"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    ],
    targets: [
        .target(name: "Starscream", dependencies: [
            "StarscreamXDR", "StarscreamRPC", "StarscreamMacros",
            .product(name: "Crypto", package: "swift-crypto"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
            .product(name: "OrderedCollections", package: "swift-collections"),
        ]),
        .target(name: "StarscreamXDR", dependencies: [
            .product(name: "Crypto", package: "swift-crypto"),
        ]),
        .target(name: "StarscreamRPC", dependencies: [
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
        .target(name: "StarscreamMacros", dependencies: ["StarscreamMacrosImpl"]),
        .macro(name: "StarscreamMacrosImpl", dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        ]),
        .executableTarget(name: "StarscreamCLI", dependencies: [
            "StarscreamXDR",
            "StarscreamRPC",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "StarscreamTests", dependencies: ["Starscream"]),
        .testTarget(name: "StarscreamXDRTests", dependencies: ["StarscreamXDR"]),
        .testTarget(name: "StarscreamMacrosTests", dependencies: [
            "StarscreamMacrosImpl",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        ]),
    ]
)
