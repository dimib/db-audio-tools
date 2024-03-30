//  Composition.swift
//  Created by Dimitri Brukakis on 23.03.24.

import Foundation
import AudioToolbox

/// A `Composition` is an individual graph with different connected `CompositionUnits`.  Everything
/// can be connected individually.
public final class Composition {
    
    // MARK: - Audio Graph
    private(set) var graph: AUGraph?
    
    // MARK: - Properties
    public private(set) var units: [CompositionUnit]
    
    /// The esitmated duration.
    private var durationInSeconds: Float64?
    
    // MARK: - Lifecycle
    public init(units: [CompositionUnit]) {
        self.units = units
    }
    
    deinit {
        if let graph = graph {
            for unit in units {
                unit.cleanup(use: self)
            }
            
            AUGraphRemoveRenderNotify(graph, renderNotificationCallback, nil)
            
            AUGraphClose(graph)
            DisposeAUGraph(graph)
        }
    }

    /// Creates the `AUGraph`, prepares and connects all `CompositionUnit`.
    public func create() throws {
        try WithCheck(NewAUGraph(&graph)) { AudioUnitError.createGraphError($0) }
        guard let graph else { return }

        // Create all nodes
        for unit in units {
            try unit.createNode(use: self)
        }
        
        // Connect units
        for unit in units {
            if let inputUnit = unit as? InputUnit {
                try connectWithNextUnit(graph: graph, unit: inputUnit)
            } else if let intermediateUnit = unit as? IntermediateUnit {
                try connectWithNextUnit(graph: graph, unit: intermediateUnit)
            }
        }
        
        try WithCheck(AUGraphAddRenderNotify(graph, renderNotificationCallback, nil)) { AudioUnitError.graphInitializeError($0) }
        
        try WithCheck(AUGraphOpen(graph)) { AudioUnitError.graphOpenError($0) }
        try WithCheck(AUGraphInitialize(graph)) { AudioUnitError.graphInitializeError($0) }
    }
    
    /// Connect the `InputUnit` with its next unit.
    private func connectWithNextUnit(graph: AUGraph, unit: InputUnit) throws {
        if let nextUnit = unit.nextUnit {
            try connectNodes(graph: graph, node1: unit.node, node2: nextUnit.node)
        }
    }
    
    /// Connect an `IntermediateUnit` with its next unit.
    private func connectWithNextUnit(graph: AUGraph, unit: IntermediateUnit) throws {
        if let nextUnit = unit.nextUnit {
            try connectNodes(graph: graph, node1: unit.node, node2: nextUnit.node)
        }
    }
    
    private func connectNodes(graph: AUGraph, node1: AUNode, node2: AUNode) throws {
        try WithCheck(AUGraphConnectNodeInput(graph, node1, 0, node2, 0)) { AudioUnitError.connectNodesError($0) }
    }
    
    /// Prepare the `Composition`, init the `AUGraph` etc.
    func prepare() throws {
        guard let graph else { return }

        // Create all nodes
        for unit in units {
            try unit.prepare(use: self)
        }
    }

    // MARK: - Play, Stop, Rewind etc.

    /// Start playing.
    public func start() throws {
        guard let graph else { throw AudioUnitError.graphNotInitialized }
        
        AUGraphStop(graph)

        try prepare()
        try WithCheck(AUGraphStart(graph)) { AudioUnitError.graphStartError($0) }
    }
    
    /// Stop playing.
    public func stop() throws {
        guard let graph else { throw AudioUnitError.graphNotInitialized }
        try WithCheck(AUGraphStop(graph)) { AudioUnitError.graphStopError($0) }
    }
    
    // MARK: - Audio Units
    public func audioUnit(for node: AUNode) -> AudioUnit? {
        guard let graph else { return nil }
        var audioUnit: AudioUnit?
        try? WithCheck(AUGraphNodeInfo(graph, node, nil, &audioUnit)) { AudioUnitError.audioUnitNotFound($0) }
        return audioUnit
    }
    
    // MARK: - Status
    public var isPlaying: Bool {
        guard let graph else { return false }
        var isPlaying: DarwinBoolean = false
        AUGraphIsRunning(graph, &isPlaying)
        debugPrint("🎹 isPlaying=\(isPlaying.boolValue)")
        return isPlaying.boolValue
    }
    
    // MARK: - Render Info Callback
    private var renderNotificationCallback: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) in
        debugPrint("🎹 renderNotification \(inTimeStamp)")
        return 0
    }
}
