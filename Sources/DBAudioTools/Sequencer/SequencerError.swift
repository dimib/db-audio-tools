//
//  File.swift
//  
//
//  Created by Dimitri Brukakis on 01.03.24.
//

import Foundation

public enum SequencerError: Error {
    case notInitialized
    case musicPlayerCreationFailed(OSStatus)
    case musicSequenceCreationFailed(OSStatus)
    case midiClientCreationFailed(OSStatus)
    case midiDestinationCreationFailed(OSStatus)
    case musicSequenceSetCallbackFailed(OSStatus)
    case musicTrackCreationFailed(OSStatus)
    case getTrackError(OSStatus)
    case newTrackError(OSStatus)
    case musicPlayerError(OSStatus)
    case coreAudioClockError(OSStatus)
    case sequencerError
    case startStopError(OSStatus)
    case setPropertyError(OSStatus)
    case loadMidiError(OSStatus)
    case sequenceTimeError(OSStatus)
}
