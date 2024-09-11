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

final class LightnessChanger: DragEditor {
    let editor: ColorEditor
    
    init(_ document: Document) {
        editor = ColorEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.changeLightness(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class TintChanger: DragEditor {
    let editor: ColorEditor
    
    init(_ document: Document) {
        editor = ColorEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.changeTint(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class ColorEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    var colorOwners = [SheetColorOwner]()
    var fp = Point()
    var firstUUColor = UU(Color())
    var editingUUColor = UU(Color())
    
    var isEditableMaxLightness: Bool {
        document.colorSpace.isHDR
    }
    var maxLightness: Double {
        document.colorSpace.maxLightness
    }
    var isEditableOpacity = false
    
    func updateNode() {
        let attitude = Attitude(document.screenToWorldTransform)
        
        var lightnessAttitude = attitude
        lightnessAttitude.position = lightnessWorldPosition
        lightnessNode.attitude = lightnessAttitude
        
        var tintAttitude = attitude
        tintAttitude.position = tintWorldPosition
        tintBorderNode.attitude = tintAttitude
        tintNode.attitude = tintAttitude
        
        panNode.attitude = attitude.with(position: panWorldPosition)
    }
    
    var isDrawPoints = true
    var pointNodes = [Node]()
    
    let colorPointNode = Node(path: Path(circleRadius: 4.5), lineWidth: 1,
                              lineType: .color(.background),
                              fillType: .color(.content))
    let whiteLineNode = Node(lineWidth: 2,
                             lineType: .color(.content))
    var whiteLightnessHeight = 140.0
    var maxLightnessHeight: Double {
        isEditableMaxLightness ?
            whiteLightnessHeight * maxLightness / Color.whiteLightness :
            whiteLightnessHeight
    }
    private func lightnessPointsWith(splitCount count: Int = 140) -> [Point] {
        let rCount = 1 / Double(count)
        return (0 ... count).map {
            let t = Double($0) * rCount
            return Point(0, maxLightnessHeight * t)
        }
    }
    private func lightnessGradientWith(chroma: Double, hue: Double,
                                       splitCount count: Int = 140, isReversed: Bool = false) -> [Color] {
        let rCount = 1 / Double(count)
        return (0 ... count).map {
            let t = Double.linear(isReversed ? maxLightness : Color.minLightness,
                                  isReversed ? Color.minLightness : maxLightness,
                                  t: Double($0) * rCount)
            return Color(lightness: t, unsafetyChroma: chroma, hue: hue,
                         document.colorSpace)
        }
    }
    private func opacityPointsWith(splitCount count: Int = 100) -> [Point] {
        let rCount = 1 / Double(count)
        return (0 ... count).map {
            let t = Double($0) * rCount
            return Point(-opaqueWidth * t - opaqueWidth, 0)
        }
    }
    private func opacityGradientWith(color: Color,
                                     splitCount count: Int = 100) -> [Color] {
        let rCount = 1 / Double(count)
        return (0 ... count).map {
            var color0 = color
            color0.opacity = 1 - Double($0) * rCount
            let color1 = $0 % 2 == 0 ? Color(white: 0.4) : Color(white: 0.6)
            return color1.alphaBlend(color0)
        }
    }
    let opacityWidth = 100.0, opaqueWidth = 10.0
    let opacityNode = Node(lineWidth: 2)
    var opacityNodeX: Double {
        editingUUColor.value.opacity
            .clipped(min: 0, max: 1,
                     newMin: -opaqueWidth - opaqueWidth,
                     newMax: -opaqueWidth)
    }
    func opacity(atX x: Double) -> Double {
        x.clipped(min: -opaqueWidth - opaqueWidth,
                  max: -opaqueWidth,
                  newMin: 0, newMax: 1)
    }
    let lightnessNode = Node(lineWidth: 2)
    var isReversedLightness = false
    var isEditingLightness = false {
        didSet {
            guard isEditingLightness != oldValue else { return }
            if isEditingLightness {
                let color = firstUUColor.value
                
                if isEditableOpacity {
                    opacityNode.lineType = .gradient(opacityGradientWith(color: color))
                    lightnessNode.append(child: opacityNode)
                }
                
                let gradient = lightnessGradientWith(chroma: color.chroma,
                                                     hue: color.hue,
                                                     splitCount: Int(maxLightnessHeight), 
                                                     isReversed: isReversedLightness)
                lightnessNode.lineType = .gradient(gradient)
                document.rootNode.append(child: lightnessNode)
                if isEditableMaxLightness {
                    whiteLineNode.path = Path(Edge(Point(-0.5, whiteLightnessHeight),
                                                   Point(0.5, whiteLightnessHeight)))
                    lightnessNode.append(child: whiteLineNode)
                }
                lightnessNode.append(child: colorPointNode)
            } else {
                lightnessNode.removeFromParent()
                whiteLineNode.removeFromParent()
                colorPointNode.removeFromParent()
            }
        }
    }
    var firstLightnessPosition = Point() {
        didSet {
            lightnessNode.attitude.position = lightnessWorldPosition
        }
    }
    var lightnessWorldPosition: Point {
        let sfp = document.convertWorldToScreen(firstLightnessPosition)
        let t = oldEditingLightness.clipped(min: Color.minLightness,
                                            max: maxLightness,
                                            newMin: 0, newMax: 1)
        let dp = Point(0, maxLightnessHeight * t)
        return document.convertScreenToWorld(sfp - dp)
    }
    var isSnappedLightness = true {
        didSet {
            guard isSnappedLightness != oldValue else { return }
            if isSnappedLightness {
                Feedback.performAlignment()
            }
            colorPointNode.fillType = .color(isSnappedLightness ? .selected : .content)
        }
    }
    var oldEditingLightness = 0.0
    var editingLightness = 0.0 {
        didSet {
            let t = editingLightness.clipped(min: Color.minLightness,
                                             max: maxLightness,
                                             newMin: 0, newMax: 1)
            let p = Point(0, maxLightnessHeight * t)
            colorPointNode.attitude.position = p
            
            if isEditableOpacity {
                opacityNode.attitude.position = p
                opacityNode.lineType = .gradient(opacityGradientWith(color: editingUUColor.value))
            }
        }
    }
    
    func updateOwners(with event: DragEvent) {
        let p = document.convertScreenToWorld(event.screenPoint)
        
        if let (uuColor, owners) = document.madeColorOwnersWithSelection(at: p) {
            self.firstUUColor = uuColor
            self.colorOwners = owners
        } else {
            self.colorOwners = []
        }
    }
    func updateTintPointNodes(with event: DragEvent) {
        let p = document.convertScreenToWorld(event.screenPoint)
        
        if isDrawPoints {
            pointNodes = document.colors(at: p).map {
                let cp = $0.tint.rectangular
                return Node(path: .init(circleRadius: 1.5, position: cp),
                            lineWidth: 0.5,
                            lineType: .color(.background),
                            fillType: .color(.content))
            }
        }
    }
    
    func capture() {
        var ssSet = Set<SheetView>()
        colorOwners.forEach {
            if ssSet.contains($0.sheetView) {
                $0.captureUUColor(isNewUndoGroup: false)
            } else {
                ssSet.insert($0.sheetView)
                $0.captureUUColor(isNewUndoGroup: true)
            }
        }
    }
    
    func volmNodes(fromVolm scale: Double, firstVolm: Double, at p: Point) -> [Node] {
        let vh = 50.0
        let vKnobW = 8.0, vKbobH = 2.0
        let vx = 0.0, vy = 0.0
        let y = scale.clipped(min: 0, max: 1)
        let fy = firstVolm.clipped(min: 0, max: 1)
        let path = Path([Pathline(Polygon(points: [Point(vx, vy),
                                                   Point(vx + 1.5, vy + vh),
                                                   Point(vx - 1.5, vy + vh)])),
                         Pathline(Rect(x: vx - vKnobW / 2,
                                       y: vy + y - vKbobH / 2,
                                       width: vKnobW,
                                       height: vKbobH))])
        return [Node(attitude: .init(position: p - Point(0, fy)), path: path,
                     fillType: .color(.content))]
    }
    
    private func panPointsWith(splitCount count: Int = 140, width: Double) -> [Point] {
        let rCount = 1 / Double(count)
        return (0 ... count).map {
            let t = Double($0) * rCount
            return Point(-width / 2 + width * t, 0)
        }
    }
    private func panGradientWith(splitCount count: Int = 140, volm: Double) -> [Color] {
        let rCount = 1 / Double(count)
        return (0 ... count).map {
            ScoreView.color(fromPan: Double($0) * rCount * 2 - 0.5, volm: volm)
        }
    }
    
    private func noisePointsWith(splitCount count: Int = 140, width: Double) -> [Point] {
        let rCount = 1 / Double(count)
        return (0 ... count).map {
            let t = Double($0) * rCount
            return Point(width * t, 0)
        }
    }
    private func noiseGradientWith(splitCount count: Int = 140, volm: Double) -> [Color] {
        let rCount = 1 / Double(count)
        return (0 ... count).map {
            ScoreView.color(fromVolm: volm, noise: Double($0) * rCount)
        }
    }
    
    private var isChangeVolm = false
    private var sheetView: SheetView?
    private var scoreResult: ScoreView.ColorHitResult?
    private var beganEnvelope = Envelope(), beganNotes = [Int: Note]()
    private var beganNotePits = [UUID: (nid: UUID, nColor: Color, dic: [Int: (note: Note, pits: [Int: (pit: Pit, sprolIs: Set<Int>)])])]()
    private var beganContents = [Int: Content]()
    private var beganSP = Point(), beganVolm = 0.0
    private var notePlayer: NotePlayer?, playerBeatNoteIndexes = [Int](), beganBeat = Rational(0)
    
    func changeVolm(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        let sp = event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isPlaying(with: event) {
                document.stopPlaying(with: event)
            }
            
            beganSP = sp
            let p = document.convertScreenToWorld(sp)
            if let sheetView = document.sheetView(at: p) {
                self.sheetView = sheetView
                
                func updateContentsWithSelections() {
                    let fs = document.selections
                        .map { $0.rect }
                        .map { sheetView.convertFromWorld($0) }
                    if !fs.isEmpty {
                        beganContents = sheetView.contentsView.elementViews.enumerated().reduce(into: [Int: Content]()) { (dic, v) in
                            if fs.contains(where: { v.element.transformedTimelineFrame?.intersects($0) ?? false }),
                                v.element.model.type.isAudio {
                                
                                dic[v.offset] = v.element.model
                            }
                        }
                    }
                }
                
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
                
                func updatePitsWithSelection(noteI: Int, pitI: Int?, sprolI: Int?, _ type: PitIDType) {
                    var noteAndPitIs: [Int: [Int: Set<Int>]]
                    if let pitI, let sprolI {
                        if document.isSelect(at: p) {
                            noteAndPitIs = sheetView.noteAndPitAndSprolIs(from: document.selections)
                        } else {
                            let id = score.notes[noteI].pits[pitI][type]
                            noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                    if ip.element[type] == id {
                                        v[ip.offset] = sprolI < ip.element.tone.spectlope.count ? [sprolI] : []
                                    }
                                }
                            }
                        }
                    } else if document.isSelect(at: p) {
                        let aNoteAndPitIs = sheetView.noteAndPitIndexes(from: document.selections)
                        noteAndPitIs = [:]
                        for (noteI, v) in aNoteAndPitIs {
                            noteAndPitIs[noteI] = v.reduce(into: [Int: Set<Int>]()) {
                                $0[$1] = []
                            }
                        }
                        if let pitI {
                            if noteAndPitIs[noteI] != nil {
                                if noteAndPitIs[noteI]![pitI] != nil {
                                    noteAndPitIs[noteI]?[pitI] = []
                                }
                            } else {
                                noteAndPitIs[noteI] = [pitI: []]
                            }
                        }
                    } else {
                        if let pitI {
                            let id = score.notes[noteI].pits[pitI][type]
                            noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                    if ip.element[type] == id {
                                        v[ip.offset] = []
                                    }
                                }
                            }
                        } else {
                            let note = score.notes[noteI]
                            if note.pits.count == 1 {
                                let id = note.firstPit[type]
                                noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                    $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                        if ip.element[type] == id {
                                            v[ip.offset] = []
                                        }
                                    }
                                }
                            } else {
                                noteAndPitIs = [noteI: score.notes[noteI].pits.count.range.reduce(into: [Int: Set<Int>]()) { $0[$1] = [] }]
                            }
                        }
                    }
                    
                    beganNotePits = noteAndPitIs.reduce(into: .init()) {
                        for (pitI, sprolIs) in $1.value {
                            let pit = score.notes[$1.key].pits[pitI]
                            let id = pit[type]
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
                
                let sheetP = sheetView.convertFromWorld(p)
                let scoreP = sheetView.scoreView.convertFromWorld(p)
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                
                if let (noteI, result) = scoreView
                    .hitTestColor(scoreP, scale: document.screenToWorldScale) {
                    
                    let note = score.notes[noteI]
                    
                    self.scoreResult = result
                    switch result {
                    case .note:
                        beganVolm = scoreView.volm(atX: scoreP.x, at: noteI)
                        updatePitsWithSelection(noteI: noteI, pitI: nil, sprolI: nil, .stereo)
                        beganBeat = scoreView.beat(atX: scoreP.x)
                    case .sustain:
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
                        beganVolm = score.notes[noteI].envelope.sustainVolm
                        beganBeat = scoreView.beat(atX: scoreP.x)
                    case .pit(let pitI):
                        beganVolm = score.notes[noteI].pits[pitI].stereo.volm
                        updatePitsWithSelection(noteI: noteI, pitI: pitI, sprolI: nil, .stereo)
                        beganBeat = note.pits[pitI].beat + note.beatRange.start
                    case .evenVolm(let pitI):
                        beganVolm = score.notes[noteI].pits[pitI].tone.overtone.evenVolm
                        updatePitsWithSelection(noteI: noteI, pitI: pitI, sprolI: nil, .tone)
                        beganBeat = note.pits[pitI].beat + note.beatRange.start
                    case .oddVolm(let pitI):
                        beganVolm = score.notes[noteI].pits[pitI].tone.overtone.oddVolm
                        updatePitsWithSelection(noteI: noteI, pitI: pitI, sprolI: nil, .tone)
                        beganBeat = note.pits[pitI].beat + note.beatRange.start
                    case .sprol(let pitI, let sprolI):
                        beganVolm = score.notes[noteI].pits[pitI].tone.spectlope.sprols[sprolI].volm
                        updatePitsWithSelection(noteI: noteI, pitI: pitI, sprolI: sprolI, .tone)
                        beganBeat = note.pits[pitI].beat + note.beatRange.start
                    }
                    
                    let noteIsSet = Set(beganNotePits.values.flatMap { $0.dic.keys }).sorted()
                    let vs = score.noteIAndNormarizedPits(atBeat: beganBeat, in: noteIsSet)
                    playerBeatNoteIndexes = vs.map { $0.noteI }
                    
                    updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                } else if let ci = sheetView.contentIndex(at: sheetP, scale: document.screenToWorldScale),
                          sheetView.model.contents[ci].type.isAudio {
                    let content = sheetView.contentsView.elementViews[ci].model
                    beganVolm = content.stereo.volm
                    
                    updateContentsWithSelections()
                    beganContents[ci] = content
                }
                
                let (minV, maxV) = scoreResult != nil && (scoreResult!.isTone || scoreResult!.isEnvelpse)
                ? (0, 1) : (Volm.minVolm, Volm.maxVolm)
                
                updateNode()
                fp = event.screenPoint
                isReversedLightness = true
                let g = lightnessGradientWith(chroma: 0, hue: 0, isReversed: isReversedLightness)
                lightnessNode.lineType = .gradient(g)
                lightnessNode.path = Path([Pathline(lightnessPointsWith(splitCount: Int(maxLightnessHeight)))])
                oldEditingLightness = beganVolm.clipped(min: minV, max: maxV, newMin: 0, newMax: 100)
                editingLightness = oldEditingLightness
                firstLightnessPosition = document.convertScreenToWorld(fp)
                isEditingLightness = true
            }
        case .changed:
            guard let sheetView else { return }
            
            let wp = document.convertScreenToWorld(event.screenPoint)
            let p = lightnessNode.convertFromWorld(wp)
            let t = (p.y / maxLightnessHeight).clipped(min: 0, max: 1)
            let volm = Double.linear(Volm.minVolm, Volm.maxVolm, t: t)
            let volmScale = beganVolm == 0 ? 0 : volm / beganVolm
            func newVolm(from otherVolm: Double) -> Double {
                if beganVolm == otherVolm {
                    volm
                } else {
                    (otherVolm * volmScale).clipped(Volm.volmRange)
                }
            }
            
            let scoreView = sheetView.scoreView
            
            if let scoreResult {
                switch scoreResult {
                case .sustain:
                    let sustainVolm = newVolm(from: beganEnvelope.sustainVolm)
                    var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                    for (noteI, beganNote) in beganNotes {
                        var envelope = beganNote.envelope
                        envelope.sustainVolm = sustainVolm
                        envelope.id = beganEnvelope.id
                        eivs.append(.init(value: envelope, index: noteI))
                    }
                    scoreView.replace(eivs)
                case .note, .pit:
                    var nvs = [Int: Note]()
                    for (_, v) in beganNotePits {
                        for (noteI, nv) in v.dic {
                            if nvs[noteI] == nil {
                                nvs[noteI] = nv.note
                            }
                            nv.pits.forEach { (pitI, beganPit) in
                                nvs[noteI]?.pits[pitI].stereo.volm = newVolm(from: beganPit.pit.stereo.volm)
                                nvs[noteI]?.pits[pitI].stereo.id = v.nid
                            }
                        }
                    }
                    let nivs = nvs.map { IndexValue(value: $0.value, index: $0.key) }
                    scoreView.replace(nivs)
                case .evenVolm:
                    var nvs = [Int: Note]()
                    for (_, v) in beganNotePits {
                        for (noteI, nv) in v.dic {
                            if nvs[noteI] == nil {
                                nvs[noteI] = nv.note
                            }
                            nv.pits.forEach { (pitI, beganPit) in
                                let nVolm = newVolm(from: beganPit.pit.tone.overtone[.evenVolm])
                                nvs[noteI]?.pits[pitI].tone.overtone[.evenVolm] = nVolm
                                nvs[noteI]?.pits[pitI].tone.id = v.nid
                            }
                        }
                    }
                    let nivs = nvs.map { IndexValue(value: $0.value, index: $0.key) }
                    scoreView.replace(nivs)
                case .oddVolm:
                    var nvs = [Int: Note]()
                    for (_, v) in beganNotePits {
                        for (noteI, nv) in v.dic {
                            if nvs[noteI] == nil {
                                nvs[noteI] = nv.note
                            }
                            nv.pits.forEach { (pitI, beganPit) in
                                let nVolm = newVolm(from: beganPit.pit.tone.overtone[.oddVolm])
                                nvs[noteI]?.pits[pitI].tone.overtone[.oddVolm] = nVolm
                                nvs[noteI]?.pits[pitI].tone.id = v.nid
                            }
                        }
                    }
                    let nivs = nvs.map { IndexValue(value: $0.value, index: $0.key) }
                    scoreView.replace(nivs)
                case .sprol:
                    var nvs = [Int: Note]()
                    for (_, v) in beganNotePits {
                        for (noteI, nv) in v.dic {
                            if nvs[noteI] == nil {
                                nvs[noteI] = nv.note
                            }
                            nv.pits.forEach { (pitI, beganPit) in
                                for sprolI in beganPit.sprolIs {
                                    let nVolm = newVolm(from: beganPit.pit.tone.spectlope.sprols[sprolI].volm)
                                    nvs[noteI]?.pits[pitI].tone.spectlope.sprols[sprolI].volm = nVolm
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
                }
                
                switch scoreResult {
                case .sprol:
                    notePlayer?.notes = playerBeatNoteIndexes.map {
                        scoreView.normarizedPitResult(atBeat: beganBeat, at: $0)
                    }
                default:
                    notePlayer?.changeStereo(from: playerBeatNoteIndexes.map {
                        scoreView.normarizedPitResult(atBeat: beganBeat, at: $0)
                    })
                }
            } else if !beganContents.isEmpty {
                for (ci, beganContent) in beganContents {
                    guard ci < sheetView.contentsView.elementViews.count else { continue }
                    let contentView = sheetView.contentsView.elementViews[ci]
                    contentView.stereo = .init(volm: newVolm(from: beganContent.stereo.volm),
                                               pan: contentView.stereo.pan)
                }
            }
            
            editingLightness = volm.clipped(min: Volm.minVolm, max: Volm.maxVolm, newMin: 0, newMax: 100)
        case .ended:
            notePlayer?.stop()
            
            if let sheetView {
                var isNewUndoGroup = false
                func updateUndoGroup() {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
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
                
                if !beganNotes.isEmpty {
                    let scoreView = sheetView.scoreView
                    let score = scoreView.model
                    var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                    for (notei, beganNote) in beganNotes.sorted(by: { $0.key < $1.key }) {
                        guard notei < score.notes.count else { continue }
                        let note = score.notes[notei]
                        if beganNote != note {
                            noteIVs.append(.init(value: note, index: notei))
                            oldNoteIVs.append(.init(value: beganNote, index: notei))
                        }
                    }
                    if !noteIVs.isEmpty {
                        updateUndoGroup()
                        sheetView.capture(noteIVs, old: oldNoteIVs)
                    }
                }
                
                if !beganContents.isEmpty {
                    for (ci, beganContent) in beganContents {
                        guard ci < sheetView.contentsView.elementViews.count else { continue }
                        let content = sheetView.contentsView.elementViews[ci].model
                        if content != beganContent {
                            updateUndoGroup()
                            sheetView.capture(content, old: beganContent, at: ci)
                        }
                    }
                }
            }
            
            isEditingLightness = false
            lightnessNode.removeFromParent()
            document.cursor = document.defaultCursor
        }
    }
    
    
    var isSnappedPan = true {
        didSet {
            guard isSnappedPan != oldValue else { return }
            if isSnappedPan {
                Feedback.performAlignment()
            }
            colorPointNode.fillType = .color(isSnappedPan ? .selected : .content)
        }
    }
    var panWorldPosition: Point {
        beganWorldP - .init(panWidth * beganPan / 2 * document.screenToWorldScale, 0)
    }
    
    var noiseWorldPosition: Point {
        beganWorldP - .init(panWidth * beganNoise * document.screenToWorldScale, 0)
    }
    
    let panWidth = 140.0
    private var beganWorldP = Point()
    private var isChangePan = false
    private var beganPan = 0.0, oldPan = 0.0, panNode = Node()//, panWorldPosition = Point()
    private var beganNoise = 0.0, oldNoise = 0.0
    func changePan(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        let sp = event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isPlaying(with: event) {
                document.stopPlaying(with: event)
            }
            
            beganSP = sp
            let p = document.convertScreenToWorld(sp)
            beganWorldP = p
            if let sheetView = document.sheetView(at: p) {
                self.sheetView = sheetView
                
                func updateContentsWithSelections() {
                    let fs = document.selections
                        .map { $0.rect }
                        .map { sheetView.convertFromWorld($0) }
                    if !fs.isEmpty {
                        beganContents = sheetView.contentsView.elementViews.enumerated().reduce(into: [Int: Content]()) { (dic, v) in
                            if fs.contains(where: { v.element.transformedTimelineFrame?.intersects($0) ?? false }),
                                v.element.model.type.isAudio {
                                
                                dic[v.offset] = v.element.model
                            }
                        }
                    }
                }
                
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
                
                func updatePitsWithSelection(noteI: Int, pitI: Int?, sprolI: Int?, _ type: PitIDType) {
                    var noteAndPitIs: [Int: [Int: Set<Int>]]
                    if let pitI, let sprolI {
                        if document.isSelect(at: p) {
                            noteAndPitIs = sheetView.noteAndPitAndSprolIs(from: document.selections)
                        } else {
                            let id = score.notes[noteI].pits[pitI][type]
                            noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                    if ip.element[type] == id {
                                        v[ip.offset] = sprolI < ip.element.tone.spectlope.count ? [sprolI] : []
                                    }
                                }
                            }
                        }
                    } else if document.isSelect(at: p) {
                        let aNoteAndPitIs = sheetView.noteAndPitIndexes(from: document.selections)
                        noteAndPitIs = [:]
                        for (noteI, v) in aNoteAndPitIs {
                            noteAndPitIs[noteI] = v.reduce(into: [Int: Set<Int>]()) {
                                $0[$1] = []
                            }
                        }
                        if let pitI {
                            if noteAndPitIs[noteI] != nil {
                                if noteAndPitIs[noteI]![pitI] != nil {
                                    noteAndPitIs[noteI]?[pitI] = []
                                }
                            } else {
                                noteAndPitIs[noteI] = [pitI: []]
                            }
                        }
                    } else {
                        if let pitI {
                            let id = score.notes[noteI].pits[pitI][type]
                            noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                    if ip.element[type] == id {
                                        v[ip.offset] = []
                                    }
                                }
                            }
                        } else {
                            let note = score.notes[noteI]
                            if note.pits.count == 1 {
                                let id = note.firstPit[type]
                                noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                    $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                        if ip.element[type] == id {
                                            v[ip.offset] = []
                                        }
                                    }
                                }
                            } else {
                                noteAndPitIs = [noteI: score.notes[noteI].pits.count.range.reduce(into: [Int: Set<Int>]()) { $0[$1] = [] }]
                            }
                        }
                    }
                    
                    beganNotePits = noteAndPitIs.reduce(into: .init()) {
                        for (pitI, sprolIs) in $1.value {
                            let pit = score.notes[$1.key].pits[pitI]
                            let id = pit[type]
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
                
                let sheetP = sheetView.convertFromWorld(p)
                let scoreP = sheetView.scoreView.convertFromWorld(p)
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                
                var beganStereo: Stereo?
                if let (noteI, result) = scoreView
                    .hitTestColor(scoreP, scale: document.screenToWorldScale) {
                    
                    let note = score.notes[noteI]
                    
                    self.scoreResult = result
                    switch result {
                    case .note:
                        beganStereo = scoreView.stereo(atX: scoreP.x, at: noteI)
                        updatePitsWithSelection(noteI: noteI, pitI: nil, sprolI: nil, .stereo)
                        beganBeat = scoreView.beat(atX: scoreP.x)
                    case .sustain: return
                    case .pit(let pitI):
                        beganStereo = note.pits[pitI].stereo
                        updatePitsWithSelection(noteI: noteI, pitI: pitI, sprolI: nil, .stereo)
                        beganBeat = note.pits[pitI].beat + note.beatRange.start
                    case .evenVolm, .oddVolm: return
                    case .sprol(let pitI, let sprolI):
                        let volm = score.notes[noteI].pits[pitI].tone.spectlope.sprols[sprolI].volm
                        beganNoise = score.notes[noteI].pits[pitI].tone.spectlope.sprols[sprolI].noise
                        updatePitsWithSelection(noteI: noteI, pitI: pitI, sprolI: sprolI, .tone)
                        beganBeat = note.pits[pitI].beat + note.beatRange.start
                        
                        let outlineColor: Color = volm < 0.5 ? .content : .background
                        let outlineGradientNode = Node(path: .init([.init(0, 0),
                                                                    .init(panWidth, 0)]),
                                                       lineWidth: 5, lineType: .color(outlineColor))
                        let gradient = noiseGradientWith(volm: volm)
                        let gradientNode = Node(path: .init([.init(noisePointsWith(splitCount: .init(panWidth),
                                                                                   width: panWidth))]),
                                                lineWidth: 3, lineType: .gradient(gradient))
                        colorPointNode.attitude.position = .init(panWidth * beganNoise, 0)
                        panNode.append(child: outlineGradientNode)
                        panNode.append(child: gradientNode)
                        panNode.append(child: colorPointNode)
                        let attitude = Attitude(document.screenToWorldTransform)
                        panNode.attitude = attitude.with(position: noiseWorldPosition)
                        
                        document.rootNode.append(child: panNode)
                    }
                    
                    let noteIsSet = Set(beganNotePits.values.flatMap { $0.dic.keys }).sorted()
                    let vs = score.noteIAndNormarizedPits(atBeat: beganBeat, in: noteIsSet)
                    playerBeatNoteIndexes = vs.map { $0.noteI }
                    updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                } else if let ci = sheetView.contentIndex(at: sheetP, scale: document.screenToWorldScale),
                          sheetView.model.contents[ci].type.isAudio {
                    let content = sheetView.contentsView.elementViews[ci].model
                    beganStereo = content.stereo
                    
                    updateContentsWithSelections()
                    beganContents[ci] = content
                }
                
                if let beganStereo {
                    beganPan = beganStereo.pan
                    
                    let outlineColor: Color = beganStereo.volm < 0.5 ? .content : .background
                    let outlineGradientNode = Node(path: .init([.init(-panWidth / 2, 0),
                                                                .init(panWidth / 2, 0)]),
                                                   lineWidth: 5, lineType: .color(outlineColor))
                    let gradient = panGradientWith(volm: beganStereo.volm)
                    let gradientNode = Node(path: .init([.init(panPointsWith(splitCount: .init(panWidth),
                                                                             width: panWidth))]),
                                            lineWidth: 3, lineType: .gradient(gradient))
                    let whiteLineNode = Node(path: .init(Edge(.init(0, -1), .init(0, 1))),
                                             lineWidth: 1, lineType: .color(outlineColor))
                    colorPointNode.attitude.position = .init(panWidth * beganPan / 2, 0)
                    panNode.append(child: outlineGradientNode)
                    panNode.append(child: gradientNode)
                    panNode.append(child: whiteLineNode)
                    panNode.append(child: colorPointNode)
                    let attitude = Attitude(document.screenToWorldTransform)
                    panNode.attitude = attitude.with(position: panWorldPosition)
                    
                    document.rootNode.append(child: panNode)
                }
            }
        case .changed:
            guard let sheetView else { return }
            
            if case .sprol = scoreResult {
                let noise = (beganNoise + (sp.x - document.convertWorldToScreen(beganWorldP).x) / panWidth).clipped(min: 0, max: 1)
                let noiseScale = beganNoise == 0 ? 0 : noise / beganNoise
                func newNoise(from otherNoise: Double) -> Double {
                    if beganNoise == otherNoise {
                        noise
                    } else {
                        (otherNoise * noiseScale).clipped(min: 0, max: 1)
                    }
                }
                
                let scoreView = sheetView.scoreView
                
                var nvs = [Int: Note]()
                for (_, v) in beganNotePits {
                    for (noteI, nv) in v.dic {
                        if nvs[noteI] == nil {
                            nvs[noteI] = nv.note
                        }
                        nv.pits.forEach { (pitI, beganPit) in
                            for sprolI in beganPit.sprolIs {
                                let nNoise = newNoise(from: beganPit.pit.tone.spectlope.sprols[sprolI].noise)
                                nvs[noteI]?.pits[pitI].tone.spectlope.sprols[sprolI].noise = nNoise
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
                
                colorPointNode.attitude.position = .init(panWidth * noise, 0)
                
                notePlayer?.notes = playerBeatNoteIndexes.map {
                    scoreView.normarizedPitResult(atBeat: beganBeat, at: $0)
                }
            } else {
                let oPan = beganPan + (sp.x - document.convertWorldToScreen(beganWorldP).x) / (panWidth / 2)
                let pan: Double
                if oldPan < 0 && oPan > 0 {
                    isSnappedPan = oPan <= 0.05
                    pan = (oPan > 0.05 ? oPan - 0.05 : 0).clipped(min: -1, max: 1)
                } else if oldPan > 0 && oPan < 0 {
                    isSnappedPan = oPan >= -0.05
                    pan = (oPan < -0.05 ? oPan + 0.05 : 0).clipped(min: -1, max: 1)
                } else {
                    isSnappedPan = false
                    pan = oPan.clipped(min: -1, max: 1)
                    oldPan = pan
                }
                let ndPan = pan - beganPan
                
                func newPan(from otherPan: Double) -> Double {
                    if beganPan == otherPan {
                        pan
                    } else {
                        (otherPan + ndPan).clipped(min: -1, max: 1)
                    }
                }
                
                if !beganNotePits.isEmpty {
                    let scoreView = sheetView.scoreView
                    
                    var nvs = [Int: Note]()
                    for (_, v) in beganNotePits {
                        for (noteI, nv) in v.dic {
                            if nvs[noteI] == nil {
                                nvs[noteI] = nv.note
                            }
                            nv.pits.forEach { (pitI, beganPit) in
                                let nPan = newPan(from: beganPit.pit.stereo.pan)
                                nvs[noteI]?.pits[pitI].stereo.pan = nPan
                                nvs[noteI]?.pits[pitI].stereo.id = v.nid
                            }
                        }
                    }
                    let nivs = nvs.map { IndexValue(value: $0.value, index: $0.key) }
                    scoreView.replace(nivs)
                    
                    notePlayer?.changeStereo(from: playerBeatNoteIndexes.map {
                        scoreView.normarizedPitResult(atBeat: beganBeat, at: $0)
                    })
                } else if !beganContents.isEmpty {
                    for (ci, beganContent) in beganContents {
                        guard ci < sheetView.contentsView.elementViews.count else { continue }
                        let contentView = sheetView.contentsView.elementViews[ci]
                        contentView.stereo = .init(volm: contentView.stereo.volm,
                                                   pan: newPan(from: beganContent.stereo.pan))
                    }
                }
                
                colorPointNode.attitude.position = .init(panWidth * pan / 2, 0)
            }
        case .ended:
            notePlayer?.stop()
            
            if let sheetView {
                var isNewUndoGroup = false
                func updateUndoGroup() {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
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
                
                if !beganContents.isEmpty {
                    for (ci, beganContent) in beganContents {
                        guard ci < sheetView.contentsView.elementViews.count else { continue }
                        let content = sheetView.contentsView.elementViews[ci].model
                        if content != beganContent {
                            updateUndoGroup()
                            sheetView.capture(content, old: beganContent, at: ci)
                        }
                    }
                }
            }
            
            colorPointNode.removeFromParent()
            panNode.removeFromParent()
            document.cursor = document.defaultCursor
        }
    }
    
    func changeLightness(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
        }
        
        if isChangeVolm {
            changeVolm(with: event)
            return
        }
        if event.phase == .began {
            let p = document.convertScreenToWorld(event.screenPoint)
            if let sheetView = document.sheetView(at: p) {
                if sheetView.model.score.enabled {
                    isChangeVolm = true
                    changeVolm(with: event)
                    return
                } else if let ci = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                          scale: document.screenToWorldScale),
                   sheetView.model.contents[ci].type.isAudio {
                    isChangeVolm = true
                    changeVolm(with: event)
                    return
                }
            }
        }
        
        func updateLightness() {
            let wp = document.convertScreenToWorld(event.screenPoint)
            let p = lightnessNode.convertFromWorld(wp)
            if isEditableMaxLightness {
                let r = abs(p.y - whiteLightnessHeight)
                if r < snappableDistance {
                    if let lastTintSnapTime = lastTintSnapTime {
                        if event.time - lastTintSnapTime > 1 {
                            isSnappedLightness = false
                        }
                    } else {
                        if !isSnappedLightness {
                            lastTintSnapTime = event.time
                        }
                        isSnappedLightness = true
                    }
                } else {
                    lastTintSnapTime = nil
                    isSnappedLightness = false
                }
            } else {
                isSnappedLightness = false
            }
            let t = (p.y / maxLightnessHeight).clipped(min: 0, max: 1)
            let lightness = isSnappedLightness ? Color.whiteLightness :
                Double.linear(Color.minLightness,
                              maxLightness,
                              t: t)
            
            var uuColor = firstUUColor
            uuColor.value.rgbColorSpace = document.colorSpace
            uuColor.value.lightness = lightness
            if isEditableOpacity {
                uuColor.value.opacity = opacity(atX: p.x)
            }
            editingUUColor = uuColor
            colorOwners.forEach { $0.uuColor = uuColor }
            
            editingLightness = lightness
        }
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            updateNode()
            updateOwners(with: event)
            fp = event.screenPoint
            let g = lightnessGradientWith(chroma: firstUUColor.value.chroma,
                                          hue: firstUUColor.value.hue)
            lightnessNode.lineType = .gradient(g)
            lightnessNode.path = Path([Pathline(lightnessPointsWith(splitCount: Int(maxLightnessHeight)))])
            opacityNode.lineType = .gradient(opacityGradientWith(color: firstUUColor.value))
            opacityNode.path = Path([Pathline(opacityPointsWith())])
            oldEditingLightness = firstUUColor.value.lightness
            editingLightness = oldEditingLightness
            firstLightnessPosition = document.convertScreenToWorld(fp)
            editingUUColor = firstUUColor
            isEditingLightness = true
        case .changed:
            updateLightness()
        case .ended:
            capture()
            colorOwners = []
            isEditingLightness = false
            lightnessNode.removeFromParent()
            tintBorderNode.removeFromParent()
            tintNode.removeFromParent()
            
            document.cursor = document.defaultCursor
        }
    }
    
    let snappableDistance = 2.0
    let tintNode = Node(lineWidth: 2)
    let tintBorderNode = Node(lineWidth: 3.25, lineType: .color(.background))
    let tintLineNode = Node(lineWidth: 1, lineType: .color(.content))
    let tintOutlineNode = Node(lineWidth: 2.5, lineType: .color(.background))
    var tintLightness = 0.0
    var isEditingTint = false {
        didSet {
            guard isEditingTint != oldValue else { return }
            if isEditingTint {
                updateTintNode()
                tintBorderNode.lineType = .color(tintLightness > 50 ? .content : .background)
                document.rootNode.append(child: tintBorderNode)
                document.rootNode.append(child: tintNode)
                if isDrawPoints {
                    pointNodes.forEach {
                        tintNode.append(child: $0)
                    }
                }
                tintNode.append(child: tintOutlineNode)
                tintNode.append(child: tintLineNode)
                tintNode.append(child: colorPointNode)
            } else {
                if isDrawPoints {
                    pointNodes.forEach {
                        $0.removeFromParent()
                    }
                }
                colorPointNode.removeFromParent()
                tintNode.removeFromParent()
                tintLineNode.removeFromParent()
                tintOutlineNode.removeFromParent()
            }
        }
    }
    func updateTintNode(radius r: Double = 128, splitCount: Int = 360) {
        let rsc = 1 / Double(splitCount)
        var points = [Point](), colors = [Color]()
        for i in 0 ..< splitCount {
            let hue = Double(i) * rsc * .pi2
            let color = Color(lightness: tintLightness,
                              unsafetyChroma: r, hue: hue,
                              document.colorSpace)
            let p = color.tint.rectangular
            colors.append(color)
            points.append(p)
        }
        let path = Path([Pathline(points, isClosed: true)])
        
        tintNode.path = path
        tintNode.lineType = .gradient(colors)
        tintBorderNode.path = path
        tintBorderNode.lineType = .gradient(colors)
    }
    var beganTintPosition = Point() {
        didSet {
            tintBorderNode.attitude.position = tintWorldPosition
            tintNode.attitude.position = tintWorldPosition
        }
    }
    var tintWorldPosition: Point {
        let sfp = document.convertWorldToScreen(beganTintPosition)
        return document.convertScreenToWorld(sfp - oldEditingTintPosition)
    }
    var isSnappedTint = true {
        didSet {
            guard isSnappedTint != oldValue else { return }
            if isSnappedTint {
                Feedback.performAlignment()
            }
            colorPointNode.fillType = .color(isSnappedTint ? .selected : .content)
        }
    }
    var oldEditingTintPosition = Point()
    var editingTintPosition = Point() {
        didSet {
            colorPointNode.attitude.position = editingTintPosition
            updateTintLinePath()
        }
    }
    func updateTintLinePath() {
        let path = Path([Pathline([Point(), editingTintPosition])])
        tintLineNode.path = path
        tintOutlineNode.path = path
    }
    var lastTintSnapTime: Double?
    func changeTint(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
        }
        
        if isChangePan {
            changePan(with: event)
            return
        }
        if event.phase == .began {
            let p = document.convertScreenToWorld(event.screenPoint)
            if let sheetView = document.sheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                if sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p),
                                                 scale: document.screenToWorldScale) != nil {
                    isChangePan = true
                    changePan(with: event)
                    return
                } else if let ci = sheetView.contentIndex(at: sheetP, scale: document.screenToWorldScale),
                          sheetView.model.contents[ci].type.isAudio {
                    isChangePan = true
                    changePan(with: event)
                    return
                }
            }
        }
        
        func updateTint() {
            let wp = document.convertScreenToWorld(event.screenPoint)
            let p = tintNode.convertFromWorld(wp)
            let fTintP = Point()
            let r = fTintP.distance(p)
            let theta = fTintP.angle(p)
            var uuColor = firstUUColor
            if r < snappableDistance {
                if let lastTintSnapTime = lastTintSnapTime {
                    if event.time - lastTintSnapTime > 1 {
                        isSnappedTint = false
                    }
                } else {
                    if !isSnappedTint {
                        lastTintSnapTime = event.time
                    }
                    isSnappedTint = true
                }
            } else {
                lastTintSnapTime = nil
                isSnappedTint = false
            }
            uuColor.value.rgbColorSpace = document.colorSpace
            uuColor.value.chroma = isSnappedTint ? 0 : r
            uuColor.value.hue = theta
            let polarPoint = Point(uuColor.value.a, uuColor.value.b).polar
            uuColor.value.hue = polarPoint.theta
            uuColor.value.chroma = min(polarPoint.r, Color.maxChroma)
            editingUUColor = uuColor
            colorOwners.forEach { $0.uuColor = uuColor }
            
            editingTintPosition = PolarPoint(uuColor.value.chroma,
                                           uuColor.value.hue).rectangular
        }
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            updateNode()
            updateOwners(with: event)
            if isDrawPoints {
                updateTintPointNodes(with: event)
            }
            fp = event.screenPoint
            tintLightness = firstUUColor.value.lightness
            oldEditingTintPosition = PolarPoint(firstUUColor.value.chroma,
                                              firstUUColor.value.hue).rectangular
            editingTintPosition = oldEditingTintPosition
            beganTintPosition = document.convertScreenToWorld(fp)
            editingUUColor = firstUUColor
            isEditingTint = true
        case .changed:
            updateTint()
        case .ended:
            capture()
            colorOwners = []
            isEditingTint = false
            lightnessNode.removeFromParent()
            tintNode.removeFromParent()
            tintBorderNode.removeFromParent()
            
            document.cursor = document.defaultCursor
        }
    }
}
