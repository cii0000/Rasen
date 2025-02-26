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

import struct Foundation.Data
import struct Foundation.Date

extension Date: Protobuf {
    init(_ pb: PBDate) throws {
        self.init(timeIntervalSinceReferenceDate: pb.timestamp)
    }
    var pb: PBDate {
        .with {
            $0.timestamp = timeIntervalSinceReferenceDate
        }
    }
}

struct Version: Hashable, Codable {
    var indexPath = [Int](), groupIndex = 0
}

enum UndoItemType {
    case unreversible, lazyReversible, reversible
}
protocol UndoItem: Codable, Sendable, Protobuf {
    var type: UndoItemType { get }
    func reversed() -> Self?
}

struct UndoItemValue<T: UndoItem> {
    var undoItem: T
    var redoItem: T
}
extension UndoItemValue {
    init(undoItem: T, redoItem: T, isReversed: Bool) {
        if isReversed {
            self.undoItem = redoItem
            self.redoItem = undoItem
        } else {
            self.undoItem = undoItem
            self.redoItem = redoItem
        }
    }
    struct InitializeError: Error {}
    init(undoItem: T?, redoItem: T?) throws {
        var undoItem = undoItem, redoItem = redoItem
        if let undoItem = undoItem, undoItem.type == .lazyReversible {
            self.undoItem = undoItem
            self.redoItem = undoItem
        } else if let redoItem = redoItem, redoItem.type == .lazyReversible {
            self.undoItem = redoItem
            self.redoItem = redoItem
        } else {
            if let aUndoItem = redoItem?.reversed() {
                undoItem = aUndoItem
            } else if let aRedoItem = undoItem?.reversed() {
                redoItem = aRedoItem
            }
            if let undoItem = undoItem, let redoItem = redoItem {
                self.undoItem = undoItem
                self.redoItem = redoItem
            } else {
                throw InitializeError()
            }
        }
    }
    init(item: T, type: UndoType) throws {
        guard let reversedItem = item.reversed() else {
            throw InitializeError()
        }
        switch type {
        case .undo:
            self.undoItem = item
            self.redoItem = reversedItem
        case .redo:
            self.undoItem = reversedItem
            self.redoItem = item
        }
    }
    mutating func set(_ item: T, type: UndoType) {
        print("UndoItem set: \(item) \(type)")
        switch type {
        case .undo:
            undoItem = item
        case .redo:
            redoItem = item
        }
    }
    func encodeTuple() -> (undoItem: T, type: UndoType) {
        let undoType = undoItem.type, redoType = redoItem.type
        if undoType == .lazyReversible {
            return (undoItem, .undo)
        } else if redoType == .lazyReversible {
            return (redoItem, .redo)
        } else if undoType == .reversible {
            return (undoItem, .undo)
        } else {
            return (redoItem, .redo)
        }
    }
}
extension UndoItemValue: CustomStringConvertible {
    var description: String {
        "\nundo: \(undoItem),\nredo: \(redoItem)\n"
    }
}
extension UndoItemValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case undo, redo
    }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let undoItem = try? values.decode(T.self, forKey: .undo)
        let redoItem = try? values.decode(T.self, forKey: .redo)
        try self.init(undoItem: undoItem, redoItem: redoItem)
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let (item, type) = encodeTuple()
        switch type {
        case .undo: try container.encode(item, forKey: .undo)
        case .redo: try container.encode(item, forKey: .redo)
        }
    }
}
struct UndoDataValue<T: UndoItem> {
    enum LoadType {
        case unload, loaded, error
    }
    
    var undoItemData = Data()
    var redoItemData = Data()
    var loadType = LoadType.unload
    var undoItemValue = UndoItemValue<T>?.none
    
    mutating func error() {
        print("Undo error: \(loadType) \(String(describing: undoItemValue))")
        loadType = .error
        undoItemData = Data()
        redoItemData = Data()
        undoItemValue = nil
    }
    var saveUndoItemValue: UndoItemValue<T>? {
        get {
            undoItemValue
        }
        set {
            undoItemValue = newValue
            save()
        }
    }
}
extension UndoDataValue {
    init(save itemValue: UndoItemValue<T>) {
        self.undoItemValue = itemValue
        self.loadType = .loaded
        save()
    }
    mutating func loadRedoItem() -> UndoItemValue<T>? {
        if loadType == .error {
            return nil
        } else if let undoItemValue = undoItemValue {
            return undoItemValue
        } else {
            let undoItem = try? T(serializedData: undoItemData)
            let redoItem = try? T(serializedData: redoItemData)
            if let undoItem = undoItem {
                if let redoItem = redoItem {
                    undoItemValue = UndoItemValue(undoItem: undoItem,
                                                  redoItem: redoItem)
                    loadType = .loaded
                    return undoItemValue
                } else if let redoItem = undoItem.reversed() {
                    undoItemValue = UndoItemValue<T>(undoItem: undoItem,
                                                     redoItem: redoItem)
                    loadType = .loaded
                    return undoItemValue
                } else {
                    loadType = .error
                    undoItemValue = nil
                    return nil
                }
            } else if let redoItem = redoItem, let undoItem = redoItem.reversed() {
                undoItemValue = UndoItemValue<T>(undoItem: undoItem,
                                                 redoItem: redoItem)
                loadType = .loaded
                return undoItemValue
            } else {
                loadType = .error
                undoItemValue = nil
                return nil
            }
        }
    }
    func loadedRedoItem() -> UndoItemValue<T>? {
        if loadType == .error {
            return nil
        } else if let undoItemValue = undoItemValue {
            return undoItemValue
        } else {
            let undoItem = try? T(serializedData: undoItemData)
            let redoItem = try? T(serializedData: redoItemData)
            if let undoItem = undoItem {
                if let redoItem = redoItem {
                    return UndoItemValue(undoItem: undoItem, redoItem: redoItem)
                } else if let redoItem = undoItem.reversed() {
                    return UndoItemValue<T>(undoItem: undoItem, redoItem: redoItem)
                } else {
                    return nil
                }
            } else if let redoItem = redoItem, let undoItem = redoItem.reversed() {
                return UndoItemValue<T>(undoItem: undoItem, redoItem: redoItem)
            } else {
                return nil
            }
        }
    }
    mutating func save() {
        undoItemData = Data()
        redoItemData = Data()
        guard let undoItemValue = undoItemValue else { return }
        let undoType = undoItemValue.undoItem.type
        let redoType = undoItemValue.redoItem.type
        if undoType == .lazyReversible || redoType == .lazyReversible {
            if let undoItemData = try? undoItemValue.undoItem.serializedData() {
                self.undoItemData = undoItemData
            }
            if let redoItemData = try? undoItemValue.redoItem.serializedData() {
                self.redoItemData = redoItemData
            }
        } else if undoType == .reversible {
            if let undoItemData = try? undoItemValue.undoItem.serializedData() {
                self.undoItemData = undoItemData
            }
        } else {
            if let redoItemData = try? undoItemValue.redoItem.serializedData() {
                self.redoItemData = redoItemData
            }
        }
    }
}
extension UndoDataValue: Protobuf {
    typealias PB = PBUndoDataValue
    init(_ pb: PBUndoDataValue) throws {
        undoItemData = pb.undoItemData
        redoItemData = pb.redoItemData
    }
    var pb: PBUndoDataValue {
        .with {
            $0.undoItemData = undoItemData
            $0.redoItemData = redoItemData
        }
    }
}
extension UndoDataValue: Codable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        undoItemData = try container.decode(Data.self)
        redoItemData = try container.decode(Data.self)
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(undoItemData)
        try container.encode(redoItemData)
    }
}

struct UndoGroup<T: UndoItem> {
    var values = [UndoDataValue<T>]()
    var isFirstReverse = false
    var date = Date()
}
extension UndoGroup {
    func reverse(_ handler: (EnumeratedSequence<[UndoDataValue<T>]>.Element) -> ()) {
        if isFirstReverse && values.count > 1 {
            handler((0, values[0]))
            for i in (1 ..< values.count).reversed() {
                handler((i, values[i]))
            }
        } else {
            values.enumerated().reversed().forEach {
                handler($0)
            }
        }
    }
}
extension UndoGroup: Protobuf {
    typealias PB = PBUndoGroup
    init(_ pb: PBUndoGroup) throws {
        values = try pb.values.map { try UndoDataValue($0) }
        isFirstReverse = pb.isFirstReverse
        date = (try? Date(pb.date)) ?? Date(timeIntervalSinceReferenceDate: 0)
    }
    var pb: PBUndoGroup {
        .with {
            $0.values = values.map { $0.pb }
            $0.isFirstReverse = isFirstReverse
            $0.date = date.pb
        }
    }
}
extension UndoGroup: Codable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        values = try container.decode([UndoDataValue<T>].self)
        isFirstReverse = try container.decode(Bool.self)
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(values)
        try container.encode(isFirstReverse)
    }
}

private final class _Branch<T: UndoItem>: @unchecked Sendable {
    var groups = [UndoGroup<T>]()
    var children = [_Branch<T>]()
    var selectedChildIndex = Int?.none
    fileprivate var childrenCount = 0
    
    init(groups: [UndoGroup<T>] = .init(), children: [_Branch<T>] = .init(),
         selectedChildIndex: Int? = nil) {
        self.groups = groups
        self.children = children
        self.selectedChildIndex = selectedChildIndex
        self.childrenCount = children.count
    }
    
    deinit {
        var count = 0
        self.allBranchs { _, _ in count += 1 }
        
        var allBranchs = [_Branch<T>](capacity: count)
        var branchStack = Stack<_Branch<T>>(minimumCapacity: count)
        branchStack.push(self)
        while let branch = branchStack.pop() {
            allBranchs.append(branch)
            for child in branch.children.reversed() {
                branchStack.push(child)
            }
        }
        allBranchs.forEach {
            $0.groups = []
            $0.children = []
            $0.selectedChildIndex = nil
        }
        allBranchs = []
    }
}
extension _Branch: Protobuf {
    typealias PB = PBBranch
    convenience init(_ pb: PBBranch) throws {
        self.init()
        groups = try pb.groups.map { try UndoGroup($0) }
        childrenCount = Int(pb.childrenCount)
        if case .selectedChildIndex(let selectedChildIndex)?
            = pb.selectedChildIndexOptional {
            
            self.selectedChildIndex = Int(selectedChildIndex)
        } else {
            selectedChildIndex = nil
        }
    }
    var pb: PBBranch {
        .with {
            $0.groups = groups.map { $0.pb }
            $0.childrenCount = Int64(children.count)
            if let selectedChildIndex = selectedChildIndex {
                $0.selectedChildIndexOptional
                    = .selectedChildIndex(Int64(selectedChildIndex))
            } else {
                $0.selectedChildIndexOptional = nil
            }
        }
    }
}
extension _Branch {
    func appendInLastGroup(undo undoItem: T,
                                    redo redoItem: T) {
        let uiv = UndoItemValue(undoItem: undoItem, redoItem: redoItem)
        let udv = UndoDataValue(save: uiv)
        groups[.last].values.append(udv)
    }
    func setFirstInLastGroup(item: T) {
        let uiv = UndoItemValue(undoItem: item, redoItem: item)
        let udv = UndoDataValue(save: uiv)
        groups[.last].values = [udv]
        groups[.last].isFirstReverse = true
    }
    subscript(version: Version) -> UndoGroup<T> {
        get { self[version.indexPath].groups[version.groupIndex] }
        set { self[version.indexPath].groups[version.groupIndex] = newValue }
    }
    subscript(indexPath: [Int]) -> _Branch<T> {
        var branch = self
        indexPath.forEach {
            branch = branch.children[$0]
        }
        return branch
    }
    func version(atAll i: Int) -> Version? {
        guard i > 0 else { return nil }
        let i = i - 1
        var branch = self, j = 0, indexPath = [Int]()
        while true {
            let nj = j + branch.groups.count
            if nj > i {
                return Version(indexPath: indexPath, groupIndex: i - j)
            }
            guard let sci = branch.selectedChildIndex else { break }
            indexPath.append(sci)
            j = nj
            branch = branch.children[sci]
        }
        return .init(indexPath: indexPath, groupIndex: branch.groups.count - 1)
    }
    
    func allBranchs(_ handler: ([Int], _Branch<T>) -> ()) {
        var indexPathAndBranchs = [([Int](), self)]
        while let (indexPath, branch) = indexPathAndBranchs.last {
            indexPathAndBranchs.removeLast()
            handler(indexPath, branch)
            for (i, child) in branch.children.enumerated().reversed() {
                var indexPath = indexPath
                indexPath.append(i)
                indexPathAndBranchs.append((indexPath, child))
            }
        }
    }
    func allGroups(_ handler: ([Int], [UndoGroup<T>]) -> ()) {
        var indexPathAndBranchs = [([Int](), self)]
        while let (indexPath, branch) = indexPathAndBranchs.last {
            indexPathAndBranchs.removeLast()
            handler(indexPath, branch.groups)
            for (i, child) in branch.children.enumerated().reversed() {
                var indexPath = indexPath
                indexPath.append(i)
                indexPathAndBranchs.append((indexPath, child))
            }
        }
    }
    
    func copy() -> Self {
        .init(groups: groups, children: children.map { $0.copy() },
              selectedChildIndex: selectedChildIndex)
    }
}
extension _Branch: Codable {
    public convenience init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init()
        groups = try container.decode([UndoGroup<T>].self)
        childrenCount = try container.decode(Int.self)
        selectedChildIndex = try container.decodeIfPresent(Int.self)
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(groups)
        try container.encode(children.count)
        try container.encode(selectedChildIndex)
    }
}

struct Branch<T: UndoItem> {
    var groups = [UndoGroup<T>]()
    var childrenCount = 0
    var selectedChildIndex = Int?.none
}

private struct BranchCoder<T: UndoItem> {
    var rootBranch: _Branch<T>
}
extension BranchCoder: Protobuf {
    typealias PB = PBBranchCoder
    init(_ pb: PBBranchCoder) throws {
        let allBranches = try pb.allBranches.map { try _Branch<T>($0) }
        rootBranch = BranchCoder.rootBranch(from: allBranches)
    }
    var pb: PBBranchCoder {
        .with {
            $0.allBranches = allBranches.map { $0.pb }
        }
    }
}
private enum BranchLoop<T: UndoItem> {
    case first(_ branch: _Branch<T>)
    case next(_ children: [_Branch<T>], _ branch: _Branch<T>, _ j: Int)
}
extension BranchCoder {
    static func rootBranch(from allBranches: [_Branch<T>]) -> _Branch<T> {
        guard let root = allBranches.first else {
            return _Branch<T>()
        }
        
        var i = 0, loopStack = Stack<BranchLoop<T>>()
        var returnStack = Stack<_Branch<T>>()
        loopStack.push(.first(root))
        loop: while true {
            let branch: _Branch<T>, nj: Int
            var children: [_Branch<T>]
            switch loopStack.pop()! {
            case .first(let oBranch):
                children = [_Branch<T>]()
                children.reserveCapacity(oBranch.childrenCount)
                branch = oBranch
                nj = 0
            case .next(var nChildren, let oBranch, let oj):
                nChildren.append(returnStack.pop()!)
                children = nChildren
                branch = oBranch
                nj = oj
            }
            for j in nj ..< branch.childrenCount {
                i += 1
                
                loopStack.push(.next(children, branch, j + 1))
                loopStack.push(.first(allBranches[i]))
                continue loop
            }
            
            let nBranch = branch
            nBranch.children = children
            nBranch.children.enumerated().reversed().forEach {
                if $0.element.groups.isEmpty {
                    nBranch.children.remove(at: $0.offset)
                }
            }
            
            if loopStack.isEmpty {
                return nBranch
            } else {
                returnStack.push(nBranch)
                continue loop
            }
        }
    }
    var allBranches: [_Branch<T>] {
        var allBranches = [_Branch<T>]()
        var uns = [rootBranch]
        while let un = uns.last {
            uns.removeLast()
            allBranches.append(un)
            for child in un.children.reversed() {
                uns.append(child)
            }
        }
        return allBranches
    }
}
extension BranchCoder: Codable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let allBranches = try container.decode([_Branch<T>].self)
        rootBranch = BranchCoder.rootBranch(from: allBranches)
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(allBranches)
    }
}

enum UndoType {
    case undo, redo
}

struct History<T: UndoItem> {
    private var rootBranch = _Branch<T>()
    var currentVersionIndex = 0, currentVersion = Version?.none
}
extension History: Protobuf {
    typealias PB = PBHistory
    init(_ pb: PBHistory) throws {
        rootBranch = try BranchCoder(pb.branchCoder).rootBranch
        currentVersionIndex = Int(pb.currentVersionIndex)
        check()
    }
    var pb: PBHistory {
        .with {
            $0.branchCoder = BranchCoder(rootBranch: rootBranch).pb
            $0.currentVersionIndex = Int64(currentVersionIndex)
        }
    }
}
extension History: Codable {
    private enum CodingKeys: String, CodingKey {
        case rootBranch, currentVersionIndex
    }
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        rootBranch = try values.decode(BranchCoder.self,
                                       forKey: .rootBranch).rootBranch
        currentVersionIndex = try values.decode(Int.self,
                                                forKey: .currentVersionIndex)
        check()
    }
    mutating func check() {
        copyIfShared()
        
        guard currentVersionIndex > 0 else {
            currentVersion = nil
            return
        }
        let i = currentVersionIndex - 1
        var branch = rootBranch, j = 0, indexPath = [Int]()
        while true {
            let nj = j + branch.groups.count
            if nj > i {
                currentVersion = Version(indexPath: indexPath, groupIndex: i - j)
                return
            }
            guard let sci = branch.selectedChildIndex else { break }
            indexPath.append(sci)
            j = nj
            branch = branch.children[sci]
        }
        currentVersionIndex = j + branch.groups.count - 1
        currentVersion = .init(indexPath: indexPath, groupIndex: branch.groups.count - 1)
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(BranchCoder(rootBranch: rootBranch),
                             forKey: .rootBranch)
        try container.encode(currentVersionIndex, forKey: .currentVersionIndex)
    }
}
extension History {
    private mutating func copyIfShared() {
        if isKnownUniquelyReferenced(&rootBranch) { return }
        rootBranch = rootBranch.copy()
    }
    
    mutating func newBranch() {
        copyIfShared()
        
        if let currentVersion {
            var indexPath = currentVersion.indexPath
            let branch = rootBranch[indexPath]
            if currentVersion.groupIndex == branch.groups.count - 1 {
                guard let i = branch.selectedChildIndex else { return }
                let branch0 = _Branch<T>(groups: [.init()])
                let ni = i + 1
                branch.children.insert(branch0, at: ni)
                branch.selectedChildIndex = ni
                indexPath.append(ni)
            } else {
                let branch0 = _Branch<T>(groups: Array(branch.groups[(currentVersion.groupIndex + 1)...]),
                                         children: branch.children,
                                         selectedChildIndex: branch.selectedChildIndex)
                let branch1 = _Branch<T>(groups: [.init()])
                branch.groups.removeLast(branch.groups.count - currentVersion.groupIndex - 1)
                branch.children = [branch0, branch1]
                branch.selectedChildIndex = 1
                indexPath.append(1)
            }
            self.currentVersion = .init(indexPath: indexPath, groupIndex: 0)
            currentVersionIndex += 1
        } else {
            let branch0 = rootBranch
            if branch0.groups.count == 0 {
                guard let i = branch0.selectedChildIndex else { return }
                let branch1 = _Branch<T>(groups: [.init()])
                let ni = i + 1
                rootBranch.children.insert(branch1, at: ni)
                rootBranch.selectedChildIndex = ni
                currentVersion = .init(indexPath: [ni], groupIndex: 0)
                currentVersionIndex = 1
            } else {
                let branch1 = _Branch<T>(groups: [.init()])
                rootBranch = .init(groups: [], children: [branch0, branch1], selectedChildIndex: 1)
                currentVersion = .init(indexPath: [1], groupIndex: 0)
                currentVersionIndex = 1
            }
        }
    }
    mutating func newUndoGroup(firstItem: T? = nil) {
        copyIfShared()
        
        if !isLeafUndo {
            newBranch()
        } else {
            if let version = currentVersion {
                rootBranch[version.indexPath].groups.append(UndoGroup())
                currentVersionIndex += 1
                currentVersion!.groupIndex += 1
            } else {
                rootBranch.groups = [UndoGroup()]
                currentVersionIndex = 1
                currentVersion = Version(indexPath: .init(), groupIndex: 0)
            }
        }
        if let item = firstItem {
            rootBranch[currentVersion!.indexPath]
                .setFirstInLastGroup(item: item)
        }
    }
    mutating func append(undo undoItem: T, redo redoItem: T) {
        copyIfShared()
        
        rootBranch[currentVersion!.indexPath]
            .appendInLastGroup(undo: undoItem, redo: redoItem)
    }
    
    struct UndoResult {
        var item: UndoDataValue<T>, type: UndoType
        var version: Version, valueIndex: Int
    }
    mutating func undoAndResults(to toTopIndex: Int) -> [UndoResult] {
        copyIfShared()
        
        let fromTopIndex = currentVersionIndex
        guard fromTopIndex != toTopIndex else { return [] }
        func enumerated(minI: Int, maxI: Int, _ handler: (Version) -> ()) {
            var minI = minI
            if minI == 0 {
                minI = 1
                handler(Version(indexPath: .init(), groupIndex: -1))
            }
            guard minI <= maxI else { return }
            for i in minI ... maxI {
                let version = rootBranch.version(atAll: i)!
                handler(version)
            }
        }
        var results = [UndoResult]()
        if fromTopIndex < toTopIndex {
            enumerated(minI: fromTopIndex + 1, maxI: toTopIndex) { (version) in
                rootBranch[version].values.enumerated().forEach {
                    results.append(UndoResult(item: $0.element,
                                              type: .redo,
                                              version: version,
                                              valueIndex: $0.offset))
                }
            }
        } else {
            var versions = [(Version)]()
            versions.reserveCapacity(fromTopIndex - toTopIndex)
            enumerated(minI: toTopIndex, maxI: fromTopIndex - 1) { (version) in
                versions.append((version))
            }
            versions.reversed().forEach { (version) in
                let branch = rootBranch[version.indexPath]
                if version.groupIndex + 1 >= branch.groups.count {
                    var nVersion = version
                    nVersion.groupIndex = 0
                    nVersion.indexPath.append(branch.selectedChildIndex!)
                    branch.children[branch.selectedChildIndex!].groups[0].reverse {
                        results.append(UndoResult(item: $0.element,
                                                  type: .undo,
                                                  version: nVersion,
                                                  valueIndex: $0.offset))
                    }
                } else {
                    var nVersion = version
                    nVersion.groupIndex = version.groupIndex + 1
                    rootBranch[nVersion].reverse {
                        results.append(UndoResult(item: $0.element,
                                                  type: .undo,
                                                  version: nVersion,
                                                  valueIndex: $0.offset))
                    }
                }
            }
        }
        currentVersion = rootBranch.version(atAll: toTopIndex)
        currentVersionIndex = toTopIndex
        return results
    }
    
    subscript(version: Version) -> UndoGroup<T> {
        get { rootBranch[version.indexPath].groups[version.groupIndex] }
        set {
            copyIfShared()
            
            rootBranch[version.indexPath].groups[version.groupIndex] = newValue
        }
    }
    
    mutating func set(selectedChildIndex: Int, at indexPath: [Int]) {
        copyIfShared()
        
        rootBranch[indexPath].selectedChildIndex = selectedChildIndex
    }
    
    mutating func reset() {
        copyIfShared()
        
        rootBranch = _Branch()
        currentVersionIndex = 0
        currentVersion = nil
    }
    
    var isEmpty: Bool {
        rootBranch.groups.isEmpty && rootBranch.children.isEmpty
    }
    
    var currentMaxVersionIndex: Int {
        var un = rootBranch, i = un.groups.count
        while let sci = un.selectedChildIndex {
            un = un.children[sci]
            i += un.groups.count
        }
        return i
    }
    var isLeafUndo: Bool {
        currentVersionIndex == currentMaxVersionIndex
    }
    var isCanUndo: Bool {
        currentVersionIndex > 0
    }
    var isCanRedo: Bool {
        currentVersionIndex < currentMaxVersionIndex
    }
    
    func branch(from indexPath: [Int]) -> Branch<T> {
        let branch = rootBranch[indexPath]
        return .init(groups: branch.groups, childrenCount: branch.children.count,
                     selectedChildIndex: branch.selectedChildIndex)
    }
    var currentDate: Date? {
        if let version = currentVersion {
            rootBranch[version].date
        } else {
            nil
        }
    }
    
    func allGroups(_ handler: ([Int], [UndoGroup<T>]) -> ()) {
        rootBranch.allGroups(handler)
    }
    func allBranchsFromSelected(_ handler: (Branch<T>, Int) -> ()) {
        var branch = rootBranch
        while let i = branch.selectedChildIndex {
            handler(.init(groups: branch.groups, childrenCount: branch.children.count,
                          selectedChildIndex: branch.selectedChildIndex),
                    i)
            branch = branch.children[i]
        }
    }
}
