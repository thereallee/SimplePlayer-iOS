//
//  FrameReader.swift
//  SimplePlayer
//
//  Created by Lee Newman on 10/21/25.
//

import Foundation
import CoreAudio
import AudioToolbox


class FrameReader {
    
    func readMP3Frame(from fileURL: URL) {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        var audioFileStream: AudioFileStreamID?
        
//        let status = AudioFileStreamOpen(context, propertyListener, packetsCallback, kAudioFileMP3Type, &audioFileStream)
        
        
        
        let status = AudioFileStreamOpen(context,
                                          
            {inClientData, inAudioFileStream, inPropertyID,
            ioFlags in
                    // This callback is called when properties of the audio stream are discovered.
                // For example, you can query for the AudioStreamBasicDescription here.
                if inPropertyID == kAudioFileStreamProperty_DataFormat {
                    // You can check the format here
                }
            }
        ,
          
          {inUserData, inNumberBytes, inNumberPackets,
            inInputData, inPacketDescriptions in

            guard let inPacketDescriptions else {
                
                return
                
            }
            // This callback is where you get the raw audio packets (frames).
            let packetSize = Int(inPacketDescriptions.pointee.mDataByteSize)
            let packetOffset = Int(inPacketDescriptions.pointee.mStartOffset)
                
            let frameData = Data(bytes: inInputData.advanced(by: packetOffset), count: packetSize)
            // Process the frameData here
            
            
            print("Read MP3 frame with size: \(packetSize)")
            print("bytes == ", frameData.bytes)
        },
                                          kAudioFileMP3Type,
                                          &audioFileStream)
            
        guard status == noErr, let streamID = audioFileStream else {
            print("Failed to open audio file stream: \(status)")
            return
        }
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            _ = fileData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
                return AudioFileStreamParseBytes(streamID, UInt32(fileData.count), buffer.baseAddress!, AudioFileStreamParseFlags(rawValue: 0))
            }
        } catch {
            print("Failed to read file data: \(error.localizedDescription)")
        }
    }

    // A C function required by the AudioFileStream API
//    func  propertyListener (_ inClientData: UnsafeMutableRawPointer, _ inAudioFileStream: AudioFileStreamID, _ inPropertyID: AudioFileStreamPropertyID, _ ioFlags: UnsafeMutablePointer<AudioFileStreamPropertyFlags>) {
//        // This callback is called when properties of the audio stream are discovered.
//        // For example, you can query for the AudioStreamBasicDescription here.
//        if inPropertyID == kAudioFileStreamProperty_DataFormat {
//            // You can check the format here
//        }
//    }

    // A C function required by the AudioFileStream API
//    func packetsCallback (_ inClientData: UnsafeMutableRawPointer, _ inNumberPacketDescriptions: UInt32,  _ unKnownYetInt32: UInt32,
//                         _ inInputData: UnsafeRawPointer,
//                          _ inPacketDescriptions: Optional<UnsafeMutablePointer<AudioStreamPacketDescription>>) {
//        // This callback is where you get the raw audio packets (frames).
//        for i in 0..<inNumberPacketDescriptions {
//            // TODO think about the optional here
//            let packetDescription = inPacketDescriptions![Int(i)]
//            let packetSize = Int(packetDescription.mDataByteSize)
//            let packetOffset = Int(packetDescription.mStartOffset)
//            
//            let frameData = Data(bytes: inInputData.advanced(by: packetOffset), count: packetSize)
//            // Process the frameData here
//            print("Read MP3 frame with size: \(packetSize)")
//        }
//    }

    // Example usage:
    // guard let url = Bundle.main.url(forResource: "my_song", withExtension: "mp3") else { return }
    // readMP3Frame(from: url)



}
