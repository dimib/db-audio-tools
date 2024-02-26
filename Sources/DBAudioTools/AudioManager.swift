//
//  AudioManager.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 21.02.24.
//

import Foundation
import AudioToolbox
import AVFoundation

public final class AudioManager {
    
    public enum Service {
        case audioQueue
        case audioUnit
    }
    
    private let fileNames: [(String, String)] = [
        ("Q1a", "sonar-ping-95840"),
        ("Q1b", "sonar-ping-95840"),
        ("Q2", "ping-82822"),
        ("Q3", "little-bell-14606")
    ]
    private var audioQueues: [String: FilePlaybackAudioQueue] = [:]
    private var audioUnits: [String: FilePlaybackAUPlayer] = [:]

    // MARK: - Lifecycle
    public init() {
        setupAudioSession(useSpeaker: true)
    }

    public func setupAudioSession(useSpeaker: Bool) {
        #if os(iOS) || os(watchOS) || os(tvOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true)
            try session.setCategory(useSpeaker ? .playAndRecord : .playback)
            try session.overrideOutputAudioPort(useSpeaker ? .speaker : .none)
        } catch {
            debugPrint("💿 could not setup audio session: \(error)")
        }
        #endif
    }
    
    // MARK: - Public methods
  
    public func play(_ fileName: String, service: Service) {
        do {
            switch service {
            case .audioUnit:
                guard let audioPlayer = audioUnits[fileName] else { return }
                try audioPlayer.start()
            case .audioQueue:
                guard let audioQueue = audioQueues[fileName] else { return }
                try audioQueue.start()
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    public func setup(service: Service) {
        switch service {
        case .audioUnit: registerAudioUnitFiles()
        case .audioQueue: registerAudioQueueFiles()
        }
    }
    
    public func cleanup(service: Service) {
        switch service {
        case .audioUnit:
            for key in audioUnits.keys {
                try? audioUnits[key]?.stop()
                audioUnits[key] = nil
            }
        case .audioQueue:
            for key in audioQueues.keys {
                try? audioQueues[key]?.stop()
                audioQueues[key] = nil
            }
        }
    }

    private func registerAudioUnitFiles() {
        for resource in fileNames {
            do {
                if let path = Bundle.main.path(forResource: (resource.1), ofType: "mp3") {
                    let audioFile = try AudioFile(path: path)
                    let audioPlayer = FilePlaybackAUPlayer(with: audioFile)
                    try audioPlayer.createPlayer()
                    audioUnits[resource.0] = audioPlayer
                }
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    private func registerAudioQueueFiles() {
        for resource in fileNames {
            do {
                if let path = Bundle.main.path(forResource: (resource.1), ofType: "mp3") {
                    let audioFile = try AudioFile(path: path)
                    let audioQueue = FilePlaybackAudioQueue(with: audioFile)
                    try audioQueue.createQueue()
                    audioQueues[resource.0] = audioQueue
                }
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}
