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
    
    var containsNoise: Bool {
        interpolation.isEmpty ?
        firstTone.spectlope.containsNoise :
        !interpolation.keys.contains(where: { !$0.value.tone.spectlope.containsNoise })
    }
    var isFullNoie: Bool {
        interpolation.isEmpty ?
        firstTone.spectlope.isFullNoise :
        !interpolation.keys.contains(where: { !$0.value.tone.spectlope.isFullNoise })
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
    
    var durSec: Double {
        pitbend.isEqualAllPitch || pitbend.isEqualAllTone ?
        1 : envelopeMemo.duration(fromDurSec: secRange.length)
    }
}
extension Rendnote {
    func notewave(fftSize: Int = 1024, fAlpha: Double = 1, rmsSize: Int = 1024,
                  cutFq: Double = 16384, sampleRate: Double = Audio.defaultSampleRate,
                  dftCount: Int = Audio.defaultDftCount) -> Notewave {
//        let date = Date()
        
        guard !pitbend.isEmpty else {
            return .init(fqScale: 1, isLoop: true, samples: [0], stereos: [.init()])
        }
        
        let isStft = !pitbend.isEqualAllPitch || !pitbend.isEqualAllTone
        let isFullNoise = pitbend.isFullNoie
        let containsNoise = pitbend.containsNoise
        let isLoop = secRange.length.isInfinite || (!isStft && !containsNoise)
        let durSec = secRange.length.isInfinite ?
            1 : envelopeMemo.duration(fromDurSec: min(secRange.length, 100000))
        let nCount = secRange.length.isInfinite ? dftCount : Int((durSec * sampleRate).rounded(.up))
        guard nCount >= 4 else {
            return .init(fqScale: 1, isLoop: true, samples: [0], stereos: [.init()])
        }
        
        func stereos(sampleCount: Int) -> [Stereo] {
            pitbend.isEqualAllStereo ?
            [pitbend.firstStereo] :
            sampleCount.range.map { pitbend.stereo(atSec: Double($0) * rSampleRate) }
        }
        
        let intFq = fq.rounded(.down)
        let fqScale = fq / intFq
        
        let rSampleRate = 1 / sampleRate
        let isOneSin = pitbend.isOne
        if isOneSin {
            if pitbend.isEqualAllPitch {
                let a = 2 * .pi * intFq * rSampleRate
                var samples = dftCount.range
                    .map { Double.sin(Double($0) * a + startDeltaSec) }
                let amp = Volm.amp(fromVolm: Loudness.reverseVolm40Phon(fromFq: fq))
                let rScale = Double.sqrt(2) / amp
                vDSP.multiply(rScale, samples, result: &samples)
                
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: fqScale, isLoop: true, samples: samples, stereos: stereos)
            } else {
                let a = 2 * .pi * rSampleRate, sqrt2 = Double.sqrt(2)
                var phase = startDeltaSec
                let samples = nCount.range.map {
                    let sec = Double($0) * rSampleRate
                    let fq = fq * pitbend.fqScale(atSec: sec)
                    let amp = Volm.amp(fromVolm: Loudness.reverseVolm40Phon(fromFq: fq))
                    let rScale = sqrt2 / amp
                    let v = rScale * Double.sin(phase)
                    phase += fq * a
                    return v
                }
                
                let stereos = stereos(sampleCount: samples.count)
                return .init(fqScale: 1, isLoop: false, samples: samples, stereos: stereos)
            }
        }
        
        let halfFFTSize = fftSize / 2
        let maxFq = sampleRate / 2
        let sqfa = fAlpha * 0.5
        let sqfas: [Double] = (0 ..< halfFFTSize).map {
            let nfq = Double($0) / Double(halfFFTSize) * maxFq
            return nfq == 0 ? 1 : 1 / (nfq / fq) ** sqfa
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
        
        func spectrum(from sprols: [Sprol]) -> (value: [Double], loudnessAmp: Double) {
            var i = 1, sRmsV = 0.0, lRmsV = 0.0
            let value: [Double] = (0 ..< halfFFTSize).map { fqi in
                let nfq = Double(fqi) / Double(halfFFTSize) * maxFq
                guard nfq >= intFq else { return 0 }
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
                let lAmp = Volm.amp(fromVolm: volm * Loudness.volm40Phon(fromFq: nfq))
                
                let sAmp = Volm.amp(fromVolm: volm)
                sRmsV += sAmp * sAmp
                lRmsV += lAmp * lAmp
                
                return lAmp * sqfas[fqi]
            }
            return (value, sRmsV == 0 ? 0 : .sqrt(lRmsV / sRmsV))
        }
        func spectrum(fromNoise sprols: [Sprol]) -> (value: [Double], loudnessAmp: Double) {
            var i = 1, sRmsV = 0.0, lRmsV = 0.0
            let value: [Double] = (0 ..< halfFFTSize).map { fqi in
                let nfq = Double(fqi) / Double(halfFFTSize) * maxFq
                guard nfq >= intFq else { return 0 }
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
                let lAmp = Volm.amp(fromVolm: volm * Loudness.volm40Phon(fromFq: nfq))
                
                let sAmp = Volm.amp(fromVolm: volm)
                sRmsV += sAmp * sAmp
                lRmsV += lAmp * lAmp
                
                return lAmp * sqfas[fqi]
            }
            return (value, sRmsV == 0 ? 0 : .sqrt(lRmsV / sRmsV))
        }
        
        func normarizedWithRMS(from sSamples: [Double], to lSamples: [Double]) -> [Double] {
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
                idxs.append(.init(sSamples.count - 1))
            }
            
            let nCount = Int(idxs.last!) + 1
            let result = [Double](unsafeUninitializedCapacity: count) { buffer, initializedCount in
                vDSP.linearInterpolate(values: rmss, atIndices: idxs, result: &buffer)
                initializedCount = nCount
            }
            
            return vDSP.multiply(lSamples, result)
        }
        
        if !isStft && !isFullNoise {
            let halfDFTCount = dftCount / 2
            var vs = [Double](repeating: 0, count: halfDFTCount)
            let vsRange = 0 ... Double(vs.count - 1)
            let fd = Double(dftCount) / sampleRate
            var overtones = [Int: Int]()
            
            func enabledIndex(atFq fq: Double) -> Double? {
                let ni = fq * fd
                return fq < cutFq && vsRange.contains(ni) ? ni : nil
            }
            let sqfa = fAlpha * 0.5
            
            let overtone = pitbend.firstTone.overtone
            let spectlope = pitbend.firstTone.spectlope
            var intNFq = intFq, fqI = 1, sRmsV = 0.0, lRmsV = 0.0
            if overtone.isAll {
                while let ni = enabledIndex(atFq: intNFq) {
                    let nFq = intNFq * fqScale
                    let nii = Int(ni)
                    let volm = spectlope.noisedVolm(atFq: nFq)
                    let amp = Volm.amp(fromVolm: volm * Loudness.volm40Phon(fromFq: nFq))
                    let lAmp = amp / (Double(fqI) ** sqfa)
                    vs[nii] = lAmp / 2
                    let sAmp = Volm.amp(fromVolm: Volm.volm(fromAmp: lAmp) * Loudness.reverseVolm40Phon(fromFq: nFq))
                    sRmsV += sAmp * sAmp
                    lRmsV += lAmp * lAmp
                    overtones[nii] = fqI
                    intNFq += intFq
                    fqI += 1
                }
            } else {
                while let ni = enabledIndex(atFq: intNFq) {
                    let nFq = intNFq * fqScale
                    let nii = Int(ni)
                    let overtoneVolm = overtone.volm(at: fqI)
                    let volm = spectlope.noisedVolm(atFq: nFq)
                    let amp = Volm.amp(fromVolm: volm * Loudness.volm40Phon(fromFq: nFq) * overtoneVolm)
                    let lAmp = amp / (Double(fqI) ** sqfa)
                    vs[nii] = lAmp / 2
                    let sAmp = Volm.amp(fromVolm: Volm.volm(fromAmp: lAmp) * Loudness.reverseVolm40Phon(fromFq: nFq))
                    sRmsV += sAmp * sAmp
                    lRmsV += lAmp * lAmp
                    overtones[nii] = fqI
                    intNFq += intFq
                    fqI += 1
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
                        let theta: Double = if let n = overtones[fi] {
                            n % 2 == 1 ? 0 : .pi
                        } else {
                            0
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
            var sSamples = dft?.transform(real: inputRes, imaginary: inputIms).real
                ?? [Double](repeating: 0, count: dftCount)
            vDSP.multiply(2 / Double(dftCount), sSamples, result: &sSamples)
            
            if startDeltaSec != 0 {
                let phaseI = Int(startDeltaSec * fqScale * sampleRate)
                    .loop(start: 0, end: sSamples.count)
                sSamples = Array(sSamples.loop(from: phaseI))
            }
            
            let lAmp = sRmsV == 0 ? 0 : Double.sqrt(lRmsV / sRmsV)
            var lSamples = vDSP.multiply(lAmp, sSamples)
            
            if containsNoise {
                let dCount = Double(sSamples.count)
                var nSamples = [Double](capacity: nCount), phase = 0.0
                for _ in nCount.range {
                    nSamples.append(spline(sSamples, phase: phase))
                    phase = (phase + fqScale).loop(start: 0, end: dCount)
                }
                sSamples = nSamples
                
                var noiseSamples = vDSP.gaussianNoise(count: nCount, seed: noiseSeed)
                let (spectrum, noiseLAmp) = spectrum(fromNoise: pitbend.firstTone.spectlope.sprols)
                noiseSamples = vDSP.apply(noiseSamples, spectrum: spectrum)
                let lNoiseSamples = vDSP.multiply(noiseLAmp, noiseSamples)
                vDSP.add(sSamples, noiseSamples, result: &sSamples)
                vDSP.add(lSamples, lNoiseSamples, result: &lSamples)
                
                sSamples = normarizedWithRMS(from: sSamples, to: lSamples)
                
                let stereos = stereos(sampleCount: sSamples.count)
                return .init(fqScale: 1, isLoop: false, samples: sSamples, stereos: stereos)
            } else {
                sSamples = normarizedWithRMS(from: sSamples, to: lSamples)
                
                let stereos = stereos(sampleCount: sSamples.count)
                return .init(fqScale: fqScale, isLoop: isLoop, samples: sSamples, stereos: stereos)
            }
        } else {
            var sSamples: [Double], lSamples: [Double]
            if isFullNoise {
                sSamples = .init(repeating: 0, count: nCount)
                lSamples = .init(repeating: 0, count: nCount)
            } else {
                let halfDFTCount = dftCount / 2
                var vs = [Double](repeating: 0, count: halfDFTCount)
                let vsRange = 0 ... Double(vs.count - 1)
                let fd = Double(dftCount) / sampleRate
                var overtones = [Int: Int]()
                
                func enabledIndex(atFq fq: Double) -> Double? {
                    let ni = fq * fd
                    return vsRange.contains(ni) ? ni : nil
                }
                
                let overtone = pitbend.firstTone.overtone//!isEqualAllOvertone
                
                var nfq = intFq, fqI = 1
                if overtone.isAll {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        vs[nii] = fqI > 0 ? 1 : 0
                        overtones[nii] = fqI
                        
                        nfq += intFq
                        fqI += 1
                    }
                } else {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        vs[nii] = fqI > 0 ? Volm.amp(fromVolm: overtone.volm(at: fqI)) : 0
                        overtones[nii] = fqI
                        
                        nfq += intFq
                        fqI += 1
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
                            let theta: Double = if let n = overtones[fi] {
                                n % 2 == 1 ? 0 : .pi
                            } else {
                                0
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
                sSamples = dft?.transform(real: inputRes,
                                         imaginary: inputIms).real
                    ?? [Double](repeating: 0, count: dftCount)
                vDSP.multiply(2 / Double(dftCount), sSamples, result: &sSamples)
                
                if startDeltaSec != 0 {
                    let phaseI = Int(startDeltaSec * fqScale * sampleRate)
                        .loop(start: 0, end: sSamples.count)
                    sSamples = Array(sSamples.loop(from: phaseI))
                }
                
                let rSampleRate = 1 / sampleRate
                let dCount = Double(sSamples.count)
                
                var phase = 0.0, nSamples = [Double](capacity: nCount)
                for i in nCount.range {
                    nSamples.append(spline(sSamples, phase: phase))
                    let sec = Double(i) * rSampleRate
                    phase += pitbend.fqScale(atSec: sec) * fqScale
                    phase = phase.loop(start: 0, end: dCount)
                }
                sSamples = nSamples
                
                let spectrumCount = vDSP
                    .spectramCount(sampleCount: sSamples.count, fftSize: fftSize)
                let rDurSp = durSec / Double(spectrumCount)
                let spectrogram = spectrumCount.range.map { i in
                    let sec = Double(i) * rDurSp
                    let spectlope = pitbend.tone(atSec: sec).spectlope
                    return spectrum(from: spectlope.sprols).value
                }
                sSamples = vDSP.apply(sSamples, spectrogram: spectrogram)
                lSamples = vDSP.multiply(lAmp, sSamples)
            }
            
            if containsNoise {
                var noiseSamples = vDSP.gaussianNoise(count: nCount, seed: noiseSeed)
                
                let spectrumCount = vDSP.spectramCount(sampleCount: noiseSamples.count, fftSize: fftSize)
                let rDurSp = durSec / Double(spectrumCount)
                let spectrogram = spectrumCount.range.map { i in
                    let sec = Double(i) * rDurSp
                    let spectlope = pitbend.tone(atSec: sec).spectlope
                    return spectrum(fromNoise: spectlope.sprols).value
                }
                noiseSamples = vDSP.apply(noiseSamples, spectrogram: spectrogram)
                let lNoiseSamples = vDSP.multiply(noiseLAmp, noiseSamples)
                
                vDSP.add(sSamples, noiseSamples, result: &sSamples)
                vDSP.add(lSamples, lNoiseSamples, result: &lSamples)
            }
            
            sSamples = normarizedWithRMS(from: sSamples, to: lSamples)
            
            if sSamples.contains(where: { $0.isNaN || $0.isInfinite }) {
                print(sSamples.contains(where: { $0.isInfinite }) ? "inf" : "nan")
            }
            
    //        print(Date().timeIntervalSince(date), isLoop, samples.count)
            
            let stereos = stereos(sampleCount: sSamples.count)
            return .init(fqScale: 1, isLoop: false, samples: sSamples, stereos: stereos)
        }
    }
}
extension vDSP {
    static func spectramCount(sampleCount: Int,
                              fftSize: Int,
                              windowOverlap: Double = 0.75) -> Int {
        sampleCount / Int(Double(fftSize) * (1 - windowOverlap)) + 1
    }
    static func apply(_ vs: [Double], spectrum: [Double]) -> [Double] {
        let spectrumCount = vDSP.spectramCount(sampleCount: vs.count,
                                               fftSize: spectrum.count)
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
        phase = phase.loop(start: 0, end: count)
        
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
