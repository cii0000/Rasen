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

import RealModule
import struct Foundation.UUID

extension Note {
    func lyricRange(at i: Int) -> ClosedRange<Int>? {
        guard !pits[i].lyric.isEmpty
                && pits[i].lyric != "[" && pits[i].lyric != "]" else { return nil }
        var minI = i
        var maxI = i
        for j in i.range.reversed() {
            if (!pits[j].lyric.isEmpty && pits[j].lyric != "[") || pits[j].lyric == "]" { break }
            if pits[j].lyric == "[" {
                minI = j
                break
            }
        }
        for j in i + 1 ..< pits.count {
            if (!pits[j].lyric.isEmpty && pits[j].lyric != "]") || pits[j].lyric == "[" { break }
            if pits[j].lyric == "]" {
                maxI = j
                break
            }
        }
        return minI <= maxI ? minI ... maxI : nil
    }
    @discardableResult
    mutating func replace(lyric: String, at oi: Int, tempo: Rational,
                          beatInterval: Rational = Sheet.fullEditBeatInterval,
                          pitchInterval: Rational = Sheet.fullEditPitchInterval,
                          isUpdateNext: Bool = true) -> Int {
        func update(lyric: String, at oi: Int, isOld: Bool = true) -> (lyricI: Int, isNext: Bool) {
            let oldNote = self
            let oldLyric = pits[oi].lyric
            self.pits[oi].lyric = lyric
            
            var isFirst = false
            let i: Int
            if !oldLyric.isEmpty {
                if oi > 0 {
                    let maxI = oi
                    var minI = oi
                    for j in maxI.range.reversed() {
                        if (!pits[j].lyric.isEmpty && pits[j].lyric != "[") || pits[j].lyric == "]" { break }
                        if pits[j].lyric == "[" {
                            isFirst = j == 0
                            if !isFirst && pits[j].pitch != pits[oi].pitch {
                                minI = j + 1
                                pits[j].beat = pits[oi].beat
                            } else {
                                minI = j
                            }
                            
                            if !isFirst {
                                pits[oi].tone = pits[j].tone
                                pits[j].lyric = ""
                            }
                            break
                        }
                    }
                    if minI < maxI {
                        pits.remove(at: Array(minI ..< maxI))
                        i = oi - (maxI - minI)
                    } else {
                        i = oi
                    }
                } else {
                    i = oi
                }
                
                let minI = i + 1
                var maxI = i
                for j in minI ..< pits.count {
                    if (!pits[j].lyric.isEmpty && pits[j].lyric != "]") || pits[j].lyric == "[" { break }
                    if pits[j].lyric == "]" {
                        maxI = j
                        break
                    }
                }
                if minI <= maxI {
                    pits.remove(at: Array(minI ... maxI))
                }
            } else {
                i = oi
            }
            
            if isFirst {
                if pits[i].beat > 0 {
                    let dBeat = pits[i].beat
                    pits = pits.map {
                        var n = $0
                        n.beat -= dBeat
                        return n
                    }
                    beatRange.start += dBeat
                    beatRange.length -= dBeat
                }
            }
            
            let nextPhonemes: [Phoneme] = {
                if lyric == "n" || lyric == "ん" {
                    for j in (i + 1) ..< pits.count {
                        if pits[j].isLyric {
                            return Phoneme.phonemes(fromHiragana: pits[j].lyric,
                                                    nextPhoneme: nil)
                        }
                    }
                }
                return []
            } ()
            let currentPhonemes = Phoneme.phonemes(fromHiragana: pits[i].lyric,
                                                   nextPhoneme: nextPhonemes.first)
            
            let isNext = Phoneme.firstVowel(nextPhonemes) != Phoneme.firstVowel(currentPhonemes)
            if lyric.isEmpty { return (i, isNext) }
            
            let previousPhoneme: Phoneme?, previousFormantFilter: FormantFilter?, previousID: UUID?
            if let preI = i.range.reversed().first(where: { !pits[$0].lyric.isEmpty }) {
                previousPhoneme = Phoneme.phonemes(fromHiragana: pits[preI].lyric,
                                                   nextPhoneme: currentPhonemes.first).last
                previousFormantFilter = .init(spectlope: pits[preI].tone.spectlope)
                previousID = pits[preI].tone.id
            } else if i > 0 {
                previousPhoneme = .a
                previousFormantFilter = FormantFilter().withSelfA(to: .a)
                previousID = .init()
            } else {
                previousPhoneme = nil
                previousFormantFilter = nil
                previousID = nil
            }
            
            var ni = i
            if var mora = Mora(hiragana: lyric,
                               previousPhoneme: previousPhoneme,
                               previousFormantFilter: previousFormantFilter, previousID: previousID,
                               nextPhoneme: nextPhonemes.first) {
                let beat = pits[i].beat
                let fBeat = Score.beat(fromSec: mora.keyFormantFilters.first?.sec ?? 0,
                                       tempo: tempo, interval: beatInterval) + beat
                let lBeat = Score.beat(fromSec: mora.keyFormantFilters.last?.sec ?? 0,
                                       tempo: tempo, interval: beatInterval) + beat
                var minI = i, maxI = i, minSec: Double?, maxSec: Double?
                for j in i.range.reversed() {
                    let isMin = (!pits[j].lyric.isEmpty && pits[j].lyric != "[")
                    || pits[j].lyric == "]"
                    if isMin {
                        minSec = -.init(Score.sec(fromBeat: pits[i].beat - pits[j].beat,
                                                  tempo: tempo)) * 0.95
                    }
                    if isMin || pits[j].beat < fBeat {
                        minI = j + 1
                        break
                    }
                }
                for j in i + 1 ..< pits.count {
                    let isMax = (!pits[j].lyric.isEmpty && pits[j].lyric != "]")
                    || pits[j].lyric == "["
                    if isMax {
                        maxSec = .init(Score.sec(fromBeat: pits[j].beat - pits[i].beat,
                                                 tempo: tempo)) * 0.95
                    }
                    if isMax || pits[j].beat > lBeat {
                        maxI = j - 1
                        break
                    }
                }
                mora.set(minSec: minSec, maxSec: maxSec)
                
                let oldPit = pits[i]
                var ivps = [IndexValue<Pit>](), isRemoved = false
                for (fi, ff) in mora.keyFormantFilters.enumerated() {
                    let fBeat = Score.beat(fromSec: ff.sec, tempo: tempo, interval: beatInterval) + beat
                    let result = (isOld ? oldNote : self).pitResult(atBeat: Double(fBeat))
                    
                    let isLyric = mora.keyFormantFilters.count == 1 || ff.sec == 0
                    let lyric = if isLyric {
                        lyric
                    } else if fi == 0 {
                        "["
                    } else if fi == mora.keyFormantFilters.count - 1 {
                        "]"
                    } else {
                        ""
                    }
                    if fi == mora.keyFormantFilters.count - 1 {
                        ni = fi + minI
                    }
                    
                    ivps.append(.init(value: .init(beat: fBeat,
                                                   pitch: result.pitch.rationalValue(intervalScale: pitchInterval) + ff.pitch,
                                                   stereo: .init(volm: oldPit.stereo.volm,
                                                                 pan: result.stereo.pan,
                                                                 id: result.stereo.id),
                                                   tone: .init(spectlope: ff.formantFilter.spectlope, id: ff.id),
                                                   lyric: lyric),
                                      index: fi + minI))
                    if !isRemoved && !isLyric && fi == 0 {
                        pits.remove(at: Array(minI ..< i))
                        isRemoved = true
                    }
                }
                if !isRemoved {
                    pits.remove(at: Array(minI ... maxI))
                } else if i <= maxI {
                    pits.remove(at: Array(i - (i - minI) ... maxI - (i - minI)))
                }
                pits.insert(ivps)
                
                let fdBeat = ivps.first?.value.beat ?? 0
                if fdBeat < 0 {
                    self.beatRange = beatRange.start + fdBeat ..< beatRange.end
                
                    for i in pits.count.range {
                        pits[i].beat -= fdBeat
                    }
                }
                
                let ldBeat = ivps.last?.value.beat ?? 0
                if ldBeat > beatRange.length {
                    self.beatRange = beatRange.start ..< beatRange.start + ldBeat
                }
            }
            return (ni, isNext)
        }
        
        //previous is n
        
        var (ni, isNext) = update(lyric: lyric, at: oi)
        
        if isUpdateNext && isNext {
            for j in (ni + 1) ..< pits.count {
                if pits[j].isLyric {
                    ni = update(lyric: pits[j].lyric, at: j, isOld: false).lyricI
                    break
                }
            }
        }
        return ni
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
    init(sdVolm: Double, sdNoise: Double,
         sdPitch: Double, sFq: Double, eFq: Double, edPitch: Double,
         volm: Double, noise: Double, edVolm: Double, edNoise: Double) {
        
        self.init(sdVolm: sdVolm, sdNoise: sdNoise,
                  sdPitch: sdPitch, sPitch: Pitch.pitch(fromFq: sFq),
                  ePitch: Pitch.pitch(fromFq: eFq), edPitch: edPitch,
                  volm: volm, noise: noise, edVolm: edVolm, edNoise: edNoise)
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
    var formants: [Formant] = [.init(sdVolm: 0.7, sdNoise: 0,
                                     sdPitch: 9.1, sPitch: 67.3, ePitch: 74.0, edPitch: 6.3,
                                     volm: 0.9, noise: 0.13,
                                     edVolm: 0.5, edNoise: 0.18),
                               .init(sdVolm: 0.5, sdNoise: 0.13,
                                     sdPitch: 5.7, sPitch: 79.5, ePitch: 81.2, edPitch: 5.2,
                                     volm: 0.9, noise: 0.3,
                                     edVolm: 0.33, edNoise: 0.26),
                               .init(sdVolm: 0.3, sdNoise: 0.23,
                                     sdPitch: 1.6, sPitch: 94, ePitch: 96, edPitch: 1.1,
                                     volm: 1, noise: 0.35,
                                     edVolm: 0.33, edNoise: 0.69),
                               .init(sdVolm: 0.4, sdNoise: 0.69,
                                     sdPitch: 0.5, sPitch: 98.5, ePitch: 100.2, edPitch: 1.2,
                                     volm: 0.75, noise: 0.39,
                                     edVolm: 0, edNoise: 1),
                               .init(sdVolm: 0, sdNoise: 1,
                                     sdPitch: 0.8, sPitch: 107.4, ePitch: 109.1, edPitch: 0.9,
                                     volm: 0.3, noise: 0.61,
                                     edVolm: 0.1, edNoise: 1),
                               .init(sdVolm: 0.1, sdNoise: 1,
                                     sdPitch: 0.6, sPitch: 113.2, ePitch: 114.8, edPitch: 0.8,
                                     volm: 0.2, noise: 0.93,
                                     edVolm: 0, edNoise: 1)]
}
extension FormantFilter {
    init(spectlope: Spectlope) {
        self.formants = spectlope.formants
    }
    var spectlope: Spectlope {
        .init(sprols: formants.flatMap { [$0.sprol0, $0.sprol1, $0.sprol2, $0.sprol3] })
    }
    
    var defaultFormantsString: String {
        var n = formants.reduce(into: "[") { $0 += """
.init(sdVolm: \($1.sdVolm.string(digitsCount: 1)), sdNoise: \($1.sdNoise.string(digitsCount: 2)),
sdPitch: \($1.sdPitch.string(digitsCount: 1)), sPitch: \($1.sPitch.string(digitsCount: 1)), ePitch: \($1.ePitch.string(digitsCount: 1)), edPitch: \($1.edPitch.string(digitsCount: 1)),
volm: \($1.volm.string(digitsCount: 2)), noise: \($1.noise.string(digitsCount: 2)),
edVolm: \($1.edVolm.string(digitsCount: 2)), edNoise: \($1.edNoise.string(digitsCount: 2))),
""" + "\n" }
        if n.count >= 2 {
            n.removeLast(2)
        }
        return n + "]"
    }
    var defaultFqFormantsString: String {
        var n = formants.reduce(into: "[") { $0 += """
.init(sdVolm: \($1.sdVolm.string(digitsCount: 1)), sdNoise: \($1.sdNoise.string(digitsCount: 2)),
sdPitch: \($1.sdPitch.string(digitsCount: 1)), sFq: \(Pitch.fq(fromPitch: $1.sPitch).string(digitsCount: 1)), eFq: \(Pitch.fq(fromPitch: $1.ePitch).string(digitsCount: 1)), edPitch: \($1.edPitch.string(digitsCount: 1)),
volm: \($1.volm.string(digitsCount: 2)), noise: \($1.noise.string(digitsCount: 2)),
edVolm: \($1.edVolm.string(digitsCount: 2)), edNoise: \($1.edNoise.string(digitsCount: 2))),
""" + "\n" }
        if n.count >= 2 {
            n.removeLast(2)
        }
        return n + "]"
    }
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
    mutating func formMultiplyAllVolm(_ x: Double) {
        self = multiplyAllVolm(x)
    }
    func multiplyAllVolm(_ x: Double) -> Self {
        .init(formants: formants.map { $0.multiplyAllVolm(x) })
    }
}
extension FormantFilter {
    var f0Pitch: Double {
        get { self[0].pitch - 25 }
        set {
            let dPitch = newValue + 25 - self[0].pitch
            self = .init(formants: self.map {
                var n = $0
                n.pitch += dPitch
                return n
            })
        }
    }
    
    func toA(from fromPhoneme: Phoneme) -> Self {
        var n = withSelfA(to: fromPhoneme)
        func substructPitch(from v0: Sprol, to v1: Sprol) -> Double {
            (v0.pitch * 2 - v1.pitch).clipped(Score.doublePitchRange)
        }
        func substructPitch(from v0: Double, to v1: Double) -> Double {
            (v0 * 2 - v1).clipped(Score.doublePitchRange)
        }
        func dividePitch(from v0: Double, to v1: Double) -> Double {
           v1 == 0 ? 0 : (v0.squared / v1)
        }
        func substructVolm(from v0: Sprol, to v1: Sprol) -> Double {
            v1.volm == 0 ? 0 : (v0.volm.squared / v1.volm).clipped(min: 0, max: 1)
        }
        func substructNoise(from v0: Sprol, to v1: Sprol) -> Double {
            v1.noise == 0 ? 0 : (v0.noise.squared / v1.noise).clipped(min: 0, max: 1)
        }
        for i in Swift.min(n.count, self.count).range {
            let pitch = substructPitch(from: self[i].pitch, to: n[i].pitch)
            let dPitch = dividePitch(from: self[i].dPitch, to: n[i].dPitch)
            let sdPitch = dividePitch(from: self[i].sdPitch, to: n[i].sdPitch)
            let edPitch = dividePitch(from: self[i].edPitch, to: n[i].edPitch)
            n[i].sprol0.pitch = (pitch - dPitch - sdPitch).clipped(Score.doublePitchRange)
            n[i].sprol1.pitch = (pitch - dPitch).clipped(Score.doublePitchRange)
            n[i].sprol2.pitch = (pitch + dPitch).clipped(Score.doublePitchRange)
            n[i].sprol3.pitch = (pitch + dPitch + edPitch).clipped(Score.doublePitchRange)
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
    func withSelfA(to phoneme: Phoneme) -> Self {
        switch phoneme {
        case .a: return self
        case .i:
            var n = self
            n[0].sdPitch *= 1.35
            n[0].pitch -= 12
            n[0].edPitch *= 1.5
            n.formMultiplyEsVolm(0.35, at: 0)
            n[1].pitch += 13
            n[1].dPitch *= 0.5
            n[1].sdPitch *= 0.8
            n[1].edPitch *= 0.8
            n[1].formMultiplyVolm(0.75)
            n[2].sdPitch *= 0.5
            n[2].pitch += -1
            n[3].pitch += -0.5
            return n
        case .j:
            var n = withSelfA(to: .i)
            n[1].pitch += -2.75
            n[1].formMultiplyVolm(0.5)
            n[2].pitch += -1
            return n
        case .ja:
            var n = withSelfA(to: .j)
            n[3].pitch += -0.375
            return n
        case .ɯ:
            var n = self
            n[0].pitch += -12
            n[0].edPitch *= 1.5
            n.formMultiplyEsVolm(0.65, at: 0)
            n[1].pitch -= 2
            n[1].sdPitch *= 0.8
            n[1].edPitch *= 0.8
            n[1].dPitch *= 0.5
            n[1].formMultiplyVolm(0.75)
            n.formMultiplyEsVolm(0.65, at: 1)
            return n
        case .β:
            var n = withSelfA(to: .ɯ)
            n[0].pitch += -3.5
            n[1].pitch += -6.75
            n[1].formMultiplyVolm(0.75)
            n[2].formMultiplyVolm(0.35)
            n.formMultiplyEsVolm(0.0625, at: 2)
            n[3].formMultiplyVolm(0.1)
            n.formMultiplyEsVolm(0, at: 3)
            n[4].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 4)
            n[5].formMultiplyVolm(0)
            n.formMultiplyEsVolm(0, at: 5)
            return n
        case .e:
            var n = self
            n[0].pitch += -6
            n[0].sdPitch *= 1.5
            n[0].edPitch *= 1.75
            n[1].formMultiplyVolm(0.8)
            n.formMultiplyEsVolm(0.5, at: 0)
            n[1].pitch += 10.5
            n[1].sdPitch *= 0.8
            n[1].edPitch *= 0.8
            n[1].dPitch *= 0.5
            n[2].pitch += 1
            n[3].pitch += 0.5
            return n
        case .o:
            var n = self
            n[0].pitch += -4
            n[1].pitch += -5
            n[1].dPitch *= 0.5
            n[1].formMultiplyVolm(0.75)
            n.formMultiplyEsVolm(0.67, at: 1)
            n[2].pitch += 1
            n[3].pitch += 0.5
            return n
        case .ã, .ĩ, .ɯ̃, .ẽ, .õ:
            let nPhoneme: Phoneme = switch phoneme {
            case .ã: .a
            case .ĩ: .i
            case .ɯ̃: .ɯ
            case .ẽ: .e
            case .õ: .o
            default: fatalError()
            }
            var n = withSelfA(to: nPhoneme)
            n[0].formMultiplyVolm(0.85)
            n.formMultiplyEsVolm(0.37, at: 0)
            n[1].formMultiplyVolm(0.43)
            n.formMultiplyEsVolm(0.34, at: 1)
            n[2].formMultiplyVolm(0.4)
            n.formMultiplyEsVolm(0.06, at: 2)
            n[3].formMultiplyVolm(0.3)
            n.formMultiplyEsVolm(0.05, at: 3)
            n[4].formMultiplyVolm(0.25)
            n.formMultiplyEsVolm(0.05, at: 4)
            n[2].formMultiplyNoise(1.25)
            n[3].formMultiplyNoise(1.5)
            n[4].formMultiplyNoise(1.75)
            n[5].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 5)
            return n
        case .ɴ:
            var n = self
            n[0].sdPitch *= 1.5
            n[0].pitch += -19
            n[0].formMultiplyVolm(0.85)
            n[0].edPitch *= 1.7
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
            n[5].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 5)
            return n
        case .ŋ:
            var n = self
            n[0].sdPitch *= 1.5
            n[0].pitch += -20
            n[0].formMultiplyVolm(0.85)
            n[0].edPitch *= 1.7
            n.formMultiplyEsVolm(0.37, at: 0)
            n[1].pitch += 0.875
            n[1].formMultiplyVolm(0.43)
            n.formMultiplyEsVolm(0.34, at: 1)
            n[2].pitch += -0.375
            n[2].formMultiplyVolm(0.4)
            n.formMultiplyEsVolm(0.06, at: 2)
            n[3].pitch += -0.17
            n[3].formMultiplyVolm(0.125)
            n.formMultiplyEsVolm(0.05, at: 3)
            n[4].formMultiplyVolm(0.125)
            n.formMultiplyEsVolm(0.05, at: 4)
            n[2].formMultiplyNoise(1.25)
            n[3].formMultiplyNoise(1.5)
            n[4].formMultiplyNoise(1.75)
            n[5].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 5)
            return n
        case .n:
            var n = self
            n[0].sdPitch *= 1.5
            n[0].pitch += -13
            n[0].edPitch *= 1.7
            n[0].eVolm *= 0.75
            n.formMultiplyEsVolm(0.125, at: 0)
            n[1].pitch += 7
            n[1].dPitch *= 1.25
            n[1].formMultiplyVolm(0.175)
            n.formMultiplyEsVolm(0.1, at: 1)
            n[2].pitch += 1
            n[2].dPitch *= 0.5
            n[2].formMultiplyVolm(0.15)
            n.formMultiplyEsVolm(0, at: 2)
            n[3].pitch += -0.15
            n[3].formMultiplyVolm(0.1)
            n.formMultiplyEsVolm(0, at: 3)
            n[4].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 4)
            n[2].formMultiplyNoise(1.25)
            n[3].formMultiplyNoise(1.5)
            n[4].formMultiplyNoise(1.75)
            n[5].formMultiplyVolm(0.0625)
            return n
        case .nj:
            var n = withSelfA(to: .n)
            n[1].pitch += 1.5
            return n
        case .m, .mj:
            var n = withSelfA(to: .n)
            n[0].pitch += -3
            n[1].pitch += -9
            n[2].pitch += -4
            n[3].pitch += -1
            return n
        case .ɾ:
            var n = self
            n[0].sdPitch *= 1.5
            n[0].pitch += -16
            n[0].edPitch *= 1.7
            n[0].formMultiplyVolm(0.75)
            n.formMultiplyEsVolm(0.125, at: 0)
            n[1].pitch += 11
            n[1].dPitch *= 1.25
            n[1].formMultiplyVolm(0.2)
            n.formMultiplyEsVolm(0.0625, at: 1)
            n[2].pitch += -1
            n[2].formMultiplyVolm(0.125)
            n.formMultiplyEsVolm(0, at: 2)
            n[3].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 3)
            n[4].formMultiplyVolm(0.0625)
            n.formMultiplyEsVolm(0, at: 4)
            n[5].formMultiplyVolm(0)
            n.formMultiplyEsVolm(0, at: 5)
            return n
        case .ɾj:
            var n = withSelfA(to: .ɾ)
            n[1].pitch += 1.5
            return n
        case .p, .pj, .b, .bj:
            var n = self
            n[0].pitch -= 20
            n[1].pitch -= 16
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .ha:
            var n = withSelfA(to: .a).toFricative(isO: false)
            n[0].pitch -= 20
            return n
        case .ç:
            var n = withSelfA(to: .i).toFricative(isO: false)
            n[1].sdPitch *= 1.33
            n[1].pitch += 2
            n[2].pitch += 1
            n[3].pitch += 1
            return n
        case .ɸ:
            var n = withSelfA(to: .ɯ).toFricative(isO: false)
            n[0].pitch -= 20
            return n
        case .he:
            var n = withSelfA(to: .e).toFricative(isO: false)
            n[0].pitch -= 20
            return n
        case .ho:
            var n = withSelfA(to: .o).toFricative(isO: true)
            n[0].pitch -= 20
            return n
        case .ka, .ga:
            var n = withSelfA(to: .a)
            n[0].pitch -= 20
            n[1].dPitch *= 0.75
            n[1].pitch += 10
            n[2].pitch -= 2
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .kj, .gj:
            var n = withSelfA(to: .i)
            n[0].pitch -= 8
            n[1].dPitch *= 1.5
            n[1].pitch += 2
            n[2].pitch -= 1
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .kβ, .gβ:
            var n = withSelfA(to: .ɯ)
            n[0].pitch -= 8
            n[1].dPitch *= 1.5
            n[1].pitch += 4
            n[2].pitch -= 2
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .ke, .ge:
            var n = withSelfA(to: .e)
            n[0].pitch -= 14
            n[1].dPitch *= 1.5
            n[1].pitch += 3.5
            n[2].pitch -= 3
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .ko, .go:
            var n = withSelfA(to: .o)
            n[0].pitch -= 16
            n[1].dPitch *= 1.5
            n[1].pitch += 5
            n[2].pitch -= 3
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .sa, .dza, .ta, .da:
            var n = self
            n[0].pitch -= 20
            n[2].pitch += 1
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .sβ, .dzβ, .so, .dzo, .tβ, .dβ, .ts, .to, .do:
            var n = self
            n[0].pitch -= 20
            n[1].pitch += 4
            n[2].pitch += 1
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .se, .dze, .te, .de:
            var n = withSelfA(to: .e)
            n[0].pitch -= 20
            n[1].pitch -= 4
            n[2].pitch += 1
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .ɕ, .dʒ, .tɕ, .tj, .dj:
            var n = self
            n[0].pitch -= 20
            n[1].pitch += 7
            n[2].pitch += 2
            n = phoneme.isDakuon ? n.toDakuon() : n.toVoiceless()
            return n
        case .off:
            var n = withSelfA(to: .ɴ)
            n[2].formMultiplyNoise(0.75)
            n[3].formMultiplyNoise(0.6)
            n[4].formMultiplyNoise(0.5)
            return n
        case .kjRes, .tɕRes, .pjRes, .çRes, .ɕRes:
            return withSelfA(to: .i).multiplyAllVolm(0.03125)
        case .kβRes, .tsRes, .pβRes, .ɸRes, .sβRes:
            return withSelfA(to: .ɯ).multiplyAllVolm(0.03125)
        case .sokuon:
            return withSelfA(to: .ɯ).toSokuon()
        case .haBreath, .hiBreath, .hɯBreath, .heBreath, .hoBreath:
            let nPhoneme: Phoneme = switch phoneme {
            case .haBreath: .a
            case .hiBreath: .i
            case .hɯBreath: .ɯ
            case .heBreath: .e
            case .hoBreath: .o
            default: fatalError()
            }
            return withSelfA(to: nPhoneme).toFricative(isO: false).toNoise().toBreath()
        case .aBreath, .iBreath, .ɯBreath, .eBreath, .oBreath:
            let nPhoneme: Phoneme = switch phoneme {
            case .aBreath: .ha
            case .iBreath: .ç
            case .ɯBreath: .ɸ
            case .eBreath: .he
            case .oBreath: .ho
            default: fatalError()
            }
            return withSelfA(to: nPhoneme).applyNoise(nPhoneme).toNoise().toBreath()
        default: return self
        }
    }
    
    func applyNoise(_ phoneme: Phoneme, opacity: Double = 1) -> Self {
        switch phoneme {
        case .ta, .tj, .tβ, .te, .to, .da, .dj, .dβ, .de, .do:
            var n = offVolm(from: 4)
            n[0].fillAllVolm(0)
            n.formFillEsVolm(0, at: 0)
            n.fillEsVolm(0, at: 1)
            n[1].fillVolm(0)
            n.fillEsNoise(1, at: 1)
            n[2].fillVolm(0.25)
            n[2].fillNoise(1)
            n.fillEsVolm(0.25, at: 2)
            n.fillEsNoise(0.75, at: 2)
            n[3].fillVolm(0.35)
            n[3].fillNoise(1)
            n.fillEsVolm(0.25, at: 3)
            n.fillEsNoise(0.75, at: 3)
            n[4].fillVolm(0.5)
            n[4].fillNoise(1)
            n.fillEsNoise(0.25, at: 4)
            n[5].fillVolm(0.125)
            n[5].fillNoise(1)
            return .linear(self, n, t: opacity)
        case .ka, .kj, .kβ, .ke, .ko, .ga, .gj, .gβ, .ge, .go, .kjRes, .kβRes:
            var n = offVolm(from: 4)
            switch phoneme {
            case .ka, .kj, .kβ, .ke, .ko:
                n[0].fillAllVolm(0)
            default: break
            }
            n.formFillEsVolm(0, at: 0)
            n.fillEsVolm(0, at: 1)
            n.fillEsNoise(1, at: 1)
            n[2].fillVolm(0.0625)
            n[2].fillNoise(1)
            n.fillEsVolm(0.125, at: 2)
            n.fillEsNoise(1, at: 2)
            n[3].fillVolm(0.125)
            n[3].fillNoise(1)
            n.fillEsVolm(0.25, at: 3)
            n.fillEsNoise(1, at: 3)
            n[4].fillVolm(0.0625)
            n[4].fillNoise(1)
            n[5].fillVolm(0)
            return .linear(self, n, t: opacity)
        case .sa, .sβ, .se, .so, .dza, .dzβ, .dze, .dzo, .ts, .sβRes:
            var n = toNoise(from: 2)
            if phoneme.isDakuon {
                n[0].fillAllVolm(0.6)
                n.formFillEsVolm(0, at: 0)
            } else {
                n[0].fillAllVolm(0)
                n.formFillEsVolm(0, at: 0)
            }
            n[1].fillVolm(0.0625)
            n.fillEsVolm(0, at: 1)
            n[2].fillVolm(0.25)
            n.formFillEsVolm(0.3, at: 2)
            n[3].fillVolm(0.4)
            n.formFillEsVolm(0.5, at: 3)
            n[4].sVolm = 0.7
            n[4].eVolm = 0.8
            n.formFillEsVolm(0.85, at: 4)
            n[5].sVolm = 0.8
            n[5].eVolm = 0.65
            n[5].edVolm = 0
            return .linear(self, n.multiplyAllVolm(0.85), t: opacity)
        case .ɕ, .dʒ, .tɕ, .ɕRes, .tɕRes:
            var n = toNoise(from: 2)
            if phoneme.isDakuon {
                n[0].fillAllVolm(0.6)
                n.formFillEsVolm(0, at: 0)
            } else {
                n[0].fillAllVolm(0)
                n.formFillEsVolm(0, at: 0)
            }
            n[1].fillVolm(0)
            n.fillEsVolm(0, at: 1)
            n[2].sdVolm = 0
            n[2].fillVolm(0.2)
            n.formFillEsVolm(0.4, at: 2)
            n[3].fillVolm(0.5)
            n.formFillEsVolm(0.85, at: 3)
            n[4].fillVolm(0.85)
            n.formFillEsVolm(0.6, at: 4)
            n[5].fillVolm(0.45)
            n[5].edVolm = 0
            return .linear(self, n, t: opacity)
        case .ha, .he, .ho:
            var n = toNoise()
            n[0].sdNoise = 0
            n[0].fillNoise(0)
            n[1].fillVolm(0.25)
            n.fillEsNoise(0.125, at: 0)
            n[2].fillVolm(0.1)
            n[1].fillNoise(0.4)
            n[2].fillNoise(1)
            n[2].fillVolm(0.1)
            n[3].fillNoise(1)
            n[3].fillVolm(0.1)
            return .linear(self, n, t: opacity)
        case .ç, .çRes:
            var n = toNoise()
            n[0].sdVolm *= 0.56
            n[0].sdNoise = 0
            n[0].fillVolm(0.25)
            n.fillEsVolm(0.125, at: 0)
            n[0].fillNoise(0)
            n.fillEsNoise(0.25, at: 0)
            n[1].fillVolm(0.5)
            n.fillEsVolm(0.5, at: 1)
            n[1].fillNoise(0.5)
            n[2].fillVolm(0.9)
            n.fillEsVolm(0.6, at: 2)
            n[3].fillVolm(0.5)
            n.fillEsVolm(0.5, at: 3)
            n[4].fillVolm(0.7)
            n.fillEsVolm(0.4, at: 4)
            n[5].fillVolm(0.4)
            n[5].edVolm = 0
            return .linear(self, n.multiplyAllVolm(0.5), t: opacity)
        case .ɸ, .ɸRes:
            var n = toNoise()
            n[0].sdVolm *= 0.56
            n[0].sdNoise = 0
            n[0].fillVolm(0.25)
            n.fillEsVolm(0.125, at: 0)
            n[0].fillNoise(0)
            n.fillEsNoise(0.25, at: 0)
            n[1].fillVolm(0.5)
            n.fillEsVolm(0.25, at: 1)
            n[1].fillNoise(0.5)
            n[2].fillVolm(0.5)
            n.fillEsVolm(0.6, at: 2)
            n[3].fillVolm(0.7)
            n.fillEsVolm(0.5, at: 3)
            n[4].fillVolm(0.8)
            n.fillEsVolm(0.6, at: 4)
            n[5].fillVolm(0.5)
            n[5].edVolm = 0
            return .linear(self, n.multiplyAllVolm(0.5), t: opacity)
        default:
            return self
        }
    }
    
    func toFricative(isO: Bool) -> Self {
        var n = offVolm(from: 5)
        n[0].sdVolm *= 0.125
        n[0].formMultiplyVolm(0)
        n.formMultiplyEsVolm(0, at: 0)
        n[1].formMultiplyVolm(0.75)
        n.formMultiplyEsVolm(0.25, at: 1)
        n[2].formMultiplyVolm(1)
        n.formMultiplyEsVolm(0.5, at: 2)
        n[3].formMultiplyVolm(isO ? 0.6 : 1)
        n.formMultiplyEsVolm(0, at: 3)
        n[4].formMultiplyVolm(isO ? 0.2 : 0.5)
        n.formMultiplyEsVolm(0, at: 4)
        n[5].formMultiplyVolm(isO ? 0.1 : 0.2)
        n.formMultiplyEsVolm(0, at: 5)
        return n
    }
    func toBreath() -> Self {
        var n = offVolm(from: 4)
        n[0].sdNoise = 0
        n[0].sdVolm = 0
        n[0].fillVolm(n[2].volm * 0.7)
        n[0].formMultiplyVolm(0.25)
        n[1].sdVolm = n[1].volm * 0.5
        n[1].fillNoise(1)
        n[2].formMultiplyVolm(0.85)
        n[2].fillNoise(1)
        n.formMultiplyEsVolm(0.7, at: 2)
        n[3].formMultiplyVolm(0.7)
        n[3].fillNoise(1)
        return n
    }
    func toVoiceless() -> Self {
        multiplyAllVolm(0)
    }
    func toDakuon() -> Self {
        var n = offVolm(from: 1)
        n[0].sVolm *= 0.85
        n[0].eVolm *= 0.8
        n.fillEsVolm(0, at: 0)
        return n
    }
    func toSokuon() -> Self {
        multiplyAllVolm(0.03125)
    }
    
    func toNoise(to i: Int) -> Self {
        var n = self
        for i in 0 ... i {
            n[i].fillAllNoise(1)
        }
        return n
    }
    func toNoise(from i: Int) -> Self {
        var n = self
        if i < n.count {
            for i in i ..< n.count {
                n[i].fillAllNoise(1)
            }
        }
        return n
    }
    func toNoise() -> Self {
        var n = self
        n.formants = n.formants.map { $0.toAllNoise() }
        return n
    }
    
    func connectNoise() -> Self {
        var n = self
        n.formMultiplyEsVolm(0, at: 0)
        n.formMultiplyEsVolm(0, at: 1)
        n.formMultiplyEsVolm(0, at: 2)
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
        if i < n.count {
            for i in i ..< n.count {
                n[i].fillAllVolm(0)
            }
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

struct KeyFormantFilter: Hashable, Codable {
    var formantFilter: FormantFilter
    var durSec = 0.0
    var sec = 0.0
    var pitch = Rational()
    var id = UUID()
    
    init(_ formantFilter: FormantFilter,
         durSec: Double = 0, sec: Double = 0, pitch: Rational = .init(), id: UUID = .init()) {
        self.formantFilter = formantFilter
        self.durSec = durSec
        self.sec = sec
        self.pitch = pitch
        self.id = id
    }
}

struct Mora: Hashable, Codable {
    var keyFormantFilters: [KeyFormantFilter]
    
    init?(hiragana: String, previousPhoneme: Phoneme?, previousFormantFilter: FormantFilter?, previousID: UUID?, nextPhoneme: Phoneme?) {
        var phonemes = Phoneme.phonemes(fromHiragana: hiragana, nextPhoneme: nextPhoneme)
        guard !phonemes.isEmpty else { return nil }
        
        let baseFf: FormantFilter = if let previousPhoneme, let previousFormantFilter {
            previousFormantFilter.toA(from: previousPhoneme)
        } else {
            .init()
        }
        
        let vowel: Phoneme
        switch phonemes.last {
        case .a, .i, .ɯ, .e, .o, .ɴ, .off, .n, .m, .ŋ, .ã, .ĩ, .ɯ̃, .ẽ, .õ:
            vowel = phonemes.last!
            phonemes.removeLast()
        case .sokuon:
            let ff = baseFf.withSelfA(to: .sokuon)
            keyFormantFilters = if let preFf = previousFormantFilter {
                [.init(preFf, durSec: 0.06, sec: -0.06), .init(ff, sec: 0)]
            } else {
                [.init(ff, sec: 0)]
            }
            return
        case .kjRes, .kβRes, .tɕRes, .tsRes, .pjRes, .pβRes, .çRes, .ɸRes, .ɕRes, .sβRes:
            let phoneme = phonemes.last!
            vowel = switch phoneme {
            case .kjRes, .tɕRes, .pjRes, .çRes, .ɕRes: .i
            default: .ɯ
            }
        case .haBreath, .hiBreath, .hɯBreath, .heBreath, .hoBreath:
            let ff = baseFf.withSelfA(to: phonemes.last!)
            keyFormantFilters = if let preFf = previousFormantFilter {
                [.init(preFf, durSec: 0.06, sec: -0.06), .init(ff, durSec: 0)]
            } else {
                [.init(ff, durSec: 0)]
            }
            return
        case .aBreath, .iBreath, .ɯBreath, .eBreath, .oBreath:
            let ff = baseFf.withSelfA(to: phonemes.last!)
            keyFormantFilters = if let preFf = previousFormantFilter {
                [.init(preFf,durSec: 0.08,  sec: -0.08), .init(ff, durSec: 0)]
            } else {
                [.init(ff, durSec: 0)]
            }
            return
        default:
            return nil
        }
        let vowelFf = baseFf.withSelfA(to: vowel)
        
        let youonFf: FormantFilter?, youonDurSec: Double, isβ: Bool
        switch phonemes.last {
        case .j, .ja:
            let phoneme = phonemes.last!
            phonemes.removeLast()
            
            youonFf = baseFf.withSelfA(to: phoneme)
            youonDurSec = 0.11
            isβ = false
        case .β:
            phonemes.removeLast()
            
            youonFf = baseFf.withSelfA(to: .β)
            youonDurSec = 0.07
            isβ = true
        default:
            youonFf = nil
            youonDurSec = 0
            isβ = false
        }
        
        var kffs = [KeyFormantFilter]()
        let centerI: Int
        if phonemes.isEmpty {
            if let preFf = previousFormantFilter, let id = previousID {
                if vowel == .off {
                    kffs.append(.init(preFf, durSec: 0.12, id: id))
                    centerI = kffs.count
                } else if youonFf == nil {
                    kffs.append(.init(preFf, durSec: 0.04, id: id))
                    var ff0 = FormantFilter.linear(preFf, vowelFf, t: 0.25)
                    ff0[1].formMultiplyVolm(0.75)
                    kffs.append(.init(ff0, durSec: 0.04))
                    centerI = kffs.count
                    var ff1 = FormantFilter.linear(preFf, vowelFf, t: 0.75)
                    ff1[1].formMultiplyVolm(0.75)
                    kffs.append(.init(ff1, durSec: 0.04))
                } else {
                    kffs.append(.init(preFf, durSec: isβ ? 0.05 : 0.1, id: id))
                    centerI = kffs.count
                }
            } else {
                centerI = kffs.count
            }
            if let youonFf {
                kffs.append(.init(youonFf, durSec: youonDurSec))
            }
            kffs.append(.init(vowelFf, durSec: 0))
        } else {
            let oph = phonemes[0]
            let onsetScale = previousPhoneme == .sokuon ? 1.5 : 1
            let onsetDurSec: Double, pitch: Rational, paddingSec: Double
            switch oph {
            case .n, .nj:
                onsetDurSec = 0.06
                pitch = 0
                paddingSec = 0.03
            case .m, .mj:
                onsetDurSec = 0.04
                pitch = 0
                paddingSec = 0.03
            case .ɾ, .ɾj:
                onsetDurSec = 0.0075
                pitch = -1
                paddingSec = 0.035
            case .p, .pj, .pjRes, .pβRes:
                onsetDurSec = 0.03
                pitch = -2
                paddingSec = 0.05
            case .b, .bj:
                onsetDurSec = 0.01
                pitch = -2
                paddingSec = 0.05
            case .sa, .ɕ, .sβ, .se, .so, .ɕRes, .sβRes:
                onsetDurSec = 0.065 * onsetScale
                pitch = -3
                paddingSec = 0.05
            case .dza, .dʒ, .dzβ, .dze, .dzo:
                onsetDurSec = 0.02 * onsetScale
                pitch = -3
                paddingSec = 0.05
            case .ha, .he, .ho:
                onsetDurSec = 0.02 * onsetScale
                pitch = -3
                paddingSec = 0.05
            case .ç, .çRes:
                onsetDurSec = 0.04 * onsetScale
                pitch = -3
                paddingSec = 0.05
            case .ɸ, .ɸRes:
                onsetDurSec = 0.02 * onsetScale
                pitch = -3
                paddingSec = 0.05
            case .ka, .kj, .kβ, .ke, .ko:
                onsetDurSec = 0.0075
                pitch = -3
                paddingSec = 0.05
            case .ga, .gj, .gβ, .ge, .go:
                onsetDurSec = 0.0075
                pitch = -3
                paddingSec = 0.05
            case .ta, .tj, .tβ, .te, .to:
                onsetDurSec = 0.01
                pitch = -3
                paddingSec = 0.03
            case .tɕ, .tɕRes:
                onsetDurSec = 0.05 * onsetScale
                pitch = -3
                paddingSec = 0.05
            case .ts, .tsRes:
                onsetDurSec = 0.03 * onsetScale
                pitch = -3
                paddingSec = 0.05
            case .da, .dj, .dβ, .de, .do:
                onsetDurSec = 0.03
                pitch = -3
                paddingSec = 0.03
            default:
                onsetDurSec = 0
                pitch = 0
                paddingSec = 0.05
            }
            
            let nextFf = youonFf ?? vowelFf
            let nFf = baseFf.withSelfA(to: oph)
            switch oph {
            case .n, .nj:
                if let preFf = previousFormantFilter, let id = previousID {
                    var ff1 = preFf
                    ff1[1] = .linear(ff1[1], nFf[1], t: 0.5)
                    
                    kffs.append(.init(preFf, durSec: paddingSec * 0.75, id: id))
                    kffs.append(.init(ff1, durSec: paddingSec))
                }
                kffs.append(.init(nFf, durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(nFf, durSec: paddingSec * 0.75, pitch: pitch))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                    kffs.append(.init(vowelFf, durSec: 0))
                } else {
                    var ff0 = nextFf
                    ff0[0].pitch = .linear(nFf[0].pitch, nextFf[0].pitch, t: 0.5)
                    ff0[1].fillVolm(.linear(nFf[1].volm, nextFf[1].volm, t: 0.25))
                    ff0[1].pitch = .linear(nFf[1].pitch, nextFf[1].pitch, t: 0.75)
                    
                    kffs.append(.init(ff0, durSec: paddingSec))
                    kffs.append(.init(vowelFf, durSec: 0))
                }
            case .ɾ, .ɾj:
                if let preFf = previousFormantFilter, let id = previousID {
                    var ff1 = preFf
                    ff1[1] = .linear(ff1[1], nFf[1], t: 0.5)
                    
                    kffs.append(.init(preFf, durSec: paddingSec * 0.75, id: id))
                    kffs.append(.init(ff1, durSec: paddingSec))
                }
                kffs.append(.init(nFf, durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(nFf, durSec: paddingSec, pitch: pitch))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: 0.025))
                    kffs.append(.init(.linear(youonFf, vowelFf,
                                              t: 0.025 / youonDurSec),
                                      durSec: 0.025, pitch: -pitch / 8))
                    kffs.append(.init(.linear(youonFf, vowelFf,
                                              t: 0.05 / youonDurSec),
                                      durSec: youonDurSec - 0.05))
                } else {
                    var ff0 = nextFf
                    ff0[1].fillVolm(.linear(nextFf[1].volm, nFf[1].volm, t: 0.75))
                    ff0[1].pitch = .linear(nextFf[1].pitch, nFf[1].pitch, t: 0.75)
                    
                    kffs.append(.init(ff0, durSec: 0.025))
                    kffs.append(.init(ff0, durSec: 0.025, pitch: -pitch / 8))
                }
                kffs.append(.init(vowelFf, durSec: 0))
            case .ha, .ç, .ɸ, .he, .ho, .çRes, .ɸRes:
                let nextFf = oph.isVowelReduction ? nextFf.multiplyAllVolm(0.03125) : nextFf
                let vowelFf = oph.isVowelReduction ? vowelFf.multiplyAllVolm(0.03125) : vowelFf
                
                let onsetFf = nFf.applyNoise(oph)
                if let preFf = previousFormantFilter, let id = previousID {
                    var ff0 =  preFf
                    ff0[1] = .linear(preFf[1], onsetFf[1], t: 0.35)
                    
                    kffs.append(.init(preFf, durSec: paddingSec * 0.5, id: id))
                    kffs.append(.init(ff0, durSec: paddingSec, pitch: 0))
                }
                var ff0 = onsetFf
                ff0[2].fillVolm(onsetFf[3].sdVolm)
                ff0[4].fillVolm(onsetFf[4].edVolm)
                
                kffs.append(.init(ff0, durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(onsetFf, durSec: paddingSec * 2 / 3, pitch: pitch))
                kffs.append(.init(.linear(onsetFf, nextFf, t: 2 / 3), durSec: paddingSec / 3, pitch: -pitch / 8))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                }
                kffs.append(.init(vowelFf, durSec: 0))
            case .ka, .kj, .kβ, .ke, .ko, .kjRes, .kβRes:
                let nextFf = oph.isVowelReduction ? nextFf.multiplyAllVolm(0.03125) : nextFf
                let vowelFf = oph.isVowelReduction ? vowelFf.multiplyAllVolm(0.03125) : vowelFf
                
                if let preFf = previousFormantFilter, let id = previousID {
                    let nnFf = FormantFilter.linear(preFf, nFf, t: 0.75)
                    kffs.append(.init(preFf, durSec: 0.03, id: id))
                    kffs.append(.init(nnFf.multiplyAllVolm(0), durSec: 0.04, pitch: pitch))
                } else {
                    kffs.append(.init(nFf.multiplyAllVolm(0), durSec: 0.04, pitch: pitch))
                }
                kffs.append(.init(nFf.multiplyAllVolm(0), durSec: paddingSec * 0.25, pitch: pitch))
                
                var ff0 = nFf.applyNoise(oph)
                ff0[1].pitch = .linear(nFf[1].pitch, nextFf[1].pitch, t: 0.25)
                let fScale = switch oph {
                case .ka: 0.6
                case .kj, .ke: 0.7
                default: 1.25
                }
                ff0[1].fillVolm(fScale * .linear(nFf[1].volm, nextFf[1].volm, t: 0.75))
                ff0[1].fillNoise(0.75)
                ff0[1].sdPitch *= 1.25
                ff0[1].dPitch *= 2
                ff0[1].edPitch *= 1.25
                
                kffs.append(.init(ff0, durSec: paddingSec * 0.25, pitch: pitch * 4 / 5))
                
                var ff1 = FormantFilter.linear(ff0, nextFf, t: 0.25)
                ff1[3].edVolm = nextFf[3].edVolm
                ff1[4] = nextFf[4]
                ff1[5] = nextFf[5]
                
                kffs.append(.init(ff1, durSec: paddingSec * 0.5, pitch: pitch / 2))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: 0.0125))
                    kffs.append(.init(.linear(youonFf, vowelFf,
                                              t: 0.00625 / youonDurSec),
                                      durSec: 0.00625, pitch: -pitch / 4))
                    kffs.append(.init(.linear(youonFf, vowelFf,
                                              t: 0.0125 / youonDurSec),
                                      durSec: youonDurSec - 0.0125))
                } else {
                    kffs.append(.init(vowelFf, durSec: 0.00625))
                    kffs.append(.init(vowelFf, durSec: 0.00625, pitch: -pitch / 4))
                }
                kffs.append(.init(vowelFf, durSec: 0))
            case .ga, .gj, .gβ, .ge, .go:
                if let preFf = previousFormantFilter, let id = previousID {
                    kffs.append(.init(preFf, durSec: paddingSec, id: id))
                }
                kffs.append(.init(nFf, durSec: paddingSec * 0.25, pitch: pitch))
                
                var ff0 = nFf.applyNoise(oph)
                let fScale = switch oph {
                case .ga: 0.6
                case .gj, .ge: 0.7
                default: 1.25
                }
                ff0[1].fillVolm(fScale * .linear(ff0[1].volm, nextFf[1].volm, t: 0.75))
                ff0[1].fillNoise(0.75)
                ff0[1].sdPitch *= 1.25
                ff0[1].dPitch *= 2
                ff0[1].edPitch *= 1.25
                
                kffs.append(.init(ff0, durSec: paddingSec * 0.35, pitch: pitch * 4 / 5))
                
                var ff1 = ff0.mid(nextFf)
                ff1[1].pitch = .linear(ff0[1].pitch, nextFf[1].pitch, t: 0.25)
                ff1[1].fillVolm(ff0[1].volm)
                
                kffs.append(.init(ff1, durSec: paddingSec * 0.4, pitch: pitch / 3))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                }
                kffs.append(.init(vowelFf, durSec: 0))
            case .sa, .ɕ, .sβ, .se, .so, .ɕRes, .sβRes:
                let nextFf = oph.isVowelReduction ? nextFf.multiplyAllVolm(0.03125) : nextFf
                let vowelFf = oph.isVowelReduction ? vowelFf.multiplyAllVolm(0.03125) : vowelFf
                
                let onsetFf = nFf.applyNoise(oph)
                if let preFf = previousFormantFilter, let id = previousID {
                    var ff00 = preFf.mid(onsetFf)
                    for i in ff00.count.range {
                        ff00[i].fillVolm(.linear(preFf[i].volm, onsetFf[i].volm, t: 0.75))
                    }
                    ff00[0].fillVolm(.linear(preFf[0].volm, onsetFf[0].volm, t: 0.25))
                    ff00[1].fillVolm(.linear(preFf[1].volm, onsetFf[1].volm, t: 0.25))
                    
                    kffs.append(.init(preFf, durSec: 0.03, id: id))
                    kffs.append(.init(ff00, durSec: 0.02, id: id))
                } else {
                    kffs.append(.init(onsetFf.multiplyAllVolm(0), durSec: 0.05, pitch: pitch))
                }
                var onsetFf0 = onsetFf
                onsetFf0.formMultiplyEsVolm(0.7, at: 4)
                
                kffs.append(.init(onsetFf0, durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(onsetFf, durSec: 0.02, pitch: pitch))
                
                var ff0 = nextFf
                ff0[0] = .linear(onsetFf[0], nextFf[0], t: 0.5)
                ff0[1] = .linear(onsetFf[1], nextFf[1], t: 0.5)
                ff0[1].fillVolm(.linear(onsetFf[1].volm, nextFf[1].volm, t: 0.75))
                
                kffs.append(.init(ff0, durSec: 0.015, pitch: pitch * 2 / 3))
                kffs.append(.init(.linear(ff0, nextFf, t: 0.5), durSec: 0.015, pitch: -pitch / 8))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                }
                kffs.append(.init(vowelFf, durSec: 0))
            case .dza, .dʒ, .dzβ, .dze, .dzo:
                let onsetFf = nFf.applyNoise(oph)
                if let preFf = previousFormantFilter, let id = previousID {
                    kffs.append(.init(preFf, durSec: paddingSec, id: id))
                } else {
                    kffs.append(.init(onsetFf.multiplyAllVolm(0), durSec: 0.05, pitch: pitch))
                }
                kffs.append(.init(onsetFf, durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(onsetFf, durSec: 0.025, pitch: pitch))
                if let youonFf {
                    kffs.append(.init(.linear(onsetFf, youonFf, t: 0.5), durSec: 0.025, pitch: -pitch / 8))
                    centerI = kffs.count
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                } else {
                    var ff0 = FormantFilter.linear(onsetFf, nextFf, t: 0.75)
                    ff0[3].edVolm = nextFf[3].edVolm
                    ff0[4] = nextFf[4]
                    ff0[5] = nextFf[5]
                    
                    kffs.append(.init(ff0, durSec: 0.02, pitch: pitch * 2 / 3))
                    kffs.append(.init(.linear(ff0, nextFf, t: 0.5), durSec: 0.025, pitch: -pitch / 8))
                    centerI = kffs.count
                }
                kffs.append(.init(vowelFf, durSec: 0))
            case .ta, .tj, .tβ, .te, .to, .tɕ, .ts, .tɕRes, .tsRes:
                let nextFf = oph.isVowelReduction ? nextFf.multiplyAllVolm(0.03125) : nextFf
                let vowelFf = oph.isVowelReduction ? vowelFf.multiplyAllVolm(0.03125) : vowelFf
                
                let offSec = switch oph {
                case .tɕ, .ts: 0.02
                default: 0.035
                }
                let onsetLastDurSec = 0.02
                let onsetFf = nFf.applyNoise(oph)
                if let preFf = previousFormantFilter, let id = previousID {
                    let nnFf = FormantFilter.linear(preFf, nFf, t: 0.75)
                    kffs.append(.init(preFf, durSec: paddingSec, id: id))
                    kffs.append(.init(nnFf.multiplyAllVolm(0), durSec: offSec, pitch: pitch))
                } else {
                    kffs.append(.init(onsetFf.multiplyAllVolm(0), durSec: offSec, pitch: pitch))
                }
                kffs.append(.init(onsetFf.multiplyAllVolm(0), durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(onsetFf, durSec: onsetLastDurSec, pitch: -pitch / 4))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                    kffs.append(.init(vowelFf, durSec: 0))
                } else {
                    var ff0 = nextFf
                    ff0[0].pitch = .linear(nFf[0].pitch, nextFf[0].pitch, t: 0.75)
                    ff0[1].fillVolm(nextFf[1].volm)
                    ff0[1].pitch = .linear(nFf[1].pitch, nextFf[1].pitch, t: 0.75)
                    ff0.formMultiplyEsVolm(.linear(nFf[0].volm, nextFf[0].volm, t: 0.25), at: 0)
                    
                    kffs.append(.init(ff0, durSec: paddingSec * 2))
                    kffs.append(.init(vowelFf, durSec: 0))
                }
            case .da, .dj, .dβ, .de, .do:
                if let preFf = previousFormantFilter, let id = previousID {
                    var ff1 = preFf
                    ff1[1] = .linear(ff1[1], nFf[1], t: 0.5)
                    
                    kffs.append(.init(preFf, durSec: paddingSec * 0.75, id: id))
                    kffs.append(.init(ff1, durSec: paddingSec))
                }
                kffs.append(.init(nFf, durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(nFf, durSec: paddingSec, pitch: -pitch / 4))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                    kffs.append(.init(vowelFf, durSec: 0))
                } else {
                    var ff0 = nextFf
                    ff0[0].pitch = .linear(nFf[0].pitch, nextFf[0].pitch, t: 0.75)
                    ff0[1].fillVolm(nextFf[1].volm)
                    ff0[1].pitch = .linear(nFf[1].pitch, nextFf[1].pitch, t: 0.75)
                    ff0.formMultiplyEsVolm(.linear(nFf[0].volm, nextFf[0].volm, t: 0.25), at: 0)
                    
                    kffs.append(.init(ff0, durSec: paddingSec * 2))
                    kffs.append(.init(vowelFf, durSec: 0))
                }
            case .b, .bj:
                if let preFf = previousFormantFilter, let id = previousID {
                    kffs.append(.init(preFf, durSec: paddingSec, id: id))
                }
                kffs.append(.init(nFf, durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(nFf, durSec: paddingSec * 0.75, pitch: pitch))
                kffs.append(.init(.linear(nFf, nextFf, t: 0.75), durSec: paddingSec * 0.25, pitch: -pitch / 8))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                }
                kffs.append(.init(vowelFf, durSec: 0))
            case .p, .pj, .pjRes, .pβRes:
                let nextFf = oph.isVowelReduction ? nextFf.multiplyAllVolm(0.03125) : nextFf
                let vowelFf = oph.isVowelReduction ? vowelFf.multiplyAllVolm(0.03125) : vowelFf
                
                if let preFf = previousFormantFilter, let id = previousID {
                    kffs.append(.init(preFf, durSec: paddingSec, id: id))
                }
                kffs.append(.init(nFf, durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(nFf, durSec: paddingSec * 2 / 3, pitch: pitch))
                kffs.append(.init(.linear(nFf, nextFf, t: 2 / 3), durSec: paddingSec / 6, pitch: pitch / 2))
                kffs.append(.init(.linear(nFf, nextFf, t: 5 / 6), durSec: paddingSec / 6, pitch: -pitch / 2))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                }
                kffs.append(.init(vowelFf, durSec: 0))
            default:
                if let preFf = previousFormantFilter, let id = previousID {
                    kffs.append(.init(preFf, durSec: paddingSec, id: id))
                }
                kffs.append(.init(nFf, durSec: onsetDurSec, pitch: pitch))
                kffs.append(.init(nFf, durSec: paddingSec, pitch: pitch))
                centerI = kffs.count
                if let youonFf {
                    kffs.append(.init(youonFf, durSec: youonDurSec))
                }
                kffs.append(.init(vowelFf, durSec: 0))
            }
        }
        
        var sec = 0.0
        for i in (0 ..< centerI).reversed() {
            sec -= kffs[i].durSec
            kffs[i].sec = sec
        }
        sec = 0.0
        for i in centerI ..< kffs.count {
            kffs[i].sec = sec
            sec += kffs[i].durSec
        }
        self.keyFormantFilters = kffs
    }
    
    mutating func set(minSec: Double?, maxSec: Double?) {
        let oMinSec = keyFormantFilters.minValue { $0.sec } ?? 0
        let oMaxSec = keyFormantFilters.maxValue { $0.sec } ?? 0
        if let minSec, minSec <= 0, oMinSec < 0, oMinSec < minSec {
            let scale = minSec / oMinSec
            for (fi, ff) in keyFormantFilters.enumerated() {
                keyFormantFilters[fi].sec *= scale
                if ff.sec >= 0 { break }
            }
        }
        if let maxSec, maxSec >= 0, oMaxSec > 0, oMaxSec > maxSec {
            let scale = maxSec / oMaxSec
            for (fi, ff) in keyFormantFilters.enumerated().reversed() {
                keyFormantFilters[fi].sec *= scale
                if ff.sec <= 0 { break }
            }
        }
    }
}

enum Phoneme: String, Hashable, Codable, CaseIterable {
    case a, i, ɯ, e, o, j, ja, β, ɴ,
         n, nj, m, mj, ɾ, ɾj,
         ha, ç, ɸ, he, ho,
         p, pj, b, bj,
         ka, kj, kβ, ke, ko,
         ga, gj, gβ, ge, go,
         sa, ɕ, sβ, se, so,
         dza, dʒ, dzβ, dze, dzo,
         ta, tj, tβ, te, to, tɕ, ts,
         da, dj, dβ, de, `do`,
         ŋ, ã, ĩ, ɯ̃, ẽ, õ,
         çRes = "ç/", ɸRes = "ɸ/",
         pjRes = "pj/", pβRes = "pβ/",
         kjRes = "kj/", kβRes = "kβ/",
         ɕRes = "ɕ/", sβRes = "sβ/",
         tɕRes = "tɕ/", tsRes = "ts/",
         sokuon = "_", off = ".", voiceless = ",",
         haBreath = "~a", hiBreath = "~i", hɯBreath = "~ɯ", heBreath = "~e", hoBreath = "~o",
         aBreath = "^a", iBreath = "^i", ɯBreath = "^ɯ", eBreath = "^e", oBreath = "^o"
}
extension Phoneme {
    var isJapaneseVowel: Bool {
        switch self {
        case .a, .i, .ɯ, .e, .o, .ɴ, .off, .ã, .ĩ, .ɯ̃, .ẽ, .õ: true
        default: false
        }
    }
    var isJapaneseConsonant: Bool {
        !isJapaneseVowel
    }
    
    var isDakuon: Bool {
        switch self {
        case .ga, .gj, .gβ, .ge, .go, 
                .dza, .dʒ, .dzβ, .dze, .dzo,
                .da, .dj, .dβ, .de, .do,
                .b, .bj: true
        default: false
        }
    }
    var isHaretsu: Bool {
        switch self {
        case .ka, .kj, .kβ, .ke, .ko, .kjRes, .kβRes,
                .sa, .ɕ, .sβ, .se, .so, .ɕRes, .sβRes,
                .ta, .tj, .tβ, .te, .to, .tɕ, .ts, .tɕRes, .tsRes,
                .ha, .ç, .ɸ, .he, .ho, .çRes, .ɸRes,
                .p, .pj, .pjRes, .pβRes: true
        default: false
        }
    }
    var isBiohuru: Bool {
        switch self {
        case .n, .nj, .m, .mj, .ɾ, .ŋ: true
        default: false
        }
    }
    var isYouon: Bool {
        switch self{
        case .j, .ja, .β: true
        default: false
        }
    }
    var isVowelReduction: Bool {
        switch self {
        case .kjRes, .kβRes, .tɕRes, .tsRes, .pjRes, .pβRes, .çRes, .ɸRes, .ɕRes, .sβRes: true
        default: false
        }
    }
    
    var isK: Bool {
        switch self {
        case .ka, .kj, .kβ, .ke, .ko, .kjRes, .kβRes: true
        default: false
        }
    }
    var isG: Bool {
        switch self {
        case .ga, .gj, .gβ, .ge, .go: true
        default: false
        }
    }
    var isS: Bool {
        switch self {
        case .sa, .ɕ, .sβ, .se, .so, .ɕRes, .sβRes: true
        default: false
        }
    }
    var isDz: Bool {
        switch self {
        case .dza, .dʒ, .dzβ, .dze, .dzo: true
        default: false
        }
    }
    var isH: Bool {
        switch self {
        case .ha, .ç, .ɸ, .he, .ho, .çRes, .ɸRes: true
        default: false
        }
    }
}
extension Phoneme {
    static func phonemes(fromHiragana hiragana: String, nextPhoneme: Phoneme?) -> [Phoneme] {
        switch hiragana {
        case "あ", "a": [.a]
        case "い", "i": [.i]
        case "う", "u": [.ɯ]
        case "え", "e": [.e]
        case "お", "を", "o", "wo": [.o]
        case "か", "ka": [.ka, .a]
        case "き", "ki": [.kj, .i]
        case "く", "ku": [.kβ, .ɯ]
        case "け", "ke": [.ke, .e]
        case "こ", "ko": [.ko, .o]
        case "きゃ", "kya": [.kj, .ja, .a]
        case "きゅ", "kyu": [.kj, .j, .ɯ]
        case "きぇ", "kye": [.kj, .j, .e]
        case "きょ", "kyo": [.kj, .j, .o]
        case "くぁ", "くゎ", "kwa": [.kβ, .β, .a]
        case "くぃ", "kwi": [.kβ, .β, .i]
        case "くぇ", "kwe": [.kβ, .β, .e]
        case "くぉ", "kwo": [.kβ, .β, .o]
        case "が", "ga": [.ga, .a]
        case "ぎ", "gi": [.gj, .i]
        case "ぐ", "gu": [.gβ, .ɯ]
        case "げ", "ge": [.ge, .e]
        case "ご", "go": [.go, .o]
        case "ぎゃ", "gya": [.gj, .ja, .a]
        case "ぎゅ", "gyu": [.gj, .j, .ɯ]
        case "ぎぇ", "gye": [.gj, .j, .e]
        case "ぎょ", "gyo": [.gj, .j, .o]
        case "ぐぁ", "ぐゎ", "gwa": [.gβ, .β, .a]
        case "ぐぃ", "gwi": [.gβ, .β, .ɯ]
        case "ぐぇ", "gwe": [.gβ, .β, .e]
        case "ぐぉ", "gwo": [.gβ, .β, .o]
        case "さ", "sa": [.sa, .a]
        case "し", "si", "shi": [.ɕ, .i]
        case "す", "su": [.sβ, .ɯ]
        case "せ", "se": [.se, .e]
        case "そ", "so": [.so, .o]
        case "しゃ", "sya", "sha": [.ɕ, .a]
        case "しゅ", "syu", "shu": [.ɕ, .ɯ]
        case "しぇ", "sye", "she": [.ɕ, .e]
        case "しょ", "syo", "sho": [.ɕ, .o]
        case "すぁ", "すゎ", "swa": [.sβ, .β, .a]
        case "すぃ", "swi": [.sβ, .β, .i]
        case "すぇ", "swe": [.sβ, .β, .e]
        case "すぉ", "swo": [.sβ, .β, .o]
        case "ざ", "za": [.dza, .a]
        case "じ", "ぢ", "zi", "ji", "di": [.dʒ, .i]
        case "ず", "づ", "zu", "du": [.dzβ, .ɯ]
        case "ぜ", "ze": [.dze, .e]
        case "ぞ", "zo": [.dzo, .o]
        case "じゃ", "ぢゃ", "ja", "jya", "zya", "dya": [.dʒ, .ja, .a]
        case "じゅ", "ぢゅ", "ju", "jyu", "zyu", "dyu": [.dʒ, .j, .ɯ]
        case "じぇ", "ぢぇ", "je", "jye", "zye", "dye": [.dʒ, .j, .e]
        case "じょ", "ぢょ", "jo", "jyo", "zyo", "dyo": [.dʒ, .j, .o]
        case "ずぁ", "ずゎ", "づぁ", "づゎ", "zwa": [.dzβ, .β, .a]
        case "ずぃ", "づぃ", "zwi", "dwi": [.dzβ, .β, .i]
        case "ずぇ", "づぇ", "zwe", "dwe": [.dzβ, .β, .e]
        case "ずぉ", "づぉ", "zwo", "dwo": [.dzβ, .β, .o]
        case "た", "ta": [.ta, .a]
        case "ち", "ti", "chi": [.tɕ, .i]
        case "つ", "tu", "tsu": [.ts, .ɯ]
        case "て", "te": [.te, .e]
        case "と", "to": [.to, .o]
        case "てぃ", "thi": [.tj, .i]
        case "とぅ", "twu": [.tβ, .ɯ]
        case "ちゃ", "tya", "cya", "cha": [.tɕ, .ja, .a]
        case "ちゅ", "tyu", "cyu", "chu": [.tɕ, .j, .ɯ]
        case "ちぇ", "tye", "cye", "che": [.tɕ, .j, .e]
        case "ちょ", "tyo", "cyo", "cho": [.tɕ, .j, .o]
        case "つぁ", "tuxa": [.ts, .β, .a]
        case "つぃ", "tuxi": [.ts, .β, .i]
        case "つぇ", "tuxe": [.ts, .β, .e]
        case "つぉ", "tuxo": [.ts, .β, .o]
        case "てゃ", "tha": [.tj, .ja, .a]
        case "てゅ", "thu": [.tj, .j, .ɯ]
        case "てぇ", "the": [.tj, .j, .e]
        case "てょ", "tho": [.tj, .j, .o]
        case "とぁ", "とゎ", "twa": [.tβ, .β, .a]
        case "とぃ", "twi": [.tβ, .β, .i]
        case "とぇ", "twe": [.tβ, .β, .e]
        case "とぉ", "two": [.tβ, .β, .o]
        case "だ", "da": [.da, .a]
        case "でぃ", "dhi": [.dj, .i]
        case "どぅ", "dhwu": [.dβ, .ɯ]
        case "で", "de": [.de, .e]
        case "ど", "do": [.do, .o]
        case "でゃ", "dha": [.dj, .ja, .a]
        case "でゅ", "dhu": [.dj, .j, .ɯ]
        case "でぇ", "dhe": [.dj, .j, .e]
        case "でょ", "dho": [.dj, .j, .o]
        case "どぁ", "どゎ", "dhwa": [.dβ, .β, .a]
        case "どぃ", "dhwi": [.dβ, .β, .i]
        case "どぇ", "dhwe": [.dβ, .β, .e]
        case "どぉ", "dhwo": [.dβ, .β, .o]
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
        case "ら", "ra": [.ɾ, .a]
        case "り", "ri": [.ɾj, .i]
        case "る", "ru": [.ɾ, .ɯ]
        case "れ", "re": [.ɾ, .e]
        case "ろ", "ro": [.ɾ, .o]
        case "りゃ", "rya": [.ɾj, .ja, .a]
        case "りゅ", "ryu": [.ɾj, .j, .ɯ]
        case "りぇ", "rye": [.ɾj, .j, .e]
        case "りょ", "ryo": [.ɾj, .j, .o]
        case "るぁ", "るゎ", "rwa": [.ɾ, .β, .a]
        case "るぃ", "rwi": [.ɾ, .β, .i]
        case "るぇ", "rwe": [.ɾ, .β, .e]
        case "るぉ", "rwo": [.ɾ, .β, .o]
        case "わ", "wa": [.β, .a]
        case "うぃ", "wi", "whi": [.β, .i]
        case "うぇ", "we", "whe": [.β, .e]
        case "うぉ", "who": [.β, .o]
        case "ん", "n":
            switch nextPhoneme {
            case .p, .pj, .pjRes, .pβRes, .b, .bj, .m, .mj: [.m]
            case .ta, .tj, .tɕ, .tβ, .ts, .te, .to, .tɕRes, .tsRes,
                    .dza, .dʒ, .dzβ, .dze, .dzo, .n, .nj, .ɾ, .ɾj: [.n]
            case .ka, .kj, .kβ, .ke, .ko, .kjRes, .kβRes, .ga, .gj, .gβ, .ge, .go: [.ŋ]
            case .a, .sa, .ha: [.ã]
            case .i, .j, .ja, .ɕ, .ɕRes, .ç, .çRes: [.ĩ]
            case .ɯ, .β, .sβ, .sβRes, .ɸ, .ɸRes, .sokuon: [.ɯ̃]
            case .e, .se, .he: [.ẽ]
            case .o, .so, .ho: [.õ]
            default: [.ɴ]
            }
        case "nn": [.n]
        case "nm": [.m]
        case "ng": [.ŋ]
        case "n.": [.ɴ]
        case "ひ/", "hi/": [.çRes]
        case "ふ/", "hu/", "fu/": [.ɸRes]
        case "ぴ/", "pi/": [.pjRes]
        case "ぷ/", "pu/": [.pβRes]
        case "き/", "ki/": [.kjRes]
        case "く/", "ku/": [.kβRes]
        case "し/", "si/", "shi/": [.ɕRes]
        case "す/", "su/": [.sβRes]
        case "ち/", "ti/", "chi/": [.tɕRes]
        case "つ/", "tu/", "tsu/": [.tsRes]
        case "っ", "xtu", "_": [.sokuon]
        case "~a": [.ã]
        case "~i": [.ĩ]
        case "~u": [.ɯ̃]
        case "~e": [.ẽ]
        case "~o": [.õ]
        case "-a": [.haBreath]
        case "-i": [.hiBreath]
        case "-u": [.hɯBreath]
        case "-e": [.heBreath]
        case "-o": [.hoBreath]
        case "^a": [.aBreath]
        case "^i": [.iBreath]
        case "^u": [.ɯBreath]
        case "^e": [.eBreath]
        case "^o": [.oBreath]
        case ".": [.off]
        case ",": [.voiceless]
        default: []
        }
    }
    static func isJapaneseVowel(_ phonemes: [Phoneme]) -> Bool {
        phonemes.count == 1 && phonemes[0].isJapaneseVowel
    }
    
    static func firstVowel(_ phonemes: [Phoneme]) -> Self? {
        let vowel: Phoneme
        var phonemes = phonemes
        switch phonemes.last {
        case .a, .i, .ɯ, .e, .o, .ɴ, .sokuon, .off,
                .ã, .ĩ, .ɯ̃, .ẽ, .õ,
                .haBreath, .hiBreath, .hɯBreath, .heBreath, .hoBreath,
                .aBreath, .iBreath, .ɯBreath, .eBreath, .oBreath:
            vowel = phonemes.last!
            phonemes.removeLast()
        default:
            return nil
        }
        
        return switch phonemes.last {
        case .j, .ja, .β: phonemes.last!
        default: vowel
        }
    }
}
