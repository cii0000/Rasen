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

import AppKit
import Accelerate
import AVFoundation

@objc(SubNSApplication)
final class SubNSApplication: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyUp && event.modifierFlags.contains(.command) {
            keyWindow?.sendEvent(event)
        } else {
            super.sendEvent(event)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate,
                         NSMenuDelegate {
    static let isFullscreenKey = "isFullscreen"
    static let defaultViewSize = NSSize(width: 900, height: 700)
    var window: NSWindow!
    var view: SubMTKView
    weak var fileMenu: NSMenu?, editMenu: NSMenu?, editMenuItem: NSMenuItem?
    
    override init() {
        AppDelegate.updateSelectedColor()
        
        view = SubMTKView(url: URL.library)
        super.init()
        
        NotificationCenter.default.addObserver(forName: NSColor.systemColorsDidChangeNotification,
                                               object: nil, queue: nil) { [weak self] (_) in
            self?.updateSelectedColor()
        }
    }
    deinit {
        urlTimer.cancel()
    }
    
    func updateSelectedColor() {
        AppDelegate.updateSelectedColor()
        if window.isMainWindow {
            view.document.updateSelectedColor(isMain: true)
        }
    }
    static func updateSelectedColor() {
        var selectedColor = Color(NSColor.controlAccentColor.cgColor)
        selectedColor.white = Color.selectedWhite
        Color.selected = selectedColor
        Renderer.shared.appendColorBuffer(with: selectedColor)
        
        var subSelectedColor = Color(NSColor.selectedControlColor.cgColor)
        subSelectedColor.white = Color.subSelectedWhite
        subSelectedColor.opacity = Color.subSelectedOpacity
        Color.subSelected = subSelectedColor
        Renderer.shared.appendColorBuffer(with: subSelectedColor)
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
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
        
        view.document.restoreDatabase()
        view.document.cursorPoint = view.clippedScreenPointFromCursor.my
        
        SubNSApplication.shared.servicesMenu = NSMenu()
        SubNSApplication.shared.mainMenu = mainMenu()
    }
    private func mainMenu() -> NSMenu {
        let appName = System.appName
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
        fileMenu.addItem(withTitle: "Import Document...".localized,
                         action: #selector(SubMTKView.importDocument(_:)))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Export as Image...".localized,
                         action: #selector(SubMTKView.exportAsImage(_:)))
        fileMenu.addItem(withTitle: "Export as PDF...".localized,
                         action: #selector(SubMTKView.exportAsPDF(_:)))
        fileMenu.addItem(withTitle: "Export as GIF...".localized,
                         action: #selector(SubMTKView.exportAsGIF(_:)))
        fileMenu.addItem(withTitle: "Export as Movie...".localized,
                         action: #selector(SubMTKView.exportAsMovie(_:)))
        fileMenu.addItem(withTitle: "Export as 4K Movie...".localized,
                         action: #selector(SubMTKView.exportAsHighQualityMovie(_:)))
        fileMenu.addItem(withTitle: "Export as Sound...".localized,
                         action: #selector(SubMTKView.exportAsSound(_:)))
        fileMenu.addItem(withTitle: "Export as Caption...".localized,
                         action: #selector(SubMTKView.exportAsCaption(_:)))
        
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Export as Document...".localized,
                         action: #selector(SubMTKView.exportAsDocument(_:)))
        fileMenu.addItem(withTitle: "Export as Document with History...".localized,
                         action: #selector(SubMTKView.exportAsDocumentWithHistory(_:)))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Clear History...".localized,
                         action: #selector(SubMTKView.clearHistory(_:)))
        if System.isVersion3 {
            fileMenu.addItem(NSMenuItem.separator())
            fileMenu.addItem(withTitle: "Show About Run".localized,
                             action: #selector(SubMTKView.showAboutRun(_:)))
        }
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
                           keyEquivalent: "w", modifierFlags: [.command])
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
    
    func applicationShouldTerminateAfterLastWindowClosed(_ document: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        view.document.endSave { _ in
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
            let urls = self.urls.filter { $0 != self.view.document.url }
            if urls.count == 1
                && urls[0].pathExtension == Document.FileType.rasendata.filenameExtension {
                
                self.view.replaceDatabase(from: urls[0])
            } else {
                guard !urls.isEmpty else { return }
                let editor = IOEditor(self.view.document)
                let sp =  self.view.bounds.my.centerPoint
                let shp = editor.beginImport(at: sp)
                editor.import(from: urls, at: shp)
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
        view.document.updateSelectedColor(isMain: true)
    }
    func windowDidResignMain(_ notification: Notification) {
        view.document.updateSelectedColor(isMain: false)
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
        view.document.stopAllEvents()
        view.draw()
    }
    func windowDidEndSheet(_ notification: Notification) {
        updateDocumentFromWindow()
    }
    func windowDidResignKey(_ notification: Notification) {
        view.document.stopAllEvents(isEnableText: false)
    }
    func updateDocumentFromWindow() {
        view.document.stopAllEvents(isEnableText: false)
        view.document.cursorPoint = view.screenPointFromCursor.my
        view.document.updateTextCursor()
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
        let string = try! String(contentsOf: url)
        acknowledgmentsPanel
            = AppDelegate.makePanel(from: string,
                                    title: "Acknowledgments".localized)
    }
    
    static func makePanel(from string: String, title: String) -> NSPanel {
        let nsFrame = NSRect(x: 0, y: 0, width: 550, height: 620)
        let nsTextView = NSTextView(frame: nsFrame)
        nsTextView.string = string
        nsTextView.isEditable = false
        nsTextView.autoresizingMask = [.width, .height,
                                     .minXMargin, .maxXMargin,
                                     .minYMargin, .maxYMargin]
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

enum Appearance {
    case light, dark
    
    static var current: Appearance = .light
}

private extension NSImage {
    static func iconNodes(centerP scp: Point, scale: Double, r: Double, lineWidth lw: Double,
                          documentWidth: Double = 0,
                          in nb: Rect) -> [Node] {
        func spiralPathline(a: Double = 0.25, b: Double = -0.25,
                        angle: Double,
                        firstT: Double,
                        lastT: Double = -50) -> Pathline {
            var ps = [Point]()
            for i in (0 ... 1000).reversed() {
                let t = (Double(i) / 1000).clipped(min: 0, max: 1,
                                                 newMin: firstT,
                                                 newMax: lastT)
                let x = a ** (b * t) * .cos(t + angle)
                let y = a ** (b * t) * .sin(t + angle)
                
                let p = Point(x, y) * scale + scp
                if nb.contains(p) {
                    ps.append(p)
                } else {
                    ps.append(nb.clipped(p))
                    break
                }
            }
            return Pathline(ps, isClosed: false)
        }
        
        let sp0 = spiralPathline(angle: 0, firstT: 5)
        let sp1 = spiralPathline(angle: 2 * .pi / 3, firstT: 5)
        let sp2 = spiralPathline(angle: 2 * .pi * 2 / 3, firstT: 5)
        
        var pls0 = [Pathline.Element]()
        pls0 += Pathline.squircle(p0: nb.maxXMaxYPoint,
                                p1: nb.minXMaxYPoint,
                                p2: nb.minXMinYPoint, r: r)
        let pls0p = pls0.first?.lastPoint ?? .init()
        pls0 += sp0.elements.reversed()
        pls0 += sp2.elements
        
        var pls1 = [Pathline.Element]()
        if documentWidth > 0 {
            pls1 += [.linear(nb.maxXMaxYPoint + Point(0, -documentWidth)),
                     .linear(nb.maxXMaxYPoint + Point(-documentWidth, 0))]
        } else {
            pls1 += Pathline.squircle(p0: nb.maxXMinYPoint,
                                    p1: nb.maxXMaxYPoint,
                                    p2: nb.minXMaxYPoint, r: r)
        }
        let pls1p = pls1.first?.lastPoint ?? .init()
        pls1 += sp2.elements.reversed()
        pls1 += sp1.elements
          
        let color0 = Color(red: 0.0011757521, green: 0.7693206, blue: 0.91262335)
        let color1 = Color(red: 0.99986285, green: 0.87789917, blue: 0.84061176)
        return [Node(path: Path([Pathline(firstPoint: pls0p,
                                          elements: pls0,
                                          isClosed: true)],
                                isPolygon: false),
                     fillType: .color(color0)),
                Node(path: Path([Pathline(firstPoint: pls1p,
                                          elements: pls1,
                                          isClosed: true)],
                                isPolygon: false),
                     fillType: .color(color1)),
                Node(path: Path([sp0]),
                     lineWidth: lw, lineType: .color(.content)),
                Node(path: Path([sp1]),
                     lineWidth: lw, lineType: .color(.content)),
                Node(path: Path([sp2]),
                     lineWidth: lw, lineType: .color(.content))]
    }
    static func exportAppIcon() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.begin { [weak panel] result in
            guard let panel = panel else { return }
            guard result == .OK else { return }
            guard let url = panel.url else { return }
            for width in [16, 32, 64, 128, 256, 512, 1024] as [Double] {
                let size = CGSize(width: width, height: width)
                let nsImage = NSImage(size: size, flipped: false) { rect -> Bool in
                    let ctx = NSGraphicsContext.current!.cgContext
                    let rect = rect.my
                    
                    let cp = rect.centerPoint
                    let lw = width * 15 / 1024
                    let r = (width * (1024 - 100 * 2) / 1024 - lw) / 2
                    let nb = Rect(x: cp.x - r, y: cp.y - r,
                                  width: r * 2, height: r * 2)
                    
                    let path = Path(nb, cornerRadius: r * 0.43)
                    let scp = cp + Point(-r * 0.125, r * 0.0625), scale = r * 2 * 1.25
                    let nNodes = [Node(path: path,
                                       fillType: .color(.background))]
                    + iconNodes(centerP: scp, scale: scale, r: r * 0.43, lineWidth: lw, in: nb)
                    + [Node(path: path,
                            lineWidth: lw, lineType: .color(.content))]
                    let node = Node(children: nNodes,
                                    path: Path(rect))
                    
                    let image = node.imageInBounds(size: rect.size,
                                                   backgroundColor: Color(lightness: 0, opacity: 0),
                                                   colorSpace: .p3)
                    image?.render(in: ctx)
                    
                    return true
                }
                try? nsImage.PNGRepresentation?
                    .write(to: url.appendingPathComponent("\(String(Int(width))).png"))
            }
        }
    }
    
    // $ iconutil -c icns DATAIcon.iconset
    // $ iconutil -c icns DOCHIcon.iconset
    // $ iconutil -c icns DOCIcon.iconset
    enum DocumentIconType: String {
        case doc = "DOC", doch = "DOCH", data = "DATA"
    }
    static func exportDocumentIcon(_ type: DocumentIconType) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.begin { [weak panel] result in
            guard let panel = panel else { return }
            guard result == .OK else { return }
            guard let url = panel.url else { return }
            for width in [16, 32, 64, 128, 256, 512, 1024] as [Double] {
                let size = CGSize(width: width, height: width)
                let nsImage = NSImage(size: size, flipped: false) { rect -> Bool in
                    let ctx = NSGraphicsContext.current!.cgContext
                    let rect = rect.my
                    
                    let cp = rect.centerPoint
                    let w = width * 348 / 1024, lw = width * 15 / 1024
                    let h = (w * sqrt(2)).rounded()
                    let b = Rect(x: cp.x - w, y: cp.y - h,
                                 width: w * 2, height: h * 2)
                    
                    let dd = b.height / 4
                    let mr = dd / 3
                    
                    var pls = [Pathline.Element]()
                    pls.append(.linear(Point(b.maxX - dd, b.maxY)))
                    pls += Pathline.squircle(p0: b.maxXMaxYPoint,
                                             p1: b.minXMaxYPoint,
                                             p2: b.minXMinYPoint, r: mr)
                    pls += Pathline.squircle(p0: b.minXMaxYPoint,
                                             p1: b.minXMinYPoint,
                                             p2: b.maxXMinYPoint, r: mr)
                    pls += Pathline.squircle(p0: b.minXMinYPoint,
                                             p1: b.maxXMinYPoint,
                                             p2: b.maxXMaxYPoint, r: mr)
                    let path = Path([Pathline(firstPoint: Point(b.maxX, b.maxY - dd),
                                              elements: pls,
                                              isClosed: true)])
                    
                    var apls = [Pathline.Element]()
                    apls += Pathline.squircle(p0: Point(b.maxX - dd, b.maxY),
                                              p1: Point(b.maxX - dd, b.maxY - dd),
                                              p2: Point(b.maxX, b.maxY - dd),
                                              r: mr)
                    apls.append(.linear(Point(b.maxX, b.maxY - dd)))
                    let roundPath = Path([Pathline(firstPoint: Point(b.maxX - dd, b.maxY),
                                                   elements: apls,
                                                   isClosed: true)])
                    
                    let r = w
                    let scp = Point(b.midX, b.height - r) + Point(-r * 0.125, r * 0.0625), scale = r * 2 * 1.25
                    let nNodes = [Node(path: path,
                                       fillType: .color(.background))]
                    + iconNodes(centerP: scp, scale: scale, r: mr, lineWidth: lw,
                                documentWidth: dd,
                                in: Rect(x: b.minX, y: b.maxY - r * 2, width: r * 2, height: r * 2))
                    + [Node(path: path,
                            lineWidth: lw,
                            lineType: .color(.content)),
                       Node(path: roundPath,
                            lineWidth: lw,
                            lineType: .color(.content),
                            fillType: .color(.background))]
                    let node = Node(children: nNodes,
                                    path: Path(rect))
                    let image = node.imageInBounds(size: rect.size,
                                                   backgroundColor: Color(lightness: 0, opacity: 0),
                                                   colorSpace: .p3)
                    image?.render(in: ctx)
                    
                    ctx.setFillColor(Color.content.cg)
                    
                    var text = Text(string: type.rawValue,
                                    size: Double(w) * 17 / 36)
                    var typobute = text.typobute
                    typobute.font.isProportional = true
                    typobute.maxTypelineWidth = b.width
                    typobute.clippedMaxTypelineWidth = b.width
                    let typesetter = Typesetter(string: text.string,
                                                typobute: typobute)
                    let f = typesetter.typoBounds!
                    let p = Point(b.centerPoint.x, b.height * 0.225)
                    text.origin = p - (f + text.origin).centerPoint
                    ctx.saveGState()
                    ctx.translateBy(x: CGFloat(text.origin.x),
                                    y: CGFloat(text.origin.y))
                    typesetter.draw(in: b,
                                    fillColor: .content,
                                    in: ctx)
                    ctx.restoreGState()
                    
                    return true
                }
                try? nsImage.PNGRepresentation?
                    .write(to: url.appendingPathComponent("\(String(Int(width))).png"))
            }
        }
    }
    
    final var bitmapSize: CGSize {
        if let tiffRepresentation = tiffRepresentation {
            if let bitmap = NSBitmapImageRep(data: tiffRepresentation) {
                return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
            }
        }
        return CGSize()
    }
    final var PNGRepresentation: Data? {
        if let tiffRepresentation = tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffRepresentation) {
            
            return bitmap.representation(using: .png, properties: [.interlaced: false])
        } else {
            return nil
        }
    }
}

struct UTType {
    fileprivate var uti: UniformTypeIdentifiers.UTType
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

protocol FileTypeProtocol {
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
    static func load(message: String? = nil,
                     directoryURL: URL? = nil,
                     prompt: String? = nil,
                     canChooseDirectories: Bool = false,
                     allowsMultipleSelection: Bool = false,
                     fileTypes: [FileTypeProtocol],
                     completionClosure closure: @escaping ([IOResult]) -> (),
                     cancelClosure: @escaping () -> () = {}) {
        guard let window = SubNSApplication.shared.mainWindow else { return }
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
        loadPanel.beginSheetModal(for: window) { [weak loadPanel] result in
            guard let loadPanel = loadPanel else { return }
            if result == .OK {
                let isExtensionHidden = loadPanel.isExtensionHidden
                let urls = loadPanel.url != nil && loadPanel.urls.count <= 1 ?
                    [loadPanel.url!] : loadPanel.urls
                let results = urls.map {
                    IOResult(url: $0, name: $0.lastPathComponent,
                             isExtensionHidden: isExtensionHidden)
                }
                closure(results)
            } else {
                cancelClosure()
            }
        }
    }
    static func save(message: String? = nil,
                     name: String? = nil,
                     directoryURL: URL? = nil,
                     prompt: String? = nil,
                     fileTypes: [FileTypeProtocol],
                     completionClosure closure: @escaping (IOResult) -> (),
                     cancelClosure: @escaping () -> () = {}) {
        guard let window = SubNSApplication.shared.mainWindow else { return }
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
        savePanel.beginSheetModal(for: window) { [weak savePanel] result in
            guard let savePanel = savePanel else { return }
            if result == .OK, let url = savePanel.url {
                closure(IOResult(url: url,
                                 name: savePanel.nameFieldStringValue,
                                 isExtensionHidden: savePanel.isExtensionHidden))
            } else {
                cancelClosure()
            }
        }
    }
    static func export(message: String? = nil,
                       name: String? = nil,
                       directoryURL: URL? = nil,
                       fileType: FileTypeProtocol,
                       fileTypeOptionName: String? = nil,
                       fileSizeHandler: @escaping () -> (Int?),
                       completionClosure closure: @escaping (IOResult) -> (),
                       cancelClosure: @escaping () -> () = {}) {
        guard let window = SubNSApplication.shared.mainWindow else { return }
        
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
        
        let fileSizeValueView = NSTextField(labelWithString: "Calculating Size...".localized)
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
        
        DispatchQueue.global().async {
            let string: String
            if let fileSize = fileSizeHandler() {
                string = IOResult.fileSizeNameFrom(fileSize: fileSize)
            } else {
                string = "--"
            }
            DispatchQueue.main.async {
                fileSizeValueView.stringValue = string
                fileSizeValueView.sizeToFit()
            }
        }
        
        savePanel.canSelectHiddenExtension = true
        savePanel.beginSheetModal(for: window) { [weak savePanel] result in
            guard let savePanel = savePanel else { return }
            if result == .OK, let url = savePanel.url {
                closure(IOResult(url: url,
                                 name: savePanel.nameFieldStringValue,
                                 isExtensionHidden: savePanel.isExtensionHidden))
            } else {
                cancelClosure()
            }
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
        let urls = FileManager.default
            .enumerator(at: self,
                        includingPropertiesForKeys: nil)?.allObjects as? [URL]
        urls?.lazy.forEach {
            fileSize += (try? $0.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?
                .totalFileAllocatedSize ?? 0
        }
        return fileSize
    }
    static var readError: Error {
        NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
    }
    static var writeError: Error {
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
        let directoryURL = FileManager.default.urls(for: .libraryDirectory,
                                                    in: .userDomainMask)[0]
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
}

struct Sleep {
    static func start(atTime t: Double = 0.06) {
        usleep(useconds_t(1000000 * t))
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}

extension URLSession {
    static func attributedString(fromURLString str: String,
                                 completionHandler: @escaping (NSAttributedString?) -> ()) {
        guard let str = str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: str) else { return }
        
        let request = URLRequest(url: url)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data else { return }
            
            let attString = try? NSAttributedString(data: data,
                                                    options: [.documentType: NSAttributedString.DocumentType.html,
                                                              .characterEncoding: String.Encoding.utf8.rawValue],
                                                    documentAttributes: nil)
            completionHandler(attString)
        }
        task.resume()
    }
}

struct System {
    static let appName = "Rasen".localized
    static let dataName = String(format: "%@ Data".localized, appName)
    static let id = Bundle.main.bundleIdentifier ?? "net.cii0.Rasen"
    
    static let oldAppName = "Shikishi".localized
    static let oldDataName = String(format: "%@ Data".localized, oldAppName)
    static let oldID = "net.cii0.Shikishi"
    
    static let version = Bundle.main
        .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "1.0"
    static let isVersion3 = version >= "3.0"
    
    static var usedMemory: UInt64? {
        var info = mach_task_basic_info()
        var count = UInt32(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : nil
    }
    static var freeMemory: UInt64? {
        var count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size) as mach_msg_type_number_t
        var info = vm_statistics64()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), host_flavor_t(HOST_VM_INFO64),
                                  $0, &count)
            }
        }
        return result == KERN_SUCCESS ?
            UInt64(info.free_count) * UInt64(vm_kernel_page_size) : nil
    }
    static var memoryTotalBytes: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }
    static var memoryRatio: Double? {
        if let usedMemory = usedMemory {
            return Double(usedMemory) / Double(memoryTotalBytes)
        } else {
            return nil
        }
    }
    static var freeMemoryRatio: Double? {
        if let freeMemory = freeMemory {
            return Double(freeMemory) / Double(memoryTotalBytes)
        } else {
            return nil
        }
    }
    static var memoryDisplayString: String {
        let um = ByteCountFormatter.string(fromByteCount: Int64(usedMemory ?? 0),
                                           countStyle: .memory)
        let tb = ByteCountFormatter.string(fromByteCount: Int64(memoryTotalBytes),
                                           countStyle: .memory)
        return "\(um) / \(tb)"
    }
}

final class Pasteboard {
    static let shared = Pasteboard()
    
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
            if let object = try? PastableObject(data: data, typeName: type.rawValue) {
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
            let range = CFRange(location: 0,
                                length: (nstr as NSString).length)
            guard let nnstr = DCSCopyTextDefinition(nil,
                                                    nstr as CFString,
                                                    range)?
                    .takeRetainedValue() as String? else { return nil }
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

final class CodeView: NSView {
    var closure: (Bool) -> ()
    
    let titleView: NSTextField
    let codeView: SubNSTextField
    
    init(codeName: String, closure: @escaping (Bool) -> ()) {
        self.closure = closure
        
        titleView = NSTextField(wrappingLabelWithString: String(format: "To enable the Run button, enter \"%@\" in the text box below.".localized, codeName))
        titleView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        titleView.frame = NSRect(x: 0, y: 0, width: 280, height: 30)
        codeView = SubNSTextField(frame: NSRect(), closure: { _ in })
        codeView.stringValue = codeName
        codeView.sizeToFit()
        codeView.frame.size.width = 100
        codeView.stringValue = ""
        titleView.frame.origin = NSPoint(x: 0, y: codeView.frame.height + 5)
        super.init(frame: NSRect(x: 0, y: 0, width: max(codeView.frame.width, titleView.frame.width), height: titleView.frame.height + codeView.frame.height + 5))
        addSubview(codeView)
        addSubview(titleView)
        codeView.closure = { [weak self] str in
            self?.closure(str == codeName)
        }
    }
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class SubNSTextField: NSTextField {
    var closure: (String) -> () = { (_) in }
    
    init(frame: NSRect, closure: @escaping (String) -> ()) {
        self.closure = closure
        super.init(frame: frame)
    }
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func textDidChange(_ notification: Notification) {
        closure(stringValue)
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
            (superview as? SubMTKView)?.document.cursor.ns.set()
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
                  pressure: Double(nsEvent.pressure), phase: phase)
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
            (superview?.superview as? SubMTKView)?.document.cursor.ns.set()
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

final class ProgressPanel: NSWindow {
    weak var window: NSWindow?
    fileprivate var progressIndicator
        = NSProgressIndicator(frame: NSRect(x: 20, y: 50, width: 360, height: 20))
    fileprivate var titleField: NSTextField
    fileprivate var cancelButton
        = NSButton(frame: NSRect(x: 278, y: 8, width: 110, height: 40))
    private let isIndeterminate: Bool
    init(message: String, isCancel: Bool = true, isIndeterminate: Bool = false) {
        self.message = message
        titleField = NSTextField(labelWithString: message)
        titleField.frame.origin = NSPoint(x: 18, y: 80)
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        self.isIndeterminate = isIndeterminate
        if isIndeterminate {
            progressIndicator.isIndeterminate = isIndeterminate
        }
        cancelButton.bezelStyle = .rounded
        cancelButton.setButtonType(.onOff)
        cancelButton.title = "Cancel".localized
        cancelButton.action = #selector(ProgressPanel.cancel(_:))
        if !isCancel {
            cancelButton.isEnabled = false
        }
        let b = NSRect(x: 0, y: 0, width: 400, height: 110)
        let view = NSView(frame: b)
        view.addSubview(titleField)
        view.addSubview(progressIndicator)
        view.addSubview(cancelButton)
        super.init(contentRect: b,
                   styleMask: .titled, backing: .buffered, defer: true)
        contentView = view
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
        center()
        makeKeyAndOrderFront(nil)
        begin()
    }
    func closePanel() {
        if !isCancel {
            progressIndicator.doubleValue = 1
            progressIndicator.isIndeterminate = true
        }
        progressIndicator.stopAnimation(nil)
        if isSheet {
            window?.endSheet(self)
        }
    }
    var isCancel = false
    @objc func cancel(_ sender: Any) {
        isCancel = true
        cancelButton.state = .on
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
        CGColor.with(rgb: rgba, alpha: opacity,
                     colorSpace: rgbColorSpace.cg ?? .default)
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
extension RGBColorSpace {
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

struct Image {
    let cg: CGImage
    
    init(cgImage: CGImage) {
        self.cg = cgImage
    }
    init?(url: URL) {
        let dic = [kCGImageSourceShouldCacheImmediately: kCFBooleanTrue]
        guard let s = CGImageSourceCreateWithURL(url as CFURL,
                                                 dic as CFDictionary),
              let image = CGImageSourceCreateImageAtIndex(s, 0, dic as CFDictionary) else { return nil }
        cg = image
    }
    init?(size: Size, color: Color) {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let ctx = CGContext(data: nil,
                                  width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: color.rgbColorSpace.cg ?? .default,
                                  bitmapInfo: bitmapInfo.rawValue) else { return nil }
        ctx.setFillColor(color.cg)
        ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        guard let nCGImage = ctx.makeImage() else { return nil }
        self.cg = nCGImage
    }
    func resize(with size: Size) -> Image? {
        let cgColorSpace: Unmanaged<CGColorSpace>?
        if let cs = cg.colorSpace {
            cgColorSpace = Unmanaged.passUnretained(cs)
        } else {
            cgColorSpace = nil
        }
        var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32,
                                          colorSpace: cgColorSpace,
                                          bitmapInfo: cg.bitmapInfo,
                                          version: 0, decode: nil,
                                          renderingIntent: .defaultIntent)
        
        var sourceBuffer = vImage_Buffer()
        defer {
            sourceBuffer.data.deallocate()
        }
        var error = vImageBuffer_InitWithCGImage(&sourceBuffer,
                                                 &format, nil, cg,
                                                 numericCast(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        
        let w = Int(size.width), h = Int(size.height)
        let bytesPerPixel = 4
        let destBytesPerPixel = w * bytesPerPixel
        let destData = UnsafeMutablePointer<UInt8>.allocate(capacity: h * destBytesPerPixel)
        defer {
            destData.deallocate()
        }
        
        var destBuffer = vImage_Buffer(data: destData,
                                       height: vImagePixelCount(h),
                                       width: vImagePixelCount(w),
                                       rowBytes: destBytesPerPixel)
        
        error = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil,
                                     numericCast(kvImageDoNotTile))
        guard error == kvImageNoError else { return nil }
        
        let newCGImage = vImageCreateCGImageFromBuffer(&destBuffer,
                                                       &format, nil, nil,
                                                       numericCast(kvImageNoFlags),
                                                       &error)
        guard error == kvImageNoError,
              let nCGImage = newCGImage else { return nil }
        
        return Image(cgImage: nCGImage.takeRetainedValue())
    }
    
    func drawn(_ image: Image, in rect: Rect) -> Image? {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let ctx = CGContext(data: nil,
                                  width: cg.width, height: cg.height,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cg.colorSpace ?? .default,
                                  bitmapInfo: bitmapInfo.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0,
                                width: cg.width,
                                height: cg.height))
        ctx.draw(image.cg, in: rect.cg)
        guard let nImage = ctx.makeImage() else { return nil }
        return Image(cgImage: nImage)
    }
    
    var size: Size {
        cg.size
    }
    var texture: Texture? {
        if let data = self.data(.jpeg) {
            return Texture(data: data, isOpaque: true)
        }
        return nil
    }
    
    func render(in ctx: CGContext) {
        ctx.draw(cg, in: CGRect(x: 0, y: 0,
                                width: cg.width, height: cg.height))
    }
}
extension Image {
    enum FileType: FileTypeProtocol, CaseIterable {
        case png, jpeg, tiff, gif, pngs
        var name: String {
            switch self {
            case .png: "PNG"
            case .jpeg: "JPEG"
            case .tiff: "TIFF"
            case .gif: "GIF"
            case .pngs: "PNGs".localized
            }
        }
        var utType: UTType {
            switch self {
            case .png: UTType(.png)
            case .jpeg: UTType(.jpeg)
            case .tiff: UTType(.tiff)
            case .gif: UTType(.gif)
            case .pngs: UTType(exportedAs: "\(System.id).rasenpngs")
            }
        }
    }
    
    func data(_ type: FileType, size: Size, to url: URL) -> Data? {
        guard let v = size == self.size ?
                self : resize(with: size) else {
            return nil
        }
        return v.cg.data(type)
    }
    func data(_ type: FileType) -> Data? {
        cg.data(type)
    }
    func write(_ type: FileType, size: Size, to url: URL) throws {
        guard let v = size == self.size ?
                self : resize(with: size) else {
            throw URL.writeError
        }
        try v.write(type, to: url)
    }
    func write(_ type: FileType, to url: URL) throws {
        try cg.write(type, to: url)
    }
    static func writeGIF(_ images: [(image: Image, time: Rational)], to url: URL) throws {
        guard !images.isEmpty,
              let d = CGImageDestinationCreateWithURL(url as CFURL, UniformTypeIdentifiers.UTType.gif.identifier as CFString, images.count, nil) else {
            throw URL.writeError
        }
        let properties = [(kCGImagePropertyGIFDictionary as String):
                            [(kCGImagePropertyGIFLoopCount as String): 0]]
        CGImageDestinationSetProperties(d, properties as CFDictionary)
        for (image, time) in images {
            let properties = [(kCGImagePropertyGIFDictionary as String):
                                [(kCGImagePropertyGIFDelayTime as String): Float(time)]]
            CGImageDestinationAddImage(d, image.cg, properties as CFDictionary)
        }
        if !CGImageDestinationFinalize(d) {
            throw URL.writeError
        }
    }
    func convertRGBA() -> Image? {
        if cg.alphaInfo == .premultipliedLast {
            return self
        }
        guard let cs = cg.colorSpace,
              let ctx = CGContext(data: nil,
                        width: cg.width, height: cg.height,
                        bitsPerComponent: cg.bitsPerComponent,
                        bytesPerRow: cg.bytesPerRow, space: cs,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue |
                                  CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        if let ncg = ctx.makeImage() {
            return Image(cgImage: ncg)
        } else {
            return nil
        }
    }
    
    static func metadata(from url: URL) -> [String: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let dic = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                  return [:]
              }
        return dic
    }
    func write(_ type: FileType, to url: URL,
               metadata: [String: Any]) throws {
        guard let des = CGImageDestinationCreateWithURL(url as CFURL, type.utType.uti.identifier as CFString, 1, nil) else {
            throw URL.writeError
        }
        CGImageDestinationAddImage(des, cg, metadata as CFDictionary)
        CGImageDestinationFinalize(des)
    }
}
extension Image: Hashable {}
extension Image: Codable {
    struct CodableError: Error {}
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        guard let cgImageSource
                = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CodableError()
        }
        guard let cg
                = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            throw CodableError()
        }
        self.cg = cg
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let data = data(.jpeg) {
            try container.encode(data)
        } else {
            throw CodableError()
        }
    }
}
extension Image: Serializable {
    struct SerializableError: Error {}
    init(serializedData data: Data) throws {
        guard let cgImageSource
                = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw SerializableError()
        }
        guard let cg
                = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            throw SerializableError()
        }
        self.cg = cg
    }
    func serializedData() throws -> Data {
        if let data = data(.jpeg) {
            return data
        } else {
            throw SerializableError()
        }
    }
}

final class PDF {
    enum FileType: FileTypeProtocol, CaseIterable {
        case pdf
        var name: String {
            switch self {
            case .pdf: "PDF"
            }
        }
        var utType: UTType {
            switch self {
            case .pdf: UTType(.pdf)
            }
        }
    }
    
    let ctx: CGContext
    private var mData: NSMutableData?
    var data: Data? {
        mData as Data?
    }
    
    init(mediaBox: Rect) throws {
        var mb = mediaBox.cg
        let data = NSMutableData()
        self.mData = data
        guard let dc = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: dc, mediaBox: &mb, nil) else {
            
            throw URL.writeError
        }
        self.ctx = ctx
    }
    init(url: URL, mediaBox: Rect) throws {
        let cfURL = url as CFURL
        var mb = mediaBox.cg
        guard let ctx = CGContext(cfURL, mediaBox: &mb, nil) else {
            throw URL.writeError
        }
        self.ctx = ctx
    }
    func finish() {
        ctx.closePDF()
    }
    var dataSize: Int {
        mData?.length ?? 0
    }
    func newPage(handler: (PDF) -> ()) {
        ctx.beginPDFPage(nil)
        handler(self)
        ctx.endPDFPage()
    }
}

final class Bitmap<Value: FixedWidthInteger & UnsignedInteger> {
    enum ColorSpace {
        case grayscale
        case sRGB
        case sRGBLinear
        var cg: CGColorSpace {
            switch self {
            case .grayscale: CGColorSpaceCreateDeviceGray()
            case .sRGB: CGColorSpace.sRGBColorSpace!
            case .sRGBLinear: CGColorSpace.sRGBLinearColorSpace!
            }
        }
    }
    private let ctx: CGContext
    private let data: UnsafeMutablePointer<Value>
    private let offsetPerRow: Int, offsetPerPixel: Int
    let width: Int, height: Int
    
    init?(width: Int, height: Int, colorSpace: ColorSpace) {
        let bitmapInfo = colorSpace == .grayscale ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: MemoryLayout<Value>.size * 8,
                                  bytesPerRow: 0, space: colorSpace.cg,
                                  bitmapInfo: bitmapInfo) else { return nil }
        guard let data = ctx.data?.assumingMemoryBound(to: Value.self) else { return nil }
        self.ctx = ctx
        self.data = data
        offsetPerRow = ctx.bytesPerRow / (ctx.bitsPerComponent / 8)
        offsetPerPixel = ctx.bitsPerPixel / ctx.bitsPerComponent
        self.width = ctx.width
        self.height = ctx.height
    }
    subscript(_ x: Int, _ y: Int) -> Value {
        get {
            data[offsetPerRow * y + offsetPerPixel * x]
        }
        set {
            data[offsetPerRow * y + offsetPerPixel * x] = newValue
        }
    }
    subscript(_ x: Int, _ y: Int, _ row: Int) -> Value {
        get {
            data[offsetPerRow * y + offsetPerPixel * x + row]
        }
        set {
            data[offsetPerRow * y + offsetPerPixel * x + row] = newValue
        }
    }
    func draw(_ texture: Texture, in rect: Rect) {
        if let cgImage = texture.cgImage {
            ctx.draw(cgImage, in: rect.cg)
        }
    }
    func draw(_ image: Image, in rect: Rect) {
        ctx.draw(image.cg, in: rect.cg)
    }
    var image: Image? {
        guard let cgImage = ctx.makeImage() else { return nil }
        return Image(cgImage: cgImage)
    }
}

struct Cursor {
    static let arrow = arrowWith()
    static let drawLine = circle()
    static let block = ban()
    static let stop = rect()
    
    static var current = arrow {
        didSet {
            current.ns.set()
        }
    }
    static var isHidden = false {
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
    
    static let circleDefaultSize = 7.0, circleDefaultLineWidth = 2.0
    static func circle(size s: Double = circleDefaultSize,
                       scale: Double = 1,
                       string: String = "",
                       lightColor: Color = .content,
                       lightOutlineColor: Color = .background,
                       darkColor: Color = .background,
                       darkOutlineColor: Color = .darkBackground) -> Cursor {
        let lineWidth = circleDefaultLineWidth * scale,
            subLineWidth = 1.25 * scale
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
            let outlineNode = Node(path: Path(circleRadius: r + (subLineWidth + lineWidth) / 2,
                                              position: b.centerPoint + Point(0, tSize.height)),
                                   lineWidth: lineWidth,
                                   lineType: .color(outlineColor))
            let inlineNode = Node(path: Path(circleRadius: r, position: b.centerPoint + Point(0, tSize.height)),
                                  lineWidth: lineWidth,
                                  lineType: .color(color))
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
    static func rotate(size s: Double = circleDefaultSize,
                       scale: Double = 1,
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
        
        let fp = b.centerPoint.movedWith(distance: s / 2 + subLineWidth, angle: angle) + Point(0, tSize.height)
        let lp = b.centerPoint.movedWith(distance: s / 2 + l, angle: angle) + Point(0, tSize.height)
        let hotSpot = Point(d + s / 2, -d - s / 2)
        
        func node(color: Color, outlineColor: Color) -> Node {
            let outlineNode =  Node(path: Path(circleRadius: r + (subLineWidth + lineWidth) / 2,
                                               position: b.centerPoint + Point(0, tSize.height)),
                                    lineWidth: lineWidth,
                                    lineType: .color(outlineColor))
            let inlineNode = Node(path: Path(circleRadius: r, position: b.centerPoint + Point(0, tSize.height)),
                                  lineWidth: lineWidth,
                                  lineType: .color(color))
            let arrowOutlineNode = Node(path: Path([fp, lp], isClosed: false),
                                        lineWidth: subLineWidth * 2 + lineWidth,
                                        lineType: .color(outlineColor))
            let arrowInlineNode = Node(path: Path([fp, lp], isClosed: false),
                                       lineWidth: lineWidth,
                                       lineType: .color(color))
            
            let nodes: [Node]
            if let tPath {
                nodes = [arrowOutlineNode, outlineNode, arrowInlineNode, inlineNode,
                         Node(attitude: Attitude(position: Point(d, b.centerPoint.y)),
                               path: tPath,
                               lineWidth: lineWidth + subLineWidth,
                               lineType: .color(outlineColor)),
                         Node(attitude: Attitude(position: Point(d, b.centerPoint.y)),
                               path: tPath,
                               fillType: .color(color))]
            } else {
                nodes = [arrowOutlineNode, outlineNode, arrowInlineNode, inlineNode]
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
    static func ban(size s: Double = 12,
                    lightColor: Color = .content,
                    lightOutlineColor: Color = .background,
                    darkColor: Color = .background,
                    darkOutlineColor: Color = .darkBackground) -> Cursor {
        let lineWidth = 2.0, subLineWidth = 1.25
        let d = (subLineWidth + lineWidth / 2).rounded(.up)
        let r = s / 2
        let b = Rect(x: d, y: d, width: s, height: s)
        let lPath = Path([b.centerPoint.movedWith(distance: r, angle: .pi * 3 / 4),
                          b.centerPoint.movedWith(distance: r, angle: -.pi / 4)], isClosed: false)
        let hotSpot = Point(d + s / 2, -d - s / 2)
        
        func node(color: Color, outlineColor: Color) -> Node {
            let outlineNode = Node(path: Path(circleRadius: r, position: b.centerPoint),
                                   lineWidth: lineWidth + subLineWidth * 2,
                                   lineType: .color(outlineColor))
            let lOutlineNode = Node(path: lPath,
                                    lineWidth: lineWidth + subLineWidth * 2,
                                    lineType: .color(outlineColor))
            let inlineNode = Node(path: Path(circleRadius: r, position: b.centerPoint),
                                  lineWidth: lineWidth,
                                  lineType: .color(color))
            let lInlineNode = Node(path: lPath,
                                   lineWidth: lineWidth,
                                   lineType: .color(color))
            let size = Size(width: s + d * 2, height: s + d * 2)
            return Node(children: [outlineNode, lOutlineNode, inlineNode, lInlineNode],
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
    var screenPoint: Point, time: Double, pressure: Double, phase: Phase
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
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment,
                                                         performanceTime: .now)
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
        return modifierKeys
    }
    var isArrow: Bool {
        switch keyCode {
        case 123, 124, 125, 126: true
        default: false
        }
    }
    var key: InputKeyType? {
        switch keyCode {
        case 0: .a
        case 1: .s
        case 2: .d
        case 3: .f
        case 4: .h
        case 5: .g
        case 6: .z
        case 7: .x
        case 8: .c
        case 9: .v
        case 11: .b
        case 12: .q
        case 13: .w
        case 14: .e
        case 15: .r
        case 16: .y
        case 17: .t
        case 18: .no1
        case 19: .no2
        case 20: .no3
        case 21: .no4
        case 22: .no6
        case 23: .no5
        case 24: .equals
        case 25: .no9
        case 26: .no7
        case 27: .minus
        case 28: .no8
        case 29: .no0
        case 30: .rightBracket
        case 31: .o
        case 32: .u
        case 33: .leftBracket
        case 34: .i
        case 35: .p
        case 36: .return
        case 37: .l
        case 38: .j
        case 39: .apostrophe
        case 40: .k
        case 41: .semicolon
        case 42: .frontslash
        case 43: .comma
        case 44: .backslash
        case 45: .n
        case 46: .m
        case 47: .period
        case 48: .tab
        case 49: .space
        case 50: .backApostrophe
        case 51: .delete
        case 53: .escape
        case 55: .command
        case 56: .shift
        case 57: .capsLock
        case 58: .option
        case 59: .control
        case 63: .function
        case 93: .frontslash
        case 94: .underscore
        case 96: .f5
        case 97: .f6
        case 99: .f3
        case 118: .f4
        case 120: .f2
        case 122: .f1
        case 123: .left
        case 124: .right
        case 125: .down
        case 126: .up
        default: nil
        }
    }
}
