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

import RealModule

extension Note {
    mutating func replaceAndOnsetNotes(lyric: String, at i: Int,
                                       tempo: Rational,
                                       beatRate: Int = 96, pitchRate: Int = 96) -> [Note] {
        var lyric = lyric
        let isVowelReduction: Bool
        if lyric.last == "/" {
            isVowelReduction = true
            lyric.removeLast()
        } else {
            isVowelReduction = false
        }
        
        self.pits[i].lyric = lyric
        
        let previousPhoneme: Phoneme?, previousFormantFilter: FormantFilter?
        if let preI = i.range.reversed().first(where: { !pits[$0].lyric.isEmpty && pits[$0].lyric != "%" }) {
            var preLyric = pits[preI].lyric
            if preLyric.last == "/" {
                preLyric.removeLast()
            }
            previousPhoneme = Phoneme.phonemes(fromHiragana: preLyric).last
            previousFormantFilter = .init(spectlope: pits[preI].tone.spectlope)
        } else {
            previousPhoneme = nil
            previousFormantFilter = nil
        }
        
        if let mora = Mora(hiragana: lyric, isVowelReduction: isVowelReduction,
                           previousPhoneme: previousPhoneme,
                           previousFormantFilter: previousFormantFilter) {
            let beat = pits[i].beat
            let fBeat = Score.beat(fromSec: mora.keyFormantFilters.first?.sec ?? 0,
                                   tempo: tempo, beatRate: beatRate) + beat
            let lBeat = Score.beat(fromSec: mora.keyFormantFilters.last?.sec ?? 0,
                                   tempo: tempo, beatRate: beatRate) + beat
            var minI = i, maxI = i
            for j in i.range.reversed() {
                if pits[j].beat < fBeat {
                    minI = j + 1
                    break
                }
            }
            for j in i.range {
                if pits[j].beat > lBeat {
                    maxI = j
                    break
                }
            }
            
            var ivps = [IndexValue<Pit>]()
            for (fi, ff) in mora.keyFormantFilters.enumerated() {
                let fBeat = Score.beat(fromSec: ff.sec, tempo: tempo, beatRate: beatRate) + beat
                let result = self.pitResult(atBeat: Double(fBeat))
                ivps.append(.init(value: .init(beat: fBeat,
                                               pitch: result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval),
                                               stereo: result.stereo,
                                               tone: .init(spectlope: ff.formantFilter.spectlope),
                                               lyric: fi == mora.keyFormantFilters.count - 1 ? lyric : "%"),
                                  index: fi + minI))
            }
            
            pits.remove(at: Array(minI ... maxI))
            pits.insert(ivps)
            
            let dBeat = ivps.first?.value.beat ?? 0
            if dBeat < 0 {
                self.beatRange = beatRange.start + dBeat ..< beatRange.end
            
                for i in pits.count.range {
                    pits[i].beat -= dBeat
                }
            }
            
            return mora.onsets.map {
                let sBeat = beatRange.start + beat + Score.beat(fromSec: $0.sec, tempo: tempo, 
                                                                beatRate: beatRate)
                let eBeat = sBeat + Score.beat(fromSec: $0.durSec, tempo: tempo, beatRate: beatRate)
                return Note(beatRange: sBeat ..< eBeat,
                            pitch: Rational($0.spectlope.sprols.first?.pitch ?? 0,
                                            intervalScale: Rational(1, pitchRate)),
                            pits: [.init(beat: 0, pitch: 0,
                                         stereo: .init(smp: $0.smp, pan: 0),
                                         tone: .init(spectlope: $0.spectlope),
                                         lyric: $0.phoneme.rawValue)],
                            envelope: .init(attackSec: $0.attackSec, decaySec: 0,
                                            sustainSmp: 1, releaseSec: $0.releaseSec),
                            isNoise: $0.spectlope.isFullNoise)
            }
        }
        
        return []
    }
}

struct Formant: Hashable, Codable {
    var sprol0 = Sprol(), sprol1 = Sprol(), sprol2 = Sprol(), sprol3 = Sprol()
}
extension Formant {
    init(sdSmp: Double, sdNoise: Double,
         sdPitch: Double, sPitch: Double, ePitch: Double, edPitch: Double,
         smp: Double, noise: Double, edSmp: Double, edNoise: Double) {
        
        sprol0 = .init(pitch: sPitch - sdPitch, smp: sdSmp, noise: sdNoise)
        sprol1 = .init(pitch: sPitch, smp: smp, noise: noise)
        sprol2 = .init(pitch: ePitch, smp: smp, noise: noise)
        sprol3 = .init(pitch: ePitch + edPitch, smp: edSmp, noise: edNoise)
    }
    
    var ssPitch: Double {
        get { sprol0.pitch }
        set { sprol0.pitch = newValue }
    }
    var sPitch: Double {
        get { sprol1.pitch }
        set {
            sprol0.pitch = newValue - sdPitch
            sprol1.pitch = newValue
        }
    }
    var ePitch: Double {
        get { sprol2.pitch }
        set {
            sprol2.pitch = newValue
            sprol3.pitch = newValue + edPitch
        }
    }
    var eePitch: Double {
        get { sprol3.pitch }
        set { sprol3.pitch = newValue }
    }
    
    var sdPitch: Double {
        get { sprol1.pitch - sprol0.pitch }
        set { sprol0.pitch = sprol1.pitch - newValue }
    }
    var edPitch: Double {
        get { sprol3.pitch - sprol2.pitch }
        set { sprol3.pitch = sprol2.pitch + newValue }
    }
    
    var pitch: Double {
        get { sPitch.mid(ePitch) }
        set {
            let dPitch = dPitch
            sPitch = newValue - dPitch
            ePitch = newValue + dPitch
        }
    }
    var pitchRange: ClosedRange<Double> {
        get { sPitch ... ePitch }
        set {
            sPitch = newValue.lowerBound
            ePitch = newValue.upperBound
        }
    }
    var dPitch: Double {
        get { (ePitch - sPitch) / 2 }
        set {
            let pitch = pitch
            sPitch = pitch - newValue
            ePitch = pitch + newValue
        }
    }
    
    var sdSmp: Double {
        get { sprol0.smp }
        set { sprol0.smp = newValue }
    }
    var sSmp: Double {
        get { sprol1.smp }
        set { sprol1.smp = newValue }
    }
    var eSmp: Double {
        get { sprol2.smp }
        set { sprol2.smp = newValue }
    }
    var edSmp: Double {
        get { sprol3.smp }
        set { sprol3.smp = newValue }
    }
    
    var smp: Double {
        get { sSmp.mid(eSmp) }
        set {
            let dSmp = dSmp
            sSmp = (newValue - dSmp).clipped(min: 0, max: 1)
            eSmp = (newValue + dSmp).clipped(min: 0, max: 1)
        }
    }
    var dSmp: Double {
        get { (eSmp - sSmp) / 2 }
        set {
            let smp = smp
            sSmp = smp - newValue
            eSmp = smp + newValue
        }
    }
    
    var sdNoise: Double {
        get { sprol0.noise }
        set { sprol0.noise = newValue }
    }
    var sNoise: Double {
        get { sprol1.noise }
        set { sprol1.noise = newValue }
    }
    var eNoise: Double {
        get { sprol2.noise }
        set { sprol2.noise = newValue }
    }
    var edNoise: Double {
        get { sprol3.noise }
        set { sprol3.noise = newValue }
    }
    
    var noise: Double {
        get { sNoise.mid(eNoise) }
        set {
            let dNoise = dNoise
            sNoise = (newValue - dNoise).clipped(min: 0, max: 1)
            eNoise = (newValue + dNoise).clipped(min: 0, max: 1)
        }
    }
    var dNoise: Double {
        get { (eNoise - sNoise) / 2 }
        set {
            let noise = noise
            sNoise = noise - newValue
            eNoise = noise + newValue
        }
    }
    
    var sdNoiseSmp: Double {
        get { sdSmp * sdNoise }
        set { sdNoise = (newValue / sdSmp).clipped(min: 0, max: 1) }
    }
    var noiseSmp: Double {
        get { smp * noise }
        set { noise = (smp == 0 ? 0 : newValue / smp).clipped(min: 0, max: 1) }
    }
    var edNoiseSmp: Double {
        get { edSmp * edNoise }
        set { edNoise = (newValue / edSmp).clipped(min: 0, max: 1) }
    }
    
    mutating func formMultiplySmp(_ x: Double) {
        sprol0.smp *= x
        sprol1.smp *= x
        sprol2.smp *= x
        sprol3.smp *= x
    }
    func multiplySmp(_ x: Double) -> Self {
        var n = self
        n.formMultiplySmp(x)
        return n
    }
    
    mutating func fillSmp(_ x: Double) {
        sprol0.smp = x
        sprol1.smp = x
        sprol2.smp = x
        sprol3.smp = x
    }
    func filledSmp(_ x: Double) -> Self {
        var n = self
        n.fillSmp(x)
        return n
    }
    
    mutating func fillSmp(_ other: Self) {
        sprol0.smp = other.sprol0.smp
        sprol1.smp = other.sprol1.smp
        sprol2.smp = other.sprol2.smp
        sprol3.smp = other.sprol3.smp
    }
    func filledSmp(_ other: Self) -> Self {
        var n = self
        n.fillSmp(other)
        return n
    }
    
    mutating func fillNoise(_ x: Double) {
        sprol0.noise = x
        sprol1.noise = x
        sprol2.noise = x
        sprol3.noise = x
    }
    func filledNoise(_ x: Double) -> Self {
        var n = self
        n.fillNoise(x)
        return n
    }
    
    mutating func fillNoise(_ other: Self) {
        sprol0.noise = other.sprol0.noise
        sprol1.noise = other.sprol1.noise
        sprol2.noise = other.sprol2.noise
        sprol3.noise = other.sprol3.noise
    }
    func filledNoise(_ other: Self) -> Self {
        var n = self
        n.fillNoise(other)
        return n
    }
    
    mutating func formToNoise() {
        fillNoise(1)
    }
    func toNoise() -> Self {
        var n = self
        n.formToNoise()
        return n
    }
    
    var isFullNoise: Bool {
        sprol0.noise == 1 && sprol1.noise == 1 && sprol2.noise == 1 && sprol3.noise == 1
    }
}
extension Formant: Interpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(sprol0: .linear(f0.sprol0, f1.sprol0, t: t),
              sprol1: .linear(f0.sprol1, f1.sprol1, t: t),
              sprol2: .linear(f0.sprol2, f1.sprol2, t: t),
              sprol3: .linear(f0.sprol3, f1.sprol3, t: t))
    }
    static func firstSpline(_ f1: Self, _ f2: Self,
                            _ f3: Self, t: Double) -> Self {
        .init(sprol0: .firstSpline(f1.sprol0, f2.sprol0, f3.sprol0, t: t),
              sprol1: .firstSpline(f1.sprol1, f2.sprol1, f3.sprol1, t: t),
              sprol2: .firstSpline(f1.sprol2, f2.sprol2, f3.sprol2, t: t),
              sprol3: .firstSpline(f1.sprol3, f2.sprol3, f3.sprol3, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(sprol0: .spline(f0.sprol0, f1.sprol0, f2.sprol0, f3.sprol0, t: t),
              sprol1: .spline(f0.sprol1, f1.sprol1, f2.sprol1, f3.sprol1, t: t),
              sprol2: .spline(f0.sprol2, f1.sprol2, f2.sprol2, f3.sprol2, t: t),
              sprol3: .spline(f0.sprol3, f1.sprol3, f2.sprol3, f3.sprol3, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(sprol0: .lastSpline(f0.sprol0, f1.sprol0, f2.sprol0, t: t),
              sprol1: .lastSpline(f0.sprol1, f1.sprol1, f2.sprol1, t: t),
              sprol2: .lastSpline(f0.sprol2, f1.sprol2, f2.sprol2, t: t),
              sprol3: .lastSpline(f0.sprol3, f1.sprol3, f2.sprol3, t: t))
    }
}
extension Formant: MonoInterpolatable {
    static func firstMonospline(_ f1: Self, _ f2: Self,
                                _ f3: Self, with ms: Monospline) -> Self {
        .init(sprol0: .firstMonospline(f1.sprol0, f2.sprol0, f3.sprol0, with: ms),
              sprol1: .firstMonospline(f1.sprol1, f2.sprol1, f3.sprol1, with: ms),
              sprol2: .firstMonospline(f1.sprol2, f2.sprol2, f3.sprol2, with: ms),
              sprol3: .firstMonospline(f1.sprol3, f2.sprol3, f3.sprol3, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self,
                           with ms: Monospline) -> Self {
        .init(sprol0: .monospline(f0.sprol0, f1.sprol0, f2.sprol0, f3.sprol0, with: ms),
              sprol1: .monospline(f0.sprol1, f1.sprol1, f2.sprol1, f3.sprol1, with: ms),
              sprol2: .monospline(f0.sprol2, f1.sprol2, f2.sprol2, f3.sprol2, with: ms),
              sprol3: .monospline(f0.sprol3, f1.sprol3, f2.sprol3, f3.sprol3, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) ->Self {
        .init(sprol0: .lastMonospline(f0.sprol0, f1.sprol0, f2.sprol0, with: ms),
              sprol1: .lastMonospline(f0.sprol1, f1.sprol1, f2.sprol1, with: ms),
              sprol2: .lastMonospline(f0.sprol2, f1.sprol2, f2.sprol2, with: ms),
              sprol3: .lastMonospline(f0.sprol3, f1.sprol3, f2.sprol3, with: ms))
    }
}

struct FormantFilter: Hashable, Codable {
    static let empty = Self.init(formants: .init(repeating: .init(), count: 8))
    
    var formants: [Formant] = [.init(sdSmp: 0.65, sdNoise: 0.1,
                                     sdPitch: 12, sPitch: 40, ePitch: 50, edPitch: 12,
                                     smp: 0.8, noise: 0,
                                     edSmp: 0.65, edNoise: 0.1),
                               .init(sdSmp: 0.65, sdNoise: 0.1,
                                     sdPitch: 12, sPitch: 68, ePitch: 73, edPitch: 12,
                                     smp: 1, noise: 0.1,
                                     edSmp: 0.7, edNoise: 0.1),
                               .init(sdSmp: 0.7, sdNoise: 0.1,
                                     sdPitch: 10, sPitch: 80, ePitch: 84, edPitch: 6,
                                     smp: 1, noise: 0.25,
                                     edSmp: 0.53, edNoise: 0.1),
                               .init(sdSmp: 0.53, sdNoise: 0.1,
                                     sdPitch: 6, sPitch: 94, ePitch: 95, edPitch: 6,
                                     smp: 0.82, noise: 0.5,
                                     edSmp: 0.4, edNoise: 0.2),
                               .init(sdSmp: 0.4, sdNoise: 0.2,
                                     sdPitch: 6, sPitch: 100, ePitch: 101, edPitch: 6,
                                     smp: 0.7, noise: 0.6,
                                     edSmp: 0.1, edNoise: 0.3),
                               .init(sdSmp: 0.1, sdNoise: 0.3,
                                     sdPitch: 6, sPitch: 104, ePitch: 109, edPitch: 6,
                                     smp: 0.3, noise: 0.7,
                                     edSmp: 0.1, edNoise: 0.45)]
}
extension FormantFilter {
    init(spectlope: Spectlope) {
        self.formants = spectlope.formants
    }
    var spectlope: Spectlope {
        .init(sprols: formants.flatMap { [$0.sprol0, $0.sprol1, $0.sprol2, $0.sprol3] })
    }
}
enum FormantFilterSmpType {
    case esSmp, esNoise
}
extension FormantFilter {
    subscript(i: Int, type: FormantFilterSmpType) -> Double {
        get {
            switch type {
            case .esSmp: i == count - 1 ? self[i].eSmp : self[i].eSmp.mid(self[i + 1].sSmp)
            case .esNoise: i == count - 1 ? self[i].eNoise : self[i].eNoise.mid(self[i + 1].sNoise)
            }
        }
        set {
            switch type {
            case .esSmp:
                if i == count - 1 {
                    self[i].eSmp = newValue
                } else {
                    let dSmp = (self[i].sSmp - self[i + 1].eSmp) / 2
                    self[i].eSmp = newValue - dSmp
                    self[i + 1].sSmp = newValue + dSmp
                }
            case .esNoise:
                if i == count - 1 {
                    self[i].eNoise = newValue
                } else {
                    let dNoise = (self[i].sNoise - self[i + 1].eNoise) / 2
                    self[i].eNoise = newValue - dNoise
                    self[i + 1].sNoise = newValue + dNoise
                }
            }
        }
    }
}
extension FormantFilter {
    func toA(from fromPhoneme: Phoneme) -> Self {
        var n = withSelfA(to: fromPhoneme)
        func substructPitch(from v0: Sprol, to v1: Sprol) -> Double {
            (v0.pitch * 2 - v1.pitch).clipped(Score.doublePitchRange)
        }
        func substructSmp(from v0: Sprol, to v1: Sprol) -> Double {
            v1.smp == 0 ? 0 : (v0.smp.squared / v1.smp).clipped(min: 0, max: 1)
        }
        func substructNoise(from v0: Sprol, to v1: Sprol) -> Double {
            v1.noise == 0 ? 0 : (v0.noise.squared / v1.noise).clipped(min: 0, max: 1)
        }
        for i in Swift.min(n.count, self.count).range {
            n[i].sprol0.pitch = substructPitch(from: self[i].sprol0, to: n[i].sprol0)
            n[i].sprol1.pitch = substructPitch(from: self[i].sprol1, to: n[i].sprol1)
            n[i].sprol2.pitch = substructPitch(from: self[i].sprol2, to: n[i].sprol2)
            n[i].sprol3.pitch = substructPitch(from: self[i].sprol3, to: n[i].sprol3)
            n[i].sprol0.smp = substructSmp(from: self[i].sprol0, to: n[i].sprol0)
            n[i].sprol1.smp = substructSmp(from: self[i].sprol1, to: n[i].sprol1)
            n[i].sprol2.smp = substructSmp(from: self[i].sprol2, to: n[i].sprol2)
            n[i].sprol3.smp = substructSmp(from: self[i].sprol3, to: n[i].sprol3)
            n[i].sprol0.noise = substructNoise(from: self[i].sprol0, to: n[i].sprol0)
            n[i].sprol1.noise = substructNoise(from: self[i].sprol1, to: n[i].sprol1)
            n[i].sprol2.noise = substructNoise(from: self[i].sprol2, to: n[i].sprol2)
            n[i].sprol3.noise = substructNoise(from: self[i].sprol3, to: n[i].sprol3)
        }
        return n
    }
    func to(_ toPhoneme: Phoneme, from fromPhoneme: Phoneme) -> Self {
        toA(from: fromPhoneme).withSelfA(to: toPhoneme)
    }
    func withSelfA(toLyric: String) -> Self {
        let phonemes = Phoneme.phonemes(fromHiragana: toLyric)
        return if let phoneme = phonemes.last, phoneme.isSyllabicJapanese {
            withSelfA(to: phoneme)
        } else {
            self
        }
    }
    func withSelfA(to phoneme: Phoneme) -> Self {
        switch phoneme {
        case .a: return self
        case .i:
            var n = self
            n[0].pitch += -24
            n[1].pitch += -20
            n[1].sdPitch += 7
            n[1].edPitch += 7
            n[1, .esSmp] *= 0.43
            n[2].pitch += 8.46
            n[2].smp *= 0.93
            n[3].pitch += -1.44
            n[4].pitch += -0.35
            n[5].pitch += -0.17
            return n
        case .j:
            var n = withSelfA(to: .i)
            n[1].smp *= 0.85
            n[2].pitch += -2.81
            n[3].pitch += -1.07
            return n
        case .ja:
            var n = withSelfA(to: .j)
            n[4].pitch += -0.35
            return n
        case .ɯ:
            var n = self
            n[0].pitch += -19
            n[1].pitch += -18.7
            n[1, .esSmp] *= 0.52
            n[2].pitch += 2.12
            n[2].smp *= 0.93
            n[3].pitch += -2.41
            n[4].pitch += -1.07
            n[5].pitch += -0.35
            return n
        case .β:
            var n = withSelfA(to: .ɯ)
            n[0].pitch += -17
            n[1].pitch += -3.4
            n[1].smp *= 0.85
            n[2].pitch += -6.7
            n[2].smp *= 0.78
            return n
        case .e:
            var n = self
            n[0].pitch += -44
            n[1].pitch += -8.5
            n[1].sdPitch += 15
            n[1].edPitch += 15
            n[1, .esSmp] *= 0.7
            n[2].pitch += 5.2
            n[2].smp *= 0.93
            n[2, .esSmp] *= 0.96
            n[3].pitch += -0.53
            n[4].pitch += 0.34
            n[5].pitch += 0.17
            return n
        case .o:
            var n = self
            n[0].pitch += -44
            n[1].pitch += -8.3
            n[1, .esSmp] *= 0.7
            n[2].pitch += -4.75
            n[2, .esSmp] *= 0.67
            n[3].pitch += -1.44
            n[4].pitch += -1.44
            n[5].pitch += -0.35
            return n
        case .nn:
            var n = self
            n[0].pitch += -44
            n[0].smp *= 1.01
            n[0, .esSmp] *= 1.05
            n[1].pitch += -19
            n[1, .esSmp] *= 0.37
            n[2].pitch += 0.84
            n[2].smp *= 0.43
            n[2, .esSmp] *= 0.34
            n[3].pitch += -0.35
            n[3].smp *= 0.46
            n[3, .esSmp] *= 0.06
            n[4].pitch += -0.17
            n[4].smp *= 0.3
            n[4, .esSmp] *= 0.19
            n[5].smp *= 0.14
            n[5, .esSmp] *= 0.19
            return n
        case .n:
            var n = self
            n[0].pitch += -60
            n[0, .esSmp] *= 1.05
            n[1].pitch += -26
            n[1, .esSmp] *= 0.37
            n[2].pitch += 3.16
            n[2].smp *= 0.43
            n[2, .esSmp] *= 0.46
            n[3].pitch += -0.53
            n[3].smp *= 0.6
            n[3, .esSmp] *= 0.4
            n[4].pitch += -0.17
            n[4].smp *= 0.56
            n[4, .esSmp] *= 0.4
            n[5].smp *= 0.34
            n[5, .esSmp] *= 0.05
            return n
        case .nj:
            var n = withSelfA(to: .n)
            n[2].pitch += 1.49
            return n
        case .m, .mj:
            var n = withSelfA(to: .n)
            n[1].pitch += -10
            n[2].pitch += -5
            n[3].pitch += -2.6
            n[4].pitch += -1.26
            return n
        case .r:
            var n = self
            n[0].pitch += -10
            n[0, .esSmp] *= 1.05
            n[1].pitch += -17
            n[1].smp *= 0.56
            n[1, .esSmp] *= 0.25
            n[2].pitch += 1
            n[2].smp *= 0.3
            n[2, .esSmp] *= 0.34
            n[3].pitch += -1.8
            n[3].smp *= 0.6
            n[3, .esSmp] *= 0.28
            n[4].pitch += -1.44
            n[4].smp *= 0.56
            n[4, .esSmp] *= 0.4
            n[5].smp *= 0.34
            n[5, .esSmp] *= 0.05
            return n
        case .rj:
            var n = withSelfA(to: .r)
            n[2].pitch += 4.8
            return n
        default: return self
        }
    }
}
extension FormantFilter: RandomAccessCollection {
    var startIndex: Int { formants.startIndex }
    var endIndex: Int { formants.endIndex }
    subscript(i: Int) -> Formant {
        get { i < formants.count ? formants[i] : .init() }
        set {
            if i < formants.count {
                formants[i] = newValue
            }
        }
    }
}
extension FormantFilter: Interpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(formants: .linear(f0.formants, f1.formants, t: t))
    }
    static func firstSpline(_ f1: Self, _ f2: Self,
                            _ f3: Self, t: Double) -> Self {
        .init(formants: .firstSpline(f1.formants, f2.formants,
                                     f3.formants, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(formants: .spline(f0.formants, f1.formants,
                                f2.formants, f3.formants, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(formants: .lastSpline(f0.formants, f1.formants,
                                    f2.formants, t: t))
    }
}
extension FormantFilter: MonoInterpolatable {
    static func firstMonospline(_ f1: Self, _ f2: Self,
                                _ f3: Self, with ms: Monospline) -> Self {
        .init(formants: .firstMonospline(f1.formants, f2.formants,
                                         f3.formants, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self,
                           with ms: Monospline) -> Self {
        .init(formants: .monospline(f0.formants, f1.formants,
                                    f2.formants, f3.formants, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) ->Self {
        .init(formants: .lastMonospline(f0.formants, f1.formants,
                                        f2.formants, with: ms))
    }
}
extension FormantFilter {
    var isFullNoise: Bool {
        !(formants.contains(where: { !$0.isFullNoise }))
    }
    
    func voiceless(dPitch: Double = -3.8) -> Self {
        var n = self
        n[0].pitch += dPitch
        n[1].pitch += dPitch
        n[4].smp = n[3].edSmp
        return n
    }
    
    func movedF2(sPitch: Double, ePitch: Double) -> Self {
        var n = self
        n[2].sPitch = sPitch
        n[2].ePitch = ePitch
        return n
    }
    func multiplyF2To(f2Smp: Double, smp: Double) -> Self {
        var n = self
        n[2].formMultiplySmp(f2Smp)
        if smp != 1 {
            for i in 3 ..< 8 {
                n[i].formMultiplySmp(smp)
            }
        }
        return n
    }
    
    func offVoice() -> Self {
        var n = offSmp(from: 2)
        n[0].pitch += -30
        n[0, .esSmp] = 0
        n[1].pitch += -20
        n[1, .esSmp] = 0
        return n
    }
    func offSmp(to i: Int) -> Self {
        var n = self
        for i in 0 ... i {
            n[i].fillSmp(0)
        }
        return n
    }
    func offSmp(from i: Int) -> Self {
        var n = self
        for i in i ..< n.count {
            n[i].fillSmp(0)
        }
        return n
    }
    func offNoise() -> Self {
        var n = self
        for i in 0 ..< n.count {
            n[i].fillNoise(0)
        }
        return n
    }
    
    func filledSmp(from sl: Self) -> Self {
        .init(formants: formants.enumerated().map { $0.element.filledSmp(sl[$0.offset]) })
    }
    
    func fricative(isO: Bool) -> Self {
        var n = offSmp(from: 6)
        n[0].smp = 0
        n[0, .esSmp] *= 0.56
        n[1].smp *= 0.7
        n[1, .esSmp] *= 0.56
        n[2].smp = 1
        n[2, .esSmp] *= 0.56
        n[3].smp = 1
        n[3, .esSmp] *= 0.56
        n[4].smp = 1
        n[4, .esSmp] = 0
        n[5].pitchRange = 101 ... 102
        n[5].smp = isO ? 0.56 : 1
        n[5, .esSmp] = 0
        return n
    }
    func breath() -> Self {
        var n = offSmp(from: 5)
        n[0].smp = n[2].smp * 0.7
        n[0, .esSmp] = n[1].edSmp * 0.7
        n[1].smp = n[2].smp * 0.7
        n[3].smp *= 0.85
        n[3, .esSmp] *= 0.7
        n[4].smp *= 0.7
        return n
    }
    
    func toDakuon() -> Self {
        var n = offSmp(from: 2)
        n[0].pitchRange = 50 ... 55
        n[0, .esSmp] *= 0.94
        n[1].pitchRange = 57 ... 59
        n[1].smp *= 0.85
        n[1, .esSmp] = 0
        return n
    }
    
    func toNoise() -> Self {
        var n = self
        n.formants = n.formants.map { $0.toNoise() }
        return n
    }
}

struct Onset: Hashable, Codable {
    var durSec: Double
    var smp: Double
    var sec: Double
    var attackSec: Double
    var releaseSec: Double
    var spectlope: Spectlope
    var phoneme: Phoneme
}

struct KeyFormantFilter: Hashable, Codable {
    var formantFilter: FormantFilter
    var sec = 0.0
    
    init(_ formantFilter: FormantFilter, sec: Double = 0) {
        self.formantFilter = formantFilter
        self.sec = sec
    }
}

struct Mora: Hashable, Codable {
    var hiragana: String
    var syllabics: [Phoneme]
    var isVowel: Bool
    var isDakuon: Bool
    var isOffVoice: Bool
    
    var deltaSyllabicStartSec: Double
    var keyFormantFilters: [KeyFormantFilter]
    
    var onsets: [Onset]
    
    init?(hiragana: String, isVowelReduction: Bool = false,
          previousPhoneme: Phoneme?, previousFormantFilter: FormantFilter?) {
        var phonemes = Phoneme.phonemes(fromHiragana: hiragana)
        guard !phonemes.isEmpty else { return nil }
        
        let baseFf: FormantFilter = if let previousPhoneme, let previousFormantFilter {
            previousFormantFilter.toA(from: previousPhoneme)
        } else {
            .init()
        }
        
        func formantFilter(from phoneme: Phoneme) -> FormantFilter? {
            baseFf.withSelfA(to: phoneme)
        }
        
        self.hiragana = hiragana
        isVowel = phonemes.last?.isSyllabicJapanese ?? false
        
        syllabics = []
        
        switch phonemes.last {
        case .a, .i, .ɯ, .e, .o, .nn:
            syllabics.append(phonemes.last!)
            phonemes.removeLast()
            
            deltaSyllabicStartSec = -0.015
        case .sokuon:
            syllabics = [phonemes.last!]
            deltaSyllabicStartSec = 0
            onsets = []
            keyFormantFilters = [.init(baseFf.withSelfA(to: .ɯ), sec: 0)]
            isDakuon = false
            isOffVoice = false
            return
        case .breath:
            syllabics.append(phonemes.last!)
            
            onsets = []
            
            let aFf = baseFf.withSelfA(to: .a)
            let durSec = 0.05
            let npFf = aFf.fricative(isO: syllabics.first == .o).toNoise()
            onsets.append(.init(durSec: durSec,
                                smp: 0.3,
                                sec: durSec,
                                attackSec: 0.02, releaseSec: 0.02,
                                spectlope: npFf.spectlope,
                                phoneme: .breath))
            onsets.append(.init(durSec: durSec,
                                smp: 0.125,
                                sec: durSec,
                                attackSec: 0.02, releaseSec: 0.03,
                                spectlope: .init(noisePitchSmps: [Point(70, 0),
                                                                  Point(80, 0.5),
                                                                  Point(100, 1),
                                                                  Point(110, 1),
                                                                  Point(120, 0)]),
                                phoneme: .breath))
            onsets.append(.init(durSec: durSec,
                                smp: 0.2,
                                sec: durSec,
                                attackSec: 0.02, releaseSec: 0.03,
                                spectlope: aFf.breath().spectlope,
                                phoneme: .breath))
            
            deltaSyllabicStartSec = 0
            keyFormantFilters = [.init(.empty, sec: 0)]
            isDakuon = false
            isOffVoice = false
            return
        default:
            return nil
        }
        let syllabicFf = formantFilter(from: syllabics.last!)!
        
        enum FirstType {
            case dakuon, haretsu, none
        }
        let firstType: FirstType = if phonemes.first?.isVoicelessSound ?? false {
            .haretsu
        } else if phonemes.first?.isVoiceBar ?? false {
            .dakuon
        } else {
            .none
        }
        
        enum Youon {
            case j, β, none
        }
        let youon: Youon, youonKffs: [KeyFormantFilter]
        switch phonemes.last {
        case .j, .ja:
            youon = .j
            let phoneme = phonemes.last!
            phonemes.removeLast()
            
            var ff = formantFilter(from: phoneme)!.multiplyF2To(f2Smp: 0.7, smp: 1)
            ff[2].sdPitch += 24
            ff[2].edPitch += 24
            youonKffs = [.init(ff, sec: 0.02),
                         .init(ff, sec: 0.1)]
            deltaSyllabicStartSec = -0.035
            syllabics.insert(phoneme, at: 0)
        case .β:
            youon = .β
            phonemes.removeLast()
            
            let sl = formantFilter(from: .β)!.multiplyF2To(f2Smp: 0.85, smp: 0.43)
            youonKffs = [.init(sl, sec: 0.01),
                         .init(sl, sec: 0.075)]
            deltaSyllabicStartSec = -0.025
            syllabics.insert(.β, at: 0)
        default:
            youon = .none
            
            youonKffs = []
        }
        
        onsets = []
        keyFormantFilters = []
        isOffVoice = false
        
        let onsetDurSec: Double
        if phonemes.count != 1 {
            onsets = []
            onsetDurSec = 0
        } else {
            let oph = phonemes[0]
            switch oph {
            case .n, .nj:
                let nDurSec = 0.0325
                let nFf = formantFilter(from: oph)!
                let nextFf = youonKffs.first?.formantFilter ?? syllabicFf
                var nnFf = nFf
                nnFf[2, .esSmp] = .linear(nnFf[2, .esSmp], nextFf[2].smp, t: 0.075)
                nnFf[3, .esSmp] = .linear(nnFf[3, .esSmp], nextFf[3].smp, t: 0.025)
                keyFormantFilters.append(.init(nFf, sec: nDurSec))
                keyFormantFilters.append(.init(nnFf, sec: youon != .none ? 0.01 : 0.015))
                deltaSyllabicStartSec = -0.01
                onsetDurSec = nDurSec
            case .m, .mj:
                let mDurSec = 0.0325
                let mFf = formantFilter(from: oph)!
                let nextFf = youonKffs.first?.formantFilter ?? syllabicFf
                var nmFf = mFf
                nmFf[2, .esSmp] = .linear(nmFf[2, .esSmp], nextFf[2].smp, t: 0.075)
                nmFf[3, .esSmp] = .linear(nmFf[3, .esSmp], nextFf[3].smp, t: 0.025)
                keyFormantFilters.append(.init(mFf, sec: mDurSec))
                keyFormantFilters.append(.init(nmFf, sec: youon != .none ? 0.01 : 0.015))
                deltaSyllabicStartSec = -0.01
                onsetDurSec = mDurSec
            case .r, .rj:
                let rDurSec = 0.01
                let rFf = formantFilter(from: oph)!
                let nextFf = youonKffs.first?.formantFilter ?? syllabicFf
                var nrFf = rFf
                nrFf[2, .esSmp] = .linear(nrFf[2, .esSmp], nextFf[2].smp, t: 0.075)
                nrFf[3, .esSmp] = .linear(nrFf[3, .esSmp], nextFf[3].smp, t: 0.025)
                keyFormantFilters.append(.init(rFf, sec: rDurSec))
                keyFormantFilters.append(.init(nrFf, sec: youon != .none ? 0.01 : 0.05))
                deltaSyllabicStartSec = 0.0
                onsetDurSec = rDurSec
                
            case .k, .kj, .g, .gj:
                let kDurSec = 0.055, kjDurSec = 0.07, kODurSec = 0.015, kjODurSec = 0.02
                let gDurSec = 0.045, gjDurSec = 0.045, gODurSec = 0.015, gjODurSec = 0.02
                let isK = oph == .k || oph == .kj
                let isJ = oph == .kj || oph == .gj
                
                let sl: Spectlope, smp: Double
                if isJ || syllabics.first == .e {
                    sl = Spectlope(pitchSmps: [Point(0, 0.5),
                                               Point(89, 0.6),
                                               Point(90, 1),
                                               Point(92, 1),
                                               Point(93, 0.5),
                                               Point(98, 0.4),
                                               Point(99, 0)])
                    smp = 0.46
                } else {
                    switch syllabics.first {
                    case .o:
                        sl = Spectlope(pitchSmps: [Point(0, 0.56),
                                                   Point(67, 0.61),
                                                   Point(71, 1),
                                                   Point(79, 1),
                                                   Point(81, 0.56),
                                                   Point(100, 0.4),
                                                   Point(102, 0)])
                    default:
                        sl = Spectlope(pitchSmps: [Point(0, 0.56),
                                                   Point(77, 0.61),
                                                   Point(80, 1),
                                                   Point(87, 1),
                                                   Point(88, 0.56),
                                                   Point(98, 0.4),
                                                   Point(99, 0)])
                    }
                    smp = 0.56
                }
                
                onsets.append(.init(durSec: isK ? (isJ ? kjODurSec : kODurSec) : (isJ ? gjODurSec : gODurSec),
                                    smp: smp,
                                    sec: isK ? -0.005 : -0.01,
                                    attackSec: 0.02, releaseSec: 0.02,
                                    spectlope: sl,
                                    phoneme: oph))
                deltaSyllabicStartSec = 0.01
                onsetDurSec = isK ? (isJ ? kjDurSec : kDurSec) : (isJ ? gjDurSec : gDurSec)
                isOffVoice = true
            case .t, .d:
                let tDurSec = 0.05, tODurSec = 0.01
                let dDurSec = 0.04, dODurSec = 0.01
                let isT = oph == .t
                onsets.append(.init(durSec: isT ? tODurSec : dODurSec,
                                    smp: 0.5,
                                    sec: isT ? 0 : 0.0075,
                                    attackSec: 0.01, releaseSec: 0.01,
                                    spectlope: .init(noisePitchSmps: [Point(96, 0),
                                                                      Point(97, 1),
                                                                      Point(99, 1),
                                                                      Point(100, 0.7),
                                                                      Point(101, 0.55),
                                                                      Point(102, 0)]),
                                    phoneme: oph))
                deltaSyllabicStartSec = 0.01
                onsetDurSec = isT ? tDurSec : dDurSec
                isOffVoice = true
            case .p, .pj, .b, .bj:
                let pDurSec = 0.05, pODurSec = 0.01
                let bDurSec = 0.04, bODurSec = 0.01
                let isP = oph == .p || oph == .pj
                onsets.append(.init(durSec: isP ? pODurSec : bODurSec,
                                    smp: 0.4,
                                    sec: isP ? 0.005 : 0.0075,
                                    attackSec: 0.01, releaseSec: 0.01,
                                    spectlope: .init(noisePitchSmps: [Point(62, 0),
                                                                      Point(65, 0.85),
                                                                      Point(73, 0.9),
                                                                      Point(74, 1),
                                                                      Point(79, 1),
                                                                      Point(80, 0.85),
                                                                      Point(89, 0.75),
                                                                      Point(90, 0)]), 
                                    phoneme: oph))
                deltaSyllabicStartSec = 0.02
                onsetDurSec = isP ? pDurSec : bDurSec
                isOffVoice = true
                
            case .s, .ts, .dz:
                let sokuonScale = previousPhoneme == .sokuon || isVowelReduction ? 1.5 : 1
                let oDurSec, durSec: Double, smp: Double
                switch oph {
                case .s:
                    oDurSec = 0.08 * sokuonScale
                    durSec = oDurSec
                    smp = 0.7
                case .ts:
                    oDurSec = 0.05 * sokuonScale
                    durSec = 0.09
                    smp = 0.675
                case .dz:
                    oDurSec = 0.06 * sokuonScale
                    durSec = oDurSec - 0.02 + 0.01
                    smp = 0.65
                default: fatalError()
                }
                
                onsets.append(.init(durSec: oDurSec,
                                    smp: smp,
                                    sec: (oph != .dz ? 0.01 : 0.01) + (isVowelReduction ? oDurSec / 3 : 0),
                                    attackSec: oph != .dz ? 0.02 : 0.04,
                                    releaseSec: oph != .dz ? 0.02 : 0.02,
                                    spectlope: .init(noisePitchSmps: [Point(87, 0),
                                                                      Point(89, 0.3),
                                                                      Point(101, 0.45),
                                                                      Point(102, 0.75),
                                                                      Point(108, 0.8),
                                                                      Point(109, 1),
                                                                      Point(113, 1),
                                                                      Point(117, 0.8),
                                                                      Point(119, 0.6),
                                                                      Point(121, 0)]),
                                    phoneme: oph))
                let oarDurSec = onsets.last!.attackSec + onsets.last!.releaseSec
                if oph == .ts {
                    let ooDurSec = 0.01
                    onsets.append(.init(durSec: ooDurSec,
                                        smp: 0.3,
                                        sec: -oDurSec - ooDurSec,
                                        attackSec: 0.01, releaseSec: 0.01,
                                        spectlope: .init(noisePitchSmps: [Point(96, 0),
                                                                          Point(97, 1),
                                                                          Point(99, 1),
                                                                          Point(100, 0.7),
                                                                          Point(101, 0.5),
                                                                          Point(102, 0)]),
                                        phoneme: oph))
                }
                deltaSyllabicStartSec = (oph == .ts ? 0.01 : 0) - 0.01
                onsetDurSec = durSec - oarDurSec
                isOffVoice = true
            case .ɕ, .tɕ, .dʒ:
                let sokuonScale = previousPhoneme == .sokuon || isVowelReduction ? 1.5 : 1
                let oDurSec, durSec: Double, smp: Double
                switch oph {
                case .ɕ:
                    oDurSec = 0.085 * sokuonScale
                    durSec = oDurSec
                    smp = 0.75
                case .tɕ:
                    oDurSec = 0.04 * sokuonScale
                    durSec = 0.08
                    smp = 0.65
                case .dʒ:
                    oDurSec = 0.055 * sokuonScale
                    durSec = oDurSec - 0.02 + 0.02
                    smp = 0.62
                default: fatalError()
                }
                onsets.append(.init(durSec: oDurSec,
                                    smp: smp,
                                    sec: (oph != .dʒ ? 0.01 : 0.02) + (isVowelReduction ? oDurSec / 3 : 0),
                                    attackSec: oph == .tɕ ? 0.01 : (oph != .dz ? 0.02 : 0.04),
                                    releaseSec: oph != .dz ? 0.02 : 0.01,
                                    spectlope: .init(noisePitchSmps: [Point(71, 0.1),
                                                                      Point(94, 0.2),
                                                                      Point(95, 0.6),
                                                                      Point(100, 0.7),
                                                                      Point(102, 1),
                                                                      Point(112, 1),
                                                                      Point(116, 0.8),
                                                                      Point(119, 0.6),
                                                                      Point(121, 0)]),
                                    phoneme: oph))
                let oarDurSec = onsets.last!.attackSec + onsets.last!.releaseSec
                if oph == .tɕ {
                    let ooDurSec = 0.01
                    onsets.append(.init(durSec: ooDurSec,
                                        smp: 0.3,
                                        sec: -oDurSec - ooDurSec,
                                        attackSec: 0.01, releaseSec: 0.01,
                                        spectlope: .init(noisePitchSmps: [Point(96, 0),
                                                                          Point(97, 1),
                                                                          Point(99, 1),
                                                                          Point(100, 0.7),
                                                                          Point(101, 0.5),
                                                                          Point(103, 0)]), 
                                        phoneme: oph))
                }
                deltaSyllabicStartSec = -0.01
                onsetDurSec = durSec - oarDurSec
                isOffVoice = true
            case .h:
                let sokuonScale = previousPhoneme == .sokuon || isVowelReduction ? 1.5 : 1
                let hDurSec = 0.06 * sokuonScale
                let pFf = youonKffs.first?.formantFilter ?? syllabicFf
                let npFf = pFf.fricative(isO: syllabics.first == .o).toNoise()
                onsets.append(.init(durSec: hDurSec,
                                    smp: 0.37,
                                    sec: 0.02 + (isVowelReduction ? hDurSec / 3 : 0),
                                    attackSec: 0.02, releaseSec: 0.02,
                                    spectlope: npFf.spectlope,
                                    phoneme: oph))
                deltaSyllabicStartSec = -0.01
                onsetDurSec = hDurSec - onsets.last!.attackSec - onsets.last!.releaseSec
                isOffVoice = true
            case .ç:
                let sokuonScale = previousPhoneme == .sokuon || isVowelReduction ? 1.5 : 1
                let çDurSec = 0.06 * sokuonScale
                onsets.append(.init(durSec: çDurSec,
                                    smp: 0.37,
                                    sec: 0.02 + (isVowelReduction ? çDurSec / 3 : 0),
                                    attackSec: 0.02, releaseSec: 0.02,
                                    spectlope: .init(noisePitchSmps: [Point(91, 0),
                                                                      Point(92, 1),
                                                                      Point(96, 1),
                                                                      Point(97, 0.56),
                                                                      Point(98, 0.7),
                                                                      Point(99, 1),
                                                                      Point(111, 1),
                                                                      Point(113, 0.56),
                                                                      Point(114, 0.3),
                                                                      Point(116, 0)]), 
                                    phoneme: oph))
                deltaSyllabicStartSec = -0.01
                onsetDurSec = çDurSec - onsets.last!.attackSec - onsets.last!.releaseSec
                isOffVoice = true
            case .ɸ:
                let sokuonScale = previousPhoneme == .sokuon || isVowelReduction ? 1.5 : 1
                let ɸDurSec = 0.06 * sokuonScale
                onsets.append(.init(durSec: ɸDurSec,
                                    smp: 0.2,
                                    sec: 0.02 + (isVowelReduction ? ɸDurSec / 3 : 0),
                                    attackSec: 0.02, releaseSec: 0.02,
                                    spectlope: .init(noisePitchSmps: [Point(81, 0),
                                                                      Point(83, 0.52),
                                                                      Point(100, 0.7),
                                                                      Point(101, 1),
                                                                      Point(102, 1),
                                                                      Point(103, 0.7),
                                                                      Point(109, 0.66),
                                                                      Point(111, 0.56),
                                                                      Point(120, 0.3),
                                                                      Point(121, 0)]), 
                                    phoneme: oph))
                deltaSyllabicStartSec = -0.01
                onsetDurSec = ɸDurSec - onsets.last!.attackSec - onsets.last!.releaseSec
                isOffVoice = true
            default:
                onsets = []
                onsetDurSec = 0
            }
        }
        
        keyFormantFilters += youonKffs
        keyFormantFilters.append(.init(syllabicFf, sec: 0))
        
        let firstFF = keyFormantFilters.first!.formantFilter
        
        if isOffVoice && youon == .none {
            if phonemes.last == .g || phonemes.last == .d || phonemes.last == .b {
                let oFf = switch phonemes.last {
                case .g:
                    syllabics.last! == .o || syllabics.last! == .ɯ ?
                        firstFF.movedF2(sPitch: 74, ePitch: 77) :
                        firstFF.movedF2(sPitch: 89, ePitch: 91)
                case .d: firstFF.movedF2(sPitch: 79, ePitch: 83)
                case .b: firstFF.movedF2(sPitch: 62, ePitch: 67)
                default: fatalError()
                }
                let nFf = FormantFilter.linear(oFf, firstFF, t: 0.8).voiceless()
                keyFormantFilters.insert(.init(nFf, sec: 0.075 * 0.25), at: 0)
                let nnFf = FormantFilter.linear(nFf, firstFF, t: 0.25).filledSmp(from: firstFF)
                keyFormantFilters.insert(.init(nnFf, sec: 0.075 * 0.75), at: 1)
            } else {
                let nFf = firstFF.voiceless()
                keyFormantFilters.insert(.init(nFf, sec: 0.075 * 0.25), at: 0)
                let nnFf = FormantFilter.linear(nFf, firstFF, t: 0.25).filledSmp(from: firstFF)
                keyFormantFilters.insert(.init(nnFf, sec: 0.075 * 0.75), at: 1)
            }
        } else if isVowel {
            let nFf = firstFF.offVoice()
            keyFormantFilters.insert(.init(nFf, sec: 0.02), at: 0)
        }
        
        if let ff = previousFormantFilter {
            keyFormantFilters.insert(.init(ff, sec: 0.025), at: 0)
        }
        
        isDakuon = firstType == .dakuon
        if isDakuon {
            onsets.append(.init(durSec: onsetDurSec * 0.9, 
                                smp: 0.5,
                                sec: 0,
                                attackSec: 0.01, releaseSec: 0.02,
                                spectlope: .init(pitchSmps: [Point(55, 1),
                                                             Point(65, 0.56),
                                                             Point(87, 0.43),
                                                             Point(93, 0)]), 
                                phoneme: phonemes[0]))
            
            let ff = keyFormantFilters[.first].formantFilter.toDakuon()
            keyFormantFilters.insert(.init(ff, sec: 0.0075), at: 0)
            keyFormantFilters.insert(.init(ff, sec: 0.01), at: 1)
        }
        
        var sec = keyFormantFilters.count >= 2 ? -keyFormantFilters[keyFormantFilters.count - 2].sec : 0
        keyFormantFilters = keyFormantFilters.map {
            let kff = KeyFormantFilter($0.formantFilter, sec: sec)
            sec += $0.sec
            return kff
        }
        deltaSyllabicStartSec += sec
    }
}

enum Phoneme: String, Hashable, Codable, CaseIterable {
    case a, i, ɯ, e, o, j, ja, β, nn,
         k, kj, s, ɕ, t, tɕ, ts, n, nj, h, ç, ɸ, p, pj, m, mj, r, rj,
         g, gj, dz, dʒ, d, b, bj,
         sokuon = "_", breath = "^"
}
extension Phoneme {
    var isVowel: Bool {
        switch self {
        case .a, .i, .ɯ, .e, .o: true
        default: false
        }
    }
    var isSyllabicJapanese: Bool {
        switch self {
        case .a, .i, .ɯ, .e, .o, .nn: true
        default: false
        }
    }
    var isConsonant: Bool {
        !isVowel
    }
    var isVoiceBar: Bool {
        switch self {
        case .g, .gj, .dz, .dʒ, .d, .b, .bj: true
        default: false
        }
    }
    var isVoicelessSound: Bool {
        switch self {
        case .k, .kj, .s, .ɕ, .t, .tɕ, .ts, .h, .ç, .ɸ, .p, .pj: true
        default: false
        }
    }
}
extension Phoneme {
    static func phonemes(fromHiragana hiragana: String) -> [Phoneme] {
        switch hiragana {
        case "あ", "a": [.a]
        case "い", "i": [.i]
        case "う", "u": [.ɯ]
        case "え", "e": [.e]
        case "お", "を", "o", "wo": [.o]
        case "か", "ka": [.k, .a]
        case "き", "ki": [.kj, .i]
        case "く", "ku": [.k, .ɯ]
        case "け", "ke": [.k, .e]
        case "こ", "ko": [.k, .o]
        case "きゃ", "kya": [.kj, .ja, .a]
        case "きゅ", "kyu": [.kj, .j, .ɯ]
        case "きぇ", "kye": [.kj, .j, .e]
        case "きょ", "kyo": [.kj, .j, .o]
        case "くぁ", "くゎ", "kwa": [.k, .β, .a]
        case "くぃ", "kwi": [.k, .β, .i]
        case "くぇ", "kwe": [.k, .β, .e]
        case "くぉ", "kwo": [.k, .β, .o]
        case "が", "ga": [.g, .a]
        case "ぎ", "gi": [.gj, .i]
        case "ぐ", "gu": [.g, .ɯ]
        case "げ", "ge": [.g, .e]
        case "ご", "go": [.g, .o]
        case "ぎゃ", "gya": [.gj, .ja, .a]
        case "ぎゅ", "gyu": [.gj, .j, .ɯ]
        case "ぎぇ", "gye": [.gj, .j, .e]
        case "ぎょ", "gyo": [.gj, .j, .o]
        case "ぐぁ", "ぐゎ", "gwa": [.g, .β, .a]
        case "ぐぃ", "gwi": [.g, .β, .ɯ]
        case "ぐぇ", "gwe": [.g, .β, .e]
        case "ぐぉ", "gwo": [.g, .β, .o]
        case "さ", "sa": [.s, .a]
        case "し", "si", "shi": [.ɕ, .i]
        case "す", "su": [.s, .ɯ]
        case "せ", "se": [.s, .e]
        case "そ", "so": [.s, .o]
        case "しゃ", "sya", "sha": [.ɕ, .a]
        case "しゅ", "syu", "shu": [.ɕ, .ɯ]
        case "しぇ", "sye", "she": [.ɕ, .e]
        case "しょ", "syo", "sho": [.ɕ, .o]
        case "すぁ", "すゎ", "swa": [.s, .β, .a]
        case "すぃ", "swi": [.s, .β, .i]
        case "すぇ", "swe": [.s, .β, .e]
        case "すぉ", "swo": [.s, .β, .o]
        case "ざ", "za": [.dz, .a]
        case "じ", "ぢ", "zi", "ji", "di": [.dʒ, .i]
        case "ず", "づ", "zu", "du": [.dz, .ɯ]
        case "ぜ", "ze": [.dz, .e]
        case "ぞ", "zo": [.dz, .o]
        case "じゃ", "ぢゃ", "ja", "jya", "dya": [.dʒ, .ja, .a]
        case "じゅ", "ぢゅ", "ju", "jyu", "dyu": [.dʒ, .j, .ɯ]
        case "じぇ", "ぢぇ", "je", "jye", "dye": [.dʒ, .j, .e]
        case "じょ", "ぢょ", "jo", "jyo", "dyo": [.dʒ, .j, .o]
        case "ずぁ", "ずゎ", "づぁ", "づゎ", "zwa", "dwa": [.dz, .β, .a]
        case "ずぃ", "づぃ", "zwi", "dwi": [.dz, .β, .i]
        case "ずぇ", "づぇ", "zwe", "dwe": [.dz, .β, .e]
        case "ずぉ", "づぉ", "zwo", "dwo": [.dz, .β, .o]
        case "た", "ta": [.t, .a]
        case "ち", "ti", "chi": [.tɕ, .i]
        case "つ", "tu", "tsu": [.ts, .ɯ]
        case "て", "te": [.t, .e]
        case "と", "to": [.t, .o]
        case "てぃ", "thi": [.t, .i]
        case "とぅ", "twu": [.t, .ɯ]
        case "ちゃ", "cya", "cha": [.tɕ, .ja, .a]
        case "ちゅ", "cyu", "chu": [.tɕ, .j, .ɯ]
        case "ちぇ", "cye", "che": [.tɕ, .j, .e]
        case "ちょ", "cyo", "cho": [.tɕ, .j, .o]
        case "つぁ", "tuxa": [.ts, .β, .a]
        case "つぃ", "tuxi": [.ts, .β, .i]
        case "つぇ", "tuxe": [.ts, .β, .e]
        case "つぉ", "tuxo": [.ts, .β, .o]
        case "だ", "da": [.d, .a]
        case "で", "de": [.d, .e]
        case "ど", "do": [.d, .o]
        case "でぃ", "dhi": [.d, .i]
        case "どぅ", "dwu": [.d, .ɯ]
        case "な", "na": [.n, .a]
        case "に", "ni": [.nj, .i]
        case "ぬ", "nu": [.n, .ɯ]
        case "ね", "ne": [.n, .e]
        case "の", "no": [.n, .o]
        case "にゃ", "nya": [.nj, .ja, .a]
        case "にゅ", "nyu": [.nj, .j, .ɯ]
        case "にぇ", "nye": [.nj, .j, .e]
        case "にょ", "nyo": [.nj, .j, .o]
        case "ぬぁ", "ぬゎ", "nwa": [.n, .β, .a]
        case "ぬぃ", "nwi": [.n, .β, .i]
        case "ぬぇ", "nwe": [.n, .β, .e]
        case "ぬぉ", "nwo": [.n, .β, .o]
        case "は", "ha": [.h, .a]
        case "ひ", "hi": [.ç, .i]
        case "ふ", "hu", "fu": [.ɸ, .ɯ]
        case "へ", "he": [.h, .e]
        case "ほ", "ho": [.h, .o]
        case "ひゃ", "hya": [.ç, .ja, .a]
        case "ひゅ", "hyu": [.ç, .j, .ɯ]
        case "ひぇ", "hye": [.ç, .j, .e]
        case "ひょ", "hyo": [.ç, .j, .o]
        case "ふぁ", "fa": [.ɸ, .β, .a]
        case "ふぃ", "fi": [.ɸ, .β, .i]
        case "ふぇ", "fe": [.ɸ, .β, .e]
        case "ふぉ", "fo": [.ɸ, .β, .o]
        case "ば", "ba": [.b, .a]
        case "び", "bi": [.bj, .i]
        case "ぶ", "bu": [.b, .ɯ]
        case "べ", "be": [.b, .e]
        case "ぼ", "bo": [.b, .o]
        case "びゃ", "bya": [.bj, .ja, .a]
        case "びゅ", "byu": [.bj, .j, .ɯ]
        case "びぇ", "bye": [.bj, .j, .e]
        case "びょ", "byo": [.bj, .j, .o]
        case "ぶぁ", "ぶゎ", "bwa": [.b, .β, .a]
        case "ぶぃ", "bwi": [.b, .β, .i]
        case "ぶぇ", "bwe": [.b, .β, .e]
        case "ぶぉ", "bwo": [.b, .β, .o]
        case "ぱ", "pa": [.p, .a]
        case "ぴ", "pi": [.pj, .i]
        case "ぷ", "pu": [.p, .ɯ]
        case "ぺ", "pe": [.p, .e]
        case "ぽ", "po": [.p, .o]
        case "ぴゃ", "pya": [.pj, .ja, .a]
        case "ぴゅ", "pyu": [.pj, .j, .ɯ]
        case "ぴぇ", "pye": [.pj, .j, .e]
        case "ぴょ", "pyo": [.pj, .j, .o]
        case "ぷぁ", "ぷゎ", "pwa": [.p, .β, .a]
        case "ぷぃ", "pwi": [.p, .β, .i]
        case "ぷぇ", "pwe": [.p, .β, .e]
        case "ぷぉ", "pwo": [.p, .β, .o]
        case "ま", "ma": [.m, .a]
        case "み", "mi": [.mj, .i]
        case "む", "mu": [.m, .ɯ]
        case "め", "me": [.m, .e]
        case "も", "mo": [.m, .o]
        case "みゃ", "mya": [.mj, .ja, .a]
        case "みゅ", "myu": [.mj, .j, .ɯ]
        case "みぇ", "mye": [.mj, .j, .e]
        case "みょ", "myo": [.mj, .j, .o]
        case "むぁ", "むゎ", "mwa": [.m, .β, .a]
        case "むぃ", "mwi": [.m, .β, .i]
        case "むぇ", "mwe": [.m, .β, .e]
        case "むぉ", "mwo": [.m, .β, .o]
        case "や", "ya": [.ja, .a]
        case "ゆ", "yu": [.j, .ɯ]
        case "いぇ", "ye": [.j, .e]
        case "よ", "yo": [.j, .o]
        case "ら", "ra": [.r, .a]
        case "り", "ri": [.rj, .i]
        case "る", "ru": [.r, .ɯ]
        case "れ", "re": [.r, .e]
        case "ろ", "ro": [.r, .o]
        case "りゃ", "rya": [.rj, .ja, .a]
        case "りゅ", "ryu": [.rj, .j, .ɯ]
        case "りぇ", "rye": [.rj, .j, .e]
        case "りょ", "ryo": [.rj, .j, .o]
        case "るぁ", "るゎ", "rwa": [.r, .β, .a]
        case "るぃ", "rwi": [.r, .β, .i]
        case "るぇ", "rwe": [.r, .β, .e]
        case "るぉ", "rwo": [.r, .β, .o]
        case "わ", "wa": [.β, .a]
        case "うぃ", "wi", "whi": [.β, .i]
        case "うぇ", "we", "whe": [.β, .e]
        case "うぉ", "who": [.β, .o]
        case "ん", "n", "nn": [.nn]
        case "っ", "xtu", "_": [.sokuon]
        case "^": [.breath]
        default: []
        }
    }
    static func isSyllabicJapanese(_ phonemes: [Phoneme]) -> Bool {
        phonemes.count == 1 && phonemes[0].isSyllabicJapanese
    }
}
