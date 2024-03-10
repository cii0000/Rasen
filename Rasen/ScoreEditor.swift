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
    func width(atBeatDuration beatDur: Rational) -> Double
    func width(atBeatDuration beatDur: Double) -> Double
    func width(atSecDuration secDur: Rational) -> Double
    func width(atSecDuration secDur: Double) -> Double
    func beat(atX x: Double, interval: Rational) -> Rational
    func beat(atX x: Double) -> Rational
    func beat(atX x: Double) -> Double
    func beatDuration(atWidth w: Double) -> Double
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
    
    func width(atBeatDuration beatDur: Rational) -> Double {
        width(atBeatDuration: Double(beatDur))
    }
    func width(atBeatDuration beatDur: Double) -> Double {
        beatDur * Sheet.beatWidth
    }
    func width(atSecDuration secDur: Rational) -> Double {
        width(atBeatDuration: beat(fromSec: secDur))
    }
    func width(atSecDuration secDur: Double) -> Double {
        width(atBeatDuration: beat(fromSec: secDur))
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
    func beatDuration(atWidth w: Double) -> Double {
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
             pitchSmp,
             endBeat
    }
    
    private let editableInterval = 5.0
    private let editableTempoInterval = 10.0
    
    private var node = Node()
    private var notePlayer: NotePlayer?
    private var sheetView: SheetView?
    private var type: SlideType?, overtoneType = OvertoneType.evenSmp
    private var beganSP = Point(), beganTime = Rational(0), beganInP = Point()
    private var beganLocalStartPitch = Rational(0), secI = 0, noteI: Int?, pitI: Int?,
                beganBeatRange: Range<Rational>?,
                currentBeatNoteIndexes = [Int](),
                beganDeltaNoteBeat = Rational(),
                oldNotePitch: Rational?, oldNoteBeat: Rational?,
                minScorePitch = Rational(0), maxScorePitch = Rational(0)
    private var beganStartBeat = Rational(0), beganPitch: Rational?
    private var beganTone = Tone(), beganOvertone = Overtone(), beganEnvelope = Envelope()
    private var pitchSmpI: Int?, beganPitchSmp = Point()
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
                beganInP = inP
                self.sheetView = sheetView
                beganTime = sheetView.animationView.beat(atX: inP.x)
                
                let scoreP = scoreView.convert(inP, from: sheetView.node)
                if let noteI = scoreView.noteIndex(at: scoreP, scale: document.screenToWorldScale) {
                    let note = score.notes[noteI]
                    
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
                    case .pitchSmp(let pitI, let pitchSmpI):
                        type = .pitchSmp
                        
                        beganTone = score.notes[noteI].pits[pitI].tone
                        self.pitchSmpI = pitchSmpI
                        self.beganPitchSmp = scoreView.pitchSmp(at: scoreP, at: noteI)
                        self.noteI = noteI
                        self.pitI = pitI
                        
                        func updatePitsWithSelection(noteI: Int, pitI: Int?, _ type: PitIDType) {
                            var noteAndPitIs: [Int: [Int]]
                            if document.isSelect(at: p) {
                                noteAndPitIs = sheetView.noteAndPitIndexes(from: document.selections)
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
                        
                        currentBeatNoteIndexes = beganNotes.keys.sorted()
                            .filter { score.notes[$0].beatRange.contains(note.beatRange.center) }
                    case nil:
                        let pitch = document.pitch(from: scoreView, at: scoreP)
                        let nsx = scoreView.x(atBeat: note.beatRange.start)
                        let nex = scoreView.x(atBeat: note.beatRange.end)
                        let nfsw = (nex - nsx) * document.worldToScreenScale
                        let dx = nfsw.clipped(min: 3, max: 30, newMin: 1, newMax: 10)
                        * document.screenToWorldScale
                        
                        type = if abs(scoreP.x - nsx) < dx {
                            .startNoteBeat
                        } else if abs(scoreP.x - nex) < dx {
                            .endNoteBeat
                        } else {
                            .note
                        }
                        
                        let interval = document.currentNoteTimeInterval
                        let nsBeat = scoreView.beat(atX: inP.x, interval: interval)
                        beganPitch = pitch
                        beganStartBeat = nsBeat
                        let dBeat = note.beatRange.start - note.beatRange.start.interval(scale: interval)
                        beganDeltaNoteBeat = -dBeat
                        beganBeatRange = note.beatRange
                        oldNotePitch = note.pitch
                        
                        if document.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: document.selections)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                        let beat = scoreView.beat(atX: scoreP.x)
                            .clipped(min: note.beatRange.start, max: note.beatRange.end)
                        currentBeatNoteIndexes = beganNotes.keys.sorted()
                            .filter { score.notes[$0].beatRange.contains(beat) }
                    }
                    
                    let volume = Volume(smp: sheetView.isPlaying ? 0.1 : 1)
                    if let notePlayer = sheetView.notePlayer {
                        self.notePlayer = notePlayer
                        notePlayer.notes = currentBeatNoteIndexes.map { score.notes[$0] }
                        notePlayer.volume = volume
                    } else {
                        notePlayer = try? NotePlayer(notes: currentBeatNoteIndexes.map { score.notes[$0] },
                                                     volume: volume)
                        sheetView.notePlayer = notePlayer
                    }
                    notePlayer?.play()
                } else if abs(scoreP.x - scoreView.x(atBeat: score.beatDuration)) < document.worldKnobEditDistance {
                    
                    type = .endBeat
                    
                    beganScoreOption = sheetView.model.score.option
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
                        let pitch = document.pitch(from: scoreView, at: scoreP)
                        let interval = document.currentNoteTimeInterval
                        let nsBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                        
                        if pitch != oldNotePitch || nsBeat != oldNoteBeat {
                            let dBeat = nsBeat - beganBeatRange.start
                            let dPitch = pitch - beganPitch
                            
                            let endBeat = sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)
                            
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
                            
                            oldNoteBeat = nsBeat
                            
                            if pitch != oldNotePitch {
                                notePlayer?.notes = currentBeatNoteIndexes.map { scoreView[$0] }
                                oldNotePitch = pitch
                            }
                            document.updateSelects()
                        }
                    }
                case .endNoteBeat:
                    if let beganPitch, let beganBeatRange {
                        let pitch = document.pitch(from: scoreView, at: scoreP)
                        let interval = document.currentNoteTimeInterval
                        let neBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                        
                        if pitch != oldNotePitch || neBeat != oldNoteBeat {
                            let dBeat = neBeat - beganBeatRange.end
                            let dPitch = pitch - beganPitch
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
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
                            
                            oldNoteBeat = neBeat
                            
                            if pitch != oldNotePitch {
                                notePlayer?.notes = currentBeatNoteIndexes.map { scoreView[$0] }
                                oldNotePitch = pitch
                            }
                            document.updateSelects()
                        }
                    }
                case .note:
                    if let beganPitch {
                        let pitch = document.pitch(from: scoreView, at: scoreP)
                        let interval = document.currentNoteTimeInterval
                        let nsBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                        
                        if pitch != oldNotePitch || nsBeat != oldNoteBeat {
                            let dBeat = nsBeat - beganStartBeat + beganDeltaNoteBeat
                            let dPitch = pitch - beganPitch
                            
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let endBeat = sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)
                           
                            for (ni, beganNote) in beganNotes {
                                guard ni < score.notes.count else { continue }
                                
                                let nBeat = dBeat + beganNote.beatRange.start
                                
                                var note = beganNote
                                note.pitch = (dPitch + beganNote.pitch)
                                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                                note.beatRange.start = max(min(nBeat, endBeat), startBeat - beganNote.beatRange.length)
                                
                                scoreView[ni] = note
                            }
                            
                            oldNoteBeat = nsBeat
                            
                            if pitch != oldNotePitch {
                                notePlayer?.notes = currentBeatNoteIndexes.map { scoreView[$0] }
                                oldNotePitch = pitch
                            }
                            document.updateSelects()
                        }
                    }
                    
                case .attack:
                    let screenScale = document.screenToWorldScale / 50
                    let attackSec = ((sp.x - beganSP.x) * screenScale
                                    + beganEnvelope.attackSec.squareRoot())
                        .clipped(min: 0, max: 1).squared
                    
                    for ni in beganNotes.keys {
                        guard ni < score.notes.count else { continue }
                        var env = scoreView.model.notes[ni].envelope
                        env.attackSec = attackSec
                        env.id = beganEnvelope.id
                        scoreView[ni].envelope = env
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) }, with: scoreView.model)
                case .decay:
                    let screenScale = document.screenToWorldScale / 50
                    let decaySec = ((sp.x - beganSP.x) * screenScale
                                    + beganEnvelope.decaySec.squareRoot())
                        .clipped(min: 0, max: 1).squared
                    let nSmp = ((sp.y - beganSP.y) * screenScale
                                + Volume(amp: beganEnvelope.sustainAmp).smp)
                        .clipped(min: 0, max: 1)
                    let sustainAmp = Volume(smp: nSmp).amp
                    
                    for ni in beganNotes.keys {
                        guard ni < score.notes.count else { continue }
                        var env = scoreView.model.notes[ni].envelope
                        env.decaySec = decaySec
                        env.sustainAmp = sustainAmp
                        env.id = beganEnvelope.id
                        scoreView[ni].envelope = env
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) }, with: scoreView.model)
                case .release:
                    let screenScale = document.screenToWorldScale / 50
                    let releaseSec = ((sp.x - beganSP.x) * screenScale
                                    + beganEnvelope.releaseSec.squareRoot())
                        .clipped(min: 0, max: 1).squared
                    
                    for ni in beganNotes.keys {
                        guard ni < score.notes.count else { continue }
                        var env = scoreView.model.notes[ni].envelope
                        env.releaseSec = releaseSec
                        env.id = beganEnvelope.id
                        scoreView[ni].envelope = env
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) }, with: scoreView.model)
                    
                case .pitchSmp:
                    if let noteI, noteI < score.notes.count,
                       let pitI, pitI < score.notes[noteI].pits.count,
                       let pitchSmpI, pitchSmpI < score.notes[noteI].pits[pitI].tone.fqAmps.count {
                       
                        let pitchSmp = scoreView.pitchSmp(at: scoreP, at: noteI)
                        
                        var tone = beganTone
                        let opspx = tone.pitchSmps[pitchSmpI].x + pitchSmp.x - beganPitchSmp.x
                        let pspx = opspx.clipped(min: pitchSmpI - 1 >= 0 ? tone.pitchSmps[pitchSmpI - 1].x : Double(Score.pitchRange.start),
                                                 max: pitchSmpI + 1 < tone.pitchSmps.count ? tone.pitchSmps[pitchSmpI + 1].x : Double(Score.pitchRange.end))
                        tone.pitchSmps[pitchSmpI].x = pspx
                        tone.id = .init()
                        
                        for (_, v) in beganNotePits {
                            let nid = UUID()
                            for (noteI, nv) in v {
                                guard noteI < score.notes.count else { continue }
                                var note = scoreView[noteI]
                                for (pitI, _) in nv.pits {
                                    guard pitI < score.notes[noteI].pits.count,
                                          pitchSmpI < note.pits[pitI].tone.pitchSmps.count else { continue }
                                    note.pits[pitI].tone = tone
                                    note.pits[pitI].tone.id = nid
                                }
                                scoreView[noteI] = note
                            }
                        }
                        
//                        sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) }, with: scoreView.model)
                    }
                    
                case .endBeat:
                    let interval = document.currentNoteTimeInterval
                    let beat = max(scoreView.beat(atX: sheetP.x, interval: interval), 0)
                    if beat != score.beatDuration {
                        scoreView.model.beatDuration = beat
                        document.updateSelects()
                    }
                }
            }
        case .ended:
            notePlayer?.stop()
            node.removeFromParent()
            
            if let sheetView {
                if type == .endBeat {
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
    static let pitchHeight = 5.0
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
    
    let currentVolumeNode = Node(lineWidth: 3, lineType: .color(.background))
    let timeNode = Node(lineWidth: 4, lineType: .color(.content))
    
    var spectrogramMaxMel: Double?
    var peakVolume = Volume() {
        didSet {
            guard peakVolume != oldValue else { return }
            updateFromPeakVolume()
        }
    }
    func updateFromPeakVolume() {
        let frame = mainFrame
        let smp = peakVolume.smp.clipped(min: 0, max: Volume.maxSmp, newMin: 0, newMax: 1)
        let y = frame.height// * smp
        currentVolumeNode.path = Path([Point(), Point(0, y)])
        if abs(peakVolume.amp) < Audio.clippingAmp {
            currentVolumeNode.lineType = .color(Color(lightness: (1 - smp) * 100))
//            currentVolumeNode.lineType = .color(.background)
        } else {
            currentVolumeNode.lineType = .color(.warning)
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
        
        timeNode.children = [currentVolumeNode]
        
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
//        octaveNode.children.insert(nivs.map { .init(value: octaveNode(from: $0.value), index: $0.index) })
        updateChord()
    }
    func removeDraft(at noteIs: [Int]) {
        unupdateModel.draftNotes.remove(at: noteIs)
        noteIs.reversed().forEach { draftNotesNode.remove(atChild: $0) }
//        noteIs.reversed().forEach { octaveNode.remove(atChild: $0) }
        updateChord()
    }
    
    static let octaveLightness = 40.0, octaveChorma = 50.0
    static let octave0 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                               hue: 2 * .pi * 0 / 12)
    static let octave1 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                               hue: 2 * .pi * 1 / 12)
    static let octave2 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                               hue: 2 * .pi * 2 / 12)
    static let octave3 = Color(lightness: octaveLightness, nearestChroma: octaveChorma, 
                               hue: 2 * .pi * 3 / 12)
    static let octave4 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                               hue: 2 * .pi * 4 / 12)
    static let octave5 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                               hue: 2 * .pi * 5 / 12)
    static let octave6 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                               hue: 2 * .pi * 6 / 12)
    static let octave7 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                               hue: 2 * .pi * 7 / 12)
    static let octave8 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                               hue: 2 * .pi * 8 / 12)
    static let octave9 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                               hue: 2 * .pi * 9 / 12)
    static let octave10 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                                hue: 2 * .pi * 10 / 12)
    static let octave11 = Color(lightness: octaveLightness, nearestChroma: octaveChorma,
                                hue: 2 * .pi * 11 / 12)
    static func octaveColor(at i: Int) -> Color {
        switch i {
        case 0: octave0
        case 1: octave1
        case 2: octave2
        case 3: octave3
        case 4: octave4
        case 5: octave5
        case 6: octave6
        case 7: octave7
        case 8: octave8
        case 9: octave9
        case 10: octave10
        case 11: octave11
        default: fatalError()
        }
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
        let nh = pitchHeight
        let sBeat = max(score.beatRange.start, -10000),
            eBeat = min(score.beatRange.end, 10000)
        let sx = self.x(atBeat: sBeat)
        let ex = self.x(atBeat: eBeat)
        let lw = 1.0
        
        var subBorderPathlines = [Pathline]()
        
        if let range = Range<Int>(pitchRange) {
            let unisonsSet = Set(score.notes.compactMap { Int($0.pitch.rounded().mod(12)) })
            for pitch in range {
                guard unisonsSet.contains(pitch.mod(12)) else { continue }
                let py = self.y(fromPitch: Rational(pitch))
                subBorderPathlines.append(Pathline(Rect(x: sx, y: py - lw / 2,
                                                        width: ex - sx, height: lw)))
            }
        }
        
        var beatRangeAndPitchs = [(Range<Rational>, Int)]()
        for note in score.notes {
            guard pitchRange.contains(note.pitch) else { continue }
            
            beatRangeAndPitchs.append((note.beatRange, note.roundedPitch))
        }
        
        let chordBeats = score.keyBeats
        
        let nChordBeats = chordBeats.filter { $0 < score.beatRange.end }.sorted()
        var preBeat: Rational = 0
        var chordRanges = nChordBeats.count.array.map {
            let v = preBeat ..< chordBeats[$0]
            preBeat = chordBeats[$0]
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
            
            var typersDic = [Int: [(typer: Chord.ChordTyper,
                                    typerIndex: Int,
                                    isInvrsion: Bool)]]()
            for (ti, typer) in chord.typers.sorted(by: { $0.index < $1.index }).enumerated() {
                let inversionUnisons = typer.inversionUnisons
                var j = typer.index
                let fp = pitchs[j]
                for i in 0 ..< typer.type.unisons.count {
                    guard j < pitchs.count else { break }
                    if typersDic[j] != nil {
                        typersDic[j]?.append((typer, ti, typer.inversion == i))
                    } else {
                        typersDic[j] = [(typer, ti, typer.inversion == i)]
                    }
                    while j + 1 < pitchs.count, !inversionUnisons.contains(pitchs[j + 1] - fp) {
                        j += 1
                    }
                    j += 1
                }
            }
            
            let nsx = x(atBeat: tr.start), nex = x(atBeat: tr.end)
            let maxTyperCount = min(chord.typers.count, Int((nex - nsx) / 5))
            let d = 2.0, nw = 5.0 * Double(maxTyperCount - 1)
            
            for (i, typers) in typersDic {
                func appendChordMark(at ti: Int, isInversion: Bool, _ typer: Chord.ChordTyper,
                                     atY cy: Double) {
                    let tlw = 0.5
                    let lw = switch typer.type {
                    case .major, .power: 5 * tlw
                    case .suspended: 3 * tlw
                    case .minor: 7 * tlw
                    case .augmented: 5 * tlw
                    case .flatfive: 3 * tlw
                    case .diminish, .tritone: 1 * tlw
                    }
                    
                    let x = -nw / 2 + 5.0 * Double(ti)
                    let fx = (nex + nsx) / 2 + x - lw / 2
                    let fy0 = cy + 1, fy1 = cy - 1 - d
                    
                    let minorCount = switch typer.type {
                    case .minor: 4
                    case .augmented: 3
                    case .flatfive: 2
                    case .diminish: 1
                    case .tritone: 1
                    default: 0
                    }
                    
                    if minorCount > 0 {
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
                    } else {
                        subBorderPathlines.append(Pathline(Rect(x: fx, y: fy0,
                                                                width: lw, height: d)))
                        subBorderPathlines.append(Pathline(Rect(x: fx, y: fy1,
                                                                width: lw, height: d)))
                    }
                    if isInversion {
                        let ilw = 1.0
                        subBorderPathlines.append(Pathline(Rect(x: fx - ilw, y: fy0 + d,
                                                                width: lw + 2 * ilw, height: ilw)))
                        subBorderPathlines.append(Pathline(Rect(x: fx - ilw, y: fy1 - ilw,
                                                                width: lw + 2 * ilw, height: ilw)))
                    }
                }
                
                func append(pitch: Rational) {
                    let ilw = 2.0
                    let y = self.y(fromPitch: pitch)
                    subBorderPathlines.append(Pathline(Rect(x: nsx, y: y - ilw / 2,
                                                            width: nex - nsx, height: ilw)))
                    
                    for (_, typerTuple) in typers.enumerated() {
                        guard typerTuple.typerIndex < maxTyperCount else { continue }
                        appendChordMark(at: typerTuple.typerIndex,
                                        isInversion: typerTuple.isInvrsion,
                                        typerTuple.typer, atY: y)
                    }
                }
                
                var nPitch = Rational(pitchs[i])
                append(pitch: nPitch)
                while true {
                    nPitch -= 12
                    guard pitchRange.contains(nPitch) else { break }
                    append(pitch: nPitch)
                }
                nPitch = Rational(pitchs[i])
                while true {
                    nPitch += 12
                    guard pitchRange.contains(nPitch) else { break }
                    append(pitch: nPitch)
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
        
        var subBorderPathlines = [Pathline]()
        
        let nx = x(atBeat: note.beatRange.start)
        let nw = width(atBeatDuration: note.beatRange.length == 0 ? Sheet.fullEditBeatInterval : note.beatRange.length)
        let smpT = 0.5
        let line: Line
        if note.pits.count == 1 {
            let attackW = width(atSecDuration: note.envelope.attackSec)
            let decayW = width(atSecDuration: note.envelope.decaySec)
            let ny = self.y(fromPitch: note.pitch)
            line = Line(controls: [.init(point: Point(nx, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: smpT),
                                       .init(point: Point(nx + nw, ny), pressure: smpT),
                                       .init(point: Point(nx + nw, ny), pressure: smpT)])
        } else {
            let secDur = Double(Score.sec(fromBeat: note.beatRange.length, tempo: model.tempo))
            var aLine = note.pitbend.line(secDuration: secDur, isRelease: false,
                                             envelope: note.envelope) ?? Line()
            aLine.controls = aLine.controls.map {
                .init(point: .init($0.point.x / secDur * nw + nx,
                                   self.y(fromPitch: Double(note.pitch) + $0.point.y * 12)),
                      weight: $0.weight,
                      pressure: smpT)
            }
            line = aLine
        }
        
        let notePathlines = [Pathline(line)]
        let pd = 12 * pitchHeight
        var nPitch = note.pitch, npd = 0.0
        subBorderPathlines += notePathlines
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
        
        let nh = pitchHeight
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
    func noteNode(from note: Note) -> Node {
        var nodes = [Node]()
        let (linePathlines, overtonePathlines, lineColors, knobPathlines, fullEditKnobPathlines, lyricPaths) = notePathlineTuple(from: note)
        
        let nh = pitchHeight
        nodes += linePathlines.map {
            .init(path: Path([$0]),
                  lineWidth: nh,
                  lineType: lineColors.count == 1 ? .color(lineColors[0]) : .gradient(lineColors))
        }
        
        var overtoneColor = Self.octaveColor(at: Int(Pitch(value: note.pitch).unison))
        if !note.pitch.isInteger {
            overtoneColor.chroma *= 0.1
        }
        nodes += overtonePathlines.map {
            .init(path: Path([$0]),
                  lineWidth: nh,
                  lineType: .color(overtoneColor))
        }
        
        nodes += lyricPaths.map {
            .init(path: $0, fillType: .color(.content))
        }
        
        nodes += knobPathlines.map {
            .init(path: .init([$0]), fillType: .color(.background))
        }
        nodes += fullEditKnobPathlines.map {
            .init(name: "isFullEdit", isHidden: !isFullEdit, path: .init([$0]), fillType: .color(.background))
        }
        
        let boundingBox = nodes.reduce(into: Rect?.none) { $0 += $1.drawableBounds }
        return Node(children: nodes, path: boundingBox != nil ? Path(boundingBox!) : .init())
    }
    func noteNode(from note: Note, color: Color, lineWidth: Double) -> Node {
        var nodes = [Node]()
        let (linePathlines, overtonePathlines, _, _, _, lyricPaths) = notePathlineTuple(from: note)
        
        nodes += linePathlines.map {
            .init(path: Path([$0]), lineWidth: lineWidth, lineType: .color(color))
        }
        
        nodes += overtonePathlines.map {
            .init(path: Path([$0]), lineWidth: lineWidth, lineType: .color(color))
        }
        
        nodes += lyricPaths.map {
            .init(path: $0, fillType: .color(color))
        }
        
        return Node(children: nodes)
    }
    func notePathlineTuple(from note: Note) -> (linePathlines: [Pathline],
                                                overtonePathlines: [Pathline],
                                                lineColors: [Color],
                                                knobPathlines: [Pathline],
                                                fullEditKnobPathlines: [Pathline],
                                                lyricPaths: [Path]) {
        let noteHeight = pitchHeight
        let nx = x(atBeat: note.beatRange.start)
        let ny = self.y(fromPitch: note.pitch)
        let nw = width(atBeatDuration: note.beatRange.length == 0 ? Sheet.fullEditBeatInterval : note.beatRange.length)
        
        let nt = 0.1, h = noteHeight / 2
        let d = 1 / h
        
        func lyricPaths() -> [Path] {
            note.pits.enumerated().compactMap { (pitI, pit) in
                let p = pitPosition(atPitI: pitI, note: note)
                if !pit.lyric.isEmpty {
                    let lyricText = Text(string: pit.lyric, size: Font.smallSize)
                    let typesetter = lyricText.typesetter
                    return typesetter.path() * Transform(translationX: p.x, y: p.y - typesetter.height / 2 - 2)
                } else {
                    return nil
                }
            }
        }
        
        let env = note.envelope
        let attackW = width(atSecDuration: env.attackSec)
        let decayW = width(atSecDuration: env.decaySec)
        let releaseW = width(atSecDuration: env.releaseSec)
        
        let overtoneH = 1.0
        let scY = 2.0
        let scH = 2.0
        
        let smpT = 0.5
        if note.pits.count >= 2 {
            let secDur = Double(Score.sec(fromBeat: note.beatRange.length, tempo: model.tempo))
            
            var line = note.pitbend.line(secDuration: secDur,
                                         envelope: note.envelope) ?? Line()
            line.controls = line.controls.map {
                .init(point: .init($0.point.x / secDur * nw + nx,
                                   self.y(fromPitch: Double(note.pitch) + $0.point.y * 12)),
                      weight: $0.weight,
                      pressure: smpT)
            }
            
            var toneLine = note.pitbend.line(secDuration: secDur, isRelease: false,
                                         envelope: note.envelope) ?? Line()
            toneLine.controls = toneLine.controls.map {
                .init(point: .init($0.point.x / secDur * nw + nx,
                                   self.y(fromPitch: Double(note.pitch) + $0.point.y * 12)),
                      weight: $0.weight,
                      pressure: smpT)
            }
            
            let colors = note.pitbend.lineColors(secDuration: secDur,
                                                 envelope: note.envelope)
            
            let pitchSmpKnobPs: [Point] = note.pits.flatMap { pit in
                let p = Point(pit.t * nw + nx,
                              self.y(fromPitch: Double(note.pitch) + pit.pitch * 12) + h / 2 + overtoneH + scY)
                return pit.tone.pitchSmps.map {
                    Point(p.x, p.y + $0.x.clipped(min: Double(Score.pitchRange.start), max: Double(Score.pitchRange.end), newMin: -scH / 2, newMax: scH / 2))
                }
            }
            
            let knobPs = 
//            [Point(nx + attackW, ny + noteHeight),
//                          Point(nx + attackW + decayW, ny + noteHeight),
//                          Point(nx + nw + releaseW, ny + noteHeight)] + 
            pitchSmpKnobPs
            let fullEditKnobPathlines = knobPs.map {
                Pathline(circleRadius: 0.0625, position: $0)
            }
            
            let knobPathlines = note.pits.map {
                Pathline(circleRadius: 0.25,
                         position: .init($0.t * nw + nx,
                                         self.y(fromPitch: Double(note.pitch) + $0.pitch * 12)))
            }
            
            let line1 = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y + overtoneH / 2 + $0.pressure * h), pressure: overtoneH / noteHeight) })
            let line2 = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y - overtoneH / 2 - $0.pressure * h), pressure: overtoneH / noteHeight) })
            
            let scLine = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y + overtoneH + scY + $0.pressure * h), pressure: scH / noteHeight) })
            
            if note.isNoise {
                let line3 = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y + d * 2 + $0.pressure * h), pressure: overtoneH / noteHeight) })
                return (line.isEmpty ? [] : [.init(line)],
                        [.init(line1), .init(line2), .init(scLine), .init(line3)],
                        colors, knobPathlines, fullEditKnobPathlines, lyricPaths())
            } else {
                return (line.isEmpty ? [] : [.init(line)],
                        [.init(line1), .init(line2), .init(scLine)],
                        colors, knobPathlines, fullEditKnobPathlines, lyricPaths())
            }
        } else {
//            let sustain = Volume(amp: env.sustainAmp).smp
//                .clipped(min: 0, max: Volume.maxSmp, newMin: 0, newMax: 1) + 1 / noteHeight
            let line = Line(controls: [.init(point: Point(nx, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: smpT),
                                       .init(point: Point(nx + nw, ny), pressure: smpT),
                                       .init(point: Point(nx + nw, ny), pressure: smpT),
                                       .init(point: Point(nx + nw + releaseW, ny), pressure: smpT)])
            
            let toneLine = Line(controls: [.init(point: Point(nx, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW + decayW, ny), pressure: smpT),
                                       .init(point: Point(nx + nw, ny), pressure: smpT),
                                       .init(point: Point(nx + nw, ny), pressure: smpT)])
            
//            let lines = (0 ... 20).map { i in
//                let s = Double(i) / 20
//                
//                let l = note.tone.sourceFilter.smp(atMel: s * NoiseSourceFilter.maxMel)
//                    .clipped(min: 0, max: 1, newMin: 75, newMax: 25)
//                return Line(controls: line.controls.map {
//                    .init(point: .init($0.point.x, $0.point.y - $0.pressure * h + $0.pressure * h * 2 * s),
//                          pressure: $0.pressure / 20)
//                }, uuColor: UU(Color(lightness: l)))
//            }
        
            let pitchSmpKnobPs = note.firstTone.pitchSmps.map {
                Point(nx, ny + $0.x.clipped(min: Double(Score.pitchRange.start), max: Double(Score.pitchRange.end), newMin: -scH / 2, newMax: scH / 2) + h / 2 + overtoneH + scY)
            }
            
            let knobPs = 
//            [Point(nx + attackW, ny + noteHeight + scY),
//                          Point(nx + attackW + decayW, ny + noteHeight + scY),
//                          Point(nx + nw + releaseW, ny + noteHeight + scY)] + 
            pitchSmpKnobPs
            let fullEditKnobPathlines = knobPs.map {
                Pathline(circleRadius: 0.0625, position: $0)
            }
            
            let nv = Color(lightness: (1 - note.pits[0].stereo.smp) * 100).rgba.r
            let color = Pitbend.panColor(pan: note.pits[0].stereo.pan, brightness: Double(nv))
            
            let line1 = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y + overtoneH / 2 + $0.pressure * h), pressure: overtoneH / noteHeight) })
            let line2 = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y - overtoneH / 2 - $0.pressure * h), pressure: overtoneH / noteHeight) })
            
            let scLine = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y + overtoneH + scY + $0.pressure * h), pressure: scH / noteHeight) })
            
            if note.isNoise {
                let line3 = Line(controls: toneLine.controls.map { .init(point: .init($0.point.x, $0.point.y - d * 5 - $0.pressure * h), pressure: overtoneH / noteHeight) })
                return ([.init(line)],
                        [.init(line1), .init(line2), .init(scLine), .init(line3)],
                        [color], [], fullEditKnobPathlines, lyricPaths())
            } else {
                return ([.init(line)],
                        [.init(line1), .init(line2), .init(scLine)],
                        [color], [], fullEditKnobPathlines, lyricPaths())
            }
        }
    }
    
    func noteLine(from note: Note) -> Line {
        let nsx = x(atBeat: note.beatRange.start)
        let nex = x(atBeat: note.beatRange.end)
        let ny = y(fromPitch: note.pitch)
        if note.pits.count >= 2 {
            let secDur = Double(model.sec(fromBeat: note.beatRange.length))
            
            var line = note.pitbend.line(secDuration: secDur, envelope: note.envelope) ?? Line()
            line.controls = line.controls.map {
                .init(point: .init(.linear(nsx, nex, t: $0.point.x / secDur),
                                   y(fromPitch: Double(note.pitch) + $0.point.y * 12)),
                      weight: $0.weight,
                      pressure: $0.pressure)
            }
            return line
        } else {
            return Line(edge: .init(.init(nsx, ny), .init(nex, ny)))
        }
    }
    func releasePosition(from note: Note) -> Point {
        let nx = x(atBeat: note.beatRange.end)
        let ny = self.y(fromPitch: note.pitch)
        let releaseW = width(atSecDuration: note.envelope.releaseSec)
        return .init(nx + releaseW, ny)
    }
    
    func updateTimeNode(atSec sec: Rational) {
        if model.enabled {
            let frame = mainFrame
            let x = self.x(atSec: sec)
            if x >= frame.minX && x < frame.maxX {
                timeNode.path = Path([Point(), Point(0, frame.height)])
                timeNode.attitude.position = Point(x, frame.minY)
                updateFromPeakVolume()
            } else {
                timeNode.path = Path()
                currentVolumeNode.path = Path()
            }
        } else if !timeNode.path.isEmpty {
            timeNode.path = Path()
            currentVolumeNode.path = Path()
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
    func noteIndex(at p: Point, scale: Double) -> Int? {
        let maxD = Sheet.knobEditDistance * scale + (pitchHeight / 2 + 5) / 2
        let maxDS = maxD * maxD, hnh = pitchHeight / 2
        var minDS = Double.infinity, minI: Int?
        for (noteI, note) in model.notes.enumerated() {
            let nf = noteFrame(at: noteI).outset(by: hnh)
            let ods = nf.distanceSquared(p)
            if ods < maxDS {
                let ds = noteLine(from: note).minDistanceSquared(at: p - Point(0, 5 / 2))
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
        case pitchSmp(pitI: Int, pitchSmpI: Int)
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
        let ap = Point(ax, noteY(atX: ax, at: noteI) + noteH(atX: ax, at: noteI))
        let decayBeat = Double(note.beatRange.start) + score.beat(fromSec: note.envelope.attackSec + note.envelope.decaySec)
        let dx = x(atBeat: decayBeat)
        let dp = Point(dx, noteY(atX: dx, at: noteI) + noteH(atX: dx, at: noteI))
        let releaseBeat = Double(note.beatRange.end) + score.beat(fromSec: note.envelope.releaseSec)
        let rx = x(atBeat: releaseBeat)
        let rp = Point(rx, noteY(atX: dx, at: noteI))
        
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
            for (pitchSmpI, _) in pit.tone.pitchSmps.enumerated() {
                let psp = pitchSmpPosition(atPitchSmpI: pitchSmpI, pitI: pitI, note: note)
                let ds = psp.distanceSquared(p)
                if ds < minDS && ds < maxDS {
                    minDS = ds
                    minResult = .pitchSmp(pitI: pitI, pitchSmpI: pitchSmpI)
                }
            }
        }
        
        return minResult
    }
    
    enum ColorHitResult {
        case note
        case sustain
        case pit(pitI: Int)
        case evenSmp(pitI: Int)
        case oddSmp(pitI: Int)
        case pitchSmp(pitI: Int, pitchSmpI: Int)
        
        var isTone: Bool {
            switch self {
            case .evenSmp, .oddSmp, .pitchSmp: true
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
                    for (pitchSmpI, _) in pit.tone.pitchSmps.enumerated() {
                        let psp = pitchSmpPosition(atPitchSmpI: pitchSmpI, pitI: pitI, note: note)
                        let dsd = psp.distanceSquared(p)
                        if dsd < minDS && dsd < maxDS {
                            minDS = dsd
                            minNoteI = noteI
                            minResult = .pitchSmp(pitI: pitI, pitchSmpI: pitchSmpI)
                        }
                    }
                    
                    let pitP = pitPosition(atPitI: pitI, note: note)
                    let noteH = pitchHeight / 2
                    let noteY = noteY(atT: pit.t, at: noteI)
                    if abs(noteY) > noteH / 2 {
                        let evenP = Point(pitP.x, pitP.y + noteH / 2 + 1 / 2)
                        let evenDsd = evenP.distanceSquared(p)
                        if evenDsd < minDS && evenDsd < maxDS {
                            minDS = evenDsd
                            minNoteI = noteI
                            minResult = .evenSmp(pitI: pitI)
                        }
                        let oddP = Point(pitP.x, pitP.y - noteH / 2 - 1 / 2)
                        let oddDsd = oddP.distanceSquared(p)
                        if oddDsd < minDS && oddDsd < maxDS {
                            minDS = oddDsd
                            minNoteI = noteI
                            minResult = .oddSmp(pitI: pitI)
                        }
                    }
                }
                
                let decayBeat = Double(note.beatRange.start)
                + score.beat(fromSec: note.envelope.attackSec + note.envelope.decaySec)
                let dx = x(atBeat: decayBeat)
                let dp = Point(dx, self.noteY(atX: dx, at: noteI) + self.noteH(atX: dx, at: noteI))
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
        let line = noteLine(from: model.notes[noteI])
        if otherRect.contains(line.firstPoint) {
            return true
        } else {
            let x0y0 = otherRect.origin
            let x1y0 = Point(otherRect.maxX, otherRect.minY)
            let x0y1 = Point(otherRect.minX, otherRect.maxY)
            let x1y1 = Point(otherRect.maxX, otherRect.maxY)
            func intersects(_ edge: Edge) -> Bool {
                for b in line.bezierSequence {
                    if b.intersects(edge) {
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
        let line = noteLine(from: model.draftNotes[noteI])
        if otherRect.contains(line.firstPoint) {
            return true
        } else {
            let x0y0 = otherRect.origin
            let x1y0 = Point(otherRect.maxX, otherRect.minY)
            let x0y1 = Point(otherRect.minX, otherRect.maxY)
            let x1y1 = Point(otherRect.maxX, otherRect.maxY)
            func intersects(_ edge: Edge) -> Bool {
                for b in line.bezierSequence {
                    if b.intersects(edge) {
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
    func noteT(atX x: Double, at noteI: Int) -> Double {
        let note = model.notes[noteI]
        let sx = self.x(atBeat: note.beatRange.start)
        let ex = self.x(atBeat: note.beatRange.end)
        return ((x - sx) / (ex - sx)).clipped(min: 0, max: 1)
    }
    func noteX(atT t: Double, at noteI: Int) -> Double {
        let note = model.notes[noteI]
        let sx = self.x(atBeat: note.beatRange.start)
        let ex = self.x(atBeat: note.beatRange.end)
        return .linear(sx, ex, t: t)
    }
    func noteY(atX x: Double, at noteI: Int) -> Double {
        noteY(atT: noteT(atX: x, at: noteI), at: noteI)
    }
    func noteY(atT t: Double, at noteI: Int) -> Double {
        let note = model.notes[noteI]
        return self.y(fromPitch: note.pitbend.pitch(atT: t) * 12 + Double(note.pitch))
    }
    func stereo(atX x: Double, at noteI: Int) -> Stereo {
        let note = model.notes[noteI]
        let t = noteT(atX: x, at: noteI)
        return note.pitbend.stereo(atT: t)
    }
    func smp(atX x: Double, at noteI: Int) -> Double {
        stereo(atX: x, at: noteI).smp
    }
    func pan(atX x: Double, at noteI: Int) -> Double {
        stereo(atX: x, at: noteI).pan
    }
    func noteH(atX x: Double, at noteI: Int) -> Double {
        pitchHeight / 2 * smp(atX: x, at: noteI)
    }
    func noteH(atT t: Double, at noteI: Int) -> Double {
        let note = model.notes[noteI]
        return pitchHeight / 2 * note.pitbend.stereo(atT: t).smp
    }
    
    func pitPosition(atPitI pitI: Int, noteI: Int) -> Point {
        pitPosition(atPitI: pitI, note: model.notes[noteI])
    }
    func pitPosition(atPitI pitI: Int, note: Note) -> Point {
        let sx = x(atBeat: note.beatRange.start)
        let ex = x(atBeat: note.beatRange.end)
        let pit = note.pits[pitI]
        return Point(.linear(sx, ex, t: pit.t),
                     y(fromPitch: pit.pitch * 12 + .init(note.pitch)))
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

            let sx = x(atBeat: note.beatRange.start)
            let ex = x(atBeat: note.beatRange.end)
            for (pitI, pit) in note.pits.enumerated() {
                let pitP = Point(.linear(sx, ex, t: pit.t),
                                 y(fromPitch: pit.pitch * 12 + .init(note.pitch)))
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
        let maxD = Sheet.knobEditDistance * scale
        let maxDS = maxD * maxD
        var minPitI: Int?, minDS = Double.infinity
        let note = model.notes[noteI]
        guard note.pits.count > 1 else { return nil }

        let sx = x(atBeat: note.beatRange.start)
        let ex = x(atBeat: note.beatRange.end)
        for (pitI, pit) in note.pits.enumerated() {
            let pitP = Point(.linear(sx, ex, t: pit.t),
                             y(fromPitch: pit.pitch * 12 + .init(note.pitch)))
            let ds = pitP.distanceSquared(p)
            if ds < minDS && ds < maxDS {
                minPitI = pitI
                minDS = ds
            }
        }
        
        return if let minPitI {
            minPitI
        } else {
            nil
        }
    }
    var toneY: Double {
        pitchHeight / 2 / 2 + 3
    }
    var toneHeight: Double {
        2
    }
    func pitIAndPitchSmpI(at p: Point, at noteI: Int) -> (pitI: Int, pitchSmpI: Int)? {
        guard isFullEdit,
                p.y > noteY(atX: p.x, at: noteI) + toneY - toneHeight / 2 else { return nil }
        
        let score = model
        let note = score.notes[noteI]
        var minDS = Double.infinity, minPitI: Int?, minPitchSmpI: Int?
        for (pitI, pit) in note.pits.enumerated() {
            for (pitchSmpI, _) in pit.tone.pitchSmps.enumerated() {
                let psp = pitchSmpPosition(atPitchSmpI: pitchSmpI, pitI: pitI, note: note)
                let ds = p.distanceSquared(psp)
                if ds < minDS {
                    minDS = ds
                    minPitI = pitI
                    minPitchSmpI = pitchSmpI
                }
            }
        }
        
        return if let minPitI, let minPitchSmpI {
            (minPitI, minPitchSmpI)
        } else {
            nil
        }
    }
    func pitchSmpPosition(atPitchSmpI pitchSmpI: Int, pitI: Int, note: Note) -> Point {
        let hlw = toneHeight / 2
        let pitchSmp = note.pits[pitI].tone.pitchSmps[pitchSmpI]
        let ny = pitchSmp.x.clipped(min: Double(Score.pitchRange.start),
                                    max: Double(Score.pitchRange.end),
                                    newMin: -hlw, newMax: hlw)
        let pitP = pitPosition(atPitI: pitI, note: note)
        return Point(pitP.x, pitP.y + ny + toneY)
    }
    func pitchSmpPosition(atPitchSmpI pitchSmpI: Int, pitI: Int, noteI: Int) -> Point {
        pitchSmpPosition(atPitchSmpI: pitchSmpI, pitI: pitI, note: model.notes[noteI])
    }
    func pitchSmp(at p: Point, at noteI: Int) -> Point {
        let noteT = noteT(atX: p.x, at: noteI)
        let noteY = noteY(atX: p.x, at: noteI) + toneY
        let tone = model.notes[noteI].pitbend.pit(atT: noteT).tone
        let hlw = toneHeight / 2
        let pitch = p.y.clipped(min: noteY - hlw, max: noteY + hlw,
                                newMin: Double(Score.pitchRange.start),
                                newMax: Double(Score.pitchRange.end))
        let smp = tone.smp(atPitch: pitch)
        return .init(pitch, smp)
    }
    func pitT(at p: Point, at noteI: Int) -> Double {
        let note = model.notes[noteI]
        let sx = x(atBeat: note.beatRange.start)
        let ex = x(atBeat: note.beatRange.end)
        let v = noteLine(from: note).nearest(at: p)
        let npx = v.point.x
        return ((npx - sx) / (ex - sx)).clipped(min: 0, max: 1)
    }
}
