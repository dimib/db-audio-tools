//
//  File.swift
//
//
//  Created by Dimitri Brukakis on 18.03.24.
//

import Foundation

/// The `AudioQueuePlayer` is a class that implements the `AudioPlayer` protocol to be
/// used with the `AudioQueue` service.

public final class AudioQueuePlayer: AudioPlayer {
    
    public typealias AudioPlayerFileId = String
    
    private var audioQueueFiles: [AudioPlayerFileId: FilePlaybackAudioQueue] = [:]

    public func load(url: URL, for id: AudioPlayerFileId) throws {
        let audioFile = try AudioFile(url: url)
        let audioQueue = FilePlaybackAudioQueue(with: audioFile)
        try audioQueue.createQueue()
        audioQueueFiles[id] = audioQueue
    }
    
    public func load(path: String, for id: AudioPlayerFileId) throws {
        let audioFile = try AudioFile(path: path)
        let audioQueue = FilePlaybackAudioQueue(with: audioFile)
        try audioQueue.createQueue()
        audioQueueFiles[id] = audioQueue    }
    
    public func play(fileId: AudioPlayerFileId) throws {
        guard let audioQueue = audioQueueFiles[fileId] else { return }
        try audioQueue.start()
    }
    
    public func stop(fileId: AudioPlayerFileId) throws {
        guard let audioQueue = audioQueueFiles[fileId] else { return }
        try audioQueue.stop()
    }
    
    public func pause(fileId: AudioPlayerFileId) throws {
    }
    
    public func unload(fileId: AudioPlayerFileId) {
        guard let audioQueue = audioQueueFiles[fileId] else { return }
        try? audioQueue.reset()
        audioQueueFiles[fileId] = nil
    }
    
    public func setOutputVolume(_ volume: Float, for id: AudioPlayerFileId) {
    }
    
    public func outputVolume(for id: AudioPlayerFileId) -> Float {
        0
    }
    public init() {
    }
}
