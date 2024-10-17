// Copyright 2024 Cii
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

//#if os(macOS) && os(iOS) && os(watchOS) && os(tvOS) && os(visionOS)
import Accelerate.vecLib.vDSP
import AVFAudio
//#elseif os(linux) && os(windows)
//#endif

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
    var sequencer: Sequencer
    var noder: ScoreNoder
    var noteIDs = Set<UUID>()
    
    struct NotePlayerError: Error {}
    
    init(notes: [Note.PitResult]) throws {
        guard let sequencer = Sequencer(audiotracks: [], type: .note) else {
            throw NotePlayerError()
        }
        self.aNotes = notes
        self.sequencer = sequencer
        noder = .init(rendnotes: [], startSec: 0, durSec: 0, sampleRate: Audio.defaultSampleRate,
                      type: .note)
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
            sequencer.play()
        }
        playNote()
        
        isPlaying = true
    }
    private func playNote() {
        noteIDs = []
        let rendnotes: [Rendnote] = notes.map { note in
            let noteID = UUID()
            noteIDs.insert(noteID)
            let (seed0, seed1) = note.id.uInt64Values
            return .init(fq: Pitch.fq(fromPitch: .init(note.notePitch) + note.pitch.doubleValue),
                         noiseSeed0: seed0, noiseSeed1: seed1,
                         pitbend: .init(pitch: 0,
                                        stereo: note.stereo,
                                        overtone: note.tone.overtone,
                                        spectlope: note.tone.spectlope),
                         secRange: -.infinity ..< .infinity,
                         envelopeMemo: .init(note.envelope),
                         id: noteID)
        }
        
        noder.rendnotes += rendnotes
        noder.updateRendnotes()
    }
    private func stopNote() {
        for (i, rendnote) in noder.rendnotes.enumerated() {
            if noteIDs.contains(rendnote.id) {
                noder.rendnotes[i].isRelease = true
            }
        }
        noteIDs = []
    }
    
    static let stopEngineSec = 10.0
    private var timer = OneshotTimer()
    func stop() {
        stopNote()
        
        isPlaying = false
        
        timer.start(afterTime: max(NotePlayer.stopEngineSec, 
                                   (notes.maxValue { $0.envelope.releaseSec + $0.envelope.reverb.durSec }) ?? 0),
                    dispatchQueue: .main) {
        } waitClosure: {
        } cancelClosure: {
        } endClosure: { [weak self] in
            self?.sequencer.stopEngine()
            self?.noder.rendnotes = []
            self?.noder.updateRendnotes()
            self?.noder.reset()
        }
    }
}

final class PCMNoder {
    fileprivate weak var sequencer: Sequencer?
    fileprivate var node: AVAudioSourceNode!
    let pcmBuffer: PCMBuffer
    
    private struct TimeOption {
        var contentLocalStartI: Int, contentCount: Int, contentStartSec: Double
        
        init(pcmBuffer: PCMBuffer,
             contentStartSec: Rational, contentLocalStartSec: Rational, contentDurSec: Rational,
             lengthSec: Rational) {
            self.init(pcmBuffer: pcmBuffer,
                      contentStartSec: .init(contentStartSec),
                      contentLocalStartSec: .init(contentLocalStartSec),
                      contentDurSec: .init(contentDurSec),
                      lengthSec: .init(lengthSec))
        }
        init(pcmBuffer: PCMBuffer,
             contentStartSec: Double, contentLocalStartSec: Double, contentDurSec: Double, lengthSec: Double) {
            
            let sampleRate = pcmBuffer.format.sampleRate
            let frameCount = pcmBuffer.frameCount
            let clsI = Int(contentLocalStartSec * sampleRate)
            contentLocalStartI = min(-min(clsI, 0), frameCount)
            self.contentCount = Int(lengthSec * sampleRate)
            self.contentStartSec = contentStartSec + max(contentLocalStartSec, 0)
        }
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
    
    func spectrogram(fromSecRange secRange: Range<Double>? = nil) -> Spectrogram? {
        .init(pcmBuffer, secRange: secRange)
    }
    
    private var timeOption: TimeOption
    
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
        let contentStartSec = timeOption.sec(fromBeat: sBeat)
        let contentLocalStartSec = timeOption.sec(fromBeat: inSBeat)
        let contentDurSec = timeOption.sec(fromBeat: max(eBeat - sBeat, 0))
        let lengthBeat = min(durBeat + min(timeOption.localStartBeat, 0),
                             timeOption.beatRange.length - max(timeOption.localStartBeat, 0))
        let lengthSec = timeOption.sec(fromBeat: lengthBeat)
        self.timeOption = .init(pcmBuffer: pcmBuffer,
                                contentStartSec: contentStartSec,
                                contentLocalStartSec: contentLocalStartSec,
                                contentDurSec: contentDurSec,
                                lengthSec: lengthSec)
        self.durSec = timeOption.secRange.end
    }
    
    var startSec = 0.0
    var durSec = Rational(0)
    var id = UUID()
    
    convenience init?(content: Content, startSec: Double = 0) {
        guard content.type.isAudio,
              let timeOption = content.timeOption,
              let localBeatRange = content.localBeatRange,
              let pcmBuffer = content.pcmBuffer,
              let durBeat = content.durBeat else { return nil }
        let beatRange = timeOption.beatRange
        let sBeat = beatRange.start + max(localBeatRange.start, 0)
        let inSBeat = min(localBeatRange.start, 0)
        let eBeat = beatRange.start + min(localBeatRange.end, beatRange.length)
        let contentStartSec = timeOption.sec(fromBeat: sBeat)
        let contentLocalStartSec = timeOption.sec(fromBeat: inSBeat)
        let contentDurSec = timeOption.sec(fromBeat: max(eBeat - sBeat, 0))
        let lengthBeat = min(durBeat + min(timeOption.localStartBeat, 0),
                             timeOption.beatRange.length - max(timeOption.localStartBeat, 0))
        let lengthSec = timeOption.sec(fromBeat: lengthBeat)
        self.init(pcmBuffer: pcmBuffer,
                  startSec: startSec,
                  durSec: timeOption.secRange.end,
                  contentStartSec: contentStartSec,
                  contentLocalStartSec: contentLocalStartSec,
                  contentDurSec: contentDurSec,
                  lengthSec: lengthSec,
                  stereo: content.stereo,
                  id: content.id)
    }
    init(pcmBuffer: PCMBuffer, 
         startSec: Double, durSec: Rational,
         contentStartSec: Rational, contentLocalStartSec: Rational, contentDurSec: Rational, lengthSec: Rational,
         stereo: Stereo, id: UUID) {
        
        let sampleRate = pcmBuffer.format.sampleRate
        
        timeOption = .init(pcmBuffer: pcmBuffer,
                           contentStartSec: contentStartSec,
                           contentLocalStartSec: contentLocalStartSec,
                           contentDurSec: contentDurSec,
                           lengthSec: lengthSec)
        self.startSec = startSec
        self.durSec = durSec
        self.id = id
        self.pcmBuffer = pcmBuffer
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        node = .init(format: format) { [weak self]
            isSilence, timestamp, frameCount, outputData in
            
            guard let self, let seq = self.sequencer else { return kAudioUnitErr_NoConnection }
            
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
            
            guard timestamp.pointee.mFlags.contains(.sampleHostTimeValid)
                    || timestamp.pointee.mFlags.contains(.sampleTimeValid),
                  let data = pcmBuffer.floatChannelData else { return kAudioUnitErr_NoConnection }
            
            let frameStartI = Int(seq.startSec * sampleRate)
            let maxCount = Int(max(1, (seq.durSec * sampleRate).rounded(.up)))
            let loopedFrameStartI = (Int(timestamp.pointee.mSampleTime) + frameStartI) % maxCount
            let loopedFrameRange = loopedFrameStartI ..< loopedFrameStartI + frameCount
            let preLoopedFrameRange = loopedFrameRange - maxCount
            
            let timeOption = self.timeOption
            let contentStartSec = self.startSec + timeOption.contentStartSec
            let contentStartI = Int(contentStartSec * sampleRate)
            let contentRange = contentStartI ..< contentStartI + timeOption.contentCount
            guard loopedFrameRange.intersects(contentRange)
                    || preLoopedFrameRange.intersects(contentRange) else {
                isSilence.pointee = true
                return noErr
            }
            
            for ci in 0 ..< min(outputBLP.count, pcmBuffer.channelCount) {
                let oFrames = data[ci], nFrames = outputBLP[ci].mData!.assumingMemoryBound(to: Float.self)
                var i = loopedFrameStartI
                for ni in 0 ..< frameCount {
                    if contentRange.contains(i) {
                        let oi = i - contentRange.start + timeOption.contentLocalStartI
                        nFrames[ni] = oFrames[oi * pcmBuffer.stride]
                    }
                    
                    i += 1
                    if i >= maxCount {
                        i -= maxCount
                    }
                }
            }
            
            return noErr
        }
        
        self.stereo = stereo
    }
}

private final class NotewaveBox {
    var notewave: Notewave
    
    init(_ notewave: Notewave = .init()) {
        self.notewave = notewave
    }
}
extension UnsafeMutableBufferPointer: @unchecked @retroactive Sendable where Element: NotewaveBox {}

final class ScoreNoder {
    fileprivate weak var sequencer: Sequencer?
    fileprivate var node: AVAudioSourceNode!
    private let format: AVAudioFormat
    private let rendnotesSemaphore = DispatchSemaphore(value: 1)
    private let notewaveDicSemaphore = DispatchSemaphore(value: 1)
    
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
                
                var notewaveBoxs = nwrrs.count.range.map { _ in NotewaveBox() }
                let dMod = nwrrs.count % threadCount
                let dCount = nwrrs.count / threadCount
                notewaveBoxs.withUnsafeMutableBufferPointer { aNotewavesPtr in
                    let notewavesPtr = aNotewavesPtr, nwrrs = nwrrs
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
        loopMemos = [:]
    }
    
    struct NotewaveID: Hashable {
        var fq: Double, noiseSeed0: UInt64, noiseSeed1: UInt64,
            envelopeMemo: EnvelopeMemo, pitbend: Pitbend,
            rendableDurSec: Double
        
        init(_ rendnote: Rendnote) {
            fq = rendnote.fq
            noiseSeed0 = rendnote.noiseSeed0
            noiseSeed1 = rendnote.noiseSeed1
            envelopeMemo = rendnote.envelopeMemo
            pitbend = rendnote.pitbend
            rendableDurSec = rendnote.rendableDurSec
        }
    }
    fileprivate(set) var notewaveDic = [NotewaveID: Notewave]()
    
    private var loopMemos = [UUID: (startI: Int, releaseI: Int?)]()
    
    enum RenderType {
        case normal, loop, note
    }
    
    convenience init(score: Score, startSec: Double = 0, sampleRate: Double,
                     type: RenderType) {
        self.init(rendnotes: score.notes.map { .init(note: $0, score: score) },
                  startSec: startSec, durSec: score.secRange.end, sampleRate: sampleRate, type: type)
    }
    init(rendnotes: [Rendnote], startSec: Double, durSec: Rational, sampleRate: Double,
         type: RenderType) {
        self.rendnotes = rendnotes
        self.startSec = startSec
        self.durSec = durSec
        format = .init(standardFormatWithSampleRate: sampleRate, channels: 2)!
        
        let sampleRate = format.sampleRate
        let rSampleRate = 1 / sampleRate
        node = .init(format: format) { [weak self]
            isSilence, timestamp, frameCount, outputData in
            
            guard let self, let seq = self.sequencer else { return kAudioUnitErr_NoConnection }
            
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
            
            guard timestamp.pointee.mFlags.contains(.sampleHostTimeValid)
                    || timestamp.pointee.mFlags.contains(.sampleTimeValid) else { return kAudioUnitErr_NoConnection }
            
            self.rendnotesSemaphore.wait()
            let rendnotes = self.rendnotes
            self.rendnotesSemaphore.signal()
            
            let nFramess = outputBLP.count.range.map {
                outputBLP[$0].mData!.assumingMemoryBound(to: Float.self)
            }
            
            func updateF(i: Int, mi: Int, ni: Int, samples: [[Double]], stereos: [Stereo],
                         isPremultipliedEnvelope: Bool,
                         allAttackStartSec: Double?, allReleaseStartSec: Double?,
                         envelopeMemo: EnvelopeMemo, startSec: Double, releaseSec: Double?) {
                let sec = Double(i) * rSampleRate
                let waveclipAmp = isPremultipliedEnvelope ?
                1 : Waveclip.amp(atSec: sec, attackStartSec: startSec, releaseStartSec: releaseSec)
                
                let allWaveclipAmp = Waveclip
                    .amp(atSec: sec, attackStartSec: allAttackStartSec, releaseStartSec: allReleaseStartSec)
                
                let envelopeVolm = isPremultipliedEnvelope ?
                1 :
                envelopeMemo.volm(atSec: sec - startSec,
                                  releaseStartSec: releaseSec != nil ? releaseSec! - startSec : nil)
                
                let stereo = stereos.count == 1 ? stereos[0] : stereos[mi]
                let amp = Volm.amp(fromVolm: stereo.volm * envelopeVolm) * waveclipAmp * allWaveclipAmp
                let pan = stereo.pan
                
                if pan == 0 || nFramess.count < 2 {
                    if nFramess.count >= 2 && samples.count >= 2 {
                        nFramess[0][ni] += Float(samples[0][mi] * amp)
                        nFramess[1][ni] += Float(samples[1][mi] * amp)
                    } else {
                        let sample = Float(samples[0][mi] * amp)
                        for frames in nFramess {
                            frames[ni] += sample
                        }
                    }
                } else {
                    let nPan = pan.clipped(min: -1, max: 1) * 0.75
                    if samples.count >= 2 {
                        let sample0 = samples[0][mi] * amp
                        let sample1 = samples[1][mi] * amp
                        if nPan < 0 {
                            nFramess[0][ni] += Float(sample0)
                            nFramess[1][ni] += Float(sample1 * Volm.amp(fromVolm: 1 + nPan))
                        } else {
                            nFramess[0][ni] += Float(sample0 * Volm.amp(fromVolm: 1 - nPan))
                            nFramess[1][ni] += Float(sample1)
                        }
                    } else {
                        let sample = samples[0][mi] * amp
                        if nPan < 0 {
                            nFramess[0][ni] += Float(sample)
                            nFramess[1][ni] += Float(sample * Volm.amp(fromVolm: 1 + nPan))
                        } else {
                            nFramess[0][ni] += Float(sample * Volm.amp(fromVolm: 1 - nPan))
                            nFramess[1][ni] += Float(sample)
                        }
                    }
                }
            }
            
            let startSec = self.startSec
            let frameStartI = Int(seq.startSec * sampleRate)
            let unloopedFrameStartI = Int(timestamp.pointee.mSampleTime) + frameStartI
            var contains = false
            if type == .note {
                for rendnote in rendnotes {
                    let ei: Int?
                    if rendnote.isRelease {
                        guard loopMemos[rendnote.id] != nil else { continue }
                        if let oei = loopMemos[rendnote.id]?.releaseI {
                            ei = oei
                        } else {
                            loopMemos[rendnote.id]?.releaseI = unloopedFrameStartI
                            ei = unloopedFrameStartI
                        }
                        let releaseCount = rendnote.releaseCount(sampleRate: sampleRate)
                        if unloopedFrameStartI >= ei! + releaseCount {
                            loopMemos[rendnote.id] = nil
                            continue
                        }
                    } else {
                        ei = nil
                    }
                    
                    contains = true
                    let nwid = NotewaveID(rendnote)
                    
                    self.notewaveDicSemaphore.wait()
                    let notewave = self.notewaveDic[nwid]
                    self.notewaveDicSemaphore.signal()
                    
                    guard let notewave else { continue }
                    
                    var si: Int
                    if let i = loopMemos[rendnote.id]?.startI {
                        si = i
                    } else {
                        loopMemos[rendnote.id] = (unloopedFrameStartI, ei)
                        si = unloopedFrameStartI
                    }
                    
                    let nStartSec = startSec + .init(si) * rSampleRate
                    let releaseSec = ei != nil ? startSec + .init(ei!) * rSampleRate : nil
                    var mi = (unloopedFrameStartI - si) % notewave.sampleCount
                    for ni in 0 ..< Int(frameCount) {
                        updateF(i: ni + unloopedFrameStartI, mi: mi, ni: ni,
                                samples: notewave.samples, stereos: notewave.stereos,
                                isPremultipliedEnvelope: notewave.isPremultipliedEnvelope,
                                allAttackStartSec: nil, allReleaseStartSec: nil,
                                envelopeMemo: rendnote.envelopeMemo,
                                startSec: nStartSec, releaseSec: releaseSec)
                        mi += 1
                        if mi >= notewave.sampleCount {
                            mi -= notewave.sampleCount
                        }
                    }
                    //fir
                }
            } else {
                let seqDurSec = seq.durSec
                let maxCount = Int(max(1, (seqDurSec * sampleRate).rounded(.up)))
                let loopedFrameStartI = type == .loop ?
                unloopedFrameStartI % maxCount : unloopedFrameStartI
                let loopedFrameRange = loopedFrameStartI ..< loopedFrameStartI + frameCount
                let preLoopedFrameRange = loopedFrameRange - maxCount
                let isLooped = type == .loop && unloopedFrameStartI >= maxCount
                
                for rendnote in rendnotes {
                    let range = rendnote.releasedRange(sampleRate: sampleRate, startSec: startSec)
                    let preRange = range - maxCount
                    let cRange = range.clamped(to: 0 ..< maxCount)
                    let cPreRange = preRange.clamped(to: 0 ..< maxCount)
                    
                    guard loopedFrameRange.intersects(cRange)
                            || (type == .loop && preLoopedFrameRange.intersects(cRange))
                            || (isLooped && loopedFrameRange.intersects(cPreRange))
                            || (isLooped && preLoopedFrameRange.intersects(cPreRange)) else { continue }
                    contains = true
                    
                    let nwid = NotewaveID(rendnote)
                    
                    self.notewaveDicSemaphore.wait()
                    let notewave = self.notewaveDic[nwid]
                    self.notewaveDicSemaphore.signal()
                    
                    let isFirstCross = range.lowerBound < 0
                    let isLastCross = range.upperBound > maxCount
                    let allAttackStartSec = type != .note && isFirstCross ? 0.0 : nil
                    let allReleaseStartSec = type == .normal && isLastCross ? seqDurSec - Waveclip.releaseSec : nil
                    
                    guard let notewave else { continue }
                    let sampleCount = notewave.sampleCount
                    func update(notewave: Notewave,
                                envelopeMemo: EnvelopeMemo, startSec: Double, releaseSec: Double?,
                                range: Range<Int>, startI: Int) {
                        var i = loopedFrameStartI
                        for ni in 0 ..< Int(frameCount) {
                            if range.contains(i) {
                                let mi = i - startI
                                if mi < sampleCount {
                                    updateF(i: i, mi: mi, ni: ni,
                                            samples: notewave.samples, stereos: notewave.stereos,
                                            isPremultipliedEnvelope: notewave.isPremultipliedEnvelope,
                                            allAttackStartSec: allAttackStartSec,
                                            allReleaseStartSec: allReleaseStartSec,
                                            envelopeMemo: envelopeMemo,
                                            startSec: startSec, releaseSec: releaseSec)
                                }
                            }
                            i += 1
                            if i >= maxCount {
                                i -= maxCount
                            }
                        }
                    }
                    
                    if cRange.intersects(loopedFrameRange)
                        || cRange.intersects(preLoopedFrameRange) {
                        update(notewave: notewave,
                               envelopeMemo: rendnote.envelopeMemo,
                               startSec: startSec + rendnote.secRange.start,
                               releaseSec: startSec + rendnote.secRange.end,
                               range: cRange, startI: range.start)
                    }
                    if type == .loop,
                       cPreRange.intersects(loopedFrameRange)
                        || cPreRange.intersects(preLoopedFrameRange) {
                        update(notewave: notewave,
                               envelopeMemo: rendnote.envelopeMemo,
                               startSec: startSec + rendnote.secRange.start - seq.durSec,
                               releaseSec: startSec + rendnote.secRange.end - seq.durSec,
                               range: cPreRange, startI: preRange.start)
                    }
                }
            }
            
            if !contains {
                isSilence.pointee = true
            }
            
            return noErr
        }
        
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
    
    convenience init?(audiotracks: [Audiotrack], clipHandler: (@Sendable (Float) -> ())? = nil,
                      type: ScoreNoder.RenderType,
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
                    track.scoreNoders.append(.init(score: score, sampleRate: sampleRate, type: type))
                case .sound(let content):
                    guard let noder = PCMNoder(content: content) else { continue }
                    track.pcmNoders.append(noder)
                }
            }
            tracks.append(track)
        }
        
        self.init(tracks: tracks, clipHandler: clipHandler)
    }
    
    init?(tracks: [Track], clipHandler: (@Sendable (Float) -> ())? = nil) {
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
    
    var engineSec: Double {
        AVAudioTime.seconds(forHostTime: AudioGetCurrentHostTime() - startHostTime)
    }
    var currentPositionInSec: Double {
        get {
            isPlaying ? engineSec + startSec : startSec
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
    
    func export(url: URL,
                sampleRate: Double,
                headroomAmp: Double = Audio.headroomAmp,
                enabledUseWaveclip: Bool = true,
                isCompress: Bool = true,
                progressHandler: (Double, inout Bool) -> ()) throws {
        guard let buffer = try buffer(sampleRate: sampleRate,
                                      headroomAmp: headroomAmp,
                                      isCompress: isCompress,
                                      progressHandler: progressHandler) else { return }
        let file = try AVAudioFile(forWriting: url,
                                   settings: buffer.format.settings,
                                   commonFormat: buffer.format.commonFormat,
                                   interleaved: buffer.format.isInterleaved)
        try file.write(from: buffer)
    }
    func audio(sampleRate: Double,
               headroomAmp: Double = Audio.headroomAmp,
               enabledUseWaveclip: Bool = true,
               isCompress: Bool = true,
               progressHandler: (Double, inout Bool) -> ()) throws -> Audio? {
        guard let buffer = try buffer(sampleRate: sampleRate,
                                      headroomAmp: headroomAmp,
                                      enabledUseWaveclip: enabledUseWaveclip,
                                      isCompress: isCompress,
                                      progressHandler: progressHandler) else { return nil }
        return Audio(pcmData: buffer.pcmData)
    }
    func buffer(sampleRate: Double,
                headroomAmp: Double = Audio.headroomAmp,
                enabledUseWaveclip: Bool = true,
                isCompress: Bool = true,
                progressHandler: (Double, inout Bool) -> ()) throws -> AVAudioPCMBuffer? {
        let oldHeadroomAmp = clippingAudioUnit.headroomAmp
        let oldEnabledAttack = clippingAudioUnit.enabledAttack
        clippingAudioUnit.headroomAmp = isCompress ? nil : .init(headroomAmp)
        clippingAudioUnit.enabledAttack = false
        defer {
            clippingAudioUnit.headroomAmp = oldHeadroomAmp
            clippingAudioUnit.enabledAttack = oldEnabledAttack
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
        
        let length = AVAudioFramePosition((durSec * sampleRate).rounded(.up))
        
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
        
        if enabledUseWaveclip {
            allBuffer.useWaveclip()
        }
        if isCompress {
            allBuffer.compress(targetAmp: Float(headroomAmp))
        } else {
            allBuffer.clip(amp: Float(headroomAmp))
        }
        
        progressHandler(1, &stop)
        if stop { return nil }
        
        return allBuffer
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
    
    static func durSec(from url: URL) -> Rational {
        if let file = try? AVAudioFile(forReading: url,
                                       commonFormat: .pcmFormatFloat32,
                                       interleaved: false),
           file.fileFormat.sampleRate != 0 {
            
            .init(Int(file.length), Int(file.fileFormat.sampleRate))
        } else {
            0
        }
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
    func useWaveclip() {
        let rSampleRate = 1 / sampleRate
        let frameCount = frameCount
        for ci in 0 ..< channelCount {
            let enabledAttack = abs(self[ci, 0]) > Waveclip.minAmp
            let enabledRelease = abs(self[ci, frameCount - 1]) > Waveclip.minAmp
            if enabledAttack || enabledRelease {
                print("attack", enabledAttack, "release", enabledRelease)
                enumerated(channelIndex: ci) { i, v in
                    let aSec = Double(i) * rSampleRate
                    if enabledAttack && aSec < Waveclip.attackSec {
                        self[ci, i] *= Float(aSec * Waveclip.rAttackSec)
                    }
                    let rSec = Double(frameCount - 1 - i) * rSampleRate
                    if enabledRelease && rSec < Waveclip.releaseSec {
                        self[ci, i] *= Float(rSec * Waveclip.rReleaseSec)
                    }
                }
            }
        }
    }
    func clip(amp: Float) {
        for ci in 0 ..< channelCount {
            enumerated(channelIndex: ci) { i, v in
                if abs(v) > amp {
                    self[ci, i] = v < amp ? -amp : amp
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
    }
    func normalizeLoudness(targetLoudness: Double) {
        let gain = Loudness.normalizeLoudnessScale(inputLoudness: integratedLoudness,
                                                   targetLoudness: targetLoudness)
        self *= Float(gain)
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
    
    func compress(targetDb: Double, attackSec: Double = 0.02, releaseSec: Double = 0.02) {
        compress(targetAmp: .init(Volm.amp(fromDb: targetDb)), attackSec: attackSec, releaseSec: releaseSec)
    }
    func compress(targetAmp: Float, attackSec: Double = 0.02, releaseSec: Double = 0.02) {
        struct P {
            var minI, maxI: Int, scale: Float
        }
        
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
        let attackCount = Int(attackSec * sampleRate)
        let releaseCount = Int(releaseSec * sampleRate)
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
    var enabledAttack = true
    
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
            guard let self else { return kAudioUnitErr_NoConnection }
            guard frameCount <= self.maximumFramesToRender else {
                return kAudioUnitErr_TooManyFramesToProcess
            }
            guard pullInputBlock != nil else {
                return kAudioUnitErr_NoConnection
            }
            
            guard let inputData = self.pcmBuffer?.mutableAudioBufferList else { return kAudioUnitErr_NoConnection }
            let inputBLP = UnsafeMutableAudioBufferListPointer(inputData)
            let byteSize = Int(min(frameCount, self.maxFramesToRender)) * MemoryLayout<Float>.size
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
            
            if let headroomAmp = self.headroomAmp {
                for ci in 0 ..< outputBLP.count {
                    let inputFrames = inputBLP[ci].mData!.assumingMemoryBound(to: Float.self)
                    let outputFrames = outputBLP[ci].mData!.assumingMemoryBound(to: Float.self)
                    for i in 0 ..< Int(frameCount) {
                        outputFrames[i] = inputFrames[i]
                        if outputFrames[i].isNaN {
                            outputFrames[i] = 0
                        } else if outputFrames[i] < -headroomAmp {
                            outputFrames[i] = -headroomAmp
                        } else if outputFrames[i] > headroomAmp {
                            outputFrames[i] = headroomAmp
                        }
                    }
                }
            } else {
                for ci in 0 ..< outputBLP.count {
                    let inputFrames = inputBLP[ci].mData!.assumingMemoryBound(to: Float.self)
                    let outputFrames = outputBLP[ci].mData!.assumingMemoryBound(to: Float.self)
                    for i in 0 ..< Int(frameCount) {
                        outputFrames[i] = inputFrames[i]
                    }
                }
            }
            
            if self.enabledAttack,
               (timestamp.pointee.mFlags.contains(.sampleTimeValid)
                || timestamp.pointee.mFlags.contains(.sampleHostTimeValid))
                && timestamp.pointee.mSampleTime == 0 {
                
                for ci in 0 ..< outputBLP.count {
                    let outputFrames = outputBLP[ci].mData!.assumingMemoryBound(to: Float.self)
                    if abs(outputFrames[0]) > Waveclip.minAmp {
                        for i in 0 ..< Int(frameCount) {
                            outputFrames[i] *= .init(i) / .init(frameCount)
                        }
                    }
                }
            }
            
            return noErr
        }
    }
}
