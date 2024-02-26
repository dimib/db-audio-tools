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
    
    // MARK: - Lifecycle
    public init(with inputFile: AudioFile) {
        self.inputFile = inputFile
    }
    
    deinit {
        debugPrint("💿 deinit")
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

        let status = AUGraphStart(graph)
        try CheckStatus(status, or: AudioUnitError.graphStartError(status))
    }
    
    public func stop() throws {
        guard let graph else { throw AudioUnitError.graphNotInitialized }
        let status = AUGraphStop(graph)
        try CheckStatus(status, or: AudioUnitError.graphStopError(status))
    }
    
    // MARK: - Private functions
    
    private func createGraph() throws {
        let status = NewAUGraph(&graph)
        try CheckStatus(status, or: AudioUnitError.createGraphError(status))
        guard let graph else { return }
        try addGeneratorNode(graph: graph)
        try addOutputNode(graph: graph)
        try connectNodes(graph: graph, node1: filePlayerNode, node2: defaultOutputNode)
        
        let openStatus = AUGraphOpen(graph)
        try CheckStatus(openStatus, or: AudioUnitError.graphOpenError(status))
        let initializeStatus = AUGraphInitialize(graph)
        try CheckStatus(initializeStatus, or: AudioUnitError.graphInitializeError(status))
    }
    
    // MARK: - Adding nodes

    private func addGeneratorNode(graph: AUGraph) throws {
        var description = AudioComponentDescription(componentType: kAudioUnitType_Generator,
                                                    componentSubType: kAudioUnitSubType_AudioFilePlayer,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        let status = AUGraphAddNode(graph, &description, &filePlayerNode)
        try CheckStatus(status, or: AudioUnitError.addGraphNodeError(status))
    }
    
    private func addOutputNode(graph: AUGraph) throws {
        #if os(macOS)
        let outputSubType = kAudioUnitSubType_DefaultOutput
        #else
        let outputSubType = kAudioUnitSubType_VoiceProcessingIO
        #endif
        var description = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                    componentSubType: outputSubType,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        let status = AUGraphAddNode(graph, &description, &defaultOutputNode)
        try CheckStatus(status, or: AudioUnitError.addGraphNodeError(status))
    }
    
    // MARK: - Connecting nodes

    private func connectNodes(graph: AUGraph, node1: AUNode, node2: AUNode) throws {
        let status = AUGraphConnectNodeInput(graph, node1, 0, node2, 0)
        try CheckStatus(status, or:  AudioUnitError.connectNodesError(status))
    }
    
    // MARK: - Prepare file input unit
    private func prepareFileInputUnit() throws {
        guard let graph, let audioFile = inputFile.id, let format = inputFile.fileFormat else {
            throw AudioUnitError.graphNotInitialized
        }
        var fileAudioUnit: AudioUnit?
        let status = AUGraphNodeInfo(graph, filePlayerNode, nil, &fileAudioUnit)
        try CheckStatus(status, or: AudioUnitError.audioUnitNotFound(status))
        guard let fileAudioUnit, var audioId = inputFile.id else { return }
    
        let setPropStatus = AudioUnitSetProperty(fileAudioUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0,
                                                 &audioId, UInt32(MemoryLayout<AudioFileID>.size))
        try CheckStatus(setPropStatus, or: AudioUnitError.setPropertyError(status))
        
        // Set Region to play
        let framesToPlay = UInt32(inputFile.numberOfPackets) * format.mFramesPerPacket
        let regionTimeStamp = AudioTimeStamp(mSampleTime: 0, mHostTime: 0, mRateScalar: 0, mWordClockTime: 0, mSMPTETime: SMPTETime(),
                                             mFlags: .sampleTimeValid, mReserved: 0)
        var region = ScheduledAudioFileRegion(mTimeStamp: regionTimeStamp, mCompletionProc: nil, mCompletionProcUserData: nil, mAudioFile: audioFile,
                                              mLoopCount: 0, mStartFrame: 0, mFramesToPlay: framesToPlay)
        let setProp2Status = AudioUnitSetProperty(fileAudioUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0,
                                                  &region, UInt32(MemoryLayout<ScheduledAudioFileRegion>.size))
        try CheckStatus(setProp2Status, or: AudioUnitError.setPropertyError(status))
        
        // Set sample start timestamp
        var startTimeStamp = AudioTimeStamp(mSampleTime: -1, mHostTime: 0, mRateScalar: 0, mWordClockTime: 0, mSMPTETime: SMPTETime(),
                                            mFlags: .sampleTimeValid, mReserved: 0)
        let setProp3Status = AudioUnitSetProperty(fileAudioUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0,
                                                  &startTimeStamp, UInt32(MemoryLayout<AudioTimeStamp>.size))
        try CheckStatus(setProp3Status, or: AudioUnitError.setPropertyError(status))
        
        let estimatedDuration = (try? inputFile.calculateBytesForTime().estimatedDuration) ?? 0
        let durationInSeconds = region.mFramesToPlay / UInt32(format.mSampleRate)
        debugPrint("💿 just for info: estimated=\(estimatedDuration) duration=\(durationInSeconds)")
    }
    
}
