//
//  MusicPlayerSequencer.swift
//
//
//  Created by Dimitri Brukakis on 01.03.24.
//

// Documentation section:
// https://www.cloudbees.com/blog/building-a-midi-music-app-for-ios-in-swift


import Foundation
import AudioToolbox

//  ====================================================
//  ## Does not work yet!!!                           ##
//  ====================================================

struct CallbackData {
    let val = 0
    let sequencer: Sequencer
}

private final class MyEventUserData {
    let size: UInt32
    let mem: UnsafeMutablePointer<UInt8>
    
    init(data: [UInt8]) {
        size = MusicEventUserData.size32 + UInt32(data.count)
        mem = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size))
        mem.initialize(repeating: 0, count: Int(size))
        mem.withMemoryRebound(to: MusicEventUserData.self, capacity: 1) { pointer in
            pointer.pointee.length = UInt32(data.count)
            memcpy(&pointer.pointee.data, data, data.count)
        }
    }
    deinit {
        mem.deallocate()
    }
    
    func withMusicEventUserData(body: (UnsafeMutablePointer<MusicEventUserData>) -> Void) {
        mem.withMemoryRebound(to: MusicEventUserData.self, capacity: 1) { pointer in
            body(pointer)
        }
    }
}

/// Sequencer that uses the Music Playere Services. It should work on iOS and VisionOS 🤔
/// See documentation for details:
/// https://developer.apple.com/documentation/audiotoolbox/music_player
///
///
final class MusicPlayerSequencer: Sequencer, SequencerControl {
    
    private var musicPlayer: MusicPlayer?
    private var sequence: MusicSequence?
    private var graph: AUGraph?

    private var callbackData: CallbackData?
    
    override init(beatsPerMinute: UInt32, sequencerTiming: SequencerTiming) {
        super.init(beatsPerMinute: beatsPerMinute, sequencerTiming: sequencerTiming)
    }
    
    deinit {
        if let graph {
            AUGraphStop(graph)
            AUGraphUninitialize(graph)
            AUGraphClose(graph)
        }
        
        if let sequence {
            DisposeMusicSequence(sequence)
        }
        
        if let musicPlayer {
            DisposeMusicPlayer(musicPlayer)
        }
    }

    func start() throws {
        // Start the sequencer
        print("💿 start")
        guard let musicPlayer else { throw SequencerError.notInitialized }
        var startTime: MusicTimeStamp = 0
        try WithCheck(MusicPlayerSetTime(musicPlayer, startTime)) { SequencerError.startStopError($0) }
        try WithCheck(MusicPlayerPreroll(musicPlayer)) { SequencerError.startStopError($0) }
        try WithCheck(MusicPlayerStart(musicPlayer)) { SequencerError.startStopError($0) }
    }
    
    func stop() throws {
        // Stop the sequencer
        guard let musicPlayer else { throw SequencerError.notInitialized }
        try WithCheck(MusicPlayerStop(musicPlayer)) { SequencerError.startStopError($0) }
    }
    
    func load(midi url: URL) throws {
        guard let sequence else { throw SequencerError.notInitialized }
        
        try WithCheck(MusicSequenceFileLoad(sequence, url as CFURL, .midiType, MusicSequenceLoadFlags())) {
            SequencerError.loadMidiError($0)
        }
    }
    
    
    // MARK: - Setup
    public func setup() throws {
        var musicPlayer: MusicPlayer?   // Music Player
        try WithCheck(NewMusicPlayer(&musicPlayer)) { SequencerError.musicPlayerCreationFailed($0) }
        guard let musicPlayer else { throw SequencerError.sequencerError }
        self.musicPlayer = musicPlayer
        
        var sequence: MusicSequence?    // Music Sequence
        try WithCheck(NewMusicSequence(&sequence)) { SequencerError.musicSequenceCreationFailed($0) }
        guard let sequence else { throw SequencerError.sequencerError }
        self.sequence = sequence
        
        var callbackData = CallbackData(sequencer: self)
        self.callbackData = callbackData
        
        try WithCheck(MusicSequenceSetSequenceType(sequence, .samples)) { SequencerError.musicSequenceCreationFailed($0) }
        try WithCheck(MusicSequenceSetUserCallback(sequence, callback, &self.callbackData)) { SequencerError.musicSequenceSetCallbackFailed($0) }
        try WithCheck(MusicPlayerSetSequence(musicPlayer, sequence)) { SequencerError.musicSequenceCreationFailed($0) }
        
        var trackLength: MusicTimeStamp = 1.0
        var tempoTrack: MusicTrack?
        try WithCheck(MusicSequenceGetTempoTrack(sequence, &tempoTrack)) { SequencerError.getTrackError($0) }
        guard let tempoTrack else { throw SequencerError.getTrackError(0) }
        try WithCheck(MusicTrackSetProperty(tempoTrack, kSequenceTrackProperty_TrackLength, &trackLength, MusicTimeStamp.size32)) {
            SequencerError.setPropertyError($0)
        }

        try addTrack(sequence: sequence)
    }
    
    private func addTrack(sequence: MusicSequence) throws {
        var track: MusicTrack?
        try WithCheck(MusicSequenceNewTrack(sequence, &track)) { SequencerError.getTrackError($0) }
        
        var timeStamp: MusicTimeStamp = 0.0
        for note in 0..<100 {
        
            var sequenceData = MyEventUserData(data: [UInt8(note)])
            sequenceData.withMusicEventUserData { userData in
                MusicTrackNewUserEvent(track!, timeStamp, userData)
            }
            
            timeStamp += 1.0
        }
    }
    
    
    private func setup(graph: AUGraph) throws {
        //        var graph: AUGraph?             // Graph
        //        try WithCheck(NewAUGraph(&graph)) { throw AudioUnitError.createGraphError($0) }
        //        guard var graph else { throw SequencerError.sequencerError }
        //        try setup(graph: graph)
        //        self.graph = graph
        //
        //        try WithCheck(MusicSequenceSetAUGraph(sequence, graph)) { SequencerError.musicSequenceCreationFailed($0) }

        try addGeneratorNode(graph: graph)
        try addOutputNode(graph: graph)
    }
    
    private func addGeneratorNode(graph: AUGraph) throws {
        var filePlayerNode: AUNode = 0
        var description = AudioComponentDescription(componentType: kAudioUnitType_Generator,
                                                    componentSubType: kAudioUnitSubType_MIDISynth,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        try WithCheck(AUGraphAddNode(graph, &description, &filePlayerNode)) { AudioUnitError.addGraphNodeError($0) }
    }
    
    private func addOutputNode(graph: AUGraph) throws {
        #if os(macOS)
        let outputSubType = kAudioUnitSubType_MIDISynth
        #else
        let outputSubType = kAudioUnitSubType_VoiceProcessingIO
        #endif
        var outputNode: AUNode = 0
        var description = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice,
                                                    componentSubType: outputSubType,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        try WithCheck(AUGraphAddNode(graph, &description, &outputNode)) { AudioUnitError.addGraphNodeError($0) }
    }

    // MARK: - Callback
    
    private var callback: MusicSequenceUserCallback = { (callbackData: UnsafeMutableRawPointer?, musicSequence: MusicSequence, musicTrack: MusicTrack,
                                                         timeStamp: MusicTimeStamp, eventUserData: UnsafePointer<MusicEventUserData>,
                                                         timeStamp2: MusicTimeStamp, timeStamp3: MusicTimeStamp) in
        guard var data = callbackData?.assumingMemoryBound(to: CallbackData.self).pointee else { return }
        
        debugPrint("💿 Callback: \(data) \(musicTrack) t1=\(timeStamp) t2=\(timeStamp2) t3=\(timeStamp3)")
        debugPrint("💿 Callback: \(eventUserData.pointee.data)")

        var barBeatTime: CABarBeatTime = CABarBeatTime()
//        MusicSequenceBeatsToBarBeatTime(musicSequence, timeStamp, 4, &barBeatTime)
        
        let userData = SequencerUserData(time: SMPTETime(), timeStaps: [timeStamp, timeStamp2, timeStamp3],
                                         barBeatTime: barBeatTime,
                                         userDataLength: eventUserData.pointee.length, userData: [eventUserData.pointee.data])
        
        data.sequencer.delegate?.sequencer(data.sequencer, userData: userData)
    }
}
