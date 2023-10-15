// Copyright 2023 Cii
//
// This file is part of Rasen.
//
// Rasen is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Rasen is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Rasen.  If not, see <http://www.gnu.org/licenses/>.

// Copyright © 2023 Apple Inc.
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import AVFAudio
import Accelerate

struct Biquad {
    private var filter: vDSP.Biquad<Double>
    init?(coefficients: [Double],
          channelCount: Int = 1, sectionCount: Int = 1) {
        guard let filter = vDSP.Biquad(coefficients: coefficients,
                                       channelCount: UInt(channelCount),
                                       sectionCount: UInt(sectionCount),
                                       ofType: Double.self) else { return nil }
        self.filter = filter
    }
    mutating func apply(input data: [Double]) -> [Double] {
        filter.apply(input: data)
    }
}

final class NotePlayer {
    var notes: [Note] {
        didSet {
            guard isPlaying,
                    notes.count == oldValue.count ?
                        (0 ..< notes.count).contains(where: { !notes[$0].isEqualOtherThanBeatRange(oldValue[$0]) }) :
                        true else { return }
            stopNote()
            playNote()
        }
    }
    var tone: Tone {
        didSet {
            noder.tone = tone
        }
    }
    var volume: Volume {
        get { noder.volume }
        set { noder.volume = newValue }
    }
    var sequencer: Sequencer
    var noder: AVAudioScoreNoder
    var noteIDs = Set<UUID>()
    
    struct NotePlayerError: Error {}
    
    init(notes: [Note], _ tone: Tone, volume: Volume, pan: Double,
         tempo: Double, reverb: Double) throws {
        
        guard let sequencer = Sequencer(timetracks: [],
                                        isAsync: true, startSec: 0) else {
            throw NotePlayerError()
        }
        self.notes = notes
        self.tone = tone
        self.sequencer = sequencer
        noder = .init(rendnotes: [], tone: tone, tempo: tempo,
                      startSec: 0, isAsync: true,
                      volumeAmp: volume.amp, pan: pan, reverb: reverb)
        sequencer.append(noder, id: UUID())
//        sequencer.reverbNode.wetDryMix = Float(reverb) * 100
    }
    deinit {
        sequencer.endEngine()
    }
    
    var isPlaying = false
    
    func play() {
        timer.cancel()
        
        if isPlaying {
            stopNote()
        }
        if !sequencer.isPlaying {
            sequencer.play()
        } else {
            sequencer.startEngine()
        }
        playNote()
        
        isPlaying = true
    }
    private func playNote() {
        noteIDs = []
        noder.rendnotes += notes.map { note in
            let noteID = UUID()
            noteIDs.insert(noteID)
            let fq = note.fq
            return .init(fq: fq,
                         sourceFilter: .init(tone.spectlope.with(lyric: note.lyric)),
                         spectlopeInterpolation: nil,
                         fAlpha: 1,
                         seed: Rendnote.seed(fromFq: fq, sec: .infinity,
                                             position: Point()),
                         overtone: tone.overtone,
                         pitbend: note.pitbend,
                         secRange: -.infinity ..< .infinity,
                         startDeltaSec: 0,
                         volumeAmp: note.volumeAmp,
                         waver: .init(tone),
                         tempo: noder.tempo,
                         sampleRate: noder.format.sampleRate,
                         dftCount: Audio.defaultDftCount,
                         id: noteID)
        }
    }
    private func stopNote() {
        let releaseStartSec = sequencer.currentPositionInSec + 0.05
        for (i, rendnote) in noder.rendnotes.enumerated() {
            if noteIDs.contains(rendnote.id) {
                noder.rendnotes[i].secRange.end = releaseStartSec
            }
        }
        noteIDs = []
    }
    
    static let stopEngineSec = 30.0
    private var timer = OneshotTimer()
    func stop() {
        stopNote()
        
        isPlaying = false
        
        timer.start(afterTime: tone.envelope.release + NotePlayer.stopEngineSec,
                    dispatchQueue: .main) {
        } waitClosure: {
        } cancelClosure: {
        } endClosure: { [weak self] in
            self?.sequencer.stopEngine()
            self?.noder.rendnotes = []
        }
    }
}

final class AVAudioPCMNoder {
    fileprivate weak var sequencer: Sequencer?
    fileprivate var node: AVAudioSourceNode!
    
    init(pcmBuffer: PCMBuffer, startTime: Double,
         contentStartTime: Double, duration: Double,
         volumeAmp: Double, pan: Double, reverb: Double) {
        let sampleRate = pcmBuffer.format.sampleRate
        let scst = startTime + contentStartTime
        let csSampleTime = -min(contentStartTime, 0) * sampleRate
        let cst = Int(csSampleTime)
        let frameLength = min(Int(pcmBuffer.frameLength),
                              Int((duration - min(contentStartTime, 0)) * sampleRate))
        let sampleFrameLength = min(Double(pcmBuffer.frameLength),
                                    (duration - min(contentStartTime, 0)) * sampleRate)
        node = AVAudioSourceNode(format: pcmBuffer.format) {
            [weak self]
            isSilence, timestamp, frameCount, outputData in

            guard let self,
                  let seq = self.sequencer else { return kAudioUnitErr_NoConnection }
            
            guard seq.isPlaying else {
                isSilence.pointee = true
                return noErr
            }
            guard let data = pcmBuffer.floatChannelData else { return kAudioUnitErr_NoConnection }
            
            let frameCount = Int(frameCount)
            let outputBLP
                = UnsafeMutableAudioBufferListPointer(outputData)
            for i in 0 ..< outputBLP.count {
                let nFrames = outputBLP[i].mData!
                    .assumingMemoryBound(to: Float.self)
                for j in 0 ..< frameCount {
                    nFrames[j] = 0
                }
            }
            
            if timestamp.pointee.mFlags.contains(.hostTimeValid) {
                let time = AVAudioTime.seconds(forHostTime: timestamp.pointee.mHostTime - seq.startHostTime) + seq.startTime
                let sampleTime = (time - scst) * sampleRate
                
                guard sampleTime < sampleFrameLength - 1 && sampleTime + Double(frameCount) >= csSampleTime else {
                    isSilence.pointee = true
                    return noErr
                }
                
//                let outputBLP
//                    = UnsafeMutableAudioBufferListPointer(outputData)
//                for i in 0 ..< outputBLP.count {
//                    let nFrames = outputBLP[i].mData!
//                        .assumingMemoryBound(to: Float.self)
//                    for j in 0 ..< frameCount {
//                        nFrames[j] = 0
//                    }
//                }
                
                for i in 0 ..< outputBLP.count {
                    let oFrames = data[i]
                    let nFrames = outputBLP[i].mData!
                        .assumingMemoryBound(to: Float.self)
                    for j in 0 ..< frameCount {
                        let ni = sampleTime + Double(j)
                        if ni >= csSampleTime && ni < sampleFrameLength - 1 {
                            let rni = ni.rounded(.down)
                            let nii = Int(rni)
                            nFrames[j] = .linear(oFrames[nii],
                                                 oFrames[nii + 1],
                                                 t: ni - rni)
                            
                        }
                    }
                }
            } else if timestamp.pointee.mFlags.contains(.sampleTimeValid) {
                let timeI = Int(timestamp.pointee.mSampleTime - scst * sampleRate)
                
                guard timeI < frameLength && timeI + frameCount >= cst else {
                    isSilence.pointee = true
                    return noErr
                }
                
//                let outputBLP
//                    = UnsafeMutableAudioBufferListPointer(outputData)
//                for i in 0 ..< outputBLP.count {
//                    let nFrames = outputBLP[i].mData!
//                        .assumingMemoryBound(to: Float.self)
//                    for j in 0 ..< frameCount {
//                        nFrames[j] = 0
//                    }
//                }
                
                for i in 0 ..< outputBLP.count {
                    let oFrames = data[i]
                    let nFrames = outputBLP[i].mData!
                        .assumingMemoryBound(to: Float.self)
                    for j in 0 ..< frameCount {
                        let ni = timeI + j
                        if ni >= cst && ni < frameLength {
                            nFrames[j] = oFrames[ni]
                        }
                    }
                }
            } else {
                return kAudioUnitErr_NoConnection
            }
            
            return noErr
        }
        if volumeAmp != 1 {
            node.volume = Float(volumeAmp)
        }
        if pan != 0 {
            node.pan = Float(pan)
        }
    }
}

final class AVAudioScoreNoder {
    fileprivate weak var sequencer: Sequencer?
    fileprivate var node: AVAudioSourceNode!
    let format: AVAudioFormat
    var reverb: Double
    
    var volume: Volume {
        get { Volume(amp: Double(node.volume)) }
        set { node.volume = Float(newValue.amp) }
    }
    var pan: Double {
        get { Double(node.pan) }
        set { node.pan = Float(newValue) }
    }
    
    var rendnotes = [Rendnote]()
    var startSec = 0.0 {
        didSet { isSyncFirst = false }
    }
    var isAsync = true
    var isSyncFirst = true
    
    var tone = Tone() {
        didSet {
            if tone != oldValue {
                let waver = Waver(tone),
                    sourceFilter = SourceFilter(tone.spectlope)
                for i in 0 ..< rendnotes.count {
                    rendnotes[i].overtone = tone.overtone
                    rendnotes[i].waver = waver
                    rendnotes[i].sourceFilter = sourceFilter
                    
                    if let dsi = rendnotes[i].deltaSpectlopeInterpolation {
                        let ns = tone.spectlope
                        rendnotes[i].spectlopeInterpolation?.keys = dsi.keys.map {
                            .init(value: $0.value.multiply(ns),
                                  time: $0.time, type: $0.type)
                        }
                    }
                }
            }
            
            if !tone.isEqualWave(oldValue) {
                notewaveDic = [:]
                
                cancelWorkItems()
                updateRendnotes()
            }
        }
    }
    private(set) var tempo = 120.0 {
        didSet {
            notewaveDic = [:]
            
            cancelWorkItems()
            updateRendnotes()
        }
    }
    
    deinit {
        cancelWorkItems()
    }
    
    struct WeakWorkItem {
        var item: DispatchWorkItem?
    }
    var workItems = [NotewaveID: WeakWorkItem]()
    func cancelWorkItems() {
        for key in workItems.keys {
            workItems[key]?.item?.cancel()
            workItems[key]?.item = nil
        }
        workItems = [:]
    }
    
    func updateRendnotes() {
        let ids = rendnotes.reduce(into: [NotewaveID: Rendnote]()) {
            $0[.init($1)] = $1
        }
        let removeNWIDs = notewaveDic.keys.filter { ids[$0] != nil }
        let insertNWIDs = ids.filter { notewaveDic[$0.key] == nil }
        for nwid in removeNWIDs {
            notewaveDic[nwid] = nil
        }
        let sortedINWIDs = insertNWIDs.sorted {
            $0.value.secRange.start < $1.value.secRange.start
        }
        let si = sortedINWIDs.enumerated().reversed().first { ($0.element.value.secRange.start * 16 - 1) / 16 <= startSec }?.offset ?? 0
        let loopedINWIDs = sortedINWIDs.loop(from: si)
        let firstSec = loopedINWIDs.first?.value.secRange.start ?? 0
        for nwid in loopedINWIDs {
            if !isAsync || isSyncFirst && nwid.value.secRange.start == firstSec {
                notewaveDic[nwid.key] = nwid.value.notewave()
            } else {
                var item: DispatchWorkItem?
                item = DispatchWorkItem(qos: .userInitiated) { [weak self] in
                    guard !(item?.isCancelled ?? true) else {
                        DispatchQueue.main.async { [weak self] in
                            self?.workItems[nwid.key]?.item = nil
                            self?.workItems[nwid.key] = nil
                        }
                        item = nil
                        return
                    }
                    
                    let notewave = nwid.value.notewave()
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.notewaveDic[nwid.key] = notewave
                        self?.workItems[nwid.key]?.item = nil
                        self?.workItems[nwid.key] = nil
                    }
                    item = nil
                }
                
                workItems[nwid.key] = .init(item: item!)
                DispatchQueue.global(qos: .userInitiated)
                    .async(execute: item!)
            }
        }
    }
    
    struct NotewaveID: Hashable, Codable {
        var fq: Double,
            sourceFilter: SourceFilter,
            spectlopeInterpolation: Interpolation<Spectlope>?,
            fAlpha: Double,
            seed: UInt64,
            overtone: Overtone,
            pitbend: Pitbend,
            secDur: Double,
            startDeltaSec: Double,
            tempo: Double
        
        init(_ rendnote: Rendnote) {
            fq = rendnote.fq
            sourceFilter = rendnote.sourceFilter
            spectlopeInterpolation = rendnote.spectlopeInterpolation
            fAlpha = rendnote.fAlpha
            seed = rendnote.seed
            overtone = rendnote.overtone
            
            pitbend = rendnote.pitbend.withEnabledPitch
            
            let loopDuration = rendnote.pitbend.isEmpty ?
                1 : rendnote.waver
                .duration(fromSecLength: rendnote.secRange.length)
            secDur = loopDuration
            startDeltaSec = rendnote.startDeltaSec
            
            tempo = rendnote.tempo
        }
    }
    private(set) var notewaveDic = [NotewaveID: Notewave]()
    
    struct Memowave {
        var startSec: Double, releaseSec: Double?, endSec: Double?,
            fq: Double, volumeAmp: Double, waver: Waver, pitbend: Pitbend
        var notewave: Notewave
        
        func contains(sec: Double) -> Bool {
            if let endSec {
                return sec > startSec && sec < endSec
            } else {
                return sec > startSec
            }
        }
    }
    private var memowaves = [UUID: Memowave]()
    private var phases = [UUID: Double]()
    
    let semaphore = DispatchSemaphore(value: 1)
    
    init(rendnotes: [Rendnote], tone: Tone, tempo: Double,
         format: AVAudioFormat = AVAudioFormat(standardFormatWithSampleRate: Audio.defaultSampleRate, channels: 1)!,
         startSec: Double, isAsync: Bool,
         volumeAmp: Double, pan: Double, reverb: Double) {
        
        self.rendnotes = rendnotes
        self.tone = tone
        self.format = format
        self.tempo = tempo
        self.isAsync = isAsync
        self.startSec = startSec
        self.reverb = reverb
        
        let sampleRate = format.sampleRate
        let rSampleRate = 1 / sampleRate
        node = AVAudioSourceNode(format: format) {
            [weak self]
            isSilence, timestamp, frameCount, outputData in

            guard let self,
                  let seq = self.sequencer else { return kAudioUnitErr_NoConnection }
            
            guard seq.isPlaying else {
                isSilence.pointee = true
                return noErr
            }
            
            let frameCount = Int(frameCount)
            let outputBLP
                = UnsafeMutableAudioBufferListPointer(outputData)
            for i in 0 ..< outputBLP.count {
                let nFrames = outputBLP[i].mData!
                    .assumingMemoryBound(to: Float.self)
                for j in 0 ..< frameCount {
                    nFrames[j] = 0
                }
            }
            
            let sec: Double
            if timestamp.pointee.mFlags.contains(.hostTimeValid) {
                let dHostTime = timestamp.pointee.mHostTime > seq.startHostTime ?
                    timestamp.pointee.mHostTime - seq.startHostTime : 0
                let nSec = AVAudioTime.seconds(forHostTime: dHostTime) + seq.startTime
                sec = nSec
            } else if timestamp.pointee.mFlags.contains(.sampleTimeValid) {
                sec = timestamp.pointee.mSampleTime * rSampleRate
            } else {
                return kAudioUnitErr_NoConnection
            }
            
            self.semaphore.wait()
            let rendnotes = self.rendnotes
            self.semaphore.signal()
            for rendnote in rendnotes {
                let startSec = rendnote.secRange.start.isInfinite ?
                    sec : rendnote.secRange.start
                let secI = Int((sec - startSec) * sampleRate)
                if rendnote.secRange.end.isInfinite {
                    if secI + frameCount >= 0
                        && self.memowaves[rendnote.id] == nil {
                        
                        let nwid = NotewaveID(rendnote)
                        
                        let notewave: Notewave
                        if let nw = self.notewaveDic[nwid] {
                            notewave = nw
                        } else {
                            notewave = rendnote.notewave()
                            self.notewaveDic[nwid] = notewave
                        }
                        self.memowaves[rendnote.id]
                            = Memowave(startSec: startSec,
                                       releaseSec: nil,
                                       endSec: nil,
                                       fq: rendnote.fq,
                                       volumeAmp: rendnote.volumeAmp,
                                       waver: rendnote.waver,
                                       pitbend: rendnote.pitbend,
                                       notewave: notewave)
                        self.phases[rendnote.id] = 0
                    }
                } else {
                    let length = rendnote.secRange.end - startSec
                    let secDur = rendnote.waver.duration(fromSecLength: length)
                    let frameLength = Int(secDur * sampleRate)
                    if sec >= startSec
                        && startSec < rendnote.secRange.end
                        && secI < frameLength && secI + frameCount >= 0
                        && self.memowaves[rendnote.id] == nil {
                        
                        let nwid = NotewaveID(rendnote)
                        
                        let notewave: Notewave
                        if let nw = self.notewaveDic[nwid] {
                            notewave = nw
                        } else {
                            notewave = rendnote.notewave()
                            self.notewaveDic[nwid] = notewave
                        }
                        
                        self.memowaves[rendnote.id]
                            = Memowave(startSec: startSec,
                                       releaseSec: startSec + length,
                                       endSec: startSec + secDur,
                                       fq: rendnote.fq,
                                       volumeAmp: rendnote.volumeAmp,
                                       waver: rendnote.waver,
                                       pitbend: rendnote.pitbend,
                                       notewave: notewave)
                        self.phases[rendnote.id] = 0
                    } else if let memowave = self.memowaves[rendnote.id], !rendnote.secRange.end.isInfinite,
                              memowave.endSec == nil {
                        
                        self.memowaves[rendnote.id]?.releaseSec = startSec + length
                        self.memowaves[rendnote.id]?.endSec = startSec + secDur
                    }
                }
            }
            
            for (id, memowave) in self.memowaves {
                if let endSec = memowave.endSec,
                    sec < memowave.startSec || sec >= endSec {
                    
                    self.memowaves[id] = nil
                    self.phases[id] = nil
                }
            }
            
            guard !self.memowaves.isEmpty else {
                isSilence.pointee = true
                return noErr
            }
            
//            let outputBLP
//                = UnsafeMutableAudioBufferListPointer(outputData)
//            for i in 0 ..< outputBLP.count {
//                let nFrames = outputBLP[i].mData!
//                    .assumingMemoryBound(to: Float.self)
//                for j in 0 ..< Int(frameCount) {
//                    nFrames[j] = 0
//                }
//            }
            
            let frames = outputBLP[0].mData!
                .assumingMemoryBound(to: Float.self)
            
            let memowaves = self.memowaves
            var phases = self.phases
            for (id, memowave) in memowaves {
                var phase = phases[id]!
                let notewave = memowave.notewave
                let waver = memowave.waver
                guard notewave.samples.count >= 4 else { continue }
                let count = Double(notewave.samples.count)
                if !notewave.isLoop && phase >= count { continue }
                phase = phase.loop(0 ..< count)
                
                for i in 0 ..< Int(frameCount) {
                    let nSec = Double(i) * rSampleRate + sec
                    guard nSec >= memowave.startSec else { continue }
                    let waverAmp = waver
                        .volume(atTime: nSec,
                                releaseTime: memowave.releaseSec,
                                startTime: memowave.startSec)
                    let pitbendAmp = waver.pitbend
                        .amp(atT: nSec - memowave.startSec)
                    let nVolumeAmp
                        = memowave.volumeAmp * waverAmp * pitbendAmp
                    
                    frames[i] += Float(notewave
                        .sample(at: i,
                                tempo: tempo,
                                sec: nSec - memowave.startSec,
                                volumeAmp: nVolumeAmp,
                                from: waver,
                                atPhase: &phase))
                }
                
                phases[id] = phase
            }
            self.phases = phases
            
            for i in 1 ..< outputBLP.count {
                let nFrames = outputBLP[i].mData!
                    .assumingMemoryBound(to: Float.self)
                for j in 0 ..< Int(frameCount) {
                    nFrames[j] = frames[j]
                }
            }
            
            return noErr
        }
        if volumeAmp != 1 {
            node.volume = Float(volumeAmp)
        }
        if pan != 0 {
            node.pan = Float(pan)
        }
        
        updateRendnotes()
    }
}

final class Sequencer {
    let pcmNodes: [(node: AVAudioSourceNode, reverbNode: AVAudioUnitReverb)]
    let pcmNoders: [UUID: AVAudioPCMNoder]
    private(set) var scoreNodes: [(node: AVAudioSourceNode, reverbNode: AVAudioUnitReverb)]
    private(set) var scoreNoders: [UUID: AVAudioScoreNoder]
    private(set) var mixings: [UUID: AVAudioMixing]
    private(set) var allMainNodes: [AVAudioNode]
    private(set) var allReverbNodes: [AVAudioUnitReverb]
    private(set) var reverbs: [UUID: AVAudioUnitReverb]
    let mixerNode: AVAudioMixerNode
    let limiterNode: AVAudioUnitEffect
    let engine: AVAudioEngine
    
    fileprivate var startTime = 0.0, startHostTime: UInt64 = 0
    var isPlaying = false
    
    let secoundDuration: Double
    
    init?(timetracks: [Timetrack], isAsync: Bool, startSec: Double,
          perceptionDelaySec: Double = 0.05,
          clipHandler: ((Float) -> ())? = nil) {
        let timetracks = timetracks.filter { !$0.isEmpty }
        
        struct TrackKey: Hashable {
            var tone: Tone, volumeAmp: Double,
                pan: Double, reverb: Double, tempo: Rational
        }
        struct Track {
            var tone: Tone, volumeAmp: Double,
                pan: Double, reverb: Double, tempo: Rational
            var rendnotes: [Rendnote]
            var id: UUID
        }
        
        var pcmNodes = [(node: AVAudioSourceNode,
                         reverbNode: AVAudioUnitReverb)]()
        var pcmNoders = [UUID: AVAudioPCMNoder]()
        var mixings = [UUID: AVAudioMixing]()
        var allMainNodes = [AVAudioNode]()
        var reverbs = [UUID: AVAudioUnitReverb]()
        var allReverbNodes = [AVAudioUnitReverb]()
        
        var tracks = [TrackKey: Track](), sSecDur = perceptionDelaySec
        for (tti, timetrack) in timetracks.enumerated() {
            let secDur = timetrack.secDuration
            guard secDur > 0 else { continue }
            for (position, timeframe) in timetrack.timeframes {
                guard timeframe.isAudio
                        && timeframe.beatRange.length > 0
                        && timeframe.beatRange.end > 0 else { continue }
                
                if let pcmBuffer = timeframe.pcmBuffer,
                   let volume = timeframe.volume,
                   let localBeatRange = timeframe.localBeatRange {
                    
                    let beatRange = timeframe.beatRange, dSec: Double
                    
                    if timeframe.score != nil {
                        let emptyTimetrack = Timetrack(timeframes: [(Point(), .init(beatRange: 0 ..< 4))])
                        dSec = Double(emptyTimetrack.secDuration)
                    } else {
                        dSec = 0
                    }
                    
                    let sBeat = beatRange.start + max(localBeatRange.start, 0)
                    let inSBeat = min(localBeatRange.start, 0)
                    let eBeat = beatRange.start + min(localBeatRange.end, beatRange.length)
                    let startSec = Double(timeframe
                        .sec(fromBeat: sBeat)) - dSec + sSecDur
                    let contentStartSec = Double(timeframe
                        .sec(fromBeat: inSBeat))
                    let secDur = Double(timeframe
                        .sec(fromBeat: max(eBeat - sBeat, 0))) + dSec * 2
                    let noder = AVAudioPCMNoder(pcmBuffer: pcmBuffer,
                                                startTime: startSec,
                                                contentStartTime: contentStartSec,
                                                duration: secDur,
                                                volumeAmp: volume.amp,
                                                pan: timeframe.pan ?? 0,
                                                reverb: timeframe.reverb ?? 0)
                    
                    let reverbNode = AVAudioUnitReverb()
                    reverbNode.loadFactoryPreset(.mediumHall)
                    reverbNode.wetDryMix = Float(timeframe.reverb ?? 0) * 100
                    reverbs[timeframe.id] = reverbNode
                    
                    pcmNodes.append((noder.node, reverbNode))
                    
                    pcmNoders[timeframe.id] = noder
                    mixings[timeframe.id] = noder.node
                    allMainNodes.append(noder.node)
                    allReverbNodes.append(reverbNode)
                    continue
                }
                
                guard let score = timeframe.score,
                      !score.notes.isEmpty else { continue }
                
                var timeframe = timeframe
                func update(at tti: Int,
                            fol: FirstOrLast) -> Bool {
                    guard (0 ..< timetracks.count).contains(tti) else { return false }
                    let oTimetrack = timetracks[tti]
                    var minTimeframe: Timeframe?, minDS = Double.infinity
                    for (oPosition, oTimeframe) in oTimetrack.timeframes {
                        if let score = oTimeframe.score, score.isVoice {
                            let ds = position.distanceSquared(oPosition)
                            if ds < minDS {
                                minDS = ds
                                minTimeframe = oTimeframe
                            }
                        }
                    }
                    guard let nMinTimeframe = minTimeframe else { return false }
                    let beatDur = oTimetrack.secDuration
                    var note = nMinTimeframe.score!.sortedNotes[fol]
                    switch fol {
                    case .first:
                        let sSec = note.beatRange.start + beatDur
                        let eSec = note.beatRange.end + beatDur
                        note.beatRange = sSec ..< eSec
                        timeframe.score?.notes.append(note)
                    case .last:
                        let sSec = note.beatRange.start - beatDur
                        let eSec = note.beatRange.end - beatDur
                        note.beatRange = sSec ..< eSec
                        timeframe.score?.notes.insert(note, at: 0)
                    }
                    return true
                }
                let isUsingFirst = !update(at: tti - 1, fol: .last)
                let isUsingLast = !update(at: tti + 1, fol: .first)
                
                let rendnotes = Score.rendnotes(from: score, timeframe,
                                                position: position,
                                                startSecDur: sSecDur,
                                                isUsingFirst: isUsingFirst,
                                                isUsingLast: isUsingLast)
                let value = TrackKey(tone: score.tone,
                                     volumeAmp: score.volumeAmp,
                                     pan: score.pan,
                                     reverb: score.reverb,
                                     tempo: timeframe.tempo)
                if tracks[value] != nil {
                    tracks[value]?.rendnotes += rendnotes
                } else {
                    tracks[value] = .init(tone: score.tone,
                                          volumeAmp: score.volumeAmp,
                                          pan: score.pan,
                                          reverb: score.reverb,
                                          tempo: timeframe.tempo,
                                          rendnotes: rendnotes,
                                          id: timeframe.id)
                }
            }
            
            sSecDur += Double(timetrack.secDuration)
        }
        tracks = tracks.filter { !$0.value.rendnotes.isEmpty }
        
        let engine = AVAudioEngine()
        
        let mixerNode = AVAudioMixerNode()
        engine.attach(mixerNode)
        self.mixerNode = mixerNode
        
        var scoreNodes = [(node: AVAudioSourceNode,
                           reverbNode: AVAudioUnitReverb)]()
        var scoreNoders = [UUID: AVAudioScoreNoder]()
        
        for (_, track) in tracks {
            let noder = AVAudioScoreNoder(rendnotes: track.rendnotes,
                                          tone: track.tone,
                                          tempo: Double(track.tempo),
                                          startSec: startSec,
                                          isAsync: isAsync,
                                          volumeAmp: track.volumeAmp,
                                          pan: track.pan,
                                          reverb: track.reverb)
            
            let reverbNode = AVAudioUnitReverb()
            reverbNode.loadFactoryPreset(.mediumHall)
            reverbNode.wetDryMix = Float(track.reverb) * 100
            reverbs[track.id] = reverbNode
            
            scoreNodes.append((noder.node, reverbNode))
            scoreNoders[track.id] = noder
            mixings[track.id] = noder.node
            allMainNodes.append(noder.node)
            allReverbNodes.append(reverbNode)
        }
        
        secoundDuration = sSecDur
        
        for (node, reverbNode) in pcmNodes {
            engine.attach(node)
            engine.attach(reverbNode)
            engine.connect(node,
                           to: reverbNode,
                           format: node.outputFormat(forBus: 0))
            engine.connect(reverbNode,
                           to: mixerNode,
                           format: reverbNode.outputFormat(forBus: 0))
        }
        self.pcmNodes = pcmNodes
        self.pcmNoders = pcmNoders
        
        for (node, reverbNode) in scoreNodes {
            engine.attach(node)
            engine.attach(reverbNode)
            engine.connect(node,
                           to: reverbNode,
                           format: node.outputFormat(forBus: 0))
            engine.connect(reverbNode,
                           to: mixerNode,
                           format: reverbNode.outputFormat(forBus: 0))
        }
        self.scoreNodes = scoreNodes
        self.scoreNoders = scoreNoders
        
        if let clipHandler = clipHandler {
            mixerNode.installTap(onBus: 0, bufferSize: 512, format: nil) { buffer, time in
                guard !buffer.isEmpty else { return }
                var peak: Float = 0.0
                for i in 0 ..< buffer.channelCount {
                    buffer.enumerated(channelIndex: i) { _, v in
                        let av = abs(v)
                        if av > peak {
                            peak = av
                        }
                    }
                }
                clipHandler(peak)
            }
        }
        
        let limiterNode = AVAudioUnitEffect.limiter()
        engine.attach(limiterNode)
        self.limiterNode = limiterNode
        
        engine.connect(mixerNode, to: limiterNode,
                       format: mixerNode.outputFormat(forBus: 0))
        engine.connect(limiterNode, to: engine.mainMixerNode,
                       format: limiterNode.outputFormat(forBus: 0))
        
        mixings.forEach {
            let v = $0.value.volume
            $0.value.volume = 0
            $0.value.volume = v
            let a = $0.value.pan
            $0.value.pan = 0
            $0.value.pan = a
        }
        
        self.engine = engine
        
        self.allMainNodes = allMainNodes
        self.allReverbNodes = allReverbNodes
        self.mixings = mixings
        self.reverbs = reverbs
        
        pcmNoders.forEach { $0.value.sequencer = self }
        scoreNoders.forEach { $0.value.sequencer = self }
    }
}
extension Sequencer {
    func append(_ noder: AVAudioScoreNoder, id: UUID) {
        let reverbNode = AVAudioUnitReverb()
        reverbNode.loadFactoryPreset(.mediumHall)
        reverbNode.wetDryMix = Float(noder.reverb) * 100
        reverbs[id] = reverbNode
        
        scoreNodes.append((noder.node, reverbNode))
        scoreNoders[id] = noder
        mixings[id] = noder.node
        allMainNodes.append(noder.node)
        allReverbNodes.append(reverbNode)
        
        engine.attach(reverbNode)
        
        engine.attach(noder.node)
        engine.connect(noder.node,
                       to: reverbNode,
                       format: noder.node.outputFormat(forBus: 0))
        
        engine.connect(reverbNode,
                       to: mixerNode,
                       format: reverbNode.outputFormat(forBus: 0))
        
        noder.sequencer = self
    }
    
    var currentPositionInSec: Double {
        get {
            isPlaying ?
                AVAudioTime.seconds(forHostTime: AudioGetCurrentHostTime() - startHostTime) + startTime :
                startTime
        }
        set {
            startHostTime = AudioGetCurrentHostTime()
            startTime = newValue
        }
    }
    
    func startEngine() {
        if !engine.isRunning {
            try? engine.start()
        }
    }
    func stopEngine() {
        isPlaying = false
        if engine.isRunning {
            engine.stop()
        }
    }
    func endEngine() {
        engine.stop()
        engine.reset()
        
        for node in allMainNodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        for node in allReverbNodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        engine.disconnectNodeOutput(mixerNode)
        engine.detach(mixerNode)
        engine.disconnectNodeOutput(limiterNode)
        engine.detach(limiterNode)
    }
    func play() {
        startEngine()
        startHostTime = AudioGetCurrentHostTime()
        isPlaying = true
    }
    func stop() {
        isPlaying = false
    }
}
extension Sequencer {
    var clippingAudioUnit: ClippingAudioUnit {
        limiterNode.auAudioUnit as! ClippingAudioUnit
    }
    
    struct ExportError: Error {}
    
    func audio(sampleRate: Double,
               clippingAmp: Float? = Audio.floatClippingAmp,
               progressHandler: (Double, inout Bool) -> ()) throws -> Audio? {
        guard let buffer = try buffer(sampleRate: sampleRate,
                                      clippingAmp: clippingAmp,
                                      progressHandler: progressHandler) else { return nil }
        return Audio(pcmData: buffer.pcmData)
    }
    func buffer(sampleRate: Double,
                clippingAmp: Float? = Audio.floatClippingAmp,
                progressHandler: (Double, inout Bool) -> ()) throws -> AVAudioPCMBuffer? {
        let oldClippingAmp = clippingAudioUnit.clippingAmp
        clippingAudioUnit.clippingAmp = clippingAmp
        defer { clippingAudioUnit.clippingAmp = oldClippingAmp }
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: sampleRate,
                                         channels: 2,
                                         interleaved: true) else { throw ExportError() }
        try engine.enableManualRenderingMode(.offline,
                                             format: format,
                                             maximumFrameCount: 512)
        try engine.start()
        isPlaying = true
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                            frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            
            isPlaying = false
            endEngine()
            throw ExportError()
        }
        
        let length = AVAudioFramePosition(secoundDuration * sampleRate)
        
        guard let allBuffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                               frameCapacity: AVAudioFrameCount(length)) else {
            throw ExportError()
        }
        
        var stop = false
        while engine.manualRenderingSampleTime < length {
            do {
                let mrst = engine.manualRenderingSampleTime
                let frameCount = length - mrst
                let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
                let status = try engine.renderOffline(framesToRender, to: buffer)
                switch status {
                case .success:
                    if let ca = clippingAmp {
                        buffer.clip(amp: Float(ca))
                    }
                    
                    allBuffer.append(buffer)
                    progressHandler(Double(mrst) / Double(length), &stop)
                    if stop { return nil }
                case .insufficientDataFromInputNode:
                    throw ExportError()
                case .cannotDoInCurrentContext:
                    progressHandler(Double(mrst) / Double(length), &stop)
                    if stop { return nil }
                    Thread.sleep(forTimeInterval: 0.1)
                case .error: throw ExportError()
                @unknown default: throw ExportError()
                }
            } catch {
                isPlaying = false
                endEngine()
                throw error
            }
        }
        
        isPlaying = false
        endEngine()
        
        return allBuffer
    }
    
    func export(url: URL,
                sampleRate: Double,
                isCompress: Bool = true,
                progressHandler: (Double, inout Bool) -> ()) throws {
        if isCompress {
            guard let oBuffer = try buffer(sampleRate: sampleRate,
                                           clippingAmp: nil,
                                           progressHandler: progressHandler) else { return }
            let file = try AVAudioFile(forWriting: url,
                                       settings: oBuffer.format.settings,
                                       commonFormat: oBuffer.format.commonFormat,
                                       interleaved: oBuffer.format.isInterleaved)
            oBuffer.compress(targetDb: -Audio.headroomDb)
            try file.write(from: oBuffer)
            return
        }
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: sampleRate,
                                         channels: 2,
                                         interleaved: true) else { throw ExportError() }

        try engine.enableManualRenderingMode(.offline,
                                             format: format,
                                             maximumFrameCount: 512)
        try engine.start()
        isPlaying = true
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                            frameCapacity: engine.manualRenderingMaximumFrameCount) else {

            isPlaying = false
            endEngine()
            throw ExportError()
        }

        let file = try AVAudioFile(forWriting: url,
                                   settings: engine.manualRenderingFormat.settings,
                                   commonFormat: engine.manualRenderingFormat.commonFormat,
                                   interleaved: engine.manualRenderingFormat.isInterleaved)
        
        var stop = false
        let length = AVAudioFramePosition(secoundDuration * sampleRate)
        while engine.manualRenderingSampleTime < length {
            do {
                let mrst = engine.manualRenderingSampleTime
                let frameCount = length - mrst
                let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
                let status = try engine.renderOffline(framesToRender, to: buffer)
                switch status {
                case .success:
                    buffer.clip(amp: Float(Audio.floatClippingAmp))
                    
                    try file.write(from: buffer)
                    progressHandler(Double(mrst) / Double(length), &stop)
                    if stop { return }
                case .insufficientDataFromInputNode:
                    throw ExportError()
                case .cannotDoInCurrentContext:
                    progressHandler(Double(mrst) / Double(length), &stop)
                    if stop { return }
                    Thread.sleep(forTimeInterval: 0.1)
                case .error: throw ExportError()
                @unknown default: throw ExportError()
                }
            } catch {
                isPlaying = false
                endEngine()
                throw error
            }
        }
        
        isPlaying = false
        endEngine()
    }
}

struct Spectrogram {
    struct SSMP {
        var smp = 0.0
        var pan = 0.0
    }
    struct Frame {
        var time = 0.0
        var ssmps = [SSMP]()
    }
    enum FqType {
        case linear, mel
    }
    
    var frames = [Frame]()
    var ampCount = 0
    var maxFq = 0.0
    var secDuration = 0.0
    var type = FqType.linear
    
    // Issue: Constant-Q or blend 1024 & 2048
    static func `default`(_ buffer: PCMBuffer) -> Self {
        self.init(buffer, windowSize: 2048, windowOverlap: 0.875,
                  type: .mel, isPan: true)
    }
    static func linear(_ buffer: PCMBuffer) -> Self {
        self.init(buffer, windowSize: 1024, windowOverlap: 0.75,
                  type: .linear, isPan: true)
    }
    init(_ buffer: PCMBuffer,
         windowSize: Int,
         windowOverlap: Double,
         type: FqType,
         isPan: Bool) {
        
        let frameCount = buffer.frameCount
        guard buffer.channelCount >= 1,
              frameCount >= windowSize,
              let dft = try? VDFT(previous: nil,
                                  count: windowSize,
                                  direction: .forward,
                                  transformType: .complexComplex,
                                  ofType: Double.self) else { return }
        
        let overlapCount = Int(Double(windowSize) * (1 - windowOverlap))
        let windowWave = vDSP.window(ofType: Double.self,
                                     usingSequence: .hanningNormalized,
                                     count: windowSize,
                                     isHalfWindow: false)
        
        let sampleRate = buffer.sampleRate
        let nd = 2 / Double(windowSize)
        let ssmpCount = windowSize / 2
        
        let inputIs = [Double](repeating: 0, count: windowSize)
        
        maxFq = sampleRate / 2
        
        func unionSsmps(_ ssmpss: [[SSMP]]) -> [SSMP] {
            if buffer.channelCount == 2 {
                return (0 ..< ssmpCount).map {
                    guard $0 > 0 else { return .init() }
                    let leftV = ssmpss[0][$0]
                    let rightV = ssmpss[1][$0]
                    let smp = (leftV.smp + rightV.smp) / 2
                    if isPan {
                        let pan = leftV.smp != rightV.smp ?
                        (leftV.smp < rightV.smp ?
                         -(leftV.smp / (leftV.smp + rightV.smp) - 0.5) * 2 :
                            (rightV.smp / (leftV.smp + rightV.smp) - 0.5) * 2) :
                        0
                        return .init(smp: smp, pan: pan)
                    } else {
                        return .init(smp: smp, pan: 0)
                    }
                }
            } else {
                return ssmpss[0]
            }
        }
        
        var frames = [Frame](capacity: frameCount)
        switch type {
        case .linear:
            for i in stride(from: 0, to: frameCount, by: overlapCount) {
                let t = Double(i) / sampleRate
                let ssmpss = (0 ..< buffer.channelCount).map { ci in
                    var wave = [Double](capacity: windowSize)
                    for j in (i - overlapCount) ..< (i - overlapCount + windowSize) {
                        wave.append(j >= 0 && j < frameCount ? Double(buffer[ci, j]) : 0)
                    }
                    
                    let inputRs = vDSP.multiply(windowWave, wave)
                    let outputs = dft.transform(real: inputRs,
                                                imaginary: inputIs)
                    
                    var nAmps = (0 ..< ssmpCount).map {
                        $0 == 0 ?
                            0 :
                            Double.hypot(outputs.real[$0] / 2,
                                         outputs.imaginary[$0] / 2) * nd
                    }
                    for x in (1 ..< ssmpCount).reversed() {
                        for y in stride(from: x * 2, to: ssmpCount - 1, by: x) {
                            nAmps[x] += nAmps[x] * nAmps[y]
                        }
                    }
                    
                    return (0 ..< ssmpCount).map {
                        let fq =  Double($0) / Double(ssmpCount) * maxFq
                        let db = Loudness.db40Phon(fromFq: fq)
                        return $0 == 0 ?
                            .init() :
                        SSMP(smp: db * Volume(amp: nAmps[$0]).smp,
                             pan: 0)
                    }
                }
                let nssmps = unionSsmps(ssmpss)
                frames.append(Frame(time: t, ssmps: nssmps))
            }
        case .mel:
            func filterBank(minFq: Double,
                            maxFq: Double,
                            sampleCount: Int,
                            filterBankCount: Int) -> [Double] {
                let minMel = Mel.mel(fromFq: minFq)
                let maxMel = Mel.mel(fromFq: maxFq)
                let bankWidth = (maxMel - minMel) / Double(filterBankCount - 1)
                let filterBankFqs = stride(from: minMel, to: maxMel,
                                           by: bankWidth).map {
                    let fq = Mel.fq(fromMel: Double($0))
                    return Int((fq / maxFq) * Double(sampleCount))
                }
                
                var filterBank = [Double](repeating: 0,
                                         count: sampleCount * filterBankCount)
                var baseValue = 1.0, endValue = 0.0
                for i in 0 ..< filterBankFqs.count {
                    let row = i * sampleCount
                    
                    let startFq = filterBankFqs[max(0, i - 1)]
                    let centerFq = filterBankFqs[i]
                    let endFq = i + 1 < filterBankFqs.count ?
                        filterBankFqs[i + 1] : sampleCount - 1
                    
                    let attackWidth = centerFq - startFq + 1
                    if attackWidth > 0 {
                        filterBank.withUnsafeMutableBufferPointer {
                            vDSP_vgenD(&endValue,
                                      &baseValue,
                                      $0.baseAddress!.advanced(by: row + startFq),
                                      1,
                                      vDSP_Length(attackWidth))
                        }
                    }
                    
                    let decayWidth = endFq - centerFq + 1
                    if decayWidth > 0 {
                        filterBank.withUnsafeMutableBufferPointer {
                            vDSP_vgenD(&baseValue,
                                      &endValue,
                                      $0.baseAddress!.advanced(by: row + centerFq),
                                      1,
                                      vDSP_Length(decayWidth))
                        }
                    }
                }
                
                return filterBank
            }
            
            let filterBankCount = 512
            let filterBank = filterBank(minFq: 0,
                                        maxFq: maxFq,
                                        sampleCount: ssmpCount,
                                        filterBankCount: filterBankCount)
            
            for i in stride(from: 0, to: frameCount, by: overlapCount) {
                let t = Double(i) / sampleRate
                let ssmpss = (0 ..< buffer.channelCount).map { ci in
                    var wave = [Double](capacity: windowSize)
                    for j in (i - overlapCount) ..< (i - overlapCount + windowSize) {
                        wave.append(j >= 0 && j < frameCount ? Double(buffer[ci, j]) : 0)
                    }
                    
                    let inputRs = vDSP.multiply(windowWave, wave)
                    let outputs = dft.transform(real: inputRs,
                                                imaginary: inputIs)
                    
                    let nAmps = (0 ..< ssmpCount).map {
                        $0 == 0 ?
                        0 :
                        Double.hypot(outputs.real[$0] / 2,
                                     outputs.imaginary[$0] / 2) * nd
                    }
                    
                    var nSmps = nAmps.map { $0 == 0 ? 0 : Volume(amp: $0).smp }
                    nSmps = (0 ..< ssmpCount).map {
                        let fq =  Double($0) / Double(ssmpCount) * maxFq
                        let db = Loudness.db40PhonScale(fromFq: fq)
                        return db * nSmps[$0]
                    }
                    
                    let nf = [Double](unsafeUninitializedCapacity: filterBankCount) { buffer, initializedCount in
                        
                        nSmps.withUnsafeBufferPointer { nPtr in
                            filterBank.withUnsafeBufferPointer { fPtr in
                                cblas_dgemm(CblasRowMajor,
                                            CblasTrans, CblasTrans,
                                            1,
                                            filterBankCount,
                                            ssmpCount,
                                            1,
                                            nPtr.baseAddress,
                                            1,
                                            fPtr.baseAddress,
                                            ssmpCount,
                                            0,
                                            buffer.baseAddress, filterBankCount)
                            }
                        }
                        
                        initializedCount = filterBankCount
                    }
                    
                    let indices = vDSP.ramp(in: 0 ... Double(ssmpCount),
                                            count: nf.count)
                    vDSP.linearInterpolate(values: nf,
                                           atIndices: indices,
                                           result: &nSmps)
                    
                    return nSmps.map { SSMP(smp: $0, pan: 0) }
                }
                
                let nssmps = unionSsmps(ssmpss)
                frames.append(Frame(time: t, ssmps: nssmps))
            }
        }
        
        var nMaxSmp = 0.0
        for frame in frames {
            nMaxSmp = max(nMaxSmp, frame.ssmps.max(by: { $0.smp < $1.smp })!.smp)
        }
        let rMaxSmp = nMaxSmp == 0 ? 0 : 1 / nMaxSmp
        for i in 0 ..< frames.count {
            for j in 0 ..< frames[i].ssmps.count {
                frames[i].ssmps[j].smp = (frames[i].ssmps[j].smp * rMaxSmp)
                    .clipped(min: 0, max: 1)
            }
        }
        
        self.frames = frames
        ampCount = ssmpCount
        secDuration = Double(frameCount) / sampleRate
    }
    
    static let (redRatio, greenRatio) = {
        var redColor = Color(red: 0.0625, green: 0, blue: 0)
        var greenColor = Color(red: 0, green: 0.0625, blue: 0)
        if redColor.lightness < greenColor.lightness {
            greenColor.lightness = redColor.lightness
        } else {
            redColor.lightness = greenColor.lightness
        }
        return (Double(redColor.rgba.r), Double(greenColor.rgba.g))
    } ()
    
    func image(b: Double = 0, width: Int = 1024, at xi: Int = 0) -> Image? {
        let h = ampCount
        guard let bitmap
                = Bitmap<UInt8>(width: width, height: h,
                                colorSpace: .sRGB) else { return nil }
        func rgamma(_ x: Double) -> Double {
            x <= 0.0031308 ?
                12.92 * x :
                1.055 * (x ** (1 / 2.4)) - 0.055
        }
        
        for x in 0 ..< width {
            for y in 0 ..< h {
                let ssmp = frames[x + xi].ssmps[h - 1 - y]
                let alpha = rgamma(ssmp.smp > 0.5 ? ssmp.smp.clipped(min: 0.5, max: 1, newMin: 0.95, newMax: 1) : ssmp.smp * 0.95 / 0.5)
                guard !alpha.isNaN else {
                    print("NaN:", ssmp.smp)
                    continue
                }
                bitmap[x, y, 0] = ssmp.pan < 0 ? UInt8(rgamma(-ssmp.pan * Self.redRatio) * alpha * Double(UInt8.max)) : 0
                bitmap[x, y, 1] = ssmp.pan > 0 ? UInt8(rgamma(ssmp.pan * Self.greenRatio) * alpha * Double(UInt8.max)) : 0
                bitmap[x, y, 2] = UInt8(b * alpha * Double(UInt8.max))
                bitmap[x, y, 3] = UInt8(alpha * Double(UInt8.max))
            }
        }
        
        return bitmap.image
    }
}

typealias PCMBuffer = AVAudioPCMBuffer
extension AVAudioPCMBuffer {
    struct AVAudioPCMBufferError: Error {}
    
    static var pcmFormat: AVAudioFormat? {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: Audio.defaultSampleRate, channels: 1, interleaved: true)
    }
    
    convenience init?(pcmData: Data) {
        guard !pcmData.isEmpty,
              let format = AVAudioPCMBuffer.pcmFormat else { return nil }
        let desc = format.streamDescription.pointee
        let frameCapacity = UInt32(pcmData.count) / desc.mBytesPerFrame
        self.init(pcmFormat: format, frameCapacity: frameCapacity)
        frameLength = self.frameCapacity
        let audioBuffer = audioBufferList.pointee.mBuffers
        pcmData.withUnsafeBytes { ptr in
            guard let address = ptr.baseAddress else { return }
            audioBuffer.mData?.copyMemory(from: address,
                                          byteCount: Int(audioBuffer.mDataByteSize))
        }
    }
    
    func convertDefaultFormat() throws -> AVAudioPCMBuffer {
        guard let pcmFormat = AVAudioPCMBuffer.pcmFormat,
              let converter = AVAudioConverter(from: format,
                                               to: pcmFormat) else { throw AVAudioPCMBufferError() }
        let tl = Double(frameLength) / format.sampleRate
        let frameLength = AVAudioFrameCount(tl * pcmFormat.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat,
                                            frameCapacity: frameLength) else { throw AVAudioPCMBufferError() }
        buffer.frameLength = frameLength
        
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return self
        }
        var error : NSError?
        let status = converter.convert(to: buffer, error: &error,
                                       withInputFrom: inputBlock)
        guard status != .error else { throw error ?? AVAudioPCMBufferError() }
        return buffer
    }
    
    var pcmData: Data {
        let audioBuffer = audioBufferList.pointee.mBuffers
        return Data(bytes: audioBuffer.mData!,
                    count: Int(audioBuffer.mDataByteSize))
    }
    
    func segment(startingFrame: AVAudioFramePosition,
                 frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let nBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                             frameCapacity: frameCount) else { return nil }
        let bpf = format.streamDescription.pointee.mBytesPerFrame
        let abl = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
        let nabl = UnsafeMutableAudioBufferListPointer(nBuffer.mutableAudioBufferList)
        for (old, new) in zip(abl, nabl) {
            memcpy(new.mData,
                   old.mData?.advanced(by: Int(startingFrame) * Int(bpf)),
                   Int(frameCount) * Int(bpf))
        }
        nBuffer.frameLength = frameCount
        return nBuffer
    }
    
    var cmSampleBuffer: CMSampleBuffer? {
        let audioBufferList = mutableAudioBufferList
        let asbd = format.streamDescription
        var format: CMFormatDescription? = nil
        var status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                    asbd: asbd,
                                                    layoutSize: 0,
                                                    layout: nil,
                                                    magicCookieSize: 0,
                                                    magicCookie: nil,
                                                    extensions: nil,
                                                    formatDescriptionOut: &format)
        guard status == noErr else { return nil }
        
        let ts = CMTimeScale(asbd.pointee.mSampleRate)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: ts),
                                        presentationTimeStamp: CMTime.zero,
                                        decodeTimeStamp: CMTime.invalid)
        var sampleBuffer: CMSampleBuffer? = nil
        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                      dataBuffer: nil,
                                      dataReady: false,
                                      makeDataReadyCallback: nil,
                                      refcon: nil,
                                      formatDescription: format,
                                      sampleCount: CMItemCount(frameLength),
                                      sampleTimingEntryCount: 1,
                                      sampleTimingArray: &timing,
                                      sampleSizeEntryCount: 0,
                                      sampleSizeArray: nil,
                                      sampleBufferOut: &sampleBuffer)
        guard status == noErr, let sampleBuffer = sampleBuffer else { return nil }
        status = CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer,
                                                                blockBufferAllocator: kCFAllocatorDefault,
                                                                blockBufferMemoryAllocator: kCFAllocatorDefault,
                                                                flags: 0,
                                                                bufferList: audioBufferList)
        guard status == noErr else { return nil }
        return sampleBuffer
    }
    
    static func from(url: URL) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url,
                                   commonFormat: .pcmFormatFloat32,
                                   interleaved: false)
        
        let afCount = AVAudioFrameCount(file.length)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: afCount) else { throw AVAudioPCMBufferError() }
        try file.read(into: buffer)
        return buffer
    }
    
    func append(_ buffer: AVAudioPCMBuffer) {
        guard format == buffer.format,
              frameLength + buffer.frameLength <= frameCapacity else {
            fatalError()
        }
        let dst = floatChannelData!
        let src = buffer.floatChannelData!
        memcpy(dst.pointee.advanced(by: stride * Int(frameLength)),
               src.pointee.advanced(by: buffer.stride * Int(0)),
               buffer.stride * Int(buffer.frameLength) * MemoryLayout<Float>.size)
        frameLength += buffer.frameLength
    }
    
    var sampleRate: Double {
        format.sampleRate
    }
    var channelCount: Int {
        Int(format.channelCount)
    }
    var frameCount: Int {
        Int(frameLength)
    }
    var secondsDuration: Double {
        Double(frameLength) / format.sampleRate
    }
    var isEmpty: Bool {
        floatChannelData == nil || frameLength == 0 || channelCount == 0
    }
    subscript(ci: Int, i: Int) -> Float {
        get { floatChannelData![ci][i * stride] }
        set { floatChannelData![ci][i * stride] = newValue }
    }
    func enumerated(channelIndex ci: Int, _ handler: (Int, Float) throws -> ()) rethrows {
        guard let samples = floatChannelData?[ci] else { return }
        for i in 0 ..< frameCount {
            try handler(i, samples[i * stride])
        }
    }
    
    subscript(i: Int) -> Double {
        get { doubleChannelData![i * stride] }
        set { doubleChannelData![i * stride] = newValue }
    }
    var doubleChannelData: UnsafeMutablePointer<Double>? {
        audioBufferList.pointee.mBuffers.mData?.assumingMemoryBound(to: Double.self)
    }
    func enumeratedDouble(_ handler: (Int, Double) throws -> ()) rethrows {
        guard let samples = doubleChannelData else { return }
        for i in 0 ..< frameCount {
            try handler(i, samples[i * stride])
        }
    }
    
    func isOver(amp: Float) -> Bool {
        for ci in 0 ..< channelCount {
            for i in 0 ..< frameCount {
                if abs(self[ci, i]) > amp {
                    return true
                }
            }
        }
        return false
    }
    func clip(amp: Float) {
        for ci in 0 ..< channelCount {
            enumerated(channelIndex: ci) { i, v in
                if abs(v) > amp {
                    self[ci, i] = v < amp ? -amp : amp
                    print("clip", v)
                }
            }
        }
    }
    var doubleData: [[Double]] {
        get {
            var ns = Array(repeating: Array(repeating: 0.0,
                                            count: frameCount),
                           count: channelCount)
            if format.commonFormat == .pcmFormatFloat64 {
                for ci in 0 ..< channelCount {
                    enumeratedDouble() { i, v in
                        ns[ci][i] = v
                    }
                }
                return ns
            } else {
                for ci in 0 ..< channelCount {
                    enumerated(channelIndex: ci) { i, v in
                        ns[ci][i] = Double(v)
                    }
                }
                return ns
            }
        }
        set {
            if format.commonFormat == .pcmFormatFloat64 {
                for ci in 0 ..< channelCount {
                    enumeratedDouble() { i, v in
                        self[i] = newValue[ci][i]
                    }
                }
            } else {
                for ci in 0 ..< channelCount {
                    enumerated(channelIndex: ci) { i, v in
                        self[ci, i] = Float(newValue[ci][i])
                    }
                }
            }
        }
    }
    
    var samplePeakDb: Double {
        var peak = 0.0
        for ci in 0 ..< channelCount {
            enumerated(channelIndex: ci) { _, v in
                peak = max(abs(Double(v)), peak)
            }
        }
        return Volume(amp: peak).db
    }
    var  integratedLoudness: Double {
        let loudness = Loudness(sampleRate: sampleRate)
        return (try? loudness.integratedLoudness(data: doubleData)) ?? 0
    }
    func normalizePeak(target: Double) {
        let gain = Loudness.normalizePeakScale(data: doubleData,
                                               target: target)
        self *= Float(gain)
        print("Peak Scale: \(gain) \(integratedLoudness) LUFS")
    }
    func normalizeLoudness(targetLoudness: Double) {
        let gain = Loudness.normalizeLoudnessScale(inputLoudness: integratedLoudness,
                                                   targetLoudness: targetLoudness)
        self *= Float(gain)
        print("Loudness Scale: \(gain) \(integratedLoudness) LUFS")
    }
    
    static func *= (lhs: PCMBuffer, rhs: Float) {
        var rhs = rhs
        for ci in 0 ..< lhs.channelCount {
            let data = lhs.floatChannelData![ci]
            vDSP_vsmul(data, lhs.stride,
                       &rhs,
                       data, lhs.stride, vDSP_Length(lhs.frameLength))
        }
    }
    
    func compress(targetDb: Double,
                  attack: Double = 0.02, release: Double = 0.02) {
        struct P {
            var minI, maxI: Int, scale: Float
        }
        let targetAmp = Float(Volume(db: targetDb).amp)
        
        var minI: Int?, maxDAmp: Float = 0.0, ps = [P]()
        for i in 0 ..< frameCount {
            var maxAmp: Float = 0.0
            for ci in 0 ..< channelCount {
                let amp = self[ci, i]
                maxAmp = max(maxAmp, abs(amp))
            }
            if maxAmp > targetAmp {
                if minI == nil {
                    minI = i
                }
                maxDAmp = max(maxDAmp, maxAmp - targetAmp)
            } else {
                if let nMinI = minI {
                    ps.append(P(minI: nMinI, maxI: i - 1, scale: targetAmp / (maxDAmp + targetAmp)))
                    minI = nil
                    maxDAmp = 0
                }
            }
        }
        let attackCount = Int(attack * sampleRate)
        let releaseCount = Int(release * sampleRate)
        var scales = [Float](repeating: 1, count: frameCount)
        for p in ps {
            let minI = max(0, p.minI - attackCount)
            for i in minI ..< p.minI {
                let t = Float(i - minI) / Float(attackCount)
                let scale = Float.linear(1, p.scale, t: t)
                scales[i] = min(scale, scales[i])
            }
            for i in p.minI ... p.maxI {
                scales[i] = p.scale
            }
            let maxI = min(frameCount - 1, p.maxI + releaseCount)
            if p.maxI + 1 <= maxI {
                for i in (p.maxI + 1) ... maxI {
                    let t = Float(i - p.maxI) / Float(releaseCount)
                    let scale = Float.linear(p.scale, 1, t: t)
                    scales[i] = min(scale, scales[i])
                }
            }
        }
        
        for ci in 0 ..< channelCount {
            enumerated(channelIndex: ci) { i, v in
                self[ci, i] *= scales[i]
            }
        }
    }
}

extension AVAudioUnitEffect {
    static func limiter() -> AVAudioUnitEffect {
        let cacd = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                            componentSubType: 0x666c7472,
                                            componentManufacturer: 0x12121213,
                                            componentFlags: AudioComponentFlags.sandboxSafe.rawValue,
                                            componentFlagsMask: 0)
        AUAudioUnit.registerSubclass(ClippingAudioUnit.self,
                                     as: cacd,
                                     name: "RasenClippingAudioUnit",
                                     version: 1)
        return AVAudioUnitEffect(audioComponentDescription: cacd)
    }
}
final class ClippingAudioUnit: AUAudioUnit {
    let inputBus: AUAudioUnitBus
    let outputBus: AUAudioUnitBus

    lazy private var inputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self,
                            busType: .input,
                            busses: [inputBus])
    }()
    public override var inputBusses: AUAudioUnitBusArray {
        inputBusArray
    }
    lazy private var outputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self,
                            busType: .output,
                            busses: [outputBus])
    }()
    public override var outputBusses: AUAudioUnitBusArray {
        outputBusArray
    }

    private var maxFramesToRender: UInt32 = 512
    private var pcmBuffer: AVAudioPCMBuffer?

    var clippingAmp: Float? = Float(Audio.floatClippingAmp)
    
    struct SError: Error {}

    override init(componentDescription: AudioComponentDescription,
                  options: AudioComponentInstantiationOptions = []) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100,
                                         channels: 2) else { throw SError() }
        try inputBus = AUAudioUnitBus(format: format)
        inputBus.maximumChannelCount = 8
        try outputBus = AUAudioUnitBus(format: format)

        guard let pcmBuffer
                = AVAudioPCMBuffer(pcmFormat: format,
                                   frameCapacity: maxFramesToRender) else { throw SError() }
        self.pcmBuffer = pcmBuffer

        try super.init(componentDescription: componentDescription,
                       options: options)

        self.maximumFramesToRender = maxFramesToRender
    }
    override func allocateRenderResources() throws {
        try super.allocateRenderResources()

        guard let pcmBuffer
                = AVAudioPCMBuffer(pcmFormat: inputBus.format,
                                   frameCapacity: maxFramesToRender) else { throw SError() }
        self.pcmBuffer = pcmBuffer
    }
    override func deallocateRenderResources() {
        super.deallocateRenderResources()
        self.pcmBuffer = nil
    }

    public override var canProcessInPlace: Bool { true }

    override var internalRenderBlock: AUInternalRenderBlock {
        return { [weak self] (actionFlags, timestamp, frameCount, outputBusNumber,
                              outputData, realtimeEventListHead, pullInputBlock) in
            guard let au = self else { return kAudioUnitErr_NoConnection }
            guard frameCount <= au.maximumFramesToRender else {
                return kAudioUnitErr_TooManyFramesToProcess
            }
            guard pullInputBlock != nil else {
                return kAudioUnitErr_NoConnection
            }
            
            guard let inputData = au.pcmBuffer?.mutableAudioBufferList else { return kAudioUnitErr_NoConnection }
            let inputBLP = UnsafeMutableAudioBufferListPointer(inputData)
            let byteSize = Int(min(frameCount, au.maxFramesToRender)) * MemoryLayout<Float>.size
            for i in 0 ..< inputBLP.count {
                inputBLP[i].mDataByteSize = UInt32(byteSize)
            }
            
            var pullFlags = AudioUnitRenderActionFlags(rawValue: 0)
            let err = pullInputBlock?(&pullFlags, timestamp, frameCount, 0, inputData)
            if let err = err, err != noErr { return err }

            let outputBLP = UnsafeMutableAudioBufferListPointer(outputData)
            for i in 0 ..< outputBLP.count {
                outputBLP[i].mNumberChannels = inputBLP[i].mNumberChannels
                outputBLP[i].mDataByteSize = inputBLP[i].mDataByteSize
               if outputBLP[i].mData == nil {
                  outputBLP[i].mData = inputBLP[i].mData
               }
            }
            guard !outputBLP.isEmpty else { return noErr }
            
            if let clippingAmp = au.clippingAmp {
                for i in 0 ..< outputBLP.count {
                    let inputFrames = inputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                    let outputFrames = outputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                    for i in 0 ..< Int(frameCount) {
                        outputFrames[i] = inputFrames[i]
                        if outputFrames[i].isNaN {
                            outputFrames[i] = 0
                            print("nan")
                        } else if outputFrames[i] < -clippingAmp {
                            outputFrames[i] = -clippingAmp
                        } else if outputFrames[i] > clippingAmp {
                            outputFrames[i] = clippingAmp
                        }
                    }
                }
            } else {
                for i in 0 ..< outputBLP.count {
                    let inputFrames = inputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                    let outputFrames = outputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                    for i in 0 ..< Int(frameCount) {
                        outputFrames[i] = inputFrames[i]
                    }
                }
            }
            
            return noErr
        }
    }
}
