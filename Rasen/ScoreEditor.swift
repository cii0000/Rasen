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

protocol TimelineView: View {
    func x(atSec sec: Rational) -> Double
    func x(atSec sec: Double) -> Double
    func x(atBeat beat: Rational) -> Double
    func width(atSecDuration sec: Rational) -> Double
    func width(atSecDuration sec: Double) -> Double
    func width(atBeatDuration beatDur: Rational) -> Double
    func sec(atX x: Double, interval: Rational) -> Rational
    func sec(atX x: Double) -> Rational
    func sec(atX x: Double) -> Double
    func beat(atX x: Double, interval: Rational) -> Rational
    func beat(atX x: Double) -> Rational
    var beatRange: Range<Rational>? { get }
    var localBeatRange: Range<Rational>? { get }
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
        case all, startBeat, endBeat,
             startNote, endNote, moveNote,
             attack, decayAndSustain, release,
             overtone, sourceFilter,
             tempo
    }
    
    private let editableInterval = 5.0
    private let editableTempoInterval = 10.0
    
    private var node = Node()
    private var notePlayer: NotePlayer?
    private var sheetView: SheetView?
    private var type = SlideType.all, sourceFilterType = SourceFilterType.fqSmp,
                overtoneType = OvertoneType.evenScale
    private var beganSP = Point(), beganTime = Rational(0), beganInP = Point()
    private var beganLocalStartPitch = Rational(0), secI = 0, noteI: Int?,
                beganBeatRange: Range<Rational>?,
                currentBeatNoteIndexes = [Int](),
                beganDeltaNoteBeat = Rational(),
                oldNotePitch: Rational?, oldNoteBeat: Rational?,
                minScorePitch = Rational(0), maxScorePitch = Rational(0)
    private var beganStartBeat = Rational(0), beganPitch: Rational?
    
    private var beganTone = Tone(), beganOvertone = Overtone(), beganEnvelope = Envelope()
    private var beganSourceFilterIndex = 0, beganSourceFilter = SourceFilter(),
                beganSourceFilterFq = 0.0, beganSourceFilterSmp = 0.0
    
    private var beganTempo: Rational = 1, oldTempo: Rational = 1
    private var beganAnimationOption: AnimationOption?, beganScoreOption: ScoreOption?,
                beganContents = [Int: Content](),
                beganTexts = [Int: Text]()
    
    private var beganNotes = [Int: Note]()
    
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
                
                let maxD = 15 * document.screenToWorldScale
                let maxMD = 10 * document.screenToWorldScale
                
                let scoreP = scoreView.convert(inP, from: sheetView.node)
                if let ni = scoreView.noteIndex(at: scoreP, maxDistance: maxD) {
                    let note = score.notes[ni]
                    if let sfi = scoreView.sourceFilterIndex(at: scoreP, at: ni) {
                        type = .sourceFilter
                        
                        beganTone = score.notes[ni].tone
                        self.beganSourceFilterIndex = sfi
                        self.beganSourceFilter = beganTone.sourceFilter
                        self.sourceFilterType = .fqSmp
                        let fqSmp = scoreView.sourceFilterFqAndSmp(at: scoreP, at: ni)
                        self.beganSourceFilterFq = fqSmp.x
                        self.beganSourceFilterSmp = fqSmp.y
                        noteI = ni
                        
                        if document.isSelect(at: p) {
                            let noteIs = document.selectedNoteIndexes(from: scoreView)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        } else {
                            let id = score.notes[ni].tone.id
                            beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                                if id == $1.element.tone.id {
                                    $0[$1.offset] = $1.element
                                }
                            }
                        }
                        beganNotes[ni] = score.notes[ni]
                        
                        currentBeatNoteIndexes = beganNotes.keys.sorted()
                            .filter { score.notes[$0].beatRange.contains(note.beatRange.center) }
                    } else if let (ni, aOvertoneType) = scoreView.overtoneType(at: scoreP, at: ni) {
                        type = .overtone
                        
                        beganTone = score.notes[ni].tone
                        beganOvertone = beganTone.overtone
                        overtoneType = aOvertoneType
                        
                        if document.isSelect(at: p) {
                            let noteIs = document.selectedNoteIndexes(from: scoreView)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        } else {
                            let id = score.notes[ni].tone.id
                            beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                                if id == $1.element.tone.id {
                                    $0[$1.offset] = $1.element
                                }
                            }
                        }
                        beganNotes[ni] = score.notes[ni]
                        
                        currentBeatNoteIndexes = beganNotes.keys.sorted()
                            .filter { score.notes[$0].beatRange.contains(note.beatRange.center) }
                    } else {
                        let pitch = document.pitch(from: scoreView, at: scoreP)
                        let nf = scoreView.noteFrame(from: note)
                        let nfsw = nf.width * document.worldToScreenScale
                        let dx = nfsw.clipped(min: 3, max: 30, newMin: 1, newMax: 10)
                        * document.screenToWorldScale
                        
                        type = if abs(scoreP.x - nf.minX) < dx {
                            .startNote
                        } else if abs(scoreP.x - nf.maxX) < dx {
                            .endNote
                        } else {
                            .moveNote
                        }
                        
                        let interval = document.currentNoteTimeInterval()
                        let nsBeat = scoreView.beat(atX: inP.x, interval: interval) - score.beatRange.start
                        beganPitch = pitch
                        beganStartBeat = nsBeat
                        let dBeat = note.beatRange.start + score.beatRange.start
                        - (note.beatRange.start + score.beatRange.start)
                            .interval(scale: interval)
                        beganDeltaNoteBeat = -dBeat
                        beganBeatRange = note.beatRange
                        oldNotePitch = note.pitch
                        
                        if document.isSelect(at: p) {
                            let noteIs = document.selectedNoteIndexes(from: scoreView)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        }
                        beganNotes[ni] = score.notes[ni]
                        
                        currentBeatNoteIndexes = beganNotes.keys.sorted()
                            .filter { score.notes[$0].beatRange.contains(note.beatRange.center) }
                    }
                    
                    let volume = Volume(smp: sheetView.isPlaying ? 0.1 : 1)
                    if let notePlayer = sheetView.notePlayer {
                        self.notePlayer = notePlayer
                        notePlayer.notes = currentBeatNoteIndexes.map { score.notes[$0] }
                        notePlayer.volume = volume
                    } else {
                        notePlayer = try? NotePlayer(notes: currentBeatNoteIndexes.map { score.notes[$0] },
                                                     volume: volume,
                                                     pan: note.pan)
                        sheetView.notePlayer = notePlayer
                    }
                    notePlayer?.play()
                } else if scoreView.tempoPositionBeat(scoreP, scale: document.screenToWorldScale) != nil {
                    type = .tempo
                    
                    beganTempo = score.tempo
                    oldTempo = beganTempo
                    
                    beganContents = sheetView.contentsView.elementViews.enumerated().reduce(into: .init()) { (dic, v) in
                        if beganTempo == v.element.model.timeOption?.tempo {
                            dic[v.offset] = v.element.model
                        }
                    }
                    beganTexts = sheetView.textsView.elementViews.enumerated().reduce(into: .init()) { (dic, v) in
                        if beganTempo == v.element.model.timeOption?.tempo {
                            dic[v.offset] = v.element.model
                        }
                    }
                    if beganTempo == sheetView.model.animation.tempo {
                        beganAnimationOption = sheetView.model.animation.option
                    }
                    if beganTempo == sheetView.model.score.tempo {
                        beganScoreOption = sheetView.model.score.option
                    }
                    
                    document.cursor = .arrowWith(string: SheetView.tempoString(fromTempo: beganTempo))
                } else if let ni = scoreView.attackNoteIndex(at: scoreP, maxDistance: maxD) {
                    type = .attack
                    
                    if document.isSelect(at: p) {
                        let noteIs = document.selectedNoteIndexes(from: scoreView)
                        beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                    } else {
                        let id = score.notes[ni].envelope.id
                        beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                            if id == $1.element.envelope.id {
                                $0[$1.offset] = $1.element
                            }
                        }
                    }
                    beganNotes[ni] = score.notes[ni]
                    
                    beganEnvelope = score.notes[ni].envelope
                } else if let ni = scoreView.decayAndSustainNoteIndex(at: scoreP, maxDistance: maxD) {
                    type = .decayAndSustain
                    
                    if document.isSelect(at: p) {
                        let noteIs = document.selectedNoteIndexes(from: scoreView)
                        beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                    } else {
                        let id = score.notes[ni].envelope.id
                        beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                            if id == $1.element.envelope.id {
                                $0[$1.offset] = $1.element
                            }
                        }
                    }
                    beganNotes[ni] = score.notes[ni]
                    
                    beganEnvelope = score.notes[ni].envelope
                } else if let ni = scoreView.releaseNoteIndex(at: scoreP, maxDistance: maxD) {
                    type = .release
                    
                    if document.isSelect(at: p) {
                        let noteIs = document.selectedNoteIndexes(from: scoreView)
                        beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                    } else {
                        let id = score.notes[ni].envelope.id
                        beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                            if id == $1.element.envelope.id {
                                $0[$1.offset] = $1.element
                            }
                        }
                    }
                    beganNotes[ni] = score.notes[ni]
                    
                    beganEnvelope = score.notes[ni].envelope
                } else if abs(scoreP.x - scoreView.x(atBeat: score.beatRange.end)) < maxMD {
                    type = .endBeat
                    
                    beganScoreOption = sheetView.model.score.option
                } else {
                    type = .all
                    
                    beganScoreOption = sheetView.model.score.option
                }
            }
        case .changed:
            if let sheetView {
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                let sheetP = sheetView.convertFromWorld(p)
                let scoreP = scoreView.convertFromWorld(p)
                
                switch type {
                case .all:
                    let px = sheetP.x - beganInP.x
                    let interval = document.currentNoteTimeInterval()
                    let beat = scoreView.beat(atX: px, interval: interval)
                    if beat != score.beatRange.start {
                        scoreView.model.beatRange.start = beat
                        document.updateSelects()
                    }
                case .startBeat:
                    if let beganScoreOption {
                        let interval = document.currentNoteTimeInterval()
                        let beat = min(scoreView.beat(atX: sheetP.x, interval: interval),
                                       beganScoreOption.beatRange.end)
                        if beat != score.beatRange.start {
                            var beatRange = beganScoreOption.beatRange
                            beatRange.start += beat
                            beatRange.length -= beat
                            scoreView.model.beatRange = beatRange
                            document.updateSelects()
                        }
                    }
                case .endBeat:
                    if let beganScoreOption {
                        let interval = document.currentNoteTimeInterval()
                        let beat = max(scoreView.beat(atX: sheetP.x, interval: interval),
                                       beganScoreOption.beatRange.start)
                        if beat != score.beatRange.end {
                            var beatRange = beganScoreOption.beatRange
                            beatRange.end = beat
                            scoreView.model.beatRange = beatRange
                            document.updateSelects()
                        }
                    }
                    
                case .tempo:
                    let di = (sp.x - beganSP.x) / editableTempoInterval
                    let tempo = Rational(Double(beganTempo) - di,
                                         intervalScale: Rational(1, 4))
                        .clipped(Music.tempoRange)
                    if tempo != oldTempo {
                        beganContents.forEach {
                            sheetView.contentsView.elementViews[$0.key].model.timeOption?.tempo = tempo
                        }
                        beganTexts.forEach {
                            sheetView.textsView.elementViews[$0.key].model.timeOption?.tempo = tempo
                        }
                        if beganAnimationOption != nil {
                            sheetView.animationView.tempo = tempo
                        }
                        if beganScoreOption != nil {
                            sheetView.scoreView.tempo = tempo
                        }
                        
                        document.updateSelects()
                        
                        document.cursor = .arrowWith(string: SheetView.tempoString(fromTempo: tempo))
                        
                        oldTempo = tempo
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
                        scoreView.notesView.elementViews[ni].model.envelope = env
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) })
                case .decayAndSustain:
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
                        scoreView.notesView.elementViews[ni].model.envelope = env
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) })
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
                        scoreView.notesView.elementViews[ni].model.envelope = env
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) })
                    
                case .overtone:
                    var overtone = beganOvertone
                    switch overtoneType {
                    case .evenScale:
                        let y = (sp.y - beganSP.y) / 5 * 0.0625
                        let v = (y + beganOvertone.evenScale).clipped(min: 0, max: 1)
                        overtone.evenScale = v
                    case .oddScale:
                        let y = (sp.y - beganSP.y) / 5 * 0.0625
                        let v = (y + beganOvertone.oddScale).clipped(min: 0, max: 1)
                        overtone.oddScale = v
                    }
                    
                    for ni in beganNotes.keys {
                        guard ni < score.notes.count else { continue }
                        var tone = scoreView.model.notes[ni].tone
                        tone.overtone = overtone
                        tone.id = beganTone.id
                        scoreView.notesView.elementViews[ni].model.tone = tone
                    }
                    sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) })
                case .sourceFilter:
                    if let noteI, noteI < score.notes.count {
                        let fqSmp = scoreView.sourceFilterFqAndSmp(at: scoreP, at: noteI)
                        var sourceFilter = beganSourceFilter
                        let firstV = beganSourceFilter[beganSourceFilterIndex, sourceFilterType]

                        let preFq = beganSourceFilterIndex - 1 >= 0 ?
                        sourceFilter.fqSmps[beganSourceFilterIndex - 1].x : 0
                        let nextFq = beganSourceFilterIndex + 1 < sourceFilter.fqSmps.count ?
                        sourceFilter.fqSmps[beganSourceFilterIndex + 1].x : SourceFilter.maxFq
                        
                        let nx = (firstV.x + fqSmp.x - beganSourceFilterFq).clipped(min: preFq, max: nextFq)
                        let ny = (firstV.y + fqSmp.y - beganSourceFilterSmp).clipped(min: 0, max: 1)
                        let ntp = Point(nx, ny)
                        sourceFilter[beganSourceFilterIndex, sourceFilterType] = ntp
                        
                        for ni in beganNotes.keys {
                            guard ni < score.notes.count else { continue }
                            var tone = scoreView.model.notes[ni].tone
                            tone.sourceFilter = sourceFilter
                            tone.id = beganTone.id
                            scoreView.notesView.elementViews[ni].model.tone = tone
                        }
                        sheetView.sequencer?.scoreNoders[score.id]?.replace(beganNotes.map { IndexValue(value: $0.value, index: $0.key) })
                    }
                    
                case .startNote:
                    if let beganPitch, let beganBeatRange {
                        let pitch = document.pitch(from: scoreView, at: scoreP)
                        let interval = document.currentNoteTimeInterval()
                        let nsBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                        - score.beatRange.start
                        
                        if pitch != oldNotePitch || nsBeat != oldNoteBeat {
                            let dBeat = nsBeat - beganBeatRange.start
                            let dPitch = pitch - beganPitch
                            for (ni, beganNote) in beganNotes {
                                guard ni < score.notes.count else { continue }
                                
                                var note = beganNote
                                note.pitch = dPitch + beganNote.pitch
                                
                                let nsBeat = beganNote.beatRange.start + dBeat
                                let neBeat = beganNote.beatRange.end
                                let beatRange = nsBeat < neBeat ? nsBeat ..< neBeat : neBeat ..< nsBeat
                                note.beatRange = beatRange
                                
                                scoreView.notesView.elementViews[ni].model = note
                            }
                            
                            oldNoteBeat = nsBeat
                            
                            if pitch != oldNotePitch {
                                notePlayer?.notes = currentBeatNoteIndexes
                                    .map { scoreView.notesView.elementViews[$0].model }
                                oldNotePitch = pitch
                            }
                            document.updateSelects()
                        }
                    }
                case .endNote:
                    if let beganPitch, let beganBeatRange {
                        let pitch = document.pitch(from: scoreView, at: scoreP)
                        let interval = document.currentNoteTimeInterval()
                        let neBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                        - score.beatRange.start
                        
                        if pitch != oldNotePitch || neBeat != oldNoteBeat {
                            let dBeat = neBeat - beganBeatRange.end
                            let dPitch = pitch - beganPitch
                            for (ni, beganNote) in beganNotes {
                                guard ni < score.notes.count else { continue }
                                
                                var note = beganNote
                                note.pitch = dPitch + beganNote.pitch
                                
                                let nsBeat = beganNote.beatRange.start
                                let neBeat = beganNote.beatRange.end + dBeat
                                let beatRange = nsBeat < neBeat ? nsBeat ..< neBeat : neBeat ..< nsBeat
                                note.beatRange = beatRange
                                
                                scoreView.notesView.elementViews[ni].model = note
                            }
                            
                            oldNoteBeat = neBeat
                            
                            if pitch != oldNotePitch {
                                notePlayer?.notes = currentBeatNoteIndexes
                                    .map { scoreView.notesView.elementViews[$0].model }
                                oldNotePitch = pitch
                            }
                            document.updateSelects()
                        }
                    }
                case .moveNote:
                    if let beganPitch {
                        let pitch = document.pitch(from: scoreView, at: scoreP)
                        let interval = document.currentNoteTimeInterval()
                        let nsBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                        - score.beatRange.start
                        
                        if pitch != oldNotePitch || nsBeat != oldNoteBeat {
                            let dBeat = nsBeat - beganStartBeat + beganDeltaNoteBeat
                            let dPitch = pitch - beganPitch
                            for (ni, beganNote) in beganNotes {
                                guard ni < score.notes.count else { continue }
                                
                                var note = beganNote
                                note.pitch = dPitch + beganNote.pitch
                                note.beatRange.start = dBeat + beganNote.beatRange.start
                                
                                scoreView.notesView.elementViews[ni].model = note
                            }
                            
                            oldNoteBeat = nsBeat
                            
                            if pitch != oldNotePitch {
                                notePlayer?.notes = currentBeatNoteIndexes
                                    .map { scoreView.notesView.elementViews[$0].model }
                                oldNotePitch = pitch
                            }
                            document.updateSelects()
                        }
                    }
                }
            }
        case .ended:
            notePlayer?.stop()
            node.removeFromParent()
            
            if let sheetView {
                if type == .all || type == .startBeat || type == .endBeat
                    || type == .startNote || type == .endNote || type == .moveNote {
                    
                    sheetView.updatePlaying()
                }
                
                if type == .all || type == .startBeat || type == .endBeat {
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
                    
                    if let beganAnimationOption, sheetView.model.animation.option != beganAnimationOption {
                        updateUndoGroup()
                        sheetView.capture(option: sheetView.model.animation.option,
                                          oldOption: beganAnimationOption)
                    }
                    if let beganScoreOption, sheetView.model.score.option != beganScoreOption {
                        updateUndoGroup()
                        sheetView.capture(sheetView.model.score.option,
                                          old: beganScoreOption)
                    }
                    if !beganContents.isEmpty || !beganTexts.isEmpty {
                        for (ci, beganContent) in beganContents {
                            guard ci < sheetView.model.contents.count else { continue }
                            let content = sheetView.contentsView.elementViews[ci].model
                            if content != beganContent {
                                updateUndoGroup()
                                sheetView.capture(content, old: beganContent, at: ci)
                            }
                        }
                        for (ti, beganText) in beganTexts {
                            guard ti < sheetView.model.texts.count else { continue }
                            let text = sheetView.textsView.elementViews[ti].model
                            if text != beganText {
                                updateUndoGroup()
                                sheetView.capture(text, old: beganText, at: ti)
                            }
                        }
                    }
                }
            }
            
            document.cursor = Document.defaultCursor
        }
    }
}

struct ScoreLayout {
    static let noteHeight = 6.0
    static let pitchPadding = 15.0
}

final class NoteView<T: BinderProtocol>: View {
    typealias Model = Note
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    var previousMora: Mora?, nextMora: Mora?
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        node = Node()//
    }
}
extension NoteView {
    func updateWithModel() {
        
    }
    
    var tone: Tone {
        get { model.tone }
        set {
            binder[keyPath: keyPath].tone = newValue
            updateWithModel()
        }
    }
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
            if let node = scoreNode.children.first(where: { $0.name == "isFullEdit" }) {
                node.isHidden = !isFullEdit
            }
        }
    }
    
    var spectrogramMaxMel: Double?
    var timeNode: Node?, currentVolumeNode: Node?
    var peakVolume = Volume() {
        didSet {
            guard peakVolume != oldValue else { return }
            updateFromPeakVolume()
        }
    }
    func updateFromPeakVolume() {
        guard let node = currentVolumeNode else { return }
        let frame = mainFrame
        let smp = peakVolume.smp
            .clipped(min: 0, max: Volume.maxSmp, newMin: 0, newMax: 1)
        let y = frame.height * smp
        node.path = Path([Point(), Point(0, y)])
        if abs(peakVolume.amp) < Audio.clippingAmp {
            node.lineType = .color(.background)
        } else {
            node.lineType = .color(.warning)
        }
    }
    
    var bounds = Sheet.defaultBounds {
        didSet {
            guard bounds != oldValue else { return }
            updateTimeline()
        }
    }
    var mainFrame: Rect {
        bounds.inset(by: Sheet.textPadding)
    }
    
    let scoreNode = Node()
    let clippingNode = Node(isHidden: true,
                            lineWidth: 4, lineType: .color(.warning))
    
    let notesView: ArrayView<SheetNoteView>
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        notesView = ArrayView(binder: binder,
                              keyPath: keyPath.appending(path: \Model.notes))
        
        node = Node(children: [scoreNode, notesView.node, clippingNode])
        updatePath()
        updateTimeline()
    }
}
extension ScoreView {
    var noteHeight: Double { ScoreLayout.noteHeight }
    
    func updateWithModel() {
        updateTimeline()
    }
    func updatePath() {
        updateClippingNode()
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
    var frameRate: Int { Keyframe.defaultFrameRate }
    func updateTimeline() {
        if model.enabled {
            scoreNode.children = self.timelineNode(model, frameRate: frameRate)
            
            let timeNode = Node(lineWidth: 3, lineType: .color(.content))
            let volumeNode = Node(lineWidth: 1, lineType: .color(.background))
            timeNode.append(child: volumeNode)
            scoreNode.children.append(timeNode)
            self.timeNode = timeNode
            self.currentVolumeNode = volumeNode
        } else {
            scoreNode.children = []
            self.timeNode = nil
            self.currentVolumeNode = nil
        }
    }
    
    var tempo: Rational {
        get { model.tempo }
        set {
            binder[keyPath: keyPath].tempo = newValue
            updateTimeline()
        }
    }
    
    func x(atSec sec: Rational) -> Double {
        x(atSec: Double(sec))
    }
    func x(atSec sec: Double) -> Double {
        sec * Sheet.secWidth + Sheet.textPadding.width
    }
    func x(atBeat beat: Rational) -> Double {
        x(atSec: model.sec(fromBeat: beat))
    }
    
    func width(atSecDuration sec: Rational) -> Double {
        width(atSecDuration: Double(sec))
    }
    func width(atSecDuration sec: Double) -> Double {
        sec * Sheet.secWidth
    }
    func width(atBeatDuration beatDur: Rational) -> Double {
        width(atSecDuration: model.sec(fromBeat: beatDur))
    }
    
    func sec(atX x: Double, interval: Rational) -> Rational {
        Rational(sec(atX: x), intervalScale: interval)
    }
    func sec(atX x: Double) -> Rational {
        sec(atX: x, interval: Rational(1, frameRate))
    }
    func sec(atX x: Double) -> Double {
        (x - Sheet.textPadding.width) / Sheet.secWidth
    }
    
    func beat(atX x: Double, interval: Rational) -> Rational {
        model.beat(fromSec: sec(atX: x), interval: interval)
    }
    func beat(atX x: Double) -> Rational {
        beat(atX: x, interval: Rational(1, frameRate))
    }
    
    func pitch(atY y: Double, interval: Rational) -> Rational {
        Rational((y - mainFrame.minY) / noteHeight, intervalScale: interval)
    }
    func smoothPitch(atY y: Double) -> Double? {
        (y - mainFrame.minY) / noteHeight
    }
    func y(fromPitch pitch: Rational) -> Double {
        y(fromPitch: pitch, noteHeight: noteHeight)
    }
    func y(fromPitch pitch: Rational, noteHeight nh: Double) -> Double {
        Double(pitch) * nh + ScoreLayout.pitchPadding
    }
    func y(fromPitch pitch: Double) -> Double {
        y(fromPitch: pitch, noteHeight: noteHeight)
    }
    func y(fromPitch pitch: Double, noteHeight nh: Double) -> Double {
        pitch * nh + ScoreLayout.pitchPadding
    }
    
    var beatRange: Range<Rational>? {
        model.beatRange
    }
    var localBeatRange: Range<Rational>? {
        model.localMaxBeatRange
    }
    
    func timelineNode(_ score: Score, frameRate: Int, padding: Double = 7) -> [Node] {
        let sBeat = max(score.beatRange.start, -10000),
            eBeat = min(score.beatRange.end, 10000)
        guard sBeat <= eBeat else { return [] }
        let sx = self.x(atBeat: sBeat)
        let ex = self.x(atBeat: eBeat)
        
        let lw = 1.0
        let knobW = 2.0, knobH = 12.0
        let pitchRange = Score.pitchRange
        let nh = noteHeight
        let y = ScoreLayout.pitchPadding, timelineHalfHeight = Sheet.timelineHalfHeight
        let h = self.y(fromPitch: pitchRange.length, noteHeight: nh)
        let maxY = y + h
        let sy = y - timelineHalfHeight
        let ey = maxY + timelineHalfHeight
        
        var scoreNodes = [Node]()
        var contentPathlines = [Pathline]()
        var subBorderPathlines = [Pathline]()
        var fullEditBorderPathlines = [Pathline]()
        var borderPathlines = [Pathline]()
        var noteLineNodes = [Node]()
        var noteOctaveLinePathlines = [Pathline]()
        var noteChordLinePathlines = [Pathline]()
        var noteKnobPathlines = [Pathline]()
        
        func timeStringFrom(time: Rational, frameRate: Int) -> String {
            if time >= 60 {
                let c = Int(time * Rational(frameRate))
                let s = c / frameRate
                let minutes = s / 60
                let sec = s - minutes * 60
                let frame = c - s * frameRate
                let minutesStr = String(format: "%d", minutes)
                let secStr = String(format: "%02d", sec)
                let frameStr = String(format: "%02d", frame)
                return minutesStr + ":" + secStr + "." + frameStr
            } else {
                let c = Int(time * Rational(frameRate))
                let s = c / frameRate
                let sec = s
                let frame = c - s * frameRate
                let secStr = String(format: "%d", sec)
                let frameStr = String(format: "%02d", frame)
                return secStr + "." + frameStr
            }
        }
        
        if let localBeatRange = score.localMaxBeatRange {
            if localBeatRange.start < 0 {
                let beat = -min(localBeatRange.start, 0)
                - min(score.beatRange.start, 0)
                let timeText = Text(string: timeStringFrom(time: beat, frameRate: frameRate),
                                    size: Font.smallSize)
                let y = self.y(fromPitch: pitchRange.length, noteHeight: nh)
                let timeP = Point(sx + 1, y + nh)
                scoreNodes.append(Node(attitude: Attitude(position: timeP),
                                       path: Path(timeText.typesetter, isPolygon: false),
                                       fillType: .color(.content)))
            } else if localBeatRange.start > 0 {
                let ssx = x(atBeat: localBeatRange.start + score.beatRange.start)
                contentPathlines.append(Pathline(Rect(x: ssx - 1 / 4,
                                                      y: y - 3,
                                                      width:  1 / 2,
                                                      height: 6)))
            }
            
            if score.beatRange.start + localBeatRange.end > score.beatRange.end {
                let beat = score.beatRange.length - localBeatRange.start
                
                let timeText = Text(string: timeStringFrom(time: beat, frameRate: frameRate),
                                    size: Font.smallSize)
                let timeFrame = timeText.frame ?? Rect()
                let y = self.y(fromPitch: pitchRange.length, noteHeight: nh)
                let timeP = Point(ex - timeFrame.width - 2, nh + y)
                scoreNodes.append(Node(attitude: Attitude(position: timeP),
                                       path: Path(timeText.typesetter, isPolygon: false),
                                       fillType: .color(.content)))
            } else if localBeatRange.end < score.beatRange.length {
                let ssx = x(atBeat: localBeatRange.end + score.beatRange.start)
                contentPathlines.append(Pathline(Rect(x: ssx - 1 / 4,
                                                      y: y - 3,
                                                      width: 1 / 2,
                                                      height: 6)))
            }
        }
        
        contentPathlines.append(.init(Rect(x: sx - 1, y: y - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: ex - 1, y: y - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: sx + 1, y: y - lw / 2,
                                           width: ex - sx - 2, height: lw)))
        
        let secRange = score.secRange
        for sec in Int(secRange.start.rounded(.up)) ..< Int(secRange.end.rounded(.up)) {
            let sec = Rational(sec)
            let secX = x(atSec: sec)
            contentPathlines.append(.init(Rect(x: secX - lw / 2,
                                               y: y - 2,
                                               width: lw,
                                               height: 4)))
        }
        
        makeBeatPathlines(in: score.beatRange, sy: sy, ey: ey,
                          subBorderPathlines: &subBorderPathlines,
                          fullEditBorderPathlines: &fullEditBorderPathlines,
                          borderPathlines: &borderPathlines)
        
        let beat = score.beatRange.start
        let notes = score.notes.map {
            var note = $0
            note.beatRange.start += beat
            return note
        }
        
        if let range = Range<Int>(pitchRange) {
            var isAppendOctaveText = false
            for pitch in range {
                for k in 0 ..< 12 {
                    let pitch = Rational(pitch - 1) + Rational(k, 12)
                    let py = self.y(fromPitch: pitch, noteHeight: nh)
                    
                    fullEditBorderPathlines.append(.init(Rect(x: sx, y: py - lw * 0.125 / 2,
                                                              width: ex - sx, height: lw * 0.125)))
                }
                
                let py = self.y(fromPitch: Rational(pitch), noteHeight: nh)
                let hlw = lw / 2
                borderPathlines.append(.init(Rect(x: sx, y: py - hlw / 2,
                                                  width: ex - sx, height: hlw)))
                
                let mod = pitch.mod(12)
                if mod == 3 || mod == 6 || mod == 9 {
                    let my = self.y(fromPitch: Rational(pitch), noteHeight: nh)
                    let lw = mod == 6 ? lw : lw / 2
                    contentPathlines.append(Pathline(Rect(x: sx - 3,
                                                          y: my - lw / 2,
                                                          width: 3,
                                                          height: lw)))
                } else if mod == 0 {
                    let my = self.y(fromPitch: Rational(pitch), noteHeight: nh)
                    
                    let plw = lw * 2
                    contentPathlines.append(Pathline(Rect(x: sx - 3,
                                                          y: my - plw / 2,
                                                          width: 3,
                                                          height: plw)))
                    
                    let octaveText = Text(string: "\(Int(Rational(pitch)) / 12)",
                                             size: Font.smallSize)
                    scoreNodes.append(Node(attitude: Attitude(position: Point(sx - 3 - (octaveText.frame?.width ?? 0) - 1, my)),
                                          path: octaveText.typesetter.path(),
                                          fillType: .color(.content)))
                    isAppendOctaveText = true
                }
            }
            if !isAppendOctaveText {
                let pitch = Rational((range.lowerBound + range.upperBound) / 2)
                let movedPitch = pitch
                let nPitch = Pitch(value: movedPitch)
                let octaveText = Text(string: "\(nPitch.octave).\(String(format: "%02d", Int(nPitch.unison)))",
                                      size: Font.smallSize * 0.75)
                
                let oy = self.y(fromPitch: pitch, noteHeight: nh)
                scoreNodes.append(Node(attitude: Attitude(position: Point(sx - 2 - (octaveText.frame?.width ?? 0) - 1, oy)),
                                      path: octaveText.typesetter.path(),
                                      fillType: .color(.content)))
            }
            
            let unisonsSet = Set(notes.compactMap { Int($0.pitch.rounded().mod(12)) })
            for pitch in range {
                guard unisonsSet.contains(pitch.mod(12)) else { continue }
                let py = self.y(fromPitch: Rational(pitch), noteHeight: nh)
                subBorderPathlines.append(Pathline(Rect(x: sx, y: py - lw / 2,
                                                        width: ex - sx, height: lw)))
            }
        }
        
        var brps = [(Range<Rational>, Int)]()
        let preBeat = max(beat, sBeat)
        let nextBeat = min(beat + score.beatRange.length, eBeat)
        
        func appendOctaves(_ note: Note, isChord: Bool) {
            var nNote = note
            while true {
                nNote.pitch -= 12
                guard nNote.pitch > 0 && nNote.pitch < pitchRange.length else { break }
                
                let (aNoteLinePathlines, _, _)
                = notePathlines(from: nNote,
                                preFq: nil, nextFq: nil, tempo: score.tempo)
                if isChord {
                    noteChordLinePathlines += aNoteLinePathlines
                } else {
                    noteOctaveLinePathlines += aNoteLinePathlines
                }
            }
            
            nNote = note
            var count = 1
            while true {
                nNote.pitch += 12
                count += 1
                guard nNote.pitch > 0 && nNote.pitch < pitchRange.length else { break }
                
                let (aNoteLinePathlines, _, _)
                = notePathlines(from: nNote,
                                preFq: nil, nextFq: nil, tempo: score.tempo)
                if isChord {
                    noteChordLinePathlines += aNoteLinePathlines
                } else {
                    noteOctaveLinePathlines += aNoteLinePathlines
                }
            }
        }
        let nNotes = notes
        for (i, note) in nNotes.enumerated() {
            guard pitchRange.contains(note.pitch) else { continue }
            var beatRange = note.beatRange
            
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
            
            let note = nNotes[i]
            
            let isChord = note.isChord
            if isChord {
                brps.append((beatRange, note.roundedPitch))
            }
            appendOctaves(note, isChord: isChord)
            
            let (preFq, nextFq) = pitbendPreNext(notes: nNotes, at: i)
            let (aNoteLinePathlines, aNoteKnobPathlines, lyricPath)
            = notePathlines(from: note,
                            preFq: preFq, nextFq: nextFq, tempo: score.tempo)
            
            let pan = note.pan
            noteLineNodes += aNoteLinePathlines.enumerated().map {
                var color = Self.panColor(pan: pan,
                                          brightness: 0.25)
                if case .line(let line) = $0.element.elements.first {
                    color = .init(lightness: line.uuColor.value.lightness, a: color.a, b: color.b)
                }
                return Node(path: Path([$0.element]),
                            lineWidth: nh,
                            lineType: .color(color))
            }
            
            noteKnobPathlines += aNoteKnobPathlines
            if let lyricPath {
                scoreNodes.append(.init(path: lyricPath, fillType: .color(.content)))
            }
        }
        
        let trs = Chord.splitedTimeRanges(timeRanges: brps)
        for (tr, pitchs) in trs {
            let ps = pitchs.sorted()
            guard let chord = Chord(pitchs: ps),
                  chord.typers.count <= 8 else { continue }
            
            var typersDic = [Int: [(typer: Chord.ChordTyper,
                                    typerIndex: Int,
                                    isInvrsion: Bool)]]()
            for (ti, typer) in chord.typers.sorted(by: { $0.index < $1.index }).enumerated() {
                let inversionUnisons = typer.inversionUnisons
                var j = typer.index
                let fp = ps[j]
                for i in 0 ..< typer.type.unisons.count {
                    guard j < ps.count else { break }
                    if typersDic[j] != nil {
                        typersDic[j]?.append((typer,
                                              ti,
                                              typer.inversion == i))
                    } else {
                        typersDic[j] = [(typer,
                                         ti,
                                         typer.inversion == i)]
                    }
                    while j + 1 < ps.count,
                          !inversionUnisons.contains(ps[j + 1] - fp) {
                        j += 1
                    }
                    j += 1
                }
            }
            
            for (i, typers) in typersDic {
                let pitch = Rational(ps[i])
                let nsx = x(atBeat: tr.start), nex = x(atBeat: tr.end)
                let cy = self.y(fromPitch: pitch, noteHeight: nh)
                let d = 1.0
                let nw = 4.0 * Double(chord.typers.count - 1)
                func appendChordLine(at ti: Int,
                                     isInversion: Bool,
                                     _ typer: Chord.ChordTyper) {
                    let tlw = 0.5
                    let lw =
                    switch typer.type {
                    case .octave: 7 * tlw
                    case .major, .power: 5 * tlw
                    case .suspended: 3 * tlw
                    case .minor: 7 * tlw
                    case .augmented: 5 * tlw
                    case .flatfive: 3 * tlw
                    case .diminish, .tritone: 1 * tlw
                    }
                    
                    let x = -nw / 2 + 4.0 * Double(ti)
                    let fx = (nex + nsx) / 2 + x - lw / 2
                    let fy0 = cy + 1, fy1 = cy - 1 - d
                    
                    let minorCount =
                    switch typer.type {
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
                            contentPathlines.append(Pathline(Rect(x: fx + id, y: fy0,
                                                                  width: tlw, height: d - tlw)))
                            contentPathlines.append(Pathline(Rect(x: fx, y: fy0 + d - tlw,
                                                                  width: lw, height: tlw)))
                            
                            contentPathlines.append(Pathline(Rect(x: fx + id, y: fy1 + tlw,
                                                                  width: tlw, height: d - tlw)))
                            contentPathlines.append(Pathline(Rect(x: fx, y: fy1,
                                                                  width: lw, height: tlw)))
                        }
                    } else {
                        contentPathlines.append(Pathline(Rect(x: fx, y: fy0,
                                                              width: lw, height: d)))
                        contentPathlines.append(Pathline(Rect(x: fx, y: fy1,
                                                              width: lw, height: d)))
                    }
                    if isInversion {
                        let ilw = 1.0
                        contentPathlines.append(Pathline(Rect(x: fx - ilw, y: fy0 + ilw,
                                                              width: lw + 2 * ilw, height: ilw)))
                        contentPathlines.append(Pathline(Rect(x: fx - ilw, y: fy1 - ilw,
                                                              width: lw + 2 * ilw, height: ilw)))
                    }
                }
                for (_, typerTuple) in typers.enumerated() {
                    appendChordLine(at: typerTuple.typerIndex,
                                    isInversion: typerTuple.isInvrsion,
                                    typerTuple.typer)
                }
            }
        }
        
        contentPathlines.append(Pathline(Rect(x: sx - 1 / 2, y: y,
                                              width: 1, height: h + 1 / 2)))
        contentPathlines.append(Pathline(Rect(x: ex - 1 / 2, y: y,
                                              width: 1, height: h + 1 / 2)))
        contentPathlines.append(Pathline(Rect(x: sx, y: y + h - 1 / 2,
                                              width: ex - sx, height: 1)))
        
        let tempoBeat = score.beatRange.start.rounded(.down) + 1
        if tempoBeat < score.beatRange.end {
            let np = Point(x(atBeat: tempoBeat), sy)
            contentPathlines.append(Pathline(Rect(x: np.x - 1, y: np.y - 2, width: 2, height: 4)))
        }
        
        var nodes = [Node]()
        
        if !fullEditBorderPathlines.isEmpty {
            nodes.append(Node(name: "isFullEdit",
                              isHidden: !isFullEdit,
                              path: Path(fullEditBorderPathlines),
                              fillType: .color(.border)))
        }
        if !borderPathlines.isEmpty {
            nodes.append(Node(path: Path(borderPathlines),
                              fillType: .color(.border)))
        }
        if !noteOctaveLinePathlines.isEmpty {
            nodes += noteOctaveLinePathlines.enumerated().map {
                return Node(path: Path([$0.element]),
                            lineWidth: nh,
                            lineType: .color(.border))
            }
        }
        if !noteChordLinePathlines.isEmpty {
            nodes += noteChordLinePathlines.enumerated().map {
                return Node(path: Path([$0.element]),
                            lineWidth: nh,
                            lineType: .color(.subBorder))
            }
        }
        if !subBorderPathlines.isEmpty {
            nodes.append(Node(path: Path(subBorderPathlines),
                              fillType: .color(.subBorder)))
        }
        nodes += noteLineNodes
        if !contentPathlines.isEmpty {
            nodes.append(Node(path: Path(contentPathlines),
                              fillType: .color(.content)))
        }
        if !noteKnobPathlines.isEmpty {
            nodes.append(Node(path: Path(noteKnobPathlines),
                              fillType: .color(.background)))
        }
        nodes += scoreNodes
        
        return nodes
    }
    
    static func panColor(pan: Double, brightness l: Double) -> Color {
        pan == 0 ?
        Color(red: l, green: l, blue: l) :
            (pan > 0 ?
             Color(red: pan * Spectrogram.editRedRatio * (1 - l) + l, green: l, blue: l) :
                Color(red: l, green: -pan * Spectrogram.editGreenRatio * (1 - l) + l, blue: l))
    }
    
    func updateTimeNode(atSec sec: Rational) {
        if let timeNode = timeNode {
            let frame = mainFrame
            let x = self.x(atSec: sec)
            if x >= frame.minX && x < frame.maxX {
                timeNode.path = Path([Point(), Point(0, frame.height)])
                timeNode.attitude.position = Point(x, frame.minY)
                updateFromPeakVolume()
            } else {
                timeNode.path = Path()
                currentVolumeNode?.path = Path()
            }
        } else {
            timeNode?.path = Path()
            currentVolumeNode?.path = Path()
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
        let sx = x(atBeat: model.beatRange.start)
        let ex = x(atBeat: model.beatRange.end)
        return Rect(x: sx, y: -6, width: ex - sx, height: 12).outset(by: 3)
    }
    var transformedTimelineFrame: Rect? {
        timelineFrame
    }
    
    func containsOctave(_ p: Point) -> Bool {
        octaveFrame?.contains(p) ?? false
    }
    var octaveFrame: Rect? {
        if let node = scoreNode.children.first(where: { $0.name == "octave" }) {
            return node.transformedBounds?.outset(by: 5)
        } else {
            return nil
        }
    }
    
    func containsAttack(_ p: Point) -> Bool {
        guard isFullEdit, let noteI = noteIndex(at: p, maxDistance: 5) else { return false }
        let nf = noteFrame(from: model.notes[noteI])
        return p.x < nf.minX + nf.width * 0.1
    }
    func attackNoteIndex(at p: Point, maxDistance: Double) -> Int? {
        containsAttack(p) ? noteIndex(at: p, maxDistance: maxDistance) : nil
    }
    var attackFrame: Rect? {
        if let node = scoreNode.children.first(where: { $0.name == "attack" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    var paddingAttackFrame: Rect? {
        guard let f = attackFrame else { return nil }
        let d = 5.0
        return Rect(x: f.minX - d,
                    y: f.minY - d,
                    width: f.width + d,
                    height: f.height + d * 2)
    }
    
    func containsDecayAndSustain(_ p: Point) -> Bool {
        guard isFullEdit, let noteI = noteIndex(at: p, maxDistance: 5) else { return false }
        let nf = noteFrame(from: model.notes[noteI])
        return p.y > nf.minY + nf.height * 0.9
    }
    func decayAndSustainNoteIndex(at p: Point, maxDistance: Double) -> Int? {
        containsDecayAndSustain(p) ? noteIndex(at: p, maxDistance: maxDistance) : nil
    }
    var decayAndSustainFrame: Rect? {
        if let node = scoreNode.children.first(where: { $0.name == "decayAndSustain" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    var paddingDecayAndSustainFrame: Rect? {
        guard let f = decayAndSustainFrame else { return nil }
        let d = 5.0
        return Rect(x: f.minX,
                    y: f.minY - d,
                    width: f.width,
                    height: f.height + d * 2)
    }
    
    func containsRelease(_ p: Point) -> Bool {
        guard isFullEdit, let noteI = noteIndex(at: p, maxDistance: 5) else { return false }
        let nf = noteFrame(from: model.notes[noteI])
        return p.x > nf.minX + nf.width * 0.9
    }
    func releaseNoteIndex(at p: Point, maxDistance: Double) -> Int? {
        containsRelease(p) ? noteIndex(at: p, maxDistance: maxDistance) : nil
    }
    var releaseFrame: Rect? {
        if let node = scoreNode.children.first(where: { $0.name == "release" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    var paddingReleaseFrame: Rect? {
        guard let f = releaseFrame else { return nil }
        let d = 5.0
        return Rect(x: f.minX,
                    y: f.minY - d,
                    width: f.width + d,
                    height: f.height + d * 2)
    }
    
    func noteT(atX x: Double, at noteI: Int) -> Double {
        let note = model.notes[noteI]
        let minX = self.x(atBeat: note.beatRange.start)
        let maxX = self.x(atBeat: note.beatRange.end)
        guard minX < maxX else { return 0 }
        return (x - minX) / (maxX - minX)
    }
    func noteY(atX x: Double, at noteI: Int) -> Double {
        let note = model.notes[noteI]
        let t = noteT(atX: x, at: noteI)
        return self.y(fromPitch: note.pitbend.pitch(atT: t) + Double(note.pitch))
    }
    
    func overtoneType(at p: Point, at noteI: Int) -> (noteI: Int, type: OvertoneType)? {
        guard isFullEdit else { return nil }
        
        let noteY = noteY(atX: p.x, at: noteI)
        if abs(noteY) > 1 && abs(noteY) < 1.2 {
            let type: OvertoneType = noteY < 0 ? .evenScale : .oddScale
            return (noteI, type)
        } else {
            return nil
        }
    }
    func containsOvertone(_ p: Point, at noteI: Int) -> Bool {
        overtoneType(at: p, at: noteI) != nil
    }
    
    func sourceFilterFqAndSmp(at p: Point, at noteI: Int) -> Point {
        let noteT = noteT(atX: p.x, at: noteI)
        let noteY = noteY(atX: p.x, at: noteI)
        let note = model.notes[noteI]
        let sec = Double(sec(atX: p.x) - model.sec(fromBeat: note.beatRange.start))
        let sf = model.notes[noteI].tone.sourceFilter
        let hlw = noteHeight * note.smp(atSec: sec) / 2
        let fq = p.y.clipped(min: noteY - hlw, max: noteT + hlw, newMin: 0, newMax: 20000)
        let smp = sf.smp(atFq: fq)
        return.init(fq, smp)
    }
    func sourceFilterPosition(at sfi: Int, at p: Point, atNote noteI: Int) -> Point {
        let noteY = noteY(atX: p.x, at: noteI)
        let note = model.notes[noteI]
        let sec = Double(sec(atX: p.x) - model.sec(fromBeat: note.beatRange.start))
        let sf = model.notes[noteI].tone.sourceFilter
        let v = sf[sfi, .fqSmp]
        let hlw = noteHeight * note.smp(atSec: sec) / 2
        let ny = v.x.clipped(min: 0, max: 20000, newMin: -hlw, newMax: hlw)
        return .init(p.x, noteY + ny)
    }
    func sourceFilterIndex(at p: Point, at noteI: Int) -> Int? {
        guard isFullEdit else { return nil }
        
        let score = model
        var minDS = Double.infinity, minI: Int?
        let sf = score.notes[noteI].tone.sourceFilter
        for (sfi, _) in sf.fqSmps.enumerated() {
            let np = sourceFilterPosition(at: sfi, at: p, atNote: noteI)
            let ds = p.distanceSquared(np)
            if ds < minDS {
                minDS = ds
                minI = sfi
            }
        }
        return minI
    }
    func containsSourceFilter(_ p: Point, at noteI: Int) -> Bool {
        sourceFilterIndex(at: p, at: noteI) != nil
    }
    
    func tempoPositionBeat(_ p: Point, scale: Double) -> Rational? {
        let score = model
        let tempoBeat = score.beatRange.start.rounded(.down) + 1
        if tempoBeat < score.beatRange.end {
            let np = Point(x(atBeat: tempoBeat), mainFrame.minY)
            return np.distance(p) < 15 * scale ? tempoBeat : nil
        } else {
            return nil
        }
    }
    
    func containsNote(_ p: Point, scale: Double) -> Bool {
        noteIndex(at: p, maxDistance: 15 * scale) != nil
    }
    
    func mainLineDistance(_ p: Point) -> Double {
        abs(p.y)
    }
    func containsMainLine(_ p: Point, distance: Double) -> Bool {
        guard containsTimeline(p) else { return false }
        return mainLineDistance(p) < distance
    }
    
    func noteFrame(from note: Note) -> Rect {
        let score = model
        let nh = noteHeight
        let sh = y(fromPitch: note.pitch, noteHeight: nh)
        let nx = x(atBeat: note.beatRange.start + score.beatRange.start)
        let w = note.beatRange.length == 0 ?
        width(atBeatDuration: Rational(1, 96)) :
        x(atBeat: note.beatRange.end + score.beatRange.start) - nx
        return Rect(x: nx, y: sh - nh / 2, width: w, height: nh)
    }
    var noteFrames: [Rect] {
        let score = model
        let nh = noteHeight
        return score.notes.compactMap { note in
            guard Score.pitchRange.contains(note.pitch) else { return nil }
            let sh = y(fromPitch: note.pitch, noteHeight: nh)
            let nx = x(atBeat: note.beatRange.start + score.beatRange.start)
            let w = note.beatRange.length == 0 ?
            1 : x(atBeat: note.beatRange.end + score.beatRange.start) - nx
            return Rect(x: nx, y: sh - nh / 2, width: w, height: nh)
        }
    }
    func noteNode(from note: Note, at i: Int?,
                  color: Color = .content) -> Node {
        Node(children: noteNodes(from: note, at: i, color: color))
    }
    func noteNodes(from note: Note, at i: Int?,
                   color: Color = .content) -> [Node] {
        let score = model
        let noteHeight = noteHeight
        
        let (preFq, nextFq) = i != nil ? pitbendPreNext(notes: score.notes, at: i!) : (nil, nil)
        let (linePathlines, knobPathlines, lyricPath) = notePathlines(from: note,
                                                                      preFq: preFq, nextFq: nextFq,
                                                                      tempo: score.tempo)
        
        let lyricNodes: [Node] = if let lyricPath {
            [Node(path: lyricPath, fillType: .color(color))]
        } else {
            []
        }
        
        let pan = note.pan
        let nodes = linePathlines.enumerated().map {
            let color = Self.panColor(pan: pan, brightness: 0.25)
            return Node(path: Path([$0.element]),
                        lineWidth: noteHeight,
                        lineType: .color(color))
        }
        
        return nodes + [Node(path: Path(knobPathlines),
                             fillType: .color(.background))] + lyricNodes
    }
    func notePathlines(from note: Note,
                       preFq: Double?, nextFq: Double?,
                       tempo: Rational) -> (linePathlines: [Pathline], knobPathlines: [Pathline],
                                            lyricPath: Path?) {
        let noteHeight = noteHeight
        let nx = x(atBeat: note.beatRange.start)
        let ny = self.y(fromPitch: note.pitch, noteHeight: noteHeight)
        let nw = width(atBeatDuration: note.beatRange.length == 0 ? Rational(1, 96) : note.beatRange.length)
        if note.volumeAmp == 0 {
            let d = 1.0 - 1.0 / 4
            var line0 = Line(edge: .init(.init(nx, ny - d), .init(nx + nw, ny - d)))
            line0.controls = line0.controls.map {
                .init(point: $0.point,
                      weight: $0.weight,
                      pressure: $0.pressure / noteHeight / 2)
            }
            var line1 = Line(edge: .init(.init(nx, ny + d), .init(nx + nw, ny + d)))
            line1.controls = line1.controls.map {
                .init(point: $0.point,
                      weight: $0.weight,
                      pressure: $0.pressure / noteHeight / 2)
            }
            
            return ([.init(line0), .init(line1)], [], nil)
        }
        
        func lyricPath(at p: Point) -> Path? {
            if !note.lyric.isEmpty || note.isBreath || note.isVibrato || note.isVowelReduction {
                let str = "\(note.lyric)"
                + (note.isBreath ? "^" : "")
                + (note.isVibrato ? "~" : "")
                + (note.isVowelReduction ? "/" : "")
                let lyricText = Text(string: str, size: Font.smallSize)
                let typesetter = lyricText.typesetter
                return typesetter.path() * Transform(translationX: p.x, y: p.y - typesetter.height / 2)
            } else {
                return nil
            }
        }
        
        let nt = 0.2, d = 1.5, h = noteHeight / 2
        let oddNT = nt * note.tone.overtone.oddScale
        let evenNT = nt * note.tone.overtone.evenScale
        
        let smpT = note.volume.smp
            .clipped(min: 0, max: Volume.maxSmp, newMin: 0, newMax: 1) + 1 / noteHeight
        if !note.pitbend.isEmpty || (note.pitbend.isEmpty && !note.lyric.isEmpty) {
            let pitbend = pitbend(from: note, tempo: tempo, preFq: preFq, nextFq: nextFq)
            let secDur = Double(Score.sec(fromBeat: note.beatRange.length, tempo: tempo))
            
            var line = pitbend.line(secDuration: secDur,
                                    envelope: note.envelope) ?? Line()
            line.controls = line.controls.map {
                .init(point: .init($0.point.x / secDur * nw + nx,
                                   self.y(fromPitch: Double(note.pitch) + $0.point.y * 12,
                                               noteHeight: noteHeight)),
                      weight: $0.weight,
                      pressure: $0.pressure * smpT)
            }
            
            let knobPathlines = pitbend.pits.map {
                Pathline(circleRadius: 0.5,
                         position: .init($0.t * nw + nx,
                                         self.y(fromPitch: Double(note.pitch) + $0.pitch * 12,
                                                     noteHeight: noteHeight)))
            }
            
            let line1 = Line(controls: line.controls.map { .init(point: .init($0.point.x, $0.point.y + d + $0.pressure * h), pressure: oddNT) })
            let line2 = Line(controls: line.controls.map { .init(point: .init($0.point.x, $0.point.y - d - $0.pressure * h), pressure: evenNT) })
            
            let lp = (line.controls.first?.point ?? .init(nx, ny)) + .init(0, -noteHeight / 2)
            return ((line.isEmpty ? [] : [.init(line), .init(line1), .init(line2)]), knobPathlines, lyricPath(at: lp))
        } else {
            let env = note.envelope
            let attackW = width(atSecDuration: env.attackSec)
            let sustain = Volume(amp: note.volume.amp * env.sustainAmp).smp
                .clipped(min: 0, max: Volume.maxSmp, newMin: 0, newMax: 1) + 1 / noteHeight
            let line = Line(controls: [.init(point: Point(nx, ny), pressure: 0),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW + width(atSecDuration: env.decaySec), ny), pressure: sustain),
                                       .init(point: Point(nx + attackW + width(atSecDuration: env.decaySec), ny), pressure: sustain),
                                       .init(point: Point(nx + nw, ny), pressure: sustain),
                                       .init(point: Point(nx + nw, ny), pressure: sustain),
                                       .init(point: Point(nx + nw + width(atSecDuration: env.releaseSec), ny), pressure: 0)])
            
            let lines = (0 ... 20).map { i in
                let s = Double(i) / 20
                let l = note.tone.sourceFilter.smp(atMel: s * SourceFilter.maxMel)
                    .clipped(min: 0, max: 1, newMin: 75, newMax: 25)
                return Line(controls: line.controls.map { .init(point: .init($0.point.x, $0.point.y - $0.pressure * h + $0.pressure * h * 2 * s), pressure: $0.pressure / 20) }, uuColor: UU(Color(lightness: l)))
            }
            
            let line1 = Line(controls: line.controls.map { .init(point: .init($0.point.x, $0.point.y + d + $0.pressure * h), pressure: oddNT) })
            let line2 = Line(controls: line.controls.map { .init(point: .init($0.point.x, $0.point.y - d - $0.pressure * h), pressure: evenNT) })
            return ([.init(line1), .init(line2)] + lines.map { .init($0) }, [], lyricPath(at: .init(nx, ny - noteHeight / 2)))
        }
    }
    
    func pitbendPreNext(notes: [Note], at i: Int) -> (preFq: Double?, nextFq: Double?) {
        let note = notes[i]
        guard !note.lyric.isEmpty else { return (nil, nil) }
        var preFq, nextFq: Double?
        
        var minD = Rational.max
        for j in (0 ..< i).reversed() {
            guard !notes[j].lyric.isEmpty else { continue }
            guard notes[j].beatRange.end == note.beatRange.start else { break }
            let d = abs(note.pitch - notes[j].pitch)
            if d < Pitbend.enabledRecoilPitchDistance, d < minD {
                preFq = notes[j].fq
                minD = d
            }
        }
        
        minD = .max
        for j in i + 1 ..< notes.count {
            guard !notes[j].lyric.isEmpty else { continue }
            guard notes[j].beatRange.start == note.beatRange.end else { break }
            let d = abs(note.pitch - notes[j].pitch)
            if d < Pitbend.enabledRecoilPitchDistance, d < minD {
                preFq = notes[j].fq
                minD = d
            }
        }
        return (preFq, nextFq)
    }
    func pitbend(from note: Note, tempo: Rational,
                 preFq: Double?, nextFq: Double?) -> Pitbend {
        if !note.pitbend.isEmpty || (note.pitbend.isEmpty && !note.lyric.isEmpty) {
            if !note.pitbend.isEmpty {
                return note.pitbend
            } else {
                let isVowel = Phoneme.isSyllabicJapanese(Phoneme.phonemes(fromHiragana: note.lyric))
                return Pitbend(isVibrato: note.isVibrato,
                               duration: Double(Score.sec(fromBeat: note.beatRange.length, tempo: tempo)),
                               fq: note.fq,
                               isVowel: isVowel,
                               previousFq: preFq, nextFq: nextFq)
            }
        } else {
            return Pitbend()
        }
    }
    
    func pitT(at p: Point,
              maxDistance maxD: Double) -> (noteI: Int, pitT: Double)? {
        let score = model
        
        var minNoteI: Int?, minPitT: Double?, minD = Double.infinity
        for noteI in 0 ..< score.notes.count {
            let note = score.notes[noteI]
            let (preFq, nextFq) = pitbendPreNext(notes: score.notes, at: noteI)
            let pitbend = pitbend(from: note, tempo: score.tempo, preFq: preFq, nextFq: nextFq)
            
            let f = noteFrame(from: note)
            let sh = self.y(fromPitch: note.pitch, noteHeight: f.height)
            if f.width > 0 && p.x >= f.minX && p.x <= f.maxX {
                let t = (p.x - f.minX) / f.width
                let pit = pitbend.pit(atT: t)
                
                let y = self.y(fromPitch: pit.pitch * 12 + .init(note.pitch),
                               noteHeight: f.height) + f.midY - sh
                let d = y.distance(p.y)
                if d < minD && d < maxD {
                    minNoteI = noteI
                    minPitT = t
                    minD = d
                }
            }
        }
        
        return if let minNoteI, let minPitT {
            (minNoteI, minPitT)
        } else {
            nil
        }
    }
    
    func pitbendTuple(at p: Point,
                      maxDistance maxD: Double) -> (noteI: Int, pitI: Int,
                                                    pit: Pit,
                                                    pitbend: Pitbend)? {
        let score = model
        
        let maxDS = maxD * maxD
        var minNoteI: Int?, minPitI: Int?,
            minPit: Pit?, minPitbend: Pitbend?,
            minDS = Double.infinity
        for noteI in 0 ..< score.notes.count {
            let note = score.notes[noteI]
            let (preFq, nextFq) = pitbendPreNext(notes: score.notes, at: noteI)
            let pitbend = pitbend(from: note, tempo: score.tempo, preFq: preFq, nextFq: nextFq)
            let f = noteFrame(from: note)
            let sh = self.y(fromPitch: note.pitch, noteHeight: f.height)
            for (pitI, pit) in pitbend.pits.enumerated() {
                let pitP = Point(pit.t * f.width + f.minX,
                                 y(fromPitch: pit.pitch * 12 + .init(note.pitch),
                                   noteHeight: f.height) + f.midY - sh)
                let ds = pitP.distanceSquared(p)
                if ds < minDS && ds < maxDS {
                    minNoteI = noteI
                    minPitI = pitI
                    minPit = pit
                    minPitbend = pitbend
                    minDS = ds
                }
            }
        }
        
        return if let minNoteI, let minPitI, let minPit, let minPitbend {
            (minNoteI, minPitI, minPit, minPitbend)
        } else {
            nil
        }
    }
    
    func noteIndex(at p: Point, maxDistance: Double) -> Int? {
        let score = model
        let sBeat = max(score.beatRange.start, -10000),
            eBeat = min(score.beatRange.end, 10000)
        guard sBeat <= eBeat else { return nil }
        let nh = noteHeight
        let beat = score.beatRange.start
        let preBeat = max(beat, sBeat)
        let nextBeat = min(beat + score.beatRange.length, eBeat)
        
        let maxDS = maxDistance * maxDistance
        var minI: Int?, minDS = Double.infinity
        for (i, note) in score.notes.enumerated() {
            guard Score.pitchRange.contains(note.pitch) else { continue }
            var beatRange = note.beatRange
            beatRange.start += beat
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
            
            let sh = y(fromPitch: note.pitch, noteHeight: nh)
            let nx = x(atBeat: beatRange.start)
            let nw = beatRange.length == 0 ?
                width(atBeatDuration: Rational(1, 96)) :
                x(atBeat: beatRange.end) - nx
            let noteF = Rect(x: nx, y: sh, width: nw, height: nh)
            
            let ds = noteF.distanceSquared(p)
            if ds < minDS && ds < maxDS {
                minDS = ds
                minI = i
            }
        }
        return minI
    }
}
