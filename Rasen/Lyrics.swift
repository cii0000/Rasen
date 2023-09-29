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

import struct Foundation.URL
import struct Foundation.Data
import class Foundation.XMLDocument
import class Foundation.XMLElement
import class Foundation.XMLNode
import class Foundation.XMLDTD

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

struct Lyrics {
    enum FileType: FileTypeProtocol, CaseIterable {
        case musicxml
        
        var name: String {
            switch self {
            case .musicxml: "MusicXML"
            }
        }
        var utType: UTType {
            switch self {
            case .musicxml: .init(importedAs: "com.recordare.musicxml")
            }
        }
    }
    
    struct MeasurePitch {
        var octave: Int
        var lyricsUnison: LyricsUnison
        
        init(pitch: Pitch, isSharp: Bool) {
            octave = pitch.octave
            lyricsUnison = pitch.lyricsUnison(isSharp: isSharp)
        }
    }
    struct MeasureScale {
        var type = MusicScaleType.major
        var lyricsUnison = LyricsUnison(.c)
        var fifthsNumber = 0
        
        init(type: MusicScaleType = .major,
             lyricsUnison: LyricsUnison = LyricsUnison(.c)) {
            
            self.type = type
            self.lyricsUnison = lyricsUnison
            self.fifthsNumber = MeasureScale.fifthsNumber(type: type,
                                                          lyricsUnison: lyricsUnison)
        }
        
        static func fifthsNumber(type: MusicScaleType,
                                 lyricsUnison: LyricsUnison) -> Int {
            if type.isMinor {
                switch lyricsUnison.unison {
                case 0: -3
                case 1: 4
                case 2: -1
                case 3: 6
                case 4: 1
                case 5: -4
                case 6: 3
                case 7: -2
                case 8: 5
                case 9: 0
                case 10: -5
                case 11: 2
                default: fatalError()
                }
            } else {
                switch lyricsUnison.unison {
                case 0: 0
                case 1: -5
                case 2: 2
                case 3: -3
                case 4: 4
                case 5: -1
                case 6: 6
                case 7: 1
                case 8: -4
                case 9: 3
                case 10: -2
                case 11: 5
                default: fatalError()
                }
            }
        }
        func fifthsIndexes() -> [LyricsUnison] {
            fifthsNumber < 0 ?
            Array([LyricsUnison(.b, .flat),
                   LyricsUnison(.e, .flat),
                   LyricsUnison(.a, .flat),
                   LyricsUnison(.d, .flat),
                   LyricsUnison(.g, .flat),
                   LyricsUnison(.c, .flat),
                   LyricsUnison(.f, .flat)][..<(-fifthsNumber)]) :
            Array([LyricsUnison(.f, .sharp),
                   LyricsUnison(.c, .sharp),
                   LyricsUnison(.g, .sharp),
                   LyricsUnison(.d, .sharp),
                   LyricsUnison(.a, .sharp),
                   LyricsUnison(.e, .sharp),
                   LyricsUnison(.b, .sharp)][..<fifthsNumber])
        }
    }
    struct MeasureNote {
        enum NoteType: Int, CaseIterable {
            case whole = 64,
                 halfDot = 48, half = 32,
                 quarterDot = 24, quarter = 16,
                 eighthDot = 12, eighth = 8,
                 n16thDot = 6, n16th = 4,
                 n32thDot = 3, n32th = 2,
                 n64th = 1
            
            var name: String {
                switch self {
                case .whole: "whole"
                case .halfDot, .half: "half"
                case .quarterDot, .quarter: "quarter"
                case .eighthDot, .eighth: "eighth"
                case .n16thDot, .n16th: "16th"
                case .n32thDot, .n32th: "32nd"
                case .n64th: "64th"
                }
            }
            var isDot: Bool {
                switch self {
                case .halfDot, .quarterDot, .eighthDot,
                        .n16thDot, .n32thDot: true
                default: false
                }
            }
            var beat: Rational {
                Rational(rawValue, 64)
            }
            init(duration: Rational) {
                for type in NoteType.allCases {
                    if duration >= type.beat {
                        self = type
                        return
                    }
                }
                self = .n64th
            }
            static func types(from64Count count: Int) -> [NoteType] {
                var types = [NoteType]()
                var count = count
                for type in NoteType.allCases {
                    let sCount = count / type.rawValue
                    if sCount > 0 {
                        types += [NoteType](repeating: type, count: sCount)
                        count -= sCount * type.rawValue
                    }
                }
                return types
            }
        }
        
        var type = NoteType.quarter
        var lyric = ""
        var pitch: MeasurePitch?
        var isBreath = false
        var isStartTie = false
        var isEndTie = false
    }
    struct Measure {
        var notes = [MeasureNote]()
        var tempo = 120.0
        var fifthsNumber = 0
        
        init(notes: [MeasureNote],
             scale: MeasureScale,
             tempo: Double) {
           
            self.tempo = tempo
            
            self.fifthsNumber = scale.fifthsNumber
            self.notes = notes
        }
    }
    
    struct LyricsError: Error {}
    
    init(timetracks: [Timetrack]) throws {
        guard !timetracks.isEmpty else { throw LyricsError() }
        
        struct Filling {
            var id = 0
            var tempo = 120.0
            var scale = MeasureScale()
            var lyric = ""
            var pitch: MeasurePitch?
            var isBreath = false
            var isStart = false
            var isEnd = false
        }
        
        let timetracks = timetracks.filter { timetrack in
            guard let tempo = timetrack.timeframes.first?.value.tempo,
                  !timetrack.timeframes.contains(where: { $0.value.tempo != tempo }) else { return false }
            return true
        }
        
        func beatDuration(from timetrack: Timetrack) -> Rational {
            timetrack.timeframes
                .reduce(Rational(0)) { max($0, $1.value.beatRange.upperBound) }
        }
        
        let measureBeatsCount = 4
        let imCount = measureBeatsCount * 16
        let mCount = Rational(imCount / 4)
        let allD = timetracks.reduce(Rational()) { $0 + beatDuration(from: $1) }
        let allCount = Int(allD * mCount).intervalUp(scale: imCount)
        var timetrackBeat = Rational()
        var fillings = [Filling](repeating: Filling(), count: allCount)
        var noteI = 1
        for timetrack in timetracks {
            let tempo = timetrack.timeframes.first!.value.tempo
            let beatDuration = beatDuration(from: timetrack)
            let si = Int(timetrackBeat * mCount)
            let ei = Int((timetrackBeat + beatDuration) * mCount)
            for i in si ..< ei {
                fillings[i].tempo = Double(tempo)
            }
            for (_, timeframe) in timetrack.timeframes {
                guard let score = timeframe.score else { continue }
                let unison = Int(score.scaleKey).mod(12)
                let lu = LyricsUnison(unison: unison, isSharp: true)
                let scale = MeasureScale(type: score.scaleType ?? .major,
                                         lyricsUnison: lu)
                let timeframeBeat = timeframe.beatRange.start + timetrackBeat
                let si = Int(timeframeBeat * mCount)
                let ei = Int((timeframeBeat + timeframe.beatRange.length) * mCount)
                for i in si ..< ei {
                    fillings[i].scale = scale
                }
                
                for note in score.notes {
                    let note = score.convertPitchToWorld(note)
                    var beatRange = note.beatRange
                    beatRange.start += timeframeBeat
                    let si = Int(beatRange.start * mCount)
                        .clipped(min: 0, max: allCount)
                    let ei = Int(beatRange.end * mCount)
                        .clipped(min: 0, max: allCount)
                    for i in si ..< ei {
                        fillings[i].id = noteI
                        fillings[i].lyric = note.lyric
                        fillings[i].pitch = MeasurePitch(pitch: Pitch(value: note.pitch),
                                                         isSharp: scale.fifthsNumber >= 0)
                        fillings[i].isBreath = note.isBreath
                    }
                    noteI += 1
                }
            }
            timetrackBeat += beatDuration
        }

        var oldID = fillings[.first].id
        fillings[.first].isStart = true
        for i in 1 ..< fillings.count {
            if fillings[i].id != oldID {
                fillings[i - 1].isEnd = true
                fillings[i].isStart = true
            }
            oldID = fillings[i].id
        }
        fillings[.last].isEnd = true
        
        var measures = [Measure]()
        var si = 0
        while si < fillings.count {
            let ei = si + imCount
            let fs = Array(fillings[si ..< ei])
            
            func appendNotes(start fsi: Int, end fei: Int,
                             isStart: Bool, isEnd: Bool,
                             startF: Filling, endF: Filling) {
                let count = 1 + fei - fsi
                let types = MeasureNote.NoteType.types(from64Count: count)
                for (ti, type) in types.enumerated() {
                    let isStartTie = isStart && ti == 0
                    let isEndTie = isEnd && ti == types.count - 1
                    let lyric = isStartTie ? startF.lyric : ""
                    let isBreath = isEndTie ? endF.isBreath : false
                    notes.append(MeasureNote(type: type,
                                             lyric: lyric,
                                             pitch: startF.pitch,
                                             isBreath: isBreath,
                                             isStartTie: isStartTie,
                                             isEndTie: isEndTie))
                }
            }
            
            var notes = [MeasureNote]()
            var fsi = 0, isStartFSI = false, startF = fs[0]
            for (fei, f) in fs.enumerated() {
                if f.isStart {
                    fsi = fei
                    isStartFSI = true
                    startF = f
                }
                if f.isEnd || fei == fs.count - 1 {
                    appendNotes(start: fsi, end: fei,
                                isStart: isStartFSI, isEnd: f.isEnd,
                                startF: startF, endF: f)
                    isStartFSI = false
                }
            }
            
            measures.append(Measure(notes: notes,
                                    scale: fs[0].scale,
                                    tempo: fs[0].tempo))
            si = ei
        }
        
        self.measures = measures
    }
    
    var measures = [Measure]()
    
    func write(to url: URL) throws {
        try data().write(to: url)
    }
    func data() throws -> Data {
        let xml = XMLDocument()
        xml.version = "1.0"
        xml.characterEncoding = "UTF-8"
        let dtd = XMLDTD()
        dtd.name = "score-partwise"
        dtd.publicID = "-//Recordare//DTD MusicXML 3.1 Partwise//EN"
        dtd.systemID = "http://www.musicxml.org/dtds/partwise.dtd"
        xml.dtd = dtd
        
        let root = XMLElement(name: "score-partwise")
        let att = XMLNode(kind: .attribute)
        att.name = "version"
        att.stringValue = "3.1"
        root.addAttribute(att)
        
        let partListE = XMLElement(name: "part-list")
        
        let partE = XMLElement(name: "score-part")
        let partAtt = XMLNode(kind: .attribute)
        partAtt.name = "id"
        partAtt.stringValue = "P1"
        partE.addAttribute(partAtt)
        
        let partNameE = XMLElement(name: "part-name")
        partNameE.stringValue = "Music"
        partE.addChild(partNameE)
        
        partListE.addChild(partE)
        
        root.addChild(partListE)
        
        let part1E = XMLElement(name: "part")
        let part1Att = XMLNode(kind: .attribute)
        part1Att.name = "id"
        part1Att.stringValue = "P1"
        part1E.addAttribute(part1Att)
        
        func appendMeasure(index: Int,
                           isFirst: Bool,
                           fifthsNumber: Int?,
                           tempo: Double?,
                           notes: [MeasureNote]) {
            let measureE = XMLElement(name: "measure")
            let measureAtt = XMLNode(kind: .attribute)
            measureAtt.name = "number"
            measureAtt.stringValue = "\(index + 1)"
            measureE.addAttribute(measureAtt)
            
            if isFirst || fifthsNumber != nil || tempo != nil {
                if isFirst || fifthsNumber != nil {
                    let attsE = XMLElement(name: "attributes")
                    
                    if isFirst {
                        let divisionsE = XMLElement(name: "divisions")
                        divisionsE.stringValue = "16"
                        attsE.addChild(divisionsE)
                    }
                    
                    if let fifthsNumber = fifthsNumber {
                        let keyE = XMLElement(name: "key")
                        let fifthsE = XMLElement(name: "fifths")
                        fifthsE.stringValue = "\(fifthsNumber)"
                        keyE.addChild(fifthsE)
                        attsE.addChild(keyE)
                    }
                    
                    if isFirst {
                        let timeE = XMLElement(name: "time")
                        let beatsE = XMLElement(name: "beats")
                        beatsE.stringValue = "4"
                        timeE.addChild(beatsE)
                        let beatTypeE = XMLElement(name: "beat-type")
                        beatTypeE.stringValue = "4"
                        timeE.addChild(beatTypeE)
                        attsE.addChild(timeE)
                        
                        let clefE = XMLElement(name: "clef")
                        let signE = XMLElement(name: "sign")
                        signE.stringValue = "G"
                        clefE.addChild(signE)
                        let lineE = XMLElement(name: "line")
                        lineE.stringValue = "2"
                        clefE.addChild(lineE)
                        attsE.addChild(clefE)
                    }
                    
                    measureE.addChild(attsE)
                }
                if isFirst || tempo != nil {
                    let directionE = XMLElement(name: "direction")
                    let directionAtt = XMLNode(kind: .attribute)
                    directionAtt.name = "placement"
                    directionAtt.stringValue = "above"
                    directionE.addAttribute(directionAtt)
                    
                    let directionTypeE = XMLElement(name: "direction-type")
                    
                    let metronomeE = XMLElement(name: "metronome")
                    
                    if isFirst {
                        let beatUnitE = XMLElement(name: "beat-unit")
                        beatUnitE.stringValue = "quarter"
                        metronomeE.addChild(beatUnitE)
                    }
                    
                    if let tempo = tempo {
                        let perMinuteE = XMLElement(name: "per-minute")
                        perMinuteE.stringValue = String(format: "%g", tempo)
                        metronomeE.addChild(perMinuteE)
                    }
                    
                    directionTypeE.addChild(metronomeE)
                    directionE.addChild(directionTypeE)
                    
                    if let tempo = tempo {
                        let soundE = XMLElement(name: "sound")
                        let soundAtt = XMLNode(kind: .attribute)
                        soundAtt.name = "tempo"
                        soundAtt.stringValue = String(format: "%g", tempo)
                        soundE.addAttribute(soundAtt)
                        directionE.addChild(soundE)
                    }
                    
                    measureE.addChild(directionE)
                }
            }
            
            if !notes.isEmpty {
                for note in notes {
                    let noteE = XMLElement(name: "note")
                    if let pitch = note.pitch {
                        let pitchE = XMLElement(name: "pitch")
                        let stepE = XMLElement(name: "step")
                        stepE.stringValue = pitch.lyricsUnison.step.name
                        pitchE.addChild(stepE)
                        if pitch.lyricsUnison.accidental == .sharp {
                            let alterE = XMLElement(name: "alter")
                            alterE.stringValue = "1"
                            pitchE.addChild(alterE)
                        } else if pitch.lyricsUnison.accidental == .flat {
                            let alterE = XMLElement(name: "alter")
                            alterE.stringValue = "-1"
                            pitchE.addChild(alterE)
                        }
                        let octaveE = XMLElement(name: "octave")
                        octaveE.stringValue = "\(pitch.octave)"
                        pitchE.addChild(octaveE)
                        noteE.addChild(pitchE)
                    } else {
                        let restE = XMLElement(name: "rest")
                        noteE.addChild(restE)
                    }
                    let durationE = XMLElement(name: "duration")
                    durationE.stringValue = "\(note.type.rawValue)"
                    noteE.addChild(durationE)
                    let typeE = XMLElement(name: "type")
                    typeE.stringValue = note.type.name
                    noteE.addChild(typeE)
                    if note.type.isDot {
                        let dotE = XMLElement(name: "dot")
                        noteE.addChild(dotE)
                    }
                    if note.isBreath ||
                        (note.pitch != nil && ((note.isStartTie || note.isEndTie)
                         && !(note.isStartTie && note.isEndTie))) {
                        
                        let notationsE = XMLElement(name: "notations")
                        if note.isBreath {
                            let articulationsE = XMLElement(name: "articulations")
                            let breathmarkE = XMLElement(name: "breath-mark")
                            articulationsE.addChild(breathmarkE)
                            notationsE.addChild(articulationsE)
                        }
                        if !(note.isStartTie && note.isEndTie) {
                            if note.isStartTie {
                                let tiedE = XMLElement(name: "tied")
                                let typeAtt = XMLNode(kind: .attribute)
                                typeAtt.name = "type"
                                typeAtt.stringValue = "start"
                                tiedE.addAttribute(typeAtt)
                                notationsE.addChild(tiedE)
                            }
                            if note.isEndTie {
                                let tiedE = XMLElement(name: "tied")
                                let typeAtt = XMLNode(kind: .attribute)
                                typeAtt.name = "type"
                                typeAtt.stringValue = "stop"
                                tiedE.addAttribute(typeAtt)
                                notationsE.addChild(tiedE)
                            }
                        }
                        noteE.addChild(notationsE)
                    }
                    if !note.lyric.isEmpty {
                        let lyricE = XMLElement(name: "lyric")
                        let syllabicE = XMLElement(name: "syllabic")
                        syllabicE.stringValue = "single"
                        lyricE.addChild(syllabicE)
                        let textE = XMLElement(name: "text")
                        textE.stringValue = note.lyric
                        lyricE.addChild(textE)
                        noteE.addChild(lyricE)
                    }
                    measureE.addChild(noteE)
                }
            }
            
            part1E.addChild(measureE)
        }
        
        var oldFifthsNumber: Int?, oldTempo: Double?
        for (i, measure) in measures.enumerated() {
            let fifthsNumber = measure.fifthsNumber != oldFifthsNumber ? measure.fifthsNumber : nil
            let tempo = measure.tempo != oldTempo ? measure.tempo : nil
            appendMeasure(index: i,
                          isFirst: i == 0,
                          fifthsNumber: fifthsNumber,
                          tempo: tempo, notes: measure.notes)
            
            oldFifthsNumber = measure.fifthsNumber
            oldTempo = measure.tempo
        }
        
        root.addChild(part1E)
        
        xml.setRootElement(root)
        
        return xml.xmlData(options: .nodePrettyPrint)
    }
}
