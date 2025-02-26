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

protocol NodeOwner: AnyObject {
    var sampleCount: Int { get }
    func draw()
    func update()
    func viewportBounds(from: Transform, bounds: Rect) -> Rect
    var viewportBounds: Rect { get }
}
final class Node: @unchecked Sendable {
    weak var owner: (any NodeOwner)?
    private func setNeedsDisplay() {
        owner?.update()
        cacheLink?.isUpdateCache = true
    }
    func draw() {
        cacheLink?.isUpdateCache = true
        owner?.draw()
    }
    
    var name = ""
    
    private(set) weak var parent: Node?
    private var backingChildren = [Node]()
    var children: [Node] {
        get { backingChildren }
        set {
            let oldChildren = backingChildren
            oldChildren.forEach { child in
                if !newValue.contains(where: { $0 === child }) {
                    child.removeFromParent()
                }
            }
            backingChildren = newValue
            newValue.forEach { child in
                if child.parent != self {
                    child.removeFromParent()
                    child.parent = self
                    child.allChildrenAndSelf { $0.owner = owner }
                    if let cacheLink = cacheLink {
                        child.allChildrenAndSelf { $0.cacheLink = cacheLink }
                    }
                    child.updateWorldTransform(worldTransform)
                }
            }
            setNeedsDisplay()
        }
    }
    func append(child: Node) {
        guard self != child else { return }
        child.removeFromParent()
        backingChildren.append(child)
        child.parent = self
        child.allChildrenAndSelf { $0.owner = owner }
        if let cacheLink = cacheLink {
            child.allChildrenAndSelf { $0.cacheLink = cacheLink }
        }
        child.updateWorldTransform(worldTransform)
        child.setNeedsDisplay()
    }
    func insert(child: Node, at index: Array<Node>.Index) {
        guard self != child else { return }
        var index = index
        if child.parent != nil {
            if let oldIndex = children.firstIndex(of: child), index > oldIndex {
                index -= 1
            }
            child.removeFromParent()
        }
        backingChildren.insert(child, at: index)
        child.parent = self
        child.allChildrenAndSelf { $0.owner = owner }
        if let cacheLink = cacheLink {
            child.allChildrenAndSelf { $0.cacheLink = cacheLink }
        }
        child.updateWorldTransform(worldTransform)
        child.setNeedsDisplay()
    }
    func remove(atChild i: Array<Node>.Index) {
        children[i].removeFromParent()
    }
    func removeFromParent() {
        guard let parent = parent else { return }
        if let index = parent.backingChildren.firstIndex(where: { $0 === self }) {
            parent.backingChildren.remove(at: index)
        }
        self.parent = nil
        updateWorldTransform(.identity)
        setNeedsDisplay()
        allChildrenAndSelf { $0.owner = nil }
        if parent.cacheLink != nil {
            allChildrenAndSelf { $0.cacheLink = nil }
        }
        
        resetBuffers()
        allChildrenAndSelf { $0.resetBuffers() }
    }
    
    var isHidden = false {
        didSet {
            guard isHidden != oldValue else { return }
            setNeedsDisplay()
        }
    }
    
    var attitude = Attitude() {
        didSet {
            localTransform = attitude.transform
            isIdentityFromLocal = localTransform.isIdentity
            localScale = isIdentityFromLocal ? 1 : localTransform.absXScale
            updateWorldTransform(parent?.worldTransform ?? .identity)
            setNeedsDisplay()
        }
    }
    private(set) var localTransform = Transform.identity
    private(set) var isIdentityFromLocal = true, localScale = 1.0
    private(set) var worldTransform = Transform.identity
    private func updateWorldTransform(_ parentTransform: Transform) {
        if !isIdentityFromLocal {
            worldTransform = localTransform * parentTransform
            children.forEach { $0.updateWorldTransform(worldTransform) }
        } else {
            worldTransform = parentTransform
            children.forEach { $0.updateWorldTransform(parentTransform) }
        }
    }
    
    private enum UpdateType {
        case none, wait, update
    }
    
    private var aPath = Path()
    var path: Path {
        get { aPath }
        set {
            aPath = newValue
            
            if lineWidth > 0 {
                if lineType != nil {
                    linePathDataUpdateType = .update
                    if lineColorBufferUpdateType == .wait {
                        lineColorBufferUpdateType = .update
                    }
                    setNeedsDisplay()
                } else if path.isEmpty {
                    linePathDataUpdateType = .update
                    setNeedsDisplay()
                } else {
                    linePathDataUpdateType = .wait
                }
            }
            if fillType != nil {
                fillPathDataUpdateType = .update
                if fillColorBufferUpdateType == .wait {
                    fillColorBufferUpdateType = .update
                }
                setNeedsDisplay()
            } else if path.isEmpty {
                fillPathDataUpdateType = .update
                setNeedsDisplay()
            } else {
                fillPathDataUpdateType = .wait
            }
        }
    }
    var lineWidth = 1.0 {
        didSet {
            guard lineWidth != oldValue else { return }
            if !path.isEmpty {
                if lineType != nil {
                    linePathDataUpdateType = .update
                    if lineColorBufferUpdateType == .wait {
                        lineColorBufferUpdateType = .update
                    }
                    setNeedsDisplay()
                } else if lineWidth == 0 {
                    linePathDataUpdateType = .update
                    setNeedsDisplay()
                } else {
                    linePathDataUpdateType = .wait
                }
            }
        }
    }
    private var linePathDataUpdateType = UpdateType.none
    private var linePathData = [Float]()
    private var linePathBufferVertexCounts = [Int]()
    private var linePathBufferUpdateType = UpdateType.none
    private var linePathBuffer: Buffer?
    func update(path: Path,
                withLinePathData linePathData: [Float],
                bufferVertexCounts: [Int]) {
        aPath = path
        
        if lineWidth > 0 {
            if lineType != nil {
                self.linePathData = linePathData
                linePathBufferVertexCounts = bufferVertexCounts
                updateLinePathBuffer()
                
                linePathDataUpdateType = .none
                linePathBufferUpdateType = .none
                
                if lineColorBufferUpdateType == .wait {
                    lineColorBufferUpdateType = .update
                }
                setNeedsDisplay()
            } else if path.isEmpty {
                self.linePathData = []
                linePathBufferVertexCounts = []
                updateLinePathBuffer()
                
                linePathDataUpdateType = .none
                linePathBufferUpdateType = .none
                setNeedsDisplay()
            } else {
                linePathDataUpdateType = .wait
            }
        }
    }
    private func updateLinePathData() {
        if !path.isEmpty {
            (linePathData, linePathBufferVertexCounts) = path.linePointsDataWith(lineWidth: lineWidth)
        } else {
            linePathData = []
            linePathBufferVertexCounts = []
        }
    }
    private func updateLinePathBuffer() {
        if !linePathData.isEmpty {
            linePathBuffer = Renderer.shared.device.makeBuffer(linePathData)
        } else {
            linePathBuffer = nil
        }
    }
    private var fillPathDataUpdateType = UpdateType.none
    private var fillPathData = [Float]()
    private var fillPathBufferVertexCounts = [Int]()
    private var fillPathBufferBezierVertexCounts = [Int]()
    private var fillPathBufferAroundVertexCounts = [Int]()
    private var fillPathBufferUpdateType = UpdateType.none
    private var fillPathBuffer: Buffer?
    private func updateFillPathData() {
        if !path.isEmpty {
            if path.isPolygon {
                (fillPathData,
                 fillPathBufferVertexCounts) = path.fillPointsData()
            } else {
                (fillPathData,
                 fillPathBufferVertexCounts,
                 fillPathBufferBezierVertexCounts,
                 fillPathBufferAroundVertexCounts)
                    = path.stencilFillData()
            }
        } else {
            fillPathData = []
            fillPathBufferVertexCounts = []
            fillPathBufferBezierVertexCounts = []
            fillPathBufferAroundVertexCounts = []
        }
    }
    private func updateFillPathBuffer() {
        if !fillPathData.isEmpty {
            fillPathBuffer = Renderer.shared.device.makeBuffer(fillPathData)
        } else {
            fillPathBuffer = nil
        }
    }
    
    enum LineType: Equatable {
        case color(Color)
        case gradient([Color])
    }
    var lineType: LineType? {
        didSet {
            if !path.isEmpty && lineWidth > 0 {
                lineColorBufferUpdateType = .update
                if linePathDataUpdateType == .wait {
                    linePathDataUpdateType = .update
                }
                setNeedsDisplay()
            } else if lineType == nil {
                lineColorBufferUpdateType = .update
                setNeedsDisplay()
            } else {
                lineColorBufferUpdateType = .wait
            }
        }
    }
    private var lineColorBufferUpdateType = UpdateType.none
    private var lineColorBuffer: Buffer?
    private var lineColorsBuffer: Buffer?
    private var isLineOpaque = false
    private func updateLineColorBuffer() {
        if let lineType = lineType {
            switch lineType {
            case .color(let color):
                lineColorBuffer = Renderer.shared.colorBuffer(with: color)
                lineColorsBuffer = nil
                isLineOpaque = color.opacity == 1
            case .gradient(let colors):
                let colorsData = path.lineColorsDataWith(colors,
                                                         lineWidth: lineWidth)
                lineColorBuffer = nil
                lineColorsBuffer = Renderer.shared.device.makeBuffer(colorsData)
                isLineOpaque = false
            }
        } else {
            lineColorBuffer = nil
            lineColorsBuffer = nil
            isLineOpaque = false
        }
    }
    
    enum FillType: Equatable {
        case color(Color)
        case gradient([Color])
        case maxGradient([Color])
        case texture(Texture)
    }
    var fillType: FillType? {
        didSet {
            if !path.isEmpty {
                fillColorBufferUpdateType = .update
                if fillPathDataUpdateType == .wait {
                    fillPathDataUpdateType = .update
                }
                setNeedsDisplay()
            } else if fillType == nil {
                fillColorBufferUpdateType = .update
                setNeedsDisplay()
            } else {
                fillColorBufferUpdateType = .wait
            }
        }
    }
    private var fillColorBufferUpdateType = UpdateType.none
    private var fillColorBuffer: Buffer?
    private var fillColorsBuffer: Buffer?
    private var fillTextureBuffer: Buffer?
    private var fillTexture: Texture?
    private var isFillOpaque = false
    private var isMaxBlend = false
    private func updateFillColorBuffer() {
        if let fillType = fillType {
            switch fillType {
            case .color(let color):
                fillColorBuffer = Renderer.shared.colorBuffer(with: color)
                fillColorsBuffer = nil
                fillTextureBuffer = nil
                fillTexture = nil
                isFillOpaque = color.opacity == 1
                isMaxBlend = false
            case .gradient(let colors):
                let colorsData = path.fillColorsDataWith(colors)
                fillColorBuffer = nil
                fillColorsBuffer = Renderer.shared.device.makeBuffer(colorsData)
                fillTextureBuffer = nil
                isFillOpaque = false
                isMaxBlend = false
            case .maxGradient(let colors):
                let colorsData = path.fillColorsDataWith(colors)
                fillColorBuffer = nil
                fillColorsBuffer = Renderer.shared.device.makeBuffer(colorsData)
                fillTextureBuffer = nil
                isFillOpaque = false
                isMaxBlend = true
            case .texture(let texture):
                fillColorBuffer = nil
                fillColorsBuffer = nil
                
                let device = Renderer.shared.device
                let pointsData = path.fillTexturePointsData()
                guard !pointsData.isEmpty else {
                    fillTextureBuffer = nil
                    fillTexture = nil
                    return
                }
                fillTextureBuffer = device.makeBuffer(pointsData)
                
                fillTexture = texture
                isFillOpaque = texture.isOpaque
                isMaxBlend = false
            }
        } else {
            fillColorBuffer = nil
            fillColorBuffer = nil
            fillTextureBuffer = nil
            fillTexture = nil
            isFillOpaque = false
            isMaxBlend = false
        }
    }
    
    var isClippingChildren = false
    
    var isCPUFillAntialias = true
    
    var enableCache = false {
        didSet {
            guard enableCache != oldValue else { return }
            if enableCache {
                allChildrenAndSelf { $0.cacheLink = self }
            } else {
                allChildrenAndSelf { $0.cacheLink = nil }
            }
        }
    }
    var cacheTexture: Texture? {
        didSet {
            updateWithCacheTexture()
        }
    }
    var isRenderCache = true
    private var cachePathBuffer: Buffer?
    private var cachePathBufferVertexCounts = [Int]()
    private var cacheTextureBuffer: Buffer?
    private weak var cacheLink: Node?
    private(set) var isUpdateCache = false
    func updateCache() {
        if isRenderCache && enableCache {
            if isUpdateCache || cacheTexture == nil {
                newCache()
                isUpdateCache = false
            }
        }
    }
    private func newCache() {
        guard enableCache else { return }
        guard let bounds = bounds else {
            cacheTexture = nil
            return
        }
        let color: Color
        if case .color(let aColor)? = fillType {
            color = aColor
        } else {
            color = .background
        }
        isRenderCache = false
        let texture = renderedTexture(in: bounds, to: bounds.size * 2,
                                      backgroundColor: color,
                                      sampleCount: owner?.sampleCount ?? 1,
                                      mipmapped: true)
        isRenderCache = true
        cacheTexture = texture
    }
    private func updateWithCacheTexture() {
        if cacheTexture != nil && !path.isEmpty && path.isPolygon {
            let (pointsData, counts) = path.fillPointsData()
            if !pointsData.isEmpty {
                let texturePointsData = path.fillTexturePointsData()
                if !texturePointsData.isEmpty {
                    let device = Renderer.shared.device
                    cachePathBuffer = device.makeBuffer(pointsData)
                    cachePathBufferVertexCounts = counts
                    cacheTextureBuffer = device.makeBuffer(texturePointsData)
                    return
                }
            }
        }
        cachePathBuffer = nil
        cachePathBufferVertexCounts = []
        cacheTextureBuffer = nil
    }
    
    init(name: String = "",
         children: [Node] = [],
         isHidden: Bool = false, isClippingChildren: Bool = false,
         attitude: Attitude = Attitude(),
         path: Path = Path(),
         lineWidth: Double = 0, lineType: LineType? = nil,
         fillType: FillType? = nil) {
        
        self.name = name
        backingChildren = children
        self.isHidden = isHidden
        self.isClippingChildren = isClippingChildren
        self.aPath = path
        self.attitude = attitude
        self.localTransform = attitude.transform
        self.isIdentityFromLocal = localTransform.isIdentity
        self.localScale = isIdentityFromLocal ? 1 : localTransform.absXScale
        worldTransform = localTransform
        self.lineWidth = lineWidth
        self.lineType = lineType
        self.fillType = fillType
        
        children.forEach {
            $0.removeFromParent()
            $0.parent = self
            $0.updateWorldTransform(worldTransform)
        }
        
        let isLinePath = lineWidth > 0 && !path.isEmpty
        let isLineColor = lineType != nil
        linePathDataUpdateType = isLinePath ?
            (isLineColor ? .update : .wait) : .none
        lineColorBufferUpdateType = isLineColor ?
            (isLinePath ? .update : .wait) : .none
        let isFillColor = fillType != nil
        let isFillPath = !path.isEmpty
        fillPathDataUpdateType = isFillPath ?
            (isFillColor ? .update : .wait) : .none
        fillColorBufferUpdateType = isFillColor ?
            (isFillPath ? .update : .wait) : .none
    }
    
    private init(name: String, backingChildren: [Node],
                 isHidden: Bool, isClippingChildren: Bool, attitude: Attitude,
                 localTransform: Transform, isIdentityFromLocal: Bool, localScale: Double,
                 worldTransform: Transform, path: Path,
                 lineWidth : Double,
                 linePathDataUpdateType: UpdateType,
                 linePathData: [Float], linePathBufferVertexCounts: [Int],
                 linePathBufferUpdateType: UpdateType, linePathBuffer: Buffer?,
                 fillPathDataUpdateType: UpdateType, fillPathData: [Float],
                 fillPathBufferVertexCounts: [Int], fillPathBufferBezierVertexCounts: [Int],
                 fillPathBufferAroundVertexCounts: [Int], fillPathBufferUpdateType: UpdateType,
                 fillPathBuffer: Buffer?, lineType: LineType?, lineColorBufferUpdateType: UpdateType,
                 lineColorBuffer: Buffer?, lineColorsBuffer: Buffer?, isLineOpaque: Bool,
                 fillType: FillType?, fillColorBufferUpdateType: UpdateType,
                 fillColorBuffer: Buffer?, fillColorsBuffer: Buffer?,
                 fillTextureBuffer: Buffer?, fillTexture: Texture?,
                 isFillOpaque: Bool, isMaxBlend: Bool) {
        
        self.name = name
        self.backingChildren = backingChildren
        self.isHidden = isHidden
        self.isClippingChildren = isClippingChildren
        self.attitude = attitude
        self.localTransform = localTransform
        self.isIdentityFromLocal = isIdentityFromLocal
        self.localScale = localScale
        self.worldTransform = worldTransform
        self.aPath = path
        self.lineWidth = lineWidth
        self.linePathDataUpdateType = linePathDataUpdateType
        self.linePathData = linePathData
        self.linePathBufferVertexCounts = linePathBufferVertexCounts
        self.linePathBufferUpdateType = linePathBufferUpdateType
        self.linePathBuffer = linePathBuffer
        self.fillPathDataUpdateType = fillPathDataUpdateType
        self.fillPathData = fillPathData
        self.fillPathBufferVertexCounts = fillPathBufferVertexCounts
        self.fillPathBufferBezierVertexCounts = fillPathBufferBezierVertexCounts
        self.fillPathBufferAroundVertexCounts = fillPathBufferAroundVertexCounts
        self.fillPathBufferUpdateType = fillPathBufferUpdateType
        self.fillPathBuffer = fillPathBuffer
        self.lineType = lineType
        self.lineColorBufferUpdateType = lineColorBufferUpdateType
        self.lineColorBuffer = lineColorBuffer
        self.lineColorsBuffer = lineColorsBuffer
        self.isLineOpaque = isLineOpaque
        self.fillType = fillType
        self.fillColorBufferUpdateType = fillColorBufferUpdateType
        self.fillColorBuffer = fillColorBuffer
        self.fillColorsBuffer = fillColorsBuffer
        self.fillTextureBuffer = fillTextureBuffer
        self.fillTexture = fillTexture
        self.isFillOpaque = isFillOpaque
        self.isMaxBlend = isMaxBlend
        
        children.forEach {
            $0.removeFromParent()
            $0.parent = self
            $0.updateWorldTransform(worldTransform)
        }
    }
    var clone: Node {
        Node(name: name,
             backingChildren: backingChildren.map { $0.clone },
             isHidden: isHidden,
             isClippingChildren: isClippingChildren,
             attitude: attitude,
             localTransform: localTransform,
             isIdentityFromLocal: isIdentityFromLocal,
             localScale: localScale,
             worldTransform: worldTransform,
             path: path,
             lineWidth: lineWidth,
             linePathDataUpdateType: linePathDataUpdateType,
             linePathData: linePathData,
             linePathBufferVertexCounts: linePathBufferVertexCounts,
             linePathBufferUpdateType: linePathBufferUpdateType,
             linePathBuffer: linePathBuffer,
             fillPathDataUpdateType: fillPathDataUpdateType,
             fillPathData: fillPathData,
             fillPathBufferVertexCounts: fillPathBufferVertexCounts,
             fillPathBufferBezierVertexCounts: fillPathBufferBezierVertexCounts,
             fillPathBufferAroundVertexCounts: fillPathBufferAroundVertexCounts,
             fillPathBufferUpdateType: fillPathBufferUpdateType,
             fillPathBuffer: fillPathBuffer,
             lineType: lineType,
             lineColorBufferUpdateType: lineColorBufferUpdateType,
             lineColorBuffer: lineColorBuffer,
             lineColorsBuffer: lineColorsBuffer,
             isLineOpaque: isLineOpaque,
             fillType: fillType,
             fillColorBufferUpdateType: fillColorBufferUpdateType,
             fillColorBuffer: fillColorBuffer, fillColorsBuffer: fillColorsBuffer,
             fillTextureBuffer: fillTextureBuffer,
             fillTexture: fillTexture,
             isFillOpaque: isFillOpaque, isMaxBlend: isMaxBlend)
    }
}
extension Node {
    func updateDatas() {
        if linePathDataUpdateType == .update {
            updateLinePathData()
            linePathDataUpdateType = .none
            linePathBufferUpdateType = .update
        }
        if linePathBufferUpdateType == .update {
            updateLinePathBuffer()
            linePathBufferUpdateType = .none
        }
        if fillPathDataUpdateType == .update {
            updateFillPathData()
            fillPathDataUpdateType = .none
            fillPathBufferUpdateType = .update
        }
        if fillPathBufferUpdateType == .update {
            updateFillPathBuffer()
            fillPathBufferUpdateType = .none
        }
        if lineColorBufferUpdateType == .update {
            updateLineColorBuffer()
            lineColorBufferUpdateType = .none
        }
        if fillColorBufferUpdateType == .update {
            updateFillColorBuffer()
            fillColorBufferUpdateType = .none
        }
    }
    func resetBuffers() {
        if linePathBuffer != nil {
            linePathBuffer = nil
            linePathBufferUpdateType = .update
        }
        if fillPathBuffer != nil {
            fillPathBuffer = nil
            fillPathBufferUpdateType = .update
        }
        if lineColorBuffer != nil || lineColorsBuffer != nil {
            lineColorBuffer = nil
            lineColorsBuffer = nil
            lineColorBufferUpdateType = .update
        }
        if fillColorBuffer != nil || fillColorsBuffer != nil
            || fillTextureBuffer != nil || fillTexture != nil {
            fillColorBuffer = nil
            fillColorsBuffer = nil
            fillTextureBuffer = nil
            fillTexture = nil
            fillColorBufferUpdateType = .update
        }
    }
    
    func draw(with t: Transform, scale: Double, in ctx: Context) {
        draw(currentTransform: t,
             currentTransformBytes: nil,
             currentScale: scale,
             rootTransform: t,
             in: ctx)
    }
    func draw(with t: Transform, in ctx: Context) {
        draw(currentTransform: t,
             currentTransformBytes: nil,
             currentScale: t.absXScale,
             rootTransform: t,
             in: ctx)
    }
    fileprivate func draw(currentTransform: Transform,
                          currentTransformBytes: [Float]?,
                          currentScale: Double,
                          rootTransform: Transform,
                          in ctx: Context) {
        guard !isHidden else { return }
        
        let transform: Transform, nTransformBytes: [Float]?, tScale: Double
        if isIdentityFromLocal {
            transform = currentTransform
            nTransformBytes = currentTransformBytes
            tScale = currentScale
        } else {
            transform = worldTransform * rootTransform
            nTransformBytes = nil
            tScale = currentScale * localScale
        }
        
        guard let bounds = drawableBounds else {
            children.forEach { $0.draw(currentTransform: transform,
                                       currentTransformBytes: nTransformBytes,
                                       currentScale: tScale,
                                       rootTransform: rootTransform,
                                       in: ctx) }
            return
        }
        guard (bounds * transform)
                .intersects(Rect(x: -1, y: -1,
                                 width: 2, height: 2))
                || path.typesetter != nil else { return }
        
        let transformBytes = nTransformBytes ?? transform.floatData4x4
        let floatSize = MemoryLayout<Float>.stride
        let transformLength = transformBytes.count * floatSize
        
        updateDatas()
        
        if isRenderCache && enableCache && tScale < 1 {
            if isUpdateCache || cacheTexture == nil {
                newCache()
                isUpdateCache = false
            }
            if let cacheTexture = cacheTexture,
               let cacheTextureBuffer = cacheTextureBuffer {
                
                let (pointsBytes, counts) = Path(bounds).fillPointsData()
                ctx.setOpaqueTexturePipeline()
                ctx.setVertex(bytes: pointsBytes,
                              length: pointsBytes.count * floatSize,
                              at: 0)
                ctx.setVertex(cacheTextureBuffer, at: 1)
                ctx.setVertex(bytes: transformBytes,
                              length: transformLength, at: 2)
                ctx.setVertexCacheSampler(at: 3)
                ctx.setFragment(cacheTexture, at: 0)
                ctx.drawTriangleStrip(with: counts)
            }
            return
        }
        
        if !isClippingChildren, let fillPathBuffer = fillPathBuffer {
            if path.isPolygon {
                if let fillColorBuffer = fillColorBuffer {
                    if isFillOpaque {
                        ctx.setOpaqueColorPipeline()
                    } else {
                        ctx.setAlphaColorPipeline()
                    }
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(fillColorBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.drawTriangleStrip(with: fillPathBufferVertexCounts)
                } else if let fillColorsBuffer {
                    if isMaxBlend {
                        ctx.setMaxColorsPipeline()
                    } else {
                        ctx.setColorsPipeline()
                    }
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(fillColorsBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.drawTriangleStrip(with: fillPathBufferVertexCounts)
                } else if let texture = fillTexture,
                          let textureBuffer = fillTextureBuffer {
                    if isFillOpaque {
                        ctx.setOpaqueTexturePipeline()
                    } else {
                        ctx.setAlphaTexturePipeline()
                    }
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(textureBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.setFragment(texture, at: 0)
                    ctx.drawTriangleStrip(with: fillPathBufferVertexCounts)
                }
            } else {
                ctx.setStencilPipeline()
                ctx.setInvertDepthStencil()
                ctx.setVertex(fillPathBuffer, at: 0)
                ctx.setVertex(bytes: transformBytes,
                              length: transformLength, at: 1)
                var i = ctx.drawTriangle(with: fillPathBufferVertexCounts)
                
                ctx.setStencilBezierPipeline()
                ctx.setVertex(fillPathBuffer, at: 0)
                ctx.setVertex(bytes: transformBytes,
                              length: transformLength, at: 1)
                i = ctx.drawTriangle(start: i,
                                     with: fillPathBufferBezierVertexCounts)
                
                if let fillColorBuffer = fillColorBuffer {
                    if isFillOpaque {
                        ctx.setOpaqueColorPipeline()
                    } else {
                        ctx.setAlphaColorPipeline()
                    }
                    ctx.setClippingDepthStencil()
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(fillColorBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.drawTriangleStrip(start: i,
                                          with: fillPathBufferAroundVertexCounts)
                } else if let texture = fillTexture,
                          let textureBuffer = fillTextureBuffer {
                    if isFillOpaque {
                        ctx.setOpaqueTexturePipeline()
                    } else {
                        ctx.setAlphaTexturePipeline()
                    }
                    ctx.setClippingDepthStencil()
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(textureBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.setFragment(texture, at: 0)
                    ctx.drawTriangleStrip(start: i,
                                          with: fillPathBufferAroundVertexCounts)
                }
                
                ctx.setNormalDepthStencil()
            }
        }
        
        if isRenderCache && enableCache, let owner = owner {
            ctx.clip(owner.viewportBounds(from: transform, bounds: bounds))
        }
        
        if let lineType = lineType, let linePathBuffer = linePathBuffer {
            switch lineType {
            case .color:
                if let lineColorBuffer = lineColorBuffer {
                    if isLineOpaque {
                        ctx.setOpaqueColorPipeline()
                    } else {
                        ctx.setAlphaColorPipeline()
                    }
                    ctx.setVertex(linePathBuffer, at: 0)
                    ctx.setVertex(lineColorBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.drawTriangleStrip(with: linePathBufferVertexCounts)
                }
            case .gradient:
                if let lineColorsBuffer = lineColorsBuffer {
                    ctx.setColorsPipeline()
                    ctx.setVertex(linePathBuffer, at: 0)
                    ctx.setVertex(lineColorsBuffer, at: 1)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 2)
                    ctx.drawTriangleStrip(with: linePathBufferVertexCounts)
                }
            }
        }
        
        if isClippingChildren {
            ctx.setStencilPipeline()
            ctx.setReplaceDepthStencil()
            ctx.setStencilReferenceValue(0)
            if let fillPathBuffer = fillPathBuffer {
                if path.isPolygon {
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 1)
                    ctx.drawTriangleStrip(with: fillPathBufferVertexCounts)
                }
            }
            ctx.setReplaceDepthStencil()
            ctx.setStencilReferenceValue(1)
            children.forEach {
                $0.updateDatas()
                if let lineType = $0.lineType, let linePathBuffer = $0.linePathBuffer {
                    switch lineType {
                    case .color:
                       ctx.setVertex(linePathBuffer, at: 0)
                       ctx.setVertex(bytes: transformBytes,
                                      length: transformLength, at: 1)
                       ctx.drawTriangleStrip(with: $0.linePathBufferVertexCounts)
                    case .gradient: break
                    }
                }
            }
            if let fillPathBuffer = fillPathBuffer {
                if path.isPolygon {
                    if let fillColorBuffer = fillColorBuffer {
                        if isFillOpaque {
                            ctx.setOpaqueColorPipeline()
                        } else {
                            ctx.setAlphaColorPipeline()
                        }
                        ctx.setReversedClippingDepthStencil()
                        ctx.setVertex(fillPathBuffer, at: 0)
                        ctx.setVertex(fillColorBuffer, at: 1)
                        ctx.setVertex(bytes: transformBytes,
                                      length: transformLength, at: 2)
                        ctx.drawTriangleStrip(with: fillPathBufferVertexCounts)
                    }
                }
            }
            ctx.setStencilPipeline()
            ctx.setReplaceDepthStencil()
            ctx.setStencilReferenceValue(0)
            if let fillPathBuffer = fillPathBuffer {
                if path.isPolygon {
                    ctx.setVertex(fillPathBuffer, at: 0)
                    ctx.setVertex(bytes: transformBytes,
                                  length: transformLength, at: 1)
                    ctx.drawTriangleStrip(with: fillPathBufferVertexCounts)
                }
            }
            ctx.setNormalDepthStencil()
        } else {
            children.forEach { $0.draw(currentTransform: transform,
                                       currentTransformBytes: transformBytes,
                                       currentScale: tScale,
                                       rootTransform: rootTransform,
                                       in: ctx) }
        }
        
        if isRenderCache && enableCache, let owner = owner {
            ctx.clip(owner.viewportBounds)
        }
    }
}

extension Node {
    func allChildrenAndSelf(_ closure: (Node) throws -> ()) rethrows {
        func allChildrenRecursion(_ child: Node, _ closure: (Node) throws -> Void) rethrows {
            try child.backingChildren.forEach { try allChildrenRecursion($0, closure) }
            try closure(child)
        }
        try allChildrenRecursion(self, closure)
    }
    func allChildren(_ closure: (Node) -> ()) {
        func allChildrenRecursion(_ child: Node, _ closure: (Node) -> Void) {
            child.backingChildren.forEach { allChildrenRecursion($0, closure) }
            closure(child)
        }
        allChildrenRecursion(self, closure)
    }
    func allChildren(_ closure: (Node, inout Bool) -> ()) {
        var stop = false
        func allChildrenRecursion(_ child: Node,
                                  _ closure: (Node, inout Bool) -> Void) {
            for nChild in child.backingChildren {
                allChildrenRecursion(nChild, closure)
                guard !stop else { return }
            }
            closure(child, &stop)
            guard !stop else { return }
        }
        allChildrenRecursion(self, closure)
    }
    func allParents(closure: (Node, inout Bool) -> ()) {
        guard let parent = parent else { return }
        var stop = false
        closure(parent, &stop)
        guard !stop else { return }
        parent.allParents(closure: closure)
    }
    func selfAndAllParents(closure: (Node, inout Bool) -> ()) {
        var stop = false
        closure(self, &stop)
        guard !stop else { return }
        parent?.selfAndAllParents(closure: closure)
    }
    var root: Node {
        parent?.root ?? self
    }
    
    var isEmpty: Bool {
        path.isEmpty
    }
    var bounds: Rect? {
        path.bounds
    }
    var transformedBounds: Rect? {
        if let bounds = bounds {
            return bounds * localTransform
        } else {
            return nil
        }
    }
    var drawableBounds: Rect? {
        lineWidth > 0 && lineType != nil ?
            path.bounds?.inset(by: -lineWidth) : path.bounds
    }
    
    func contains(_ p: Point) -> Bool {
        !isHidden && containsPath(p)
    }
    func containsPath(_ p: Point) -> Bool {
        if fillType != nil && path.contains(p) {
            return true
        }
        if lineType != nil && path.containsLine(p, lineWidth: lineWidth) {
            return true
        }
        return false
    }
    func containsFromAllParents(_ parent: Node) -> Bool {
        var isParent = false
        allParents { (node, stop) in
            if node == parent {
                isParent = true
                stop = true
            }
        }
        return isParent
    }
    
    func at(_ p: Point) -> Node? {
        guard (isEmpty || containsPath(p)) && !isHidden else {
            return nil
        }
        for child in backingChildren.reversed() {
            let inPoint = p * child.localTransform.inverted()
            if let hitChild = child.at(inPoint) {
                return hitChild
            }
        }
        return isEmpty ? nil : self
    }
    
    func convert<T: AppliableTransform>(_ value: T,
                                        from node: Node) -> T {
        guard self != node else {
            return value
        }
        if containsFromAllParents(node) {
            return convert(value, fromParent: node)
        } else if node.containsFromAllParents(self) {
            return node.convert(value, toParent: self)
        } else {
            let rootValue = node.convertToWorld(value)
            return convertFromWorld(rootValue)
        }
    }
    private func convert<T: AppliableTransform>(_ value: T,
                                                fromParent: Node) -> T {
        var transform = Transform.identity
        selfAndAllParents { (node, stop) in
            if node == fromParent {
                stop = true
            } else {
                transform *= node.localTransform
            }
        }
        return value * transform.inverted()
    }
    func convertFromWorld<T: AppliableTransform>(_ value: T) -> T {
        var transform = Transform.identity
        selfAndAllParents { (node, _) in
            if node.parent != nil {
                transform *= node.localTransform
            }
        }
        return value * transform.inverted()
    }
    
    func convert<T: AppliableTransform>(_ value: T,
                                        to node: Node) -> T {
        guard self != node else {
            return value
        }
        if containsFromAllParents(node) {
            return convert(value, toParent: node)
        } else if node.containsFromAllParents(self) {
            return node.convert(value, fromParent: self)
        } else {
            let rootValue = convertToWorld(value)
            return node.convertFromWorld(rootValue)
        }
    }
    private func convert<T: AppliableTransform>(_ value: T,
                                                toParent: Node) -> T {
        guard let parent = parent else {
            return value
        }
        if parent == toParent {
            return value * localTransform
        } else {
            return parent.convert(value * localTransform,
                                  toParent: toParent)
        }
    }
    func convertToWorld<T: AppliableTransform>(_ value: T) -> T {
        parent?.convertToWorld(value * localTransform) ?? value
    }
}
extension Node: Equatable {
    static func == (lhs: Node, rhs: Node) -> Bool {
        lhs === rhs
    }
}
extension Node: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
