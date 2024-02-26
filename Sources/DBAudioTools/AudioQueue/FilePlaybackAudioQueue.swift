//
//  AudioQueue.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 21.02.24.
//  With a lot of help from
//  https://medium.com/programming-for-music/playing-back-with-audio-queues-c8e9137bc850
//  https://github.com/pmatsinopoulos/PlayingBackWithAudioQueues

import Foundation
import AudioToolbox
import Combine


protocol FilePlaybackAudioQueueDelegate: AnyObject {
    func filePlaybackAudioQueue(_ audioQueue: FilePlaybackAudioQueue, didStartPlaying audioFile: AudioFile)
    func filePlaybackAudioQueue(_ audioQueue: FilePlaybackAudioQueue, didStopPlaying audioFile: AudioFile)
    func filePlaybackAudioQueue(_ audioQueue: FilePlaybackAudioQueue, didFailPlaying audioFile: AudioFile, error: Error)
}

extension FilePlaybackAudioQueueDelegate {
    func filePlaybackAudioQueue(_ audioQueue: FilePlaybackAudioQueue, didStartPlaying audioFile: AudioFile) {}
    func filePlaybackAudioQueue(_ audioQueue: FilePlaybackAudioQueue, didStopPlaying audioFile: AudioFile) {}
    func filePlaybackAudioQueue(_ audioQueue: FilePlaybackAudioQueue, didFailPlaying audioFile: AudioFile, error: Error) {}
}

/// The `FilePlaybackAudioQueue` can be used to play an audio file using
/// an output queue. The `FilePlaybackAudioQueue` must be initialized with
/// a filename / file path that contains the data to be played. The file will remain open
/// as long as the `FilePlaybackAudioQueue` exists.
final class FilePlaybackAudioQueue {
    
    // MARK: - Constants
    private let numberOfBuffers = 3
    private let durationInSeconds = 0.1

    // MARK: - Audio Queue properties
    private var audioQueueRef: AudioQueueRef?
    private var audioQueueTapRef: AudioQueueProcessingTapRef?
    private let inputFile: AudioFile
    private var playbackData: AudioQueuePlaybackData?
    private var tapContext: AudioQueueTapContext?
    private var isRunning = false
    
    private var buffers: [AudioQueueBufferRef?] = {
        Array<AudioQueueBufferRef?>(repeating: nil, count: 3)
    }()
    
    weak var delegate: FilePlaybackAudioQueueDelegate?

    // MARK: Lifecycle
    init(with inputFile: AudioFile) {
        self.inputFile = inputFile
    }
    
    deinit {
        debugPrint("💿 deinit")
        if let audioQueueRef {
            for i in 0..<numberOfBuffers {
                AudioQueueFreeBuffer(audioQueueRef, buffers[i]!)
            }
            AudioQueueDispose(audioQueueRef, true)
            disposeTapCallback()
        }
        if let audioQueueTapRef {
            AudioQueueProcessingTapDispose(audioQueueTapRef)
        }
        inputFile.close()
    }
    
    /// Create the audio queue from the specified `AudioFile`.
    /// - throws when creating the audio queue is not possible
    public func createQueue() throws {
        guard let audioFileId = inputFile.id, var format = inputFile.fileFormat else {
            throw AudioQueueError.noAudioFile
        }
        debugPrint("💿 format \(format)")
        let status = AudioQueueNewOutput(&format, self.audioQueueOutputCallback, nil, nil, nil, 0, &audioQueueRef)
        guard status == noErr, let audioQueueRef  else { throw AudioQueueError.creationError(status) }
        
        try copyEncoderMagicToAudioQueue()
        let bytesForTime = try inputFile.calculateBytesForTime()
            
        let needExtraPackets = format.mBytesPerPacket == 0 || format.mBytesPerFrame == 0
        
        let playbackData = AudioQueuePlaybackData(playbackFile: audioFileId, packetPosition: 0,
                                                  numberOfBytesToRead: bytesForTime.bytesToRead,
                                                  numberOfPacketsToRead: bytesForTime.packetsToRead,
                                                  duration: bytesForTime.estimatedDuration,
                                                  isDone: false, needMorePackets: needExtraPackets)
        self.playbackData = playbackData
        for i in 0..<numberOfBuffers {
            AudioQueueAllocateBuffer(audioQueueRef, playbackData.numberOfBytesToRead, &buffers[i])
        }
        try setupTapCallback()
    }
    
    private func setupTapCallback() throws {
        guard let audioQueueRef, let playbackData, var format = inputFile.fileFormat else {
            throw AudioQueueError.audioQueueNotInitialized
        }
        
        var tapRef: AudioQueueProcessingTapRef?
        var maxFrames: UInt32 = 0;
        self.tapContext = AudioQueueTapContext(audioQueue: audioQueueRef, duration: playbackData.duration)
        let flags = AudioQueueProcessingTapFlags.postEffects
        
        let status = AudioQueueProcessingTapNew(audioQueueRef, self.processingTapCallback, &tapContext, flags, &maxFrames, &format, &tapRef)
        try CheckStatus(status, or: AudioQueueError.tapProcessingError(status))
        self.audioQueueTapRef = tapRef
    }
    
    private func disposeTapCallback() {
        guard let audioQueueTapRef else { return }
        AudioQueueProcessingTapDispose(audioQueueTapRef)
    }
    
    /// Starts the audio playback from the beginning. A running audio queue will be stopped and the playback data will be reset.
    public func start() throws {
        guard let audioQueueRef, var playbackData = self.playbackData else { throw AudioQueueError.audioQueueNotInitialized }
        AudioQueueStop(audioQueueRef, true)
        playbackData.packetPosition = 0
        playbackData.isDone = false
        for i in 0..<numberOfBuffers {
            withUnsafeMutablePointer(to: &playbackData) { ptr in
                if let buffer = buffers[i] {
                    audioQueueOutputCallback(ptr, audioQueueRef, buffer)
                }
            }
        }
        AudioQueueStart(audioQueueRef, nil)
    }
    
    /// Stops the audio queue immediately and resets the playback data to the initial position.
    public func stop() throws {
        guard let audioQueueRef, let playbackData else { throw AudioQueueError.audioQueueNotInitialized }
        AudioQueueStop(audioQueueRef, true)
        playbackData.packetPosition = 0
        playbackData.isDone = false
    }

    /// Resets the audio queue immediately and resets the playback data to the initial position.
    public func reset() throws {
        guard let audioQueueRef, let playbackData else { throw AudioQueueError.audioQueueNotInitialized }
        AudioQueueReset(audioQueueRef)
        playbackData.packetPosition = 0
        playbackData.isDone = false
    }
    
    /// Copies the cookie magic data from the audio file to the audio queue. This might fail but it is not
    /// a reason to throw an error if the magic cookie does not exist.
    private func copyEncoderMagicToAudioQueue() throws {
        guard let audioQueueRef else { throw AudioQueueError.audioQueueNotInitialized }
        var cookieDataSize: UInt32 = 0
        var isWritable: UInt32 = 0
        
        guard let audioFileId = inputFile.id else { throw AudioQueueError.noAudioFile }
        
        let status = AudioFileGetPropertyInfo(audioFileId, kAudioFilePropertyMagicCookieData, &cookieDataSize, &isWritable)
        if status == noErr, cookieDataSize > 0 {
            var magicCookie = [UInt8](repeating: 0, count: Int(cookieDataSize))
            var size = cookieDataSize
            AudioFileGetProperty(audioFileId, kAudioFilePropertyMagicCookieData, &size, &magicCookie)
            AudioQueueSetProperty(audioQueueRef, kAudioQueueProperty_MagicCookie, &magicCookie, size)
        }
    }
    
    // MARK: - Callbacks

    /// Audio Playback callback. Will be called manually when starting the playback and automatically to feed more
    /// sample data.
    ///
    private var audioQueueOutputCallback: AudioQueueOutputCallback = { (inUserData, audioQueueRef, audioQueueBufferRef) in
        guard var playbackData = inUserData?.assumingMemoryBound(to: AudioQueuePlaybackData.self).pointee else { return }
        debugPrint("💿 callback: \(playbackData.packetPosition)")
        guard !playbackData.isDone else { return }
        var numBytes = playbackData.numberOfBytesToRead
        var numPackets = playbackData.numberOfPacketsToRead
        let readStatus = AudioFileReadPacketData(playbackData.playbackFile, false, &numBytes, &playbackData.packetDescs, playbackData.packetPosition,
                                                 &numPackets, audioQueueBufferRef.pointee.mAudioData)
        if readStatus == noErr && numBytes > 0 && numPackets > 0 {
            audioQueueBufferRef.pointee.mAudioDataByteSize = numBytes
            let enqueue = AudioQueueEnqueueBuffer(audioQueueRef, audioQueueBufferRef, UInt32(playbackData.packetDescs.count), &playbackData.packetDescs)
            playbackData.packetPosition += Int64(numPackets)
        } else {
            AudioQueueStop(audioQueueRef, false)
            playbackData.isDone = true
        }
    }
    
//    public typealias AudioQueueProcessingTapCallback = @convention(c) (UnsafeMutableRawPointer, AudioQueueProcessingTapRef, UInt32, UnsafeMutablePointer<AudioTimeStamp>,
//                               UnsafeMutablePointer<AudioQueueProcessingTapFlags>, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<AudioBufferList>) -> Void
    
    private var processingTapCallback: AudioQueueProcessingTapCallback = { inClientData, inAQTap, inNumberFrames, ioTimeStamp, ioFlags, outNumberFrames, ioData in
        let tapContext = inClientData.assumingMemoryBound(to: AudioQueueTapContext.self).pointee
        var sampleTime: Float64 = 0
        var frameCount: UInt32 = 0
        
        AudioQueueProcessingTapGetSourceAudio(inAQTap, inNumberFrames, ioTimeStamp, ioFlags, outNumberFrames, ioData);
        AudioQueueProcessingTapGetQueueTime(inAQTap, &sampleTime, &frameCount)
        debugPrint("💿 processingTapCallback: duration=\(tapContext.durationSampleTime) sampleTime=\(sampleTime) frameCount=\(frameCount)")
        if sampleTime > tapContext.durationSampleTime {
            debugPrint("💿 ende?")
        }
    }
}
