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
    
    func sec(atX x: Double, interval: Rational) -> Rational {
        model.sec(fromBeat: beat(atX: x, interval: interval))
    }
    func sec(atX x: Double) -> Double {
        model.sec(fromBeat: beat(atX: x))
    }
    func sec(atX x: Double) -> Rational {
        sec(atX: x, interval: Rational(1, frameRate))
    }
    
    func containsSec(_ p: Point, maxDistance: Double) -> Bool {
        guard let beatRange else { return false }
        let secRange = model.secRange(fromBeat: beatRange)
        let sy = timelineCenterY - Sheet.timelineHalfHeight + origin.y
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
        abs(p.y - timelineCenterY)
    }
    func containsMainLine(_ p: Point, scale: Double) -> Bool {
        guard containsTimeline(p, scale: scale) else { return false }
        return mainLineDistance(p) < 5 * scale
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
            reverbsNode.children.forEach {
                $0.children.forEach {
                    if $0.name == "isFullEdit" {
                        $0.isHidden = !isFullEdit
                    }
                }
            }
        }
    }
    var isEditTone = false {
        didSet {
            guard isEditTone != oldValue else { return }
            notesNode.children.forEach {
                $0.children.forEach {
                    if $0.name == "point" {
                        $0.isHidden = !isEditTone
                    }
                }
            }
        }
    }
    
    let currentPeakVolmNode = Node(lineWidth: 2, lineType: .color(.background))
    let timeNode = Node(lineWidth: 3, lineType: .color(.content))
    
    var peakVolm = 0.0 {
        didSet {
            guard option.enabled, peakVolm != oldValue else { return }
            updateFromPeakVolm()
        }
    }
    func updateFromPeakVolm() {
        let frame = mainFrame
        currentPeakVolmNode.path = Path([Point(), Point(0, frame.maxY - timelineFrame.minY)])
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
    var transformedMainFrame: Rect {
        mainFrame * node.localTransform
    }
    
    let octaveNode = Node(isHidden: true), draftNotesNode = Node(), notesNode = Node()
    let timelineContentNode = Node(fillType: .color(.content))
    let timelineSubBorderNode = Node(fillType: .color(.subBorder))
    let timelineBorderNode = Node(fillType: .color(.border))
    let timelineBackgroundNode = Node(fillType: .color(.background))
    let timelineFullEditBorderNode = Node(isHidden: true, fillType: .color(.border))
    let chordNode = Node()
    let pitsNode = Node(fillType: .color(.background))
    var tonesNode = Node(), reverbsNode = Node(), spectlopesNode = Node()
    let clippingNode = Node(isHidden: true, lineWidth: 4, lineType: .color(.warning))
    
    var spectrogramNode: Node?
    var spectrogramFqType: Spectrogram.FqType?
    
    var scoreTrackItem: ScoreTrackItem?
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        timeNode.children = [currentPeakVolmNode]
        
        node = Node(children: [spectlopesNode, timelineBorderNode, timelineFullEditBorderNode,
                               octaveNode,
                               timelineSubBorderNode,
                               timelineBackgroundNode,
                               chordNode,
                               timelineContentNode,
                               draftNotesNode, reverbsNode, notesNode, pitsNode, tonesNode,
                               timeNode, clippingNode])
        updateClippingNode()
        updateTimeline()
        updateSpectrogram()
        updateScore()
        updateDraftNotes()
        
        if model.enabled {
            scoreTrackItem = .init(score: model, sampleRate: Audio.defaultSampleRate, isUpdateNotewaveDic: true)
        }
        node.attitude.position.y = binder[keyPath: keyPath].timelineY
    }
}
extension ScoreView {
    var pitchHeight: Double { Sheet.pitchHeight }
    
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
                 borderPathlines, fullEditBorderPathlines,
                 backgroundPathlines) = self.timelinePathlinesTuple()
            timelineBackgroundNode.path = .init(backgroundPathlines)
            timelineContentNode.path = .init(contentPathlines)
            timelineSubBorderNode.path = .init(subBorderPathlines)
            timelineBorderNode.path = .init(borderPathlines)
            timelineFullEditBorderNode.path = .init(fullEditBorderPathlines)
            node.attitude.position.y = model.timelineY
        } else {
            timelineBackgroundNode.path = .init()
            timelineContentNode.path = .init()
            timelineSubBorderNode.path = .init()
            timelineBorderNode.path = .init()
            timelineFullEditBorderNode.path = .init()
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
            tonesNode.children = vs.map { $0.toneNode }
            reverbsNode.children = vs.map { $0.reverbNode }
            spectlopesNode.children = vs.map { $0.spectlopeNode }
            octaveNode.children = zip(model.notes, nodes).map { octaveNode(fromPitch: $0.0.firstPitch, $0.1.children[0].clone) }
        } else {
            notesNode.children = []
            tonesNode.children = []
            reverbsNode.children = []
            spectlopesNode.children = []
            octaveNode.children = []
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
    var localBeatRange: Range<Rational>? {
        model.localMaxBeatRange
    }
    
    var pitchStartY: Double {
        timelineCenterY + Sheet.timelineHalfHeight + Sheet.isShownSpectrogramHeight
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
    func normarizedPitResult(atBeat beat: Rational, at noteI: Int) -> Note.PitResult {
        self[noteI].normarizedPitResult(atBeat: .init(beat - self[noteI].beatRange.start))
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
        }
    }
    
    func append(_ note: Note) {
        unupdateModel.notes.append(note)
        let (noteNode, toneNode, reverbNode, spectlopeNode) = noteNode(from: note)
        notesNode.append(child: noteNode)
        tonesNode.append(child: toneNode)
        reverbsNode.append(child: reverbNode)
        spectlopesNode.append(child: spectlopeNode)
        octaveNode.append(child: octaveNode(fromPitch: note.firstPitch, noteNode.children[0].clone))
        updateChord()
        scoreTrackItem?.insert([.init(value: note, index: unupdateModel.notes.count - 1)], with: model)
    }
    func insert(_ note: Note, at noteI: Int) {
        unupdateModel.notes.insert(note, at: noteI)
        let (noteNode, toneNode, reverbNode, spectlopeNode) = noteNode(from: note)
        notesNode.insert(child: noteNode, at: noteI)
        tonesNode.insert(child: toneNode, at: noteI)
        reverbsNode.insert(child: reverbNode, at: noteI)
        spectlopesNode.insert(child: spectlopeNode, at: noteI)
        octaveNode.append(child: octaveNode(fromPitch: note.firstPitch, noteNode.children[0].clone))
        updateChord()
        scoreTrackItem?.insert([.init(value: note, index: noteI)], with: model)
    }
    func insert(_ nivs: [IndexValue<Note>]) {
        unupdateModel.notes.insert(nivs)
        let vs = nivs.map { IndexValue(value: noteNode(from: $0.value), index: $0.index) }
        let noivs = vs.map { IndexValue(value: $0.value.node, index: $0.index) }
        let toivs = vs.map { IndexValue(value: $0.value.toneNode, index: $0.index) }
        let reivs = vs.map { IndexValue(value: $0.value.reverbNode, index: $0.index) }
        let seivs = vs.map { IndexValue(value: $0.value.spectlopeNode, index: $0.index) }
        notesNode.children.insert(noivs)
        tonesNode.children.insert(toivs)
        reverbsNode.children.insert(reivs)
        spectlopesNode.children.insert(seivs)
        octaveNode.children.insert(noivs.enumerated().map { .init(value: octaveNode(fromPitch: nivs[$0.offset].value.firstPitch, $0.element.value.children[0].clone), index: $0.element.index) })
        updateChord()
        scoreTrackItem?.insert(nivs, with: model)
    }
    func replace(_ nivs: [IndexValue<Note>]) {
        unupdateModel.notes.replace(nivs)
        let vs = nivs.map { IndexValue(value: noteNode(from: $0.value), index: $0.index) }
        let noivs = vs.map { IndexValue(value: $0.value.node, index: $0.index) }
        let toivs = vs.map { IndexValue(value: $0.value.toneNode, index: $0.index) }
        let reivs = vs.map { IndexValue(value: $0.value.reverbNode, index: $0.index) }
        let seivs = vs.map { IndexValue(value: $0.value.spectlopeNode, index: $0.index) }
        notesNode.children.replace(noivs)
        tonesNode.children.replace(toivs)
        reverbsNode.children.replace(reivs)
        spectlopesNode.children.replace(seivs)
        octaveNode.children.replace(noivs.enumerated().map { .init(value: octaveNode(fromPitch: nivs[$0.offset].value.firstPitch, $0.element.value.children[0].clone), index: $0.element.index) })
        updateChord()
        scoreTrackItem?.replace(nivs, with: model)
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
        let reivs = vs.map { IndexValue(value: $0.value.reverbNode, index: $0.index) }
        let seivs = vs.map { IndexValue(value: $0.value.spectlopeNode, index: $0.index) }
        notesNode.children.replace(noivs)
        tonesNode.children.replace(toivs)
        reverbsNode.children.replace(reivs)
        spectlopesNode.children.replace(seivs)
        octaveNode.children.replace(noivs.enumerated().map { .init(value: octaveNode(fromPitch: nivs[$0.offset].value.firstPitch, $0.element.value.children[0].clone), index: $0.element.index) })
        
        scoreTrackItem?.replace(eivs)
    }
    func remove(at noteI: Int) {
        unupdateModel.notes.remove(at: noteI)
        notesNode.remove(atChild: noteI)
        tonesNode.remove(atChild: noteI)
        reverbsNode.remove(atChild: noteI)
        spectlopesNode.remove(atChild: noteI)
        octaveNode.remove(atChild: noteI)
        updateChord()
        scoreTrackItem?.remove(at: [noteI])
    }
    func remove(at noteIs: [Int]) {
        unupdateModel.notes.remove(at: noteIs)
        noteIs.reversed().forEach { notesNode.remove(atChild: $0) }
        noteIs.reversed().forEach { tonesNode.remove(atChild: $0) }
        noteIs.reversed().forEach { reverbsNode.remove(atChild: $0) }
        noteIs.reversed().forEach { spectlopesNode.remove(atChild: $0) }
        noteIs.reversed().forEach { octaveNode.remove(atChild: $0) }
        updateChord()
        scoreTrackItem?.remove(at: noteIs)
    }
    subscript(noteI: Int) -> Note {
        get {
            unupdateModel.notes[noteI]
        }
        set {
            unupdateModel.notes[noteI] = newValue
            let (noteNode, toneNode, reverbNode, spectlopeNode) = noteNode(from: newValue)
            notesNode.children[noteI] = noteNode
            tonesNode.children[noteI] = toneNode
            reverbsNode.children[noteI] = reverbNode
            spectlopesNode.children[noteI] = spectlopeNode
            octaveNode.children[noteI] = octaveNode(fromPitch: newValue.firstPitch, noteNode.children[0].clone)
            updateChord()
            scoreTrackItem?.replace([.init(value: newValue, index: noteI)], with: model)
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
                                      fullEditBorderPathlines: [Pathline],
                                      backgroundPathlines: [Pathline]) {
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
        var fullEditBorderPathlines = [Pathline]()
        var backgroundPathlines = [Pathline]()
        
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
                    0.0625
                }
                let py = self.y(fromPitch: cPitch)
                let rect = Rect(x: sx, y: py - plw / 2, width: ex - sx, height: plw)
                if plw == 0.0625 {
                    fullEditBorderPathlines.append(Pathline(rect))
                } else {
                    borderPathlines.append(Pathline(rect))
                }
            }
            cPitch += deltaPitch
        }
        
        let psy = self.y(fromPitch: pitchRange.start), pey = self.y(fromPitch: pitchRange.end)
        
        for keyBeat in score.keyBeats {
            guard score.beatRange.contains(keyBeat) else { continue }
            let nx = x(atBeat: keyBeat)
            let lw = 1.0
            subBorderPathlines.append(.init(Rect(x: nx - lw / 2, y: sy,
                                                 width: lw, height: ey - sy)))
            contentPathlines.append(.init(Rect(x: nx - knobW / 2, y: y - knobH / 2,
                                               width: knobW, height: knobH)))
            
            let plw = 1.0
            subBorderPathlines.append(.init(Rect(x: nx - plw / 2, y: psy, width: plw, height: pey - psy)))
            
            let blw = 0.25
            if !keyBeat.isInteger {
                backgroundPathlines.append(.init(Rect(x: nx - blw / 2, y: sy, width: blw, height: ey - sy)))
                backgroundPathlines.append(.init(Rect(x: nx - blw / 2, y: psy, width: blw, height: pey - psy)))
            }
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
        
        let sprH = Sheet.isShownSpectrogramHeight
        let sprKnobW = knobH, sprKbobH = knobW
        let np = Point(Sheet.spectrogramX + sx, ey)
        contentPathlines.append(Pathline(Rect(x: np.x - 1 / 2,
                                              y: np.y + 1,
                                              width: 1,
                                              height: sprH - 2)))
        if score.isShownSpectrogram {
            contentPathlines.append(Pathline(Rect(x: np.x - sprKnobW / 2,
                                                  y: np.y + sprH - 1 - sprKbobH / 2,
                                                  width: sprKnobW,
                                                  height: sprKbobH)))
        } else {
            contentPathlines.append(Pathline(Rect(x: np.x - sprKnobW / 2,
                                                  y: np.y + 1 - sprKbobH / 2,
                                                  width: sprKnobW,
                                                  height: sprKbobH)))
        }
        
        return (contentPathlines, subBorderPathlines, borderPathlines, fullEditBorderPathlines,
                backgroundPathlines)
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
        
        let chordBeats = score.notes.reduce(into: Set<Rational>()) {
            let vs = $1.chordBeatRangeAndRoundedPitchs()
            for v in vs {
                if score.beatRange.contains(v.beatRange.start) {
                    $0.insert(v.beatRange.start)
                }
                if score.beatRange.contains(v.beatRange.end) {
                    $0.insert(v.beatRange.end)
                }
            }
        }.sorted()
        guard !chordBeats.isEmpty else { return [] }
        
        var preBeat = score.beatRange.start
        var chordRanges = chordBeats.count.array.map {
            let v = preBeat ..< chordBeats[$0]
            preBeat = chordBeats[$0]
            return v
        }
        chordRanges.append(preBeat ..< score.beatRange.end)
        
        var chordEdges = [(edge: Edge, typers: [Chord.ChordTyper])]()
        let trs = chordRanges.map { ($0, score.chordPitches(atBeat: $0)) }
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
        
        var colorPathlineDic0 = [Color: [Pathline]](),
            colorPathlineDic1 = [Color: [Pathline]]()
        func append0(_ pathline: Pathline, color: Color) {
            if colorPathlineDic0[color] != nil {
                colorPathlineDic0[color]?.append(pathline)
            } else {
                colorPathlineDic0[color] = [pathline]
            }
        }
        func append1(_ pathline: Pathline, color: Color) {
            if colorPathlineDic1[color] != nil {
                colorPathlineDic1[color]?.append(pathline)
            } else {
                colorPathlineDic1[color] = [pathline]
            }
        }
        
        let chordBeats = score.notes.reduce(into: Set<Rational>()) {
            let vs = $1.chordBeatRangeAndRoundedPitchs()
            for v in vs {
                if score.beatRange.contains(v.beatRange.start) {
                    $0.insert(v.beatRange.start)
                }
                if score.beatRange.contains(v.beatRange.end) {
                    $0.insert(v.beatRange.end)
                }
            }
        }.sorted()
        guard !chordBeats.isEmpty else { return [] }
        
        var preBeat = score.beatRange.start
        var chordRanges = chordBeats.count.array.map {
            let v = preBeat ..< chordBeats[$0]
            preBeat = chordBeats[$0]
            return v
        }
        chordRanges.append(preBeat ..< score.beatRange.end)
        
        struct PitchAndTyper: Hashable {
            var pitch: Int, typers: [Chord.ChordTyper]
        }
        let trs = chordRanges.map { ($0, score.chordPitches(atBeat: $0)) }
        var cbpts = [(beatRange: Range<Rational>, typers: [Chord.ChordTyper],
                      pitchAndTypers: [PitchAndTyper])]()
        for (chordBeatRange, pitchs) in trs {
            let pitchs = pitchs.sorted()
            guard let chord = Chord(pitchs: pitchs) else { continue }
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
                cbpts.append((chordBeatRange, typers, pitchAndTypers))
            }
        }
        
        for cbpt in cbpts {
            let maxTypersCount = cbpt.typers.count
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
            let nw = maxW * Double(maxTypersCount - 1)
            let hd = Sheet.pitchHeight
            
            let plh = 0.5
            for pitchAndTyper in cbpt.pitchAndTypers {
                let py = self.y(fromPitch: Rational(pitchAndTyper.pitch))
                let colors: [Color] = pitchAndTyper.typers.map {
                    switch $0.type {
                    case .octave: .init(red: 0.85, green: 0.85, blue: 0.85)
                    case .power: .init(red: 0.88, green: 0.88, blue: 0.75)
                        
                    case .major: .init(red: 0.9, green: 0.8, blue: 0)
                    case .major3: .init(red: 0.9, green: 0.8, blue: 0).with(lightness: 93)
                        
                    case .suspended: .init(red: 0.25, green: 0.9, blue: 0)
                        
                    case .minor: .init(red: 0.0, green: 0.8, blue: 0.95)
                    case .minor3: .init(red: 0.0, green: 0.8, blue: 0.95).with(lightness: 90)
                        
                    case .augmented: .init(red: 0.75, green: 0.5, blue: 1.0)
                        
                    case .flatfive: .init(red: 1.0, green: 0.5, blue: 1.0)
                        
                    case .wholeTone: .init(red: 0.25, green: 0.9, blue: 0).with(lightness: 93)
                    case .semitone: .init(red: 1.0, green: 0.75, blue: 0.5)
                        
                    case .diminish: .init(red: 1.0, green: 0.5, blue: 0.5)
                    case .tritone: .init(red: 1.0, green: 0.5, blue: 0.5).with(lightness: 90)
                    }
                }
                
                for (ti, color) in colors.enumerated() {
                    let nti = cbpt.typers.firstIndex(of: pitchAndTyper.typers[ti])!
                    let fx = chordCenterX - nw / 2 + maxW * Double(nti)
                    append0(.init(Rect(x: fx - plh * lwScale / 2, y: py - hd / 2,
                                      width: plh * lwScale, height: hd)), color: color)
                }
                for (ti, color) in colors.enumerated() {
                    let h = plh / Double(pitchAndTyper.typers.count)
                    append1(.init(Rect(x: chordSX, y: py - plh / 2 + h * Double(ti),
                                      width: chordW, height: h)), color: color)
                }
            }
        }
        
        return colorPathlineDic0.map { (color, pathlines) in
            .init(path: .init(pathlines), fillType: .color(color))
        } + colorPathlineDic1.map { (color, pathlines) in
            .init(path: .init(pathlines), fillType: .color(color))
        }
    }
    
    func octaveNode(fromPitch pitch: Rational, noteIs: [Int], _ color: Color = .border) -> Node {
        let node = Node(children: noteIs.map { notesNode.children[$0].children[0].clone })
        node.children.forEach { $0.fillType = .color(color) }
        return octaveNode(fromPitch: pitch, node, color)
    }
    func octaveNode(fromPitch pitch: Rational, _ noteNode: Node, enabledPitchLine: Bool = true,
                    _ color: Color = .border) -> Node {
        let pitchRange = Score.pitchRange
        guard pitchRange.contains(pitch) else { return .init() }
        
        noteNode.fillType = .color(color)
        
        let sx = x(atBeat: model.beatRange.start)
        let ex = x(atBeat: model.beatRange.end)
        
        let pd = 12 * pitchHeight
        var nodes = [Node](), nPitch = pitch, npd = 0.0
        let plw = 0.5
        nodes.append(Node(path: .init(Rect(x: sx, y: y(fromPitch: nPitch) - plw / 2,
                                           width: ex - sx, height: plw)),
                          fillType: .color(color)))
        while true {
            nPitch -= 12
            npd -= pd
            guard pitchRange.contains(nPitch) else { break }
            let node = noteNode.clone
            node.attitude.position.y = npd
            nodes.append(node)
            nodes.append(Node(path: .init(Rect(x: sx, y: y(fromPitch: nPitch) - plw / 2,
                                               width: ex - sx, height: plw)),
                              fillType: .color(color)))
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
            nodes.append(Node(path: .init(Rect(x: sx, y: y(fromPitch: nPitch) - plw / 2,
                                               width: ex - sx, height: plw)),
                              fillType: .color(color)))
        }
        return Node(children: nodes)
    }
    
    func draftNoteNode(from note: Note) -> Node {
        let noteNode = noteNode(from: note).node.children[0]
        var color = Color.draft
        color.opacity = 0.1
        noteNode.fillType = .color(color)
        return noteNode
    }
    
    func noteNode(from note: Note, color: Color? = nil,
                  lineWidth: Double? = nil) -> (node: Node,
                                                toneNode: Node,
                                                reverbNode: Node,
                                                spectlopeNode: Node) {
        guard note.beatRange.length > 0 else {
            return (.init(children: [.init(path: Path(Rect(.init(x(atBeat: note.beatRange.start),
                                                                 y(fromPitch: note.firstPitch)),
                                                           distance: 0).outsetBy(dx: 0.25, dy: 1)),
                                           fillType: .color(color != nil ? color! : .content))]),
                    .init(), .init(), .init())
        }
        let nh = noteH(from: note)
        let halfNH = nh / 2
        let nsx = x(atBeat: note.beatRange.start)
        let ny = y(fromPitch: note.firstPitch)
        let nw = width(atDurBeat: max(note.beatRange.length, Sheet.fullEditBeatInterval))
        let attackW = 0.0
        let decayW = 0.0
        let releaseW = 0.0
        let attackX = nsx + attackW, decayX = nsx + attackW + decayW, releaseX = nsx + nw + releaseW
        let nex = nsx + nw
        
        let spectlopeY = y(fromPitch: note.firstPitch) + Sheet.tonePadding
        let overtoneHalfH = 0.25
        let spectlopeH = note.spectlopeHeight
        let evenY = Sheet.evenY + spectlopeY
        let spectlopeMaxY = spectlopeY + spectlopeH
        
        var stereoLinePath, mainLinePath: Path, mainEvenLinePath: Path?, lyricLinePathlines = [Pathline]()
        var spectlopeFqLinePathlines = [Pathline](), spectlopeLinePathlines = [Pathline]()
        var spectlopeTonePanelNodes = [Node](), backSpectlopeNodes = [Node]()
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
        let isFullNoise = note.isFullNoise, lastP: Point
        let mainLineHalfH = noteMainH(from: note) / 2
        let mainEvenLineHalfH = mainLineHalfH * 0.375
        var mainEvenLineColors, stereoLineColors: [Color], knobPRCs: [(p: Point, r: Double, color: Color)]
        var toneFrames = [Rect]()
        var tonePanelKnobPRCs: [(p: Point, r: Double, color: Color)], lastStereo = note.pits[0].stereo
        if note.pits.count >= 2 {
            let pitbend = note.pitbend(fromTempo: model.tempo)
            
            let t = note.spectlopeHeight.clipped(min: Sheet.spectlopeHeight,
                                                 max: Sheet.maxSpectlopeHeight,
                                                 newMin: 0, newMax: 1)
            let toneMaxY = toneMaxY(from: note)
            
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
            
            var ps = [LinePoint](), eps = [LinePoint](), mps = [LinePoint](), meps = [LinePoint]()
            ps.append(.init(nsx, ny, halfNH, Self.color(from: note.firstStereo)))
            mps.append(.init(nsx, ny, mainLineHalfH, .content))
            if isEven {
                meps.append(.init(nsx, ny, mainEvenLineHalfH, Self.color(fromScale: note.firstTone.overtone.evenAmp)))
            }
            eps.append(.init(nsx, evenY, overtoneHalfH, Self.color(fromScale: note.firstTone.overtone.evenAmp)))
            
            let ns: [(beat: Rational, result: Note.PitResult, sumTone: Double)] = beats.map { beat in
                let result = note.pitResult(atBeat: .init(beat - note.beatRange.start))
                return (beat, result, isOneOvertone ? 0 : result.sumTone)
            }
            let maxSumTone = ns.maxValue { $0.sumTone } ?? 0
            var preBeatY: Double?
            for n in ns {
                let noteX = x(atBeat: n.beat), noteY = noteY(atBeat: n.beat, from: note)
                var stereo = n.result.stereo
                if !isOneOvertone {
                    stereo.volm *= maxSumTone == 0 ? 0 : n.sumTone / maxSumTone
                }
                lastStereo = stereo
                if (pitIsDic[n.beat]?.count ?? 0) >= 2, let preBeatY {
                    ps.append(.init(noteX, preBeatY, halfNH, Self.color(from: stereo)))
                    mps.append(.init(noteX, preBeatY, mainLineHalfH, .content))
                    if isEven {
                        meps.append(.init(noteX, preBeatY, mainEvenLineHalfH, Self.color(fromScale: n.result.tone.overtone.evenAmp)))
                    }
                }
                ps.append(.init(noteX, noteY, halfNH, Self.color(from: stereo)))
                mps.append(.init(noteX, noteY, mainLineHalfH, .content))
                if isEven {
                    meps.append(.init(noteX, noteY, mainEvenLineHalfH, Self.color(fromScale: n.result.tone.overtone.evenAmp)))
                }
                eps.append(.init(noteX, evenY, overtoneHalfH, Self.color(fromScale: n.result.tone.overtone.evenAmp)))
                preBeatY = noteY
            }
            
            ps.append(.init(nsx + nw + releaseW, noteY(atBeat: note.beatRange.end, from: note), 0,
                            ps.last!.color))
            mps.append(.init(nsx + nw + releaseW, noteY(atBeat: note.beatRange.end, from: note), mainLineHalfH / 4,
                             .content))
            if isEven {
                meps.append(.init(nsx + nw + releaseW, noteY(atBeat: note.beatRange.end, from: note), mainEvenLineHalfH / 4,
                                  meps.last!.color))
            }
            
            var preI = 0
            if attackX - ps[0].x > 0 {
                for i in 1 ..< ps.count {
                    let preP = ps[i - 1], p = ps[i]
                    if attackX >= preP.x && attackX < p.x {
                        for j in i.range {
                            ps[j].h *= (ps[j].x - ps[0].x) / (attackX - ps[0].x)
                        }
                        let t = attackX.clipped(min: preP.x, max: p.x, newMin: 0, newMax: 1)
                        ps.insert(.init(attackX,
                                        .linear(preP.y, p.y, t: t),
                                        .linear(preP.h, p.h, t: t),
                                        .rgbLinear(preP.color, p.color, t: t)), at: i)
                        preI = i
                        break
                    }
                }
            }
            let susVolm = note.envelope.sustainVolm
            if decayX - ps[preI].x > 0 {
                for i in preI + 1 ..< ps.count {
                    let preP = ps[i - 1], p = ps[i]
                    if decayX >= preP.x && decayX < p.x {
                        for j in i.range {
                            ps[j].h *= ps[j].x.clipped(min: ps[preI].x, max: decayX, newMin: 1, newMax: susVolm)
                        }
                        let t = decayX.clipped(min: preP.x, max: p.x, newMin: 0, newMax: 1)
                        ps.insert(.init(decayX,
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
            
            knobPRCs = note.pits.map { (.init(x(atBeat: note.beatRange.start + $0.beat),
                                              y(fromPitch: note.pitch + $0.pitch)),
                                        (note.beatRange.start + $0.beat) % Sheet.beatInterval == 0
                                        && (note.pitch + $0.pitch).isInteger ? knobR : knobR / 2,
                                        $0.tone.baseColor()) }
            
            stereoLinePath = .init(triangleStrip(ps))
            stereoLineColors = colors(ps)
            
            mainLinePath = .init(triangleStrip(mps))
            
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
            var sprolKnobPAndRs = [(Point, Double, Color)](capacity: pitbend.pits.count)
            func curveSpectlopeNodes() -> [Node] {
                struct VItem {
                    var vs: [[PAndColor]]
                    var fqPs: [Point]
                    var y: Double
                }
                var vItems = [VItem](), vItem = VItem(vs: [], fqPs: [], y: oy),
                    pitIs = [Int](),
                    lastV: [PAndColor]?, isLastAppned = false
                for (bi, nBeat) in beats.enumerated() {
                    let nx = self.x(atBeat: nBeat)
                    let sprols = pitbend.spectlope(atSec: Double(model.sec(fromBeat: nBeat - note.beatRange.start))).sprols
                    let psPitch = pitch(atBeat: nBeat, from: note)
                    let noteY = y(fromPitch: psPitch)
                    
                    let topY = noteY
                    if currentY - topY < Sheet.tonePadding / 2
                        || currentY - topY > Sheet.tonePadding * 3 / 2
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
                        let sprols = pitbend.pits[pi].tone.spectlope.sprols
                        let sprolYs = sprols.map { tonePanelPitchY(fromPitch: $0.pitch, atY: p.y) }
                        sprolKnobPAndRs += sprols.enumerated().map { (spi, sprol) in
                            let d0 = spi + 1 < sprols.count ? (sprolYs[spi + 1] - sprolYs[spi]) / 2 : sprolR
                            let d1 = spi - 1 >= 0 ? (sprolYs[spi] - sprolYs[spi - 1]) / 2 : sprolR
                            return (Point(p.x, sprolYs[spi]),
                                    min(d0, d1).clipped(min: 0.015625 / 2, max: sprolR),
                                    sprol.volm == 0 ?
                                    Color.subBorder :
                                        (spi > 0 && sprols[spi - 1].pitch > sprol.pitch ? Color.warning : Color.background))
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
            
            lastP = .init(ps.last!.point)
        } else {
            let sustainHalfH = halfNH * note.envelope.sustainVolm
            let color = Self.color(from: note.pits[0].stereo)
            stereoLinePath = .init(triangleStrip([.init(nsx, ny, 0, color),
                                            .init(attackX, ny, halfNH, color),
                                            .init(decayX, ny, sustainHalfH, color),
                                            .init(nsx + nw, ny, sustainHalfH, color),
                                            .init(releaseX, ny, 0, color)]))
            stereoLineColors = [color]
            
            mainLinePath = .init(triangleStrip([.init(nsx, ny, mainLineHalfH, .content),
                                                .init(nsx + nw, ny, mainLineHalfH, .content),
                                                .init(nsx + nw, ny, mainLineHalfH / 4, .content),
                                                .init(releaseX, ny, mainLineHalfH / 4, .content)]))
            
            if isEven {
                let mainEvenLineColor = Self.color(fromScale: note.firstTone.overtone.evenAmp)
                mainEvenLinePath = .init(triangleStrip([.init(nsx, ny, mainEvenLineHalfH, mainEvenLineColor),
                                                        .init(nsx + nw, ny, mainEvenLineHalfH, mainEvenLineColor),
                                                        .init(nsx + nw, ny, mainEvenLineHalfH / 4, mainEvenLineColor),
                                                        .init(releaseX, ny, mainEvenLineHalfH / 4, mainEvenLineColor)]))
                mainEvenLineColors = [mainEvenLineColor]
            } else {
                mainEvenLineColors = []
            }
            
            knobPRCs = note.pits.map { (.init(x(atBeat: note.beatRange.start + $0.beat),
                                              y(fromPitch: note.pitch + $0.pitch)),
                                        (note.beatRange.start + $0.beat) % Sheet.beatInterval == 0
                                        && note.firstPitch.isInteger ? knobR : knobR / 2,
                                        note.firstTone.baseColor()) }
            
            let fPitNx = x(atBeat: note.beatRange.start + note.firstPit.beat)
            
            let sprols = note.firstTone.spectlope.sprols
            let noteY = spectlopeY
            let sprolYs = sprols.map { tonePanelPitchY(fromPitch: $0.pitch, atY: noteY) }
            let sprolKnobPRCs = sprols.enumerated().map { (spi, sprol) in
                let d0 = spi + 1 < sprols.count ? (sprolYs[spi + 1] - sprolYs[spi]) / 2 : sprolR
                let d1 = spi - 1 >= 0 ? (sprolYs[spi] - sprolYs[spi - 1]) / 2 : sprolR
                return (Point(fPitNx, sprolYs[spi]),
                        min(d0, d1).clipped(min: 0.015625 / 2, max: sprolR),
                        sprol.volm == 0 ?
                        Color.subBorder :
                            (spi > 0 && sprols[spi - 1].pitch > sprol.pitch ? Color.border : Color.background))
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
            
            lastP = .init(nex, ny)
        }
        
        let isMinSpectlopeHeight = note.spectlopeHeight == Sheet.spectlopeHeight
        let isHiddenFullEdit = isMinSpectlopeHeight ? !isFullEdit : !isEditTone
        
        let earlyReverbColor = Self.color(from: .init(volm: note.envelope.reverb.earlyVolm, pan: lastStereo.pan))
        let lateReverbColor = Self.color(from: .init(volm: note.envelope.reverb.lateVolm, pan: lastStereo.pan))
        let zeroReverbColor = Self.color(from: .init(volm: 0, pan: lastStereo.pan))
        let earlyReverbP = earlyReverbPosition(from: note)
        let lateReverbP = lateReverbPosition(from: note)
        let durReverbP = durReverbPosition(from: note)
        let reverbLineHalfH = 0.125, reverbHalfH = reverbLineHalfH / 2
        let rps = [earlyReverbP, lateReverbP, durReverbP]
        let reverbBackKnobPathlines = rps.map { Pathline(circleRadius: sprolR * 1.5, position: $0) }
        let reverbKnobPathlines = rps.map { Pathline(circleRadius: sprolR, position: $0) }
        let reverbNodes: [Node] = note.isDefaultTone ? [] : [
            .init(path: .init(Rect(x: lastP.x, y: lastP.y - reverbLineHalfH,
                                   width: durReverbP.x - lastP.x, height: reverbLineHalfH * 2)),
                  fillType: .color(.content)),
            .init(path: .init(Rect(x: lastP.x, y: lastP.y - reverbHalfH,
                                   width: earlyReverbP.x - lastP.x, height: reverbHalfH * 2)),
                  fillType: .color(earlyReverbColor)),
            .init(path: .init([.init(earlyReverbP.x, lastP.y + reverbHalfH),
                               .init(earlyReverbP.x, lastP.y - reverbHalfH),
                               .init(lateReverbP.x, lastP.y - reverbHalfH),
                               .init(lateReverbP.x, lastP.y + reverbHalfH)]),
                  fillType: .gradient([earlyReverbColor, earlyReverbColor, lateReverbColor, lateReverbColor])),
            .init(path: .init([.init(lateReverbP.x, lastP.y + reverbHalfH),
                               .init(lateReverbP.x, lastP.y - reverbHalfH),
                               .init(durReverbP.x, lastP.y - reverbHalfH),
                               .init(durReverbP.x, lastP.y + reverbHalfH)]),
                  fillType: .gradient([lateReverbColor, lateReverbColor, zeroReverbColor, zeroReverbColor])),
            .init(name: "isFullEdit",
                  isHidden: !isFullEdit,
                  path: .init(reverbBackKnobPathlines), fillType: .color(.content)),
            .init(name: "isFullEdit",
                  isHidden: !isFullEdit,
                  path: .init(reverbKnobPathlines), fillType: .color(.background))
        ]
        
        var nodes = [Node]()
        nodes.append(.init(path: stereoLinePath,
                           fillType: color != nil ? .color(color!) : (stereoLineColors.count == 1 ? .color(stereoLineColors[0]) : .gradient(stereoLineColors))))
        nodes.append(.init(path: mainLinePath, fillType: .color(.content)))
        if let mainEvenLinePath {
            nodes.append(.init(path: mainEvenLinePath,
                               fillType: color != nil ? .color(color!) : (mainEvenLineColors.count == 1 ? .color(mainEvenLineColors[0]) : .gradient(mainEvenLineColors))))
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
        for (color, prs) in knobPrcsDic.sorted(by: { $0.key.lightness < $1.key.lightness }) {
            let backKnobPathlines = prs.map {
                Pathline(circleRadius: $0.r * 1.5, position: $0.p)
            }
            let knobPathlines = prs.map {
                Pathline(circleRadius: $0.r, position: $0.p)
            }
            nodes.append(.init(path: .init(backKnobPathlines), fillType: .color(.content)))
            nodes.append(.init(path: .init(knobPathlines), fillType: .color(color)))
        }
        
        var tonePanelNodes = [Node]()
        let boxPath = Path(toneFrames.map { Pathline($0) })
        tonePanelNodes.append(.init(path: boxPath, fillType: .color(.background)))
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
        tonePanelNodes.append(.init(name: isMinSpectlopeHeight ? "isFullEdit" : "point",
                                    isHidden: isHiddenFullEdit,
                                    path: Path(toneFrames.map {
            Pathline(Rect(origin: $0.minXMaxYPoint + .init(0, 0.03125), size: .init(width: $0.width, height: 0.0625)))
        }), fillType: .color(.content)))
        
        if !tonePanelKnobPRCs.isEmpty {
            let toneBackKnobPathlines = tonePanelKnobPRCs.map {
                Pathline(circleRadius: $0.r * 1.5, position: $0.p)
            }
            
            tonePanelNodes.append(.init(name: isMinSpectlopeHeight ? "isFullEdit" : "point",
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
                
                tonePanelNodes.append(.init(name: isMinSpectlopeHeight ? "isFullEdit" : "point",
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
        
        let boundingBox = nodes.reduce(into: Rect?.none) { $0 += $1.drawableBounds }
        let tonePanelBoundingBox = tonePanelNodes.reduce(into: Rect?.none) { $0 += $1.drawableBounds }
        let reverbBoundingBox = reverbNodes.reduce(into: Rect?.none) { $0 += $1.drawableBounds }
        let backSpectlopeBoundingBox = backSpectlopeNodes.reduce(into: Rect?.none) { $0 += $1.drawableBounds }
        return (Node(children: nodes,
                    path: boundingBox != nil ? Path(boundingBox!) : .init()),
                Node(children: [],
                     path: tonePanelBoundingBox != nil ? Path(tonePanelBoundingBox!) : .init()),
                Node(children: reverbNodes,
                     path: reverbBoundingBox != nil ? Path(reverbBoundingBox!) : .init()),
                Node(children: backSpectlopeNodes,
                     path: backSpectlopeBoundingBox != nil ? Path(backSpectlopeBoundingBox!) : .init()))
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
    static func lightness(fromScale scale: Double) -> Double {
        scale.clipped(min: 0, max: 1, newMin: 100, newMax: Color.content.lightness)
    }
    static func color(fromScale scale: Double) -> Color {
        Color(lightness: lightness(fromScale: scale))
    }
    static func color(fromScale scale: Double, noise: Double) -> Color {
        color(fromLightness: lightness(fromScale: scale * 0.65), noise: noise)
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
        let lightness = volm.clipped(min: Volm.minVolm, max: Volm.safeVolm,
                                     newMin: 100, newMax: Color.content.lightness)
        let l = Double(Color(lightness: lightness).rgba.r)
        return if pan == 0 {
            Color(red: l, green: l, blue: l)
        } else if pan > 0 {
            Color(red: pan * Spectrogram.editRedRatio * (1 - l) + l, green: l, blue: l)
        } else {
            Color(red: l, green: -pan * Spectrogram.editGreenRatio * (1 - l) + l, blue: l)
        }
    }
    
    func updateTimeNode(atSec sec: Rational) {
        if model.enabled {
            let frame = mainFrame
            let x = self.x(atSec: sec)
            if x >= frame.minX && x < frame.maxX {
                timeNode.path = Path([Point(), Point(0, frame.maxY - timelineFrame.minY)])
                timeNode.attitude.position = Point(x, timelineFrame.minY)
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
        mainFrame + timelineFrame
    }
    var transformedClippableBounds: Rect? {
        if let bounds = clippableBounds {
            bounds * node.localTransform
        } else {
            nil
        }
    }
    
    func contains(_ p : Point, scale: Double) -> Bool {
        model.enabled
        && (containsTimeline(p, scale: scale)
            || containsIsShownSpectrogram(p, scale: scale)
            || containsMainFrame(p, scale: scale)
            || containsNote(p, scale: scale, enabledTone: true, enabledRelease: true))
    }
    func containsMainFrame(_ p: Point, scale: Double) -> Bool {
        model.enabled && mainFrame.outset(by: 10 * scale).contains(p)
    }
    func containsTimeline(_ p : Point, scale: Double) -> Bool {
        model.enabled && timelineFrame.outsetBy(dx: 5 * scale, dy: 3 * scale).contains(p)
    }
    var timelineFrame: Rect {
        let sx = self.x(atBeat: model.beatRange.start)
        let ex = self.x(atBeat: model.beatRange.end)
        return Rect(x: sx, y: timelineCenterY - Sheet.timelineHalfHeight,
                    width: ex - sx, height: Sheet.timelineHalfHeight * 2)
    }
    var transformedTimelineFrame: Rect? {
        timelineFrame
    }
    
    func keyBeatIndex(at p: Point, scale: Double) -> Int? {
        guard containsTimeline(p, scale: scale) else { return nil }
        let maxD = Sheet.knobEditDistance * scale
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
    
    func containsNote(_ p: Point, scale: Double, enabledTone: Bool = false, enabledRelease: Bool = false) -> Bool {
        noteIndex(at: p, scale: scale,
                  enabledTone: enabledTone, enabledRelease: enabledRelease) != nil
    }
    func noteIndex(at p: Point, scale: Double, enabledTone: Bool = false, enabledRelease: Bool = false) -> Int? {
        let hnh = pitchHeight / 2
        var minDS = Double.infinity, minI: Int?
        for (noteI, note) in model.notes.enumerated().reversed() {
            let noteD = noteH(from: note) / 2
            let maxPitD = Sheet.knobEditDistance * scale + noteD
            let maxPitDS = maxPitD * maxPitD
            let nf = noteFrame(at: noteI).outset(by: hnh)
            let ods = nf.distanceSquared(p)
            if ods < maxPitDS {
                let ds = pointline(from: note).minDistanceSquared(at: p)
                if ds < noteD * noteD {
                    return noteI
                } else if ds < minDS && ds < maxPitDS {
                    minDS = ds
                    minI = noteI
                }
            }
            
            if enabledTone {
                for (_, toneFrame) in toneFrames(from: note) {
                    let maxD = Sheet.knobEditDistance * scale
                    let maxDS = maxD * maxD
                    
                    let ds = toneFrame.distanceSquared(p)
                    if ds < minDS && ds < maxDS {
                        return noteI
                    }
                }
            }
            
            if enabledRelease {
                let maxD = Sheet.knobEditDistance * scale
                let maxDS = maxD * maxD
                
                let erp = earlyReverbPosition(from: note)
                let elrp = lateReverbPosition(from: note)
                var ds = erp.distanceSquared(p)
                if ds < minDS && ds < maxDS && (erp.x == elrp.x ? p.x < erp.x : true) {
                    minDS = ds
                    minI = noteI
                }
                
                ds = elrp.distanceSquared(p)
                if ds < minDS && ds < maxDS && (erp.x == elrp.x ? p.x > erp.x : true) {
                    minDS = ds
                    minI = noteI
                }
                
                let drp = durReverbPosition(from: note)
                ds = drp.distanceSquared(p)
                if ds < minDS && ds < maxDS && (elrp.x == drp.x ? p.x > elrp.x : true) {
                    minDS = ds
                    minI = noteI
                }
            }
        }
        return minI
    }
    
    enum PointHitResult {
        case note
        case startBeat
        case endBeat
        case pit(pitI: Int)
        case reverbEarlyRSec
        case reverbEarlyAndLateRSec
        case reverbDurSec
        case even(pitI: Int)
        case sprol(pitI: Int, sprolI: Int, y: Double)
        case spectlopeHeight
    }
    func hitTestPoint(_ p: Point, scale: Double) -> (noteI: Int, result: PointHitResult)? {
        let maxD = Sheet.knobEditDistance * scale
        let maxDSq = maxD * maxD
        let toneMaxD = min(Sheet.tonePadding - Sheet.noteHeight / 2,
                           Sheet.knobEditDistance * scale)
        let toneMaxDSq = toneMaxD * toneMaxD
        var minDSq = Double.infinity, minResult: (noteI: Int, result: PointHitResult)?
        var containsNote = false
        var isPit = false
        for (noteI, note) in model.notes.enumerated().reversed() {
            if note.spectlopeHeight == Sheet.spectlopeHeight ? isFullEdit : isEditTone {
                for (pitIs, toneFrame) in toneFrames(from: note) {
                    let dSq = toneFrame.distanceSquared(p)
                    if dSq < minDSq && dSq < toneMaxDSq {
                        let containsTone = toneFrame.contains(p)
                        
                        for pitI in pitIs {
                            let pit = note.pits[pitI]
                            for (sprolI, _) in pit.tone.spectlope.sprols.enumerated() {
                                let sprolP = sprolPosition(atSprol: sprolI, atPit: pitI, from: note,
                                                           atY: toneFrame.minY)
                                let dSq = sprolP.distanceSquared(p)
                                if dSq < minDSq {
                                    minDSq = dSq
                                    minResult = (noteI, .sprol(pitI: pitI, sprolI: sprolI, y: toneFrame.minY))
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
            
            let nsx = x(atBeat: note.beatRange.start)
            let nex = x(atBeat: note.beatRange.end)
            let nw = nex - nsx
            let nMaxDSq = note.pits.count == 1 && nw / 4 < maxD ? (nw / 4).squared : maxDSq
            for pitI in note.pits.count.range {
                let pitP = pitPosition(atPit: pitI, from: note)
                let dSq = pitP.distanceSquared(p)
                if dSq < minDSq && dSq < nMaxDSq {
                    minDSq = dSq
                    minResult = (noteI, .pit(pitI: pitI))
                    isPit = true
                }
            }
            
            let noteD = noteH(from: note) / 2
            let maxPitD = Sheet.knobEditDistance * scale + noteD
            let nfsw = (nex - nsx) / scale
            let dx = nfsw.clipped(min: 3, max: 30, newMin: 1, newMax: 8) * scale
            let nsy = noteY(atBeat: note.beatRange.start, from: note)
            let ney = noteY(atBeat: note.beatRange.end, from: note)
            let ndx = note.pits.count == 1 && nw / 4 < dx ? nw / 4 : dx
            let pdSq = pointline(from: note).minDistanceSquared(at: p)
            if p.x < nsx + ndx && abs(p.y - nsy) < maxD {
                let dSq = min(pdSq, p.distanceSquared(.init(nsx, nsy)))
                if dSq < minDSq && pdSq < maxPitD * maxPitD {
                    minDSq = dSq
                    minResult = (noteI, .startBeat)
                }
            } else if p.x > nex - ndx && abs(p.y - ney) < maxD {
                let dSq = min(pdSq, p.distanceSquared(.init(nex, ney)))
                if dSq < minDSq && pdSq < maxPitD * maxPitD {
                    minDSq = dSq
                    minResult = (noteI, .endBeat)
                }
            } else if !isPit {
                if pdSq < minDSq && pdSq < maxPitD * maxPitD {
                    minDSq = pdSq
                    minResult = (noteI, .note)
                }
            }
            
            let hnh = pitchHeight / 2
            let maxPitDS = maxPitD * maxPitD
            let nf = noteFrame(at: noteI).outset(by: hnh)
            let ods = nf.distanceSquared(p)
            if ods < maxPitDS {
                let ds = pointline(from: note).minDistanceSquared(at: p)
                if ds < noteD * noteD {
                    containsNote = true
                }
            }
        }
        
        if containsNote {
            return minResult
        }
        
        if isFullEdit {
            for (noteI, note) in model.notes.enumerated().reversed() {
                guard !note.isDefaultTone else { continue }
                let reverbFrame = reverbFrame(from: note)
                let dSq = reverbFrame.distanceSquared(p)
                if dSq < minDSq && dSq < toneMaxDSq {
                    let containsReverb = reverbFrame.contains(p)
                    
                    let earlyReverbP = earlyReverbPosition(from: note)
                    let lateReverbP = lateReverbPosition(from: note)
                    var dSq = earlyReverbP.distanceSquared(p)
                    if dSq < minDSq && (earlyReverbP.x == lateReverbP.x ? p.x < earlyReverbP.x : true) {
                        minDSq = dSq
                        minResult = (noteI, .reverbEarlyRSec)
                    }
                    
                    dSq = lateReverbP.distanceSquared(p)
                    if dSq < minDSq && (earlyReverbP.x == lateReverbP.x ? p.x > earlyReverbP.x : true) {
                        minDSq = dSq
                        minResult = (noteI, .reverbEarlyAndLateRSec)
                    }
                    
                    let durReverbP = durReverbPosition(from: note)
                    dSq = durReverbP.distanceSquared(p)
                    if dSq <= minDSq && (lateReverbP.x == durReverbP.x ? p.x > lateReverbP.x : true) {
                        minDSq = dSq
                        minResult = (noteI, .reverbDurSec)
                    }
                    
                    if containsReverb {
                        return minResult
                    }
                }
            }
        }
        
        return minResult
    }
    
    enum ColorHitResult {
        case note
        case pit(pitI: Int)
        case reverbEarlyRVolm
        case reverbLateRVolm
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
        
        for (noteI, note) in model.notes.enumerated().reversed() {
            if note.spectlopeHeight == Sheet.spectlopeHeight ? isFullEdit : isEditTone {
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
                                    let result = note.pitResult(atBeat: beat - .init(note.beatRange.start))
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
            
            for pitI in note.pits.count.range {
                let pitP = pitPosition(atPit: pitI, from: note)
                let dSq = pitP.distanceSquared(p)
                if dSq < minDSq && dSq < maxDSq {
                    minDSq = dSq
                    minResult = (noteI, .pit(pitI: pitI))
                }
            }
            
            let hnh = pitchHeight / 2
            let noteD = noteH(from: note) / 2
            let maxPitD = Sheet.knobEditDistance * scale + noteD
            let maxPitDS = maxPitD * maxPitD
            let nf = noteFrame(at: noteI).outset(by: hnh)
            let ods = nf.distanceSquared(p)
            if ods < maxPitDS {
                let ds = pointline(from: note).minDistanceSquared(at: p)
                if ds < noteD * noteD {
                    return minResult ?? (noteI, .note)
                }
            }
        }
        
        if isFullEdit {
            let hnh = pitchHeight / 2
            for (noteI, note) in model.notes.enumerated().reversed() {
                guard !note.isDefaultTone else { continue }
                let noteD = noteH(from: note) / 2
                let maxPitD = Sheet.knobEditDistance * scale + noteD
                let maxPitDS = maxPitD * maxPitD
                let nf = noteFrame(at: noteI).outset(by: hnh)
                let ods = nf.distanceSquared(p)
                if ods < maxPitDS {
                    let ds = pointline(from: note).minDistanceSquared(at: p)
                    if ds < noteD * noteD { break }
                }
                
                let reverbFrame = reverbFrame(from: note)
                let dSq = reverbFrame.distanceSquared(p)
                if dSq < minDSq && dSq < maxDSq {
                    let containsReverb = reverbFrame.contains(p)
                    
                    let earlyReverbP = earlyReverbPosition(from: note)
                    var dSq = earlyReverbP.distanceSquared(p)
                    if dSq < minDSq {
                        minDSq = dSq
                        minResult = (noteI, .reverbEarlyRVolm)
                    }
                    
                    let lateReverbP = lateReverbPosition(from: note)
                    dSq = lateReverbP.distanceSquared(p)
                    if dSq < minDSq {
                        minDSq = dSq
                        minResult = (noteI, .reverbLateRVolm)
                    }
                    
                    if containsReverb {
                        return minResult
                    }
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
    func containsTone(at p: Point) -> Bool {
        for note in model.notes {
            if toneFrames(from: note).contains(where: { $0.frame.contains(p) }) {
                return true
            }
        }
        return false
    }
    func containsTone(at p: Point, at noteI: Int) -> Bool {
        toneFrames(at: noteI).contains(where: { $0.frame.contains(p) })
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
            let pitbend = note.pitbend(fromTempo: model.tempo)
            
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
                let psPitch = pitch(atBeat: nBeat, from: note)
                let noteY = y(fromPitch: psPitch)
                
                let topY = noteY
                if currentY - topY < Sheet.tonePadding / 2
                    || currentY - topY > Sheet.tonePadding * 3 / 2
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
            let nw = width(atDurBeat: max(note.beatRange.length, Sheet.fullEditBeatInterval))
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
    func pitIAndSprolI(at p: Point, at noteI: Int) -> (pitI: Int, sprolI: Int)? {
        let score = model
        let note = score.notes[noteI]
        var minDS = Double.infinity, minPitI: Int?, minSprolI: Int?
        for (pitIs, toneFrame) in toneFrames(at: noteI) {
            guard toneFrame.contains(p) else { continue }
            for pitI in pitIs {
                let pit = note.pits[pitI]
                for (sprolI, _) in pit.tone.spectlope.sprols.enumerated() {
                    let psp = sprolPosition(atSprol: sprolI, atPit: pitI, at: noteI, atY: toneFrame.minY)
                    let ds = p.distanceSquared(psp)
                    if ds < minDS {
                        minDS = ds
                        minPitI = pitI
                        minSprolI = sprolI
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
    
    func earlyReverbPosition(from note: Note) -> Point {
        noteLastPosition(from: note) + .init(width(atDurSec: note.envelope.reverb.earlySec), 0)
    }
    func reverbEarlyRSecPosition(at noteI: Int) -> Point {
        earlyReverbPosition(from: model.notes[noteI])
    }
    func lateReverbPosition(from note: Note) -> Point {
        noteLastPosition(from: note) + .init(width(atDurSec: note.envelope.reverb.earlyLateSec), 0)
    }
    func reverbEarlyAndLateRSecPosition(at noteI: Int) -> Point {
        lateReverbPosition(from: model.notes[noteI])
    }
    func durReverbPosition(from note: Note) -> Point {
        noteLastPosition(from: note) + .init(width(atDurSec: note.envelope.reverb.durSec), 0)
    }
    func reverbDurSecPosition(at noteI: Int) -> Point {
        durReverbPosition(from: model.notes[noteI])
    }
    
    func reverbFrame(from note: Note) -> Rect {
        let lastP = noteLastPosition(from: note)
        let durReverbP = durReverbPosition(from: note)
        let reverbHalfH = Sheet.reverbHeight / 2
        return .init(x: lastP.x, y: lastP.y - reverbHalfH,
                     width: durReverbP.x - lastP.x, height: reverbHalfH * 2)
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
        let allBeat = score.beatRange.end
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
    
    func containsIsShownSpectrogram(_ p: Point, scale: Double) -> Bool {
        Rect(x: x(atBeat: model.beatRange.start) + Sheet.spectrogramX - Sheet.knobHeight / 2,
                 y: timelineCenterY + Sheet.timelineHalfHeight,
                 width: Sheet.knobHeight,
             height: Sheet.isShownSpectrogramHeight)
            .outset(by: scale * 3)
            .contains(p)
    }
    
    func isShownSpectrogram(at p :Point) -> Bool {
        p.y > timelineCenterY + Sheet.timelineHalfHeight + Sheet.isShownSpectrogramHeight / 2
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
