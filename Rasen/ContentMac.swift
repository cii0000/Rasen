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

struct ContentTimeOption: Codable, Hashable, BeatRangeType {
    var beatRange = 0 ..< Rational(0)
    var localStartBeat = Rational(0)
    var tempo = Music.defaultTempo
}
extension ContentTimeOption: Protobuf {
    init(_ pb: PBContentTimeOption) throws {
        beatRange = (try? RationalRange(pb.beatRange).value) ?? 0 ..< 0
        localStartBeat = (try? Rational(pb.localStartBeat)) ?? 0
        tempo = (try? Rational(pb.tempo))?.clipped(Music.tempoRange) ?? Music.defaultTempo
    }
    var pb: PBContentTimeOption {
        .with {
            $0.beatRange = RationalRange(value: beatRange).pb
            if localStartBeat != 0 {
                $0.localStartBeat = localStartBeat.pb
            }
            if tempo != Music.defaultTempo {
                $0.tempo = tempo.pb
            }
        }
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
        var displayName: String {
            switch self {
            case .movie: "Movie".localized
            case .sound: "Sound".localized
            case .image: "Image".localized
            case .none: "None".localized
            }
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
    
    let name: String
    let url: URL
    let type: ContentType
    let durSec: Double
    let volms: [Double]
    let image: Image?
    
    var stereo = Stereo(volm: 1)
    var size = Size(width: 100, height: 100)
    var origin = Point()
    var isShownSpectrogram = false
    var timeOption: ContentTimeOption?
    var id = UUID()
    
    init(name: String = "empty", stereo: Stereo = .init(volm: 1, pan: 0),
         size: Size = Size(width: 100, height: 100), origin: Point = Point(),
         isShownSpectrogram: Bool = false, timeOption: ContentTimeOption? = nil) {
        self.name = name
        url = URL.contents.appending(component: name)
        type = Self.type(from: url)
        durSec = type.isDuration ? Self.duration(from: url) : 0
        volms = type.isDuration ?
        (try? Content.volms(url: url)) ?? [] : []
        image = Image(url: url)
        
        self.stereo = stereo
        self.size = size
        self.origin = origin
        self.isShownSpectrogram = isShownSpectrogram
        self.timeOption = timeOption
        
        if type.isDuration, let lufs = integratedLoudness, lufs > -14 {
            let gain = Loudness.normalizeLoudnessScale(inputLoudness: lufs,
                                                       targetLoudness: -14)
            self.stereo.volm = Volm.volm(fromAmp: Volm.amp(fromVolm: stereo.volm) * gain)
        }
    }
    static let volmFrameRate = Rational(Keyframe.defaultFrameRate)
    static func volms(fps: Rational = volmFrameRate, url: URL) throws -> [Double] {
        let buffer = try AVAudioPCMBuffer.from(url: url)
        let volmFrameCount = Int(buffer.sampleRate / Double(fps))
        let count = buffer.frameCount / volmFrameCount
        var volms = [Double]()
        volms.reserveCapacity(count)
        let hvfc = volmFrameCount / 2, frameCount = buffer.frameCount
        for i in stride(from: 0, to: frameCount, by: volmFrameCount) {
            var x: Float = 0.0
            for j in (i - hvfc) ..< (i + hvfc) {
                if j >= 0 && j < frameCount {
                    for ci in 0 ..< buffer.channelCount {
                        x = max(x, abs(buffer[ci, j]))
                    }
                }
            }
            volms.append(Volm.volm(fromAmp: Double(x)).clipped(min: 0, max: 1))
        }
        return volms
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
}
extension Content {
    var localBeatRange: Range<Rational>? {
        if let timeOption {
            let durBeat = ContentTimeOption.beat(fromSec: durSec,
                                                 tempo: timeOption.tempo,
                                                 beatRate: Keyframe.defaultFrameRate,
                                                 rounded: .up)
            return Range(start: timeOption.localStartBeat, length: durBeat)
        } else {
            return nil
        }
    }
    
    var imageFrame: Rect? {
        if type == .image {
            Rect(origin: origin, size: size)
        } else {
            nil
        }
    }
    
    var pcmBuffer: PCMBuffer? {
        try? AVAudioPCMBuffer.from(url: url)
    }
    var spectrogram: Spectrogram? {
        guard let buffer = try? AVAudioPCMBuffer.from(url: url) else { return nil }
        return .init(buffer)
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
        name = pb.name
        url = URL.contents.appending(component: name)
        type = Content.type(from: url)
        durSec = type.isDuration ? Content.duration(from: url) : 0
        volms = type.isDuration ? ((try? Content.volms(url: url)) ?? []) : []
        image = type == .image ? Image(url: url) : nil
        
        stereo = (try? .init(pb.stereo)) ?? .init(volm: 1)
        size = (try? .init(pb.size)) ?? .init(width: 100, height: 100)
        origin = (try? .init(pb.origin)) ?? .init()
        isShownSpectrogram = pb.isShownSpectrogram
        self.timeOption = if case .timeOption(let timeOption)? = pb.contentTimeOptionOptional {
            try? .init(timeOption)
        } else {
            nil
        }
        id = (try? .init(pb.id)) ?? .init()
    }
    var pb: PBContent {
        .with {
            $0.name = name
            $0.stereo = stereo.pb
            $0.size = size.pb
            $0.origin = origin.pb
            $0.isShownSpectrogram = isShownSpectrogram
            $0.contentTimeOptionOptional = if let timeOption {
                .timeOption(timeOption.pb)
            } else {
                nil
            }
            $0.id = id.pb
        }
    }
}

final class ContentPlayer {
    var content: Content
    private let player: AVAudioPlayer
    init(_ content: Content) throws {
        self.content = content
        
        player = try AVAudioPlayer(contentsOf: content.url)
        if content.stereo.volm != 1 {
            player.volume = Float(Volm.amp(fromVolm: content.stereo.volm))
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
