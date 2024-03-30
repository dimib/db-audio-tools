//  General.swift
//  Created by Dimitri Brukakis on 23.03.24.

import Foundation
import AudioToolbox

public final class GeneralOutputUnit: OutputUnit {

    // MARK: - OutputUnit implementation
    public var node: AUNode = AUNode()
    
    // MARK: - Properties
    private var audioUnit: AudioUnit?
    
    // MARK: - Lifecycle
    public init() {
    }

    // MARK: - CompositionUnit implementation
    
    public func prepare(use composition: Composition) throws {
    }

    public func createNode(use composition: Composition) throws {
        guard let graph = composition.graph else { throw AudioUnitError.graphNotInitialized }
        #if os(macOS)
        let outputSubType = kAudioUnitSubType_DefaultOutput
        #else
        // https://stackoverflow.com/questions/40257923/how-to-play-a-signal-with-audiounit-ios
        let outputSubType = kAudioUnitSubType_RemoteIO // kAudioUnitSubType_VoiceProcessingIO
        #endif
        var description = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                    componentSubType: outputSubType,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        try WithCheck(AUGraphAddNode(graph, &description, &node)) { AudioUnitError.addGraphNodeError($0) }
    }
    
    public func cleanup(use composition: Composition) {
    }
    
    public var previousUnit: CompositionUnit?
}
