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

import struct Foundation.UUID

final class TextView<T: BinderProtocol>: TimelineView, @unchecked Sendable {
    typealias Model = Text
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    private(set) var typesetter: Typesetter
    
    var markedRange: Range<String.Index>?
    var replacedRange: Range<String.Index>?
    var selectedRange: Range<String.Index>?
    var selectedLineLocation = 0.0
    
    var isFullEdit = false {
        didSet {
            guard isFullEdit != oldValue else { return }
            if let node = timelineNode.children.first(where: { $0.name == "isFullEdit" }) {
                node.isHidden = !isFullEdit
            }
        }
    }
    
    var intSelectedLowerBound: Int? {
        if let i = selectedRange?.lowerBound {
            return model.string.intIndex(from: i)
        } else {
            return nil
        }
    }
    var intSelectedUpperBound: Int? {
        if let i = selectedRange?.upperBound {
            return model.string.intIndex(from: i)
        } else {
            return nil
        }
    }
    var selectedTypelineIndex: Int? {
        if let i = selectedRange?.lowerBound,
           let ti = typesetter.typelineIndex(at: i) {
            return ti
        } else {
            return typesetter.typelines.isEmpty ? nil :
                typesetter.typelines.count - 1
        }
    }
    var selectedTypeline: Typeline? {
        if let i = selectedRange?.lowerBound,
           let ti = typesetter.typelineIndex(at: i) {
            return typesetter.typelines[ti]
        } else {
            return typesetter.typelines.last
        }
    }
    
    let markedRangeNode = Node(lineWidth: 1, lineType: .color(.content))
    let replacedRangeNode = Node(lineWidth: 2, lineType: .color(.content))
    let cursorNode = Node(isHidden: true,
                          lineWidth: 0.5, lineType: .color(.background),
                          fillType: .color(.content))
    let borderNode = Node(isHidden: true,
                          lineWidth: 0.5, lineType: .color(.border))
    let clippingNode = Node(isHidden: true,
                            lineWidth: 4, lineType: .color(.warning))
    var isHiddenSelectedRange = true {
        didSet {
            cursorNode.isHidden = isHiddenSelectedRange
            borderNode.isHidden = isHiddenSelectedRange
        }
    }
    
    let id = UUID()
    
    let timelineNode = Node()
    var timeNode: Node?, currentPeakVolmNode: Node?
    var peakVolm = 0.0 {
        didSet {
            guard peakVolm != oldValue else { return }
            updateFromPeakVolm()
        }
    }
    func updateFromPeakVolm() {
        guard let node = currentPeakVolmNode, let frame = timelineFrame else { return }
        let y = frame.height * peakVolm
        node.path = Path([Point(), Point(0, y)])
        if peakVolm < Audio.headroomVolm {
            node.lineType = .color(.background)
        } else {
            node.lineType = .color(.warning)
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        typesetter = binder[keyPath: keyPath].typesetter
        
        node = Node(children: [markedRangeNode, replacedRangeNode,
                               cursorNode, borderNode, timelineNode, clippingNode],
                    attitude: Attitude(position: binder[keyPath: keyPath].origin),
                    fillType: .color(.content))
        updateLineWidth()
        updatePath()
        
        updateCursor()
        updateTimeline()
    }
}
extension TextView {
    func updateWithModel() {
        node.attitude.position = model.origin
        updateLineWidth()
        updateTypesetter()
    }
    func updateLineWidth() {
        let ratio = model.size / Font.defaultSize
        cursorNode.lineWidth = 0.5 * ratio
        borderNode.lineWidth = cursorNode.lineWidth
        markedRangeNode.lineWidth = Line.defaultLineWidth * ratio
        replacedRangeNode.lineWidth = Line.defaultLineWidth * 1.5 * ratio
    }
    func updateTypesetter() {
        typesetter = model.typesetter
        updatePath()
        
        updateMarkedRange()
        updateCursor()
        updateTimeline()
    }
    func updatePath() {
        node.path = typesetter.path()
        borderNode.path = typesetter.maxTypelineWidthPath
        
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
    
    func updateTimeline() {
        if let timeOption = model.timeOption {
            timelineNode.children = self.timelineNode(timeOption, from: typesetter)
            
            let timeNode = Node(lineWidth: 3, lineType: .color(.content))
            let volmNode = Node(lineWidth: 1, lineType: .color(.background))
            timeNode.append(child: volmNode)
            timelineNode.children.append(timeNode)
            self.timeNode = timeNode
            self.currentPeakVolmNode = volmNode
        } else if !timelineNode.children.isEmpty {
            timelineNode.children = []
            self.timeNode = nil
            self.currentPeakVolmNode = nil
        }
    }
    
    func set(_ timeOption: TextTimeOption?, origin: Point) {
        binder[keyPath: keyPath].timeOption = timeOption
        binder[keyPath: keyPath].origin = origin
        node.attitude.position = origin
        updateTimeline()
        updateClippingNode()
    }
    var timeOption: TextTimeOption? {
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
    
    var frameRate: Int { Keyframe.defaultFrameRate }
    
    var tempo: Rational {
        get { model.timeOption?.tempo ?? 0 }
        set {
            binder[keyPath: keyPath].timeOption?.tempo = newValue
            updateTimeline()
        }
    }
    
    var timelineCenterY: Double {
        (typesetter.firstReturnBounds?.minY ?? 0) + Sheet.timelineHalfHeight
    }
    var beatRange: Range<Rational>? {
        model.timeOption?.beatRange
    }
    var localBeatRange: Range<Rational>? {
        nil
    }
    
    func timelineNode(_ timeOption: TextTimeOption, from typesetter: Typesetter) -> [Node] {
        let sBeat = max(timeOption.beatRange.start, -10000),
            eBeat = min(timeOption.beatRange.end, 10000)
        let sx = self.x(atBeat: sBeat)
        let ex = self.x(atBeat: eBeat)
        
        let lw = 1.0
        let knobW = Sheet.knobWidth, knobH = Sheet.knobHeight
        let timelineHalfHeight = Sheet.timelineHalfHeight
        let rulerH = Sheet.rulerHeight
        
        let centerY = (typesetter.firstReturnBounds?.minY ?? 0) + timelineHalfHeight
        let sy = centerY - timelineHalfHeight
        let ey = centerY + timelineHalfHeight
        
        var contentPathlines = [Pathline]()
        var subBorderPathlines = [Pathline]()
        var fullEditBorderPathlines = [Pathline]()
        var borderPathlines = [Pathline]()
        
        contentPathlines.append(.init(Rect(x: sx - 1, y: centerY - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: ex - 1, y: centerY - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: sx + 1, y: centerY - lw / 2,
                                           width: ex - sx - 2, height: lw)))
        
        makeBeatPathlines(in: timeOption.beatRange, sy: sy, ey: ey,
                          subBorderPathlines: &subBorderPathlines,
                          fullEditBorderPathlines: &fullEditBorderPathlines,
                          borderPathlines: &borderPathlines)
        
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
        if !contentPathlines.isEmpty {
            nodes.append(Node(path: Path(contentPathlines),
                              fillType: .color(.content)))
        }
        
        return nodes
    }
    
    func updateTimeNode(atSec sec: Rational) {
        if let frame = timelineFrame, let timeNode {
            let x = self.x(atSec: sec)
            if x >= frame.minX && x < frame.maxX {
                timeNode.path = Path([Point(), Point(0, frame.height)])
                timeNode.attitude.position = Point(x, frame.minY)
            } else {
                timeNode.path = Path()
            }
        } else {
            timeNode?.path = Path()
        }
    }
    
    func containsTimeline(_ p : Point, scale: Double) -> Bool {
        timelineFrame?.outset(by: 3 * scale).contains(p) ?? false
    }
    var timelineFrame: Rect? {
        guard let timeOption = model.timeOption else { return nil }
        let sx = x(atBeat: timeOption.beatRange.start)
        let ex = x(atBeat: timeOption.beatRange.end)
        let y = typesetter.firstReturnBounds?.minY ?? 0
        return Rect(x: sx, y: y,
                    width: ex - sx, height: Sheet.timelineHalfHeight * 2)
    }
    var transformedTimelineFrame: Rect? {
        if var f = timelineFrame {
            f.origin.y += model.origin.y
            return f
        } else {
            return nil
        }
    }
    
    func contains(_ p: Point, scale: Double) -> Bool {
        containsTimeline(p, scale: scale)
        || (bounds?.contains(p) ?? false)
    }
    
    private func updateMarkedRange() {
        if let markedRange {
            var mPathlines = [Pathline]()
            let delta = markedRangeNode.lineWidth
            for edge in typesetter.underlineEdges(for: markedRange,
                                                  delta: delta) {
                mPathlines.append(Pathline(edge))
            }
            markedRangeNode.path = Path(mPathlines)
        } else {
            markedRangeNode.path = Path()
        }
        
        if let replacedRange {
            var rPathlines = [Pathline]()
            let delta = markedRangeNode.lineWidth
            for edge in typesetter.underlineEdges(for: replacedRange,
                                                  delta: delta) {
                rPathlines.append(Pathline(edge))
            }
            replacedRangeNode.path = Path(rPathlines)
        } else {
            replacedRangeNode.path = Path()
        }
    }
    func updateCursor() {
        if let selectedRange {
            cursorNode.path = typesetter.cursorPath(at: selectedRange.lowerBound)
        } else {
            cursorNode.path = Path()
        }
    }
    func updateSelectedLineLocation() {
        if let range = selectedRange {
            if let li = typesetter.typelineIndex(at: range.lowerBound) {
             selectedLineLocation = typesetter.typelines[li]
                 .characterOffset(at: range.lowerBound)
            } else {
             if let typeline = typesetter.typelines.last,
                range.lowerBound == typeline.range.upperBound {
                 if !typeline.isLastReturnEnd {
                    selectedLineLocation = typeline.width
                 } else {
                     selectedLineLocation = 0
                 }
             } else {
                selectedLineLocation = 0
             }
            }
        } else {
            selectedLineLocation = 0
        }
    }
    
    var bounds: Rect? {
        if let timelineFrame {
            let rect = typesetter.spacingTypoBoundsEnabledEmpty
            return timelineFrame.union(rect)
        } else {
            return typesetter.spacingTypoBoundsEnabledEmpty
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
            timelineFrame.union(typesetter.typoBounds)
        } else {
            typesetter.typoBounds
        }
    }
    var transformedClippableBounds: Rect? {
        if let bounds = clippableBounds {
            bounds * node.localTransform
        } else {
            nil
        }
    }
    
    func typoBounds(with textValue: TextValue) -> Rect? {
        let sRange = model.string.range(fromInt: textValue.newRange)
        return typesetter.typoBounds(for: sRange)
    }
    func transformedTypoBounds(with range: Range<String.Index>) -> Rect? {
        let b = typesetter.typoBounds(for: range)
        return if let b {
            b * node.localTransform
        } else {
            nil
        }
    }
    
    func transformedRects(with range: Range<String.Index>) -> [Rect] {
        typesetter.rects(for: range).map { $0 * node.localTransform }
    }
    func transformedPaddingRects(with range: Range<String.Index>) -> [Rect] {
        typesetter.paddingRects(for: range).map { $0 * node.localTransform }
    }
    
    var cursorPositon: Point? {
        guard let selectedRange = selectedRange else { return nil }
        return typesetter.characterPosition(at: selectedRange.lowerBound)
    }

    var isMarked: Bool {
        markedRange != nil
    }
    
    func characterIndexWithOutOfBounds(for p: Point) -> String.Index? {
        typesetter.characterIndexWithOutOfBounds(for: p)
    }
    func characterIndex(for p: Point) -> String.Index? {
        typesetter.characterIndex(for: p)
    }
    func characterRatio(for p: Point) -> Double? {
        typesetter.characterRatio(for: p)
    }
    func characterPosition(at i: String.Index) -> Point {
        typesetter.characterPosition(at: i)
    }
    func characterBasePosition(at i: String.Index) -> Point {
        typesetter.characterBasePosition(at: i)
    }
    func characterBounds(at i: String.Index) -> Rect? {
        typesetter.characterBounds(at: i)
    }
    func baselineDelta(at i: String.Index) -> Double {
        typesetter.baselineDelta(at: i)
    }
    func firstRect(for range: Range<String.Index>) -> Rect? {
        typesetter.firstRect(for: range)
    }
    
    var textOrientation: Orientation {
        model.orientation
    }
    
    func wordRange(at i: String.Index) -> Range<String.Index>? {
        let string = model.string
        var range: Range<String.Index>?
        string.enumerateSubstrings(in: string.startIndex ..< string.endIndex,
                                   options: .byWords) { (str, sRange, eRange, isStop) in
            if sRange.contains(i) {
                range = sRange
                isStop = true
            }
        }
        if i == string.endIndex {
            return nil
        }
        if let range = range, string[range] == "\n" {
            return nil
        }
        return range ?? i ..< string.index(after: i)
    }
    
    func intersects(_ rect: Rect) -> Bool {
        typesetter.intersects(rect)
    }
    func intersectsHalf(_ rect: Rect) -> Bool {
        typesetter.intersectsHalf(rect)
    }
    
    func ranges(at selection: Selection) -> [Range<String.Index>] {
        guard let fi = characterIndexWithOutOfBounds(for: selection.firstOrigin),
              let li = characterIndexWithOutOfBounds(for: selection.lastOrigin) else { return [] }
        return [fi < li ? fi ..< li : li ..< fi]
    }
    
    var copyPadding: Double {
        1 * model.size / Font.defaultSize
    }
    
    var lassoPadding: Double {
        -2 * typesetter.typobute.font.size / Font.defaultSize
    }
    func lassoRanges(at nPath: Path) -> [Range<String.Index>] {
        var ranges = [Range<String.Index>](), oldI: String.Index?
        for i in model.string.indices {
            guard let otb = typesetter.characterBounds(at: i) else { continue }
            let tb = otb.outset(by: lassoPadding) + model.origin
            if nPath.intersects(tb) {
                if oldI == nil {
                    oldI = i
                }
            } else {
                if let oldI = oldI {
                    ranges.append(oldI ..< i)
                }
                oldI = nil
            }
        }
        if let oldI = oldI {
            ranges.append(oldI ..< model.string.endIndex)
        }
        return ranges
    }
    
    func set(_ textValue: TextValue) {
        unmark()
        
        let oldRange = model.string.range(fromInt: textValue.replacedRange)
        binder[keyPath: keyPath].string
            .replaceSubrange(oldRange, with: textValue.string)
        let nri = model.string.range(fromInt: textValue.newRange).upperBound
        selectedRange = nri ..< nri
        
        if let origin = textValue.origin {
            binder[keyPath: keyPath].origin = origin
            node.attitude.position = origin
        }
        if let size = textValue.size {
            binder[keyPath: keyPath].size = size
        }
        if let widthCount = textValue.widthCount {
            binder[keyPath: keyPath].widthCount = widthCount
        }
        
        updateTypesetter()
        updateSelectedLineLocation()
    }
    
    func insertNewline() {
        guard let rRange = isMarked ?
                markedRange : selectedRange else { return }
        
        let string = model.string
        var str = "\n"
        loop: for (li, typeline) in typesetter.typelines.enumerated() {
            guard (typeline.range.contains(rRange.lowerBound)
                    || (li == typesetter.typelines.count - 1
                            && !typeline.isLastReturnEnd
                            && rRange.lowerBound == typeline.range.upperBound))
                    && !typeline.range.isEmpty else { continue }
            var i = typeline.range.lowerBound
            while i < typeline.range.upperBound {
                let c = string[i]
                if c != "\t" {
                    if rRange.lowerBound > typeline.range.lowerBound {
                        let i1 = string.index(before: rRange.lowerBound)
                        let c1 = string[i1]
                        if c1 == ":" {
                            str.append("\t")
                        } else {
                            if i1 > typeline.range.lowerBound {
                                let i2 = string.index(before: i1)
                                let c2 = string[i2]
                                
                                if i2 > typeline.range.lowerBound {
                                    let i3 = string.index(before: i2)
                                    if string[i3].isWhitespace
                                        && c2 == "-" && (c1 == ">" || c1 == "!") {
                                    
                                        str.append("\t")
                                    }
                                }
                            }
                        }
                    }
                    break loop
                } else {
                    if i < rRange.lowerBound {
                        str.append(c)
                    }
                }
                i = string.index(after: i)
            }
            break
        }
        insert(str)
    }
    func insertTab() {
        insert("\t")
    }
    
    func range(from selection: Selection) -> Range<String.Index>? {
        let nRect = convertFromWorld(selection.rect)
        let tfp = convertFromWorld(selection.firstOrigin)
        let tlp = convertFromWorld(selection.lastOrigin)
        if intersects(nRect),
           let fi = characterIndexWithOutOfBounds(for: tfp),
           let li = characterIndexWithOutOfBounds(for: tlp) {
            
            return fi < li ? fi ..< li : li ..< fi
        } else {
            return nil
        }
    }
    @discardableResult func delete(from selections: [Selection]) -> Bool {
        guard let deleteRange = selectedRange else { return false }
        for selection in selections {
            if let nRange = range(from: selection) {
                if nRange.contains(deleteRange.lowerBound)
                    || nRange.lowerBound == deleteRange.lowerBound
                    || nRange.upperBound == deleteRange.lowerBound {
                    removeCharacters(in: nRange)
                    return true
                }
            }
        }
        return false
    }
    
    func moveLeft() {
        guard let range = selectedRange else { return }
        if !range.isEmpty {
            selectedRange = range.lowerBound ..< range.lowerBound
        } else {
            let string = model.string
            guard range.lowerBound > string.startIndex else { return }
            let ni = typesetter.index(before: range.lowerBound)
            selectedRange = ni ..< ni
        }
        updateCursor()
        updateSelectedLineLocation()
    }
    func moveRight() {
        guard let range = selectedRange else { return }
        if !range.isEmpty {
            selectedRange = range.upperBound ..< range.upperBound
        } else {
            let string = model.string
            guard range.lowerBound < string.endIndex else { return }
            let ni = typesetter.index(after: range.lowerBound)
            selectedRange = ni ..< ni
        }
        updateCursor()
        updateSelectedLineLocation()
    }
    func moveUp() {
        guard let range = selectedRange else { return }
        guard let tli = typesetter
                .typelineIndex(at: range.lowerBound) else {
            if var typeline = typesetter.typelines.last,
               range.lowerBound == typeline.range.upperBound {
                let string = model.string
                let d = selectedLineLocation
                if !typeline.isLastReturnEnd {
                    let tli = typesetter.typelines.count - 1
                    if tli == 0 && d == typesetter.typelines[tli].width {
                        let si = model.string.startIndex
                        selectedRange = si ..< si
                        updateCursor()
                        return
                    }
                    let i = d < typesetter.typelines[tli].width ?
                        tli : tli - 1
                    typeline = typesetter.typelines[i]
                }
                let ni = typeline.characterIndex(forOffset: d, padding: 0)
                    ?? string.index(before: typeline.range.upperBound)
                selectedRange = ni ..< ni
                updateCursor()
            }
            return
        }
        if !range.isEmpty {
            selectedRange = range.lowerBound ..< range.lowerBound
        } else {
            let string = model.string
            let d = selectedLineLocation
            let isFirst = tli == 0
            let isSelectedLast = range.lowerBound == string.endIndex
                && d < typesetter.typelines[tli].width
            if !isSelectedLast, isFirst {
                let si = model.string.startIndex
                selectedRange = si ..< si
            } else {
                let i = isSelectedLast || isFirst ? tli : tli - 1
                let typeline = typesetter.typelines[i]
                let ni = typeline.characterMainIndex(forOffset: d, padding: 0,
                                                     from: typesetter)
                    ?? string.index(before: typeline.range.upperBound)
                selectedRange = ni ..< ni
            }
        }
        updateCursor()
    }
    func moveDown() {
        guard let range = selectedRange else { return }
        guard let li = typesetter
                .typelineIndex(at: range.lowerBound) else { return }
        if !range.isEmpty {
            selectedRange = range.upperBound ..< range.upperBound
        } else {
            let string = model.string
            let isSelectedFirst = range.lowerBound == string.startIndex
                && selectedLineLocation > 0
            let isLast = li == typesetter.typelines.count - 1
            if !isSelectedFirst, isLast {
               let ni = string.endIndex
               selectedRange = ni ..< ni
            } else {
                let i = isSelectedFirst || isLast ? li : li + 1
                let typeline = typesetter.typelines[i]
                let d = selectedLineLocation
                if let ni = typeline.characterMainIndex(forOffset: d, padding: 0,
                                                        from: typesetter) {
                    selectedRange = ni ..< ni
                } else {
                    let ni = i == typesetter.typelines.count - 1
                        && !typeline.isLastReturnEnd
                        ?
                        typeline.range.upperBound :
                        string.index(before: typeline.range.upperBound)
                    selectedRange = ni ..< ni
                }
            }
        }
        updateCursor()
    }
    
    func removeCharacters(in range: Range<String.Index>) {
        isHiddenSelectedRange = false
        
        if let markedRange = markedRange {
            let nRange: Range<String.Index>
            let string = model.string
            let d = string.count(from: range)
            if markedRange.contains(range.upperBound) {
                let nei = string.index(markedRange.upperBound, offsetBy: -d)
                nRange = range.lowerBound ..< nei
            } else {
                nRange = string.range(markedRange, offsetBy: -d)
            }
            if nRange.isEmpty {
                unmark()
            } else {
                self.markedRange = nRange
            }
        }
        
        let iMarkedRange: Range<Int>? = markedRange != nil ?
            model.string.intRange(from: markedRange!) : nil
        let iReplacedRange: Range<Int>? = replacedRange != nil ?
            model.string.intRange(from: replacedRange!) : nil
        let i = model.string.intIndex(from: range.lowerBound)
        binder[keyPath: keyPath].string.removeSubrange(range)
        let ni = model.string.index(fromInt: i)
        if let iMarkedRange = iMarkedRange {
            markedRange = model.string.range(fromInt: iMarkedRange)
        }
        if let iReplacedRange = iReplacedRange {
            replacedRange = model.string.range(fromInt: iReplacedRange)
        }
        selectedRange = ni ..< ni
        
        TextInputContext.update()
        updateTypesetter()
        updateSelectedLineLocation()
    }
    
    func unmark() {
        if isMarked {
            markedRange = nil
            replacedRange = nil
            TextInputContext.unmark()
            updateMarkedRange()
        }
    }
    func mark(_ str: String,
              markingRange: Range<String.Index>,
              at range: Range<String.Index>? = nil) {
        isHiddenSelectedRange = false
        
        let rRange: Range<String.Index>
        if let range = range {
            rRange = range
        } else if let markedRange = markedRange {
            rRange = markedRange
        } else if let selectedRange = selectedRange {
            rRange = selectedRange
        } else {
            return
        }
        
        TextInputContext.update()
        if str.isEmpty {
            let i = model.string.intIndex(from: rRange.lowerBound)
            binder[keyPath: keyPath].string.removeSubrange(rRange)
            let ni = model.string.index(fromInt: i)
            markedRange = nil
            replacedRange = nil
            selectedRange = ni ..< ni
        } else {
            let i = model.string.intIndex(from: rRange.lowerBound)
            let iMarkingRange = str.intRange(from: markingRange)
            binder[keyPath: keyPath].string.replaceSubrange(rRange, with: str)
            let ni = model.string.index(fromInt: i)
            let di = model.string.index(ni, offsetBy: str.count)
            let imsi = model.string.index(fromInt: iMarkingRange.lowerBound + i)
            let imei = model.string.index(fromInt: iMarkingRange.upperBound + i)
            markedRange = ni ..< di
            replacedRange = imsi ..< imei
            selectedRange = di ..< di
        }
        updateTypesetter()
        updateSelectedLineLocation()
    }
    func insert(_ str: String,
                at range: Range<String.Index>? = nil) {
        isHiddenSelectedRange = false
        
        let rRange: Range<String.Index>
        if let range = range {
            rRange = range
        } else if let markedRange = markedRange {
            rRange = markedRange
        } else if let selectedRange = selectedRange {
            rRange = selectedRange
        } else {
            return
        }
        
        unmark()
        TextInputContext.update()
        
        let irRange = model.string.intRange(from: rRange)
        binder[keyPath: keyPath].string.replaceSubrange(rRange, with: str)
        let ei = model.string.index(model.string.startIndex,
                                    offsetBy: irRange.lowerBound + str.count)
        selectedRange = ei ..< ei
        
        updateTypesetter()
        updateSelectedLineLocation()
    }
}
