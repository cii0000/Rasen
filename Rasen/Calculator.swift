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

import struct Foundation.UUID

extension O {
    private enum Temp: CustomStringConvertible {
        case o(O, Substring), uncal(Substring)
        
        var o: O? {
            switch self {
            case .o(let o, _): o
            default: nil
            }
        }
        var uncal: Substring? {
            switch self {
            case .uncal(let uncal): uncal
            default: nil
            }
        }
        var description: String {
            switch self {
            case .o(let o, _): "o:'\(o.description)'"
            case .uncal(let str): "uncal:'\(str.description)'"
            }
        }
    }
    init(_ text: Text, range: Range<String.Index>? = nil, isDictionary: Bool = false, _ oDic: inout [OKey: O]) {
        let range = range ?? (text.string.startIndex ..< text.string.endIndex)
        guard !text.isEmpty && !range.isEmpty else {
            self = O()
            return
        }
        
        enum Tree: CustomStringConvertible {
            case literal([Tree], Substring)
            case fo([Tree], Substring)
            case string(Substring)
            
            var string: Substring {
                switch self {
                case .literal(_, let str): str
                case .fo(_, let str): str
                case .string(let str): str
                }
            }
            var description: String {
                switch self {
                case .literal(let ts, _): "literal:'\(ts.description)'"
                case .fo(let ts, _): "fo:'\(ts.description)'"
                case .string(let s): "s:'\(s)'"
                }
            }
        }
        
        let srs = O.analyzed(from: text, range: range).filter { !$0.string.isEmpty }
        var trees = [Tree](), height = 0
        var bracketStack = Stack<(Int)>(), unionStack = Stack<((Int, Int))>()
        for (sri, sr) in srs.enumerated() {
            func unionTree(from i: Int) {
                guard i + 1 < trees.count else { return }
                let no = Array(trees[i...])
                trees.removeLast(trees.count - i)
                trees.append(.literal(no, no.first?.string ?? ""))
            }
            switch sr.type {
            case .start:
                if sri - 1 < 0 || !srs[sri - 1].isLeftUnion {
                    unionStack.push((trees.count, height))
                }
                bracketStack.push(trees.count)
                height += 1
            case .endStart:
                guard let i = bracketStack.pop() else { break }
                let nfo = Array(trees[i...])
                if let str = nfo.first?.string {
                    trees.removeLast(trees.count - i)
                    trees.append(.fo(nfo, str))
                }
                
                bracketStack.push(trees.count)
                
                //                if let (i, _) = unionStack.pop() {
                //                    unionStack.push((i, false))
                //                }
            case .end:
                height -= 1
                guard let i = bracketStack.pop() else { break }
                let nfo = Array(trees[i...])
                trees.removeLast(trees.count - i)
                trees.append(.fo(nfo, nfo.first?.string ?? ""))
                
                if sri + 1 >= srs.count || !srs[sri + 1].isRightUnion,
                   unionStack.elements.last?.1 == height,
                   let (i, _) = unionStack.pop() {
                    
                    unionTree(from: i)
                }
            case .leftLiteral:
                unionStack.push((trees.count, height))
                trees.append(.string(sr.string))
            case .string:
                trees.append(.string(sr.string))
            case .leftString:
                unionStack.push((trees.count, height))
                trees.append(.string(sr.string))
            case .rightString:
                trees.append(.string(sr.string))
                if let (i, _) = unionStack.pop() {
                    unionTree(from: i)
                }
            case .centerString:
                trees.append(.string(sr.string))
                //                if let (i, _) = unionStack.pop() {
                //                    unionStack.push((i, height))
                //                }
            case .rightLiteral:
                trees.append(.string(sr.string))
                if let (i, _) = unionStack.pop() {
                    unionTree(from: i)
                }
            case .centerLiteral:
                trees.append(.string(sr.string))
                //                if let (i, _) = unionStack.pop() {
                //                    unionStack.push((i, height))
                //                }
            case .stringBracketError:
                self = O(OError("Unterminated string literal '\"'".localized))
                return
            case .bracketError:
                self = O(OError("Unterminated function literal ')'".localized))
                return
            }
        }
        
        func substring(from trees: [Tree]) -> Substring? {
            for tree in trees {
                switch tree {
                case .string(let s): return s
                default: break
                }
            }
            return nil
        }
        
        let typesetter = text.typesetter
        func subO(from tree: Tree) -> O {
            switch tree {
            case .fo(let fts, _):
                return o(from: fts)
            case .literal(let lts, _):
                let temps: [Temp] = lts.compactMap {
                    switch $0 {
                    case .fo(let fts, let fstr): .o(o(from: fts), fstr)
                    case .literal: fatalError()
                    case .string(let s): .uncal(s)
                    }
                }
                return O.literalO(from: temps,
                                  text, typesetter, &oDic)
            case .string(let s):
                return O.literalO(from: [.uncal(s)],
                                  text, typesetter, &oDic)
            }
        }
        func fDics(_ fods: [Tree]) -> [(label: Tree, values: [Tree])] {
            var dics = [(label: Tree, values: [Tree])](), preLabel: Tree?
            var vs = [Tree]()
            for fod in fods {
                var nLabel: Tree?
                switch fod {
                case .literal(let fs, let fstr):
                    if let lt = fs.last {
                        switch lt {
                        case .literal, .fo: nLabel = nil
                        case .string(var s):
                            if s.last == ":" {
                                var fs = fs
                                fs.removeLast()
                                s.removeLast()
                                if !s.isEmpty {
                                    fs.append(.string(s))
                                }
                                nLabel = .literal(fs, fstr)
                            } else {
                                nLabel = nil
                            }
                        }
                    } else {
                        nLabel = nil
                    }
                case .fo: nLabel = nil
                case .string(var s):
                    if s.last == ":" {
                        s.removeLast()
                        nLabel = .string(s)
                    } else {
                        nLabel = nil
                    }
                }
                if let nLabel = nLabel {
                    if let label = preLabel, !vs.isEmpty {
                        dics.append((label, vs))
                        vs = []
                    }
                    preLabel = nLabel
                } else {
                    vs.append(fod)
                }
            }
            if let label = preLabel, !vs.isEmpty {
                dics.append((label, vs))
                vs = []
            }
            return dics
        }
        func ifO(from ts: [Tree]) -> O? {
            let thenKey = "->", elseKey = "-!", caseKey = "case"
            guard let ii0 = ts.firstIndex(where: {
                switch $0 {
                case .string(let s): s == thenKey || s == caseKey
                default: false
                }
            }) else { return nil }
            var i = ii0
            
            struct IfTree {
                var ifLiteral: Substring = ""
                var ifValueTrees: [Tree]
                var returnTuples = [(label: [Tree], value: [Tree])]()
                var elseLiteral: Substring = ""
                var elseTrees: [Tree]
            }
            enum IfType {
                case thenLiteral, elseLiteral, caseLiteral
                case ifTrees, caseTrees, valueTrees, elseTrees
                var isLiteral: Bool {
                    switch self {
                    case .thenLiteral, .elseLiteral, .caseLiteral:
                        return true
                    default:
                        return false
                    }
                }
            }
            var ifTrees = [IfTree]()
            var preType = IfType.ifTrees
            let firstTrees = Array(ts[..<i])
            
            var curerntTrees = [Tree](), preLabel: [Tree]?
            ifTrees.append(IfTree(ifValueTrees: firstTrees, elseTrees: []))
            func append() {
                if !curerntTrees.isEmpty {
                    switch preType {
                    case .ifTrees:
                        ifTrees[.last].ifValueTrees = curerntTrees
                    case .caseTrees:
                        preLabel = curerntTrees
                    case .elseTrees:
                        ifTrees[.last].elseTrees = curerntTrees
                    case .valueTrees:
                        if let preLabel = preLabel {
                            ifTrees[.last].returnTuples.append((preLabel, curerntTrees))
                        }
                        preLabel = nil
                    default: break
                    }
                    curerntTrees = []
                }
            }
            loop: while true {
                let v = ts[i]
                switch v {
                case .string(let s):
                    if s == thenKey {
                        if preType.isLiteral {
                            return O(OError("Conditional syntax error".localized))
                        }
                        if preType == .elseTrees {
                            ifTrees.append(IfTree(ifValueTrees: curerntTrees, elseTrees: []))
                            curerntTrees = []
                            ifTrees[.last].ifLiteral = s
                        } else {
                            ifTrees[.last].ifLiteral = s
                            append()
                        }
                        if preLabel == nil {
                            let trueStr = s.substring("true", s.startIndex ..< s.startIndex)
                            preLabel = [Tree.string(trueStr)]
                        }
                        preType = .thenLiteral
                    } else if s == elseKey {
                        if preType.isLiteral || preType == .elseTrees {
                            return O(OError("Conditional syntax error".localized))
                        }
                        ifTrees[.last].elseLiteral = s
                        append()
                        preType = .elseLiteral
                    } else if s == caseKey {
                        if preType.isLiteral {
                            return O(OError("Conditional syntax error".localized))
                        }
                        if preType == .elseTrees {
                            ifTrees.append(IfTree(ifValueTrees: curerntTrees, elseTrees: []))
                            curerntTrees = []
                            ifTrees[.last].ifLiteral = s
                        } else {
                            ifTrees[.last].ifLiteral = s
                            append()
                        }
                        preType = .caseLiteral
                    } else {
                        curerntTrees.append(v)
                        switch preType {
                        case .thenLiteral: preType = .valueTrees
                        case .elseLiteral: preType = .elseTrees
                        case .caseLiteral: preType = .caseTrees
                        default: break
                        }
                    }
                default:
                    curerntTrees.append(v)
                    switch preType {
                    case .thenLiteral: preType = .valueTrees
                    case .elseLiteral: preType = .elseTrees
                    case .caseLiteral: preType = .caseTrees
                    default: break
                    }
                }
                i = ts.index(after: i)
                if i == ts.endIndex { break }
            }
            append()
            
            var nextO: O
            if let elseTrees = ifTrees.last?.elseTrees, !elseTrees.isEmpty {
                let elseOs = os(from: elseTrees)
                nextO = O(F(elseOs))
            } else {
                nextO = O(F([O(OError("-! value".localized))]))
            }
            
            func rect(at i: Substring.Index, _ str: Substring) -> Rect? {
                return typesetter.characterBounds(at: i)
            }
            func v(_ nstr: String, in str: Substring) -> ID {
                if !str.isEmpty, var r = rect(at: str.startIndex, str) {
                    r.size.width = 0
                    return ID(nstr, typesetter.typobute, r + text.origin)
                } else {
                    return ID(nstr, typesetter.typobute)
                }
            }
            for ifTree in ifTrees.reversed() {
                let valuesOs = ifTree.returnTuples.reduce(into: [O]()) {
                    let los = os(from: $1.label)
                    $0.append(O(F([los.count == 1 ? los[0] : O(F(los)),
                                   O(v(":", in: ifTree.ifLiteral))])))
                    $0.append(O(F(os(from: $1.value)).with(isBlock: true)))
                }
                
                let getO = O(v(".", in: ifTree.ifLiteral))
                let ifValueOs = os(from: ifTree.ifValueTrees)
                
                let elseO = O(v("??", in: ifTree.elseLiteral))
                
                let vos = [O(F([O(F(valuesOs)), getO, O(F(ifValueOs))])), elseO, nextO]
                nextO = O(F(vos))
            }
            let sendO = O(v("send", in: ts[ii0].string))
            let sendOsO = O(F([]))
            return O(F([nextO, sendO, sendOsO]))
        }
        func os(from ts: [Tree]) -> [O] {
            if let o = ifO(from: ts) {
                return [o]
            }
            
            let fos = ts.map { subO(from: $0) }
            if fos.count == 1,
               case .f(let sf) = fos[0],
               sf.definitions.isEmpty && sf.type == .empty && !sf.isBlock {
                
                return sf.os
            } else {
                return fos
            }
        }
        
        struct FOption {
            var leftVs = [Argument]()
            var ovName: String?
            var rightVs = [Argument]()
            var prece: Int?, asso = F.AssociativityType.left
        }
        func fOption(_ nfs: [Tree],
                     isNoname: Bool = false) -> FOption? {
            var fs: [Tree]
            if case .literal(let nfs, _)? = nfs.first {
                fs = nfs
            } else {
                fs = nfs
            }
            let dics = fDics(fs)
            if isNoname && dics.isEmpty && !fs.contains(where: {
                switch $0 {
                case .literal, .fo: true
                case .string: false
                }
            }) {
                let args: [Argument] = fs.compactMap {
                    switch $0 {
                    case .literal, .fo:
                        return nil
                    case .string(let name):
                        return Argument(inKey: nil, outKey: OKey(name))
                    }
                }
                if args.isEmpty {
                    return nil
                }
                return FOption(leftVs: args, ovName: nil, rightVs: [],
                               prece: F.defaultPrecedence, asso: .left)
            } else {
                func vDic(_ vs: [Tree]) -> [Argument] {
                    var dic = [Argument](), preLabel: String?
                    for v in vs {
                        switch v {
                        case .literal, .fo: break
                        case .string(var s):
                            if s.last == ":" {
                                s.removeLast()
                                preLabel = String(s)
                            } else {
                                let value = String(s)
                                if let label = preLabel {
                                    dic.append(Argument(inKey: OKey(label), outKey: OKey(value)))
                                    preLabel = nil
                                } else {
                                    dic.append(Argument(inKey: nil, outKey: OKey(value)))
                                }
                            }
                        }
                    }
                    return dic
                }
                if fs.count == 2 {
                    if case .string(let s0) = fs[0],
                       case .fo(let fos, _) = fs[1] {
                        
                        if !isNoname || (isNoname && s0 == "$") {
                            return FOption(leftVs: [],
                                           ovName: String(s0),
                                           rightVs: vDic(fos),
                                           prece: nil, asso: .right)
                        }
                    } else if case .fo(let fos, _) = fs[0],
                              case .string(let s0) = fs[1] {
                        
                        if !isNoname || (isNoname && s0 == "$") {
                            return FOption(leftVs: vDic(fos),
                                           ovName: String(s0),
                                           rightVs: [],
                                           prece: nil, asso: .left)
                        }
                    }
                } else if fs.count == 3 {
                    if case .fo(let fos0, _) = fs[0],
                       case .string(let s0) = fs[1],
                       case .fo(let fos1, _) = fs[2] {
                        
                        if !isNoname || (isNoname && s0 == "$") {
                            return FOption(leftVs: vDic(fos0),
                                           ovName: String(s0),
                                           rightVs: vDic(fos1),
                                           prece: nil, asso: .left)
                        }
                    }
                } else if fs.count == 4 {
                    if case .fo(let fos0, _) = fs[0],
                       case .string(let s0) = fs[1],
                       case .fo(let fos1, _) = fs[2],
                       case .string(var s1) = fs[3] {
                        
                        let prece: Int?, asso: F.AssociativityType
                        if s1.last == "r" {
                            if s1.count >= 2 {
                                s1.removeLast()
                                if let p = Int(s1) {
                                    prece = p
                                    asso = .right
                                } else {
                                    return nil
                                }
                            } else {
                                prece = nil
                                asso = .right
                            }
                        } else {
                            if let p = Int(s1) {
                                prece = p
                                asso = .left
                            } else {
                                return nil
                            }
                        }
                        if !isNoname || (isNoname && s0 == "$") {
                            return FOption(leftVs: vDic(fos0),
                                           ovName: String(s0),
                                           rightVs: vDic(fos1),
                                           prece: prece, asso: asso)
                        }
                    }
                }
                return nil
            }
        }
        func foDic(_ fods: [Tree],
                   _ oldDic: inout [OKey: O?]) -> [OKey: F]? {
            let dics = fDics(fods)
            
            for (label, _) in dics {
                switch label {
                case .literal(let fs, _):
                    guard let option = fOption(fs),
                          let name = option.ovName else { continue }
                    let f = F(precedence: option.prece ?? F.defaultPrecedence,
                              associativity: option.asso,
                              left: option.leftVs, right: option.rightVs,
                              [:], os: [])
                    let fname = f.key(from: name)
                    oldDic[fname] = oDic[fname]
                    oDic[fname] = O()
                case .fo: fatalError()
                case .string(let n):
                    let name = OKey(n)
                    oldDic[name] = oDic[name]
                    oDic[name] = O()
                }
            }
            
            var foDic = [OKey: F]()
            for (label, values) in dics {
                switch label {
                case .literal(let fs, _):
                    var oldFODic = [OKey: O?]()
                    
                    guard let option = fOption(fs),
                          let name = option.ovName else { return nil }
                    for arg in option.leftVs {
                        oldFODic[arg.outKey] = oDic[arg.outKey]
                        oDic[arg.outKey] = O()
                    }
                    for arg in option.rightVs {
                        oldFODic[arg.outKey] = oDic[arg.outKey]
                        oDic[arg.outKey] = O()
                    }
                    let fos = os(from: values)
                    
                    for (key, value) in oldFODic { oDic[key] = value }
                    
                    let f = F(precedence: option.prece ?? F.defaultPrecedence,
                              associativity: option.asso,
                              left: option.leftVs, right: option.rightVs,
                              [:], os: fos)
                    foDic[f.key(from: name)] = f
                case .fo: fatalError()
                case .string(let name):
                    foDic[OKey(name)] = F(os(from: values))
                }
            }
            return foDic
        }
        func o(from ts: [Tree], isDic: Bool = false) -> O {
            let fi0 = ts.firstIndex {
                switch $0 {
                case .string(let s): s == "|"
                default: false
                }
            }
            if isDic {
                var oldDic = [OKey: O?]()
                
                guard let foDic = foDic(Array(ts[..<(fi0 ?? ts.count)]),
                                        &oldDic)
                else { return O(OError("Function syntax error".localized)) }
                
                for (key, value) in oldDic { oDic[key] = value }
                
                return O(F(foDic))
            } else if let fi0 = fi0 {
                let fi1 = ts.lastIndex {
                    switch $0 {
                    case .string(let s): s == "|"
                    default: false
                    }
                }
                if let fi1 = fi1, fi0 != fi1 {
                    if fi0 == ts.startIndex {//(| b | c)
                        var oldDic = [OKey: O?]()
                        
                        guard fi0 + 1 < fi1,
                              let foDic = foDic(Array(ts[(fi0 + 1) ..< fi1]).filter({
                                  switch $0 {
                                  case .string(let s): s != "|"
                                  default: true
                                  }
                              }),
                                                &oldDic)
                        else { return O(OError("Function syntax error".localized)) }
                        let foTemps = fi1 + 1 < ts.count ?
                        Array(ts[(fi1 + 1)...]) : []
                        let fos = os(from: foTemps)
                        
                        for (key, value) in oldDic { oDic[key] = value }
                        
                        let f = foDic.isEmpty ? F(fos) : F(foDic, os: fos)
                        return O(f.with(isBlock: true))
                    } else {//(a | b | c)
                        var oldDic = [OKey: O?]()
                        
                        guard let option = fOption(Array(ts[..<fi0]),
                                                   isNoname: true)
                        else { return O(OError("Function syntax error".localized)) }
                        for arg in option.leftVs {
                            oldDic[arg.outKey] = oDic[arg.outKey]
                            oDic[arg.outKey] = O()
                        }
                        for arg in option.rightVs {
                            oldDic[arg.outKey] = oDic[arg.outKey]
                            oDic[arg.outKey] = O()
                        }
                        guard fi0 + 1 < fi1,
                              let foDic = foDic(Array(ts[(fi0 + 1) ..< fi1]).filter({
                                  switch $0 {
                                  case .string(let s): s != "|"
                                  default: true
                                  }
                              }),
                                                &oldDic)
                        else { return O(OError("Function syntax error".localized)) }
                        let foTemps = fi1 + 1 < ts.count ?
                        Array(ts[(fi1 + 1)...]) : []
                        let fos = os(from: foTemps)
                        
                        for (key, value) in oldDic { oDic[key] = value }
                        
                        return O(F(precedence: option.prece ?? F.defaultPrecedence,
                                   associativity: option.asso,
                                   left: option.leftVs,
                                   right: option.rightVs,
                                   foDic, os: fos).with(isBlock: true))
                    }
                } else {
                    if fi0 == ts.startIndex {//(| a)
                        let foTemps = fi0 + 1 < ts.count ?
                        Array(ts[(fi0 + 1)...]) : []
                        return O(F(os(from: foTemps)).with(isBlock: true))
                    } else if let option = fOption(Array(ts[..<fi0]),
                                                   isNoname: true) {
                        var oldDic = [OKey: O?]()
                        
                        for arg in option.leftVs {
                            oldDic[arg.outKey] = oDic[arg.outKey]
                            oDic[arg.outKey] = O()
                        }
                        for arg in option.rightVs {
                            oldDic[arg.outKey] = oDic[arg.outKey]
                            oDic[arg.outKey] = O()
                        }
                        let foTemps = fi0 + 1 < ts.count ?
                        Array(ts[(fi0 + 1)...]) : []
                        let fos = os(from: foTemps)
                        
                        for (key, value) in oldDic { oDic[key] = value }
                        
                        return O(F(precedence: option.prece ?? F.defaultPrecedence,
                                   associativity: option.asso,
                                   left: option.leftVs,
                                   right: option.rightVs,
                                   [:], os: fos).with(isBlock: true))
                    } else {
                        var oldDic = [OKey: O?]()
                        
                        guard let foDic = foDic(Array(ts[..<fi0]),
                                                &oldDic)
                        else { return O(OError("Function syntax error".localized)) }
                        if foDic.isEmpty {
                            return O(F(os(from: ts.filter({
                                switch $0 {
                                case .string(let s): s != "|"
                                default: true
                                }
                            }))))
                        } else {
                            let foTemps = fi0 + 1 < ts.count ?
                            Array(ts[(fi0 + 1)...]) : []
                            let fos = os(from: foTemps)
                            
                            for (key, value) in oldDic { oDic[key] = value }
                            
                            return O(foDic.isEmpty ? F(fos) : F(foDic, os: fos))
                        }
                    }
                }
            } else {//(a)
                return O(F(os(from: ts)))
            }
        }
        self = o(from: trees, isDic: isDictionary)
    }
    
    private struct Analyzed: CustomStringConvertible {
        enum AnalyzedType: String {
            case start, end, endStart
            case leftLiteral, rightLiteral, centerLiteral
            case string, leftString, rightString, centerString
            case stringBracketError, bracketError
        }
        var type: AnalyzedType, string: Substring
        
        init(_ type: AnalyzedType, _ string: Substring) {
            self.type = type
            self.string = string
        }
        var isLeftUnion: Bool {
            type == .leftLiteral || type == .centerLiteral
        }
        var isRightUnion: Bool {
            type == .rightLiteral || type == .centerLiteral
        }
        var description: String {
            "\(type.rawValue): \(string)"
        }
    }
    private static func analyzed(from text: Text, range: Range<String.Index>,
                                 stringBracket: Character = "\"",
                                 separator: Character = " ") -> [Analyzed] {
        let str = text.string[range]
        guard !str.isEmpty else { return [] }
        
        let string = String(str)
        let typesetter = Text(string: string).typesetter
        var vs = [(strs: [Substring], isWhitespace: Bool,
                   tabIntIndexes: [Int], i: Int, isMatrix: Bool)]()
        for typeline in typesetter.typelines {
            var j = 0, minI = typeline.range.lowerBound, ni: String.Index?
            var nsi = typeline.range.lowerBound
            typelinesLoop: while nsi < typeline.range.upperBound {
                let c = string[nsi]
                switch c {
                case "\t": j += 8
                default:
                    minI = nsi
                    ni = nsi
                    break typelinesLoop
                }
                nsi = string.index(after: nsi)
            }
            if j != 0 && ni == nil {
                ni = typeline.range.upperBound
                minI = typeline.range.upperBound
            }
            
            nsi = typeline.range.lowerBound
            var isWhitespace = true
            while nsi < typeline.range.upperBound {
                let c = string[nsi]
                if !c.isWhitespace {
                    isWhitespace = false
                }
                nsi = string.index(after: nsi)
            }
            
            var tabIntIndexes = [Int]()
            if minI < typeline.range.upperBound {
                let nextI = string.index(after: minI)
                if nextI < typeline.range.upperBound {
                    var isTab = false
                    var nsk = nextI
                    while nsk < typeline.range.upperBound {
                        switch string[nsk] {
                        case "\t": isTab = true
                        default:
                            if isTab {
                                let ni = string.distance(from: typeline.range.lowerBound,
                                                         to: nsk)
                                tabIntIndexes.append(ni)
                                isTab = false
                            }
                        }
                        nsk = string.index(after: nsk)
                    }
                    if isTab {
                        let nsk = typeline.range.upperBound
                        let ni = string.distance(from: typeline.range.lowerBound,
                                                 to: nsk)
                        tabIntIndexes.append(ni)
                    }
                }
            }
            
            let intRange = string.intRange(from: typeline.range)
            let isi = str.index(str.startIndex, offsetBy: intRange.lowerBound)
            let iei = str.index(str.startIndex, offsetBy: intRange.upperBound)
            let nstr = str[isi ..< iei]
            let nstrs = [nstr]
            if typeline.range.lowerBound == minI {
                vs.append((nstrs, isWhitespace, tabIntIndexes, 0, false))
            } else {
                vs.append((nstrs, isWhitespace, tabIntIndexes, j, false))
            }
        }
        
        if !vs.isEmpty {
            let lis = vs.reduce(into: Set<Int>()) {
                if $1.i > 0 {
                    $0.insert($1.i)
                }
            }
            var nvs = [(f: Int, l: Int, i:Int)]()
            for li in lis {
                let ns = vs.enumerated().map { $0 }
                    .split { li > $0.element.i }
                for n in ns {
                    if let si = n.first?.offset, let ei = n.last?.offset,
                       let minI = n.min(by: { $0.element.i < $1.element.i }),
                       minI.element.i == li {
                        
                        nvs.append((si, ei, li))
                    }
                }
            }
            
            for (i, v) in vs.enumerated() {
                if v.isWhitespace {
                    let fstr = v.strs[.first]
                    let si = fstr.startIndex
                    vs[i].strs.insert(fstr.substring("|", si ... si),
                                      at: v.strs.startIndex)
                } else if !v.tabIntIndexes.isEmpty {
                    let s = v.strs[.first]
                    var oi = s.startIndex
                    var nstrs = [Substring]()
                    for i in v.tabIntIndexes {
                        let ni = s.index(s.startIndex, offsetBy: i)
                        nstrs.append(s[oi ..< ni])
                        if ni < s.endIndex {
                            nstrs.append(s.substring(",", ni ... ni))
                        }
                        oi = ni
                    }
                    if oi < s.endIndex {
                        nstrs.append(s[oi...])
                    }
                    vs[i].strs = nstrs
                    
                    for nv in nvs {
                        if nv.i == v.i && i >= nv.f && i <= nv.l {
                            vs[nv.f].isMatrix = true
                            break
                        }
                    }
                }
                
                if !v.tabIntIndexes.isEmpty {
                    let fstr = vs[i].strs[.first]
                    let lstr = vs[i].strs[.last]
                    let si = fstr.startIndex
                    let ei = lstr.index(before: lstr.endIndex)
                    vs[i].strs.insert(fstr.substring("(", si ... si),
                                      at: vs[i].strs.startIndex)
                    vs[i].strs.append(lstr.substring(")", ei ... ei))
                }
            }
            
            for (fi, li, _) in nvs {
                let fstr = vs[fi].strs[.first]
                let lstr = vs[li].strs[.last]
                let si = fstr.startIndex
                let ei = lstr.index(before: lstr.endIndex)
                vs[fi].strs.insert(fstr.substring("(", si ... si),
                                   at: vs[fi].strs.startIndex)
                vs[li].strs.append(lstr.substring(")", ei ... ei))
                
                if vs[fi].isMatrix {
                    vs[fi].strs.insert(fstr.substring("(", si ... si),
                                       at: vs[fi].strs.startIndex)
                    vs[li].strs.append(lstr.substring(";", ei ... ei))
                    vs[li].strs.append(lstr.substring(")", ei ... ei))
                }
            }
        }
        
        let strs = vs.flatMap { $0.strs }
        
        struct StringResult {
            var isString: Bool, v: Substring
            var isWhitespaceLeft = false, isWhitespaceRight = false
        }
        var nss = [StringResult]()
        for str in strs {
            var issvs = [StringResult]()
            var si = str.startIndex, isS = false, lastBI: String.Index?
            for i in str.indices {
                let c = str[i]
                guard c == stringBracket else { continue }
                lastBI = i
                guard str.startIndex == i
                        || (str.startIndex < i && str[str.index(before: i)] != "\\") else { continue }
                if isS {
                    let ei = str.index(after: i)
                    let isWhitespaceLeft, isWhitespaceRight: Bool
                    if si == str.startIndex {
                        isWhitespaceLeft = true
                    } else {
                        let sc = str[str.index(before: si)]
                        isWhitespaceLeft = sc.isWhitespace || sc == "("
                    }
                    if ei == str.endIndex {
                        isWhitespaceRight = true
                    } else {
                        let sc = str[ei]
                        isWhitespaceRight = sc.isWhitespace || sc == ")"
                    }
                    issvs.append(StringResult(isString: true, v: str[si ..< ei],
                                              isWhitespaceLeft: isWhitespaceLeft,
                                              isWhitespaceRight: isWhitespaceRight))
                    si = ei
                } else {
                    if si < i {
                        issvs.append(StringResult(isString: false, v: str[si ..< i]))
                        si = i
                    }
                }
                isS = !isS
            }
            if si < str.endIndex {
                issvs.append(StringResult(isString: false, v: str[si ..< str.endIndex]))
            }
            for issv in issvs {
                if issv.isString {
                    nss.append(issv)
                } else {
                    let splited = issv.v.split(whereSeparator: { $0.isWhitespace })
                    for nv in splited {
                        if !nv.isEmpty {
                            nss.append(StringResult(isString: false, v: nv))
                        }
                    }
                }
            }
            if isS {
                if let bi = lastBI {
                    return [Analyzed(.stringBracketError, str[bi ... bi])]
                } else {
                    return [Analyzed(.stringBracketError, str)]
                }
            }
        }
        
        var srs = [Analyzed]()
        var iStack = [(i: Int, isC: Bool)]()
        for ns in nss {
            if ns.isString {
                if ns.isWhitespaceLeft {
                    if ns.isWhitespaceRight {
                        srs.append(Analyzed(.string, ns.v))
                    } else {
                        srs.append(Analyzed(.leftString, ns.v))
                    }
                } else {
                    if ns.isWhitespaceRight {
                        srs.append(Analyzed(.rightString, ns.v))
                    } else {
                        srs.append(Analyzed(.centerString, ns.v))
                    }
                }
            } else if ns.v.contains("(") || ns.v.contains(")") || ns.v.contains(",") {
                let nvs = ns.v.unionSplit(separator: "(,)")
                for (i, v) in nvs.enumerated() {
                    if v == "(" {
                        let right = i > 0 && nvs[i - 1] == ")"
                        srs.append(Analyzed(right ? .endStart : .start, v))
                        
                        iStack.append((srs.count - 1, false))
                    } else if v == ")" {
                        if let (oi, isC) = iStack.last {
                            if isC {
                                srs.insert(Analyzed(.start, srs[oi].string),
                                           at: oi + 1)
                                srs.append(Analyzed(.end, v))
                            }
                            iStack.removeLast()
                        } else {
                            return [Analyzed(.bracketError, v)]
                        }
                        
                        let left = i < nvs.count - 1 && nvs[i + 1] == "("
                        if !left {
                            srs.append(Analyzed(.end, v))
                        }
                    } else if v == "," {
                        if !iStack.isEmpty {
                            iStack[.last].isC = true
                        }
                        let vi = v.startIndex
                        srs.append(Analyzed(.end, v.substring(")", vi ... vi)))
                        srs.append(Analyzed(.start, v.substring("(", vi ... vi)))
                    } else {
                        let left = i < nvs.count - 1 && nvs[i + 1] == "("
                        let right = i > 0 && nvs[i - 1] == ")"
                        if left {
                            if right {
                                srs.append(Analyzed(.centerLiteral, v))
                            } else {
                                srs.append(Analyzed(.leftLiteral, v))
                            }
                        } else if right {
                            srs.append(Analyzed(.rightLiteral, v))
                        } else {
                            srs.append(Analyzed(.string, v))
                        }
                    }
                }
            } else {
                srs.append(Analyzed(.string, ns.v))
            }
        }
        if !iStack.isEmpty {
            return [Analyzed(.bracketError, str)]
        }
        
        for (i, sr) in srs.enumerated() {
            if (sr.type == .leftString || sr.type == .centerString)
                && i < srs.count - 1 {
                
                if srs[i + 1].type == .leftLiteral {
                    srs[i + 1].type = .centerLiteral
                } else if srs[i + 1].type == .string {
                    srs[i + 1].type = .rightLiteral
                }
            }
            if (sr.type == .rightString || sr.type == .centerString)
                && i > 0 {
                
                if srs[i - 1].type == .rightLiteral {
                    srs[i - 1].type = .centerLiteral
                } else if srs[i - 1].type == .string {
                    srs[i - 1].type = .leftLiteral
                }
            }
        }
        return srs
    }
    
    static let defaultLiteralSeparator = "!#%&-=^~|@:;,.{}[]<>+*/_"
    private static func literalO(from cs: [Temp],
                                 _ text: Text, _ typesetter: Typesetter,
                                 separator: String = O.defaultLiteralSeparator,
                                 _ oDic: inout [OKey: O]) -> O {
        func rect(at i: Substring.Index, _ str: Substring) -> Rect? {
            typesetter.characterBounds(at: i)
        }
        func rect(_ str: Substring) -> Rect? {
            return str.indices.reduce(into: Rect?.none) {
                if let r = rect(at: $1, str) {
                    $0 = $0 == nil ? r : $0! + r
                }
            }
        }
        func v(_ str: Substring, isInactivity: Bool = false) -> ID {
            if let r = rect(str) {
                return ID(String(str), isInactivity: isInactivity,
                          typesetter.typobute,
                          r + text.origin)
            } else {
                return ID(String(str),
                          isInactivity: isInactivity, typesetter.typobute)
            }
        }
        func v(_ nstr: String, in str: Substring) -> ID {
            if !str.isEmpty, var r = rect(at: str.startIndex, str) {
                r.size.width = 0
                return ID(nstr, typesetter.typobute, r + text.origin)
            } else {
                return ID(nstr, typesetter.typobute)
            }
        }
        func substring(from temps: [Temp]) -> Substring? {
            if temps.count == 1, case .uncal(let c)? = temps.first {
                return c
            } else {
                return nil
            }
        }
        
        if let str = substring(from: cs) {
            if str.contains("$") && oDic[OKey(str)] != nil {
                return O(v(str))
            } else if str.count >= 2 && str.last == ":" {
                var nstr = str
                nstr.removeLast()
                let lo = literalO(from: [.uncal(nstr)],
                                  text, typesetter, &oDic)
                if case .id(let id) = lo {
                    return O(OLabel(O(id.key.string)))
                } else {
                    return O(F([lo, O(ID(":"))]))
                }
            } else if str.count >= 2 && str.first == "\"" && str.last == "\"" {
                let si = str.index(str.startIndex, offsetBy: 1)
                let ei = str.index(str.endIndex, offsetBy: -1)
                return O(String(str[si ..< ei]))
            }
        }
        
        enum IDType {
            case int, real, o, string, id, subID, pow, separator, none
        }
        enum CurrentType {
            case none
            case integral, dot, decimal
            case separator, o, string, s, subS, superS
            var idType: IDType {
                switch self {
                case .none: .none
                case .integral: .int
                case .dot: .none
                case .decimal: .real
                case .separator: .separator
                case .o: .o
                case .string: .string
                case .s: .id
                case .subS: .subID
                case .superS: .pow
                }
            }
        }
        
        var os = [O]()
        var to = O(), ts: Substring = "", isSelect = false
        var tmpsi = ts.startIndex, tmpei = ts.startIndex
        var currentType = CurrentType.none
        var isPreviousOneValue = false
        
        func append() {
            if case id(var id)? = os.last, id.key == OKey(".") {
                if isSelect {
                    id.key = OKey("/.")
                    os[.last] = O(id)
                }
            }
            let tss = ts[tmpsi ..< tmpei]
            switch currentType.idType {
            case .int:
                if let i = Int(tss) {
                    os.append(O(i))
                } else if let d = Double(tss) {
                    os.append(O(d))
                } else {
                    os.append(O(OError(String(format: "'%1$@' is unknown literal".localized, "\(tss)"))))
                }
                isPreviousOneValue = true
            case .real:
                if let i = Int(tss) {
                    os.append(O(i))
                } else if let d = Double(tss) {
                    os.append(O(d))
                } else {
                    os.append(O(OError(String(format: "'%1$@' is unknown literal".localized, "\(tss)"))))
                }
                isPreviousOneValue = true
            case .o:
                if isPreviousOneValue {
                    os.append(O(v("*", in: tss)))
                }
                os.append(to)
                isPreviousOneValue = true
            case .string:
                os.append(to)
                isPreviousOneValue = false
            case .id:
                if let g = G(rawValue: String(tss)) {
                    os.append(O(g))
                } else if tss == "false" {
                    os.append(O(false))
                } else if tss == "true" {
                    os.append(O(true))
                } else if tss == "nil" {
                    os.append(O(OArray([])))
                } else if tss == "∞" {
                    os.append(O(Double.infinity))
                } else if case id(let id)? = os.last, id.key == OKey(".") {
                    if let i = Int(tss) {
                        os.append(O(i))
                    } else {
                        os.append(O(String(tss)))
                    }
                    isPreviousOneValue = false
                } else if case id(let id)? = os.last, id.key == OKey("/.") {
                    if let i = Int(tss) {
                        os.append(O(i))
                    } else {
                        os.append(O(String(tss)))
                    }
                    isSelect = true
                    isPreviousOneValue = false
                } else if oDic[OKey(tss)] != nil {
                    if tss.count > 1 && !tss.contains(where: { oDic[OKey($0)] == nil }) {
                        os.append(O(OError(String(format: "'%1$@' overlaps with multiplication by multiple single character variables".localized, "\(tss)"))))
                        isPreviousOneValue = false
                    } else {
                        if isPreviousOneValue {
                            os.append(O(v("*", in: tss)))
                        }
                        os.append(O(v(tss)))
                        isPreviousOneValue = tss.count == 1
                    }
                } else {
                    var isMul = !os.isEmpty && isPreviousOneValue
                    var nos = [O](), isP = false
                    for noi in tss.indices {
                        let ntss = tss[noi ... noi]
                        if oDic[OKey(ntss)] != nil {
                            if isMul {
                                nos.append(O(v("*", in: tss)))
                            } else {
                                isMul = true
                            }
                            nos.append(O((v(ntss))))
                            if tss.index(after: noi) == tss.endIndex {
                                isP = true
                            }
                        } else {
                            nos = [O(v(tss))]
                            break
                        }
                    }
                    isPreviousOneValue = isP
                    os += nos
                }
            case .subID:
                if oDic[OKey(tss)] != nil {
                    if isPreviousOneValue {
                        os.append(O(v("*", in: tss)))
                    }
                    os.append(O(v(tss)))
                } else {
                    os.append(O(OError(String(format: "'%1$@' is unknown literal".localized, "\(tss)"))))
                }
                isPreviousOneValue = true
            case .pow:
                var nt = text
                let a = tss.reduce(into: "") { $0.append($1.fromSuperscript ?? $1) }
                nt.string.replaceSubrange(tss.startIndex ..< tss.endIndex, with: a)
                
                let i = nt.string.intIndex(from: tss.startIndex)
                let ns = nt.string.index(fromInt: i)
                let ne = nt.string.index(fromInt: i + tss.count)
                
                let o = O(nt, range: ns ..< ne,
                          isDictionary: false, &oDic)
                os.append(O(v(powName, in: tss)))
                os.append(o)
                isPreviousOneValue = true
            case .separator:
                os.append(O(v(tss)))
                isPreviousOneValue = false
            case .none:
                os.append(O(OError(String(format: "'%1$@' is unknown literal".localized, "\(tss)"))))
                isPreviousOneValue = false
            }
            tmpsi = tmpei
        }
        enum SType {
            case num, separator, s, subS, superS
            
            init(_ n: Character, separator: String) {
                if "0123456789".contains(n) {
                    self = .num
                } else if separator.contains(n) {
                    self = .separator
                } else if n.isSubscript || n == "'" {
                    self = .subS
                } else if n.isSuperscript {
                    self = .superS
                } else {
                    self = .s
                }
            }
        }
        var isDot = false
        func analyzeLiteral(from s: Character, _ sType: SType) {
            if isDot {
                if (s == "." && currentType == .dot) || (s != "." && sType != .num) {
                    isDot = false
                }
            } else {
                if s == "." && currentType != .integral {
                    isDot = true
                }
            }
            switch currentType {
            case .none:
                switch sType {
                case .num: currentType = .integral
                case .separator: currentType = .separator
                case .s: currentType = .s
                case .subS: currentType = .none
                case .superS: currentType = .none
                }
            case .integral:
                switch sType {
                case .num: break
                case .separator:
                    if s == "." {
                        var ni = ts.index(after: tmpei), isSplit = false
                        if ni < ts.endIndex && ts[ni] == "." {
                            append()
                            currentType = .separator
                        } else {
                            if  ni == ts.endIndex || isDot {
                                isSplit = true
                            } else {
                                while ni != ts.endIndex {
                                    let ns = ts[ni]
                                    let sType = SType(ns, separator: separator)
                                    if sType != .num {
                                        if ns == "." {
                                            isSplit = true
                                        }
                                        break
                                    }
                                    ni = ts.index(after: ni)
                                }
                            }
                            if isSplit {
                                isDot = true
                                append()
                                currentType = .separator
                            } else {
                                currentType = .dot
                            }
                        }
                    } else {
                        append()
                        currentType = .separator
                    }
                case .s:
                    append()
                    currentType = .s
                case .subS:
                    append()
                    currentType = .none
                case .superS:
                    append()
                    currentType = .superS
                }
            case .dot:
                switch sType {
                case .num:
                    currentType = .decimal
                case .separator:
                    currentType = .none
                    append()
                    currentType = .separator
                case .s:
                    currentType = .none
                    append()
                    currentType = .s
                case .subS, .superS:
                    currentType = .none
                    append()
                    currentType = .none
                }
            case .decimal:
                switch sType {
                case .num: break
                case .separator:
                    append()
                    currentType = .separator
                case .s:
                    append()
                    currentType = .s
                case .subS:
                    append()
                    currentType = .none
                case .superS:
                    append()
                    currentType = .superS
                }
            case .separator:
                switch sType {
                case .num:
                    append()
                    currentType = .integral
                case .separator: break
                case .s:
                    append()
                    currentType = .s
                case .subS, .superS:
                    append()
                    currentType = .none
                }
            case .o:
                switch sType {
                case .num:
                    append()
                    currentType = .integral
                case .separator:
                    append()
                    currentType = .separator
                case .s:
                    append()
                    currentType = .s
                case .subS:
                    append()
                    currentType = .subS
                case .superS:
                    append()
                    currentType = .superS
                }
            case .string:
                switch sType {
                case .num:
                    append()
                    currentType = .integral
                case .separator:
                    append()
                    currentType = .separator
                case .s:
                    append()
                    currentType = .s
                case .subS:
                    append()
                    currentType = .subS
                case .superS:
                    append()
                    currentType = .superS
                }
            case .s:
                switch sType {
                case .num: break
                case .separator:
                    append()
                    currentType = .separator
                case .s: break
                case .subS:
                    if tmpsi < tmpei {
                        let ni = ts.index(before: tmpei)
                        if tmpsi < ni {
                            let oi = tmpei
                            tmpei = ni
                            append()
                            tmpei = oi
                        }
                    }
                    currentType = .subS
                case .superS:
                    append()
                    currentType = .superS
                }
            case .subS:
                switch sType {
                case .num:
                    append()
                    currentType = .none
                case .separator:
                    append()
                    currentType = .separator
                case .s:
                    append()
                    currentType = .s
                case .subS: break
                case .superS:
                    append()
                    currentType = .superS
                }
            case .superS:
                switch sType {
                case .num:
                    append()
                    currentType = .none
                case .separator:
                    append()
                    currentType = .separator
                case .s:
                    append()
                    currentType = .s
                case .subS:
                    append()
                    currentType = .none
                case .superS: break
                }
            }
        }
        for e in cs {
            switch e {
            case .o(let o, let s):
                switch currentType {
                case .none: break
                case .integral, .decimal,
                        .separator, .o, .string, .s, .subS, .superS:
                    append()
                case .dot:
                    currentType = .none
                    append()
                }
                to = o
                ts = s
                tmpsi = s.startIndex
                tmpei = s.endIndex
                currentType = .o
            case .uncal(let ns):
                if ns.count >= 2 && ns.first == "\"" && ns.last == "\"" {
                    let si = ns.index(ns.startIndex, offsetBy: 1)
                    let ei = ns.index(ns.endIndex, offsetBy: -1)
                    let o = O(String(ns[si ..< ei]))
                    switch currentType {
                    case .none: break
                    case .integral, .decimal,
                            .separator, .o, .string, .s, .subS, .superS:
                        append()
                    case .dot:
                        currentType = .none
                        append()
                    }
                    to = o
                    ts = ns
                    tmpsi = ns.startIndex
                    tmpei = ns.endIndex
                    currentType = .string
                } else {
                    ts = ns
                    tmpsi = ns.startIndex
                    tmpei = ns.startIndex
                    for i in ns.indices {
                        let n = ns[i]
                        let sType = SType(n, separator: separator)
                        analyzeLiteral(from: n, sType)
                        tmpei = ns.index(after: i)
                    }
                }
            }
        }
        append()
        if os.count == 1 {
            return os[0]
        } else {
            for o in os {
                if case .error = o {
                    return o
                }
            }
            return O(F(os))
        }
    }
}
extension O {
    static let stopped = O(OError("Stopped"))
    static let maxStackCount = 100000
    static let stackOverflow = O(OError(String(format: "Stack has exceeded the limit %d".localized, maxStackCount)))
    static func argsError(withCount count: Int, notCount: Int) -> O {
        O(OError(String(format: "Arguments count should be %1$d, not %2$d".localized, count, notCount)))
    }
    static func sendArgsError(withCount count: Int, notCount: Int) -> O {
        O(OError(String(format: "Arguments count for argument $1 must be %1$d, not %2$d".localized, count, notCount)))
    }
    static func arrayArgsError(withCount count: Int, notCount: Int) -> O {
        O(OError(String(format: "Array count for argument $1 must be %1$d, not %2$d".localized, count, notCount)))
    }
}

struct Calculator {
    static func rpn(_ os: [O], _ oDic: inout [OKey: O]) -> RPN {
        enum FVA {
            case fv(ID), f(F), arg([O])
        }
        func rootV(from ov: ID, _ oDic: inout [OKey: O]) -> ID {
            var v = ov, vSet = Set<ID>()
            while true {
                let preV = v
                if let o = oDic[v.key] {
                    switch o {
                    case .id(let nv): v = nv
                    default: return v.with(ov.typobute,
                                           typoBounds: ov.typoBounds)
                    }
                }
                vSet.insert(preV)
                guard !vSet.contains(v) else {
                    return v.with(ov.typobute, typoBounds: ov.typoBounds)
                }
            }
        }
        
        var fvas = [FVA](), args = [O]()
        for o in os {
            switch o {
            case .id(let ov):
                let v = rootV(from: ov, &oDic)
                if oDic[v.key] != nil {
//                    if let o = oDic[v.key], case .f = o {//
//                        args.append(o)
//                    } else {
                        args.append(O(v))
//                    }
                } else {
                    if !args.isEmpty {
                        fvas.append(.arg(args))
                        args = []
                    }
                    fvas.append(.fv(v))
                }
            case .f(let f):
                if f.isBlock || f.type == .empty {
                    args.append(o)
                } else {
                    if !args.isEmpty {
                        fvas.append(.arg(args))
                        args = []
                    }
                    fvas.append(.f(f))
                }
            default:
                args.append(o)
            }
        }
        if !args.isEmpty {
            fvas.append(.arg(args))
            args = []
        }
        
        func keywordString(from os: [O]) -> String {
            let s = os.reduce(into: "") {
                switch $1 {
//                case .f(let f):
//                    if f.os.count == 2,
//                        case .string(let s) = f.os[0],
//                        case .id(let id) = f.os[1], id.key.string == "::" {
//
//                        $0 += "$" + s
//                    } else {
//                        $0 += "$"
//                    }
                case .label(let label):
                    switch label.o {
                    case .string(let s): $0 += "$" + s
                    case .id(let s): $0 += "$" + s.key.string
                    default: $0 += "$"
                    }
                default: $0 += "$"
                }
            }
            return s
        }
        func keyString(from fva: FVA) -> String {
            switch fva {
            case .fv, .f: "$"
            case .arg(let os): keywordString(from: os)
            }
        }
        
        var nOIDFs = [OIDF](), indexes = [Int]()
        var idfBStack = Stack<IDF>(), idfLStack = Stack<IDF>()
        var sos = [OIDF]()
        func append(_ idf: IDF) {
            if idf.f.isShortCircuit && !indexes.isEmpty {
                let i = indexes.last!
                let ods = Array(nOIDFs[i...])
                nOIDFs.removeSubrange(i...)
                let f = F(RPN(oidfs: ods), isBlock: true)
                nOIDFs.append(.oOrBlockO(O(f)))
            }
            
            indexes.append(nOIDFs.count)
            nOIDFs.append(.calculateVN1(idf))
            
            let count = idf.f.outKeys.count + 1
            let noCount = indexes.count - count
            if !indexes.isEmpty && noCount >= 0 {
                let minI = indexes[noCount]
                indexes.removeLast(count)
                indexes.append(minI)
            }
        }
        func appendFromType(_ idf: IDF) {
            if !sos.isEmpty && idf.f.type != .empty {
                (0 ..< sos.count).forEach { indexes.append(nOIDFs.count + $0) }
                nOIDFs += sos
                
                sos = []
                while let nf = idfLStack.pop() { append(nf) }
            }
            switch idf.f.type {
            case .empty:
                if idf.f.isBlock {
                    sos.append(.oOrBlockO(O(idf.f)))
                } else {
                    sos.append(.calculateON0(idf.f))
                }
//            case .left: idfLStack.push(idf)
//            case .right:
//                if !idfLStack.isEmpty {
//                    idfLStack.removeAll()
//                }
//                append(idf)
//            case .binary:
            case .left, .right, .binary:
                if !idfLStack.isEmpty {
                    idfLStack.removeAll()
                }
                while !idfBStack.isEmpty {
                    let oldF = idfBStack.elements.last!
                    if idf.f.associativity == .right
                        && oldF.key == idf.key { break }
                    if oldF.f.type == .left && idf.f.type == .left { break }
                    if oldF.f.precedence < idf.f.precedence { break }
                    append(idfBStack.pop()!)
                }
                idfBStack.push(idf)
            }
        }
        for (i, fva) in fvas.enumerated() {
            switch fva {
            case .fv(let v):
                func idfAndO(from key: OKey) -> IDF? {
                    guard let o = oDic[key],
                        case .f(let f) = o else { return nil }
                    return IDF(key: key, f: f, v: v)
                }
                let ls = i > 0 ? "$" : ""
                let rs = i < fvas.count - 1 ?
                    keyString(from: fvas[i + 1]) : ""
                guard let idf = idfAndO(from: OKey(ls + v.key.string + rs))
                    ?? idfAndO(from: OKey(v.key.string + rs))
                    ?? idfAndO(from: OKey(ls + v.key.string)) else {
                    
                    indexes.append(nOIDFs.count)
                    if oDic.keys.contains(where: { $0.baseString == v.key.string }) {
                        nOIDFs.append(.oOrBlockO(O(OError(String(format: "The same function name as '%1$@' exists, but the arguments do not match".localized, v.key.string)))))
                    } else {
                        nOIDFs.append(.oOrBlockO(O(OError(String(format: "'%1$@' is unknown literal".localized, v.key.string)))))
                    }
                     
                    break
                }
                if idf.v?.isInactivity ?? false {
                    indexes.append(nOIDFs.count)
                    nOIDFs.append(.oOrBlockO(O(idf.f)))
                } else {
                    appendFromType(idf)
                }
            case .f(let f):
                if f.isBlock {
                    indexes.append(nOIDFs.count)
                    nOIDFs.append(.oOrBlockO(O(f)))
                } else {
                    appendFromType(IDF(key: OKey(), f: f, v: nil))
                }
            case .arg(let args):
                sos += args.map {
                    switch $0 {
                    case .id(let v): .calculateVN0(v)
                    case .f(let f):
                        if f.isBlock {
                            .oOrBlockO($0)
                        } else if f.type == .empty {
                            .calculateON0(f)
                        } else {
                            .oOrBlockO($0)
                        }
                    default: .oOrBlockO($0)
                    }
                }
            }
        }
        
        if !sos.isEmpty {
            (0 ..< sos.count).forEach { indexes.append(nOIDFs.count + $0) }
            nOIDFs += sos
            
            while let nf = idfLStack.pop() { append(nf) }
        }
        while let idf = idfBStack.pop() { append(idf) }
        
        if nOIDFs.contains(where: {
            switch $0 {
            case .calculateVN1: true
            default: false
            }
        }) {
            nOIDFs = nOIDFs.filter {
                switch $0 {
                case .oOrBlockO(let o):
                    switch o {
                    case .label: false
                    default: true
                    }
                default: true
                }
            }
        }
        return RPN(oidfs: nOIDFs)
    }
    
    typealias Handler = (ID?, O) -> (Bool)
    static func asyncCalculate(_ o: O, _ oDic: [OKey: O],
                               _ handler: Handler) async -> (o: O, id: ID?) {
        calculate(o, oDic, handler)
    }
    static func calculate(_ o: O, _ oDic: [OKey: O], _ handler: Handler) -> (o: O, id: ID?) {
        var oDic = oDic, memoRPN = [UUID: RPN]()
        switch o {
        case .f(let f):
            if f.outKeys.isEmpty {
                return calculate(f, nil, args: [], &oDic, &memoRPN, handler)
            }
        default: break
        }
        return (o, nil)
    }
    static func calculate(_ ff: F, _ fid: ID?, args fargs: [O],
                          _ oDic: inout [OKey: O],
                          _ memoRPN: inout [UUID: RPN],
                          _ handler: Handler) -> (o: O, id: ID?) {
        enum Loop {
            case first(_ f: F, _ id: ID?, args: [O])
            case l0(_ id: ID?)
            case l1(_ id: ID?, oldDic: [OKey: O], _ f: F, _ key: OKey, i: Dictionary<OKey, F>.Index)
            case l2(_ id: ID?, oldDic: [OKey: O], _ oidfs: [OIDF], _ oStack: [O], oj: Int)
        }
        var returnStack = Stack<O>(), loopStack = Stack<Loop>()
        loopStack.push(.first(ff, fid, args: fargs))
        loop: while true {
            let o: O, nid: ID?
            switch loopStack.pop()! {
            case .first(let f, let id, let args):
                if loopStack.elements.count == O.maxStackCount { return (.stackOverflow, id) }
                
                if let oo = f.run(args) {
                    o = oo
                } else {
                    switch f.runType {
                    case .send:
                        let oo = args[0], oso = args[1]
                        if case .f(let subF) = oo {
                            let os = oso.asArray
                            guard os.count == subF.outKeys.count
                            else {
                                let o = O.sendArgsError(withCount: subF.outKeys.count,
                                                        notCount: os.count)
                                if case .error = o {
                                    return (o, id)
                                }
                                guard handler(id, o) else { return (.stopped, nil) }
                                if loopStack.isEmpty {
                                    return (o, id)
                                } else {
                                    returnStack.push(o)
                                    continue loop
                                }
                            }
                            loopStack.push(.l0(id))
                            loopStack.push(.first(subF, nil, args: oso.asArray))
                            continue loop
                        } else {
                            o = oo
                        }
                    case .custom:
                        var oldDic = [OKey: O]()
                        oldDic.reserveCapacity(f.outKeys.count + f.definitions.count)
                        for (i, key) in f.outKeys.enumerated() {
                            oldDic[key] = oDic[key]
                            oDic[key] = args[i]
                        }
                        for (key, value) in f.definitions {
                            oldDic[key] = oDic[key]
                            oDic[key] = O(value)
                        }
                        for i in f.definitions.indices {
                            let (key, value) = f.definitions[i]
                            if value.type == .empty && !value.isBlock {
                                let j = f.definitions.index(after: i)
                                loopStack.push(.l1(id, oldDic: oldDic, f, key, i: j))
                                loopStack.push(.first(value, id, args: []))
                                continue loop
                            }
                        }
                        
                        let nRPN: RPN
                        if let rpn = f.rpn ?? memoRPN[f.id] {
                            nRPN = rpn
                        } else {
                            let rpn = rpn(f.os, &oDic)
                            memoRPN[f.id] = rpn
                            nRPN = rpn
                        }
                        let oidfs = nRPN.oidfs
                        var oStack = [O]()
                        for (oi, oidf) in oidfs.enumerated() {
                            switch oidf {
                            case .oOrBlockO(let o):
                                oStack.append(o)
                            case .calculateON0(let f):
                                loopStack.push(.l2(id, oldDic: oldDic, oidfs, oStack, oj: oi + 1))
                                loopStack.push(.first(f, nil, args: []))
                                continue loop
                            case .calculateVN0(let v):
                                let o = oDic[v.key] ?? O(v)
                                if case .f(let subF) = o, subF.type == .empty && !subF.isBlock {
                                    loopStack.push(.l2(id, oldDic: oldDic, oidfs, oStack, oj: oi + 1))
                                    loopStack.push(.first(subF, nil, args: []))
                                    continue loop
                                } else {
                                    oStack.append(o)
                                }
                            case .calculateVN1(let idf):
                                let subF = idf.f
                                let count = subF.outKeys.count
                                let noCount = oStack.count - count
                                guard noCount >= 0 else {
                                    let o = O.argsError(withCount: count, notCount: oStack.count)
                                    if case .error = o {
                                        return (o, id)
                                    }
                                    guard handler(id, o) else { return (.stopped, nil) }
                                    if loopStack.isEmpty {
                                        return (o, id)
                                    } else {
                                        returnStack.push(o)
                                        continue loop
                                    }
                                }
                                let nos = (0 ..< count).map { oStack[noCount + $0] }
                                oStack.removeLast(count)
                                loopStack.push(.l2(id, oldDic: oldDic, oidfs, oStack, oj: oi + 1))
                                loopStack.push(.first(subF, idf.v, args: nos))
                                continue loop
                            }
                        }
                        
                        for (key, value) in oldDic { oDic[key] = value }
                        
                        o = union(from: oStack)
                    default:
                        o = operateSpecial(f.runType, id, args: args, &oDic, &memoRPN, handler)
                    }
                }
                
                nid = id
            case .l0(let id):
                o = returnStack.pop()!
                nid = id
            case .l1(let id, let oldDic, let f, let key, let k):
                oDic[key] = returnStack.pop()!
                
                var i = k
                while i < f.definitions.endIndex {
                    let (key, value) = f.definitions[i]
                    if value.type == .empty && !value.isBlock {
                        let j = f.definitions.index(after: i)
                        loopStack.push(.l1(id, oldDic: oldDic, f, key, i: j))
                        loopStack.push(.first(value, fid, args: []))
                        continue loop
                    }
                    i = f.definitions.index(after: i)
                }
                
                let nRPN: RPN
                if let rpn = f.rpn ?? memoRPN[f.id] {
                    nRPN = rpn
                } else {
                    let rpn = rpn(f.os, &oDic)
                    memoRPN[f.id] = rpn
                    nRPN = rpn
                }
                let oidfs = nRPN.oidfs
                var oStack = [O]()
                for (oi, oidf) in oidfs.enumerated() {
                    switch oidf {
                    case .oOrBlockO(let o):
                        oStack.append(o)
                    case .calculateON0(let f):
                        loopStack.push(.l2(id, oldDic: oldDic, oidfs, oStack, oj: oi + 1))
                        loopStack.push(.first(f, nil, args: []))
                        continue loop
                    case .calculateVN0(let v):
                        let o = oDic[v.key] ?? O(v)
                        if case .f(let subF) = o, subF.type == .empty && !subF.isBlock {
                            loopStack.push(.l2(id, oldDic: oldDic, oidfs, oStack, oj: oi + 1))
                            loopStack.push(.first(subF, nil, args: []))
                            continue loop
                        } else {
                            oStack.append(o)
                        }
                    case .calculateVN1(let idf):
                        let subF = idf.f
                        let count = subF.outKeys.count
                        let noCount = oStack.count - count
                        guard noCount >= 0 else {
                            let o = O.argsError(withCount: count, notCount: oStack.count)
                            if case .error = o {
                                return (o, id)
                            }
                            guard handler(id, o) else { return (.stopped, nil) }
                            if loopStack.isEmpty {
                                return (o, id)
                            } else {
                                returnStack.push(o)
                                continue loop
                            }
                        }
                        let nos = (0 ..< count).map { oStack[noCount + $0] }
                        oStack.removeLast(count)
                        loopStack.push(.l2(id, oldDic: oldDic, oidfs, oStack, oj: oi + 1))
                        loopStack.push(.first(subF, idf.v, args: nos))
                        continue loop
                    }
                }
                
                for (key, value) in oldDic { oDic[key] = value }
                
                o = union(from: oStack)
                nid = id
            case .l2(let id, let oldDic, let oidfs, var oStack, let oj):
                oStack.append(returnStack.pop()!)
                
                for oi in oj ..< oidfs.count {
                    let oidf = oidfs[oi]
                    switch oidf {
                    case .oOrBlockO(let o):
                        oStack.append(o)
                    case .calculateON0(let f):
                        loopStack.push(.l2(id, oldDic: oldDic, oidfs, oStack, oj: oi + 1))
                        loopStack.push(.first(f, nil, args: []))
                        continue loop
                    case .calculateVN0(let v):
                        let o = oDic[v.key] ?? O(v)
                        if case .f(let subF) = o, subF.type == .empty && !subF.isBlock {
                            loopStack.push(.l2(id, oldDic: oldDic, oidfs, oStack, oj: oi + 1))
                            loopStack.push(.first(subF, nil, args: []))
                            continue loop
                        } else {
                            oStack.append(o)
                        }
                    case .calculateVN1(let idf):
                        let subF = idf.f
                        let count = subF.outKeys.count
                        let noCount = oStack.count - count
                        guard noCount >= 0 else {
                            let o = O.argsError(withCount: count, notCount: oStack.count)
                            if case .error = o {
                                return (o, id)
                            }
                            guard handler(id, o) else { return (.stopped, nil) }
                            if loopStack.isEmpty {
                                return (o, id)
                            } else {
                                returnStack.push(o)
                                continue loop
                            }
                        }
                        let nos = (0 ..< count).map { oStack[noCount + $0] }
                        oStack.removeLast(count)
                        loopStack.push(.l2(id, oldDic: oldDic, oidfs, oStack, oj: oi + 1))
                        loopStack.push(.first(subF, idf.v, args: nos))
                        continue loop
                    }
                }
                
                for (key, value) in oldDic { oDic[key] = value }
                
                o = union(from: oStack)
                nid = id
            }
            
            if case .error = o {
                return (o, nid)
            }
            guard handler(nid, o) else { return (.stopped, nil) }
            
            if loopStack.isEmpty {
                return (o, nid)
            } else {
                returnStack.push(o)
                continue loop
            }
        }
    }
    private static func calculateS(_ f: F, _ id: ID?, args: [O],
                                   _ oDic: inout [OKey: O],
                                   _ memoRPN: inout [UUID: RPN],
                                   _ handler: Handler) -> O {
        if let o = f.run(args) {
            guard handler(id, o) else { return .stopped }
            return o
        } else {
            switch f.runType {
            case .send:
                let o = args[0], oso = args[1]
                if case .f(let subF) = o {
                    let os = oso.asArray
                    guard os.count == subF.outKeys.count
                    else {
                        let o = O.sendArgsError(withCount: subF.outKeys.count,
                                                notCount: os.count)
                        guard handler(id, o) else { return .stopped }
                        return o
                    }
                    let o = calculateS(subF, nil, args: os, &oDic, &memoRPN, handler)
                    guard handler(id, o) else { return .stopped }
                    return o
                } else {
                    guard handler(id, o) else { return .stopped }
                    return o
                }
            case .custom:
                var oldDic = [OKey: O]()
                oldDic.reserveCapacity(f.outKeys.count + f.definitions.count)
                for (i, key) in f.outKeys.enumerated() {
                    oldDic[key] = oDic[key]
                    oDic[key] = args[i]
                }
                for (key, value) in f.definitions {
                    oldDic[key] = oDic[key]
                    oDic[key] = O(value)
                }
                for (key, value) in f.definitions {
                    if value.type == .empty && !value.isBlock {
                        oDic[key] = calculateS(value, id, args: [], &oDic, &memoRPN, handler)
                    }
                }
                
                let nRPN: RPN
                if let rpn = f.rpn ?? memoRPN[f.id] {
                    nRPN = rpn
                } else {
                    let rpn = rpn(f.os, &oDic)
                    memoRPN[f.id] = rpn
                    nRPN = rpn
                }
                let oidfs = nRPN.oidfs
                var oStack = [O]()
                for oidf in oidfs {
                    switch oidf {
                    case .oOrBlockO(let o):
                        oStack.append(o)
                    case .calculateON0(let f):
                        oStack.append(calculateS(f, nil, args: [], &oDic, &memoRPN, handler))
                    case .calculateVN0(let v):
                        let o = oDic[v.key] ?? O(v)
                        if case .f(let subF) = o, subF.type == .empty && !subF.isBlock {
                            let o = calculateS(subF, nil, args: [], &oDic, &memoRPN, handler)
                            oStack.append(o)
                        } else {
                            oStack.append(o)
                        }
                    case .calculateVN1(let idf):
                        let subF = idf.f
                        let count = subF.outKeys.count
                        let noCount = oStack.count - count
                        guard noCount >= 0 else {
                            let o = O.argsError(withCount: count, notCount: oStack.count)
                            guard handler(id, o) else { return .stopped }
                            return o
                        }
                        let nos = (0 ..< count).map { oStack[noCount + $0] }
                        oStack.removeLast(count)
                        oStack.append(calculateS(subF, idf.v, args: nos, &oDic, &memoRPN, handler))
                    }
                }
                
                for (key, value) in oldDic { oDic[key] = value }
                
                let o = union(from: oStack)
                guard handler(id, o) else { return .stopped }
                return o
            default:
                let o = operateSpecial(f.runType, id, args: args, &oDic, &memoRPN, handler)
                guard handler(id, o) else { return .stopped }
                return o
            }
        }
    }
    
    private static func union(from os: [O]) -> O {
        guard os.count != 1 else { return os[0] }
        for o in os {
            switch o {
            case .error: return o
            default: break
            }
        }
        if os.contains(where: {
            switch $0 {
            case .label: true
            default: false
            }
        }) {
            var i = 0, oldLabel: OLabel?, oDic = [O: O]()
            for o in os {
                switch o {
                case .label(let label): oldLabel = label
                default:
                    if let nLabel = oldLabel {
                        oDic[nLabel.o] = o
                        oldLabel = nil
                    } else {
                        oDic[O("$\(i)")] = o
                        i += 1
                    }
                }
            }
            return O(oDic)
        } else {
            return O(OArray(os))
        }
    }
    
    private static func operateSpecial(_ runType: F.RunType, _ id: ID?, args: [O],
                                       _ oDic: inout [OKey: O],
                                       _ memoRPN: inout [UUID: RPN],
                                       _ handler: Handler) -> O {
        switch runType {
        case .flip: O.flip(args[0], &oDic)
        case .showAllDefinitions: O.showAllDefinitions(args[0], &oDic)
        case .drawAxes: O.drawAxes(base: args[0], args[1], args[2], &oDic)
        case .plot: O.plot(base: args[0], args[1], &oDic)
        case .draw: O.draw(args[0], &oDic)
        case .map://再帰バグ
            O.map(args[0], args[1]) { calculate($0, id, args: [$1], &oDic, &memoRPN, handler).o }
        case .filter:
            O.filter(args[0], args[1]) { calculate($0, id, args: [$1], &oDic, &memoRPN, handler).o }
        case .reduce:
            O.reduce(args[0], args[1], args[2]) { calculate($0, id, args: [$1, $2], &oDic, &memoRPN, handler).o }
        default: fatalError()
        }
    }
}
