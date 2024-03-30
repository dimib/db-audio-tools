//
//  File.swift
//
//
//  Created by Dimitri Brukakis on 30.03.24.
//

import Foundation
import AudioToolbox

// MARK: - Low pass filter paramters
public enum LowPassFilterParameter: CaseIterable, EffectParameter {
    public static var allCases: [LowPassFilterParameter] = [.cutoffFrequency(0), .resonance(0)]
    
    /// Cutoff frequency in Hz. Range is 10Hz to (SampleRate/2). Default is 6900Hz.
    case cutoffFrequency(Float)
    
    /// Resonance value. Range is -20dB to 40dB. Default is 0dB.
    case resonance(Float)
    
    public var parameterId: AudioUnitParameterID {
        switch self {
        case .cutoffFrequency: kLowPassParam_CutoffFrequency
        case .resonance: kLowPassParam_Resonance
        }
    }
    
    public var scope: AudioUnitScope { kAudioUnitScope_Global }
}

// MARK: - Low Pass Filter Effect Unit

public final class LowPassFilterEffectUnit: EffectUnit {
    
    // MARK: - Types
    public typealias Parameter = LowPassFilterParameter
    
    // MARK: - Intermediate Unit implementation
    public var previousUnit: CompositionUnit?
    public var nextUnit: CompositionUnit?
    
    // MARK: - Composition Unit implementation
    public var node: AUNode = AUNode()
    weak var composition: Composition?
    
    // MARK: - Lifecycle
    public init() {
    }
    
    deinit {
    }

    public func createNode(use composition: Composition) throws {
        guard let graph = composition.graph else { throw AudioUnitError.graphNotInitialized }
        var description = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                                    componentSubType: kAudioUnitSubType_LowPassFilter,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        try WithCheck(AUGraphAddNode(graph, &description, &node)) { AudioUnitError.addGraphNodeError($0) }
        self.composition = composition
    }

    public func prepare(use composition: Composition) throws {
        
    }
    
    public func cleanup(use composition: Composition) {
        
    }
    
    // MARK: - Effect Parameters
    public var parameters: [LowPassFilterParameter] {
        let parameters: [LowPassFilterParameter] = LowPassFilterParameter.allCases.reduce([]) { result, element in
            switch element {
            case .cutoffFrequency: return result + [.cutoffFrequency(value(for: element))]
            case .resonance: return result + [.resonance(value(for: element))]
            }
        }
        return parameters
    }
    
    public func change(parameter: LowPassFilterParameter) {
        var changeParam = { (param: AudioUnitParameterID, value: Float) in
            guard let audioUnit = self.audioUnit else { return }
            AudioUnitSetParameter(audioUnit, param, kAudioUnitScope_Global, 0, value, 0)
        }
        
        switch parameter {
        case .cutoffFrequency(let value): changeParam(parameter.parameterId, value)
        case .resonance(let value): changeParam(parameter.parameterId, value)
        }
    }
    
    public func value(for parameter: LowPassFilterParameter) -> Float {
        guard let audioUnit else { return 0 }
        var value: Float = 0
        AudioUnitGetParameter(audioUnit, parameter.parameterId, kAudioUnitScope_Global, 0, &value)
        return value
    }
    
    private var audioUnit: AudioUnit? {
        composition?.audioUnit(for: node)
    }
}
