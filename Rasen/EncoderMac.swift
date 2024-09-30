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

import AVFoundation
import VideoToolbox
import CoreImage

struct Caption: Hashable, Codable {
    var string = ""
    var orientation = Orientation.horizontal
    var isTitle = false
    var beatRange = 0 ..< Rational(0)
    var tempo = Music.defaultTempo
}
extension Caption: TempoType {
    var secRange: Range<Rational> {
        secRange(fromBeat: beatRange)
    }
}
extension Caption {
    enum FileType: FileTypeProtocol, CaseIterable {
        case scc
        var name: String {
            switch self {
            case .scc: "SCC"
            }
        }
        var utType: UTType {
            switch self {
            case .scc: AVFileType.SCC.utType
            }
        }
    }
    
    func nodes(withFontSize fontSize: Double = 11,
               in bounds: Rect, padding: Double = 8, outlineWidth: Double = 2) -> [Node] {
        let fontSize = isTitle ? fontSize * 1.25 : fontSize
        guard let tb = Text(string: string, size: fontSize,
                            widthCount: bounds.width).bounds else { return [] }
        switch orientation {
        case .horizontal:
            let tp = bounds.midXMinYPoint + Point(-tb.width / 2, padding + tb.height)
            
            let text = Text(string: string, size: fontSize, widthCount: bounds.width)
            var typebute = text.typobute
            typebute.font.isProportional = isTitle
            typebute.orientation = .horizontal
            typebute.maxTypelineWidth = .infinity
            typebute.spacing = typebute.font.size / 2
            typebute.alignment = .center
            let path = Typesetter(string: string, typobute: typebute).path()
            return [Node(attitude: Attitude(position: tp),
                         path: path,
                         lineWidth: outlineWidth, lineType: .color(.content)),
                    Node(attitude: Attitude(position: tp),
                         path: path,
                         fillType: .color(.background))]
        case .vertical:
            let tp = bounds.maxXMidYPoint + Point(-padding * 5, tb.width / 2)
            
            let text = Text(string: string, size: fontSize, widthCount: bounds.width)
            var typebute = text.typobute
            typebute.orientation = .vertical
            typebute.maxTypelineWidth = .infinity
            typebute.spacing = typebute.font.size / 2
            let path = Typesetter(string: string, typobute: typebute).path()
            return [Node(attitude: Attitude(position: tp),
                         path: path,
                         lineWidth: outlineWidth, lineType: .color(.content)),
                    Node(attitude: Attitude(position: tp),
                         path: path,
                         fillType: .color(.background))]
        }
    }
    static func caption(atBeat time: Rational, in captions: [Caption]) -> Caption? {
        for caption in captions {
            if caption.beatRange.contains(time) {
                return caption
            }
        }
        return nil
    }
}

extension AVFileType: FileTypeProtocol {
    var name: String { rawValue }
    var utType: UTType { UTType(UniformTypeIdentifiers.UTType(rawValue)!) }
}

final class Movie {
    enum FileType: FileTypeProtocol, CaseIterable {
        case mov, mp4
        var name: String {
            switch self {
            case .mov: "MOV"
            case .mp4: "MP4"
            }
        }
        var utType: UTType {
            switch self {
            case .mov: AVFileType.mov.utType
            case .mp4: AVFileType.mp4.utType
            }
        }
    }
    
    private struct Setting {
        var loopCount = 1
        var soundTuples = [(startTime: Rational, inTimeRange: Range<Rational>, sound: Content)]()
        var time = Rational(), duration = Rational()
        
        var isEmpty: Bool {
            loopCount <= 1 && soundTuples.isEmpty
        }
        var loopedDuration: Rational {
            duration * Rational(loopCount)
        }
    }
    
    static let exportError = NSError(domain: AVFoundationErrorDomain,
                                     code: AVError.Code.exportFailed.rawValue)
    
    let url: URL
    let fileType = AVFileType.mp4, codec: AVVideoCodecType
    let renderSize: Size, isHDR: Bool
    let sampleRate = Audio.defaultSampleRate, audioChannelCount = 2
    private let colorSpace: CGColorSpace, colorSpaceProfile: CFData
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput
    private let pbAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    private var //currentTime = Rational(0),
                lastCMTime = CMTime(value: 0, timescale: 60), append = false, stop = false
    private var deltaTime = Rational(0)
    private var settings = [Setting]()
    
    init(url: URL, renderSize: Size,
         isLinearPCM: Bool,
         colorSpace rgbColorSpace: RGBColorSpace) throws {
        self.url = url
        self.renderSize = renderSize
        
        isHDR = rgbColorSpace.isHDR
        codec = isHDR ? AVVideoCodecType.hevc : AVVideoCodecType.h264
        guard let colorSpace = isHDR ?
                CGColorSpace.itur2020HLGColorSpace : CGColorSpace.sRGBColorSpace,
              let colorSpaceProfile = colorSpace.copyICCData() else { throw Self.exportError }
        self.colorSpace = colorSpace
        self.colorSpaceProfile = colorSpaceProfile
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        let width = Int(renderSize.width), height = Int(renderSize.height)
        let setting: [String: Any] = isHDR ?
            [AVVideoCodecKey: codec,
             AVVideoWidthKey: width,
             AVVideoHeightKey: height,
             AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                                         AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                                         AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020],
             AVVideoCompressionPropertiesKey: [AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel]]
            : [AVVideoCodecKey: codec,
               AVVideoWidthKey: width,
               AVVideoHeightKey: height,
               AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                           AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                           AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2]]
        videoInput = AVAssetWriterInput(mediaType: .video,
                                         outputSettings: setting)
        videoInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)
        
        let audioSetting: [String: Any] = isLinearPCM ?
            [AVFormatIDKey: kAudioFormatFLAC,
             AVNumberOfChannelsKey: audioChannelCount,
             AVSampleRateKey: Float(sampleRate)] :
            [AVFormatIDKey: kAudioFormatMPEG4AAC,
             AVNumberOfChannelsKey: audioChannelCount,
             AVSampleRateKey: Float(sampleRate),
             AVEncoderBitRateKey: 320000]
        audioInput = AVAssetWriterInput(mediaType: .audio,
                                        outputSettings: audioSetting)
        audioInput.expectsMediaDataInRealTime = true
        audioInput.languageCode = Locale.current.language.languageCode?.identifier
        writer.add(audioInput)
        
        let attributes: [String: Any] = isHDR ?
           [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange),
            String(kCVPixelBufferWidthKey): width,
            String(kCVPixelBufferHeightKey): height % 2 == 0 ? height + 1 : height//AVFondation or Core Image bug?
            ] :
            [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32ARGB),
             String(kCVPixelBufferWidthKey): width,
             String(kCVPixelBufferHeightKey): height,
             String(kCVPixelBufferCGBitmapContextCompatibilityKey): true]
        pbAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput,
                                                       sourcePixelBufferAttributes: attributes)
        
        if !writer.startWriting() { throw Self.exportError }
        writer.startSession(atSourceTime: .zero)
    }
    
    func writeMovie(frameCount: Int, duration: Rational,
                    frameRate: Int,
                    imageHandler: (Rational) -> (Image?),
                    progressHandler: (Double, inout Bool) -> ()) {
        for i in 0 ..< frameCount {
            autoreleasepool {
                while !videoInput.isReadyForMoreMediaData {
                    progressHandler(Double(i) / Double(frameCount - 1), &stop)
                    if stop { return }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                guard let bufferPool = pbAdaptor.pixelBufferPool else { return }
                var pixelBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,
                                                   bufferPool, &pixelBuffer)
                if let pb = pixelBuffer {
                    CVBufferSetAttachment(pb,
                                          kCVImageBufferICCProfileKey,
                                          colorSpaceProfile,
                                          .shouldPropagate)
                    CVPixelBufferLockBaseAddress(pb,
                                                 CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                    
                    let it = Rational(i, frameRate) + deltaTime
                    if isHDR {
                        if let image = imageHandler(it) {
                            let ciImage = CIImage(cgImage: image.cg)
                            let ctx = CIContext(options: [.workingColorSpace: colorSpace])
                            ctx.render(ciImage, to: pb)
                        }
                    } else {
                        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                        if let ctx
                            = CGContext(data: CVPixelBufferGetBaseAddress(pb),
                                        width: CVPixelBufferGetWidth(pb),
                                        height: CVPixelBufferGetHeight(pb),
                                        bitsPerComponent: 8,
                                        bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                        space: colorSpace,
                                        bitmapInfo: bitmapInfo.rawValue) {

                            if let image = imageHandler(it) {
                                ctx.draw(image.cg,
                                         in: CGRect(x: 0, y: 0,
                                                    width: image.size.width,
                                                    height: image.size.height))
                            }
                        }
                    }
                    
                    CVPixelBufferUnlockBaseAddress(pb,
                                                   CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                    let time = CMTime(value: Int64(i),
                                      timescale: Int32(frameRate)) + lastCMTime
                    append = pbAdaptor.append(pb, withPresentationTime: time)
                    if !append { return }
                    progressHandler(Double(i) / Double(frameCount - 1), &stop)
                    if stop { return }
                }
            }
            if !append || stop { break }
        }
        
        lastCMTime = CMTime(value: Int64(frameCount),
                            timescale: Int32(frameRate)) + lastCMTime
        let d = duration - Rational(frameCount) / Rational(frameRate)
        deltaTime = d < Rational(1, 100000) ? 0 : d
    }
    
    func writeAudio(from seq: Sequencer,
                    isCompress: Bool = true,
                    progressHandler: (Double, inout Bool) -> ()) throws {
        if isCompress {
            guard let oBuffer = try seq.buffer(sampleRate: sampleRate,
                                               headroomAmp: nil,
                                               progressHandler: progressHandler) else { return }
            oBuffer.compress(targetDb: -Audio.headroomDb)
            guard let buffer = oBuffer.cmSampleBuffer else { return }
            audioInput.append(buffer)
            
            var stop = false
            let length = AVAudioFramePosition(seq.durSec * sampleRate)
            
            progressHandler(Double(seq.engine.manualRenderingSampleTime) / Double(length), &stop)
            if stop { return }
            
            return
        }
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: Double(sampleRate),
                                         channels: AVAudioChannelCount(audioChannelCount),
                                         interleaved: true) else { throw Self.exportError }
        
        try seq.engine.enableManualRenderingMode(.offline,
                                             format: format,
                                             maximumFrameCount: 512)
        try seq.engine.start()
//        seq.playerNodes.forEach { $0.schedule(inTime: 0) }
//        try seq.avSequencer?.start()
//        seq.playerNodes.forEach { $0.play() }
        seq.isPlaying = true
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: seq.engine.manualRenderingFormat, frameCapacity: seq.engine.manualRenderingMaximumFrameCount) else {
            
            seq.isPlaying = false
//            seq.avSequencer?.stop()
//            seq.playerNodes.forEach { $0.stop() }
            seq.endEngine()
            throw Self.exportError
        }
        
        var stop = false
        let length = AVAudioFramePosition(seq.durSec * sampleRate)
        while seq.engine.manualRenderingSampleTime < length {
            while !audioInput.isReadyForMoreMediaData {
                progressHandler(Double(seq.engine.manualRenderingSampleTime) / Double(length), &stop)
                if stop { return }
                Thread.sleep(forTimeInterval: 0.1)
            }
            do {
                let frameCount = length - seq.engine.manualRenderingSampleTime
                let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
                let status = try seq.engine.renderOffline(framesToRender, to: buffer)
                switch status {
                case .success:
                    autoreleasepool {
                        buffer.clip(amp: Float(Audio.floatHeadroomAmp))
                        
                        guard let buffer = buffer.cmSampleBuffer else { return }
                        audioInput.append(buffer)
                    }
                    progressHandler(Double(seq.engine.manualRenderingSampleTime) / Double(length), &stop)
                    if stop { return }
                case .insufficientDataFromInputNode:
                    throw Self.exportError
                case .cannotDoInCurrentContext:
                    progressHandler(Double(seq.engine.manualRenderingSampleTime) / Double(length), &stop)
                    if stop { return }
                    Thread.sleep(forTimeInterval: 0.1)
                case .error: throw Self.exportError
                @unknown default: throw Self.exportError
                }
            } catch {
                seq.isPlaying = false
//                seq.avSequencer?.stop()
//                seq.playerNodes.forEach { $0.stop() }
                seq.endEngine()
                throw error
            }
        }
        
        seq.isPlaying = false
//        seq.avSequencer?.stop()
//        seq.playerNodes.forEach { $0.stop() }
        seq.endEngine()
    }
    
    func finish(completionHandler handler: @escaping (Bool, (any Error)?) -> ()) {
        videoInput.markAsFinished()
        audioInput.markAsFinished()
        
        if !append || stop {
            writer.cancelWriting()
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    handler(stop, error)
                    return
                }
            }
            if !append && !stop {
                handler(stop, Self.exportError)
            } else {
                handler(stop, nil)
            }
        } else {
            writer.endSession(atSourceTime: lastCMTime)
            let writer = self.writer, stop = self.stop
            writer.finishWriting {
                handler(stop, writer.error)
            }
        }
    }
}

final class CaptionRenderer {
    struct ExportError: Error {}
    
    let url: URL
    private let writer: AVAssetWriter,
                captionInput: AVAssetWriterInput,
                cAdaptor: AVAssetWriterInputCaptionAdaptor
    private var append = false, stop = false,
                lastCMTime = CMTime(),
                allDuration = Rational(), currentTime = Rational()

    init(url: URL) throws {
        self.url = url

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }

        writer = try AVAssetWriter(outputURL: url, fileType: .SCC)
        captionInput = AVAssetWriterInput(mediaType: .closedCaption,
                                         outputSettings: [:])
        captionInput.expectsMediaDataInRealTime = true
        captionInput.languageCode = Locale.current.language.languageCode?.identifier
        writer.add(captionInput)

        cAdaptor = AVAssetWriterInputCaptionAdaptor(assetWriterInput: captionInput)

        if !writer.startWriting() {
            throw ExportError()
        }
        writer.startSession(atSourceTime: .zero)
    }

    func write(captions: [Caption], duration: Rational = Rational(),
               frameRate: Int,
               progressHandler: (Double, inout Bool) -> ()) {
        for (i, caption) in captions.enumerated() {
            autoreleasepool {
                while !captionInput.isReadyForMoreMediaData {
                    progressHandler(Double(i) / Double(captions.count - 1), &stop)
                    if stop { return }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                let startTime = (caption.beatRange.start + allDuration)
                    .cm(timescale: Int32(frameRate))
                
                let duration = (caption.beatRange.end - caption.beatRange.start)
                    .cm(timescale: Int32(frameRate))
                
                let range = CMTimeRange(start: startTime,
                                        duration: duration)
                let avCaption = AVCaption(caption.string, timeRange: range)
                append = cAdaptor.append(avCaption)
                
                if !append { return }
                progressHandler(Double(i) / Double(captions.count - 1), &stop)
                if stop { return }
            }
            if !append || stop { break }
        }
        
        lastCMTime = duration.cm(timescale: Int32(frameRate)) + lastCMTime
        allDuration += duration
        currentTime += duration
    }
    func finish(completionHandler handler: @escaping ((any Error)?) -> ()) {
        captionInput.markAsFinished()

        if !append || stop {
            writer.cancelWriting()
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    handler(error)
                }
            }
            if !append {
                handler(ExportError())
            }
        } else {
            writer.endSession(atSourceTime: lastCMTime)
            let writer = self.writer
            writer.finishWriting {
                handler(writer.error)
            }
        }
    }
}

extension Rational {
    fileprivate func cm(timescale: CMTimeScale) -> CMTime {
        CMTime(value: CMTimeValue(p * Int(timescale) / q),
               timescale: timescale)
    }
}
extension Double {
    fileprivate func cm(timescale: CMTimeScale) -> CMTime {
        CMTime(value: CMTimeValue(self * Double(timescale)),
               timescale: timescale)
    }
}
extension Range where Bound == Rational {
    fileprivate func cm(timescale: CMTimeScale) -> CMTimeRange {
        CMTimeRange(start: start.cm(timescale: timescale),
                    duration: length.cm(timescale: timescale))
    }
}
extension Range where Bound == Double {
    fileprivate func cm(timescale: CMTimeScale) -> CMTimeRange {
        CMTimeRange(start: start.cm(timescale: timescale),
                    duration: length.cm(timescale: timescale))
    }
}

extension Movie {
    static func m4aFromMP4(from fromUrl: URL, to toUrl: URL, isRemoveFromUrl: Bool = true) async throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: toUrl.path) {
            try fileManager.removeItem(at: toUrl)
        }
        
        let asset = AVURLAsset(url: fromUrl)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
        else { throw Self.exportError }
        session.outputFileType = AVFileType.m4a
        session.outputURL = toUrl
        
        await session.export()
        
        switch session.status {
        case .completed:
            if isRemoveFromUrl {
                try fileManager.removeItem(at: fromUrl)
            }
        default:
            if let error = session.error {
                throw error
            }
        }
    }
}

final class MovieImageGenerator {
    private var generator: AVAssetImageGenerator
    
    init(url: URL) {
        let asset = AVURLAsset(url: url)
        generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
    }
    func thumbnail(atSec sec: Rational = .init(0, 1)) async throws -> Image {
        let cgImage = try await generator.image(at: .init(value: .init(sec.p),
                                                          timescale: .init(sec.q))).image
        return Image(cgImage: cgImage)
    }
}
extension Movie {
    static func size(from url: URL) async throws -> Size? {
        let asset = AVAsset(url: url)
        return try await asset.load(.tracks).first?.load(.naturalSize).my
    }
    static func durSec(from url: URL) async throws -> Rational {
        let asset = AVAsset(url: url)
        return try await asset.load(.duration).my
    }
    static func frameRate(from url: URL) async throws -> Float? {
        let asset = AVAsset(url: url)
        return try await asset.load(.tracks).first?.load(.nominalFrameRate)
    }
}

extension CMTime {
    var my: Rational {
        .init(Int(value), Int(timescale))
    }
}

extension Movie {
    static func toMP4(from url: URL, to outputURL: URL) async throws {
        let asset = AVAsset(url: url)
        
        let mTracks = try await asset.loadTracks(withMediaType: .video)
        guard !mTracks.isEmpty else { throw Self.exportError }
        let aTracks = try await asset.loadTracks(withMediaType: .audio)
        
        let comp = AVMutableComposition()
        
        guard let nmTrack = comp.addMutableTrack(withMediaType: .video,
                                                 preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Self.exportError }
        
        for mTrack in mTracks {
            guard let timeRange = try? await mTrack.load(.timeRange) else { continue }
            try? nmTrack.insertTimeRange(timeRange, of: mTrack, at: CMTime())
        }
        
        if !aTracks.isEmpty, let naTrack = comp.addMutableTrack(withMediaType: .audio,
                                                                preferredTrackID: kCMPersistentTrackID_Invalid) {
            for aTrack in aTracks {
                guard let timeRange = try? await aTrack.load(.timeRange) else { continue }
                try? naTrack.insertTimeRange(timeRange, of: aTrack, at: CMTime())
            }
        }
        
        guard let session = AVAssetExportSession(asset: comp,
                                                 presetName: AVAssetExportPresetHighestQuality)
        else { throw Self.exportError }
        
        session.outputURL = outputURL
        session.outputFileType = .mp4
        
        try FileManager.default.removeItem(at: url)
        
        await session.export()
        
        switch session.status {
        case .completed: break
        case .failed:
            if let error = session.error {
                throw error
            }
        default: break
        }
    }
}
final class ToMP4MovieEditor: InputKeyEditor, @unchecked Sendable {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    func send(_ event: InputKeyEvent) {
        Task { @MainActor in
            let result = await URL.load(prompt: "Import".localized,
                                        fileTypes: [Movie.FileType.mp4, Movie.FileType.mov])
            switch result {
            case .complete(let ioResult0s):
                let result = await URL.export(name: "",
                                              fileType: Movie.FileType.mp4,
                                              fileSizeHandler: { return nil })
                switch result {
                case .complete(let ioResult1):
                    let fromURL = ioResult0s[0].url
                    let toURL = ioResult1.url
                    Task.detached {
                        do {
                            try await Movie.toMP4(from: fromURL, to: toURL)
                        } catch {
                            Task { @MainActor in
                                self.document.rootNode.show(error)
                            }
                        }
                    }
                case .cancel: break
                }
            case .cancel: break
            }
        }
    }
}

final class MoviePlayer {
    struct MoviePlayerError: Error {}
    static func images(url: URL, handler: (Double, CGImage) -> ()) async throws {
        let asset = AVAsset(url: url)
        
        let reader = try AVAssetReader(asset: asset)
        let vTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = vTracks.first else { throw MoviePlayerError() }
        let fps = Double(try await videoTrack.load(.nominalFrameRate))
        
        let outputSettings = [String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32ARGB)]
        let readerTrackOutput = AVAssetReaderTrackOutput(track: videoTrack,
                                                         outputSettings: outputSettings)
        readerTrackOutput.alwaysCopiesSampleData = false
        readerTrackOutput.supportsRandomAccess = true
        
        reader.add(readerTrackOutput)
        reader.startReading()
        
        var time = 0.0
        while let sampleBuffer = readerTrackOutput.copyNextSampleBuffer() {
            if let pb = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let ciImage = CIImage(cvPixelBuffer: pb)
                let b = CGRect(x: 0, y: 0,
                               width: CVPixelBufferGetWidth(pb),
                               height: CVPixelBufferGetHeight(pb))
                let ctx = CIContext()
                if let cgImage = ctx.createCGImage(ciImage, from: b) {
                    handler(time, cgImage)
                }
            }
            time += 1 / fps
        }
        readerTrackOutput.markConfigurationAsFinal()
        reader.cancelReading()
    }
}
