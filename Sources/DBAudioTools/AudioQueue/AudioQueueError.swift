//
//  Errors.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 21.02.24.
//

import Foundation

enum AudioQueueError: Error {
    case audioQueueNotInitialized
    case noAudioFile
    case getPropertyError(OSStatus)
    case creationError(OSStatus)
    case noMagicCookie(OSStatus)
    case tapProcessingError(OSStatus)
}
