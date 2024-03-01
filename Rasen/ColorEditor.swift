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
                                       splitCount count: Int = 140) -> [Color] {
        let rCount = 1 / Double(count)
        return (0 ... count).map {
            let t = Double.linear(Color.minLightness,
                                  maxLightness,
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
                                                     splitCount: Int(maxLightnessHeight))
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
    
    func volumeNodes(from volume: Volume, firstVolume: Volume, at p: Point) -> [Node] {
        let vh = 50.0
        let defaultVH = vh * (1 / Volume.maxSmp)
        let vKnobW = 8.0, vKbobH = 2.0
        let vx = 0.0, vy = 0.0
        let y = volume.smp.clipped(min: Volume.minSmp, max: Volume.maxSmp,
                                   newMin: 0, newMax: vh)
        let fy = firstVolume.smp.clipped(min: Volume.minSmp, max: Volume.maxSmp,
                                         newMin: 0, newMax: vh)
        let path = Path([Pathline(Polygon(points: [Point(vx, vy),
                                                   Point(vx + 1.5, vy + vh),
                                                   Point(vx - 1.5, vy + vh)])),
                         Pathline(Rect(x: vx - vKnobW / 2,
                                       y: vy + y - vKbobH / 2,
                                       width: vKnobW,
                                       height: vKbobH)),
                         Pathline(Rect(x: vx - 3,
                                       y: vy + defaultVH - 1 / 2,
                                       width: 6,
                                       height: 1))])
        return [Node(attitude: .init(position: p - Point(0, fy)), path: path,
                     fillType: .color(.content))]
    }
    
    func panNodes(fromPan pan: Double, firstPan: Double, at p: Point) -> [Node] {
        let panW = 50.0
        
        var contentPathlines = [Pathline]()
        
        let vw = 0.0, vy = 0.0
        let fx = firstPan.clipped(min: -1, max: 1, newMin: 0, newMax: panW)
        
        let knobW = 2.0, knobH = 12.0
        let vKnobW = knobW, vKbobH = knobH, plh = 3.0, plw = 1.0
        contentPathlines.append(Pathline(Rect(x: vw + panW / 2 + pan * panW / 2 - vKnobW / 2,
                                              y: vy - vKbobH / 2,
                                              width: vKnobW,
                                              height: vKbobH)))
        
        contentPathlines.append(Pathline(Rect(x: vw + panW / 2 - plw / 2,
                                              y: vy - plh / 2,
                                              width: plw,
                                              height: plh)))
        
        contentPathlines.append(Pathline(Polygon(points: [
            Point(vw, vy - plh / 2),
            Point(vw + panW / 2, vy),
            Point(vw, vy + plh / 2)
        ])))
        contentPathlines.append(Pathline(Polygon(points: [
            Point(vw + panW, vy + plh / 2),
            Point(vw + panW / 2, vy),
            Point(vw + panW, vy - plh / 2)
        ])))
        
        if pan == 0 {
            contentPathlines.append(Pathline(Rect(x: vw + panW / 2 - vKnobW / 2,
                                                  y: vy - vKbobH / 2 - plw * 2,
                                                  width: vKnobW,
                                                  height: plw)))
            contentPathlines.append(Pathline(Rect(x: vw + panW / 2 - vKnobW / 2,
                                                  y: vy + vKbobH / 2 + plw,
                                                  width: vKnobW,
                                                  height: plw)))
        }
        return [Node(attitude: .init(position: p - Point(fx, 0)), path: Path(contentPathlines),
                     fillType: .color(.content))]
    }
    
    private var isChangeVolumeAmp = false, isChangePit = false
    private var sheetView: SheetView?
    private var beganNotes = [Int: Note]()
    private var beganNotePits = [Int: (note: Note, pits: [Int: Pit])]()
    private var beganContents = [Int: Content]()
    private var beganSP = Point(), beganVolume = Volume()
    private var notePlayer: NotePlayer?
    func changeVolumeAmp(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        let sp = event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            beganSP = sp
            let p = document.convertScreenToWorld(sp)
            if let sheetView = document.sheetView(at: p) {
                self.sheetView = sheetView
                
                func updateWithSelections() {
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
                func updateNotePlayer(atNote ni: Int, with score: Score) {
                    let note = score.notes[ni]
                    let volume = sheetView.isPlaying ? note.volume * 0.1 : note.volume
                    if let notePlayer = sheetView.notePlayer {
                        self.notePlayer = notePlayer
                        notePlayer.notes = [note]
                        notePlayer.volume = volume
                    } else {
                        notePlayer = try? NotePlayer(notes: [note],
                                                     volume: volume, pan: note.pan)
                        sheetView.notePlayer = notePlayer
                    }
                    notePlayer?.play()
                }
                
                let sheetP = sheetView.convertFromWorld(p)
                if let ni = sheetView.scoreView.noteIndex(at: sheetP,
                                                          maxDistance: 15 * document.screenToWorldScale) {
                    let scoreView = sheetView.scoreView
                    let score = scoreView.model
                    
                    let scoreP = scoreView.convertFromWorld(p)
                    let maxD = 5 * document.screenToWorldScale
                    if scoreView.isFullEdit,
                       let (ni, pitI, pit, _) = scoreView.pitbendTuple(at: scoreP, maxDistance: maxD) {
                        isChangePit = true
                        beganVolume = Volume(amp: pit.amp)
                        
                        if document.isSelect(at: p) {
//                            let noteIs = document.selectedNoteIndexes(from: scoreView)
//                            beganNotes = noteIs.reduce(into: .init()) { $0[$1] = score.notes[$1] }
                        }
                        beganNotePits[ni] = (score.notes[ni], [pitI: pit])
                        
                        updateNotePlayer(atNote: ni, with: score)//
                    } else {
                        isChangePit = false
                        beganVolume = score.notes[ni].volume
                        
                        if document.isSelect(at: p) {
                            let noteIs = document.selectedNoteIndexes(from: scoreView)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        }
                        beganNotes[ni] = score.notes[ni]
                        
                        updateNotePlayer(atNote: ni, with: score)
                    }
                } else if let ci = sheetView.contentIndex(at: sheetP, scale: document.screenToWorldScale),
                          sheetView.model.contents[ci].type.isAudio {
                    let content = sheetView.contentsView.elementViews[ci].model
                    beganVolume = content.volume
                    
                    updateWithSelections()
                    beganContents[ci] = content
                }
                
                lightnessNode.children = volumeNodes(from: beganVolume, firstVolume: beganVolume, at: p)
                document.rootNode.append(child: lightnessNode)
            }
        case .changed:
            guard let sheetView else { return }
            
            let dSmp = (sp.y - beganSP.y) * (document.screenToWorldScale / 50)
            let smp = (beganVolume.smp + dSmp).clipped(min: 0, max: Volume.maxSmp)
            let volume = Volume(smp: smp)
            let scale = beganVolume.amp == 0 ? 1 : volume.amp / beganVolume.amp
            
            func newVolume(from otherVolume: Volume) -> Volume {
                if beganVolume == otherVolume {
                    volume
                } else if beganVolume.amp == 0 {
                    .init(smp: (otherVolume.smp + dSmp).clipped(min: 0, max: Volume.maxSmp))
                } else {
                    .init(amp: (otherVolume.amp * scale).clipped(min: 0, max: Volume.maxAmp))
                }
            }
            
            let scoreView = sheetView.scoreView
            let score = scoreView.model
            if isChangePit {
                for (ni, beganNotePit) in beganNotePits {
                    guard ni < score.notes.count else { continue }
                    for (pi, beganPit) in beganNotePit.pits {
                        guard pi < score.notes[ni].pitbend.pits.count else { continue }
                        let nVolume = newVolume(from: beganPit.volume)
                        scoreView.model.notes[ni].pitbend.pits[pi].volume = nVolume
                        
                        if beganPit.volume == beganVolume {
                            notePlayer?.notes = [scoreView.model.notes[ni]]//
                            
                            sheetView.sequencer?.scoreNoders[score.id]?
                                .replaceVolumeOrPan([.init(value: scoreView.model.notes[ni], index: ni)],
                                                    with: scoreView.model)
                        }
                    }
                }
            } else {
                for (ni, beganNote) in beganNotes {
                    guard ni < score.notes.count else { continue }
                    let nVolume = newVolume(from: beganNote.volume)
                    scoreView.model.notes[ni].volume = nVolume
                    
                    if beganNote.volume == beganVolume {
                        notePlayer?.notes = [scoreView.model.notes[ni]]//
                        
                        sheetView.sequencer?.scoreNoders[score.id]?
                            .replaceVolumeOrPan([.init(value: scoreView.model.notes[ni], index: ni)],
                                                with: scoreView.model)
                    }
                }
            }
            
            if !beganContents.isEmpty {
                for (ci, beganContent) in beganContents {
                    guard ci < sheetView.contentsView.elementViews.count else { continue }
                    let contentView = sheetView.contentsView.elementViews[ci]
                    let nVolume = newVolume(from: beganContent.volume)
                    contentView.model.volume = nVolume
                    sheetView.sequencer?.mixings[beganContent.id]?.volume = .init(nVolume.amp)
                }
            }
            
            lightnessNode.children = volumeNodes(from: volume,
                                                 firstVolume: beganVolume,
                                                 at: document.convertScreenToWorld(beganSP))
        case .ended:
            notePlayer?.stop()
            
            lightnessNode.removeFromParent()
            
            if let sheetView {
                var isNewUndoGroup = false
                func updateUndoGroup() {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
                }
                
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                if isChangePit {
                    var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                    for (ni, beganNotePit) in beganNotePits {
                        guard ni < score.notes.count else { continue }
                        let note = scoreView.model.notes[ni]
                        if beganNotePit.note != note {
                            noteIVs.append(.init(value: note, index: ni))
                            oldNoteIVs.append(.init(value: beganNotePit.note, index: ni))
                        }
                    }
                    if !noteIVs.isEmpty {
                        updateUndoGroup()
                        sheetView.capture(noteIVs, old: oldNoteIVs)
                    }
                } else {
                    var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                    for (ni, beganNote) in beganNotes {
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
            
            document.cursor = Document.defaultCursor
        }
    }
    
    private var isChangePan = false
    private var beganPan = 0.0, oldPan = 0.0
    func changePan(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        let sp = event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            beganSP = sp
            let p = document.convertScreenToWorld(sp)
            if let sheetView = document.sheetView(at: p) {
                self.sheetView = sheetView
                
                //
                
                func updateWithSelections() {
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
                
                let sheetP = sheetView.convertFromWorld(p)
                if let ci = sheetView.contentIndex(at: sheetP, scale: document.screenToWorldScale),
                          sheetView.model.contents[ci].type.isAudio {
                    let content = sheetView.contentsView.elementViews[ci].model
                    beganPan = content.pan
                    
                    updateWithSelections()
                    beganContents[ci] = content
                }
                
                lightnessNode.children = panNodes(fromPan: beganPan, firstPan: beganPan, at: p)
                document.rootNode.append(child: lightnessNode)
            }
        case .changed:
            guard let sheetView else { return }
            
            let dPan = (sp.x - beganSP.x) * (document.screenToWorldScale / 50)
            let oPan = (beganPan + dPan).clipped(min: -1, max: 1)
            let pan: Double
            if oldPan < 0 && oPan > 0 {
                pan = oPan > 0.05 ? oPan - 0.05 : 0
            } else if oldPan > 0 && oPan < 0 {
                pan = oPan < -0.05 ? oPan + 0.05 : 0
            } else {
                pan = oPan
                oldPan = pan
            }
            let ndPan = pan - beganPan
            
            func newPan(from otherPan: Double) -> Double {
                if beganPan == otherPan {
                    pan
                } else {
                    (beganPan + ndPan).clipped(min: -1, max: 1)
                }
            }
            
            //
            
            if !beganContents.isEmpty {
                for (ci, beganContent) in beganContents {
                    guard ci < sheetView.contentsView.elementViews.count else { continue }
                    let contentView = sheetView.contentsView.elementViews[ci]
                    let nPan = newPan(from: beganContent.pan)
                    contentView.model.pan = nPan
                    sheetView.sequencer?.mixings[beganContent.id]?.pan = Float(nPan)
                }
            }
            
            lightnessNode.children = panNodes(fromPan: pan,
                                              firstPan: beganPan,
                                              at: document.convertScreenToWorld(beganSP))
        case .ended:
            notePlayer?.stop()
            
            lightnessNode.removeFromParent()
            
            if let sheetView {
                var isNewUndoGroup = false
                func updateUndoGroup() {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
                }
                
                //
                
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
            
            document.cursor = Document.defaultCursor
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
        
        if isChangeVolumeAmp {
            changeVolumeAmp(with: event)
            return
        }
        if event.phase == .began {
            let p = document.convertScreenToWorld(event.screenPoint)
            if let sheetView = document.sheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                if sheetView.scoreView.noteIndex(at: sheetP,
                                                 maxDistance: 15 * document.screenToWorldScale) != nil {
                    isChangeVolumeAmp = true
                    changeVolumeAmp(with: event)
                    return
                } else if let ci = sheetView.contentIndex(at: sheetP, scale: document.screenToWorldScale),
                          sheetView.model.contents[ci].type.isAudio {
                    isChangeVolumeAmp = true
                    changeVolumeAmp(with: event)
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
            
            document.cursor = Document.defaultCursor
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
            let hue = Double(i) * rsc * 2 * .pi
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
                if sheetView.scoreView.noteIndex(at: sheetP,
                                                 maxDistance: 15 * document.screenToWorldScale) != nil {
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
            
            document.cursor = Document.defaultCursor
        }
    }
}
