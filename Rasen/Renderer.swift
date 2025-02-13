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

//#if os(macOS) && os(iOS) && os(watchOS) && os(tvOS) && os(visionOS)
import MetalKit
import MetalPerformanceShaders
import Accelerate.vImage
import UniformTypeIdentifiers
//#elseif os(linux) && os(windows)
//#endif

final class Renderer {
    let device: any MTLDevice
    let library: any MTLLibrary
    let commandQueue: any MTLCommandQueue
    let colorSpace = ColorSpace.default.cg!
    let pixelFormat = MTLPixelFormat.bgra8Unorm
    let imageColorSpace = ColorSpace.export.cg!
    let imagePixelFormat = MTLPixelFormat.rgba8Unorm
    let hdrColorSpace = CGColorSpace.sRGBHDRColorSpace!
    let hdrPixelFormat = MTLPixelFormat.rgba16Float
    var defaultColorBuffers: [RGBA: Buffer]
    
    nonisolated(unsafe) static let shared = try! Renderer()
    
    static var metalError: any Error {
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
            let rgba = color.with(ColorSpace.default).rgba.premultipliedAlpha
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
        let rgba = color.with(ColorSpace.default).rgba.premultipliedAlpha
        if defaultColorBuffers[rgba] == nil {
            defaultColorBuffers[rgba] = device.makeBuffer(rgba)
        }
    }
    func colorBuffer(with color: Color) -> Buffer? {
        let rgba = color.with(ColorSpace.default).rgba.premultipliedAlpha
        if let buffer = defaultColorBuffers[rgba] {
            return buffer
        }
        return device.makeBuffer(rgba)
    }
}

final class Renderstate {
    let sampleCount: Int
    let opaqueColorRenderPipelineState: any MTLRenderPipelineState
    let alphaColorRenderPipelineState: any MTLRenderPipelineState
    let colorsRenderPipelineState: any MTLRenderPipelineState
    let maxColorsRenderPipelineState: any MTLRenderPipelineState
    let opaqueTextureRenderPipelineState: any MTLRenderPipelineState
    let alphaTextureRenderPipelineState: any MTLRenderPipelineState
    let stencilRenderPipelineState: any MTLRenderPipelineState
    let stencilBezierRenderPipelineState: any MTLRenderPipelineState
    let invertDepthStencilState: any MTLDepthStencilState
    let zeroDepthStencilState: any MTLDepthStencilState
    let replaceDepthStencilState: any MTLDepthStencilState
    let normalDepthStencilState: any MTLDepthStencilState
    let clippingDepthStencilState: any MTLDepthStencilState
    let reversedClippingDepthStencilState: any MTLDepthStencilState
    let cacheSamplerState: any MTLSamplerState
    
    nonisolated(unsafe) static let sampleCount1 = try? Renderstate(sampleCount: 1)
    nonisolated(unsafe) static let sampleCount4 = try? Renderstate(sampleCount: 4)
    nonisolated(unsafe) static let sampleCount8 = try? Renderstate(sampleCount: 8)
    
    init(sampleCount: Int) throws {
        let device = Renderer.shared.device
        let library = Renderer.shared.library
        let pixelFormat = Renderer.shared.pixelFormat
        
        self.sampleCount = sampleCount
        
        let opaqueColorD = MTLRenderPipelineDescriptor()
        opaqueColorD.vertexFunction = library.makeFunction(name: "basicVertex")
        opaqueColorD.vertexBuffers[0].mutability = .immutable
        opaqueColorD.vertexBuffers[1].mutability = .immutable
        opaqueColorD.vertexBuffers[2].mutability = .immutable
        opaqueColorD.fragmentFunction = library.makeFunction(name: "basicFragment")
        opaqueColorD.colorAttachments[0].pixelFormat = pixelFormat
        opaqueColorD.stencilAttachmentPixelFormat = .stencil8
        opaqueColorD.rasterSampleCount = sampleCount
        opaqueColorRenderPipelineState = try device.makeRenderPipelineState(descriptor: opaqueColorD)
        
        let alphaColorD = MTLRenderPipelineDescriptor()
        alphaColorD.vertexFunction = library.makeFunction(name: "basicVertex")
        alphaColorD.vertexBuffers[0].mutability = .immutable
        alphaColorD.vertexBuffers[1].mutability = .immutable
        alphaColorD.vertexBuffers[2].mutability = .immutable
        alphaColorD.fragmentFunction = library.makeFunction(name: "basicFragment")
        alphaColorD.colorAttachments[0].isBlendingEnabled = true
        alphaColorD.colorAttachments[0].rgbBlendOperation = .add
        alphaColorD.colorAttachments[0].alphaBlendOperation = .add
        alphaColorD.colorAttachments[0].sourceRGBBlendFactor = .one
        alphaColorD.colorAttachments[0].sourceAlphaBlendFactor = .one
        alphaColorD.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        alphaColorD.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        alphaColorD.colorAttachments[0].pixelFormat = pixelFormat
        alphaColorD.stencilAttachmentPixelFormat = .stencil8
        alphaColorD.rasterSampleCount = sampleCount
        alphaColorRenderPipelineState = try device.makeRenderPipelineState(descriptor: alphaColorD)
        
        let alphaColorsD = MTLRenderPipelineDescriptor()
        alphaColorsD.vertexFunction = library.makeFunction(name: "colorsVertex")
        alphaColorsD.vertexBuffers[0].mutability = .immutable
        alphaColorsD.vertexBuffers[1].mutability = .immutable
        alphaColorsD.vertexBuffers[2].mutability = .immutable
        alphaColorsD.fragmentFunction = library.makeFunction(name: "basicFragment")
        alphaColorsD.colorAttachments[0].isBlendingEnabled = true
        alphaColorsD.colorAttachments[0].rgbBlendOperation = .add
        alphaColorsD.colorAttachments[0].alphaBlendOperation = .add
        alphaColorsD.colorAttachments[0].sourceRGBBlendFactor = .one
        alphaColorsD.colorAttachments[0].sourceAlphaBlendFactor = .one
        alphaColorsD.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        alphaColorsD.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        alphaColorsD.colorAttachments[0].pixelFormat = pixelFormat
        alphaColorsD.stencilAttachmentPixelFormat = .stencil8
        alphaColorsD.rasterSampleCount = sampleCount
        colorsRenderPipelineState = try device.makeRenderPipelineState(descriptor: alphaColorsD)
        
        let maxColorsD = MTLRenderPipelineDescriptor()
        maxColorsD.vertexFunction = library.makeFunction(name: "colorsVertex")
        maxColorsD.vertexBuffers[0].mutability = .immutable
        maxColorsD.vertexBuffers[1].mutability = .immutable
        maxColorsD.vertexBuffers[2].mutability = .immutable
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
        
        let opaqueTextureD = MTLRenderPipelineDescriptor()
        opaqueTextureD.vertexFunction = library.makeFunction(name: "textureVertex")
        opaqueTextureD.vertexBuffers[0].mutability = .immutable
        opaqueTextureD.vertexBuffers[1].mutability = .immutable
        opaqueTextureD.vertexBuffers[2].mutability = .immutable
        opaqueTextureD.fragmentFunction = library.makeFunction(name: "textureFragment")
        opaqueTextureD.colorAttachments[0].pixelFormat = pixelFormat
        opaqueTextureD.stencilAttachmentPixelFormat = .stencil8
        opaqueTextureD.rasterSampleCount = sampleCount
        opaqueTextureRenderPipelineState = try device.makeRenderPipelineState(descriptor: opaqueTextureD)
        
        let alphaTextureD = MTLRenderPipelineDescriptor()
        alphaTextureD.vertexFunction = library.makeFunction(name: "textureVertex")
        alphaTextureD.vertexFunction = library.makeFunction(name: "textureVertex")
        alphaTextureD.vertexBuffers[0].mutability = .immutable
        alphaTextureD.vertexBuffers[1].mutability = .immutable
        alphaTextureD.vertexBuffers[2].mutability = .immutable
        alphaTextureD.fragmentFunction = library.makeFunction(name: "textureFragment")
        alphaTextureD.colorAttachments[0].isBlendingEnabled = true
        alphaTextureD.colorAttachments[0].rgbBlendOperation = .add
        alphaTextureD.colorAttachments[0].alphaBlendOperation = .add
        alphaTextureD.colorAttachments[0].sourceRGBBlendFactor = .one
        alphaTextureD.colorAttachments[0].sourceAlphaBlendFactor = .one
        alphaTextureD.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        alphaTextureD.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        alphaTextureD.colorAttachments[0].pixelFormat = pixelFormat
        alphaTextureD.stencilAttachmentPixelFormat = .stencil8
        alphaTextureD.rasterSampleCount = sampleCount
        alphaTextureRenderPipelineState = try device.makeRenderPipelineState(descriptor: alphaTextureD)
        
        let stencilD = MTLRenderPipelineDescriptor()
        stencilD.isAlphaToCoverageEnabled = true
        stencilD.vertexFunction = library.makeFunction(name: "stencilVertex")
        stencilD.vertexBuffers[0].mutability = .immutable
        stencilD.vertexBuffers[1].mutability = .immutable
        stencilD.fragmentFunction = nil
        stencilD.colorAttachments[0].pixelFormat = pixelFormat
        stencilD.colorAttachments[0].writeMask = []
        stencilD.stencilAttachmentPixelFormat = .stencil8
        stencilD.rasterSampleCount = sampleCount
        stencilRenderPipelineState = try device.makeRenderPipelineState(descriptor: stencilD)
        
        let stencilBezierD = MTLRenderPipelineDescriptor()
        stencilBezierD.isAlphaToCoverageEnabled = true
        stencilBezierD.vertexFunction = library.makeFunction(name: "stencilBVertex")
        stencilBezierD.vertexBuffers[0].mutability = .immutable
        stencilBezierD.vertexBuffers[1].mutability = .immutable
        stencilBezierD.fragmentFunction = library.makeFunction(name: "stencilBFragment")
        stencilBezierD.colorAttachments[0].pixelFormat = pixelFormat
        stencilBezierD.colorAttachments[0].writeMask = []
        stencilBezierD.stencilAttachmentPixelFormat = .stencil8
        stencilBezierD.rasterSampleCount = sampleCount
        stencilBezierRenderPipelineState = try device.makeRenderPipelineState(descriptor: stencilBezierD)
        
        let invertStencilD = MTLStencilDescriptor()
        invertStencilD.stencilFailureOperation = .invert
        invertStencilD.depthStencilPassOperation = .invert
        let invertDepthStencilD = MTLDepthStencilDescriptor()
        invertDepthStencilD.backFaceStencil = invertStencilD
        invertDepthStencilD.frontFaceStencil = invertStencilD
        guard let ss = device.makeDepthStencilState(descriptor: invertDepthStencilD) else {
            throw Renderer.metalError
        }
        invertDepthStencilState = ss
        
        let zeroStencilD = MTLStencilDescriptor()
        zeroStencilD.stencilFailureOperation = .zero
        zeroStencilD.depthStencilPassOperation = .zero
        let zeroDepthStencilD = MTLDepthStencilDescriptor()
        zeroDepthStencilD.backFaceStencil = zeroStencilD
        zeroDepthStencilD.frontFaceStencil = zeroStencilD
        guard let zs = device.makeDepthStencilState(descriptor: zeroDepthStencilD) else {
            throw Renderer.metalError
        }
        zeroDepthStencilState = zs
        
        let replaceStencilD = MTLStencilDescriptor()
        replaceStencilD.stencilFailureOperation = .replace
        replaceStencilD.depthStencilPassOperation = .replace
        let replaceDepthStencilD = MTLDepthStencilDescriptor()
        replaceDepthStencilD.backFaceStencil = replaceStencilD
        replaceDepthStencilD.frontFaceStencil = replaceStencilD
        guard let rs = device.makeDepthStencilState(descriptor: replaceDepthStencilD) else {
            throw Renderer.metalError
        }
        replaceDepthStencilState = rs
        
        let clippingStencilD = MTLStencilDescriptor()
        clippingStencilD.stencilCompareFunction = .notEqual
        clippingStencilD.stencilFailureOperation = .keep
        clippingStencilD.depthStencilPassOperation = .zero
        let clippingDepthStecilD = MTLDepthStencilDescriptor()
        clippingDepthStecilD.backFaceStencil = clippingStencilD
        clippingDepthStecilD.frontFaceStencil = clippingStencilD
        guard let cs = device.makeDepthStencilState(descriptor: clippingDepthStecilD) else {
            throw Renderer.metalError
        }
        clippingDepthStencilState = cs
        
        let reversedClippingStencilD = MTLStencilDescriptor()
        reversedClippingStencilD.stencilCompareFunction = .equal
        reversedClippingStencilD.stencilFailureOperation = .keep
        reversedClippingStencilD.depthStencilPassOperation = .zero
        let reversedClippingDepthStecilD = MTLDepthStencilDescriptor()
        reversedClippingDepthStecilD.backFaceStencil = reversedClippingStencilD
        reversedClippingDepthStecilD.frontFaceStencil = reversedClippingStencilD
        guard let rcs = device.makeDepthStencilState(descriptor: reversedClippingDepthStecilD) else {
            throw Renderer.metalError
        }
        reversedClippingDepthStencilState = rcs
        
        let normalDepthStencilD = MTLDepthStencilDescriptor()
        guard let ncs = device.makeDepthStencilState(descriptor: normalDepthStencilD) else {
            throw Renderer.metalError
        }
        normalDepthStencilState = ncs
        
        let cacheSamplerD = MTLSamplerDescriptor()
        cacheSamplerD.minFilter = .nearest
        cacheSamplerD.magFilter = .linear
        guard let ncss = device.makeSamplerState(descriptor: cacheSamplerD) else {
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

final class Context {
    var encoder: any MTLRenderCommandEncoder
    fileprivate let rs: Renderstate
    
    init(_ encoder: any MTLRenderCommandEncoder, _ rs: Renderstate) {
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
    func setZeroDepthStencil() {
        encoder.setDepthStencilState(rs.zeroDepthStencilState)
    }
    func setReplaceDepthStencil() {
        encoder.setDepthStencilState(rs.replaceDepthStencilState)
    }
    func setStencilReferenceValue(_ v: UInt32) {
        encoder.setStencilReferenceValue(v)
    }
    func setNormalDepthStencil() {
        encoder.setDepthStencilState(rs.normalDepthStencilState)
    }
    func setClippingDepthStencil() {
        encoder.setDepthStencilState(rs.clippingDepthStencilState)
    }
    func setReversedClippingDepthStencil() {
        encoder.setDepthStencilState(rs.reversedClippingDepthStencilState)
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
        
        let rpd: MTLRenderPassDescriptor, mtlTexture: any MTLTexture
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
        
        guard let commandBuffer = renderer.commandQueue.makeCommandBuffer() else { return nil }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { return nil }
        
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
    
    func renderedAntialiasFillImage(in bounds: Rect, to size: Size,
                                    backgroundColor: Color, _ colorSpace: ColorSpace) -> Image? {
        guard children.contains(where: { $0.fillType != nil }) else {
            return image(in: bounds, size: size, backgroundColor: backgroundColor, .sRGB)
        }
        
        children.forEach {
            if $0.lineType != nil {
                $0.isHidden = true
            }
        }
        guard let oImage = image(in: bounds, size: size * 2, backgroundColor: backgroundColor,
                                 colorSpace, isAntialias: false)?
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
        guard let nImage = image(in: bounds, size: size, backgroundColor: nil, colorSpace) else { return nil }
        return oImage.drawn(nImage, in: Rect(size: size))
    }
    func imageInBounds(size: Size? = nil,
                       backgroundColor: Color? = nil,
                       _ colorSpace: ColorSpace,
                       isAntialias: Bool = true,
                       isGray: Bool = false) -> Image? {
        guard let bounds = bounds else { return nil }
        return image(in: bounds, size: size ?? bounds.size,
                     backgroundColor: backgroundColor, colorSpace,
                     isAntialias: isAntialias, isGray: isGray)
    }
    func image(in bounds: Rect,
               size: Size,
               backgroundColor: Color? = nil, _ colorSpace: ColorSpace,
               isAntialias: Bool = true,
               isGray: Bool = false) -> Image? {
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: size.width / bounds.width,
                        y: size.height / bounds.height)
        return image(size: size, transform: transform,
                     backgroundColor: backgroundColor, colorSpace,
                     isAntialias: isAntialias, isGray: isGray)
    }
    func image(size: Size, transform: Transform,
               backgroundColor: Color? = nil, _ colorSpace: ColorSpace,
               isAntialias: Bool = true,
               isGray: Bool = false) -> Image? {
        let ctx = context(size: size, transform: transform, backgroundColor: backgroundColor,
                          colorSpace, isAntialias: isAntialias, isGray: isGray)
        guard let cgImage = ctx?.makeImage() else { return nil }
        return Image(cgImage: cgImage)
    }
    func bitmap<Value: FixedWidthInteger & UnsignedInteger>(size: Size,
                                                            backgroundColor: Color? = nil,
                                                            _ colorSpace: ColorSpace,
                                                            isAntialias: Bool = true,
                                                            isGray: Bool = false) -> Bitmap<Value>? {
        guard let bounds = bounds else { return nil }
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: size.width / bounds.width,
                        y: size.height / bounds.height)
        guard let ctx = context(size: size, transform: transform,
                                backgroundColor: backgroundColor, colorSpace,
                                isAntialias: isAntialias, isGray: isGray) else { return nil }
        return .init(ctx)
    }
    private func context(size: Size, transform: Transform,
                         backgroundColor: Color? = nil, _ colorSpace: ColorSpace,
                         isAntialias: Bool = true,
                         isGray: Bool = false) -> CGContext? {
        guard let space = isGray ? CGColorSpaceCreateDeviceGray() : colorSpace.cg else { return nil }
        let ctx: CGContext
        if colorSpace.isHDR {
            let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            guard let actx = CGContext(data: nil,
                                      width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 32, bytesPerRow: 0, space: space,
                                      bitmapInfo: bitmapInfo.rawValue) else { return nil }
            ctx = actx
        } else {
            let bitmapInfo = CGBitmapInfo(rawValue: isGray ? CGImageAlphaInfo.none.rawValue : (backgroundColor?.opacity == 1 ?
                                            CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue))
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
        return ctx
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
        } else if !isClippingChildren && !path.isEmpty {
            if let fillType = fillType {
                switch fillType {
                case .color(let color):
                    let cgPath = CGMutablePath()
                    for pathline in path.pathlines {
                        let polygon = pathline.polygon()
                        let points = polygon.points.map { $0.cg }
                        if !points.isEmpty {
                            cgPath.addLines(between: points)
                            cgPath.closeSubpath()
                        }
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
                    for ts in path.triangleStrips {
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
                    
                    for ts in path.triangleStrips {
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
                        if !points.isEmpty {
                            cgPath.addLines(between: points)
                            cgPath.closeSubpath()
                        }
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
        if isClippingChildren {
            if !path.isEmpty {
                if let fillType = fillType {
                    switch fillType {
                    case .color(let color):
                        ctx.saveGState()
                        
                        ctx.setAlpha(.init(color.opacity))
                        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                        let cgColor = color.with(opacity: 1).cg
                        ctx.setFillColor(cgColor)
                        
                        children.forEach {
                            if let lineType = $0.lineType {
                                switch lineType {
                                case .color:
                                    let (pd, counts) = $0.path.outlinePointsDataWith(lineWidth: $0.lineWidth)
                                    var i = 0
                                    let cgPath = CGMutablePath()
                                    for count in counts {
                                        let points = (i ..< (i + count)).map {
                                            Point(Double(pd[$0 * 4]),
                                                  Double(pd[$0 * 4 + 1])).cg
                                        }
                                        if !points.isEmpty {
                                            cgPath.addLines(between: points)
                                            cgPath.closeSubpath()
                                        }
                                        i += count
                                    }
                                    ctx.addPath(cgPath)
                                    ctx.fillPath()
                                default: break
                                }
                            }
                        }
                        
                        ctx.endTransparencyLayer()
                        ctx.restoreGState()
                    default: break
                    }
                }
            }
        } else {
            children.forEach { $0.render(in: ctx) }
        }
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
    fileprivate let mtl: any MTLBuffer
}

struct Texture {
    static let maxWidth = 16384, maxHeight = 16384
    
    fileprivate let mtl: any MTLTexture
    let isOpaque: Bool
    let cgColorSpace: CGColorSpace
    var cgImage: CGImage? {
        try? mtl.cgImage(with: cgColorSpace)
    }
    
    fileprivate init(_ mtl: any MTLTexture, isOpaque: Bool, colorSpace: CGColorSpace) {
        self.mtl = mtl
        self.isOpaque = isOpaque
        self.cgColorSpace = colorSpace
    }
    
    struct TextureError: Error {
        var localizedDescription = ""
    }
    
    struct Block {
        struct Item {
            let providerData: Data, width: Int, height: Int, mipmapLevel: Int, bytesPerRow: Int
        }
        
        var items: [Item]
        var isMipmapped: Bool { items.count > 1 }
    }
    static func block(from record: Record<Image>, isMipmapped: Bool = false) throws -> Block {
        if let image = record.value {
            try Self.block(from: image, isMipmapped: isMipmapped)
        } else if let data = record.decodedData {
            try Self.block(from: data, isMipmapped: isMipmapped)
        } else {
            throw TextureError()
        }
    }
    static func block(from data: Data, isMipmapped: Bool = false) throws -> Block {
        guard let cgImageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw TextureError()
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            throw TextureError()
        }
        return try block(from: cgImage, isMipmapped: isMipmapped)
    }
    static func block(from image: Image, isMipmapped: Bool = false) throws -> Block {
        try block(from: image.cg, isMipmapped: isMipmapped)
    }
    static func block(from cgImage: CGImage, isMipmapped: Bool = false) throws -> Block {
        guard let dp = cgImage.dataProvider, let data = dp.data else { throw TextureError() }
        let iw = cgImage.width, ih = cgImage.height
        
        var items = [Block.Item(providerData: data as Data, width: iw, height: ih, mipmapLevel: 0,
                                bytesPerRow: cgImage.bytesPerRow)]
        if isMipmapped {
            var image = Image(cgImage: cgImage), level = 1, mipW = iw / 2, mipH = ih / 2
            while mipW >= 1 && mipH >= 1 {
                guard let aImage = image.resize(with: Size(width: mipW, height: mipH)) else { throw TextureError() }
                image = aImage
                let cgImage = image.cg
                guard let ndp = cgImage.dataProvider, let ndata = ndp.data else { throw TextureError() }
                items.append(.init(providerData: ndata as Data, width: mipW, height: mipH,
                                   mipmapLevel: level, bytesPerRow: cgImage.bytesPerRow))
                
                mipW /= 2
                mipH /= 2
                level += 1
            }
        }
        return .init(items: items)
    }
    
//    @MainActor
    init(imageData: Data,
         isMipmapped: Bool = false,
         isOpaque: Bool = true,
         _ colorSpace: ColorSpace = .sRGB, isBGR: Bool = false) throws {
        let block = try Self.block(from: imageData, isMipmapped: isMipmapped)
        try self.init(block: block, isOpaque: isOpaque, colorSpace, isBGR: isBGR)
    }
//    @MainActor
    init(image: Image,
         isMipmapped: Bool = false,
         isOpaque: Bool = true,
         _ colorSpace: ColorSpace = .sRGB, isBGR: Bool = false) throws {
        let block = try Self.block(from: image, isMipmapped: isMipmapped)
        try self.init(block: block, isOpaque: isOpaque, colorSpace, isBGR: isBGR)
    }
//    @MainActor
    init(cgImage: CGImage,
         isMipmapped: Bool = false,
         isOpaque: Bool = true,
         _ colorSpace: ColorSpace = .sRGB, isBGR: Bool = false) throws {
        let block = try Self.block(from: cgImage, isMipmapped: isMipmapped)
        try self.init(block: block, isOpaque: isOpaque, colorSpace, isBGR: isBGR)
    }
//    @MainActor
    init(block: Block,
                    isOpaque: Bool = true,
         _ colorSpace: ColorSpace = .sRGB, isBGR: Bool = false) throws {
        guard let cgColorSpace = colorSpace.cg, !block.items.isEmpty else { throw TextureError() }
        let format = if colorSpace.isHDR {
            MTLPixelFormat.bgr10_xr_srgb
        } else {
            isBGR ? Renderer.shared.pixelFormat : Renderer.shared.imagePixelFormat
        }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format,
                                                          width: block.items[0].width,
                                                          height: block.items[0].height,
                                                          mipmapped: block.isMipmapped)
        guard let mtl = Renderer.shared.device.makeTexture(descriptor: td) else { throw TextureError() }
        
        for item in block.items {
            guard let bytes = CFDataGetBytePtr(item.providerData as CFData) else { throw TextureError() }
            let region = MTLRegionMake2D(0, 0, item.width, item.height)
            mtl.replace(region: region, mipmapLevel: item.mipmapLevel,
                        withBytes: bytes, bytesPerRow: item.bytesPerRow)
        }
        
        self.init(mtl, isOpaque: isOpaque, colorSpace: cgColorSpace)
    }
    
    @MainActor static func withGPU(block: Block,
                                   isOpaque: Bool,
                                   _ colorSpace: ColorSpace = .sRGB,
                                   completionHandler: @escaping (Texture) -> ()) throws {
        guard let cgColorSpace = colorSpace.cg, !block.items.isEmpty else { throw TextureError() }
        let format = if colorSpace.isHDR {
            MTLPixelFormat.bgr10_xr_srgb
        } else {
            Renderer.shared.imagePixelFormat
        }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format,
                                                          width: block.items[0].width,
                                                          height: block.items[0].height,
                                                          mipmapped: block.isMipmapped)
        guard let mtl = Renderer.shared.device.makeTexture(descriptor: td) else { return }
        
        for item in block.items {
            guard let bytes = CFDataGetBytePtr(item.providerData as CFData) else { throw TextureError() }
            let region = MTLRegionMake2D(0, 0, item.width, item.height)
            mtl.replace(region: region, mipmapLevel: item.mipmapLevel,
                        withBytes: bytes, bytesPerRow: item.bytesPerRow)
        }
        
        let commandQueue = Renderer.shared.commandQueue
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeBlitCommandEncoder()
        commandEncoder?.generateMipmaps(for: mtl)
        commandEncoder?.endEncoding()
        commandBuffer?.addCompletedHandler { _ in
            completionHandler(Texture(mtl, isOpaque: isOpaque, colorSpace: cgColorSpace))
        }
        commandBuffer?.commit()
    }
    
    @MainActor func with(mipmapLevel: Int) throws -> Self {
        let cgImage = try mtl.cgImage(with: cgColorSpace, mipmapLevel: mipmapLevel)
        let block = try Self.block(from: cgImage, isMipmapped: false)
        return try .init(block: block)
    }
}
extension Texture {
    static func mipmapLevel(from size: Size) -> Int {
        Int(Double.log2(max(size.width, size.height)).rounded(.down)) + 1
    }
    
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
            Image(cgImage: cgImage)
        } else {
            nil
        }
    }
    func image(mipmapLevel: Int) -> Image? {
        if let cgImage = try? mtl.cgImage(with: cgColorSpace,
                                          mipmapLevel: mipmapLevel) {
            Image(cgImage: cgImage)
        } else {
            nil
        }
    }
}
extension Texture: Equatable {
    static func == (lhs: Texture, rhs: Texture) -> Bool {
        lhs.mtl === rhs.mtl
    }
}
extension MTLTexture {
    func cgImage(with colorSpace: CGColorSpace, mipmapLevel: Int = 0) throws -> CGImage {
        if pixelFormat != .rgba8Unorm && pixelFormat != .rgba8Unorm_srgb
            && pixelFormat != .bgra8Unorm && pixelFormat != .bgra8Unorm_srgb {
            throw Texture.TextureError(localizedDescription: "Texture: Unsupport pixel format \(pixelFormat)")
        }
        let nl = 2 ** mipmapLevel
        let nw = width / nl, nh = height / nl
        let bytesSize = nw * nh * 4
        guard let bytes = malloc(bytesSize) else {
            throw Texture.TextureError()
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
            throw Texture.TextureError()
        }
        guard let cgImage = CGImage(width: nw, height: nh,
                                    bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                                    space: colorSpace, bitmapInfo: bitmapInfo, provider: provider,
                                    decode: nil, shouldInterpolate: true,
                                    intent: .defaultIntent) else {
            throw Texture.TextureError()
        }
        return cgImage
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

struct CPUNode {
    var children = [Self]()
    var isHidden = false
    var attitude = Attitude() {
        didSet {
            localTransform = attitude.transform
            isIdentityFromLocal = localTransform.isIdentity
        }
    }
    private(set) var localTransform = Transform.identity
    private(set) var isIdentityFromLocal = true
    
    var path = Path()
    var lineWidth = 0.0
    var lineType: Node.LineType?
    var fillType: Node.FillType?
    var isCPUFillAntialias = true
    var isDrawLineAntialias = false
    
    init(children: [Self] = [Self](), isHidden: Bool = false, attitude: Attitude = Attitude(),
         path: Path = Path(),
         lineWidth: Double = 0.0, lineType: Node.LineType? = nil, fillType: Node.FillType? = nil,
         isCPUFillAntialias: Bool = true, isDrawLineAntialias: Bool = false) {
        
        self.children = children
        self.isHidden = isHidden
        self.attitude = attitude
        let localTransform = attitude.transform
        self.localTransform = localTransform
        self.isIdentityFromLocal = localTransform.isIdentity
        self.path = path
        self.lineWidth = lineWidth
        self.lineType = lineType
        self.fillType = fillType
        self.isCPUFillAntialias = isCPUFillAntialias
        self.isDrawLineAntialias = isDrawLineAntialias
    }
    init(children: [Self] = [Self](), isHidden: Bool = false, attitude: Attitude = Attitude(),
         localTransform: Transform = .identity, isIdentityFromLocal: Bool = true,
         path: Path = Path(),
         lineWidth: Double = 0.0, lineType: Node.LineType? = nil, fillType: Node.FillType? = nil,
         isCPUFillAntialias: Bool = true, isDrawLineAntialias: Bool = false) {
        
        self.children = children
        self.isHidden = isHidden
        self.attitude = attitude
        self.localTransform = localTransform
        self.isIdentityFromLocal = isIdentityFromLocal
        self.path = path
        self.lineWidth = lineWidth
        self.lineType = lineType
        self.fillType = fillType
        self.isCPUFillAntialias = isCPUFillAntialias
        self.isDrawLineAntialias = isDrawLineAntialias
    }
}
extension Node {
    var cpu: CPUNode {
        .init(children: children.map { $0.cpu }, isHidden: isHidden, attitude: attitude,
              localTransform: localTransform, isIdentityFromLocal: isIdentityFromLocal,
              path: path, lineWidth: lineWidth, lineType: lineType, fillType: fillType,
              isCPUFillAntialias: isCPUFillAntialias)
    }
}
extension CPUNode {
    var bounds: Rect? {
        path.bounds
    }
}
extension CPUNode {
    func render(in bounds: Rect, to size: Size, in pdf: PDF) {
        let transform = Transform(translation: -bounds.origin)
        * Transform(scaleX: size.width / bounds.width, y: size.height / bounds.height)
        render(to: size, transform: transform, in: pdf)
    }
    func render(to size: Size, transform: Transform, in pdf: PDF) {
        render(to: Rect(origin: Point(), size: size), transform, in: pdf)
    }
    func render(in bounds: Rect, to toBounds: Rect, in pdf: PDF) {
        let transform = Transform(translation: -bounds.origin)
        * Transform(scaleX: toBounds.width / bounds.width, y: toBounds.height / bounds.height)
        * Transform(translation: toBounds.origin)
        render(to: toBounds, transform, in: pdf)
    }
    func render(to toBounds: Rect, _ transform: Transform, in pdf: PDF) {
        let backgroundColor = if case .color(let color) = fillType {
            color
        } else {
            Color.background
        }
        let nt = localTransform.inverted() * transform
        
        let ctx = pdf.ctx
        ctx.saveGState()
       
        ctx.setFillColor(backgroundColor.cg)
        ctx.fill(toBounds.cg)
        
        ctx.concatenate(nt.cg)
        render(in: ctx, isDrawFillAntialias: nil)
        
        ctx.restoreGState()
    }
    
    func renderedAntialiasFillImage(in bounds: Rect, to size: Size, _ colorSpace: ColorSpace) -> Image? {
        let backgroundColor = if case .color(let color) = fillType {
            color
        } else {
            Color.background
        }
        guard children.contains(where: { $0.fillType != nil }) else {
            return image(in: bounds, size: size, backgroundColor: backgroundColor, .sRGB)
        }
        guard let oImage = image(in: bounds, size: size * 2, backgroundColor: backgroundColor,
                                 colorSpace, isAntialias: false,
                                 isDrawFillAntialias: true)?
            .resize(with: size) else { return nil }
        guard let nImage = image(in: bounds, size: size, backgroundColor: nil, colorSpace,
                                 isDrawFillAntialias: false) else { return nil }
        return oImage.drawn(nImage, in: Rect(size: size))
    }
    func imageInBounds(size: Size? = nil,
                       backgroundColor: Color? = nil,
                       _ colorSpace: ColorSpace,
                       isAntialias: Bool = true,
                       isGray: Bool = false) -> Image? {
        guard let bounds = bounds else { return nil }
        return image(in: bounds, size: size ?? bounds.size,
                     backgroundColor: backgroundColor, colorSpace,
                     isAntialias: isAntialias, isGray: isGray)
    }
    func image(in bounds: Rect,
               size: Size,
               backgroundColor: Color? = nil, _ colorSpace: ColorSpace,
               isAntialias: Bool = true,
               isGray: Bool = false, isDrawFillAntialias: Bool? = false) -> Image? {
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: size.width / bounds.width,
                        y: size.height / bounds.height)
        return image(size: size, transform: transform,
                     backgroundColor: backgroundColor, colorSpace,
                     isAntialias: isAntialias, isGray: isGray, isDrawFillAntialias: isDrawFillAntialias)
    }
    func image(size: Size, transform: Transform,
               backgroundColor: Color? = nil, _ colorSpace: ColorSpace,
               isAntialias: Bool = true,
               isGray: Bool = false, isDrawFillAntialias: Bool? = false) -> Image? {
        let ctx = context(size: size, transform: transform, backgroundColor: backgroundColor,
                          colorSpace, isAntialias: isAntialias, isGray: isGray,
                          isDrawFillAntialias: isDrawFillAntialias)
        guard let cgImage = ctx?.makeImage() else { return nil }
        return Image(cgImage: cgImage)
    }
    func bitmap<Value: FixedWidthInteger & UnsignedInteger>(size: Size,
                                                            backgroundColor: Color? = nil,
                                                            _ colorSpace: ColorSpace,
                                                            isAntialias: Bool = true,
                                                            isGray: Bool = false) -> Bitmap<Value>? {
        guard let bounds = bounds else { return nil }
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: size.width / bounds.width,
                        y: size.height / bounds.height)
        guard let ctx = context(size: size, transform: transform,
                                backgroundColor: backgroundColor, colorSpace,
                                isAntialias: isAntialias, isGray: isGray) else { return nil }
        return .init(ctx)
    }
    private func context(size: Size, transform: Transform,
                         backgroundColor: Color? = nil, _ colorSpace: ColorSpace,
                         isAntialias: Bool = true,
                         isGray: Bool = false, isDrawFillAntialias: Bool? = false) -> CGContext? {
        guard let space = isGray ? CGColorSpaceCreateDeviceGray() : colorSpace.cg else { return nil }
        let ctx: CGContext
        if colorSpace.isHDR {
            let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            guard let actx = CGContext(data: nil,
                                      width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 32, bytesPerRow: 0, space: space,
                                      bitmapInfo: bitmapInfo.rawValue) else { return nil }
            ctx = actx
        } else {
            let bitmapInfo = CGBitmapInfo(rawValue: isGray ? CGImageAlphaInfo.none.rawValue : (backgroundColor?.opacity == 1 ?
                                            CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue))
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
        } else if isDrawFillAntialias ?? true, case .color(let backgroundColor)? = fillType {
            ctx.setFillColor(backgroundColor.cg)
            ctx.fill(Rect(origin: Point(), size: size).cg)
        }
        ctx.setShouldAntialias(isAntialias)
        ctx.concatenate(nt.cg)
        render(in: ctx, isDrawFillAntialias: isDrawFillAntialias)
        ctx.restoreGState()
        return ctx
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
    func render(transform: Transform, in ctx: CGContext, isDrawFillAntialias: Bool? = false) {
        let nt = localTransform.inverted() * transform
        ctx.saveGState()
        ctx.concatenate(nt.cg)
        render(in: ctx, isDrawFillAntialias: isDrawFillAntialias)
        ctx.restoreGState()
    }
    func render(in ctx: CGContext, isDrawFillAntialias: Bool? = false) {
        guard !isHidden else { return }
        if !isIdentityFromLocal {
            ctx.saveGState()
            ctx.concatenate(localTransform.cg)
        }
        if let typesetter = path.typesetter, let b = bounds {
            if !(isDrawFillAntialias ?? false) {
                switch lineType {
                case .color(let color):
                    ctx.saveGState()
                    ctx.setStrokeColor(color.cg)
                    ctx.setLineWidth(lineWidth)
                    ctx.setLineJoin(.round)
                    typesetter.append(in: ctx)
                    ctx.strokePath()
                    ctx.restoreGState()
                case .gradient, .none: break
                }
                switch fillType {
                case .color(let color):
                    typesetter.draw(in: b, fillColor: color, in: ctx)
                default:
                    typesetter.draw(in: b, fillColor: .content, in: ctx)
                }
            }
        } else if !path.isEmpty {
            if isDrawFillAntialias ?? true, let fillType {
                switch fillType {
                case .color(let color):
                    let cgPath = CGMutablePath()
                    for pathline in path.pathlines {
                        let polygon = pathline.polygon()
                        let points = polygon.points.map { $0.cg }
                        if !points.isEmpty {
                            cgPath.addLines(between: points)
                            cgPath.closeSubpath()
                        }
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
                    for ts in path.triangleStrips {
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
                    
                    for ts in path.triangleStrips {
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
            if isDrawLineAntialias ?
                (isDrawFillAntialias ?? false) : !(isDrawFillAntialias ?? false), let lineType {
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
                        if !points.isEmpty {
                            cgPath.addLines(between: points)
                            cgPath.closeSubpath()
                        }
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
        children.forEach { $0.render(in: ctx, isDrawFillAntialias: isDrawFillAntialias) }
        if !isIdentityFromLocal {
            ctx.restoreGState()
        }
    }
}

struct Image {
    let cg: CGImage
    
    init(cgImage: CGImage) {
        self.cg = cgImage
    }
    init?(data: Data) {
        guard let cgImageSource
                = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        guard let cg
                = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            return nil
        }
        self.cg = cg
    }
    init?(url: URL) {
        let dic = [kCGImageSourceShouldCacheImmediately: kCFBooleanTrue]
        guard let s = CGImageSourceCreateWithURL(url as CFURL,
                                                 dic as CFDictionary),
              let cgImage = CGImageSourceCreateImageAtIndex(s, 0, dic as CFDictionary),
              let cs = CGColorSpace.sRGBColorSpace else { return nil }
        
        if cgImage.colorSpace?.name == cs.name
            && ((cgImage.bitmapInfo.rawValue & CGImageAlphaInfo.premultipliedLast.rawValue) != 0
                || (cgImage.bitmapInfo.rawValue & CGImageAlphaInfo.noneSkipLast.rawValue) != 0) {
            cg = cgImage
        } else {
            let isNoneAlpha = (cgImage.bitmapInfo.rawValue & CGImageAlphaInfo.noneSkipLast.rawValue) != 0
            || (cgImage.bitmapInfo.rawValue & CGImageAlphaInfo.noneSkipFirst.rawValue) != 0
            || (cgImage.bitmapInfo.rawValue & CGImageAlphaInfo.none.rawValue) != 0
            let bitmapInfo = CGBitmapInfo(rawValue: isNoneAlpha ?
                                          CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let data = cgImage.dataProvider,
                  let colorSpace = cgImage.colorSpace,
                  let nCGImage = CGImage(width: cgImage.width,
                                       height: cgImage.height,
                                       bitsPerComponent: cgImage.bitsPerComponent,
                                       bitsPerPixel: cgImage.bitsPerPixel,
                                       bytesPerRow: cgImage.bytesPerRow,
                                       space: colorSpace,
                                       bitmapInfo: cgImage.bitmapInfo,
                                       provider: data,
                                       decode: nil,
                                       shouldInterpolate: false,
                                       intent: .absoluteColorimetric),
                  let ctx = CGContext(data: nil,
                                      width: cgImage.width,
                                      height: cgImage.height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 4 * cgImage.width,
                                      space: cs,
                                      bitmapInfo: bitmapInfo.rawValue) else { return nil }
            ctx.draw(nCGImage, in: CGRect(x: 0,
                                          y: 0,
                                          width: nCGImage.width,
                                          height: nCGImage.height))
            guard let nnCGImage = ctx.makeImage() else { return nil }
            cg = nnCGImage
        }
    }
    init?(size: Size, color: Color) {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let ctx = CGContext(data: nil,
                                  width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: color.colorSpace.cg ?? .default,
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
        guard let ctx = CGContext(data: nil,
                                  width: cg.width, height: cg.height,
                                  bitsPerComponent: cg.bitsPerComponent, bytesPerRow: cg.bytesPerRow,
                                  space: cg.colorSpace ?? .default,
                                  bitmapInfo: cg.bitmapInfo.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        ctx.draw(image.cg, in: rect.cg)
        guard let nImage = ctx.makeImage() else { return nil }
        return Image(cgImage: nImage)
    }
    
    var size: Size {
        cg.size
    }
    var texture: Texture? {
        if let data = self.data(.jpeg) {
            return try? Texture(imageData: data, isOpaque: true)
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
    
    var fileType: FileType {
        switch cg.utType as? String {
        case UniformTypeIdentifiers.UTType.jpeg.identifier: .jpeg
        case UniformTypeIdentifiers.UTType.png.identifier: .png
        case UniformTypeIdentifiers.UTType.tiff.identifier: .tiff
        case UniformTypeIdentifiers.UTType.gif.identifier: .gif
        default: .jpeg
        }
    }
}
extension Image: Hashable {}
extension Image: Codable {
    struct CodableError: Error {}
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        guard let aSelf = Image(data: data) else {
            throw CodableError()
        }
        self = aSelf
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let data = data(fileType) {
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
        if let data = data(fileType) {
            return data
        } else {
            throw SerializableError()
        }
    }
}
extension Image: Protobuf {
    struct DecodeError: Error {}
    init(_ pb: PBImage) throws {
        guard let aSelf = Image(data: pb.data) else {
            throw DecodeError()
        }
        self = aSelf
    }
    var pb: PBImage {
        .with {
            $0.data = data(fileType) ?? .init()
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
    let data: UnsafeMutablePointer<Value>
    let offsetPerRow: Int, offsetPerPixel: Int
    let width: Int, height: Int
    
    convenience init?(width: Int, height: Int, colorSpace: ColorSpace) {
        let bitmapInfo = colorSpace == .grayscale ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: MemoryLayout<Value>.size * 8,
                                  bytesPerRow: 0, space: colorSpace.cg,
                                  bitmapInfo: bitmapInfo) else { return nil }
        self.init(ctx)
    }
    init?(_ ctx: CGContext) {
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
            data[offsetPerRow * y + x]
        }
        set {
            data[offsetPerRow * y + x] = newValue
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
    
    func set(isAntialias: Bool) {
        ctx.setShouldAntialias(isAntialias)
    }
    func set(_ transform: Transform) {
        ctx.concatenate(transform.cg)
    }
    func set(fillColor: Color) {
        ctx.setFillColor(fillColor.cg)
    }
    func set(lineCap: LineCap) {
        ctx.setLineCap(lineCap.cg)
    }
    func set(lineWidth: Double) {
        ctx.setLineWidth(.init(lineWidth))
    }
    func set(lineColor: Color) {
        ctx.setStrokeColor(lineColor.cg)
    }
    
    func fill(_ rect: Rect) {
        ctx.addRect(rect.cg)
        ctx.fillPath()
    }
    func fill(_ ps: [Point]) {
        ctx.addLines(between: ps.map { $0.cg })
        ctx.closePath()
        ctx.fillPath()
    }
    func stroke(_ edge: Edge) {
        ctx.move(to: edge.p0.cg)
        ctx.addLine(to: edge.p1.cg)
        ctx.strokePath()
    }
    
    var image: Image? {
        guard let cgImage = ctx.makeImage() else { return nil }
        return Image(cgImage: cgImage)
    }
}
