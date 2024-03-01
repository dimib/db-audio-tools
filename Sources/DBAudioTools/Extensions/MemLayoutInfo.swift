//
//  MemLayoutInfo.swift
//  MetalScreenUIKit
//
//  Created by Dimitri Brukakis on 13.01.24.
//

import Foundation
import MetalKit
import AudioToolbox

/// Convenience functionality for getting memory layout information
protocol MemLayoutInfo {
    static var size: Int { get }
    static var size32: UInt32 { get }
    static var stride: Int { get }
    
    static func size(_ count: Int) -> Int
    static func stride(_ count: Int) -> Int
}

extension MemLayoutInfo {
    static var size: Int { MemoryLayout<Self>.size }
    static var size32: UInt32 { UInt32(Self.size) }
    static var stride: Int { MemoryLayout<Self>.stride }
    
    static func size(_ count: Int) -> Int { MemoryLayout<Self>.size * count }
    static func stride(_ count: Int) -> Int { MemoryLayout<Self>.stride * count }
}

extension SIMD2<Float>: MemLayoutInfo {}
extension SIMD3<Float>: MemLayoutInfo {}
extension SIMD4<Float>: MemLayoutInfo {}
extension Float: MemLayoutInfo {}
extension Float64: MemLayoutInfo {}
extension UInt32: MemLayoutInfo {}
extension UInt64: MemLayoutInfo {}

extension AudioFileID: MemLayoutInfo {}
extension AudioTimeStamp: MemLayoutInfo {}
extension AudioStreamBasicDescription: MemLayoutInfo {}
extension ScheduledAudioFileRegion: MemLayoutInfo {}
extension MusicEventUserData: MemLayoutInfo {}

