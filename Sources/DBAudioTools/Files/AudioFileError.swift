//
//  Errors.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 25.02.24.
//

import Foundation

public enum AudioFileError: Error {
    case getPropertyError(OSStatus)
    case closeError(OSStatus)
    case openError(OSStatus)
    case notInitialized
}
