// Copyright 2026 Cii
//
// This file is part of Shikisen.
//
// Shikisen is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shikisen is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shikisen.  If not, see <http://www.gnu.org/licenses/>.

import struct Foundation.UUID

protocol TimelineView: BindableView where Model: TempoType {
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
    func containsTimeline(_ p: Point, scale: Double) -> Bool
    var timelineCenterY: Double { get }
    var beatRange: Range<Rational>? { get }
    var loopDurBeat: Rational? { get }
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
        x(atBeat: model.beat(fromSec: sec))
    }
    func x(atSec sec: Double) -> Double {
        x(atBeat: model.beat(fromSec: sec))
    }
    
    func width(atDurBeat durBeat: Rational) -> Double {
        width(atDurBeat: Double(durBeat))
    }
    func width(atDurBeat durBeat: Double) -> Double {
        durBeat * Sheet.beatWidth
    }
    func width(atDurSec durSec: Rational) -> Double {
        width(atDurBeat: model.beat(fromSec: durSec))
    }
    func width(atDurSec durSec: Double) -> Double {
        width(atDurBeat: model.beat(fromSec: durSec))
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
    func durBeat(atWidth w: Double, interval: Rational) -> Rational {
        Rational(w / Sheet.beatWidth, intervalScale: interval)
    }
    
    func sec(atX x: Double, interval: Rational) -> Rational {
        model.sec(fromBeat: beat(atX: x, interval: interval))
    }
    func sec(atX x: Double) -> Double {
        model.sec(fromBeat: beat(atX: x))
    }
    func sec(atX x: Double) -> Rational {
        sec(atX: x, interval: Rational(1, frameRate))
    }
    
    func tempoFrames() -> [Rect] {
        guard let beatRange else { return [] }
        let loopDurBeat = loopDurBeat ?? 0
        let knobW = Sheet.knobWidth, rulerH = Sheet.rulerHeight
        let secRange = model.secRange(fromBeat: beatRange.start ..< (beatRange.end + loopDurBeat))
        let sy = timelineCenterY - Sheet.timelineHalfHeight - rulerH / 2 + origin.y
        var rects = [Rect]()
        for sec in Int(secRange.start.rounded(.up)) ..< Int(secRange.end.rounded(.up)) {
            let sec = Rational(sec)
            let secX = x(atSec: sec) + origin.x
            rects.append(Rect(x: secX - knobW / 2, y: sy - rulerH / 2,
                              width: knobW, height: rulerH).outset(by: 1))
        }
        return rects
    }
    func containsTempo(_ p: Point, scale: Double) -> Bool {
        guard let beatRange else { return false }
        let loopDurBeat = loopDurBeat ?? 0
        let secRange = model.secRange(fromBeat: beatRange.start ..< (beatRange.end + loopDurBeat))
        let sy = timelineCenterY - Sheet.timelineHalfHeight - Sheet.rulerHeight / 2 + origin.y
        for sec in Int(secRange.start.rounded(.up)) ..< Int(secRange.end.rounded(.up)) {
            let sec = Rational(sec)
            let secX = x(atSec: sec) + origin.x
            if abs(p.x - secX) < Sheet.keyframeEditDistance * scale
                && abs(p.y - sy) < Sheet.rulerHeight / 2 + 2 * scale {
                return true
            }
        }
        return false
    }
    
    func mainLineDistance(_ p: Point) -> Double {
        abs(p.y - timelineCenterY)
    }
    func containsMainLine(_ p: Point, scale: Double) -> Bool {
        guard containsTimeline(p, scale: scale) else { return false }
        return mainLineDistance(p) < 5 * scale
    }
}

enum EditGrid {
    case main, second, full
    
    static let fullEditBeatInterval = Rational(1, 384),
               secondBeatInterval = Rational(1, 48),
               beatInterval = Rational(1, 8)
    static let fullEditPitchInterval = Rational(1, 48),
               pitchInterval = Rational(1)
    
    init(logScale: Double) {
        switch logScale {
        case ...(-4): self = .full
        case ...(-3): self = .second
        default: self = .main
        }
    }
    
    var beatInterval: Rational {
        switch self {
        case .main: Self.beatInterval
        case .second: Self.secondBeatInterval
        case .full: Self.fullEditBeatInterval
        }
    }
    var pitchInterval: Rational {
        switch self {
        case .main: Self.pitchInterval
        case .second: Self.pitchInterval
        case .full: Self.fullEditPitchInterval
        }
    }
}

protocol SpectrgramView: TimelineView {
    var pcmBuffer: PCMBuffer? { get }
    var spectrgramY: Double { get }
}

final class ScoreView: TimelineView, @unchecked Sendable {
    typealias Model = Score
    typealias Binder = SheetBinder
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    var editGrid = EditGrid.main {
        didSet {
            guard editGrid != oldValue else { return }
            timelineFullEditBorderNode.isHidden = editGrid != .full
            timelineSecondEditBorderNode.isHidden = editGrid != .second
            
            notesNode.children.forEach {
                $0.children.forEach {
                    if $0.name == "fullGrid" {
                        $0.isHidden = editGrid != .full
                    } else if $0.name == "secondGrid" {
                        $0.isHidden = editGrid != .second
                    } else if $0.name == "point" {
                        $0.isHidden = !isEditTone
                    }
                }
            }
            reverbsNode.children.forEach {
                $0.children.forEach {
                    if $0.name == "fullGrid" {
                        $0.isHidden = editGrid != .full
                    } else if $0.name == "secondGrid" {
                        $0.isHidden = editGrid != .second
                    }
                }
            }
        }
    }
    var isFullEdit: Bool {
        editGrid == .full
    }
    var isEditTone: Bool {
        editGrid != .main
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
    var transformedMainFrame: Rect {
        mainFrame * node.localTransform
    }
    var scaleFrame: Rect {
        let score = model
        let sBeat = max(score.beatRange.start, -10000)
        let sx = x(atBeat: sBeat)
        let sy = y(fromPitch: Score.pitchRange.start)
        let ey = y(fromPitch: Score.pitchRange.end)
        return .init(x: sx - Sheet.textPadding.width, y: sy,
                     width: Sheet.textPadding.width, height: ey - sy)
    }
    var transformedScaleFrame: Rect {
        scaleFrame * node.localTransform
    }
    
    var otherNotes = [Note]() {
        didSet {
            guard otherNotes != oldValue else { return }
            otherChordResults = otherNotes.map { $0.chordResult(fromTempo: model.tempo) }
            updateChord()
            otherNotesNode.children = otherNotes.map {
                mainLineNoteNode(from: $0, color: .init(white: 0, opacity: 0.5))
            }
        }
    }
    private var otherChordResults = [Note.ChordResult?]()
    
    let draftNotesNode = Node(), notesNode = Node()
    let timelineContentNode = Node(fillType: .color(.content))
    let timelineSubBorderNode = Node(fillType: .color(.subBorder))
    let timelineBorderNode = Node(fillType: .color(.border))
    let timelineFullEditBorderNode = Node(isHidden: true, fillType: .color(.border))
    let timelineSecondEditBorderNode = Node(isHidden: true, fillType: .color(.border))
    let chordNode = Node()
    let pitsNode = Node(fillType: .color(.background))
    var tonesNode = Node(), reverbsNode = Node(), otherNotesNode = Node()
    var noteLines = [Pointline]()
    var selectedNode = Node()
    let clippingNode = Node(isHidden: true, lineWidth: 4, lineType: .color(.warning))
    var chordResults = [Note.ChordResult?](), draftChordResults = [Note.ChordResult?]()
    
    var spectrogramNode: Node?
    var spectrogramFqType: Spectrogram.FqType?
    
    var scoreTrackItem: ScoreTrackItem?
    
    var isHiddenSelected = false {
        didSet {
            guard isHiddenSelected != oldValue else { return }
            selectedNode.isHidden = isHiddenSelected
        }
    }
    var selectedNotePitSprolIs = [Int: [Int: Set<Int>]]() {
        didSet {
            guard selectedNotePitSprolIs != oldValue else { return }
            updateWithSelected(old: oldValue)
        }
    }
    var selectedNotePitIs: [Int: [Int]] {
        selectedNotePitSprolIs.reduce(into: .init()) { $0[$1.key] = $1.value.keys.sorted() }
    }
    var selectedNoteIs: [Int] {
        selectedNotePitSprolIs.keys.sorted()
    }
    func updateWithSelected(old: [Int: [Int: Set<Int>]]) {
        guard !selectedNotePitSprolIs.isEmpty else {
            selectedNode.children = []
            return
        }
        
        let score = model
        var children = [Node]()
        for (noteI, pitSprols) in selectedNotePitSprolIs {
            let note = score.notes[noteI]
            
            if pitSprols.isEmpty || pitSprols.count == note.pits.count {
                let ps = noteLines[noteI].controls.map { $0.point }
                if !ps.isEmpty {
                    children.append(Node(path: Path(ps),
                                         lineWidth: 1.5,
                                         lineType: .color(.selected.with(opacity: 0.75))))
                }
            }
            
            var pathlines = [Pathline]()
            if note.isDefaultTone {
                pitSprols.keys.forEach {
                    let pitP = pitPosition(atPit: $0, from: note)
                    pathlines.append(.init(circleRadius: 0.2 * 8, position: pitP))
                }
            } else {
                let toneFrames = toneFrames(from: note)
                if toneFrames.isEmpty {
                    for pitI in note.pits.count.range {
                        if pitSprols[pitI] != nil {
                            let pitP = pitPosition(atPit: pitI, from: note)
                            pathlines.append(.init(circleRadius: 0.175 * 8, position: pitP))
                        }
                    }
                } else {
                    for (pitIs, toneFrame) in toneFrames {
                        for pitI in pitIs {
                            if let sprolIs = pitSprols[pitI] {
                                let pitP = pitPosition(atPit: pitI, from: note)
                                pathlines.append(.init(circleRadius: 0.175 * 8, position: pitP))
                                for sprolI in sprolIs {
                                    let sprolP = sprolPosition(atSprol: sprolI, atPit: pitI,
                                                               from: note, atY: toneFrame.minY)
                                    pathlines.append(.init(circleRadius: 0.1 * 2, position: sprolP))
                                }
                            }
                        }
                    }
                }
            }
            children.append(Node(path: Path(pathlines),
                                 fillType: .color(.selected)))
        }
        selectedNode.children = children
    }
    var selectedFrame: Rect? {
        selectedNode.children.reduce(into: Rect?.none) {
            $0 += $1.bounds
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        node = Node(children: [timelineBorderNode,
                               timelineSecondEditBorderNode, timelineFullEditBorderNode,
                               timelineSubBorderNode,
                               chordNode,
                               timelineContentNode,
                               draftNotesNode, otherNotesNode, notesNode, pitsNode, tonesNode,
                               clippingNode, selectedNode])
        updateClippingNode()
        updateTimeline()
        updateDraftNotes()
        updateScore()
        
        if model.enabled {
            scoreTrackItem = .init(score: model, sampleRate: Audio.defaultSampleRate,
                                   isUpdateNotewaveDic: false)
        }
        node.attitude.position.y = binder[keyPath: keyPath].timelineY
    }
}
extension ScoreView {
    var pitchHeight: Double { Sheet.pitchHeight }
    
    func updateWithModel() {
        updateTimeline()
        updateDraftNotes()
        updateScore()
    }
    func updateClippingNode() {
        guard model.enabled else {
            clippingNode.isHidden = true
            return
        }
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
                 borderPathlines, secondEditBorderPathlines, fullEditBorderPathlines) = self.timelinePathlinesTuple()
            timelineContentNode.path = .init(contentPathlines)
            timelineSubBorderNode.path = .init(subBorderPathlines)
            timelineBorderNode.path = .init(borderPathlines)
            timelineSecondEditBorderNode.path = .init(secondEditBorderPathlines)
            timelineFullEditBorderNode.path = .init(fullEditBorderPathlines)
            node.attitude.position.y = model.timelineY
        } else {
            timelineContentNode.path = .init()
            timelineSubBorderNode.path = .init()
            timelineBorderNode.path = .init()
            timelineSecondEditBorderNode.path = .init()
            timelineFullEditBorderNode.path = .init()
            node.attitude.position = .init()
        }
    }
    func updateChord() {
        if model.enabled {
            chordNode.children = chordNodes()
        } else {
            chordNode.children = []
        }
    }
    func updateNotes() {
        if model.enabled {
            let vs = model.notes.map { noteNode(from: $0) }
            let nodes = vs.map { $0.node }
            notesNode.children = nodes
            chordResults = model.notes.map { $0.chordResult(fromTempo: model.tempo) }
            tonesNode.children = vs.map { $0.toneNode }
            reverbsNode.children = vs.map { $0.reverbNode }
            noteLines = vs.map { $0.noteLine }
        } else {
            notesNode.children = []
            chordResults = []
            tonesNode.children = []
            reverbsNode.children = []
            noteLines = []
        }
    }
    func updateDraftNotes() {
        if model.enabled {
            draftNotesNode.children = model.draftNotes.map { draftNoteNode(from: $0) }
        } else {
            draftNotesNode.children = []
        }
        draftChordResults = model.draftNotes.map { $0.chordResult(fromTempo: model.tempo) }
    }
    func updateScore() {
        updateNotes()
        updateChord()
    }
    
    var frameRate: Int { Keyframe.defaultFrameRate }
    
    var timelineY: Double {
        get { model.timelineY }
        set {
            binder[keyPath: keyPath].timelineY = newValue
            updateTimeline()
        }
    }
    
    var tempo: Rational {
        get { model.tempo }
        set {
            binder[keyPath: keyPath].tempo = newValue
            updateTimeline()
            scoreTrackItem?.changeTempo(with: model)
        }
    }
    
    var origin: Point { .init(0, timelineY) }
    var timelineCenterY: Double { 0 }
    var beatRange: Range<Rational>? {
        model.beatRange
    }
    var loopDurBeat: Rational? {
        model.loopDurBeat
    }
    var localBeatRange: Range<Rational>? {
        model.localMaxBeatRange
    }
    
    var endLoopDurBeat: Rational? {
        get { model.endLoopDurBeat }
        set {
            guard let newValue else { return }
            let oldDurBeat = model.endLoopDurBeat
            binder[keyPath: keyPath].endLoopDurBeat = newValue
            updateTimeline()
            if oldDurBeat != newValue {
                scoreTrackItem?.loopDurSec = model.sec(fromBeat: model.loopDurBeat)
            }
            scoreTrackItem?.changeTempo(with: model)
        }
    }
    
    var pitchStartY: Double {
        timelineCenterY + Sheet.timelineHalfHeight + Sheet.timelineMargin
    }
    func pitch(atY y: Double) -> Double {
        (y - pitchStartY) / pitchHeight
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
    func rendableNormarizedPitResult(atBeat beat: Rational, at noteI: Int) -> Note.PitResult {
        let note = self[noteI].withRendable(tempo: model.tempo)
        return note.normarizedPitResult(atBeat: .init(beat - note.beatRange.start))
    }
    
    var option: ScoreOption {
        get { model.option }
        set {
            let oldValue = option
            
            unupdateModel.option = newValue
            updateTimeline()
            updateChord()
            updateClippingNode()
            if oldValue.isShownSpectrogram != newValue.isShownSpectrogram {
                updateSpectrogram()
            }
            
            if oldValue.enabled != newValue.enabled {
                scoreTrackItem = newValue.enabled ? .init(score: model, sampleRate: Audio.defaultSampleRate,
                                                          isUpdateNotewaveDic: false) : nil
            }
            if oldValue.tempo != newValue.tempo {
                scoreTrackItem?.changeTempo(with: model)
            }
            if oldValue.beatRange != newValue.beatRange {
                scoreTrackItem?.durSec = model.secRange.end
            }
            
            if oldValue.endLoopDurBeat != newValue.endLoopDurBeat {
                scoreTrackItem?.loopDurSec = model.sec(fromBeat: model.loopDurBeat)
            }
        }
    }
    
    func append(_ note: Note) {
        unupdateModel.notes.append(note)
        let (noteNode, toneNode, reverbNode, noteLine) = noteNode(from: note)
        notesNode.append(child: noteNode)
        chordResults.append(note.chordResult(fromTempo: model.tempo))
        tonesNode.append(child: toneNode)
        reverbsNode.append(child: reverbNode)
        noteLines.append(noteLine)
        updateChord()
        scoreTrackItem?.insert([.init(value: note, index: unupdateModel.notes.count - 1)], with: model)
    }
    func insert(_ note: Note, at noteI: Int) {
        unupdateModel.notes.insert(note, at: noteI)
        let (noteNode, toneNode, reverbNode, noteLine) = noteNode(from: note)
        notesNode.insert(child: noteNode, at: noteI)
        chordResults.insert(note.chordResult(fromTempo: model.tempo), at: noteI)
        tonesNode.insert(child: toneNode, at: noteI)
        reverbsNode.insert(child: reverbNode, at: noteI)
        noteLines.insert(noteLine, at: noteI)
        updateChord()
        scoreTrackItem?.insert([.init(value: note, index: noteI)], with: model)
    }
    func insert(_ nivs: [IndexValue<Note>]) {
        unupdateModel.notes.insert(nivs)
        let vs = nivs.map { IndexValue(value: noteNode(from: $0.value), index: $0.index) }
        let noivs = vs.map { IndexValue(value: $0.value.node, index: $0.index) }
        let toivs = vs.map { IndexValue(value: $0.value.toneNode, index: $0.index) }
        let reivs = vs.map { IndexValue(value: $0.value.reverbNode, index: $0.index) }
        let seivs = vs.map { IndexValue(value: $0.value.noteLine, index: $0.index) }
        notesNode.children.insert(noivs)
        chordResults.insert(nivs.map { .init(value: $0.value.chordResult(fromTempo: model.tempo),
                                             index: $0.index) })
        tonesNode.children.insert(toivs)
        reverbsNode.children.insert(reivs)
        noteLines.insert(seivs)
        updateChord()
        scoreTrackItem?.insert(nivs, with: model)
    }
    func replace(_ nivs: [IndexValue<Note>]) {
        unupdateModel.notes.replace(nivs)
        let vs = nivs.map { IndexValue(value: noteNode(from: $0.value), index: $0.index) }
        let noivs = vs.map { IndexValue(value: $0.value.node, index: $0.index) }
        let toivs = vs.map { IndexValue(value: $0.value.toneNode, index: $0.index) }
        let reivs = vs.map { IndexValue(value: $0.value.reverbNode, index: $0.index) }
        let seivs = vs.map { IndexValue(value: $0.value.noteLine, index: $0.index) }
        notesNode.children.replace(noivs)
        chordResults.replace(nivs.map { .init(value: $0.value.chordResult(fromTempo: model.tempo),
                                              index: $0.index) })
        tonesNode.children.replace(toivs)
        reverbsNode.children.replace(reivs)
        noteLines.replace(seivs)
        updateChord()
        scoreTrackItem?.replace(nivs, with: model)
        
        updateWithSelected(old: selectedNotePitSprolIs)
    }
    func remove(at noteI: Int) {
        unupdateModel.notes.remove(at: noteI)
        notesNode.remove(atChild: noteI)
        chordResults.remove(at: noteI)
        tonesNode.remove(atChild: noteI)
        reverbsNode.remove(atChild: noteI)
        noteLines.remove(at: noteI)
        updateChord()
        scoreTrackItem?.remove(at: [noteI])
    }
    func remove(at noteIs: [Int]) {
        unupdateModel.notes.remove(at: noteIs)
        noteIs.reversed().forEach { notesNode.remove(atChild: $0) }
        noteIs.reversed().forEach { chordResults.remove(at: $0) }
        noteIs.reversed().forEach { tonesNode.remove(atChild: $0) }
        noteIs.reversed().forEach { reverbsNode.remove(atChild: $0) }
        noteLines.remove(at: noteIs)
        updateChord()
        scoreTrackItem?.remove(at: noteIs)
    }
    subscript(noteI: Int) -> Note {
        get {
            unupdateModel.notes[noteI]
        }
        set {
            unupdateModel.notes[noteI] = newValue
            let (noteNode, toneNode, reverbNode, noteLine) = noteNode(from: newValue)
            notesNode.children[noteI] = noteNode
            chordResults[noteI] = newValue.chordResult(fromTempo: model.tempo)
            tonesNode.children[noteI] = toneNode
            reverbsNode.children[noteI] = reverbNode
            noteLines[noteI] = noteLine
            updateChord()
            scoreTrackItem?.replace([.init(value: newValue, index: noteI)], with: model)
            
            updateWithSelected(old: selectedNotePitSprolIs)
        }
    }
    
    func insertDraft(_ nivs: [IndexValue<Note>]) {
        unupdateModel.draftNotes.insert(nivs)
        draftNotesNode.children.insert(nivs.map { .init(value: draftNoteNode(from: $0.value), index: $0.index) })
        draftChordResults.insert(nivs.map { .init(value: $0.value.chordResult(fromTempo: model.tempo),
                                             index: $0.index) })
        updateChord()
    }
    func removeDraft(at noteIs: [Int]) {
        unupdateModel.draftNotes.remove(at: noteIs)
        noteIs.reversed().forEach { draftNotesNode.remove(atChild: $0) }
        noteIs.reversed().forEach { draftChordResults.remove(at: $0) }
        updateChord()
    }
    
    func timelinePathlinesTuple() -> (contentPathlines: [Pathline],
                                      subBorderPathlines: [Pathline],
                                      borderPathlines: [Pathline],
                                      secondEditBorderPathlines: [Pathline],
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
        let y = timelineCenterY, timelineHalfHeight = Sheet.timelineHalfHeight
        let sy = y - timelineHalfHeight
        let ey = y + timelineHalfHeight
        
        var contentPathlines = [Pathline]()
        var subBorderPathlines = [Pathline]()
        var borderPathlines = [Pathline]()
        var secondEditBorderPathlines = [Pathline]()
        var fullEditBorderPathlines = [Pathline]()
        
        makeBeatPathlines(in: score.allBeatRange, sy: sy, ey: ey,
                          subBorderBeats: Set(score.keyBeats),
                          subBorderPathlines: &subBorderPathlines,
                          fullEditBorderPathlines: &fullEditBorderPathlines,
                          secondEditBorderPathlines: &secondEditBorderPathlines,
                          borderPathlines: &borderPathlines)
        
        let pitchMinY = self.y(fromPitch: pitchRange.start)
        let pitchMaxY = self.y(fromPitch: pitchRange.end)
        makeBeatPathlines(in: score.allBeatRange,
                          sy: pitchMinY,
                          ey: pitchMaxY,
                          subBorderBeats: Set(score.keyBeats),
                          enabledBeatExtension: false,
                          subBorderPathlines: &subBorderPathlines,
                          fullEditBorderPathlines: &fullEditBorderPathlines,
                          secondEditBorderPathlines: &secondEditBorderPathlines,
                          borderPathlines: &borderPathlines)
        
        let scaleSet = Set(score.scales.map { $0.mod(12) })
        
        contentPathlines.append(.init(Rect(x: sx - Sheet.textPadding.width / 2 - 0.125, y: pitchMinY,
                                           width: 0.25, height: pitchMaxY - pitchMinY)))
        
        let scaleW = 4.0, scaleCW = 8.0
        let roundedSPitch = pitchRange.start.rounded(.down)
        let deltaPitch = Rational(1, 16)
        let pitchR1 = EditGrid.pitchInterval
        var cPitch = roundedSPitch
        while cPitch <= pitchRange.end {
            if cPitch >= pitchRange.start {
                let py = self.y(fromPitch: cPitch)
                let plw: Double
                if cPitch % pitchR1 == 0 {
                    plw = scaleSet.contains(cPitch.mod(12)) ? 0.5 : 0.25
                } else {
                    plw = 0.03125
                }
                let rect = Rect(x: sx, y: py - plw / 2, width: ex - sx, height: plw)
                let scaleRect = Rect(x: sx - Sheet.textPadding.width / 2 - scaleW / 2, y: py - plw / 2,
                                     width: scaleW, height: plw)
                if plw == 0.03125 {
                    fullEditBorderPathlines.append(.init(rect))
                    fullEditBorderPathlines.append(.init(scaleRect))
                } else if plw == 0.5 {
                    subBorderPathlines.append(.init(rect))
                    contentPathlines.append(.init(Rect(x: sx - Sheet.textPadding.width / 2 - scaleW / 2, y: py - lw / 2,
                                                       width: scaleW, height: lw)))
                } else {
                    borderPathlines.append(.init(rect))
                    borderPathlines.append(.init(cPitch.mod(12) == 0 ?
                                                 Rect(x: sx - Sheet.textPadding.width / 2 - scaleCW / 2, y: py - plw * 2 / 2.0, width: scaleCW, height: plw * 2) :
                                                scaleRect))
                }
            }
            cPitch += deltaPitch
        }
        
        for scale in score.scales {
            let unison = scale.mod(12)
            if !unison.isInteger {
                var pitch = unison
                while pitch < pitchRange.start { pitch += 12 }
                while pitchRange.contains(pitch) {
                    let plw = 0.25
                    let py = self.y(fromPitch: pitch)
                    let rect = Rect(x: sx, y: py - plw / 2, width: ex - sx, height: plw)
                    subBorderPathlines.append(.init(rect))
                    contentPathlines.append(.init(Rect(x: sx - Sheet.textPadding.width / 2 - scaleW / 2, y: py - lw * 0.5 / 2, width: scaleW, height: lw * 0.5)))
                    pitch += 12
                }
            }
        }
        
        for keyBeat in score.keyBeats {
            let nx = x(atBeat: keyBeat)
            let nKnobW = keyBeat % EditGrid.beatInterval == 0 ? knobW : knobW / 2
            contentPathlines.append(.init(Rect(x: nx - nKnobW / 2, y: y - knobH / 2,
                                               width: nKnobW, height: knobH)))
        }
        let nKnobW = eBeat % EditGrid.beatInterval == 0 ? knobW : knobW / 2
        contentPathlines.append(.init(Rect(x: ex - nKnobW / 2, y: y - knobH / 2,
                                           width: nKnobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: sx, y: y - lw / 2,
                                           width: ex - sx, height: lw)))
        
        let loopKnobH = 4.0
        let neBeat = eBeat + score.loopDurBeat
        let lkx = x(atBeat: neBeat)
        let nnKnobW = neBeat % EditGrid.beatInterval == 0 ? knobW : knobW / 2
        if score.loopDurBeat > 0 {
            contentPathlines.append(.init(Rect(x: ex, y: ey - lw / 2,
                                               width: lkx - ex, height: lw)))
            contentPathlines.append(.init(Rect(x: ex, y: y - lw / 2,
                                               width: lkx - ex, height: lw)))
        }
        contentPathlines.append(.init(Rect(x: lkx - nnKnobW / 2,
                                           y: ey - loopKnobH / 2,
                                           width: nnKnobW, height: loopKnobH)))
        
        let secRange = score.secRange
        for sec in Int(secRange.start.rounded(.up)) ..< Int((secRange.end + score.loopDurSec).rounded(.up)) {
            let sec = Rational(sec)
            let secX = x(atSec: sec)
            contentPathlines.append(.init(Rect(x: secX - knobW / 2, y: sy - rulerH,
                                               width: knobW, height: rulerH)))
        }
        
        let sprH = Sheet.timelineMargin
        let pnW = 20.0, pnH = 6.0, spnW = 3.0, pnY = ey + sprH / 2
        contentPathlines.append(.init(Rect(x: sx,
                                           y: pnY - lw / 2,
                                           width: pnW + spnW, height: lw)))
        
        contentPathlines.append(.init(Rect(x: sx - lw / 2,
                                           y: pnY - pnH / 2,
                                           width: lw, height: pnH)))
        contentPathlines.append(.init(Rect(x: sx + pnW - lw / 2,
                                           y: pnY - pnH / 2,
                                           width: lw, height: pnH)))
        
        contentPathlines.append(.init(Rect(x: sx + pnW - spnW,
                                           y: pnY - pnH / 2 + pnH - lw / 2,
                                           width: spnW * 2, height: lw)))
        contentPathlines.append(.init(Rect(x: sx + pnW - spnW,
                                           y: pnY - pnH / 2 - lw / 2,
                                           width: spnW * 2, height: lw)))
        
        let issx = score.isShownSpectrogram ? pnW * 1 : pnW * 0
        contentPathlines.append(Pathline(Rect(x: sx + issx - Sheet.knobWidth / 2,
                                              y: pnY - Sheet.knobHeight / 2,
                                              width: Sheet.knobWidth,
                                              height: Sheet.knobHeight)))
        
        return (contentPathlines, subBorderPathlines, borderPathlines,
                secondEditBorderPathlines, fullEditBorderPathlines)
    }
    
    func chordTypers(at p: Point, scale: Double) -> [Chord.ChordTyper] {
        let maxD = Sheet.knobEditDistance * scale
        let maxDS = maxD * maxD
        let edges = chordEdges()
        var minDS = Double.infinity, minTypers = [Chord.ChordTyper]()
        for (edge, typers) in edges {
            let ds = edge.distanceSquared(from: p)
            if ds < minDS && ds < maxDS {
                minDS = ds
                minTypers = typers
            }
        }
        return minTypers
    }
    func chordEdges() -> [(edge: Edge, typers: [Chord.ChordTyper])] {
        let score = model
        let pitchRange = Score.pitchRange
        guard let intPitchRange = Range<Int>(pitchRange) else { return [] }
        
        let chordResults = (chordResults + draftChordResults + otherChordResults).compactMap() { $0 }
        let trs = score.chordsResult(from: chordResults)
        
        var chordEdges = [(edge: Edge, typers: [Chord.ChordTyper])]()
        for (tr, pitchs) in trs {
            let pitchs = pitchs.sorted()
            guard let chord = Chord(pitchs: pitchs) else { continue }
            let typers = chord.typers.sorted(by: { $0.type.rawValue > $1.type.rawValue })
            
            let nsx = x(atBeat: tr.start + score.beatRange.start),
                nex = x(atBeat: tr.end + score.beatRange.start)
            let unisonsSet = typers.reduce(into: Set<Int>()) { $0.formUnion($1.unisons) }
            for pitch in intPitchRange {
                let pitchUnison = pitch.mod(12)
                guard unisonsSet.contains(pitchUnison) else { continue }
                let py = self.y(fromPitch: Rational(pitch))
                chordEdges.append((.init(.init(nsx, py), .init(nex, py)),
                                   .init(typers.filter { $0.unisons.contains(pitchUnison) })))
            }
        }
        return chordEdges
    }
    
    func chordNodes() -> [Node] {
        let score = model
        let pitchRange = Score.pitchRange
        guard let intPitchRange = Range<Int>(pitchRange) else { return [] }
        
        let chordResults = (chordResults + draftChordResults + otherChordResults).compactMap() { $0 }
        let trs = score.chordsResult(from: chordResults)
        
        struct PitchAndTyper: Hashable {
            var pitch: Int, typers: [Chord.ChordTyper]
            
            func inversion(from typer: Chord.ChordTyper) -> Bool {
                typer.mainUnison == pitch.mod(12)
            }
        }
        var cbpts = [(beatRange: Range<Rational>, pitchAndTypers: [PitchAndTyper])]()
        for (chordBeatRange, pitchs) in trs {
            let pitchs = pitchs.sorted()
            guard let chord = Chord(pitchs: pitchs) else {
                cbpts.append((chordBeatRange, []))
                continue
            }
            let typers = chord.typers.sorted(by: { $0.type.rawValue > $1.type.rawValue })
            let unisonsSet = typers.reduce(into: Set<Int>()) { $0.formUnion($1.unisons) }
            let pitchAndTypers: [PitchAndTyper] = intPitchRange.compactMap { pitch in
                let pitchUnison = pitch.mod(12)
                guard unisonsSet.contains(pitchUnison) else { return nil }
                let nTypers = typers.filter { $0.unisons.contains(pitchUnison) }
                return .init(pitch: pitch, typers: nTypers)
            }
            if cbpts.last?.pitchAndTypers == pitchAndTypers {
                cbpts[.last].beatRange.end = chordBeatRange.end
            } else {
                cbpts.append((chordBeatRange, pitchAndTypers))
            }
        }
        
        var chordTypeRectDic0 = [Chord.ChordType: [Rect]](),
            chordTypeRectDic1 = [Chord.ChordType: [Rect]]()
        for cbpt in cbpts {
            let maxTypersCount = cbpt.pitchAndTypers.maxValue { $0.typers.count } ?? 0
            guard maxTypersCount > 0 else { continue }
            let chordSX = x(atBeat: cbpt.beatRange.start)
            let chordEX = x(atBeat: cbpt.beatRange.end)
            let chordW = chordEX - chordSX
            let chordCenterX = chordSX.mid(chordEX)
            let oMaxW = 1.0, padding = 1.0
            let oNw = oMaxW * Double(maxTypersCount - 1) + padding * 2
            let cw = max(0, chordW)
            let lwScale = maxTypersCount == 1 ?
            1 : (oNw < cw ? 1 : cw / (Double(maxTypersCount - 1) * oMaxW + padding * 2))
            let maxW = oMaxW * lwScale
            let hd = Sheet.pitchHeight
            
            let plh = 0.5
            for pitchAndTyper in cbpt.pitchAndTypers {
                let py = self.y(fromPitch: Rational(pitchAndTyper.pitch))
                let nw = maxW * Double(pitchAndTyper.typers.count - 1)
                for (ti, typer) in pitchAndTyper.typers.enumerated() {
                    let fx = chordCenterX - nw / 2 + maxW * Double(ti)
                    let rect = Rect(x: fx - plh * lwScale / 2, y: py - hd / 2,
                                    width: plh * lwScale, height: hd)
                    chordTypeRectDic0.append(rect, forKey: typer.type)
                }
                for (ti, typer) in pitchAndTyper.typers.enumerated() {
                    let h = plh / Double(pitchAndTyper.typers.count)
                    let rect = Rect(x: chordSX, y: py - plh / 2 + h * Double(ti),
                                    width: chordW, height: h)
                    chordTypeRectDic1.append(rect, forKey: typer.type)
                }
            }
        }
        
        return chordTypeRectDic0.map { (type, rects) in
            .init(path: .init(rects.map { .init($0) }), fillType: .color(type.color))
        } + chordTypeRectDic1.map { (type, rects) in
            .init(path: .init(rects.map { .init($0) }), fillType: .color(type.color))
        }
    }
    
    func mainLineBounds(at i: Int) -> Rect? {
        noteLines[i].bounds
    }
    
    func octaveNode(noteIs: [Int], _ color: Color = .octave) -> Node {
        var vs = Set<Rational>()
        let nodes = noteIs.flatMap {
            let node = notesNode.children[$0].children[0].clone
            return octaveNodes(fromPitch: model.notes[$0].firstPitch, node, color,
                               addedPitches: &vs)
        }
        return Node(children: nodes)
    }
    func octaveNode(fromPitch pitch: Rational, _ noteNode: Node, enabledPitchLine: Bool = true,
                     _ color: Color = .octave) -> Node {
        var vs = Set<Rational>()
        return Node(children: octaveNodes(fromPitch: pitch, noteNode,
                                          enabledPitchLine: enabledPitchLine, color,
                                          addedPitches: &vs))
    }
    func octaveNodes(fromPitch pitch: Rational, _ noteNode: Node, enabledPitchLine: Bool = true,
    _ color: Color = .octave, addedPitches: inout Set<Rational>) -> [Node] {
        let pitchRange = Score.pitchRange
        guard pitchRange.contains(pitch) else { return .init() }
        let pitchLineColor = Set(model.scales).contains(pitch.mod(12)) ?
        color :
        color.with(lightness: min(color.lightness * 1.2, Color.whiteLightness))
        let sx = x(atBeat: model.beatRange.start)
        let ex = x(atBeat: model.beatRange.end)
        
        let pd = 12 * pitchHeight
        var nodes = [Node](), nPitch = pitch, npd = 0.0
        let plw = 0.5
        if enabledPitchLine && !addedPitches.contains(nPitch) {
            nodes.append(Node(path: .init(Rect(x: sx, y: y(fromPitch: nPitch) - plw / 2,
                                               width: ex - sx, height: plw)),
                              fillType: .color(pitchLineColor)))
            addedPitches.insert(nPitch)
        }
        while true {
            nPitch -= 12
            npd -= pd
            guard pitchRange.contains(nPitch) else { break }
            let node = noteNode.clone
            node.fillType = .color(color)
            node.attitude.position.y = npd
            nodes.append(node)
            if enabledPitchLine && !addedPitches.contains(nPitch) {
                nodes.append(Node(path: .init(Rect(x: sx, y: y(fromPitch: nPitch) - plw / 2,
                                                   width: ex - sx, height: plw)),
                                  fillType: .color(pitchLineColor)))
                addedPitches.insert(nPitch)
            }
        }
        nPitch = pitch
        npd = 0.0
        while true {
            nPitch += 12
            npd += pd
            guard pitchRange.contains(nPitch) else { break }
            let node = noteNode.clone
            node.fillType = .color(color)
            node.attitude.position.y = npd
            nodes.append(node)
            if enabledPitchLine && !addedPitches.contains(nPitch) {
                nodes.append(Node(path: .init(Rect(x: sx, y: y(fromPitch: nPitch) - plw / 2,
                                                   width: ex - sx, height: plw)),
                                  fillType: .color(pitchLineColor)))
                addedPitches.insert(nPitch)
            }
        }
        return nodes
    }
    
    func keyBeatRect(fromBeat beat: Rational) -> Rect {
        let x = x(atBeat: beat)
        let pitchRange = Score.pitchRange
        let sy = y(fromPitch: pitchRange.start)
        let ey = y(fromPitch: pitchRange.end)
        let lw = ScoreView.beatLineWidth(atBeat: beat)
        return .init(x: x - lw / 2, y: sy, width: lw, height: ey - sy)
    }
    func keyBeatKnobRect(fromBeat beat: Rational) -> Rect {
        let nx = x(atBeat: beat)
        let knobW = Sheet.knobWidth, knobH = Sheet.knobHeight
        let nKnobW = beat % EditGrid.beatInterval == 0 ? knobW : knobW / 2
        return Rect(x: nx - nKnobW / 2, y: timelineCenterY - knobH / 2,
                    width: nKnobW, height: knobH)
    }
    func scaleRect(fromPitch pitch: Rational) -> Rect {
        let sx = x(atBeat: model.beatRange.start)
        let ex = x(atBeat: model.beatRange.end)
        let y = y(fromPitch: pitch)
        let lw = pitch.isInteger ? 0.5 : 0.25
        return .init(x: sx, y: y - lw / 2, width: ex - sx, height: lw)
    }
    func scaleRects(fromUnison unison: Rational) -> [Rect] {
        let pitchRange = Score.pitchRange
        let sx = x(atBeat: model.beatRange.start)
        let ex = x(atBeat: model.beatRange.end)
        
        var rects = [Rect](), pitch = unison
        while pitch < pitchRange.start { pitch += 12 }
        while pitchRange.contains(pitch) {
            let y = y(fromPitch: pitch)
            let lw = pitch.isInteger ? 0.5 : 0.25
            rects.append(.init(x: sx, y: y - lw / 2, width: ex - sx, height: lw))
            pitch += 12
        }
        return rects
    }
    func scaleKnobRect(fromPitch pitch: Rational) -> Rect {
        let lw = pitch.isInteger ? 1.0 : 0.5, scaleW = 4.0
        let sx = x(atBeat: model.beatRange.start)
        let py = self.y(fromPitch: pitch)
        return Rect(x: sx - Sheet.textPadding.width / 2 - scaleW / 2, y: py - lw / 2,
                    width: scaleW, height: lw)
    }
    func scaleNode(mainPitch: Rational,
                   mainColor: Color = .subInterpolated, _ color: Color = .subBorder) -> Node {
        let score = model, pitchRange = Score.pitchRange
        let scaleSet = Set(score.scales.map { $0.mod(12) })
        let sx = x(atBeat: score.beatRange.start)
        let ex = x(atBeat: score.beatRange.end)
        
        let roundedSPitch = pitchRange.start.rounded(.down)
        var cPitch = roundedSPitch
        var pathlines = [Pathline]()
        while cPitch <= pitchRange.end {
            if cPitch >= pitchRange.start {
                if scaleSet.contains(cPitch.mod(12)) {
                    let plw = cPitch.isInteger ? 0.5 : 0.25
                    let py = self.y(fromPitch: cPitch)
                    let rect = Rect(x: sx, y: py - plw / 2, width: ex - sx, height: plw)
                    pathlines.append(.init(rect))
                }
            }
            cPitch += 1
        }
        
        for scale in score.scales {
            let unison = scale.mod(12)
            if !unison.isInteger {
                var pitch = unison
                while pitch < pitchRange.start { pitch += 12 }
                while pitchRange.contains(pitch) {
                    let plw = 0.25
                    let py = self.y(fromPitch: pitch)
                    let rect = Rect(x: sx, y: py - plw / 2, width: ex - sx, height: plw)
                    pathlines.append(.init(rect))
                    pitch += 12
                }
            }
        }
        
        let py = self.y(fromPitch: mainPitch)
        let plw = mainPitch.isInteger ? 0.5 : 0.25
        return .init(children: [.init(path: .init(pathlines), fillType: .color(color)),
                                .init(path: .init(Rect(x: sx, y: py - plw / 2, width: ex - sx, height: plw)), fillType: .color(mainColor))])
    }
    
    func draftNoteNode(from note: Note) -> Node {
        mainLineNoteNode(from: note, color: .draft.with(opacity: 0.1))
    }
    func mainLineNoteNode(from note: Note, color: Color) -> Node {
        let noteNode = noteNode(from: note).node.children[0]
        noteNode.fillType = .color(color)
        return noteNode
    }
    
    func noteNode(from note: Note, color: Color? = nil,
                  lineWidth: Double? = nil) -> (node: Node,
                                                toneNode: Node,
                                                reverbNode: Node,
                                                noteLine: Pointline) {
        guard note.beatRange.length > 0 else {
            let path = Path(Rect(.init(x(atBeat: note.beatRange.start),
                                       y(fromPitch: note.firstPitch)),
                                 distance: 0).outsetBy(dx: 0.25, dy: 1))
            return (.init(children: [.init(path: path,
                                           fillType: .color(color != nil ? color! : .content))],
                          path: path),
                    .init(), .init(), .init())
        }
        let nh = noteH(from: note)
        let halfNH = nh / 2
        let nsx = x(atBeat: note.beatRange.start)
        let ny = y(fromPitch: note.firstPitch)
        let nw = width(atDurBeat: max(note.beatRange.length, EditGrid.fullEditBeatInterval))
        let attackW = width(atDurSec: Waveclip.default.attackSec)
        let attackX = nsx + attackW
        let nex = nsx + nw
        let fScale = Waveclip.default.attackSec > .init(model.sec(fromBeat: note.beatRange.length)) ? 1.25 : 0.75
        
        let spectlopeY = y(fromPitch: note.firstPitch) + Sheet.tonePadding
        let overtoneHalfH = 0.25
        let spectlopeH = note.spectlopeHeight
        let evenY = Sheet.evenY + spectlopeY
        let spectlopeMaxY = spectlopeY + spectlopeH
        
        var stereoLinePath, mainLinePath: Path, lyricLinePath: Path?, mainEvenLinePath: Path?, lyricLinePathlines = [Pathline]()
        var spectlopeFqLinePathlines = [Pathline](), spectlopeLinePathlines = [Pathline]()
        var spectlopeTonePanelNodes = [Node](), noteLinePs = [Point]()
        let knobR = 0.25, sprolR = 0.125
        
        let lyricNodes: [Node] = note.pits.enumerated().compactMap { (pitI, pit) in
            let p = pitPosition(atPit: pitI, from: note)
            if !pit.lyric.isEmpty {
                if pit.lyric == "[" {
                    lyricLinePathlines.append(.init(Rect(x: p.x - 0.25, y: p.y - 3,
                                                         width: 0.5, height: 3)))
                    lyricLinePathlines.append(.init(Rect(x: p.x - 0.25, y: p.y - 3.5,
                                                         width: 1.5, height: 0.5)))
                    return nil
                } else if pit.lyric == "]" {
                    lyricLinePathlines.append(.init(Rect(x: p.x - 0.25, y: p.y - 3,
                                                         width: 0.5, height: 3)))
                    lyricLinePathlines.append(.init(Rect(x: p.x - 0.25 - 1, y: p.y - 3.5,
                                                         width: 1.5, height: 0.5)))
                    return nil
                } else {
                    let fHeight = 5.0
                    let lyricText = Text(string: pit.lyric, size: fHeight)
                    let typesetter = lyricText.typesetter
                    let lh = fHeight * 2
                    lyricLinePathlines.append(.init(Rect(x: p.x - 0.125, y: p.y - lh,
                                                         width: 0.25, height: lh)))
                    let isEnabledLyric = !Phoneme.phonemes(fromHiragana: pit.lyric,
                                                           nextPhoneme: nil).isEmpty
                    return .init(attitude: .init(position: .init(p.x + 1,
                                                                 p.y - lh + typesetter.height / 2)),
                                 path: typesetter.path(), fillType: .color(color ?? (isEnabledLyric ? .content : .interpolated)))
                }
            } else {
                return nil
            }
        }
        
        func tonePanelPitchY(fromPitch pitch: Double, atY y: Double) -> Double {
            pitch.clipped(min: Score.doubleMinPitch, max: Score.doubleMaxPitch,
                          newMin: 0, newMax: spectlopeH) + y
        }
        func backSpectlopePitchY(fromPitch pitch: Double) -> Double {
            y(fromPitch: pitch)
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
        func triangleStrip(_ wps: [LinePoint], isSnap: Bool = false) -> TriangleStrip {
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
                    if isSnap {
                        let angle0 = Edge(wps[i - 1].point, wps[i].point).angle()
                        let angle1 = Edge(wps[i].point, wps[i + 1].point).angle()
                        if wps[i - 1].point.y == wps[i].point.y {
                            ps.append(wp.point + Point(0, wp.h))
                            ps.append(wp.point - Point(0, wp.h))
                            ps.append(wp.point + Point(0, wp.h))
                            ps.append(wp.point - Point(0, wp.h))
                        } else if wps[i].point.y == wps[i + 1].point.y {
                            ps.append(wp.point + Point(0, wp.h))
                            ps.append(wp.point - Point(0, wp.h))
                            ps.append(wp.point + Point(0, wp.h))
                            ps.append(wp.point - Point(0, wp.h))
                        } else if abs(Point.differenceAngle(wps[i - 1].point,
                                                            wps[i].point,
                                                            wps[i + 1].point)) < .pi / 4 {
                            let p0 = PolarPoint(wp.h, angle0 + .pi / 2).rectangular
                            let p1 = PolarPoint(wp.h, angle1 + .pi / 2).rectangular
                            ps.append(wp.point + p0.mid(p1))
                            ps.append(wp.point - p0.mid(p1))
                            ps.append(wp.point + p0.mid(p1))
                            ps.append(wp.point - p0.mid(p1))
                        } else {
                            let p0 = PolarPoint(wp.h, angle0 + .pi / 2).rectangular
                            ps.append(wp.point + p0)
                            ps.append(wp.point - p0)
                            let p1 = PolarPoint(wp.h, angle1 + .pi / 2).rectangular
                            ps.append(wp.point + p1)
                            ps.append(wp.point - p1)
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
            }
            return .init(points: ps)
        }
        func triangleTopPs(_ wps: [LinePoint]) -> [Point] {
            var ps = [Point](capacity: wps.count * 2)
            guard wps.count >= 2 else {
                return wps.isEmpty ? [] : [wps[0].point]
            }
            for (i, wp) in wps.enumerated() {
                if i == 0 || i == wps.count - 1 {
                    if wp.h == 0 {
                        ps.append(.init(wp.x, wp.y))
                    } else if i == 0 {
                        let angle = Edge(wps[0].point, wps[1].point).angle()
                        let p = PolarPoint(wp.h, angle + .pi / 2).rectangular
                        ps.append(wp.point + p)
                    } else {
                        let angle = Edge(wps[i - 1].point, wps[i].point).angle()
                        let p = PolarPoint(wp.h, angle + .pi / 2).rectangular
                        ps.append(wp.point + p)
                    }
                } else {
                    let angle0 = Edge(wps[i - 1].point, wps[i].point).angle()
                    let angle1 = Edge(wps[i].point, wps[i + 1].point).angle()
                    let p0 = PolarPoint(wp.h, angle0 + .pi / 2).rectangular
                    ps.append(wp.point + p0)
                    let p1 = PolarPoint(wp.h, angle1 + .pi / 2).rectangular
                    ps.append(wp.point + p1)
                }
            }
            return ps
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

        let borderWidth = 0.0625
        
        let isOneOvertone = note.isOneOvertone
        let isEven = !isOneOvertone && note.containsNoOneEven
        let isFullNoise = note.isFullNoise
        let mainLineHalfH = noteMainH(from: note) / 2
        let mainEvenLineHalfH = mainLineHalfH * 0.375
        let mainLineColors, mainEvenLineColors, stereoLineColors: [Color]
        var knobPRCs: [(p: Point, r: Double, isCircle: Bool, color: Color)]
        var toneFrames = [Rect]()
        var tonePanelKnobPRCs: [(p: Point, r: Double, color: Color)]
        
        func beatsAndPitIsDic(from note: Note) -> (beats: [Rational],
                                                   pitIsDic: [Rational: [Int]]) {
            var beatSet = Set<Rational>(minimumCapacity: Int(note.beatRange.length / .init(1, 72)))
            var nBeat = note.beatRange.start
            while nBeat <= note.beatRange.end {
                beatSet.insert(nBeat)
                nBeat += .init(1, 72)
            }
            if nBeat != note.beatRange.end {
                beatSet.insert(note.beatRange.end)
            }
            let pitIsDic = note.pits.enumerated().reduce(into: [Rational: [Int]](minimumCapacity: note.pits.count)) {
                let beat = note.beatRange.start + $1.element.beat
                if $0[beat] != nil {
                    $0[beat]?.append($1.offset)
                } else {
                    $0[beat] = [$1.offset]
                }
            }
            let pitBeatSet = Set(note.pits.map { note.beatRange.start + $0.beat })
            beatSet.formUnion(pitBeatSet)
            let beats = beatSet.sorted()
            return (beats, pitIsDic)
        }
        
        if note.isSimpleLyric {
            let nNote = note.withRendable(tempo: model.tempo)
            let (beats, pitIsDic) = beatsAndPitIsDic(from: nNote)
            let lHalfH = mainLineHalfH / 2
            var lmps = [LinePoint]()
            lmps.append(.init(x(atBeat: nNote.beatRange.start),
                              y(fromPitch: nNote.firstPitch), lHalfH, .content))
            var preBeatY: Double?
            for beat in beats {
                let noteX = x(atBeat: beat), noteY = noteY(atBeat: beat, from: nNote)
                if (pitIsDic[beat]?.count ?? 0) >= 2, let preBeatY {
                    lmps.append(.init(noteX, preBeatY, lHalfH, .content))
                }
                lmps.append(.init(noteX, noteY, lHalfH, .content))
                preBeatY = noteY
            }
            lmps.append(.init(x(atBeat: nNote.beatRange.end),
                              noteY(atBeat: nNote.beatRange.end, from: nNote), lHalfH, .content))
            
            for (pitI, pit) in nNote.pits.enumerated() {
                let p = pitPosition(atPit: pitI, from: nNote)
                let lh = 0.25, w = 1.0, h = 2.0
                if pit.lyric == "[" {
                    lyricLinePathlines.append(.init(Rect(x: p.x - lh / 2, y: p.y - h,
                                                         width: lh, height: h)))
                    lyricLinePathlines.append(.init(Rect(x: p.x - lh / 2, y: p.y - h - lh,
                                                         width: w, height: lh)))
                } else if pit.lyric == "]" {
                    lyricLinePathlines.append(.init(Rect(x: p.x - lh / 2, y: p.y - h,
                                                         width: lh, height: h)))
                    lyricLinePathlines.append(.init(Rect(x: p.x + lh / 2 - w, y: p.y - h - lh,
                                                         width: w, height: lh)))
                }
            }
            
            lyricLinePath = .init(triangleStrip(lmps))
        }
        
        if note.pits.count >= 2 {
            let t = note.spectlopeHeight.clipped(min: Sheet.spectlopeHeight,
                                                 max: Sheet.maxSpectlopeHeight,
                                                 newMin: 0, newMax: 1)
            let toneMaxY = toneMaxY(from: note)
            
            let (beats, pitIsDic) = beatsAndPitIsDic(from: note)
            
            var ps = [LinePoint](), eps = [LinePoint](), mps = [LinePoint](), meps = [LinePoint]()
            var isPreJI = note.firstPitResult.isJustIntonation
            var isUseMPColor = isPreJI
            ps.append(.init(nsx, ny, halfNH, Self.color(from: note.firstStereo)))
            noteLinePs.append(.init(nsx, ny))
            mps.append(.init(nsx, ny, mainLineHalfH, isPreJI ? .justFit : .content))
            if isEven {
                meps.append(.init(nsx, ny, mainEvenLineHalfH, Self.color(fromScale: note.firstTone.overtone.evenAmp)))
            }
            eps.append(.init(nsx, evenY, overtoneHalfH, Self.color(fromScale: note.firstTone.overtone.evenAmp)))
            
            let tempo = model.tempo
            let nNote = note.withRendable(tempo: tempo)
            let pitbend = nNote.pitbend(fromTempo: tempo)
            let ns: [(beat: Rational, result: Note.PitResult, sumTone: Double)] = beats.map { beat in
                let result = nNote.pitResult(atBeat: .init(beat - nNote.beatRange.start),
                                             tempo: Double(tempo), from: pitbend)
                return (beat, result, isOneOvertone ? 0 : result.sumTone)
            }
            let maxSumTone = ns.maxValue { $0.sumTone } ?? 0
            for n in ns {
                if n.result.isJustIntonation {
                    isUseMPColor = true
                    isPreJI = true
                } else if !n.result.isStraight {
                    isPreJI = false
                }
                let noteX = x(atBeat: n.beat)
                let evenAmp = Self.color(fromScale: n.result.tone.overtone.evenAmp)
                if let pitIs = pitIsDic[n.beat] {
                    let scale = pitIs.count >= 2 ? 0.5 : 1.0
                    for pitI in pitIs {
                        var stereo = note.pits[pitI].stereo
                        if !isOneOvertone {
                            stereo.volm *= maxSumTone == 0 ? 0 : n.sumTone / maxSumTone
                        }
                        let pitY = pitY(atPit: pitI, from: note)
                        ps.append(.init(noteX, pitY, halfNH * scale, Self.color(from: stereo)))
                        noteLinePs.append(.init(noteX, pitY))
                        mps.append(.init(noteX, pitY, mainLineHalfH * scale, isPreJI ? .justFit : .content))
                        if isEven {
                            meps.append(.init(noteX, pitY, mainEvenLineHalfH * scale, evenAmp))
                        }
                    }
                } else {
                    let noteY = noteY(atBeat: n.beat, from: note)
                    var stereo = n.result.stereo
                    if !isOneOvertone {
                        stereo.volm *= maxSumTone == 0 ? 0 : n.sumTone / maxSumTone
                    }
                    ps.append(.init(noteX, noteY, halfNH, Self.color(from: stereo)))
                    noteLinePs.append(.init(noteX, noteY))
                    mps.append(.init(noteX, noteY, mainLineHalfH, isPreJI ? .justFit : .content))
                    if isEven {
                        meps.append(.init(noteX, noteY, mainEvenLineHalfH, evenAmp))
                    }
                }
                eps.append(.init(noteX, evenY, overtoneHalfH, evenAmp))
            }
            
            let lastNoteX = nsx + nw
            let lastNoteY = noteY(atBeat: note.beatRange.end, from: note)
            ps.append(.init(lastNoteX, lastNoteY, 0, ps.last!.color))
            noteLinePs.append(.init(lastNoteX, lastNoteY))
            mps.append(.init(lastNoteX, lastNoteY, mainLineHalfH / 4, isPreJI ? .justFit : .content))
            if isEven {
                meps.append(.init(lastNoteX, lastNoteY, mainEvenLineHalfH / 4, meps.last!.color))
            }
            
            if attackX - ps[0].x > 0 {
                for i in 1 ..< ps.count {
                    let preP = ps[i - 1], p = ps[i]
                    if attackX >= preP.x && attackX < p.x {
                        for j in i.range {
                            ps[j].h *= ps[j].x.clipped(min: ps[0].x, max: attackX, newMin: fScale, newMax: 1)
                        }
                        let t = attackX.clipped(min: preP.x, max: p.x, newMin: 0, newMax: 1)
                        ps.insert(.init(attackX,
                                        .linear(preP.y, p.y, t: t),
                                        .linear(preP.h, p.h, t: t),
                                        .rgbLinear(preP.color, p.color, t: t)), at: i)
                        break
                    }
                }
            }
            
            knobPRCs = note.pits.enumerated().map { (pi, pit) in
                (.init(x(atBeat: note.beatRange.start + pit.beat),
                       y(fromPitch: note.pitch + pit.pitch)),
                 (note.beatRange.start + pit.beat) % EditGrid.beatInterval == 0
                 && (note.pitch + pit.pitch).isInteger ? knobR : knobR / 2,
                 pi != 0,
                 .background)
            }
            
            stereoLinePath = .init(triangleStrip(ps, isSnap: true))
            stereoLineColors = colors(ps)
            
            mainLinePath = .init(triangleStrip(mps))
            mainLineColors = isUseMPColor ? colors(mps) : [.content]
            
            if isEven {
                mainEvenLinePath = .init(triangleStrip(meps))
                mainEvenLineColors = colors(meps)
            } else {
                mainEvenLineColors = []
            }
            
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
            
            func pAndColors(x: Double, pitch: Double, minY: Double,
                            sprols: [Sprol], isBack: Bool) -> [PAndColor] {
                var vs = [PAndColor](capacity: sprols.count)
                
                let s = isBack ? 0.1 : 1
                func append(_ sprol: Sprol) {
                    let y = isBack ? backSpectlopePitchY(fromPitch: sprol.pitch) : tonePanelPitchY(fromPitch: sprol.pitch, atY: minY)
                    let color = Self.color(fromScale: sprol.volm * s, noise: sprol.noise)
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
            
            var ox = nsx, oy = Double.linear(y(fromPitch: note.firstPitch) + Sheet.tonePadding,
                                             toneMaxY,
                                             t: t)
            var currentY = oy
            var sprolKnobPAndRs = [(Point, Double, Color)](capacity: note.pits.count)
            func curveSpectlopeNodes() -> [Node] {
                struct VItem {
                    var vs: [[PAndColor]]
                    var fqPs: [Point]
                    var y: Double
                }
                var vItems = [VItem](), vItem = VItem(vs: [], fqPs: [], y: oy),
                    pitIs = [Int](),
                    lastV: [PAndColor]?, isLastAppned = false
                for (bi, n) in ns.enumerated() {
                    let nBeat = n.beat
                    let nx = self.x(atBeat: nBeat)
                    let sprols = pitbend.spectlope(atSec: Double(model.sec(fromBeat: nBeat - note.beatRange.start))).sprols
                    let psPitch = .init(note.pitch) + n.result.pitch.doubleValue
                    let noteY = y(fromPitch: psPitch)
                    
                    let topY = noteY
                    if currentY - topY < Sheet.tonePadding / 2
                        || currentY - topY > Sheet.tonePadding * 3 / 2.0
                        || (pitIsDic[nBeat]?.count ?? 0) >= 2 {
                        
                        currentY = Double.linear(topY + Sheet.tonePadding, toneMaxY, t: t)
                    }
                    let ny = currentY
                    if pitIsDic[nBeat]?.count == 1 {
                        oy = ny
                        vItem.y = ny
                    }
                    
                    func appendKnobs(at pi: Int, y: Double) {
                        let nx = x(atBeat: note.pits[pi].beat + note.beatRange.start)
                        let p = Point(nx, y)
                        let sprols = note.pits[pi].tone.spectlope.sprols
                        
                        let sprolYs = sprols.enumerated().map { (tonePanelPitchY(fromPitch: $0.element.pitch, atY: p.y),
                                                                 $0.offset > 0 && sprols[$0.offset - 1].pitch > $0.element.pitch,
                                                                 $0.element) }.sorted { $0.0 < $1.0 }
                        sprolKnobPAndRs += sprolYs.enumerated().map { (spi, v) in
                            let sprol = v.2
                            let d0 = spi + 1 < sprols.count ? (sprolYs[spi + 1].0 - sprolYs[spi].0) / 2 : sprolR
                            let d1 = spi - 1 >= 0 ? (sprolYs[spi].0 - sprolYs[spi - 1].0) / 2 : sprolR
                            return (Point(p.x, sprolYs[spi].0),
                                    min(d0, d1).clipped(min: 0.015625 / 2, max: sprolR),
                                    v.1 ? Color.warning : (sprol.volm == 0 ? Color.subBorder : Color.background))
                        }
                        
                        let knobPRC = knobPRCs[pi]
                        spectlopeLinePathlines.append(.init(Edge(knobPRC.p + .init(0, knobPRC.r * 1.5),
                                                                 .init(knobPRC.p.x, y + spectlopeH))))
                    }
                    
                    if let nPitI = pitIsDic[nBeat]?.first {
                        pitIs.append(nPitI)
                    }
                    if oy != ny || bi == beats.count - 1 {
                        for pitI in pitIs {
                            appendKnobs(at: pitI, y: oy)
                        }
                        toneFrames.append(Rect(x: ox, y: oy, width: nx - ox, height: spectlopeH))
                        let v = pAndColors(x: nx, pitch: psPitch, minY: 0, sprols: sprols,
                                           isBack: false)
                        vItem.vs.append(v)
                        if !isFullNoise {
                            let fqLineP = Point(nx, tonePanelPitchY(fromPitch: psPitch, atY: 0))
                            vItem.fqPs.append(fqLineP)
                        }
                        vItems.append(vItem)
                        vItem = .init(vs: [], fqPs: [], y: ny)
                        
                        ox = nx
                        oy = ny
                        
                        pitIs = []
                    }
                    if let nPitIs = pitIsDic[nBeat], nPitIs.count >= 2 {
                        appendKnobs(at: nPitIs[.last], y: ny)
                    }
                    
                    let v = pAndColors(x: nx, pitch: psPitch, minY: 0, sprols: sprols, isBack: false)
                    
                    isLastAppned = vItem.vs.last != v
                    if isLastAppned {
                        if let v = lastV {
                            vItem.vs.append(v)
                        }
                        vItem.vs.append(v)
                    }
                    
                    if !isFullNoise {
                        let fqLineP = Point(nx, tonePanelPitchY(fromPitch: psPitch, atY: 0))
                        if vItem.fqPs.last?.y != fqLineP.y {
                            vItem.fqPs.append(fqLineP)
                        }
                    }
                }
                
                var nodes = [Node]()
                for vItem in vItems {
                    let vs = vItem.vs
                    if !vs.isEmpty && vs[0].count >= 2 {
                        for yi in 1 ..< vs[0].count {
                            var ps = [Point](capacity: 2 * vs.count)
                            var colors = [Color](capacity: 2 * vs.count)
                            for xi in vs.count.range {
                                ps.append(vs[xi][yi - 1].p + .init(0, vItem.y))
                                ps.append(vs[xi][yi].p + .init(0, vItem.y))
                                colors.append(vs[xi][yi - 1].color)
                                colors.append(vs[xi][yi].color)
                            }
                            let tst = TriangleStrip(points: ps)
                            
                            nodes.append(.init(path: Path(tst), fillType: .maxGradient(colors)))
                        }
                    }
                    
                    if !vItem.fqPs.isEmpty {
                        spectlopeFqLinePathlines += [.init(vItem.fqPs.map { $0 + .init(0, vItem.y) })]
                    }
                }
                return nodes
            }
            spectlopeTonePanelNodes += curveSpectlopeNodes()
            tonePanelKnobPRCs = sprolKnobPAndRs
        } else {
            let color = Self.color(from: note.pits[0].stereo)
            var ts: [LinePoint] = [.init(nsx, ny, halfNH * fScale,
                                         Self.color(from: note.pits[0].stereo.with(volm: 0)))]
            if attackX < nsx + nw {
                ts.append(.init(attackX, ny, halfNH, color))
            }
            ts += [.init(nsx + nw, ny, halfNH, color)]
            stereoLinePath = .init(triangleStrip(ts))
            stereoLineColors = [color]
            
            let mainLineColor = Chord.unisonFromApproximationJustIntonation(pitch: note.firstPitch) != nil ? Color.justFit : Color.content
            mainLinePath = .init(triangleStrip([.init(nsx, ny, mainLineHalfH, mainLineColor),
                                                .init(nsx + nw, ny, mainLineHalfH, mainLineColor)]))
            mainLineColors = [mainLineColor]
            
            noteLinePs.append(.init(nsx, ny))
            noteLinePs.append(.init(nsx + nw, ny))
            
            if isEven {
                let mainEvenLineColor = Self.color(fromScale: note.firstTone.overtone.evenAmp)
                mainEvenLinePath = .init(triangleStrip([.init(nsx, ny, mainEvenLineHalfH, mainEvenLineColor),
                                                        .init(nsx + nw, ny, mainEvenLineHalfH, mainEvenLineColor),
                                                        .init(nsx + nw, ny, mainEvenLineHalfH / 4, mainEvenLineColor)]))
                mainEvenLineColors = [mainEvenLineColor]
            } else {
                mainEvenLineColors = []
            }
            
            knobPRCs = note.pits.enumerated().map { (pi, pit) in
                (.init(x(atBeat: note.beatRange.start + pit.beat),
                       y(fromPitch: note.pitch + pit.pitch)),
                 (note.beatRange.start + pit.beat) % EditGrid.beatInterval == 0
                 && note.firstPitch.isInteger ? knobR : knobR / 2,
                 pi != 0,
                 .background)
            }
            
            let fPitNx = x(atBeat: note.beatRange.start + note.firstPit.beat)
            
            let sprols = note.firstTone.spectlope.sprols
            let noteY = spectlopeY
            let sprolYs = sprols.enumerated().map { (tonePanelPitchY(fromPitch: $0.element.pitch, atY: noteY),
                                                     $0.offset > 0 && sprols[$0.offset - 1].pitch > $0.element.pitch,
                                                     $0.element) }.sorted { $0.0 < $1.0 }
            let sprolKnobPRCs = sprolYs.enumerated().map { (spi, v) in
                let sprol = v.2
                let d0 = spi + 1 < sprols.count ? (sprolYs[spi + 1].0 - sprolYs[spi].0) / 2 : sprolR
                let d1 = spi - 1 >= 0 ? (sprolYs[spi].0 - sprolYs[spi - 1].0) / 2 : sprolR
                return (Point(fPitNx, sprolYs[spi].0),
                        min(d0, d1).clipped(min: 0.015625 / 2, max: sprolR),
                        v.1 ? Color.warning : (sprol.volm == 0 ? Color.subBorder : Color.background))
            }
            tonePanelKnobPRCs = sprolKnobPRCs
            
            func spectlopeNodes(isBack: Bool) -> [Node] {
                var nNodes = [Node]()
                var preY = isBack ? backSpectlopePitchY(fromPitch: 0) : tonePanelPitchY(fromPitch: 0, atY: spectlopeY)
                let s = isBack ? 0.1 : 1
                var preColor = Self.color(fromScale: (note.firstTone.spectlope.sprols.first?.volm ?? 0) * s,
                                          noise: note.firstTone.spectlope.sprols.first?.noise ?? 0)
                func append(_ sprol: Sprol) {
                    let y = isBack ? backSpectlopePitchY(fromPitch: sprol.pitch) : tonePanelPitchY(fromPitch: sprol.pitch, atY: spectlopeY)
                    let color = Self.color(fromScale: sprol.volm * s, noise: sprol.noise)
                    
                    let tst = TriangleStrip(points: [.init(nsx, preY), .init(nsx, y),
                                                     .init(nsx + nw, preY), .init(nsx + nw, y)])
                    let colors = [preColor, color, preColor, color]
                    
                    nNodes.append(.init(path: Path(tst), fillType: .maxGradient(colors)))
                    preY = y
                    preColor = color
                }
                for sprol in note.firstTone.spectlope.sprols {
                    append(sprol)
                }
                append(.init(pitch: Score.doubleMaxPitch,
                             volm: note.firstTone.spectlope.sprols.last?.volm ?? 0,
                             noise: note.firstTone.spectlope.sprols.last?.noise ?? 0))
                return nNodes
            }
            spectlopeTonePanelNodes += spectlopeNodes(isBack: false)
            
            if !isFullNoise {
                let fqY = tonePanelPitchY(fromPitch: .init(note.firstPitch), atY: spectlopeY)
                spectlopeFqLinePathlines = [.init([Point(nsx, fqY), Point(nsx + nw, fqY)])]
            }
            
            spectlopeLinePathlines += knobPRCs.map {
                .init(Edge($0.p + .init(0, $0.r * 1.5), .init($0.p.x, spectlopeMaxY)))
            }
            
            toneFrames.append(Rect(x: nsx, y: spectlopeY, width: nex - nsx, height: spectlopeH))
        }
        
        let isMinSpectlopeHeight = note.spectlopeHeight == Sheet.spectlopeHeight
        let isHiddenFullEdit = isMinSpectlopeHeight ? !isFullEdit : !isEditTone
        
        var nodes = [Node]()
        if note.isSimpleLyric {
            let x = x(atBeat: note.beatRange.start)
            let y = y(fromPitch: .init(note.f0Pitch))
            lyricLinePathlines.append(.init(Rect(x: x - 0.125, y: min(ny, y),
                                                 width: 0.25, height: abs(ny - y))))
            lyricLinePathlines.append(.init(Rect(x: x - 0.125, y: y - 0.25,
                                                 width: 3, height: 0.5)))
            knobPRCs.append((.init(x, ny - 10), knobR, true, .background))
        }
        nodes.append(.init(path: stereoLinePath,
                           fillType: color != nil ? .color(color!) : (stereoLineColors.count == 1 ? .color(stereoLineColors[0]) : .gradient(stereoLineColors))))
        if let lyricLinePath {
            nodes.append(.init(path: lyricLinePath, fillType: .color(.interpolated)))
        }
        nodes.append(.init(path: mainLinePath, fillType: color != nil ? .color(color!) : (mainLineColors.count == 1 ? .color(mainLineColors[0]) : .gradient(mainLineColors))))
        nodes.append(.init(path: Path(Rect(x: nsx, y: ny - halfNH * 0.75,
                                           width: overtoneHalfH / 4, height: nh * 0.75)),
                           fillType: .color(.content)))
        if let mainEvenLinePath {
            nodes.append(.init(path: mainEvenLinePath,
                               fillType: color != nil ? .color(color!) : (mainEvenLineColors.count == 1 ? .color(mainEvenLineColors[0]) : .gradient(mainEvenLineColors))))
        }
        nodes += lyricNodes
        nodes.append(.init(path: .init(lyricLinePathlines), fillType: .color(.content)))
        
        let knobPrcsDic = knobPRCs.reduce(into: [Color: [(p: Point, r: Double, isCircle: Bool)]]()) {
            if $0[$1.color] == nil {
                $0[$1.color] = [($1.p, $1.r, $1.isCircle)]
            } else {
                $0[$1.color]?.append(($1.p, $1.r, $1.isCircle))
            }
        }
        for (color, prs) in knobPrcsDic.sorted(by: { $0.key.lightness < $1.key.lightness }) {
            let backKnobPathlines = prs.map {
                $0.isCircle ?
                Pathline(circleRadius: $0.r * 1.5, position: $0.p) :
                Pathline(Rect($0.p, distance: $0.r * 1.5))
            }
            let knobPathlines = prs.map {
                $0.isCircle ?
                Pathline(circleRadius: $0.r, position: $0.p) :
                Pathline(Rect($0.p, distance: $0.r))
            }
            nodes.append(.init(path: .init(backKnobPathlines), fillType: .color(.content)))
            nodes.append(.init(path: .init(knobPathlines), fillType: .color(color)))
        }
        
        var tonePanelNodes = [Node]()
        let boxPath = Path(toneFrames.map { Pathline($0) })
        tonePanelNodes.append(.init(name: "toneFrame", path: boxPath, fillType: .color(.background)))
        tonePanelNodes += spectlopeTonePanelNodes
        if !spectlopeFqLinePathlines.isEmpty {
            tonePanelNodes.append(.init(path: Path(spectlopeFqLinePathlines),
                                   lineWidth: 0.03125,
                                   lineType: .color(.content)))
        }
        tonePanelNodes.append(.init(path: boxPath, lineWidth: borderWidth, lineType: .color(.subBorder)))
        if !spectlopeLinePathlines.isEmpty {
            tonePanelNodes.append(.init(path: Path(spectlopeLinePathlines),
                                        lineWidth: borderWidth,
                                        lineType: .color(.content)))
        }
        tonePanelNodes.append(.init(name: isMinSpectlopeHeight ? "fullGrid" : "point",
                                    isHidden: isHiddenFullEdit,
                                    path: Path(toneFrames.map {
            Pathline(Rect(origin: $0.minXMaxYPoint + .init(0, 0.03125), size: .init(width: $0.width, height: 0.0625)))
        }), fillType: .color(.content)))
        
        if !tonePanelKnobPRCs.isEmpty {
            let toneBackKnobPathlines = tonePanelKnobPRCs.map {
                Pathline(circleRadius: $0.r * 1.5, position: $0.p)
            }
            
            tonePanelNodes.append(.init(name: isMinSpectlopeHeight ? "fullGrid" : "point",
                                        isHidden: isHiddenFullEdit,
                                        path: .init(toneBackKnobPathlines),
                                        fillType: .color(.content)))
            let prsDic = tonePanelKnobPRCs.reduce(into: [Color: [(p: Point, r: Double)]]()) {
                if $0[$1.color] == nil {
                    $0[$1.color] = [($1.p, $1.r)]
                } else {
                    $0[$1.color]?.append(($1.p, $1.r))
                }
            }
            for (color, prs) in prsDic.sorted(by: { $0.key.lightness < $1.key.lightness }) {
                let toneKnobPathlines = prs.map {
                    Pathline(circleRadius: $0.r, position: $0.p)
                }
                
                tonePanelNodes.append(.init(name: isMinSpectlopeHeight ? "fullGrid" : "point",
                                            isHidden: isHiddenFullEdit,
                                            path: .init(toneKnobPathlines),
                                            fillType: .color(color)))
            }
        }
        
        if isOneOvertone || note.isDefaultTone {//
            tonePanelKnobPRCs = []
            tonePanelNodes = []
        }
        
        nodes += tonePanelNodes
        
        let boundingBox = nodes.reduce(into: Rect?.none) { $0 += $1.transformedDrawableBounds }
        let tonePanelBoundingBox = tonePanelNodes.reduce(into: Rect?.none) { $0 += $1.transformedDrawableBounds }
        return (Node(children: nodes,
                    path: boundingBox != nil ? Path(boundingBox!) : .init()),
                Node(children: [],
                     path: tonePanelBoundingBox != nil ? Path(tonePanelBoundingBox!) : .init()),
                Node(children: [],
                     path: .init()),
                Pointline(controls: noteLinePs.map { .init(point: $0) }))
    }
    
    func pointline(at noteI: Int) -> Pointline {
        noteLines[noteI]
    }
    func pointline(from note: Note) -> Pointline {
        if note.pits.count == 1 {
            let noteSX = x(atBeat: note.beatRange.start)
            let noteEX = x(atBeat: note.beatRange.end)
            let noteY = noteY(atBeat: note.beatRange.start, from: note)
            return .init(controls: [.init(point: .init(noteSX, noteY)),
                                    .init(point: .init(noteEX, noteY))])
        } else {
            let pitbend = note.pitbend(fromTempo: 120)
            var beat = note.beatRange.start, ps = [Point]()
            while beat <= note.beatRange.end {
                let result = note.pitResult(atBeat: .init(beat - note.beatRange.start),
                                            tempo: 120, from: pitbend)
                let noteX = x(atBeat: beat), noteY = noteY(from: result, from: note)
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
    static func lightness(fromScale scale: Double) -> Double {
        scale.clipped(min: 0, max: 1, newMin: 100, newMax: Color.content.lightness)
    }
    static func color(fromScale scale: Double) -> Color {
        Color(lightness: lightness(fromScale: scale))
    }
    static func color(fromScale scale: Double, noise: Double) -> Color {
        color(fromLightness: lightness(fromScale: scale * 0.75), noise: noise)
    }
    static func color(fromLightness l: Double, noise: Double) -> Color {
        let br = Double(Color(lightness: l, opacity: 0.1).rgba.r)
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
        let volm = Spectrogram.mainVolm(fromVolum: volm)
        let lightness = volm.clipped(min: Volm.minVolm, max: Volm.safeVolm,
                                     newMin: 100, newMax: Color.content.lightness)
        let l = Double(Color(lightness: lightness).rgba.r)
        return if pan == 0 {
            Color(red: 0.0, green: 0, blue: 0, opacity: 1 - l)
        } else if pan > 0 {
            Color(red: pan * Spectrogram.editRedRatio, green: 0, blue: 0, opacity: 1 - l)
        } else {
            Color(red: 0, green: -pan * Spectrogram.editGreenRatio, blue: 0, opacity: 1 - l)
        }
    }
    
    var clippableBounds: Rect? {
        mainFrame + timelineFrame
    }
    var transformedClippableBounds: Rect? {
        if let bounds = clippableBounds {
            bounds * node.localTransform
        } else {
            nil
        }
    }
    
    func isEditTone(from note: Note) -> Bool {
        let isMinSpectlopeHeight = note.spectlopeHeight == Sheet.spectlopeHeight
        return isMinSpectlopeHeight ? isFullEdit : isEditTone
    }
    
    func contains(_ p : Point, scale: Double) -> Bool {
        model.enabled
        && (containsTimeline(p, scale: scale)
            || containsIsShownSpectrogram(p, scale: scale)
            || containsMainFrame(p, scale: scale)
            || containsScaleFrame(p, scale: scale)
            || containsNote(p, scale: scale, enabledTone: true))
    }
    func containsMainFrame(_ p: Point, scale: Double) -> Bool {
        model.enabled && mainFrame.outset(by: 10 * scale).contains(p)
    }
    func containsScaleFrame(_ p: Point, scale: Double) -> Bool {
        model.enabled && scaleFrame.outset(by: 10 * scale).contains(p)
    }
    func containsTimeline(_ p : Point, scale: Double) -> Bool {
        model.enabled && timelineFrame.outsetBy(dx: 5 * scale, dy: 3 * scale).contains(p)
    }
    var timelineFrame: Rect {
        let sx = self.x(atBeat: model.beatRange.start)
        let ex = self.x(atBeat: model.endLoopDurBeat)
        return Rect(x: sx, y: timelineCenterY - Sheet.timelineHalfHeight,
                    width: ex - sx, height: Sheet.timelineHalfHeight * 2)
    }
    var transformedTimelineFrame: Rect? {
        timelineFrame
    }
    
    func keyBeatIndex(at p: Point, scale: Double) -> Int? {
        guard containsTimeline(p, scale: scale) else { return nil }
        let maxD = Sheet.keyframeEditDistance * scale
        let maxDS = maxD * maxD
        var minDS = Double.infinity, minI: Int?
        let score = model
        for (keyBeatI, keyBeat) in score.keyBeats.enumerated() {
            guard score.beatRange.contains(keyBeat) else { continue }
            let ds = p.x.distanceSquared(x(atBeat: keyBeat))
            if ds < minDS && ds < maxDS {
                minDS = ds
                minI = keyBeatI
            }
        }
        return minI
    }
    
    func isStraightWithSelection(atPit pitI: Int, atNote noteI: Int) -> Bool {
        if selectedNotePitSprolIs[noteI]?[pitI] == nil {
            let note = model.notes[noteI]
            let pit = note.pits[pitI]
            if pitI - 1 >= 0 {
                if pit.beat == note.pits[pitI - 1].beat {
                    return true
                }
                if pitI == note.pits.count - 1 && pitI - 2 >= 0
                    && note.pits[pitI - 1].beat == note.pits[pitI - 2].beat {
                    return true
                }
            }
            if pitI + 1 < note.pits.count {
                if pit.beat == note.pits[pitI + 1].beat {
                    return true
                }
                if pitI == 0 && pitI + 2 < note.pits.count
                    && note.pits[pitI + 1].beat == note.pits[pitI + 2].beat {
                    return true
                }
            }
        }
        return false
    }
    
    func noteIs(at p: Point, scale: Double, enabledTone: Bool = false) -> [Int] {
        guard let i = noteIndex(at: p, scale: scale, enabledTone: enabledTone) else { return [] }
        return selectedNotePitSprolIs[i] != nil ? selectedNotePitSprolIs.map { $0.key }.sorted() : [i]
    }
    func containsNote(_ p: Point, scale: Double, enabledTone: Bool = false) -> Bool {
        noteIndex(at: p, scale: scale, enabledTone: enabledTone) != nil
    }
    func noteIndex(at p: Point, scale: Double, enabledTone: Bool = false) -> Int? {
        let hnh = pitchHeight / 2
        var minDSq = Double.infinity, minI: Int?
        for (noteI, note) in model.notes.enumerated().reversed() {
            let noteD = noteH(from: note) / 2
            let maxPitD = Sheet.knobEditDistance * scale + noteD
            let maxPitDSq = maxPitD * maxPitD
            let nf = noteFrame(at: noteI).outset(by: hnh)
            let oDSq = nf.distanceSquared(p)
            if oDSq < maxPitDSq {
                let dSq = pointline(from: note).minDistanceSquared(at: p)
                if dSq < noteD * noteD {
                    return noteI
                } else if dSq < minDSq && dSq < maxPitDSq {
                    minDSq = dSq
                    minI = noteI
                }
            }
            
            if enabledTone {
                for (_, toneFrame) in toneFrames(from: note) {
                    let maxD = Sheet.knobEditDistance * scale
                    let maxDSq = maxD * maxD
                    
                    let dSq = toneFrame.distanceSquared(p)
                    if dSq < minDSq && dSq < maxDSq {
                        return noteI
                    }
                }
            }
        }
        return minI
    }
    func nearestNoteIndexes(at p: Point) -> [Int] {
        var ivs = [Double: Int]()
        for (noteI, note) in model.notes.enumerated().reversed() {
            let dSq = pointline(from: note).minDistanceSquared(at: p)
            ivs[dSq] = noteI
        }
        return ivs
            .sorted { $0.key < $1.key }
            .map { $0.value }
    }
    
    enum PointHitResult {
        case note
        case startBeat
        case endBeat
        case f0
        case pit(pitI: Int)
        case lyric(pitI: Int)
        case even(pitI: Int)
        case sprol(pitI: Int, sprolI: Int, y: Double)
        case allSprol(sprolI: Int, sprol: Sprol, y: Double)
        case spectlopeHeight
        
        var isStartEndBeat: Bool {
            switch self {
            case .pit(let pitI): pitI == 0
            case .startBeat, .endBeat: true
            default: false
            }
        }
        var isPit: Bool {
            switch self {
            case .pit, .lyric: true
            default: false
            }
        }
        var isNote: Bool {
            switch self {
            case .note: true
            default: false
            }
        }
    }
    func hitTestPoint(_ p: Point, scale: Double) -> (noteI: Int, result: PointHitResult)? {
        let maxD = Sheet.knobEditDistance * scale
        let maxDSq = maxD * maxD
        let toneMaxD = min(Sheet.tonePadding - Sheet.noteHeight / 2,
                           Sheet.knobEditDistance * scale)
        let toneMaxDSq = toneMaxD * toneMaxD
        var minDSq = Double.infinity, minResult: (noteI: Int, result: PointHitResult)?
        var isPit = false, pds = [Point: Double]()
        for (noteI, note) in model.notes.enumerated().reversed() {
            if note.spectlopeHeight == Sheet.spectlopeHeight ? isFullEdit : isEditTone {
                let pitbend = note.pitbend(fromTempo: 120)
                for (pitIs, toneFrame) in toneFrames(from: note) {
                    let dSq = toneFrame.distanceSquared(p)
                    if dSq < minDSq && dSq < toneMaxDSq {
                        let containsTone = toneFrame.contains(p)
                        if note.pits.count == 1 {
                            for (sprolI, _) in note.pits[0].tone.spectlope.sprols.enumerated() {
                                let sprolY = sprolPosition(atSprol: sprolI, atPit: 0, from: note,
                                                           atY: toneFrame.minY).y
                                let dSq = p.y.distanceSquared(sprolY)
                                if dSq < minDSq {
                                    minDSq = dSq
                                    minResult = (noteI, .sprol(pitI: 0, sprolI: sprolI, y: toneFrame.minY))
                                }
                            }
                        } else {
                            var nMinResult: (noteI: Int, result: PointHitResult)?
                            for pitI in pitIs {
                                let pit = note.pits[pitI]
                                for (sprolI, _) in pit.tone.spectlope.sprols.enumerated() {
                                    let sprolP = sprolPosition(atSprol: sprolI, atPit: pitI, from: note,
                                                               atY: toneFrame.minY)
                                    let dSq = sprolP.distanceSquared(p)
                                    if dSq < minDSq && dSq < maxDSq {
                                        minDSq = dSq
                                        nMinResult = (noteI, .sprol(pitI: pitI, sprolI: sprolI, y: toneFrame.minY))
                                    }
                                }
                            }
                            
                            if nMinResult != nil {
                                minResult = nMinResult
                            } else {
                                let dSq = toneFrame.distanceSquared(p)
                                if dSq < minDSq && containsTone {
                                    let beat: Double = beat(atX: p.x)
                                    let result = note.pitResult(atBeat: beat - .init(note.beatRange.start), tempo: 120, from: pitbend)
                                    let spectlope = result.tone.spectlope
                                    for (sprolI, sprol) in spectlope.sprols.enumerated() {
                                        let ny = sprol.pitch.clipped(min: Score.doubleMinPitch,
                                                                     max: Score.doubleMaxPitch,
                                                                     newMin: 0, newMax: note.spectlopeHeight)
                                        let sprolY = ny + toneFrame.minY
                                        let dSq = p.y.distanceSquared(sprolY)
                                        if dSq < minDSq {
                                            minDSq = dSq
                                            minResult = (noteI, .allSprol(sprolI: sprolI, sprol: sprol, y: toneFrame.minY))
                                        }
                                    }
                                }
                            }
                        }
                        
                        if containsTone {
                            return minResult
                        }
                    }
                    
                    if p.x >= toneFrame.minX - toneMaxD && p.x < toneFrame.maxX + toneMaxD
                        && p.y > toneFrame.maxY && p.y <= toneFrame.maxY + toneMaxD {
                        
                        minResult = (noteI, .spectlopeHeight)
                    }
                }
            }
            
            let pointline = pointline(from: note)
            let nsx = x(atBeat: note.beatRange.start)
            let nex = x(atBeat: note.beatRange.end)
            let nsy = noteY(atBeat: note.beatRange.start, from: note)
            let ney = noteY(atBeat: note.beatRange.end, from: note)
            let nw = nex - nsx
            let nMaxDSq = note.pits.count == 1 && nw / 4 < maxD ? (nw / 4).squared : maxDSq
            var prePitP: Point?
            let isRendableFromLyric = note.isRendableFromLyric
            for (pitI, pit) in note.pits.enumerated() {
                let pitP = pitPosition(atPit: pitI, from: note)
                let dSq = pitP.distanceSquared(p)
                if dSq <= minDSq && dSq < nMaxDSq {
                    let pdSq = pointline.minDistanceSquared(at: p)
                    if prePitP == pitP {
                        pds[pitP] = pdSq
                        minDSq = dSq
                        minResult = (noteI, .pit(pitI: pitI))
                        isPit = true
                    } else if let minPDSq = pds[pitP] {
                        if pdSq < minPDSq {
                            pds[pitP] = pdSq
                            minDSq = dSq
                            minResult = (noteI, .pit(pitI: pitI))
                            isPit = true
                        }
                    } else {
                        pds[pitP] = pdSq
                        minDSq = dSq
                        minResult = (noteI, .pit(pitI: pitI))
                        isPit = true
                    }
                }
                
                if isRendableFromLyric && !pit.lyric.isEmpty && pit.lyric != "[" && pit.lyric != "]" {
                    let pitP = pitPosition(atPit: pitI, from: note) + Point(0, -8)

                    let dSq = pitP.distanceSquared(p)
                    if dSq <= minDSq && dSq < nMaxDSq {
                        minDSq = dSq
                        minResult = (noteI, .lyric(pitI: pitI))
                    }
                }
                
                prePitP = pitP
            }
            if note.pits.last?.beat != note.beatRange.length {
                let pitP = Point(nex, ney)
                let dSq = pitP.distanceSquared(p)
                if dSq <= minDSq && dSq < nMaxDSq {
                    let pdSq = pointline.minDistanceSquared(at: p)
                    if let minPDSq = pds[pitP] {
                        if pdSq < minPDSq {
                            pds[pitP] = pdSq
                            minDSq = dSq
                            minResult = (noteI, .endBeat)
                            isPit = true
                        }
                    } else {
                        pds[pitP] = pdSq
                        minDSq = dSq
                        minResult = (noteI, .endBeat)
                        isPit = true
                    }
                }
            }
            
            let noteD = noteH(from: note) / 2
            let knobMaxPitDSq = (Sheet.knobEditDistance * scale + noteD).squared
            let noteMaxPitDSq = (Sheet.noteEditDistance * scale + noteD).squared
            if !isPit {
                let nfsw = (nex - nsx) / scale
                let dx = nfsw.clipped(min: 3, max: 30, newMin: 1, newMax: 8) * scale
                let ndx = note.pits.count == 1 && nw / 4 < dx ? nw / 4 : dx
                let pdSq = pointline.minDistanceSquared(at: p)
                if p.x < nsx + ndx && abs(p.y - nsy) < maxD {
                    let dSq = min(pdSq, p.distanceSquared(.init(nsx, nsy)))
                    if dSq < minDSq && pdSq < knobMaxPitDSq {
                        minDSq = dSq
                        minResult = (noteI, .startBeat)
                    }
                } else if p.x > nex - ndx && abs(p.y - ney) < maxD {
                    let dSq = min(pdSq, p.distanceSquared(.init(nex, ney)))
                    if dSq < minDSq && pdSq < knobMaxPitDSq {
                        minDSq = dSq
                        minResult = (noteI, .endBeat)
                    }
                } else {
                    if pdSq < minDSq && pdSq < noteMaxPitDSq {
                        minDSq = pdSq
                        minResult = (noteI, .note)
                    }
                }
            }
            
            if note.isSimpleLyric {
                let f0P = Point(nsx, nsy - 10)
                let dSq = f0P.distanceSquared(p)
                if dSq <= minDSq && dSq < nMaxDSq {
                    minDSq = dSq
                    minResult = (noteI, .f0)
                }
            }
            
            let hnh = pitchHeight / 2
            let nf = noteFrame(at: noteI).outset(by: hnh)
            let oDSq = nf.distanceSquared(p)
            if oDSq < noteMaxPitDSq {
                let dSq = pointline.minDistanceSquared(at: p)
                if dSq < noteD * noteD && p.x >= nsx && p.x < nex {
                    return minResult ?? (noteI, .note)
                }
            }
        }
        
        return minResult
    }
    
    enum OptionHitResult {
        case keyBeat(beatI: Int)
        case scale(scaleI: Int, pitch: Rational)
    }
    func hitTestOption(_ p: Point, scale: Double) -> OptionHitResult? {
        if let keyBeatI = keyBeatIndex(at: p, scale: scale) {
            return .keyBeat(beatI: keyBeatI)
        }
        
        let containsMainFrame = containsMainFrame(p, scale: scale)
        let maxD = Sheet.knobEditDistance * scale
        let maxDSq = maxD * maxD
        let score = model
        
        var result: OptionHitResult?, minDSq = Double.infinity
        if containsMainFrame {
            for (ki, keyBeat) in score.keyBeats.enumerated() {
                let x = x(atBeat: keyBeat)
                let dSq = p.x.distanceSquared(x)
                if dSq < minDSq && dSq < maxDSq {
                    minDSq = dSq
                    result = .keyBeat(beatI: ki)
                }
            }
            if result != nil {
                return result
            }
        }
        
        if containsMainFrame || containsScaleFrame(p, scale: scale) {
            let pitchRange = Score.pitchRange
            for (si, scale) in score.scales.enumerated() {
                var pitch = scale.mod(12)
                while pitch < pitchRange.start { pitch += 12 }
                while pitchRange.contains(pitch) {
                    let y = y(fromPitch: pitch)
                    let dSq = p.y.distanceSquared(y)
                    if dSq < minDSq && dSq < maxDSq {
                        minDSq = dSq
                        result = .scale(scaleI: si, pitch: pitch)
                    }
                    pitch += 12
                }
            }
        }
        return result
    }
    
    enum ColorHitResult {
        case note
        case pit(pitI: Int)
        case allEven
        case evenAmp(pitI: Int)
        case oddVolm(pitI: Int)
        case allSprol(sprolI: Int, sprol: Sprol)
        case sprol(pitI: Int, sprolI: Int)
        
        var isStereo: Bool {
            switch self {
            case .note, .pit: true
            default: false
            }
        }
        var isTone: Bool {
            switch self {
            case .evenAmp, .oddVolm, .sprol: true
            default: false
            }
        }
        var isSprol: Bool {
            switch self {
            case .sprol, .allSprol: true
            default: false
            }
        }
    }
    func hitTestColor(_ p: Point, scale: Double) -> (noteI: Int, result: ColorHitResult)? {
        let maxD = Sheet.knobEditDistance * scale
        let maxDSq = maxD * maxD
        let toneMaxD = min(Sheet.tonePadding - Sheet.noteHeight / 2,
                           Sheet.knobEditDistance * scale)
        let toneMaxDSq = toneMaxD * toneMaxD
        var minDSq = Double.infinity, minResult: (noteI: Int, result: ColorHitResult)?
        var pds = [Point: Double]()
        for (noteI, note) in model.notes.enumerated().reversed() {
            if note.spectlopeHeight == Sheet.spectlopeHeight ? isFullEdit : isEditTone {
                let pitbend = note.pitbend(fromTempo: 120)
                for (pitIs, toneFrame) in toneFrames(from: note) {
                    let dSq = toneFrame.distanceSquared(p)
                    if dSq < minDSq && dSq < toneMaxDSq {
                        let containsTone = toneFrame.contains(p)
                        if note.pits.count == 1 {
                            for (sprolI, _) in note.pits[0].tone.spectlope.sprols.enumerated() {
                                let sprolY = sprolPosition(atSprol: sprolI, atPit: 0, from: note,
                                                           atY: toneFrame.minY).y
                                let dSq = p.y.distanceSquared(sprolY)
                                if dSq < minDSq {
                                    minDSq = dSq
                                    minResult = (noteI, .sprol(pitI: 0, sprolI: sprolI))
                                }
                            }
                        } else {
                            var nMinResult: (noteI: Int, result: ColorHitResult)?
                            for pitI in pitIs {
                                let pit = note.pits[pitI]
                                for (sprolI, _) in pit.tone.spectlope.sprols.enumerated() {
                                    let sprolP = sprolPosition(atSprol: sprolI, atPit: pitI, from: note,
                                                               atY: toneFrame.minY)
                                    let dSq = sprolP.distanceSquared(p)
                                    if dSq < minDSq && dSq < maxDSq {
                                        minDSq = dSq
                                        nMinResult = (noteI, .sprol(pitI: pitI, sprolI: sprolI))
                                    }
                                }
                            }
                            
                            if nMinResult != nil {
                                minResult = nMinResult
                            } else {
                                let dSq = toneFrame.distanceSquared(p)
                                if dSq < minDSq && (containsTone || dSq < toneMaxDSq) {
                                    let beat: Double = beat(atX: p.x)
                                    let result = note.pitResult(atBeat: beat - .init(note.beatRange.start), tempo: 120, from: pitbend)
                                    let spectlope = result.tone.spectlope
                                    for (sprolI, sprol) in spectlope.sprols.enumerated() {
                                        let ny = sprol.pitch.clipped(min: Score.doubleMinPitch,
                                                                     max: Score.doubleMaxPitch,
                                                                     newMin: 0, newMax: note.spectlopeHeight)
                                        let sprolY = ny + toneFrame.minY
                                        let dSq = p.y.distanceSquared(sprolY)
                                        if dSq < minDSq {
                                            minDSq = dSq
                                            minResult = (noteI, .allSprol(sprolI: sprolI, sprol: sprol))
                                        }
                                    }
                                }
                            }
                        }
                        
                        if containsTone {
                            return minResult
                        }
                    }
                }
            }
            
            let pointline = pointline(from: note)
            let nsx = x(atBeat: note.beatRange.start)
            let nex = x(atBeat: note.beatRange.end)
            let nw = nex - nsx
            let nMaxDSq = note.pits.count == 1 && nw / 4 < maxD ? (nw / 4).squared : maxDSq
            var prePitP: Point?
            for pitI in note.pits.count.range {
                let pitP = pitPosition(atPit: pitI, from: note)
                let dSq = pitP.distanceSquared(p)
                if dSq <= minDSq && dSq < nMaxDSq {
                    let pdSq = pointline.minDistanceSquared(at: p)
                    if prePitP == pitP {
                        pds[pitP] = pdSq
                        minDSq = dSq
                        minResult = (noteI, .pit(pitI: pitI))
                    } else if let minPDSq = pds[pitP] {
                        if pdSq < minPDSq {
                            pds[pitP] = pdSq
                            minDSq = dSq
                            minResult = (noteI, .pit(pitI: pitI))
                        }
                    } else {
                        pds[pitP] = pdSq
                        minDSq = dSq
                        minResult = (noteI, .pit(pitI: pitI))
                    }
                }
                prePitP = pitP
            }
            
            let hnh = pitchHeight / 2
            let noteD = noteH(from: note) / 2
            let maxPitD = Sheet.knobEditDistance * scale + noteD
            let maxPitDSq = maxPitD * maxPitD
            let nf = noteFrame(at: noteI).outset(by: hnh)
            let odSq = nf.distanceSquared(p)
            if odSq < maxPitDSq {
                let dSq = pointline.minDistanceSquared(at: p)
                if dSq < noteD * noteD && p.x >= nsx && p.x < nex {
                    return minResult ?? (noteI, .note)
                }
            }
        }
        
        return if let minResult {
            minResult
        } else if let noteI = noteIndex(at: p, scale: scale) {
            (noteI, .note)
        } else {
            nil
        }
    }
    
    func intersectsNote(_ otherRect: Rect, at noteI: Int) -> Bool {
        guard notesNode.children[noteI].path.intersects(otherRect),
              let b = mainLineBounds(at: noteI) else { return false }
        guard b.intersects(otherRect) else {
            return false
        }
        if otherRect.contains(b) {
            return true
        }
        
        let note = model.notes[noteI]
        if note.pits.count == 1 {
            return true
        }
        
        var preBeat = note.beatRange.start
        var x0 = x(atBeat: preBeat)
        var y0 = y(fromPitch: note.firstPitch)
        for pit in note.pits {
            let nextBeat = pit.beat + note.beatRange.start
            let x1 = x(atBeat: nextBeat)
            let y1 = y(fromPitch: pit.pitch + note.pitch)
            
            let (minX, maxX) = x0 < x1 ? (x0, x1) : (x1, x0)
            let (minY, maxY) = y0 < y1 ? (y0, y1) : (y1, y0)
            if minX == maxX {
                if otherRect.intersects(Edge(.init(x0, y0), .init(x0, y1))) {
                    return true
                }
            }
            let rect = AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
            if otherRect.intersects(rect) {
                if y0 == y1 {
                    return true
                }
                
                var beat = preBeat, ps = [Point]()
                while beat <= nextBeat {
                    let noteX = x(atBeat: beat), noteY = noteY(atBeat: beat, from: note)
                    ps.append(Point(noteX, noteY))
                    beat += .init(1, 48)
                }
                let line = Pointline(controls: ps.map { .init(point: $0) })
                if line.intersects(otherRect) {
                    return true
                }
            }
            
            preBeat = nextBeat
            x0 = x1
            y0 = y1
        }
        let x1 = x(atBeat: note.beatRange.end)
        if otherRect.intersects(Edge(.init(x0, y0), .init(x1, y0))) {
            return true
        }
        
        return false
    }
    func containsNote(_ otherRect: Rect, at noteI: Int) -> Bool {
        if model.notes[noteI].pits.count == 1 {
            return intersectsNote(otherRect, at: noteI)
        } else {
            let line = pointline(from: model.notes[noteI])
            return line.controls.allSatisfy { otherRect.contains($0.point) }
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
    func transformedNoteFrame(at noteI: Int) -> Rect {
        noteFrame(at: noteI) * node.localTransform
    }
    func draftNoteFrame(at noteI: Int) -> Rect {
        draftNotesNode.children[noteI].path.bounds ?? .init()
    }
    func transformedDraftNoteFrame(at noteI: Int) -> Rect {
        draftNoteFrame(at: noteI) * node.localTransform
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
    func pitResult(atBeat beat: Rational, from note: Note) -> Note.PitResult {
        note.pitResult(atBeat: .init(beat - note.beatRange.start))
    }
    func noteY(from result: Note.PitResult, from note: Note) -> Double {
        y(fromPitch: (.init(note.pitch) + result.pitch.doubleValue).clipped(Score.doublePitchRange))
    }
    func pitch(atBeat beat: Rational, from note: Note) -> Double {
        let result = note.pitResult(atBeat: .init(beat - note.beatRange.start))
        return .init(note.pitch) + result.pitch.doubleValue
    }
    func pitch(from result: Note.PitResult, from note: Note) -> Double {
        (.init(note.pitch) + result.pitch.doubleValue).clipped(Score.doublePitchRange)
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
    func evenAmp(atX x: Double, from note: Note) -> Double {
        let result = note.pitResult(atBeat: .init(beat(atX: x) - note.beatRange.start))
        return result.tone.overtone.evenAmp
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
        note.isOneOvertone ? 1.0 : (note.isFullNoise ? 2.5 : Sheet.noteHeight)
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
                if ds <= minDS && ds < maxDS {
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
    func noteIInTone(at p: Point, scale: Double) -> Int? {
        let toneMaxD = min(Sheet.tonePadding - Sheet.noteHeight / 2,
                           Sheet.knobEditDistance * scale)
        return notesNode.children.firstIndex {
            $0.children.contains {
                $0.name == "toneFrame" ? $0.bounds?.outset(by: toneMaxD).contains(p) ?? false : false
            }
        }
    }
    func containsTone(at p: Point, at noteI: Int, scale: Double) -> Bool {
        let toneMaxD = min(Sheet.tonePadding - Sheet.noteHeight / 2,
                           Sheet.knobEditDistance * scale)
        return notesNode.children[noteI].children.contains {
            $0.name == "toneFrame" ? $0.bounds?.outset(by: toneMaxD).contains(p) ?? false : false
        }
    }
    func toneFrames(from note: Note) -> [(pitIs: [Int], frame: Rect)] {
        guard note.beatRange.length > 0 && !note.isOneOvertone && !note.isDefaultTone else {
            return []
        }
        let nsx = x(atBeat: note.beatRange.start)
        
        if note.pits.count >= 2 {
            let t = note.spectlopeHeight.clipped(min: Sheet.spectlopeHeight,
                                                 max: Sheet.maxSpectlopeHeight,
                                                 newMin: 0, newMax: 1)
            let toneMaxY = toneMaxY(from: note)
            let tempo = model.tempo
            let pitbend = note.pitbend(fromTempo: tempo)
            
            var beatSet = Set<Rational>(minimumCapacity: Int(note.beatRange.length / .init(1, 72)))
            var nBeat = note.beatRange.start
            while nBeat <= note.beatRange.end {
                beatSet.insert(nBeat)
                nBeat += .init(1, 72)
            }
            if nBeat != note.beatRange.end {
                beatSet.insert(note.beatRange.end)
            }
            let pitIsDic = pitbend.pits.enumerated().reduce(into: [Rational: [Int]](minimumCapacity: pitbend.pits.count)) {
                let beat = note.beatRange.start + $1.element.beat
                if $0[beat] != nil {
                    $0[beat]?.append($1.offset)
                } else {
                    $0[beat] = [$1.offset]
                }
            }
            let pitBeatSet = Set(pitbend.pits.map { note.beatRange.start + $0.beat })
            beatSet.formUnion(pitBeatSet)
            let beats = beatSet.sorted()
            
            var ox = nsx, oy = Double.linear(y(fromPitch: note.firstPitch) + Sheet.tonePadding,
                                             toneMaxY,
                                             t: t)
            var currentY = oy
            var toneFrames = [(pitIs: [Int], frame: Rect)](), pitIs = [Int]()
            for (bi, nBeat) in beats.enumerated() {
                let nx = self.x(atBeat: nBeat)
                let result = note.pitResult(atBeat: .init(nBeat - note.beatRange.start),
                                            tempo: Double(tempo), from: pitbend)
                let psPitch = pitch(from: result, from: note)
                let noteY = y(fromPitch: psPitch)
                
                let topY = noteY
                if currentY - topY < Sheet.tonePadding / 2
                    || currentY - topY > Sheet.tonePadding * 3 / 2.0
                    || (pitIsDic[nBeat]?.count ?? 0) >= 2 {
                    
                    currentY = Double.linear(topY + Sheet.tonePadding, toneMaxY, t: t)
                }
                let ny = currentY
                if pitIsDic[nBeat]?.count == 1 {
                    oy = ny
                }
                
                if let nPitI = pitIsDic[nBeat]?.first {
                    pitIs.append(nPitI)
                }
                if oy != ny || bi == beats.count - 1 {
                    toneFrames.append((pitIs.sorted(),
                                       Rect(x: ox, y: oy, width: nx - ox, height: note.spectlopeHeight)))
                    ox = nx
                    oy = ny
                    
                    pitIs = []
                }
                if let nPitIs = pitIsDic[nBeat], nPitIs.count >= 2 {
                    pitIs.append(nPitIs[.last])
                }
            }
            return toneFrames
        } else {
            let toneY = y(fromPitch: note.firstPitch) + Sheet.tonePadding
            let nx = x(atBeat: note.beatRange.start)
            let nw = width(atDurBeat: max(note.beatRange.length, EditGrid.fullEditBeatInterval))
            return [(.init(note.pits.count.range),
                     .init(x: nx, y: toneY, width: nw, height: note.spectlopeHeight))]
        }
    }
    func toneFrames(at noteI: Int) -> [(pitIs: [Int], frame: Rect)] {
        toneFrames(from: model.notes[noteI])
    }
    func spectlopeFrames(from note: Note) -> [(pitIs: [Int], frame: Rect)] {
        toneFrames(from: note)
    }
    func spectlopeFrames(at noteI: Int) -> [(pitIs: [Int], frame: Rect)] {
        spectlopeFrames(from: model.notes[noteI])
    }
    func pitIAndSprolI(at p: Point, at noteI: Int, scale: Double) -> (pitI: Int, sprolI: Int)? {
        let toneMaxD = min(Sheet.tonePadding - Sheet.noteHeight / 2,
                           Sheet.knobEditDistance * scale)
        let toneMaxDSq = toneMaxD * toneMaxD
        
        let score = model
        let note = score.notes[noteI]
        var minDSq = Double.infinity, minPitI: Int?, minSprolI: Int?
        for (pitIs, toneFrame) in toneFrames(at: noteI) {
            let dSq = toneFrame.distanceSquared(p)
            if dSq < minDSq && dSq < toneMaxDSq {
                for pitI in pitIs {
                    let pit = note.pits[pitI]
                    for (sprolI, _) in pit.tone.spectlope.sprols.enumerated() {
                        let psp = sprolPosition(atSprol: sprolI, atPit: pitI, at: noteI, atY: toneFrame.minY)
                        let ds = p.distanceSquared(psp)
                        if ds < minDSq {
                            minDSq = ds
                            minPitI = pitI
                            minSprolI = sprolI
                        }
                    }
                }
            }
        }
        
        return if let minPitI, let minSprolI {
            (minPitI, minSprolI)
        } else {
            nil
        }
    }
    func sprolPosition(atSprol sprolI: Int, atPit pitI: Int, from note: Note, atY y: Double) -> Point {
        let sprol = note.pits[pitI].tone.spectlope.sprols[sprolI]
        let ny = sprol.pitch.clipped(min: Score.doubleMinPitch,
                                     max: Score.doubleMaxPitch,
                                     newMin: 0, newMax: note.spectlopeHeight) + y
        let pitP = pitPosition(atPit: pitI, from: note)
        return .init(pitP.x, ny)
    }
    func sprolPosition(atSprol sprolI: Int, atPit pitI: Int, at noteI: Int, atY y: Double) -> Point {
        sprolPosition(atSprol: sprolI, atPit: pitI, from: model.notes[noteI], atY: y)
    }
    func toneY(at p: Point, from note: Note) -> Double {
        let tfs = toneFrames(from: note)
        guard !tfs.isEmpty else {
            return y(fromPitch: note.firstPitch) + Sheet.tonePadding
        }
        if p.x < tfs[0].frame.minX {
            return tfs[0].frame.minY
        }
        for tf in tfs {
            if p.x < tf.frame.maxX {
                return tf.frame.minY
            }
        }
        return tfs.last!.frame.minY
    }
    func toneMaxY(from note: Note) -> Double {
        y(fromPitch: (note.pits.maxValue { $0.pitch } ?? 0) + note.pitch) + Sheet.tonePadding
    }
    func spectlopePitch(at p: Point, at noteI: Int, y: Double) -> Double {
        p.y.clipped(min: y, max: y + model.notes[noteI].spectlopeHeight,
                    newMin: Score.doubleMinPitch, newMax: Score.doubleMaxPitch)
    }
    func nearestSprol(at p: Point, at noteI: Int) -> (y: Double, sprol: Sprol) {
        let note = model.notes[noteI]
        let y = toneY(at: p, from: note)
        let tone = note.pitResult(atBeat: beat(atX: p.x) - .init(note.beatRange.start)).tone
        let pitch = p.y.clipped(min: y, max: y + note.spectlopeHeight,
                                newMin: Score.doubleMinPitch, newMax: Score.doubleMaxPitch)
        return (y, tone.spectlope.sprol(atPitch: pitch))
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
        
        let stereo: Stereo, tone: Tone
        if result.pitI + 1 < note.pits.count {
            let prePit = note.pits[result.pitI]
            let nextPit = note.pits[result.pitI + 1]
            stereo = prePit.stereo == nextPit.stereo ?
            prePit.stereo : result.stereo.with(id: .init())
            tone = prePit.tone == nextPit.tone ?
            prePit.tone : result.tone.with(id: .init())
        } else {
            stereo = result.stereo
            tone = result.tone
        }
        
        return .init(beat: self.beat(atX: p.x, interval: beatInterval) - note.beatRange.start,
                     pitch: pitch, stereo: stereo, tone: tone)
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
    func pitX(atPit pitI: Int, from note: Note) -> Double {
        x(atBeat: note.beatRange.start + note.pits[pitI].beat)
    }
    func pitY(atPit pitI: Int, from note: Note) -> Double {
        y(fromPitch: note.pitch + note.pits[pitI].pitch)
    }
    func pitPosition(atPit pitI: Int, from note: Note) -> Point {
        .init(pitX(atPit: pitI, from: note), pitY(atPit: pitI, from: note))
    }
    func pitPosition(atPit pitI: Int, at noteI: Int) -> Point {
        pitPosition(atPit: pitI, from: model.notes[noteI])
    }
    
    func noteLastPosition(from note: Note) -> Point {
        .init(x(atBeat: note.beatRange.end),
              y(fromPitch: note.pitch + note.pits.last!.pitch))
    }
    func noteLastPosition(at noteI: Int) -> Point {
        noteLastPosition(from: model.notes[noteI])
    }
    
    static var spectrogramHeight: Double {
        Sheet.pitchHeight * (Score.doubleMaxPitch - Score.doubleMinPitch)
    }
    func updateSpectrogram() {
        spectrogramNode?.removeFromParent()
        spectrogramNode = nil
        
        let score = model
        guard score.isShownSpectrogram, let sm = score.spectrogram else { return }
        
        let firstX = x(atBeat: Rational(0))
        let y = mainFrame.minY
        let allBeat = score.allBeatRange.end
        let allW = width(atDurBeat: allBeat)
        var nodes = [Node](), maxH = 0.0
        func spNode(width: Int, at xi: Int) -> Node? {
            guard let image = sm.image(width: width, at: xi),
                  let texture = try? Texture(image: image, isOpaque: false, .sRGB) else { return nil }
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
        node.insert(child: sNode, at: node.children.firstIndex(of: timelineContentNode) ?? 0)
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
    
    func isShownSpectrogramDistance(_ p: Point, scale: Double) -> Double {
        isShownSpectrogramFrame.distanceSquared(p).squareRoot()
    }
    var isShownSpectrogramFrame: Rect {
        let beatRange = model.beatRange
        let sBeat = max(beatRange.start, -10000)
        let sx = x(atBeat: sBeat)
        let ey = Sheet.timelineHalfHeight
        let pnW = 20.0, pnnH = 12.0, spnW = 3.0, pnY = ey + 12
        return Rect(x: sx, y: pnY - pnnH / 2, width: pnW + spnW, height: pnnH)
    }
    var paddingIsShownSpectrogramFrame: Rect {
        isShownSpectrogramFrame.outset(by: Sheet.timelinePadding)
    }
    var transformedIsShownSpectrogramFrame: Rect {
        var f = isShownSpectrogramFrame
        f.origin.y += timelineY
        return f
    }
    func containsIsShownSpectrogram(_ p: Point, scale: Double) -> Bool {
        isShownSpectrogramDistance(p, scale: scale) < 3 + scale * 5
    }
    
    func isLoopDurBeat(at p: Point, scale: Double) -> Bool {
        p.y > timelineCenterY + Sheet.timelineHalfHeight - 3
        && abs(p.x - x(atBeat: model.endLoopDurBeat)) < 10.0 * scale
    }
    func isShownSpectrogram(at p :Point) -> Bool {
        let beatRange = model.beatRange
        let sBeat = max(beatRange.start, -10000)
        let sx = x(atBeat: sBeat)
        let pnW = 20.0
        return p.x >= sx + pnW * 0.5
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
                Sleep.start()
                updateSpectrogram()
            }
        }
    }
}
