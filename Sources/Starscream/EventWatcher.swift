import Foundation
import StarscreamRPC

public actor EventWatcher {
    private let server: SorobanServer
    private let startLedger: Int?
    private var cursor: String?
    private var isCancelled = false
    private let pollIntervalSeconds: TimeInterval
    private var pollTask: Task<Void, Never>?

    public init(
        server: SorobanServer,
        startLedger: Int? = nil,
        pollInterval: TimeInterval = 2
    ) {
        self.server = server
        self.startLedger = startLedger
        self.pollIntervalSeconds = pollInterval
    }

    public func cancel() {
        isCancelled = true
        cancelPollingTask()
    }

    public func resume() {
        isCancelled = false
    }

    public func events(filters: [EventFilter] = []) -> AsyncStream<Result<EventInfo, Error>> {
        let (stream, continuation) = AsyncStream.makeStream(of: Result<EventInfo, Error>.self)

        cancelPollingTask()
        let task = Task {
            await self.pollLoop(filters: filters, continuation: continuation)
        }
        pollTask = task

        continuation.onTermination = { _ in
            Task {
                await self.cancelPollingTask()
            }
        }

        return stream
    }

    private func pollLoop(
        filters: [EventFilter],
        continuation: AsyncStream<Result<EventInfo, Error>>.Continuation
    ) async {
        defer { pollTask = nil }

        while !isCancelled && !Task.isCancelled {
            do {
                let response = try await server.getEvents(
                    startLedger: cursor == nil ? startLedger : nil,
                    filters: filters.isEmpty ? nil : filters,
                    pagination: PaginationOptions(cursor: cursor, limit: 10)
                )

                for event in response.events {
                    continuation.yield(.success(event))
                    cursor = event.pagingToken
                }

                let nanos = UInt64(max(0, pollIntervalSeconds) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanos)
            } catch {
                continuation.yield(.failure(error))
                continuation.finish()
                return
            }
        }

        continuation.finish()
    }

    private func cancelPollingTask() {
        pollTask?.cancel()
        pollTask = nil
    }
}
