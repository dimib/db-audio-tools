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
import CoreMIDI

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
    
    private static let name: CFString = "DB Audio Sequencer" as CFString
    
    private var musicPlayer: MusicPlayer?
    private var sequence: MusicSequence?
    private var graph: AUGraph?

    private var callbackData: CallbackData?
    
    override init(beatsPerMinute: UInt32, sequencerTiming: SequencerTiming) {
        super.init(beatsPerMinute: beatsPerMinute, sequencerTiming: sequencerTiming)
        
        var callbackData = CallbackData(sequencer: self)
        self.callbackData = callbackData
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
        
        debugPrint("💿 temp = \(tempo)")
        
        try WithCheck(MusicSequenceSetSequenceType(sequence, .beats)) { SequencerError.musicSequenceCreationFailed($0) }
        try WithCheck(MusicSequenceSetUserCallback(sequence, userCallback, &self.callbackData)) { SequencerError.musicSequenceSetCallbackFailed($0) }
        try WithCheck(MusicPlayerSetSequence(musicPlayer, sequence)) { SequencerError.musicSequenceCreationFailed($0) }
        
        var trackLength: MusicTimeStamp = 1.0
        var tempoTrack: MusicTrack?
        try WithCheck(MusicSequenceGetTempoTrack(sequence, &tempoTrack)) { SequencerError.getTrackError($0) }
        
        guard let tempoTrack else { throw SequencerError.getTrackError(0) }
        try WithCheck(MusicTrackSetProperty(tempoTrack, kSequenceTrackProperty_TrackLength, &trackLength, MusicTimeStamp.size32)) { SequencerError.setPropertyError($0) }
        
        try addTrack(sequence: sequence)
        try createMidiDestination(sequence: sequence)
    }
    
    var tempo: Float64 {
        guard let sequence else { return 0 }
        do {
            var seconds: Float64 = 0
            try WithCheck(MusicSequenceGetSecondsForBeats(sequence, 1.0, &seconds)) { SequencerError.sequenceTimeError($0) }
            return seconds
        } catch {
            return 0
        }
    }
        
    func setTempo(bpm: UInt16) throws {
        guard let sequence else { throw SequencerError.notInitialized }
        var seconds: Float64 = 0
        try WithCheck(MusicSequenceGetSecondsForBeats(sequence, 1.0, &seconds)) { SequencerError.sequenceTimeError($0) }
        
    }
    
    private func createMidiDestination(sequence: MusicSequence) throws {
        var clientRef: MIDIClientRef = 0
        try WithCheck(MIDIClientCreate(Self.name, midiNotifyProc, &self.callbackData, &clientRef)) {
            SequencerError.midiClientCreationFailed($0)
        }
        
        var endpointRef: MIDIEndpointRef = 0
        try WithCheck(MIDIDestinationCreateWithProtocol(clientRef, Self.name, ._1_0, &endpointRef, midiReceiveBlock)) {
            SequencerError.midiDestinationCreationFailed($0)
        }
        
        try WithCheck(MusicSequenceSetMIDIEndpoint(sequence, endpointRef)) {
            SequencerError.musicSequenceCreationFailed($0)
        }
    }
    
    private func addTrack(sequence: MusicSequence) throws {
        var track: MusicTrack?
        try WithCheck(MusicSequenceNewTrack(sequence, &track)) { SequencerError.getTrackError($0) }
        
        var timeStamp: MusicTimeStamp = 0.0
        var velocity: UInt8 = 0
        var release: UInt8 = 0
        for note in 1..<10 {
            
            var n1 = MIDINoteMessage(channel: 1, note: UInt8(note), velocity: velocity, releaseVelocity: release, duration: 1.0)
            MusicTrackNewMIDINoteEvent(track!, timeStamp, &n1)
            
//            var instrument: MusicDeviceInstrumentID = 0
//            var group: MusicDeviceGroupID = 0
//            var controls = NoteParamsControlValue(mID: 0, mValue: 0)
//            var param = MusicDeviceNoteParams(argCount: 1, mPitch: 0, mVelocity: 1, mControls: controls)
//            var en1 = ExtendedNoteOnEvent(instrumentID: instrument, groupID: 0, duration: 1, extendedParams: param)
//            MusicTrackNewExtendedNoteEvent(track!, timeStamp, &en1)
            
//             var n2 = MIDINoteMessage(channel: 2, note: UInt8(note), velocity: 80, releaseVelocity: 80, duration: 0.0)
//            MusicTrackNewMIDINoteEvent(track!, timeStamp, &n2)

//            var sequenceData = MyEventUserData(data: [UInt8(note)])
//            sequenceData.withMusicEventUserData { userData in
//                MusicTrackNewUserEvent(track!, timeStamp, userData)
//            }
            
            timeStamp += 4.0
            velocity += 1
            release += 1
        }
    }
    
    // MARK: - Callbacks
    
    /// User Event Callback
    private var userCallback: MusicSequenceUserCallback = { (callbackData: UnsafeMutableRawPointer?, musicSequence: MusicSequence, musicTrack: MusicTrack,
                                                         timeStamp: MusicTimeStamp, eventUserData: UnsafePointer<MusicEventUserData>,
                                                         timeStamp2: MusicTimeStamp, timeStamp3: MusicTimeStamp) in
        guard var data = callbackData?.assumingMemoryBound(to: CallbackData.self).pointee else { return }
        
        debugPrint("💿 User Callback: \(data) \(musicTrack) t1=\(timeStamp) t2=\(timeStamp2) t3=\(timeStamp3)")
        debugPrint("💿 User Callback: \(eventUserData.pointee.data)")

        var barBeatTime: CABarBeatTime = CABarBeatTime()
//        MusicSequenceBeatsToBarBeatTime(musicSequence, timeStamp, 4, &barBeatTime)
        
        let userData = SequencerUserData(time: SMPTETime(), timeStaps: [timeStamp, timeStamp2, timeStamp3],
                                         barBeatTime: barBeatTime,
                                         userDataLength: eventUserData.pointee.length, userData: [eventUserData.pointee.data])
        
        data.sequencer.delegate?.sequencer(data.sequencer, userData: userData)
    }
    
    /// MIDI Endpoint Receive Block
    private var midiReceiveBlock: MIDIReceiveBlock = { (midiEventList, callbackData) in
        let eventList: MIDIEventList = midiEventList.pointee
        debugPrint("💿 MIDI Receive Block: \(eventList.numPackets)")
        
        for midiEventPacket in midiEventList.unsafeSequence() {
            let wordCount = midiEventPacket.pointee.wordCount
            let timeStamp = midiEventPacket.pointee.timeStamp
            let wordCollection = MIDIEventPacket.WordCollection(midiEventPacket)
            let hex = wordCollection.map { String(format: "%04x", $0) }
        
            debugPrint(" 💿 MIDI Receive Packet: \(timeStamp) \(wordCount) \(hex.joined(separator: ","))")
        }
    }
    
    /// MIDINotifyProc = @convention(c) (UnsafePointer<MIDINotification>, UnsafeMutableRawPointer?) -> Void
    private var midiNotifyProc: MIDINotifyProc = { (midiNotification, callbackData) in
        let notification: MIDINotification = midiNotification.pointee
        debugPrint("💿 MIDI Notify Block: \(notification) \(notification.messageID)")
    }
}
