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
import struct Accelerate.DSPDoubleSplitComplex
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
            let cosV = Double.cos(.pi2 * t1)
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
        
        self.init(fq: Pitch.fq(fromPitch: .init(note.pitch)),
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
        if secRange.length.isInfinite {
            true
        } else if pitbend.isOne {
            false
        } else {
            false
//            !isStft && !pitbend.containsNoise
        }
    }
    var rendableDurSec: Double {
        isLoop ? 1 : envelopeMemo.duration(fromDurSec: min(secRange.length, 100000))
    }
}
extension Rendnote {
    func notewave(stftCount: Int = 1024, fAlpha: Double = 1, rmsSize: Int = 2048,
                  cutFq: Double = 16384, cutStartFq: Double = 15800, sampleRate: Double,
                  fftCount: Int = 65536) -> Notewave {
        let date = Date()
        
        let notewave = aNotewave(stftCount: stftCount, fAlpha: fAlpha, rmsSize: rmsSize,
                                 cutFq: cutFq, 
                                 cutStartFq: cutStartFq, sampleRate: sampleRate, fftCount: fftCount)
        
//        print(Date().timeIntervalSince(date), fq, notewave.isLoop, notewave.samples.count)
        
        if notewave.samples.contains(where: { $0.isNaN || $0.isInfinite }) {
            print(notewave.samples.contains(where: { $0.isInfinite }) ? "inf" : "nan")
        }
        
        return notewave
    }
    private func aNotewave(stftCount: Int, fAlpha: Double, rmsSize: Int,
                           cutFq: Double, cutStartFq: Double, sampleRate: Double,
                           fftCount: Int) -> Notewave {
        guard !pitbend.isEmpty else {
            return .init(fqScale: 1, isLoop: isLoop, samples: [0], stereos: [.init()])
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
        
        let stereoScale = Volm.volm(fromAmp: 1 / 2.0.squareRoot())
        func stereos(sampleCount: Int) -> [Stereo] {
            pitbend.isEqualAllStereo ?
            [pitbend.firstStereo.multiply(volm: stereoScale)] :
            sampleCount.range.map { pitbend.stereo(atSec: Double($0) * rSampleRate).multiply(volm: stereoScale) }
        }
        
        let fq = fq.clipped(min: Score.minFq, max: cutFq)
        let intFq = fq.rounded(.down)
        let fqScale = fq / intFq
        
        let rSampleRate = 1 / sampleRate
        func firstPhase() -> Double {
            guard startDeltaSec > 0 else { return 0 }
            if pitbend.isEqualAllPitch {
                return (startDeltaSec * (isLoop ? intFq : fq) * .pi2).mod(.pi2)
            } else {
                let pi2rs = .pi2 * rSampleRate
                var phase = 0.0
                for i in sampleCount.range {
                    let sec = Double(i) * rSampleRate
                    guard sec < startDeltaSec else { break }
                    let fq = (fq * pitbend.fqScale(atSec: sec)).clipped(min: Score.minFq, max: cutFq)
                    phase += fq * pi2rs
                }
                return phase.mod(.pi2)
            }
        }
        
        let isOneSin = pitbend.isOne
        if isOneSin {
            if pitbend.isEqualAllPitch {
                let a = (isLoop ? intFq : fq) * .pi2 * rSampleRate, firstPhase = firstPhase()
                var samples = sampleCount.range.map { Double.sin(Double($0) * a + firstPhase) }
                let amp = Volm.amp(fromVolm: Loudness.reverseVolm40Phon(fromFq: fq))
                let rScale = Double.sqrt(2) / amp
                vDSP.multiply(rScale, samples, result: &samples)
                
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: isLoop ? fqScale : 1, isLoop: isLoop, samples: samples, stereos: stereos)
            } else {
                let pi2rs = .pi2 * rSampleRate, sqrt2 = Double.sqrt(2)
                var phase = firstPhase()
                let samples = sampleCount.range.map {
                    let sec = Double($0) * rSampleRate
                    let fq = (fq * pitbend.fqScale(atSec: sec)).clipped(min: Score.minFq, max: cutFq)
                    let amp = Volm.amp(fromVolm: Loudness.reverseVolm40Phon(fromFq: fq))
                    let rScale = sqrt2 / amp
                    let v = rScale * Double.sin(phase)
                    phase += fq * pi2rs
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
        
//        func spline(_ samples: [Double], phase: Double) -> Double {// change to sinc
//            if phase.isInteger {
//                return samples[Int(phase)]
//            } else {
//                let sai = Int(phase)
//                
//                let a0 = sai - 1 >= 0 ? samples[sai - 1] : 0
//                let a1 = samples[sai]
//                let a2 = sai + 1 < samples.count ? samples[sai + 1] : 0
//                let a3 = sai + 2 < samples.count ? samples[sai + 2] : 0
//                let t = phase - Double(sai)
//                return Double.spline(a0, a1, a2, a3, t: t)
//            }
//        }
        
//        func spectrum(from sprols: [Sprol], isLoudness: Bool) -> [Double] {
//            var i = 1
//            return (1 ... halfStftCount).map { fqi in
//                let nfq = Double(fqi) / Double(halfStftCount) * maxFq
//                guard nfq > 0 && nfq < cutFq else { return 0 }
//                let nPitch = Pitch.pitch(fromFq: nfq)
//                while i + 1 < sprols.count, nPitch > sprols[i].pitch { i += 1 }
//                let volm: Double
//                if let lastSprol = sprols.last, nPitch >= lastSprol.pitch {
//                    volm = lastSprol.noisedVolm
//                } else {
//                    let preSprol = sprols[i - 1], nextSprol = sprols[i]
//                    let t = preSprol.pitch == nextSprol.pitch ?
//                        0 : (nPitch - preSprol.pitch) / (nextSprol.pitch - preSprol.pitch)
//                    volm = Double.linear(preSprol.noisedVolm, nextSprol.noisedVolm, t: t)
//                }
//                let cutScale = cutStartFq < nfq ? nfq.clipped(min: cutStartFq, max: cutFq, newMin: 1, newMax: 0) : 1
//                let amp = Volm.amp(fromVolm: (isLoudness ? volm * Loudness.reverseVolm40Phon(fromFq: nfq) : volm) * cutScale)
//                return amp * sqfas[fqi]
//            }
//        }
        func aNoiseSpectrum(fromNoise spectlope: Spectlope, fq: Double,
                            oddScale: Double, evenScale: Double) -> (spectrum: [Double], rms: Double) {
            var rmsV = 0.0, sign = true
            return ((1 ... halfStftCount).map { fqi in
                let nfq = Double(fqi) / Double(halfStftCount) * maxFq
                guard nfq > 0 && nfq >= fq && nfq < cutFq else { return 0 }
                let loudnessVolm = Loudness.volm40Phon(fromFq: nfq)
                let noiseVolm = spectlope.sprol(atFq: nfq).noiseVolm
                let cutScale = cutStartFq < nfq ? nfq.clipped(min: cutStartFq, max: cutFq, newMin: 1, newMax: 0) : 1
                let overtoneScale = sign ? oddScale : evenScale
                let a = sqfas[fqi] * cutScale * overtoneScale
                let amp = Volm.amp(fromVolm: loudnessVolm * noiseVolm) * a
                rmsV += (Volm.amp(fromVolm: noiseVolm) * a).squared
                sign = !sign
                return amp
            }, (rmsV / 2).squareRoot())
        }
        func clippedStft(_ samples: [Double]) -> [Double] {
            .init(samples[halfStftCount ..< samples.count - halfStftCount])
        }
        
        if !isStft {
            let overtone = pitbend.firstOvertone
            let isAll = overtone.isAll,
                oddScale = Volm.amp(fromVolm: overtone.oddVolm),
                evenScale = -Volm.amp(fromVolm: overtone.evenVolm)
            if isFullNoise {
                let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount, seed: noiseSeed)
                let (noiseSpectrum, sumSpectrum) = aNoiseSpectrum(fromNoise: pitbend.firstSpectlope, 
                                                                  fq: fq,
                                                                  oddScale: oddScale,
                                                                  evenScale: -evenScale)
                let nNoiseSpectrum = vDSP.multiply(sumSpectrum == 0 ? 0 : 1 / sumSpectrum, noiseSpectrum)
                let samples = clippedStft(vDSP.apply(noiseSamples, spectrum: nNoiseSpectrum))
                
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: 1, isLoop: isLoop, samples: samples, stereos: stereos)
            } else {
                let sinCount = Int((cutFq / fq).clipped(min: 1, max: Double(Int.max)))
                let fq = fq.clipped(min: Score.minFq, max: cutFq)
                
//                    let dPhase = fq * .pi2 * rSampleRate
//                    var x = firstPhase()
//                    var sinMX = 0.0, cosMX = 0.0
//                    return sampleCount.range.map { _ in
//                        let sin1X = Double.sin(x), cos1X = Double.cos(x)
//                        sinMX = sin1X
//                        cosMX = cos1X
//                        var v = vs[0] * sin1X
//                        if sinCount >= 2 {
//                            for n in 2 ... sinCount {
//                                let m = n - 1
//                                let sinNX = sinMX * cos1X + cosMX * sin1X
//                                let cosNX = cosMX * cos1X - sinMX * sin1X
//                                sinMX = sinNX
//                                cosMX = cosNX
//                                v += vs[m] * sinNX
//                            }
//                        }
//                        x += dPhase
//                        x = x.mod(.pi2)
//                        return v
//                    }
                let dPhase = fq * .pi2 * rSampleRate
                var x = firstPhase()
                var sin1Xs = [Double](capacity: sampleCount)
                var cos1Xs = [Double](capacity: sampleCount)
                var sinMXs = [Double](capacity: sampleCount)
                var cosMXs = [Double](capacity: sampleCount)
                sampleCount.range.forEach { _ in
                    let sin1X = Double.sin(x), cos1X = Double.cos(x)
                    sin1Xs.append(sin1X)
                    cos1Xs.append(cos1X)
                    sinMXs.append(sin1X)
                    cosMXs.append(cos1X)
                    x += dPhase
                    x = x.mod(.pi2)
                }
                var sinNXss = [[Double]](capacity: sinCount)
                sinNXss.append(sin1Xs)
                var sinNXs = [Double](repeating: 0, count: sampleCount)
                var sinNXs1 = [Double](repeating: 0, count: sampleCount)
                var cosNXs = [Double](repeating: 0, count: sampleCount)
                var cosNXs1 = [Double](repeating: 0, count: sampleCount)
                if sinCount >= 2 {
                    for _ in 2 ... sinCount {
                        vDSP.multiply(sinMXs, cos1Xs, result: &sinNXs)
                        vDSP.multiply(cosMXs, sin1Xs, result: &sinNXs1)
                        
                        vDSP.multiply(cosMXs, cos1Xs, result: &cosNXs)
                        vDSP.multiply(sinMXs, sin1Xs, result: &cosNXs1)
                        
                        vDSP.add(sinNXs, sinNXs1, result: &sinMXs)
                        vDSP.subtract(cosNXs, cosNXs1, result: &cosMXs)
                        sinNXss.append(sinMXs)
                    }
                }
                
                let spectlope = pitbend.firstSpectlope
                var sign = true, rmsV = 0.0
                let spectrum = (1 ... sinCount).map { n in
                    let nFq = fq * Double(n)
                    let loudnessVolm = Loudness.volm40Phon(fromFq: nFq)
                    
                    let spectlopeVolm = spectlope.noisedVolm(atFq: nFq)
                    nFq - fq / 2 ... nFq + fq / 2
                    
                    let cutScale = nFq.clipped(min: cutStartFq, max: cutFq, newMin: 1, newMax: 0)
                    let overtoneScale = isAll || n == 1 ? (sign ? 1 : -1) : (sign ? oddScale : evenScale)
                    let sqfa = Double(n) ** sqfa
                    let a = overtoneScale / sqfa * cutScale
                    let amp = Volm.amp(fromVolm: loudnessVolm * spectlopeVolm) * a
                    rmsV += (Volm.amp(fromVolm: spectlopeVolm) * a).squared
                    sign = !sign
                    return amp
                }
                let sumSpectrum = (rmsV / 2).squareRoot()
                
                let allSumSpectrum: Double, noiseSpectrum: [Double]?
                if containsNoise {
                    let (aNoiseSpectrum, noiseSumSpectrum) = aNoiseSpectrum(fromNoise: spectlope,
                                                                            fq: fq,
                                                                            oddScale: oddScale,
                                                                            evenScale: -evenScale)
                    allSumSpectrum = sumSpectrum + noiseSumSpectrum
                    noiseSpectrum = aNoiseSpectrum
                } else {
                    noiseSpectrum = nil
                    allSumSpectrum = sumSpectrum
                }
                
                let spectrumScale = allSumSpectrum == 0 ? 0 : 1 / allSumSpectrum
                let nSpectrum = vDSP.multiply(spectrumScale, spectrum)
                
                var samples = [Double](repeating: 0, count: sampleCount)
                for (n, sinNXs) in sinNXss.enumerated() {
                    vDSP.multiply(nSpectrum[n], sinNXs, result: &sinNXs1)
                    vDSP.add(sinNXs1, samples, result: &samples)
                }
                
//                    let halfFftCount = fftCount / 2
//                    var amps = [Double](repeating: 0, count: halfFftCount)
//                    var phases = [Double](repeating: 0, count: halfFftCount)
//                    
//                    let ampRange = 1 ... Double(amps.count - 2)
//                    let fd = Double(fftCount) / sampleRate
//                    func enabledIndex(atFq fq: Double) -> Double? {
//                        let ni = fq * fd
//                        return fq < cutFq && ampRange.contains(ni) ? ni : nil
//                    }
//                    
//                    let sqfa = fAlpha * 0.5
//                    let overtone = pitbend.firstOvertone
//                    let spectlope = pitbend.firstSpectlope
//                    var intNFq = intFq, fqI = 1
//                    if overtone.isAll {
//                        while let ni = enabledIndex(atFq: intNFq) {
//                            let nFq = intNFq * fqScale
//                            let nii = Int(ni) - 1
//                            let volm = spectlope.noisedVolm(atFq: nFq)
//                            let amp = Volm.amp(fromVolm: isLoudness ? volm * Loudness.volm40Phon(fromFq: nFq) : volm)
//                            let nAmp = amp / (Double(fqI) ** sqfa)
//                            amps[nii] = nAmp
//                            phases[nii] = fqI % 2 == 1 ? 0 : .pi
//                            intNFq += intFq
//                            fqI += 1
//                        }
//                    } else {
//                        while let ni = enabledIndex(atFq: intNFq) {
//                            let nFq = intNFq * fqScale
//                            let nii = Int(ni) - 1
//                            let overtoneVolm = overtone.volm(at: fqI)
//                            let volm = spectlope.noisedVolm(atFq: nFq)
//                            let amp = Volm.amp(fromVolm: volm * (isLoudness ? Loudness.volm40Phon(fromFq: nFq) : 1) * overtoneVolm)
//                            let nAmp = amp / (Double(fqI) ** sqfa)
//                            amps[nii] = nAmp
//                            phases[nii] = fqI % 2 == 1 ? 0 : .pi
//                            intNFq += intFq
//                            fqI += 1
//                        }
//                    }
//                    
//                    let ifft = try! Ifft(count: fftCount)
//                    var sSamples = ifft.resTransform(dc: 0, amps: amps, phases: phases)
//                    if startDeltaSec != 0 {
//                        sSamples = Array(sSamples.loop(fromLoop: Int(startDeltaSec * fqScale * sampleRate)))
//                    }
//                    return sSamples
//                }
                
                if let noiseSpectrum {
    //                func loopedSamples(from samples: [Double]) -> [Double] {
    //                    guard samples.count != sampleCount else { return samples }
    //                    let dCount = Double(samples.count)
    //                    var nSamples = [Double](capacity: sampleCount), phase = 0.0
    //                    for _ in sampleCount.range {
    //                        nSamples.append(spline(samples, phase: phase))
    //                        phase = (phase + fqScale).loop(start: 0, end: dCount)
    //                    }
    //                    return nSamples
    //                }
    //                sSamples = loopedSamples(from: sSamples)
    //                lSamples = loopedSamples(from: lSamples)
                    
                    let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount, seed: noiseSeed)
                    let nNoiseSpectrum = vDSP.multiply(spectrumScale, noiseSpectrum)
                    let nNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrum: nNoiseSpectrum))
                    vDSP.add(samples, nNoiseSamples, result: &samples)
                    
                    let stereos = stereos(sampleCount: samples.count)
                    return .init(fqScale: 1, isLoop: isLoop, samples: samples, stereos: stereos)
                } else {
                    let stereos = stereos(sampleCount: samples.count)
                    return .init(fqScale: 1, isLoop: isLoop, samples: samples, stereos: stereos)
    //                return .init(fqScale: fqScale, isLoop: isLoop, samples: sSamples, stereos: stereos)
                }
            }
        } else {
            if isFullNoise {
                let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount, seed: noiseSeed)
                
                let overlapSamplesCount = vDSP.overlapSamplesCount(fftCount: stftCount)
                let noiseSpectrogram = stride(from: 0, to: sampleCount, by: overlapSamplesCount).map { i in
                    let sec = Double(i) * rSampleRate
                    let spectlope = pitbend.spectlope(atSec: sec)
                    let fq = fq * pitbend.fqScale(atSec: sec)
                    let overtone = pitbend.overtone(atSec: sec)
                    let oddScale = overtone.isAll ? 1 : Volm.amp(fromVolm: overtone.oddVolm)
                    let evenScale = overtone.isAll ? -1 : -Volm.amp(fromVolm: overtone.evenVolm)
                    let (noiseSpectrum, sumSpectrum) = aNoiseSpectrum(fromNoise: spectlope, fq: fq,
                                                                      oddScale: oddScale,
                                                                      evenScale: -evenScale)
                    return vDSP.multiply(sumSpectrum == 0 ? 0 : 1 / sumSpectrum, noiseSpectrum)
                }
                
                let samples = clippedStft(vDSP.apply(noiseSamples, spectrogram: noiseSpectrogram))
                
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: 1, isLoop: isLoop, samples: samples, stereos: stereos)
            } else {
                struct Frame {
                    var sec: Double, fq: Double, sinCount: Int, sin1X: Double, cos1X: Double
                }
                let pi2rs = .pi2 * rSampleRate
                var x = firstPhase()
                let frames: [Frame] = sampleCount.range.map { i in
                    let sec = Double(i) * rSampleRate
                    let fq = (fq * pitbend.fqScale(atSec: sec)).clipped(min: Score.minFq, max: cutFq)
                    let sinCount = Int((cutFq / fq).clipped(min: 1, max: Double(Int.max)))
                    let sin1X = Double.sin(x), cos1X = Double.cos(x)
                    x += fq * pi2rs
                    x = x.mod(.pi2)
                    return Frame(sec: sec, fq: fq, sinCount: sinCount, sin1X: sin1X, cos1X: cos1X)
                }
                
                let sinss: [[Double]] = frames.enumerated().map { (i, v) in
                    let sinCount = v.sinCount, sin1X = v.sin1X, cos1X = v.cos1X
                    var sinMX = sin1X, cosMX = cos1X
                    var sins = [Double](capacity: sinCount)
                    sins.append(sin1X)
                    if sinCount >= 2 {
                        for _ in 2 ... sinCount {
                            let sinNX = sinMX * cos1X + cosMX * sin1X
                            let cosNX = cosMX * cos1X - sinMX * sin1X
                            sinMX = sinNX
                            cosMX = cosNX
                            sins.append(sinNX)
                        }
                    }
                    return sins
                }
                
                let intCutStartFq = Int(cutStartFq.rounded(.down))
                let cutScales = (intCutStartFq ..< Int(cutFq.rounded(.down))).map {
                    Double($0).clipped(min: cutStartFq, max: cutFq, newMin: 1, newMax: 0)
                }
                let overlapSamplesCount = vDSP.overlapSamplesCount(fftCount: stftCount)
                
                let firstOvertone = pitbend.firstOvertone
                let isEqualAllOvertone = pitbend.isEqualAllOvertone,
                    isAll = firstOvertone.isAll,
                    oddScale = Volm.amp(fromVolm: firstOvertone.oddVolm),
                    evenScale = -Volm.amp(fromVolm: firstOvertone.evenVolm)
                var oddScales = [Double](capacity: sampleCount)
                var evenScales = [Double](capacity: sampleCount)
                for i in sampleCount.range {
                    let sec = Double(i) * rSampleRate
                    let overtone = pitbend.overtone(atSec: sec)
                    oddScales.append(Volm.amp(fromVolm: overtone.oddVolm))
                    evenScales.append(-Volm.amp(fromVolm: overtone.evenVolm))
                }
                
                let maxSinCount = frames.maxValue { $0.sinCount }!
                let rsqfas = [0] + (1 ... maxSinCount).map { n in 1 / Double(n) ** sqfa }
                
                var spectrogram = Array(repeating: Array(repeating: 0.0, count: maxSinCount),
                                        count: sampleCount)
                var noiseSpectrogram = [[Double]](capacity: sampleCount / overlapSamplesCount)
                var preSpectrum: [Double]!
                func update(at i: Int) {
                    let frame = frames[i]
                    let sec = frame.sec
                    let spectlope = pitbend.spectlope(atSec: sec)
                    var sign = true, rmsV = 0.0
                    let spectrum = (1 ... maxSinCount).map { n in
                        let fq = frame.fq * Double(n)
                        let loudnessVolm = Loudness.volm40Phon(fromFq: fq)
                        
                        let spectlopeVolm = spectlope.noisedVolm(atFq: fq)
                        fq - frame.fq / 2 ... fq + frame.fq / 2
                        
                        let overtoneScale = isEqualAllOvertone ?
                        (isAll || n == 1 ? (sign ? 1 : -1) : (sign ? oddScale : evenScale)) :
                        (n == 1 ? 1 : (sign ? oddScales[i] : evenScales[i]))
                        sign = !sign
                        
                        let a = overtoneScale * rsqfas[n]
                        let amp = Volm.amp(fromVolm: loudnessVolm * spectlopeVolm) * a
                        rmsV += (Volm.amp(fromVolm: spectlopeVolm) * a * (fq > cutStartFq ? (fq < cutFq ? cutScales[Int(fq) - intCutStartFq] : 0) : 1)).squared
                        return amp
                    }
                    let sumSpectrum = (rmsV / 2).squareRoot()
                    
                    let oddScale = isEqualAllOvertone ? oddScale : oddScales[i]
                    let evenScale = isEqualAllOvertone ? evenScale : evenScales[i]
                    
                    let allSumSpectrum: Double, spectrumScale: Double
                    if containsNoise {
                        let noiseSpectlope = pitbend.spectlope(atSec: sec)
                        let (noiseSpectrum, noiseSumSpectrum) = aNoiseSpectrum(fromNoise: noiseSpectlope,
                                                                               fq: frame.fq,
                                                                               oddScale: oddScale,
                                                                               evenScale: -evenScale)
                        allSumSpectrum = sumSpectrum + noiseSumSpectrum
                        spectrumScale = allSumSpectrum == 0 ? 0 : 1 / allSumSpectrum
                        noiseSpectrogram.append(vDSP.multiply(spectrumScale, noiseSpectrum))
                    } else {
                        allSumSpectrum = sumSpectrum
                        spectrumScale = allSumSpectrum == 0 ? 0 : 1 / allSumSpectrum
                    }
                    
                    let nSpectrum = vDSP.multiply(spectrumScale, spectrum)
                    
                    maxSinCount.range.forEach { spectrogram[i][$0] = nSpectrum[$0] }
                    if i > 0 {
                        for j in i - overlapSamplesCount + 1 ..< i {
                            let t = Double(j - i + overlapSamplesCount) / Double(overlapSamplesCount)
                            for k in maxSinCount.range {
                                let fq = frames[j].fq * Double(k)
                                let amp = Double.linear(preSpectrum[k], nSpectrum[k], t: t)
                                spectrogram[j][k] = fq > cutStartFq ?
                                (fq < cutFq ? amp * cutScales[Int(fq) - intCutStartFq] : 0) : amp
                            }
                        }
                    }
                    preSpectrum = nSpectrum
                }
                for i in stride(from: 0, to: sampleCount, by: overlapSamplesCount) {
                    update(at: i)
                }
                if sampleCount % overlapSamplesCount != 0 {
                    update(at: sampleCount - 1)
                }
                
                for (i, v) in spectrogram.enumerated() {
                    if v.count > frames[i].sinCount {
                        spectrogram[i].removeLast(v.count - frames[i].sinCount)
                    }
                }
                
                var samples = zip(sinss, spectrogram).map { vDSP.sum(vDSP.multiply($0.0, $0.1)) }
                
//                let a = .pi2 * rSampleRate
//                var phase = firstPhase()
//                let samples = sampleCount.range.map { i in
//                    let sec = Double(i) * rSampleRate
//                    let fq = fq * pitbend.fqScale(atSec: sec)
//                    let sinCount = Int((cutFq / fq).clipped(min: 1, max: Double(Int.max)))
//                    let k = Double(sinCount)
//                    let x = phase
//                    let v: Double = .sin((k + 1) * (x + .pi) / 2) * .sin((k * x + .pi * (k + 2)) / 2) / .cos(x / 2)
//                    phase += fq * a
//                    phase = phase.mod(.pi2)
//                    return v
//                }
//                
//                let spectrumCount = vDSP.spectramCount(sampleCount: samples.count, fftCount: stftCount)
//                let rDurSp = rendableDurSec / Double(spectrumCount)
//                let spectrogram = spectrumCount.range.map { i in
//                    let sec = Double(i) * rDurSp
//                    let spectlope = pitbend.spectlope(atSec: sec)
//                    let fq = fq * pitbend.fqScale(atSec: sec)
//                    return spectrum(from: spectlope, fq: fq)
//                }
//                lSamples = vDSP.apply(samples, spectrogram: spectrogram)
                
                if containsNoise {
                    let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount, seed: noiseSeed)
                    let nNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrogram: noiseSpectrogram))
                    vDSP.add(samples, nNoiseSamples, result: &samples)
                }
                
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: 1, isLoop: isLoop, samples: samples, stereos: stereos)
            }
        }
    }
}
extension vDSP {
    static func overlapSamplesCount(fftCount: Int, windowOverlap: Double = 0.75) -> Int {
        Int(Double(fftCount) * (1 - windowOverlap))
    }
    static func spectrumCount(sampleCount: Int,
                              fftCount: Int,
                              windowOverlap: Double = 0.75) -> Int {
        sampleCount / overlapSamplesCount(fftCount: fftCount, windowOverlap: windowOverlap)
    }
    static func apply(_ vs: [Double], spectrum: [Double]) -> [Double] {
        let spectrumCount = vDSP.spectrumCount(sampleCount: vs.count,
                                               fftCount: spectrum.count)
        return apply(vs, spectrogram: .init(repeating: spectrum,
                                       count: spectrumCount))
    }
    static func apply(_ samples: [Double], spectrogram: [[Double]],
                      windowOverlap: Double = 0.75) -> [Double] {
        let halfFftCount = spectrogram[0].count
        let fftCount = halfFftCount * 2
        let fft = try! Fft(count: fftCount)
        let ifft = try! Ifft(count: fftCount)
        let windowSamples = vDSP.window(.hanningDenormalized, count: fftCount)
        
        let overlapSamplesCount = overlapSamplesCount(fftCount: fftCount, windowOverlap: windowOverlap)
        let sampleCount = samples.count - fftCount
        
        var frames = [FftFrame](capacity: sampleCount / overlapSamplesCount)
        for i in stride(from: halfFftCount, to: sampleCount + halfFftCount, by: overlapSamplesCount) {
            let ni = i - halfFftCount
            let samples = (ni ..< ni + fftCount).map {
                $0 >= 0 && $0 < sampleCount ? samples[$0] : 0
            }
            let inputRes = vDSP.multiply(windowSamples, samples)
            frames.append(fft.frame(inputRes))
        }
        
        for i in 0 ..< frames.count {
            frames[i].dc = 0
            vDSP.multiply(frames[i].amps, spectrogram[i], result: &frames[i].amps)
        }
        
        var nSamples = [Double](repeating: 0, count: samples.count)
        for (j, i) in stride(from: halfFftCount, to: sampleCount + halfFftCount, by: overlapSamplesCount).enumerated() {
            let frame = frames[j]
            var samples = ifft.resTransform(frame)
            samples = vDSP.multiply(windowSamples, samples)
            let ni = i - halfFftCount
            for k in ni ..< ni + fftCount {
                if k >= 0 && k < sampleCount {
                    nSamples[k] += samples[k - ni]
                }
            }
        }
        
        let acf = Double(fftCount) / vDSP.sum(windowSamples)
        vDSP.multiply(acf * acf, nSamples, result: &nSamples)
        
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
        let count = Double(samples.count)
        if !isLoop && phase >= count { return 0 }
        phase = phase.loop(start: 0, end: count)
        
        let n: Double
        if phase.isInteger {
            n = samples[Int(phase)] * amp
        } else {
            guard samples.count >= 4 else { return 0 }
            let sai = Int(phase)
            
            let a0 = sai - 1 >= 0 ? samples[sai - 1] : (isLoop ? samples[samples.count - 1] : 0)
            let a1 = samples[sai]
            let a2 = sai + 1 < samples.count ? samples[sai + 1] : (isLoop ? samples[0] : 0)
            let a3 = sai + 2 < samples.count ? samples[sai + 2] : (isLoop ? samples[1] : 0)
            let t = phase - Double(sai)
            let sy = Double.spline(a0, a1, a2, a3, t: t)
            n = sy * amp
        }
        
        phase += fqScale
        phase = !isLoop && phase >= count ? phase : phase.loop(start: 0, end: count)
        
        return n
    }
    
    func stereo(at i: Int, atPhase phase: inout Double) -> Stereo {
        let count = Double(stereos.count)
        if !isLoop && phase >= count { return .init() }
        
        if phase.isInteger {
            return stereos[Int(phase)]
        } else {
            guard stereos.count >= 2 else { return .init() }
            let sai = Int(phase)
            
            let s0 = stereos[sai]
            let s1 = sai + 1 < stereos.count ? stereos[sai + 1] : (isLoop ? stereos[0] : .init())
            let t = phase - Double(sai)
            return Stereo.linear(s0, s1, t: t)
        }
    }
}
