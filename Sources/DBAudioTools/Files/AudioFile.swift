//
//  AudioFile.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 22.02.24.
//

import Foundation
import AudioToolbox

public struct AudioFile {
    let id: AudioFileID?
    let path: String
    
    // MARK: - File Properties
   
    var fileSize: UInt64 {
        guard let id else { return 0 }
        return (try? AudioFile.getFileSize(from: id)) ?? 0
    }
    
    var fileFormat: AudioStreamBasicDescription? {
        guard let id else { return nil }
        return (try? AudioFile.getFormat(from: id)) ?? AudioStreamBasicDescription()
    }
    
    var numberOfPackets: UInt64 {
        guard let id else { return 0 }
        return (try? AudioFile.getNumberOfPackets(from: id)) ?? 0
    }
   
    // MARK: - Lifecycle

    public init(id: AudioFileID, path: String) throws {
        self.id = id
        self.path = path
    }
    
    public init(path: String) throws {
        self.path = path
        self.id = try AudioFile.open(path: path)
    }
    
    public init(url: URL) throws {
        self.path = url.path(percentEncoded: false)
        self.id = try AudioFile.open(url: url)
    }
    
    // MARK: - Public functionss

    func calculateBytesForTime() throws -> (packetsToRead: UInt32, bytesToRead: UInt32, estimatedDuration: Float64) {
        guard let audioFileId = id else { throw AudioQueueError.noAudioFile }
        let audioStreamDescription = try AudioFile.getFormat(from: audioFileId)
        var packetSizeUpperBound: UInt32 = 0
        var packetSizeUpperBoundSize: UInt32 = UInt32.size32
        
        var estimatedDurationInSeconds: Float64 = 0
        var estimatedDurationInSecondsSize: UInt32 = Float64.size32
        try WithCheck(AudioFileGetProperty(audioFileId, kAudioFilePropertyEstimatedDuration, &estimatedDurationInSecondsSize, &estimatedDurationInSeconds)) {
            AudioFileError.getPropertyError($0)
        }

        try WithCheck(AudioFileGetProperty(audioFileId, kAudioFilePropertyPacketSizeUpperBound, &packetSizeUpperBoundSize, &packetSizeUpperBound)) {
            AudioFileError.getPropertyError($0)
        }
        let maxBufferSize: UInt32 = 0x100000
        let minBufferSize: UInt32 = 0x4000
        
        let numberOfPackets: UInt32 = if audioStreamDescription.mFramesPerPacket > 0 {
            UInt32(ceil(Float64(audioStreamDescription.mSampleRate * estimatedDurationInSeconds))) / audioStreamDescription.mFramesPerPacket
        } else {
            1
        }
        
        var bufferByteSize: UInt32 = if audioStreamDescription.mBytesPerPacket > 0 {
            audioStreamDescription.mBytesPerPacket * numberOfPackets
        } else {
            packetSizeUpperBound * numberOfPackets
        }
        if bufferByteSize > maxBufferSize {
            bufferByteSize = maxBufferSize
        } else if bufferByteSize < minBufferSize {
            bufferByteSize = minBufferSize
        }
        
        let numPacketsToRead = bufferByteSize / packetSizeUpperBound
        return (numPacketsToRead, bufferByteSize, estimatedDurationInSeconds)
    }

    // MARK: - Static functions

    static func open(path: String) throws -> AudioFileID {
        var id: AudioFileID?
        try WithCheck(AudioFileOpenURL(URL(fileURLWithPath: path) as CFURL, .readPermission, 0, &id)) { AudioFileError.openError($0) }
        return id!
    }
    
    static func open(url: URL) throws -> AudioFileID {
        var id: AudioFileID?
        try WithCheck(AudioFileOpenURL(url as CFURL, .readPermission, 0, &id)) { AudioFileError.openError($0) }
        return id!
    }
    
    static func getFileType(from id: AudioFileID) throws -> AudioFileTypeID {
        var fileType: AudioFileTypeID = 0
        var size = AudioFileTypeID.size32
        try WithCheck(AudioFileGetProperty(id, kAudioFilePropertyFileFormat, &size, &fileType)) { AudioFileError.getPropertyError($0) }
        return fileType
    }
    
    static func getFileSize(from id: AudioFileID) throws -> UInt64 {
        var size: UInt64 = 0
        var sizeSize = UInt64.size32
        try WithCheck(AudioFileGetProperty(id, kAudioFilePropertyAudioDataByteCount, &sizeSize, &size)) { AudioFileError.getPropertyError($0) }
        return size
    }
    
    static func getFormat(from id: AudioFileID) throws -> AudioStreamBasicDescription {
        var format = AudioStreamBasicDescription()
        var size = AudioStreamBasicDescription.size32
        try WithCheck(AudioFileGetProperty(id, kAudioFilePropertyDataFormat, &size, &format)) { AudioFileError.getPropertyError($0) }
        return format
    }
    
    static func getNumberOfPackets(from id: AudioFileID) throws -> UInt64 {
        var packets: UInt64 = 0
        var size = UInt64.size32 // TODO: Use AudioFileGetPropertyInfo for size?
        try WithCheck(AudioFileGetProperty(id, kAudioFilePropertyAudioDataPacketCount, &size, &packets)) { AudioFileError.getPropertyError($0) }
        return packets
    }
    
    func close() {
        guard let id else { return }
        AudioFileClose(id)
    }
}
