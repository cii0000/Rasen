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

struct InputKeyType {
    static let click = InputKeyType(name: "Click".localized)
    static let subClick = InputKeyType(name: "SubClick".localized)
    static let topSubClick = InputKeyType(name: "TopSubClick".localized)
    static let lookUpTap = InputKeyType(name: "LookUpOperate".localized)
    static let fourFingers = InputKeyType(name: "FourFingers".localized)
    
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
        case .click, .subClick, .lookUpTap,
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
        case .click, .subClick, .lookUpTap,
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
        case .click, .subClick, .lookUpTap,
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
    static let scroll = EventType(name: "Scroll".localized)
    static let swipe = EventType(name: "Swipe".localized)
    static let pinch = EventType(name: "Pinch".localized)
    static let rotate = EventType(name: "Rotate".localized)
    static let keyInput = EventType(name: "KeyInput".localized)
    static let vPinch = EventType(name: "V Pinch".localized)
    
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
        if contains(.option) {
            str.append("⌥")
        }
        if contains(.control) {
            str.append("⌃")
        }
        if contains(.command) {
            str.append("⌘")
        }
        if contains(.function) {
            str.append("🌐︎")
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
    static let drawLine = Quasimode(.drag)
    static let drawStraightLine = Quasimode(modifier: [.shift], .drag)
    
    static let lassoCut = Quasimode(modifier: [.command], .drag)
    static let selectByRange = Quasimode(modifier: [.shift, .command], .drag)
    
    static let changeLightness = Quasimode(modifier: [.option], .drag)
    static let changeTint = Quasimode(modifier: [.shift, .option], .drag)
    
    static let movePreviousKeyframe = Quasimode(modifier: [.control], .z)
    static let moveNextKeyframe = Quasimode(modifier: [.control], .x)
    static let movePreviousTime = Quasimode(modifier: [.control, .option], .z)
    static let moveNextTime = Quasimode(modifier: [.control, .option], .x)
    static let selectTime = Quasimode(modifier: [.control, .option], .drag)
    
    static let slide = Quasimode(modifier: [.control], .drag)
    static let slideLine = Quasimode(modifier: [.control, .option, .command], .drag)
    static let moveLineZ = Quasimode(modifier: [.control, .command], .drag)
    
    static let selectVersion = Quasimode(modifier: [.control, .shift], .drag)
    
    static let play = Quasimode(modifier: [.control], .click)
    static let otherDragPlay = Quasimode(.otherDrag)
    static let controlPlay = Quasimode(.control)
    static let showTone = Quasimode(modifier: [.command], .click)
    static let run = Quasimode(.click)
    static let openMenu = Quasimode(.subClick)
    static let lookUp = Quasimode(.lookUpTap)
    
    static let inputCharacter = Quasimode(.keyInput)
    static let newWrap = Quasimode(modifier: [.shift], .enter)
    static let deleteWrap = Quasimode(modifier: [.shift], .delete)
    
    static let zoom = Quasimode(.pinch)
    static let rotate = Quasimode(.rotate)
    static let scroll = Quasimode(.scroll)
    
    static let undo = Quasimode(modifier: [.command], .z)
    static let redo = Quasimode(modifier: [.shift, .command], .z)
    
    static let cut = Quasimode(modifier: [.command], .x)
    static let copy = Quasimode(modifier: [.command], .c)
    static let copyLineColor = Quasimode(modifier: [.option, .command], .c)
    static let copyTone = Quasimode(modifier: [.shift, .command], .c)
    static let paste = Quasimode(modifier: [.command], .v)
    static let scalingPaste = Quasimode(modifier: [.command], .vPinch)
    
    static let find = Quasimode(modifier: [.command], .f)
    
    static let changeToDraft = Quasimode(modifier: [.command], .d)
    static let cutDraft = Quasimode(modifier: [.shift, .command], .d)
    
    static let makeFaces = Quasimode(modifier: [.command], .b)
    static let cutFaces = Quasimode(modifier: [.shift, .command], .b)
    
    static let changeToSuperscript = Quasimode(modifier: [.command], .up)
    static let changeToSubscript = Quasimode(modifier: [.command], .down)
    
    static let changeToVerticalText = Quasimode(modifier: [.command], .l)
    static let changeToHorizontalText = Quasimode(modifier: [.command, .shift], .l)
    
    static let insertKeyframe = Quasimode(modifier: [.command], .e)
    static let addScore = Quasimode(modifier: [.command, .shift], .e)
    
    static let interpolate = Quasimode(modifier: [.command], .s)
    static let crossErase = Quasimode(modifier: [.shift, .command], .s)
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
