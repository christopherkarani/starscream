import Foundation

internal enum MinimalXDRDecodingError: Error {
    case insufficientData
    case invalidDiscriminant(Int32)
    case invalidUTF8
    case invalidBase64
}

internal enum MinimalSCSpecEntry {
    case functionV0(MinimalSCSpecFunctionV0)
    case udtStructV0(MinimalSCSpecUDTStructV0)
    case udtUnionV0(MinimalSCSpecUDTUnionV0)
    case udtEnumV0(MinimalSCSpecUDTEnumV0)
    case udtErrorEnumV0(MinimalSCSpecUDTErrorEnumV0)
}

internal struct MinimalSCSpecFunctionInputV0 {
    let name: String
    let type: MinimalSCSpecTypeDef
}

internal struct MinimalSCSpecFunctionV0 {
    let name: String
    let inputs: [MinimalSCSpecFunctionInputV0]
    let outputs: [MinimalSCSpecTypeDef]
}

internal struct MinimalSCSpecUDTStructFieldV0 {
    let name: String
    let type: MinimalSCSpecTypeDef
}

internal struct MinimalSCSpecUDTStructV0 {
    let name: String
    let fields: [MinimalSCSpecUDTStructFieldV0]
}

internal struct MinimalSCSpecUDTEnumCaseV0 {
    let name: String
    let value: UInt32
}

internal struct MinimalSCSpecUDTEnumV0 {
    let name: String
    let cases: [MinimalSCSpecUDTEnumCaseV0]
}

internal struct MinimalSCSpecUDTUnionCaseV0 {
    let name: String
    let type: MinimalSCSpecTypeDef
}

internal struct MinimalSCSpecUDTUnionV0 {
    let name: String
    let cases: [MinimalSCSpecUDTUnionCaseV0]
}

internal struct MinimalSCSpecUDTErrorEnumCaseV0 {
    let name: String
    let value: UInt32
}

internal struct MinimalSCSpecUDTErrorEnumV0 {
    let name: String
    let cases: [MinimalSCSpecUDTErrorEnumCaseV0]
}

internal indirect enum MinimalSCSpecTypeDef {
    case val
    case bool
    case void
    case error
    case u32
    case i32
    case u64
    case i64
    case timepoint
    case duration
    case u128
    case i128
    case u256
    case i256
    case bytes
    case string
    case symbol
    case address
    case muxedAddress
    case option(MinimalSCSpecTypeDef)
    case result(ok: MinimalSCSpecTypeDef, error: MinimalSCSpecTypeDef)
    case vec(MinimalSCSpecTypeDef)
    case map(key: MinimalSCSpecTypeDef, value: MinimalSCSpecTypeDef)
    case tuple([MinimalSCSpecTypeDef])
    case bytesN(UInt32)
    case udt(String)
}

internal struct MinimalXDRDecoder {
    private let data: Data
    private var cursor: Int

    internal init(data: Data) {
        self.data = data
        self.cursor = 0
    }

    internal static func decodeSpecEntries(base64: String) throws -> [MinimalSCSpecEntry] {
        guard let bytes = Data(base64Encoded: base64) else {
            throw MinimalXDRDecodingError.invalidBase64
        }
        var decoder = MinimalXDRDecoder(data: bytes)
        return try decoder.decodeArray { decoder in
            try decoder.decodeSpecEntry()
        }
    }

    internal mutating func decodeSpecEntries() throws -> [MinimalSCSpecEntry] {
        try decodeArray { decoder in
            try decoder.decodeSpecEntry()
        }
    }

    private mutating func decodeSpecEntry() throws -> MinimalSCSpecEntry {
        let disc = try decodeInt32()
        switch disc {
        case 0:
            return .functionV0(try decodeFunctionV0())
        case 1:
            return .udtStructV0(try decodeUDTStructV0())
        case 2:
            return .udtUnionV0(try decodeUDTUnionV0())
        case 3:
            return .udtEnumV0(try decodeUDTEnumV0())
        case 4:
            return .udtErrorEnumV0(try decodeUDTErrorEnumV0())
        default:
            throw MinimalXDRDecodingError.invalidDiscriminant(disc)
        }
    }

    private mutating func decodeFunctionV0() throws -> MinimalSCSpecFunctionV0 {
        let name = try decodeString()
        let inputs: [MinimalSCSpecFunctionInputV0] = try decodeArray { decoder in
            MinimalSCSpecFunctionInputV0(name: try decoder.decodeString(), type: try decoder.decodeTypeDef())
        }
        let outputs: [MinimalSCSpecTypeDef] = try decodeArray { decoder in
            try decoder.decodeTypeDef()
        }
        return MinimalSCSpecFunctionV0(name: name, inputs: inputs, outputs: outputs)
    }

    private mutating func decodeUDTStructV0() throws -> MinimalSCSpecUDTStructV0 {
        let name = try decodeString()
        let fields: [MinimalSCSpecUDTStructFieldV0] = try decodeArray { decoder in
            MinimalSCSpecUDTStructFieldV0(name: try decoder.decodeString(), type: try decoder.decodeTypeDef())
        }
        return MinimalSCSpecUDTStructV0(name: name, fields: fields)
    }

    private mutating func decodeUDTEnumV0() throws -> MinimalSCSpecUDTEnumV0 {
        let name = try decodeString()
        let cases: [MinimalSCSpecUDTEnumCaseV0] = try decodeArray { decoder in
            MinimalSCSpecUDTEnumCaseV0(name: try decoder.decodeString(), value: try decoder.decodeUInt32())
        }
        return MinimalSCSpecUDTEnumV0(name: name, cases: cases)
    }

    private mutating func decodeUDTUnionV0() throws -> MinimalSCSpecUDTUnionV0 {
        let name = try decodeString()
        let cases: [MinimalSCSpecUDTUnionCaseV0] = try decodeArray { decoder in
            MinimalSCSpecUDTUnionCaseV0(name: try decoder.decodeString(), type: try decoder.decodeTypeDef())
        }
        return MinimalSCSpecUDTUnionV0(name: name, cases: cases)
    }

    private mutating func decodeUDTErrorEnumV0() throws -> MinimalSCSpecUDTErrorEnumV0 {
        let name = try decodeString()
        let cases: [MinimalSCSpecUDTErrorEnumCaseV0] = try decodeArray { decoder in
            MinimalSCSpecUDTErrorEnumCaseV0(name: try decoder.decodeString(), value: try decoder.decodeUInt32())
        }
        return MinimalSCSpecUDTErrorEnumV0(name: name, cases: cases)
    }

    private mutating func decodeTypeDef() throws -> MinimalSCSpecTypeDef {
        let disc = try decodeInt32()
        switch disc {
        case 0: return .val
        case 1: return .bool
        case 2: return .void
        case 3: return .error
        case 4: return .u32
        case 5: return .i32
        case 6: return .u64
        case 7: return .i64
        case 8: return .timepoint
        case 9: return .duration
        case 10: return .u128
        case 11: return .i128
        case 12: return .u256
        case 13: return .i256
        case 14: return .bytes
        case 16: return .string
        case 17: return .symbol
        case 19: return .address
        case 20: return .muxedAddress
        case 1000:
            return .option(try decodeTypeDef())
        case 1001:
            return .result(ok: try decodeTypeDef(), error: try decodeTypeDef())
        case 1002:
            return .vec(try decodeTypeDef())
        case 1004:
            return .map(key: try decodeTypeDef(), value: try decodeTypeDef())
        case 1005:
            let types: [MinimalSCSpecTypeDef] = try decodeArray { decoder in
                try decoder.decodeTypeDef()
            }
            return .tuple(types)
        case 1006:
            return .bytesN(try decodeUInt32())
        case 2000:
            return .udt(try decodeString())
        default:
            throw MinimalXDRDecodingError.invalidDiscriminant(disc)
        }
    }

    private mutating func decodeString() throws -> String {
        let bytes = try decodeOpaque()
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw MinimalXDRDecodingError.invalidUTF8
        }
        return string
    }

    private mutating func decodeOpaque() throws -> Data {
        let length = Int(try decodeUInt32())
        let value = try read(length)
        let padding = (4 - (length % 4)) % 4
        _ = try read(padding)
        return value
    }

    private mutating func decodeUInt32() throws -> UInt32 {
        UInt32(bitPattern: try decodeInt32())
    }

    private mutating func decodeInt32() throws -> Int32 {
        let bytes = try read(4)
        let value = (UInt32(bytes[bytes.startIndex]) << 24)
            | (UInt32(bytes[bytes.index(bytes.startIndex, offsetBy: 1)]) << 16)
            | (UInt32(bytes[bytes.index(bytes.startIndex, offsetBy: 2)]) << 8)
            | UInt32(bytes[bytes.index(bytes.startIndex, offsetBy: 3)])
        return Int32(bitPattern: value)
    }

    private mutating func decodeArray<T>(_ decodeElement: (inout MinimalXDRDecoder) throws -> T) throws -> [T] {
        let count = Int(try decodeUInt32())
        var values: [T] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try decodeElement(&self))
        }
        return values
    }

    private mutating func read(_ count: Int) throws -> Data {
        guard cursor + count <= data.count else {
            throw MinimalXDRDecodingError.insufficientData
        }
        let range = cursor..<(cursor + count)
        cursor += count
        return data.subdata(in: range)
    }
}
