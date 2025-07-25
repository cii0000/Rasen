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

//#if os(macOS)
import MetalKit
//#elseif os(iOS) && os(watchOS) && os(tvOS) && os(visionOS) && os(linux) && os(windows)
//#endif

//#if os(macOS) && os(iOS) && os(watchOS) && os(tvOS) && os(visionOS)
import UniformTypeIdentifiers
//#elseif os(linux) && os(windows)
//#endif

@main struct App {
    static func main() {
        let app = SubNSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class SubNSApplication: NSApplication {
    // AppKit bug: nsEvent.allTouches() returns [] after sleep
    @objc protocol HIDEvent {}
    static let cgHandle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW)
    typealias CGEventCopyIOHIDEventType = @convention(c) (_ cgEvent: CGEvent) -> any HIDEvent
    let CGEventCopyIOHIDEvent = unsafeBitCast(dlsym(cgHandle, "CGEventCopyIOHIDEvent"),
                                              to: CGEventCopyIOHIDEventType.self)
    
    static let ioKitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)
    typealias IOHIDEventGetChildrenType = @convention(c) (_ event: any HIDEvent) -> CFArray
    let IOHIDEventGetChildren = unsafeBitCast(dlsym(ioKitHandle, "IOHIDEventGetChildren"),
                                              to: IOHIDEventGetChildrenType.self)
    typealias IOHIDEventGetTypeType = @convention(c) (_ event: any AnyObject) -> UInt32
    let IOHIDEventGetType = unsafeBitCast(dlsym(ioKitHandle, "IOHIDEventGetType"),
                                          to: IOHIDEventGetTypeType.self)
    typealias IOHIDEventGetEventFlagsType = @convention(c) (_ event: any AnyObject) -> UInt64
    let IOHIDEventGetEventFlags = unsafeBitCast(dlsym(ioKitHandle, "IOHIDEventGetEventFlags"),
                                                to: IOHIDEventGetEventFlagsType.self)
    typealias IOHIDEventGetIntegerValueType = @convention(c) (_ event: any AnyObject, UInt32) -> Int32
    let IOHIDEventGetIntegerValue = unsafeBitCast(dlsym(ioKitHandle, "IOHIDEventGetIntegerValue"),
                                                  to: IOHIDEventGetIntegerValueType.self)
    typealias IOHIDEventGetFloatValueType = @convention(c) (_ event: any AnyObject, UInt32) -> Double
    let IOHIDEventGetFloatValue = unsafeBitCast(dlsym(ioKitHandle, "IOHIDEventGetFloatValue"),
                                                to: IOHIDEventGetFloatValueType.self)
    
    private var touchDeviceSizes = [UInt64: Size](), oldTouchEvent: TouchEvent?
    override func sendEvent(_ nsEvent: NSEvent) {
        if nsEvent.type == .gesture {
            if let cgEvent = nsEvent.cgEvent, let view = nsEvent.window?.contentView as? SubMTKView {
                let ioEvent = CGEventCopyIOHIDEvent(cgEvent)
                let flags = IOHIDEventGetEventFlags(ioEvent)
                let flagID = (flags >> 4) & 0xF
                if let size = nsEvent.allTouches().first?.deviceSize {
                    touchDeviceSizes[flagID] = size.my
                }
                if let deviceSize = touchDeviceSizes[flagID] {
                    let array = IOHIDEventGetChildren(ioEvent) as Array
                    var fingers = [Int: TouchEvent.Finger]()
                    for o in array {
                        // Referenced definition:
                        // https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-2102.0.6/IOHIDFamily/IOHIDEvent.h
                        // https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1446.140.2/IOHIDFamily/IOHIDEventFieldDefs.h
                        if IOHIDEventGetType(o) == 11 {
                            let x = IOHIDEventGetFloatValue(o, (11 << 16) | 0)
                            let y = IOHIDEventGetFloatValue(o, (11 << 16) | 1)
                            let id = Int(IOHIDEventGetIntegerValue(o, (11 << 16) | 5))
                            let flags = IOHIDEventGetEventFlags(o)
                            let flags1 = flags == 0x1, flags2 = flags == 0x10001
                            let isTouch = Int(IOHIDEventGetIntegerValue(o, (11 << 16) | 9)) == 1
                            guard !(oldTouchEvent == nil && !isTouch) else { continue }
                            let phase: Phase = if let oldTouchEvent,
                                                    let v = oldTouchEvent.fingers[id] {
                                flags1 ? .ended : (v.phase == .ended ?
                                                   (!isTouch ? .ended : .began) :
                                                    (flags2 && !isTouch ? .ended : .changed))
                            } else {
                                .began
                            }
                            guard !(phase == .began && (flags1 || flags2)) else { continue }
                            if let oldTouchEvent, phase == .ended,
                               let oldFinger = oldTouchEvent.fingers[id], oldFinger.phase == .ended { continue }
                            fingers[id] = .init(normalizedPosition: .init(x, 1 - y), phase: phase, id: id)
                        }
                    }
                    if !fingers.isEmpty {
                        let screenPoint = view.screenPoint(with: nsEvent).my
                        let time = nsEvent.timestamp
                        let phase: Phase = fingers.contains(where: { $0.value.phase == .began }) ?
                            .began : (fingers.contains(where: { $0.value.phase == .ended }) ? .ended : .changed)
                        let event = TouchEvent(screenPoint: screenPoint, time: time, phase: phase,
                                               fingers: fingers, deviceSize: deviceSize)
                        switch event.phase {
                        case .began: view.touchesBegan(with: event)
                        case .changed: view.touchesMoved(with: event)
                        case .ended: view.touchesEnded(with: event)
                        }
                        
                        oldTouchEvent = fingers.allSatisfy({ $0.value.phase == .ended }) ? nil : event
                        return
                    }
                }
            }
            
            nsEvent.window?.sendEvent(nsEvent)
        } else if nsEvent.type == .keyUp && nsEvent.modifierFlags.contains(.command) {
            nsEvent.window?.sendEvent(nsEvent)
        } else {
            super.sendEvent(nsEvent)
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    static let isFullscreenKey = "isFullscreen"
    static let defaultViewSize = NSSize(width: 900, height: 700)
    var window: NSWindow!
    var view: SubMTKView!
    weak var fileMenu: NSMenu?, editMenu: NSMenu?, editMenuItem: NSMenuItem?
    
    override init() {
        AppDelegate.updateSelectedColor()
        super.init()
    }
    
    func updateSelectedColor() {
        AppDelegate.updateSelectedColor()
        if window.isMainWindow {
            view.rootView.updateSelectedColor(isMain: true)
        }
    }
    static func updateSelectedColor() {
        var selectedColor = Color(NSColor.controlAccentColor.cgColor)
        selectedColor.white = Color.selectedWhite
        Color.selected = selectedColor
        Renderer.shared.appendColorBuffer(with: selectedColor)
        
        var subSelectedColor = Color(NSColor.selectedTextBackgroundColor.cgColor)
        subSelectedColor.white = Color.subSelectedWhite
        subSelectedColor.opacity = Color.subSelectedOpacity
        Color.subSelected = subSelectedColor
        Renderer.shared.appendColorBuffer(with: subSelectedColor)
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        view = SubMTKView(url: URL.library)
        view.frame = NSRect(origin: NSPoint(),
                            size: AppDelegate.defaultViewSize)
        
        let viewController = NSViewController()
        viewController.view = view
        window = NSWindow(contentViewController: viewController)
        window.title = ""
        window.center()
        window.setFrameAutosaveName("Main")
        window.delegate = self
        if !window.styleMask.contains(.fullScreen)
            && UserDefaults.standard.bool(forKey: AppDelegate.isFullscreenKey) {
            
            window.toggleFullScreen(nil)
        }
        
        do {
            try view.rootView.restoreDatabase()
        } catch {
            view.rootView.node.show(error)
        }
        view.rootView.cursorPoint = view.clippedScreenPointFromCursor.my
        
        SubNSApplication.shared.servicesMenu = NSMenu()
        SubNSApplication.shared.mainMenu = mainMenu()
        
        Task { [weak self] in
            let notifications = NotificationCenter.default
                .notifications(named: NSColor.systemColorsDidChangeNotification)
            for await _ in notifications.map({ _ in }) {
                self?.updateSelectedColor()
            }
        }
    }
    private func mainMenu() -> NSMenu {
        let appName = System.appName.localized
        let appMenu = NSMenu(title: appName)
        appMenu.addItem(withTitle: String(format: "About %@".localized, appName),
                        action: #selector(SubNSApplication.shared.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        
        let databaseMenu = NSMenu()
        databaseMenu.addItem(withTitle: "Replace...".localized,
                             action: #selector(SubMTKView.replaceDatabase(_:)),
                             keyEquivalent: "")
        databaseMenu.addItem(withTitle: "Export...".localized,
                             action: #selector(SubMTKView.exportDatabase(_:)),
                             keyEquivalent: "")
        databaseMenu.addItem(NSMenuItem.separator())
        databaseMenu.addItem(withTitle: "Reset...".localized,
                             action: #selector(SubMTKView.resetDatabase(_:)),
                             keyEquivalent: "")
        let databaseMenuItem = NSMenuItem(title: System.dataName,
                                          action: nil, keyEquivalent: "")
        databaseMenuItem.submenu = databaseMenu
        appMenu.addItem(databaseMenuItem)
        
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Clear Root History...".localized,
                        action: #selector(SubMTKView.clearHistoryDatabase(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let servicesMenuItem = NSMenuItem(title: "Services".localized,
                                          action: nil, keyEquivalent: "")
        servicesMenuItem.submenu = SubNSApplication.shared.servicesMenu
        appMenu.addItem(servicesMenuItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: String(format: "Hide %@".localized, appName),
                        action: #selector(SubNSApplication.hide(_:)),
                        keyEquivalent: "h", modifierFlags: [.command])
        appMenu.addItem(withTitle: "Hide Others".localized,
                        action: #selector(SubNSApplication.hideOtherApplications(_:)),
                        keyEquivalent: "h", modifierFlags: [.command, .option])
        appMenu.addItem(withTitle: "Show All".localized,
                        action: #selector(SubNSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: String(format: "Quit %@".localized, appName),
                        action: #selector(SubNSApplication.terminate(_:)),
                        keyEquivalent: "q", modifierFlags: [.command])
        let appMenuItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        
        let fileString = "File".localized
        let fileMenu = NSMenu(title: fileString)
        fileMenu.delegate = self
        fileMenu.addItem(withTitle: "Import...".localized,
                         action: #selector(SubMTKView.importDocument(_:)))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Export as Image...".localized,
                         action: #selector(SubMTKView.exportAsImage(_:)))
        fileMenu.addItem(withTitle: "Export as 4K Image...".localized,
                         action: #selector(SubMTKView.exportAsImage4K(_:)))
        fileMenu.addItem(withTitle: "Export as PDF...".localized,
                         action: #selector(SubMTKView.exportAsPDF(_:)))
        fileMenu.addItem(withTitle: "Export as GIF...".localized,
                         action: #selector(SubMTKView.exportAsGIF(_:)))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Export as Movie...".localized,
                         action: #selector(SubMTKView.exportAsMovie(_:)))
        fileMenu.addItem(withTitle: "Export as 4K Movie...".localized,
                         action: #selector(SubMTKView.exportAsMovie4K(_:)))
        fileMenu.addItem(withTitle: "Export as Sound...".localized,
                         action: #selector(SubMTKView.exportAsSound(_:)))
        fileMenu.addItem(withTitle: "Export as Linear PCM...".localized,
                         action: #selector(SubMTKView.exportAsLinearPCM(_:)))
        
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Export as Document...".localized,
                         action: #selector(SubMTKView.exportAsDocument(_:)))
        fileMenu.addItem(withTitle: "Export as Document with History...".localized,
                         action: #selector(SubMTKView.exportAsDocumentWithHistory(_:)))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Clear History...".localized,
                         action: #selector(SubMTKView.clearHistory(_:)))
        self.fileMenu = fileMenu
        let fileMenuItem = NSMenuItem(title: fileString,
                                      action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        
        let editString = "Edit".localized
        let editMenu = NSMenu(title: editString)
        editMenu.delegate = self
        editMenu.addItem(withTitle: "Undo".localized,
                         action: #selector(SubMTKView.undo(_:)),
                         keyEquivalent: "z", modifierFlags: [.command])
        editMenu.addItem(withTitle: "Redo".localized,
                         action: #selector(SubMTKView.redo(_:)),
                         keyEquivalent: "z", modifierFlags: [.command, .shift])
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut".localized,
                         action: #selector(SubMTKView.cut(_:)),
                         keyEquivalent: "x", modifierFlags: [.command])
        editMenu.addItem(withTitle: "Copy".localized,
                         action: #selector(SubMTKView.copy(_:)),
                         keyEquivalent: "c", modifierFlags: [.command])
        editMenu.addItem(withTitle: "Paste".localized,
                         action: #selector(SubMTKView.paste(_:)),
                         keyEquivalent: "v", modifierFlags: [.command])
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Find".localized,
                         action: #selector(SubMTKView.find(_:)),
                         keyEquivalent: "f", modifierFlags: [.command])
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Change to Draft".localized,
                         action: #selector(SubMTKView.changeToDraft(_:)),
                         keyEquivalent: "d", modifierFlags: [.command])
        editMenu.addItem(withTitle: "Cut Draft".localized,
                         action: #selector(SubMTKView.cutDraft(_:)),
                         keyEquivalent: "d", modifierFlags: [.command, .shift])
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Make Faces".localized,
                         action: #selector(SubMTKView.makeFaces(_:)),
                         keyEquivalent: "b", modifierFlags: [.command])
        editMenu.addItem(withTitle: "Cut Faces".localized,
                         action: #selector(SubMTKView.cutFaces(_:)),
                         keyEquivalent: "b", modifierFlags: [.command, .shift])
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Change to Vertical Text".localized,
                         action: #selector(SubMTKView.changeToVerticalText(_:)),
                         keyEquivalent: "l", modifierFlags: [.command])
        editMenu.addItem(withTitle: "Change to Horizontal Text".localized,
                         action: #selector(SubMTKView.changeToHorizontalText(_:)),
                         keyEquivalent: "l", modifierFlags: [.command, .shift])
        self.editMenu = editMenu
        let editMenuItem = NSMenuItem(title: editString,
                                      action: nil, keyEquivalent: "")
        self.editMenuItem = editMenuItem
        editMenuItem.submenu = editMenu
        
        let actionString = "Action".localized
        let actionMenu = NSMenu(title: actionString)
        actionMenu.addItem(withTitle: "Shown Action List".localized,
                           action: #selector(SubMTKView.shownActionList(_:)),
                           keyEquivalent: "")
        actionMenu.addItem(withTitle: "Hidden Action List".localized,
                           action: #selector(SubMTKView.hiddenActionList(_:)),
                           keyEquivalent: "")
        actionMenu.addItem(NSMenuItem.separator())
        
        actionMenu.addItem(withTitle: "Shown Trackpad Alternative".localized,
                           action: #selector(SubMTKView.shownTrackpadAlternative(_:)),
                           keyEquivalent: "")
        actionMenu.addItem(withTitle: "Hidden Trackpad Alternative".localized,
                           action: #selector(SubMTKView.hiddenTrackpadAlternative(_:)),
                           keyEquivalent: "")
        let actionMenuItem = NSMenuItem(title: actionString,
                                        action: nil, keyEquivalent: "")
        actionMenuItem.submenu = actionMenu
        
        let windowString = "Window".localized
        let windowMenu = NSMenu(title: windowString)
        windowMenu.addItem(withTitle: "Close".localized,
                           action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w", modifierFlags: [.command, .shift])
        windowMenu.addItem(withTitle: "Minimize".localized,
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m", modifierFlags: [.command])
        windowMenu.addItem(withTitle: "Enter Full Screen",
                           action: #selector(NSWindow.toggleFullScreen(_:)),
                           keyEquivalent: "f", modifierFlags: [.command, .control])
        let windowMenuItem = NSMenuItem(title: windowString,
                                        action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        
        let helpString = "Help".localized
        let helpMenu = NSMenu(title: helpString)
        helpMenu.addItem(withTitle: "Acknowledgments".localized,
                         action: #selector(AppDelegate.showAcknowledgments(_:)),
                         keyEquivalent: "")
        let helpMenuItem = NSMenuItem(title: helpString,
                                      action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        
        let mainMenu = NSMenu(title: "Main Menu")
        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(editMenuItem)
        mainMenu.addItem(actionMenuItem)
        mainMenu.addItem(windowMenuItem)
        mainMenu.addItem(helpMenuItem)
        return mainMenu
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        view.cancelTasks()
        urlTimer.cancel()
        view.rootView.endSave { _ in
            SubNSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    
    private var urlTimer = OneshotTimer(), urls = [URL]()
    func application(_ application: NSApplication, open urls: [URL]) {
        let beginClosure: () -> () = { [weak self] in
            guard let self else { return }
            self.urls = urls
        }
        let waitClosure: () -> () = { [weak self] in
            guard let self else { return }
            self.urls += urls
        }
        let cancelClosure: () -> () = {}
        let endClosure: () -> () = { [weak self] in
            guard let self else { return }
            let urls = self.urls.filter { $0 != self.view.rootView.model.url }
            if urls.count == 1
                && urls[0].pathExtension == Document.FileType.rasendata.filenameExtension {
                
                self.view.replaceDatabase(from: urls[0])
            } else {
                guard !urls.isEmpty else { return }
                let action = IOAction(self.view.rootAction)
                let sp =  self.view.bounds.my.centerPoint
                let shp = action.beginImportFile(at: sp)
                action.importFile(from: urls, at: shp)
                self.urls = []
            }
        }
        urlTimer.start(afterTime: 1, dispatchQueue: .main,
                       beginClosure: beginClosure,
                       waitClosure: waitClosure,
                       cancelClosure: cancelClosure,
                       endClosure: endClosure)
    }
    func windowDidBecomeMain(_ notification: Notification) {
        updateDocumentFromWindow()
        view.update()
        view.rootView.updateSelectedColor(isMain: true)
    }
    func windowDidResignMain(_ notification: Notification) {
        view.rootView.updateSelectedColor(isMain: false)
    }
    func windowDidEnterFullScreen(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: AppDelegate.isFullscreenKey)
        updateDocumentFromWindow()
        view.update()
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: AppDelegate.isFullscreenKey)
        updateDocumentFromWindow()
        view.update()
    }
    func windowWillBeginSheet(_ notification: Notification) {
        view.rootAction.stopAllEvents()
        view.draw()
    }
    func windowDidEndSheet(_ notification: Notification) {
        updateDocumentFromWindow()
    }
    func windowDidResignKey(_ notification: Notification) {
        view.rootAction.stopAllEvents(isEnableText: false)
        view.rootView.endSeqencer()
    }
    func updateDocumentFromWindow() {
        view.rootAction.stopAllEvents(isEnableText: false)
        view.rootView.cursorPoint = view.screenPointFromCursor.my
        view.rootView.updateTextCursor()
    }
    
    private var isShownFileMenu = false, isShownEditMenu = false
    func menuWillOpen(_ menu: NSMenu) {
        if menu == fileMenu {
            isShownFileMenu = true
            view.isEnableMenuCommand = isShownFileMenu || isShownEditMenu
        } else if menu == editMenu {
            isShownEditMenu = true
            view.isEnableMenuCommand = isShownFileMenu || isShownEditMenu
        }
    }
    func menuDidClose(_ menu: NSMenu) {
        if menu == fileMenu {
            isShownFileMenu = false
            view.isEnableMenuCommand = isShownFileMenu || isShownEditMenu
        } else if menu == editMenu {
            isShownEditMenu = false
            view.isEnableMenuCommand = isShownFileMenu || isShownEditMenu
        }
    }
    
    weak var acknowledgmentsPanel: NSPanel?
    @objc func showAcknowledgments(_ sender: Any) {
        guard acknowledgmentsPanel == nil else {
            acknowledgmentsPanel?.makeKeyAndOrderFront(nil)
            return
        }
        let url = Bundle.main.url(forResource: "Acknowledgments",
                                  withExtension: "txt")!
        let string = try! String(contentsOf: url, encoding: .utf8)
        acknowledgmentsPanel = AppDelegate.makePanel(from: string, title: "Acknowledgments".localized)
    }
    
    static func makePanel(from string: String, title: String) -> NSPanel {
        let nsFrame = NSRect(x: 0, y: 0, width: 550, height: 620)
        let nsTextView = NSTextView(frame: nsFrame)
        nsTextView.string = string
        nsTextView.isEditable = false
        nsTextView.autoresizingMask = [.width, .height, .minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        let nsScrollView = NSScrollView(frame: nsFrame)
        nsScrollView.hasVerticalScroller = true
        nsScrollView.documentView = nsTextView
        let nsViewController = NSViewController()
        nsViewController.view = nsScrollView
        
        let nsPanel = NSPanel(contentViewController: nsViewController)
        nsPanel.collectionBehavior = .fullScreenPrimary
        nsPanel.hidesOnDeactivate = false
        nsPanel.title = title
        nsPanel.center()
        nsPanel.makeKeyAndOrderFront(nil)
        nsScrollView.flashScrollers()
        
        return nsPanel
    }
}
private extension NSMenu {
    @discardableResult
    func addItem(withTitle string: String,
                 action selector: AppKit.Selector?,
                 keyEquivalent charCode: String = "",
                 modifierFlags: NSEvent.ModifierFlags = []) -> NSMenuItem {
        let item = NSMenuItem(title: string, action: selector,
                              keyEquivalent: charCode)
        if !modifierFlags.isEmpty {
            item.keyEquivalentModifierMask = modifierFlags
        }
        addItem(item)
        return item
    }
}

final class SubMTKView: MTKView, MTKViewDelegate,
                        @preconcurrency NSTextInputClient, NSMenuItemValidation, NSMenuDelegate {
    static let enabledAnimationKey = "enabledAnimation"
    static let isHiddenActionListKey = "isHiddenActionList"
    static let isShownTrackpadAlternativeKey = "isShownTrackpadAlternative"
    private(set) var rootAction: RootAction
    private(set) var rootView: RootView
    let renderstate = Renderstate.sampleCount4!
    
    var isShownDebug = false
    var isShownClock = false
    private var updateDebugCount = 0
    private let debugNode = Node(attitude: Attitude(position: Point(5, 5)),
                                 fillType: .color(.content))
    
    private var actionNode: Node?
    var isHiddenActionList = true {
        didSet {
            guard isHiddenActionList != oldValue else { return }
            updateActionList()
            if isShownTrackpadAlternative {
                updateTrackpadAlternativePositions()
            }
        }
    }
    private func makeActionNode() -> Node {
        let actionNode = ActionList.default.node()
        let b = rootView.screenBounds
        let w = b.maxX - (actionNode.bounds?.maxX ?? 0)
        let h = b.midY - (actionNode.bounds?.midY ?? 0)
        actionNode.attitude.position = Point(w, h)
        return actionNode
    }
    private func updateActionList() {
        if isHiddenActionList {
            actionNode = nil
        } else if actionNode == nil {
            actionNode = makeActionNode()
        }
        update()
    }
    
    func update() {
        needsDisplay = true
    }
    
    required init(url: URL, frame: NSRect = NSRect()) {
        let rootView = RootView(url: url)
        self.rootView = rootView
        self.rootAction = .init(rootView)
        
        super.init(frame: frame, device: Renderer.shared.device)
        delegate = self
        sampleCount = renderstate.sampleCount
        depthStencilPixelFormat = .stencil8
        clearColor = rootView.backgroundColor.mtl
        
        if ColorSpace.default.isHDR {
            colorPixelFormat = Renderer.shared.hdrPixelFormat
            colorspace = Renderer.shared.hdrColorSpace
            (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = true
        } else {
            colorPixelFormat = Renderer.shared.pixelFormat
            colorspace = Renderer.shared.colorSpace
        }
        
        isPaused = true
        enableSetNeedsDisplay = true
        self.allowedTouchTypes = .indirect
        self.wantsRestingTouches = true
        setupRootView()
        
        if !UserDefaults.standard.bool(forKey: SubMTKView.isHiddenActionListKey) {
            isHiddenActionList = false
            updateActionList()
        }
        
        if UserDefaults.standard.bool(forKey: SubMTKView.isShownTrackpadAlternativeKey) {
            isShownTrackpadAlternative = true
            updateTrackpadAlternative()
        }
        
        updateWithAppearance()
    }
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func cancelTasks() {
        scrollTimer?.cancel()
        scrollTimer = nil
        pinchTimer?.cancel()
        pinchTimer = nil
        rootAction.cancelTasks()
    }
    
    override func viewDidChangeEffectiveAppearance() {
        updateWithAppearance()
    }
    var enabledAppearance = false {
        didSet {
            guard enabledAppearance != oldValue else { return }
            updateWithAppearance()
        }
    }
    func updateWithAppearance() {
        if enabledAppearance {
            Appearance.current
                = NSApp.effectiveAppearance.name == .darkAqua ? .dark : .light
            
            window?.invalidateCursorRects(for: self)
            addCursorRect(bounds, cursor: Cursor.current.ns)
            
            switch Appearance.current {
            case .light:
                if layer?.filters != nil {
                    layer?.filters = nil
                }
            case .dark:
                 layer?.filters = SubMTKView.darkFilters()
                // change edit lightness
                // export
            }
        } else {
            if layer?.filters != nil {
                layer?.filters = nil
            }
        }
    }
    static func darkFilters() -> [CIFilter] {
        if let invertFilter = CIFilter(name: "CIColorInvert"),
           let gammaFilter = CIFilter(name: "CIGammaAdjust"),
           let brightnessFilter = CIFilter(name: "CIColorControls"),
           let hueFilter = CIFilter(name: "CIHueAdjust") {
            
            gammaFilter.setValue(1.75, forKey: "inputPower")
            brightnessFilter.setValue(0.02, forKey: "inputBrightness")
            hueFilter.setValue(Double.pi, forKey: "inputAngle")
            
            return [invertFilter, gammaFilter, brightnessFilter, hueFilter]
        } else {
            return []
        }
    }
    
    func setupRootView() {
        rootView.backgroundColorNotifications.append { [weak self] (_, backgroundColor) in
            self?.clearColor = backgroundColor.mtl
            self?.update()
        }
        rootView.cursorNotifications.append { [weak self] (_, cursor) in
            guard let self else { return }
            self.window?.invalidateCursorRects(for: self)
            self.addCursorRect(self.bounds, cursor: cursor.ns)
            Cursor.current = cursor
        }
        rootView.povNotifications.append { [weak self] (_, _) in
            guard let self else { return }
            if !self.isHiddenActionList {
                self.updateActionList()
            }
            self.update()
        }
        rootView.node.allChildrenAndSelf { $0.owner = self }
        
        rootView.cursorPoint = clippedScreenPointFromCursor.my
    }
    
    var isShownTrackpadAlternative = false {
        didSet {
            guard isShownTrackpadAlternative != oldValue else { return }
            updateTrackpadAlternative()
        }
    }
    private var trackpadView: NSView?,
                lookUpButton: NSButton?,
                scrollButton: NSButton?,
                zoomButton: NSButton?,
                rotateButton: NSButton?
    func updateTrackpadAlternative() {
        if isShownTrackpadAlternative {
            let trackpadView = SubNSTrackpadView(frame: NSRect())
            let lookUpButton = SubNSButton(frame: NSRect(),
                                           .lookUp) { [weak self] (event, dp) in
                guard let self else { return }
                if event.phase == .began,
                   let r = self.rootView.selections
                    .first(where: { self.rootView.worldBounds.intersects($0.rect) })?.rect {
                    
                    let p = r.centerPoint
                    let sp = self.rootView.convertWorldToScreen(p)
                    self.rootAction.inputKey(with: self.inputKeyEventWith(at: sp, .threeFingersTap, .began))
                    self.rootAction.inputKey(with: self.inputKeyEventWith(at: sp, .threeFingersTap, .ended))
                }
            }
            trackpadView.addSubview(lookUpButton)
            self.lookUpButton = lookUpButton
            
            let scrollButton = SubNSButton(frame: NSRect(),
                                           .scroll) { [weak self] (event, dp) in
                guard let self else { return }
                let nEvent = ScrollEvent(screenPoint: self.rootView.screenBounds.centerPoint,
                                         time: event.time,
                                         scrollDeltaPoint: Point(dp.x, -dp.y) * 2,
                                         phase: event.phase,
                                         touchPhase: nil,
                                         momentumPhase: nil)
                self.rootAction.scroll(with: nEvent)
            }
            trackpadView.addSubview(scrollButton)
            self.scrollButton = scrollButton
            
            let zoomButton = SubNSButton(frame: NSRect(),
                                         .zoom) { [weak self] (event, dp) in
                guard let self else { return }
                let nEvent = PinchEvent(screenPoint: self.rootView.screenBounds.centerPoint,
                                        time: event.time,
                                        magnification: -dp.y / 100,
                                        phase: event.phase)
                self.rootAction.pinch(with: nEvent)
            }
            trackpadView.addSubview(zoomButton)
            self.zoomButton = zoomButton
            
            let rotateButton = SubNSButton(frame: NSRect(),
                                           .rotate) { [weak self] (event, dp) in
                guard let self else { return }
                let nEvent = RotateEvent(screenPoint: self.rootView.screenBounds.centerPoint,
                                         time: event.time,
                                         rotationQuantity: -dp.x / 10,
                                         phase: event.phase)
                self.rootAction.rotate(with: nEvent)
            }
            trackpadView.addSubview(rotateButton)
            self.rotateButton = rotateButton
            
            addSubview(trackpadView)
            self.trackpadView = trackpadView
            
            updateTrackpadAlternativePositions()
        } else {
            trackpadView?.removeFromSuperview()
            lookUpButton?.removeFromSuperview()
            scrollButton?.removeFromSuperview()
            zoomButton?.removeFromSuperview()
            rotateButton?.removeFromSuperview()
        }
    }
    func updateTrackpadAlternativePositions() {
        let aw = max(actionNode?.transformedBounds?.cg.width ?? 0, 150)
        let w: CGFloat = 40.0, padding: CGFloat = 4.0
        let lookUpSize = NSSize(width: w, height: 40)
        let scrollSize = NSSize(width: w, height: 40)
        let zoomSize = NSSize(width: w, height: 100)
        let rotateSize = NSSize(width: w, height: 40)
        let h = lookUpSize.height + scrollSize.height + zoomSize.height + rotateSize.height + padding * 5
        let b = bounds
        
        lookUpButton?.frame = NSRect(x: padding,
                                     y: padding * 4 + rotateSize.height + zoomSize.height + scrollSize.height,
                                   width: lookUpSize.width,
                                   height: lookUpSize.height)
        scrollButton?.frame = NSRect(x: padding,
                                     y: padding * 3 + rotateSize.height + zoomSize.height,
                                   width: scrollSize.width,
                                   height: scrollSize.height)
        zoomButton?.frame = NSRect(x: padding,
                                   y: padding * 2 + rotateSize.height,
                                   width: zoomSize.width,
                                   height: zoomSize.height)
        rotateButton?.frame = NSRect(x: padding,
                                   y: padding,
                                   width: rotateSize.width,
                                   height: rotateSize.height)
        trackpadView?.frame = NSRect(x: b.width - aw - w - padding * 2,
                                     y: b.midY - h / 2,
                                     width: w + padding * 2,
                                     height: h)
    }
    
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }
    override func resignFirstResponder() -> Bool { true }
    
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: rootView.cursor.ns)
    }
    
    var isEnableMenuCommand = false {
        didSet {
            guard isEnableMenuCommand != oldValue else { return }
            rootView.isShownLastEditedSheet = isEnableMenuCommand
            rootView.isNoneCursor = isEnableMenuCommand
        }
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(SubMTKView.importDocument(_:)):
            return rootView.isSelectedNoneCursor
            
        case #selector(SubMTKView.exportAsImage(_:)):
            return rootView.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsImage4K(_:)):
            return rootView.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsPDF(_:)):
            return rootView.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsGIF(_:)):
            return rootView.isSelectedNoneCursor
            
        case #selector(SubMTKView.exportAsMovie(_:)):
            return rootView.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsMovie4K(_:)):
            return rootView.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsSound(_:)):
            return rootView.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsLinearPCM(_:)):
            return rootView.isSelectedNoneCursor
            
        case #selector(SubMTKView.exportAsDocument(_:)):
            return rootView.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsDocumentWithHistory(_:)):
            return rootView.isSelectedNoneCursor
            
        case #selector(SubMTKView.clearHistory(_:)):
            return rootView.isSelectedNoneCursor
            
        case #selector(SubMTKView.undo(_:)):
            if isEnableMenuCommand {
                if rootView.isEditingSheet {
                    if rootView.isSelectedNoneCursor {
                        return rootView.selectedSheetViewNoneCursor?.history.isCanUndo ?? false
                    }
                } else {
                    return rootView.history.isCanUndo
                }
            }
            return false
        case #selector(SubMTKView.redo(_:)):
            if isEnableMenuCommand {
                if rootView.isEditingSheet {
                    if rootView.isSelectedNoneCursor {
                        return rootView.selectedSheetViewNoneCursor?.history.isCanRedo ?? false
                    }
                } else {
                    return rootView.history.isCanRedo
                }
            }
            return false
        case #selector(SubMTKView.cut(_:)):
            return isEnableMenuCommand
                && rootView.isSelectedNoneCursor && rootView.isSelectedOnlyNoneCursor
        case #selector(SubMTKView.copy(_:)):
            return isEnableMenuCommand
                && rootView.isSelectedNoneCursor && rootView.isSelectedOnlyNoneCursor
        case #selector(SubMTKView.paste(_:)):
            return if isEnableMenuCommand
                && rootView.isSelectedNoneCursor {
                switch Pasteboard.shared.copiedObjects.first {
                case .picture, .planesValue: rootView.isEditingSheet
                case .copiedSheetsValue: !rootView.isEditingSheet
                default: false
                }
            } else {
                false
            }
        case #selector(SubMTKView.find(_:)):
            return isEnableMenuCommand && rootView.isEditingSheet
                && rootView.isSelectedNoneCursor && rootView.isSelectedText
        case #selector(SubMTKView.changeToDraft(_:)):
            return isEnableMenuCommand && rootView.isEditingSheet
                && rootView.isSelectedNoneCursor
                && !(rootView.selectedSheetViewNoneCursor?.model.picture.isEmpty ?? true)
        case #selector(SubMTKView.cutDraft(_:)):
            return isEnableMenuCommand && rootView.isEditingSheet
                && rootView.isSelectedNoneCursor
                && !(rootView.selectedSheetViewNoneCursor?.model.draftPicture.isEmpty ?? true)
        case #selector(SubMTKView.makeFaces(_:)):
            return isEnableMenuCommand && rootView.isEditingSheet
                && rootView.isSelectedNoneCursor
                && !(rootView.selectedSheetViewNoneCursor?.model.picture.lines.isEmpty ?? true)
        case #selector(SubMTKView.cutFaces(_:)):
            return isEnableMenuCommand && rootView.isEditingSheet
                && rootView.isSelectedNoneCursor
                && !(rootView.selectedSheetViewNoneCursor?.model.picture.planes.isEmpty ?? true)
        case #selector(SubMTKView.changeToVerticalText(_:)):
            return isEnableMenuCommand && rootView.isEditingSheet
                && rootView.isSelectedNoneCursor && rootView.isSelectedText
        case #selector(SubMTKView.changeToHorizontalText(_:)):
            return isEnableMenuCommand && rootView.isEditingSheet
                && rootView.isSelectedNoneCursor && rootView.isSelectedText
        
        case #selector(SubMTKView.shownActionList(_:)):
            menuItem.state = !isHiddenActionList ? .on : .off
        case #selector(SubMTKView.hiddenActionList(_:)):
            menuItem.state = isHiddenActionList ? .on : .off
            
        case #selector(SubMTKView.shownTrackpadAlternative(_:)):
            menuItem.state = isShownTrackpadAlternative ? .on : .off
        case #selector(SubMTKView.hiddenTrackpadAlternative(_:)):
            menuItem.state = !isShownTrackpadAlternative ? .on : .off
            
        default:
            break
        }
        return true
    }
    
    @objc func clearHistoryDatabase(_ sender: Any) {
        Task { @MainActor in
            let result = await rootView.node
                .show(message: "Do you want to clear root history?".localized,
                      infomation: "You can’t undo this action. \nRoot history is what is used in \"Undo\", \"Redo\" or \"Select Version\" when in root operation, and if you clear it, you will not be able to return to the previous work.".localized,
                      okTitle: "Clear Root History".localized,
                      isSaftyCheck: true)
            switch result {
            case .ok:
                let progressPanel = ProgressPanel(message: "Clearing Root History".localized)
                self.rootView.node.show(progressPanel)
                let task = Task.detached(priority: .high) {
                    await self.rootView.clearHistory { (progress, isStop) in
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
                    }
                }
                progressPanel.cancelHandler = { task.cancel() }
            case .cancel: break
            }
        }
    }
    
    func replacingDatabase(from url: URL) {
        @Sendable func replace(to toURL: URL, progressHandler: (Double, inout Bool) -> ()) throws {
            var stop = false
            
            progressHandler(0.5, &stop)
            if stop { return }
            
            guard toURL != url else { throw URL.readError }
            let fm = FileManager.default
            if fm.fileExists(atPath: toURL.path) {
                try fm.trashItem(at: toURL, resultingItemURL: nil)
            }
            try fm.copyItem(at: url, to: toURL)
            
            progressHandler(1, &stop)
            if stop { return }
        }
        
        rootView.syncSave()
        
        let toURL = rootView.model.url
        
        let progressPanel = ProgressPanel(message: String(format: "Replacing %@".localized, System.dataName))
        rootView.node.show(progressPanel)
        let task = Task.detached(priority: .high) {
            do {
                try replace(to: toURL) { (progress, isStop) in
                    if Task.isCancelled {
                        isStop = true
                        return
                    }
                    Task { @MainActor in
                        progressPanel.progress = progress
                    }
                }
                Task { @MainActor in
                    self.updateWithURL()
                    progressPanel.closePanel()
                }
            } catch {
                Task { @MainActor in
                    self.rootView.node.show(error)
                    self.updateWithURL()
                    progressPanel.closePanel()
                }
            }
        }
        progressPanel.cancelHandler = { task.cancel() }
    }
    func replaceDatabase(from url: URL) {
        Task { @MainActor in
            let result = await rootView.node
                .show(message: String(format: "Do you want to replace %@?".localized, System.dataName),
                      infomation: String(format: "You can’t undo this action. \n%1$@ is all the data written to this %2$@, if you replace %1$@ with new %1$@, all old %1$@ will be moved to the Trash.".localized, System.dataName, System.appName),
                      okTitle: String(format: "Replace %@".localized, System.dataName),
                      isSaftyCheck: true)
            switch result {
            case .ok: replacingDatabase(from: url)
            case .cancel: break
            }
        }
    }
    @objc func replaceDatabase(_ sender: Any) {
        Task { @MainActor in
            let result = await rootView.node
                .show(message: String(format: "Do you want to replace %@?".localized, System.dataName),
                      infomation: String(format: "You can’t undo this action. \n%1$@ is all the data written to this %2$@, if you replace %1$@ with new %1$@, all old %1$@ will be moved to the Trash.".localized, System.dataName, System.appName),
                      okTitle: String(format: "Replace %@...".localized, System.dataName),
                      isSaftyCheck: rootView.model.url.allFileSize > 20*1024*1024)
            switch result {
            case .ok:
                let loadResult = await URL.load(prompt: "Replace".localized,
                                                fileTypes: [Document.FileType.rasendata,
                                                            Document.FileType.sksdata])
                switch loadResult {
                case .complete(let ioResults):
                    replacingDatabase(from: ioResults[0].url)
                case .cancel: break
                }
            case .cancel: break
            }
        }
    }
    
    @objc func exportDatabase(_ sender: Any) {
        Task { @MainActor in
            let url = rootView.model.url
            let result = await URL.export(name: "User", fileType: Document.FileType.rasendata,
                                          fileSizeHandler: { url.allFileSize })
            switch result {
            case .complete(let ioResult):
                rootView.syncSave()
                
                @Sendable func export(progressHandler: @Sendable (Double, inout Bool) -> ()) async throws {
                    var stop = false
                    
                    progressHandler(0.5, &stop)
                    if stop { return }
                    
                    guard url != ioResult.url else { throw URL.readError }
                    let fm = FileManager.default
                    if fm.fileExists(atPath: ioResult.url.path) {
                        try fm.removeItem(at: ioResult.url)
                    }
                    if fm.fileExists(atPath: url.path) {
                        try fm.copyItem(at: url, to: ioResult.url)
                    } else {
                        try fm.createDirectory(at: ioResult.url,
                                               withIntermediateDirectories: false)
                    }
                    
                    try ioResult.setAttributes()
                    
                    progressHandler(1, &stop)
                    if stop { return }
                }
                
                let progressPanel = ProgressPanel(message: String(format: "Exporting %@".localized, System.dataName))
                rootView.node.show(progressPanel)
                let task = Task.detached(priority: .high) {
                    do {
                        try await export { (progress, isStop) in
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
                        }
                    } catch {
                        Task { @MainActor in
                            self.rootView.node.show(error)
                            progressPanel.closePanel()
                        }
                    }
                }
                progressPanel.cancelHandler = { task.cancel() }
            case .cancel: break
            }
        }
    }
    
    @objc func resetDatabase(_ sender: Any) {
        Task { @MainActor in
            let result = await rootView.node
                .show(message: String(format: "Do you want to reset the %@?".localized, System.dataName),
                      infomation: String(format: "You can’t undo this action. \n%1$@ is all the data written to this %2$@, if you reset %1$@, all %1$@ will be moved to the Trash.".localized, System.dataName, System.appName),
                      okTitle: String(format: "Reset %@".localized, System.dataName),
                      isSaftyCheck: rootView.model.url.allFileSize > 20*1024*1024)
            switch result {
            case .ok:
                @Sendable func reset(in url: URL, progressHandler: (Double, inout Bool) -> ()) throws {
                    var stop = false
                    
                    progressHandler(0.5, &stop)
                    if stop { return }
                    
                    let fm = FileManager.default
                    if fm.fileExists(atPath: url.path) {
                        try fm.trashItem(at: url, resultingItemURL: nil)
                    }
                    
                    progressHandler(1, &stop)
                    if stop { return }
                }
                
                rootView.syncSave()
                
                let url = rootView.model.url
                
                let progressPanel = ProgressPanel(message: String(format: "Resetting %@".localized, System.dataName))
                self.rootView.node.show(progressPanel)
                let task = Task.detached(priority: .high) {
                    do {
                        try reset(in: url) { (progress, isStop) in
                            if Task.isCancelled {
                                isStop = true
                                return
                            }
                            Task { @MainActor in
                                progressPanel.progress = progress
                            }
                        }
                        Task { @MainActor in
                            self.updateWithURL()
                            progressPanel.closePanel()
                        }
                    } catch {
                        Task { @MainActor in
                            self.rootView.node.show(error)
                            self.updateWithURL()
                            progressPanel.closePanel()
                        }
                    }
                }
                progressPanel.cancelHandler = { task.cancel() }
            case .cancel: break
            }
        }
    }
    
    @objc func shownActionList(_ sender: Any) {
        UserDefaults.standard.set(false, forKey: SubMTKView.isHiddenActionListKey)
        isHiddenActionList = false
    }
    @objc func hiddenActionList(_ sender: Any) {
        UserDefaults.standard.set(true, forKey: SubMTKView.isHiddenActionListKey)
        isHiddenActionList = true
    }
    
    @objc func shownTrackpadAlternative(_ sender: Any) {
        UserDefaults.standard.set(true, forKey: SubMTKView.isShownTrackpadAlternativeKey)
        isShownTrackpadAlternative = true
    }
    @objc func hiddenTrackpadAlternative(_ sender: Any) {
        UserDefaults.standard.set(false, forKey: SubMTKView.isShownTrackpadAlternativeKey)
        isShownTrackpadAlternative = false
    }
    
    @objc func importDocument(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ImportAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    
    @objc func exportAsImage(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAsImageAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func exportAsImage4K(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAs4KImageAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func exportAsPDF(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAsPDFAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func exportAsGIF(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAsGIFAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func exportAsMovie(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAsMovieAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func exportAsMovie4K(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAs4KMovieAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func exportAsSound(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAsSoundAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func exportAsLinearPCM(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAsLinearPCMAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    
    @objc func exportAsDocument(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAsDocumentAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func exportAsDocumentWithHistory(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ExportAsDocumentWithHistoryAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    
    @objc func clearHistory(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ClearHistoryAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    
    @objc func undo(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = UndoAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func redo(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = RedoAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func cut(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = CutAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func copy(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = CopyAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func paste(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = PasteAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func find(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = FindAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func changeToDraft(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ChangeToDraftAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func cutDraft(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = CutDraftAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func makeFaces(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = MakeFacesAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func cutFaces(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = CutFacesAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func changeToVerticalText(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ChangeToVerticalTextAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    @objc func changeToHorizontalText(_ sender: Any) {
        rootView.isNoneCursor = true
        let action = ChangeToHorizontalTextAction(rootAction)
        action.flow(with: inputKeyEventWith(.began))
        Sleep.start()
        action.flow(with: inputKeyEventWith(.ended))
        rootView.isNoneCursor = false
    }
    
//    @objc func startDictation(_ sender: Any) {
//    }
//    @objc func orderFrontCharacterPalette(_ sender: Any) {
//    }
    
    func updateWithURL() {
        rootView = .init(url: rootView.model.url)
        setupRootView()
        do {
            try rootView.restoreDatabase()
        } catch {
            rootView.node.show(error)
        }
        rootView.screenBounds = bounds.my
        rootView.drawableSize = drawableSize.my
        clearColor = rootView.backgroundColor.mtl
        draw()
    }
    
    func draw(in view: MTKView) {}
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        rootView.screenBounds = bounds.my
        rootView.drawableSize = size.my
        
        if !isHiddenActionList {
            func update(_ node: Node) {
                let b = rootView.screenBounds
                let w = b.maxX - (node.bounds?.maxX ?? 0)
                let h = b.midY - (node.bounds?.midY ?? 0)
                node.attitude.position = Point(w, h)
            }
            if let actionNode {
                update(actionNode)
            }
        }
        if isShownTrackpadAlternative {
            updateTrackpadAlternativePositions()
        }
        
        update()
    }
    
    var viewportBounds: Rect {
        Rect(x: 0, y: 0,
             width: Double(drawableSize.width),
             height: Double(drawableSize.height))
    }
    func viewportScale() -> Double {
        return rootView.worldToViewportTransform.absXScale
            * rootView.viewportToScreenTransform.absXScale
            * Double(drawableSize.width / self.bounds.width)
    }
    func viewportBounds(from transform: Transform, bounds: Rect) -> Rect {
        let dr = Rect(x: 0, y: 0,
                      width: Double(drawableSize.width),
                      height: Double(drawableSize.height))
        let scale = Double(drawableSize.width / self.bounds.width)
        let st = transform
            * rootView.viewportToScreenTransform
            * Transform(translationX: 0,
                        y: -rootView.screenBounds.height)
            * Transform(scaleX: scale, y: -scale)
        return dr.intersection(bounds * st) ?? dr
    }
    
    func screenPoint(with event: NSEvent) -> NSPoint {
        convertToLayer(convert(event.locationInWindow, from: nil))
    }
    var screenPointFromCursor: NSPoint {
        guard let window = window else {
            return NSPoint()
        }
        let windowPoint = window.mouseLocationOutsideOfEventStream
        return convertToLayer(convert(windowPoint, from: nil))
    }
    var clippedScreenPointFromCursor: NSPoint {
        guard let window = window else {
            return NSPoint()
        }
        let windowPoint = window.mouseLocationOutsideOfEventStream
        let b = NSRect(origin: NSPoint(), size: window.frame.size)
        if b.contains(windowPoint) {
            return convertToLayer(convert(windowPoint, from: nil))
        } else {
            let wp = NSPoint(x: b.midX, y: b.midY)
            return convertToLayer(convert(wp, from: nil))
        }
    }
    func convertFromTopScreen(_ p: NSPoint) -> NSPoint {
        guard let window = window else {
            return NSPoint()
        }
        let windowPoint = window
            .convertFromScreen(NSRect(origin: p, size: NSSize())).origin
        return convertToLayer(convert(windowPoint, from: nil))
    }
    func convertToTopScreen(_ r: NSRect) -> NSRect {
        guard let window = window else {
            return NSRect()
        }
        return window.convertToScreen(convert(convertFromLayer(r), to: nil))
    }
    func convertToTopScreen(_ p: NSPoint) -> NSPoint {
        convertToTopScreen(NSRect(origin: p, size: CGSize())).origin
    }
    
    override func mouseEntered(with event: NSEvent) {}
    override func mouseExited(with event: NSEvent) {
        rootAction.stopScrollEvent()
    }
    private var trackingArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = self.trackingArea {
            removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(rect: bounds,
                                          options: [.mouseEnteredAndExited,
                                                    .mouseMoved,
                                                    .activeWhenFirstResponder],
                                          owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
    
    func dragEventWith(indicate nsEvent: NSEvent) -> DragEvent {
        DragEvent(screenPoint: screenPoint(with: nsEvent).my,
                  time: nsEvent.timestamp,
                  pressure: 1, isTablet: nsEvent.subtype == .tabletPoint, phase: .changed)
    }
    func dragEventWith(_ nsEvent: NSEvent, _ phase: Phase) -> DragEvent {
        DragEvent(screenPoint: screenPoint(with: nsEvent).my,
                  time: nsEvent.timestamp,
                  pressure: Double(nsEvent.pressure),
                  isTablet: nsEvent.subtype == .tabletPoint, phase: phase)
    }
    func pinchEventWith(_ nsEvent: NSEvent, _ phase: Phase) -> PinchEvent {
        PinchEvent(screenPoint: screenPoint(with: nsEvent).my,
                   time: nsEvent.timestamp,
                   magnification: Double(nsEvent.magnification), phase: phase)
    }
    func scrollEventWith(_ nsEvent: NSEvent, _ phase: Phase,
                         touchPhase: Phase?,
                         momentumPhase: Phase?) -> ScrollEvent {
        let sdp = NSPoint(x: nsEvent.scrollingDeltaX,
                          y: -nsEvent.scrollingDeltaY).my
        let nsdp = Point(sdp.x.clipped(min: -500, max: 500),
                         sdp.y.clipped(min: -500, max: 500))
        return ScrollEvent(screenPoint: screenPoint(with: nsEvent).my,
                           time: nsEvent.timestamp,
                           scrollDeltaPoint: nsdp,
                           phase: phase,
                           touchPhase: touchPhase,
                           momentumPhase: momentumPhase)
    }
    func rotateEventWith(_ nsEvent: NSEvent,
                         _ phase: Phase) -> RotateEvent {
        RotateEvent(screenPoint: screenPoint(with: nsEvent).my,
                    time: nsEvent.timestamp,
                    rotationQuantity: Double(nsEvent.rotation), phase: phase)
    }
    func inputKeyEventWith(_ phase: Phase) -> InputKeyEvent {
        return InputKeyEvent(screenPoint: screenPointFromCursor.my,
                             time: ProcessInfo.processInfo.systemUptime,
                             pressure: 1, phase: phase, isRepeat: false,
                             inputKeyType: .click)
    }
    func inputKeyEventWith(at sp: Point, _ keyType: InputKeyType = .click,
                           _ phase: Phase) -> InputKeyEvent {
        InputKeyEvent(screenPoint: sp,
                      time: ProcessInfo.processInfo.systemUptime,
                      pressure: 1, phase: phase, isRepeat: false,
                      inputKeyType: keyType)
    }
    func inputKeyEventWith(_ nsEvent: NSEvent, _ keyType: InputKeyType,
                           isRepeat: Bool = false,
                           _ phase: Phase) -> InputKeyEvent {
        InputKeyEvent(screenPoint: screenPointFromCursor.my,
                      time: nsEvent.timestamp,
                      pressure: 1, phase: phase, isRepeat: isRepeat,
                      inputKeyType: keyType)
    }
    func inputKeyEventWith(drag nsEvent: NSEvent,
                           _ phase: Phase) -> InputKeyEvent {
        InputKeyEvent(screenPoint: screenPoint(with: nsEvent).my,
                      time: nsEvent.timestamp,
                      pressure: Double(nsEvent.pressure),
                      phase: phase, isRepeat: false,
                      inputKeyType: .click)
    }
    func inputKeyEventWith(_ dragEvent: DragEvent,
                           _ phase: Phase) -> InputKeyEvent {
        InputKeyEvent(screenPoint: dragEvent.screenPoint,
                      time: dragEvent.time,
                      pressure: dragEvent.pressure,
                      phase: phase, isRepeat: false,
                      inputKeyType: .click)
    }
    func inputTextEventWith(_ nsEvent: NSEvent, _ keyType: InputKeyType,
                            _ phase: Phase) -> InputTextEvent {
        InputTextEvent(screenPoint: screenPointFromCursor.my,
                       time: nsEvent.timestamp,
                       pressure: 1, phase: phase, isRepeat: nsEvent.isARepeat,
                       inputKeyType: keyType,
                       ns: nsEvent, inputContext: inputContext)
    }
    
    private var isOneFlag = false, oneFlagTime: Double?
    override func flagsChanged(with nsEvent: NSEvent) {
        let oldModifierKeys = rootAction.modifierKeys
        
        rootAction.modifierKeys = nsEvent.modifierKeys
        
        if oldModifierKeys.isEmpty && rootAction.modifierKeys.isOne {
            isOneFlag = true
            oneFlagTime = nsEvent.timestamp
        } else if let oneKey = oldModifierKeys.oneInputKeyTYpe,
                  rootAction.modifierKeys.isEmpty && isOneFlag,
            let oneFlagTime, nsEvent.timestamp - oneFlagTime < 0.175 {
            rootAction.inputKey(with: inputKeyEventWith(nsEvent, oneKey, .began))
            rootAction.inputKey(with: inputKeyEventWith(nsEvent, oneKey, .ended))
            isOneFlag = false
        } else {
            isOneFlag = false
        }
    }
    
    override func mouseMoved(with nsEvent: NSEvent) {
        rootAction.indicate(with: dragEventWith(indicate: nsEvent))
        
        if let oldEvent = rootAction.oldInputKeyEvent,
           let action = rootAction.inputKeyAction {
            
            action.flow(with: inputKeyEventWith(nsEvent, oldEvent.inputKeyType, .changed))
        } else if let beganDragEvent = beganSubDragEvent {
            let nEvent = dragEventWith(nsEvent, .changed)
            if isSubDrag || nEvent.screenPoint.distance(beganDragEvent.screenPoint) > 5 {
                if !isSubDrag {
                    isSubDrag = true
                    rootAction.subDrag(with: beganDragEvent)
                }
                rootAction.subDrag(with: nEvent)
            }
        }
    }
    
    override func keyDown(with nsEvent: NSEvent) {
        isOneFlag = false
        guard let key = nsEvent.key else { return }
        let phase: Phase = nsEvent.isARepeat ? .changed : .began
        if key.isTextEdit
            && !rootAction.modifierKeys.contains(.command)
            && rootAction.modifierKeys != .control
            && rootAction.modifierKeys != [.control, .option]
            && !rootAction.modifierKeys.contains(.function) {
            
            rootAction.inputText(with: inputTextEventWith(nsEvent, key, phase))
        } else {
            rootAction.inputKey(with: inputKeyEventWith(nsEvent, key, isRepeat: nsEvent.isARepeat, phase))
        }
    }
    override func keyUp(with nsEvent: NSEvent) {
        guard let key = nsEvent.key else { return }
        let textEvent = inputTextEventWith(nsEvent, key, .ended)
        if rootAction.oldInputTextKeys.contains(textEvent.inputKeyType) {
            rootAction.inputText(with: textEvent)
        }
        if rootAction.oldInputKeyEvent?.inputKeyType == key {
            rootAction.inputKey(with: inputKeyEventWith(nsEvent, key, .ended))
        }
    }
    
    private var beganDragEvent: DragEvent?,
                oldPressureStage = 0, isDrag = false, isStrongDrag = false,
                firstTime = 0.0, firstP = Point(), isMovedDrag = false
    override func mouseDown(with nsEvent: NSEvent) {
        if beganSwipePosition != nil && nsEvent.subtype != .tabletPoint { return }
        isOneFlag = false
        isDrag = false
        isStrongDrag = false
        let beganDragEvent = dragEventWith(nsEvent, .began)
        self.beganDragEvent = beganDragEvent
        oldPressureStage = 0
        firstTime = beganDragEvent.time
        firstP = beganDragEvent.screenPoint
        isMovedDrag = false
    }
    override func mouseDragged(with nsEvent: NSEvent) {
        guard let beganDragEvent = beganDragEvent else { return }
        isMovedDrag = true
        if !isDrag {
            isDrag = true
            if oldPressureStage == 2 {
                isStrongDrag = true
                rootAction.strongDrag(with: beganDragEvent)
            } else {
                rootAction.drag(with: beganDragEvent)
            }
        }
        if isStrongDrag {
            rootAction.strongDrag(with: dragEventWith(nsEvent, .changed))
        } else {
            rootAction.drag(with: dragEventWith(nsEvent, .changed))
        }
    }
    override func mouseUp(with nsEvent: NSEvent) {
        let endedDragEvent = dragEventWith(nsEvent, .ended)
        if isDrag {
            if isStrongDrag {
                rootAction.strongDrag(with: endedDragEvent)
                isStrongDrag = false
            } else {
                rootAction.drag(with: endedDragEvent)
            }
            isDrag = false
        } else {
            if oldPressureStage >= 2 {
                quickLook(with: nsEvent)
            } else {
                guard let beganDragEvent = beganDragEvent else { return }
                if isMovedDrag {
                    rootAction.drag(with: beganDragEvent)
                    rootAction.drag(with: endedDragEvent)
                } else {
                    rootAction.inputKey(with: inputKeyEventWith(beganDragEvent, .began))
                    Sleep.start()
                    rootAction.inputKey(with: inputKeyEventWith(beganDragEvent, .ended))
                }
            }
        }
        beganDragEvent = nil
    }
    
    override func pressureChange(with event: NSEvent) {
        oldPressureStage = max(event.stage, oldPressureStage)
    }
    
    private var beganSubDragEvent: DragEvent?, isSubDrag = false, isSubTouth = false
    override func rightMouseDown(with nsEvent: NSEvent) {
        isOneFlag = false
        isSubTouth = nsEvent.subtype == .touch
        isSubDrag = false
        let beganDragEvent = dragEventWith(nsEvent, .began)
        self.beganSubDragEvent = beganDragEvent
    }
    override func rightMouseDragged(with nsEvent: NSEvent) {
        guard let beganDragEvent = beganSubDragEvent else { return }
        if !isSubDrag {
            isSubDrag = true
            rootAction.subDrag(with: beganDragEvent)
        }
        rootAction.subDrag(with: dragEventWith(nsEvent, .changed))
    }
    override func rightMouseUp(with nsEvent: NSEvent) {
        let endedDragEvent = dragEventWith(nsEvent, .ended)
        if isSubDrag {
            rootAction.subDrag(with: endedDragEvent)
            isSubDrag = false
        } else {
            guard let beganDragEvent = beganSubDragEvent else { return }
            if beganDragEvent.screenPoint != endedDragEvent.screenPoint {
                rootAction.subDrag(with: beganDragEvent)
                rootAction.subDrag(with: endedDragEvent)
            } else {
                showMenu(nsEvent)
            }
        }
        if isSubTouth {
            oldScrollPosition = nil
        }
        isSubTouth = false
        beganSubDragEvent = nil
    }
    
    private var menuAction: StartExportAction?
    func showMenu(_ nsEvent: NSEvent) {
        guard window?.sheets.isEmpty ?? false else { return }
        guard window?.isMainWindow ?? false else { return }
        
        let event = inputKeyEventWith(drag: nsEvent, .began)
        rootAction.updateLastEditedIntPoint(from: event)
        let menu = NSMenu()
        if menuAction != nil {
            menuAction?.action.end()
        }
        menuAction = StartExportAction(rootAction)
        menuAction?.flow(with: event)
        menu.delegate = self
        menu.addItem(SubNSMenuItem(title: "Import...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ImportAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(SubNSMenuItem(title: "Export as Image...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAsImageAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as 4K Image...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAs4KImageAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as PDF...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAsPDFAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as GIF...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAsGIFAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(SubNSMenuItem(title: "Export as Movie...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAsMovieAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as 4K Movie...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAs4KMovieAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as Sound...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAsSoundAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as Linear PCM...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAsLinearPCMAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(SubNSMenuItem(title: "Export as Document...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAsDocumentAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as Document with History...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ExportAsDocumentWithHistoryAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(SubNSMenuItem(title: "Clear History...".localized, closure: { [weak self] in
            guard let self else { return }
            let action = ClearHistoryAction(self.rootAction)
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .began))
            action.flow(with: self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        
        rootAction.stopAllEvents()
        if rootAction.isPlaying(with: event) {
            rootAction.stopPlaying(with: event)
        }
        NSMenu.popUpContextMenu(menu, with: nsEvent, for: self)
    }
    func menuDidClose(_ menu: NSMenu) {
        menuAction?.action.end()
        menuAction = nil
    }
    
    private var beganMiddleDragEvent: DragEvent?, isMiddleDrag = false
    override func otherMouseDown(with nsEvent: NSEvent) {
        isOneFlag = false
        isMiddleDrag = false
        let beganDragEvent = dragEventWith(nsEvent, .began)
        self.beganMiddleDragEvent = beganDragEvent
    }
    override func otherMouseDragged(with nsEvent: NSEvent) {
        guard let beganDragEvent = beganMiddleDragEvent else { return }
        if !isMiddleDrag {
            isMiddleDrag = true
            rootAction.middleDrag(with: beganDragEvent)
        }
        rootAction.middleDrag(with: dragEventWith(nsEvent, .changed))
    }
    override func otherMouseUp(with nsEvent: NSEvent) {
        let endedDragEvent = dragEventWith(nsEvent, .ended)
        if isMiddleDrag {
            rootAction.middleDrag(with: endedDragEvent)
            isMiddleDrag = false
        } else {
            guard let beganDragEvent = beganSubDragEvent else { return }
            if beganDragEvent.screenPoint != endedDragEvent.screenPoint {
                rootAction.middleDrag(with: beganDragEvent)
                rootAction.middleDrag(with: endedDragEvent)
            }
        }
        beganMiddleDragEvent = nil
    }
    
    let scrollEndSec = 0.1
    private var scrollTask: Task<(), any Error>?
    override func scrollWheel(with nsEvent: NSEvent) {
        guard !isEnabledCustomTrackpad else { return }
        
        func beginEvent() -> Phase {
            if scrollTask != nil {
                scrollTask?.cancel()
                scrollTask = nil
                return .changed
            } else {
                return .began
            }
        }
        func endEvent() {
            scrollTask = Task {
                try await Task.sleep(sec: scrollEndSec)
                try Task.checkCancellation()
                
                var event = scrollEventWith(nsEvent, .ended, touchPhase: nil, momentumPhase: nil)
                event.screenPoint = screenPointFromCursor.my
                event.time += scrollEndSec
                rootAction.scroll(with: event)
                
                scrollTask = nil
            }
        }
        if nsEvent.phase.contains(.began) {
            allScrollPosition = .init()
            rootAction.scroll(with: scrollEventWith(nsEvent, beginEvent(), touchPhase: .began, momentumPhase: nil))
        } else if nsEvent.phase.contains(.ended) {
            rootAction.scroll(with: scrollEventWith(nsEvent, .changed, touchPhase: .ended, momentumPhase: nil))
            endEvent()
        } else if nsEvent.phase.contains(.changed) {
            var event = scrollEventWith(nsEvent, .changed,
                                        touchPhase: .changed,
                                        momentumPhase: nil)
            var dp = event.scrollDeltaPoint
            allScrollPosition += dp
            switch snapScrollType {
            case .x:
                if abs(allScrollPosition.y) < 5 {
                    dp.y = 0
                } else {
                    snapScrollType = .none
                }
            case .y:
                if abs(allScrollPosition.x) < 5 {
                    dp.x = 0
                } else {
                    snapScrollType = .none
                }
            case .none: break
            }
            event.scrollDeltaPoint = dp
            
            rootAction.scroll(with: event)
        } else {
            if nsEvent.momentumPhase.contains(.began) {
                var event = scrollEventWith(nsEvent, beginEvent(),
                                            touchPhase: nil,
                                            momentumPhase: .began)
                var dp = event.scrollDeltaPoint
                switch snapScrollType {
                case .x: dp.y = 0
                case .y: dp.x = 0
                case .none: break
                }
                event.scrollDeltaPoint = dp
                rootAction.scroll(with: event)
            } else if nsEvent.momentumPhase.contains(.ended) {
                var event = scrollEventWith(nsEvent, .changed,
                                            touchPhase: nil,
                                            momentumPhase: .ended)
                var dp = event.scrollDeltaPoint
                switch snapScrollType {
                case .x: dp.y = 0
                case .y: dp.x = 0
                case .none: break
                }
                event.scrollDeltaPoint = dp
                rootAction.scroll(with: event)
                endEvent()
            } else if nsEvent.momentumPhase.contains(.changed) {
                var event = scrollEventWith(nsEvent, .changed,
                                            touchPhase: nil,
                                            momentumPhase: .changed)
                var dp = event.scrollDeltaPoint
                switch snapScrollType {
                case .x: dp.y = 0
                case .y: dp.x = 0
                case .none: break
                }
                event.scrollDeltaPoint = dp
                rootAction.scroll(with: event)
            }
        }
    }
    
    var isEnabledCustomTrackpad = true
    
    var oldTouchPoints = [Int: Point]()
    var touchedIDs = [Int](), beganTouchTime: Double?, oldTouchTime: Double?
    var began2FingersTime: Double?
    var isBeganScroll = false, isFirstChangedScroll = false, beganScrollPosition: Point?, oldScrollPosition: Point?, allScrollPosition = Point()
    var isBeganPinch = false, isFirstChangedPinch = false,beganPinchDistance: Double?, oldPinchDistance: Double?
    var isBeganRotate = false, isFirstChangedRotate = false, beganRotateAngle: Double?, oldRotateAngle: Double?
    var isPrepare3FingersTap = false, isPrepare4FingersTap = false
    var scrollVs = [(dp: Point, time: Double)]()
    var pinchVs = [(d: Double, time: Double)]()
    var lastScrollLength0 = 0.0, lastScrollLength1 = 0.0
    enum  SnapScrollType {
        case none, x, y
    }
    var snapScrollType = SnapScrollType.none
    var lastMagnification = 0.0, preMagnification = 0.0
    var lastRotationQuantity = 0.0
    var isTouchedSubDrag = false
    var isBeganSwipe = false, swipePosition: Point?, beganSwipePosition: Point?
    var began4FingersPosition: Point?
    
    var isMomentumPinch = false, isMomentumScroll = false
    private var scrollTimeValue = 0.0
    private var scrollTimer: (any DispatchSourceTimer)?
    private var pinchTimeValue = 0.0
    private var pinchTimer: (any DispatchSourceTimer)?
    
    func touchPoints(with event: TouchEvent) -> [Int: Point] {
        event.fingers.reduce(into: .init()) {
            $0[$1.key] = .init($1.value.normalizedPosition.x * event.deviceSize.width,
                               $1.value.normalizedPosition.y * event.deviceSize.height)
        }
    }
    static func finger(with touch: NSTouch) -> TouchEvent.Finger {
        let phase: Phase = if touch.phase.contains(.began) {
            .began
        } else if touch.phase.contains(.moved) || touch.phase.contains(.stationary) {
            .changed
        } else {
            .ended
        }
        return .init(normalizedPosition: touch.normalizedPosition.my, phase: phase,
                     id: touch.identity.hash)
    }
    static func fingers(with allTouches: Set<NSTouch>) -> [Int: TouchEvent.Finger] {
        allTouches.reduce(into: .init()) {
            let finger = Self.finger(with: $1)
            $0[finger.id] = finger
        }
    }
    
    override func touchesBegan(with nsEvent: NSEvent) {
        guard let touch = nsEvent.allTouches().first else { return }
        touchesBegan(with: .init(screenPoint: screenPoint(with: nsEvent).my,
                                 time: nsEvent.timestamp, phase: .began,
                                 fingers: Self.fingers(with: nsEvent.allTouches()),
                     deviceSize: touch.deviceSize.my))
    }
    override func touchesMoved(with nsEvent: NSEvent) {
        guard let touch = nsEvent.allTouches().first else { return }
        touchesMoved(with: .init(screenPoint: screenPoint(with: nsEvent).my,
                                 time: nsEvent.timestamp, phase: .changed,
                                 fingers: Self.fingers(with: nsEvent.allTouches()),
                     deviceSize: touch.deviceSize.my))
    }
    override func touchesEnded(with nsEvent: NSEvent) {
        guard let touch = nsEvent.allTouches().first else { return }
        touchesEnded(with: .init(screenPoint: screenPoint(with: nsEvent).my,
                                 time: nsEvent.timestamp, phase: .ended,
                                 fingers: Self.fingers(with: nsEvent.allTouches()),
                     deviceSize: touch.deviceSize.my))
    }
    override func touchesCancelled(with event: NSEvent) {
        touchesEnded(with: event)
    }
    func touchesBegan(with event: TouchEvent) {
        guard isEnabledCustomTrackpad else { return }
        
        if oldTouchPoints.isEmpty {
            beganTouchTime = event.time
            isTouchedSubDrag = false
        }
        
        if isSubDrag {
            isTouchedSubDrag = true
        }
        
        let ps = touchPoints(with: event)
        oldTouchPoints = ps
        
        touchedIDs.removeAll { ps[$0] == nil }
        for id in ps.keys {
            if !touchedIDs.contains(id) {
                touchedIDs.append(id)
            }
        }
        
        oldTouchTime = event.time
        
        beganSwipePosition = nil
        isPrepare3FingersTap = false
        isPrepare4FingersTap = false
        if ps.count == 2 && !isBeganSwipe {
            swipePosition = nil
            began2FingersTime = event.time
            let ps0 = ps[touchedIDs[0]]!, ps1 = ps[touchedIDs[1]]!
            oldPinchDistance = ps0.distance(ps1)
            oldScrollPosition = ps0.mid(ps1)
            oldRotateAngle = ps0.angle(ps1)
            beganPinchDistance = oldPinchDistance
            beganScrollPosition = oldScrollPosition
            beganRotateAngle = oldRotateAngle
            isBeganPinch = false
            isBeganScroll = false
            isBeganRotate = false
            isFirstChangedPinch = false
            isFirstChangedScroll = false
            isFirstChangedRotate = false
            snapScrollType = .none
            lastScrollLength0 = 0
            lastScrollLength1 = 0
            lastMagnification = 0
            preMagnification = 0
            pinchVs = []
            scrollVs = []
        } else if ps.count == 3 && !isBeganScroll && !isBeganPinch && !isBeganRotate {
            oldPinchDistance = nil
            oldScrollPosition = nil
            oldRotateAngle = nil
            beganPinchDistance = nil
            beganScrollPosition = nil
            beganRotateAngle = nil
            
            let ps0 = ps[touchedIDs[0]]!, ps1 = ps[touchedIDs[1]]!, ps2 = ps[touchedIDs[2]]!
            beganSwipePosition = [ps0, ps1, ps2].mean()
            
            isBeganSwipe = false
            swipePosition = Point()
            isPrepare3FingersTap = true
        } else if ps.count == 4 && !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe {
            oldPinchDistance = nil
            oldScrollPosition = nil
            oldRotateAngle = nil
            beganPinchDistance = nil
            beganScrollPosition = nil
            beganRotateAngle = nil
            
            began4FingersPosition = (0 ..< 4).map { ps[touchedIDs[$0]]! }.mean()!
            isPrepare4FingersTap = true
        }
    }
    func touchesMoved(with event: TouchEvent) {
        guard isEnabledCustomTrackpad else { return }
        
        let ps = touchPoints(with: event)
        
        if isTouchedSubDrag || isSubDrag {
            isTouchedSubDrag = true
            endPinch(with: event, enabledMomentum: false)
            endScroll(with: event, enabledMomentum: false)
            endRotate(with: event)
        } else if ps.count >= 2 {
            if touchedIDs.count >= 2,
               let ps0 = ps[touchedIDs[0]],//captureTouchedIDs2
               let ps1 = ps[touchedIDs[1]],
               let ops0 = oldTouchPoints[touchedIDs[0]],
               let ops1 = oldTouchPoints[touchedIDs[1]] {
                
                if let beganPinchDistance, let beganScrollPosition, let beganRotateAngle {
                    let t = (event.time - (began2FingersTime ?? event.time))
                        .clipped(min: 0.1, max: 0.25, newMin: 9, newMax: 3)
                    let pinchDistance = t
                    let scrollDistance = t
                    func scrollLengthAndAngle(fromDelta odp: Point) -> (length: Double, angle: Double) {
                        var dp = odp
                        allScrollPosition += dp
                        switch snapScrollType {
                        case .x:
                            if abs(allScrollPosition.y) < scrollDistance {
                                dp.y = 0
                            } else {
                                snapScrollType = .none
                            }
                        case .y:
                            if abs(allScrollPosition.x) < scrollDistance {
                                dp.x = 0
                            } else {
                                snapScrollType = .none
                            }
                        case .none: break
                        }
                        let angle = dp.angle()
                        let dpl = dp.length() * 3.5
                        let length = dpl < 15 ? dpl : dpl.clipped(min: 15, max: 200,
                                                                  newMin: 15, newMax: 500)
                        return (length, angle)
                    }
                    
                    let nPinchDistance = ps0.distance(ps1)
                    let oldPinchDistance = oldPinchDistance ?? beganPinchDistance
                    let oMagnification = (nPinchDistance - oldPinchDistance) * 0.0125
                    let magnification: Double = if lastMagnification == 0 {
                        oMagnification.signValue * min(abs(oMagnification), 0.001)
                    } else {
                        oMagnification.mid(lastMagnification)
                    }
                    
                    let nScrollPosition = ps0.mid(ps1)
                    let nRotateAngle = ps0.angle(ps1)
                    let isPinchWithAngle = abs(Edge(ops0, ps0).angle(Edge(ops1, ps1))) > .pi / 2
                    let isPinchWithDistance = abs(nPinchDistance - beganPinchDistance) > pinchDistance
                    && isPinchWithAngle
                    let isScrollWithDistance = nScrollPosition.distance(beganScrollPosition) > scrollDistance && !isPinchWithAngle
                    let isRotateWithDistance = nPinchDistance > 120
                    && abs(nRotateAngle.differenceRotation(beganRotateAngle)) > .pi * 0.02
                    if !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe
                        && isPinchWithDistance {
                        
                        isBeganPinch = true
                        
                        cancelScroll(event)
                        cancelPinch(event)
                        
                        let nMagnification = magnification / 2
                        if lastMagnification.sign == magnification.sign {
                            rootAction.pinch(with: .init(screenPoint: event.screenPoint,
                                                         time: oldTouchTime ?? event.time,
                                                         magnification: 0,
                                                         phase: .began))
                            rootAction.pinch(with: .init(screenPoint: event.screenPoint,
                                                         time: event.time,
                                                         magnification: nMagnification,
                                                         phase: .changed))
                            pinchVs = [(0, oldTouchTime ?? event.time), (nMagnification, event.time)]
                        } else {
                            rootAction.pinch(with: .init(screenPoint: event.screenPoint,
                                                         time: event.time,
                                                         magnification: 0,
                                                         phase: .began))
                            pinchVs = [(0, event.time)]
                        }
                        
                        preMagnification = nMagnification
                    } else if isBeganPinch {
                        if ps0 != ops0 || ps1 != ops1 {
                            if isFirstChangedPinch || lastMagnification.sign == magnification.sign {
                                let m = magnification.mid(preMagnification)
                                rootAction.pinch(with: .init(screenPoint: event.screenPoint,
                                                             time: event.time,
                                                             magnification: m,
                                                             phase: .changed))
                                pinchVs.append((m, event.time))
                                preMagnification = magnification
                            } else {
                                isFirstChangedPinch = true
                            }
                        }
                    } else if !(isSubDrag && isSubTouth)
                                && !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe
                                && !isPinchWithDistance && isScrollWithDistance {
                        isBeganScroll = true
                        
                        cancelScroll(event)
                        cancelPinch(event)
                        
                        let dp = nScrollPosition - (oldScrollPosition ?? beganScrollPosition)
                        snapScrollType = min(abs(dp.x), abs(dp.y)) < 3
                        ? (abs(dp.x) > abs(dp.y) ? .x : .y) : .none
                        allScrollPosition = dp
                        
                        let (scrollLength, angle) = scrollLengthAndAngle(fromDelta: dp)
                        let scrollDeltaPoint = Point().movedWith(distance: scrollLength, angle: angle)
                        let sdp = scrollDeltaPoint
                        if abs(Point.differenceAngle(nScrollPosition, oldScrollPosition ?? beganScrollPosition)) < .pi / 2 {
                            rootAction.scroll(with: .init(screenPoint: event.screenPoint,
                                                          time: oldTouchTime ?? event.time,
                                                          scrollDeltaPoint: .init(),
                                                          phase: .began,
                                                          touchPhase: .began,
                                                          momentumPhase: nil))
                            rootAction.scroll(with: .init(screenPoint: event.screenPoint,
                                                          time: event.time,
                                                          scrollDeltaPoint: scrollDeltaPoint,
                                                          phase: .changed,
                                                          touchPhase: .changed,
                                                          momentumPhase: nil))
                            scrollVs = [(.init(), oldTouchTime ?? event.time), (sdp, event.time)]
                        } else {
                            rootAction.scroll(with: .init(screenPoint: event.screenPoint,
                                                          time: event.time,
                                                          scrollDeltaPoint: .init(),
                                                          phase: .began,
                                                          touchPhase: .began,
                                                          momentumPhase: nil))
                            scrollVs = [(.init(), event.time)]
                        }
                        lastScrollLength0 = scrollLength
                        lastScrollLength1 = scrollLength
                    } else if isBeganScroll, let oldScrollPosition {
                        if ps0 != ops0 || ps1 != ops1 {
                            if isFirstChangedScroll || abs(Point.differenceAngle(nScrollPosition, oldScrollPosition)) < .pi / 2 {
                                let (scrollLength, angle) = scrollLengthAndAngle(fromDelta: nScrollPosition - oldScrollPosition)
                                let nScrollLength = (scrollLength + lastScrollLength0) / 2
                                let sdp = Point().movedWith(distance: nScrollLength, angle: angle)
                                rootAction.scroll(with: .init(screenPoint: event.screenPoint,
                                                              time: event.time,
                                                              scrollDeltaPoint: sdp,
                                                              phase: .changed,
                                                              touchPhase: .changed,
                                                              momentumPhase: nil))
                                
                                let nnScrollLength = (scrollLength + lastScrollLength0 * 0.75 + lastScrollLength1 * 0.25) / 2
                                scrollVs.append((Point().movedWith(distance: nnScrollLength, angle: angle),
                                                 event.time))
                                lastScrollLength1 = lastScrollLength0
                                lastScrollLength0 = scrollLength
                            } else {
                                isFirstChangedScroll = true
                            }
                        }
                    } else if !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe
                                && !isPinchWithDistance && !isScrollWithDistance
                                && isRotateWithDistance {
                        isBeganRotate = true
                        
                        cancelScroll(event)
                        cancelPinch(event)
                        
                        rootAction.rotate(with: .init(screenPoint: event.screenPoint,
                                                      time: event.time,
                                                      rotationQuantity: 0,
                                                      phase: .began))
                        lastRotationQuantity = 0
                    } else if isBeganRotate, let oldRotateAngle {
                        if ps0 != ops0 || ps1 != ops1 {
                            let rotationQuantity = nRotateAngle.differenceRotation(oldRotateAngle) * 80
                            if isFirstChangedRotate || lastRotationQuantity.sign == rotationQuantity.sign {
                                rootAction.rotate(with: .init(screenPoint: event.screenPoint,
                                                              time: event.time,
                                                              rotationQuantity: rotationQuantity.mid(lastRotationQuantity),
                                                              phase: .changed))
                                lastRotationQuantity = rotationQuantity
                            } else {
                                isFirstChangedRotate = true
                            }
                        }
                    }
                    self.oldPinchDistance = nPinchDistance
                    self.oldScrollPosition = nScrollPosition
                    self.oldRotateAngle = nRotateAngle
                    lastMagnification = magnification
                }
                
                if ps.count == 3 {
                    if touchedIDs.count == 3,
                       let swipePosition, let beganSwipePosition,
                       let ps0 = ps[touchedIDs[0]],
                       let ops0 = oldTouchPoints[touchedIDs[0]],
                       let ps1 = ps[touchedIDs[1]],
                       let ops1 = oldTouchPoints[touchedIDs[1]],
                       let ps2 = ps[touchedIDs[2]],
                       let ops2 = oldTouchPoints[touchedIDs[2]] {
                        
                        let deltaP = [ps0 - ops0, ps1 - ops1, ps2 - ops2].mean()!
                        if !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe
                            && abs(deltaP.x) > abs(deltaP.y)
                            && ([ps0, ps1, ps2].mean()! - beganSwipePosition).length() > 3 {
                            
                            isBeganSwipe = true
                            isPrepare3FingersTap = false
                            isPrepare4FingersTap = false
                            
                            cancelPinch(event)
                            cancelScroll(event)
                            
                            rootAction.swipe(with: .init(screenPoint: event.screenPoint,
                                                         time: event.time,
                                                         scrollDeltaPoint: Point(),
                                                         phase: .began))
                            self.swipePosition = swipePosition + deltaP
                        } else if isBeganSwipe {
                            if ps0 != ops0 || ps1 != ops1 || ps2 != ops2 {
                                let minD = 4.0, maxD = 10.0, newMaxD = 20.0
                                let absX = abs(deltaP.x), absY = abs(deltaP.y)
                                let sdx = absX < minD ? deltaP.x : deltaP.x.signValue * absX
                                    .clipped(min: minD, max: maxD, newMin: minD, newMax: newMaxD)
                                let sdy = absY < minD ? deltaP.y : deltaP.x.signValue * absY
                                    .clipped(min: minD, max: maxD, newMin: minD, newMax: newMaxD)
                                rootAction.swipe(with: .init(screenPoint: event.screenPoint,
                                                             time: event.time,
                                                             scrollDeltaPoint: .init(sdx, sdy),
                                                             phase: .changed))
                                self.swipePosition = swipePosition + deltaP
                            }
                        } else if !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe {
                            let vs = (0 ..< 3).compactMap { ps[touchedIDs[$0]] }
                            if vs.count == 3 {
                                let np = vs.mean()!
                                if np.distance(beganSwipePosition) > 3 {
                                    isPrepare3FingersTap = false
                                }
                            }
                        }
                    } else if !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe,
                              touchedIDs.count == 3 {
                        cancelPinch(event)
                        cancelScroll(event)
                        
                        let vs = (0 ..< 3).compactMap { ps[touchedIDs[$0]] }
                        if let beganSwipePosition, vs.count == 3 {
                            let np = vs.mean()!
                            if np.distance(beganSwipePosition) > 3 {
                                isPrepare3FingersTap = false
                            }
                        }
                    }
                } else if !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe,
                          ps.count == 4 && touchedIDs.count == 4 {
                    
                    cancelPinch(event)
                    cancelScroll(event)
                    
                    let vs = (0 ..< 4).compactMap { ps[touchedIDs[$0]] }
                    if let began4FingersPosition, vs.count == 4 {
                        let np = vs.mean()!
                        if np.distance(began4FingersPosition) > 3 {
                            isPrepare4FingersTap = false
                        }
                    }
                }
            }
        } else {
            if swipePosition != nil, isBeganSwipe {
                rootAction.swipe(with: .init(screenPoint: event.screenPoint,
                                             time: event.time,
                                             scrollDeltaPoint: Point(),
                                             phase: .ended))
                swipePosition = nil
                isBeganSwipe = false
            }
            
            endPinch(with: event)
            endRotate(with: event)
            endScroll(with: event)
        }
        
        oldTouchPoints = ps
        oldTouchTime = event.time
    }
    func touchesEnded(with event: TouchEvent) {
        guard isEnabledCustomTrackpad else { return }
        
        if isTouchedSubDrag || isSubDrag {
            endPinch(with: event, enabledMomentum: false)
            endScroll(with: event, enabledMomentum: false)
            endRotate(with: event)
            
            oldTouchPoints = [:]
            touchedIDs = []
            beganSwipePosition = nil
            isTouchedSubDrag = false
            return
        }
        
        if !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe && isPrepare3FingersTap {
            if event.isAllEnded, let beganTouchTime, event.time - beganTouchTime < 0.2 {
                var event = InputKeyEvent(screenPoint: event.screenPoint,
                                          time: event.time,
                                          pressure: 1, phase: .began, isRepeat: false,
                                          inputKeyType: .threeFingersTap)
                let action = LookUpAction(rootAction)
                action.flow(with: event)
                Sleep.start()
                event.phase = .ended
                action.flow(with: event)
                isPrepare3FingersTap = false
            }
        } else if !isBeganScroll && !isBeganPinch && !isBeganRotate && !isBeganSwipe && isPrepare4FingersTap {
            if event.isAllEnded, let beganTouchTime, event.time - beganTouchTime < 0.3 {
                var event = InputKeyEvent(screenPoint: event.screenPoint,
                                          time: event.time,
                                          pressure: 1, phase: .began, isRepeat: false,
                                          inputKeyType: .fourFingersTap)
                let action = PlayAction(rootAction)
                action.flow(with: event)
                Sleep.start()
                event.phase = .ended
                action.flow(with: event)
                isPrepare4FingersTap = false
            }
        } else if swipePosition != nil {
            rootAction.swipe(with: .init(screenPoint: event.screenPoint,
                                         time: event.time,
                                         scrollDeltaPoint: Point(),
                                         phase: .ended))
            swipePosition = nil
            isBeganSwipe = false
        }
        
        let fingerCount = event.fingers.filter({ $0.value.phase != .ended }).count
        if fingerCount < 2 {
            endPinch(with: event)
            endRotate(with: event)
            endScroll(with: event)
            if fingerCount == 0 {
                oldTouchPoints = [:]
                touchedIDs = []
            }
        }
        
        touchedIDs.removeAll { event.fingers[$0]?.phase == .ended }
        
        beganSwipePosition = nil
    }
    
    func endPinch(with event: TouchEvent, enabledMomentum: Bool = true,
                  timeInterval: Double = 1 / 60) {
        guard isBeganPinch else { return }
        self.oldPinchDistance = nil
        isBeganPinch = false
        guard pinchVs.count >= 2 && enabledMomentum else {
            rootAction.pinch(with: .init(screenPoint: event.screenPoint,
                                         time: event.time,
                                         magnification: 0,
                                         phase: .ended))
            return
        }
        
        let fpi = pinchVs[..<(pinchVs.count - 1)]
            .lastIndex(where: { event.time - $0.time > 0.05 }) ?? 0
        let lpv = pinchVs.last!
        let t = timeInterval + lpv.time
        
        let sd = pinchVs.last!.d
        let sign = sd < 0 ? -1.0 : 1.0
        let (a, b) = Double.leastSquares(xs: pinchVs[fpi...].map { $0.time },
                                         ys: pinchVs[fpi...].map { abs($0.d) })
        let v = min(a * t + b, 0.35)
        let tv = v / timeInterval
        let minTV = 0.01
        let sv = tv / (tv - minTV)
        if tv.isNaN || v < 0.03 || a == 0 {
            rootAction.pinch(with: .init(screenPoint: event.screenPoint,
                                         time: event.time,
                                         magnification: 0,
                                         phase: .ended))
        } else {
            isMomentumPinch = true
            pinchTimeValue = tv
            pinchTimer = DispatchSource.scheduledTimer(withTimeInterval: timeInterval) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let ntv = self.pinchTimeValue * 0.8
                    self.pinchTimeValue = ntv
                    if ntv < minTV {
                        self.cancelPinch(event)
                    } else {
                        let m = timeInterval * (ntv - minTV) * sv * sign
                        self.rootAction.pinch(with: .init(screenPoint: event.screenPoint,
                                                          time: event.time,
                                                          magnification: m,
                                                          phase: .changed))
                    }
                }
            }
        }
    }
    func cancelPinch(_ event: TouchEvent) {
        pinchTimer?.cancel()
        pinchTimer = nil
        if isMomentumPinch {
            isMomentumPinch = false
            pinchTimeValue = 0
            
            rootAction.pinch(with: .init(screenPoint: event.screenPoint,
                                         time: event.time,
                                         magnification: 0,
                                         phase: .ended))
        }
    }
    
    func endRotate(with event: TouchEvent) {
        guard isBeganRotate else { return }
        self.oldRotateAngle = nil
        isBeganRotate = false
        rootAction.rotate(with: .init(screenPoint: event.screenPoint,
                                      time: event.time,
                                      rotationQuantity: 0,
                                      phase: .ended))
    }
    
    func endScroll(with event: TouchEvent, enabledMomentum: Bool = true,
                   timeInterval: Double = 1 / 60) {
        guard isBeganScroll else { return }
        self.oldScrollPosition = nil
        isBeganScroll = false
        guard scrollVs.count >= 2 && enabledMomentum else {
            rootAction.scroll(with: .init(screenPoint: event.screenPoint,
                                          time: event.time,
                                          scrollDeltaPoint: .init(),
                                          phase: .ended,
                                          touchPhase: .ended,
                                          momentumPhase: nil))
            return
        }
        
        let fsi = scrollVs[..<(scrollVs.count - 1)]
            .lastIndex(where: { event.time - $0.time > 0.05 }) ?? 0
        let lsv = scrollVs.last!
        let t = timeInterval + lsv.time
        
        let sdp = scrollVs.last!.dp
        let angle = sdp.angle()
        let (a, b) = Double.leastSquares(xs: scrollVs[fsi...].map { $0.time },
                            ys: scrollVs[fsi...].map { $0.dp.length() })
        let atb = a * t + b
        let v = min(atb < 0 ? scrollVs.last?.dp.length() ?? 0 : atb, 700) * 1.125
        let scale = v.clipped(min: 100, max: 700,
                              newMin: 0.91, newMax: 0.95)
        let tv = v / timeInterval
        let minTV = 100.0
        let sv = tv / (tv - minTV)
        if tv.isNaN || v < 4 || a == 0 {
            rootAction.scroll(with: .init(screenPoint: event.screenPoint,
                                          time: event.time,
                                          scrollDeltaPoint: .init(),
                                          phase: .ended,
                                          touchPhase: .ended,
                                          momentumPhase: nil))
        } else {
            rootAction.scroll(with: .init(screenPoint: event.screenPoint,
                                          time: event.time,
                                          scrollDeltaPoint: .init(),
                                          phase: .changed,
                                          touchPhase: .ended,
                                          momentumPhase: .began))
            
            isMomentumScroll = true
            scrollTimeValue = tv
            scrollTimer = DispatchSource.scheduledTimer(withTimeInterval: timeInterval) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self, !(self.scrollTimer?.isCancelled ?? true) else { return }
                    let ntv = self.scrollTimeValue * scale
                    self.scrollTimeValue = ntv
                    let sdp = Point().movedWith(distance: timeInterval * (ntv - minTV) * sv,
                                                angle: angle)
                    if ntv < minTV {
                        self.cancelScroll(event)
                    } else {
                        self.rootAction.scroll(with: .init(screenPoint: event.screenPoint,
                                                           time: event.time,
                                                           scrollDeltaPoint: sdp,
                                                           phase: .changed,
                                                           touchPhase: nil, momentumPhase: .changed))
                    }
                }
            }
        }
    }
    func cancelScroll(_ event: TouchEvent) {
        scrollTimer?.cancel()
        scrollTimer = nil
        if isMomentumScroll {
            isMomentumScroll = false
            scrollTimeValue = 0
            rootAction.scroll(with: .init(screenPoint: event.screenPoint,
                                          time: event.time,
                                          scrollDeltaPoint: .init(),
                                          phase: .ended,
                                          touchPhase: nil, momentumPhase: .ended))
        }
    }
    
    private enum TouchGesture {
        case none, pinch, rotate
    }
    private var blockGesture = TouchGesture.none
    override func magnify(with nsEvent: NSEvent) {
        guard !isEnabledCustomTrackpad else { return }
        
        if nsEvent.phase.contains(.began) {
            blockGesture = .pinch
            pinchVs = []
            rootAction.pinch(with: pinchEventWith(nsEvent, .began))
        } else if nsEvent.phase.contains(.ended) {
            blockGesture = .none
            rootAction.pinch(with: pinchEventWith(nsEvent, .ended))
            pinchVs = []
        } else if nsEvent.phase.contains(.changed) {
            pinchVs.append((Double(nsEvent.magnification), nsEvent.timestamp))
            rootAction.pinch(with: pinchEventWith(nsEvent, .changed))
        }
    }
    
    private var isFirstStoppedRotation = true
    private var isBlockedRotation = false
    private var rotatedValue: Float = 0.0
    private let blockRotationValue: Float = 4.0
    override func rotate(with nsEvent: NSEvent) {
        guard !isEnabledCustomTrackpad else { return }
        
        if nsEvent.phase.contains(.began) {
            if blockGesture != .pinch {
                isBlockedRotation = false
                isFirstStoppedRotation = true
                rotatedValue = nsEvent.rotation
            } else {
                isBlockedRotation = true
            }
        } else if nsEvent.phase.contains(.ended) {
            if !isBlockedRotation {
                if !isFirstStoppedRotation {
                    isFirstStoppedRotation = true
                    rootAction.rotate(with: rotateEventWith(nsEvent, .ended))
                }
            } else {
                isBlockedRotation = false
            }
        } else if nsEvent.phase.contains(.changed) {
            if !isBlockedRotation {
                rotatedValue += abs(nsEvent.rotation)
                if rotatedValue > blockRotationValue {
                    if isFirstStoppedRotation {
                        isFirstStoppedRotation = false
                        rootAction.rotate(with: rotateEventWith(nsEvent, .began))
                    } else {
                        rootAction.rotate(with: rotateEventWith(nsEvent, .changed))
                    }
                }
            }
        }
    }
    
    override func quickLook(with nsEvent: NSEvent) {
        guard !isEnabledCustomTrackpad else { return }
        
        guard window?.sheets.isEmpty ?? false else { return }
        
        rootAction.inputKey(with: inputKeyEventWith(nsEvent, .threeFingersTap, .began))
        Sleep.start()
        rootAction.inputKey(with: inputKeyEventWith(nsEvent, .threeFingersTap, .ended))
    }
    
    func windowLevel() -> Int {
        window?.level.rawValue ?? 0
    }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        [.markedClauseSegment, .glyphInfo]
    }
    func hasMarkedText() -> Bool {
        rootAction.rootView.editingTextView?.isMarked ?? false
    }
    func markedRange() -> NSRange {
        if let textView = rootAction.rootView.editingTextView,
           let range = textView.markedRange {
            return textView.model.string.nsRange(from: range)
                ?? NSRange(location: NSNotFound, length: 0)
        } else {
            return NSRange(location: NSNotFound, length: 0)
        }
    }
    func selectedRange() -> NSRange {
        if let textView = rootAction.rootView.editingTextView,
           let range = textView.selectedRange {
            return textView.model.string.nsRange(from: range)
                ?? NSRange(location: NSNotFound, length: 0)
        } else {
            return NSRange(location: NSNotFound, length: 0)
        }
    }
    func attributedString() -> NSAttributedString {
        if let text = rootAction.rootView.editingTextView?.model {
            return NSAttributedString(string: text.string.nsBased,
                                      attributes: text.typobute.attributes())
        } else {
            return NSAttributedString()
        }
    }
    func attributedSubstring(forProposedRange nsRange: NSRange,
                             actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = nsRange
        let attString = attributedString()
        if nsRange.location >= 0 && nsRange.upperBound <= attString.length {
            return attString.attributedSubstring(from: nsRange)
        } else {
            return nil
        }
    }
    func fractionOfDistanceThroughGlyph(for point: NSPoint) -> CGFloat {
        let p = convertFromTopScreen(point).my
        let d = rootAction.textAction.characterRatio(for: p)
        return CGFloat(d ?? 0)
    }
    func characterIndex(for nsP: NSPoint) -> Int {
        let p = convertFromTopScreen(nsP).my
        if let i = rootAction.textAction.characterIndex(for: p),
           let string = rootAction.rootView.editingTextView?.model.string {
            
            return string.nsIndex(from: i)
        } else {
            return 0
        }
    }
    func firstRect(forCharacterRange nsRange: NSRange,
                   actualRange: NSRangePointer?) -> NSRect {
        if let string = rootAction.rootView.editingTextView?.model.string,
           let range = string.range(fromNS: nsRange),
           let rect = rootAction.textAction.firstRect(for: range) {
            return convertToTopScreen(rect.cg)
        } else {
            return NSRect()
        }
    }
    func baselineDeltaForCharacter(at nsI: Int) -> CGFloat {
        if let string = rootAction.rootView.editingTextView?.model.string,
           let i = string.index(fromNS: nsI),
           let d = rootAction.textAction.baselineDelta(at: i) {
            
            return CGFloat(d)
        } else {
            return 0
        }
    }
    func drawsVerticallyForCharacter(at nsI: Int) -> Bool {
        if let o = rootAction.rootView.editingTextView?.textOrientation {
            return o == .vertical
        } else {
            return false
        }
    }
    
    func unmarkText() {
        rootAction.textAction.unmark()
    }
    
    func setMarkedText(_ str: Any,
                       selectedRange selectedNSRange: NSRange,
                       replacementRange replacementNSRange: NSRange) {
        guard let string = rootAction.rootView.editingTextView?.model.string else { return }
        let range = string.range(fromNS: replacementNSRange)
        
        func mark(_ mStr: String) {
            if let markingRange = mStr.range(fromNS: selectedNSRange) {
                rootAction.textAction.mark(mStr, markingRange: markingRange, at: range)
            }
        }
        if let attString = str as? NSAttributedString {
            mark(attString.string.swiftBased)
        } else if let nsString = str as? NSString {
            mark((nsString as String).swiftBased)
        }
    }
    func insertText(_ str: Any, replacementRange: NSRange) {
        guard let string = rootAction.rootView.editingTextView?.model.string else { return }
        let range = string.range(fromNS: replacementRange)
        
        if let attString = str as? NSAttributedString {
            rootAction.textAction.insert(attString.string.swiftBased, at: range)
        } else if let nsString = str as? NSString {
            rootAction.textAction.insert((nsString as String).swiftBased, at: range)
        }
    }
    
    override func insertNewline(_ sender: Any?) {
        rootAction.textAction.insertNewline()
    }
    override func insertTab(_ sender: Any?) {
        rootAction.textAction.insertTab()
    }
    override func deleteBackward(_ sender: Any?) {
        rootAction.textAction.deleteBackward()
    }
    override func deleteForward(_ sender: Any?) {
        rootAction.textAction.deleteForward()
    }
    override func moveLeft(_ sender: Any?) {
        rootAction.textAction.moveLeft()
    }
    override func moveRight(_ sender: Any?) {
        rootAction.textAction.moveRight()
    }
    override func moveUp(_ sender: Any?) {
        rootAction.textAction.moveUp()
    }
    override func moveDown(_ sender: Any?) {
        rootAction.textAction.moveDown()
    }
}
extension SubMTKView {
    override func draw(_ dirtyRect: NSRect) {
        autoreleasepool { self.render() }
    }
    func render() {
        guard let commandBuffer
                = Renderer.shared.commandQueue.makeCommandBuffer() else { return }
        guard let renderPassDescriptor = currentRenderPassDescriptor,
              let drawable = currentDrawable else {
            commandBuffer.commit()
            return
        }
        renderPassDescriptor.colorAttachments[0].texture = multisampleColorTexture
        renderPassDescriptor.colorAttachments[0].resolveTexture = drawable.texture
        renderPassDescriptor.stencilAttachment.texture = depthStencilTexture
        
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            let ctx = Context(encoder, renderstate)
            let wtvTransform = rootView.worldToViewportTransform
            let wtsScale = rootView.worldToScreenScale
            rootView.node.draw(with: wtvTransform, scale: wtsScale, in: ctx)
            
            if isShownDebug || isShownClock {
                drawDebugNode(in: ctx)
            }
            if !isHiddenActionList {
                let t = rootView.screenToViewportTransform
                actionNode?.draw(with: t, scale: 1, in: ctx)
            }
            
            ctx.encoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    func drawDebugNode(in context: Context) {
        updateDebugCount += 1
        if updateDebugCount >= 10 {
            updateDebugCount = 0
            let size = Renderer.shared.device.currentAllocatedSize
            let debugGPUSize = Int(Double(size) / (1024 * 1024))
            let maxSize = Renderer.shared.device.recommendedMaxWorkingSetSize
            let debugMaxGPUSize = Int(Double(maxSize) / (1024 * 1024))
            let string0 = isShownClock ? "\(Date().defaultString)" : ""
            let string1 = isShownDebug ? "GPU Memory: \(debugGPUSize) / \(debugMaxGPUSize) MB" : ""
            debugNode.path = Text(string: string0 + (isShownClock && isShownDebug ? " " : "") + string1).typesetter.path()
        }
        let t = rootView.screenToViewportTransform
        debugNode.draw(with: t, scale: 1, in: context)
    }
}
extension SubMTKView: @preconcurrency NodeOwner {}

extension Node {
    @MainActor func moveCursor(to sp: Point) {
        if let subMTKView = owner as? SubMTKView, let h = NSScreen.main?.frame.height {
            let np = subMTKView.convertToTopScreen(sp.cg)
            CGDisplayMoveCursorToPoint(0, CGPoint(x: np.x, y: h - np.y))
        }
    }
    @MainActor func show(definition: String, font: Font, orientation: Orientation, at p: Point) {
        if let owner = owner as? SubMTKView {
            let attributes = Typobute(font: font,
                                      orientation: orientation).attributes()
            let attString = NSAttributedString(string: definition,
                                               attributes: attributes)
            let sp = owner.rootView.convertWorldToScreen(convertToWorld(p))
            owner.showDefinition(for: attString, at: sp.cg)
        }
    }
    
    @MainActor func show(_ error: any Error) {
        guard let window = (owner as? SubMTKView)?.window else { return }
        NSAlert(error: error).beginSheetModal(for: window,
                                              completionHandler: { _ in })
    }
    
    @MainActor func show(message: String = "", infomation: String = "", isCaution: Bool = false) {
        guard let window = (owner as? SubMTKView)?.window else { return }
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = infomation
        if isCaution {
            alert.alertStyle = .critical
            alert.window.defaultButtonCell = nil
        }
        alert.beginSheetModal(for: window) { _ in }
    }
    
    enum AlertResult {
        case ok, cancel
    }
    @MainActor func show(message: String, infomation: String, okTitle: String,
                         isSaftyCheck: Bool = false,
                         isDefaultButton: Bool = false) async -> AlertResult {
        guard let window = (owner as? SubMTKView)?.window else { return .cancel }
        let alert = NSAlert()
        let okButton = alert.addButton(withTitle: okTitle)
        alert.addButton(withTitle: "Cancel".localized)
        alert.messageText = message
        if isSaftyCheck {
            okButton.isEnabled = false
            
            let textField = SubNSCheckbox(onTitle: "Enable the run button".localized,
                                          offTitle: "Disable the run button".localized) { [weak okButton] bool in
                okButton?.isEnabled = bool
            }
            alert.accessoryView = textField
        }
        alert.informativeText = infomation
        alert.alertStyle = .critical
        if !isDefaultButton {
            alert.window.defaultButtonCell = nil
        }
        let result = await alert.beginSheetModal(for: window)
        return switch result {
        case .alertFirstButtonReturn: .ok
        default: .cancel
        }
    }
    
    @MainActor func show(message: String, infomation: String, titles: [String]) async -> Int? {
        guard let window = (owner as? SubMTKView)?.window else { return nil }
        let alert = NSAlert()
        for title in titles {
            alert.addButton(withTitle: title)
        }
        alert.messageText = message
        alert.informativeText = infomation
        return await alert.beginSheetModal(for: window).rawValue
    }
    
    @MainActor func show(message: String, infomation: String) async {
        guard let window = (owner as? SubMTKView)?.window else { return }
        let alert = NSAlert()
        alert.addButton(withTitle: "Done".localized)
        alert.messageText = message
        alert.informativeText = infomation
        
        _ = await alert.beginSheetModal(for: window)
    }
    
    @MainActor func show(_ progressPanel: ProgressPanel) {
        guard let window = (owner as? SubMTKView)?.window else { return }
        progressPanel.topWindow = window
        progressPanel.begin()
        window.beginSheet(progressPanel.window) { _ in }
    }
}

enum Appearance {
    case light, dark
    
    nonisolated(unsafe) static var current: Appearance = .light
}

struct UTType {
    var uti: UniformTypeIdentifiers.UTType
    init(importedAs: String) {
        uti = UniformTypeIdentifiers.UTType(importedAs: importedAs)
    }
    init(exportedAs: String) {
        uti = UniformTypeIdentifiers.UTType(exportedAs: exportedAs)
    }
    init(_ uti: UniformTypeIdentifiers.UTType) {
        self.uti = uti
    }
    init?(filenameExtension: String) {
        guard let nuti = UniformTypeIdentifiers.UTType(filenameExtension: filenameExtension) else { return nil }
        self.uti = nuti
    }
}

protocol FileTypeProtocol: Sendable {
    var name: String { get }
    var utType: UTType { get }
}

struct IOResult {
    var url: URL, name: String, isExtensionHidden: Bool
    
    var attributes: [FileAttributeKey: Any] { [.extensionHidden: isExtensionHidden] }
    
    func setAttributes() throws {
        try FileManager.default.setAttributes(attributes,
                                              ofItemAtPath: url.path)
    }
    func remove() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }
    func makeDirectory() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url,
                               withIntermediateDirectories: true,
                               attributes: nil)
    }
    func sub(name: String) -> IOResult {
        let nurl = url.appendingPathComponent(name)
        return IOResult(url: nurl, name: name, isExtensionHidden: isExtensionHidden)
    }
    static func fileSizeNameFrom(fileSize: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}
extension URL {
    enum LoadedResult {
        case complete([IOResult]), cancel
    }
    @MainActor static func load(message: String? = nil,
                                directoryURL: URL? = nil,
                                prompt: String? = nil,
                                canChooseDirectories: Bool = false,
                                allowsMultipleSelection: Bool = false,
                                fileTypes: [any FileTypeProtocol]) async -> LoadedResult {
        guard let window = SubNSApplication.shared.mainWindow else { return .cancel }
        let loadPanel = NSOpenPanel()
        loadPanel.message = message
        loadPanel.allowsMultipleSelection = allowsMultipleSelection
        if let directoryURL = directoryURL {
            loadPanel.directoryURL = directoryURL
        }
        if let prompt = prompt {
            loadPanel.prompt = prompt
        }
        loadPanel.canChooseDirectories = canChooseDirectories
        loadPanel.allowedContentTypes = fileTypes.map { $0.utType.uti }
        let result = await loadPanel.beginSheetModal(for: window)
        if result == .OK {
            let isExtensionHidden = loadPanel.isExtensionHidden
            let urls = loadPanel.url != nil && loadPanel.urls.count <= 1 ?
                [loadPanel.url!] : loadPanel.urls
            let results = urls.map {
                IOResult(url: $0, name: $0.lastPathComponent,
                         isExtensionHidden: isExtensionHidden)
            }
            return .complete(results)
        } else {
            return .cancel
        }
    }
    
    enum ExportedResult {
        case complete(IOResult), cancel
    }
    @MainActor static func save(message: String? = nil,
                                name: String? = nil,
                                directoryURL: URL? = nil,
                                prompt: String? = nil,
                                fileTypes: [any FileTypeProtocol]) async -> ExportedResult {
        guard let window = SubNSApplication.shared.mainWindow else { return .cancel }
        let savePanel = NSSavePanel()
        savePanel.message = message
        if let name = name {
            savePanel.nameFieldStringValue = name
        } else {
            let dateFomatter = DateFormatter()
            dateFomatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
            savePanel.nameFieldStringValue = dateFomatter.string(from: Date())
        }
        if let directoryURL = directoryURL {
            savePanel.directoryURL = directoryURL
        }
        if let prompt = prompt {
            savePanel.prompt = prompt
        }
        savePanel.canSelectHiddenExtension = true
        savePanel.allowedContentTypes = fileTypes.map { $0.utType.uti }
        let result = await savePanel.beginSheetModal(for: window)
        return if result == .OK, let url = savePanel.url {
            .complete(IOResult(url: url,
                               name: savePanel.nameFieldStringValue,
                               isExtensionHidden: savePanel.isExtensionHidden))
        } else {
            .cancel
        }
    }
    @MainActor static func export(message: String? = nil,
                                  name: String? = nil,
                                  directoryURL: URL? = nil,
                                  fileType: any FileTypeProtocol,
                                  fileTypeOptionName: String? = nil,
                                  fileSizeHandler: @Sendable @escaping () async -> (Int?)) async -> ExportedResult {
        guard let window = SubNSApplication.shared.mainWindow else { return .cancel }
        
        let savePanel = NSSavePanel()
        savePanel.message = message
        savePanel.nameFieldLabel = "Export As".localized + ":"
        if let name = name {
            savePanel.nameFieldStringValue = name
        } else {
            let dateFomatter = DateFormatter()
            dateFomatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
            savePanel.nameFieldStringValue = dateFomatter.string(from: Date())
        }
        if let directoryURL = directoryURL {
            savePanel.directoryURL = directoryURL
        }
        savePanel.prompt = "Save".localized
        
        let formatView = NSTextField(labelWithString: "Format".localized + ":")
        formatView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        formatView.controlSize = .small
        formatView.sizeToFit()
        
        let fileTypeName: String
        if let str = fileTypeOptionName {
            fileTypeName = str
        } else {
            fileTypeName = fileType.name
        }
        let formatTypeView = NSTextField(labelWithString: fileTypeName)
        formatTypeView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        formatTypeView.controlSize = .small
        formatTypeView.sizeToFit()
        
        let fileSizeView = NSTextField(labelWithString: "File Size".localized + ":")
        fileSizeView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        fileSizeView.controlSize = .small
        fileSizeView.sizeToFit()
        
        let fileSizeValueView = NSTextField(labelWithString: "Calculating Size".localized)
        fileSizeValueView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        fileSizeValueView.controlSize = .small
        fileSizeValueView.sizeToFit()
        
        let padding: CGFloat = 5.0, aroundPadding: CGFloat = 10.0
        let valueWidth: CGFloat = 100.0
        let w = max(formatView.frame.width,
                    fileSizeView.frame.width) + aroundPadding
        let h = formatView.frame.height
        
        formatView.frame.origin = NSPoint(x: w - formatView.frame.width,
                                          y: aroundPadding + padding + h)
        formatTypeView.frame.origin = NSPoint(x: w + padding,
                                              y: aroundPadding + padding + h)
        fileSizeView.frame.origin = NSPoint(x: w - fileSizeView.frame.width,
                                            y: aroundPadding)
        fileSizeValueView.frame.origin = NSPoint(x: w + padding,
                                                 y: aroundPadding)
        let vw = max(formatTypeView.frame.width,
                     fileSizeValueView.frame.width,
                     valueWidth)
        let nw = aroundPadding * 2 + w + padding + vw
        let nh = aroundPadding * 2 + padding + h * 2
        let view = NSView(frame: NSRect(x: 0, y: 0, width: nw, height: nh))
        view.addSubview(formatView)
        view.addSubview(formatTypeView)
        view.addSubview(fileSizeView)
        view.addSubview(fileSizeValueView)
        savePanel.accessoryView = view
        
        savePanel.allowedContentTypes = [fileType.utType.uti]
        
        Task {
            let string = if let fileSize = await fileSizeHandler() {
                IOResult.fileSizeNameFrom(fileSize: fileSize)
            } else {
                "--"
            }
            fileSizeValueView.stringValue = string
            fileSizeValueView.sizeToFit()
        }
        
        savePanel.canSelectHiddenExtension = true
        let result = await savePanel.beginSheetModal(for: window)
        return if result == .OK, let url = savePanel.url {
            .complete(IOResult(url: url,
                               name: savePanel.nameFieldStringValue,
                               isExtensionHidden: savePanel.isExtensionHidden))
        } else {
            .cancel
        }
    }
}
extension URL {
    var fileSize: Int? {
        (try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }
    var updateDate: Date? {
        (try? resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate
    }
    var createdDate: Date? {
        (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }
    var allFileSize: Int {
        var fileSize = 0
        let urls = FileManager.default.enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL]
        urls?.lazy.forEach {
            fileSize += (try? $0.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?
                .totalFileAllocatedSize ?? 0
        }
        return fileSize
    }
    static var readError: any Error {
        NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
    }
    static var writeError: any Error {
        NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
    }
}
extension URL {
    static let library = {
        let libraryName = "User" + "." + (Document.FileType.rasendata.utType.uti.preferredFilenameExtension ?? "rasendata")
        return URL(libraryName: libraryName)
    } ()
    static let contents = library.appending(path: "contents")
    
    init(libraryName: String) {
        let directoryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        self = directoryURL.appendingPathComponent(libraryName)
    }
    init?(bundleName: String, extension ex: String) {
        guard let url = Bundle.main.url(forResource: bundleName, withExtension: ex) else { return nil }
        self = url
    }
    
    struct BookmarkError: Error {}
    /// SandBox: com.apple.security.files.bookmarks.app-scope = true
    init(bookmarkData: Data) throws {
        do {
            var bds = false
            try self.init(resolvingBookmarkData: bookmarkData,
                          options: [.withSecurityScope],
                          bookmarkDataIsStale: &bds)
            if bds {
            }
        } catch {
            throw error
        }
    }
    
    var type: String? {
        let resourceValues = try? self.resourceValues(forKeys: Set([.typeIdentifierKey]))
        return resourceValues?.typeIdentifier
    }
    
    @discardableResult func openInBrowser() -> Bool {
        NSWorkspace.shared.open(self)
    }
}

struct Sleep {
    static func start(atTime t: Double = 0.06) {
        usleep(useconds_t(1000000 * t))
    }
}
extension Task where Success == Never, Failure == Never {
    static func sleep(sec: Double) async throws {
        try await sleep(nanoseconds: .init(sec * 1_000_000_000))
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}

struct System {
    static let appName = "Rasen".localized
    static let dataName = String(format: "%@ Data".localized, appName)
    static let id = Bundle.main.bundleIdentifier ?? "net.cii0.Rasen"
    
    static let oldAppName = "Shikishi".localized
    static let oldDataName = String(format: "%@ Data".localized, oldAppName)
    static let oldID = "net.cii0.Shikishi"
}

final class Pasteboard {
    nonisolated(unsafe) static let shared = Pasteboard()
    
    private var aCopiedObjects: [PastableObject]?
    private var nsChangedCount = NSPasteboard.general.changeCount
    var copiedObjects: [PastableObject] {
        get {
            let value: [PastableObject]
            if nsChangedCount != NSPasteboard.general.changeCount {
                value = NSPasteboard.general.copiedObjects
                aCopiedObjects = value
                nsChangedCount = NSPasteboard.general.changeCount
            } else if let aCopiedObjects = aCopiedObjects {
                value = aCopiedObjects
            } else {
                value = NSPasteboard.general.copiedObjects
                aCopiedObjects = value
                nsChangedCount = NSPasteboard.general.changeCount
            }
            return value
        }
        set {
            aCopiedObjects = newValue
            NSPasteboard.general.set(copiedObjects: newValue)
            nsChangedCount = NSPasteboard.general.changeCount
        }
    }
}
extension NSPasteboard {
    var copiedObjects: [PastableObject] {
        var copiedObjects = [PastableObject]()
        func append(with data: Data, type: NSPasteboard.PasteboardType) {
            if type == .tiff || type == .png,
               let image = Image(data: data) {
                copiedObjects.append(.image(image))
            } else if let object = try? PastableObject(data: data, typeName: type.rawValue) {
                copiedObjects.append(object)
            }
        }
        if let types = types {
            for type in types {
                if let data = data(forType: type) {
                    append(with: data, type: type)
                } else if let string = string(forType: .string) {
                    copiedObjects.append(.string(string))
                }
            }
        }
        if let items = pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        append(with: data, type: type)
                    } else if let string = item.string(forType: .string) {
                        copiedObjects.append(.string(string))
                    }
                }
            }
        }
        if let string = string(forType: .string) {
            copiedObjects.append(.string(string))
        }
        return copiedObjects
    }
    
    func set(copiedObjects: [PastableObject]) {
        if copiedObjects.isEmpty {
            clearContents()
            return
        }
        
        var strings = [String]()
        var typesAndDatas = [(type: NSPasteboard.PasteboardType, data: Data)]()
        for object in copiedObjects {
            if case .string(let string) = object {
                strings.append(string)
            } else {
                let typeName = object.typeName
                if let data = object.data {
                    let pasteboardType = NSPasteboard.PasteboardType(rawValue: typeName)
                    typesAndDatas.append((pasteboardType, data))
                }
            }
        }
        
        if strings.count == 1 && typesAndDatas.isEmpty {
            let string = strings[0]
            declareTypes([.string], owner: nil)
            setString(string, forType: .string)
        } else if strings.isEmpty && typesAndDatas.count == 1 {
            let typeAndData = typesAndDatas[0]
            declareTypes([typeAndData.type], owner: nil)
            setData(typeAndData.data, forType: typeAndData.type)
        } else {
            var items = [NSPasteboardItem]()
            for typeAndData in typesAndDatas {
                let item = NSPasteboardItem()
                item.setData(typeAndData.data, forType: typeAndData.type)
                items.append(item)
            }
            for string in strings {
                let item = NSPasteboardItem()
                item.setString(string, forType: .string)
                items.append(item)
            }
            clearContents()
            writeObjects(items)
        }
    }
}

struct TextDictionary {
    static func string(from str: String) -> String? {
        let nstr = TextChecker().convert(str, ignoredWords: []) ?? str
        switch nstr {
        case "!", "！": return "Exclamation mark".localized
        case "?", "？": return "Question mark".localized
        default:
            let range = CFRange(location: 0, length: (nstr as NSString).length)
            guard let nnstr = DCSCopyTextDefinition(nil, nstr as CFString, range)?.takeRetainedValue() as String? else { return nil }
            return nnstr.count < 1000 ? nnstr : nil
        }
    }
}

final class TextChecker {
    init() {}
    func convert(_ str: String, ignoredWords: [String]) -> String? {
        let checker = NSSpellChecker()
        let tag = NSSpellChecker.uniqueSpellDocumentTag()
        checker.setIgnoredWords(ignoredWords, inSpellDocumentWithTag: tag)
        let range = checker.checkSpelling(of: str, startingAt: 0)
        guard range.location != NSNotFound else { return nil }
        let strs = checker.guesses(forWordRange: range, in: str, language: nil,
                                   inSpellDocumentWithTag: tag)
        guard let firstStr = strs?.first else { return nil }
        return firstStr
    }
}

final class SubNSTrackpadView: NSView {
    override init (frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderColor = NSColor.gridColor.cgColor
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
    }
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderColor = NSColor.gridColor.cgColor
    }
    
    var isDrag = false
    override func mouseEntered(with event: NSEvent) {
        if !isDrag {
            NSCursor.arrow.set()
        }
    }
    override func mouseExited(with event: NSEvent) {
        if !isDrag {
            (superview as? SubMTKView)?.rootView.cursor.ns.set()
        }
    }
    private var trackingArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = self.trackingArea {
            removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(rect: bounds,
                                          options: [.mouseEnteredAndExited,
                                                    .activeInKeyWindow],
                                          owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
}

final class SubNSButton: NSButton {
    enum IconType {
        case lookUp, scroll, zoom, rotate
    }
    
    var closure: (_ event: DragEvent, _ deltaPoint: Point) -> () = { (_, _) in }
    var iconType: IconType
    
    init(frame: NSRect, _ iconType: IconType,
         closure: @escaping (_ event: DragEvent, _ deltaPoint: Point) -> ()) {
        
        self.closure = closure
        self.iconType = iconType
        super.init(frame: frame)
        switch iconType {
        case .lookUp:
            toolTip = "Look Up".localized
            image = NSImage(named: NSImage.quickLookTemplateName)
        case .scroll: toolTip = "Scroll".localized
        case .zoom: toolTip = "Zoom".localized
        case .rotate: toolTip = "Rotate".localized
        }
        self.title = ""
        bezelStyle = .regularSquare
    }
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func screenPoint(with event: NSEvent) -> NSPoint {
        convertToLayer(convert(event.locationInWindow, from: nil))
    }
    func dragEventWith(_ nsEvent: NSEvent, _ phase: Phase) -> DragEvent {
        DragEvent(screenPoint: screenPoint(with: nsEvent).my,
                  time: nsEvent.timestamp,
                  pressure: Double(nsEvent.pressure),
                  isTablet: nsEvent.subtype == .tabletPoint, phase: phase)
    }
    var isDrag: Bool {
        get {
            (superview as? SubNSTrackpadView)?.isDrag ?? false
        }
        set {
            (superview as? SubNSTrackpadView)?.isDrag = newValue
        }
    }
    override func mouseDown(with nsEvent: NSEvent) {
        isDrag = true
        NSCursor.arrow.set()
        highlight(true)
        closure(dragEventWith(nsEvent, .began),
                Point(Double(nsEvent.deltaX), Double(nsEvent.deltaY)))
    }
    override func mouseDragged(with nsEvent: NSEvent) {
        closure(dragEventWith(nsEvent, .changed),
                Point(Double(nsEvent.deltaX), Double(nsEvent.deltaY)))
    }
    override func mouseUp(with nsEvent: NSEvent) {
        closure(dragEventWith(nsEvent, .ended),
                Point(Double(nsEvent.deltaX), Double(nsEvent.deltaY)))
        highlight(false)
        if superview?.bounds.contains(convert(nsEvent.locationInWindow, from: nil)) ?? false {
            NSCursor.arrow.set()
        } else {
            (superview?.superview as? SubMTKView)?.rootView.cursor.ns.set()
        }
        isDrag = false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard iconType != .lookUp else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        
        let padding: CGFloat = 9.0
        let dd: CGFloat = 4.0
        let d = sqrt(3) * dd * 3 / 5
        let path = CGMutablePath()
        switch iconType {
        case .lookUp: break
        case .scroll:
            path.move(to: NSPoint(x: bounds.width / 2 - dd,
                                  y: bounds.height - padding - d))
            path.addLine(to: NSPoint(x: bounds.width / 2,
                                     y: bounds.height - padding))
            path.addLine(to: NSPoint(x: bounds.width / 2 + dd,
                                     y: bounds.height - padding - d))
            path.move(to: NSPoint(x: bounds.width / 2,
                                  y: bounds.height - padding))
            path.addLine(to: NSPoint(x: bounds.width / 2,
                                     y: padding))
            path.move(to: NSPoint(x: bounds.width / 2 - dd,
                                  y: padding + d))
            path.addLine(to: NSPoint(x: bounds.width / 2,
                                     y: padding))
            path.addLine(to: NSPoint(x: bounds.width / 2 + dd,
                                     y: padding + d))
            
            path.move(to: NSPoint(x: bounds.width - padding - d,
                                  y: bounds.height / 2 - dd))
            path.addLine(to: NSPoint(x: bounds.width - padding,
                                     y: bounds.height / 2))
            path.addLine(to: NSPoint(x: bounds.width - padding - d,
                                     y: bounds.height / 2 + dd))
            path.move(to: NSPoint(x: bounds.width - padding,
                                  y: bounds.height / 2))
            path.addLine(to: NSPoint(x: padding,
                                     y: bounds.height / 2))
            path.move(to: NSPoint(x: padding + d,
                                  y: bounds.height / 2 - dd))
            path.addLine(to: NSPoint(x: padding,
                                     y: bounds.height / 2))
            path.addLine(to: NSPoint(x: padding + d,
                                     y: bounds.height / 2 + dd))
        case .zoom:
            path.move(to: NSPoint(x: bounds.width / 2 - dd * 5 / 2,
                                  y: bounds.height - padding - d * 5 / 2))
            path.addLine(to: NSPoint(x: bounds.width / 2,
                                     y: bounds.height - padding))
            path.addLine(to: NSPoint(x: bounds.width / 2 + dd * 5 / 2,
                                     y: bounds.height - padding - d * 5 / 2))
            path.move(to: NSPoint(x: bounds.width / 2,
                                  y: bounds.height - padding))
            path.addLine(to: NSPoint(x: bounds.width / 2,
                                     y: padding))
            path.move(to: NSPoint(x: bounds.width / 2 - dd,
                                  y: padding + d))
            path.addLine(to: NSPoint(x: bounds.width / 2,
                                     y: padding))
            path.addLine(to: NSPoint(x: bounds.width / 2 + dd,
                                     y: padding + d))
        case .rotate:
            path.move(to: NSPoint(x: bounds.width - padding - d,
                                  y: bounds.height / 2 - dd + d))
            path.addLine(to: NSPoint(x: bounds.width - padding,
                                     y: bounds.height / 2 + d))
            path.addLine(to: NSPoint(x: bounds.width - padding - d,
                                     y: bounds.height / 2 + dd + d))
            path.move(to: NSPoint(x: bounds.width - padding,
                                  y: bounds.height / 2 + d))
            path.addQuadCurve(to: NSPoint(x: bounds.width / 2,
                                          y: padding + d),
                              control: NSPoint(x: bounds.width / 2,
                                               y: bounds.height / 2 + d))
            path.move(to: NSPoint(x: bounds.width / 2,
                                  y: padding + d))
            path.addQuadCurve(to: NSPoint(x: padding,
                                          y: bounds.height / 2 + d),
                              control: NSPoint(x: bounds.width / 2,
                                               y: bounds.height / 2 + d))
            path.move(to: NSPoint(x: padding + d,
                                  y: bounds.height / 2 - dd + d))
            path.addLine(to: NSPoint(x: padding,
                                     y: bounds.height / 2 + d))
            path.addLine(to: NSPoint(x: padding + d,
                                     y: bounds.height / 2 + dd + d))
        }
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.textColor.cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

final class SubNSCheckbox: NSView {
    var closure: (Bool) -> ()
    
    let onButton, offButton: NSButton
    
    enum Layout {
        case horizontal, vertical
    }
    
    init(onTitle: String, offTitle: String,
         layout: Layout = .vertical, padding: CGFloat = 8,
         closure: @escaping (Bool) -> ()) {
        self.closure = closure
        onButton = NSButton(radioButtonWithTitle: onTitle,
                            target: nil,
                            action: #selector(closureAction(_:)))
        offButton = NSButton(radioButtonWithTitle: offTitle,
                             target: nil,
                             action: #selector(closureAction(_:)))
        onButton.controlSize = .regular
        onButton.sizeToFit()
        offButton.controlSize = .regular
        offButton.sizeToFit()
        
        let frame: NSRect
        switch layout {
        case .horizontal:
            frame = NSRect(x: 0, y: 0,
                           width: onButton.frame.width + offButton.frame.width + 10,
                           height: max(onButton.frame.height, offButton.frame.height) + padding * 2)
            offButton.frame.origin = NSPoint(x: 0, y: padding)
            onButton.frame.origin = NSPoint(x: offButton.frame.width + 5, y: padding)
        case .vertical:
            frame = NSRect(x: 0, y: 0,
                           width: max(onButton.frame.width,
                                      offButton.frame.width),
                           height: onButton.frame.height + offButton.frame.height + 8 + padding * 2)
            offButton.frame.origin = NSPoint(x: 0, y: padding)
            onButton.frame.origin = NSPoint(x: 0, y: offButton.frame.height + 8 + padding)
        }
        offButton.state = .on
        super.init(frame: frame)
        onButton.target = self
        offButton.target = self
        addSubview(onButton)
        addSubview(offButton)
    }
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func closureAction(_ sender: Any) {
        closure((sender as? NSObject) == onButton)
    }
}

final class SubNSMenuItem: NSMenuItem {
    var closure: () -> ()
    
    init(title: String, closure: @escaping () -> ()) {
        self.closure = closure
        
        super.init(title: title,
                   action: #selector(closureAction(_:)),
                   keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func closureAction(_ sender: Any) {
        closure()
    }
}

final class ProgressButton: NSButton {
    var closure: () -> ()
    
    init(frame: NSRect, title: String, closure: @escaping () -> ()) {
        self.closure = closure
        
        super.init(frame: frame)
        self.title = title
        self.action = #selector(closureAction(_:))
        target = self
    }
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func closureAction(_ sender: Any) {
        closure()
    }
}

actor ActorProgress {
    var total = 0, count = 0
    
    init(total: Int = 0, count: Int = 0) {
        self.total = total
        self.count = count
    }
    
    var fractionCompleted: Double {
        total == 0 ? 0 : Double(count) / Double(total)
    }
    
    func addTotal() {
        total += 1
    }
    func addCount() {
        count += 1
    }
}

@MainActor final class ProgressPanel {
    weak var topWindow: NSWindow?
    let window: NSWindow
    fileprivate var progressIndicator = NSProgressIndicator(frame: NSRect(x: 20, y: 50, width: 360, height: 20))
    fileprivate var titleField: NSTextField
    fileprivate var cancelButton = ProgressButton(frame: NSRect(x: 278, y: 8, width: 110, height: 40),
                                                  title: "Cancel".localized, closure: {})
    private let isIndeterminate: Bool
    init(message: String, isCancel: Bool = true, isIndeterminate: Bool = false,
         cancelHandler: @escaping () -> () = {}) {
        self.message = message
        titleField = NSTextField(labelWithString: message)
        titleField.frame.origin = NSPoint(x: 18, y: 80)
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        self.isIndeterminate = isIndeterminate
        if isIndeterminate {
            progressIndicator.isIndeterminate = isIndeterminate
            if isIndeterminate {
                progressIndicator.startAnimation(nil)
            }
        }
        cancelButton.bezelStyle = .rounded
        cancelButton.setButtonType(.momentaryPushIn)
        if !isCancel {
            cancelButton.isEnabled = false
        }
        let b = NSRect(x: 0, y: 0, width: 400, height: 110)
        let view = NSView(frame: b)
        view.addSubview(titleField)
        view.addSubview(progressIndicator)
        view.addSubview(cancelButton)
        
        window = .init(contentRect: b, styleMask: .titled, backing: .buffered, defer: true)
        window.contentView = view
        
        cancelButton.closure = { [weak self] in
            self?.cancel()
        }
    }
    
    var message = ""
    var progress = 0.0 {
        didSet {
            progressIndicator.doubleValue = progress
        }
    }
    func begin() {
        if !isIndeterminate {
            progressIndicator.isIndeterminate = false
        }
        progressIndicator.startAnimation(nil)
    }
    func end() {
        if !isIndeterminate {
            progressIndicator.isIndeterminate = true
        }
        progressIndicator.stopAnimation(nil)
    }
    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        begin()
    }
    func closePanel() {
        if !isCancel {
            progressIndicator.doubleValue = 1
            progressIndicator.isIndeterminate = true
        }
        progressIndicator.stopAnimation(nil)
        if window.isSheet {
            topWindow?.endSheet(window)
        }
    }
    var isCancel = false
    var cancelHandler: (() -> ())?
    func cancel() {
        isCancel = true
        titleField.stringValue = "Stopping Task".localized
        titleField.sizeToFit()
        cancelButton.state = .on
        cancelButton.isEnabled = false
        progressIndicator.doubleValue = 1
        progressIndicator.isIndeterminate = true
        progressIndicator.startAnimation(nil)
        cancelHandler?()
    }
    
    func close() {
        window.close()
    }
}

enum ByteOrder {
    case littleEndian, bigEndian
    static func current() -> ByteOrder? {
        switch UInt32(CFByteOrderGetCurrent()) {
        case CFByteOrderLittleEndian.rawValue: .littleEndian
        case CFByteOrderBigEndian.rawValue: .bigEndian
        default: nil
        }
    }
}
extension Double {
    func littleEndianToBigEndian() -> Double {
        CFConvertDoubleSwappedToHost(CFSwappedFloat64(v: bitPattern))
    }
    func bigEndianToLittleEndian() -> Double {
        Double(bitPattern: CFConvertDoubleHostToSwapped(self).v)
    }
}

extension CGImage {
    var size: Size {
        Size(width: width, height: height)
    }
    func data(_ fileType: Image.FileType) -> Data? {
        guard let mData = CFDataCreateMutable(nil, 0) else {
            return nil
        }
        let cfFileType = fileType.utType.uti.identifier as CFString
        guard let idn = CGImageDestinationCreateWithData(mData, cfFileType, 1, nil) else {
            return nil
        }
        if fileType == .jpeg {
            CGImageDestinationAddImage(idn, self, [kCGImageDestinationLossyCompressionQuality: 0.5] as CFDictionary)
        } else {
            CGImageDestinationAddImage(idn, self, nil)
        }
        if !CGImageDestinationFinalize(idn) {
            return nil
        } else {
            return mData as Data
        }
    }
    func write(_ fileType: Image.FileType, to url: URL) throws {
        let cfURL = url as CFURL, cfFileType = fileType.utType.uti.identifier as CFString
        guard let idn = CGImageDestinationCreateWithURL(cfURL, cfFileType, 1, nil) else {
            throw URL.writeError
        }
        if fileType == .jpeg {
            CGImageDestinationAddImage(idn, self, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        } else {
            CGImageDestinationAddImage(idn, self, nil)
        }
        if !CGImageDestinationFinalize(idn) {
            throw URL.writeError
        }
    }
}

extension Color {
    init(_ cgColor: CGColor) {
        guard cgColor.numberOfComponents == 4,
              let components = cgColor.components,
              let name = cgColor.colorSpace?.name as String? else {
            self.init()
            return
        }
        switch name {
        case String(CGColorSpace.sRGB):
            self.init(red: Float(components[0]),
                      green: Float(components[1]),
                      blue: Float(components[2]),
                      opacity: Double(Float(components[3])),
                      .sRGB)
        default:
            self.init()
        }
    }
    var cg: CGColor {
        CGColor.with(rgb: rgba, alpha: opacity, colorSpace: colorSpace.cg ?? .default)
    }
}
extension CGColor {
    static func with(rgb: RGBA, alpha a: Double = 1,
                     colorSpace: CGColorSpace? = nil) -> CGColor {
        let cs = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let cps = [CGFloat(rgb.r), CGFloat(rgb.g), CGFloat(rgb.b), CGFloat(a)]
        return CGColor(colorSpace: cs, components: cps)
            ?? CGColor(red: cps[0], green: cps[1], blue: cps[2], alpha: cps[3])
    }
}
extension CGColorSpace {
    static var sRGBColorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.sRGB)
    }
    static var sRGBLinearColorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.linearSRGB)
    }
    static var sRGBHDRColorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.extendedSRGB)
    }
    static var sRGBHDRLinearColorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
    }
    static var p3ColorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.displayP3)
    }
    static var p3LinearColorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.linearDisplayP3)
    }
    static var p3HDRColorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.extendedDisplayP3)
    }
    static var p3HDRLinearColorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
    }
    static var itur2020HLGColorSpace: CGColorSpace? {
        CGColorSpace(name: CGColorSpace.itur_2100_HLG)
    }
    static let `default` = sRGBColorSpace ?? CGColorSpaceCreateDeviceRGB()
}
extension ColorSpace {
    var cg: CGColorSpace? {
        switch self {
        case .sRGB: .sRGBColorSpace
        case .sRGBLinear: .sRGBLinearColorSpace
        case .sRGBHDR: .sRGBHDRColorSpace
        case .sRGBHDRLinear: .sRGBHDRLinearColorSpace
        case .p3: .p3ColorSpace
        case .p3Linear: .p3LinearColorSpace
        case .p3HDR: .p3HDRColorSpace
        case .p3HDRLinear: .p3HDRLinearColorSpace
        }
    }
}

enum LineCap {
    case round, square
}
extension LineCap {
    var cg: CGLineCap {
        switch self {
        case .round: .round
        case .square: .square
        }
    }
}

struct Cursor {
    nonisolated(unsafe) static let arrow = arrowWith()
    nonisolated(unsafe) static let drawLine = circle()
    nonisolated(unsafe) static let cross = crossWith()
    nonisolated(unsafe) static let block = ban()
    nonisolated(unsafe) static let stop = rect()
    
    nonisolated(unsafe) static var current = arrow {
        didSet {
            current.ns.set()
        }
    }
    nonisolated(unsafe) static var isHidden = false {
        didSet {
            if isHidden != oldValue {
                if isHidden {
                    NSCursor.hide()
                } else {
                    NSCursor.unhide()
                }
            }
        }
    }
    
    static let circleDefaultSize = 7.0, circleDefaultLineWidth = 1.5
    static func circle(size s: Double = circleDefaultSize,
                       scale: Double = 1,
                       progress: Double? = nil, progressWidth: Double = 40.0,
                       string: String = "",
                       lightColor: Color = .content,
                       lightOutlineColor: Color = .background,
                       darkColor: Color = .background,
                       darkOutlineColor: Color = .darkBackground) -> Cursor {
        let lineWidth = circleDefaultLineWidth * scale,
            subLineWidth = 1.125 * scale
        let d = (subLineWidth + lineWidth / 2).rounded(.up)
        let r = s / 2
        
        let tPath: Path?, tSize: Size
        if !string.isEmpty {
            let text = Text(string: string, size: Font.defaultSize)
            let tb = text.frame ?? Rect()
            tSize = tb.size + Size(width: 0, height: 3)
            tPath = text.typesetter.path()
        } else {
            tSize = .init()
            tPath = nil
        }
        
        let hotSpot = Point(d + s / 2, -d - s / 2)
        
        let ph = progress != nil ? lineWidth + subLineWidth * 2 + 2 : 0
        let ah = tSize.height + ph
        let bcp = Point(d + r, d + r + ah)
        func node(color: Color, outlineColor: Color) -> Node {
            let outlineNode = Node(path: Path(circleRadius: r + (subLineWidth + lineWidth) / 2,
                                              position: bcp),
                                   lineWidth: lineWidth,
                                   lineType: .color(outlineColor))
            let inlineNode = Node(path: Path(circleRadius: r, position: bcp),
                                  lineWidth: lineWidth,
                                  lineType: .color(color))
            
            func progressNodes(fromWidth progressW: Double) -> [Node] {
                guard let progress else { return [] }
                let bp = Point(d, d + (subLineWidth + lineWidth) / 2)
                return [Node(path: Path([bp, Point(progressW * progress, 0) + bp]),
                             lineWidth: lineWidth + subLineWidth * 2,
                             lineType: .color(outlineColor)),
                        Node(path: Path([bp, Point(progressW * progress, 0) + bp]),
                             lineWidth: lineWidth,
                             lineType: .color(color))]
            }
            let progressNodes = progressNodes(fromWidth: progressWidth)
             
            let nodes: [Node]
            if let tPath {
                nodes = [outlineNode, inlineNode,
                         Node(attitude: Attitude(position: Point(d, d + r + ph)),
                               path: tPath,
                               lineWidth: lineWidth + subLineWidth,
                               lineType: .color(outlineColor)),
                         Node(attitude: Attitude(position: Point(d, d + r + ph)),
                               path: tPath,
                              fillType: .color(color))] + progressNodes
            } else {
                nodes = [outlineNode, inlineNode] + progressNodes
            }
            
            let size = Size(width: max(s, tSize.width, progressWidth) + d * 2,
                            height: s + d * 2 + ah)
            return Node(children: nodes,
                        path: Path(Rect(origin: Point(), size: size)))
        }
        
        return Cursor(lightNode: node(color: lightColor,
                                      outlineColor: lightOutlineColor),
                      darkNode: node(color: darkColor,
                                     outlineColor: darkOutlineColor),
                      hotSpot: hotSpot)
    }
    static func rotate(size s: Double = circleDefaultSize,
                       scale: Double = 1,
                       progress: Double? = nil, progressWidth: Double = 40.0,
                       string: String = "",
                       rotation angle: Double,
                       rotationLength l: Double = 5,
                       lightColor: Color = .content,
                       lightOutlineColor: Color = .background,
                       darkColor: Color = .background,
                       darkOutlineColor: Color = .darkBackground) -> Cursor {
        let lineWidth = circleDefaultLineWidth * scale, subLineWidth = 1.25 * scale
        let d = max(l + subLineWidth / 2 + lineWidth / 2,
                    subLineWidth + lineWidth / 2).rounded(.up)
        let r = s / 2
        
        let tPath: Path?, tSize: Size
        if !string.isEmpty {
            let text = Text(string: string, size: Font.defaultSize)
            let tb = text.frame ?? Rect()
            tSize = tb.size + Size(width: 0, height: 3)
            tPath = text.typesetter.path()
        } else {
            tSize = .init()
            tPath = nil
        }
        
        let ph = progress != nil ? lineWidth + subLineWidth * 2 + 2 : 0
        let ah = tSize.height + ph
        let bcp = Point(d + r, d + r + ah)
        let fp = bcp.movedWith(distance: s / 2 + subLineWidth, angle: angle)
        let lp = bcp.movedWith(distance: s / 2 + l, angle: angle)
        let hotSpot = Point(d + s / 2, -d - s / 2)
        func node(color: Color, outlineColor: Color) -> Node {
            let outlineNode =  Node(path: Path(circleRadius: r + (subLineWidth + lineWidth) / 2,
                                               position: bcp),
                                    lineWidth: lineWidth,
                                    lineType: .color(outlineColor))
            let inlineNode = Node(path: Path(circleRadius: r, position: bcp),
                                  lineWidth: lineWidth,
                                  lineType: .color(color))
            let arrowOutlineNode = Node(path: Path([fp, lp], isClosed: false),
                                        lineWidth: subLineWidth * 2 + lineWidth,
                                        lineType: .color(outlineColor))
            let arrowInlineNode = Node(path: Path([fp, lp], isClosed: false),
                                       lineWidth: lineWidth,
                                       lineType: .color(color))
            
            func progressNodes(fromWidth progressW: Double) -> [Node] {
                guard let progress else { return [] }
                let bp = Point(d, d + (subLineWidth + lineWidth) / 2)
                return [Node(path: Path([bp, Point(progressW * progress, 0) + bp]),
                             lineWidth: lineWidth + subLineWidth * 2,
                             lineType: .color(outlineColor)),
                        Node(path: Path([bp, Point(progressW * progress, 0) + bp]),
                             lineWidth: lineWidth,
                             lineType: .color(color))]
            }
            let progressNodes = progressNodes(fromWidth: progressWidth)
            
            let nodes: [Node]
            if let tPath {
                nodes = [arrowOutlineNode, outlineNode, arrowInlineNode, inlineNode,
                         Node(attitude: Attitude(position: Point(d, d + r + ph)),
                               path: tPath,
                               lineWidth: lineWidth + subLineWidth,
                               lineType: .color(outlineColor)),
                         Node(attitude: Attitude(position: Point(d, d + r + ph)),
                               path: tPath,
                               fillType: .color(color))] + progressNodes
            } else {
                nodes = [arrowOutlineNode, outlineNode, arrowInlineNode, inlineNode] + progressNodes
            }
            
            let size = Size(width: max(s, tSize.width, progressWidth) + d * 2,
                            height: s + d * 2 + ah)
            return Node(children: nodes,
                        path: Path(Rect(origin: Point(), size: size)))
        }
        
        return Cursor(lightNode: node(color: lightColor,
                                      outlineColor: lightOutlineColor),
                      darkNode: node(color: darkColor,
                                     outlineColor: darkOutlineColor),
                      hotSpot: hotSpot)
    }
    static func arrowWith(size s: Double = 12,
                          string: String = "",
                          lightColor: Color = .content,
                          lightOutlineColor: Color = .background,
                          darkColor: Color = .background,
                          darkOutlineColor: Color = .darkBackground) -> Cursor {
        let subLineWidth = 1.5
        let d = subLineWidth.rounded(.up), h = s
        let angle = .pi / 4.0
        let sh = h * 0.75
        let w = h * .sin(angle)
        let path = Path([Point(d, h + d),
                         Point(w + d, h - h * .cos(angle) + d),
                         Point(sh * .sin(angle / 2) + d,
                               h - sh * .cos(angle / 2) + d),
                         Point(d, d)], isClosed: true)
        
        let tPath: Path?, tSize: Size
        if !string.isEmpty {
            let text = Text(string: string, size: Font.defaultSize)
            let tb = text.frame ?? Rect()
            tSize = tb.size + Size(width: 0, height: 3)
            tPath = text.typesetter.path()
        } else {
            tSize = .init()
            tPath = nil
        }
        
        let hotSpot = Point(d, -d)
        
        func node(color: Color, outlineColor: Color) -> Node {
            let outlineNode = Node(attitude: Attitude(position: Point(0, tSize.height)),
                                   path: path,
                                   lineWidth: subLineWidth * 2,
                                   lineType: .color(outlineColor))
            let inlineNode = Node(attitude: Attitude(position: Point(0, tSize.height)),
                                  path: path,
                                  fillType: .color(color))
            
            let nodes: [Node]
            if let tPath {
                let lineWidth = circleDefaultLineWidth, subLineWidth = 1.25
                nodes = [outlineNode, inlineNode,
                         Node(attitude: Attitude(position: Point(d, h / 2)),
                              path: tPath,
                              lineWidth: lineWidth + subLineWidth,
                              lineType: .color(outlineColor)),
                         Node(attitude: Attitude(position: Point(d, h / 2)),
                              path: tPath,
                              fillType: .color(color))]
            } else {
                nodes = [outlineNode, inlineNode]
            }
            
            let size = Size(width: max(w, tSize.width) + d * 2,
                            height: h + d * 2 + tSize.height)
            return Node(children: nodes,
                        path: Path(Rect(origin: Point(), size: size)))
        }
        
        return Cursor(lightNode: node(color: lightColor,
                                      outlineColor: lightOutlineColor),
                      darkNode: node(color: darkColor,
                                     outlineColor: darkOutlineColor),
                      hotSpot: hotSpot)
    }
    
    static func crossWith(size s: Double = circleDefaultSize,
                          scale: Double = 1,
                          string: String = "",
                          lightColor: Color = .content,
                          lightOutlineColor: Color = .background,
                          darkColor: Color = .background,
                          darkOutlineColor: Color = .darkBackground) -> Cursor {
        let lineWidth = circleDefaultLineWidth * scale,
            subLineWidth = 1.5 * scale
        let d = (subLineWidth + lineWidth / 2).rounded(.up)
        let r = s / 2
        let b = Rect(x: d, y: d, width: s, height: s)
        
        let tPath: Path?, tSize: Size
        if !string.isEmpty {
            let text = Text(string: string, size: Font.defaultSize)
            let tb = text.frame ?? Rect()
            tSize = tb.size + Size(width: 0, height: 3)
            tPath = text.typesetter.path()
        } else {
            tSize = .init()
            tPath = nil
        }
        
        let hotSpot = Point(d + s / 2, -d - s / 2)
        
        func node(color: Color, outlineColor: Color) -> Node {
            func crossPath(width w: Double, lineWidth: Double) -> Path {
                let cp = b.centerPoint + Point(0, tSize.height)
                let hlw = lineWidth / 2
                return .init([Point(cp.x - hlw, cp.y + hlw + w), Point(cp.x - hlw, cp.y + hlw),
                              Point(cp.x - hlw - w, cp.y + hlw), Point(cp.x - hlw - w, cp.y - hlw),
                              Point(cp.x - hlw, cp.y - hlw), Point(cp.x - hlw, cp.y - hlw - w),
                              Point(cp.x + hlw, cp.y - hlw - w), Point(cp.x + hlw, cp.y - hlw),
                              Point(cp.x + hlw + w, cp.y - hlw), Point(cp.x + hlw + w,  cp.y + hlw),
                              Point(cp.x + hlw, cp.y + hlw), Point(cp.x + hlw, cp.y + hlw + w)], isClosed: true)
            }
            let outlineNode = Node(path: crossPath(width: r, lineWidth: lineWidth + subLineWidth),
                                   fillType: .color(outlineColor))
            let inlineNode = Node(path: crossPath(width: r, lineWidth: lineWidth),
                                  fillType: .color(color))
            let nodes: [Node]
            if let tPath {
                nodes = [outlineNode, inlineNode,
                         Node(attitude: Attitude(position: Point(d, b.centerPoint.y)),
                               path: tPath,
                               lineWidth: lineWidth + subLineWidth,
                               lineType: .color(outlineColor)),
                         Node(attitude: Attitude(position: Point(d, b.centerPoint.y)),
                               path: tPath,
                               fillType: .color(color))]
            } else {
                nodes = [outlineNode, inlineNode]
            }
            
            let size = Size(width: max(s, tSize.width) + d * 2,
                            height: s + d * 2 + tSize.height)
            return Node(children: nodes,
                        path: Path(Rect(origin: Point(), size: size)))
        }
        
        return Cursor(lightNode: node(color: lightColor,
                                      outlineColor: lightOutlineColor),
                      darkNode: node(color: darkColor,
                                     outlineColor: darkOutlineColor),
                      hotSpot: hotSpot)
    }
    
    static func ban(size s: Double = 12,
                    string: String = "Under development".localized,
                    lightColor: Color = .content,
                    lightOutlineColor: Color = .background,
                    darkColor: Color = .background,
                    darkOutlineColor: Color = .darkBackground) -> Cursor {
        let lineWidth = 2.0, subLineWidth = 1.25
        let d = (subLineWidth + lineWidth / 2).rounded(.up)
        let r = s / 2
        
        let tPath: Path?, tSize: Size
        if !string.isEmpty {
            let text = Text(string: string, size: Font.defaultSize)
            let tb = text.frame ?? Rect()
            tSize = tb.size + Size(width: 0, height: 5)
            tPath = text.typesetter.path()
        } else {
            tSize = .init()
            tPath = nil
        }
        
        let hotSpot = Point(d + s / 2, -d - s / 2)
        
        let ph = 0.0
        let ah = tSize.height + ph
        let bcp = Point(d + r, d + r + ah)
        let lPath = Path([bcp.movedWith(distance: r, angle: .pi * 3 / 4),
                          bcp.movedWith(distance: r, angle: -.pi / 4)], isClosed: false)
        
        func node(color: Color, outlineColor: Color) -> Node {
            let outlineNode = Node(path: Path(circleRadius: r, position: bcp),
                                   lineWidth: lineWidth + subLineWidth * 2,
                                   lineType: .color(outlineColor))
            let lOutlineNode = Node(path: lPath,
                                    lineWidth: lineWidth + subLineWidth * 2,
                                    lineType: .color(outlineColor))
            let inlineNode = Node(path: Path(circleRadius: r, position: bcp),
                                  lineWidth: lineWidth,
                                  lineType: .color(color))
            let lInlineNode = Node(path: lPath,
                                   lineWidth: lineWidth,
                                   lineType: .color(color))
            
            let nodes: [Node]
            if let tPath {
                nodes = [outlineNode, lOutlineNode, inlineNode, lInlineNode,
                         Node(attitude: Attitude(position: Point(d, d + r + ph)),
                               path: tPath,
                               lineWidth: lineWidth + subLineWidth,
                               lineType: .color(outlineColor)),
                         Node(attitude: Attitude(position: Point(d, d + r + ph)),
                               path: tPath,
                              fillType: .color(color))]
            } else {
                nodes = [outlineNode, lOutlineNode, inlineNode, lInlineNode]
            }
            
            let size = Size(width: max(s, tSize.width) + d * 2,
                            height: s + d * 2 + ah)
            return Node(children: nodes,
                        path: Path(Rect(origin: Point(), size: size)))
        }
        
        return Cursor(lightNode: node(color: lightColor,
                                      outlineColor: lightOutlineColor),
                      darkNode: node(color: darkColor,
                                     outlineColor: darkOutlineColor),
                      hotSpot: hotSpot)
    }
    static func rect(size s: Double = 10,
                     lightColor: Color = .content,
                     lightOutlineColor: Color = .background,
                     darkColor: Color = .background,
                     darkOutlineColor: Color = .darkBackground) -> Cursor {
        let subLineWidth = 1.5
        let d = subLineWidth.rounded(.up)
        let b = Rect(x: d, y: d, width: s, height: s)
        let hotSpot = Point(d + s / 2, -d - s / 2)
        
        func node(color: Color, outlineColor: Color) -> Node {
            let outlineNode = Node(path: Path(b),
                                   lineWidth: subLineWidth * 2,
                                   lineType: .color(outlineColor))
            let inlineNode = Node(path: Path(b),
                                  fillType: .color(color))
            let size = Size(width: s + d * 2, height: s + d * 2)
            return Node(children: [outlineNode, inlineNode],
                        path: Path(Rect(origin: Point(), size: size)))
        }
        
        return Cursor(lightNode: node(color: lightColor,
                                      outlineColor: lightOutlineColor),
                      darkNode: node(color: darkColor,
                                     outlineColor: darkOutlineColor),
                      hotSpot: hotSpot)
    }
    
    var lightNode, darkNode: Node
    var hotSpot: Point
    var ns: NSCursor {
        switch Appearance.current {
        case .light: lightNS
        case .dark: darkNS
        }
    }
    private(set) var lightNS: NSCursor
    private(set) var darkNS: NSCursor
    
    init(lightNode: Node, darkNode: Node, hotSpot: Point) {
        let lightSize = lightNode.bounds?.size ?? Size()
        let lightNSImage = NSImage(size: lightSize.cg) { ctx in
            lightNode.renderInBounds(size: lightSize, in: ctx)
        }
        lightNS = NSCursor(image: lightNSImage, hotSpot: hotSpot.cg)
        
        let darkSize = darkNode.bounds?.size ?? Size()
        let darkNSImage = NSImage(size: darkSize.cg) { ctx in
            darkNode.renderInBounds(size: darkSize, in: ctx)
        }
        darkNS = NSCursor(image: darkNSImage, hotSpot: hotSpot.cg)
        
        self.lightNode = lightNode
        self.darkNode = darkNode
        self.hotSpot = hotSpot
    }
}
extension Cursor: Equatable {
    static func == (lhs: Cursor, rhs: Cursor) -> Bool {
        lhs.ns === rhs.ns
    }
}

extension NSImage {
    convenience init(size: NSSize, closure: (CGContext) -> Void) {
        self.init(size: size)
        lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            closure(ctx)
        }
        unlockFocus()
    }
}

extension Point {
    var cg: CGPoint {
        CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}
extension Size {
    var cg: CGSize {
        CGSize(width: CGFloat(width), height: CGFloat(height))
    }
}
extension Rect {
    var cg: CGRect {
        CGRect(origin: origin.cg, size: size.cg)
    }
}
extension Transform {
    var cg: CGAffineTransform {
        CGAffineTransform(a: CGFloat(self[0][0]), b: CGFloat(self[0][1]),
                          c: CGFloat(self[1][0]), d: CGFloat(self[1][1]),
                          tx: CGFloat(self[0][2]), ty: CGFloat(self[1][2]))
    }
}
extension CGPoint {
    var my: Point {
        Point(Double(x), Double(y))
    }
}
extension CGSize {
    var my: Size {
        Size(width: Double(width), height: Double(height))
    }
}
extension CGRect {
    var my: Rect {
        Rect(origin: origin.my, size: size.my)
    }
}

final class TextInputContext {
    private static var current: NSTextInputContext? {
        NSTextInputContext.current
    }
    static func update() {
        current?.invalidateCharacterCoordinates()
    }
    static func unmark() {
        current?.discardMarkedText()
    }
    static var inputSource: String {
        current?.selectedKeyboardInputSource ?? ""
    }
    static var currentLocale: Locale {
        let vs = inputSource.split(separator: ".")
        guard vs.count >= 4
                && vs[0] == "com"
                && vs[1] == "apple"
                && vs[2] == "inputmethod" else { return .autoupdatingCurrent }
        return switch vs[3] {
        case "SCIM": Locale(identifier: "cn")
        case "TYIM": Locale(identifier: "hk")
        case "Korean": Locale(identifier: "kr")
        case "TCIM": Locale(identifier: "tw")
        default: .autoupdatingCurrent
        }
    }
}
struct InputTextEvent: Event {
    var screenPoint: Point, time: Double, pressure: Double, phase: Phase, isRepeat: Bool
    var inputKeyType: InputKeyType
    var ns: NSEvent, inputContext: NSTextInputContext?
}
extension InputTextEvent {
    func send() {
        inputContext?.handleEvent(ns)
    }
}

struct Feedback {
    static func performAlignment() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

extension NSEvent {
    var modifierKeys: ModifierKeys {
        var modifierKeys = ModifierKeys()
        if modifierFlags.contains(.shift) {
            modifierKeys.insert(.shift)
        }
        if modifierFlags.contains(.command) {
            modifierKeys.insert(.command)
        }
        if modifierFlags.contains(.control) {
            modifierKeys.insert(.control)
        }
        if modifierFlags.contains(.option) {
            modifierKeys.insert(.option)
        }
        if modifierFlags.contains(.function) {
            modifierKeys.insert(.function)
        }
        if modifierFlags.contains(.numericPad) {
            modifierKeys.insert(.numericPad)
        }
        return modifierKeys
    }
    var isArrow: Bool {
        if let specialKey {
            switch specialKey {
            case .upArrow, .downArrow, .leftArrow, .rightArrow: true
            default: false
            }
        } else {
            false
        }
    }
    var key: InputKeyType? {
        if let specialKey {
            return switch specialKey {
            case .backspace: .backspace
            case .carriageReturn: .carriageReturn
            case .newline: .newline
            case .enter: .enter
            case .delete: .delete
            case .deleteForward: .deleteForward
            case .backTab: .backTab
            case .tab: .tab
            case .upArrow: .up
            case .downArrow: .down
            case .leftArrow: .left
            case .rightArrow: .right
            case .pageUp: .pageUp
            case .pageDown: .pageDown
            case .home: .home
            case .end: .end
            case .prev: .prev
            case .next: .next
            case .begin: .begin
            case .`break`: .break
            case .clearDisplay: .clearDisplay
            case .clearLine: .clearLine
            case .deleteCharacter: .deleteCharacter
            case .deleteLine: .deleteLine
            case .execute: .execute
            case .find: .find
            case .formFeed: .formFeed
            case .help: .help
            case .insert: .insert
            case .insertCharacter: .insertCharacter
            case .insertLine: .insertLine
            case .lineSeparator: .lineSeparator
            case .menu: .menu
            case .modeSwitch: .modeSwitch
            case .paragraphSeparator: .paragraphSeparator
            case .pause: .pause
            case .print: .print
            case .printScreen: .printScreen
            case .redo: .redo
            case .reset: .reset
            case .scrollLock: .scrollLock
            case .select: .select
            case .stop: .stop
            case .sysReq: .sysReq
            case .system: .system
            case .undo: .undo
            case .user: .user
            case .f1: .f1
            case .f2: .f2
            case .f3: .f3
            case .f4: .f4
            case .f5: .f5
            case .f6: .f6
            case .f7: .f7
            case .f8: .f8
            case .f9: .f9
            case .f10: .f10
            case .f11: .f11
            case .f12: .f12
            case .f13: .f13
            case .f14: .f14
            case .f15: .f15
            case .f16: .f16
            case .f17: .f17
            case .f18: .f18
            case .f19: .f19
            case .f20: .f20
            case .f21: .f21
            case .f22: .f22
            case .f23: .f23
            case .f24: .f24
            case .f25: .f25
            case .f26: .f26
            case .f27: .f27
            case .f28: .f28
            case .f29: .f29
            case .f30: .f30
            case .f31: .f31
            case .f32: .f32
            case .f33: .f33
            case .f34: .f34
            case .f35: .f35
            default: .unknown
            }
        }
        
        guard let charactersIM = self.charactersIgnoringModifiers else { return nil }
        return switch charactersIM {
        case "\u{1B}": .escape
        case " ": .space
        case "a", "A": .a
        case "b", "B": .b
        case "c", "C": .c
        case "d", "D": .d
        case "e", "E": .e
        case "f", "F": .f
        case "g", "G": .g
        case "h", "H": .h
        case "i", "I": .i
        case "j", "J": .j
        case "k", "K": .k
        case "l", "L": .l
        case "m", "M": .m
        case "n", "N": .n
        case "o", "O": .o
        case "p", "P": .p
        case "q", "Q": .q
        case "r", "R": .r
        case "s", "S": .s
        case "t", "T": .t
        case "u", "U": .u
        case "v", "V": .v
        case "w", "W": .w
        case "x", "X": .x
        case "y", "Y": .y
        case "z", "Z": .z
        case "0": .no0
        case "1": .no1
        case "2": .no2
        case "3": .no3
        case "4": .no4
        case "5": .no5
        case "6": .no6
        case "7": .no7
        case "8": .no8
        case "9": .no9
        case "!": .exclamationMark
        case "\"": .quotationMarks
        case "#": .numberSign
        case "$": .dollarSign
        case "%": .percentSign
        case "&": .ampersand
        case "'": .apostrophe
        case "(": .leftParentheses
        case ")": .rightParentheses
        case "-": .minus
        case "=": .equals
        case "^": .backApostrophe
        case "~": .tilde
        case "¥": .yuanSign
        case "|": .verticalBar
        case "@": .atSign
        case "`": .graveAccent
        case "[": .leftBracket
        case "{": .leftBrace
        case ";": .semicolon
        case "+": .plus
        case ":": .colon
        case "*": .asterisk
        case "]": .rightBracket
        case "}": .rightBrace
        case ",": .comma
        case "<": .lessThanSign
        case ".": .period
        case ">": .greaterThanSign
        case "/": .backslash
        case "?": .questionMark
        case "_": .underscore
        default: if let characters { .init(name: characters) } else { nil }
        }
    }
}
