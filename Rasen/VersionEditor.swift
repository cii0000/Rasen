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

final class UndoEditor: InputKeyEventEditor {
    let editor: VersionEditor
    
    init(_ rootEditor: RootEditor) {
        editor = VersionEditor(rootEditor)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.undo(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class RedoEditor: InputKeyEventEditor {
    let editor: VersionEditor
    
    init(_ rootEditor: RootEditor) {
        editor = VersionEditor(rootEditor)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.redo(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class SelectVersionEditor: DragEventEditor {
    let editor: VersionEditor
    
    init(_ rootEditor: RootEditor) {
        editor = VersionEditor(rootEditor)
    }
    
    func send(_ event: DragEvent) {
        editor.selectVersion(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class VersionEditor: Editor {
    let rootEditor: RootEditor, rootView: RootView
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
    }
    
    enum UndoType {
        case x, y
    }
    
    let undoXWidth = 8.0, undoYWidth = 12.0,
        correction = 1.0, xd = 3.0, yd = 3.0
    let outlineNode = Node(lineWidth: 2, lineType: .color(.background))
    let lineNode = Node(lineWidth: 1, lineType: .color(.content))
    let currentKnobNode = Node(path: Path(circleRadius: 4.5), lineWidth: 1,
                               lineType: .color(.background),
                               fillType: .color(.content))
    var outlineYNodes = [Node]()
    var yNodes = [Node]()
    let rootNode = Node()
    let selectingOutlineRootNode = Node(lineWidth: 3,
                                        lineType: .color(.background))
    let selectingRootNode = Node(lineWidth: 1, lineType: .color(.selected))
    let outOfBoundsOutlineNode = Node(lineWidth: 3,
                                      lineType: .color(.background))
    let outOfBoundsNode = Node(lineWidth: 1, lineType: .color(.selected))

    
    var beganSP = Point(), beganDP = Point(), ydp = Point()
    var beganVersion = Version?.none,
        beganXIndex = 0, beganYIndex = 0, dyIndex = 0
    var currentXIndex = 0, maxXCount = 0, currentYIndex = 0, maxYCount = 0
    var oldSP = Point(), oldTime = 0.0
    var sheetView: SheetView?
    var isEditRoot = false
    var oldDate: Date?
    
    var type = UndoType.x
    
    func updateNode() {
        selectingOutlineRootNode.lineWidth = rootView.worldLineWidth * 3
        selectingRootNode.lineWidth = rootView.worldLineWidth
        outOfBoundsOutlineNode.lineWidth = rootView.worldLineWidth * 3
        outOfBoundsNode.lineWidth = rootView.worldLineWidth
    }
    
    func yPath(selectedIndex: Int,
               count: Int, x: Double) -> (path: Path, position: Point) {
        var pathlines = [Pathline]()
        pathlines.append(Pathline([Point(x, 0),
                                   Point(x, -undoYWidth * Double(count - 1))]))
        for i in 0 ..< count {
            let ny = -undoYWidth * Double(i)
            pathlines.append(Pathline([Point(x - xd, ny), Point(x + xd, ny)]))
        }
        return (Path(pathlines), Point(0, undoYWidth * Double(selectedIndex)))
    }
    func updateEmptyPath(at p: Point) {
        let linePath = Path([Pathline([Point(0, -yd), Point(0, yd)])])
        outlineNode.path = linePath
        lineNode.path = linePath
        
        var attitude = Attitude(rootView.screenToWorldTransform)
        let up = rootView.convertScreenToWorld(rootView.convertWorldToScreen(p))
        attitude.position = up
        rootNode.attitude = attitude
        
        currentKnobNode.attitude.position = Point()
        rootNode.append(child: outlineNode)
        rootNode.append(child: lineNode)
        rootNode.append(child: currentKnobNode)
        rootView.node.append(child: rootNode)
    }
    func updatePath<T: UndoItem>(maxTopIndex: Int, rootBranch: Branch<T>) {
        var pathlines = [Pathline]()
        pathlines.append(Pathline([Point(),
                                   Point(undoXWidth * Double(maxTopIndex), 0)]))
        (0 ... maxTopIndex).forEach { i in
            let sx = undoXWidth * Double(i)
            pathlines.append(Pathline([Point(sx, -yd), Point(sx, yd)]))
        }
        let linePath = Path(pathlines)
        outlineNode.path = linePath
        lineNode.path = linePath
        
        rootNode.children = []
        outlineYNodes = []
        yNodes = []
        var un = rootBranch, count = 0
        while let sci = un.selectedChildIndex {
            count += un.groups.count
            let x = undoXWidth * Double(count)
            let (path, p) = yPath(selectedIndex: sci,
                                  count: un.children.count, x: x)
            let outlineYNode = Node(path: path, lineWidth: 2,
                                    lineType: .color(.background))
            let yNode = Node(path: path, lineWidth: 1,
                             lineType: .color(.content))
            outlineYNode.attitude.position = p
            yNode.attitude.position = p
            outlineYNodes.append(outlineYNode)
            yNodes.append(yNode)
            un = un.children[sci]
        }
        
        rootNode.append(child: outlineNode)
        outlineYNodes.forEach { rootNode.append(child: $0) }
        rootNode.append(child: lineNode)
        yNodes.forEach { rootNode.append(child: $0) }
        rootNode.append(child: currentKnobNode)
    }
    func undo(at p: Point, undoIndex: Int) {
        var frame: Rect?, nodes = [Node]()
        if let sheetView = sheetView {
            let (aFrame, aNodes) = sheetView.undo(to: undoIndex)
            if let aFrame = aFrame {
                frame = sheetView.convertToWorld(aFrame)
            }
            aNodes.forEach {
                $0.attitude = sheetView.node.attitude
            }
            nodes = aNodes
        } else {
            frame = rootView.undo(to: undoIndex)
        }
        if let frame = frame {
            let f = rootView.screenBounds * rootView.screenToWorldTransform
            if frame.width > 0 || frame.height > 0, !f.intersects(frame) {
                let fp = f.centerPoint, lp = frame.centerPoint
                let d = max(frame.width, frame.height)
                let ps = f.intersection(Edge(fp, lp).extendedLast(withDistance: d))
                if !ps.isEmpty {
                    let np = ps[0]
                    let nfp = Point.linear(fp, np, t: 0.6)
                    let nlp = Point.linear(fp, np, t: 0.95)
                    let angle = Edge(nfp, nlp).reversed().angle()
                    var pathlines = [Pathline]()
                    pathlines.append(Pathline([nfp, nlp]))
                    let l = 10 / rootView.worldToScreenScale
                    pathlines.append(Pathline([nlp.movedWith(distance: l,
                                                             angle: angle - .pi / 6),
                                               nlp,
                                               nlp.movedWith(distance: l,
                                                             angle: angle + .pi / 6)]))
                    let path = Path(pathlines)
                    outOfBoundsOutlineNode.path = path
                    outOfBoundsNode.path = path
                } else {
                    outOfBoundsOutlineNode.path = Path()
                    outOfBoundsNode.path = Path()
                }
            } else {
                outOfBoundsOutlineNode.path = Path()
                outOfBoundsNode.path = Path()
            }
            let nf = frame * rootView.worldToScreenTransform
            if !rootView.isEditingSheet || (nf.width < 6 && nf.height < 6) {
                let s = 1 / rootView.worldToScreenScale
                let path = Path(frame.outset(by: 4 * s),
                                cornerRadius: 3 * s)
                selectingOutlineRootNode.path = path
                selectingRootNode.path = path
            } else {
                selectingOutlineRootNode.path = Path()
                selectingRootNode.path = Path()
            }
        }
        if !nodes.isEmpty {
            selectingRootNode.children = nodes
        } else if !selectingRootNode.children.isEmpty {
            selectingRootNode.children = []
        }
    }
    
    func undo(with event: InputKeyEvent) {
        undo(with: event, isRedo: false)
    }
    func redo(with event: InputKeyEvent) {
        undo(with: event, isRedo: true)
    }
    func undo(with event: InputKeyEvent, isRedo: Bool) {
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneSelectedNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            updateUndoOrRedo(at: p, isRedo: isRedo)
        case .changed:
            if event.isRepeat {
                updateUndoOrRedo(at: p, isRedo: isRedo)
            }
        case .ended:
            outOfBoundsOutlineNode.removeFromParent()
            outOfBoundsNode.removeFromParent()
            selectingOutlineRootNode.removeFromParent()
            selectingRootNode.removeFromParent()
            rootNode.removeFromParent()
            
            rootView.updateSelects()
            if let sheetView = sheetView {
                rootView.updateFinding(from: sheetView)
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    func updateUndoOrRedo(at p: Point, isRedo: Bool) {
        func update(currentVersionIndex: Int,
                    currentMaxVersionIndex: Int) {
            func setup(firstPathline: Pathline, topIndex: Int) {
                var pathlines = [firstPathline]
                let sx = undoXWidth * Double(topIndex)
                pathlines.append(Pathline([Point(sx, -yd), Point(sx, yd)]))
                let linePath = Path(pathlines)
                outlineNode.path = linePath
                lineNode.path = linePath
                
                let rp = Point(undoXWidth * Double(topIndex), 0)
                
                var attitude = Attitude(rootView.screenToWorldTransform)
                let up = rootView.convertScreenToWorld(rootView.convertWorldToScreen(p) - rp)
                attitude.position = up
                rootNode.attitude = attitude
                
                currentKnobNode.attitude.position = rp
                
                rootNode.append(child: outlineNode)
                rootNode.append(child: lineNode)
                rootNode.append(child: currentKnobNode)
                rootView.node.append(child: rootNode)
            }
            let ni = currentVersionIndex + (isRedo ? 1 : -1)
            let nsi = ni.clipped(min: 0, max: currentMaxVersionIndex)
            if nsi == 0 {
                setup(firstPathline: Pathline([Point(0, 0),
                                               Point(undoXWidth, 0)]),
                      topIndex: nsi)
            } else if nsi == currentMaxVersionIndex {
                setup(firstPathline: Pathline([Point(undoXWidth * Double(nsi - 1), 0),
                                               Point(undoXWidth * Double(nsi), 0)]),
                      topIndex: nsi)
            }
            if currentVersionIndex != nsi {
                undo(at: p, undoIndex: nsi)
                selectingOutlineRootNode.lineWidth = rootView.worldLineWidth * 3
                selectingRootNode.lineWidth = rootView.worldLineWidth
                outOfBoundsOutlineNode.lineWidth = rootView.worldLineWidth * 3
                outOfBoundsNode.lineWidth = rootView.worldLineWidth
                rootView.node.append(child: selectingOutlineRootNode)
                rootView.node.append(child: selectingRootNode)
                rootView.node.append(child: outOfBoundsOutlineNode)
                rootView.node.append(child: outOfBoundsNode)
            }
        }
        if !rootView.isEditingSheet {
            self.sheetView = nil
            isEditRoot = true
            
            update(currentVersionIndex: rootView.history.currentVersionIndex,
                   currentMaxVersionIndex: rootView.history.currentMaxVersionIndex)
        } else if let sheetView = rootView.sheetView(at: p) {
            self.sheetView = sheetView
            isEditRoot = false
            
            update(currentVersionIndex: sheetView.history.currentVersionIndex,
                   currentMaxVersionIndex: sheetView.history.currentMaxVersionIndex)
        } else {
            self.sheetView = nil
            isEditRoot = false
            
            updateEmptyPath(at: p)
        }
        rootView.updateTextCursor()
    }
    
    func selectVersion(with event: DragEvent) {
        let p = rootView.convertScreenToWorld(event.screenPoint)
        
        func updateDate(_ date: Date) {
            guard date != oldDate else { return }
            rootView.cursor = date.timeIntervalSinceReferenceDate == 0 ?
                .arrow : .arrowWith(string: date.defaultString)
            
            oldDate = date
        }
        
        switch event.phase {
        case .began:
            beganSP = event.screenPoint
            oldSP = event.screenPoint
            oldTime = event.time
            
            func update<T: UndoItem>(currentVersion: Version?,
                                     currentVersionIndex: Int,
                                     currentMaxVersionIndex:Int,
                                     rootBranch: Branch<T>) {
                beganVersion = currentVersion
                
                beganXIndex = currentVersionIndex
                currentXIndex = currentVersionIndex
                beganDP = Point(undoXWidth * Double(currentVersionIndex), 0)
                maxXCount = currentMaxVersionIndex + 1
                
                dyIndex = 0
                let beganVIP = beganVersion?.indexPath ?? []
                let un = rootBranch[beganVIP]
                if let yi = un.selectedChildIndex,
                   currentVersion?.groupIndex == nil
                    || currentVersion?.groupIndex == un.groups.count - 1 {
                    
                    beganYIndex = yi
                    currentYIndex = yi
                    ydp = Point(0, -undoYWidth * Double(yi))
                    maxYCount = un.children.count
                }
                
                updatePath(maxTopIndex: currentMaxVersionIndex,
                           rootBranch: rootBranch)
                var attitude = Attitude(rootView.screenToWorldTransform)
                let up = rootView.convertScreenToWorld(rootView.convertWorldToScreen(p) - beganDP)
                attitude.position = up
                rootNode.attitude = attitude
                currentKnobNode.attitude.position = beganDP
                
                rootView.node.append(child: rootNode)
                selectingOutlineRootNode.lineWidth = rootView.worldLineWidth * 3
                selectingRootNode.lineWidth = rootView.worldLineWidth
                outOfBoundsOutlineNode.lineWidth = rootView.worldLineWidth * 3
                outOfBoundsNode.lineWidth = rootView.worldLineWidth
                rootView.node.append(child: selectingOutlineRootNode)
                rootView.node.append(child: selectingRootNode)
                rootView.node.append(child: outOfBoundsOutlineNode)
                rootView.node.append(child: outOfBoundsNode)
            }
            if !rootView.isEditingSheet {
                self.sheetView = nil
                isEditRoot = true
                
                update(currentVersion: rootView.history.currentVersion,
                       currentVersionIndex: rootView.history.currentVersionIndex,
                       currentMaxVersionIndex: rootView.history.currentMaxVersionIndex,
                       rootBranch: rootView.history.rootBranch)
            } else if let sheetView = rootView.sheetView(at: p) {
                self.sheetView = sheetView
                isEditRoot = false
                
                update(currentVersion: sheetView.history.currentVersion,
                       currentVersionIndex: sheetView.history.currentVersionIndex,
                       currentMaxVersionIndex: sheetView.history.currentMaxVersionIndex,
                       rootBranch: sheetView.history.rootBranch)
            } else {
                self.sheetView = nil
                isEditRoot = false
                
                updateEmptyPath(at: p)
            }
            
            if let sheetView = sheetView {
                if let version = sheetView.history.currentVersion {
                    updateDate(sheetView.history.rootBranch[version].date)
                } else {
                    rootView.cursor = .arrow
                }
            } else {
                if let version = rootView.history.currentVersion {
                    updateDate(rootView.history.rootBranch[version].date)
                } else {
                    rootView.cursor = .arrow
                }
            }
        case .changed:
            guard (sheetView != nil || isEditRoot) && maxXCount > 0 else { return }
            
            func uip<T: UndoItem>(currentVersion: Version?,
                                  rootBranch: Branch<T>) -> VersionPath? {
                let buip = currentVersion?.indexPath ?? []
                let un = rootBranch[buip]
                if un.selectedChildIndex != nil {
                    if currentVersion?.groupIndex == nil
                        || currentVersion?.groupIndex == un.groups.count - 1 {
                        
                        return buip
                    }
                }
                return nil
            }
            let buip: VersionPath?
            if let sheetView = sheetView {
                buip = uip(currentVersion: sheetView.history.currentVersion,
                           rootBranch: sheetView.history.rootBranch)
            } else {
                buip = uip(currentVersion: rootView.history.currentVersion,
                           rootBranch: rootView.history.rootBranch)
            }
            
            let speed = (event.screenPoint - oldSP).length()
                / (event.time - oldTime)
            if buip != nil && speed < 200 {
                let dp = event.screenPoint - oldSP
                type = abs(dp.x) > abs(dp.y) ? .x : .y
            }
            oldSP = event.screenPoint
            oldTime = event.time
            
            let deltaP = event.screenPoint - beganSP
            switch type {
            case .x:
                var dp = beganDP + deltaP
                dp.x = dp.x.clipped(min: 0,
                                    max: undoXWidth * Double(maxXCount - 1))
                let newIndex = Int((dp.x / undoXWidth).rounded())
                    .clipped(min: 0, max: maxXCount - 1)
                if newIndex != currentXIndex {
                    currentXIndex = newIndex
                    
                    undo(at: p, undoIndex: newIndex)
                    currentKnobNode.attitude.position.x
                        = undoXWidth * Double(newIndex)
                    
                    func updateY<T: UndoItem>(currentVersion: Version?,
                                              rootBranch: Branch<T>) {
                        let buip = currentVersion?.indexPath ?? []
                        let un = rootBranch[buip]
                        if let yi = un.selectedChildIndex,
                           currentVersion?.groupIndex == nil
                            || currentVersion?.groupIndex == un.groups.count - 1 {
                            
                            beganYIndex = yi
                            currentYIndex = yi
                            ydp = Point(0, -undoYWidth * Double(yi - dyIndex))
                            maxYCount = un.children.count
                        }
                    }
                    if let sheetView = sheetView {
                        updateY(currentVersion: sheetView.history.currentVersion,
                                rootBranch: sheetView.history.rootBranch)
                    } else {
                        updateY(currentVersion: rootView.history.currentVersion,
                                rootBranch: rootView.history.rootBranch)
                    }
                    
                    let np = rootView.convertScreenToWorld(beganSP)
                    let nnp = Point(undoXWidth * Double(beganXIndex),
                                    undoYWidth * Double(dyIndex))
                    let up = rootView.convertScreenToWorld(rootView.convertWorldToScreen(np) - nnp)
                    rootNode.attitude.position = up
                }
            case .y:
                if let buip = buip {
                    var dp = ydp + deltaP
                    dp.y = dp.y.clipped(min: -undoYWidth * Double(maxYCount - 1),
                                        max: 0)
                    let newIndex = Int((-dp.y / undoYWidth).rounded())
                        .clipped(min: 0, max: maxYCount - 1)
                    if newIndex != currentYIndex {
                        dyIndex += newIndex - currentYIndex
                        currentYIndex = newIndex
                        
                        if let sheetView = sheetView {
                            sheetView.history.rootBranch[buip]
                                .selectedChildIndex = newIndex
                            let maxIndex = sheetView.history.currentMaxVersionIndex
                            updatePath(maxTopIndex: maxIndex,
                                       rootBranch: sheetView.history.rootBranch)
                            maxXCount = maxIndex + 1
                        } else {
                            rootView.history.rootBranch[buip]
                                .selectedChildIndex = newIndex
                            let maxIndex = rootView.history.currentMaxVersionIndex
                            updatePath(maxTopIndex: maxIndex,
                                       rootBranch: rootView.history.rootBranch)
                            maxXCount = maxIndex + 1
                        }
                        
                        let np = rootView.convertScreenToWorld(beganSP)
                        let nnp = Point(undoXWidth * Double(beganXIndex),
                                        undoYWidth * Double(dyIndex))
                        let up = rootView.convertScreenToWorld(rootView.convertWorldToScreen(np) - nnp)
                        rootNode.attitude.position = up
                    }
                }
            }
            
            if let sheetView = sheetView {
                if let version = sheetView.history.currentVersion {
                    updateDate(sheetView.history.rootBranch[version].date)
                }
            } else {
                if let version = rootView.history.currentVersion {
                    updateDate(rootView.history.rootBranch[version].date)
                }
            }
        case .ended:
            outOfBoundsOutlineNode.removeFromParent()
            outOfBoundsNode.removeFromParent()
            selectingOutlineRootNode.removeFromParent()
            selectingRootNode.removeFromParent()
            rootNode.removeFromParent()
            
            rootView.updateSelects()
            if let sheetView = sheetView {
                rootView.updateFinding(from: sheetView)
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

extension RootView {
    func clearHistorys(from shps: [IntPoint], progressHandler: (Double, inout Bool) -> ()) throws {
        var isStop = false
        for (j, shp) in shps.enumerated() {
            if let sheetView = sheetView(at: shp) {
                sheetView.clearHistory()
                clearContents(from: sheetView)
            } else {
                removeSheetHistory(at: shp)
            }
            progressHandler(Double(j + 1) / Double(shps.count), &isStop)
            if isStop { break }
        }
    }
}

final class ClearHistoryEditor: InputKeyEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
    }
    
    let selectingLineNode = Node(lineWidth: 1.5)
    func updateNode() {
        selectingLineNode.lineWidth = rootView.worldLineWidth
    }
    func end() {
        selectingLineNode.removeFromParent()
        
        rootView.cursor = rootView.defaultCursor
        
        rootView.updateSelectedColor(isMain: true)
    }
    
    func send(_ event: InputKeyEvent) {
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText {
                let vs: [Rect] = rootView.world.sheetIDs.keys.compactMap { shp in
                    let frame = rootView.sheetFrame(with: shp)
                    return rootView.multiSelection.intersects(frame) ? frame : nil
                }
                selectingLineNode.children = vs.map {
                    Node(path: Path($0),
                         lineWidth: rootView.worldLineWidth,
                         lineType: .color(.selected),
                         fillType: .color(.subSelected))
                }
            } else {
                selectingLineNode.lineWidth = rootView.worldLineWidth
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                let frame = rootView
                    .sheetFrame(with: rootView.sheetPosition(at: p))
                selectingLineNode.path = Path(frame)
                
                rootView.updateSelectedColor(isMain: false)
            }
            rootView.node.append(child: selectingLineNode)
            
            rootView.textCursorNode.isHidden = true
            rootView.textMaxTypelineWidthNode.isHidden = true
        case .changed:
            break
        case .ended:
            if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText {
                let shps = rootView.sheetposWithSelection()
                
                let mes = shps.count == 1 ?
                    "Do you want to clear history of this sheet?".localized :
                    String(format: "Do you want to clear %d historys?".localized, shps.count)
                Task { @MainActor in
                    let result = await rootView.node
                        .show(message: mes,
                              infomation: "You can’t undo this action. \nHistory is what is used in \"Undo\", \"Redo\" or \"Select Version\", and if you clear it, you will not be able to return to the previous work.".localized,
                              okTitle: "Clear History".localized,
                              isSaftyCheck: shps.count > 30)
                    switch result {
                    case .ok:
                        let progressPanel = ProgressPanel(message: "Clearing Historys".localized)
                        self.rootView.node.show(progressPanel)
                        let task = Task.detached(priority: .high) {
                            do {
                                try self.rootView.clearHistorys(from: shps) { (progress, isStop) in
                                    if Task.isCancelled {
                                        isStop = true
                                        return
                                    }
                                    Task { @MainActor in
                                        progressPanel.progress = progress
                                    }
                                }
                                Task { @MainActor in
                                    progressPanel.closePanel()
                                    self.end()
                                }
                            } catch {
                                Task { @MainActor in
                                    self.rootView.node.show(error)
                                    progressPanel.closePanel()
                                    self.end()
                                }
                            }
                        }
                        progressPanel.cancelHandler = { task.cancel() }
                        
                        end()
                    case .cancel:
                        end()
                    }
                }
            } else {
                let shp = rootView.sheetPosition(at: p)
                
                Task { @MainActor in
                    let result = await rootView.node
                        .show(message: "Do you want to clear history of this sheet?".localized,
                              infomation: "You can’t undo this action. \nHistory is what is used in \"Undo\", \"Redo\" or \"Select Version\", and if you clear it, you will not be able to return to the previous work.".localized,
                              okTitle: "Clear History".localized)
                    switch result {
                    case .ok:
                        if let sheetView = rootView.sheetView(at: shp) {
                            sheetView.clearHistory()
                            rootView.clearContents(from: sheetView)
                        } else {
                            rootView.removeSheetHistory(at: shp)
                        }
                        
                        end()
                    case .cancel:
                        end()
                    }
                }
            }
        }
    }
}
