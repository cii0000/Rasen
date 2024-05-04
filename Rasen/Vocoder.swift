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

import struct Foundation.UUID
import RealModule
import enum Accelerate.vDSP
import struct Foundation.Date

/// xoshiro256**
struct Random: Hashable, Codable {
    static let defaultSeed: UInt64 = 88675123
    
    private struct State: Hashable, Codable {
        var x: UInt64 = 123456789
        var y: UInt64 = 362436069
        var z: UInt64 = 521288629
        var w = defaultSeed
    }
    private var state = State()
    var seed: UInt64 { state.w }
    
    init(seed: UInt64 = defaultSeed) {
        state.w = seed
    }
    
    private func rol(_ x: UInt64, _ k: Int) -> UInt64 {
        (x << k) | (x >> (64 - k))
    }
    mutating func next() -> UInt64 {
        let result = rol(state.y &* 5, 7) &* 9
        let t = state.y << 17
        state.z ^= state.x
        state.w ^= state.y
        state.y ^= state.z
        state.x ^= state.w
        
        state.z ^= t
        state.w = rol(state.w, 45)
        return result
    }
    mutating func nextT() -> Double {
        return Double(next()) / Double(UInt64.max)
    }
}

extension vDSP {
    static func gaussianNoise(count: Int,
                              seed: UInt64 = Random.defaultSeed) -> [Double] {
        gaussianNoise(count: count, seed0: seed, seed1: seed << 10)
    }
    static func gaussianNoise(count: Int,
                              seed0: UInt64 = Random.defaultSeed,
                              seed1: UInt64 = 100001,
                              maxAmp: Double = 3) -> [Double] {
        guard count > 0 else { return [] }
        
        var random0 = Random(seed: seed0),
            random1 = Random(seed: seed1)
        var vs = [Double](capacity: count)
        for _ in 0 ..< count {
            let t0 = random0.nextT()
            let t1 = random1.nextT()
            let cosV = Double.cos(2 * .pi * t1)
            let x = t0 == 0 ?
                (cosV < 0 ? -maxAmp : maxAmp) :
                (-2 * .log(t0)).squareRoot() * cosV
            vs.append(x.clipped(min: -maxAmp, max: maxAmp))
        }
        return vs
    }
    static func approximateGaussianNoise(count: Int,
                                         seed: UInt64 = Random.defaultSeed,
                                         maxAmp: Double = 3) -> [Double] {
        guard count > 0 else { return [] }
        
        var random = Random(seed: seed)
        var vs = [Double](capacity: count)
        for _ in 0 ..< count {
            var v: Double = 0
            for _ in 0 ..< 12 {
                v += Double(random.next())
            }
            vs.append(v)
        }
        vDSP.multiply(1 / Double(UInt64.max), vs, result: &vs)
        vDSP.add(-6, vs, result: &vs)
        return vs.map { $0.clipped(min: -maxAmp, max: maxAmp) }
    }
}

struct EnvelopeMemo {
    let attackSec, decaySec, sustainVolm, releaseSec: Double
    let attackAndDecaySec: Double
    let rAttackSec, rDecaySec, rReleaseSec: Double
    
    init(_ envelope: Envelope) {
        attackSec = max(envelope.attackSec, 0)
        decaySec = max(envelope.decaySec, 0)
        sustainVolm = envelope.sustainVolm
        releaseSec = max(envelope.releaseSec, 0)
        attackAndDecaySec = attackSec + decaySec
        rAttackSec = 1 / attackSec
        rDecaySec = 1 / decaySec
        rReleaseSec = 1 / releaseSec
    }
}
extension EnvelopeMemo {
    func duration(fromDurSec durSec: Double) -> Double {
        durSec < attackAndDecaySec ? attackAndDecaySec + releaseSec : durSec + releaseSec
    }
    
    func volm(atSec sec: Double, releaseStartSec relaseStartSec: Double?) -> Double {
        if sec < 0 {
            return 0
        } else if attackSec > 0 && sec < attackSec {
            return sec * rAttackSec
        } else {
            let nSec = sec - attackSec
            if decaySec > 0 && nSec < decaySec {
                return .linear(1, sustainVolm, t: nSec * rDecaySec)
            } else if let relaseStartSec {
                let rsSec = relaseStartSec < attackAndDecaySec ? attackAndDecaySec : relaseStartSec
                if sec < rsSec {
                    return sustainVolm
                } else {
                    let nnSec = sec - rsSec
                    if releaseSec > 0 && nnSec < releaseSec {
                        return .linear(sustainVolm, 0, t: nnSec * rReleaseSec)
                    } else {
                        return 0
                    }
                }
            } else {
                return sustainVolm
            }
        }
    }
}

struct InterPit: Hashable, Codable {
    var pitch = 0.0, stereo = Stereo(), tone = Tone(), lyric = ""
}
extension InterPit: MonoInterpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(pitch: .linear(f0.pitch, f1.pitch, t: t),
              stereo: .linear(f0.stereo, f1.stereo, t: t),
              tone: .linear(f0.tone, f1.tone, t: t),
              lyric: f0.lyric)
    }
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(pitch: .firstSpline(f1.pitch, f2.pitch, f3.pitch, t: t),
              stereo: .firstSpline(f1.stereo, f2.stereo, f3.stereo, t: t),
              tone: .firstSpline(f1.tone, f2.tone, f3.tone, t: t),
              lyric: f1.lyric)
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(pitch: .spline(f0.pitch, f1.pitch, f2.pitch, f3.pitch, t: t),
              stereo: .spline(f0.stereo, f1.stereo, f2.stereo, f3.stereo, t: t),
              tone: .spline(f0.tone, f1.tone, f2.tone, f3.tone, t: t),
              lyric: f1.lyric)
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(pitch: .lastSpline(f0.pitch, f1.pitch, f2.pitch, t: t),
              stereo: .lastSpline(f0.stereo, f1.stereo, f2.stereo, t: t),
              tone: .lastSpline(f0.tone, f1.tone, f2.tone, t: t),
              lyric: f1.lyric)
    }
    static func firstMonospline(_ f1: Self,
                                _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(pitch: .firstMonospline(f1.pitch, f2.pitch, f3.pitch, with: ms),
              stereo: .firstMonospline(f1.stereo, f2.stereo, f3.stereo, with: ms),
              tone: .firstMonospline(f1.tone, f2.tone, f3.tone, with: ms),
              lyric: f1.lyric)
    }
    static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(pitch: .monospline(f0.pitch, f1.pitch, f2.pitch, f3.pitch, with: ms),
              stereo: .monospline(f0.stereo, f1.stereo, f2.stereo, f3.stereo, with: ms),
              tone: .monospline(f0.tone, f1.tone, f2.tone, f3.tone, with: ms),
              lyric: f1.lyric)
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) -> Self {
        .init(pitch: .lastMonospline(f0.pitch, f1.pitch, f2.pitch, with: ms),
              stereo: .lastMonospline(f0.stereo, f1.stereo, f2.stereo, with: ms),
              tone: .lastMonospline(f0.tone, f1.tone, f2.tone, with: ms),
              lyric: f1.lyric)
    }
}
struct Pitbend: Codable, Hashable {
    let pitchInterpolation: Interpolation<Double>
    let firstPitch: Double, firstFqScale: Double, isEqualAllPitch: Bool
    
    let stereoInterpolation: Interpolation<Stereo>
    let firstStereo: Stereo, isEqualAllStereo: Bool
    
    let overtoneInterpolation: Interpolation<Overtone>
    let firstOvertone: Overtone, isEqualAllOvertone: Bool
    
    let spectlopeInterpolation: Interpolation<Spectlope>
    let firstSpectlope: Spectlope, isEqualAllSpectlope: Bool
 
    init(pits: [Pit], beatRange: Range<Rational>, tempo: Rational) {
        let pitchs = pits.map { Double($0.pitch / 12) }
        let stereos = pits.map { $0.stereo.with(id: .zero) }
        let overtones = pits.map { $0.tone.overtone }
        let spectlopeCount = pits.maxValue { $0.tone.spectlope.sprols.count } ?? 0
        let spectlopes = pits.map { $0.tone.spectlope.with(count: spectlopeCount) }
        let secs = pits.map { Double(Score.sec(fromBeat: $0.beat, tempo: tempo)) }
        let durSec = Double(Score.sec(fromBeat: beatRange.length, tempo: tempo))
        func interpolation<T: MonoInterpolatable & Equatable>(isAll: Bool, _ vs: [T]) -> Interpolation<T> {
            guard !isAll else { return .init() }
            var pitKeys = zip(vs, secs).map {
                Interpolation.Key(value: $0.0, time: $0.1, type: .spline)
            }
            if pits.first!.beat > 0 {
                pitKeys.insert(.init(value: pitKeys.first!.value, time: 0, type: .spline), at: 0)
            }
            if pits.last!.beat < beatRange.length {
                pitKeys.append(.init(value: pitKeys.last!.value, time: durSec, type: .spline))
            }
            return .init(keys: pitKeys, duration: durSec)
        }
        
        let firstPitch = pitchs.first!
        self.firstPitch = firstPitch
        firstFqScale = .exp2(firstPitch)
        isEqualAllPitch = !(pitchs.contains { $0 != firstPitch })
        pitchInterpolation = interpolation(isAll: isEqualAllPitch, pitchs)
        
        let firstStereo = stereos.first!
        self.firstStereo = firstStereo
        isEqualAllStereo = !(stereos.contains { $0 != firstStereo })
        stereoInterpolation = interpolation(isAll: isEqualAllStereo, stereos)
        
        let firstOvertone = overtones.first!
        self.firstOvertone = firstOvertone
        isEqualAllOvertone = !(overtones.contains { $0 != firstOvertone })
        overtoneInterpolation = interpolation(isAll: isEqualAllOvertone, overtones)
        
        let firstSpectlope = spectlopes.first!
        self.firstSpectlope = firstSpectlope
        isEqualAllSpectlope = !(spectlopes.contains { $0 != firstSpectlope })
        spectlopeInterpolation = interpolation(isAll: isEqualAllSpectlope, spectlopes)
    }
    init(pitch: Double, stereo: Stereo, overtone: Overtone, spectlope: Spectlope) {
        pitchInterpolation = .init()
        firstPitch = pitch
        firstFqScale = .exp2(pitch)
        isEqualAllPitch = true
        
        stereoInterpolation = .init()
        firstStereo = stereo.with(id: .zero)
        isEqualAllStereo = true
        
        overtoneInterpolation = .init()
        firstOvertone = overtone
        isEqualAllOvertone = true
        
        spectlopeInterpolation = .init()
        firstSpectlope = spectlope
        isEqualAllSpectlope = true
    }
}
extension Pitbend {
    var isEmpty: Bool {
        isEqualAllStereo && firstStereo.isEmpty
    }
    
    func pitch(atSec sec: Double) -> Double {
        isEqualAllPitch ? 
        firstPitch :
        pitchInterpolation.monoValueEnabledFirstLast(withT: sec, isLoop: false) ?? 0
    }
    func fqScale(atSec sec: Double) -> Double {
        isEqualAllPitch ? firstFqScale : .exp2(pitch(atSec: sec))
    }
    
    func stereo(atSec sec: Double) -> Stereo {
        isEqualAllStereo ?
        firstStereo : 
        stereoInterpolation.monoValueEnabledFirstLast(withT: sec, isLoop: false) ?? firstStereo
    }
    
    func overtone(atSec sec: Double) -> Overtone {
        isEqualAllOvertone ?
        firstOvertone : 
        overtoneInterpolation.monoValueEnabledFirstLast(withT: sec, isLoop: false) ?? firstOvertone
    }
    
    func spectlope(atSec sec: Double) -> Spectlope {
        isEqualAllSpectlope ?
        firstSpectlope :
        spectlopeInterpolation.monoValueEnabledFirstLast(withT: sec, isLoop: false) ?? firstSpectlope
    }
    
    var containsNoise: Bool {
        isEqualAllSpectlope ?
        firstSpectlope.containsNoise :
        spectlopeInterpolation.keys.contains { $0.value.containsNoise }
    }
    var isFullNoise: Bool {
        isEqualAllSpectlope ?
        firstSpectlope.isFullNoise :
        !spectlopeInterpolation.keys.contains { !$0.value.isFullNoise }
    }
    var isOne: Bool {
        isEqualAllOvertone ?
        firstOvertone.isOne : !overtoneInterpolation.keys.contains { !$0.value.isOne }
    }
    var isEqualAllWithoutStereo: Bool {
        isEqualAllPitch && isEqualAllOvertone && isEqualAllSpectlope
    }
}

struct Rendnote {
    var fq: Double
    var noiseSeed: UInt64
    var pitbend: Pitbend
    var secRange: Range<Double>
    var startDeltaSec: Double
    var envelopeMemo: EnvelopeMemo
    var id = UUID()
}
extension Rendnote {
    static func noiseSeed(from id: UUID) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(id)
        return UInt64(abs(hasher.finalize()))
    }
    init(note: Note, score: Score, snapBeatScale: Rational = .init(1, 4)) {
        let startBeat = note.beatRange.start
        let endBeat = note.beatRange.end
        let snapBeat = startBeat.interval(scale: snapBeatScale)
        let sSec = Double(score.sec(fromBeat: startBeat))
        let eSec = Double(score.sec(fromBeat: endBeat))
        let snapSec = Double(score.sec(fromBeat: snapBeat))
        let dSec = sSec - snapSec
        
        self.init(fq: note.firstFq,
                  noiseSeed: note.containsNoise ? Rendnote.noiseSeed(from: note.id) : 0,
                  pitbend: note.pitbend(fromTempo: score.tempo),
                  secRange: sSec ..< eSec,
                  startDeltaSec: dSec,
                  envelopeMemo: .init(note.envelope))
    }
    
    var isStft: Bool {
        !pitbend.isEqualAllWithoutStereo
    }
    var isLoop: Bool {
        if pitbend.isEmpty {
            true
        } else if pitbend.isOne {
            pitbend.isEqualAllPitch
        } else {
            secRange.length.isInfinite || (!isStft && !pitbend.containsNoise)
        }
    }
    var rendableDurSec: Double {
        isLoop ? 1 : envelopeMemo.duration(fromDurSec: min(secRange.length, 100000))
    }
}
extension Rendnote {
    func notewave(stftCount: Int = 1024, fAlpha: Double = 1, rmsSize: Int = 2048,
                  cutFq: Double = 16384, sampleRate: Double = Audio.defaultSampleRate,
                  fftCount: Int = Audio.defaultFftCount) -> Notewave {
        let date = Date()
        
        let notewave = aNotewave(stftCount: stftCount, fAlpha: fAlpha, rmsSize: rmsSize,
                                 cutFq: cutFq, sampleRate: sampleRate, fftCount: fftCount)
        
        print(Date().timeIntervalSince(date), notewave.isLoop, notewave.samples.count)
        
        if notewave.samples.contains(where: { $0.isNaN || $0.isInfinite }) {
            print(notewave.samples.contains(where: { $0.isInfinite }) ? "inf" : "nan")
        }
        
        return notewave
    }
    private func aNotewave(stftCount: Int, fAlpha: Double, rmsSize: Int,
                           cutFq: Double, sampleRate: Double,
                           fftCount: Int) -> Notewave {
        guard !pitbend.isEmpty else {
            return .init(fqScale: 1, isLoop: true, samples: [0], stereos: [.init()])
        }
        
        let isLoop = isLoop
        let isStft = isStft
        let isFullNoise = pitbend.isFullNoise
        let containsNoise = pitbend.containsNoise
        let rendableDurSec = rendableDurSec
        let sampleCount = rendableDurSec == 1 ? fftCount : Int((rendableDurSec * sampleRate).rounded(.up))
        guard sampleCount >= 4 else {
            return .init(fqScale: 1, isLoop: isLoop, samples: [0], stereos: [.init()])
        }
        
//        let testSamples = (0 ..< 128).map { Double.sin(10 * Double($0) / 128 * 2 * .pi) }
//        let fft = try! Fft(count: 128)
//        let (dc, amps) = fft.dcAndAmps(testSamples)
//        let ifft = try! Ifft(count: 128)
//        let nnv = ifft.resTransform(dc: dc, amps: amps, phases: amps.map { _ in 0 })
//        print(fft.dcAndAmps(nnv))        
        
        func stereos(sampleCount: Int) -> [Stereo] {
            pitbend.isEqualAllStereo ?
            [pitbend.firstStereo] :
            sampleCount.range.map { pitbend.stereo(atSec: Double($0) * rSampleRate) }
        }
        
        let fq = max(fq, 1)
        let intFq = fq.rounded(.down)
        let fqScale = fq / intFq
        
        let rSampleRate = 1 / sampleRate
        let isOneSin = pitbend.isOne
        if isOneSin {
            if pitbend.isEqualAllPitch {
                let a = 2 * .pi * intFq * rSampleRate
                var samples = fftCount.range
                    .map { Double.sin(Double($0) * a + startDeltaSec) }
                let amp = Volm.amp(fromVolm: Loudness.reverseVolm40Phon(fromFq: fq))
                let rScale = Double.sqrt(2) / amp
                vDSP.multiply(rScale, samples, result: &samples)
                
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: fqScale, isLoop: isLoop, samples: samples, stereos: stereos)
            } else {
                let a = 2 * .pi * rSampleRate, sqrt2 = Double.sqrt(2)
                var phase = startDeltaSec
                let samples = sampleCount.range.map {
                    let sec = Double($0) * rSampleRate
                    let fq = fq * pitbend.fqScale(atSec: sec)
                    let amp = Volm.amp(fromVolm: Loudness.reverseVolm40Phon(fromFq: fq))
                    let rScale = sqrt2 / amp
                    let v = rScale * Double.sin(phase)
                    phase += fq * a
                    return v
                }
                
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: 1, isLoop: isLoop, samples: samples, stereos: stereos)
            }
        }
        
        let halfStftCount = stftCount / 2
        let maxFq = sampleRate / 2
        let sqfa = fAlpha * 0.5
        let sqfas: [Double] = halfStftCount.range.map {
            let nfq = Double($0) / Double(halfStftCount) * maxFq
            return $0 == 0 || nfq == 0 ? 1 : 1 / (nfq / fq) ** sqfa
        }
        
        func spline(_ samples: [Double], phase: Double) -> Double {
            if phase.isInteger {
                return samples[Int(phase)]
            } else {
                let sai = Int(phase)
                
                let a0 = sai - 1 >= 0 ? samples[sai - 1] : 0
                let a1 = samples[sai]
                let a2 = sai + 1 < samples.count ? samples[sai + 1] : 0
                let a3 = sai + 2 < samples.count ? samples[sai + 2] : 0
                let t = phase - Double(sai)
                return Double.spline(a0, a1, a2, a3, t: t)
            }
        }
        
        func spectrum(from sprols: [Sprol], fq: Double, isLoudness: Bool) -> [Double] {
            var i = 1
            return (0 ..< halfStftCount).map { fqi in
                guard fqi != 0 else { return 0 }
                let nfq = Double(fqi) / Double(halfStftCount) * maxFq
                guard nfq > 0 && nfq < cutFq else { return 0 }
                let nPitch = Pitch.pitch(fromFq: nfq)
                while i + 1 < sprols.count, nPitch > sprols[i].pitch { i += 1 }
                let volm: Double
                if let lastSprol = sprols.last, nPitch >= lastSprol.pitch {
                    volm = lastSprol.noisedVolm
                } else {
                    let preSprol = sprols[i - 1], nextSprol = sprols[i]
                    let t = preSprol.pitch == nextSprol.pitch ?
                        0 : (nPitch - preSprol.pitch) / (nextSprol.pitch - preSprol.pitch)
                    volm = Double.linear(preSprol.noisedVolm, nextSprol.noisedVolm, t: t)
                }
                let amp = Volm.amp(fromVolm: isLoudness ? volm * Loudness.volm40Phon(fromFq: nfq) : volm)
                if amp.isNaN {
                    print(volm, nfq, nPitch)
                }
                return amp * sqfas[fqi]
            }
        }
        func spectrum(fromNoise sprols: [Sprol], fq: Double, isLoudness: Bool) -> [Double] {
            var i = 1
            return (0 ..< halfStftCount).map { fqi in
                guard fqi != 0 else { return 0 }
                let nfq = Double(fqi) / Double(halfStftCount) * maxFq
                guard nfq > 0 && nfq >= fq && nfq < cutFq else { return 0 }
                let nPitch = Pitch.pitch(fromFq: nfq)
                while i + 1 < sprols.count, nPitch > sprols[i].pitch { i += 1 }
                let volm: Double
                if let lastSprol = sprols.last, nPitch >= lastSprol.pitch {
                    volm = lastSprol.noiseVolm
                } else {
                    let preSprol = sprols[i - 1], nextSprol = sprols[i]
                    let t = preSprol.pitch == nextSprol.pitch ?
                        0 : (nPitch - preSprol.pitch) / (nextSprol.pitch - preSprol.pitch)
                    volm = Double.linear(preSprol.noiseVolm, nextSprol.noiseVolm, t: t)
                }
                let amp = Volm.amp(fromVolm: isLoudness ? volm * Loudness.volm40Phon(fromFq: nfq) : volm)
                return amp * sqfas[fqi]
            }
        }
        func clippedStft(_ samples: [Double]) -> [Double] {
            .init(samples[halfStftCount ..< samples.count - halfStftCount])
        }
        
        func normarizedWithRMS(from sSamples: [Double], to lSamples: [Double]) -> [Double] {
            guard rmsSize < sSamples.count else {
                let maxV = vDSP.rootMeanSquare(sSamples)
                return vDSP.multiply(maxV == 0 ? 0 : 1 / maxV, lSamples)
            }
            
            let isLast = sSamples.count % rmsSize != 0
            let count = sSamples.count / rmsSize + (isLast ? 1 : 0)
            var rmss = [Double](capacity: count), idxs = [Double](capacity: count)
            for i in stride(from: rmsSize, to: sSamples.count, by: rmsSize) {
                let rms = vDSP.rootMeanSquare(sSamples[(i - rmsSize) ..< i])
                rmss.append(rms == 0 ? 0 : 1 / rms)
                idxs.append(.init(i))
            }
            if isLast {
                rmss.append(rmss.last!)
            } else {
                let rms = vDSP.rootMeanSquare(sSamples[(sSamples.count - rmsSize) ..< sSamples.count])
                rmss.append(rms == 0 ? 0 : 1 / rms)
            }
            idxs.append(.init(sSamples.count - 1))
            
            let nCount = Int(idxs.last!) + 1
            let result = [Double](unsafeUninitializedCapacity: nCount) { buffer, initializedCount in
                vDSP.linearInterpolate(values: rmss, atIndices: idxs, result: &buffer)
                initializedCount = nCount
            }
            return vDSP.multiply(lSamples, result)
        }
        
        if !isStft {
            var sSamples: [Double], lSamples: [Double]
            if isFullNoise {
                sSamples = .init(repeating: 0, count: sampleCount)
                lSamples = .init(repeating: 0, count: sampleCount)
            } else {
                func samples(isLoudness: Bool) -> [Double] {
                    let halfFftCount = fftCount / 2
                    var amps = [Double](repeating: 0, count: halfFftCount)
                    var phases = [Double](repeating: 0, count: halfFftCount)
                    
                    let ampRange = 1 ... Double(amps.count - 1)
                    let fd = Double(fftCount) / sampleRate
                    func enabledIndex(atFq fq: Double) -> Double? {
                        let ni = fq * fd
                        return fq < cutFq && ampRange.contains(ni) ? ni : nil
                    }
                    
                    let sqfa = fAlpha * 0.5
                    let overtone = pitbend.firstOvertone
                    let spectlope = pitbend.firstSpectlope
                    var intNFq = intFq, fqI = 1
                    if overtone.isAll {
                        while let ni = enabledIndex(atFq: intNFq) {
                            let nFq = intNFq * fqScale
                            let nii = Int(ni)
                            let volm = spectlope.noisedVolm(atFq: nFq)
                            let amp = Volm.amp(fromVolm: isLoudness ? volm * Loudness.volm40Phon(fromFq: nFq) : volm)
                            let nAmp = amp / (Double(fqI) ** sqfa)
                            amps[nii] = nAmp
                            phases[nii] = fqI % 2 == 1 ? 0 : .pi
                            intNFq += intFq
                            fqI += 1
                        }
                    } else {
                        while let ni = enabledIndex(atFq: intNFq) {
                            let nFq = intNFq * fqScale
                            let nii = Int(ni)
                            let overtoneVolm = overtone.volm(at: fqI)
                            let volm = spectlope.noisedVolm(atFq: nFq)
                            let amp = Volm.amp(fromVolm: volm * (isLoudness ? Loudness.volm40Phon(fromFq: nFq) : 1) * overtoneVolm)
                            let nAmp = amp / (Double(fqI) ** sqfa)
                            amps[nii] = nAmp
                            phases[nii] = fqI % 2 == 1 ? 0 : .pi
                            intNFq += intFq
                            fqI += 1
                        }
                    }
                    
                    let ifft = try! Ifft(count: fftCount)
                    var sSamples = ifft.resTransform(dc: 0, amps: amps, phases: phases)
                    if startDeltaSec != 0 {
                        sSamples = Array(sSamples.loop(fromLoop: Int(startDeltaSec * fqScale * sampleRate)))
                    }
                    return sSamples
                }
                
                sSamples = samples(isLoudness: false)
                lSamples = samples(isLoudness: true)
            }
            
            if containsNoise {
                func loopedSamples(from samples: [Double]) -> [Double] {
                    guard samples.count != sampleCount else { return samples }
                    let dCount = Double(samples.count)
                    var nSamples = [Double](capacity: sampleCount), phase = 0.0
                    for _ in sampleCount.range {
                        nSamples.append(spline(samples, phase: phase))
                        phase = (phase + fqScale).loop(start: 0, end: dCount)
                    }
                    return nSamples
                }
                sSamples = loopedSamples(from: sSamples)
                lSamples = loopedSamples(from: lSamples)
                
                let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount, seed: noiseSeed)
                let sSpectrum = spectrum(fromNoise: pitbend.firstSpectlope.sprols, 
                                         fq: fq, isLoudness: false)
                let lSpectrum = spectrum(fromNoise: pitbend.firstSpectlope.sprols,
                                         fq: fq, isLoudness: true)
                let sNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrum: sSpectrum))
                let lNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrum: lSpectrum))
                vDSP.add(sSamples, sNoiseSamples, result: &sSamples)
                vDSP.add(lSamples, lNoiseSamples, result: &lSamples)
                
                sSamples = normarizedWithRMS(from: sSamples, to: lSamples)
                
                let stereos = stereos(sampleCount: sSamples.count)
                return .init(fqScale: 1, isLoop: isLoop, samples: sSamples, stereos: stereos)
            } else {
                sSamples = normarizedWithRMS(from: sSamples, to: lSamples)
                
                let stereos = stereos(sampleCount: sSamples.count)
                return .init(fqScale: fqScale, isLoop: isLoop, samples: sSamples, stereos: stereos)
            }
        } else {
            var sSamples: [Double], lSamples: [Double]
            if isFullNoise {
                sSamples = .init(repeating: 0, count: sampleCount)
                lSamples = .init(repeating: 0, count: sampleCount)
            } else {
                let halfFftCount = fftCount / 2
                var amps = [Double](repeating: 0, count: halfFftCount)
                var phases = [Double](repeating: 0, count: halfFftCount)
                
                let ampRange = 1 ... Double(amps.count - 1)
                let fd = Double(fftCount) / sampleRate
                func enabledIndex(atFq fq: Double) -> Double? {
                    let ni = fq * fd
                    return fq < cutFq && ampRange.contains(ni) ? ni : nil
                }
                
                let overtone = pitbend.firstOvertone//!isEqualAllOvertone
                
                var nfq = intFq, fqI = 1
                if overtone.isAll {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        amps[nii] = fqI > 0 ? 1 : 0
                        phases[nii] = fqI % 2 == 1 ? 0 : .pi
                        
                        nfq += intFq
                        fqI += 1
                    }
                } else {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        amps[nii] = fqI > 0 ? Volm.amp(fromVolm: overtone.volm(at: fqI)) : 0
                        phases[nii] = fqI % 2 == 1 ? 0 : .pi
                        
                        nfq += intFq
                        fqI += 1
                    }
                }
                
                let ifft = try! Ifft(count: fftCount)
                var aSamples = ifft.resTransform(dc: 0, amps: amps, phases: phases)
                if startDeltaSec != 0 {
                    aSamples = Array(aSamples.loop(fromLoop: Int(startDeltaSec * fqScale * sampleRate)))
                }
                
                let rSampleRate = 1 / sampleRate
                let dCount = Double(aSamples.count)
                
                var phase = 0.0, nSamples = [Double](capacity: sampleCount)
                for i in sampleCount.range {
                    nSamples.append(spline(aSamples, phase: phase))
                    let sec = Double(i) * rSampleRate
                    phase += pitbend.fqScale(atSec: sec) * fqScale
                    phase = phase.loop(start: 0, end: dCount)
                }
                aSamples = nSamples
                
                let spectrumCount = vDSP.spectramCount(sampleCount: aSamples.count, fftCount: stftCount)
                let rDurSp = rendableDurSec / Double(spectrumCount)
                let sSpectrogram = spectrumCount.range.map { i in
                    let sec = Double(i) * rDurSp
                    let spectlope = pitbend.spectlope(atSec: sec)
                    let fq = fq * pitbend.fqScale(atSec: sec)
                    return spectrum(from: spectlope.sprols, fq: fq, isLoudness: false)
                }
                let lSpectrogram = spectrumCount.range.map { i in
                    let sec = Double(i) * rDurSp
                    let spectlope = pitbend.spectlope(atSec: sec)
                    let fq = fq * pitbend.fqScale(atSec: sec)
                    return spectrum(from: spectlope.sprols, fq: fq, isLoudness: true)
                }
                sSamples = vDSP.apply(aSamples, spectrogram: sSpectrogram)
                lSamples = vDSP.apply(aSamples, spectrogram: lSpectrogram)
                
//                func multiSin(_ x: Double, count: Int) -> Double {
//                    0//
//                }
//                
//                let a = 2 * .pi * rSampleRate, sqrt2 = Double.sqrt(2)
//                var phase = startDeltaSec
//                let aSamples: [Double] = sampleCount.range.map {
//                    let sec = Double($0) * rSampleRate
//                    let fq = fq * pitbend.fqScale(atSec: sec)
//                    guard fq < cutFq else { return 0 }
//                    let sinCount = Int((cutFq / fq).clipped(min: 1, max: Double(Int.max)))
////                    pitbend.fqScaleAndOvertone(atSec: <#T##Double#>)
//                    let v = multiSin(phase, count: sinCount)
//                    phase += fq * a
//                    return v
//                }
//                
//                let spectrumCount = vDSP.spectramCount(sampleCount: aSamples.count, fftCount: stftCount)
//                let rDurSp = rendableDurSec / Double(spectrumCount)
//                let sSpectrogram = spectrumCount.range.map { i in
//                    let sec = Double(i) * rDurSp
//                    let spectlope = pitbend.spectlope(atSec: sec)
//                    return spectrum(from: spectlope.sprols, isLoudness: false)
//                }
//                let lSpectrogram = spectrumCount.range.map { i in
//                    let sec = Double(i) * rDurSp
//                    let spectlope = pitbend.spectlope(atSec: sec)
//                    return spectrum(from: spectlope.sprols, isLoudness: true)
//                }
//                sSamples = clippedStft(vDSP.apply(aSamples, spectrogram: sSpectrogram))
//                lSamples = clippedStft(vDSP.apply(aSamples, spectrogram: lSpectrogram))
            }
            
            if containsNoise {
                let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount, seed: noiseSeed)
                
                let spectrumCount = vDSP.spectramCount(sampleCount: noiseSamples.count, fftCount: stftCount)
                let rDurSp = rendableDurSec / Double(spectrumCount)
                let sSpectrogram = spectrumCount.range.map { i in
                    let sec = Double(i) * rDurSp
                    let spectlope = pitbend.spectlope(atSec: sec)
                    let fq = fq * pitbend.fqScale(atSec: sec)
                    return spectrum(fromNoise: spectlope.sprols, fq: fq, isLoudness: false)
                }
                let lSpectrogram = spectrumCount.range.map { i in
                    let sec = Double(i) * rDurSp
                    let spectlope = pitbend.spectlope(atSec: sec)
                    let fq = fq * pitbend.fqScale(atSec: sec)
                    return spectrum(fromNoise: spectlope.sprols, fq: fq, isLoudness: true)
                }
                let sNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrogram: sSpectrogram))
                let lNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrogram: lSpectrogram))
                
                vDSP.add(sSamples, sNoiseSamples, result: &sSamples)
                vDSP.add(lSamples, lNoiseSamples, result: &lSamples)
            }
            
            sSamples = normarizedWithRMS(from: sSamples, to: lSamples)
            let stereos = stereos(sampleCount: sSamples.count)
            return .init(fqScale: 1, isLoop: isLoop, samples: sSamples, stereos: stereos)
        }
    }
}
extension vDSP {
    static func spectramCount(sampleCount: Int,
                              fftCount: Int,
                              windowOverlap: Double = 0.75) -> Int {
        sampleCount / Int(Double(fftCount) * (1 - windowOverlap)) + 1
    }
    static func apply(_ vs: [Double], spectrum: [Double]) -> [Double] {
        let spectrumCount = vDSP.spectramCount(sampleCount: vs.count,
                                               fftCount: spectrum.count)
        return apply(vs, spectrogram: .init(repeating: spectrum,
                                       count: spectrumCount))
    }
    static func apply(_ samples: [Double], spectrogram: [[Double]],
                      windowOverlap: Double = 0.75) -> [Double] {
        let halfWindowSize = spectrogram[0].count
        let windowSize = halfWindowSize * 2
        let dft = try! VDFT(previous: nil,
                            count: windowSize,
                            direction: .forward,
                            transformType: .complexComplex,
                            ofType: Double.self)
        let overlapSize = Int(Double(windowSize) * (1 - windowOverlap))
        let windowWave = vDSP.window(ofType: Double.self,
                                     usingSequence: .hanningNormalized,
                                     count: windowSize,
                                     isHalfWindow: false)
        let acf = Double(windowSize) / windowWave.sum()
        let inputIms = [Double](repeating: 0, count: windowSize)
        let frameCount = samples.count
        struct Frame {
            var amps = [Double]()
            var thetas = [Double]()
        }
        var frames = [Frame](capacity: frameCount / overlapSize + 1)
        for i in stride(from: 0, to: frameCount, by: overlapSize) {
            let doi = i - windowSize / 2
            let wave = (doi ..< doi + windowSize).map {
                $0 >= 0 && $0 < frameCount ? samples[$0] : 0
            }
            
            let inputRes = vDSP.multiply(windowWave, wave)
            var (outputRes, outputIms) = dft.transform(real: inputRes,
                                                     imaginary: inputIms)
            vDSP.multiply(0.5, outputRes, result: &outputRes)
            vDSP.multiply(0.5, outputIms, result: &outputIms)
            
            let amps = (0 ..< halfWindowSize).map {
                Double.hypot(outputRes[$0] / 2, outputIms[$0] / 2)
            }
            let thetas = (0 ..< halfWindowSize).map {
                Double.atan2(y: outputIms[$0], x: outputRes[$0])
            }
            frames.append(Frame(amps: amps, thetas: thetas))
        }
        
        for i in 0 ..< frames.count {
            vDSP.multiply(frames[i].amps, spectrogram[i],
                          result: &frames[i].amps)
        }
        
        let idft = try! VDFT(previous: nil,
                             count: windowSize,
                             direction: .inverse,
                             transformType: .complexComplex,
                             ofType: Double.self)
        
        var nSamples = [Double](repeating: 0, count: samples.count)
        for (j, i) in stride(from: 0, to: frameCount, by: overlapSize).enumerated() {
            let doi = i - windowSize / 2
            let frame = frames[j]
            var nInputRes = (0 ..< frame.amps.count).map {
                frame.amps[$0] * .cos(frame.thetas[$0])
            }
            var nInputIms = (0 ..< frame.amps.count).map {
                frame.amps[$0] * .sin(frame.thetas[$0])
            }
            nInputRes += [nInputRes.last!] + nInputRes[1...].reversed()
            nInputIms += [0] + nInputIms[1...].reversed().map { -$0 }
            
            var (wave, _) = idft.transform(real: nInputRes,
                                           imaginary: nInputIms)
            vDSP.multiply(acf / Double(windowSize), wave, result: &wave)
            
            for k in doi ..< doi + windowSize {
                if k >= 0 && k < frameCount {
                    nSamples[k] += wave[k - doi]
                }
            }
        }
        
        return nSamples
    }
}

struct Notewave {
    let fqScale: Double
    let isLoop: Bool
    let samples: [Double]
    let stereos: [Stereo]
}
extension Notewave {
    func sample(at i: Int, amp: Double, atPhase phase: inout Double) -> Double {
        guard samples.count >= 4 else { return 0 }
        let count = Double(samples.count)
        if !isLoop && phase >= count { return 0 }
        phase = phase.loop(start: 0, end: count)
        
        let n: Double
        if phase.isInteger {
            n = samples[Int(phase)] * amp
        } else {
            let sai = Int(phase)
            
            let a0 = sai - 1 >= 0 ?
                samples[sai - 1] :
                (isLoop ? samples[samples.count - 1] : 0)
            let a1 = samples[sai]
            let a2 = sai + 1 < samples.count ?
                samples[sai + 1] :
                (isLoop ? samples[0] : 0)
            let a3 = sai + 2 < samples.count ?
                samples[sai + 2] :
                (isLoop ? samples[1] : 0)
            let t = phase - Double(sai)
            let sy = Double.spline(a0, a1, a2, a3, t: t)
            n = sy * amp
        }
        
        phase += fqScale
        phase = !isLoop && phase >= count ? phase : phase.loop(start: 0, end: count)
        
        return n
    }
    
    func stereo(at i: Int, atPhase phase: inout Double) -> Stereo {
        guard stereos.count >= 4 else { return .init() }
        let count = Double(stereos.count)
        if !isLoop && phase >= count { return .init() }
        
        if phase.isInteger {
            return stereos[Int(phase)]
        } else {
            let sai = Int(phase)
            
            let s0 = stereos[sai]
            let s1 = sai + 1 < stereos.count ? stereos[sai + 1] : (isLoop ? stereos[0] : .init())
            let t = phase - Double(sai)
            return Stereo.linear(s0, s1, t: t)
        }
    }
}
