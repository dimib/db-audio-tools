//
//  CheckStatus.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 25.02.24.
//

import Foundation

//public func CheckStatus(_ status: OSStatus, or error: Error) throws {
//    if status != noErr {
//        debugPrint("💀 status=\(status)")
//        throw error
//    }
//}

public func WithCheck(_ status: OSStatus, or call: (OSStatus) throws -> Void) throws {
    if status != noErr {
        debugPrint("💀 status=\(status)")
        try call(status)
    }
}

public func WithCheck(_ status: OSStatus, else call: (OSStatus) -> Error) throws {
    if status != noErr {
        debugPrint("💀 status=\(status)")
        throw call(status)
    }
}

