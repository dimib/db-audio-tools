//  FileInputUnit.swift
//  Created by Dimitri Brukakis on 23.03.24.

import Foundation
import AudioToolbox

/// The `FileInputUnit` provides an audio file as input source.
///
public final class FileInputUnit: InputUnit {

    // MARK: - InputUnit implementation
    public var node: AUNode = AUNode()
    public var inputFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
    
    // MARK: - Properties
    private var inputFile: AudioFile?
    private var audioUnit: AudioUnit?
    
    // MARK: - Lifecycle
    init(inputFile: AudioFile) {
        self.inputFile = inputFile
        self.inputFormat = inputFile.fileFormat ?? AudioStreamBasicDescription()
    }
    
    public func cleanup(use composition: Composition) {
        inputFile?.close()
    }
    
    // MARK: - CompositionUnit implementation
    public func createNode(use composition: Composition) throws {
        guard let graph = composition.graph else { throw AudioUnitError.graphNotInitialized }
        var description = AudioComponentDescription(componentType: kAudioUnitType_Generator,
                                                    componentSubType: kAudioUnitSubType_AudioFilePlayer,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        try WithCheck(AUGraphAddNode(graph, &description, &node)) { AudioUnitError.addGraphNodeError($0) }
    }
    
    public func prepare(use composition: Composition) throws {
        guard let graph = composition.graph,
              let inputFile,
              let audioFile = inputFile.id,
              let format = inputFile.fileFormat else {
            throw AudioUnitError.graphNotInitialized
        }
        var fileAudioUnit: AudioUnit?
        try WithCheck(AUGraphNodeInfo(graph, node, nil, &fileAudioUnit)) { AudioUnitError.audioUnitNotFound($0) }
        guard let fileAudioUnit, var audioId = inputFile.id else { return }
    
        try WithCheck(AudioUnitSetProperty(fileAudioUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0,
                                           &audioId, AudioFileID.size32)) { AudioUnitError.setPropertyError($0) }
        
        // Set Region to play
        let framesToPlay = UInt32(inputFile.numberOfPackets) * format.mFramesPerPacket
        let regionTimeStamp = AudioTimeStamp(mSampleTime: 0, mHostTime: 0, mRateScalar: 0, mWordClockTime: 0, mSMPTETime: SMPTETime(),
                                             mFlags: .sampleTimeValid, mReserved: 0)
        var region = ScheduledAudioFileRegion(mTimeStamp: regionTimeStamp, mCompletionProc: nil, mCompletionProcUserData: nil,
                                              mAudioFile: audioFile, mLoopCount: 0, mStartFrame: 0, mFramesToPlay: framesToPlay)
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
        self.audioUnit = fileAudioUnit
    }

    public var nextUnit: CompositionUnit?
}

