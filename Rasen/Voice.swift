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
import struct Foundation.UUID

extension Note {
    mutating func replaceAndOnsetNotes(lyric: String, at i: Int,
                                       tempo: Rational,
                                       beatRate: Int = 96 * 2, pitchRate: Int = 96) -> [Note] {
        self.pits[i].lyric = lyric
        
        let previousPhoneme: Phoneme?, previousFormantFilter: FormantFilter?, previousID: UUID?
        if let preI = i.range.reversed().first(where: { !pits[$0].lyric.isEmpty }) {
            var preLyric = pits[preI].lyric
            if preLyric.last == "/" {
                preLyric.removeLast()
            }
            previousPhoneme = Phoneme.phonemes(fromHiragana: preLyric).last
            previousFormantFilter = .init(spectlope: pits[preI].tone.spectlope)
            previousID = pits[preI].tone.id
        } else {
            previousPhoneme = nil
            previousFormantFilter = nil
            previousID = nil
        }
        
        if let mora = Mora(hiragana: lyric,
                           previousPhoneme: previousPhoneme,
                           previousFormantFilter: previousFormantFilter, previousID: previousID) {
            var beat = pits[i].beat
            let pitch = pits[i].pitch + pitch
            let volm = pits[i].stereo.volm
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
                                               pitch: result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval) + ff.pitch,
                                               stereo: .init(volm: pits[i].stereo.volm * ff.volm,
                                                             pan: result.stereo.pan,
                                                             id: ff.volm == 1 ? result.stereo.id : .init()),
                                               tone: .init(spectlope: ff.formantFilter.spectlope, id: ff.id),
                                               lyric: fi == mora.keyFormantFilters.count - 1 ? lyric : ""),
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
                beat -= dBeat
            }
            
            let onsetBeat = beat + beatRange.start
            return mora.onsets.map {
                let sBeat = Score.beat(fromSec: $0.sec, tempo: tempo, beatRate: beatRate) + onsetBeat
                let eBeat = Score.beat(fromSec: $0.durSec - $0.releaseSec,
                                       tempo: tempo, beatRate: beatRate) + sBeat
                return Note(beatRange: sBeat ..< eBeat,
                            pitch: Rational(min($0.spectlope.sprols.first?.pitch ?? 0, Double(pitch) + 6),
                                            intervalScale: Rational(1, pitchRate)),
                            pits: [.init(beat: 0, pitch: 0,
                                         stereo: .init(volm: volm * $0.volm, pan: 0),
                                         tone: .init(spectlope: $0.spectlope),
                                         lyric: $0.phoneme.rawValue)],
                            envelope: .init(attackSec: $0.attackSec, decaySec: 0,
                                            sustainVolm: 1, releaseSec: $0.releaseSec))
            }
        }
        
        return []
    }
}

struct Formant: Hashable, Codable {
    var sprol0 = Sprol(), sprol1 = Sprol(), sprol2 = Sprol(), sprol3 = Sprol()
}
extension Formant {
    init(sdVolm: Double, sdNoise: Double,
         sdPitch: Double, sPitch: Double, ePitch: Double, edPitch: Double,
         volm: Double, noise: Double, edVolm: Double, edNoise: Double) {
        
        sprol0 = .init(pitch: sPitch - sdPitch, volm: sdVolm, noise: sdNoise)
        sprol1 = .init(pitch: sPitch, volm: volm, noise: noise)
        sprol2 = .init(pitch: ePitch, volm: volm, noise: noise)
        sprol3 = .init(pitch: ePitch + edPitch, volm: edVolm, noise: edNoise)
    }
    init(pitches: [Double], volms: [Double]) {
        sprol0 = .init(pitch: pitches[0], volm: volms[0])
        sprol1 = .init(pitch: pitches[1], volm: volms[1])
        sprol2 = .init(pitch: pitches[2], volm: volms[2])
        sprol3 = .init(pitch: pitches[3], volm: volms[3])
    }
    init(pitches: [Double], noises: [Double]) {
        sprol0 = .init(pitch: pitches[0], noise: noises[0])
        sprol1 = .init(pitch: pitches[1], noise: noises[1])
        sprol2 = .init(pitch: pitches[2], noise: noises[2])
        sprol3 = .init(pitch: pitches[3], noise: noises[3])
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
            let edPitch = edPitch
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
    
    var sdVolm: Double {
        get { sprol0.volm }
        set { sprol0.volm = newValue }
    }
    var sVolm: Double {
        get { sprol1.volm }
        set { sprol1.volm = newValue }
    }
    var eVolm: Double {
        get { sprol2.volm }
        set { sprol2.volm = newValue }
    }
    var edVolm: Double {
        get { sprol3.volm }
        set { sprol3.volm = newValue }
    }

    var volm: Double {
        sVolm.mid(eVolm)
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
        sNoise.mid(eNoise)
    }
    
    mutating func formMultiplyVolm(_ x: Double) {
        sprol1.volm *= x
        sprol2.volm *= x
    }
    func multiplyVolm(_ x: Double) -> Self {
        var n = self
        n.formMultiplyVolm(x)
        return n
    }
    mutating func formMultiplyAllVolm(_ x: Double) {
        sprol0.volm *= x
        sprol1.volm *= x
        sprol2.volm *= x
        sprol3.volm *= x
    }
    func multiplyAllVolm(_ x: Double) -> Self {
        var n = self
        n.formMultiplyAllVolm(x)
        return n
    }
    
    mutating func formMultiplyNoise(_ x: Double) {
        sprol1.noise = (sprol1.noise * x).clipped(min: 0, max: 1)
        sprol2.noise = (sprol2.noise * x).clipped(min: 0, max: 1)
    }
    func multiplyNoise(_ x: Double) -> Self {
        var n = self
        n.formMultiplyNoise(x)
        return n
    }
    mutating func formMultiplyAllNoise(_ x: Double) {
        sprol0.noise = (sprol0.noise * x).clipped(min: 0, max: 1)
        sprol1.noise = (sprol1.noise * x).clipped(min: 0, max: 1)
        sprol2.noise = (sprol2.noise * x).clipped(min: 0, max: 1)
        sprol3.noise = (sprol3.noise * x).clipped(min: 0, max: 1)
    }
    func multiplyAllNoise(_ x: Double) -> Self {
        var n = self
        n.formMultiplyAllNoise(x)
        return n
    }
    
    mutating func fillVolm(_ x: Double) {
        sprol1.volm = x
        sprol2.volm = x
    }
    func filledVolm(_ x: Double) -> Self {
        var n = self
        n.fillVolm(x)
        return n
    }
    mutating func fillAllVolm(_ x: Double) {
        sprol0.volm = x
        sprol1.volm = x
        sprol2.volm = x
        sprol3.volm = x
    }
    func filledAllVolm(_ x: Double) -> Self {
        var n = self
        n.fillAllVolm(x)
        return n
    }
    
    mutating func fillAllVolm(_ other: Self) {
        sprol0.volm = other.sprol0.volm
        sprol1.volm = other.sprol1.volm
        sprol2.volm = other.sprol2.volm
        sprol3.volm = other.sprol3.volm
    }
    func filledVolm(_ other: Self) -> Self {
        var n = self
        n.fillAllVolm(other)
        return n
    }
    
    mutating func fillNoise(_ x: Double) {
        sprol1.noise = x
        sprol2.noise = x
    }
    func filledNoise(_ x: Double) -> Self {
        var n = self
        n.fillNoise(x)
        return n
    }
    mutating func fillAllNoise(_ x: Double) {
        sprol0.noise = x
        sprol1.noise = x
        sprol2.noise = x
        sprol3.noise = x
    }
    func filledAllNoise(_ x: Double) -> Self {
        var n = self
        n.fillAllNoise(x)
        return n
    }
    
    mutating func fillAllNoise(_ other: Self) {
        sprol0.noise = other.sprol0.noise
        sprol1.noise = other.sprol1.noise
        sprol2.noise = other.sprol2.noise
        sprol3.noise = other.sprol3.noise
    }
    func filledAllNoise(_ other: Self) -> Self {
        var n = self
        n.fillAllNoise(other)
        return n
    }
    
    mutating func formToAllNoise() {
        fillAllNoise(1)
    }
    func toAllNoise() -> Self {
        var n = self
        n.formToAllNoise()
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
    var formants: [Formant] = [.init(sdVolm: 0.65, sdNoise: 0.1,
                                     sdPitch: 14, sPitch: 68, ePitch: 73, edPitch: 10,
                                     volm: 1, noise: 0.1,
                                     edVolm: 0.5, edNoise: 0.1),
                               .init(sdVolm: 0.5, sdNoise: 0.1,
                                     sdPitch: 6, sPitch: 80, ePitch: 84, edPitch: 4,
                                     volm: 1, noise: 0.25,
                                     edVolm: 0.25, edNoise: 0.1),
                               .init(sdVolm: 0.25, sdNoise: 0.1,
                                     sdPitch: 2, sPitch: 94, ePitch: 96, edPitch: 2,
                                     volm: 0.82, noise: 0.3,
                                     edVolm: 0.125, edNoise: 0.1),
                               .init(sdVolm: 0.125, sdNoise: 0.1,
                                     sdPitch: 1, sPitch: 98, ePitch: 100, edPitch: 1,
                                     volm: 0.5, noise: 0.4,
                                     edVolm: 0, edNoise: 0.3),
                               .init(sdVolm: 0, sdNoise: 0.3,
                                     sdPitch: 1, sPitch: 103, ePitch: 105, edPitch: 1,
                                     volm: 0.25, noise: 0.5,
                                     edVolm: 0, edNoise: 0.7),
                               .init(sdVolm: 0, sdNoise: 0.3,
                                     sdPitch: 1, sPitch: 107, ePitch: 109, edPitch: 1,
                                     volm: 0.25, noise: 0.5,
                                     edVolm: 0, edNoise: 0.7)]
}
extension FormantFilter {
    init(spectlope: Spectlope) {
        self.formants = spectlope.formants
    }
    var spectlope: Spectlope {
        .init(sprols: formants.flatMap { [$0.sprol0, $0.sprol1, $0.sprol2, $0.sprol3] })
    }
}
enum FormantFilterVolmType {
    case esVolm, esNoise
}
extension FormantFilter {
    mutating func fillEsVolm(_ x: Double, at i: Int) {
        self[i].edVolm = x
        self[i + 1].sdVolm = x
    }
    mutating func fillEsNoise(_ x: Double, at i: Int) {
        self[i].edNoise = x
        self[i + 1].sdNoise = x
    }
    mutating func formMultiplyEsVolm(_ x: Double, at i: Int) {
        self[i].edVolm *= x
        self[i + 1].sdVolm *= x
    }
    mutating func formFillEsVolm(_ x: Double, at i: Int) {
        self[i].edVolm = x
        self[i + 1].sdVolm = x
    }
    mutating func formMultiplyEsVolm(to x: Double, t: Double, at i: Int) {
        self[i].edVolm = .linear(self[i].edVolm, x, t: t)
        self[i + 1].sdVolm = .linear(self[i + 1].sdVolm, x, t: t)
    }
}
extension FormantFilter {
    func toA(from fromPhoneme: Phoneme) -> Self {
        var n = withSelfA(to: fromPhoneme)
        func substructPitch(from v0: Sprol, to v1: Sprol) -> Double {
            (v0.pitch * 2 - v1.pitch).clipped(Score.doublePitchRange)
        }
        func substructVolm(from v0: Sprol, to v1: Sprol) -> Double {
            v1.volm == 0 ? 0 : (v0.volm.squared / v1.volm).clipped(min: 0, max: 1)
        }
        func substructNoise(from v0: Sprol, to v1: Sprol) -> Double {
            v1.noise == 0 ? 0 : (v0.noise.squared / v1.noise).clipped(min: 0, max: 1)
        }
        for i in Swift.min(n.count, self.count).range {
            n[i].sprol0.pitch = substructPitch(from: self[i].sprol0, to: n[i].sprol0)
            n[i].sprol1.pitch = substructPitch(from: self[i].sprol1, to: n[i].sprol1)
            n[i].sprol2.pitch = substructPitch(from: self[i].sprol2, to: n[i].sprol2)
            n[i].sprol3.pitch = substructPitch(from: self[i].sprol3, to: n[i].sprol3)
            n[i].sprol0.volm = substructVolm(from: self[i].sprol0, to: n[i].sprol0)
            n[i].sprol1.volm = substructVolm(from: self[i].sprol1, to: n[i].sprol1)
            n[i].sprol2.volm = substructVolm(from: self[i].sprol2, to: n[i].sprol2)
            n[i].sprol3.volm = substructVolm(from: self[i].sprol3, to: n[i].sprol3)
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
        return if let phoneme = phonemes.last, phoneme.isJapaneseVowel {
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
            n[0].sdPitch += 5
            n[0].pitch += -19
            n[0].edPitch += 5
            n.formMultiplyEsVolm(0.5, at: 0)
            n[1].pitch += 8.5
            n[1].sdPitch += -2
            n[1].edPitch += -2
            n[1].formMultiplyVolm(0.875)
            n[2].sdPitch += -2
            n[2].pitch += -1
            n[3].pitch += -0.5
            return n
        case .j:
            var n = withSelfA(to: .i)
            n[0].formMultiplyVolm(0.875)
            n[1].pitch += -2.75
            n[1].dPitch += -2
            n[2].pitch += -1
            n[3].pitch += -0.5
            return n
        case .ja:
            var n = withSelfA(to: .j)
            n[3].pitch += -0.375
            return n
        case .ɯ:
            var n = self
            n[0].pitch += -16
            n.formMultiplyEsVolm(0.75, at: 0)
            n[1].pitch += 1
            n[1].formMultiplyVolm(0.75)
            n.formMultiplyEsVolm(0.75, at: 1)
            n[2].pitch += -1
            n[3].pitch += -0.5
            return n
        case .β:
            var n = withSelfA(to: .ɯ)
            n[0].pitch += -3.5
            n[0].formMultiplyVolm(0.875)
            n[1].pitch += -6.75
            n[1].formMultiplyVolm(0.75)
            n[2].formMultiplyVolm(0.35)
            n.formMultiplyEsVolm(0.0625, at: 2)
            n[3].formMultiplyVolm(0.1)
            n.formMultiplyEsVolm(0, at: 3)
            n[4].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 4)
            return n
        case .e:
            var n = self
            n[0].pitch += -8.5
            n[0].sdPitch += 8
            n[0].ePitch += -2
            n[0].edPitch += 6
            n.formMultiplyEsVolm(0.75, at: 0)
            n[1].pitch += 5.25
            n[2].pitch += -0.5
            n[3].pitch += -0.25
            return n
        case .o:
            var n = self
            n[0].pitch += -8.25
            n.formMultiplyEsVolm(0.7, at: 0)
            n[1].pitch += -4.75
            n.formMultiplyEsVolm(0.67, at: 1)
            n[2].pitch += 1
            n[3].pitch += 0.5
            return n
        case .ɴ:
            var n = self
            n[0].sdPitch += 7
            n[0].pitch += -19
            n[0].edPitch += 7
            n.formMultiplyEsVolm(0.37, at: 0)
            n[1].pitch += 0.875
            n[1].formMultiplyVolm(0.43)
            n.formMultiplyEsVolm(0.34, at: 1)
            n[2].pitch += -0.375
            n[2].formMultiplyVolm(0.4)
            n.formMultiplyEsVolm(0.06, at: 2)
            n[3].pitch += -0.17
            n[3].formMultiplyVolm(0.3)
            n.formMultiplyEsVolm(0.05, at: 3)
            n[4].formMultiplyVolm(0.25)
            n.formMultiplyEsVolm(0.05, at: 4)
            n[2].formMultiplyNoise(1.25)
            n[3].formMultiplyNoise(1.5)
            n[4].formMultiplyNoise(1.75)
            return n
        case .n:
            var n = self
            n[0].sdPitch += 7
            n[0].pitch += -19
            n[0].edPitch += 7
            n.formMultiplyEsVolm(0.45, at: 0)
            n[1].pitch += 7
            n[1].dPitch += -1
            n[1].formMultiplyVolm(0.55)
            n.formMultiplyEsVolm(0.25, at: 1)
            n[2].pitch += 7
            n[2].dPitch += -1
            n[2].formMultiplyVolm(0.75)
            n.formMultiplyEsVolm(0, at: 2)
            n[3].pitch += -0.15
            n[3].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 3)
            n[4].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 4)
            n[2].formMultiplyNoise(1.25)
            n[3].formMultiplyNoise(1.5)
            n[4].formMultiplyNoise(1.75)
            return n
        case .nj:
            var n = withSelfA(to: .n)
            n[1].pitch += 1.5
            return n
        case .m, .mj:
            var n = withSelfA(to: .n)
            n[0].sdPitch += 7
            n[0].pitch += -10
            n[0].edPitch += 7
            n[1].pitch += -10
            n[2].pitch += -10
            n[3].pitch += -1
            return n
        case .r:
            var n = self
            n[0].sdPitch += 5
            n[0].pitch += -17
            n[0].edPitch += 5
            n[0].formMultiplyVolm(0.6)
            n.formMultiplyEsVolm(0.25, at: 0)
            n[1].pitch += 1
            n[1].formMultiplyVolm(0.5)
            n.formMultiplyEsVolm(0.25, at: 1)
            n[2].pitch += -1
            n[2].formMultiplyVolm(0.75)
            n.formMultiplyEsVolm(0, at: 2)
            n[3].formMultiplyVolm(0.125)
            n.formMultiplyEsVolm(0, at: 3)
            n[4].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 4)
            n[5].formMultiplyVolm(0)
            n.formMultiplyEsVolm(0, at: 5)
            return n
        case .rj:
            var n = withSelfA(to: .r)
            n[1].pitch += 1.5
            return n
        case .s, .dz:
            var n = movedF2(sPitch: 84, ePitch: 85)
            if phoneme == .dz {
                n = n.toDakuon()
            } else {
                n = n.toVoiceless()
            }
            return n
//            [Point(87, 0),
//                                              Point(89, 0.3),
//                                              Point(101, 0.45),
//                                              Point(102, 0.75),
//                                              Point(108, 0.8),
//                                              Point(109, 1),
//                                              Point(113, 1),
//                                              Point(117, 0.8),
//                                              Point(119, 0.6),
//                                              Point(121, 0)]
        case .ɕ, .dʒ:
            var n = movedF2(sPitch: 84, ePitch: 85).toNoise().offVolm(to: 1)
            if phoneme == .dʒ {
                n = n.toDakuon()
            }
            n[2].sdVolm = 0
            n[2].fillVolm(0.6)
            n.formFillEsVolm(0.65, at: 2)
            n[3].fillVolm(0.7)
            n.formFillEsVolm(0.8, at: 3)
            n[4].fillVolm(1)
            n.formFillEsVolm(1, at: 4)
            n[5].fillVolm(1)
            n[5].pitch += 1
            n[5].dPitch *= 2
            n[5].edPitch += 7
            return n
//            [Point(71, 0.1),
//                                              Point(94, 0.2),
//                                              Point(95, 0.6),//2
//                                              Point(100, 0.7),//3
//                                              Point(102, 1),//4
//                                              Point(112, 1),//5
//                                              Point(116, 0.8),
//                                              Point(119, 0.6),
//                                              Point(121, 0)]
        case .ha, .he, .ho:
            var n = withSelfA(to: phoneme == .ho ? .o : (phoneme == .he ? .e : .a))
                .toFricative(isO: phoneme == .ho).toNoise()
            n[0].fillNoise(0)
            n.fillEsNoise(0.25, at: 0)
            n[1].fillNoise(0.5)
            return n
        case .ç:
            var n = toNoise()
            n[0].sdVolm *= 0.56
            n[0].formMultiplyVolm(0.25)
            n.formMultiplyEsVolm(0.125, at: 0)
            n[0].fillNoise(0)
            n.fillEsNoise(0.25, at: 0)
            n[1].formMultiplyVolm(0.5)
            n.formMultiplyEsVolm(0.5, at: 1)
            n[1].fillNoise(0.5)
            n[2].dPitch += 2
            n[2].pitch += -1
            n[2].fillVolm(1)
            n.fillEsVolm(0.6, at: 2)
            n[3].pitch += 1
            n[3].fillVolm(1)
            n.fillEsVolm(1, at: 3)
            n[4].pitch += 1
            n[4].fillVolm(1)
            n.fillEsVolm(1, at: 4)
            n[5].pitch += 2
            n[5].edPitch += 4
            n[5].fillVolm(1)
            n[5].edVolm = 0
            return n
//        oisePitchVolms: [Point(91, 0),
//                                      Point(92, 1),2
//                                      Point(96, 1),2
//                                      Point(97, 0.56),
//                                      Point(98, 0.7),
//                                      Point(99, 1),3
//                                      Point(111, 1),4
//                                      Point(113, 0.56),5
//                                      Point(114, 0.3),
//                                      Point(116, 0)]),
        case .ɸ:
            var n = toNoise().offVolm(to: 2)
            n[0].sdVolm *= 0.56
            n[0].formMultiplyVolm(0.25)
            n.formMultiplyEsVolm(0.125, at: 0)
            n[0].fillNoise(0)
            n.fillEsNoise(0.25, at: 0)
            n[1].pitch += 3
            n[1].fillVolm(0.5)
            n.formMultiplyEsVolm(0.25, at: 1)
            n[1].fillNoise(0.5)
            n[2].dPitch += 2
            n[2].pitch += -1
            n[2].fillVolm(0.5)
            n.fillEsVolm(0.6, at: 2)
            n[3].pitch += -1
            n[3].fillVolm(0.7)
            n.fillEsVolm(1, at: 3)
            n[4].pitch += -1
            n[4].fillVolm(1)
            n.fillEsVolm(0.7, at: 4)
            n[5].pitch += 1
            n[5].edPitch += 9
            n[5].fillVolm(0.6)
            n[5].edVolm = 0
            return n
//        spectlope: .init(noisePitchVolms: [Point(81, 0),1
//                                          Point(83, 0.52),
//                                          Point(100, 0.7),3
//                                          Point(101, 1),4
//                                          Point(102, 1),4
//                                          Point(103, 0.7),
//                                          Point(109, 0.66),5
//                                          Point(111, 0.56),5
//                                          Point(120, 0.3),
//                                          Point(121, 0)]),
        case .k, .kj:
            return movedF2(sPitch: 89, ePitch: 91)
        case .kβ, .ko:
            return movedF2(sPitch: 74, ePitch: 77)
        case .g, .gj:
            return movedF2(sPitch: 89, ePitch: 91).toDakuon()
        case .gβ, .go:
            return movedF2(sPitch: 74, ePitch: 77).toDakuon()
        case .t, .ts, .tɕ:
            return movedF2(sPitch: 79, ePitch: 83)
        case .d, .dz, .dʒ:
            return movedF2(sPitch: 79, ePitch: 83).toDakuon()
        case .p, .pj:
            return movedF2(sPitch: 62, ePitch: 67).toVoiceless()
        case .b, .bj:
            return movedF2(sPitch: 62, ePitch: 67).toDakuon()
        case .off:
            var n = withSelfA(to: .ɴ)
            n[2].formMultiplyNoise(0.75)
            n[3].formMultiplyNoise(0.6)
            n[4].formMultiplyNoise(0.5)
            return n
        default: return self
        }
    }
    func onsetWithSelfA(to phoneme: Phoneme) -> Self {
        switch phoneme {
        case .a: return self
        case .s, .dz:
            var n = movedF2(sPitch: 84, ePitch: 85).toNoise().offVolm(to: 1)
            if phoneme == .dz {
                n = n.toDakuon()
            }
            n[2].sdVolm = 0
            n[2].fillVolm(0.3)
            n.formFillEsVolm(0.4, at: 2)
            n[3].fillVolm(0.45)
            n.formFillEsVolm(0.6, at: 3)
            n[4].fillVolm(0.8)
            n.formFillEsVolm(0.7, at: 4)
            n[5].fillVolm(1)
            n[5].pitch += 3
            n[5].dPitch *= 2
            n[5].edPitch += 7
            return n
        default: return self
        }
    }
}
extension FormantFilter: RandomAccessCollection {
    var startIndex: Int { formants.startIndex }
    var endIndex: Int { formants.endIndex }
    subscript(i: Int) -> Formant {
        get { i >= 0 && i < formants.count ? formants[i] : .init() }
        set {
            if i >= 0 && i < formants.count {
                formants[i] = newValue
            }
        }
    }
}
extension FormantFilter: Interpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(formants: .linear(f0.formants, f1.formants, t: t))
    }
    static func firstSpline(_ f1: Self, _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(formants: .firstSpline(f1.formants, f2.formants, f3.formants, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(formants: .spline(f0.formants, f1.formants, f2.formants, f3.formants, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self, _ f2: Self, t: Double) -> Self {
        .init(formants: .lastSpline(f0.formants, f1.formants, f2.formants, t: t))
    }
}
extension FormantFilter: MonoInterpolatable {
    static func firstMonospline(_ f1: Self, _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(formants: .firstMonospline(f1.formants, f2.formants, f3.formants, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(formants: .monospline(f0.formants, f1.formants, f2.formants, f3.formants, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self, _ f2: Self, with ms: Monospline) ->Self {
        .init(formants: .lastMonospline(f0.formants, f1.formants, f2.formants, with: ms))
    }
}
extension FormantFilter {
    func movedF2(sPitch: Double, ePitch: Double) -> Self {
        var n = self
        n[1].sPitch = sPitch
        n[1].ePitch = ePitch
        return n
    }
    func multiplyF2To(f2Volm: Double, volm: Double) -> Self {
        var n = self
        n[1].formMultiplyAllVolm(f2Volm)
        if volm != 1 {
            for i in 2 ..< n.count {
                n[i].formMultiplyAllVolm(volm)
            }
        }
        return n
    }
    
    func offVolm(to i: Int) -> Self {
        var n = self
        for i in 0 ... i {
            n[i].fillAllVolm(0)
        }
        return n
    }
    func offVolm(from i: Int) -> Self {
        var n = self
        for i in i ..< n.count {
            n[i].fillAllVolm(0)
        }
        return n
    }
    func offNoise() -> Self {
        var n = self
        for i in 0 ..< n.count {
            n[i].fillAllNoise(0)
        }
        return n
    }
    
    func toFricative(isO: Bool) -> Self {
        var n = offVolm(from: 5)
        n[0].sdVolm *= 0.56
        n[0].formMultiplyVolm(0.7)
        n.formMultiplyEsVolm(0.56, at: 0)
        n[1].fillVolm(1)
        n.formMultiplyEsVolm(0.56, at: 1)
        n[2].fillVolm(1)
        n.formMultiplyEsVolm(0.56, at: 2)
        n[3].fillVolm(isO ? 0.6 : 1)
        n.fillEsVolm(0, at: 3)
        n[4].fillVolm(isO ? 0.2 : 0.5)
        n.fillEsVolm(0, at: 4)
        n[5].fillVolm(isO ? 0.1 : 0.2)
        n.fillEsVolm(0, at: 5)
        return n
    }
    func toBreath() -> Self {
        var n = offVolm(from: 4)
        n[0].sdVolm = n[1].edVolm * 0.7
        n[0].fillVolm(n[2].volm * 0.7)
        n[2].formMultiplyVolm(0.85)
        n.formMultiplyEsVolm(0.7, at: 2)
        n[3].formMultiplyVolm(0.7)
        return n
    }
    
    func toVoiceless() -> Self {
        var n = offVolm(from: 3)
        n[2].sdVolm *= n[1].edVolm * 0.75
        n[2].sVolm *= n[1].edVolm * 0.5
        n[2].eVolm *= n[1].edVolm * 0.25
        n[2].edVolm *= n[1].edVolm * 0.1
        return n
    }
    
    func toDakuon() -> Self {
        var n = offVolm(from: 1)
        n[0].pitchRange = 55 ... 60
        n[0].sVolm *= 0.85
        n[0].eVolm *= 0.6
        n.fillEsVolm(0, at: 0)
        return n
    }
    
    func toNoise() -> Self {
        var n = self
        n.formants = n.formants.map { $0.toAllNoise() }
        return n
    }
}

struct Onset: Hashable, Codable {
    var durSec: Double
    var volm: Double
    var sec: Double
    var attackSec: Double
    var releaseSec: Double
    var spectlope: Spectlope
    var phoneme: Phoneme
}

struct KeyFormantFilter: Hashable, Codable {
    var formantFilter: FormantFilter
    var sec = 0.0
    var volm = 1.0
    var pitch = Rational()
    var id = UUID()
    
    init(_ formantFilter: FormantFilter, sec: Double = 0, volm: Double = 1,
         pitch: Rational = .init(), id: UUID = .init()) {
        self.formantFilter = formantFilter
        self.sec = sec
        self.volm = volm
        self.pitch = pitch
        self.id = id
    }
}

struct Mora: Hashable, Codable {
    var keyFormantFilters: [KeyFormantFilter]
    var onsets: [Onset]
    
    init?(hiragana: String,
          previousPhoneme: Phoneme?, previousFormantFilter: FormantFilter?, previousID: UUID?) {
        var hiragana = hiragana
        let isVowelReduction: Bool
        if hiragana.last == "/" {
            hiragana.removeLast()
            isVowelReduction = true
        } else {
            isVowelReduction = false
        }
        var phonemes = Phoneme.phonemes(fromHiragana: hiragana)
        guard !phonemes.isEmpty else { return nil }
        
        let baseFf: FormantFilter = if let previousPhoneme, let previousFormantFilter {
            previousFormantFilter.toA(from: previousPhoneme)
        } else {
            .init()
        }
        
        let vowel: Phoneme
        switch phonemes.last {
        case .a, .i, .ɯ, .e, .o, .ɴ, .off:
            vowel = phonemes.last!
            phonemes.removeLast()
        case .sokuon:
            let ff = baseFf.withSelfA(to: .ɯ)
            keyFormantFilters = if let preFf = previousFormantFilter {
                [.init(preFf, sec: 0), .init(ff, sec: 0.06, volm: 0.25)]
            } else {
                [.init(ff, sec: 0, volm: 0.25)]
            }
            onsets = []
            return
        case .breath:
            let aFf = baseFf.withSelfA(to: .a)
            let ff = aFf.toFricative(isO: false).toNoise().toBreath()
            keyFormantFilters = if let preFf = previousFormantFilter {
                [.init(preFf, sec: 0), .init(ff, sec: 0.06, volm: 0.25)]
            } else {
                [.init(ff, sec: 0, volm: 0.25)]
            }
            onsets = []
            return
        default:
            return nil
        }
        var syllabics = [vowel]
        let vowelFf = baseFf.withSelfA(to: vowel)
        
        let youonKffs: [KeyFormantFilter]
        switch phonemes.last {
        case .j, .ja:
            let phoneme = phonemes.last!
            phonemes.removeLast()
            
            let ff = baseFf.withSelfA(to: phoneme)
            youonKffs = [.init(ff, sec: 0.09)]
            
            syllabics.insert(phoneme, at: 0)
        case .β:
            phonemes.removeLast()
            
            let ff = baseFf.withSelfA(to: .β)
            youonKffs = [.init(ff, sec: 0.07, volm: 0.75)]
            
            syllabics.insert(.β, at: 0)
        default:
            youonKffs = []
        }
        let onsetStartSec = -(youonKffs.last?.sec ?? 0) - 0.02
        var paddingSec = 0.05
        
        var kffs = [KeyFormantFilter](), onsets = [Onset]()
        
        let nextFf = youonKffs.first?.formantFilter ?? vowelFf
        let onsetDurSec: Double
        if phonemes.count != 1 {
            onsetDurSec = 0
        } else {
            let onsetScale = previousPhoneme == .sokuon ? 1.5 : (isVowelReduction ? 1.15 : 1)
            let volm: Double, pitch: Rational
            var centerPitch: Rational?
            let oph = phonemes[0]
            switch oph {
            case .n, .nj:
                onsetDurSec = 0.06
                volm = 0.75
                pitch = 0
                paddingSec = 0.03
            case .m, .mj:
                onsetDurSec = 0.04
                volm = 0.75
                pitch = 0
                paddingSec = 0.03
            case .r, .rj:
                onsetDurSec = 0.03
                volm = 0.75
                pitch = 0
                paddingSec = 0.03
                
            case .k, .kj, .kβ, .ko, .g, .gj, .gβ, .go:
                let sl: Spectlope, onsetVolm: Double
                if oph == .kj || oph == .gj {
                    sl = Spectlope(noisePitchVolms: [Point(80, 0),
                                                     Point(89, 0.6),
                                                     Point(90, 1),
                                                     Point(92, 1),
                                                     Point(93, 0.5),
                                                     Point(98, 0.4),
                                                     Point(99, 0)])
                    onsetVolm = 0.25
                } else {
                    sl = switch vowel {
                    case .o: Spectlope(noisePitchVolms: [Point(55, 0),
                                                         Point(67, 0.61),
                                                         Point(71, 1),
                                                         Point(79, 1),
                                                         Point(81, 0.56),
                                                         Point(100, 0.4),
                                                         Point(102, 0)])
                    default: Spectlope(noisePitchVolms: [Point(55, 0),
                                                         Point(77, 0.61),
                                                         Point(80, 1),
                                                         Point(87, 1),
                                                         Point(88, 0.56),
                                                         Point(98, 0.4),
                                                         Point(99, 0)])
                    }
                    onsetVolm = 0.1
                }
                
                let oDurSec = 0.035
                onsets.append(.init(durSec: oDurSec,
                                    volm: onsetVolm,
                                    sec: -oDurSec + onsetStartSec,
                                    attackSec: 0.01, releaseSec: 0.01,
                                    spectlope: sl,
                                    phoneme: oph))
                
                onsetDurSec = (oph == .k || oph == .kj ? 0.065 : 0.05) - 0.02 * 2
                volm = oph == .k || oph == .kj ? 0 : 0.75
                pitch = -3
                
            case .t, .d:
                let oDurSec = 0.035
                onsets.append(.init(durSec: oDurSec,
                                    volm: 0.5,
                                    sec: -oDurSec + onsetStartSec,
                                    attackSec: 0.01, releaseSec: 0.01,
                                    spectlope: .init(noisePitchVolms: [Point(96, 0),
                                                                      Point(97, 1),
                                                                      Point(99, 1),
                                                                      Point(100, 0.7),
                                                                      Point(101, 0.55),
                                                                      Point(102, 0)]),
                                    phoneme: oph))
                onsetDurSec = (oph == .t ? 0.085 : 0.065) - 0.02 * 2
                volm = oph == .t ? 0 : 0.75
                pitch = -3
            case .p, .pj, .b, .bj:
                onsetDurSec = (oph == .p || oph == .pj ? 0.07 : 0.05) - 0.02 * 2
                volm = oph == .p || oph == .pj ? 0 : 0.75
                pitch = -3
            case .s, .ts, .dz:
                let oDurSec, onsetVolm: Double
                switch oph {
                case .s:
                    oDurSec = 0.1 * onsetScale
                    onsetDurSec = oDurSec - 0.02 * 2
                    onsetVolm = 0.7
                    volm = 0.75
                    pitch = -3
                case .ts:
                    oDurSec = 0.05 * onsetScale
                    onsetDurSec = oDurSec + 0.04 - 0.02 * 2
                    onsetVolm = 0.675
                    volm = 0.75
                    pitch = -3
                case .dz:
                    oDurSec = 0.06 * onsetScale
                    onsetDurSec = oDurSec + 0.03 - 0.02 * 2
                    onsetVolm = 0.65
                    volm = 0.75
                    pitch = -3
                default: fatalError()
                }
//                onsets.append(.init(durSec: oDurSec,
//                                    volm: onsetVolm,
//                                    sec: -oDurSec + onsetStartSec,
//                                    attackSec: 0.02, releaseSec: 0.02,
//                                    spectlope: baseFf.withSelfA(to: oph).spectlope,
//                                    phoneme: oph))
            case .ɕ, .tɕ, .dʒ:
                let oDurSec, onsetVolm: Double
                switch oph {
                case .ɕ:
                    oDurSec = 0.085 * onsetScale
                    onsetDurSec = oDurSec - 0.02 * 2
                    onsetVolm = 0.75
                    volm = 0.75
                    pitch = -3
                case .tɕ:
                    oDurSec = 0.04 * onsetScale
                    onsetDurSec = oDurSec + 0.04 - 0.02 * 2
                    onsetVolm = 0.65
                    volm = 0.75
                    pitch = -3
                case .dʒ:
                    oDurSec = 0.055 * onsetScale
                    onsetDurSec = oDurSec + 0.03 - 0.02 * 2
                    onsetVolm = 0.62
                    volm = 0.75
                    pitch = -3
                default: fatalError()
                }
//                onsets.append(.init(durSec: oDurSec,
//                                    volm: onsetVolm,
//                                    sec: -oDurSec + onsetStartSec,
//                                    attackSec: 0.02, releaseSec: 0.02,
//                                    spectlope: baseFf.withSelfA(to: oph).spectlope,
//                                    phoneme: oph))
            case .ha, .he, .ho:
                onsetDurSec = 0.06 * onsetScale - 0.02 * 2
                centerPitch = 1
                volm = 0.125
                pitch = -3
            case .ç:
                onsetDurSec = 0.08 * onsetScale - 0.02 * 2
                centerPitch = 1
                volm = 0.125
                pitch = -3
            case .ɸ:
                onsetDurSec = 0.06 * onsetScale - 0.02 * 2
                centerPitch = 1
                volm = 0.125
                pitch = -3
            default:
                onsetDurSec = 0
                volm = 0
                pitch = 0
            }
            
            let nFf = baseFf.withSelfA(to: oph)
            if let centerPitch {
                kffs.append(.init(nFf, sec: onsetDurSec / 2, volm: volm, pitch: pitch))
                kffs.append(.init(nFf, sec: onsetDurSec / 2, volm: volm, pitch: centerPitch))
            } else {
                switch oph {
                case .s, .ts, .dz:
                    let onsetFf = baseFf.onsetWithSelfA(to: oph)
                    kffs.append(.init(nFf, sec: paddingSec * 0.5, volm: volm, pitch: pitch))
                    kffs.append(.init(onsetFf, sec: onsetDurSec, volm: volm, pitch: pitch))
                    kffs.append(.init(onsetFf, sec: paddingSec * 0.5, volm: volm, pitch: pitch))
                default:
                    kffs.append(.init(nFf, sec: onsetDurSec, volm: volm, pitch: pitch))
                }
                
            }
            kffs.append(.init(nFf, sec: paddingSec, volm: volm, pitch: pitch))
        }
        
        if let ff = previousFormantFilter, let id = previousID {
            kffs.insert(.init(ff, sec: paddingSec, id: id), at: 0)
        }
        kffs += youonKffs
        if !isVowelReduction {
            kffs.append(.init(vowelFf, sec: 0, volm: vowel == .off ? 0 : 1))
        } else if let lastKff = kffs.last {
            kffs.append(.init(lastKff.formantFilter, sec: 0, volm: lastKff.volm))
        }
        
        let durSec = kffs.sum { $0.sec }
        var sec = -durSec
        kffs = kffs.map {
            var kff = $0
            kff.sec = sec
            sec += $0.sec
            return kff
        }
        self.keyFormantFilters = kffs
        self.onsets = onsets
    }
}

enum Phoneme: String, Hashable, Codable, CaseIterable {
    case a, i, ɯ, e, o, j, ja, β, ɴ,
         k, kj, kβ, ko, s, ɕ, t, tɕ, ts, n, nj, ha, he, ho, ç, ɸ, p, pj, m, mj, r, rj,
         g, gj, gβ, go, dz, dʒ, d, b, bj,
         sokuon = "_", breath = "^", off = ".", voiceless = ","
}
extension Phoneme {
    var isJapaneseVowel: Bool {
        switch self {
        case .a, .i, .ɯ, .e, .o, .ɴ, .off: true
        default: false
        }
    }
    var isJapaneseConsonant: Bool {
        !isJapaneseVowel
    }
    
    var isDakuon: Bool {
        switch self {
        case .g, .gj, .gβ, .go, .dz, .dʒ, .d, .b, .bj: true
        default: false
        }
    }
    var isHaretsu: Bool {
        switch self {
        case .k, .kj, .kβ, .ko, .s, .ɕ, .t, .tɕ, .ts, .ha, .he, .ç, .ɸ, .p, .pj: true
        default: false
        }
    }
    var isBiohuru: Bool {
        switch self {
        case .n, .nj, .m, .mj, .r: true
        default: false
        }
    }
    var isYouon: Bool {
        switch self{
        case .j, .ja, .β: true
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
        case "く", "ku": [.kβ, .ɯ]
        case "け", "ke": [.k, .e]
        case "こ", "ko": [.ko, .o]
        case "きゃ", "kya": [.kj, .ja, .a]
        case "きゅ", "kyu": [.kj, .j, .ɯ]
        case "きぇ", "kye": [.kj, .j, .e]
        case "きょ", "kyo": [.kj, .j, .o]
        case "くぁ", "くゎ", "kwa": [.kβ, .β, .a]
        case "くぃ", "kwi": [.kβ, .β, .i]
        case "くぇ", "kwe": [.kβ, .β, .e]
        case "くぉ", "kwo": [.kβ, .β, .o]
        case "が", "ga": [.g, .a]
        case "ぎ", "gi": [.gj, .i]
        case "ぐ", "gu": [.gβ, .ɯ]
        case "げ", "ge": [.g, .e]
        case "ご", "go": [.go, .o]
        case "ぎゃ", "gya": [.gj, .ja, .a]
        case "ぎゅ", "gyu": [.gj, .j, .ɯ]
        case "ぎぇ", "gye": [.gj, .j, .e]
        case "ぎょ", "gyo": [.gj, .j, .o]
        case "ぐぁ", "ぐゎ", "gwa": [.gβ, .β, .a]
        case "ぐぃ", "gwi": [.gβ, .β, .ɯ]
        case "ぐぇ", "gwe": [.gβ, .β, .e]
        case "ぐぉ", "gwo": [.gβ, .β, .o]
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
        case "は", "ha": [.ha, .a]
        case "ひ", "hi": [.ç, .i]
        case "ふ", "hu", "fu": [.ɸ, .ɯ]
        case "へ", "he": [.he, .e]
        case "ほ", "ho": [.ho, .o]
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
        case "ん", "n", "nn": [.ɴ]
        case "っ", "xtu", "_": [.sokuon]
        case "^": [.breath]
        case ".": [.off]
        case ",": [.voiceless]
        default: []
        }
    }
    static func isJapaneseVowel(_ phonemes: [Phoneme]) -> Bool {
        phonemes.count == 1 && phonemes[0].isJapaneseVowel
    }
}
