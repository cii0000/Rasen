// Copyright 2025 Cii
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
@preconcurrency import AVFAudio
//#elseif os(linux) && os(windows)
//#endif

extension vDSP {
    static func add(in dst: inout [Double], from src: [Double], startI: Int) {
        guard startI < dst.count else { return }
        
        let count = min(src.count, dst.count - startI)
        guard count > 0 else { return }
        
        dst.withUnsafeMutableBufferPointer { dstPtr in
            src.withUnsafeBufferPointer { srcPtr in
                vDSP_vaddD(dstPtr.baseAddress!.advanced(by: startI), 1,
                           srcPtr.baseAddress!, 1,
                           dstPtr.baseAddress!.advanced(by: startI), 1,
                           vDSP_Length(count))
            }
        }
    }
}

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
            stopNote()
            playNote()
        }
    }
    func changeStereo(from notes: [Note.PitResult]) {
//        self.notes = notes
        self.aNotes = notes
        
        let count = scoreNoder.scoreTrackItem.rendnotes.count
        if notes.count <= count {
            scoreNoder.scoreTrackItem.replace(notes.enumerated().map { .init(value: $0.element.stereo,
                                                                             index: count - notes.count + $0.offset) })
        }
    }
    var sequencer: Sequencer
    var scoreNoder: ScoreNoder
    var noteIDs = Set<UUID>()
    
    struct NotePlayerError: Error {}
    
    init(notes: [Note.PitResult]) throws {
        guard let sequencer = Sequencer(audiotracks: [], type: .loopNote) else {
            throw NotePlayerError()
        }
        self.aNotes = notes
        self.sequencer = sequencer
        scoreNoder = sequencer.append(ScoreTrackItem(rendnotes: [], sampleRate: Audio.defaultSampleRate,
                                                     startSec: 0, durSec: 0,
                                                     isEnabledSamples: false))
    }
    
    var isPlaying = false
    
    func play() {
        timer.cancel()
        
        if isPlaying {
            stopNote()
        }
        playNote()
        sequencer.play()
        
        isPlaying = true
    }
    private func playNote() {
        noteIDs = []
        let rendnotes: [Rendnote] = notes.map { note in
            let (seed0, seed1) = note.id.uInt64Values
            let rootFq = Pitch.fq(fromPitch: .init(note.notePitch) + note.pitch.doubleValue)
            return .init(rootFq: rootFq,
                         firstFq: rootFq,
                         noiseSeed0: seed0, noiseSeed1: seed1,
                         pitbend: .init(pitch: 0,
                                        stereo: note.stereo,
                                        overtone: note.tone.overtone,
                                        spectlope: note.tone.spectlope),
                         secRange: -.infinity ..< .infinity,
                         reverb: .init())
        }
        rendnotes.forEach { noteIDs.insert($0.id) }
        
        scoreNoder.scoreTrackItem.rendnotes += rendnotes
        scoreNoder.scoreTrackItem.updateNotewaveDic()
    }
    private func stopNote() {
        for (i, rendnote) in scoreNoder.scoreTrackItem.rendnotes.enumerated() {
            if noteIDs.contains(rendnote.id) {
                scoreNoder.scoreTrackItem.rendnotes[i].isRelease = true
            }
        }
        noteIDs = []
    }
    
    static let stopEngineSec = 5.0
    private var timer = OneshotTimer()
    func stop() {
        stopNote()
        
        isPlaying = false
        
        timer.start(afterTime: max(NotePlayer.stopEngineSec, Waveclip.releaseSec),
                    dispatchQueue: .main) {
        } waitClosure: {
        } cancelClosure: {
        } endClosure: { [weak self] in
            self?.sequencer.stop()
            self?.scoreNoder.scoreTrackItem.rendnotes = []
            self?.scoreNoder.scoreTrackItem.updateNotewaveDic()
            self?.scoreNoder.reset()
        }
    }
}

struct PCMTrackItem {
    struct TimeOption {
        var contentLocalStartI: Int, contentCount: Int, contentStartSec: Double, contentEndSec: Double
        
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
            self.contentEndSec = self.contentStartSec + lengthSec
        }
    }
    
    var pcmBuffer: PCMBuffer
    var timeOption: TimeOption
    var stereo: Stereo
    var startSec = 0.0
    var durSec = Rational(0)
    var id = UUID()
    
    init?(content: Content, startSec: Double = 0) {
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
        
        self.startSec = startSec
        self.pcmBuffer = pcmBuffer
        timeOption = .init(pcmBuffer: pcmBuffer,
                           contentStartSec: contentStartSec,
                           contentLocalStartSec: contentLocalStartSec,
                           contentDurSec: contentDurSec,
                           lengthSec: lengthSec)
        self.durSec = durSec
        self.stereo = stereo
        self.id = id
    }
}
extension PCMTrackItem {
    var sampleRate: Double {
        pcmBuffer.format.sampleRate
    }
    
    var lufs: Double? {
        pcmBuffer.lufs
    }
    var peakDb: Double {
        pcmBuffer.peakDb
    }
    
    mutating func change(from timeOption: ContentTimeOption) {
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
}

final class PCMNoder: ObjectHashable {
    fileprivate(set) weak var sequencer: Sequencer?
    fileprivate var node: AVAudioSourceNode!
    var pcmTrackItem: PCMTrackItem
    private var startSampleTime: Float64?, isBeginPause = false, endSampleTime: Float64?
    private let isBeginPauseSemaphore = DispatchSemaphore(value: 1)
    func start() {
        isBeginPause = false
        endSampleTime = nil
        startSampleTime = nil
    }
    func beginPause() {
        isBeginPauseSemaphore.wait()
        isBeginPause = true
        isBeginPauseSemaphore.signal()
    }
    
    var stereo: Stereo {
        get {
            .init(volm: Volm.volm(fromAmp: Double(node.volume)), pan: Double(node.pan))
        }
        set {
            pcmTrackItem.stereo = newValue
            
            let oldValue = stereo
            if newValue.volm != oldValue.volm {
                node.volume = Float(Volm.amp(fromVolm: newValue.volm))
            }
            if newValue.pan != oldValue.pan {
                node.pan = Float(newValue.pan)//
            }
        }
    }
    
    var enabledWaveclip = false
    
    convenience init?(content: Content, startSec: Double = 0) {
        guard let pcmTrackItem = PCMTrackItem(content: content, startSec: startSec) else { return nil }
        self.init(pcmTrackItem: pcmTrackItem)
    }
    init(pcmTrackItem: PCMTrackItem) {
        self.pcmTrackItem = pcmTrackItem
        let sampleRate = pcmTrackItem.pcmBuffer.format.sampleRate
        let rSampleRate = 1 / sampleRate
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
            
            let pcmBuffer = pcmTrackItem.pcmBuffer
            guard timestamp.pointee.mFlags.contains(.sampleHostTimeValid)
                    || timestamp.pointee.mFlags.contains(.sampleTimeValid),
                  let data = pcmBuffer.floatChannelData else { return kAudioUnitErr_NoConnection }
            
            let startSampleTime: Float64
            if let nStartSampleTime = self.startSampleTime {
                startSampleTime = nStartSampleTime
            } else {
                self.startSampleTime = timestamp.pointee.mSampleTime
                startSampleTime = timestamp.pointee.mSampleTime
            }
            
            self.isBeginPauseSemaphore.wait()
            let isBeginPause = self.isBeginPause
            self.isBeginPauseSemaphore.signal()
            
            let endSampleTime: Float64?
            if let nEndSampleTime = self.endSampleTime {
                endSampleTime = nEndSampleTime
            } else if isBeginPause {
                self.endSampleTime = timestamp.pointee.mSampleTime
                endSampleTime = timestamp.pointee.mSampleTime
            } else {
                endSampleTime = nil
            }
            
            let seqStartI = Int(seq.startSec * sampleRate)
            let maxCount = Int(max(1, (seq.durSec * sampleRate).rounded(.up)))
            let frameStartI = Int(timestamp.pointee.mSampleTime - startSampleTime) + seqStartI
            let loopedFrameStartI = frameStartI % maxCount
            let loopStartI = (frameStartI / maxCount) * maxCount
            let loopedFrameRange = loopedFrameStartI ..< loopedFrameStartI + frameCount
            let preLoopedFrameRange = loopedFrameRange - maxCount
            let isLooped = frameStartI >= maxCount
            
            let timeOption = self.pcmTrackItem.timeOption
            let loopedContentStartSec = self.pcmTrackItem.startSec + timeOption.contentStartSec
            let loopedContentEndSec = self.pcmTrackItem.startSec + timeOption.contentEndSec
            let loopedContentStartI = Int(loopedContentStartSec * sampleRate)
            let loopedContentRange = loopedContentStartI ..< loopedContentStartI + timeOption.contentCount
            guard loopedFrameRange.intersects(loopedContentRange)
                    || preLoopedFrameRange.intersects(loopedContentRange) else {
                isSilence.pointee = true
                return noErr
            }
            
            let biganPauseI = endSampleTime != nil ? Int(endSampleTime! - startSampleTime) + seqStartI : nil
            
            let contentRange = loopedContentRange + loopStartI
            
            let playingAttackStartSec = !isLooped
            && contentRange.lowerBound != seqStartI && contentRange.contains(seqStartI) ?
            Double(seqStartI) * rSampleRate : nil
            
            let playingReleaseStartSec = biganPauseI != nil
            && (contentRange.lowerBound != biganPauseI && contentRange.contains(biganPauseI!)) ?
            Double(biganPauseI!) * rSampleRate : nil
            guard !(biganPauseI != nil && contentRange.lowerBound >= biganPauseI!) else {
                isSilence.pointee = true
                return noErr
            }
            
            let enabledWaveclip = self.enabledWaveclip
            let rSampleRate = 1 / sampleRate
            for ci in 0 ..< min(outputBLP.count, pcmBuffer.channelCount) {
                let oFrames = data[ci], nFrames = outputBLP[ci].mData!.assumingMemoryBound(to: Float.self)
                var i = loopedFrameStartI
                for ni in 0 ..< frameCount {
                    if loopedContentRange.contains(i) {
                        let oi = i - loopedContentRange.start + timeOption.contentLocalStartI
                        
                        let sec = Double(i) * rSampleRate
                        let amp = enabledWaveclip ?
                        Waveclip.amp(atSec: sec,
                                     attackStartSec: loopedContentStartSec,
                                     releaseStartSec: loopedContentEndSec - Waveclip.releaseSec) : 1
                        
                        let playingWaveclipAmp = Waveclip
                            .amp(atSec: Double(ni + frameStartI) * rSampleRate,
                                 attackStartSec: playingAttackStartSec, releaseStartSec: playingReleaseStartSec)
                        
                        nFrames[ni] = oFrames[oi * pcmBuffer.stride] * Float(amp * playingWaveclipAmp)
                    }
                    
                    i += 1
                    if i >= maxCount {
                        i -= maxCount
                    }
                }
            }
            
            return noErr
        }
        try? node.auAudioUnit.outputBusses[0].setFormat(format)
        
        self.stereo = pcmTrackItem.stereo
    }
}

private final class LockedNotewaves: @unchecked Sendable {
    private var notewaves: [Int: Notewave] = [:]
    private let lock = NSLock()
    
    init(_ notewaves: [Int: Notewave]) {
        self.notewaves = notewaves
    }
    
    subscript(i: Int) -> Notewave? {
        get {
            lock.withLock { notewaves[i] }
        }
        set {
            lock.withLock { notewaves[i] = newValue }
        }
    }
    var wrapped: [Int: Notewave] {
        get {
            lock.withLock { notewaves }
        }
        set {
            lock.withLock { notewaves = newValue }
        }
    }
}

struct ScoreTrackItem {
    var rendnotes = [Rendnote]() {
        didSet { isChanged = true }
    }
    var sampleRate = Audio.defaultSampleRate {
        didSet { isChanged = true }
    }
    var startSec = 0.0 {
        didSet { isChanged = true }
    }
    var durSec = Rational(0) {
        didSet { isChanged = true }
    }
    var loopDurSec = Rational(0) {
        didSet { isChanged = true }
    }
    let id = UUID()
    var isEnabledSamples = true
    
    fileprivate(set) var notewaveDic = [UUID: Notewave]()
    fileprivate(set) var isChanged = false
    fileprivate(set) var sampless = [[Double]](), normarizedSampless = [[Double]](),
                         sampleStartI = 0
    var sampleCount: Int {
        normarizedSampless.isEmpty ? 0 : normarizedSampless[0].count
    }
}
extension ScoreTrackItem {
    init(score: Score, startSec: Double = 0, sampleRate: Double, isUpdateNotewaveDic: Bool,
         isEnabledSamples: Bool = true) {
        rendnotes = score.notes.map { .init(note: $0, score: score) }
        self.sampleRate = sampleRate
        self.startSec = startSec
        durSec = score.secRange.end
        loopDurSec = score.sec(fromBeat: score.loopDurBeat)
        self.isEnabledSamples = isEnabledSamples
        if isUpdateNotewaveDic {
            isChanged = true
            updateNotewaveDic()
        }
    }
    
    var isEmpty: Bool {
        rendnotes.isEmpty || durSec == 0
    }
    
    func notewave(from rendnote: Rendnote) -> Notewave? {
        notewaveDic[rendnote.id]
    }
    
    var lufs: Double? {
        PCMBuffer.lufs(sampless: sampless, sampleRate: sampleRate)
    }
    var peakDb: Double {
        PCMBuffer.peakDb(sampless: sampless)
    }
    
    mutating func changeTempo(with score: Score) {
        replace(score.notes.enumerated().map { .init(value: $0.element, index: $0.offset) },
                with: score)
        
        durSec = score.secRange.end
    }
    
    mutating func insert(_ noteIVs: [IndexValue<Note>], with score: Score) {
        rendnotes.insert(noteIVs.map {
            IndexValue(value: Rendnote(note: $0.value, score: score), index: $0.index)
        })
    }
    mutating func replace(_ note: Note, at i: Int, with score: Score) {
        replace([.init(value: note, index: i)], with: score)
    }
    mutating func replace(_ noteIVs: [IndexValue<Note>], with score: Score) {
        rendnotes.replace(noteIVs.map {
            IndexValue(value: Rendnote(note: $0.value, score: score), index: $0.index)
        })
    }
    
    mutating func replace(_ sivs: [IndexValue<Stereo>]) {
        var isUpdate = false
        sivs.forEach {
            let rendnote = rendnotes[$0.index]
            let notewaveID = rendnote.id
            if var notewave = notewaveDic[notewaveID] {
                notewave = rendnote.notewave(from: notewave.noStereoSampless, stereo: $0.value,
                                             sampleRate: sampleRate)
                notewaveDic[notewaveID] = notewave
                isUpdate = true
            }
        }
        if isUpdate {
            updateSamples()
        }
    }
    
    mutating func remove(at noteIs: [Int]) {
        rendnotes.remove(at: noteIs)
    }
    
    mutating func updateNotewaveDic() {
        let newNIDs = Set(rendnotes.map { $0.id })
        let oldNIDs = Set(notewaveDic.keys)
        
        for nid in oldNIDs {
            guard !newNIDs.contains(nid) else { continue }
            notewaveDic[nid] = nil
        }
        
        let ors = rendnotes.reduce(into: [UUID: Rendnote]()) { $0[$1.id] = $1 }
        var newWillRenderRendnoteDic = [UUID: Rendnote]()
        for nid in newNIDs {
            guard notewaveDic[nid] == nil else { continue }
            newWillRenderRendnoteDic[nid] = ors[nid]
        }
        
        let nwrrs = newWillRenderRendnoteDic.map { ($0.key, $0.value) }
        if nwrrs.count > 0 {
            let sampleRate = sampleRate
            if nwrrs.count == 1 {
                let notewave = nwrrs[0].1.notewave(sampleRate: sampleRate)
                notewaveDic[nwrrs[0].0] = notewave
            } else {
                let threadCount = 8
                let nThreadCount = min(nwrrs.count, threadCount)
                
                let lockedNotewaves = LockedNotewaves(nwrrs.count.range.reduce(into: .init()) { $0[$1] = .init() })
                let dMod = nwrrs.count % threadCount
                let dCount = nwrrs.count / threadCount
                if nThreadCount == nwrrs.count {
                    DispatchQueue.concurrentPerform(iterations: nThreadCount) { threadI in
                        lockedNotewaves[threadI] = nwrrs[threadI].1.notewave(sampleRate: sampleRate)
                    }
                } else {
                    DispatchQueue.concurrentPerform(iterations: nThreadCount) { threadI in
                        for i in (threadI < dMod ? dCount + 1 : dCount).range {
                            let j = threadI < dMod ?
                            (dCount + 1) * threadI + i :
                            (dCount + 1) * dMod + dCount * (threadI - dMod) + i
                            lockedNotewaves[j] = nwrrs[j].1.notewave(sampleRate: sampleRate)
                        }
                    }
                }
                for (i, notewave) in lockedNotewaves.wrapped.sorted(by: { $0.key < $1.key }) {
                    notewaveDic[nwrrs[i].0] = notewave
                }
            }
        }
        if isChanged {
            updateSamples()
            isChanged = false
        }
    }
    mutating func updateSamples(limitLufs: Double = Audio.limitLufs) {
        guard isEnabledSamples else { return }
        let ranges = rendnotes.map { $0.releasedRange(sampleRate: sampleRate, startSec: startSec) }
        let startI = ranges.minValue { $0.start } ?? 0
        let endI = ranges.maxValue { $0.end } ?? 0
        let count = endI - startI
        
        var sampless = [[Double](repeating: 0, count: count),
                        [Double](repeating: 0, count: count)]
        for (rendnote, range) in zip(rendnotes, ranges) {
            guard let notewave = notewave(from: rendnote),
                  range.length <= notewave.sampleCount else { continue }
            for i in range {
                sampless[0][i - startI] += notewave.sampless[0][i - range.start]
                sampless[1][i - startI] += notewave.sampless[1][i - range.start]
            }
        }
        self.sampless = sampless
        
        var normarizedSampless = PCMBuffer.compress(sampless: sampless, sampleRate: sampleRate)
        if let nSampless = PCMBuffer.normalizedLoudness(sampless: normarizedSampless,
                                                        limitLufs: limitLufs,
                                                        sampleRate: sampleRate) {
            normarizedSampless = nSampless
        }
        
        self.normarizedSampless = sampless
        self.sampleStartI = -startI
    }
}

final class ScoreNoder: ObjectHashable {
    fileprivate(set) weak var sequencer: Sequencer?
    fileprivate var node: AVAudioSourceNode!
    
    private let scoreTrackItemSemaphore = DispatchSemaphore(value: 1)
    var scoreTrackItem: ScoreTrackItem {
        willSet { scoreTrackItemSemaphore.wait() }
        didSet { scoreTrackItemSemaphore.signal() }
    }
    
    private var startSampleTime: Float64?, isBeginPause = false, endSampleTime: Float64?
    private let isBeginPauseSemaphore = DispatchSemaphore(value: 1)
    func start() {
        loopNoteMemos = [:]
        isBeginPause = false
        endSampleTime = nil
        startSampleTime = nil
    }
    func beginPause() {
        isBeginPauseSemaphore.wait()
        isBeginPause = true
        isBeginPauseSemaphore.signal()
    }
    
    func reset() {
        loopNoteMemos = [:]
    }
    private var loopNoteMemos = [UUID: (startI: Int, releaseI: Int?)]()
    
    convenience init(score: Score, startSec: Double = 0, sampleRate: Double, isUpdateNotewaveDic: Bool,
                     type: Sequencer.RenderType) {
        self.init(scoreTrackItem: .init(score: score, startSec: startSec, sampleRate: sampleRate,
                                        isUpdateNotewaveDic: isUpdateNotewaveDic),
                  type: type)
    }
    init(scoreTrackItem: ScoreTrackItem, type: Sequencer.RenderType) {
        self.scoreTrackItem = scoreTrackItem
        
        let format = AVAudioFormat(standardFormatWithSampleRate: scoreTrackItem.sampleRate, channels: 2)!
        let sampleRate = scoreTrackItem.sampleRate
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
            
            let startSampleTime: Float64
            if let nStartSampleTime = self.startSampleTime {
                startSampleTime = nStartSampleTime
            } else {
                self.startSampleTime = timestamp.pointee.mSampleTime
                startSampleTime = timestamp.pointee.mSampleTime
            }
            
            self.isBeginPauseSemaphore.wait()
            let isBeginPause = self.isBeginPause
            self.isBeginPauseSemaphore.signal()
            
            let endSampleTime: Float64?
            if let nEndSampleTime = self.endSampleTime {
                endSampleTime = nEndSampleTime
            } else if isBeginPause {
                self.endSampleTime = timestamp.pointee.mSampleTime
                endSampleTime = timestamp.pointee.mSampleTime
            } else {
                endSampleTime = nil
            }
            
            self.scoreTrackItemSemaphore.wait()
            let scoreTrackItem = self.scoreTrackItem
            self.scoreTrackItemSemaphore.signal()
            
            let nFramess = outputBLP.count.range.map {
                outputBLP[$0].mData!.assumingMemoryBound(to: Float.self)
            }
            
            func updateF(i: Int, ui: Int, mi: Int, ni: Int, sampless: [[Double]],
                         isPremultipliedEnvelope: Bool,
                         allAttackStartSec: Double?, allReleaseStartSec: Double?,
                         playingAttackStartSec: Double?, playingReleaseStartSec: Double?,
                         startSec: Double, releaseSec: Double?) {
                let sec = Double(i) * rSampleRate
                
                let waveclipAmp = isPremultipliedEnvelope ?
                1 : Waveclip.amp(atSec: sec, attackStartSec: startSec, releaseStartSec: releaseSec)
                
                let allWaveclipAmp = Waveclip
                    .amp(atSec: sec, attackStartSec: allAttackStartSec, releaseStartSec: allReleaseStartSec)
                
                let playingWaveclipAmp = Waveclip
                    .amp(atSec: Double(ui) * rSampleRate,
                         attackStartSec: playingAttackStartSec, releaseStartSec: playingReleaseStartSec)
                
                let amp = waveclipAmp * allWaveclipAmp * playingWaveclipAmp
                if nFramess.count >= 2 {
                    if sampless.count >= 2 {
                        nFramess[0][ni] += Float(sampless[0][mi] * amp)
                        nFramess[1][ni] += Float(sampless[1][mi] * amp)
                    } else {
                        let nAmp = Float(sampless[0][mi] * amp)
                        nFramess[0][ni] += nAmp
                        nFramess[1][ni] += nAmp
                    }
                } else {
                    nFramess[0][ni] += Float(sampless[0][mi] * amp)
                }
            }
            
            let startSec = scoreTrackItem.startSec
            let seqStartI = Int(seq.startSec * sampleRate)
            let frameStartI = Int(timestamp.pointee.mSampleTime - startSampleTime) + seqStartI
            var contains = false
            if type == .loopNote {
                for rendnote in scoreTrackItem.rendnotes {
                    let ei: Int?
                    if rendnote.isRelease {
                        guard loopNoteMemos[rendnote.id] != nil else { continue }
                        if let oei = loopNoteMemos[rendnote.id]?.releaseI {
                            ei = min(frameStartI, oei)
                        } else {
                            loopNoteMemos[rendnote.id]?.releaseI = frameStartI
                            ei = frameStartI
                        }
                        let releaseCount = rendnote.releaseCount(sampleRate: sampleRate)
                        if frameStartI >= ei! + releaseCount {
                            loopNoteMemos[rendnote.id] = nil
                            continue
                        }
                    } else {
                        ei = nil
                    }
                    
                    guard let notewave = scoreTrackItem.notewave(from: rendnote) else { continue }
                    contains = true
                    
                    var si: Int
                    if let i = loopNoteMemos[rendnote.id]?.startI {
                        si = min(frameStartI, i)
                    } else {
                        loopNoteMemos[rendnote.id] = (frameStartI, ei)
                        si = frameStartI
                    }
                    
                    let nStartSec = startSec + .init(si) * rSampleRate
                    let releaseSec = ei != nil ? startSec + .init(ei!) * rSampleRate : nil
                    var mi = (frameStartI - si) % notewave.sampleCount
                    for ni in 0 ..< Int(frameCount) {
                        updateF(i: ni + frameStartI, ui: ni + frameStartI, mi: mi, ni: ni,
                                sampless: notewave.sampless,
                                isPremultipliedEnvelope: !notewave.isLoop,
                                allAttackStartSec: nil, allReleaseStartSec: nil,
                                playingAttackStartSec: nil, playingReleaseStartSec: nil,
                                startSec: nStartSec, releaseSec: releaseSec)
                        mi += 1
                        if mi >= notewave.sampleCount {
                            mi -= notewave.sampleCount
                        }
                    }
                }
            } else {
                let seqDurSec = seq.durSec
                let maxCount = Int(max(1, (seqDurSec * sampleRate).rounded(.up)))
                let loopedFrameStartI = type == .loop ? frameStartI % maxCount : frameStartI
                let loopStartI = (frameStartI / maxCount) * maxCount
                let loopedFrameRange = loopedFrameStartI ..< loopedFrameStartI + frameCount
                let preLoopedFrameRange = loopedFrameRange - maxCount
                let nextLoopedFrameRange = loopedFrameRange + maxCount
                let isLooped = type == .loop && frameStartI >= maxCount - frameCount
                
                let beganPauseI = endSampleTime != nil ? Int(endSampleTime! - startSampleTime) + seqStartI : nil
                
                let scoreDurSec = Double(scoreTrackItem.durSec + scoreTrackItem.loopDurSec)
                
                func make(dSampleI: Int) {
                    let loopedNoteRange = Range(start: Int((startSec * sampleRate).rounded(.down)) - scoreTrackItem.sampleStartI + dSampleI,
                                                length: scoreTrackItem.sampleCount)
                    if let beganPauseI, beganPauseI < loopedNoteRange.lowerBound + loopStartI { return }
                    
                    let preLoopedNoteRange = loopedNoteRange - maxCount
                    let nextLoopedNoteRange = loopedNoteRange + maxCount
                    let cLoopedNoteRange = loopedNoteRange.clamped(to: 0 ..< maxCount)
                    let cPreLoopedNoteRange = preLoopedNoteRange.clamped(to: 0 ..< maxCount)
                    let cNextLoopedNoteRange = nextLoopedNoteRange.clamped(to: 0 ..< maxCount)
                    
                    guard loopedFrameRange.intersects(cLoopedNoteRange)
                            || (type == .loop && preLoopedFrameRange.intersects(cLoopedNoteRange))
                            || (type == .loop && nextLoopedFrameRange.intersects(cLoopedNoteRange))
                            || (isLooped && loopedFrameRange.intersects(cPreLoopedNoteRange))
                            || (isLooped && preLoopedFrameRange.intersects(cPreLoopedNoteRange))
                            || (loopedFrameRange.intersects(cNextLoopedNoteRange))
                            || (nextLoopedFrameRange.intersects(cNextLoopedNoteRange)) else { return }
                    
                    let isFirstCross = loopedNoteRange.lowerBound < 0
                    let isLastCross = loopedNoteRange.upperBound > maxCount
                    let allAttackStartSec = type == .normal && isFirstCross ? 0.0 : nil
                    let allReleaseStartSec = type == .normal && isLastCross ? seqDurSec - Waveclip.releaseSec : nil
                    
                    let noteRange = loopedNoteRange + loopStartI
                    
                    let playingAttackStartSec = !isLooped
                    && noteRange.lowerBound != seqStartI && noteRange.contains(seqStartI) ?
                    Double(seqStartI) * rSampleRate : nil
                    
                    let playingReleaseStartSec = beganPauseI != nil
                    && (noteRange.lowerBound != beganPauseI && noteRange.contains(beganPauseI!)) ?
                    Double(beganPauseI!) * rSampleRate : nil
                    
                    let preNoteRange = noteRange - maxCount
                    let prePlayingReleaseStartSec = beganPauseI != nil
                    && (preNoteRange.lowerBound != beganPauseI && preNoteRange.contains(beganPauseI!)) ?
                    Double(beganPauseI!) * rSampleRate : nil
                    
                    let nextNoteRange = noteRange + maxCount
                    let nextPlayingAttackStartSec = !isLooped
                    && nextNoteRange.lowerBound != seqStartI && nextNoteRange.contains(seqStartI) ?
                    Double(seqStartI) * rSampleRate : nil
                    
                    let nextPlayingReleaseStartSec = beganPauseI != nil
                    && (nextNoteRange.lowerBound != beganPauseI && nextNoteRange.contains(beganPauseI!)) ?
                    Double(beganPauseI!) * rSampleRate : nil
                    
                    guard !(beganPauseI != nil && noteRange.lowerBound >= beganPauseI!)
                            || !(beganPauseI != nil && preNoteRange.lowerBound >= beganPauseI!)
                            || !(beganPauseI != nil && nextNoteRange.lowerBound >= beganPauseI!) else { return }
                    
                    contains = true
                    
                    let sampleCount = scoreTrackItem.sampleCount
                    func update(envelopeMemo: EnvelopeMemo, startSec: Double, releaseSec: Double?,
                                playingAttackStartSec: Double?,
                                playingReleaseStartSec: Double?,
                                range: Range<Int>, startI: Int) {
                        var i = loopedFrameStartI
                        for ni in 0 ..< Int(frameCount) {
                            if range.contains(i) {
                                let mi = i - startI
                                if mi >= 0 && mi < sampleCount {
                                    updateF(i: i, ui: ni + frameStartI, mi: mi, ni: ni,
                                            sampless: scoreTrackItem.normarizedSampless,
                                            isPremultipliedEnvelope: true,
                                            allAttackStartSec: allAttackStartSec,
                                            allReleaseStartSec: allReleaseStartSec,
                                            playingAttackStartSec: playingAttackStartSec,
                                            playingReleaseStartSec: playingReleaseStartSec,
                                            startSec: startSec, releaseSec: releaseSec)
                                }
                            }
                            i += 1
                            if i >= maxCount {
                                i -= maxCount
                            }
                        }
                    }
                    
                    if cLoopedNoteRange.intersects(loopedFrameRange)
                        || cLoopedNoteRange.intersects(preLoopedFrameRange)
                        || cLoopedNoteRange.intersects(nextLoopedFrameRange) {
                        update(envelopeMemo: .init(.init()),
                               startSec: startSec,
                               releaseSec: startSec + scoreDurSec,
                               playingAttackStartSec: playingAttackStartSec,
                               playingReleaseStartSec: playingReleaseStartSec,
                               range: cLoopedNoteRange, startI: loopedNoteRange.start)
                    }
                    if type == .loop && isLooped,
                       cPreLoopedNoteRange.intersects(loopedFrameRange)
                        || cPreLoopedNoteRange.intersects(preLoopedFrameRange) {
                        update(envelopeMemo: .init(.init()),
                               startSec: startSec - seqDurSec,
                               releaseSec: startSec + scoreDurSec - seqDurSec,
                               playingAttackStartSec: playingAttackStartSec,
                               playingReleaseStartSec: prePlayingReleaseStartSec,
                               range: cPreLoopedNoteRange, startI: preLoopedNoteRange.start)
                    }
                    if type == .loop,
                       cNextLoopedNoteRange.intersects(loopedFrameRange)
                        || cNextLoopedNoteRange.intersects(nextLoopedFrameRange) {
                        update(envelopeMemo: .init(.init()),
                               startSec: startSec - seqDurSec,
                               releaseSec: startSec + scoreDurSec - seqDurSec,
                               playingAttackStartSec: nextPlayingAttackStartSec,
                               playingReleaseStartSec: nextPlayingReleaseStartSec,
                               range: cNextLoopedNoteRange, startI: nextLoopedNoteRange.start)
                    }
                }
                if scoreTrackItem.loopDurSec > 0 {
                    var sec: Rational = 0
                    while sec < scoreTrackItem.durSec + scoreTrackItem.loopDurSec {
                        let dSampleI = Int((Double(sec) * sampleRate).rounded(.down))
                        make(dSampleI: dSampleI)
                        sec += scoreTrackItem.durSec
                    }
                } else {
                    make(dSampleI: 0)
                }
            }
            
            if !contains {
                isSilence.pointee = true
            }
            
            return noErr
        }
        try? node.auAudioUnit.outputBusses[0].setFormat(format)
    }
}

final class Sequencer {
    private(set) var scoreNoders: Set<ScoreNoder>
    private(set) var pcmNoders: Set<PCMNoder>
    private let mixerNode: AVAudioMixerNode
    private let limiterNode: AVAudioUnitEffect
    private let engine: AVAudioEngine
    
    var startSec = 0.0
    let type: RenderType
    private(set) var isPlaying = false
    private(set) var durSec: Double
    
    struct Track {
        var scoreTrackItems = [ScoreTrackItem]()
        var pcmTrackItems = [PCMTrackItem]()
        
        var durSec: Rational {
            max(scoreTrackItems.maxValue { $0.durSec + $0.loopDurSec } ?? 0,
                pcmTrackItems.maxValue { $0.durSec } ?? 0)
        }
        
        static func + (lhs: Self, rhs: Self) -> Self {
            .init(scoreTrackItems: lhs.scoreTrackItems + rhs.scoreTrackItems,
                  pcmTrackItems: lhs.pcmTrackItems + rhs.pcmTrackItems)
        }
        static func += (lhs: inout Self, rhs: Self) {
            lhs.scoreTrackItems += rhs.scoreTrackItems
            lhs.pcmTrackItems += rhs.pcmTrackItems
        }
        static func += (lhs: inout Self?, rhs: Self) {
            if lhs == nil {
                lhs = rhs
            } else {
                lhs?.scoreTrackItems += rhs.scoreTrackItems
                lhs?.pcmTrackItems += rhs.pcmTrackItems
            }
        }
        
        var isEmpty: Bool {
            durSec == 0 || (scoreTrackItems.allSatisfy { $0.isEmpty } && pcmTrackItems.isEmpty)
        }
    }
    static func sampless(from tracks: [Track], sampleRate: Double) -> [[Double]] {
        var allDurSec = tracks.sum { Double($0.durSec) }
        let count = Int((allDurSec * sampleRate).rounded(.up))
        
        var sampless = [[Double]](repeating: .init(repeating: 0, count: count), count: 2)
        allDurSec = 0.0
        for track in tracks {
            let durSec = track.durSec
            guard durSec > 0 else { continue }
            for scoreTrackItem in track.scoreTrackItems {
                guard scoreTrackItem.durSec > 0 else { continue }
                var scoreTrackItem = scoreTrackItem
                scoreTrackItem.startSec = allDurSec
                
                let startI = Int((allDurSec * sampleRate).rounded(.down))
                for (ci, samples) in scoreTrackItem.sampless.enumerated() {
                    vDSP.add(in: &sampless[ci], from: samples, startI: startI)
                }
            }
            
            //pcm
            
            allDurSec += Double(durSec)
        }
        
        PCMBuffer.useWaveclip(sampless: &sampless, sampleRate: sampleRate)
        
        return sampless
    }
    
    enum RenderType {
        case normal, loop, loopNote
    }
    
    convenience init?(audiotracks: [Audiotrack], clipHandler: (@Sendable (Float) -> ())? = nil,
                      type: RenderType,
                      sampleRate: Double = Audio.defaultSampleRate) {
        let audiotracks = audiotracks.filter { !$0.isEmpty }
        
        var tracks = [Track]()
        for audiotrack in audiotracks {
            let durSec = audiotrack.allDurSec
            guard durSec > 0 else { continue }
            
            var track = Track()
            for value in audiotrack.values {
                guard value.beatRange.length > 0 && value.beatRange.end > 0 else { continue }
                switch value {
                case .score(let score):
                    track.scoreTrackItems.append(.init(score: score, sampleRate: sampleRate,
                                                       isUpdateNotewaveDic: true))
                case .sound(let content):
                    guard let pcmTrackItem = PCMTrackItem(content: content) else { continue }
                    track.pcmTrackItems.append(pcmTrackItem)
                }
            }
            tracks.append(track)
        }
        
        self.init(tracks: tracks, type: type, clipHandler: clipHandler)
    }
    
    init?(tracks: [Track], type: RenderType, clipHandler: (@Sendable (Float) -> ())? = nil) {
        self.type = type
        
        let engine = AVAudioEngine()
        
        let mixerNode = AVAudioMixerNode()
        engine.attach(mixerNode)
        self.mixerNode = mixerNode
        
        var scoreNoders = Set<ScoreNoder>(), pcmNoders = Set<PCMNoder>()
        var sSec = 0.0
        for track in tracks {
            let durSec = track.durSec
            guard durSec > 0 else { continue }
            for scoreTrackItem in track.scoreTrackItems {
                guard scoreTrackItem.durSec > 0 else { continue }
                var scoreTrackItem = scoreTrackItem
                scoreTrackItem.startSec = sSec
                
                let scoreNoder = ScoreNoder(scoreTrackItem: scoreTrackItem, type: type)
                scoreNoders.insert(scoreNoder)
                
                engine.attach(scoreNoder.node)
                engine.connect(scoreNoder.node, to: mixerNode,
                               format: scoreNoder.node.outputFormat(forBus: 0))
            }
            for pcmTrackItem in track.pcmTrackItems {
                guard pcmTrackItem.durSec > 0 else { continue }
                var pcmTrackItem = pcmTrackItem
                pcmTrackItem.startSec = sSec
                
                let pcmNoder = PCMNoder(pcmTrackItem: pcmTrackItem)
                pcmNoders.insert(pcmNoder)
                
                engine.attach(pcmNoder.node)
                engine.connect(pcmNoder.node, to: mixerNode,
                               format: pcmNoder.node.outputFormat(forBus: 0))
            }
            
            sSec += Double(durSec)
        }
        durSec = sSec
        self.scoreNoders = scoreNoders
        self.pcmNoders = pcmNoders
        
        if let clipHandler {
            mixerNode.installTap(onBus: 0, bufferSize: 512, format: nil) { @Sendable buffer, time in
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
                       format: limiterNode.inputFormat(forBus: 0))
        engine.connect(limiterNode, to: engine.mainMixerNode,
                       format: limiterNode.outputFormat(forBus: 0))
        
        self.engine = engine
        
        scoreNoders.forEach { $0.sequencer = self }
        pcmNoders.forEach { $0.sequencer = self }
    }
    
    deinit {
        engine.stop()
        engine.reset()
        
        for noder in scoreNoders {
            engine.disconnectNodeOutput(noder.node)
            engine.detach(noder.node)
            
            noder.reset()
            noder.sequencer = nil
        }
        
        for noder in pcmNoders {
            engine.disconnectNodeOutput(noder.node)
            engine.detach(noder.node)
            
            noder.sequencer = nil
        }
        
        engine.disconnectNodeOutput(mixerNode)
        engine.detach(mixerNode)
        
        engine.disconnectNodeOutput(limiterNode)
        engine.detach(limiterNode)
    }
}
extension Sequencer {
    func append(_ scoreTrackItem: ScoreTrackItem) -> ScoreNoder {
        let scoreNoder = ScoreNoder(scoreTrackItem: scoreTrackItem, type: type)
        scoreNoders.insert(scoreNoder)
        
        engine.attach(scoreNoder.node)
        engine.connect(scoreNoder.node, to: mixerNode,
                       format: scoreNoder.node.outputFormat(forBus: 0))
        
        scoreNoder.sequencer = self
        return scoreNoder
    }
    func remove(_ noder: ScoreNoder) {
        guard scoreNoders.contains(noder) else { return }
        scoreNoders.remove(noder)
        
        engine.disconnectNodeOutput(noder.node)
        engine.detach(noder.node)
        
        noder.sequencer = nil
    }
    func update(_ tracks: [Track]) {
        for noder in scoreNoders {
            engine.disconnectNodeOutput(noder.node)
            engine.detach(noder.node)
            
            noder.reset()
            noder.sequencer = nil
        }
        for noder in pcmNoders {
            engine.disconnectNodeOutput(noder.node)
            engine.detach(noder.node)
            
            noder.sequencer = nil
        }
        
        var scoreNoders = Set<ScoreNoder>(), pcmNoders = Set<PCMNoder>()
        var sSec = 0.0
        for track in tracks {
            let durSec = track.durSec
            guard durSec > 0 else { continue }
            for scoreTrackItem in track.scoreTrackItems {
                guard scoreTrackItem.durSec > 0 else { continue }
                var scoreTrackItem = scoreTrackItem
                scoreTrackItem.startSec = sSec
                
                let scoreNoder = ScoreNoder(scoreTrackItem: scoreTrackItem, type: type)
                scoreNoders.insert(scoreNoder)
                
                engine.attach(scoreNoder.node)
                engine.connect(scoreNoder.node, to: mixerNode,
                               format: scoreNoder.node.outputFormat(forBus: 0))
            }
            for pcmTrackItem in track.pcmTrackItems {
                guard pcmTrackItem.durSec > 0 else { continue }
                var pcmTrackItem = pcmTrackItem
                pcmTrackItem.startSec = sSec
                
                let pcmNoder = PCMNoder(pcmTrackItem: pcmTrackItem)
                pcmNoders.insert(pcmNoder)
                
                engine.attach(pcmNoder.node)
                engine.connect(pcmNoder.node, to: mixerNode,
                               format: pcmNoder.node.outputFormat(forBus: 0))
            }
            
            sSec += Double(durSec)
        }
        durSec = sSec
        
        self.scoreNoders = scoreNoders
        self.pcmNoders = pcmNoders
        
        scoreNoders.forEach { $0.sequencer = self }
        pcmNoders.forEach { $0.sequencer = self }
    }
    
    func play() {
        isPlaying = true
        scoreNoders.forEach { $0.start() }
        pcmNoders.forEach { $0.start() }
        if !engine.isRunning {
            try? engine.start()
        }
    }
    
    func beginPause() {
        scoreNoders.forEach { $0.beginPause() }
        pcmNoders.forEach { $0.beginPause() }
    }
    func pause() {
        if engine.isRunning {
            engine.prepare()
        }
        isPlaying = false
    }
    
    func stop() {
        if engine.isRunning {
            engine.stop()
        }
        isPlaying = false
    }
}
extension Sequencer {
    private var clippingAudioUnit: ClippingAudioUnit {
        limiterNode.auAudioUnit as! ClippingAudioUnit
    }
    
    struct ExportError: Error {}
    
    static func audioSettings(isLinearPCM: Bool, channelCount: Int,
                              sampleRate: Double) -> [String: Any] {
        isLinearPCM ?
        [AVFormatIDKey: kAudioFormatLinearPCM,
             AVLinearPCMBitDepthKey: 24,
             AVLinearPCMIsFloatKey: false,
             AVLinearPCMIsBigEndianKey: false,
             AVLinearPCMIsNonInterleaved: false,
             AVNumberOfChannelsKey: channelCount,
             AVSampleRateKey: Float(sampleRate)] :
            [AVFormatIDKey: kAudioFormatMPEG4AAC,
             AVNumberOfChannelsKey: channelCount,
             AVSampleRateKey: Float(sampleRate),
             AVEncoderBitRateKey: 320000]
    }
    
    func export(url: URL,
                sampleRate: Double,
                headroomAmp: Double = Audio.headroomAmp,
                enabledUseWaveclip: Bool = true,
                isCompress: Bool = true,
                isLinearPCM: Bool,
                progressHandler: (Double, inout Bool) -> ()) throws {
        guard let buffer = try buffer(sampleRate: sampleRate,
                                      headroomAmp: headroomAmp,
                                      isCompress: isCompress,
                                      progressHandler: progressHandler) else { return }
        
        let settings = Self.audioSettings(isLinearPCM: isLinearPCM,
                                          channelCount: buffer.channelCount,
                                          sampleRate: sampleRate)
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32,
                                   interleaved: true)
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
                limitLufs: Double? = Audio.limitLufs,
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
        play()
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                            frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            stop()
            throw ExportError()
        }
        
        let length = AVAudioFramePosition((durSec * sampleRate).rounded(.up))
        
        guard let allBuffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                               frameCapacity: AVAudioFrameCount(length)) else {
            stop()
            throw ExportError()
        }
        
        var isStop = false
        while engine.manualRenderingSampleTime < length {
            do {
                let mrst = engine.manualRenderingSampleTime
                let frameCount = length - mrst
                let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
                let status = try engine.renderOffline(framesToRender, to: buffer)
                switch status {
                case .success:
                    allBuffer.append(buffer)
                    progressHandler(Double(mrst) / Double(length), &isStop)
                    if isStop { return nil }
                case .insufficientDataFromInputNode:
                    throw ExportError()
                case .cannotDoInCurrentContext:
                    progressHandler(Double(mrst) / Double(length), &isStop)
                    if isStop { return nil }
                    Thread.sleep(forTimeInterval: 0.1)
                case .error: throw ExportError()
                @unknown default: throw ExportError()
                }
            } catch {
                stop()
                throw error
            }
        }
        
        stop()
        
        if enabledUseWaveclip {
            allBuffer.useWaveclip()
        }
        if let limitLufs {
            allBuffer.normalizeLoudness(limitLufs: limitLufs)
        }
        if isCompress {
            allBuffer.compress(targetAmp: Float(headroomAmp))
        } else {
            allBuffer.clip(amp: Float(headroomAmp))
        }
        
        progressHandler(1, &isStop)
        if isStop { return nil }
        
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
        guard frameCount > 0 else { return }
        for ci in 0 ..< channelCount {
            let enabledAttack = abs(self[ci, 0]) > Waveclip.minAmp
            let enabledRelease = abs(self[ci, frameCount - 1]) > Waveclip.minAmp
            if enabledAttack || enabledRelease {
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
    static func useWaveclip(sampless: inout [[Double]], sampleRate: Double) {
        let rSampleRate = 1 / sampleRate
        let frameCount = sampless[0].count, channelCount = sampless.count
        guard frameCount > 0 else { return }
        for ci in 0 ..< channelCount {
            let enabledAttack = abs(sampless[ci][0]) > Waveclip.minDoubleAmp
            let enabledRelease = abs(sampless[ci][frameCount - 1]) > Waveclip.minDoubleAmp
            if enabledAttack || enabledRelease {
                for i in 0 ..< frameCount {
                    let aSec = Double(i) * rSampleRate
                    if enabledAttack && aSec < Waveclip.attackSec {
                        sampless[ci][i] *= aSec * Waveclip.rAttackSec
                    }
                    let rSec = Double(frameCount - 1 - i) * rSampleRate
                    if enabledRelease && rSec < Waveclip.releaseSec {
                        sampless[ci][i] *= rSec * Waveclip.rReleaseSec
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
    var doubleSampless: [[Double]] {
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
    
    static func normalizeScale(inputDb: Double, targetDb: Double) -> Double {
        10 ** ((targetDb - inputDb) / 20)
    }
    
    var peakAmp: Double {
        var peakAmp: Float = 0.0
        for ci in 0 ..< channelCount {
            enumerated(channelIndex: ci) { _, v in
                peakAmp = max(abs(v), peakAmp)
            }
        }
        return Double(peakAmp)
    }
    var peakDb: Double {
        Volm.db(fromAmp: peakAmp)
    }
    
    static func peakAmp(sampless: [[Double]]) -> Double {
        sampless.map { cs in (cs.map { abs($0) }).max()! }.max()!
    }
    static func peakDb(sampless: [[Double]]) -> Double {
        Volm.db(fromAmp: peakAmp(sampless: sampless))
    }
    
    var lufs: Double? {
        try? Loudness(sampleRate: sampleRate).lufs(from: doubleSampless)
    }
    func normalizeLoudness(limitLufs: Double) {
        if let lufs = lufs, lufs > limitLufs {
            self *= Float(Self.normalizeScale(inputDb: lufs, targetDb: limitLufs))
        }
    }
    
    static func lufs(sampless: [[Double]], sampleRate: Double) -> Double? {
        try? Loudness(sampleRate: sampleRate).lufs(from: sampless)
    }
    static func normalizedLoudness(sampless: [[Double]], limitLufs: Double,
                                   sampleRate: Double) -> [[Double]]? {
        let lufs = (try? Loudness(sampleRate: sampleRate).lufs(from: sampless)) ?? limitLufs
        if lufs > limitLufs {
            let scale = PCMBuffer.normalizeScale(inputDb: lufs, targetDb: limitLufs)
            return sampless.count.range.map { vDSP.multiply(scale, sampless[$0]) }
        }
        return nil
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
    
    static func compress(sampless: [[Double]], headroomAmp: Double = Audio.headroomAmp,
                         sampleRate: Double,
                         attackSec: Double = 0.02, releaseSec: Double = 0.02) -> [[Double]] {
        struct P {
            var minI, maxI: Int, scale: Double
        }
        let frameCount = sampless.isEmpty ? 0 : sampless[0].count
        
        var minI: Int?, maxDAmp = 0.0, ps = [P]()
        for i in 0 ..< frameCount {
            var maxAmp = 0.0
            for ci in 0 ..< sampless.count {
                let amp = sampless[ci][i]
                maxAmp = max(maxAmp, abs(amp))
            }
            if maxAmp > headroomAmp {
                if minI == nil {
                    minI = i
                }
                maxDAmp = max(maxDAmp, maxAmp - headroomAmp)
            } else {
                if let nMinI = minI {
                    ps.append(P(minI: nMinI, maxI: i, scale: headroomAmp / (maxDAmp + headroomAmp)))
                    minI = nil
                    maxDAmp = 0
                }
            }
        }
        
        if ps.isEmpty {
            return sampless
        }
        
        let attackCount = Int(attackSec * sampleRate)
        let rAttackCount = 1 / Double(attackCount)
        let releaseCount = Int(releaseSec * sampleRate)
        let rReleaseCount = 1 / Double(releaseCount)
        var scales = [Double](repeating: 1, count: frameCount)
        for p in ps {
            let minI = max(0, p.minI - attackCount)
            for i in (minI ..< p.minI).reversed() {
                let t = Double(p.minI - i) * rAttackCount
                let scale = Double.linear(p.scale, 1, t: t)
                scales[i] = min(scale, scales[i])
            }
            for i in p.minI ..< p.maxI {
                scales[i] = min(p.scale, scales[i])
            }
            let maxI = min(frameCount - 1, p.maxI + releaseCount)
            for i in p.maxI ... maxI {
                let t = Double(i - p.maxI) * rReleaseCount
                let scale = Double.linear(p.scale, 1, t: t)
                scales[i] = min(scale, scales[i])
            }
        }
        
        return sampless.count.range.map { vDSP.multiply(scales, sampless[$0]) }
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
                    ps.append(P(minI: nMinI, maxI: i, scale: targetAmp / (maxDAmp + targetAmp)))
                    minI = nil
                    maxDAmp = 0
                }
            }
        }
        
        if ps.isEmpty { return }
        
        let attackCount = Int(attackSec * sampleRate)
        let releaseCount = Int(releaseSec * sampleRate)
        var scales = [Float](repeating: 1, count: frameCount)
        for p in ps {
            let minI = max(0, p.minI - attackCount)
            for i in (minI ..< p.minI).reversed() {
                let t = Float(p.minI - i) / Float(attackCount)
                let scale = Float.linear(p.scale, 1, t: t)
                scales[i] = min(scale, scales[i])
            }
            for i in p.minI ..< p.maxI {
                scales[i] = min(p.scale, scales[i])
            }
            let maxI = min(frameCount - 1, p.maxI + releaseCount)
            for i in p.maxI ... maxI {
                let t = Float(i - p.maxI) / Float(releaseCount)
                let scale = Float.linear(p.scale, 1, t: t)
                scales[i] = min(scale, scales[i])
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
    
    private var pcmBuffer: AVAudioPCMBuffer?

    var headroomAmp: Float? = Float(Audio.floatHeadroomAmp)
    var enabledAttack = true
    
    struct SError: Error {}

    override init(componentDescription: AudioComponentDescription,
                  options: AudioComponentInstantiationOptions = []) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Audio.defaultSampleRate,
                                         channels: 2) else { throw SError() }
        try inputBus = AUAudioUnitBus(format: format)
        inputBus.maximumChannelCount = 8
        try outputBus = AUAudioUnitBus(format: format)

        let maxFramesToRender: UInt32 = 512
        guard let pcmBuffer
                = AVAudioPCMBuffer(pcmFormat: format,
                                   frameCapacity: maxFramesToRender) else { throw SError() }
        self.pcmBuffer = pcmBuffer

        try super.init(componentDescription: componentDescription, options: options)

        self.maximumFramesToRender = maxFramesToRender
    }
    override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        
        guard let pcmBuffer
                = AVAudioPCMBuffer(pcmFormat: outputBus.format,
                                   frameCapacity: maximumFramesToRender) else { throw SError() }
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
            let byteSize = Int(frameCount) * MemoryLayout<Float>.size
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
