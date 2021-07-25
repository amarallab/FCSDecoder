//
//  SegmentDecoder.swift
//  FCSDecoder
//
//  Created by Helio Tejedor on 7/16/21.
//

import Combine
import Foundation

public protocol Parametrized {
    static var paramCountKey: String? { get }
    static var paramPrefixes: [String] { get }
}

protocol CollectionProtocol {
    static func getElement() -> Any.Type
}

extension Array: CollectionProtocol where Element : Parametrized {
    static func getElement() -> Any.Type {
        return Element.self
    }
}

internal struct KeyValueReader {
    var data: [String: String] = [:]
    var nextName: String? = nil
    var isBalanced: Bool { nextName?.count ?? 0 == 0 }

    mutating func addChunk(data: Data, from startIndex: Data.Index, to endIndex: Data.Index, indicesToDelete: Set<Int>) throws {
        var chunk = data[startIndex..<endIndex]
        for index in indicesToDelete.sorted(by: >) {
            chunk.remove(at: index)
        }
        guard let value = String(data: chunk, encoding: .utf8)?.trimmingCharacters(in: .whitespaces) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Bad data at index \(startIndex) to \(endIndex)"))
        }

        if let name = nextName {
            guard !self.data.keys.contains(name) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Duplicated key \(name)"))
            }
            self.data[name] = value
            nextName = nil
        } else {
            nextName = value
        }
    }
}

public struct SegmentDecoder: TopLevelDecoder {
   public typealias Input = Data
    
    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        guard data.count > 0 else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        }
        
        let delimiter = data[data.startIndex]
        var prevIndex = data.startIndex.advanced(by: 1)
        var indicesToDelete: Set<Int> = []
        var keyValueReader = KeyValueReader()
        var index = data.startIndex.advanced(by: 1)
        while index < data.endIndex {
            if data[index] != delimiter {
                index = index.advanced(by: 1)
                continue
            }
            
            let nextIndex = index.advanced(by: 1)
            if nextIndex < data.endIndex && data[nextIndex] == delimiter {
                indicesToDelete.insert(index)
                index = index.advanced(by: 2)
                continue
            }
            
            try keyValueReader.addChunk(data: data, from: prevIndex, to: index, indicesToDelete: indicesToDelete)
            prevIndex = nextIndex
            indicesToDelete.removeAll()
            index = index.advanced(by: 1)
        }
        if prevIndex < data.endIndex {
            try keyValueReader.addChunk(data: data, from: prevIndex, to: data.endIndex, indicesToDelete: indicesToDelete)
        }
        
        guard keyValueReader.isBalanced else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Inbalanced params"))
        }
        
        return try T(from: InternalSegmentDecoder(codingPath: [], userInfo: [:], keyValueReader: keyValueReader))
    }
}

internal struct InternalSegmentDecoder: Decoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var value: String? = nil
    var keyValueReader: KeyValueReader? = nil
    var keyValueReaderList: [KeyValueReader]? = nil
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard let keyValueReader = keyValueReader else { fatalError() }
        return KeyedDecodingContainer(InternalSegmentKeyedDecodingContainer(codingPath: codingPath, userInfo: userInfo, keyValueReader: keyValueReader))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let keyValueReaderList = keyValueReaderList else { fatalError() }
        return InternalSegmentUnkeyedDecodingContainer(codingPath: codingPath, userInfo: userInfo, keyValueReaderList: keyValueReaderList)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        guard let value = value else { fatalError() }
        return InternalSegmentSingleValueDecodingContainer(codingPath: codingPath, value: value)
    }
}

internal struct InternalSegmentKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var allKeys: [Key] { keyValueReader.data.keys.compactMap { Key(stringValue: $0) } }
    var keyValueReader: KeyValueReader
    
    func contains(_ key: Key) -> Bool {
        keyValueReader.data.keys.contains(key.stringValue)
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        !keyValueReader.data.keys.contains(key.stringValue)
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        if
            let collectionType = type as? CollectionProtocol.Type,
            let parametrized = collectionType.getElement() as? Parametrized.Type
        {
            let count: Int?
            if let paramCountKey = parametrized.paramCountKey {
                guard
                    let countString = keyValueReader.data[paramCountKey],
                    let validCount = Int(countString)
                else {
                    throw DecodingError.typeMismatch(Int.self, .init(codingPath: codingPath, debugDescription: ""))
                }
                count = validCount
            } else {
                count = nil
            }
            
            var keyValueReaderList: [KeyValueReader] = []
            var id = 0
            while true {
                id += 1
                if let count = count, id > count {
                    break
                }

                var littleContainer = KeyValueReader()
                for current in parametrized.paramPrefixes {
                    let prefix = "\(current)\(id)"
                    for (keyString, valueString) in keyValueReader.data {
                        guard keyString.count > prefix.count else { continue }
                        let index = keyString.index(keyString.startIndex, offsetBy: prefix.count)
                        guard keyString.starts(with: prefix),
                              index < keyString.endIndex,  // not necessary
                              !keyString[index].isNumber
                        else {
                            continue
                        }
                        let newKey = String(keyString[index...])
                        littleContainer.data[newKey] = valueString
                    }
                }
                if littleContainer.data.count == 0 && count == nil {
                    break
                }
                keyValueReaderList.append(littleContainer)
            }

            let decoder = InternalSegmentDecoder(codingPath: codingPath, userInfo: userInfo, keyValueReaderList: keyValueReaderList)
            return try T(from: decoder)
        }
        
        guard let value = keyValueReader.data[key.stringValue] else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "")
        }
        let decoder = InternalSegmentDecoder(codingPath: codingPath + [key], userInfo: userInfo, value: value)
        return try decoder.singleValueContainer().decode(type)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError()
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        fatalError()
    }
    
    func superDecoder() throws -> Decoder {
        fatalError()
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        fatalError()
    }
    
}

internal struct InternalSegmentUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var count: Int?
    var isAtEnd: Bool
    var currentIndex: Int
    var keyValueReaderList: [KeyValueReader]

    init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any], keyValueReaderList: [KeyValueReader]) {
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.count = keyValueReaderList.count
        self.isAtEnd = keyValueReaderList.count == 0
        self.currentIndex = 0
        self.keyValueReaderList = keyValueReaderList
    }

    func decodeNil() throws -> Bool {
        fatalError()
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let index = currentIndex
        currentIndex += 1
        isAtEnd = currentIndex == keyValueReaderList.count
        let decoder = InternalSegmentDecoder(codingPath: codingPath, userInfo: userInfo, keyValueReader: keyValueReaderList[index])
        return try T(from: decoder)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError()
    }
    
    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError()
    }
    
    func superDecoder() throws -> Decoder {
        fatalError()
    }

}

internal struct InternalSegmentSingleValueDecodingContainer: SingleValueDecodingContainer {
    var codingPath: [CodingKey]
    var value: String
    
    func decodeNil() -> Bool {
        false
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        switch value.lowercased() {
        case "true": return true
        case "false": return false
        default:
            throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "Invalid bool value: \(value)"))
        }
    }
    
    func decode(_ type: String.Type) throws -> String {
        value
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        guard let value = Double(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        guard let value = Float(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        guard let value = Int(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        guard let value = Int8(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        guard let value = Int16(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        guard let value = Int32(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        guard let value = Int64(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        guard let value = UInt(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard let value = UInt8(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard let value = UInt16(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard let value = UInt32(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard let value = UInt64(value) else { throw DecodingError.typeMismatch(type, .init(codingPath: codingPath, debugDescription: "")) }
        return value
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let decoder = InternalSegmentDecoder(codingPath: codingPath, userInfo: [:], value: value)
        return try T(from: decoder)
    }
    
}
