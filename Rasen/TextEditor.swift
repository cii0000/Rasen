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

final class Finder: InputKeyEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    func send(_ event: InputKeyEvent) {
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            let p = document.convertScreenToWorld(event.screenPoint)
            guard let sheetView = document.sheetView(at: p) else { return }
            let inP = sheetView.convertFromWorld(p)
            if let (textView, _, i, _) = sheetView.textTuple(at: inP) {
                if document.isSelect(at: p),
                   let selection = document.multiSelection.firstSelection(at: p) {
                    
                    let nSelection = textView.convertFromWorld(selection)
                    let ranges = textView.ranges(at: nSelection)
                    if let range = ranges.first {
                        let string = String(textView.model.string[range])
                        document.selections.removeLast()
                        document.finding = Finding(worldPosition: p,
                                                   string: string)
                        document.selections = []
                    } else {
                        document.finding = Finding()
                    }
                } else {
                    if let range = textView.wordRange(at: i) {
                        let string = String(textView.model.string[range])
                        document.finding = Finding(worldPosition: p,
                                                   string: string)
                    }
                }
            } else {
                let topOwner = sheetView.sheetColorOwner(at: inP, scale: document.screenToWorldScale).value
                let uuColor = topOwner.uuColor
                if uuColor != Sheet.defalutBackgroundUUColor {
                    let string = uuColor.id.uuidString
                    document.finding = Finding(worldPosition: p,
                                               string: string)
                } else {
                    document.finding = Finding()
                }
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class Looker: InputKeyEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    func send(_ event: InputKeyEvent) {
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            let p = document.convertScreenToWorld(event.screenPoint)
            let isClose = !show(for: p)
            if isClose {
                document.closeLookingUpNode()
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    func show(for p: Point) -> Bool {
        let d = 5 / document.worldToScreenScale
        if !document.isEditingSheet {
            if let sid = document.sheetID(at: document.sheetPosition(at: p)),
               let recoder = document.sheetRecorders[sid],
               let updateDate = recoder.directory.updateDate,
               let createdDate = recoder.directory.createdDate {
               
                let fileSize = recoder.fileSize
                let string = IOResult.fileSizeNameFrom(fileSize: fileSize)
                document.show("Sheet".localized + "\n\t\("File Size".localized): \(string)" + "\n\t\("Update Date".localized): \(updateDate.defaultString)" + "\n\t\("Created Date".localized): \(createdDate.defaultString)", at: p)
            } else {
                document.show("Root".localized, at: p)
            }
            return true
        } else if document.isSelect(at: p), !document.selections.isEmpty {
            if let selection = document.multiSelection.firstSelection(at: p) {
                if let sheetView = document.sheetView(at: p),
                   let (textView, _, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
                    
                    let nSelection = textView.convertFromWorld(selection)
                    if let range = textView.ranges(at: nSelection).first {
                        let string = String(textView.model.string[range])
                        showDefinition(string: string, range: range,
                                       in: textView, in: sheetView)
                        
                    }
                } else if let sheetView = document.sheetView(at: p),
                          let (node, hMaxMel, _) = sheetView.spectrogramNode(at: sheetView.convertFromWorld(p)) {
                    let nSelection = sheetView.convertFromWorld(selection)
                    let rect = node.convertFromWorld(selection.rect)
                    let minY = rect.minY - 0.5, maxY = rect.maxY - 0.5
                    let h = node.path.bounds?.height ?? 0
                    let minMel = minY.clipped(min: 0, max: h,
                                              newMin: 0, newMax: hMaxMel)
                    let maxMel = maxY.clipped(min: 0, max: h,
                                              newMin: 0, newMax: hMaxMel)
                    let minFq = Int(Mel.fq(fromMel: minMel))
                    let maxFq = Int(Mel.fq(fromMel: maxMel))
                    let minSec: Rational = sheetView.animationView.sec(atX: nSelection.rect.minX)
                    let maxSec: Rational = sheetView.animationView.sec(atX: nSelection.rect.maxX)
                    document.show("Δ\(Double(maxSec - minSec).string(digitsCount: 4)) sec, Δ\(maxFq - minFq) Hz", at: p)
                } else if let sheetView = document.sheetView(at: p),
                          let ti = sheetView.timeframeIndex(at: sheetView.convertFromWorld(p)) {
                    let textView = sheetView.textsView.elementViews[ti]
                    let inTP = textView.convertFromWorld(p)
                    if textView.containsScore(inTP),
                       let timeframe = textView.model.timeframe,
                       let score = timeframe.score {
                        
                        let nis = document.selectedNoteIndexes(from: textView)
                        if !nis.isEmpty {
                            let notes = nis.map { score.convertPitchToWorld(score.notes[$0]) }
                            
                            let minNote = notes.min { $0.pitch < $1.pitch }!
                            let maxNote = notes.max { $0.pitch < $1.pitch }!
                            
                            let str = "\(minNote.octavePitchString) ... \(maxNote.octavePitchString)  (\(minNote.fq.string(digitsCount: 3)) ... \(maxNote.fq.string(digitsCount: 3)) Hz)".localized
                            document.show(str, at: p)
                        }
                    }
                }
            }
            return true
        } else if let (_, _) = document.worldBorder(at: p, distance: d) {
            document.show("Border".localized, at: p)
            return true
        } else if let (_, _, _) = document.border(at: p, distance: d) {
            document.show("Border".localized, at: p)
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let lineView = sheetView.lineTuple(at: sheetView.convertFromWorld(p), scale: 1 / document.worldToScreenScale)?.lineView {
            document.show("Line".localized + "\n\t\("Length".localized):  \(lineView.model.length().string(digitsCount: 4))", at: p)
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (textView, _, i, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
            
            if let range = textView.wordRange(at: i) {
                let string = String(textView.model.string[range])
                showDefinition(string: string, range: range,
                               in: textView, in: sheetView)
            } else {
                document.show("Text".localized, at: p)
            }
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (note, score) = sheetView.noteAndScore(at: sheetView.convertFromWorld(p), scale: document.screenToWorldScale) {
            let note = score.convertPitchToWorld(note)
            let fq = note.fq
            let fqStr = "\(note.octavePitchString) (\(fq.string(digitsCount: 3)) Hz)".localized
            document.show(fqStr, at: p)
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (_, timeframe) = sheetView.timeframeTuple(at: sheetView.convertFromWorld(p)),
                  let lufs = timeframe.content?.integratedLoudness,
                  let db = timeframe.content?.samplePeakDb {
            
            document.show("Sound".localized + "\n\t\("Loudness".localized): \(lufs.string(digitsCount: 4)) LUFS" + "\n\t\("Sample Peak".localized): \(db.string(digitsCount: 4)) dB", at: p)
            
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (_, timeframe) = sheetView.timeframeTuple(at: sheetView.convertFromWorld(p)),
                  let buffer = timeframe.renderedPCMBuffer {
            
            let inP = sheetView.convertFromWorld(p)
            let lufs = buffer.integratedLoudness
            let db = buffer.samplePeakDb
            let sec: Rational = sheetView.animationView.sec(atX: inP.x)
            document.show("Score".localized
                          + "\n\t\(Double(sec).string(digitsCount: 4)) sec"
                          + "\n\t\("Loudness".localized): \(lufs.string(digitsCount: 4)) LUFS"
                          + "\n\t\("Sample Peak".localized): \(db.string(digitsCount: 4)) dB",
                          at: p)
            
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (node, maxMel, textView) = sheetView.spectrogramNode(at: sheetView.convertFromWorld(p)) {
            let y = node.convertFromWorld(p).y - 0.5 * textView.nodeRatio
            let h = node.path.bounds?.height ?? 0
            let mel = y.clipped(min: 0, max: h, newMin: 0, newMax: maxMel)
            let fq = Mel.fq(fromMel: mel)
            let pitch = Pitch.pitch(fromFq: fq)
            let pitchRat = Rational(pitch, intervalScale: .init(1, 12))
            let nfq = Pitch(value: pitchRat).fq
            let fqStr = "\(Pitch(value: pitchRat).octaveString) (\(nfq.string(digitsCount: 3)) Hz)".localized
            document.show(fqStr, at: p)
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let buffer = sheetView.model.pcmBuffer {
            
            let lufs = buffer.integratedLoudness
            let db = buffer.samplePeakDb
            document.show("Sheet".localized + "\n\t\("Loudness".localized): \(lufs.string(digitsCount: 4)) LUFS" + "\n\t\("Sample Peak".localized): \(db.string(digitsCount: 4)) dB", at: p)
            return true
        } else if !document.isDefaultUUColor(at: p) {
            let colorOwners = document.readColorOwners(at: p)
            if !colorOwners.isEmpty,
               let sheetView = document.sheetView(at: p),
               let plane = sheetView.plane(at: sheetView.convertFromWorld(p)) {
                
                let rgba = plane.uuColor.value.rgba
                document.show("Face".localized + "\n\t\("Area".localized):  \(plane.topolygon.area.string(digitsCount: 4))\n\tsRGB: \(rgba.r) \(rgba.g) \(rgba.b)", at: p)
                return true
            }
        }
        
        return false
    }
    
    func showDefinition(string: String,
                        range: Range<String.Index>,
                        in textView: SheetTextView, in sheetView: SheetView) {
        let np = textView.characterPosition(at: range.lowerBound)
        if let nstr = TextDictionary.string(from: string) {
            show(string: nstr, fromSize: textView.model.size,
                 rects: textView.transformedRects(with: range),
                 at: np, in: textView, in: sheetView)
        } else {
            show(string: "?", fromSize: textView.model.size,
                 rects: textView.transformedRects(with: range),
                 at: np, in: textView, in: sheetView)
        }
    }
    func show(string: String, fromSize: Double, rects: [Rect], at p: Point,
              in textView: SheetTextView, in sheetView: SheetView) {
        document.show(string,
                      fromSize: fromSize,
                      rects: rects.map { sheetView.convertToWorld($0) },
                      textView.model.orientation)
    }
}

final class VerticalTextChanger: InputKeyEditor {
    let editor: TextOrientationEditor
    
    init(_ document: Document) {
        editor = TextOrientationEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeToVerticalText(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class HorizontalTextChanger: InputKeyEditor {
    let editor: TextOrientationEditor
    
    init(_ document: Document) {
        editor = TextOrientationEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeToHorizontalText(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class TextOrientationEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    func changeToVerticalText(with event: InputKeyEvent) {
        changeTextOrientation(.vertical, with: event)
    }
    func changeToHorizontalText(with event: InputKeyEvent) {
        changeTextOrientation(.horizontal, with: event)
    }
    func changeTextOrientation(_ orientation: Orientation, with event: InputKeyEvent) {
        guard isEditingSheet else {
            switch event.phase {
            case .began:
                document.cursor = .arrow
                
                let p = document.convertScreenToWorld(event.screenPoint)
                var shp = document.sheetPosition(at: p)
                let isRight = orientation == .horizontal
                if let sid = document.sheetID(at: shp),
                   shp.isRight != isRight {
                   
                    shp.isRight = isRight
                    document.history.newUndoGroup()
                    document.removeSheets(at: [shp])
                    document.append([shp: sid])
                }
            case .changed:
                break
            case .ended:
                document.cursor = Document.defaultCursor
            }
            
            return
        }
        switch event.phase {
        case .began:
            defer {
                document.updateTextCursor()
            }
            document.cursor = .arrow
            
            let p = document.convertScreenToWorld(event.screenPoint)
            
            if document.isSelectNoneCursor(at: p), !document.multiSelection.isEmpty {
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if document.multiSelection.intersects(ssFrame),
                       let sheetView = document.sheetView(at: shp) {
                        
                        let ms = sheetView.convertFromWorld(document.multiSelection)
                        var tivs = [IndexValue<Text>]()
                        for (i, textView) in sheetView.textsView.elementViews.enumerated() {
                            if let tb = textView.transformedBounds, ms.intersects(tb) {
                                var text = textView.model
                                text.orientation = orientation
                                tivs.append(IndexValue(value: text, index: i))
                            }
                            
                        }
                        if !tivs.isEmpty {
                            sheetView.newUndoGroup()
                            sheetView.replace(tivs)
                        }
                    }
                }
            } else if !document.isNoneCursor {
                document.textEditor.begin(atScreen: event.screenPoint)
                
                guard let sheetView = document.sheetView(at: p) else { return }
                if let aTextView = document.textEditor.editingTextView,
                   !aTextView.isHiddenSelectedRange,
                   let i = sheetView.textsView.elementViews
                    .firstIndex(of: aTextView) {
                    
                    document.textEditor.endInputKey(isUnmarkText: true,
                                                    isRemoveText: false)
                    let textView = aTextView
                    var text = textView.model
                    if text.orientation != orientation {
                        text.orientation = orientation
                        
                        let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                        if let textFrame = text.frame, !sb.contains(textFrame) {
                            let nFrame = sb.clipped(textFrame)
                            text.origin += nFrame.origin - textFrame.origin
                            
                            if let textFrame = text.frame, !sb.outset(by: 1).contains(textFrame) {
                                
                                let scale = min(sb.width / textFrame.width,
                                                sb.height / textFrame.height)
                                let dp = sb.clipped(textFrame).origin - textFrame.origin
                                text.size *= scale
                                text.origin += dp
                            }
                        }
                        
                        sheetView.newUndoGroup()
                        sheetView.replace([IndexValue(value: text, index: i)])
                    }
                } else {
                    let inP = sheetView.convertFromWorld(p)
                    document.textEditor
                        .appendEmptyText(screenPoint: event.screenPoint,
                                         at: inP,
                                         orientation: orientation,
                                         in: sheetView)
                }
            }
            
            document.updateSelects()
            document.updateFinding(at: p)
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class SuperscriptChanger: InputKeyEditor {
    let editor: TextScriptEditor
    
    init(_ document: Document) {
        editor = TextScriptEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeScripst(true, with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class SubscriptChanger: InputKeyEditor {
    let editor: TextScriptEditor
    
    init(_ document: Document) {
        editor = TextScriptEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeScripst(false, with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class TextScriptEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    func changeScripst(_ isSuper: Bool, with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        func moveCharacter(isSuper: Bool, from c: Character) -> Character? {
            if isSuper {
                if c.isSuperscript {
                    return nil
                } else if c.isSubscript {
                    return c.fromSubscript
                } else {
                    return c.toSuperscript
                }
            } else {
                if c.isSuperscript {
                    return c.fromSuperscript
                } else if c.isSubscript {
                    return nil
                } else {
                    return c.toSubscript
                }
            }
        }
        
        switch event.phase {
        case .began:
            defer {
                document.updateTextCursor()
            }
            document.cursor = .arrow
            
            let p = document.convertScreenToWorld(event.screenPoint)
            
            if document.isSelect(at: p),
               let selection = document.multiSelection.firstSelection(at: p) {
                
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if ssFrame.intersects(selection.rect),
                       let sheetView = document.sheetView(at: shp) {
                        
                        var isNewUndoGroup = true
                        for (j, textView) in sheetView.textsView.elementViews.enumerated() {
                            let nSelection = textView.convertFromWorld(selection)
                            let ranges = textView.ranges(at: nSelection)
                            let string = textView.model.string
                            for range in ranges {
                                let str = string[range]
                                var nstr = "", isChange = false
                                for c in str {
                                    if let nc = moveCharacter(isSuper: isSuper, from: c) {
                                        nstr.append(nc)
                                        isChange = true
                                    } else {
                                        nstr.append(c)
                                    }
                                }
                                if isChange {
                                    let tv = TextValue(string: nstr,
                                                       replacedRange: string.intRange(from: range),
                                                       origin: nil, size: nil,
                                                       widthCount: nil)
                                    if isNewUndoGroup {
                                        sheetView.newUndoGroup()
                                        isNewUndoGroup = false
                                    }
                                    sheetView.replace(IndexValue(value: tv, index: j))
                                }
                            }
                        }
                    }
                }
            } else {
                document.textEditor.begin(atScreen: event.screenPoint)
                
                guard let sheetView = document.sheetView(at: p) else { return }
                if let aTextView = document.textEditor.editingTextView,
                   !aTextView.isHiddenSelectedRange,
                   let ai = sheetView.textsView.elementViews
                    .firstIndex(of: aTextView) {
                    
                    document.textEditor.endInputKey(isUnmarkText: true,
                                                    isRemoveText: true)
                    guard let ati = aTextView.selectedRange?.lowerBound,
                          ati > aTextView.model.string.startIndex else { return }
                    let textView = aTextView
                    let i = ai
                    let ti = aTextView.model.string.index(before: ati)
                    
                    let text = textView.model
                    if !text.string.isEmpty {
                        let ti = ti >= text.string.endIndex ?
                            text.string.index(before: text.string.endIndex) : ti
                        let c = text.string[ti]
                        if let nc = moveCharacter(isSuper: isSuper, from: c) {
                            let nti = text.string.intIndex(from: ti)
                            let tv = TextValue(string: String(nc),
                                               replacedRange: nti ..< (nti + 1),
                                               origin: nil, size: nil,
                                               widthCount: nil)
                            sheetView.newUndoGroup()
                            sheetView.replace(IndexValue(value: tv, index: i))
                        }
                    }
                }
            }
            
            document.updateSelects()
            document.updateFinding(at: p)
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class TextEditor: Editor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    deinit {
        inputKeyTimer.cancel()
    }
    
    weak var editingSheetView: SheetView?
    weak var editingTextView: SheetTextView? {
        didSet {
            if editingTextView !== oldValue {
                editingTextView?.editor = self
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
    var isIndicated = false
    
    var isMovedCursor = true
    
    enum InputKeyEditType {
        case insert, remove, moveCursor, none
    }
    private(set) var inputType = InputKeyEditType.none
    private var inputKeyTimer = OneshotTimer(), isInputtingKey = false
    private var captureString = "", captureOrigin: Point?,
                captureSize: Double?, captureWidthCount: Double?,
                captureOrigins = [Point](),
                isFirstInputKey = false
    
    func begin(atScreen sp: Point) {
        guard document.isEditingSheet else { return }
        let p = document.convertScreenToWorld(sp)
        
        document.textCursorNode.isHidden = true
        document.textMaxTypelineWidthNode.isHidden = true
        
        guard let sheetView = document.madeSheetView(at: p) else { return }
        let inP = sheetView.convertFromWorld(p)
        if !isMovedCursor, let eTextView = editingTextView,
           sheetView.textsView.elementViews.contains(eTextView) {
            
        } else if let (textView, _, _, sri) = sheetView.textTuple(at: inP) {
            if isMovedCursor {
                if textView.editor == nil {
                    textView.editor = self
                }
                textView.selectedRange = sri ..< sri
                textView.updateCursor()
                textView.updateSelectedLineLocation()
            }
            self.editingSheetView = sheetView
            self.editingTextView = textView
            Cursor.isHidden = true
            isMovedCursor = false
        }
    }
    
    func send(_ event: InputTextEvent) {
        switch event.phase {
        case .began:
            beginInputKey(event)
        case .changed:
            beginInputKey(event)
        case .ended:
            sendEnd()
        }
    }
    func sendEnd() {
        if document.oldInputTextKeys.isEmpty && !Cursor.isHidden {
            document.cursor = Document.defaultCursor
        }
    }
    func stopInputKey(isEndEdit: Bool = true) {
        sendEnd()
        cancelInputKey(isEndEdit: isEndEdit)
        endInputKey(isUnmarkText: true, isRemoveText: true)
    }
    func beginInputKey(_ event: InputTextEvent) {
        guard document.isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        let p = document.convertScreenToWorld(event.screenPoint)
        if !event.isRepeat,
           let sheetView = document.sheetView(at: p) {
            let inP = sheetView.convertFromWorld(p)
            if let (ti, timeframe) = sheetView.timeframeTuple(at: inP) {
                let textView = sheetView.textsView.elementViews[ti]
                let maxD = textView.nodeRatio
                * 15.0 * document.screenToWorldScale
                
                let inTP = textView.convert(inP, from: sheetView.node)
                if textView.containsScore(inTP),
                   var score = timeframe.score,
                   let ni = textView.noteIndex(at: inTP,
                                               maxDistance: maxD) {
                    
                    let key = (event.inputKeyType.name.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? "").lowercased()
                    if key == "^" {
                        score.notes[ni].isBreath = true
                    } else if key == "~" {
                        score.notes[ni].isVibrato = true
                    } else if key == "/" {
                        score.notes[ni].isVowelReduction = true
                    } else if event.inputKeyType == .delete, !score.notes[ni].lyric.isEmpty {
                        score.notes[ni].lyric.removeLast()
                    } else if event.inputKeyType != .delete {
                        score.notes[ni].lyric += key
                    }
                    
                    var timeframe = timeframe
                    timeframe.score = score
                    sheetView.newUndoGroup()
                    sheetView.replaceScore(score, at: ti)
                    return
                }
            }
        }
        
        if !document.finding.isEmpty,
           document.editingFindingSheetView == nil {
            let sp = event.screenPoint
            let p = document.convertScreenToWorld(sp)
            guard let sheetView = document.sheetView(at: p) else { return }
            let inP = sheetView.convertFromWorld(p)
            
            if let (textView, _, si, _) = sheetView.textTuple(at: inP),
                let range = textView.model.string.ranges(of: document.finding.string)
                .first(where: { $0.contains(si) }) {
                
                document.isEditingFinding = true
                document.editingFindingSheetView = sheetView
                document.editingFindingTextView = textView
                document.editingFindingRange
                = textView.model.string.intRange(from: range)
                let str = textView.model.string
                var nstr = str
                nstr.removeSubrange(range)
                document.editingFindingOldString = str
                document.editingFindingOldRemovedString = nstr
            }
        }
        
        document.textCursorNode.isHidden = true
        document.textMaxTypelineWidthNode.isHidden = true
        
        if !isMovedCursor,
           let eSheetView = editingSheetView,
           let eTextView = editingTextView,
           eSheetView.textsView.elementViews.contains(eTextView) {
            
            inputKey(with: event, in: eTextView, in: eSheetView)
        } else {
            let sp = event.screenPoint
            let p = document.convertScreenToWorld(sp)
            guard let sheetView = document.madeSheetView(at: p) else { return }
            let inP = sheetView.convertFromWorld(p)
            if let (textView, _, _, sri) = sheetView.textTuple(at: inP) {
                if isMovedCursor {
                    if textView.editor == nil {
                        textView.editor = self
                    }
                    textView.selectedRange = sri ..< sri
                    textView.updateCursor()
                    textView.updateSelectedLineLocation()
                }
                self.editingSheetView = sheetView
                self.editingTextView = textView
                Cursor.isHidden = true
                inputKey(with: event, in: textView, in: sheetView)
                isMovedCursor = false
            } else if event.inputKeyType.isInputText {
                appendEmptyText(event, at: inP, in: sheetView)
            }
        }
    }
    func appendEmptyText(_ event: InputTextEvent, at inP: Point,
                         orientation: Orientation = .horizontal,
                         in sheetView: SheetView) {
        let text = Text(string: "", orientation: orientation,
                        size: document.sheetTextSize, origin: inP,
                        locale: TextInputContext.currentLocale)
        sheetView.newUndoGroup()
        sheetView.append(text)
        
        self.isFirstInputKey = true
        
        let editingTextView = sheetView.textsView.elementViews.last!
        let si = editingTextView.model.string.startIndex
        editingTextView.selectedRange = si ..< si
        editingTextView.updateCursor()
        
        self.editingSheetView = sheetView
        self.editingTextView = editingTextView
        
        Cursor.isHidden = true
        
        inputKey(with: event, in: editingTextView, in: sheetView,
                 isNewUndoGroup: false)
        
        isMovedCursor = false
    }
    func appendEmptyText(screenPoint: Point, at inP: Point,
                         orientation: Orientation = .horizontal,
                         in sheetView: SheetView) {
        let text = Text(string: "", orientation: orientation,
                        size: document.sheetTextSize, origin: inP,
                        locale: TextInputContext.currentLocale)
        sheetView.newUndoGroup()
        sheetView.append(text)
        
        self.isFirstInputKey = true
        
        let editingTextView = sheetView.textsView.elementViews.last!
        let si = editingTextView.model.string.startIndex
        editingTextView.selectedRange = si ..< si
        editingTextView.updateCursor()
        
        self.editingSheetView = sheetView
        self.editingTextView = editingTextView
        
        Cursor.isHidden = true
        
        isMovedCursor = false
    }
    
    func cancelInputKey(isEndEdit: Bool = true) {
        if let editingTextView = editingTextView {
            inputKeyTimer.cancel()
            editingTextView.unmark()
            let oldEditingSheetView = editingSheetView
            if isEndEdit {
                editingTextView.isHiddenSelectedRange = true
                editingSheetView = nil
                self.editingTextView = nil
                Cursor.isHidden = false
            }
            
            document.updateSelects()
            if let oldEditingSheetView = oldEditingSheetView {
                document.updateFinding(from: oldEditingSheetView)
            }
        }
    }
    func endInputKey(isUnmarkText: Bool = false, isRemoveText: Bool = false) {
        if let editingTextView = editingTextView,
           inputKeyTimer.isWait || editingTextView.isMarked {
            
            if isUnmarkText {
                editingTextView.unmark()
            }
            inputKeyTimer.cancel()
            if isRemoveText, let sheetView = editingSheetView {
                removeText(in: editingTextView, in: sheetView)
            }
            
            document.updateSelects()
            if let editingSheetView = editingSheetView {
                document.updateFinding(from: editingSheetView)
            }
        }
    }
    func inputKey(with event: InputTextEvent,
                  in textView: SheetTextView,
                  in sheetView: SheetView,
                  isNewUndoGroup: Bool = true) {
        inputKey(with: { event.send() }, in: textView, in: sheetView,
                 isNewUndoGroup: isNewUndoGroup)
    }
    var isCapturing = false
    func inputKey(with handler: () -> (),
                  in textView: SheetTextView,
                  in sheetView: SheetView,
                  isNewUndoGroup: Bool = true,
                  isUpdateCursor: Bool = true) {
        guard !isCapturing else {
            handler()
            return
        }
        isCapturing = true
        if !inputKeyTimer.isWait {
            self.captureString = textView.model.string
            self.captureOrigin = textView.model.origin
            self.captureSize = textView.model.size
            self.captureWidthCount = textView.model.widthCount
            self.captureOrigins = sheetView.textsView.elementViews
                .map { $0.model.origin }
        }
        
        let oldString = textView.model.string
        let oldTypelineOrigins = textView.typesetter.typelines.map { $0.origin }
        let oldI = textView.selectedTypelineIndex
        let oldSpacing = textView.typesetter.typelineSpacing
        let oldBoundsArray = textView.typesetter.typelines.map { $0.frame }
        
        handler()
        
        update(oldString: oldString, oldSpacing: oldSpacing,
               oldTypelineOrigins: oldTypelineOrigins, oldTypelineIndex: oldI,
               oldBoundsArray: oldBoundsArray,
               in: textView, in: sheetView,
               isUpdateCursor: isUpdateCursor)
        
        let beginClosure: () -> () = { [weak self] in
            guard let self else { return }
            self.beginInputKey()
        }
        let waitClosure: () -> () = {}
        let cancelClosure: () -> () = { [weak self,
                                         weak textView,
                                         weak sheetView] in
            guard let self,
                  let textView = textView,
                  let sheetView = sheetView else { return }
            self.endInputKey(in: textView, in: sheetView,
                             isNewUndoGroup: isNewUndoGroup)
        }
        let endClosure: () -> () = { [weak self,
                                      weak textView,
                                      weak sheetView] in
            guard let self,
                  let textView = textView,
                  let sheetView = sheetView else { return }
            self.endInputKey(in: textView, in: sheetView,
                             isNewUndoGroup: isNewUndoGroup)
        }
        inputKeyTimer.start(afterTime: 0.5, dispatchQueue: .main,
                            beginClosure: beginClosure,
                            waitClosure: waitClosure,
                            cancelClosure: cancelClosure,
                            endClosure: endClosure)
        isCapturing = false
    }
    func beginInputKey() {
        if !isInputtingKey {
        } else {
            isInputtingKey = true
        }
    }
    func moveEndInputKey(isStopFromMarkedText: Bool = false) {
        func updateFinding() {
            if !document.finding.isEmpty {
                if let sheetView = editingSheetView,
                   let textView = editingTextView,
                   sheetView == document.editingFindingSheetView
                    && textView == document.editingFindingTextView,
                   let oldString = document.editingFindingOldString,
                   let oldRemovedString = document.editingFindingOldRemovedString {
                    let substring = oldRemovedString
                        .difference(to: textView.model.string)?.subString ?? ""
                    if substring != document.finding.string {
                        document.replaceFinding(from: substring,
                                                oldString: oldString,
                                                oldTextView: textView)
                    }
                }
                
                document.isEditingFinding = false
            }
        }
        if let editingTextView = editingTextView,
           let editingSheetView = editingSheetView {
            
            if isStopFromMarkedText ? !editingTextView.isMarked : true {
                inputKeyTimer.cancel()
                editingTextView.unmark()
                editingTextView.isHiddenSelectedRange = true
                updateFinding()
                self.editingSheetView = nil
                self.editingTextView = nil
                removeText(in: editingTextView, in: editingSheetView)
            } else {
                updateFinding()
            }
        } else {
            updateFinding()
        }
        if Cursor.isHidden {
            Cursor.isHidden = false
        }
    }
    func endInputKey(in textView: SheetTextView,
                     in sheetView: SheetView,
                     isNewUndoGroup: Bool = true) {
        isInputtingKey = false
        guard let i = sheetView.textsView.elementViews
                .firstIndex(of: textView) else { return }
        let value = captureString.difference(to: textView.model.string)
        
//        if let str = value?.subString {
//            let dic = O.defaultDictionary(with: Sheet(), ssDic: [:],
//                                cursorP: Point(), printP: Point())
//            dic.keys.forEach { (key) in
//                if key.baseString == str {
//                    print(key.baseString)
//                }
//            }
//            print("SS:", str)
//        }
        
        // Spell Check (Version 2.0)
        
        let isChangeOption = captureOrigin != textView.model.origin
            || captureSize != textView.model.size
            || captureWidthCount != textView.model.widthCount
        
        if isFirstInputKey {
            isFirstInputKey = false
        } else if isNewUndoGroup && (value != nil || isChangeOption) {
            sheetView.newUndoGroup()
        }
        
        if let value = value {
            sheetView.capture(intRange: value.intRange,
                              subString: value.subString,
                              captureString: captureString,
                              captureOrigin: captureOrigin,
                              captureSize: captureSize,
                              captureWidthCount: captureWidthCount,
                              at: i, in: textView)
            for (j, aTextView) in sheetView.textsView.elementViews.enumerated() {
                if j < captureOrigins.count && textView != aTextView {
                    let origin = captureOrigins[j]
                    sheetView.capture(captureOrigin: origin,
                                      at: j, in: aTextView)
                }
            }
            captureString = textView.model.string
        } else if isChangeOption {
            sheetView.capture(intRange: textView.model.string.intRange(from: textView.selectedRange ?? (textView.model.string.startIndex ..< textView.model.string.endIndex)),
                              subString: "",
                              captureString: captureString,
                              captureOrigin: captureOrigin,
                              captureSize: captureSize,
                              captureWidthCount: captureWidthCount,
                              at: i, in: textView)
        }
    }
    func removeText(in textView: SheetTextView,
                    in sheetView: SheetView) {
        guard let i = sheetView.textsView.elementViews
                .firstIndex(of: textView) else { return }
        if textView.model.string.isEmpty
             && textView.model.timeframe == nil {
            sheetView.removeText(at: i)
            if editingTextView != nil {
                editingSheetView = nil
                editingTextView = nil
            }
            document.updateSelects()
            document.updateFinding(from: sheetView)
        }
    }
    
    func cut(from selection: Selection, at p: Point) {
        guard let sheetView = document.madeSheetView(at: p) else { return }
        let inP = sheetView.convertFromWorld(p)
        guard let (textView, ti, _, _) = sheetView.textTuple(at: inP) else { return }
        
        guard let range = textView.range(from: selection) else { return }
        
        let minP = textView.typesetter
            .characterPosition(at: range.lowerBound)
        var removedText = textView.model
        removedText.string = String(removedText.string[range])
        removedText.origin += minP
        let ssValue = SheetValue(texts: [removedText])
        
        let removeRange: Range<String.Index>
        if textView.typesetter.isFirst(at: range.lowerBound) && textView.typesetter.isLast(at: range.upperBound) {
            
            let str = textView.typesetter.string
            if  str.startIndex < range.lowerBound {
                removeRange = str.index(before: range.lowerBound) ..< range.upperBound
            } else if range.upperBound < str.endIndex {
                removeRange = range.lowerBound ..< str.index(after: range.upperBound)
            } else {
                removeRange = range
            }
        } else {
            removeRange = range
        }
        
        let captureString = textView.model.string
        let captureOrigin = textView.model.origin
        let captureSize = textView.model.size
        let captureWidthCount = textView.model.widthCount
        editingTextView = textView
        editingSheetView = sheetView
        textView.removeCharacters(in: removeRange)
        textView.unmark()
        let sb = sheetView.bounds.inset(by: Sheet.textPadding)
        if let textFrame = textView.model.frame,
           !sb.contains(textFrame) {
           
            let nFrame = sb.clipped(textFrame)
            textView.model.origin += nFrame.origin - textFrame.origin
        }
        if let value = captureString.difference(to: textView.model.string) {
            sheetView.newUndoGroup()
            sheetView.capture(intRange: value.intRange,
                              subString: value.subString,
                              captureString: captureString,
                              captureOrigin: captureOrigin,
                              captureSize: captureSize,
                              captureWidthCount: captureWidthCount,
                              at: ti, in: textView)
        }
        
        Cursor.isHidden = true
        
        isMovedCursor = false
        
        let t = Transform(translation: -sheetView.convertFromWorld(p))
        let nValue = ssValue * t
        if let s = nValue.string {
            Pasteboard.shared.copiedObjects
                = [.sheetValue(nValue), .string(s)]
        } else {
            Pasteboard.shared.copiedObjects
                = [.sheetValue(nValue)]
        }
    }
    
    func update(oldString: String, oldSpacing: Double,
                oldTypelineOrigins: [Point], oldTypelineIndex: Int?,
                oldBoundsArray: [Rect],
                in textView: SheetTextView,
                in sheetView: SheetView,
                isUpdateCursor: Bool = true) {
        guard let p = textView.cursorPositon else { return }
        guard textView.model.string != oldString else {
            if isUpdateCursor {
                let osp = textView.convertToWorld(p)
                let sp = document.convertWorldToScreen(osp)
                if sp != document.cursorPoint {
                    textView.node.moveCursor(to: sp)
                    document.isUpdateWithCursorPosition = false
                    document.cursorPoint = sp
                    document.isUpdateWithCursorPosition = true
                }
            }
            return
        }
        
        if isUpdateCursor {
            let osp = textView.convertToWorld(p)
            let sp = document.convertWorldToScreen(osp)
            textView.node.moveCursor(to: sp)
            document.isUpdateWithCursorPosition = false
            document.cursorPoint = sp
            document.isUpdateWithCursorPosition = true
        }
        
        document.updateSelects()
        document.updateFinding(from: sheetView)
    }
    
    func characterIndex(for point: Point) -> String.Index? {
        guard let textView = editingTextView else { return nil }
        let sp = document.convertScreenToWorld(point)
        let p = textView.convertFromWorld(sp)
        return textView.characterIndex(for: p)
    }
    func characterRatio(for point: Point) -> Double? {
        guard let textView = editingTextView else { return nil }
        let sp = document.convertScreenToWorld(point)
        let p = textView.convertFromWorld(sp)
        return textView.characterRatio(for: p)
    }
    func characterPosition(at i: String.Index) -> Point? {
        guard let textView = editingTextView else { return nil }
        let p = textView.characterPosition(at: i)
        let sp = textView.convertToWorld(p)
        return document.convertWorldToScreen(sp)
    }
    func characterBasePosition(at i: String.Index) -> Point? {
        guard let textView = editingTextView else { return nil }
        let p = textView.characterBasePosition(at: i)
        let sp = textView.convertToWorld(p)
        return document.convertWorldToScreen(sp)
    }
    func characterBounds(at i: String.Index) -> Rect? {
        guard let textView = editingTextView,
              let rect = textView.characterBounds(at: i) else { return nil }
        let sRect = textView.convertToWorld(rect)
        return document.convertWorldToScreen(sRect)
    }
    func baselineDelta(at i: String.Index) -> Double? {
        guard let textView = editingTextView else { return nil }
        return textView.baselineDelta(at: i)
    }
    func firstRect(for range: Range<String.Index>) -> Rect? {
        guard let textView = editingTextView,
              let rect = textView.firstRect(for: range) else { return nil }
        let sRect = textView.convertToWorld(rect)
        return document.convertWorldToScreen(sRect)
    }
    
    func unmark() {
        editingTextView?.unmark()
    }
    enum InputEventType {
        case mark, insert, insertNewline, insertTab,
             deleteBackward, deleteForward,
             moveLeft, moveRight, moveUp, moveDown,
             none
    }
    var lastInputEventType = InputEventType.none
    func mark(_ string: String,
              markingRange: Range<String.Index>,
              at replacedRange: Range<String.Index>? = nil) {
        if let textView = editingTextView,
           let sheetView = editingSheetView {
           
            inputKey(with: { textView.mark(string,
                                           markingRange: markingRange,
                                           at: replacedRange) },
                     in: textView, in: sheetView,
                     isUpdateCursor: false)
        }
        lastInputEventType = .mark
    }
    func insert(_ string: String,
                at replacedRange: Range<String.Index>? = nil) {
        if inputType != .insert {
            endInputKey()
            inputType = .insert
        }
        editingTextView?.insert(string, at: replacedRange)
        lastInputEventType = .insert
    }
    func insertNewline() {
        if inputType != .insert {
            endInputKey()
            inputType = .insert
        }
        
        if document.modifierKeys == .shift {
            if let textView = editingTextView {
                let d = textView.selectedLineLocation
                let count = (d / textView.model.size)
                
                if textView.binder[keyPath: textView.keyPath]
                    .widthCount != count {
                    
                    textView.unmark()
                    TextInputContext.update()
                    
                    textView.binder[keyPath: textView.keyPath]
                        .widthCount = count
                    textView.updateTypesetter()
                    textView.updateSelectedLineLocation()
                }
            }
        } else {
            editingTextView?.insertNewline()
        }
        
        lastInputEventType = .insertNewline
    }
    func insertTab() {
        if inputType != .insert {
            endInputKey()
            inputType = .insert
        }
        editingTextView?.insertTab()
        lastInputEventType = .insertTab
    }
    func deleteBackward() {
        if inputType != .remove {
            endInputKey()
            inputType = .remove
        }
        
        if document.modifierKeys == .shift {
            if let textView = editingTextView {
                if textView.binder[keyPath: textView.keyPath]
                    .widthCount != Typobute.defaultWidthCount {
                    
                    textView.unmark()
                    TextInputContext.update()
                    
                    textView.binder[keyPath: textView.keyPath]
                        .widthCount = Typobute.defaultWidthCount
                    textView.updateTypesetter()
                    textView.updateSelectedLineLocation()
                }
            }
        } else {
            editingTextView?.deleteBackward()
        }
        
        lastInputEventType = .deleteBackward
    }
    func deleteForward() {
        if inputType != .remove {
            endInputKey()
            inputType = .remove
        }
        editingTextView?.deleteForward()
        lastInputEventType = .deleteForward
    }
    func moveLeft() {
        if inputType != .moveCursor {
            endInputKey()
            inputType = .moveCursor
        }
        editingTextView?.moveLeft()
        lastInputEventType = .moveLeft
    }
    func moveRight() {
        if inputType != .moveCursor {
            endInputKey()
            inputType = .moveCursor
        }
        editingTextView?.moveRight()
        lastInputEventType = .moveRight
    }
    func moveUp() {
        if inputType != .moveCursor {
            endInputKey()
            inputType = .moveCursor
        }
        editingTextView?.moveUp()
        lastInputEventType = .moveUp
    }
    func moveDown() {
        if inputType != .moveCursor {
            endInputKey()
            inputType = .moveCursor
        }
        editingTextView?.moveDown()
        lastInputEventType = .moveDown
    }
}

struct ScoreLayout {
    static let noteHeight = 6.0
    static let spectrumAmplitudeWidth = 3.0
}

final class TextView<T: BinderProtocol>: View {
    typealias Model = Text
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    weak var editor: TextEditor?
    private(set) var typesetter: Typesetter
    
    var markedRange: Range<String.Index>?
    var replacedRange: Range<String.Index>?
    var selectedRange: Range<String.Index>?
    var selectedLineLocation = 0.0
    var isUpdatedAudioCache = true
    
    var isFullEdit = false {
        didSet {
            guard isFullEdit != oldValue else { return }
            if let node = timeframeNode.children.first(where: { $0.name == "isFullEdit" }) {
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
    var spectrogramMaxMel: Double?
    var timeNode: Node?, currentVolumeNode: Node?
    var peakVolume = Volume() {
        didSet {
            guard peakVolume != oldValue else { return }
            updateFromPeakVolume()
        }
    }
    func updateFromPeakVolume() {
        guard let node = currentVolumeNode,
              let frame = scoreFrame ?? timeRangeFrame else { return }
        let smp = peakVolume.smp
            .clipped(min: 0, max: Volume.maxSmp, newMin: 0, newMax: 1)
        let y = frame.height * smp
        node.path = Path([Point(), Point(0, y)])
        if abs(peakVolume.amp) < Audio.clippingAmp {
            node.lineType = .color(.background)
        } else {
            node.lineType = .color(.warning)
        }
    }
    
    func set(otherNotesTempo120: [Note]) {
        guard let timeframe = model.timeframe else {
            otherNotes = []
            return
        }
        let octavePitch = timeframe.score?.octavePitch ?? 0
        let tempo = timeframe.tempo
        self.otherNotes = otherNotesTempo120.map {
            var note = $0
            note.apply(toTempo: tempo, fromTempo: 120)
            note.beatRange.start
            -= timeframe.localStartBeat + timeframe.beatRange.start
            note.pitch -= octavePitch
            note.volumeAmp *= (timeframe.volume?.amp ?? 0)
            return note
        }
    }
    private(set) var otherNotes = [Note]() {
        didSet {
            guard otherNotes != oldValue else { return }
            updateWithTimeframe()
        }
    }
    func notesTempo120() -> [Note] {
        guard let timeframe = model.timeframe,
              let score = timeframe.score else { return [] }
        let notes = score.clippedNotes(inBeatRange: timeframe.beatRange,
                                       localStartBeat: timeframe.localStartBeat)
        return notes.map {
            var note = $0
            note.apply(toTempo: 120, fromTempo: timeframe.tempo)
            note.pitch += score.octavePitch
            return note
        }
    }
    
    let timeframeNode = Node()
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        typesetter = binder[keyPath: keyPath].typesetter
        
        node = Node(children: [markedRangeNode, replacedRangeNode,
                               cursorNode, borderNode, timeframeNode, clippingNode],
                    attitude: Attitude(position: binder[keyPath: keyPath].origin),
                    fillType: .color(.content))
        updateLineWidth()
        updatePath()
        
        updateCursor()
        updateWithTimeframe()
        updateSpectrogram()
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
    func updateAudioCache() {
        if !isUpdatedAudioCache,
           let timeframe = model.timeframe, timeframe.score != nil {
            isUpdatedAudioCache = true
            
            // update
        }
    }
    func updateTypesetter() {
        typesetter = model.typesetter
        updatePath()
        
        updateMarkedRange()
        updateCursor()
        updateWithTimeframe()
    }
    func updatePath() {
        //        if let volumeFrame = volumeFrame, let timeRangeFrame = timeRangeFrame {
        //            var path = typesetter.path()
        //            path.pathlines += [Pathline(volumeFrame), Pathline(timeRangeFrame)]
        //            node.path = path
        //        } else {
        node.path = typesetter.path()
        //        }
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
    var frameRate: Int { Keyframe.defaultFrameRate }
    func updateWithTimeframe() {
        if let timeframe = model.timeframe {
            timeframeNode.children = self.timeframeNode(timeframe,
                                                        ratio: nodeRatio,
                                                        frameRate: frameRate,
                                                        textSize: model.size,
                                                        otherNotes: otherNotes,
                                                        from: typesetter)
            
            let timeNode = Node(lineWidth: 3 * nodeRatio,
                                lineType: .color(.content))
            let volumeNode = Node(lineWidth: 1 * nodeRatio,
                                  lineType: .color(.background))
            timeNode.append(child: volumeNode)
            timeframeNode.children.append(timeNode)
            self.timeNode = timeNode
            self.currentVolumeNode = volumeNode
        } else if !timeframeNode.children.isEmpty {
            timeframeNode.children = []
        }
    }
    
    func updateSpectrogram() {
        node.children
            .filter { $0.name == "spectrogram" }
            .forEach { $0.removeFromParent() }
        guard model.timeframe?.isShownSpectrogram ?? false else { return }
        
        guard let timeframe = model.timeframe,
              let sm = timeframe.spectrogram else { return }
        
        let firstX = x(atBeat: timeframe.beatRange.start + (timeframe.score != nil ? 0 : timeframe.localStartBeat))
        let y = (scoreFrame?.maxY ?? timeRangeFrame?.maxY ?? 0) + 0.5 * nodeRatio
        let allBeat = timeframe.score != nil ?
        timeframe.beatRange.length : timeframe.localBeatRange?.length ?? 0
        let allW = width(atBeatDuration: allBeat)
        var nodes = [Node](), maxH = 0.0
        func spNode(width: Int, at xi: Int) -> Node? {
            guard let image = sm.image(width: width, at: xi),
                  let texture = Texture(image: image,
                                        isOpaque: false,
                                        colorSpace: .sRGB) else { return nil }
            let w = allW * Double(width) / Double(sm.frames.count)
            let h = 256 * sm.maxFq / Audio.defaultExportSampleRate
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
        
        self.spectrogramMaxMel = Mel.mel(fromFq: sm.maxFq)
        
        node.append(child: sNode)
    }
    
    func x(atSec sec: Rational) -> Double {
        x(atSec: Double(sec))
    }
    func x(atSec sec: Double) -> Double {
        sec * Sheet.secWidth + Sheet.textPadding.width - model.origin.x
    }
    func x(atBeat beat: Rational) -> Double {
        x(atSec: model.timeframe?.sec(fromBeat: beat) ?? 0)
    }
    
    func width(atSecDuration sec: Rational) -> Double {
        width(atSecDuration: Double(sec))
    }
    func width(atSecDuration sec: Double) -> Double {
        sec * Sheet.secWidth
    }
    func width(atBeatDuration beatDur: Rational) -> Double {
        width(atSecDuration: model.timeframe?.sec(fromBeat: beatDur) ?? 0)
    }
    
    func sec(atX x: Double, interval: Rational) -> Rational {
        Rational(sec(atX: x), intervalScale: interval)
    }
    func sec(atX x: Double) -> Rational {
        sec(atX: x, interval: Rational(1, frameRate))
    }
    func sec(atX x: Double) -> Double {
        (x - Sheet.textPadding.width) / Sheet.secWidth
    }
    
    func beat(atX x: Double, interval: Rational) -> Rational {
        model.timeframe?.beat(fromSec: sec(atX: x),
                              interval: interval) ?? 0
    }
    func beat(atX x: Double) -> Rational {
        beat(atX: x, interval: Rational(1, frameRate))
    }
    
    func pitch(fromHeight h: Double, interval: Rational) -> Rational {
        Rational(h / (ScoreLayout.noteHeight * nodeRatio),
                 intervalScale: interval)
    }
    func pitch(atY y: Double, interval: Rational) -> Rational? {
        guard let score = model.timeframe?.score,
              let f = scoreFrame else { return nil }
        let nh = ScoreLayout.noteHeight * nodeRatio
        let t = (y - f.minY - nh / 2) / nh
        return Rational(t, intervalScale: interval)
        + score.pitchRange.start
    }
    func smoothPitch(atY y: Double) -> Double? {
        guard let score = model.timeframe?.score,
              let f = scoreFrame else { return nil }
        let nh = ScoreLayout.noteHeight * nodeRatio
        let t = (y - f.minY - nh / 2) / nh
        return t + Double(score.pitchRange.start)
    }
    func height(fromPitch pitch: Rational) -> Double {
        height(fromPitch: pitch, noteHeight: ScoreLayout.noteHeight * nodeRatio)
    }
    func height(fromPitch pitch: Rational, noteHeight nh: Double) -> Double {
        Double(pitch) * nh
    }
    func height(fromPitch pitch: Double, noteHeight nh: Double) -> Double {
        pitch * nh
    }
    
    var nodeRatio: Double { model.size / Font.defaultSize }
    
    func timeframeNode(_ timeframe: Timeframe, ratio: Double,
                       frameRate: Int, textSize: Double,
                       otherNotes: [Note],
                       from typesetter: Typesetter,
                       padding: Double = 7) -> [Node] {
        let lw = 1.0 * ratio
        let sBeat = max(timeframe.beatRange.start, -10000),
            eBeat = min(timeframe.beatRange.end, 10000)
        guard sBeat <= eBeat else { return [] }
        let sx = self.x(atBeat: sBeat)
        let ex = self.x(atBeat: eBeat)
        let lastB = typesetter.firstReturnBounds ?? Rect()
        let y = lastB.minY
        let nh = ScoreLayout.noteHeight * ratio
        let knobW = 2 * ratio, knobH = 12 * ratio
        let vy = (typesetter.lastBounds ?? Rect()).midY
        let knobRadius = 2 * ratio
        let lp = typesetter.lastBounds?.maxXMidYPoint ?? Point()
        let vw = lp.x + padding * ratio
        
        var boxNodes = [Node]()
        var textNodes = [Node]()
        var contentPathlines = [Pathline]()
        var subBorderPathlines = [Pathline]()
        var fullEditBorderPathlines = [Pathline]()
        var borderPathlines = [Pathline]()
        var contentRatioLinePathlines = [Pathline]()
        var noteLineNodes = [Node]()
        var noteOctaveLinePathlines = [Pathline]()
        var noteChordLinePathlines = [Pathline]()
        var noteKnobPathlines = [Pathline]()
        
        func timeStringFrom(time: Rational,
                            frameRate: Int) -> String {
            if time >= 60 {
                let c = Int(time * Rational(frameRate))
                let s = c / frameRate
                let minutes = s / 60
                let sec = s - minutes * 60
                let frame = c - s * frameRate
                let minutesStr = String(format: "%d", minutes)
                let secStr = String(format: "%02d", sec)
                let frameStr = String(format: "%02d", frame)
                return minutesStr + ":" + secStr + "." + frameStr
            } else {
                let c = Int(time * Rational(frameRate))
                let s = c / frameRate
                let sec = s
                let frame = c - s * frameRate
                let secStr = String(format: "%d", sec)
                let frameStr = String(format: "%02d", frame)
                return secStr + "." + frameStr
            }
        }
        
        if let localBeatRange = timeframe.localBeatRange {
            if localBeatRange.start < 0 {
                
                let beat = -min(localBeatRange.start, 0)
                - min(timeframe.beatRange.start, 0)
                let timeText = Text(string: timeStringFrom(time: beat, frameRate: frameRate),
                                    size: textSize * Font.smallSize / Font.defaultSize)
                let h = timeframe.score != nil ?
                self.height(fromPitch: timeframe.score!.pitchRange.length,
                            noteHeight: nh) :
                0
                let timeP = Point(sx + 1, y + nh + h)
                textNodes.append(Node(attitude: Attitude(position: timeP),
                                      path: Path(timeText.typesetter,
                                                 isPolygon: false),
                                      fillType: .color(.content)))
            } else if localBeatRange.start > 0 {
                let ssx = x(atBeat: localBeatRange.start + timeframe.beatRange.start)
                contentPathlines.append(Pathline(Rect(x: ssx - ratio / 4,
                                                      y: y - 3 * ratio,
                                                      width: ratio / 2,
                                                      height: 6 * ratio)))
            }
        }
        
        if let localBeatRange = timeframe.localBeatRange {
            if timeframe.beatRange.start + localBeatRange.end
                > timeframe.beatRange.end {
                
                let beat = timeframe.beatRange.length - localBeatRange.start
                
                let timeText = Text(string: timeStringFrom(time: beat, frameRate: frameRate),
                                    size: textSize * Font.smallSize / Font.defaultSize)
                let timeFrame = timeText.frame ?? Rect()
                let h = timeframe.score != nil ?
                self.height(fromPitch: timeframe.score!.pitchRange.length,
                            noteHeight: nh) :
                0
                let timeP = Point(ex - timeFrame.width - 2, y + nh + h)
                textNodes.append(Node(attitude: Attitude(position: timeP),
                                      path: Path(timeText.typesetter,
                                                 isPolygon: false),
                                      fillType: .color(.content)))
            } else if localBeatRange.end < timeframe.beatRange.length {
                let ssx = x(atBeat: localBeatRange.end + timeframe.beatRange.start)
                contentPathlines.append(Pathline(Rect(x: ssx - ratio / 4,
                                                      y: y - 3 * ratio,
                                                      width: ratio / 2,
                                                      height: 6 * ratio)))
            }
        }
        
        if let content = timeframe.content {
            if !content.volumeValues.isEmpty {
                let sSec = timeframe.sec(fromBeat: max(-timeframe.localStartBeat, 0))
                let msSec = timeframe.sec(fromBeat: timeframe.localStartBeat)
                let csSec = timeframe.sec(fromBeat: timeframe.beatRange.start)
                let beatDur = Timeframe.beat(fromSec: content.secDuration,
                                             tempo: timeframe.tempo,
                                             beatRate: Keyframe.defaultFrameRate,
                                             rounded: .up)
                let eSec = timeframe
                    .sec(fromBeat: min(timeframe.beatRange.end - (timeframe.localStartBeat + timeframe.beatRange.start),
                                       beatDur))
                let si = Int((sSec * Content.volumeFrameRate).rounded())
                    .clipped(min: 0, max: content.volumeValues.count - 1)
                let msi = Int((msSec * Content.volumeFrameRate).rounded())
                let ei = Int((eSec * Content.volumeFrameRate).rounded())
                    .clipped(min: 0, max: content.volumeValues.count - 1)
                let vt = content.volume.smp
                    .clipped(min: 0, max: Volume.maxSmp,
                             newMin: lw / nh, newMax: 1)
                if si < ei {
                    let line = Line(controls: (si ... ei).map { i in
                        let sec = Rational(i + msi) / Content.volumeFrameRate + csSec
                        return .init(point: .init(x(atSec: sec), y),
                                     pressure: content.volumeValues[i] * vt)
                    })
                    
                    let pan = timeframe.score?.pan ?? 0
                    let color = Self.panColor(pan: pan,
                                              brightness: 0.25)
                    noteLineNodes += [Node(path: .init(line),
                                           lineWidth: nh,
                                           lineType: .color(color))]
                }
            }
            
            if let image = content.image,
               let texture = Texture(image: image, isOpaque: false,
                                     colorSpace: .sRGB) {
                var parent: Node?
                node.allParents { node, stop in
                    if node.bounds != nil {
                        parent = node
                        stop = true
                    }
                }
                
                let parentSize: Size =
                if let parent, let pb = parent.bounds {
                    pb.size
                } else {
                    Sheet.defaultBounds.size
                }
                
                let size = (image.size / 2)
                    .snapped(parentSize * 0.95)
                * textSize / Font.defaultSize
                boxNodes.append(Node(name: "content",
                                     path: Path(Rect(size: size)),
                                     fillType: .texture(texture)))
            }
        }
        
        contentPathlines.append(.init(Rect(x: sx - ratio, y: y - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: ex - ratio, y: y - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: sx + ratio, y: y - lw / 2,
                                           width: ex - sx - ratio * 2,
                                           height: lw)))
        
        let secRange = timeframe.secRange
        for sec in Int(secRange.start.rounded(.up)) ..< Int(secRange.end.rounded(.up)) {
            let sec = Rational(sec)
            let secX = x(atSec: sec)
            contentPathlines.append(.init(Rect(x: secX - lw / 2,
                                               y: y - ratio * 2,
                                               width: lw,
                                               height: ratio * 4)))
        }
        
        let h = if let score = timeframe.score {
            self.height(fromPitch: score.pitchRange.length,
                                noteHeight: nh)
        } else {
            knobH / 2 + knobW
        }
        
        let roundedSBeat = timeframe.beatRange.start.rounded(.down)
        let deltaBeat = Rational(1, 48)
        let beatR1 = Rational(1, 4), beatR2 = Rational(1, 12)
        let beat1 = Rational(2), beat2 = Rational(4)
        var cBeat = roundedSBeat
        while cBeat <= timeframe.beatRange.end {
            if cBeat >= timeframe.beatRange.start {
                let olw: Double = if cBeat % beat2 == 0 {
                    2
                } else if cBeat % beat1 == 0 {
                    1.5
                } else if cBeat % 1 == 0 {
                    1
                } else if cBeat % beatR1 == 0 {
                    0.5
                } else if cBeat % beatR2 == 0 {
                    0.25
                } else {
                    0.125
                }
                let lw = olw * ratio
                
                let beatX = x(atBeat: cBeat)
                
                let rect = Rect(x: beatX - lw / 2,
                                y: y - knobH / 2 - knobW,
                                width: lw,
                                height: h + knobH / 2 + knobW)
                if cBeat % 1 == 0 {
                    subBorderPathlines.append(Pathline(rect))
                } else if lw == 0.125 {
                    fullEditBorderPathlines.append(Pathline(rect))
                } else {
                    borderPathlines.append(Pathline(rect))
                }
            }
            cBeat += deltaBeat
        }
        
        if let score = timeframe.score {
            let beat = timeframe.beatRange.start
            let notes = score.sortedNotes.map {
                var note = $0
                note.volumeAmp *= score.volumeAmp
                note.tone = score.tone//
                note.pan = score.pan//
                note.beatRange.start += beat + timeframe.localStartBeat
                return note
            }
            let otherNotes = otherNotes.map {
                var note = $0
                note.beatRange.start += beat + timeframe.localStartBeat
                return note
            }
            
            let pitchRange = score.pitchRange
            if let range = Range<Int>(pitchRange) {
                var isAppendOctaveText = false
                for pitch in range {
                    for k in 0 ..< 12 {
                        let pitch = Rational(pitch - 1) + Rational(k, 12)
                        let sh = self.height(fromPitch: pitch - pitchRange.start,
                                             noteHeight: nh)
                        
                        fullEditBorderPathlines.append(.init(Rect(x: sx, y: y + sh + nh / 2 - lw * 0.125 / 2,
                                                                  width: ex - sx, height: lw * 0.125)))
                    }
                    
                    let sh = self.height(fromPitch: Rational(pitch) - pitchRange.start,
                                         noteHeight: nh)
                    let hlw = lw / 2
                    borderPathlines.append(.init(Rect(x: sx, y: y + sh + nh / 2 - hlw / 2,
                                                      width: ex - sx, height: hlw)))
                    
                    let mod = (pitch + Int(score.scaleKey)).mod(12)
                    if mod == 3 || mod == 6 || mod == 9 {
                        let sh = self.height(fromPitch: Rational(pitch) - pitchRange.start,
                                             noteHeight: nh)
                        let lw = mod == 6 ? lw : lw / 2
                        contentPathlines.append(Pathline(Rect(x: sx - ratio * 3,
                                                              y: y + sh + nh / 2 - lw / 2,
                                                              width: ratio * 3,
                                                              height: lw)))
                    } else if mod == 0 {
                        let sh = self.height(fromPitch: Rational(pitch) - pitchRange.start,
                                             noteHeight: nh)
                        
                        let plw = lw * 2
                        contentPathlines.append(Pathline(Rect(x: sx - ratio * 3,
                                                              y: y + sh + nh / 2 - plw / 2,
                                                              width: ratio * 3,
                                                              height: plw)))
                        
                        let octaveText = Text(string: "\(Int(Rational(pitch) + score.octavePitch) / 12)",
                                                 size: Font.smallSize * ratio)
                        textNodes.append(Node(attitude: Attitude(position: Point(sx - ratio * 3 - (octaveText.frame?.width ?? 0) - ratio, y + sh + nh / 2)),
                                              path: octaveText.typesetter.path(),
                                              fillType: .color(.content)))
                        isAppendOctaveText = true
                    }
                }
                if !isAppendOctaveText {
                    let pitch = Rational((range.lowerBound + range.upperBound) / 2)
                    let movedPitch = pitch + score.octavePitch
                    let nPitch = Pitch(value: movedPitch)
                    let octaveText = Text(string: "\(nPitch.octave).\(String(format: "%02d", Int(nPitch.unison)))",
                                          size: Font.smallSize * 0.75 * ratio)
                    
                    let sh = self.height(fromPitch: pitch - pitchRange.start,
                                         noteHeight: nh)
                    textNodes.append(Node(attitude: Attitude(position: Point(sx - ratio * 2 - (octaveText.frame?.width ?? 0) - ratio, y + sh + nh / 2)),
                                          path: octaveText.typesetter.path(),
                                          fillType: .color(.content)))
                }
                
                let unisonsSet = Set((otherNotes + notes).compactMap { Int($0.pitch.rounded().mod(12)) })
                for pitch in range {
                    guard unisonsSet
                        .contains(pitch.mod(12)) else { continue }
                    let sh = self.height(fromPitch: Rational(pitch) - pitchRange.start,
                                         noteHeight: nh)
                    subBorderPathlines.append(Pathline(Rect(x: sx, y: y + sh + nh / 2 - lw / 2,
                                                            width: ex - sx, height: lw)))
                }
            }
            
            var brps = [(Range<Rational>, Int)]()
            let preBeat = max(beat, sBeat)
            let nextBeat = min(beat + timeframe.beatRange.length, eBeat)
            
            func appendOctaves(_ note: Note, isChord: Bool) {
                var nNote = note
                while true {
                    nNote.pitch -= 12
                    guard nNote.pitch > 0 && nNote.pitch < pitchRange.length else { break }
                    
                    let (aNoteLinePathlines, _, _)
                    = notePathlines(from: nNote, y: y + nh / 2,
                                    preFq: nil, nextFq: nil, tempo: timeframe.tempo)
                    if isChord {
                        noteChordLinePathlines += aNoteLinePathlines
                    } else {
                        noteOctaveLinePathlines += aNoteLinePathlines
                    }
                }
                
                nNote = note
                var count = 1
                while true {
                    nNote.pitch += 12
                    count += 1
                    guard nNote.pitch > 0 && nNote.pitch < pitchRange.length else { break }
                    
                    let (aNoteLinePathlines, _, _)
                    = notePathlines(from: nNote, y: y + nh / 2,
                                    preFq: nil, nextFq: nil, tempo: timeframe.tempo)
                    if isChord {
                        noteChordLinePathlines += aNoteLinePathlines
                    } else {
                        noteOctaveLinePathlines += aNoteLinePathlines
                    }
                }
            }
            let nNotes = notes
            for (i, note) in nNotes.enumerated() {
                guard pitchRange.contains(note.pitch) else { continue }
                var beatRange = note.beatRange
                
                guard beatRange.end > preBeat
                        && beatRange.start < nextBeat
                        && note.volumeAmp >= Volume.minAmp
                        && note.volumeAmp <= Volume.maxAmp else { continue }
                
                if beatRange.start < preBeat {
                    beatRange.length -= preBeat - beatRange.start
                    beatRange.start = preBeat
                }
                if beatRange.end > nextBeat {
                    beatRange.end = nextBeat
                }
                
                var note = nNotes[i]
                note.pitch -= pitchRange.start
                
                let isChord = note.isChord
                if isChord {
                    brps.append((beatRange, note.roundedPitch))
                }
                appendOctaves(note, isChord: isChord)
                
                let (preFq, nextFq) = pitbendPreNext(notes: nNotes, at: i)
                let (aNoteLinePathlines, aNoteKnobPathlines, lyricPath)
                = notePathlines(from: note, y: y + nh / 2,
                                preFq: preFq, nextFq: nextFq, tempo: timeframe.tempo)
                
                let pan = timeframe.score?.pan ?? 0
                noteLineNodes += aNoteLinePathlines.enumerated().map {
                    let color = Self.panColor(pan: pan,
                                              brightness: 0.25)
                    return Node(path: Path([$0.element]),
                                lineWidth: nh,
                                lineType: .color(color))
                }
                
                noteKnobPathlines += aNoteKnobPathlines
                if let lyricPath {
                    textNodes.append(.init(path: lyricPath, fillType: .color(.content)))
                }
            }
            
            for note in otherNotes {
                guard pitchRange.contains(note.pitch) else { continue }
                
                let isChord = note.isChord
                var note = note
                note.pitch -= pitchRange.start
                
                let (aNoteLinePathlines, _, _)
                = notePathlines(from: note, y: y + nh / 2,
                                preFq: nil, nextFq: nil, tempo: timeframe.tempo)
                if isChord {
                    noteChordLinePathlines += aNoteLinePathlines
                } else {
                    noteOctaveLinePathlines += aNoteLinePathlines
                }
                
                appendOctaves(note, isChord: isChord)
            }
            
            let trs = Chord.splitedTimeRanges(timeRanges: brps)
            for (tr, pitchs) in trs {
                let ps = pitchs.sorted()
                guard let chord = Chord(pitchs: ps),
                      chord.typers.count <= 8 else { continue }
                
                var typersDic = [Int: [(typer: Chord.ChordTyper,
                                        typerIndex: Int,
                                        isInvrsion: Bool)]]()
                for (ti, typer) in chord.typers.sorted(by: { $0.index < $1.index }).enumerated() {
                    let inversionUnisons = typer.inversionUnisons
                    var j = typer.index
                    let fp = ps[j]
                    for i in 0 ..< typer.type.unisons.count {
                        guard j < ps.count else { break }
                        if typersDic[j] != nil {
                            typersDic[j]?.append((typer,
                                                  ti,
                                                  typer.inversion == i))
                        } else {
                            typersDic[j] = [(typer,
                                             ti,
                                             typer.inversion == i)]
                        }
                        while j + 1 < ps.count,
                              !inversionUnisons.contains(ps[j + 1] - fp) {
                            j += 1
                        }
                        j += 1
                    }
                }
                
                for (i, typers) in typersDic {
                    let pitch = Rational(ps[i])
                    let nsx = x(atBeat: tr.start), nex = x(atBeat: tr.end)
                    let sh = self.height(fromPitch: pitch,
                                         noteHeight: nh)
                    let d = 1.0 * ratio
                    let nw = 4.0 * Double(chord.typers.count - 1) * ratio
                    func appendChordLine(at ti: Int,
                                         isInversion: Bool,
                                         _ typer: Chord.ChordTyper) {
                        let tlw = 0.5 * ratio
                        let lw =
                        switch typer.type {
                        case .octave: 7 * tlw
                        case .major, .power: 5 * tlw
                        case .suspended: 3 * tlw
                        case .minor: 7 * tlw
                        case .augmented: 5 * tlw
                        case .flatfive: 3 * tlw
                        case .diminish, .tritone: 1 * tlw
                        }
                        
                        let x = -nw / 2 + 4.0 * Double(ti) * ratio
                        let fx = (nex + nsx) / 2 + x - lw / 2
                        let fy0 = y + sh + nh / 2 + ratio, fy1 = y + sh + nh / 2 - ratio - d
                        
                        let minorCount =
                        switch typer.type {
                        case .minor: 4
                        case .augmented: 3
                        case .flatfive: 2
                        case .diminish: 1
                        case .tritone: 1
                        default: 0
                        }
                        
                        if minorCount > 0 {
                            for i in 0 ..< minorCount {
                                let id = Double(i) * 2 * tlw
                                contentPathlines.append(Pathline(Rect(x: fx + id, y: fy0,
                                                                      width: tlw, height: d - tlw)))
                                contentPathlines.append(Pathline(Rect(x: fx, y: fy0 + d - tlw,
                                                                      width: lw, height: tlw)))
                                
                                contentPathlines.append(Pathline(Rect(x: fx + id, y: fy1 + tlw,
                                                                      width: tlw, height: d - tlw)))
                                contentPathlines.append(Pathline(Rect(x: fx, y: fy1,
                                                                      width: lw, height: tlw)))
                            }
                        } else {
                            contentPathlines.append(Pathline(Rect(x: fx, y: fy0,
                                                                  width: lw, height: d)))
                            contentPathlines.append(Pathline(Rect(x: fx, y: fy1,
                                                                  width: lw, height: d)))
                        }
                        if isInversion {
                            let ilw = 1 * ratio
                            contentPathlines.append(Pathline(Rect(x: fx - ilw, y: fy0 + ilw,
                                                                  width: lw + 2 * ilw, height: ilw)))
                            contentPathlines.append(Pathline(Rect(x: fx - ilw, y: fy1 - ilw,
                                                                  width: lw + 2 * ilw, height: ilw)))
                        }
                    }
                    for (_, typerTuple) in typers.enumerated() {
                        appendChordLine(at: typerTuple.typerIndex,
                                        isInversion: typerTuple.isInvrsion,
                                        typerTuple.typer)
                    }
                }
            }
            
            var vx = vw + ratio * padding
            
            let tone = score.tone
            
            let overtoneW = 6.0 * ratio
            let overtoneDW = 6.0 * ratio
            let oh = 14 * ratio
            let hoh = oh / 2
            
            boxNodes.append(Node(name: "overtone",
                                 path: Path(Rect(x: vx,
                                                 y: vy - hoh,
                                                 width: overtoneDW * 6,
                                                 height: oh).outset(by: 4 * ratio))))
            
            contentRatioLinePathlines.append(.init([Point(vx + overtoneW / 2 - overtoneDW / 2, vy - hoh + ratio),
                                                    Point(vx + overtoneW / 2 + overtoneDW * 4 + overtoneDW / 2, vy - hoh + ratio)]))
            
            contentRatioLinePathlines.append(.init([Point(vx + overtoneW / 2, vy - hoh + ratio),
                                                    Point(vx + overtoneW / 2, vy + hoh - ratio)]))
            
            vx += overtoneDW
            
            let evenP = Point(vx + overtoneW / 2,
                              vy - hoh + ratio + (oh - 2 * ratio) * tone.overtone.evenScale)
            contentRatioLinePathlines.append(.init([Point(vx + overtoneW / 2,
                                                          vy - hoh + ratio),
                                                    evenP]))
            contentPathlines.append(.init(circleRadius: 2 * ratio,
                                          position: evenP))
            
            vx += overtoneDW
            
            let oddP = Point(vx + overtoneW / 2,
                             vy - hoh + ratio + (oh - 2 * ratio) * tone.overtone.oddScale)
            contentRatioLinePathlines.append(.init([Point(vx + overtoneW / 2,
                                                          vy - hoh + ratio),
                                                    oddP]))
            contentPathlines.append(.init(circleRadius: 2 * ratio,
                                          position: oddP))
            
            vx += overtoneDW
            
            let evenP2 = Point(vx + overtoneW / 2,
                               vy - hoh + ratio + (oh - 2 * ratio) * tone.overtone.evenScale)
            contentRatioLinePathlines.append(.init([Point(vx + overtoneW / 2,
                                                          vy - hoh + ratio),
                                                    evenP2]))
            
            vx += overtoneDW
            
            let oddP2 = Point(vx + overtoneW / 2,
                              vy - hoh + ratio + (oh - 2 * ratio) * tone.overtone.oddScale)
            contentRatioLinePathlines.append(.init([Point(vx + overtoneW / 2,
                                                          vy - hoh + ratio),
                                                    oddP2]))
            vx += overtoneDW + ratio * padding
            
            let sf = tone.sourceFilter

            let fh = 12 * ratio
            let hfh = fh / 2
            let octaveCount = 7.0
            let spW = octaveCount * 20 * ratio
            let spy = vy - hfh
            let sffp = Point(vx, spy)
            let sflp = Point(vx + spW, spy)
            
            func sourceFilterX(atFq fq: Double) -> Double {
                let t = Mel.mel(fromFq: fq)
                    .clipped(min: 0, max: 4000, newMin: 0, newMax: 1)
                return vx + spW * t
            }
            func sourceFilterY(atSmp smp: Double) -> Double {
                vy - hfh + smp * fh
            }
            func sourceFilterP(at p: Point) -> Point {
                .init(sourceFilterX(atFq: p.x),
                      sourceFilterY(atSmp: p.y))
            }
            
            borderPathlines += (1 ... 10).map {
                .init(Rect(x: sourceFilterX(atFq: Pitch(octave: $0, step: .c).fq),
                           y: sffp.y,
                           width: 0.5 * ratio, height: fh))
            }
            
            var lastP = Point()
            var noisePs = [Point](capacity: sf.fqSmps.count)
            var ps = [Point](capacity: sf.fqSmps.count)
            for (i, fqSmp) in sf.fqSmps.enumerated() {
                let noiseSmp = sf.noiseFqSmps[i]
                
                let editNoiseP = sourceFilterP(at: sf[i, .editFqNoiseSmp])
                let noiseFP = Point(editNoiseP.x, spy)
                let noiseP = sourceFilterP(at: noiseSmp)
//                contentRatioLinePathlines.append(.init([noiseFP, noiseP],
//                                                       isClosed: false))
                contentPathlines.append(Pathline(circleRadius: knobRadius / 2,
                                                 position: editNoiseP))
                
                let p = sourceFilterP(at: fqSmp)
                contentPathlines.append(Pathline(circleRadius: knobRadius * 0.75,
                                                 position: p))
                
                if i == 0 {
                    noisePs.append(Point(sffp.x, noiseP.y))
                    ps.append(Point(sffp.x, p.y))
                }
                
                noisePs.append(noiseP)
                ps.append(p)
                
                lastP = p
                
                if i == sf.fqSmps.count - 1 {
                    noisePs.append(Point(sflp.x, noiseP.y))
                    ps.append(Point(sflp.x, p.y))
                }
            }
            if !ps.isEmpty && !noisePs.isEmpty {
//                let nps = [sffp, sflp] + noisePs.reversed()
//                borderPathlines += [.init(nps, isClosed: false)]
                
                contentRatioLinePathlines += [.init(noisePs, isClosed: false),
                                              .init(ps, isClosed: false)]
            }
            
            contentRatioLinePathlines += [.init([sffp, sflp],
                                                isClosed: false)]
            
            contentPathlines.append(Pathline(circleRadius: knobRadius,
                                             position: Point(lastP.x + ratio * 2, sflp.y)))
            
            boxNodes.append(Node(name: "sourceFilter",
                                 path: Path(Rect(x: vx,
                                                 y: vy - hfh,
                                                 width: spW,
                                                 height: fh).outset(by: 4 * ratio))))
            
            contentPathlines.append(Pathline(Rect(x: sx - ratio / 2, y: y,
                                                  width: ratio, height: h + ratio / 2)))
            contentPathlines.append(Pathline(Rect(x: ex - ratio / 2, y: y,
                                                  width: ratio, height: h + ratio / 2)))
            contentPathlines.append(Pathline(Rect(x: sx, y: y + h - ratio / 2,
                                                  width: ex - sx, height: ratio)))
        }
        
        let tempoBeat = timeframe.beatRange.start.rounded(.down) + 1
        if tempoBeat < timeframe.beatRange.end {
            let np = Point(x(atBeat: tempoBeat), y + h)
            contentPathlines.append(Pathline(circleRadius: knobRadius,
                                             position: np))
        }
        
        if timeframe.isAudio {
            let sprBeat = timeframe.beatRange.start.rounded(.down) + Rational(1, 2)
            if sprBeat < timeframe.beatRange.end {
                let sprH = 5 * ratio
                let sprKnobW = knobH, sprKbobH = knobW
                let np = Point(x(atBeat: sprBeat), y + h)
                contentPathlines.append(Pathline(Rect(x: np.x - ratio / 2,
                                                      y: np.y,
                                                      width: ratio,
                                                      height: sprH)))
                if timeframe.isShownSpectrogram {
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
                
                boxNodes.append(Node(name: "isShownSpectrogram",
                                     path: Path(Rect(x: np.x, y: np.y,
                                                     width: sprKnobW, height: sprH))))
            }
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
        if !noteOctaveLinePathlines.isEmpty {
            nodes += noteOctaveLinePathlines.enumerated().map {
                return Node(path: Path([$0.element]),
                            lineWidth: nh,
                            lineType: .color(.border))
            }
        }
        if !noteChordLinePathlines.isEmpty {
            nodes += noteChordLinePathlines.enumerated().map {
                return Node(path: Path([$0.element]),
                            lineWidth: nh,
                            lineType: .color(.subBorder))
            }
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
        if !contentRatioLinePathlines.isEmpty {
            nodes.append(Node(path: Path(contentRatioLinePathlines),
                              lineWidth: ratio,
                              lineType: .color(.content)))
        }
        if !noteKnobPathlines.isEmpty {
            nodes.append(Node(path: Path(noteKnobPathlines),
                              fillType: .color(.background)))
        }
        nodes += boxNodes
        nodes += textNodes
        
        return nodes
    }
    
    static func panColor(pan: Double, brightness l: Double) -> Color {
        pan == 0 ?
        Color(red: l, green: l, blue: l) :
            (pan < 0 ?
             Color(red: -pan * Spectrogram.editRedRatio * (1 - l) + l, green: l, blue: l) :
                Color(red: l, green: pan * Spectrogram.editGreenRatio * (1 - l) + l, blue: l))
    }
    
    func updateTimeNode(atSec sec: Rational) {
        if let timeNode = timeNode,
           let frame = scoreFrame ?? timeRangeFrame {
            
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
    
    var timeframeFrame: Rect? {
        timeRangeFrame?.union(scoreFrame).union(contentFrame)
    }
    
    func containsTimeRange(_ p : Point) -> Bool {
        timeRangeFrame?.contains(p) ?? false
    }
    var timeRangeFrame: Rect? {
        guard let timeframe = model.timeframe else { return nil }
        let sx = x(atBeat: timeframe.beatRange.start)
        let ex = x(atBeat: timeframe.beatRange.end)
        let lastB = typesetter.firstReturnBounds ?? Rect()
        let y = lastB.minY
        let ratio = nodeRatio
        return Rect(x: sx, y: y - 6 * ratio,
                    width: ex - sx, height: 12 * ratio).outset(by: 3 * ratio)
    }
    var transformedTimeRangeFrame: Rect? {
        if var f = timeRangeFrame {
            f.origin.y += model.origin.y
            return f
        } else {
            return nil
        }
    }
    
    var isShownSpectrogram: Bool {
        get {
            model.timeframe?.isShownSpectrogram ?? false
        }
        set {
            let oldValue = model.timeframe?.isShownSpectrogram ?? false
            model.timeframe?.isShownSpectrogram = newValue
            if newValue != oldValue {
                updateSpectrogram()
            }
        }
    }
    func containsIsShownSpectrogram(_ p: Point) -> Bool {
        paddingIsShownSpectrogramFrame?.contains(p) ?? false
    }
    var isShownSpectrogramFrame: Rect? {
        guard model.timeframe?.isShownSpectrogram != nil else { return nil }
        if let node = timeframeNode.children.first(where: { $0.name == "isShownSpectrogram" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    var paddingIsShownSpectrogramFrame: Rect? {
        isShownSpectrogramFrame?.outset(by: 3 * nodeRatio)
    }
    
    func containsOctave(_ p: Point) -> Bool {
        octaveFrame?.contains(p) ?? false
    }
    var octaveFrame: Rect? {
        guard model.timeframe?.score != nil else { return nil }
        if let node = timeframeNode.children.first(where: { $0.name == "octave" }) {
            return node.transformedBounds?.outset(by: 5 * nodeRatio)
        } else {
            return nil
        }
    }
    
    func containsAttack(_ p: Point) -> Bool {
        guard isFullEdit, let timeframe = model.timeframe, let score = timeframe.score,
              let noteI = noteIndex(at: p, maxDistance: 5) else { return false }
        
        let nf = noteFrame(from: score.notes[noteI], score, timeframe)
        return p.x < nf.minX + nf.width * 0.1
    }
    var attackFrame: Rect? {
        guard model.timeframe?.score != nil else { return nil }
        if let node = timeframeNode.children.first(where: { $0.name == "attack" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    var paddingAttackFrame: Rect? {
        guard let f = attackFrame else { return nil }
        let d = 5 * nodeRatio
        return Rect(x: f.minX - d,
                    y: f.minY - d,
                    width: f.width + d,
                    height: f.height + d * 2)
    }
    
    func containsDecayAndSustain(_ p: Point) -> Bool {
        guard isFullEdit, let timeframe = model.timeframe, let score = timeframe.score,
              let noteI = noteIndex(at: p, maxDistance: 5) else { return false }
        
        let nf = noteFrame(from: score.notes[noteI], score, timeframe)
        return p.y > nf.minY + nf.height * 0.9
    }
    var decayAndSustainFrame: Rect? {
        guard model.timeframe?.score != nil else { return nil }
        if let node = timeframeNode.children.first(where: { $0.name == "decayAndSustain" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    var paddingDecayAndSustainFrame: Rect? {
        guard let f = decayAndSustainFrame else { return nil }
        let d = 5 * nodeRatio
        return Rect(x: f.minX,
                    y: f.minY - d,
                    width: f.width,
                    height: f.height + d * 2)
    }
    
    func containsRelease(_ p: Point) -> Bool {
        guard isFullEdit, let timeframe = model.timeframe, let score = timeframe.score,
              let noteI = noteIndex(at: p, maxDistance: 5) else { return false }
        
        let nf = noteFrame(from: score.notes[noteI], score, timeframe)
        return p.x > nf.minX + nf.width * 0.9
    }
    var releaseFrame: Rect? {
        guard model.timeframe?.score != nil else { return nil }
        if let node = timeframeNode.children.first(where: { $0.name == "release" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    var paddingReleaseFrame: Rect? {
        guard let f = releaseFrame else { return nil }
        let d = 5 * nodeRatio
        return Rect(x: f.minX,
                    y: f.minY - d,
                    width: f.width + d,
                    height: f.height + d * 2)
    }
    
    func overtonePosition(at type: OvertoneType) -> Point? {
        guard let f = overtoneFrame,
              let tone = model.timeframe?.score?.tone else { return nil }
        let ratio = nodeRatio
        let vx = f.minX + 4 * ratio, vy = f.minY + 4 * ratio
        let overtoneW = 6.0 * ratio
        let overtoneDW = 6.0 * ratio
        let oh = 14 * ratio
        return switch type {
        case .evenScale:
            .init(vx + overtoneDW + overtoneW / 2,
                  vy + ratio + (oh - 2 * ratio) * tone.overtone.evenScale)
        case .oddScale:
            .init(vx + overtoneDW * 2 + overtoneW / 2,
                  vy + ratio + (oh - 2 * ratio) * tone.overtone.oddScale)
        }
    }
    func overtoneType(at p: Point) -> OvertoneType? {
        guard let f = overtoneFrame, f.contains(p) else { return nil }
        var minDS = Double.infinity, minType: OvertoneType?
        for type in OvertoneType.allCases {
            guard let op = overtonePosition(at: type) else { continue }
            let ds = op.distanceSquared(p)
            if ds < minDS {
                minDS = ds
                minType = type
            }
        }
        return minType
    }
    func containsOvertone(_ p: Point) -> Bool {
        overtoneFrame?.contains(p) ?? false
    }
    var overtoneFrame: Rect? {
        guard model.timeframe?.score != nil else { return nil }
        if let node = timeframeNode.children.first(where: { $0.name == "overtone" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    
    func sourceFilterFq(atX x: Double,
                       octaveCount: Double = 7,
                       octaveWidth: Double = 20) -> Double? {
        guard let f = sourceFilterFrame else { return nil }
        let ratio = nodeRatio
        let spx = f.minX + 4 * ratio
        let spW = octaveCount * octaveWidth * ratio
        let mel = ((x - spx) / spW).clipped(min: 0, max: 1,
                                            newMin: 0, newMax: 4000)
        return Mel.fq(fromMel: mel)
    }
    func sourceFilterX(atFq fq: Double,
                      octaveCount: Double = 7,
                      octaveWidth: Double = 20) -> Double? {
        guard let f = sourceFilterFrame else { return nil }
        let ratio = nodeRatio
        let spx = f.minX + 4 * ratio
        let spW = octaveCount * octaveWidth * ratio
        let t = Mel.mel(fromFq: fq)
            .clipped(min: 0, max: 4000, newMin: 0, newMax: 1)
        return spx + spW * t
    }
    func sourceFilterIndex(atX x: Double) -> Int? {
        guard let sourceFilter = model.timeframe?.score?.tone.sourceFilter,
              let fq = sourceFilterFq(atX: x) else { return nil }
        for (i, fqSmp) in sourceFilter.fqSmps.enumerated().reversed() {
            if fq >= fqSmp.x {
                return i
            }
        }
        return nil
    }
    func sourceFilterY(atSmp smp: Double, height: Double = 12) -> Double? {
        guard let f = sourceFilterFrame else { return nil }
        let ratio = nodeRatio
        let spy = f.minY + 4 * ratio
        let fh = height * ratio
        return spy + smp * fh
    }
    func sourceFilterSmp(atY y: Double, height: Double = 12) -> Double? {
        guard let f = sourceFilterFrame else { return nil }
        let ratio = nodeRatio
        let spy = f.minY + 4 * ratio
        let fh = height * ratio
        return (y - spy) / fh
    }
    
    func sourceFilterType(at p: Point,
                       maxDistance: Double) -> (i: Int, type: SourceFilterType, isLast: Bool)? {
        guard let f = sourceFilterFrame, f.contains(p),
              let score = model.timeframe?.score else { return nil }
        
        let ratio = nodeRatio
        let spy = f.minY + 4 * ratio
        
        func sourceFilterP(at p: Point) -> Point {
            .init(sourceFilterX(atFq: p.x)!,
                  sourceFilterY(atSmp: p.y)!)
        }
        
        var ps = [(p: Point, i: Int, type: SourceFilterType)](), lastP = Point()
        let sf = score.tone.sourceFilter
        for (i, fqSmp) in sf.fqSmps.enumerated() {
            let enp = sourceFilterP(at: sf[i, .editFqNoiseSmp])
            let p = sourceFilterP(at: fqSmp)
            
            ps.append((enp, i, .editFqNoiseSmp))
            ps.append((p, i, .fqSmp))
            lastP = p
        }
        
        let maxDS = maxDistance * maxDistance
        var minDS = Double.infinity, minI: Int?, minType = SourceFilterType.fqSmp
        
        for fpt in ps {
            let ds = fpt.p.distanceSquared(p)
            if ds < minDS && ds < maxDS {
                minDS = ds
                minI = fpt.i
                minType = fpt.type
            }
        }
        
        if let minI, minType == .editFqNoiseSmp && sourceFilterP(at: sf.fqSmps[minI]).distance(sourceFilterP(at: sf[minI, .editFqNoiseSmp])) < ratio * 2 {
            minType = .fqSmp
        }
        
        let np = Point(lastP.x + ratio * 2, spy)
        let ds = np.distanceSquared(p)
        if ds < minDS && ds < maxDS {
            return (score.tone.sourceFilter.fqSmps.count - 1, minType, true)
        } else if let minI {
            return (minI, minType, false)
        } else {
            return nil
        }
    }
    func containsSourceFilter(_ p: Point) -> Bool {
        sourceFilterFrame?.contains(p) ?? false
    }
    var sourceFilterFrame: Rect? {
        guard model.timeframe?.score != nil else { return nil }
        if let node = timeframeNode.children.first(where: { $0.name == "sourceFilter" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    
    func containsContent(_ p: Point) -> Bool {
        contentFrame?.contains(p) ?? false
    }
    var contentFrame: Rect? {
        guard model.timeframe?.content != nil else { return nil }
        if let node = timeframeNode.children.first(where: { $0.name == "content" }) {
            return node.transformedBounds
        } else {
            return nil
        }
    }
    
    func tempoPositionBeat(_ p: Point, maxDistance: Double) -> Rational? {
        guard let timeframe = model.timeframe else { return nil }
        let tempoBeat = timeframe.beatRange.start.rounded(.down) + 1
        if tempoBeat < timeframe.beatRange.end {
            let np = if let scoreFrame {
                Point(x(atBeat: tempoBeat), scoreFrame.maxY)
            } else {
                Point(x(atBeat: tempoBeat), timeRangeFrame?.maxY ?? 0)
            }
            return np.distance(p) < maxDistance ? tempoBeat : nil
        } else {
            return nil
        }
    }
    
    func containsTone(_ p: Point) -> Bool {
        toneFrame?.contains(p) ?? false
    }
    var toneFrame: Rect? {
        guard model.timeframe?.score != nil else { return nil }
        return overtoneFrame + sourceFilterFrame
    }
    
    func containsScore(_ p: Point) -> Bool {
        paddingScoreFrame?.contains(p) ?? false
    }
    var scoreFrame: Rect? {
        guard let timeframe = model.timeframe,
              let score = timeframe.score else { return nil }
        let h = self.height(fromPitch: score.pitchRange.length)
        let sx = self.x(atBeat: timeframe.beatRange.start)
        let ex = self.x(atBeat: timeframe.beatRange.end)
        let lastB = typesetter.firstReturnBounds ?? Rect()
        let y = lastB.minY
        return Rect(x: sx, y: y, width: ex - sx, height: h)
    }
    var transformedScoreFrame: Rect? {
        if var sf = scoreFrame {
            sf.origin.y += model.origin.y
            return sf
        } else {
            return nil
        }
    }
    var paddingScoreFrame: Rect? {
        scoreFrame?.outset(by: 3 * nodeRatio)
    }
    
    func containsTimeframe(_ p: Point) -> Bool {
        containsTimeRange(p)
        || containsIsShownSpectrogram(p)
        || containsScore(p)
        || containsTone(p) || containsContent(p)
    }
    var endTimeFrame: Rect? {
        guard let timeframe = model.timeframe else { return nil }
        
        let ratio = nodeRatio
        let t = timeframe.beatRange.end
        let sx = self.x(atBeat: t)
        let ex = self.x(atBeat: t)
        let lastB = typesetter.firstReturnBounds ?? Rect()
        let y = lastB.minY
        
        return Rect(x: sx, y: y - 6 * ratio, width: ex - sx, height: 12 * ratio)
            .outset(by: 3 * ratio)
    }
    
    func containsMainLine(_ p: Point, distance: Double) -> Bool {
        guard containsTimeframe(p) else { return false }
        let lastB = typesetter.firstReturnBounds ?? Rect()
        let y = lastB.minY
        return abs(p.y - y) < distance
    }
    
    func noteFrame(from note: Note,
                   _ score: Score, _ timeframe: Timeframe) -> Rect {
        let ratio = nodeRatio
        
        let lastB = typesetter.firstReturnBounds ?? Rect()
        let y = lastB.minY
        
        let nh = ScoreLayout.noteHeight * ratio
        
        let sh = self.height(fromPitch: note.pitch - score.pitchRange.lowerBound,
                             noteHeight: nh)
        let nx = x(atBeat: note.beatRange.start + timeframe.beatRange.start + timeframe.localStartBeat)
        let w = note.beatRange.length == 0 ?
        width(atBeatDuration: Rational(1, 96)) :
        x(atBeat: note.beatRange.end + timeframe.beatRange.start + timeframe.localStartBeat) - nx
        return Rect(x: nx, y: y + sh, width: w, height: nh)
    }
    func noteFrames(_ score: Score, _ timeframe: Timeframe) -> [Rect] {
        let ratio = nodeRatio
        let lastB = typesetter.firstReturnBounds ?? Rect()
        let y = lastB.minY
        let nh = ScoreLayout.noteHeight * ratio
        return score.notes.compactMap { note in
            guard score.pitchRange.contains(note.pitch) else { return nil }
            let sh = self.height(fromPitch: note.pitch - score.pitchRange.lowerBound,
                                 noteHeight: nh)
            let nx = x(atBeat: note.beatRange.start + timeframe.beatRange.start + timeframe.localStartBeat)
            let w = note.beatRange.length == 0 ?
            1.0 * ratio :
            x(atBeat: note.beatRange.end + timeframe.beatRange.start + timeframe.localStartBeat) - nx
            return Rect(x: nx, y: y + sh, width: w, height: nh)
        }
    }
    func noteNode(from note: Note, at i: Int?, y: Double,
                  color: Color = .content) -> Node {
        Node(children: noteNodes(from: note, at: i, y: y, color: color))
    }
    func noteNodes(from note: Note, at i: Int?, y: Double,
                   color: Color = .content) -> [Node] {
        guard let timeframe = model.timeframe, let score = timeframe.score else { return [] }
        let ratio = nodeRatio
        let noteHeight = ScoreLayout.noteHeight * ratio
        
//        let lastB = typesetter.firstReturnBounds ?? Rect()
        let y = y + noteHeight / 2
        let (preFq, nextFq) = i != nil ? pitbendPreNext(notes: score.notes, at: i!) : (nil, nil)
        let (linePathlines, knobPathlines, lyricPath) = notePathlines(from: note, y: y,
                                                                      preFq: preFq, nextFq: nextFq,
                                                                      tempo: timeframe.tempo)
        
        let lyricNodes: [Node]
        if let lyricPath {
            lyricNodes = [Node(path: lyricPath,
                               fillType: .color(color))]
        } else {
            lyricNodes = []
        }
        
        let pan = timeframe.score?.pan ?? 0
        let nodes = linePathlines.enumerated().map {
            let color = Self.panColor(pan: pan,
                                      brightness: 0.25)
            return Node(path: Path([$0.element]),
                        lineWidth: noteHeight,
                        lineType: .color(color))
        }
        
        return nodes + [Node(path: Path(knobPathlines),
                             fillType: .color(.background))] + lyricNodes
    }
    func notePathlines(from note: Note, y: Double,
                       preFq: Double?, nextFq: Double?,
                       tempo: Rational) -> (linePathlines: [Pathline], knobPathlines: [Pathline],
                                            lyricPath: Path?) {
        let ratio = nodeRatio
        let noteHeight = ScoreLayout.noteHeight * ratio
        let nx = self.x(atBeat: note.beatRange.start)
        let ny = self.height(fromPitch: note.pitch,
                             noteHeight: noteHeight) + y
        let nw = width(atBeatDuration: note.beatRange.length == 0 ? Rational(1, 96) : note.beatRange.length)
        if note.volumeAmp == 0 {
            let d = ratio - ratio / 4
            var line0 = Line(edge: .init(.init(nx, ny - d), .init(nx + nw, ny - d)))
            line0.controls = line0.controls.map {
                .init(point: $0.point,
                      weight: $0.weight,
                      pressure: $0.pressure / noteHeight / 2)
            }
            var line1 = Line(edge: .init(.init(nx, ny + d), .init(nx + nw, ny + d)))
            line1.controls = line1.controls.map {
                .init(point: $0.point,
                      weight: $0.weight,
                      pressure: $0.pressure / noteHeight / 2)
            }
            
            return ([.init(line0), .init(line1)], [], nil)
        }
        
        func lyricPath(at p: Point) -> Path? {
            if !note.lyric.isEmpty || note.isBreath || note.isVibrato || note.isVowelReduction {
                let lyricText = Text(string: "\(note.lyric)" + (note.isBreath ? "^" : "") + (note.isVibrato ? "~" : "") + (note.isVowelReduction ? "/" : ""),
                                     size: Font.smallSize * ratio)
                let typesetter = lyricText.typesetter
                return typesetter.path() * Transform(translationX: p.x, y: p.y - typesetter.height / 2)
            } else {
                return nil
            }
        }
        
        let smpT = note.volume.smp
            .clipped(min: 0, max: Volume.maxSmp, newMin: 0, newMax: 1) + 1 / noteHeight
        if !note.pitbend.isEmpty || (note.pitbend.isEmpty && !note.lyric.isEmpty) {
            let pitbend = pitbend(from: note, tempo: tempo, preFq: preFq, nextFq: nextFq)
            let secDur = Double(Timeframe.sec(fromBeat: note.beatRange.length, tempo: tempo))
            
            var line = pitbend.line(secDuration: secDur,
                                    envelope: note.tone.envelope) ?? Line()
            line.controls = line.controls.map {
                .init(point: .init($0.point.x / secDur * nw + nx,
                                   self.height(fromPitch: $0.point.y * 12,
                                               noteHeight: noteHeight) + ny),
                      weight: $0.weight,
                      pressure: $0.pressure * smpT)
            }
            
            let knobPathlines = pitbend.pits.map {
                Pathline(circleRadius: 0.5 * nodeRatio,
                         position: .init($0.t * nw + nx,
                                         self.height(fromPitch: $0.pitch * 12,
                                                     noteHeight: noteHeight) + ny))
            }
            
            let lp = (line.controls.first?.point ?? .init(nx, ny)) + .init(0, -noteHeight / 2)
            return ((line.isEmpty ? [] : [.init(line)]), knobPathlines, lyricPath(at: lp))
        } else {
            let env = note.tone.envelope
            let attackW = width(atSecDuration: env.attack)
            let sustain = Volume(amp: note.volume.amp * env.sustain).smp
                .clipped(min: 0, max: Volume.maxSmp, newMin: 0, newMax: 1) + 1 / noteHeight
            let line = Line(controls: [.init(point: Point(nx, ny), pressure: 0),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW, ny), pressure: smpT),
                                       .init(point: Point(nx + attackW + width(atSecDuration: env.decay), ny), pressure: sustain),
                                       .init(point: Point(nx + attackW + width(atSecDuration: env.decay), ny), pressure: sustain),
                                       .init(point: Point(nx + nw, ny), pressure: sustain),
                                       .init(point: Point(nx + nw, ny), pressure: sustain),
                                       .init(point: Point(nx + nw + width(atSecDuration: env.release), ny), pressure: 0)])
            return ([.init(line)], [], lyricPath(at: .init(nx, ny - noteHeight / 2)))
        }
    }
    
    func pitbendPreNext(notes: [Note], at i: Int) -> (preFq: Double?, nextFq: Double?) {
        let note = notes[i]
        guard !note.lyric.isEmpty else { return (nil, nil) }
        var preFq, nextFq: Double?
        
        var minD = Rational.max
        for j in (0 ..< i).reversed() {
            guard !notes[j].lyric.isEmpty else { continue }
            guard notes[j].beatRange.end == note.beatRange.start else { break }
            let d = abs(note.pitch - notes[j].pitch)
            if d < Pitbend.enabledRecoilPitchDistance, d < minD {
                preFq = notes[j].fq
                minD = d
            }
        }
        
        minD = .max
        for j in i + 1 ..< notes.count {
            guard !notes[j].lyric.isEmpty else { continue }
            guard notes[j].beatRange.start == note.beatRange.end else { break }
            let d = abs(note.pitch - notes[j].pitch)
            if d < Pitbend.enabledRecoilPitchDistance, d < minD {
                preFq = notes[j].fq
                minD = d
            }
        }
        return (preFq, nextFq)
    }
    func pitbend(from note: Note, tempo: Rational,
                 preFq: Double?, nextFq: Double?) -> Pitbend {
        if !note.pitbend.isEmpty || (note.pitbend.isEmpty && !note.lyric.isEmpty) {
            if !note.pitbend.isEmpty {
                return note.pitbend
            } else {
                let isVowel = Phoneme.isSyllabicJapanese(Phoneme.phonemes(fromHiragana: note.lyric))
                return Pitbend(isVibrato: note.isVibrato,
                               duration: Double(Timeframe.sec(fromBeat: note.beatRange.length, tempo: tempo)),
                               fq: note.fq,
                               isVowel: isVowel,
                               previousFq: preFq, nextFq: nextFq)
            }
        } else {
            return Pitbend()
        }
    }
    
    func pitT(at p: Point,
              maxDistance maxD: Double) -> (noteI: Int, pitT: Double)? {
        guard let timeframe = model.timeframe,
              let score = timeframe.score else { return nil }
        
        var minNoteI: Int?, minPitT: Double?, minD = Double.infinity
        for noteI in 0 ..< score.notes.count {
            let note = score.notes[noteI]
            let (preFq, nextFq) = pitbendPreNext(notes: score.notes, at: noteI)
            let pitbend = pitbend(from: note, tempo: timeframe.tempo, preFq: preFq, nextFq: nextFq)
            
            let f = noteFrame(from: note, score, timeframe)
            let sh = self.height(fromPitch: note.pitch - score.pitchRange.start,
                                 noteHeight: f.height)
            if f.width > 0 && p.x >= f.minX && p.x <= f.maxX {
                let t = (p.x - f.minX) / f.width
                let pit = pitbend.pit(atT: t)
                
                let y = self.height(fromPitch: pit.pitch * 12 + .init(note.pitch - score.pitchRange.start),
                                    noteHeight: f.height) + f.midY - sh
                let d = y.distance(p.y)
                if d < minD && d < maxD {
                    minNoteI = noteI
                    minPitT = t
                    minD = d
                }
            }
        }
        
        if let minNoteI, let minPitT {
            return (minNoteI, minPitT)
        } else {
            return nil
        }
    }
    
    func pitbendTuple(at p: Point,
                      maxDistance maxD: Double) -> (noteI: Int, pitI: Int,
                                                    pit: Pit,
                                                    pitbend: Pitbend)? {
        guard let timeframe = model.timeframe,
              let score = timeframe.score else { return nil }
        
        let maxDS = maxD * maxD
        var minNoteI: Int?, minPitI: Int?,
            minPit: Pit?, minPitbend: Pitbend?,
            minDS = Double.infinity
        for noteI in 0 ..< score.notes.count {
            let note = score.notes[noteI]
            let (preFq, nextFq) = pitbendPreNext(notes: score.notes, at: noteI)
            let pitbend = pitbend(from: note, tempo: timeframe.tempo, preFq: preFq, nextFq: nextFq)
            let f = noteFrame(from: note, score, timeframe)
            let sh = self.height(fromPitch: note.pitch - score.pitchRange.start,
                                 noteHeight: f.height)
            for (pitI, pit) in pitbend.pits.enumerated() {
                let pitP = Point(pit.t * f.width + f.minX,
                                 self.height(fromPitch: pit.pitch * 12 + .init(note.pitch - score.pitchRange.start),
                                                     noteHeight: f.height) + f.midY - sh)
                let ds = pitP.distanceSquared(p)
                if ds < minDS && ds < maxDS {
                    minNoteI = noteI
                    minPitI = pitI
                    minPit = pit
                    minPitbend = pitbend
                    minDS = ds
                }
            }
        }
        
        if let minNoteI, let minPitI, let minPit, let minPitbend {
            return (minNoteI, minPitI, minPit, minPitbend)
        } else {
            return nil
        }
    }
    
    func noteIndex(at p: Point, maxDistance: Double) -> Int? {
        guard let timeframe = model.timeframe,
              let score = timeframe.score,
              containsScore(p) else { return nil }
        
        let ratio = nodeRatio
        let sBeat = max(timeframe.beatRange.start, -10000),
            eBeat = min(timeframe.beatRange.end, 10000)
        guard sBeat <= eBeat else { return nil }
        let lastB = typesetter.firstReturnBounds ?? Rect()
        let y = lastB.minY
        let nh = ScoreLayout.noteHeight * ratio
        
        let pitchRange = score.pitchRange
        let beat = timeframe.beatRange.start
        let preBeat = max(beat, sBeat)
        let nextBeat = min(beat + timeframe.beatRange.length, eBeat)
        
        let maxDS = maxDistance * maxDistance
        var minI: Int?, minDS = Double.infinity
        for (i, note) in score.notes.enumerated() {
            guard pitchRange.contains(note.pitch) else { continue }
            var beatRange = note.beatRange
            beatRange.start += beat + timeframe.localStartBeat
            
            guard beatRange.end > preBeat
                    && beatRange.start < nextBeat
                    && note.volumeAmp >= Volume.minAmp
                    && note.volumeAmp <= Volume.maxAmp else { continue }
            
            if beatRange.start < preBeat {
                beatRange.length -= preBeat - beatRange.start
                beatRange.start = preBeat
            }
            if beatRange.end > nextBeat {
                beatRange.end = nextBeat
            }
            
            let sh = self.height(fromPitch: note.pitch - pitchRange.start,
                                 noteHeight: nh)
            let nx = x(atBeat: beatRange.start)
            let nw = beatRange.length == 0 ?
                width(atBeatDuration: Rational(1, 96)) :
                x(atBeat: beatRange.end) - nx
            let noteF = Rect(x: nx, y: y + sh, width: nw, height: nh)
            
            let ds = noteF.distanceSquared(p)
            if ds < minDS && ds < maxDS {
                minDS = ds
                minI = i
            }
        }
        return minI
    }
    
    private func updateMarkedRange() {
        if let markedRange = markedRange {
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
        if let replacedRange = replacedRange {
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
    fileprivate func updateCursor() {
        if let selectedRange = selectedRange {
            cursorNode.path = typesetter.cursorPath(at: selectedRange.lowerBound)
        } else {
            cursorNode.path = Path()
        }
    }
    fileprivate func updateSelectedLineLocation() {
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
        if let timeframeFrame {
            let rect = typesetter.spacingTypoBoundsEnabledEmpty
            return timeframeFrame.union(rect)
        } else {
            return typesetter.spacingTypoBoundsEnabledEmpty
        }
    }
    var transformedBounds: Rect? {
        if let bounds = bounds {
            return bounds * node.localTransform
        } else {
            return nil
        }
    }
    
    var clippableBounds: Rect? {
        if let timeframeFrame {
            if let rect = typesetter.typoBounds {
                return timeframeFrame.union(rect)
            } else {
                return nil
            }
        } else {
            return typesetter.typoBounds
        }
    }
    var transformedClippableBounds: Rect? {
        if let bounds = clippableBounds {
            return bounds * node.localTransform
        } else {
            return nil
        }
    }
    
    func typoBounds(with textValue: TextValue) -> Rect? {
        let sRange = model.string.range(fromInt: textValue.newRange)
        return typesetter.typoBounds(for: sRange)
    }
    func transformedTypoBounds(with range: Range<String.Index>) -> Rect? {
        let b = typesetter.typoBounds(for: range)
        if let b = b {
            return b * node.localTransform
        } else {
            return nil
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
    
    func deleteBackward(from range: Range<String.Index>? = nil) {
        if let range = range {
            removeCharacters(in: range)
            return
        }
        guard let deleteRange = selectedRange else { return }
        
        if let document = editor?.document, !document.selectedFrames.isEmpty {
            if delete(from: document.selections) {
                document.selections = []
                return
            }
        }
        
        if deleteRange.isEmpty {
            let string = model.string
            guard deleteRange.lowerBound > string.startIndex else { return }
            let nsi = typesetter.index(before: deleteRange.lowerBound)
            let nRange = nsi ..< deleteRange.lowerBound
            let nnRange = string.rangeOfComposedCharacterSequences(for: nRange)
            removeCharacters(in: nnRange)
        } else {
            removeCharacters(in: deleteRange)
        }
    }
    func deleteForward(from range: Range<String.Index>? = nil) {
        if let range = range {
            removeCharacters(in: range)
            return
        }
        guard let deleteRange = selectedRange else { return }
        
        if let document = editor?.document, !document.selectedFrames.isEmpty {
            if delete(from: document.selections) {
                document.selections = []
                return
            }
        }
        
        if deleteRange.isEmpty {
            let string = model.string
            guard deleteRange.lowerBound < string.endIndex else { return }
            let nei = typesetter.index(after: deleteRange.lowerBound)
            let nRange = deleteRange.lowerBound ..< nei
            let nnRange = string.rangeOfComposedCharacterSequences(for: nRange)
            removeCharacters(in: nnRange)
        } else {
            removeCharacters(in: deleteRange)
        }
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
