import Testing
@testable import Starscream

@Suite("Integration Tests")
struct IntegrationTests {
    @Test(.disabled("Requires Stellar testnet access"))
    func integration_readOnlyCall_isReadCallTrue() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_writeCall_signSendPollSuccess() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_multiPartySigning_signAuthEntries() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_autoRestore_restorePreambleFlow() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_contractDeployment_uploadAndCreate() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_eventPolling_eventWatcherStream() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_ttlExtension_extendFootprintTTL() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_dslEndToEnd_transactionBuilderInvokeContract() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_jsonRoundTrip_toJSONFromJSON() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_feeVerification_basePlusResourceFee() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_friendbotAirdrop_testnet() async throws {}

    @Test(.disabled("Requires Stellar testnet access"))
    func integration_errorHandling_invalidContractExpiredEntriesInsufficientBalance() async throws {}
}
