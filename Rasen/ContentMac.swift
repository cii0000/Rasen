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

import AVFAudio

struct Timeframe: Hashable, Codable {
    var beatRange = 0 ..< Rational(0)
    var localStartBeat = Rational(0)
    var content: Content?
    var score: Score?
    var tempo = Music.defaultTempo
    var isPlaying = false
    var isShownSpectrogram = false
    var id = UUID()
}
extension Timeframe {
    static let defaultBeatDuration = Rational(16)
    static let defaultBeatRange = 0 ..< defaultBeatDuration
}
extension Timeframe: Protobuf {
    init(_ pb: PBTimeframe) throws {
        beatRange = (try? RationalRange(pb.beatRange).value) ?? 0 ..< 0
        if case .content(let content)? = pb.contentOptional {
            self.content = try? Content(content)
        } else {
            content = nil
        }
        if case .score(let score)? = pb.scoreOptional {
            self.score = try? Score(score)
        } else {
            score = nil
        }
        tempo = (try? Rational(pb.tempo))?.clipped(Music.tempoRange) ?? Music.defaultTempo
        localStartBeat = (try? Rational(pb.localStartBeat)) ?? 0
        isShownSpectrogram = pb.isShownSpectrogram
    }
    var pb: PBTimeframe {
        .with {
            $0.beatRange = RationalRange(value: beatRange).pb
            if let content = content {
                $0.contentOptional = .content(content.pb)
            } else {
                $0.contentOptional = nil
            }
            if let score = score {
                $0.scoreOptional = .score(score.pb)
            } else {
                $0.scoreOptional = nil
            }
            $0.tempo = tempo.pb
            $0.localStartBeat = localStartBeat.pb
            $0.isShownSpectrogram = isShownSpectrogram
        }
    }
}
extension Timeframe: TempoContainer {
    var secRange: Range<Rational> {
        secRange(fromBeat: beatRange)
    }
}
extension Timeframe {
    var duration: Rational {
        beatRange.length
    }
    var volume: Volume? {
        get {
            content?.type != .image ? content?.volume ?? score?.volume : nil
        }
        set {
            guard let newValue = newValue else { return }
            if content != nil {
                content?.volume = newValue
            } else {
                score?.volume = newValue
            }
        }
    }
    var pan: Double? {
        get {
            content?.type != .image ? content?.pan ?? score?.pan : nil
        }
        set {
            guard let newValue = newValue else { return }
            if content != nil {
                content?.pan = newValue
            } else {
                score?.pan = newValue
            }
        }
    }
    var reverb: Double? {
        get {
            content?.type != .image ? content?.reverb ?? score?.reverb : nil
        }
        set {
            guard let newValue = newValue else { return }
            if content != nil {
                content?.reverb = newValue
            } else {
                score?.reverb = newValue
            }
        }
    }
    var localBeatRange: Range<Rational>? {
        if let content {
            let beatDur = Timeframe.beat(fromSec: content.secDuration,
                                         tempo: tempo,
                                         beatRate: Keyframe.defaultFrameRate,
                                         rounded: .up)
            return Range(start: localStartBeat,
                         length: beatDur)
        } else if let score {
            var range = score.beatRange
            range?.start += localStartBeat
            return range
        } else {
            return nil
        }
    }
    var isAudio: Bool {
        (content?.type.isAudio ?? false) || score != nil
    }
    var spectrogram: Spectrogram? {
        if let n = content?.spectrogram {
            return n
        } else if let renderedNoneDelayPCMBuffer {
            return Spectrogram.default(renderedNoneDelayPCMBuffer)
        } else {
            return nil
        }
    }
    var renderedNoneDelayPCMBuffer: PCMBuffer? {
        var n = self
        n.beatRange.start = 0
        let seq = Sequencer(timetracks: [.init(timeframes: [(Point(), n)])],
                            isAsync: false, startSec: 0,
                            perceptionDelaySec: 0)
        return try? seq?.buffer(sampleRate: Audio.defaultExportSampleRate,
                                progressHandler: { _, _ in })
    }
    var renderedPCMBuffer: PCMBuffer? {
        var n = self
        n.beatRange.start = 0
        let seq = Sequencer(timetracks: [.init(timeframes: [(Point(), n)])],
                            isAsync: false, startSec: 0)
        return try? seq?.buffer(sampleRate: Audio.defaultExportSampleRate,
                                progressHandler: { _, _ in })
    }
    var pcmBuffer: PCMBuffer? {
        content?.pcmBuffer
    }
}

struct Content: Hashable, Codable {
    enum FileType: FileTypeProtocol, CaseIterable {
        case m4a
        case mp4
        case mov
        case wav
        case mp3
        case aiff
        case png
        case jpeg
        
        var name: String {
            switch self {
            case .mp4: "MP4"
            case .mov: "MOV"
            case .m4a: "M4A"
            case .mp3: "MP3"
            case .wav: "WAV"
            case .aiff: "AIFF"
            case .png: "PNG"
            case .jpeg: "JPEG"
            }
        }
        var utType: UTType {
            switch self {
            case .mp4: .init(filenameExtension: "mp4")!
            case .mov: .init(filenameExtension: "mov")!
            case .m4a: .init(filenameExtension: "m4a")!
            case .mp3: .init(filenameExtension: "mp3")!
            case .wav: .init(filenameExtension: "wav")!
            case .aiff: .init(filenameExtension: "aiff")!
            case .png: .init(filenameExtension: "png")!
            case .jpeg: .init(filenameExtension: "jpg")!
            }
        }
    }
    
    enum ContentType: Int, Hashable, Codable, CaseIterable {
        case movie, sound, image, none
        
        var isAudio: Bool {
            self == .movie || self == .sound
        }
        var isDuration: Bool {
            self == .movie || self == .sound
        }
    }
    static func type(from url: URL) -> ContentType {
        switch url.pathExtension {
        case "mp4", "mov", "MP4", "MOV": .movie
        case "wav", "m4a", "mp3", "aiff",
            "WAV", "M4A", "MP3", "AIFF": .sound
        case "png", "jpeg", "jpg", "tiff", "heif", "heic", "PNG", "JPEG", "JPG", "TIFF", "HEIF", "HEIC": .image
        default: .none
        }
    }
    
    var volume = Volume(smp: 1)
    var pan = 0.0
    var reverb = 0.0
    
    let name: String
    let url: URL
    let type: ContentType
    let secDuration: Double
    let volumeValues: [Double]
    let image: Image?
    
    init(name: String, volume: Volume = Volume(smp: 1),
         pan: Double = 0, reverb: Double = 0) {
        
        self.volume = volume
        self.pan = pan
        self.reverb = reverb
        
        self.name = name
        url = URL.contents.appending(component: name)
        type = Self.type(from: url)
        secDuration = type.isDuration ? Self.duration(from: url) : 0
        volumeValues = type.isDuration ?
            (try? Content.volumeValues(url: url)) ?? [] : []
        image = Image(url: url)
        if type.isDuration, let lufs = integratedLoudness, lufs > -14 {
            let gain = Loudness.normalizeLoudnessScale(inputLoudness: lufs,
                                                       targetLoudness: -14)
            self.volume.amp *= gain
        }
    }
    static let volumeFrameRate = Rational(Keyframe.defaultFrameRate)
    static func volumeValues(fps: Rational = volumeFrameRate,
                             url: URL) throws -> [Double] {
        let buffer = try AVAudioPCMBuffer.from(url: url)
        let volumeFrameCount = Int(buffer.sampleRate / Double(fps))
        let count = buffer.frameCount / volumeFrameCount
        var volumeValues = [Double]()
        volumeValues.reserveCapacity(count)
        let hvfc = volumeFrameCount / 2, frameCount = buffer.frameCount
        for i in stride(from: 0, to: frameCount, by: volumeFrameCount) {
            var x: Float = 0.0
            for j in (i - hvfc) ..< (i + hvfc) {
                if j >= 0 && j < frameCount {
                    for ci in 0 ..< buffer.channelCount {
                        x = max(x, abs(buffer[ci, j]))
                    }
                }
            }
            volumeValues.append(Volume(amp: Double(x)).smp
                .clipped(min: 0, max: 1))
        }
        return volumeValues
    }
    static func duration(from url: URL) -> Double {
        if let file = try? AVAudioFile(forReading: url,
                                       commonFormat: .pcmFormatFloat32,
                                       interleaved: false) {
            Double(file.length) / file.fileFormat.sampleRate
        } else {
            0
        }
    }
    
    var pcmBuffer: PCMBuffer? {
        try? AVAudioPCMBuffer.from(url: url)
    }
    var spectrogram: Spectrogram? {
        guard let buffer = try? AVAudioPCMBuffer.from(url: url) else { return nil }
        return Spectrogram.default(buffer)
    }
    var samplePeakDb: Double? {
        guard let buffer = try? AVAudioPCMBuffer.from(url: url) else { return nil }
        return buffer.samplePeakDb
    }
    var integratedLoudness: Double? {
        guard let buffer = try? AVAudioPCMBuffer.from(url: url) else { return nil }
        return buffer.integratedLoudness
    }
}
extension Content: Protobuf {
    init(_ pb: PBContent) throws {
        volume = .init(amp: ((try? pb.volumeAmp.notNaN()) ?? 1)
            .clipped(min: 0, max: Volume.maxAmp))
        pan = pb.pan.clipped(min: -1, max: 1)
        reverb = pb.reverb.clipped(min: 0, max: 1)
        
        name = pb.name
        url = URL.contents.appending(component: name)
        type = Content.type(from: url)
        secDuration = type.isDuration ? Content.duration(from: url) : 0
        volumeValues = type.isDuration ? ((try? Content.volumeValues(url: url)) ?? []) : []
        image = type == .image ? Image(url: url) : nil
    }
    var pb: PBContent {
        .with {
            $0.name = name
            $0.volumeAmp = volume.amp
            $0.pan = pan
            $0.reverb = reverb
        }
    }
}

final class ContentPlayer {
    var content: Content
    private let player: AVAudioPlayer
    init(_ content: Content) throws {
        self.content = content
        
        player = try AVAudioPlayer(contentsOf: content.url)
        if content.volume.amp != 1 {
            player.volume = Float(content.volume.amp)
        }
    }
    deinit {
        player.stop()
    }
    func play() {
        player.play()
    }
    func stop() {
        player.stop()
    }
    func play(atStartTime startTime: Rational, contentTime: Rational) {
        self.startTime = startTime
        self.contentTime = contentTime
        self.time = Double(contentTime)
        if startTime == 0 {
            player.play()
        } else {
            player.play(atTime: player.deviceCurrentTime + Double(startTime))
        }
    }
    var time: Double {
        get { player.currentTime }
        set { player.currentTime = newValue }
    }
    var startTime = Rational(0), contentTime = Rational(0)
}
