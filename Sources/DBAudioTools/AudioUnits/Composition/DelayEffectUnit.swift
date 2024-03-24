//  DelayEffectUnit.swift
//  Created by Dimitri Brukakis on 23.03.24.

import Foundation
import AudioToolbox

// MARK: - Delay effect parameters

enum DelayEffectParameter: CaseIterable, EffectParameter {
    static var allCases: [DelayEffectParameter] = [.feedback(0), .delayTime(0), .wetDryMix(0), .lowPassCutoff(0)]
    
    /// Percent, -100->100, 50
    case feedback(Float)
    
    /// Secs, 0->2, 1
    case delayTime(Float)
    
    /// Global, EqPow Crossfade, 0->100, 50
    case wetDryMix(Float)
    
    /// Hz, 10->(SampleRate/2), 15000
    case lowPassCutoff(Float)

    var parameterId: AudioUnitParameterID {
        switch self {
        case .feedback: kDelayParam_Feedback
        case .delayTime: kDelayParam_DelayTime
        case .wetDryMix: kDelayParam_WetDryMix
        case .lowPassCutoff: kDelayParam_LopassCutoff
        }
    }
    
    var scope: AudioUnitScope { kAudioUnitScope_Global }
}

// MARK: - Delay Effect Unit

final class DelayEffectUnit: EffectUnit {
    
    // MARK: - Types
    typealias Parameter = DelayEffectParameter

    // MARK: - Intermediate Unit implementation
    var previousUnit: CompositionUnit?
    var nextUnit: CompositionUnit?
    
    // MARK: - Composition Unit implementation
    var node: AUNode = AUNode()
    weak var composition: Composition?

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
        self.composition = composition
    }
    
    func prepare(use composition: Composition) throws {
    }
    
    func cleanup(use composition: Composition) {
    }
    
    // MARK: - Effect parameters

    public var parameters: [DelayEffectParameter] {
        let parameters: [DelayEffectParameter] = DelayEffectParameter.allCases.reduce([]) { result, element in
            switch element {
            case .feedback: return result + [.feedback(value(for: element))]
            case .delayTime: return result + [.delayTime(value(for: element))]
            case .wetDryMix: return result + [.wetDryMix(value(for: element))]
            case .lowPassCutoff: return result + [.lowPassCutoff(value(for: element))]
            }
        }
        return parameters
    }

    public func change(parameter: DelayEffectParameter) {
        
        var changeParam = { (param: AudioUnitParameterID, value: Float) in
            guard let audioUnit = self.audioUnit else { return }
            AudioUnitSetParameter(audioUnit, param, kAudioUnitScope_Global, 0, value, 0)
        }
        
        switch parameter {
        case .feedback(let value): changeParam(parameter.parameterId, value)
        case .delayTime(let value): changeParam(parameter.parameterId, value)
        case .wetDryMix(let value): changeParam(parameter.parameterId, value)
        case .lowPassCutoff(let value): changeParam(parameter.parameterId, value)
        }
    }

    public func value(for parameter: DelayEffectParameter) -> Float {
        guard let audioUnit else { return 0 }
        var value: Float = 0
        AudioUnitGetParameter(audioUnit, parameter.parameterId, kAudioUnitScope_Global, 0, &value)
        return value
    }
    
    private var audioUnit: AudioUnit? {
        composition?.audioUnit(for: node)
    }
}
