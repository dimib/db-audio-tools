//
//  AudioManager.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 21.02.24.
//

import Foundation
import AudioToolbox

final class AudioManager {
    
    private let fileNames: [(String, String)] = [
        ("Q1a", "sonar-ping-95840"),
        ("Q1b", "sonar-ping-95840"),
        ("Q2", "ping-82822"),
        ("Q3", "little-bell-14606")
    ]
    private var audioFileQueues: [String: FilePlaybackAudioQueue] = [:]
    private var audioPlayers: [String: FilePlaybackAUPlayer] = [:]

    // MARK: - Lifecycle
    init() {
        setup()
    }
    
    // MARK: - Public methods
  
    func playAudioFile(_ fileName: String) {
        do {
            guard let audioPlayer = audioPlayers[fileName] else { return }
            try audioPlayer.start()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
/*
    func playAudioFile(_ fileName: String) {
        do {
            guard let audioQueue = audioFileQueues[fileName] else { return }
            try audioQueue.start()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
*/
    func setup() {
        registerAudioPlayers()
    }

    func cleanup() {
        for key in audioPlayers.keys {
            try? audioPlayers[key]?.stop()
            audioPlayers[key] = nil
        }
    }
/*
    func cleanup() {
        for key in audioFileQueues.keys {
            try? audioFileQueues[key]?.stop()
            audioFileQueues[key] = nil
        }
    }
*/
    private func registerAudioPlayers() {
        for resource in fileNames {
            do {
                if let path = Bundle.main.path(forResource: (resource.1), ofType: "mp3") {
                    let audioFile = try AudioFile(path: path)
                    let audioPlayer = FilePlaybackAUPlayer(with: audioFile)
                    try audioPlayer.createPlayer()
                    audioPlayers[resource.0] = audioPlayer
                }
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
/*
    private func registerAudioFiles() {
        for resource in fileNames {
            do {
                if let path = Bundle.main.path(forResource: (resource.1), ofType: "mp3") {
                    let audioFile = try AudioFile(path: path)
                    let audioQueue = FilePlaybackAudioQueue(with: audioFile)
                    try audioQueue.createQueue()
                    audioFileQueues[resource.0] = audioQueue
                }
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
 */
}
