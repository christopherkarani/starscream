import AsyncHTTPClient
import Foundation
import NIOCore

public enum RPCClientError: Error, Sendable {
    case invalidStatus(Int)
    case missingResponseBody
    case malformedResponse
    case rpcError(code: Int, message: String, data: String?)
}

public final class RPCClient: Sendable {
    private let httpClient: HTTPClient
    private let endpoint: URL
    private let timeout: TimeAmount
    private let ownsHTTPClient: Bool

    public init(endpoint: URL, httpClient: HTTPClient? = nil, timeout: TimeAmount = .seconds(30)) {
        if let httpClient {
            self.httpClient = httpClient
            self.ownsHTTPClient = false
        } else {
            self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
            self.ownsHTTPClient = true
        }
        self.endpoint = endpoint
        self.timeout = timeout
    }

    deinit {
        if ownsHTTPClient {
            try? httpClient.syncShutdown()
        }
    }

    public func send<R: Decodable>(_ method: String, params: Encodable) async throws -> R {
        let payload = JSONRPCRequest(
            jsonrpc: "2.0",
            id: requestID(),
            method: method,
            params: AnyEncodable(params)
        )
        let body = try JSONEncoder().encode(payload)

        var request = HTTPClientRequest(url: endpoint.absoluteString)
        request.method = .POST
        request.headers.add(name: "content-type", value: "application/json")
        request.body = .bytes(body)

        let response = try await httpClient.execute(request, timeout: timeout)
        guard response.status == .ok else {
            throw RPCClientError.invalidStatus(Int(response.status.code))
        }

        let bytes = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let data = Data(bytes.readableBytesView)

        let decoded = try JSONDecoder().decode(JSONRPCResponse<R>.self, from: data)
        if let error = decoded.error {
            throw RPCClientError.rpcError(code: error.code, message: error.message, data: error.data)
        }
        guard let result = decoded.result else {
            throw RPCClientError.malformedResponse
        }
        return result
    }

    private func requestID() -> Int {
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let random = Int.random(in: 0...65_535)
        return millis ^ random
    }
}

private struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeBlock = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}

private struct JSONRPCRequest<Params: Encodable>: Encodable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: Params
}

private struct JSONRPCResponse<Result: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int?
    let result: Result?
    let error: JSONRPCError?
}

private struct JSONRPCError: Decodable, Sendable {
    let code: Int
    let message: String
    let data: String?
}
