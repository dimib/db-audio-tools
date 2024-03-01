//
//  Sequencer.swift
//
//
//  Created by Dimitri Brukakis on 01.03.24.
//

import Foundation
import AudioToolbox


/// Delegate protocol for audio players that use the `Sequencer`.
public protocol SequencerDelegate: AnyObject {
    func sequencer(_ sequencer: Sequencer, userData: SequencerUserData)
}

public protocol SequencerControl {
    func start() throws
    func stop() throws
}

public struct SequencerUserData {
    public let time: SMPTETime
    public let timeStaps: [MusicTimeStamp]
    public let barBeatTime: CABarBeatTime
    public let userDataLength: UInt32
    public let userData: [UInt8]
}

/// Base class for sequencers.
public class Sequencer {

    /// Definition of the sequencer time (e.g. 4/4, 3/4, ...)
    public enum SequencerTiming {
        case fourFour
    }

    public enum SequencerQuantize {
        case ones
        case twos
        case fours
        case eights
    }

    let beatsPerMinute: UInt32
    let sequencerTiming: SequencerTiming
    let quantization: SequencerQuantize = .fours
    
    public weak var delegate: SequencerDelegate?
    
    init(beatsPerMinute: UInt32, sequencerTiming: SequencerTiming) {
        self.beatsPerMinute = beatsPerMinute
        self.sequencerTiming = sequencerTiming
    }
}


