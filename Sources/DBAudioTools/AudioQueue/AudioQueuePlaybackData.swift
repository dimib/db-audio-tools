//
//  PlaybackCallbackData.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 22.02.24.
//
// See https://medium.com/programming-for-music/playing-back-with-audio-queues-c8e9137bc850

import Foundation
import AudioToolbox

/// Audio Queue playback callback data
final class AudioQueuePlaybackData {
    let playbackFile: AudioFileID
    var packetPosition: Int64
    var numberOfBytesToRead: UInt32
    var numberOfPacketsToRead: UInt32
    var duration: Float64
    var packetDescs: [AudioStreamPacketDescription]
    var isDone: Bool
    
    init(playbackFile: AudioFileID, packetPosition: Int64, numberOfBytesToRead: UInt32, numberOfPacketsToRead: UInt32, duration: Float64, isDone: Bool, needMorePackets: Bool) {
        self.playbackFile = playbackFile
        self.packetPosition = packetPosition
        self.numberOfBytesToRead = numberOfBytesToRead
        self.numberOfPacketsToRead = numberOfPacketsToRead
        self.duration = duration
        self.packetDescs = needMorePackets ? Array<AudioStreamPacketDescription>(repeating: AudioStreamPacketDescription(), count: Int(numberOfPacketsToRead)) : []
        self.isDone = isDone
    }
}
