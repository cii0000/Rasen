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
extension LyricsUnison {
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
    func octaveString(hidableDecimal: Bool = true) -> String {
        let octavePitch = value / 12
        let iPart = octavePitch.rounded(.down)
        let dPart = (octavePitch - iPart) * 12
        let dPartStr = String(format: "%02d", Int(dPart))
        if hidableDecimal && dPart.decimalPart == 0 {
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

struct Stereo: Codable, Hashable {
    var smp = 0.0, pan = 0.0, id = UUID()
}
extension Stereo {
    var isEmpty: Bool {
        smp == 0
    }
    
    func with(id: UUID) -> Self {
        var v = self
        v.id = id
        return v
    }
}
extension Stereo: Protobuf {
    init(_ pb: PBStereo) throws {
        smp = ((try? pb.smp.notNaN()) ?? 1).clipped(Volume.smpRange)
        pan = pb.pan.clipped(min: -1, max: 1)
        id = (try? .init(pb.id)) ?? .init()
    }
    var pb: PBStereo {
        .with {
            $0.smp = smp
            $0.pan = pan
            $0.id = id.pb
        }
    }
}
extension Stereo: MonoInterpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(smp: .linear(f0.smp, f1.smp, t: t),
              pan: .linear(f0.pan, f1.pan, t: t))
    }
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(smp: .firstSpline(f1.smp, f2.smp, f3.smp, t: t),
              pan: .firstSpline(f1.pan, f2.pan, f3.pan, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(smp: .spline(f0.smp, f1.smp, f2.smp, f3.smp, t: t),
              pan: .spline(f0.pan, f1.pan, f2.pan, f3.pan, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(smp: .lastSpline(f0.smp, f1.smp, f2.smp, t: t),
              pan: .lastSpline(f0.pan, f1.pan, f2.pan, t: t))
    }
    static func firstMonospline(_ f1: Self,
                            _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(smp: .firstMonospline(f1.smp, f2.smp, f3.smp, with: ms),
              pan: .firstMonospline(f1.pan, f2.pan, f3.pan, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(smp: .monospline(f0.smp, f1.smp, f2.smp, f3.smp, with: ms),
              pan: .monospline(f0.pan, f1.pan, f2.pan, f3.pan, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, with ms: Monospline) -> Self {
        .init(smp: .lastMonospline(f0.smp, f1.smp, f2.smp, with: ms),
              pan: .lastMonospline(f0.pan, f1.pan, f2.pan, with: ms))
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
extension Overtone: Protobuf {
    init(_ pb: PBOvertone) throws {
        evenSmp = ((try? pb.evenSmp.notNaN()) ?? 0).clipped(min: 0, max: 1)
        oddSmp = ((try? pb.oddSmp.notNaN()) ?? 0).clipped(min: 0, max: 1)
    }
    var pb: PBOvertone {
        .with {
            $0.evenSmp = evenSmp
            $0.oddSmp = oddSmp
        }
    }
}
enum OvertoneType: Int, Hashable, Codable, CaseIterable {
    case evenSmp, oddSmp
}
extension Overtone {
    subscript(type: OvertoneType) -> Double {
        get {
            switch type {
            case .evenSmp: evenSmp
            case .oddSmp: oddSmp
            }
        }
        set {
            switch type {
            case .evenSmp: evenSmp = newValue
            case .oddSmp: oddSmp = newValue
            }
        }
    }
}
extension Overtone: MonoInterpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(evenSmp: .linear(f0.evenSmp, f1.evenSmp, t: t),
              oddSmp: .linear(f0.oddSmp, f1.oddSmp, t: t))
    }
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(evenSmp: .firstSpline(f1.evenSmp, f2.evenSmp, f3.evenSmp, t: t),
              oddSmp: .firstSpline(f1.oddSmp, f2.oddSmp, f3.oddSmp, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(evenSmp: .spline(f0.evenSmp, f1.evenSmp, f2.evenSmp, f3.evenSmp, t: t),
              oddSmp: .spline(f0.oddSmp, f1.oddSmp, f2.oddSmp, f3.oddSmp, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(evenSmp: .lastSpline(f0.evenSmp, f1.evenSmp, f2.evenSmp, t: t),
              oddSmp: .lastSpline(f0.oddSmp, f1.oddSmp, f2.oddSmp, t: t))
    }
    static func firstMonospline(_ f1: Self,
                                _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(evenSmp: .firstMonospline(f1.evenSmp, f2.evenSmp, f3.evenSmp, with: ms),
              oddSmp: .firstMonospline(f1.oddSmp, f2.oddSmp, f3.oddSmp, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(evenSmp: .monospline(f0.evenSmp, f1.evenSmp, f2.evenSmp, f3.evenSmp, with: ms),
              oddSmp: .monospline(f0.oddSmp, f1.oddSmp, f2.oddSmp, f3.oddSmp, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) -> Self {
        .init(evenSmp: .lastMonospline(f0.evenSmp, f1.evenSmp, f2.evenSmp, with: ms),
              oddSmp: .lastMonospline(f0.oddSmp, f1.oddSmp, f2.oddSmp, with: ms))
    }
}

struct Sprol: Hashable, Codable {
    var pitch = 0.0, smp = 0.0, noise = 0.0
}
extension Sprol: Protobuf {
    init(_ pb: PBSprol) throws {
        pitch = ((try? pb.pitch.notNaN()) ?? 0).clipped(Score.doublePitchRange)
        smp = ((try? pb.smp.notNaN()) ?? 0).clipped(min: 0, max: 1)
        noise = ((try? pb.noise.notNaN()) ?? 0).clipped(min: 0, max: 1)
    }
    var pb: PBSprol {
        .with {
            $0.pitch = pitch
            $0.smp = smp
            $0.noise = noise
        }
    }
}

struct Spectlope: Hashable, Codable {
    var sprols = [Sprol(pitch: 0, smp: 1, noise: 0),
                    Sprol(pitch: 108, smp: 0, noise: 0)]
}
extension Spectlope: Protobuf {
    init(_ pb: PBSpectlope) throws {
        sprols = pb.sprols.compactMap { try? .init($0) }.sorted { $0.pitch < $1.pitch }
    }
    var pb: PBSpectlope {
        .with {
            $0.sprols = sprols.map { $0.pb }
        }
    }
}
extension Spectlope {
    init(pitchSmps: [Point]) {
        sprols = pitchSmps.map { .init(pitch: $0.x, smp: $0.y, noise: 0) }
    }
    init(noisePitchSmps: [Point]) {
        sprols = noisePitchSmps.map { .init(pitch: $0.x, smp: $0.y, noise: 1) }
    }
}
extension Spectlope {
    var isEmpty: Bool {
        sprols.isEmpty
    }
    var isEmptySmp: Bool {
        !sprols.contains { $0.smp > 0 }
    }
    var count: Int {
        sprols.count
    }
    var isFullNoise: Bool {
        !sprols.contains { $0.noise != 1 }
    }
    var isNoise: Bool {
        sprols.contains { $0.noise > 0 }
    }
    
    func sprol(atPitch pitch: Double) -> Sprol {
        guard !sprols.isEmpty else { return .init() }
        var prePitch = sprols.first!.pitch, preSprol = sprols.first!, maxSprol: Sprol?
        guard pitch >= prePitch else { return sprols.first! }
        for sprol in sprols {
            let nextPitch = sprol.pitch, nextSprol = sprol
            guard prePitch < nextPitch else {
                prePitch = nextPitch
                preSprol = nextSprol
                continue
            }
            if pitch < nextPitch, prePitch < nextPitch {
                let t = (pitch - prePitch) / (nextPitch - prePitch)
                let nSprol = Sprol.linear(preSprol, nextSprol, t: t)
                if let nMaxSprol = maxSprol {
                    maxSprol?.smp = max(nMaxSprol.smp, nSprol.smp)
                    maxSprol?.noise = max(nMaxSprol.noise, nSprol.noise)
                } else {
                    maxSprol = nSprol
                }
            }
            prePitch = nextPitch
            preSprol = nextSprol
        }
        return maxSprol ?? sprols.last!
    }
    
    func amp(atFq fq: Double) -> Double {
        Volume.amp(fromSmp: sprol(atPitch: Pitch.pitch(fromFq: fq)).smp)
    }
    
    func noiseT(atPitch pitch: Double) -> Double {
        sprol(atPitch: pitch).noise
    }
    func noiseT(atFq fq: Double) -> Double {
        noiseT(atPitch: Pitch.pitch(fromFq: fq))
    }
    
    func noiseAmp(atFq fq: Double) -> Double {
        Volume.amp(fromSmp: sprol(atPitch: Pitch.pitch(fromFq: fq)).noise)
    }
    func noisedAmp(atFq fq: Double) -> Double {
        let amp = amp(atFq: fq)
        let noiseAmp = noiseAmp(atFq: fq)
        return amp - noiseAmp
    }
    
    var formants: [Formant] {
        stride(from: 0, to: sprols.count, by: 4).map {
            .init(sprol0: sprols[$0], sprol1: sprols[$0 + 1],
                  sprol2: sprols[$0 + 2], sprol3: sprols[$0 + 3])
        }
    }
    var formantCount: Int {
        sprols.count / 4
    }
}
extension Sprol: MonoInterpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        .init(pitch: .linear(f0.pitch, f1.pitch, t: t),
              smp: .linear(f0.smp, f1.smp, t: t),
              noise: .linear(f0.noise, f1.noise, t: t))
    }
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(pitch: .firstSpline(f1.pitch, f2.pitch, f3.pitch, t: t),
              smp: .firstSpline(f1.smp, f2.smp, f3.smp, t: t),
              noise: .firstSpline(f1.noise, f2.noise, f3.noise, t: t))
    }
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self {
        .init(pitch: .spline(f0.pitch, f1.pitch, f2.pitch, f3.pitch, t: t),
              smp: .spline(f0.smp, f1.smp, f2.smp, f3.smp, t: t),
              noise: .spline(f0.noise, f1.noise, f2.noise, f3.noise, t: t))
    }
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self {
        .init(pitch: .lastSpline(f0.pitch, f1.pitch, f2.pitch, t: t),
              smp: .lastSpline(f0.smp, f1.smp, f2.smp, t: t),
              noise: .lastSpline(f0.noise, f1.noise, f2.noise, t: t))
    }
    static func firstMonospline(_ f1: Self,
                                _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(pitch: .firstMonospline(f1.pitch, f2.pitch, f3.pitch, with: ms),
              smp: .firstMonospline(f1.smp, f2.smp, f3.smp, with: ms),
              noise: .firstMonospline(f1.noise, f2.noise, f3.noise, with: ms))
    }
    static func monospline(_ f0: Self, _ f1: Self,
                           _ f2: Self, _ f3: Self, with ms: Monospline) -> Self {
        .init(pitch: .monospline(f0.pitch, f1.pitch, f2.pitch, f3.pitch, with: ms),
              smp: .monospline(f0.smp, f1.smp, f2.smp, f3.smp, with: ms),
              noise: .monospline(f0.noise, f1.noise, f2.noise, f3.noise, with: ms))
    }
    static func lastMonospline(_ f0: Self, _ f1: Self,
                               _ f2: Self, with ms: Monospline) -> Self {
        .init(pitch: .lastMonospline(f0.pitch, f1.pitch, f2.pitch, with: ms),
              smp: .lastMonospline(f0.smp, f1.smp, f2.smp, with: ms),
              noise: .lastMonospline(f0.noise, f1.noise, f2.noise, with: ms))
    }
}
extension Spectlope: MonoInterpolatable {
    func with(count: Int) -> Self {
        let sprols = sprols
        guard sprols.count != count else { return self }
        guard sprols.count < count else { fatalError() }
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
}

struct Tone: Hashable, Codable {
    static let noise = Self(spectlope: .init(sprols: [.init(pitch: Score.doubleMinPitch,
                                                            smp: 1, noise: 1),
                                                      .init(pitch: Score.doubleMaxPitch,
                                                            smp: 1, noise: 1)]))
    
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
    func with(id: UUID) -> Self {
        var v = self
        v.id = id
        return v
    }
    func with(spectlopeCount: Int) -> Self {
        .init(overtone: overtone, spectlope: spectlope.with(count: spectlopeCount), id: id)
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
    var beat = Rational(0), pitch = Rational(0), stereo = Stereo(smp: 0.5), tone = Tone(), lyric = ""
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
    init(beat: Rational, pitch: Rational, smp: Double) {
        self.beat = beat
        self.pitch = pitch
        self.stereo = .init(smp: smp.clipped(Volume.smpRange))
    }
    
    func isEqualWithoutBeat(_ other: Self) -> Bool {
        pitch == other.pitch && stereo == other.stereo && tone == other.tone && lyric == other.lyric
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

struct Envelope: Hashable, Codable {
    var attackSec = 0.02, decaySec = 0.04, sustainSmp = 0.95, releaseSec = 0.06
    var id = UUID()
}
extension Envelope: Protobuf {
    init(_ pb: PBEnvelope) throws {
        attackSec = try pb.attackSec.notNaN().clipped(min: 0, max: 1)
        decaySec = try pb.decaySec.notNaN().clipped(min: 0, max: 1)
        sustainSmp = try pb.sustainSmp.notNaN().clipped(min: 0, max: 1)
        releaseSec = try pb.releaseSec.notNaN().clipped(min: 0, max: 1)
        id = (try? .init(pb.id)) ?? .init()
    }
    var pb: PBEnvelope {
        .with {
            $0.attackSec = attackSec
            $0.decaySec = decaySec
            $0.sustainSmp = sustainSmp
            $0.releaseSec = releaseSec
            $0.id = id.pb
        }
    }
}

struct Note {
    var beatRange = 0 ..< Rational(1, 4)
    var pitch = Rational(0)
    var pits = [Pit()]
    var envelope = Envelope()
    var isNoise = false
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
        envelope = (try? Envelope(pb.envelope)) ?? .init()
        isNoise = pb.isNoise
        id = (try? UUID(pb.id)) ?? UUID()
    }
    var pb: PBNote {
        .with {
            $0.beatRange = RationalRange(value: beatRange).pb
            $0.pitch = pitch.pb
            $0.pits = pits.map { $0.pb }
            $0.envelope = envelope.pb
            $0.isNoise = isNoise
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
    var firstFq: Double {
        Pitch(value: pitch + pits[0].pitch).fq
    }
    var firstPitResult: PitResult {
        .init(notePitch: pitch, pitch: .rational(firstPit.pitch), stereo: firstStereo,
              tone: firstTone, lyric: firstPit.lyric,
              envelope: envelope, isNoise: isNoise, id: id)
    }
    var containsNoise: Bool {
        pits.contains(where: { $0.tone.spectlope.sprols.contains(where: { $0.noise > 0 }) })
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
    
    func chordBeatRangeAndRoundedPitchs() -> [(beatRange: Range<Rational>, roundedPitch: Int)] {
        if pits.count >= 2 {
            var ns = [(beatRange: Range<Rational>, roundedPitch: Int)]()
            var preBeat = beatRange.start, prePitch = Int((pitch + pits[0].pitch).rounded())
            var isPreEqual = true
            for i in 1 ..< pits.count {
                let pit = pits[i]
                let pitch = Int((pitch + pit.pitch).rounded())
                if pitch != prePitch {
                    let beat = pit.beat + beatRange.start
                    if isPreEqual {
                        ns.append((preBeat ..< beat, prePitch))
                    }
                    preBeat = beat
                    prePitch = pitch
                    
                    isPreEqual = false
                } else {
                    isPreEqual = true
                }
            }
            if preBeat < beatRange.end {
                ns.append((preBeat ..< beatRange.end, prePitch))
            }
            return ns
        } else {
            return [(beatRange, firstRoundedPitch)]
        }
    }
    
    func isEqualOtherThanBeatRange(_ other: Self) -> Bool {
        pitch == other.pitch
        && pits == other.pits
        && envelope == other.envelope
        && isNoise == other.isNoise
        && id == other.id
    }
    
    func pitbend(fromTempo tempo: Rational) -> Pitbend {
        let spectlopeCount = (pits.maxValue { $0.tone.spectlope.sprols.count }) ?? 0
        var pitKeys: [Interpolation<InterPit>.Key] = pits.map {
            .init(value: .init(pitch: .init($0.pitch / 12),
                               stereo: $0.stereo,
                               tone: $0.tone.with(spectlopeCount: spectlopeCount),
                               lyric: $0.lyric),
                  time: .init(Score.sec(fromBeat: $0.beat, tempo: tempo)), 
                  type: .spline)
        }
        if pits.first?.beat != 0 {
            pitKeys.insert(.init(value: pitKeys.first!.value, time: 0, type: .spline), at: 0)
        }
        let durSec = Double(Score.sec(fromBeat: beatRange.length, tempo: tempo))
        if pits.last?.beat != beatRange.length {
            pitKeys.append(.init(value: pitKeys.last!.value, time: durSec, type: .spline))
        }
        let it = Interpolation<InterPit>(keys: pitKeys, duration: durSec)
        let firstStereo = firstStereo, firstTone = firstTone
        let isEmptyPitch = !(pits.contains { $0.pitch != 0 })
        let isEmptyTone = !(pits.contains { $0.tone != firstTone })
        let isEmptyStereo = !(pits.contains { $0.stereo != firstStereo })
        return .init(interpolation: it,
                     firstPitch: .init(pits[0].pitch / 12),
                     firstStereo: firstStereo, firstTone: firstTone,
                     isEqualAllPitch: isEmptyPitch, isEqualAllTone: isEmptyTone, isEqualAllStereo: isEmptyStereo,
                     isEqualAllWithoutStereo: isEmptyPitch && isEmptyTone)
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
            tone: Tone, lyric: String, envelope: Envelope, isNoise: Bool, id: UUID
    }
    func pitResult(atBeat beat: Double) -> PitResult {
        if pits.count == 1 || beat <= .init(pits[0].beat) {
            let pit = pits[0]
            return .init(notePitch: pitch, pitch: .rational(pit.pitch), stereo: pit.stereo,
                         tone: pit.tone, lyric: pit.lyric,
                         envelope: envelope, isNoise: isNoise, id: id)
        } else if let pit = pits.last, beat >= .init(pit.beat) {
            return .init(notePitch: pitch, pitch: .rational(pit.pitch), stereo: pit.stereo,
                         tone: pit.tone, lyric: pit.lyric,
                         envelope: envelope, isNoise: isNoise, id: id)
        }
        for pitI in 0 ..< pits.count - 1 {
            let pit = pits[pitI], nextPit = pits[pitI + 1]
            if beat >= .init(pit.beat) && beat < .init(nextPit.beat) && pit.isEqualWithoutBeat(nextPit) {
                return .init(notePitch: pitch, pitch: .rational(pit.pitch), stereo: pit.stereo,
                             tone: pit.tone, lyric: pit.lyric,
                             envelope: envelope, isNoise: isNoise, id: id)
            }
        }
        
        var pitKeys: [Interpolation<InterPit>.Key] = pits.map {
            .init(value: .init(pitch: .init($0.pitch),
                               stereo: $0.stereo,
                               tone: $0.tone,
                               lyric: $0.lyric),
                  time: .init($0.beat),
                  type: .spline)
        }
        if pits.first?.beat != 0 {
            pitKeys.insert(.init(value: pitKeys.first!.value, time: 0, type: .spline), at: 0)
        }
        let durSec = Double(beatRange.length)
        if pits.last?.beat != beatRange.length {
            pitKeys.append(.init(value: pitKeys.last!.value, time: durSec, type: .spline))
        }
        let it = Interpolation<InterPit>(keys: pitKeys, duration: durSec)
        guard let value = it.monoValueEnabledFirstLast(withT: .init(beat), isLoop: false) else {
            let pit = firstPit
            return .init(notePitch: pitch, pitch: .rational(pit.pitch), stereo: pit.stereo,
                         tone: pit.tone, lyric: pit.lyric,
                         envelope: envelope, isNoise: isNoise, id: id)
        }
        return .init(notePitch: pitch, pitch: .real(value.pitch),
                     stereo: value.stereo,
                     tone: value.tone, lyric: value.lyric,
                     envelope: envelope, isNoise: isNoise, id: id)
    }

    var isEmpty: Bool {
        pits.isEmpty
    }
    var isEmptyPitch: Bool {
        !pits.contains(where: { $0.pitch != 0 })
    }
    var isEmptyStereo: Bool {
        !pits.contains(where: { !$0.stereo.isEmpty })
    }
    var isEmptySmp: Bool {
        !pits.contains(where: { $0.stereo.smp != 0 })
    }
    var isEmptyPan: Bool {
        !pits.contains(where: { $0.stereo.pan != 0 })
    }
    var isOneOvertone: Bool {
        !pits.contains(where: { !$0.tone.overtone.isOne })
    }
}
extension Note {
    private static func pitsFrom(recoilBeat0 beat0: Rational, beat1: Rational,
                                 beat2: Rational, beat3: Rational, lastBeat: Rational,
                                 pitch0: Rational, pitch1: Rational, pitch2: Rational,
                                 pitch3: Rational, lastPitch: Rational,
                                 v1Smp: Double) -> [Pit] {
        [.init(beat: 0, pitch: pitch0, smp: 0.95),
         .init(beat: beat0, pitch: pitch1, smp: 1),
         .init(beat: beat1, pitch: pitch2, smp: 1),
         .init(beat: beat2, pitch: pitch3, smp: 1),
         .init(beat: beat3, pitch: 0, smp: v1Smp),
         .init(beat: lastBeat, pitch: lastPitch, smp: 0.9 * v1Smp)]
    }
    private static func pitsFrom(recoilBeat0 beat0: Rational, beat1: Rational, lastBeat: Rational,
                                 pitch0: Rational, pitch1: Rational,
                                 pitch2: Rational, lastPitch: Rational) -> [Pit] {
        [.init(beat: 0, pitch: pitch0, smp: 0.95),
         .init(beat: beat0, pitch: pitch1, smp: 0.975),
         .init(beat: beat1, pitch: pitch2, smp: 1),
         .init(beat: lastBeat, pitch: lastPitch, smp: 0.9)]
    }
    private static func pitsFrom(oneBeat0 beat0: Rational, beat1: Rational, lastBeat: Rational,
                                 pitch0: Rational, pitch1: Rational, lastPitch: Rational) -> [Pit] {
        [.init(beat: 0, pitch: pitch0, smp: 0.975),
         .init(beat: beat0, pitch: pitch1, smp: 1),
         .init(beat: beat1, pitch: 0, smp: 1),
         .init(beat: lastBeat, pitch: lastPitch, smp: 0.9)]
    }
    private static func pitsFrom(oneBeat0 beat0: Rational,  lastBeat: Rational,
                                 pitch0: Rational, pitch1: Rational, lastPitch: Rational) -> [Pit] {
        [.init(beat: 0, pitch: pitch0, smp: 0.975),
         .init(beat: beat0, pitch: pitch1, smp: 1),
         .init(beat: lastBeat, pitch: lastPitch, smp: 0.9)]
    }
    private static func pitsFrom(vibratoBeatPitchs bps: [(beat: Rational, pitch: Rational)],
                                 vibratoStartBeat vBeat: Rational,
                                 beat0: Rational,  lastBeat: Rational,
                                 pitch0: Rational, lastPitch: Rational) -> [Pit] {
        guard bps.count % 2 == 0 else { fatalError() }
        var pits = [Pit]()
        pits.append(.init(beat: 0, pitch: pitch0, smp: 0.975))
        pits.append(.init(beat: beat0, pitch: 0, smp: 1))
        pits.append(.init(beat: vBeat, pitch: 0, smp: 1))
        for bp in bps {
            pits.append(.init(beat: bp.beat, pitch: bp.pitch, smp: 1))
        }
        pits[.last].pitch = 0
        pits.append(.init(beat: lastBeat, pitch: lastPitch, smp: 0.8))
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
                                 v1Smp: isVibrato ? 0.9 : 0.95)
        }
    }
}

struct Chord: Hashable, Codable {
    enum ChordType: Int, Hashable, Codable, CaseIterable, CustomStringConvertible {
        case power, major, suspended, minor, augmented, flatfive, diminish, tritone
        
        var description: String {
            switch self {
            case .power: "Pow"
            case .major: "Maj"
            case .suspended: "Sus"
            case .minor: "Min"
            case .augmented: "Aug"
            case .flatfive: "Fla"
            case .diminish: "Dim"
            case .tritone: "Tri"
            }
        }
        var unisons: [Int] {
            switch self {
            case .power: [0, 7]
            case .major: [0, 4, 7]
            case .suspended: [0, 5, 7]
            case .minor: [0, 3, 7]
            case .augmented: [0, 4, 8]
            case .flatfive: [0, 4, 6]
            case .diminish: [0, 3, 6]
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
            case .augmented, .tritone: 1
            case .power: 2
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
        let pitchs = Set(pitchs.map { $0.mod(12) }).sorted()
        guard pitchs.count >= 2 else { return nil }
        
        let pitchsSet = Set(pitchs)
        
        var typers = [ChordTyper]()
        
        for type in ChordType.cases3Count {
            for j in 0 ..< pitchs.count {
                let unison = pitchs[j]
                let nUnisons = type.unisons.map { ($0 + unison).mod(12) }
                if pitchsSet.isSuperset(of: nUnisons) {
                    typers.append(.init(type, unison: unison))
                }
            }
        }
        
        for type in ChordType.cases2Count {
            for j in 0 ..< pitchs.count {
                let unison = pitchs[j]
                let nUnisons = type.unisons.map { ($0 + unison).mod(12) }
                if pitchsSet.isSuperset(of: nUnisons) {
                    let nTyper = ChordTyper(type, unison: unison)
                    if !typers.contains(where: { $0.unisons.isSuperset(of: nTyper.unisons) }) {
                        typers.append(nTyper)
                    }
                }
            }
        }
        
        for type in ChordType.cases1Count {
            for j in 0 ..< pitchs.count {
                let unison = pitchs[j]
                let nUnisons = type.unisons.map { ($0 + unison).mod(12) }
                if pitchsSet.isSuperset(of: nUnisons) {
                    let nTyper = ChordTyper(type, unison: unison)
                    if !typers.contains(where: { $0.unisons.isSuperset(of: nTyper.unisons) }) {
                        typers.append(nTyper)
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

struct ScoreOption {
    var durBeat = Rational(16)
    var keyBeats: [Rational] = [4, 8, 12]
    var tempo = Music.defaultTempo
    var enabled = false
}
extension ScoreOption: Protobuf {
    init(_ pb: PBScoreOption) throws {
        durBeat = (try? Rational(pb.durBeat)) ?? 16
        if durBeat < 0 {
            durBeat = 0
        }
        keyBeats = pb.keyBeats.compactMap { try? Rational($0) }
        tempo = (try? Rational(pb.tempo))?.clipped(Music.tempoRange) ?? Music.defaultTempo
        enabled = pb.enabled
    }
    var pb: PBScoreOption {
        .with {
            $0.durBeat = durBeat.pb
            $0.keyBeats = keyBeats.map { $0.pb }
            if tempo != Music.defaultTempo {
                $0.tempo = tempo.pb
            }
            $0.enabled = enabled
        }
    }
}
extension ScoreOption: Hashable, Codable {}

struct Score: BeatRangeType {
    static let minPitch = Rational(0, 12), maxPitch = Rational(10 * 12)
    static let pitchRange = minPitch ..< maxPitch
    static let doubleMinPitch = 0.0, doubleMaxPitch = 120.0
    static let doublePitchRange = doubleMinPitch ... doubleMaxPitch
    
    var notes = [Note]()
    var draftNotes = [Note]()
    var durBeat = Rational(16)
    var tempo = Music.defaultTempo
    var keyBeats: [Rational] = [4, 8, 12]
    var enabled = false
    var id = UUID()
}
extension Score: Protobuf {
    init(_ pb: PBScore) throws {
        notes = pb.notes.compactMap { try? Note($0) }
        draftNotes = pb.draftNotes.compactMap { try? Note($0) }
        durBeat = (try? Rational(pb.durBeat)) ?? 16
        if durBeat < 0 {
            durBeat = 0
        }
        keyBeats = pb.keyBeats.compactMap { try? Rational($0) }
        tempo = (try? Rational(pb.tempo))?.clipped(Music.tempoRange) ?? Music.defaultTempo
        enabled = pb.enabled
        id = (try? .init(pb.id)) ?? .init()
    }
    var pb: PBScore {
        .with {
            $0.notes = notes.map { $0.pb }
            $0.draftNotes = draftNotes.map { $0.pb }
            $0.durBeat = durBeat.pb
            $0.keyBeats = keyBeats.map { $0.pb }
            $0.tempo = tempo.pb
            $0.enabled = enabled
            $0.id = id.pb
        }
    }
}
extension Score: Hashable, Codable {}
extension Score {
    var beatRange: Range<Rational> {
        0 ..< durBeat
    }
    var spectrogram: Spectrogram? {
        if let renderedPCMBuffer {
            .init(renderedPCMBuffer)
        } else {
            nil
        }
    }
    var renderedPCMBuffer: PCMBuffer? {
        let seq = Sequencer(audiotracks: [.init(values: [.score(self)])],
                            isAsync: false, playStartSec: 0)
        return try? seq?.buffer(sampleRate: Audio.defaultExportSampleRate,
                                progressHandler: { _, _ in })
    }
    
    var localMaxBeatRange: Range<Rational>? {
        guard !notes.isEmpty else { return nil }
        let minV = notes.min(by: { $0.beatRange.lowerBound < $1.beatRange.lowerBound })!.beatRange.lowerBound
        let maxV = notes.max(by: { $0.beatRange.upperBound < $1.beatRange.upperBound })!.beatRange.upperBound
        return minV ..< maxV
    }
    
    func chordPitches(atBeat range: Range<Rational>) -> [Int] {
        var pitchLengths = [Int: Rational]()
        for note in notes {
            for (beatRange, roundedPitch) in note.chordBeatRangeAndRoundedPitchs() {
                if let iRange = beatRange.intersection(range) {
                    if pitchLengths[roundedPitch] != nil {
                        pitchLengths[roundedPitch]! += iRange.length
                    } else {
                        pitchLengths[roundedPitch] = iRange.length
                    }
                }
            }
        }
        let length = range.length / 8
        return pitchLengths.filter { $0.value > length }.keys.sorted()
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
}
extension Score {
    var option: ScoreOption {
        get {
            .init(durBeat: durBeat, keyBeats: keyBeats, tempo: tempo, enabled: enabled)
        }
        set {
            durBeat = newValue.durBeat
            keyBeats = newValue.keyBeats
            tempo = newValue.tempo
            enabled = newValue.enabled
        }
    }
}

struct Music {
    static let defaultTempo: Rational = 120
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
        Int(Double(beat) * 60 / Double(tempo) * Double(frameRate))
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
            case .score(let score): score.beatRange
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
}
extension Audiotrack {
    var durSec: Rational {
        values.reduce(0) { max($0, $1.secRange.upperBound) }
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

struct Volume: Hashable, Codable {
    static let minSmp = 0.0, maxSmp = 1.0, smpRange = minSmp ... maxSmp
    static let minAmp = 0.0, maxAmp = 1.0, ampRange = minAmp ... maxAmp
}
extension Volume {
    /// amp = (.exp(40 * smp / 8.7) - 1) / (.exp(40 / 8.7) - 1)
    static func amp(fromSmp smp: Double) -> Double {
        (.exp(4.5977011494 * smp) - 1) * 0.01017750808
    }
    static func smp(fromAmp amp: Double) -> Double {
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
    
    static func db(fromSmp smp: Double) -> Double {
        db(fromAmp: amp(fromSmp: smp))
    }
    static func smp(fromDb db: Double) -> Double {
        smp(fromAmp: amp(fromDb: db))
    }
}

struct Audio: Hashable, Codable {
    static let defaultExportSampleRate = 44100.0
    static let defaultSampleRate = 65536.0
    static let defaultDftCount = 65536
    static let headroomDb = 1.0
    static let headroomSmp = Volume.smp(fromDb: -headroomDb)
    static let headroomAmp = Volume.amp(fromSmp: headroomSmp)
    static let floatHeadroomAmp = Float(headroomAmp)
    static let defaultReverb = 0.0
    static let hearingRange = 20.0 ... 20000.0
    
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
