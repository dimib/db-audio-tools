//  EffectParameter.swift
//  Created by Dimitri Brukakis on 24.03.24.

import Foundation
import AudioToolbox

/// An `EffectParameter` controlls changablee values of
/// `EffectUnit` instances. Every `EffectUnit` has its own
/// set of parameters.
public protocol EffectParameter {
    
    /// Audio Unit Parameter ID
    var parameterId: AudioUnitParameterID { get }
    var scope: AudioUnitScope { get }
}
