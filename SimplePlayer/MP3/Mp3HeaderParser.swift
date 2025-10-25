//
//  Mp3HeaderParser.swift
//  SimplePlayer
//
//  Created by Lee Newman on 10/25/25.
//

import Foundation


/// A struct representing the 32-bit (4-byte) header of an MPEG Audio Frame.
/// The parsing logic follows the specification from mpegedit.org/mpgedit/mpeg_format/mpeghdr.htm
/// This header determines the version, layer, bitrate, and sampling frequency of the audio frame.
public struct MPEGFrameHeader {

    // MARK: - Enums for Typed Values

    /// MPEG Audio Version ID (2 bits)
    public enum Version: UInt32, CustomStringConvertible {
        case mpeg2_5 = 0b00 // Non-official extension (MPEG 2.5)
        case reserved = 0b01
        case mpeg2 = 0b10
        case mpeg1 = 0b11

        public var description: String {
            switch self {
            case .mpeg1: return "MPEG 1"
            case .mpeg2: return "MPEG 2"
            case .mpeg2_5: return "MPEG 2.5"
            case .reserved: return "Reserved"
            }
        }
    }

    /// MPEG Audio Layer (2 bits)
    public enum Layer: UInt32, CustomStringConvertible {
        case reserved = 0b00
        case layerIII = 0b01 // MP3
        case layerII = 0b10
        case layerI = 0b11

        public var description: String {
            switch self {
            case .layerI: return "Layer I"
            case .layerII: return "Layer II"
            case .layerIII: return "Layer III"
            case .reserved: return "Reserved"
            }
        }
    }

    /// Channel Mode (2 bits)
    public enum ChannelMode: UInt32, CustomStringConvertible {
        case stereo = 0b00
        case jointStereo = 0b01
        case dualChannel = 0b10
        case mono = 0b11

        public var description: String {
            switch self {
            case .stereo: return "Stereo"
            case .jointStereo: return "Joint Stereo (Intensity Stereo/MS Stereo)"
            case .dualChannel: return "Dual Channel"
            case .mono: return "Mono"
            }
        }
    }

    // MARK: - Extracted Fields (Properties)

    public let syncWord: UInt32           // Bits 31-21 (Must be 0x7FF)
    public let version: Version
    public let layer: Layer
    public let isProtected: Bool          // Bit 16: true if NOT protected (no CRC)
    public let bitrateIndex: UInt32       // Bits 15-12
    public let samplingRateIndex: UInt32  // Bits 11-10
    public let isPadded: Bool             // Bit 9: true if padding byte is added
    public let isPrivate: Bool            // Bit 8
    public let channelMode: ChannelMode   // Bits 7-6
    public let modeExtension: UInt32      // Bits 5-4 (Joint Stereo parameters)
    public let isCopyrighted: Bool        // Bit 3
    public let isOriginal: Bool           // Bit 2 (true if original copy)
    public let emphasis: UInt32           // Bits 1-0

    // MARK: - Calculated Properties

    /// Retrieves the actual sampling frequency in Hz, based on Version and Index.
    public var sampleRate: Int? {
        let table: [Version: [Int?]] = [
            .mpeg1: [44100, 48000, 32000, nil], // [00, 01, 10, 11]
            .mpeg2: [22050, 24000, 16000, nil],
            .mpeg2_5: [11025, 12000, 8000, nil]
        ]
        
        guard let rates = table[version],
              samplingRateIndex < rates.count else { return nil }

        return rates[Int(samplingRateIndex)]
    }

    /// Retrieves the actual bitrate in kbps, based on Version, Layer, and Index.
    public var bitrate: Int? {
        // Bitrate table [Index]: Layer III, Layer II, Layer I (kbps)
        // 0 and 15 are special values (free format and reserved)
        let table: [Version: [[Int?]]] = [
            // [Index]: [L3, L2, L1]
            .mpeg1: [
                [nil, nil, nil],
                [32, 32, 32],
                [40, 48, 64],
                [48, 56, 96],
                [56, 64, 128],
                [64, 80, 160],
                [80, 96, 192],
                [96, 112, 224],
                [112, 128, 256],
                [128, 160, 288],
                [160, 192, 320],
                [192, 224, 352],
                [224, 256, 384],
                [256, 320, 416],
                [320, 384, 448],
                [nil, nil, nil]
            ],
            // MPEG 2/2.5 uses the same table for L1/L2, but different for L3
            .mpeg2: [
                [nil, nil, nil],
                [8, 8, 32],
                [16, 16, 48],
                [24, 24, 56],
                [32, 32, 64],
                [40, 40, 80],
                [48, 48, 96],
                [56, 56, 112],
                [64, 64, 128],
                [80, 80, 144],
                [96, 96, 160],
                [112, 112, 176],
                [128, 128, 192],
                [144, 144, 224],
                [160, 160, 256],
                [nil, nil, nil]
            ]
        ]

        guard let versionTable = table[version],
              bitrateIndex > 0, bitrateIndex < 15 // Skip free and reserved
        else { return nil }
        
        let rates = versionTable[Int(bitrateIndex)]

        switch layer {
        case .layerIII: return rates[0]
        case .layerII: return rates[1]
        case .layerI: return rates[2]
        case .reserved: return nil
        }
    }

    /// Calculates the size of the MPEG audio frame in bytes.
    /// FrameSize = ((144 * BitRate) / SampleRate) + Padding
    public var frameSize: Int? {
        guard let bitrate = self.bitrate,
              let sampleRate = self.sampleRate else { return nil }
        
        // BitRate is in kbps, so multiply by 1000 for bps.
        let bitRateBPS = Double(bitrate * 1000)
        
        let multiplier: Double
        switch layer {
        case .layerI:
            // Layer I formula: ((12 * BitRate) / SampleRate) * 4 + Padding
            multiplier = 48.0 // 12 * 4 (slots * bytes/slot)
        case .layerII, .layerIII:
            // Layer II & III formula: ((144 * BitRate) / SampleRate) + Padding
            multiplier = 144.0
        case .reserved:
            return nil
        }

        let frameLength = floor(multiplier * bitRateBPS / Double(sampleRate))
        let padding = isPadded ? 1 : 0
        
        return Int(frameLength) + padding
    }

    // MARK: - Initializer (The actual parser)

    /// Initializes a header struct by parsing the first 4 bytes of a Data object.
    /// - Parameter data: A Data object containing at least 4 bytes of the MPEG frame header.
    public init?(data: Data) {
        guard data.count >= 4 else {
            print("Error: Data must contain at least 4 bytes for the MPEG header.")
            return nil
        }
        
        print (data.asBytes)

        // 1. Convert the first 4 bytes of Data into a single Big-Endian UInt32.
        // MPEG headers are always Big-Endian (Most Significant Byte first).
        let headerData = data.prefix(4)
        let headerValue : UInt32 = headerData.withUnsafeBytes { buffer in
            return buffer.load(as: UInt32.self).bigEndian
        }

        // 2. Extract fields using bitwise shifting and masking.
        
        // Bits 31-21: Frame Sync (11 bits, must be 0x7FF)
        self.syncWord = (headerValue >> 20) & 0x7FF
        guard self.syncWord == 0x7FF else {
            print("Error: Invalid Frame Sync word (\(String(self.syncWord, radix: 16))). Expected 0x7FF.")
            return nil
        }

        // Bits 20-19: Version ID (2 bits)
        let versionRaw = (headerValue >> 19) & 0x3
        guard let version = Version(rawValue: versionRaw) else { return nil }
        self.version = version

        // Bits 18-17: Layer Description (2 bits)
        let layerRaw = (headerValue >> 17) & 0x3
        guard let layer = Layer(rawValue: layerRaw), layer != .reserved else {
            print("Error: Layer is reserved.")
            return nil
        }
        self.layer = layer

        // Bit 16: Protection Bit (1 bit) - 0 is protected (CRC), 1 is NOT protected
        self.isProtected = (headerValue >> 16) & 0x1 == 0

        // Bits 15-12: Bitrate Index (4 bits)
        self.bitrateIndex = (headerValue >> 12) & 0xF
        
        // Bits 11-10: Sample Rate Index (2 bits)
        self.samplingRateIndex = (headerValue >> 10) & 0x3
        
        // Check for reserved values in Version and Sample Rate
        if version == .reserved || version == .mpeg2_5 {
            print("Error: MPEG Version is reserved or unofficial.")
            return nil
        }
        if samplingRateIndex == 0b11 {
            print("Error: Sampling Rate Index is reserved.")
            return nil
        }
        if bitrateIndex == 0b0000 || bitrateIndex == 0b1111 {
            print("Error: Bitrate is set to 'Free' or 'Reserved'. Cannot parse frame.")
            return nil
        }
        
        // Bit 9: Padding Bit (1 bit)
        self.isPadded = (headerValue >> 9) & 0x1 == 1
        
        // Bit 8: Private Bit (1 bit)
        self.isPrivate = (headerValue >> 8) & 0x1 == 1

        // Bits 7-6: Channel Mode (2 bits)
        let channelModeRaw = (headerValue >> 6) & 0x3
        guard let channelMode = ChannelMode(rawValue: channelModeRaw) else { return nil }
        self.channelMode = channelMode

        // Bits 5-4: Mode Extension (2 bits) - Only used for Joint Stereo
        self.modeExtension = (headerValue >> 4) & 0x3

        // Bit 3: Copyright (1 bit)
        self.isCopyrighted = (headerValue >> 3) & 0x1 == 1

        // Bit 2: Original/Copy (1 bit)
        self.isOriginal = (headerValue >> 2) & 0x1 == 1

        // Bits 1-0: Emphasis (2 bits)
        self.emphasis = headerValue & 0x3
    }
}

// MARK: - Example Usage

extension MPEGFrameHeader: CustomStringConvertible {
    public var description: String {
        let frameSizeStr = frameSize != nil ? "\(frameSize!) bytes" : "unknown"
        let sampleRateStr = sampleRate != nil ? "\(sampleRate! / 1000) kHz" : "unknown"
        let bitrateStr = bitrate != nil ? "\(bitrate!) kbps" : "unknown"
        
        var output = """
        --- MPEG Frame Header Details ---
        Raw Header Value: 0x\(String(format: "%08X", (syncWord << 21) | (version.rawValue << 19) | (layer.rawValue << 17) | (isProtected ? 0 : (1 << 16)) | (bitrateIndex << 12) | (samplingRateIndex << 10) | (isPadded ? (1 << 9) : 0) | (isPrivate ? (1 << 8) : 0) | (channelMode.rawValue << 6) | (modeExtension << 4) | (isCopyrighted ? (1 << 3) : 0) | (isOriginal ? (1 << 2) : 0) | emphasis))
        
        [Format]
          Version:        \(version)
          Layer:          \(layer)
          Bitrate:        \(bitrateStr)
          Sample Rate:    \(sampleRateStr)
          Channel Mode:   \(channelMode)
          Frame Size:     \(frameSizeStr)
        
        [Details]
          Protection:     \(isProtected ? "CRC enabled" : "No CRC")
          Padding:        \(isPadded ? "Yes (1 byte)" : "No")
          Copyright:      \(isCopyrighted ? "Yes" : "No")
          Original:       \(isOriginal ? "Yes" : "No")
          Emphasis:       \(emphasis)
        ---------------------------------
        """
        
        // Add Mode Extension details if relevant (Joint Stereo)
        if channelMode == .jointStereo {
            output += "\n  Mode Extension:   \(modeExtension) (Intensity Stereo/MS Coding)"
        }
        
        return output
    }
    
    // Example usage to make the file runnable
    func demonstrateParsing() {
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
        
        // Example MPEG 2, Layer II, 64 kbps, 24 kHz, Mono
        // Hex: FFC81440 (1111 1111 111 | 10 | 10 | 0 | 0100 | 01 | 0 | 0 | 11 | 00 | 0 | 1 | 00)
        // Sync=11, Ver=10 (MPEG 2), Lyr=10 (L2), Prot=0, BR=0100 (64k), SR=01 (24k), Pad=0, Priv=0, Ch=11 (Mono), Ext=00, Copy=0, Orig=1, Emph=00
        let mpeg2HeaderData = Data([0xFF, 0xC8, 0x14, 0x40])
        
        print("\n--- Parsing Example MPEG 2 Layer II Header (64kbps, 24kHz, Mono) ---")
        if let header = MPEGFrameHeader(data: mpeg2HeaderData) {
            print(header)
        } else {
            print("Failed to parse header.")
        }
        
        // Example of an Invalid Header (Missing Sync Word)
        let invalidHeaderData = Data([0x00, 0x00, 0x00, 0x00])
        print("\n--- Parsing Invalid Header (No Sync Word) ---")
        if let header = MPEGFrameHeader(data: invalidHeaderData) {
            print(header)
        } else {
            print("Successfully rejected invalid header (expected).")
        }
    }
}


