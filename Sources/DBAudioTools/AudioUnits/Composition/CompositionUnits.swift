//  CompositionUnits.swift
//  Created by Dimitri Brukakis on 23.03.24.

import Foundation
import AudioToolbox

// MARK: - Composition Unit

/// A `CompositionUnit`  is one atom of the `Composition`. It can be an
/// InputUnit, OutputUnit, EffectUnit, MixerUnit etc.
public protocol CompositionUnit: AnyObject {
    /// Each `CompositionUnit` needs an `AUNode` to reference it
    var node: AUNode { get }

    /// Create the individual `AUNode` depending on what the node should represent.
    func createNode(use composition: Composition) throws
    
    /// Will be called when preparing the `Composition`.
    func prepare(use composition: Composition) throws
    
    /// Cleanup the the `CompositionUnit`
    func cleanup(use composition: Composition)
}

// MARK: - Input Unit
/// The `InputUnit` is the beginning of the composition. It can be something like a `FileInputUnit`,
/// `StreamInputUnit` etc. An `InputUnit` defines format of the data to be processed.
public protocol InputUnit: CompositionUnit {

    /// Must return the next `CompositionUnit`. Used during the connection of
    /// `AudioUnits` within the `AUGraph`.
    ///
    /// Return `nil`, if there is no next unit.
    var nextUnit: CompositionUnit? { get }

    /// Specifies the input format description for the whole composition.
    var inputFormat: AudioStreamBasicDescription { get }
}

// MARK: - Output Unit

/// The `OutputUnit` is the the end of a composition. It can be a physical output device like speakers or
/// a virtual output.
public protocol OutputUnit: CompositionUnit {
    /// Returns the previous `CompositionUnit`. Used during the connection of
    /// `AudioUnits` within the `AUGraph`.
    var previousUnit: CompositionUnit? { get }
}

// MARK: - Intermediate Unit

/// The `IntermediateUnit` sits between two other `CompositionUnits`. A mixer or an effect
/// is an `IntermediateUnit`.

public protocol IntermediateUnit: CompositionUnit {
    /// Returns the previous `CompositionUnit`. Used during the connection of
    /// `AudioUnits` within the `AUGraph`.
    var previousUnit: CompositionUnit? { get }

    /// Must return the next `CompositionUnit`. Used during the connection of
    /// `AudioUnits` within the `AUGraph`.
    ///
    /// Return `nil`, if there is no next unit.
    var nextUnit: CompositionUnit? { get }
}

// MARK: - Effects Unit

/// An `EffectUnit` is an `IntermediateUnit` that applies an effect to the audio data.
public protocol EffectUnit: IntermediateUnit {
    associatedtype Parameter: EffectParameter
    
    /// Get all `EffectParameter` values for this effect. Every effect unit has
    /// its own set of parameters.
    var parameters: [Parameter] { get }
    
    /// Change an effect parameter.
    func change(parameter: Parameter)
}
