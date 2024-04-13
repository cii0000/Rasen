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

import Accelerate
import ComplexModule

extension vDSP {
    static func linspace(start: Double, end: Double, count: Int) -> [Double] {
        .init(unsafeUninitializedCapacity: count) { buffer, initializedCount in
            vDSP.linearInterpolate(values: [start, end],
                                   atIndices: [0, Double(count - 1)],
                                   result: &buffer)
            initializedCount = count
        }
    }
}

typealias FFTComp = Complex<Double>
struct FFT {
    var vdft: VDFT<Double>
    var ims: [Double]
    
    init(count: Int) throws {
        self.vdft = try VDFT(previous: nil,
                             count: count,
                             direction: .forward,
                             transformType: .complexComplex,
                             ofType: Double.self)
        ims = .init(repeating: 0, count: count)
    }
    func transform(_ x: [Double]) -> [FFTComp] {
        let v = vdft.transform(real: x, imaginary: ims)
        return zip(v.real, v.imaginary).map { .init($0.0, $0.1) }
    }
    func transform(_ x: [FFTComp]) -> [FFTComp] {
        let v = vdft.transform(real: x.map { $0.real }, imaginary: x.map { $0.imaginary })
        return zip(v.real, v.imaginary).map { .init($0.0, $0.1) }
    }
    
    static func fftfreq(_ n: Int, _ d: Double) -> [Double] {
        let v = 1 / (Double(n) * d)
        var results = [Int](capacityUninitialized: n)
        let nn = (n - 1) / 2 + 1
        (0 ..< nn).forEach { results[$0] = $0 }
        (nn ..< results.count).forEach { results[$0] = -(n / 2) + $0 - nn }
        return results.map { Double($0) * v }
    }
}
struct IFFT {
    var vdft: VDFT<Double>
    var ims: [Double]
    
    init(count: Int) throws {
        self.vdft = try VDFT(previous: nil,
                             count: count,
                             direction: .inverse,
                             transformType: .complexComplex,
                             ofType: Double.self)
        ims = .init(repeating: 0, count: count)
    }
    func transform(_ x: [FFTComp]) -> [FFTComp] {
        let v = vdft.transform(real: x.map { $0.real }, imaginary: x.map { $0.imaginary })
        return zip(v.real, v.imaginary).map { .init($0.0, $0.1) }
    }
}

struct FilterBank {
    let type: BankType
    private let filterBank: [Double]
    let sampleCount, filterBankCount, cutMinFqI, cutMaxFqI: Int
    
    enum BankType {
        case pitch, mel
    }
    
    init (sampleCount: Int, filterBankCount: Int = 512,
          minPitch: Double, maxPitch: Double, maxFq: Double) {
        self.init(sampleCount: sampleCount, minV: minPitch, maxV: maxPitch, maxFq: maxFq, .pitch)
    }
    init (sampleCount: Int, filterBankCount: Int = 512,
          minMel: Double, maxMel: Double, maxFq: Double) {
        self.init(sampleCount: sampleCount, minV: minMel, maxV: maxMel, maxFq: maxFq, .mel)
    }
    init (sampleCount: Int, filterBankCount: Int = 512,
          minV: Double, maxV: Double, maxFq: Double, _ type: BankType) {
        let bankWidth = (maxV - minV) / Double(filterBankCount - 1)
        let filterBankFqs = switch type {
        case .pitch:
            stride(from: minV, to: maxV, by: bankWidth).map {
                let fq = Pitch.fq(fromPitch: $0)
                return Int(((fq / maxFq) * Double(sampleCount)).rounded())
                    .clipped(min: 0, max: sampleCount - 1)
            }
        case .mel:
            stride(from: minV, to: maxV, by: bankWidth).map {
                let fq = Mel.fq(fromMel: $0)
                return Int(((fq / maxFq) * Double(sampleCount)).rounded())
                    .clipped(min: 0, max: sampleCount - 1)
            }
        }
        
        var filterBank = [Double](repeating: 0, count: sampleCount * filterBankCount)
        var baseValue = 1.0, endValue = 0.0
        for i in 0 ..< filterBankFqs.count {
            let row = i * sampleCount
            
            let startFq = filterBankFqs[max(0, i - 1)]
            let centerFq = filterBankFqs[i]
            let endFq = i + 1 < filterBankFqs.count ? filterBankFqs[i + 1] : sampleCount - 1
            
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
        
        self.type = type
        self.filterBank = filterBank
        self.sampleCount = sampleCount
        self.filterBankCount = filterBankCount
        cutMinFqI = filterBankFqs.first!
        cutMaxFqI = filterBankFqs.last!
    }
    
    func transform(_ input: [Double]) -> [Double] {
        var input = input
        for i in 0 ..< cutMinFqI {
            input[i] = 0
        }
        for i in cutMaxFqI ..< input.count {
            input[i] = 0
        }
        
        let nf = [Double](unsafeUninitializedCapacity: filterBankCount) { buffer, initializedCount in
            input.withUnsafeBufferPointer { nPtr in
                filterBank.withUnsafeBufferPointer { fPtr in
                    cblas_dgemm(CblasRowMajor,
                                CblasTrans, CblasTrans,
                                1,
                                filterBankCount,
                                sampleCount,
                                1,
                                nPtr.baseAddress,
                                1,
                                fPtr.baseAddress,
                                sampleCount,
                                0,
                                buffer.baseAddress, filterBankCount)
                }
            }
            
            initializedCount = filterBankCount
        }
        
        var output = input
        let indices = vDSP.ramp(in: 0 ... Double(sampleCount), count: nf.count)
        vDSP.linearInterpolate(values: nf, atIndices: indices, result: &output)
        return output
    }
}

struct Spectrogram {
    struct Frame {
        var sec = 0.0
        var stereos = [Stereo]()
    }
    
    var frames = [Frame]()
    var stereoCount = 0
    var type = FqType.pitch
    var durSec = 0.0
    
    static let minLinearFq = 0.0, maxLinearFq = Audio.defaultExportSampleRate / 2
    static let minPitch = Score.doubleMinPitch, maxPitch = Score.doubleMaxPitch
    
    enum FqType {
        case linear, pitch
    }
    init(_ buffer: PCMBuffer,
         windowSize: Int = 2048, windowOverlap: Double = 0.875,
         isNormalized: Bool = true,
         type: FqType = .pitch) {
        
        let windowSize = Int(.exp2(.log2(Double(windowSize))).rounded(.up))
        
        guard buffer.frameCount < Int(buffer.sampleRate) * 60 * 10 else {
            print("unsupported")
            return
        }
        
        var buffer = buffer
        if buffer.sampleRate != Audio.defaultExportSampleRate {
            guard let nBuffer = try? buffer.convertDefaultFormat(isExportFormat: true) else { return }
            buffer = nBuffer
        }
        
        let channelCount = buffer.channelCount
        let frameCount = buffer.frameCount
        guard channelCount >= 1, windowSize > 0, frameCount >= windowSize,
              let dft = try? FFT(count: windowSize) else { return }
        
        let overlapCount = Int(Double(windowSize) * (1 - windowOverlap))
        let windowWave = vDSP.window(ofType: Double.self,
                                     usingSequence: .hanningNormalized,
                                     count: windowSize,
                                     isHalfWindow: false)
        
        let sampleRate = buffer.sampleRate
        let nd = 1 / Double(windowSize)
        let volmCount = windowSize / 2
        
        let secs: [(i: Int, sec: Double)] = stride(from: 0, to: frameCount, by: overlapCount).map { i in
            (i, Double(i) / sampleRate)
        }
        let loudnessScales = volmCount.range.map {
            let fq = Double.linear(Self.minLinearFq, Self.maxLinearFq,
                                   t: Double($0) / Double(volmCount))
            return Loudness.reverseVolm40Phon(fromFq: fq)
        }
        
        var ctss: [[[Double]]]
        switch type {
        case .linear:
            ctss = channelCount.range.map { ci in
                let amps = buffer.channelAmpsFromFloat(at: ci)
                return secs.map { (ti, sec) in
                    var wave = [Double](capacity: windowSize)
                    for j in (ti - windowSize / 2) ..< (ti - windowSize / 2 + windowSize) {
                        wave.append(j >= 0 && j < frameCount ? amps[j] : 0)
                    }
                    
                    let inputRs = vDSP.multiply(windowWave, wave)
                    let outputs = dft.transform(inputRs)
                    
                    return volmCount.range.map {
                        if $0 == 0 {
                            return 0.0
                        } else {
                            let amp = outputs[$0].length * nd
                            let volm = Volm.volm(fromAmp: amp)
                            return loudnessScales[$0] * volm
                        }
                    }
                }
            }
        case .pitch:
            let filterBank = FilterBank(sampleCount: volmCount,
                                        minPitch: Self.minPitch, maxPitch: Self.maxPitch,
                                        maxFq: Self.maxLinearFq)

            ctss = channelCount.range.map { ci in
                let amps = buffer.channelAmpsFromFloat(at: ci)
                return secs.map { (ti, sec) in
                    var wave = [Double](capacity: windowSize)
                    for j in (ti - windowSize / 2) ..< (ti - windowSize / 2 + windowSize) {
                        wave.append(j >= 0 && j < frameCount ? amps[j] : 0)
                    }
                    
                    let inputRs = vDSP.multiply(windowWave, wave)
                    let outputs = dft.transform(inputRs)
                    
                    let volms = volmCount.range.map {
                        if $0 == 0 {
                            return 0.0
                        } else {
                            let amp = outputs[$0].length * nd
                            let volm = Volm.volm(fromAmp: amp)
                            return loudnessScales[$0] * volm
                        }
                    }
                    return filterBank.transform(volms)
                }
            }
            
            let windowSize2 = Int(.exp2(.log2(Double(windowSize * 4))).rounded(.up))
            if let dft2 = try? FFT(count: windowSize2) {
                let overlapCount2 = Int(Double(windowSize2) * (1 - windowOverlap))
                let windowWave2 = vDSP.window(ofType: Double.self,
                                              usingSequence: .hanningNormalized,
                                              count: windowSize2,
                                              isHalfWindow: false)
                
                let nd2 = 1 / Double(windowSize2)
                let volmCount2 = windowSize2 / 2
                
                let secs2: [(i: Int, sec: Double)] = stride(from: 0, to: frameCount, by: overlapCount2).map { i in
                    (i, Double(i) / sampleRate)
                }
                let loudnessScales2 = volmCount2.range.map {
                    let fq = Double.linear(Self.minLinearFq, Self.maxLinearFq,
                                           t: Double($0) / Double(volmCount2))
                    return Loudness.reverseVolm40Phon(fromFq: fq)
                }
                
                let filterBank2 = FilterBank(sampleCount: volmCount2,
                                             minPitch: Self.minPitch, maxPitch: Self.maxPitch,
                                             maxFq: Self.maxLinearFq)

                channelCount.range.forEach { ci in
                    let amps = buffer.channelAmpsFromFloat(at: ci)
                    let tss2 = secs2.map { (ti, sec) in
                        var wave2 = [Double](capacity: windowSize2)
                        for j in (ti - windowSize2 / 2) ..< (ti - windowSize2 / 2 + windowSize2) {
                            wave2.append(j >= 0 && j < frameCount ? amps[j] : 0)
                        }
                        
                        let inputRs2 = vDSP.multiply(windowWave2, wave2)
                        let outputs2 = dft2.transform(inputRs2)
                        let volms = volmCount2.range.map {
                            if $0 == 0 {
                                return 0.0
                            } else {
                                let amp = outputs2[$0].length * nd2
                                let volm = Volm.volm(fromAmp: amp)
                                return loudnessScales2[$0] * volm
                            }
                        }
                        let nVolms = filterBank2.transform(volms)
                        return stride(from: 0, to: nVolms.count, by: 4).map { nVolms[$0] }
                    }
                    
                    secs.enumerated().forEach { ti, v in
                        let ti2 = min(Int((Double(tss2.count * ti) / Double(secs.count)).rounded()), tss2.count - 1)
                        for si in 0 ..< volmCount / 2 {
                            let t = si < volmCount * 3 / 8 ?
                            Double(si).clipped(min: Double(volmCount * 1 / 8),
                                               max: Double(volmCount * 3 / 8),
                                               newMin: 0, newMax: 0.5) :
                            Double(si).clipped(min: Double(volmCount * 3 / 8),
                                               max: Double(volmCount / 2),
                                               newMin: 0.5, newMax: 1)
                            ctss[ci][ti][si] = Double.linear(tss2[ti2][si], ctss[ci][ti][si], t: t)
                        }
                    }
                }
            }
        }
    
        func stereo(fromVolms volms: [Double]) -> Stereo {
            if buffer.channelCount == 2 {
                let leftVolm = volms[0]
                let rightVolm = volms[1]
                let volm = (leftVolm + rightVolm) / 2
                let pan = leftVolm != rightVolm ?
                (leftVolm < rightVolm ?
                 -(leftVolm / (leftVolm + rightVolm) - 0.5) * 2 :
                    (rightVolm / (leftVolm + rightVolm) - 0.5) * 2) :
                0
                return .init(volm: volm, pan: pan)
            } else {
                return .init(volm: volms[0], pan: 0)
            }
        }
        
        var frames = secs.enumerated().map { ti, v in
            return Frame(sec: v.sec, stereos: volmCount.range.map { si in
                stereo(fromVolms: channelCount.range.map { ci in ctss[ci][ti][si] })
            })
        }
        
        if isNormalized {
            var nMaxVolm = 0.0
            for frame in frames {
                nMaxVolm = max(nMaxVolm, frame.stereos.max(by: { $0.volm < $1.volm })!.volm)
            }
            let rMaxVolm = nMaxVolm == 0 ? 0 : 1 / nMaxVolm
            for i in 0 ..< frames.count {
                for j in 0 ..< frames[i].stereos.count {
                    frames[i].stereos[j].volm = (frames[i].stereos[j].volm * rMaxVolm)
                        .clipped(min: 0, max: 1)
                }
            }
        }
        
        self.frames = frames
        self.stereoCount = frames.isEmpty ? 0 : frames[0].stereos.count
        self.type = type
        self.durSec = Double(frameCount) / sampleRate
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
    
    static let (editRedRatio, editGreenRatio) = {
        var redColor = Color(red: 0.5, green: 0, blue: 0)
        var greenColor = Color(red: 0, green: 0.5, blue: 0)
        if redColor.lightness < greenColor.lightness {
            greenColor.lightness = redColor.lightness
        } else {
            redColor.lightness = greenColor.lightness
        }
        return (Double(redColor.rgba.r), Double(greenColor.rgba.g))
    } ()
    
    func image(b: Double = 0, width: Int = 1024, at xi: Int = 0) -> Image? {
        let h = stereoCount
        guard let bitmap = Bitmap<UInt8>(width: width, height: h, colorSpace: .sRGB) else { return nil }
        func rgamma(_ x: Double) -> Double {
            x <= 0.0031308 ?
            12.92 * x :
            1.055 * (x ** (1 / 2.4)) - 0.055
        }
        
        for x in 0 ..< width {
            for y in 0 ..< h {
                let stereo = frames[x + xi].stereos[h - 1 - y]
                let alpha = rgamma(stereo.volm)
                guard !alpha.isNaN else {
                    print("NaN:", stereo.volm)
                    continue
                }
                bitmap[x, y, 0] = stereo.pan > 0 ? UInt8(rgamma(stereo.volm * stereo.pan * Self.redRatio) * Double(UInt8.max)) : 0
                bitmap[x, y, 1] = stereo.pan < 0 ? UInt8(rgamma(stereo.volm * -stereo.pan * Self.greenRatio) * Double(UInt8.max)) : 0
                bitmap[x, y, 2] = UInt8(b * alpha * Double(UInt8.max))
                bitmap[x, y, 3] = UInt8(alpha * Double(UInt8.max))
            }
        }
        
        return bitmap.image
    }
}
