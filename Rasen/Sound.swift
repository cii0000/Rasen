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
import struct Foundation.Data

struct Pitch: Hashable, Codable {
    var value = Rational(0)
}
extension Pitch {
    var octave: Int {
        Int((value / 12).rounded(.down))
    }
    var unison: Rational {
        value.mod(12)
    }
    var fq: Double {
        2 ** ((Double(value) - 57) / 12) * 440
    }
}
extension Pitch {
    static func pitch(fromFq fq: Double) -> Double {
        .log(fq / 440) / .log(2) * 12 + 57
    }
    init(octave: Int, lyricsUnison: LyricsUnison) {
        value = Rational(octave * 12) + Rational(lyricsUnison.unison)
    }
    init(octave: Int, step: LyricsUnison.Step,
         accidental: LyricsUnison.Accidental = .none) {
        
        self.init(octave: octave,
                  lyricsUnison: LyricsUnison(step, accidental))
    }
    func lyricsUnison(isSharp: Bool) -> LyricsUnison {
        LyricsUnison(unison: Int(unison.rounded()), isSharp: isSharp)
    }
    var octaveString: String {
        let octavePitch = value / 12
        let iPart = octavePitch.rounded(.down)
        let dPart = (octavePitch - iPart) * 12
        let dPartStr = String(format: "%02d", Int(dPart))
        if dPart.decimalPart == 0 {
            return "C\(iPart).\(dPartStr)"
        } else {
            let ddPart = dPart.decimalPart * 12
            let ddPartStr = ddPart.decimalPart == 0 ? String(format: "%02d", Int(ddPart)) : "\(ddPart.decimalPart)"
            return "C\(iPart).\(dPartStr).\(ddPartStr)"
        }
    }
}

enum MusicScaleType: Int32, Hashable, Codable, CaseIterable {
    case major, minor,
         hexaMajor, hexaMinor,
         pentaMajor, pentaMinor,
         dorian,
         wholeTone, chromatic,
         none
}
extension MusicScaleType: Protobuf {
    init(_ pb: PBMusicScaleType) throws {
        switch pb {
        case .major: self = .major
        case .minor: self = .minor
        case .hexaMajor: self = .hexaMajor
        case .hexaMinor: self = .hexaMinor
        case .pentaMajor: self = .pentaMajor
        case .pentaMinor: self = .pentaMinor
        case .dorian: self = .dorian
        case .wholeTone: self = .wholeTone
        case .chromatic: self = .chromatic
        case .aNone: self = .none
        case .UNRECOGNIZED: self = .none
        }
    }
    var pb: PBMusicScaleType {
        switch self {
        case .major: .major
        case .minor: .minor
        case .hexaMajor: .hexaMajor
        case .hexaMinor: .hexaMinor
        case .pentaMajor: .pentaMajor
        case .pentaMinor: .pentaMinor
        case .dorian: .dorian
        case .wholeTone: .wholeTone
        case .chromatic: .chromatic
        case .none: .aNone
        }
    }
}
extension MusicScaleType {
    private static let selfDic: [Set<Int>: Self] = {
        var n = [Set<Int>: Self]()
        n.reserveCapacity(allCases.count)
        for v in allCases {
            n[Set(v.unisons)] = v
        }
        return n
    } ()
    init?(pitchs: [Int]) {
        guard pitchs.count >= 3 else { return nil }
        
        for i in 0 ..< pitchs.count {
            let pitchIs = Set(pitchs.map { ($0 - pitchs[i]).mod(12) })
            if let n = Self.selfDic[pitchIs] {
                self = n
                return
            }
        }
        return nil
    }
    
    var unisons: [Int] {
        switch self {
        case .major: [0, 2, 4, 5, 7, 9, 11]
        case .minor: [0, 2, 3, 5, 7, 8, 10]
        case .hexaMajor: [0, 2, 4, 7, 9, 11]
        case .hexaMinor: [0, 3, 5, 7, 8, 10]
        case .pentaMajor: [0, 2, 4, 7, 9]
        case .pentaMinor: [0, 3, 5, 7, 10]
        case .dorian: [0, 2, 3, 5, 7, 9, 10]
        case .wholeTone: [0, 2, 4, 6, 8, 10]
        case .chromatic: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .none: []
        }
    }
    var name: String {
        switch self {
        case .major: "Major".localized
        case .minor: "Minor".localized
        case .hexaMajor: "Hexa Major".localized
        case .hexaMinor: "Hexa Minor".localized
        case .pentaMajor: "Penta Major".localized
        case .pentaMinor: "Penta Minor".localized
        case .dorian: "Dorian".localized
        case .wholeTone: "Whole Tone".localized
        case .chromatic: "Chromatic".localized
        case .none: ""
        }
    }
    var isMinor: Bool {
        switch self {
        case .minor, .hexaMinor, .pentaMinor: true
        default: false
        }
    }
}

struct Mel {
    static let f0 = 700.0
    static let m0 = 1127.01048033416
    private static let rf0 = 1 / f0, rm0 = 1 / m0
    static func mel(fromFq fq: Double) -> Double {
        m0 * .log(fq * rf0 + 1)
    }
    static func fq(fromMel mel: Double) -> Double {
        f0 * (.exp(mel * rm0) - 1)
    }
}

struct Pit: Codable, Hashable {
    var t = 0.0, pitch = 0.0, amp = 1.0
}
extension Pit {
    var smp: Double {
        get { Volume(amp: amp).smp }
        set { amp = Volume(smp: newValue).amp }
    }
}
extension Pit: Protobuf {
    init(_ pb: PBPit) throws {
        t = (try? pb.t.notInfiniteAndNAN()) ?? 0
        pitch = (try? pb.pitch.notInfiniteAndNAN()) ?? 0
        amp = ((try? pb.amp.notNaN()) ?? 1).clipped(min: 0, max: Volume.maxAmp)
    }
    var pb: PBPit {
        .with {
            $0.t = t
            $0.pitch = pitch
            $0.amp = amp
        }
    }
}

struct Pitbend: Codable, Hashable {
    var pits = [Pit]()
    
    init(_ pits: [Pit] = []) {
        self.pits = pits
    }
}
extension Pitbend: Protobuf {
    init(_ pb: PBPitbend) throws {
        pits = pb.pits.compactMap { try? Pit($0) }
            .sorted(by: { $0.t < $1.t })
    }
    var pb: PBPitbend {
        .with {
            $0.pits = pits.map { $0.pb }
        }
    }
}
extension Pitbend {
    static let enabledRecoilPitchDistance: Rational = 1
    
    init(recoilS0 s0: Double, s1: Double, s2: Double, s3: Double,
         y0: Double, y1: Double, y2: Double, y3: Double, ly: Double,
         v1Amp: Double) {
        self.init([.init(t: 0, pitch: y0, amp: 0.85),
                   .init(t: s0, pitch: y1, amp: 1.05),
                   .init(t: s1, pitch: y2, amp: 1.05),
                   .init(t: s2, pitch: y3, amp: 1),
                   .init(t: s3, pitch: 0, amp: v1Amp),
                   .init(t: 1, pitch: ly, amp: 0.5 * v1Amp)])
    }
    init(recoilS0 s0: Double, s1: Double,
         y0: Double, y1: Double, y2: Double, ly: Double) {
        self.init([.init(t: 0, pitch: y0, amp: 0.85),
                   .init(t: s0, pitch: y1, amp: 0.9),
                   .init(t: s1, pitch: y2, amp: 1),
                   .init(t: 1, pitch: ly, amp: 0.75)])
    }
    init(oneS0 s0: Double, s1: Double, y0: Double, y1: Double, ly: Double) {
        self.init([.init(t: 0, pitch: y0, amp: 0.95),
                   .init(t: s0, pitch: y1, amp: 1.05),
                   .init(t: s1, pitch: 0, amp: 1.1),
                   .init(t: 1, pitch: ly, amp: 0.75)])
    }
    init(oneS0 s0: Double, y0: Double, y1: Double, ly: Double) {
        self.init([.init(t: 0, pitch: y0, amp: 0.95),
                   .init(t: s0, pitch: y1, amp: 1.05),
                   .init(t: 1, pitch: ly, amp: 0.75)])
    }
    init(vibratoSYs sys: [Point], vibratoStartS vs: Double,
         s0: Double, y0: Double, ly: Double) {
        guard sys.count % 2 == 0 else { fatalError() }
        var pits = [Pit]()
        pits.append(.init(t: 0, pitch: y0, amp: 0.95))
        pits.append(.init(t: s0, pitch: 0, amp: 1.25))
        pits.append(.init(t: vs, pitch: 0, amp: 1))
        for v in sys {
            pits.append(.init(t: v.x, pitch: v.y, amp: 1))
        }
        pits[.last].pitch = 0
        pits.append(.init(t: 1, pitch: ly, amp: 0.5))
        self.init(pits)
    }
    init(isVibrato: Bool, duration: Double,
         fq: Double, isVowel: Bool, pitchScale psc: Double = 4,
         previousFq: Double?, nextFq: Double?) {
        let isStartVowel = previousFq == nil && isVowel
        let s0 = isStartVowel ? 0.1 : 0.075
        let maxLS = 1.0
        let y0 = isStartVowel ? -0.015 : -0.01
        let ly = -0.01
        if isVibrato {
            let vss = s0 + 0.075
            let vibratoCount = Int((duration / (1 / 6.0)).rounded())
            let vibratoAmp = 0.01
            var sys = [Point]()
            sys.reserveCapacity(vibratoCount * 2 + 2)
            if vibratoCount * 2 + 1 > 2 {
                for i in 2 ..< (vibratoCount * 2 + 1) {
                    let t = Double(i + 1) / Double(vibratoCount * 2 + 2)
                    sys.append(Point(vss + 0.95 * (1 - vss) * t * t,
                                     ((i % 2 == 0 ? vibratoAmp : -vibratoAmp) * psc) * t))
                }
            } else {
                sys.append(Point(0.5, 0))
            }
            sys.append(Point(0.95, 0))
            self.init(vibratoSYs: sys,
                      vibratoStartS: vss,
                      s0: s0,
                      y0: y0 * psc, ly: ly * psc)
        } else if duration < 0.15 {
            self.init(oneS0: 0.3,
                      y0: -0.05 / 12 * psc, y1: 0, ly: -0.15 / 12 * psc)
        } else if duration < 0.3, let previousFq, let nextFq,
                  fq > previousFq && fq > nextFq {
            self.init(oneS0: 0.3, s1: 0.7,
                      y0: -0.05 / 12 * psc, y1: 0, ly: -0.35 / 12 * psc)
        } else if duration < 0.3 {
            let lastY = nextFq == nil ? ly / 2 : ly
            self.init(recoilS0: s0, s1: isStartVowel ? 0.5 : 0.3,
                      y0: y0 * psc, y1: 0.01 * psc, y2: -0.005 * psc,
                      ly: lastY * psc)
        } else {
            let lastY = nextFq == nil ? ly / 2 : ly
            let v1Amp = isVibrato ? 0.75 : 0.85
            self.init(recoilS0: s0, s1: isStartVowel ? 0.5 : 0.3,
                      s2: 0.7, s3: 1 - 0.2 * maxLS,
                      y0: y0 * psc, y1: 0.01 * psc, y2: -0.005 * psc,
                      y3: 0.0025 * psc, ly: lastY * psc, v1Amp: v1Amp)
        }
    }
    
    func with(scale: Double) -> Self {
        .init(pits.map {
            .init(t: $0.t * scale, pitch: $0.pitch, amp: $0.amp)
        })
    }
    
    var withEnabledPitch: Self {
        pits.contains(where: { $0.pitch != 0 }) ? self : Self()
    }
    
    struct InterKey: Hashable, Codable, MonoInterpolatable {
        var pitch = 0.0, smp = 0.0
        
        static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
            Self(pitch: .linear(f0.pitch, f1.pitch, t: t),
                 smp: .linear(f0.smp, f1.smp, t: t))
        }
        static func firstSpline(_ f1: Self,
                                _ f2: Self, _ f3: Self, t: Double) -> Self {
            Self(pitch: .firstSpline(f1.pitch, f2.pitch, f3.pitch, t: t),
                 smp: .firstSpline(f1.smp, f2.smp, f3.smp, t: t))
        }
        static func spline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self, t: Double) -> Self {
            Self(pitch: .spline(f0.pitch, f1.pitch,
                                f2.pitch, f3.pitch, t: t),
                 smp: .spline(f0.smp, f1.smp,
                                    f2.smp, f3.smp, t: t))
        }
        static func lastSpline(_ f0: Self, _ f1: Self,
                               _ f2: Self, t: Double) -> Self {
            Self(pitch: .lastSpline(f0.pitch, f1.pitch, f2.pitch, t: t),
                 smp: .lastSpline(f0.smp, f1.smp,
                                        f2.smp, t: t))
        }
        static func firstMonospline(_ f1: Self,
                                _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
            Self(pitch: .firstMonospline(f1.pitch, f2.pitch, f3.pitch, with: ms),
                 smp: .firstMonospline(f1.smp, f2.smp,
                                         f3.smp, with: ms))
        }
        static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
            Self(pitch: .monospline(f0.pitch, f1.pitch,
                                f2.pitch, f3.pitch, with: ms),
                 smp: .monospline(f0.smp, f1.smp,
                                    f2.smp, f3.smp, with: ms))
        }
        static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) -> Self {
            Self(pitch: .lastMonospline(f0.pitch, f1.pitch, f2.pitch, with: ms),
                 smp: .lastMonospline(f0.smp, f1.smp,
                                        f2.smp, with: ms))
        }
    }
    
    var isEmpty: Bool {
        pits.isEmpty
    }
    var isEmptyPitch: Bool {
        !pits.contains(where: { $0.pitch != 0 })
    }
    var isEmptyAmp: Bool {
        !pits.contains(where: { $0.amp != 0 })
    }
    
    var interpolation: Interpolation<InterKey> {
        .init(keys: pits.map { .init(value: InterKey(pitch: $0.pitch,
                                                     smp: $0.smp),
                                     time: $0.t, type: .spline) },
              duration: pits.last?.t ?? 1)
    }
    func pit(atT t: Double) -> Pit {
        let interpolation = interpolation
        let pitch = interpolation
            .valueEnabledFirstLast(withT: t)?.pitch ?? 0
        let amp = Volume(smp: interpolation.valueEnabledFirstLast(withT: t)?.smp ?? 1).amp
        return .init(t: t, pitch: pitch, amp: amp)
    }
    func pitch(atT t: Double) -> Double {
        interpolation.valueEnabledFirstLast(withT: t)?.pitch ?? 0
    }
    func smp(atT t: Double) -> Double {
        (interpolation.valueEnabledFirstLast(withT: t)?.smp ?? 1)
            .clipped(min: 0, max: Volume.maxSmp)
    }
    func amp(atT t: Double) -> Double {
        Volume(smp: smp(atT: t)).amp
    }
    func fqScale(atT t: Double) -> Double {
        2 ** pitch(atT: t)
    }
    
    func line(fromSecPerSplitCount count: Int = 24,
              secDuration: Double,
              envelope: Envelope) -> Line? {
        guard !isEmpty else { return nil }
        let dSec = 1 / Double(count)
        let interpolation = interpolation
        var sec = 0.0, cs = [Line.Control]()
        while sec < secDuration {
            if let v = interpolation.monoValue(withTime: sec / secDuration) {
                cs.append(.init(point: .init(sec, v.pitch), pressure: v.smp))
            }
            sec += dSec
        }
        cs.append(.init(point: .init(secDuration,
                                     cs.last?.point.y ?? 0),
                        pressure: cs.last?.pressure ?? 0))
        cs.append(.init(point: .init(secDuration + envelope.release,
                                     cs.last?.point.y ?? 0),
                        pressure: 0))
        
        return Line(controls: cs)
    }
}

struct Noterial {
    
}

struct Note {
    var pitch = Rational(0)
    var pitbend = Pitbend()
    var beatRange = 0 ..< Rational(1, 4)
    var volumeAmp = Volume.mainAmp
    var pan = 0.0
    var tone = Tone()
    var lyric = ""
    
    var isBreath = false
    var isVibrato = false
    var isVowelReduction = false
}
extension Note: Protobuf {
    init(_ pb: PBNote) throws {
        pitch = (try? Rational(pb.pitch)) ?? 0
        pitbend = (try? Pitbend(pb.pitbend)) ?? .init()
        beatRange = (try? RationalRange(pb.beatRange).value) ?? 0 ..< Rational(1, 4)
        volumeAmp = ((try? pb.volumeAmp.notInfiniteAndNAN()) ?? 0)
            .clipped(min: Volume.minAmp, max: Volume.maxAmp)
        lyric = pb.lyric
        isBreath = pb.isBreath
        isVibrato = pb.isVibrato
    }
    var pb: PBNote {
        .with {
            $0.pitch = pitch.pb
            $0.pitbend = pitbend.pb
            $0.beatRange = RationalRange(value: beatRange).pb
            $0.volumeAmp = volumeAmp
            $0.lyric = lyric
            $0.isBreath = isBreath
            $0.isVibrato = isVibrato
        }
    }
}
extension Note: Hashable, Codable {}
extension Note {
    var isChord: Bool {
        volumeAmp == 0
    }
    var volume: Volume {
        get { .init(amp: volumeAmp) }
        set { volumeAmp = newValue.amp }
    }
    var roundedPitch: Int {
        Int(pitch.rounded())
    }
    var fq: Double {
        Pitch(value: pitch).fq
    }
    mutating func apply(toTempo: Rational, fromTempo: Rational) {
        let scale = toTempo / fromTempo
        let start = beatRange.start * scale
        let length = beatRange.length * scale
        beatRange = .init(start: start, length: length)
    }
    func isEqualOtherThanBeatRange(_ other: Self) -> Bool {
        pitch == other.pitch
        && pitbend == other.pitbend
        && volumeAmp == other.volumeAmp
        && lyric == other.lyric
        && isBreath == other.isBreath
        && isVibrato == other.isVibrato
    }
    
    var octavePitchString: String {
        Pitch(value: pitch).octaveString
    }
}

struct Chord: Hashable, Codable {
    enum ChordType: Hashable, Codable, CaseIterable, CustomStringConvertible {
        case major, suspended, minor, augmented, flatfive, diminish,
             octave, power, tritone
        
        var description: String {
            switch self {
            case .major: "Maj"
            case .suspended: "Sus"
            case .minor: "Min"
            case .augmented: "Aug"
            case .flatfive: "Fla"
            case .diminish: "Dim"
            case .octave: "Oct"
            case .power: "Pow"
            case .tritone: "Tri"
            }
        }
        var unisons: [Int] {
            switch self {
            case .major: [0, 4, 7]
            case .suspended: [0, 5, 7]
            case .minor: [0, 3, 7]
            case .augmented: [0, 4, 8]
            case .flatfive: [0, 4, 6]
            case .diminish: [0, 3, 6]
            case .octave: [0, 12]
            case .power: [0, 7]
            case .tritone: [0, 6]
            }
        }
        
        static var cases3Count: [Self] {
            [.major, .suspended, .minor, .augmented, .flatfive, .diminish]
        }
        static var cases2Count: [Self] {
            [.power]
        }
        static var cases1Count: [Self] {
            [.octave, .tritone]
        }
        var containsOctave: Bool {
            switch self {
            case .octave: true
            default: false
            }
        }
        var containsPower: Bool {
            switch self {
            case .major, .suspended, .minor: true
            default: false
            }
        }
        var containsTritone: Bool {
            switch self {
            case .flatfive, .diminish, .tritone: true
            default: false
            }
        }
        var inversionCount: Int {
            switch self {
            case .augmented, .tritone: 1
            case .power: 2
            default: 3
            }
        }
    }
    
    struct ChordTyper: Hashable, Codable, CustomStringConvertible {
        var type = ChordType.major
        var inversion = 0
        var index = 0
        
        init(_ type: ChordType, inversion: Int = 0, index: Int = 0) {
            self.type = type
            self.inversion = inversion
            self.index = index
        }
        
        var inversionUnisons: [Int] {
            Chord.loop(type.unisons, at: inversion)
        }
        
        var description: String {
            type.description + "\(inversion).\(index)"
        }
        var dispalyString: String {
            type.description + "\(inversion)".toSubscript
        }
    }
    
    var typers = [ChordTyper]()
    var ratios = [Int]()
    var cacophonyLevel = 0.0
}
extension Chord {
    var concordance: Double {
        .log2(cacophonyLevel)
        .clipped(min: -0.5, max: 3, newMin: 1, newMax: 0)
    }
    
    init?(pitchs: [Int]) {
        guard pitchs.count >= 2 else { return nil }
        let oPitchs = pitchs.sorted()
        let pitchs = oPitchs.map { $0 - oPitchs[0] }
        
        var typers = [ChordTyper]()
        for type in ChordType.cases3Count {
            for i in 0 ..< type.inversionCount {
                let vs = Self.loop(type.unisons, at: i)
                for j in 0 ..< pitchs.count - (type.unisons.count - 1) {
                    let nvs = vs.map { $0 + pitchs[j] }
                    if Set(pitchs).isSuperset(of: nvs) {
                        typers.append(.init(type, inversion: i, index: j))
                    }
                }
            }
        }
        for type in ChordType.cases2Count {
            for i in 0 ..< type.inversionCount {
                let vs = Self.loop(type.unisons, at: i)
                for j in 0 ..< pitchs.count - (type.unisons.count - 1) {
                    let nvs = vs.map { $0 + pitchs[j] }
                    if Set(pitchs).isSuperset(of: nvs) {
                        if !(typers.contains(where: { typer in typer.type.containsPower && Set(typer.inversionUnisons.map { $0 + pitchs[typer.index] }).isSuperset(of: nvs) })) {
                            
                            typers.append(.init(type, inversion: i,
                                                index: j))
                        }
                    }
                }
            }
        }
        for type in ChordType.cases1Count {
            let vs = type.unisons
            for j in 0 ..< pitchs.count - (type.unisons.count - 1) {
                let nvs = vs.map { $0 + pitchs[j] }
                if Set(pitchs).isSuperset(of: nvs) {
                    if !(typers.contains(where: { typer in (type == .octave ? typer.type.containsOctave : typer.type.containsTritone) && Set(typer.inversionUnisons.map { $0 + pitchs[typer.index] }).isSuperset(of: nvs) })) {
                        
                        typers.append(.init(type, inversion: 0, index: j))
                    }
                }
            }
        }
        
        guard !typers.isEmpty else { return nil }
        self.init(typers: typers)
    }
    
    static func loop(_ vs: [Int], at i: Int, inCount: Int = 12) -> [Int] {
        if i == 0 {
            return vs
        }
        var ni = i
        var nvs = [Int]()
        nvs.reserveCapacity(vs.count)
        nvs.append(0)
        ni = ni + 1 < vs.count ? ni + 1 : 0
        while ni != i {
            nvs.append(ni > i ? vs[ni] - vs[i] : inCount - vs[i] + vs[ni])
            ni = ni + 1 < vs.count ? ni + 1 : 0
        }
        return nvs
    }
    static func justIntonationRatios(at vs: [Int]) -> [Int] {
        let vs = vs.map { i in Self.justIntonationRatio5Limit(unison: i) }
        let ratios = Rational.toIntRatios(vs)
        let gcd = Int.gcd(ratios)
        return ratios.map { $0 / gcd }
    }
    
    static func splitedTimeRanges(timeRanges: [(Range<Rational>, Int)]) -> [Range<Rational>: Set<Int>] {
        
        enum SE: String, CustomStringConvertible {
            case start, end, endStart
            
            var description: String { rawValue }
        }
        var counts = [Rational: Int]()
        timeRanges.forEach {
            if let i = counts[$0.0.start] {
                counts[$0.0.start] = i + 1
            } else {
                counts[$0.0.start] = 1
            }
            if let i = counts[$0.0.end] {
                counts[$0.0.end] = i - 1
            } else {
                counts[$0.0.end] = -1
            }
        }
        var i = 0, ses = [(key: Rational, value: SE)]()
        for count in counts.sorted(by: { $0.key < $1.key }) {
            let oi = i
            i += count.value
            if i > 0 && oi == 0 {
                ses.append((count.key, .start))
            } else if i == 0 && oi > 0 {
                ses.append((count.key, .end))
            } else {
                ses.append((count.key, .endStart))
            }
        }
        
        var ranges = [Range<Rational>]()
        var ot: Rational?
        for (t, se) in ses {
            switch se {
            case .start:
                ot = t
            case .end:
                if let not = ot {
                    ranges.append(not ..< t)
                    ot = nil
                }
            case .endStart:
                if let not = ot {
                    ranges.append(not ..< t)
                    ot = nil
                }
                ot = t
            }
        }
        var nRanges = [Range<Rational>: Set<Int>]()
        for (timeRange, pitch) in timeRanges {
            for range in ranges {
                if timeRange.intersects(range) {
                    if nRanges[range] != nil {
                        nRanges[range]?.insert(pitch)
                    } else {
                        nRanges[range] = Set([pitch])
                    }
                }
            }
        }
        return nRanges
    }
    static func filterChords(_ notes: [Note]) -> [Note] {
        let tps = notes.map { ($0.beatRange, $0.roundedPitch) }
        let trs = splitedTimeRanges(timeRanges: tps)
        var npis = Set<Int>()
        for tr in trs {
            if Chord(pitchs: tr.value.sorted()) != nil {
                npis.formUnion(tr.value)
            }
        }
        return notes.filter { npis.contains($0.roundedPitch) }
    }
    static func chordIndexes(_ notes: [Note]) -> [Int] {
        let tps = notes.map { ($0.beatRange, $0.roundedPitch) }
        let trs = splitedTimeRanges(timeRanges: tps)
        var npis = Set<Int>()
        for tr in trs {
            if Chord(pitchs: tr.value.sorted()) != nil {
                npis.formUnion(tr.value)
            }
        }
        return notes.enumerated().compactMap {
            npis.contains(tps[$0.offset].1) ?
                $0.offset : nil
        }
    }
    
    static func approximationJustIntonation5Limit(pitch: Rational) -> Rational {
        switch pitch {
        case 1: 1 + .init(1173, 10000)
        case 2: 2 + .init(391, 10000)
        case 3: 3 + .init(1564, 10000)
        case 4: 4 + .init(-1369, 10000)
        case 5: 5 + .init(-196, 10000)
        case 6: 6 + .init(-978, 10000)
        case 7: 7 + .init(196, 10000)
        case 8: 8 + .init(1369, 10000)
        case 9: 9 + .init(-1564, 10000)
        case 10: 10 + .init(-391, 10000)
        case 11: 11 + .init(-1173, 10000)
        default: pitch
        }
    }
    static func justIntonationRatio5Limit(unison: Int) -> Rational {
        switch unison {
        case 1: .init(16, 15)
        case 2: .init(9, 8)
        case 3: .init(6, 5)
        case 4: .init(5, 4)
        case 5: .init(4, 3)
        case 6: .init(45, 32)
        case 7: .init(3, 2)
        case 8: .init(8, 5)
        case 9: .init(5, 3)
        case 10: .init(16, 9)
        case 11: .init(15, 8)
        default: 1
        }
    }
}
extension Chord: CustomStringConvertible {
    var description: String {
        typers.description
    }
}

struct Envelope: Hashable, Codable {
    var attack = 0.02, decay = 0.04,
        sustain = Volume(smp: 0.95).amp, release = 0.06
}
extension Envelope: Protobuf {
    init(_ pb: PBEnvelope) throws {
        attack = try pb.attack.notNaN().clipped(min: 0, max: 1)
        decay = try pb.decay.notNaN().clipped(min: 0, max: 1)
        sustain = try pb.sustain.notNaN().clipped(min: 0, max: 1)
        release = try pb.release.notNaN().clipped(min: 0, max: 1)
    }
    var pb: PBEnvelope {
        .with {
            $0.attack = attack
            $0.decay = decay
            $0.sustain = sustain
            $0.release = release
        }
    }
}

struct Overtone: Hashable, Codable {
    var evenScale = 1.0
    var oddScale = 1.0
}
extension Overtone: Protobuf {
    init(_ pb: PBOvertone) throws {
        evenScale = ((try? pb.evenScale.notNaN()) ?? 0).clipped(min: 0, max: 1)
        oddScale = ((try? pb.oddScale.notNaN()) ?? 0).clipped(min: 0, max: 1)
    }
    var pb: PBOvertone {
        .with {
            $0.evenScale = evenScale
            $0.oddScale = oddScale
        }
    }
}
extension Overtone {
    var isAll: Bool {
        evenScale == 1 && oddScale == 1
    }
    var isOne: Bool {
        evenScale == 0 && oddScale == 0
    }
    func scale(at i: Int) -> Double {
        i == 1 ? 1 : (i % 2 == 0 ? evenScale : oddScale)
    }
}
enum OvertoneType: Int, Hashable, Codable, CaseIterable {
    case evenScale, oddScale
}
extension Overtone {
    subscript(type: OvertoneType) -> Double {
        get {
            switch type {
            case .evenScale: evenScale
            case .oddScale: oddScale
            }
        }
        set {
            switch type {
            case .evenScale: evenScale = newValue
            case .oddScale: oddScale = newValue
            }
        }
    }
}

struct Tone: Hashable, Codable {
    var envelope = Envelope()
    var overtone = Overtone()
    var spectlope = Spectlope()
}
extension Tone: Protobuf {
    init(_ pb: PBTone) throws {
        envelope = (try? Envelope(pb.envelope)) ?? .init()
        overtone = (try? Overtone(pb.overtone)) ?? .init()
        spectlope = (try? Spectlope(pb.spectlope)) ?? .init()
    }
    var pb: PBTone {
        .with {
            $0.envelope = envelope.pb
            $0.overtone = overtone.pb
            $0.spectlope = spectlope.pb
        }
    }
}
extension Tone {
    func isEqualTimebend(_ other: Self) -> Bool {
        envelope == other.envelope
    }
    func isEqualWave(_ other: Self) -> Bool {
        overtone == other.overtone
        && spectlope == other.spectlope
    }
}

struct Wave: Codable, Hashable {
    var amp = 0.0, fq = 1.0, offsetTime = 0.0, phase = 0.0
}
extension Wave {
    func value(atT t: Double) -> Double {
        amp * .sin((t - offsetTime) * fq * 2 * .pi + phase)
    }
    func value120(atT t: Double, tempo: Double) -> Double {
        amp * .sin((t - offsetTime) * fq * (tempo / 120) * 2 * .pi + phase)
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
    func fqScale120(atLocalTime t: Double,
                            tempo: Double) -> Double {
        let t = t - beganTime
        guard t >= 0 else { return 1 }
        return 2 ** (waves.sum { $0.value120(atT: t, tempo: tempo) })
    }
    
    func value(atLocalTime t: Double) -> Double {
        let t = t - beganTime
        guard t >= 0 else { return 0 }
        return waves.sum { $0.value(atT: t) }
    }
    func value120(atLocalTime t: Double,
                            tempo: Double) -> Double {
        let t = t - beganTime
        guard t >= 0 else { return 0 }
        return waves.sum { $0.value120(atT: t, tempo: tempo) }
    }
    
    var isEmpty: Bool {
        waves.contains(where: { $0.isEmpty })
    }
}

struct Score {
    static let minOctave = -Rational(1), maxOctave = Rational(12)
    
    var notes = [Note]()
    var volumeAmp = Volume(smp: 0.5).amp
    var pan = 0.0
    var tone = Tone()
    var octave = Rational(4)
    var pitchRange = Rational(-12 * 3) ..< Rational(12 * 2)
}
extension Score: Protobuf {
    init(_ pb: PBScore) throws {
        notes = pb.notes.compactMap { try? Note($0) }
        volumeAmp = ((try? pb.volumeAmp.notNaN()) ?? 1)
            .clipped(min: 0, max: Volume.maxAmp)
        pan = pb.pan.clipped(min: -1, max: 1)
        tone = (try? Tone(pb.tone)) ?? Tone()
        octave = ((try? Rational(pb.octave)) ?? 4)
            .clipped(min: Self.minOctave, max: Self.maxOctave)
        pitchRange = (try? RationalRange(pb.pitchRange).value) ?? Rational(-3) ..< Rational(14)
        if pitchRange.isEmpty {
            pitchRange = pitchRange.lowerBound ..< (pitchRange.lowerBound + 1)
        }
    }
    var pb: PBScore {
        .with {
            $0.notes = notes.map { $0.pb }
            $0.volumeAmp = volumeAmp
            $0.pan = pan
            $0.tone = tone.pb
            $0.octave = octave.pb
            $0.pitchRange = RationalRange(value: pitchRange).pb
        }
    }
}
extension Score: Hashable, Codable {}
extension Score {
    var beatRange: Range<Rational>? {
        guard !notes.isEmpty else { return nil }
        let minV = notes.min(by: { $0.beatRange.lowerBound < $1.beatRange.lowerBound })!.beatRange.lowerBound
        let maxV = notes.max(by: { $0.beatRange.upperBound < $1.beatRange.upperBound })!.beatRange.upperBound
        return minV ..< maxV
    }
    
    var volume: Volume {
        get { Volume(amp: volumeAmp) }
        set { volumeAmp = newValue.amp }
    }
    var isVoice: Bool {
        notes.contains { !$0.lyric.isEmpty }
    }
    var octavePitch: Rational {
        octave * 12
    }
    var sortedNotes: [Note] {
        notes.sorted { $0.beatRange.start < $1.beatRange.start }
    }
    var scaleKey: Rational {
        get { octave.decimalPart * 12 }
        set { octave = Rational(octave.integralPart) + newValue }
    }
    var scaleType: MusicScaleType? {
        .init(pitchs: notes.map { Int($0.pitch.rounded()) })
    }
    
    func convertPitchToWorld(_ note: Note) -> Note {
        var note = note
        note.pitch += octavePitch
        return note
    }
    
    func pitchRange(fromScaleKey scaleKey: Int) -> Range<Rational> {
        let scalePitch = octavePitch + Rational(scaleKey)
        return pitchRange + scalePitch
    }
    mutating func replaceNoteLyrics(_ str: String,
                                    inBeatRange beatRange: Range<Rational>) {
        guard !str.isEmpty, str != "_" && str != "＿" else {
            for i in 0 ..< notes.count {
                notes[i].lyric = ""
            }
            return
        }
        
        var str = str.isAlphanumeric ? str : str.toHiragana()
        
        if str.count < notes.count {
            var nstr = "", i = str.startIndex
            for _ in 0 ..< notes.count {
                nstr.append(str[i])
                i = str.index(after: i)
                if i >= str.endIndex {
                    i = str.startIndex
                }
            }
            str = nstr
        }
        
        let nis = notes.enumerated().sorted {
            $0.element.beatRange.start < $1.element.beatRange.start
        }
        var si = str.startIndex
        var i = 0
        loop: while i < nis.count {
            let v = nis[i]
            let isD = (i + 1 < nis.count ? nis[i + 1].element.beatRange.start : beatRange.end) - v.element.beatRange.end > 0
            self.notes[v.offset].lyric = String(str[si])
            self.notes[v.offset].isBreath = false
            self.notes[v.offset].isVibrato = false
            self.notes[v.offset].isVowelReduction = false
            
            var nsi = str.index(after: si)
            guard nsi < str.endIndex else { break loop }
            
            let ss = ["ゃ", "ゅ", "ょ",
                      "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ゎ"]
            for s in ss {
                var isNone = false, nnsi = nsi
                for c in s {
                    if str[nnsi] == c {
                        nnsi = str.index(after: nnsi)
                        guard nnsi < str.endIndex else { break loop }
                    } else {
                        isNone = true
                        break
                    }
                }
                if !isNone {
                    for c in s {
                        self.notes[v.offset].lyric.append(c)
                        
                        nsi = str.index(after: nsi)
                        guard nsi < str.endIndex else { break loop }
                    }
                    if s.contains("’") && i - 1 >= 0 {
                        self.notes[nis[i - 1].offset].lyric += self.notes[v.offset].lyric
                        self.notes[v.offset].lyric = ""
                        nsi = str.index(after: nsi)
                        guard nsi < str.endIndex else { break loop }
                        si = nsi
                        continue loop
                    }
                    break
                }
            }
            while nsi < str.endIndex {
                if str[nsi] == " " || str[nsi] == "　" {
                    if !isD {
                        self.notes[v.offset].isBreath = true
                    }
                    
                    nsi = str.index(after: nsi)
                    guard nsi < str.endIndex else { break loop }
                } else if str[nsi] == "~" || str[nsi] == "〜" {
                    self.notes[v.offset].isVibrato = true
                    nsi = str.index(after: nsi)
                    guard nsi < str.endIndex else { break loop }
                } else if str[nsi] == "/" {
                    self.notes[v.offset].isVowelReduction = true
                    nsi = str.index(after: nsi)
                    guard nsi < str.endIndex else { break loop }
                } else if str[nsi] == "_" || str[nsi] == "＿" {
                    nsi = str.index(after: nsi)
                    guard nsi < str.endIndex else { break loop }
                } else {
                    break
                }
            }
            si = nsi
            guard si < str.endIndex else { break loop }
            
            i += 1
        }
    }
    
    func splitedTimeRanges(at indexes: [Int]) -> [Range<Rational>: Set<Int>] {
        var brps = [(Range<Rational>, Int)]()
        for (i, note) in notes.enumerated() {
            guard indexes.contains(i),
                  pitchRange.contains(note.pitch) else { continue }
            brps.append((note.beatRange, note.roundedPitch))
        }
        return Chord.splitedTimeRanges(timeRanges: brps)
    }
    
    func clippedNotes(inBeatRange: Range<Rational>,
                      localStartBeat: Rational) -> [Note] {
        clippedNotes(notes,
                     inBeatRange: inBeatRange,
                     localStartBeat: localStartBeat)
    }
    func clippedNotes(_ notes: [Note],
                      inBeatRange: Range<Rational>,
                      localStartBeat: Rational) -> [Note] {
        var nNotes = [Note]()
        let preBeat = inBeatRange.start
        let nextBeat = inBeatRange.end
        for note in notes {
            guard pitchRange.contains(note.pitch) else { continue }
            var beatRange = note.beatRange
            beatRange.start += inBeatRange.start + localStartBeat
            
            guard beatRange.end > preBeat
                    && beatRange.start < nextBeat
                    && note.volumeAmp >= Volume.minAmp
                    && note.volumeAmp <= Volume.maxAmp else { continue }
            
            if beatRange.start < preBeat {
                beatRange.length -= preBeat - beatRange.start
                beatRange.start = preBeat
            }
            if beatRange.end > nextBeat {
                beatRange.end = nextBeat
            }
            
            var nNote = note
            nNote.beatRange = beatRange
            nNotes.append(nNote)
        }
        return nNotes
    }
    static func clippedNotes(_ notes: [Note],
                             pitchRange: Range<Rational>,
                             inBeatRange: Range<Rational>,
                             localStartBeat: Rational,
                             isRepeartPitch: Bool = false,
                             isChord: Bool = false) -> [Note] {
        let st = inBeatRange.start, et = inBeatRange.end
        var nNotes = [Note]()
        for note in notes {
            guard !isChord || (isChord && note.isChord) else { continue }
            func append(pitch: Rational) {
                guard pitchRange.contains(pitch) else { return }
                
                var beatRange = note.beatRange
                beatRange.start += inBeatRange.start + localStartBeat
                
                guard beatRange.end > st
                        && beatRange.start < et
                        && note.volumeAmp >= Volume.minAmp
                        && note.volumeAmp <= Volume.maxAmp else { return }
                
                if beatRange.start < st {
                    beatRange.length -= st - beatRange.start
                    beatRange.start = st
                }
                if beatRange.end > et {
                    beatRange.end = et
                }
                
                var nNote = note
                nNote.beatRange = beatRange
                nNote.pitch = pitch
                nNotes.append(nNote)
            }
            if isRepeartPitch {
                var i = note.pitch
                while i >= pitchRange.lowerBound {
                    append(pitch: i)
                    i -= 12
                }
                i = note.pitch
                while i < pitchRange.upperBound {
                    append(pitch: i)
                    i += 12
                }
            } else {
                append(pitch: note.pitch)
            }
        }
        return nNotes
    }
    func pitchRange(inBeatRange beatRange: Range<Rational>,
                    beatDuration: Rational,
                    atStartBeat startBeat: Rational) -> ClosedRange<Rational>? {
        let notes = movedNotes(inBeatRange: beatRange,
                               beatDuration: beatDuration,
                               atStartBeat: startBeat)
        guard let minPitch = notes.min(by: { $0.pitch < $1.pitch })?.pitch,
              let maxPitch = notes.max(by: { $0.pitch < $1.pitch })?.pitch else { return nil }
        return minPitch ... maxPitch
    }
    
    func movedNotes(inBeatRange beatRange: Range<Rational>,
                    beatDuration: Rational,
                    atStartBeat startBeat: Rational) -> [Note] {
        guard volumeAmp > 0, !notes.isEmpty else { return [] }
        guard beatRange.length > 0 && beatRange.end > 0
                && beatRange.start < beatDuration else { return [] }
        var notes = [Note]()
        let preBeat = beatRange.start,
            nextBeat = min(beatRange.end, beatDuration)
        for note in notes {
            guard pitchRange.contains(note.pitch) else { continue }
            var note = convertPitchToWorld(note)
            guard note.beatRange.length > 0
                    && note.beatRange.end > preBeat
                    && note.beatRange.start < nextBeat
                    && note.pitch >= 0
                    && note.pitch < 256
                    && note.volumeAmp >= Volume.minAmp
                    && note.volumeAmp <= Volume.maxAmp else { continue }
            
            if note.beatRange.start < preBeat {
                note.beatRange.length -= preBeat - note.beatRange.start
                note.beatRange.start = preBeat
            }
            if note.beatRange.end > nextBeat {
                note.beatRange.end = nextBeat
            }
            note.beatRange.start += startBeat
            
            notes.append(note)
        }
        return notes
    }
}

struct Music {
    static let defaultTempo: Rational = 120
    static let minTempo = Rational(1, 4), maxTempo: Rational = 10000
    static let tempoRange = minTempo ... maxTempo
}
protocol TempoType {
    var tempo: Rational { get }
}
extension TempoType {
    static func sec(fromBeat beat: Rational, tempo: Rational) -> Rational {
        beat * 60 / tempo
    }
    static func beat(fromSec sec: Rational, tempo: Rational) -> Rational {
        sec * tempo / 60
    }
    static func beat(fromSec sec: Double,
                     tempo: Rational,
                     beatRate: Int,
                     rounded rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Rational {
        Rational(Int((sec * Double(tempo) / 60 * Double(beatRate)).rounded(rule)),
                 beatRate)
    }
    static func count(fromBeat beat: Rational,
                      tempo: Rational, frameRate: Int) -> Int {
        Int(beat * 60 / tempo * Rational(frameRate))
    }
    
    func sec(fromBeat beat: Rational) -> Rational {
        beat * 60 / tempo
    }
    func secRange(fromBeat beatRange: Range<Rational>) -> Range<Rational> {
        sec(fromBeat: beatRange.lowerBound)
        ..< sec(fromBeat: beatRange.upperBound)
    }
    func beat(fromSec sec: Rational) -> Rational {
        sec * tempo / 60
    }
    func beat(fromSec sec: Double,
              beatRate: Int,
              rounded rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Rational {
        Rational(Int((sec * Double(tempo) / 60 * Double(beatRate)).rounded(rule)),
                 beatRate)
    }
    func beat(fromSec sec: Double,
              interval: Rational,
              rounded rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Rational {
        let ii = interval.inversed!
        return Rational(Int((sec * Double(tempo) / 60 * Double(ii)).rounded(rule)))
        / ii
    }
    func count(fromBeat beat: Rational, frameRate: Int) -> Int {
        Int(Double(beat) * 60 / Double(tempo) * Double(frameRate))
    }
}

protocol TempoContainer: TempoType {
    var beatRange: Range<Rational> { get }
    var isPlaying: Bool { get }
}

struct Timetrack {
    var timeframes = [(position: Point, value: Timeframe)]()
}
extension Timetrack {
    var secDuration: Rational {
        timeframes.reduce(0) { max($0, $1.value.secRange.upperBound) }
    }
    static func + (lhs: Self, rhs: Self) -> Self {
        .init(timeframes: lhs.timeframes + rhs.timeframes)
    }
    static func += (lhs: inout Self, rhs: Self) {
        lhs.timeframes += rhs.timeframes
    }
    static func += (lhs: inout Self?, rhs: Self) {
        if lhs == nil {
            lhs = rhs
        } else {
            lhs?.timeframes += rhs.timeframes
        }
    }
    var isEmpty: Bool {
        timeframes.isEmpty
    }
    func moved(_ p: Point) -> Timetrack {
        .init(timeframes: timeframes.map { ($0.position + p, $0.value) })
    }
}

struct Volume: Hashable, Codable {
    static let minSmp = 0.0
    static let mainSmp = 1.0
    static let maxSmp = 1.25
    
    static let minAmp = 0.0
    static let mainAmp = 1.0
    static let maxAmp = Volume(smp: maxSmp).amp
    
    var amp = 0.0
}
extension Volume {
    /// amp = (.exp(40 * smp / 8.7) - 1) / (.exp(40 / 8.7) - 1)
    init(smp: Double) {
        amp = (.exp(4.5977011494 * smp) - 1) * 0.01017750808
    }
    var smp: Double {
        .log(1 + amp * 98.2558787375) * 0.2175
    }
    
    init(db: Double) {
        if db == 0 {
            amp = 1
        } else if db == -.infinity {
            amp = 0
        } else {
            amp = 10 ** (db / 20)
        }
    }
    var db: Double {
        20 * .log10(amp)
    }
    
    static func * (_ lhs: Self, _ rhs: Double) -> Self {
        .init(amp: lhs.amp * rhs)
    }
}

struct Audio: Hashable, Codable {
    static let defaultExportSampleRate = 44100.0
    static let defaultSampleRate = 65536.0
    static let defaultDftCount = 65536
    static let headroomDb = 1.0
    static let clippingVolume = Volume(db: -headroomDb)
    static let clippingAmp = clippingVolume.amp
    static let floatClippingAmp = Float(clippingVolume.amp)
    static let defaultReverb = 0.0
    
    var pcmData = Data()
}
extension Audio: Protobuf {
    init(_ pb: PBAudio) throws {
        pcmData = pb.pcmData
    }
    var pb: PBAudio {
        .with {
            $0.pcmData = pcmData
        }
    }
}
