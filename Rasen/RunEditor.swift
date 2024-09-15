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

import struct Foundation.Date
import struct Foundation.UUID
import struct Foundation.URL

final class Runner: InputKeyEditor, @unchecked Sendable {
    let editor: RunEditor
    
    init(_ document: Document) {
        editor = RunEditor(document, isDebug: false)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.send(event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class Debugger: InputKeyEditor, @unchecked Sendable {
    let editor: RunEditor
    
    init(_ document: Document) {
        editor = RunEditor(document, isDebug: true)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.send(event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class RunEditor: InputKeyEditor, @unchecked Sendable {
    let document: Document
    let isEditingSheet: Bool
    
    static let noFreeMemoryO = O(OError("No free memory".localized))
    
    var maxSheetByte = 100 * 1024 * 1024
    
    var runText = Text(), runTypobute = Typobute()
    var worldPrintOrigin = Point()
    
    var stepString = ""
    var stepNode = Node(fillType: .color(.content))
    var stepTimerTask: Task<Void, any Error>?
    
    var task: Task<O, Never>?
    
    let isDebug: Bool
    var debugString = ""
    var debugNode = Node(fillType: .color(.removing))
    struct DebugNodeValue {
        var isEmpty: Bool
        var stack = [O]()
        var node: Node
    }
    var debugNodeValues = [Point: DebugNodeValue]()
    var debugTexts = [(ID, O)]()
    var firstErrorNode: Node?
    var oldDebugNode: Node?
    var debugCount = 0 {
        didSet {
            guard debugCount <= debugTexts.count else { return }
            
            var newNode: Node?
            if oldValue < debugCount {
                for i in oldValue ..< debugCount {
                    newNode = draw(debugTexts[i].0, debugTexts[i].1,
                                   i == debugCount - 1 ? .selected : .removing)
                }
            } else if oldValue > debugCount {
                for i in (debugCount ..< oldValue).reversed() {
                    if let b = debugTexts[i].0.typoBounds {
                        if !(debugNodeValues[b.origin]?.stack.isEmpty ?? true) {
                            debugNodeValues[b.origin]?.stack.removeLast()
                        }
                        if let ls = debugNodeValues[b.origin]?.stack.last {
                            debugNodeValues[b.origin]?.stack.removeLast()
                            newNode = draw(debugTexts[i].0, ls, .removing)
                        } else {
                            drawEmpty(debugTexts[i].0)
                        }
                    } else {
                        drawEmpty(debugTexts[i].0)
                    }
                }
                if !debugTexts.isEmpty, debugCount - 1 >= 0,
                    let p = debugTexts[debugCount - 1].0.typoBounds?.origin,
                    let node = debugNodeValues[p]?.node {
                    
                    node.children.first?.fillType = .color(.selected)
                    node.lineType = .color(.selected)
                    node.removeFromParent()
                    document.rootNode.append(child: node)
                    newNode = node
                }
            }
            
            oldDebugNode?.children.first?.fillType = .color(.removing)
            oldDebugNode?.lineType = .color(.removing)
            oldDebugNode = newNode
        }
    }
    func drawFirstError(_ id: ID) {
        guard firstErrorNode == nil,
              let ratio = id.typobute?.font.defaultRatio,
              let idb = id.typoBounds else { return }
        let idOrigin = idb.origin
        guard !(debugNodeValues[idOrigin]?.isEmpty ?? false) else { return }
        let b = idb.insetBy(dx: -1 * ratio, dy: 0)
        let node = Node(attitude: Attitude(position: b.origin),
                        path: Path(Rect(origin: Point(), size: b.size)),
                        lineWidth: 0.5 * ratio, lineType: .color(.removing))
        firstErrorNode = node
        document.rootNode.append(child: node)
    }
    func drawEmpty(_ id: ID) {
        guard let ratio = id.typobute?.font.defaultRatio,
            let idb = id.typoBounds else { return }
        let idOrigin = idb.origin
        guard !(debugNodeValues[idOrigin]?.isEmpty ?? false) else { return }
        let b = idb.insetBy(dx: -1 * ratio, dy: 0)
        
        let rb = Rect(x: 0, y: -4 * ratio,
                      width: b.width + 4 * ratio, height: 8 * ratio)
        let origin = Point(b.centerPoint.x - rb.size.width / 2,
                           b.origin.y - 4 * ratio)
        let e = Edge(b.minXMinYPoint - origin, b.maxXMinYPoint - origin)
        
        let subNode = Node(path: Path([Pathline(Rect(e).inset(by: -0.5 * ratio))]),
                           fillType: .color(.removing))
        let node = Node(children: [subNode],
                        attitude: Attitude(position: origin),
                        path: Path(rb, cornerRadius: 2 * ratio),
                        lineWidth: 0.5 * ratio, lineType: .color(.removing),
                        fillType: .color(.background))
        if let aNode = debugNodeValues[idOrigin] {
            aNode.node.removeFromParent()
        }
        debugNodeValues[idOrigin] = DebugNodeValue(isEmpty: true, stack: [],
                                           node: node)
        document.rootNode.append(child: node)
    }
    @discardableResult func draw(_ id: ID?, _ o: O, _ color: Color) -> Node? {
        guard let ratio = id?.typobute?.font.defaultRatio,
            let idb = id?.typoBounds else { return nil }
        let idOrigin = idb.origin
        let b = idb.insetBy(dx: -1 * ratio, dy: 0)
        let string = o.displayString(fromLength: 40)
        let text = Text(string: string, size: Font.smallSize * ratio)
        let typesetter = text.typesetter
        let s = typesetter.typoBounds?.size ?? Size()
        
        let rb = Rect(x: -(b.width + 4 * ratio) / 2, y: -4 * ratio,
                      width: b.width + 4 * ratio, height: 8 * ratio)
        let sp = Point(-s.width / 2, 0)
        let vb = rb.extend(width: s.width + 6 * ratio, height: s.height)
        let origin = Point(b.centerPoint.x, b.origin.y - 4 * ratio)
        let e = Edge(Point(-b.width / 2 + s.width / 2, vb.height / 2),
                     Point(b.width / 2 + s.width / 2, vb.height / 2))
        
        var path = typesetter.path()
        path.pathlines.append(Pathline(Rect(e).inset(by: -0.5 * ratio)))
        
        let subNode = Node(attitude: Attitude(position: sp),
                           path: path,
                           fillType: .color(color))
        let node = Node(children: [subNode],
                        attitude: Attitude(position: origin),
                        path: Path(vb, cornerRadius: 2 * ratio),
                        lineWidth: 0.5 * ratio, lineType: .color(color),
                        fillType: .color(.background))
        document.rootNode.append(child: node)
        if debugNodeValues[idOrigin] != nil {
            debugNodeValues[idOrigin]?.node.removeFromParent()
            debugNodeValues[idOrigin]?.isEmpty = false
            debugNodeValues[idOrigin]?.stack.append(o)
            debugNodeValues[idOrigin]?.node = node
        } else {
            debugNodeValues[idOrigin] = DebugNodeValue(isEmpty: false, stack: [o],
                                               node: node)
        }
        return node
    }
    
    init(_ document: Document, isDebug: Bool) {
        self.document = document
        isEditingSheet = document.isEditingSheet
        self.isDebug = isDebug
    }
    
    deinit {
        task?.cancel()
        stepTimerTask?.cancel()
    }
    
    func send(_ event: InputKeyEvent) {
        let sp = event.screenPoint
        let p = document.convertScreenToWorld(sp)
        if event.phase == .began && document.closePanel(at: p) { return }
        guard isEditingSheet else {
            document.stop(with: event)
            
            if event.phase == .began {
                document.closeAllPanels(at: p)
            }
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
            return
        }
        
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            document.closeAllPanels(at: p)
            
            let shp = document.sheetPosition(at: p)
            guard let sheetView = document.sheetView(at: shp) else { break }
            let inP = sheetView.convertFromWorld(p)
            if let (textView, ti, _, _) = sheetView.textTuple(at: inP) {
                let text = textView.model
                
                if URL(webString: text.string)?.openInBrowser() ?? false { return }
                
                if text.string == "Waveform draw" {
                    var view: SheetContentView?, minD = Double.infinity
                    for contentView in sheetView.contentsView.elementViews {
                        if contentView.model.timeOption != nil {
                            let d = contentView.mainLineDistance(contentView.convertFromWorld(p))
                            if d < min(minD, 500) {
                                view = contentView
                                minD = d
                            }
                        }
                    }
                    
                    if let view, let pcmBuffer = view.pcmBuffer {
                        let allW = sheetView.bounds.width - Sheet.textPadding.width * 2
                        let tW = view.width(atDurBeat: view.localBeatRange?.length ?? 0)
                        let dx = text.origin.x
                        let wx = Sheet.textPadding.width - dx
                        
                        let fx = view.x(atBeat: (view.beatRange?.start ?? 0) + (view.localBeatRange?.start ?? 0))
                        let pw = inP.x - fx
                        let firstX = -wx + pw
                        
                        let maxCount = 10000
                        let xi = Int(Double(pcmBuffer.frameCount) * pw / tW)
                        var pathlines = [Pathline](), y = 100.0
                        for ci in 0 ..< pcmBuffer.channelCount {
                            let minX = min(xi, pcmBuffer.frameCount)
                            let maxX = min(xi + maxCount, pcmBuffer.frameCount)
                            let ps = (minX ..< maxX).map { i in
                                Point(-wx + allW * Double(i - minX) / Double(maxX - minX),
                                      y + Double(pcmBuffer[ci, i]) * 50)
                            }
                            if !ps.isEmpty {
                                pathlines.append(.init(ps, isClosed: false))
                            }
                            y += 100
                        }
                        
                        let rangeY = 10.0, edgeH = 3.0
                        let endX = firstX + allW * Double(maxCount) / Double(pcmBuffer.frameCount)
                        pathlines.append(.init(Edge(Point(firstX, rangeY),
                                                    Point(endX, rangeY))))
                        pathlines.append(.init(Edge(Point(firstX, rangeY - edgeH),
                                                    Point(firstX, rangeY + edgeH))))
                        pathlines.append(.init(Edge(Point(endX, rangeY - edgeH),
                                                    Point(endX, rangeY + edgeH))))
                        pathlines.append(.init(Edge(Point(firstX, rangeY),
                                                    Point(-wx, rangeY * 2))))
                        pathlines.append(.init(Edge(Point(endX, rangeY),
                                                    Point(-wx + allW, rangeY * 2))))
                        pathlines.append(.init(Edge(Point(-wx, rangeY * 2),
                                                    Point(-wx + allW, rangeY * 2))))
                        let path = Path(pathlines)
                        
                        let wy = view.spectrgramY + 0.5
                        let sNode = Node(name: "spectrogram",
                                         attitude: .init(position: .init(wx, wy)),
                                         path: path,
                                         lineWidth: 0.5,
                                         lineType: .color(.content))
                        view.node.children
                            .filter { $0.name == sNode.name }
                            .forEach { $0.removeFromParent() }
                        view.node.append(child: sNode)
                        return
                    }
                } else if text.string == "Loudness get" {
                    if let sheetView = document.sheetView(at: p) {
                        let maxD = document.worldKnobEditDistance
                        var minD = Double.infinity, minContentView: SheetContentView?
                        for contentView in sheetView.contentsView.elementViews {
                            let d = contentView.mainLineDistance(contentView.convertFromWorld(p))
                            if d < minD && d < maxD {
                                minD = d
                                minContentView = contentView
                            }
                        }
                        
                        if let contentView = minContentView {
                            if let buffer = contentView.pcmBuffer {
                                let lufs = buffer.integratedLoudness
                                let db = buffer.samplePeakDb
                                document.show("Sound".localized
                                              + "\n\t\("Loudness".localized): \(lufs.string(digitsCount: 4)) LUFS"
                                              + "\n\t\("Sample Peak".localized): \(db.string(digitsCount: 4)) dB",
                                              at: p)
                                return
                            }
                        } else if let buffer = sheetView.model.pcmBuffer {
                            let lufs = buffer.integratedLoudness
                            let db = buffer.samplePeakDb
                            document.show("Sheet".localized + "\n\t\("Loudness".localized): \(lufs.string(digitsCount: 4)) LUFS" + "\n\t\("Sample Peak".localized): \(db.string(digitsCount: 4)) dB", at: p)
                            return
                        }
                    }
                }
                
                send(inP, from: text, ti: ti, shp, sheetView)
            }
        case .changed:
            break
        case .ended:
            document.cursor = document.defaultCursor
        }
    }
}
extension RunEditor: Hashable {
    static func == (lhs: RunEditor, rhs: RunEditor) -> Bool {
        return lhs === rhs
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
extension RunEditor {
    func containsStep(_ p: Point) -> Bool {
        stepNode.path.bounds?.contains(stepNode.convertFromWorld(p)) ?? false
    }
    func containsDebug(_ p: Point) -> Bool {
        debugNodeValues.contains {
            $0.value.node.path.bounds?
                .contains($0.value.node.convertFromWorld(p)) ?? false
        }
    }
    func showStep(_ string: String) {
        stepString = string
        stepNode.path = Typesetter(string: string, typobute: runTypobute).path()
    }
    func append(_ id: ID, at sheetView: SheetView) {
        if let b = id.typoBounds, let ratio = id.typobute?.font.defaultRatio {
            let p = b.centerPoint
            if let nSheetView = document.sheetView(at: p) {
                let nb = nSheetView.convertFromWorld(b)
                let s = Line.defaultLineWidth * ratio
                let line = Line.wave(Edge(nb.minXMinYPoint + Point(-s * 2, -s * 2),
                                          nb.maxXMinYPoint + Point(s * 2, -s * 2)),
                                     a: s, length: s * 2, size: s)
                if !nSheetView.model.picture.lines.contains(line) {
                    if sheetView != nSheetView {
                        nSheetView.newUndoGroup()
                    }
                    nSheetView.append(line)
                }
            }
        }
    }
    func send(_ currentP: Point,
              from text: Text, ti: Int,
              _ shp: Sheetpos, _ sheetView: SheetView) {
        runText = text
        runTypobute = text.typobute
        let sf = document.sheetFrame(with: shp)
        let shpp = sf.origin
        var ssDic = [O: O](), tsss = [([Text], Sheetpos, Sheet)]()
        var shps = Set<Sheetpos>(), shpStack = Stack<Sheetpos>()
        shps.insert(shp)
        shpStack.push(shp)
        while let nshp = shpStack.pop() {
            guard let sid = document.sheetID(at: nshp) else { continue }
            guard let sheet = document.readSheet(at: sid) else { continue }
            let sheetBounds = document.sheetFrame(with: nshp).bounds
            let dshp = nshp - shp
            ssDic[O(dshp)] = O(OSheet(sheet, bounds: sheetBounds))
            
            let texts = sheet.texts
            var nTexts = [Text]()
            nTexts.reserveCapacity(texts.count)
            for t in texts {
                func shpFromPlus(at t: Text) -> Sheetpos? {
                    guard t.string == "+", let f = t.frame else { return nil }
                    let s = max(f.width, f.height), p = f.centerPoint
                    guard !sheetBounds.inset(by: s).contains(p),
                        let lrtb = sheetBounds.lrtb(at: p) else { return nil }
                    return switch lrtb {
                    case .left: .init(x: nshp.x - 1, y: nshp.y)
                    case .right: .init(x: nshp.x + 1, y: nshp.y)
                    case .top: .init(x: nshp.x, y: nshp.y + 1)
                    case .bottom: .init(x: nshp.x, y: nshp.y - 1)
                    }
                }
                if let nnshp = shpFromPlus(at: t) {
                    if !shps.contains(nnshp) {
                        shps.insert(nnshp)
                        shpStack.push(nnshp)
                    }
                } else {
                    nTexts.append(t)
                }
            }
            tsss.append((nTexts, nshp, sheet))
        }
        
        let printOrigin = nodePoint(from: text)
        self.worldPrintOrigin = sheetView.convertToWorld(printOrigin)
        
        var oDic = O.defaultDictionary(with: sheetView.model, 
                                       bounds: sf.bounds,
                                       ssDic: ssDic,
                                       cursorP: currentP, printP: printOrigin)
        
        for (nTexts, nshp, _) in tsss {
            for (i, t) in nTexts.enumerated() {
                guard !(shp == nshp && i == ti) && !t.isEmpty else { continue }
                var nText = t
                nText.origin += shpp
                let o = O(nText, isDictionary: true, &oDic)
                switch o {
                case .f(let f):
                    for (key, _) in f.definitions {
                        oDic[key] = O()
                    }
                default: break
                }
            }
        }
        for (nTexts, nshp, _) in tsss {
            for (i, t) in nTexts.enumerated() {
                guard !(shp == nshp && i == ti) && !t.isEmpty else { continue }
                var nText = t
                nText.origin += shpp
                let o = O(nText, isDictionary: true, &oDic)
                switch o {
                case .f(let f):
                    for (key, value) in f.definitions {
                        oDic[key] = O(value)
                    }
                default: break
                }
            }
        }
        let oText = sheetView.model.texts[ti]
        var nText = oText
        nText.origin += document.sheetFrame(with: shp).origin
        let xo = O(nText, &oDic)
        
        stepNode.attitude.position = nodePoint(from: nText)
        document.rootNode.append(child: stepNode)
        
        let timer = Timer(interval: 1)
        stepTimerTask = Task { @MainActor in
            for try await sec in timer {
                showStep("Calculating".localized + "\n" + "\(Int(sec.rounded())) s")
            }
        }
        
        document.runners.insert(self)
        
        let xoDic = oDic, isDebug = self.isDebug
        Task { @MainActor in
            let firstDate = Date()
            let task = Task.detached {
                if isDebug {
                    O.calculate(xo, xoDic) { (id, o) in
                        if Task.isCancelled {
                            return false
                        }
                        if let id {
                            Task { @MainActor in
                                if case .error = o {
                                    self.drawFirstError(id)
                                }
                                self.debugTexts.append((id, o))
                                if let p = id.typoBounds?.origin, self.debugNodeValues[p] == nil {
                                    self.drawEmpty(id)
                                }
                            }
                        }
                        return true
                    }
                } else {
                    O.calculate(xo, xoDic) { (_, _) in !Task.isCancelled }
                }
            }
            self.task = task
            let no = await task.value
            self.task = nil
            
            stepTimerTask?.cancel()
            stepTimerTask = nil
            if !isDebug {
                document.runners.remove(self)
            }
            stepNode.removeFromParent()
            
            if no != .stopped {
                let t = Date().timeIntervalSince(firstDate)
                if let sheetView = document.madeReadSheetView(at: worldPrintOrigin) {
                    let shp = document.sheetPosition(at: worldPrintOrigin)
                    draw(no, from: text, time: t, in: sheetView, shp)
                }
            }
            document.updateTextCursor()
        }
    }
    func cancel() {
        stepTimerTask?.cancel()
        stepTimerTask = nil
        if isDebug {
            cancelDebug()
        }
        
        task?.cancel()
        task = nil
    }
    func cancelDebug() {
        document.runners.remove(self)
        firstErrorNode?.removeFromParent()
        debugNode.removeFromParent()
        debugNodeValues.values.forEach { $0.node.removeFromParent() }
        debugNodeValues = [:]
    }
    
    func nodePoint(from text: Text) -> Point {
        let size = text.typesetter.typoBounds?.size ?? Size()
        let padding = runTypobute.font.size * 2 * 2 / 3
        return Point(text.origin.x + padding + size.width, text.origin.y)
    }
    func draw(_ o: O, from text: Text, time: Double,
              in sheetView: SheetView, _ shp: Sheetpos) {
//        var isUp = false
        func drawO(_ o: O) {
            let s = o.description
            var isMultiLines = false, count = 0
            s.enumerateLines { (str, stop) in
                count += 1
                if count > 1 {
                    isMultiLines = true
                    stop = true
                }
            }
//            isUp = isMultiLines
            let ns = isMultiLines ? "=\n\(s)" : "= \(s)"
            draw(ns, at: nodePoint(from: text), in: sheetView)
        }
        switch o {
        case .dic(let a):
            var ssDic = [Sheetpos: OSheet]()
            for (key, value) in a {
                if case .array(let idxs) = key, idxs.count == 2,
                    case .int(let x) = idxs[0], case .int(let y) = idxs[1],
                    case .sheet(let sheet) = value {
                    
                    let nshp = Sheetpos(x: x, y: y) + shp
                    ssDic[nshp] = sheet
                }
            }
            if !ssDic.isEmpty {
                for (key, value) in ssDic {
                    draw(value, from: text, at: key)
                }
            } else {
                drawO(o)
            }
        case .sheet(let a):
            draw(a, from: text, at: shp)
        default:
            switch o {
            case .error(_):
                break
                // enabled debug
//                print(error)
//                self.append(id, at: sheetView)
            default:
                drawO(o)
            }
        }
//        enabled debug
//        if time > 5 {
//        isNewUndoGroup
//            drawTime(time, from: text, isUp: isUp, in: sheetView, shp)
//        }
    }
    func draw(_ ss: OSheet, from text: Text, at shp: Sheetpos) {
        guard let sheetView = document.readSheetView(at: shp) else { return }
        sheetView.newUndoGroup()
        func lineCount(_ line: Line) -> Int {
            return line.controls.count * MemoryLayout<Point>.size
        }
        func textCount(_ text: Text) -> Int {
            return text.string.utf8.count * MemoryLayout<UInt8>.size
        }
        var si = 0
        func isMax() -> Bool {
            if si > maxSheetByte {
                let maxO = O(OError(String(format: "Not support more than %1$@ in total".localized, IOResult.fileSizeNameFrom(fileSize: maxSheetByte))))
                draw(maxO.description,
                     at: nodePoint(from: text), isNewUndoGroup: false,
                     in: sheetView)
                return true
            } else {
                return false
            }
        }
        for item in ss.undos {
            switch item.redoItem {
            case .appendLine(let line):
                si += lineCount(line)
                if isMax() { return }
                sheetView.append(line)
            case .appendLines(let lines):
                si += lines.reduce(0) { $0 + lineCount($1) }
                if isMax() { return }
                sheetView.append(lines)
            case .insertLines(let livs):
                si += livs.reduce(0) { $0 + lineCount($1.value) }
                if isMax() { return }
                sheetView.insert(livs)
            case .removeLines(let lineIndexes):
                sheetView.removeLines(at: lineIndexes)
            case .insertTexts(let tivs):
                si += tivs.reduce(0) { $0 + textCount($1.value) }
                if isMax() { return }
                sheetView.insert(tivs)
            case .removeTexts(let textIndexes):
                sheetView.removeText(at: textIndexes)
            default: fatalError()
            }
        }
    }
    func draw(_ s: String,
              at p: Point, isNewUndoGroup: Bool = true,
              in sheetView: SheetView) {
        let nt = Text(string: s, size: runTypobute.font.size, origin: p)
        if !sheetView.model.texts.contains(nt) {
            if isNewUndoGroup {
                sheetView.newUndoGroup()
            }
            if let i = sheetView.model.texts
                .firstIndex(where: { $0.origin == p }) {
                
                sheetView.removeText(at: i)
            }
            sheetView.append(nt)
        }
    }
    func drawTime(_ t: Double, from text: Text, isUp: Bool,
                  isNewUndoGroup: Bool = true,
                  in sheetView: SheetView, _ shp: Sheetpos) {
        let size = text.typesetter.typoBounds?.size ?? Size()
        let padding = runTypobute.font.size * 2 * 2 / 3
        let p = Point(text.origin.x + padding + size.width,
                      text.origin.y + (isUp ? 1 : -1) * runTypobute.font.size * 1.5)
        let nt = Text(string: String(format: "%.4f", t),
                      size: runTypobute.font.size,
                      origin: p)
        if !sheetView.model.texts.contains(nt) {
            if isNewUndoGroup {
                sheetView.newUndoGroup()
            }
            if let i = sheetView.model.texts
                .firstIndex(where: { $0.origin == p }) {
                
                sheetView.removeText(at: i)
            }
            sheetView.append(nt)
        }
    }
}

final class AboutRunShower: InputKeyEditor {
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
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if let sheetView = document.madeSheetView(at: p) {
                let b = sheetView.bounds
                let lPadding = 20.0
                
                var p = Point(0, -lPadding), allSize = Size()
                
                var t0 = Text(string: "About Run".localized, size: 20, origin: p)
                let size0 = t0.typesetter.typoBounds?.size ?? Size()
                p.y -= size0.height + lPadding / 4
                allSize.width = max(allSize.width, size0.width)
                
                var t1 = Text(string: "To show all definitions, run the following statement".localized, origin: p)
                let size2 = t1.typesetter.typoBounds?.size ?? Size()
                p.y -= size2.height * 2
                
                var t2 = Text(string: "sheet showAllDefinitions", origin: p)
                let size3 = t2.typesetter.typoBounds?.size ?? Size()
                p.y -= size3.height + lPadding * 2
                
                let s0 = """
\("Bool".localized)
    false
    true

\("Rational number".localized)
    0
    1
    +3
    -20
    1/2

\("Real number".localized)
    0.0
    1.3
    +1.02
    -20.0

\("Infinity".localized)
    ∞ -∞ +∞ (\("Key input".localized): ⌥ 5)

\("String".localized)
    "A AA" -> A AA
    "AA\"A" -> AA"A
    "AAAAA\\nAA" ->
        AAAAA
        AA

\("Array".localized)
    a b c
    (a b c)
    (a b (c d))

\("Dictionary".localized)
    (a: d  b: e  c: f)
    = ((\"a\"): d  (\"b\"): e  (\"c\"): f)

\("Function".localized)
    (1 + 2) = 3
    (a: 1  b: 2  c: 3 | a + b + c) = 6
    (a(b c): b + c | a 1 2 + 3) = 6
    ((b)a(c): b + c | 1 a 2 + 3) = 6
    ((b)a(c: d): b + d | 1 a c: 2 + 3) = 6
    ((b)a(c)100: b + c | 2 a 2 * 3 + 1) = 9
        \("Precedence".localized): 100  \("Associaticity".localized): \("Left".localized)
    ((b)a(c)150r: b / c | 1 a 2 a 3 + 1) = 5 / 2
        \("Precedence".localized): 150  \("Associaticity".localized): \("Right".localized)

\("Block function".localized)
    (| 1 + 2) send () = 3
    (| a: 1  b: 2  c: 3 | a + b + c) send () = 6
    (a b c | a + b + c) send (1 2 3) = 6
    (a b c | d: a + b | d + c) send (1 2 3) = 6

\("Conditional function".localized)
        1 == 2
        -> 3
        -! 4
    = 4,
        1 == 2
        -> 3
        -!
        4 * 5
        case 10      -> 100
        case 10 + 10 -> 200
        -! 300
    = 200,
        "a"
        case "a" -> 1
        case "b" -> 2
        case "c" -> 3
    = 1
"""
                // Issue?: if 1 == 2
                // switch "a"
                
                let t3 = Text(string: s0, origin: p)
                let size4 = t3.typesetter.typoBounds?.size ?? Size()
                
                let setS = G.allCases.reduce(into: "") { $0 += "\n\t" + $1.rawValue + ": " + $1.displayString }
                let s1 = """
\("Set".localized)
    \(setS)

\("Lines bracket".localized)
    a + b +
        c +
            d + e
    = a + b + (c + (d + e))

\("Split".localized)
    (a + b, b + c, c) = ((a + b) (b + c) (c))

\("Separator".localized) (\("Separator character".localized) \(O.defaultLiteralSeparator)):
    abc12+3 = abc12 + 3
    abc12++3 = abc12 ++ 3

\("Union".localized)
    a + b+c = a + (b + c)
    a+b*c + d/e = (a + b * c) + (d / e)

\("Omit multiplication sign".localized)
    3a + b = 3 * a + b
    3a\("12".toSubscript)c\("3".toSubscript) + b = 3 * a\("12".toSubscript) * c\("3".toSubscript) + b
    a\("2".toSubscript)''b\("2".toSubscript)c'd = a\("2".toSubscript)'' * b\("2".toSubscript) * c' * d
    (x + 1)(x - 1) = (x + 1) * (x - 1)

\("Pow".localized)
    x\("1+2".toSuperscript) = x ** (1 + 2)

\("Get".localized)
    a.b.c = a . "b" . "c"

\("Select".localized)
    a/.b.c = a /. "b" /. "c"

\("xyzw".localized)
    a is Array -> a.x = a . 0
    a is Array -> a.y = a . 1
    a is Array -> a.z = a . 2
    a is Array -> a.w = a . 3

\("Sheet bond".localized)
    \("Put '+' string beside the frame of the sheet you want to connect.".localized)
""" // + xxxx -> border bond
                
                let t4 = Text(string: s1, origin: p + Point(size4.width + lPadding * 2, 0))
                let size5 = t4.typesetter.typoBounds?.size ?? Size()
                
                p.y -= max(size4.height, size5.height) + lPadding
                allSize.width = size4.width + size5.width + lPadding * 2
                
                t0.origin.x = (allSize.width - size0.width) / 2
                t1.origin.x = (allSize.width - size2.width) / 2
                t2.origin.x = (allSize.width - size3.width) / 2
                
                let w = allSize.width, h = -p.y
                let ts = [t0, t1, t2, t3, t4]
                
                let size = Size(width: w + lPadding * 2,
                                height: h + lPadding * 2)
                let scale = min(1, b.width / size.width, b.height / size.height)
                let dx = (b.width - size.width * scale) / 2
                let t = Transform(scale: scale)
                    * Transform(translation: b.minXMaxYPoint + Point(lPadding * scale + dx, -lPadding * scale))
                let nts = ts.map { $0 * t }
                
                sheetView.newUndoGroup()
                sheetView.removeAll()
                sheetView.append(nts)
            }
        case .changed:
            break
        case .ended:
            document.cursor = document.defaultCursor
        }
    }
}
