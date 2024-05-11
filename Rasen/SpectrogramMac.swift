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
    
    static func nextPow2(_ x: Int) -> Int {
        Int(.exp2(.log2(Double(x)).rounded(.up)))
    }
    
    static func fftfreq(_ n: Int, _ d: Double) -> [Double] {
        let v = 1 / (Double(n) * d)
        var results = [Int](capacityUninitialized: n)
        let nn = (n - 1) / 2 + 1
        (0 ..< nn).forEach { results[$0] = $0 }
        (nn ..< results.count).forEach { results[$0] = -(n / 2) + $0 - nn }
        return results.map { Double($0) * v }
    }
    
    static func window(_ type: WindowSequence, count: Int) -> [Double] {
        Self.window(ofType: Double.self, usingSequence: type, count: count, isHalfWindow: false)
    }
    
    static func sinRMS<U>(_ vector: U) -> Double where U: AccelerateBuffer, U.Element == Double {
        (vDSP.sumOfSquares(vector) / 2).squareRoot()
    }
}

struct FftFrame {
    var dc = 0.0
    var amps = [Double]()
    var phases = [Double]()
}

typealias VDFT = vDSP.DiscreteFourierTransform
typealias FftComp = Complex<Double>
struct Fft {
    private let vdft: VDFT<Double>, count: Int, rdCount: Double, ims: [Double]
    
    init(count: Int) throws {
        self.vdft = try VDFT(previous: nil,
                             count: count,
                             direction: .forward,
                             transformType: .complexComplex,
                             ofType: Double.self)
        ims = .init(repeating: 0, count: count)
        self.count = count
        self.rdCount = 1 / Double(count)
    }
    
    func noMathTransform(_ x: [Double]) -> [FftComp] {
        let v = vdft.transform(real: x, imaginary: ims)
        return zip(v.real, v.imaginary).map { .init($0.0, $0.1) }
    }
    func transform(_ x: [Double]) -> [FftComp] {
        var v = vdft.transform(real: x, imaginary: ims)
        vDSP.multiply(rdCount, v.real, result: &v.real)
        vDSP.multiply(rdCount, v.imaginary, result: &v.imaginary)
        return zip(v.real, v.imaginary).map { .init($0.0, $0.1) }
    }
    
    func noMathTransform(res: [Double], ims: [Double]) -> [FftComp] {
        let v = vdft.transform(real: res, imaginary: ims)
        return zip(v.real, v.imaginary).map { .init($0.0, $0.1) }
    }
    func transform(res: [Double], ims: [Double]) -> [FftComp] {
        var v = vdft.transform(real: res, imaginary: ims)
        vDSP.multiply(rdCount, v.real, result: &v.real)
        vDSP.multiply(rdCount, v.imaginary, result: &v.imaginary)
        return zip(v.real, v.imaginary).map { .init($0.0, $0.1) }
    }
    
    func noMathTransform(_ x: [FftComp]) -> [FftComp] {
        let v = vdft.transform(real: x.map { $0.real }, imaginary: x.map { $0.imaginary })
        return zip(v.real, v.imaginary).map { .init($0.0, $0.1) }
    }
    func transform(_ x: [FftComp]) -> [FftComp] {
        var v = vdft.transform(real: x.map { $0.real }, imaginary: x.map { $0.imaginary })
        vDSP.multiply(rdCount, v.real, result: &v.real)
        vDSP.multiply(rdCount, v.imaginary, result: &v.imaginary)
        return zip(v.real, v.imaginary).map { .init($0.0, $0.1) }
    }
    
    func dcAndAmps(_ x: [Double]) -> (dc: Double, amps: [Double]) {
        let vs = transform(x), ni = x.count / 2
        return (vs[0].real, vs[1 ..< ni].map { $0.length * 2 } + [vs[ni].length])
    }
    func dcAndAmps(_ x: [FftComp]) -> (dc: Double, amps: [Double]) {
        let vs = transform(x), ni = x.count / 2
        return (vs[0].real, vs[1 ..< ni].map { $0.length * 2 } + [vs[ni].length])
    }
    
    func frame(_ x: [Double]) -> FftFrame {
        let vs = transform(x), ni = x.count / 2
        return .init(dc: vs[0].real,
                     amps: vs[1 ..< ni].map { $0.length * 2 } + [vs[ni].length],
                     phases: vs[1 ... ni].map { $0.phase })
    }
    func frame(_ x: [FftComp]) -> FftFrame {
        let vs = transform(x), ni = x.count / 2
        return .init(dc: vs[0].real,
                     amps: vs[1 ..< ni].map { $0.length * 2 } + [vs[ni].length],
                     phases: vs[1 ... ni].map { $0.phase })
    }
}

struct Ifft {
    private let vdft: VDFT<Double>, count: Int
    
    init(count: Int) throws {
        self.vdft = try VDFT(previous: nil,
                             count: count,
                             direction: .inverse,
                             transformType: .complexComplex,
                             ofType: Double.self)
        self.count = count
    }
    
    func resAndImsTransform(dc: Double, amps: [Double], phases: [Double]) -> (res: [Double], ims: [Double]) {
        var res = [Double](capacity: count)
        var ims = [Double](capacity: count)
        res.append(dc)
        ims.append(0)
        for i in amps.count.range {
            let r = i == amps.count - 1 ? amps[i] : amps[i] / 2, phase = phases[i]
            res.append(r * .sin(phase))
            ims.append(-r * .cos(phase))
        }
        for i in (1 ..< amps.count).reversed() {
            res.append(res[i])
            ims.append(-ims[i])
        }
        return resAndImsTransform(res: res, ims: ims)
    }
    func compsTransform(_ frame: FftFrame) -> (res: [Double], ims: [Double]) {
        let v = resAndImsTransform(dc: frame.dc, amps: frame.amps, phases: frame.phases)
        return (v.res, v.ims)
    }
    func resAndImsTransform(res: [Double], ims: [Double]) -> (res: [Double], ims: [Double]) {
        let v = vdft.transform(real: res, imaginary: ims)
        return (v.real, v.imaginary)
    }
    func resAndImsTransform(_ x: [FftComp]) -> (res: [Double], ims: [Double]) {
        let v = vdft.transform(real: x.map { $0.real }, imaginary: x.map { $0.imaginary })
        return (v.real, v.imaginary)
    }
    
    func compsTransform(dc: Double, amps: [Double], phases: [Double]) -> [FftComp] {
        let v = resAndImsTransform(dc: dc, amps: amps, phases: phases)
        return zip(v.res, v.ims).map { .init($0.0, $0.1) }
    }
    func compsTransform(_ frame: FftFrame) -> [FftComp] {
        let v = resAndImsTransform(dc: frame.dc, amps: frame.amps, phases: frame.phases)
        return zip(v.res, v.ims).map { .init($0.0, $0.1) }
    }
    func compsTransform(res: [Double], ims: [Double]) -> [FftComp] {
        let v = resAndImsTransform(res: res, ims: ims)
        return zip(v.res, v.ims).map { .init($0.0, $0.1) }
    }
    func compsTransform(_ x: [FftComp]) -> [FftComp] {
        let v = resAndImsTransform(x)
        return zip(v.res, v.ims).map { .init($0.0, $0.1) }
    }
    
    func resTransform(dc: Double, amps: [Double], phases: [Double]) -> [Double] {
        resAndImsTransform(dc: dc, amps: amps, phases: phases).res
    }
    func resTransform(_ frame: FftFrame) -> [Double] {
        resAndImsTransform(dc: frame.dc, amps: frame.amps, phases: frame.phases).res
    }
    func resTransform(res: [Double], ims: [Double]) -> [Double] {
        resAndImsTransform(res: res, ims: ims).res
    }
    func resTransform(_ x: [FftComp]) -> [Double] {
        resAndImsTransform(x).res
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
    
    static let minLinearFq = 0.0, maxLinearFq = Audio.defaultSampleRate / 2
    static let minPitch = Score.doubleMinPitch, maxPitch = Score.doubleMaxPitch
    
    enum FqType {
        case linear, pitch
    }
    init(_ oBuffer: PCMBuffer,
         fftCount: Int = 2048, windowOverlap: Double = 0.875,
         isNormalized: Bool = true,
         type: FqType = .pitch) {
        
        let fftCount = vDSP.nextPow2(fftCount)
        
        guard oBuffer.frameCount < Int(oBuffer.sampleRate) * 60 * 10 else {
            print("unsupported")
            return
        }
        
        let buffer: PCMBuffer
        if oBuffer.sampleRate != Audio.defaultSampleRate {
            guard let nBuffer = try? oBuffer.convertDefaultFormat(isExportFormat: true) else { return }
            buffer = nBuffer
        } else {
            buffer = oBuffer
        }
        
        let channelCount = buffer.channelCount
        let frameCount = buffer.frameCount
        guard channelCount >= 1, fftCount > 0, frameCount >= fftCount,
              let fft = try? Fft(count: fftCount) else { return }
        
        let overlapCount = Int(Double(fftCount) * (1 - windowOverlap))
        var windowSamples = vDSP.window(.hanningDenormalized, count: fftCount)
        if !isNormalized {
            let racf = Double(fftCount) / vDSP.sum(windowSamples)
            vDSP.multiply(racf, windowSamples, result: &windowSamples)
        }
        
        let sampleRate = buffer.sampleRate
        let hFftCount = fftCount / 2
        let volmCount = hFftCount
        
        let secs: [(i: Int, sec: Double)] = stride(from: 0, to: frameCount, by: overlapCount).map { i in
            (i, Double(i) / sampleRate)
        }
        let loudnessScales = volmCount.range.map {
            let fq = Double.linear(Self.minLinearFq, Self.maxLinearFq,
                                   t: Double($0) / Double(volmCount))
            return Loudness.reverseVolm40Phon(fromFq: fq)
        }
        
        var chSecVolms: [[[Double]]]
        switch type {
        case .linear:
            chSecVolms = channelCount.range.map { chI in
                let amps = buffer.channelAmpsFromFloat(at: chI)
                return secs.map { (i, sec) in
                    let wave: [Double] = ((i - hFftCount) ..< (i - hFftCount + fftCount)).map { j in
                        j >= 0 && j < frameCount ? amps[j] : 0
                    }
                    
                    let inputRs = vDSP.multiply(windowSamples, wave)
                    let (_, amps) = fft.dcAndAmps(inputRs)
                    
                    return volmCount.range.map {
                        $0 == 0 ? 0 : loudnessScales[$0] * Volm.volm(fromAmp: amps[$0 - 1])
                    }
                }
            }
        case .pitch:
            let filterBank = FilterBank(sampleCount: volmCount,
                                        minPitch: Self.minPitch, maxPitch: Self.maxPitch,
                                        maxFq: Self.maxLinearFq)

            chSecVolms = channelCount.range.map { chI in
                let amps = buffer.channelAmpsFromFloat(at: chI)
                return secs.map { (i, sec) in
                    let wave: [Double] = ((i - hFftCount) ..< (i - hFftCount + fftCount)).map { j in
                        j >= 0 && j < frameCount ? amps[j] : 0
                    }
                    
                    let inputRs = vDSP.multiply(windowSamples, wave)
                    let (_, amps) = fft.dcAndAmps(inputRs)
                    
                    let volms = volmCount.range.map {
                        $0 == 0 ? 0 : loudnessScales[$0] * Volm.volm(fromAmp: amps[$0 - 1])
                    }
                    return filterBank.transform(volms)
                }
            }
            
            let fftCount2 = Int(.exp2(.log2(Double(fftCount * 4))).rounded(.up))
            let hFftCount2 = fftCount2 / 2
            if let fft2 = try? Fft(count: fftCount2) {
                let overlapCount2 = Int(Double(fftCount2) * (1 - windowOverlap))
                var windowSamples2 = vDSP.window(.hanningDenormalized, count: fftCount2)
                if !isNormalized {
                    let racf = Double(fftCount2) / vDSP.sum(windowSamples2)
                    vDSP.multiply(racf, windowSamples2, result: &windowSamples2)
                }
                let volmCount2 = fftCount2 / 2
                
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

                channelCount.range.forEach { chI in
                    let amps = buffer.channelAmpsFromFloat(at: chI)
                    let tss2 = secs2.map { (i, sec) in
                        let wave2: [Double] = ((i - hFftCount2) ..< (i - hFftCount2 + fftCount2)).map { j in
                            j >= 0 && j < frameCount ? amps[j] : 0
                        }
                        
                        let inputRs2 = vDSP.multiply(windowSamples2, wave2)
                        let (_, amps2) = fft2.dcAndAmps(inputRs2)
                        let volms = volmCount2.range.map {
                            $0 == 0 ? 0 : loudnessScales2[$0] * Volm.volm(fromAmp: amps2[$0 - 1])
                        }
                        let nVolms = filterBank2.transform(volms)
                        return stride(from: 0, to: nVolms.count, by: 4).map { nVolms[$0] }
                    }
                    
                    secs.enumerated().forEach { secI, v in
                        let ti2 = min(Int((Double(tss2.count * secI) / Double(secs.count)).rounded()), tss2.count - 1)
                        for volmI in 0 ..< volmCount / 2 {
                            let t = volmI < volmCount * 3 / 8 ?
                            Double(volmI).clipped(min: Double(volmCount * 1 / 8),
                                               max: Double(volmCount * 3 / 8),
                                               newMin: 0, newMax: 0.5) :
                            Double(volmI).clipped(min: Double(volmCount * 3 / 8),
                                               max: Double(volmCount / 2),
                                               newMin: 0.5, newMax: 1)
                            chSecVolms[chI][secI][volmI] = Double.linear(tss2[ti2][volmI],
                                                                   chSecVolms[chI][secI][volmI], t: t)
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
        
        var frames = secs.enumerated().map { secI, v in
            return Frame(sec: v.sec, stereos: volmCount.range.map { volmI in
                stereo(fromVolms: channelCount.range.map { chI in chSecVolms[chI][secI][volmI] })
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
