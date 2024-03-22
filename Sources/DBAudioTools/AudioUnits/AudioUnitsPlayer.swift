//
//  File.swift
//
//
//  Created by Dimitri Brukakis on 18.03.24.
//

import Foundation

/// The `AudioUnitsPlayer` is a class that implements the `AudioFilePlayer` protocol to be
/// used with the `AudioUnits` service.

public final class AudioUnitsPlayer: AudioPlayer {
    public typealias AudioPlayerFileId = String
    
    private var audioUnitsFiles: [AudioPlayerFileId: FilePlaybackAUPlayer] = [:]

    public func load(url: URL, for id: AudioPlayerFileId) throws {
        let audioFile = try AudioFile(url: url)
        let audioUnit = FilePlaybackAUPlayer(with: audioFile)
        try audioUnit.createPlayer()
        audioUnitsFiles[id] = audioUnit
    }
    
    public func load(path: String, for id: AudioPlayerFileId) throws {
        let audioFile = try AudioFile(path: path)
        let audioUnit = FilePlaybackAUPlayer(with: audioFile)
        try audioUnit.createPlayer()
        audioUnitsFiles[id] = audioUnit
    }

    public func setOutputVolume(_ volume: Float, for id: String) {
        guard let audioUnit = audioUnitsFiles[id] else { return }
        audioUnit.outputVolume = min(volume, 1000)
    }
    
    public func outputVolume(for id: String) -> Float {
        guard let audioUnit = audioUnitsFiles[id] else { return 0 }
        return audioUnit.outputVolume
    }

    public func play(fileId: AudioPlayerFileId) throws {
        guard let audioUnit = audioUnitsFiles[fileId] else { return }
        try audioUnit.start()
    }
    
    public func stop(fileId: AudioPlayerFileId) throws {
        guard let audioUnit = audioUnitsFiles[fileId] else { return }
        try audioUnit.stop()
    }
    
    public func pause(fileId: AudioPlayerFileId) throws {
    }
    
    public func unload(fileId: AudioPlayerFileId) {
        guard let audioUnit = audioUnitsFiles[fileId] else { return }
        audioUnitsFiles[fileId] = nil
    }
        
    public init() {
    }
}
