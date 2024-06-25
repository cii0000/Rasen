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
    private var aNotes: [Note.PitResult]
    var notes: [Note.PitResult] {
        get { aNotes }
        set {
            let oldValue = aNotes
            aNotes = newValue
            guard isPlaying,
                    aNotes.count == oldValue.count ?
                        (0 ..< notes.count).contains(where: { aNotes[$0] != oldValue[$0] }) :
                        true else { return }
//            noder.rendnotes.count.range.forEach {
//                noder.rendnotes[$0].envelopeMemo.releaseSec = 0.02
//            }
            stopNote()
//            noder.rendnotes.count.range.forEach {
//                noder.rendnotes[$0].envelopeMemo.attackSec = 0.02
//            }
            playNote()
        }
    }
    func changeStereo(from notes: [Note.PitResult]) {
        self.notes = notes
        
//        self.aNotes = notes
//        if notes.count == noder.rendnotes.count {
//            noder.replaceStereo(notes.enumerated().map { .init(value: $0.element, index: $0.offset) })
//        }
    }
    var stereo: Stereo {
        get { noder.stereo }
        set { noder.stereo = newValue }
    }
    var sequencer: Sequencer
    var noder: ScoreNoder
    var noteIDs = Set<UUID>()
    
    struct NotePlayerError: Error {}
    
    init(notes: [Note.PitResult], stereo: Stereo = .init(volm: 1)) throws {
        guard let sequencer = Sequencer(audiotracks: []) else {
            throw NotePlayerError()
        }
        self.aNotes = notes
        self.sequencer = sequencer
        noder = .init(rendnotes: [], startSec: 0, durSec: 0, sampleRate: Audio.defaultSampleRate,
                      stereo: stereo)
        sequencer.append(noder, id: UUID())
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
        let rendnotes: [Rendnote] = notes.map { note in
            let noteID = UUID()
            noteIDs.insert(noteID)
            return .init(fq: Pitch.fq(fromPitch: .init(note.notePitch) + note.pitch.doubleValue),
                         noiseSeed: Rendnote.noiseSeed(from: note.id),
                         pitbend: .init(pitch: 0,
                                        stereo: note.stereo,
                                        overtone: note.tone.overtone,
                                        spectlope: note.tone.spectlope),
                         secRange: -.infinity ..< .infinity,
                         startDeltaSec: 0,
                         envelopeMemo: .init(note.envelope),
                         id: noteID)
        }
        
        noder.rendnotes += rendnotes
        noder.updateRendnotes()
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
        
        timer.start(afterTime: max(NotePlayer.stopEngineSec, 
                                   (notes.maxValue { $0.envelope.releaseSec }) ?? 0),
                    dispatchQueue: .main) {
        } waitClosure: {
        } cancelClosure: {
        } endClosure: { [weak self] in
            self?.sequencer.stopEngine()
            self?.noder.rendnotes = []
        }
    }
}

final class PCMNoder {
    fileprivate weak var sequencer: Sequencer?
    fileprivate var node: AVAudioSourceNode!
    let pcmBuffer: PCMBuffer
    
    private struct TimeOption {
        var csSampleSec: Double, cst: Int, frameLength: Int, sampleFrameLength: Double, clsSec: Double
    }
    
    var stereo: Stereo {
        get {
            .init(volm: Volm.volm(fromAmp: Double(node.volume)), pan: Double(node.pan))
        }
        set {
            let oldValue = stereo
            if newValue.volm != oldValue.volm {
                node.volume = Float(Volm.amp(fromVolm: newValue.volm))
            }
            if newValue.pan != oldValue.pan {
                node.pan = Float(newValue.pan)//
            }
        }
    }
    
    var spectrogram: Spectrogram? {
        .init(pcmBuffer)
    }
    
    private var timeOption: TimeOption
    
    private static func timeOption(from pcmBuffer: PCMBuffer,
                                   contentStartSec: Double, contentLocalStartSec: Double, 
                                   contentDurSec: Double) -> TimeOption {
        let sampleRate = pcmBuffer.format.sampleRate
        
        let csSampleSec = -min(contentLocalStartSec, 0) * sampleRate
        let cst = Int(csSampleSec)
        let frameLength = min(Int(pcmBuffer.frameLength),
                              Int((contentDurSec - min(contentLocalStartSec, 0)) * sampleRate))
        let sampleFrameLength = min(Double(pcmBuffer.frameLength),
                                    (contentDurSec - min(contentLocalStartSec, 0)) * sampleRate)
        let clsSec = contentStartSec + contentLocalStartSec
        return .init(csSampleSec: csSampleSec, cst: cst, frameLength: frameLength,
                     sampleFrameLength: sampleFrameLength, clsSec: clsSec)
    }
    
    func change(from timeOption: ContentTimeOption) {
        guard pcmBuffer.sampleRate > 0 else { return }
        let durSec = Double(pcmBuffer.frameLength) / pcmBuffer.sampleRate
        let durBeat = ContentTimeOption.beat(fromSec: durSec,
                                             tempo: timeOption.tempo,
                                             beatRate: Keyframe.defaultFrameRate,
                                             rounded: .up)
        let localBeatRange = Range(start: timeOption.localStartBeat, length: durBeat)
        
        let beatRange = timeOption.beatRange
        let sBeat = beatRange.start + max(localBeatRange.start, 0)
        let inSBeat = min(localBeatRange.start, 0)
        let eBeat = beatRange.start + min(localBeatRange.end, beatRange.length)
        let contentStartSec = Double(timeOption.sec(fromBeat: sBeat))
        let contentLocalStartSec = Double(timeOption.sec(fromBeat: inSBeat))
        let contentDurSec = Double(timeOption.sec(fromBeat: max(eBeat - sBeat, 0)))
        
        self.timeOption = Self.timeOption(from: pcmBuffer,
                                          contentStartSec: contentStartSec,
                                          contentLocalStartSec: contentLocalStartSec,
                                          contentDurSec: contentDurSec)
    }
    
    var startSec = 0.0
    var durSec = Rational(0)
    var id = UUID()
    
    convenience init?(content: Content, startSec: Double = 0) {
        guard content.type.isAudio,
                let timeOption = content.timeOption,
                let localBeatRange = content.localBeatRange,
                let pcmBuffer = content.pcmBuffer else { return nil }
        let beatRange = timeOption.beatRange
        let sBeat = beatRange.start + max(localBeatRange.start, 0)
        let inSBeat = min(localBeatRange.start, 0)
        let eBeat = beatRange.start + min(localBeatRange.end, beatRange.length)
        let contentStartSec = Double(timeOption.sec(fromBeat: sBeat))
        let contentLocalStartSec = Double(timeOption.sec(fromBeat: inSBeat))
        let contentDurSec = Double(timeOption.sec(fromBeat: max(eBeat - sBeat, 0)))
        self.init(pcmBuffer: pcmBuffer,
                  startSec: startSec,
                  durSec: timeOption.secRange.end,
                  contentStartSec: contentStartSec,
                  contentLocalStartSec: contentLocalStartSec,
                  contentDurSec: contentDurSec,
                  stereo: content.stereo,
                  id: content.id)
    }
    init(pcmBuffer: PCMBuffer, 
         startSec: Double, durSec: Rational,
         contentStartSec: Double, contentLocalStartSec: Double, contentDurSec: Double,
         stereo: Stereo, id: UUID) {
        
        let sampleRate = pcmBuffer.format.sampleRate
        
        self.timeOption = Self.timeOption(from: pcmBuffer,
                                          contentStartSec: contentStartSec,
                                          contentLocalStartSec: contentLocalStartSec,
                                          contentDurSec: contentDurSec)
        self.startSec = startSec
        self.durSec = durSec
        self.id = id
        self.pcmBuffer = pcmBuffer
        node = AVAudioSourceNode(format: pcmBuffer.format) {
            [weak self]
            isSilence, timestamp, frameCount, outputData in

            guard let self, let seq = self.sequencer else { return kAudioUnitErr_NoConnection }
            let to = self.timeOption
            
            guard seq.isPlaying else {
                isSilence.pointee = true
                return noErr
            }
            guard let data = pcmBuffer.floatChannelData else { return kAudioUnitErr_NoConnection }
            
            let frameCount = Int(frameCount)
            let outputBLP = UnsafeMutableAudioBufferListPointer(outputData)
            for i in 0 ..< outputBLP.count {
                let nFrames = outputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                for j in 0 ..< frameCount {
                    nFrames[j] = 0
                }
            }
            
            if timestamp.pointee.mFlags.contains(.hostTimeValid) {
                let sec = AVAudioTime.seconds(forHostTime: timestamp.pointee.mHostTime - seq.startHostTime) + seq.startSec
                let scst = self.startSec + to.clsSec
                let sampleSec = (sec - scst) * sampleRate
                
                guard sampleSec < to.sampleFrameLength - 1 && sampleSec + Double(frameCount) >= to.csSampleSec else {
                    isSilence.pointee = true
                    return noErr
                }
                
                for i in 0 ..< outputBLP.count {
                    let oFrames = data[i]
                    let nFrames = outputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                    for j in 0 ..< frameCount {
                        let ni = sampleSec + Double(j)
                        if ni >= to.csSampleSec && ni < to.sampleFrameLength - 1 {
                            let rni = ni.rounded(.down)
                            let nii = Int(rni)
                            nFrames[j] = .linear(oFrames[nii],
                                                 oFrames[nii + 1],
                                                 t: ni - rni)
                            
                        }
                    }
                }
            } else if timestamp.pointee.mFlags.contains(.sampleTimeValid) {
                let scst = self.startSec + to.clsSec
                let secI = Int(timestamp.pointee.mSampleTime - scst * sampleRate)
                
                guard secI < to.frameLength && secI + frameCount >= to.cst else {
                    isSilence.pointee = true
                    return noErr
                }
                
                for i in 0 ..< outputBLP.count {
                    let oFrames = data[i]
                    let nFrames = outputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                    for j in 0 ..< frameCount {
                        let ni = secI + j
                        if ni >= to.cst && ni < to.frameLength {
                            nFrames[j] = oFrames[ni]
                        }
                    }
                }
            } else {
                return kAudioUnitErr_NoConnection
            }
            
            return noErr
        }
        
        self.stereo = stereo
    }
}

final class ScoreNoder {
    fileprivate weak var sequencer: Sequencer?
    fileprivate var node: AVAudioSourceNode!
    private let format: AVAudioFormat
    private let rendnotesSemaphore = DispatchSemaphore(value: 1)
    private let notewaveDicSemaphore = DispatchSemaphore(value: 1)
    
    var stereo: Stereo {
        get {
            .init(volm: Volm.volm(fromAmp: Double(node.volume)), pan: Double(node.pan))
        }
        set {
            let oldValue = stereo
            if newValue.volm != oldValue.volm {
                node.volume = Float(Volm.amp(fromVolm: newValue.volm))
            }
            if newValue.pan != oldValue.pan {
                node.pan = Float(newValue.pan)//
            }
        }
    }
    
    var startSec = 0.0
    var durSec = Rational(0)
    let id = UUID()
    
    var rendnotes = [Rendnote]()
    
    var isEmpty: Bool {
        rendnotes.isEmpty || durSec == 0
    }
    
    func changeTempo(with score: Score) {
        replace(score.notes.enumerated().map { .init(value: $0.element, index: $0.offset) },
                with: score)
        
        durSec = score.secRange.end
    }
    
    func insert(_ noteIVs: [IndexValue<Note>], with score: Score) {
        rendnotesSemaphore.wait()
        rendnotes.insert(noteIVs.map {
            IndexValue(value: Rendnote(note: $0.value, score: score), index: $0.index)
        })
        rendnotesSemaphore.signal()
    }
    func replace(_ note: Note, at i: Int, with score: Score) {
        replace([.init(value: note, index: i)], with: score)
    }
    func replace(_ noteIVs: [IndexValue<Note>], with score: Score) {
        rendnotesSemaphore.wait()
        rendnotes.replace(noteIVs.map {
            IndexValue(value: Rendnote(note: $0.value, score: score), index: $0.index)
        })// check change stereo only
        rendnotesSemaphore.signal()
    }
    
    func replace(_ eivs: [IndexValue<Envelope>]) {
        eivs.forEach { replace($0.value, at: $0.index) }
    }
    func replace(_ envelope: Envelope, at noteI: Int) {
        let envelopeMemo = EnvelopeMemo(envelope)
        rendnotesSemaphore.wait()
        rendnotes[noteI].envelopeMemo = envelopeMemo
        rendnotesSemaphore.signal()
    }
    
    func remove(at noteIs: [Int]) {
        rendnotesSemaphore.wait()
        rendnotes.remove(at: noteIs)
        rendnotesSemaphore.signal()
    }
    
    func updateRendnotes() {
        let newNIDs = Set(rendnotes.map { NotewaveID($0) })
        let oldNIDs = Set(notewaveDic.keys)
        
        for nid in oldNIDs {
            guard !newNIDs.contains(nid) else { continue }
            notewaveDicSemaphore.wait()
            notewaveDic[nid] = nil
            notewaveDicSemaphore.signal()
        }
        
        let ors = rendnotes.reduce(into: [NotewaveID: Rendnote]()) { $0[NotewaveID($1)] = $1 }
        var newWillRenderRendnoteDic = [NotewaveID: Rendnote]()
        for nid in newNIDs {
            guard notewaveDic[nid] == nil else { continue }
            newWillRenderRendnoteDic[nid] = ors[nid]
        }
        
        let nwrrs = newWillRenderRendnoteDic.map { ($0.key, $0.value) }
        if nwrrs.count > 0 {
            let sampleRate = format.sampleRate
            if nwrrs.count == 1 {
                let notewave = nwrrs[0].1.notewave(sampleRate: sampleRate)
                
                notewaveDicSemaphore.wait()
                notewaveDic[nwrrs[0].0] = notewave
                notewaveDicSemaphore.signal()
            } else {
                let threadCount = 8
                let nThreadCount = min(nwrrs.count, threadCount)
                
                final class NotewaveBox {
                    var notewave: Notewave
                    
                    init(_ notewave: Notewave = .init(fqScale: 1, isLoop: false, samples: [], stereos: [])) {
                        self.notewave = notewave
                    }
                }
                
                var notewaveBoxs = nwrrs.count.range.map { _ in NotewaveBox() }
                let dMod = nwrrs.count % threadCount
                let dCount = nwrrs.count / threadCount
                notewaveBoxs.withUnsafeMutableBufferPointer { notewavesPtr in
                    if nThreadCount == nwrrs.count {
                        DispatchQueue.concurrentPerform(iterations: nThreadCount) { threadI in
                            notewavesPtr[threadI] = .init(nwrrs[threadI].1.notewave(sampleRate: sampleRate))
                        }
                    } else {
                        DispatchQueue.concurrentPerform(iterations: nThreadCount) { threadI in
                            for i in (threadI < dMod ? dCount + 1 : dCount).range {
                                let j = threadI < dMod ? 
                                (dCount + 1) * threadI + i :
                                (dCount + 1) * dMod + dCount * (threadI - dMod) + i
                                notewavesPtr[j] = .init(nwrrs[j].1.notewave(sampleRate: sampleRate))
                            }
                        }
                    }
                }
                for (i, notewaveBox) in notewaveBoxs.enumerated() {
                    notewaveDicSemaphore.wait()
                    notewaveDic[nwrrs[i].0] = notewaveBox.notewave
                    notewaveDicSemaphore.signal()
                }
            }
        }
        
    }
    
    func reset() {
        memowaves = [:]
        phases = [:]
    }
    
    struct NotewaveID: Hashable, Codable {
        var fq: Double, noiseSeed: UInt64, pitbend: Pitbend, rendableDurSec: Double, startDeltaSec: Double
        
        init(_ rendnote: Rendnote) {
            fq = rendnote.fq
            noiseSeed = rendnote.noiseSeed
            pitbend = rendnote.pitbend
            rendableDurSec = rendnote.rendableDurSec
            startDeltaSec = rendnote.startDeltaSec
        }
    }
    fileprivate(set) var notewaveDic = [NotewaveID: Notewave]()
    
    struct Memowave {
        var startSec: Double, releaseSec: Double?, endSec: Double?,
            envelopeMemo: EnvelopeMemo, pitbend: Pitbend
        var notewave: Notewave
        
        func contains(sec: Double) -> Bool {
            if let endSec {
                sec > startSec && sec < endSec
            } else {
                sec > startSec
            }
        }
    }
    private var memowaves = [UUID: Memowave]()
    private var phases = [UUID: Double]()
    
    convenience init(score: Score, startSec: Double = 0, sampleRate: Double,
                     stereo: Stereo = .init(volm: 1)) {
        self.init(rendnotes: score.notes.map { Rendnote(note: $0, score: score) },
                  startSec: startSec, durSec: score.secRange.end, sampleRate: sampleRate,
                  stereo: stereo)
    }
    init(rendnotes: [Rendnote], startSec: Double, durSec: Rational, sampleRate: Double,
         stereo: Stereo = .init(volm: 1)) {
        
        self.rendnotes = rendnotes
        self.startSec = startSec
        self.durSec = durSec
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        
        let sampleRate = format.sampleRate
        let rSampleRate = 1 / sampleRate
        node = AVAudioSourceNode(format: format) { [weak self]
            isSilence, timestamp, frameCount, outputData in
            
            guard let self, let seq = self.sequencer else { return kAudioUnitErr_NoConnection }
            let startSec = self.startSec
            
            guard seq.isPlaying else {
                isSilence.pointee = true
                return noErr
            }
            
            let frameCount = Int(frameCount)
            let outputBLP = UnsafeMutableAudioBufferListPointer(outputData)
            for i in 0 ..< outputBLP.count {
                let nFrames = outputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                for j in 0 ..< frameCount {
                    nFrames[j] = 0
                }
            }
            
            let sec: Double
            if timestamp.pointee.mFlags.contains(.hostTimeValid) {
                let dHostTime = timestamp.pointee.mHostTime > seq.startHostTime ?
                    timestamp.pointee.mHostTime - seq.startHostTime : 0
                sec = AVAudioTime.seconds(forHostTime: dHostTime) + seq.startSec
            } else if timestamp.pointee.mFlags.contains(.sampleTimeValid) {
                sec = timestamp.pointee.mSampleTime * rSampleRate
            } else {
                return kAudioUnitErr_NoConnection
            }
            
            self.rendnotesSemaphore.wait()
            let rendnotes = self.rendnotes
            self.rendnotesSemaphore.signal()
            
            for rendnote in rendnotes {
                let noteStartSec = rendnote.secRange.start.isInfinite ?
                sec : rendnote.secRange.start + startSec
                let secI = Int((sec - noteStartSec) * sampleRate)
                if rendnote.secRange.end.isInfinite {
                    if secI + frameCount >= 0 && self.memowaves[rendnote.id] == nil {
                        let nwid = NotewaveID(rendnote)
                        
                        self.notewaveDicSemaphore.wait()
                        let notewave = self.notewaveDic[nwid]
                        self.notewaveDicSemaphore.signal()
                        
                        if let notewave {
                            self.memowaves[rendnote.id]
                                = Memowave(startSec: noteStartSec,
                                           releaseSec: nil,
                                           endSec: nil,
                                           envelopeMemo: rendnote.envelopeMemo,
                                           pitbend: rendnote.pitbend,
                                           notewave: notewave)
                            self.phases[rendnote.id] = .init(secI.mod(notewave.samples.count))
                        }
                    }
                } else {
                    let length = rendnote.secRange.end + startSec - noteStartSec
                    let durSec = rendnote.envelopeMemo.duration(fromDurSec: length)
                    let frameLength = Int(durSec * sampleRate)
                    if sec >= noteStartSec
                        && noteStartSec < rendnote.secRange.end + startSec
                        && secI < frameLength && secI + frameCount >= 0
                        && self.memowaves[rendnote.id] == nil {
                        
                        let nwid = NotewaveID(rendnote)
                        
                        self.notewaveDicSemaphore.wait()
                        let notewave = self.notewaveDic[nwid]
                        self.notewaveDicSemaphore.signal()
                        
                        if let notewave {
                            self.memowaves[rendnote.id]
                                = Memowave(startSec: noteStartSec,
                                           releaseSec: noteStartSec + length,
                                           endSec: noteStartSec + durSec,
                                           envelopeMemo: rendnote.envelopeMemo,
                                           pitbend: rendnote.pitbend,
                                           notewave: notewave)
                            self.phases[rendnote.id] = .init(secI.mod(notewave.samples.count))
                        }
                    } else if let memowave = self.memowaves[rendnote.id], !rendnote.secRange.end.isInfinite,
                              memowave.endSec == nil {
                        
                        self.memowaves[rendnote.id]?.releaseSec = noteStartSec + length
                        self.memowaves[rendnote.id]?.endSec = noteStartSec + durSec
                    }
                }
            }
            
            for (id, memowave) in self.memowaves {
                if let endSec = memowave.endSec, sec < memowave.startSec || sec >= endSec {
                    self.memowaves[id] = nil
                    self.phases[id] = nil
                }
            }
            
            guard !self.memowaves.isEmpty else {
                isSilence.pointee = true
                return noErr
            }
            
            let framess = outputBLP.count.range.map {
                outputBLP[$0].mData!.assumingMemoryBound(to: Float.self)
            }
            
            let memowaves = self.memowaves
            var phases = self.phases
            for (id, memowave) in memowaves {
                var phase = phases[id]!
                let notewave = memowave.notewave, pitbend = memowave.pitbend
                guard notewave.samples.count >= 4 else { continue }
                let count = Double(notewave.samples.count)
                if !notewave.isLoop && phase >= count { continue }
                phase = phase.loop(0 ..< count)
                
                for i in 0 ..< Int(frameCount) {
                    let nSec = Double(i) * rSampleRate + sec
                    guard nSec >= memowave.startSec else { continue }
                    let envelopeVolm = memowave.envelopeMemo
                        .volm(atSec: nSec - memowave.startSec,
                              releaseStartSec: memowave.releaseSec != nil ? memowave.releaseSec! - memowave.startSec : nil)
                    
                    let amp, pan: Double
                    if pitbend.isEqualAllStereo {
                        amp = Volm.amp(fromVolm: pitbend.firstStereo.volm * envelopeVolm)
                        pan = pitbend.firstStereo.pan
                    } else {
                        let stereo = notewave.stereo(at: i, atPhase: &phase)
                        amp = Volm.amp(fromVolm: stereo.volm * envelopeVolm)
                        pan = stereo.pan
                    }
                    
                    let sample = notewave.sample(at: i, amp: amp, atPhase: &phase)
                    
                    if pan == 0 || framess.count < 2 {
                        let fSample = Float(sample)
                        for frames in framess {
                            frames[i] += fSample
                        }
                    } else {
                        let nPan = pan.clipped(min: -1, max: 1) * 0.75
                        if nPan < 0 {
                            framess[0][i] += Float(sample)
                            framess[1][i] += Float(sample * Volm.amp(fromVolm: 1 + nPan))
                        } else {
                            framess[0][i] += Float(sample * Volm.amp(fromVolm: 1 - nPan))
                            framess[1][i] += Float(sample)
                        }
                    }
                }
                
                phases[id] = phase
            }
            self.phases = phases
            
            return noErr
        }
        
        self.stereo = stereo
        
        updateRendnotes()
    }
}

final class Sequencer {
    private(set) var scoreNoders: [UUID: ScoreNoder]
    private(set) var pcmNoders: [UUID: PCMNoder]
    private var allMainNodes: [AVAudioNode]
    private let mixerNode: AVAudioMixerNode
    private let limiterNode: AVAudioUnitEffect
    let engine: AVAudioEngine
    
    fileprivate var startSec = 0.0, startHostTime: UInt64 = 0
    var isPlaying = false
    
    let durSec: Double
    
    struct Track {
        var scoreNoders = [ScoreNoder]()
        var pcmNoders = [PCMNoder]()
        
        var durSec: Rational {
            max(scoreNoders.maxValue { $0.durSec } ?? 0, pcmNoders.maxValue { $0.durSec } ?? 0)
        }
        static func + (lhs: Self, rhs: Self) -> Self {
            .init(scoreNoders: lhs.scoreNoders + rhs.scoreNoders,
                  pcmNoders: lhs.pcmNoders + rhs.pcmNoders)
        }
        static func += (lhs: inout Self, rhs: Self) {
            lhs.scoreNoders += rhs.scoreNoders
            lhs.pcmNoders += rhs.pcmNoders
        }
        static func += (lhs: inout Self?, rhs: Self) {
            if lhs == nil {
                lhs = rhs
            } else {
                lhs?.scoreNoders += rhs.scoreNoders
                lhs?.pcmNoders += rhs.pcmNoders
            }
        }
        var isEmpty: Bool {
            durSec == 0 || (scoreNoders.allSatisfy { $0.isEmpty } && pcmNoders.isEmpty)
        }
    }
    
    convenience init?(audiotracks: [Audiotrack], clipHandler: ((Float) -> ())? = nil,
                      sampleRate: Double = Audio.defaultSampleRate) {
        let audiotracks = audiotracks.filter { !$0.isEmpty }
        
        var tracks = [Track]()
        for audiotrack in audiotracks {
            let durSec = audiotrack.durSec
            guard durSec > 0 else { continue }
            
            var track = Track()
            for value in audiotrack.values {
                guard value.beatRange.length > 0 && value.beatRange.end > 0 else { continue }
                switch value {
                case .score(let score):
                    track.scoreNoders.append(.init(score: score, sampleRate: sampleRate))
                case .sound(let content):
                    guard let noder = PCMNoder(content: content) else { continue }
                    track.pcmNoders.append(noder)
                }
            }
            tracks.append(track)
        }
        
        self.init(tracks: tracks, clipHandler: clipHandler)
    }
    
    init?(tracks: [Track], clipHandler: ((Float) -> ())? = nil) {
        let engine = AVAudioEngine()
        
        let mixerNode = AVAudioMixerNode()
        engine.attach(mixerNode)
        self.mixerNode = mixerNode
        
        var scoreNoders = [UUID: ScoreNoder](), pcmNoders = [UUID: PCMNoder]()
        var allMainNodes = [AVAudioNode]()
        var sSec = 0.0
        for track in tracks {
            let durSec = track.durSec
            guard durSec > 0 else { continue }
            for noder in track.scoreNoders {
                noder.startSec = sSec
                noder.reset()
                noder.updateRendnotes()
                
                scoreNoders[noder.id] = noder
                allMainNodes.append(noder.node)
                
                engine.attach(noder.node)
                engine.connect(noder.node, to: mixerNode,
                               format: noder.node.outputFormat(forBus: 0))
            }
            for noder in track.pcmNoders {
                noder.startSec = sSec
                
                pcmNoders[noder.id] = noder
                allMainNodes.append(noder.node)
                
                engine.attach(noder.node)
                engine.connect(noder.node, to: mixerNode,
                               format: noder.node.outputFormat(forBus: 0))
            }
            
            sSec += Double(durSec)
        }
        durSec = sSec
        self.scoreNoders = scoreNoders
        self.pcmNoders = pcmNoders
        
        if let clipHandler {
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
        
        self.engine = engine
        self.allMainNodes = allMainNodes
        
        scoreNoders.forEach { $0.value.sequencer = self }
        pcmNoders.forEach { $0.value.sequencer = self }
    }
}
extension Sequencer {
    func append(_ noder: ScoreNoder, id: UUID) {
        scoreNoders[id] = noder
        allMainNodes.append(noder.node)
        
        engine.attach(noder.node)
        engine.connect(noder.node, to: mixerNode,
                       format: noder.node.outputFormat(forBus: 0))
        
        noder.sequencer = self
    }
    func remove(_ noder: ScoreNoder) {
        engine.disconnectNodeOutput(noder.node)
        engine.detach(noder.node)
    }
    
    var currentPositionInSec: Double {
        get {
            isPlaying ?
                AVAudioTime.seconds(forHostTime: AudioGetCurrentHostTime() - startHostTime) + startSec :
                startSec
        }
        set {
            startHostTime = AudioGetCurrentHostTime()
            startSec = newValue
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
        scoreNoders.forEach { $0.value.reset() }
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
               headroomAmp: Float? = Audio.floatHeadroomAmp,
               progressHandler: (Double, inout Bool) -> ()) throws -> Audio? {
        guard let buffer = try buffer(sampleRate: sampleRate,
                                      headroomAmp: headroomAmp,
                                      progressHandler: progressHandler) else { return nil }
        return Audio(pcmData: buffer.pcmData)
    }
    func buffer(sampleRate: Double,
                headroomAmp: Float? = Audio.floatHeadroomAmp,
                progressHandler: (Double, inout Bool) -> ()) throws -> AVAudioPCMBuffer? {
        let oldHeadroomAmp = clippingAudioUnit.headroomAmp
        clippingAudioUnit.headroomAmp = headroomAmp
        defer { clippingAudioUnit.headroomAmp = oldHeadroomAmp }
        
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
        
        let length = AVAudioFramePosition(durSec * sampleRate)
        
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
                    if let ca = headroomAmp {
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
                                           headroomAmp: nil,
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
        let length = AVAudioFramePosition(durSec * sampleRate)
        while engine.manualRenderingSampleTime < length {
            do {
                let mrst = engine.manualRenderingSampleTime
                let frameCount = length - mrst
                let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
                let status = try engine.renderOffline(framesToRender, to: buffer)
                switch status {
                case .success:
                    buffer.clip(amp: Float(Audio.floatHeadroomAmp))
                    
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

typealias PCMBuffer = AVAudioPCMBuffer
extension AVAudioPCMBuffer {
    struct AVAudioPCMBufferError: Error {}
    
    static var pcmFormat: AVAudioFormat? {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: Audio.defaultSampleRate, channels: 1, interleaved: true)
    }
    static var exportPcmFormat: AVAudioFormat? {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: Audio.defaultSampleRate, channels: 2, interleaved: true)
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
    
    func convertDefaultFormat(isExportFormat: Bool = false) throws -> AVAudioPCMBuffer {
        guard let pcmFormat = isExportFormat ? AVAudioPCMBuffer.exportPcmFormat : AVAudioPCMBuffer.pcmFormat,
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
    
    func channelAmpsFromFloat(at ci: Int) -> [Double] {
        frameCount.range.map { Double(self[ci, $0]) }
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
        return Volm.db(fromAmp: peak)
    }
    var  integratedLoudness: Double {
        let loudness = Loudness(sampleRate: sampleRate)
        return (try? loudness.integratedLoudnessDb(data: doubleData)) ?? 0
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
        let targetAmp = Float(Volm.amp(fromDb: targetDb))
        
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
    
    static let volmFrameRate = Rational(Keyframe.defaultFrameRate)
    func volms(fromFrameRate frameRate: Rational = volmFrameRate) -> [Double] {
        let volmFrameCount = Int(sampleRate / Double(frameRate))
        let count = frameCount / volmFrameCount
        var volms = [Double](capacity: count)
        let hvfc = volmFrameCount / 2, frameCount = frameCount
        for i in Swift.stride(from: 0, to: frameCount, by: volmFrameCount) {
            var x: Float = 0.0
            for j in (i - hvfc) ..< (i + hvfc) {
                if j >= 0 && j < frameCount {
                    for ci in 0 ..< channelCount {
                        x = max(x, abs(self[ci, j]))
                    }
                }
            }
            volms.append(Volm.volm(fromAmp: Double(x)).clipped(min: 0, max: 1))
        }
        return volms
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

    var headroomAmp: Float? = Float(Audio.floatHeadroomAmp)
    
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
            
            if let headroomAmp = au.headroomAmp {
                for i in 0 ..< outputBLP.count {
                    let inputFrames = inputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                    let outputFrames = outputBLP[i].mData!.assumingMemoryBound(to: Float.self)
                    for i in 0 ..< Int(frameCount) {
                        outputFrames[i] = inputFrames[i]
                        if outputFrames[i].isNaN {
                            outputFrames[i] = 0
                            print("nan")
                        } else if outputFrames[i] < -headroomAmp {
                            outputFrames[i] = -headroomAmp
                        } else if outputFrames[i] > headroomAmp {
                            outputFrames[i] = headroomAmp
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
