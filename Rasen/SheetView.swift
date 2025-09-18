// Copyright 2025 Cii
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

import Dispatch
import struct Foundation.UUID

final class LineView<T: BinderProtocol>: BindableView, @unchecked Sendable {
    typealias Model = Line
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    fileprivate var captureColor: Color?
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        node = Node(path: Path(binder[keyPath: keyPath]),
                    lineWidth: binder[keyPath: keyPath].size,
                    lineType: .color(binder[keyPath: keyPath].uuColor.value))
    }
    
    func updateWithModel() {
        updateColor()
        updatePath()
        node.lineWidth = model.size
    }
    func updateColor() {
        node.lineType = .color(model.uuColor.value)
    }
    func updatePath() {
        node.path = Path(model)
    }
    var uuColor: UUColor {
        get { model.uuColor }
        set {
            binder[keyPath: keyPath].uuColor = newValue
            updateColor()
        }
    }
    func intersects(_ otherRect: Rect) -> Bool {
        guard let b = node.bounds else { return false }
        guard b.intersects(otherRect) else {
            return false
        }
        if otherRect.contains(b) {
            return true
        }
        let line = model
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
}
typealias SheetLineView = LineView<SheetBinder>

final class PlaneView<T: BinderProtocol>: BindableView, @unchecked Sendable {
    typealias Model = Plane
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        node = Node(path: binder[keyPath: keyPath].path,
                    fillType: .color(binder[keyPath: keyPath].uuColor.value))
        node.isCPUFillAntialias = false
    }
    
    func updateWithModel() {
        updateColor()
        updatePath()
    }
    func updateColor() {
        node.fillType = .color(model.uuColor.value)
    }
    func updatePath() {
        node.path = model.path
    }
    var uuColor: UUColor {
        get { model.uuColor }
        set {
            binder[keyPath: keyPath].uuColor = newValue
            updateColor()
        }
    }
}
typealias SheetPlaneView = PlaneView<SheetBinder>

typealias SheetTextView = TextView<SheetBinder>
typealias SheetContentView = ContentView<SheetBinder>

final class BorderView<T: BinderProtocol>: BindableView, @unchecked Sendable {
    typealias Model = Border
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    var bounds = Sheet.defaultBounds {
        didSet {
            guard bounds != oldValue else { return }
            updateWithModel()
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        node = Node(path: binder[keyPath: keyPath].path(with: bounds),
                    lineWidth: 1, lineType: .color(.subBorder))
    }
    
    var screenToWorldScale = 1.0 {
        didSet {
            guard screenToWorldScale != oldValue else { return }
            if screenToWorldScale < 0.5 {
                node.lineWidth = screenToWorldScale * 2
            } else if node.lineWidth != 1 {
                node.lineWidth = 1
            }
        }
    }
    func updateWithModel() {
        node.path = model.path(with: bounds)
    }
}
typealias SheetBorderView = BorderView<SheetBinder>

final class KeyframeView: BindableView, @unchecked Sendable {
    typealias Model = Keyframe
    typealias Binder = SheetBinder
    let binder: Binder
    var keyPath: BinderKeyPath {
        didSet {
            linesView.keyPath = keyPath.appending(path: \Model.picture.lines)
            planesView.keyPath = keyPath.appending(path: \Model.picture.planes)
            draftLinesView.keyPath = keyPath.appending(path: \Model.draftPicture.lines)
            draftPlanesView.keyPath = keyPath.appending(path: \Model.draftPicture.planes)
        }
    }
    let node: Node
    
    let linesView: ArrayView<SheetLineView>
    let planesView: ArrayView<SheetPlaneView>
    let draftLinesView: ArrayView<SheetLineView>
    let draftPlanesView: ArrayView<SheetPlaneView>
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        linesView = ArrayView(binder: binder,
                              keyPath: keyPath.appending(path: \Model.picture.lines))
        planesView = ArrayView(binder: binder,
                               keyPath: keyPath.appending(path: \Model.picture.planes))
        draftLinesView = ArrayView(binder: binder,
                                   keyPath: keyPath.appending(path: \Model.draftPicture.lines))
        draftPlanesView = ArrayView(binder: binder,
                                    keyPath: keyPath.appending(path: \Model.draftPicture.planes))
        
        node = Node(children: [draftPlanesView.node, draftLinesView.node,
                               planesView.node, linesView.node])
        
        updateDraft()
    }
    
    func updateWithModel() {
        linesView.updateWithModel()
        planesView.updateWithModel()
        draftLinesView.updateWithModel()
        draftPlanesView.updateWithModel()
        
        updateDraft()
    }
    func updateDraft() {
        if !draftLinesView.model.isEmpty {
            draftLinesView.elementViews.forEach {
                $0.node.lineType = .color(.draftLine)
            }
        }
        if !draftPlanesView.model.isEmpty {
            draftPlanesView.elementViews.forEach {
                $0.node.fillType = .color(Sheet.draftPlaneColor(from: $0.model.uuColor.value,
                                                                fillColor: .background))
            }
        }
    }
}

extension TimelineView {
    func makeBeatPathlines(in beatRange: Range<Rational>,
                           sy: Double, ey: Double, subBorderBeats: Set<Rational> = [],
                           enabledBeatExtension: Bool = true,
                           subBorderPathlines: inout [Pathline],
                           fullEditBorderPathlines: inout [Pathline],
                           borderPathlines: inout [Pathline]) {
        let roundedSBeat = beatRange.start.rounded(.down)
        let deltaBeat = Rational(1, 128)
        let beatR1 = Rational(1, 8)
        let beat0 = Rational(1)
        var cBeat = roundedSBeat
        while cBeat <= beatRange.end {
            if cBeat >= beatRange.start {
                let lw: Double = if cBeat % beat0 == 0 {
                    0.5
                } else if cBeat % beatR1 == 0 {
                    0.25
                } else {
                    0.0625
                }
                
                let beatX = x(atBeat: cBeat)
                
                let dlh = enabledBeatExtension && lw == 0.5 ? 3.0 : 0.0
                let rect = Rect(x: beatX - lw / 2, y: sy - dlh,
                                width: lw, height: ey - sy + dlh * 2)
                if subBorderBeats.contains(cBeat) {
                    subBorderPathlines.append(.init(rect))
                } else if lw == 0.0625 {
                    fullEditBorderPathlines.append(.init(rect))
                } else {
                    borderPathlines.append(.init(rect))
                }
            }
            cBeat += deltaBeat
        }
        
        subBorderBeats.sorted().forEach {
            if $0 % deltaBeat != 0 {
                let beatX = x(atBeat: $0)
                let lw = 0.0625
                let rect = Rect(x: beatX - lw / 2, y: sy,
                                width: lw, height: ey - sy)
                subBorderPathlines.append(.init(rect))
            }
        }
    }
}

final class AnimationView: TimelineView, @unchecked Sendable {
    typealias Binder = KeyframeView.Binder
    typealias Model = Animation
    let binder: Binder
    var keyPath: BinderKeyPath
    let node = Node()
    let previousNextNode = Node()
    let captionNode = Node()
    let timelineNode = Node()
    let boundsNode = Node(lineWidth: 1, lineType: .color(.content))
    let clippingNode = Node(isHidden: true, lineWidth: 4, lineType: .color(.warning))
    
    var isPlaying = false
    var bounds = Sheet.defaultBounds {
        didSet {
            guard bounds != oldValue else { return }
            updateTimeline()
        }
    }
    var frameRate = Keyframe.defaultFrameRate {
        didSet { updateTimeline() }
    }
    var timelineY: Double {
        get { model.timelineY }
        set {
            binder[keyPath: keyPath].timelineY = newValue
            timelineNode.attitude.position.y = newValue
        }
    }
    
    var tempo: Rational {
        get { model.tempo }
        set {
            binder[keyPath: keyPath].tempo = newValue
            updateTimeline()
        }
    }
    
    var isSelected = false {
        didSet {
            updateTimeline()
        }
    }
    
    var selectedFrameIndexes = [Int]() {
        didSet {
            guard selectedFrameIndexes != oldValue else { return }
            updateTimeline()
        }
    }
    
    var keyframeView: KeyframeView {
        elementViews[model.index]
    }
    
    typealias ElementView = KeyframeView
    typealias ModelElement = KeyframeView.Model
    private(set) var elementViews: [ElementView]
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        elementViews = AnimationView.elementViewsWith(model: binder[keyPath: keyPath],
                                                      binder: binder,
                                                      keyPath: keyPath)
        updateTimeline()
        updateWithKeyframeIndex()
        timelineNode.attitude.position.y = binder[keyPath: keyPath].timelineY
    }
    
    func updateWithModel() {
        updateElementViews()
    }
    func updateElementViews() {
        elementViews = AnimationView.elementViewsWith(model: model,
                                                      binder: binder,
                                                      keyPath: keyPath)
    }
    private static func elementViewsWith(model: Model,
                                         binder: Binder,
                                         keyPath: BinderKeyPath) -> [ElementView] {
        return model.keyframes.enumerated().map { (i, _) in
            ElementView(binder: binder,
                        keyPath: keyPath.appending(path: \Model.keyframes[i]))
        }
    }
    
    @discardableResult
    func append(_ modelElement: ModelElement) -> ElementView {
        binder[keyPath: keyPath].keyframes.append(modelElement)
        let elementView
            = ElementView(binder: binder,
                          keyPath: keyPath
                            .appending(path: \Model.keyframes[model.keyframes.count - 1]))
        elementViews.append(elementView)
        return elementView
    }
    @discardableResult
    func insert(_ modelElement: ModelElement, at index: Int) -> ElementView {
        binder[keyPath: keyPath].keyframes.insert(modelElement, at: index)
        let elementView
            = ElementView(binder: binder,
                          keyPath: keyPath.appending(path: \Model.keyframes[index]))
        elementViews.insert(elementView, at: index)
        
        elementViews[(index + 1)...].enumerated().forEach { (i, aElementView) in
            aElementView.keyPath = keyPath.appending(path: \Model.keyframes[index + 1 + i])
        }
        return elementView
    }
    func insert(_ elementView: ElementView, _ modelElement: ModelElement,
                at index: Int) {
        binder[keyPath: keyPath].keyframes.insert(modelElement, at: index)
        elementViews.insert(elementView, at: index)
        
        elementViews[(index + 1)...].enumerated().forEach { (i, aElementView) in
            aElementView.keyPath = keyPath.appending(path: \Model.keyframes[index + 1 + i])
        }
    }
    func remove(at index: Int) {
        binder[keyPath: keyPath].keyframes.remove(at: index)
        elementViews.remove(at: index)
        
        elementViews[index...].enumerated().forEach { (i, elementView) in
            elementView.keyPath = keyPath.appending(path: \Model.keyframes[index + i])
        }
    }
    func append(_ modelElements: [ModelElement]) {
        binder[keyPath: keyPath].keyframes += modelElements
        
        for i in 0 ..< modelElements.count {
            let j = model.keyframes.count - modelElements.count + i
            let elementView
                = ElementView(binder: binder,
                              keyPath: keyPath.appending(path: \Model.keyframes[j]))
            elementViews.append(elementView)
        }
    }
    func insert(_ ivs: [IndexValue<ModelElement>]) {
        var model = self.model
        for iv in ivs {
            model.keyframes.insert(iv.value, at: iv.index)
        }
        binder[keyPath: keyPath] = model
        
        let nElementViews: [ElementView] = ivs.map { iv in
            ElementView(binder: binder,
                        keyPath: keyPath.appending(path: \Model.keyframes[iv.index]))
        }
        for (i, elementView) in nElementViews.enumerated() {
            let iv = ivs[i]
            elementViews.insert(elementView, at: iv.index)
        }
        
        elementViews.enumerated().forEach { (i, elementView) in
            elementView.keyPath = keyPath.appending(path: \Model.keyframes[i])
        }
    }
    func insert(_ ivs: [IndexValue<ElementView>]) {
        var model = self.model
        for iv in ivs {
            model.keyframes.insert(iv.value.model, at: iv.index)
        }
        binder[keyPath: keyPath] = model
        
        for iv in ivs {
            elementViews.insert(iv.value, at: iv.index)
        }
        
        elementViews.enumerated().forEach { (i, elementView) in
            elementView.keyPath = keyPath.appending(path: \Model.keyframes[i])
        }
    }
    func append(_ elementViews: [ElementView], _ modelElements: [ModelElement]) {
        binder[keyPath: keyPath].keyframes += modelElements
        self.elementViews += elementViews
    }
    func removeLasts(count: Int) {
        binder[keyPath: keyPath].keyframes.removeLast(count)
        elementViews.removeLast(count)
    }
    func remove(at indexes: [Int]) {
        var model = self.model
        for index in indexes.reversed() {
            model.keyframes.remove(at: index)
            elementViews.remove(at: index)
        }
        binder[keyPath: keyPath] = model
        
        elementViews.enumerated().forEach { (i, elementView) in
            elementView.keyPath = keyPath.appending(path: \Model.keyframes[i])
        }
    }
    
    var rootBeat: Rational {
        get { binder[keyPath: keyPath].rootBeat }
        set {
            binder[keyPath: keyPath].rootBeat = newValue
            updateWithKeyframeIndex()
            updateTimeline()
        }
    }
    var rootBeatIndex: Animation.RootBeatIndex {
        get { binder[keyPath: keyPath].rootBeatIndex }
        set {
            binder[keyPath: keyPath].rootBeatIndex = newValue
            updateWithKeyframeIndex()
            updateTimeline()
        }
    }
    var rootBeatPosition: Animation.RootBeatPosition {
        get { binder[keyPath: keyPath].rootBeatPosition }
        set {
            binder[keyPath: keyPath].rootBeatPosition = newValue
            updateWithKeyframeIndex()
            updateTimeline()
        }
    }
    var rootKeyframeIndex: Int {
        get { binder[keyPath: keyPath].rootIndex }
        set {
            binder[keyPath: keyPath].rootIndex = newValue
            updateWithKeyframeIndex()
            updateTimeline()
        }
    }
    func moveNextInterKeyframe() {
        binder[keyPath: keyPath].moveNextInterKeyframe()
        updateWithKeyframeIndex()
        updateTimeline()
    }
    func movePreviousInterKeyframe() {
        binder[keyPath: keyPath].movePreviousInterKeyframe()
        updateWithKeyframeIndex()
        updateTimeline()
    }
    
    var currentKeyframe: Keyframe {
        get { binder[keyPath: keyPath].currentKeyframe }
        set {
            binder[keyPath: keyPath].currentKeyframe = newValue
            updateWithKeyframeIndex()
        }
    }
    
    func updateWithKeyframeIndex() {
        updatePreviousNext()
        
        node.children = [keyframeView.node]
    }
    
    func previousNextDistance(_ p: Point, scale: Double) -> Double {
        previousNextFrame.distanceSquared(p).squareRoot()
    }
    var previousNextFrame: Rect {
        let beatRange = model.beatRange
        let sBeat = max(beatRange.start, -10000)
        let sx = x(atBeat: sBeat)
        let ey = Sheet.timelineHalfHeight
        let pnW = 20.0, pnnH = 12.0, spnW = 3.0, pnY = ey + 12
        return Rect(x: sx, y: pnY - pnnH / 2, width: pnW * 3 + spnW, height: pnnH)
    }
    var paddingPreviousNextFrame: Rect {
        previousNextFrame.outset(by: Sheet.timelinePadding)
    }
    var transformedPreviousNextFrame: Rect {
        var f = previousNextFrame
        f.origin.y += timelineY
        return f
    }
    func containsPreviousNext(_ p: Point, scale: Double) -> Bool {
        previousNextDistance(p, scale: scale) < 3 + scale * 5
    }
    func previousNext(at p: Point) -> PreviousNext {
        let beatRange = model.beatRange
        let sBeat = max(beatRange.start, -10000)
        let sx = x(atBeat: sBeat)
        let pnW = 20.0
        return if p.x < sx + pnW * 0.5 {
            .none
        } else if p.x < sx + pnW * 1.5 {
            .previous
        } else if p.x < sx + pnW * 2.5 {
            .next
        } else {
            .previousAndNext
        }
    }
    
    func containsTimeline(_ p: Point, scale: Double) -> Bool {
        model.enabled ?
        ((paddingTimelineBounds?.contains(p) ?? false)
         || containsPreviousNext(p, scale: scale)) : false
    }
    var transformedPaddingTimelineBounds: Rect? {
        guard var b = paddingTimelineBounds else { return nil }
        b.origin.y += model.timelineY
        return b
    }
    func transformedKeyframeBounds(at i: Int) -> Rect? {
        let knobW = Sheet.knobWidth, knobH = Sheet.knobHeight
        let iKnobW = width(atDurBeat: Rational(1, frameRate)),
            iKnobH = Sheet.interpolatedKnobHeight
        let centerY = 0.0
        
        let kfBeat = model.beatRange.start + model.localBeat(at: i)
        let keyframe = model.keyframes[i]
        let kx = x(atBeat: kfBeat)
        
        let nKnobH = keyframe.isKey ? knobH : iKnobH
        
        return keyframe.isKey ?
            Rect(x: kx - knobW / 2,
                 y: centerY - nKnobH / 2 + model.timelineY,
                 width: knobW, height: nKnobH) :
            Rect(x: kx - iKnobW / 2,
                 y: centerY - nKnobH / 2 + model.timelineY,
                 width: iKnobW, height: nKnobH)
    }
    private(set) var timelineBounds: Rect?
    var paddingTimelineBounds: Rect? {
        timelineBounds?.outset(by: Sheet.timelinePadding)
    }
    
    var isFullEdit = false {
        didSet {
            guard isFullEdit != oldValue else { return }
            if let node = timelineNode.children.first(where: { $0.name == "isFullEdit" }) {
                node.isHidden = !isFullEdit
            }
        }
    }
    
    func updateTimeline() {
        if model.enabled {
            let btsx = x(atBeat: model.beatRange.lowerBound)
            let btex = x(atBeat: model.endLoopDurBeat)
            let timelineBounds = Rect(x: btsx, y: -Sheet.timelineHalfHeight,
                                      width: btex - btsx,
                                      height: Sheet.timelineHalfHeight * 2)
            self.timelineBounds = timelineBounds
            let af = timelineBounds.outset(by: Sheet.timelinePadding),
                bf = previousNextFrame.outset(by: Sheet.timelinePadding)
            timelineNode.children = timelineNodes() + [clippingNode]
            timelineNode.path = .init([Point(bf.minX, bf.maxY), Point(af.minX, af.minY),
                                       Point(af.maxX, af.minY), Point(af.maxX, af.maxY),
                                       Point(bf.maxX, af.maxY), Point(bf.maxX, bf.maxY)])
            timelineNode.fillType = .color(.subRemoving)
            timelineNode.attitude.position.y = model.timelineY
            
            updateClippingNode()
        } else {
            timelineNode.children = []
            timelineNode.path = .init()
            timelineNode.fillType = nil
            timelineBounds = nil
            timelineNode.attitude.position = .init()
            updateClippingNode()
        }
    }
    func updateTimelime(atKeyframe ki: Int) {
        updateTimeline()//
    }
    func updateTimelineAtCurrentKeyframe() {
        updateTimelime(atKeyframe: model.index)
    }
    func timelineNodes() -> [Node] {
        let beatRange = model.beatRange, loopDurBeat = model.loopDurBeat
        let sBeat = max(beatRange.start, -10000),
            eBeat = min(beatRange.end, 10000)
        let sx = x(atBeat: sBeat), ex = x(atBeat: eBeat)
        let lw = 1.0
        let knobW = Sheet.knobWidth, knobH = Sheet.knobHeight
        let rulerH = Sheet.rulerHeight
        let iKnobW = knobW, iKnobH = Sheet.interpolatedKnobHeight
        let centerY = 0.0
        let sy = centerY - Sheet.timelineHalfHeight
        let ey = centerY + Sheet.timelineHalfHeight
        let w = ex - sx
        
        let iSet = Set(selectedFrameIndexes)
        
        var contentPathlines = [Pathline](),
            borderPathlines = [Pathline](), subBorderPathlines = [Pathline]()
        var fullEditBorderPathlines = [Pathline]()
        var selectedPathlines = [Pathline]()
        
        contentPathlines.append(.init(Rect(x: sx, y: centerY - lw / 2,
                                           width: w, height: lw)))
        
        makeBeatPathlines(in: beatRange.start ..< beatRange.end + loopDurBeat, sy: sy, ey: ey,
                          subBorderPathlines: &subBorderPathlines,
                          fullEditBorderPathlines: &fullEditBorderPathlines,
                          borderPathlines: &borderPathlines)
        
        let mainBeatX = x(atBeat: model.mainBeat)
        
        for (i, keyframe) in model.keyframes.enumerated() {
            let kx = x(atBeat: keyframe.beat + beatRange.start)
            
            let nKnobH = keyframe.isKey ? knobH : iKnobH
            let nKnobW = (keyframe.beat + beatRange.start) % Sheet.beatInterval == 0 ? knobW : knobW / 2
            let topD: Double
            if !keyframe.draftPicture.isEmpty {
                let pathline = Pathline(Rect(x: kx - nKnobW / 2,
                                             y: centerY + nKnobH / 2 - knobW,
                                             width: nKnobW, height: knobW))
                if iSet.contains(i) {
                    selectedPathlines.append(pathline)
                } else {
                    contentPathlines.append(pathline)
                }
                topD = knobW * 2
            } else {
                topD = 0
            }
            
            let bottomD = 0.0
            
            let niKnobW = (keyframe.beat + beatRange.start) % Sheet.beatInterval == 0 ? iKnobW : iKnobW / 2
            let pathline = keyframe.isKey ?
            Pathline(Rect(x: kx - nKnobW / 2,
                          y: centerY - nKnobH / 2 + bottomD,
                          width: nKnobW, height: nKnobH - bottomD - topD)) :
            Pathline(Rect(x: kx - niKnobW / 2,
                          y: centerY - nKnobH / 2 + bottomD,
                          width: niKnobW, height: nKnobH - bottomD - topD))
            if iSet.contains(i) {
                selectedPathlines.append(pathline)
            } else {
                contentPathlines.append(pathline)
            }
        }
        let kx = ex
        let nKnobW = eBeat % Sheet.beatInterval == 0 ? knobW : knobW / 2
        let eKnobMinY = centerY - knobH / 2 - 1
        contentPathlines.append(.init(Rect(x: kx - nKnobW / 2,
                                           y: eKnobMinY,
                                           width: nKnobW, height: knobH + 2)))
        
        let loopKnobH = 4.0
        let neBeat = eBeat + loopDurBeat
        let lkx = x(atBeat: neBeat)
        if loopDurBeat > 0 {
            contentPathlines.append(.init(Rect(x: ex, y: ey - lw / 2,
                                               width: lkx - ex, height: lw)))
            contentPathlines.append(.init(Rect(x: ex, y: centerY - lw / 2,
                                               width: lkx - ex, height: lw)))
            var beat = eBeat
            loop: while beat < neBeat {
                for keyframe in model.keyframes {
                    let nBeat = keyframe.beat + beat
                    guard nBeat < neBeat else { break loop }
                    let kx = x(atBeat: nBeat)
                    contentPathlines.append(.init(Rect(x: kx - 0.5,
                                                       y: centerY - 2,
                                                       width: 1, height: 4)))
                }
                beat += beatRange.length
            }
        }
        contentPathlines.append(.init(Rect(x: lkx - nKnobW / 2,
                                           y: ey - loopKnobH / 2,
                                           width: nKnobW, height: loopKnobH)))
        
        if isSelected {
            let d = knobH / 2
            let kx = x(atBeat: model.currentKeyframe.beat + beatRange.start)
            let kd = model.currentKeyframe.isKey ? knobH / 2 : iKnobH / 2
            contentPathlines.append(.init(Rect(x: kx - lw / 2,
                                               y: sy,
                                               width: lw,
                                               height: (centerY - kd - knobW / 2) - sy)))
            contentPathlines.append(.init(Rect(x: kx - lw / 2,
                                               y: centerY + kd + knobW / 2,
                                               width: lw,
                                               height: ey - (centerY + kd + knobW / 2))))
            
            contentPathlines.append(.init(Rect(x: mainBeatX - lw / 2,
                                               y: sy,
                                               width: lw,
                                               height: (centerY - d - knobW / 2) - sy)))
            contentPathlines.append(.init(Rect(x: mainBeatX - lw * 2,
                                               y: sy,
                                               width: lw * 4,
                                               height: lw)))
            contentPathlines.append(.init(Rect(x: mainBeatX - lw / 2,
                                               y: centerY + d + knobW / 2,
                                               width: lw,
                                               height: ey - (centerY + d + knobW / 2))))
            contentPathlines.append(.init(Rect(x: mainBeatX - lw * 2,
                                               y: ey - lw,
                                               width: lw * 4,
                                               height: lw)))
        }
        
        let secRange = model.secRange
        for sec in Int(secRange.start.rounded(.up)) ..< Int((secRange.end + model.loopDurSec).rounded(.up)) {
            let sec = Rational(sec)
            let secX = x(atSec: sec)
            let lw = sec == 1 ? knobW : lw
            contentPathlines.append(.init(Rect(x: secX - lw / 2, y: sy - rulerH,
                                               width: lw, height: rulerH)))
        }
        
        let pnW = 20.0, pnH = 6.0, spnW = 3.0, spnH = 3.0, pnnH = Sheet.knobHeight,
            pnY = ey + Sheet.timelineMargin / 2
        contentPathlines.append(.init(Rect(x: sx,
                                           y: pnY - lw / 2,
                                           width: pnW * 3 + spnW, height: lw)))
        
        contentPathlines.append(.init(Rect(x: sx - lw / 2,
                                           y: pnY - pnH / 2,
                                           width: lw, height: pnH)))
        
        contentPathlines.append(.init(Rect(x: sx + pnW - spnW - lw / 2,
                                           y: pnY - spnH / 2,
                                           width: lw, height: spnH)))
        contentPathlines.append(.init(Rect(x: sx + pnW - lw / 2,
                                           y: pnY - pnH / 2,
                                           width: lw, height: pnH)))
        
        contentPathlines.append(.init(Rect(x: sx + pnW * 2 - lw / 2,
                                           y: pnY - pnH / 2,
                                           width: lw, height: pnH)))
        contentPathlines.append(.init(Rect(x: sx + pnW * 2 + spnW - lw / 2,
                                           y: pnY - spnH / 2,
                                           width: lw, height: spnH)))
        
        contentPathlines.append(.init(Rect(x: sx + pnW * 3 - spnW - lw / 2,
                                           y: pnY - spnH / 2,
                                           width: lw, height: spnH)))
        contentPathlines.append(.init(Rect(x: sx + pnW * 3 - lw / 2,
                                           y: pnY - pnH / 2,
                                           width: lw, height: pnH)))
        contentPathlines.append(.init(Rect(x: sx + pnW * 3 + spnW - lw / 2,
                                           y: pnY - spnH / 2,
                                           width: lw, height: spnH)))
        let pnX = switch model.previousNext {
        case .none: pnW * 0
        case .previous: pnW * 1
        case .next: pnW * 2
        case .previousAndNext: pnW * 3
        }
        contentPathlines.append(.init(Rect(x: pnX + sx - nKnobW / 2,
                                           y: pnY - pnnH / 2,
                                           width: Sheet.knobWidth, height: pnnH)))
        
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
        if !contentPathlines.isEmpty {
            nodes.append(Node(path: Path(contentPathlines),
                              fillType: .color(.content)))
        }
        if !selectedPathlines.isEmpty {
            nodes.append(Node(path: Path(selectedPathlines),
                              fillType: .color(.selected)))
        }
        return nodes
    }
    func updatePreviousNext() {
        guard !isPlaying else { return }
        
        func otherNode(color: Color, _ previousNext: PreviousNext, atRootInter i :Int) -> Node {
            let i = model.index(atRootInter: i)
            let keyframeView = elementViews[i]
            let currentKeyframe = model.keyframe(atRootInter: model.rootInterIndex)
            let dp = previousNext == .previous ?
            currentKeyframe.previousPosition : currentKeyframe.nextPosition
            let nodes = keyframeView.linesView.elementViews.map {
                let node = $0.node.clone
                node.attitude.position = dp
                node.lineType = .color(.background)
                return node
            } + (dp != .init() ? keyframeView.model.picture.lines.map {
                Node(path: Path([$0.firstPoint, $0.firstPoint + dp]),
                     lineWidth: $0.size * 0.25, lineType: .color(.background))
            } : [])
            return Node(children: nodes, isClippingChildren: true,
                        path: .init(bounds), fillType: .color(color))
        }
        
        if model.keyframes.count <= 1 {
            if !previousNextNode.children.isEmpty {
                previousNextNode.children.forEach {
                    $0.lineType = .color(.content)
                }
                previousNextNode.children = []
            }
            return
        }
        switch model.previousNext {
        case .none:
            if !previousNextNode.children.isEmpty {
                previousNextNode.children.forEach {
                    $0.lineType = .color(.content)
                }
                previousNextNode.children = []
            }
        case .previous:
            previousNextNode.children = [otherNode(color: .previous, .previous,
                                                   atRootInter: model.rootInterIndex - 1)]
        case .next:
            previousNextNode.children = [otherNode(color: .next, .next,
                                                   atRootInter: model.rootInterIndex + 1)]
        case .previousAndNext:
            previousNextNode.children = [otherNode(color: .previous, .previous,
                                                   atRootInter: model.rootInterIndex - 1),
                                         otherNode(color: .next, .next,
                                                   atRootInter: model.rootInterIndex + 1)]
        }
    }
    
    var clippableBounds: Rect? {
        transformedPaddingTimelineBounds
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
                clippingNode.attitude.position = -timelineNode.attitude.position
            } else {
                clippingNode.isHidden = true
            }
        } else {
            clippingNode.isHidden = true
        }
    }
    
    func slidableKeyframeIndex(atRootBeat: Rational, maxDistance: Double) -> (i: Int, distance: Double)? {
        slidableKeyframeIndex(at: Point(x(atBeat: model.localBeat(atRootBeat: atRootBeat)), 0),
                              maxDistance: maxDistance)
    }
    func slidableKeyframeIndex(at inP: Point, maxDistance: Double) -> (i: Int, distance: Double)? {
        guard abs(inP.y) < Sheet.timelineHalfHeight * 15 / 16 else { return nil }
        let animation = model
        let beatRange = animation.beatRange
        
        var minD = maxDistance, minI: Int?
        for (i, keyframe) in animation.keyframes.enumerated() {
            let x = x(atBeat: keyframe.beat + beatRange.start)
            let d = abs(inP.x - x)
            if d < minD {
                minD = d
                minI = i
            }
        }
        
        if let minI, minI + 2 < animation.keyframes.count,
           animation.keyframes[minI].beat == animation.keyframes[minI + 1].beat {
            
            for i in minI + 1 ..< animation.keyframes.count - 1 {
                if animation.keyframes[i + 1].beat - animation.keyframes[i].beat > 0 {
                    return (i, minD)
                }
            }
            return (animation.keyframes.count - 1, minD)
        }
        
        return if let minI { (minI, minD) } else { nil }
    }
    func keyframeIndex(at inP: Point, isEnabledCount: Bool = false) -> Int? {
        guard abs(inP.y) < Sheet.timelineHalfHeight * 15 / 16 else { return nil }
        let animation = model
        let count = animation.keyframes.count
        var minD = Double.infinity, minI: Int?
        let beatRange = animation.beatRange
        for (i, keyframe) in animation.keyframes.enumerated() {
            let x = x(atBeat: keyframe.beat + beatRange.start)
            let d = abs(inP.x - x)
            if d < minD {
                minD = d
                minI = i
            }
        }
        if isEnabledCount {
            let x = x(atBeat: beatRange.end)
            let d = abs(inP.x - x)
            if d < minD {
                minD = d
                minI = count
            }
        }
        
        if let minI {
            return minI
        } else {
            return nil
        }
    }
    
    func isInterpolated(atLineI li: Int, atKeyframeI fki: Int) -> Bool {
        guard model.keyframes.count >= 2 else { return false }
        let id = model.keyframes[fki].picture.lines[li].id
        return model.keyframes.enumerated().contains(where: { (ki, kf) in
            guard ki != fki else { return false }
            return kf.picture.lines.enumerated().contains(where: {
                $0.element.id == id
            })
        })
    }
    func enabledFirstOrLastInterpolated(atLineI li: Int,
                                        atRootKI: Int, fromRootKI: Int) -> Bool {
        guard model.keyframes.count >= 2 else { return false }
        let ki = model.index(atRoot: atRootKI)
        let id = model.keyframes[ki].picture.lines[li].id
        func isID(at ki: Int) -> Bool {
            model.keyframes[ki].picture.lines.contains { $0.id == id }
        }
        return if fromRootKI <= atRootKI {
            !(fromRootKI ..< atRootKI).contains(where: { isID(at: model.index(atRoot: $0)) })
        } else {
            !(atRootKI + 1 ... fromRootKI).contains(where: { isID(at: model.index(atRoot: $0)) })
        }
    }
    var shownInterTypeKeyframeIndex: Int? {
        didSet {
            guard shownInterTypeKeyframeIndex != oldValue else { return }
            if let oldValue = oldValue, oldValue < elementViews.count {
                elementViews[oldValue].linesView.elementViews.forEach {
                    $0.node.lineType = .color($0.captureColor ?? $0.model.uuColor.value)
                    $0.captureColor = nil
                }
            }
            if let i = shownInterTypeKeyframeIndex, i < elementViews.count {
                elementViews[i].linesView.elementViews.forEach {
                    let nColor: Color
                    if case .color(let color) = $0.node.lineType {
                        $0.captureColor = color
                        nColor = color
                    } else {
                        $0.captureColor = nil
                        nColor = $0.model.uuColor.value
                    }
                    
                    $0.node.lineType = switch $0.model.interType {
                    case .interpolated: .color(nColor.lightness < 80 ? .init(lightness: min(nColor.lightness + 40, 80)) : .init(lightness: nColor.lightness - 20))
                    case .key, .none: .color(nColor)
                    }
                }
            }
        }
    }
    func interpolationNodes(from ids: [UUID], scale: Double,
                            removeLineIndex: Int? = nil,
                            oldRootKeyframeIndex orki: Int? = nil,
                            newRootKeyframeIndex nrki: Int? = nil,
                            isConvertToWorld: Bool = true) -> [Node] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        let ki = model.index, lw = Line.defaultLineWidth
        
        let boldKISet: Set<Int> = if let orki, let nrki {
            Set((orki < nrki ? (orki ... nrki) : (nrki ... orki)).map { model.index(atRoot: $0) })
        } else {
            []
        }
        
        func draw(orki: Int, nrki: Int, ort: Double, nrt: Double,
                  pnP: Point, in pnPs: inout [Int: Point]) {
            let (pri, ot, nri, nt) = orki < nrki ? (orki, ort, nrki, nrt) : (nrki, nrt, orki, ort)
            (pri ... nri).forEach {
                let t = Double($0).clipped(min: .init(pri), max: .init(nri), newMin: ot, newMax: nt)
                let i = model.index(atRoot: $0)
                if let op = pnPs[i] {
                    pnPs[i] = op + Point.linear(.init(), pnP, t: t)
                } else {
                    pnPs[i] = Point.linear(.init(), pnP, t: t)
                }
            }
        }
       
        var pnPs = [Int: Point]()
        let pP = model.currentKeyframe.previousPosition
        if !pP.isEmpty {
            let preRKI0 = model.rootIndex(atRootInter: model.rootInterIndex - 1)
            let preRKI1 = model.rootIndex(atRootInter: model.rootInterIndex - 2)
            draw(orki: preRKI1, nrki: preRKI0, ort: 0, nrt: 1, pnP: pP, in: &pnPs)
            if preRKI0 + 1 < model.rootIndex {
                draw(orki: preRKI0 + 1, nrki: model.rootIndex, ort: 1, nrt: 0, pnP: pP, in: &pnPs)
            }
        }
        let nP = model.currentKeyframe.nextPosition
        if !nP.isEmpty {
            let nextRKI0 = model.rootIndex(atRootInter: model.rootInterIndex + 1)
            let nextRKI1 = model.rootIndex(atRootInter: model.rootInterIndex + 2)
            draw(orki: model.rootIndex, nrki: nextRKI0, ort: 0, nrt: 1, pnP: nP, in: &pnPs)
            if nextRKI0 + 1 < nextRKI1 {
                draw(orki: nextRKI0 + 1, nrki: nextRKI1, ort: 1, nrt: 0, pnP: nP, in: &pnPs)
            }
        }
        
        let nlw = max(lw * 0.5, lw * scale), blw = lw * 4, nblw = lw * 2
        let color: Color = removeLineIndex != nil ?
            .removing : .subSelected
        var nodes = [Node]()
        var lineNodeDic = [[Line.Control]: Node]()
        for (i, kf) in model.keyframes.enumerated() {
            for (li, line) in kf.picture.lines.enumerated() {
                var isAppend = true
                if let nli = removeLineIndex {
                    if i == ki && nli == li {
                        isAppend = false
                    }
                }
                if isAppend, idSet.contains(line.id) {
                    if let node = lineNodeDic[line.controls] {
                        node.lineWidth = blw
                    } else {
                        let pnP = pnPs[i] ?? .init()
                        let nLine = isConvertToWorld ? convertToWorld(line) : line
                        let node = Node(attitude: .init(position: pnP),
                                        path: Path(nLine),
                                        lineWidth: boldKISet.contains(i) ? nblw : nlw,
                                        lineType: .color(color))
                        nodes.append(node)
                        lineNodeDic[line.controls] = node
                    }
                }
            }
        }
        
        return nodes
    }
    func interporatedTimelineNodes(from ids: [UUID]) -> [Node] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        
        let knobW = Sheet.knobWidth, knobH = Sheet.knobHeight
        let iKnobW = width(atDurBeat: Rational(1, frameRate)),
            iKnobH = Sheet.interpolatedKnobHeight
        let nb = bounds.insetBy(dx: Sheet.textPadding.width, dy: 0)
        let kfY = nb.minY + timelineY
        
        var selectedPathlines = [Pathline]()
        
        let beatRange = model.beatRange
        for keyframe in model.keyframes {
            let nLines = keyframe.picture.lines.filter { idSet.contains($0.id) }
            guard !nLines.isEmpty else { continue }
            let kx = x(atBeat: keyframe.beat + beatRange.start)
            
            let pathline = nLines.contains(where: { $0.interType == .key }) ?
                Pathline(Rect(x: kx - knobW / 2,
                              y: kfY - knobH / 2,
                              width: knobW, height: knobH)) :
                Pathline(Rect(x: kx - iKnobW / 2,
                              y: kfY - iKnobH / 2,
                              width: iKnobW, height: iKnobH))
            selectedPathlines.append(pathline)
            
            if !keyframe.draftPicture.isEmpty {
                let pathline = Pathline(Rect(x: kx - knobW / 2,
                                             y: kfY + knobH / 2 + knobW,
                                             width: knobW, height: knobW))
                 selectedPathlines.append(pathline)
            }
        }
        
        return [Node(path: convertToWorld(Path(selectedPathlines)),
                     fillType: .color(.selected))]
    }
    func interporatedTimelineNodes(fromColor ids: [UUID]) -> [Node] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        
        let knobW = Sheet.knobWidth, knobH = Sheet.knobHeight
        let iKnobW = width(atDurBeat: Rational(1, frameRate)),
            iKnobH = Sheet.interpolatedKnobHeight
        let nb = bounds.insetBy(dx: Sheet.textPadding.width, dy: 0)
        let kfY = nb.minY + timelineY
        
        var selectedPathlines = [Pathline]()
        
        let beatRange = model.beatRange
        for keyframe in model.keyframes {
            let nPlanes = keyframe.picture.planes.filter { idSet.contains($0.uuColor.id) }
            guard !nPlanes.isEmpty else { continue }
            let kx = x(atBeat: keyframe.beat + beatRange.start)
            
            let pathline = Pathline(Rect(x: kx - iKnobW / 2,
                                         y: kfY - iKnobH / 2,
                                         width: iKnobW, height: iKnobH))
            selectedPathlines.append(pathline)
            
            if !keyframe.draftPicture.isEmpty {
                let pathline = Pathline(Rect(x: kx - knobW / 2,
                                             y: kfY + knobH / 2 + knobW,
                                             width: knobW, height: knobW))
                 selectedPathlines.append(pathline)
            }
        }
        
        return [Node(path: convertToWorld(Path(selectedPathlines)),
                     fillType: .color(.selected))]
    }
    
    var origin: Point { .init(0, timelineY) }
    var timelineCenterY: Double { 0 }
    var beatRange: Range<Rational>? {
        get { model.beatRange }
        set {
            guard let newValue else { return }
            binder[keyPath: keyPath].beatRange = newValue
            updateTimeline()
        }
    }
    var localBeatRange: Range<Rational>? {
        model.localBeatRange
    }
    
    var endLoopDurBeat: Rational? {
        get { model.endLoopDurBeat }
        set {
            guard let newValue else { return }
            binder[keyPath: keyPath].endLoopDurBeat = newValue
            updateTimeline()
        }
    }
    
    var previousNext: PreviousNext {
        get { model.previousNext }
        set {
            guard newValue != previousNext else { return }
            binder[keyPath: keyPath].previousNext = newValue
            updatePreviousNext()
            updateTimeline()
        }
    }
    
    enum HitResult {
        case key(i: Int)
        case previousNext(PreviousNext)
        case endBeat
        case loopDurBeat
        case all
    }
    func hitTest(_ p: Point, scale: Double) -> HitResult {
        var minD = Double.infinity, minResult = HitResult.all
        let pnD = previousNextDistance(p, scale: scale)
        
        if pnD < minD && pnD < 3 + scale * 5 {
            minD = pnD
            minResult = .previousNext(previousNext(at: p))
        }
        
        if p.y > Sheet.timelineHalfHeight - 3 {
            let ld = abs(p.x - x(atBeat: model.endLoopDurBeat))
            if ld < minD && ld < 10.0 * scale {
                minD = ld
                minResult = .loopDurBeat
            }
        }
        
        let ed = abs(p.x - x(atBeat: model.beatRange.end))
        if ed < minD && ed < 10.0 * scale {
            minD = ed
            minResult = .endBeat
        }
        
        let md = Sheet.knobEditDistance * 2 * scale
        if let (minI, d) = slidableKeyframeIndex(at: p, maxDistance: md) {
            if d < minD {
                minD = d
                minResult = .key(i: minI)
            }
        }
        
        return minResult
    }
    
    func tempoPositionBeat(_ p: Point, scale: Double) -> Rational? {
        let tempoBeat = model.beatRange.start.rounded(.down) + 1
        if tempoBeat < model.beatRange.end {
            let sy = model.timelineY - Sheet.timelineHalfHeight
            let np = Point(x(atBeat: tempoBeat), sy)
            return np.distance(p) < 15 * scale ? tempoBeat : nil
        } else {
            return nil
        }
    }
}

typealias SheetBinder = RecordBinder<Sheet>
typealias SheetHistory = History<SheetUndoItem>

final class SheetView: BindableView, @unchecked Sendable {
    typealias Model = Sheet
    typealias Binder = SheetBinder
    let binder: Binder
    var keyPath: BinderKeyPath
    
    weak var selectedTextView: SheetTextView?
    
    var history = SheetHistory()
    var id = UUID()
    
    let node: Node
    let opacityNode = Node()
    let animationView: AnimationView
    var keyframeView: KeyframeView {
        animationView.elementViews[model.animation.index]
    }
    var linesView: ArrayView<SheetLineView> {
        keyframeView.linesView
    }
    var planesView: ArrayView<SheetPlaneView> {
        keyframeView.planesView
    }
    var draftLinesView: ArrayView<SheetLineView> {
        keyframeView.draftLinesView
    }
    var draftPlanesView: ArrayView<SheetPlaneView> {
        keyframeView.draftPlanesView
    }
    let scoreView: ScoreView
    let contentsView: ArrayView<SheetContentView>
    let textsView: ArrayView<SheetTextView>
    let bordersView: ArrayView<SheetBorderView>
    
    var notePlayer: NotePlayer?
    let tempoNode = Node()
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        animationView = AnimationView(binder: binder,
                                      keyPath: keyPath.appending(path: \Model.animation))
        scoreView =  ScoreView(binder: binder,
                               keyPath: keyPath.appending(path: \Model.score))
        contentsView = ArrayView(binder: binder,
                                 keyPath: keyPath.appending(path: \Model.contents))
        textsView = ArrayView(binder: binder,
                              keyPath: keyPath.appending(path: \Model.texts))
        bordersView = ArrayView(binder: binder,
                                keyPath: keyPath.appending(path: \Model.borders))
        
        node = Node(children: [opacityNode,
                               animationView.node,
                               animationView.previousNextNode,
                               contentsView.node,
                               scoreView.node,
                               textsView.node,
                               bordersView.node,
                               animationView.timelineNode,
                               animationView.captionNode])
        
        updateBackground()
        updateWithKeyframeIndex()
        updateTimeline()
        
        animationView.isSelected = true
    }
    
    func cancelTasks() {
        playingTimer?.cancel()
        playingTimer = nil
        isPlaying = false
        
        if sequencer != nil {
            sequencer?.beginPause()
            audioPauseTask = Task { @MainActor in
                try Task.checkCancellation()
                try await Task.sleep(sec: Waveclip.releaseSec + 0.01)
                try Task.checkCancellation()
                sequencer?.pause()
            }
        }
    }
    
    func updateWithModel() {
        linesView.updateWithModel()
        planesView.updateWithModel()
        draftLinesView.updateWithModel()
        draftPlanesView.updateWithModel()
        scoreView.updateWithModel()
        contentsView.updateWithModel()
        textsView.updateWithModel()
        bordersView.updateWithModel()
        
        updateBackground()
        updateTimeline()
    }
    func updateWithKeyframeIndex() {
        updatePreviousNext()
        animationView.node.children = [keyframeView.node]
    }
    func updatePreviousNext() {
        animationView.updatePreviousNext()
    }
    func updateTimeline() {
        animationView.updateTimeline()
    }
    
    var screenToWorldScale = 1.0 {
        didSet {
            bordersView.elementViews.forEach {
                $0.screenToWorldScale = screenToWorldScale
            }
        }
    }
    
    var bounds: Rect {
        get { node.bounds ?? Sheet.defaultBounds }
        set {
            node.path = .init(newValue)
            animationView.bounds = newValue
            scoreView.bounds = newValue
            contentsView.elementViews.forEach { $0.updateClippingNode() }
            textsView.elementViews.forEach { $0.updateClippingNode() }
            bordersView.elementViews.forEach { $0.bounds = newValue }
        }
    }
    var backgroundUUColor: UUColor {
        get { model.backgroundUUColor }
        set {
            binder.value.backgroundUUColor = newValue
            
            updateBackground()
        }
    }
    private func updateBackground() {
        let backgroundUUColor = backgroundUUColor
        if backgroundUUColor != Sheet.defalutBackgroundUUColor {
            if backgroundUUColor.value.opacity != 1 {
                let color0 = Color(white: 1), color1 = Color(white: 0.975)
                opacityNode.path = .init([Rect].checkerboard(with: .init(square: 8), in: bounds)
                    .map { Pathline($0) })
                opacityNode.fillType = .color(color0.alphaBlend(backgroundUUColor.value))
                node.fillType = .color(color1.alphaBlend(backgroundUUColor.value))
            } else {
                opacityNode.path = .init()
                node.fillType = .color(backgroundUUColor.value)
            }
        } else {
            opacityNode.path = .init()
            node.fillType = nil
        }
    }
    
    var isSelectedKeyframes: Bool {
        !animationView.selectedFrameIndexes.isEmpty
    }
    func unselectKeyframes() {
        if isSelectedKeyframes {
            animationView.selectedFrameIndexes = []
        }
    }
    
    func sec(at p: Point, scale: Double, interval: Rational) -> Rational {
        if let (_, view) = contentIndexAndView(at: p, scale: scale) {
            view.sec(atX: p.x, interval: interval)
        } else if scoreView.contains(p, scale: scale) {
            scoreView.sec(atX: p.x, interval: interval)
        } else {
            animationView.sec(atX: p.x, interval: interval)
        }
    }
    
    func interporatedTimelineNodes(from ids: [UUID]) -> [Node] {
        animationView.interporatedTimelineNodes(from: ids)
    }
    func interporatedTimelineNodes(fromColor ids: [UUID]) -> [Node] {
        animationView.interporatedTimelineNodes(fromColor: ids)
    }
    
    func containsScoreNoder(from ids: Set<UUID>) -> Bool {
        if let scoreTrackItem = scoreView.scoreTrackItem {
            ids.contains(scoreTrackItem.id)
        } else {
            false
        }
    }
    func containsPCMTrackItem(from ids: Set<UUID>, in contentView: SheetContentView) -> Bool {
        if let pcmTrackItem = contentView.pcmTrackItem {
            ids.contains(pcmTrackItem.id)
        } else {
            false
        }
    }
    
    func currentKeyframeString() -> String {
        Animation.timeString(fromTime: model.animation.currentKeyframe.beat + model.animation.beatRange.start,
                             frameRate: Rational(frameRate))
        + (model.animation.currentKeyframe.isKey ? "" : "i")
    }
    func timeString(fromBeat beat: Rational) -> String {
        Animation.timeString(fromTime: beat, frameRate: Rational(frameRate))
    }
    func currentTimeString() -> String {
        Animation.timeString(fromTime: model.animation.localBeat,
                             frameRate: Rational(frameRate))
    }
    func currentTimeProgress() -> Double? {
        model.animation.localDurBeat != 0 && model.enabledAnimation ?
            .init(model.animation.localBeat / model.animation.localDurBeat) : nil
    }
    func currentTimeNodes() -> [Node] {
        Self.timeNodes(duration: model.animation.currentDurBeat,
                       time: model.animation.localBeat,
                       isKey: model.animation.currentKeyframe.isKey,
                       frameRate: Rational(frameRate))
    }
    static func timeNodes(duration: Rational,
                          time: Rational,
                          isKey: Bool,
                          frameRate: Rational) -> [Node] {
        let u = Animation.timeString(fromTime: time, frameRate: frameRate) + (isKey ? "" : "i")
        let size = Font.largeSize
        let text = Text(string: u, size: size)
        let b = text.frame ?? Rect()
        let tp = Point(-b.width / 2, -b.height / 2 - 9)
        let path = Text(string: u, size: size).typesetter.path()
        return [Node(attitude: Attitude(position: tp),
                     path: path,
                     lineWidth: 4, lineType: .color(.background)),
                Node(attitude: Attitude(position: tp),
                     path: path,
                     fillType: .color(.content))]
    }
    
    func containsTempo(_ p: Point, scale: Double) -> Bool {
        if animationView.containsTempo(p, scale: scale) {
            return true
        }
        if scoreView.containsTempo(p, scale: scale) {
            return true
        }
        for textView in textsView.elementViews {
            if textView.containsTempo(p, scale: scale) {
                return true
            }
        }
        for contentView in contentsView.elementViews {
            if contentView.containsTempo(p, scale: scale) {
                return true
            }
        }
        return false
    }
    func tempo(at p: Point, scale: Double) -> Rational? {
        if animationView.containsTempo(p, scale: scale) {
            return animationView.tempo
        }
        if scoreView.containsTempo(p, scale: scale) {
            return scoreView.tempo
        }
        for textView in textsView.elementViews {
            if textView.containsTempo(p, scale: scale) {
                return textView.tempo
            }
        }
        for contentView in contentsView.elementViews {
            if contentView.containsTempo(p, scale: scale) {
                return contentView.tempo
            }
        }
        return nil
    }
    
    func tempoString(from animationView: AnimationView) -> String {
        Self.tempoString(fromTempo: animationView.model.tempo)
    }
    func tempoNode(from animationView: AnimationView) -> Node {
        Self.tempoNode(fromTempo: animationView.model.tempo)
    }
    static func tempoString(fromTempo tempo: Rational) -> String {
        Double(tempo).string(digitsCount: 2) + " bpm"
    }
    static func tempoNode(fromTempo tempo: Rational) -> Node {
        let u = tempoString(fromTempo: tempo)
        let text = Text(string: u, size: Font.defaultSize)
        let b = text.frame ?? Rect()
        let tp = Point(-b.width / 2, -b.height - 7)
        let path = Text(string: u, size: Font.defaultSize).typesetter.path()
        return Node(children: [Node(attitude: Attitude(position: tp),
                                    path: path,
                                    lineWidth: 2, lineType: .color(.background)),
                               Node(attitude: Attitude(position: tp),
                                    path: path,
                                    fillType: .color(.content))])
    }
    
    func containsOtherTimeline(_ p: Point, scale: Double) -> Bool {
        if scoreView.containsMainFrame(scoreView.convert(p, from: node), scale: scale)
            || scoreView.containsTimeline(scoreView.convert(p, from: node), scale: scale) {
            return true
        }
        for view in contentsView.elementViews {
            if view.containsTimeline(view.convert(p, from: node), scale: scale) {
                return true
            }
        }
        for view in textsView.elementViews {
            if view.containsTimeline(view.convert(p, from: node), scale: scale) {
                return true
            }
        }
        return false
    }
    
    func contentIndex(at p: Point, scale: Double) -> Int? {
        for (i, view) in contentsView.elementViews.enumerated().reversed() {
            if view.contains(view.convert(p, from: node), scale: scale) {
                return i
            }
        }
        return nil
    }
    func contentIndexAndView(at p: Point, scale: Double) -> (Int, SheetContentView)? {
        if let ci = contentIndex(at: p, scale: scale) {
            (ci, contentsView.elementViews[ci])
        } else {
            nil
        }
    }
    func textIndex(at p: Point, scale: Double) -> Int? {
        if let i = textTuple(at: p)?.textIndex {
            return i
        }
        for (i, view) in textsView.elementViews.enumerated().reversed() {
            if view.contains(view.convert(p, from: node), scale: scale) {
                return i
            }
        }
        return nil
    }
    func textIndexAndView(at p: Point, scale: Double) -> (Int, SheetTextView)? {
        if let ti = textIndex(at: p, scale: scale) {
            (ti, textsView.elementViews[ti])
        } else {
            nil
        }
    }
    
    func slidableKeyframeIndex(at inP: Point,
                               maxDistance: Double) -> Int? {
        animationView.slidableKeyframeIndex(at: inP,
                                            maxDistance: maxDistance)?.i
    }
    func keyframeIndex(at inP: Point, isEnabledCount: Bool = false) -> Int? {
        animationView.keyframeIndex(at: inP, isEnabledCount: isEnabledCount)
    }
    
    var rootKeyframeIndex: Int {
        get { animationView.rootKeyframeIndex }
        set { animationView.rootKeyframeIndex = newValue }
    }
    var rootBeatIndex: Animation.RootBeatIndex {
        get { animationView.rootBeatIndex }
        set { animationView.rootBeatIndex = newValue }
    }
    var rootBeatPosition: Animation.RootBeatPosition {
        get { animationView.rootBeatPosition }
        set { animationView.rootBeatPosition = newValue }
    }
    var rootBeat: Rational {
        get { animationView.rootBeat }
        set { animationView.rootBeat = newValue }
    }
    
    var currentKeyframe: Keyframe {
        get { animationView.currentKeyframe }
        set { animationView.currentKeyframe = newValue }
    }
    
    var selectedFrameIndexes: [Int] {
        get { animationView.selectedFrameIndexes }
        set { animationView.selectedFrameIndexes = newValue }
    }
    
    func moveNextKeyframe() {
        if isPlaying {
            stop()
        }
        rootKeyframeIndex += 1
    }
    func movePreviousKeyframe() {
        if isPlaying {
            stop()
        }
        rootKeyframeIndex -= 1
    }
    func moveNextInterKeyframe() {
        if isPlaying {
            stop()
        }
        animationView.moveNextInterKeyframe()
    }
    func movePreviousInterKeyframe() {
        if isPlaying {
            stop()
        }
        animationView.movePreviousInterKeyframe()
    }
    func goNextFrame() {
        if isPlaying {
            stop()
        }
        let deltaTime = Rational(1, animationView.frameRate)
        self.rootBeat = Rational.saftyAdd(rootBeat, deltaTime)
    }
    func goPreviousFrame() {
        if isPlaying {
            stop()
        }
        let deltaTime = Rational(-1, animationView.frameRate)
        self.rootBeat = Rational.saftyAdd(rootBeat, deltaTime)
    }
    
    weak var left, right, top, bottom: SheetView?
    func updateScoreViewFromAround() {
        let nBeatRange = self.scoreView.model.beatRange
        var nNotes = [Note]()
        if let scoreView = left?.scoreView, scoreView.model.enabled {
            let beatRange = scoreView.model.beatRange
            nNotes += scoreView.model.notes.filter { $0.beatRange.end > beatRange.end }.map {
                var n = $0
                n.beatRange.start -= beatRange.end
                return n
            }
        }
        if let scoreView = right?.scoreView, scoreView.model.enabled {
            let startBeat = scoreView.model.beatRange.start
            nNotes += scoreView.model.notes.filter { $0.beatRange.start < startBeat }.map {
                var n = $0
                n.beatRange.start += nBeatRange.end
                return n
            }
        }
        self.scoreView.otherNotes = nNotes
    }
    func updateScoreViewFromOtherAround() {
        if let left {
            left.updateScoreViewFromAround()
        }
        if let right {
            right.updateScoreViewFromAround()
        }
        if let top {
            top.updateScoreViewFromAround()
        }
        if let bottom {
            bottom.updateScoreViewFromAround()
        }
    }
    
    func seqTrack(sampleRate: Double) -> Sequencer.Track {
        var seqTrack = sequencerTrack
        bottomSheetViews.forEach {
            if let aSeqTrack = $0.element?.sequencerTrack {
                seqTrack += aSeqTrack
            }
        }
        topSheetViews.forEach {
            if let aSeqTrack = $0.element?.sequencerTrack {
                seqTrack += aSeqTrack
            }
        }
        let bottomEndSec = bottomSheetViews.reduce(Rational(0)) {
            max($0, $1.element?.model.allEndSec ?? 0)
        }
        let topEndSec = topSheetViews.reduce(Rational(0)) {
            max($0, $1.element?.model.allEndSec ?? 0)
        }
        let mainDurSec = max(model.allEndSec, bottomEndSec, topEndSec,
                             seqTrack.durSec)
        seqTrack.scoreTrackItems.append(.init(rendnotes: [],
                                              sampleRate: sampleRate,
                                              startSec: 0,
                                              durSec: mainDurSec))
        return seqTrack
    }
    
    private var playingTimer: (any DispatchSourceTimer)?,
                playingOldKeyframeIndex: Int?
    private var playingCaptions = [Caption](),
                playingCaption: Caption?, playingCaptionNodes = [Node]()
    private var playingSheetIndex = 0
    var previousSheetViews = [WeakElement<SheetView>]()
    var nextSheetViews = [WeakElement<SheetView>]()
    var bottomSheetViews = [WeakElement<SheetView>]()
    var topSheetViews = [WeakElement<SheetView>]()
    private var bottomNodes = [Node](), centerNode: Node?, topNodes = [Node]()
    private var timeNode: Node?, volumeNode: Node?, musicBackgroundNode: Node?
    private var volumeColor = Color.background
    private(set) var sequencer: Sequencer?
    private var firstSec: Rational?
    private var willPlaySec: Rational?, playingOtherTimelineIDs = Set<UUID>()
    private var playingFrameRate: Rational = 24, firstDeltaSec: Rational = 0
    private var beganPlaySec: SuspendingClock.Instant?
    private var audioPauseTask: Task<(), any Error>?
    private var mainDurSec: Rational = 0
    let frameRate = Keyframe.defaultFrameRate
    var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else { return }
            updateWithIsPlaying()
        }
    }
    private func updateWithIsPlaying() {
        audioPauseTask?.cancel()
        playingTimer?.cancel()
        playingTimer = nil
        animationView.isPlaying = isPlaying
        animationView.previousNextNode.isHidden = isPlaying
        if isPlaying {
            let playingSec = firstSec
            ?? model.animation.sec(fromBeat: model.animation.mainBeat)
            self.playingSec = playingSec
            
            playingOldKeyframeIndex = nil
            bottomSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
            topSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
            bottomNodes = bottomSheetViews.count.range.map { _ in Node() }
            centerNode = nil
            topNodes = topSheetViews.count.range.map { _ in Node() }
            
            playingSheetIndex = 0
            playingCaption = nil
            
            let beat = firstSec != nil ?
            model.animation.beat(fromSec: firstSec!) :
            model.animation.mainBeat
            
            let caption = model.caption(atBeat: beat)
            playingCaption = caption
            if let caption = caption {
                let nodes = caption.nodes(in: model.mainFrame ?? bounds)
                playingCaptionNodes = nodes
                animationView.captionNode.children = nodes
            } else {
                playingCaptionNodes = []
                animationView.captionNode.children = []
            }
            
            setupTimeNodes(isVolume: true)
            
            var seqTracks = [Sequencer.Track]()
            var deltaSec: Rational = 0
            
            let sampleRate = Audio.defaultSampleRate
            var minFrameRate = model.mainFrameRate
            
            for weakElement in previousSheetViews {
                guard let sheetView = weakElement.element else { continue }
                let seqTrack = sheetView.seqTrack(sampleRate: sampleRate)
                sheetView.mainDurSec = seqTrack.durSec
                seqTracks.append(seqTrack)
                deltaSec += seqTrack.durSec
                
                minFrameRate = min(minFrameRate, sheetView.model.mainFrameRate)
            }
            firstDeltaSec = deltaSec
            
            let seqTrack = seqTrack(sampleRate: sampleRate)
            self.mainDurSec = seqTrack.durSec
            seqTracks.append(seqTrack)
            
            if model.enabledMusic {
                musicBackgroundNode = Node(path: .init(bounds), fillType: .color(.subRemoving))
            }
            
            let mainSec = model.animation.sec(fromBeat: beat)
            deltaSec += mainSec
            willPlaySec = mainSec
            
            for weakElement in nextSheetViews {
                guard let sheetView = weakElement.element else { continue }
                let seqTrack = sheetView.seqTrack(sampleRate: sampleRate)
                sheetView.mainDurSec = seqTrack.durSec
                seqTracks.append(seqTrack)
                
                minFrameRate = min(minFrameRate, sheetView.model.mainFrameRate)
            }
            
            if !playingOtherTimelineIDs.isEmpty {
                for i in 0 ..< seqTracks.count {
                    seqTracks[i].scoreTrackItems.removeAll {
                        !playingOtherTimelineIDs.contains($0.id)
                    }
                    seqTracks[i].pcmTrackItems.removeAll {
                        !playingOtherTimelineIDs.contains($0.id)
                    }
                }
            }
            
            allSampless = [[Double]](repeating: .init(repeating: 0, count: Self.tapSampleCount),
                                     count: 2)
            
            if seqTracks.contains(where: { !$0.isEmpty }) {
                if sequencer != nil {
                    sequencer?.update(seqTracks)
                } else {
                    let sequencer = Sequencer(tracks: seqTracks, type: .loop) { [weak self] (sampless, sampleRate) in
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.isPlaying else { return }
                            self.updateTimeNodes(from: sampless, sampleRate: sampleRate)
                        }
                    }
                    self.sequencer = sequencer
                }
            } else {
                sequencer = nil
            }
            
            sequencer?.startSec = Double(deltaSec)
            sequencer?.play()
            
            playingFrameRate = Rational(60)
            beganPlaySec = .now
            let timeInterval = Double(1 / playingFrameRate)
            playingTimer = DispatchSource.scheduledTimer(withTimeInterval: timeInterval) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard !(self?.playingTimer?.isCancelled ?? true) else { return }
                    self?.loopPlay()
                }
            }
        } else {
            playingSheetIndex = 0
            playingSec = nil
            playingOldKeyframeIndex = nil
            bottomSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
            topSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
            bottomNodes = []
            centerNode = nil
            topNodes = []
            musicBackgroundNode = nil
            
            updateWithKeyframeIndex()
            
            animationView.captionNode.children = []
            playingCaption = nil
            playingCaptionNodes = []
            
            playingSecRange = nil
            firstSec = nil
            
            endTimeNodes()
            
            allSampless = []
            
            contentsView.elementViews.forEach {
                if $0.model.type == .movie, let sec = $0.model.rootSec {
                    $0.updateMovie(atSec: sec)
                }
            }
            
            updatePreviousNext()
        
            if sequencer != nil {
                sequencer?.beginPause()
                audioPauseTask = Task { @MainActor in
                    try Task.checkCancellation()
                    try await Task.sleep(sec: Waveclip.releaseSec + 0.01)
                    try Task.checkCancellation()
                    sequencer?.pause()
                }
            }
//            sequencer?.endEngine()
//            sequencer = nil
        }
    }
    var playingSec: Rational? {
        didSet {
            guard playingSec != oldValue, let playingSec else { return }
            let sheetView = playingSheetView
            
            var children = [Node]()
            
            if !sheetView.bottomSheetViews.isEmpty {
                for (si, bottomSheetViewE) in sheetView.bottomSheetViews.enumerated() {
                    guard let bottomSheetView = bottomSheetViewE.element else { continue }
                    let i = bottomSheetView.model.animation.indexInBeatRange(atSec: playingSec)
                    if let i {
                        if bottomSheetView.playingOldKeyframeIndex != i {
                            if si < bottomNodes.count {
                                bottomNodes[si]
                                = bottomSheetView.animationView.elementViews[i].node.clone
                            }
                            bottomSheetView.playingOldKeyframeIndex = i
                        }
                    } else if si < bottomNodes.count {
                        bottomNodes[si] = .init()
                        bottomSheetView.playingOldKeyframeIndex = nil
                    }
                }
                children += bottomNodes
            } else {
                bottomNodes = []
            }
            
            let i = sheetView.model.animation.indexInBeatRange(atSec: playingSec)
            if let i {
                if playingOldKeyframeIndex != i {
                    let node = sheetView.animationView.elementViews[i].node
                    centerNode = playingSheetIndex == 0 ? node : node.clone
                    playingOldKeyframeIndex = i
                }
            } else {
                centerNode = nil
                playingOldKeyframeIndex = nil
            }
            if let centerNode {
                children.append(centerNode)
            }
            
            if !sheetView.topSheetViews.isEmpty {
                for (si, topSheetViewE) in sheetView.topSheetViews.enumerated() {
                    guard let topSheetView = topSheetViewE.element else { continue }
                    let i = topSheetView.model.animation.indexInBeatRange(atSec: playingSec)
                    if let i {
                        if topSheetView.playingOldKeyframeIndex != i {
                            if si < topNodes.count {
                                topNodes[si]
                                = topSheetView.animationView.elementViews[i].node.clone
                            }
                            topSheetView.playingOldKeyframeIndex = i
                        }
                    } else if si < topNodes.count {
                        topNodes[si] = .init()
                        topSheetView.playingOldKeyframeIndex = nil
                    }
                }
                children += topNodes
            } else {
                topNodes = []
            }
            
            if let musicBackgroundNode {
                children += [musicBackgroundNode]
            }
            
            if !children.isEmpty {
                animationView.node.children = children
            }
            
            let playingBeat = sheetView.model.animation.beat(fromSec: playingSec)
            let caption = sheetView.model.caption(atBeat: playingBeat)
            if caption != playingCaption {
                playingCaption = caption
                if let caption = caption {
                    let nodes = caption.nodes(in: sheetView.model.mainFrame ?? sheetView.bounds)
                    playingCaptionNodes = nodes
                    animationView.captionNode.children = nodes
                } else {
                    playingCaptionNodes = []
                    animationView.captionNode.children = playingCaptionNodes
                }
            } else {
                animationView.captionNode.children = playingCaptionNodes
            }
            
            updateTimeNodes()
            
            sheetView.contentsView.elementViews.forEach {
                if $0.model.type == .movie, let timeOption = $0.model.timeOption {
                    $0.updateMovie(atSec: playingSec - timeOption.secRange.start - timeOption.localStartBeat)
                }
            }
        }
    }
    func setupTimeNodes(isVolume: Bool) {
        endTimeNodes()
        if let parentNode = node.parent {
            let timeNode = Node()
            parentNode.append(child: timeNode)
            self.timeNode = timeNode
            
            if isVolume {
                let volumeNode = Node()
                parentNode.append(child: volumeNode)
                self.volumeNode = volumeNode
            }
            
            updateTimeNodes()
            if isVolume {
                updateTimeNodes(from: nil, sampleRate: Audio.defaultSampleRate)
            }
        }
    }
    func endTimeNodes() {
        timeNode?.removeFromParent()
        volumeNode?.removeFromParent()
        timeNode?.children = []
        volumeNode?.children = []
    }
    func updateTimeNodes() {
        if let playingSec {
            updateTimeNodes(fromSec: playingSec)
        }
    }
    func updateTimeNodesWithMainSec() {
        updateTimeNodes(fromSec: animationView.model.mainSec)
    }
    func updateTimeNodes(fromSec playingSec: Rational) {
        let sheetView = playingSheetView
        if let parentNode = sheetView.node.parent {
            var timeRects0 = [Rect](), timeRects1 = [Rect](), volumeRects1 = [Rect]()
            func update(from sheetView: SheetView) {
                let knobW = isPlaying ? 2.0 : 1.0, volmW = 1.25
                if !(!isPlaying && sheetView == self), sheetView.model.enabledAnimation && sheetView.animationView.model.allSecRange.contains(playingSec) {
                    
                    let btx = sheetView.animationView.x(atSec: playingSec)
                    let knobH = sheetView.animationView.timelineBounds?.height ?? 0
                    let tlY = sheetView.animationView.transformedPaddingTimelineBounds?.midY ?? 0
                    timeRects0.append(parentNode.convert(Rect(x: btx - knobW / 2, y: tlY - knobH / 2,
                                                              width: knobW, height: knobH),
                                                         from: sheetView.node))
                }
                timeRects0 += sheetView.textsView.elementViews.compactMap {
                    guard $0.timeOption?.secRange.contains(playingSec) ?? false,
                          let f = $0.transformedTimelineFrame else { return nil }
                    let btx = $0.x(atSec: playingSec) + $0.origin.x
                    return .init(x: btx - knobW / 2, y: f.minY, width: knobW, height: f.height)
                }.map { parentNode.convert($0, from: sheetView.node) }
                
                var oTimeRects1 = [Rect]()
                let scoreView = sheetView.scoreView
                if scoreView.option.enabled {
                    if scoreView.model.allSecRange.contains(playingSec) {
                        let btx = scoreView.x(atSec: playingSec) + scoreView.origin.x
                        let h = scoreView.mainFrame.maxY - scoreView.timelineFrame.minY
                        oTimeRects1.append(Rect(x: btx - knobW / 2,
                                                y: scoreView.timelineY - scoreView.timelineFrame.height / 2,
                                                width: knobW, height: h))
                    }
                }
                oTimeRects1 += sheetView.contentsView.elementViews.compactMap {
                    guard $0.timeOption?.secRange.contains(playingSec) ?? false,
                          let f = $0.transformedTimelineFrame else { return nil }
                    let h = $0.isShownSpectrogram ?
                    f.height + SheetContentView.spectrogramHeight + Sheet.timelineMargin : f.height
                    let btx = $0.x(atSec: playingSec) + $0.origin.x
                    return .init(x: btx - knobW / 2, y: f.minY, width: knobW, height: h)
                }
                
                timeRects1 += oTimeRects1.map { parentNode.convert($0, from: sheetView.node) }
                volumeRects1 += oTimeRects1.map { $0.inset(by: (knobW - volmW) / 2) }
                    .map { parentNode.convert($0, from: sheetView.node) }
            }
            update(from: sheetView)
            sheetView.bottomSheetViews.forEach {
                guard let sheetView = $0.element else { return }
                update(from: sheetView)
            }
            sheetView.topSheetViews.forEach {
                guard let sheetView = $0.element else { return }
                update(from: sheetView)
            }
            
            let rects0 = isPlaying ? [parentNode.convert(allTimeSliderRect(atSec: playingSec,
                                                                           at: playingSheetIndex),
                                                         from: node)] : []
            timeNode?.children
            = rects0.map { Node(path: Path($0), fillType: .color(.content)) }
            + timeRects0.map { Node(path: Path($0), fillType: .color(.content)) }
            + timeRects1.map { Node(path: Path($0), fillType: .color(.content)) }
            volumeNode?.children = volumeRects1.map { Node(path: Path($0), fillType: .color(volumeColor)) }
        } else {
            timeNode?.children = []
            volumeNode?.children = []
        }
    }
    
    static let tapSampleCount = 16384
    private var allSampless = [[Double]](repeating: .init(repeating: 0, count: tapSampleCount),
                                         count: 2)
    private func updateTimeNodes(from sampless: [[Double]]?, sampleRate: Double) {
        guard let sampless else {
            volumeColor = .background
            volumeNode?.children.forEach { $0.fillType = .color(volumeColor) }
            return
        }
        
        for ci in 0 ..< min(sampless.count, allSampless.count) {
            if allSampless[ci].count < sampless[ci].count {
                allSampless[ci] = Array(sampless[ci][(sampless[ci].count - allSampless[ci].count)...])
            } else {
                let di = allSampless[ci].count - sampless[ci].count
                for i in 0 ..< di {
                    allSampless[ci][i] = allSampless[ci][i + sampless[ci].count]
                }
                for i in di ..< allSampless[ci].count {
                    allSampless[ci][i] = sampless[ci][i - di]
                }
            }
        }
        
        let lufs = PCMBuffer.lufs(sampless: allSampless,
                                  sampleRate: sampleRate) ?? -.infinity
        let peakAmp = PCMBuffer.peakAmp(sampless: sampless)
        let isPeak = peakAmp > Audio.headroomAmp
        
        volumeColor = if isPeak {
            .warning
        } else if lufs > -14 {
            .linear(.content, .loudnessWarning,
                    t: lufs.clipped(min: -14, max: -9, newMin: 0, newMax: 1))
        } else {
            Color(white: lufs.clipped(min: -19, max: -14, newMin: 1, newMax: 0))
        }
        
        volumeNode?.children.forEach { $0.fillType = .color(volumeColor) }
    }
    private func allTimeSliderRect(atSec sec: Rational, at index: Int) -> Rect {
        if index == 0 {
            let beat = model.animation.beat(fromSec: sec)
            let btx = animationView.x(atBeat: beat)
            let knobW = 2.0, knobH = 6.0
            return Rect(x: btx - knobW / 2, y: 0,
                        width: knobW, height: knobH)
        } else if index < 0 {
            let allDurSec = model.allEndSec
            let bt = allDurSec == 0 ? 0 : Double(sec / allDurSec).clipped(min: 0, max: 1)
            let knobW = 2.0, knobH = 6.0
            return Rect(x: bounds.width / 2 * bt,
                        y: 0,
                        width: knobW, height: knobH)
        } else {
            let allDurSec = model.allEndSec
            let bt = allDurSec == 0 ? 0 : Double(sec / allDurSec).clipped(min: 0, max: 1)
            let knobW = 2.0, knobH = 6.0
            return Rect(x: bounds.midX + bounds.width / 2 * bt,
                        y: 0,
                        width: knobW, height: knobH)
        }
    }
    
    var playingSheetView: SheetView {
        if playingSheetIndex < 0, -playingSheetIndex <= previousSheetViews.count,
            let sheetView = previousSheetViews[previousSheetViews.count - (-playingSheetIndex - 1) - 1].element {
            return sheetView
        } else if playingSheetIndex > 0, playingSheetIndex <= nextSheetViews.count,
            let sheetView = nextSheetViews[playingSheetIndex - 1].element {
            
            return sheetView
        } else {
            return self
        }
    }
    private func loopPlay() {
        guard let willPlaySec else { return }
        if sequencer != nil, let beganPlaySec {
            let ddSec = beganPlaySec.duration(to: .now).sec
            let dSec = Rational(ddSec, intervalScale: .init(1, 60))
            let preDurSecs = previousSheetViews.map { $0.element?.mainDurSec ?? 0 }
            let preDurSec = preDurSecs.sum()
            guard mainDurSec > 0 else { return }
            let nextDurSecs = nextSheetViews.map { $0.element?.mainDurSec ?? 0 }
            let nexrDurSec = nextDurSecs.sum()
            let oldPlayingSheetIndex = playingSheetIndex
            if preDurSec == 0 && nexrDurSec == 0 {
                playingSheetIndex = 0
                playingSec = (dSec + willPlaySec) % mainDurSec
            } else {
                let nSec = dSec + willPlaySec
                var i = 0, nPlayingSec: Rational = 0, sec: Rational = 0
                while true {
                    let oldSec = sec
                    if i == 0 {
                        sec += mainDurSec
                        if nSec < sec {
                            nPlayingSec = (nSec - oldSec) % mainDurSec
                            break
                        }
                    } else if i < 0 {
                        let durSec = preDurSecs[preDurSecs.count - (-i - 1) - 1]
                        sec += durSec
                        if nSec < sec && durSec > 0 {
                            nPlayingSec = (nSec - oldSec) % durSec
                            break
                        }
                    } else {
                        let durSec = nextDurSecs[i - 1]
                        sec += durSec
                        if nSec < sec && durSec > 0 {
                            nPlayingSec = (nSec - oldSec) % durSec
                            break
                        }
                    }
                    
                    i += 1
                    if i > nextSheetViews.count {
                        i = -previousSheetViews.count
                    }
                }
                playingSheetIndex = i
                playingSec = nPlayingSec
            }
            
            if playingSheetIndex != oldPlayingSheetIndex {
                playingOldKeyframeIndex = nil
                bottomSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
                topSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
                bottomNodes = bottomSheetViews.count.range.map { _ in Node() }
                topNodes = topSheetViews.count.range.map { _ in Node() }
                
                let nSheetView = playingSheetView
                nSheetView.bottomSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
                nSheetView.topSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
                bottomNodes = nSheetView.bottomSheetViews.count.range.map { _ in Node() }
                topNodes = nSheetView.topSheetViews.count.range.map { _ in Node() }
            }
            
            return
        }
        
        let nSec = willPlaySec + 1 / playingFrameRate
        
        let sheetView = playingSheetView
        let maxSec = playingSecRange != nil ? playingSecRange!.end : sheetView.mainDurSec
        if nSec >= maxSec {
            let oldPlayingSheetIndex = playingSheetIndex
            
            playingSheetIndex += 1
            if playingSheetIndex > nextSheetViews.count {
                playingSheetIndex = -previousSheetViews.count
            }
            if playingSecRange != nil {
                playingSheetIndex = 0
            }
            
            if playingSheetIndex != oldPlayingSheetIndex {
                playingOldKeyframeIndex = nil
                bottomSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
                topSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
                bottomNodes = bottomSheetViews.count.range.map { _ in Node() }
                topNodes = topSheetViews.count.range.map { _ in Node() }
                
                let nSheetView = playingSheetView
                nSheetView.bottomSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
                nSheetView.topSheetViews.forEach { $0.element?.playingOldKeyframeIndex = nil }
                bottomNodes = nSheetView.bottomSheetViews.count.range.map { _ in Node() }
                topNodes = nSheetView.topSheetViews.count.range.map { _ in Node() }
            }
            
            if playingSecRange != nil || playingSheetIndex <= 0 {
                let sSec = playingSecRange?.start ?? 0
                self.willPlaySec = sSec
                playingSec = sSec
            } else {
                self.willPlaySec = nSec - maxSec
                playingSec = nSec - maxSec
            }
        } else {
            self.willPlaySec = nSec
            playingSec = nSec
        }
    }
    var playingSecRange: Range<Rational>?
    func play(atSec sec: Rational? = nil,
              inSec playingSecRange: Range<Rational>? = nil,
              otherTimelineIDs: Set<UUID> = []) {
        if isPlaying {
            isPlaying = false
            Sleep.start(atTime: Waveclip.releaseSec + 0.01)
        }
        if let sec {
            firstSec = sec
        }
        self.playingSecRange = playingSecRange
        self.playingOtherTimelineIDs = otherTimelineIDs
        isPlaying = true
    }
    func stop() {
        playingSecRange = nil
        playingOtherTimelineIDs = []
        isPlaying = false
    }
    func updatePlaying() {
        if isPlaying {
            let sec = playingSec
            let secRange = playingSecRange
            isPlaying = false
            firstSec = sec
            playingSecRange = secRange
            isPlaying = true
        }
    }
    
    func endSeqencer() {
        guard !(sequencer?.isPlaying ?? true) else { return }
        sequencer = nil
    }
    
    func updateCaption() {
        guard isPlaying else { return }
        
        guard let playingSec else { return }
        
        let sheetView = playingSheetView
        let playingBeat = sheetView.model.animation
            .beat(fromSec: Double(playingSec), beatRate: 60)
        
        let caption = model.caption(atBeat: playingBeat)
        playingCaption = caption
        if let caption = caption {
            let nodes = caption.nodes(in: model.mainFrame ?? bounds)
            playingCaptionNodes = nodes
            animationView.captionNode.children = nodes
        } else {
            playingCaptionNodes = []
            animationView.captionNode.children = []
        }
    }
    
    func note(at inP: Point, scale: Double) -> Note? {
        guard scoreView.model.enabled else { return nil }
        let scoreP = scoreView.convert(inP, from: node)
        return if let ni = scoreView.noteIndex(at: scoreP, scale: scale) {
            scoreView.model.notes[ni]
        } else {
            nil
        }
    }
    
    var sequencerTrack: Sequencer.Track {
        scoreView.scoreTrackItem?.updateNotewaveDic()
        return .init(scoreTrackItems: scoreView.scoreTrackItem != nil ? [scoreView.scoreTrackItem!] : [],
                     pcmTrackItems: contentsView.elementViews.compactMap { $0.pcmTrackItem })
    }
    
    func spectrogramNode(at p: Point) -> (node: Node, contentView: SheetContentView)? {
        for contentView in contentsView.elementViews {
            if let nNode = contentView.spectrogramNode(at: contentView.convert(p, from: node)) {
                return (nNode, contentView)
            }
        }
        return nil
    }
    
    func nearestTempo(at p: Point) -> Rational? {
        var minTempo: Rational?, minDS = Double.infinity
        
        if scoreView.model.enabled {
            let ds = scoreView.transformedTimelineFrame?.distanceSquared(p) ?? 0
            if ds < minDS {
                minTempo = scoreView.model.tempo
                minDS = ds
            }
        }
        
        for contentView in contentsView.elementViews {
            guard let tempo = contentView.model.timeOption?.tempo else { continue }
            let ds = contentView.transformedTimelineFrame?.distanceSquared(p) ?? 0
            if ds < minDS {
                minTempo = tempo
                minDS = ds
            }
        }
        for textView in textsView.elementViews {
            guard let tempo = textView.model.timeOption?.tempo else { continue }
            let ds = textView.transformedTimelineFrame?.distanceSquared(p) ?? 0
            if ds < minDS {
                minTempo = tempo
                minDS = ds
            }
        }
        if animationView.model.enabled {
            let ds = animationView.transformedPaddingTimelineBounds?.distanceSquared(p) ?? 0
            if ds < minDS {
                minTempo = animationView.model.tempo
                minDS = ds
            }
        }
        return minTempo
    }
    
    func clearHistory() {
        history.reset()
        binder.enableWrite()
    }
    
    func set(_ colorValue: ColorValue) {
        if !colorValue.planeIndexes.isEmpty {
            var picture = model.picture
            for pi in colorValue.planeIndexes {
                picture.planes[pi].uuColor = colorValue.uuColor
            }
            binder.value.picture = picture
            for pi in colorValue.planeIndexes {
                planesView.elementViews[pi].updateColor()
            }
        } else if !colorValue.planeAnimationIndexes.isEmpty {
            var keyframes = model.animation.keyframes
            if colorValue.animationColors.count == colorValue.planeAnimationIndexes.count {
                for (ki, v) in colorValue.planeAnimationIndexes.enumerated() {
                    let uuColor = UUColor(colorValue.animationColors[ki],
                                          id: colorValue.uuColor.id)
                    for i in v.value {
                        keyframes[v.index].picture.planes[i]
                            .uuColor = uuColor
                    }
                }
            } else {
                for v in colorValue.planeAnimationIndexes {
                    for i in v.value {
                        keyframes[v.index].picture.planes[i].uuColor = colorValue.uuColor
                    }
                }
            }
            binder.value.animation.keyframes = keyframes
            for v in colorValue.planeAnimationIndexes {
                for i in v.value {
                    animationView.elementViews[v.index].planesView.elementViews[i].updateColor()
                }
            }
        }
        
        if !colorValue.lineIndexes.isEmpty {
            var picture = model.picture
            for li in colorValue.lineIndexes {
                picture.lines[li].uuColor = colorValue.uuColor
            }
            binder.value.picture = picture
            for li in colorValue.lineIndexes {
                linesView.elementViews[li].updateColor()
            }
        } else if !colorValue.lineAnimationIndexes.isEmpty {
            var keyframes = model.animation.keyframes
            if colorValue.animationColors.count == colorValue.lineAnimationIndexes.count {
                for (ki, v) in colorValue.lineAnimationIndexes.enumerated() {
                    let uuColor = UUColor(colorValue.animationColors[ki],
                                          id: colorValue.uuColor.id)
                    for i in v.value {
                        keyframes[v.index].picture.lines[i]
                            .uuColor = uuColor
                    }
                }
            } else {
                for v in colorValue.lineAnimationIndexes {
                    for i in v.value {
                        keyframes[v.index].picture.lines[i].uuColor = colorValue.uuColor
                    }
                }
            }
            binder.value.animation.keyframes = keyframes
            for v in colorValue.lineAnimationIndexes {
                for i in v.value {
                    animationView.elementViews[v.index].linesView.elementViews[i].updateColor()
                }
            }
        }
        
        if colorValue.isBackground {
            backgroundUUColor = colorValue.uuColor
        }
    }
    func colorPathValue(with colorValue: ColorValue,
                        toColor: Color?,
                        color: Color, subColor: Color) -> ColorPathValue {
        if !colorValue.planeIndexes.isEmpty {
            var paths = colorValue.planeIndexes.map {
                planesView.elementViews[$0].node.path * node.localTransform
            }
            if colorValue.isBackground, let b = node.bounds {
                let path = Path([Pathline(b)]) * node.localTransform
                paths.append(path)
            }
            if let toColor = toColor {
                return ColorPathValue(paths: paths,
                                      lineType: .color(color),
                                      fillType: .color(subColor + toColor))
            } else {
                return ColorPathValue(paths: paths,
                                      lineType: .color(color),
                                      fillType: .color(subColor))
            }
        } else if !colorValue.planeAnimationIndexes.isEmpty {
            var paths = [Path]()
            for v in colorValue.planeAnimationIndexes {
                if v.index == model.animation.index {
                    let planes = model.animation.keyframes[v.index].picture.planes
                    for i in v.value {
                        let path = planes[i].node.path * node.localTransform
                        paths.append(path)
                    }
                }
            }
            if colorValue.isBackground, let b = node.bounds {
                let path = Path([Pathline(b)]) * node.localTransform
                paths.append(path)
            }
            if let toColor = toColor {
                return ColorPathValue(paths: paths,
                                      lineType: .color(color),
                                      fillType: .color(subColor + toColor))
            } else {
                return ColorPathValue(paths: paths,
                                      lineType: .color(color),
                                      fillType: .color(subColor))
            }
        } else if colorValue.isBackground, let b = node.bounds {
            let path = Path([Pathline(b)]) * node.localTransform
            if let toColor = toColor {
                return ColorPathValue(paths: [path],
                                      lineType: .color(color),
                                      fillType: .color(subColor + toColor))
            } else {
                return ColorPathValue(paths: [path],
                                      lineType: .color(color),
                                      fillType: .color(subColor))
            }
        } else {
            return ColorPathValue(paths: [], lineType: nil, fillType: nil)
        }
    }
    
    func removeAll() {
        guard !model.picture.isEmpty
                || !model.draftPicture.isEmpty
                || !model.texts.isEmpty else { return }
        newUndoGroup()
        if !model.picture.isEmpty {
            set(Picture())
        }
        if !model.draftPicture.isEmpty {
            removeDraft()
        }
        if !model.texts.isEmpty {
            removeText(at: Array(0 ..< model.texts.count))
        }
    }
    
    func plane(at p: Point) -> Plane? {
        if let pi = planesView.firstIndex(at: p) {
            return model.picture.planes[pi]
        } else {
            return nil
        }
    }
    func sheetColorOwner(at p: Point,
                         removingUUColor: UUColor? = Line.defaultUUColor,
                         scale: Double) -> (isLine: Bool, value: SheetColorOwner) {
        if let (lineView, li) = lineTuple(at: p,
                                          enabledPlane: true, removingUUColor: removingUUColor,
                                          scale: scale) {
            let uuColor = lineView.model.uuColor
            
            if model.enabledAnimation {
                if !selectedFrameIndexes.isEmpty {
                    return (true, sheetColorOwnerFromAnimation(with: uuColor, isLine: true))
                } else {
                    let cv = ColorValue(uuColor: uuColor,
                                        planeIndexes: [], lineIndexes: [],
                                        isBackground: false,
                                        planeAnimationIndexes: [],
                                        lineAnimationIndexes: [IndexValue(value: [li],
                                                               index: model.animation.index)],
                                        animationColors: [])
                    return (true, SheetColorOwner(sheetView: self, colorValue: cv))
                }
            } else {
                let cv = ColorValue(uuColor: uuColor,
                                    planeIndexes: [],
                                    lineIndexes: [li],
                                    isBackground: false,
                                    planeAnimationIndexes: [],
                                    lineAnimationIndexes: [],
                                    animationColors: [])
                return (true, SheetColorOwner(sheetView: self, colorValue: cv))
            }
        } else {
            return (false, sheetColorOwnerFromPlane(at: p))
        }
    }
    func sheetColorOwnerFromAnimation(with uuColor: UUColor,
                                      isLine: Bool = false) -> SheetColorOwner {
        let planeValue: [IndexValue<[Int]>] = !isLine ? [] : selectedFrameIndexes.compactMap {
            let pis = animationView.elementViews[$0].planesView.elementViews.enumerated().filter { $0.element.model.uuColor == uuColor }
                .map { $0.offset }
            if pis.isEmpty {
                return nil
            } else {
                return IndexValue(value: pis, index: $0)
            }
        }
        let lineValue: [IndexValue<[Int]>] = selectedFrameIndexes.compactMap {
            let lis = animationView.elementViews[$0].linesView.elementViews.enumerated().filter { $0.element.model.uuColor == uuColor }
                .map { $0.offset }
            if lis.isEmpty {
                return nil
            } else {
                return IndexValue(value: lis, index: $0)
            }
        }
        let cv = ColorValue(uuColor: uuColor,
                            planeIndexes: [], lineIndexes: [],
                            isBackground: false,
                            planeAnimationIndexes: planeValue,
                            lineAnimationIndexes: lineValue,
                            animationColors: [])
        return SheetColorOwner(sheetView: self, colorValue: cv)
    }
    func sheetColorOwnerFromPlane(at p: Point) -> SheetColorOwner {
        if let pi = planesView.firstIndex(at: p) {
            if model.enabledAnimation {
                if !selectedFrameIndexes.isEmpty {
                    let uuColor = model.picture.planes[pi].uuColor
                    return sheetColorOwnerFromAnimation(with: uuColor)
                } else {
                    let cv = ColorValue(uuColor: model.picture.planes[pi].uuColor,
                                        planeIndexes: [], lineIndexes: [],
                                        isBackground: false,
                                        planeAnimationIndexes: [IndexValue(value: [pi],
                                                           index: model.animation.index)],
                                        lineAnimationIndexes: [],
                                        animationColors: [])
                    return SheetColorOwner(sheetView: self, colorValue: cv)
                }
            } else {
                let cv = ColorValue(uuColor: model.picture.planes[pi].uuColor,
                                    planeIndexes: [pi], lineIndexes: [],
                                    isBackground: false,
                                    planeAnimationIndexes: [], lineAnimationIndexes: [],
                                    animationColors: [])
                return SheetColorOwner(sheetView: self, colorValue: cv)
            }
        } else {
            let cv = ColorValue(uuColor: model.backgroundUUColor,
                                planeIndexes: [], lineIndexes: [],
                                isBackground: true,
                                planeAnimationIndexes: [], lineAnimationIndexes: [],
                                animationColors: [])
            return SheetColorOwner(sheetView: self, colorValue: cv)
        }
    }
    func sheetColorOwner(at r: Rect,
                         isLine: Bool = false) -> [SheetColorOwner] {
        if isLine {
            let liDic = linesView.elementViews.enumerated().reduce(into: [UUColor: [Int]]()) {
                if $1.element.intersects(r) {
                    let uuColor = $1.element.model.uuColor
                    if $0[uuColor] != nil {
                        $0[uuColor]?.append($1.offset)
                    } else {
                        $0[uuColor] = [$1.offset]
                    }
                }
            }
            return liDic.map {
                if model.enabledAnimation {
                    let cv = ColorValue(uuColor: $0.key,
                                        planeIndexes: [], lineIndexes: [],
                                        isBackground: false,
                                        planeAnimationIndexes: [],
                                        lineAnimationIndexes: [IndexValue(value: $0.value,
                                                           index: model.animation.index)],
                                        animationColors: [])
                    return SheetColorOwner(sheetView: self, colorValue: cv)
                } else {
                    let cv = ColorValue(uuColor: $0.key,
                                        planeIndexes: [],
                                        lineIndexes: $0.value,
                                        isBackground: false,
                                        planeAnimationIndexes: [],
                                        lineAnimationIndexes: [],
                                        animationColors: [])
                    return SheetColorOwner(sheetView: self, colorValue: cv)
                }
            }
        } else {
            let piDic = planesView.elementViews.enumerated().reduce(into: [UUColor: [Int]]()) {
                if $1.element.node.path.intersects(r) {
                    let uuColor = $1.element.model.uuColor
                    if $0[uuColor] != nil {
                        $0[uuColor]?.append($1.offset)
                    } else {
                        $0[uuColor] = [$1.offset]
                    }
                }
            }
            return piDic.map {
                if model.enabledAnimation {
                    let cv = ColorValue(uuColor: $0.key,
                                        planeIndexes: [], lineIndexes: [],
                                        isBackground: false,
                                        planeAnimationIndexes: [IndexValue(value: $0.value,
                                                           index: model.animation.index)],
                                        lineAnimationIndexes: [],
                                        animationColors: [])
                    return SheetColorOwner(sheetView: self, colorValue: cv)
                } else {
                    let cv = ColorValue(uuColor: $0.key,
                                        planeIndexes: $0.value,
                                        lineIndexes: [],
                                        isBackground: false,
                                        planeAnimationIndexes: [], lineAnimationIndexes: [],
                                        animationColors: [])
                    return SheetColorOwner(sheetView: self, colorValue: cv)
                }
            }
        }
    }
    func sheetColorOwner(with uuColor: UUColor) -> SheetColorOwner? {
        if model.enabledAnimation {
            let iivs: [IndexValue<[Int]>] = model.animation.keyframes.enumerated().compactMap { (i, kf) in
                let planeIndexes = kf.picture.planes.enumerated().compactMap {
                    $0.element.uuColor == uuColor ? $0.offset : nil
                }
                if planeIndexes.isEmpty {
                    return nil
                } else {
                    return IndexValue(value: planeIndexes, index: i)
                }
            }
            let liivs: [IndexValue<[Int]>] = model.animation.keyframes.enumerated().compactMap { (i, kf) in
                let lineIndexes = kf.picture.lines.enumerated().compactMap {
                    $0.element.uuColor == uuColor ? $0.offset : nil
                }
                if lineIndexes.isEmpty {
                    return nil
                } else {
                    return IndexValue(value: lineIndexes, index: i)
                }
            }
            let isBackground = model.backgroundUUColor == uuColor
            guard !iivs.isEmpty || !liivs.isEmpty || isBackground else {
                return nil
            }
            let cv = ColorValue(uuColor: uuColor,
                                planeIndexes: [], lineIndexes: [],
                                isBackground: isBackground,
                                planeAnimationIndexes: iivs, lineAnimationIndexes: liivs,
                                animationColors: [])
            return SheetColorOwner(sheetView: self, colorValue: cv)
        } else {
            let planeIndexes = model.picture.planes.enumerated().compactMap {
                $0.element.uuColor == uuColor ? $0.offset : nil
            }
            let lineIndexes = model.picture.lines.enumerated().compactMap {
                $0.element.uuColor == uuColor ? $0.offset : nil
            }
            let isBackground = model.backgroundUUColor == uuColor
            guard !planeIndexes.isEmpty || !lineIndexes.isEmpty || isBackground else {
                return nil
            }
            let cv = ColorValue(uuColor: uuColor,
                                planeIndexes: planeIndexes,
                                lineIndexes: lineIndexes,
                                isBackground: isBackground,
                                planeAnimationIndexes: [], lineAnimationIndexes: [],
                                animationColors: [])
            return SheetColorOwner(sheetView: self, colorValue: cv)
        }
    }
    
    func newUndoGroup(enabledKeyframeIndex: Bool = true) {
        if enabledKeyframeIndex && model.enabledAnimation {
            history.newUndoGroup(firstItem: .setRootKeyframeIndex(rootKeyframeIndex: rootKeyframeIndex))
        } else {
            history.newUndoGroup()
        }
    }
    
    private func append(undo undoItem: SheetUndoItem,
                        redo redoItem: SheetUndoItem) {
        history.append(undo: undoItem, redo: redoItem)
    }
    @discardableResult
    func set(_ item: SheetUndoItem,
             isMakeRect: Bool = false) -> (rect: Rect?, nodes: [Node]) {
        selectedTextView = nil
        switch item {
        case .appendLine(let line):
            stop()
            let lineView = appendNode(line)
            animationView.updateTimelineAtCurrentKeyframe()
            if isMakeRect {
                return (lineView.node.bounds, [])
            }
        case .appendLines(let lines):
            stop()
            appendNode(lines)
            animationView.updateTimelineAtCurrentKeyframe()
            if isMakeRect {
                let rect = linesView.elementViews[(linesView.elementViews.count - lines.count)...]
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
                return (rect, [])
            }
        case .appendPlanes(let planes):
            stop()
            appendNode(planes)
            if isMakeRect {
                let rect = planesView.elementViews[(planesView.elementViews.count - planes.count)...]
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
                return (rect, [])
            }
        case .removeLastLines(let count):
            stop()
            if isMakeRect {
                let rect = linesView.elementViews[(linesView.elementViews.count - count)...]
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
                removeLastsLineNode(count: count)
                animationView.updateTimelineAtCurrentKeyframe()
                return (rect, [])
            } else {
                removeLastsLineNode(count: count)
                animationView.updateTimelineAtCurrentKeyframe()
            }
        case .removeLastPlanes(let count):
            stop()
            if isMakeRect {
                let rect = planesView.elementViews[(planesView.elementViews.count - count)...]
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
                removeLastsPlaneNode(count: count)
                return (rect, [])
            } else {
                removeLastsPlaneNode(count: count)
            }
        case .insertLines(let livs):
            stop()
            insertNode(livs)
            
            animationView.updateTimelineAtCurrentKeyframe()
            if isMakeRect {
                let rect = livs.reduce(into: Rect?.none) {
                    $0 += linesView.elementViews[$1.index].node.bounds
                }
                return (rect, [])
            }
        case .insertPlanes(let pivs):
            stop()
            insertNode(pivs)
            if isMakeRect {
                let rect = pivs.reduce(into: Rect?.none) {
                    $0 += planesView.elementViews[$1.index].node.bounds
                }
                return (rect, [])
            }
        case .removeLines(let lineIndexes):
            stop()
            if isMakeRect {
                let rect = lineIndexes.reduce(into: Rect?.none) {
                    $0 += linesView.elementViews[$1].node.bounds
                }
                removeLinesNode(at: lineIndexes)
                animationView.updateTimelineAtCurrentKeyframe()
                return (rect, [])
            } else {
                removeLinesNode(at: lineIndexes)
                animationView.updateTimelineAtCurrentKeyframe()
            }
        case .removePlanes(let planeIndexes):
            stop()
            if isMakeRect {
                let rect = planeIndexes.reduce(into: Rect?.none) {
                    $0 += planesView.elementViews[$1].node.bounds
                }
                removePlanesNode(at: planeIndexes)
                return (rect, [])
            } else {
                removePlanesNode(at: planeIndexes)
            }
        case .setPlaneValue(let planeValue):
            stop()
            let planeIndexes = planeValue.moveIndexValues.map {
                IndexValue(value: planesView.elementViews[$0.value].model, index: $0.index)
            }
            setNode(planeValue.planes)
            if isMakeRect {
                let rect = planesView.elementViews
                    .reduce(into: Rect?.none) { $0 += $1.node.bounds }
                insertNode(planeIndexes)
                return (rect, [])
            } else {
                insertNode(planeIndexes)
            }
        case .changeToDraft(let isReverse):
            stop()
            if isReverse {
                if linesView.model.isEmpty && planesView.model.isEmpty {
                    setNode(draftLinesView.model)
                    setDraftNode([Line]())
                    setNode(draftPlanesView.model)
                    setDraftNode([Plane]())
                }
            } else {
                if draftLinesView.model.isEmpty && draftPlanesView.model.isEmpty {
                    setDraftNode(linesView.model)
                    setNode([Line]())
                    setDraftNode(planesView.model)
                    setNode([Plane]())
                }
            }
            updateTimeline()
            if isMakeRect {
                return (node.bounds, [])
            }
        case .setPicture(let picture):
            stop()
            setNode(picture.lines)
            setNode(picture.planes)
            animationView.updateTimelineAtCurrentKeyframe()
            if isMakeRect {
                return (node.bounds, [])
            }
        case .insertDraftLines(let livs):
            stop()
            insertDraftNode(livs)
            updateTimeline()
            if isMakeRect {
                let rect = livs.reduce(into: Rect?.none) {
                    $0 += draftLinesView.elementViews[$1.index].node.bounds
                }
                return (rect, [])
            }
        case .insertDraftPlanes(let pivs):
            stop()
            insertDraftNode(pivs)
            updateTimeline()
            if isMakeRect {
                let rect = pivs.reduce(into: Rect?.none) {
                    $0 += draftPlanesView.elementViews[$1.index].node.bounds
                }
                return (rect, [])
            }
        case .removeDraftLines(let lineIndexes):
            stop()
            if isMakeRect {
                let rect = lineIndexes.reduce(into: Rect?.none) {
                    $0 += draftLinesView.elementViews[$1].node.bounds
                }
                removeDraftLinesNode(at: lineIndexes)
                updateTimeline()
                return (rect, [])
            } else {
                removeDraftLinesNode(at: lineIndexes)
                updateTimeline()
            }
        case .removeDraftPlanes(let planeIndexes):
            stop()
            if isMakeRect {
                let rect = planeIndexes.reduce(into: Rect?.none) {
                    $0 += draftPlanesView.elementViews[$1].node.bounds
                }
                removeDraftPlanesNode(at: planeIndexes)
                updateTimeline()
                return (rect, [])
            } else {
                removeDraftPlanesNode(at: planeIndexes)
                updateTimeline()
            }
        case .setDraftPicture(let picture):
            stop()
            setDraftNode(picture.lines)
            setDraftNode(picture.planes)
            updateTimeline()
            if isMakeRect {
                return (node.bounds, [])
            }
        case .insertTexts(let tivs):
            insertNode(tivs)
            
            if isPlaying ? tivs.contains(where: { $0.value.timeOption != nil }) : false {
                updateCaption()
            }
            
            tivs.forEach { textsView.elementViews[$0.index].updateClippingNode() }
            
            if isMakeRect {
                let rect = tivs.reduce(into: Rect?.none) {
                    $0 += textsView.elementViews[$1.index].transformedBounds
                }
                return (rect, [])
            }
        case .removeTexts(let textIndexes):
            let isUpdateCaption = isPlaying ?
            textIndexes.contains(where: { textsView.elementViews[$0].model.timeOption != nil }) : false
            
            if isMakeRect {
                let rect = textIndexes.reduce(into: Rect?.none) {
                    $0 += textsView.elementViews[$1].transformedBounds
                }
                removeTextsNode(at: textIndexes)
                
                if isUpdateCaption {
                    updateCaption()
                }
                
                return (rect, [])
            } else {
                removeTextsNode(at: textIndexes)
                
                if isUpdateCaption {
                    updateCaption()
                }
            }
        case .replaceString(let ituv):
            if isMakeRect {
                let textView = textsView.elementViews[ituv.index]
                let firstRect: Rect?
                if ituv.value.origin != nil || ituv.value.size != nil {
                    firstRect = textView.transformedBounds
                } else {
                    let fRange = textView.model.string
                        .range(fromInt: ituv.value.replacedRange)
                    firstRect = textView
                        .transformedTypoBounds(with: fRange)
                }
                setNode(ituv)
                let lastRect: Rect?
                if ituv.value.origin != nil || ituv.value.size != nil {
                    lastRect = textView.transformedBounds
                } else {
                    let nRange = textView.model.string
                        .range(fromInt: ituv.value.newRange)
                    lastRect = textView
                        .transformedTypoBounds(with: nRange)
                }
                selectedTextView = textView
                
                if isPlaying ? textView.model.timeOption != nil : false {
                    updateCaption()
                }
                
                return (firstRect + lastRect, [])
            } else {
                setNode(ituv)
                
                let textView = textsView.elementViews[ituv.index]
                if isPlaying ? textView.model.timeOption != nil : false {
                    updateCaption()
                }
                
                selectedTextView = textsView.elementViews[ituv.index]
            }
        case .changedColors(let colorValue):
            changeColorsNode(colorValue)
            
            if isMakeRect {
                let rect = colorValue.planeIndexes.reduce(into: Rect?.none) {
                    $0 += planesView.elementViews[$1].node.bounds
                } + colorValue.lineIndexes.reduce(into: Rect?.none) {
                    $0 += linesView.elementViews[$1].node.bounds
                }
                return (rect, [])
            }
        case .insertBorders(let bivs):
            insertNode(bivs)
            if isMakeRect {
                let rect = bivs.reduce(into: Rect?.none) {
                    let borderView = bordersView.elementViews[$1.index]
                    $0 += borderView.node.bounds?.inset(by: -borderView.node.lineWidth)
                }
                return (rect, [])
            }
        case .removeBorders(let borderIndexes):
            if isMakeRect {
                let rect = borderIndexes.reduce(into: Rect?.none) {
                    let borderView = bordersView.elementViews[$1]
                    $0 += borderView.node.bounds?.inset(by: -borderView.node.lineWidth)
                }
                removeBordersNode(at: borderIndexes)
                return (rect, [])
            } else {
                removeBordersNode(at: borderIndexes)
            }
        case .setRootKeyframeIndex(let rootKeyframeIndex):
            stop()
            if model.animation.rootIndex != rootKeyframeIndex {
                binder[keyPath: keyPath].animation.rootIndex = rootKeyframeIndex
                updateWithKeyframeIndex()
                updateTimeline()
                node.draw()
                Sleep.start(atTime: 0.04)
            }
        case .insertKeyframes(let kivs):
            stop()
            if !kivs.isEmpty {
                animationView.insert(kivs)
                
                var sfis = animationView.selectedFrameIndexes
                for i in 0 ..< sfis.count {
                    for kiv in kivs {
                        if sfis[i] > kiv.index {
                            sfis[i] += 1
                        }
                    }
                }
                animationView.selectedFrameIndexes = sfis
                
                binder[keyPath: keyPath].animation.rootIndex = kivs.last?.index ?? 0
                
                updateWithKeyframeIndex()
                updateTimeline()
                if isMakeRect {
                    let rect = kivs.reduce(into: Rect?.none) {
                        $0 += animationView.transformedKeyframeBounds(at: $1.index)
                    }
                    return (rect, [])
                }
            }
        case .removeKeyframes(let indexes):
            stop()
            if !indexes.isEmpty {
                let rect = isMakeRect ? indexes.reduce(into: Rect?.none) {
                    $0 += animationView.transformedKeyframeBounds(at: $1)
                } : Rect?.none
                
                var sfis = animationView.selectedFrameIndexes
                for i in 0 ..< sfis.count {
                    for ni in indexes {
                        if sfis[i] > ni {
                            sfis[i] -= 1
                        }
                    }
                }
                animationView.selectedFrameIndexes = sfis
                
                animationView.remove(at: indexes)
                
                binder[keyPath: keyPath].animation
                    .rootIndex = (indexes.first ?? 0) - 1
                
                updateWithKeyframeIndex()
                updateTimeline()
                if isMakeRect {
                    return (rect, [])
                }
            }
        case .setKeyframeOptions(let koivs):
            stop()
            
            let rootBI = model.animation.rootBeatIndex
            
            binder[keyPath: keyPath].animation.set(koivs)
            
            if model.animation.rootBeatIndex != rootBI {
                binder[keyPath: keyPath].animation.rootBeatIndex = rootBI
            }
            
            updateTimeline()
            updatePreviousNext()
            
            if isMakeRect {
                let rect = koivs.reduce(into: Rect?.none) {
                    $0 += animationView.transformedKeyframeBounds(at: $1.index)
                }
                return (rect, [])
            }
            
        case .insertKeyLines(let kvs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                let lw = Line.defaultLineWidth * 1.5
                for kv in kvs {
                    animationView.elementViews[kv.index].linesView.insert(kv.value)
                    
                    rect += kv.value.reduce(into: Rect?.none) {
                        let line = binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.lines[$1.index]
                        $0 += line.bounds
                        
                        nodes.append(Node(path: Path(line),
                                          lineWidth: lw,
                                          lineType: .color(.selected)))
                    }
                }
                updateWithKeyframeIndex()
                updateTimeline()
                return (rect, nodes)
            } else {
                for kv in kvs {
                    animationView.elementViews[kv.index].linesView.insert(kv.value)
                }
                updateWithKeyframeIndex()
                updateTimeline()
            }
        case .replaceKeyLines(let kvs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                let lw = Line.defaultLineWidth * 1.5
                for kv in kvs {
                    for liv in kv.value {
                        binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.lines[liv.index] = liv.value
                        animationView.elementViews[kv.index].linesView.elementViews[liv.index].updateWithModel()
                    }
                    
                    rect += kv.value.reduce(into: Rect?.none) {
                        let line = binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.lines[$1.index]
                        $0 += line.bounds
                        
                        nodes.append(Node(path: Path(line),
                                          lineWidth: lw,
                                          lineType: .color(.selected)))
                    }
                }
                updateWithKeyframeIndex()
                updateTimeline()
                return (rect, nodes)
            } else {
                for kv in kvs {
                    for liv in kv.value {
                        binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.lines[liv.index] = liv.value
                        animationView.elementViews[kv.index].linesView.elementViews[liv.index].updateWithModel()
                    }
                }
                updateWithKeyframeIndex()
                updateTimeline()
            }
        case .removeKeyLines(let iivs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                let lw = Line.defaultLineWidth * 1.5
                for iv in iivs {
                    rect += iv.value.reduce(into: Rect?.none) {
                        let line = binder[keyPath: keyPath].animation.keyframes[iv.index]
                            .picture.lines[$1]
                        $0 += line.bounds
                        
                        nodes.append(Node(path: Path(line),
                                          lineWidth: lw,
                                          lineType: .color(.removing)))
                    }
                    
                    animationView.elementViews[iv.index].linesView.remove(at: iv.value)
                }
                updateWithKeyframeIndex()
                updateTimeline()
                
                return (rect, nodes)
            } else {
                for iv in iivs {
                    animationView.elementViews[iv.index].linesView.remove(at: iv.value)
                }
                updateWithKeyframeIndex()
                updateTimeline()
            }
            
        case .insertKeyPlanes(let kvs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                for kv in kvs {
                    animationView.elementViews[kv.index].planesView.insert(kv.value)
                    
                    rect += kv.value.reduce(into: Rect?.none) {
                        let plane = binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.planes[$1.index]
                        $0 += plane.bounds
                        nodes.append(plane.node(from: .selected))
                    }
                }
                updateWithKeyframeIndex()
                return (rect, nodes)
            } else {
                for kv in kvs {
                    animationView.elementViews[kv.index].planesView.insert(kv.value)
                }
                updateWithKeyframeIndex()
            }
        case .replaceKeyPlanes(let kvs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                for kv in kvs {
                    for liv in kv.value {
                        binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.planes[liv.index] = liv.value
                        animationView.elementViews[kv.index].planesView.elementViews[liv.index].updateWithModel()
                    }
                    
                    rect += kv.value.reduce(into: Rect?.none) {
                        let plane = binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.planes[$1.index]
                        $0 += plane.bounds
                        nodes.append(plane.node(from: .selected))
                    }
                }
                updateWithKeyframeIndex()
                updateTimeline()
                return (rect, nodes)
            } else {
                for kv in kvs {
                    for piv in kv.value {
                        binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.planes[piv.index] = piv.value
                        animationView.elementViews[kv.index].planesView.elementViews[piv.index].updateWithModel()
                    }
                }
                updateWithKeyframeIndex()
                updateTimeline()
            }
        case .removeKeyPlanes(let iivs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                for iv in iivs {
                    rect += iv.value.reduce(into: Rect?.none) {
                        let plane = binder[keyPath: keyPath].animation.keyframes[iv.index]
                            .picture.planes[$1]
                        $0 += plane.bounds
                        nodes.append(plane.node(from: .removing))
                    }
                    
                    animationView.elementViews[iv.index].planesView.remove(at: iv.value)
                }
                updateWithKeyframeIndex()
                
                return (rect, nodes)
            } else {
                for iv in iivs {
                    animationView.elementViews[iv.index].planesView.remove(at: iv.value)
                }
                updateWithKeyframeIndex()
            }
            
        case .insertDraftKeyLines(let kvs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                let lw = Line.defaultLineWidth * 1.5
                for kv in kvs {
                    animationView.elementViews[kv.index].draftLinesView.insert(kv.value)
                    updateDraftLines(from: kv.value.map { $0.index },
                                     atKeyframeIndex: kv.index)
                    
                    rect += kv.value.reduce(into: Rect?.none) {
                        let line = binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .draftPicture.lines[$1.index]
                        $0 += line.bounds
                        
                        nodes.append(Node(path: Path(line),
                                          lineWidth: lw,
                                          lineType: .color(.selected)))
                    }
                }
                updateWithKeyframeIndex()
                return (rect, nodes)
            } else {
                for kv in kvs {
                    animationView.elementViews[kv.index].draftLinesView.insert(kv.value)
                    updateDraftLines(from: kv.value.map { $0.index },
                                     atKeyframeIndex: kv.index)
                }
                updateWithKeyframeIndex()
            }
        case .removeDraftKeyLines(let iivs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                let lw = Line.defaultLineWidth * 1.5
                for iv in iivs {
                    rect += iv.value.reduce(into: Rect?.none) {
                        let line = binder[keyPath: keyPath].animation.keyframes[iv.index]
                            .draftPicture.lines[$1]
                        $0 += line.bounds
                        
                        nodes.append(Node(path: Path(line),
                                          lineWidth: lw,
                                          lineType: .color(.removing)))
                    }
                    
                    animationView.elementViews[iv.index].draftLinesView.remove(at: iv.value)
                }
                updateWithKeyframeIndex()
                
                return (rect, nodes)
            } else {
                for iv in iivs {
                    animationView.elementViews[iv.index].draftLinesView.remove(at: iv.value)
                }
                updateWithKeyframeIndex()
            }
            
        case .insertDraftKeyPlanes(let kvs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                for kv in kvs {
                    animationView.elementViews[kv.index].draftPlanesView.insert(kv.value)
                    updateDraftPlanes(from: kv.value.map { $0.index },
                                      atKeyframeIndex: kv.index)
                    
                    rect += kv.value.reduce(into: Rect?.none) {
                        let plane = binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .draftPicture.planes[$1.index]
                        $0 += plane.bounds
                        nodes.append(plane.node(from: .selected))
                    }
                }
                updateWithKeyframeIndex()
                return (rect, nodes)
            } else {
                for kv in kvs {
                    animationView.elementViews[kv.index].draftPlanesView.insert(kv.value)
                    updateDraftPlanes(from: kv.value.map { $0.index },
                                      atKeyframeIndex: kv.index)
                }
                updateWithKeyframeIndex()
            }
        case .removeDraftKeyPlanes(let iivs):
            stop()
            if isMakeRect {
                var rect: Rect?, nodes = [Node]()
                for iv in iivs {
                    rect += iv.value.reduce(into: Rect?.none) {
                        let plane = binder[keyPath: keyPath].animation.keyframes[iv.index]
                            .draftPicture.planes[$1]
                        $0 += plane.bounds
                        nodes.append(plane.node(from: .removing))
                    }
                    
                    animationView.elementViews[iv.index].draftPlanesView.remove(at: iv.value)
                }
                updateWithKeyframeIndex()
                
                return (rect, nodes)
            } else {
                for iv in iivs {
                    animationView.elementViews[iv.index].draftPlanesView.remove(at: iv.value)
                }
                updateWithKeyframeIndex()
            }
            
        case .setLineIDs(let kvs):
            stop()
            if isMakeRect {
                for kv in kvs {
                    for iov in kv.value {
                        binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.lines[iov.index].interOption = iov.value
                    }
                }
                
                let idSet = Set(kvs.flatMap { $0.value.map { $0.value.id } })
                let lw = Line.defaultLineWidth * 1.5
                var nodes = [Node]()
                for keyframe in model.animation.keyframes {
                    for line in keyframe.picture.lines {
                        if idSet.contains(line.id) {
                            nodes.append(Node(path: Path(line),
                                              lineWidth: lw,
                                              lineType: .color(.selected)))
                        }
                    }
                }
                
                updateTimeline()
                
                let rect = kvs.reduce(into: Rect?.none) { (n, kv) in
                    n += kv.value.reduce(into: Rect?.none) {
                        $0 += binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.lines[$1.index].bounds
                    }
                }
                return (rect, nodes)
            } else {
                for kv in kvs {
                    for iov in kv.value {
                        binder[keyPath: keyPath].animation.keyframes[kv.index]
                            .picture.lines[iov.index].interOption = iov.value
                    }
                }
            }
        case .setAnimationOption(let option):
            stop()
            binder[keyPath: keyPath].animation.option = option
            updateTimeline()
            updatePreviousNext()
            if isMakeRect {
                return (animationView.transformedPaddingTimelineBounds ?? node.bounds, [])
            }
        case .insertNotes(let nivs):
            stop()
            insertNode(nivs)
            if isMakeRect {
                let rect = nivs.reduce(into: Rect?.none) {
                    $0 += scoreView.transformedNoteFrame(at: $1.index)
                }
                return (rect, [])
            }
        case .replaceNotes(let nivs):
            stop()
            if isMakeRect {
                var rect: Rect?
                for niv in nivs {
                    rect += scoreView.transformedNoteFrame(at: niv.index)
                }
                replaceNode(nivs)
                for niv in nivs {
                    rect += scoreView.transformedNoteFrame(at: niv.index)
                }
                return (rect, [])
            } else {
                replaceNode(nivs)
            }
        case .removeNotes(noteIndexes: let noteIndexes):
            stop()
            if isMakeRect {
                let rect = noteIndexes.reduce(into: Rect?.none) {
                    $0 += scoreView.transformedNoteFrame(at: $1)
                }
                removeNotesNode(at: noteIndexes)
                return (rect, [])
            } else {
                removeNotesNode(at: noteIndexes)
            }
        case .insertDraftNotes(let nivs):
            stop()
            insertDraftNode(nivs)
            if isMakeRect {
                let rect = nivs.reduce(into: Rect?.none) {
                    $0 += scoreView.transformedDraftNoteFrame(at: $1.index)
                }
                return (rect, [])
            }
        case .removeDraftNotes(noteIndexes: let noteIndexes):
            stop()
            if isMakeRect {
                let rect = noteIndexes.reduce(into: Rect?.none) {
                    $0 += scoreView.transformedDraftNoteFrame(at: $1)
                }
                removeDraftNotesNode(at: noteIndexes)
                return (rect, [])
            } else {
                removeDraftNotesNode(at: noteIndexes)
            }
        case .insertContents(let civs):
            stop()
            insertNode(civs)
            
            civs.forEach { contentsView.elementViews[$0.index].updateClippingNode() }
            
            if isMakeRect {
                let rect = civs.reduce(into: Rect?.none) {
                    let contentView = contentsView.elementViews[$1.index]
                    $0 += contentView.node.transformedBounds
                }
                return (rect, [])
            }
        case .replaceContents(let civs):
            stop()
            if isMakeRect {
                var rect: Rect?
                for civ in civs {
                    binder[keyPath: keyPath].contents[civ.index] = civ.value
                    contentsView.elementViews[civ.index].updateWithModel()
                    rect += contentsView.elementViews[civ.index].node.transformedBounds
                }
                
                civs.forEach { contentsView.elementViews[$0.index].updateClippingNode() }
                
                return (rect, [])
            } else {
                for civ in civs {
                    binder[keyPath: keyPath].contents[civ.index] = civ.value
                    contentsView.elementViews[civ.index].updateWithModel()
                }
                
                civs.forEach { contentsView.elementViews[$0.index].updateClippingNode() }
            }
        case .removeContents(contentIndexes: let contentIndexes):
            stop()
            if isMakeRect {
                let rect = contentIndexes.reduce(into: Rect?.none) {
                    let contentView = contentsView.elementViews[$1]
                    $0 += contentView.node.transformedBounds
                }
                removeContentsNode(at: contentIndexes)
                return (rect, [])
            } else {
                removeContentsNode(at: contentIndexes)
            }
        case .setScoreOption(let option):
            stop()
            scoreView.option = option
            if isMakeRect {
                return (scoreView.transformedMainFrame, [])
            }
        }
        return (nil, [])
    }
    @discardableResult
    private func appendNode(_ line: Line) -> SheetLineView {
        linesView.append(line)
    }
    private func appendNode(_ lines: [Line]) {
        linesView.append(lines)
    }
    private func appendNode(_ planes: [Plane]) {
        planesView.append(planes)
    }
    private func removeLastsLineNode(count: Int) {
        linesView.removeLasts(count: count)
    }
    private func removeLastsPlaneNode(count: Int) {
        planesView.removeLasts(count: count)
    }
    private func insertNode(_ livs: [IndexValue<Line>]) {
        linesView.insert(livs)
    }
    private func insertNode(_ pivs: [IndexValue<Plane>]) {
        planesView.insert(pivs)
    }
    private func removeLinesNode(at lineIndexes: [Int]) {
        linesView.remove(at: lineIndexes)
    }
    private func removePlanesNode(at planeIndexes: [Int]) {
        planesView.remove(at: planeIndexes)
    }
    private func setNode(_ lines: [Line]) {
        linesView.model = lines
    }
    private func setNode(_ planes: [Plane]) {
        planesView.model = planes
    }
    private func setDraftNode(_ lines: [Line]) {
        draftLinesView.model = lines
        
        if !lines.isEmpty {
            let lineColor = model.draftLinesColor()
            draftLinesView.elementViews.forEach {
                $0.node.lineType = .color(lineColor)
            }
        }
    }
    private func setDraftNode(_ planes: [Plane]) {
        draftPlanesView.model = planes
        
        if !planes.isEmpty {
            let fillColor = model.backgroundUUColor.value
            draftPlanesView.elementViews.forEach {
                $0.node.fillType = .color(Sheet.draftPlaneColor(from: $0.model.uuColor.value,
                                                           fillColor: fillColor))
            }
        }
    }
    private func updateDraftLines(from livs: [Int],
                                  atKeyframeIndex ki: Int) {
        if !livs.isEmpty {
            let lineColor = model.draftLinesColor()
            let draftLinesView = animationView.elementViews[ki].draftLinesView
            livs.forEach {
                draftLinesView.elementViews[$0].node.lineType = .color(lineColor)
            }
        }
    }
    private func updateDraftPlanes(from pivs: [Int],
                                  atKeyframeIndex ki: Int) {
        if !pivs.isEmpty {
            let fillColor = model.backgroundUUColor.value
            let draftPlanesView = animationView.elementViews[ki].draftPlanesView
            pivs.forEach {
                let planeView = draftPlanesView.elementViews[$0]
                planeView.node.fillType = .color(Sheet.draftPlaneColor(from: planeView.model.uuColor.value,
                                                             fillColor: fillColor))
            }
        }
    }
    private func insertDraftNode(_ livs: [IndexValue<Line>]) {
        draftLinesView.insert(livs)
        updateDraftLines(from: livs.map { $0.index },
                         atKeyframeIndex: model.animation.index)
    }
    private func insertDraftNode(_ pivs: [IndexValue<Plane>]) {
        draftPlanesView.insert(pivs)
        updateDraftPlanes(from: pivs.map { $0.index },
                          atKeyframeIndex: model.animation.index)
    }
    private func removeDraftLinesNode(at lineIndexes: [Int]) {
        draftLinesView.remove(at: lineIndexes)
    }
    private func removeDraftPlanesNode(at planeIndexes: [Int]) {
        draftPlanesView.remove(at: planeIndexes)
    }
    private func insertNode(_ tivs: [IndexValue<Text>]) {
        textsView.insert(tivs)
    }
    private func removeTextsNode(at textIndexes: [Int]) {
        textsView.remove(at: textIndexes)
    }
    private func setNode(_ ituv: IndexValue<TextValue>) {
        textsView.elementViews[ituv.index].set(ituv.value)
    }
    
    private func changeColorsNode(_ colorValue: ColorValue) {
        if !colorValue.planeIndexes.isEmpty {
            colorValue.planeIndexes.forEach {
                planesView.elementViews[$0].uuColor = colorValue.uuColor
            }
        } else if !colorValue.planeAnimationIndexes.isEmpty {
            if colorValue.animationColors.count == colorValue.planeAnimationIndexes.count {
                for (ki, v) in colorValue.planeAnimationIndexes.enumerated() {
                    let uuColor = UUColor(colorValue.animationColors[ki],
                                          id: colorValue.uuColor.id)
                    for i in v.value {
                        animationView.elementViews[v.index].planesView.elementViews[i]
                            .uuColor = uuColor
                    }
                }
            } else {
                for v in colorValue.planeAnimationIndexes {
                    for i in v.value {
                        animationView.elementViews[v.index].planesView.elementViews[i].uuColor = colorValue.uuColor
                    }
                }
            }
        }
        
        if !colorValue.lineIndexes.isEmpty {
            colorValue.lineIndexes.forEach {
                linesView.elementViews[$0].uuColor = colorValue.uuColor
            }
        } else if !colorValue.lineAnimationIndexes.isEmpty {
            if colorValue.animationColors.count == colorValue.lineAnimationIndexes.count {
                for (ki, v) in colorValue.lineAnimationIndexes.enumerated() {
                    let uuColor = UUColor(colorValue.animationColors[ki],
                                          id: colorValue.uuColor.id)
                    for i in v.value {
                        animationView.elementViews[v.index].linesView.elementViews[i]
                            .uuColor = uuColor
                    }
                }
            } else {
                for v in colorValue.lineAnimationIndexes {
                    for i in v.value {
                        animationView.elementViews[v.index].linesView.elementViews[i].uuColor = colorValue.uuColor
                    }
                }
            }
        }
        
        if colorValue.isBackground {
            backgroundUUColor = colorValue.uuColor
        }
    }
    
    private func insertNode(_ nivs: [IndexValue<Note>]) {
        scoreView.insert(nivs)
        updateScoreViewFromOtherAround()
    }
    private func replaceNode(_ nivs: [IndexValue<Note>]) {
        scoreView.replace(nivs)
        updateScoreViewFromOtherAround()
    }
    private func removeNotesNode(at noteIndexes: [Int]) {
        scoreView.remove(at: noteIndexes)
        updateScoreViewFromOtherAround()
    }
    
    private func insertDraftNode(_ nivs: [IndexValue<Note>]) {
        scoreView.insertDraft(nivs)
    }
    private func removeDraftNotesNode(at noteIndexes: [Int]) {
        scoreView.removeDraft(at: noteIndexes)
    }
    
    private func insertNode(_ civs: [IndexValue<Content>]) {
        contentsView.insert(civs)
    }
    private func removeContentsNode(at contentIndexes: [Int]) {
        contentsView.remove(at: contentIndexes)
    }
    
    private func insertNode(_ bivs: [IndexValue<Border>]) {
        bordersView.insert(bivs)
        let bounds = self.bounds
        bivs.forEach {
            bordersView.elementViews[$0.index].bounds = bounds
            bordersView.elementViews[$0.index].screenToWorldScale = screenToWorldScale
        }
    }
    private func removeBordersNode(at borderIndexes: [Int]) {
        bordersView.remove(at: borderIndexes)
    }
    
    func append(_ line: Line) {
        let undoItem = SheetUndoItem.removeLastLines(count: 1)
        let redoItem = SheetUndoItem.appendLine(line)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func append(_ lines: [Line]) {
        if lines.count == 1 {
            append(lines[0])
        } else {
            let undoItem = SheetUndoItem.removeLastLines(count: lines.count)
            let redoItem = SheetUndoItem.appendLines(lines)
            append(undo: undoItem, redo: redoItem)
            set(redoItem)
        }
    }
    func append(_ planes: [Plane]) {
        let undoItem = SheetUndoItem.removeLastPlanes(count: planes.count)
        let redoItem = SheetUndoItem.appendPlanes(planes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insert(_ livs: [IndexValue<Line>]) {
        let undoItem = SheetUndoItem.removeLines(lineIndexes: livs.map { $0.index })
        let redoItem = SheetUndoItem.insertLines(livs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insert(_ pivs: [IndexValue<Plane>]) {
        let undoItem = SheetUndoItem.removePlanes(planeIndexes: pivs.map { $0.index })
        let redoItem = SheetUndoItem.insertPlanes(pivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeLines(at lineIndexes: [Int]) {
        let livs = lineIndexes.map {
            IndexValue(value: model.picture.lines[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertLines(livs)
        let redoItem = SheetUndoItem.removeLines(lineIndexes: lineIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removePlanes(at planeIndexes: [Int]) {
        let pivs = planeIndexes.map {
            IndexValue(value: model.picture.planes[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertPlanes(pivs)
        let redoItem = SheetUndoItem.removePlanes(planeIndexes: planeIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func set(_ picture: Picture) {
        let undoItem = SheetUndoItem.setPicture(model.picture)
        let redoItem = SheetUndoItem.setPicture(picture)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func set(_ planeValue: PlaneValue) {
        var isArray = Array(repeating: false, count: model.picture.planes.count)
        for v in planeValue.moveIndexValues {
            isArray[v.value] = true
        }
        let oldPlanes = model.picture.planes.enumerated().compactMap {
            isArray[$0.offset] ? nil : $0.element
        }
        let oldVs = planeValue.moveIndexValues
            .map { IndexValue(value: $0.index, index: $0.value) }
            .sorted { $0.index < $1.index }
        let oldPlaneValue = PlaneValue(planes: oldPlanes, moveIndexValues: oldVs)
        let undoItem = SheetUndoItem.setPlaneValue(oldPlaneValue)
        let redoItem = SheetUndoItem.setPlaneValue(planeValue)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insertDraft(_ livs: [IndexValue<Line>]) {
        let undoItem = SheetUndoItem.removeDraftLines(lineIndexes: livs.map { $0.index })
        let redoItem = SheetUndoItem.insertDraftLines(livs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insertDraft(_ pivs: [IndexValue<Plane>]) {
        let undoItem = SheetUndoItem.removeDraftPlanes(planeIndexes: pivs.map { $0.index })
        let redoItem = SheetUndoItem.insertDraftPlanes(pivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeDraftLines(at lineIndexes: [Int]) {
        let livs = lineIndexes.map {
            IndexValue(value: model.draftPicture.lines[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertDraftLines(livs)
        let redoItem = SheetUndoItem.removeDraftLines(lineIndexes: lineIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeDraftPlanes(at planeIndexes: [Int]) {
        let pivs = planeIndexes.map {
            IndexValue(value: model.draftPicture.planes[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertDraftPlanes(pivs)
        let redoItem = SheetUndoItem.removeDraftPlanes(planeIndexes: planeIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func setDraft(_ draftPicture: Picture) {
        let undoItem = SheetUndoItem.setDraftPicture(model.draftPicture)
        let redoItem = SheetUndoItem.setDraftPicture(draftPicture)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func changeToDraft() {
        if !model.draftPicture.isEmpty {
            removeDraft()
        }
        let undoItem = SheetUndoItem.changeToDraft(isReverse: true)
        let redoItem = SheetUndoItem.changeToDraft(isReverse: false)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeDraft() {
        setDraft(Picture())
    }
    func append(_ text: Text) {
        let undoItem = SheetUndoItem.removeTexts(textIndexes: [model.texts.count])
        let redoItem = SheetUndoItem.insertTexts([IndexValue(value: text,
                                                             index: model.texts.count)])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func append(_ texts: [Text]) {
        let undoItem = SheetUndoItem.removeTexts(textIndexes: Array(model.texts.count ..< (model.texts.count + texts.count)))
        let redoItem = SheetUndoItem.insertTexts(texts.enumerated().map {
            IndexValue(value: $0.element, index: model.texts.count + $0.offset)
        })
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func insert(_ tivs: [IndexValue<Text>]) {
        let undoItem = SheetUndoItem.removeTexts(textIndexes: tivs.map { $0.index })
        let redoItem = SheetUndoItem.insertTexts(tivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeText(at i: Int) {
        let undoItem = SheetUndoItem.insertTexts([IndexValue(value: model.texts[i],
                                                             index: i)])
        let redoItem = SheetUndoItem.removeTexts(textIndexes: [i])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func replace(_ tivs: [IndexValue<Text>]) {
        let ivs = tivs.map { $0.index }
        let otivs = tivs
            .map { IndexValue(value: model.texts[$0.index], index: $0.index) }
        let undoItem0 = SheetUndoItem.insertTexts(otivs)
        let redoItem0 = SheetUndoItem.removeTexts(textIndexes: ivs)
        append(undo: undoItem0, redo: redoItem0)
        
        let undoItem1 = SheetUndoItem.removeTexts(textIndexes: ivs)
        let redoItem1 = SheetUndoItem.insertTexts(tivs)
        append(undo: undoItem1, redo: redoItem1)
        
        tivs.forEach { textsView.elementViews[$0.index].model = $0.value }
    }
    func removeText(at textIndexes: [Int]) {
        let tivs = textIndexes.map {
            IndexValue(value: model.texts[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertTexts(tivs)
        let redoItem = SheetUndoItem.removeTexts(textIndexes: textIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeTexts(at textIndexes: [Int]) {
        let tivs = textIndexes.map {
            IndexValue(value: model.texts[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertTexts(tivs)
        let redoItem = SheetUndoItem.removeTexts(textIndexes: textIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(_ ituv: IndexValue<TextValue>,
                 old oituv: IndexValue<TextValue>) {
        let undoItem = SheetUndoItem.replaceString(oituv)
        let redoItem = SheetUndoItem.replaceString(ituv)
        append(undo: undoItem, redo: redoItem)
    }
    func replace(_ ituv: IndexValue<TextValue>) {
        let oldText = textsView.elementViews[ituv.index].model
        let string = oldText.string
        let intRange = ituv.value.replacedRange
        let oldRange = intRange.lowerBound ..< (intRange.lowerBound + ituv.value.string.count)
        let oldOrigin = ituv.value.origin != nil ? oldText.origin : nil
        let oldSize = ituv.value.size != nil ? oldText.size : nil
        let oldWidthCount = ituv.value.widthCount != nil ? oldText.widthCount : nil
        let sRange = string.range(fromInt: intRange)
        let oituv = TextValue(string: String(string[sRange]),
                              replacedRange: oldRange,
                              origin: oldOrigin, size: oldSize,
                              widthCount: oldWidthCount)
        let undoItem = SheetUndoItem.replaceString(IndexValue(value: oituv,
                                                              index: ituv.index))
        let redoItem = SheetUndoItem.replaceString(ituv)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(_ colorUndoValue: ColorValue, oldColorValue: ColorValue) {
        let undoItem = SheetUndoItem.changedColors(oldColorValue)
        let redoItem = SheetUndoItem.changedColors(colorUndoValue)
        append(undo: undoItem, redo: redoItem)
    }
    func set(_ colorValue: ColorValue, oldColorValue: ColorValue) {
        let undoItem = SheetUndoItem.changedColors(oldColorValue)
        let redoItem = SheetUndoItem.changedColors(colorValue)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func append(_ note: Note) {
        append([note])
    }
    func append(_ notes: [Note]) {
        let undoItem = SheetUndoItem.removeNotes(noteIndexes: Array(model.score.notes.count ..< (model.score.notes.count + notes.count)))
        let redoItem = SheetUndoItem.insertNotes(notes.enumerated().map {
            IndexValue(value: $0.element, index: model.score.notes.count + $0.offset)
        })
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func captureAppend(_ note: Note) {
        captureAppend([note])
    }
    func captureAppend(_ notes: [Note]) {
        let undoItem = SheetUndoItem.removeNotes(noteIndexes: Array((model.score.notes.count - notes.count) ..< (model.score.notes.count)))
        let redoItem = SheetUndoItem.insertNotes(notes.enumerated().map {
            IndexValue(value: $0.element, index: model.score.notes.count - notes.count + $0.offset)
        })
        append(undo: undoItem, redo: redoItem)
    }
    func insert(_ nivs: [IndexValue<Note>]) {
        let undoItem = SheetUndoItem.removeNotes(noteIndexes: nivs.map { $0.index })
        let redoItem = SheetUndoItem.insertNotes(nivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func capture(_ note: Note, old oldNote: Note, at ni: Int) {
        capture([.init(value: note, index: ni)], old: [.init(value: oldNote, index: ni)])
    }
    func capture(_ values: [IndexValue<Note>], old oldValues: [IndexValue<Note>]) {
        let undoItem = SheetUndoItem.replaceNotes(oldValues)
        let redoItem = SheetUndoItem.replaceNotes(values)
        append(undo: undoItem, redo: redoItem)
    }
    func replace(_ note: Note, at ni: Int) {
        replace([.init(value: note, index: ni)])
    }
    func replace(_ values: [IndexValue<Note>]) {
        let undoItem = SheetUndoItem.replaceNotes(values.map { IndexValue(value: model.score.notes[$0.index], index: $0.index) })
        let redoItem = SheetUndoItem.replaceNotes(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func removeNote(at i: Int) {
        let undoItem = SheetUndoItem.insertNotes([IndexValue(value: model.score.notes[i],
                                                             index: i)])
        let redoItem = SheetUndoItem.removeNotes(noteIndexes: [i])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeNote(at noteIndexes: [Int]) {
        let nivs = noteIndexes.map {
            IndexValue(value: model.score.notes[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertNotes(nivs)
        let redoItem = SheetUndoItem.removeNotes(noteIndexes: noteIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func insertDraft(_ nivs: [IndexValue<Note>]) {
        let undoItem = SheetUndoItem.removeDraftNotes(noteIndexes: nivs.map { $0.index })
        let redoItem = SheetUndoItem.insertDraftNotes(nivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeDraftNotes(at noteIndexes: [Int]) {
        let nivs = noteIndexes.map {
            IndexValue(value: model.score.draftNotes[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertDraftNotes(nivs)
        let redoItem = SheetUndoItem.removeDraftNotes(noteIndexes: noteIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func append(_ content: Content) {
        let undoItem = SheetUndoItem.removeContents(contentIndexes: [model.contents.count])
        let redoItem = SheetUndoItem.insertContents([IndexValue(value: content,
                                                                index: model.contents.count)])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(_ content: Content, old oldContent: Content, at i: Int) {
        let undoItem = SheetUndoItem.replaceContents([IndexValue(value: oldContent, index: i)])
        let redoItem = SheetUndoItem.replaceContents([IndexValue(value: content, index: i)])
        append(undo: undoItem, redo: redoItem)
    }
    func replace(_ content: Content, at i: Int) {
        replace(IndexValue(value: content, index: i))
    }
    func replace(_ contentValue: IndexValue<Content>) {
        let undoItem = SheetUndoItem.replaceContents([IndexValue(value: model.contents[contentValue.index],
                                                                 index: contentValue.index)])
        let redoItem = SheetUndoItem.replaceContents([contentValue])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeContent(at i: Int) {
        let undoItem = SheetUndoItem.insertContents([IndexValue(value: model.contents[i],
                                                                index: i)])
        let redoItem = SheetUndoItem.removeContents(contentIndexes: [i])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeContents(at contentIndexes: [Int]) {
        let civs = contentIndexes.map {
            IndexValue(value: model.contents[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertContents(civs)
        let redoItem = SheetUndoItem.removeContents(contentIndexes: contentIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func append(_ border: Border) {
        let undoItem = SheetUndoItem.removeBorders(borderIndexes: [model.borders.count])
        let redoItem = SheetUndoItem.insertBorders([IndexValue(value: border,
                                                               index: model.borders.count)])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeBorder(at i: Int) {
        let undoItem = SheetUndoItem.insertBorders([IndexValue(value: model.borders[i],
                                                               index: i)])
        let redoItem = SheetUndoItem.removeBorders(borderIndexes: [i])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(_ border: Border, old oldBorder: Border, at i: Int) {
        let undoItem1 = SheetUndoItem.insertBorders([IndexValue(value: oldBorder, index: i)])
        let redoItem1 = SheetUndoItem.removeBorders(borderIndexes: [i])
        append(undo: undoItem1, redo: redoItem1)
        
        let undoItem0 = SheetUndoItem.removeBorders(borderIndexes: [i])
        let redoItem0 = SheetUndoItem.insertBorders([IndexValue(value: border, index: i)])
        append(undo: undoItem0, redo: redoItem0)
    }
    
    func insert(_ kivs: [IndexValue<Keyframe>]) {
        let undoItem = SheetUndoItem.removeKeyframes(keyframeIndexes: kivs.map { $0.index })
        let redoItem = SheetUndoItem.insertKeyframes(kivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeKeyframes(at indexes: [Int]) {
        let kivs = indexes.map {
            IndexValue(value: model.animation.keyframes[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertKeyframes(kivs)
        let redoItem = SheetUndoItem.removeKeyframes(keyframeIndexes: indexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func set(_ koivs: [IndexValue<KeyframeOption>]) {
        let keyframes = model.animation.keyframes
        let okoivs = koivs.map {
            IndexValue(value: keyframes[$0.index].option,
                       index: $0.index)
        }
        let undoItem = SheetUndoItem.setKeyframeOptions(okoivs)
        let redoItem = SheetUndoItem.setKeyframeOptions(koivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func set(beat: Rational, previousPosition: Point, nextPosition: Point,
             at i: Int) {
        let ko = KeyframeOption(beat: beat,
                                previousPosition: previousPosition, nextPosition: nextPosition)
        set([IndexValue(value: ko, index: i)])
    }
    func set(beat: Rational, at i: Int) {
        let oko = model.animation.keyframes[i].option
        let opo = [IndexValue(value: oko, index: i)]
        
        var nko = oko
        nko.beat = beat
        let npo = [IndexValue(value: nko, index: i)]
        
        let undoItem = SheetUndoItem.setKeyframeOptions(opo)
        let redoItem = SheetUndoItem.setKeyframeOptions(npo)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(beat: Rational, oldBeat: Rational, at i: Int) {
        var oko = model.animation.keyframes[i].option
        oko.beat = oldBeat
        let opo = [IndexValue(value: oko, index: i)]
        
        var nko = model.animation.keyframes[i].option
        nko.beat = beat
        let npo = [IndexValue(value: nko, index: i)]
        
        let undoItem = SheetUndoItem.setKeyframeOptions(opo)
        let redoItem = SheetUndoItem.setKeyframeOptions(npo)
        append(undo: undoItem, redo: redoItem)
    }
    func capture(_ koivs: [IndexValue<KeyframeOption>], old okoivs: [IndexValue<KeyframeOption>]) {
        let undoItem = SheetUndoItem.setKeyframeOptions(okoivs)
        let redoItem = SheetUndoItem.setKeyframeOptions(koivs)
        append(undo: undoItem, redo: redoItem)
    }
    
    func set(_ option: AnimationOption) {
        let undoItem = SheetUndoItem.setAnimationOption(model.animation.option)
        let redoItem = SheetUndoItem.setAnimationOption(option)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(option: AnimationOption, oldOption: AnimationOption) {
        let undoItem = SheetUndoItem.setAnimationOption(oldOption)
        let redoItem = SheetUndoItem.setAnimationOption(option)
        append(undo: undoItem, redo: redoItem)
    }
    
    func set(_ option: ScoreOption) {
        let undoItem = SheetUndoItem.setScoreOption(model.score.option)
        let redoItem = SheetUndoItem.setScoreOption(option)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(_ option: ScoreOption, old oldOption: ScoreOption) {
        let undoItem = SheetUndoItem.setScoreOption(oldOption)
        let redoItem = SheetUndoItem.setScoreOption(option)
        append(undo: undoItem, redo: redoItem)
    }
    
    func appendKeyLines(_ values: [IndexValue<[Line]>]) {
        let vs: [IndexValue<[IndexValue<Line>]>] = values.map { kv in
            let lines = model.animation.keyframes[kv.index].picture.lines
            let livs = kv.value.enumerated().map {
                IndexValue(value: $0.element, index: lines.count + $0.offset)
            }
            return IndexValue(value: livs, index: kv.index)
        }
        insertKeyLines(vs)
    }
    func insertKeyLines(_ values: [IndexValue<[IndexValue<Line>]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[Int]>] = values.map { kv in
            IndexValue(value: kv.value.map { $0.index }, index: kv.index)
        }
        let undoItem = SheetUndoItem.removeKeyLines(ovs)
        let redoItem = SheetUndoItem.insertKeyLines(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func replaceKeyLines(_ values: [IndexValue<[IndexValue<Line>]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[IndexValue<Line>]>] = values.map { kv in
            let lines = model.animation.keyframes[kv.index].picture.lines
            let livs = kv.value.map {
                IndexValue(value: lines[$0.index], index: $0.index)
            }
            return IndexValue(value: livs, index: kv.index)
        }
        let undoItem = SheetUndoItem.replaceKeyLines(ovs)
        let redoItem = SheetUndoItem.replaceKeyLines(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeKeyLines(_ values: [IndexValue<[Int]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[IndexValue<Line>]>] = values.map { kv in
            let lines = model.animation.keyframes[kv.index].picture.lines
            let livs = kv.value.map {
                IndexValue(value: lines[$0], index: $0)
            }
            return IndexValue(value: livs, index: kv.index)
        }
        let undoItem = SheetUndoItem.insertKeyLines(ovs)
        let redoItem = SheetUndoItem.removeKeyLines(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func appendKeyPlanes(_ values: [IndexValue<[Plane]>]) {
        guard !values.isEmpty else { return }
        
        let vs: [IndexValue<[IndexValue<Plane>]>] = values.map { kv in
            let planes = model.animation.keyframes[kv.index].picture.planes
            let pivs = kv.value.enumerated().map {
                IndexValue(value: $0.element, index: planes.count + $0.offset)
            }
            return IndexValue(value: pivs, index: kv.index)
        }
        insertKeyPlanes(vs)
    }
    func insertKeyPlanes(_ values: [IndexValue<[IndexValue<Plane>]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[Int]>] = values.map { kv in
            IndexValue(value: kv.value.map { $0.index }, index: kv.index)
        }
        let undoItem = SheetUndoItem.removeKeyPlanes(ovs)
        let redoItem = SheetUndoItem.insertKeyPlanes(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func replaceKeyPlanes(_ values: [IndexValue<[IndexValue<Plane>]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[IndexValue<Plane>]>] = values.map { kv in
            let planes = model.animation.keyframes[kv.index].picture.planes
            let pivs = kv.value.map {
                IndexValue(value: planes[$0.index], index: $0.index)
            }
            return IndexValue(value: pivs, index: kv.index)
        }
        let undoItem = SheetUndoItem.replaceKeyPlanes(ovs)
        let redoItem = SheetUndoItem.replaceKeyPlanes(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeKeyPlanes(_ values: [IndexValue<[Int]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[IndexValue<Plane>]>] = values.map { kv in
            let planes = model.animation.keyframes[kv.index].picture.planes
            let pivs = kv.value.map {
                IndexValue(value: planes[$0], index: $0)
            }
            return IndexValue(value: pivs, index: kv.index)
        }
        let undoItem = SheetUndoItem.insertKeyPlanes(ovs)
        let redoItem = SheetUndoItem.removeKeyPlanes(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func appendDraftKeyLines(_ values: [IndexValue<[Line]>]) {
        guard !values.isEmpty else { return }
        
        let vs: [IndexValue<[IndexValue<Line>]>] = values.map { kv in
            let lines = model.animation.keyframes[kv.index].draftPicture.lines
            let livs = kv.value.enumerated().map {
                IndexValue(value: $0.element, index: lines.count + $0.offset)
            }
            return IndexValue(value: livs, index: kv.index)
        }
        insertDraftKeyLines(vs)
    }
    func insertDraftKeyLines(_ values: [IndexValue<[IndexValue<Line>]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[Int]>] = values.map { kv in
            IndexValue(value: kv.value.map { $0.index }, index: kv.index)
        }
        let undoItem = SheetUndoItem.removeDraftKeyLines(ovs)
        let redoItem = SheetUndoItem.insertDraftKeyLines(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeDraftKeyLines(_ values: [IndexValue<[Int]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[IndexValue<Line>]>] = values.map { kv in
            let lines = model.animation.keyframes[kv.index].draftPicture.lines
            let livs = kv.value.map {
                IndexValue(value: lines[$0], index: $0)
            }
            return IndexValue(value: livs, index: kv.index)
        }
        let undoItem = SheetUndoItem.insertDraftKeyLines(ovs)
        let redoItem = SheetUndoItem.removeDraftKeyLines(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func appendDraftKeyPlanes(_ values: [IndexValue<[Plane]>]) {
        guard !values.isEmpty else { return }
        
        let vs: [IndexValue<[IndexValue<Plane>]>] = values.map { kv in
            let planes = model.animation.keyframes[kv.index].draftPicture.planes
            let pivs = kv.value.enumerated().map {
                IndexValue(value: $0.element, index: planes.count + $0.offset)
            }
            return IndexValue(value: pivs, index: kv.index)
        }
        insertKeyPlanes(vs)
    }
    func insertDraftKeyPlanes(_ values: [IndexValue<[IndexValue<Plane>]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[Int]>] = values.map { kv in
            IndexValue(value: kv.value.map { $0.index }, index: kv.index)
        }
        let undoItem = SheetUndoItem.removeDraftKeyPlanes(ovs)
        let redoItem = SheetUndoItem.insertDraftKeyPlanes(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func removeDraftKeyPlanes(_ values: [IndexValue<[Int]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[IndexValue<Plane>]>] = values.map { kv in
            let planes = model.animation.keyframes[kv.index].draftPicture.planes
            let pivs = kv.value.map {
                IndexValue(value: planes[$0], index: $0)
            }
            return IndexValue(value: pivs, index: kv.index)
        }
        let undoItem = SheetUndoItem.insertDraftKeyPlanes(ovs)
        let redoItem = SheetUndoItem.removeDraftKeyPlanes(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func set(_ values: [IndexValue<[IndexValue<InterOption>]>]) {
        guard !values.isEmpty else { return }
        
        let ovs: [IndexValue<[IndexValue<InterOption>]>] = values.map { kv in
            let lines = model.animation.keyframes[kv.index].picture.lines
            return .init(value: kv.value.map { .init(value: lines[$0.index].interOption, index: $0.index) },
                         index: kv.index)
        }
        let undoItem = SheetUndoItem.setLineIDs(ovs)
        let redoItem = SheetUndoItem.setLineIDs(values)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func capture(_ text: Text, old oldText: Text, at i: Int) {
        let undoItem1 = SheetUndoItem.insertTexts([IndexValue(value: oldText, index: i)])
        let redoItem1 = SheetUndoItem.removeTexts(textIndexes: [i])
        append(undo: undoItem1, redo: redoItem1)
        
        let undoItem0 = SheetUndoItem.removeTexts(textIndexes: [i])
        let redoItem0 = SheetUndoItem.insertTexts([IndexValue(value: text, index: i)])
        append(undo: undoItem0, redo: redoItem0)
    }
    
    func captureLine(_ line: Line, old oldLine: Line, at i: Int) {
        let undoItem1 = SheetUndoItem.insertLines([IndexValue(value: oldLine, index: i)])
        let redoItem1 = SheetUndoItem.removeLines(lineIndexes: [i])
        append(undo: undoItem1, redo: redoItem1)
        
        let undoItem0 = SheetUndoItem.removeLines(lineIndexes: [i])
        let redoItem0 = SheetUndoItem.insertLines([IndexValue(value: line, index: i)])
        append(undo: undoItem0, redo: redoItem0)
    }
    func captureLines(_ lines: [Line], old oldLines: [Line], at idxs: [Int]) {
        let undoItem1 = SheetUndoItem.insertLines(zip(oldLines, idxs).map { .init(value: $0.0, index: $0.1) })
        let redoItem1 = SheetUndoItem.removeLines(lineIndexes: idxs)
        append(undo: undoItem1, redo: redoItem1)
        
        let undoItem0 = SheetUndoItem.removeLines(lineIndexes: idxs)
        let redoItem0 = SheetUndoItem.insertLines(zip(lines, idxs).map { .init(value: $0.0, index: $0.1) })
        append(undo: undoItem0, redo: redoItem0)
    }
    func capturePlanes(_ planes: [Plane], old oldPlanes: [Plane], at idxs: [Int]) {
        let undoItem1 = SheetUndoItem.insertPlanes(zip(oldPlanes, idxs).map { .init(value: $0.0, index: $0.1) })
        let redoItem1 = SheetUndoItem.removePlanes(planeIndexes: idxs)
        append(undo: undoItem1, redo: redoItem1)
        
        let undoItem0 = SheetUndoItem.removePlanes(planeIndexes: idxs)
        let redoItem0 = SheetUndoItem.insertPlanes(zip(planes, idxs).map { .init(value: $0.0, index: $0.1) })
        append(undo: undoItem0, redo: redoItem0)
    }
    func captureTexts(_ texts: [Text], old oldTexts: [Text], at idxs: [Int]) {
        let undoItem1 = SheetUndoItem.insertTexts(zip(oldTexts, idxs).map { .init(value: $0.0, index: $0.1) })
        let redoItem1 = SheetUndoItem.removeTexts(textIndexes: idxs)
        append(undo: undoItem1, redo: redoItem1)
        
        let undoItem0 = SheetUndoItem.removeTexts(textIndexes: idxs)
        let redoItem0 = SheetUndoItem.insertTexts(zip(texts, idxs).map { .init(value: $0.0, index: $0.1) })
        append(undo: undoItem0, redo: redoItem0)
    }
    func captureContents(_ contents: [Content], old oldContents: [Content], at idxs: [Int]) {
        let undoItem1 = SheetUndoItem.insertContents(zip(oldContents, idxs).map { .init(value: $0.0, index: $0.1) })
        let redoItem1 = SheetUndoItem.removeContents(contentIndexes: idxs)
        append(undo: undoItem1, redo: redoItem1)
        
        let undoItem0 = SheetUndoItem.removeContents(contentIndexes: idxs)
        let redoItem0 = SheetUndoItem.insertContents(zip(contents, idxs).map { .init(value: $0.0, index: $0.1) })
        append(undo: undoItem0, redo: redoItem0)
    }
    func setRootKeyframeIndex(rootKeyframeIndex: Int) {
        let undoItem = SheetUndoItem.setRootKeyframeIndex(rootKeyframeIndex: self.rootKeyframeIndex)
        let redoItem = SheetUndoItem.setRootKeyframeIndex(rootKeyframeIndex: rootKeyframeIndex)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    @discardableResult
    func undo(to toTopIndex: Int) -> (rect: Rect?, nodes: [Node]) {
        var rect = Rect?.none, nodes = [Node]()
        let results = history.undoAndResults(to: toTopIndex)
        var reverses = [Version: Int]()
        for result in results {
            let item: UndoItemValue<SheetUndoItem>?
            if result.item.loadType == .unload {
                _ = history[result.version].values[result.valueIndex].loadRedoItem()
                loadCheck(with: result, reverses: &reverses)
                item = history[result.version].values[result.valueIndex].undoItemValue
            } else {
                item = result.item.undoItemValue
            }
            switch result.type {
            case .undo:
                if let undoItem = item?.undoItem {
                    let (aRect, aNodes) = set(undoItem, isMakeRect: true)
                    rect += aRect
                    nodes += aNodes
                }
            case .redo:
                if let redoItem = item?.redoItem {
                    let (aRect, aNodes) = set(redoItem, isMakeRect: true)
                    rect += aRect
                    nodes += aNodes
                }
            }
        }
        
        for (version, index) in reverses {
            let item = SheetUndoItem.setRootKeyframeIndex(rootKeyframeIndex: index)
            let uiv = UndoItemValue(undoItem: item, redoItem: item)
            let udv = UndoDataValue(save: uiv)
            history[version].values.insert(udv, at: 0)
        }
        
        return (rect, nodes)
    }
    func loadCheck(with result: SheetHistory.UndoResult,
                   reverses: inout [Version: Int]) {
        guard let uiv = history[result.version].values[result.valueIndex]
                .undoItemValue else { return }
        
        let isUndo = result.type == .undo
        let reversedType: UndoType = isUndo ? .redo : .undo
        
        func updateFirstReverse() {
            if model.enabledAnimation {
                if !history[result.version].isFirstReverse {
                    history[result.version].isFirstReverse = true
                }
                if case .setRootKeyframeIndex? =  history[result.version].values.first?.loadedRedoItem()?.undoItem {
                    
                } else {
                    reverses[result.version] = rootKeyframeIndex
                    print("first reverse error")
                }
            }
        }
        switch isUndo ? uiv.redoItem : uiv.undoItem {
        case .appendLine(let line):
            updateFirstReverse()
            if let lastLine = model.picture.lines.last {
                if lastLine != line {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.appendLine(lastLine), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .appendLines(let lines):
            updateFirstReverse()
            let di = model.picture.lines.count - lines.count
            if di >= 0 {
                let lastLines = Array(model.picture.lines[di...])
                if lastLines != lines {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.appendLines(lastLines), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .appendPlanes(let planes):
            updateFirstReverse()
            let di = model.picture.planes.count - planes.count
            if di >= 0 {
                let lastPlanes = Array(model.picture.planes[di...])
                if lastPlanes != planes {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.appendPlanes(lastPlanes),
                                                type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .removeLastLines:
            updateFirstReverse()
        case .removeLastPlanes:
            updateFirstReverse()
        case .insertLines(let livs):
            updateFirstReverse()
            let maxI = livs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.picture.lines.count {
                let oldLIVS = livs.map { IndexValue(value: model.picture.lines[$0.index],
                                                    index: $0.index) }
                if oldLIVS != livs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertLines(oldLIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .insertPlanes(let pivs):
            updateFirstReverse()
            let maxI = pivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.picture.planes.count {
                let oldPIVS = pivs.map { IndexValue(value: model.picture.planes[$0.index],
                                                    index: $0.index) }
                if oldPIVS != pivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertPlanes(oldPIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .removeLines(let lineIndexes):
            updateFirstReverse()
            let oldLIS = lineIndexes.filter { $0 < model.picture.lines.count + lineIndexes.count }.sorted()
            if oldLIS != lineIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeLines(lineIndexes: oldLIS), type: reversedType)
            }
        case .removePlanes(let planeIndexes):
            updateFirstReverse()
            let oldPIS = planeIndexes.filter { $0 < model.picture.planes.count + planeIndexes.count }.sorted()
            if oldPIS != planeIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removePlanes(planeIndexes: oldPIS), type: reversedType)
            }
        case .setPlaneValue(let planeValue):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            if planeValue.planes.count + planeValue.moveIndexValues.count
                == model.picture.planes.count {
                
                var isArray = Array(repeating: false,
                                    count: model.picture.planes.count)
                for v in planeValue.moveIndexValues {
                    if v.index < isArray.count {
                        isArray[v.index] = true
                    } else {
                        error()
                    }
                }
                var i = 0
                for (j, isMoved) in isArray.enumerated() {
                    if !isMoved {
                        if i < planeValue.planes.count
                            && planeValue.planes[i] != model.picture.planes[j] {
                            
                            error()
                            break
                        }
                        i += 1
                    }
                }
            } else {
                error()
            }
        case .changeToDraft:
            updateFirstReverse()
        case .setPicture(let picture):
            updateFirstReverse()
            if model.picture != picture {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.setPicture(model.picture), type: reversedType)
            }
        case .insertDraftLines(let livs):
            updateFirstReverse()
            let maxI = livs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.draftPicture.lines.count {
                let oldLIVS = livs.map { IndexValue(value: model.draftPicture.lines[$0.index],
                                                    index: $0.index) }
                if oldLIVS != livs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertDraftLines(oldLIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .insertDraftPlanes(let pivs):
            updateFirstReverse()
            let maxI = pivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.draftPicture.planes.count {
                let oldPIVS = pivs.map { IndexValue(value: model.draftPicture.planes[$0.index],
                                                    index: $0.index) }
                if oldPIVS != pivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertDraftPlanes(oldPIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .removeDraftLines(let lineIndexes):
            updateFirstReverse()
            let oldLIS = lineIndexes.filter { $0 < model.draftPicture.lines.count + lineIndexes.count }.sorted()
            if oldLIS != lineIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeDraftLines(lineIndexes: oldLIS), type: reversedType)
            }
        case .removeDraftPlanes(let planeIndexes):
            updateFirstReverse()
            let oldPIS = planeIndexes.filter { $0 < model.draftPicture.planes.count + planeIndexes.count }.sorted()
            if oldPIS != planeIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeDraftPlanes(planeIndexes: oldPIS), type: reversedType)
            }
        case .setDraftPicture(let draftPicture):
            updateFirstReverse()
            if model.draftPicture != draftPicture {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.setDraftPicture(model.draftPicture),
                                            type: reversedType)
            }
        case .insertTexts(let tivs):
            updateFirstReverse()
            let maxI = tivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.texts.count {
                let oldTIVS = tivs.map { IndexValue(value: model.texts[$0.index],
                                                    index: $0.index) }
                if oldTIVS != tivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertTexts(oldTIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .removeTexts(let textIndexes):
            updateFirstReverse()
            let oldTIS = textIndexes.filter { $0 < model.texts.count + textIndexes.count }.sorted()
            if oldTIS != textIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeTexts(textIndexes: oldTIS), type: reversedType)
            }
        case .replaceString(let tuiv):
            updateFirstReverse()
            guard tuiv.index < model.texts.count else {
                history[result.version]
                    .values[result.valueIndex].error()
                break
            }
            let text = model.texts[tuiv.index]
            let intRange = tuiv.value.newRange
            if intRange.lowerBound >= 0
                && intRange.upperBound <= text.string.count {
                
                let range = text.string.range(fromInt: intRange)
                let oldString = text.string[range]
                let oldOrigin = tuiv.value.origin != nil ? text.origin : nil
                let oldSize = tuiv.value.size != nil ? text.size : nil
                let oldWidthCount
                = tuiv.value.widthCount != nil ? text.widthCount : nil
                if oldString != tuiv.value.string
                    || oldOrigin != tuiv.value.origin
                    || oldSize != tuiv.value.size
                    || oldWidthCount != tuiv.value.widthCount {
                    
                    let nOrigin = oldOrigin != tuiv.value.origin ?
                        oldOrigin : tuiv.value.origin
                    let nSize = oldSize != tuiv.value.size ?
                        oldSize : tuiv.value.size
                    let nWidthCount = oldWidthCount != tuiv.value.widthCount ?
                        oldWidthCount : tuiv.value.widthCount
                    let tv = TextValue(string: String(oldString),
                                       replacedRange: tuiv.value.replacedRange,
                                       origin: nOrigin, size: nSize,
                                       widthCount: nWidthCount)
                    let nTUIV = IndexValue(value: tv, index: tuiv.index)
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.replaceString(nTUIV), type: reversedType)
                }
            } else {
                history[result.version]
                    .values[result.valueIndex].error()
            }
        case .changedColors(let colorUndoValue):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            
            if !colorUndoValue.planeIndexes.isEmpty {
                let maxPISI = colorUndoValue.planeIndexes.max { $0 < $1 }
                if let maxPISI = maxPISI, maxPISI < model.picture.planes.count {
                    for i in colorUndoValue.planeIndexes {
                        if model.picture.planes[i].uuColor != colorUndoValue.uuColor {
                            error()
                            break
                        }
                    }
                } else {
                    error()
                }
            } else if !colorUndoValue.planeAnimationIndexes.isEmpty {
                loop: for k in colorUndoValue.planeAnimationIndexes {
                    if k.index >= model.animation.keyframes.count {
                        error()
                        break loop
                    }
                    let planes = model.animation.keyframes[k.index].picture.planes
                    for pi in k.value {
                        if pi >= planes.count {
                            error()
                            break loop
                        }
                        if planes[pi].uuColor != colorUndoValue.uuColor {
                            error()
                            break loop
                        }
                    }
                }
            }
            
            if !colorUndoValue.lineIndexes.isEmpty {
                let maxLISI = colorUndoValue.lineIndexes.max { $0 < $1 }
                if let maxLISI, maxLISI < model.picture.lines.count {
                    for i in colorUndoValue.lineIndexes {
                        if model.picture.lines[i].uuColor != colorUndoValue.uuColor {
                            error()
                            break
                        }
                    }
                } else {
                    error()
                }
            } else if !colorUndoValue.lineAnimationIndexes.isEmpty {
                loop: for k in colorUndoValue.lineAnimationIndexes {
                    if k.index >= model.animation.keyframes.count {
                        error()
                        break loop
                    }
                    let lines = model.animation.keyframes[k.index].picture.lines
                    for li in k.value {
                        if li >= lines.count {
                            error()
                            break loop
                        }
                        if lines[li].uuColor != colorUndoValue.uuColor {
                            error()
                            break loop
                        }
                    }
                }
            }
            
            if colorUndoValue.isBackground && model.backgroundUUColor != colorUndoValue.uuColor {
                error()
            }
        case .insertBorders(let bivs):
            updateFirstReverse()
            let maxI = bivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.borders.count {
                let oldBIVS = bivs.map { IndexValue(value: model.borders[$0.index],
                                                    index: $0.index) }
                if oldBIVS != bivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertBorders(oldBIVS), type: reversedType)
                }
            } else {
                history[result.version]
                    .values[result.valueIndex].error()
            }
        case .removeBorders(let borderIndexes):
            updateFirstReverse()
            let oldBIS = borderIndexes.filter { $0 < model.borders.count + borderIndexes.count }.sorted()
            if oldBIS != borderIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeBorders(borderIndexes: oldBIS), type: reversedType)
            }
        case .setRootKeyframeIndex(_): break
        case .insertKeyframes(let kivs):
            let maxI = kivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.animation.keyframes.count {
                let oldKIVS = kivs.map { IndexValue(value: model.animation.keyframes[$0.index],
                                                    index: $0.index) }
                if oldKIVS != kivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertKeyframes(oldKIVS), type: reversedType)
                }
            } else {
                history[result.version]
                    .values[result.valueIndex].error()
            }
        case .removeKeyframes(let indexes):
            let oldKIS = indexes.filter { $0 < model.animation.keyframes.count + indexes.count }.sorted()
            if oldKIS != indexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeKeyframes(keyframeIndexes: oldKIS), type: reversedType)
            }
        case .setKeyframeOptions(let koivs):
            var isError = false
            for koiv in koivs {
                if koiv.index >= model.animation.keyframes.count {
                    isError = true
                }
            }
            if isError {
                history[result.version]
                    .values[result.valueIndex].error()
            } else {
                let okoivs = koivs.map {
                    IndexValue(value: model.animation.keyframes[$0.index].option,
                               index: $0.index)
                }
                if okoivs != koivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?
                        .set(.setKeyframeOptions(okoivs), type: reversedType)
                }
            }
            
        case .insertKeyLines(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].picture.lines
                let maxI = k.value.max { $0.index < $1.index }?.index
                if let maxI = maxI, maxI < lines.count {
                    let oldLIVS = k.value.map { IndexValue(value: lines[$0.index],
                                                           index: $0.index) }
                    if oldLIVS != k.value {
                        error()
                        break loop
                    }
                } else {
                    error()
                    break loop
                }
            }
        case .replaceKeyLines(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].picture.lines
                for liv in k.value {
                    if liv.index >= lines.count {
                        error()
                        break loop
                    }
                    if liv.value != lines[liv.index] {
                        error()
                        break loop
                    }
                }
            }
        case .removeKeyLines(let iivs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in iivs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].picture.lines
                let oldLIS = k.value.filter { $0 < lines.count + k.value.count }.sorted()
                if oldLIS != k.value {
                    error()
                    break loop
                }
            }
            
        case .insertKeyPlanes(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].picture.planes
                let maxI = k.value.max { $0.index < $1.index }?.index
                if let maxI = maxI, maxI < planes.count {
                    let oldPIVS = k.value.map { IndexValue(value: planes[$0.index],
                                                           index: $0.index) }
                    if oldPIVS != k.value {
                        error()
                        break loop
                    }
                } else {
                    error()
                    break loop
                }
            }
        case .replaceKeyPlanes(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].picture.planes
                for piv in k.value {
                    if piv.index >= planes.count {
                        error()
                        break loop
                    }
                    if piv.value != planes[piv.index] {
                        error()
                        break loop
                    }
                }
            }
        case .removeKeyPlanes(let iivs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in iivs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].picture.planes
                let oldPIS = k.value.filter { $0 < planes.count + k.value.count }.sorted()
                if oldPIS != k.value {
                    error()
                    break loop
                }
            }
            
        case .insertDraftKeyLines(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].draftPicture.lines
                let maxI = k.value.max { $0.index < $1.index }?.index
                if let maxI = maxI, maxI < lines.count {
                    let oldLIVS = k.value.map { IndexValue(value: lines[$0.index],
                                                           index: $0.index) }
                    if oldLIVS != k.value {
                        error()
                        break loop
                    }
                } else {
                    error()
                    break loop
                }
            }
        case .removeDraftKeyLines(let iivs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in iivs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].draftPicture.lines
                let oldLIS = k.value.filter { $0 < lines.count + k.value.count }.sorted()
                if oldLIS != k.value {
                    error()
                    break loop
                }
            }
            
        case .insertDraftKeyPlanes(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].draftPicture.planes
                let maxI = k.value.max { $0.index < $1.index }?.index
                if let maxI = maxI, maxI < planes.count {
                    let oldPIVS = k.value.map { IndexValue(value: planes[$0.index],
                                                           index: $0.index) }
                    if oldPIVS != k.value {
                        error()
                        break loop
                    }
                } else {
                    error()
                    break loop
                }
            }
        case .removeDraftKeyPlanes(let iivs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in iivs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].draftPicture.planes
                let oldPIS = k.value.filter { $0 < planes.count + k.value.count }.sorted()
                if oldPIS != k.value {
                    error()
                    break loop
                }
            }
            
        case .setLineIDs(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].picture.lines
                for liv in k.value {
                    if liv.index >= lines.count {
                        error()
                        break loop
                    }
                    if liv.value != lines[liv.index].interOption {
                        error()
                        break loop
                    }
                }
            }
            
        case .setAnimationOption(let option):
            let oldOption = model.animation.option
            if oldOption != option {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.setAnimationOption(oldOption), type: reversedType)
            }
            
        case .insertNotes(let nivs):
            updateFirstReverse()
            let maxI = nivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.score.notes.count {
                let oldNIVS = nivs.map { IndexValue(value: model.score.notes[$0.index],
                                                    index: $0.index) }
                if oldNIVS != nivs {
                    print("InsertNotesUndoError", model.score.notes.count, oldNIVS.count, nivs.count, oldNIVS, nivs)
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertNotes(oldNIVS), type: reversedType)
                }
            } else {
                history[result.version]
                    .values[result.valueIndex].error()
            }
        case .replaceNotes(let nivs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            let notes = model.score.notes
            for niv in nivs {
                if niv.index >= notes.count {
                    error()
                    break
                }
                if niv.value != notes[niv.index] {
                    error()
                    break
                }
            }
        case .removeNotes(let noteIndexes):
            updateFirstReverse()
            let oldNIS = noteIndexes.filter { $0 < model.score.notes.count + noteIndexes.count }.sorted()
            if oldNIS != noteIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeNotes(noteIndexes: oldNIS), type: reversedType)
            }
        case .insertDraftNotes(let nivs):
            updateFirstReverse()
            let maxI = nivs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.score.notes.count {
                let oldNIVS = nivs.map { IndexValue(value: model.score.notes[$0.index],
                                                    index: $0.index) }
                if oldNIVS != nivs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertDraftNotes(oldNIVS), type: reversedType)
                }
            } else {
                history[result.version].values[result.valueIndex].error()
            }
        case .removeDraftNotes(let noteIndexes):
            updateFirstReverse()
            let oldNIS = noteIndexes.filter { $0 < model.score.notes.count + noteIndexes.count }.sorted()
            if oldNIS != noteIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeDraftNotes(noteIndexes: oldNIS), type: reversedType)
            }
        case .insertContents(let civs):
            updateFirstReverse()
            let maxI = civs.max { $0.index < $1.index }?.index
            if let maxI = maxI, maxI < model.contents.count {
                let oldCIVS = civs.map { IndexValue(value: model.contents[$0.index],
                                                    index: $0.index) }
                if oldCIVS != civs {
                    history[result.version].values[result.valueIndex]
                        .saveUndoItemValue?.set(.insertContents(oldCIVS), type: reversedType)
                }
            } else {
                history[result.version]
                    .values[result.valueIndex].error()
            }
        case .replaceContents(let civs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            let contents = model.contents
            for civ in civs {
                if civ.index >= contents.count {
                    error()
                    break
                }
                if civ.value != contents[civ.index] {
                    error()
                    break
                }
            }
        case .removeContents(let contentIndexes):
            updateFirstReverse()
            let oldCIS = contentIndexes.filter { $0 < model.contents.count + contentIndexes.count }.sorted()
            if oldCIS != contentIndexes {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.removeContents(contentIndexes: oldCIS), type: reversedType)
            }
        case .setScoreOption(let option):
            let oldOption = model.score.option
            if oldOption != option {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.setScoreOption(oldOption), type: reversedType)
            }
        }
        
        guard let nuiv = history[result.version].values[result.valueIndex]
                .undoItemValue else { return }
        switch isUndo ? nuiv.undoItem : nuiv.redoItem {
        case .appendLine(_):
            updateFirstReverse()
        case .appendLines(_):
            updateFirstReverse()
        case .appendPlanes(_):
            updateFirstReverse()
        case .removeLastLines(let count):
            updateFirstReverse()
            if count > model.picture.lines.count {
                history[result.version]
                    .values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .appendLines(model.picture.lines),
                                    redoItem: .removeLastLines(count: model.picture.lines.count),
                                    isReversed: isUndo)
            }
        case .removeLastPlanes(let count):
            updateFirstReverse()
            if count > model.picture.planes.count {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .appendPlanes(model.picture.planes),
                                    redoItem: .removeLastPlanes(count: model.picture.planes.count),
                                    isReversed: isUndo)
            }
        case .insertLines(var livs):
            updateFirstReverse()
            var isChanged = false, linesCount = model.picture.lines.count
            livs.enumerated().forEach { (k, iv) in
                if iv.index > linesCount {
                    livs[k].index = linesCount
                    isChanged = true
                }
                linesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeLines(lineIndexes: livs.map { $0.index }),
                                    redoItem: .insertLines(livs),
                                    isReversed: isUndo)
            }
        case .insertPlanes(var pivs):
            updateFirstReverse()
            var isChanged = false, planesCount = model.picture.planes.count
            pivs.enumerated().forEach { (k, iv) in
                if iv.index > planesCount {
                    pivs[k].index = planesCount
                    isChanged = true
                }
                planesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removePlanes(planeIndexes: pivs.map { $0.index }),
                                    redoItem: .insertPlanes(pivs),
                                    isReversed: isUndo)
            }
        case .removeLines(var lineIndexes):
            updateFirstReverse()
            let lis = lineIndexes.filter { $0 < model.picture.lines.count }.sorted()
            if lineIndexes != lis {
                lineIndexes = lis
                let livs = lineIndexes.map {
                    IndexValue(value: model.picture.lines[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertLines(livs),
                                    redoItem: .removeLines(lineIndexes: lis),
                                    isReversed: isUndo)
            }
        case .removePlanes(var planeIndexes):
            updateFirstReverse()
            let pis = planeIndexes.filter { $0 < model.picture.planes.count }.sorted()
            if planeIndexes != pis {
                planeIndexes = pis
                let pivs = planeIndexes.map {
                    IndexValue(value: model.picture.planes[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertPlanes(pivs),
                                    redoItem: .removePlanes(planeIndexes: pis),
                                    isReversed: isUndo)
            }
        case .setPlaneValue(var planeValue):
            updateFirstReverse()
            var isChanged = false
            let oldPlanesCount = model.picture.planes.count
            if oldPlanesCount > 0 {
                for (i, v) in planeValue.moveIndexValues.enumerated() {
                    if v.value >= oldPlanesCount {
                        planeValue.moveIndexValues[i].value = oldPlanesCount - 1
                        isChanged = true
                    }
                }
            } else {
                planeValue.moveIndexValues = []
            }
            
            var planesCount = planeValue.planes.count
            planeValue.moveIndexValues.enumerated().forEach { (k, iv) in
                if iv.index > planesCount {
                    planeValue.moveIndexValues[k].index = planesCount
                    isChanged = true
                }
                planesCount += 1
            }
            
            var isArray = Array(repeating: false,
                                count: model.picture.planes.count)
            for v in planeValue.moveIndexValues {
                isArray[v.value] = true
            }
            let oldPlanes = model.picture.planes.enumerated().compactMap {
                isArray[$0.offset] ? nil : $0.element
            }
            let oldVs = planeValue.moveIndexValues
                .map { IndexValue(value: $0.index, index: $0.value) }
                .sorted { $0.index < $1.index }
            let oldPlaneValue = PlaneValue(planes: oldPlanes,
                                           moveIndexValues: oldVs)
            
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .setPlaneValue(oldPlaneValue),
                                    redoItem: .setPlaneValue(planeValue),
                                    isReversed: isUndo)
            } else {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .setPlaneValue(oldPlaneValue)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .setPlaneValue(oldPlaneValue)
                }
            }
        case .changeToDraft(_):
            updateFirstReverse()
        case .setPicture(_):
            updateFirstReverse()
            switch result.type {
            case .undo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.redoItem = .setPicture(model.picture)
            case .redo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.undoItem = .setPicture(model.picture)
            }
        case .insertDraftLines(var livs):
            updateFirstReverse()
            var isChanged = false, linesCount = model.draftPicture.lines.count
            livs.enumerated().forEach { (k, iv) in
                if iv.index > linesCount {
                    livs[k].index = linesCount
                    isChanged = true
                }
                linesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeDraftLines(lineIndexes: livs.map { $0.index }),
                                    redoItem: .insertDraftLines(livs),
                                    isReversed: isUndo)
            }
        case .insertDraftPlanes(var pivs):
            updateFirstReverse()
            var isChanged = false, planesCount = model.draftPicture.planes.count
            pivs.enumerated().forEach { (k, iv) in
                if iv.index > planesCount {
                    pivs[k].index = planesCount
                    isChanged = true
                }
                planesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeDraftPlanes(planeIndexes: pivs.map { $0.index }),
                                    redoItem: .insertDraftPlanes(pivs),
                                    isReversed: isUndo)
            }
        case .removeDraftLines(var lineIndexes):
            updateFirstReverse()
            let lis = lineIndexes.filter { $0 < model.draftPicture.lines.count }.sorted()
            if lineIndexes != lis {
                lineIndexes = lis
                let livs = lineIndexes.map {
                    IndexValue(value: model.draftPicture.lines[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertDraftLines(livs),
                                    redoItem: .removeDraftLines(lineIndexes: lis),
                                    isReversed: isUndo)
            }
        case .removeDraftPlanes(var planeIndexes):
            updateFirstReverse()
            let pis = planeIndexes.filter { $0 < model.draftPicture.planes.count }.sorted()
            if planeIndexes != pis {
                planeIndexes = pis
                let pivs = planeIndexes.map {
                    IndexValue(value: model.draftPicture.planes[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertDraftPlanes(pivs),
                                    redoItem: .removeDraftPlanes(planeIndexes: pis),
                                    isReversed: isUndo)
            }
        case .setDraftPicture(_):
            updateFirstReverse()
            switch result.type {
            case .undo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.redoItem = .setDraftPicture(model.draftPicture)
            case .redo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.undoItem = .setDraftPicture(model.draftPicture)
            }
        case .insertTexts(var tivs):
            updateFirstReverse()
            var isChanged = false, textsCount = model.texts.count
            tivs.enumerated().forEach { (k, iv) in
                if iv.index > textsCount {
                    tivs[k].index = textsCount
                    isChanged = true
                }
                textsCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeTexts(textIndexes: tivs.map { $0.index }),
                                    redoItem: .insertTexts(tivs),
                                    isReversed: isUndo)
            }
        case .removeTexts(var textIndexes):
            updateFirstReverse()
            let tis = textIndexes.filter { $0 < model.texts.count }.sorted()
            if textIndexes != tis {
                textIndexes = tis
                let tivs = textIndexes.map {
                    IndexValue(value: model.texts[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertTexts(tivs),
                                    redoItem: .removeTexts(textIndexes: tis),
                                    isReversed: isUndo)
            }
        case .replaceString(var tuiv):
            updateFirstReverse()
            guard !model.texts.isEmpty else {
                history[result.version]
                    .values[result.valueIndex].error()
                break
            }
            var isChanged = false
            if tuiv.index >= model.texts.count {
                tuiv.index = model.texts.count - 1
                isChanged = true
            }
            let oldString = model.texts[tuiv.index].string
            if tuiv.value.replacedRange.lowerBound < 0 {
                tuiv.value.replacedRange
                    = 0 ..< tuiv.value.replacedRange.upperBound
                isChanged = true
            }
            if tuiv.value.replacedRange.lowerBound > oldString.count {
                tuiv.value.replacedRange
                    = oldString.count ..< oldString.count
                isChanged = true
            }
            if tuiv.value.replacedRange.upperBound > oldString.count {
                tuiv.value.replacedRange
                    = tuiv.value.replacedRange.lowerBound ..< oldString.count
                isChanged = true
            }
            let oldRange = tuiv.value.newRange
            let oldOrigin = tuiv.value.origin != nil ?
                model.texts[tuiv.index].origin : nil
            let oldSize = tuiv.value.size != nil ?
                model.texts[tuiv.index].size : nil
            let oldWidthCount = tuiv.value.widthCount != nil ?
                model.texts[tuiv.index].widthCount : nil
            let nRange = oldString.range(fromInt: tuiv.value.replacedRange)
            let nString = String(oldString[nRange])
            let tv = TextValue(string: nString,
                               replacedRange: oldRange,
                               origin: oldOrigin, size: oldSize,
                               widthCount: oldWidthCount)
            let tiv = IndexValue(value: tv, index: tuiv.index)
            if isChanged {
                history[result.version]
                    .values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .replaceString(tiv),
                                    redoItem: .replaceString(tuiv),
                                    isReversed: isUndo)
            } else {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .replaceString(tiv)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .replaceString(tiv)
                }
            }
        case .changedColors(var colorUndoValue):
            updateFirstReverse()
            var isChanged = false, isError = false
            if !colorUndoValue.planeIndexes.isEmpty {
                let pis = colorUndoValue.planeIndexes.filter {
                    $0 < model.picture.planes.count
                }
                if colorUndoValue.planeIndexes != pis {
                    colorUndoValue.planeIndexes = pis
                    isChanged = true
                }
            } else if !colorUndoValue.planeAnimationIndexes.isEmpty {
                func error() {
                    history[result.version]
                        .values[result.valueIndex].error()
                    isError = true
                }
                loop: for k in colorUndoValue.planeAnimationIndexes {
                    if k.index >= model.animation.keyframes.count {
                        error()
                        break loop
                    }
                    let planes = model.animation.keyframes[k.index].picture.planes
                    for i in k.value {
                        if i >= planes.count {
                            error()
                            break loop
                        }
                    }
                }
            }
            
            if !colorUndoValue.lineIndexes.isEmpty {
                let lis = colorUndoValue.lineIndexes.filter {
                    $0 < model.picture.lines.count
                }
                if colorUndoValue.lineIndexes != lis {
                    colorUndoValue.lineIndexes = lis
                    isChanged = true
                }
            } else if !colorUndoValue.lineAnimationIndexes.isEmpty {
                func error() {
                    history[result.version]
                        .values[result.valueIndex].error()
                    isError = true
                }
                loop: for k in colorUndoValue.lineAnimationIndexes {
                    if k.index >= model.animation.keyframes.count {
                        error()
                        break loop
                    }
                    let lines = model.animation.keyframes[k.index].picture.lines
                    for i in k.value {
                        if i >= lines.count {
                            error()
                            break loop
                        }
                    }
                }
            }
            
            if !isError {
                var oColorUndoValue = colorUndoValue
                var isBackground = true
                if let pi = oColorUndoValue.planeIndexes.first {
                    oColorUndoValue.uuColor = model.picture.planes[pi].uuColor
                    isBackground = false
                } else if let piv = oColorUndoValue.planeAnimationIndexes.first,
                          let pi = piv.value.first {
                    if oColorUndoValue.planeAnimationIndexes.count == oColorUndoValue.animationColors.count {
                        
                        oColorUndoValue.animationColors = oColorUndoValue.planeAnimationIndexes.map {
                            model.animation.keyframes[$0.index].picture.planes[$0.value.first!].uuColor.value
                        }
                    } else {
                        oColorUndoValue.uuColor
                        = model.animation.keyframes[piv.index].picture.planes[pi].uuColor
                    }
                    isBackground = false
                }
                
                if let li = oColorUndoValue.lineIndexes.first {
                    oColorUndoValue.uuColor = model.picture.lines[li].uuColor
                    isBackground = false
                } else if let liv = oColorUndoValue.lineAnimationIndexes.first,
                          let li = liv.value.first {
                    if oColorUndoValue.lineAnimationIndexes.count == oColorUndoValue.animationColors.count {
                        
                        oColorUndoValue.animationColors = oColorUndoValue.lineAnimationIndexes.map {
                            model.animation.keyframes[$0.index].picture.lines[$0.value.first!].uuColor.value
                        }
                    } else {
                        oColorUndoValue.uuColor
                        = model.animation.keyframes[liv.index].picture.lines[li].uuColor
                    }
                    isBackground = false
                }
                
                if isBackground {
                    oColorUndoValue.uuColor = model.backgroundUUColor
                }
                
                if isChanged {
                    history[result.version].values[result.valueIndex].saveUndoItemValue
                        = UndoItemValue(undoItem: .changedColors(oColorUndoValue),
                                        redoItem: .changedColors(colorUndoValue),
                                        isReversed: isUndo)
                } else {
                    switch result.type {
                    case .undo:
                        history[result.version].values[result.valueIndex]
                            .undoItemValue?.redoItem = .changedColors(oColorUndoValue)
                    case .redo:
                        history[result.version].values[result.valueIndex]
                            .undoItemValue?.undoItem = .changedColors(oColorUndoValue)
                    }
                }
            }
        case .insertBorders(var bivs):
            updateFirstReverse()
            var isChanged = false, bordersCount = model.borders.count
            bivs.enumerated().forEach { (k, iv) in
                if iv.index > bordersCount {
                    bivs[k].index = bordersCount
                    isChanged = true
                }
                bordersCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeBorders(borderIndexes: bivs.map { $0.index }),
                                    redoItem: .insertBorders(bivs),
                                    isReversed: isUndo)
            }
        case .removeBorders(var borderIndexes):
            updateFirstReverse()
            let bis = borderIndexes.filter { $0 < model.borders.count }.sorted()
            if borderIndexes != bis {
                borderIndexes = bis
                let bivs = borderIndexes.map {
                    IndexValue(value: model.borders[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertBorders(bivs),
                                    redoItem: .removeBorders(borderIndexes: bis),
                                    isReversed: isUndo)
            }
        case .setRootKeyframeIndex(let rootKeyframeIndex):
            switch result.type {
            case .undo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.redoItem = .setRootKeyframeIndex(rootKeyframeIndex: rootKeyframeIndex)
            case .redo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.undoItem = .setRootKeyframeIndex(rootKeyframeIndex: rootKeyframeIndex)
            }
        case .insertKeyframes(var pivs):
            var isChanged = false, keyframesCount = model.animation.keyframes.count
            pivs.enumerated().forEach { (k, iv) in
                if iv.index > keyframesCount {
                    pivs[k].index = keyframesCount
                    isChanged = true
                }
                keyframesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeKeyframes(keyframeIndexes: pivs.map { $0.index }),
                                    redoItem: .insertKeyframes(pivs),
                                    isReversed: isUndo)
            }
        case .removeKeyframes(var indexes):
            let pis = indexes.filter { $0 < model.animation.keyframes.count }.sorted()
            if indexes != pis {
                indexes = pis
                let pivs = indexes.map {
                    IndexValue(value: model.animation.keyframes[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertKeyframes(pivs),
                                    redoItem: .removeKeyframes(keyframeIndexes: pis),
                                    isReversed: isUndo)
            }
        case .setKeyframeOptions(let koivs):
            updateFirstReverse()
            let isError = {
                for koiv in koivs {
                    if koiv.index >= model.animation.keyframes.count {
                        return true
                    }
                }
                return false
            } ()
            if isError {
                history[result.version]
                    .values[result.valueIndex].error()
            } else {
                let okoivs = koivs.map {
                    IndexValue(value: model.animation.keyframes[$0.index].option,
                               index: $0.index)
                }
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .setKeyframeOptions(okoivs)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .setKeyframeOptions(okoivs)
                }
            }
            
        case .insertKeyLines(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].picture.lines
                var linesCount = lines.count
                for liv in k.value {
                    if liv.index > linesCount {
                        error()
                        break loop
                    }
                    linesCount += 1
                }
            }
        case .replaceKeyLines(let kvs):
            updateFirstReverse()
            var isError = false
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
                isError = true
            }
            var oldKVs = [IndexValue<[IndexValue<Line>]>]()
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].picture.lines
                var oldLIVs = [IndexValue<Line>]()
                for liv in k.value {
                    if liv.index >= lines.count {
                        error()
                        break loop
                    }
                    oldLIVs.append(IndexValue(value: lines[liv.index],
                                              index: liv.index))
                }
                oldKVs.append(IndexValue(value: oldLIVs, index: k.index))
            }
            if !isError {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .replaceKeyLines(oldKVs)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .replaceKeyLines(oldKVs)
                }
            }
        case .removeKeyLines(let iivs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in iivs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].picture.lines
                let lis = k.value.filter { $0 < lines.count }.sorted()
                if k.value != lis {
                    error()
                    break loop
                }
            }
            
        case .insertKeyPlanes(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].picture.planes
                var planesCount = planes.count
                for piv in k.value {
                    if piv.index > planesCount {
                        error()
                        break loop
                    }
                    planesCount += 1
                }
            }
        case .replaceKeyPlanes(let kvs):
            updateFirstReverse()
            var isError = false
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
                isError = true
            }
            var oldKVs = [IndexValue<[IndexValue<Plane>]>]()
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].picture.planes
                var oldPIVs = [IndexValue<Plane>]()
                for piv in k.value {
                    if piv.index >= planes.count {
                        error()
                        break loop
                    }
                    oldPIVs.append(IndexValue(value: planes[piv.index],
                                              index: piv.index))
                }
                oldKVs.append(IndexValue(value: oldPIVs, index: k.index))
            }
            if !isError {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .replaceKeyPlanes(oldKVs)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .replaceKeyPlanes(oldKVs)
                }
            }
        case .removeKeyPlanes(let iivs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in iivs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].picture.planes
                let pis = k.value.filter { $0 < planes.count }.sorted()
                if k.value != pis {
                    error()
                    break loop
                }
            }
            
        case .insertDraftKeyLines(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].draftPicture.lines
                var linesCount = lines.count
                for liv in k.value {
                    if liv.index > linesCount {
                        error()
                        break loop
                    }
                    linesCount += 1
                }
            }
        case .removeDraftKeyLines(let iivs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in iivs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].draftPicture.lines
                let lis = k.value.filter { $0 < lines.count }.sorted()
                if k.value != lis {
                    error()
                    break loop
                }
            }
            
        case .insertDraftKeyPlanes(let kvs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].draftPicture.planes
                var planesCount = planes.count
                for piv in k.value {
                    if piv.index > planesCount {
                        error()
                        break loop
                    }
                    planesCount += 1
                }
            }
        case .removeDraftKeyPlanes(let iivs):
            updateFirstReverse()
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
            }
            loop: for k in iivs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let planes = model.animation.keyframes[k.index].draftPicture.planes
                let pis = k.value.filter { $0 < planes.count }.sorted()
                if k.value != pis {
                    error()
                    break loop
                }
            }
            
        case .setLineIDs(let kvs):
            updateFirstReverse()
            var isError = false
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
                isError = true
            }
            var oldKvs = [IndexValue<[IndexValue<InterOption>]>]()
            loop: for k in kvs {
                if k.index >= model.animation.keyframes.count {
                    error()
                    break loop
                }
                let lines = model.animation.keyframes[k.index].picture.lines
                var oldVs = [IndexValue<InterOption>]()
                for liv in k.value {
                    if liv.index >= lines.count {
                        error()
                        break loop
                    }
                    oldVs.append(IndexValue(value: lines[liv.index].interOption,
                                              index: liv.index))
                }
                oldKvs.append(IndexValue(value: oldVs, index: k.index))
            }
            if !isError {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .setLineIDs(oldKvs)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .setLineIDs(oldKvs)
                }
            }
            
        case .setAnimationOption:
            let oldOption = model.animation.option
            switch result.type {
            case .undo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.redoItem = .setAnimationOption(oldOption)
            case .redo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.undoItem = .setAnimationOption(oldOption)
            }
            
        case .insertNotes(var nivs):
            updateFirstReverse()
            var isChanged = false, notesCount = model.score.notes.count
            nivs.enumerated().forEach { (k, iv) in
                if iv.index > notesCount {
                    nivs[k].index = notesCount
                    isChanged = true
                }
                notesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeNotes(noteIndexes: nivs.map { $0.index }),
                                    redoItem: .insertNotes(nivs),
                                    isReversed: isUndo)
            }
        case .replaceNotes(let nivs):
            updateFirstReverse()
            var isError = false
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
                isError = true
            }
            let notes = model.score.notes
            var oldNIVs = [IndexValue<Note>]()
            for niv in nivs {
                if niv.index >= notes.count {
                    error()
                    break
                }
                oldNIVs.append(IndexValue(value: notes[niv.index],
                                          index: niv.index))
            }
            if !isError {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .replaceNotes(oldNIVs)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .replaceNotes(oldNIVs)
                }
            }
        case .removeNotes(var noteIndexes):
            updateFirstReverse()
            let nis = noteIndexes.filter { $0 < model.score.notes.count }.sorted()
            if noteIndexes != nis {
                noteIndexes = nis
                let nivs = noteIndexes.map {
                    IndexValue(value: model.score.notes[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertNotes(nivs),
                                    redoItem: .removeNotes(noteIndexes: nis),
                                    isReversed: isUndo)
            }
        case .insertDraftNotes(var nivs):
            updateFirstReverse()
            var isChanged = false, notesCount = model.score.notes.count
            nivs.enumerated().forEach { (k, iv) in
                if iv.index > notesCount {
                    nivs[k].index = notesCount
                    isChanged = true
                }
                notesCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeDraftNotes(noteIndexes: nivs.map { $0.index }),
                                    redoItem: .insertDraftNotes(nivs),
                                    isReversed: isUndo)
            }
        case .removeDraftNotes(var noteIndexes):
            updateFirstReverse()
            let nis = noteIndexes.filter { $0 < model.score.notes.count }.sorted()
            if noteIndexes != nis {
                noteIndexes = nis
                let nivs = noteIndexes.map {
                    IndexValue(value: model.score.notes[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertDraftNotes(nivs),
                                    redoItem: .removeDraftNotes(noteIndexes: nis),
                                    isReversed: isUndo)
            }
        case .insertContents(var civs):
            updateFirstReverse()
            var isChanged = false, contentsCount = model.contents.count
            civs.enumerated().forEach { (k, iv) in
                if iv.index > contentsCount {
                    civs[k].index = contentsCount
                    isChanged = true
                }
                contentsCount += 1
            }
            if isChanged {
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .removeContents(contentIndexes: civs.map { $0.index }),
                                    redoItem: .insertContents(civs),
                                    isReversed: isUndo)
            }
        case .replaceContents(let civs):
            updateFirstReverse()
            var isError = false
            func error() {
                history[result.version]
                    .values[result.valueIndex].error()
                isError = true
            }
            let contents = model.contents
            var oldCIVs = [IndexValue<Content>]()
            for civ in civs {
                if civ.index >= contents.count {
                    error()
                    break
                }
                oldCIVs.append(IndexValue(value: contents[civ.index],
                                          index: civ.index))
            }
            if !isError {
                switch result.type {
                case .undo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.redoItem = .replaceContents(oldCIVs)
                case .redo:
                    history[result.version].values[result.valueIndex]
                        .undoItemValue?.undoItem = .replaceContents(oldCIVs)
                }
            }
        case .removeContents(var contentIndexes):
            updateFirstReverse()
            let cis = contentIndexes.filter { $0 < model.contents.count }.sorted()
            if contentIndexes != cis {
                contentIndexes = cis
                let civs = contentIndexes.map {
                    IndexValue(value: model.contents[$0], index: $0)
                }
                history[result.version].values[result.valueIndex].saveUndoItemValue
                    = UndoItemValue(undoItem: .insertContents(civs),
                                    redoItem: .removeContents(contentIndexes: cis),
                                    isReversed: isUndo)
            }
        case .setScoreOption:
            let oldOption = model.score.option
            switch result.type {
            case .undo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.redoItem = .setScoreOption(oldOption)
            case .redo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.undoItem = .setScoreOption(oldOption)
            }
        }
    }
    
    func textTuple(at p: Point) -> (textView: SheetTextView,
                                    textIndex: Int,
                                    stringIndex: String.Index,
                                    cursorIndex: String.Index)? {
        var n: (textView: SheetTextView,
                textIndex: Int,
                stringIndex: String.Index,
                cursorIndex: String.Index)?
        var minD = Double.infinity
        for (ti, textView) in textsView.elementViews.enumerated() {
            if textView.transformedBounds?.contains(p) ?? false {
                let inP = textView.convert(p, from: node)
                if let i = textView.characterIndex(for: inP),
                   let cr = textView.characterRatio(for: inP) {
                    
                    let sri = cr > 0.5 ?
                        textView.typesetter.index(after: i) : i
                    
                    let np = textView.typesetter.characterPosition(at: sri)
                    let d = p.distanceSquared(textView.convert(np, to: node))
                    if d < minD {
                        minD = d
                        n = (textView, ti, i, sri)
                    }
                }
            }
        }
        return n
    }
    
    func lineTuple(at p: Point, enabledPlane: Bool = false,
                   removingUUColor: UUColor? = nil,
                   scale: Double) -> (lineView: SheetLineView,
                                      lineIndex: Int)? {
        guard let v = lineTuple(at: p, enabledPlane: enabledPlane, removingUUColor: removingUUColor,
                                enabledPreviousNext: false, scale: scale) else { return nil }
        return (v.lineView, v.lineI)
    }
    func lineTuple(at p: Point, enabledPlane: Bool = false,
                   removingUUColor: UUColor? = nil,
                   enabledPreviousNext: Bool,
                   minEnabledDistance med: Double = 10,
                   scale: Double) -> (lineView: SheetLineView, lineI: Int, rootKeyframeI: Int)? {
        let isNoneDefaultColorPlane = !model.picture.planes.isEmpty
        && sheetColorOwnerFromPlane(at: p).uuColor != Sheet.defalutBackgroundUUColor
        let smallScale: Double? = if enabledPlane && isNoneDefaultColorPlane {
            8.0
        } else if textTuple(at: p) != nil {
            2.0
        } else {
            nil
        }
        
        let ds = Line.defaultLineWidth * 6 * scale
        var minI: Int?, minRKI: Int?, minDSquared = Double.infinity
        func update(at i: Int, rki: Int, dp: Point = .init(), isPNLine: Bool = false,
                    from line: Line) -> (lineView: SheetLineView, lineI: Int, rootKeyframeI: Int)? {
            guard line.uuColor != removingUUColor else { return nil }
            if line.uuColor != Line.defaultUUColor && isNoneDefaultColorPlane {
                if line.containsPressure(at: p - dp) {
                    return (linesView.elementViews[i], i, rki)
                }
            } else {
                let nd = smallScale != nil ?
                (line.size / 2 + ds) / smallScale! : line.size / 2 + ds * 5
                let ldSquared = nd * nd
                let mdSquared = line.minDistanceSquared(at: p - dp)
                let dSquared = isPNLine ?
                (min(mdSquared, Edge(line.firstPoint, line.firstPoint - dp).distanceSquared(from: p - dp))) :
                mdSquared
                if dSquared < minDSquared && dSquared < ldSquared {
                    minI = i
                    minRKI = rki
                    minDSquared = dSquared
                }
            }
            return nil
        }
        let rki = model.animation.rootIndex
        for (i, line) in model.picture.lines.enumerated().reversed() {
            if let n = update(at: i, rki: rki, from: line) {
                return n
            }
        }
        
        let mds = med * scale
        if enabledPreviousNext && minDSquared >= mds * mds && model.animation.keyframes.count > 1 {
            let isPNLine = bounds.contains(p) && !bounds.inset(by: 5 * scale).contains(p)
            let pn = model.animation.previousNext
            if pn == .previous || pn == .previousAndNext {
                let pP = model.animation.currentKeyframe.previousPosition
                let rii = model.animation.rootInterIndex - 1
                let ki = model.animation.index(atRootInter: rii)
                let ri = model.animation.rootIndex(atRootInter: rii)
                let keyframe = model.animation.keyframes[ki]
                for (i, line) in keyframe.picture.lines.enumerated().reversed() {
                    if let n = update(at: i, rki: ri, dp: pP, isPNLine: isPNLine, from: line) {
                        return n
                    }
                }
            }
            if pn == .next || pn == .previousAndNext {
                let nP = model.animation.currentKeyframe.nextPosition
                let rii = model.animation.rootInterIndex + 1
                let ki = model.animation.index(atRootInter: rii)
                let ri = model.animation.rootIndex(atRootInter: rii)
                let keyframe = model.animation.keyframes[ki]
                for (i, line) in keyframe.picture.lines.enumerated().reversed() {
                    if let n = update(at: i, rki: ri, dp: nP, isPNLine: isPNLine, from: line) {
                        return n
                    }
                }
            }
        }
        
        if let i = minI, let rki = minRKI {
            let linesView = rki == model.animation.rootIndex ?
            self.linesView :
            animationView.elementViews[model.animation.index(atRoot: rki)].linesView
            return (linesView.elementViews[i], i, rki)
        } else {
            return nil
        }
    }
    
    func lineIndexes(from selections: [Selection]) -> [Int] {
        linesView.elementViews.enumerated().compactMap { (li, lineView) in
            if selections.contains(where: {
                lineView.intersects(convertFromWorld($0.rect))
            }) { li } else { nil }
        }
    }
    func planeIndexes(from selections: [Selection]) -> [Int] {
        planesView.elementViews.enumerated().compactMap { (pi, planeView) in
            if selections.contains(where: {
                Path(convertFromWorld($0.rect))
                    .contains(planeView.node.path)
            }) { pi } else { nil }
        }
    }
    func textIndexes(from selections: [Selection]) -> [Int] {
        textsView.elementViews.enumerated().compactMap { (ti, textView) in
            if textView.transformedBounds != nil, selections.contains(where: {
                let nRect = textView.convertFromWorld($0.rect)
                guard textView.intersectsHalf(nRect) else { return false }
                let tfp = textView.convertFromWorld($0.firstOrigin)
                let tlp = textView.convertFromWorld($0.lastOrigin)
                guard textView.characterIndexWithOutOfBounds(for: tfp) != nil,
                      textView.characterIndexWithOutOfBounds(for: tlp) != nil else { return false }
                return true
            }) { ti } else { nil }
        }
    }
    func contentIndexes(from selections: [Selection]) -> [Int] {
        contentsView.elementViews.enumerated().compactMap { (ci, contentView) in
            if let b = contentView.transformedBounds, selections.contains(where: {
                Path(convertFromWorld($0.rect))
                    .intersects(b)
            }) { ci } else { nil }
        }
    }
    func noteIndexes(from selections: [Selection]) -> [Int] {
        let fs = selections
            .map { $0.rect }
            .map { scoreView.convertFromWorld($0) }
        return (0 ..< scoreView.model.notes.count).compactMap { i in
            fs.contains(where: { scoreView.intersectsNote($0, at: i) }) ? i : nil
        }
    }
    func containedNotes(from selections: [Selection]) -> [Int] {
        let fs = selections
            .map { $0.rect }
            .map { scoreView.convertFromWorld($0) }
        return (0 ..< scoreView.model.notes.count).compactMap { i in
            fs.contains(where: { scoreView.containsNote($0, at: i) }) ? i : nil
        }
    }
    func noteAndPitIndexes(from selections: [Selection], enabledAllPits: Bool = true) -> [Int: [Int]] {
        let fs = selections
            .map { $0.rect }
            .map { scoreView.convertFromWorld($0) }
        return scoreView.model.notes.enumerated().reduce(into: [Int: [Int]]()) { (n, v) in
            let noteI = v.offset, note = v.element
            let pitIs = note.pits.enumerated().compactMap { (pitI, pit) in
                fs.contains(where: { $0.contains(scoreView.pitPosition(atPit: pitI, from: note)) }) ?
                pitI : nil
            }
            
            if pitIs.isEmpty {
                if enabledAllPits && fs.contains(where: { scoreView.intersectsNote($0, at: noteI) }) {
                    n[noteI] = note.pits.count.array
                }
            } else {
                n[noteI] = pitIs
            }
        }
    }
    func noteAndPitAndSprolIs(from selections: [Selection], enabledAll: Bool = true) -> [Int: [Int: Set<Int>]] {
        let fs = selections
            .map { $0.rect }
            .map { scoreView.convertFromWorld($0) }
        return scoreView.model.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) { (n, v) in
            let noteI = v.offset, note = v.element
            
            let toneFrames = scoreView.toneFrames(from: note)
            n[noteI] = toneFrames.reduce(into: .init()) { (v, tf) in
                tf.pitIs.forEach { pitI in
                    let pit = note.pits[pitI]
                    for sprolI in pit.tone.spectlope.sprols.count.range {
                        if fs.contains(where: { $0.contains(scoreView.sprolPosition(atSprol: sprolI, atPit: pitI, at: noteI, atY: tf.frame.minY)) }) {
                            if v[pitI] != nil {
                                v[pitI]?.insert(sprolI)
                            } else {
                                v[pitI] = [sprolI]
                            }
                        }
                    }
                }
            }
        }
    }
    func isStraight(from selections: [Selection], atPit pitI: Int, at note: Note) -> Bool {
        let fs = selections
            .map { $0.rect }
            .map { scoreView.convertFromWorld($0) }
        if !fs.contains(where: { $0.contains(scoreView.pitPosition(atPit: pitI, from: note)) }) {
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
    func draftNoteIndexes(from selections: [Selection]) -> [Int] {
        let fs = selections
            .map { $0.rect }
            .map { scoreView.convertFromWorld($0) }
        return (0 ..< scoreView.model.draftNotes.count).compactMap { i in
            fs.contains(where: { scoreView.intersectsDraftNote($0, at: i) }) ? i : nil
        }
    }
    
    func autoUUColor(with uuColors: [UUColor],
                     baseUUColor: UUColor = UU(Color(lightness: 85)),
                     lRanges: [ClosedRange<Double>] = [0.78 ... 0.8,
                                                       0.82 ... 0.84,
                                                       0.86 ... 0.88,
                                                       0.9 ... 0.92]) -> UUColor {
        var vs = Array(repeating: false, count: lRanges.count)
        uuColors.forEach {
            for (i, lRange) in lRanges.enumerated() {
                if lRange.contains($0.value.lightness) {
                    vs[i] = true
                }
            }
        }
        var uuColor = baseUUColor
        uuColor.value.lightness = Double.random(in: lRanges[vs.firstIndex(of: false) ?? 0])
        return uuColor
    }
    
    func capture(intRange: Range<Int>, subString: String,
                 captureString: String, captureOrigin: Point?,
                 captureSize: Double?, captureWidthCount: Double?,
                 at i: Int, in textView: SheetTextView) {
        let oldIntRange = intRange.lowerBound ..< (intRange.lowerBound + subString.count)
        let range = captureString.range(fromInt: intRange)
        
        let newOrigin, oldOrigin: Point?
        if let captureOrigin = captureOrigin,
           captureOrigin != textView.model.origin {
            newOrigin = textView.model.origin
            oldOrigin = captureOrigin
        } else {
            newOrigin = nil
            oldOrigin = nil
        }
        
        let newSize, oldSize: Double?
        if let captureSize = captureSize,
           captureSize != textView.model.size {
            newSize = textView.model.size
            oldSize = captureSize
        } else {
            newSize = nil
            oldSize = nil
        }
        
        let newWidthCount, oldWidthCount: Double?
        if let captureWidthCount = captureWidthCount,
           captureWidthCount != textView.model.widthCount {
            newWidthCount = textView.model.widthCount
            oldWidthCount = captureWidthCount
        } else {
            newWidthCount = nil
            oldWidthCount = nil
        }
        
        let otv = TextValue(string: String(captureString[range]),
                            replacedRange: oldIntRange,
                            origin: oldOrigin, size: oldSize,
                            widthCount: oldWidthCount)
        let tv = TextValue(string: subString,
                           replacedRange: intRange,
                           origin: newOrigin, size: newSize,
                           widthCount: newWidthCount)
        capture(IndexValue(value: tv, index: i),
                old: IndexValue(value: otv, index: i))
    }
    func capture(captureOrigin: Point,
                 at i: Int, in textView: SheetTextView) {
        let newOrigin = textView.model.origin
        guard newOrigin != captureOrigin else { return }
        let oldOrigin = captureOrigin
        
        let otv = TextValue(string: "", replacedRange: 0 ..< 0,
                            origin: oldOrigin, size: nil, widthCount: nil)
        let tv = TextValue(string: "", replacedRange: 0 ..< 0,
                           origin: newOrigin, size: nil, widthCount: nil)
        capture(IndexValue(value: tv, index: i),
                old: IndexValue(value: otv, index: i))
    }
    
    func lassoErase(with lasso: Lasso,
                    distance d: Double = 0,
                    isSplitLine: Bool = true,
                    isRemove: Bool,
                    isEnableLine: Bool = true,
                    isEnablePlane: Bool = true,
                    isEnableText: Bool = true,
                    selections: [Selection] = [],
                    isDraft: Bool = false,
                    isUpdateUndoGroup: Bool = false) -> SheetValue? {
        guard let nlb = lasso.bounds else { return nil }
        guard node.bounds?.intersects(nlb) ?? false else { return nil }
        
        var isUpdateUndoGroup = isUpdateUndoGroup
        func updateUndoGroup() {
            if !isUpdateUndoGroup {
                newUndoGroup()
                isUpdateUndoGroup = true
            }
        }
        
        var ssValue = SheetValue(id: id,
                                 rootKeyframeIndex: model.animation.rootIndex)
        
        if !selectedFrameIndexes.isEmpty {
            let sfis = selectedFrameIndexes.sorted()
            
            var nis = [Int]()
            let sfisSet = Set(sfis)
            for (i, keyframeView) in animationView.elementViews.enumerated() {
                
                guard sfisSet.contains(i) else { continue }
                
                ssValue.keyframes.append(keyframeView.model)
                
                nis.append(i)
            }
            
            guard !nis.isEmpty else { return nil }
            
            let bi = nis.firstIndex(of: model.animation.index) ?? 0
            ssValue.keyframeBeganIndex = bi
            
            return ssValue.isEmpty ? nil : ssValue
        }
        
        let nPath = lasso.line.path(isClosed: true, isPolygon: false)
        
        if isEnableLine {
            let linesView = isDraft ? self.draftLinesView : self.linesView
            if !isSplitLine {
                let indexValues: [IndexValue<Line>] = linesView.elementViews.enumerated().compactMap { (li, lineView) in
                    if selections.contains(where: {
                        lineView.intersects(convertFromWorld($0.rect))
                    }) {
                        return IndexValue(value: lineView.model, index: li)
                    } else {
                        return nil
                    }
                }
                if !indexValues.isEmpty {
                    if isRemove {
                        updateUndoGroup()
                        if isDraft {
                            self.removeDraftLines(at: indexValues.map { $0.index })
                        } else {
                            self.removeLines(at: indexValues.map { $0.index })
                        }
                    }
                    ssValue.lines += indexValues.map { $0.value }
                }
            } else {
                var removeLines = [Line](), splitedLines = [Line]()
                var removeLineIndexes = [Int]()
                let nSplitLines: [Line], nd: Double
                if d > 0 {
                    let snlb = nlb.outset(by: d + 0.0001)
                    let splitLines = linesView.model.filter {
                        $0.bounds?.outset(by: $0.size / 2).intersects(snlb) ?? false
                    }
                    if splitLines.count < 50 {
                        let count = splitLines.reduce(0) {
                            lasso.intersects($1) ? $0 + 1 : $0
                        }
                        nd = count <= 3 ? d * 2 : d
                        nSplitLines = splitLines
                    } else {
                        nd = d
                        nSplitLines = []
                    }
                } else {
                    nd = d
                    nSplitLines = []
                }
                for (i, aLine) in linesView.model.enumerated() {
                    if let splitedLine = lasso
                        .splitedLine(with: aLine,
                                     splitLines: nSplitLines,
                                     distance: nd) {
                        switch splitedLine {
                        case .around(let line):
                            removeLineIndexes.append(i)
                            removeLines.append(line)
                        case .split((let aRemoveLines, var aSplitLines)):
                            removeLineIndexes.append(i)
                            removeLines += aRemoveLines
                            if !aSplitLines.isEmpty {
                                let idI: Int
                                if aSplitLines.count == 1 {
                                    idI = 0
                                } else {
                                    var maxD = 0.0, j = 0
                                    for (k, l) in aSplitLines.enumerated() {
                                        let d = l.length()
                                        if d > maxD {
                                            j = k
                                            maxD = d
                                        }
                                    }
                                    idI = j
                                }
                                for i in aSplitLines.count.range {
                                    if i == idI {
                                        aSplitLines[idI].id = aLine.id
                                        aSplitLines[idI].interType = aLine.interType
                                    } else {
                                        aSplitLines[i].id = .init()
                                    }
                                }
                                
                                splitedLines += aSplitLines
                            }
                        }
                    }
                }
                if isRemove && (!removeLineIndexes.isEmpty || !splitedLines.isEmpty) {
                    updateUndoGroup()
                    if !removeLineIndexes.isEmpty {
                        if isDraft {
                            self.removeDraftLines(at: removeLineIndexes)
                        } else {
                            self.removeLines(at: removeLineIndexes)
                        }
                    }
                    if isDraft {
                        insertDraft(splitedLines.enumerated().map {
                            IndexValue(value: $0.element, index: $0.offset)
                        })
                    } else {
                        append(splitedLines)
                    }
                }
                ssValue.lines = removeLines
            }
        }
        
        if isEnablePlane {
            let planesView = isDraft ? self.draftPlanesView : self.planesView
            let indexValues = planesView.elementViews.enumerated().compactMap {
                nPath.contains($0.element.node.path) ?
                    IndexValue(value: $0.element.model, index: $0.offset) : nil
            }
            if !indexValues.isEmpty {
                if isRemove {
                    updateUndoGroup()
                    if isDraft {
                        removeDraftPlanes(at: indexValues.map { $0.index })
                    } else {
                        removePlanes(at: indexValues.map { $0.index })
                    }
                }
                ssValue.planes += indexValues.map { $0.value }
            }
            if isRemove {
                let iSet = Set(indexValues.map { $0.index })
                var repPlanes = [IndexValue<Plane>]()
                for (i, planeView) in planesView.elementViews.enumerated() {
                    guard !iSet.contains(i) else { continue }
                    var plane = planeView.model
                    if !plane.topolygon.holePolygons.isEmpty {
                        var nHolePolygons = plane.topolygon.holePolygons, isRemove = false
                        for (j, holePolygon) in plane.topolygon.holePolygons.enumerated().reversed() {
                            if nPath.contains(Path(holePolygon)) {
                                nHolePolygons.remove(at: j)
                                isRemove = true
                            }
                        }
                        if isRemove {
                            plane.topolygon.holePolygons = nHolePolygons
                            repPlanes.append(IndexValue(value: plane, index: i))
                        }
                    }
                }
                if !repPlanes.isEmpty {
                    updateUndoGroup()
                    removePlanes(at: repPlanes.map { $0.index })
                    insert(repPlanes)
                }
            }
        }
        
        if isEnableText {
            for (ti, textView) in textsView.elementViews.enumerated().reversed() {
                
                guard textView.transformedBounds.intersects(nlb) else { continue }
                var ranges = [Range<String.Index>]()
                if !selections.isEmpty {
                    let string = textView.model.string
                    var isFilleds = [Bool](repeating: false, count: string.count)
                    for selection in selections {
                        let nRect = textView.convertFromWorld(selection.rect)
                        let tfp = textView.convertFromWorld(selection.firstOrigin)
                        let tlp = textView.convertFromWorld(selection.lastOrigin)
                        if textView.intersectsHalf(nRect),
                           let fi = textView.characterIndexWithOutOfBounds(for: tfp),
                           let li = textView.characterIndexWithOutOfBounds(for: tlp) {
                            
                            let ifi = string.intIndex(from: fi)
                            let ili = string.intIndex(from: li)
                            for i in (ifi < ili ? ifi ..< ili : ili ..< ifi) {
                                isFilleds[i] = true
                            }
                        }
                    }
                    var fi: Int?
                    for (i, isFilled) in isFilleds.enumerated() {
                        if isFilled {
                            if fi == nil {
                                fi = i
                            }
                        } else if let nfi = fi {
                            let sfi = string.index(fromInt: nfi)
                            let sli = string.index(fromInt: i)
                            ranges.append(sfi ..< sli)
                            fi = nil
                        }
                    }
                    if let nfi = fi {
                        let sfi = string.index(fromInt: nfi)
                        ranges.append(sfi ..< string.endIndex)
                    }
                } else {
                    for typeline in textView.typesetter.typelines {
                        let tlRange = typeline.range
                        var oldI: String.Index?
                        var isRemoveAll = true
                        
                        let range: Range<String.Index>
                        if !typeline.isReturnEnd {
                            range = tlRange
                        } else if tlRange.lowerBound < tlRange.upperBound {
                            range = tlRange.lowerBound ..< tlRange.upperBound
                        } else { continue }
                        
                        for i in textView.model.string[range].indices {
                            let tb = textView.typesetter
                                .characterBounds(at: i)!
                                .outset(by: textView.lassoPadding)
                                + textView.model.origin
                            if nPath.intersects(tb) {
                                if oldI == nil {
                                    oldI = i
                                }
                            } else {
                                isRemoveAll = false
                                if let oldI = oldI {
                                    ranges.append(oldI ..< i)
                                }
                                oldI = nil
                            }
                        }
                        if isRemoveAll {
                            ranges.append(tlRange)
                        } else if let oldI = oldI, oldI < range.upperBound {
                            ranges.append(oldI ..< range.upperBound)
                        }
                        oldI = nil
                    }
                }
                
                guard !ranges.isEmpty else { continue }
                
                var minP = textView.typesetter
                    .characterPosition(at: textView.model.string.startIndex)
                var minI = textView.model.string.endIndex
                for range in ranges {
                    let i = range.lowerBound
                    if i < minI {
                        minI = i
                        minP = textView.typesetter
                            .characterPosition(at: i)
                    }
                }
                let oldText = textView.model
                var text = textView.model
                var removedText = text
                removedText.string = ""
                for range in ranges {
                    removedText.string += text.string[range]
                }
                for range in ranges.reversed() {
                    text.string.removeSubrange(range)
                }
                removedText.origin += minP
                
                if isRemove {
                    if text.string.isEmpty {
                        updateUndoGroup()
                        removeText(at: ti)
                    } else {
                        let os = oldText.string
                        let range = os
                            .intRange(from: os.startIndex ..< os.endIndex)
                        
                        let sb = bounds.inset(by: Sheet.textPadding)
                        let origin: Point?
                        if let textFrame = text.frame,
                           !sb.contains(textFrame) {
                           
                            let nFrame = sb.clipped(textFrame)
                            origin = text.origin + nFrame.origin - textFrame.origin
                        } else {
                            origin = nil
                        }
                        
                        let tuv = TextValue(string: text.string,
                                            replacedRange: range,
                                            origin: origin, size: nil,
                                            widthCount: nil)
                        updateUndoGroup()
                        replace(IndexValue(value: tuv, index: ti))
                    }
                }
                
                ssValue.texts.append(removedText)
            }
        }
        
        return ssValue.isEmpty ? nil : ssValue
    }
    
    func copy(with line: Line?, at p: Point, isRemove: Bool = false) {
        if let line = line {
            if let value = lassoErase(with: Lasso(line: line),
                                      isRemove: isRemove) {
                let t = Transform(translation: -convertFromWorld(p))
                Pasteboard.shared.copiedObjects = [.sheetValue(value * t)]
            } else {
                Pasteboard.shared.copiedObjects = []
            }
        } else {
            let ssv = SheetValue(lines: model.picture.lines,
                                 planes: model.picture.planes,
                                 texts: model.texts,
                                 id: id,
                                 rootKeyframeIndex: model.animation.rootIndex)
            if !ssv.isEmpty {
                if isRemove {
                    newUndoGroup()
                    if !model.picture.isEmpty {
                        set(Picture())
                    }
                    if !model.texts.isEmpty {
                        removeText(at: Array(0 ..< model.texts.count))
                    }
                }
                let t = Transform(translation: -convertFromWorld(p))
                Pasteboard.shared.copiedObjects = [.sheetValue(ssv * t)]
            } else {
                Pasteboard.shared.copiedObjects = []
            }
        }
    }
    func changeToDraft(withLineInexes lis: [Int], planeInexes pis: [Int]) {
        if !lis.isEmpty {
            let lines = model.picture.lines[lis]
            removeLines(at: lis)
            let li = model.draftPicture.lines.count
            insertDraft(lines.enumerated().map {
                IndexValue(value: $0.element, index: li + $0.offset)
            })
        }
        if !pis.isEmpty {
            let planes = model.picture.planes[pis]
            removePlanes(at: pis)
            let pi = model.draftPicture.planes.count
            insertDraft(planes.enumerated().map {
                IndexValue(value: $0.element, index: pi + $0.offset)
            })
        }
    }
    func changeToDraft(with line: Line?) {
        if let line = line {
            if let value = lassoErase(with: Lasso(line: line),
                                      isRemove: true, isEnableText: false) {
                if !value.lines.isEmpty {
                    let li = model.draftPicture.lines.count
                    insertDraft(value.lines.enumerated().map {
                        IndexValue(value: $0.element, index: li + $0.offset)
                    })
                }
                if !value.planes.isEmpty {
                    let pi = model.draftPicture.planes.count
                    insertDraft(value.planes.enumerated().map {
                        IndexValue(value: $0.element, index: pi + $0.offset)
                    })
                }
            }
        } else {
            if !selectedFrameIndexes.isEmpty {
                newUndoGroup()
                let sfis = selectedFrameIndexes.sorted()
                
                insertDraftKeyLines(sfis.compactMap {
                    let lines = model.animation.keyframes[$0].picture.lines
                    let oldLines = model.animation.keyframes[$0].draftPicture.lines
                    let li = oldLines.count
                    let value = lines.enumerated().map {
                        IndexValue(value: $0.element,
                                   index: li + $0.offset)
                    }
                    return lines.isEmpty ?
                        nil :
                        IndexValue(value: value, index: $0)
                })
                insertDraftKeyPlanes(sfis.compactMap {
                    let planes = model.animation.keyframes[$0].picture.planes
                    let oldPlanes = model.animation.keyframes[$0].draftPicture.planes
                    let pi = oldPlanes.count
                    let value = planes.enumerated().map {
                        IndexValue(value: $0.element,
                                   index: pi + $0.offset)
                    }
                    return planes.isEmpty ?
                        nil :
                        IndexValue(value: value, index: $0)
                })
                removeKeyLines(sfis.compactMap {
                    let lines = model.animation.keyframes[$0].picture.lines
                    return lines.isEmpty ?
                        nil :
                    IndexValue(value: Array(0 ..< lines.count), index: $0)
                })
                removeKeyPlanes(sfis.compactMap {
                    let planes = model.animation.keyframes[$0].picture.planes
                    return planes.isEmpty ?
                        nil :
                    IndexValue(value: Array(0 ..< planes.count), index: $0)
                })
                return
            }
            
            if !model.picture.isEmpty {
                if model.draftPicture.isEmpty {
                    newUndoGroup()
                    
                    changeToDraft()
                } else {
                    newUndoGroup()
                    if !model.picture.lines.isEmpty {
                        let li = model.draftPicture.lines.count
                        insertDraft(model.picture.lines.enumerated().map {
                            IndexValue(value: $0.element, index: li + $0.offset)
                        })
                    }
                    if !model.picture.planes.isEmpty {
                        let pi = model.draftPicture.planes.count
                        insertDraft(model.picture.planes.enumerated().map {
                            IndexValue(value: $0.element, index: pi + $0.offset)
                        })
                    }
                    set(Picture())
                }
            }
        }
    }
    func removeDraft(with line: Line, at p: Point) -> SheetValue? {
        if let value = lassoErase(with: Lasso(line: line),
                                  isRemove: true,
                                  isEnableText: false,
                                  isDraft: true) {
            let t = Transform(translation: -convertFromWorld(p))
            return value * t
        }
        return nil
    }
    func cutDraft(with line: Line?, at p: Point) {
        if let line = line {
            if let value = lassoErase(with: Lasso(line: line),
                                      isRemove: true,
                                      isEnableText: false,
                                      isDraft: true) {
                let t = Transform(translation: -convertFromWorld(p))
                Pasteboard.shared.copiedObjects = [.sheetValue(value * t)]
            }
        } else {
            if !selectedFrameIndexes.isEmpty {
                newUndoGroup()
                let sfis = selectedFrameIndexes.sorted()
                removeDraftKeyLines(sfis.compactMap {
                    let lines = model.animation.keyframes[$0].draftPicture.lines
                    return lines.isEmpty ?
                        nil :
                    IndexValue(value: Array(0 ..< lines.count), index: $0)
                })
                removeDraftKeyPlanes(sfis.compactMap {
                    let planes = model.animation.keyframes[$0].draftPicture.planes
                    return planes.isEmpty ?
                        nil :
                    IndexValue(value: Array(0 ..< planes.count), index: $0)
                })
                return
            }
            
            if !selectedFrameIndexes.isEmpty {
                newUndoGroup()
                for i in selectedFrameIndexes.sorted() {
                    if !animationView.elementViews[i].model.draftPicture.isEmpty {
                        setRootKeyframeIndex(rootKeyframeIndex: i)
                        removeDraft()
                        setRootKeyframeIndex(rootKeyframeIndex: i)
                    }
                }
                return
            }
            
            let object = PastableObject.picture(model.draftPicture)
            if !model.draftPicture.isEmpty {
                newUndoGroup()
                removeDraft()
                Pasteboard.shared.copiedObjects = [object]
            }
        }
    }
    
    func changeToDraft(withNoteInexes nis: [Int]) {
        if !nis.isEmpty {
            let notes = model.score.notes[nis]
            removeNote(at: nis)
            let ni = model.score.draftNotes.count
            insertDraft(notes.enumerated().map {
                IndexValue(value: $0.element, index: ni + $0.offset)
            })
        }
    }
    
    @MainActor
    func makeFaces(with path: Path?, isSelection: Bool) {
        if selectedFrameIndexes.isEmpty {
            makeFacesFromKeyframeIndex(with: path, isSelection: isSelection)
            return
        }
        
        let indexes = selectedFrameIndexes.sorted()
        let b = bounds, borders = model.borders
        let pictures = model.animation.keyframes[indexes].map { $0.picture }
        
        let progressPanel = ProgressPanel(message: "Making Faces".localized)
        node.root.show(progressPanel)
        let task = Task.detached {
            let progress = ActorProgress(total: indexes.count)
            let nPolyss = try? await withThrowingTaskGroup(of: (i: Int, polys: [Topolygon]).self,
                                                          returning: [[Topolygon]]?.self) { group in
                for i in indexes.count.range {
                    group.addTask(priority: .high) {
                        try Task.checkCancellation()
                        let v = pictures[i].makePolygons(inFrame: b, clipingPath: path,
                                                         borders: borders, isSelection: isSelection)
                        await progress.addCount()
                        Task(priority: .high) { @MainActor in
                            progressPanel.progress = await progress.fractionCompleted
                        }
                        return (i, v)
                    }
                }
                
                return try await group.reduce(into: .init(repeating: [], count: indexes.count)) {
                    $0[$1.i] = $1.polys
                }
            }
            Task { @MainActor in
                defer { progressPanel.closePanel() }
                guard let nPolyss, nPolyss.count == indexes.count else { return }
                self.newUndoGroup()
                for (j, i) in indexes.enumerated() {
                    autoreleasepool {
                        self.setRootKeyframeIndex(rootKeyframeIndex: i)
                        self.makeFacesFromKeyframeIndex(with: path,
                                                        topolygons: nPolyss[j],
                                                        isSelection: isSelection,
                                                        isNewUndoGroup: false)
                        self.setRootKeyframeIndex(rootKeyframeIndex: i)
                    }
                }
            }
        }
        progressPanel.cancelHandler = { task.cancel() }
    }
    func makeFacesFromKeyframeIndex(with path: Path?, isSelection: Bool,
                                    isNewUndoGroup: Bool = true) {
        let topolygons = model.picture.makePolygons(inFrame: bounds,
                                                    clipingPath: path,
                                                    borders: model.borders,
                                                    isSelection: isSelection)
        return makeFacesFromKeyframeIndex(with: path,
                                          topolygons: topolygons,
                                          isSelection: isSelection,
                                          isNewUndoGroup: isNewUndoGroup)
    }
    func makeFacesFromKeyframeIndex(with path: Path?, topolygons: [Topolygon],
                                    isSelection: Bool,
                                    isNewUndoGroup: Bool = true) {
        func enabledPlanes(at otherKI: Int) -> [Plane]? {
            let planes = model.animation.keyframes[otherKI].picture.planes
            return planes.isEmpty ? nil : planes
        }
        let b = bounds
        let result: Picture.AutoFillResult
        if model.enabledAnimation {
            func otherPlanes() -> [Plane]? {
                guard model.picture.planes.isEmpty else { return nil }
                let ki = model.animation.index
                let preKI = ki - 1 >= 0 ?ki - 1 : model.animation.keyframes.count - 1
                let nextKI = ki + 1 < model.animation.keyframes.count ?ki + 1 : 0
                return enabledPlanes(at: preKI) ?? enabledPlanes(at: nextKI)
            }
            result = Picture.autoFill(fromOther: otherPlanes(),
                                      from: topolygons,
                                      from: model.picture.planes,
                                      inFrame: b,
                                      clipingPath: path, borders: model.borders,
                                      isSelection: isSelection)
        } else {
            result = Picture.autoFill(from: topolygons,
                                      from: model.picture.planes,
                                      inFrame: b,
                                      clipingPath: path, borders: model.borders,
                                      isSelection: isSelection)
        }
        switch result {
        case .planes(let planes):
            if isNewUndoGroup {
                newUndoGroup()
            }
            append(planes)
        case .planeValue(let planeValue):
            if isNewUndoGroup {
                newUndoGroup()
            }
            set(planeValue)
        case .none: break
        }
    }
    func removeFilledFaces(with path: Path?, at p: Point) -> SheetValue? {
        var removePlaneValues = Array(planesView.elementViews.enumerated())
        if let path = path {
            removePlaneValues = removePlaneValues.filter {
                path.intersects($0.element.node.path)
            }
        }
        if !removePlaneValues.isEmpty {
            newUndoGroup()
            let planes = removePlaneValues.map { $0.element.model }
            let t = Transform(translation: -convertFromWorld(p))
            removePlanes(at: removePlaneValues.map { $0.offset })
            return SheetValue(lines: [], planes: planes, texts: []) * t
        } else {
            return nil
        }
    }
    func cutFaces(with path: Path?) {
        if !selectedFrameIndexes.isEmpty {
            newUndoGroup()
            removeKeyPlanes(selectedFrameIndexes.sorted().compactMap {
                let planes = model.animation.keyframes[$0].picture.planes
                return planes.isEmpty ?
                    nil :
                IndexValue(value: Array(0 ..< planes.count), index: $0)
            })
            return
        }
        
        var removePlaneValues = Array(planesView.elementViews.enumerated())
        if let path = path {
            removePlaneValues = removePlaneValues.filter {
                path.intersects($0.element.node.path)
            }
        }
        let isRemoveBackground
            = model.backgroundUUColor != Sheet.defalutBackgroundUUColor
            && path == nil
        
        if isRemoveBackground || !removePlaneValues.isEmpty {
            newUndoGroup()
            if !removePlaneValues.isEmpty {
                let planes = removePlaneValues.map { $0.element.model }
                Pasteboard.shared.copiedObjects
                    = [.planesValue(PlanesValue(planes: planes))]
                removePlanes(at: removePlaneValues.map { $0.offset })
            }
            if isRemoveBackground {
                let ncv = ColorValue(uuColor: Sheet.defalutBackgroundUUColor,
                                     planeIndexes: [], lineIndexes: [],
                                     isBackground: true,
                                     planeAnimationIndexes: [],
                                     lineAnimationIndexes: [],
                                     animationColors: [])
                let ocv = ColorValue(uuColor: model.backgroundUUColor,
                                     planeIndexes: [], lineIndexes: [],
                                     isBackground: true,
                                     planeAnimationIndexes: [],
                                     lineAnimationIndexes: [],
                                     animationColors: [])
                backgroundUUColor = ncv.uuColor
                capture(ncv, oldColorValue: ocv)
            }
        }
    }
}

final class SheetColorOwner {
    let sheetView: SheetView
    private(set) var colorValue: ColorValue
    let oldColorValue: ColorValue
    var uuColor: UUColor {
        get { colorValue.uuColor }
        set {
            colorValue.uuColor = newValue
            sheetView.set(colorValue)
        }
    }
    var oldUUColor: UUColor {
        oldColorValue.uuColor
    }
    
    init(sheetView: SheetView, colorValue: ColorValue) {
        self.sheetView = sheetView
        self.colorValue = colorValue
        oldColorValue = colorValue
    }
    
    func captureUUColor(isNewUndoGroup: Bool = true) {
        if isNewUndoGroup {
            sheetView.newUndoGroup()
        }
        sheetView.capture(colorValue, oldColorValue: oldColorValue)
    }
    func colorPathValue(toColor: Color?,
                        color: Color, subColor: Color) -> ColorPathValue {
        sheetView.colorPathValue(with: colorValue,
                                 toColor: toColor,
                                 color: color, subColor: subColor)
    }
}
