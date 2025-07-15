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

import struct Foundation.Data
import struct Foundation.UUID

struct ColorPathValue {
    var paths: [Path], lineType: Node.LineType?, fillType: Node.FillType?
}

struct CopiedSheetsValue: Equatable {
    var deltaPoint = Point()
    var sheetIDs = [IntPoint: UUID]()
}
extension CopiedSheetsValue: Protobuf {
    init(_ pb: PBCopiedSheetsValue) throws {
        deltaPoint = try Point(pb.deltaPoint)
        sheetIDs = try [IntPoint: UUID](pb.sheetIds)
    }
    var pb: PBCopiedSheetsValue {
        .with {
            $0.deltaPoint = deltaPoint.pb
            $0.sheetIds = sheetIDs.pb
        }
    }
}
extension CopiedSheetsValue: Codable {}

struct PlanesValue: Codable {
    var planes: [Plane]
}
extension PlanesValue: Protobuf {
    init(_ pb: PBPlanesValue) throws {
        planes = try pb.planes.map { try Plane($0) }
    }
    var pb: PBPlanesValue {
        .with {
            $0.planes = planes.map { $0.pb }
        }
    }
}

struct NotesValue: Codable {
    var notes: [Note]
    var deltaPitch: Rational
}
extension NotesValue: Protobuf {
    init(_ pb: PBNotesValue) throws {
        notes = try pb.notes.map { try Note($0) }
        deltaPitch = (try? .init(pb.deltaPitch)) ?? 0
    }
    var pb: PBNotesValue {
        .with {
            $0.notes = notes.map { $0.pb }
            $0.deltaPitch = deltaPitch.pb
        }
    }
}

struct InteroptionsValue: Codable {
    var ids: [InterOption]
    var sheetID: UUID
    var rootKeyframeIndex: Int
}
extension InteroptionsValue: Protobuf {
    init(_ pb: PBInterOptionsValue) throws {
        ids = try pb.ids.map { try InterOption($0) }
        sheetID = try UUID(pb.sheetID)
        rootKeyframeIndex = Int(pb.rootKeyframeIndex)
    }
    var pb: PBInterOptionsValue {
        .with {
            $0.ids = ids.map { $0.pb }
            $0.sheetID = sheetID.pb
            $0.rootKeyframeIndex = Int64(rootKeyframeIndex)
        }
    }
}

enum PastableObject: Sendable {
    case copiedSheetsValue(_ copiedSheetsValue: CopiedSheetsValue)
    case sheetValue(_ sheetValue: SheetValue)
    case border(_ border: Border)
    case text(_ text: Text)
    case string(_ string: String)
    case picture(_ picture: Picture)
    case planesValue(_ planesValue: PlanesValue)
    case uuColor(_ uuColor: UUColor)
    case animation(_ animation: Animation)
    case ids(_ ids: InteroptionsValue)
    case score(_ score: Score)
    case content(_ content: Content)
    case image(_ image: Image)
    case beatRange(_ beatRange: Range<Rational>)
    case normalizationValue(_ normalizationValue: Double)
    case normalizationRationalValue(_ normalizationRationalValue: Rational)
    case notesValue(_ notesValue: NotesValue)
    case stereo(_ stereo: Stereo)
    case tone(_ tone: Tone)
}
extension PastableObject {
    static func typeName(with obj: Any) -> String {
        System.id + "." + String(describing: type(of: obj))
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
    }
    static func objectTypeName(with typeName: String) -> String {
        typeName.replacingOccurrences(of: System.id + ".", with: "")
    }
    static func objectTypeName<T>(with obj: T.Type) -> String {
        String(describing: obj)
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
    }
    struct PastableError: Error {}
    var typeName: String {
        switch self {
        case .copiedSheetsValue(let copiedSheetsValue):
             PastableObject.typeName(with: copiedSheetsValue)
        case .sheetValue(let sheetValue):
             PastableObject.typeName(with: sheetValue)
        case .border(let border):
             PastableObject.typeName(with: border)
        case .text(let text):
             PastableObject.typeName(with: text)
        case .string(let string):
             PastableObject.typeName(with: string)
        case .picture(let picture):
             PastableObject.typeName(with: picture)
        case .planesValue(let planesValue):
             PastableObject.typeName(with: planesValue)
        case .uuColor(let uuColor):
             PastableObject.typeName(with: uuColor)
        case .animation(let animation):
             PastableObject.typeName(with: animation)
        case .ids(let ids):
             PastableObject.typeName(with: ids)
        case .score(let score):
             PastableObject.typeName(with: score)
        case .content(let content):
             PastableObject.typeName(with: content)
        case .image(let image):
             PastableObject.typeName(with: image)
        case .beatRange(let beatRange):
             PastableObject.typeName(with: beatRange)
        case .normalizationValue(let normalizationValue):
             PastableObject.typeName(with: normalizationValue)
        case .normalizationRationalValue(let normalizationRationalValue):
             PastableObject.typeName(with: normalizationRationalValue)
        case .notesValue(let notesValue):
             PastableObject.typeName(with: notesValue)
        case .stereo(let stereo):
             PastableObject.typeName(with: stereo)
        case .tone(let tone):
             PastableObject.typeName(with: tone)
        }
    }
    init(data: Data, typeName: String) throws {
        let objectname = PastableObject.objectTypeName(with: typeName)
        switch objectname {
        case PastableObject.objectTypeName(with: CopiedSheetsValue.self):
            self = .copiedSheetsValue(try CopiedSheetsValue(serializedData: data))
        case PastableObject.objectTypeName(with: SheetValue.self):
            self = .sheetValue(try SheetValue(serializedData: data))
        case PastableObject.objectTypeName(with: Border.self):
            self = .border(try Border(serializedData: data))
        case PastableObject.objectTypeName(with: Text.self):
            self = .text(try Text(serializedData: data))
        case PastableObject.objectTypeName(with: String.self):
            if let string = String(data: data, encoding: .utf8) {
                self = .string(string)
            } else {
                throw PastableObject.PastableError()
            }
        case PastableObject.objectTypeName(with: Picture.self):
            self = .picture(try Picture(serializedData: data))
        case PastableObject.objectTypeName(with: PlanesValue.self):
            self = .planesValue(try PlanesValue(serializedData: data))
        case PastableObject.objectTypeName(with: UUColor.self):
            self = .uuColor(try UUColor(serializedData: data))
        case PastableObject.objectTypeName(with: Animation.self):
            self = .animation(try Animation(serializedData: data))
        case PastableObject.objectTypeName(with: InteroptionsValue.self):
            self = .ids(try InteroptionsValue(serializedData: data))
        case PastableObject.objectTypeName(with: Score.self):
            self = .score(try Score(serializedData: data))
        case PastableObject.objectTypeName(with: Content.self):
            self = .content(try Content(serializedData: data))
        case PastableObject.objectTypeName(with: Image.self):
            self = .image(try Image(serializedData: data))
        case PastableObject.objectTypeName(with: Range<Rational>.self):
            self = .beatRange(try RationalRange(serializedData: data).value)
        case PastableObject.objectTypeName(with: Double.self):
            self = .normalizationValue(try Double(serializedData: data))
        case PastableObject.objectTypeName(with: Rational.self):
            self = .normalizationRationalValue(try Rational(serializedData: data))
        case PastableObject.objectTypeName(with: NotesValue.self):
            self = .notesValue(try NotesValue(serializedData: data))
        case PastableObject.objectTypeName(with: Stereo.self):
            self = .stereo(try Stereo(serializedData: data))
        case PastableObject.objectTypeName(with: Tone.self):
            self = .tone(try Tone(serializedData: data))
        default:
            throw PastableObject.PastableError()
        }
    }
    var data: Data? {
        switch self {
        case .copiedSheetsValue(let copiedSheetsValue):
             try? copiedSheetsValue.serializedData()
        case .sheetValue(let sheetValue):
             try? sheetValue.serializedData()
        case .border(let border):
             try? border.serializedData()
        case .text(let text):
             try? text.serializedData()
        case .string(let string):
             string.data(using: .utf8)
        case .picture(let picture):
             try? picture.serializedData()
        case .planesValue(let planesValue):
             try? planesValue.serializedData()
        case .uuColor(let uuColor):
             try? uuColor.serializedData()
        case .animation(let animation):
             try? animation.serializedData()
        case .ids(let ids):
             try? ids.serializedData()
        case .score(let score):
             try? score.serializedData()
        case .content(let content):
             try? content.serializedData()
        case .image(let image):
             try? image.serializedData()
        case .beatRange(let beatRange):
             try? RationalRange(value: beatRange).serializedData()
        case .normalizationValue(let normalizationValue):
             try? normalizationValue.serializedData()
        case .normalizationRationalValue(let normalizationRationalValue):
             try? normalizationRationalValue.serializedData()
        case .notesValue(let notesValue):
             try? notesValue.serializedData()
        case .stereo(let stereo):
             try? stereo.serializedData()
        case .tone(let tone):
             try? tone.serializedData()
        }
    }
}
extension PastableObject: Protobuf {
    init(_ pb: PBPastableObject) throws {
        guard let value = pb.value else {
            throw ProtobufError()
        }
        switch value {
        case .copiedSheetsValue(let copiedSheetsValue):
            self = .copiedSheetsValue(try CopiedSheetsValue(copiedSheetsValue))
        case .sheetValue(let sheetValue):
            self = .sheetValue(try SheetValue(sheetValue))
        case .border(let border):
            self = .border(try Border(border))
        case .text(let text):
            self = .text(try Text(text))
        case .string(let string):
            self = .string(string)
        case .picture(let picture):
            self = .picture(try Picture(picture))
        case .planesValue(let planesValue):
            self = .planesValue(try PlanesValue(planesValue))
        case .uuColor(let uuColor):
            self = .uuColor(try UUColor(uuColor))
        case .animation(let animation):
            self = .animation(try Animation(animation))
        case .ids(let ids):
            self = .ids(try InteroptionsValue(ids))
        case .score(let score):
            self = .score(try Score(score))
        case .content(let content):
            self = .content(try Content(content))
        case .image(let image):
            self = .image(try Image(image))
        case .beatRange(let beatRange):
            self = .beatRange(try RationalRange(beatRange).value)
        case .normalizationValue(let normalizationValue):
            self = .normalizationValue(normalizationValue)
        case .normalizationRationalValue(let normalizationRationalValue):
            self = .normalizationRationalValue(try Rational(normalizationRationalValue))
        case .notesValue(let notesValue):
            self = .notesValue(try NotesValue(notesValue))
        case .stereo(let stereo):
            self = .stereo(try Stereo(stereo))
        case .tone(let tone):
            self = .tone(try Tone(tone))
        }
    }
    var pb: PBPastableObject {
        .with {
            switch self {
            case .copiedSheetsValue(let copiedSheetsValue):
                $0.value = .copiedSheetsValue(copiedSheetsValue.pb)
            case .sheetValue(let sheetValue):
                $0.value = .sheetValue(sheetValue.pb)
            case .border(let border):
                $0.value = .border(border.pb)
            case .text(let text):
                $0.value = .text(text.pb)
            case .string(let string):
                $0.value = .string(string)
            case .picture(let picture):
                $0.value = .picture(picture.pb)
            case .planesValue(let planesValue):
                $0.value = .planesValue(planesValue.pb)
            case .uuColor(let uuColor):
                $0.value = .uuColor(uuColor.pb)
            case .animation(let animation):
                $0.value = .animation(animation.pb)
            case .ids(let ids):
                $0.value = .ids(ids.pb)
            case .score(let score):
                $0.value = .score(score.pb)
            case .content(let content):
                $0.value = .content(content.pb)
            case .image(let image):
                $0.value = .image(image.pb)
            case .beatRange(let beatRange):
                $0.value = .beatRange(RationalRange(value: beatRange).pb)
            case .normalizationValue(let normalizationValue):
                $0.value = .normalizationValue(normalizationValue)
            case .normalizationRationalValue(let normalizationRationalValue):
                $0.value = .normalizationRationalValue(normalizationRationalValue.pb)
            case .notesValue(let notesValue):
                $0.value = .notesValue(notesValue.pb)
            case .stereo(let stereo):
                $0.value = .stereo(stereo.pb)
            case .tone(let tone):
                $0.value = .tone(tone.pb)
            }
        }
    }
}
extension PastableObject: Codable {
    private enum CodingTypeKey: String, Codable {
        case copiedSheetsValue = "0"
        case sheetValue = "1"
        case border = "2"
        case text = "3"
        case string = "4"
        case picture = "5"
        case planesValue = "6"
        case uuColor = "7"
        case animation = "8"
        case ids = "9"
        case score = "10"
        case content = "16"
        case image = "20"
        case beatRange = "11"
        case normalizationValue = "12"
        case normalizationRationalValue = "15"
        case notesValue = "13"
        case stereo = "22"
        case tone = "14"
    }
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let key = try container.decode(CodingTypeKey.self)
        switch key {
        case .copiedSheetsValue:
            self = .copiedSheetsValue(try container.decode(CopiedSheetsValue.self))
        case .sheetValue:
            self = .sheetValue(try container.decode(SheetValue.self))
        case .border:
            self = .border(try container.decode(Border.self))
        case .text:
            self = .text(try container.decode(Text.self))
        case .string:
            self = .string(try container.decode(String.self))
        case .picture:
            self = .picture(try container.decode(Picture.self))
        case .planesValue:
            self = .planesValue(try container.decode(PlanesValue.self))
        case .uuColor:
            self = .uuColor(try container.decode(UUColor.self))
        case .animation:
            self = .animation(try container.decode(Animation.self))
        case .ids:
            self = .ids(try container.decode(InteroptionsValue.self))
        case .score:
            self = .score(try container.decode(Score.self))
        case .content:
            self = .content(try container.decode(Content.self))
        case .image:
            self = .image(try container.decode(Image.self))
        case .beatRange:
            self = .beatRange(try container.decode(Range<Rational>.self))
        case .normalizationValue:
            self = .normalizationValue(try container.decode(Double.self))
        case .normalizationRationalValue:
            self = .normalizationRationalValue(try container.decode(Rational.self))
        case .notesValue:
            self = .notesValue(try container.decode(NotesValue.self))
        case .stereo:
            self = .stereo(try container.decode(Stereo.self))
        case .tone:
            self = .tone(try container.decode(Tone.self))
        }
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .copiedSheetsValue(let copiedSheetsValue):
            try container.encode(CodingTypeKey.copiedSheetsValue)
            try container.encode(copiedSheetsValue)
        case .sheetValue(let sheetValue):
            try container.encode(CodingTypeKey.sheetValue)
            try container.encode(sheetValue)
        case .border(let border):
            try container.encode(CodingTypeKey.border)
            try container.encode(border)
        case .text(let text):
            try container.encode(CodingTypeKey.text)
            try container.encode(text)
        case .string(let string):
            try container.encode(CodingTypeKey.string)
            try container.encode(string)
        case .picture(let picture):
            try container.encode(CodingTypeKey.picture)
            try container.encode(picture)
        case .planesValue(let planesValue):
            try container.encode(CodingTypeKey.picture)
            try container.encode(planesValue)
        case .uuColor(let uuColor):
            try container.encode(CodingTypeKey.uuColor)
            try container.encode(uuColor)
        case .animation(let animation):
            try container.encode(CodingTypeKey.animation)
            try container.encode(animation)
        case .ids(let ids):
            try container.encode(CodingTypeKey.ids)
            try container.encode(ids)
        case .score(let score):
            try container.encode(CodingTypeKey.score)
            try container.encode(score)
        case .content(let content):
            try container.encode(CodingTypeKey.content)
            try container.encode(content)
        case .image(let image):
            try container.encode(CodingTypeKey.image)
            try container.encode(image)
        case .beatRange(let beatRange):
            try container.encode(CodingTypeKey.beatRange)
            try container.encode(beatRange)
        case .normalizationValue(let normalizationValue):
            try container.encode(CodingTypeKey.normalizationValue)
            try container.encode(normalizationValue)
        case .normalizationRationalValue(let normalizationRationalValue):
            try container.encode(CodingTypeKey.normalizationRationalValue)
            try container.encode(normalizationRationalValue)
        case .notesValue(let notesValue):
            try container.encode(CodingTypeKey.notesValue)
            try container.encode(notesValue)
        case .stereo(let stereo):
            try container.encode(CodingTypeKey.stereo)
            try container.encode(stereo)
        case .tone(let tone):
            try container.encode(CodingTypeKey.tone)
            try container.encode(tone)
        }
    }
}
extension PastableObject {
    enum FileType: FileTypeProtocol, CaseIterable {
        case skp
        var name: String { "Pastable Object" }
        var utType: UTType { UTType(exportedAs: "\(System.id).rasenp") }
    }
}

final class CutAction: InputKeyEventAction {
    let action: PastableAction
    
    init(_ rootAction: RootAction) {
        action = PastableAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.cut(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class CopyAction: InputKeyEventAction {
    let action: PastableAction
    
    init(_ rootAction: RootAction) {
        action = PastableAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.copy(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class PasteAction: InputKeyEventAction {
    let action: PastableAction
    
    init(_ rootAction: RootAction) {
        action = PastableAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.paste(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class PastableAction: Action {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum CopiableType {
        case cut, copy, paste
    }
    var type = CopiableType.cut
    var snapLineNode = Node(fillType: .color(.subSelected))
    var selectingLineNode = Node(lineWidth: 1.5)
    var firstScale = 1.0, editingP = Point(), editingSP = Point()
    var pasteObject = PastableObject.sheetValue(SheetValue())
    var isEditingText = false
    
    func updateNode() {
        if selectingLineNode.children.isEmpty {
            selectingLineNode.lineWidth = rootView.worldLineWidth
        } else {
            let w = rootView.worldLineWidth
            for node in selectingLineNode.children {
                node.lineWidth = w
            }
            for node in pasteSheetNode.children {
                node.lineWidth = w
            }
        }
        if isEditingSheet {
            switch type {
            case .cut: updateWithCopy(for: editingP, isSendPasteboard: false,
                                      isCutColor: true)
            case .copy: updateWithCopy(for: editingP, isSendPasteboard: true,
                                       isCutColor: false)
            case .paste:
                let p = rootView.convertScreenToWorld(editingSP)
                updateWithPaste(at: p, atScreen: editingSP, .changed)
            }
        }
    }
    
    @discardableResult
    func updateWithCopy(for p: Point, isSendPasteboard: Bool, isCutColor: Bool) -> Bool {
        if let sheetView = rootView.sheetView(at: p),
           sheetView.animationView.containsTimeline(sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale),
           let ki = sheetView.animationView.keyframeIndex(at: sheetView.convertFromWorld(p)) {
            
            let animationView = sheetView.animationView
            
            let isSelected = animationView.selectedFrameIndexes.contains(ki)
            let indexes = isSelected ?
                animationView.selectedFrameIndexes.sorted() : [ki]
            var beat: Rational = 0
            let kfs = indexes.map {
                var kf = animationView.model.keyframes[$0]
                let nextBeat = $0 + 1 < animationView.model.keyframes.count ? animationView.model.keyframes[$0 + 1].beat : animationView.model.beatRange.upperBound
                let dBeat = nextBeat - kf.beat
                kf.beat = beat
                beat += dBeat
                return kf
            }
            
            Pasteboard.shared.copiedObjects = [.animation(Animation(keyframes: kfs))]
            
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = rootView.worldLineWidth
            let rects = indexes
                .compactMap { animationView.transformedKeyframeBounds(at: $0) }
            selectingLineNode.path = Path(rects.map { Pathline(sheetView.convertToWorld($0)) })
        } else if rootView.isSelectSelectedNoneCursor(at: p), !rootView.selections.isEmpty {
            if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled,
               sheetView.scoreView.contains(sheetView.scoreView.convertFromWorld(p),
                                            scale: rootView.screenToWorldScale) {//lassoCopy
                
                let scoreView = sheetView.scoreView
                let nis = sheetView.noteIndexes(from: rootView.selections)
                if nis.count == 1 {
                    let note = scoreView.model.notes[nis[0]]
                    let pitIs = note.pits.count.range.filter {
                        let p = scoreView.convertToWorld(scoreView.pitPosition(atPit: $0, from: note))
                        return rootView.selections.contains(where: { $0.rect.contains(p) })
                    }
                    if !pitIs.isEmpty && note.pits.count > 1 {
                        var currentBeat: Rational = 0, nPits = [Pit]()
                        for pitI in pitIs {
                            let pit = note.pits[pitI]
                            let dBeat = (pitI + 1 < note.pits.count ?
                                         note.pits[pitI + 1].beat : note.beatRange.length) - pit.beat
                            nPits.append(.init(beat: currentBeat, pitch: pit.pitch, stereo: pit.stereo,
                                               tone: pit.tone, lyric: pit.lyric))
                            currentBeat += dBeat
                        }
                        let startBeat = note.pits[pitIs[0]].beat + note.beatRange.start
                        var nNote = Note(beatRange: startBeat ..< (startBeat + currentBeat),
                                         pitch: note.pitch, pits: nPits, id: .init())
                        
                        let scoreP = scoreView.convertFromWorld(p)
                        let pitchInterval = rootView.currentPitchInterval
                        let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                        let beatInterval = rootView.currentBeatInterval
                        let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
                        nNote.pitch -= pitch
                        nNote.beatRange.start -= beat
                        
                        if isSendPasteboard {
                            Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [nNote], deltaPitch: pitch))]
                        }
                        let rects = rootView.isSelectedText ?
                        rootView.selectedFrames :
                        rootView.selections.map { $0.rect } + rootView.selectedFrames
                        let lw = Line.defaultLineWidth * 2 / rootView.worldToScreenScale
                        selectingLineNode.children = rects.map {
                            Node(path: Path($0),
                                 lineWidth: lw,
                                 lineType: .color(.selected),
                                 fillType: .color(.subSelected))
                        } + note.pits.count.range.compactMap {
                            let p = scoreView.convertToWorld(scoreView.pitPosition(atPit: $0, from: note))
                            return rootView.selections.contains(where: { $0.rect.contains(p) }) ?
                            Node(path: .init(circleRadius: 1, position: p), fillType: .color(.selected)) :
                            nil
                        }
                        
                        return true
                    }
                }
                if !nis.isEmpty {
                    let scoreP = scoreView.convertFromWorld(p)
                    let pitchInterval = rootView.currentPitchInterval
                    let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                    let score = scoreView.model
                    let beatInterval = rootView.currentBeatInterval
                    let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
                    let notes: [Note] = nis.map {
                        var note = score.notes[$0]
                        note.pitch -= pitch
                        note.beatRange.start -= beat
                        return note
                    }
                    if isSendPasteboard {
                        Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: notes, deltaPitch: pitch))]
                    }
                    let rects = rootView.isSelectedText ?
                    rootView.selectedFrames :
                    rootView.selections.map { $0.rect } + rootView.selectedFrames
                    let lw = Line.defaultLineWidth * 2 / rootView.worldToScreenScale
                    selectingLineNode.children = rects.map {
                        Node(path: Path($0),
                             lineWidth: lw,
                             lineType: .color(.selected),
                             fillType: .color(.subSelected))
                    }
                }
            } else {
                if isSendPasteboard {
                    let se = LineAction(rootAction)
                    se.updateClipBoundsAndIndexRange(at: p)
                    if let r = rootView.selections.map({ $0.rect }).union() {
                        se.tempLine = Line(r) * Transform(translation: -se.centerOrigin)
                        se.lassoCopy(isRemove: false,
                                     isEnableLine: !rootView.isSelectedText,
                                     isEnablePlane: !rootView.isSelectedText,
                                     isSplitLine: false,
                                     selections: rootView.selections,
                                     at: rootView.roundedPoint(from: p))
                    }
                }
                let rects = rootView.isSelectedText ?
                rootView.selectedFrames :
                rootView.selections.map { $0.rect } + rootView.selectedFrames
                let lw = Line.defaultLineWidth * 2 / rootView.worldToScreenScale
                selectingLineNode.children = rects.map {
                    Node(path: Path($0),
                         lineWidth: lw,
                         lineType: .color(.selected),
                         fillType: .color(.subSelected))
                }
            }
            
            return true
        } else if rootView.containsLookingUp(at: p),
                  !rootView.lookingUpString.isEmpty {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.string(rootView.lookingUpString)]
            }
            
            let lw = Line.defaultLineWidth * 2 / rootView.worldToScreenScale
            selectingLineNode.children =
            [Node(path: rootView.lookingUpBoundsNode?.path ?? Path(),
                     lineWidth: lw,
                     lineType: .color(.selected),
                     fillType: .color(.subSelected))]
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let (textView, _, si, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
            if let node = rootView.findingNode(at: p) {
                if isSendPasteboard {
                    if let range = textView.model.string.ranges(of: rootView.finding.string)
                        .first(where: { $0.contains(si) }) {
                        
                        var text = textView.model
                        text.string = rootView.finding.string
                        let minP = textView.typesetter.characterPosition(at: range.lowerBound)
                        text.origin -= sheetView.convertFromWorld(p) - minP
                        Pasteboard.shared.copiedObjects = [.text(text),
                                                           .string(text.string)]
                    }
                }
                let scale = 1 / rootView.worldToScreenScale
                selectingLineNode.children = [Node(path: node.path,
                                                   lineWidth: Line.defaultLineWidth * scale,
                                                   lineType: .color(.selected),
                                                   fillType: .color(.subSelected))]
                return true
            } else if let result = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p)), result.isLastWarp,
                      let wcPath = textView.typesetter.warpCursorPath(at: textView.convertFromWorld(p)) {
                
                let x = result.offset +
                (textView.textOrientation == .horizontal ?
                 textView.model.origin.x : textView.model.origin.y)
                let origin = rootView.sheetFrame(with: rootView.sheetPosition(at: p)).origin
                let path =  wcPath * Transform(translation: textView.model.origin + origin)
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                selectingLineNode.lineWidth = rootView.worldLineWidth
                selectingLineNode.path = path
                
                let text = textView.model
                let border = Border(location: x,
                                    orientation: text.orientation.reversed())
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.border(border)]
                }
                return true
            }
            
            var text = textView.model
            text.origin -= sheetView.convertFromWorld(p)
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.text(text),
                                                   .string(text.string)]
            }
            let paths = textView.typesetter.allPaddingRects()
                .map { Path(textView.convertToWorld($0)) }
            let scale = 1 / rootView.worldToScreenScale
            selectingLineNode.children = paths.map {
                Node(path: $0,
                     lineWidth: Line.defaultLineWidth * scale,
                     lineType: .color(.selected),
                     fillType: .color(.subSelected))
            }
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let (_, textView) = sheetView.textIndexAndView(at: sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale),
                  textView.containsTimeline(textView.convertFromWorld(p), scale: rootView.screenToWorldScale),
                  let beatRange = textView.beatRange, let tf = textView.timelineFrame {
            
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.beatRange(beatRange)]
            }
            
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = rootView.worldLineWidth
            selectingLineNode.path = Path(textView.convertToWorld(tf))
        } else if let sheetView = rootView.sheetView(at: p),
                  let lineView = sheetView.lineTuple(at: sheetView.convertFromWorld(p),
                                                     scale: 1 / rootView.worldToScreenScale)?.lineView {
            let t = Transform(translation: -sheetView.convertFromWorld(p))
            let ssv = SheetValue(lines: [lineView.model],
                                 planes: [], texts: [],
                                 origin: sheetView.convertFromWorld(p),
                                 id: sheetView.id,
                                 rootKeyframeIndex: sheetView.model.animation.rootIndex) * t
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.sheetValue(ssv)]
            }
            
            let scale = 1 / rootView.worldToScreenScale
            let lw = Line.defaultLineWidth
            let selectedNode = Node(path: lineView.node.path * sheetView.node.localTransform,
                                    lineWidth: max(lw * 1.5, lw * 2.5 * scale, 1 * scale),
                                    lineType: .color(.selected))
            if sheetView.model.enabledAnimation {
                selectingLineNode.children = [selectedNode]
                + sheetView.animationView.interpolationNodes(from: [lineView.model.id], scale: scale)
                + sheetView.interporatedTimelineNodes(from: [lineView.model.id])
            } else {
                selectingLineNode.children = [selectedNode]
            }
            
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let ci = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                  scale: rootView.screenToWorldScale) {
            let contentView = sheetView.contentsView.elementViews[ci]
            let contentP = contentView.convertFromWorld(p)
            if contentView.containsTimeline(contentP, scale: rootView.screenToWorldScale),
               let beatRange = contentView.beatRange, let tf = contentView.timelineFrame {
                
                if isSendPasteboard {
                    if contentView.model.type.isAudio {
                        var content = contentView.model
                        content.origin -= sheetView.convertFromWorld(p)
                        Pasteboard.shared.copiedObjects = [.content(content)]
                    } else {
                        Pasteboard.shared.copiedObjects = [.beatRange(beatRange)]
                    }
                }
                
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                selectingLineNode.lineWidth = rootView.worldLineWidth
                selectingLineNode.path = Path(contentView.convertToWorld(tf))
            } else if let frame = contentView.imageFrame {
                if isSendPasteboard {
                    var content = contentView.model
                    content.origin -= sheetView.convertFromWorld(p)
                    Pasteboard.shared.copiedObjects = [.content(content)]
                }
                
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                selectingLineNode.lineWidth = rootView.worldLineWidth
                selectingLineNode.path = Path(sheetView.convertToWorld(frame))
            }
//        } else if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
//
        } else if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled,
                  let (noteI, result) = sheetView.scoreView
            .hitTestPoint(sheetView.scoreView.convertFromWorld(p), scale: rootView.screenToWorldScale / 2) {
            
            let scoreView = sheetView.scoreView
            let score = scoreView.model
            
            let nlw = max(0.5, 7 * rootView.screenToWorldScale)
            func show(_ ps: [Point]) {
                let node = Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                                path: Path(ps.map { Pathline(circleRadius: nlw, position: $0) }),
                                fillType: .color(.selected))
                selectingLineNode.children = [node]
            }
            
            switch result {
            case .pit(let pitI):
                let stereo = score.notes[noteI].pits[pitI].stereo
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.stereo(stereo)]
                }
                let ps = score.notes.flatMap { note in
                    note.pits.enumerated().compactMap {
                        $0.element.stereo.id == stereo.id ?
                        scoreView.pitPosition(atPit: $0.offset, from: note) : nil
                    }
                }
                show(ps)
            case .lyric:
                break
            case .even(let pitI):
                let note = score.notes[noteI]
                let tone = note.pits[pitI].tone
                let volm = tone.overtone.evenAmp
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.normalizationValue(volm)]
                }
                let ps = score.notes.flatMap { note in
                    note.pits.enumerated().compactMap {
                        $0.element.tone.id == tone.id ?
                        scoreView.pitPosition(atPit: $0.offset, from: note) : nil
                    }
                }
                show(ps)
            case .sprol(let pitI, _, _):
                let tone = score.notes[noteI].pits[pitI].tone
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.tone(tone)]
                }
                let ps = score.notes.flatMap { note in
                    scoreView.toneFrames(from: note).flatMap { (pitIs, f) in
                        pitIs.flatMap { pitI in
                            let pit = note.pits[pitI]
                            return pit.tone.id == tone.id ?
                                [scoreView.pitPosition(atPit: pitI, from: note)]
                                + pit.tone.spectlope.sprols.count.range.map {
                                    scoreView.sprolPosition(atSprol: $0, atPit: pitI,
                                                            from: note, atY: f.minY)
                                } : []
                        }
                    }
                }
                show(ps)
            case .allSprol(_, _, let toneY):
                let scoreP = scoreView.convertFromWorld(p)
                let beat: Double = scoreView.beat(atX: scoreP.x)
                
                let note = score.notes[noteI]
                let tone = note.tone(atBeat: beat - Double(note.beatRange.start))
                
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.tone(tone)]
                }
                let p0 = Point(scoreP.x, toneY)
                let p1 = Point(scoreP.x, toneY + score.notes[noteI].spectlopeHeight)
                let nps = [p0 + .init(0.125, 0), p0 - .init(0.125, 0),
                           p1 - .init(0.125, 0), p1 + .init(0.125, 0)]
                let ps = score.notes.flatMap { note in
                    scoreView.toneFrames(from: note).flatMap { (pitIs, f) in
                        pitIs.flatMap { pitI in
                            let pit = note.pits[pitI]
                            return pit.tone.id == tone.id ?
                            [scoreView.pitPosition(atPit: pitI, from: note)]
                            + pit.tone.spectlope.sprols.count.range.map {
                                scoreView.sprolPosition(atSprol: $0, atPit: pitI,
                                                        from: note, atY: f.minY)
                            } : []
                        }
                    }
                }
                let pathlines = [Pathline(nps.map { scoreView.node.convertToWorld($0) })]
                + ps.map { Pathline(circleRadius: nlw, position: scoreView.convertToWorld($0)) }
                let node = Node(path: Path(pathlines), fillType: .color(.selected))
                selectingLineNode.children = [node]
            case .spectlopeHeight:
                let note = score.notes[noteI]
                let toneFrames = scoreView.toneFrames(at: noteI)
                
                let node = Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                                path: .init(toneFrames.map { Edge($0.frame.minXMaxYPoint,
                                                                  $0.frame.maxXMaxYPoint) }),
                                lineWidth: rootView.worldLineWidth,
                                lineType: .color(.selected))
                selectingLineNode.children = [node]
                Pasteboard.shared.copiedObjects = [.normalizationValue(note.spectlopeHeight)]
            case .note, .startBeat, .endBeat, .mid:
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                let scoreP = scoreView.convertFromWorld(p)
                
                let pitchInterval = rootView.currentPitchInterval
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                let beatInterval = rootView.currentBeatInterval
                let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
                var note = score.notes[noteI]
                note.pitch -= pitch
                note.beatRange.start -= beat
                
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [note], deltaPitch: pitch))]
                }
                let lines = [scoreView.pointline(from: score.notes[noteI])]
                    .map { scoreView.convertToWorld($0) }
                selectingLineNode.children = lines.map {
                    Node(path: Path($0.controls.map { $0.point }),
                         lineWidth: rootView.worldLineWidth * 1.5,
                         lineType: .color(.selected))
                }
            }
            return true
        } else if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled,
                  sheetView.scoreView.contains(sheetView.scoreView.convertFromWorld(p),
                                               scale: rootView.screenToWorldScale) {
            let scoreView = sheetView.scoreView
            if let result = scoreView.hitTestOption(scoreView.convertFromWorld(p),
                                                    scale: rootView.screenToWorldScale) {
                switch result {
                case .keyBeat(let keyBeatI):
                    Pasteboard.shared.copiedObjects = [.border(.init(.vertical))]
                    
                    let keyBeat = scoreView.model.keyBeats[keyBeatI]
                    selectingLineNode.fillType = .color(.subSelected)
                    selectingLineNode.lineType = .color(.selected)
                    selectingLineNode.lineWidth = rootView.worldLineWidth
                    let edge = scoreView.convertToWorld(scoreView.keyBeatEdge(fromBeat: keyBeat))
                    selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
                    return true
                case .scale(_, let pitch):
                    Pasteboard.shared.copiedObjects = [.border(.init(.horizontal))]
                    
                    selectingLineNode.fillType = .color(.subSelected)
                    selectingLineNode.lineType = .color(.selected)
                    selectingLineNode.lineWidth = rootView.worldLineWidth
                    let edge = scoreView.convertToWorld(scoreView.scaleEdge(fromPitch: pitch))
                    selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
                    return true
                }
            }
        } else if let (sBorder, edge) = rootView.worldBorder(at: p) {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.border(sBorder)]
            }
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = rootView.worldLineWidth
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            return true
        } else if let (border, _, _, edge) = rootView.border(at: p) {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.border(border)]
            }
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = rootView.worldLineWidth
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            return true
        } else if !rootView.isDefaultUUColor(at: p) {
            let colorOwners = rootView.readColorOwners(at: p)
            if let fco = colorOwners.first {
                var mainPlanePath: Path?
                if isSendPasteboard {
                    let inP = fco.sheetView.convertFromWorld(p)
                    if let pi = fco.sheetView.planesView.firstIndex(at: inP) {
                        let planeView = fco.sheetView.planesView.elementViews[pi]
                        mainPlanePath = planeView.node.path
                        
                        let sheetValue = SheetValue(planes: [planeView.model],
                                                    origin: inP,
                                          id: fco.sheetView.id,
                                          rootKeyframeIndex: fco.sheetView.model.animation.rootIndex)
                        Pasteboard.shared.copiedObjects =
                            [.uuColor(rootView.uuColor(at: p)),
                             .sheetValue(sheetValue)]
                    } else {
                        Pasteboard.shared.copiedObjects =
                            [.uuColor(rootView.uuColor(at: p))]
                    }
                }
                
                let inP = fco.sheetView.convertFromWorld(p)
                let ids: [UUID] = if let pi = fco.sheetView.planesView.firstIndex(at: inP) {
                    [fco.sheetView.planesView.elementViews[pi].model.uuColor.id]
                } else {
                    []
                }
                
                let scale = 1 / rootView.worldToScreenScale
                selectingLineNode.children = colorOwners.reduce(into: [Node]()) {
                    let value = $1.colorPathValue(toColor: nil, color: .selected,
                                                  subColor: .subSelected)
                    $0 += value.paths.map {
                        Node(path: $0, lineWidth: Line.defaultLineWidth * 2 * scale,
                             lineType: value.lineType, fillType: value.fillType)
                    }
                } + (mainPlanePath != nil ? [
                    Node(path: mainPlanePath!, lineWidth: Line.defaultLineWidth * 4 * scale,
                         lineType: .color(.selected))
                ] :  [])
                + (fco.sheetView.model.enabledAnimation ?
                   fco.sheetView.interporatedTimelineNodes(fromColor: ids) : [])
                
                return true
            }
        }
        return false
    }
    
    @discardableResult
    func cut(at p: Point) -> Bool {
        func cutPit(fromPit pitIs: [Int], at noteI: Int,
                    from scoreView: ScoreView, _ sheetView: SheetView) -> Bool {
            let note = scoreView.model.notes[noteI]
            if !pitIs.isEmpty && note.pits.count > 1 && pitIs.count != note.pits.count {
                var currentBeat: Rational = 0, nPits = [Pit]()
                for pitI in pitIs {
                    let pit = note.pits[pitI]
                    let dBeat = (pitI + 1 < note.pits.count ?
                                 note.pits[pitI + 1].beat : note.beatRange.length) - pit.beat
                    nPits.append(.init(beat: currentBeat, pitch: pit.pitch, stereo: pit.stereo,
                                       tone: pit.tone, lyric: pit.lyric))
                    if dBeat > 0 {
                        currentBeat += dBeat
                    }
                }
                let startBeat = note.pits[pitIs[0]].beat + note.beatRange.start
                var nNote = Note(beatRange: startBeat ..< (startBeat + currentBeat),
                                 pitch: note.pitch, pits: nPits, id: .init())
                
                let scoreP = scoreView.convertFromWorld(p)
                let pitchInterval = rootView.currentPitchInterval
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                let beatInterval = rootView.currentBeatInterval
                let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
                nNote.pitch -= pitch
                nNote.beatRange.start -= beat
                
                Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [nNote], deltaPitch: pitch))]
                
                var pits = note.pits
                pits.remove(at: pitIs)
                let fBeat = pits[0].beat
                for i in pits.count.range {
                    pits[i].beat -= fBeat
                }
                var nnNote = note
                nnNote.beatRange = (nnNote.beatRange.start + fBeat) ..< note.beatRange.end
                nnNote.pits = pits
                
                sheetView.newUndoGroup()
                sheetView.replace(nnNote, at: noteI)
                
                sheetView.updatePlaying()
                return true
            }
            return false
        }
        
        if let sheetView = rootView.sheetView(at: p),
           sheetView.animationView.containsTimeline(sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale),
           let ki = sheetView.animationView.keyframeIndex(at: sheetView.convertFromWorld(p)) {
            
            let animationView = sheetView.animationView
            
            let isSelected = animationView.selectedFrameIndexes.contains(ki)
            var indexes = isSelected ?
                animationView.selectedFrameIndexes.sorted() : [ki]
            if indexes.last == animationView.model.keyframes.count {
                indexes.removeLast()
            }
            
            var beat: Rational = 0
            let kfs = indexes.map {
                var kf = animationView.model.keyframes[$0]
                let nextBeat = $0 + 1 < animationView.model.keyframes.count ? animationView.model.keyframes[$0 + 1].beat : animationView.model.beatRange.upperBound
                let dBeat = nextBeat - kf.beat
                kf.beat = beat
                beat += dBeat
                return kf
            }
            
            if isSelected {
                animationView.selectedFrameIndexes = []
            }
            sheetView.newUndoGroup(enabledKeyframeIndex: false)
            if indexes == animationView.model.keyframes.count.array {
                let keyframe = Keyframe(beat: 0)
                sheetView.insert([IndexValue(value: keyframe, index: 0)])
                sheetView.removeKeyframes(at: indexes)
                
                var option = sheetView.model.animation.option
                option.enabled = false
                sheetView.set(option)
                
                sheetView.rootKeyframeIndex = 0
            } else {
                sheetView.removeKeyframes(at: indexes)
            }
            rootView.updateSelects()

            Pasteboard.shared.copiedObjects = [.animation(Animation(keyframes: kfs))]
        } else if rootView.isSelectSelectedNoneCursor(at: p), !rootView.selections.isEmpty {
            if rootView.isSelectedText, rootView.selections.count == 1 {
                rootAction.textAction.cut(from: rootView.selections[0], at: p)
            } else {
                if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled,
                   sheetView.scoreView
                    .contains(sheetView.scoreView.convertFromWorld(p),
                               scale: rootView.screenToWorldScale) {
                    
                    let scoreView = sheetView.scoreView
                    let scoreP = scoreView.convertFromWorld(p)
                    let pitchInterval = rootView.currentPitchInterval
                    let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                    let nis = sheetView.noteIndexes(from: rootView.selections)
                    if nis.count == 1 {
                        let noteI = nis[0]
                        let note = scoreView.model.notes[noteI]
                        let pitIs = note.pits.count.range.filter {
                            let p = scoreView.convertToWorld(scoreView.pitPosition(atPit: $0, from: note))
                            return rootView.selections.contains(where: { $0.rect.contains(p) })
                        }
                        if cutPit(fromPit: pitIs, at: noteI, from: scoreView, sheetView) {
                            rootView.selections = []
                            return true
                        }
                    }
                    
                    if !nis.isEmpty {
                        let beatInterval = rootView.currentBeatInterval
                        let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
                        let score = scoreView.model
                        let notes: [Note] = nis.map {
                            var note = score.notes[$0]
                            note.pitch -= pitch
                            note.beatRange.start -= beat
                            return note
                        }
                        
                        Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: notes, deltaPitch: pitch))]
                        
                        sheetView.newUndoGroup()
                        sheetView.removeNote(at: nis)
                        
                        sheetView.updatePlaying()
                    }
                } else {
                    let se = LineAction(rootAction)
                    se.updateClipBoundsAndIndexRange(at: p)
                    if let r = rootView.selections.map({ $0.rect }).union() {
                        se.tempLine = Line(r) * Transform(translation: -se.centerOrigin)
                        se.lassoCopy(isRemove: true,
                                     isEnableLine: !rootView.isSelectedText,
                                     isEnablePlane: !rootView.isSelectedText,
                                     isSplitLine: false,
                                     selections: rootView.selections,
                                     at: rootView.roundedPoint(from: p))
                    }
                }
            }
            
            rootView.selections = []
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let (lineView, li) = sheetView
                    .lineTuple(at: sheetView.convertFromWorld(p),
                               scale: 1 / rootView.worldToScreenScale) {
            
            let t = Transform(translation: -sheetView.convertFromWorld(p))
            let ssv = SheetValue(lines: [lineView.model],
                                 planes: [], texts: [],
                                 origin: sheetView.convertFromWorld(p),
                                 id: sheetView.id,
                                 rootKeyframeIndex: sheetView.model.animation.rootIndex) * t
            Pasteboard.shared.copiedObjects = [.sheetValue(ssv)]
            
            if sheetView.model.enabledAnimation {
                let scale = 1 / rootView.worldToScreenScale
                let nodes = sheetView.animationView.interpolationNodes(from: [lineView.model.id], scale: scale,
                                                         removeLineIndex: li)
                if nodes.count > 1 {
                    selectingLineNode.children = nodes
                }
            }
            
            sheetView.newUndoGroup()
            sheetView.removeLines(at: [li])
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let (textView, ti, si, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
            if rootView.findingNode(at: p) != nil {
                if let range = textView.model.string.ranges(of: rootView.finding.string)
                    .first(where: { $0.contains(si) }) {
                    
                    var text = textView.model
                    text.string = rootView.finding.string
                    let minP = textView.typesetter.characterPosition(at: range.lowerBound)
                    text.origin -= sheetView.convertFromWorld(p) - minP
                    Pasteboard.shared.copiedObjects = [.text(text),
                                                       .string(text.string)]
                }
                
                rootView.replaceFinding(from: "")
                return true
            } else if let result = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p)), result.isLastWarp {
                let x = result.offset
                let widthCount = Typobute.maxWidthCount
                
                var text = textView.model
                if text.widthCount != widthCount {
                    text.widthCount = widthCount
                    
                    let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                    if let textFrame = text.frame,
                       !sb.contains(textFrame) {
                       
                        let nFrame = sb.clipped(textFrame)
                        text.origin += nFrame.origin - textFrame.origin
                    }
                    let border = Border(location: x,
                                        orientation: text.orientation.reversed())
                    Pasteboard.shared.copiedObjects = [.border(border)]
                    sheetView.newUndoGroup()
                    sheetView.replace([IndexValue(value: text, index: ti)])
                }
                return true
            }
            
            var text = textView.model
            text.origin -= sheetView.convertFromWorld(p)
            
            Pasteboard.shared.copiedObjects = [.text(text),
                                               .string(text.string)]
            
            let tbs = textView.typesetter.allRects()
            selectingLineNode.path = Path(tbs.map { Pathline(textView.convertToWorld($0)) })
            
            sheetView.newUndoGroup()
            sheetView.removeText(at: ti)
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let (ti, textView) = sheetView.textIndexAndView(at: sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale),
                  textView.containsTimeline(textView.convertFromWorld(p), scale: rootView.screenToWorldScale),
                  let beatRange = textView.beatRange {
                
            Pasteboard.shared.copiedObjects = [.beatRange(beatRange)]
            
            var text = textView.model
            text.timeOption = nil
            
            sheetView.newUndoGroup()
            sheetView.replace([IndexValue(value: text, index: ti)])
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let (ci, contentView) = sheetView.contentIndexAndView(at: sheetView.convertFromWorld(p),
                                                                        scale: rootView.screenToWorldScale) {
            if contentView.containsTimeline(contentView.convertFromWorld(p), scale: rootView.screenToWorldScale),
               let beatRange = contentView.beatRange, !contentView.model.type.isAudio {
                
                Pasteboard.shared.copiedObjects = [.beatRange(beatRange)]
                
                var content = contentView.model
                content.timeOption = nil
                
                sheetView.newUndoGroup()
                sheetView.replace(IndexValue(value: content, index: ci))
                return true
            } else {
                var content = sheetView.contentsView.elementViews[ci].model
                content.origin -= sheetView.convertFromWorld(p)
                
                Pasteboard.shared.copiedObjects = [.content(content)]
                
                sheetView.newUndoGroup()
                sheetView.removeContent(at: ci)
                
                sheetView.updatePlaying()
                return true
            }
        } else if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled,
                  let (noteI, result) = sheetView.scoreView
            .hitTestPoint(sheetView.scoreView.convertFromWorld(p), scale: rootView.screenToWorldScale) {
            
            let scoreView = sheetView.scoreView
            let score = scoreView.model
            switch result {
            case .pit(let pitI):
                if cutPit(fromPit: [pitI], at: noteI, from: scoreView, sheetView) {
                    return true
                }
                
                let scoreView = sheetView.scoreView
                let scoreP = scoreView.convertFromWorld(p)
                
                let pitchInterval = rootView.currentPitchInterval
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                let beatInterval = rootView.currentBeatInterval
                let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
                var note = score.notes[noteI]
                note.pitch -= pitch
                note.beatRange.start -= beat
                
                Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [note], deltaPitch: pitch))]
                
                sheetView.newUndoGroup()
                sheetView.removeNote(at: noteI)
                
                sheetView.updatePlaying()
                return true
                
            case .lyric:
                break
            case .even(let pitI):
                if !scoreView.model.notes[noteI].isEmpty {
                    var pits = score.notes[noteI].pits
                    pits.remove(at: pitI)
                    var note = score.notes[noteI]
                    if pits.isEmpty {
                        note.pits = [.init()]
                    } else {
                        note.pits = pits
                    }
                    
                    sheetView.newUndoGroup()
                    sheetView.replace(note, at: noteI)
                    
                    sheetView.updatePlaying()
                    return true
                }
            case .sprol(let pitI, let sprolI, _):
                let oldTone = score.notes[noteI].pits[pitI].tone
                var tone = oldTone
                if tone.spectlope.count <= 1 {
                    tone = .init()
                } else {
                    tone.spectlope.sprols.remove(at: sprolI)
                }
                tone.id = .init()
                
                let nis = (0 ..< score.notes.count).filter { score.notes[$0].pits.contains { $0.tone.id == oldTone.id } }
                
                let nivs = nis.map {
                    var note = score.notes[$0]
                    note.pits = note.pits.map {
                        if $0.tone.id == oldTone.id {
                            var pit = $0
                            pit.tone = tone
                            return pit
                        } else {
                            return $0
                        }
                    }
                    return IndexValue(value: note, index: $0)
                }
                
                sheetView.newUndoGroup()
                sheetView.replace(nivs)
                return true
            case .allSprol:
                break
            case .spectlopeHeight:
                var note = score.notes[noteI]
                if note.spectlopeHeight != Sheet.spectlopeHeight {
                    note.spectlopeHeight = Sheet.spectlopeHeight
                    sheetView.replace([IndexValue<Note>(value: note, index: noteI)])
                    Pasteboard.shared.copiedObjects = [.normalizationValue(note.spectlopeHeight)]
                    return true
                }
            case .note, .startBeat, .endBeat, .mid:
                let scoreP = scoreView.convertFromWorld(p)
                
                let pitchInterval = rootView.currentPitchInterval
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                let beatInterval = rootView.currentBeatInterval
                let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
                var note = score.notes[noteI]
                note.pitch -= pitch
                note.beatRange.start -= beat
                
                Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [note], deltaPitch: pitch))]
                
                sheetView.newUndoGroup()
                sheetView.removeNote(at: noteI)
                
                sheetView.updatePlaying()
                return true
            }
        } else if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled,
                  sheetView.scoreView.contains(sheetView.scoreView.convertFromWorld(p),
                                               scale: rootView.screenToWorldScale) {
            if let result = sheetView.scoreView
                .hitTestOption(sheetView.scoreView.convertFromWorld(p),
                               scale: rootView.screenToWorldScale) {
                switch result {
                case .keyBeat(let keyBeatI):
                    var option = sheetView.model.score.option
                    option.keyBeats.remove(at: keyBeatI)
                    
                    Pasteboard.shared.copiedObjects = [.border(.init(.vertical))]
                    
                    sheetView.newUndoGroup()
                    sheetView.set(option)
                    return true
                case .scale(let scaleI, _):
                    var option = sheetView.model.score.option
                    option.scales.remove(at: scaleI)
                    
                    Pasteboard.shared.copiedObjects = [.border(.init(.horizontal))]
                    
                    sheetView.newUndoGroup()
                    sheetView.set(option)
                    return true
                }
            } else if sheetView.scoreView.model.notes.isEmpty {
                var option = sheetView.model.score.option
                option.enabled = false
                sheetView.newUndoGroup()
                sheetView.set(option)
                return true
            }
        } else if let (border, i, sheetView, edge) = rootView.border(at: p) {
            Pasteboard.shared.copiedObjects = [.border(border)]
            
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            
            sheetView.newUndoGroup()
            sheetView.removeBorder(at: i)
            return true
         } else if !rootView.isDefaultUUColor(at: p) {
            let colorOwners = rootView.colorOwners(at: p)
            if !colorOwners.isEmpty {
                Pasteboard.shared.copiedObjects = [.uuColor(rootView.uuColor(at: p))]
                var nug = Set<SheetView>()
                colorOwners.forEach {
                    if $0.colorValue.isBackground {
                        $0.uuColor = Sheet.defalutBackgroundUUColor
                        if !nug.contains($0.sheetView) {
                            $0.captureUUColor(isNewUndoGroup: true)
                            nug.insert($0.sheetView)
                        }
                    }
                    if !$0.colorValue.planeIndexes.isEmpty {
                        if !nug.contains($0.sheetView) {
                            $0.sheetView.newUndoGroup()
                            nug.insert($0.sheetView)
                        }
                        $0.sheetView.removePlanes(at: $0.colorValue.planeIndexes)
                    }
                    if !$0.colorValue.planeAnimationIndexes.isEmpty {
                        let ki = $0.sheetView.model.animation.index
                        for v in $0.colorValue.planeAnimationIndexes {
                            if ki == v.index {
                                if !v.value.isEmpty {
                                    if !nug.contains($0.sheetView) {
                                        $0.sheetView.newUndoGroup()
                                        nug.insert($0.sheetView)
                                    }
                                    $0.sheetView.removePlanes(at: v.value)
                                }
                                break
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    var isSnapped = false {
        didSet {
            guard isSnapped != oldValue else { return }
            if isSnapped {
                Feedback.performAlignment()
            }
        }
    }
    
    private var oldScale: Double?, firstRotation = 0.0,
                oldSnapP: Point?, oldFillSnapP: Point?, beganPitch = Rational(0),
                octaveNode: Node?, beganNotes = [Int: Note](), beganSheetView: SheetView?,
                textNode: Node?, imageNode: Node?, textFrame: Rect?, textScale = 1.0
    var snapDistance = 1.0
    private var notePlayer: NotePlayer?, playerBeatNoteIndexes = [Int](), oldPitch: Rational?
    
    func updateWithPaste(at p: Point, atScreen sp: Point, _ phase: Phase) {
        let shp = rootView.sheetPosition(at: p)
        let sheetFrame = rootView.sheetFrame(with: shp)
        let sheetView = rootView.sheetView(at: shp)
        
        func updateWithValue(_ value: SheetValue) {
            let scale = firstScale * rootView.screenToWorldScale
            if phase == .began {
                let lineNodes = value.keyframes.isEmpty ?
                    value.lines.map { $0.node } :
                    value.keyframes[value.keyframeBeganIndex].picture.lines.map { $0.node }
                let planeNodes = value.keyframes.isEmpty ?
                    value.planes.map { $0.node } :
                    value.keyframes[value.keyframeBeganIndex].picture.planes.map { $0.node }
                let textNodes = value.texts.map { $0.node }
                let keyframesNodes = value.keyframes.isEmpty ?
                    [] :
                    [Text(string: "\(value.keyframeBeganIndex)", origin: Point(-10, 0)).node,
                     Text(string: "\(value.keyframes.count - value.keyframeBeganIndex)", origin: Point(10, 0)).node]
                let node0 = Node(children: planeNodes + lineNodes + keyframesNodes)
                let node1 = Node(children: textNodes)
                let snapNode = Node(lineWidth: 1, lineType: .color(.background),
                                    fillType: .color(.border))
                selectingLineNode.children = [node0, node1, snapNode]
//                selectingLineNode.children = planeNodes + lineNodes + textNodes
            }
            if !selectingLineNode.path.isEmpty {
                selectingLineNode.path = Path()
            }
            
            let nSnapP: Point?, np: Point
            if !(sheetView?.id == value.id && sheetView?.rootKeyframeIndex == value.rootKeyframeIndex) {
                let snapP = value.origin + sheetFrame.origin
                nSnapP = snapP
                np = snapP.distance(p) < snapDistance * rootView.screenToWorldScale && firstScale == rootView.worldToScreenScale ?
                    snapP : rootView.roundedPoint(from: p)
                let isSnapped = np == snapP
                if isSnapped {
                    if oldFillSnapP != np {
                        selectingLineNode.children.last?.fillType = .color(.selected)
                        Feedback.performAlignment()
                    }
                } else {
                    if oldFillSnapP != np {
                        selectingLineNode.children.last?.fillType = .color(.border)
                    }
                }
                oldFillSnapP = np
            } else {
                np = rootView.roundedPoint(from: p)
                nSnapP = nil
            }
            
            if selectingLineNode.children.count == 3 {
                selectingLineNode.children[0].attitude = Attitude(position: np,
                                                                  scale: Size(square: 1.0 * scale),
                                                                  rotation: rootView.pov.rotation - firstRotation)
                
                let textChildren = selectingLineNode.children[1].children
                if textChildren.count == value.texts.count {
                    let screenScale = rootView.worldToScreenScale
                    let t = Transform(scale: 1.0 * firstScale / screenScale)
                        .rotated(by: rootView.pov.rotation - firstRotation)
                    let nt = t.translated(by: np - sheetFrame.minXMinYPoint)
                    for (i, text) in value.texts.enumerated() {
                        textChildren[i].attitude = Attitude(position: (text.origin) * nt + sheetFrame.minXMinYPoint,
                                                            scale: Size(square: 1.0 * scale))
                    }
                }
                
                if nSnapP != oldSnapP {
                    if let nSnapP {
                        selectingLineNode.children[2].path = Path(circleRadius: isSnapped ? 5 : 3)
                        selectingLineNode.children[2].attitude = Attitude(position: nSnapP, scale: Size(square: rootView.screenToWorldScale))
                    } else {
                        selectingLineNode.children[2].path = Path()
                    }
                }
                
                oldSnapP = nSnapP
            }
        }
        func updateWithText(_ text: Text) {
            let inP = p - sheetFrame.origin
            var isAppend = false
            
            var textView: SheetTextView?, sri: String.Index?
            if let aTextView = rootAction.textAction.editingTextView,
               !aTextView.isHiddenSelectedRange {
                
                if let asri = aTextView.selectedRange?.lowerBound {
                    textView = aTextView
                    sri = asri
                }
            } else if let (aTextView, _, _, asri) = sheetView?.textTuple(at: inP) {
                textView = aTextView
                sri = asri
            }
            if let textView = textView, let sri = sri {
                textNode = nil
                let cpath = textView.typesetter.cursorPath(at: sri)
                let path = textView.convertToWorld(cpath)
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                selectingLineNode.path = path
                selectingLineNode.attitude = Attitude(position: Point())
                selectingLineNode.children = []
                isAppend = true
            }
            if !isAppend {
                let fScale = firstScale * rootView.screenToWorldScale
                let s = text.font.defaultRatio * fScale
                let os = oldScale ?? s
                func scaleIndex(_ cs: Double) -> Double {
                    if cs <= 1 || text.string.count > 50 {
                        return 1
                    } else {
                        return cs
                    }
                }
                if scaleIndex(os) == scaleIndex(s),
                   let textNode = textNode {
                    if let imageNode {
                        selectingLineNode.children = [textNode, imageNode]
                    } else {
                        selectingLineNode.children = [textNode]
                    }
                } else {
                    var nText = text
                    nText.origin *= fScale
                    nText.size *= fScale
                    selectingLineNode.children = [nText.node]
                    self.textNode = nText.node
                    self.textFrame = nText.frame
                    textScale = rootView.worldToScreenScale
                }
                
                let scale = textScale * rootView.screenToWorldScale
                let np: Point
                if let stb = textFrame {
                    let textFrame = stb
                        * Attitude(position: p,
                                   scale: Size(square: 1.0 * scale)).transform
                    let sb = sheetFrame.inset(by: Sheet.textPadding)
                    if !sb.intersects(textFrame) {
                        let nFrame = sb.moveOutline(textFrame)
                        np = p + nFrame.origin - textFrame.origin
                    } else {
                        np = p
                    }
                } else {
                    np = p
                }
                
                var snapDP = Point(), path: Path?
                if let sheetView = sheetView {
                    let np = sheetView.convertFromWorld(np)
                    let scale = firstScale / rootView.worldToScreenScale
                    let nnp = text.origin * scale + np
                    let fp1 = rootView.roundedPoint(from: nnp)
                    let lp1 = fp1 + (text.typesetter.typelines.last?.origin ?? Point())
                    for textView in sheetView.textsView.elementViews {
                        guard !textView.typesetter.typelines.isEmpty else { continue }
                        let fp0 = textView.model.origin
                            + (textView.typesetter
                                .firstEditReturnBounds?.centerPoint
                                ?? Point())
                        let lp0 = textView.model.origin
                            + (textView.typesetter
                                .lastEditReturnBounds?.centerPoint
                                ?? Point())
                        
                        if text.size.absRatio(textView.model.size) < 1.25 {
                            let d = 3.0 * rootView.screenToWorldScale
                            if fp0.distance(lp1) < d {
                                let spacing = textView.model.typelineSpacing
                                let edge = textView.typesetter.firstEdge(offset: spacing / 2)
                                path = textView.convertToWorld(Path(edge))
                                snapDP = fp0 - lp1
                                break
                            } else if lp0.distance(fp1) < d {
                                let spacing = textView.model.typelineSpacing
                                let edge = textView.typesetter.lastEdge(offset: spacing / 2)
                                path = textView.convertToWorld(Path(edge))
                                snapDP = lp0 - fp1
                                break
                            }
                        }
                    }
                }
                
                if let path = path {
                    selectingLineNode.fillType = .color(.subSelected)
                    selectingLineNode.lineType = .color(.selected)
                    selectingLineNode.path = path * Attitude(position: np + snapDP,
                                                             scale: Size(square: 1.0 * scale)).transform.inverted()
                } else {
                    selectingLineNode.path = Path()
                }
                selectingLineNode.attitude
                    = Attitude(position: np + snapDP,
                               scale: Size(square: 1.0 * scale))
                
                oldScale = s
            }
        }
        func updateBorder(with oldBorder: Border) {
            if phase == .began {
                selectingLineNode.lineType = .color(.subBorder)
            }
            
            let lw = rootView.screenToWorldScale < 0.5 ? rootView.screenToWorldScale * 2 : 1
            selectingLineNode.lineWidth = lw
            
            if let sheetView = sheetView,
               let (textView, _, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)),
               let x = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p))?.offset,
               textView.textOrientation == oldBorder.orientation.reversed(),
               let frame = textView.model.frame {
                let f = frame + sheetFrame.origin
                let edge = switch textView.model.orientation {
                case .horizontal:
                    Edge(Point(f.minX + x, f.minY), Point(f.minX + x, f.maxY))
                case .vertical:
                    Edge(Point(f.minX, f.maxY - x), Point(f.maxX, f.maxY - x))
                }
                if !snapLineNode.children.isEmpty {
                    rootView.cursor = .arrow
                }
                snapLineNode.children = []
                selectingLineNode.path = Path([Pathline(edge)])
                selectingLineNode.lineWidth = 0.5
                return
            } else if let sheetView,
                        sheetView.scoreView.contains(sheetView.scoreView.convertFromWorld(p),
                                                     scale: rootView.screenToWorldScale) {
                let scoreP = sheetView.scoreView.convertFromWorld(p)
                let edges: [Edge]
                switch oldBorder.orientation {
                case .horizontal:
                    let pitch = sheetView.scoreView.pitch(atY: scoreP.y,
                                                          interval: rootView.currentPitchInterval)
                    edges = sheetView.scoreView.scaleEdges(fromUnison: pitch.mod(12))
                    rootView.cursor = .arrowWith(string: Pitch(value: pitch).octaveString())
                    selectingLineNode.lineWidth = pitch.isInteger ? 0.5 : 0.25
                case .vertical:
                    let beat = sheetView.scoreView.beat(atX: scoreP.x,
                                                        interval: rootView.currentBeatInterval)
                    let sy = sheetView.scoreView.y(fromPitch: Score.minPitch)
                    let ey = sheetView.scoreView.y(fromPitch: Score.maxPitch)
                    let x = sheetView.scoreView.x(atBeat: beat)
                    edges = [Edge(.init(x, sy), .init(x, ey))]
                    isSnapped = beat.isInteger
                    if !snapLineNode.children.isEmpty {
                        rootView.cursor = .arrow
                    }
                    selectingLineNode.lineWidth = 0.5
                }
                snapLineNode.children = []
                selectingLineNode.path = Path(edges.map { Pathline(sheetView.scoreView.convertToWorld($0)) })
                return
            }
            
            var paths = [Path]()
            let values = Sheet.snappableBorderLocations(from: oldBorder.orientation,
                                                        with: sheetFrame)
            switch oldBorder.orientation {
            case .horizontal:
                func append(_ p0: Point, _ p1: Point, lw: Double) {
                    paths.append(Path(Rect(x: p0.x, y: p0.y - lw / 2,
                                           width: p1.x - p0.x, height: lw)))
                }
                for value in values {
                    append(Point(sheetFrame.minX, sheetFrame.minY + value),
                           Point(sheetFrame.maxX, sheetFrame.minY + value), lw: lw * 1.5)
                }
                append(Point(sheetFrame.minX, sheetFrame.minY + oldBorder.location),
                       Point(sheetFrame.maxX, sheetFrame.minY + oldBorder.location), lw: lw * 0.5)
            case .vertical:
                func append(_ p0: Point, _ p1: Point, lw: Double) {
                    paths.append(Path(Rect(x: p0.x - lw / 2, y: p0.y,
                                           width: lw, height: p1.y - p0.y)))
                }
                for value in values {
                    append(Point(sheetFrame.minX + value, sheetFrame.minY),
                           Point(sheetFrame.minX + value, sheetFrame.maxY), lw: lw * 1.5)
                }
                append(Point(sheetFrame.minX + oldBorder.location, sheetFrame.minY),
                       Point(sheetFrame.minX + oldBorder.location, sheetFrame.maxY), lw: lw * 0.5)
            }
            snapLineNode.children = paths.map {
                Node(path: $0, fillType: .color(.subSelected))
            }
            
            let inP = p - sheetFrame.origin
            let bnp = Sheet.borderSnappedPoint(inP, with: sheetFrame,
                                               distance: 3 / rootView.worldToScreenScale,
                                               oldBorder: oldBorder)
            isSnapped = bnp.isSnapped
            let np = bnp.point + sheetFrame.origin
            var nBorder = oldBorder
            switch oldBorder.orientation {
            case .horizontal:
                selectingLineNode.path = Path([Pathline([Point(sheetFrame.minX, np.y),
                                                         Point(sheetFrame.maxX, np.y)])])
                nBorder.location = np.y - sheetFrame.minY
            case .vertical:
                selectingLineNode.path = Path([Pathline([Point(np.x, sheetFrame.minY),
                                                         Point(np.x, sheetFrame.maxY)])])
                nBorder.location = np.x - sheetFrame.minX
            }
            if let sheetView {
                let borders = sheetView.model.borders + [nBorder]
                if borders.count == 4 && borders.reduce(0, { $0 + ($1.orientation == .horizontal ? 1 : 0) }) == 2 {
                    var xs = [Double](), ys = [Double]()
                    func append(border: Border) {
                        if border.orientation == .horizontal {
                            ys.append(border.location)
                        } else {
                            xs.append(border.location)
                        }
                    }
                    borders.forEach { append(border: $0) }
                    let nxs = xs.sorted(), nys = ys.sorted()
                    let width = nxs[1] - nxs[0], height = nys[1] - nys[0]
                    let nString0 = nBorder.location.string(digitsCount: 1, enabledZeroInteger: false)
                    let nString1 = ((nBorder.orientation == .horizontal ? sheetFrame.width : sheetFrame.height) - nBorder.location).string(digitsCount: 1, enabledZeroInteger: false)
                    rootView.cursor = rootView.cursor(from: "\(nString0):\(nString1) (\(LookUpAction.sizeString(from: .init(width: width, height: height))))")
                } else {
                    let nString0 = nBorder.location.string(digitsCount: 1, enabledZeroInteger: false)
                    let nString1 = ((nBorder.orientation == .horizontal ? sheetFrame.width : sheetFrame.height) - nBorder.location).string(digitsCount: 1, enabledZeroInteger: false)
                    rootView.cursor = switch nBorder.orientation {
                    case .horizontal: rootView.cursor(from: "\(nString0):\(nString1)")
                    case .vertical: rootView.cursor(from: "\(nString0):\(nString1)")
                    }
                }
            } else {
                let nString0 = nBorder.location.string(digitsCount: 1, enabledZeroInteger: false)
                let nString1 = ((nBorder.orientation == .horizontal ? sheetFrame.width : sheetFrame.height) - nBorder.location).string(digitsCount: 1, enabledZeroInteger: false)
                rootView.cursor = switch nBorder.orientation {
                case .horizontal: rootView.cursor(from: "\(nString0):\(nString1)")
                case .vertical: rootView.cursor(from: "\(nString0):\(nString1)")
                }
            }
        }
        func updateIDs(_ ids: [InterOption]) {
            guard let sheetView = sheetView else { return }
            let lis: [Int]
            if rootView.isSelectNoneCursor(at: p),
               !rootView.isSelectedText, !rootView.selections.isEmpty {
                
                let ms = sheetView.convertFromWorld(rootView.multiSelection)
                lis = sheetView.model.picture.lines.enumerated()
                    .compactMap { ms.intersects($0.element) ? $0.offset : nil }
            } else {
                if let li = sheetView.lineTuple(at: sheetView.convertFromWorld(p), scale: 1 / rootView.worldToScreenScale)?.lineIndex {
                    lis = [li]
                } else {
                    lis = []
                }
            }
            guard !ids.isEmpty && !lis.isEmpty else {
                selectingLineNode.children = []
                return
            }
            
            let idSet = Set(ids)
            let lw = Line.defaultLineWidth
            let scale = 1 / rootView.worldToScreenScale
            
            var nodes = [Node]()
            for keyframe in sheetView.model.animation.keyframes {
                for line in keyframe.picture.lines {
                    let nLine = sheetView.convertToWorld(line)
                        
                    nodes.append(Node(path: Path(nLine),
                                      lineWidth: max(lw * 1.5, lw * 2.5 * scale, 1 * scale) * 0.25,
                                      lineType: .color(.selected)))
                }
            }
            for (i, id) in ids.enumerated() {
                guard i < lis.count else { break }
                let line = sheetView.model.picture.lines[lis[i]]
                if idSet.contains(id) {
                    nodes.append(Node(path: sheetView.convertToWorld(line.node.path),
                                      lineWidth: max(lw * 1.5, lw * 2.5 * scale, 1 * scale),
                                      lineType: .color(.selected)))
                }
            }
            
            selectingLineNode.children = nodes
        }
        func updateImage(_ image: Image, imageFrame: Rect? = nil) {
            if phase == .began {
                if let texture = try? Texture(image: image, isOpaque: false, .sRGB) {
                    let rect: Rect
                    if let imf = imageFrame {
                        rect = imf
                    } else {
                        let maxSize = Sheet.defaultBounds.inset(by: Sheet.textPadding).size
                        var size = image.size / 2
                        if size.width > maxSize.width || size.height > maxSize.height {
                            size *= min(maxSize.width / size.width, maxSize.height / size.height)
                        }
                        rect = Rect(origin: -Point(size.width / 2, size.height / 2), size: size)
                    }
                    
                    let scale = firstScale / rootView.worldToScreenScale
                    let imageNode = Node(name: "content",
                                         attitude: .init(position: p, scale: .init(square: scale)),
                                         path: Path(rect),
                                         fillType: .texture(texture))
                    self.imageNode = imageNode
                    selectingLineNode.children = [imageNode]
                }
            } else if !selectingLineNode.children.isEmpty {
                let scale = firstScale / rootView.worldToScreenScale
                selectingLineNode.children[0].attitude = Attitude(position: p, scale: .init(square: scale))
            }
        }
        func updateNotes(_ notes: [Note], deltaPitch: Rational) {
            if phase == .began {
                beganSheetView = rootView.madeSheetView(at: shp)
            }
            guard let sheetView = beganSheetView else { return }
            let scoreView = sheetView.scoreView
            let scoreP = scoreView.convertFromWorld(p)
            let pitchInterval = rootView.currentPitchInterval
            let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
            let beatInterval = rootView.currentBeatInterval
            let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
            
            if phase == .began {
                beganPitch = pitch
                
                sheetView.newUndoGroup()
                if !sheetView.scoreView.model.enabled {
                    var option = sheetView.scoreView.option
                    option.enabled = true
                    sheetView.set(option)
                }
                
                let count = scoreView.model.notes.count
                beganNotes = notes.enumerated().reduce(into: .init()) {
                    var note = $1.element
                    note.id = .init()
                    $0[count + $1.offset] = note
                }
                
                var notes = beganNotes.sorted(by: { $0.key < $1.key }).map { $0.value }
                for j in 0 ..< notes.count {
                    notes[j].pitch += pitch - Score.pitchRange.start
                    notes[j].beatRange.start += beat
                }
                sheetView.append(notes)
                
                let octaveNode = scoreView.octaveNode(noteIs: Array(count ..< count + notes.count))
                octaveNode.attitude.position = sheetView.convertToWorld(scoreView.node.attitude.position)
                self.octaveNode = octaveNode
                rootView.node.append(child: octaveNode)
                
                func updatePlayer(from vs: [Note.PitResult], in sheetView: SheetView) {
                    if let notePlayer = sheetView.notePlayer {
                        self.notePlayer = notePlayer
                        notePlayer.notes = vs
                    } else {
                        notePlayer = try? NotePlayer(notes: vs)
                        sheetView.notePlayer = notePlayer
                    }
                    notePlayer?.play()
                }
                
                let minBV = beganNotes.min(by: { $0.value.beatRange.start < $1.value.beatRange.start })
                let maxBV = beganNotes.max(by: { $0.value.beatRange.end < $1.value.beatRange.end })
                let minBeat = (minBV?.value.beatRange.start ?? 0) + beat
                let maxBeat = (maxBV?.value.beatRange.end ?? 0) + beat
                let noteI = !beganNotes.contains(where: { 0 >= $0.value.beatRange.start }) ?
                minBV?.key :
                (!beganNotes.contains(where: { 0 < $0.value.beatRange.end }) ? maxBV?.key : nil)
                let vs = scoreView.model.noteIAndNormarizedPits(atBeat: beat.clipped(min: minBeat, max: maxBeat), selectedNoteI: noteI,
                                                                in: Set(beganNotes.keys).sorted())
                playerBeatNoteIndexes = vs.map { $0.noteI }
                
                updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
            } else {
                var notes = beganNotes.sorted(by: { $0.key < $1.key }).map { $0.value }
                for j in 0 ..< notes.count {
                    notes[j].pitch += pitch - Score.pitchRange.start
                    notes[j].beatRange.start += beat
                }
                scoreView.replace(notes.enumerated().map { .init(value: $0.element, index: $0.offset + scoreView.model.notes.count - notes.count) })
                
                octaveNode?.children = scoreView.octaveNode(noteIs: Array(scoreView.model.notes.count - notes.count ..< scoreView.model.notes.count)).children
                
                if pitch != oldPitch {
                    notePlayer?.notes = playerBeatNoteIndexes.map {
                        scoreView.rendableNormarizedPitResult(atBeat: beat, at: $0)
                    }
                    oldPitch = pitch
                }
            }
            
//            selectingLineNode.children = notes.map {
//                let node = scoreView.noteNode(from: $0).node
//                node.attitude = Attitude(position: sheetView.convertToWorld(Point()))
//                return node
//            }
            
            rootView.cursor = .circle(string: Pitch(value: pitch)
                .octaveString(deltaPitch: pitch - deltaPitch))
        }
        
        switch pasteObject {
        case .copiedSheetsValue: break
        case .picture:
            break
        case .sheetValue(let value):
            if value.texts.count == 1 && value.lines.isEmpty && value.planes.isEmpty {
                updateWithText(value.texts[0])
            } else {
                updateWithValue(value)
            }
        case .planesValue:
            break
        case .string(let string):
            updateWithText(Text(autoWidthCountWith: string,
                                locale: TextInputContext.currentLocale))
        case .text(let text):
            updateWithText(text)
        case .border(let border):
            updateBorder(with: border)
        case .uuColor:
            break
        case .animation:
            break
        case .ids(let ids):
            updateIDs(ids.ids)
        case .score:
            break
        case .content(let content):
            if let image = content.image {
                updateImage(image, imageFrame: content.imageFrame)
            }
        case .image(let image):
            updateImage(image)
        case .beatRange:
            break
        case .normalizationValue:
            break
        case .normalizationRationalValue:
            break
        case .notesValue(let notesValue):
            updateNotes(notesValue.notes, deltaPitch: notesValue.deltaPitch)
        case .stereo:
            break
        case .tone:
            break
        }
    }
    
    func paste(at p: Point, atScreen sp: Point) {
        let shp = rootView.sheetPosition(at: p)
        
        var isRootNewUndoGroup = true
        var isUpdateUndoGroupSet = Set<IntPoint>()
        func updateUndoGroup(with nshp: IntPoint) {
            if !isUpdateUndoGroupSet.contains(nshp),
               let sheetView = rootView.sheetView(at: nshp) {
                
                sheetView.newUndoGroup()
                isUpdateUndoGroupSet.insert(nshp)
            }
        }
        
        let screenScale = rootView.worldToScreenScale
        func firstTransform(at p: Point) -> Transform {
            if firstScale != screenScale
                || firstRotation != rootView.pov.rotation {
                let t = Transform(scale: 1.0 * firstScale / screenScale)
                    .rotated(by: rootView.pov.rotation - firstRotation)
                return t.translated(by: p)
            } else {
                return Transform(translation: p)
            }
        }
        func transform(in frame: Rect, at p: Point) -> Transform {
            if firstScale != screenScale
                || firstRotation != rootView.pov.rotation{
                let t = Transform(scale: 1.0 * firstScale / screenScale)
                    .rotated(by: rootView.pov.rotation - firstRotation)
                return t.translated(by: p - frame.minXMinYPoint)
            } else {
                return Transform(translation: p - frame.minXMinYPoint)
            }
        }
        
        func pasteLines(_ lines: [Line], at p: Point) {
            let p = rootView.roundedPoint(from: p)
            let pt = firstTransform(at: p)
            let ratio = firstScale / rootView.worldToScreenScale
            let pLines: [Line] = lines.map {
                var l = $0 * pt
                l.size *= ratio
                return l
            }
            guard !pLines.isEmpty, let rect = pLines.bounds else { return }
            
            let minXMinYSHP = rootView.sheetPosition(at: rect.minXMinYPoint)
            let maxXMinYSHP = rootView.sheetPosition(at: rect.maxXMinYPoint)
            let minXMaxYSHP = rootView.sheetPosition(at: rect.minXMaxYPoint)
            let lx = max(minXMinYSHP.x, shp.x - 1)
            let rx = min(maxXMinYSHP.x, shp.x + 1)
            let by = max(minXMinYSHP.y, shp.y - 1)
            let ty = min(minXMaxYSHP.y, shp.y + 1)
            var filledShps = Set<IntPoint>()
            if lx <= rx && by <= ty {
                for xi in lx ... rx {
                    for yi in by ... ty {
                        let nshp = IntPoint(xi, yi)
                        guard !filledShps.contains(nshp) else { continue }
                        filledShps.insert(nshp)
                        
                        let frame = rootView.sheetFrame(with: nshp)
                        let t = transform(in: frame, at: p)
                        let oLines: [Line] = lines.map {
                            var l = $0 * t
                            l.size *= ratio
                            return l
                        }
                        var nLines = Sheet.clipped(oLines,
                                                   in: Rect(size: frame.size))
                        if !nLines.isEmpty,
                           let (sheetView, isNew) = rootView
                            .madeSheetViewIsNew(at: nshp, isNewUndoGroup: isRootNewUndoGroup) {
                            
                            let idSet = Set(sheetView.model.picture.lines.map { $0.id })
                            for (i, l) in nLines.enumerated() {
                                if idSet.contains(l.id) {
                                    nLines[i].id = UUID()
                                }
                            }
                            if isNew {
                                isRootNewUndoGroup = false
                            }
                            updateUndoGroup(with: nshp)
                            sheetView.append(nLines)
                        }
                    }
                }
            }
        }
        func pastePlanes(_ planes: [Plane], at p: Point) {
            let p = rootView.roundedPoint(from: p)
            let pt = firstTransform(at: p)
            let pPlanes = planes.map { $0 * pt }
            guard !pPlanes.isEmpty, let rect = pPlanes.bounds else { return }
            
            let minXMinYSHP = rootView.sheetPosition(at: rect.minXMinYPoint)
            let maxXMinYSHP = rootView.sheetPosition(at: rect.maxXMinYPoint)
            let minXMaxYSHP = rootView.sheetPosition(at: rect.minXMaxYPoint)
            let lx = max(minXMinYSHP.x, shp.x - 1)
            let rx = min(maxXMinYSHP.x, shp.x + 1)
            let by = max(minXMinYSHP.y, shp.y - 1)
            let ty = min(minXMaxYSHP.y, shp.y + 1)
            var filledShps = Set<IntPoint>()
            if lx <= rx && by <= ty {
                for xi in lx ... rx {
                    for yi in by ... ty {
                        let nshp = IntPoint(xi, yi)
                        guard !filledShps.contains(nshp) else { continue }
                        filledShps.insert(nshp)
                        
                        let frame = rootView.sheetFrame(with: nshp)
                        let t = transform(in: frame, at: p)
                        let nPlanes = Sheet.clipped(planes.map { $0 * t },
                                                    in: Rect(size: frame.size))
                        if !nPlanes.isEmpty,
                           let (sheetView, isNew) = rootView
                            .madeSheetViewIsNew(at: nshp,
                                                isNewUndoGroup:
                                                    isRootNewUndoGroup) {
                            if isNew {
                                isRootNewUndoGroup = false
                            }
                            updateUndoGroup(with: nshp)
                            sheetView.append(nPlanes)
                        }
                    }
                }
            }
        }
        func pasteTexts(_ texts: [Text], at p: Point) {
            let p = rootView.roundedPoint(from: p)
            let pt = firstTransform(at: p)
            guard !texts.isEmpty else { return }
            
            for text in texts {
                let nshp = rootView.sheetPosition(at: (text * pt).origin)
                guard ((shp.x - 1) ... (shp.x + 1)).contains(nshp.x)
                    && ((shp.y - 1) ... (shp.y + 1)).contains(nshp.y) else {
                    
                    continue
                }
                let frame = rootView.sheetFrame(with: nshp)
                let t = transform(in: frame, at: p)
                var nText = text * t
                if let (sheetView, isNew) = rootView
                    .madeSheetViewIsNew(at: nshp, isNewUndoGroup: isRootNewUndoGroup) {
                    let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                    if let textFrame = nText.frame,
                       !sb.contains(textFrame) {
                       
                        let nFrame = sb.clipped(textFrame)
                        nText.origin += nFrame.origin - textFrame.origin
                        
                        if let textFrame = nText.frame, !sb.outset(by: 1).contains(textFrame) {
                            
                            let scale = min(sb.width / textFrame.width,
                                            sb.height / textFrame.height)
                            let dp = sb.clipped(textFrame).origin - textFrame.origin
                            nText.size *= scale
                            nText.origin += dp
                        }
                    }
                    if isNew {
                        isRootNewUndoGroup = false
                    }
                    updateUndoGroup(with: nshp)
                    sheetView.append([nText])
                }
            }
        }
        func pasteText(_ text: Text) {
//            let pt = firstTransform()
            let nshp = shp
            guard ((shp.x - 1) ... (shp.x + 1)).contains(nshp.x)
                    && ((shp.y - 1) ... (shp.y + 1)).contains(nshp.y),
                  let sheetView = rootView.madeSheetView(at: nshp) else { return }
            var text = text
            var isAppend = false
            
            rootAction.textAction.begin(atScreen: sp)
            if let textView = rootAction.textAction.editingTextView,
               !textView.isHiddenSelectedRange,
               let i = sheetView.textsView.elementViews.firstIndex(of: textView) {
                
                rootAction.textAction.endInputKey(isUnmarkText: true,
                                                isRemoveText: false)
                if rootView.findingNode(at: p) != nil,
                    rootView.finding.string != text.string {
                    
                    rootView.replaceFinding(from: text.string)
                } else if let ati = textView.selectedRange?.lowerBound {
                    let rRange: Range<Int>
                    if let selection = rootView.multiSelection.firstSelection(at: p),
                       let sRange = textView.range(from: selection),
                       sRange.contains(ati) {
                            
                        rRange = textView.model.string.intRange(from: sRange)
                        rootView.selections = []
                    } else {
                        let ti = textView.model.string.intIndex(from: ati)
                        rRange = ti ..< ti
                    }
                    let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                    var nText = textView.model
                    nText.replaceSubrange(text.string, from: rRange,
                                          clipFrame: sb)
                    let origin = textView.model.origin != nText.origin ?
                        nText.origin : nil
                    let size = textView.model.size != nText.size ?
                        nText.size : nil
                    let widthCount = textView.model.widthCount != nText.widthCount ?
                        nText.widthCount : nil
                    let tv = TextValue(string: text.string,
                                       replacedRange: rRange,
                                       origin: origin, size: size,
                                       widthCount: widthCount)
                    updateUndoGroup(with: nshp)
                    sheetView.replace(IndexValue(value: tv, index: i))
                }
                isAppend = true
            }
            
            if !isAppend {
                let np = sheetView.convertFromWorld(p)
                let scale = firstScale / rootView.worldToScreenScale
                let nnp = text.origin * scale + np
                let fp1 = rootView.roundedPoint(from: nnp)
                let lp1 = fp1 + (text.typesetter.typelines.last?.origin ?? Point())
                for (i, textView) in sheetView.textsView.elementViews.enumerated() {
                    guard !textView.typesetter.typelines.isEmpty else { continue }
                    let fp0 = textView.model.origin
                        + (textView.typesetter
                            .firstEditReturnBounds?.centerPoint
                            ?? Point())
                    let lp0 = textView.model.origin
                        + (textView.typesetter
                            .lastEditReturnBounds?.centerPoint
                            ?? Point())
                    
                    if text.size.absRatio(textView.model.size) < 1.25 {
                        var str = text.string
                        let d = 3.0 * rootView.screenToWorldScale
                        var dp = Point(), rRange: Range<Int>?
                        if fp0.distance(lp1) < d {
                            str.append("\n")
                            let th = text.typesetter.height
                                + text.typelineSpacing
                            switch textView.model.orientation {
                            case .horizontal: dp = Point(0, th)
                            case .vertical: dp = Point(th, 0)
                            }
                            let si = textView.model.string
                                .intIndex(from: textView.model.string.startIndex)
                            rRange = si ..< si
                        } else if lp0.distance(fp1) < d {
                            str.insert("\n", at: str.startIndex)
                            let ei = textView.model.string
                                .intIndex(from: textView.model.string.endIndex)
                            rRange = ei ..< ei
                        }
                        if let rRange = rRange {
                            let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                            var nText = textView.model
                            nText.replaceSubrange(str, from: rRange,
                                                  clipFrame: sb)
                            let origin = textView.model.origin != nText.origin + dp ?
                                nText.origin + dp : nil
                            let size = textView.model.size != nText.size ?
                                nText.size : nil
                            let widthCount = textView.model.widthCount != nText.widthCount ?
                                nText.widthCount : nil
                            let tv = TextValue(string: str,
                                               replacedRange: rRange,
                                               origin: origin, size: size,
                                               widthCount: widthCount)
                            updateUndoGroup(with: nshp)
                            sheetView.replace(IndexValue(value: tv, index: i))
                            isAppend = true
                            break
                        }
                    }
                }
            }
            
            if !isAppend {
                let np = sheetView.convertFromWorld(p)
                let scale = firstScale / rootView.worldToScreenScale
                let nnp = text.origin * scale + np
                text.origin = rootView.roundedPoint(from: nnp)
                text.size = text.size * scale
                let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                if let textFrame = text.frame, !sb.intersects(textFrame) {
                    let nFrame = sb.moveOutline(textFrame)
                    text.origin += nFrame.origin - textFrame.origin
                }
                
                updateUndoGroup(with: nshp)
                sheetView.append(text)
            }
        }
        
        switch pasteObject {
        case .copiedSheetsValue: break
        case .picture(let picture):
            if let sheetView = rootView.madeSheetView(at: shp) {
                sheetView.newUndoGroup()
                sheetView.set(picture)
            }
        case .sheetValue(let value):
            let snapP = value.origin + rootView.sheetFrame(with: shp).origin
            let np = snapP.distance(p) < snapDistance / rootView.worldToScreenScale && firstScale == screenScale ?
                snapP : p
            if !value.keyframes.isEmpty {
                guard let sheetView = rootView.madeSheetView(at: shp) else { return }
                let pt = firstTransform(at: np)
                let ratio = firstScale / rootView.worldToScreenScale
                let frame = rootView.sheetFrame(with: shp)
                let fki = sheetView.model.animation.index - value.keyframeBeganIndex
                
                func keyLines(isDraft: Bool) -> [IndexValue<[Line]>] {
                    var ki = fki
                    return value.keyframes.compactMap {
                        defer { ki += 1 }
                        guard ki < sheetView.model.animation.keyframes.count else { return nil }
                        
                        let oldLines = (isDraft ?
                                        $0.draftPicture : $0.picture).lines
                        let pLines: [Line] = oldLines.map {
                            var l = $0 * pt
                            l.size *= ratio
                            return l
                        }
                        guard !pLines.isEmpty else { return nil }
                        
                        let t = transform(in: frame, at: np)
                        let oLines: [Line] = oldLines.map {
                            var l = $0 * t
                            l.size *= ratio
                            return l
                        }
                        var nLines = Sheet.clipped(oLines,
                                                   in: Rect(size: frame.size))
                        guard !nLines.isEmpty else { return nil }
                        
                        let idSet = Set(oldLines.map { $0.id })
                        for (i, l) in nLines.enumerated() {
                            if idSet.contains(l.id) {
                                nLines[i].id = UUID()
                            }
                        }
                        
                        return IndexValue(value: nLines, index: ki)
                    }
                }
                
                func keyPlanes(isDraft: Bool) -> [IndexValue<[Plane]>] {
                    var ki = fki
                    return value.keyframes.compactMap {
                        defer { ki += 1 }
                        guard ki < sheetView.model.animation.keyframes.count else { return nil }
                        
                        let oldPlanes = (isDraft ?
                                        $0.draftPicture : $0.picture).planes
                        let pPlanes = oldPlanes.map { $0 * pt }
                        guard !pPlanes.isEmpty else { return nil }
                        let t = transform(in: frame, at: np)
                        let nPlanes = Sheet.clipped(oldPlanes.map { $0 * t },
                                                    in: Rect(size: frame.size))
                        guard !nPlanes.isEmpty else { return nil }
                        
                        return IndexValue(value: nPlanes, index: ki)
                    }
                }
                
                let kivs = keyLines(isDraft: false)
                let pkivs = keyPlanes(isDraft: false)
                let dkivs = keyLines(isDraft: true)
                let dpkivs = keyPlanes(isDraft: true)
                if !kivs.isEmpty || !pkivs.isEmpty
                    || !dkivs.isEmpty || !dpkivs.isEmpty {
                    
                    sheetView.newUndoGroup()
                    if !kivs.isEmpty {
                        sheetView.appendKeyLines(kivs)
                    }
                    if !pkivs.isEmpty {
                        sheetView.appendKeyPlanes(pkivs)
                    }
                    if !dkivs.isEmpty {
                        sheetView.appendDraftKeyLines(dkivs)
                    }
                    if !dpkivs.isEmpty {
                        sheetView.appendDraftKeyPlanes(dpkivs)
                    }
                }
            } else {
                if value.texts.count == 1 && value.lines.isEmpty && value.planes.isEmpty {
                    pasteText(value.texts[0])
                } else {
                    pasteLines(value.lines, at: np)
                    pastePlanes(value.planes, at: np)
                    pasteTexts(value.texts, at: np)
                }
            }
        case .planesValue(let planesValue):
            guard !planesValue.planes.isEmpty else { return }
            guard let sheetView = rootView.madeSheetView(at: shp) else { return }
            sheetView.newUndoGroup()
            if !sheetView.model.picture.planes.isEmpty {
                let counts = Array(0 ..< sheetView.model.picture.planes.count)
                sheetView.removePlanes(at: counts)
            }
            sheetView.append(planesValue.planes)
        case .string(let string):
            pasteText(Text(autoWidthCountWith: string,
                           locale: TextInputContext.currentLocale))
        case .text(let text):
            pasteText(text)
        case .border(let border):
            if let sheetView = rootView.sheetView(at: shp),
               let (textView, ti, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)),
               let x = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p))?.offset {
                let widthCount = textView.model.size == 0 ?
                    Typobute.maxWidthCount :
                    (x / textView.model.size)
                    .clipped(min: Typobute.minWidthCount,
                             max: Typobute.maxWidthCount)
                
                var text = textView.model
                if text.widthCount != widthCount {
                    text.widthCount = widthCount
                    
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
                    sheetView.replace([IndexValue(value: text, index: ti)])
                }
                return
            } else if let sheetView = rootView.sheetView(at: shp),
                      sheetView.scoreView.contains(sheetView.scoreView.convertFromWorld(p),
                                                   scale: rootView.screenToWorldScale) {
                let scoreP = sheetView.scoreView.convertFromWorld(p)
                switch border.orientation {
                case .horizontal:
                    let pitch = sheetView.scoreView.pitch(atY: scoreP.y,
                                                          interval: rootView.currentPitchInterval)
                    let unison = pitch.mod(12)
                    var option = sheetView.scoreView.option
                    if !option.scales.contains(unison) {
                        option.scales.append(unison)
                        option.scales.sort()
                        sheetView.newUndoGroup()
                        sheetView.set(option)
                    }
                case .vertical:
                    let beat = sheetView.scoreView.beat(atX: scoreP.x,
                                                        interval: rootView.currentBeatInterval)
                    var option = sheetView.scoreView.option
                    if !option.keyBeats.contains(beat) {
                        option.keyBeats.append(beat)
                        option.keyBeats.sort()
                        sheetView.newUndoGroup()
                        sheetView.set(option)
                    }
                }
                return
            } else if let sheetView = rootView.madeSheetView(at: shp) {
                let sb = rootView.sheetFrame(with: shp)
                let inP = sheetView.convertFromWorld(p)
                let np = Sheet.borderSnappedPoint(inP, with: sb,
                                                  distance: 3 / rootView.worldToScreenScale,
                                                  oldBorder: border).point
                sheetView.newUndoGroup()
                sheetView.append(Border(position: np, border: border))
            }
        case .uuColor(let uuColor):
            func moveLine(oldUUColor: UUColor, from owner: SheetColorOwner) {
                if oldUUColor == Line.defaultUUColor && uuColor != Line.defaultUUColor {
                    if owner.colorValue.lineAnimationIndexes.count == 1 {
                        let v = owner.colorValue.lineAnimationIndexes[0]
                        if v.index == owner.sheetView.model.animation.index {
                            let lis = owner.colorValue.lineIndexes.filter { $0 != 0 }
                            if !lis.isEmpty {
                                let livs = owner.sheetView.model.picture.lines[lis].enumerated()
                                    .map { IndexValue(value: $0.element, index: $0.offset) }
                                owner.sheetView.removeLines(at: lis)
                                owner.sheetView.insert(livs)
                            }
                        }
                    } else {
                        let lis = owner.colorValue.lineIndexes.filter { $0 != 0 }
                        if !lis.isEmpty {
                            let livs = owner.sheetView.model.picture.lines[lis].enumerated()
                                .map { IndexValue(value: $0.element, index: $0.offset) }
                            owner.sheetView.removeLines(at: lis)
                            owner.sheetView.insert(livs)
                        }
                    }
                }
            }
            
            guard rootView.isSelect(at: p) else {
                guard let _ = rootView.madeSheetView(at: shp) else { return }
                let colorOwners = rootView.madeColorOwner(at: p, removingUUColor: uuColor)
                colorOwners.forEach {
                    if $0.uuColor != uuColor {
                        let oldUUColor = $0.uuColor
                        
                        $0.uuColor = uuColor
                        $0.captureUUColor(isNewUndoGroup: true)
                        
                        moveLine(oldUUColor: oldUUColor, from: $0)
                    }
                }
                rootView.updateSelects()
                return
            }
            
            guard let (_, owners) = rootView.madeColorOwnersWithSelection(at: p,
                                                                          removingUUColor: uuColor) else { return }
            let ownerDic = owners.reduce(into: [SheetView: [SheetColorOwner]]()) {
                if $0[$1.sheetView] == nil {
                    $0[$1.sheetView] = [$1]
                } else {
                    $0[$1.sheetView]?.append($1)
                }
            }
            for (_, owners) in ownerDic {
                var isNewUndoGroup = true
                owners.forEach {
                    if $0.uuColor != uuColor {
                        let oldUUColor = $0.uuColor
                        
                        $0.uuColor = uuColor
                        $0.captureUUColor(isNewUndoGroup: isNewUndoGroup)
                        isNewUndoGroup = false
                        
                        moveLine(oldUUColor: oldUUColor, from: $0)
                    }
                }
            }
            rootView.updateSelects()
        case .animation(let animation):
            guard !animation.keyframes.isEmpty,
                  let sheetView = rootView.sheetView(at: shp) else { return }
            let beat: Rational = sheetView.animationView.beat(atX: sheetView.convertFromWorld(p).x)
            var ni = 0
            for (i, kf) in sheetView.model.animation.keyframes.enumerated().reversed() {
                if kf.beat <= beat {
                    ni = i + 1
                    break
                }
            }
            
            let currentIndex = sheetView.model.animation.index(atRoot: sheetView.rootKeyframeIndex)
            let count = (sheetView.rootKeyframeIndex - currentIndex) / sheetView.model.animation.keyframes.count
            let nextBeat = ni < sheetView.model.animation.keyframes.count ? sheetView.model.animation.keyframes[ni].beat : sheetView.model.animation.beatRange.length
            var ki = ni
            let kivs: [IndexValue<Keyframe>] = animation.keyframes.compactMap {
                var keyframe = $0
                keyframe.beat += beat - sheetView.model.animation.beatRange.start
                if keyframe.beat >= nextBeat {
                    return nil
                }
                let v = IndexValue(value: keyframe, index: ki)
                ki += 1
                return v
            }
            
            sheetView.newUndoGroup()
            sheetView.insert(kivs)
            sheetView.rootKeyframeIndex = sheetView.model.animation.keyframes.count * count + ni
            rootAction.updateActionNode()
            rootView.updateSelects()
        case .ids(let idv):
            let ids = idv.ids
            guard let sheetView = rootView.sheetView(at: shp) else { return }
            let lis: [Int]
            if rootView.isSelectNoneCursor(at: p),
               !rootView.isSelectedText, !rootView.selections.isEmpty {
                
                let ms = sheetView.convertFromWorld(rootView.multiSelection)
                lis = sheetView.model.picture.lines.enumerated()
                    .compactMap { ms.intersects($0.element) ? $0.offset : nil }
            } else {
                if let li = sheetView.lineTuple(at: sheetView.convertFromWorld(p), scale: 1 / rootView.worldToScreenScale)?.lineIndex {
                    lis = [li]
                } else {
                    lis = []
                }
            }
            let maxCount = min(ids.count, lis.count)
            if maxCount > 0 {
                let idivs = (0 ..< maxCount).map { IndexValue(value: ids[$0],
                                                              index: lis[$0]) }
                sheetView.newUndoGroup()
                sheetView.set([IndexValue(value: idivs, index: sheetView.animationView.model.index)])
            }
        case .score(let score):
            guard !score.notes.isEmpty, let sheetView = rootView.sheetView(at: shp) else { return }
            
            var ni = sheetView.model.score.notes.count
            let nivs: [IndexValue<Note>] = score.notes.map {
                let v = IndexValue(value: $0, index: ni)
                ni += 1
                return v
            }
            
            sheetView.newUndoGroup()
            sheetView.insert(nivs)
            
            var option = sheetView.scoreView.model.option
            if !option.enabled {
                option.enabled = true
                sheetView.set(option)
            }
        case .content(var content):
            guard let sheetView = rootView.madeSheetView(at: shp) else { return }
            let sheetP = sheetView.convertFromWorld(p)
            
            let scale = firstScale / rootView.worldToScreenScale
            let nnp = content.origin * scale + sheetP
            
            if !sheetView.contentsView.model.contains(where: { $0.isEqualFile(content) }) {
                if let directory = rootView.model.sheetRecorders[sheetView.id]?.contentsDirectory {
                    directory.isWillwrite = true
                    try? directory.write()
                    try? directory.copy(name: content.name, from: content.url)
                }
            }
            
            content.directoryName = sheetView.id.uuidString
            
            if content.type.hasDur, var timeOption = content.timeOption {
                let tempo = sheetView.nearestTempo(at: sheetP) ?? timeOption.tempo
                let interval = rootView.currentBeatInterval
                let startBeat = sheetView.animationView.beat(atX: sheetP.x, interval: interval)
                timeOption.beatRange.start += startBeat
                timeOption.tempo = tempo
                content.timeOption = timeOption
                content.origin = .init(sheetView.animationView.x(atBeat: timeOption.beatRange.start), nnp.y)
            } else {
                content.origin = rootView.roundedPoint(from: nnp)
            }
            
            content.size = content.size * scale
            let maxSize = Size(width: 100000, height: 100000)
            if content.size.width > maxSize.width || content.size.height > maxSize.height {
                content.size *= min(maxSize.width / content.size.width, maxSize.height / content.size.height)
            }
            
            content.id = .init()
            
            sheetView.newUndoGroup()
            sheetView.append(content)
        case .image(let image):
            guard let sheetView = rootView.madeSheetView(at: shp) else { return }
            let sheetP = sheetView.convertFromWorld(p)
            
            let name = UUID().uuidString + ".tiff"
            if let directory = rootView.model.sheetRecorders[sheetView.id]?.contentsDirectory {
                directory.isWillwrite = true
                try? directory.write()
                try? directory.write(image, .tiff, name: name)
            }
            
            let scale = firstScale / rootView.worldToScreenScale
            let nnp = rootView.roundedPoint(from: sheetP)
            
            var content = Content(directoryName: sheetView.id.uuidString, name: name, origin: nnp)
            if let size = content.image?.size {
                let maxSize = Sheet.defaultBounds.inset(by: Sheet.textPadding).size
                var size = size / 2
                if size.width > maxSize.width || size.height > maxSize.height {
                    size *= min(maxSize.width / size.width, maxSize.height / size.height)
                }
                content.size = size
            }
            content.size = content.size * scale
            content.origin -= Point(content.size.width / 2, content.size.height / 2)
            
            sheetView.newUndoGroup()
            sheetView.append(content)
        case .beatRange(let beatRange):
            guard let sheetView = rootView.sheetView(at: shp) else { return }
            let sheetP = sheetView.convertFromWorld(p)
            if let ci = sheetView.contentIndex(at: sheetP,
                                               scale: rootView.screenToWorldScale) {
                var content = sheetView.model.contents[ci]
                let beatRange = Range(start: sheetView.animationView.beat(atX: content.origin.x),
                                      length: beatRange.length)
                if content.timeOption != nil {
                    content.timeOption?.beatRange = beatRange
                } else {
                    content.timeOption = .init(beatRange: beatRange)
                }
                sheetView.newUndoGroup()
                sheetView.replace(content, at: ci)
            } else if let ti = sheetView.textIndex(at: sheetP, scale: rootView.screenToWorldScale) {
                var text = sheetView.model.texts[ti]
                let beatRange = Range(start: sheetView.animationView.beat(atX: text.origin.x),
                                      length: beatRange.length)
                if text.timeOption != nil {
                    text.timeOption?.beatRange = beatRange
                } else {
                    text.timeOption = .init(beatRange: beatRange)
                }
                sheetView.newUndoGroup()
                sheetView.replace([IndexValue(value: text, index: ti)])
            }
        case .normalizationValue:
            break
        case .normalizationRationalValue:
            break
        case .notesValue(_):
            octaveNode?.removeFromParent()
            octaveNode = nil
            
            guard let sheetView = beganSheetView else { return }
            let scoreView = sheetView.scoreView
            let score = scoreView.model
            var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
            for (noteI, beganNote) in beganNotes.sorted(by: { $0.key < $1.key }) {
                guard noteI < score.notes.count else { continue }
                let note = score.notes[noteI]
                if beganNote != note {
                    noteIVs.append(.init(value: note, index: noteI))
                    oldNoteIVs.append(.init(value: beganNote, index: noteI))
                }
            }
            if !noteIVs.isEmpty {
                sheetView.capture(noteIVs, old: oldNoteIVs)
            }
        case .stereo(let stereo):
            guard let sheetView = rootView.sheetView(at: shp) else { return }
            if sheetView.model.score.enabled {
                let scoreView = sheetView.scoreView
                if let (noteI, pitI) = scoreView.noteAndPitIEnabledNote(at: scoreView.convertFromWorld(p),
                                                                        scale: rootView.screenToWorldScale) {
                    if rootView.isSelect(at: p) {
                        let score = scoreView.model
                        let nis = sheetView.noteAndPitIndexes(from: rootView.selections)
                        var nivs = [IndexValue<Note>]()
                        for (noteI, pitIs) in nis {
                            var note = score.notes[noteI], isChanged = false
                            for pitI in pitIs {
                                if note.pits[pitI].stereo != stereo {
                                    note.pits[pitI].stereo = stereo
                                    isChanged = true
                                }
                            }
                            if isChanged {
                                nivs.append(.init(value: note, index: noteI))
                            }
                        }
                        if !nivs.isEmpty {
                            sheetView.newUndoGroup()
                            sheetView.replace(nivs)
                            
                            sheetView.updatePlaying()
                        }
                    } else {
                        var note = scoreView.model.notes[noteI]
                        if note.pits[pitI].stereo != stereo {
                            note.pits[pitI].stereo = stereo
                            
                            sheetView.newUndoGroup()
                            sheetView.replace(note, at: noteI)
                            
                            sheetView.updatePlaying()
                        }
                    }
                }
            }
        case .tone(let tone):
            guard let sheetView = rootView.sheetView(at: shp) else { return }
            if sheetView.model.score.enabled {
                let scoreView = sheetView.scoreView
                if rootView.isSelect(at: p) {
                    let score = scoreView.model
                    let nis = sheetView.noteAndPitIndexes(from: rootView.selections)
                    var nivs = [IndexValue<Note>]()
                    for (noteI, pitIs) in nis {
                        var note = score.notes[noteI], isChanged = false
                        for pitI in pitIs {
                            if note.pits[pitI].tone != tone {
                                note.pits[pitI].tone = tone
                                isChanged = true
                            }
                        }
                        if isChanged {
                            nivs.append(.init(value: note, index: noteI))
                        }
                    }
                    if !nivs.isEmpty {
                        sheetView.newUndoGroup()
                        sheetView.replace(nivs)
                        
                        sheetView.updatePlaying()
                    }
                } else if let (noteI, result) = scoreView
                    .hitTestPoint(scoreView.convertFromWorld(p),
                                  scale: rootView.screenToWorldScale) {
                    switch result {
                    case .note:
                        var note = scoreView.model.notes[noteI]
                        let oldNote = note
                        
                        let beat: Rational = scoreView.beat(atX: scoreView.convertFromWorld(p).x)
                        let oldTone = scoreView.pitResult(atBeat: beat, at: noteI).tone
                        let dSpectlope = tone.spectlope / oldTone.spectlope
                        
                        for (pitI, _) in note.pits.enumerated() {
                            note.pits[pitI].tone.spectlope *= dSpectlope
                            note.pits[pitI].tone.spectlope.clip()
                        }
                        
                        if note != oldNote {
                            sheetView.newUndoGroup()
                            sheetView.replace(note, at: noteI)
                            
                            sheetView.updatePlaying()
                        }
                    case .pit(let pitI), .mid(let pitI), .sprol(let pitI, _, _):
                        var note = scoreView.model.notes[noteI]
                        var isChanged = false
                        if note.pits[pitI].tone != tone {
                            note.pits[pitI].tone = tone
                            isChanged = true
                        }
                        if case .mid = result, pitI + 1 < note.pits.count,
                            note.pits[pitI + 1].tone != tone {
                            
                            note.pits[pitI + 1].tone = tone
                            isChanged = true
                        }
                        if isChanged {
                            sheetView.newUndoGroup()
                            sheetView.replace(note, at: noteI)
                            
                            sheetView.updatePlaying()
                        }
                    default: break
                    }
                }
            }
        }
    }
    
    var isMovePasteObject: Bool {
        switch pasteObject {
        case .copiedSheetsValue: false
        case .picture: false
        case .sheetValue: true
        case .planesValue: false
        case .string: true
        case .text: true
        case .border: true
        case .uuColor: false
        case .animation: true
        case .ids: true
        case .score: true
        case .content: true
        case .image: true
        case .beatRange: false
        case .normalizationValue: false
        case .normalizationRationalValue: false
        case .notesValue: true
        case .stereo: false
        case .tone: false
        }
    }
    
    func cut(with event: InputKeyEvent) {
        let sp = rootView.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        for runAction in rootAction.runActions {
            if runAction.containsCalculating(p) {
                Pasteboard.shared.copiedObjects = [.string(runAction.calculatingString)]
                runAction.cancel()
                return
            }
        }
        if rootView.containsLookingUp(at: p) {
            rootView.closeLookingUpNode()
            return
        }
        
        guard isEditingSheet else {
            cutSheet(with: event)
            return
        }
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            type = .cut
            editingSP = sp
            editingP = rootView.convertScreenToWorld(sp)
            cut(at: editingP)
            
            rootView.updateSelects()
            rootView.updateFinding(at: editingP)
            rootView.updateTextCursor()
            rootView.node.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func copy(with event: InputKeyEvent) {
        guard isEditingSheet else {
            copySheet(with: event)
            return
        }
        let sp = rootView.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            type = .copy
            firstScale = rootView.worldToScreenScale
            editingSP = sp
            editingP = rootView.convertScreenToWorld(sp)
            updateWithCopy(for: editingP,
                           isSendPasteboard: true, isCutColor: false)
            rootView.node.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func paste(with event: InputKeyEvent) {
        guard isEditingSheet else {
            pasteSheet(with: event)
            return
        }
        guard !isEditingText else { return }
        
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            if let textView = rootAction.textAction.editingTextView,
               !textView.isHiddenSelectedRange,
               let sheetView = rootAction.textAction.editingSheetView,
               let i = sheetView.textsView.elementViews
                .firstIndex(of: textView),
               let o = Pasteboard.shared.copiedObjects.first {
                
                let str: String?
                switch o {
                case .string(let s): str = s
                case .text(let t): str = t.string
                default: str = nil
                }
                if let str = str {
                    rootAction.textAction.endInputKey(isUnmarkText: true, isRemoveText: false)
                    guard let ti = textView.selectedRange?.lowerBound,
                          ti >= textView.model.string.startIndex else { return }
                    let text = textView.model
                    let nti = text.string.intIndex(from: ti)
                    let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                    var nText = text
                    nText.replaceSubrange(str, from: nti ..< nti,
                                          clipFrame: sb)
                    let origin = text.origin != nText.origin ?
                        nText.origin : nil
                    let size = text.size != nText.size ?
                        nText.size : nil
                    let widthCount = textView.model.widthCount != nText.widthCount ?
                        nText.widthCount : nil
                    let tv = TextValue(string: str,
                                       replacedRange: nti ..< nti,
                                       origin: origin, size: size, widthCount: widthCount)
                    sheetView.newUndoGroup()
                    sheetView.replace(IndexValue(value: tv, index: i))
                    
                    isEditingText = true
                    return
                }
            }
            
            rootView.cursor = .arrow
            
            type = .paste
            firstScale = rootView.worldToScreenScale
            firstRotation = rootView.pov.rotation
            textScale = firstScale
            editingSP = sp
            editingP = rootView.convertScreenToWorld(sp)
            guard let o = Pasteboard.shared.copiedObjects.first else { return }
            pasteObject = o
            if isMovePasteObject {
                selectingLineNode.lineWidth = rootView.worldLineWidth
                snapLineNode.lineWidth = selectingLineNode.lineWidth
                updateWithPaste(at: editingP, atScreen: sp,
                                event.phase)
                rootView.node.append(child: snapLineNode)
                rootView.node.append(child: selectingLineNode)
            } else {
                paste(at: editingP, atScreen: sp)
            }
        case .changed:
            if isMovePasteObject {
                editingSP = sp
                editingP = rootView.convertScreenToWorld(sp)
                updateWithPaste(at: editingP, atScreen: sp,
                                event.phase)
            }
        case .ended:
            notePlayer?.stop()
            
            if isMovePasteObject {
                editingSP = sp
                editingP = rootView.convertScreenToWorld(sp)
                paste(at: editingP, atScreen: sp)
                snapLineNode.removeFromParent()
                selectingLineNode.removeFromParent()
            }
            
            rootView.updateSelects()
            rootView.updateFinding(at: editingP)
            rootView.updateTextCursor()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func updateWithCopySheet(at dp: Point, from values: [RootView.SheetFramePosition]) {
        var csv = CopiedSheetsValue()
        for value in values {
            if let sid = rootView.sheetID(at: value.shp) {
                csv.sheetIDs[value.shp] = sid
            }
        }
        if !csv.sheetIDs.isEmpty {
            csv.deltaPoint = dp
            Pasteboard.shared.copiedObjects = [.copiedSheetsValue(csv)]
        }
    }
    
    func updateWithPasteSheet(at sp: Point, phase: Phase) {
        let p = rootView.convertScreenToWorld(sp)
        if case .copiedSheetsValue(let csv) = pasteObject {
            if phase == .began {
                let lw = Line.defaultLineWidth / rootView.worldToScreenScale
                pasteSheetNode.children = csv.sheetIDs.map {
                    let fillType = rootView.readFillType(at: $0.value)
                        ?? .color(.disabled)
                    
                    let sf = rootView.sheetFrame(with: $0.key)
                    return Node(attitude: Attitude(position: sf.origin),
                                path: Path(Rect(size: sf.size)),
                                lineWidth: lw,
                                lineType: .color(.selected), fillType: fillType)
                }
            }
            
            var children = [Node]()
            for (shp, _) in csv.sheetIDs {
                var sf = rootView.sheetFrame(with: shp)
                sf.origin += p - csv.deltaPoint
                let nshp = rootView.sheetPosition(at: Point(Sheet.width / 2, Sheet.height / 2) + sf.origin)
                let nsf = Rect(origin: rootView.sheetFrame(with: nshp).origin,
                              size: sf.size)
                let lw = Line.defaultLineWidth / rootView.worldToScreenScale
                children.append(Node(attitude: Attitude(position: nsf.origin),
                                     path: Path(Rect(size: nsf.size)),
                                     lineWidth: lw,
                                     lineType: selectingLineNode.lineType,
                                     fillType: selectingLineNode.fillType))
            }
            selectingLineNode.children = children
            
            pasteSheetNode.attitude.position = p - csv.deltaPoint
        }
    }
    func pasteSheet(at sp: Point) {
        rootView.cursorPoint = sp
        let p = rootView.convertScreenToWorld(sp)
        if case .copiedSheetsValue(let csv) = pasteObject {
            var nIndexes = [IntPoint: UUID]()
            var removeIndexes = [IntPoint]()
            for (shp, sid) in csv.sheetIDs {
                var sf = rootView.sheetFrame(with: shp)
                sf.origin += p - csv.deltaPoint
                let nshp = rootView.sheetPosition(at: Point(Sheet.width / 2, Sheet.height / 2) + sf.origin)
                
                if rootView.sheetID(at: nshp) != nil {
                    removeIndexes.append(nshp)
                }
                if rootView.sheetPosition(at: sid) != nil {
                    nIndexes[nshp] = rootView.duplicateSheet(from: sid)
                } else {
                    nIndexes[nshp] = sid
                }
            }
            if !removeIndexes.isEmpty || !nIndexes.isEmpty {
                rootView.history.newUndoGroup()
                if !removeIndexes.isEmpty {
                    rootView.removeSheets(at: removeIndexes)
                }
                if !nIndexes.isEmpty {
                    rootView.append(nIndexes)
                }
                rootView.updateNode()
            }
        }
    }
    
    func cutSheet(with event: InputKeyEvent) {
        let sp = rootView.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            type = .cut
            editingSP = sp
            editingP = rootView.convertScreenToWorld(sp)
            let p = rootView.convertScreenToWorld(sp)
            let values = rootView.sheetFramePositions(at: p, isUnselect: true)
            updateWithCopySheet(at: p, from: values)
            if !values.isEmpty {
                let shps = values.map { $0.shp }
                rootView.cursorPoint = sp
                rootView.close(from: shps)
                rootView.newUndoGroup()
                rootView.removeSheets(at: shps)
            }
            
            rootView.updateSelects()
            rootView.updateWithFinding()
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func copySheet(with event: InputKeyEvent) {
        let sp = rootView.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            type = .copy
            editingSP = sp
            editingP = rootView.convertScreenToWorld(sp)
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = rootView.worldLineWidth
            
            let p = rootView.convertScreenToWorld(sp)
            let values = rootView.sheetFramePositions(at: p, isUnselect: false)
            selectingLineNode.children = values.map {
                let sf = $0.frame
                return Node(attitude: Attitude(position: sf.origin),
                            path: Path(Rect(size: sf.size)),
                            lineWidth: selectingLineNode.lineWidth,
                            lineType: selectingLineNode.lineType,
                            fillType: selectingLineNode.fillType)
            }
            updateWithCopySheet(at: p, from: values)
            
            rootView.node.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    var pasteSheetNode = Node()
    func pasteSheet(with event: InputKeyEvent) {
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            type = .paste
            firstScale = rootView.worldToScreenScale
            editingSP = sp
            editingP = rootView.convertScreenToWorld(sp)
            pasteObject = Pasteboard.shared.copiedObjects.first
                ?? .sheetValue(SheetValue())
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = rootView.worldLineWidth
            
            rootView.node.append(child: selectingLineNode)
            rootView.node.append(child: pasteSheetNode)
            
            updateWithPasteSheet(at: sp, phase: event.phase)
        case .changed:
            updateWithPasteSheet(at: sp, phase: event.phase)
        case .ended:
            pasteSheet(at: sp)
            selectingLineNode.removeFromParent()
            pasteSheetNode.removeFromParent()
            
            rootView.updateSelects()
            rootView.updateWithFinding()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class CopyLineColorAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    var selectingLineNode = Node(lineWidth: 1.5)
    var firstScale = 1.0, editingP = Point(), editingSP = Point()
    
    func updateNode() {
        if selectingLineNode.children.isEmpty {
            selectingLineNode.lineWidth = rootView.worldLineWidth
        } else {
            let w = rootView.worldLineWidth
            for node in selectingLineNode.children {
                node.lineWidth = w
            }
        }
        if isEditingSheet {
            updateWithCopy(for: editingP, isSendPasteboard: true,
                                       isCutColor: false)
        }
    }
    
    func flow(with event: InputKeyEvent) {
        guard isEditingSheet else {
            return
        }
        let sp = rootView.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            firstScale = rootView.worldToScreenScale
            editingSP = sp
            editingP = rootView.convertScreenToWorld(sp)
            updateWithCopy(for: editingP,
                           isSendPasteboard: true, isCutColor: false)
            rootView.node.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    @discardableResult
    func updateWithCopy(for p: Point, isSendPasteboard: Bool, isCutColor: Bool) -> Bool {
        if let sheetView = rootView.sheetView(at: p),
           let lineView = sheetView.lineTuple(at: sheetView.convertFromWorld(p),
                                              scale: 1 / rootView.worldToScreenScale)?.lineView {
            
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.uuColor(lineView.model.uuColor)]
            }
            
            let scale = 1 / rootView.worldToScreenScale
            let lw = Line.defaultLineWidth
            let selectedNode = Node(path: lineView.node.path * sheetView.node.localTransform,
                                    lineWidth: max(lw * 1.5, lw * 2.5 * scale, 1 * scale),
                                    lineType: .color(.selected))
            if sheetView.model.enabledAnimation {
                selectingLineNode.children = [selectedNode]
                + sheetView.animationView.interpolationNodes(from: [lineView.model.id], scale: scale)
                + sheetView.interporatedTimelineNodes(from: [lineView.model.id])
            } else {
                selectingLineNode.children = [selectedNode]
            }
            
            return true
        } else if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
            let scoreView = sheetView.scoreView
            let scoreP = scoreView.convertFromWorld(p)
            
            if let (noteI, _) = scoreView.noteAndPitIEnabledNote(at: scoreP,
                                                                 scale: rootView.screenToWorldScale) {
                
                func show(_ ps: [Point], color: Color) {
                    let scale = 1 / rootView.worldToScreenScale
                    let lw = Line.defaultLineWidth
                    let nlw = max(lw * 1.5, lw * 2.5 * scale, 1 * scale)
                    
                    let colorNode = Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                                         path: Path(ps.map { Pathline(circleRadius: nlw / 2, position: $0) }),
                                         fillType: .color(color))
                    let node = Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                                    path: Path(ps.map { Pathline(circleRadius: nlw, position: $0) }),
                                    fillType: .color(.selected))
                    selectingLineNode.children = [node, colorNode]
                }
                
                let score = scoreView.model
                
                if let pitI = scoreView.pitI(at: scoreP, scale: .infinity, at: noteI) {
                    let tone = score.notes[noteI].pits[pitI].tone
                    if isSendPasteboard {
                        Pasteboard.shared.copiedObjects = [.tone(tone)]
                    }
                    let ps = score.notes.flatMap { note in
                        note.pits.enumerated().compactMap {
                            $0.element.tone.id == tone.id ?
                            scoreView.pitPosition(atPit: $0.offset, from: note) : nil
                        }
                    }
                    show(ps, color: tone.baseColor())
                }
            }
        }
        return false
    }
}
