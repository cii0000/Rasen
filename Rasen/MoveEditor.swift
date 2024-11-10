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

final class MoveEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
    }
    
    enum MoveType {
        case animation(MoveAnimationEditor)
        case line(MoveLineEditor)
        case score(MoveScoreEditor)
        case content(MoveContentEditor)
        case text(MoveTextEditor)
        case tempo(MoveTempoEditor)
        case none
    }
    private var type = MoveType.none
    
    func updateNode() {
        switch type {
        case .animation(let editor): editor.updateNode()
        case .line(let editor): editor.updateNode()
        case .score(let editor): editor.updateNode()
        case .content(let editor): editor.updateNode()
        case .text(let editor): editor.updateNode()
        case .tempo(let editor): editor.updateNode()
        case .none: break
        }
    }
    
    func send(_ event: DragEvent) {
        if event.phase == .began {
            let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor ?? event.screenPoint
            let p = rootView.convertScreenToWorld(sp)
            
            if let sheetView = rootView.sheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                if sheetView.containsTempo(sheetP, maxDistance: rootView.worldKnobEditDistance * 0.5) {
                    type = .tempo(MoveTempoEditor(rootEditor))
                } else if sheetView.contentIndex(at: sheetP, scale: rootView.screenToWorldScale) != nil {
                    type = .content(MoveContentEditor(rootEditor))
                } else if sheetView.textIndex(at: sheetP, scale: rootView.screenToWorldScale) != nil {
                    type = .text(MoveTextEditor(rootEditor))
                } else if sheetView.scoreView.contains(sheetView.scoreView.convertFromWorld(p),
                                                       scale: rootView.screenToWorldScale) {
                    type = .score(MoveScoreEditor(rootEditor))
                } else if sheetView.lineTuple(at: sheetP,
                                              isSmall: false,
                                              scale: rootView.screenToWorldScale) != nil {
                    type = .line(MoveLineEditor(rootEditor))
                } else if sheetView.animationView.containsTimeline(sheetP, scale: rootView.screenToWorldScale) {
                    type = .animation(MoveAnimationEditor(rootEditor))
                }
            }
        }
        
        switch type {
        case .animation(let editor):
            editor.send(event)
        case .line(let editor):
            editor.send(event)
        case .score(let editor):
            editor.send(event)
        case .content(let editor):
            editor.send(event)
        case .text(let editor):
            editor.send(event)
        case .tempo(let editor):
            editor.send(event)
        case .none:
            switch event.phase {
            case .began:
                rootView.cursor = .arrow
            case .changed: break
            case .ended:
                rootView.cursor = rootView.defaultCursor
            }
        }
    }
}

final class MoveAnimationEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum SlideType {
        case key, all, startBeat, endBeat, none
    }
    
    private let indexInterval = 10.0
    
    private var node = Node()
    private var sheetView: SheetView?, animationIndex = 0, keyframeIndex = 0
    private var type = SlideType.key
    private var beganSP = Point(), beganSheetP = Point(), beganKeyframeOptions = [Int: KeyframeOption](),
                beganTimelineX = 0.0, beganKeyframeX = 0.0, beganBeatX = 0.0,
                beganKeyframeBeat = Rational(0)
    private var beganAnimationOption: AnimationOption?
    private var minLastSec = 1 / 12.0
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }
        
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.enabledAnimation {
                beganSP = sp
                self.sheetView = sheetView
                let inP = sheetView.convertFromWorld(p)
                beganSheetP = inP
                beganTimelineX = sheetView.animationView
                    .x(atBeat: sheetView.animationView.model.beatRange.start)
                if sheetView.animationView.containsTimeline(inP, scale: rootView.screenToWorldScale) {
                    let animationView = sheetView.animationView
                    
                    if animationView.isEndBeat(at: inP, scale: rootView.screenToWorldScale) {
                        type = .endBeat
                        
                        beganAnimationOption = sheetView.model.animation.option
                        beganBeatX = animationView.x(atBeat: sheetView.model.animation.beatRange.end)
                    } else if let minI = animationView
                        .slidableKeyframeIndex(at: inP,
                                               maxDistance: rootView.worldKnobEditDistance,
                                               enabledKeyOnly: true) {
                        type = .key
                        
                        keyframeIndex = minI
                        let keyframe = animationView.model.keyframes[keyframeIndex]
                        beganKeyframeBeat = keyframe.beat
                        beganKeyframeX = animationView.x(atBeat: animationView.model.localBeat(at: minI))
                        
                        if !animationView.selectedFrameIndexes.isEmpty
                            && animationView.selectedFrameIndexes.contains(keyframeIndex) {
                            
                            beganKeyframeOptions = animationView.selectedFrameIndexes.reduce(into: .init()) {
                                $0[$1] = animationView.model.keyframes[$1].option
                            }
                        } else {
                            beganKeyframeOptions = [keyframeIndex: keyframe.option]
                        }
                    } else {
                        beganAnimationOption = sheetView.model.animation.option
                        type = .all
                    }
                }
            }
        case .changed:
            if let sheetView = sheetView {
                let animationView = sheetView.animationView
                let sheetP = sheetView.convertFromWorld(p)
                
                switch type {
                case .all:
                    let nh = Sheet.pitchHeight
                    let np = beganTimelineX + sheetP - beganSheetP
                    let py = ((beganAnimationOption?.timelineY ?? 0) + sheetP.y - beganSheetP.y).interval(scale: nh)
                        .clipped(min: Sheet.timelineY, max: sheetView.bounds.height - Sheet.timelineY)
                    let interval = rootView.currentBeatInterval
                    let beat = max(min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - sheetView.animationView.model.beatRange.length)
                    if py != sheetView.animationView.timelineY
                        || beat != sheetView.model.animation.beatRange.start {
                        
                        sheetView.binder[keyPath: sheetView.keyPath].animation.beatRange.start = beat
                        sheetView.binder[keyPath: sheetView.keyPath].animation.timelineY = py
                        sheetView.animationView.updateTimeline()
                    }
                case .startBeat:
                    let interval = rootView.currentKeyframeBeatInterval
                    let beat = animationView.beat(atX: sheetP.x,
                                                  interval: interval) + sheetView.model.animation.beatRange.start
                    if beat != sheetView.model.animation.beatRange.start {
                        sheetView.binder[keyPath: sheetView.keyPath]
                            .animation.beatRange.start = beat
                        
                        sheetView.animationView.updateTimeline()
                    }
                case .endBeat:
                    if let beganAnimationOption {
                        let interval = rootView.currentBeatInterval
                        let nBeat = animationView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                       interval: interval)
                        if nBeat != animationView.beatRange?.end {
                            let dBeat = nBeat - beganAnimationOption.beatRange.end
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganAnimationOption.beatRange.end + dBeat, startBeat)
                            
                            animationView.beatRange?.end = nkBeat
                        }
                    }
                case .key:
                    let interval = rootView.currentKeyframeBeatInterval
                    let durBeat = animationView.model.beatRange.length
                    let beat = animationView.beat(atX: beganKeyframeX + sheetP.x - beganSheetP.x, interval: interval)
                        .clipped(min: 0, max: durBeat)
                    let oldBeat = animationView.model.keyframes[keyframeIndex].beat
                    if oldBeat != beat && !beganKeyframeOptions.isEmpty {
                        let rootBeatIndex = animationView.model.rootBeatIndex
                        
                        let dBeat = beat - beganKeyframeBeat
                        let kos = beganKeyframeOptions.sorted { $0.key < $1.key }
                        func clippedDBeat() -> Rational {
                            let keyframes = animationView.model.keyframes
                            var preI = 0, minPreDBeat = Rational.max, minNextDBeat = Rational.max
                            while preI < kos.count {
                                var nextI = preI
                                while nextI + 1 < kos.count {
                                    if nextI + 1 < kos.count && kos[nextI].key + 1 != kos[nextI + 1].key { break }
                                    nextI += 1
                                }
                                let preKI = kos[preI].key, nextKI = kos[nextI].key
                                let preDBeat = kos[preI].value.beat - (preKI - 1 >= 0 ? keyframes[preKI - 1].beat : 0)
                                let nextDBeat = (nextKI + 1 < keyframes.count ? keyframes[nextKI + 1].beat : durBeat) - kos[nextI].value.beat
                                minPreDBeat = min(preDBeat, minPreDBeat)
                                minNextDBeat = min(nextDBeat, minNextDBeat)
                                
                                preI = nextI + 1
                            }
                            return dBeat.clipped(min: -minPreDBeat, max: minNextDBeat)
                        }
                        let nDBeat = clippedDBeat()
                        kos.forEach {
                            sheetView.binder[keyPath: sheetView.keyPath].animation
                                .keyframes[$0.key].beat = $0.value.beat + nDBeat
                        }
                        
                        sheetView.rootBeatIndex = rootBeatIndex
                        sheetView.animationView.updateTimeline()
                    }
                case .none: break
                }
            }
        case .ended:
            node.removeFromParent()
            
            if let sheetView = sheetView {
                var isNewUndoGroup = false
                func updateUndoGroup() {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
                }
                switch type {
                case .all, .startBeat, .endBeat:
                    if let beganAnimationOption, sheetView.model.animation.option != beganAnimationOption {
                        updateUndoGroup()
                        sheetView.capture(option: sheetView.model.animation.option,
                                          oldOption: beganAnimationOption)
                    }
                case .key:
                    let animationView = sheetView.animationView
                    let okos = beganKeyframeOptions
                        .filter { animationView.model.keyframes[$0.key].option != $0.value }
                        .sorted { $0.key < $1.key }
                        .map { IndexValue(value: $0.value, index: $0.key) }
                    if !okos.isEmpty {
                        let kos = okos.map {
                            IndexValue(value: animationView.model.keyframes[$0.index].option, index: $0.index)
                        }
                        updateUndoGroup()
                        sheetView.capture(kos, old: okos)
                    }
                case .none: break
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveScoreEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum SlideType {
        case keyBeats, allBeat, endBeat, isShownSpectrogram,
             startNoteBeat, endNoteBeat, note,
             pit, reverbEarlyRSec, reverbEarlyAndLateRSec, reverbDurSec, even, sprol
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
    private var beganStartBeat = Rational(0), beganPitch = Rational(0),  beganBeatX = 0.0, beganPitchY = 0.0
    private var beganTone = Tone(), beganOvertone = Overtone(), beganEnvelope = Envelope()
    private var sprolI: Int?, beganSprol = Sprol()
    private var beganScoreOption: ScoreOption?
    private var beganNotes = [Int: Note]()
    private var beganNote: Note?, beganPit: Pit?, beganBeat = Rational(0)
    private var beganNotePits = [Int: (note: Note, pit: Pit, pits: [Int: Pit])]()
    private var beganSprolPitch = 0.0, beganSpectlopeY = 0.0
    private var beganNoteSprols = [UUID: (nid: UUID, dic: [Int: (note: Note, pits: [Int: (pit: Pit, sprolIs: Set<Int>)])])]()
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if rootEditor.isPlaying(with: event) {
                rootEditor.stopPlaying(with: event)
            }
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
                let sheetP = sheetView.convertFromWorld(p)
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                
                beganSP = sp
                beganSheetP = sheetP
                self.sheetView = sheetView
                beganTime = sheetView.animationView.beat(atX: sheetP.x)
                
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
                
                let scoreP = scoreView.convert(sheetP, from: sheetView.node)
                if scoreView.containsIsShownSpectrogram(scoreP, scale: rootView.screenToWorldScale) {
                    type = .isShownSpectrogram
                    
                    beganScoreOption = scoreView.model.option
                } else if let keyBeatI = scoreView.keyBeatIndex(at: scoreP, scale: rootView.screenToWorldScale) {
                    type = .keyBeats
                    
                    self.keyBeatI = keyBeatI
                    beganScoreOption = score.option
                    beganBeatX = scoreView.x(atBeat: score.keyBeats[keyBeatI])
                } else if abs(scoreP.x - scoreView.x(atBeat: score.beatRange.end)) < rootView.worldKnobEditDistance
                            && abs(scoreP.y - scoreView.timelineCenterY) < Sheet.timelineHalfHeight {
                    type = .endBeat
                    
                    beganScoreOption = sheetView.model.score.option
                    beganBeatX = scoreView.x(atBeat: score.beatRange.end)
                } else if scoreView.containsTimeline(scoreP, scale: rootView.screenToWorldScale) {
                    type = .allBeat
                    
                    beganScoreOption = sheetView.model.score.option
                    beganBeatX = scoreView.x(atBeat: score.beatRange.start)
                } else if let (noteI, result) = scoreView.hitTestPoint(scoreP, scale: rootView.screenToWorldScale) {
                    self.noteI = noteI
                    
                    let score = scoreView.model
                    let note = score.notes[noteI]
                    let interval = rootView.currentBeatInterval
                    let nsBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                    beganStartBeat = nsBeat
                    beganSheetP = sheetP
                    beganSP = sp
                    beganNote = note
                    
                    switch result {
                    case .pit(let pitI):
                        type = .pit
                        
                        let pit = note.pits[pitI]
                        self.pitI = pitI
                        beganPit = pit
                        
                        beganPitch = note.pitch + pit.pitch
                        oldPitch = beganPitch
                        beganBeat = note.beatRange.start + pit.beat
                        oldBeat = beganBeat
                        beganBeatX = scoreView.x(atBeat: note.beatRange.start + pit.beat)
                        beganPitchY = scoreView.y(fromPitch: note.pitch + pit.pitch)
                        
                        var noteAndPitIs: [Int: [Int]]
                        if rootView.isSelect(at: p) {
                            noteAndPitIs = sheetView.noteAndPitIndexes(from: rootView.selections,
                                                                       enabledAll: false)
                            if noteAndPitIs[noteI] != nil {
                                if !noteAndPitIs[noteI]!.contains(pitI) {
                                    noteAndPitIs[noteI]?.append(pitI)
                                }
                            } else {
                                noteAndPitIs[noteI] = [pitI]
                            }
                        } else {
                            noteAndPitIs = [noteI: [pitI]]
                        }
                        
                        beganNotePits = noteAndPitIs.reduce(into: .init()) { (nv, nap) in
                            let pitDic = nap.value.reduce(into: [Int: Pit]()) { (v, pitI) in
                                v[pitI] = score.notes[nap.key].pits[pitI]
                            }
                            nv[nap.key] = (score.notes[nap.key], pit, pitDic)
                        }
                        
                        let vs = score.noteIAndNormarizedPits(atBeat: pit.beat + note.beatRange.start,
                                                              in: Set(beganNotePits.keys).sorted())
                        playerBeatNoteIndexes = vs.map { $0.noteI }
                        
                        updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                        
                        let octaveNode = scoreView.octaveNode(fromPitch: note.pitch,
                                                              noteIs: [noteI],
                                                              .octave)
                        octaveNode.attitude.position
                        = sheetView.convertToWorld(scoreView.node.attitude.position)
                        self.octaveNode = octaveNode
                        rootView.node.append(child: octaveNode)
                                                 
                        rootView.cursor = .circle(string: Pitch(value: beganPitch).octaveString())
                        
                    case .reverbEarlyRSec:
                        type = .reverbEarlyRSec
                        
                        if rootView.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: rootView.selections)
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
                    case .reverbEarlyAndLateRSec:
                        type = .reverbEarlyAndLateRSec
                        
                        if rootView.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: rootView.selections)
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
                    case .reverbDurSec:
                        type = .reverbDurSec
                        
                        if rootView.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: rootView.selections)
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
                    case .even(let pitI):
                        type = .even
                        
                        let pit = note.pits[pitI]
                    
                        self.pitI = pitI
                        beganPit = pit
                        
                        beganBeat = note.beatRange.start + pit.beat
                        oldBeat = beganBeat
                        beganBeatX = scoreView.x(atBeat: note.beatRange.start + pit.beat)
                        
                        var noteAndPitIs: [Int: [Int]]
                        if rootView.isSelect(at: p) {
                            noteAndPitIs = sheetView.noteAndPitIndexes(from: rootView.selections,
                                                                       enabledAll: false)
                            if noteAndPitIs[noteI] != nil {
                                if !noteAndPitIs[noteI]!.contains(pitI) {
                                    noteAndPitIs[noteI]?.append(pitI)
                                }
                            } else {
                                noteAndPitIs[noteI] = [pitI]
                            }
                        } else {
                            noteAndPitIs = [noteI: [pitI]]
                        }
                        
                        beganNotePits = noteAndPitIs.reduce(into: .init()) { (nv, nap) in
                            let pitDic = nap.value.reduce(into: [Int: Pit]()) { (v, pitI) in
                                v[pitI] = score.notes[nap.key].pits[pitI]
                            }
                            nv[nap.key] = (score.notes[nap.key], pit, pitDic)
                        }
                    case .sprol(let pitI, let sprolI, let spectlopeY):
                        type = .sprol
                        
                        beganTone = score.notes[noteI].pits[pitI].tone
                        self.sprolI = sprolI
                        self.beganSpectlopeY = spectlopeY
                        self.beganSprol = beganTone.spectlope.sprols[sprolI]
//                        self.beganSprol = scoreView.nearestSprol(at: scoreP, at: noteI)
                        self.beganSprolPitch = scoreView.spectlopePitch(at: scoreP, at: noteI, y: spectlopeY)
                        self.noteI = noteI
                        self.pitI = pitI
                        
                        func updatePitsWithSelection() {
                            var noteAndPitIs: [Int: [Int: Set<Int>]]
                            if rootView.isSelect(at: p) {
                                noteAndPitIs = sheetView.noteAndPitAndSprolIs(from: rootView.selections)
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
                            
                            beganNoteSprols = noteAndPitIs.reduce(into: .init()) {
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
                                        $0[id] = (UUID(), [$1.key: (score.notes[$1.key], [pitI: (pit, sprolIs)])])
                                    }
                                }
                            }
                        }
                        
                        updatePitsWithSelection()
                        
                        let noteIsSet = Set(beganNoteSprols.values.flatMap { $0.dic.keys }).sorted()
                        let vs = score.noteIAndNormarizedPits(atBeat: note.pits[pitI].beat + note.beatRange.start,
                                                              in: noteIsSet)
                        playerBeatNoteIndexes = vs.map { $0.noteI }
                        
                        updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                        
                        rootView.cursor = .circle(string: Pitch(value: .init(beganTone.spectlope.sprols[sprolI].pitch, intervalScale: Sheet.fullEditPitchInterval)).octaveString(hidableDecimal: false))
                    }
                } else if let noteI = scoreView.noteIndex(at: scoreP, scale: rootView.screenToWorldScale) {
                    let note = score.notes[noteI]
                    self.noteI = noteI
                    
                    let nsx = scoreView.x(atBeat: note.beatRange.start)
                    let nex = scoreView.x(atBeat: note.beatRange.end)
                    let nsy = scoreView.noteY(atBeat: note.beatRange.start, from: note)
                    let ney = scoreView.noteY(atBeat: note.beatRange.end, from: note)
                    let nfsw = (nex - nsx) * rootView.worldToScreenScale
                    let dx = nfsw.clipped(min: 3, max: 30, newMin: 1, newMax: 8)
                    * rootView.screenToWorldScale
                    
                    type = if scoreP.x - nsx < dx && abs(scoreP.y - nsy) < dx {
                        .startNoteBeat
                    } else if scoreP.x - nex > -dx && abs(scoreP.y - ney) < dx {
                        .endNoteBeat
                    } else {
                        .note
                    }
                    
                    let interval = rootView.currentBeatInterval
                    let nsBeat = scoreView.beat(atX: sheetP.x, interval: interval)
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
                    
                    if rootView.isSelect(at: p) {
                        let noteIs = sheetView.noteIndexes(from: rootView.selections)
                        beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                    }
                    beganNotes[noteI] = score.notes[noteI]
                    
                    let playerBeat: Rational = switch type {
                    case .startNoteBeat: note.beatRange.start
                    case .endNoteBeat: note.beatRange.end
                    default: scoreView.beat(atX: scoreP.x)
                    }
                    let vs = score.noteIAndNormarizedPits(atBeat: playerBeat,
                                                          in: Set(beganNotes.keys).sorted())
                    playerBeatNoteIndexes = vs.map { $0.noteI }
                    
                    updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                    
                    let octaveNode = scoreView.octaveNode(fromPitch: note.pitch,
                                                          noteIs: beganNotes.keys.sorted(),
                                                          .octave)
                    octaveNode.attitude.position
                    = sheetView.convertToWorld(scoreView.node.attitude.position)
                    self.octaveNode = octaveNode
                    rootView.node.append(child: octaveNode)
                    
                    let result = note.pitResult(atBeat: Double(nsBeat - note.beatRange.start))
                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                    rootView.cursor = .circle(string: Pitch(value: cPitch).octaveString())
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
                    if let beganBeatRange {
                        let beatInterval = rootView.currentBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: rootView.currentPitchInterval)
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
                                    scoreView.normarizedPitResult(atBeat: nsBeat, at: $0)
                                }
                                oldPitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(nsBeat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                                    rootView.cursor = .circle(string: Pitch(value: cPitch).octaveString(deltaPitch: dPitch))
                                }
                            }
                            rootView.updateSelects()
                        }
                    }
                case .endNoteBeat:
                    if let beganBeatRange {
                        let beatInterval = rootView.currentBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: rootView.currentPitchInterval)
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
                                    scoreView.normarizedPitResult(atBeat: neBeat, at: $0)
                                }
                                oldPitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(neBeat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                                    rootView.cursor = .circle(string: Pitch(value: cPitch).octaveString(deltaPitch: dPitch))
                                }
                            }
                            rootView.updateSelects()
                        }
                    }
                case .note:
                    if let beganBeatRange {
                        let beatInterval = rootView.currentBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: rootView.currentPitchInterval)
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
                                    scoreView.normarizedPitResult(atBeat: beat, at: $0)
                                }
                                oldPitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(beat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: Sheet.fullEditBeatInterval)
                                    rootView.cursor = .circle(string: Pitch(value: cPitch).octaveString(deltaPitch: dPitch))
                                }
                            }
                            rootView.updateSelects()
                        }
                    }
                    
                case .keyBeats:
                    if let keyBeatI, keyBeatI < score.keyBeats.count, let beganScoreOption {
                        let interval = rootView.currentBeatInterval
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
                            rootView.updateSelects()
                        }
                    }
                case .allBeat:
                    let nh = Sheet.pitchHeight
                    let np = beganBeatX + sheetP - beganSheetP
                    let py = ((beganScoreOption?.timelineY ?? 0) + sheetP.y - beganSheetP.y).interval(scale: nh)
                        .clipped(min: Sheet.timelineY, max: sheetView.bounds.height - Sheet.timelineY)
                    let interval = rootView.currentBeatInterval
                    let beat = max(min(scoreView.beat(atX: np.x, interval: interval),
                                   scoreView.beat(atX: scoreView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   scoreView.beat(atX: Sheet.textPadding.width, interval: interval) - scoreView.model.beatRange.length)
                    if py != scoreView.timelineY
                        || beat != scoreView.model.beatRange.start {
                        
                        var option = scoreView.option
                        option.beatRange.start = beat
                        option.timelineY = py
                        scoreView.option = option
                        rootView.updateSelects()
                    }
                case .endBeat:
                    if let beganScoreOption {
                        let interval = rootView.currentBeatInterval
                        let nBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                   interval: interval)
                        if nBeat != oldBeat {
                            let dBeat = nBeat - beganScoreOption.beatRange.end
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganScoreOption.beatRange.end + dBeat, startBeat)
                            
                            oldBeat = nkBeat
                            scoreView.option.beatRange.end = nkBeat
                            rootView.updateSelects()
                        }
                    }
                case .isShownSpectrogram:
                    let scoreP = scoreView.convertFromWorld(p)
                    let isShownSpectrogram = scoreView.isShownSpectrogram(at: scoreP)
                    scoreView.isShownSpectrogram = isShownSpectrogram
                    
                case .pit:
                    if let noteI, noteI < score.notes.count, let pitI {
                        let note = score.notes[noteI]
                        let preBeat = pitI > 0 ? note.pits[pitI - 1].beat + note.beatRange.start : .min
                        let nextBeat = pitI + 1 < note.pits.count ? note.pits[pitI + 1].beat + note.beatRange.start : .max
                        let beatInterval = rootView.currentBeatInterval
                        let pitchInterval = rootView.currentPitchInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: pitchInterval)
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                            .clipped(min: preBeat, max: nextBeat)
                        if pitch != oldPitch || nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeat
                            let dPitch = pitch - beganPitch
                            
                            for (noteI, nv) in beganNotePits {
                                guard noteI < score.notes.count else { continue }
                                var note = nv.note
                                for (pitI, beganPit) in nv.pits {
                                    guard pitI < score.notes[noteI].pits.count else { continue }
                                    note.pits[pitI].beat = dBeat + beganPit.beat
                                    note.pits[pitI].pitch = dPitch + beganPit.pitch
                                }
                                if nv.pits[0] != nil {
                                    let dBeat = note.pits.first!.beat
                                    if nv.note.beatRange.length - dBeat <= 0 {
                                        note.beatRange.start = nv.note.beatRange.end
                                        note.beatRange.length = 0
                                        for i in note.pits.count.range {
                                            note.pits[i].beat -= nv.note.beatRange.length
                                        }
                                    } else {
                                        note.beatRange.start = nv.note.beatRange.start + dBeat
                                        note.beatRange.length = nv.note.beatRange.length - dBeat
                                        for i in note.pits.count.range {
                                            note.pits[i].beat -= dBeat
                                        }
                                    }
                                } else {
                                    if note.pits.last!.beat > note.beatRange.length {
                                        note.beatRange.length = note.pits.last!.beat
                                    } else {
                                        note.beatRange.length = nv.note.beatRange.length
                                    }
                                }
                                
                                scoreView[noteI] = note
                            }
                            
                            oldBeat = nsBeat
                            
                            octaveNode?.children = scoreView.octaveNode(fromPitch: pitch,
                                                                        noteIs: [noteI],
                                                                        .octave).children
                            
                            if pitch != oldPitch {
                                let note = scoreView[noteI]
                                let pBeat = note.pits[pitI].beat + note.beatRange.start
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.normarizedPitResult(atBeat: pBeat, at: $0)
                                }
                                
                                oldPitch = pitch
                                
                                rootView.cursor = .circle(string: Pitch(value: pitch).octaveString())
                            }
                            rootView.updateSelects()
                        }
                    }
                case .reverbEarlyRSec:
                    let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                    let sec = (beganEnvelope.reverb.earlySec + score.sec(fromBeat: dBeat))
                        .clipped(min: 0.02, max: 10)
                    
                    let nid = UUID()
                    var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                    for noteI in beganNotes.keys {
                        guard noteI < score.notes.count else { continue }
                        var envelope = scoreView.model.notes[noteI].envelope
                        envelope.reverb.earlySec = sec
                        envelope.reverb.seedID = nid
                        envelope.id = nid
                        eivs.append(.init(value: envelope, index: noteI))
                    }
                    scoreView.replace(eivs)
                case .reverbEarlyAndLateRSec:
                    let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                    let sec = (beganEnvelope.reverb.lateSec + score.sec(fromBeat: dBeat))
                        .clipped(min: 0, max: 10)
                    
                    let nid = UUID()
                    var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                    for noteI in beganNotes.keys {
                        guard noteI < score.notes.count else { continue }
                        var envelope = scoreView.model.notes[noteI].envelope
                        envelope.reverb.lateSec = sec
                        envelope.reverb.seedID = nid
                        envelope.id = nid
                        eivs.append(.init(value: envelope, index: noteI))
                    }
                    scoreView.replace(eivs)
                case .reverbDurSec:
                    let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                    let sec = (beganEnvelope.reverb.releaseSec + score.sec(fromBeat: dBeat))
                        .clipped(min: 0, max: 10)
                    
                    let nid = UUID()
                    var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                    for noteI in beganNotes.keys {
                        guard noteI < score.notes.count else { continue }
                        var envelope = scoreView.model.notes[noteI].envelope
                        envelope.reverb.releaseSec = sec
                        envelope.reverb.seedID = nid
                        envelope.id = nid
                        eivs.append(.init(value: envelope, index: noteI))
                    }
                    scoreView.replace(eivs)
                case .even:
                    if let noteI, noteI < score.notes.count, let pitI {
                        let note = score.notes[noteI]
                        let preBeat = pitI > 0 ? note.pits[pitI - 1].beat + note.beatRange.start : .min
                        let nextBeat = pitI + 1 < note.pits.count ? note.pits[pitI + 1].beat + note.beatRange.start : .max
                        let beatInterval = rootView.currentBeatInterval
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                            .clipped(min: preBeat, max: nextBeat)
                        if nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeat
                            
                            for (noteI, nv) in beganNotePits {
                                guard noteI < score.notes.count else { continue }
                                var note = nv.note
                                for (pitI, beganPit) in nv.pits {
                                    guard pitI < score.notes[noteI].pits.count else { continue }
                                    note.pits[pitI].beat = dBeat + beganPit.beat
                                }
                                if note.pits.first!.beat < 0 {
                                    let dBeat = note.pits.first!.beat
                                    note.beatRange.start = nv.note.beatRange.start + dBeat
                                    note.beatRange.length = nv.note.beatRange.length - dBeat
                                    for i in note.pits.count.range {
                                        note.pits[i].beat -= dBeat
                                    }
                                } else {
                                    if note.pits.last!.beat > note.beatRange.length {
                                        note.beatRange.length = note.pits.last!.beat
                                    } else {
                                        note.beatRange.length = nv.note.beatRange.length
                                    }
                                }
                                
                                scoreView[noteI] = note
                            }
                            
                            oldBeat = nsBeat
                            
                            rootView.updateSelects()
                        }
                    }
                case .sprol:
                    if let noteI, noteI < score.notes.count,
                       let pitI, pitI < score.notes[noteI].pits.count,
                       let sprolI, sprolI < score.notes[noteI].pits[pitI].tone.spectlope.count {
                       
                        let pitch = scoreView.spectlopePitch(at: scoreP, at: noteI, y: beganSpectlopeY)
                        let dPitch = pitch - beganSprolPitch
                        let nPitch = (beganTone.spectlope.sprols[sprolI].pitch + dPitch)
                            .clipped(min: Score.doubleMinPitch, max: Score.doubleMaxPitch)
                        
                        var nvs = [Int: Note]()
                        for (_, v) in beganNoteSprols {
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
                                    nvs[noteI]?.pits[pitI].tone.id = v.nid
                                }
                            }
                        }
                        let nivs = nvs.map { IndexValue(value: $0.value, index: $0.key) }
                        scoreView.replace(nivs)
                        
                        notePlayer?.notes = playerBeatNoteIndexes.map {
                            scoreView.normarizedPitResult(atBeat: beganStartBeat, at: $0)
                        }
                        
                        rootView.cursor = .circle(string: Pitch(value: .init(nPitch, intervalScale: Sheet.fullEditPitchInterval)).octaveString(hidableDecimal: false))
                    }
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
                            $0[$1.key] = $1.value.note
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
                    
                    if !beganNoteSprols.isEmpty {
                        let scoreView = sheetView.scoreView
                        let score = scoreView.model
                        var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                        
                        let beganNoteIAndNotes = beganNoteSprols.reduce(into: [Int: Note]()) {
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
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveContentEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum SlideType {
        case all, startBeat, endBeat, isShownSpectrogram, position
    }
    
    private var contentView: SheetContentView? {
        guard let sheetView, let contentI,
              contentI < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentI]
    }
    private var beganContentBeat: Rational = 0, oldContentBeat: Rational = 0
    private let indexInterval = 10.0
    private var oldDeltaI: Int?
    
    private var sheetView: SheetView?, contentI: Int?, beganContent: Content?
    private var type = SlideType.all
    private var beganSP = Point(), beganInP = Point(), beganContentEndP = Point()
    
    private var beganIsShownSpectrogram = false
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = Cursor.arrow
            
            if rootEditor.isPlaying(with: event) {
                rootEditor.stopPlaying(with: event)
            }
            
            if let sheetView = rootView.sheetView(at: p),
                let ci = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                scale: rootView.screenToWorldScale) {
                
                let sheetP = sheetView.convertFromWorld(p)
                let contentView = sheetView.contentsView.elementViews[ci]
                let content = contentView.model
                let contentP = contentView.convertFromWorld(p)
                
                beganSP = sp
                beganInP = sheetP
                self.sheetView = sheetView
                beganContent = content
                if let timeOption = content.timeOption {
                    beganContentEndP = .init(sheetView.animationView.x(atBeat: timeOption.beatRange.end), content.origin.y)
                }
                contentI = ci
                
                let maxMD = 10 * rootView.screenToWorldScale
                
                if contentView.containsIsShownSpectrogram(contentP, scale: rootView.screenToWorldScale) {
                    type = .isShownSpectrogram
                    beganIsShownSpectrogram = contentView.model.isShownSpectrogram
                    contentView.updateSpectrogram()
                } else if let timeOption = content.timeOption {
                    if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.start)) < maxMD {
                        type = .startBeat
                    } else if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.end)) < maxMD {
                        type = .endBeat
                    } else {
                        type = .all
                    }
                } else {
                    type = .position
                }
            }
        case .changed:
            if let sheetView, let beganContent,
               let contentI, contentI < sheetView.contentsView.elementViews.count {
                
                let sheetP = sheetView.convertFromWorld(p)
                let contentView = sheetView.contentsView.elementViews[contentI]
                let content = contentView.model
                
                switch type {
                case .all:
                    let nh = Sheet.pitchHeight
                    let np = beganContent.origin + sheetP - beganInP
                    let interval = rootView.currentBeatInterval
                    let beat = max(min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - (content.timeOption?.beatRange.length ?? 0))
                    var timeOption = content.timeOption
                    timeOption?.beatRange.start = beat
                    let timelineY = np.y.interval(scale: nh)
                        .clipped(min: Sheet.timelineY, max: sheetView.bounds.height - Sheet.timelineY)
                    contentView.set(timeOption, origin: Point(sheetView.animationView.x(atBeat: beat), timelineY))
                    rootView.updateSelects()
                case .startBeat:
                    if var timeOption = content.timeOption {
                        let np = beganContent.origin + sheetP - beganInP
                        let interval = rootView.currentBeatInterval
                        let beat = min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.end)
                        if beat != timeOption.beatRange.start {
                            let dBeat = timeOption.beatRange.start - beat
                            if content.type.hasDur {
                                timeOption.localStartBeat += dBeat
                            }
                            timeOption.beatRange.start -= dBeat
                            timeOption.beatRange.length += dBeat
                            contentView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), content.origin.y))
                            rootView.updateSelects()
                        }
                    }
                case .endBeat:
                    if var timeOption = content.timeOption {
                        let np = beganContentEndP + sheetP - beganInP
                        let interval = rootView.currentBeatInterval
                        let beat = max(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.start)
                        if beat != timeOption.beatRange.end {
                            timeOption.beatRange.end = beat
                            contentView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), content.origin.y))
                            rootView.updateSelects()
                        }
                    }
                case .isShownSpectrogram:
                    let contentP = contentView.convertFromWorld(p)
                    let isShownSpectrogram = contentView.isShownSpectrogram(at: contentP)
                    contentView.isShownSpectrogram = isShownSpectrogram
                case .position:
                    let np = beganContent.origin + sheetP - beganInP
                    let maxBounds = Sheet.defaultBounds.inset(by: Sheet.textPadding)
                    let nnp = maxBounds.clipped(Rect(origin: np, size: content.size)).origin
                    contentView.origin = nnp
                    rootView.updateSelects()
                }
            }
        case .ended:
            if let sheetView, let beganContent,
               let contentI, contentI < sheetView.contentsView.elementViews.count {
               
                let contentView = sheetView.contentsView.elementViews[contentI]
                if contentView.model != beganContent {
                    sheetView.newUndoGroup()
                    sheetView.capture(contentView.model, old: beganContent, at: contentI)
                }
                if type == .all || type == .startBeat || type == .endBeat {
                    sheetView.updatePlaying()
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveTextEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum SlideType {
        case all, startBeat, endBeat, position
    }
    
    private var sheetView: SheetView?, textI: Int?, beganText: Text?
    private var type = SlideType.all
    private var beganSP = Point(), beganInP = Point(), beganTextEndP = Point()
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.sheetView(at: p),
               let ci = sheetView.textIndex(at: sheetView.convertFromWorld(p),
                                            scale: rootView.screenToWorldScale) {
                
                let sheetP = sheetView.convertFromWorld(p)
                let textView = sheetView.textsView.elementViews[ci]
                let text = textView.model
                
                beganSP = sp
                beganInP = sheetP
                self.sheetView = sheetView
                beganText = text
                if let timeOption = text.timeOption {
                    beganTextEndP = .init(sheetView.animationView.x(atBeat: timeOption.beatRange.end), text.origin.y)
                }
                textI = ci
                
                let maxMD = 10 * rootView.screenToWorldScale
                
                if let timeOption = text.timeOption {
                    if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.start)) < maxMD {
                        type = .startBeat
                    } else if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.end)) < maxMD {
                        type = .endBeat
                    } else {
                        type = .all
                    }
                } else {
                    type = .position
                }
            }
        case .changed:
            if let sheetView, let beganText,
               let textI, textI < sheetView.textsView.elementViews.count {
                
                let sheetP = sheetView.convertFromWorld(p)
                let textView = sheetView.textsView.elementViews[textI]
                let text = textView.model
                
                switch type {
                case .all:
                    let np = beganText.origin + sheetP - beganInP
                    let interval = rootView.currentBeatInterval
                    let beat = max(min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - (text.timeOption?.beatRange.length ?? 0))
                    var timeOption = text.timeOption
                    timeOption?.beatRange.start = beat
                    textView.set(timeOption, origin: Point(sheetView.animationView.x(atBeat: beat), np.y))
                    rootView.updateSelects()
                case .startBeat:
                    if var timeOption = text.timeOption {
                        let np = beganText.origin + sheetP - beganInP
                        let interval = rootView.currentBeatInterval
                        let beat = min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.end)
                        if beat != timeOption.beatRange.start {
                            let dBeat = timeOption.beatRange.start - beat
                            timeOption.beatRange.start -= dBeat
                            timeOption.beatRange.length += dBeat
                            textView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), text.origin.y))
                            rootView.updateSelects()
                        }
                    }
                case .endBeat:
                    if let beganTimeOption = beganText.timeOption {
                        let np = beganTextEndP + sheetP - beganInP
                        let interval = rootView.currentBeatInterval
                        let beat = max(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval),
                                       beganTimeOption.beatRange.start)
                        if beat != text.timeOption?.beatRange.end {
                            var beatRange = beganTimeOption.beatRange
                            beatRange.end = beat
                            textView.timeOption?.beatRange = beatRange
                            rootView.updateSelects()
                        }
                    }
                case .position:
                    let np = beganText.origin + sheetP - beganInP
                    let maxBounds = Sheet.defaultBounds.inset(by: Sheet.textPadding)
                    let nnp = maxBounds.clipped(Rect(origin: np, size: text.typesetter.typoBounds?.size ?? .init())).origin
                    textView.origin = nnp
                    rootView.updateSelects()
                }
            }
        case .ended:
            if let sheetView, let beganText,
               let textI, textI < sheetView.textsView.elementViews.count {
               
                let textView = sheetView.textsView.elementViews[textI]
                if textView.model != beganText {
                    sheetView.newUndoGroup()
                    sheetView.capture(textView.model, old: beganText, at: textI)
                }
                sheetView.updatePlaying()
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveTempoEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private let editableTempoInterval = 10.0
    
    private var node = Node()
    private var sheetView: SheetView?
    private var beganSP = Point(), beganSheetP = Point()
    private var beganTempo: Rational = 1, oldTempo: Rational = 1
    private var beganAnimationOption: AnimationOption?, beganScoreOption: ScoreOption?,
                beganContents = [Int: Content](),
                beganTexts = [Int: Text]()
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }
        
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.enabledTimeline {
                beganSP = sp
                self.sheetView = sheetView
                let inP = sheetView.convertFromWorld(p)
                beganSheetP = inP
                if let tempo = sheetView.tempo(at: inP, maxDistance: rootView.worldKnobEditDistance) {
                    beganTempo = tempo
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
                    
                    rootView.cursor = .arrowWith(string: SheetView.tempoString(fromTempo: beganTempo))
                }
            }
        case .changed:
            if let sheetView = sheetView {
                let di = (sp.x - beganSP.x) / editableTempoInterval
                let tempo = Rational(Double(beganTempo) + di, intervalScale: Rational(1, 4))
                    .clipped(Music.tempoRange)
                if tempo != oldTempo {
                    beganContents.forEach {
                        sheetView.contentsView.elementViews[$0.key].tempo = tempo
                    }
                    beganTexts.forEach {
                        sheetView.textsView.elementViews[$0.key].tempo = tempo
                    }
                    if beganAnimationOption != nil {
                        sheetView.animationView.tempo = tempo
                    }
                    if beganScoreOption != nil {
                        sheetView.scoreView.tempo = tempo
                    }
                    
                    rootView.updateSelects()
                    
                    rootView.cursor = .arrowWith(string: SheetView.tempoString(fromTempo: tempo))
                    
                    oldTempo = tempo
                }
            }
        case .ended:
            node.removeFromParent()
            
            if let sheetView = sheetView {
                var isNewUndoGroup = false
                func updateUndoGroup() {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
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
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveLineEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?, lineIndex = 0, pointIndex = 0
    private var beganLine = Line(), beganMainP = Point(), beganSheetP = Point(), isPressure = false
    private var pressures = [(time: Double, pressure: Double)]()
    private var node = Node()
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }

        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.sheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                
                if let (lineView, li) = sheetView.lineTuple(at: sheetP,
                                                                   isSmall: false,
                                                                   scale: rootView.screenToWorldScale),
                          let pi = lineView.model.mainPointSequence.nearestIndex(at: sheetP) {
                    
                    self.sheetView = sheetView
                    beganLine = lineView.model
                    lineIndex = li
                    pointIndex = pi
                    beganMainP = beganLine.mainPoint(at: pi)
                    beganSheetP = sheetP
                    let pressure = event.pressure
                        .clipped(min: 0.4, max: 1, newMin: 0, newMax: 1)
                    pressures.append((event.time, pressure))
                    
                    node.children = beganLine.mainPointSequence.flatMap {
                        let p = sheetView.convertToWorld($0)
                        return [Node(path: .init(circleRadius: 0.25 * 1.5 * beganLine.size, position: p),
                                     fillType: .color(.content)),
                                Node(path: .init(circleRadius: 0.25 * beganLine.size, position: p),
                                     fillType: .color(.background))]
                    }
                    rootView.node.append(child: node)
                }
            }
        case .changed:
            if let sheetView {
                if lineIndex < sheetView.linesView.elementViews.count {
                    let lineView = sheetView.linesView.elementViews[lineIndex]
                    
                    var line = lineView.model
                    if pointIndex < line.mainPointCount {
                        let inP = sheetView.convertFromWorld(p)
                        let op = inP - beganSheetP + beganMainP
                        let np = line.mainPoint(withMainCenterPoint: op,
                                                at: pointIndex)
                        let pressure = event.pressure
                            .clipped(min: 0.4, max: 1, newMin: 0, newMax: 1)
                        pressures.append((event.time, pressure))
                        
                        line.controls[pointIndex].point = np
                        
                        if isPressure || (!isPressure && (event.time - (pressures.first?.time ?? 0) > 1 && (pressures.allSatisfy { $0.pressure <= 0.5 }))) {
                            isPressure = true
                            
                            let nPressures = pressures
                                .filter { (0.04 ..< 0.4).contains(event.time - $0.time) }
                            let nPressure = nPressures.mean { $0.pressure } ?? pressures.first!.pressure
                            line.controls[pointIndex].pressure = nPressure
                        }
                        
                        lineView.model = line
                        
                        node.children = line.mainPointSequence.flatMap {
                            let p = sheetView.convertToWorld($0)
                            return [Node(path: .init(circleRadius: 0.25 * 1.5 * line.size, position: p),
                                         fillType: .color(.content)),
                                    Node(path: .init(circleRadius: 0.25 * line.size, position: p),
                                         fillType: .color(.background))]
                        }
                    }
                }
            }
        case .ended:
            node.removeFromParent()
            
            if let sheetView {
                if lineIndex < sheetView.linesView.elementViews.count {
                    let line = sheetView.linesView.elementViews[lineIndex].model
                    if line != beganLine {
                        sheetView.newUndoGroup()
                        sheetView.captureLine(line, old: beganLine, at: lineIndex)
                    }
                }
            }

            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveLineZEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?, lineNode = Node(),
    crossIndexes = [Int](), crossLineIndex = 0,
    lineIndex = 0, lineView: SheetLineView?, oldSP = Point(),
                isNote = false, noteNode: Node?
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }

        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)

        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.sheetView(at: p) {
                let inP = sheetView.convertFromWorld(p)
                if let (lineView, li) = sheetView.lineTuple(at: inP,
                                                            isSmall: false,
                                                            scale: rootView.screenToWorldScale) {
                    
                    self.sheetView = sheetView
                    lineIndex = li
                    lineView.node.isHidden = true
                    self.lineView = lineView
                    
                    let line = lineView.model
                    if let lb = lineView.node.path.bounds?.outset(by: line.size / 2) {
                        crossIndexes = sheetView.linesView.elementViews.enumerated().compactMap {
                            let nLine = $0.element.model
                            return if $0.offset == li {
                                li
                            } else if let nb = $0.element.node.path.bounds,
                                      nb.outset(by: nLine.size / 2).intersects(lb) {
                                nLine.minDistanceSquared(line) < (line.size / 2 + nLine.size / 2).squared ?
                                $0.offset : nil
                            } else {
                                nil
                            }
                        }
                        if let lastI = crossIndexes.last {
                            crossIndexes.append(lastI + 1)
                        }
                        crossLineIndex = crossIndexes.firstIndex(of: li)!
                    }
                    
                    oldSP = sp
                    lineNode.path = Path(lineView.model)
                    lineNode.lineType = lineView.node.lineType
                    lineNode.lineWidth = lineView.node.lineWidth
                    sheetView.linesView.node.children.insert(lineNode, at: li)
                } else if sheetView.scoreView.model.enabled,
                          let li = sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p),
                                                                 scale: rootView.screenToWorldScale) {
                    self.sheetView = sheetView
                    lineIndex = li
                    let noteNode = sheetView.scoreView.notesNode.children[li]
                    self.noteNode = noteNode
                    noteNode.isHidden = true
                    
                    let line = sheetView.scoreView.pointline(from: sheetView.scoreView.model.notes[li])
                    let noteH = sheetView.scoreView.noteH(from: sheetView.scoreView.model.notes[li])
                    if let lb = noteNode.path.bounds?.outset(by: noteH / 2) {
                        let toneFrames = sheetView.scoreView.toneFrames(at: li)
                        crossIndexes = sheetView.scoreView.model.notes.enumerated().compactMap {
                            let nNoteH = sheetView.scoreView.noteH(from: sheetView.scoreView.model.notes[$0.offset])
                            let nLine = sheetView.scoreView.pointline(from: $0.element)
                            return if $0.offset == li {
                                li
                            } else if let nb = sheetView.scoreView.notesNode.children[$0.offset].path.bounds,
                                      nb.outset(by: noteH / 2).intersects(lb) {
                                nLine.minDistanceSquared(line) < (noteH / 2 + nNoteH / 2).squared ?
                                $0.offset : nil
                            } else if !toneFrames.isEmpty,
                                      sheetView.scoreView.toneFrames(at: $0.offset).contains(where: { v0 in toneFrames.contains(where: { v1 in v0.frame.intersects(v1.frame) })
                                          || nLine.minDistanceSquared(v0.frame) < (noteH / 2 + nNoteH / 2).squared
                                      }) {
                                $0.offset
                            } else {
                                nil
                            }
                        }
                        if let lastI = crossIndexes.last {
                            crossIndexes.append(lastI + 1)
                        }
                        crossLineIndex = crossIndexes.firstIndex(of: li)!
                    }
                    
                    oldSP = sp
                    lineNode = noteNode.clone
                    lineNode.isHidden = false
                    sheetView.scoreView.notesNode.children.insert(lineNode, at: li)
                }
            }
        case .changed:
            if let sheetView = sheetView,
               lineIndex < sheetView.linesView.elementViews.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0, max: sheetView.linesView.elementViews.count)
                lineNode.removeFromParent()
                sheetView.linesView.node.children.insert(lineNode, at: li)
            } else if let sheetView = sheetView, sheetView.scoreView.model.enabled,
                      lineIndex < sheetView.scoreView.model.notes.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0, max: sheetView.scoreView.model.notes.count)
                lineNode.removeFromParent()
                sheetView.scoreView.notesNode.children.insert(lineNode, at: li)
            }
        case .ended:
            lineNode.removeFromParent()
            lineView?.node.isHidden = false
            noteNode?.isHidden = false
            
            if let sheetView = sheetView,
               lineIndex < sheetView.linesView.elementViews.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0, max: sheetView.linesView.elementViews.count)
                let line = sheetView.linesView.elementViews[lineIndex].model
                if lineIndex != li {
                    sheetView.newUndoGroup()
                    sheetView.removeLines(at: [lineIndex])
                    sheetView.insert([.init(value: line, index: li > lineIndex ? li - 1 : li)])
                }
            } else if let sheetView = sheetView, sheetView.scoreView.model.enabled,
                      lineIndex < sheetView.scoreView.model.notes.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0, max: sheetView.scoreView.model.notes.count)
                let line = sheetView.scoreView.model.notes[lineIndex]
                if lineIndex != li {
                    sheetView.newUndoGroup()
                    sheetView.removeNote(at: lineIndex)
                    sheetView.insert([.init(value: line, index: li > lineIndex ? li - 1 : li)])
                }
            }

            rootView.cursor = rootView.defaultCursor
        }
    }
}
