//
//  SimplePlayerTests.swift
//  SimplePlayerTests
//
//  Created by Lee Newman on 10/25/25.
//

import Testing
import XCTest
import Foundation

struct SimplePlayerTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func testHeader1() async throws {
        
        // Example MP3 Header (MPEG 1, Layer III, 128 kbps, 44.1 kHz, Stereo)
        // Hex: FFE30030 (1111 1111 111 | 11 | 01 | 0 | 1000 | 00 | 0 | 0 | 00 | 00 | 1 | 1 | 00)
        // Sync=11, Ver=11 (MPEG 1), Lyr=01 (L3), Prot=0, BR=1000 (128k), SR=00 (44.1k), Pad=0, Priv=0, Ch=00 (Stereo), Ext=00, Copy=1, Orig=1, Emph=00
        let mp3HeaderData = Data([0xFF, 0xE3, 0x00, 0x30])
        
        print("--- Parsing Example MP3 Header (128kbps, 44.1kHz) ---")
        if let header = MPEGFrameHeader(data: mp3HeaderData) {
            print(header)
        } else {
            print("Failed to parse header.")
        }
    }
    
    @Test func testHeader2() async throws {
        
        // Example MPEG 2, Layer II, 64 kbps, 24 kHz, Mono
        // Hex: FFC81440 (1111 1111 111 | 10 | 10 | 0 | 0100 | 01 | 0 | 0 | 11 | 00 | 0 | 1 | 00)
        // Sync=11, Ver=10 (MPEG 2), Lyr=10 (L2), Prot=0, BR=0100 (64k), SR=01 (24k), Pad=0, Priv=0, Ch=11 (Mono), Ext=00, Copy=0, Orig=1, Emph=00
        
        let headerAsInt : UInt32 = 0xFFF444C4
        
        let binaryString = String(headerAsInt, radix: 2)
        print(binaryString) // Prints "10110"

        
        // Option 1: Convert to big-endian or little-endian explicitly
        // For big-endian:
        var bigEndianValue = headerAsInt.bigEndian
        let mpeg2HeaderData = Data(bytes: &bigEndianValue, count: MemoryLayout<UInt32>.size)
        
        print("Big-endian Data: \(mpeg2HeaderData.map { String(format: "%02x", $0) }.joined())") // Example: 12345678

        print("\n--- Parsing Example MPEG 2 Layer II Header (64kbps, 24kHz, Mono) ---")
        
        guard let header = MPEGFrameHeader(data: mpeg2HeaderData) else
        {
            XCTFail("didn't get a header back")
            return
        }
        
        XCTAssert(header.version == .mpeg2, "Version should be .version2")
        XCTAssert(header.layer == .layerII, "Layer should be .layer2")
        XCTAssertFalse(header.isProtected, "shouldn't be protected")
        XCTAssert(header.bitrate == 64, "Bitrate should be 64")
        XCTAssert(header.sampleRate == 24, "Sample Rate should be 24")
        XCTAssertFalse(header.isPadded, "header isn't paddede")
        XCTAssertFalse(header.isPrivate, "header isn't private")
        XCTAssert(header.channelMode == .mono, "Channel mode should be .mono")
        XCTAssertFalse(header.isCopyrighted, "header isn't copyrighted")
        XCTAssert(header.isOriginal, "header should be original")
        XCTAssert(header.emphasis == 0, "Emphasis should be 0")
    
    }

    @Test func testHeader3() async throws {
        
        // Example of an Invalid Header (Missing Sync Word)
        let invalidHeaderData = Data([0x00, 0x00, 0x00, 0x00])
        print("\n--- Parsing Invalid Header (No Sync Word) ---")
        let header = MPEGFrameHeader(data: invalidHeaderData)
        print (header ?? "nil")
        
        XCTAssertNil(header, "header is nil - didnt parse")
    }
}
