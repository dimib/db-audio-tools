//
//  CoreAudioClockSequencer.swift
//
//  Created by Dimitri Brukakis on 01.03.24.
//  Documentation: https://developer.apple.com/documentation/audiotoolbox/clock_utilities

import Foundation
import AudioToolbox

//  ====================================================
//  ## Does not work yet!!!                           ##
//  ====================================================

/// Sequencer that uses the Core Audio Clock services. This will only work on MacOSX 🙄
/// See documentation for details:
/// https://developer.apple.com/documentation/audiotoolbox/clock_utilities
final class CoreAudioClockSequencer: Sequencer, SequencerControl {
    
    private var clockRef: CAClockRef?
    
    override init(beatsPerMinute: UInt32, sequencerTiming: SequencerTiming) {
        super.init(beatsPerMinute: beatsPerMinute, sequencerTiming: sequencerTiming)
    }
    
    func start() throws {
        // Start the sequencer
    }
    
    func stop() throws {
        // Stop the sequencer
    }
}
