//
//  AudioQueueTapContext.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 24.02.24.
//

import Foundation
import AudioToolbox

/// Use this as client data for `AudioQueueProcessingTapNew`
struct AudioQueueTapContext {
    let audioQueue: AudioQueueRef?
    let duration: Float64
    let durationSampleTime: Float64
    init(audioQueue: AudioQueueRef? = nil, duration: Float64) {
        self.audioQueue = audioQueue
        self.duration = duration
        self.durationSampleTime = duration * 10000
    }
}
