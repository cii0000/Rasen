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
//import struct Foundation.Date

typealias VDFT = vDSP.DiscreteFourierTransform

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
    let attackSec, decaySec, sustainSmp, releaseSec: Double
    let attackAndDecaySec: Double
    let rAttackSec, rDecaySec, rReleaseSec: Double
    
    init(_ envelope: Envelope) {
        attackSec = max(envelope.attackSec, 0)
        decaySec = max(envelope.decaySec, 0)
        sustainSmp = envelope.sustainSmp
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
    
    func smp(atSec sec: Double, releaseStartSec relaseStartSec: Double?) -> Double {
        if sec < 0 {
            return 0
        } else if attackSec > 0 && sec < attackSec {
            return sec * rAttackSec
        } else {
            let nSec = sec - attackSec
            if decaySec > 0 && nSec < decaySec {
                return .linear(1, sustainSmp, t: nSec * rDecaySec)
            } else if let relaseStartSec {
                let rsSec = relaseStartSec < attackAndDecaySec ? attackAndDecaySec : relaseStartSec
                if sec < rsSec {
                    return sustainSmp
                } else {
                    let nnSec = sec - rsSec
                    if releaseSec > 0 && nnSec < releaseSec {
                        return .linear(sustainSmp, 0, t: nnSec * rReleaseSec)
                    } else {
                        return 0
                    }
                }
            } else {
                return sustainSmp
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
    let interpolation: Interpolation<InterPit>
    var firstPitch: Double, firstStereo: Stereo, firstTone: Tone
    let isEqualAllPitch: Bool
    let isEqualAllTone: Bool
    let isEqualAllStereo: Bool
    let isEqualAllWithoutStereo: Bool
}
extension Pitbend {    
    var isEmpty: Bool {
        isEqualAllStereo && firstStereo.isEmpty
    }
    
    func pitch(atSec sec: Double) -> Double {
        isEqualAllPitch ? 0 : interpolation.monoValueEnabledFirstLast(withT: sec, isLoop: false)?.pitch ?? 0
    }
    func fqScale(atSec sec: Double) -> Double {
        isEqualAllPitch ? 1 : .exp2(pitch(atSec: sec))
    }
    func stereo(atSec sec: Double) -> Stereo {
        interpolation.monoValueEnabledFirstLast(withT: sec, isLoop: false)?.stereo ?? .init()
    }
    func tone(atSec sec: Double) -> Tone {
        isEqualAllTone ?
        (interpolation.keys.first?.value.tone ?? .init())
        : (interpolation.monoValueEnabledFirstLast(withT: sec, isLoop: false)?.tone ?? .init())
    }
    
    var isOne: Bool {
        interpolation.isEmpty ?
        firstTone.overtone.isOne :
        !interpolation.keys.contains(where: { !$0.value.tone.overtone.isOne })
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
    init(note: Note, score: Score, startSec: Double, snapBeatScale: Rational = .init(1, 4)) {
        let startBeat = note.beatRange.start
        let endBeat = note.beatRange.end
        let snapBeat = startBeat.interval(scale: snapBeatScale)
        let sSec = Double(score.sec(fromBeat: startBeat)) + startSec
        let eSec = Double(score.sec(fromBeat: endBeat)) + startSec
        let snapSec = Double(score.sec(fromBeat: snapBeat)) + startSec
        let dSec = sSec - snapSec
        
        self.init(fq: note.firstFq,
                  noiseSeed: note.containsNoise ? Rendnote.noiseSeed(from: note.id) : 0,
                  pitbend: note.pitbend(fromTempo: score.tempo),
                  secRange: sSec ..< eSec,
                  startDeltaSec: dSec,
                  envelopeMemo: .init(note.envelope))
    }
}
extension Rendnote {
    func notewave(fftSize: Int = 1024, fAlpha: Double = 1, 
                  cutFq: Double = 16384, sampleRate: Double = Audio.defaultSampleRate,
                  dftCount: Int = Audio.defaultDftCount) -> Notewave {
//        let date = Date()
        let scaledFq = fq.rounded(.down)
        let fqScale = fq / scaledFq
        
        guard !pitbend.isEmpty else {
            return .init(fqScale: 1, isLoop: true, samples: [0], stereos: [.init()])
        }
        
        func stereos(sampleCount: Int) -> [Stereo] {
            pitbend.isEqualAllStereo ?
            [pitbend.firstStereo] :
            sampleCount.range.map { pitbend.stereo(atSec: Double($0) * rSampleRate) }
        }
        
        let isStft = !pitbend.isEqualAllPitch || !pitbend.isEqualAllTone
        let isFullNoise = pitbend.interpolation.isEmpty ?
        pitbend.firstTone.spectlope.isFullNoise :
        !pitbend.interpolation.keys.contains(where: { !$0.value.tone.spectlope.isFullNoise })
        let isNoise = pitbend.interpolation.isEmpty ?
        pitbend.firstTone.spectlope.isNoise :
        !pitbend.interpolation.keys.contains(where: { !$0.value.tone.spectlope.isNoise })
        let isLoop = secRange.length.isInfinite || (!isStft && !isNoise)
        let durSec = secRange.length.isInfinite ? 1 : min(secRange.length, 100000)
        let releaseDur = self.envelopeMemo.duration(fromDurSec: durSec)
        let nCount = isLoop ? dftCount : Int((releaseDur * sampleRate).rounded(.up))
        guard nCount >= 4 else {
            return .init(fqScale: 1, isLoop: true, samples: [0], stereos: [.init()])
        }
        
        let rSampleRate = 1 / sampleRate
        let isOneSin = pitbend.isOne
        if isOneSin {
            let rrms = Double.sqrt(2)
            if pitbend.isEqualAllPitch {
                var samples = dftCount.range
                    .map { Double.sin(scaledFq * 2 * .pi * Double($0) * rSampleRate + startDeltaSec) }
                let scale = Volume.amp(fromSmp: Loudness.reverseScale40Phon(fromFq: fq))
                vDSP.multiply(scale * rrms, samples, result: &samples)
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: fqScale, isLoop: true, samples: samples, stereos: stereos)
            } else {
                let samples = nCount.range.map {
                    let sec = Double($0) * rSampleRate
                    let fq = fq * pitbend.fqScale(atSec: sec)
                    let scale = Volume.amp(fromSmp: Loudness.reverseScale40Phon(fromFq: fq))
                    return scale * rrms * Double.sin(fq * 2 * .pi * sec + startDeltaSec)
                }
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: 1, isLoop: true, samples: samples, stereos: stereos)
            }
        }
        
        let halfFFTSize = fftSize / 2
        let maxFq = sampleRate / 2
        let sqfa = fAlpha * 0.5
        let sqfas: [Double] = (0 ..< halfFFTSize).map {
            let nfq = Double($0) / Double(halfFFTSize) * maxFq
            return nfq == 0 ? 1 : 1 / (nfq / fq) ** sqfa
        }
        
        func spectrum(from sprols: [Sprol]) -> [Double] {
            var i = 1
            return (0 ..< halfFFTSize).map { fqi in
                let nfq = Double(fqi) / Double(halfFFTSize) * maxFq
                guard nfq >= scaledFq else { return 0 }
                let nPitch = Pitch.pitch(fromFq: nfq)
                while i + 1 < sprols.count, nPitch > sprols[i].pitch { i += 1 }
                let smp: Double
                if let lastSprol = sprols.last, nPitch >= lastSprol.pitch {
                    smp = lastSprol.smp
                } else {
                    let preSprol = sprols[i - 1], sprol = sprols[i]
                    let t = preSprol.pitch == sprol.pitch ?
                        0 : (nPitch - preSprol.pitch) / (sprol.pitch - preSprol.pitch)
                    smp = Double.linear(preSprol.smp, sprol.smp, t: t)
                }
                let amp = Volume.amp(fromSmp: smp)
                let alpha = sqfas[fqi]
                return amp * alpha
            }
        }
        func spectrum(fromNoise sprols: [Sprol]) -> [Double] {
            var i = 1
            return (0 ..< halfFFTSize).map { fqi in
                let nfq = Double(fqi) / Double(halfFFTSize) * maxFq
                guard nfq >= scaledFq else { return 0 }
                let nPitch = Pitch.pitch(fromFq: nfq)
                while i + 1 < sprols.count, nPitch > sprols[i].pitch { i += 1 }
                let smp: Double
                if let lastSprol = sprols.last, nPitch >= lastSprol.pitch {
                    smp = lastSprol.smp * lastSprol.noise
                } else {
                    let preSprol = sprols[i - 1], fqSmp = sprols[i]
                    let t = preSprol.pitch == fqSmp.pitch ?
                        0 : (nPitch - preSprol.pitch) / (fqSmp.pitch - preSprol.pitch)
                    smp = Double.linear(preSprol.smp, fqSmp.smp, t: t)
                    * Double.linear(preSprol.noise, fqSmp.noise, t: t)
                }
                let amp = Volume.amp(fromSmp: smp)
                let alpha = sqfas[fqi]
                return amp * alpha
            }
        }
        
        var samples: [Double]
        if isFullNoise {
            samples = .init(repeating: 0, count: nCount)
        } else {
            let halfDFTCount = dftCount / 2
            var vs = [Double](repeating: 0, count: halfDFTCount)
            let vsRange = 0 ... Double(vs.count - 1)
            let fd = Double(dftCount) / sampleRate
            var overtones = [Int: Int]()
            
            if isStft {
                func enabledIndex(atFq fq: Double) -> Double? {
                    let ni = fq * fd
                    return vsRange.contains(ni) ? ni : nil
                }
                
                let overtone = pitbend.firstTone.overtone//!isEqualAllOvertone
                
                var nfq = scaledFq, fqI = 1
                if overtone.isAll {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        vs[nii] = fqI > 0 ? 1 : 0
                        overtones[nii] = fqI
                        
                        nfq += scaledFq
                        fqI += 1
                    }
                } else if overtone.isOne {
                    if let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        vs[nii] = fqI > 0 ? 1 : 0
                        overtones[nii] = fqI
                    }
                } else {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        vs[nii] = fqI > 0 ? Volume.amp(fromSmp: overtone.smp(at: fqI)) : 0
                        overtones[nii] = fqI
                        
                        nfq += scaledFq
                        fqI += 1
                    }
                }
            } else {
                func enabledIndex(atFq fq: Double) -> Double? {
                    let ni = fq * fd
                    return fq < cutFq && vsRange.contains(ni) ? ni : nil
                }
                let sqfa = fAlpha * 0.5
                
                let overtone = pitbend.firstTone.overtone
                let spectlope = pitbend.firstTone.spectlope
                
                var nfq = scaledFq, fqI = 1
                if overtone.isAll {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        let sfScale = spectlope.noisedAmp(atFq: nfq * fqScale)
                        vs[nii] = sfScale / (Double(fqI) ** sqfa)
                        overtones[nii] = fqI
                        nfq += scaledFq
                        fqI += 1
                    }
                } else if overtone.isOne {
                    if let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        let sfScale = spectlope.noisedAmp(atFq: nfq * fqScale)
                        vs[nii] = sfScale
                        overtones[nii] = fqI
                    }
                } else {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        let overtoneSmp = overtone.smp(at: fqI)
                        let sfAmp = spectlope.noisedAmp(atFq: nfq * fqScale)
                        vs[nii] = Volume.amp(fromSmp: overtoneSmp) * sfAmp / (Double(fqI) ** sqfa)
                        overtones[nii] = fqI
                        nfq += scaledFq
                        fqI += 1
                    }
                }
            }
            
            var inputRes = [Double](capacity: dftCount)
            var inputIms = [Double](capacity: dftCount)
            for fi in 0 ..< halfDFTCount {
                let amp = vs[fi]
                let r = amp * Double(halfDFTCount)
                if fi == 0 {
                    inputRes.append(r)
                    inputIms.append(0)
                } else {
                    if r > 0 {
                        let theta: Double
                        if let n = overtones[fi] {
                            theta = n % 2 == 1 ? 0 : .pi
                        } else {
                            theta = 0
                        }
                        
                        inputRes.append(r * .sin(theta))
                        inputIms.append(-r * .cos(theta))
                    } else {
                        inputRes.append(0)
                        inputIms.append(0)
                    }
                }
            }
            inputRes += [inputRes.last!] + inputRes[1...].reversed()
            inputIms += [0] + inputIms[1...].reversed().map { -$0 }
            
            let dft = try? VDFT(previous: nil,
                                count: dftCount,
                                direction: .inverse,
                                transformType: .complexComplex,
                                ofType: Double.self)
            samples = dft?.transform(real: inputRes,
                                     imaginary: inputIms).real
                ?? [Double](repeating: 0, count: dftCount)
            vDSP.multiply(1 / Double(dftCount * 2), samples,
                          result: &samples)
            
            if startDeltaSec != 0 {
                let phaseI = Int(startDeltaSec * fqScale * sampleRate)
                    .loop(start: 0, end: samples.count)
                samples = Array(samples.loop(from: phaseI))
            }
            
            if isStft {
                let rSampleRate = 1 / sampleRate
                let dCount = Double(samples.count)
                
                var phase = 0.0
                var nSamples = [Double](capacity: nCount)
                for i in 0 ..< nCount {
                    let n: Double
                    if phase.isInteger {
                        n = samples[Int(phase)]
                    } else {
                        let sai = Int(phase)
                        
                        let a0 = sai - 1 >= 0 ? samples[sai - 1] : 0
                        let a1 = samples[sai]
                        let a2 = sai + 1 < samples.count ? samples[sai + 1] : 0
                        let a3 = sai + 2 < samples.count ? samples[sai + 2] : 0
                        let t = phase - Double(sai)
                        n = Double.spline(a0, a1, a2, a3, t: t)
                    }
                    nSamples.append(n)
                    
                    let sec = Double(i) * rSampleRate
                    let vbScale = pitbend.fqScale(atSec: sec)
                    phase += vbScale * fqScale
                    phase = phase.loop(start: 0, end: dCount)
                }
                samples = nSamples
                
                if !pitbend.isEqualAllTone {
                    let spectrumCount = vDSP
                        .spectramCount(sampleCount: samples.count,
                                       fftSize: fftSize)
                    let rDurSp = releaseDur / Double(spectrumCount)
                    let spectrogram = (0 ..< spectrumCount).map { i in
                        let sec = Double(i) * rDurSp
                        let spectlope = pitbend.tone(atSec: sec).spectlope
                        return vDSP.subtract(spectrum(from: spectlope.sprols),
                                             spectrum(fromNoise: spectlope.sprols))
                    }
                    samples = vDSP.apply(samples, scales: spectrogram)
                } else {
                    let spectrum = vDSP.subtract(spectrum(from: pitbend.firstTone.spectlope.sprols),
                                                 spectrum(fromNoise: pitbend.firstTone.spectlope.sprols))
                    samples = vDSP.apply(samples, scales: spectrum)
                }
            }
        }
        
        if isNoise {
            let noiseSamples = vDSP.gaussianNoise(count: nCount, seed: noiseSeed)
            
            var nNoiseSamples: [Double]
            if !pitbend.isEqualAllTone {
                let spectrumCount = vDSP
                    .spectramCount(sampleCount: noiseSamples.count,
                                   fftSize: fftSize)
                let rDurSp = releaseDur / Double(spectrumCount)
                let spectrogram = (0 ..< spectrumCount).map { i in
                    let sec = Double(i) * rDurSp
                    let spectlope = pitbend.tone(atSec: sec).spectlope
                    return spectrum(fromNoise: spectlope.sprols)
                }
                nNoiseSamples = vDSP.apply(noiseSamples, scales: spectrogram)
            } else {
                let spectrum = spectrum(fromNoise: pitbend.firstTone.spectlope.sprols)
                nNoiseSamples = vDSP.apply(noiseSamples, scales: spectrum)
            }
            vDSP.multiply(Double(fftSize) / scaledFq, nNoiseSamples,
                          result: &nNoiseSamples)
            
            if isFullNoise {
                samples = nNoiseSamples
            } else {
                samples = vDSP.add(samples.loopExtended(count: nCount), nNoiseSamples)
            }
        }
        
        if isStft {
            let l = (try? Loudness(sampleRate: sampleRate).integratedLoudness(data: [samples])) ?? 0
            let amp = Volume.amp(fromDb: l)
            let scale = amp < 0.0000001 ? 0 : (1 / amp).clipped(min: 0, max: 2)
            vDSP.multiply(scale, samples, result: &samples)//
        } else {
            let l = (try? Loudness(sampleRate: sampleRate).integratedLoudness(data: [samples])) ?? 0
            let amp = Volume.amp(fromDb: l)
            let scale = amp < 0.0000001 ? 0 : (1 / amp).clipped(min: 0, max: 2)
            vDSP.multiply(scale, samples, result: &samples)
        }
        
        if samples.contains(where: { $0.isNaN || $0.isInfinite }) {
            print(samples.contains(where: { $0.isInfinite }) ? "inf" : "nan")
        }
        
        let stereos = stereos(sampleCount: samples.count)
        
        print(isLoop, samples.count, isStft)
//        print(Date().timeIntervalSince(date), isLoop, samples.count)
        return .init(fqScale: isStft ? 1 : fqScale,
                     isLoop: isLoop,
                     samples: samples, stereos: stereos)
    }
}
extension vDSP {
    static func spectramCount(sampleCount: Int,
                              fftSize: Int,
                              windowOverlap: Double = 0.75) -> Int {
        sampleCount / Int(Double(fftSize) * (1 - windowOverlap)) + 1
    }
    static func apply(_ vs: [Double], scales: [Double]) -> [Double] {
        let spectrumCount = vDSP.spectramCount(sampleCount: vs.count,
                                               fftSize: scales.count)
        return apply(vs, scales: .init(repeating: scales,
                                       count: spectrumCount))
    }
    static func apply(_ samples: [Double], scales: [[Double]],
                      windowOverlap: Double = 0.75) -> [Double] {
        let halfWindowSize = scales[0].count
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
            vDSP.multiply(frames[i].amps, scales[i],
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
        phase = phase.loop(start: 0, end: count)
        
        return n.clipped(min: -1, max: 1)
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
