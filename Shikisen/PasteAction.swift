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

import struct Foundation.Data
import struct Foundation.UUID

struct ColorPathValue {
    var paths: [Path], lineType: Node.LineType?, fillType: Node.FillType?
}

struct CopiedSheetsValue: Equatable {
    var deltaPoint = Point()
    var sheetIDs = [IntPoint: UUID]()
    var isSelected = false
}
extension CopiedSheetsValue: Protobuf {
    init(_ pb: PBCopiedSheetsValue) throws {
        deltaPoint = try Point(pb.deltaPoint)
        sheetIDs = try [IntPoint: UUID](pb.sheetIds)
        isSelected = pb.isSelected
    }
    var pb: PBCopiedSheetsValue {
        .with {
            $0.deltaPoint = deltaPoint.pb
            $0.sheetIds = sheetIDs.pb
            $0.isSelected = isSelected
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
    var isSelected: Bool
}
extension NotesValue: Protobuf {
    init(_ pb: PBNotesValue) throws {
        notes = try pb.notes.map { try Note($0) }
        deltaPitch = (try? .init(pb.deltaPitch)) ?? 0
        isSelected = pb.isSelected
    }
    var pb: PBNotesValue {
        .with {
            $0.notes = notes.map { $0.pb }
            $0.deltaPitch = deltaPitch.pb
            $0.isSelected = isSelected
        }
    }
}

struct CopiedAnimation: Codable {
    var animation: Animation
    var sheetID: UUID
    var keyframeID: UUID
}
extension CopiedAnimation: Protobuf {
    init(_ pb: PBCopiedAnimation) throws {
        animation = try .init(pb.animation)
        sheetID = try UUID(pb.sheetID)
        keyframeID = try UUID(pb.keyframeID)
    }
    var pb: PBCopiedAnimation {
        .with {
            $0.animation = animation.pb
            $0.sheetID = sheetID.pb
            $0.keyframeID = keyframeID.pb
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
    case copiedAnimation(_ copiedAnimation: CopiedAnimation)
    case ids(_ ids: InteroptionsValue)
    case content(_ content: Content)
    case image(_ image: Image)
    case beatRange(_ beatRange: Range<Rational>)
    case normalizationValue(_ normalizationValue: Double)
    case normalizationRationalValue(_ normalizationRationalValue: Rational)
    case notesValue(_ notesValue: NotesValue)
    case stereo(_ stereo: Stereo)
    case tone(_ tone: Tone)
    case rect(_ rect: Rect)
    case tempo(_ tempo: Rational)
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
        case .copiedAnimation(let copiedAnimation):
             PastableObject.typeName(with: copiedAnimation)
        case .ids(let ids):
             PastableObject.typeName(with: ids)
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
        case .rect(let rect):
             PastableObject.typeName(with: rect)
        case .tempo(let tempo):
             PastableObject.typeName(with: tempo)
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
        case PastableObject.objectTypeName(with: CopiedAnimation.self):
            self = .copiedAnimation(try CopiedAnimation(serializedData: data))
        case PastableObject.objectTypeName(with: InteroptionsValue.self):
            self = .ids(try InteroptionsValue(serializedData: data))
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
        case PastableObject.objectTypeName(with: Rect.self):
            self = .rect(try Rect(serializedData: data))
        case PastableObject.objectTypeName(with: Rational.self):
            self = .tempo(try Rational(serializedData: data))
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
        case .copiedAnimation(let copiedAnimation):
             try? copiedAnimation.serializedData()
        case .ids(let ids):
             try? ids.serializedData()
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
        case .rect(let rect):
             try? rect.serializedData()
        case .tempo(let tempo):
             try? tempo.serializedData()
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
        case .copiedAnimation(let copiedAnimation):
            self = .copiedAnimation(try CopiedAnimation(copiedAnimation))
        case .ids(let ids):
            self = .ids(try InteroptionsValue(ids))
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
        case .rect(let rect):
            self = .rect(try Rect(rect))
        case .tempo(let tempo):
            self = .tempo(try Rational(tempo))
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
            case .copiedAnimation(let copiedAnimation):
                $0.value = .copiedAnimation(copiedAnimation.pb)
            case .ids(let ids):
                $0.value = .ids(ids.pb)
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
            case .rect(let rect):
                $0.value = .rect(rect.pb)
            case .tempo(let tempo):
                $0.value = .tempo(tempo.pb)
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
        case copiedAnimation = "8"
        case ids = "9"
        case content = "16"
        case image = "20"
        case beatRange = "11"
        case normalizationValue = "12"
        case normalizationRationalValue = "15"
        case notesValue = "13"
        case stereo = "22"
        case tone = "14"
        case rect = "23"
        case tempo = "24"
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
        case .copiedAnimation:
            self = .copiedAnimation(try container.decode(CopiedAnimation.self))
        case .ids:
            self = .ids(try container.decode(InteroptionsValue.self))
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
        case .rect:
            self = .rect(try container.decode(Rect.self))
        case .tempo:
            self = .tempo(try container.decode(Rational.self))
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
        case .copiedAnimation(let copiedAnimation):
            try container.encode(CodingTypeKey.copiedAnimation)
            try container.encode(copiedAnimation)
        case .ids(let ids):
            try container.encode(CodingTypeKey.ids)
            try container.encode(ids)
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
        case .rect(let rect):
            try container.encode(CodingTypeKey.rect)
            try container.encode(rect)
        case .tempo(let tempo):
            try container.encode(CodingTypeKey.tempo)
            try container.encode(tempo)
        }
    }
}
extension PastableObject {
    enum FileType: FileTypeProtocol, CaseIterable {
        case skp
        var name: String { "Pastable Object" }
        var utType: UTType { UTType(exportedAs: "\(System.id).shikisenp") }
    }
}

final class CutAction: InputKeyEventAction {
    let action: APasteAction
    
    init(_ rootAction: RootAction) {
        action = APasteAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.cut(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class CopyAction: InputKeyEventAction {
    let action: APasteAction
    
    init(_ rootAction: RootAction) {
        action = APasteAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.copy(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class PasteAction: InputKeyEventAction {
    let action: APasteAction
    
    init(_ rootAction: RootAction) {
        action = APasteAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.paste(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class APasteAction: Action {
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
    var pasteObject = PastableObject.sheetValue(SheetValue(isSelected: false))
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
            case .cut:
                selectingLineNode.path = .init()
                selectingLineNode.children = []
            case .copy: updateWithCopy(for: editingP, isSendPasteboard: true)
            case .paste:
                let p = rootView.convertScreenToWorld(editingSP)
                updateWithPaste(at: p, atScreen: editingSP, .changed, nil)
            }
        }
    }
    
    @discardableResult
    func updateWithCopy(for p: Point, isSendPasteboard: Bool) -> Bool {
        if let sheetView = rootView.sheetView(at: p),
           sheetView.animationView.containsTimeline(sheetView.animationView.timelineNode.convertFromWorld(p), scale: rootView.screenToWorldScale),
           let ki = sheetView.animationView.keyframeIndex(at: sheetView.animationView.timelineNode.convertFromWorld(p),
                                                          scale: rootView.screenToWorldScale) {
            
            let animationView = sheetView.animationView
            
            let isSelected = animationView.selectedIs.contains(ki)
            let indexes = isSelected ?
            animationView.selectedIs.sorted() : [ki]
            var beat: Rational = 0
            let kfs = indexes.map {
                var kf = animationView.model.keyframes[$0]
                let nextBeat = $0 + 1 < animationView.model.keyframes.count ? animationView.model.keyframes[$0 + 1].beat : animationView.model.beatRange.upperBound
                let dBeat = nextBeat - kf.beat
                kf.beat = beat
                beat += dBeat
                return kf
            }
            
            Pasteboard.shared.copiedObjects
            = [.copiedAnimation(.init(animation: .init(keyframes: kfs),
                                      sheetID: sheetView.id,
                                      keyframeID: animationView.model.keyframes[ki].id))]
            
            selectingLineNode.fillType = .color(.selected)
            let scale = rootView.screenToWorldScale
            let rects = indexes
                .compactMap { animationView.transformedKeyframeBounds(at: $0)?.outset(by: 2 * scale) }
            selectingLineNode.path = Path(rects.map { Pathline(sheetView.convertToWorld($0)) })
            
            return true
        } else if let sheetView = rootView.sheetViewWithSelectedSheetValue(at: p),
                  let sheetValue = sheetView.selectedSheetValue() {
            let sheetP = sheetView.convertFromWorld(p)
            let t = Transform(translation: -sheetP)
            var sheetValue = sheetValue * t
            sheetValue.origin = sheetP
            if isSendPasteboard {
                if let s = sheetValue.string {
                    Pasteboard.shared.copiedObjects = [.sheetValue(sheetValue), .string(s)]
                } else {
                    Pasteboard.shared.copiedObjects = [.sheetValue(sheetValue)]
                }
            }
            
            let lw = rootView.worldLineWidth * 2
            
            let lineNodes = sheetView.keyframeView.selectedLineIs.map {
                let line = sheetView.model.picture.lines[$0]
                return Node(path: Path(sheetView.convertToWorld(line)),
                            lineWidth: line.size * 1.5,
                            lineType: .color(.selected))
            }
            let planeNodes = sheetView.keyframeView.selectedPlaneIs.map {
                let node = sheetView.keyframeView.planesView.elementViews[$0].node.clone
                node.attitude *= sheetView.node.worldTransform
                node.fillType = .color(sheetView.model.picture.planes[$0].uuColor.value + .subSelected)
                return node
            }
            let textNodes = sheetView.selectedTextFrames
                .map { sheetView.convertToWorld($0) }
                .map { Node(path: Path($0),
                            lineWidth: lw,
                            lineType: .color(.selected),
                            fillType: .color(.subSelected))
            }
            let contentNodes: [Node] = sheetView.selectedContentIs.compactMap {
                guard let f = sheetView.contentsView.elementViews[$0].imageFrame else { return nil }
                return Node(path: Path(sheetView.convertToWorld(f)),
                            lineWidth: 2,
                            lineType: .color(.selected),
                            fillType: .color(.subSelected))
            }
            let selectedFrameNodes: [Node]
            let scale = rootView.screenToWorldScale
            if let selectedFrame = sheetView.selectedFrame(scale: scale) {
                let rect = sheetView.convertToWorld(selectedFrame)
                let lastP: Point? = if let p = sheetView.selection.lastPosition { sheetView.convertToWorld(p) } else { nil }
                selectedFrameNodes = SheetView.selectedFrameNodes(fom: rect, lastP: lastP,
                                                                  isKnob: !sheetView.model.score.enabled,
                                                                  scale: scale * 1.5)
            } else {
                selectedFrameNodes = []
            }
            
            selectingLineNode.children = planeNodes + lineNodes + textNodes + contentNodes
            + selectedFrameNodes
            
            return true
        } else if let sheetView = rootView.sheetViewWithSelectedNote(at: p) {
            let scoreView = sheetView.scoreView
            
            func show(_ ps: [Point], r: Double) {
                let node = Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                                path: Path(ps.map { Pathline(circleRadius: r, position: $0) }),
                                fillType: .color(.selected))
                let inNode = Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                                  path: Path(ps.map { Pathline(circleRadius: r * 0.5,
                                                               position: $0) }),
                                fillType: .color(.background))
                selectingLineNode.children = [node, inNode]
            }
            
            let scoreP = scoreView.convertFromWorld(p)
            let pitchInterval = rootView.currentPitchInterval
            let beatInterval = rootView.currentBeatInterval
            let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
            let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
            
            let isPit = scoreView.hitTestPoint(scoreP, scale: rootView.screenToWorldScale / 2)?
                .result.isPit ?? false
            let nis = scoreView.selectedNotePitSprolIs
            var ps = [Point](), allNoteIs = [Int]()
            let notes = nis.sorted(by: { $0.key < $1.key }).map { v in
                let note = scoreView.model.notes[v.key]
                let pitSprolIs = v.value
                if isPit, !pitSprolIs.isEmpty && note.pits.count > 1 && pitSprolIs.count != note.pits.count {
                    var currentBeat: Rational = 0, nPits = [Pit]()
                    for (pitI, _) in pitSprolIs {
                        let pit = note.pits[pitI]
                        let dBeat = (pitI + 1 < note.pits.count ?
                                     note.pits[pitI + 1].beat : note.beatRange.length) - pit.beat
                        nPits.append(.init(beat: currentBeat, pitch: pit.pitch, stereo: pit.stereo,
                                           tone: pit.tone, lyric: pit.lyric))
                        currentBeat += dBeat
                        ps.append(scoreView.pitPosition(atPit:pitI, from: note))
                    }
                    let startBeat = note.pits[pitSprolIs.keys.min()!].beat + note.beatRange.start
                    var nNote = Note(beatRange: startBeat ..< (startBeat + currentBeat),
                                     pitch: note.pitch, pits: nPits, id: .init())
                    nNote.pitch -= pitch
                    nNote.beatRange.start -= beat
                    return nNote
                } else {
                    allNoteIs.append(v.key)
                    var nNote = note
                    nNote.pitch -= pitch
                    nNote.beatRange.start -= beat
                    return nNote
                }
            }
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: notes,
                                                                          deltaPitch: pitch,
                                                                          isSelected: true))]
            }
            
            let selectedFrameNodes: [Node]
            let scale = rootView.screenToWorldScale
            if let selectedFrame = sheetView.selectedFrame(scale: scale) {
                let rect = sheetView.convertToWorld(selectedFrame)
                let lastP: Point? = if let p = sheetView.selection.lastPosition { sheetView.convertToWorld(p) } else { nil }
                selectedFrameNodes = SheetView.selectedFrameNodes(fom: rect, lastP: lastP,
                                                                  isKnob: !sheetView.model.score.enabled,
                                                                  scale: scale * 1.5)
            } else {
                selectedFrameNodes = []
            }
            
            selectingLineNode.children = allNoteIs
                .map { Path(scoreView.pointline(at: $0).controls
                    .map { scoreView.convertToWorld($0.point) }) }
                .map {
                Node(path: $0,
                     lineWidth: 1.5 * 2,
                     lineType: .color(.selected))
            } + [Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                      path: Path(ps.map { Pathline(circleRadius: 0.25 * 8, position: $0) }),
                      fillType: .color(.selected)),
                 Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                      path: Path(ps.map { Pathline(circleRadius: 0.25 * 8 * 0.5,
                                                   position: $0) }),
                      fillType: .color(.background))] + selectedFrameNodes
            
            return true
        } else if rootView.containsLookingUp(at: p),
                  !rootView.lookingUpString.isEmpty,
                    let path = rootView.lookingUpBoundsNode?.path {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.string(rootView.lookingUpString)]
            }
            selectingLineNode.children =
            [Node(attitude: rootView.lookingUpNode.attitude, path: path,
                  lineWidth: Line.defaultLineWidth * 1.5,
                  lineType: .color(.selected),
                  fillType: .color(.subSelected))]
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let tempo = sheetView.tempo(at: sheetView.convertFromWorld(p),
                                              scale: rootView.screenToWorldScale) {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.tempo(tempo)]
            }
            
            var frames = [Rect]()
            if sheetView.animationView.model.enabled, sheetView.animationView.tempo == tempo {
                frames += sheetView.animationView.tempoFrames()
            }
            if sheetView.scoreView.model.enabled, sheetView.scoreView.tempo == tempo {
                frames += sheetView.scoreView.tempoFrames()
            }
            for textView in sheetView.textsView.elementViews {
                if textView.model.timeOption != nil, textView.tempo == tempo {
                    frames += textView.tempoFrames()
                }
            }
            for contentView in sheetView.contentsView.elementViews {
                if contentView.model.timeOption != nil, contentView.tempo == tempo {
                    frames += contentView.tempoFrames()
                }
            }
            
            selectingLineNode.children =
            [Node(path: Path(frames.map { .init(sheetView.convertToWorld($0)) }),
                  fillType: .color(.selected))]
            
            rootView.cursor = .arrowWith(string: Sheet.tempoNameFromStandardFrameRate(withTempo: tempo))
            
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let lineView = sheetView.lineTuple(at: sheetView.convertFromWorld(p),
                                                     enabledPlane: true,
                                                     scale: 1 / rootView.worldToScreenScale)?.lineView {
            let t = Transform(translation: -sheetView.convertFromWorld(p))
            let ssv = SheetValue(lines: [lineView.model],
                                 planes: [], texts: [],
                                 origin: sheetView.convertFromWorld(p),
                                 id: sheetView.id,
                                 rootKeyframeIndex: sheetView.model.animation.rootIndex,
                                 isSelected: false) * t
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
                + sheetView.animationView.interpolationNodes(from: [lineView.model.interID], scale: scale)
                + sheetView.interporatedTimelineNodes(from: [lineView.model.interID])
            } else {
                selectingLineNode.children = [selectedNode]
            }
            
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let (textView, _, si, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale) {
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
                selectingLineNode.lineWidth = 1
                selectingLineNode.path = Path(sheetView.convertToWorld(frame))
            }
            
            return true
        } else if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled,
                  let (noteI, result) = sheetView.scoreView
            .hitTestPoint(sheetView.scoreView.convertFromWorld(p), scale: rootView.screenToWorldScale / 2) {
            
            let scoreView = sheetView.scoreView
            let score = scoreView.model
            
            func show(_ ps: [Point], r: Double) {
                let node = Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                                path: Path(ps.map { Pathline(circleRadius: r, position: $0) }),
                                fillType: .color(.selected))
                let inNode = Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                                  path: Path(ps.map { Pathline(circleRadius: r * 0.5,
                                                               position: $0) }),
                                fillType: .color(.background))
                selectingLineNode.children = [node, inNode]
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
                
                rootView.cursor = .arrowWith(string: stereo.displayName)
                show(ps, r: 0.25 * 8)
            case .f0:
                let note = score.notes[noteI]
                if isSendPasteboard {
                    Pasteboard.shared.copiedObjects = [.normalizationRationalValue(note.f0Pitch)]
                }
                let x = scoreView.x(atBeat: note.beatRange.start)
                show([.init(x, scoreView.y(fromPitch: note.firstPitch) - 10),
                      .init(x, scoreView.y(fromPitch: note.f0Pitch))],
                     r: 0.25 * 8)
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
                show(ps, r: 0.25 * 8)
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
                show(ps, r: 0.125 * 2)
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
                + ps.map { Pathline(circleRadius: 0.125 * 2, position: scoreView.convertToWorld($0)) }
                let inNode = Node(attitude: .init(position: scoreView.node.convertToWorld(Point())),
                                  path: Path(ps.map { Pathline(circleRadius: 0.125 * 2 * 0.5,
                                                               position: $0) }),
                                fillType: .color(.background))
                let node = Node(path: Path(pathlines), fillType: .color(.selected))
                selectingLineNode.children = [node, inNode]
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
            case .note, .startBeat, .endBeat:
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
                    Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [note],
                                                                              deltaPitch: pitch,
                                                                              isSelected: false))]
                }
                let lines = [scoreView.pointline(from: score.notes[noteI])]
                    .map { scoreView.convertToWorld($0) }
                selectingLineNode.children = lines.map {
                    Node(path: Path($0.controls.map { $0.point }),
                         lineWidth: 1.5 * 2,
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
                    
                    let scale = rootView.screenToWorldScale
                    let keyBeat = scoreView.model.keyBeats[keyBeatI]
                    let rects = [scoreView.convertToWorld(scoreView.keyBeatRect(fromBeat: keyBeat).outsetBy(dx: 0.5, dy: 0)),
                                 scoreView.convertToWorld(scoreView.keyBeatKnobRect(fromBeat: keyBeat)).outset(by: 2 * scale)]
                    selectingLineNode.children = rects.map { .init(path: .init($0),
                                                                   fillType: .color(.selected)) }
                    return true
                case .scale(_, let pitch):
                    Pasteboard.shared.copiedObjects = [.border(.init(.horizontal))]
                    
                    let scale = rootView.screenToWorldScale
                    let rects = [scoreView.convertToWorld(scoreView.scaleRect(fromPitch: pitch)),
                                 scoreView.convertToWorld(scoreView.scaleKnobRect(fromPitch: pitch)).outset(by: 2 * scale)]
                    selectingLineNode.children = rects.map { .init(path: .init($0),
                                                                   fillType: .color(.selected)) }
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
        } else if let (mainFrame, sheetView) = rootView.mainFrame(at: p) {
            if isSendPasteboard {
                Pasteboard.shared.copiedObjects = [.rect(mainFrame)]
            }
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = Sheet.mainFrameLineWidth * 1.5
            if let sheetView {
                selectingLineNode.path = Path([Pathline(sheetView.convertToWorld(mainFrame.outset(by: 3)))])
            } else {
                selectingLineNode.path = Path([Pathline(mainFrame.outset(by: 3))])
            }
            return true
        } else if !rootView.isDefaultUUColor(at: p) {
            let colorOwners = rootView.readColorOwners(at: p)
            if let fco = colorOwners.first {
                var mainPlanePath: Path?
                if isSendPasteboard {
                    let sheetP = fco.sheetView.convertFromWorld(p)
                    if let pi = fco.sheetView.planesView.firstIndex(at: sheetP) {
                        let planeView = fco.sheetView.planesView.elementViews[pi]
                        mainPlanePath = planeView.node.path
                        
                        let sheetValue = SheetValue(planes: [planeView.model],
                                                    origin: sheetP,
                                          id: fco.sheetView.id,
                                                    rootKeyframeIndex: fco.sheetView.model.animation.rootIndex,
                                                    isSelected: false)
                        Pasteboard.shared.copiedObjects =
                            [.uuColor(rootView.uuColor(at: p)),
                             .sheetValue(sheetValue)]
                    } else {
                        Pasteboard.shared.copiedObjects =
                            [.uuColor(rootView.uuColor(at: p))]
                    }
                }
                
                let sheetP = fco.sheetView.convertFromWorld(p)
                let ids: [UUID] = if let pi = fco.sheetView.planesView.firstIndex(at: sheetP) {
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
        
        rootView.cursor = .arrowWith(string: "Empty".localized)
        return false
    }
    
    @discardableResult
    func cut(at p: Point) -> Bool {
        if rootAction.textAction.editingTextView != nil {
            rootAction.textAction.cut(at: p)
            return true
        } else if let sheetView = rootView.sheetView(at: p),
           sheetView.animationView.containsTimeline(sheetView.animationView.timelineNode.convertFromWorld(p), scale: rootView.screenToWorldScale),
                  let ki = sheetView.animationView.keyframeIndex(at: sheetView.animationView.timelineNode.convertFromWorld(p),
                                                                 scale: rootView.screenToWorldScale) {
            
            let animationView = sheetView.animationView
            let keyframeID = animationView.model.keyframes[ki].id
            
            let isSelected = animationView.selectedIs.contains(ki)
            var indexes = isSelected ?
            animationView.selectedIs.sorted() : [ki]
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
            
            sheetView.newUndoGroup(enabledKeyframeIndex: false)
            sheetView.unselect()
            if indexes == animationView.model.keyframes.count.array {
                let keyframe = Keyframe(beat: 0)
                sheetView.insert([IndexValue(value: keyframe, index: 0)])
                sheetView.removeKeyframes(at: indexes)
                
                let option = AnimationOption(enabled: false)
                sheetView.set(option)
                
                sheetView.rootKeyframeIndex = 0
            } else {
                sheetView.removeKeyframes(at: indexes)
            }
            rootView.updateSelectedFrame()
            
            Pasteboard.shared.copiedObjects
            = [.copiedAnimation(.init(animation: .init(keyframes: kfs),
                                      sheetID: sheetView.id,
                                      keyframeID: keyframeID))]
            
            return true
        } else if let sheetView = rootView.sheetViewWithSelectedSheetValue(at: p),
                    let sheetValue = sheetView.selectedSheetValue() {
            let sheetP = sheetView.convertFromWorld(p)
            let t = Transform(translation: -sheetP)
            var sheetValue = sheetValue * t
            sheetValue.origin = sheetP
            if let s = sheetValue.string {
                Pasteboard.shared.copiedObjects = [.sheetValue(sheetValue), .string(s)]
            } else {
                Pasteboard.shared.copiedObjects = [.sheetValue(sheetValue)]
            }
            
            let lineIs = sheetView.keyframeView.selectedLineIs
            let planeIs = sheetView.keyframeView.selectedPlaneIs
            let textRanges = sheetView.textsView.elementViews.enumerated().reversed()
                .map { ($0.offset, $0.element.selectedRanges) }
            let contentIs = sheetView.selectedContentIs
            
            sheetView.newUndoGroup()
            sheetView.unselect()
            
            if !lineIs.isEmpty {
                sheetView.removeLines(at: lineIs)
            }
            if !planeIs.isEmpty {
                sheetView.removePlanes(at: planeIs)
            }
            for (ti, ranges) in textRanges {
                let textView = sheetView.textsView.elementViews[ti]
                guard !ranges.isEmpty else { continue }
                
                var minI = textView.model.string.endIndex
                for range in ranges {
                    let i = range.lowerBound
                    if i < minI {
                        minI = i
                    }
                }
                let oldText = textView.model
                var text = textView.model
                for range in ranges.reversed() {
                    text.string.removeSubrange(range)
                }
                
                if text.string.isEmpty {
                    sheetView.removeText(at: ti)
                } else {
                    let os = oldText.string
                    let range = os.intRange(from: os.startIndex ..< os.endIndex)
                    
                    let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                    let origin: Point?
                    if let textFrame = text.frame, !sb.contains(textFrame) {
                        let nFrame = sb.clipped(textFrame)
                        origin = text.origin + nFrame.origin - textFrame.origin
                    } else {
                        origin = nil
                    }
                    
                    let tuv = TextValue(string: text.string,
                                        replacedRange: range,
                                        origin: origin, size: nil,
                                        widthCount: nil)
                    sheetView.replace(IndexValue(value: tuv, index: ti))
                }
            }
            if !contentIs.isEmpty {
                sheetView.removeContents(at: contentIs)
            }
            
            return true
        } else if let sheetView = rootView.sheetViewWithSelectedNote(at: p) {
            let scoreView = sheetView.scoreView
            
            let scoreP = scoreView.convertFromWorld(p)
            let pitchInterval = rootView.currentPitchInterval
            let beatInterval = rootView.currentBeatInterval
            let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
            let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
            
            let nis = scoreView.selectedNotePitSprolIs
            
            let isPit = scoreView.hitTestPoint(scoreP, scale: rootView.screenToWorldScale / 2)?
                .result.isPit ?? false
            
            var removeNoteIs = [Int](), replaceNIVs = [IndexValue<Note>]()
            let notes = nis.sorted(by: { $0.key < $1.key }).map { v in
                let noteI = v.key
                let note = scoreView.model.notes[noteI]
                let pitSprolIs = v.value
                if (isPit && !pitSprolIs.isEmpty && note.pits.count > 1 && pitSprolIs.count != note.pits.count)
                    || scoreView.containsTone(at: scoreP, at: noteI,
                                              scale: rootView.screenToWorldScale) {
                    
                    var currentBeat: Rational = 0, nPits = [Pit]()
                    for (pitI, _) in pitSprolIs {
                        let pit = note.pits[pitI]
                        let dBeat = (pitI + 1 < note.pits.count ?
                                     note.pits[pitI + 1].beat : note.beatRange.length) - pit.beat
                        nPits.append(.init(beat: currentBeat, pitch: pit.pitch, stereo: pit.stereo,
                                           tone: pit.tone, lyric: pit.lyric))
                        currentBeat += dBeat
                    }
                    let startBeat = note.pits[pitSprolIs.keys.min()!].beat + note.beatRange.start
                    var nNote = Note(beatRange: startBeat ..< (startBeat + currentBeat),
                                     pitch: note.pitch, pits: nPits, id: .init())
                    nNote.pitch -= pitch
                    nNote.beatRange.start -= beat
                    
                    var pits = note.pits
                    for (pitI, sprolIs) in pitSprolIs.sorted(by: { $0.key < $1.key }).reversed() {
                        if sprolIs.isEmpty {
                            pits.remove(at: pitI)
                        } else {
                            var pit = note.pits[pitI]
                            pit.tone.spectlope.sprols.remove(at: sprolIs.sorted())
                            pits[pitI] = pit
                        }
                    }
                    if pits.isEmpty {
                        removeNoteIs.append(noteI)
                        
                        var nNote = note
                        nNote.pitch -= pitch
                        nNote.beatRange.start -= beat
                        return nNote
                    } else {
                        let fBeat = pits[0].beat
                        for i in pits.count.range {
                            pits[i].beat -= fBeat
                        }
                        var nnNote = note
                        nnNote.beatRange = (nnNote.beatRange.start + fBeat) ..< note.beatRange.end
                        nnNote.pits = pits
                        replaceNIVs.append(.init(value: nnNote, index: noteI))
                        
                        return nNote
                    }
                } else {
                    removeNoteIs.append(noteI)
                    
                    var nNote = note
                    nNote.pitch -= pitch
                    nNote.beatRange.start -= beat
                    return nNote
                }
            }
            
            Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: notes,
                                                                      deltaPitch: pitch,
                                                                      isSelected: true))]
            
            sheetView.newUndoGroup()
            sheetView.unselect()
            
            if !replaceNIVs.isEmpty {
                sheetView.replace(replaceNIVs)
            }
            if !removeNoteIs.isEmpty {
                sheetView.removeNote(at: removeNoteIs)
            }
            
            sheetView.updatePlaying()
            
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let (lineView, li) = sheetView
                    .lineTuple(at: sheetView.convertFromWorld(p),
                               enabledPlane: true,
                               scale: 1 / rootView.worldToScreenScale) {
            
            let sheetP = sheetView.convertFromWorld(p)
            let t = Transform(translation: -sheetP)
            let ssv = SheetValue(lines: [lineView.model],
                                 planes: [], texts: [],
                                 origin: sheetP,
                                 id: sheetView.id,
                                 rootKeyframeIndex: sheetView.model.animation.rootIndex,
                                 isSelected: false) * t
            Pasteboard.shared.copiedObjects = [.sheetValue(ssv)]
            
            if sheetView.model.enabledAnimation {
                let scale = 1 / rootView.worldToScreenScale
                let nodes = sheetView.animationView.interpolationNodes(from: [lineView.model.interID], scale: scale,
                                                         removeLineIndex: li)
                if nodes.count > 1 {
                    selectingLineNode.children = nodes
                }
            }
            
            sheetView.newUndoGroup()
            sheetView.unselect()
            
            let line = lineView.model
            if rootView.isFullEdit,
               line.controls.count > 2,
               let pi = lineView.model.mainPointSequence.nearestIndex(at: sheetP),
               lineView.model.mainPoint(at: pi).distanceSquared(sheetP)
                < (lineView.model.mainPressure(at: pi) * line.size / 2).squared {
                
                var line = line
                line.controls.remove(at: pi)
                sheetView.removeLines(at: [li])
                sheetView.insert([IndexValue(value: line, index: li)])
            } else {
                sheetView.removeLines(at: [li])
            }
            return true
        } else if let sheetView = rootView.sheetView(at: p),
                  let (textView, ti, si, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale) {
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
                var text = textView.model
                let widthCount = text.widthCount == Typobute.mainWidthCount ?
                Typobute.maxWidthCount : Typobute.mainWidthCount
                
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
                    sheetView.unselect()
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
            sheetView.unselect()
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
            sheetView.unselect()
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
                sheetView.unselect()
                sheetView.replace(IndexValue(value: content, index: ci))
                return true
            } else {
                var content = sheetView.contentsView.elementViews[ci].model
                content.origin -= sheetView.convertFromWorld(p)
                
                Pasteboard.shared.copiedObjects = [.content(content)]
                
                sheetView.newUndoGroup()
                sheetView.unselect()
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
                let scoreP = scoreView.convertFromWorld(p)
                let note = scoreView.model.notes[noteI]
                let pitchInterval = rootView.currentPitchInterval
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                let beatInterval = rootView.currentBeatInterval
                let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
                if note.pits.count > 1 {
                    var currentBeat: Rational = 0, nPits = [Pit]()
                    let pit = note.pits[pitI]
                    let dBeat = (pitI + 1 < note.pits.count ?
                                 note.pits[pitI + 1].beat : note.beatRange.length) - pit.beat
                    nPits.append(.init(beat: currentBeat, pitch: pit.pitch, stereo: pit.stereo,
                                       tone: pit.tone, lyric: pit.lyric))
                    if dBeat > 0 {
                        currentBeat += dBeat
                    }
                    let startBeat = note.pits[pitI].beat + note.beatRange.start
                    var nNote = Note(beatRange: startBeat ..< (startBeat + currentBeat),
                                     pitch: note.pitch, pits: nPits, id: .init())
                    nNote.pitch -= pitch
                    nNote.beatRange.start -= beat
                    
                    Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [nNote],
                                                                              deltaPitch: pitch,
                                                                              isSelected: false))]
                    
                    var pits = note.pits
                    pits.remove(at: pitI)
                    let fBeat = pits[0].beat
                    for i in pits.count.range {
                        pits[i].beat -= fBeat
                    }
                    var nnNote = note
                    nnNote.beatRange = (nnNote.beatRange.start + fBeat) ..< note.beatRange.end
                    nnNote.pits = pits
                    
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    sheetView.replace(nnNote, at: noteI)
                } else {
                    var note = score.notes[noteI]
                    note.pitch -= pitch
                    note.beatRange.start -= beat
                    
                    Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [note],
                                                                              deltaPitch: pitch,
                                                                              isSelected: false))]
                    
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    sheetView.removeNote(at: noteI)
                }
                
                sheetView.updatePlaying()
                
                return true
                
            case .f0:
                var note = score.notes[noteI]
                Pasteboard.shared.copiedObjects = [.normalizationRationalValue(note.f0Pitch)]
                
                if note.f0Pitch != Note.defaultF0Pitch {
                    note.f0Pitch = Note.defaultF0Pitch
                    
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    sheetView.replace(note, at: noteI)
                    
                    sheetView.updatePlaying()
                }
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
                    sheetView.unselect()
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
                sheetView.unselect()
                sheetView.replace(nivs)
                return true
            case .allSprol:
                break
            case .spectlopeHeight:
                var note = score.notes[noteI]
                if note.spectlopeHeight != Sheet.spectlopeHeight {
                    note.spectlopeHeight = Sheet.spectlopeHeight
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    sheetView.replace([IndexValue<Note>(value: note, index: noteI)])
                    Pasteboard.shared.copiedObjects = [.normalizationValue(note.spectlopeHeight)]
                    return true
                }
            case .note, .startBeat, .endBeat:
                let scoreP = scoreView.convertFromWorld(p)
                
                let pitchInterval = rootView.currentPitchInterval
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                let beatInterval = rootView.currentBeatInterval
                let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
                var note = score.notes[noteI]
                note.pitch -= pitch
                note.beatRange.start -= beat
                
                Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: [note],
                                                                          deltaPitch: pitch,
                                                                          isSelected: false))]
                
                sheetView.newUndoGroup()
                sheetView.unselect()
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
                    sheetView.unselect()
                    sheetView.set(option)
                    return true
                case .scale(let scaleI, _):
                    var option = sheetView.model.score.option
                    option.scales.remove(at: scaleI)
                    
                    Pasteboard.shared.copiedObjects = [.border(.init(.horizontal))]
                    
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    sheetView.set(option)
                    return true
                }
            } else if sheetView.scoreView.model.notes.isEmpty {
                let option = ScoreOption(enabled: false)
                sheetView.newUndoGroup()
                sheetView.unselect()
                sheetView.set(option)
                return true
            }
        } else if let (mainFrame, sheetView) = rootView.mainFrame(at: p), let sheetView {
            Pasteboard.shared.copiedObjects = [.rect(mainFrame)]
            
            if mainFrame != Sheet.defaultBounds {
                selectingLineNode.path = Path([Pathline(sheetView.convertToWorld(mainFrame))])
                
                sheetView.newUndoGroup()
                sheetView.unselect()
                sheetView.set(SheetOption(mainFrame: Sheet.defaultBounds))
            }
            return true
        } else if let (border, i, sheetView, edge) = rootView.border(at: p) {
            Pasteboard.shared.copiedObjects = [.border(border)]
            
            selectingLineNode.path = Path([Pathline([edge.p0, edge.p1])])
            
            sheetView.newUndoGroup()
            sheetView.unselect()
            sheetView.removeBorder(at: i)
            return true
         } else if !rootView.isDefaultUUColor(at: p) {
            let colorOwners = rootView.colorOwners(at: p, enabledAlwaysAnimation: true)
            if !colorOwners.isEmpty {
                Pasteboard.shared.copiedObjects = [.uuColor(rootView.uuColor(at: p))]
                var nug = Set<SheetView>()
                colorOwners.forEach {
                    if $0.colorValue.isBackground {
                        $0.uuColor = Sheet.defalutBackgroundUUColor
                        if !nug.contains($0.sheetView) {
                            $0.sheetView.newUndoGroup()
                            $0.sheetView.unselect()
                        }
                        $0.captureUUColor()
                        nug.insert($0.sheetView)
                    } else if !$0.colorValue.planeIndexes.isEmpty {
                        $0.uuColor = .init(.empty, id: .two)
                        if !nug.contains($0.sheetView) {
                            $0.sheetView.newUndoGroup()
                            $0.sheetView.unselect()
                        }
                        $0.captureUUColor()
                        nug.insert($0.sheetView)
                    } else if !$0.colorValue.planeAnimationIndexes.isEmpty {
                        let ki = $0.sheetView.model.animation.index
                        for v in $0.colorValue.planeAnimationIndexes {
                            if ki == v.index {
                                if !v.value.isEmpty {
                                    $0.uuColor = .init(.empty, id: .two)
                                    if !nug.contains($0.sheetView) {
                                        $0.sheetView.newUndoGroup()
                                        $0.sheetView.unselect()
                                    }
                                    $0.captureUUColor()
                                    nug.insert($0.sheetView)
                                }
                                break
                            }
                        }
                    }
                }
                return true
            }
        }
        
        if let sheetView = rootView.sheetView(at: p) {
            var isNewUndoGroup = true
            sheetView.unselect(isNewUndoGroup: &isNewUndoGroup)
        }
        rootView.cursor = .arrowWith(string: "Empty".localized)
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
                oldSnapP: Point?, oldFillSnapP: Point?,
                beganPitch = Rational(0), beganBeat = Rational(0),
                octaveNode: Node?, beganNotes = [Int: Note](), beganSheetView: SheetView?,
                textNode: Node?, imageNode: Node?, textFrame: Rect?, textScale = 1.0,
                filledSheetViews = [UUID: SheetView](), beganTime = 0.0
    let enableUUColorTime = 0.3
    var snapDistance = 4.0
    private var notePlayer: NotePlayer?, playerBeatNoteIndexes = [Int](),
                oldPitch: Rational?, oldBeat: Rational?
    
    func updateWithPaste(at p: Point, atScreen sp: Point, _ phase: Phase, _ event: (any Event)?) {
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
                
                let contentNodes: [Node] = value.contents.compactMap { content in
                    guard let image = content.image,
                          let texture = try? Texture(image: image,
                                                     isOpaque: false, .sRGB) else { return nil }
                    let imageFrame = content.imageFrame
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
                    
                    return Node(name: "content", path: Path(rect), fillType: .texture(texture))
                }
                
                let keyframesNodes = value.keyframes.isEmpty ?
                    [] :
                    [Text(string: "\(value.keyframeBeganIndex)", origin: Point(-10, 0)).node,
                     Text(string: "\(value.keyframes.count - value.keyframeBeganIndex)", origin: Point(10, 0)).node]
                let node0 = Node(children: planeNodes + lineNodes + keyframesNodes)
                let node1 = Node(children: textNodes)
                let node2 = Node(children: contentNodes)
                let snapNode = Node(lineWidth: 1, lineType: .color(.background),
                                    fillType: .color(.border))
                selectingLineNode.children = [node0, node1, node2, snapNode]
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
            
            if selectingLineNode.children.count == 4 {
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
                
                selectingLineNode.children[2].attitude = Attitude(position: np,
                                                                  scale: Size(square: 1.0 * scale))
                
                if nSnapP != oldSnapP {
                    if let nSnapP {
                        selectingLineNode.children[3].path = Path(circleRadius: isSnapped ? 6 : 4)
                        selectingLineNode.children[3].attitude = Attitude(position: nSnapP, scale: Size(square: rootView.screenToWorldScale))
                    } else {
                        selectingLineNode.children[3].path = Path()
                    }
                }
                
                oldSnapP = nSnapP
            }
        }
        func updateWithText(_ text: Text) {
            let sheetP = p - sheetFrame.origin
            var isAppend = false
            
            var textView: SheetTextView?, sri: String.Index?
            if let aTextView = rootAction.textAction.editingTextView,
               !aTextView.isHiddenSelectedRange {
                
                if let asri = aTextView.selectedRange?.lowerBound {
                    textView = aTextView
                    sri = asri
                }
            } else if let (aTextView, _, _, asri) = sheetView?.textTuple(at: sheetP, scale: rootView.screenToWorldScale) {
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
               let (textView, _, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale),
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
                let scoreView = sheetView.scoreView
                let scoreP = scoreView.convertFromWorld(p)
                switch oldBorder.orientation {
                case .horizontal:
                    let pitch = scoreView.pitch(atY: scoreP.y,
                                                interval: rootView.currentPitchInterval)
                    rootView.cursor = .arrowWith(string: Pitch(value: pitch).displayString())
                    
                    snapLineNode.children = []
                    
                    let rects = scoreView.scaleRects(fromUnison: pitch.mod(12)).map { scoreView.convertToWorld($0) }
                    let knobRect = scoreView.convertToWorld(scoreView.scaleKnobRect(fromPitch: pitch))
                    selectingLineNode.children = [.init(path: .init(rects.map { .init($0) }),
                                                        fillType: .color(.subBorder)),
                                                  .init(path: .init(knobRect),
                                                        fillType: .color(.content))]
                case .vertical:
                    let keyBeat = scoreView.beat(atX: scoreP.x,
                                                 interval: rootView.currentBeatInterval)
                    isSnapped = keyBeat.isInteger
                    if !snapLineNode.children.isEmpty {
                        rootView.cursor = .arrow
                    }
                    snapLineNode.children = []
                    
                    let rect = scoreView.convertToWorld(scoreView.keyBeatRect(fromBeat: keyBeat))
                    let knobRect = scoreView.convertToWorld(scoreView.keyBeatKnobRect(fromBeat: keyBeat))
                    selectingLineNode.children = [.init(path: .init(rect),
                                                        fillType: .color(.subBorder)),
                                                  .init(path: .init(knobRect),
                                                        fillType: .color(.content))]
                }
                
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
            
            let sheetP = p - sheetFrame.origin
            let bnp = Sheet.borderSnappedPoint(sheetP, with: sheetFrame,
                                               distance: 3 / rootView.worldToScreenScale,
                                               oldBorder: oldBorder)
            isSnapped = bnp.isSnapped
            let np = bnp.point + sheetFrame.origin
            let cp = sheetFrame.bounds.centerPoint
            let (nx, ny) = switch oldBorder.orientation {
            case .horizontal:
                (sheetFrame.width / 2, np.y - sheetFrame.minY - cp.y)
            case .vertical:
                (np.x - sheetFrame.minX - cp.x, sheetFrame.height / 2)
            }
            let mainFrame = Rect(cp,
                                 dx: abs(nx).rounded().clipped(min: 1, max: sheetFrame.width / 2),
                                 dy: abs(ny).rounded().clipped(min: 1, max: sheetFrame.height / 2))
            selectingLineNode.children = SheetView.mainFrameNodes(fromMainFrame: mainFrame + sheetFrame.origin)
            
            let width = mainFrame.width, height = mainFrame.height
            rootView.cursor = rootView.cursor(from: "\(LookUpAction.sizeString(from: .init(width: width, height: height)))", isArrow: true)
        }
        func updateIDs(_ ids: [InterOption]) {
            guard let sheetView else { return }
            let lis: [Int] = if sheetView.containsSelectedLine(sheetView.convertFromWorld(p),
                                                        scale: rootView.screenToWorldScale) {
                sheetView.keyframeView.selectedLineIs
            } else if let li = sheetView.lineTuple(at: sheetView.convertFromWorld(p),
                                                   scale: rootView.screenToWorldScale)?.lineIndex {
                [li]
            } else {
                []
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
        func updateNotes(_ notes: [Note], deltaPitch: Rational, isSelected: Bool) {
            if phase == .began {
                beganSheetView = rootView.madeSheetView(at: shp)
            }
            guard let sheetView = beganSheetView else { return }
            let scoreView = sheetView.scoreView
            let scoreP = scoreView.convertFromWorld(p)
            let pitchInterval = rootView.currentPitchInterval
            let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
            - Score.pitchRange.start
            let beatInterval = rootView.currentBeatInterval
            let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
            
            if phase == .began {
                beganPitch = pitch
                beganBeat = beat
                
                sheetView.newUndoGroup()
                sheetView.unselect()
                if !sheetView.scoreView.model.enabled {
                    var option = sheetView.scoreView.option
                    option.enabled = true
                    sheetView.set(option)
                }
                
                let count = scoreView.model.notes.count
                beganNotes = notes.enumerated().reduce(into: .init()) {
                    var note = $1.element
                    note.pitch += pitch
                    note.beatRange.start += beat
                    note.id = .init()
                    $0[count + $1.offset] = note
                }
                
                let notes = beganNotes.sorted(by: { $0.key < $1.key }).map { $0.value }
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
                let minBeat = minBV?.value.beatRange.start ?? 0
                let maxBeat = maxBV?.value.beatRange.end ?? 0
                let noteI = !beganNotes.contains(where: { 0 >= $0.value.beatRange.start }) ?
                minBV?.key :
                (!beganNotes.contains(where: { 0 < $0.value.beatRange.end }) ? maxBV?.key : nil)
                let vs = scoreView.model.noteIAndNormarizedPits(atBeat: beat.clipped(min: minBeat, max: maxBeat), selectedNoteI: noteI,
                                                                in: Set(beganNotes.keys).sorted())
                playerBeatNoteIndexes = vs.map { $0.noteI }
                
                updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
            } else if pitch != oldPitch || beat != oldBeat {
                var notes = beganNotes.sorted(by: { $0.key < $1.key }).map { $0.value }
                for j in 0 ..< notes.count {
                    notes[j].pitch += pitch - beganPitch
                    notes[j].beatRange.start += beat - beganBeat
                    notes[j].id = .init()
                }
                scoreView.replace(notes.enumerated().map { .init(value: $0.element, index: $0.offset + scoreView.model.notes.count - notes.count) })
                rootView.updateOtherAround(from: sheetView, isUpdateAlways: true)
                
                octaveNode?.children = scoreView.octaveNode(noteIs: Array(scoreView.model.notes.count - notes.count ..< scoreView.model.notes.count)).children
                
                if pitch != oldPitch {
                    notePlayer?.notes = playerBeatNoteIndexes.map {
                        scoreView.rendableNormarizedPitResult(atBeat: beat, at: $0)
                    }
                }
            }
            
            oldPitch = pitch
            oldBeat = beat
            
//            selectingLineNode.children = notes.map {
//                let node = scoreView.noteNode(from: $0).node
//                node.attitude = Attitude(position: sheetView.convertToWorld(Point()))
//                return node
//            }
            
            rootView.cursor = .circle(string: Pitch(value: pitch)
                .displayString(deltaPitch: pitch - deltaPitch))
        }
        
        switch pasteObject {
        case .copiedSheetsValue: break
        case .picture:
            break
        case .sheetValue(let value):
            if value.texts.count == 1
                && value.lines.isEmpty && value.planes.isEmpty && value.contents.isEmpty {
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
        case .uuColor(let uuColor):
            guard phase == .began || (event == nil ? false : (event!.time - beganTime > enableUUColorTime)) else { return }
            if let sheetView = rootView.sheetView(at: p),
               sheetView.selectedFrame(scale: rootView.screenToWorldScale)?
                .contains(sheetView.convertFromWorld(p)) ?? false,
               sheetView.containsSelectedLineOrPlane(sheetView.convertFromWorld(p),
                                                     scale: rootView.screenToWorldScale),
                let (_, owners) = rootView.madeColorOwnersWithSelection(at: p,
                                                                              enabledLinePlane: false,
                                                                              removingUUColor: uuColor) {
                let ownerDic = owners.reduce(into: [SheetView: [SheetColorOwner]]()) {
                    if $0[$1.sheetView] == nil {
                        $0[$1.sheetView] = [$1]
                    } else {
                        $0[$1.sheetView]?.append($1)
                    }
                }
                for (_, owners) in ownerDic {
                    owners.forEach {
                        if $0.uuColor != uuColor {
                            let oldUUColor = $0.uuColor
                            $0.uuColor = uuColor
                            $0.captureUUColor(isNewUndoGroup: filledSheetViews[$0.sheetView.id] == nil)
                            $0.moveLine(with: uuColor, old: oldUUColor)
                            filledSheetViews[$0.sheetView.id] = $0.sheetView
                        }
                    }
                }
            } else if let _ = rootView.madeSheetView(at: shp) {
                let colorOwners = rootView.madeColorOwner(at: p, enabledLine: false,
                                                          enabledAlwaysAnimation: true,
                                                          removingUUColor: uuColor)
                colorOwners.forEach {
                    if $0.uuColor != uuColor {
                        let oldUUColor = $0.uuColor
                        $0.uuColor = uuColor
                        $0.captureUUColor(isNewUndoGroup: filledSheetViews[$0.sheetView.id] == nil)
                        $0.moveLine(with: uuColor, old: oldUUColor)
                        filledSheetViews[$0.sheetView.id] = $0.sheetView
                    }
                }
            }
            
            break
        case .copiedAnimation:
            break
        case .ids(let ids):
            updateIDs(ids.ids)
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
            updateNotes(notesValue.notes, deltaPitch: notesValue.deltaPitch,
                        isSelected: notesValue.isSelected)
        case .stereo:
            break
        case .tone:
            break
        case .rect:
            break
        case .tempo:
            break
        }
    }
    
    func paste(at p: Point, atScreen sp: Point, event: (any Event)?) {
        let shp = rootView.sheetPosition(at: p)
        
        var isRootNewUndoGroup = true
        var updatedNewUndoGroupDic = [SheetView: SheetSelection]()
        func updateUndoGroup(with sheetView: SheetView) {
            if updatedNewUndoGroupDic[sheetView] == nil {
                sheetView.newUndoGroup()
                sheetView.unselect()
                updatedNewUndoGroupDic[sheetView] = .init()
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
        
        func pasteLines(_ lines: [Line], isSelected: Bool, at p: Point) {
            let p = rootView.roundedPoint(from: p)
            let pt = firstTransform(at: p)
            let pLines: [Line] = lines.map { $0 * pt }
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
                        let oLines: [Line] = lines.map { $0 * t }
                        var nLines = Sheet.clipped(oLines, in: Rect(size: frame.size))
                        if !nLines.isEmpty,
                           let (sheetView, isNew) = rootView
                            .madeSheetViewIsNew(at: nshp, isNewUndoGroup: isRootNewUndoGroup) {
                            
                            let idSet = Set(sheetView.model.picture.lines.map { $0.interID })
                            for (i, l) in nLines.enumerated() {
                                if idSet.contains(l.interID) {
                                    nLines[i].interID = UUID()
                                }
                            }
                            if isNew {
                                isRootNewUndoGroup = false
                            }
                            updateUndoGroup(with: sheetView)
                            sheetView.append(nLines)
                            if isSelected {
                                let ki = sheetView.model.animation.index
                                let li = sheetView.model.picture.lines.count - nLines.count
                                if updatedNewUndoGroupDic[sheetView]?.keyframeSelections[ki] != nil {
                                    updatedNewUndoGroupDic[sheetView]?.keyframeSelections[ki]?.lineIs
                                        .formUnion(li ..< li + nLines.count)
                                } else {
                                    updatedNewUndoGroupDic[sheetView]?.keyframeSelections[ki]
                                    = .init(lineIs: Set(li ..< li + nLines.count))
                                }
                            }
                        }
                    }
                }
            }
        }
        func pastePlanes(_ planes: [Plane], isSelected: Bool, at p: Point) {
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
                            updateUndoGroup(with: sheetView)
                            sheetView.append(nPlanes)
                            if isSelected {
                                let ki = sheetView.model.animation.index
                                let pi = sheetView.model.picture.planes.count - nPlanes.count
                                if updatedNewUndoGroupDic[sheetView]?.keyframeSelections[ki] != nil {
                                    updatedNewUndoGroupDic[sheetView]?.keyframeSelections[ki]?.planeIs
                                        .formUnion(pi ..< pi + nPlanes.count)
                                } else {
                                    updatedNewUndoGroupDic[sheetView]?.keyframeSelections[ki]
                                    = .init(planeIs: Set(pi ..< pi + nPlanes.count))
                                }
                            }
                        }
                    }
                }
            }
        }
        func pasteTexts(_ texts: [Text], isSelected: Bool, at p: Point) {
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
                    updateUndoGroup(with: sheetView)
                    sheetView.append([nText])
                    if isSelected {
                        updatedNewUndoGroupDic[sheetView]?
                            .textSelections[sheetView.model.texts.count - 1] =
                        text.string.isEmpty ? nil : .init(ranges: [text.string.allIntRange])
                    }
                }
            }
        }
        func pasteText(_ text: Text, isSelected: Bool) {
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
                
                rootAction.textAction.endInputKey(isUnmarkText: true, isRemoveText: false)
                if rootView.findingNode(at: p) != nil,
                    rootView.finding.string != text.string {
                    
                    rootView.replaceFinding(from: text.string)
                } else {
                    let rRange: Range<Int>?
                    if let sRange = textView.selectedRange(at: textView.convertFromWorld(p)) {
                        rRange = textView.model.string.intRange(from: sRange)
                    } else if let ati = textView.selectedRange?.lowerBound {
                        let ti = textView.model.string.intIndex(from: ati)
                        rRange = ti ..< ti
                    } else {
                        rRange = nil
                    }
                    if let rRange {
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
                        updateUndoGroup(with: sheetView)
                        sheetView.replace(IndexValue(value: tv, index: i))
                    }
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
                            updateUndoGroup(with: sheetView)
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
                
                updateUndoGroup(with: sheetView)
                sheetView.append(text)
                if isSelected {
                    updatedNewUndoGroupDic[sheetView]?
                        .textSelections[sheetView.model.texts.count - 1] =
                    text.string.isEmpty ? nil : .init(ranges: [text.string.allIntRange])
                }
            }
        }
        func pasteContents(_ contents: [Content], isSelected: Bool, at p: Point) {
            let p = rootView.roundedPoint(from: p)
            let pt = firstTransform(at: p)
            guard !contents.isEmpty else { return }
            
            for content in contents {
                let nshp = rootView.sheetPosition(at: (content * pt).origin)
                guard ((shp.x - 1) ... (shp.x + 1)).contains(nshp.x)
                    && ((shp.y - 1) ... (shp.y + 1)).contains(nshp.y) else {
                    
                    continue
                }
                let frame = rootView.sheetFrame(with: nshp)
                let t = transform(in: frame, at: p)
                var content = content * t
                if let (sheetView, isNew) = rootView
                    .madeSheetViewIsNew(at: nshp, isNewUndoGroup: isRootNewUndoGroup) {
                    
                    if !sheetView.contentsView.model.contains(where: { $0.isEqualFile(content) }) {
                        if let directory = rootView.model.sheetRecorders[sheetView.id]?.contentsDirectory {
                            directory.isWillwrite = true
                            try? directory.write()
                            try? directory.copy(name: content.name, from: content.url)
                        }
                    }
                    
                    content.directoryName = sheetView.id.uuidString
                    
                    let maxSize = Size(width: 100000, height: 100000)
                    if content.size.width > maxSize.width || content.size.height > maxSize.height {
                        content.size *= min(maxSize.width / content.size.width, maxSize.height / content.size.height)
                    }
                    
                    content.id = .init()
                    
                    if isNew {
                        isRootNewUndoGroup = false
                    }
                    updateUndoGroup(with: sheetView)
                    sheetView.append(content)
                    if isSelected {
                        updatedNewUndoGroupDic[sheetView]?.contentIs.insert(sheetView.model.contents.count - 1)
                    }
                }
            }
        }
        func pasteContent(_ content: Content) {
            var content = content
            
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
            
            
            updateUndoGroup(with: sheetView)
            sheetView.append(content)
        }
        
        switch pasteObject {
        case .copiedSheetsValue: break
        case .picture(let picture):
            if let sheetView = rootView.madeSheetView(at: shp) {
                sheetView.newUndoGroup()
                sheetView.append(picture.lines)
                sheetView.append(picture.planes)
            }
        case .sheetValue(let value):
            let sheetView = rootView.sheetView(at: shp)
            let np: Point
            if !(sheetView?.id == value.id && sheetView?.rootKeyframeIndex == value.rootKeyframeIndex) {
                let snapP = value.origin + rootView.sheetFrame(with: shp).origin
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
            } else {
                np = rootView.roundedPoint(from: p)
            }
            
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
                        let pLines: [Line] = oldLines.map { $0 * pt }
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
                        
                        let idSet = Set(oldLines.map { $0.interID })
                        for (i, l) in nLines.enumerated() {
                            if idSet.contains(l.interID) {
                                nLines[i].interID = UUID()
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
                if value.texts.count == 1
                    && value.lines.isEmpty && value.planes.isEmpty && value.contents.isEmpty {
                    pasteText(value.texts[0], isSelected: value.isSelected)
                } else {
                    pasteLines(value.lines, isSelected: value.isSelected, at: np)
                    pastePlanes(value.planes, isSelected: value.isSelected, at: np)
                    pasteTexts(value.texts, isSelected: value.isSelected, at: np)
                    pasteContents(value.contents, isSelected: value.isSelected, at: np)
                }
                if value.isSelected {
                    for (sheetView, selection) in updatedNewUndoGroupDic {
                        if selection != sheetView.model.selection {
                            sheetView.doSet(selection)
                        }
                    }
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
                           locale: TextInputContext.currentLocale), isSelected: false)
        case .text(let text):
            pasteText(text, isSelected: false)
        case .border(let border):
            if let sheetView = rootView.sheetView(at: shp),
               let (textView, ti, _, _) = sheetView.textTuple(at: sheetView.convertFromWorld(p), scale: rootView.screenToWorldScale),
               let x = textView.typesetter.warpCursorOffset(at: textView.convertFromWorld(p))?.offset {
                let widthCount = textView.model.size == 0 ?
                    Typobute.mainWidthCount :
                    (x / textView.model.size)
                    .clipped(min: Typobute.minWidthCount,
                             max: Typobute.mainWidthCount)
                
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
                let sheetFrame = rootView.sheetFrame(with: shp)
                let sheetP = p - sheetFrame.origin
                let bnp = Sheet.borderSnappedPoint(sheetP, with: sheetFrame,
                                                   distance: 3 / rootView.worldToScreenScale,
                                                   oldBorder: border)
                let np = bnp.point + sheetFrame.origin
                let cp = sheetFrame.bounds.centerPoint
                let (nx, ny) = switch border.orientation {
                case .horizontal:
                    (sheetFrame.width / 2, np.y - sheetFrame.minY - cp.y)
                case .vertical:
                    (np.x - sheetFrame.minX - cp.x, sheetFrame.height / 2)
                }
                let mainFrame = Rect(cp,
                                     dx: abs(nx).rounded().clipped(min: 1, max: sheetFrame.width / 2),
                                     dy: abs(ny).rounded().clipped(min: 1, max: sheetFrame.height / 2))
                var option = sheetView.model.option
                if option.mainFrame != mainFrame {
                    option.mainFrame = mainFrame
                    sheetView.newUndoGroup()
                    sheetView.set(option)
                }
            }
        case .uuColor(let uuColor):
            guard event == nil ? false : (event!.time - beganTime > enableUUColorTime) else { return }
            if let sheetView = rootView.sheetView(at: p),
               sheetView.containsSelectedLine(sheetView.convertFromWorld(p),
                                              scale: rootView.screenToWorldScale)
                || sheetView.containsSelectedPlane(sheetView.convertFromWorld(p)),
                let (_, owners) = rootView.madeColorOwnersWithSelection(at: p,
                                                                              enabledLinePlane: false,
                                                                              removingUUColor: uuColor) {
                let ownerDic = owners.reduce(into: [SheetView: [SheetColorOwner]]()) {
                    if $0[$1.sheetView] == nil {
                        $0[$1.sheetView] = [$1]
                    } else {
                        $0[$1.sheetView]?.append($1)
                    }
                }
                for (_, owners) in ownerDic {
                    owners.forEach {
                        if $0.uuColor != uuColor {
                            let oldUUColor = $0.uuColor
                            
                            $0.uuColor = uuColor
                            $0.captureUUColor(isNewUndoGroup: filledSheetViews[$0.sheetView.id] == nil)
                            
                            $0.moveLine(with: uuColor, old: oldUUColor)
                            filledSheetViews[$0.sheetView.id] = $0.sheetView
                        }
                    }
                }
                rootView.updateSelectedFrame()
            } else if let _ = rootView.madeSheetView(at: shp) {
                let colorOwners = rootView.madeColorOwner(at: p, enabledLine: false,
                                                          removingUUColor: uuColor)
                colorOwners.forEach {
                    if $0.uuColor != uuColor {
                        let oldUUColor = $0.uuColor
                        
                        $0.uuColor = uuColor
                        
                        $0.captureUUColor(isNewUndoGroup: filledSheetViews[$0.sheetView.id] == nil)
                        $0.moveLine(with: uuColor, old: oldUUColor)
                        filledSheetViews[$0.sheetView.id] = $0.sheetView
                    }
                }
                rootView.updateSelectedFrame()
            }
            
        case .copiedAnimation(let copiedAnimation):
            guard !copiedAnimation.animation.keyframes.isEmpty,
                  let sheetView = rootView.sheetView(at: shp) else { return }
            let beat: Rational = sheetView.animationView.beat(atX: sheetView.convertFromWorld(p).x)
            var ni = 0
            for (i, kf) in sheetView.model.animation.keyframes.enumerated().reversed() {
                if kf.beat + sheetView.model.animation.beatRange.start <= beat {
                    ni = i + 1
                    break
                }
            }
            
            let currentIndex = sheetView.model.animation.index(atRoot: sheetView.rootKeyframeIndex)
            let count = (sheetView.rootKeyframeIndex - currentIndex) / sheetView.model.animation.keyframes.count
            let nextBeat = ni < sheetView.model.animation.keyframes.count ? sheetView.model.animation.keyframes[ni].beat : sheetView.model.animation.beatRange.length
            var ki = ni
            let kivs: [IndexValue<Keyframe>] = copiedAnimation.animation.keyframes.compactMap {
                var keyframe = $0
                keyframe.beat += beat - sheetView.model.animation.beatRange.start
                if keyframe.beat >= nextBeat {
                    return nil
                }
                keyframe.id = .init()
                let v = IndexValue(value: keyframe, index: ki)
                ki += 1
                return v
            }
            
            sheetView.newUndoGroup()
            sheetView.insert(kivs)
            sheetView.rootKeyframeIndex = sheetView.model.animation.keyframes.count * count + ni
            let selection = SheetSelection(keyframeSelections: kivs.reduce(into: .init()) { $0[$1.index] = .init() })
            if selection != sheetView.model.selection {
                sheetView.doSet(selection)
            }
            rootAction.updateActionNode()
            rootView.updateSelectedFrame()
        case .ids(let idv):
            let ids = idv.ids
            guard let sheetView = rootView.sheetView(at: shp) else { return }
            let lis: [Int] = if sheetView.containsSelectedLine(sheetView.convertFromWorld(p),
                                                               scale: rootView.screenToWorldScale) {
                sheetView.keyframeView.selectedLineIs
            } else if let li = sheetView.lineTuple(at: sheetView.convertFromWorld(p),
                                                   scale: rootView.screenToWorldScale)?.lineIndex {
                [li]
            } else {
                []
            }
            let maxCount = min(ids.count, lis.count)
            if maxCount > 0 {
                let idivs = (0 ..< maxCount).map { IndexValue(value: ids[$0],
                                                              index: lis[$0]) }
                sheetView.newUndoGroup()
                sheetView.set([IndexValue(value: idivs, index: sheetView.animationView.model.index)])
            }
        case .content(let content):
            pasteContent(content)
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
        case .normalizationRationalValue(let v):
            guard let sheetView = rootView.sheetView(at: shp) else { return }
            if sheetView.model.score.enabled {
                let scoreView = sheetView.scoreView
                if let (noteI, result) = scoreView
                    .hitTestPoint(scoreView.convertFromWorld(p),
                                  scale: rootView.screenToWorldScale) {
                    switch result {
                    case .f0:
                        let f0Pitch = v.clipped(Score.pitchRange)
                        
                        var note = scoreView.model.notes[noteI]
                        if f0Pitch != note.f0Pitch {
                            note.f0Pitch = f0Pitch
                            
                            sheetView.newUndoGroup()
                            sheetView.replace(note, at: noteI)
                            
                            sheetView.updatePlaying()
                        }
                        
                    default: break
                    }
                }
            }
        case .notesValue(let v):
            octaveNode?.removeFromParent()
            octaveNode = nil
            
            notePlayer?.stop()
            
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
            if v.isSelected {
                sheetView.doSet(SheetSelection(noteSelections: noteIVs.map { $0.index }
                    .reduce(into: .init()) { $0[$1] = .init(pitSelections: [0: .init()]) }))
            }
        case .stereo(let stereo):
            guard let sheetView = rootView.sheetView(at: shp) else { return }
            if sheetView.model.score.enabled {
                let scoreView = sheetView.scoreView
                if let (noteI, pitI) = scoreView.noteAndPitIEnabledNote(at: scoreView.convertFromWorld(p),
                                                                        scale: rootView.screenToWorldScale) {
                    if sheetView.containsSelectedNote(sheetView.convertFromWorld(p),
                                                      scale: rootView.screenToWorldScale) {
                        let score = scoreView.model
                        let nis = scoreView.selectedNotePitIs
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
                        let oID = note.pits[pitI].stereo.id
                        if scoreView.model.notes.enumerated().contains(where: { i, nNote in
                            nNote.pits.enumerated().contains(where: {
                                !(i == noteI && $0.offset == pitI) ?
                                $0.element.stereo.id == oID : false
                            })
                        }) {
                            
                            let score = scoreView.model
                            let nis = score.notes.enumerated().reduce(into: [Int: [Int]]()) { n, v in
                                let pitIs = v.element.pits.count.range
                                    .filter { v.element.pits[$0].stereo.id == oID }
                                if !pitIs.isEmpty {
                                    n[v.offset] = pitIs
                                }
                            }
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
                        } else if note.pits[pitI].stereo != stereo {
                            note.pits[pitI].stereo = stereo
                            
                            if scoreView.isStraightWithSelection(atPit: pitI, atNote: noteI),
                               pitI + 1 < note.pits.count,
                                note.pits[pitI + 1].stereo != stereo {
                                
                                note.pits[pitI + 1].stereo = stereo
                            }
                            
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
                if sheetView.containsSelectedNote(sheetView.convertFromWorld(p),
                                                  scale: rootView.screenToWorldScale) {
                    let score = scoreView.model
                    let nis = scoreView.selectedNotePitIs
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
                        sheetView.unselect()
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
                        
                        if note.pits.count == 1 {
                            note.pits[0].tone = tone
                        } else {
                            let beat: Rational = scoreView.beat(atX: scoreView.convertFromWorld(p).x)
                            let oldTone = scoreView.pitResult(atBeat: beat, at: noteI).tone
                            let dSpectlope = tone.spectlope / oldTone.spectlope
                            
                            for (pitI, _) in note.pits.enumerated() {
                                note.pits[pitI].tone.spectlope *= dSpectlope
                                note.pits[pitI].tone.spectlope.clip()
                            }
                        }
                        
                        if note != oldNote {
                            sheetView.newUndoGroup()
                            sheetView.unselect()
                            sheetView.replace(note, at: noteI)
                            
                            sheetView.updatePlaying()
                        }
                    case .pit(let pitI), .sprol(let pitI, _, _):
                        var note = scoreView.model.notes[noteI]
                        let oID = note.pits[pitI].tone.id
                        if scoreView.model.notes.enumerated().contains(where: { i, nNote in
                            nNote.pits.enumerated().contains(where: {
                                !(i == noteI && $0.offset == pitI) ?
                                $0.element.tone.id == oID : false
                            })
                        }) {
                            
                            let score = scoreView.model
                            let nis = score.notes.enumerated().reduce(into: [Int: [Int]]()) { n, v in
                                let pitIs = v.element.pits.count.range
                                    .filter { v.element.pits[$0].tone.id == oID }
                                if !pitIs.isEmpty {
                                    n[v.offset] = pitIs
                                }
                            }
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
                                sheetView.unselect()
                                sheetView.replace(nivs)
                                
                                sheetView.updatePlaying()
                            }
                        } else {
                            var isChanged = false
                            if note.pits[pitI].tone != tone {
                                note.pits[pitI].tone = tone
                                isChanged = true
                            }
                            if scoreView.isStraightWithSelection(atPit: pitI, atNote: noteI),
                               pitI + 1 < note.pits.count,
                                note.pits[pitI + 1].tone != tone {
                                
                                note.pits[pitI + 1].tone = tone
                                isChanged = true
                            }
                            if isChanged {
                                sheetView.newUndoGroup()
                                sheetView.unselect()
                                sheetView.replace(note, at: noteI)
                                
                                sheetView.updatePlaying()
                            }
                        }
                    default: break
                    }
                }
            }
        case .rect(let rect):
            guard let sheetView = rootView.madeSheetView(at: shp) else { return }
            if sheetView.model.mainFrame != rect {
                sheetView.newUndoGroup()
                sheetView.set(SheetOption(mainFrame: rect))
            }
        case .tempo(let tempo):
            rootView.replaceTempo(fromTempo: tempo, in: [rootView.sheetPosition(at: p)])
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
        case .uuColor: true
        case .copiedAnimation: true
        case .ids: true
        case .content: true
        case .image: true
        case .beatRange: false
        case .normalizationValue: false
        case .normalizationRationalValue: false
        case .notesValue: true
        case .stereo: false
        case .tone: false
        case .rect: false
        case .tempo: false
        }
    }
    
    func cut(with event: InputKeyEvent) {
        guard isEditingSheet else {
            cutSheet(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            for runAction in rootAction.runActions {
                if runAction.containsCalculating(p) {
                    Pasteboard.shared.copiedObjects = [.string(runAction.calculatingString)]
                    runAction.cancel()
                    return
                }
            }
            if rootView.containsLookingUp(at: p) {
                rootView.closeLookingUp()
                return
            }
            
            type = .cut
            editingSP = event.screenPoint
            editingP = p
            cut(at: editingP)
            
            rootView.updateSelectedFrame()
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
        
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            type = .copy
            firstScale = rootView.worldToScreenScale
            editingSP = event.screenPoint
            editingP = rootView.convertScreenToWorld(event.screenPoint)
            updateWithCopy(for: editingP, isSendPasteboard: true)
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
            editingSP = event.screenPoint
            beganTime = event.time
            editingP = rootView.convertScreenToWorld(event.screenPoint)
            guard let o = Pasteboard.shared.copiedObjects.first else { return }
            pasteObject = o
            if isMovePasteObject {
                selectingLineNode.lineWidth = rootView.worldLineWidth
                snapLineNode.lineWidth = selectingLineNode.lineWidth
                updateWithPaste(at: editingP, atScreen: event.screenPoint,
                                event.phase, event)
                rootView.node.append(child: snapLineNode)
                rootView.node.append(child: selectingLineNode)
            } else {
                paste(at: editingP, atScreen: event.screenPoint, event: event)
            }
        case .changed:
            if isMovePasteObject {
                editingSP = event.screenPoint
                editingP = rootView.convertScreenToWorld(event.screenPoint)
                updateWithPaste(at: editingP, atScreen: event.screenPoint,
                                event.phase, event)
            }
        case .ended:
            notePlayer?.stop()
            
            if isMovePasteObject {
                editingSP = event.screenPoint
                editingP = rootView.convertScreenToWorld(event.screenPoint)
                paste(at: editingP, atScreen: event.screenPoint, event: event)
                snapLineNode.removeFromParent()
                selectingLineNode.removeFromParent()
            }
            
            rootView.updateSelectedFrame()
            rootView.updateFinding(at: editingP)
            rootView.updateTextCursor()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func updateWithCopySheet(at dp: Point,
                             isSelected: Bool, from values: [RootView.SheetFramePosition]) {
        var csv = CopiedSheetsValue()
        for value in values {
            if let sid = rootView.sheetID(at: value.shp) {
                csv.sheetIDs[value.shp] = sid
            }
        }
        if !csv.sheetIDs.isEmpty {
            csv.deltaPoint = dp
            csv.isSelected = isSelected
            Pasteboard.shared.copiedObjects = [.copiedSheetsValue(csv)]
        } else {
            rootView.cursor = .arrowWith(string: "Empty".localized)
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
                let nSelection = WorldSelection(sheetIDs: nIndexes.values.sorted())
                
                rootView.history.newUndoGroup()
                if !removeIndexes.isEmpty {
                    rootView.removeSheets(at: removeIndexes)
                }
                if !nIndexes.isEmpty {
                    rootView.append(nIndexes)
                }
                if csv.isSelected, nSelection != rootView.world.selection {
                    rootView.doSet(nSelection)
                }
                rootView.updateNode()
            }
        } else if case .tempo(let tempo) = pasteObject {
            let shps = rootView.sheetFramePositions(at: p).sfps.map { $0.shp }
            rootView.replaceTempo(fromTempo: tempo, in: shps)
        }
    }
    
    func cutSheet(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            type = .cut
            editingSP = event.screenPoint
            editingP = rootView.convertScreenToWorld(event.screenPoint)
            let p = rootView.convertScreenToWorld(event.screenPoint)
            let (isSelected, values) = rootView.sheetFramePositions(at: p)
            updateWithCopySheet(at: p, isSelected: isSelected, from: values)
            if !values.isEmpty {
                let shps = values.map { $0.shp }
                rootView.cursorPoint = event.screenPoint
                rootView.close(from: shps)
                rootView.newUndoGroup()
                if !rootView.world.selection.isEmpty {
                    rootView.doSet(WorldSelection.empty)
                }
                rootView.removeSheets(at: shps)
            }
            
            rootView.updateWithFinding()
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func copySheet(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            type = .copy
            editingSP = event.screenPoint
            editingP = rootView.convertScreenToWorld(event.screenPoint)
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = rootView.worldLineWidth * 2
            
            let p = rootView.convertScreenToWorld(event.screenPoint)
            let (isSelected, values) = rootView.sheetFramePositions(at: p)
            let roads = rootView.roads(fromMap: Set(values.map { $0.shp }))
            var roadPathlines = roads.compactMap {
                $0.pathlineWith(width: Sheet.width, height: Sheet.height)
            }
            
            if let lastPs = rootView.selectedLastPositionLinePoints {
                roadPathlines.append(.init(lastPs))
            }
            
            selectingLineNode.children = values.map {
                let sf = $0.frame
                return Node(attitude: Attitude(position: sf.origin),
                            path: Path(Rect(size: sf.size)),
                            lineWidth: selectingLineNode.lineWidth,
                            lineType: selectingLineNode.lineType,
                            fillType: selectingLineNode.fillType)
            } + (!roads.isEmpty ? [.init(path: .init(roadPathlines, isCap: false),
                                         lineWidth: selectingLineNode.lineWidth * 0.5,
                                         lineType: .color(.selected))] : [])
            updateWithCopySheet(at: p, isSelected: isSelected, from: values)
            
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
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootView.hideSelected()
            
            type = .paste
            firstScale = rootView.worldToScreenScale
            editingSP = event.screenPoint
            editingP = rootView.convertScreenToWorld(event.screenPoint)
            pasteObject = Pasteboard.shared.copiedObjects.first
            ?? .sheetValue(SheetValue(isSelected: false))
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = rootView.worldLineWidth
            
            rootView.node.append(child: selectingLineNode)
            rootView.node.append(child: pasteSheetNode)
            
            updateWithPasteSheet(at: event.screenPoint, phase: event.phase)
        case .changed:
            updateWithPasteSheet(at: event.screenPoint, phase: event.phase)
        case .ended:
            pasteSheet(at: event.screenPoint)
            selectingLineNode.removeFromParent()
            pasteSheetNode.removeFromParent()
            
            rootView.updateWithFinding()
            
            rootView.showSelected()
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class CutLinePointAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    var node = Node()
    
    func flow(with event: InputKeyEvent) {
        guard isEditingSheet else {
            return
        }
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            let p = rootView.convertScreenToWorld(event.screenPoint)
            var isCut = false
            if isEditingSheet,
               let sheetView = rootView.madeSheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                
                if let (lineView, li) = sheetView.lineTuple(at: sheetP,
                                                            scale: rootView.screenToWorldScale),
                   let pi = lineView.model.mainPointSequence.nearestIndex(at: sheetP) {
                    
                    var line = lineView.model
                    line.controls.remove(at: pi)
                    sheetView.newUndoGroup()
                    sheetView.removeLines(at: [li])
                    sheetView.insert([.init(value: line, index: li)])
                    isCut = true
                    
                    node.children = line.mainControlSequence.flatMap {
                        let p = sheetView.convertToWorld($0.point)
                        return [Node(path: .init(circleRadius: 0.35 * 1.5 * max(line.size * $0.pressure, 0.5),
                                                 position: p),
                                     fillType: .color(.content)),
                                Node(path: .init(circleRadius: 0.35 * max(line.size * $0.pressure, 0.5),
                                                 position: p),
                                     fillType: .color(.background))]
                    }
                }
            }
            
            if !isCut {
                rootView.cursor = .arrowWith(string: "Empty".localized)
            }
            
            rootView.node.append(child: node)
        case .changed:
            break
        case .ended:
            node.removeFromParent()
            
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
            updateWithCopy(for: editingP, isSendPasteboard: true)
        }
    }
    
    func flow(with event: InputKeyEvent) {
        guard isEditingSheet else {
            return
        }
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            firstScale = rootView.worldToScreenScale
            editingSP = event.screenPoint
            editingP = rootView.convertScreenToWorld(event.screenPoint)
            updateWithCopy(for: editingP, isSendPasteboard: true)
            rootView.node.append(child: selectingLineNode)
        case .changed:
            break
        case .ended:
            selectingLineNode.removeFromParent()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    @discardableResult
    func updateWithCopy(for p: Point, isSendPasteboard: Bool) -> Bool {
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
                + sheetView.animationView.interpolationNodes(from: [lineView.model.interID], scale: scale)
                + sheetView.interporatedTimelineNodes(from: [lineView.model.interID])
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
                    show(ps, color: .background)
                }
            }
            
            return true
        }
        rootView.cursor = .arrowWith(string: "Empty".localized)
        return false
    }
}
