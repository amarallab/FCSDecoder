//
//  BitBuffer.swift
//  FCSDecoder
//
//  Created by Heliodoro Tejedor Navarro on 7/23/21.
//

import Foundation

public protocol BitBuffer {
    var isEmpty: Bool { get }
    mutating func next(_ bitCount: Int) -> UInt32
}

public func createBitBuffer(_ buffer: Data, byteOrder: ByteOrder, onlyBytes: Bool) -> BitBuffer {
    switch (byteOrder, onlyBytes) {
    case (.bigEndian, false):
        return BitBufferBigEndian(buffer: buffer)
    case (.littleEndian, false):
        return BitBufferLittleEndian(buffer: buffer)
    case (.bigEndian, true):
        return BitBufferBigEndianOnlyBytes(buffer: buffer)
    case (.littleEndian, true):
        return BitBufferLittleEndianOnlyBytes(buffer: buffer)
    }
}

struct BitBufferBigEndianOnlyBytes: BitBuffer {
    var buffer: Data
    var index = 0
    var isEmpty: Bool { index == buffer.count }
    
    mutating func next(_ bitCount: Int) -> UInt32 {
        let byteCount = bitCount/8
        guard bitCount.isMultiple(of: 8), byteCount <= 4 else { fatalError() }
        var current: UInt32 = 0
        for _ in 0..<byteCount {
            let byte: UInt8 = buffer[buffer.startIndex + index]
            current = (current << 8) | UInt32(byte)
            index += 1
        }
        return current
    }
}

struct BitBufferLittleEndianOnlyBytes: BitBuffer {
    var buffer: Data
    var index = 0
    var isEmpty: Bool { index == buffer.count }
    
    mutating func next(_ bitCount: Int) -> UInt32 {
        let byteCount = bitCount/8
        guard bitCount.isMultiple(of: 8), byteCount <= 4 else { fatalError() }
        var current: UInt32 = 0
        var currentByte = 0
        for _ in 0..<byteCount {
            let byte: UInt8 = buffer[buffer.startIndex + index]
            current = current | (UInt32(byte) << (currentByte * 8))
            index += 1
            currentByte += 1
        }
        return current
    }
}

struct BitBufferBigEndian: BitBuffer {
    var buffer: Data
    var index = 0
    var isEmpty: Bool { index == buffer.count * 8 }
        
    mutating func next(_ bitCount: Int) -> UInt32 {
        assert(bitCount >= 0 && bitCount <= 32)
        var current: UInt32 = 0
        for i in 0..<bitCount {
            let byte = index / 8
            let offset = 7 - (index % 8)
            if buffer[buffer.startIndex + byte] & (1 << offset) != 0 {
                current |= 1 << (bitCount - i - 1)
            }
            index += 1
        }
        return current
    }
}

struct BitBufferLittleEndian: BitBuffer {
    var buffer: Data
    var index = 0
    var isEmpty: Bool { index == buffer.count * 8 }
    
    mutating func next(_ bitCount: Int) -> UInt32 {
        assert(bitCount >= 0 && bitCount <= 32)
        var current: UInt32 = 0
        for i in 0..<bitCount {
            let byte = index / 8
            let offset = 7 - (index % 8)
            if buffer[buffer.startIndex + byte] & (1 << offset) != 0 {
                let byte = (bitCount / 8) - (bitCount - i - 1) / 8 - 1
                let offset = (bitCount - i - 1) % 8
                current |= 1 << (byte * 8 + offset)
            }
            index += 1
        }
        return current
    }
}
