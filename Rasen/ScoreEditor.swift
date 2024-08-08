// Copyright 2024 Cii
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
    func sec(atX x: Double) -> Double {
        sec(fromBeat: beat(atX: x))
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

final class ToneShower: InputKeyEditor {
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
            
            if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                let inP = sheetView.convertFromWorld(p)
               
                if document.isSelectSelectedNoneCursor(at: p), !document.isSelectedText {
                    let scoreView = sheetView.scoreView
                    let nIsShownTone = scoreView.containsNote(scoreView.convertFromWorld(p),
                                                              scale: document.screenToWorldScale)
                    let toneIs = sheetView.noteIndexes(from: document.selections).filter {
                        scoreView.model.notes[$0].isShownTone != nIsShownTone
                    }
                    if !toneIs.isEmpty {
                        sheetView.newUndoGroup()
                        sheetView.setIsShownTones(toneIs.map { .init(value: nIsShownTone, index: $0) })
                    }
                } else {
                    if let (noteI, pitI) = sheetView.scoreView.noteAndPitIEnabledNote(at: inP, scale: document.screenToWorldScale) {
                        let id = sheetView.scoreView.model.notes[noteI].pits[pitI].tone.id
                        let toneIs = sheetView.scoreView.model.notes.enumerated().compactMap {
                            !$0.element.isShownTone && $0.element.pits.contains { $0.tone.id == id } ? $0.offset : nil
                        }
                        if !toneIs.isEmpty {
                            sheetView.newUndoGroup()
                            sheetView.setIsShownTones(toneIs.map { .init(value: true, index: $0) })
                        }
                    } else {
                        let toneIs = sheetView.scoreView.model.notes.enumerated().compactMap {
                            $0.element.isShownTone ? $0.offset : nil
                        }
                        if !toneIs.isEmpty {
                            sheetView.newUndoGroup()
                            sheetView.setIsShownTones(toneIs.map { .init(value: false, index: $0) })
                        }
                    }
                }
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
             keyBeats, endBeat, isShownSpectrogram
    }
    
    private let editableInterval = 5.0
    private let editableTempoInterval = 10.0
    
    private var node = Node()
    private var notePlayer: NotePlayer?
    private var sheetView: SheetView?
    private var type: SlideType?
    private var beganSP = Point(), beganTime = Rational(0), beganSheetP = Point()
    private var beganLocalStartPitch = Rational(0), secI = 0, noteI: Int?, pitI: Int?, keyBeatI: Int?,
                beganBeatRange: Range<Rational>?,
                playerBeatNoteIndexes = [Int](),
                beganDeltaNoteBeat = Rational(),
                oldPitch: Rational?, oldBeat: Rational?, octaveNode: Node?,
                minScorePitch = Rational(0), maxScorePitch = Rational(0)
    private var beganStartBeat = Rational(0), beganPitch: Rational?,  beganBeatX = 0.0, beganPitchY = 0.0
    private var beganTone = Tone(), beganOvertone = Overtone(), beganEnvelope = Envelope()
    private var sprolI: Int?, beganSprol = Sprol()
    private var beganScoreOption: ScoreOption?
    private var beganNotes = [Int: Note]()
    private var beganNotePits = [UUID: (nid: UUID, nColor: Color, dic: [Int: (note: Note, pits: [Int: (pit: Pit, sprolIs: Set<Int>)])])]()
    
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
            
            if document.isPlaying(with: event) {
                document.stopPlaying(with: event)
            }
            
            if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                let inP = sheetView.convertFromWorld(p)
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                
                beganSP = sp
                beganSheetP = inP
                self.sheetView = sheetView
                beganTime = sheetView.animationView.beat(atX: inP.x)
                
                func updatePlayer(from vs: [Note.PitResult], in sheetView: SheetView) {
                    if let notePlayer = sheetView.notePlayer {
                        self.notePlayer = notePlayer
                        notePlayer.notes = vs
                    } else {
                        notePlayer = try? NotePlayer(notes: vs)
                        sheetView.notePlayer = notePlayer
                    }
                    notePlayer?.play()
                }
                
                let scoreP = scoreView.convert(inP, from: sheetView.node)
                if scoreView.containsIsShownSpectrogram(scoreP, scale: document.screenToWorldScale) {
                    type = .isShownSpectrogram
                    beganScoreOption = scoreView.model.option
                } else if let noteI = scoreView.noteIndex(at: scoreP, scale: document.screenToWorldScale,
                                                   enabledRelease: true) {
                    let note = score.notes[noteI]
                    
                    let interval = document.currentBeatInterval
                    let nsBeat = scoreView.beat(atX: inP.x, interval: interval)
                    beganStartBeat = nsBeat
                    self.noteI = noteI
                    
                    let result = scoreView.hitTestControl(scoreP, scale: document.screenToWorldScale,
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
                        
                        func updatePitsWithSelection() {
                            var noteAndPitIs: [Int: [Int: Set<Int>]]
                            if document.isSelect(at: p) {
                                noteAndPitIs = sheetView.noteAndPitAndSprolIs(from: document.selections)
                            } else {
                                let id = score.notes[noteI].pits[pitI][.tone]
                                noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                    $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                        if ip.element[.tone] == id {
                                            v[ip.offset] = sprolI < ip.element.tone.spectlope.count ? [sprolI] : []
                                        }
                                    }
                                }
                            }
                            
                            beganNotePits = noteAndPitIs.reduce(into: .init()) {
                                for (pitI, sprolIs) in $1.value {
                                    let pit = score.notes[$1.key].pits[pitI]
                                    let id = pit[.tone]
                                    if $0[id] != nil {
                                        if $0[id]!.dic[$1.key] != nil {
                                            $0[id]!.dic[$1.key]!.pits[pitI] = (pit, sprolIs)
                                        } else {
                                            $0[id]!.dic[$1.key] = (score.notes[$1.key], [pitI: (pit, sprolIs)])
                                        }
                                    } else {
                                        $0[id] = (UUID(), Tone.randomColor(), [$1.key: (score.notes[$1.key], [pitI: (pit, sprolIs)])])
                                    }
                                }
                            }
                        }
                        
                        updatePitsWithSelection()
                        
                        let noteIsSet = Set(beganNotePits.values.flatMap { $0.dic.keys }).sorted()
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
                        
                        let interval = document.currentBeatInterval
                        let nsBeat = scoreView.beat(atX: inP.x, interval: interval)
                        beganPitch = note.pitch
                        beganStartBeat = nsBeat
                        let dBeat = note.beatRange.start - note.beatRange.start.interval(scale: interval)
                        beganDeltaNoteBeat = -dBeat
                        beganBeatRange = note.beatRange
                        oldPitch = note.pitch
                        
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
                        
                        let octaveNode = scoreView.octaveNode(fromPitch: note.pitch,
                                                              noteIs: beganNotes.keys.sorted(),
                                                              .octave)
                        octaveNode.attitude.position = sheetView.node.attitude.position
                        self.octaveNode = octaveNode
                        document.rootNode.append(child: octaveNode)
                        
                        document.cursor = .circle(string: Pitch(value: note.pitch).octaveString())
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
                        let beatInterval = document.currentBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: document.currentPitchInterval)
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                        if pitch != oldPitch || nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeatRange.start
                            let dPitch = pitch - beganPitch
                            
                            let endBeat = sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: beatInterval)
                            
                            var nivs = [IndexValue<Note>](capacity: beganNotes.count)
                            for (noteI, beganNote) in beganNotes {
                                guard noteI < score.notes.count else { continue }
                                
                                var note = beganNote
                                note.pitch = (dPitch + beganNote.pitch)
                                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                                
                                let nsBeat = min(beganNote.beatRange.start + dBeat, endBeat)
                                let neBeat = beganNote.beatRange.end
                                let beatRange = nsBeat < neBeat ? nsBeat ..< neBeat : neBeat ..< nsBeat
                                note.beatRange = beatRange
                                
                                nivs.append(.init(value: note, index: noteI))
                            }
                            scoreView.replace(nivs)
                            
                            oldBeat = nsBeat
                            
                            octaveNode?.children = scoreView.octaveNode(fromPitch: pitch,
                                                                        noteIs: beganNotes.keys.sorted(),
                                                                        .octave).children
                            
                            if pitch != oldPitch {
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.pitResult(atBeat: nsBeat, at: $0)
                                }
                                oldPitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(nsBeat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                                    document.cursor = .circle(string: Pitch(value: cPitch).octaveString(deltaPitch: dPitch))
                                }
                            }
                            document.updateSelects()
                        }
                    }
                case .endNoteBeat:
                    if let beganPitch, let beganBeatRange {
                        let beatInterval = document.currentBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: document.currentPitchInterval)
                        let neBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                        if pitch != oldPitch || neBeat != oldBeat {
                            let dBeat = neBeat - beganBeatRange.end
                            let dPitch = pitch - beganPitch
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: beatInterval)
                            
                            var nivs = [IndexValue<Note>](capacity: beganNotes.count)
                            for (noteI, beganNote) in beganNotes {
                                guard noteI < score.notes.count else { continue }
                                
                                var note = beganNote
                                note.pitch = (dPitch + beganNote.pitch)
                                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                                
                                let nsBeat = beganNote.beatRange.start
                                let neBeat = max(beganNote.beatRange.end + dBeat, startBeat)
                                let beatRange = nsBeat < neBeat ? nsBeat ..< neBeat : neBeat ..< nsBeat
                                note.beatRange = beatRange
                                
                                nivs.append(.init(value: note, index: noteI))
                            }
                            scoreView.replace(nivs)
                            
                            oldBeat = neBeat
                            
                            octaveNode?.children = scoreView.octaveNode(fromPitch: pitch,
                                                                        noteIs: beganNotes.keys.sorted(),
                                                                        .octave).children
                            
                            if pitch != oldPitch {
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.pitResult(atBeat: neBeat, at: $0)
                                }
                                oldPitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(neBeat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                                    document.cursor = .circle(string: Pitch(value: cPitch).octaveString(deltaPitch: dPitch))
                                }
                            }
                            document.updateSelects()
                        }
                    }
                case .note:
                    if let beganPitch, let beganBeatRange {
                        let beatInterval = document.currentBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: document.currentPitchInterval)
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                        if pitch != oldPitch || nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeatRange.start
                            let dPitch = pitch - beganPitch
                            
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: beatInterval)
                            let endBeat = sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: beatInterval)
                           
                            var nivs = [IndexValue<Note>](capacity: beganNotes.count)
                            for (noteI, beganNote) in beganNotes {
                                guard noteI < score.notes.count else { continue }
                                
                                let nBeat = dBeat + beganNote.beatRange.start
                                
                                var note = beganNote
                                note.pitch = (dPitch + beganNote.pitch)
                                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                                note.beatRange.start = max(min(nBeat, endBeat), startBeat - beganNote.beatRange.length)
                                
                                nivs.append(.init(value: note, index: noteI))
                            }
                            scoreView.replace(nivs)
                            
                            oldBeat = nsBeat
                            
                            octaveNode?.children = scoreView.octaveNode(fromPitch: pitch,
                                                                        noteIs: beganNotes.keys.sorted(),
                                                                        .octave).children
                            
                            if pitch != oldPitch {
                                let beat: Rational = scoreView.beat(atX: scoreP.x)
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.pitResult(atBeat: beat, at: $0)
                                }
                                oldPitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(beat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                                    document.cursor = .circle(string: Pitch(value: cPitch).octaveString(deltaPitch: dPitch))
                                }
                            }
                            document.updateSelects()
                        }
                    }
                    
                case .attack:
                    let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                    let attackSec = (beganEnvelope.attackSec + score.sec(fromBeat: dBeat))
                        .clipped(min: 0, max: 10)
                    
                    let nid = UUID()
                    var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                    for noteI in beganNotes.keys {
                        guard noteI < score.notes.count else { continue }
                        var envelope = scoreView.model.notes[noteI].envelope
                        envelope.attackSec = attackSec
                        envelope.id = nid
                        eivs.append(.init(value: envelope, index: noteI))
                    }
                    scoreView.replace(eivs)
                case .decay:
                    let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                    let decaySec = (beganEnvelope.decaySec + score.sec(fromBeat: dBeat))
                        .clipped(min: 0, max: 10)
                    
                    let nid = UUID()
                    var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                    for noteI in beganNotes.keys {
                        guard noteI < score.notes.count else { continue }
                        var envelope = scoreView.model.notes[noteI].envelope
                        envelope.decaySec = decaySec
                        envelope.id = nid
                        eivs.append(.init(value: envelope, index: noteI))
                    }
                    scoreView.replace(eivs)
                case .release:
                    let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                    let releaseSec = (beganEnvelope.releaseSec + score.sec(fromBeat: dBeat))
                        .clipped(min: 0, max: 10)
                    
                    let nid = UUID()
                    var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                    for noteI in beganNotes.keys {
                        guard noteI < score.notes.count else { continue }
                        var envelope = scoreView.model.notes[noteI].envelope
                        envelope.releaseSec = releaseSec
                        envelope.id = nid
                        eivs.append(.init(value: envelope, index: noteI))
                    }
                    scoreView.replace(eivs)
                    
                case .sprol:
                    if let noteI, noteI < score.notes.count,
                       let pitI, pitI < score.notes[noteI].pits.count,
                       let sprolI, sprolI < score.notes[noteI].pits[pitI].tone.spectlope.count {
                       
                        let pitch = scoreView.spectlopePitch(at: scoreP, at: noteI)
                        let dPitch = pitch - beganSprol.pitch
                        let nPitch = (beganTone.spectlope.sprols[sprolI].pitch + dPitch)
                            .clipped(min: Score.doubleMinPitch, max: Score.doubleMaxPitch)
                        
                        var nvs = [Int: Note]()
                        for (_, v) in beganNotePits {
                            for (noteI, nv) in v.dic {
                                if nvs[noteI] == nil {
                                    nvs[noteI] = nv.note
                                }
                                nv.pits.forEach { (pitI, beganPit) in
                                    for sprolI in beganPit.sprolIs {
                                        let pitch = (beganPit.pit.tone.spectlope.sprols[sprolI].pitch + dPitch)
                                            .clipped(min: Score.doubleMinPitch, max: Score.doubleMaxPitch)
                                        nvs[noteI]?.pits[pitI].tone.spectlope.sprols[sprolI].pitch = pitch
                                    }
                                    if let tone = nvs[noteI]?.pits[pitI].tone,
                                        !tone.isDefault && tone.color == .background {
                                        nvs[noteI]?.pits[pitI].tone.color = v.nColor
                                    }
                                    nvs[noteI]?.pits[pitI].tone.id = v.nid
                                }
                            }
                        }
                        let nivs = nvs.map { IndexValue(value: $0.value, index: $0.key) }
                        scoreView.replace(nivs)
                        
                        notePlayer?.notes = playerBeatNoteIndexes.map {
                            scoreView.pitResult(atBeat: beganStartBeat, at: $0)
                        }
                        
                        document.cursor = .circle(string: Pitch(value: .init(nPitch, intervalScale: Sheet.fullEditPitchInterval)).octaveString(hidableDecimal: false))
                    }
                    
                case .keyBeats:
                    if let keyBeatI, keyBeatI < score.keyBeats.count, let beganScoreOption {
                        let interval = document.currentBeatInterval
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
                        let interval = document.currentBeatInterval
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
                case .isShownSpectrogram:
                    let scoreP = scoreView.convertFromWorld(p)
                    let isShownSpectrogram = scoreView.isShownSpectrogram(at: scoreP)
                    scoreView.isShownSpectrogram = isShownSpectrogram
                }
            }
        case .ended:
            notePlayer?.stop()
            node.removeFromParent()
            octaveNode?.removeFromParent()
            octaveNode = nil
            
            if let sheetView {
                if type == .keyBeats || type == .endBeat || type == .isShownSpectrogram {
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
                    for (noteI, beganNote) in beganNotes.sorted(by: { $0.key < $1.key }) {
                        guard noteI < score.notes.count else { continue }
                        let note = score.notes[noteI]
                        if beganNote != note {
                            noteIVs.append(.init(value: note, index: noteI))
                            oldNoteIVs.append(.init(value: beganNote, index: noteI))
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
                            for (noteI, v) in $1.value.dic {
                                $0[noteI] = v.note
                            }
                        }
                        for (noteI, beganNote) in beganNoteIAndNotes {
                            guard noteI < score.notes.count else { continue }
                            let note = scoreView.model.notes[noteI]
                            if beganNote != note {
                                noteIVs.append(.init(value: note, index: noteI))
                                oldNoteIVs.append(.init(value: beganNote, index: noteI))
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
    static let evenY = 1.0
    static let oddY = 2.0
    static let spectlopeY = 3.0
    static let envelopeY = 0.5
    static let toneColorY = 2.0
    static let tonePadding = 4.0
    static let spectlopeHeight = 20.0
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
            guard option.enabled, peakVolm != oldValue else { return }
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
        let score = model
        let sBeat = max(score.beatRange.start, -10000), eBeat = min(score.beatRange.end, 10000)
        let sx = x(atBeat: sBeat)
        let ex = x(atBeat: eBeat)
        let sy = y(fromPitch: Score.pitchRange.start)
        let ey = y(fromPitch: Score.pitchRange.end)
        return .init(x: sx, y: sy, width: ex - sx, height: ey - sy)
    }
    
    let octaveNode = Node(), draftNotesNode = Node(), notesNode = Node()
    let timelineContentNode = Node(fillType: .color(.content))
    let timelineSubBorderNode = Node(fillType: .color(.subBorder))
    let timelineBorderNode = Node(fillType: .color(.border))
    let timelineFullEditBorderNode = Node(isHidden: true, fillType: .color(.border))
    let chordNode = Node(fillType: .color(.subBorder))
    let pitsNode = Node(fillType: .color(.background))
    var tonesNode = Node()
    let clippingNode = Node(isHidden: true, lineWidth: 4, lineType: .color(.warning))
    
    var spectrogramNode: Node?
    var spectrogramFqType: Spectrogram.FqType?
    
    var scoreNoder: ScoreNoder?
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        timeNode.children = [currentPeakVolmNode]
        
        node = Node(children: [timelineBorderNode, timelineFullEditBorderNode,
                               octaveNode,
                               timelineSubBorderNode, chordNode,
                               timelineContentNode,
                               draftNotesNode, notesNode, pitsNode, tonesNode,
                               timeNode, clippingNode])
        updateClippingNode()
        updateTimeline()
        updateSpectrogram()
        updateScore()
        updateDraftNotes()
        
        if model.enabled {
            scoreNoder = .init(score: model, sampleRate: Audio.defaultSampleRate)
        }
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
            let vs = model.notes.map { noteNode(from: $0) }
            let nodes = vs.map { $0.node }
            notesNode.children = nodes
            tonesNode.children = vs.map { $0.toneNode }
            octaveNode.children = zip(model.notes, nodes).map { octaveNode(fromPitch: $0.0.firstPitch, $0.1.children[0].clone) }
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
            scoreNoder?.changeTempo(with: model)
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
    
    var pitchStartY: Double {
        32
    }
    func pitch(atY y: Double, interval: Rational) -> Rational {
        Rational((y - pitchStartY) / pitchHeight, intervalScale: interval)
    }
    func smoothPitch(atY y: Double) -> Double? {
        (y - pitchStartY) / pitchHeight
    }
    func y(fromPitch pitch: Rational) -> Double {
        Double(pitch) * pitchHeight + pitchStartY
    }
    func y(fromPitch pitch: Double) -> Double {
        pitch * pitchHeight + pitchStartY
    }
    
    func pitResult(atBeat beat: Rational, at noteI: Int) -> Note.PitResult {
        self[noteI].pitResult(atBeat: .init(beat - self[noteI].beatRange.start))
    }
    
    var option: ScoreOption {
        get { model.option }
        set {
            let oldValue = option
            
            unupdateModel.option = newValue
            updateTimeline()
            updateChord()
            updateSpectrogram()
            
            if oldValue.enabled != newValue.enabled {
                scoreNoder = newValue.enabled ? .init(score: model,
                                                      sampleRate: Audio.defaultSampleRate) : nil
            } else if oldValue.tempo != newValue.tempo {
                scoreNoder?.changeTempo(with: model)
            } else if oldValue.durBeat != newValue.durBeat {
                scoreNoder?.durSec = model.secRange.end
            }
        }
    }
    
    func append(_ note: Note) {
        unupdateModel.notes.append(note)
        let (noteNode, toneNode) = noteNode(from: note)
        notesNode.append(child: noteNode)
        tonesNode.append(child: toneNode)
        octaveNode.append(child: octaveNode(fromPitch: note.firstPitch, noteNode.children[0].clone))
        updateChord()
        scoreNoder?.insert([.init(value: note, index: unupdateModel.notes.count - 1)], with: model)
    }
    func insert(_ note: Note, at noteI: Int) {
        unupdateModel.notes.insert(note, at: noteI)
        let (noteNode, toneNode) = noteNode(from: note)
        notesNode.insert(child: noteNode, at: noteI)
        tonesNode.insert(child: toneNode, at: noteI)
        octaveNode.append(child: octaveNode(fromPitch: note.firstPitch, noteNode.children[0].clone))
        updateChord()
        scoreNoder?.insert([.init(value: note, index: noteI)], with: model)
    }
    func insert(_ nivs: [IndexValue<Note>]) {
        unupdateModel.notes.insert(nivs)
        let vs = nivs.map { IndexValue(value: noteNode(from: $0.value), index: $0.index) }
        let noivs = vs.map { IndexValue(value: $0.value.node, index: $0.index) }
        let toivs = vs.map { IndexValue(value: $0.value.toneNode, index: $0.index) }
        notesNode.children.insert(noivs)
        tonesNode.children.insert(toivs)
        octaveNode.children.insert(noivs.enumerated().map { .init(value: octaveNode(fromPitch: nivs[$0.offset].value.firstPitch, $0.element.value.children[0].clone), index: $0.element.index) })
        updateChord()
        scoreNoder?.insert(nivs, with: model)
    }
    func replace(_ nivs: [IndexValue<Note>]) {
        unupdateModel.notes.replace(nivs)
        let vs = nivs.map { IndexValue(value: noteNode(from: $0.value), index: $0.index) }
        let noivs = vs.map { IndexValue(value: $0.value.node, index: $0.index) }
        let toivs = vs.map { IndexValue(value: $0.value.toneNode, index: $0.index) }
        notesNode.children.replace(noivs)
        tonesNode.children.replace(toivs)
        octaveNode.children.replace(noivs.enumerated().map { .init(value: octaveNode(fromPitch: nivs[$0.offset].value.firstPitch, $0.element.value.children[0].clone), index: $0.element.index) })
        updateChord()
        scoreNoder?.replace(nivs, with: model)
    }
    func setIsShownTones(_ isivs: [IndexValue<Bool>]) {
        isivs.forEach {
            unupdateModel.notes[$0.index].isShownTone = $0.value
        }
        isivs.forEach {
            if $0.index < tonesNode.children.count {
                tonesNode.children[$0.index].isHidden = !$0.value
            }
        }
    }
    func replace(_ eivs: [IndexValue<Envelope>]) {
        let nivs = eivs.map {
            var note = unupdateModel.notes[$0.index]
            note.envelope = $0.value
            return IndexValue(value: note, index: $0.index)
        }
        unupdateModel.notes.replace(nivs)
        let vs = nivs.map { IndexValue(value: noteNode(from: $0.value), index: $0.index) }
        let noivs = vs.map { IndexValue(value: $0.value.node, index: $0.index) }
        let toivs = vs.map { IndexValue(value: $0.value.toneNode, index: $0.index) }
        notesNode.children.replace(noivs)
        tonesNode.children.replace(toivs)
        octaveNode.children.replace(noivs.enumerated().map { .init(value: octaveNode(fromPitch: nivs[$0.offset].value.firstPitch, $0.element.value.children[0].clone), index: $0.element.index) })
        
        scoreNoder?.replace(eivs)
    }
    func remove(at noteI: Int) {
        unupdateModel.notes.remove(at: noteI)
        notesNode.remove(atChild: noteI)
        tonesNode.remove(atChild: noteI)
        octaveNode.remove(atChild: noteI)
        updateChord()
        scoreNoder?.remove(at: [noteI])
    }
    func remove(at noteIs: [Int]) {
        unupdateModel.notes.remove(at: noteIs)
        noteIs.reversed().forEach { notesNode.remove(atChild: $0) }
        noteIs.reversed().forEach { tonesNode.remove(atChild: $0) }
        noteIs.reversed().forEach { octaveNode.remove(atChild: $0) }
        updateChord()
        scoreNoder?.remove(at: noteIs)
    }
    subscript(noteI: Int) -> Note {
        get {
            unupdateModel.notes[noteI]
        }
        set {
            unupdateModel.notes[noteI] = newValue
            let (noteNode, toneNode) = noteNode(from: newValue)
            notesNode.children[noteI] = noteNode
            tonesNode.children[noteI] = toneNode
            octaveNode.children[noteI] = octaveNode(fromPitch: newValue.firstPitch, noteNode.children[0].clone)
            updateChord()
            scoreNoder?.replace([.init(value: newValue, index: noteI)], with: model)
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
        let deltaPitch = Rational(1, 6)
        let pitchR1 = Rational(1)
        var cPitch = roundedSPitch
        while cPitch <= pitchRange.end {
            if cPitch >= pitchRange.start {
                let plw: Double = if cPitch % pitchR1 == 0 {
                    0.25
                } else {
                    0.125
                }
                let py = self.y(fromPitch: cPitch)
                let rect = Rect(x: sx, y: py - plw / 2, width: ex - sx, height: plw)
                if plw == 0.125 {
                    fullEditBorderPathlines.append(Pathline(rect))
                } else {
                    borderPathlines.append(Pathline(rect))
                }
            }
            cPitch += deltaPitch
        }
        
        for keyBeat in score.keyBeats {
            let nx = x(atBeat: keyBeat)
            let lw = 1.0
            subBorderPathlines.append(.init(Rect(x: nx - lw / 2, y: sy,
                                                 width: lw, height: ey - sy)))
            contentPathlines.append(.init(Rect(x: nx - knobW / 2, y: y - knobH / 2,
                                               width: knobW, height: knobH)))
        }
        contentPathlines.append(.init(Rect(x: ex - knobW / 2, y: y - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: sx, y: y - lw / 2,
                                           width: ex - sx, height: lw)))
        
        let secRange = score.secRange
        for sec in Int(secRange.start.rounded(.up)) ..< Int(secRange.end.rounded(.up)) {
            let sec = Rational(sec)
            guard secRange.contains(sec) else { continue }
            let secX = x(atSec: sec)
            contentPathlines.append(.init(Rect(x: secX - lw / 2, y: sy - rulerH / 2,
                                               width: lw, height: rulerH)))
        }
        
        let sprH = ContentLayout.isShownSpectrogramHeight
        let sprKnobW = knobH, sprKbobH = knobW
        let np = Point(ContentLayout.spectrogramX + sx, ey)
        contentPathlines.append(Pathline(Rect(x: np.x - 1 / 2,
                                              y: np.y,
                                              width: 1,
                                              height: sprH)))
        if score.isShownSpectrogram {
            contentPathlines.append(Pathline(Rect(x: np.x - sprKnobW / 2,
                                                  y: np.y + sprH - sprKbobH / 2,
                                                  width: sprKnobW,
                                                  height: sprKbobH)))
        } else {
            contentPathlines.append(Pathline(Rect(x: np.x - sprKnobW / 2,
                                                  y: np.y - sprKbobH / 2,
                                                  width: sprKnobW,
                                                  height: sprKbobH)))
        }
        
        return (contentPathlines, subBorderPathlines, borderPathlines, fullEditBorderPathlines)
    }
    
    func chordPathlines() -> [Pathline] {
        let score = model
        let pitchRange = Score.pitchRange
        let sBeat = max(score.beatRange.start, -10000), eBeat = min(score.beatRange.end, 10000)
        let sx = self.x(atBeat: sBeat)
        let ex = self.x(atBeat: eBeat)
        
        var subBorderPathlines = [Pathline]()
        
        let notes = score.notes + score.draftNotes
        if let range = Range<Int>(pitchRange) {
            let plw = 0.5
            let unisonsSet = Set(notes.flatMap { $0.chordBeatRangeAndRoundedPitchs().map { $0.roundedPitch.mod(12) } })
            for pitch in range {
                guard unisonsSet.contains(pitch.mod(12)) else { continue }
                let py = self.y(fromPitch: Rational(pitch))
                subBorderPathlines.append(Pathline(Rect(x: sx, y: py - plw / 2,
                                                        width: ex - sx, height: plw)))
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
        let plw = 1.0
        subBorderPathlines += chordBeats.map {
            Pathline(Rect(x: x(atBeat: $0) - plw / 2, y: sy, width: plw, height: ey - sy))
        }
        
        let trs = chordRanges.map { ($0, score.chordPitches(atBeat: $0)) }
        for (tr, pitchs) in trs {
            let pitchs = pitchs.sorted()
            guard let chord = Chord(pitchs: pitchs) else { continue }
            
            let nsx = x(atBeat: tr.start), nex = x(atBeat: tr.end)
            let maxTyperCount = min(chord.typers.count, Int((nex - nsx) / 5))
            let d = 1.5, maxW = 6.0, nw = maxW * Double(maxTyperCount - 1)
            let centerX = nsx.mid(nex)
            
            let typers = chord.typers.sorted(by: { $0.type.rawValue > $1.type.rawValue })[..<maxTyperCount]
            
            if let range = Range<Int>(pitchRange) {
                let ilw = 1.0
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
                            let fx = centerX - nw / 2 + maxW * Double(ti)
                            func append(count: Int, lineWidth lw: Double) {
                                let allLw = lw * Double(count * 2 - 1)
                                for i in 0 ..< count {
                                    let nd = Double(i) * 2 * lw
                                    subBorderPathlines.append(.init(Rect(x: fx - allLw / 2 + nd, y: py - d,
                                                                         width: lw, height: d * 2)))
                                }
                                subBorderPathlines.append(.init(Rect(x: fx - allLw / 2, y: py - d - tlw,
                                                                     width: allLw, height: tlw)))
                                subBorderPathlines.append(.init(Rect(x: fx - allLw / 2, y: py + d,
                                                                     width: allLw, height: tlw)))
                                if isInversion {
                                    let ilw = 0.75
                                    subBorderPathlines.append(.init(Rect(x: fx - allLw / 2 - ilw, y: py - d - ilw,
                                                                         width: allLw + 2 * ilw, height: ilw)))
                                    subBorderPathlines.append(.init(Rect(x: fx - allLw / 2 - ilw, y: py + d,
                                                                         width: allLw + 2 * ilw, height: ilw)))
                                }
                            }
                            
                            switch typer.type {
                            case .power: append(count: 2, lineWidth: tlw * 2)
                            case .major: append(count: 1, lineWidth: tlw * 2)
                            case .suspended: append(count: 3, lineWidth: tlw * 2)
                            case .minor: append(count: 1, lineWidth: tlw)
                            case .augmented: append(count: 2, lineWidth: tlw)
                            case .flatfive: append(count: 3, lineWidth: tlw)
                            case .diminish: append(count: 4, lineWidth: tlw)
                            case .tritone: append(count: 4, lineWidth: tlw)
                            }
                        }
                    }
                }
            }
        }
        
        return subBorderPathlines
    }
    
    func octaveNode(fromPitch pitch: Rational, noteIs: [Int], _ color: Color = .border) -> Node {
        let node = Node(children: noteIs.map { notesNode.children[$0].children[0].clone })
        node.children.forEach { $0.fillType = .color(color) }
        return octaveNode(fromPitch: pitch, node, color)
    }
    func octaveNode(fromPitch pitch: Rational, _ noteNode: Node, _ color: Color = .border) -> Node {
        let pitchRange = Score.pitchRange
        guard pitchRange.contains(pitch) else { return .init() }
        
        noteNode.fillType = .color(color)
        
        let pd = 12 * pitchHeight
        var nodes = [Node](), nPitch = pitch, npd = 0.0
        while true {
            nPitch -= 12
            npd -= pd
            guard pitchRange.contains(nPitch) else { break }
            let node = noteNode.clone
            node.attitude.position.y = npd
            nodes.append(node)
        }
        nPitch = pitch
        npd = 0.0
        while true {
            nPitch += 12
            npd += pd
            guard pitchRange.contains(nPitch) else { break }
            let node = noteNode.clone
            node.attitude.position.y = npd
            nodes.append(node)
        }
        return Node(children: nodes)
    }
    
    func draftNoteNode(from note: Note) -> Node {
        let noteNode = noteNode(from: note).node
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
    
    func noteNode(from note: Note, color: Color? = nil, lineWidth: Double? = nil) -> (node: Node, toneNode: Node) {
        guard note.beatRange.length > 0 else {
            return (.init(children: [.init(path: Path(Rect(.init(x(atBeat: note.beatRange.start),
                                                                y(fromPitch: note.pitch)),
                                                          distance: 1)),
                                           fillType: .color(color != nil ? color! : .content))]),
                    .init())
        }
        let nh = noteH(from: note)
        let halfNH = nh / 2
        let nx = x(atBeat: note.beatRange.start)
        let ny = y(fromPitch: note.firstPitch)
        let nw = width(atDurBeat: max(note.beatRange.length, Sheet.fullEditBeatInterval))
        let attackW = width(atDurSec: note.envelope.attackSec)
        let decayW = width(atDurSec: note.envelope.decaySec)
        let releaseW = width(atDurSec: note.envelope.releaseSec)
        let ax = nx + attackW, dx = nx + attackW + decayW, rx = nx + nw + releaseW
        
        let overtoneHalfH = 0.125
        let evenY = ScoreLayout.evenY, oddY = ScoreLayout.oddY, spectlopeH = ScoreLayout.spectlopeHeight
        let toneY = toneY(at: .init(), from: note)
        
        var linePath, mainLinePath, evenLinePath, oddLinePath: Path, mainEvenLinePath: Path?,
            lyricLinePathlines = [Pathline]()
        var spectlopePathline: Pathline?
        var scNodes = [Node]()
        let knobR = 0.5, envelopeR = 0.125, toneR = 0.125, sprolR = 0.125, sprolSubR = 0.0625
        
        let lyricNodes: [Node] = note.pits.enumerated().compactMap { (pitI, pit) in
            let p = pitPosition(atPit: pitI, from: note)
            if !pit.lyric.isEmpty {
                if pit.lyric == "[" {
                    lyricLinePathlines.append(.init(Rect(x: p.x - 0.25, y: p.y - 3,
                                                         width: 0.5, height: 3)))
                    return nil
                } else {
                    let lyricText = Text(string: pit.lyric, size: 6)
                    let typesetter = lyricText.typesetter
                    let lh = typesetter.height / 2 + 16
                    lyricLinePathlines.append(.init(Rect(x: p.x - 0.25, y: p.y - lh / 2,
                                                         width: 0.5, height: lh / 2)))
                    return .init(attitude: .init(position: .init(p.x - typesetter.width / 2,
                                                                 p.y - lh / 2 - typesetter.height / 2)),
                                 path: typesetter.path(), fillType: .color(color ?? .content))
                }
            } else {
                return nil
            }
        }
        
        func tonePitchY(fromPitch pitch: Double) -> Double {
            pitch.clipped(min: Score.doubleMinPitch, max: Score.doubleMaxPitch,
                          newMin: 0, newMax: spectlopeH) + toneY + ScoreLayout.spectlopeY
        }
        
        struct LinePoint {
            var x, y, h: Double, color: Color
            
            init(_ x: Double, _ y: Double, _ h: Double, _ color: Color) {
                self.x = x
                self.y = y
                self.h = h
                self.color = color
            }
            
            var point: Point {
                .init(x, y)
            }
        }
        func triangleStrip(_ wps: [LinePoint]) -> TriangleStrip {
            var ps = [Point](capacity: wps.count * 4)
            guard wps.count >= 2 else {
                return .init(points: wps.isEmpty ? [] : [wps[0].point])
            }
            for (i, wp) in wps.enumerated() {
                if i == 0 || i == wps.count - 1 {
                    if wp.h == 0 {
                        ps.append(.init(wp.x, wp.y))
                    } else if i == 0 {
                        let angle = Edge(wps[0].point, wps[1].point).angle()
                        let p = PolarPoint(wp.h, angle + .pi / 2).rectangular
                        ps.append(wp.point + p)
                        ps.append(wp.point - p)
                    } else {
                        let angle = Edge(wps[i - 1].point, wps[i].point).angle()
                        let p = PolarPoint(wp.h, angle + .pi / 2).rectangular
                        ps.append(wp.point + p)
                        ps.append(wp.point - p)
                    }
                } else {
                    let angle0 = Edge(wps[i - 1].point, wps[i].point).angle()
                    let angle1 = Edge(wps[i].point, wps[i + 1].point).angle()
                    let p0 = PolarPoint(wp.h, angle0 + .pi / 2).rectangular
                    ps.append(wp.point + p0)
                    ps.append(wp.point - p0)
                    let p1 = PolarPoint(wp.h, angle1 + .pi / 2).rectangular
                    ps.append(wp.point + p1)
                    ps.append(wp.point - p1)
                }
            }
            return .init(points: ps)
        }
        func colors(_ wps: [LinePoint]) -> [Color] {
            var colors = [Color](capacity: wps.count * 4)
            guard wps.count >= 2 else {
                return wps.isEmpty ? [] : [wps[0].color]
            }
            for (i, wp) in wps.enumerated() {
                if i == 0 || i == wps.count - 1 {
                    if wp.h == 0 {
                        colors.append(wp.color)
                    } else {
                        colors.append(wp.color)
                        colors.append(wp.color)
                    }
                } else {
                    colors.append(wp.color)
                    colors.append(wp.color)
                    colors.append(wp.color)
                    colors.append(wp.color)
                }
            }
            return colors
        }

        let isEven = !note.isOneOvertone && note.containsNoOneEven
        let mainLineHalfH = noteMainH(from: note) / 2
        let mainEvenLineHalfH = mainLineHalfH * 0.375
        let mainEvenLineColors, lineColors, evenColors, oddColors: [Color], lastP: Point,
            knobPRCs: [(p: Point, r: Double, color: Color)],
            toneKnobPRCs: [(p: Point, r: Double, color: Color)]
        if note.pits.count >= 2 {
            var beat = note.beatRange.start
            var ps = [LinePoint](), eps = [LinePoint](), ops = [LinePoint](),
                mps = [LinePoint](), meps = [LinePoint]()
            ps.append(.init(nx, ny, halfNH, Self.color(from: note.firstStereo)))
            mps.append(.init(nx, ny, mainLineHalfH, .content))
            if isEven {
                meps.append(.init(nx, ny, mainEvenLineHalfH, Self.color(fromVolm: note.firstTone.overtone.evenVolm)))
            }
            eps.append(.init(nx, self.toneY(at: .init(nx, ny), from: note) + evenY, overtoneHalfH,
                             Self.color(fromVolm: note.firstTone.overtone.evenVolm)))
            ops.append(.init(nx, self.toneY(at: .init(nx, ny), from: note) + oddY, overtoneHalfH,
                             Self.color(fromVolm: note.firstTone.overtone.oddVolm)))
            beat += .init(1, 48)
            while beat <= note.beatRange.end {
                let noteX = x(atBeat: beat), noteY = noteY(atBeat: beat, from: note)
                let result = note.pitResult(atBeat: .init(beat - note.beatRange.start))
                ps.append(.init(noteX, noteY, halfNH, Self.color(from: result.stereo)))
                mps.append(.init(noteX, noteY, mainLineHalfH, .content))
                if isEven {
                    meps.append(.init(noteX, noteY, mainEvenLineHalfH, Self.color(fromVolm: result.tone.overtone.evenVolm)))
                }
                eps.append(.init(noteX, self.toneY(at: .init(noteX, noteY), from: note) + evenY, overtoneHalfH,
                                 Self.color(fromVolm: result.tone.overtone.evenVolm)))
                ops.append(.init(noteX, self.toneY(at: .init(noteX, noteY), from: note) + oddY, overtoneHalfH,
                                 Self.color(fromVolm: result.tone.overtone.oddVolm)))
                beat += .init(1, 48)
            }
            if beat < note.beatRange.end {
                let lastPit = note.pits.last!
                let lastTone = lastPit.tone
                ps.append(.init(nx + nw, noteY(atBeat: note.beatRange.end, from: note), 0,
                                Self.color(from: lastPit.stereo)))
                eps.append(.init(nx + nw, self.toneY(at: ps.last!.point, from: note), 0,
                                 Self.color(fromVolm: lastTone.overtone.evenVolm)))
                ops.append(.init(nx + nw, self.toneY(at: ps.last!.point, from: note), 0,
                                 Self.color(fromVolm: lastTone.overtone.oddVolm)))
                mps.append(.init(nx + nw, noteY(atBeat: note.beatRange.end, from: note), mainLineHalfH,
                                 .content))
                if isEven {
                    meps.append(.init(nx + nw, noteY(atBeat: note.beatRange.end, from: note), mainEvenLineHalfH,
                                      Self.color(fromVolm: lastTone.overtone.evenVolm)))
                }
            }
            mps.append(.init(nx + nw, noteY(atBeat: note.beatRange.end, from: note), mainLineHalfH / 4,
                             .content))
            if isEven {
                meps.append(.init(nx + nw, noteY(atBeat: note.beatRange.end, from: note), mainEvenLineHalfH / 4,
                                  meps.last!.color))
            }
            
            ps.append(.init(nx + nw + releaseW, noteY(atBeat: note.beatRange.end, from: note), 0,
                            ps.last!.color))
            mps.append(.init(nx + nw + releaseW, noteY(atBeat: note.beatRange.end, from: note), mainLineHalfH / 4,
                             .content))
            if isEven {
                meps.append(.init(nx + nw + releaseW, noteY(atBeat: note.beatRange.end, from: note), mainEvenLineHalfH / 4,
                                  meps.last!.color))
            }
            
            var preI = 0
            if ax - ps[0].x > 0 {
                for i in 1 ..< ps.count {
                    let preP = ps[i - 1], p = ps[i]
                    if ax >= preP.x && ax < p.x {
                        for j in i.range {
                            ps[j].h *= (ps[j].x - ps[0].x) / (ax - ps[0].x)
                        }
                        let t = ax.clipped(min: preP.x, max: p.x, newMin: 0, newMax: 1)
                        ps.insert(.init(ax,
                                        .linear(preP.y, p.y, t: t),
                                        .linear(preP.h, p.h, t: t),
                                        .rgbLinear(preP.color, p.color, t: t)), at: i)
                        preI = i
                        break
                    }
                }
            }
            let susVolm = note.envelope.sustainVolm
            if dx - ps[preI].x > 0 {
                for i in preI + 1 ..< ps.count {
                    let preP = ps[i - 1], p = ps[i]
                    if dx >= preP.x && dx < p.x {
                        for j in i.range {
                            ps[j].h *= ps[j].x.clipped(min: ps[preI].x, max: dx, newMin: 1, newMax: susVolm)
                        }
                        let t = dx.clipped(min: preP.x, max: p.x, newMin: 0, newMax: 1)
                        ps.insert(.init(dx,
                                        .linear(preP.y, p.y, t: t),
                                        .linear(preP.h, p.h, t: t),
                                        .rgbLinear(preP.color, p.color, t: t)), at: i)
                        preI = i
                        break
                    }
                }
            }
            for i in preI ..< ps.count {
                ps[i].h *= susVolm
            }
            
            let envelopeY = nh / 2 + ScoreLayout.envelopeY
            knobPRCs = note.pits.map { (.init(x(atBeat: note.beatRange.start + $0.beat),
                                              y(fromPitch: note.pitch + $0.pitch)),
                                        knobR, $0.tone.color) }
            let envelopeKnobPAndRs = [(Point(ax, noteY(atX: ax, from: note) + envelopeY), envelopeR, Color.background),
                                      (Point(dx, noteY(atX: dx, from: note) + envelopeY), envelopeR, Color.background),
                                      (Point(rx, noteY(atX: rx, from: note) + envelopeY), envelopeR, Color.background)]
            
            linePath = .init(triangleStrip(ps))
            lineColors = colors(ps)
            
            mainLinePath = .init(triangleStrip(mps))
            
            if isEven {
                mainEvenLinePath = .init(triangleStrip(meps))
                mainEvenLineColors = colors(meps)
            } else {
                mainEvenLineColors = []
            }
            
            evenLinePath = .init(triangleStrip(eps))
            evenColors = colors(eps)
            oddLinePath = .init(triangleStrip(ops))
            oddColors = colors(ops)
            
            let sprolKnobPAndRs: [(Point, Double, Color)] = note.pits.flatMap { pit in
                let p = Point(x(atBeat: note.beatRange.start + pit.beat),
                              y(fromPitch: note.pitch + pit.pitch))
                return pit.tone.spectlope.sprols.enumerated().map {
                    (Point(p.x, tonePitchY(fromPitch: $0.element.pitch)),
                     $0.offset > 0 && pit.tone.spectlope.sprols[$0.offset - 1].pitch > $0.element.pitch ? sprolSubR : sprolR,
                     $0.element.volm == 0 ? Color.subBorder : Color.background)
                }
            }
            
            toneKnobPRCs = envelopeKnobPAndRs + sprolKnobPAndRs
            + knobPRCs.map { (Point($0.p.x, self.toneY(at: $0.p, from: note) + evenY), toneR, .background) }
            + knobPRCs.map { (Point($0.p.x, self.toneY(at: $0.p, from: note) + oddY), toneR, .background) }
            
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
                    let y = tonePitchY(fromPitch: sprol.pitch)
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
            
            var nBeat = note.beatRange.start, vs = [[PAndColor]](), fqLinePs = [Point]()
            var lastV: [PAndColor]?, lastFqLineP: Point?, isLastAppned = false
            while nBeat <= note.beatRange.end {
                let x = self.x(atBeat: nBeat)
                let sprols = pitbend.spectlope(atSec: Double(sec(fromBeat: nBeat - note.beatRange.start))).sprols
                let psPitch = pitch(atBeat: nBeat, from: note)
                let noteY = y(fromPitch: psPitch)
                let v = pAndColors(x: x, pitch: psPitch, noteY: noteY, sprols: sprols)
                let fqLineP = Point(x, tonePitchY(fromPitch: psPitch))
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
                nBeat += .init(1, 48)
            }
            if !isLastAppned, let v = lastV, let fqLineP = lastFqLineP {
                vs.append(v)
                fqLinePs.append(fqLineP)
            }
            
            if !vs.isEmpty && vs[0].count >= 2 {
                let preY = tonePitchY(fromPitch: 0)
                scNodes.append(.init(path: Path(Rect(x: nx, y: preY - ScoreLayout.spectlopeY,
                                                     width: nw, height: spectlopeH + ScoreLayout.spectlopeY)),
                                     fillType: .color(.background)))
                
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
                    
                    scNodes.append(.init(path: Path(tst), fillType: .maxGradient(colors)))
                }
            }
            
            lastP = .init(ps.last!.point)
            
            spectlopePathline = .init(fqLinePs)
        } else {
            let sustainHalfH = halfNH * note.envelope.sustainVolm
            let color = Self.color(from: note.pits[0].stereo)
            linePath = .init(triangleStrip([.init(nx, ny, 0, color),
                                            .init(ax, ny, halfNH, color),
                                            .init(dx, ny, sustainHalfH, color),
                                            .init(nx + nw, ny, sustainHalfH, color),
                                            .init(rx, ny, 0, color)]))
            lineColors = [color]
            
            mainLinePath = .init(triangleStrip([.init(nx, ny, mainLineHalfH, .content),
                                                .init(nx + nw, ny, mainLineHalfH, .content),
                                                .init(nx + nw, ny, mainLineHalfH / 4, .content),
                                                .init(rx, ny, mainLineHalfH / 4, .content)]))
            
            if isEven {
                let mainEvenLineColor = Self.color(fromVolm: note.firstTone.overtone.evenVolm)
                mainEvenLinePath = .init(triangleStrip([.init(nx, ny, mainEvenLineHalfH, mainEvenLineColor),
                                                        .init(nx + nw, ny, mainEvenLineHalfH, mainEvenLineColor),
                                                        .init(nx + nw, ny, mainEvenLineHalfH / 4, mainEvenLineColor),
                                                        .init(rx, ny, mainEvenLineHalfH / 4, mainEvenLineColor)]))
                mainEvenLineColors = [mainEvenLineColor]
            } else {
                mainEvenLineColors = []
            }
            
            lastP = .init(rx, ny)
            
            let envelopeY = ny + nh / 2 + ScoreLayout.envelopeY
            let envelopeKnobPRCs = [(Point(ax, envelopeY), envelopeR, Color.background),
                                      (Point(dx, envelopeY), envelopeR, Color.background),
                                      (Point(rx, envelopeY), envelopeR, Color.background)]
            knobPRCs = note.pits.map { (.init(x(atBeat: note.beatRange.start + $0.beat),
                                               y(fromPitch: note.pitch + $0.pitch)),
                                        knobR, note.firstTone.color) }
            
            evenLinePath = .init(Rect(x: nx, y: toneY + evenY - overtoneHalfH,
                                      width: nw, height: overtoneHalfH * 2))
            evenColors = [Self.color(fromVolm: note.firstTone.overtone.evenVolm)]
            
            oddLinePath = .init(Rect(x: nx, y: toneY + oddY - overtoneHalfH,
                                     width: nw, height: overtoneHalfH * 2))
            oddColors = [Self.color(fromVolm: note.firstTone.overtone.oddVolm)]
            
            let fPitNx = x(atBeat: note.beatRange.start + note.firstPit.beat)
            let sprolKnobPRCs = note.firstTone.spectlope.sprols.enumerated().map {
                (Point(fPitNx, tonePitchY(fromPitch: $0.element.pitch)),
                 $0.offset > 0 && note.firstTone.spectlope.sprols[$0.offset - 1].pitch > $0.element.pitch ? sprolSubR : sprolR,
                 $0.element.volm == 0 ? Color.subBorder : Color.background)
            }
            
            toneKnobPRCs = envelopeKnobPRCs + sprolKnobPRCs
            var preY = tonePitchY(fromPitch: 0)
            var preColor = Self.color(fromVolm: note.firstTone.spectlope.sprols.first?.volm ?? 0,
                                      noise: note.firstTone.spectlope.sprols.first?.noise ?? 0)
            scNodes.append(.init(path: Path(Rect(x: nx, y: preY - ScoreLayout.spectlopeY,
                                                 width: nw, height: spectlopeH + ScoreLayout.spectlopeY)),
                                 fillType: .color(.background)))
            func append(_ sprol: Sprol) {
                let y = tonePitchY(fromPitch: sprol.pitch)
                let color = Self.color(fromVolm: sprol.volm, noise: sprol.noise)
                
                let tst = TriangleStrip(points: [.init(nx, preY), .init(nx, y),
                                                 .init(nx + nw, preY), .init(nx + nw, y)])
                let colors = [preColor, color, preColor, color]
                
                scNodes.append(.init(path: Path(tst), fillType: .maxGradient(colors)))
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
            spectlopePathline = .init([Point(nx, fqY), Point(nx + nw, fqY)])
        }
        
        var nodes = [Node](), toneNodes = [Node]()
        
        let lineNode = Node(path: linePath,
                            fillType: color != nil ? .color(color!) : (lineColors.count == 1 ? .color(lineColors[0]) : .gradient(lineColors)))
        nodes.append(lineNode)
        
        let mainLineNode = Node(path: mainLinePath, fillType: .color(.content))
        nodes.append(mainLineNode)
        
        if let mainEvenLinePath {
            let mainEvenLineNode = Node(path: mainEvenLinePath,
                                        fillType: color != nil ? .color(color!) : (mainEvenLineColors.count == 1 ? .color(mainEvenLineColors[0]) : .gradient(mainEvenLineColors)))
            nodes.append(mainEvenLineNode)
        }
        
        toneNodes.append(.init(path: .init(Rect(x: nx, y: ny + ScoreLayout.toneColorY, width: nw, height: 3)), fillType: .color(.content)))
        
        toneNodes += scNodes
        toneNodes.append(.init(path: evenLinePath,
                               fillType: color != nil ? .color(color!) : (evenColors.count == 1 ? .color(evenColors[0]) : .gradient(evenColors))))
        toneNodes.append(.init(path: oddLinePath,
                               fillType: color != nil ? .color(color!) : (oddColors.count == 1 ? .color(oddColors[0]) : .gradient(oddColors))))
        if let spectlopePathline {
            toneNodes.append(.init(path: Path([spectlopePathline]),
                                   lineWidth: 0.125,
                                   lineType: .color(.content)))
        }
        
        nodes += lyricNodes
        nodes.append(.init(path: .init(lyricLinePathlines), fillType: .color(.content)))
        
        let knobPrcsDic = knobPRCs.reduce(into: [Color: [(p: Point, r: Double)]]()) {
            if $0[$1.color] == nil {
                $0[$1.color] = [($1.p, $1.r)]
            } else {
                $0[$1.color]?.append(($1.p, $1.r))
            }
        }
        for (color, prs) in knobPrcsDic {
            let backKnobPathlines = prs.map {
                Pathline(circleRadius: $0.r * 1.5, position: $0.p)
            }
            let knobPathlines = prs.map {
                Pathline(circleRadius: $0.r, position: $0.p)
            }
            nodes.append(.init(path: .init(backKnobPathlines), fillType: .color(.content)))
            nodes.append(.init(path: .init(knobPathlines), fillType: .color(color)))
        }
        
        toneNodes.append(.init(path: .init([lastP + Point(0, -halfNH), lastP + Point(0, halfNH)]),
                               lineWidth: mainLineHalfH / 4, lineType: .color(.content)))
        
        let toneBackKnobPathlines = toneKnobPRCs.map {
            Pathline(circleRadius: $0.r * 1.5, position: $0.p)
        }
        toneNodes.append(.init(path: .init(toneBackKnobPathlines), fillType: .color(.content)))
        
        let prsDic = toneKnobPRCs.reduce(into: [Color: [(p: Point, r: Double)]]()) {
            if $0[$1.color] == nil {
                $0[$1.color] = [($1.p, $1.r)]
            } else {
                $0[$1.color]?.append(($1.p, $1.r))
            }
        }
        for (color, prs) in prsDic {
            let toneKnobPathlines = prs.map {
                Pathline(circleRadius: $0.r, position: $0.p)
            }
            toneNodes.append(.init(path: .init(toneKnobPathlines), fillType: .color(color)))
        }
        
        let boundingBox = nodes.reduce(into: Rect?.none) { $0 += $1.drawableBounds }
        let toneBoundingBox = toneNodes.reduce(into: Rect?.none) { $0 += $1.drawableBounds }
        return (Node(children: nodes,
                    path: boundingBox != nil ? Path(boundingBox!) : .init(Rect(origin: .init(nx, ny)))),
                Node(children: toneNodes, isHidden: !note.isShownTone,
                     path: toneBoundingBox != nil ? Path(toneBoundingBox!) : .init(Rect(origin: .init(nx, ny)))))
    }
    
    func pointline(from note: Note) -> Pointline {
        if note.pits.count == 1 {
            let noteSX = x(atBeat: note.beatRange.start)
            let noteEX = x(atBeat: note.beatRange.end)
            let noteY = noteY(atBeat: note.beatRange.start, from: note)
            return .init(controls: [.init(point: .init(noteSX, noteY)),
                                    .init(point: .init(noteEX, noteY))])
        } else {
            var beat = note.beatRange.start, ps = [Point]()
            while beat <= note.beatRange.end {
                let noteX = x(atBeat: beat), noteY = noteY(atBeat: beat, from: note)
                ps.append(Point(noteX, noteY))
                beat += .init(1, 48)
            }
            return .init(controls: ps.map { .init(point: $0) })
        }
    }
    func lineColors(from note: Note) -> [Color] {
        if note.pits.count == 1 {
            let color = Self.color(from: note.pits[0].stereo)
            return [color, color]
        } else {
            var beat = note.beatRange.start, colors = [Color]()
            while beat <= note.beatRange.end {
                let stereo = stereo(atBeat: beat, from: note)
                colors.append(Self.color(from: stereo))
                beat += .init(1, 48)
            }
            return colors
        }
    }
    
    static func lightness(fromVolm volm: Double) -> Double {
        volm.clipped(min: Volm.minVolm, max: Volm.maxVolm,
                     newMin: 100, newMax: Color.content.lightness)
    }
    static func color(fromVolm volm: Double) -> Color {
        Color(lightness: lightness(fromVolm: volm))
    }
    static func color(fromVolm volm: Double, noise: Double) -> Color {
        color(fromLightness: lightness(fromVolm: volm * 0.75), noise: noise)
    }
    static func color(fromLightness l: Double, noise: Double) -> Color {
        let br = Double(Color(lightness: l).rgba.r)
        return if noise == 0 {
            Color(red: br, green: br, blue: br)
        } else {
            Color(red: br, green: br, blue: noise * Spectrogram.editRedRatio * (1 - br) + br)
        }
    }
    static func color(from stereo: Stereo) -> Color {
        color(fromPan: stereo.pan, volm: stereo.volm)
    }
    static func color(fromPan pan: Double, volm: Double) -> Color {
        let volm = Spectrogram.mainVolm(fromVolum: volm, splitVolm: 0.5, midVolm: 0.9)
        let l = Double(Color(lightness: lightness(fromVolm: volm)).rgba.r)
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
        let ny = noteY(atX: nx, from: note) + noteH(atX: nx, from: note) / 2 + ScoreLayout.envelopeY
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
    
    func containsMainFrame(_ p: Point) -> Bool {
        model.enabled ? mainFrame.contains(p) : false
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
        let hnh = pitchHeight / 2
        var minDS = Double.infinity, minI: Int?
        for (noteI, note) in model.notes.enumerated() {
            let maxD = Sheet.knobEditDistance * scale + noteH(from: note) / 2
            let maxDS = maxD * maxD
            let nf = noteFrame(at: noteI).outset(by: hnh)
            let ods = nf.distanceSquared(p)
            if ods < maxDS {
                let ds = pointline(from: note).minDistanceSquared(at: p)
                if ds < minDS && ds < maxDS {
                    minDS = ds
                    minI = noteI
                }
            }
            if note.isShownTone {
                let ds = toneFrame(from: note).distanceSquared(p)
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
    
    enum ControlHitResult {
        case attack
        case decay
        case release
        case sprol(pitI: Int, sprolI: Int)
    }
    func hitTestControl(_ p: Point, scale: Double, at noteI: Int) -> ControlHitResult? {
        var minResult: ControlHitResult?
        
        let maxD = Sheet.knobEditDistance * scale
        let maxDS = maxD * maxD
        let score = model
        let note = score.notes[noteI]
        
        var minDS = Double.infinity
        if note.isShownTone {
            let attackBeat = Double(note.beatRange.start) + score.beat(fromSec: note.envelope.attackSec)
            let ax = x(atBeat: attackBeat)
            let ap = Point(ax, noteY(atX: ax, at: noteI) + noteH(atX: ax, at: noteI) / 2 + ScoreLayout.envelopeY)
            
            let decayBeat = Double(note.beatRange.start) + score.beat(fromSec: note.envelope.attackSec + note.envelope.decaySec)
            let dx = x(atBeat: decayBeat)
            let dp = Point(dx, noteY(atX: dx, at: noteI) + noteH(atX: dx, at: noteI) / 2 + ScoreLayout.envelopeY)
            
            let dsa = ap.distanceSquared(p)
            if dsa < minDS && dsa < maxDS && (ax == dx ? p.x < ax : true) {
                minDS = dsa
                minResult = .attack
            }
            
            let dsd = dp.distanceSquared(p)
            if dsd < minDS && dsd < maxDS && (ax == dx ? p.x > ax : true) {
                minDS = dsd
                minResult = .decay
            }
            
            let releaseBeat = Double(note.beatRange.end) + score.beat(fromSec: note.envelope.releaseSec)
            let rx = x(atBeat: releaseBeat)
            let rp = Point(rx, noteY(atX: rx, at: noteI) + noteH(atX: rx, at: noteI) / 2 + ScoreLayout.envelopeY)
            
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
        }
        
        return minResult
    }
    
    enum ColorHitResult {
        case note
        case pit(pitI: Int)
        case sustain
        case evenVolm(pitI: Int)
        case oddVolm(pitI: Int)
        case sprol(pitI: Int, sprolI: Int)
        
        var isTone: Bool {
            switch self {
            case .evenVolm, .oddVolm, .sprol: true
            default: false
            }
        }
        var isEnvelpse: Bool {
            switch self {
            case .sustain: true
            default: false
            }
        }
    }
    func hitTestColor(_ p: Point, scale: Double) -> (noteI: Int, result: ColorHitResult)? {
        var minNoteI: Int?, minResult: ColorHitResult?
        
        let maxD = Sheet.knobEditDistance * scale
        let maxDS = maxD * maxD
        var minDS = Double.infinity
        
        let score = model
        for (noteI, note) in score.notes.enumerated() {
            guard note.isShownTone else { continue }
            if note.pits.count == 1 {
                let pitP = Point(x(atBeat: note.beatRange.start), y(fromPitch: note.firstPitch))
                
                let evenY = toneY(at: pitP, from: note) + ScoreLayout.evenY
                var ds = p.y.distanceSquared(evenY)
                if p.x >= pitP.x - maxD && p.x < x(atBeat: note.beatRange.end) + maxD
                    && ds < minDS && ds < maxDS {
                    
                    minDS = ds
                    minNoteI = noteI
                    minResult = .evenVolm(pitI: 0)
                }
                
                let oddY = toneY(at: pitP, from: note) + ScoreLayout.oddY
                ds = p.y.distanceSquared(oddY)
                if p.x >= pitP.x - maxD && p.x < x(atBeat: note.beatRange.end) + maxD
                    && ds < minDS && ds < maxDS {
                    
                    minDS = ds
                    minNoteI = noteI
                    minResult = .oddVolm(pitI: 0)
                }
            } else {
                let noteH = noteH(from: note)
                for pitI in note.pits.count.range {
                    let minODS = p.y - noteY(atX: p.x, at: noteI)
                    if minODS > noteH / 2 {
                        let pitP = pitPosition(atPit: pitI, from: note)
                        
                        let evenP = Point(pitP.x, toneY(at: pitP, from: note) + ScoreLayout.evenY)
                        let evenDsd = evenP.distanceSquared(p)
                        if evenDsd < minDS && evenDsd < maxDS {
                            minDS = evenDsd
                            minNoteI = noteI
                            minResult = .evenVolm(pitI: pitI)
                        }
                        
                        let oddP = Point(pitP.x, toneY(at: pitP, from: note) + ScoreLayout.oddY)
                        let oddDsd = oddP.distanceSquared(p)
                        if oddDsd < minDS && oddDsd < maxDS {
                            minDS = oddDsd
                            minNoteI = noteI
                            minResult = .oddVolm(pitI: pitI)
                        }
                    }
                }
            }
            
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
            }
            
            let decayBeat = Double(note.beatRange.start) + score.beat(fromSec: note.envelope.attackSec + note.envelope.decaySec)
            let dx = x(atBeat: decayBeat)
            let dp = Point(dx, noteY(atX: dx, at: noteI) + noteH(atX: dx, at: noteI) / 2 + ScoreLayout.envelopeY)
            let dsd = dp.distanceSquared(p)
            if dsd < minDS && dsd < maxDS {
                minDS = dsd
                minNoteI = noteI
                minResult = .sustain
            }
        }
        
        return if let minNoteI, let minResult {
            (minNoteI, minResult)
        } else if let (noteI, pitI) = noteAndPitI(at: p, scale: scale) {
            (noteI, .pit(pitI: pitI))
        } else if let noteI = noteIndex(at: p, scale: scale) {
            (noteI, .note)
        } else {
            nil
        }
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
        notesNode.children[noteI].path.bounds ?? .init()
    }
    func draftNoteFrame(at noteI: Int) -> Rect {
        draftNotesNode.children[noteI].path.bounds ?? .init()
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
        noteH(from: model.notes[noteI])
    }
    func noteH(atX x: Double, from note: Note) -> Double {
        noteH(from: note)
    }
    func noteH(at noteI: Int) -> Double {
        noteH(from: model.notes[noteI])
    }
    func noteH(from note: Note) -> Double {
        note.isOneOvertone ? 1.25 : (note.isFullNoise ? 2.5 : ScoreLayout.noteHeight)
    }
    func noteMainH(from note: Note) -> Double {
        note.isOneOvertone ? 0.125 : (note.isFullNoise ? 1 : 0.5)
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
    func toneY(at p: Point, from note: Note) -> Double {
        y(fromPitch: (note.pits.maxValue { $0.pitch } ?? 0) + note.pitch) + ScoreLayout.tonePadding
    }
    func toneY(at p: Point, at noteI: Int) -> Double {
        toneY(at: p, from: model.notes[noteI])
    }
    func toneFrame(at noteI: Int) -> Rect {
        toneFrame(from: model.notes[noteI])
    }
    func toneFrame(from note: Note) -> Rect {
        let toneY = toneY(at: .init(), from: note)
        let nx = x(atBeat: note.beatRange.start)
        let nw = width(atDurBeat: max(note.beatRange.length, Sheet.fullEditBeatInterval))
        return .init(x: nx, y: toneY,
                     width: nw, height: ScoreLayout.spectlopeHeight + ScoreLayout.spectlopeY)
    }
    func pitIAndSprolI(at p: Point, at noteI: Int) -> (pitI: Int, sprolI: Int)? {
        guard p.y > toneY(at: p, at: noteI) + ScoreLayout.spectlopeY else { return nil }
        
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
        let sprol = note.pits[pitI].tone.spectlope.sprols[sprolI]
        let ny = sprol.pitch.clipped(min: Score.doubleMinPitch,
                                     max: Score.doubleMaxPitch,
                                     newMin: 0, newMax: ScoreLayout.spectlopeHeight)
        let pitP = pitPosition(atPit: pitI, from: note)
        return .init(pitP.x, ny + toneY(at: pitP, from: note) + ScoreLayout.spectlopeY)
    }
    func sprolPosition(atSprol sprolI: Int, atPit pitI: Int, at noteI: Int) -> Point {
        sprolPosition(atSprol: sprolI, atPit: pitI, from: model.notes[noteI])
    }
    func spectlopePitch(at p: Point, at noteI: Int) -> Double {
        let spectlopeY = toneY(at: p, at: noteI) + ScoreLayout.spectlopeY
        return p.y.clipped(min: spectlopeY, max: spectlopeY + ScoreLayout.spectlopeHeight,
                           newMin: Score.doubleMinPitch, newMax: Score.doubleMaxPitch)
    }
    func nearestSprol(at p: Point, at noteI: Int) -> Sprol {
        let note = model.notes[noteI]
        let spectlopeY = toneY(at: p, from: note) + ScoreLayout.spectlopeY
        let tone = note.pitResult(atBeat: beat(atX: p.x) - .init(note.beatRange.start)).tone
        let pitch = p.y.clipped(min: spectlopeY, max: spectlopeY + ScoreLayout.spectlopeHeight,
                                newMin: Score.doubleMinPitch, newMax: Score.doubleMaxPitch)
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
    func insertablePitIndex(atBeat beat: Rational, at noteI: Int) -> Int {
        let note = model.notes[noteI]
        if beat < note.pits[0].beat {
            return 0
        }
        for i in 1 ..< note.pits.count {
            if note.pits[i - 1].beat <= beat && beat < note.pits[i].beat {
                return i
            }
        }
        return note.pits.count
    }
    func pitPosition(atPit pitI: Int, at noteI: Int) -> Point {
        pitPosition(atPit: pitI, from: model.notes[noteI])
    }
    func pitPosition(atPit pitI: Int, from note: Note) -> Point {
        .init(x(atBeat: note.beatRange.start + note.pits[pitI].beat),
              y(fromPitch: note.pitch + note.pits[pitI].pitch))
    }
    
    static var spectrogramHeight: Double {
        ScoreLayout.pitchHeight * (Score.doubleMaxPitch - Score.doubleMinPitch)
    }
    func updateSpectrogram() {
        spectrogramNode?.removeFromParent()
        spectrogramNode = nil
        
        let score = model
        guard score.isShownSpectrogram, let sm = score.spectrogram else { return }
        
        let firstX = x(atBeat: score.beatRange.start)
        let y = timeLineCenterY + Sheet.timelineHalfHeight + ContentLayout.isShownSpectrogramHeight + Sheet.knobWidth / 2
        let allBeat = score.beatRange.length
        let allW = width(atDurBeat: allBeat)
        var nodes = [Node](), maxH = 0.0
        func spNode(width: Int, at xi: Int) -> Node? {
            guard let image = sm.image(width: width, at: xi),
                  let texture = Texture(image: image,
                                        isOpaque: false,
                                        colorSpace: .sRGB) else { return nil }
            let w = allW * Double(width) / Double(sm.frames.count)
            let h = Self.spectrogramHeight
            maxH = max(maxH, h)
            let x = allW * Double(xi) / Double(sm.frames.count)
            return Node(name: "spectrogram",
                        attitude: .init(position: .init(x, 0)),
                        path: Path(Rect(width: w, height: h)),
                        fillType: .texture(texture))
        }
        (0 ..< (sm.frames.count / 1024)).forEach { xi in
            if let node = spNode(width: 1024,
                                 at: xi * 1024) {
                nodes.append(node)
            }
        }
        let lastCount = sm.frames.count % 1024
        if lastCount > 0 {
            let xi = sm.frames.count / 1024
            if let node = spNode(width: lastCount,
                                 at: xi * 1024) {
                nodes.append(node)
            }
        }
        
        let sNode = Node(name: "spectrogram",
                         children: nodes,
                         attitude: .init(position: .init(firstX, y)),
                         path: Path(Rect(width: allW, height: maxH)))
        
        self.spectrogramNode = sNode
        self.spectrogramFqType = sm.type
        
        node.insert(child: sNode, at: 5)
    }
    func spectrogramPitch(atY y: Double) -> Double? {
        guard let spectrogramNode, let spectrogramFqType else { return nil }
        let y = y - 0.5 * Self.spectrogramHeight / 1024
        let h = spectrogramNode.path.bounds?.height ?? 0
        switch spectrogramFqType {
        case .linear:
            let fq = y.clipped(min: 0, max: h,
                               newMin: Spectrogram.minLinearFq,
                               newMax: Spectrogram.maxLinearFq)
            return Pitch.pitch(fromFq: max(fq, 1))
        case .pitch:
            return y.clipped(min: 0, max: h,
                             newMin: Spectrogram.minPitch,
                             newMax: Spectrogram.maxPitch)
        }
    }
    
    func containsIsShownSpectrogram(_ p: Point, scale: Double) -> Bool {
        Rect(x: timelineFrame.minX + ContentLayout.spectrogramX - Sheet.knobHeight / 2,
                 y: timeLineCenterY + Sheet.timelineHalfHeight - Sheet.knobWidth / 2,
                 width: Sheet.knobHeight,
                 height: ContentLayout.isShownSpectrogramHeight + Sheet.knobWidth)
            .outset(by: scale * 3)
            .contains(p)
    }
    
    func isShownSpectrogram(at p :Point) -> Bool {
        p.y > timeLineCenterY + Sheet.timelineHalfHeight + ContentLayout.isShownSpectrogramHeight / 2
    }
    var isShownSpectrogram: Bool {
        get {
            model.isShownSpectrogram
        }
        set {
            let oldValue = model.isShownSpectrogram
            if newValue != oldValue {
                binder[keyPath: keyPath].isShownSpectrogram = newValue
                updateTimeline()
                updateSpectrogram()
            }
        }
    }
}
