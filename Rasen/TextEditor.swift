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

import struct Foundation.UUID

final class TextSlider: DragEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    enum SlideType {
        case all, startBeat, endBeat
    }
    
    private var sheetView: SheetView?, textI: Int?, beganText: Text?
    private var type = SlideType.all
    private var beganSP = Point(), beganInP = Point(), beganTextEndP = Point()
    
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
                let ci = sheetView.textIndex(at: sheetView.convertFromWorld(p)) {
                
                let sheetP = sheetView.convertFromWorld(p)
                let textView = sheetView.textsView.elementViews[ci]
                let text = textView.model
                
                beganSP = sp
                beganInP = sheetP
                self.sheetView = sheetView
                beganText = text
                if let timeOption = text.timeOption {
                    beganTextEndP = .init(sheetView.animationView.x(atBeat: timeOption.beatRange.end), text.origin.y)
                }
                textI = ci
                
                let maxMD = 10 * document.screenToWorldScale
                
                if let timeOption = text.timeOption {
                    if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.start)) < maxMD {
                        type = .startBeat
                    } else if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.end)) < maxMD {
                        type = .endBeat
                    } else {
                        type = .all
                    }
                }
            }
        case .changed:
            if let sheetView, let beganText,
               let textI, textI < sheetView.textsView.elementViews.count {
                
                let sheetP = sheetView.convertFromWorld(p)
                let textView = sheetView.textsView.elementViews[textI]
                let text = textView.model
                
                switch type {
                case .all:
                    let np = beganText.origin + sheetP - beganInP
                    let interval = document.currentNoteBeatInterval
                    let beat = max(min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - (text.timeOption?.beatRange.length ?? 0))
                    var timeOption = text.timeOption
                    timeOption?.beatRange.start = beat
                    textView.set(timeOption, origin: Point(sheetView.animationView.x(atBeat: beat), np.y))
                    document.updateSelects()
                case .startBeat:
                    if var timeOption = text.timeOption {
                        let np = beganText.origin + sheetP - beganInP
                        let interval = document.currentNoteBeatInterval
                        let beat = min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.end)
                        if beat != timeOption.beatRange.start {
                            let dBeat = timeOption.beatRange.start - beat
                            timeOption.beatRange.start -= dBeat
                            timeOption.beatRange.length += dBeat
                            textView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), text.origin.y))
                            document.updateSelects()
                        }
                    }
                case .endBeat:
                    if let beganTimeOption = beganText.timeOption {
                        let np = beganTextEndP + sheetP - beganInP
                        let interval = document.currentNoteBeatInterval
                        let beat = max(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval),
                                       beganTimeOption.beatRange.start)
                        if beat != text.timeOption?.beatRange.end {
                            var beatRange = beganTimeOption.beatRange
                            beatRange.end = beat
                            textView.timeOption?.beatRange = beatRange
                            document.updateSelects()
                        }
                    }
                }
            }
        case .ended:
            if let sheetView, let beganText,
               let textI, textI < sheetView.textsView.elementViews.count {
               
                let textView = sheetView.textsView.elementViews[textI]
                if textView.model != beganText {
                    sheetView.newUndoGroup()
                    sheetView.capture(textView.model, old: beganText, at: textI)
                }
                sheetView.updatePlaying()
            }
            
            document.cursor = Document.defaultCursor
        }
    }
}

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
            show(for: p)
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    func show(for p: Point) {
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
                          let (node, contentView) = sheetView.spectrogramNode(at: sheetView.convertFromWorld(p)) {
                    let nSelection = sheetView.convertFromWorld(selection)
                    let rect = node.convertFromWorld(selection.rect)
                    let minY = rect.minY, maxY = rect.maxY
                    let minPitch = contentView.spectrogramPitch(atY: minY)!
                    let minPitchRat = Rational(minPitch, intervalScale: .init(1, 12))
                    let minFq = Pitch(value: minPitchRat).fq
                    let maxPitch = contentView.spectrogramPitch(atY: maxY)!
                    let maxPitchRat = Rational(maxPitch, intervalScale: .init(1, 12))
                    let maxFq = Pitch(value: maxPitchRat).fq
                    let minSec: Rational = sheetView.animationView.sec(atX: nSelection.rect.minX)
                    let maxSec: Rational = sheetView.animationView.sec(atX: nSelection.rect.maxX)
                    document.show("Δ\(Double(maxSec - minSec).string(digitsCount: 4)) sec, Δ\(Pitch(value: maxPitchRat - minPitchRat).octaveString()), (Δ\((maxFq - minFq).string(digitsCount: 1)) Hz)", at: p)
                } else if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                    let scoreView = sheetView.scoreView
                    let score = scoreView.model
                    let nis = sheetView.noteIndexes(from: document.selections)
                    if !nis.isEmpty {
                        let notes = nis.map { score.notes[$0] }
                        var fpr = notes[0].pitchRange
                        for i in 1 ..< notes.count {
                            let range = notes[i].pitchRange
                            if fpr.start < range.start {
                                fpr.start = range.start
                            }
                            if fpr.end > range.end {
                                fpr.end = range.end
                            }
                        }
                        let startPitch = Pitch(value: fpr.start)
                        let endPitch = Pitch(value: fpr.end)
                        
                        let str = "\(startPitch.octaveString()) ... \(endPitch.octaveString())  (\(startPitch.fq.string(digitsCount: 1)) ... \(endPitch.fq.string(digitsCount: 1)) Hz)".localized
                        document.show(str, at: p)
                    }
                } else {
                    document.show("No selection".localized, at: p)
                }
            }
        } else if let (_, _) = document.worldBorder(at: p, distance: d) {
            document.show("Border".localized, at: p)
        } else if let (_, _, _) = document.border(at: p, distance: d) {
            document.show("Border".localized, at: p)
        } else if let sheetView = document.sheetView(at: p),
                  let lineView = sheetView.lineTuple(at: sheetView.convertFromWorld(p), scale: 1 / document.worldToScreenScale)?.lineView {
            document.show("Line".localized + "\n\t\("Length".localized):  \(lineView.model.length().string(digitsCount: 4))", at: p)
        } else if let sheetView = document.sheetView(at: p),
                  let (textView, _, i, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
            
            if let range = textView.wordRange(at: i) {
                let string = String(textView.model.string[range])
                showDefinition(string: string, range: range,
                               in: textView, in: sheetView)
            } else {
                document.show("Text".localized, at: p)
            }
        } else if let sheetView = document.sheetView(at: p),
                  let noteI = sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p),
                                                            scale: document.screenToWorldScale) {
            let y = sheetView.scoreView.noteY(atX: sheetView.scoreView.convertFromWorld(p).x, at: noteI)
            let pitch = Pitch(value: sheetView.scoreView.pitch(atY: y, interval: Rational(1, 12)))
            let fq = pitch.fq
            let fqStr = "\("Note".localized) \(pitch.octaveString()) (\(fq.string(digitsCount: 1)) Hz)".localized
            document.show(fqStr, at: p)
        } else if let sheetView = document.sheetView(at: p),
                    let ci = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                    scale: document.screenToWorldScale) {
            let content = sheetView.contentsView.elementViews[ci].model
            document.show(content.type.displayName, at: p)
        } else if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
            let scoreView = sheetView.scoreView
            let pitch = Pitch(value: document.pitch(from: scoreView, at: scoreView.convertFromWorld(p)))
            let fqStr = "\(pitch.octaveString()) (\(pitch.fq.string(digitsCount: 1)) Hz)".localized
            document.show(fqStr, at: p)
        } else if let sheetView = document.sheetView(at: p),
                  let (node, contentView) = sheetView.spectrogramNode(at: sheetView.convertFromWorld(p)) {
            let y = node.convertFromWorld(p).y
            let pitch = contentView.spectrogramPitch(atY: y)!
            let pitchRat = Rational(pitch, intervalScale: .init(1, 12))
            let nfq = Pitch(value: pitchRat).fq
            let fqStr = "\(Pitch(value: pitchRat).octaveString()) (\(nfq.string(digitsCount: 1)) Hz)".localized
            document.show(fqStr, at: p)
        } else if !document.isDefaultUUColor(at: p) {
            let colorOwners = document.readColorOwners(at: p)
            if !colorOwners.isEmpty,
               let sheetView = document.sheetView(at: p),
               let plane = sheetView.plane(at: sheetView.convertFromWorld(p)) {
                
                let rgba = plane.uuColor.value.rgba
                document.show("Face".localized + "\n\t\("Area".localized):  \(plane.topolygon.area.string(digitsCount: 4))\n\tsRGB: \(rgba.r) \(rgba.g) \(rgba.b)", at: p)
            } else {
                document.show("Background".localized, at: p)
            }
        } else {
            document.show("Background".localized, at: p)
        }
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
        if !event.isRepeat, let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
            let scoreView = sheetView.scoreView
            let scoreP = scoreView.convertFromWorld(p)
            if let (noteI, pitI) = scoreView.noteAndPitIEnabledNote(at: scoreP, scale: document.screenToWorldScale) {
                var note = scoreView.model.notes[noteI]
                let key = (event.inputKeyType.name
                    .applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? "").lowercased()
                var lyric = note.pits[pitI].lyric
                if event.inputKeyType == .delete, !lyric.isEmpty {
                    lyric.removeLast()
                } else if event.inputKeyType != .delete {
                    lyric += key
                }
                if lyric != note.pits[pitI].lyric {
                    note.replace(lyric: lyric, at: pitI, tempo: scoreView.model.tempo)
                    
                    sheetView.newUndoGroup()
                    sheetView.replace(note, at: noteI)
                }
                return
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
        if textView.model.string.isEmpty {
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

final class TextView<T: BinderProtocol>: TimelineView {
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
        if abs(peakVolume.amp) < Audio.clippingAmp {
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
    
    var timeLineCenterY: Double {
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
    
    func containsTimeline(_ p : Point) -> Bool {
        timelineFrame?.contains(p) ?? false
    }
    var timelineFrame: Rect? {
        guard let timeOption = model.timeOption else { return nil }
        let sx = x(atBeat: timeOption.beatRange.start)
        let ex = x(atBeat: timeOption.beatRange.end)
        let y = typesetter.firstReturnBounds?.minY ?? 0
        return Rect(x: sx, y: y,
                    width: ex - sx, height: Sheet.timelineHalfHeight * 2).outset(by: 3)
    }
    var transformedTimelineFrame: Rect? {
        if var f = timelineFrame {
            f.origin.y += model.origin.y
            return f
        } else {
            return nil
        }
    }
    
    func contains(_ p: Point) -> Bool {
        containsTimeline(p)
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
    fileprivate func updateCursor() {
        if let selectedRange {
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
