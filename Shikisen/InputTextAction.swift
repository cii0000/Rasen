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

import struct Foundation.UUID
import struct Foundation.Date

final class FindAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func flow(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            guard isEditingSheet else {
                rootAction.keepOut(with: event)
                return
            }
            
            let p = rootView.convertScreenToWorld(event.screenPoint)
            guard let sheetView = rootView.sheetView(at: p) else { return }
            let sheetP = sheetView.convertFromWorld(p)
            var isFind = false
            if let (textView, _, i, _) = sheetView.textTuple(at: sheetP, scale: rootView.screenToWorldScale) {
                if let range = textView.selectedRange(at: textView.convertFromWorld(p))
                    ?? textView.wordRange(at: i) {
                    
                    let string = String(textView.model.string[range])
                    rootView.finding = Finding(worldPosition: p, string: string)
                    isFind = true
                }
            } else if let tempo = sheetView.tempo(at: sheetP, scale: rootView.screenToWorldScale) {
                let str = "\(tempo) bpm"
                rootView.finding = Finding(worldPosition: p, string: str)
                isFind = true
            } else if let mainFrame = rootView.mainFrame(at: p)?.mainFrame {
                if mainFrame != Sheet.defaultBounds {
                    let str = "((\(mainFrame.minX), \(mainFrame.minY)) (\(mainFrame.size.width)x\(mainFrame.size.height))"
                    rootView.finding = Finding(worldPosition: p, string: str)
                    isFind = true
                }
            } else {
                let topOwner = sheetView.sheetColorOwner(at: sheetP, scale: rootView.screenToWorldScale).value
                let uuColor = topOwner.uuColor
                if uuColor != Sheet.defalutBackgroundUUColor && uuColor.value.opacity != 0 {
                    let string = uuColor.id.uuidString
                    rootView.finding = Finding(worldPosition: p, string: string)
                    isFind = true
                }
            }
            if !isFind {
                rootView.finding = Finding()
                rootView.cursor = .arrowWith(string: "Empty".localized)
            } else {
                rootView.cursor = .arrow
            }
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class ChangeLanguageAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    func flow(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            let name: String
            if event.inputKeyType == .abc {
                name = "Ａ"
            } else if event.inputKeyType == .aiu {
                name = "あ"
            } else {
                return
            }
            
            if rootView.pov.rotation != 0 {
                rootView.cursor = Cursor.rotate(string: name,
                                                rotation: -rootView.pov.rotation + .pi / 2)
            } else {
                rootView.cursor = .circle(string: name)
            }
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class LookUpAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    func flow(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            let p = rootView.convertScreenToWorld(event.screenPoint)
            show(for: p)
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
    func show(for p: Point) {
        if !rootView.isEditingSheet {
            let shp = rootView.sheetPosition(at: p)
            if let shps = rootView.selectedSheetPositions(p) {
                let sheetCount = shps.count
                var allFileSize = 0, updateDate: Date?, createdDate: Date?
                for shp in shps {
                    if let sid = rootView.sheetID(at: shp),
                       let recoder = rootView.model.sheetRecorders[sid] {
                        
                        if let aUpdateDate = recoder.directory.updateDate {
                            updateDate = updateDate != nil ?
                            max(updateDate!, aUpdateDate) : aUpdateDate
                        }
                        if let aCreatedDate = recoder.directory.createdDate {
                            createdDate = createdDate != nil ?
                            min(createdDate!, aCreatedDate) : aCreatedDate
                        }
                        allFileSize += recoder.fileSize
                    }
                }
                
                let string = IOResult.fileSizeNameFrom(fileSize: allFileSize)
                rootView.show("Sheets".localized
                              + "\n\t\("All File Size".localized): \(string)"
                              + "\n\t\("Update Date".localized): \(updateDate?.defaultString ?? "N/A")"
                              + "\n\t\("Created Date".localized): \(createdDate?.defaultString ?? "N/A")"
                              + "\n\t\("Count".localized): \(sheetCount)", at: p)
            } else if let sid = rootView.sheetID(at: shp),
                      let recoder = rootView.model.sheetRecorders[sid] {
                
                let fileSize = recoder.fileSize
                let updateDate = recoder.directory.updateDate
                let createdDate = recoder.directory.createdDate
                let string = IOResult.fileSizeNameFrom(fileSize: fileSize)
                rootView.show("Sheet".localized
                              + "\n\t\("File Size".localized): \(string)"
                              + "\n\t\("Update Date".localized): \(updateDate?.defaultString ?? "N/A")"
                              + "\n\t\("Created Date".localized): \(createdDate?.defaultString ?? "N/A")"
                              + "\n\t\("Position".localized): \(shp.x)_\(shp.y)", at: p)
            } else {
                rootView.show("Root".localized, at: p)
            }
        } else if let sheetView = rootView.sheetView(at: p),
                  sheetView.animationView.containsTimeline(sheetView.animationView.timelineNode.convertFromWorld(p),
                                                           scale: rootView.screenToWorldScale),
                  let ki = sheetView.animationView.keyframeIndex(at: sheetView.animationView.timelineNode.convertFromWorld(p),
                                                                 scale: rootView.screenToWorldScale) {
            let animationView = sheetView.animationView
            
            let isSelected = animationView.selectedIs.contains(ki)
            if isSelected {
                let indexes = animationView.selectedIs.sorted()
                let animation = animationView.model
                let startBeatStr = sheetView.timeString(fromBeat: animation.keyframes[indexes.first!].beat)
                let endBeatStr = sheetView.timeString(fromBeat: animation.keyframes[indexes.last!].beat)
                rootView.show("Keyframes".localized
                              + "\n\t\("Beat Range".localized): \(startBeatStr) - \(endBeatStr)"
                              + "\n\t\("Count".localized): \(indexes.count)",
                              at: p)
            } else {
                let fpb = Sheet.fpb(fromTempo: sheetView.model.animation.tempo)
                let beat = sheetView.model.animation.keyframes[ki].beat
                let beatStr = sheetView.timeString(fromBeat: beat) + (fpb == nil || !(Rational(fpb!) * beat).isInteger ? " (" + "Rounding error".localized + ")" : "")
                rootView.show("Keyframe".localized
                              + "\n\t\("Beat".localized): \(beatStr)",
                              at: p)
            }
        } else if let sheetView = rootView.sheetView(at: p),
                  sheetView.animationView.containsTimeline(sheetView.animationView.timelineNode.convertFromWorld(p),
                                                           scale: rootView.screenToWorldScale) {
            let animation = sheetView.animationView.model
            let tempoStr = Sheet.tempoNameFromStandardFrameRate(withTempo: animation.tempo)
            let startBeatStr = sheetView.timeString(fromBeat: animation.beatRange.start)
            let endBeatStr = sheetView.timeString(fromBeat: animation.endLoopDurBeat)
            rootView.show("Timeline".localized
                          + "\n\t\("Beat Range".localized): \(startBeatStr) - \(endBeatStr)"
                          + "\n\t\("Tempo".localized): \(tempoStr)",
                          at: p)
        } else if let sheetView = rootView.sheetView(at: p),
                  let (textView, _, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale),
                  let range = textView.selectedRange(at: textView.convertFromWorld(p)) {
            let string = String(textView.model.string[range])
            showDefinition(string: string, range: range,
                           in: textView, in: sheetView)
        } else if let (_, _) = rootView.worldBorder(at: p) {
            rootView.show("Border".localized, at: p)
        } else if let (_, _, _, _) = rootView.border(at: p) {
            rootView.show("Border".localized, at: p)
        } else if let sheetView = rootView.sheetView(at: p),
                  let (lineView, li) = sheetView.lineTuple(at: sheetView.convertFromWorld(p),
                                                     enabledPlane: true,
                                                     scale: 1 / rootView.worldToScreenScale) {
            rootView.show((lineView.model.controls.count == 2 ? "Straight Line".localized : "Line".localized) + "\n\t\("Length".localized):  \(lineView.model.length().string(digitsCount: 4))\n\t\("Index".localized): \(li)", at: p)
        } else if let sheetView = rootView.sheetView(at: p),
                  let (textView, _, i, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale) {
            
            if let range = textView.wordRange(at: i) {
                let string = String(textView.model.string[range])
                showDefinition(string: string, range: range,
                               in: textView, in: sheetView)
            } else {
                rootView.show("Text".localized, at: p)
            }
        } else if let sheetView = rootView.sheetView(at: p),
                  let noteI = sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p),
                                                            scale: rootView.screenToWorldScale) {
            let note = sheetView.scoreView.model.notes[noteI]
            let idStr = note.pits.count == 1 ? note.pits[0].tone.id.uuidString : ""
            
            let scoreView = sheetView.scoreView
            let y = scoreView.noteY(atX: sheetView.scoreView.convertFromWorld(p).x, at: noteI)
            let scoreP = scoreView.convertFromWorld(p)
            let pitch = Pitch(value: sheetView.scoreView.pitch(atY: y, interval: Rational(1, 12)))
            let beat = scoreView.beat(atX: scoreP.x, interval: rootView.currentBeatInterval)
            let fq = pitch.fq
            let fqStr = "\("Note".localized) \(pitch.displayString()) (\(fq.string(digitsCount: 2)) Hz)"
            + "\n" + Animation.timeString(fromTime: beat,
                                          frameRate: Rational(Keyframe.defaultFrameRate)) + " beat" + (idStr.isEmpty ? "" : "\n\tID: \(idStr)")
            rootView.show(fqStr, at: p)
        } else if let sheetView = rootView.sheetView(at: p),
                  sheetView.scoreView.contains(sheetView.scoreView.convertFromWorld(p),
                                               scale: rootView.screenToWorldScale) {
            let scoreView = sheetView.scoreView
            let scoreP = scoreView.convertFromWorld(p)
            if let ki = scoreView.keyBeatIndex(at: scoreP, scale: rootView.screenToWorldScale) {
                let beatStr = sheetView.timeString(fromBeat: scoreView.model.keyBeats[ki])
                rootView.show("Keyframe".localized
                              + "\n\t\("Beat".localized): \(beatStr)",
                              at: p)
            } else if scoreView.containsTimeline(scoreP, scale: rootView.screenToWorldScale)
                || scoreView.containsIsShownSpectrogram(scoreP, scale: rootView.screenToWorldScale) {
                scoreView.scoreTrackItem?.updateNotewaveDic()
                let lufs = scoreView.scoreTrackItem?.lufs
                let peakDb = scoreView.scoreTrackItem?.peakDb
                let truePeakDb = scoreView.scoreTrackItem?.truePeakDb
                let tempoStr = Sheet.tempoNameFromStandardFrameRate(withTempo: scoreView.model.tempo)
                let startBeatStr = sheetView.timeString(fromBeat: scoreView.model.beatRange.start)
                let endBeatStr = sheetView.timeString(fromBeat: scoreView.model.endLoopDurBeat)
                rootView.show("Score".localized
                              + "\n\t\("Loudness".localized): \(lufs?.string(digitsCount: 2) ?? "N/A") LUFS"
                              + "\n\t\("Sample Peak".localized): \(peakDb?.string(digitsCount: 2) ?? "N/A") dB"
                              + "\n\t\("True Peak".localized): \(truePeakDb?.string(digitsCount: 2) ?? "N/A") dBTP"
                              + "\n\t\("Beat Range".localized): \(startBeatStr) - \(endBeatStr)"
                              + "\n\t\("Tempo".localized): \(tempoStr)",
                              at: p)
            } else {
                let pitchInterval = rootView.currentPitchInterval
                let pitch = Pitch(value: scoreView.pitch(atY: scoreP.y, interval: pitchInterval))
                let beat = scoreView.beat(atX: scoreP.x, interval: rootView.currentBeatInterval)
                let typers = scoreView.chordTypers(at: scoreView.convertFromWorld(p), scale: rootView.screenToWorldScale)
                let typerStr = !typers.isEmpty ?
                typers.reduce(into: "") { $0 += (!$0.isEmpty ? " " : "") + $1.type.description }
                : ""
                let fqStr = "\(pitch.displayString()) (\(pitch.fq.string(digitsCount: 2)) Hz)"
                + (typerStr.isEmpty ? typerStr : " " + typerStr)
                + "\n" + Animation.timeString(fromTime: beat,
                                              frameRate: Rational(Keyframe.defaultFrameRate)) + " beat"
                rootView.show(fqStr, at: p)
            }
        } else if let sheetView = rootView.sheetView(at: p),
                  let (node, contentView) = sheetView.spectrogramNode(at: sheetView.convertFromWorld(p)) {
            let pitch = contentView.spectrogramPitch(atY: node.convertFromWorld(p).y)!
            let beat = contentView.beat(atX: sheetView.convertFromWorld(p).x,
                                        interval: rootView.currentBeatInterval)
            - (contentView.model.timeOption?.localStartBeat ?? 0) + contentView.model.beat
            let pitchRat = Rational(pitch, intervalScale: EditGrid.fullEditPitchInterval)
            let nfq = Pitch(value: pitchRat).fq
            let fqStr = "\(Pitch(value: pitchRat).displayString()) (\(nfq.string(digitsCount: 2)) Hz)"
            + "\n" + Animation.timeString(fromTime: beat,
                                          frameRate: Rational(Keyframe.defaultFrameRate)) + " beat"
            rootView.show(fqStr, at: p)
        } else if let sheetView = rootView.sheetView(at: p),
                    let ci = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                    scale: rootView.screenToWorldScale) {
            let contentView = sheetView.contentsView.elementViews[ci]
            let content = contentView.model
            let fileSize = content.url.fileSize ?? 0
            let lufs = contentView.pcmTrackItem?.lufs
            let peakDb = contentView.pcmTrackItem?.peakDb
            let truePeakDb = contentView.pcmTrackItem?.truePeakDb
            let fileSizeStr = IOResult.fileSizeNameFrom(fileSize: fileSize)
            var str = content.type.displayName
            if content.type.isAudio {
                str += "\n\t\("Loudness".localized): \(lufs?.string(digitsCount: 2) ?? "N/A") LUFS"
                + "\n\t\("Sample Peak".localized): \(peakDb?.string(digitsCount: 2) ?? "N/A") dB"
                + "\n\t\("True Peak".localized): \(truePeakDb?.string(digitsCount: 2) ?? "N/A") dBTP"
            }
            if content.type != .sound, !content.size.isEmpty {
                str += "\n\t\("Size".localized): \(Self.sizeString(from: content.size))"
            }
            if let size = content.image?.size, !size.isEmpty {
                str += "\n\t\("Image Size".localized): \(Self.sizeString(from: size))"
            }
            if let timeOption = content.timeOption {
                let tempoStr = Sheet.tempoNameFromStandardFrameRate(withTempo: timeOption.tempo)
                let startBeatStr = sheetView.timeString(fromBeat: timeOption.beatRange.start)
                let endBeatStr = sheetView.timeString(fromBeat: timeOption.beatRange.end)
                str +=  "\n\t\("Beat Range".localized): \(startBeatStr) - \(endBeatStr)"
                + "\n\t\("Tempo".localized): \(tempoStr)"
            }
            str += "\n\t\("File Size".localized): \(fileSizeStr)"
            rootView.show(str, at: p)
        } else if !rootView.isDefaultUUColor(at: p),
                  let sheetView = rootView.sheetView(at: p),
                  let (pi, plane) = sheetView.planeTuple(at: sheetView.convertFromWorld(p)) {
            let rgba = plane.uuColor.value.rgba
            rootView.show("Color".localized + "\n\t\("Area".localized):  \(plane.topolygon.area.string(digitsCount: 4))\n\tsRGB: \(rgba.r) \(rgba.g) \(rgba.b)\n\t\("Index".localized): \(pi)", at: p)
        } else if let sheetView = rootView.sheetView(at: p) {
            let b = rootView.sheetFrame(with: rootView.sheetPosition(at: p)).bounds
            var sampless = rootView.currentSampless(at: rootView.sheetPosition(at: p))
            if !sampless.isEmpty {
                let peakDb = PCMBuffer.peakDb(sampless: sampless)
                let truePeakDb = PCMBuffer.truePeakDb(sampless: sampless)
                PCMBuffer.clip(amp: Audio.headroomAmp, sampless: &sampless)
                let lufs = PCMBuffer.lufs(sampless: sampless, sampleRate: Audio.defaultSampleRate)
                let mainSize = sheetView.mainFrame.bounds.size != Sheet.defaultBounds.size ? sheetView.mainFrame.size : nil
                rootView.show("Background".localized
                              + "\n\t\("Loudness".localized): \(lufs?.string(digitsCount: 2) ?? "N/A") LUFS"
                              + "\n\t\("Sample Peak".localized): \(peakDb.string(digitsCount: 2)) dB"
                              + "\n\t\("True Peak".localized): \(truePeakDb.string(digitsCount: 2)) dBTP"
                              + "\n\t\("Size".localized): \(Self.sizeString(from: b.size))"
                              + (mainSize != nil ? "\n\t\("Main Size".localized): \(LookUpAction.sizeString(from: mainSize!))" : ""),
                              at: p)
            } else {
                let mainSize = sheetView.mainFrame.bounds.size != Sheet.defaultBounds.size ? sheetView.mainFrame.size : nil
                rootView.show("Background".localized
                              + "\n\t\("Size".localized): \(Self.sizeString(from: b.size))"
                              + (mainSize != nil ? "\n\t\("Main Size".localized): \(LookUpAction.sizeString(from: mainSize!))" : ""), at: p)
            }
        } else {
            rootView.show("Background".localized
                          + "\n\t\("Size".localized): \(Self.sizeString(from: Sheet.defaultBounds.size))", at: p)
        }
    }
    
    func showDefinition(string: String,
                        range: Range<String.Index>,
                        in textView: SheetTextView, in sheetView: SheetView) {
        let np = textView.characterPosition(at: range.lowerBound)
        if let nstr = TextDictionary.string(from: string) {
            show(string: nstr,
                 rects: textView.transformedRects(with: range),
                 at: np, in: textView, in: sheetView)
        } else {
            show(string: "?",
                 rects: textView.transformedRects(with: range),
                 at: np, in: textView, in: sheetView)
        }
    }
    func show(string: String, rects: [Rect], at p: Point,
              in textView: SheetTextView, in sheetView: SheetView) {
        rootView.show(string,
                      rects: rects.map { sheetView.convertToWorld($0) },
                      textView.model.orientation)
    }
    
    static func sizeString(from size: Size) -> String {
        let width = size.width, height = size.height
        let widthStr = width.string(digitsCount: 1, enabledZeroInteger: false)
        let heightStr = height.string(digitsCount: 1, enabledZeroInteger: false)
        let iWidth = max(Int(width.rounded()), 1), iHeight = max(Int(height.rounded()), 1)
        let wScale = height == 0 ? "" : String(format: "%.3f:1", width / height)
        return if Rational(iWidth, iHeight) == Rational(37, 20) {
            "\(widthStr) x \(heightStr) \(wScale) 37:20"
        } else if Rational(iWidth, iHeight) == Rational(16, 9) {
            "\(widthStr) x \(heightStr) \(wScale) 16:9"
        } else if Rational(iWidth, iHeight) == Rational(16, 10) {
            "\(widthStr) x \(heightStr) \(wScale) 16:10"
        } else if Rational(iWidth, iHeight) == Rational(16, 11) {
            "\(widthStr) x \(heightStr) \(wScale) 16:11"
        } else if Rational(iWidth, iHeight) == Rational(4, 3) {
            "\(widthStr) x \(heightStr) \(wScale) 4:3"
        } else if width == height {
            "\(widthStr) x \(heightStr)"
        } else {
            "\(widthStr) x \(heightStr) \(wScale)"
        }
    }
}

final class ChangeToVerticalTextAction: InputKeyEventAction {
    let action: ChangeTextOrientationAction
    
    init(_ rootAction: RootAction) {
        action = ChangeTextOrientationAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.changeToVerticalText(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ChangeToHorizontalTextAction: InputKeyEventAction {
    let action: ChangeTextOrientationAction
    
    init(_ rootAction: RootAction) {
        action = ChangeTextOrientationAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.changeToHorizontalText(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ChangeTextOrientationAction: Action {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func changeToVerticalText(with event: InputKeyEvent) {
        changeTextOrientation(.vertical, with: event)
    }
    func changeToHorizontalText(with event: InputKeyEvent) {
        changeTextOrientation(.horizontal, with: event)
    }
    func changeTextOrientation(_ orientation: Orientation, with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        switch event.phase {
        case .began:
            defer {
                rootView.updateTextCursor()
            }
            rootView.cursor = .arrow
            
            let p = rootView.convertScreenToWorld(event.screenPoint)
            guard let sheetView = rootView.madeSheetView(at: p) else { return }
            if sheetView.model.score.enabled {
                rootAction.keepOut(with: event)
                return
            }
            
            if sheetView.containsSelectedText(sheetView.convertFromWorld(p),
                                              scale: rootView.screenToWorldScale) {
                var tivs = [IndexValue<Text>]()
                for ti in sheetView.selectedTextIs {
                    var text = sheetView.model.texts[ti]
                    text.orientation = orientation
                    tivs.append(IndexValue(value: text, index: ti))
                }
                if !tivs.isEmpty {
                    sheetView.newUndoGroup()
                    sheetView.replace(tivs)
                }
            } else {
                rootAction.textAction.begin(atScreen: event.screenPoint)
                
                var isNewUndoGroup = true
                if !sheetView.model.selection.isEmpty {
                    sheetView.newUndoGroup()
                    isNewUndoGroup = false
                    sheetView.doSet(SheetSelection.empty)
                }
                
                if let aTextView = rootAction.textAction.editingTextView,
                   !aTextView.isHiddenSelectedRange,
                   let i = sheetView.textsView.elementViews.firstIndex(of: aTextView) {
                    
                    rootAction.textAction.endInputKey(isUnmarkText: true, isRemoveText: false)
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
                        
                        if isNewUndoGroup {
                            sheetView.newUndoGroup()
                        }
                        sheetView.replace([IndexValue(value: text, index: i)])
                    }
                } else {
                    let sheetP = sheetView.convertFromWorld(p)
                    rootAction.textAction.appendEmptyText(screenPoint: event.screenPoint,
                                                    at: sheetP,
                                                    orientation: orientation,
                                                    in: sheetView)
                }
            }
            
            rootView.updateSelectedFrame()
            rootView.updateFinding(at: p)
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class ChangeToSuperscriptAction: InputKeyEventAction {
    let action: ChangeTextScriptAction
    
    init(_ rootAction: RootAction) {
        action = ChangeTextScriptAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.changeScripst(true, with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ChangeToSubscriptAction: InputKeyEventAction {
    let action: ChangeTextScriptAction
    
    init(_ rootAction: RootAction) {
        action = ChangeTextScriptAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.changeScripst(false, with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ChangeTextScriptAction: Action {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func changeScripst(_ isSuper: Bool, with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        func moveCharacter(isSuper: Bool, from c: Character) -> Character? {
            if isSuper {
                if c.isSuperscript {
                    nil
                } else if c.isSubscript {
                    c.fromSubscript
                } else {
                    c.toSuperscript
                }
            } else {
                if c.isSuperscript {
                    c.fromSuperscript
                } else if c.isSubscript {
                    nil
                } else {
                    c.toSubscript
                }
            }
        }
        
        switch event.phase {
        case .began:
            defer {
                rootView.updateTextCursor()
            }
            rootView.cursor = .arrow
            
            let p = rootView.convertScreenToWorld(event.screenPoint)
            
            if let sheetView = rootView.sheetView(at: p),
               let (textView, _, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale),
               textView.selectedRange(at: textView.convertFromWorld(p)) != nil {
                
                var isNewUndoGroup = true
                for (j, textView) in sheetView.textsView.elementViews.enumerated() {
                    let string = textView.model.string
                    for range in textView.selectedRanges {
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
            } else {
                rootAction.textAction.begin(atScreen: event.screenPoint)
                
                guard let sheetView = rootView.sheetView(at: p) else { return }
                if let aTextView = rootAction.textAction.editingTextView,
                   !aTextView.isHiddenSelectedRange,
                   let ai = sheetView.textsView.elementViews.firstIndex(of: aTextView) {
                    
                    rootAction.textAction.endInputKey(isUnmarkText: true, isRemoveText: true)
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
            
            rootView.updateSelectedFrame()
            rootView.updateFinding(at: p)
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class InputTextAction: InputTextEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    func cancelTasks() {
        inputKeyTimer.cancel()
    }
    
    var editingSheetView: SheetView? {
        get { rootView.editingSheetView }
        set { rootView.editingSheetView = newValue }
    }
    var editingTextView: SheetTextView? {
        get { rootView.editingTextView }
        set { rootView.editingTextView = newValue }
    }
    
    var isMovedCursor = true
    
    enum InputKeyEditType {
        case insert, remove, moveCursor, none
    }
    private(set) var inputType = InputKeyEditType.none
    private var inputKeyTimer = OneshotTimer(), isInputtingKey = false
    private var captureString = "", captureOrigin: Point?,
                captureSize: Double?, captureWidthCount: Double?,
                captureOrigins = [Point](), captureSheetSelection: SheetSelection?,
                isFirstInputKey = false
    
    func begin(atScreen sp: Point) {
        guard rootView.isEditingSheet else { return }
        let p = rootView.convertScreenToWorld(sp)
        
        rootView.textCursorNode.isHidden = true
        rootView.textMaxTypelineWidthNode.isHidden = true
        
        guard let sheetView = rootView.madeSheetView(at: p) else { return }
        let sheetP = sheetView.convertFromWorld(p)
        if !isMovedCursor, let eTextView = editingTextView,
           sheetView.textsView.elementViews.contains(eTextView) {
            
        } else if let (textView, _, _, sri) = sheetView.textTuple(at: sheetP, scale: rootView.screenToWorldScale) {
            if isMovedCursor {
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
    
    func flow(with event: InputTextEvent) {
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
        if rootAction.oldInputTextKeys.isEmpty && !Cursor.isHidden {
            rootView.cursor = rootView.defaultCursor
        }
    }
    func stopInputKey(isEndEdit: Bool = true) {
        sendEnd()
        cancelInputKey(isEndEdit: isEndEdit)
        endInputKey(isUnmarkText: true, isRemoveText: true)
    }
    func beginInputKey(_ event: InputTextEvent) {
        guard rootView.isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        if !event.isRepeat, let sheetView = rootView.sheetView(at: p),
           sheetView.model.score.enabled,
           sheetView.scoreView.containsMainFrame(sheetView.scoreView.convertFromWorld(p),
                                                 scale: rootView.screenToWorldScale) {
            let scoreView = sheetView.scoreView
            let scoreP = scoreView.convertFromWorld(p)
            
            let key = (event.inputKeyType.name
                .applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? "").lowercased()
            func appendLyric(atPit pitI: Int, atNote noteI: Int, isNewUndoGroup: Bool = true) {
                var note = scoreView.model.notes[noteI]
                var lyric = note.pits[pitI].lyric, pitI = pitI
                let oPit = note.pits[pitI]
                for (nPitI, pit) in note.pits.enumerated().reversed() {
                    if pit.beat == oPit.beat && pit.pitch == oPit.pitch {
                        lyric = pit.lyric
                        pitI = nPitI
                        break
                    }
                }
                if event.inputKeyType == .delete, !lyric.isEmpty {
                    lyric.removeLast()
                } else if event.inputKeyType.isText {
                    if lyric == "[" || lyric == "]" {
                        lyric = ""
                    }
                    lyric += key
                }
                if lyric != note.pits[pitI].lyric {
                    rootAction.closeLookingUpAndStop(at: p)
                    
                    if note.isRendableFromLyric {
                        note.replace(lyric: lyric, at: pitI, tempo: scoreView.model.tempo)
                    } else {
                        note.pits[pitI].lyric = lyric
                    }
                    if isNewUndoGroup {
                        sheetView.newUndoGroup()
                        sheetView.unselect()
                        rootView.unselectAllAndNewUndoGroupIfNeeded()
                    }
                    sheetView.replace(note, at: noteI)
                }
            }
            let beat = scoreView.beat(atX: scoreP.x, interval: rootView.currentBeatInterval)
            let pitch = scoreView.pitch(atY: scoreP.y, interval: rootView.currentPitchInterval)
            func lNoteI() -> (Bool, Int)? {
                if let i = scoreView.model.notes.firstIndex(where: {
                    $0.beatRange.end == beat && $0.containsLyric
                    && abs(($0.pits.last!.pitch + $0.pitch) - pitch) <= 6
                }) {
                    return (true, i)
                } else if let noteI = scoreView.noteIndex(at: scoreP, scale: rootView.screenToWorldScale) {
                    return (false, noteI)
                } else {
                    return nil
                }
            }
            if let (noteI, pitI) = scoreView.noteAndPitI(at: scoreP, scale: rootView.screenToWorldScale) {
                appendLyric(atPit: pitI, atNote: noteI)
            } else if let (isPitch, noteI) = lNoteI(),
                      event.inputKeyType.isText {
                var pit = scoreView.splittedPit(at: scoreP, at: noteI,
                                                beatInterval: rootView.currentBeatInterval,
                                                pitchInterval: rootView.currentPitchInterval)
                pit.lyric = ""
                var note = scoreView.model.notes[noteI]
                let pitI = scoreView.insertablePitIndex(atBeat: pit.beat, at: noteI)
                note.pits.insert(pit, at: pitI)
                var nPit = pit
                if isPitch {
                    nPit.pitch = pitch - note.pitch
                }
                note.pits.insert(nPit, at: pitI + 1)
                if pit.beat == note.beatRange.length
                    && (key != "^" && !note.pits[pitI].lyric.contains("^")) {
                    note.beatRange.end += .init(1, 2)
                }
                sheetView.newUndoGroup()
                sheetView.unselect()
                rootView.unselectAllAndNewUndoGroupIfNeeded()
                sheetView.replace([IndexValue(value: note, index: noteI)])
                appendLyric(atPit: pitI + 1, atNote: noteI, isNewUndoGroup: false)
            } else if event.inputKeyType.isText {
                sheetView.newUndoGroup()
                sheetView.unselect()
                rootView.unselectAllAndNewUndoGroupIfNeeded()
                sheetView.append(Note(beatRange: beat ..< beat + .init(1, 2), pitch: pitch, pits: [.init(stereo: .init(volm: 0.453125 * 1.25, pan: 0, id: .two))]))
                appendLyric(atPit: 0, atNote: scoreView.model.notes.count - 1, isNewUndoGroup: false)
            } else {
                rootView.cursor = .block
            }
            return
        }
        
        if !rootView.finding.isEmpty,
           rootView.editingFindingSheetView == nil {
            let p = rootView.convertScreenToWorld(event.screenPoint)
            guard let sheetView = rootView.sheetView(at: p) else { return }
            let sheetP = sheetView.convertFromWorld(p)
            
            if let (textView, _, si, _) = sheetView.textTuple(at: sheetP, scale: rootView.screenToWorldScale),
                let range = textView.model.string.ranges(of: rootView.finding.string)
                .first(where: { $0.contains(si) }) {
                
                rootView.isEditingFinding = true
                rootView.editingFindingSheetView = sheetView
                rootView.editingFindingTextView = textView
                rootView.editingFindingRange
                = textView.model.string.intRange(from: range)
                let str = textView.model.string
                var nstr = str
                nstr.removeSubrange(range)
                rootView.editingFindingOldString = str
                rootView.editingFindingOldRemovedString = nstr
            }
        }
        
        rootView.textCursorNode.isHidden = true
        rootView.textMaxTypelineWidthNode.isHidden = true
        
        if !isMovedCursor,
           let eSheetView = editingSheetView,
           let eTextView = editingTextView,
           eSheetView.textsView.elementViews.contains(eTextView) {
            
            inputKey(with: event, in: eTextView, in: eSheetView)
        } else {
            let sp = event.screenPoint
            let p = rootView.convertScreenToWorld(sp)
            
            rootAction.closeLookingUpAndStop(at: p)
            
            guard let sheetView = rootView.madeSheetView(at: p) else { return }
            let sheetP = sheetView.convertFromWorld(p)
            if let (textView, _, _, sri) = sheetView.textTuple(at: sheetP, scale: rootView.screenToWorldScale) {
                if isMovedCursor {
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
                appendEmptyText(event, at: sheetP, in: sheetView)
            } else {
                rootView.cursor = .block
            }
        }
    }
    func appendEmptyText(_ event: InputTextEvent, at sheetP: Point,
                         orientation: Orientation = .horizontal,
                         in sheetView: SheetView) {
        let text = Text(string: "", orientation: orientation,
                        size: rootView.sheetTextSize, origin: sheetP,
                        locale: TextInputContext.currentLocale)
        sheetView.newUndoGroup()
        sheetView.unselect()
        rootView.unselectAllAndNewUndoGroupIfNeeded()
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
    func appendEmptyText(screenPoint: Point, at sheetP: Point,
                         orientation: Orientation = .horizontal,
                         in sheetView: SheetView) {
        let text = Text(string: "", orientation: orientation,
                        size: rootView.sheetTextSize, origin: sheetP,
                        locale: TextInputContext.currentLocale)
        sheetView.newUndoGroup()
        sheetView.unselect()
        rootView.unselectAllAndNewUndoGroupIfNeeded()
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
            
            rootView.updateSelectedFrame()
            if let oldEditingSheetView = oldEditingSheetView {
                rootView.updateFinding(from: oldEditingSheetView)
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
            
            rootView.updateSelectedFrame()
            if let editingSheetView = editingSheetView {
                rootView.updateFinding(from: editingSheetView)
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
            if let i = sheetView.textsView.elementViews
                .firstIndex(of: textView) {
                rootView.unselectAllAndNewUndoGroupIfNeeded(withoutTextI: i, in: sheetView)
            } else {
                rootView.unselectAllAndNewUndoGroupIfNeeded()
            }
            
            self.captureString = textView.model.string
            self.captureSheetSelection = sheetView.model.selection
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
            if !rootView.finding.isEmpty {
                if let sheetView = editingSheetView,
                   let textView = editingTextView,
                   sheetView == rootView.editingFindingSheetView
                    && textView == rootView.editingFindingTextView,
                   let oldString = rootView.editingFindingOldString,
                   let oldRemovedString = rootView.editingFindingOldRemovedString {
                    let substring = oldRemovedString
                        .difference(to: textView.model.string)?.subString ?? ""
                    if substring != rootView.finding.string {
                        rootView.replaceFinding(from: substring,
                                                oldString: oldString,
                                                oldTextView: textView)
                    }
                }
                
                rootView.isEditingFinding = false
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
//                }
//            }
//        }
        
        // Spell Check
        
        let isChangeOption = captureOrigin != textView.model.origin
            || captureSize != textView.model.size
            || captureWidthCount != textView.model.widthCount
        
        if isFirstInputKey {
            isFirstInputKey = false
        } else if isNewUndoGroup && (value != nil || isChangeOption) {
            sheetView.newUndoGroup()
        }
        
        let sheetSelection = sheetView.model.selection
        if let captureSheetSelection, captureSheetSelection != sheetSelection {
            sheetView.capture(old: captureSheetSelection)
            self.captureSheetSelection = sheetSelection
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
            rootView.updateSelectedFrame()
            rootView.updateFinding(from: sheetView)
        }
    }
    
    func cut(at p: Point) {
        guard let sheetView = rootView.madeSheetView(at: p) else { return }
        let sheetP = sheetView.convertFromWorld(p)
        guard let (textView, ti, _, _) = sheetView.textTuple(at: sheetP, scale: rootView.screenToWorldScale) else { return }
        
        guard let range = textView.selectedRange(at: textView.convertFromWorld(p)) else { return }
        
        var removedText = textView.model
        removedText.string = String(removedText.string[range])
        let ssValue = SheetValue(texts: [removedText], isSelected: false)
        
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
        let captureSheetSelection = sheetView.model.selection
        editingTextView = textView
        editingSheetView = sheetView
        textView.removeCharacters(in: removeRange)
        textView.unmark()
        if let value = captureString.difference(to: textView.model.string) {
            sheetView.newUndoGroup()
            if captureSheetSelection != sheetView.model.selection {
                sheetView.capture(old: captureSheetSelection)
            }
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
            Pasteboard.shared.copiedObjects = [.sheetValue(nValue), .string(s)]
        } else {
            Pasteboard.shared.copiedObjects = [.sheetValue(nValue)]
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
                let sp = rootView.convertWorldToScreen(osp)
                if sp != rootView.cursorPoint {
                    textView.node.moveCursor(to: sp)
                    rootView.isUpdateWithCursorPosition = false
                    rootView.cursorPoint = sp
                    rootView.isUpdateWithCursorPosition = true
                }
            }
            return
        }
        
        if isUpdateCursor {
            let osp = textView.convertToWorld(p)
            let sp = rootView.convertWorldToScreen(osp)
            textView.node.moveCursor(to: sp)
            rootView.isUpdateWithCursorPosition = false
            rootView.cursorPoint = sp
            rootView.isUpdateWithCursorPosition = true
        }
        
        rootView.updateSelectedFrame()
        rootView.updateFinding(from: sheetView)
    }
    
    func characterIndex(for point: Point) -> String.Index? {
        guard let textView = editingTextView else { return nil }
        let sp = rootView.convertScreenToWorld(point)
        let p = textView.convertFromWorld(sp)
        return textView.characterIndex(for: p)
    }
    func characterRatio(for point: Point) -> Double? {
        guard let textView = editingTextView else { return nil }
        let sp = rootView.convertScreenToWorld(point)
        let p = textView.convertFromWorld(sp)
        return textView.characterRatio(for: p)
    }
    func characterPosition(at i: String.Index) -> Point? {
        guard let textView = editingTextView else { return nil }
        let p = textView.characterPosition(at: i)
        let sp = textView.convertToWorld(p)
        return rootView.convertWorldToScreen(sp)
    }
    func characterBasePosition(at i: String.Index) -> Point? {
        guard let textView = editingTextView else { return nil }
        let p = textView.characterBasePosition(at: i)
        let sp = textView.convertToWorld(p)
        return rootView.convertWorldToScreen(sp)
    }
    func characterBounds(at i: String.Index) -> Rect? {
        guard let textView = editingTextView,
              let rect = textView.characterBounds(at: i) else { return nil }
        let sRect = textView.convertToWorld(rect)
        return rootView.convertWorldToScreen(sRect)
    }
    func baselineDelta(at i: String.Index) -> Double? {
        guard let textView = editingTextView else { return nil }
        return textView.baselineDelta(at: i)
    }
    func firstRect(for range: Range<String.Index>) -> Rect? {
        guard let textView = editingTextView,
              let rect = textView.firstRect(for: range) else { return nil }
        let sRect = textView.convertToWorld(rect)
        return rootView.convertWorldToScreen(sRect)
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
        
        if rootAction.modifierKeys == .shift {
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
        
        if rootAction.modifierKeys == .shift {
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
            if let editingTextView {
                deleteBackward(in: editingTextView)
            }
        }
        
        lastInputEventType = .deleteBackward
    }
    func deleteForward() {
        if inputType != .remove {
            endInputKey()
            inputType = .remove
        }
        if let editingTextView {
            deleteForward(in: editingTextView)
        }
        lastInputEventType = .deleteForward
    }
    func deleteBackward(from range: Range<String.Index>? = nil, in textView: SheetTextView) {
        if let range = range {
            textView.removeCharacters(in: range)
            return
        }
        guard let deleteRange = textView.selectedRange else { return }
        
        if textView.deleteWithSelected() {
            return
        }
        
        if deleteRange.isEmpty {
            let string = textView.model.string
            guard deleteRange.lowerBound > string.startIndex else { return }
            let nsi = textView.typesetter.index(before: deleteRange.lowerBound)
            let nRange = nsi ..< deleteRange.lowerBound
            let nnRange = string.rangeOfComposedCharacterSequences(for: nRange)
            textView.removeCharacters(in: nnRange)
        } else {
            textView.removeCharacters(in: deleteRange)
        }
    }
    func deleteForward(from range: Range<String.Index>? = nil, in textView: SheetTextView) {
        if let range = range {
            textView.removeCharacters(in: range)
            return
        }
        guard let deleteRange = textView.selectedRange else { return }
        
        if textView.deleteWithSelected() {
            return
        }
        
        if deleteRange.isEmpty {
            let string = textView.model.string
            guard deleteRange.lowerBound < string.endIndex else { return }
            let nei = textView.typesetter.index(after: deleteRange.lowerBound)
            let nRange = deleteRange.lowerBound ..< nei
            let nnRange = string.rangeOfComposedCharacterSequences(for: nRange)
            textView.removeCharacters(in: nnRange)
        } else {
            textView.removeCharacters(in: deleteRange)
        }
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
