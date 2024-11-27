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

enum Phase: Int8, Codable {
    case began, changed, ended
}
extension Phase: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .began: "began"
        case .changed: "changed"
        case .ended: "ended"
        }
    }
}

struct InputKeyType {
    static let click = InputKeyType(name: "Click".localized)
    static let subClick = InputKeyType(name: "SubClick".localized)
    static let threeFingersTap = InputKeyType(name: "3FingersTap".localized)
    static let fourFingersTap = InputKeyType(name: "4FingersTap".localized)
    
    static let a = InputKeyType(name: "Ａ"), b = InputKeyType(name: "Ｂ")
    static let c = InputKeyType(name: "Ｃ"), d = InputKeyType(name: "Ｄ")
    static let e = InputKeyType(name: "Ｅ"), f = InputKeyType(name: "Ｆ")
    static let g = InputKeyType(name: "Ｇ"), h = InputKeyType(name: "Ｈ")
    static let i = InputKeyType(name: "Ｉ"), j = InputKeyType(name: "Ｊ")
    static let k = InputKeyType(name: "Ｋ"), l = InputKeyType(name: "Ｌ")
    static let m = InputKeyType(name: "Ｍ"), n = InputKeyType(name: "Ｎ")
    static let o = InputKeyType(name: "Ｏ"), p = InputKeyType(name: "Ｐ")
    static let q = InputKeyType(name: "Ｑ"), r = InputKeyType(name: "Ｒ")
    static let s = InputKeyType(name: "Ｓ"), t = InputKeyType(name: "Ｔ")
    static let u = InputKeyType(name: "Ｕ"), v = InputKeyType(name: "Ｖ")
    static let w = InputKeyType(name: "Ｗ"), x = InputKeyType(name: "Ｘ")
    static let y = InputKeyType(name: "Ｙ"), z = InputKeyType(name: "Ｚ")
    
    static let no0 = InputKeyType(name: "0"), no1 = InputKeyType(name: "1")
    static let no2 = InputKeyType(name: "2"), no3 = InputKeyType(name: "3")
    static let no4 = InputKeyType(name: "4"), no5 = InputKeyType(name: "5")
    static let no6 = InputKeyType(name: "6"), no7 = InputKeyType(name: "7")
    static let no8 = InputKeyType(name: "8"), no9 = InputKeyType(name: "9")
    
    static let exclamationMark = InputKeyType(name: "!")
    static let quotationMarks = InputKeyType(name: "\"")
    static let numberSign = InputKeyType(name: "#")
    static let dollarSign = InputKeyType(name: "$")
    static let percentSign = InputKeyType(name: "%")
    static let ampersand = InputKeyType(name: "&")
    static let apostrophe = InputKeyType(name: "'")
    static let leftParentheses = InputKeyType(name: "(")
    static let rightParentheses = InputKeyType(name: ")")
    static let minus = InputKeyType(name: "-")
    static let equals = InputKeyType(name: "=")
    static let backApostrophe = InputKeyType(name: "^")
    static let tilde = InputKeyType(name: "~")
    static let yuanSign = InputKeyType(name: "¥")
    static let verticalBar = InputKeyType(name: "|")
    static let atSign = InputKeyType(name: "@")
    static let graveAccent = InputKeyType(name: "`")
    static let leftBracket = InputKeyType(name: "[")
    static let leftBrace = InputKeyType(name: "{")
    static let semicolon = InputKeyType(name: ";")
    static let plus = InputKeyType(name: "+")
    static let colon = InputKeyType(name: ":")
    static let asterisk = InputKeyType(name: "*")
    static let rightBracket = InputKeyType(name: "]")
    static let rightBrace = InputKeyType(name: "}")
    static let comma = InputKeyType(name: ",")
    static let lessThanSign = InputKeyType(name: "<")
    static let period = InputKeyType(name: ".")
    static let greaterThanSign = InputKeyType(name: ">")
    static let backslash = InputKeyType(name: "/")
    static let questionMark = InputKeyType(name: "?")
    static let underscore = InputKeyType(name: "_")
    
    static let space = InputKeyType(name: "space")
    
    static let command = InputKeyType(name: "⌘")
    static let shift = InputKeyType(name: "⇧")
    static let option = InputKeyType(name: "⌥")
    static let control = InputKeyType(name: "⌃")
    static let capsLock = InputKeyType(name: "⇪")
    static let function = InputKeyType(name: "🌐︎")
    
    static let escape = InputKeyType(name: "esc")
    
    static let backspace = InputKeyType(name: "backspace")
    static let carriageReturn = InputKeyType(name: "carriageReturn")
    static let newline = InputKeyType(name: "newline")
    static let enter = InputKeyType(name: "enter")
    static let delete = InputKeyType(name: "delete")
    static let deleteForward = InputKeyType(name: "deleteForward")
    static let backTab = InputKeyType(name: "backTab")
    static let tab = InputKeyType(name: "tab")
    static let up = InputKeyType(name: "↑")
    static let down = InputKeyType(name: "↓")
    static let left = InputKeyType(name: "←")
    static let right = InputKeyType(name: "→")
    static let pageUp = InputKeyType(name: "pageUp")
    static let pageDown = InputKeyType(name: "pageDown")
    static let home = InputKeyType(name: "home")
    static let end = InputKeyType(name: "end")
    static let prev = InputKeyType(name: "prev")
    static let next = InputKeyType(name: "next")
    static let begin = InputKeyType(name: "begin")
    static let `break` = InputKeyType(name: "break")
    static let clearDisplay = InputKeyType(name: "clearDisplay")
    static let clearLine = InputKeyType(name: "clearLine")
    static let deleteCharacter = InputKeyType(name: "deleteCharacter")
    static let deleteLine = InputKeyType(name: "deleteLine")
    static let execute = InputKeyType(name: "execute")
    static let find = InputKeyType(name: "find")
    static let formFeed = InputKeyType(name: "formFeed")
    static let help = InputKeyType(name: "help")
    static let insert = InputKeyType(name: "insert")
    static let insertCharacter = InputKeyType(name: "insertCharacter")
    static let insertLine = InputKeyType(name: "insertLine")
    static let lineSeparator = InputKeyType(name: "lineSeparator")
    static let menu = InputKeyType(name: "menu")
    static let modeSwitch = InputKeyType(name: "modeSwitch")
    static let paragraphSeparator = InputKeyType(name: "paragraphSeparator")
    static let pause = InputKeyType(name: "pause")
    static let print = InputKeyType(name: "print")
    static let printScreen = InputKeyType(name: "printScreen")
    static let redo = InputKeyType(name: "redo")
    static let reset = InputKeyType(name: "reset")
    static let scrollLock = InputKeyType(name: "scrollLock")
    static let select = InputKeyType(name: "select")
    static let stop = InputKeyType(name: "stop")
    static let sysReq = InputKeyType(name: "sysReq")
    static let system = InputKeyType(name: "system")
    static let undo = InputKeyType(name: "undo")
    static let user = InputKeyType(name: "user")
    static let f1 = InputKeyType(name: "F1")
    static let f2 = InputKeyType(name: "F2")
    static let f3 = InputKeyType(name: "F3")
    static let f4 = InputKeyType(name: "F4")
    static let f5 = InputKeyType(name: "F5")
    static let f6 = InputKeyType(name: "F6")
    static let f7 = InputKeyType(name: "F7")
    static let f8 = InputKeyType(name: "F8")
    static let f9 = InputKeyType(name: "F9")
    static let f10 = InputKeyType(name: "F10")
    static let f11 = InputKeyType(name: "F11")
    static let f12 = InputKeyType(name: "F12")
    static let f13 = InputKeyType(name: "F13")
    static let f14 = InputKeyType(name: "F14")
    static let f15 = InputKeyType(name: "F15")
    static let f16 = InputKeyType(name: "F16")
    static let f17 = InputKeyType(name: "F17")
    static let f18 = InputKeyType(name: "F18")
    static let f19 = InputKeyType(name: "F19")
    static let f20 = InputKeyType(name: "F20")
    static let f21 = InputKeyType(name: "F21")
    static let f22 = InputKeyType(name: "F22")
    static let f23 = InputKeyType(name: "F23")
    static let f24 = InputKeyType(name: "F24")
    static let f25 = InputKeyType(name: "F25")
    static let f26 = InputKeyType(name: "F26")
    static let f27 = InputKeyType(name: "F27")
    static let f28 = InputKeyType(name: "F28")
    static let f29 = InputKeyType(name: "F29")
    static let f30 = InputKeyType(name: "F30")
    static let f31 = InputKeyType(name: "F31")
    static let f32 = InputKeyType(name: "F32")
    static let f33 = InputKeyType(name: "F33")
    static let f34 = InputKeyType(name: "F34")
    static let f35 = InputKeyType(name: "F35")
    
    static let unknown = InputKeyType(name: "unknown")
    
    var name: String
}
extension InputKeyType: Hashable {}
extension InputKeyType {
    var isText: Bool {
        switch self {
        case .click, .subClick, .threeFingersTap, .fourFingersTap,
             .space, .enter, .tab, .delete,
             .escape, .command, .shift, .option, .control, .function,
             .up, .down, .left, .right,
             .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10,
             .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20,
             .f21, .f22, .f23, .f24, .f25, .f26, .f27, .f28, .f29, .f30,
             .f31, .f32, .f33, .f34, .f35:
            false
        default:
            true
        }
    }
    var isTextEdit: Bool {
        switch self {
        case .click, .subClick, .threeFingersTap, .fourFingersTap,
                .escape, .command, .shift, .option, .control, .function,
                .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10,
                .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20,
                .f21, .f22, .f23, .f24, .f25, .f26, .f27, .f28, .f29, .f30,
                .f31, .f32, .f33, .f34, .f35:
            false
        default:
            true
        }
    }
    var isInputText: Bool {
        switch self {
        case .click, .subClick, .threeFingersTap, .fourFingersTap,
             .escape, .command, .shift, .option, .control, .function,
             .up, .down, .left, .right,
             .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10,
             .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20,
             .f21, .f22, .f23, .f24, .f25, .f26, .f27, .f28, .f29, .f30,
             .f31, .f32, .f33, .f34, .f35:
            false
        default:
            true
        }
    }
    var isArrow: Bool {
        switch self {
        case .up, .down, .left, .right:
            true
        default:
            false
        }
    }
}

struct EventType {
    static let indicate = EventType(name: "Indicate".localized)
    static let drag = EventType(name: "Drag".localized)
    static let subDrag = EventType(name: "SubDrag".localized)
    static let otherDrag = EventType(name: "OtherDrag".localized)
    static let scroll = EventType(name: "2FingersScroll".localized)
    static let swipe = EventType(name: "3FingersScroll".localized)
    static let pinch = EventType(name: "2FingersPinch".localized)
    static let rotate = EventType(name: "2FingersRotate".localized)
    static let keyInput = EventType(name: "KeyInput".localized)
    
    var name: String
}
extension EventType: Hashable {}

struct ModifierKeys: OptionSet {
    let rawValue: Int
    
    static let shift = ModifierKeys(rawValue: 1 << 0)
    static let control = ModifierKeys(rawValue: 1 << 1)
    static let option = ModifierKeys(rawValue: 1 << 2)
    static let command = ModifierKeys(rawValue: 1 << 3)
    static let function = ModifierKeys(rawValue: 1 << 4)
}
extension ModifierKeys: Hashable {}
extension ModifierKeys {
    var displayString: String {
        var str = ""
        if contains(.shift) {
            str.append("⇧")
        }
        if contains(.function) {
            str.append("🌐︎")
        }
        if contains(.control) {
            str.append("⌃")
        }
        if contains(.option) {
            str.append("⌥")
        }
        if contains(.command) {
            str.append("⌘")
        }
        return str
    }
    var isOne: Bool {
        self == .shift || self == .control || self == .option || self == .command || self == .function
    }
    var oneInputKeyTYpe: InputKeyType? {
        switch self {
        case .shift: .shift
        case .control: .control
        case .option: .option
        case .command: .command
        case .function: .function
        default: nil
        }
    }
}
struct Quasimode {
    var modifierKeys: ModifierKeys
    var type: EventType
    var inputKeyType: InputKeyType?
    
    init(modifier modifierKeys: ModifierKeys = [], _ type: EventType) {
        self.modifierKeys = modifierKeys
        self.type = type
    }
    init(modifier modifierKeys: ModifierKeys = [], _ inputKeyType: InputKeyType) {
        self.modifierKeys = modifierKeys
        type = .keyInput
        self.inputKeyType = inputKeyType
    }
}
extension Quasimode: Hashable {}
extension Quasimode {
    var displayString: String {
        let mt = modifierKeys.displayString
        return mt.isEmpty ? inputDisplayString : mt + " " + inputDisplayString
    }
    var modifierDisplayString: String {
        modifierKeys.displayString
    }
    var inputDisplayString: String {
        inputKeyType?.name ?? type.name
    }
}
extension Quasimode {
    static let drawLine = Self(.drag)
    static let drawStraightLine = Self(modifier: [.shift], .drag)
    
    static let lassoCut = Self(modifier: [.command], .drag)
    static let selectVersion = Self(modifier: [.shift, .command], .drag)
    
    static let changeLightness = Self(modifier: [.option], .drag)
    static let changeTint = Self(modifier: [.shift, .option], .drag)
    static let changeOpacity = Self(modifier: [.control, .option], .drag)
    
    static let move = Self(modifier: [.control], .drag)
    static let moveLineZ = Self(modifier: [.shift, .control], .drag)
    
    static let selectFrame = Self(.swipe)
    static let keySelectFrame = Self(modifier: [.control, .command], .drag)
    static let play = Self(.fourFingersTap)
    static let keyPlay = Self(modifier: [.control, .command], .click)
    
    static let goPrevious = Self(modifier: [.control], .z)//
    static let goNext = Self(modifier: [.control], .x)//
    static let goPreviousFrame = Self(modifier: [.control, .option], .z)//
    static let goNextFrame = Self(modifier: [.control, .option], .x)//
    static let controlCopy = Self(modifier: [.control], .c)//
    static let controlInterpolate = Self(modifier: [.control], .s)//
    
    static let zoom = Self(.pinch)
    static let keyZoom = Self(modifier: [.control, .option, .command], .drag)
    static let scroll = Self(.scroll)
    static let keyScroll = Self(modifier: [.shift, .control, .command], .drag)
    static let rotate = Self(.rotate)
    static let keyRotate = Self(modifier: [.shift, .control, .option, .command], .drag)
    
    static let lookUp = Self(.threeFingersTap)
    static let keyLookUp = Self(modifier: [.control, .command], .d)
    static let selectByRange = Self(.subDrag)
    static let openMenu = Self(.subClick)
    
    static let runOrClose = Self(.click)
    static let stop = Self(.escape)
    
    static let inputCharacter = Self(.keyInput)
    
    static let changeToSuperscript = Self(modifier: [.command], .up)
    static let changeToSubscript = Self(modifier: [.command], .down)
    
    static let undo = Self(modifier: [.command], .z)
    static let redo = Self(modifier: [.shift, .command], .z)
    
    static let cut = Self(modifier: [.command], .x)
    static let copy = Self(modifier: [.command], .c)
    static let copyLineColor = Self(modifier: [.option, .command], .c)
    static let paste = Self(modifier: [.command], .v)
    
    static let find = Self(modifier: [.command], .f)
    
    static let changeToDraft = Self(modifier: [.command], .d)
    static let cutDraft = Self(modifier: [.shift, .command], .d)
    
    static let makeFaces = Self(modifier: [.command], .b)
    static let cutFaces = Self(modifier: [.shift, .command], .b)
    
    static let changeToVerticalText = Self(modifier: [.command], .l)
    static let changeToHorizontalText = Self(modifier: [.shift, .command], .l)
    
    static let insertKeyframe = Self(modifier: [.command], .e)
    static let addScore = Self(modifier: [.shift, .command], .e)
    
    static let interpolate = Self(modifier: [.command], .s)
    static let crossErase = Self(modifier: [.shift, .command], .s)
}

protocol Event {
    var screenPoint: Point { get }
    var time: Double { get }
    var phase: Phase { get }
}

struct InputKeyEvent: Event {
    var screenPoint: Point, time: Double, pressure: Double, phase: Phase,
        isRepeat: Bool
    var inputKeyType: InputKeyType
}

struct DragEvent: Event {
    var screenPoint: Point, time: Double, pressure: Double, phase: Phase
}
extension DragEvent {
    init(_ event: InputKeyEvent) {
        screenPoint = event.screenPoint
        time = event.time
        pressure = 1
        phase = event.phase
    }
}

struct ScrollEvent: Event {
    var screenPoint: Point, time: Double, scrollDeltaPoint: Point
    var phase: Phase, touchPhase: Phase?, momentumPhase: Phase?
}

struct SwipeEvent: Event {
    var screenPoint: Point, time: Double, scrollDeltaPoint: Point
    var phase: Phase
}

struct PinchEvent: Event {
    var screenPoint: Point, time: Double, magnification: Double, phase: Phase
}

struct RotateEvent: Event {
    var screenPoint: Point, time: Double, rotationQuantity: Double, phase: Phase
}

struct TouchEvent: Event {
    struct Finger: Hashable {
        var normalizedPosition: Point, phase: Phase, id: Int
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    var screenPoint: Point, time: Double, phase: Phase
    var fingers: Set<Finger>, deviceSize: Size
}

struct ActionItem {
    var name: String, quasimode: Quasimode, isEnableRoot = true
}
struct ActionList {
    typealias Group = [ActionItem]
    
    var actionGroups: [Group]
    var actionItems: [ActionItem]
    
    init(_ actionGroups: [Group]) {
        self.actionGroups = actionGroups
        actionItems = actionGroups.reduce(into: .init()) { $0 += $1 }
    }
}
extension ActionList {
    static let `default` = ActionList([[.init(name: "Draw Line".localized,
                                              quasimode: .drawLine,
                                              isEnableRoot: false),
                                       .init(name: "Draw Straight Line".localized,
                                              quasimode: .drawStraightLine,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Lasso Cut".localized,
                                              quasimode: .lassoCut),
                                       .init(name: "Select Version".localized,
                                              quasimode: .selectVersion)],
                                      
                                      [.init(name: "Change Lightness".localized,
                                              quasimode: .changeLightness,
                                              isEnableRoot: false),
                                       .init(name: "Change Tint".localized,
                                              quasimode: .changeTint,
                                              isEnableRoot: false),
                                       .init(name: "Change Opacity".localized,
                                              quasimode: .changeOpacity,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Move".localized,
                                              quasimode: .move,
                                              isEnableRoot: false),
                                       .init(name: "Move Line Z".localized,
                                              quasimode: .moveLineZ,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Select Frame".localized,
                                              quasimode: .selectFrame,
                                              isEnableRoot: false),
                                       .init(name: "Play".localized,
                                              quasimode: .play,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Zoom".localized,
                                             quasimode: .zoom),
                                       .init(name: "Scroll".localized,
                                              quasimode: .scroll),
                                       .init(name: "Rotate".localized,
                                              quasimode: .rotate)],
                                      
                                      [.init(name: "Look Up".localized,
                                              quasimode: .lookUp),
                                       .init(name: "Select by Range".localized,
                                              quasimode: .selectByRange),
                                       .init(name: "Open Menu".localized,
                                              quasimode: .openMenu),
                                       .init(name: "Input Character".localized,
                                              quasimode: .inputCharacter,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Undo".localized,
                                              quasimode: .undo),
                                       .init(name: "Redo".localized,
                                              quasimode: .redo)],
                                      
                                      [.init(name: "Cut".localized,
                                              quasimode: .cut),
                                       .init(name: "Copy".localized,
                                              quasimode: .copy),
                                       .init(name: "Copy Line Color".localized,
                                              quasimode: .copyLineColor),
                                       .init(name: "Paste".localized,
                                              quasimode: .paste),],
                                      
                                      [.init(name: "Find".localized,
                                              quasimode: .find,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Change to Draft".localized,
                                              quasimode: .changeToDraft,
                                              isEnableRoot: false),
                                       .init(name: "Cut Draft".localized,
                                              quasimode: .cutDraft,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Make Faces".localized,
                                              quasimode: .makeFaces,
                                              isEnableRoot: false),
                                       .init(name: "Cut Faces".localized,
                                              quasimode: .cutFaces,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Change to Vertical Text".localized,
                                              quasimode: .changeToVerticalText,
                                              isEnableRoot: false),
                                       .init(name: "Change to Horizontal Text".localized,
                                              quasimode: .changeToHorizontalText,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Insert Keyframe".localized,
                                              quasimode: .insertKeyframe,
                                              isEnableRoot: false),
                                       .init(name: "Add Score".localized,
                                              quasimode: .addScore,
                                              isEnableRoot: false)],
                                      
                                      [.init(name: "Interpolate".localized,
                                              quasimode: .interpolate,
                                              isEnableRoot: false),
                                       .init(name: "Cross Erase".localized,
                                              quasimode: .crossErase,
                                              isEnableRoot: false)]])
}
extension ActionList {
    func node(isEditingSheet: Bool) -> Node {
        let fontSize = 12.0
        let padding = fontSize / 2, lineWidth = 1.0, cornerRadius = 8.0
        let margin = fontSize / 2 + 1.0, imagePadding = 3.0
        
        func textNode(with string: String, color: Color = .content) -> (size: Size, node: Node)? {
            let typesetter = Text(string: string, size: fontSize).typesetter
            let paddingSize = Size(square: imagePadding)
            guard let b = typesetter.typoBounds else { return nil }
            let nb = b.outset(by: paddingSize).integral
            let backColor = Color(lightness: color.lightness, opacity: 0)
            guard let texture = typesetter.texture(with: nb, fillColor: color,
                                                   backgroundColor: backColor) else { return nil }
            return (b.integral.size, Node(path: Path(nb), fillType: .texture(texture)))
        }
        
        var quasimodeNodes = [Node]()
        var borderNodes = [(height: Double, node: Node)]()
        var children = [Node]()
        
        var w = 0.0, h = margin
        for (i, actionGroup) in actionGroups.reversed().enumerated() {
            var isDraw = false
            for action in actionGroup.reversed() {
                let color: Color = !isEditingSheet && !action.isEnableRoot ?
                Color(lightness: Color.content.lightness, opacity: 0.3) : .content
                guard let (nts, nNode) = textNode(with: action.name, color: color),
                      let (its, iNode)
                        = textNode(with: action.quasimode.inputDisplayString, color: color) else { continue }
                nNode.attitude.position = Point((margin + imagePadding).rounded(), h + fontSize / 2 - imagePadding)
                iNode.attitude.position = Point(-its.width + imagePadding, h + fontSize / 2 - imagePadding)
                let qw: Double, qNode: Node
                if let (mts, mNode) = textNode(with: action.quasimode.modifierDisplayString, color: color) {
                    qw = (its.width + padding + mts.width).rounded()
                    mNode.attitude.position = Point(-qw + imagePadding, h + fontSize / 2 - imagePadding)
                    qNode = Node(children: [iNode, mNode])
                } else {
                    qw = its.width.rounded()
                    qNode = Node(children: [iNode])
                }
                w = max(w, nts.width + qw + margin * 2)
                quasimodeNodes.append(qNode)
                children.append(nNode)
                children.append(qNode)
                h += fontSize + padding
                isDraw = true
            }
            if isDraw {
                h += -padding + margin
                
                if i < actionGroups.count - 1 {
                    let borderNode = Node(lineWidth: lineWidth, lineType: .color(.subBorder))
                    children.append(borderNode)
                    borderNodes.append((h, borderNode))
                    h += margin
                }
            }
        }
        
        w += margin * 2
        
        for node in quasimodeNodes {
            node.attitude.position.x = (w - margin).rounded()
        }
        for (height, node) in borderNodes {
            node.path = Path(Edge(Point(0, height), Point(w, height)))
        }
        
        let f = Rect(x: 0, y: 0, width: w, height: h)
        let node = Node(children: children,
                        attitude: Attitude(position: Point()),
                        path: Path(f, cornerRadius: cornerRadius),
                        lineWidth: lineWidth, lineType: .color(.subBorder),
                        fillType: .color(.transparentDisabled))
        return Node(children: [node], path: Path(f.inset(by: -margin)))
    }
}
