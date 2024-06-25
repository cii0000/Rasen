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

import MetalKit
import MetalPerformanceShaders
//import AVFoundation

extension NSRange {
    init(_ cfRange: CFRange) {
        self.init(location: cfRange.location, length: cfRange.length)
    }
}
extension CFRange {
    init(_ nsRange: NSRange) {
        self.init(location: nsRange.location, length: nsRange.length)
    }
}
extension String {
    func nsIndex(from i: String.Index) -> Int {
        NSRange(i ..< i, in: self).location
    }
    func cfIndex(from i: String.Index) -> CFIndex {
        NSRange(i ..< i, in: self).location
    }
    func nsRange(from range: Range<String.Index>) -> NSRange? {
        NSRange(range, in: self)
    }
    func cfRange(from range: Range<String.Index>) -> CFRange? {
        CFRange(NSRange(range, in: self))
    }
    func index(fromNS nsI: Int) -> String.Index? {
        Range(NSRange(location: nsI, length: 0), in: self)?.lowerBound
    }
    func index(fromCF cfI: CFIndex) -> String.Index? {
        Range(NSRange(location: cfI, length: 0), in: self)?.lowerBound
    }
    func range(fromNS nsRange: NSRange) -> Range<String.Index>? {
        Range(nsRange, in: self)
    }
    func range(fromCF cfRange: CFRange) -> Range<String.Index>? {
        Range(NSRange(cfRange), in: self)
    }
    
    var cfBased: CFString { self as CFString }
    var nsBased: String { self }
    var swiftBased: String {
        String(bytes: utf8.map { $0 }, encoding: .utf8) ?? ""
    }
}

final class Renderer {
    let device: MTLDevice
    let library: MTLLibrary
    let commandQueue: MTLCommandQueue
    let colorSpace = CGColorSpace.sRGBColorSpace!
    let pixelFormat = MTLPixelFormat.bgra8Unorm
    let imageColorSpace = CGColorSpace.sRGBColorSpace!
    let imagePixelFormat = MTLPixelFormat.rgba8Unorm
    let hdrColorSpace = CGColorSpace.sRGBHDRColorSpace!
    let hdrPixelFormat = MTLPixelFormat.rgba16Float
    var defaultColorBuffers: [RGBA: Buffer]
    
    static let shared = try! Renderer()
    
    static var metalError: Error {
        NSError(domain: NSCocoaErrorDomain, code: 0)
    }
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Renderer.metalError
        }
        self.device = device
        guard let library = device.makeDefaultLibrary() else {
            throw Renderer.metalError
        }
        self.library = library
        guard let commandQueue = device.makeCommandQueue() else {
            throw Renderer.metalError
        }
        self.commandQueue = commandQueue
        
        var n = [RGBA: Buffer]()
        func append(_ color: Color) {
            let rgba = color.rgba.premultipliedAlpha
            n[rgba] = device.makeBuffer(rgba)
        }
        append(.background)
        append(.disabled)
        append(.border)
        append(.subBorder)
        append(.draft)
        append(.selected)
        append(.subSelected)
        append(.diselected)
        append(.subDiselected)
        append(.removing)
        append(.subRemoving)
        append(.content)
        append(.interpolated)
        append(.warning)
        defaultColorBuffers = n
    }
    func appendColorBuffer(with color: Color) {
        let rgba = color.rgba.premultipliedAlpha
        if defaultColorBuffers[rgba] == nil {
            defaultColorBuffers[rgba] = device.makeBuffer(rgba)
        }
    }
    func colorBuffer(with color: Color) -> Buffer? {
        let rgba = color.rgba.premultipliedAlpha
        if let buffer = defaultColorBuffers[rgba] {
            return buffer
        }
        return device.makeBuffer(rgba)
    }
}

final class Renderstate {
    let sampleCount: Int
    let opaqueColorRenderPipelineState: MTLRenderPipelineState
    let minColorRenderPipelineState: MTLRenderPipelineState
    let alphaColorRenderPipelineState: MTLRenderPipelineState
    let colorsRenderPipelineState: MTLRenderPipelineState
    let maxColorsRenderPipelineState: MTLRenderPipelineState
    let opaqueTextureRenderPipelineState: MTLRenderPipelineState
    let alphaTextureRenderPipelineState: MTLRenderPipelineState
    let stencilRenderPipelineState: MTLRenderPipelineState
    let stencilBezierRenderPipelineState: MTLRenderPipelineState
    let invertDepthStencilState: MTLDepthStencilState
    let normalDepthStencilState: MTLDepthStencilState
    let clippingDepthStencilState: MTLDepthStencilState
    let cacheSamplerState: MTLSamplerState
    
    static let sampleCount1 = try? Renderstate(sampleCount: 1)
    static let sampleCount4 = try? Renderstate(sampleCount: 4)
    static let sampleCount8 = try? Renderstate(sampleCount: 8)
    
    init(sampleCount: Int) throws {
        let device = Renderer.shared.device
        let library = Renderer.shared.library
        let pixelFormat = Renderer.shared.pixelFormat
        
        self.sampleCount = sampleCount
        
        let basicD = MTLRenderPipelineDescriptor()
        basicD.vertexFunction = library.makeFunction(name: "basicVertex")
        basicD.fragmentFunction = library.makeFunction(name: "basicFragment")
        basicD.colorAttachments[0].pixelFormat = pixelFormat
        basicD.stencilAttachmentPixelFormat = .stencil8
        basicD.rasterSampleCount = sampleCount
        opaqueColorRenderPipelineState = try device.makeRenderPipelineState(descriptor: basicD)
        
        let minD = MTLRenderPipelineDescriptor()
        minD.vertexFunction = library.makeFunction(name: "basicVertex")
        minD.fragmentFunction = library.makeFunction(name: "basicFragment")
        minD.colorAttachments[0].isBlendingEnabled = true
        minD.colorAttachments[0].rgbBlendOperation = .min
        minD.colorAttachments[0].sourceRGBBlendFactor = .one
        minD.colorAttachments[0].sourceAlphaBlendFactor = .zero
        minD.colorAttachments[0].destinationRGBBlendFactor = .one
        minD.colorAttachments[0].destinationAlphaBlendFactor = .one
        minD.colorAttachments[0].pixelFormat = pixelFormat
        minD.stencilAttachmentPixelFormat = .stencil8
        minD.rasterSampleCount = sampleCount
        minColorRenderPipelineState = try device.makeRenderPipelineState(descriptor: minD)
        
        let alphaD = MTLRenderPipelineDescriptor()
        alphaD.vertexFunction = library.makeFunction(name: "basicVertex")
        alphaD.fragmentFunction = library.makeFunction(name: "basicFragment")
        alphaD.colorAttachments[0].isBlendingEnabled = true
        alphaD.colorAttachments[0].rgbBlendOperation = .add
        alphaD.colorAttachments[0].alphaBlendOperation = .add
        alphaD.colorAttachments[0].sourceRGBBlendFactor = .one
        alphaD.colorAttachments[0].sourceAlphaBlendFactor = .one
        alphaD.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        alphaD.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        alphaD.colorAttachments[0].pixelFormat = pixelFormat
        alphaD.stencilAttachmentPixelFormat = .stencil8
        alphaD.rasterSampleCount = sampleCount
        alphaColorRenderPipelineState = try device.makeRenderPipelineState(descriptor: alphaD)
        
        let colorsD = MTLRenderPipelineDescriptor()
        colorsD.vertexFunction = library.makeFunction(name: "colorsVertex")
        colorsD.fragmentFunction = library.makeFunction(name: "basicFragment")
        colorsD.colorAttachments[0].isBlendingEnabled = true
        colorsD.colorAttachments[0].rgbBlendOperation = .add
        colorsD.colorAttachments[0].alphaBlendOperation = .add
        colorsD.colorAttachments[0].sourceRGBBlendFactor = .one
        colorsD.colorAttachments[0].sourceAlphaBlendFactor = .one
        colorsD.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorsD.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        colorsD.colorAttachments[0].pixelFormat = pixelFormat
        colorsD.stencilAttachmentPixelFormat = .stencil8
        colorsD.rasterSampleCount = sampleCount
        colorsRenderPipelineState = try device.makeRenderPipelineState(descriptor: colorsD)
        
        let maxColorsD = MTLRenderPipelineDescriptor()
        maxColorsD.vertexFunction = library.makeFunction(name: "colorsVertex")
        maxColorsD.fragmentFunction = library.makeFunction(name: "basicFragment")
        maxColorsD.colorAttachments[0].isBlendingEnabled = true
        maxColorsD.colorAttachments[0].rgbBlendOperation = .min
        maxColorsD.colorAttachments[0].alphaBlendOperation = .min
        maxColorsD.colorAttachments[0].sourceRGBBlendFactor = .one
        maxColorsD.colorAttachments[0].sourceAlphaBlendFactor = .one
        maxColorsD.colorAttachments[0].destinationRGBBlendFactor = .one
        maxColorsD.colorAttachments[0].destinationAlphaBlendFactor = .one
        maxColorsD.colorAttachments[0].pixelFormat = pixelFormat
        maxColorsD.stencilAttachmentPixelFormat = .stencil8
        maxColorsD.rasterSampleCount = sampleCount
        maxColorsRenderPipelineState = try device.makeRenderPipelineState(descriptor: maxColorsD)
        
        let textureD = MTLRenderPipelineDescriptor()
        textureD.vertexFunction = library.makeFunction(name: "textureVertex")
        textureD.fragmentFunction = library.makeFunction(name: "textureFragment")
        textureD.colorAttachments[0].pixelFormat = pixelFormat
        textureD.stencilAttachmentPixelFormat = .stencil8
        textureD.rasterSampleCount = sampleCount
        opaqueTextureRenderPipelineState
            = try device.makeRenderPipelineState(descriptor: textureD)
        
        let aTextureD = MTLRenderPipelineDescriptor()
        aTextureD.vertexFunction = library.makeFunction(name: "textureVertex")
        aTextureD.fragmentFunction = library.makeFunction(name: "textureFragment")
        aTextureD.colorAttachments[0].isBlendingEnabled = true
        aTextureD.colorAttachments[0].rgbBlendOperation = .add
        aTextureD.colorAttachments[0].alphaBlendOperation = .add
        aTextureD.colorAttachments[0].sourceRGBBlendFactor = .one
        aTextureD.colorAttachments[0].sourceAlphaBlendFactor = .one
        aTextureD.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        aTextureD.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        aTextureD.colorAttachments[0].pixelFormat = pixelFormat
        aTextureD.stencilAttachmentPixelFormat = .stencil8
        aTextureD.rasterSampleCount = sampleCount
        alphaTextureRenderPipelineState
            = try device.makeRenderPipelineState(descriptor: aTextureD)
        
        let stencilPD = MTLRenderPipelineDescriptor()
        stencilPD.isAlphaToCoverageEnabled = true
        stencilPD.vertexFunction = library.makeFunction(name: "stencilVertex")
        stencilPD.fragmentFunction = nil
        stencilPD.colorAttachments[0].pixelFormat = pixelFormat
        stencilPD.colorAttachments[0].writeMask = []
        stencilPD.stencilAttachmentPixelFormat = .stencil8
        stencilPD.rasterSampleCount = sampleCount
        stencilRenderPipelineState
            = try device.makeRenderPipelineState(descriptor: stencilPD)
        
        let stencilBPD = MTLRenderPipelineDescriptor()
        stencilBPD.isAlphaToCoverageEnabled = true
        stencilBPD.vertexFunction = library.makeFunction(name: "stencilBVertex")
        stencilBPD.fragmentFunction = library.makeFunction(name: "stencilBFragment")
        stencilBPD.colorAttachments[0].pixelFormat = pixelFormat
        stencilBPD.colorAttachments[0].writeMask = []
        stencilBPD.stencilAttachmentPixelFormat = .stencil8
        stencilBPD.rasterSampleCount = sampleCount
        stencilBezierRenderPipelineState
            = try device.makeRenderPipelineState(descriptor: stencilBPD)
        
        let stencil = MTLStencilDescriptor()
        stencil.stencilFailureOperation = .invert
        stencil.depthStencilPassOperation = .invert
        let stencilD = MTLDepthStencilDescriptor()
        stencilD.backFaceStencil = stencil
        stencilD.frontFaceStencil = stencil
        guard let ss = device.makeDepthStencilState(descriptor: stencilD) else {
            throw Renderer.metalError
        }
        invertDepthStencilState = ss
        
        let clipping = MTLStencilDescriptor()
        clipping.stencilCompareFunction = .notEqual
        clipping.stencilFailureOperation = .keep
        clipping.depthStencilPassOperation = .zero
        let clippingDescriptor = MTLDepthStencilDescriptor()
        clippingDescriptor.backFaceStencil = clipping
        clippingDescriptor.frontFaceStencil = clipping
        guard let cs = device.makeDepthStencilState(descriptor: clippingDescriptor) else {
            throw Renderer.metalError
        }
        clippingDepthStencilState = cs
        
        let nclippingDescriptor = MTLDepthStencilDescriptor()
        guard let ncs = device.makeDepthStencilState(descriptor: nclippingDescriptor) else {
            throw Renderer.metalError
        }
        normalDepthStencilState = ncs
        
        let cSamplerDescriptor = MTLSamplerDescriptor()
        cSamplerDescriptor.minFilter = .nearest
        cSamplerDescriptor.magFilter = .linear
        guard let ncss = device.makeSamplerState(descriptor: cSamplerDescriptor) else {
            throw Renderer.metalError
        }
        cacheSamplerState = ncss
    }
}

final class DynamicBuffer {
    static let maxInflightBuffers = 3
    private let semaphore = DispatchSemaphore(value: DynamicBuffer.maxInflightBuffers)
    var buffers = [Buffer?]()
    var bufferIndex = 0
    init() {
        buffers = (0 ..< DynamicBuffer.maxInflightBuffers).map { _ in
            Renderer.shared.device.makeBuffer(Transform.identity.floatData4x4)
        }
    }
    func next() -> Buffer? {
        semaphore.wait()
        let buffer = buffers[bufferIndex]
        bufferIndex = (bufferIndex + 1) % DynamicBuffer.maxInflightBuffers
        return buffer
    }
    func signal() {
        semaphore.signal()
    }
}

final class SubMTKView: MTKView, MTKViewDelegate,
                        NSTextInputClient, NSMenuItemValidation, NSMenuDelegate {
    static let enabledAnimationKey = "enabledAnimation"
    static let isHiddenActionListKey = "isHiddenActionList"
    static let isShownTrackpadAlternativeKey = "isShownTrackpadAlternative"
    private(set) var document: Document
    let renderstate = Renderstate.sampleCount4!
    
    var isShownDebug = false
    var isShownClock = false
    private var updateDebugCount = 0
    private let debugNode = Node(attitude: Attitude(position: Point(5, 5)),
                                 fillType: .color(.content))
    
    private var sheetActionNode, rootActionNode: Node?,
                actionIsEditingSheet = true
    private var actionNode: Node? {
        actionIsEditingSheet ? sheetActionNode : rootActionNode
    }
    var isHiddenActionList = true {
        didSet {
            
            guard isHiddenActionList != oldValue else { return }
            updateActionList()
            if isShownTrackpadAlternative {
                updateTrackpadAlternativePositions()
            }
        }
    }
    private func makeActionNode(isEditingSheet: Bool) -> Node {
        let actionNode = ActionList.default.node(isEditingSheet: isEditingSheet)
        let b = document.screenBounds
        let w = b.maxX - (actionNode.bounds?.maxX ?? 0)
        let h = b.midY - (actionNode.bounds?.midY ?? 0)
        actionNode.attitude.position = Point(w, h)
        return actionNode
    }
    private func updateActionList() {
        if isHiddenActionList {
            sheetActionNode = nil
            rootActionNode = nil
        } else if sheetActionNode == nil || rootActionNode == nil {
            sheetActionNode = makeActionNode(isEditingSheet: true)
            rootActionNode = makeActionNode(isEditingSheet: false)
        }
        actionIsEditingSheet = document.isEditingSheet
        update()
    }
    
    func update() {
        needsDisplay = true
    }
    
    required init(url: URL, frame: NSRect = NSRect()) {
        self.document = Document(url: url)
        
        super.init(frame: frame, device: Renderer.shared.device)
        delegate = self
        sampleCount = renderstate.sampleCount
        depthStencilPixelFormat = .stencil8
        clearColor = document.backgroundColor.mtl
        
        if document.colorSpace.isHDR {
            colorPixelFormat = Renderer.shared.hdrPixelFormat
            colorspace = Renderer.shared.hdrColorSpace
            (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = true
            Swift.print("HDR")
        } else {
            colorPixelFormat = Renderer.shared.pixelFormat
            colorspace = Renderer.shared.colorSpace
        }
        
        isPaused = true
        enableSetNeedsDisplay = true
        self.allowedTouchTypes = .indirect
        self.wantsRestingTouches = true
        setupDocument()
        
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
    
    func setupDocument() {
        document.backgroundColorNotifications.append { [weak self] (_, backgroundColor) in
            self?.clearColor = backgroundColor.mtl
            self?.update()
        }
        document.cursorNotifications.append { [weak self] (_, cursor) in
            guard let self else { return }
            self.window?.invalidateCursorRects(for: self)
            self.addCursorRect(self.bounds, cursor: cursor.ns)
            Cursor.current = cursor
        }
        document.cameraNotifications.append { [weak self] (_, _) in
            guard let self else { return }
            if !self.isHiddenActionList {
                if self.actionIsEditingSheet != self.document.isEditingSheet {
                    self.updateActionList()
                }
            }
            self.update()
        }
        document.rootNode.allChildrenAndSelf { $0.owner = self }
        
        document.cursorPoint = clippedScreenPointFromCursor.my
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
                   let r = self.document.selections
                    .first(where: { self.document.worldBounds.intersects($0.rect) })?.rect {
                    
                    let p = r.centerPoint
                    let sp = self.document.convertWorldToScreen(p)
                    self.document.inputKey(self.inputKeyEventWith(at: sp, .lookUpTap, .began))
                    self.document.inputKey(self.inputKeyEventWith(at: sp, .lookUpTap, .ended))
                }
            }
            trackpadView.addSubview(lookUpButton)
            self.lookUpButton = lookUpButton
            
            let scrollButton = SubNSButton(frame: NSRect(),
                                           .scroll) { [weak self] (event, dp) in
                guard let self else { return }
                let nEvent = ScrollEvent(screenPoint: self.document.screenBounds.centerPoint,
                                         time: event.time,
                                         scrollDeltaPoint: Point(dp.x, -dp.y) * 2,
                                         phase: event.phase,
                                         touchPhase: nil,
                                         momentumPhase: nil)
                self.document.scroll(nEvent)
            }
            trackpadView.addSubview(scrollButton)
            self.scrollButton = scrollButton
            
            let zoomButton = SubNSButton(frame: NSRect(),
                                         .zoom) { [weak self] (event, dp) in
                guard let self else { return }
                let nEvent = PinchEvent(screenPoint: self.document.screenBounds.centerPoint,
                                        time: event.time,
                                        magnification: -dp.y / 100,
                                        phase: event.phase)
                self.document.pinch(nEvent)
            }
            trackpadView.addSubview(zoomButton)
            self.zoomButton = zoomButton
            
            let rotateButton = SubNSButton(frame: NSRect(),
                                           .rotate) { [weak self] (event, dp) in
                guard let self else { return }
                let nEvent = RotateEvent(screenPoint: self.document.screenBounds.centerPoint,
                                         time: event.time,
                                         rotationQuantity: -dp.x / 10,
                                         phase: event.phase)
                self.document.rotate(nEvent)
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
        addCursorRect(bounds, cursor: document.cursor.ns)
    }
    
    var isEnableMenuCommand = false {
        didSet {
            guard isEnableMenuCommand != oldValue else { return }
            document.isShownLastEditedSheet = isEnableMenuCommand
            document.isNoneCursor = isEnableMenuCommand
        }
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(SubMTKView.exportAsImage(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsPDF(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsGIF(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsMovie(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsHighQualityMovie(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsSound(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsCaption(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsDocument(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.exportAsDocumentWithHistory(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.importDocument(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.clearHistory(_:)):
            return document.isSelectedNoneCursor
        case #selector(SubMTKView.showAboutRun(_:)):
            return document.isEditingSheet
                && document.isSelectedNoneCursor
            
        case #selector(SubMTKView.undo(_:)):
            if isEnableMenuCommand {
                if document.isEditingSheet {
                    if document.isSelectedNoneCursor {
                        return document.selectedSheetViewNoneCursor?.history.isCanUndo ?? false
                    }
                } else {
                    return document.history.isCanUndo
                }
            }
            return false
        case #selector(SubMTKView.redo(_:)):
            if isEnableMenuCommand {
                if document.isEditingSheet {
                    if document.isSelectedNoneCursor {
                        return document.selectedSheetViewNoneCursor?.history.isCanRedo ?? false
                    }
                } else {
                    return document.history.isCanRedo
                }
            }
            return false
        case #selector(SubMTKView.cut(_:)):
            return isEnableMenuCommand
                && document.isSelectedNoneCursor && document.isSelectedOnlyNoneCursor
        case #selector(SubMTKView.copy(_:)):
            return isEnableMenuCommand
                && document.isSelectedNoneCursor && document.isSelectedOnlyNoneCursor
        case #selector(SubMTKView.paste(_:)):
            return if isEnableMenuCommand
                && document.isSelectedNoneCursor {
                switch Pasteboard.shared.copiedObjects.first {
                case .picture, .planesValue: document.isEditingSheet
                case .copiedSheetsValue: !document.isEditingSheet
                default: false
                }
            } else {
                false
            }
        case #selector(SubMTKView.find(_:)):
            return isEnableMenuCommand && document.isEditingSheet
                && document.isSelectedNoneCursor && document.isSelectedText
        case #selector(SubMTKView.changeToDraft(_:)):
            return isEnableMenuCommand && document.isEditingSheet
                && document.isSelectedNoneCursor
                && !(document.selectedSheetViewNoneCursor?.model.picture.isEmpty ?? true)
        case #selector(SubMTKView.cutDraft(_:)):
            return isEnableMenuCommand && document.isEditingSheet
                && document.isSelectedNoneCursor
                && !(document.selectedSheetViewNoneCursor?.model.draftPicture.isEmpty ?? true)
        case #selector(SubMTKView.makeFaces(_:)):
            return isEnableMenuCommand && document.isEditingSheet
                && document.isSelectedNoneCursor
                && !(document.selectedSheetViewNoneCursor?.model.picture.lines.isEmpty ?? true)
        case #selector(SubMTKView.cutFaces(_:)):
            return isEnableMenuCommand && document.isEditingSheet
                && document.isSelectedNoneCursor
                && !(document.selectedSheetViewNoneCursor?.model.picture.planes.isEmpty ?? true)
        case #selector(SubMTKView.changeToVerticalText(_:)):
            return isEnableMenuCommand && document.isEditingSheet
                && document.isSelectedNoneCursor && document.isSelectedText
        case #selector(SubMTKView.changeToHorizontalText(_:)):
            return isEnableMenuCommand && document.isEditingSheet
                && document.isSelectedNoneCursor && document.isSelectedText
        
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
        let ok: () -> () = {
            let message = "Clearing Root History".localized
            let progressPanel = ProgressPanel(message: message)
            self.document.rootNode.show(progressPanel)
            DispatchQueue.global().async {
                self.document.clearHistory { (progress, isStop) in
                    if progressPanel.isCancel {
                        isStop = true
                    } else {
                        DispatchQueue.main.async {
                            progressPanel.progress = progress
                        }
                    }
                }
                DispatchQueue.main.async {
                    progressPanel.closePanel()
                }
            }
        }
        let cancel: () -> () = {}
        document.rootNode
            .show(message: "Do you want to clear root history?".localized,
                  infomation: "You can’t undo this action. \nRoot history is what is used in \"Undo\", \"Redo\" or \"Select Version\" when in root operation, and if you clear it, you will not be able to return to the previous work.".localized,
                  okTitle: "Clear Root History".localized,
                  isSaftyCheck: true,
                  okClosure: ok, cancelClosure: cancel)
    }
    func replacingDatabase(from url: URL) {
        func replace(progressHandler: (Double, inout Bool) -> ()) throws {
            var stop = false
            
            self.document.syncSave()
            
            progressHandler(0.5, &stop)
            if stop { return }
            
            let oldURL = self.document.url
            guard oldURL != url else { throw URL.readError }
            let fm = FileManager.default
            if fm.fileExists(atPath: oldURL.path) {
                try fm.trashItem(at: oldURL, resultingItemURL: nil)
            }
            try fm.copyItem(at: url, to: oldURL)
            
            progressHandler(1, &stop)
            if stop { return }
        }
        let message = String(format: "Replacing %@".localized, System.dataName)
        let progressPanel = ProgressPanel(message: message)
        self.document.rootNode.show(progressPanel)
        DispatchQueue.global().async {
            do {
                try replace { (progress, isStop) in
                    if progressPanel.isCancel {
                        isStop = true
                    } else {
                        DispatchQueue.main.async {
                            progressPanel.progress = progress
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.updateWithURL()
                    progressPanel.closePanel()
                }
            } catch {
                DispatchQueue.main.async {
                    self.document.rootNode.show(error)
                    self.updateWithURL()
                    progressPanel.closePanel()
                }
            }
        }
    }
    func replaceDatabase(from url: URL) {
        let ok: () -> () = {
            self.replacingDatabase(from: url)
        }
        let cancel: () -> () = {}
        document.rootNode
            .show(message: String(format: "Do you want to replace %@?".localized, System.dataName),
                  infomation: String(format: "You can’t undo this action. \n%1$@ is all the data written to this %2$@, if you replace %1$@ with new %1$@, all old %1$@ will be moved to the Trash.".localized, System.dataName, System.appName),
                  okTitle: String(format: "Replace %@".localized, System.dataName),
                  isSaftyCheck: true,
                  okClosure: ok, cancelClosure: cancel)
    }
    @objc func replaceDatabase(_ sender: Any) {
        let ok: () -> () = {
            let complete: ([IOResult]) -> () = { ioResults in
                self.replacingDatabase(from: ioResults[0].url)
            }
            let cancel: () -> () = {}
            URL.load(prompt: "Replace".localized,
                     fileTypes: [Document.FileType.rasendata,
                                 Document.FileType.sksdata],
                     completionClosure: complete, cancelClosure: cancel)
        }
        let cancel: () -> () = {}
        document.rootNode
            .show(message: String(format: "Do you want to replace %@?".localized, System.dataName),
                  infomation: String(format: "You can’t undo this action. \n%1$@ is all the data written to this %2$@, if you replace %1$@ with new %1$@, all old %1$@ will be moved to the Trash.".localized, System.dataName, System.appName),
                  okTitle: String(format: "Replace %@...".localized, System.dataName),
                  isSaftyCheck: self.document.url.allFileSize > 20*1024*1024,
                  okClosure: ok, cancelClosure: cancel)
    }
    @objc func exportDatabase(_ sender: Any) {
        let complete: (IOResult) -> () = { (ioResult) in
            func export(progressHandler: (Double, inout Bool) -> ()) throws {
                var stop = false
                
                self.document.syncSave()
                
                progressHandler(0.5, &stop)
                if stop { return }
                
                let url = self.document.url
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
            let message = String(format: "Exporting %@".localized, System.dataName)
            let progressPanel = ProgressPanel(message: message)
            self.document.rootNode.show(progressPanel)
            DispatchQueue.global().async {
                do {
                    try export { (progress, isStop) in
                        if progressPanel.isCancel {
                            isStop = true
                        } else {
                            DispatchQueue.main.async {
                                progressPanel.progress = progress
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        progressPanel.closePanel()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.document.rootNode.show(error)
                        progressPanel.closePanel()
                    }
                }
            }
        }
        let cancel: () -> () = {}
        let fileSize: () -> (Int?) = { self.document.url.allFileSize }
        URL.export(name: "User", fileType: Document.FileType.rasendata,
                   fileSizeHandler: fileSize,
                   completionClosure: complete, cancelClosure: cancel)
    }
    @objc func resetDatabase(_ sender: Any) {
        let ok: () -> () = {
            func reset(progressHandler: (Double, inout Bool) -> ()) throws {
                var stop = false
                
                self.document.syncSave()
                
                progressHandler(0.5, &stop)
                if stop { return }
                
                let url = self.document.url
                let fm = FileManager.default
                if fm.fileExists(atPath: url.path) {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                }
                
                progressHandler(1, &stop)
                if stop { return }
            }
            let message = String(format: "Resetting %@".localized, System.dataName)
            let progressPanel = ProgressPanel(message: message)
            self.document.rootNode.show(progressPanel)
            DispatchQueue.global().async {
                do {
                    try reset { (progress, isStop) in
                        if progressPanel.isCancel {
                            isStop = true
                        } else {
                            DispatchQueue.main.async {
                                progressPanel.progress = progress
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self.updateWithURL()
                        progressPanel.closePanel()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.document.rootNode.show(error)
                        self.updateWithURL()
                        progressPanel.closePanel()
                    }
                }
            }
        }
        let cancel: () -> () = {}
        document.rootNode
            .show(message: String(format: "Do you want to reset the %@?".localized, System.dataName),
                  infomation: String(format: "You can’t undo this action. \n%1$@ is all the data written to this %2$@, if you reset %1$@, all %1$@ will be moved to the Trash.".localized, System.dataName, System.appName),
                  okTitle: String(format: "Reset %@".localized, System.dataName),
                  isSaftyCheck: self.document.url.allFileSize > 20*1024*1024,
                  okClosure: ok, cancelClosure: cancel)
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
        document.isNoneCursor = true
        let editor = Importer(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    
    @objc func exportAsImage(_ sender: Any) {
        document.isNoneCursor = true
        let editor = ImageExporter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func exportAsPDF(_ sender: Any) {
        document.isNoneCursor = true
        let editor = PDFExporter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func exportAsGIF(_ sender: Any) {
        document.isNoneCursor = true
        let editor = GIFExporter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func exportAsMovie(_ sender: Any) {
        document.isNoneCursor = true
        let editor = MovieExporter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func exportAsHighQualityMovie(_ sender: Any) {
        document.isNoneCursor = true
        let editor = HighQualityMovieExporter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func exportAsSound(_ sender: Any) {
        document.isNoneCursor = true
        let editor = SoundExporter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func exportAsCaption(_ sender: Any) {
        document.isNoneCursor = true
        let editor = CaptionExporter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    
    @objc func exportAsDocument(_ sender: Any) {
        document.isNoneCursor = true
        let editor = DocumentWithoutHistoryExporter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func exportAsDocumentWithHistory(_ sender: Any) {
        document.isNoneCursor = true
        let editor = DocumentExporter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    
    @objc func clearHistory(_ sender: Any) {
        document.isNoneCursor = true
        let editor = HistoryCleaner(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    
    @objc func showAboutRun(_ sender: Any) {
        document.isNoneCursor = true
        let editor = AboutRunShower(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    
    @objc func undo(_ sender: Any) {
        document.isNoneCursor = true
        let editor = Undoer(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func redo(_ sender: Any) {
        document.isNoneCursor = true
        let editor = Redoer(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func cut(_ sender: Any) {
        document.isNoneCursor = true
        let editor = Cutter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func copy(_ sender: Any) {
        document.isNoneCursor = true
        let editor = Copier(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func paste(_ sender: Any) {
        document.isNoneCursor = true
        let editor = Paster(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func find(_ sender: Any) {
        document.isNoneCursor = true
        let editor = Finder(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func changeToDraft(_ sender: Any) {
        document.isNoneCursor = true
        let editor = DraftChanger(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func cutDraft(_ sender: Any) {
        document.isNoneCursor = true
        let editor = DraftCutter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func makeFaces(_ sender: Any) {
        document.isNoneCursor = true
        let editor = FacesMaker(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func cutFaces(_ sender: Any) {
        document.isNoneCursor = true
        let editor = FacesCutter(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func changeToVerticalText(_ sender: Any) {
        document.isNoneCursor = true
        let editor = VerticalTextChanger(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    @objc func changeToHorizontalText(_ sender: Any) {
        document.isNoneCursor = true
        let editor = HorizontalTextChanger(document)
        editor.send(inputKeyEventWith(.began))
        Sleep.start()
        editor.send(inputKeyEventWith(.ended))
        document.isNoneCursor = false
    }
    
//    @objc func startDictation(_ sender: Any) {
//    }
//    @objc func orderFrontCharacterPalette(_ sender: Any) {
//    }
    
    func updateWithURL() {
        document = Document(url: document.url)
        setupDocument()
        document.restoreDatabase()
        document.screenBounds = bounds.my
        document.drawableSize = drawableSize.my
        clearColor = document.backgroundColor.mtl
        draw()
    }
    
    func draw(in view: MTKView) {}
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        document.screenBounds = bounds.my
        document.drawableSize = size.my
        
        if !isHiddenActionList {
            func update(_ node: Node) {
                let b = document.screenBounds
                let w = b.maxX - (node.bounds?.maxX ?? 0)
                let h = b.midY - (node.bounds?.midY ?? 0)
                node.attitude.position = Point(w, h)
            }
            if let actionNode = sheetActionNode {
                update(actionNode)
            }
            if let actionNode = rootActionNode {
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
        return document.worldToViewportTransform.absXScale
            * document.viewportToScreenTransform.absXScale
            * Double(drawableSize.width / self.bounds.width)
    }
    func viewportBounds(from transform: Transform, bounds: Rect) -> Rect {
        let dr = Rect(x: 0, y: 0,
                      width: Double(drawableSize.width),
                      height: Double(drawableSize.height))
        let scale = Double(drawableSize.width / self.bounds.width)
        let st = transform
            * document.viewportToScreenTransform
            * Transform(translationX: 0,
                        y: -document.screenBounds.height)
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
        document.stopScrollEvent()
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
                  pressure: 1, phase: .changed)
    }
    func dragEventWith(_ nsEvent: NSEvent, _ phase: Phase) -> DragEvent {
        DragEvent(screenPoint: screenPoint(with: nsEvent).my,
                  time: nsEvent.timestamp,
                  pressure: Double(nsEvent.pressure), phase: phase)
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
    
    override func flagsChanged(with nsEvent: NSEvent) {
        document.modifierKeys = nsEvent.modifierKeys
    }
    
    override func mouseMoved(with nsEvent: NSEvent) {
        document.indicate(with: dragEventWith(indicate: nsEvent))
        
        if let oldEvent = document.oldInputKeyEvent,
           let editor = document.inputKeyEditor {
            
            editor.send(inputKeyEventWith(nsEvent, oldEvent.inputKeyType, .changed))
        }
    }
    
    override func keyDown(with nsEvent: NSEvent) {
        guard let key = nsEvent.key else { return }
        let phase: Phase = nsEvent.isARepeat ? .changed : .began
        if key.isTextEdit
            && !document.modifierKeys.contains(.command)
            && document.modifierKeys != .control
            && document.modifierKeys != [.control, .option]
            && !document.modifierKeys.contains(.function) {
            
            document.inputText(inputTextEventWith(nsEvent, key, phase))
        } else {
            document.inputKey(inputKeyEventWith(nsEvent, key,
                                                isRepeat: nsEvent.isARepeat,
                                                phase))
        }
    }
    override func keyUp(with nsEvent: NSEvent) {
        guard let key = nsEvent.key else { return }
        let textEvent = inputTextEventWith(nsEvent, key, .ended)
        if document.oldInputTextKeys.contains(textEvent.inputKeyType) {
            document.inputText(textEvent)
        }
        if document.oldInputKeyEvent?.inputKeyType == key {
            document.inputKey(inputKeyEventWith(nsEvent, key, .ended))
        }
    }
    
    private var beganDragEvent: DragEvent?,
                oldPressureStage = 0, isDrag = false, isStrongDrag = false,
                firstTime = 0.0, firstP = Point(), isMovedDrag = false
    override func mouseDown(with nsEvent: NSEvent) {
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
        let dragEvent = dragEventWith(nsEvent, .changed)
        guard dragEvent.screenPoint.distance(firstP) >= 2.5
            || dragEvent.time - firstTime >= 0.1 else { return }
        isMovedDrag = true
        if !isDrag {
            isDrag = true
            if oldPressureStage == 2 {
                isStrongDrag = true
                document.strongDrag(beganDragEvent)
            } else {
                document.drag(beganDragEvent)
            }
        }
        if isStrongDrag {
            document.strongDrag(dragEventWith(nsEvent, .changed))
        } else {
            document.drag(dragEventWith(nsEvent, .changed))
        }
    }
    override func mouseUp(with nsEvent: NSEvent) {
        let endedDragEvent = dragEventWith(nsEvent, .ended)
        if isDrag {
            if isStrongDrag {
                document.strongDrag(endedDragEvent)
                isStrongDrag = false
            } else {
                document.drag(endedDragEvent)
            }
            isDrag = false
        } else {
            if oldPressureStage >= 2 {
                quickLook(with: nsEvent)
            } else {
                guard let beganDragEvent = beganDragEvent else { return }
                if isMovedDrag {
                    document.drag(beganDragEvent)
                    document.drag(endedDragEvent)
                } else {
                    document.inputKey(inputKeyEventWith(beganDragEvent, .began))
                    Sleep.start()
                    document.inputKey(inputKeyEventWith(beganDragEvent, .ended))
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
        isSubTouth = nsEvent.subtype == .touch
        isSubDrag = false
        let beganDragEvent = dragEventWith(nsEvent, .began)
        self.beganSubDragEvent = beganDragEvent
    }
    override func rightMouseDragged(with nsEvent: NSEvent) {
        guard let beganDragEvent = beganSubDragEvent else { return }
        if !isSubDrag {
            isSubDrag = true
            document.subDrag(beganDragEvent)
        }
        document.subDrag(dragEventWith(nsEvent, .changed))
    }
    override func rightMouseUp(with nsEvent: NSEvent) {
        let endedDragEvent = dragEventWith(nsEvent, .ended)
        if isSubDrag {
            document.subDrag(endedDragEvent)
            isSubDrag = false
        } else {
            guard let beganDragEvent = beganSubDragEvent else { return }
            if beganDragEvent.screenPoint != endedDragEvent.screenPoint {
                document.subDrag(beganDragEvent)
                document.subDrag(endedDragEvent)
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
    
    private var menuEditor: Exporter?
    func showMenu(_ nsEvent: NSEvent) {
        guard window?.sheets.isEmpty ?? false else { return }
        guard window?.isMainWindow ?? false else { return }
        
        let event = inputKeyEventWith(drag: nsEvent, .began)
        document.updateLastEditedSheetpos(from: event)
        let menu = NSMenu()
        if menuEditor != nil {
            menuEditor?.editor.end()
        }
        menuEditor = Exporter(document)
        menuEditor?.send(event)
        menu.delegate = self
        menu.addItem(SubNSMenuItem(title: "Import Document...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = Importer(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(SubNSMenuItem(title: "Export as Image...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = ImageExporter(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as PDF...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = PDFExporter(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as GIF...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = GIFExporter(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as Movie...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = MovieExporter(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as 4K Movie...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = HighQualityMovieExporter(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as Sound...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = SoundExporter(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as Caption...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = CaptionExporter(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(SubNSMenuItem(title: "Export as Document...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = DocumentWithoutHistoryExporter(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(SubNSMenuItem(title: "Export as Document with History...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = DocumentExporter(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(SubNSMenuItem(title: "Clear History...".localized, closure: { [weak self] in
            guard let self else { return }
            let editor = HistoryCleaner(self.document)
            editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
            editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
        }))
        
        menu.addItem(SubNSMenuItem(title: "test".localized, closure: { [weak self] in
            guard let self else { return }
            self.isEnabledPinch = !self.isEnabledPinch
            self.isEnabledScroll = !self.isEnabledScroll
            self.isEnabledRotate = !self.isEnabledRotate
        }))
        
        if System.isVersion3 {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(SubNSMenuItem(title: "Show About Run".localized, closure: { [weak self] in
                guard let self else { return }
                let editor = AboutRunShower(self.document)
                editor.send(self.inputKeyEventWith(drag: nsEvent, .began))
                editor.send(self.inputKeyEventWith(drag: nsEvent, .ended))
            }))
        }
        document.stopAllEvents()
        NSMenu.popUpContextMenu(menu, with: nsEvent, for: self)
    }
    func menuDidClose(_ menu: NSMenu) {
        menuEditor?.editor.end()
        menuEditor = nil
    }
    
    private var beganMiddleDragEvent: DragEvent?, isMiddleDrag = false
    override func otherMouseDown(with nsEvent: NSEvent) {
        isMiddleDrag = false
        let beganDragEvent = dragEventWith(nsEvent, .began)
        self.beganMiddleDragEvent = beganDragEvent
    }
    override func otherMouseDragged(with nsEvent: NSEvent) {
        guard let beganDragEvent = beganMiddleDragEvent else { return }
        if !isMiddleDrag {
            isMiddleDrag = true
            document.middleDrag(beganDragEvent)
        }
        document.middleDrag(dragEventWith(nsEvent, .changed))
    }
    override func otherMouseUp(with nsEvent: NSEvent) {
        let endedDragEvent = dragEventWith(nsEvent, .ended)
        if isMiddleDrag {
            document.middleDrag(endedDragEvent)
            isMiddleDrag = false
        } else {
            guard let beganDragEvent = beganSubDragEvent else { return }
            if beganDragEvent.screenPoint != endedDragEvent.screenPoint {
                document.middleDrag(beganDragEvent)
                document.middleDrag(endedDragEvent)
            }
        }
        beganMiddleDragEvent = nil
    }
    
    let scrollEndTime = 0.1
    private var scrollWorkItem: DispatchWorkItem?
    override func scrollWheel(with nsEvent: NSEvent) {
        guard !isEnabledScroll else { return }
        
        func beginEvent() -> Phase {
            if scrollWorkItem != nil {
                scrollWorkItem?.cancel()
                scrollWorkItem = nil
                return .changed
            } else {
                return .began
            }
        }
        func endEvent() {
            let workItem = DispatchWorkItem() { [weak self] in
                guard let self else { return }
                guard !(self.scrollWorkItem?.isCancelled ?? true) else { return }
                var event = self.scrollEventWith(nsEvent, .ended,
                                                  touchPhase: nil,
                                                  momentumPhase: nil)
                event.screenPoint = self.screenPointFromCursor.my
                event.time += self.scrollEndTime
                self.document.scroll(event)
                self.scrollWorkItem?.cancel()
                self.scrollWorkItem = nil
            }
            self.scrollWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + scrollEndTime,
                                          execute: workItem)
        }
        if nsEvent.phase.contains(.began) {
            allScrollPosition = .init()
            document.scroll(scrollEventWith(nsEvent, beginEvent(),
                                            touchPhase: .began,
                                            momentumPhase: nil))
        } else if nsEvent.phase.contains(.ended) {
            document.scroll(scrollEventWith(nsEvent, .changed,
                                            touchPhase: .ended,
                                            momentumPhase: nil))
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
            
            document.scroll(event)
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
                document.scroll(event)
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
                document.scroll(event)
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
                document.scroll(event)
            }
        }
    }
    
    var oldTouchPoints = [TouchID: Point]()
    var touchedIDs = [TouchID]()
    
    var isEnabledScroll = true
    var isEnabledPinch = true
    var isEnabledRotate = true
    var isEnabledSwipe = true
    var isEnabledPlay = true
    
    var isBeganScroll = false, oldScrollPosition: Point?, allScrollPosition = Point()
    var isBeganPinch = false, oldPinchDistance: Double?
    var isBeganRotate = false, oldRotateAngle: Double?
    var isPreparePlay = false
    var scrollVs = [(dp: Point, time: Double)]()
    var pinchVs = [(d: Double, time: Double)]()
    var rotateVs = [(d: Double, time: Double)]()
    var lastScrollDeltaPosition = Point()
    enum  SnapScrollType {
        case none, x, y
    }
    var snapScrollType = SnapScrollType.none
    var lastMagnification = 0.0
    var lastRotationQuantity = 0.0
    var isBeganSwipe = false, swipePosition: Point?
    
    var scrollTimer: DispatchSourceTimer?
    var pinchTimer: DispatchSourceTimer?
    
    struct TouchID: Hashable {
        var id: NSCopying & NSObjectProtocol
        
        static func ==(lhs: Self, rhs: Self) -> Bool {
            lhs.id.isEqual(rhs.id)
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(id.hash)
        }
    }
    func touchPoints(with event: NSEvent) -> [TouchID: Point] {
        let touches = event.touches(matching: .touching, in: self)
        return touches.reduce(into: [TouchID: Point]()) {
            $0[.init(id: $1.identity)] =
            Point(Double($1.normalizedPosition.x * $1.deviceSize.width),
                  Double($1.normalizedPosition.y * $1.deviceSize.height))
        }
    }
    override func touchesBegan(with event: NSEvent) {
        let ps = touchPoints(with: event)
        oldTouchPoints = ps
        touchedIDs = Array(ps.keys)
        if ps.count == 2 {
            swipePosition = nil
            let ps0 = ps[touchedIDs[0]]!, ps1 = ps[touchedIDs[1]]!
            oldPinchDistance = ps0.distance(ps1)
            oldRotateAngle = ps0.angle(ps1)
            oldScrollPosition = ps0.mid(ps1)
            isBeganPinch = false
            isBeganScroll = false
            isBeganRotate = false
            snapScrollType = .none
            lastScrollDeltaPosition = .init()
            lastMagnification = 0
            pinchVs = []
            scrollVs = []
            rotateVs = []
        } else if ps.count == 3 {
            oldPinchDistance = nil
            oldRotateAngle = nil
            oldScrollPosition = nil
            
            isBeganSwipe = false
            swipePosition = Point()
        } else if ps.count == 4 {
            oldPinchDistance = nil
            oldRotateAngle = nil
            oldScrollPosition = nil
            
            oldScrollPosition = (0 ..< 4).map { ps[touchedIDs[$0]]! }.mean()!
            isPreparePlay = true
        }
    }
    override func touchesMoved(with event: NSEvent) {
        let ps = touchPoints(with: event)
        if ps.count == 2 {
            if touchedIDs.count == 2,
                isEnabledPinch || isEnabledScroll,
                let oldPinchDistance, let oldRotateAngle,
                let oldScrollPosition,
                let ps0 = ps[touchedIDs[0]],
                let ps1 = ps[touchedIDs[1]],
                let ops0 = oldTouchPoints[touchedIDs[0]],
                let ops1 = oldTouchPoints[touchedIDs[1]] {
               
                let nps0 = ps0.mid(ops0), nps1 = ps1.mid(ops1)
                let nPinchDistance = nps0.distance(nps1)
                let nRotateAngle = nps0.angle(nps1)
                let nScrollPosition = nps0.mid(nps1)
                if isEnabledPinch
                    && !isBeganScroll && !isBeganPinch && !isBeganRotate
                    && abs(Edge(ops0, ps0).angle(Edge(ops1, ps1))) > .pi / 2
                    && abs(nPinchDistance - oldPinchDistance) > 6
                    && nScrollPosition.distance(oldScrollPosition) <= 5 {
                    
                    isBeganPinch = true
                    
                    scrollTimer?.cancel()
                    scrollTimer = nil
                    pinchTimer?.cancel()
                    pinchTimer = nil
                    document.pinch(.init(screenPoint: screenPoint(with: event).my,
                                         time: event.timestamp,
                                         magnification: 0,
                                         phase: .began))
                    pinchVs.append((0, event.timestamp))
                    self.oldPinchDistance = nPinchDistance
                    lastMagnification = 0
                } else if isBeganPinch {
                    let magnification = (nPinchDistance - oldPinchDistance) * 0.0125
                    document.pinch(.init(screenPoint: screenPoint(with: event).my,
                                         time: event.timestamp,
                                         magnification: magnification.mid(lastMagnification),
                                         phase: .changed))
                    pinchVs.append((magnification, event.timestamp))
//                    print("A", magnification)
                    self.oldPinchDistance = nPinchDistance
                    lastMagnification = magnification
                } else if isEnabledScroll && !(isSubDrag && isSubTouth)
                            && !isBeganScroll && !isBeganPinch
                            && !isBeganRotate
                            && abs(nPinchDistance - oldPinchDistance) <= 6
                            && nScrollPosition.distance(oldScrollPosition) > 5 {
                    isBeganScroll = true
                    
                    scrollTimer?.cancel()
                    scrollTimer = nil
                    pinchTimer?.cancel()
                    pinchTimer = nil
                    document.scroll(.init(screenPoint: screenPoint(with: event).my,
                                          time: event.timestamp,
                                          scrollDeltaPoint: .init(),
                                          phase: .began,
                                          touchPhase: .began,
                                          momentumPhase: nil))
                    scrollVs.append((.init(), event.timestamp))
                    self.oldScrollPosition = nScrollPosition
                    lastScrollDeltaPosition = .init()
                    let dp = nScrollPosition - oldScrollPosition
                    snapScrollType = min(abs(dp.x), abs(dp.y)) < 3
                        ? (abs(dp.x) > abs(dp.y) ? .x : .y) : .none
                    
                    allScrollPosition = .init()
                } else if isBeganScroll {
                    var dp = nScrollPosition - oldScrollPosition
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
                    let angle = dp.angle()
                    let dpl = dp.length() * 3.25
                    let length = dpl < 15 ? dpl : dpl
                        .clipped(min: 15, max: 200,
                                 newMin: 15, newMax: 500)
                    let scrollDeltaPosition = Point()
                        .movedWith(distance: length, angle: angle)
                    
                    document.scroll(.init(screenPoint: screenPoint(with: event).my,
                                          time: event.timestamp,
                                          scrollDeltaPoint: scrollDeltaPosition.mid(lastScrollDeltaPosition),
                                          phase: .changed,
                                          touchPhase: .changed,
                                          momentumPhase: nil))
                    scrollVs.append((scrollDeltaPosition, event.timestamp))
                    self.oldScrollPosition = nScrollPosition
                    lastScrollDeltaPosition = scrollDeltaPosition
                } else if isEnabledRotate
                            && !isBeganScroll && !isBeganPinch && !isBeganRotate
                            && nPinchDistance > 120
                            && abs(nPinchDistance - oldPinchDistance) <= 6
                            && nScrollPosition.distance(oldScrollPosition) <= 5
                            && abs(nRotateAngle.differenceRotation(oldRotateAngle)) > .pi * 0.02 {
                    
                    isBeganRotate = true
                    
                    scrollTimer?.cancel()
                    scrollTimer = nil
                    pinchTimer?.cancel()
                    pinchTimer = nil
                    document.rotate(.init(screenPoint: screenPoint(with: event).my,
                                         time: event.timestamp,
                                         rotationQuantity: 0,
                                         phase: .began))
                    self.oldRotateAngle = nRotateAngle
                    lastRotationQuantity = 0
                } else if isBeganRotate {
                    let rotationQuantity = nRotateAngle.differenceRotation(oldRotateAngle) * 80
                    document.rotate(.init(screenPoint: screenPoint(with: event).my,
                                          time: event.timestamp,
                                          rotationQuantity: rotationQuantity.mid(lastRotationQuantity),
                                          phase: .changed))
                    self.oldRotateAngle = nRotateAngle
                    lastRotationQuantity = rotationQuantity
                }
            }
        } else if ps.count == 3 {
            if touchedIDs.count == 3,
               isEnabledSwipe, let swipePosition,
               let ps0 = ps[touchedIDs[0]],
               let ops0 = oldTouchPoints[touchedIDs[0]],
               let ps1 = ps[touchedIDs[1]],
               let ops1 = oldTouchPoints[touchedIDs[1]],
               let ps2 = ps[touchedIDs[2]],
               let ops2 = oldTouchPoints[touchedIDs[2]] {
                
                let deltaP = [ps0 - ops0, ps1 - ops1, ps2 - ops2].sum()
                
                if !isBeganSwipe && abs(deltaP.x) > abs(deltaP.y) {
                    isBeganSwipe = true
                    
                    document.swipe(.init(screenPoint: screenPoint(with: event).my,
                                         time: event.timestamp,
                                         scrollDeltaPoint: Point(),
                                         phase: .began))
                    self.swipePosition = swipePosition + deltaP
                } else if isBeganSwipe {
                    document.swipe(.init(screenPoint: screenPoint(with: event).my,
                                         time: event.timestamp,
                                         scrollDeltaPoint: deltaP,
                                         phase: .changed))
                    self.swipePosition = swipePosition + deltaP
                }
            }
        } else if ps.count == 4 {
            let vs = (0 ..< 4).compactMap { ps[touchedIDs[$0]] }
            if let oldScrollPosition, vs.count == 4 {
                let np = vs.mean()!
                if np.distance(oldScrollPosition) > 5 {
                    isPreparePlay = false
                }
            }
        } else {
            if swipePosition != nil, isBeganSwipe {
                document.swipe(.init(screenPoint: screenPoint(with: event).my,
                                     time: event.timestamp,
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
    }
    override func touchesEnded(with event: NSEvent) {
        if oldTouchPoints.count == 4 {
            if isEnabledPlay && isPreparePlay {
                var event = inputKeyEventWith(event, .click, .began)
                event.inputKeyType = .control
                let player = Player(document)
                player.send(event)
                Sleep.start()
                event.phase = .ended
                player.send(event)
            }
        }
        
        if swipePosition != nil {
            document.swipe(.init(screenPoint: screenPoint(with: event).my,
                                 time: event.timestamp,
                                 scrollDeltaPoint: Point(),
                                 phase: .ended))
            swipePosition = nil
            isBeganSwipe = false
        }
        
        endPinch(with: event)
        endRotate(with: event)
        endScroll(with: event)
        
        oldTouchPoints = [:]
        touchedIDs = []
    }
    func endPinch(with event: NSEvent,
                  timeInterval: Double = 1 / 60) {
        guard isBeganPinch else { return }
        self.oldPinchDistance = nil
        isBeganPinch = false
        guard pinchVs.count >= 2 else { return }
        
        let fpi = pinchVs[..<(pinchVs.count - 1)]
            .lastIndex(where: { event.timestamp - $0.time > 0.05 }) ?? 0
        let lpv = pinchVs.last!
        let t = timeInterval + lpv.time
        
        let sd = pinchVs.last!.d
        let sign = sd < 0 ? -1.0 : 1.0
        let (a, b) = Double.leastSquares(xs: pinchVs[fpi...].map { $0.time },
                            ys: pinchVs[fpi...].map { abs($0.d) })
        let v = min(a * t + b, 10)
        var tv = v / timeInterval
        let minTV = 0.01
        let sv = tv / (tv - minTV)
        if tv.isNaN || v < 0.04 || a == 0 {
            document.pinch(.init(screenPoint: screenPoint(with: event).my,
                                 time: event.timestamp,
                                 magnification: 0,
                                 phase: .ended))
        } else {
            pinchTimer = DispatchSource.scheduledTimer(withTimeInterval: timeInterval) { [weak self] in
                DispatchQueue.main.async {
                    guard let self, !(self.pinchTimer?.isCancelled ?? true) else {
                        self?.pinchTimer?.cancel()
                        self?.pinchTimer = nil
                        return
                    }
                    tv *= 0.8
                    if tv < minTV {
                        self.pinchTimer?.cancel()
                        self.pinchTimer = nil
                        
                        self.document.pinch(.init(screenPoint: self.screenPoint(with: event).my,
                                              time: event.timestamp,
                                              magnification: 0,
                                              phase: .ended))
                    } else {
                        let m = timeInterval * (tv - minTV) * sv * sign
                        self.document.pinch(.init(screenPoint: self.screenPoint(with: event).my,
                                              time: event.timestamp,
                                              magnification: m,
                                              phase: .changed))
                    }
                }
            }
        }
    }
    func endRotate(with event: NSEvent) {
        guard isBeganRotate else { return }
        self.oldRotateAngle = nil
        isBeganRotate = false
        guard rotateVs.count >= 2 else { return }
        
        document.rotate(.init(screenPoint: screenPoint(with: event).my,
                             time: event.timestamp,
                             rotationQuantity: 0,
                             phase: .ended))
    }
    func endScroll(with event: NSEvent,
                   timeInterval: Double = 1 / 60) {
        guard isBeganScroll else { return }
        self.oldScrollPosition = nil
        isBeganScroll = false
        guard scrollVs.count >= 2 else { return }
        
        let fsi = scrollVs[..<(scrollVs.count - 1)]
            .lastIndex(where: { event.timestamp - $0.time > 0.05 }) ?? 0
        let lsv = scrollVs.last!
        let t = timeInterval + lsv.time
        
        let sdp = scrollVs.last!.dp
        let angle = sdp.angle()
        let (a, b) = Double.leastSquares(xs: scrollVs[fsi...].map { $0.time },
                            ys: scrollVs[fsi...].map { $0.dp.length() })
        let v = min(a * t + b, 700)
        let scale = v.clipped(min: 100, max: 700,
                              newMin: 0.9, newMax: 0.95)
        var tv = v / timeInterval
        let minTV = 100.0
        let sv = tv / (tv - minTV)
        if tv.isNaN || v < 5 || a == 0 {
            document.scroll(.init(screenPoint: screenPoint(with: event).my,
                                  time: event.timestamp,
                                  scrollDeltaPoint: .init(),
                                  phase: .ended,
                                  touchPhase: .ended,
                                  momentumPhase: nil))
        } else {
            document.scroll(.init(screenPoint: screenPoint(with: event).my,
                                  time: event.timestamp,
                                  scrollDeltaPoint: .init(),
                                  phase: .changed,
                                  touchPhase: .ended,
                                  momentumPhase: .began))
            
            scrollTimer = DispatchSource.scheduledTimer(withTimeInterval: timeInterval) { [weak self] in
                DispatchQueue.main.async {
                    guard let self, !(self.scrollTimer?.isCancelled ?? true) else {
                        self?.scrollTimer?.cancel()
                        self?.scrollTimer = nil
                        return
                    }
                    tv *= scale
                    let sdp = Point()
                        .movedWith(distance: timeInterval * (tv - minTV) * sv, angle: angle)
                    if tv < minTV {
                        self.scrollTimer?.cancel()
                        self.scrollTimer = nil
                        
                        self.document.scroll(.init(screenPoint: self.screenPoint(with: event).my,
                                              time: event.timestamp,
                                              scrollDeltaPoint: .init(),
                                              phase: .ended,
                                              touchPhase: nil,
                                                   momentumPhase: .ended))
                    } else {
                        self.document.scroll(.init(screenPoint: self.screenPoint(with: event).my,
                                              time: event.timestamp,
                                              scrollDeltaPoint: sdp,
                                              phase: .changed,
                                              touchPhase: nil,
                                            momentumPhase: .changed))
                    }
                }
            }
        }
    }
    
    func cancelScroll(with event: NSEvent) {
        scrollTimer?.cancel()
        scrollTimer = nil
        
        guard isBeganScroll else { return }
        isBeganScroll = false
        document.scroll(.init(screenPoint: screenPoint(with: event).my,
                              time: event.timestamp,
                              scrollDeltaPoint: .init(),
                              phase: .ended,
                              touchPhase: .ended,
                              momentumPhase: nil))
        oldScrollPosition = nil
    }
    func cancelPinch(with event: NSEvent) {
        pinchTimer?.cancel()
        pinchTimer = nil
        
        guard isBeganPinch else { return }
        isBeganPinch = false
        document.pinch(.init(screenPoint: screenPoint(with: event).my,
                             time: event.timestamp,
                             magnification: 0,
                             phase: .ended))
        oldPinchDistance = nil
    }
    func cancelRotatte(with event: NSEvent) {
        guard isBeganRotate else { return }
        isBeganRotate = false
        document.rotate(.init(screenPoint: screenPoint(with: event).my,
                             time: event.timestamp,
                              rotationQuantity: 0,
                             phase: .ended))
        oldRotateAngle = nil
    }
    override func touchesCancelled(with event: NSEvent) {
        if swipePosition != nil {
            document.swipe(.init(screenPoint: screenPoint(with: event).my,
                                 time: event.timestamp,
                                 scrollDeltaPoint: .init(),
                                 phase: .ended))
            swipePosition = nil
            isBeganSwipe = false
        }
        
        cancelScroll(with: event)
        cancelRotatte(with: event)
        cancelPinch(with: event)
        
        oldTouchPoints = [:]
        touchedIDs = []
    }
    
    private enum TouchGesture {
        case none, pinch, rotate
    }
    private var blockGesture = TouchGesture.none
    override func magnify(with nsEvent: NSEvent) {
        guard !isEnabledPinch else { return }
        if nsEvent.phase.contains(.began) {
            blockGesture = .pinch
            pinchVs = []
            document.pinch(pinchEventWith(nsEvent, .began))
        } else if nsEvent.phase.contains(.ended) {
            blockGesture = .none
            document.pinch(pinchEventWith(nsEvent, .ended))
            pinchVs = []
        } else if nsEvent.phase.contains(.changed) {
            pinchVs.append((Double(nsEvent.magnification), nsEvent.timestamp))
//            print("B", Double(nsEvent.magnification))
            document.pinch(pinchEventWith(nsEvent, .changed))
        }
    }
    
    private var isFirstStoppedRotation = true
    private var isBlockedRotation = false
    private var rotatedValue: Float = 0.0
    private let blockRotationValue: Float = 4.0
    override func rotate(with nsEvent: NSEvent) {
        guard !isEnabledRotate else { return }
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
                    document.rotate(rotateEventWith(nsEvent, .ended))
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
                        document.rotate(rotateEventWith(nsEvent, .began))
                    } else {
                        document.rotate(rotateEventWith(nsEvent, .changed))
                    }
                }
            }
        }
    }
    
    override func quickLook(with nsEvent: NSEvent) {
        guard window?.sheets.isEmpty ?? false else { return }
        
        document.inputKey(inputKeyEventWith(nsEvent, .lookUpTap, .began))
        Sleep.start()
        document.inputKey(inputKeyEventWith(nsEvent, .lookUpTap, .ended))
    }
    
    func windowLevel() -> Int {
        window?.level.rawValue ?? 0
    }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        [.markedClauseSegment, .glyphInfo]
    }
    func hasMarkedText() -> Bool {
        document.textEditor.editingTextView?.isMarked ?? false
    }
    func markedRange() -> NSRange {
        if let textView = document.textEditor.editingTextView,
           let range = textView.markedRange {
            return textView.model.string.nsRange(from: range)
                ?? NSRange(location: NSNotFound, length: 0)
        } else {
            return NSRange(location: NSNotFound, length: 0)
        }
    }
    func selectedRange() -> NSRange {
        if let textView = document.textEditor.editingTextView,
           let range = textView.selectedRange {
            return textView.model.string.nsRange(from: range)
                ?? NSRange(location: NSNotFound, length: 0)
        } else {
            return NSRange(location: NSNotFound, length: 0)
        }
    }
    func attributedString() -> NSAttributedString {
        if let text = document.textEditor.editingTextView?.model {
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
        let d = document.textEditor.characterRatio(for: p)
        return CGFloat(d ?? 0)
    }
    func characterIndex(for nsP: NSPoint) -> Int {
        let p = convertFromTopScreen(nsP).my
        if let i = document.textEditor.characterIndex(for: p),
           let string = document.textEditor.editingTextView?.model.string {
            
            return string.nsIndex(from: i)
        } else {
            return 0
        }
    }
    func firstRect(forCharacterRange nsRange: NSRange,
                   actualRange: NSRangePointer?) -> NSRect {
        if let string = document.textEditor.editingTextView?.model.string,
           let range = string.range(fromNS: nsRange),
           let rect = document.textEditor.firstRect(for: range) {
            return convertToTopScreen(rect.cg)
        } else {
            return NSRect()
        }
    }
    func baselineDeltaForCharacter(at nsI: Int) -> CGFloat {
        if let string = document.textEditor.editingTextView?.model.string,
           let i = string.index(fromNS: nsI),
           let d = document.textEditor.baselineDelta(at: i) {
            
            return CGFloat(d)
        } else {
            return 0
        }
    }
    func drawsVerticallyForCharacter(at nsI: Int) -> Bool {
        if let o = document.textEditor.editingTextView?.textOrientation {
            return o == .vertical
        } else {
            return false
        }
    }
    
    func unmarkText() {
        document.textEditor.unmark()
    }
    
    func setMarkedText(_ str: Any,
                       selectedRange selectedNSRange: NSRange,
                       replacementRange replacementNSRange: NSRange) {
        guard let string = document.textEditor
                .editingTextView?.model.string else { return }
        let range = string.range(fromNS: replacementNSRange)
        
        func mark(_ mStr: String) {
            if let markingRange = mStr.range(fromNS: selectedNSRange) {
                document.textEditor.mark(mStr,
                                         markingRange: markingRange,
                                         at: range)
            }
        }
        if let attString = str as? NSAttributedString {
            mark(attString.string.swiftBased)
        } else if let nsString = str as? NSString {
            mark((nsString as String).swiftBased)
        }
    }
    func insertText(_ str: Any, replacementRange: NSRange) {
        guard let string = document.textEditor
                .editingTextView?.model.string else { return }
        let range = string.range(fromNS: replacementRange)
        
        if let attString = str as? NSAttributedString {
            document.textEditor.insert(attString.string.swiftBased,
                                       at: range)
        } else if let nsString = str as? NSString {
            document.textEditor.insert((nsString as String).swiftBased,
                                       at: range)
        }
    }
    
//    // control return
//    override func insertLineBreak(_ sender: Any?) {}
//    // option return
//    override func insertNewlineIgnoringFieldEditor(_ sender: Any?) {}
    override func insertNewline(_ sender: Any?) {
        document.textEditor.insertNewline()
    }
    override func insertTab(_ sender: Any?) {
        document.textEditor.insertTab()
    }
    override func deleteBackward(_ sender: Any?) {
        document.textEditor.deleteBackward()
    }
    override func deleteForward(_ sender: Any?) {
        document.textEditor.deleteForward()
    }
    override func moveLeft(_ sender: Any?) {
        document.textEditor.moveLeft()
    }
    override func moveRight(_ sender: Any?) {
        document.textEditor.moveRight()
    }
    override func moveUp(_ sender: Any?) {
        document.textEditor.moveUp()
    }
    override func moveDown(_ sender: Any?) {
        document.textEditor.moveDown()
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
        
        if let encoder = commandBuffer
            .makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            
            let ctx = Context(encoder, renderstate)
            let wtvTransform = document.worldToViewportTransform
            let wtsScale = document.worldToScreenScale
            document.rootNode.draw(with: wtvTransform, scale: wtsScale, in: ctx)
            
            if isShownDebug || isShownClock {
                drawDebugNode(in: ctx)
            }
            if !isHiddenActionList {
                let t = document.screenToViewportTransform
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
            print(string0)
            debugNode.path = Text(string: string0 + (isShownClock && isShownDebug ? " " : "") + string1).typesetter.path()
        }
        let t = document.screenToViewportTransform
        debugNode.draw(with: t, scale: 1, in: context)
    }
}
typealias NodeOwner = SubMTKView

final class Context {
    fileprivate var encoder: MTLRenderCommandEncoder
    fileprivate let rs: Renderstate
    
    fileprivate init(_ encoder: MTLRenderCommandEncoder,
                     _ rs: Renderstate) {
        self.encoder = encoder
        self.rs = rs
    }
    
    func setVertex(_ buffer: Buffer, offset: Int = 0, at index: Int) {
        encoder.setVertexBuffer(buffer.mtl, offset: offset, index: index)
    }
    func setVertex(bytes: UnsafeRawPointer, length: Int, at index: Int) {
        encoder.setVertexBytes(bytes, length: length, index: index)
    }
    func setVertexCacheSampler(at index: Int) {
        encoder.setVertexSamplerState(rs.cacheSamplerState, index: index)
    }
    
    func setFragment(_ texture: Texture?, at index: Int) {
        encoder.setFragmentTexture(texture?.mtl, index: index)
    }
    
    @discardableResult
    func drawTriangle(start i: Int = 0, with counts: [Int]) -> Int {
        counts.reduce(into: i) {
            encoder.drawPrimitives(type: .triangle,
                                   vertexStart: $0, vertexCount: $1)
            $0 += $1
        }
    }
    @discardableResult
    func drawTriangleStrip(start i: Int = 0, with counts: [Int]) -> Int {
        counts.reduce(into: i) {
            encoder.drawPrimitives(type: .triangleStrip,
                                   vertexStart: $0, vertexCount: $1)
            $0 += $1
        }
    }
    
    func clip(_ rect: Rect) {
        encoder.setScissorRect(MTLScissorRect(x: Int(rect.minX),
                                              y: Int(rect.minY),
                                              width: max(1, Int(rect.width)),
                                              height: max(1, Int(rect.height))))
    }
    
    func setOpaqueColorPipeline() {
        encoder.setRenderPipelineState(rs.opaqueColorRenderPipelineState)
    }
    func setMinColorPipeline() {
        encoder.setRenderPipelineState(rs.minColorRenderPipelineState)
    }
    func setAlphaColorPipeline() {
        encoder.setRenderPipelineState(rs.alphaColorRenderPipelineState)
    }
    func setColorsPipeline() {
        encoder.setRenderPipelineState(rs.colorsRenderPipelineState)
    }
    func setMaxColorsPipeline() {
        encoder.setRenderPipelineState(rs.maxColorsRenderPipelineState)
    }
    func setOpaqueTexturePipeline() {
        encoder.setRenderPipelineState(rs.opaqueTextureRenderPipelineState)
    }
    func setAlphaTexturePipeline() {
        encoder.setRenderPipelineState(rs.alphaTextureRenderPipelineState)
    }
    func setStencilPipeline() {
        encoder.setRenderPipelineState(rs.stencilRenderPipelineState)
    }
    func setStencilBezierPipeline() {
        encoder.setRenderPipelineState(rs.stencilBezierRenderPipelineState)
    }
    func setInvertDepthStencil() {
        encoder.setDepthStencilState(rs.invertDepthStencilState)
    }
    func setNormalDepthStencil() {
        encoder.setDepthStencilState(rs.normalDepthStencilState)
    }
    func setClippingDepthStencil() {
        encoder.setDepthStencilState(rs.clippingDepthStencilState)
    }
}

extension Node {
    func moveCursor(to sp: Point) {
        if let subMTKView = owner, let h = NSScreen.main?.frame.height {
            let np = subMTKView.convertToTopScreen(sp.cg)
            CGDisplayMoveCursorToPoint(0, CGPoint(x: np.x, y: h - np.y))
        }
    }
    func show(definition: String, font: Font, orientation: Orientation, at p: Point) {
        if let owner = owner {
            let attributes = Typobute(font: font,
                                      orientation: orientation).attributes()
            let attString = NSAttributedString(string: definition,
                                               attributes: attributes)
            let sp = owner.document.convertWorldToScreen(convertToWorld(p))
            owner.showDefinition(for: attString, at: sp.cg)
        }
    }
    func show(_ error: Error) {
        guard let window = owner?.window else { return }
        NSAlert(error: error).beginSheetModal(for: window,
                                              completionHandler: { _ in })
    }
    func show(message: String = "", infomation: String = "",
              isCaution: Bool = false) {
        guard let window = owner?.window else { return }
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = infomation
        if isCaution {
            alert.alertStyle = .critical
            alert.window.defaultButtonCell = nil
        }
        alert.beginSheetModal(for: window) { _ in }
    }
    func show(message: String, infomation: String, okTitle: String,
              isSaftyCheck: Bool = false,
              isDefaultButton: Bool = false,
              okClosure: @escaping () -> (),
              cancelClosure: @escaping () -> ()) {
        guard let window = owner?.window else { return }
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
        alert.beginSheetModal(for: window) { (mr) in
            switch mr {
            case .alertFirstButtonReturn:
                okClosure()
            default:
                cancelClosure()
            }
        }
    }
    func show(message: String, infomation: String, titles: [String],
              closure: @escaping (Int) -> ()) {
        guard let window = owner?.window else { return }
        let alert = NSAlert()
        for title in titles {
            alert.addButton(withTitle: title)
        }
        alert.messageText = message
        alert.informativeText = infomation
        alert.beginSheetModal(for: window) { (mr) in
            closure(mr.rawValue)
        }
    }
    func show(message: String, infomation: String,
              doneClosure: @escaping () -> ()) {
        guard let window = owner?.window else { return }
        let alert = NSAlert()
        alert.addButton(withTitle: "Done".localized)
        alert.messageText = message
        alert.informativeText = infomation
        alert.beginSheetModal(for: window) { (_) in
            doneClosure()
        }
    }
    func show(_ progressPanel: ProgressPanel) {
        guard let window = owner?.window else { return }
        progressPanel.window = window
        progressPanel.begin()
        window.beginSheet(progressPanel) { _ in }
    }
}

extension Node {
    func renderedTexture(with size: Size, backgroundColor: Color,
                         sampleCount: Int = 4, mipmapped: Bool = false) -> Texture? {
        guard let bounds = bounds else { return nil }
        return renderedTexture(in: bounds, to: size,
                               backgroundColor: backgroundColor,
                               sampleCount: sampleCount, mipmapped: mipmapped)
    }
    func renderedAntialiasFillImage(in bounds: Rect, to size: Size,
                                    backgroundColor: Color) -> Image? {
        guard children.contains(where: { $0.fillType != nil }) else {
            return image(in: bounds,
                         size: size,
                         backgroundColor: backgroundColor,
                         colorSpace: .sRGB)
        }
        
        children.forEach {
            if $0.lineType != nil {
                $0.isHidden = true
            }
        }
        guard let oImage = image(in: bounds, size: size * 2, backgroundColor: backgroundColor, colorSpace: .sRGB, isAntialias: false)?
            .resize(with: size) else { return nil }
        children.forEach {
            if $0.lineType != nil {
                $0.isHidden = false
            }
            if $0.fillType != nil {
                $0.isHidden = true
            }
        }
        fillType = nil
        guard let nImage = image(in: bounds,
                                 size: size,
                                 backgroundColor: nil,
                                 colorSpace: .sRGB) else { return nil }
        return oImage.drawn(nImage, in: Rect(size: size))
    }
    func renderedTexture(in bounds: Rect, to size: Size,
                         backgroundColor: Color,
                         sampleCount: Int = 4, mipmapped: Bool = false) -> Texture? {
        let transform = Transform(translation: -bounds.origin)
            * Transform(invertedViewportSize: bounds.size)
        return renderedTexture(to: size, transform: transform,
                               backgroundColor: backgroundColor,
                               sampleCount: sampleCount, mipmapped: mipmapped)
    }
    func renderedTexture(to size: Size, transform: Transform,
                         backgroundColor: Color,
                         sampleCount: Int = 4, mipmapped: Bool = false) -> Texture? {
        let width = Int(size.width), height = Int(size.height)
        guard width > 0 && height > 0 else { return nil }
        
        let renderer = Renderer.shared
        
        let renderstate: Renderstate
        if sampleCount == 8 && renderer.device.supportsTextureSampleCount(8) {
            if let aRenderstate = Renderstate.sampleCount8 {
                renderstate = aRenderstate
            } else {
                return nil
            }
        } else if sampleCount == 4 {
            if let aRenderstate = Renderstate.sampleCount4 {
                renderstate = aRenderstate
            } else {
                return nil
            }
        } else {
            if let aRenderstate = Renderstate.sampleCount1 {
                renderstate = aRenderstate
            } else {
                return nil
            }
        }
        
        let rpd: MTLRenderPassDescriptor, mtlTexture: MTLTexture
        if sampleCount > 1 {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderer.pixelFormat,
                                                              width: width,
                                                              height: height,
                                                              mipmapped: mipmapped)
            guard let aMTLTexture
                    = renderer.device.makeTexture(descriptor: td) else { return nil }
            mtlTexture = aMTLTexture
            
            let msaatd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderer.pixelFormat,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: false)
            msaatd.storageMode = .private
            msaatd.usage = .renderTarget
            msaatd.textureType = .type2DMultisample
            msaatd.sampleCount = renderstate.sampleCount
            guard let msaaTexture
                    = renderer.device.makeTexture(descriptor: msaatd) else { return nil }
            
            rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].storeAction = .multisampleResolve
            rpd.colorAttachments[0].clearColor = backgroundColor.mtl
            rpd.colorAttachments[0].texture = msaaTexture
            rpd.colorAttachments[0].resolveTexture = mtlTexture
        } else {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderer.pixelFormat,
                                                              width: width,
                                                              height: height,
                                                              mipmapped: mipmapped)
            td.usage = [.renderTarget, .shaderRead]
            guard let aMTLTexture
                    = renderer.device.makeTexture(descriptor: td) else { return nil }
            mtlTexture = aMTLTexture
            
            rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].storeAction = .store
            rpd.colorAttachments[0].clearColor = backgroundColor.mtl
            rpd.colorAttachments[0].texture = mtlTexture
        }
        
        let stencilD = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .stencil8,
                                                                width: width,
                                                                height: height,
                                                                mipmapped: false)
        stencilD.storageMode = .private
        stencilD.usage = .renderTarget
        if sampleCount > 1 {
            stencilD.textureType = .type2DMultisample
            stencilD.sampleCount = renderstate.sampleCount
        } else {
            stencilD.textureType = .type2D
        }
        guard let stencilMTLTexture = renderer.device.makeTexture(descriptor: stencilD) else { return nil }
        rpd.stencilAttachment.texture = stencilMTLTexture
        
        guard let commandBuffer
                = renderer.commandQueue.makeCommandBuffer() else { return nil }
        guard let encoder
                = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { return nil }
        
        isRenderCache = false
        let ctx = Context(encoder, renderstate)
        draw(with: localTransform.inverted() * transform, in: ctx)
        ctx.encoder.endEncoding()
        isRenderCache = true
        
        let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()
        if mipmapped {
            blitCommandEncoder?.generateMipmaps(for: mtlTexture)
        } else {
            blitCommandEncoder?.synchronize(resource: mtlTexture)
        }
        blitCommandEncoder?.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return Texture(mtlTexture, isOpaque: backgroundColor.opacity == 1,
                       colorSpace: renderer.colorSpace)
    }
    
    func render(with size: Size, in pdf: PDF) {
        guard let bounds = bounds else { return }
        render(in: bounds, to: size, in: pdf)
    }
    func render(with size: Size, backgroundColor: Color, in pdf: PDF) {
        guard let bounds = bounds else { return }
        render(in: bounds, to: size,
               backgroundColor: backgroundColor, in: pdf)
    }
    func render(in bounds: Rect, to size: Size, in pdf: PDF) {
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: size.width / bounds.width,
                        y: size.height / bounds.height)
        render(to: size, transform: transform, in: pdf)
    }
    func render(in bounds: Rect, to size: Size,
                backgroundColor: Color, in pdf: PDF) {
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: size.width / bounds.width,
                        y: size.height / bounds.height)
        render(to: size, transform: transform,
               backgroundColor: backgroundColor, in: pdf)
    }
    func render(to size: Size, transform: Transform, in pdf: PDF) {
        let ctx = pdf.ctx
        let nt = localTransform.inverted() * transform
        ctx.saveGState()
        ctx.beginPDFPage(nil)
        
        if case .color(let backgroundColor) = fillType {
            ctx.setFillColor(backgroundColor.cg)
            ctx.fill(Rect(origin: Point(), size: size).cg)
        }
        ctx.concatenate(nt.cg)
        render(in: ctx)
        
        ctx.endPDFPage()
        ctx.restoreGState()
    }
    func render(to size: Size, transform: Transform,
                backgroundColor: Color, in pdf: PDF) {
        let ctx = pdf.ctx
        let nt = localTransform.inverted() * transform
        ctx.saveGState()
        ctx.beginPDFPage(nil)
        
        ctx.setFillColor(backgroundColor.cg)
        ctx.fill(Rect(origin: Point(), size: size).cg)
        ctx.concatenate(nt.cg)
        render(in: ctx)
        
        ctx.endPDFPage()
        ctx.restoreGState()
    }
    func render(in bounds: Rect, to toBounds: Rect, in pdf: PDF) {
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: toBounds.width / bounds.width,
                        y: toBounds.height / bounds.height)
            * Transform(translation: toBounds.origin)
        let ctx = pdf.ctx
        let nt = localTransform.inverted() * transform
        ctx.saveGState()
        if case .color(let backgroundColor) = fillType {
            ctx.setFillColor(backgroundColor.cg)
            ctx.fill(toBounds.cg)
        }
        ctx.concatenate(nt.cg)
        render(in: ctx)
        ctx.restoreGState()
    }
    func render(in bounds: Rect, to toBounds: Rect,
                backgroundColor: Color, in pdf: PDF) {
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: toBounds.width / bounds.width,
                        y: toBounds.height / bounds.height)
            * Transform(translation: toBounds.origin)
        let ctx = pdf.ctx
        let nt = localTransform.inverted() * transform
        ctx.saveGState()
        ctx.setFillColor(backgroundColor.cg)
        ctx.fill(toBounds.cg)
        ctx.concatenate(nt.cg)
        render(in: ctx)
        ctx.restoreGState()
    }
    
    func imageInBounds(size: Size? = nil,
                       backgroundColor: Color? = nil,
                       colorSpace: RGBColorSpace,
                       isAntialias: Bool = true) -> Image? {
        guard let bounds = bounds else { return nil }
        return image(in: bounds, size: size ?? bounds.size,
                     backgroundColor: backgroundColor, colorSpace: colorSpace,
                     isAntialias: isAntialias)
    }
    func image(in bounds: Rect,
               size: Size,
               backgroundColor: Color? = nil, colorSpace: RGBColorSpace,
               isAntialias: Bool = true) -> Image? {
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: size.width / bounds.width,
                        y: size.height / bounds.height)
        return image(size: size, transform: transform,
                     backgroundColor: backgroundColor, colorSpace: colorSpace,
                     isAntialias: isAntialias)
    }
    func image(size: Size, transform: Transform,
               backgroundColor: Color? = nil, colorSpace: RGBColorSpace,
               isAntialias: Bool = true) -> Image? {
        guard let space = colorSpace.cg else { return nil }
        let ctx: CGContext
        if colorSpace.isHDR {
            let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            guard let actx = CGContext(data: nil,
                                      width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 32, bytesPerRow: 0, space: space,
                                      bitmapInfo: bitmapInfo.rawValue) else { return nil }
            ctx = actx
        } else {
            let bitmapInfo = CGBitmapInfo(rawValue: backgroundColor?.opacity == 1 ?
                                            CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let actx = CGContext(data: nil,
                                      width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: bitmapInfo.rawValue) else { return nil }
            ctx = actx
        }
        
        let nt = localTransform.inverted() * transform
        ctx.saveGState()
        if let backgroundColor = backgroundColor {
            ctx.setFillColor(backgroundColor.cg)
            ctx.fill(Rect(origin: Point(), size: size).cg)
        } else if case .color(let backgroundColor)? = fillType {
            ctx.setFillColor(backgroundColor.cg)
            ctx.fill(Rect(origin: Point(), size: size).cg)
        }
        ctx.setShouldAntialias(isAntialias)
        ctx.concatenate(nt.cg)
        render(in: ctx)
        ctx.restoreGState()
        guard let cgImage = ctx.makeImage() else { return nil }
        
//        //
//        if appearance == .dark {
//            let filters = SubMTKView.darkFilters()
//            var ciImage = CIImage(cgImage: cgImage)
//            for filter in filters {
//                filter.setValue(ciImage, forKey: kCIInputImageKey)
//                if let nCiImage = filter.outputImage {
//                    ciImage = nCiImage
//                }
//            }
//            let cictx = CIContext()
//            let rect = CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height)
//            if let nImage = cictx.createCGImage(ciImage, from: rect) {
//                return Image(cgImage: nImage)
//            }
//        }
        
        return Image(cgImage: cgImage)
    }
    func renderInBounds(size: Size? = nil, in ctx: CGContext) {
        guard let bounds = bounds else { return }
        render(in: bounds, size: size ?? bounds.size, in: ctx)
    }
    func render(in bounds: Rect, size: Size, in ctx: CGContext) {
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: size.width / bounds.width,
                        y: size.height / bounds.height)
        render(transform: transform, in: ctx)
    }
    func render(transform: Transform, in ctx: CGContext) {
        let nt = localTransform.inverted() * transform
        ctx.saveGState()
        ctx.concatenate(nt.cg)
        render(in: ctx)
        ctx.restoreGState()
    }
    func render(in ctx: CGContext) {
        guard !isHidden else { return }
        if !isIdentityFromLocal {
            ctx.saveGState()
            ctx.concatenate(localTransform.cg)
        }
        if let typesetter = path.typesetter, let b = bounds {
            if let lineType = lineType {
                switch lineType {
                case .color(let color):
                    ctx.saveGState()
                    ctx.setStrokeColor(color.cg)
                    ctx.setLineWidth(lineWidth)
                    ctx.setLineJoin(.round)
                    typesetter.append(in: ctx)
                    ctx.strokePath()
                    ctx.restoreGState()
                case .gradient: break
                }
            }
            switch fillType {
            case .color(let color):
                typesetter.draw(in: b, fillColor: color, in: ctx)
            default:
                typesetter.draw(in: b, fillColor: .content, in: ctx)
            }
        } else if !path.isEmpty {
            if let fillType = fillType {
                switch fillType {
                case .color(let color):
                    let cgPath = CGMutablePath()
                    for pathline in path.pathlines {
                        let polygon = pathline.polygon()
                        let points = polygon.points.map { $0.cg }
                        cgPath.addLines(between: points)
                        cgPath.closeSubpath()
                    }
                    ctx.addPath(cgPath)
                    let cgColor = color.cg
                    if isCPUFillAntialias {
                        ctx.setFillColor(cgColor)
                        ctx.drawPath(using: .fill)
                    } else {
                        ctx.setShouldAntialias(false)
                        ctx.setFillColor(cgColor)
                        ctx.drawPath(using: .fill)
                        ctx.setShouldAntialias(true)
                    }
                case .gradient(let colors):
                    if let ts = path.triangleStrip {
                        let rgbas = colors.map { $0.rgba.premultipliedAlpha }
                        let minCount = min(ts.points.count, rgbas.count)
                        if minCount >= 3 {
                            for i in 2 ..< minCount {
                                if i % 2 == 0 {
                                    ctx.drawTriangleInData(.init(ts.points[i - 2], ts.points[i],
                                              ts.points[i - 1]),
                                                           rgbas[i - 2], rgbas[i], rgbas[i - 1])
                                } else {
                                    ctx.drawTriangleInData(.init(ts.points[i - 2], ts.points[i - 1],
                                                                 ts.points[i]),
                                                           rgbas[i - 2], rgbas[i - 1], rgbas[i])
                                }
                            }
                        }
                    }
                case .maxGradient(let colors):
                    ctx.saveGState()
                    ctx.setBlendMode(.darken)
                    
                    if let ts = path.triangleStrip {
                        let rgbas = colors.map { $0.rgba.premultipliedAlpha }
                        let minCount = min(ts.points.count, rgbas.count)
                        if minCount >= 3 {
                            for i in 2 ..< minCount {
                                if i % 2 == 0 {
                                    ctx.drawTriangleInData(.init(ts.points[i - 2], ts.points[i],
                                              ts.points[i - 1]),
                                                           rgbas[i - 2], rgbas[i], rgbas[i - 1])
                                } else {
                                    ctx.drawTriangleInData(.init(ts.points[i - 2], ts.points[i - 1],
                                                                 ts.points[i]),
                                                           rgbas[i - 2], rgbas[i - 1], rgbas[i])
                                }
                            }
                        }
                    }
                    
                    ctx.restoreGState()
                case .texture(let texture):
                    if let cgImage = texture.cgImage, let b = bounds {
                        ctx.draw(cgImage, in: b.cg)
                    }
                }
            }
            if let lineType = lineType {
                switch lineType {
                case .color(let color):
                    ctx.setFillColor(color.cg)
                    let (pd, counts) = path.outlinePointsDataWith(lineWidth: lineWidth)
                    var i = 0
                    let cgPath = CGMutablePath()
                    for count in counts {
                        let points = (i ..< (i + count)).map {
                            Point(Double(pd[$0 * 4]),
                                  Double(pd[$0 * 4 + 1])).cg
                        }
                        cgPath.addLines(between: points)
                        cgPath.closeSubpath()
                        i += count
                    }
                    ctx.addPath(cgPath)
                    ctx.fillPath()
                case .gradient(let colors):
                    let (pd, counts) = path.linePointsDataWith(lineWidth: lineWidth)
                    let rgbas = path.lineColorsDataWith(colors, lineWidth: lineWidth)
                    var i = 0
                    for count in counts {
                        let points = (i ..< (i + count)).map {
                            Point(Double(pd[$0 * 4]),
                                  Double(pd[$0 * 4 + 1]))
                        }
                        let ts = TriangleStrip(points: points)
                        let minCount = min(ts.points.count, rgbas.count)
                        if minCount >= 3 {
                            for i in 2 ..< minCount {
                                if i % 2 == 0 {
                                    ctx.drawTriangleInData(.init(ts.points[i - 2], ts.points[i],
                                              ts.points[i - 1]),
                                                           rgbas[i - 2], rgbas[i], rgbas[i - 1])
                                } else {
                                    ctx.drawTriangleInData(.init(ts.points[i - 2], ts.points[i - 1],
                                                                 ts.points[i]),
                                                           rgbas[i - 2], rgbas[i - 1], rgbas[i])
                                }
                            }
                        }
                        
                        i += count
                    }
                }
            }
        }
        children.forEach { $0.render(in: ctx) }
        if !isIdentityFromLocal {
            ctx.restoreGState()
        }
    }
}

extension CGContext {
    func drawTriangleInData(_ triangle: Triangle, _ rgba0: RGBA, _ rgba1: RGBA, _ rgba2: RGBA) {
        let bounds = triangle.bounds.integral
        let area = triangle.area
        guard area > 0, let bitmap = Bitmap<UInt8>(width: Int(bounds.width), height: Int(bounds.height),
                                                   colorSpace: .sRGB) else { return }
            
        saveGState()
        
        let path = CGMutablePath()
        path.addLines(between: [triangle.p0.cg, triangle.p1.cg, triangle.p2.cg])
        path.closeSubpath()
        addPath(path)
        clip()
        
        let rArea = Float(1 / area)
        for y in bitmap.height.range {
            for x in bitmap.width.range {
                let p = Point(x, bitmap.height - y - 1) + bounds.origin
                let areas = triangle.subs(form: p).map { Float($0.area) }
                let r = (rgba0.r * areas[1] + rgba1.r * areas[2] + rgba2.r * areas[0]) * rArea
                let g = (rgba0.g * areas[1] + rgba1.g * areas[2] + rgba2.g * areas[0]) * rArea
                let b = (rgba0.b * areas[1] + rgba1.b * areas[2] + rgba2.b * areas[0]) * rArea
                let a = (rgba0.a * areas[1] + rgba1.a * areas[2] + rgba2.a * areas[0]) * rArea
                bitmap[x, y, 0] = UInt8(r.clipped(min: 0, max: 1) * Float(UInt8.max))
                bitmap[x, y, 1] = UInt8(g.clipped(min: 0, max: 1) * Float(UInt8.max))
                bitmap[x, y, 2] = UInt8(b.clipped(min: 0, max: 1) * Float(UInt8.max))
                bitmap[x, y, 3] = UInt8(a.clipped(min: 0, max: 1) * Float(UInt8.max))
            }
        }
            
        if let cgImage = bitmap.image?.cg {
            draw(cgImage, in: bounds.cg)
        }
        
        restoreGState()
    }
}

extension MTLDevice {
    func makeBuffer(_ values: [Float]) -> Buffer? {
        let size = values.count * MemoryLayout<Float>.stride
        if let mtlBuffer = makeBuffer(bytes: values,
                                      length: size,
                                      options: .storageModeManaged) {
            return Buffer(mtl: mtlBuffer)
        } else {
            return nil
        }
    }
    func makeBuffer(_ values: [RGBA]) -> Buffer? {
        let size = values.count * MemoryLayout<RGBA>.stride
        if let mtlBuffer = makeBuffer(bytes: values,
                                      length: size,
                                      options: .storageModeManaged) {
            return Buffer(mtl: mtlBuffer)
        } else {
            return nil
        }
    }
    func makeBuffer(_ value: RGBA) -> Buffer? {
        var value = value
        let size = MemoryLayout<RGBA>.stride
        if let mtlBuffer = makeBuffer(bytes: &value,
                                      length: size,
                                      options: .storageModeManaged) {
            return Buffer(mtl: mtlBuffer)
        } else {
            return nil
        }
    }
}

extension Color {
    var mtl: MTLClearColor {
        MTLClearColorMake(Double(rgba.r), Double(rgba.g),
                          Double(rgba.b), Double(rgba.a))
    }
}

struct Buffer {
    fileprivate let mtl: MTLBuffer
}

struct Texture {
    static let maxWidth = 16384, maxHeight = 16384
    
    fileprivate let mtl: MTLTexture
    let isOpaque: Bool
    let cgColorSpace: CGColorSpace
    var cgImage: CGImage? {
        mtl.cgImage(with: cgColorSpace)
    }
    
    fileprivate init(_ mtl: MTLTexture, isOpaque: Bool, colorSpace: CGColorSpace) {
        self.mtl = mtl
        self.isOpaque = isOpaque
        self.cgColorSpace = colorSpace
    }
    static func mipmapLevel(from size: Size) -> Int {
        Int(Double.log2(max(size.width, size.height)).rounded(.down)) + 1
    }
    struct TextureError: Error {}
    static func texture(mipmapData: Data,
                        completionHandler: @escaping (Texture) -> (),
                        cancelHandler: @escaping (Error) -> ()) throws {
        guard let cgImageSource = CGImageSourceCreateWithData(mipmapData as CFData, nil) else {
            throw TextureError()
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            throw TextureError()
        }
        try Texture.texture(mipmapCGImage: cgImage,
                            completionHandler: completionHandler,
                            cancelHandler: cancelHandler)
    }
    static func texture(mipmapImage: Image,
                        isOpaque: Bool = true,
                        completionHandler: @escaping (Texture) -> (),
                        cancelHandler: @escaping (Error) -> ()) throws {
        try texture(mipmapCGImage: mipmapImage.cg, isOpaque: isOpaque,
                    completionHandler: completionHandler,
                    cancelHandler: cancelHandler)
    }
    static func texture(mipmapCGImage cgImage: CGImage,
                        isOpaque: Bool = true,
                        completionHandler: @escaping (Texture) -> (),
                        cancelHandler: @escaping (Error) -> ()) throws {
        guard let dp = cgImage.dataProvider, let data = dp.data else { throw TextureError() }
        let iw = cgImage.width, ih = cgImage.height
        
        struct Mipmap {
            let data: Data, width: Int, height: Int, level: Int, bytesPerRow: Int
        }
        var mipmaps = [Mipmap]()
        let colorSpace = Renderer.shared.imageColorSpace
        var image = Image(cgImage: cgImage)
        var level = 1
        var mipW = iw / 2, mipH = ih / 2
        while mipW >= 1 && mipH >= 1 {
            guard let aImage = image.resize(with: Size(width: mipW, height: mipH)) else { throw TextureError() }
            image = aImage
            let cgImage = image.cg
            guard let ndp = cgImage.dataProvider, let ndata = ndp.data else { throw TextureError() }
            mipmaps.append(Mipmap(data: ndata as Data, width: mipW, height: mipH,
                                  level: level, bytesPerRow: cgImage.bytesPerRow))
            
            mipW /= 2
            mipH /= 2
            level += 1
        }
        
        DispatchQueue.main.async {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Renderer.shared.imagePixelFormat,
                                                              width: iw, height: ih,
                                                              mipmapped: true)
            guard let mtl = Renderer.shared.device.makeTexture(descriptor: td) else {
                cancelHandler(TextureError())
                return
            }
            
            guard let baseBytes = CFDataGetBytePtr(data) else {
                cancelHandler(TextureError())
                return
            }
            let region = MTLRegionMake2D(0, 0, iw, ih)
            mtl.replace(region: region, mipmapLevel: 0,
                        withBytes: baseBytes, bytesPerRow: cgImage.bytesPerRow)
            
            mipmaps.forEach {
                guard let bytes
                        = CFDataGetBytePtr(($0.data as CFData)) else {
                    cancelHandler(TextureError())
                    return
                }
                let region = MTLRegionMake2D(0, 0, $0.width, $0.height)
                mtl.replace(region: region, mipmapLevel: $0.level,
                            withBytes: bytes, bytesPerRow: $0.bytesPerRow)
            }
            
            completionHandler(Texture(mtl, isOpaque: isOpaque, colorSpace: colorSpace))
        }
    }
    static func bc1Texture(mipmapData: Data, isOpaque: Bool,
                           completionHandler: @escaping (Texture) -> ()) {
        guard let cgImageSource = CGImageSourceCreateWithData(mipmapData as CFData, nil) else { return }
        guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else { return }
        guard let dp = cgImage.dataProvider, let data = dp.data else { return }
        guard let baseBytes = CFDataGetBytePtr(data) else { return }
        let iw = cgImage.width, ih = cgImage.height
        let bc1Data = Texture.bc1Data(with: baseBytes, width: iw, height: ih)
        guard let bc1Bytes = CFDataGetBytePtr((bc1Data.data as CFData)) else { return }
        
        DispatchQueue.main.async {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bc1_rgba,
                                                              width: iw, height: ih,
                                                              mipmapped: false)
            guard let mtl = Renderer.shared.device.makeTexture(descriptor: td) else { return }
            
            let region = MTLRegionMake2D(0, 0, iw, ih)
            mtl.replace(region: region, mipmapLevel: 0,
                        withBytes: bc1Bytes, bytesPerRow: 8 * bc1Data.blockW)
            
            completionHandler(Texture(mtl, isOpaque: isOpaque,
                                      colorSpace: Renderer.shared.colorSpace))
        }
    }
    init?(data: Data, isOpaque: Bool) {
        guard let cgImageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            return nil
        }
        guard let dp = cgImage.dataProvider, let data = dp.data else {
            return nil
        }
        let iw = cgImage.width, ih = cgImage.height
        
        struct Mipmap {
            let data: Data, width: Int, height: Int, level: Int, bytesPerRow: Int
        }
        var mipmaps = [Mipmap]()
        let colorSpace = Renderer.shared.imageColorSpace
        var image = Image(cgImage: cgImage)
        var level = 1
        var mipW = iw / 2, mipH = ih / 2
        while mipW >= 1 && mipH >= 1 {
            guard let aImage = image.resize(with: Size(width: mipW, height: mipH)) else {
                return nil
            }
            image = aImage
            let nCGImage = image.cg
            guard let ndp = nCGImage.dataProvider, let ndata = ndp.data else {
                return nil
            }
            mipmaps.append(Mipmap(data: ndata as Data, width: mipW, height: mipH,
                                  level: level, bytesPerRow: nCGImage.bytesPerRow))
            
            mipW /= 2
            mipH /= 2
            level += 1
        }
        
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Renderer.shared.imagePixelFormat,
                                                          width: iw, height: ih,
                                                          mipmapped: true)
        guard let mtl = Renderer.shared.device.makeTexture(descriptor: td) else {
            return nil
        }
        
        guard let abaseBytes = CFDataGetBytePtr(data) else {
            return nil
        }
        let region = MTLRegionMake2D(0, 0, iw, ih)
        mtl.replace(region: region, mipmapLevel: 0,
                    withBytes: abaseBytes, bytesPerRow: cgImage.bytesPerRow)
        
        mipmaps.forEach {
            guard let bytes
                    = CFDataGetBytePtr(($0.data as CFData)) else { return }
            let region = MTLRegionMake2D(0, 0, $0.width, $0.height)
            mtl.replace(region: region, mipmapLevel: $0.level,
                        withBytes: bytes, bytesPerRow: $0.bytesPerRow)
        }
        
        self.mtl = mtl
        self.cgColorSpace = colorSpace
        self.isOpaque = isOpaque
    }
    
    init?(mipmapData: Data, isOpaque: Bool) {
        guard let cgImageSource = CGImageSourceCreateWithData(mipmapData as CFData, nil) else {
            return nil
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            return nil
        }
        self.init(mipmapCGImage: cgImage, isOpaque: isOpaque)
    }
    init?(mipmapImage image: Image, isOpaque: Bool) {
        self.init(mipmapCGImage: image.cg, isOpaque: isOpaque)
    }
    init?(mipmapCGImage cgImage: CGImage, isOpaque: Bool) {
        let colorSpace = Renderer.shared.imageColorSpace
        var cgImage = cgImage
        let iw = cgImage.width, ih = cgImage.height
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Renderer.shared.imagePixelFormat,
                                                          width: iw, height: ih,
                                                          mipmapped: false)
        guard let mtl = Renderer.shared.device.makeTexture(descriptor: td) else {
            return nil
        }
        
        guard let dp = cgImage.dataProvider, let data = dp.data else {
            return nil
        }
        guard let baseBytes = CFDataGetBytePtr(data) else {
            return nil
        }
        let region = MTLRegionMake2D(0, 0, iw, ih)
        mtl.replace(region: region, mipmapLevel: 0,
                    withBytes: baseBytes, bytesPerRow: cgImage.bytesPerRow)
        
        var level = 1
        var mipW = mtl.width / 2, mipH = mtl.height / 2
        while mipW >= 1 && mipH >= 1 {
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue |
                                            CGBitmapInfo.byteOrder32Little.rawValue)
            guard let ctx = CGContext(data: nil, width: mipW, height: mipH,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace.default,
                                      bitmapInfo: bitmapInfo.rawValue) else { return nil }
            guard let bytes = ctx.data else { return nil }
            ctx.interpolationQuality = .medium
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: mipW, height: mipH))
            guard let aCGImage = ctx.makeImage() else { return nil }
            cgImage = aCGImage
            
            let region = MTLRegionMake2D(0, 0, mipW, mipH)
            mtl.replace(region: region, mipmapLevel: level,
                        withBytes: bytes, bytesPerRow: cgImage.bytesPerRow)
            mipW /= 2
            mipH /= 2
            level += 1
        }
        self.mtl = mtl
        self.cgColorSpace = colorSpace
        self.isOpaque = isOpaque
    }
    
    init?(image: Image, isOpaque: Bool, colorSpace: RGBColorSpace) {
        self.init(cgImage: image.cg, isOpaque: isOpaque,
                  colorSpace: colorSpace)
    }
    init?(cgImage: CGImage, isOpaque: Bool, colorSpace: RGBColorSpace) {
        guard let cgColorSpace = colorSpace.cg else { return nil }
        let iw = cgImage.width, ih = cgImage.height
        guard iw <= Self.maxWidth && ih <= Self.maxHeight else { return nil }
        let format: MTLPixelFormat
        if colorSpace.isHDR {
            format = MTLPixelFormat.bgr10_xr_srgb
        } else {
            format = Renderer.shared.imagePixelFormat
        }
        
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format,
                                                          width: iw, height: ih,
                                                          mipmapped: false)
        guard let mtl = Renderer.shared.device.makeTexture(descriptor: td) else {
            return nil
        }
        
        guard let dp = cgImage.dataProvider, let data = dp.data else {
            return nil
        }
        guard let baseBytes = CFDataGetBytePtr(data) else {
            return nil
        }
        let region = MTLRegionMake2D(0, 0, iw, ih)
        mtl.replace(region: region, mipmapLevel: 0,
                    withBytes: baseBytes, bytesPerRow: cgImage.bytesPerRow)
        
        self.mtl = mtl
        self.cgColorSpace = cgColorSpace
        self.isOpaque = isOpaque
    }
    
    static func textureWithGPU(mipmapData: Data, isOpaque: Bool,
                               completionHandler: @escaping (Texture) -> ()) {
        guard let cgImageSource
                = CGImageSourceCreateWithData(mipmapData as CFData, nil) else { return }
        guard let cgImage
                = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else { return }
        guard let dp = cgImage.dataProvider, let data = dp.data else { return }
        guard let baseBytes = CFDataGetBytePtr(data) else { return }
        let iw = cgImage.width, ih = cgImage.height
        let colorSpace = Renderer.shared.imageColorSpace
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Renderer.shared.imagePixelFormat,
                                                          width: iw, height: ih,
                                                          mipmapped: true)
        guard let mtl
                = Renderer.shared.device.makeTexture(descriptor: td) else { return }
        
        let region = MTLRegionMake2D(0, 0, iw, ih)
        mtl.replace(region: region, mipmapLevel: 0,
                    withBytes: baseBytes, bytesPerRow: cgImage.bytesPerRow)
        
        let commandQueue = Renderer.shared.commandQueue
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeBlitCommandEncoder()
        commandEncoder?.generateMipmaps(for: mtl)
        commandEncoder?.endEncoding()
        commandBuffer?.addCompletedHandler { _ in
            completionHandler(Texture(mtl, isOpaque: isOpaque, colorSpace: colorSpace))
        }
        commandBuffer?.commit()
    }
    
    struct BytesData {
        let data: Data, width: Int, height: Int, bytesPerRow: Int
    }
    static func bytesData(with data: Data) -> BytesData? {
        guard let cgImageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            return nil
        }
        return bytesData(with: cgImage)
    }
    static func bytesData(with Image: Image) -> BytesData? {
        bytesData(with: Image.cg)
    }
    static func bytesData(with cgImage: CGImage) -> BytesData? {
        guard let dp = cgImage.dataProvider, let nData = dp.data else {
            return nil
        }
        return BytesData(data: nData as Data,
                         width: cgImage.width, height: cgImage.height,
                         bytesPerRow: cgImage.bytesPerRow)
    }
    init?(bytesData: BytesData, isOpaque: Bool) {
        let colorSpace = Renderer.shared.imageColorSpace
        let iw = bytesData.width, ih = bytesData.height
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Renderer.shared.imagePixelFormat,
                                                          width: iw, height: ih,
                                                          mipmapped: false)
        guard let mtl = Renderer.shared.device.makeTexture(descriptor: td) else {
            return nil
        }
        
        guard let baseBytes = CFDataGetBytePtr(bytesData.data as CFData) else {
            return nil
        }
        let region = MTLRegionMake2D(0, 0, iw, ih)
        mtl.replace(region: region, mipmapLevel: 0,
                    withBytes: baseBytes, bytesPerRow: bytesData.bytesPerRow)
        
        self.mtl = mtl
        self.cgColorSpace = colorSpace
        self.isOpaque = isOpaque
    }
    
    static func bc1Data(with bytes: UnsafePointer<UInt8>,
                        width: Int, height: Int) -> (data: Data, blockW: Int, blockH: Int) {
        struct RGB888 {
            let r, g, b: UInt8
            func mid(_ other: RGB888) -> RGB888 {
                return RGB888(r: (r >> 2) + (other.r >> 2),
                              g: (g >> 2) + (other.g >> 2),
                              b: (b >> 2) + (other.b >> 2))
            }
            func delta(_ rhs: RGB888) -> Int {
                let dr = abs(Int(r) - Int(rhs.r))
                let dg = abs(Int(g) - Int(rhs.g))
                let db = abs(Int(b) - Int(rhs.b))
                return dr + dg + db
            }
        }
        func rgb565(with rgb888: RGB888) -> UInt16 {
            let r = UInt16(rgb888.r & 0b11111000)
            let g = UInt16(rgb888.g & 0b11111100)
            let b = UInt16(rgb888.b)
            return (r << 8) | (g << 3) | (b >> 3)
        }
        func rgb888(atX x: Int, y: Int) -> RGB888 {
            let r = bytes[(x + y * width) * 4 + 0]
            let g = bytes[(x + y * width) * 4 + 1]
            let b = bytes[(x + y * width) * 4 + 2]
            return RGB888(r: r, g: g, b: b)
        }
        let wBlockCount = max(1, width / 4), hBlockCount = max(1, height / 4)
        var nBytes = [UInt32]()
        nBytes.reserveCapacity(wBlockCount * hBlockCount * 2)
        for yb in 0 ..< hBlockCount {
            for xb in 0 ..< wBlockCount {
                let nx = xb * 4, ny = yb * 4
                let color0 = rgb888(atX: nx, y: ny)
                let color1 = rgb888(atX: nx + 3, y: ny + 3)
                let color2 = color0.mid(color1)
                let c0 = UInt32(rgb565(with: color0))
                let c1 = UInt32(rgb565(with: color1))
                var v: UInt32 = 0, i = 0
                for y in 0 ..< 4 {
                    for x in 0 ..< 4 {
                        let color = rgb888(atX: nx + x, y: ny + y)
                        var d = (color.delta(color0), 0b00000000)
                        let d1 = (color.delta(color1), 0b00000001)
                        if d1.0 < d.0 {
                            d = d1
                        }
                        let d2 = (color.delta(color2), 0b00000010)
                        if d2.0 < d.0 {
                            d = d2
                        }
                        v |= UInt32(d.1) << i
                        i += 2
                    }
                }
                nBytes.append(c0 | (c1 << 16))
                nBytes.append(v)
            }
        }
        return (Data(nBytes.withUnsafeBytes { $0 }), wBlockCount, hBlockCount)
    }
    
    init?(_ texture: Texture, mipmapLevel: Int) {
        guard let cgImage = texture.mtl.cgImage(with: texture.cgColorSpace,
                                                mipmapLevel: mipmapLevel) else {
            return nil
        }
        guard let dp = cgImage.dataProvider, let data = dp.data else { return nil }
        guard let baseBytes = CFDataGetBytePtr(data) else { return nil }
        let iw = cgImage.width, ih = cgImage.height
        
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Renderer.shared.imagePixelFormat,
                                                          width: iw, height: ih,
                                                          mipmapped: true)
        guard let mtl
                = Renderer.shared.device.makeTexture(descriptor: td) else { return nil }
        
        let region = MTLRegionMake2D(0, 0, iw, ih)
        mtl.replace(region: region, mipmapLevel: 0,
                    withBytes: baseBytes, bytesPerRow: cgImage.bytesPerRow)
        
        self.mtl = mtl
        self.cgColorSpace = texture.cgColorSpace
        self.isOpaque = texture.isOpaque
    }
}
extension Texture {
    var size: Size {
        Size(width: mtl.width, height: mtl.height)
    }
    var isEmpty: Bool {
        size.isEmpty
    }
}
extension Texture {
    var image: Image? {
        if let cgImage = cgImage {
            return Image(cgImage: cgImage)
        } else {
            return nil
        }
    }
    func image(mipmapLevel: Int) -> Image? {
        if let cgImage = mtl.cgImage(with: cgColorSpace,
                                     mipmapLevel: mipmapLevel) {
            return Image(cgImage: cgImage)
        } else {
            return nil
        }
    }
}
extension Texture: Equatable {
    static func == (lhs: Texture, rhs: Texture) -> Bool {
        lhs.mtl === rhs.mtl
    }
}
extension MTLTexture {
    func cgImage(with colorSpace: CGColorSpace, mipmapLevel: Int = 0) -> CGImage? {
        if pixelFormat != .rgba8Unorm && pixelFormat != .rgba8Unorm_srgb
            && pixelFormat != .bgra8Unorm && pixelFormat != .bgra8Unorm_srgb {
            print("Texture: Unsupport pixel format \(pixelFormat)")
        }
        let nl = 2 ** mipmapLevel
        let nw = width / nl, nh = height / nl
        let bytesSize = nw * nh * 4
        guard let bytes = malloc(bytesSize) else {
            return nil
        }
        defer {
            free(bytes)
        }
        let bytesPerRow = nw * 4
        let region = MTLRegionMake2D(0, 0, nw, nh)
        getBytes(bytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: mipmapLevel)
        
        let bitmapInfo = pixelFormat != .bgra8Unorm && pixelFormat != .bgra8Unorm_srgb ?
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue) :
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                            | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let provider = CGDataProvider(dataInfo: nil, data: bytes, size: bytesSize,
                                            releaseData: { _, _, _ in }) else {
            return nil
        }
        return CGImage(width: nw, height: nh,
                       bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                       space: colorSpace, bitmapInfo: bitmapInfo, provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
extension CGContext {
    func renderedTexture(isOpaque: Bool) -> Texture? {
        if let cg = makeImage() {
            let mltTextureLoader = MTKTextureLoader(device: Renderer.shared.device)
            let option = MTKTextureLoader.Origin.flippedVertically
            if let mtl = try? mltTextureLoader.newTexture(cgImage: cg,
                                                          options: [.origin: option]) {
                return Texture(mtl, isOpaque: isOpaque,
                               colorSpace: Renderer.shared.colorSpace)
            }
        }
        return nil
    }
}
