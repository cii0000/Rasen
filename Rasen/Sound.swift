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
import struct Foundation.Data

//#if os(macOS) && os(iOS) && os(watchOS) && os(tvOS) && os(visionOS)
import Accelerate.vecLib.vDSP
//#elseif os(linux) && os(windows)
//#endif

struct LyricsUnison: Hashable, Codable {
    enum Step: Int32, Hashable, Codable, CaseIterable {
        case c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11
    }
    enum Accidental: Int32, Hashable, Codable, CaseIterable {
        case none = 0, flat = -1, sharp = 1
    }
    
    var step = Step.c, accidental = Accidental.none
    
    init(_ step: Step, _ accidental: Accidental = .none) {
        self.step = step
        self.accidental = accidental
    }
    init(unison: Int, isSharp: Bool) {
        switch unison {
        case 0: self = .init(.c)
        case 1: self = isSharp ? .init(.c, .sharp) : .init(.d, .flat)
        case 2: self = .init(.d)
        case 3: self = isSharp ? .init(.d, .sharp) : .init(.e, .flat)
        case 4: self = .init(.e)
        case 5: self = .init(.f)
        case 6: self = isSharp ? .init(.f, .sharp) : .init(.g, .flat)
        case 7: self = .init(.g)
        case 8: self = isSharp ? .init(.g, .sharp) : .init(.a, .flat)
        case 9: self = .init(.a)
        case 10: self = isSharp ? .init(.a, .sharp) : .init(.b, .flat)
        case 11: self = .init(.b)
        default: fatalError()
        }
    }
}
extension LyricsUnison.Step {
    var name: String {
        switch self {
        case .c: "C"
        case .d: "D"
        case .e: "E"
        case .f: "F"
        case .g: "G"
        case .a: "A"
        case .b: "B"
        }
    }
}
extension LyricsUnison.Accidental {
    var name: String {
        switch self {
        case .none: ""
        case .flat: "♭"
        case .sharp: "#"
        }
    }
}
extension LyricsUnison {
    var name: String {
        step.name + accidental.name
    }
    var unison: Int {
        (Int(step.rawValue) + Int(accidental.rawValue)).mod(12)
    }
}

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
        .exp2((Double(value) - 57) / 12) * 440
    }
}
extension Pitch {
    static func pitch(fromFq fq: Double) -> Double {
        .log2(fq / 440) * 12 + 57
    }
    static func fq(fromPitch pitch: Double) -> Double {
        .exp2((pitch - 57) / 12) * 440
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
    func octaveString(hidableDecimal: Bool = true, deltaPitch: Rational = 0) -> String {
        let octavePitch = value / 12
        let iPart = octavePitch.rounded(.down)        
        let dPart = (octavePitch - iPart) * 12
        let dPartStr = String(format: "%02d", Int(dPart))
        
        let deltaDPartStr: String
        if abs(deltaPitch) >= 12 {
            let deltaOctavePitch = abs(deltaPitch) / 12
            let deltaIPart = (deltaOctavePitch).rounded(.down)
            let deltaDPart = (deltaOctavePitch - deltaIPart) * 12
            deltaDPartStr = String(format: deltaPitch > 0 ? "+%d.%02d" : "-%d.%02d", Int(deltaIPart), Int(deltaDPart))
        } else {
            deltaDPartStr = String(format: deltaPitch > 0 ? "+%d" : "-%d", Int(abs(deltaPitch)))
        }
        let deltaStr: String
        if deltaPitch == 0 {
            deltaStr = ""
        } else if hidableDecimal && deltaPitch.decimalPart == 0 {
            deltaStr = " (\(deltaDPartStr))"
        } else {
            let ddPart = deltaPitch.decimalPart * 16
            let ddPartStr = ddPart.decimalPart == 0 ? String(format: "%d", Int(abs(ddPart))) : "\(abs(ddPart.decimalPart))"
            deltaStr = " (\(deltaDPartStr).\(ddPartStr))"
        }
        
        if hidableDecimal && dPart.decimalPart == 0 {
            return "\(iPart).\(dPartStr)" + deltaStr
        } else {
            let ddPart = dPart.decimalPart * 16
            let ddPartStr = ddPart.decimalPart == 0 ? String(format: "%d", Int(ddPart)) : "\(ddPart.decimalPart)"
            return "\(iPart).\(dPartStr).\(ddPartStr)" + deltaStr
        }
    }
}

enum MusicScaleType: Int32, Hashable, Codable, CaseIterable {
    case popular, hexaPopular, pentaPopular, wholeTone, chromatic
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
    init?(unisons: Set<Int>) {
        guard unisons.count >= 3, let n = Self.selfDic[unisons] else { return nil }
        self = n
    }
    
    var unisons: [Int] {
        switch self {
        case .popular: [0, 2, 4, 5, 7, 9, 11]
        case .hexaPopular: [0, 2, 4, 7, 9, 11]
        case .pentaPopular: [0, 2, 4, 7, 9]
        case .wholeTone: [0, 2, 4, 6, 8, 10]
        case .chromatic: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        }
    }
    var isPopular: Bool {
        switch self {
        case .popular, .hexaPopular, .pentaPopular: true
        default: false
        }
    }
    var name: String {
        switch self {
        case .popular: "Popular".localized
        case .hexaPopular: "Hexa Popular".localized
        case .pentaPopular: "Hexa Popular".localized
        case .wholeTone: "Whole Tone".localized
        case .chromatic: "Chromatic".localized
        }
    }
}
struct MusicScale {
    var type: MusicScaleType
    var unison: Int
}
extension MusicScale {
    init?(pitchs: [Int]) {
        guard pitchs.count >= 3 else { return nil }
        let pitchs = Set(pitchs).sorted()
        for i in 0 ..< pitchs.count {
            let unisons = Set(pitchs.map { ($0 - pitchs[i]).mod(12) })
            if let type = MusicScaleType(unisons: unisons) {
                self.type = type
                self.unison = pitchs[i]
                return
            }
        }
        return nil
    }
    var name: String {
        "\(LyricsUnison(unison: unison, isSharp: false).name) \(type) (\(unison))"
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

struct Stereo: Codable, Hashable {
    var volm = 0.0, pan = 0.0, id = UUID()
}
extension Stereo {
    var isEmpty: Bool {
        volm == 0
    }
    var amp: Double {
        Volm.amp(fromVolm: volm)
    }
    
    func with(volm: Double) -> Self {
        var v = self
        v.volm = volm
        return v
    }
    func with(pan: Double) -> Self {
        var v = self
        v.pan = pan
        return v
    }
    func with(id: UUID) -> Self {
        var v = self
        v.id = id
        return v
    }
    func multiply(volm: Double) -> Self {
        var v = self
        v.volm *= volm
        return v
    }
}
extension Stereo: Protobuf {
    init(_ pb: PBStereo) throws {
        volm = ((try? pb.volm.notNaN()) ?? 1).clipped(Volm.volmRange)
        pan = pb.pan.clipped(min: -1, max: 1)
        id = (try? .init(pb.id)) ?? .init()
    }
    var pb: PBStereo {
        .with {
            $0.volm = volm
            $0.pan = pan
            $0.id = id.pb
        }
    }
}
extension Stereo: MonoInterpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(volm: .linear(f0.volm, f1.volm, t: t),
              pan: .linear(f0.pan, f1.pan, t: t))
    }
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(volm: .firstSpline(f1.volm, f2.volm, f3.volm, t: t),
              pan: .firstSpline(f1.pan, f2.pan, f3.pan, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(volm: .spline(f0.volm, f1.volm, f2.volm, f3.volm, t: t),
              pan: .spline(f0.pan, f1.pan, f2.pan, f3.pan, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(volm: .lastSpline(f0.volm, f1.volm, f2.volm, t: t),
              pan: .lastSpline(f0.pan, f1.pan, f2.pan, t: t))
    }
    static func firstMonospline(_ f1: Self,
                            _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(volm: .firstMonospline(f1.volm, f2.volm, f3.volm, with: ms),
              pan: .firstMonospline(f1.pan, f2.pan, f3.pan, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(volm: .monospline(f0.volm, f1.volm, f2.volm, f3.volm, with: ms),
              pan: .monospline(f0.pan, f1.pan, f2.pan, f3.pan, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, with ms: Monospline) -> Self {
        .init(volm: .lastMonospline(f0.volm, f1.volm, f2.volm, with: ms),
              pan: .lastMonospline(f0.pan, f1.pan, f2.pan, with: ms))
    }
}

struct Overtone: Hashable, Codable {
    var evenAmp = 1.0, oddVolm = 1.0
}
extension Overtone {
    var isAll: Bool {
        evenAmp == 1 && oddVolm == 1
    }
    var isOne: Bool {
        evenAmp == 0 && oddVolm == 0
    }
    func volm(at i: Int) -> Double {
        i == 1 ? 1 : (i % 2 == 0 ? evenAmp : oddVolm)
    }
}
extension Overtone: Protobuf {
    init(_ pb: PBOvertone) throws {
        evenAmp = ((try? pb.evenAmp.notNaN()) ?? 0).clipped(min: 0, max: 1)
        oddVolm = ((try? pb.oddVolm.notNaN()) ?? 0).clipped(min: 0, max: 1)
    }
    var pb: PBOvertone {
        .with {
            $0.evenAmp = evenAmp
            $0.oddVolm = oddVolm
        }
    }
}
enum OvertoneType: Int, Hashable, Codable, CaseIterable {
    case evenAmp, oddVolm
}
extension Overtone {
    subscript(type: OvertoneType) -> Double {
        get {
            switch type {
            case .evenAmp: evenAmp
            case .oddVolm: oddVolm
            }
        }
        set {
            switch type {
            case .evenAmp: evenAmp = newValue
            case .oddVolm: oddVolm = newValue
            }
        }
    }
}
extension Overtone: MonoInterpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(evenAmp: .linear(f0.evenAmp, f1.evenAmp, t: t),
              oddVolm: .linear(f0.oddVolm, f1.oddVolm, t: t))
    }
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(evenAmp: .firstSpline(f1.evenAmp, f2.evenAmp, f3.evenAmp, t: t),
              oddVolm: .firstSpline(f1.oddVolm, f2.oddVolm, f3.oddVolm, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(evenAmp: .spline(f0.evenAmp, f1.evenAmp, f2.evenAmp, f3.evenAmp, t: t),
              oddVolm: .spline(f0.oddVolm, f1.oddVolm, f2.oddVolm, f3.oddVolm, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(evenAmp: .lastSpline(f0.evenAmp, f1.evenAmp, f2.evenAmp, t: t),
              oddVolm: .lastSpline(f0.oddVolm, f1.oddVolm, f2.oddVolm, t: t))
    }
    static func firstMonospline(_ f1: Self,
                                _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(evenAmp: .firstMonospline(f1.evenAmp, f2.evenAmp, f3.evenAmp, with: ms),
              oddVolm: .firstMonospline(f1.oddVolm, f2.oddVolm, f3.oddVolm, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(evenAmp: .monospline(f0.evenAmp, f1.evenAmp, f2.evenAmp, f3.evenAmp, with: ms),
              oddVolm: .monospline(f0.oddVolm, f1.oddVolm, f2.oddVolm, f3.oddVolm, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) -> Self {
        .init(evenAmp: .lastMonospline(f0.evenAmp, f1.evenAmp, f2.evenAmp, with: ms),
              oddVolm: .lastMonospline(f0.oddVolm, f1.oddVolm, f2.oddVolm, with: ms))
    }
}

struct Sprol: Hashable, Codable {
    var pitch = 0.0, volm = 0.0, noise = 0.0
}
extension Sprol: Protobuf {
    init(_ pb: PBSprol) throws {
        pitch = ((try? pb.pitch.notNaN()) ?? 0).clipped(Score.doublePitchRange)
        volm = ((try? pb.volm.notNaN()) ?? 0).clipped(min: 0, max: 1)
        noise = ((try? pb.noise.notNaN()) ?? 0).clipped(min: 0, max: 1)
    }
    var pb: PBSprol {
        .with {
            $0.pitch = pitch
            $0.volm = volm
            $0.noise = noise
        }
    }
}
extension Sprol {
    var overtonesVolm: Double {
        volm * (1 - noise)
    }
    var noiseVolm: Double {
        volm * noise
    }
    
    static func / (lhs: Self, rhs: Self) -> Self {
        .init(pitch: lhs.pitch - rhs.pitch,
              volm: rhs.volm == 0 ? 0 : lhs.volm / rhs.volm,
              noise: rhs.noise == 0 ? 0 : lhs.noise / rhs.noise)
    }
    static func * (lhs: Self, rhs: Self) -> Self {
        .init(pitch: lhs.pitch + rhs.pitch,
              volm: lhs.volm * rhs.volm,
              noise: lhs.noise * rhs.noise)
    }
    static func *= (lhs: inout Self, rhs: Self) {
        lhs = lhs * rhs
    }
    
    func clipped() -> Self {
        .init(pitch: pitch.clipped(Score.doublePitchRange),
              volm: volm.clipped(min: 0, max: 1),
              noise: noise.clipped(min: 0, max: 1))
    }
    mutating func clip() {
        self = clipped()
    }
}

struct Spectlope: Hashable, Codable {
    static func defaultSprols(isRandom: Bool = false) -> [Sprol] {
        [Sprol(pitch: 12 * 0, volm: 0, noise: 0),
         Sprol(pitch: 12 * 1.25, volm: 0.5, noise: 0),
         Sprol(pitch: 12 * 2.25, volm: !isRandom ? 1 : .random(in: 0.5 ... 1), noise: 0),
         Sprol(pitch: 12 * 6, volm: 0.5, noise: 0),
         Sprol(pitch: 12 * 7, volm: 0.5, noise: 0),
         Sprol(pitch: 12 * 7.25, volm: !isRandom ? 0.6 : .random(in: 0.5 ... 0.8), noise: 0),
         Sprol(pitch: 12 * 8.15, volm: !isRandom ? 0.6 : .random(in: 0.5 ... 0.8), noise: 0),
         Sprol(pitch: 12 * 10, volm: 0, noise: 0)]
    }
    
    var sprols = Self.defaultSprols()
}
extension Spectlope: Protobuf {
    init(_ pb: PBSpectlope) throws {
        sprols = pb.sprols.compactMap { try? .init($0) }
    }
    var pb: PBSpectlope {
        .with {
            $0.sprols = sprols.map { $0.pb }
        }
    }
}
extension Spectlope {
    init(pitchVolms: [Point]) {
        sprols = pitchVolms.map { .init(pitch: $0.x, volm: $0.y, noise: 0) }
    }
    init(noisePitchVolms: [Point]) {
        sprols = noisePitchVolms.map { .init(pitch: $0.x, volm: $0.y, noise: 1) }
    }
    static func random() -> Self {
        .init(sprols: Self.defaultSprols(isRandom: true))
    }
}
extension Spectlope {
    var isEmpty: Bool {
        sprols.isEmpty
    }
    var isEmptyVolm: Bool {
        isEmpty || sprols.allSatisfy { $0.volm == 0 }
    }
    var count: Int {
        sprols.count
    }
    var isFullNoise: Bool {
        sprols.allSatisfy { $0.noise == 1 }
    }
    var containsNoise: Bool {
        sprols.contains { $0.noise > 0 }
    }
    
    var maxFq: Double {
        let maxV = sprols.sorted { $0.pitch < $1.pitch }.last
        guard let maxV, maxV.volm == 0 else { return Score.maxFq }
        return Pitch.fq(fromPitch: maxV.pitch)
    }
    
    func normarized() -> Self {
        let maxVolm = sprols.maxValue { $0.volm } ?? 0
        let rMaxVolm = maxVolm == 0 ? 1 : 1 / maxVolm
        return .init(sprols: sprols.map {
            var n = $0
            n.volm *= rMaxVolm
            return n
        })
    }
    
    func sprol(atPitch pitch: Double, isClippedPitch: Bool = false) -> Sprol {
        guard !sprols.isEmpty else { return .init() }
        var prePitch = sprols.first!.pitch, preSprol = sprols.first!, maxSprol: Sprol?
        guard pitch >= prePitch else { return isClippedPitch ? sprols.first! : .init(pitch: pitch, volm: sprols.first!.volm, noise: sprols.first!.noise) }
        for sprol in sprols {
            let nextPitch = sprol.pitch, nextSprol = sprol
            let (nPrePitch, nNextPitch) = prePitch < nextPitch ?
            (prePitch, nextPitch) : (nextPitch, prePitch)
            if pitch >= nPrePitch && pitch < nNextPitch {
                let t = (pitch - nPrePitch) / (nNextPitch - nPrePitch)
                let nSprol = Sprol.linear(preSprol, nextSprol, t: t)
                if let nMaxSprol = maxSprol {
                    maxSprol?.volm = max(nMaxSprol.volm, nSprol.volm)
                    maxSprol?.noise = max(nMaxSprol.noise, nSprol.noise)
                } else {
                    maxSprol = nSprol
                }
            }
            prePitch = nextPitch
            preSprol = nextSprol
        }
        return maxSprol ?? (isClippedPitch ? sprols.last! : .init(pitch: pitch, volm: sprols.last!.volm, noise: sprols.last!.noise))
    }
    func sprol(atFq fq: Double) -> Sprol {
        sprol(atPitch: Pitch.pitch(fromFq: fq))
    }
    
    func volm(atPitch pitch: Double) -> Double {
        guard !sprols.isEmpty else { return 0 }
        var prePitch = sprols.first!.pitch, preVolm = sprols.first!.volm, maxVolm: Double?
        guard pitch >= prePitch else { return sprols.first!.volm }
        for sprol in sprols {
            let nextPitch = sprol.pitch, nextVolm = sprol.volm
            let (nPrePitch, nNextPitch) = prePitch < nextPitch ?
            (prePitch, nextPitch) : (nextPitch, prePitch)
            if pitch >= nPrePitch && pitch < nNextPitch {
                let t = (pitch - nPrePitch) / (nNextPitch - nPrePitch)
                let nVolm = Double.linear(preVolm, nextVolm, t: t)
                maxVolm = if let nMaxVolm = maxVolm {
                    max(nMaxVolm, nVolm)
                } else {
                    nVolm
                }
            }
            prePitch = nextPitch
            preVolm = nextVolm
        }
        return maxVolm ?? sprols.last!.volm
    }
    func volm(atFq fq: Double) -> Double {
        volm(atPitch: Pitch.pitch(fromFq: fq))
    }
    func amp(atFq fq: Double) -> Double {
        Volm.amp(fromVolm: volm(atPitch: Pitch.pitch(fromFq: fq)))
    }
    
    func noise(atPitch pitch: Double) -> Double {
        guard !sprols.isEmpty else { return 0 }
        var prePitch = sprols.first!.pitch, preNoise = sprols.first!.noise, maxNoise: Double?
        guard pitch >= prePitch else { return sprols.first!.noise }
        for sprol in sprols {
            let nextPitch = sprol.pitch, nextNoise = sprol.noise
            let (nPrePitch, nNextPitch) = prePitch < nextPitch ?
            (prePitch, nextPitch) : (nextPitch, prePitch)
            if pitch >= nPrePitch && pitch < nNextPitch {
                let t = (pitch - nPrePitch) / (nNextPitch - nPrePitch)
                let nNoise = Double.linear(preNoise, nextNoise, t: t)
                maxNoise = if let nMaxNoise = maxNoise {
                    max(nMaxNoise, nNoise)
                } else {
                    nNoise
                }
            }
            prePitch = nextPitch
            preNoise = nextNoise
        }
        return maxNoise ?? sprols.last!.noise
    }
    func noise(atFq fq: Double) -> Double {
        noise(atPitch: Pitch.pitch(fromFq: fq))
    }
    func noiseAmp(atFq fq: Double) -> Double {
        Volm.amp(fromVolm: noise(atPitch: Pitch.pitch(fromFq: fq)))
    }
    
    func overtonesVolm(atPitch pitch: Double) -> Double {
        sprol(atPitch: pitch).overtonesVolm
    }
    func overtonesVolm(atFq fq: Double) -> Double {
        overtonesVolm(atPitch: Pitch.pitch(fromFq: fq))
    }
    
    var sumVolm: Double {
        sprols.isEmpty ? 0 : (0 ... sprols.count).sum {
            let (prePitch, preVolm) = $0 == 0 ?
            (Score.doubleMinPitch, sprols[$0].volm) : (sprols[$0 - 1].pitch, sprols[$0 - 1].volm)
            let (nextPitch, nextVolm) = $0 == sprols.count ?
            (Score.doubleMaxPitch, sprols[$0 - 1].volm) : (sprols[$0].pitch, sprols[$0].volm)
            let dPitch = nextPitch - prePitch
            return (nextVolm + preVolm) * dPitch / 2
        }
    }
    func sumVolm(fromPitch pitch: Double) -> Double {
        let pitchSprol = sprol(atPitch: pitch)
        let fi = sprols.firstIndex(where: { $0.pitch > pitch }) ?? sprols.count - 1
        return sprols.isEmpty ? 0 : (fi ... sprols.count).sum {
            let preSprol = $0 == fi ? pitchSprol : sprols[$0 - 1]
            let dPitch = ($0 == sprols.count ? Score.doubleMaxPitch : sprols[$0].pitch) - preSprol.pitch
            return (($0 == sprols.count ? preSprol.volm : sprols[$0].volm) + preSprol.volm) * dPitch / 2
        }
    }
    func sumOvertonesVolm(fromPitch pitch: Double) -> Double {
        let pitchSprol = sprol(atPitch: pitch)
        let fi = sprols.firstIndex(where: { $0.pitch > pitch }) ?? sprols.count - 1
        return sprols.isEmpty ? 0 : (fi ... sprols.count).sum {
            let preSprol = $0 == fi ? pitchSprol : sprols[$0 - 1]
            let dPitch = ($0 == sprols.count ? Score.doubleMaxPitch : sprols[$0].pitch) - preSprol.pitch
            return (($0 == sprols.count ? preSprol.overtonesVolm : sprols[$0].overtonesVolm) + preSprol.overtonesVolm) * dPitch / 2
        }
    }
    var sumNoiseVolm: Double {
        sprols.isEmpty ? 0 : (0 ... sprols.count).sum {
            let (prePitch, preVolm) = $0 == 0 ?
            (Score.doubleMinPitch, sprols[$0].noiseVolm) : (sprols[$0 - 1].pitch, sprols[$0 - 1].noiseVolm)
            let (nextPitch, nextVolm) = $0 == sprols.count ?
            (Score.doubleMaxPitch, sprols[$0 - 1].noiseVolm) : (sprols[$0].pitch, sprols[$0].noiseVolm)
            let dPitch = nextPitch - prePitch
            return (nextVolm + preVolm) * dPitch / 2
        }
    }
    
    var sumNoise: Double {
        guard !sprols.isEmpty else { return 0 }
        
        let noiseVolms = vDSP.multiply(sprols.map { $0.volm }, sprols.map { $0.noise })
        var dPitchs = [Double](capacity: sprols.count + 1)
        var dVolms = [Double](capacity: sprols.count + 1)
        let dNoises = (0 ... sprols.count).map {
            let (prePitch, preNoise, preVolm) = $0 == 0 ?
            (Score.doubleMinPitch, noiseVolms[$0], sprols[$0].volm) :
            (sprols[$0 - 1].pitch, noiseVolms[$0 - 1], sprols[$0 - 1].volm)
            let (nextPitch, nextNoise, nextVolm) = $0 == sprols.count ?
            (Score.doubleMaxPitch, noiseVolms[$0 - 1], sprols[$0 - 1].volm) :
            (sprols[$0].pitch, noiseVolms[$0], sprols[$0].volm)
            let dPitch = nextPitch - prePitch
            dPitchs.append(dPitch)
            dVolms.append(nextVolm + preVolm)
            return nextNoise + preNoise
        }
        let allPitchs = vDSP.sum(vDSP.multiply(dPitchs, dVolms))
        if allPitchs == 0 { return 0 }
        return vDSP.sum(vDSP.multiply(dPitchs, dNoises)) / allPitchs
    }
    
    var formants: [Formant] {
        stride(from: 0, to: (sprols.count / 4) * 4, by: 4).map {
            .init(sprol0: sprols[$0], sprol1: sprols[$0 + 1],
                  sprol2: sprols[$0 + 2], sprol3: sprols[$0 + 3])
        }
    }
    var formantCount: Int {
        sprols.count / 4
    }
    
    func baseColor(lightness: Double = 85) -> Color {
        guard self != .init(), !sprols.isEmpty else { return .background }
        let minV = sprols.min { $0.volm < $1.volm }!
        let maxV = sprols.max { $0.volm < $1.volm }!
        let t = maxV.volm == 0 ? 0 : (maxV.volm - minV.volm) / maxV.volm
        let chroma = Double.linear(0, 60, t: t)
        let maxPitch = maxV.pitch
        let greenaPitch = Score.doubleMinPitch,
            bluePitch = 12.0 * 2, purplePitch = 12.0 * 4, redPitch = 12.0 * 6, orangePitch = 12.0 * 8,
            yellowPitch = Score.doubleMaxPitch
        return if maxPitch < bluePitch {
            .init(lightness: lightness, nearestChroma: chroma,
                  hue: maxPitch.clipped(min: greenaPitch, max: bluePitch,
                                        newMin: .pi2 * 0.625, newMax: .pi2 * 0.75))
        } else if maxPitch < purplePitch {
            .init(lightness: lightness, nearestChroma: chroma,
                  hue: maxPitch.clipped(min: bluePitch, max: purplePitch,
                                        newMin: .pi2 * 0.75, newMax: .pi2 * 0.875))
        } else if maxPitch < redPitch {
            .init(lightness: lightness, nearestChroma: chroma,
                  hue: maxPitch.clipped(min: purplePitch, max: redPitch,
                                        newMin: -.pi2 * 0.125, newMax: 0))
        } else if maxPitch < orangePitch {
            .init(lightness: lightness, nearestChroma: chroma,
                  hue: maxPitch.clipped(min: redPitch, max: orangePitch,
                                        newMin: 0, newMax: .pi2 * 0.125))
        } else {
            .init(lightness: lightness, nearestChroma: chroma,
                  hue: maxPitch.clipped(min: orangePitch, max: yellowPitch,
                                        newMin: .pi2 * 0.125, newMax: .pi2 * 0.25))
        }
    }
}
extension Sprol: MonoInterpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(pitch: .linear(f0.pitch, f1.pitch, t: t),
              volm: .linear(f0.volm, f1.volm, t: t),
              noise: .linear(f0.noise, f1.noise, t: t))
    }
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(pitch: .firstSpline(f1.pitch, f2.pitch, f3.pitch, t: t),
              volm: .firstSpline(f1.volm, f2.volm, f3.volm, t: t),
              noise: .firstSpline(f1.noise, f2.noise, f3.noise, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(pitch: .spline(f0.pitch, f1.pitch, f2.pitch, f3.pitch, t: t),
              volm: .spline(f0.volm, f1.volm, f2.volm, f3.volm, t: t),
              noise: .spline(f0.noise, f1.noise, f2.noise, f3.noise, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(pitch: .lastSpline(f0.pitch, f1.pitch, f2.pitch, t: t),
              volm: .lastSpline(f0.volm, f1.volm, f2.volm, t: t),
              noise: .lastSpline(f0.noise, f1.noise, f2.noise, t: t))
    }
    static func firstMonospline(_ f1: Self,
                                _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(pitch: .firstMonospline(f1.pitch, f2.pitch, f3.pitch, with: ms),
              volm: .firstMonospline(f1.volm, f2.volm, f3.volm, with: ms),
              noise: .firstMonospline(f1.noise, f2.noise, f3.noise, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(pitch: .monospline(f0.pitch, f1.pitch, f2.pitch, f3.pitch, with: ms),
              volm: .monospline(f0.volm, f1.volm, f2.volm, f3.volm, with: ms),
              noise: .monospline(f0.noise, f1.noise, f2.noise, f3.noise, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) -> Self {
        .init(pitch: .lastMonospline(f0.pitch, f1.pitch, f2.pitch, with: ms),
              volm: .lastMonospline(f0.volm, f1.volm, f2.volm, with: ms),
              noise: .lastMonospline(f0.noise, f1.noise, f2.noise, with: ms))
    }
}
extension Spectlope: MonoInterpolatable {
    func with(count: Int) -> Self {
        let sprols = sprols
        guard sprols.count != count else { return self }
        guard sprols.count < count else { fatalError() }
        guard !sprols.isEmpty else {
            return .init(sprols: .init(repeating: .init(), count: count))
        }
        guard sprols.count > 1 else {
            return .init(sprols: .init(repeating: sprols[0], count: count))
        }
        guard sprols.count > 2 else {
            return .init(sprols: count.range.map { i in
                let t = Double(i) / Double(count - 1)
                return .linear(sprols[0], sprols[1], t: t)
            })
        }
        
        var nSprols = sprols
        nSprols.reserveCapacity(count)
        
        var ds: [(Double, Int)] = (0 ..< (sprols.count - 1)).map {
            (sprols[$0].pitch.distance(sprols[$0 + 1].pitch), $0)
        }.sorted { $0.0 < $1.0 }
        
        for _ in 0 ..< (count - sprols.count) {
            let ld = ds[.last]
            nSprols.insert(.linear(nSprols[ld.1], nSprols[ld.1 + 1], t: 0.5), at: ld.1)
            ds.removeLast()
            var nd = ld
            nd.0 /= 2
            var isInsert = true
            for (i, d) in ds.enumerated() {
                if nd.0 < d.0 {
                    ds.insert(nd, at: i)
                    ds.insert(nd, at: i + 1)
                    isInsert = false
                    break
                }
            }
            if isInsert {
                ds.append(nd)
                ds.append(nd)
            }
            for (i, d) in ds.enumerated() {
                if d.1 > ld.1 {
                    ds[i].1 += 1
                }
            }
        }
        return .init(sprols: nSprols.sorted(by: { $0.pitch < $1.pitch }))
    }
    
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        let count = max(f0.sprols.count, f1.sprols.count)
        let l0 = f0.with(count: count)
        let l1 = f1.with(count: count)
        return .init(sprols: .linear(l0.sprols, l1.sprols, t: t))
    }
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self {
        let count = max(f1.sprols.count, f2.sprols.count, f3.sprols.count)
        let l1 = f1.with(count: count)
        let l2 = f2.with(count: count)
        let l3 = f3.with(count: count)
        return .init(sprols: .firstSpline(l1.sprols, l2.sprols, l3.sprols, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        let count = max(f0.sprols.count, f1.sprols.count, f2.sprols.count, f3.sprols.count)
        let l0 = f0.with(count: count)
        let l1 = f1.with(count: count)
        let l2 = f2.with(count: count)
        let l3 = f3.with(count: count)
        return .init(sprols: .spline(l0.sprols, l1.sprols, l2.sprols, l3.sprols, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        let count = max(f0.sprols.count, f1.sprols.count, f2.sprols.count)
        let l0 = f0.with(count: count)
        let l1 = f1.with(count: count)
        let l2 = f2.with(count: count)
        return .init(sprols: .lastSpline(l0.sprols, l1.sprols, l2.sprols, t: t))
    }
    static func firstMonospline(_ f1: Self,
                                _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        let count = max(f1.sprols.count, f2.sprols.count, f3.sprols.count)
        let l1 = f1.with(count: count)
        let l2 = f2.with(count: count)
        let l3 = f3.with(count: count)
        return .init(sprols: .firstMonospline(l1.sprols, l2.sprols, l3.sprols, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        let count = max(f0.sprols.count, f1.sprols.count, f2.sprols.count, f3.sprols.count)
        let l0 = f0.with(count: count)
        let l1 = f1.with(count: count)
        let l2 = f2.with(count: count)
        let l3 = f3.with(count: count)
        return .init(sprols: .monospline(l0.sprols, l1.sprols, l2.sprols, l3.sprols, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) -> Self {
        let count = max(f0.sprols.count, f1.sprols.count, f2.sprols.count)
        let l0 = f0.with(count: count)
        let l1 = f1.with(count: count)
        let l2 = f2.with(count: count)
        return .init(sprols: .lastMonospline(l0.sprols, l1.sprols, l2.sprols, with: ms))
    }
    
    static func / (lhs: Self, rhs: Self) -> Self {
        .init(sprols: Swift.min(lhs.count, rhs.count).range.map { lhs.sprols[$0] / rhs.sprols[$0] })
    }
    static func * (lhs: Self, rhs: Self) -> Self {
        .init(sprols: Swift.min(lhs.count, rhs.count).range.map { lhs.sprols[$0] * rhs.sprols[$0] })
    }
    static func *= (lhs: inout Self, rhs: Self) {
        lhs = lhs * rhs
    }
    
    func clipped() -> Self {
        .init(sprols: sprols.map { $0.clipped() })
    }
    mutating func clip() {
        self = clipped()
    }
}

struct Tone: Hashable, Codable {
    var overtone = Overtone()
    var spectlope = Spectlope()
    var id = UUID()
}
extension Tone: Protobuf {
    init(_ pb: PBTone) throws {
        overtone = (try? .init(pb.overtone)) ?? .init()
        spectlope = (try? .init(pb.spectlope)) ?? .init()
        id = (try? .init(pb.id)) ?? .init()
    }
    var pb: PBTone {
        .with {
            $0.overtone = overtone.pb
            $0.spectlope = spectlope.pb
            $0.id = id.pb
        }
    }
}
extension Tone {
    static func empty() -> Self {
        Self.init(overtone: .init(evenAmp: 0, oddVolm: 0),
                  spectlope: .init(sprols: [.init(pitch: 0, volm: 1, noise: 0)]))
    }
    static func minNoise() -> Self {
        Self.init(overtone: .init(evenAmp: 1, oddVolm: 1),
                  spectlope: .init(sprols: [Sprol(pitch: 12 * 1, volm: 0, noise: 1),
                                            Sprol(pitch: 12 * 2, volm: 1, noise: 1),
                                            Sprol(pitch: 12 * 3, volm: 1, noise: 1),
                                            Sprol(pitch: 12 * 4, volm: 0, noise: 1)]))
    }
    static func maxNoise() -> Self {
        Self.init(overtone: .init(evenAmp: 1, oddVolm: 1),
                  spectlope: .init(sprols: [Sprol(pitch: 12 * 5, volm: 0, noise: 1),
                                            Sprol(pitch: 12 * 6, volm: 0.5, noise: 1),
                                            Sprol(pitch: 12 * 9, volm: 1, noise: 1),
                                            Sprol(pitch: 12 * 10, volm: 0, noise: 1)]))
    }
    
    func with(id: UUID) -> Self {
        var v = self
        v.id = id
        return v
    }
    func with(spectlopeCount: Int) -> Self {
        .init(overtone: overtone, spectlope: spectlope.with(count: spectlopeCount), id: id)
    }
    var isDefault: Bool {
        spectlope == .init()
    }
    
    func baseColor(lightness: Double = 85) -> Color {
        spectlope.baseColor(lightness: lightness)
    }
}
extension Tone: MonoInterpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(overtone: .linear(f0.overtone, f1.overtone, t: t),
              spectlope: .linear(f0.spectlope, f1.spectlope, t: t))
    }
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(overtone: .firstSpline(f1.overtone, f2.overtone, f3.overtone, t: t),
              spectlope: .firstSpline(f1.spectlope, f2.spectlope, f3.spectlope, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(overtone: .spline(f0.overtone, f1.overtone, f2.overtone, f3.overtone, t: t),
              spectlope: .spline(f0.spectlope, f1.spectlope, f2.spectlope, f3.spectlope, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(overtone: .lastSpline(f0.overtone, f1.overtone, f2.overtone, t: t),
              spectlope: .lastSpline(f0.spectlope, f1.spectlope, f2.spectlope, t: t))
    }
    static func firstMonospline(_ f1: Self,
                                _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(overtone: .firstMonospline(f1.overtone, f2.overtone, f3.overtone, with: ms),
              spectlope: .firstMonospline(f1.spectlope, f2.spectlope, f3.spectlope, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(overtone: .monospline(f0.overtone, f1.overtone, f2.overtone, f3.overtone, with: ms),
              spectlope: .monospline(f0.spectlope, f1.spectlope, f2.spectlope, f3.spectlope, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) -> Self {
        .init(overtone: .lastMonospline(f0.overtone, f1.overtone, f2.overtone, with: ms),
              spectlope: .lastMonospline(f0.spectlope, f1.spectlope, f2.spectlope, with: ms))
    }
}

struct Pit: Codable, Hashable {
    var beat = Rational(0), pitch = Rational(0), stereo = Stereo(volm: 0.5), tone = Tone(), lyric = ""
}
extension Pit: Protobuf {
    init(_ pb: PBPit) throws {
        beat = (try? .init(pb.beat)) ?? 0
        pitch = (try? .init(pb.pitch)) ?? 0
        stereo = (try? .init(pb.stereo)) ?? .init()
        tone = (try? .init(pb.tone)) ?? .init()
        lyric = pb.lyric
    }
    var pb: PBPit {
        .with {
            $0.beat = beat.pb
            $0.pitch = pitch.pb
            $0.stereo = stereo.pb
            $0.tone = tone.pb
            $0.lyric = lyric
        }
    }
}
extension Pit {
    init(beat: Rational, pitch: Rational, volm: Double) {
        self.beat = beat
        self.pitch = pitch
        self.stereo = .init(volm: volm.clipped(Volm.volmRange))
    }
    
    func isEqualWithoutBeat(_ other: Self) -> Bool {
        pitch == other.pitch && stereo == other.stereo && tone == other.tone && lyric == other.lyric
    }
    var isLyric: Bool {
        !lyric.isEmpty && lyric != "[" && lyric != "]"
    }
}
enum PitIDType {
    case stereo, tone
}
extension Pit {
    subscript(_ type: PitIDType) -> UUID {
        switch type {
        case .stereo: stereo.id
        case .tone: tone.id
        }
    }
}

struct Reverb: Hashable, Codable, Sendable {
    var earlySec = 0.02
    var earlyVolm = 0.75
    var lateSec = 0.08
    var lateVolm = 0.5
    var releaseSec = 0.5
    var seedID = UUID(index: 2)
}
extension Reverb: Protobuf {
    init(_ pb: PBReverb) throws {
        earlySec = max(0, ((try? pb.earlySec.notNaN()) ?? 0))
        earlyVolm = ((try? pb.earlyVolm.notNaN()) ?? 0).clipped(min: 0, max: 1)
        lateSec = max(0, ((try? pb.lateSec.notNaN()) ?? 0))
        lateVolm = ((try? pb.lateVolm.notNaN()) ?? 0).clipped(min: 0, max: 1)
        releaseSec = max(0, ((try? pb.releaseSec.notNaN()) ?? 0))
        seedID = (try? .init(pb.seedID)) ?? .init()
    }
    var pb: PBReverb {
        .with {
            $0.earlySec = earlySec
            $0.earlyVolm = earlyVolm
            $0.lateSec = lateSec
            $0.lateVolm = lateVolm
            $0.releaseSec = releaseSec
            $0.seedID = seedID.pb
        }
    }
}
extension Reverb {
    static let empty = Self.init(earlySec: 0, earlyVolm: 0, lateSec: 0, lateVolm: 0, releaseSec: 0)
    
    var isEmpty: Bool {
        (earlySec == 0 && lateSec == 0 && releaseSec == 0) || (earlyVolm == 0 && lateVolm == 0)
    }
    
    var earlyLateSec: Double {
        earlySec + lateSec
    }
    var durSec: Double {
        earlySec + lateSec + releaseSec
    }
    func count(sampleRate: Double) -> Int {
        Int((min(durSec, 1000) * sampleRate).rounded(.up))
    }
    
    static let defaulrFIR0 = Self.init().aFir(sampleRate: Audio.defaultSampleRate, channel: 0)
    static let defaulrFIR1 = Self.init().aFir(sampleRate: Audio.defaultSampleRate, channel: 1)
    func fir(sampleRate: Double, channel: Int) -> [Double] {
        if self == .init() && sampleRate == Audio.defaultSampleRate {
            if channel == 0 {
                return Self.defaulrFIR0
            } else if channel == 1 {
                return Self.defaulrFIR1
            }
        }
        return aFir(sampleRate: sampleRate, channel: channel)
    }
    private func aFir(sampleRate: Double, channel: Int) -> [Double] {
        guard !isEmpty else { return [] }
        
        let durSec = durSec
        let count = Int((durSec * sampleRate).rounded(.up))
        var fir = [Double](repeating: 0, count: count)
        
        let seed = seedID.uInt64Values.value0
        var random = Random(seed: seed)
        
        let earlyLateSec = earlyLateSec
        let rSampleRate = 1 / sampleRate
        
        let xi = Int(earlySec * sampleRate).clipped(min: 0, max: count - 1)
        let scale = 100.0
        let siMin = Double(xi).squareRoot().clipped(min: 10, max: 5000.squareRoot(), newMin: 1, newMax: scale)
        
        var pan = false
        let ft1 = random.nextT()
        func update(i: Int) {
            let sec = Double(i) * rSampleRate
            let nScale = lateSec == 0 ? 0 : sec.clipped(min: earlySec, max: earlyLateSec, newMin: 1, newMax: 0)
            
            let volm = sec < earlyLateSec ? (1 - nScale).squared.clipped(min: earlySec, max: earlyLateSec, newMin: earlyVolm, newMax: lateVolm) :
            sec.clipped(min: earlyLateSec, max: durSec, newMin: lateVolm, newMax: 0)
            
            let t1 = random.nextT()
            let nPan = t1 * 2 - 1
            let nVolm = if sec >= earlyLateSec {
                if nPan < 0 {
                   channel == 0 ? volm : volm * (1 + nPan)
               } else {
                   channel == 0 ? volm * (1 - nPan) : volm
               }
            } else {
                if channel == 0 {
                    ft1 > 0.5 ? (pan ? volm : 0) : (pan ? 0 : volm)
                } else {
                    ft1 > 0.5 ? (pan ? 0 : volm) : (pan ? volm : 0)
                }
            }
            pan = !pan
            
            let t2 = random.nextT()
            let sign = t2 > 0.5 ? 1.0 : -1.0
            fir[i] = sign * Volm.amp(fromVolm: nVolm)
            * nScale.clipped(min: 1, max: 0, newMin: siMin, newMax: 1) / scale
        }
        
        let x = earlySec * 0.5 * sampleRate
        let y = earlyLateSec * sampleRate
        let a = x < 1 || y < 1 ? 1 : (y - x) / (y - 1)
        var na = 1.0, nx = earlySec * sampleRate
        while nx < y && x * na > 1 {
            let i = Int(nx).clipped(min: 0, max: count - 1)
            update(i: i)
            
            na *= a
            nx += x * na
        }
        let nxi = Int(nx).clipped(min: 0, max: count)
        for i in nxi ..< count {
            update(i: i)
        }
        fir[0] = 1
        return fir
    }
}

struct Envelope: Hashable, Codable {
    var attackSec = 0.0, decaySec = 0.0, sustainVolm = 1.0, releaseSec = 0.0
    var id = UUID()
}
extension Envelope: Protobuf {
    init(_ pb: PBEnvelope) throws {
        attackSec = max(0, ((try? pb.attackSec.notNaN()) ?? 0))
        decaySec = max(0, ((try? pb.decaySec.notNaN()) ?? 0))
        sustainVolm = ((try? pb.sustainVolm.notNaN()) ?? 0).clipped(min: 0, max: 1)
        releaseSec = max(0, ((try? pb.releaseSec.notNaN()) ?? 0))
        id = (try? .init(pb.id)) ?? .init()
    }
    var pb: PBEnvelope {
        .with {
            $0.attackSec = attackSec
            $0.decaySec = decaySec
            $0.sustainVolm = sustainVolm
            $0.releaseSec = releaseSec
            $0.id = id.pb
        }
    }
}

struct Note {
    var beatRange = 0 ..< Rational(1, 4)
    var pitch = Rational(0)
    var pits = [Pit()]
    var spectlopeHeight = Sheet.spectlopeHeight
    var id = UUID()
}
extension Note: Protobuf {
    init(_ pb: PBNote) throws {
        beatRange = (try? RationalRange(pb.beatRange).value) ?? 0 ..< Rational(1, 4)
        pitch = (try? Rational(pb.pitch)) ?? 0
        pits = pb.pits.compactMap { try? Pit($0) }.sorted(by: { $0.beat < $1.beat })
        if pits.isEmpty {
            pits = [Pit()]
        }
        spectlopeHeight = ((try? pb.spectlopeHeight.notNaN()) ?? 0)
            .clipped(min: Sheet.spectlopeHeight, max: Sheet.maxSpectlopeHeight)
        id = (try? UUID(pb.id)) ?? UUID()
    }
    var pb: PBNote {
        .with {
            $0.beatRange = RationalRange(value: beatRange).pb
            $0.pitch = pitch.pb
            $0.pits = pits.map { $0.pb }
            $0.spectlopeHeight = spectlopeHeight
            $0.id = id.pb
        }
    }
}
extension Note: Hashable, Codable {}
extension Note {
    var firstPit: Pit {
        pits.first!
    }
    var firstStereo: Stereo {
        firstPit.stereo
    }
    var firstTone: Tone {
        firstPit.tone
    }
    var firstPitch: Rational {
        pitch + pits[0].pitch
    }
    var firstRoundedPitch: Int {
        Int(firstPitch.rounded())
    }
    var firstPitResult: PitResult {
        .init(notePitch: pitch, pitch: .rational(firstPit.pitch), stereo: firstStereo,
              tone: firstTone, lyric: firstPit.lyric, id: id)
    }
    
    var noiseRatio: Double {
        if pits.count == 1 {
            let sumVolm = firstTone.spectlope.sumVolm
            return sumVolm == 0 ? 0 : firstTone.spectlope.sumNoiseVolm / sumVolm
        } else {
            let sumVolm = pits.sum { $0.tone.spectlope.sumVolm }
            return sumVolm == 0 ? 0 : pits.sum { $0.tone.spectlope.sumNoiseVolm } / sumVolm
        }
    }
    
    func pitsEqualSpectlopeCount() -> [Pit] {
        guard let count = pits.max(by: { $0.tone.spectlope.count < $1.tone.spectlope.count })?.tone.spectlope.count else { return [] }
        return pits.map {
            var pit = $0
            pit.tone.spectlope = pit.tone.spectlope.with(count: count)
            return pit
        }
    }
    
    var pitchRange: Range<Rational> {
        let minPitch = (pits.min(by: { $0.pitch < $1.pitch })?.pitch ?? 0) + pitch
        let maxPitch = (pits.max(by: { $0.pitch < $1.pitch })?.pitch ?? 0) + pitch
        return minPitch ..< maxPitch
    }
    
    struct ChordResult {
        struct Item {
            var beatRange: Range<Rational>, roundedPitch: Int
        }
        
        var items: [Item]
    }
    func chordResult(minBeatLength: Rational = .init(1, 8), fromTempo tempo: Rational) -> ChordResult? {
        guard !isOneOvertone && !isFullNoise else { return nil }
        return withRendable(tempo: tempo).chordResult(minBeatLength: minBeatLength)
    }
    private func chordResult(minBeatLength: Rational = .init(1, 8)) -> ChordResult? {
        if pits.count >= 2 {
            var ns = [ChordResult.Item]()
            var preBeat = beatRange.start, prePitch = Int((pitch + pits[0].pitch).rounded())
            var preVolm = pits[0].stereo.volm
            var prePit = pits[0]
            if preBeat < pits[0].beat + beatRange.start
                && prePit.tone.spectlope.sumNoise < 0.75
                && prePit.stereo.volm > 0.1 {
                ns.append(.init(beatRange: preBeat ..< pits[0].beat + beatRange.start,
                                roundedPitch: prePitch))
            }
            var isPreEqual = false
            for i in 1 ..< pits.count {
                let pit = pits[i]
                let pitch = Int((pitch + pit.pitch).rounded())
                let volm = pit.stereo.volm
                if pitch != prePitch {
                    let pPit = pits[i - 1]
                    let pBeat = pPit.beat + beatRange.start
                    if isPreEqual && preBeat < pBeat
                        && prePit.tone.spectlope.mid(pPit.tone.spectlope).sumNoise < 0.75
                        && prePit.stereo.volm.mid(pPit.stereo.volm) > 0.1 {
                        ns.append(.init(beatRange: preBeat ..< pBeat,
                                        roundedPitch: prePitch))
                    }
                    let beat = pit.beat + beatRange.start
                    preBeat = beat
                    prePitch = pitch
                    preVolm = volm
                    prePit = pit
                    
                    isPreEqual = false
                } else if volm != preVolm {
                    let beat = pit.beat + beatRange.start
                    if preBeat < beat
                        && prePit.tone.spectlope.mid(pit.tone.spectlope).sumNoise < 0.75
                        && preVolm.mid(volm) > 0.1 {
                        ns.append(.init(beatRange: preBeat ..< beat,
                                        roundedPitch: pitch))
                    }
                    preBeat = beat
                    prePitch = pitch
                    preVolm = volm
                    prePit = pit
                    
                    isPreEqual = false
                } else {
                    isPreEqual = true
                }
            }
            if preBeat < beatRange.end
                && prePit.tone.spectlope.sumNoise < 0.75
                && prePit.stereo.volm > 0.1 {
                ns.append(.init(beatRange: preBeat ..< beatRange.end,
                                roundedPitch: prePitch))
            }
            return .init(items: ns.filter { $0.beatRange.length >= minBeatLength })
        } else {
            return beatRange.length >= minBeatLength
            && firstTone.spectlope.sumNoise < 0.75
            && firstStereo.volm > 0.1 ?
                .init(items: [.init(beatRange: beatRange, roundedPitch: firstRoundedPitch)]) :
                nil
        }
    }
    
    func isEqualOtherThanBeatRange(_ other: Self) -> Bool {
        pitch == other.pitch
        && pits == other.pits
        && id == other.id
    }
    
    func pitbend(fromTempo tempo: Rational) -> Pitbend {
        .init(pits: pits, beatRange: beatRange, tempo: tempo)
    }
    
    enum ResultPitch: Hashable {
        case rational(Rational), real(Double)
        
        var doubleValue: Double {
            switch self {
            case .rational(let value): .init(value)
            case .real(let value): value
            }
        }
        func rationalValue(intervalScale: Rational) -> Rational {
            switch self {
            case .rational(let value): value.interval(scale: intervalScale)
            case .real(let value): .init(value, intervalScale: intervalScale)
            }
        }
    }
    struct PitResult: Hashable {
        var notePitch: Rational, pitch: ResultPitch, stereo: Stereo,
            tone: Tone, lyric: String, id: UUID
        
        var sumTone: Double {
            tone.spectlope.sumVolm
        }
    }
    func pitResult(atBeat beat: Double) -> PitResult {
        if pits.count == 1 || beat <= .init(pits[0].beat) {
            let pit = pits[0]
            return .init(notePitch: pitch, pitch: .rational(pit.pitch), stereo: pit.stereo,
                         tone: pit.tone, lyric: pit.lyric, id: id)
        } else if let pit = pits.last, beat >= .init(pit.beat) {
            return .init(notePitch: pitch, pitch: .rational(pit.pitch), stereo: pit.stereo,
                         tone: pit.tone, lyric: pit.lyric, id: id)
        }
        for pitI in 0 ..< pits.count - 1 {
            let pit = pits[pitI], nextPit = pits[pitI + 1]
            if beat >= .init(pit.beat) && beat < .init(nextPit.beat) && pit.isEqualWithoutBeat(nextPit) {
                return .init(notePitch: pitch, pitch: .rational(pit.pitch), stereo: pit.stereo,
                             tone: pit.tone, lyric: pit.lyric, id: id)
            }
        }
        
        let sec = beat * 60 / 120
        let pitbend = pitbend(fromTempo: 120)
        return .init(notePitch: pitch, pitch: .real(pitbend.pitch(atSec: sec) * 12),
                     stereo: pitbend.stereo(atSec: sec),
                     tone: .init(overtone: pitbend.overtone(atSec: sec),
                                 spectlope: pitbend.spectlope(atSec: sec),
                                 id: .init()), lyric: "",
                     id: id)
    }
    func tone(atBeat beat: Double) -> Tone {
        if pits.count == 1 || beat <= .init(pits[0].beat) {
            return pits[0].tone
        } else if let pit = pits.last, beat >= .init(pit.beat) {
            return pit.tone
        }
        for pitI in 0 ..< pits.count - 1 {
            let pit = pits[pitI], nextPit = pits[pitI + 1]
            if beat >= .init(pit.beat) && beat < .init(nextPit.beat) && pit.tone == nextPit.tone {
                return pit.tone
            }
        }
        
        let sec = beat * 60 / 120
        let pitbend = pitbend(fromTempo: 120)
        return .init(overtone: pitbend.overtone(atSec: sec),
                     spectlope: pitbend.spectlope(atSec: sec),
                     id: .init())
    }
    func normarizedPitResult(atBeat beat: Double) -> PitResult {
        let firstSpectlope = pits.first!.tone.spectlope
        let isEqualAllSpectlope = pits.allSatisfy { $0.tone.spectlope == firstSpectlope }
        if isEqualAllSpectlope {
            return pitResult(atBeat: .init(beat))
        } else {
            let maxSumVolm = pits.maxValue { $0.tone.spectlope.sumVolm } ?? 0
            var result = pitResult(atBeat: .init(beat))
            result.stereo.volm = (result.stereo.volm * (maxSumVolm == 0 ? 1 : result.sumTone / maxSumVolm))
                .clipped(Volm.volmRange)
            return result
        }
    }
    
    var isEmpty: Bool {
        pits.count == 1 && pits[0].beat == 0 && pits[0].pitch == 0
    }
    var isEmptyPitch: Bool {
        pits.allSatisfy { $0.pitch == 0 }
    }
    var isEmptyStereo: Bool {
        pits.allSatisfy { $0.stereo.isEmpty }
    }
    var isEmptyVolm: Bool {
        pits.allSatisfy { $0.stereo.volm == 0 }
    }
    var isEmptyPan: Bool {
        pits.allSatisfy { $0.stereo.pan == 0 }
    }
    var isDefaultTone: Bool {
        pits.allSatisfy { $0.tone.isDefault }
    }
    var isOneOvertone: Bool {
        pits.allSatisfy { $0.tone.overtone.isOne }
    }
    var containsNoise: Bool {
        pits.contains(where: { $0.tone.spectlope.sprols.contains(where: { $0.noise > 0 }) })
    }
    var containsNoOneEven: Bool {
        pits.contains(where: { $0.tone.overtone.evenAmp != 1 })
    }
    var isFullNoise: Bool {
        pits.allSatisfy { $0.tone.spectlope.isFullNoise }
    }
    
    var isSimpleLyric: Bool {
        isDefaultTone && pits.contains(where: { !$0.lyric.isEmpty })
    }
    var isRendableFromLyric: Bool {
        !isDefaultTone && pits.contains(where: { !$0.lyric.isEmpty })
    }
    func withRendable(tempo: Rational) -> Self {
        guard isSimpleLyric else { return self }
        var n = self, i = 0, oldTone = n.pits[0].tone
        while i < n.pits.count {
            if n.pits[i].isLyric {
                i = n.replace(lyric: n.pits[i].lyric, at: i, tempo: tempo, isUpdateNext: false)
                oldTone = n.pits[i].tone
            } else {
                n.pits[i].tone = oldTone
            }
            i += 1
        }
        return n
    }
    var withSimpleLyric: Self {
        var n = self
        var nPits = [Pit](capacity: pits.count)
        let oPits = pits.filter { $0.isLyric }
        var prePit: Pit?
        for pit in oPits {
            if let prePitch = prePit?.pitch, pit.pitch != prePitch {
                var nPit = pit
                nPit.pitch = prePitch
                nPit.lyric = ""
                nPit.tone = .init()
                nPits.append(nPit)
            }
            var pit = pit
            pit.tone = .init()
            nPits.append(pit)
            prePit = pit
        }
        if nPits.isEmpty {
            n.pits = [n.pits[0]]
        }
        n.pits = nPits
        
        let dBeat = nPits[0].beat
        if dBeat > 0 {
            n.beatRange.start += dBeat
            n.beatRange.length -= dBeat
            n.pits = n.pits.map {
                var nPit = $0
                nPit.beat -= dBeat
                return nPit
            }
        }
        
        return n
    }
}
extension Note {
    private static func pitsFrom(recoilBeat0 beat0: Rational, beat1: Rational,
                                 beat2: Rational, beat3: Rational, lastBeat: Rational,
                                 pitch0: Rational, pitch1: Rational, pitch2: Rational,
                                 pitch3: Rational, lastPitch: Rational,
                                 v1Volm: Double) -> [Pit] {
        [.init(beat: 0, pitch: pitch0, volm: 0.95),
         .init(beat: beat0, pitch: pitch1, volm: 1),
         .init(beat: beat1, pitch: pitch2, volm: 1),
         .init(beat: beat2, pitch: pitch3, volm: 1),
         .init(beat: beat3, pitch: 0, volm: v1Volm),
         .init(beat: lastBeat, pitch: lastPitch, volm: 0.9 * v1Volm)]
    }
    private static func pitsFrom(recoilBeat0 beat0: Rational, beat1: Rational, lastBeat: Rational,
                                 pitch0: Rational, pitch1: Rational,
                                 pitch2: Rational, lastPitch: Rational) -> [Pit] {
        [.init(beat: 0, pitch: pitch0, volm: 0.95),
         .init(beat: beat0, pitch: pitch1, volm: 0.975),
         .init(beat: beat1, pitch: pitch2, volm: 1),
         .init(beat: lastBeat, pitch: lastPitch, volm: 0.9)]
    }
    private static func pitsFrom(oneBeat0 beat0: Rational, beat1: Rational, lastBeat: Rational,
                                 pitch0: Rational, pitch1: Rational, lastPitch: Rational) -> [Pit] {
        [.init(beat: 0, pitch: pitch0, volm: 0.975),
         .init(beat: beat0, pitch: pitch1, volm: 1),
         .init(beat: beat1, pitch: 0, volm: 1),
         .init(beat: lastBeat, pitch: lastPitch, volm: 0.9)]
    }
    private static func pitsFrom(oneBeat0 beat0: Rational,  lastBeat: Rational,
                                 pitch0: Rational, pitch1: Rational, lastPitch: Rational) -> [Pit] {
        [.init(beat: 0, pitch: pitch0, volm: 0.975),
         .init(beat: beat0, pitch: pitch1, volm: 1),
         .init(beat: lastBeat, pitch: lastPitch, volm: 0.9)]
    }
    private static func pitsFrom(vibratoBeatPitchs bps: [(beat: Rational, pitch: Rational)],
                                 vibratoStartBeat vBeat: Rational,
                                 beat0: Rational,  lastBeat: Rational,
                                 pitch0: Rational, lastPitch: Rational) -> [Pit] {
        guard bps.count % 2 == 0 else { fatalError() }
        var pits = [Pit]()
        pits.append(.init(beat: 0, pitch: pitch0, volm: 0.975))
        pits.append(.init(beat: beat0, pitch: 0, volm: 1))
        pits.append(.init(beat: vBeat, pitch: 0, volm: 1))
        for bp in bps {
            pits.append(.init(beat: bp.beat, pitch: bp.pitch, volm: 1))
        }
        pits[.last].pitch = 0
        pits.append(.init(beat: lastBeat, pitch: lastPitch, volm: 0.8))
        return pits
    }
    private static func pitsFrom(durBeat: Rational, tempo: Rational,
                                 isVibrato: Bool, isVowel: Bool,
                                 fq: Double, previousFq: Double?, nextFq: Double?) -> [Pit] {
        let durSec = Double(Score.sec(fromBeat: durBeat, tempo: tempo))
        func beat(fromT t: Double) -> Rational {
            Score.beat(fromSec: durSec * t, tempo: tempo, beatRate: Keyframe.defaultFrameRate)
        }
        let isStartVowel = previousFq == nil && isVowel
        let beat0 = beat(fromT: isStartVowel ? 0.1 : 0.075)
        let pitch0 = isStartVowel ? -Rational(3, 4) : -Rational(1, 2)
        let lastBeat = beat(fromT: 1)
        let lastPitch = -Rational(1, 2)
        if isVibrato {
            let vst = isStartVowel ? 0.175 : 0.15
            let vibratoCount = Int((durSec / (1 / 6.0)).rounded()) * 2 + 1
            let vibratoPitch = Rational(1, 2)
            var sys = [(beat: Rational, pitch: Rational)]()
            sys.reserveCapacity(vibratoCount + 1)
            if vibratoCount > 2 {
                for i in 2 ..< vibratoCount {
                    let t = Double(i + 1) / Double(vibratoCount + 1)
                    sys.append((beat(fromT: vst + 0.95 * (1 - vst) * t * t),
                                (i % 2 == 0 ? vibratoPitch : -vibratoPitch)
                                * (i < vibratoCount / 2 ? Rational(1, 2) : 1)))
                }
            } else {
                sys.append((beat(fromT: 0.5), 0))
            }
            sys.append((beat(fromT: 0.95), 0))
            return Self.pitsFrom(vibratoBeatPitchs: sys,  vibratoStartBeat: beat(fromT: vst),
                                 beat0: beat0, lastBeat: lastBeat,
                                 pitch0: pitch0, lastPitch: lastPitch)
        } else if durSec < 0.15 {
            return Self.pitsFrom(oneBeat0: beat(fromT: 0.3), lastBeat: lastBeat,
                      pitch0: -Rational(1, 4), pitch1: 0, lastPitch: -Rational(1, 2))
        } else if durSec < 0.3, let previousFq, let nextFq, fq > previousFq && fq > nextFq {
            return Self.pitsFrom(oneBeat0: beat(fromT: 0.3), beat1: beat(fromT: 0.7), lastBeat: lastBeat,
                      pitch0: -Rational(1, 4), pitch1: 0, lastPitch: -Rational(5, 4))
        } else if durSec < 0.3 {
            return Self.pitsFrom(recoilBeat0: beat0, beat1: beat(fromT: isStartVowel ? 0.5 : 0.3), lastBeat: lastBeat,
                      pitch0: pitch0, pitch1: Rational(1, 2), pitch2: -Rational(1, 4),
                      lastPitch: nextFq == nil ? lastPitch / 2 : lastPitch)
        } else {
            return Self.pitsFrom(recoilBeat0: beat0, beat1: beat(fromT: isStartVowel ? 0.5 : 0.3),
                                 beat2: beat(fromT: 0.7), beat3: beat(fromT: 0.8), lastBeat: lastBeat,
                                 pitch0: pitch0, pitch1: Rational(1, 2),
                                 pitch2: -Rational(1, 4), pitch3: Rational(1, 4),
                                 lastPitch: nextFq == nil ? lastPitch / 2 : lastPitch,
                                 v1Volm: isVibrato ? 0.9 : 0.95)
        }
    }
}

struct Chord: Hashable, Codable {
    enum ChordType: Int, Hashable, Codable, CaseIterable, CustomStringConvertible {
        case octave, power, major3, major, suspended, minor, minor3, augmented, flatfive,
             wholeTone, semitone,
             diminish, tritone
        
        var description: String {
            switch self {
            case .octave: "Oct"
            case .power: "Pow"
            case .major: "Maj"
            case .major3: "Maj3"
            case .suspended: "Sus"
            case .minor: "Min"
            case .minor3: "Min3"
            case .augmented: "Aug"
            case .flatfive: "Fla"
            case .wholeTone: "Who"
            case .semitone: "Sem"
            case .diminish: "Dim"
            case .tritone: "Tri"
            }
        }
        var unisons: [Int] {
            switch self {
            case .octave: [0]
            case .power: [0, 7]
            case .major3: [0, 4]
            case .major: [0, 4, 7]
            case .suspended: [0, 5, 7]
            case .minor: [0, 3, 7]
            case .minor3: [0, 3]
            case .augmented: [0, 4, 8]
            case .flatfive: [0, 4, 6]
            case .wholeTone: [0, 2]
            case .semitone: [0, 1]
            case .diminish: [0, 3, 6]
            case .tritone: [0, 6]
            }
        }
        
        static var cases3Count: [Self] {
            [.major, .suspended, .minor, .augmented, .flatfive, .diminish]
        }
        static var cases2Count: [Self] {
            [.power, .major3, .minor3, .wholeTone, .semitone]
        }
        static var cases1Count: [Self] {
            [.tritone]
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
            case .augmented, .tritone, .octave: 1
            case .power, .major3, .minor3, .wholeTone, .semitone: 2
            default: 3
            }
        }
    }
    
    struct ChordTyper: Hashable, Codable, CustomStringConvertible {
        var type = ChordType.major
        var mainUnison = 0
        var unisons = Set<Int>()
        
        init(_ type: ChordType, unison: Int = 0) {
            self.type = type
            self.mainUnison = unison
            unisons = Set(type.unisons.map { ($0 + unison).mod(12) })
        }
        
        var description: String {
            type.description + "\(mainUnison)"
        }
    }
    
    var typers = [ChordTyper]()
}
extension Chord {
    init?(pitchs: [Int]) {
        let mods = pitchs.map { $0.mod(12) }
        let unisons = Set(mods).sorted()
        guard unisons.count >= 2 else {
            if unisons.count == 1 && pitchs.count >= 2 {
                self.init(typers: [.init(.octave, unison: unisons[0])])
                return
            }
            return nil
        }
        
        let unisonsSet = Set(unisons)
        
        var typers = [ChordTyper]()
        
        for type in ChordType.cases3Count {
            for j in 0 ..< unisons.count {
                let unison = unisons[j]
                let nUnisons = type.unisons.map { ($0 + unison).mod(12) }
                if unisonsSet.isSuperset(of: nUnisons) {
                    typers.append(.init(type, unison: unison))
                    if type == .augmented { break }
                }
            }
        }
        
        for type in ChordType.cases2Count {
            for j in 0 ..< unisons.count {
                let unison = unisons[j]
                let nUnisons = type.unisons.map { ($0 + unison).mod(12) }
                if unisonsSet.isSuperset(of: nUnisons) {
                    let nTyper = ChordTyper(type, unison: unison)
                    if !typers.contains(where: { $0.unisons.isSuperset(of: nTyper.unisons) }) {
                        typers.append(nTyper)
                    }
                }
            }
        }
        
        for type in ChordType.cases1Count {
            for j in 0 ..< unisons.count {
                let unison = unisons[j]
                let nUnisons = type.unisons.map { ($0 + unison).mod(12) }
                if unisonsSet.isSuperset(of: nUnisons) {
                    let nTyper = ChordTyper(type, unison: unison)
                    if !typers.contains(where: { $0.unisons.isSuperset(of: nTyper.unisons) }) {
                        typers.append(nTyper)
                    }
                }
            }
        }
        
        var filledUnisons = Set<Int>(), octaveUnisons = Set<Int>()
        for unison in mods {
            if filledUnisons.contains(unison) {
                octaveUnisons.insert(unison)
            } else {
                filledUnisons.insert(unison)
            }
        }
        for unison in octaveUnisons.sorted() {
            typers.append(.init(.octave, unison: unison))
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
    
    static func approximationJustIntonation5Limit(pitch: Rational) -> Rational {
        let intPitch = (pitch / 12).rounded(.down)
        return approximationJustIntonation5Limit(unison: pitch.mod(12)) + intPitch * 12
    }
    static func approximationJustIntonation5Limit(unison: Rational) -> Rational {
        switch unison {
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
        default: 0
        }
    }
    static func unisonFromApproximationJustIntonation5Limit(pitch: Rational) -> Int? {
        let unison = pitch.mod(12)
        let dUnison = unison.decimalPart
        for i in 1 ... 11 {
            if approximationJustIntonation5Limit(unison: Rational(i)) - Rational(i) == dUnison {
                return i
            }
        }
        return nil
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

struct ScoreOption {
    var beatRange = Music.defaultBeatRange
    var loopDurBeat: Rational = 0
    var keyBeats: [Rational] = [4, 8, 12]
    var scales: [Rational] = [0, 2, 4, 5, 7, 9, 11]
    var tempo = Music.defaultTempo
    var timelineY = Sheet.timelineY
    var enabled = false
    var isShownSpectrogram = false
}
extension ScoreOption: Protobuf {
    init(_ pb: PBScoreOption) throws {
        beatRange = (try? RationalRange(pb.beatRange).value) ?? Music.defaultBeatRange
        loopDurBeat = (try? Rational(pb.loopDurBeat)) ?? 0
        keyBeats = pb.keyBeats.compactMap { try? Rational($0) }
        scales = pb.scales.compactMap { try? Rational($0) }
        tempo = (try? Rational(pb.tempo))?.clipped(Music.tempoRange) ?? Music.defaultTempo
        timelineY = pb.timelineY.clipped(min: Sheet.timelineY,
                                         max: Sheet.height - Sheet.timelineY)
        enabled = pb.enabled
        isShownSpectrogram = pb.isShownSpectrogram
    }
    var pb: PBScoreOption {
        .with {
            $0.beatRange = RationalRange(value: beatRange).pb
            $0.loopDurBeat = loopDurBeat.pb
            $0.keyBeats = keyBeats.map { $0.pb }
            $0.scales = scales.map { $0.pb }
            if tempo != Music.defaultTempo {
                $0.tempo = tempo.pb
            }
            $0.timelineY = timelineY
            $0.enabled = enabled
            $0.isShownSpectrogram = isShownSpectrogram
        }
    }
}
extension ScoreOption: Hashable, Codable {}
extension ScoreOption {
    var endLoopDurBeat: Rational {
        beatRange.end + loopDurBeat
    }
}

struct Score: BeatRangeType {
    static let minPitch = Rational(0, 12), maxPitch = Rational(10 * 12)
    static let pitchRange = minPitch ..< maxPitch
    static let doubleMinPitch = 0.0, doubleMaxPitch = 120.0
    static let doublePitchRange = doubleMinPitch ... doubleMaxPitch
    static let minFq = Pitch.fq(fromPitch: doubleMinPitch), maxFq = Pitch.fq(fromPitch: doubleMaxPitch)
    static let fqRange = minFq ... maxFq
    
    var notes = [Note]()
    var draftNotes = [Note]()
    var beatRange = Music.defaultBeatRange
    var loopDurBeat: Rational = 0
    var tempo = Music.defaultTempo
    var timelineY = Sheet.timelineY
    var keyBeats = [Rational]()
    var scales: [Rational] = [0, 2, 4, 5, 7, 9, 11]
    var enabled = false
    var isShownSpectrogram = false
    var id = UUID()
}
extension Score: Protobuf {
    init(_ pb: PBScore) throws {
        notes = pb.notes.compactMap { try? Note($0) }
        draftNotes = pb.draftNotes.compactMap { try? Note($0) }
        beatRange = (try? RationalRange(pb.beatRange).value) ?? Music.defaultBeatRange
        loopDurBeat = (try? Rational(pb.loopDurBeat)) ?? 0
        keyBeats = pb.keyBeats.compactMap { try? Rational($0) }
        scales = pb.scales.compactMap { try? Rational($0) }
        tempo = (try? Rational(pb.tempo))?.clipped(Music.tempoRange) ?? Music.defaultTempo
        timelineY = pb.timelineY.clipped(min: Sheet.timelineY,
                                         max: Sheet.height - Sheet.timelineY)
        enabled = pb.enabled
        isShownSpectrogram = pb.isShownSpectrogram
        id = (try? .init(pb.id)) ?? .init()
    }
    var pb: PBScore {
        .with {
            $0.notes = notes.map { $0.pb }
            $0.draftNotes = draftNotes.map { $0.pb }
            $0.beatRange = RationalRange(value: beatRange).pb
            $0.loopDurBeat = loopDurBeat.pb
            $0.keyBeats = keyBeats.map { $0.pb }
            $0.scales = scales.map { $0.pb }
            $0.tempo = tempo.pb
            $0.timelineY = timelineY
            $0.enabled = enabled
            $0.isShownSpectrogram = isShownSpectrogram
            $0.id = id.pb
        }
    }
}
extension Score: Hashable, Codable {}
extension Score {
    var spectrogram: Spectrogram? {
        if let renderedPCMBuffer {
            .init(renderedPCMBuffer)
        } else {
            nil
        }
    }
    var renderedPCMBuffer: PCMBuffer? {
        let seq = Sequencer(audiotracks: [.init(values: [.score(self)])], type: .normal)
        return try? seq?.buffer(sampleRate: Audio.defaultSampleRate,
                                progressHandler: { _, _ in })
    }
    
    var endLoopDurBeat: Rational {
        get {
            beatRange.end + loopDurBeat
        }
        set {
            loopDurBeat = max(0, newValue - beatRange.end)
        }
    }
    var loopDurSec: Rational {
        sec(fromBeat: loopDurBeat)
    }
    
    var allBeatRange: Range<Rational> {
        beatRange.start ..< (beatRange.end + loopDurBeat)
    }
    var allSecRange: Range<Rational> {
        secRange.start ..< (secRange.end + loopDurSec)
    }
    
    var musicScale: MusicScale? {
        .init(pitchs: scales.map { Int($0.rounded()) })
    }
    
    var localMaxBeatRange: Range<Rational>? {
        guard !notes.isEmpty else { return nil }
        let minV = notes.min(by: { $0.beatRange.lowerBound < $1.beatRange.lowerBound })!.beatRange.lowerBound
        let maxV = notes.max(by: { $0.beatRange.upperBound < $1.beatRange.upperBound })!.beatRange.upperBound
        return minV ..< maxV
    }
    
    func chordsResult(from chordResults: [Note.ChordResult]) -> [(chordRange: Range<Rational>,
                                                                  chordPitches: [Int])] {
        let chordBeats = chordResults.reduce(into: Set<Rational>()) {
            for v in $1.items {
                if beatRange.contains(v.beatRange.start) {
                    $0.insert(v.beatRange.start)
                }
                if beatRange.contains(v.beatRange.end) {
                    $0.insert(v.beatRange.end)
                }
            }
        }.sorted()
        guard !chordBeats.isEmpty else { return [] }
        
        var preBeat = beatRange.start
        var chordRanges = chordBeats.count.array.map {
            let v = preBeat ..< chordBeats[$0]
            preBeat = chordBeats[$0]
            return v
        }
        chordRanges.append(preBeat ..< beatRange.end)
        
        return chordRanges.map { ($0, Score.chordPitches(atBeat: $0, from: chordResults)) }
    }
    static func chordPitches(atBeat range: Range<Rational>,
                             from chordResults: [Note.ChordResult]) -> [Int] {
        var pitchLengths = [Int: [Range<Rational>]]()
        for chordResult in chordResults {
            for item in chordResult.items {
                if let iRange = item.beatRange.intersection(range) {
                    if pitchLengths[item.roundedPitch] != nil {
                        Range.union(iRange, in: &pitchLengths[item.roundedPitch]!)
                    } else {
                        pitchLengths[item.roundedPitch] = [iRange]
                    }
                }
            }
        }
        return pitchLengths.keys.sorted()
    }
    
    func noteIAndPits(atBeat beat: Rational,
                      in noteIs: [Int]) -> [(noteI: Int, pitResult: Note.PitResult)] {
        noteIs.compactMap { noteI in
            let note = notes[noteI]
            return if note.beatRange.contains(beat) || note.beatRange.end == beat {
                (noteI, note.pitResult(atBeat: Double(beat - note.beatRange.start)))
            } else {
                nil
            }
        }
    }
    func noteIAndNormarizedPits(atBeat beat: Rational, selectedNoteI: Int?,
                                in noteIs: [Int]) -> [(noteI: Int, pitResult: Note.PitResult)] {
        let notes = notes.map { $0.isSimpleLyric ? $0.withRendable(tempo: tempo) : $0 }
        let firstOrlast: FirstOrLast?
        if let selectedNoteI {
            let note = notes[selectedNoteI]
            if note.beatRange.start == beat {
                firstOrlast = .first
            } else if note.beatRange.end == beat {
                firstOrlast = .last
            } else {
                firstOrlast = nil
            }
        } else {
            firstOrlast = nil
        }
        
        return noteIs.compactMap { noteI in
            let note = notes[noteI]
            if noteI == selectedNoteI {
                if note.beatRange.contains(beat) || note.beatRange.end == beat {
                    return (noteI, note.normarizedPitResult(atBeat: Double(beat - note.beatRange.start)))
                }
            } else if firstOrlast == nil {
                if note.beatRange.contains(beat) {
                    return (noteI, note.normarizedPitResult(atBeat: Double(beat - note.beatRange.start)))
                }
            } else {
                if (beat > note.beatRange.start && beat < note.beatRange.end)
                    || (firstOrlast == .first ? note.beatRange.start == beat : note.beatRange.end == beat) {
                    return (noteI, note.normarizedPitResult(atBeat: Double(beat - note.beatRange.start)))
                }
            }
            return nil
        }
    }
}
extension Score {
    var option: ScoreOption {
        get {
            .init(beatRange: beatRange, loopDurBeat: loopDurBeat,
                  keyBeats: keyBeats, scales: scales,
                  tempo: tempo, timelineY: timelineY,
                  enabled: enabled,
                  isShownSpectrogram: isShownSpectrogram)
        }
        set {
            beatRange = newValue.beatRange
            loopDurBeat = newValue.loopDurBeat
            keyBeats = newValue.keyBeats
            scales = newValue.scales
            tempo = newValue.tempo
            timelineY = newValue.timelineY
            enabled = newValue.enabled
            isShownSpectrogram = newValue.isShownSpectrogram
        }
    }
}

struct Music {
    static let defaultTempo: Rational = 135
    static let minTempo = Rational(1, 4), maxTempo: Rational = 10000
    static let tempoRange = minTempo ... maxTempo
    static let defaultDurBeat = Rational(16)
    static let defaultBeatRange = 0 ..< defaultDurBeat
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
    static func beat(fromSec sec: Double,
                     tempo: Rational,
                     interval: Rational,
                     rounded rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Rational {
        let ii = interval.inversed!
        return Rational(Int((sec * Double(tempo) / 60 * Double(ii)).rounded(rule)))
        / ii
    }
    static func count(fromBeat beat: Rational,
                      tempo: Rational, frameRate: Int) -> Int {
        Int(beat * 60 / tempo * Rational(frameRate))
    }
    
    func sec(fromBeat beat: Double) -> Double {
        beat * 60 / Double(tempo)
    }
    func sec(fromBeat beat: Rational) -> Rational {
        beat * 60 / tempo
    }
    func secRange(fromBeat beatRange: Range<Rational>) -> Range<Rational> {
        sec(fromBeat: beatRange.lowerBound) ..< sec(fromBeat: beatRange.upperBound)
    }
    func beat(fromSec sec: Rational) -> Rational {
        sec * tempo / 60
    }
    func beat(fromSec sec: Double) -> Double {
        sec * Double(tempo) / 60
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
        Int(Double(beat * 60 / tempo * .init(frameRate)))
    }
    func count(fromSec sec: Rational, frameRate: Int) -> Int {
        Int(Double(sec * .init(frameRate)))
    }
}
protocol BeatRangeType: TempoType {
    var beatRange: Range<Rational> { get }
}
extension BeatRangeType {
    var secRange: Range<Rational> {
        secRange(fromBeat: beatRange)
    }
}

struct Audiotrack {
    enum Value: BeatRangeType {
        case score(Score)
        case sound(Content)
        
        var tempo: Rational {
            switch self {
            case .score(let score): score.tempo
            case .sound(let content): content.timeOption?.tempo ?? Music.defaultTempo
            }
        }
        var beatRange: Range<Rational> {
            switch self {
            case .score(let score): score.allBeatRange
            case .sound(let content): content.timeOption?.beatRange ?? 0 ..< 0
            }
        }
        var id: UUID {
            switch self {
            case .score(let score): score.id
            case .sound(let content): content.id
            }
        }
    }
    var values = [Value]()
    var durSec: Rational?
}
extension Audiotrack {
    var allDurSec: Rational {
        max(values.reduce(0) { max($0, $1.secRange.upperBound) }, durSec ?? 0)
    }
    static func + (lhs: Self, rhs: Self) -> Self {
        .init(values: lhs.values + rhs.values)
    }
    static func += (lhs: inout Self, rhs: Self) {
        lhs.values += rhs.values
    }
    static func += (lhs: inout Self?, rhs: Self) {
        if lhs == nil {
            lhs = rhs
        } else {
            lhs?.values += rhs.values
        }
    }
    var isEmpty: Bool {
        values.isEmpty
    }
}

struct Volm: Hashable, Codable {
    static let minVolm = 0.0, safeVolm = 0.75, maxVolm = 1.0
    static let safeVolmRange = minVolm ... safeVolm, volmRange = minVolm ... maxVolm
}
extension Volm {
    /// cutDb = -40, a = -cutDb, amp = (.exp(a * volm / 8.7) - 1) / (.exp(a / 8.7) - 1)
    static func amp(fromVolm volm: Double) -> Double {
        (.exp(4.5977011494 * volm) - 1) * 0.01017750808
    }
    static func volm(fromAmp amp: Double) -> Double {
        .log(1 + amp * 98.2558787375) * 0.2175
    }
    
    static func db(fromAmp amp: Double) -> Double {
        20 * .log10(amp)
    }
    static func amp(fromDb db: Double) -> Double {
        if db == 0 {
            1
        } else if db == -.infinity {
            0
        } else {
            10 ** (db / 20)
        }
    }
    
    static func db(fromVolm volm: Double) -> Double {
        db(fromAmp: amp(fromVolm: volm))
    }
    static func volm(fromDb db: Double) -> Double {
        volm(fromAmp: amp(fromDb: db))
    }
}

struct Audio: Hashable, Codable {
    static let defaultSampleRate = 44100.0
    static let headroomDb = 1.0
    static let headroomVolm = Volm.volm(fromDb: -headroomDb)
    static let headroomAmp = Volm.amp(fromVolm: headroomVolm)
    static let floatHeadroomAmp = Float(headroomAmp)
    
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
