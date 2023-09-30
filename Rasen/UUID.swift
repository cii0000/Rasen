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

import struct Foundation.UUID
import class Foundation.NSUUID
import struct Foundation.Data

extension UUID: Protobuf {
    init(_ pb: PBUUID) throws {
        if let v = Self(data: pb.data) {
            self = v
        } else if let v = Self(uuidString: pb.value) {
            self = v
        } else {
            throw ProtobufError()
        }
    }
    var pb: PBUUID {
        .with {
            $0.data = data
        }
    }
}
extension UUID {
    init(index i: UInt8) {
        self.init(uuid: (i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i))
    }
    
    static let zero = Self(index: 0)
    static let one = Self(index: 1)
    
    init?(data: Data) {
        guard data.count == 16 else { return nil }
        let uuid: Self? = data.withUnsafeBytes {
            guard let ptr = $0.baseAddress?
                .assumingMemoryBound(to: UInt8.self) else { return nil }
            return NSUUID(uuidBytes: ptr) as Self
        }
        if let uuid = uuid {
            self = uuid
        } else {
            return nil
        }
    }
    var data: Data {
        var data = Data(count: 16)
        data.withUnsafeMutableBytes {
            guard let ptr = $0.baseAddress?
                .assumingMemoryBound(to: UInt8.self) else { return }
            (self as NSUUID).getBytes(ptr)
        }
        return data
    }
}

struct UU<Value: Codable>: Codable {
    var value: Value {
        didSet {
            id = UUID()
        }
    }
    private(set) var id: UUID
    
    init(_ value: Value, id: UUID = UUID()) {
        self.value = value
        self.id = id
    }
}
extension UU: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
extension UU: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
extension UU: Interpolatable where Value: Interpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self {
        let value = Value.linear(f0.value, f1.value, t: t)
        return Self(value)
    }
    static func firstSpline(_ f1: Self, _ f2: Self, _ f3: Self,
                            t: Double) -> Self {
        let value = Value.firstSpline(f1.value, f2.value, f3.value, t: t)
        return Self(value)
    }
    static func spline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self,
                       t: Double) -> Self {
        let value = Value.spline(f0.value, f1.value, f2.value, f3.value, t: t)
        return Self(value)
    }
    static func lastSpline(_ f0: Self, _ f1: Self, _ f2: Self,
                           t: Double) -> Self {
        let value = Value.lastSpline(f0.value, f1.value, f2.value, t: t)
        return Self(value)
    }
}
extension UU: MonoInterpolatable where Value: MonoInterpolatable {
    static func firstMonospline(_ f1: Self, _ f2: Self, _ f3: Self,
                                with ms: Monospline) -> Self {
        let value = Value.firstMonospline(f1.value, f2.value, f3.value, with: ms)
        return Self(value)
    }
    static func monospline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self,
                           with ms: Monospline) -> Self {
        let value = Value.monospline(f0.value, f1.value, f2.value, f3.value, with: ms)
        return Self(value)
    }
    static func lastMonospline(_ f0: Self, _ f1: Self, _ f2: Self,
                               with ms: Monospline) -> Self {
        let value = Value.lastMonospline(f0.value, f1.value, f2.value, with: ms)
        return Self(value)
    }
}
