// Copyright 2023 Cii
//
// This file is part of Shikishi.
//
// Shikishi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shikishi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shikishi.  If not, see <http://www.gnu.org/licenses/>.

import AVFAudio

final class OtherVoiceGenerator {
    static var sharedEngineURL: URL?
    struct SongGeneratorError: Error {}
    static func generate(engineURL: URL, voiceName: String,
                         timetracks: [Timetrack],
                         startTimetrackIndex: Int) throws -> Data {
        guard !timetracks.isEmpty,
              startTimetrackIndex < timetracks.count else { throw SongGeneratorError() }
        let xmlURL = engineURL.appendingPathComponent("song.musicxml")
        
        let emptyTimetrack = Timetrack(timeframes: [.init(beatRange: 0 ..< 4)])
        let lyrics = try Lyrics(timetracks: [emptyTimetrack] + timetracks + [emptyTimetrack])
        try lyrics.write(to: xmlURL)
        
        let tshURL = engineURL.appendingPathComponent("RunTiming.sh")
        let tprocess = Process()
        tprocess.executableURL = URL(fileURLWithPath: "/bin/sh")
        tprocess.arguments = [tshURL.path]
        try tprocess.run()
        tprocess.waitUntilExit()
        
        var nts = [(latin: String, dt: Int)](), t: Rational = 0
        for timetrack in timetracks {
            for timeframe in timetrack.timeframes {
                guard let score = timeframe.score,
                      !score.notes.isEmpty else { continue }
                func noteDeltaTime(from note: Note) -> Int {
                    let tr = score.convertPitchToWorld(note).beatRange
                    let t = tr.start
                    let nt = tr.start.interval(scale: Rational(1, 16))
                    return Int(timeframe.sec(fromBeat: nt - t) * 10000000)
                }
                let nNotes = score.notes.sorted(by: { $0.beatRange.start < $1.beatRange.start })
                if nNotes[0].beatRange.start > 0 {
                    nts.append(("pau", 0))
                }
                for (i, note) in nNotes.enumerated() {
                    if i > 0 && nNotes[i - 1].beatRange.end < note.beatRange.start {
                        nts.append(("pau", 0))
                    }
                    
                    var latin = note.lyric.applyingTransform(.latinToHiragana, reverse: true) ?? ""
                    var isLastN = false
                    if latin.last == "n" {
                        isLastN = true
                        latin.removeLast()
                    }
                    if latin == "n" {
                        latin = "N"
                    }
                    
                    if latin == "vu~a" {
                        latin = "va"
                    } else if latin == "vu~i" {
                        latin = "vi"
                    } else if latin == "vu~e" {
                        latin = "ve"
                    } else if latin == "vu~o" {
                        latin = "vo"
                    }
                    
                    let ndt = noteDeltaTime(from: note)
                    if let lastC = latin.last,
                       "aiueo".contains(lastC) {
                        
                        if latin.count > 1 {
                            latin.removeLast()
                            nts.append((latin, ndt))
                        }
                        
                        nts.append((String(lastC), ndt))
                    }
                    
                    if isLastN {
                        nts.append(("N", ndt))
                    }
                    
                    if note.isBreath {
                        nts.append(("br", 0))
                    }
                }
                if nNotes[.last].beatRange.end < timeframe.beatRange.end {
                    nts.append(("pau", 0))
                }
            }
            t += timetrack.secDuration
        }
        
        let timingURL = engineURL.appendingPathComponent("score/label/timing/song.lab")
        if let timingsStr = String(bytes: try Data(contentsOf: timingURL),
                                   encoding: .utf8) {
            var nLatins = [(latin: String, startT: Int, endT: Int)]()
            
            for line in timingsStr.lines {
                let vs = line.split(separator: " ")
                let startT = Int(vs[0]) ?? 0
                let endT = Int(vs[1]) ?? 0
                let latin = String(vs[2])
                
                nLatins.append((latin, startT, endT))
            }
            
            if nts.map({ $0.latin }) == nLatins.map({ $0.latin }) {
                for i in 0 ..< nLatins.count {
                    let ntsL = nts[i]
                    
                    nLatins[i].startT += ntsL.dt
                    if !"aiueoN".contains(ntsL.latin.last!) {
                        nLatins[i].endT += ntsL.dt
                    }
                }
                
                var nnts = ""
                for (latin, startT, endT) in nLatins {
                    nnts += "\(startT) \(endT) \(latin)"
                    nnts += "\n"
                }
                
                try nnts.write(to: engineURL.appendingPathComponent("timing.lab"), atomically: true,
                               encoding: .utf8)
            } else {
                try timingsStr.write(to: engineURL.appendingPathComponent("timing.lab"), atomically: true,
                                     encoding: .utf8)
            }
        }
        
        let shURL = engineURL.appendingPathComponent("Run\(voiceName).sh")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [shURL.path]
        try process.run()
        process.waitUntilExit()
        
        let wavURL = engineURL.appendingPathComponent("song.wav")
        let file = try AVAudioFile(forReading: wavURL)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)) else { throw SongGeneratorError() }
        try file.read(into: buffer)
        
        let nBuffer = try buffer.convertDefaultFormat()
        var sst = emptyTimetrack.secDuration, isChangedVolume = false
        var volumes = [Rational: (dt: Rational, v: Double)]()
        var vibratos = [Rational: (dt: Rational, v: Double, tempo: Rational)]()
        volumes[0] = (0, 1)
        vibratos[0] = (0, 0.01, 120)
        for timetrack in timetracks {
            for timeframe in timetrack.timeframes {
                let dt = timeframe.sec(fromBeat: Rational(1, 16))
                guard let score = timeframe.score else { continue }
                for note in score.notes {
                    let t = note.beatRange.start + timeframe.beatRange.start
                    let time = timeframe.sec(fromBeat: t) + sst
                    let defaultVolumeAmp = 90.0 / 127.0
                    let volume = (note.volumeAmp / defaultVolumeAmp).clipped(min: 0, max: 1.5)
                    if note.volumeAmp != defaultVolumeAmp {
                        isChangedVolume = true
                    }
                    volumes[time] = (dt, volume)
                    
                    if note.isVibrato {
                        vibratos[time] = (dt, 0.04, timeframe.tempo)
                    } else {
                        vibratos[time] = (dt, 0, timeframe.tempo)
                    }
                }
            }
            
            sst += timetrack.secDuration
        }
        volumes[sst] = (0, 1)
        vibratos[sst] = (0, 0.01, 120)
        
        if isChangedVolume {
            let vs = volumes.sorted(by: { $0.key < $1.key })
            var preV = vs[0].value.v, preI = 0, preDT: Rational = 0
            for v in vs {
                let nextI = Int(Double(v.key) * nBuffer.sampleRate)
                let nextDI = Int(Double(v.key - preDT) * nBuffer.sampleRate)
                for i in preI ..< nextI {
                    guard i < nBuffer.frameCount else { break }
                    let t = i < nextDI || nextDI >= nextI ?
                        0 :
                        Double(i - nextDI) / Double(nextI - nextDI)
                    let nv = Float(Double.linear(preV, v.value.v, t: t))
                    for ci in 0 ..< nBuffer.channelCount {
                        nBuffer[ci, i] *= nv
                    }
                }
                preI = nextI
                preV = v.value.v
                preDT = v.value.dt
            }
        }
        
        if let oldBuffer = nBuffer.copy() as? AVAudioPCMBuffer {
            var phase = 0.0
            let rSampleRate = 1 / oldBuffer.sampleRate
            let count = oldBuffer.frameCount

            let vs = vibratos.sorted(by: { $0.key < $1.key })
            var preV = vs[0].value.v, preI = 0, preDT: Rational = 0
            for v in vs {
                let nextI = Int(Double(v.key) * nBuffer.sampleRate)
                let nextDI = Int(Double(v.key - preDT) * nBuffer.sampleRate)
                for i in preI ..< nextI {
                    guard i < nBuffer.frameCount else { break }
                    for ci in 0 ..< nBuffer.channelCount {
                        if phase.isInteger {
                            nBuffer[ci, i] = oldBuffer[ci, Int(phase)]
                        } else {
                            let sai = Int(phase)
                            let a0 = oldBuffer[ci, sai - 1 >= 0 ? sai - 1 : count - 1]
                            let a1 = oldBuffer[ci, sai]
                            let a2 = oldBuffer[ci, sai + 1 < count ? sai + 1 : 0]
                            let a3 = oldBuffer[ci, sai + 2 < count ? sai + 2 : 1]
                            let t = phase - Double(sai)
                            nBuffer[ci, i] = Float.spline(a0, a1, a2, a3, t: t)
                                .clipped(min: -1, max: 1)
                        }
                        let t = Double(i) * rSampleRate
                        let vibratoFrenquency = Double(6 * (v.value.tempo / 120))

                        let vibratoAmplitude = nextDI >= nextI || nextDI <= preI || preV == 0.01 ?
                        (nextDI <= preI ? preV : 0.01) :
                        (i < nextDI ?
                         Double.expLinear(0.01, preV,
                                          t: Double(i - preI) / Double(nextDI - preI)) :
                            Double.expLinear(preV, 0.01,
                                             t: Double(i - nextDI) / Double(nextI - nextDI)))
                        let vScale = 2 ** (vibratoAmplitude * sin(t * vibratoFrenquency * 2 * .pi))
                        phase = (phase + vScale).loop(0 ..< Double(count))
                    }
                }
                preI = nextI
                preV = v.value.v
                preDT = v.value.dt
            }
        }
        
        return nBuffer.pcmData
    }
}
