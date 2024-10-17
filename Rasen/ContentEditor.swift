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

@globalActor actor MovieActor: GlobalActor {
    static let shared = MovieActor()
}

final class ContentSlider: DragEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    enum SlideType {
        case all, startBeat, endBeat, isShownSpectrogram, movie
    }
    
    private var contentView: SheetContentView? {
        guard let sheetView, let contentI,
              contentI < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentI]
    }
    private var beganContentBeat: Rational = 0, oldContentBeat: Rational = 0
    private let indexInterval = 10.0
    private var oldDeltaI: Int?
    
    private var sheetView: SheetView?, contentI: Int?, beganContent: Content?
    private var type = SlideType.all
    private var beganSP = Point(), beganInP = Point(), beganContentEndP = Point()
    
    private var beganIsShownSpectrogram = false
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            var cursor = Cursor.arrow
            
            if let sheetView = document.sheetView(at: p),
                let ci = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                scale: document.screenToWorldScale) {
                
                let sheetP = sheetView.convertFromWorld(p)
                let contentView = sheetView.contentsView.elementViews[ci]
                let content = contentView.model
                let contentP = contentView.convertFromWorld(p)
                
                beganSP = sp
                beganInP = sheetP
                self.sheetView = sheetView
                beganContent = content
                if let timeOption = content.timeOption {
                    beganContentEndP = .init(sheetView.animationView.x(atBeat: timeOption.beatRange.end), content.origin.y)
                }
                contentI = ci
                
                let maxMD = 10 * document.screenToWorldScale
                
                if contentView.containsIsShownSpectrogram(contentP, scale: document.screenToWorldScale) {
                    type = .isShownSpectrogram
                    beganIsShownSpectrogram = contentView.model.isShownSpectrogram
                    contentView.updateSpectrogram()
                } else if let timeOption = content.timeOption {
                    if !contentView.containsTimeline(contentP, scale: document.screenToWorldScale)
                        && contentView.model.type == .movie {
                        type = .movie
                        
                        beganContentBeat = contentView.model.beat
                        oldContentBeat = beganContentBeat
                        cursor = document.cursor(from: contentView.currentTimeString(isInter: true))
                    } else if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.start)) < maxMD {
                        type = .startBeat
                    } else if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.end)) < maxMD {
                        type = .endBeat
                    } else {
                        type = .all
                    }
                }
            }
            document.cursor = cursor
        case .changed:
            if let sheetView, let beganContent,
               let contentI, contentI < sheetView.contentsView.elementViews.count {
                
                let sheetP = sheetView.convertFromWorld(p)
                let contentView = sheetView.contentsView.elementViews[contentI]
                let content = contentView.model
                
                switch type {
                case .all:
                    let nh = ScoreLayout.pitchHeight
                    let np = beganContent.origin + sheetP - beganInP
                    let interval = document.currentBeatInterval
                    let beat = max(min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - (content.timeOption?.beatRange.length ?? 0))
                    var timeOption = content.timeOption
                    timeOption?.beatRange.start = beat
                    let timelineY = np.y.interval(scale: nh)
                        .clipped(min: Sheet.timelineY, max: sheetView.bounds.height - Sheet.timelineY)
                    contentView.set(timeOption, origin: Point(sheetView.animationView.x(atBeat: beat), timelineY))
                    document.updateSelects()
                case .startBeat:
                    if var timeOption = content.timeOption {
                        let np = beganContent.origin + sheetP - beganInP
                        let interval = document.currentBeatInterval
                        let beat = min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.end)
                        if beat != timeOption.beatRange.start {
                            let dBeat = timeOption.beatRange.start - beat
                            if content.type.hasDur {
                                timeOption.localStartBeat += dBeat
                            }
                            timeOption.beatRange.start -= dBeat
                            timeOption.beatRange.length += dBeat
                            contentView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), content.origin.y))
                            document.updateSelects()
                        }
                    }
                case .endBeat:
                    if var timeOption = content.timeOption {
                        let np = beganContentEndP + sheetP - beganInP
                        let interval = document.currentBeatInterval
                        let beat = max(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.start)
                        if beat != timeOption.beatRange.end {
                            timeOption.beatRange.end = beat
                            contentView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), content.origin.y))
                            document.updateSelects()
                        }
                    }
                case .isShownSpectrogram:
                    let contentP = contentView.convertFromWorld(p)
                    let isShownSpectrogram = contentView.isShownSpectrogram(at: contentP)
                    contentView.isShownSpectrogram = isShownSpectrogram
                case .movie:
                    let dp = event.screenPoint - beganSP
                    let deltaI = Int((dp.x / indexInterval).rounded())
                    
                    if deltaI != oldDeltaI {
                        oldDeltaI = deltaI
                        
                        let nBeat = (beganContentBeat + .init(deltaI, 12))
                            .loop(start: 0, end: contentView.model.timeOption?.beatRange.length ?? 0)
                            .interval(scale: .init(1, 12))
                        if nBeat != oldContentBeat {
                            oldContentBeat = nBeat
                            
                            contentView.model.beat = nBeat
                            contentView.updateTimeline()
                            if let sec = contentView.model.rootSec {
                                contentView.updateMovie(atSec: sec)
                            }
                            
                            document.cursor = .circle(string: contentView.currentTimeString(isInter: true))
                        }
                    }
                }
            }
        case .ended:
            if type != .movie, let sheetView, let beganContent,
               let contentI, contentI < sheetView.contentsView.elementViews.count {
               
                let contentView = sheetView.contentsView.elementViews[contentI]
                if contentView.model != beganContent {
                    sheetView.newUndoGroup()
                    sheetView.capture(contentView.model, old: beganContent, at: contentI)
                }
                if type == .all || type == .startBeat || type == .endBeat {
                    sheetView.updatePlaying()
                }
            }
            
            document.cursor = document.defaultCursor
        }
    }
}

struct ContentLayout {
    static let spectrogramX = 10.0, isShownSpectrogramHeight = 6.0
}

final class ContentView<T: BinderProtocol>: SpectrgramView, @unchecked Sendable {
    typealias Model = Content
    typealias Binder = T
    let binder: Binder
    var keyPath: BinderKeyPath
    let node: Node
    
    var isFullEdit = false {
        didSet {
            guard isFullEdit != oldValue else { return }
            if let node = timelineNode.children.first(where: { $0.name == "isFullEdit" }) {
                node.isHidden = !isFullEdit
            }
        }
    }
    
    private var movieTask: Task<(), Never>?
    @MovieActor private var movieImageGenerator: MovieImageGenerator?
    
    let clippingNode = Node(isHidden: true,
                            lineWidth: 4, lineType: .color(.warning))
    
    let timelineNode = Node()
    var spectrogramNode: Node?, spectrogramDeltaX = 0.0
    var spectrogramFqType: Spectrogram.FqType?
    var timeNode: Node?, currentPeakVolmNode: Node?
    var peakVolm = 0.0 {
        didSet {
            guard peakVolm != oldValue else { return }
            updateFromPeakVolm()
        }
    }
    func updateFromPeakVolm() {
        guard model.type != .movie, let node = currentPeakVolmNode, let frame = timelineFrame else { return }
        let y = isShownSpectrogram ? frame.height + Self.spectrogramHeight + ContentLayout.isShownSpectrogramHeight : frame.height
        node.path = Path([Point(), Point(0, y)])
        if peakVolm < Audio.headroomVolm {
            node.lineType = .color(Color(lightness: (1 - peakVolm) * 100))
//            currentPeakVolmNode.lineType = .color(.background)
        } else {
            node.lineType = .color(.warning)
        }
    }
    
    var pcmNoder: PCMNoder?
    var volms = [Double]()
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        if let image = binder[keyPath: keyPath].image,
           let texture = try? Texture(image: image, isOpaque: false, colorSpace: .sRGB) {
            node = Node(children: [timelineNode, clippingNode],
                        attitude: Attitude(position: binder[keyPath: keyPath].origin),
                        path: Path(Rect(origin:binder[keyPath: keyPath].timeOption == nil ?
                            .init() : .init(0, Sheet.timelineHalfHeight + ContentLayout.isShownSpectrogramHeight),
                            size: binder[keyPath: keyPath].size)),
                        fillType: .texture(texture))
        } else if binder[keyPath: keyPath].type == .movie {
            node = Node(children: [timelineNode, clippingNode],
                        attitude: Attitude(position: binder[keyPath: keyPath].origin),
                        path: Path(Rect(origin: .init(0, Sheet.timelineHalfHeight + ContentLayout.isShownSpectrogramHeight),
                                        size: binder[keyPath: keyPath].size)))
        } else {
            node = Node(children: [timelineNode, clippingNode],
                        attitude: Attitude(position: binder[keyPath: keyPath].origin))
        }
        
        if model.type == .sound {
            pcmNoder = .init(content: model)
            volms = pcmNoder?.pcmBuffer.volms() ?? []
        }
        
        updateClippingNode()
        updateTimeline()
        updateSpectrogram()
        
        if model.type == .movie, let sec = model.rootSec {
            updateMovie(atSec: sec)
        }
    }
}
extension ContentView {
    func updateWithModel() {
        node.attitude.position = model.origin
        if let image = model.image,
           let texture = try? Texture(image: image, isOpaque: false, colorSpace: .sRGB) {
            node.fillType = .texture(texture)
            node.path = Path(Rect(size: model.size))
        }
        updateClippingNode()
        updateTimeline()
        if let timeOption = model.timeOption {
            pcmNoder?.change(from: timeOption)
            updateSpectrogram()
        }
    }
    func updateClippingNode() {
        var parent: Node?
        node.allParents { node, stop in
            if node.bounds != nil {
                parent = node
                stop = true
            }
        }
        if let parent,
           let pb = parent.bounds, let b = clippableBounds {
            let edges = convert(pb, from: parent).intersectionEdges(b)
            
            if !edges.isEmpty {
                clippingNode.isHidden = false
                clippingNode.path = .init(edges)
            } else {
                clippingNode.isHidden = true
            }
        } else {
            clippingNode.isHidden = true
        }
    }
    func updateTimeline() {
        if model.timeOption != nil {
            timelineNode.children = self.timelineNode(with: model)
            
            let timeNode = Node(lineWidth: 3, lineType: .color(.content))
            let volmNode = Node(lineWidth: 2, lineType: .color(.background))
            timeNode.append(child: volmNode)
            timelineNode.children.append(timeNode)
            self.timeNode = timeNode
            self.currentPeakVolmNode = volmNode
            
            if model.type == .movie || model.type == .image {
                node.path = .init(Rect(origin: .init(0, Sheet.timelineHalfHeight + ContentLayout.isShownSpectrogramHeight),
                                       size: model.size))
            }
        } else if !timelineNode.children.isEmpty {
            timelineNode.children = []
            self.timeNode = nil
            self.currentPeakVolmNode = nil
            if model.type == .movie || model.type == .image {
                node.path = .init(Rect(size: model.size))
            }
        }
    }
    
    func movePreviousInterKeyframe() {
        guard let timeOption else { return }
        let beat = model.beat, durBeat = timeOption.beatRange.length
        let frameBeat = Rational(1, 12)
        let nBeat = (beat - frameBeat < 0 ? durBeat - frameBeat : beat - frameBeat)
            .interval(scale: frameBeat)
        
        binder[keyPath: keyPath].beat = nBeat
        updateTimeline()
        if model.type == .movie, let sec = model.rootSec {
            updateMovie(atSec: sec)
        }
    }
    func movePreviousKeyframe() {
        guard let timeOption, let frameBeat = model.frameBeat else { return }
        let beat = model.beat, durBeat = timeOption.beatRange.length
        let nBeat = (beat - frameBeat < 0 ? durBeat - frameBeat : beat - frameBeat)
            .interval(scale: frameBeat)
        
        binder[keyPath: keyPath].beat = nBeat
        updateTimeline()
        if model.type == .movie, let sec = model.rootSec {
            updateMovie(atSec: sec)
        }
    }
    
    func moveNextInterKeyframe() {
        guard let timeOption else { return }
        let beat = model.beat, durBeat = timeOption.beatRange.length
        let frameBeat = Rational(1, 12)
        let nBeat = (beat + frameBeat >= durBeat ? 0 : beat + frameBeat).interval(scale: frameBeat)
        
        binder[keyPath: keyPath].beat = nBeat
        updateTimeline()
        if model.type == .movie, let sec = model.rootSec {
            updateMovie(atSec: sec)
        }
    }
    func moveNextKeyframe() {
        guard let timeOption, let frameBeat = model.frameBeat else { return }
        let beat = model.beat, durBeat = timeOption.beatRange.length
        let nBeat = (beat + frameBeat >= durBeat ? 0 : beat + frameBeat).interval(scale: frameBeat)
        
        binder[keyPath: keyPath].beat = nBeat
        updateTimeline()
        if model.type == .movie, let sec = model.rootSec {
            updateMovie(atSec: sec)
        }
    }
    
    var beat: Rational {
        get { model.beat }
        set {
            binder[keyPath: keyPath].beat = newValue
            updateTimeline()
            
            if model.type == .movie, let sec = model.rootSec {
                updateMovie(atSec: sec)
            }
        }
    }
    func updateMovie(atSec sec: Rational) {
        let url = model.url
        
        movieTask?.cancel()
        movieTask = Task { @MovieActor in
            let movieImageGenerator: MovieImageGenerator
            if let aMovieImageGenerator = self.movieImageGenerator {
                movieImageGenerator = aMovieImageGenerator
            } else {
                movieImageGenerator = MovieImageGenerator(url: url)
                self.movieImageGenerator = movieImageGenerator
            }
            
            guard let image = try? await movieImageGenerator.thumbnail(atSec: sec) else { return }
            
            Task { @MainActor in
                if let texture = try? Texture(image: image, isOpaque: false, colorSpace: .sRGB,
                                              isBGR: true) {
                    try Task.checkCancellation()
                    self.node.fillType = .texture(texture)
                }
            }
        }
    }
    
    func currentTimeString(isInter: Bool) -> String {
        Animation.timeString(fromTime: model.beat,
                             frameRate: isInter ? 12 : model.frameRateBeat ?? 1)
    }
    
    func set(_ timeOption: ContentTimeOption?, origin: Point) {
        binder[keyPath: keyPath].timeOption = timeOption
        binder[keyPath: keyPath].origin = origin
        node.attitude.position = origin
        updateTimeline()
        updateClippingNode()
        if let timeOption = model.timeOption {
            pcmNoder?.change(from: timeOption)
            
            spectrogramNode?.attitude.position.x
            = x(atBeat: timeOption.beatRange.start + timeOption.localStartBeat) + spectrogramDeltaX
        }
    }
    var timeOption: ContentTimeOption? {
        get { model.timeOption }
        set {
            binder[keyPath: keyPath].timeOption = newValue
            updateTimeline()
            updateClippingNode()
            if let timeOption = model.timeOption {
                pcmNoder?.change(from: timeOption)
                
                spectrogramNode?.attitude.position.x
                = x(atBeat: timeOption.beatRange.start + timeOption.localStartBeat) + spectrogramDeltaX
            }
        }
    }
    var origin: Point {
        get { model.origin }
        set {
            binder[keyPath: keyPath].origin = newValue
            node.attitude.position = newValue
            updateClippingNode()
        }
    }
    var stereo: Stereo {
        get { model.stereo }
        set {
            binder[keyPath: keyPath].stereo = newValue
            updateTimeline()
            pcmNoder?.stereo = newValue
        }
    }
    
    var imageFrame: Rect? {
        if let f = model.imageFrame {
            f + Point(0,
                      model.timeOption == nil ?
                      0 : Sheet.timelineHalfHeight + ContentLayout.isShownSpectrogramHeight)
        } else {
            nil
        }
    }
    
    var frameRate: Int { Keyframe.defaultFrameRate }
    
    var tempo: Rational {
        get { model.timeOption?.tempo ?? 0 }
        set {
            binder[keyPath: keyPath].timeOption?.tempo = newValue
            updateTimeline()
            
//            if let spctrogram {
//                let allBeat = content.localBeatRange?.length ?? 0
//                let allW = width(atDurBeat: allBeat)
//            }
        }
    }
    
    var timelineCenterY: Double {
        model.type.hasDur ? 0 : -Sheet.timelineHalfHeight
    }
    var beatRange: Range<Rational>? {
        model.timeOption?.beatRange
    }
    var localBeatRange: Range<Rational>? {
        model.localBeatRange
    }
    
    var spectrgramY: Double {
        timelineFrame?.maxY ?? 0
    }
    
    var pcmBuffer: PCMBuffer? {
        pcmNoder?.pcmBuffer
    }
    
    func timelineNode(with content: Content) -> [Node] {
        guard let timeOption = content.timeOption else { return [] }
        let sBeat = max(timeOption.beatRange.start, -10000),
            eBeat = min(timeOption.beatRange.end, 10000)
        guard sBeat <= eBeat else { return [] }
        let sx = self.x(atBeat: sBeat)
        let ex = self.x(atBeat: eBeat)
        
        let lw = 1.0
        let noteHeight = ScoreLayout.noteHeight
        let knobW = Sheet.knobWidth, knobH = Sheet.knobHeight
        let rulerH = Sheet.rulerHeight
        let timelineHalfHeight = Sheet.timelineHalfHeight
        let centerY = content.type.hasDur ? 0 : -timelineHalfHeight
        let sy = centerY - timelineHalfHeight
        let ey = centerY + timelineHalfHeight
        
        var textNodes = [Node]()
        var contentPathlines = [Pathline]()
        var subBorderPathlines = [Pathline]()
        var fullEditBorderPathlines = [Pathline]()
        var borderPathlines = [Pathline]()
        var noteLineNodes = [Node]()
        
        if let localBeatRange = content.localBeatRange {
            if localBeatRange.start < 0 {
                let beat = -min(localBeatRange.start, 0)
                - min(timeOption.beatRange.start, 0)
                let timeText = Text(string: Animation.timeString(fromTime: beat, frameRate: 12),
                                    size: Font.smallSize)
                let timeP = Point(sx + 1, centerY + timeText.size / 2 + 1)
                textNodes.append(Node(attitude: Attitude(position: timeP),
                                      path: Path(timeText.typesetter, isPolygon: false),
                                      fillType: .color(.content)))
            } else if localBeatRange.start > 0 {
                let ssx = x(atBeat: localBeatRange.start + timeOption.beatRange.start)
                contentPathlines.append(Pathline(Rect(x: ssx - 1 / 4, y: centerY - 3,
                                                      width: 1 / 2, height: 6)))
            }
        }
        
        if let localBeatRange = content.localBeatRange {
            if timeOption.beatRange.start + localBeatRange.end > timeOption.beatRange.end {
                let beat = timeOption.beatRange.length - localBeatRange.start
                
                let timeText = Text(string: Animation.timeString(fromTime: beat, frameRate: 12),
                                    size: Font.smallSize)
                let timeFrame = timeText.frame ?? Rect()
                let timeP = Point(ex - timeFrame.width - 2, centerY + timeText.size / 2 + 1)
                textNodes.append(Node(attitude: Attitude(position: timeP),
                                      path: Path(timeText.typesetter,
                                                 isPolygon: false),
                                      fillType: .color(.content)))
            } else if localBeatRange.end < timeOption.beatRange.length {
                let ssx = x(atBeat: localBeatRange.end + timeOption.beatRange.start)
                contentPathlines.append(Pathline(Rect(x: ssx - 1 / 4, y: centerY - 3,
                                                      width: 1 / 2, height: 6)))
            }
        }
        
        if !volms.isEmpty {
            let sSec = timeOption.sec(fromBeat: max(-timeOption.localStartBeat, 0))
            let msSec = timeOption.sec(fromBeat: timeOption.localStartBeat)
            let csSec = timeOption.sec(fromBeat: timeOption.beatRange.start)
            let durBeat = ContentTimeOption.beat(fromSec: content.durSec, tempo: timeOption.tempo)
            let eSec = timeOption
                .sec(fromBeat: min(timeOption.beatRange.end - (timeOption.localStartBeat + timeOption.beatRange.start),
                                   durBeat))
            let si = Int((sSec * PCMBuffer.volmFrameRate).rounded())
                .clipped(min: 0, max: volms.count - 1)
            let msi = Int((msSec * PCMBuffer.volmFrameRate).rounded())
            let ei = Int((eSec * PCMBuffer.volmFrameRate).rounded())
                .clipped(min: 0, max: volms.count - 1)
            let vt = content.stereo.volm
                .clipped(min: Volm.minVolm, max: Volm.maxVolm,
                         newMin: lw / noteHeight, newMax: 1)
            if si < ei {
                let line = Line(controls: (si ... ei).map { i in
                    let sec = Rational(i + msi) / PCMBuffer.volmFrameRate + csSec
                    return .init(point: .init(x(atSec: sec), centerY),
                                 pressure: volms[i] * vt)
                })
                
                let pan = content.stereo.pan
                let color = Self.panColor(pan: pan, brightness: 0.25)
                noteLineNodes += [Node(path: .init(line),
                                       lineWidth: noteHeight,
                                       lineType: .color(color))]
            }
        }
        
        contentPathlines.append(.init(Rect(x: sx - 1, y: centerY - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: ex - 1, y: centerY - knobH / 2,
                                           width: knobW, height: knobH)))
        contentPathlines.append(.init(Rect(x: sx + 1, y: centerY - lw / 2,
                                           width: ex - sx - 2, height: lw)))
        
        makeBeatPathlines(in: timeOption.beatRange, sy: sy, ey: ey,
                          subBorderPathlines: &subBorderPathlines,
                          fullEditBorderPathlines: &fullEditBorderPathlines,
                          borderPathlines: &borderPathlines)
        
        if content.type.isAudio {
            if content.isShownSpectrogram {
                makeBeatPathlines(in: timeOption.beatRange, sy: ey + ContentLayout.isShownSpectrogramHeight, ey: ey + ContentLayout.isShownSpectrogramHeight + Self.spectrogramHeight,
                                  subBorderPathlines: &subBorderPathlines,
                                  fullEditBorderPathlines: &fullEditBorderPathlines,
                                  borderPathlines: &borderPathlines)
            }
            
            let sprH = ContentLayout.isShownSpectrogramHeight
            let sprKnobW = knobH, sprKbobH = knobW
            let np = Point(ContentLayout.spectrogramX + sx, ey)
            contentPathlines.append(Pathline(Rect(x: np.x - 1 / 2,
                                                  y: np.y + 1,
                                                  width: 1,
                                                  height: sprH - 2)))
            if content.isShownSpectrogram {
                contentPathlines.append(Pathline(Rect(x: np.x - sprKnobW / 2,
                                                      y: np.y + sprH - 1 - sprKbobH / 2,
                                                      width: sprKnobW,
                                                      height: sprKbobH)))
            } else {
                contentPathlines.append(Pathline(Rect(x: np.x - sprKnobW / 2,
                                                      y: np.y + 1 - sprKbobH / 2,
                                                      width: sprKnobW,
                                                      height: sprKbobH)))
            }
        }
        
        if model.type == .movie {
            let mainBeatX = self.x(atBeat: model.beat + timeOption.beatRange.start)
            let d = model.beat == 0 ? knobH / 2 : lw / 2
            contentPathlines.append(.init(Rect(x: mainBeatX - lw / 2,
                                               y: sy,
                                               width: lw,
                                               height: (centerY - d - knobW) - sy)))
            contentPathlines.append(.init(Rect(x: mainBeatX - lw * 3,
                                               y: sy - lw,
                                               width: lw * 6,
                                               height: lw)))
            contentPathlines.append(.init(Rect(x: mainBeatX - lw / 2,
                                               y: centerY + d + knobW,
                                               width: lw,
                                               height: ey - (centerY + d + knobW))))
            contentPathlines.append(.init(Rect(x: mainBeatX - lw * 3,
                                               y: ey,
                                               width: lw * 6,
                                               height: lw)))
        }
        
        let secRange = timeOption.secRange
        for sec in Int(secRange.start.rounded(.up)) ..< Int(secRange.end.rounded(.up)) {
            let sec = Rational(sec)
            guard secRange.contains(sec) else { continue }
            let secX = x(atSec: sec)
            contentPathlines.append(.init(Rect(x: secX - lw / 2, y: sy - rulerH / 2,
                                               width: lw, height: rulerH)))
        }
        
        var nodes = [Node]()
        
        if !fullEditBorderPathlines.isEmpty {
            nodes.append(Node(name: "isFullEdit",
                              isHidden: !isFullEdit,
                              path: Path(fullEditBorderPathlines),
                              fillType: .color(.border)))
        }
        if !borderPathlines.isEmpty {
            nodes.append(Node(path: Path(borderPathlines),
                              fillType: .color(.border)))
        }
        if !subBorderPathlines.isEmpty {
            nodes.append(Node(path: Path(subBorderPathlines),
                              fillType: .color(.subBorder)))
        }
        nodes += noteLineNodes
        if !contentPathlines.isEmpty {
            nodes.append(Node(path: Path(contentPathlines),
                              fillType: .color(.content)))
        }
        nodes += textNodes
        
        return nodes
    }
    
    static func panColor(pan: Double, brightness l: Double) -> Color {
        pan == 0 ?
        Color(red: l, green: l, blue: l) :
            (pan > 0 ?
             Color(red: pan * Spectrogram.editRedRatio * (1 - l) + l, green: l, blue: l) :
                Color(red: l, green: -pan * Spectrogram.editGreenRatio * (1 - l) + l, blue: l))
    }
    
    static var spectrogramHeight: Double {
        ScoreLayout.pitchHeight * (Score.doubleMaxPitch - Score.doubleMinPitch)
    }
    func updateSpectrogram() {
        spectrogramNode?.removeFromParent()
        spectrogramNode = nil
        
        let content = model
        guard content.isShownSpectrogram, let timeOption = content.timeOption,
              let contentSecRange = content.contentSecRange,
              let sm = pcmNoder?.spectrogram(fromSecRange: .init(contentSecRange)) else { return }
        
        let firstX = x(atBeat: timeOption.beatRange.start + max(timeOption.localStartBeat, 0))
        spectrogramDeltaX = width(atDurBeat: -min(timeOption.localStartBeat, 0))
        let y = timelineCenterY + Sheet.timelineHalfHeight + ContentLayout.isShownSpectrogramHeight
        let allW = width(atDurSec: contentSecRange.length)
        var nodes = [Node](), maxH = 0.0
        func spNode(width: Int, at xi: Int) -> Node? {
            guard let image = sm.image(width: width, at: xi),
                  let texture = try? Texture(image: image, isOpaque: false, colorSpace: .sRGB) else { return nil }
            let w = allW * Double(width) / Double(sm.frames.count)
            let h = Self.spectrogramHeight
            maxH = max(maxH, h)
            let x = allW * Double(xi) / Double(sm.frames.count)
            return Node(name: "spectrogram",
                        attitude: .init(position: .init(x, 0)),
                        path: Path(Rect(width: w, height: h)),
                        fillType: .texture(texture))
        }
        (0 ..< (sm.frames.count / 1024)).forEach { xi in
            if let node = spNode(width: 1024,
                                 at: xi * 1024) {
                nodes.append(node)
            }
        }
        let lastCount = sm.frames.count % 1024
        if lastCount > 0 {
            let xi = sm.frames.count / 1024
            if let node = spNode(width: lastCount,
                                 at: xi * 1024) {
                nodes.append(node)
            }
        }
        
        let sNode = Node(name: "spectrogram",
                         children: nodes,
                         attitude: .init(position: .init(firstX, y)),
                         path: Path(Rect(width: allW, height: maxH)))
        
        self.spectrogramNode = sNode
        self.spectrogramFqType = sm.type
        
        node.append(child: sNode)
    }
    func spectrogramPitch(atY y: Double) -> Double? {
        guard let spectrogramNode, let spectrogramFqType else { return nil }
        let y = y - 0.5 * Self.spectrogramHeight / 1024
        let h = spectrogramNode.path.bounds?.height ?? 0
        switch spectrogramFqType {
        case .linear:
            let fq = y.clipped(min: 0, max: h,
                               newMin: Spectrogram.minLinearFq,
                               newMax: Spectrogram.maxLinearFq)
            return Pitch.pitch(fromFq: max(fq, 1))
        case .pitch:
            return y.clipped(min: 0, max: h,
                             newMin: Spectrogram.minPitch,
                             newMax: Spectrogram.maxPitch)
        }
    }
    
    func updateTimeNode(atSec sec: Rational) {
        if let timeNode = timeNode, let frame = timelineFrame {
            let x = self.x(atSec: sec)
            if x >= frame.minX && x < frame.maxX {
                timeNode.path = Path([Point(), Point(0, isShownSpectrogram ? frame.height + Self.spectrogramHeight + ContentLayout.isShownSpectrogramHeight : frame.height)])
                timeNode.attitude.position = Point(x, frame.minY)
                updateFromPeakVolm()
            } else {
                timeNode.path = Path()
                currentPeakVolmNode?.path = Path()
            }
        } else {
            timeNode?.path = Path()
            currentPeakVolmNode?.path = Path()
        }
    }
    
    var bounds: Rect? {
        if let timelineFrame {
            return timelineFrame.union(contentFrame)
        } else {
            return contentFrame
        }
    }
    var transformedBounds: Rect? {
        if let bounds {
            bounds * node.localTransform
        } else {
            nil
        }
    }
    
    var clippableBounds: Rect? {
        if let timelineFrame {
            timelineFrame.union(contentFrame)
        } else {
            contentFrame
        }
    }
    var transformedClippableBounds: Rect? {
        if let bounds = clippableBounds {
            bounds * node.localTransform
        } else {
            nil
        }
    }
    
    func containsContent(_ p : Point) -> Bool {
        contentFrame?.contains(p) ?? false
    }
    var contentFrame: Rect? {
        model.imageFrame?.bounds
    }
    
    func containsTimeline(_ p : Point, scale: Double) -> Bool {
        timelineFrame?.outsetBy(dx: 5 * scale, dy: 3 * scale).contains(p) ?? false
    }
    var timelineFrame: Rect? {
        guard let timeOption = model.timeOption else { return nil }
        let sx = x(atBeat: timeOption.beatRange.start)
        let ex = x(atBeat: timeOption.beatRange.end)
        let thh = Sheet.timelineHalfHeight
        return Rect(x: sx, y: model.type.hasDur ? -thh : -thh * 2,
                    width: ex - sx, height: thh * 2)
    }
    var transformedTimelineFrame: Rect? {
        if var f = timelineFrame {
            f.origin.y += model.origin.y
            return f
        } else {
            return nil
        }
    }
    
    func containsIsShownSpectrogram(_ p: Point, scale: Double) -> Bool {
        if model.type.isAudio, let timeOption = model.timeOption {
            Rect(x: x(atBeat: timeOption.beatRange.start) + ContentLayout.spectrogramX - Sheet.knobHeight / 2,
                 y: Sheet.timelineHalfHeight,
                 width: Sheet.knobHeight,
                 height: ContentLayout.isShownSpectrogramHeight)
            .outset(by: scale * 3)
            .contains(p)
        } else {
            false
        }
    }
    
    func contains(_ p: Point, scale: Double) -> Bool {
        containsContent(p)
        || containsTimeline(p, scale: scale)
        || containsIsShownSpectrogram(p, scale: scale)
    }
    
    func isShownSpectrogram(at p :Point) -> Bool {
        if model.type.isAudio {
            p.y > Sheet.timelineHalfHeight + ContentLayout.isShownSpectrogramHeight / 2
        } else {
            false
        }
    }
    var isShownSpectrogram: Bool {
        get {
            model.isShownSpectrogram
        }
        set {
            let oldValue = model.isShownSpectrogram
            if newValue != oldValue {
                binder[keyPath: keyPath].isShownSpectrogram = newValue
                updateTimeline()
                updateSpectrogram()
            }
        }
    }
}
