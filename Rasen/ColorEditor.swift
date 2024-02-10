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
    
    private var beganPan = 0.0, oldPan = 0.0
    var isChangePan = false, isFirstChangedVolumeAmp = false
    func changePan(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        let sp = event.screenPoint
        let p = document.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            beganSP = event.screenPoint
            
            if let sheetView = document.sheetView(at: p) {
                let inP = sheetView.convertFromWorld(p)
                if let (ti, _) = sheetView.timeframeTuple(at: inP) {
                    let textView = sheetView.textsView.elementViews[ti]
                    if let pan = textView.model.timeframe?.pan {
                        
                        beganPan = pan
                        oldPan = pan
                        
                        self.textI = ti
                        
                        let fs = document.selections
                            .map { $0.rect }
                            .map { sheetView.convertFromWorld($0) }
                        beganTimeframes = sheetView.textsView.elementViews.enumerated().reduce(into: [Int: Timeframe]()) { (dic, v) in
                            if fs.contains(where: { v.element.transformedScoreFrame.intersects($0) }),
                               let timeframe = v.element.model.timeframe,
                               timeframe.pan != nil {
                                dic[v.offset] = timeframe
                            }
                        }
                        
                        lightnessNode.children = panNodes(fromPan: beganPan, firstPan: beganPan, at: p)
                        document.rootNode.append(child: lightnessNode)
                    }
                }
            }
        case .changed:
            if let sheetView = noteSheetView,
               let textI, textI < sheetView.textsView.elementViews.count {
                
                let textView = sheetView.textsView.elementViews[textI]
                
                let dPan = (sp.x - beganSP.x)
                    * (document.screenToWorldScale / 50 / textView.nodeRatio)
                let oPan = (beganPan + dPan)
                    .clipped(min: -1, max: 1)
                let pan: Double
                if oldPan < 0 && oPan > 0 {
                    pan = oPan > 0.05 ? oPan - 0.05 : 0
                } else if oldPan > 0 && oPan < 0 {
                    pan = oPan < -0.05 ? oPan + 0.05 : 0
                } else {
                    pan = oPan
                    oldPan = pan
                }
                
                if !beganTimeframes.isEmpty {
                    for (ti, textView) in sheetView.textsView.elementViews.enumerated() {
                        guard let beganTimeframePan = beganTimeframes[ti]?.pan else { continue }
                        
                        let pan = (beganTimeframePan + dPan)
                                .clipped(min: -1, max: 1)
                        
                        textView.model.timeframe?.pan = pan
                        
                        if textView.model.timeframe?.content == nil {
                            textView.isUpdatedAudioCache = false
                        }
                        
                        if let timeframe = textView.model.timeframe {
                            sheetView.sequencer?.mixings[timeframe.id]?
                                .pan = Float(pan)
                        }
                    }
                } else {
                    textView.model.timeframe?.pan = pan
                    
                    if textView.model.timeframe?.content == nil {
                        textView.isUpdatedAudioCache = false
                    }
                    
                    if let timeframe = textView.model.timeframe {
                        sheetView.sequencer?.mixings[timeframe.id]?
                            .pan = Float(pan)
                    }
                }
                
                lightnessNode.children = panNodes(fromPan: pan,
                                                  firstPan: beganPan,
                                                  at: document.convertScreenToWorld(beganSP))
            }
        case .ended:
            notePlayer?.stop()
            
            lightnessNode.removeFromParent()
            
            if let sheetView = noteSheetView {
                var isNewUndoGroup = false
                func updateUndoGroup() {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
                }
                if !beganTimeframes.isEmpty {
                    for (ti, beganTimeframe) in beganTimeframes {
                        guard ti < sheetView.model.texts.count else { continue }
                        if let beganScore = beganTimeframe.score {
                           let score = sheetView.textsView.elementViews[ti].model.timeframe?.score
                           if score != beganScore {
                               updateUndoGroup()
                               sheetView.captureScore(score, old: beganScore, at: ti)
                           }
                        } else {
                            let text = sheetView.textsView.elementViews[ti].model
                            if text.timeframe != beganTimeframe {
                                var beganText = text
                                beganText.timeframe = beganTimeframe
                                updateUndoGroup()
                                sheetView.captureText(text, old: beganText, at: ti)
                            }
                        }
                    }
                } else if let ti = textI,
                            ti < sheetView.model.texts.count,
                            let beganScore = beganScore {
                    let score = sheetView.textsView.elementViews[ti].model.timeframe?.score
                    if score != beganScore {
                        updateUndoGroup()
                        sheetView.captureScore(score, old: beganScore, at: ti)
                    }
                }
            }
            
            document.cursor = Document.defaultCursor
        }
    }
    
    var notePlayer: NotePlayer?
    var isChangeVolumeAmp = false
    var noteSheetView: SheetView?, noteTextIndex: Int?, noteIndexes = [Int]()
    var isPit = false
    var textI: Int?, noteI: Int?, pitI: Int?,
        beganScore: Score?, beganContent: Content?, beganPit: Pit?, beganPitbend: Pitbend?
    var beganTimeframes = [Int: Timeframe]()
    var beganVolumes = [Volume](), beganSP = Point(), firstScore: Score?
    var firstNoteIndex = 0, beganVolume = Volume(), isChangeScoreVolume = false
    func changeVolumeAmp(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        if isChangePan {
            changePan(with: event)
            return
        }
        
        let sp = event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            beganSP = event.screenPoint
            let p = document.convertScreenToWorld(event.screenPoint)
            if let sheetView = noteSheetView, let ti = noteTextIndex {
                let textView = sheetView.textsView.elementViews[ti]
                if let timeframe = textView.model.timeframe,
                   let score = timeframe.score {
                    
                    firstScore = score
                    
                    let inP = sheetView.convertFromWorld(p)
                    isPit = false
                    if let (ti, _) = sheetView.timeframeTuple(at: inP) {
                        let textView = sheetView.textsView.elementViews[ti]
                    
                        let inTP = textView.convert(inP, from: sheetView.node)
                        let maxD = textView.nodeRatio
                        * 5.0 * document.screenToWorldScale
                        if textView.containsScore(inTP),
                           let (ni, pitI, pit, pitbend) = textView.pitbendTuple(at: inTP,
                                                                  maxDistance: maxD) {
                            
                            self.textI = ti
                            self.noteI = ni
                            self.pitI = pitI
                            beganScore = textView.model.timeframe?.score
                            beganPit = pit
                            beganPitbend = pitbend
                            isPit = true
                        }
                    }
                    
                    if !isPit {
                        if isChangeScoreVolume {
                            beganVolume = score.volume
                            let fs = document.selections
                                .map { $0.rect }
                                .map { sheetView.convertFromWorld($0) }
                            beganTimeframes = sheetView.textsView.elementViews.enumerated().reduce(into: [Int: Timeframe]()) { (dic, v) in
                                if fs.contains(where: { v.element.transformedScoreFrame.intersects($0) }),
                                   let timeframe = v.element.model.timeframe,
                                   timeframe.volume != nil {
                                    dic[v.offset] = timeframe
                                }
                            }
                        } else {
                            beganVolume = score.notes[firstNoteIndex].volume
                            if document.isSelect(at: p) {
                                noteIndexes = document.selectedNoteIndexes(from: textView)
                                beganVolumes = noteIndexes.map { score.notes[$0].volume }
                            } else {
                                noteIndexes = [firstNoteIndex]
                                beganVolumes = [beganVolume]
                            }
                            
                            let note = score.notes[firstNoteIndex]
                            let volume = sheetView.isPlaying ?
                            score.volume * 0.1 : score.volume
                            if let notePlayer = sheetView.notePlayer {
                                self.notePlayer = notePlayer
                                notePlayer.notes = [score.convertPitchToWorld(note)]
                                notePlayer.tone = score.tone
                                notePlayer.volume = volume
                            } else {
                                notePlayer = try? NotePlayer(notes: [score.convertPitchToWorld(note)],
                                                             score.tone,
                                                             volume: volume,
                                                             pan: score.pan,
                                                             tempo: Double(timeframe.tempo))
                                sheetView.notePlayer = notePlayer
                            }
                            notePlayer?.play()
                        }
                    }
                } else if let timeframe = textView.model.timeframe,
                    let content = timeframe.content {
                    
                    let inP = sheetView.convertFromWorld(p)
                    if let (ti, _) = sheetView.timeframeTuple(at: inP) {
                        let textView = sheetView.textsView.elementViews[ti]
                    
                        let inTP = textView.convert(inP, from: sheetView.node)
                        if textView.containsTimeframe(inTP) {
                            self.textI = ti
                            
                            beganVolume = content.volume
                            let fs = document.selections
                                .map { $0.rect }
                                .map { sheetView.convertFromWorld($0) }
                            beganTimeframes = sheetView.textsView.elementViews.enumerated().reduce(into: [Int: Timeframe]()) { (dic, v) in
                                if fs.contains(where: { v.element.transformedScoreFrame.intersects($0) }),
                                   let timeframe = v.element.model.timeframe,
                                   timeframe.volume != nil {
                                    dic[v.offset] = timeframe
                                }
                            }
                            
                            beganContent = textView.model.timeframe?.content
                        }
                    }
                }
                
                lightnessNode.children = volumeNodes(from: beganVolume, firstVolume: beganVolume, at: p)
                document.rootNode.append(child: lightnessNode)
            }
        case .changed:
            let dsp = event.screenPoint - beganSP
            if !isFirstChangedVolumeAmp, abs(dsp.x) > abs(dsp.y) {
                isChangePan = true
                
                lightnessNode.removeFromParent()
                
                var nEvent = event
                nEvent.phase = .began
                changePan(with: nEvent)
                changePan(with: event)
                
                return
            }
            isFirstChangedVolumeAmp = true
            
            if isPit {
                if let sheetView = noteSheetView,
                    let textI, textI < sheetView.textsView.elementViews.count {
                    
                    let textView = sheetView.textsView.elementViews[textI]
                    if let score = textView.model.timeframe?.score,
                       let noteI, noteI < score.notes.count,
                       let pitI, let beganPit, let beganPitbend,
                       pitI < beganPitbend.pits.count {
                        
                        let dp = sp - beganSP
                        var pitbend = beganPitbend
                        var pit = pitbend.pits[pitI]
                        pit.amp = (beganPit.amp + dp.y / 100).clipped(min: 0, max: Volume.maxAmp)
                        pitbend.pits[pitI] = pit
                        textView.model.timeframe?.score?.notes[noteI].pitbend = pitbend
                        
                        lightnessNode.children = volumeNodes(from: Volume(amp: pit.amp), 
                                                             firstVolume: beganVolume,
                                                             at: document.convertScreenToWorld(beganSP))
                    }
                }
            } else if let sheetView = noteSheetView, let ti = noteTextIndex {
                let textView = sheetView.textsView.elementViews[ti]
                let dSmp = (sp.y - beganSP.y)
                    * (document.screenToWorldScale / 50 / textView.nodeRatio)
                let smp = (beganVolume.smp + dSmp)
                    .clipped(min: 0, max: Volume.maxSmp)
                let volume = Volume(smp: smp)
                
                lightnessNode.children = volumeNodes(from: volume,
                                                     firstVolume: beganVolume,
                                                     at: document.convertScreenToWorld(beganSP))
                
                if isChangeScoreVolume {
                    if !beganTimeframes.isEmpty {
                        let scale = beganVolume.amp == 0 ?
                        1 : volume.amp / beganVolume.amp
                        for (ti, textView) in sheetView.textsView.elementViews.enumerated() {
                            guard let beganTimeframeVolume = beganTimeframes[ti]?.volume else { continue }
                            
                            let volume: Volume
                            if beganVolume.amp == 0 {
                                let smp = (beganTimeframeVolume.smp + dSmp)
                                    .clipped(min: 0, max: Volume.maxSmp)
                                volume = Volume(smp: smp)
                            } else {
                                let amp = (beganTimeframeVolume.amp * scale)
                                    .clipped(min: 0, max: Volume.maxAmp)
                                volume = Volume(amp: amp)
                            }
                            
                            textView.model.timeframe?.volume = volume
                            
                            if textView.model.timeframe?.content == nil {
                                textView.isUpdatedAudioCache = false
                            }
                            
                            if let timeframe = textView.model.timeframe {
                                sheetView.sequencer?.mixings[timeframe.id]?
                                    .volume = .init(volume.amp)
                            }
                        }
                    } else {
                        textView.model.timeframe?.volume = volume
                        
                        if textView.model.timeframe?.content == nil {
                            textView.isUpdatedAudioCache = false
                        }
                        
                        if let timeframe = textView.model.timeframe {
                            sheetView.sequencer?.mixings[timeframe.id]?
                                .volume = .init(volume.amp)
                        }
                    }
                    return
                }
                
                if let score = textView.model.timeframe?.score {
                    if !noteIndexes.isEmpty,
                              noteIndexes.count == beganVolumes.count {
                        let scale = beganVolume.amp == 0 ?
                            1 : volume.amp / beganVolume.amp
                        for (i, ni) in noteIndexes.enumerated() {
                            if ni < score.notes.count {
                                let volume: Volume
                                if beganVolume.amp == 0 {
                                    let smp = (beganVolumes[i].smp + dSmp)
                                        .clipped(min: 0, max: Volume.maxSmp)
                                    volume = Volume(smp: smp)
                                } else {
                                    let amp = (beganVolumes[i].amp * scale)
                                        .clipped(min: 0, max: Volume.maxAmp)
                                    volume = Volume(amp: amp)
                                }
                                
                                textView.model.timeframe?.score?.notes[ni].volume = volume
                                
                                if i == 0 {
                                    notePlayer?.notes = [score
                                        .convertPitchToWorld(score.notes[ni])]
                                }
                            }
                        }
                    }
                }
            }
        case .ended:
            notePlayer?.stop()
            
            lightnessNode.removeFromParent()
            
            if isPit {
                if let sheetView = noteSheetView,
                   let textI, textI < sheetView.textsView.elementViews.count {
                    
                    let textView = sheetView.textsView.elementViews[textI]
                    if let score = textView.model.timeframe?.score,
                       score != beganScore {
                        
                        sheetView.newUndoGroup()
                        sheetView.captureScore(score, old: beganScore,
                                               at: textI)
                    }
                }
            } else if let sheetView = noteSheetView,
                let ti = noteTextIndex, ti < sheetView.model.texts.count {
                
                if isChangeScoreVolume {
                    if !beganTimeframes.isEmpty {
                        var isNewUndoGroup = false
                        func updateUndoGroup() {
                            if !isNewUndoGroup {
                                sheetView.newUndoGroup()
                                isNewUndoGroup = true
                            }
                        }
                        for (ti, beganTimeframe) in beganTimeframes {
                            guard ti < sheetView.model.texts.count else { continue }
                            if let beganScore = beganTimeframe.score {
                               let score = sheetView.textsView.elementViews[ti].model.timeframe?.score
                               if score != beganScore {
                                   updateUndoGroup()
                                   sheetView.captureScore(score, old: beganScore, at: ti)
                               }
                            } else {
                                let text = sheetView.textsView.elementViews[ti].model
                                if text.timeframe != beganTimeframe {
                                    var beganText = text
                                    beganText.timeframe = beganTimeframe
                                    updateUndoGroup()
                                    sheetView.captureText(text, old: beganText, at: ti)
                                }
                            }
                        }
                    } else if let firstScore {
                        let score = sheetView.textsView.elementViews[ti].model.timeframe?.score
                        if score != firstScore {
                            sheetView.newUndoGroup()
                            sheetView.captureScore(score, old: firstScore, at: ti)
                        }
                    }
                } else {
                    let score = sheetView.textsView.elementViews[ti].model.timeframe?.score
                    if score != firstScore {
                        sheetView.newUndoGroup()
                        sheetView.captureScore(score, old: firstScore, at: ti)
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
                if sheetView.model.texts.contains(where: { $0.timeframe?.score != nil }) {
                    for (ti, textView) in sheetView.textsView.elementViews.enumerated() {
                        let inTP = textView.convertFromWorld(p)
                        if textView.containsScore(inTP) || textView.containsTimeframe(inTP) {
                            isChangeVolumeAmp = true
                            noteSheetView = sheetView
                            noteTextIndex = ti
                            if let ni = textView.noteIndex(at: inTP, maxDistance: 2.0 * document.screenToWorldScale) {
                                firstNoteIndex = ni
                                isChangeScoreVolume = false
                            } else {
                                isChangeScoreVolume = true
                            }
                            changeVolumeAmp(with: event)
                            return
                        }
                    }
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
