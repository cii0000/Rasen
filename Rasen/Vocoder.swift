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

struct Wave: Codable, Hashable {
    var amp = 0.0, fq = 1.0, offsetTime = 0.0, phase = 0.0
}
extension Wave {
    func value(atT t: Double) -> Double {
        amp * .sin((t - offsetTime) * fq * 2 * .pi + phase)
    }
    var isEmpty: Bool {
        amp == 0 || fq == 0
    }
}

struct Reswave: Codable, Hashable {
    static let vibrato = Reswave(amp: 0.008 / 1.4321,
                                 fqs: [6, 12],
                                 phases: [0, .pi], fAlpha: 1)
    static let voiceVibrato = Reswave(amp: 0.0055 / 1.4321,
                                      fqs: [6, 12],
                                      phases: [0, .pi], fAlpha: 1)
    static let strongVibrato = Reswave(amp: 0.015 / 1.4321,
                                       fqs: [6, 12],
                                       phases: [0, .pi], fAlpha: 1)
    static let tremolo = Reswave(amp: 0.125,
                                 fqs: [6],
                                 phases: [0], fAlpha: 1)
    
    var waves = [Wave()]
    var beganTime = 0.0
}
extension Reswave {
    init(amp: Double, fqs: [Double], phases: [Double] = [],
         fAlpha: Double, beganTime: Double = 0) {
        let f0 = fqs.first!
        let sqfa = fAlpha * 0.5
        let waves: [Wave]
        if phases.isEmpty {
            waves = fqs.map { fq in
                Wave(amp: amp * (1 / ((fq / f0) ** sqfa)),
                     fq: fq)
            }
        } else {
            waves = fqs.enumerated().map { i, fq in
                Wave(amp: amp * (1 / ((fq / f0) ** sqfa)),
                     fq: fq, phase: phases[i])
            }
        }
        self.init(waves: waves, beganTime: beganTime)
    }
    
    func fqScale(atLocalTime t: Double) -> Double {
        let t = t - beganTime
        guard t >= 0 else { return 1 }//
        return 2 ** (waves.sum { $0.value(atT: t) })
    }
    
    func value(atLocalTime t: Double) -> Double {
        let t = t - beganTime
        guard t >= 0 else { return 0 }
        return waves.sum { $0.value(atT: t) }
    }
    
    var isEmpty: Bool {
        waves.contains(where: { $0.isEmpty })
    }
}

struct Rendnote {
    var fq: Double
    var sourceFilter: NoiseSourceFilter
    var formantFilterInterpolation: Interpolation<FormantFilter>?
    var deltaFormantFilterInterpolation: Interpolation<FormantFilter>?
    var fAlpha: Double
    var noiseSeed: UInt64
    var overtone: Overtone
    var pitbend: Pitbend
    var secRange: Range<Double>
    var startDeltaSec: Double
    var volumeAmp: Double
    var waver: Waver
    var sampleRate: Double
    var dftCount: Int
    var id = UUID()
}
extension Rendnote {
    static func seed(fromFq fq: Double, sec: Double) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(fq)
        hasher.combine(sec)
        return UInt64(abs(hasher.finalize()))
    }
    init(note: Note, score: Score, startSec: Double, sampleRate: Double) {
        let startBeat = note.beatRange.start
        let endBeat = note.beatRange.end
        let snapBeat = startBeat.interval(scale: Rational(1, 4))
        let sSec = Double(score.sec(fromBeat: startBeat)) + startSec
        let eSec = Double(score.sec(fromBeat: endBeat)) + startSec
        let snapSec = Double(score.sec(fromBeat: snapBeat)) + startSec
        let dSec = sSec - snapSec
        
        let pitbend = note.pitbend.with(scale: eSec - sSec)
        self.init(fq: note.fq,
                  sourceFilter: note.firstTone.noiseSourceFilter(isNoise: note.isNoise),
                  formantFilterInterpolation: nil,
                  deltaFormantFilterInterpolation: nil,
                  fAlpha: 1,
                  noiseSeed: Rendnote.seed(fromFq: note.fq, sec: sSec),
                  overtone: note.firstTone.overtone,
                  pitbend: pitbend,
                  secRange: sSec ..< eSec,
                  startDeltaSec: dSec,
                  volumeAmp: note.volumeAmp,
                  waver: .init(envelope: note.envelope, pitbend: pitbend),
                  sampleRate: sampleRate,
                  dftCount: Audio.defaultDftCount)
    }
}
extension Rendnote {
    func notewave(fftSize: Int = 1024,
                  cutFq: Double = 22050) -> Notewave {
        let scaledFq = fq.rounded(.down)
        let fqScale = fq / scaledFq
        
        guard !sourceFilter.fqSmps.isEmpty
                && sourceFilter.fqSmps.contains(where: { $0.y > 0 }) else {
            return .init(fqScale: fqScale, isLoop: true,
                         normalizedScale: 0, samples: [0])
        }
        
        let halfFFTSize = fftSize / 2
        let secLength = secRange.length.isInfinite ?
            1 : min(secRange.length, 100000)
        let releaseDur = self.waver.duration(fromSecLength: secLength)
        let nCount = Int((releaseDur * sampleRate).rounded(.up))
        
        let isStft = !pitbend.isEmptyPitch
            || formantFilterInterpolation != nil
        let isFullNoise = !sourceFilter.noiseTs.contains { $0 != 1 }
        let isNoise = sourceFilter.noiseTs.contains { $0 != 0 }
        
        let maxFq = sampleRate / 2
        let sqfa = fAlpha * 0.5
        let sqfas: [Double] = (0 ..< halfFFTSize).map {
            let nfq = Double($0) / Double(halfFFTSize) * maxFq
            return nfq == 0 ? 1 : 1 / (nfq / fq) ** sqfa
        }
        
        func spectrum(from fqSmps: [Point]) -> [Double] {
            var i = 1
            return (0 ..< halfFFTSize).map { fqi in
                let nfq = Double(fqi) / Double(halfFFTSize) * maxFq
                guard nfq >= scaledFq else { return 0 }
                while i + 1 < fqSmps.count, nfq > fqSmps[i].x { i += 1 }
                let smp: Double
                if let lastFqSmp = fqSmps.last, nfq >= lastFqSmp.x {
                    smp = lastFqSmp.y
                } else {
                    let preFqSmp = fqSmps[i - 1], fqSmp = fqSmps[i]
                    let t = preFqSmp.x == fqSmp.x ?
                        0 : (nfq - preFqSmp.x) / (fqSmp.x - preFqSmp.x)
                    smp = Double.linear(preFqSmp.y, fqSmp.y, t: t)
                }
                let amp = Volume(smp: smp).amp
                let alpha = sqfas[fqi]
                return amp * alpha
            }
        }
        
        func baseScale() -> Double {
            let halfDFTCount = dftCount / 2
            var vs = [Double](repeating: 0, count: halfDFTCount)
            let vsRange = 0 ... Double(vs.count - 1)
            let fd = Double(dftCount) / sampleRate
            var overtones = [Int: Int]()
            
            func enabledIndex(atFq fq: Double) -> Double? {
                let ni = fq * fd
                return fq < cutFq && vsRange.contains(ni) ? ni : nil
            }
            
            var nfq = scaledFq, fqI = 1
            if overtone.isAll {
                while let ni = enabledIndex(atFq: nfq) {
                    let nii = Int(ni)
                    let sfScale = sourceFilter.amp(atFq: nfq * fqScale)
                    vs[nii] = sfScale / (Double(fqI) ** sqfa)
                    overtones[nii] = fqI
                    nfq += scaledFq
                    fqI += 1
                }
            } else if overtone.isOne {
                if let ni = enabledIndex(atFq: nfq) {
                    let nii = Int(ni)
                    let sfScale = sourceFilter.amp(atFq: nfq * fqScale)
                    vs[nii] = sfScale
                    overtones[nii] = fqI
                }
            } else {
                while let ni = enabledIndex(atFq: nfq) {
                    let nii = Int(ni)
                    let overtoneSmp = overtone.smp(at: fqI)
                    let sfSmp = sourceFilter.smp(atFq: nfq * fqScale)
                    vs[nii] = Volume(smp: overtoneSmp * sfSmp).amp / (Double(fqI) ** sqfa)
                    overtones[nii] = fqI
                    nfq += scaledFq
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
            var sSamples = dft?.transform(real: inputRes,
                                          imaginary: inputIms).real
                ?? [Double](repeating: 0, count: dftCount)
            vDSP.multiply(1 / Double(dftCount * 2), sSamples,
                          result: &sSamples)
            let mm = vDSP.maximumMagnitude(sSamples)
            return (1 / mm).clipped(min: 0, max: 2)
        }
        let normalizedScale = baseScale()
        
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
                        vs[nii] = fqI > 0 ? Volume(smp: overtone.smp(at: fqI)).amp : 0
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
                
                var nfq = scaledFq, fqI = 1
                if overtone.isAll {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        let sfScale = sourceFilter.noisedAmp(atFq: nfq * fqScale)
                        vs[nii] = sfScale / (Double(fqI) ** sqfa)
                        overtones[nii] = fqI
                        nfq += scaledFq
                        fqI += 1
                    }
                } else if overtone.isOne {
                    if let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        let sfScale = sourceFilter.noisedAmp(atFq: nfq * fqScale)
                        vs[nii] = sfScale
                        overtones[nii] = fqI
                    }
                } else {
                    while let ni = enabledIndex(atFq: nfq) {
                        let nii = Int(ni)
                        let overtoneSmp = overtone.smp(at: fqI)
                        let sfAmp = sourceFilter.noisedAmp(atFq: nfq * fqScale)
                        vs[nii] = Volume(smp: overtoneSmp).amp * sfAmp / (Double(fqI) ** sqfa)
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
                if !pitbend.isEmptyPitch && samples.count >= 4 {
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
                            
                            let a0 = sai - 1 >= 0 ?
                                samples[sai - 1] : 0
                            let a1 = samples[sai]
                            let a2 = sai + 1 < samples.count ?
                                samples[sai + 1] : 0
                            let a3 = sai + 2 < samples.count ?
                                samples[sai + 2] : 0
                            
                            let t = phase - Double(sai)
                            n = Double.spline(a0, a1, a2, a3, t: t)
                        }
                        nSamples.append(n)
                        
                        let sec = Double(i) * rSampleRate
                        let vbScale = pitbend.fqScale(atT: sec)
                        phase += vbScale * fqScale
                        phase = phase.loop(start: 0, end: dCount)
                    }
                    samples = nSamples
                }
                
                if let formantFilterInterpolation {
                    let spectrumCount = vDSP
                        .spectramCount(sampleCount: samples.count,
                                       fftSize: fftSize)
                    let rDurSp = releaseDur / Double(spectrumCount)
                    let spectrogram = (0 ..< spectrumCount).map { i in
                        let sec = Double(i) * rDurSp
                        let formantFilter = formantFilterInterpolation.value(withTime: sec)
                            ?? formantFilterInterpolation.keys.last?.value
                            ?? .empty
                        let sourceFilter = sourceFilter.union(NoiseSourceFilter(formantFilter))
                        return vDSP.subtract(spectrum(from: sourceFilter.fqSmps),
                                             spectrum(from: sourceFilter.noiseFqSmps))
                    }
                    samples = vDSP.apply(samples, scales: spectrogram)
                } else {
                    let spectrum = vDSP.subtract(spectrum(from: sourceFilter.fqSmps),
                                                 spectrum(from: sourceFilter.noiseFqSmps))
                    samples = vDSP.apply(samples, scales: spectrum)
                }
            }
        }
        
        if isNoise {
            let noiseSamples = vDSP.gaussianNoise(count: nCount,
                                                  seed: noiseSeed)
            
            var nNoiseSamples: [Double]
            if let formantFilterInterpolation {
                let spectrumCount = vDSP
                    .spectramCount(sampleCount: noiseSamples.count,
                                   fftSize: fftSize)
                let rDurSp = releaseDur / Double(spectrumCount)
                let spectrogram = (0 ..< spectrumCount).map { i in
                    let t = Double(i) * rDurSp
                    let formantFilter = formantFilterInterpolation.value(withTime: t)
                        ?? formantFilterInterpolation.keys.last?.value
                        ?? .empty
                    let sourceFilter = NoiseSourceFilter(formantFilter)
                    return spectrum(from: sourceFilter.noiseFqSmps)
                }
                nNoiseSamples = vDSP.apply(noiseSamples, scales: spectrogram)
            } else {
                let spectrum = spectrum(from: sourceFilter.noiseFqSmps)
                nNoiseSamples = vDSP.apply(noiseSamples, scales: spectrum)
            }
            vDSP.multiply(Double(fftSize) / scaledFq, nNoiseSamples,
                          result: &nNoiseSamples)
            
            if isFullNoise {
                samples = nNoiseSamples
            } else {
                let nSamples = samples.loopExtended(count: nCount)
                samples = vDSP.add(nSamples, nNoiseSamples)
            }
        }
        
        vDSP.multiply(normalizedScale, samples, result: &samples)
        
        if samples.contains(where: { $0.isNaN || $0.isInfinite }) {
            print("nan", samples.contains(where: { $0.isInfinite }))
        }
        return .init(fqScale: isStft ? 1 : fqScale,
                     isLoop: !isStft,
                     normalizedScale: 1,
                     samples: samples)
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
            let doi = i - overlapSize
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
            let doi = i - overlapSize
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

struct Overtone: Hashable, Codable {
    var evenSmp = 1.0, oddSmp = 1.0
}
extension Overtone {
    var isAll: Bool {
        evenSmp == 1 && oddSmp == 1
    }
    var isOne: Bool {
        evenSmp == 0 && oddSmp == 0
    }
    func smp(at i: Int) -> Double {
        i == 1 ? 1 : (i % 2 == 0 ? evenSmp : oddSmp)
    }
}

struct NoiseSourceFilter: Hashable, Codable {
    static let maxFq = 22050.0, maxMel = 4000.0
    
    var fqSmps = [Point(0, 1), Point(4000, 0)]
    var noiseFqSmps = [Point(0, 0), Point(4000, 0)]
    var noiseTs = [0.0, 0.0]
}
extension NoiseSourceFilter {
    mutating func formMultiplyFq(_ x: Double) {
        fqSmps = fqSmps.map { .init($0.x * x, $0.y) }
        noiseFqSmps = noiseFqSmps.map { .init($0.x * x, $0.y) }
    }
    func multiplyFq(_ x: Double) -> Self {
        var n = self
        n.formMultiplyFq(x)
        return n
    }
}

extension NoiseSourceFilter {
    init(fqSmps: [Point] = [], noiseFqSmps: [Point] = []) {
        if noiseFqSmps.isEmpty {
            self.noiseFqSmps = fqSmps.map { Point($0.x, 0) }
            noiseTs = fqSmps.map { _ in 0 }
        } else {
            self.noiseFqSmps = noiseFqSmps
        }
        if fqSmps.isEmpty {
            self.fqSmps = noiseFqSmps
            noiseTs = noiseFqSmps.map { _ in 1 }
        } else {
            self.fqSmps = fqSmps
        }
        if noiseTs.isEmpty {
            noiseTs = fqSmps.enumerated().map {
                $0.element.y == 0 ?
                    0 : noiseFqSmps[$0.offset].y / $0.element.y
            }
        }
    }
    var unnoiseScales: [Point] {
        noiseFqSmps.enumerated().map {
            let scale = fqSmps[$0.offset]
            return Point(scale.x, scale.y - $0.element.y)
        }
    }
    
    func union(_ other: Self) -> Self {
        self
//        fqSmps
//        other
    }
}
extension NoiseSourceFilter {
    init(_ formantFilter: FormantFilter) {
        var ps = [Point]()
        ps.reserveCapacity(formantFilter.count * 4)
        var ns = [Point]()
        ns.reserveCapacity(formantFilter.count * 4)
        for (i, f) in formantFilter.enumerated() {
            ps.append(.init(f.sFq, f.smp))
            ps.append(.init(f.eFq, f.smp))
            ns.append(.init(f.sFq, f.noiseT))
            ns.append(.init(f.eFq, f.noiseT))
            if i + 1 < formantFilter.count {
                let nextF = formantFilter[i + 1]
                if f.eeFq <= nextF.ssFq {
                    ps.append(f.eeFqSmp)
                    ps.append(.init(nextF.ssFq, f.edSmp))
                    ns.append(f.eeFqNoiseT)
                    ns.append(.init(nextF.ssFq, f.edNoiseT))
                } else {
                    func smpP() -> Point? {
                        Edge(f.eFqSmp, f.eeFqSmp)
                            .intersection(Edge(.init(nextF.ssFq, f.edSmp),
                                               nextF.sFqSmp))
                    }
                    func noiseSmpP() -> Point? {
                        Edge(f.eFqNoiseT, f.eeFqNoiseT)
                            .intersection(Edge(.init(nextF.ssFq, f.edNoiseT),
                                               nextF.sFqNoiseT))
                    }
                    func aSmpP(fromNoiseSmpP noiseSmpP: Point,
                               midP: Point? = nil) -> Point {
                        let edge: Edge
                        if let midP {
                            edge = noiseSmpP.x < midP.x ?
                            Edge(f.sFqSmp, midP) :
                            Edge(midP, nextF.eFqSmp)
                        } else {
                            edge = Edge(f.sFqSmp, nextF.eFqSmp)
                        }
                        return .init(noiseSmpP.x, edge.y(atX: noiseSmpP.x))
                    }
                    func aNoiseSmpP(fromSmpP smpP: Point,
                                    midP: Point? = nil) -> Point {
                        let edge: Edge
                        if let midP {
                            edge = smpP.x < midP.x ?
                            Edge(f.sFqNoiseT, midP) :
                            Edge(midP, nextF.eFqNoiseT)
                        } else {
                            edge = Edge(f.sFqNoiseT, nextF.eFqNoiseT)
                        }
                        return .init(smpP.x, edge.y(atX: smpP.x))
                    }
                    
                    if let smpP = smpP() {
                        if let noiseSmpP = noiseSmpP() {
                            let aSmpP = aSmpP(fromNoiseSmpP: noiseSmpP, midP: smpP)
                            if smpP.x < aSmpP.x {
                                ps.append(smpP)
                                ps.append(aSmpP)
                            } else {
                                ps.append(aSmpP)
                                ps.append(smpP)
                            }
                            
                            let aNoiseSmpP = aNoiseSmpP(fromSmpP: smpP, midP: noiseSmpP)
                            if noiseSmpP.x < aNoiseSmpP.x {
                                ns.append(noiseSmpP)
                                ns.append(aNoiseSmpP)
                            } else {
                                ns.append(aNoiseSmpP)
                                ns.append(noiseSmpP)
                            }
                        } else {
                            ps.append(smpP)
                            ns.append(aNoiseSmpP(fromSmpP: smpP))
                        }
                    } else if let noiseSmpP = noiseSmpP() {
                        ps.append(aSmpP(fromNoiseSmpP: noiseSmpP))
                        ns.append(noiseSmpP)
                    }
                }
            } else {
                ps.append(.init(f.eeFq, f.edSmp))
                ns.append(.init(f.eeFq, f.edNoiseT))
            }
        }
        
        let noiseTs = ns.map { $0.y }
        ns = ns.enumerated().map {
            .init($0.element.x, $0.element.y * ps[$0.offset].y)
        }
        self.init(fqSmps: ps, noiseFqSmps: ns, noiseTs: noiseTs)
    }
}
extension NoiseSourceFilter {
    var isEmpty: Bool {
        fqSmps.isEmpty
    }
    
    func smp(atMel mel: Double) -> Double {
        smp(atFq: Mel.fq(fromMel: mel))
    }
    func smp(atFq fq: Double) -> Double {
        guard !fqSmps.isEmpty else { return 1 }
        var preFq = fqSmps.first!.x, preSmp = fqSmps.first!.y
        guard fq >= preFq else { return fqSmps.first!.y }
        for scale in fqSmps {
            let nextFq = scale.x, nextSmp = scale.y
            guard preFq < nextFq else {
                preFq = nextFq
                preSmp = nextSmp
                continue
            }
            if fq < nextFq {
                let t = (fq - preFq) / (nextFq - preFq)
                let smp = Double.linear(preSmp, nextSmp, t: t)
                return smp
            }
            preFq = nextFq
            preSmp = nextSmp
        }
        return fqSmps.last!.y
    }
    
    func amp(atMel mel: Double) -> Double {
        amp(atFq: Mel.fq(fromMel: mel))
    }
    func amp(atFq fq: Double) -> Double {
        guard !fqSmps.isEmpty else { return 1 }
        var preFq = fqSmps.first!.x, preSmp = fqSmps.first!.y
        guard fq >= preFq else { return Volume(smp: fqSmps.first!.y).amp }
        for scale in fqSmps {
            let nextFq = scale.x, nextSmp = scale.y
            guard preFq < nextFq else {
                preFq = nextFq
                preSmp = nextSmp
                continue
            }
            if fq < nextFq {
                let t = (fq - preFq) / (nextFq - preFq)
                let smp = Double.linear(preSmp, nextSmp, t: t)
                return Volume(smp: smp).amp
            }
            preFq = nextFq
            preSmp = nextSmp
        }
        return Volume(smp: fqSmps.last!.y).amp
    }
    func noiseT(atMel mel: Double) -> Double {
        noiseT(atFq: Mel.fq(fromMel: mel))
    }
    func noiseT(atFq fq: Double) -> Double {
        guard !noiseFqSmps.isEmpty else { return 0 }
        
        var preFq = noiseFqSmps.first!.x
        guard fq >= preFq else { return noiseTs.first! }
        for scale in noiseFqSmps {
            let nextFq = scale.x
            guard preFq < nextFq else {
                preFq = nextFq
                continue
            }
            if fq < nextFq {
                return (fq - preFq) / (nextFq - preFq)
            }
            preFq = nextFq
        }
        return noiseTs.last!
    }
    func noiseAmp(atMel mel: Double) -> Double {
        noiseAmp(atFq: Mel.fq(fromMel: mel))
    }
    func noiseAmp(atFq fq: Double) -> Double {
        guard !noiseFqSmps.isEmpty else { return 0 }
        
        var preFq = noiseFqSmps.first!.x, preSmp = noiseFqSmps.first!.y
        guard fq >= preFq else { return Volume(smp: noiseFqSmps.first!.y).amp }
        for scale in noiseFqSmps {
            let nextFq = scale.x, nextSmp = scale.y
            guard preFq < nextFq else {
                preFq = nextFq
                preSmp = nextSmp
                continue
            }
            if fq < nextFq {
                let t = (fq - preFq) / (nextFq - preFq)
                let smp = Double.linear(preSmp, nextSmp, t: t)
                return Volume(smp: smp).amp
            }
            preFq = nextFq
            preSmp = nextSmp
        }
        return Volume(smp: noiseFqSmps.last!.y).amp
    }
    func noisedAmp(atMel mel: Double) -> Double {
        noisedAmp(atFq: Mel.fq(fromMel: mel))
    }
    func noisedAmp(atFq fq: Double) -> Double {
        let amp = amp(atFq: fq)
        let noiseAmp = noiseAmp(atFq: fq)
        return amp - noiseAmp
    }
}

struct Waver {
    let envelope: Envelope
    let pitbend: Pitbend
    let attack, decay, sustainSmp, release: Double
    let attackAndDecay, sustainAmp: Double
    let rAttack, rDecay, rSustain, rRelease: Double
    
    init(envelope: Envelope, pitbend: Pitbend) {
        self.envelope = envelope
        self.pitbend = pitbend
        
        attack = max(envelope.attackSec, 0)
        decay = envelope.decaySec
        sustainAmp = envelope.sustainAmp
        sustainSmp = Volume(amp: envelope.sustainAmp).smp
        release = max(envelope.releaseSec, 0)
        attackAndDecay = attack + decay
        rAttack = 1 / attack
        rDecay = 1 / decay
        rSustain = 1 / sustainSmp
        rRelease = 1 / release
    }
}
extension Waver {
    func duration(fromSecLength sl: Double) -> Double {
        sl < attackAndDecay ? attackAndDecay + release : sl + release
    }
    func volumeAmp(atTime t: Double, releaseTime rt: Double?,
                   startTime: Double) -> Double {
        if let rt {
            volumeAmp(atLocalTime: t - startTime,
                      releaseLocalTime: rt - startTime)
        } else {
            volumeAmp(atLocalTime: t - startTime,
                      releaseLocalTime: nil)
        }
    }
    func volumeAmp(atLocalTime t: Double,
                   releaseLocalTime rt: Double?) -> Double {
        if t < 0 {
            return 0
        } else if attack > 0 && t < attack {
            return Volume(smp: t * rAttack).amp
        } else {
            let nt = t - attack
            if decay > 0 && nt < decay {
                return Volume(smp: .linear(1, sustainSmp, t: nt * rDecay)).amp
            } else if let rt {
                let rt = rt < attackAndDecay ? attackAndDecay : rt
                if t < rt {
                    return sustainAmp
                } else {
                    let nnt = t - rt
                    if release > 0 && nnt < release {
                        return Volume(smp: .linear(sustainSmp, 0, t: nnt * rRelease)).amp
                    } else {
                        return 0
                    }
                }
            } else {
                return sustainAmp
            }
        }
    }
}

struct Notewave {
    let fqScale: Double
    let isLoop: Bool
    let normalizedScale: Double
    let samples: [Double]
}
extension Notewave {
    func sample(at i: Int,
                sec: Double, releaseSec: Double? = nil,
                volumeAmp: Double, from waver: Waver,
                atPhase phase: inout Double) -> Double {
        guard samples.count >= 4 else { return 0 }
        let count = Double(samples.count)
        if !isLoop && phase >= count { return 0 }
        phase = phase.loop(start: 0, end: count)
        
        let n: Double
        if phase.isInteger {
            n = samples[Int(phase)] * volumeAmp
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
            n = sy * volumeAmp
        }
        
//        let vbScale = waver.pitbend.isEmpty ?
//        1 : waver.pitbend.fqScale(atT: sec)
        phase += fqScale// * vbScale
        phase = phase.loop(start: 0, end: count)
        
        return n
    }
    
    static func phase(sec: Double, releaseSec: Double? = nil,
                      from waver: Waver,
                      atPhase phase: inout Double,
                      fqScale: Double, samplesCount: Int) {
        let vbScale = waver.pitbend.isEmpty ?
            1 : waver.pitbend.fqScale(atT: sec)
        phase += fqScale * vbScale
        phase = phase.loop(0 ..< Double(samplesCount))
    }
    static func phaseScale(sec: Double, releaseSec: Double? = nil,
                           from waver: Waver) -> Double {
        let vbScale = waver.pitbend.isEmpty ?
            1 : waver.pitbend.fqScale(atT: sec)
        return vbScale
    }
}
