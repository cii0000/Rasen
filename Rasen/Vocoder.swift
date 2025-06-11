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

import struct Foundation.UUID
import RealModule

//#if os(macOS) && os(iOS) && os(watchOS) && os(tvOS) && os(visionOS)
import Accelerate.vecLib.vDSP
//#elseif os(linux) && os(windows)
//#endif

/// xoshiro256**
struct Random: Hashable, Codable {
    private var s0, s1, s2, s3: UInt64
    
    static func next(seed: inout UInt64) -> UInt64 {
        seed &+= 0x9e3779b97f4a7c15
        var z = seed
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
    init(seed: UInt64) {
        var seed = seed
        s0 = Self.next(seed: &seed)
        s1 = Self.next(seed: &seed)
        s2 = Self.next(seed: &seed)
        s3 = Self.next(seed: &seed)
    }
    
    private func rol(_ x: UInt64, _ k: Int) -> UInt64 {
        (x << k) | (x >> (64 - k))
    }
    mutating func next() -> UInt64 {
        let result = rol(s1 &* 5, 7) &* 9
        let t = s1 << 17
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        
        s2 ^= t
        s3 = rol(s3, 45)
        return result
    }
    mutating func nextT() -> Double {
        return Double(next()) / Double(UInt64.max)
    }
}

extension vDSP {
    static func gaussianNoise(count: Int, seed: UInt64) -> [Double] {
        gaussianNoise(count: count, seed0: seed, seed1: seed << 10)
    }
    static func gaussianNoise(count: Int, seed0: UInt64, seed1: UInt64,
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
    static func approximateGaussianNoise(count: Int, seed: UInt64,
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

struct Waveclip {
    static let minAmp: Float = 0.00001
    static let attackSec = 0.015625, releaseSec = 0.015625
    static let rAttackSec = 1 / attackSec, rReleaseSec = 1 / releaseSec
}
extension Waveclip {
    static func amp(atSec sec: Double, attackStartSec: Double?, releaseStartSec: Double?) -> Double {
        guard attackStartSec != nil || releaseStartSec != nil else { return 1 }
        let aAmp: Double
        if let attackStartSec {
            if sec <= attackStartSec {
                return 0
            }
            let nSec = sec - attackStartSec
            aAmp = nSec < attackSec ? nSec * rAttackSec : 1
        } else {
            aAmp = 1
        }
        
        if let releaseStartSec, sec >= releaseStartSec {
            let nSec = sec - releaseStartSec
            return if releaseSec > 0 && nSec < releaseSec {
                .linear(aAmp, 0, t: nSec * rReleaseSec)
            } else {
                0
            }
        } else {
            return aAmp
        }
    }
}

struct EnvelopeMemo: Hashable, Codable {
    let attackSec, decaySec, sustainAmp, releaseSec, maxSec: Double
    let rAttackSec, rDecaySec, rReleaseSec: Double
    let reverb: Reverb
    
    init(_ envelope: Envelope) {
        attackSec = max(envelope.attackSec, 0)
        decaySec = max(envelope.decaySec, 0)
        sustainAmp = Volm.amp(fromVolm: envelope.sustainVolm)
        releaseSec = max(envelope.releaseSec, 0)
        rAttackSec = 1 / attackSec
        rDecaySec = 1 / decaySec
        rReleaseSec = 1 / releaseSec
        reverb = envelope.reverb
        maxSec = releaseSec + (envelope.reverb.isEmpty ? 0 : envelope.reverb.durSec)
    }
}
extension EnvelopeMemo {
    func amp(atSec sec: Double, attackStartSec: Double?, releaseStartSec: Double?) -> Double {
        guard attackStartSec != nil || releaseStartSec != nil else { return 1 }
        let aAmp: Double
        if let attackStartSec {
            if sec <= attackStartSec {
                return 0
            }
            let nSec = sec - attackStartSec
            
            if attackSec > 0 && nSec < attackSec {
                aAmp = nSec * rAttackSec
            } else {
                let nSec = nSec - attackSec
                aAmp = if decaySec > 0 && nSec < decaySec {
                    .linear(1, sustainAmp, t: nSec * rDecaySec)
                } else {
                    sustainAmp
                }
            }
        } else {
            aAmp = 1
        }
        
        if let releaseStartSec, sec >= releaseStartSec {
            if sec <= releaseStartSec {
                return aAmp
            }
            let nSec = sec - releaseStartSec
            return if releaseSec > 0 && nSec < releaseSec {
                .linear(aAmp, 0, t: nSec * rReleaseSec)
            } else {
                0
            }
        } else {
            return aAmp
        }
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
 
    let pits: [Pit]
    let secs: [Double]
    
    init(pits: [Pit], beatRange: Range<Rational>, tempo: Rational) {
        let pitchs = pits.map { Double($0.pitch / 12) }
        let stereos = pits.map { $0.stereo.with(id: .zero) }
        let overtones = pits.map { $0.tone.overtone }
        let spectlopeCount = pits.maxValue { $0.tone.spectlope.sprols.count } ?? 0
        let spectlopes = pits.map { $0.tone.spectlope.with(count: spectlopeCount) }
        let secs = pits.map { Double(Score.sec(fromBeat: $0.beat, tempo: tempo)) }
        let durSec = Double(Score.sec(fromBeat: beatRange.length, tempo: tempo))
        func interpolation<T: MonoInterpolatable & Equatable>(isAll: Bool, _ vs: [T],
                                                              _ type: Interpolation<T>.KeyType = .spline) -> Interpolation<T> {
            guard !isAll else { return .init() }
            var pitKeys = zip(vs, secs).map {
                Interpolation.Key(value: $0.0, time: $0.1, type: type)
            }
            if pits.first!.beat > 0 {
                pitKeys.insert(.init(value: pitKeys.first!.value, time: 0, type: type), at: 0)
            }
            if pits.last!.beat < beatRange.length {
                pitKeys.append(.init(value: pitKeys.last!.value, time: durSec, type: type))
            }
            return .init(keys: pitKeys, duration: durSec)
        }
        
        let firstPitch = pitchs.first!
        self.firstPitch = firstPitch
        firstFqScale = .exp2(firstPitch)
        isEqualAllPitch = pitchs.allSatisfy { $0 == firstPitch }
        pitchInterpolation = interpolation(isAll: isEqualAllPitch, pitchs)
        
        let firstStereo = stereos.first!
        self.firstStereo = firstStereo
        isEqualAllStereo = stereos.allSatisfy { $0 == firstStereo }
        stereoInterpolation = interpolation(isAll: isEqualAllStereo, stereos, .linear)
        
        let firstOvertone = overtones.first!
        self.firstOvertone = firstOvertone
        isEqualAllOvertone = overtones.allSatisfy { $0 == firstOvertone }
        overtoneInterpolation = interpolation(isAll: isEqualAllOvertone, overtones)
        
        let firstSpectlope = spectlopes.first!
        self.firstSpectlope = firstSpectlope
        isEqualAllSpectlope = spectlopes.allSatisfy { $0 == firstSpectlope }
        spectlopeInterpolation = interpolation(isAll: isEqualAllSpectlope, spectlopes)
        
        self.pits = pits
        self.secs = secs
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
        
        pits = []
        secs = []
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
        spectlopeInterpolation.keys.allSatisfy { $0.value.isFullNoise }
    }
    var isOneOvertone: Bool {
        isEqualAllOvertone ?
        firstOvertone.isOne : overtoneInterpolation.keys.allSatisfy { $0.value.isOne }
    }
    var isEqualAllWithoutStereo: Bool {
        isEqualAllPitch && isEqualAllOvertone && isEqualAllSpectlope
    }
}

struct Rendnote {
    var rootFq: Double, firstFq: Double
    var noiseSeed0, noiseSeed1: UInt64
    var pitbend: Pitbend
    var secRange: Range<Double>
    var reverb: Reverb
    var isRelease = false
    let id = UUID()
}
extension Rendnote {
    init(note: Note, score: Score, snapBeatScale: Rational = .init(1, 4)) {
        let sSec = Double(score.sec(fromBeat: note.beatRange.start))
        let eSec = Double(score.sec(fromBeat: note.beatRange.end))
        
        let (seed0, seed1) = note.containsNoise ? note.id.uInt64Values : (0, 0)
        let rootFq = Pitch.fq(fromPitch: .init(note.pitch))
        let pitbend = note.pitbend(fromTempo: score.tempo)
        self.init(rootFq: rootFq,
                  firstFq: rootFq * pitbend.firstFqScale,
                  noiseSeed0: seed0, noiseSeed1: seed1,
                  pitbend: pitbend,
                  secRange: sSec ..< eSec,
                  reverb: .full)
    }
    
    var isStft: Bool {
        !pitbend.isEqualAllWithoutStereo
    }
    var isLoop: Bool {
        secRange.length.isInfinite
    }
    var rendableDurSec: Double {
        min(isLoop ? firstFq.rounded(.up) / firstFq : secRange.length + Waveclip.releaseSec,
            1000)
    }
    
    func sampleCount(sampleRate: Double) -> Int {
        guard !pitbend.isEmpty else { return 1 }
        if isLoop {
            let rendableDurSec = min(firstFq.rounded(.up) / firstFq, 1000)
            return max(1, Int((rendableDurSec * sampleRate).rounded(.down)))
        }
        let rendableDurSec = min(secRange.length + Waveclip.releaseSec, 1000)
        let sampleCount = max(1, Int((rendableDurSec * sampleRate).rounded(.up)))
        return reverb.isEmpty ?
        sampleCount :
        sampleCount + reverb.count(sampleRate: sampleRate) - 1
    }
    func releaseCount(sampleRate: Double) -> Int {
        let rendableDurSec = min(Waveclip.releaseSec, 1000)
        let sampleCount = max(1, Int((rendableDurSec * sampleRate).rounded(.up)))
        return reverb.isEmpty ?
        sampleCount : sampleCount + reverb.count(sampleRate: sampleRate) - 1
    }
    func releasedRange(sampleRate: Double, startSec: Double) -> Range<Int> {
        isLoop ? (0 ..< sampleCount(sampleRate: sampleRate)) :
        .init(start: Int(((secRange.lowerBound + startSec) * sampleRate).rounded(.down)),
              length: sampleCount(sampleRate: sampleRate))
    }
}
extension Rendnote {
    func notewave(stftCount: Int = 1024, fAlpha: Double = 1, rmsSize: Int = 2048,
                  cutFq: Double = 16384, cutStartFq: Double = 15800, sampleRate: Double) -> Notewave {
        func nSamples(noiseSeed0: UInt64, noiseSeed1: UInt64) -> [Double] {
            var samples = samples(stftCount: stftCount, fAlpha: fAlpha, rmsSize: rmsSize,
                                  noiseSeed0: noiseSeed0, noiseSeed1: noiseSeed1,
                                  cutFq: cutFq, cutStartFq: cutStartFq, sampleRate: sampleRate)
            if !isLoop {
                let rSampleRate = 1 / sampleRate
                let sampleCount = samples.count
                let attackStartSec = !pitbend.firstStereo.isEmpty && !pitbend.firstSpectlope.isEmptyVolm ? 0.0 : nil
                let releaseStartSec = Double(sampleCount - 1) * rSampleRate - Waveclip.releaseSec
                for i in 0 ..< sampleCount {
                    samples[i] *= Waveclip.amp(atSec: Double(i) * rSampleRate,
                                               attackStartSec: attackStartSec,
                                               releaseStartSec: releaseStartSec)
                }
            }
            return samples
        }
        if reverb.isFull && pitbend.isFullNoise {
            var noiseSeed2 = noiseSeed0
            _ = Random.next(seed: &noiseSeed2)
            _ = Random.next(seed: &noiseSeed2)
            _ = Random.next(seed: &noiseSeed2)
            _ = Random.next(seed: &noiseSeed2)
            var noiseSeed3 = noiseSeed1
            _ = Random.next(seed: &noiseSeed3)
            _ = Random.next(seed: &noiseSeed3)
            _ = Random.next(seed: &noiseSeed3)
            _ = Random.next(seed: &noiseSeed3)
            let samples0 = nSamples(noiseSeed0: noiseSeed0, noiseSeed1: noiseSeed1)
            let samples1 = nSamples(noiseSeed0: noiseSeed2, noiseSeed1: noiseSeed3)
            return notewave(from: [samples0, samples1], sampleRate: sampleRate)
        } else {
            let samples = nSamples(noiseSeed0: noiseSeed0, noiseSeed1: noiseSeed1)
            return notewave(from: [samples], sampleRate: sampleRate)
        }
    }
    func notewave(from sampless: [[Double]], stereo: Stereo? = nil, sampleRate: Double) -> Notewave {
        let rSampleRate = 1 / sampleRate
        var nSampless: [[Double]]
        let stereoScale = Volm.volm(fromAmp: 1 / 2.0.squareRoot())
        
        if pitbend.isEqualAllStereo || stereo != nil {
            let stereo = (stereo ?? pitbend.firstStereo).multiply(volm: stereoScale)
            let stereoAmp = Volm.amp(fromVolm: stereo.volm)
            let oSampless = sampless.map { vDSP.multiply(stereoAmp, $0) }
            let pan = stereo.pan
            if oSampless.count == 1 {
                let nSamples = oSampless[0]
                if pan == 0 {
                    nSampless = [nSamples, nSamples]
                } else {
                    let nPan = pan.clipped(min: -1, max: 1)
                    if nPan < 0 {
                        nSampless = [nSamples,
                                     vDSP.multiply(Volm.amp(fromVolm: 1 + nPan), nSamples)]
                    } else {
                        nSampless = [vDSP.multiply(Volm.amp(fromVolm: 1 - nPan), nSamples),
                                     nSamples]
                    }
                }
            } else {
                if pan == 0 {
                    nSampless = [oSampless[0], oSampless[1]]
                } else {
                    let nPan = pan.clipped(min: -1, max: 1)
                    if nPan < 0 {
                        nSampless = [oSampless[0],
                                     vDSP.multiply(Volm.amp(fromVolm: 1 + nPan), oSampless[1])]
                    } else {
                        nSampless = [vDSP.multiply(Volm.amp(fromVolm: 1 - nPan), oSampless[0]),
                                     oSampless[1]]
                    }
                }
            }
        } else {
            let stereos = sampless[0].count.range.map { pitbend.stereo(atSec: Double($0) * rSampleRate).multiply(volm: stereoScale) }
            let stereoAmps = stereos.map { Volm.amp(fromVolm: $0.volm) }
            let oSampless = sampless.map { vDSP.multiply($0, stereoAmps) }
            nSampless = [[Double](capacity: stereos.count), [Double](capacity: stereos.count)]
            if oSampless.count == 1 {
                for (sample, stereo) in zip(oSampless[0], stereos) {
                    let pan = stereo.pan
                    if pan == 0 {
                        nSampless[0].append(sample)
                        nSampless[1].append(sample)
                    } else {
                        let nPan = pan.clipped(min: -1, max: 1)
                        if nPan < 0 {
                            nSampless[0].append(sample)
                            nSampless[1].append(sample * Volm.amp(fromVolm: 1 + nPan))
                        } else {
                            nSampless[0].append(sample * Volm.amp(fromVolm: 1 - nPan))
                            nSampless[1].append(sample)
                        }
                    }
                }
            } else {
                for (si, stereo) in stereos.enumerated() {
                    let pan = stereo.pan
                    if pan == 0 {
                        nSampless[0].append(oSampless[0][si])
                        nSampless[1].append(oSampless[1][si])
                    } else {
                        let nPan = pan.clipped(min: -1, max: 1)
                        if nPan < 0 {
                            nSampless[0].append(oSampless[0][si])
                            nSampless[1].append(oSampless[1][si] * Volm.amp(fromVolm: 1 + nPan))
                        } else {
                            nSampless[0].append(oSampless[0][si] * Volm.amp(fromVolm: 1 - nPan))
                            nSampless[1].append(oSampless[1][si])
                        }
                    }
                }
            }
        }
        
        var notewave = Notewave(noStereoSampless: sampless, sampless: nSampless, isLoop: isLoop)
        if !reverb.isEmpty {
            let sampleCount = notewave.sampleCount
            notewave.sampless = [vDSP.apply(fir: reverb.fir(sampleRate: sampleRate, channel: 0),
                                            in: notewave.sampless[0]),
                                 vDSP.apply(fir: reverb.fir(sampleRate: sampleRate, channel: 1),
                                            in: notewave.sampless[1])]
            if isLoop && notewave.sampleCount > sampleCount {
                let count = notewave.sampleCount - sampleCount
                notewave.sampless[0].removeLast(count)
                notewave.sampless[1].removeLast(count)
            }
        }
        
        notewave.sampless.forEach { samples in
            if samples.contains(where: { $0.isNaN || $0.isInfinite }) {
                print(samples.contains(where: { $0.isInfinite }) ? "inf" : "nan")
            }
        }
        
        return notewave
    }
    private func samples(stftCount: Int, fAlpha: Double, rmsSize: Int,
                         noiseSeed0: UInt64, noiseSeed1: UInt64,
                         cutFq: Double, cutStartFq: Double, sampleRate: Double) -> [Double] {
        let sampleCount = Int((rendableDurSec * sampleRate).rounded(isLoop ? .down : .up))
        guard !pitbend.isEmpty && sampleCount >= 1 else {
            return [0]
        }
        let isStft = isStft
        let isFullNoise = pitbend.isFullNoise
        let containsNoise = pitbend.containsNoise
        let rSampleRate = 1 / sampleRate
        let rootFq = rootFq.clipped(min: Score.minFq, max: cutFq)
        let firstFq = firstFq.clipped(min: Score.minFq, max: cutFq)
        let cutPitch = Pitch.pitch(fromFq: cutFq)
        let rootPitch = Pitch.pitch(fromFq: rootFq)
        let startPhase = secRange.start.isInfinite ? 0.0 : (secRange.start * firstFq * .pi2)
        let firstClearVolm = Loudness.clearVolm40Phon(fromPitch: Pitch.pitch(fromFq: firstFq))
        
        let isOneSin = pitbend.isOneOvertone
        if isOneSin {
            let pi2rs = .pi2 * rSampleRate, rScale = Double.sqrt(2)
            if pitbend.isEqualAllPitch {
                let a = firstFq * pi2rs
                var samples = sampleCount.range.map { Double.sin(Double($0) * a + startPhase) }
                let pitch = Pitch.pitch(fromFq: firstFq)
                let amp = Volm.amp(fromVolm: Loudness.volm40Phon(fromPitch: pitch))
                vDSP.multiply(amp * rScale * firstClearVolm, samples, result: &samples)
                return samples
            } else {
                var phase = startPhase
                return sampleCount.range.map {
                    let sec = Double($0) * rSampleRate
                    let fq = (rootFq * pitbend.fqScale(atSec: sec)).clipped(min: Score.minFq, max: cutFq)
                    let pitch = Pitch.pitch(fromFq: fq)
                    let amp = Volm.amp(fromVolm: Loudness.volm40Phon(fromPitch: pitch))
                    let v = amp * rScale * Double.sin(phase) * Loudness.clearVolm40Phon(fromPitch: pitch)
                    phase += fq * pi2rs
                    return v
                }
            }
        }
        
        let halfStftCount = stftCount / 2
        let maxFq = sampleRate / 2
        let sqfa = fAlpha * 0.5
        let sqfas = halfStftCount.range.map { $0 == 0 ? 1 : 1 / Double($0) ** sqfa }
        
        func aNoiseSpectrum(fromNoise spectlope: Spectlope,
                            oddScale: Double, evenScale: Double) -> (spectrum: [Double], mainSpectrum: [Double]) {
            var sign = true, mainSpectrum = [Double](capacity: halfStftCount)
            return ((1 ... halfStftCount).map { fqi in
                let nfq = Double(fqi) / Double(halfStftCount) * maxFq
                guard nfq > 0 && nfq < cutFq else {
                    mainSpectrum.append(0)
                    return 0
                }
                let pitch = Pitch.pitch(fromFq: nfq)
                let loudnessVolm = Loudness.volm40Phon(fromPitch: pitch)
                let noiseVolm = spectlope.sprol(atPitch: pitch).noiseVolm
                let cutScale = cutStartFq < nfq ? nfq.clipped(min: cutStartFq, max: cutFq, newMin: 1, newMax: 0) : 1
                let overtoneScale = sign ? oddScale : evenScale
                let a = sqfas[fqi] * cutScale * overtoneScale
                let amp = Volm.amp(fromVolm: loudnessVolm * noiseVolm) * a
                mainSpectrum.append(Volm.amp(fromVolm: noiseVolm) * a)
                sign = !sign
                return amp
            }, mainSpectrum)
        }
        func clippedStft(_ samples: [Double]) -> [Double] {
            .init(samples[halfStftCount ..< samples.count - halfStftCount])
        }
        
        if !isStft {
            func normarizedWithRMS(from sSamples: [Double], to lSamples: [Double],
                                   scale: Double = 1) -> [Double] {
                let v = vDSP.rootMeanSquare(sSamples)
                let spectrumScale = v == 0 ? 0 : scale / v
                var nSamples = lSamples
                vDSP.multiply(spectrumScale, nSamples, result: &nSamples)
                return nSamples
            }
            
            let overtone = pitbend.firstOvertone
            let isAll = overtone.isAll,
                oddScale = Volm.amp(fromVolm: overtone.oddVolm),
                evenScale = -overtone.evenAmp
            if isFullNoise {
                let (noiseSpectrum, mainNoiseSpectrum) = aNoiseSpectrum(fromNoise: pitbend.firstSpectlope,
                                                                        oddScale: oddScale,
                                                                        evenScale: -evenScale)
                let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount,
                                                      seed0: noiseSeed0, seed1: noiseSeed1)
                let samples = clippedStft(vDSP.apply(noiseSamples, spectrum: noiseSpectrum))
                let mainSamples = clippedStft(vDSP.apply(noiseSamples, spectrum: mainNoiseSpectrum))
                return normarizedWithRMS(from: mainSamples, to: samples)
            } else {
                let spectlope = pitbend.firstSpectlope
                let sinCount = Int((min(spectlope.maxFq, cutFq) / firstFq).clipped(min: 1, max: Double(Int.max)))
                
                var sign = true, prePitch = 0.0, mainSpectrum = [Double](capacity: sinCount)
                let spectrum = (1 ... sinCount).map { n in
                    let nFq = firstFq * Double(n)
                    let pitch = Pitch.pitch(fromFq: nFq)
                    let loudnessVolm = Loudness.volm40Phon(fromPitch: pitch)
                    let mainScale = (pitch - prePitch).clipped(min: 0, max: 2, newMin: 3, newMax: 1)
                    let spectlopeVolm = spectlope.overtonesVolm(atPitch: pitch)
                    let cutScale = nFq.clipped(min: cutStartFq, max: cutFq, newMin: 1, newMax: 0)
                    let overtoneScale = isAll || n == 1 ? (sign ? 1 : -1) : (sign ? oddScale : evenScale)
                    let sqfa = Double(n) ** sqfa
                    let a = Volm.amp(fromVolm: spectlopeVolm) * overtoneScale / sqfa * cutScale
                    let amp = Volm.amp(fromVolm: loudnessVolm) * a
                    mainSpectrum.append(a * mainScale)
                    sign = !sign
                    prePitch = pitch
                    return amp * firstClearVolm
                }
                
                let dPhase = firstFq * .pi2 * rSampleRate
                var x = startPhase
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
                
                var mainSamples = [Double](repeating: 0, count: sampleCount)
                var samples = [Double](repeating: 0, count: sampleCount)
                var sinKXs = [Double](repeating: 0, count: sampleCount)
                func append(_ sinNXs: [Double], at n: Int) {
                    if containsNoise {
                        vDSP.multiply(mainSpectrum[n], sinNXs, result: &sinKXs)
                        vDSP.add(sinKXs, mainSamples, result: &mainSamples)
                    }
                    vDSP.multiply(spectrum[n], sinNXs, result: &sinKXs)
                    vDSP.add(sinKXs, samples, result: &samples)
                }
                
                var sinNXs = [Double](repeating: 0, count: sampleCount)
                var sinNXs1 = [Double](repeating: 0, count: sampleCount)
                var cosNXs = [Double](repeating: 0, count: sampleCount)
                var cosNXs1 = [Double](repeating: 0, count: sampleCount)
                append(sin1Xs, at: 0)
                if sinCount >= 2 {
                    for n in 1 ..< sinCount {
                        vDSP.multiply(sinMXs, cos1Xs, result: &sinNXs)
                        vDSP.multiply(cosMXs, sin1Xs, result: &sinNXs1)
                        
                        vDSP.multiply(cosMXs, cos1Xs, result: &cosNXs)
                        vDSP.multiply(sinMXs, sin1Xs, result: &cosNXs1)
                        
                        vDSP.add(sinNXs, sinNXs1, result: &sinMXs)
                        vDSP.subtract(cosNXs, cosNXs1, result: &cosMXs)
                        
                        append(sinMXs, at: n)
                    }
                }
                
                if containsNoise {
                    let (noiseSpectrum, mainNoiseSpectrum) = aNoiseSpectrum(fromNoise: spectlope,
                                                                            oddScale: oddScale,
                                                                            evenScale: -evenScale)
                    let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount,
                                                          seed0: noiseSeed0, seed1: noiseSeed1)
                    let nNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrum: noiseSpectrum))
                    let nMainNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrum: mainNoiseSpectrum))
                    
                    vDSP.add(mainSamples, nMainNoiseSamples, result: &mainSamples)
                    vDSP.add(samples, nNoiseSamples, result: &samples)
                    
                    samples = normarizedWithRMS(from: mainSamples, to: samples)
                } else {
                    let rms = (mainSpectrum.map { $0.squared }.sum() / 2).squareRoot()
                    let scale = rms == 0 ? 0 : 1 / rms
                    vDSP.multiply(scale, samples, result: &samples)
                }
                
                return samples
            }
        } else {
            func normarizedWithRMS(from sSamples: [Double], to lSamples: [Double]) -> [Double] {
                if sSamples.count < rmsSize {
                    let maxV = vDSP.rootMeanSquare(sSamples)
                    let spectrumScale = maxV == 0 ? 0 : 1 / maxV
                    var nSamples = lSamples
                    vDSP.multiply(spectrumScale, nSamples, result: &nSamples)
                    return nSamples
                }
                var volms = [(sec: Double, sumVolm: Double)](capacity: pitbend.pits.count)
                for (pit, sec) in zip(pitbend.pits, pitbend.secs) {
                    let pitch = (rootPitch + pitbend.pitch(atSec: sec)).clipped(min: Score.doubleMinPitch, max: cutPitch)
                    let sumVolm = pit.tone.spectlope.sumOvertonesVolm(fromPitch: pitch) + pit.tone.spectlope.sumNoiseVolm
                    volms.append((sec, sumVolm))
                }
                let maxSumVolm = volms.maxValue { $0.sumVolm }
                var maxV = 0.0
                func append(_ secRange: Range<Double>) {
                    var si = Int(secRange.lowerBound * sampleRate).clipped(min: 0, max: lSamples.count)
                    var ei = Int(secRange.upperBound * sampleRate).clipped(min: 0, max: lSamples.count)
                    if si == ei {
                        si = max(si - rmsSize / 2, 0)
                        ei = min(ei + rmsSize / 2, lSamples.count)
                    }
                    let v = vDSP.rootMeanSquare(sSamples[si ..< ei])
                    if maxV < v {
                        maxV = v
                    }
                }
                var preSec: Double?
                for (i, volm) in volms.enumerated() {
                    if volm.sumVolm == maxSumVolm {
                        if preSec == nil {
                            preSec = i == 0 ? 0 : volm.sec
                        }
                    } else if let nPreSec = preSec {
                        append(nPreSec ..< volms[i - 1].sec)
                        preSec = nil
                    }
                }
                if let preSec {
                    append(preSec ..< max(preSec, self.secRange.length))
                }
                
                let spectrumScale = maxV == 0 ? 0 : 1 / maxV
                var nSamples = lSamples
                vDSP.multiply(spectrumScale, nSamples, result: &nSamples)
                return nSamples
            }
            
            if isFullNoise {
                let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount,
                                                      seed0: noiseSeed0, seed1: noiseSeed1)
                
                let overlapSamplesCount = vDSP.overlapSamplesCount(fftCount: stftCount)
                var mainNoiseSpectrogram = [[Double]](capacity: overlapSamplesCount / sampleCount)
                let noiseSpectrogram = stride(from: 0, to: sampleCount, by: overlapSamplesCount).map { i in
                    let sec = Double(i) * rSampleRate
                    let spectlope = pitbend.spectlope(atSec: sec)
                    let overtone = pitbend.overtone(atSec: sec)
                    let oddScale = overtone.isAll ? 1 : Volm.amp(fromVolm: overtone.oddVolm)
                    let evenScale = overtone.isAll ? -1 : -overtone.evenAmp
                    let (noiseSpectrum, mainNoiseSpectrum) = aNoiseSpectrum(fromNoise: spectlope,
                                                                      oddScale: oddScale,
                                                                      evenScale: -evenScale)
                    mainNoiseSpectrogram.append(mainNoiseSpectrum)
                    return noiseSpectrum
                }
                
                let mainSamples = clippedStft(vDSP.apply(noiseSamples, spectrogram: mainNoiseSpectrogram))
                let samples = clippedStft(vDSP.apply(noiseSamples, spectrogram: noiseSpectrogram))
                return normarizedWithRMS(from: mainSamples, to: samples)
            } else {
                let maxSpectlopeFq = pitbend.spectlopeInterpolation.keys
                    .maxValue { $0.value.maxFq } ?? Score.maxFq
                
                struct Frame {
                    var sec: Double, fq: Double, sinCount: Int, sin1X: Double, cos1X: Double
                }
                let pi2rs = .pi2 * rSampleRate
                var x = startPhase
                let frames: [Frame] = sampleCount.range.map { i in
                    let sec = Double(i) * rSampleRate
                    let fq = (rootFq * pitbend.fqScale(atSec: sec)).clipped(min: Score.minFq, max: cutFq)
                    let sinCount = Int((min(maxSpectlopeFq, cutFq) / fq).clipped(min: 1, max: Double(Int.max)))
                    let sin1X = Double.sin(x), cos1X = Double.cos(x)
                    x += fq * pi2rs
                    x = x.mod(.pi2)
                    return Frame(sec: sec, fq: fq, sinCount: sinCount, sin1X: sin1X, cos1X: cos1X)
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
                    evenScale = -firstOvertone.evenAmp
                var oddScales = [Double](capacity: sampleCount)
                var evenScales = [Double](capacity: sampleCount)
                for i in sampleCount.range {
                    let sec = Double(i) * rSampleRate
                    let overtone = pitbend.overtone(atSec: sec)
                    oddScales.append(Volm.amp(fromVolm: overtone.oddVolm))
                    evenScales.append(-overtone.evenAmp)
                }
                
                let maxSinCount = frames.maxValue { $0.sinCount }!
                let rsqfas = [0] + (1 ... maxSinCount).map { n in 1 / Double(n) ** sqfa }
                
                var noiseSpectrogram = [[Double]](capacity: sampleCount / overlapSamplesCount)
                var mainNoiseSpectrogram = [[Double]](capacity: sampleCount / overlapSamplesCount)
                var preSpectrum: [Double]!, preMainSpectrum: [Double]!
                
                var mainSamples = [Double](repeating: 0, count: sampleCount)
                var samples = [Double](repeating: 0, count: sampleCount)
                func append(at i: Int, spectrum: [Double], mainSpectrum: [Double]) {
                    let v = frames[i]
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
                    mainSamples[i] = vDSP.sum(vDSP.multiply(sins, mainSpectrum[..<sinCount]))
                    samples[i] = vDSP.sum(vDSP.multiply(sins, spectrum[..<sinCount]))
                }
                
                var maxSpectlope = pitbend.firstSpectlope, maxSumVolm = 0.0
                for (pit, sec) in zip(pitbend.pits, pitbend.secs) {
                    let pitch = (rootPitch + pitbend.pitch(atSec: sec)).clipped(min: Score.doubleMinPitch, max: cutPitch)
                    let sumVolm = pit.tone.spectlope.sumOvertonesVolm(fromPitch: pitch)
                    if sumVolm > maxSumVolm {
                        maxSpectlope = pit.tone.spectlope
                        maxSumVolm = sumVolm
                    }
                }
                
                func update(at i: Int) {
                    let frame = frames[i]
                    let sec = frame.sec
                    let spectlope = pitbend.spectlope(atSec: sec)
                    var sign = true, prePitch = 0.0, mainSpectrum = [Double](capacity: maxSinCount), rmsV = 0.0
                    var spectrum = (1 ... maxSinCount).map { n in
                        let fq = frame.fq * Double(n)
                        let pitch = Pitch.pitch(fromFq: fq)
                        let loudnessVolm = Loudness.volm40Phon(fromPitch: pitch)
                        let mainScale = (pitch - prePitch).clipped(min: 0, max: 2, newMin: 3, newMax: 1)
                        
                        let spectlopeVolm = spectlope.overtonesVolm(atPitch: pitch)
                        let overtoneScale = isEqualAllOvertone ?
                        (isAll || n == 1 ? (sign ? 1 : -1) : (sign ? oddScale : evenScale)) :
                        (n == 1 ? 1 : (sign ? oddScales[i] : evenScales[i]))
                        sign = !sign
                        prePitch = pitch
                        
                        let oa = overtoneScale * rsqfas[n]
                        let a = Volm.amp(fromVolm: spectlopeVolm) * oa
                        let amp = Volm.amp(fromVolm: loudnessVolm) * a
                        mainSpectrum.append(a * (fq > cutStartFq ? (fq < cutFq ? cutScales[Int(fq) - intCutStartFq] : 0) : 1) * mainScale)
                        
                        let maxSpectlopeVolm = maxSpectlope.volm(atPitch: pitch)
                        rmsV += (Volm.amp(fromVolm: maxSpectlopeVolm) * oa * (fq > cutStartFq ? (fq < cutFq ? cutScales[Int(fq) - intCutStartFq] : 0) : 1) * mainScale).squared
                        return amp
                    }
                    let rms = (rmsV / 2).squareRoot()
                    let scale = rms == 0 ? 0 : 1 / rms
                    let clearVolm = Loudness.clearVolm40Phon(fromPitch: Pitch.pitch(fromFq: frame.fq))
                    vDSP.multiply(scale * clearVolm, spectrum, result: &spectrum)
                    vDSP.multiply(scale, mainSpectrum, result: &mainSpectrum)
                    
                    if i > 0 {
                        for j in i - overlapSamplesCount + 1 ..< i {
                            let t = Double(j - i + overlapSamplesCount) / Double(overlapSamplesCount)
                            
                            var nSpectrum = [Double](capacity: maxSinCount)
                            var nMainSpectrum = [Double](capacity: maxSinCount)
                            for k in maxSinCount.range {
                                let fq = frames[j].fq * Double(k)
                                let amp = Double.linear(preSpectrum[k], spectrum[k], t: t)
                                nSpectrum.append(fq > cutStartFq ?
                                (fq < cutFq ? amp * cutScales[Int(fq) - intCutStartFq] : 0) : amp)
                                
                                let mainAmp = Double.linear(preMainSpectrum[k], mainSpectrum[k], t: t)
                                nMainSpectrum.append(fq > cutStartFq ?
                                (fq < cutFq ? mainAmp * cutScales[Int(fq) - intCutStartFq] : 0) : mainAmp)
                            }
                            append(at: j, spectrum: nSpectrum, mainSpectrum: nMainSpectrum)
                        }
                    }
                    append(at: i, spectrum: spectrum, mainSpectrum: mainSpectrum)
                    
                    let oddScale = isEqualAllOvertone ? oddScale : oddScales[i]
                    let evenScale = isEqualAllOvertone ? evenScale : evenScales[i]
                    if containsNoise {
                        let noiseSpectlope = pitbend.spectlope(atSec: sec)
                        var (noiseSpectrum, mainNoiseSpectrum) = aNoiseSpectrum(fromNoise: noiseSpectlope,
                                                                               oddScale: oddScale,
                                                                               evenScale: -evenScale)
                        vDSP.multiply(scale, noiseSpectrum, result: &noiseSpectrum)
                        vDSP.multiply(scale, mainNoiseSpectrum, result: &mainNoiseSpectrum)
                        
                        noiseSpectrogram.append(noiseSpectrum)
                        mainNoiseSpectrogram.append(mainNoiseSpectrum)
                    }
                    
                    preSpectrum = spectrum
                    preMainSpectrum = mainSpectrum
                }
                for i in stride(from: 0, to: sampleCount, by: overlapSamplesCount) {
                    update(at: i)
                }
                if sampleCount % overlapSamplesCount != 1 {
                    update(at: sampleCount - 1)
                }
                
                if containsNoise {
                    let noiseSamples = vDSP.gaussianNoise(count: sampleCount + stftCount,
                                                          seed0: noiseSeed0, seed1: noiseSeed1)
                    let nNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrogram: noiseSpectrogram))
                    let nMainNoiseSamples = clippedStft(vDSP.apply(noiseSamples, spectrogram: mainNoiseSpectrogram))
                    vDSP.add(samples, nNoiseSamples, result: &samples)
                    vDSP.add(mainSamples, nMainNoiseSamples, result: &mainSamples)
                }
                return normarizedWithRMS(from: mainSamples, to: samples)
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
            let frameSamples = (ni ..< ni + fftCount).map {
                $0 >= 0 && $0 < samples.count ? samples[$0] : 0
            }
            let inputRes = vDSP.multiply(windowSamples, frameSamples)
            frames.append(fft.frame(inputRes))
        }
        
        for i in 0 ..< frames.count {
            frames[i].dc = 0
            vDSP.multiply(frames[i].amps, spectrogram[i], result: &frames[i].amps)
        }
        
        var nSamples = [Double](repeating: 0, count: samples.count)
        for (j, i) in stride(from: halfFftCount, to: sampleCount + halfFftCount, by: overlapSamplesCount).enumerated() {
            let frame = frames[j]
            var frameSamples = ifft.resTransform(frame)
            frameSamples = vDSP.multiply(windowSamples, frameSamples)
            let ni = i - halfFftCount
            for k in ni ..< ni + fftCount {
                if k >= 0 && k < samples.count {
                    nSamples[k] += frameSamples[k - ni]
                }
            }
        }
        
        let acf = Double(fftCount) / vDSP.sum(windowSamples)
        vDSP.multiply(acf * acf, nSamples, result: &nSamples)
        
        return nSamples
    }
}

struct Notewave {
    var noStereoSampless = [[Double]]()
    var sampless = [[Double]]()
    var isLoop = false
}
extension Notewave {
    var sampleCount: Int {
        sampless.isEmpty ? 0 : sampless[0].count
    }
}
