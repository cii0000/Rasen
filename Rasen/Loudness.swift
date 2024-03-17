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

// https://github.com/csteinmetz1/pyloudnorm
//
// Copyright (c) 2018 Christian Steinmetz
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

struct IIRfilter {
    enum FilterType: Hashable {
        case highShelf, lowShelf, highPass,
             lowPass, peaking, notch,
             highShelfDeMan, highPassDeMan
    }
    
    var G, Q, fc, rate: Double,
        filterType: FilterType,
        passbandGain: Double
    
    init(G: Double, Q: Double, fc: Double, rate: Double,
         _ filterType: FilterType,
         passbandGain: Double = 1) {
        self.G  = G
        self.Q  = Q
        self.fc = fc
        self.rate = rate
        self.filterType = filterType
        self.passbandGain = passbandGain
    }

    func generateCoefficients() -> [Double] {
        let A = 10 ** (self.G / 40)
        let w0 = 2 * .pi * (self.fc / self.rate)
        let alpha = .sin(w0) / (2 * self.Q)

        let a0, a1, a2, b0, b1, b2: Double
        switch filterType {
        case .highShelf:
            b0 =      A * ( (A+1) + (A-1) * .cos(w0) + 2 * .sqrt(A) * alpha )
            b1 = -2 * A * ( (A-1) + (A+1) * .cos(w0)                        )
            b2 =      A * ( (A+1) + (A-1) * .cos(w0) - 2 * .sqrt(A) * alpha )
            a0 =            (A+1) - (A-1) * .cos(w0) + 2 * .sqrt(A) * alpha
            a1 =      2 * ( (A-1) - (A+1) * .cos(w0)                        )
            a2 =            (A+1) - (A-1) * .cos(w0) - 2 * .sqrt(A) * alpha
        case .lowShelf:
            b0 =      A * ( (A+1) - (A-1) * .cos(w0) + 2 * .sqrt(A) * alpha )
            b1 =  2 * A * ( (A-1) - (A+1) * .cos(w0)                        )
            b2 =      A * ( (A+1) - (A-1) * .cos(w0) - 2 * .sqrt(A) * alpha )
            a0 =            (A+1) + (A-1) * .cos(w0) + 2 * .sqrt(A) * alpha
            a1 =     -2 * ( (A-1) + (A+1) * .cos(w0)                        )
            a2 =            (A+1) + (A-1) * .cos(w0) - 2 * .sqrt(A) * alpha
        case .highPass:
            b0 =  (1 + .cos(w0))/2
            b1 = -(1 + .cos(w0))
            b2 =  (1 + .cos(w0))/2
            a0 =   1 + alpha
            a1 =  -2 * .cos(w0)
            a2 =   1 - alpha
        case .lowPass:
            b0 =  (1 - .cos(w0))/2
            b1 =  (1 - .cos(w0))
            b2 =  (1 - .cos(w0))/2
            a0 =   1 + alpha
            a1 =  -2 * .cos(w0)
            a2 =   1 - alpha
        case .peaking:
            b0 =   1 + alpha * A
            b1 =  -2 * .cos(w0)
            b2 =   1 - alpha * A
            a0 =   1 + alpha / A
            a1 =  -2 * .cos(w0)
            a2 =   1 - alpha / A
        case .notch:
            b0 =   1
            b1 =  -2 * .cos(w0)
            b2 =   1
            a0 =   1 + alpha
            a1 =  -2 * .cos(w0)
            a2 =   1 - alpha
        case .highShelfDeMan:
            let K  = Double.tan(.pi * self.fc / self.rate)
            let Vh = 10 ** (self.G / 20)
            let Vb = Vh ** 0.499666774155
            let a0_ = 1.0 + K / self.Q + K * K
            b0 = (Vh + Vb * K / self.Q + K * K) / a0_
            b1 =  2.0 * (K * K -  Vh) / a0_
            b2 = (Vh - Vb * K / self.Q + K * K) / a0_
            a0 =  1.0
            a1 =  2.0 * (K * K - 1.0) / a0_
            a2 = (1.0 - K / self.Q + K * K) / a0_
        case .highPassDeMan:
            let K  = Double.tan(.pi * self.fc / self.rate)
            a0 =  1.0
            a1 =  2.0 * (K * K - 1.0) / (1.0 + K / self.Q + K * K)
            a2 = (1.0 - K / self.Q + K * K) / (1.0 + K / self.Q + K * K)
            b0 =  1.0
            b1 = -2.0
            b2 =  1.0
        }

        return [b0, b1, b2, a1, a2].map { $0 / a0 }
    }

    func applyFilter(data: [Double]) -> [Double] {
        var filter = Biquad(coefficients: generateCoefficients(),
                            channelCount: 1,
                            sectionCount: 1)
        let nData = filter?.apply(input: data) ?? data
        return nData.map { $0 * passbandGain }
    }
}

struct Loudness {
    private static let ps = [Point(60, 70),
                             Point(80, 60),
                             Point(200, 50),
                             Point(1000, 40),
                             Point(1400, 45),
                             Point(1600, 45),
                             Point(3000, 35),
                             Point(4000, 35),
                             Point(9000, 55),
                             Point(12500, 55),
                             Point(15000, 52)]
    static func db40PhonScale(fromFq fq: Double) -> Double {
        db40Phon(fromFq: fq) / 70
    }
    static func db40Phon(fromFq fq: Double) -> Double {
        var preFq = 0.0, preDb = ps.last!.y
        
        for p in ps {
            if fq < p.x {
                let t = (fq - preFq) / (p.x - preFq)
                return Double.linear(preDb, p.y, t: t)
            }
            preFq = p.x
            preDb = p.y
        }
        return ps.last!.y
    }
    
    enum FilterClass: String {
        case kWeighting = "K-weighting"
        case fentonLee1 = "Fenton/Lee 1"
        case fentonLee2 = "Fenton/Lee 2"
        case dashEtAl = "Dash et al."
        case deMan = "DeMan"
        case custom = "Custom"
        
        func filters(fromSampleRate sampleRate: Double) -> [IIRfilter.FilterType: IIRfilter] {
            var filters = [IIRfilter.FilterType: IIRfilter]()
            switch self {
            case .kWeighting:
                filters[.highShelf] = IIRfilter(G: 4, Q: 1 / .sqrt(2), fc: 1500,
                                                rate: sampleRate, .highShelf)
                filters[.highPass] = IIRfilter(G: 0, Q: 0.5, fc: 38,
                                               rate: sampleRate, .highPass)
            case .fentonLee1:
                filters[.highShelf] = IIRfilter(G: 5, Q: 1 / .sqrt(2), fc: 1500,
                                                rate: sampleRate, .highShelf)
                filters[.highPass] = IIRfilter(G: 0, Q: 0.5, fc: 130,
                                               rate: sampleRate, .highPass)
                filters[.peaking] = IIRfilter(G: 0, Q: 1 / .sqrt(2), fc: 500,
                                              rate: sampleRate, .peaking)
            case .fentonLee2:
                filters[.highShelf] = IIRfilter(G: 4, Q: 1 / .sqrt(2), fc: 1500,
                                                rate: sampleRate, .highShelf)
                filters[.highPass] = IIRfilter(G: 0, Q: 0.5, fc: 38,
                                               rate: sampleRate, .highPass)
                fatalError("not yet implemented")
            case .dashEtAl:
                filters[.highPass] = IIRfilter(G: 0, Q: 0.375, fc: 149,
                                               rate: sampleRate, .highPass)
                filters[.peaking] = IIRfilter(G: -2.93820927, Q: 1.68878655, fc: 1000,
                                              rate: sampleRate, .peaking)
            case .deMan:
                filters[.highShelfDeMan] = IIRfilter(G: 3.99984385397,
                                                     Q: 0.7071752369554193,
                                                     fc: 1681.9744509555319,
                                                     rate: sampleRate,
                                                     .highShelfDeMan)
                filters[.highPassDeMan] = IIRfilter(G: 0,
                                                    Q: 0.5003270373253953,
                                                    fc: 38.13547087613982,
                                                    rate: sampleRate,
                                                    .highPassDeMan)
            case .custom: break
            }
            return filters
        }
    }
    
    var sampleRate: Double {
        didSet {
            filters = filterClass.filters(fromSampleRate: sampleRate)
        }
    }
    var filterClass: FilterClass {
        didSet {
            filters = filterClass.filters(fromSampleRate: sampleRate)
        }
    }
    private(set) var filters: [IIRfilter.FilterType: IIRfilter]
    var blockSize: Double
    
    init(sampleRate: Double,
         filterClass: FilterClass = .kWeighting,
         blockSize: Double = 0.4) {
        self.sampleRate = sampleRate
        self.filterClass = filterClass
        self.filters = filterClass.filters(fromSampleRate: sampleRate)
        self.blockSize = blockSize
    }

    struct ValueError: Error {
        var string: String
        init(_ str: String) {
            self.string = str
        }
    }
    func integratedLoudness(data: [[Double]]) throws -> Double {
        var inputData = data
        if inputData.count > 5 || inputData.isEmpty {
            throw ValueError("Audio must have five channels or less.")
        }
        if Double(inputData[0].count) < blockSize * sampleRate {
            throw ValueError("Audio must have length greater than the block size.")
        }
        
        let numChannels = inputData.count
        let numSamples  = inputData[0].count
        
        // Apply frequency weighting filters - account for the acoustic response of the head and auditory system
        for (_, filterStage) in filters {
            for ch in 0 ..< numChannels {
                inputData[ch] = filterStage.applyFilter(data: inputData[ch])
            }
        }
        let G = [1.0, 1.0, 1.0, 1.41, 1.41] // channel gains
        let T_g = blockSize // 400 ms gating block standard
        let GammaA = -70.0 // -70 LKFS = absolute loudness threshold
        let overlap = 0.75 // overlap of 75 % of the block duration
        let step = 1 - overlap // step size by percentage
        
        let T = Double(numSamples) / sampleRate // length of the input in seconds
        let numBlocks = Int((((T - T_g) / (T_g * step))).rounded() + 1) // total number of gated blocks (see end of eq. 3)
        let jRange = 0 ..< numBlocks // indexed list of total blocks
        var z = Array(repeating: Array(repeating: 0.0, count: numBlocks),
                      count: numChannels) // instantiate array - trasponse of input
        
        for i in 0 ..< numChannels { // iterate over input channels
            for j in jRange { // iterate over total frames
                let l = min(Int(T_g * (Double(j) * step) * sampleRate), numSamples) // lower bound of integration (in samples)
                let u = min(Int(T_g * (Double(j) * step + 1) * sampleRate), numSamples) // upper bound of integration (in samples)
                // caluate mean square of the filtered for each block (see eq. 1)
                z[i][j] = (1.0 / (T_g * sampleRate)) * (inputData[i][l ..< u].map { $0.squared }.sum())
            }
        }
        
        // loudness for each jth block (see eq. 4)
        let l = jRange.map { j in
            let s = (0 ..< numChannels).sum { i in G[i] * z[i][j] }
            return -0.691 + 10 * .log10(s)
        }
        
        // find gating block indices above absolute threshold
        let J_g0 = l.enumerated().compactMap { j, l_j in l_j >= GammaA ? j : nil }
        
        // calculate the average of z[i][j] as show in eq. 5
        let zAvgGated0 = (0 ..< numChannels).map { i in J_g0.mean { j in z[i][j] } }
        
        // calculate the relative threshold value (see eq. 6)
        let n0 = (0 ..< numChannels).sum { i in G[i] * zAvgGated0[i] }
        let GammaR = -0.691 + 10 * .log10(n0) - 10
        
        // find gating block indices above relative and absolute thresholds  (end of eq. 7)
        let J_g1 = l.enumerated().compactMap { j, l_j in (l_j > GammaR && l_j > GammaA) ? j : nil }
        
        // calculate the average of z[i][j] as show in eq. 7 with blocks above both thresholds
        let zAvgGated1 = (0 ..< numChannels)
            .map { i in J_g1.mean { j in z[i][j] } }
            .map { $0.isNaN || $0.isInfinite ? 0 : $0 }
        
        // calculate final loudness gated loudness (see eq. 7)
        let n1 = (0 ..< numChannels).sum { i in G[i] * zAvgGated1[i] }
        let lufs = -0.691 + 10 * .log10(n1)
        return lufs
    }
    
    static func currentPeak(data: [[Double]]) -> Double {
        data.map { cs in (cs.map { abs($0) }).max()! }.max()!
    }
    static func normalizePeakScale(data: [[Double]],
                                   target: Double) -> Double {
        let currentPeak = currentPeak(data: data)
        return (10 ** (target / 20)) / currentPeak
    }
    static func normalizePeak(data: [[Double]],
                              target: Double) -> [[Double]] {
        let gain = normalizePeakScale(data: data, target: target)
        return data.map { cs in cs.map { $0 * gain } }
    }
    static func normalizeLoudnessScale(inputLoudness: Double,
                                       targetLoudness: Double) -> Double {
        let deltaLoudness = targetLoudness - inputLoudness
        return 10 ** (deltaLoudness / 20)
    }
    static func normalizeLoudness(data: [[Double]],
                                  inputLoudness: Double,
                                  targetLoudness: Double) -> [[Double]] {
        let gain = normalizeLoudnessScale(inputLoudness: inputLoudness,
                                          targetLoudness: targetLoudness)
        return data.map { cs in cs.map { $0 * gain } }
    }
}
