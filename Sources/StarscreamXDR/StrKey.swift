import Foundation

public enum StrKeyError: Error, Sendable, Equatable, Hashable {
    case invalidBase32
    case invalidLength
    case checksumMismatch
    case unknownVersionByte(UInt8)
    case invalidPayloadLength(expected: Int, actual: Int)
}

public enum StrKey: Sendable {
    public enum VersionByte: UInt8, Sendable, CaseIterable {
        case ed25519PublicKey = 48
        case ed25519SecretSeed = 144
        case preAuthTx = 152
        case sha256Hash = 184
        case muxedAccount = 96
        case signedPayload = 120
        case contract = 16
    }

    public static func encode(_ data: Data, version: VersionByte) -> String {
        var payload = Data([version.rawValue])
        payload.append(data)

        let checksum = crc16xmodem(payload)
        payload.append(UInt8(checksum & 0x00FF))
        payload.append(UInt8((checksum & 0xFF00) >> 8))

        return base32Encode(payload)
    }

    public static func decode(_ strKey: String) throws -> (data: Data, version: VersionByte) {
        let decoded = try base32Decode(strKey)
        guard decoded.count >= 3 else {
            throw StrKeyError.invalidLength
        }

        let payloadEnd = decoded.count - 2
        let payload = decoded.prefix(payloadEnd)
        let checksumBytes = decoded.suffix(2)
        let expectedChecksum = UInt16(checksumBytes[checksumBytes.startIndex])
            | (UInt16(checksumBytes[checksumBytes.index(after: checksumBytes.startIndex)]) << 8)
        let actualChecksum = crc16xmodem(Data(payload))
        guard expectedChecksum == actualChecksum else {
            throw StrKeyError.checksumMismatch
        }

        let versionRaw = payload[payload.startIndex]
        guard let version = VersionByte(rawValue: versionRaw) else {
            throw StrKeyError.unknownVersionByte(versionRaw)
        }

        let content = Data(payload.dropFirst())
        try validateLength(content.count, for: version)
        return (content, version)
    }

    static func crc16xmodem(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0x0000
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                if (crc & 0x8000) != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
    }

    static func base32Encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var buffer: UInt32 = 0
        var bitCount = 0
        var output = String()
        output.reserveCapacity((data.count * 8 + 4) / 5)

        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bitCount += 8

            while bitCount >= 5 {
                let shift = bitCount - 5
                let index = Int((buffer >> UInt32(shift)) & 0x1F)
                output.append(alphabet[index])
                bitCount -= 5
                buffer &= (1 << UInt32(bitCount)) - 1
            }
        }

        if bitCount > 0 {
            let index = Int((buffer << UInt32(5 - bitCount)) & 0x1F)
            output.append(alphabet[index])
        }

        return output
    }

    static func base32Decode(_ string: String) throws -> Data {
        guard !string.isEmpty else { return Data() }
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var map: [Character: UInt8] = [:]
        for (index, character) in alphabet.enumerated() {
            map[character] = UInt8(index)
        }

        var buffer: UInt32 = 0
        var bitCount = 0
        var output = Data()
        output.reserveCapacity(string.count * 5 / 8)

        for character in string.uppercased() {
            guard let value = map[character] else {
                throw StrKeyError.invalidBase32
            }
            buffer = (buffer << 5) | UInt32(value)
            bitCount += 5

            while bitCount >= 8 {
                let shift = bitCount - 8
                let byte = UInt8((buffer >> UInt32(shift)) & 0xFF)
                output.append(byte)
                bitCount -= 8
                if bitCount > 0 {
                    buffer &= (1 << UInt32(bitCount)) - 1
                } else {
                    buffer = 0
                }
            }
        }

        if bitCount > 0 && buffer != 0 {
            throw StrKeyError.invalidBase32
        }

        return output
    }

    private static func validateLength(_ length: Int, for version: VersionByte) throws {
        switch version {
        case .ed25519PublicKey, .ed25519SecretSeed, .preAuthTx, .sha256Hash, .contract:
            guard length == 32 else {
                throw StrKeyError.invalidPayloadLength(expected: 32, actual: length)
            }
        case .muxedAccount:
            guard length == 40 else {
                throw StrKeyError.invalidPayloadLength(expected: 40, actual: length)
            }
        case .signedPayload:
            guard length >= 32 else {
                throw StrKeyError.invalidLength
            }
        }
    }
}
