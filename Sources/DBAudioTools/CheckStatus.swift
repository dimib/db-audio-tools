//
//  CheckStatus.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 25.02.24.
//

import Foundation

func CheckStatus(_ status: OSStatus, or error: Error) throws {
    if status != noErr {
        debugPrint("💀 status=\(status)")
        throw error
    }
}
