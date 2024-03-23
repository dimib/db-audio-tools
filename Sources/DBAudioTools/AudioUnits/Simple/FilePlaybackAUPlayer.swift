//
//  AudioPlayer.swift
//  AudioplayerMac
//
//  Created by Dimitri Brukakis on 25.02.24.
//  With good advice from:
//  https://medium.com/programming-for-music/playing-back-with-audio-units-11c4552aa65e
//  https://github.com/pmatsinopoulos/ap_PlayingBackWithAudioUnits

import Foundation
import AudioToolbox
import CoreAudio

/// Simple file player using AudioUnits
public final class FilePlaybackAUPlayer {
    
    // MARK: - Types
    
    // MARK: - Properties
    private var inputFormat: AudioStreamBasicDescription?
    private var inputFile: AudioFile
    private var graph: AUGraph?
    private var durationInSeconds: Float64?
    
    private var filePlayerNode: AUNode = 0
    private var defaultOutputNode: AUNode = 0
    private var mixerNode: AUNode = 0
    
    // MARK: - Lifecycle
    public init(with inputFile: AudioFile) {
        self.inputFile = inputFile
    }
    
    deinit {
        debugPrint("🎹 deinit")
        if let graph {
            AUGraphStop(graph)
            AUGraphUninitialize(graph);
            AUGraphClose(graph);
        }
        
        inputFile.close()
    }
    
    // MARK: - Player creation
    public func createPlayer() throws {
        try createGraph()
        try prepareFileInputUnit()
    }
    
    public func start() throws {
        guard let graph else { throw AudioUnitError.graphNotInitialized }
        
        AUGraphStop(graph)
        try prepareFileInputUnit()

        try WithCheck(AUGraphStart(graph)) { AudioUnitError.graphStartError($0) }
    }
    
    public func stop() throws {
        guard let graph else { throw AudioUnitError.graphNotInitialized }
        try WithCheck(AUGraphStop(graph)) { AudioUnitError.graphStopError($0) }
    }
    
    // MARK: - Output volume
    
    // https://stackoverflow.com/questions/3094691/setting-volume-on-audio-unit-kaudiounitsubtype-remoteio
    public var outputVolume: Float {
        get {
            do {
                guard let mixerUnit = getAudioUnit(of: kAudioUnitType_Mixer) else { throw AudioUnitError.graphNotInitialized }
                var volume: Float = 0
                try WithCheck(AudioUnitGetParameter(mixerUnit, kStereoMixerParam_Volume, kAudioUnitScope_Output, 0, &volume)) { AudioUnitError.setParamError($0) }
                return volume
            } catch {
                return 0
            }
        }
        set {
            do {
                guard let mixerUnit = getAudioUnit(of: kAudioUnitType_Mixer) else { throw AudioUnitError.graphNotInitialized }
                try WithCheck(AudioUnitSetParameter(mixerUnit, kStereoMixerParam_Volume, kAudioUnitScope_Output, 0, newValue, 0)) { AudioUnitError.setParamError($0) }
            } catch {
            }
        }
    }
    
    public var outputPan: Float {
        get {
            do {
                guard let mixerUnit = getAudioUnit(of: kAudioUnitType_Mixer) else { throw AudioUnitError.graphNotInitialized }
                var pan: Float = 0
                try WithCheck(AudioUnitGetParameter(mixerUnit, kStereoMixerParam_Pan, kAudioUnitScope_Output, 0, &pan)) { AudioUnitError.setParamError($0) }
                return pan
            } catch {
                return 0
            }
        }
        
        set {
            do {
                guard let mixerUnit = getAudioUnit(of: kAudioUnitType_Mixer) else { throw AudioUnitError.graphNotInitialized }
                try WithCheck(AudioUnitSetParameter(mixerUnit, kStereoMixerParam_Pan, kAudioUnitScope_Output, 0, newValue, 0)) { AudioUnitError.setParamError($0) }
            } catch {
            }
        }
    }

    // MARK: - Private functions
    
    private func createGraph() throws {
        try WithCheck(NewAUGraph(&graph)) { AudioUnitError.createGraphError($0) }
        guard let graph else { return }
        try addGeneratorNode(graph: graph)
        try addMixerNode(graph: graph)
        try addOutputNode(graph: graph)
        
        try connectNodes(graph: graph, node1: filePlayerNode, node2: mixerNode)
        try connectNodes(graph: graph, node1: mixerNode, node2: defaultOutputNode)

        try WithCheck(AUGraphOpen(graph)) { AudioUnitError.graphOpenError($0) }
        try WithCheck(AUGraphInitialize(graph)) { AudioUnitError.graphInitializeError($0) }
    }
    
    // MARK: - Adding nodes

    private func addGeneratorNode(graph: AUGraph) throws {
        var description = AudioComponentDescription(componentType: kAudioUnitType_Generator,
                                                    componentSubType: kAudioUnitSubType_AudioFilePlayer,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        try WithCheck(AUGraphAddNode(graph, &description, &filePlayerNode)) { AudioUnitError.addGraphNodeError($0) }
    }
    
    private func addOutputNode(graph: AUGraph) throws {
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
        try WithCheck(AUGraphAddNode(graph, &description, &defaultOutputNode)) { AudioUnitError.addGraphNodeError($0) }
    }
    
    private func addMixerNode(graph: AUGraph) throws {
        
        #if os(macOS)
        var description = AudioComponentDescription(componentType: kAudioUnitType_Mixer,
                                                    componentSubType: kAudioUnitSubType_StereoMixer,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        #endif
        try WithCheck(AUGraphAddNode(graph, &description, &mixerNode)) { AudioUnitError.addGraphNodeError($0) }
        
    }
    
    // MARK: - Finding nodes
    private func getAudioUnit(of type: OSType) -> AudioUnit? {
        guard let graph else { return nil }

        var numberOfNodes: UInt32 = 0
        AUGraphGetNodeCount(graph, &numberOfNodes)
        
        for index in 0..<numberOfNodes {
            var node: AUNode = AUNode()
            AUGraphGetIndNode(graph, index, &node)
            
            var description = AudioComponentDescription()
            var audioUnit: AudioUnit?
            AUGraphNodeInfo(graph, node, &description, &audioUnit)
            
            if description.componentType == type {
                return audioUnit
            }
        }
        return nil
    }
    
    // MARK: - Connecting nodes

    private func connectNodes(graph: AUGraph, node1: AUNode, node2: AUNode) throws {
        try WithCheck(AUGraphConnectNodeInput(graph, node1, 0, node2, 0)) { AudioUnitError.connectNodesError($0) }
    }
    
    // MARK: - Prepare file input unit
    private func prepareFileInputUnit() throws {
        guard let graph, let audioFile = inputFile.id, let format = inputFile.fileFormat else {
            throw AudioUnitError.graphNotInitialized
        }
        var fileAudioUnit: AudioUnit?
        try WithCheck(AUGraphNodeInfo(graph, filePlayerNode, nil, &fileAudioUnit)) { AudioUnitError.audioUnitNotFound($0) }
        guard let fileAudioUnit, var audioId = inputFile.id else { return }
    
        try WithCheck(AudioUnitSetProperty(fileAudioUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0,
                                           &audioId, AudioFileID.size32)) { AudioUnitError.setPropertyError($0) }
        
        // Set Region to play
        let framesToPlay = UInt32(inputFile.numberOfPackets) * format.mFramesPerPacket
        let regionTimeStamp = AudioTimeStamp(mSampleTime: 0, mHostTime: 0, mRateScalar: 0, mWordClockTime: 0, mSMPTETime: SMPTETime(),
                                             mFlags: .sampleTimeValid, mReserved: 0)
        var region = ScheduledAudioFileRegion(mTimeStamp: regionTimeStamp, mCompletionProc: nil, mCompletionProcUserData: nil, mAudioFile: audioFile,
                                              mLoopCount: 0, mStartFrame: 0, mFramesToPlay: framesToPlay)
        try WithCheck(AudioUnitSetProperty(fileAudioUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0,
                                           &region, ScheduledAudioFileRegion.size32)) { AudioUnitError.setPropertyError($0) }
        
        // Set sample start timestamp
        var startTimeStamp = AudioTimeStamp(mSampleTime: -1, mHostTime: 0, mRateScalar: 0, mWordClockTime: 0, mSMPTETime: SMPTETime(),
                                            mFlags: .sampleTimeValid, mReserved: 0)
        try WithCheck(AudioUnitSetProperty(fileAudioUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0,
                                           &startTimeStamp, AudioTimeStamp.size32)) { AudioUnitError.setPropertyError($0) }
        
        let estimatedDuration = (try? inputFile.calculateBytesForTime().estimatedDuration) ?? 0
        let durationInSeconds = region.mFramesToPlay / UInt32(format.mSampleRate)
        debugPrint("🎹 just for info: estimated=\(estimatedDuration) duration=\(durationInSeconds)")
    }
    
    private func prepareOutputUnit() throws {
        guard let graph else {
            throw AudioUnitError.graphNotInitialized
        }

        var outputUnit: AudioUnit?
        try WithCheck(AUGraphNodeInfo(graph, defaultOutputNode, nil, &outputUnit)) { AudioUnitError.audioUnitNotFound($0) }
        
    }
}
