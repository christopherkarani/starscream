import Foundation

public enum Network: Sendable, Hashable {
    case `public`
    case testnet
    case futurenet
    case custom(passphrase: String)

    public var passphrase: String {
        switch self {
        case .public:
            return "Public Global Stellar Network ; September 2015"
        case .testnet:
            return "Test SDF Network ; September 2015"
        case .futurenet:
            return "Test SDF Future Network ; October 2022"
        case .custom(let passphrase):
            return passphrase
        }
    }
}
