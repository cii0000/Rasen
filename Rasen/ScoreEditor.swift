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

protocol TimelineView: View, TempoType {
    func x(atBeat beat: Rational) -> Double
    func x(atBeat beat: Double) -> Double
    func x(atSec sec: Rational) -> Double
    func x(atSec sec: Double) -> Double
    func width(atDurBeat durBeat: Rational) -> Double
    func width(atDurBeat durBeat: Double) -> Double
    func width(atDurSec durSec: Rational) -> Double
    func width(atDurSec durSec: Double) -> Double
    func beat(atX x: Double, interval: Rational) -> Rational
    func beat(atX x: Double) -> Rational
    func beat(atX x: Double) -> Double
    func durBeat(atWidth w: Double) -> Double
    func sec(atX x: Double, interval: Rational) -> Rational
    func sec(atX x: Double) -> Rational
    var origin: Point { get }
    var frameRate: Int { get }
    func containsTimeline(_ p: Point) -> Bool
    var timeLineCenterY: Double { get }
    var beatRange: Range<Rational>? { get }
    var localBeatRange: Range<Rational>? { get }
}
extension TimelineView {
    func x(atBeat beat: Rational) -> Double {
        x(atBeat: Double(beat))
    }
    func x(atBeat beat: Double) -> Double {
        beat * Sheet.beatWidth + Sheet.textPadding.width - origin.x
    }
    func x(atSec sec: Rational) -> Double {
        x(atBeat: beat(fromSec: sec))
    }
    func x(atSec sec: Double) -> Double {
        x(atBeat: beat(fromSec: sec))
    }
    
    func width(atDurBeat durBeat: Rational) -> Double {
        width(atDurBeat: Double(durBeat))
    }
    func width(atDurBeat durBeat: Double) -> Double {
        durBeat * Sheet.beatWidth
    }
    func width(atDurSec durSec: Rational) -> Double {
        width(atDurBeat: beat(fromSec: durSec))
    }
    func width(atDurSec durSec: Double) -> Double {
        width(atDurBeat: beat(fromSec: durSec))
    }
    
    func beat(atX x: Double, interval: Rational) -> Rational {
        Rational(beat(atX: x), intervalScale: interval)
    }
    func beat(atX x: Double) -> Rational {
        beat(atX: x, interval: Rational(1, frameRate))
    }
    func beat(atX x: Double) -> Double {
        (x - Sheet.textPadding.width) / Sheet.beatWidth
    }
    func durBeat(atWidth w: Double) -> Double {
        w / Sheet.beatWidth
    }
    
    func sec(atX x: Double, interval: Rational) -> Rational {
        sec(fromBeat: beat(atX: x, interval: interval))
    }
    func sec(atX x: Double) -> Rational {
        sec(atX: x, interval: Rational(1, frameRate))
    }
    
    func containsSec(_ p: Point, maxDistance: Double) -> Bool {
        guard let beatRange else { return false }
        let secRange = secRange(fromBeat: beatRange)
        let sy = timeLineCenterY - Sheet.timelineHalfHeight + origin.y
        for sec in Int(secRange.start.rounded(.up)) ..< Int(secRange.end.rounded(.up)) {
            let sec = Rational(sec)
            guard secRange.contains(sec) else { continue }
            let secX = x(atSec: sec) + origin.x
            if Point(secX, sy).distance(p) < maxDistance {
                return true
            }
        }
        return false
    }
    
    func mainLineDistance(_ p: Point) -> Double {
        abs(p.y - timeLineCenterY)
    }
    func containsMainLine(_ p: Point, distance: Double) -> Bool {
        guard containsTimeline(p) else { return false }
        return mainLineDistance(p) < distance
    }
}
protocol SpectrgramView: TimelineView {
    var pcmBuffer: PCMBuffer? { get }
    var spectrgramY: Double { get }
}

final class ScoreAdder: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if let sheetView = document.madeSheetView(at: p) {
                let inP = sheetView.convertFromWorld(p)
                let option = ScoreOption(tempo: sheetView.nearestTempo(at: inP) ?? Music.defaultTempo,
                                         enabled: true)
                
                sheetView.newUndoGroup()
                sheetView.set(option)
                
                document.updateEditorNode()
                document.updateSelects()
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class ScoreSlider: DragEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    enum SlideType {
        case startNoteBeat, endNoteBeat, note,
             attack, decay, release,
             sprol,
             keyBeats, endBeat
    }
    
    private let editableInterval = 5.0
    private let editableTempoInterval = 10.0
    
    private var node = Node()
    private var notePlayer: NotePlayer?
    private var sheetView: SheetView?
    private var type: SlideType?, overtoneType = OvertoneType.evenVolm
    private var beganSP = Point(), beganTime = Rational(0), beganSheetP = Point()
    private var beganLocalStartPitch = Rational(0), secI = 0, noteI: Int?, pitI: Int?, keyBeatI: Int?,
                beganBeatRange: Range<Rational>?,
                playerBeatNoteIndexes = [Int](),
                beganDeltaNoteBeat = Rational(),
                oldNotePitch: Rational?, oldBeat: Rational?,
                minScorePitch = Rational(0), maxScorePitch = Rational(0)
    private var beganStartBeat = Rational(0), beganPitch: Rational?,  beganBeatX = 0.0, beganPitchY = 0.0
    private var beganTone = Tone(), beganOvertone = Overtone(), beganEnvelope = Envelope()
    private var sprolI: Int?, beganSprol = Sprol()
    private var beganScoreOption: ScoreOption?
    private var beganNotes = [Int: Note]()
    private var beganNotePits = [UUID: [Int: (note: Note, pit: Pit, pits: [Int: Pit])]]()
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                let inP = sheetView.convertFromWorld(p)
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                
                beganSP = sp
                beganSheetP = inP
                self.sheetView = sheetView
                beganTime = sheetView.animationView.beat(atX: inP.x)
                
                func updatePlayer(from vs: [Note.PitResult], in sheetView: SheetView) {
                    let stereo = Stereo(volm: sheetView.isPlaying ? 0.1 : 1)
                    if let notePlayer = sheetView.notePlayer {
                        self.notePlayer = notePlayer
                        notePlayer.notes = vs
                        notePlayer.stereo = stereo
                    } else {
                        notePlayer = try? NotePlayer(notes: vs, stereo: stereo)
                        sheetView.notePlayer = notePlayer
                    }
                    notePlayer?.play()
                }
                
                let scoreP = scoreView.convert(inP, from: sheetView.node)
                if let noteI = scoreView.noteIndex(at: scoreP, scale: document.screenToWorldScale,
                                                   enabledRelease: true) {
                    let note = score.notes[noteI]
                    
                    let interval = document.currentNoteBeatInterval
                    let nsBeat = scoreView.beat(atX: inP.x, interval: interval)
                    beganStartBeat = nsBeat
                    self.noteI = noteI
                    
                    let result = scoreView.hitTestFullEdit(scoreP, scale: document.screenToWorldScale,
                                                           at: noteI)
                    switch result {
                    case .attack:
                        type = .attack
                        
                        if document.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: document.selections)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        } else {
                            let id = score.notes[noteI].envelope.id
                            beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                                if id == $1.element.envelope.id {
                                    $0[$1.offset] = $1.element
                                }
                            }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                        beganEnvelope = score.notes[noteI].envelope
                    case .decay:
                        type = .decay
                        
                        if document.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: document.selections)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        } else {
                            let id = score.notes[noteI].envelope.id
                            beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                                if id == $1.element.envelope.id {
                                    $0[$1.offset] = $1.element
                                }
                            }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                        beganEnvelope = score.notes[noteI].envelope
                    case .release:
                        type = .release
                        
                        if document.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: document.selections)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        } else {
                            let id = score.notes[noteI].envelope.id
                            beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                                if id == $1.element.envelope.id {
                                    $0[$1.offset] = $1.element
                                }
                            }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                        beganEnvelope = score.notes[noteI].envelope
                    case .sprol(let pitI, let sprolI):
                        type = .sprol
                        
                        beganTone = score.notes[noteI].pits[pitI].tone
                        self.sprolI = sprolI
                        self.beganSprol = scoreView.nearestSprol(at: scoreP, at: noteI)
                        self.noteI = noteI
                        self.pitI = pitI
                        
                        func updatePitsWithSelection(noteI: Int, pitI: Int?, _ type: PitIDType) {
                            var noteAndPitIs: [Int: [Int]]
                            if document.isSelect(at: p) {
                                noteAndPitIs = sheetView.noteAndPitIndexes(from: document.selections,
                                                                           enabledAll: false)
                                if let pitI {
                                    if noteAndPitIs[noteI] != nil {
                                        if noteAndPitIs[noteI]!.contains(pitI) {
                                            noteAndPitIs[noteI]?.append(pitI)
                                        }
                                    } else {
                                        noteAndPitIs[noteI] = [pitI]
                                    }
                                } else {
                                    noteAndPitIs[noteI] = score.notes[noteI].pits.count.array
                                }
                            } else {
                                if let pitI {
                                    let id = score.notes[noteI].pits[pitI][type]
                                    noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int]]()) {
                                        $0[$1.offset] = $1.element.pits.enumerated().compactMap { (pitI, pit) in
                                            pit[type] == id ? pitI : nil
                                        }
                                    }
                                } else {
                                    noteAndPitIs = [noteI: score.notes[noteI].pits.count.array]
                                }
                            }
                            
                            beganNotePits = noteAndPitIs.reduce(into: .init()) {
                                for pitI in $1.value {
                                    let pit = score.notes[$1.key].pits[pitI]
                                    let id = pit[type]
                                    if $0[id] != nil {
                                        if $0[id]![$1.key] != nil {
                                            $0[id]![$1.key]!.pits[pitI] = pit
                                        } else {
                                            $0[id]![$1.key] = (score.notes[$1.key], pit, [pitI: pit])
                                        }
                                    } else {
                                        $0[id] = [$1.key: (score.notes[$1.key], pit, [pitI: pit])]
                                    }
                                }
                            }
                        }
                        
                        updatePitsWithSelection(noteI: noteI, pitI: pitI, .tone)
                        
                        let noteIsSet = Set(beganNotePits.values.flatMap { $0.keys }).sorted()
                        let vs = score.noteIAndPits(atBeat: note.pits[pitI].beat + note.beatRange.start,
                                                    in: noteIsSet)
                        playerBeatNoteIndexes = vs.map { $0.noteI }
                        
                        updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                        
                        document.cursor = .circle(string: Pitch(value: .init(beganTone.spectlope.sprols[sprolI].pitch, intervalScale: Sheet.fullEditPitchInterval)).octaveString(hidableDecimal: false))
                    case nil:
                        let nsx = scoreView.x(atBeat: note.beatRange.start)
                        let nex = scoreView.x(atBeat: note.beatRange.end)
                        let nfsw = (nex - nsx) * document.worldToScreenScale
                        let dx = nfsw.clipped(min: 3, max: 30, newMin: 1, newMax: 10)
                        * document.screenToWorldScale
                        
                        type = if scoreP.x - nsx < dx {
                            .startNoteBeat
                        } else if scoreP.x - nex > -dx {
                            .endNoteBeat
                        } else {
                            .note
                        }
                        
                        let interval = document.currentNoteBeatInterval
                        let nsBeat = scoreView.beat(atX: inP.x, interval: interval)
                        beganPitch = note.pitch
                        beganStartBeat = nsBeat
                        let dBeat = note.beatRange.start - note.beatRange.start.interval(scale: interval)
                        beganDeltaNoteBeat = -dBeat
                        beganBeatRange = note.beatRange
                        oldNotePitch = note.pitch
                        
                        if type == .startNoteBeat || type == .note {
                            beganBeatX = scoreView.x(atBeat: note.beatRange.start)
                        } else {
                            beganBeatX = scoreView.x(atBeat: note.beatRange.end)
                        }
                        beganPitchY = scoreView.y(fromPitch: note.pitch)
                        
                        if document.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: document.selections)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                        let playerBeat: Rational = switch type {
                        case .startNoteBeat: note.beatRange.start
                        case .endNoteBeat: note.beatRange.end
                        default: scoreView.beat(atX: scoreP.x)
                        }
                        let vs = score.noteIAndPits(atBeat: playerBeat,
                                                    in: Set(beganNotes.keys).sorted())
                        playerBeatNoteIndexes = vs.map { $0.noteI }
                        
                        updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                    }
                    
                    if type == .startNoteBeat || type == .endNoteBeat || type == .note {
                        let result = note.pitResult(atBeat: Double(nsBeat - note.beatRange.start))
                        let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                        document.cursor = .circle(string: Pitch(value: cPitch).octaveString())
                    }
                } else if let keyBeatI = scoreView.keyBeatIndex(at: scoreP, scale: document.screenToWorldScale) {
                    type = .keyBeats
                    
                    self.keyBeatI = keyBeatI
                    beganScoreOption = score.option
                    beganBeatX = scoreView.x(atBeat: score.keyBeats[keyBeatI])
                } else if abs(scoreP.x - scoreView.x(atBeat: score.durBeat)) < document.worldKnobEditDistance {
                    
                    type = .endBeat
                    
                    beganScoreOption = sheetView.model.score.option
                    beganBeatX = scoreView.x(atBeat: score.durBeat)
                }
            }
        case .changed:
            if let sheetView, let type {
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                let sheetP = sheetView.convertFromWorld(p)
                let scoreP = scoreView.convertFromWorld(p)
                
                switch type {
                case .startNoteBeat:
                    if let beganPitch, let beganBeatRange {
                        let beatInterval = document.currentNoteBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: document.currentNotePitchInterval)
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                        if pitch != oldNotePitch || nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeatRange.start
                            let dPitch = pitch - beganPitch
                            
                            let endBeat = sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: beatInterval)
                            
                            for (ni, beganNote) in beganNotes {
                                guard ni < score.notes.count else { continue }
                                
                                var note = beganNote
                                note.pitch = (dPitch + beganNote.pitch)
                                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                                
                                let nsBeat = min(beganNote.beatRange.start + dBeat, endBeat)
                                let neBeat = beganNote.beatRange.end
                                let beatRange = nsBeat < neBeat ? nsBeat ..< neBeat : neBeat ..< nsBeat
                                note.beatRange = beatRange
                                
                                scoreView[ni] = note
                            }
                            
                            oldBeat = nsBeat
                            
                            if pitch != oldNotePitch {
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.pitResult(atBeat: nsBeat, at: $0)
                                }
                                oldNotePitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(nsBeat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                                    document.cursor = .circle(string: Pitch(value: cPitch).octaveString())
                                }
                            }
                            document.updateSelects()
                        }
                    }
                case .endNoteBeat:
                    if let beganPitch, let beganBeatRange {
                        let beatInterval = document.currentNoteBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: document.currentNotePitchInterval)
                        let neBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                        if pitch != oldNotePitch || neBeat != oldBeat {
                            let dBeat = neBeat - beganBeatRange.end
                            let dPitch = pitch - beganPitch
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: beatInterval)
                            for (ni, beganNote) in beganNotes {
                                guard ni < score.notes.count else { continue }
                                
                                var note = beganNote
                                note.pitch = (dPitch + beganNote.pitch)
                                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                                
                                let nsBeat = beganNote.beatRange.start
                                let neBeat = max(beganNote.beatRange.end + dBeat, startBeat)
                                let beatRange = nsBeat < neBeat ? nsBeat ..< neBeat : neBeat ..< nsBeat
                                note.beatRange = beatRange
                                
                                scoreView[ni] = note
                            }
                            
                            oldBeat = neBeat
                            
                            if pitch != oldNotePitch {
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.pitResult(atBeat: neBeat, at: $0)
                                }
                                oldNotePitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(neBeat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                                    document.cursor = .circle(string: Pitch(value: cPitch).octaveString())
                                }
                            }
                            document.updateSelects()
                        }
                    }
                case .note:
                    if let beganPitch, let beganBeatRange {
                        let beatInterval = document.currentNoteBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: document.currentNotePitchInterval)
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                        if pitch != oldNotePitch || nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeatRange.start
                            let dPitch = pitch - beganPitch
                            
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: beatInterval)
                            let endBeat = sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: beatInterval)
                           
                            for (ni, beganNote) in beganNotes {
                                guard ni < score.notes.count else { continue }
                                
                                let nBeat = dBeat + beganNote.beatRange.start
                                
                                var note = beganNote
                                note.pitch = (dPitch + beganNote.pitch)
                                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                                note.beatRange.start = max(min(nBeat, endBeat), startBeat - beganNote.beatRange.length)
                                
                                scoreView[ni] = note
                            }
                            
                            oldBeat = nsBeat
                            
                            if pitch != oldNotePitch {
                                let beat: Rational = scoreView.beat(atX: scoreP.x)
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.pitResult(atBeat: beat, at: $0)
                                }
                                oldNotePitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(beat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                                    document.cursor = .circle(string: Pitch(value: cPitch).octaveString())
                                }
                            }
                            document.updateSelects()
                        }
                    }
                    
                case .attack:
                    let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                    let attackSec = (beganEnvelope.attackSec + score.sec(fromBeat: dBeat))
                        .clipped(min: 0, max: 10)
                    
                    for ni in beganNotes.keys {
                        guard ni < score.notes.count else { continue }
                        var env = scoreView.model.notes[ni].envelope
                        env.attackSec = attackSec
                        env.id = beganEnvelope.id
                        scoreView[ni].envelope = env
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) }, with: scoreView.model)
                case .decay:
                    let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                    let decaySec = (beganEnvelope.decaySec + score.sec(fromBeat: dBeat))
                        .clipped(min: 0, max: 10)
                    
                    for ni in beganNotes.keys {
                        guard ni < score.notes.count else { continue }
                        var env = scoreView.model.notes[ni].envelope
                        env.decaySec = decaySec
                        env.id = beganEnvelope.id
                        scoreView[ni].envelope = env
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) }, with: scoreView.model)
                case .release:
                    let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                    let releaseSec = (beganEnvelope.releaseSec + score.sec(fromBeat: dBeat))
                        .clipped(min: 0, max: 10)
                    
                    for ni in beganNotes.keys {
                        guard ni < score.notes.count else { continue }
                        var env = scoreView.model.notes[ni].envelope
                        env.releaseSec = releaseSec
                        env.id = beganEnvelope.id
                        scoreView[ni].envelope = env
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) }, with: scoreView.model)
                    
                case .sprol:
                    if let noteI, noteI < score.notes.count,
                       let pitI, pitI < score.notes[noteI].pits.count,
                       let sprolI, sprolI < score.notes[noteI].pits[pitI].tone.spectlope.count {
                       
                        let pitch = scoreView.spectlopePitch(at: scoreP, at: noteI)
                        
                        var tone = beganTone
                        let opspx = tone.spectlope.sprols[sprolI].pitch + pitch - beganSprol.pitch
                        let pspx = opspx.clipped(min: sprolI - 1 >= 0 ? tone.spectlope.sprols[sprolI - 1].pitch : Score.doubleMinPitch,
                                                 max: sprolI + 1 < tone.spectlope.count ? tone.spectlope.sprols[sprolI + 1].pitch : Score.doubleMaxPitch)
                        tone.spectlope.sprols[sprolI].pitch = pspx
                        tone.id = .init()
                        
                        for (_, v) in beganNotePits {
                            let nid = UUID()
                            for (noteI, nv) in v {
                                guard noteI < score.notes.count else { continue }
                                var note = scoreView[noteI]
                                for (pitI, _) in nv.pits {
                                    guard pitI < score.notes[noteI].pits.count,
                                          sprolI < note.pits[pitI].tone.spectlope.count else { continue }
                                    note.pits[pitI].tone = tone
                                    note.pits[pitI].tone.id = nid
                                }
                                scoreView[noteI] = note
                            }
                        }
                        
                        notePlayer?.notes = playerBeatNoteIndexes.map {
                            scoreView.pitResult(atBeat: beganStartBeat, at: $0)
                        }
                        
                        document.cursor = .circle(string: Pitch(value: .init(pspx, intervalScale: Sheet.fullEditPitchInterval)).octaveString(hidableDecimal: false))
                    }
                    
                case .keyBeats:
                    if let keyBeatI, keyBeatI < score.keyBeats.count, let beganScoreOption {
                        let interval = document.currentNoteBeatInterval
                        let nBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                   interval: interval)
                        if nBeat != oldBeat {
                            let dBeat = nBeat - beganScoreOption.keyBeats[keyBeatI]
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganScoreOption.keyBeats[keyBeatI] + dBeat, startBeat)
                            
                            oldBeat = nkBeat
                            
                            var option = beganScoreOption
                            option.keyBeats[keyBeatI] = nkBeat
                            option.keyBeats.sort()
                            scoreView.option = option
                            document.updateSelects()
                        }
                    }
                case .endBeat:
                    if let beganScoreOption {
                        let interval = document.currentNoteBeatInterval
                        let nBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                   interval: interval)
                        if nBeat != oldBeat {
                            let dBeat = nBeat - beganScoreOption.durBeat
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganScoreOption.durBeat + dBeat, startBeat)
                            
                            oldBeat = nkBeat
                            scoreView.option.durBeat = nkBeat
                            document.updateSelects()
                        }
                    }
                }
            }
        case .ended:
            notePlayer?.stop()
            node.removeFromParent()
            
            if let sheetView {
                if type == .keyBeats || type == .endBeat {
                    sheetView.updatePlaying()
                    if let beganScoreOption, sheetView.model.score.option != beganScoreOption {
                        sheetView.newUndoGroup()
                        sheetView.capture(sheetView.model.score.option,
                                          old: beganScoreOption)
                    }
                } else {
                    var isNewUndoGroup = false
                    func updateUndoGroup() {
                        if !isNewUndoGroup {
                            sheetView.newUndoGroup()
                            isNewUndoGroup = true
                        }
                    }
                    
                    let scoreView = sheetView.scoreView
                    let score = scoreView.model
                    var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                    for (ni, beganNote) in beganNotes.sorted(by: { $0.key < $1.key }) {
                        guard ni < score.notes.count else { continue }
                        let note = score.notes[ni]
                        if beganNote != note {
                            noteIVs.append(.init(value: note, index: ni))
                            oldNoteIVs.append(.init(value: beganNote, index: ni))
                        }
                    }
                    if !noteIVs.isEmpty {
                        updateUndoGroup()
                        sheetView.capture(noteIVs, old: oldNoteIVs)
                    }
                    
                    if let beganScoreOption, sheetView.model.score.option != beganScoreOption {
                        updateUndoGroup()
                        sheetView.capture(sheetView.model.score.option,
                                          old: beganScoreOption)
                    }
                    
                    if !beganNotePits.isEmpty {
                        let scoreView = sheetView.scoreView
                        let score = scoreView.model
                        var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                        
                        let beganNoteIAndNotes = beganNotePits.reduce(into: [Int: Note]()) {
                            for (noteI, v) in $1.value {
                                $0[noteI] = v.note
                            }
                        }
                        for (ni, beganNote) in beganNoteIAndNotes {
                            guard ni < score.notes.count else { continue }
                            let note = scoreView.model.notes[ni]
                            if beganNote != note {
                                noteIVs.append(.init(value: note, index: ni))
                                oldNoteIVs.append(.init(value: beganNote, index: ni))
                            }
                        }
                        if !noteIVs.isEmpty {
                            updateUndoGroup()
                            sheetView.capture(noteIVs, old: oldNoteIVs)
                        }
                    }
                }
            }
            
            document.cursor = Document.defaultCursor
        }
    }
}

struct ScoreLayout {
    static let pitchHeight = 3.0
    static let noteHeight = 2.0
}

final class ScoreView: TimelineView {
    typealias Model = Score
    typealias Binder = SheetBinder
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    var isFullEdit = false {
        didSet {
            guard isFullEdit != oldValue else { return }
            timelineFullEditBorderNode.isHidden = !isFullEdit
            pitsFullEditNode.isHidden = !isFullEdit
            pitsNode.isHidden = isFullEdit
            
            notesNode.children.forEach {
                $0.children.forEach {
                    if $0.name == "isFullEdit" {
                        $0.isHidden = !isFullEdit
                    }
                }
            }
        }
    }
    
    let currentPeakVolmNode = Node(lineWidth: 3, lineType: .color(.background))
    let timeNode = Node(lineWidth: 4, lineType: .color(.content))
    
    var peakVolm = 0.0 {
        didSet {
            guard peakVolm != oldValue else { return }
            updateFromPeakVolm()
        }
    }
    func updateFromPeakVolm() {
        let frame = mainFrame
        let y = frame.height// * volm
        currentPeakVolmNode.path = Path([Point(), Point(0, y)])
        if peakVolm < Audio.headroomVolm {
            currentPeakVolmNode.lineType = .color(Color(lightness: (1 - peakVolm) * 100))
//            currentPeakVolmNode.lineType = .color(.background)
        } else {
            currentPeakVolmNode.lineType = .color(.warning)
        }
    }
    
    var bounds = Sheet.defaultBounds {
        didSet {
            guard bounds != oldValue else { return }
            updateTimeline()
            updateScore()
            updateClippingNode()
        }
    }
    var mainFrame: Rect {
        bounds.insetBy(dx: Sheet.textPadding.width, dy: 32)
    }
    
    let octaveNode = Node(), draftNotesNode = Node(), notesNode = Node()
    let timelineContentNode = Node(fillType: .color(.content))
    let timelineSubBorderNode = Node(fillType: .color(.subBorder))
    let timelineBorderNode = Node(fillType: .color(.border))
    let timelineFullEditBorderNode = Node(isHidden: true, fillType: .color(.border))
    let chordNode = Node(fillType: .color(.subBorder))
    let pitsNode = Node(isHidden: true, fillType: .color(.background))
    let pitsFullEditNode = Node(isHidden: true, fillType: .color(.background))
    let clippingNode = Node(isHidden: true, lineWidth: 4, lineType: .color(.warning))
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        timeNode.children = [currentPeakVolmNode]
        
        node = Node(children: [timelineBorderNode,
                               timelineFullEditBorderNode,
                               timelineSubBorderNode, chordNode, octaveNode,
                               timelineContentNode,
                               draftNotesNode, notesNode,
                               pitsFullEditNode, pitsNode,
                               timeNode, clippingNode])
        updateClippingNode()
        updateTimeline()
        updateScore()
        updateDraftNotes()
    }
}
extension ScoreView {
    var pitchHeight: Double { ScoreLayout.pitchHeight }
    
    func updateWithModel() {
        updateTimeline()
        updateScore()
        updateDraftNotes()
    }
    func updateClippingNode() {
        var parent: Node?
        node.allParents { node, stop in
            if node.bounds != nil {
                parent = node
                stop = true
            }
        }
        if let parent,
           let pb = parent.bounds, let b = clippableBounds {
            let edges = convert(pb, from: parent).intersectionEdges(b)
            
            if !edges.isEmpty {
                clippingNode.isHidden = false
                clippingNode.path = .init(edges)
            } else {
                clippingNode.isHidden = true
            }
        } else {
            clippingNode.isHidden = true
        }
    }
    func updateTimeline() {
        if model.enabled {
            let (contentPathlines, subBorderPathlines,
                 borderPathlines, fullEditBorderPathlines) = self.timelinePathlinesTuple()
            timelineContentNode.path = .init(contentPathlines)
            timelineSubBorderNode.path = .init(subBorderPathlines)
            timelineBorderNode.path = .init(borderPathlines)
            timelineFullEditBorderNode.path = .init(fullEditBorderPathlines)
        } else {
            timelineContentNode.path = .init()
            timelineSubBorderNode.path = .init()
            timelineBorderNode.path = .init()
            timelineFullEditBorderNode.path = .init()
        }
    }
    func updateChord() {
        if model.enabled {
            chordNode.path = .init(chordPathlines())
        } else {
            chordNode.path = .init()
        }
    }
    func updateNotes() {
        if model.enabled {
            octaveNode.children = model.notes.map { octaveNode(from: $0) }
            notesNode.children = model.notes.map { noteNode(from: $0) }
        } else {
            notesNode.children = []
        }
    }
    func updateDraftNotes() {
        if model.enabled {
            draftNotesNode.children = model.draftNotes.map { draftNoteNode(from: $0) }
        } else {
            draftNotesNode.children = []
        }
    }
    func updateScore() {
        updateChord()
        updateNotes()
    }
    
    var frameRate: Int { Keyframe.defaultFrameRate }
    
    var tempo: Rational {
        get { model.tempo }
        set {
            binder[keyPath: keyPath].tempo = newValue
            updateTimeline()
        }
    }
    
    var origin: Point { .init() }
    var timeLineCenterY: Double { Animation.timelineY }
    var beatRange: Range<Rational>? {
        model.beatRange
    }
    var localBeatRange: Range<Rational>? {
        model.localMaxBeatRange
    }
    
    func pitch(atY y: Double, interval: Rational) -> Rational {
        Rational((y - mainFrame.minY) / pitchHeight, intervalScale: interval)
    }
    func smoothPitch(atY y: Double) -> Double? {
        (y - mainFrame.minY) / pitchHeight
    }
    func y(fromPitch pitch: Rational) -> Double {
        Double(pitch) * pitchHeight + mainFrame.minY
    }
    func y(fromPitch pitch: Double) -> Double {
        pitch * pitchHeight + mainFrame.minY
    }
    
    func pitResult(atBeat beat: Rational, at noteI: Int) -> Note.PitResult {
        self[noteI].pitResult(atBeat: .init(beat - self[noteI].beatRange.start))
    }
    
    var option: ScoreOption {
        get { model.option }
        set {
            unupdateModel.option = newValue
            updateTimeline()
            updateChord()
        }
    }
    
    func append(_ note: Note) {
        unupdateModel.notes.append(note)
        octaveNode.append(child: octaveNode(from: note))
        notesNode.append(child: noteNode(from: note))
        updateChord()
    }
    func insert(_ note: Note, at noteI: Int) {
        unupdateModel.notes.insert(note, at: noteI)
        notesNode.insert(child: noteNode(from: note), at: noteI)
        updateChord()
    }
    func insert(_ nivs: [IndexValue<Note>]) {
        unupdateModel.notes.insert(nivs)
        notesNode.children.insert(nivs.map { .init(value: noteNode(from: $0.value), index: $0.index) })
        octaveNode.children.insert(nivs.map { .init(value: octaveNode(from: $0.value), index: $0.index) })
        updateChord()
    }
    func replace(_ nivs: [IndexValue<Note>]) {
        unupdateModel.notes.replace(nivs)
        notesNode.children.replace(nivs.map { .init(value: noteNode(from: $0.value), index: $0.index) })
        octaveNode.children.replace(nivs.map { .init(value: octaveNode(from: $0.value), index: $0.index) })
        updateChord()
    }
    func remove(at noteI: Int) {
        unupdateModel.notes.remove(at: noteI)
        notesNode.remove(atChild: noteI)
        octaveNode.remove(atChild: noteI)
        updateChord()
    }
    func remove(at noteIs: [Int]) {
        unupdateModel.notes.remove(at: noteIs)
        noteIs.reversed().forEach { notesNode.remove(atChild: $0) }
        noteIs.reversed().forEach { octaveNode.remove(atChild: $0) }
        updateChord()
    }
    subscript(noteI: Int) -> Note {
        get {
            unupdateModel.notes[noteI]
        }
        set {
            unupdateModel.notes[noteI] = newValue
            notesNode.children[noteI] = noteNode(from: newValue)
            octaveNode.children[noteI] = octaveNode(from: newValue)
            updateChord()
        }
    }
    
    func insertDraft(_ nivs: [IndexValue<Note>]) {
        unupdateModel.draftNotes.insert(nivs)
        draftNotesNode.children.insert(nivs.map { .init(value: draftNoteNode(from: $0.value), index: $0.index) })
        updateChord()
    }
    func removeDraft(at noteIs: [Int]) {
        unupdateModel.draftNotes.remove(at: noteIs)
        noteIs.reversed().forEach { draftNotesNode.remove(atChild: $0) }
        updateChord()
    }
    
    func timelinePathlinesTuple() -> (contentPathlines: [Pathline],
                                      subBorderPathlines: [Pathline],
                                      borderPathlines: [Pathline],
                                      fullEditBorderPathlines: [Pathline]) {
        let score = model
        let sBeat = max(score.beatRange.start, -10000),
            eBeat = min(score.beatRange.end, 10000)
        let sx = self.x(atBeat: sBeat)
        let ex = self.x(atBeat: eBeat)
        
        let lw = 1.0
        let knobW = Sheet.knobWidth, knobH = Sheet.knobHeight
        let rulerH = Sheet.rulerHeight
        let pitchRange = Score.pitchRange
        let y = timeLineCenterY, timelineHalfHeight = Sheet.timelineHalfHeight
        let sy = y - timelineHalfHeight
        let ey = y + timelineHalfHeight
        
        var contentPathlines = [Pathline]()
        var subBorderPathlines = [Pathline]()
        var borderPathlines = [Pathline]()
        var fullEditBorderPathlines = [Pathline]()
        
        makeBeatPathlines(in: score.beatRange, sy: sy, ey: ey,
                          subBorderPathlines: &subBorderPathlines,
                          fullEditBorderPathlines: &fullEditBorderPathlines,
                          borderPathlines: &borderPathlines)
        
        
        makeBeatPathlines(in: score.beatRange, 
                          sy: self.y(fromPitch: pitchRange.start),
                          ey: self.y(fromPitch: pitchRange.end),
                          subBorderPathlines: &subBorderPathlines,
                          fullEditBorderPathlines: &fullEditBorderPathlines,
                          borderPathlines: &borderPathlines)
        
        let roundedSPitch = pitchRange.start.rounded(.down)
        let deltaPitch = Rational(1, 4)
        let pitchR1 = Rational(1)
        var cPitch = roundedSPitch
        while cPitch <= pitchRange.end {
            if cPitch >= pitchRange.start {
                let lw: Double = if cPitch % pitchR1 == 0 {
                    0.5
                } else {
                    0.125
                }
                
                let py = self.y(fromPitch: cPitch)
                let rect = Rect(x: sx, y: py - lw / 2, width: ex - sx, height: lw)
                if lw == 0.125 {
                    fullEditBorderPathlines.append(Pathline(rect))
                } else {
                    borderPathlines.append(Pathline(rect))
                }
            }
            cPitch += deltaPitch
        }
        
        for keyBeat in score.keyBeats {
            let nx = x(atBeat: keyBeat)
            contentPathlines.append(.init(Rect(x: nx - 1, y: y - knobH / 2,
                                               width: knobW, height: knobH)))
        }
        
        contentPathlines.append(.init(Rect(x: ex - 1, y: y - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: sx + 1, y: y - lw / 2,
                                           width: ex - sx - 2, height: lw)))
        
        let secRange = score.secRange
        for sec in Int(secRange.start.rounded(.up)) ..< Int(secRange.end.rounded(.up)) {
            let sec = Rational(sec)
            guard secRange.contains(sec) else { continue }
            let secX = x(atSec: sec)
            contentPathlines.append(.init(Rect(x: secX - lw / 2, y: sy - rulerH / 2,
                                               width: lw, height: rulerH)))
        }
        
        return (contentPathlines, subBorderPathlines, borderPathlines, fullEditBorderPathlines)
    }
    
    func chordPathlines() -> [Pathline] {
        let score = model
        let pitchRange = Score.pitchRange
        let sBeat = max(score.beatRange.start, -10000), eBeat = min(score.beatRange.end, 10000)
        let sx = self.x(atBeat: sBeat)
        let ex = self.x(atBeat: eBeat)
        let lw = 1.0
        
        var subBorderPathlines = [Pathline]()
        
        if let range = Range<Int>(pitchRange) {
            let unisonsSet = Set(score.notes.flatMap { $0.chordBeatRangeAndRoundedPitchs().map { $0.roundedPitch.mod(12) } })
            for pitch in range {
                guard unisonsSet.contains(pitch.mod(12)) else { continue }
                let py = self.y(fromPitch: Rational(pitch))
                subBorderPathlines.append(Pathline(Rect(x: sx, y: py - lw / 2,
                                                        width: ex - sx, height: lw)))
            }
        }
        
        let chordBeats = score.keyBeats
        guard !chordBeats.isEmpty else { return subBorderPathlines }
        
        let nChordBeats = chordBeats.filter { $0 < score.beatRange.end }.sorted()
        var preBeat: Rational = 0
        var chordRanges = nChordBeats.count.array.map {
            let v = preBeat ..< nChordBeats[$0]
            preBeat = nChordBeats[$0]
            return v
        }
        chordRanges.append(preBeat ..< score.beatRange.end)
        
        let sy = self.y(fromPitch: pitchRange.start), ey = self.y(fromPitch: pitchRange.end)
        subBorderPathlines += chordBeats.map {
            Pathline(Rect(x: x(atBeat: $0) - lw / 2, y: sy, width: lw, height: ey - sy))
        }
        
        let trs = chordRanges.map { ($0, score.chordPitches(atBeat: $0)) }
        for (tr, pitchs) in trs {
            let pitchs = pitchs.sorted()
            guard let chord = Chord(pitchs: pitchs) else { continue }
            
            let nsx = x(atBeat: tr.start), nex = x(atBeat: tr.end)
            let maxTyperCount = min(chord.typers.count, Int((nex - nsx) / 5))
            let d = 2.0, nw = 5.0 * Double(maxTyperCount - 1)
            
            let typers = chord.typers.sorted(by: { $0.type.rawValue > $1.type.rawValue })[..<maxTyperCount]
            
            if let range = Range<Int>(pitchRange) {
                let ilw = 2.0
                let unisonsSet = typers.reduce(into: Set<Int>()) { $0.formUnion($1.unisons) }
                for pitch in range {
                    let pitchUnison = pitch.mod(12)
                    guard unisonsSet.contains(pitchUnison) else { continue }
                    let py = self.y(fromPitch: Rational(pitch))
                    subBorderPathlines.append(Pathline(Rect(x: nsx, y: py - ilw / 2,
                                                            width: nex - nsx, height: ilw)))
                    
                    for (ti, typer) in typers.enumerated() {
                        if typer.unisons.contains(pitchUnison) {
                            let isInversion = typer.mainUnison == pitchUnison
                            
                            let tlw = 0.5
                            let x = -nw / 2 + 5.0 * Double(ti)
                            let fx = (nex + nsx) / 2 + x - lw / 2
                            let fy0 = py + 1, fy1 = py - 1 - d
                            func appendMain(lineWidth lw: Double) {
                                guard isInversion else { return }
                                let ilw = 1.0
                                subBorderPathlines.append(Pathline(Rect(x: fx - ilw, y: fy0 + d - ilw,
                                                                        width: lw + 2 * ilw, height: ilw)))
                                subBorderPathlines.append(Pathline(Rect(x: fx - ilw, y: fy1,
                                                                        width: lw + 2 * ilw, height: ilw)))
                            }
                            func appendMinor(minorCount: Int, lineWidth lw: Double) {
                                for i in 0 ..< minorCount {
                                    let id = Double(i) * 2 * tlw
                                    subBorderPathlines.append(Pathline(Rect(x: fx + id, y: fy0,
                                                                            width: tlw, height: d - tlw)))
                                    subBorderPathlines.append(Pathline(Rect(x: fx, y: fy0 + d - tlw,
                                                                            width: lw, height: tlw)))
                                    
                                    subBorderPathlines.append(Pathline(Rect(x: fx + id, y: fy1 + tlw,
                                                                            width: tlw, height: d - tlw)))
                                    subBorderPathlines.append(Pathline(Rect(x: fx, y: fy1,
                                                                            width: lw, height: tlw)))
                                }
                                appendMain(lineWidth: lw)
                            }
                            func appendMajor(lineWidth lw: Double) {
                                subBorderPathlines.append(Pathline(Rect(x: fx, y: fy0,
                                                                        width: lw, height: d)))
                                subBorderPathlines.append(Pathline(Rect(x: fx, y: fy1,
                                                                        width: lw, height: d)))
                                appendMain(lineWidth: lw)
                            }
                            
                            switch typer.type {
                            case .power:
                                appendMajor(lineWidth: 7 * tlw)
                            case .major:
                                appendMajor(lineWidth: 5 * tlw)
                            case .suspended:
                                appendMajor(lineWidth: 3 * tlw)
                            case .minor:
                                appendMinor(minorCount: 4, lineWidth: 7 * tlw)
                            case .augmented:
                                appendMinor(minorCount: 3, lineWidth: 5 * tlw)
                            case .flatfive:
                                appendMinor(minorCount: 2, lineWidth: 3 * tlw)
                            case .diminish:
                                appendMinor(minorCount: 1, lineWidth: 1 * tlw)
                            case .tritone:
                                appendMinor(minorCount: 1, lineWidth: 0.5 * tlw)
                            }
                        }
                    }
                }
            }
        }
        
        return subBorderPathlines
    }
    
    func octaveNode(from note: Note) -> Node {
        let pitchRange = Score.pitchRange
        guard pitchRange.contains(note.pitch) else {
            return .init()
        }
        
        let nx = x(atBeat: note.beatRange.start)
        let nw = width(atDurBeat: max(note.beatRange.length, Sheet.fullEditBeatInterval))
        let points: [Point]
        if note.pits.count == 1 {
            let ny = self.y(fromPitch: note.pitch)
            points = [Point(nx, ny), Point(nx + nw, ny)]
        } else {
            points = self.pointline(from: note).points
        }
        
        var subBorderPathlines = [Pathline]()
        let notePathlines = [Pathline(points)]
        let pd = 12 * pitchHeight
        var nPitch = note.pitch, npd = 0.0
        while true {
            nPitch -= 12
            npd -= pd
            guard pitchRange.contains(nPitch) else { break }
            subBorderPathlines += notePathlines.map { $0 * Transform(translation: .init(0, npd)) }
        }
        nPitch = note.pitch
        npd = 0.0
        while true {
            nPitch += 12
            npd += pd
            guard pitchRange.contains(nPitch) else { break }
            subBorderPathlines += notePathlines.map { $0 * Transform(translation: .init(0, npd)) }
        }
        
        let nh = ScoreLayout.noteHeight
        return Node(path: Path(subBorderPathlines), lineWidth: nh, lineType: .color(.subBorder))
    }
    
    func draftNoteNode(from note: Note) -> Node {
        let noteNode = noteNode(from: note)
        var color = Color.draft
        color.opacity = 0.1
        noteNode.children.forEach {
            if $0.lineType != nil {
                $0.lineType = .color(color)
            }
            if $0.fillType != nil {
                $0.fillType = .color(color)
            }
        }
        return noteNode
    }
    
    func noteNode(from note: Note, color: Color? = nil, lineWidth: Double? = nil) -> Node {
        guard note.beatRange.length > 0 else {
            return .init(path: Path(Rect(.init(x(atBeat: note.beatRange.start),
                                               y(fromPitch: note.pitch)),
                                         distance: 1)),
                         fillType: .color(color != nil ? color! : .content))
        }
        let nh = ScoreLayout.noteHeight
        let nx = x(atBeat: note.beatRange.start)
        let ny = y(fromPitch: note.firstPitch)
        let nw = width(atDurBeat: max(note.beatRange.length, Sheet.fullEditBeatInterval))
        let attackW = width(atDurSec: note.envelope.attackSec)
        let decayW = width(atDurSec: note.envelope.decaySec)
        let releaseW = width(atDurSec: note.envelope.releaseSec)
        
        let overtoneH = 1.0
        let scH = 2.0
        let scY = 2.0
        let noiseY = 1.5
        
        var linePathlines = [Pathline](), lyricLinePathlines = [Pathline]()
        var evenPathline, oddPathline, fqPathline: Pathline?
        var noisePathline: Pathline?
        var scNodes = [Node]()
        let envelopeR = 0.125, sprolR = 0.03125 / 2, sprolSubR = 0.03125 / 4
        
        let lyricPaths: [Path] = note.pits.enumerated().compactMap { (pitI, pit) in
            let p = pitPosition(atPit: pitI, from: note)
            if !pit.lyric.isEmpty {
                if pit.lyric == "%" {
                    lyricLinePathlines.append(.init(Rect(x: p.x - 0.25, y: p.y - nh, width: 0.5, height: nh)))
                    return nil
                } else {
                    let lyricText = Text(string: pit.lyric, size: Font.smallSize)
                    let typesetter = lyricText.typesetter
                    let lh = typesetter.height / 2 + 2
                    lyricLinePathlines.append(.init(Rect(x: p.x - 0.25, y: p.y - lh / 2, width: 0.5, height: lh / 2)))
                    return typesetter.path() * Transform(translationX: p.x, y: p.y - lh)
                }
            } else {
                return nil
            }
        }
        
        func tonePitchY(fromPitch pitch: Double, noteY: Double) -> Double {
            pitch.clipped(min: Score.doubleMinPitch, max: Score.doubleMaxPitch,
                          newMin: -scH / 2, newMax: scH / 2) + nh / 2 + overtoneH + scY + noteY
        }
        
        let lineColors: [Color], evenColors: [Color], oddColors: [Color],
            knobPs: [Point], smallKnobPAndRs: [(Point, Double)]
        let volmT = 1.0
        if note.pits.count >= 2 {
            let sprolKnobPAndRs: [(Point, Double)] = note.pits.flatMap { pit in
                let p = Point(x(atBeat: note.beatRange.start + pit.beat),
                              self.y(fromPitch: note.pitch + pit.pitch))
                return pit.tone.spectlope.sprols.enumerated().map {
                    (Point(p.x, tonePitchY(fromPitch: $0.element.pitch, noteY: p.y)),
                     pit.lyric.isEmpty ? sprolR : ($0.offset % 4 == 0 || $0.offset % 4 == 3 ? sprolSubR : sprolR))
                }
            }
            
            let envelopeY = nh / 2 + overtoneH + overtoneH / 2
            let ax = nx + attackW, dx = nx + attackW + decayW, rx = nx + nw + releaseW
            smallKnobPAndRs = [(Point(ax, noteY(atX: ax, from: note) + envelopeY), envelopeR),
                               (Point(dx, noteY(atX: dx, from: note) + envelopeY), envelopeR),
                               (Point(rx, noteY(atX: rx, from: note) + envelopeY), envelopeR)] + sprolKnobPAndRs
            
            knobPs = note.pits.map { .init(x(atBeat: note.beatRange.start + $0.beat),
                                           self.y(fromPitch: note.pitch + $0.pitch)) }
            
            if !note.isOneOvertone {
                struct PAndColor: Hashable {
                    var p: Point, color: Color
                    
                    init(_ p: Point, _ color: Color) {
                        self.p = p
                        self.color = color
                    }
                    static func ==(lhs: Self, rhs: Self) -> Bool {
                        lhs.p.y == rhs.p.y && lhs.color == rhs.color
                    }
                }
                
                func pAndColors(x: Double, pitch: Double, noteY: Double,
                                sprols: [Sprol]) -> [PAndColor] {
                    var vs = [PAndColor](capacity: sprols.count)
                    
                    func append(_ sprol: Sprol) {
                        let y = tonePitchY(fromPitch: sprol.pitch, noteY: noteY)
                        let color = Self.color(fromVolm: sprol.volm, noise: sprol.noise)
                        vs.append(.init(.init(x, y), color))
                    }
                    
                    append(.init(pitch: Score.doubleMinPitch,
                                 volm: sprols.first?.volm ?? 0,
                                 noise: sprols.first?.noise ?? 0))
                    for sprol in sprols {
                        append(sprol)
                    }
                    append(.init(pitch: Score.doubleMaxPitch,
                                 volm: sprols.last?.volm ?? 0,
                                 noise: sprols.last?.noise ?? 0))
                    
                    return vs
                }
                
                let pitbend = note.pitbend(fromTempo: model.tempo)
                
                var beat = note.beatRange.start, vs = [[PAndColor]](), fqLinePs = [Point]()
                var lastV: [PAndColor]?, lastFqLineP: Point?, isLastAppned = false
                while beat <= note.beatRange.end {
                    let x = self.x(atBeat: beat)
                    let sprols = pitbend.tone(atSec: Double(sec(fromBeat: beat - note.beatRange.start))).spectlope.sprols
                    let psPitch = pitch(atBeat: beat, from: note)
                    let noteY = y(fromPitch: psPitch)
                    let v = pAndColors(x: x, pitch: psPitch, noteY: noteY, sprols: sprols)
                    let fqLineP = Point(x, tonePitchY(fromPitch: psPitch, noteY: noteY))
                    isLastAppned = vs.last != v
                    if isLastAppned {
                        if let v = lastV, let fqLineP = lastFqLineP {
                            vs.append(v)
                            fqLinePs.append(fqLineP)
                        }
                        vs.append(v)
                        fqLinePs.append(fqLineP)
                    }
                    
                    lastV = v
                    lastFqLineP = fqLineP
                    beat += .init(1, 48)
                }
                if !isLastAppned, let v = lastV, let fqLineP = lastFqLineP {
                    vs.append(v)
                    fqLinePs.append(fqLineP)
                }
                
                if !vs.isEmpty && vs[0].count >= 2 {
                    for yi in 1 ..< vs[0].count {
                        var ps = [Point](capacity: 2 * vs.count)
                        var colors = [Color](capacity: 2 * vs.count)
                        for xi in vs.count.range {
                            ps.append(vs[xi][yi - 1].p)
                            ps.append(vs[xi][yi].p)
                            colors.append(vs[xi][yi - 1].color)
                            colors.append(vs[xi][yi].color)
                        }
                        let tst = TriangleStrip(points: ps)
                        
                        scNodes.append(.init(path: Path(tst), fillType: .colors(colors)))
                    }
                }
                
                fqPathline = .init(fqLinePs)
            }
            
            lineColors = self.lineColors(from: note)
            evenColors = self.overtoneColors(from: note, .evenVolm)
            oddColors = self.overtoneColors(from: note, .oddVolm)
            
            let pointline = pointline(from: note)
            if !pointline.isEmpty {
                linePathlines += [.init(pointline.points)]
                
                let line1: [Point] = pointline.points.map { .init($0.x, $0.y + overtoneH / 2 + nh / 2) }
                let line2: [Point] = pointline.points.map { .init($0.x, $0.y - overtoneH / 2 - nh / 2) }
                evenPathline = .init(line1)
                oddPathline = .init(line2)
            
                if note.isNoise {
                    noisePathline = .init(pointline.points.map { .init($0.x, $0.y - overtoneH - noiseY - nh / 2) })
                }
            }
        } else {
//            let sustain = env.sustainVolm + 1 / noteHeight
            let line = Line(controls: [.init(point: Point(nx, ny), pressure: 0),
                                       .init(point: Point(nx + attackW, ny), pressure: volmT),
                                       .init(point: Point(nx + attackW, ny), pressure: volmT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: volmT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: volmT),
                                       .init(point: Point(nx + nw, ny), pressure: volmT),
                                       .init(point: Point(nx + nw, ny), pressure: volmT),
                                       .init(point: Point(nx + nw + releaseW, ny), pressure: 0)])
            
            let toneLine = Line(controls: [.init(point: Point(nx, ny), pressure: volmT),
                                       .init(point: Point(nx + attackW, ny), pressure: volmT),
                                       .init(point: Point(nx + attackW, ny), pressure: volmT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: volmT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: volmT),
                                       .init(point: Point(nx + nw, ny), pressure: volmT),
                                       .init(point: Point(nx + nw, ny), pressure: volmT)])
            
            let sprolKnobPAndRs = note.firstTone.spectlope.sprols.enumerated().map {
                (Point(nx, tonePitchY(fromPitch: $0.element.pitch, noteY: ny)),
                 note.firstPit.lyric.isEmpty ? sprolR : ($0.offset % 4 == 0 || $0.offset % 4 == 3 ? sprolSubR : sprolR))
            }
            
            let envelopeY = ny + nh / 2 + overtoneH + overtoneH / 2
            smallKnobPAndRs = [(Point(nx + attackW, envelopeY), envelopeR),
                               (Point(nx + attackW + decayW, envelopeY), envelopeR),
                               (Point(nx + nw + releaseW, envelopeY), envelopeR)] + sprolKnobPAndRs
            knobPs = []
            
            let color = Self.color(from: note.pits[0].stereo)
            lineColors = [color]
            
            if !note.isOneOvertone {
                func tonePitchY(fromPitch pitch: Double) -> Double {
                    ny + pitch.clipped(min: Double(Score.pitchRange.start),
                                       max: Double(Score.pitchRange.end),
                                       newMin: -scH / 2,
                                       newMax: scH / 2) + nh / 2 + overtoneH + scY
                }
                var preY = tonePitchY(fromPitch: 0)
                var preColor = Self.color(fromVolm: note.firstTone.spectlope.sprols.first?.volm ?? 0,
                                          noise: note.firstTone.spectlope.sprols.first?.noise ?? 0)
                func append(_ sprol: Sprol) {
                    let y = tonePitchY(fromPitch: sprol.pitch)
                    let color = Self.color(fromVolm: sprol.volm, noise: sprol.noise)
                    
                    let tst = TriangleStrip(points: [.init(nx, preY), .init(nx, y),
                                                     .init(nx + nw, preY), .init(nx + nw, y)])
                    let colors = [preColor, color, preColor, color]
                    
                    scNodes.append(.init(path: Path(tst), fillType: .colors(colors)))
                    
                    preY = y
                    preColor = color
                }
                for sprol in note.firstTone.spectlope.sprols {
                    append(sprol)
                }
                append(.init(pitch: Score.doubleMaxPitch,
                             volm: note.firstTone.spectlope.sprols.last?.volm ?? 0,
                             noise: note.firstTone.spectlope.sprols.last?.noise ?? 0))
                
                let fqY = tonePitchY(fromPitch: .init(note.firstPitch))
                fqPathline = .init([Point(nx, fqY), Point(nx + nw, fqY)])
            }
            
            linePathlines += [.init(line)]
            
            let line1 = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y + overtoneH / 2 + $0.pressure * nh / 2)) })
            let line2 = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y - overtoneH / 2 - $0.pressure * nh / 2)) })
            evenPathline = .init(line1)
            oddPathline = .init(line2)
            
            evenColors = [Self.color(fromVolm: note.firstTone.overtone.evenVolm)]
            oddColors = [Self.color(fromVolm: note.firstTone.overtone.oddVolm)]
            
            if note.isNoise {
                noisePathline = .init(Line(controls: toneLine.controls.map {
                    .init(point: .init($0.point.x, $0.point.y - overtoneH - noiseY - $0.pressure * nh / 2))
                }))
            }
        }
        
        var nodes = [Node]()
        nodes += linePathlines.map {
            .init(path: Path([$0]),
                  lineWidth: lineWidth ?? nh,
                  lineType: color != nil ? .color(color!) : (lineColors.count == 1 ? .color(lineColors[0]) : .gradient(lineColors)))
        }
        
        if let noisePathline {
            nodes.append(.init(path: Path([noisePathline]),
                               lineWidth: (lineWidth ?? nh) / 2,
                               lineType: .color(.content)))
        }
        
        nodes += scNodes
        
        if let oddPathline {
            nodes.append(.init(path: Path([oddPathline]),
                               lineWidth: (lineWidth ?? nh) / 2,
                               lineType: color != nil ? .color(color!) : (oddColors.count == 1 ? .color(oddColors[0]) : .gradient(oddColors))))
        }
        if let evenPathline {
            nodes.append(.init(path: Path([evenPathline]),
                               lineWidth: (lineWidth ?? nh) / 2,
                               lineType: color != nil ? .color(color!) : (evenColors.count == 1 ? .color(evenColors[0]) : .gradient(evenColors))))
        }
        if let fqPathline {
            nodes.append(.init(path: Path([fqPathline]),
                               lineWidth: 0.03125,
                               lineType: .color(.content)))
        }
        
        let fullEditBackKnobPathlines = smallKnobPAndRs.map {
            Pathline(circleRadius: $0.1 * 1.5, position: $0.0)
        }
        let fullEditKnobPathlines = smallKnobPAndRs.map {
            Pathline(circleRadius: $0.1, position: $0.0)
        }
        
        let backKnobPathlines = knobPs.map { Pathline(circleRadius: 0.25 * 1.5, position: $0) }
        let knobPathlines = knobPs.map { Pathline(circleRadius: 0.25, position: $0) }
        
        nodes += lyricPaths.map { .init(path: $0, fillType: .color(color ?? .content)) }
        nodes.append(.init(path: .init(lyricLinePathlines), fillType: .color(.content)))
        
        nodes.append(.init(path: .init(backKnobPathlines), fillType: .color(.content)))
        nodes.append(.init(path: .init(knobPathlines), fillType: .color(.background)))
        nodes.append(.init(name: "isFullEdit", isHidden: !isFullEdit,
                           path: .init(fullEditBackKnobPathlines), fillType: .color(.content)))
        nodes.append(.init(name: "isFullEdit", isHidden: !isFullEdit,
                           path: .init(fullEditKnobPathlines), fillType: .color(.background)))
        
        let boundingBox = nodes.reduce(into: Rect?.none) { $0 += $1.drawableBounds }
        return Node(children: nodes, path: boundingBox != nil ? Path(boundingBox!) : .init())
    }
    
    func pointline(from note: Note) -> Pointline {
        if note.pits.count == 1 {
            let noteSX = x(atBeat: note.beatRange.start)
            let noteEX = x(atBeat: note.beatRange.end)
            let noteY = noteY(atBeat: note.beatRange.start, from: note)
            return .init(points: [.init(noteSX, noteY), .init(noteEX, noteY)])
        }
        
        var beat = note.beatRange.start, ps = [Point]()
//        var lastP: Point?, lastStereo: Stereo?, isLastAppned = false
        while beat <= note.beatRange.end {
            let noteX = x(atBeat: beat)
            let noteY = noteY(atBeat: beat, from: note)
            let p = Point(noteX, noteY)
//            let stereo = stereo(atBeat: beat, from: note)
//            isLastAppned = lastP?.y != p.y || lastStereo != stereo
//            if isLastAppned {
//                if let p = lastP {
//                    ps.append(p)
//                }
                ps.append(p)
//            }
//            lastP = p
//            lastStereo = stereo
            beat += .init(1, 48)
        }
//        if !isLastAppned, let p = lastP {
//            ps.append(p)
//        }
       
        return .init(points: ps)
    }
    func lineColors(from note: Note) -> [Color] {
        if note.pits.count == 1 {
            let color = Self.color(from: note.pits[0].stereo)
            return [color, color]
        }
        
        var beat = note.beatRange.start, colors = [Color]()//, ps = [Point]()
//        var lastP: Point?, lastStereo: Stereo?, isLastAppned = false
        while beat <= note.beatRange.end {
//            let noteX = x(atBeat: beat)
//            let noteY = noteY(atBeat: beat, from: note)
//            let p = Point(noteX, noteY)
            let stereo = stereo(atBeat: beat, from: note)
//            isLastAppned = lastP?.y != p.y || lastStereo != stereo
//            if isLastAppned {
//                if let p = lastP, let stereo = lastStereo {
//                    ps.append(p)
//                    
                    colors.append(Self.color(from: stereo))
//                }
//                ps.append(p)
//                colors.append(Self.color(from: stereo))
//            }
//            lastP = p
//            lastStereo = stereo
            beat += .init(1, 48)
        }
//        if !isLastAppned, let p = lastP, let stereo = lastStereo {
//            ps.append(p)
//            colors.append(Self.color(from: stereo))
//        }
        
        return colors
    }
    func overtoneColors(from note: Note, _ type: OvertoneType) -> [Color] {
        if note.pits.count == 1 {
            let color = Self.color(fromVolm: note.pits[0].tone.overtone[type])
            return [color, color]
        }
        
        var beat = note.beatRange.start, colors = [Color]()//, ps = [Point]()
//        var lastP: Point?, lastOvertone: Double?, isLastAppned = false
        while beat <= note.beatRange.end {
//            let noteX = x(atBeat: beat)
//            let noteY = noteY(atBeat: beat, from: note)
//            let p = Point(noteX, noteY)
            let overtone = tone(atBeat: beat, from: note).overtone[type]
//            isLastAppned = lastP?.y != p.y || lastOvertone != overtone
//            if isLastAppned {
//                if let p = lastP, let overtone = lastOvertone {
//                    ps.append(p)
//                    
//                    colors.append(Self.color(fromVolm: overtone))
//                }
//                ps.append(p)
                colors.append(Self.color(fromVolm: overtone))
//            }
//            lastP = p
//            lastOvertone = overtone
            beat += .init(1, 48)
        }
//        if !isLastAppned, let p = lastP, let overtone = lastOvertone {
//            ps.append(p)
//            colors.append(Self.color(fromVolm: overtone))
//        }
        
        return colors
    }
    
    static func octaveColor(lightness: Double = 40, chroma: Double = 50,
                            fromPitch pitch: Double) -> Color {
        Color(lightness: lightness,
              nearestChroma: chroma,
              hue: 2 * .pi * pitch.mod(12) / 12)
    }
    static func color(fromVolm volm: Double) -> Color {
        Color(lightness: (1 - volm) * 100)
    }
    static func color(fromVolm volm: Double, noise: Double) -> Color {
        let l = Double(Color(lightness: (1 - volm * 0.75) * 100).rgba.r)
        return if noise == 0 {
            Color(red: l, green: l, blue: l)
        } else {
            Color(red: l, green: l, blue: noise * Spectrogram.editRedRatio * (1 - l) + l)
        }
    }
    static func color(from stereo: Stereo) -> Color {
        color(fromPan: stereo.pan, volm: stereo.volm)
    }
    static func color(fromPan pan: Double, volm: Double) -> Color {
        let l = Double(Color(lightness: (1 - volm) * 100).rgba.r)
        return if pan == 0 {
            Color(red: l, green: l, blue: l)
        } else if pan > 0 {
            Color(red: pan * Spectrogram.editRedRatio * (1 - l) + l, green: l, blue: l)
        } else {
            Color(red: l, green: -pan * Spectrogram.editGreenRatio * (1 - l) + l, blue: l)
        }
    }
    
    func releasePosition(from note: Note) -> Point {
        let nx = x(atBeat: note.beatRange.end)
        let ny = noteY(atX: nx, from: note) + noteH(atX: nx, from: note) / 2 + 1 + 1 / 2
        let releaseW = width(atDurSec: note.envelope.releaseSec)
        return .init(nx + releaseW, ny)
    }
    
    func updateTimeNode(atSec sec: Rational) {
        if model.enabled {
            let frame = mainFrame
            let x = self.x(atSec: sec)
            if x >= frame.minX && x < frame.maxX {
                timeNode.path = Path([Point(), Point(0, frame.height)])
                timeNode.attitude.position = Point(x, frame.minY)
                updateFromPeakVolm()
            } else {
                timeNode.path = Path()
                currentPeakVolmNode.path = Path()
            }
        } else if !timeNode.path.isEmpty {
            timeNode.path = Path()
            currentPeakVolmNode.path = Path()
        }
    }
    
    var clippableBounds: Rect? {
        mainFrame
    }
    var transformedClippableBounds: Rect? {
        if let bounds = clippableBounds {
            bounds * node.localTransform
        } else {
            nil
        }
    }
    
    func containsTimeline(_ p : Point) -> Bool {
        model.enabled ? timelineFrame.contains(p) : false
    }
    var timelineFrame: Rect {
        let sx = self.x(atBeat: model.beatRange.start)
        let ex = self.x(atBeat: model.beatRange.end)
        return Rect(x: sx, y: timeLineCenterY - Sheet.timelineHalfHeight,
                    width: ex - sx, height: Sheet.timelineHalfHeight * 2).outset(by: 3)
    }
    var transformedTimelineFrame: Rect? {
        timelineFrame
    }
    
    func keyBeatIndex(at p: Point, scale: Double) -> Int? {
        guard containsTimeline(p) else { return nil }
        let maxD = Sheet.knobEditDistance * scale
        let maxDS = maxD * maxD
        var minDS = Double.infinity, minI: Int?
        for (keyBeatI, keyBeat) in model.keyBeats.enumerated() {
            let ds = p.x.distanceSquared(x(atBeat: keyBeat))
            if ds < minDS && ds < maxDS {
                minDS = ds
                minI = keyBeatI
            }
        }
        return minI
    }
    
    func containsNote(_ p: Point, scale: Double) -> Bool {
        noteIndex(at: p, scale: scale) != nil
    }
    func noteIndex(at p: Point, scale: Double, enabledRelease: Bool = false) -> Int? {
        let maxD = Sheet.knobEditDistance * scale + (pitchHeight / 2 + 5) / 2
        let maxDS = maxD * maxD, hnh = pitchHeight / 2
        var minDS = Double.infinity, minI: Int?
        for (noteI, note) in model.notes.enumerated() {
            let nf = noteFrame(at: noteI).outset(by: hnh)
            let ods = nf.distanceSquared(p)
            if ods < maxDS {
                let ds = pointline(from: note).minDistanceSquared(at: p - Point(0, 5 / 2))
                if ds < minDS && ds < maxDS {
                    minDS = ds
                    minI = noteI
                }
            }
            if enabledRelease {
                let rp = releasePosition(from: note)
                let ds = rp.distanceSquared(p)
                if ds < minDS && ds < maxDS {
                    minDS = ds
                    minI = noteI
                }
            }
        }
        return minI
    }
    
    enum FullEditHitResult {
        case attack
        case decay
        case release
        case sprol(pitI: Int, sprolI: Int)
    }
    func hitTestFullEdit(_ p: Point, scale: Double, at noteI: Int) -> FullEditHitResult? {
        guard isFullEdit else { return nil }
        var minResult: FullEditHitResult?
        
        let maxD = Sheet.knobEditDistance * scale
        let maxDS = maxD * maxD
        let score = model
        let note = score.notes[noteI]
        
        let attackBeat = Double(note.beatRange.start) + score.beat(fromSec: note.envelope.attackSec)
        let ax = x(atBeat: attackBeat)
        let ap = Point(ax, noteY(atX: ax, at: noteI) + noteH(atX: ax, at: noteI) / 2 + 1 + 1 / 2)
        let decayBeat = Double(note.beatRange.start) + score.beat(fromSec: note.envelope.attackSec + note.envelope.decaySec)
        let dx = x(atBeat: decayBeat)
        let dp = Point(dx, noteY(atX: dx, at: noteI) + noteH(atX: dx, at: noteI) / 2 + 1 + 1 / 2)
        let releaseBeat = Double(note.beatRange.end) + score.beat(fromSec: note.envelope.releaseSec)
        let rx = x(atBeat: releaseBeat)
        let rp = Point(rx, noteY(atX: rx, at: noteI) + noteH(atX: rx, at: noteI) / 2 + 1 + 1 / 2)
        
        var minDS = Double.infinity
        
        let dsa = ap.distanceSquared(p)
        if dsa < minDS && dsa < maxDS {
            minDS = dsa
            minResult = .attack
        }
        
        let dsd = dp.distanceSquared(p)
        if dsd < minDS && dsd < maxDS {
            minDS = dsd
            minResult = .decay
        }
        
        let dsr = rp.distanceSquared(p)
        if dsr < minDS && dsr < maxDS {
            minDS = dsr
            minResult = .release
        }
        
        for (pitI, pit) in note.pits.enumerated() {
            for (sprolI, _) in pit.tone.spectlope.sprols.enumerated() {
                let psp = sprolPosition(atSprol: sprolI, atPit: pitI, from: note)
                let ds = psp.distanceSquared(p)
                if ds < minDS && ds < maxDS {
                    minDS = ds
                    minResult = .sprol(pitI: pitI, sprolI: sprolI)
                }
            }
        }
        
        return minResult
    }
    
    enum ColorHitResult {
        case note
        case sustain
        case pit(pitI: Int)
        case evenVolm(pitI: Int)
        case oddVolm(pitI: Int)
        case sprol(pitI: Int, sprolI: Int)
        
        var isTone: Bool {
            switch self {
            case .evenVolm, .oddVolm, .sprol: true
            default: false
            }
        }
    }
    func hitTestColor(_ p: Point, scale: Double) -> (noteI: Int, result: ColorHitResult)? {
        if isFullEdit {
            var minNoteI: Int?, minResult: ColorHitResult?
            
            let maxD = Sheet.knobEditDistance * scale
            let maxDS = maxD * maxD
            var minDS = Double.infinity
            
            let score = model
            for (noteI, note) in score.notes.enumerated() {
                for (pitI, pit) in note.pits.enumerated() {
                    for (sprolI, _) in pit.tone.spectlope.sprols.enumerated() {
                        let psp = sprolPosition(atSprol: sprolI, atPit: pitI, from: note)
                        let dsd = psp.distanceSquared(p)
                        if dsd < minDS && dsd < maxDS {
                            minDS = dsd
                            minNoteI = noteI
                            minResult = .sprol(pitI: pitI, sprolI: sprolI)
                        }
                    }
                    
                    let noteH = ScoreLayout.noteHeight
                    let minODS = noteY(atX: p.x, at: noteI) - p.y
                    if abs(minODS) > noteH / 2 {
                        let pitP = pitPosition(atPit: pitI, from: note)
                        
                        let evenP = pitP + .init(0, noteH / 2 + 1 / 2)
                        let evenDsd = evenP.distanceSquared(p)
                        if evenDsd < minDS && evenDsd < maxDS {
                            minDS = evenDsd
                            minNoteI = noteI
                            minResult = .evenVolm(pitI: pitI)
                        }
                        let oddP = pitP + .init(0, -noteH / 2 - 1 / 2)
                        let oddDsd = oddP.distanceSquared(p)
                        if oddDsd < minDS && oddDsd < maxDS {
                            minDS = oddDsd
                            minNoteI = noteI
                            minResult = .oddVolm(pitI: pitI)
                        }
                        
                        if note.pits.count == 1 {
                            let pointline = pointline(from: note)
                            var ds = pointline.minDistanceSquared(at: p - Point(0, ScoreLayout.noteHeight / 2 + 1 / 2))
                            if ds < minDS && ds < maxDS {
                                minDS = ds
                                minNoteI = noteI
                                minResult = .evenVolm(pitI: 0)
                            }
                            ds = pointline.minDistanceSquared(at: p + Point(0, ScoreLayout.noteHeight / 2 + 1 / 2))
                            if ds < minDS && ds < maxDS {
                                minDS = ds
                                minNoteI = noteI
                                minResult = .oddVolm(pitI: 0)
                            }
                        }
                    }
                }
                
                let decayBeat = Double(note.beatRange.start) + score.beat(fromSec: note.envelope.attackSec + note.envelope.decaySec)
                let dx = x(atBeat: decayBeat)
                let dp = Point(dx, noteY(atX: dx, at: noteI) + noteH(atX: dx, at: noteI) / 2 + 1 + 1 / 2)
                let dsd = dp.distanceSquared(p)
                if dsd < minDS && dsd < maxDS {
                    minDS = dsd
                    minNoteI = noteI
                    minResult = .sustain
                }
            }
            
            if let minNoteI, let minResult {
                return (minNoteI, minResult)
            }
        }
        if let (noteI, pitI) = noteAndPitI(at: p, scale: scale) {
            return (noteI, .pit(pitI: pitI))
        }
        
        if let noteI = noteIndex(at: p, scale: scale) {
            return (noteI, .note)
        }
        
        return nil
    }
    
    func intersectsNote(_ otherRect: Rect, at noteI: Int) -> Bool {
        let node = notesNode.children[noteI]
        guard let b = node.bounds else { return false }
        guard b.intersects(otherRect) else {
            return false
        }
        if otherRect.contains(b) {
            return true
        }
        let line = pointline(from: model.notes[noteI])
        if otherRect.contains(line.firstPoint) {
            return true
        } else {
            let x0y0 = otherRect.origin
            let x1y0 = Point(otherRect.maxX, otherRect.minY)
            let x0y1 = Point(otherRect.minX, otherRect.maxY)
            let x1y1 = Point(otherRect.maxX, otherRect.maxY)
            func intersects(_ edge: Edge) -> Bool {
                for ledge in line.edges {
                    if ledge.intersects(edge) {
                        return true
                    }
                }
                return false
            }
            return intersects(Edge(x0y0, x1y0))
                || intersects(Edge(x1y0, x1y1))
                || intersects(Edge(x1y1, x0y1))
                || intersects(Edge(x0y1, x0y0))
        }
    }
    func intersectsDraftNote(_ otherRect: Rect, at noteI: Int) -> Bool {
        let node = draftNotesNode.children[noteI]
        guard let b = node.bounds else { return false }
        guard b.intersects(otherRect) else {
            return false
        }
        if otherRect.contains(b) {
            return true
        }
        let line = pointline(from: model.draftNotes[noteI])
        if otherRect.contains(line.firstPoint) {
            return true
        } else {
            let x0y0 = otherRect.origin
            let x1y0 = Point(otherRect.maxX, otherRect.minY)
            let x0y1 = Point(otherRect.minX, otherRect.maxY)
            let x1y1 = Point(otherRect.maxX, otherRect.maxY)
            func intersects(_ edge: Edge) -> Bool {
                for ledge in line.edges {
                    if ledge.intersects(edge) {
                        return true
                    }
                }
                return false
            }
            return intersects(Edge(x0y0, x1y0))
                || intersects(Edge(x1y0, x1y1))
                || intersects(Edge(x1y1, x0y1))
                || intersects(Edge(x0y1, x0y0))
        }
    }
    
    func noteFrame(at noteI: Int) -> Rect {
        notesNode.children[noteI].path.bounds!
    }
    func draftNoteFrame(at noteI: Int) -> Rect {
        draftNotesNode.children[noteI].path.bounds!
    }
    func noteY(atX x: Double, at noteI: Int) -> Double {
        noteY(atX: x, from: model.notes[noteI])
    }
    func noteY(atX x: Double, from note: Note) -> Double {
        let result = note.pitResult(atBeat: beat(atX: x) - .init(note.beatRange.start))
        return y(fromPitch: (.init(note.pitch) + result.pitch.doubleValue).clipped(Score.doublePitchRange))
    }
    func noteY(atBeat beat: Double, from note: Note) -> Double {
        let result = note.pitResult(atBeat: .init(beat - .init(note.beatRange.start)))
        return y(fromPitch: (.init(note.pitch) + result.pitch.doubleValue).clipped(Score.doublePitchRange))
    }
    func noteY(atBeat beat: Rational, from note: Note) -> Double {
        let result = note.pitResult(atBeat: .init(beat - note.beatRange.start))
        return y(fromPitch: (.init(note.pitch) + result.pitch.doubleValue).clipped(Score.doublePitchRange))
    }
    func pitch(atBeat beat: Rational, from note: Note) -> Double {
        let result = note.pitResult(atBeat: .init(beat - note.beatRange.start))
        return .init(note.pitch) + result.pitch.doubleValue
    }
    func stereo(atX x: Double, at noteI: Int) -> Stereo {
        let note = model.notes[noteI]
        let result = note.pitResult(atBeat: beat(atX: x) - .init(note.beatRange.start))
        return result.stereo
    }
    func stereo(atBeat beat: Rational, from note: Note) -> Stereo {
        let result = note.pitResult(atBeat: .init(beat - note.beatRange.start))
        return result.stereo
    }
    func volm(atX x: Double, at noteI: Int) -> Double {
        stereo(atX: x, at: noteI).volm
    }
    func pan(atX x: Double, at noteI: Int) -> Double {
        stereo(atX: x, at: noteI).pan
    }
    func tone(atBeat beat: Rational, from note: Note) -> Tone {
        let result = note.pitResult(atBeat: .init(beat - note.beatRange.start))
        return result.tone
    }
    func noteH(atX x: Double, at noteI: Int) -> Double {
        ScoreLayout.noteHeight
    }
    func noteH(atX x: Double, from note: Note) -> Double {
        ScoreLayout.noteHeight
    }
    
    func noteAndPitIEnabledNote(at p: Point, scale: Double) -> (noteI: Int, pitI: Int)? {
        if let v = noteAndPitI(at: p, scale: scale) {
            v
        } else if let noteI = noteIndex(at: p, scale: scale) {
            (noteI, 0)
        } else {
            nil
        }
    }
    func noteAndPitI(at p: Point, scale: Double) -> (noteI: Int, pitI: Int)? {
        let score = model
        let maxD = Sheet.knobEditDistance * scale
        let maxDS = maxD * maxD
        var minNoteI: Int?, minPitI: Int?, minDS = Double.infinity
        for (noteI, note) in score.notes.enumerated() {
            guard note.pits.count > 1 else { continue }
            
            for pitI in note.pits.count.range {
                let pitP = pitPosition(atPit: pitI, from: note)
                let ds = pitP.distanceSquared(p)
                if ds < minDS && ds < maxDS {
                    minNoteI = noteI
                    minPitI = pitI
                    minDS = ds
                }
            }
        }
        
        return if let minNoteI, let minPitI {
            (minNoteI, minPitI)
        } else {
            nil
        }
    }
    func pitI(at p: Point, scale: Double, at noteI: Int) -> Int? {
        let note = model.notes[noteI]
        guard note.pits.count > 1 else { return nil }

        let maxD = Sheet.knobEditDistance * scale
        let maxDS = maxD * maxD
        var minPitI: Int?, minDS = Double.infinity
        for pitI in note.pits.count.range {
            let pitP = pitPosition(atPit: pitI, from: note)
            let ds = pitP.distanceSquared(p)
            if ds < minDS && ds < maxDS {
                minPitI = pitI
                minDS = ds
            }
        }
        return minPitI
    }
    var toneY: Double {
        ScoreLayout.noteHeight / 2 + 2 + toneHeight / 2
    }
    var toneHeight: Double {
        2
    }
    func pitIAndSprolI(at p: Point, at noteI: Int) -> (pitI: Int, sprolI: Int)? {
        guard isFullEdit,
                p.y > noteY(atX: p.x, at: noteI) + toneY - toneHeight / 2 else { return nil }
        
        let score = model
        let note = score.notes[noteI]
        var minDS = Double.infinity, minPitI: Int?, minSprolI: Int?
        for (pitI, pit) in note.pits.enumerated() {
            for (sprolI, sprol) in pit.tone.spectlope.sprols.enumerated() {
                let psp = sprolPosition(atSprol: sprolI, atPit: pitI, from: note)
                let ds = p.distanceSquared(psp)
                if sprol.pitch == Score.doubleMinPitch ? ds >= minDS : ds < minDS {
                    minDS = ds
                    minPitI = pitI
                    minSprolI = sprolI
                }
            }
        }
        
        return if let minPitI, let minSprolI {
            (minPitI, minSprolI)
        } else {
            nil
        }
    }
    func sprolPosition(atSprol sprolI: Int, atPit pitI: Int, from note: Note) -> Point {
        let hlw = toneHeight / 2
        let sprol = note.pits[pitI].tone.spectlope.sprols[sprolI]
        let ny = sprol.pitch.clipped(min: Score.doubleMinPitch,
                                     max: Score.doubleMaxPitch,
                                     newMin: -hlw, newMax: hlw)
        let pitP = pitPosition(atPit: pitI, from: note)
        return pitP + .init(0, ny + toneY)
    }
    func sprolPosition(atSprol sprolI: Int, atPit pitI: Int, at noteI: Int) -> Point {
        sprolPosition(atSprol: sprolI, atPit: pitI, from: model.notes[noteI])
    }
    func spectlopePitch(at p: Point, at noteI: Int) -> Double {
        let noteY = noteY(atX: p.x, at: noteI) + toneY
        let hlw = toneHeight / 2
        return p.y.clipped(min: noteY - hlw, max: noteY + hlw,
                           newMin: Score.doubleMinPitch,
                           newMax: Score.doubleMaxPitch)
    }
    func nearestSprol(at p: Point, at noteI: Int) -> Sprol {
        let noteY = noteY(atX: p.x, at: noteI) + toneY
        let note = model.notes[noteI]
        let tone = note.pitResult(atBeat: beat(atX: p.x) - .init(note.beatRange.start)).tone
        let hlw = toneHeight / 2
        let pitch = p.y.clipped(min: noteY - hlw, max: noteY + hlw,
                                newMin: Score.doubleMinPitch,
                                newMax: Score.doubleMaxPitch)
        return tone.spectlope.sprol(atPitch: pitch)
    }
    
    func splittedPit(at p: Point, at noteI: Int, beatInterval: Rational, pitchInterval: Rational) -> Pit {
        let note = model.notes[noteI]
        let beat: Double = beat(atX: p.x)
        let result = note.pitResult(atBeat: beat - .init(note.beatRange.start))
        let pitch = switch result.pitch {
        case .rational(let rational):
            rational.interval(scale: beatInterval)
        case .real(let real):
            Rational(real, intervalScale: pitchInterval)
        }
        return .init(beat: self.beat(atX: p.x, interval: beatInterval) - note.beatRange.start,
                     pitch: pitch,
                     stereo: result.stereo.with(id: .init()),
                     tone: result.tone.with(id: .init()))
    }
    func pitPosition(atPit pitI: Int, at noteI: Int) -> Point {
        pitPosition(atPit: pitI, from: model.notes[noteI])
    }
    func pitPosition(atPit pitI: Int, from note: Note) -> Point {
        .init(x(atBeat: note.beatRange.start + note.pits[pitI].beat),
              y(fromPitch: note.pitch + note.pits[pitI].pitch))
    }
}
