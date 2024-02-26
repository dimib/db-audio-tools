//
//  AudioUnitErros.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 25.02.24.
//

import Foundation

enum AudioUnitError: Error {
    case graphNotInitialized
    case createGraphError(OSStatus)
    case addGraphNodeError(OSStatus)
    case connectNodesError(OSStatus)
    case graphOpenError(OSStatus)
    case graphInitializeError(OSStatus)
    case audioUnitNotFound(OSStatus)
    case setPropertyError(OSStatus)
    case graphStartError(OSStatus)
    case graphStopError(OSStatus)
}

