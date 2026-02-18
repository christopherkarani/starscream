import Foundation

// MARK: - Supporting Types

public struct ResourceConfig: Codable, Sendable, Hashable {
    public let instructionLeeway: UInt32?

    public init(instructionLeeway: UInt32? = nil) {
        self.instructionLeeway = instructionLeeway
    }
}

public struct PaginationOptions: Codable, Sendable, Hashable {
    public let cursor: String?
    public let limit: Int?

    public init(cursor: String? = nil, limit: Int? = nil) {
        self.cursor = cursor
        self.limit = limit
    }
}

public struct RestorePreamble: Codable, Sendable, Hashable {
    public let transactionData: String
    public let minResourceFee: Int64

    public init(transactionData: String, minResourceFee: Int64) {
        self.transactionData = transactionData
        self.minResourceFee = minResourceFee
    }
}

public struct SimResult: Codable, Sendable, Hashable {
    public let auth: [String]?
    public let xdr: String?

    public init(auth: [String]? = nil, xdr: String? = nil) {
        self.auth = auth
        self.xdr = xdr
    }
}

public struct StateChange: Codable, Sendable, Hashable {
    public let type: String
    public let key: String
    public let before: String?
    public let after: String?

    public init(type: String, key: String, before: String? = nil, after: String? = nil) {
        self.type = type
        self.key = key
        self.before = before
        self.after = after
    }
}

public struct EventInfo: Codable, Sendable, Hashable {
    public let type: String
    public let ledger: Int
    public let ledgerClosedAt: String?
    public let contractId: String?
    public let id: String
    public let pagingToken: String
    public let topic: [String]
    public let value: String
    public let inSuccessfulContractCall: Bool
    public let txHash: String?

    public init(
        type: String,
        ledger: Int,
        ledgerClosedAt: String? = nil,
        contractId: String? = nil,
        id: String,
        pagingToken: String,
        topic: [String],
        value: String,
        inSuccessfulContractCall: Bool,
        txHash: String? = nil
    ) {
        self.type = type
        self.ledger = ledger
        self.ledgerClosedAt = ledgerClosedAt
        self.contractId = contractId
        self.id = id
        self.pagingToken = pagingToken
        self.topic = topic
        self.value = value
        self.inSuccessfulContractCall = inSuccessfulContractCall
        self.txHash = txHash
    }
}

public struct LedgerEntryResult: Codable, Sendable, Hashable {
    public let key: String
    public let xdr: String
    public let lastModifiedLedgerSeq: Int
    public let liveUntilLedgerSeq: Int?

    public init(key: String, xdr: String, lastModifiedLedgerSeq: Int, liveUntilLedgerSeq: Int? = nil) {
        self.key = key
        self.xdr = xdr
        self.lastModifiedLedgerSeq = lastModifiedLedgerSeq
        self.liveUntilLedgerSeq = liveUntilLedgerSeq
    }
}

public struct FeeDistribution: Codable, Sendable, Hashable {
    public let max: String
    public let min: String
    public let mode: String
    public let p10: String
    public let p20: String
    public let p30: String
    public let p40: String
    public let p50: String
    public let p60: String
    public let p70: String
    public let p80: String
    public let p90: String
    public let p95: String
    public let p99: String
    public let transactionCount: String
    public let ledgerCount: Int

    public init(
        max: String,
        min: String,
        mode: String,
        p10: String,
        p20: String,
        p30: String,
        p40: String,
        p50: String,
        p60: String,
        p70: String,
        p80: String,
        p90: String,
        p95: String,
        p99: String,
        transactionCount: String,
        ledgerCount: Int
    ) {
        self.max = max
        self.min = min
        self.mode = mode
        self.p10 = p10
        self.p20 = p20
        self.p30 = p30
        self.p40 = p40
        self.p50 = p50
        self.p60 = p60
        self.p70 = p70
        self.p80 = p80
        self.p90 = p90
        self.p95 = p95
        self.p99 = p99
        self.transactionCount = transactionCount
        self.ledgerCount = ledgerCount
    }

    public var maxFee: Int64? { Int64(max) }
    public var minFee: Int64? { Int64(min) }
    public var modeFee: Int64? { Int64(mode) }
}

public struct SimulationCost: Codable, Sendable, Hashable {
    public let cpuInsns: String
    public let memBytes: String

    public init(cpuInsns: String, memBytes: String) {
        self.cpuInsns = cpuInsns
        self.memBytes = memBytes
    }
}

public struct LedgerInfo: Codable, Sendable, Hashable {
    public let id: String?
    public let hash: String?
    public let sequence: Int?
    public let protocolVersion: Int?
    public let ledgerCloseTime: String?
    public let headerXdr: String?

    public init(
        id: String? = nil,
        hash: String? = nil,
        sequence: Int? = nil,
        protocolVersion: Int? = nil,
        ledgerCloseTime: String? = nil,
        headerXdr: String? = nil
    ) {
        self.id = id
        self.hash = hash
        self.sequence = sequence
        self.protocolVersion = protocolVersion
        self.ledgerCloseTime = ledgerCloseTime
        self.headerXdr = headerXdr
    }
}

public struct TransactionInfo: Codable, Sendable, Hashable {
    public let status: String
    public let txHash: String
    public let applicationOrder: Int?
    public let feeBump: Bool?
    public let envelopeXdr: String?
    public let resultXdr: String?
    public let resultMetaXdr: String?
    public let ledger: Int?
    public let createdAt: String?

    public init(
        status: String,
        txHash: String,
        applicationOrder: Int? = nil,
        feeBump: Bool? = nil,
        envelopeXdr: String? = nil,
        resultXdr: String? = nil,
        resultMetaXdr: String? = nil,
        ledger: Int? = nil,
        createdAt: String? = nil
    ) {
        self.status = status
        self.txHash = txHash
        self.applicationOrder = applicationOrder
        self.feeBump = feeBump
        self.envelopeXdr = envelopeXdr
        self.resultXdr = resultXdr
        self.resultMetaXdr = resultMetaXdr
        self.ledger = ledger
        self.createdAt = createdAt
    }
}

// MARK: - Request Types

public struct SimulateTransactionRequest: Codable, Sendable, Hashable {
    public let transaction: String
    public let resourceConfig: ResourceConfig?

    public init(transaction: String, resourceConfig: ResourceConfig? = nil) {
        self.transaction = transaction
        self.resourceConfig = resourceConfig
    }
}

public struct GetEventsRequest: Codable, Sendable, Hashable {
    public let startLedger: Int?
    public let filters: [EventFilter]?
    public let pagination: PaginationOptions?

    public init(startLedger: Int? = nil, filters: [EventFilter]? = nil, pagination: PaginationOptions? = nil) {
        self.startLedger = startLedger
        self.filters = filters
        self.pagination = pagination
    }
}

public struct EventFilterTopic: Codable, Sendable, Hashable {
    public let segments: [String]

    public init(segments: [String]) {
        self.segments = segments
    }
}

public struct EventFilter: Codable, Sendable, Hashable {
    public let type: String?
    public let contractIds: [String]?
    public let topics: [[String]]?

    public init(type: String? = nil, contractIds: [String]? = nil, topics: [[String]]? = nil) {
        self.type = type
        self.contractIds = contractIds
        self.topics = topics
    }
}

public struct GetLedgerEntriesRequest: Codable, Sendable, Hashable {
    public let keys: [String]

    public init(keys: [String]) {
        self.keys = keys
    }
}

public struct SendTransactionRequest: Codable, Sendable, Hashable {
    public let transaction: String

    public init(transaction: String) {
        self.transaction = transaction
    }
}

public struct GetTransactionRequest: Codable, Sendable, Hashable {
    public let hash: String

    public init(hash: String) {
        self.hash = hash
    }
}

public struct GetTransactionsRequest: Codable, Sendable, Hashable {
    public let startLedger: Int
    public let pagination: PaginationOptions?

    public init(startLedger: Int, pagination: PaginationOptions? = nil) {
        self.startLedger = startLedger
        self.pagination = pagination
    }
}

public struct GetLedgersRequest: Codable, Sendable, Hashable {
    public let startLedger: Int
    public let pagination: PaginationOptions?

    public init(startLedger: Int, pagination: PaginationOptions? = nil) {
        self.startLedger = startLedger
        self.pagination = pagination
    }
}

public struct GetFeeStatsRequest: Codable, Sendable, Hashable {
    public init() {}
}

// MARK: - Response Types

public struct GetHealthResponse: Codable, Sendable, Hashable {
    public let status: String

    public init(status: String) {
        self.status = status
    }
}

public struct GetNetworkResponse: Codable, Sendable, Hashable {
    public let friendbotUrl: String?
    public let passphrase: String
    public let protocolVersion: Int

    public init(friendbotUrl: String? = nil, passphrase: String, protocolVersion: Int) {
        self.friendbotUrl = friendbotUrl
        self.passphrase = passphrase
        self.protocolVersion = protocolVersion
    }
}

public struct GetLatestLedgerResponse: Codable, Sendable, Hashable {
    public let id: String
    public let protocolVersion: Int
    public let sequence: Int

    public init(id: String, protocolVersion: Int, sequence: Int) {
        self.id = id
        self.protocolVersion = protocolVersion
        self.sequence = sequence
    }
}

public struct GetLedgerEntriesResponse: Codable, Sendable, Hashable {
    public let entries: [LedgerEntryResult]?
    public let latestLedger: Int

    public init(entries: [LedgerEntryResult]? = nil, latestLedger: Int) {
        self.entries = entries
        self.latestLedger = latestLedger
    }
}

public struct SendTransactionResponse: Codable, Sendable, Hashable {
    public let status: String
    public let hash: String
    public let latestLedger: Int
    public let latestLedgerCloseTime: String
    public let errorResultXdr: String?
    public let diagnosticEventsXdr: [String]?

    public init(
        status: String,
        hash: String,
        latestLedger: Int,
        latestLedgerCloseTime: String,
        errorResultXdr: String? = nil,
        diagnosticEventsXdr: [String]? = nil
    ) {
        self.status = status
        self.hash = hash
        self.latestLedger = latestLedger
        self.latestLedgerCloseTime = latestLedgerCloseTime
        self.errorResultXdr = errorResultXdr
        self.diagnosticEventsXdr = diagnosticEventsXdr
    }
}

public struct GetTransactionResponse: Codable, Sendable, Hashable {
    public let status: String
    public let latestLedger: Int
    public let latestLedgerCloseTime: String?
    public let oldestLedger: Int?
    public let oldestLedgerCloseTime: String?
    public let applicationOrder: Int?
    public let feeBump: Bool?
    public let envelopeXdr: String?
    public let resultXdr: String?
    public let resultMetaXdr: String?
    public let returnValue: String?
    public let ledger: Int?
    public let createdAt: String?

    public init(
        status: String,
        latestLedger: Int,
        latestLedgerCloseTime: String? = nil,
        oldestLedger: Int? = nil,
        oldestLedgerCloseTime: String? = nil,
        applicationOrder: Int? = nil,
        feeBump: Bool? = nil,
        envelopeXdr: String? = nil,
        resultXdr: String? = nil,
        resultMetaXdr: String? = nil,
        returnValue: String? = nil,
        ledger: Int? = nil,
        createdAt: String? = nil
    ) {
        self.status = status
        self.latestLedger = latestLedger
        self.latestLedgerCloseTime = latestLedgerCloseTime
        self.oldestLedger = oldestLedger
        self.oldestLedgerCloseTime = oldestLedgerCloseTime
        self.applicationOrder = applicationOrder
        self.feeBump = feeBump
        self.envelopeXdr = envelopeXdr
        self.resultXdr = resultXdr
        self.resultMetaXdr = resultMetaXdr
        self.returnValue = returnValue
        self.ledger = ledger
        self.createdAt = createdAt
    }
}

public struct GetTransactionsResponse: Codable, Sendable, Hashable {
    public let transactions: [TransactionInfo]
    public let latestLedger: Int

    public init(transactions: [TransactionInfo], latestLedger: Int) {
        self.transactions = transactions
        self.latestLedger = latestLedger
    }
}

public struct GetLedgersResponse: Codable, Sendable, Hashable {
    public let ledgers: [LedgerInfo]
    public let latestLedger: Int

    public init(ledgers: [LedgerInfo], latestLedger: Int) {
        self.ledgers = ledgers
        self.latestLedger = latestLedger
    }
}

public struct GetFeeStatsResponse: Codable, Sendable, Hashable {
    public let sorobanInclusionFee: FeeDistribution
    public let inclusionFee: FeeDistribution
    public let latestLedger: Int

    public init(sorobanInclusionFee: FeeDistribution, inclusionFee: FeeDistribution, latestLedger: Int) {
        self.sorobanInclusionFee = sorobanInclusionFee
        self.inclusionFee = inclusionFee
        self.latestLedger = latestLedger
    }
}

public struct GetVersionInfoResponse: Codable, Sendable, Hashable {
    public let version: String
    public let commitHash: String
    public let buildTimestamp: String
    public let captiveCoreVersion: String
    public let protocolVersion: Int

    public init(
        version: String,
        commitHash: String,
        buildTimestamp: String,
        captiveCoreVersion: String,
        protocolVersion: Int
    ) {
        self.version = version
        self.commitHash = commitHash
        self.buildTimestamp = buildTimestamp
        self.captiveCoreVersion = captiveCoreVersion
        self.protocolVersion = protocolVersion
    }
}

public struct GetEventsResponse: Codable, Sendable, Hashable {
    public let events: [EventInfo]
    public let latestLedger: Int

    public init(events: [EventInfo], latestLedger: Int) {
        self.events = events
        self.latestLedger = latestLedger
    }
}

public struct SimulateTransactionResponse: Codable, Sendable, Hashable {
    public let latestLedger: Int
    public let minResourceFee: String?
    public let results: [SimResult]?
    public let transactionData: String?
    public let restorePreamble: RestorePreamble?
    public let stateChanges: [StateChange]?
    public let error: String?
    public let events: [String]?
    public let cost: SimulationCost?

    public init(
        latestLedger: Int,
        minResourceFee: String? = nil,
        results: [SimResult]? = nil,
        transactionData: String? = nil,
        restorePreamble: RestorePreamble? = nil,
        stateChanges: [StateChange]? = nil,
        error: String? = nil,
        events: [String]? = nil,
        cost: SimulationCost? = nil
    ) {
        self.latestLedger = latestLedger
        self.minResourceFee = minResourceFee
        self.results = results
        self.transactionData = transactionData
        self.restorePreamble = restorePreamble
        self.stateChanges = stateChanges
        self.error = error
        self.events = events
        self.cost = cost
    }
}
