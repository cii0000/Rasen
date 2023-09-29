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

import struct Foundation.Data
import struct Foundation.UUID

struct ColorPathValue {
    var paths: [Path], lineType: Node.LineType?, fillType: Node.FillType?
}

struct CopiedSheetsValue: Equatable {
    var deltaPoint = Point()
    var sheetIDs = [SheetPosition: SheetID]()
}
extension CopiedSheetsValue: Protobuf {
    init(_ pb: PBCopiedSheetsValue) throws {
        deltaPoint = try Point(pb.deltaPoint)
        sheetIDs = try [SheetPosition: SheetID](pb.sheetIds)
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
}
extension NotesValue: Protobuf {
    init(_ pb: PBNotesValue) throws {
        notes = try pb.notes.map { try Note($0) }
    }
    var pb: PBNotesValue {
        .with {
            $0.notes = notes.map { $0.pb }
        }
    }
}

struct InteroptionsValue: Codable {
    var ids: [InterOption]
    var sheetID: SheetID
    var rootKeyframeIndex: Int
}
extension InteroptionsValue: Protobuf {
    init(_ pb: PBInterOptionsValue) throws {
        ids = try pb.ids.map { try InterOption($0) }
        sheetID = try SheetID(pb.sheetID)
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

enum PastableObject {
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
    case timeframe(_ timeframe: Timeframe)
    case beatRange(_ beatRange: Range<Rational>)
    case normalizationValue(_ normalizationValue: Double)
    case normalizationRationalValue(_ normalizationRationalValue: Rational)
    case notesValue(_ notesValue: NotesValue)
    case tone(_ tone: Tone)
    case envelope(_ envelope: Envelope)
    case pitchbend(_ pitchbend: Pitchbend)
    case formant(_ formant: Formant)
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
        case .timeframe(let timeframe):
             PastableObject.typeName(with: timeframe)
        case .beatRange(let beatRange):
             PastableObject.typeName(with: beatRange)
        case .normalizationValue(let normalizationValue):
             PastableObject.typeName(with: normalizationValue)
        case .normalizationRationalValue(let normalizationRationalValue):
             PastableObject.typeName(with: normalizationRationalValue)
        case .notesValue(let notesValue):
             PastableObject.typeName(with: notesValue)
        case .tone(let tone):
             PastableObject.typeName(with: tone)
        case .envelope(let envelope):
             PastableObject.typeName(with: envelope)
        case .pitchbend(let pitchbend):
             PastableObject.typeName(with: pitchbend)
        case .formant(let formant):
             PastableObject.typeName(with: formant)
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
        case PastableObject.objectTypeName(with: Timeframe.self):
            self = .timeframe(try Timeframe(serializedData: data))
        case PastableObject.objectTypeName(with: Range<Rational>.self):
            self = .beatRange(try RationalRange(serializedData: data).value)
        case PastableObject.objectTypeName(with: Double.self):
            self = .normalizationValue(try Double(serializedData: data))
        case PastableObject.objectTypeName(with: Rational.self):
            self = .normalizationRationalValue(try Rational(serializedData: data))
        case PastableObject.objectTypeName(with: NotesValue.self):
            self = .notesValue(try NotesValue(serializedData: data))
        case PastableObject.objectTypeName(with: Tone.self):
            self = .tone(try Tone(serializedData: data))
        case PastableObject.objectTypeName(with: Envelope.self):
            self = .envelope(try Envelope(serializedData: data))
        case PastableObject.objectTypeName(with: Pitchbend.self):
            self = .pitchbend(try Pitchbend(serializedData: data))
        case PastableObject.objectTypeName(with: Formant.self):
            self = .formant(try Formant(serializedData: data))
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
        case .timeframe(let timeframe):
             try? timeframe.serializedData()
        case .beatRange(let beatRange):
             try? RationalRange(value: beatRange).serializedData()
        case .normalizationValue(let normalizationValue):
             try? normalizationValue.serializedData()
        case .normalizationRationalValue(let normalizationRationalValue):
             try? normalizationRationalValue.serializedData()
        case .notesValue(let notesValue):
             try? notesValue.serializedData()
        case .tone(let tone):
             try? tone.serializedData()
        case .envelope(let envelope):
             try? envelope.serializedData()
        case .pitchbend(let pitchbend):
             try? pitchbend.serializedData()
        case .formant(let formant):
             try? formant.serializedData()
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
        case .timeframe(let timeframe):
            self = .timeframe(try Timeframe(timeframe))
        case .beatRange(let beatRange):
            self = .beatRange(try RationalRange(beatRange).value)
        case .normalizationValue(let normalizationValue):
            self = .normalizationValue(normalizationValue)
        case .normalizationRationalValue(let normalizationRationalValue):
            self = .normalizationRationalValue(try Rational(normalizationRationalValue))
        case .notesValue(let notesValue):
            self = .notesValue(try NotesValue(notesValue))
        case .tone(let tone):
            self = .tone(try Tone(tone))
        case .envelope(let envelope):
            self = .envelope(try Envelope(envelope))
        case .pitchbend(let pitchbend):
            self = .pitchbend(try Pitchbend(pitchbend))
        case .formant(let formant):
            self = .formant(try Formant(formant))
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
            case .timeframe(let timeframe):
                $0.value = .timeframe(timeframe.pb)
            case .beatRange(let beatRange):
                $0.value = .beatRange(RationalRange(value: beatRange).pb)
            case .normalizationValue(let normalizationValue):
                $0.value = .normalizationValue(normalizationValue)
            case .normalizationRationalValue(let normalizationRationalValue):
                $0.value = .normalizationRationalValue(normalizationRationalValue.pb)
            case .notesValue(let notesValue):
                $0.value = .notesValue(notesValue.pb)
            case .tone(let tone):
                $0.value = .tone(tone.pb)
            case .envelope(let envelope):
                $0.value = .envelope(envelope.pb)
            case .pitchbend(let pitchbend):
                $0.value = .pitchbend(pitchbend.pb)
            case .formant(let formant):
                $0.value = .formant(formant.pb)
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
        case timeframe = "10"
        case beatRange = "11"
        case normalizationValue = "12"
        case normalizationRationalValue = "15"
        case notesValue = "13"
        case tone = "14"
        case envelope = "17"
        case pitchbend = "18"
        case formant = "19"
    }
    init(from decoder: Decoder) throws {
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
        case .timeframe:
            self = .timeframe(try container.decode(Timeframe.self))
        case .beatRange:
            self = .beatRange(try container.decode(Range<Rational>.self))
        case .normalizationValue:
            self = .normalizationValue(try container.decode(Double.self))
        case .normalizationRationalValue:
            self = .normalizationRationalValue(try container.decode(Rational.self))
        case .notesValue:
            self = .notesValue(try container.decode(NotesValue.self))
        case .tone:
            self = .tone(try container.decode(Tone.self))
        case .envelope:
            self = .envelope(try container.decode(Envelope.self))
        case .pitchbend:
            self = .pitchbend(try container.decode(Pitchbend.self))
        case .formant:
            self = .formant(try container.decode(Formant.self))
        }
    }
    func encode(to encoder: Encoder) throws {
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
        case .timeframe(let timeframe):
            try container.encode(CodingTypeKey.timeframe)
            try container.encode(timeframe)
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
        case .tone(let tone):
            try container.encode(CodingTypeKey.tone)
            try container.encode(tone)
        case .envelope(let envelope):
            try container.encode(CodingTypeKey.envelope)
            try container.encode(envelope)
        case .pitchbend(let pitchbend):
            try container.encode(CodingTypeKey.pitchbend)
            try container.encode(pitchbend)
        case .formant(let formant):
            try container.encode(CodingTypeKey.formant)
            try container.encode(formant)
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

final class Cutter: InputKeyEditor {
    let editor: CopyEditor
    
    init(_ document: Document) {
        editor = CopyEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cut(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class Copier: InputKeyEditor {
    let editor: CopyEditor
    
    init(_ document: Document) {
        editor = CopyEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.copy(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class Paster: InputKeyEditor {
    let editor: CopyEditor
    
    init(_ document: Document) {
        editor = CopyEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.paste(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class CopyEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
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
            selectingLineNode.lineWidth = document.worldLineWidth
        } else {
            let w = document.worldLineWidth
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
                let p = document.convertScreenToWorld(editingSP)
                updateWithPaste(at: p, atScreen: editingSP, .began)
            }
        }
    }
    
    func snappableBorderLocations(from orientation: Orientation,
                                  with sb: Rect) -> [Double] {
        switch orientation {
        case .horizontal:
             [sb.height / 4,
              202,
              242,
              sb.height / 2,
              sb.height - 242,
              sb.height - 202,
              3 * sb.height / 4]
        case .vertical:
             [43,
              sb.width / 4,
              sb.width / 3,
              sb.width / 2,
              2 * sb.width / 3,
              3 * sb.width / 4,
              sb.width - 43]
        }
    }
    func borderSnappedPoint(_ p: Point, with sb: Rect, distance d: Double,
                            oldBorder: Border) -> (isSnapped: Bool,
                                                   point: Point) {
        func snapped(_ v: Double, values: [Double]) -> (Bool, Double) {
            for value in values {
                if v > value - d && v < value + d {
                    return (true, value)
                }
            }
            if oldBorder.location != 0 {
                let value = oldBorder.location
                if v > value - d && v < value + d {
                    return (true, value)
                }
            }
            return (false, v)
        }
        switch oldBorder.orientation {
        case .horizontal:
            let values = snappableBorderLocations(from: oldBorder.orientation,
                                                  with: sb)
            let (iss, y) = snapped(p.y, values: values)
            return (iss, Point(p.x, y).rounded())
        case .vertical:
            let values = snappableBorderLocations(from: oldBorder.orientation,
                                                  with: sb)
            let (iss, x) = snapped(p.x, values: values)
            return (iss, Point(x, p.y).rounded())
        }
    }
    
    @discardableResult
    func updateWithCopy(for p: Point, isSendPasteboard: Bool, isCutColor: Bool) -> Bool {
        let d = 5 / document.worldToScreenScale
        
        if let sheetView = document.sheetView(at: p),
           sheetView.containsTimeline(sheetView.convertFromWorld(p)),
           let ki = sheetView.animationView.keyframeIndex(at: sheetView.convertFromWorld(p)) {
            
            let animationView = sheetView.animationView
            
            let isSelected = animationView.selectedFrameIndexes.contains(ki)
            let indexes = isSelected ?
                animationView.selectedFrameIndexes.sorted() : [ki]
            let kfs = indexes.map { animationView.model.keyframes[$0] }
            
            Pasteboard.shared.copiedObjects = [.animation(Animation(keyframes: kfs))]
            
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            let rects = indexes
                .compactMap { animationView.transformedKeyframeBounds(at: $0) }
            selectingLineNode.path = Path(rects.map { Pathline(sheetView.convertToWorld($0)) })
        } else if document.isSelectSelectedNoneCursor(at: p), !document.selections.isEmpty {
            
            if let sheetView = document.sheetView(at: p),
               let ti = sheetView.timeframeIndex(at: sheetView.convertFromWorld(p)) {
                let textView = sheetView.textsView.elementViews[ti]
                let inTP = textView.convertFromWorld(p)
                if textView.containsScore(inTP),
                   let timeframe = textView.model.timeframe,
                   let score = timeframe.score {
                    
                    if let pitch = document.pitch(from: textView, at: inTP) {
                        
                        let nis = document.selectedNoteIndexes(from: textView)
                        if !nis.isEmpty {
                            let interval = document.currentNoteTimeInterval(from: textView.model)
                            let t = textView.beat(atX: inTP.x, interval: interval)
                            let notes: [Note] = nis.map {
                                var note = score.notes[$0]
                                note.pitch -= pitch
                                note.beatRange.start -= t
                                return note
                            }
                            if isSendPasteboard {
                                Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: notes))]
                            }
                            let rects = nis
                                .map { textView.noteFrame(from: score.notes[$0], score, timeframe) }
                                .map { textView.convertToWorld($0) }
                            let lw = Line.defaultLineWidth * 2 / document.worldToScreenScale
                            selectingLineNode.children = rects.map {
                                Node(path: Path($0),
                                     lineWidth: lw,
                                     lineType: .color(.selected),
                                     fillType: .color(.subSelected))
                            }
                        }
                    }
                }
            } else {
                if isSendPasteboard {
                    let se = LineEditor(document)
                    se.updateClipBoundsAndIndexRange(at: p)
                    if let r = document.selections.map({ $0.rect }).union() {
                        se.tempLine = Line(r) * Transform(translation: -se.centerOrigin)
                        se.lassoCopy(isRemove: false,
                                     isEnableLine: !document.isSelectedText,
                                     isEnablePlane: !document.isSelectedText,
                                     isSplitLine: false,
                                     selections: document.selections,
                                     at: p)
                    }
                }
                let rects = document.isSelectedText ?
                document.selectedFrames :
                document.selections.map { $0.rect } + document.selectedFrames
                let lw = Line.defaultLineWidth * 2 / document.worldToScreenScale
                selectingLineNode.children = rects.map {
                    Node(path: Path($0),
                         lineWidth: lw,
                         lineType: .color(.selected),
                         fillType: .color(.subSelected))
                }
            }
            
            return true
        } else if document.containsLookingUp(at: p),
                  !document.lookingUpString.isEmpty {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.string(document.lookingUpString)]
            }
            
            let lw = Line.defaultLineWidth * 2 / document.worldToScreenScale
            selectingLineNode.children =
            [Node(path: document.lookingUpBoundsNode?.path ?? Path(),
                     lineWidth: lw,
                     lineType: .color(.selected),
                     fillType: .color(.subSelected))]
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (textView, _, si, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
            
            if let node = document.findingNode(at: p) {
                if isSendPasteboard {
                    if let range = textView.model.string.ranges(of: document.finding.string)
                        .first(where: { $0.contains(si) }) {
                        
                        var text = textView.model
                        text.string = document.finding.string
                        let minP = textView.typesetter.characterPosition(at: range.lowerBound)
                        text.origin -= sheetView.convertFromWorld(p) - minP
                        Pasteboard.shared.copiedObjects = [.text(text),
                                                           .string(text.string)]
                    }
                }
                let scale = 1 / document.worldToScreenScale
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
                let origin = document.sheetFrame(with: document.sheetPosition(at: p)).origin
                let path =  wcPath * Transform(translation: textView.model.origin + origin)
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                selectingLineNode.lineWidth = document.worldLineWidth
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
            let scale = 1 / document.worldToScreenScale
            selectingLineNode.children = paths.map {
                Node(path: $0,
                     lineWidth: Line.defaultLineWidth * scale,
                     lineType: .color(.selected),
                     fillType: .color(.subSelected))
            }
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (ti, timeframe) = sheetView.timeframeTuple(at: sheetView.convertFromWorld(p)) {
            
            let textView = sheetView.textsView.elementViews[ti]
            let inTP = textView.convertFromWorld(p)
            
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            
            if textView.containsScore(inTP),
               var timeframe = textView.model.timeframe,
               let score = timeframe.score,
               let ni = textView.noteIndex(at: inTP,
                                           maxDistance: 2.0 * document.screenToWorldScale),
               let pitch = document.pitch(from: textView, at: inTP) {
                    
                let interval = document.currentNoteTimeInterval(from: textView.model)
                let beat = textView.beat(atX: inTP.x, interval: interval)
                var note = score.notes[ni]
                note.pitch -= pitch
                note.beatRange.start -= beat
                timeframe.score?.notes.remove(at: ni)
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects
                        = [.notesValue(NotesValue(notes: [note]))]
                }
                let rects = [textView.noteFrame(from: score.notes[ni], score, timeframe)]
                    .map { textView.convertToWorld($0) }
                let lw = Line.defaultLineWidth * 2 / document.worldToScreenScale
                selectingLineNode.children = rects.map {
                    Node(path: Path($0),
                         lineWidth: lw,
                         lineType: .color(.selected),
                         fillType: .color(.subSelected))
                }
            } else if textView.containsSpectlope(inTP),
               let score = textView.model.timeframe?.score {
                
                if let (i, _, isLast) = textView.spectlopeType(at: inTP, maxDistance: 25.0 * document.screenToWorldScale),
                   !isLast {
                   
                    if isSendPasteboard {
                        Pasteboard.shared.copiedObjects = [.formant(score.tone.spectlope.formants[i])]
                    }
                    if let frame = textView.formantFrame(at: i) {
                        selectingLineNode.path = Path(textView.convertToWorld(frame))
                    }
                } else {
                    if isSendPasteboard {
                        Pasteboard.shared.copiedObjects = [.tone(score.tone)]
                    }
                    if let frame = textView.spectlopeFrame {
                        selectingLineNode.path = Path(textView.convertToWorld(frame))
                    }
                }
            } else if textView.containsVolume(inTP),
               let volume = timeframe.volume {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.normalizationValue(volume.amp)]
                }
                if let frame = textView.volumeFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            } else if textView.containsPan(inTP),
               let pan = timeframe.pan {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.normalizationValue(pan)]
                }
                if let frame = textView.panFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            } else if textView.containsReverb(inTP),
               let reverb = timeframe.reverb {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.normalizationValue(reverb)]
                }
                if let frame = textView.reverbFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            } else if textView.containsIsShownSpectrogram(inTP) {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.normalizationValue(timeframe.isShownSpectrogram ? 1 : 0)]
                }
                if let frame = textView.isShownSpectrogramFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            } else if textView.containsOctave(inTP),
                      let octave = timeframe.score?.octave {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.normalizationRationalValue(octave)]
                }
                if let frame = textView.octaveFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            } else if let type = textView.overtoneType(at: inTP),
                      let value = timeframe.score?.tone.overtone[type] {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.normalizationValue(value)]
                }
                if let p = textView.overtonePosition(at: type) {
                    selectingLineNode.path = Path(circleRadius: 2,
                                                  position: textView.convertToWorld(p))
                }
            } else if textView.containsEnvelope(inTP),
                      let envelope = timeframe.score?.tone.envelope {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.envelope(envelope)]
                }
                if let frame = textView.envelopeFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            } else if textView.containsPitchDecay(inTP),
                      let pitchbend = timeframe.score?.tone.pitchbend {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.pitchbend(pitchbend)]
                }
                if let frame = textView.pitchDecayFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            } else if textView.containsTimeRange(inTP) {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.timeframe(timeframe)]
                }
                if let frame = textView.timeRangeFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            } else if textView.containsScore(inTP) {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.timeframe(timeframe)]
                }
                if let frame = textView.scoreFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            } else if textView.containsTone(inTP),
                        let tone = timeframe.score?.tone {
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.tone(tone)]
                }
                if let frame = textView.toneFrame {
                    selectingLineNode.path = Path(textView.convertToWorld(frame))
                }
            }
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let lineView = sheetView.lineTuple(at: sheetView.convertFromWorld(p),
                                                     scale: 1 / document.worldToScreenScale)?.lineView {
            
            let t = Transform(translation: -sheetView.convertFromWorld(p))
            let ssv = SheetValue(lines: [lineView.model],
                                 planes: [], texts: [],
                                 origin: sheetView.convertFromWorld(p),
                                 id: sheetView.id,
                                 rootKeyframeIndex: sheetView.model.animation.rootIndex) * t
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.sheetValue(ssv)]
            }
            
            let scale = 1 / document.worldToScreenScale
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
        } else if let (sBorder, edge) = document.worldBorder(at: p, distance: d) {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.border(sBorder)]
            }
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            return true
        } else if let (border, _, edge) = document.border(at: p, distance: d) {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.border(border)]
            }
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            return true
        } else if !document.isDefaultUUColor(at: p) {
            let colorOwners = document.readColorOwners(at: p)
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
                            [.uuColor(document.uuColor(at: p)),
                             .sheetValue(sheetValue)]
                    } else {
                        Pasteboard.shared.copiedObjects =
                            [.uuColor(document.uuColor(at: p))]
                    }
                }
                let scale = 1 / document.worldToScreenScale
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
                return true
            }
        }
        return false
    }
    
    @discardableResult
    func cut(at p: Point) -> Bool {
        let d = 5 / document.worldToScreenScale
        
        if let sheetView = document.sheetView(at: p),
           sheetView.containsTimeline(sheetView.convertFromWorld(p)),
           let ki = sheetView.animationView.keyframeIndex(at: sheetView.convertFromWorld(p), isEnabledCount: true) {
            
            let animationView = sheetView.animationView
            
            let isSelected = animationView.selectedFrameIndexes.contains(ki)
            var indexes = isSelected ?
                animationView.selectedFrameIndexes.sorted() : [ki]
            if indexes.last == animationView.model.keyframes.count {
                indexes.removeLast()
            }
            let kfs = indexes.map { animationView.model.keyframes[$0] }
            
            if isSelected {
                animationView.selectedFrameIndexes = []
            }
            sheetView.newUndoGroup(enabledKeyframeIndex: false)
            if indexes.count == animationView.model.keyframes.count {
                let keyframe = Keyframe(beatDuration: 0)
                sheetView.insert([IndexValue(value: keyframe, index: 0)])
                sheetView.removeKeyframes(at: indexes)
                
                var option = sheetView.model.animation.option
                option.enabled = false
                sheetView.set(option)
                
                sheetView.rootKeyframeIndex = 0
            } else {
                var setDurs = [(i: Int, dur: Rational)](), di = 0, preI: Int?
                var fbd = Rational(0)
                for i in indexes {
                    let dur = animationView.model.keyframes[i].beatDuration
                    if preI == i - 1 {
                        if setDurs.isEmpty {
                            fbd += dur
                        } else {
                            setDurs[.last].dur += dur
                        }
                    } else if i > 0 {
                        let ni = i - 1
                        let nkf = animationView.model.keyframes[ni]
                        setDurs.append((ni - di, nkf.beatDuration + dur))
                    } else {
                        fbd = dur
                    }
                    di += 1
                    preI = i
                }
                sheetView.removeKeyframes(at: indexes)
                if fbd > 0 {
                    var ao = animationView.model.option
                    ao.startBeat += fbd
                    sheetView.set(ao)
                }
                let kiovs = setDurs.map {
                    IndexValue(value: KeyframeOption(beatDuration: $0.dur,
                                                     previousNext: animationView.model.keyframes[$0.i].previousNext),
                               index: $0.i)
                }
                sheetView.set(kiovs)
            }
            document.updateSelects()

            Pasteboard.shared.copiedObjects = [.animation(Animation(keyframes: kfs))]
        } else if document.isSelectSelectedNoneCursor(at: p), !document.selections.isEmpty {
            if document.isSelectedText, document.selections.count == 1 {
                document.textEditor.cut(from: document.selections[0], at: p)
            } else {
                if let sheetView = document.sheetView(at: p),
                          let ti = sheetView.timeframeIndex(at: sheetView.convertFromWorld(p)) {
                    let textView = sheetView.textsView.elementViews[ti]
                    let inTP = textView.convertFromWorld(p)
                    if textView.containsScore(inTP),
                       let timeframe = textView.model.timeframe,
                        var score = timeframe.score {
                        
                        if let pitch = document.pitch(from: textView, at: inTP) {
                            
                            let nis = document.selectedNoteIndexes(from: textView)
                            if !nis.isEmpty {
                                let interval = document.currentNoteTimeInterval(from: textView.model)
                                let t = textView.beat(atX: inTP.x, interval: interval)
                                let notes: [Note] = nis.map {
                                    var note = score.notes[$0]
                                    note.pitch -= pitch
                                    note.beatRange.start -= t
                                    return note
                                }
                                score.notes.remove(at: nis)
                                Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: notes))]
                                sheetView.newUndoGroup()
                                sheetView.replaceScore(score, at: ti)
                                
                                sheetView.updatePlaying()
                            }
                        }
                    }
                } else {
                    let se = LineEditor(document)
                    se.updateClipBoundsAndIndexRange(at: p)
                    if let r = document.selections.map({ $0.rect }).union() {
                        se.tempLine = Line(r) * Transform(translation: -se.centerOrigin)
                        se.lassoCopy(isRemove: true,
                                     isEnableLine: !document.isSelectedText,
                                     isEnablePlane: !document.isSelectedText,
                                     isSplitLine: false,
                                     selections: document.selections,
                                     at: p)
                    }
                }
            }
            
            document.selections = []
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let ti = sheetView.timeframeIndex(at: sheetView.convertFromWorld(p)) {
        
            let textView = sheetView.textsView.elementViews[ti]
            let inTP = textView.convertFromWorld(p)
            if textView.containsScore(inTP),
               let timeframe = textView.model.timeframe,
               var score = timeframe.score {
                
                let maxD = textView.nodeRatio
                * 15.0 * document.screenToWorldScale
                if let score = timeframe.score,
                   let (ni, pitI, _, pitbend) = textView.pitbendTuple(at: inTP,
                                                          maxDistance: maxD) {
                    var pitbend = pitbend
                    if !pitbend.pits.isEmpty {
                        pitbend.pits.remove(at: pitI)
                        var score = score
                        score.notes[ni].pitbend = pitbend
                        
                        sheetView.newUndoGroup()
                        sheetView.replaceScore(score, at: ti)
                        
                        sheetView.updatePlaying()
                        return true
                    }
                }
                
                if let noteI = textView.noteIndex(at: inTP,
                                                  maxDistance: 2.0 * document.screenToWorldScale),
                   let pitch = document.pitch(from: textView, at: inTP) {
                    let interval = document.currentNoteTimeInterval(from: textView.model)
                    let beat = textView.beat(atX: inTP.x, interval: interval)
                    var note = score.notes[noteI]
                    note.pitch -= pitch
                    note.beatRange.start -= beat
                    score.notes.remove(at: noteI)
                    Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [note]))]
                    sheetView.newUndoGroup()
                    sheetView.replaceScore(score, at: ti)
                    
                    sheetView.updatePlaying()
                    return true
                }
            } else if textView.containsPan(inTP),
                      var timeframe = textView.model.timeframe,
                      let pan = timeframe.pan, pan != 0 {
                timeframe.pan = 0
                Pasteboard.shared.copiedObjects = [.normalizationValue(pan)]
                sheetView.newUndoGroup()
                var text = textView.model
                text.timeframe = timeframe
                sheetView.replace([IndexValue(value: text, index: ti)])
                return true
            } else if textView.containsReverb(inTP),
                      var timeframe = textView.model.timeframe,
                      let reverb = timeframe.reverb, (timeframe.content?.type == .sound && reverb != 0) || reverb != Audio.defaultReverb {
                timeframe.reverb = timeframe.content?.type == .sound ? 0 : Audio.defaultReverb
                Pasteboard.shared.copiedObjects = [.normalizationValue(reverb)]
                sheetView.newUndoGroup()
                var text = textView.model
                text.timeframe = timeframe
                sheetView.replace([IndexValue(value: text, index: ti)])
                return true
            } else if textView.containsSpectlope(inTP),
                      let timeframe = textView.model.timeframe,
                      var score = timeframe.score {
                
                if let (i, _, isLast) = textView.spectlopeType(at: inTP, maxDistance: 25.0 * document.screenToWorldScale),
                   !isLast {
                   
                    let formant = score.tone.spectlope.formants[i]
                    var spectlope = score.tone.spectlope
                    spectlope.formants.remove(at: i)
                    score.tone.spectlope = spectlope
                    Pasteboard.shared.copiedObjects = [.formant(formant)]
                    sheetView.newUndoGroup()
                    sheetView.replaceScore(score, at: ti)
                    return true
                } else if score.tone.spectlope != Spectlope() {
                    score.tone.spectlope = Spectlope()
                    Pasteboard.shared.copiedObjects = [.tone(score.tone)]
                    sheetView.newUndoGroup()
                    sheetView.replaceScore(score, at: ti)
                    return true
                }
            }
            
            var text = textView.model
            let timeframe = text.timeframe
            if text.timeframe?.score != nil
                && !textView.containsTimeRange(inTP) {
                
                text.timeframe?.score = nil
            } else {
                text.timeframe = nil
            }
            if let timeframe = timeframe {
                Pasteboard.shared.copiedObjects = [.timeframe(timeframe)]
            }
            sheetView.newUndoGroup()
            sheetView.replace([IndexValue(value: text, index: ti)])
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (lineView, li) = sheetView
                    .lineTuple(at: sheetView.convertFromWorld(p),
                               scale: 1 / document.worldToScreenScale) {
            
            let t = Transform(translation: -sheetView.convertFromWorld(p))
            let ssv = SheetValue(lines: [lineView.model],
                                 planes: [], texts: [],
                                 origin: sheetView.convertFromWorld(p),
                                 id: sheetView.id,
                                 rootKeyframeIndex: sheetView.model.animation.rootIndex) * t
            Pasteboard.shared.copiedObjects = [.sheetValue(ssv)]
            
            if sheetView.model.enabledAnimation {
                let scale = 1 / document.worldToScreenScale
                let nodes = sheetView.animationView.interpolationNodes(from: [lineView.model.id], scale: scale,
                                                         removeLineIndex: li)
                if nodes.count > 1 {
                    selectingLineNode.children = nodes
                }
            }
            
            sheetView.newUndoGroup()
            sheetView.removeLines(at: [li])
            return true
        } else if let sheetView = document.sheetView(at: p),
                  let (textView, ti, si, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)) {
            if document.findingNode(at: p) != nil {
                if let range = textView.model.string.ranges(of: document.finding.string)
                    .first(where: { $0.contains(si) }) {
                    
                    var text = textView.model
                    text.string = document.finding.string
                    let minP = textView.typesetter.characterPosition(at: range.lowerBound)
                    text.origin -= sheetView.convertFromWorld(p) - minP
                    Pasteboard.shared.copiedObjects = [.text(text),
                                                       .string(text.string)]
                }
                
                document.replaceFinding(from: "")
                return true
            } else if let result = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p)), result.isLastWarp {
                let x = result.offset
                let widthCount = Typobute.maxWidthCount
                
                var text = textView.model
                if text.widthCount != widthCount {
                    text.widthCount = widthCount
                    
                    let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
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
        } else if let (border, i, edge) = document.border(at: p, distance: d),
                  let sheetView = document.sheetView(at: p) {
            
            Pasteboard.shared.copiedObjects = [.border(border)]
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            sheetView.newUndoGroup()
            sheetView.removeBorder(at: i)
            return true
         } else if !document.isDefaultUUColor(at: p) {
            let colorOwners = document.colorOwners(at: p)
            if !colorOwners.isEmpty {
                Pasteboard.shared.copiedObjects = [.uuColor(document.uuColor(at: p))]
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
                    if !$0.colorValue.value.isEmpty {
                        let ki = $0.sheetView.model.animation.index
                        for v in $0.colorValue.value {
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
    
    private var oldScale: Double?, firstRotation = 0.0, oldSnapP: Point?,
                textNode: Node?, textFrame: Rect?, textScale = 1.0
    var snapDistance = 1.0
    
    func updateWithPaste(at p: Point, atScreen sp: Point, _ phase: Phase) {
        let shp = document.sheetPosition(at: p)
        let sb = document.sheetFrame(with: shp)
        let sheetView = document.sheetView(at: shp)
        
        func updateWithValue(_ value: SheetValue) {
            let scale = firstScale * document.screenToWorldScale
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
            selectingLineNode.path = Path()
            
            let nSnapP: Point?, np: Point
            if !(sheetView?.id == value.id && sheetView?.rootKeyframeIndex == value.rootKeyframeIndex) {
                let snapP = value.origin + sb.origin
                nSnapP = snapP
                np = snapP.distance(p) < snapDistance * document.screenToWorldScale && firstScale == document.worldToScreenScale ?
                    snapP : p
                let isSnapped = np == snapP
                if isSnapped {
                    if oldSnapP != np {
                        selectingLineNode.children.last?.fillType = .color(.selected)
                        Feedback.performAlignment()
                    }
                } else {
                    if oldSnapP != np {
                        selectingLineNode.children.last?.fillType = .color(.border)
                    }
                }
                oldSnapP = np
            } else {
                np = p
                nSnapP = nil
            }
            
            if selectingLineNode.children.count == 3 {
                selectingLineNode.children[0].attitude = Attitude(position: np,
                                                                  scale: Size(square: 1.0 * scale),
                                                                  rotation: document.camera.rotation - firstRotation)
                
                let textChildren = selectingLineNode.children[1].children
                if textChildren.count == value.texts.count {
                    let screenScale = document.worldToScreenScale
                    let t = Transform(scale: 1.0 * firstScale / screenScale)
                            .rotated(by: document.camera.rotation - firstRotation)
                    let nt = t.translated(by: np - sb.minXMinYPoint)
                    for (i, text) in value.texts.enumerated() {
                        textChildren[i].attitude = Attitude(position: (text.origin) * nt + sb.minXMinYPoint,
                                                            scale: Size(square: 1.0 * scale))
                    }
                }
                
                if let snapP = nSnapP {
                    selectingLineNode.children[2].path = Path(circleRadius: isSnapped ? 5 : 3)
                    selectingLineNode.children[2].attitude = Attitude(position: snapP, scale: Size(square: document.screenToWorldScale))
                } else {
                    selectingLineNode.children[2].path = Path()
                }
            }
        }
        func updateWithText(_ text: Text) {
            let inP = p - sb.origin
            var isAppend = false
            
            var textView: SheetTextView?, sri: String.Index?
            if let aTextView = document.textEditor.editingTextView,
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
                let fScale = firstScale * document.screenToWorldScale
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
                    selectingLineNode.children = [textNode]
                } else {
                    var ntext = text
                    ntext.origin *= fScale
                    ntext.size *= fScale
                    let textNode = ntext.node
                    selectingLineNode.children = [textNode]
                    self.textNode = textNode
                    self.textFrame = ntext.frame
                    textScale = document.worldToScreenScale
                }
                
                let scale = textScale * document.screenToWorldScale
                let np: Point
                if let stb = textFrame {
                    let textFrame = stb
                        * Attitude(position: p,
                                   scale: Size(square: 1.0 * scale)).transform
                    let sb = sb.inset(by: Sheet.textPadding)
                    if !sb.contains(textFrame) {
                        let nFrame = sb.clipped(textFrame)
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
                    let scale = firstScale / document.worldToScreenScale
                    let nnp = text.origin * scale + np
                    let log10Scale: Double = .log10(document.worldToScreenScale)
                    let clipScale = max(0.0, log10Scale)
                    let decimalPlaces = Int(clipScale + 2)
                    let fp1 = nnp.rounded(decimalPlaces: decimalPlaces)
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
                            let d = 3.0 * document.screenToWorldScale
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
                selectingLineNode.lineType = .color(.border)
            }
            
            if let sheetView = sheetView,
               let (textView, _, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)),
               let x = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p))?.offset,
               textView.textOrientation == oldBorder.orientation.reversed(),
               let frame = textView.model.frame {
                let f = frame + sb.origin
                let edge: Edge
                switch textView.model.orientation {
                case .horizontal:
                    edge = Edge(Point(f.minX + x, f.minY),
                                Point(f.minX + x, f.maxY))
                case .vertical:
                    edge = Edge(Point(f.minX, f.maxY - x),
                                Point(f.maxX, f.maxY - x))
                }
                snapLineNode.children = []
                selectingLineNode.path = Path([Pathline(edge)])
                return
            }
            
            var paths = [Path]()
            let values = snappableBorderLocations(from: oldBorder.orientation,
                                                  with: sb)
            switch oldBorder.orientation {
            case .horizontal:
                func append(_ p0: Point, _ p1: Point, lw: Double = 1) {
                    paths.append(Path(Rect(x: p0.x, y: p0.y - lw / 2,
                                           width: p1.x - p0.x, height: lw)))
                }
                for value in values {
                    append(Point(sb.minX, sb.minY + value),
                           Point(sb.maxX, sb.minY + value))
                }
                append(Point(sb.minX, sb.minY + oldBorder.location),
                       Point(sb.maxX, sb.minY + oldBorder.location), lw: 0.5)
            case .vertical:
                func append(_ p0: Point, _ p1: Point, lw: Double = 1) {
                    paths.append(Path(Rect(x: p0.x - lw / 2, y: p0.y,
                                           width: lw, height: p1.y - p0.y)))
                }
                for value in values {
                    append(Point(sb.minX + value, sb.minY),
                           Point(sb.minX + value, sb.maxY))
                }
                append(Point(sb.minX + oldBorder.location, sb.minY),
                       Point(sb.minX + oldBorder.location, sb.maxY), lw: 0.5)
            }
            snapLineNode.children = paths.map {
                Node(path: $0, fillType: .color(.subSelected))
            }
            
            let inP = p - sb.origin
            let bnp = borderSnappedPoint(inP, with: sb,
                                         distance: 3 / document.worldToScreenScale,
                                         oldBorder: oldBorder)
            isSnapped = bnp.isSnapped
            let np = bnp.point + sb.origin
            switch oldBorder.orientation {
            case .horizontal:
                selectingLineNode.path = Path([Pathline([Point(sb.minX, np.y),
                                                         Point(sb.maxX, np.y)])])
            case .vertical:
                selectingLineNode.path = Path([Pathline([Point(np.x, sb.minY),
                                                         Point(np.x, sb.maxY)])])
            }
        }
        func updateIDs(_ ids: [InterOption]) {
            guard let sheetView = sheetView else { return }
            let lis: [Int]
            if document.isSelectNoneCursor(at: p),
               !document.isSelectedText, !document.selections.isEmpty {
                
                let ms = sheetView.convertFromWorld(document.multiSelection)
                lis = sheetView.model.picture.lines.enumerated()
                    .compactMap { ms.intersects($0.element) ? $0.offset : nil }
            } else {
                if let li = sheetView.lineTuple(at: sheetView.convertFromWorld(p), scale: 1 / document.worldToScreenScale)?.lineIndex {
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
            let scale = 1 / document.worldToScreenScale
            
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
        func updateNotes(_ notes: [Note]) {
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) {
                let textView = sheetView.textsView.elementViews[ti]
                let inTP = textView.convertFromWorld(p)
                if let timeframe = textView.model.timeframe,
                   let score = timeframe.score,
                   let pitch = document.pitch(from: textView, at: inTP) {
                    
                    let interval = document.currentNoteTimeInterval(from: textView.model)
                    let t = textView.beat(atX: inTP.x, interval: interval)
                    var notes = notes
                    for j in 0 ..< notes.count {
                        notes[j].pitch += pitch
                        notes[j].beatRange.start += t
                    }
                    selectingLineNode.children = notes.map {
                        let f = textView.noteFrame(from: $0, score, timeframe)
                        let nf = textView.convertToWorld(f)
                        return textView.noteNode(from: $0, at: nil, score, timeframe, frame: nf)
                    }
                }
            }
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
        case .timeframe:
            break
        case .beatRange:
            break
        case .normalizationValue:
            break
        case .normalizationRationalValue:
            break
        case .notesValue(let notesValue):
            updateNotes(notesValue.notes)
        case .tone:
            break
        case .envelope:
            break
        case .pitchbend:
            break
        case .formant:
            break
        }
    }
    
    func paste(at p: Point, atScreen sp: Point) {
        let shp = document.sheetPosition(at: p)
        
        var isRootNewUndoGroup = true
        var isUpdateUndoGroupSet = Set<SheetPosition>()
        func updateUndoGroup(with nshp: SheetPosition) {
            if !isUpdateUndoGroupSet.contains(nshp),
               let sheetView = document.sheetView(at: nshp) {
                
                sheetView.newUndoGroup()
                isUpdateUndoGroupSet.insert(nshp)
            }
        }
        
        let screenScale = document.worldToScreenScale
        func firstTransform(at p: Point) -> Transform {
            if firstScale != screenScale
                || firstRotation != document.camera.rotation {
                let t = Transform(scale: 1.0 * firstScale / screenScale)
                    .rotated(by: document.camera.rotation - firstRotation)
                return t.translated(by: p)
            } else {
                return Transform(translation: p)
            }
        }
        func transform(in frame: Rect, at p: Point) -> Transform {
            if firstScale != screenScale
                || firstRotation != document.camera.rotation{
                let t = Transform(scale: 1.0 * firstScale / screenScale)
                    .rotated(by: document.camera.rotation - firstRotation)
                return t.translated(by: p - frame.minXMinYPoint)
            } else {
                return Transform(translation: p - frame.minXMinYPoint)
            }
        }
        
        func pasteLines(_ lines: [Line], at p: Point) {
            let pt = firstTransform(at: p)
            let ratio = firstScale / document.worldToScreenScale
            let pLines: [Line] = lines.map {
                var l = $0 * pt
                l.size *= ratio
                return l
            }
            guard !pLines.isEmpty, let rect = pLines.bounds else { return }
            
            let minXMinYSHP = document.sheetPosition(at: rect.minXMinYPoint)
            let maxXMinYSHP = document.sheetPosition(at: rect.maxXMinYPoint)
            let minXMaxYSHP = document.sheetPosition(at: rect.minXMaxYPoint)
            let lx = max(minXMinYSHP.x, shp.x - 1)
            let rx = min(maxXMinYSHP.x, shp.x + 1)
            let by = max(minXMinYSHP.y, shp.y - 1)
            let ty = min(minXMaxYSHP.y, shp.y + 1)
            if lx <= rx && by <= ty {
                for xi in lx ... rx {
                    for yi in by ... ty {
                        let nshp = SheetPosition(xi, yi)
                        let frame = document.sheetFrame(with: nshp)
                        let t = transform(in: frame, at: p)
                        let oLines: [Line] = lines.map {
                            var l = $0 * t
                            l.size *= ratio
                            return l
                        }
                        var nLines = Sheet.clipped(oLines,
                                                   in: Rect(size: frame.size))
                        if !nLines.isEmpty,
                           let (sheetView, isNew) = document
                            .madeSheetViewIsNew(at: nshp,
                                                isNewUndoGroup:
                                                    isRootNewUndoGroup) {
                            if sheetView.model.enabledAnimation {
                                let idSet = Set(sheetView.model.picture.lines.map { $0.id })
                                for (i, l) in nLines.enumerated() {
                                    if idSet.contains(l.id) {
                                        nLines[i].id = UUID()
                                    }
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
            let pt = firstTransform(at: p)
            let pPlanes = planes.map { $0 * pt }
            guard !pPlanes.isEmpty, let rect = pPlanes.bounds else { return }
            
            let minXMinYSHP = document.sheetPosition(at: rect.minXMinYPoint)
            let maxXMinYSHP = document.sheetPosition(at: rect.maxXMinYPoint)
            let minXMaxYSHP = document.sheetPosition(at: rect.minXMaxYPoint)
            let lx = max(minXMinYSHP.x, shp.x - 1)
            let rx = min(maxXMinYSHP.x, shp.x + 1)
            let by = max(minXMinYSHP.y, shp.y - 1)
            let ty = min(minXMaxYSHP.y, shp.y + 1)
            if lx <= rx && by <= ty {
                for xi in lx ... rx {
                    for yi in by ... ty {
                        let nshp = SheetPosition(xi, yi)
                        let frame = document.sheetFrame(with: nshp)
                        let t = transform(in: frame, at: p)
                        let nPlanes = Sheet.clipped(planes.map { $0 * t },
                                                    in: Rect(size: frame.size))
                        if !nPlanes.isEmpty,
                           let (sheetView, isNew) = document
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
            let pt = firstTransform(at: p)
            guard !texts.isEmpty else { return }
            
            for text in texts {
                let nshp = document.sheetPosition(at: (text * pt).origin)
                guard ((shp.x - 1) ... (shp.x + 1)).contains(nshp.x)
                    && ((shp.y - 1) ... (shp.y + 1)).contains(nshp.y) else {
                    
                    continue
                }
                let frame = document.sheetFrame(with: nshp)
                let t = transform(in: frame, at: p)
                var nText = text * t
                if let (sheetView, isNew) = document
                    .madeSheetViewIsNew(at: nshp,
                                          isNewUndoGroup:
                                            isRootNewUndoGroup) {
                    let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
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
                    if nText.timeframe != nil {
                        nText.origin.y = nText.origin.y.interval(scale: 5)
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
                  let sheetView = document.madeSheetView(at: nshp) else { return }
            var text = text
            var isAppend = false
            
            document.textEditor.begin(atScreen: sp)
            if let textView = document.textEditor.editingTextView,
               !textView.isHiddenSelectedRange,
               let i = sheetView.textsView.elementViews.firstIndex(of: textView) {
                
                document.textEditor.endInputKey(isUnmarkText: true,
                                                isRemoveText: false)
                if document.findingNode(at: p) != nil,
                    document.finding.string != text.string {
                    
                    document.replaceFinding(from: text.string)
                } else if let ati = textView.selectedRange?.lowerBound {
                    let rRange: Range<Int>
                    if let selection = document.multiSelection.firstSelection(at: p),
                       let sRange = textView.range(from: selection),
                       sRange.contains(ati) {
                            
                        rRange = textView.model.string.intRange(from: sRange)
                        document.selections = []
                    } else {
                        let ti = textView.model.string.intIndex(from: ati)
                        rRange = ti ..< ti
                    }
                    let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
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
                let scale = firstScale / document.worldToScreenScale
                let nnp = text.origin * scale + np
                let log10Scale: Double = .log10(document.worldToScreenScale)
                let clipScale = max(0.0, log10Scale)
                let decimalPlaces = Int(clipScale + 2)
                let fp1 = nnp.rounded(decimalPlaces: decimalPlaces)
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
                        let d = 3.0 * document.screenToWorldScale
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
                            let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
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
                let scale = firstScale / document.worldToScreenScale
                let nnp = text.origin * scale + np
                let log10Scale: Double = .log10(document.worldToScreenScale)
                let clipScale = max(0.0, log10Scale)
                let decimalPlaces = Int(clipScale + 2)
                text.origin = nnp.rounded(decimalPlaces: decimalPlaces)
                text.size = text.size * scale
                let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
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
                if text.timeframe != nil {
                    text.timeframe?.beatRange.start = sheetView.animationView.beat(atX: np.x)
                }
                updateUndoGroup(with: nshp)
                sheetView.append(text)
            }
        }
        
        switch pasteObject {
        case .copiedSheetsValue: break
        case .picture(let picture):
            if let sheetView = document.madeSheetView(at: shp) {
                sheetView.newUndoGroup()
                sheetView.set(picture)
            }
        case .sheetValue(let value):
            let snapP = value.origin + document.sheetFrame(with: shp).origin
            let np = snapP.distance(p) < snapDistance / document.worldToScreenScale && firstScale == screenScale ?
                snapP : p
            if !value.keyframes.isEmpty {
                guard let sheetView = document.madeSheetView(at: shp) else { return }
                let pt = firstTransform(at: np)
                let ratio = firstScale / document.worldToScreenScale
                let frame = document.sheetFrame(with: shp)
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
            guard let sheetView = document.madeSheetView(at: shp) else { return }
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
            if let sheetView = document.madeSheetView(at: shp) {
                
                if let (textView, ti, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p)),
                   let x = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p))?.offset {
                    let widthCount = textView.model.size == 0 ?
                        Typobute.maxWidthCount :
                        (x / textView.model.size)
                        .clipped(min: Typobute.minWidthCount,
                                 max: Typobute.maxWidthCount)
                    
                    var text = textView.model
                    if text.widthCount != widthCount {
                        text.widthCount = widthCount
                        
                        let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
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
                }
                
                
                let sb = document.sheetFrame(with: shp)
                let inP = sheetView.convertFromWorld(p)
                let np = borderSnappedPoint(inP, with: sb,
                                            distance: 3 / document.worldToScreenScale,
                                            oldBorder: border).point
                sheetView.newUndoGroup()
                sheetView.append(Border(position: np, border: border))
            }
        case .uuColor(let uuColor):
            guard document.isSelect(at: p) else {
                guard let _ = document.madeSheetView(at: shp) else { return }
                let colorOwners = document.madeColorOwner(at: p)
                colorOwners.forEach {
                    if $0.uuColor != uuColor {
                        $0.uuColor = uuColor
                        $0.captureUUColor(isNewUndoGroup: true)
                    }
                }
                return
            }
            
            guard let (_, owners) = document.madeColorOwnersWithSelection(at: p) else { return }
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
                        $0.uuColor = uuColor
                        $0.captureUUColor(isNewUndoGroup: isNewUndoGroup)
                        isNewUndoGroup = false
                    }
                }
            }
        case .animation(let animation):
            guard !animation.keyframes.isEmpty,
                  let sheetView = document.sheetView(at: shp),
                  let ni = sheetView.keyframeIndex(at: sheetView.convertFromWorld(p),
                                                   isEnabledCount: true) else { return }
            
            let currentIndex = sheetView.model.animation.index(atRoot: sheetView.rootKeyframeIndex)
            let count = (sheetView.rootKeyframeIndex - currentIndex) / sheetView.model.animation.keyframes.count
            var ki = ni
            let kivs: [IndexValue<Keyframe>] = animation.keyframes.map {
                let v = IndexValue(value: $0, index: ki)
                ki += 1
                return v
            }
            sheetView.newUndoGroup()
            sheetView.insert(kivs)
            sheetView.rootKeyframeIndex = sheetView.model.animation.keyframes.count * count + currentIndex + 1
            document.updateEditorNode()
            document.updateSelects()
        case .ids(let idv):
            let ids = idv.ids
            guard let sheetView = document.sheetView(at: shp) else { return }
            let lis: [Int]
            if document.isSelectNoneCursor(at: p),
               !document.isSelectedText, !document.selections.isEmpty {
                
                let ms = sheetView.convertFromWorld(document.multiSelection)
                lis = sheetView.model.picture.lines.enumerated()
                    .compactMap { ms.intersects($0.element) ? $0.offset : nil }
            } else {
                if let li = sheetView.lineTuple(at: sheetView.convertFromWorld(p), scale: 1 / document.worldToScreenScale)?.lineIndex {
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
        case .timeframe(var timeframe):
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) ?? sheetView.textTuple(at: np)?.textIndex {
                var text = sheetView.model.texts[ti]
                if let beatRange =  text.timeframe?.beatRange {
                    timeframe.beatRange = beatRange
                }
                text.timeframe = timeframe
                sheetView.newUndoGroup()
                sheetView.replace([IndexValue(value: text, index: ti)])
            }
        case .beatRange(let beatRange):
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) ?? sheetView.textTuple(at: np)?.textIndex {
                let beatRange = Range(start: sheetView.animationView.beat(atX: np.x),
                                      length: beatRange.length)
                var text = sheetView.model.texts[ti]
                if text.timeframe == nil {
                    text.timeframe = Timeframe(beatRange: beatRange)
                } else {
                    text.timeframe?.beatRange = beatRange
                }
                sheetView.newUndoGroup()
                sheetView.replace([IndexValue(value: text, index: ti)])
            }
        case .normalizationValue(let nValue):
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) ?? sheetView.textTuple(at: np)?.textIndex {
                let textView = sheetView.textsView.elementViews[ti]
                var text = textView.model
                let inTP = textView.convertFromWorld(p)
                if textView.containsVolume(inTP) {
                    let volume = Volume(amp: nValue.clipped(min: 0,
                                                            max: Volume.maxAmp))
                    if volume != text.timeframe?.volume {
                        text.timeframe?.volume = volume
                        sheetView.newUndoGroup()
                        sheetView.replace([IndexValue(value: text, index: ti)])
                    }
                } else if textView.containsPan(inTP) {
                    let pan = nValue.clipped(min: -1, max: 1)
                    if pan != text.timeframe?.pan {
                        text.timeframe?.pan = pan
                        sheetView.newUndoGroup()
                        sheetView.replace([IndexValue(value: text, index: ti)])
                    }
                } else if textView.containsReverb(inTP) {
                    let reverb = nValue.clipped(min: 0, max: 1)
                    if reverb != text.timeframe?.reverb {
                        text.timeframe?.reverb = reverb
                        sheetView.newUndoGroup()
                        sheetView.replace([IndexValue(value: text, index: ti)])
                    }
                } else if textView.containsIsShownSpectrogram(inTP) {
                    let isShownSpectrogram = nValue == 0
                    if isShownSpectrogram != text.timeframe?.isShownSpectrogram {
                        text.timeframe?.isShownSpectrogram = isShownSpectrogram
                        sheetView.newUndoGroup()
                        sheetView.replace([IndexValue(value: text, index: ti)])
                    }
                } else if let type = textView.overtoneType(at: inTP),
                          var score = text.timeframe?.score {
                    switch type {
                    case .evenScale:
                        let evenScale = nValue.clipped(min: 0, max: 1)
                        if evenScale != score.tone.overtone.evenScale {
                            score.tone.overtone.evenScale = evenScale
                            sheetView.newUndoGroup()
                            sheetView.replaceScore(IndexValue(value: score, index: ti))
                        }
                    case .oddScale:
                        let oddScale = nValue.clipped(min: 0.125, max: 100)
                        if oddScale != score.tone.overtone.oddScale {
                            score.tone.overtone.oddScale = oddScale
                            sheetView.newUndoGroup()
                            sheetView.replaceScore(IndexValue(value: score, index: ti))
                        }
                    }
                }
            }
        case .normalizationRationalValue(let nValue):
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) ?? sheetView.textTuple(at: np)?.textIndex {
                let textView = sheetView.textsView.elementViews[ti]
                let inTP = textView.convertFromWorld(p)
                if textView.containsOctave(inTP),
                   var score = textView.model.timeframe?.score {
                    let octave = nValue.clipped(min: Score.minOctave,
                                                max: Score.maxOctave)
                    if octave != score.octave {
                        score.octave = octave
                        sheetView.newUndoGroup()
                        sheetView.replaceScore(IndexValue(value: score, index: ti))
                    }
                }
            }
        case .notesValue(let notesValue):
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) {
                let textView = sheetView.textsView.elementViews[ti]
                let inTP = textView.convertFromWorld(p)
                if let timeframe = textView.model.timeframe,
                   var score = timeframe.score,
                   let pitch = document.pitch(from: textView, at: inTP) {
                    
                    let interval = document.currentNoteTimeInterval(from: textView.model)
                    let t = textView.beat(atX: inTP.x, interval: interval)
                    var notes = notesValue.notes
                    for j in 0 ..< notes.count {
                        notes[j].pitch += pitch
                        notes[j].beatRange.start += t
                    }
                    score.notes += notes
                    sheetView.newUndoGroup()
                    sheetView.replaceScore(score, at: ti)
                    
                    sheetView.updatePlaying()
                }
            }
        case .tone(let tone):
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) {
                let textView = sheetView.textsView.elementViews[ti]
                if let timeframe = textView.model.timeframe,
                   var score = timeframe.score {
                    
                    score.tone = tone
                    sheetView.newUndoGroup()
                    sheetView.replaceScore(score, at: ti)
                    
                    sheetView.updatePlaying()
                }
            }
        case .envelope(let envelope):
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) {
                let textView = sheetView.textsView.elementViews[ti]
                if let timeframe = textView.model.timeframe,
                   var score = timeframe.score {
                    
                    score.tone.envelope = envelope
                    sheetView.newUndoGroup()
                    sheetView.replaceScore(score, at: ti)
                    
                    sheetView.updatePlaying()
                }
            }
        case .pitchbend(let pitchbend):
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) {
                let textView = sheetView.textsView.elementViews[ti]
                if let timeframe = textView.model.timeframe,
                   var score = timeframe.score {
                    
                    score.tone.pitchbend = pitchbend
                    sheetView.newUndoGroup()
                    sheetView.replaceScore(score, at: ti)
                    
                    sheetView.updatePlaying()
                }
            }
        case .formant(var formant):
            guard let sheetView = document.sheetView(at: shp) else { return }
            let np = sheetView.convertFromWorld(p)
            if let ti = sheetView.timeframeIndex(at: np) {
                let textView = sheetView.textsView.elementViews[ti]
                let inTP = textView.convertFromWorld(p)
                if let timeframe = textView.model.timeframe,
                   var score = timeframe.score,
                   let i = textView.formantIndex(at: inTP.x),
                   let fq = textView.spectlopeFq(atX: inTP.x) {
                    
                    formant.fq = fq
                    score.tone.spectlope.formants.insert(formant, at: i + 1)
                    sheetView.newUndoGroup()
                    sheetView.replaceScore(score, at: ti)
                    
                    sheetView.updatePlaying()
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
        case .timeframe: false
        case .beatRange: false
        case .normalizationValue: false
        case .normalizationRationalValue: false
        case .notesValue: true
        case .tone: false
        case .envelope: false
        case .pitchbend: false
        case .formant: false
        }
    }
    
    func cut(with event: InputKeyEvent) {
        let sp = document.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        for runner in document.runners {
            if runner.containsStep(p) {
                Pasteboard.shared.copiedObjects
                    = [.string(runner.stepString)]
                runner.stop()
                return
            } else if runner.containsDebug(p) {
                Pasteboard.shared.copiedObjects
                    = [.string(runner.debugString)]
                runner.stop()
                return
            }
        }
        if document.containsLookingUp(at: p) {
            document.closeLookingUpNode()
            return
        }
        
        guard isEditingSheet else {
            cutSheet(with: event)
            return
        }
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .cut
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            cut(at: editingP)
            
            document.updateSelects()
            document.updateFinding(at: editingP)
            document.updateTextCursor()
            document.rootNode.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    func copy(with event: InputKeyEvent) {
        guard isEditingSheet else {
            copySheet(with: event)
            return
        }
        let sp = document.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .copy
            firstScale = document.worldToScreenScale
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            updateWithCopy(for: editingP,
                           isSendPasteboard: true, isCutColor: false)
            document.rootNode.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    func paste(with event: InputKeyEvent) {
        guard isEditingSheet else {
            pasteSheet(with: event)
            return
        }
        guard !isEditingText else { return }
        
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            if let textView = document.textEditor.editingTextView,
               !textView.isHiddenSelectedRange,
               let sheetView = document.textEditor.editingSheetView,
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
                    document.textEditor.endInputKey(isUnmarkText: true,
                                                    isRemoveText: false)
                    guard let ti = textView.selectedRange?.lowerBound,
                          ti >= textView.model.string.startIndex else { return }
                    let text = textView.model
                    let nti = text.string.intIndex(from: ti)
                    let sb = sheetView.model.bounds.inset(by: Sheet.textPadding)
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
            
            document.cursor = .arrow
            
            type = .paste
            firstScale = document.worldToScreenScale
            firstRotation = document.camera.rotation
            textScale = firstScale
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            guard let o = Pasteboard.shared.copiedObjects.first else { return }
            pasteObject = o
            if isMovePasteObject {
                selectingLineNode.lineWidth = document.worldLineWidth
                snapLineNode.lineWidth = selectingLineNode.lineWidth
                updateWithPaste(at: editingP, atScreen: sp,
                                event.phase)
                document.rootNode.append(child: snapLineNode)
                document.rootNode.append(child: selectingLineNode)
            } else {
                paste(at: editingP, atScreen: sp)
            }
        case .changed:
            if isMovePasteObject {
                editingSP = sp
                editingP = document.convertScreenToWorld(sp)
                updateWithPaste(at: editingP, atScreen: sp,
                                event.phase)
            }
        case .ended:
            if isMovePasteObject {
                editingSP = sp
                editingP = document.convertScreenToWorld(sp)
                paste(at: editingP, atScreen: sp)
                snapLineNode.removeFromParent()
                selectingLineNode.removeFromParent()
            }
            
            document.updateSelects()
            document.updateFinding(at: editingP)
            document.updateTextCursor()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    struct Value {
        var shp: SheetPosition, frame: Rect
    }
    func values(at p: Point, isCut: Bool) -> [Value] {
        if document.isSelectSelectedNoneCursor(at: p), !document.isSelectedText {
            let vs: [Value] = document.world.sheetIDs.keys.compactMap { shp in
                let frame = document.sheetFrame(with: shp)
                return document.multiSelection.intersects(frame) ?
                    Value(shp: shp, frame: frame) : nil
            }
            if isCut {
                document.selections = []
            }
            return vs
        } else {
            let shp = document.sheetPosition(at: p)
            if document.sheetID(at: shp) != nil {
                return [Value(shp: shp,
                              frame: document.sheetFrame(with: shp))]
            } else {
                return []
            }
        }
    }
    
    func updateWithCopySheet(at dp: Point, from values: [Value]) {
        var csv = CopiedSheetsValue()
        for value in values {
            if let sid = document.sheetID(at: value.shp) {
                csv.sheetIDs[value.shp] = sid
            }
        }
        if !csv.sheetIDs.isEmpty {
            csv.deltaPoint = dp
            Pasteboard.shared.copiedObjects = [.copiedSheetsValue(csv)]
        }
    }
    
    func updateWithPasteSheet(at sp: Point, phase: Phase) {
        let p = document.convertScreenToWorld(sp)
        if case .copiedSheetsValue(let csv) = pasteObject {
            if phase == .began {
                let lw = Line.defaultLineWidth / document.worldToScreenScale
                pasteSheetNode.children = csv.sheetIDs.map {
                    let fillType = document.readFillType(at: $0.value)
                        ?? .color(.disabled)
                    
                    let sf = document.sheetFrame(with: $0.key)
                    return Node(attitude: Attitude(position: sf.origin),
                                path: Path(Rect(size: sf.size)),
                                lineWidth: lw,
                                lineType: .color(.selected), fillType: fillType)
                }
            }
            
            var children = [Node]()
            for (shp, _) in csv.sheetIDs {
                var sf = document.sheetFrame(with: shp)
                sf.origin += p - csv.deltaPoint
                let nshp = document.sheetPosition(at: sf.centerPoint)
                if document.sheetID(at: nshp) == nil {
                    let sf = document.sheetFrame(with: nshp)
                    let lw = Line.defaultLineWidth / document.worldToScreenScale
                    children.append(Node(attitude: Attitude(position: sf.origin),
                                         path: Path(Rect(size: sf.size)),
                                         lineWidth: lw,
                                         lineType: selectingLineNode.lineType,
                                         fillType: selectingLineNode.fillType))
                }
            }
            selectingLineNode.children = children
            
            pasteSheetNode.attitude.position = p - csv.deltaPoint
        }
    }
    func pasteSheet(at sp: Point) {
        document.cursorPoint = sp
        let p = document.convertScreenToWorld(sp)
        if case .copiedSheetsValue(let csv) = pasteObject {
            var nIndexes = [SheetPosition: SheetID]()
            var removeIndexes = [SheetPosition]()
            for (shp, sid) in csv.sheetIDs {
                var sf = document.sheetFrame(with: shp)
                sf.origin += p - csv.deltaPoint
                let nshp = document.sheetPosition(at: sf.centerPoint)
                
                if document.sheetID(at: nshp) != nil {
                    removeIndexes.append(nshp)
                }
                if document.sheetPosition(at: sid) != nil {
                    nIndexes[nshp] = document.duplicateSheet(from: sid)
                } else {
                    nIndexes[nshp] = sid
                }
            }
            if !removeIndexes.isEmpty || !nIndexes.isEmpty {
                document.history.newUndoGroup()
                if !removeIndexes.isEmpty {
                    document.removeSheets(at: removeIndexes)
                }
                if !nIndexes.isEmpty {
                    document.append(nIndexes)
                }
                document.updateNode()
            }
        }
    }
    
    func cutSheet(with event: InputKeyEvent) {
        let sp = document.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .cut
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            let p = document.convertScreenToWorld(sp)
            let values = self.values(at: p, isCut: true)
            updateWithCopySheet(at: p, from: values)
            if !values.isEmpty {
                let shps = values.map { $0.shp }
                document.cursorPoint = sp
                document.close(from: shps)
                document.newUndoGroup()
                document.removeSheets(at: shps)
            }
            
            document.updateSelects()
            document.updateWithFinding()
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    
    func copySheet(with event: InputKeyEvent) {
        let sp = document.selectedScreenPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .copy
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            
            let p = document.convertScreenToWorld(sp)
            let values = self.values(at: p, isCut: false)
            selectingLineNode.children = values.map {
                let sf = $0.frame
                return Node(attitude: Attitude(position: sf.origin),
                            path: Path(Rect(size: sf.size)),
                            lineWidth: selectingLineNode.lineWidth,
                            lineType: selectingLineNode.lineType,
                            fillType: selectingLineNode.fillType)
            }
            updateWithCopySheet(at: p, from: values)
            
            document.rootNode.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
    var pasteSheetNode = Node()
    func pasteSheet(with event: InputKeyEvent) {
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            type = .paste
            firstScale = document.worldToScreenScale
            editingSP = sp
            editingP = document.convertScreenToWorld(sp)
            pasteObject = Pasteboard.shared.copiedObjects.first
                ?? .sheetValue(SheetValue())
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = document.worldLineWidth
            
            document.rootNode.append(child: selectingLineNode)
            document.rootNode.append(child: pasteSheetNode)
            
            updateWithPasteSheet(at: sp, phase: event.phase)
        case .changed:
            updateWithPasteSheet(at: sp, phase: event.phase)
        case .ended:
            pasteSheet(at: sp)
            selectingLineNode.removeFromParent()
            pasteSheetNode.removeFromParent()
            
            document.updateSelects()
            document.updateWithFinding()
            
            document.cursor = Document.defaultCursor
        }
    }
}
