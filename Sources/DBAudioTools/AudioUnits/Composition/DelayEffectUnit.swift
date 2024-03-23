//  DelayEffectUnit.swift
//  Created by Dimitri Brukakis on 23.03.24.

import Foundation
import AudioToolbox

final class DelayEffectUnit: EffectUnit {
    
    // MARK: - Intermediate Unit implementation
    var previousUnit: CompositionUnit?
    
    var nextUnit: CompositionUnit?
    
    // MARK: - Composition Unit implementation
    var node: AUNode = AUNode()
    
    // MARK: - Lifecycle
    init() {
        
    }
    deinit {
    }
    
    func createNode(use composition: Composition) throws {
        guard let graph = composition.graph else { throw AudioUnitError.graphNotInitialized }
        var description = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                                    componentSubType: kAudioUnitSubType_Delay,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        try WithCheck(AUGraphAddNode(graph, &description, &node)) { AudioUnitError.addGraphNodeError($0) }
    }
    
    func prepare(use composition: Composition) throws {
    }
    
    func cleanup(use composition: Composition) {
    }
}
