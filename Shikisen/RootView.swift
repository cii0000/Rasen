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

import Dispatch
import struct Foundation.Data
import struct Foundation.URL
import struct Foundation.UUID

final class RootView: View, @unchecked Sendable {
    typealias Model = Root
    var model: Model
    
    let node = Node()
    let sheetsNode = Node()
    let gridNode = Node(lineType: .color(.border))
    let mapNode = Node(lineType: .color(.border))
    let currentMapNode = Node(lineType: .color(.border))
    let lastEditedSheetNode = Node(lineType: .color(.subBorder))
    let selectedNode = Node(), selectedFrameNode = Node()
    let accessoryNodeIndex = 1
    
    init(url: URL) {
        model = .init(url)
        
        world = model.world()
        history = model.history()
        finding = model.finding()
        pov = Self.clippedPOV(from: model.pov())
        baseThumbnailBlocks = model.baseThumbnailBlocks()
        
        node.children = [sheetsNode, gridNode, mapNode, currentMapNode, lastEditedSheetNode,
                         selectedNode, selectedFrameNode]
        
        model.rootDirectory.changedIsWillwriteByChildrenClosure = { [weak self] (_, isWillwrite) in
            if isWillwrite {
                self?.updateAutosavingTimer()
            }
        }
        model.povRecord.willwriteClosure = { [weak self] (record) in
            guard let self else { return }
            record.value = self.pov
        }
        model.findingRecord.willwriteClosure = { [weak self] (record) in
            guard let self else { return }
            record.value = self.finding
        }
        model.worldRecord.willwriteClosure = { [weak self] (record) in
            guard let self else { return }
            record.value = self.world
            self.model.worldHistoryRecord.value = self.history
            self.model.worldHistoryRecord.isPreparedWrite = true
        }
        
        if pov.rotation != 0 {
            defaultCursor = Cursor.rotate(rotation: -pov.rotation + .pi / 2)
            cursor = defaultCursor
        }
        updateTransformsWithPOV()
        updateWithWorld()
        updateWithFinding()
        backgroundColor = isEditingSheet ? .background : .disabled
        
//        node.append(child: cursorNode)
//        updateCursorNode()
    }
    
    func cancelTasks() {
        sheetViewValues.forEach {
            $0.value.task?.cancel()
        }
        thumbnailNodeValues.forEach {
            $0.value.task?.cancel()
        }
    }
    
    let queue = DispatchQueue(label: System.id + ".queue", qos: .userInteractive)
    
    let autosavingDelay = 60.0
    private var autosavingTimer = OneshotTimer()
    private func updateAutosavingTimer() {
        if !autosavingTimer.isWait {
            autosavingTimer.start(afterTime: autosavingDelay,
                                  dispatchQueue: .main,
                                  beginClosure: {}, waitClosure: {},
                                  cancelClosure: {},
                                  endClosure: { [weak self] in self?.asyncSave() })
        }
    }
    private var savingItem: DispatchWorkItem?
    private var savingFuncs = [() -> ()]()
    private func asyncSave() {
        model.rootDirectory.prepareToWriteAll()
        if let item = savingItem {
            item.wait()
        }
        
        let item = DispatchWorkItem(flags: .barrier) { @Sendable [weak self] in
            do {
                try self?.model.rootDirectory.writeAll()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.node.show(error)
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.model.rootDirectory.resetWriteAll()
                self?.savingItem = nil
                
                self?.savingFuncs.forEach { $0() }
                self?.savingFuncs = []
            }
        }
        savingItem = item
        queue.async(execute: item)
    }
    func syncSave() {
        if autosavingTimer.isWait {
            autosavingTimer.cancel()
            autosavingTimer = OneshotTimer()
            
            do {
                try model.write()
            } catch {
                Task { @MainActor in
                    node.show(error)
                }
            }
        }
    }
    @MainActor func endSave(completionHandler: @MainActor @escaping (RootView?) -> ()) {
        let progressPanel = ProgressPanel(message: "Saving".localized,
                                          isCancel : false,
                                          isIndeterminate: true)
        
        let timer = OneshotTimer()
        timer.start(afterTime: 2, dispatchQueue: .main,
                    beginClosure: {}, waitClosure: {},
                    cancelClosure: { progressPanel.close() },
                    endClosure: { progressPanel.show() })
        if autosavingTimer.isWait {
            autosavingTimer.cancel()
            autosavingTimer = OneshotTimer()
            model.rootDirectory.prepareToWriteAll()
            let workItem = DispatchWorkItem(flags: .barrier) { @Sendable [weak self] in
                do {
                    try self?.model.rootDirectory.writeAll()
                } catch {
                    DispatchQueue.main.async { @MainActor [weak self] in
                        self?.node.show(error)
                    }
                }
                DispatchQueue.main.async { @MainActor [weak self] in
                    self?.model.rootDirectory.resetWriteAll()
                    timer.cancel()
                    progressPanel.close()
                    completionHandler(self)
                }
            }
            queue.async(execute: workItem)
        } else if let workItem = savingItem {
            workItem.notify(queue: .main) { @MainActor [weak self] in
                timer.cancel()
                progressPanel.close()
                completionHandler(self)
            }
        } else {
            timer.cancel()
            progressPanel.close()
            completionHandler(self)
        }
        
        autosavingTimer.cancel()
    }
    
    var world = World() { didSet { model.worldRecord.isWillwrite = true } }
    var history = WorldHistory() { didSet { model.worldHistoryRecord.isWillwrite = true } }
    
    func updateWithWorld() {
        for (shp, _) in world.sheetIDs {
            let sf = sheetFrame(with: shp)
            thumbnailNode(at: shp)?.attitude.position = sf.origin
            sheetView(at: shp)?.node.attitude.position = sf.origin
        }
        updateMap()
        updateSelected()
        updateSelectedFrame()
    }
    
    func newUndoGroup() {
        history.newUndoGroup()
    }
    
    private func append(undo undoItem: WorldUndoItem,
                        redo redoItem: WorldUndoItem) {
        history.append(undo: undoItem, redo: redoItem)
    }
    @discardableResult
    private func set(_ item: WorldUndoItem, enableNode: Bool = true,
                     isMakeRect: Bool = false) -> Rect? {
        if enableNode {
            switch item {
            case .insertSheets(let sids):
                var rect = Rect?.none
                sids.forEach { (shp, sid) in
                    let sheetFrame = self.sheetFrame(with: shp)
                    let fillType = readFillType(at: sid) ?? .color(.disabled)
                    let sheetNode = Node(path: Path(sheetFrame), fillType: fillType)
                    thumbnailNodeValues[shp]?.task?.cancel()
                    sheetViewValues[shp]?.task?.cancel()
                    thumbnailNode(at: shp)?.removeFromParent()
                    sheetView(at: shp)?.node.removeFromParent()
                    sheetsNode.append(child: sheetNode)
                    thumbnailNodeValues[shp] = .init(type: thumbnailType, sheetID: sid, node: sheetNode)
                    
                    if let oldSID = world.sheetIDs[shp] {
                        world.sheetPositions[oldSID] = nil
                    }
                    world.sheetIDs[shp] = sid
                    world.sheetPositions[sid] = shp
                    
                    if isMakeRect {
                        rect += sheetFrame
                    }
                }
                updateMap()
                updateGrid(with: screenToWorldTransform, in: screenBounds)
                updateWithCursorPosition()
                if !world.selection.isEmpty {
                    updateSelected()
                }
                return rect
            case .removeSheets(let shps):
                var rect = Rect?.none
                shps.forEach { shp in
                    if let sid = sheetID(at: shp) {
                        if isMakeRect {
                            rect += sheetFrame(with: shp)
                        }
                        
                        readAndClose(.none, at: sid, shp)
                        
                        thumbnailNode(at: shp)?.removeFromParent()
                        let tv = thumbnailNodeValues[shp]
                        thumbnailNodeValues[shp] = nil
                        tv?.task?.cancel()
                        
                        world.sheetPositions[sid] = nil
                    }
                    world.sheetIDs[shp] = nil
                }
                updateMap()
                updateGrid(with: screenToWorldTransform, in: screenBounds)
                updateWithCursorPosition()
                if !world.selection.isEmpty {
                    updateSelected()
                }
                
                return rect
            case .setSelection(let selection):
                let rect = Set(selection.sheetIDs + world.selection.sheetIDs)
                    .reduce(into: Rect?.none) {
                    $0 += sheetFrame(at: $1)
                }
                world.selection = selection
                updateSelected()
                
                return rect
            }
        } else {
            switch item {
            case .insertSheets(let sids):
                var rect = Rect?.none
                sids.forEach { (shp, sid) in
                    let sheetFrame = self.sheetFrame(with: shp)
                    
                    if let oldSID = world.sheetIDs[shp] {
                        world.sheetPositions[oldSID] = nil
                    }
                    world.sheetIDs[shp] = sid
                    world.sheetPositions[sid] = shp
                    
                    if isMakeRect {
                        rect += sheetFrame
                    }
                }
                return rect
            case .removeSheets(let shps):
                var rect = Rect?.none
                shps.forEach { shp in
                    if let sid = sheetID(at: shp) {
                        if isMakeRect {
                            rect += sheetFrame(with: shp)
                        }
                        world.sheetPositions[sid] = nil
                    }
                    world.sheetIDs[shp] = nil
                }
                
                return rect
                
            case .setSelection(let selection):
                let rect = Set(selection.sheetIDs + world.selection.sheetIDs)
                    .reduce(into: Rect?.none) {
                    $0 += sheetFrame(at: $1)
                }
                world.selection = selection
                
                return rect
            }
        }
    }
    func append(_ sids: [IntPoint: UUID], enableNode: Bool = true) {
        let undoItem = WorldUndoItem.removeSheets(sids.map { $0.key })
        let redoItem = WorldUndoItem.insertSheets(sids)
        append(undo: undoItem, redo: redoItem)
        set(redoItem, enableNode: enableNode)
    }
    func removeSheets(at shps: [IntPoint]) {
        var sids = [IntPoint: UUID]()
        shps.forEach {
            sids[$0] = world.sheetIDs[$0]
        }
        let undoItem = WorldUndoItem.insertSheets(sids)
        let redoItem = WorldUndoItem.removeSheets(shps)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    func doSet(_ selection: WorldSelection) {
        let undoItem = WorldUndoItem.setSelection(world.selection)
        let redoItem = WorldUndoItem.setSelection(selection)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    func capture(old oldSelection: WorldSelection) {
        let undoItem = WorldUndoItem.setSelection(oldSelection)
        let redoItem = WorldUndoItem.setSelection(world.selection)
        append(undo: undoItem, redo: redoItem)
    }
    
    @discardableResult
    func undo(to toTopIndex: Int) -> Rect? {
        var frame = Rect?.none
        let results = history.undoAndResults(to: toTopIndex)
        for result in results {
            let item: UndoItemValue<WorldUndoItem>?
            if result.item.loadType == .unload {
                _ = history[result.version].values[result.valueIndex].loadRedoItem()
                loadCheck(with: result)
                item = history[result.version].values[result.valueIndex].undoItemValue
            } else {
                item = result.item.undoItemValue
            }
            switch result.type {
            case .undo:
                if let undoItem = item?.undoItem {
                    if let aFrame = set(undoItem, isMakeRect: true) {
                        frame += aFrame
                    }
                }
            case .redo:
                if let redoItem = item?.redoItem {
                    if let aFrame = set(redoItem, isMakeRect: true) {
                        frame += aFrame
                    }
                }
            }
        }
        return frame
    }
    func loadCheck(with result: WorldHistory.UndoResult) {
        guard let uiv = history[result.version].values[result.valueIndex]
            .undoItemValue else { return }
        
        let isUndo = result.type == .undo
        let reversedType: UndoType = isUndo ? .redo : .undo
        
        switch !isUndo ? uiv.undoItem : uiv.redoItem {
        case .insertSheets(let sids):
            for (shp, sid) in sids {
                if world.sheetIDs[shp] != sid {
                    history[result.version].values[result.valueIndex].error()
                    break
                }
            }
        case .removeSheets: break
        case .setSelection(let selection):
            if world.selection != selection {
                history[result.version].values[result.valueIndex]
                    .saveUndoItemValue?.set(.setSelection(world.selection),
                                            type: reversedType)
            }
        }
        
        switch isUndo ? uiv.undoItem : uiv.redoItem {
        case .insertSheets(_): break
        case .removeSheets(_): break
        case .setSelection:
            switch result.type {
            case .undo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.redoItem = .setSelection(world.selection)
            case .redo:
                history[result.version].values[result.valueIndex]
                    .undoItemValue?.undoItem = .setSelection(world.selection)
            }
        }
    }
    
    struct RestoreError: Error {
        var localizedDescription = "There are sheets added in the upper right corner because the positions data is not found.".localized
    }
    func restoreDatabase() throws {
        var resetSIDs = Set<UUID>()
        for sid in model.sheetRecorders.keys {
            if world.sheetPositions[sid] == nil {
                resetSIDs.insert(sid)
            }
        }
        history.allGroups { (_, groups) in
            for group in groups {
                for udv in group.values {
                    if let item = udv.loadedRedoItem() {
                        if case .insertSheets(let sids) = item.undoItem {
                            for sid in sids.values {
                                resetSIDs.remove(sid)
                            }
                        }
                        if case .insertSheets(let sids) = item.redoItem {
                            for sid in sids.values {
                                resetSIDs.remove(sid)
                            }
                        }
                    }
                }
            }
        }
        if !resetSIDs.isEmpty {
            moveSheetsToUpperRightCorner(with: Array(resetSIDs))
            throw RestoreError()
        }
    }
    func moveSheetsToUpperRightCorner(with sids: [UUID],
                                      isNewUndoGroup: Bool = true) {
        let xCount = Int(Double(sids.count).squareRoot())
        let fxi = (world.sheetPositions.values.max { $0.x < $1.x }?.x ?? 0) + 2
        var dxi = 0
        var yi = (world.sheetPositions.values.max { $0.y < $1.y }?.y ?? 0) + 2
        var newSIDs = [IntPoint: UUID]()
        for sid in sids {
            let shp = IntPoint(fxi + dxi, yi)
            newSIDs[shp] = sid
            dxi += 1
            if dxi >= xCount {
                dxi = 0
                yi += 1
            }
        }
        if isNewUndoGroup {
            newUndoGroup()
        }
        append(newSIDs)
    }
    
    func resetAllThumbnails(_ handler: (String) -> (Bool)) {
        for (i, v) in model.sheetRecorders.enumerated() {
            let (sheetID, sheetRecorder) = v
            guard handler("\(i) / \(model.sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue,
                      let shp = sheetPosition(at: sheetID) else { return }
                let sheetBinder = RecordBinder(value: sheet,
                                               record: record)
                let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value,
                                          history: .init())
                sheetView.screenToWorldScale = self.screenToWorldScale
                let frame = self.sheetFrame(with: shp)
                sheetView.bounds = Rect(size: frame.size)
                sheetView.node.allChildrenAndSelf { $0.updateDatas() }
                
                sheetView.contentsView.elementViews.forEach { $0.updateSpectrogram() }
                sheetView.scoreView.updateSpectrogram()
                
                sheetView.stopNotifications.append { [weak self] _ in
                    self?.showSelected()
                }
                sheetView.changeSelectedFrameNotifications.append { [weak self] _, _ in
                    self?.updateSelectedFrame()
                }
                
                makeThumbnailRecord(at: sheetID, with: sheetView)
                syncSave()
            }
        }
    }
    func resetAllSheets(_ handler: (String) -> (Bool)) {
        for (i, v) in model.sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(model.sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                record.value = sheet
                record.isWillwrite = true
                syncSave()
            }
        }
    }
    func resetAllAnimationSheets(_ handler: (String) -> (Bool)) {
        for (i, v) in model.sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(model.sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                if sheet.enabledAnimation {
                    record.value = sheet
                    record.isWillwrite = true
                    syncSave()
                }
            }
        }
    }
    func resetAllMusicSheets(_ handler: (String) -> (Bool)) {
        for (i, v) in model.sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(model.sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                if sheet.isEnabledAudio {
                    record.value = sheet
                    record.isWillwrite = true
                    syncSave()
                }
            }
        }
    }
    func resetAllStrings(_ handler: (String) -> (Bool)) {
        for (i, v) in model.sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(model.sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                sheetRecorder.stringRecord.value = sheet.allTextsString
                sheetRecorder.stringRecord.isWillwrite = true
                syncSave()
            }
        }
    }
    
    func clearHistory(progressHandler: (Double, inout Bool) -> ()) {
        syncSave()
        
        var resetSRRs = [UUID: Model.SheetRecorder]()
        for (sid, srr) in model.sheetRecorders {
            if world.sheetPositions[sid] == nil {
                resetSRRs[sid] = srr
            }
        }
        var isStop = false
        if !resetSRRs.isEmpty {
            for (i, v) in resetSRRs.enumerated() {
                try? model.remove(v.value)
                progressHandler(Double(i + 1) / Double(resetSRRs.count), &isStop)
                if isStop { break }
            }
        }
        
        history.reset()
        model.worldHistoryRecord.value = history
        model.worldHistoryRecord.isWillwrite = true
    }
    func clearSheetHistorys(from shps: [IntPoint],
                            progressHandler: (Double, inout Bool) -> ()) throws {
        var isStop = false
        for (j, shp) in shps.enumerated() {
            Task { @MainActor in
                if let sheetView = self.sheetViewValues[shp]?.sheetView {
                    clearHistory(from: sheetView)
                } else if let sid = self.sheetID(at: shp),
                          let sheetRecorder = self.model.sheetRecorders[sid] {
                    let record = sheetRecorder.sheetRecord
                    let historyRecord = sheetRecorder.sheetHistoryRecord
                    guard let sheet = record.decodedValue else { return }
                    
                    let sheetBinder = RecordBinder(value: sheet, record: record)
                    let sheetView = SheetView(binder: sheetBinder,
                                              keyPath: \SheetBinder.value,
                                              history: historyRecord.decodedValue ?? .init())
                    sheetView.screenToWorldScale = self.screenToWorldScale
                    let frame = self.sheetFrame(with: shp)
                    sheetView.bounds = Rect(size: frame.size)
                    sheetView.node.allChildrenAndSelf { $0.updateDatas() }
                    
                    sheetView.stopNotifications.append { [weak self] _ in
                        self?.showSelected()
                    }
                    sheetView.changeSelectedFrameNotifications.append { [weak self] _, _ in
                        self?.updateSelectedFrame()
                    }
                    
                    clearHistory(from: sheetView)
                    
                    if self.savingItem != nil {
                        self.savingFuncs.append { [model = sheetView.model, um = sheetView.history,
                                                   tm = self.thumbnailMipmap(from: sheetView),
                                                   weak self] in
                            
                            sheetRecorder.sheetRecord.value = model
                            sheetRecorder.sheetRecord.isWillwrite = true
                            sheetRecorder.sheetHistoryRecord.value = um
                            sheetRecorder.sheetHistoryRecord.isWillwrite = true
                            self?.updateStringRecord(at: sid, with: sheetView)
                            if let tm = tm {
                                self?.saveThumbnailRecord(tm, in: sheetRecorder)
                                self?.baseThumbnailBlocks[sid]
                                = try? Texture.block(from: tm.thumbnail4Data)
                            }
                        }
                    } else {
                        sheetRecorder.sheetRecord.value = sheetView.model
                        sheetRecorder.sheetHistoryRecord.value = sheetView.history
                        sheetRecorder.sheetHistoryRecord.isWillwrite = true
                        self.makeThumbnailRecord(at: sid, with: sheetView)
                        sheetRecorder.sheetRecord.willwriteClosure = { (_) in }
                    }
                }
            }
            
            guard !Task.isCancelled else { return }
            Sleep.start(atTime: 0.1)
            
            progressHandler(Double(j + 1) / Double(shps.count), &isStop)
            if isStop { break }
        }
    }
    func clearHistory(from sheetView: SheetView) {
        sheetView.clearHistory()
        if let directory = model.sheetRecorders[sheetView.id]?.contentsDirectory {
            let nUrls = Set(sheetView.model.contents.map { $0.url })
            directory.childrenURLs.filter { !nUrls.contains($0.value) }.forEach {
                try? directory.remove(from: $0.value, key: $0.key)
            }
        }
    }
    
    var defaultCursor = Cursor.drawLine
    var cursorNotifications = [((RootView, Cursor) -> ())]()
    var cursor = Cursor.drawLine {
        didSet {
            guard cursor != oldValue else { return }
            cursorNotifications.forEach { $0(self, cursor) }
        }
    }
    
    static let defaultBackgroundColor = Color.background
    var backgroundColorNotifications = [((RootView, Color) -> ())]()
    var backgroundColor = defaultBackgroundColor {
        didSet {
            guard backgroundColor != oldValue else { return }
            backgroundColorNotifications.forEach { $0(self, backgroundColor) }
        }
    }
    
    static let maxSheetCount = 10000
    static let maxSheetAABB = AABB(maxValueX: Double(maxSheetCount) * Sheet.width,
                                   maxValueY: Double(maxSheetCount) * Sheet.height)
    static let minPOVLog2Scale = -12.0, maxPOVLog2Scale = 10.0
    static func clippedPOVPosition(from p: Point) -> Point {
        var p = p
        if p.x < maxSheetAABB.minX {
            p.x = maxSheetAABB.minX
        } else if p.x > maxSheetAABB.maxX {
            p.x = maxSheetAABB.maxX
        }
        if p.y < maxSheetAABB.minY {
            p.y = maxSheetAABB.minY
        } else if p.y > maxSheetAABB.maxY {
            p.y = maxSheetAABB.maxY
        }
        return p
    }
    static func clippedPOV(from pov: Attitude) -> Attitude {
        var pov = pov
        pov.position = clippedPOVPosition(from: pov.position)
        let s = pov.scale.width
        if s != pov.scale.height {
            pov.scale = Size(square: s)
        }
        
        let logScale = pov.logScale
        if logScale.isNaN {
            pov.logScale = 0
        } else if logScale < minPOVLog2Scale {
            pov.logScale = minPOVLog2Scale
        } else if logScale > maxPOVLog2Scale {
            pov.logScale = maxPOVLog2Scale
        }
        return pov
    }
    
    var povNotifications = [((RootView, Attitude) -> ())]()
    var pov = Root.defaultPOV {
        didSet {
            model.povRecord.isWillwrite = true
            updateTransformsWithPOV()
            povNotifications.forEach { $0(self, pov) }
        }
    }
    var drawableSize = Size() {
        didSet {
            updateNode()
        }
    }
    var screenBounds = Rect() {
        didSet {
            centeringPOVTransform = Transform(translation: -screenBounds.centerPoint)
            viewportToScreenTransform = Transform(viewportSize: screenBounds.size)
            screenToViewportTransform = Transform(invertedViewportSize: screenBounds.size)
            updateTransformsWithPOV()
        }
    }
    var worldBoundsInScreen: Rect { screenBounds * screenToWorldTransform }
    private(set) var screenToWorldTransform = Transform.identity
    var screenToWorldScale: Double { screenToWorldTransform.absXScale }
    private(set) var worldToScreenTransform = Transform.identity
    private(set) var worldToScreenScale = 1.0
    private(set) var centeringPOVTransform = Transform.identity
    private(set) var viewportToScreenTransform = Transform.identity
    private(set) var screenToViewportTransform = Transform.identity
    private(set) var worldToViewportTransform = Transform.identity
    private func updateTransformsWithPOV() {
        screenToWorldTransform = centeringPOVTransform * pov.transform
        worldToScreenTransform = screenToWorldTransform.inverted()
        worldToScreenScale = worldToScreenTransform.absXScale
        worldToViewportTransform = worldToScreenTransform * screenToViewportTransform
        updateNode()
    }
    var updateNodeNotifications = [((RootView) -> ())]()
    func updateNode() {
        guard !drawableSize.isEmpty else { return }
        thumbnailType = self.thumbnailType(withScale: worldToScreenScale)
        readAndClose(with: screenBounds, screenToWorldTransform)
        updateMapWith(worldToScreenTransform: worldToScreenTransform,
                      screenToWorldTransform: screenToWorldTransform,
                      pov: pov,
                      in: screenBounds)
        updateGrid(with: screenToWorldTransform, in: screenBounds)
        updateNodeNotifications.forEach { $0(self) }
        updateRunningNodesPosition()
        updateSheetViewsWithPOV()
//        updateCursorNode()
    }
    let editableMapScale = 2.0 ** -4
    var isEditingSheet: Bool {
        worldToScreenScale > editableMapScale
    }
    var worldLineWidth: Double {
        Line.defaultLineWidth * screenToWorldScale
    }
    func convertScreenToWorld<T: AppliableTransform>(_ v: T) -> T {
        v * screenToWorldTransform
    }
    func convertWorldToScreen<T: AppliableTransform>(_ v: T) -> T {
        v * worldToScreenTransform
    }
    
    func roundedPoint(from p: Point) -> Point {
        Self.roundedPoint(from: p, scale: worldToScreenScale)
    }
    static func roundedPoint(from p: Point, scale: Double) -> Point {
        let decimalPlaces = Int(max(0, .log10(scale)) + 2)
        return p.rounded(decimalPlaces: decimalPlaces)
    }
    
    func updateSheetViewsWithPOV() {
        sheetViewValues.forEach {
            if let view = $0.value.sheetView {
                updateWithEditGrid(in: view)
                view.screenToWorldScale = screenToWorldScale
            }
        }
    }
    func updateWithEditGrid(in sheetView: SheetView) {
        let editGrid = EditGrid(logScale: pov.logScale)
        sheetView.textsView.elementViews.forEach { $0.editGrid = editGrid }
        sheetView.contentsView.elementViews.forEach { $0.editGrid = editGrid }
        sheetView.scoreView.editGrid = editGrid
        sheetView.animationView.editGrid = editGrid
    }
    
    var sheetLineWidth: Double { Line.defaultLineWidth }
    var sheetTextSize: Double { pov.logScale > 2 ? 100.0 : Font.defaultSize }
    
    var runningNodes = [(origin: Point, node: Node)]()
    var runningsNode: Node?
    func updateRunningNodes(fromWorldPrintOrigins wpos: [Point]) {
        runningNodes.forEach { $0.node.removeFromParent() }
        runningNodes = wpos.map {
            let text = Text(string: "Calculating".localized)
            let textNode = text.node
            let runningNode = Node(children: [textNode], isHidden: true,
                                  path: Path(textNode.bounds?.inset(by: -10) ?? Rect(),
                                             cornerRadius: 8),
                                  lineWidth: 1, lineType: .color(.border),
                                  fillType: .color(.background))
            return ($0, runningNode)
        }
        runningNodes.forEach { node.append(child: $0.node) }
        
        updateRunningNodesPosition()
    }
    func updateRunningNodesPosition() {
        guard !runningNodes.isEmpty else { return }
        let b = screenBounds.inset(by: 5)
        for (p, runningNode) in runningNodes {
            let sp = convertWorldToScreen(p)
            if !b.contains(sp) || worldToScreenScale < 0.25 {
                runningNode.isHidden = false
                
                let fp = b.centerPoint
                let ps = b.intersection(Edge(fp, sp))
                if !ps.isEmpty, let cvb = runningNode.bounds {
                    let np = ps[0]
                    let cvf = Rect(x: np.x - cvb.width / 2,
                                   y: np.y - cvb.height / 2,
                                   width: cvb.width, height: cvb.height)
                    let nf = screenBounds.inset(by: 5).clipped(cvf)
                    runningNode.attitude.position = convertScreenToWorld(nf.origin - cvb.origin)
                } else {
                    runningNode.attitude.position = p
                }
                runningNode.attitude.scale = Size(square: 1 / worldToScreenScale)
                if pov.rotation != 0 {
                    runningNode.attitude.rotation = pov.rotation
                }
            } else {
                runningNode.isHidden = true
            }
        }
    }
    
    var selectedBounds: Rect? {
        world.selection.sheetIDs.reduce(into: Rect?.none) { $0 += sheetFrame(at: $1) }
    }
    func updateSelectedFrame() {
        let nodes: [Node] = sheetViewValues.compactMap {
            guard let sheetView = $0.value.sheetView else {
                return nil
            }
            sheetView.updateSelectedFrame()
            return sheetView.selectedFrameNode
        }
        
        if nodes.isEmpty {
            if !selectedFrameNode.children.isEmpty {
                selectedFrameNode.children = []
            }
        } else {
            selectedFrameNode.children = nodes
        }
        updateSelectedWithIsEditingSheet()
    }
    func updateSelected() {
        let shps = Set(world.selectedSheetPositions)
        if shps.isEmpty {
            if !selectedNode.children.isEmpty {
                selectedNode.children = []
            }
        } else {
            let roads = roads(fromMap: shps)
            var roadPathlines = roads.compactMap {
                $0.pathlineWith(width: Sheet.width, height: Sheet.height)
            }
            let rects = shps.map { sheetFrame(with: $0) }
            let framePath = Path(rects.map { .init($0) })
            
            if let lastPs = selectedLastPositionLinePoints {
                roadPathlines.append(.init(lastPs))
            }
            
            let l = worldLineWidth
            selectedNode.children = [Node(path: framePath,
                                          lineWidth: l,
                                          lineType: .color(.selected),
                                          fillType: .color(.subSelected))] +
            (!roadPathlines.isEmpty ? [.init(path: .init(roadPathlines, isCap: false),
                                             lineWidth: l * 0.5,
                                             lineType: .color(.selected))] : [])
        }
        updateSelectedWithIsEditingSheet()
    }
    func updateSelectedNodesWithScale() {
        if isEditingSheet {
           updateSelectedFrame()
        } else {
            let l = worldLineWidth
            if selectedNode.children.count == 1 {
                selectedNode.children[0].lineWidth = l
            } else if selectedNode.children.count == 2 {
                selectedNode.children[0].lineWidth = l
                selectedNode.children[1].lineWidth = l * 0.5
            }
        }
        updateSelectedWithIsEditingSheet()
    }
    func updateSelectedWithIsEditingSheet() {
        if isEditingSheet {
            selectedFrameNode.isHidden = isHiddenSelected
            selectedNode.isHidden = true
        } else {
            selectedFrameNode.isHidden = true
            selectedNode.isHidden = isHiddenSelected
        }
    }
    func updateSelectedColor(isMain: Bool) {
        let selectedColor = isMain ? Color.selected : Color.diselected
        let subSelectedColor = isMain ? Color.subSelected : Color.subDiselected
        selectedNode.children.forEach {
            if $0.fillType != nil {
                $0.fillType = .color(subSelectedColor)
            }
            if $0.lineType != nil {
                $0.lineType = .color(selectedColor)
            }
        }
        selectedFrameNode.children.forEach {
            $0.children.forEach {
                if $0.fillType != nil {
                    $0.fillType = .color(selectedColor)
                }
                if $0.lineType != nil {
                    $0.lineType = .color(selectedColor)
                }
            }
        }
        
        sheetViewValues.forEach {
            $0.value.sheetView?.updateSelectedColor(isMain: isMain)
        }
    }
    var isHiddenSelected = false {
        didSet {
            selectedNode.isHidden = isHiddenSelected ? true : isEditingSheet
            selectedFrameNode.isHidden = isHiddenSelected ? true : !isEditingSheet
        }
    }
    func showSelected() {
        isHiddenSelected = false
    }
    func hideSelected() {
        isHiddenSelected = true
    }
    
    var finding = Finding() {
        didSet {
            model.findingRecord.isWillwrite = true
            updateWithFinding()
        }
    }
    private var findingNode: Node?
    private(set) var findingChildNodeDic = [IntPoint: Node]()
    let findingSplittedWidth = (Double.hypot(Sheet.width / 2, Sheet.height / 2) * 1.25).rounded()
    var findingLineWidth: Double {
        isEditingFinding ? worldLineWidth * 2 : worldLineWidth
    }
    var isEditingFinding = false {
        didSet {
            guard isEditingFinding != oldValue else { return }
            let l = findingLineWidth
            findingChildNodeDic.forEach { v in
                v.value.children.forEach { $0.lineWidth = l }
            }
            if !isEditingFinding {
                editingFindingSheetView = nil
                editingFindingTextView = nil
                editingFindingRange = nil
                editingFindingOldString = nil
                editingFindingOldRemovedString = nil
            }
        }
    }
    weak var editingFindingSheetView: SheetView?,
             editingFindingTextView: SheetTextView?
    var editingFindingRange: Range<Int>?,
        editingFindingOldString: String?,
        editingFindingOldRemovedString: String?
    func updateWithFinding() {
        guard !finding.isEmpty else {
            if findingNode != nil {
                findingChildNodeDic = [:]
                findingNode?.removeFromParent()
                findingNode = nil
            }
            return
        }
        
        var findingChildNodes = [Node]()
        var findingChildrenNodeDic = [IntPoint: Node]()
        for sr in model.sheetRecorders {
            guard let shp = sheetPosition(at: sr.key) else { continue }
            if !world.selection.isEmpty && !world.selection.sheetIDs.contains(sr.key) { continue }
            let string = sheetViewValues[shp]?.sheetView?.model.allTextsString
                ?? sr.value.stringRecord.decodedValue
            if string?.contains(finding.string) ?? false {
                let findingChildNode = Node()
                findingChildrenNodeDic[shp] = findingChildNode
                findingChildNodes.append(findingChildNode)
            }
        }
        
        self.findingChildNodeDic = findingChildrenNodeDic
        findingNode?.removeFromParent()
        let findingNode = Node(children: findingChildNodes)
        node.append(child: findingNode)
        self.findingNode = findingNode
        findingChildrenNodeDic.forEach { updateFindingNodes(at: $0.key) }
    }
    func updateFinding(at p: Point) {
        guard !finding.isEmpty else { return }
        if let sheetView = sheetView(at: p) {
            updateFinding(from: sheetView)
        }
    }
    func updateFinding(from sheetView: SheetView) {
        guard !finding.isEmpty,
              let shp = sheetPosition(from: sheetView) else { return }
        updateFindingNodes(at: shp)
    }
    func sheetPosition(from sheetView: SheetView) -> IntPoint? {
        for svv in sheetViewValues {
            if sheetView == svv.value.sheetView {
                return svv.key
            }
        }
        return nil
    }
    private func updateFindingNodes(at shp: IntPoint) {
        guard let findingChildNode = findingChildNodeDic[shp] else { return }
        
        let sf = sheetFrame(with: shp)
        let l = findingLineWidth, p: Point
        var nodes = [Node]()
        if finding.worldPosition.distance(sf.centerPoint) < findingSplittedWidth {
            p = finding.worldPosition
        } else {
            let angle = sf.centerPoint.angle(finding.worldPosition)
            p = sf.centerPoint.movedWith(distance: findingSplittedWidth,
                                         angle: angle)
            nodes.append(.init(path: Path([Pathline([finding.worldPosition, p])]),
                               lineWidth: l,
                               lineType: .color(.selected)))
        }
        if let nSheetView = sheetView(at: shp) {
            for textView in nSheetView.textsView.elementViews {
                let text = textView.model
                
                var ranges = text.string.ranges(of: finding.string)
                if nSheetView == editingFindingSheetView
                    && textView == editingFindingTextView,
                   let oldRemovedString = editingFindingOldRemovedString,
                   let (intRange, substring) = oldRemovedString
                    .difference(to: textView.model.string) {
                    
                    let nr = intRange.lowerBound ..< (intRange.lowerBound + substring.count)
                    let editingRange = textView.model.string.range(fromInt: nr)
                    ranges = ranges.filter { !$0.intersects(editingRange) }
                    ranges.append(editingRange)
                }
                
                for range in ranges {
                    let rects = textView.transformedPaddingRects(with: range).map {
                        nSheetView.convertToWorld($0)
                    }
                    rects.forEach {
                        nodes.append(Node(path: Path($0),
                                          lineWidth: l,
                                          lineType: .color(.selected),
                                          fillType: .color(.subSelected)))
                    }
                    if let rect = rects.first {
                        nodes.append(Node(path: Path([Pathline([p,
                                                                rect.centerPoint])]),
                                          lineWidth: l,
                                          lineType: .color(.selected)))
                    }
                    if rects.count >= 2 {
                        let r0 = rects[0], r1 = rects[1]
                        switch text.orientation {
                        case .horizontal:
                            let w = r0.minX - r1.maxX
                            if w > 0 {
                                nodes.append(Node(path: Path(Edge(r0.minXMinYPoint,
                                                                      r1.maxXMaxYPoint)),
                                                      lineWidth: l,
                                                      lineType: .color(.selected)))
                            }
                        case .vertical:
                            let h = r1.minY - r0.maxY
                            if h > 0 {
                                nodes.append(Node(path: Path(Edge(r0.minXMaxYPoint,
                                                                  r1.maxXMinYPoint)),
                                                  lineWidth: l,
                                                  lineType: .color(.selected)))
                            }
                        }
                    }
                }
            }
            if let uuid = UUID(uuidString: finding.string) {
                for planeView in nSheetView.planesView.elementViews {
                    if planeView.model.uuColor.id == uuid {
                        if let pp = planeView.model.topolygon.polygon.points.first {
                            let ppp = nSheetView.convertToWorld(pp)
                            nodes.append(Node(path: Path([Pathline([p,
                                                                    ppp])]),
                                              lineWidth: l,
                                              lineType: .color(.selected)))
                        }
                    }
                }
            }
        } else {
            nodes.append(Node(path: Path(sf),
                              lineWidth: l,
                              lineType: .color(.selected),
                              fillType: .color(.subSelected)))
            nodes.append(Node(path: Path([Pathline([p,
                                                    sf.centerPoint])]),
                              lineWidth: l,
                              lineType: .color(.selected)))
        }
        findingChildNode.children = nodes
    }
    func updateFindingNodes() {
        if !finding.isEmpty, !findingChildNodeDic.isEmpty {
            let l = findingLineWidth
            findingChildNodeDic.values.forEach {
                $0.children.forEach { $0.lineWidth = l }
            }
        }
    }
    func findingNode(at p: Point) -> Node? {
        let shp = sheetPosition(at: p)
        for (nshp, findingChildNode) in findingChildNodeDic {
            guard nshp == shp else { continue }
            for child in findingChildNode.children {
                if child.contains(p) {
                    return child
                }
            }
        }
        return nil
    }
    func replaceFinding(from toStr: String,
                        oldString: String? = nil,
                        oldTextView: SheetTextView? = nil) {
        let fromStr = finding.string
        @Sendable func make(_ sheetView: SheetView) -> Bool {
            var isNewUndoGroup = true
            func updateUndoGroup() {
                if isNewUndoGroup {
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    isNewUndoGroup = false
                }
            }
            let sb = sheetView.bounds.inset(by: Sheet.textPadding)
            let selection = sheetView.model.selection
            for (i, textView) in sheetView.textsView.elementViews.enumerated() {
                var text = textView.model
                if selection.textSelections.isEmpty || selection.textSelections[i] != nil,
                   text.string.contains(fromStr) {
                    let rRange = 0 ..< text.string.count
                    var ns = text.string
                    if let oldString = oldString, let oldTextView = oldTextView,
                       oldTextView == textView {
                        ns = oldString
                    }
                    ns = ns.replacingOccurrences(of: fromStr, with: toStr)
                    text.replaceSubrange(ns, from: rRange, clipFrame: sb)
                    let origin = textView.model.origin != text.origin ?
                    text.origin : nil
                    let size = textView.model.size != text.size ?
                    text.size : nil
                    let widthCount = textView.model.widthCount != text.widthCount ?
                    text.widthCount : nil
                    let tv = TextValue(string: ns,
                                       replacedRange: rRange,
                                       origin: origin, size: size,
                                       widthCount: widthCount)
                    updateUndoGroup()
                    sheetView.replace(IndexValue(value: tv, index: i))
                }
            }
            return !isNewUndoGroup
        }
        
        var recordCount = 0
        for (shp, _) in findingChildNodeDic {
            if sheetViewValues[shp]?.sheetView == nil,
                let sid = sheetID(at: shp), model.sheetRecorders[sid] != nil {
                
                recordCount += 1
            }
        }
        if findingChildNodeDic.count >= 2 {
            for (shp, _) in findingChildNodeDic {
                if sheetViewValues[shp]?.sheetView != nil,
                   let sid = sheetID(at: shp), model.sheetRecorders[sid] != nil {
                    
                    recordCount += 1
                }
            }
            let nRecordCount = recordCount
            
            Task { @MainActor in
                let result = await node
                    .show(message: String(format: "Do you want to replace the \"%2$@\" written on the %1$d sheets with the \"%3$@\"?".localized, nRecordCount, fromStr.omit(count: 12), toStr.omit(count: 12)),
                          infomation: "This operation can be undone for each sheet, but not for all sheets at once.".localized,
                          okTitle: "Replace".localized,
                          isDefaultButton: true)
                guard result == .ok else { return }
                
                syncSave()
                
                let progressPanel = ProgressPanel(message: "Replacing sheets".localized)
                node.show(progressPanel)
                let shps = Array(findingChildNodeDic.keys)
                let task = Task.detached(priority: .high) {
                    let progress = ActorProgress(total: shps.count)
                    for shp in shps {
                        Task { @MainActor in
                            if let sheetView = self.sheetViewValues[shp]?.sheetView {
                                _ = make(sheetView)
                            } else if let sid = self.sheetID(at: shp),
                                      let sheetRecorder = self.model.sheetRecorders[sid] {
                                let record = sheetRecorder.sheetRecord
                                let historyRecord = sheetRecorder.sheetHistoryRecord
                                guard let sheet = record.decodedValue else { return }
                                
                                let sheetBinder = RecordBinder(value: sheet, record: record)
                                let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value,
                                                          history: historyRecord.decodedValue ?? .init())
                                sheetView.screenToWorldScale = self.screenToWorldScale
                                let frame = self.sheetFrame(with: shp)
                                sheetView.bounds = Rect(size: frame.size)
                                sheetView.node.allChildrenAndSelf { $0.updateDatas() }
                                
                                sheetView.stopNotifications.append { [weak self] _ in
                                    self?.showSelected()
                                }
                                sheetView.changeSelectedFrameNotifications.append { [weak self] _, _ in
                                    self?.updateSelectedFrame()
                                }
                                
                                if make(sheetView) {
                                    if self.savingItem != nil {
                                        self.savingFuncs.append { [model = sheetView.model, um = sheetView.history,
                                                                   tm = self.thumbnailMipmap(from: sheetView),
                                                                   weak self] in
                                            
                                            sheetRecorder.sheetRecord.value = model
                                            sheetRecorder.sheetRecord.isWillwrite = true
                                            sheetRecorder.sheetHistoryRecord.value = um
                                            sheetRecorder.sheetHistoryRecord.isWillwrite = true
                                            self?.updateStringRecord(at: sid, with: sheetView)
                                            if let tm = tm {
                                                self?.saveThumbnailRecord(tm, in: sheetRecorder)
                                                self?.baseThumbnailBlocks[sid]
                                                = try? Texture.block(from: tm.thumbnail4Data)
                                            }
                                        }
                                    } else {
                                        sheetRecorder.sheetRecord.value = sheetView.model
                                        sheetRecorder.sheetHistoryRecord.value = sheetView.history
                                        sheetRecorder.sheetHistoryRecord.isWillwrite = true
                                        self.makeThumbnailRecord(at: sid, with: sheetView)
                                        sheetRecorder.sheetRecord.willwriteClosure = { (_) in }
                                    }
                                }
                            }
                        }
                        
                        guard !Task.isCancelled else { return }
                        Sleep.start(atTime: 0.1)
                        
                        await progress.addCount()
                        Task { @MainActor in
                            progressPanel.progress = await progress.fractionCompleted
                        }
                    }
                    
                    Task { @MainActor in
                        progressPanel.closePanel()
                        self.finding.string = toStr
                    }
                }
                progressPanel.cancelHandler = { task.cancel() }
            }
        } else {
            for (shp, _) in findingChildNodeDic {
                if let sheetView = sheetViewValues[shp]?.sheetView {
                    _ = make(sheetView)
                }
            }
            finding.string = toStr
        }
    }
    
    func replaceTempo(fromTempo tempo: Rational, in shps: [IntPoint]) {
        let shps = Array(Set(shps))
        @Sendable func make(_ sheetView: SheetView) -> Bool {
            var isNewUndoGroup = false
            func updateUndoGroup() {
                if !isNewUndoGroup {
                    sheetView.newUndoGroup()
                    isNewUndoGroup = true
                }
            }
            
            if sheetView.model.animation.enabled, sheetView.model.animation.tempo != tempo {
                updateUndoGroup()
                var option = sheetView.model.animation.option
                option.tempo = tempo
                sheetView.set(option)
            }
            if sheetView.model.score.enabled, sheetView.model.score.tempo != tempo {
                updateUndoGroup()
                var option = sheetView.model.score.option
                option.tempo = tempo
                sheetView.set(option)
            }
            for (ci, content) in sheetView.model.contents.enumerated() {
                if content.timeOption != nil, content.tempo != tempo {
                    updateUndoGroup()
                    var content = content
                    content.timeOption?.tempo = tempo
                    sheetView.replace(content, at: ci)
                }
            }
            for (ti, text) in sheetView.model.texts.enumerated() {
                if text.timeOption != nil, text.tempo != tempo {
                    updateUndoGroup()
                    var text = text
                    text.timeOption?.tempo = tempo
                    sheetView.replace([IndexValue(value: text, index: ti)])
                }
            }
            return isNewUndoGroup
        }
        
        var recordCount = 0
        for shp in shps {
            if sheetViewValues[shp]?.sheetView == nil,
                let sid = sheetID(at: shp), model.sheetRecorders[sid] != nil {
                
                recordCount += 1
            }
        }
        if shps.count >= 2 {
            for shp in shps {
                if sheetViewValues[shp]?.sheetView != nil,
                   let sid = sheetID(at: shp), model.sheetRecorders[sid] != nil {
                    
                    recordCount += 1
                }
            }
            let nRecordCount = recordCount
            
            Task { @MainActor in
                let result = await node
                    .show(message: String(format: "Do you want to change the tempo of %1$d sheets to %2$@?".localized, nRecordCount, Sheet.tempoNameFromStandardFrameRate(withTempo: tempo)),
                          infomation: "This operation can be undone for each sheet, but not for all sheets at once.".localized,
                          okTitle: "Replace".localized,
                          isDefaultButton: true)
                guard result == .ok else { return }
                
                syncSave()
                
                let progressPanel = ProgressPanel(message: "Replacing tempos".localized)
                node.show(progressPanel)
                let task = Task.detached(priority: .high) {
                    let progress = ActorProgress(total: shps.count)
                    for shp in shps {
                        Task { @MainActor in
                            if let sheetView = self.sheetViewValues[shp]?.sheetView {
                                _ = make(sheetView)
                            } else if let sid = self.sheetID(at: shp),
                                      let sheetRecorder = self.model.sheetRecorders[sid] {
                                let record = sheetRecorder.sheetRecord
                                let historyRecord = sheetRecorder.sheetHistoryRecord
                                guard let sheet = record.decodedValue else { return }
                                
                                let sheetBinder = RecordBinder(value: sheet, record: record)
                                let sheetView = SheetView(binder: sheetBinder,
                                                          keyPath: \SheetBinder.value,
                                                          history: historyRecord.decodedValue ?? .init())
                                sheetView.screenToWorldScale = self.screenToWorldScale
                                let frame = self.sheetFrame(with: shp)
                                sheetView.bounds = Rect(size: frame.size)
                                sheetView.node.allChildrenAndSelf { $0.updateDatas() }
                                
                                sheetView.stopNotifications.append { [weak self] _ in
                                    self?.showSelected()
                                }
                                sheetView.changeSelectedFrameNotifications.append { [weak self] _, _ in
                                    self?.updateSelectedFrame()
                                }
                                
                                if make(sheetView) {
                                    if self.savingItem != nil {
                                        self.savingFuncs.append { [model = sheetView.model, um = sheetView.history,
                                                                   tm = self.thumbnailMipmap(from: sheetView),
                                                                   weak self] in
                                            
                                            sheetRecorder.sheetRecord.value = model
                                            sheetRecorder.sheetRecord.isWillwrite = true
                                            sheetRecorder.sheetHistoryRecord.value = um
                                            sheetRecorder.sheetHistoryRecord.isWillwrite = true
                                            self?.updateStringRecord(at: sid, with: sheetView)
                                            if let tm = tm {
                                                self?.saveThumbnailRecord(tm, in: sheetRecorder)
                                                self?.baseThumbnailBlocks[sid]
                                                = try? Texture.block(from: tm.thumbnail4Data)
                                            }
                                        }
                                    } else {
                                        sheetRecorder.sheetRecord.value = sheetView.model
                                        sheetRecorder.sheetHistoryRecord.value = sheetView.history
                                        sheetRecorder.sheetHistoryRecord.isWillwrite = true
                                        self.makeThumbnailRecord(at: sid, with: sheetView)
                                        sheetRecorder.sheetRecord.willwriteClosure = { (_) in }
                                    }
                                }
                            }
                        }
                        
                        guard !Task.isCancelled else { return }
                        Sleep.start(atTime: 0.1)
                        
                        await progress.addCount()
                        Task { @MainActor in
                            progressPanel.progress = await progress.fractionCompleted
                        }
                    }
                    
                    Task { @MainActor in
                        progressPanel.closePanel()
                    }
                }
                progressPanel.cancelHandler = { task.cancel() }
            }
        } else {
            for shp in shps {
                if let sheetView = sheetViewValues[shp]?.sheetView {
                    _ = make(sheetView)
                }
            }
        }
    }
    
    func containsLookingUp(at wp: Point) -> Bool {
        lookingUpBoundsNode?.path
            .contains(lookingUpNode.convertFromWorld(wp)) ?? false
    }
    private(set) var isShownLookingUp = false
    private(set) var lookingUpNode = Node(), lookingUpBoundsNode: Node?,
                     lookingUpString = ""
    func show(_ string: String, at origin: Point) {
        show(string, rects: [Rect(origin: origin)], .horizontal, fontSize: Font.defaultSize)
    }
    func show(_ string: String, rects: [Rect], _ orientation: Orientation,
              fontSize: Double = Font.smallSize,
              margin: Double = 3, padding: Double = 5,
              textPadding: Double = 3, cornerRadius: Double = 4) {
        closeLookingUpNode()
        guard !rects.isEmpty else {
            lookingUpString = ""
            return
        }
        let pd = margin + 3.75 + textPadding + fontSize / 2 + 1
        let lpd = margin
        var backNodes = [Node](), lineNodes = [Node]()
        func backNode(from path: Path) -> Node {
            return Node(path: path,
                        lineWidth: 1,
                        lineType: .color(.subBorder),
                        fillType: .color(.transparentDisabled))
        }
        func lineNode(from path: Path) -> Node {
            return Node(path: path,
                        lineWidth: 1,
                        lineType: .color(.subBorder),
                        fillType: .color(.transparentDisabled))
        }
        let origin = rects.count == 1 && rects[0].size.isEmpty ? rects[0].origin : nil
        let textOrigin: Point
        if let origin {
            lookingUpNode.attitude = .init(position: origin,
                                           scale: .init(square: screenToWorldScale))
            textOrigin = Point(0, -pd)
            backNodes = [Node(path: Path(circleRadius: 4),
                              lineWidth: 1,
                              lineType: .color(.subBorder),
                              fillType: .color(.transparentDisabled))]
            lineNodes = [Node(path: Path(circleRadius: 1.5),
                              fillType: .color(.content))]
        } else {
            lookingUpNode.attitude = .init()
            switch orientation {
            case .horizontal:
                textOrigin = rects[0].minXMinYPoint + Point(0, -pd)
                backNodes = rects.map {
                    let rect = Rect(Edge($0.minXMinYPoint + Point(0, -lpd),
                                         $0.maxXMinYPoint + Point(0, -lpd)))
                    return backNode(from: Path(rect.inset(by: -2),
                                               cornerRadius: 1))
                }
                lineNodes = rects.map {
                    Node(path: Path(Edge($0.minXMinYPoint + Point(0, -lpd),
                                         $0.maxXMinYPoint + Point(0, -lpd))),
                         lineWidth: 1, lineType: .color(.content))
                }
            case .vertical:
                textOrigin = rects[0].minXMaxYPoint + Point(-pd, 0)
                backNodes = rects.map {
                    let rect = Rect(Edge($0.minXMaxYPoint + Point(-lpd, 0),
                                         $0.minXMinYPoint + Point(-lpd, 0)))
                    return backNode(from: Path(rect.inset(by: -2),
                                               cornerRadius: 1))
                }
                lineNodes = rects.map {
                    Node(path: Path(Edge($0.minXMaxYPoint + Point(-lpd, 0),
                                         $0.minXMinYPoint + Point(-lpd, 0))),
                         lineWidth: 1, lineType: .color(.content))
                }
            }
        }
        let text = Text(string: string, orientation: orientation,
                        size: fontSize, widthCount: 30, origin: textOrigin)
        var typobute = text.typobute
        typobute.clippedMaxTypelineWidth = text.size * 30
        let typesetter = Typesetter(string: text.string, typobute: typobute)
        guard let b = typesetter.typoBounds?
            .outset(by: padding) else { return }
        let textNode = Node(attitude: Attitude(position: text.origin),
                            path: typesetter.path(), fillType: .color(.content))
        let boundsNode = Node(path: Path(b + text.origin,
                                         cornerRadius: cornerRadius),
                              lineWidth: 1,
                              lineType: .color(.subBorder),
                              fillType: .color(.transparentDisabled))
        lookingUpNode.children = backNodes + lineNodes + [boundsNode, textNode]
        lookingUpBoundsNode = boundsNode
        if lookingUpNode.parent == nil {
            node.append(child: lookingUpNode)
        }
        isShownLookingUp = true
        lookingUpString = string
    }
    private func closeLookingUpNode() {
        lookingUpBoundsNode = nil
        lookingUpNode.children = []
        lookingUpNode.path = Path()
        lookingUpNode.removeFromParent()
    }
    func closeLookingUp() {
        if isShownLookingUp {
            closeLookingUpNode()
            isShownLookingUp = false
        }
    }
    
    func unselectAndNewUndoGroupIfNeeded() {
        if !world.selection.isEmpty {
            newUndoGroup()
            doSet(WorldSelection.empty)
        }
    }
    func unselectAllAndNewUndoGroupIfNeeded() {
        sheetViewValues.forEach {
            $0.value.sheetView?.unselectAndNewUndoGroupIfNeeded()
        }
        if !world.selection.isEmpty {
            newUndoGroup()
            doSet(WorldSelection.empty)
        }
    }
    func unselectAllAndNewUndoGroupIfNeeded(withoutTextI textI: Int, in sheetView: SheetView) {
        sheetViewValues.forEach {
            if $0.value.sheetView == sheetView {
                $0.value.sheetView?.unselectAndNewUndoGroupIfNeeded(withoutText: textI)
            } else {
                $0.value.sheetView?.unselectAndNewUndoGroupIfNeeded()
            }
        }
        if !world.selection.isEmpty {
            newUndoGroup()
            doSet(WorldSelection.empty)
        }
    }
    func closeAllPanels(at p: Point) {
        closeLookingUp()
        finding = Finding()
    }
    
    func endSeqencer() {
        sheetViewValues.forEach { $0.value.sheetView?.endSeqencer() }
    }
    
    private var menuNode: Node?
    
    weak var editingSheetView: SheetView?
    weak var editingTextView: SheetTextView? {
        didSet {
            if editingTextView !== oldValue {
                oldValue?.unmark()
                TextInputContext.update()
                oldValue?.isHiddenSelectedRange = true
            }
            editingTextView?.isHiddenSelectedRange = false
            if editingTextView == nil && Cursor.isHidden {
                Cursor.isHidden = false
            }
        }
    }
    var textMaxTypelineWidthNode = Node(lineWidth: 0.5, lineType: .color(.border))
    var textCursorWidthNode = Node(lineWidth: 3, lineType: .color(.subBorder))
    var textCursorNode = Node(lineWidth: 0.5, lineType: .color(.background),
                              fillType: .color(.content))
    func updateTextCursor(isMove: Bool = false) {
        func close() {
            if textCursorNode.parent != nil {
                textCursorNode.removeFromParent()
            }
            if textCursorWidthNode.parent != nil {
                textCursorWidthNode.removeFromParent()
            }
            if textMaxTypelineWidthNode.parent != nil {
                textMaxTypelineWidthNode.removeFromParent()
            }
        }
        if isEditingSheet && editingTextView == nil,
           let sheetView = sheetView(at: cursorSHP) {
            
            if isMove {
                sheetView.selectedTextView = nil
            }
            
            if !sheetView.model.texts.isEmpty {
                let cp = convertScreenToWorld(cursorPoint)
                let vp = sheetView.convertFromWorld(cp)
                if let textView = sheetView.selectedTextView,
                   let i = textView.selectedRange?.lowerBound {
                    
                    if textMaxTypelineWidthNode.parent == nil {
                        node.append(child: textMaxTypelineWidthNode)
                    }
                    if textMaxTypelineWidthNode.isHidden {
                        textMaxTypelineWidthNode.isHidden = false
                    }
                    if textCursorWidthNode.parent == nil {
                        node.append(child: textCursorWidthNode)
                    }
                    if textCursorNode.parent == nil {
                        node.append(child: textCursorNode)
                    }
                    if textCursorWidthNode.isHidden {
                        textCursorWidthNode.isHidden = false
                    }
                    if textCursorNode.isHidden {
                        textCursorNode.isHidden = false
                    }
                    let path = textView.typesetter.cursorPath(at: i)
                    textCursorNode.path = textView.convertToWorld(path)
                    textCursorWidthNode.path = textCursorNode.path
                    let mPath = textView.typesetter.maxTypelineWidthPath
                    textMaxTypelineWidthNode.path = textView.convertToWorld(mPath)
                } else if let (textView, _, _, cursorIndex) = sheetView.textTuple(at: vp, scale: screenToWorldScale) {
                    if textMaxTypelineWidthNode.parent == nil {
                        node.append(child: textMaxTypelineWidthNode)
                    }
                    if textMaxTypelineWidthNode.isHidden {
                        textMaxTypelineWidthNode.isHidden = false
                    }
                    if textCursorWidthNode.parent == nil {
                        node.append(child: textCursorWidthNode)
                    }
                    if textCursorNode.parent == nil {
                        node.append(child: textCursorNode)
                    }
                    if textCursorNode.isHidden {
                        textCursorNode.isHidden = false
                    }
                    let ratio = textView.model.size / Font.defaultSize
                    textCursorWidthNode.lineWidth = 1 * ratio
                    textCursorNode.lineWidth = 0.5 * ratio
                    textMaxTypelineWidthNode.lineWidth = 0.5 * ratio
                    
                    if let wcpath = textView.typesetter.warpCursorPath(at: textView.convertFromWorld(cp)) {
                        
                        textCursorWidthNode.path = textView.convertToWorld(wcpath)
                        textCursorWidthNode.isHidden = false
                    } else {
                        textCursorWidthNode.isHidden = true
                    }
                    let path = textView.typesetter
                        .cursorPath(at: cursorIndex,
                                    halfWidth: 0.75, heightRatio: 0.3)
                    textCursorNode.path = textView.convertToWorld(path)
                    let mPath = textView.typesetter.maxTypelineWidthPath
                    textMaxTypelineWidthNode.path = textView.convertToWorld(mPath)
                } else {
                    close()
                }
            } else {
                close()
            }
        } else {
            close()
        }
    }
    
    let thumbnail4Scale = 2.0 ** -8 * baseThumbnailScale
    let thumbnail16Scale = 2.0 ** -6 * baseThumbnailScale
    let thumbnail64Scale = 2.0 ** -4 * baseThumbnailScale
    let thumbnail256Scale = 2.0 ** -2 * baseThumbnailScale
    let thumbnail1024Scale = 2.0 ** 0 * baseThumbnailScale
    func thumbnailType(withScale scale: Double) -> Model.ThumbnailType {
        if scale < thumbnail4Scale {
            .w4
        } else if scale < thumbnail16Scale {
            .w16
        } else if scale < thumbnail64Scale {
            .w64
        } else if scale < thumbnail256Scale {
            .w256
        } else {
            .w1024
        }
    }
    var thumbnailType = Model.ThumbnailType.w4
    
    private(set) var baseThumbnailBlocks: [UUID: Texture.Block]
    
    struct ThumbnailNodeValue {
        var type: Model.ThumbnailType?
        let sheetID: UUID
        var node: Node?
        var task: Task<(), any Error>?
    }
    private(set) var thumbnailNodeValues = [IntPoint: ThumbnailNodeValue]()
    
    struct SheetViewValue {
        let sheetID: UUID
        var sheetView: SheetView?
        var loadingNode: Node?, isLoading = false
        var task: Task<(), any Error>?
    }
    private(set) var sheetViewValues = [IntPoint: SheetViewValue]()
    
    @discardableResult
    func readThumbnailNode(at sid: UUID) -> Node? {
        guard let shp = sheetPosition(at: sid) else { return nil }
        if let tv = thumbnailNodeValues[shp]?.node { return tv }
        let ssFrame = sheetFrame(with: shp)
        return Node(attitude: Attitude(position: ssFrame.origin),
                    path: Path(Rect(size: ssFrame.size)),
                    fillType: readFillType(at: sid) ?? .color(.disabled))
    }
    func readThumbnail(at sid: UUID) -> Texture? {
        if let shp = sheetPosition(at: sid) {
            if let fillType = thumbnailNode(at: shp)?.fillType,
               case .texture(let thumbnailTexture) = fillType {
                
                if Int(thumbnailTexture.size.width) != thumbnailType.rawValue {
                    guard let data = readThumbnailData(at: sid),
                          let nThumbnailTexture = try? Texture(imageData: data, isOpaque: true) else { return nil }
                    return nThumbnailTexture
                }
                return thumbnailTexture
            }
        }
        
        guard let data = readThumbnailData(at: sid),
              let thumbnailTexture = try? Texture(imageData: data, isOpaque: true) else {
            return model.thumbnailRecord(at: sid, with: thumbnailType)?.decodedValue?.texture
        }
        return thumbnailTexture
    }
    func readFillType(at sid: UUID) -> Node.FillType? {
        if let shp = sheetPosition(at: sid) {
            if let fillType = thumbnailNode(at: shp)?.fillType {
                return fillType
            }
        }
        
        guard let data = readThumbnailData(at: sid),
              let thumbnailTexture = try? Texture(imageData: data, isOpaque: true) else {
            guard let thumbnailTexture = model.thumbnailRecord(at: sid, with: thumbnailType)?.decodedValue?.texture else {
                return nil
            }
            return .texture(thumbnailTexture)
        }
        return .texture(thumbnailTexture)
    }
    func readThumbnailData(at sid: UUID) -> Data? {
        model.thumbnailRecord(at: sid, with: thumbnailType)?.decodedData
    }
    func readSheet(at sid: UUID) -> Sheet? {
        if let shp = sheetPosition(at: sid), let sheet = sheetView(at: shp)?.model {
            sheet
        } else {
            model.sheet(at: sid)
        }
    }
    func readSheetHistory(at sid: UUID) -> SheetHistory? {
        if let shp = sheetPosition(at: sid), let history = sheetView(at: shp)?.history {
            history
        } else {
            model.sheetHistory(at: sid)
        }
    }
    
    func updateStringRecord(at sid: UUID, with sheetView: SheetView,
                            isPreparedWrite: Bool = false) {
        guard let sheetRecorder = model.sheetRecorders[sid] else { return }
        sheetRecorder.stringRecord.value = sheetView.model.allTextsString
        if isPreparedWrite {
            sheetRecorder.stringRecord.isPreparedWrite = true
        } else {
            sheetRecorder.stringRecord.isWillwrite = true
        }
    }
    
    struct ThumbnailMipmap {
        var thumbnail4Data: Data
        var thumbnail4: Image?
        var thumbnail16: Image?
        var thumbnail64: Image?
        var thumbnail256: Image?
        var thumbnail1024: Image?
    }
    func hideSelectedRange(_ handler: () -> ()) {
        var isHiddenSelectedRange = false
        if let textView = editingTextView, !textView.isHiddenSelectedRange {
            textView.isHiddenSelectedRange = true
            isHiddenSelectedRange = true
        }
        
        handler()
        
        if isHiddenSelectedRange, let textView = editingTextView {
            textView.isHiddenSelectedRange = false
        }
    }
    func makeThumbnailRecord(at sid: UUID, with sheetView: SheetView,
                             isPreparedWrite: Bool = false) {
        hideSelectedRange {
            if let tm = thumbnailMipmap(from: sheetView),
               let sheetRecorder = model.sheetRecorders[sid] {
                
                saveThumbnailRecord(tm, in: sheetRecorder,
                                    isPreparedWrite: isPreparedWrite)
                baseThumbnailBlocks[sid] = try? Texture.block(from: tm.thumbnail4Data)
            }
        }
        updateStringRecord(at: sid, with: sheetView,
                           isPreparedWrite: isPreparedWrite)
    }
    static let baseMinThumbnailWidth = min(Sheet.width, Sheet.height)
    static let baseThumbnailScale = 512 / baseMinThumbnailWidth
    func thumbnailMipmap(from sheetView: SheetView) -> ThumbnailMipmap? {
        var size = sheetView.bounds.size.snapped(min: .init(square: 512)) * (2.0 ** 1)
        let bColor = sheetView.model.backgroundUUColor.value
        let baseImage = sheetView.node.imageInBounds(size: size, backgroundColor: bColor,
                                                     ColorSpace.export)
        guard let thumbnail1024 = baseImage else { return nil }
        size = size / 4
        let thumbnail256 = thumbnail1024.resize(with: size)
        size = size / 4
        let thumbnail64 = thumbnail256?.resize(with: size)
        size = size / 4
        let thumbnail16 = thumbnail64?.resize(with: size)
        size = size / 4
        let thumbnail4 = thumbnail16?.resize(with: size)
        guard let thumbnail4Data = thumbnail4?.data(.jpeg) else { return nil }
        return ThumbnailMipmap(thumbnail4Data: thumbnail4Data,
                               thumbnail4: thumbnail4,
                               thumbnail16: thumbnail16,
                               thumbnail64: thumbnail64,
                               thumbnail256: thumbnail256,
                               thumbnail1024: thumbnail1024)
    }
    func saveThumbnailRecord(_ tm: ThumbnailMipmap,
                             in srr: Model.SheetRecorder,
                             isPreparedWrite: Bool = false) {
        srr.thumbnail4Record.value = tm.thumbnail4
        srr.thumbnail16Record.value = tm.thumbnail16
        srr.thumbnail64Record.value = tm.thumbnail64
        srr.thumbnail256Record.value = tm.thumbnail256
        srr.thumbnail1024Record.value = tm.thumbnail1024
        if isPreparedWrite {
            srr.thumbnail4Record.isPreparedWrite = true
            srr.thumbnail16Record.isPreparedWrite = true
            srr.thumbnail64Record.isPreparedWrite = true
            srr.thumbnail256Record.isPreparedWrite = true
            srr.thumbnail1024Record.isPreparedWrite = true
        } else {
            srr.thumbnail4Record.isWillwrite = true
            srr.thumbnail16Record.isWillwrite = true
            srr.thumbnail64Record.isWillwrite = true
            srr.thumbnail256Record.isWillwrite = true
            srr.thumbnail1024Record.isWillwrite = true
        }
    }
    func emptyNode(at shp: IntPoint) -> Node {
        let ssFrame = sheetFrame(with: shp)
        return Node(path: Path(ssFrame), fillType: baseFillType(at: shp))
    }
    func baseFillType(at shp: IntPoint) -> Node.FillType {
        guard let sid = sheetID(at: shp), let block = baseThumbnailBlocks[sid] else {
            return .color(.disabled)
        }
        guard let texture = try? Texture(block: block, isOpaque: true) else {
            return .color(.disabled)
        }
        return .texture(texture)
    }
    
    var isUpdateWithCursorPosition = true
    var cursorPoint = Point() {
        didSet {
            updateWithCursorPosition()
//            updateCursorNode()
        }
    }
    func aroundSheetPositions(atCenter centerShp: IntPoint) -> [IntPoint] {
        [.init(centerShp.x + 1, centerShp.y),
         .init(centerShp.x - 1, centerShp.y),
         .init(centerShp.x, centerShp.y + 1),
         .init(centerShp.x, centerShp.y - 1),
         .init(centerShp.x + 1, centerShp.y + 1),
         .init(centerShp.x + 1, centerShp.y - 1),
         .init(centerShp.x - 1, centerShp.y - 1),
         .init(centerShp.x - 1, centerShp.y + 1)]
    }
    func sheetPositionFromVertical(at shp: IntPoint, handler: (IntPoint) -> ()) {
        handler(shp)
        var nShp = shp
        nShp.y += 1
        while sheetID(at: nShp) != nil {
            handler(nShp)
            nShp.y += 1
        }
        nShp = shp
        nShp.y -= 1
        while sheetID(at: nShp) != nil {
            handler(nShp)
            nShp.y -= 1
        }
    }
    func floodSheetPositionFromVertical(at shp: IntPoint, handler: (IntPoint) -> (Bool)) {
        if !handler(shp) { return }
        var dShp = shp, uShp = shp
        uShp.y += 1
        dShp.y -= 1
        while true {
            if sheetID(at: uShp) != nil {
                if !handler(uShp) { return }
            } else { break }
            if sheetID(at: dShp) != nil {
                if !handler(dShp) { return }
            } else { break }
            uShp.y += 1
            dShp.y -= 1
        }
    }
    func maxVerticalSheetPosition(at shp: IntPoint, deltaX: Int) -> IntPoint? {
        var maxShp: IntPoint?
        sheetPositionFromVertical(at: shp) { nShp in
            let dShp = IntPoint(nShp.x + deltaX, nShp.y)
            if let sheetView = sheetView(at: dShp), sheetView.model.enabledTimeline {
                maxShp = maxShp != nil ? (dShp.y > maxShp!.y ? dShp : maxShp!) : dShp
            }
        }
        return maxShp
    }
    func nearestVerticalSheetPosition(at shp: IntPoint, deltaX: Int) -> IntPoint? {
        var maxShp: IntPoint?
        floodSheetPositionFromVertical(at: shp) { nShp in
            let dShp = IntPoint(nShp.x + deltaX, nShp.y)
            if sheetID(at: dShp) != nil {
                maxShp = dShp
                return false
            }
            return true
        }
        return maxShp
    }
    func groupSheetPositions(at cShp: IntPoint) -> [IntPoint] {
        guard sheetID(at: cShp) != nil else { return [] }
        
        var shp = cShp, shps = [IntPoint]()
        sheetPositionFromVertical(at: shp) { shps.append($0) }
        while let preShp = maxVerticalSheetPosition(at: shp, deltaX: -1) {
            sheetPositionFromVertical(at: preShp) { shps.append($0) }
            shp = preShp
        }
        shp = cShp
        while let nextShp = maxVerticalSheetPosition(at: shp, deltaX: 1) {
            sheetPositionFromVertical(at: nextShp) { shps.append($0) }
            shp = nextShp
        }
        
        return shps
    }
    func groupAndAroundSheetPositions(at cp: IntPoint) -> [IntPoint] {
        var shps = [cp] + aroundSheetPositions(atCenter: cp)
        shps = groupSheetPositions(at: cp)
        if let leshp = lastEditedSheetPosition {
            shps.append(leshp)
            shps += groupSheetPositions(at: leshp)
        }
        return shps
    }
    
    func selectedSheetPositions(_ p: Point) -> [IntPoint]? {
        if containsSelectedSheetPositions(p) {
            let shps = world.selectedSheetPositions
            if !shps.isEmpty {
                return shps
            }
        }
        return nil
    }
    var selectedLastPositionLinePoints: [Point]? {
        if let lastP = world.selection.lastPosition {
            let shps = Set(world.selectedSheetPositions)
            let lastSHP = sheetPosition(at: lastP)
            if !shps.contains(lastSHP),
               let nearestSHP = shps.min(by: { $0.distanceSquared(lastSHP) }) {
                
                var ps = Road(shp0: nearestSHP, shp1: lastSHP)
                    .pointsWith(width: Sheet.width, height: Sheet.height)
                if ps.count >= 2 {
                    if ps[ps.count - 2] != ps[ps.count - 1] {
                        if ps[ps.count - 2].x == ps[ps.count - 1].x {
                            ps[ps.count - 2].x = lastP.x
                        }
                        if ps[ps.count - 2].y == ps[ps.count - 1].y {
                            ps[ps.count - 2].y = lastP.y
                        }
                    } else {
                        if nearestSHP.x != lastSHP.x {
                            ps[ps.count - 2].y = lastP.y
                        } else {
                            ps[ps.count - 2].x = lastP.x
                        }
                    }
                    ps[ps.count - 1] = lastP
                    return ps
                }
            }
        }
        return nil
    }
    func containsSelectedLastLine(_ p: Point) -> Bool {
        let maxDSq = (Sheet.knobEditDistance * screenToWorldScale).squared
        if let lastPs = selectedLastPositionLinePoints {
            for edge in Edge.edges(from: lastPs) {
                if edge.distanceSquared(from: p) < maxDSq {
                    return true
                }
            }
        }
        return false
    }
    func containsSelectedSheetPositions(_ p: Point) -> Bool {
        if isEditingSheet {
            return false
        } else {
            let maxDSq = (Sheet.knobEditDistance * screenToWorldScale).squared
            if world.selection.sheetIDs.contains(where: {
                if let f = sheetFrame(at: $0) {
                    f.distanceSquared(p) < maxDSq
                } else {
                    false
                }
            }) {
                return true
            }
            
            let shps = Set(world.selectedSheetPositions)
            
            if let lastPs = selectedLastPositionLinePoints {
                for edge in Edge.edges(from: lastPs) {
                    if edge.distanceSquared(from: p) < maxDSq {
                        return true
                    }
                }
            }
            
            let roads = roads(fromMap: shps)
            return roads.contains {
                let ps = $0.pointsWith(width: Sheet.width, height: Sheet.height)
                return if ps.count > 1 {
                    (1 ..< ps.count).contains(where: {
                        Edge(ps[$0 - 1], ps[$0]).distanceSquared(from: p) < maxDSq
                    })
                } else {
                    false
                }
            }
        }
    }
    
    struct SheetFramePosition {
        var shp: IntPoint, frame: Rect
    }
    func sheetFramePositions(at p: Point) -> (isSelected: Bool, sfps: [SheetFramePosition]) {
        if containsSelectedSheetPositions(p) {
            return (true, world.selectedSheetPositions.map { .init(shp: $0, frame: sheetFrame(with: $0)) })
        } else {
            let shp = sheetPosition(at: p)
            if sheetID(at: shp) != nil {
                return (false, [.init(shp: shp, frame: sheetFrame(with: shp))])
            } else {
                return (false, [])
            }
        }
    }
    
    var cursorSHP = IntPoint()
    var centerSHPs = [IntPoint]()
    func updateWithCursorPosition() {
        if isUpdateWithCursorPosition {
            updateWithCursorPositionAlways()
        }
    }
    private func updateWithCursorPositionAlways() {
        let shp = sheetPosition(at: convertScreenToWorld(cursorPoint))
        cursorSHP = shp
        var shps = [shp] + aroundSheetPositions(atCenter: shp)
        centerSHPs = shps
        var groupSheetPs = groupSheetPositions(at: shp)
        if let leshp = lastEditedSheetPosition {
            shps.append(leshp)
            groupSheetPs += groupSheetPositions(at: leshp)
        }
        
        var nshps = sheetViewValues
        let oshps = nshps
        for shp in shps + groupSheetPs {
            nshps[shp] = nil
        }
        nshps.forEach { readAndClose(.none, at: $0.value.sheetID, $0.key) }
        for nshp in shps {
            if oshps[nshp] == nil, let sid = sheetID(at: nshp) {
                readAndClose(.sheet, priority: nshp == shp ? .high : .medium, at: sid, nshp)
            }
        }
        
        updateTextCursor(isMove: true)
    }
    
    private enum NodeType {
        case none, sheet
    }
    func readAndClose(with aBounds: Rect, _ transform: Transform) {
        readAndClose(with: aBounds, transform, model.sheetRecorders)
    }
    func readAndClose(with aBounds: Rect, _ transform: Transform,
                      _ sheetRecorders: [UUID: Model.SheetRecorder]) {
        let bounds = aBounds * transform
        let d = transform.log2Scale.clipped(min: 0, max: 4, newMin: 1440, newMax: 360)
        let thumbnailsBounds = bounds.inset(by: -d)
        let minXIndex = Int((thumbnailsBounds.minX / Sheet.width).rounded(.down))
        let maxXIndex = Int((thumbnailsBounds.maxX / Sheet.width).rounded(.up))
        let minYIndex = Int((thumbnailsBounds.minY / Sheet.height).rounded(.down))
        let maxYIndex = Int((thumbnailsBounds.maxY / Sheet.height).rounded(.up))
        
        for (sid, _) in sheetRecorders {
            guard let shp = sheetPosition(at: sid) else { continue }
            let type: Model.ThumbnailType?
            if shp.x >= minXIndex && shp.x <= maxXIndex
                && shp.y >= minYIndex && shp.y <= maxYIndex {
                
                type = thumbnailType
            } else {
                type = nil
            }
            let tv = thumbnailNodeValues[shp] ?? .init(type: .none, sheetID: sid, node: nil)
            if tv.type != type {
                set(type, in: tv, at: sid, shp)
            }
        }
    }
    private func set(_ type: Model.ThumbnailType?, in tv: ThumbnailNodeValue,
                     at sid: UUID, _ shp: IntPoint) {
        if sheetViewValues[shp]?.sheetView != nil { return }
        if let type = type {
            if let oldType = tv.type {
                if type != oldType {
                    tv.task?.cancel()
                    openThumbnail(at: shp, sid, tv.node, type)
                }
            } else {
                openThumbnail(at: shp, sid, tv.node, type)
            }
        } else {
            if tv.type != nil {
                tv.task?.cancel()
                tv.node?.removeFromParent()
                thumbnailNodeValues[shp]?.node?.removeFromParent()
                thumbnailNodeValues[shp] = .init(type: type, sheetID: sid, node: nil)
            }
        }
    }
    func openThumbnail(at shp: IntPoint, _ sid: UUID, _ thumbnailNode: Node?,
                       _ type: Model.ThumbnailType) {
        let thumbnailNode = thumbnailNode ?? emptyNode(at: shp)
        guard type != .w4, let thumbnailRecord = self.model.thumbnailRecord(at: sid, with: type) else {
            thumbnailNode.fillType = baseFillType(at: shp)
            thumbnailNodeValues[shp]?.node?.removeFromParent()
            thumbnailNodeValues[shp] = .init(type: type, sheetID: sid, node: thumbnailNode)
            sheetsNode.append(child: thumbnailNode)
            return
        }
        
        let task = Task.detached(priority: .high) {
            try Task.checkCancellation()
            let block = try Texture.block(from: thumbnailRecord, isMipmapped: true)
            try Task.checkCancellation()
            Task { @MainActor in
                thumbnailNode.fillType = .texture(try .init(block: block))
            }
        }
        
        thumbnailNodeValues[shp]?.node?.removeFromParent()
        thumbnailNodeValues[shp] = .init(type: type, sheetID: sid, node: thumbnailNode, task: task)
        sheetsNode.append(child: thumbnailNode)
    }
    
    func close(from shps: [IntPoint]) {
        shps.forEach {
            if let sid = sheetID(at: $0) {
                readAndClose(.none, priority: .medium, at: sid, $0)
            }
        }
    }
    func close(from sids: [UUID]) {
        sids.forEach {
            if let shp = sheetPosition(at: $0) {
                readAndClose(.none, priority: .medium, at: $0, shp)
            }
        }
    }
    private func updateThumbnail(_ sheetViewValue: SheetViewValue,
                                 at shp: IntPoint, _ sid: UUID) {
        if let sheetView = sheetViewValue.sheetView {
            if let texture = sheetView.node.cacheTexture {
                if let tv = thumbnailNodeValues[shp], let tNode = tv.node {
                    tNode.fillType = .texture(texture)
                    if tNode.parent == nil {
                        sheetsNode.append(child: tNode)
                    }
                } else if sheetViewValues[shp] != nil {
                    let ssFrame = sheetFrame(with: shp)
                    let tNode = Node(path: Path(ssFrame), fillType: .color(.disabled))
                    tNode.fillType = .texture(texture)
                    thumbnailNodeValues[shp]?.node?.removeFromParent()
                    thumbnailNodeValues[shp] = .init(type: thumbnailType, sheetID: sid, node: tNode)
                    sheetsNode.append(child: tNode)
                }
            } else if let tv = thumbnailNodeValues[shp] {
                openThumbnail(at: shp, sid, tv.node, thumbnailType)
            }
        }
    }
    struct ReadingError: Error {}
    private func readAndClose(_ type: NodeType, priority: TaskPriority = .high,
                              at sid: UUID, _ shp: IntPoint) {
        switch type {
        case .none:
            if let sheetViewValue = sheetViewValues[shp] {
                sheetViewValue.task?.cancel()
                
                if let sheetView = sheetViewValue.sheetView,
                   let sheetRecorder = model.sheetRecorders[sheetViewValue.sheetID],
                   sheetRecorder.sheetRecord.isWillwrite {
                    
                    if let sheetView = sheetViewValue.sheetView {
                        sheetView.node.updateCache()
                    }
                    if savingItem != nil {
                        savingFuncs.append { [sid = sheetViewValue.sheetID,
                                              model = sheetView.model, um = sheetView.history,
                                              tm = thumbnailMipmap(from: sheetView), weak self] in
                            
                            sheetRecorder.sheetRecord.value = model
                            sheetRecorder.sheetRecord.isWillwrite = true
                            sheetRecorder.sheetHistoryRecord.value = um
                            sheetRecorder.sheetHistoryRecord.isWillwrite = true
                            self?.updateStringRecord(at: sid, with: sheetView)
                            if let tm = tm {
                                self?.saveThumbnailRecord(tm, in: sheetRecorder)
                                self?.baseThumbnailBlocks[sid]
                                = try? Texture.block(from: tm.thumbnail4Data)
                            }
                        }
                    } else {
                        sheetRecorder.sheetRecord.value = sheetView.model
                        sheetRecorder.sheetHistoryRecord.value = sheetView.history
                        sheetRecorder.sheetHistoryRecord.isWillwrite = true
                        makeThumbnailRecord(at: sheetViewValue.sheetID, with: sheetView)
                        sheetRecorder.sheetRecord.willwriteClosure = { (_) in }
                    }
                }
                
                updateThumbnail(sheetViewValue, at: shp, sid)
                sheetViewValues[shp]?.sheetView?.node.removeFromParent()
                sheetViewValues[shp]?.loadingNode?.removeFromParent()
                sheetViewValues[shp]?.sheetView?.cancelTasks()
                sheetViewValues[shp] = nil
                sheetViewValue.sheetView?.node.removeFromParent()
                sheetViewValue.loadingNode?.removeFromParent()
                
                updateSelectedFrame()
                updateFindingNodes(at: shp)
                
                self.sheetViewValues[shp]?.loadingNode?.removeFromParent()
            }
        case .sheet:
            if sheetViewValues.contains(where: { $0.value.sheetID == sid }) { return }
            guard let sheetRecorder = self.model.sheetRecorders[sid] else { return }
            let frame = self.sheetFrame(with: shp)
            
            Task.detached(priority: .high) {
                try await Task.sleep(sec: 1.5)
                Task { @MainActor in
                    if self.sheetViewValues[shp]?.isLoading ?? false {
                        let node = Node(path: .init(frame), fillType: .color(.loading))
                        self.sheetViewValues[shp]?.loadingNode?.removeFromParent()
                        self.sheetViewValues[shp]?.loadingNode = node
                        self.node.append(child: node)
                    }
                }
            }
            let task = Task.detached(priority: priority) {
                try await withTaskCancellationHandler {
                    try Task.checkCancellation()
                    let sheetRecord = sheetRecorder.sheetRecord
                    let sheet = sheetRecord.decodedValue ?? .init(message: "Failed to load".localized)
                    try Task.checkCancellation()
                    let historyRecord = sheetRecorder.sheetHistoryRecord
                    let history = historyRecord.decodedValue
                    try Task.checkCancellation()
                    
                    let sheetBinder = RecordBinder(value: sheet, record: sheetRecord)
                    let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value,
                                              history: history ?? .init())
                    try Task.checkCancellation()
                    sheetView.id = sid
                    sheetView.bounds = Rect(size: frame.size)
                    sheetView.node.attitude.position = frame.origin
                    try Task.checkCancellation()
                    try sheetView.node.allChildrenAndSelf {
                        $0.updateDatas()
                        try Task.checkCancellation()
                    }
                    try Task.checkCancellation()
                    do {
                        guard let thumbnail = sheetRecorder.thumbnail1024Record.decodedValue else { throw ReadingError() }
                        try Task.checkCancellation()
                        let block = try Texture.block(from: thumbnail, isMipmapped: true)
                        try Task.checkCancellation()
                        Task { @MainActor in
                            sheetView.node.cacheTexture = try .init(block: block)
                        }
                    } catch {
    //                    sheetView.enableCache = true
                    }
                    try Task.checkCancellation()
                    
                    sheetView.contentsView.elementViews.forEach { $0.updateSpectrogram() }
                    sheetView.scoreView.updateSpectrogram()
                    
                    try Task.checkCancellation()
                    
                    Task { @MainActor in
                        self.sheetViewValues[shp]?.isLoading = false
                        self.sheetViewValues[shp]?.loadingNode?.removeFromParent()
                        self.sheetViewValues[shp]?.loadingNode = nil
                        
                        guard self.sheetID(at: shp) == sid,
                              self.sheetViewValues[shp] != nil else { return }
                        self.updateWithEditGrid(in: sheetView)
                        sheetRecord.willwriteClosure = { [weak sheetView, weak self,
                                                          weak historyRecord] (record) in
                            if let sheetView {
                                record.value = sheetView.model
                                historyRecord?.value = sheetView.history
                                historyRecord?.isPreparedWrite = true
                                self?.makeThumbnailRecord(at: sid, with: sheetView,
                                                          isPreparedWrite: true)// -> write
                            }
                        }
                        
                        self.sheetView(at: shp)?.node.removeFromParent()
                        self.sheetViewValues[shp] = .init(sheetID: sid, sheetView: sheetView, task: nil)
                        if sheetView.node.parent == nil {
                            self.sheetsNode.append(child: sheetView.node)
                            sheetView.node.enableCache = true
                        }
                        
                        self.updateAround(in: sheetView, at: shp)
                        self.updateOtherAround(from: sheetView)
                        
                        self.thumbnailNodeValues[shp]?.node?.removeFromParent()
                        
                        self.updateSelectedFrame()
                        self.updateFindingNodes(at: shp)
                        if shp == self.sheetPosition(at: self.convertScreenToWorld(self.cursorPoint)) {
                            self.updateTextCursor()
                        }
                        
                        if sheetView.screenToWorldScale != self.screenToWorldScale {
                            sheetView.screenToWorldScale = self.screenToWorldScale
                            self.updateSelectedFrame()
                        }
                        
                        sheetView.stopNotifications.append { [weak self] _ in
                            self?.showSelected()
                        }
                        sheetView.changeSelectedFrameNotifications.append { [weak self] _, _ in
                            self?.updateSelectedFrame()
                        }
                    }
                } onCancel: {
                    Task { @MainActor in
                        self.sheetViewValues[shp]?.loadingNode?.removeFromParent()
                        self.sheetViewValues[shp]?.loadingNode = nil
                        self.sheetViewValues[shp] = nil
                    }
                }
            }
            sheetViewValues[shp]?.sheetView?.node.removeFromParent()
            sheetViewValues[shp]?.loadingNode?.removeFromParent()
            sheetViewValues[shp]?.sheetView?.cancelTasks()
            sheetViewValues[shp] = .init(sheetID: sid, sheetView: nil, isLoading: true, task: task)
        }
    }
    
    func renderableSheetNode(at sid: UUID) -> CPUNode? {
        guard let shp = sheetPosition(at: sid) else { return nil }
        guard let sheet = model.sheet(at: sid) else { return nil }
        let frame = sheetFrame(with: shp)
        return sheet.node(isBorder: false, attitude: .init(position: frame.origin), in: frame.bounds)
    }
    
    func readSheetView(at sid: UUID) -> SheetView? {
        guard let shp = sheetPosition(at: sid) else { return nil }
        return sheetView(at: shp) ?? readSheetView(at: sid, shp)
    }
    func readSheetView(at shp: IntPoint) -> SheetView? {
        if let sheetView = sheetView(at: shp) {
            sheetView
        } else if let sid = sheetID(at: shp) {
            readSheetView(at: sid, shp)
        } else {
            nil
        }
    }
    func readSheetView(at p: Point) -> SheetView? {
        readSheetView(at: sheetPosition(at: p))
    }
    func readSheetView(at sid: UUID, _ shp: IntPoint,
                       isUpdateNode: Bool = false) -> SheetView? {
        guard let sheetRecorder = model.sheetRecorders[sid] else { return nil }
        let sheetRecord = sheetRecorder.sheetRecord
        let sheetHistoryRecord = sheetRecorder.sheetHistoryRecord
        
        guard let sheet = sheetRecord.decodedValue else { return nil }
        let sheetBinder = RecordBinder(value: sheet, record: sheetRecord)
        let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value,
                                  history: sheetHistoryRecord.decodedValue ?? .init())
        sheetView.screenToWorldScale = screenToWorldScale
        sheetView.id = sid
        let frame = sheetFrame(with: shp)
        sheetView.bounds = Rect(size: frame.size)
        sheetView.node.attitude.position = frame.origin
        sheetView.node.allChildrenAndSelf { $0.updateDatas() }
        sheetView.node.enableCache = true
        updateWithEditGrid(in: sheetView)
        
        sheetView.stopNotifications.append { [weak self] _ in
            self?.showSelected()
        }
        sheetView.changeSelectedFrameNotifications.append { [weak self] _, _ in
            self?.updateSelectedFrame()
        }
        
        sheetRecord.willwriteClosure = { [weak sheetView, weak sheetHistoryRecord, weak self] (record) in
            if let sheetView = sheetView {
                record.value = sheetView.model
                sheetHistoryRecord?.value = sheetView.history
                sheetHistoryRecord?.isPreparedWrite = true
                self?.makeThumbnailRecord(at: sid, with: sheetView,
                                          isPreparedWrite: true)// -> write
            }
        }
        
        if isUpdateNode {
            self.sheetView(at: shp)?.node.removeFromParent()
            sheetViewValues[shp] = SheetViewValue(sheetID: sid, sheetView: sheetView, task: nil)
            if sheetView.node.parent == nil {
                sheetsNode.append(child: sheetView.node)
            }
            thumbnailNodeValues[shp]?.node?.removeFromParent()
            updateWithEditGrid(in: sheetView)
        }
        
        return sheetView
    }
    
    func sheetPosition(at sid: UUID) -> IntPoint? {
        world.sheetPositions[sid]
    }
    func sheetFrame(at sid: UUID) -> Rect? {
        if let shp = world.sheetPositions[sid] {
            sheetFrame(with: shp)
        } else {
            nil
        }
    }
    func sheetID(at shp: IntPoint) -> UUID? {
        world.sheetIDs[shp]
    }
    func sheetPosition(at p: Point) -> IntPoint {
        let p = Self.maxSheetAABB.clippedPoint(with: p)
        let x = Int((p.x / Sheet.width).rounded(.down))
        let y = Int((p.y / Sheet.height).rounded(.down))
        return .init(x, y)
    }
    func sheetFrame(with shp: IntPoint) -> Rect {
        Rect(x: Double(shp.x) * Sheet.width,
             y: Double(shp.y) * Sheet.height,
             width: Sheet.width,
             height: Sheet.height)
    }
    func sheetView(at p: Point) -> SheetView? {
        sheetViewValues[sheetPosition(at: p)]?.sheetView
    }
    func sheetViewValue(at shp: IntPoint) -> SheetViewValue? {
        sheetViewValues[shp]
    }
    func sheetView(at shp: IntPoint) -> SheetView? {
        sheetViewValues[shp]?.sheetView
    }
    func thumbnailNode(at shp: IntPoint) -> Node? {
        thumbnailNodeValues[shp]?.node
    }
    
    func madeReadSheetView(at p: Point,
                           isNewUndoGroup: Bool = true) -> SheetView? {
        let shp = sheetPosition(at: p)
        return if let ssv = madeSheetView(at: shp,
                                          isNewUndoGroup: isNewUndoGroup) {
            ssv
        } else if let sid = sheetID(at: shp) {
            readSheetView(at: sid, shp, isUpdateNode: true)
        } else {
            nil
        }
    }
    
    @discardableResult
    func madeSheetView(at p: Point,
                       isNewUndoGroup: Bool = true) -> SheetView? {
        madeSheetView(at: sheetPosition(at: p), isNewUndoGroup: isNewUndoGroup)
    }
    @discardableResult
    func madeSheetView(at shp: IntPoint,
                       isNewUndoGroup: Bool = true) -> SheetView? {
        if let sheetView = sheetView(at: shp) { return sheetView }
        if sheetID(at: shp) != nil { return nil }
        let newSID = UUID()
        guard !model.contains(at: newSID) else { return nil }
        return append(Sheet(), history: nil, at: newSID, at: shp,
                      isNewUndoGroup: isNewUndoGroup)
    }
    @discardableResult
    func madeSheetViewIsNew(at shp: IntPoint,
                            isNewUndoGroup: Bool = true) -> (SheetView,
                                                             isNew: Bool)? {
        if let sheetView = sheetView(at: shp) { return (sheetView, false) }
        if sheetID(at: shp) != nil { return nil }
        let newSID = UUID()
        guard !model.contains(at: newSID) else { return nil }
        return (append(Sheet(), history: nil, at: newSID, at: shp,
                       isNewUndoGroup: isNewUndoGroup), true)
    }
    @discardableResult
    func madeSheetView(with sheet: Sheet,
                       history: SheetHistory?,
                       at shp: IntPoint,
                       isNewUndoGroup: Bool = true) -> SheetView? {
        if let sheetView = sheetView(at: shp) {
            sheetView.node.removeFromParent()
        }
        let newSID = UUID()
        guard !model.contains(at: newSID) else { return nil }
        return append(sheet, history: history,
                      at: newSID, at: shp,
                      isNewUndoGroup: isNewUndoGroup)
    }
    @discardableResult
    func append(_ sheet: Sheet, history: SheetHistory?,
                at sid: UUID, at shp: IntPoint,
                isNewUndoGroup: Bool = true) -> SheetView {
        if isNewUndoGroup {
            newUndoGroup()
        }
        append([shp: sid], enableNode: false)
        
        let sheetRecorder = model.makeSheetRecorder(at: sid)
        let sheetRecord = sheetRecorder.sheetRecord
        let sheetHistoryRecord = sheetRecorder.sheetHistoryRecord
        
        let sheetBinder = RecordBinder(value: sheet, record: sheetRecord)
        let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value,
                                  history: history ?? .init())
        sheetView.screenToWorldScale = screenToWorldScale
        sheetView.id = sid
        let frame = sheetFrame(with: shp)
        sheetView.bounds = Rect(size: frame.size)
        sheetView.node.attitude.position = frame.origin
        sheetView.node.allChildrenAndSelf { $0.updateDatas() }
        sheetView.node.enableCache = true
        updateWithEditGrid(in: sheetView)
        
        sheetView.contentsView.elementViews.forEach { $0.updateSpectrogram() }
        sheetView.scoreView.updateSpectrogram()
        
        updateAround(in: sheetView, at: shp)
        updateOtherAround(from: sheetView)
        
        sheetRecord.willwriteClosure = { [weak sheetView, weak sheetHistoryRecord, weak self] (record) in
            if let sheetView = sheetView {
                record.value = sheetView.model
                sheetHistoryRecord?.value = sheetView.history
                sheetHistoryRecord?.isPreparedWrite = true
                self?.makeThumbnailRecord(at: sid, with: sheetView,
                                          isPreparedWrite: true)// -> write
            }
        }
        
        sheetView.stopNotifications.append { [weak self] _ in
            self?.showSelected()
        }
        sheetView.changeSelectedFrameNotifications.append { [weak self] _, _ in
            self?.updateSelectedFrame()
        }
        
        self.sheetView(at: shp)?.node.removeFromParent()
        sheetViewValues[shp]?.sheetView?.node.removeFromParent()
        sheetViewValues[shp]?.loadingNode?.removeFromParent()
        sheetViewValues[shp] = .init(sheetID: sid, sheetView: sheetView, task: nil)
        sheetsNode.append(child: sheetView.node)
        updateMap()
        updateWithEditGrid(in: sheetView)
        
        return sheetView
    }
    @discardableResult
    func duplicateSheet(from sid: UUID) -> UUID {
        let nsid = UUID()
        let nsrr = model.makeSheetRecorder(at: nsid)
        if let shp = sheetPosition(at: sid),
           let sheetView = sheetView(at: shp) {
            nsrr.sheetRecord.value = sheetView.model
            nsrr.sheetHistoryRecord.value = sheetView.history
            hideSelectedRange {
                if let t = thumbnailMipmap(from: sheetView) {
                    saveThumbnailRecord(t, in: nsrr)
                }
            }
        } else if let osrr = model.sheetRecorders[sid] {
            nsrr.sheetRecord.data = osrr.sheetRecord.valueDataOrDecodedData
            nsrr.thumbnail4Record.data = osrr.thumbnail4Record.valueDataOrDecodedData
            nsrr.thumbnail16Record.data = osrr.thumbnail16Record.valueDataOrDecodedData
            nsrr.thumbnail64Record.data = osrr.thumbnail64Record.valueDataOrDecodedData
            nsrr.thumbnail256Record.data = osrr.thumbnail256Record.valueDataOrDecodedData
            nsrr.thumbnail1024Record.data = osrr.thumbnail1024Record.valueDataOrDecodedData
            nsrr.sheetHistoryRecord.data = osrr.sheetHistoryRecord.valueDataOrDecodedData
            nsrr.stringRecord.data = osrr.stringRecord.valueDataOrDecodedData
        }
        
        if let osrr = model.sheetRecorders[sid], !osrr.contentsDirectory.childrenURLs.isEmpty {
            nsrr.contentsDirectory.isWillwrite = true
            try? nsrr.contentsDirectory.write()
            for (key, url) in osrr.contentsDirectory.childrenURLs {
                try? nsrr.contentsDirectory.copy(name: key, from: url)
            }
            if var sheet = nsrr.sheetRecord.decodedValue {
                if !sheet.contents.isEmpty {
                    let dn = nsid.uuidString
                    for i in sheet.contents.count.range {
                        sheet.contents[i].directoryName = dn
                    }
                    nsrr.sheetRecord.data = try? sheet.serializedData()
                }
            }
        }
        nsrr.sheetRecord.isWillwrite = true
        nsrr.thumbnail4Record.isWillwrite = true
        nsrr.thumbnail16Record.isWillwrite = true
        nsrr.thumbnail64Record.isWillwrite = true
        nsrr.thumbnail256Record.isWillwrite = true
        nsrr.thumbnail1024Record.isWillwrite = true
        nsrr.sheetHistoryRecord.isWillwrite = true
        nsrr.stringRecord.isWillwrite = true
        
        if let data = nsrr.thumbnail4Record.decodedData {
            baseThumbnailBlocks[nsid] = try? Texture.block(from: data)
        }
        
        return nsid
    }
    func appendSheet(from osrr: Model.SheetRecorder) -> UUID {
        let nsid = UUID()
        let nsrr = model.makeSheetRecorder(at: nsid)
        nsrr.sheetRecord.data = osrr.sheetRecord.valueDataOrDecodedData
        nsrr.thumbnail4Record.data = osrr.thumbnail4Record.valueDataOrDecodedData
        nsrr.thumbnail16Record.data = osrr.thumbnail16Record.valueDataOrDecodedData
        nsrr.thumbnail64Record.data = osrr.thumbnail64Record.valueDataOrDecodedData
        nsrr.thumbnail256Record.data = osrr.thumbnail256Record.valueDataOrDecodedData
        nsrr.thumbnail1024Record.data = osrr.thumbnail1024Record.valueDataOrDecodedData
        nsrr.sheetHistoryRecord.data = osrr.sheetHistoryRecord.valueDataOrDecodedData
        nsrr.stringRecord.data = osrr.stringRecord.valueDataOrDecodedData
        
        if !osrr.contentsDirectory.childrenURLs.isEmpty {
            nsrr.contentsDirectory.isWillwrite = true
            try? nsrr.contentsDirectory.write()
            for (key, url) in osrr.contentsDirectory.childrenURLs {
                try? nsrr.contentsDirectory.copy(name: key, from: url)
            }
            if var sheet = nsrr.sheetRecord.decodedValue {
                if !sheet.contents.isEmpty {
                    let dn = nsid.uuidString
                    for i in sheet.contents.count.range {
                        sheet.contents[i].directoryName = dn
                    }
                    nsrr.sheetRecord.data = try? sheet.serializedData()
                }
            }
        }
        nsrr.sheetRecord.isWillwrite = true
        nsrr.thumbnail4Record.isWillwrite = true
        nsrr.thumbnail16Record.isWillwrite = true
        nsrr.thumbnail64Record.isWillwrite = true
        nsrr.thumbnail256Record.isWillwrite = true
        nsrr.thumbnail1024Record.isWillwrite = true
        nsrr.sheetHistoryRecord.isWillwrite = true
        nsrr.stringRecord.isWillwrite = true
        
        if let data = nsrr.thumbnail4Record.decodedData {
            baseThumbnailBlocks[nsid] = try? Texture.block(from: data)
        }
        
        return nsid
    }
    func removeSheet(at sid: UUID, for shp: IntPoint) {
        try? model.removeSheetRecoder(at: sid)
        
        if let sheetViewValue = sheetViewValues[shp] {
            sheetViewValue.sheetView?.node.removeFromParent()
            sheetViewValue.loadingNode?.removeFromParent()
            sheetViewValue.sheetView?.cancelTasks()
            sheetViewValues[shp] = nil
        }
        updateMap()
    }
    
    func updateAround(in sheetView: SheetView, at shp: IntPoint, isUpdateAlways: Bool = false) {
        var isUpdate = false
        if let nSheetView = sheetViewValue(at: .init(shp.x - 1, shp.y))?.sheetView,
           sheetView.left != nSheetView {
            sheetView.left = nSheetView
            isUpdate = true
            
            if sheetView.right == nil {
                var nShp = shp, lastSheetView: SheetView?
                nShp.x -= 1
                while let nSheetView = sheetViewValue(at: nShp)?.sheetView {
                    lastSheetView = nSheetView
                    nShp.x -= 1
                }
                if let lastSheetView, sheetView.right != lastSheetView {
                    sheetView.right = lastSheetView
                    isUpdate = true
                }
            }
        }
        if let nSheetView = sheetViewValue(at: .init(shp.x + 1, shp.y))?.sheetView,
           sheetView.right != nSheetView {
            sheetView.right = nSheetView
            isUpdate = true
            
            if sheetView.left == nil {
                var nShp = shp, lastSheetView: SheetView?
                nShp.x += 1
                while let nSheetView = sheetViewValue(at: nShp)?.sheetView {
                    lastSheetView = nSheetView
                    nShp.x += 1
                }
                if let lastSheetView, sheetView.left != lastSheetView {
                    sheetView.left = lastSheetView
                    isUpdate = true
                }
            }
        }
        if let nSheetView = sheetViewValue(at: .init(shp.x, shp.y - 1))?.sheetView,
           sheetView.bottom != nSheetView {
            sheetView.bottom = nSheetView
            isUpdate = true
        }
        if let nSheetView = sheetViewValue(at: .init(shp.x, shp.y + 1))?.sheetView,
           sheetView.top != nSheetView {
            sheetView.top = nSheetView
            isUpdate = true
        }
        
        if isUpdate || isUpdateAlways {
            sheetView.updateScoreViewFromAround()
        }
    }
    func updateOtherAround(from sheetView: SheetView, isUpdateAlways: Bool = false) {
        if let nSheetView = sheetView.left,
           let shp = sheetPosition(from: nSheetView) {
            updateAround(in: nSheetView, at: shp, isUpdateAlways: isUpdateAlways)
        }
        if let nSheetView = sheetView.right,
           let shp = sheetPosition(from: nSheetView) {
            updateAround(in: nSheetView, at: shp, isUpdateAlways: isUpdateAlways)
        }
        if let nSheetView = sheetView.top,
           let shp = sheetPosition(from: nSheetView) {
            updateAround(in: nSheetView, at: shp, isUpdateAlways: isUpdateAlways)
        }
        if let nSheetView = sheetView.bottom,
           let shp = sheetPosition(from: nSheetView) {
            updateAround(in: nSheetView, at: shp, isUpdateAlways: isUpdateAlways)
        }
    }
    
    func updateLastEditedSheetPosition(fromScreen sp: Point) {
        lastEditedSheetPosition = sheetPosition(at: convertScreenToWorld(sp))
    }
    private(set) var lastEditedSheetPosition: IntPoint?
    
    func sheetViewAndFrame(at p: Point) -> (shp: IntPoint,
                                            sheetView: SheetView?,
                                            frame: Rect,
                                            isAll: Bool) {
        let shp = sheetPosition(at: p)
        let frame = sheetFrame(with: shp)
        if let sheetView = sheetView(at: p) {
            if !isEditingSheet {
                return (shp, sheetView, frame, true)
            } else {
                let (bounds, isAll) = sheetView.model
                    .boundsTuple(at: sheetView.convertFromWorld(p),
                                 in: frame.bounds)
                return (shp, sheetView, bounds + frame.origin, isAll)
            }
        } else {
            return (shp, nil, frame, false)
        }
    }
    func frame(at p: Point, with sheetView: SheetView) -> (frame: Rect, isAll: Bool) {
        let frame = sheetFrame(at: sheetView.id) ?? sheetFrame(with: sheetPosition(at: p))
        if !isEditingSheet {
            return (frame, true)
        } else {
            let (bounds, isAll) = sheetView.model
                .boundsTuple(at: sheetView.convertFromWorld(p),
                             in: frame.bounds)
            return (bounds + frame.origin, isAll)
        }
    }
    
    func nearestAroundTempo(at p: Point) -> Rational {
        let shp = sheetPosition(at: p)
        var shps = aroundSheetPositions(atCenter: shp)
        sheetPositionFromVertical(at: shp) { nshp in
            shps.append(nshp)
        }
        var nnTempo: Rational?
        for shp in shps {
            if let sheetView = sheetViewValues[shp]?.sheetView,
               let tempo = sheetView.nearestTempo(at: sheetView.convertFromWorld(p)) {
                
                nnTempo = tempo
                break
            }
        }
        return nnTempo ?? Music.defaultTempo
    }
    
    func worldBorder(at p: Point) -> (border: Border, edge: Edge)? {
        let d = 10 * screenToWorldScale
        let shp = sheetPosition(at: p)
        let b = sheetFrame(with: shp)
        let topEdge = b.topEdge
        if topEdge.distance(from: p) < d {
            return (Border(.horizontal), topEdge)
        }
        let bottomEdge = b.bottomEdge
        if bottomEdge.distance(from: p) < d {
            return (Border(.horizontal), bottomEdge)
        }
        let leftEdge = b.leftEdge
        if leftEdge.distance(from: p) < d {
            return (Border(.vertical), leftEdge)
        }
        let rightEdge = b.rightEdge
        if rightEdge.distance(from: p) < d {
            return (Border(.vertical), rightEdge)
        }
        return nil
    }
    func mainFrame(at p: Point) -> (mainFrame: Rect, sheetView: SheetView?)? {
        guard isEditingSheet else { return nil }
        let d = 10 * screenToWorldScale
        let shp = sheetPosition(at: p)
        let dSq = d * d
        guard let sheetView = sheetView(at: shp) else {
            let mainFrame = sheetFrame(with: shp)
            let nb = mainFrame.outset(by: Sheet.mainFrameLineWidth / 2)
            return nb.topEdge.distanceSquared(from: p) < dSq
            || nb.rightEdge.distanceSquared(from: p) < dSq
            || nb.leftEdge.distanceSquared(from: p) < dSq
            || nb.bottomEdge.distanceSquared(from: p) < dSq ?
            (mainFrame, nil) : nil
        }
        let sheetP = sheetView.convertFromWorld(p)
        let nb = sheetView.mainFrame != Sheet.defaultBounds ?
        sheetView.mainFrame.intersection(sheetView.bounds)?.outset(by: Sheet.mainFrameLineWidth / 2) ?? sheetView.bounds : sheetView.bounds
        return nb.topEdge.distanceSquared(from: sheetP) < dSq
        || nb.rightEdge.distanceSquared(from: sheetP) < dSq
        || nb.leftEdge.distanceSquared(from: sheetP) < dSq
        || nb.bottomEdge.distanceSquared(from: sheetP) < dSq ?
        (sheetView.mainFrame, sheetView) : nil
    }
    func border(at p: Point) -> (border: Border, index: Int,
                                 sheetView: SheetView, edge: Edge)? {
        let d = 10 * screenToWorldScale
        let shp = sheetPosition(at: p)
        guard let sheetView = sheetView(at: shp) else { return nil }
        let b = sheetFrame(with: shp)
        let sheetP = sheetView.convertFromWorld(p)
        for (i, border) in sheetView.model.borders.enumerated() {
            switch border.orientation {
            case .horizontal:
                if abs(sheetP.y - border.location) < d {
                    return (border, i, sheetView,
                            Edge(Point(0, border.location) + b.origin,
                                 Point(b.width, border.location) + b.origin))
                }
            case .vertical:
                if abs(sheetP.x - border.location) < d {
                    return (border, i, sheetView,
                            Edge(Point(border.location, 0) + b.origin,
                                 Point(border.location, b.height) + b.origin))
                }
            }
        }
        return nil
    }
    
    func sheetViewsWithSelected(at p: Point) -> [SheetView] {
        guard isEditingSheet else { return [] }
        let sheetViews = sheetViewsFromSelectedFrame(at: p)
        if !sheetViews.isEmpty {
            return sheetViews
        }
        return sheetViewValues.compactMap {
            guard let sheetView = $0.value.sheetView else { return nil }
            if sheetView.containsSelected(sheetView.convertFromWorld(p),
                                          scale: screenToWorldScale) {
                return sheetView
            } else {
                return nil
            }
        }
    }
    func containsSelectedFrame(_ p: Point) -> Bool {
        sheetViewValues.contains {
            if let sheetView = $0.value.sheetView {
                sheetView.containsSelectedFrame(sheetView.convertFromWorld(p),
                                                scale: screenToWorldScale)
            } else {
                false
            }
        }
    }
    func sheetPositionFromSelectedFrame(at p: Point) -> IntPoint? {
        var minSHP: IntPoint?, minDSq = Double.infinity
        sheetViewValues.forEach {
            if let sheetVeiw = $0.value.sheetView,
               let dSq = sheetVeiw.selectedFrameDistanceSquared(sheetVeiw.convertFromWorld(p),
                                                                scale: screenToWorldScale) {
                if dSq < minDSq {
                    minSHP = $0.key
                    minDSq = dSq
                }
            }
        }
        return minSHP
    }
    func sheetViewsFromSelectedFrame(at p: Point) -> [SheetView] {
        sheetViewValues.compactMap {
            if let sheetVeiw = $0.value.sheetView,
               sheetVeiw.selectedFrameDistanceSquared(sheetVeiw.convertFromWorld(p),
                                                      scale: screenToWorldScale) != nil {
                sheetVeiw
            } else {
                nil
            }
        }
    }
    func sheetViewWithSelectedSheetValue(at p: Point) -> SheetView? {
        guard isEditingSheet else { return nil }
        if let shp = sheetPositionFromSelectedFrame(at: p) {
            return sheetView(at: shp)
        }
        for v in sheetViewValues {
            guard let sheetView = v.value.sheetView else { continue }
            if sheetView.containsSelectedSheetValue(sheetView.convertFromWorld(p),
                                                    scale: screenToWorldScale) {
                return sheetView
            }
        }
        return nil
    }
    func sheetViewWithSelectedLineOrPlane(at p: Point) -> SheetView? {
        guard isEditingSheet else { return nil }
        if let shp = sheetPositionFromSelectedFrame(at: p) {
            return sheetView(at: shp)
        }
        for v in sheetViewValues {
            guard let sheetView = v.value.sheetView else { continue }
            if sheetView.containsSelectedLineOrPlane(sheetView.convertFromWorld(p),
                                                     scale: screenToWorldScale) {
                return sheetView
            }
        }
        return nil
    }
    func sheetViewWithSelectedLine(at p: Point) -> SheetView? {
        guard isEditingSheet else { return nil }
        if let shp = sheetPositionFromSelectedFrame(at: p) {
            return sheetView(at: shp)
        }
        for v in sheetViewValues {
            guard let sheetView = v.value.sheetView else { continue }
            if sheetView.containsSelectedLine(sheetView.convertFromWorld(p),
                                              scale: screenToWorldScale) {
                return sheetView
            }
        }
        return nil
    }
    func sheetViewWithSelectedPlane(at p: Point) -> SheetView? {
        guard isEditingSheet else { return nil }
        if let shp = sheetPositionFromSelectedFrame(at: p) {
            return sheetView(at: shp)
        }
        for v in sheetViewValues {
            guard let sheetView = v.value.sheetView else { continue }
            if sheetView.containsSelectedPlane(sheetView.convertFromWorld(p)) {
                return sheetView
            }
        }
        return nil
    }
    func sheetViewWithSelectedText(at p: Point) -> SheetView? {
        guard isEditingSheet else { return nil }
        if let shp = sheetPositionFromSelectedFrame(at: p) {
            return sheetView(at: shp)
        }
        for v in sheetViewValues {
            guard let sheetView = v.value.sheetView else { continue }
            if sheetView.containsSelectedText(sheetView.convertFromWorld(p),
                                              scale: screenToWorldScale) {
                return sheetView
            }
        }
        return nil
    }
    func sheetViewWithSelectedContent(at p: Point) -> SheetView? {
        guard isEditingSheet else { return nil }
        if let shp = sheetPositionFromSelectedFrame(at: p) {
            return sheetView(at: shp)
        }
        for v in sheetViewValues {
            guard let sheetView = v.value.sheetView else { continue }
            if sheetView.containsSelectedContent(sheetView.convertFromWorld(p),
                                                 scale: screenToWorldScale) {
                return sheetView
            }
        }
        return nil
    }
    func sheetViewWithSelectedKeyframe(at p: Point) -> SheetView? {
        guard isEditingSheet else { return nil }
        for v in sheetViewValues {
            guard let sheetView = v.value.sheetView else { continue }
            if sheetView.containsSelectedKeyframe(sheetView.convertFromWorld(p),
                                                  scale: screenToWorldScale) {
                return sheetView
            }
        }
        return nil
    }
    func sheetViewWithSelectedNote(at p: Point) -> SheetView? {
        guard isEditingSheet else { return nil }
        if let shp = sheetPositionFromSelectedFrame(at: p) {
            return sheetView(at: shp)
        }
        for v in sheetViewValues {
            guard let sheetView = v.value.sheetView else { continue }
            if sheetView.containsSelectedNote(sheetView.convertFromWorld(p),
                                              scale: screenToWorldScale) {
                return sheetView
            }
        }
        return nil
    }
    
    func colorPathValue(at p: Point, toColor: Color?,
                        color: Color, subColor: Color) -> ColorPathValue {
        if let sheetView = sheetView(at: p) {
            let sheetP = sheetView.convertFromWorld(p)
            return sheetView.sheetColorOwner(at: sheetP,
                                             scale: screenToWorldScale).value
                .colorPathValue(toColor: toColor, color: color, subColor: subColor)
        } else {
            let shp = sheetPosition(at: p)
            return ColorPathValue(paths: [Path(sheetFrame(with: shp))],
                                  lineType: .color(color),
                                  fillType: .color(subColor))
        }
    }
    func uuColor(at p: Point) -> UUColor {
        if let sheetView = sheetView(at: p) {
            let sheetP = sheetView.convertFromWorld(p)
            return sheetView.sheetColorOwner(at: sheetP,
                                             scale: screenToWorldScale).value.uuColor
        } else {
            return Sheet.defalutBackgroundUUColor
        }
    }
    func madeColorOwner(at p: Point,
                        enabledLine: Bool = true,
                        enabledAlwaysAnimation: Bool = false,
                        removingUUColor: UUColor? = Line.defaultUUColor) -> [SheetColorOwner] {
        guard let sheetView = madeSheetView(at: p) else {
            return []
        }
        let sheetP = sheetView.convertFromWorld(p)
        return [sheetView.sheetColorOwner(at: sheetP,
                                          enabledLine: enabledLine,
                                          enabledAlwaysAnimation: enabledAlwaysAnimation,
                                          removingUUColor: removingUUColor,
                                          scale: screenToWorldScale).value]
    }
    func madeColorOwnersWithSelection(at p: Point,
                                      enabledLinePlane: Bool = true,
                                      removingUUColor: UUColor? = Line.defaultUUColor) -> (firstUUColor: UUColor,
                                                                                           owners: [SheetColorOwner])? {
        guard let sheetView = madeSheetView(at: p) else {
            return nil
        }
        
        let sheetP = sheetView.convertFromWorld(p)
        let (isLine, topOwner) = sheetView.sheetColorOwner(at: sheetP,
                                                           enabledLinePlane: enabledLinePlane,
                                                           removingUUColor: removingUUColor,
                                                           scale: screenToWorldScale)
        let uuColor = topOwner.uuColor
        
        if topOwner.sheetView.containsSelectedLineOrPlane(sheetP, scale: screenToWorldScale) {
            var colorOwners = [SheetColorOwner]()
            for co in sheetView.sheetColorOwnerWithSelection(isLine: isLine) {
                colorOwners.append(co)
            }
            return (uuColor, sheetView.sheetColorOwnerWithSelection(isLine: isLine))
        } else {
            let colorOwners: [SheetColorOwner] = if let co = sheetView
                .sheetColorOwner(with: uuColor) { [co] } else { [] }
            return (uuColor, colorOwners)
        }
    }
    func colors(minArea: Double = 9, at p: Point) -> [Color] {
        guard let sheetView = sheetView(at: p) else {
            return []
        }
        let scale = screenToWorldScale
        let minArea = minArea * scale * scale
        return sheetView.model.picture.planes.compactMap {
            guard let area = $0.bounds?.area, area > minArea else {
                return nil
            }
            return $0.uuColor.value
        }
    }
    func readColorOwners(at p: Point) -> [SheetColorOwner] {
        guard let sheetView = readSheetView(at: p) else {
            return []
        }
        let sheetP = sheetView.convertFromWorld(p)
        let uuColor = sheetView.sheetColorOwner(at: sheetP,
                                                scale: screenToWorldScale).value.uuColor
        if let co = sheetView.sheetColorOwner(with: uuColor) {
            return [co]
        } else {
            return []
        }
    }
    func colorOwners(at p: Point, enabledAlwaysAnimation: Bool = false) -> [SheetColorOwner] {
        guard let sheetView = readSheetView(at: p) else {
            return []
        }
        let sheetP = sheetView.convertFromWorld(p)
        return [sheetView.sheetColorOwner(at: sheetP,
                                          enabledAlwaysAnimation: enabledAlwaysAnimation,
                                          scale: screenToWorldScale).value]
    }
    func isDefaultUUColor(at p: Point) -> Bool {
        if let sheetView = sheetView(at: p) {
            let sheetP = sheetView.convertFromWorld(p)
            let uuColor = sheetView.sheetColorOwner(at: sheetP,
                                                    scale: screenToWorldScale).value.uuColor
            return uuColor == Sheet.defalutBackgroundUUColor
            || (uuColor.id == .two && uuColor.value.opacity == 0)
        } else {
            return true
        }
    }
    
    func updateFromAroundWithTimeline(at cShp: IntPoint) {
        func topAndBottom(at ncShp: IntPoint, in aSheetView: SheetView) {
            var nncShp = ncShp, npsvs = [WeakElement<SheetView>]()
            nncShp.y -= 1
            while let aaSheetView = sheetView(at: nncShp),
                  aaSheetView.model.enabledTimeline {
                npsvs.append(.init(element: aaSheetView))
                nncShp.y -= 1
            }
            aSheetView.bottomSheetViews = npsvs.reversed()
            nncShp = ncShp
            npsvs = []
            nncShp.y += 1
            while let aaSheetView = sheetView(at: nncShp),
                  aaSheetView.model.enabledTimeline {
                npsvs.append(.init(element: aaSheetView))
                nncShp.y += 1
            }
            aSheetView.topSheetViews = npsvs
        }
        
        let shps = groupSheetPositions(at: cShp)
        for cShp in shps {
            guard let cSheetView = sheetView(at: cShp) else { continue }
            
            topAndBottom(at: cShp, in: cSheetView)
            
            var ncShp = cShp, psvs = [WeakElement<SheetView>]()
            while let preShp = nearestVerticalSheetPosition(at: ncShp, deltaX: -1) {
                guard let ncSheetView = sheetView(at: preShp),
                      ncSheetView.model.enabledTimeline else { break }
                psvs.append(.init(element: ncSheetView))
                ncShp = preShp
            }
            cSheetView.previousSheetViews = psvs.reversed()
            
            ncShp = cShp
            var nsvs = [WeakElement<SheetView>]()
            while let nextShp = nearestVerticalSheetPosition(at: ncShp, deltaX: 1) {
                guard let ncSheetView = sheetView(at: nextShp),
                      ncSheetView.model.enabledTimeline else { break }
                nsvs.append(.init(element: ncSheetView))
                ncShp = nextShp
            }
            cSheetView.nextSheetViews = nsvs
        }
    }
    func currentSampless(at shp: IntPoint,
                         sampleRate: Double = Audio.defaultSampleRate) -> [[Double]] {
        guard let sheetView = sheetViewValue(at: shp)?.sheetView,
                sheetView.model.isEnabledAudio else { return [] }
        
        updateFromAroundWithTimeline(at: shp)
        
        var seqTracks = [Sequencer.Track]()
        
        sheetView.previousSheetViews.forEach {
            guard let seqTrack = $0.element?.seqTrack(sampleRate: sampleRate) else { return }
            seqTracks.append(seqTrack)
        }
        
        let seqTrack = sheetView.seqTrack(sampleRate: sampleRate)
        seqTracks.append(seqTrack)
        
        sheetView.nextSheetViews.forEach {
            guard let seqTrack = $0.element?.seqTrack(sampleRate: sampleRate) else { return }
            seqTracks.append(seqTrack)
        }
        
        let seq = Sequencer(tracks: seqTracks, type: .normal)
        let buffer = try? seq?.buffer(sampleRate: sampleRate, headroomType: .none, limitLufs: nil,
                                      isClip: false) { d, flag in }
        return buffer?.doubleSampless ?? []
    }
    
    var worldKnobEditDistance: Double {
        Sheet.knobEditDistance * screenToWorldScale
    }
    
    var editGrid: EditGrid {
        .init(logScale: pov.logScale)
    }
    var currentBeatInterval: Rational {
        editGrid.beatInterval
    }
    var currentKeyframeBeatInterval: Rational {
        currentBeatInterval
    }
    var currentPitchInterval: Rational {
        editGrid.pitchInterval
    }
    func smoothPitch(from scoreView: ScoreView, at scoreP: Point) -> Double? {
        scoreView.smoothPitch(atY: scoreP.y)
    }
    var isFullEdit: Bool {
        editGrid == .full
    }
    var isSecondEdit: Bool {
        editGrid == .second
    }
    
    static let mapScale = 16
    let mapWidth = Sheet.width * Double(mapScale), mapHeight = Sheet.height * Double(mapScale)
    private var mapIntPositions = Set<IntPoint>()
    func mapIntPosition(at p: IntPoint, mapScale: Int = mapScale) -> IntPoint {
        let x = (Rational(p.x) / Rational(mapScale)).rounded(.down).integralPart
        let y = (Rational(p.y) / Rational(mapScale)).rounded(.down).integralPart
        return .init(x, y)
    }
    func mapPosition(at ip: IntPoint) -> Point {
        Point(Double(ip.x) * mapWidth + mapWidth / 2,
              Double(ip.y) * mapHeight + mapHeight / 2)
    }
    func mapFrame(at shp: IntPoint) -> Rect {
        Rect(x: Double(shp.x) * mapWidth,
             y: Double(shp.y) * mapHeight,
             width: mapWidth, height: mapHeight)
    }
    private var roads = [Road]()
    func roads(fromMap mapIntPositions: Set<IntPoint>) -> [Road] {
        var roads = [Road]()
        
        var xSHPs = [Int: [IntPoint]]()
        for mSHP in mapIntPositions {
            if xSHPs[mSHP.y] != nil {
                xSHPs[mSHP.y]?.append(mSHP)
            } else {
                xSHPs[mSHP.y] = [mSHP]
            }
        }
        let sortedSHPs = xSHPs.sorted { $0.key < $1.key }
        var previousSHPs = [IntPoint]()
        for shpV in sortedSHPs {
            let sortedXSHPs = shpV.value.sorted { $0.x < $1.x }
            if sortedXSHPs.count > 1 {
                for i in 1 ..< sortedXSHPs.count {
                    roads.append(Road(shp0: sortedXSHPs[i - 1],
                                      shp1: sortedXSHPs[i]))
                }
            }
            if !previousSHPs.isEmpty {
                roads.append(Road(shp0: previousSHPs[0],
                                  shp1: sortedXSHPs[0]))
            }
            previousSHPs = sortedXSHPs
        }
        return roads
    }
    func updateMap() {
        mapIntPositions = Set(model.sheetRecorders.keys.reduce(into: [IntPoint]()) {
            if let shp = sheetPosition(at: $1) {
                $0.append(mapIntPosition(at: shp))
            }
        })
        let roads = roads(fromMap: mapIntPositions)
        self.roads = roads
        let pathlines = roads.compactMap {
            $0.pathlineWith(width: mapWidth, height: mapHeight)
        }
        mapNode.path = Path(pathlines, isCap: false)
    }
    func updateMapWith(worldToScreenTransform: Transform,
                       screenToWorldTransform: Transform,
                       pov: Attitude,
                       in screenBounds: Rect) {
        let worldBounds = screenBounds * screenToWorldTransform
        for road in roads {
            if worldBounds.intersects(Edge(mapPosition(at: road.shp0),
                                           mapPosition(at: road.shp1))) {
                currentMapNode.isHidden = true
                currentMapNode.path = Path()
                return
            }
        }
        if currentMapNode.isHidden {
            currentMapNode.isHidden = false
        }
        
        let worldCP = screenBounds.centerPoint * screenToWorldTransform
        
        let currentIP = sheetPosition(at: worldCP)
        let mapSHP = mapIntPosition(at: currentIP)
        var minMSHP: IntPoint?, minDSquared = Int.max
        for mshp in mapIntPositions {
            let dSquared = mshp.distanceSquared(mapSHP)
            if dSquared < minDSquared {
                minDSquared = dSquared
                minMSHP = mshp
            }
        }
        if let minMSHP = minMSHP {
            let road = Road(shp0: minMSHP, shp1: mapSHP)
            if let pathline = road.pathlineWith(width: mapWidth,
                                                height: mapHeight) {
                currentMapNode.path = Path([pathline])
            } else {
                currentMapNode.path = Path()
            }
        } else {
            currentMapNode.path = Path()
        }
    }
    func updateGrid(with transform: Transform, in bounds: Rect) {
        let bounds = bounds * transform, lw = gridNode.lineWidth
        let scale = isEditingSheet ? 1.0 : Double(Self.mapScale)
        let w = Sheet.width * scale, h = Sheet.height * scale
        let cp = Point()
        var pathlines = [Pathline]()
        let minXIndex = Int(((bounds.minX - cp.x - lw) / w).rounded(.down))
        let maxXIndex = Int(((bounds.maxX - cp.x + lw) / w).rounded(.up))
        let minYIndex = Int(((bounds.minY - cp.y - lw) / h).rounded(.down))
        let maxYIndex = Int(((bounds.maxY - cp.y + lw) / h).rounded(.up))
        if maxXIndex - minXIndex > 0 {
            for xi in minXIndex ..< maxXIndex {
                if minYIndex < maxYIndex {
                    let x = Double(xi) * w + cp.x
                    let minY = Double(minYIndex) * h + cp.y
                    let maxY = Double(maxYIndex) * h + cp.y
                    pathlines.append(Pathline(Edge(Point(x: x, y: minY),
                                                   Point(x: x, y: maxY))))
                }
            }
        }
        if maxYIndex - minYIndex > 0 {
            let minX = bounds.minX, maxX = bounds.maxX
            for i in minYIndex ..< maxYIndex {
                let y = Double(i) * h + cp.y
                pathlines.append(Pathline(Edge(Point(x: minX, y: y),
                                               Point(x: maxX, y: y))))
            }
        }
        gridNode.path = Path(pathlines, isCap: false)
        gridNode.lineWidth = transform.absXScale
        lastEditedSheetNode.lineWidth = gridNode.lineWidth
        
        updateMapColor(with: transform)
    }
    private enum MapType {
        case hidden, shown
    }
    private var oldMapType = MapType.hidden
    func updateMapColor(with transform: Transform) {
        let mapType: MapType = isEditingSheet ? .hidden : .shown
        switch mapType {
        case .hidden:
            if oldMapType != .hidden {
                mapNode.isHidden = true
                backgroundColor = .background
                mapNode.lineType = .color(.border)
                currentMapNode.lineType = .color(.border)
            }
        case .shown:
            let scale = transform.absXScale
            mapNode.lineWidth = 2 * scale
            currentMapNode.lineWidth = 2 * scale
            if oldMapType != .shown {
                if oldMapType == .hidden {
                    mapNode.isHidden = false
                    backgroundColor = .disabled
                    mapNode.lineType = .color(.subBorder)
                    currentMapNode.lineType = .color(.subBorder)
                }
            }
        }
        oldMapType = mapType
    }
    
    func cursor(from string: String, isArrow: Bool = false,
                progress: Double? = nil, progressWidth: Double = 40) -> Cursor {
        if isArrow {
            .arrowWith(string: string)
        } else if pov.rotation != 0 {
            .rotate(progress: progress, progressWidth: progressWidth, string: string,
                    fontSize: progress == 0 ? Font.largeSize : Font.defaultSize,
                    rotation: -pov.rotation + .pi / 2)
        } else {
            .circle(progress: progress, progressWidth: progressWidth, string: string,
                    fontSize: progress == 0 ? Font.largeSize : Font.defaultSize)
        }
    }
}
