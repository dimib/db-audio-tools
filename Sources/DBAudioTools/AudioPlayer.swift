//  AudioTool.swift
//  Created by Dimitri Brukakis on 18.03.24.

import Foundation

/// The protocol `AudioPlayer` is used to define the basic functionality of
/// either `AudioQueue` or `AudioUnit` services.

public protocol AudioPlayer {
    
    associatedtype AudioPlayerId

    func load(url: URL, for id: AudioPlayerId) throws
    func load(path: String, for id: AudioPlayerId) throws
    
    func setOutputVolume(_ volume: Float, for id: AudioPlayerId)
    func outputVolume(for id: AudioPlayerId) -> Float
    
    func play(fileId: AudioPlayerId) throws
    func stop(fileId: AudioPlayerId) throws
    func pause(fileId: AudioPlayerId) throws
    
    func unload(fileId: AudioPlayerId)
    
    init()
}
