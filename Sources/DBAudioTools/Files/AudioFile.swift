//
//  AudioFile.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 22.02.24.
//

import Foundation
import AudioToolbox

struct AudioFile {
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

    init(id: AudioFileID, path: String) throws {
        self.id = id
        self.path = path
    }
    
    init(path: String) throws {
        self.path = path
        self.id = try AudioFile.open(path: path)
    }
    
    // MARK: - Public functionss

    func calculateBytesForTime() throws -> (packetsToRead: UInt32, bytesToRead: UInt32, estimatedDuration: Float64) {
        guard let audioFileId = id else { throw AudioQueueError.noAudioFile }
        let audioStreamDescription = try AudioFile.getFormat(from: audioFileId)
        var packetSizeUpperBound: UInt32 = 0
        var packetSizeUpperBoundSize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        
        var estimatedDurationInSeconds: Float64 = 0
        var estimatedDurationInSecondsSize: UInt32 = UInt32(MemoryLayout<Float64>.size)
        let durationStatus = AudioFileGetProperty(audioFileId, kAudioFilePropertyEstimatedDuration, &estimatedDurationInSecondsSize, &estimatedDurationInSeconds)
        guard durationStatus == noErr else { throw AudioFileError.getPropertyError(durationStatus) }

        let status = AudioFileGetProperty(audioFileId, kAudioFilePropertyPacketSizeUpperBound, &packetSizeUpperBoundSize, &packetSizeUpperBound)
        guard status == noErr else { throw AudioFileError.getPropertyError(status) }
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
        let status = AudioFileOpenURL(URL(fileURLWithPath: path) as CFURL, .readPermission, 0, &id)
        try CheckStatus(status, or: AudioFileError.openError(status))
        return id!
    }
    
    static func getFileType(from id: AudioFileID) throws -> AudioFileTypeID {
        var fileType: AudioFileTypeID = 0
        var size = UInt32(MemoryLayout<AudioFileTypeID>.size)
        let status = AudioFileGetProperty(id, kAudioFilePropertyFileFormat, &size, &fileType)
        try CheckStatus(status, or: AudioFileError.getPropertyError(status))
        return fileType
    }
    
    static func getFileSize(from id: AudioFileID) throws -> UInt64 {
        var size: UInt64 = 0
        var sizeSize = UInt32(MemoryLayout<UInt64>.size)
        let status = AudioFileGetProperty(id, kAudioFilePropertyAudioDataByteCount, &sizeSize, &size)
        try CheckStatus(status, or: AudioFileError.getPropertyError(status))
        return size
    }
    
    static func getFormat(from id: AudioFileID) throws -> AudioStreamBasicDescription {
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioFileGetProperty(id, kAudioFilePropertyDataFormat, &size, &format)
        try CheckStatus(status, or: AudioFileError.getPropertyError(status))
        return format
    }
    
    static func getNumberOfPackets(from id: AudioFileID) throws -> UInt64 {
        var packets: UInt64 = 0
        var size = UInt32(MemoryLayout<UInt64>.size) // TODO: Use AudioFileGetPropertyInfo for size?
        let status = AudioFileGetProperty(id, kAudioFilePropertyAudioDataPacketCount, &size, &packets)
        try CheckStatus(status, or: AudioFileError.getPropertyError(status))
        return packets
    }
    
    func close() {
        guard let id else { return }
        AudioFileClose(id)
    }
}
