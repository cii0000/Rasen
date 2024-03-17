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

final class ContentSlider: DragEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    enum SlideType {
        case all, startBeat, endBeat, isShownSpectrogram
    }
    
    private var sheetView: SheetView?, contentI: Int?, beganContent: Content?
    private var type = SlideType.all
    private var beganSP = Point(), beganInP = Point(), beganContentEndP = Point()
    
    private var beganIsShownSpectrogram = false
    
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
            
            if let sheetView = document.sheetView(at: p),
                let ci = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                scale: document.screenToWorldScale) {
                
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
                
                let maxMD = 10 * document.screenToWorldScale
                
                if contentView.containsIsShownSpectrogram(contentP, scale: document.screenToWorldScale) {
                    type = .isShownSpectrogram
                    beganIsShownSpectrogram = contentView.model.isShownSpectrogram
                } else if let timeOption = content.timeOption {
                    if Swift.abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.start)) < maxMD {
                        type = .startBeat
                    } else if Swift.abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.end)) < maxMD {
                        type = .endBeat
                    } else {
                        type = .all
                    }
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
                    let np = beganContent.origin + sheetP - beganInP
                    let interval = document.currentNoteTimeInterval
                    let beat = max(min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - (content.timeOption?.beatRange.length ?? 0))
                    var timeOption = content.timeOption
                    timeOption?.beatRange.start = beat
                    contentView.set(timeOption, origin: Point(sheetView.animationView.x(atBeat: beat), np.y))
                    document.updateSelects()
                case .startBeat:
                    if var timeOption = content.timeOption {
                        let np = beganContent.origin + sheetP - beganInP
                        let interval = document.currentNoteTimeInterval
                        let beat = min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.end)
                        if beat != timeOption.beatRange.start {
                            let dBeat = timeOption.beatRange.start - beat
                            if content.type.isDuration {
                                timeOption.localStartBeat += dBeat
                            }
                            timeOption.beatRange.start -= dBeat
                            timeOption.beatRange.length += dBeat
                            contentView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), content.origin.y))
                            document.updateSelects()
                        }
                    }
                case .endBeat:
                    if var timeOption = content.timeOption {
                        let np = beganContentEndP + sheetP - beganInP
                        let interval = document.currentNoteTimeInterval
                        let beat = max(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.start)
                        if beat != timeOption.beatRange.end {
                            timeOption.beatRange.end = beat
                            contentView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), content.origin.y))
                            document.updateSelects()
                        }
                    }
                case .isShownSpectrogram:
                    let contentP = contentView.convertFromWorld(p)
                    let isShownSpectrogram = contentView.isShownSpectrogram(at: contentP)
                    contentView.isShownSpectrogram = isShownSpectrogram
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
            
            document.cursor = Document.defaultCursor
        }
    }
}

struct ContentLayout {
    static let spectrogramX = 10.0, spectrogramHeight = 5.0
}

final class ContentView<T: BinderProtocol>: SpectrgramView {
    typealias Model = Content
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    var isFullEdit = false {
        didSet {
            guard isFullEdit != oldValue else { return }
            if let node = timelineNode.children.first(where: { $0.name == "isFullEdit" }) {
                node.isHidden = !isFullEdit
            }
        }
    }
    
    let clippingNode = Node(isHidden: true,
                            lineWidth: 4, lineType: .color(.warning))
    
    let timelineNode = Node()
    var spectrogramNode: Node?
    var spectrogramFqType: Spectrogram.FqType?
    var timeNode: Node?, currentVolumeNode: Node?
    var peakVolume = Volume() {
        didSet {
            guard peakVolume != oldValue else { return }
            updateFromPeakVolume()
        }
    }
    func updateFromPeakVolume() {
        guard let node = currentVolumeNode,
              let frame = timelineFrame else { return }
        let smp = peakVolume.smp
            .clipped(min: 0, max: Volume.maxSmp, newMin: 0, newMax: 1)
        let y = frame.height * smp
        node.path = Path([Point(), Point(0, y)])
        if Swift.abs(peakVolume.amp) < Audio.clippingAmp {
            node.lineType = .color(.background)
        } else {
            node.lineType = .color(.warning)
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        if let image = binder[keyPath: keyPath].image,
           let texture = Texture(image: image, isOpaque: false, colorSpace: .sRGB) {
            node = Node(children: [timelineNode, clippingNode],
                        attitude: Attitude(position: binder[keyPath: keyPath].origin),
                        path: Path(Rect(size: binder[keyPath: keyPath].size)),
                        fillType: .texture(texture))
        } else {
            node = Node(children: [timelineNode, clippingNode],
                        attitude: Attitude(position: binder[keyPath: keyPath].origin))
        }
        
        updateClippingNode()
        updateTimeline()
        updateSpectrogram()
    }
}
extension ContentView {
    func updateWithModel() {
        node.attitude.position = model.origin
        if let image = model.image,
           let texture = Texture(image: image, isOpaque: false, colorSpace: .sRGB) {
            node.fillType = .texture(texture)
            node.path = Path(Rect(size: model.size))
        }
        updateClippingNode()
        updateTimeline()
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
        if model.timeOption != nil {
            timelineNode.children = self.timelineNode(with: model)
            
            let timeNode = Node(lineWidth: 3, lineType: .color(.content))
            let volumeNode = Node(lineWidth: 1, lineType: .color(.background))
            timeNode.append(child: volumeNode)
            timelineNode.children.append(timeNode)
            self.timeNode = timeNode
            self.currentVolumeNode = volumeNode
        } else if !timelineNode.children.isEmpty {
            timelineNode.children = []
            self.timeNode = nil
            self.currentVolumeNode = nil
        }
    }
    
    func set(_ timeOption: ContentTimeOption?, origin: Point) {
        binder[keyPath: keyPath].timeOption = timeOption
        binder[keyPath: keyPath].origin = origin
        node.attitude.position = origin
        updateTimeline()
        updateClippingNode()
    }
    var timeOption: ContentTimeOption? {
        get { model.timeOption }
        set {
            binder[keyPath: keyPath].timeOption = newValue
            updateTimeline()
            updateClippingNode()
        }
    }
    var origin: Point {
        get { model.origin }
        set {
            binder[keyPath: keyPath].origin = newValue
            node.attitude.position = newValue
            updateClippingNode()
        }
    }
    
    var imageFrame: Rect? {
        model.imageFrame
    }
    
    var frameRate: Int { Keyframe.defaultFrameRate }
    
    var tempo: Rational {
        get { model.timeOption?.tempo ?? 0 }
        set {
            binder[keyPath: keyPath].timeOption?.tempo = newValue
            updateTimeline()
            
//            if let spctrogram {
//                let allBeat = content.localBeatRange?.length ?? 0
//                let allW = width(atBeatDuration: allBeat)
//            }
        }
    }
    
    var timeLineCenterY: Double {
        model.type.isDuration ? 0 : -Sheet.timelineHalfHeight
    }
    var beatRange: Range<Rational>? {
        model.timeOption?.beatRange
    }
    var localBeatRange: Range<Rational>? {
        model.localBeatRange
    }
    
    var spectrgramY: Double {
        timelineFrame?.maxY ?? 0
    }
    
    var pcmBuffer: PCMBuffer? {
        model.pcmBuffer
    }
    
    func timelineNode(with content: Content) -> [Node] {
        guard let timeOption = content.timeOption else { return [] }
        let sBeat = max(timeOption.beatRange.start, -10000),
            eBeat = min(timeOption.beatRange.end, 10000)
        guard sBeat <= eBeat else { return [] }
        let sx = self.x(atBeat: sBeat)
        let ex = self.x(atBeat: eBeat)
        
        let lw = 1.0
        let noteHeight = ScoreLayout.noteHeight
        let knobW = Sheet.knobWidth, knobH = Sheet.knobHeight
        let rulerH = Sheet.rulerHeight
        let timelineHalfHeight = Sheet.timelineHalfHeight
        let y = content.type.isDuration ? 0 : -timelineHalfHeight
        let sy = y - timelineHalfHeight
        let ey = y + timelineHalfHeight
        
        var textNodes = [Node]()
        var contentPathlines = [Pathline]()
        var subBorderPathlines = [Pathline]()
        var fullEditBorderPathlines = [Pathline]()
        var borderPathlines = [Pathline]()
        var noteLineNodes = [Node]()
        
        func timeStringFrom(time: Rational,
                            frameRate: Int) -> String {
            let minusStr = time < 0 ? "-" : ""
            let time = abs(time)
            if time >= 60 {
                let c = Int(time * Rational(frameRate))
                let s = c / frameRate
                let minutes = s / 60
                let sec = s - minutes * 60
                let frame = c - s * frameRate
                let minutesStr = String(format: "%d", minutes)
                let secStr = String(format: "%02d", sec)
                let frameStr = String(format: "%02d", frame)
                return minusStr + minutesStr + ":" + secStr + "." + frameStr
            } else {
                let c = Int(time * Rational(frameRate))
                let s = c / frameRate
                let sec = s
                let frame = c - s * frameRate
                let secStr = String(format: "%d", sec)
                let frameStr = String(format: "%02d", frame)
                return minusStr + secStr + "." + frameStr
            }
        }
        
        if let localBeatRange = content.localBeatRange {
            if localBeatRange.start < 0 {
                let beat = -min(localBeatRange.start, 0)
                - min(timeOption.beatRange.start, 0)
                let timeText = Text(string: timeStringFrom(time: beat, frameRate: 48),
                                    size: Font.smallSize)
                let timeP = Point(sx + 1, y + noteHeight)
                textNodes.append(Node(attitude: Attitude(position: timeP),
                                      path: Path(timeText.typesetter, isPolygon: false),
                                      fillType: .color(.content)))
            } else if localBeatRange.start > 0 {
                let ssx = x(atBeat: localBeatRange.start + timeOption.beatRange.start)
                contentPathlines.append(Pathline(Rect(x: ssx - 1 / 4, y: y - 3,
                                                      width: 1 / 2, height: 6)))
            }
        }
        
        if let localBeatRange = content.localBeatRange {
            if timeOption.beatRange.start + localBeatRange.end > timeOption.beatRange.end {
                let beat = timeOption.beatRange.length - localBeatRange.start
                
                let timeText = Text(string: timeStringFrom(time: beat, frameRate: 48),
                                    size: Font.smallSize)
                let timeFrame = timeText.frame ?? Rect()
                let timeP = Point(ex - timeFrame.width - 2, y + noteHeight)
                textNodes.append(Node(attitude: Attitude(position: timeP),
                                      path: Path(timeText.typesetter,
                                                 isPolygon: false),
                                      fillType: .color(.content)))
            } else if localBeatRange.end < timeOption.beatRange.length {
                let ssx = x(atBeat: localBeatRange.end + timeOption.beatRange.start)
                contentPathlines.append(Pathline(Rect(x: ssx - 1 / 4, y: y - 3,
                                                      width: 1 / 2, height: 6)))
            }
        }
        
        if !content.volumeValues.isEmpty {
            let sSec = timeOption.sec(fromBeat: max(-timeOption.localStartBeat, 0))
            let msSec = timeOption.sec(fromBeat: timeOption.localStartBeat)
            let csSec = timeOption.sec(fromBeat: timeOption.beatRange.start)
            let beatDur = ContentTimeOption.beat(fromSec: content.secDuration,
                                                 tempo: timeOption.tempo,
                                                 beatRate: Keyframe.defaultFrameRate,
                                                 rounded: .up)
            let eSec = timeOption
                .sec(fromBeat: min(timeOption.beatRange.end - (timeOption.localStartBeat + timeOption.beatRange.start),
                                   beatDur))
            let si = Int((sSec * Content.volumeFrameRate).rounded())
                .clipped(min: 0, max: content.volumeValues.count - 1)
            let msi = Int((msSec * Content.volumeFrameRate).rounded())
            let ei = Int((eSec * Content.volumeFrameRate).rounded())
                .clipped(min: 0, max: content.volumeValues.count - 1)
            let vt = content.volume.smp
                .clipped(min: 0, max: Volume.maxSmp,
                         newMin: lw / noteHeight, newMax: 1)
            if si < ei {
                let line = Line(controls: (si ... ei).map { i in
                    let sec = Rational(i + msi) / Content.volumeFrameRate + csSec
                    return .init(point: .init(x(atSec: sec), y),
                                 pressure: content.volumeValues[i] * vt)
                })
                
                let pan = content.pan
                let color = Self.panColor(pan: pan, brightness: 0.25)
                noteLineNodes += [Node(path: .init(line),
                                       lineWidth: noteHeight,
                                       lineType: .color(color))]
            }
        }
        
        contentPathlines.append(.init(Rect(x: sx - 1, y: y - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: ex - 1, y: y - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: sx + 1, y: y - lw / 2,
                                           width: ex - sx - 2, height: lw)))
        
        makeBeatPathlines(in: timeOption.beatRange, sy: sy, ey: ey,
                          subBorderPathlines: &subBorderPathlines,
                          fullEditBorderPathlines: &fullEditBorderPathlines,
                          borderPathlines: &borderPathlines)
        
        if content.type.isAudio {
            let sprH = ContentLayout.spectrogramHeight
            let sprKnobW = knobH, sprKbobH = knobW
            let np = Point(ContentLayout.spectrogramX + sx, ey)
            contentPathlines.append(Pathline(Rect(x: np.x - 1 / 2,
                                                  y: np.y,
                                                  width: 1,
                                                  height: sprH)))
            if content.isShownSpectrogram {
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
        }
        
        let secRange = timeOption.secRange
        for sec in Int(secRange.start.rounded(.up)) ..< Int(secRange.end.rounded(.up)) {
            let sec = Rational(sec)
            guard secRange.contains(sec) else { continue }
            let secX = x(atSec: sec)
            contentPathlines.append(.init(Rect(x: secX - lw / 2, y: sy - rulerH / 2,
                                               width: lw, height: rulerH)))
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
        if !subBorderPathlines.isEmpty {
            nodes.append(Node(path: Path(subBorderPathlines),
                              fillType: .color(.subBorder)))
        }
        nodes += noteLineNodes
        if !contentPathlines.isEmpty {
            nodes.append(Node(path: Path(contentPathlines),
                              fillType: .color(.content)))
        }
        nodes += textNodes
        
        return nodes
    }
    
    static func panColor(pan: Double, brightness l: Double) -> Color {
        pan == 0 ?
        Color(red: l, green: l, blue: l) :
            (pan > 0 ?
             Color(red: pan * Spectrogram.editRedRatio * (1 - l) + l, green: l, blue: l) :
                Color(red: l, green: -pan * Spectrogram.editGreenRatio * (1 - l) + l, blue: l))
    }
    
    func updateSpectrogram() {
        spectrogramNode?.removeFromParent()
        spectrogramNode = nil
        
        let content = model
        guard content.isShownSpectrogram, let sm = content.spectrogram,
              let timeOption = content.timeOption else { return }
        
        let firstX = x(atBeat: timeOption.beatRange.start + timeOption.localStartBeat)
        let y = timeLineCenterY + Sheet.timelineHalfHeight + ContentLayout.spectrogramHeight
        let allBeat = content.localBeatRange?.length ?? 0
        let allW = width(atBeatDuration: allBeat)
        var nodes = [Node](), maxH = 0.0
        func spNode(width: Int, at xi: Int) -> Node? {
            guard let image = sm.image(width: width, at: xi),
                  let texture = Texture(image: image,
                                        isOpaque: false,
                                        colorSpace: .sRGB) else { return nil }
            let w = allW * Double(width) / Double(sm.frames.count)
            let h = 256.0
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
        
        node.append(child: sNode)
    }
    func spectrogramPitch(atY y: Double) -> Double? {
        guard let spectrogramNode, let spectrogramFqType else { return nil }
        let y = y - 0.5 * 128.0 / 1024// - 1
        let h = spectrogramNode.path.bounds?.height ?? 0
        switch spectrogramFqType {
        case .linear:
            let fq = y.clipped(min: 0, max: h,
                               newMin: Spectrogram.minLinearFq,
                               newMax: Spectrogram.maxLinearFq)
            return Pitch.pitch(fromFq: max(fq, 1))
        case .pitch:
            return y.clipped(min: 0, max: h,
                             newMin: Double(Score.pitchRange.start),
                             newMax: Double(Score.pitchRange.end))
//            let fq = Mel.fq(fromMel: y.clipped(min: 0, max: h,
//                             newMin: 100,
//                             newMax: 4000))
//            return Pitch.pitch(fromFq: max(fq, 1))
        }
    }
    
    func updateTimeNode(atSec sec: Rational) {
        if let timeNode = timeNode, let frame = timelineFrame {
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
    
    var bounds: Rect? {
        if let timelineFrame {
            return timelineFrame.union(contentFrame)
        } else {
            return contentFrame
        }
    }
    var transformedBounds: Rect? {
        if let bounds {
            bounds * node.localTransform
        } else {
            nil
        }
    }
    
    var clippableBounds: Rect? {
        if let timelineFrame {
            timelineFrame.union(contentFrame)
        } else {
            contentFrame
        }
    }
    var transformedClippableBounds: Rect? {
        if let bounds = clippableBounds {
            bounds * node.localTransform
        } else {
            nil
        }
    }
    
    func containsContent(_ p : Point) -> Bool {
        contentFrame?.contains(p) ?? false
    }
    var contentFrame: Rect? {
        model.imageFrame?.bounds
    }
    
    func containsTimeline(_ p : Point) -> Bool {
        timelineFrame?.contains(p) ?? false
    }
    var timelineFrame: Rect? {
        guard let timeOption = model.timeOption else { return nil }
        let sx = x(atBeat: timeOption.beatRange.start)
        let ex = x(atBeat: timeOption.beatRange.end)
        let thh = Sheet.timelineHalfHeight
        return Rect(x: sx, y: model.type.isDuration ? -thh : -thh * 2,
                    width: ex - sx, height: thh * 2).outset(by: 3)
    }
    var transformedTimelineFrame: Rect? {
        if var f = timelineFrame {
            f.origin.y += model.origin.y
            return f
        } else {
            return nil
        }
    }
    
    func containsIsShownSpectrogram(_ p: Point, scale: Double) -> Bool {
        if let timelineFrame {
            Rect(x: timelineFrame.minX + ContentLayout.spectrogramX - Sheet.knobHeight / 2,
                 y: Sheet.timelineHalfHeight - Sheet.knobWidth / 2,
                 width: Sheet.knobHeight,
                 height: ContentLayout.spectrogramHeight + Sheet.knobWidth)
            .outset(by: scale * 3)
            .contains(p)
        } else {
            false
        }
    }
    
    func contains(_ p: Point, scale: Double) -> Bool {
        containsContent(p)
        || containsTimeline(p)
        || containsIsShownSpectrogram(p, scale: scale)
    }
    
    func isShownSpectrogram(at p :Point) -> Bool {
        if model.type.isAudio {
            p.y > Sheet.timelineHalfHeight + ContentLayout.spectrogramHeight / 2
        } else {
            false
        }
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
